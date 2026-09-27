-- [ts]: Hud.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ResultHintHex, ResultButtonBgHex, ResultButtonAltBgHex, ResultButtonFgHex, ResultButtonBorderHex -- 1
local ____Dora = require("Dora") -- 32
local Node = ____Dora.Node -- 32
local Size = ____Dora.Size -- 32
local Vec2 = ____Dora.Vec2 -- 32
local ____Projection = require("game.Projection") -- 33
local screenToPlaneY = ____Projection.screenToPlaneY -- 33
local ____Config = require("game.Config") -- 35
local AimMaxDragPx = ____Config.AimMaxDragPx -- 36
local AimMaxSpeed = ____Config.AimMaxSpeed -- 36
local AimMinSpeed = ____Config.AimMinSpeed -- 36
local FlightPlayback = ____Config.FlightPlayback -- 36
local PlaneToWorldX = ____Config.PlaneToWorldX -- 36
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 36
local TimeWarpRate = ____Config.TimeWarpRate -- 37
local TimeWarpStep = ____Config.TimeWarpStep -- 37
local WarpHoldDelaySec = ____Config.WarpHoldDelaySec -- 37
local ____Ui = require("game.Ui") -- 42
local MinButtonHeight = ____Ui.MinButtonHeight -- 42
local MinButtonWidth = ____Ui.MinButtonWidth -- 42
local createButton = ____Ui.createButton -- 42
local createLabel = ____Ui.createLabel -- 42
local createPanel = ____Ui.createPanel -- 42
local setLabelCenter = ____Ui.setLabelCenter -- 42
local setLabelColor = ____Ui.setLabelColor -- 42
local setLabelText = ____Ui.setLabelText -- 42
--- 纯计算：由“探测器屏幕偏移”与“当前触摸屏幕偏移”解算发射向量。
-- 
-- 方向语义（手册 §5.7）：发射方向 = **探测器 → 触摸点**。
-- 屏幕上玩家把手指移到探测器**上方**，发射就朝屏幕上方。
-- 
-- @param probeOffset 探测器在投影偏移空间中的位置
-- @param touchOffset 触摸点在投影偏移空间中的位置
-- @param maxDragPx 拖动多少像素算满力
-- @param maxSpeed 满力对应的速度（= 这一关的 Δv 预算）；省略 = 全局上限 `AimMaxSpeed`
function ____exports.computeAim(probeOffset, touchOffset, maxDragPx, maxSpeed) -- 71
	local speedTop = maxSpeed ~= nil and maxSpeed > AimMinSpeed and maxSpeed or AimMaxSpeed -- 77
	local dx = touchOffset.x - probeOffset.x -- 82
	local dy = touchOffset.y - probeOffset.y -- 83
	local len = math.sqrt(dx * dx + dy * dy) -- 85
	if len < 0.000001 then -- 85
		return {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 88
	end -- 88
	local ux = dx / len -- 91
	local uy = -dy / len -- 96
	local safeMax = maxDragPx > 1 and maxDragPx or 1 -- 98
	local power = len / safeMax -- 99
	if power < 0 then -- 99
		power = 0 -- 100
	end -- 100
	if power > 1 then -- 100
		power = 1 -- 101
	end -- 101
	local speed = AimMinSpeed + (speedTop - AimMinSpeed) * power -- 103
	return {velocity = {x = ux * speed, y = uy * speed}, power = power, unit = {x = ux, y = uy}} -- 105
end -- 71
--- 把屏幕位置（**投影偏移空间**，与 `project()` 同空间）转成平面坐标。
-- 
-- 不是矄准必需（矄准只用方向），但调试与关卡设计时有用。
-- 与 `project()` 互逆（已有往返测试守着）。
function ____exports.screenToPlane(viewPoint, basis) -- 118
	local world = screenToPlaneY(viewPoint, basis, 0) -- 122
	if world == nil then -- 122
		return nil -- 123
	end -- 123
	return {x = world.x / PlaneToWorldX, y = world.z / PlaneToWorldZ} -- 125
end -- 118
--- 默认的力度→拖动像素映射（供 UI 层统一引用）。
function ____exports.defaultMaxDragPx() -- 129
	return AimMaxDragPx -- 130
end -- 129
--- 默认速度区间（供 UI 层展示）。
function ____exports.defaultSpeedRange() -- 134
	return {min = AimMinSpeed, max = AimMaxSpeed} -- 135
end -- 134
--- 全屏输入节点的局部坐标 → 投影偏移空间（中心原点、+Y 向上）。
-- 
-- 两个空间的差异（已核对 `Projection.ts` 的修正后约定）：
-- 
-- | | 原点 | 范围 | Y 方向 |
-- |---|---|---|---|
-- | 全屏节点局部坐标 | **左下角** | [0,W]×[0,H] | **+Y 向上** |
-- | 投影偏移空间 | **屏幕中心** | ±W/2, ±H/2 | **+Y 向上** |
-- 
-- 换算：`offset.x = local.x - W/2`，`offset.y = local.y - H/2`。
function ____exports.localToOffset(____local, space) -- 156
	return {x = ____local.x - space.viewW / 2, y = ____local.y - space.viewH / 2} -- 157
end -- 156
--- 反向换算（投影偏移空间 → 全屏节点局部坐标）。
function ____exports.offsetToLocal(offset, space) -- 161
	return {x = offset.x + space.viewW / 2, y = offset.y + space.viewH / 2} -- 162
end -- 161
--- 创建拖拽矄准输入层。
-- 
-- ### 为何要一个带尺寸的全屏节点
-- `touch.location` 是**接收节点局部坐标**。若直接挂在未设尺寸的
-- `Director.ui` 根上，其局部坐标就是屏幕中心原点（+Y 向上），
-- 与投影空间不一致，容易搞错。这里用一个 `size = View.size`、
-- `anchor = (0.5,0.5)` 的全屏节点，使 `touch.location` 落在
-- `[0,W]×[0,H]`、左下原点、+Y 向上，再用 `localToOffset()` 显式换算。
-- 
-- @param parent 挂载父节点（通常是 Director.ui）
-- @param viewW 视图宽（`View.size.width`）
-- @param viewH 视图高（`View.size.height`）
function ____exports.createAimInput(parent, viewW, viewH, maxSpeed) -- 291
	local brakeOn, paintBrake, datePlate, dateLabel -- 291
	local speedTop = maxSpeed ~= nil and maxSpeed > AimMinSpeed and maxSpeed or AimMaxSpeed -- 298
	local root = Node() -- 299
	root.size = Size(viewW, viewH) -- 300
	root.anchor = Vec2(0, 0) -- 306
	root.position = Vec2(0, 0) -- 307
	local touchLayer = Node() -- 310
	touchLayer.size = Size(viewW, viewH) -- 311
	touchLayer.anchor = Vec2(0.5, 0.5) -- 312
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 313
	touchLayer.swallowTouches = true -- 314
	root:addChild(touchLayer) -- 315
	local space = {viewW = viewW, viewH = viewH} -- 317
	local enabled = false -- 319
	local dragging = false -- 320
	--- 整屏瞄准（2D 模式）；由 Game 按视图状态同步。
	local fullScreenAim = false -- 322
	local aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 323
	local probeOffset = {x = 0, y = 0} -- 326
	local dragHandler = nil -- 328
	local readyHandler = nil -- 329
	local observeHandler = nil -- 330
	local zoomHandler = nil -- 331
	local launchHandler = nil -- 332
	local pressOffset = {x = 0, y = 0} -- 343
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 346
		aim = ____exports.computeAim({x = 0, y = 0}, delta, AimMaxDragPx, speedTop) -- 347
		if dragHandler ~= nil then -- 347
			dragHandler(aim) -- 348
		end -- 348
	end -- 346
	local aimRadius = math.max(96, viewW * 0.25) -- 355
	local mode = "none" -- 356
	local observeLast = {x = 0, y = 0} -- 357
	touchLayer:onTapBegan(function(touch) -- 358
		if not enabled then -- 358
			return -- 359
		end -- 359
		local at = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 360
		local dx = at.x - probeOffset.x -- 361
		local dy = at.y - probeOffset.y -- 362
		if fullScreenAim or math.sqrt(dx * dx + dy * dy) <= aimRadius then -- 362
			mode = "aim" -- 364
			dragging = true -- 365
			pressOffset = at -- 366
			handleDelta({x = 0, y = 0}) -- 368
		else -- 368
			mode = "observe" -- 370
			observeLast = at -- 371
		end -- 371
	end) -- 358
	touchLayer:onTapMoved(function(touch) -- 375
		if not enabled then -- 375
			return -- 376
		end -- 376
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 377
		if mode == "aim" and dragging then -- 377
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 379
		elseif mode == "observe" then -- 379
			if observeHandler ~= nil then -- 379
				observeHandler(cur.x - observeLast.x, cur.y - observeLast.y) -- 382
			end -- 382
			observeLast = cur -- 383
		end -- 383
	end) -- 375
	touchLayer:onTapEnded(function(touch) -- 387
		if not enabled then -- 387
			return -- 388
		end -- 388
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 389
		if mode == "aim" then -- 389
			dragging = false -- 391
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 392
			if readyHandler ~= nil then -- 392
				readyHandler(aim) -- 394
			end -- 394
		end -- 394
		mode = "none" -- 396
	end) -- 387
	touchLayer:onGesture(function(_center, numFingers, deltaDist, _deltaAngle) -- 400
		if not enabled or numFingers < 2 then -- 400
			return -- 401
		end -- 401
		if zoomHandler ~= nil then -- 401
			zoomHandler(deltaDist) -- 402
		end -- 402
	end) -- 400
	touchLayer.touchEnabled = false -- 410
	local brakeHandler = nil -- 415
	local BrakeButtonW = 116 -- 416
	local BrakeButtonH = 64 -- 417
	local brakeGap = 8 -- 418
	local brakeButtons = {} -- 422
	local function makeBrakeButton(text, on, x) -- 423
		local btn = createButton( -- 424
			root, -- 424
			{ -- 424
				w = BrakeButtonW, -- 425
				h = BrakeButtonH, -- 426
				text = text, -- 427
				fontSize = 30, -- 428
				bgHex = ResultButtonAltBgHex, -- 429
				fgHex = ResultButtonFgHex, -- 430
				borderHex = ResultButtonBorderHex, -- 431
				onTap = function() -- 432
					brakeOn = on -- 435
					paintBrake() -- 436
					if brakeHandler ~= nil then -- 436
						brakeHandler(on) -- 437
					end -- 437
				end -- 432
			} -- 432
		) -- 432
		btn.root.position = Vec2(x, viewH - BrakeButtonH - 20) -- 440
		brakeButtons[#brakeButtons + 1] = btn -- 441
	end -- 423
	brakeOn = false -- 443
	paintBrake = function() -- 444
		if #brakeButtons < 2 then -- 444
			return -- 445
		end -- 445
		brakeButtons[1]:setColors(brakeOn and ResultButtonAltBgHex or ResultButtonBgHex, ResultButtonFgHex) -- 446
		brakeButtons[2]:setColors(brakeOn and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 447
	end -- 444
	createPanel( -- 453
		root, -- 453
		220, -- 453
		50, -- 453
		658964, -- 453
		{alpha = 0.45} -- 453
	) -- 453
	local dvLabel = createLabel(root, "Δv — / —", 30, ResultHintHex) -- 454
	if dvLabel ~= nil then -- 454
		dvLabel.position = Vec2(24, viewH - 44) -- 456
		dvLabel.anchor = Vec2(0, 0) -- 457
	end -- 457
	local warpHandler = nil -- 467
	local dateSpan = 0 -- 468
	--- 这一关有时间轴**且**当前相态允许改日期（Flying/Result 时必须是 false）。
	local warpOn = true -- 475
	local warpVisible = true -- 476
	--- 相态是否允许改日期（由主循环每帧 setTimeEnabled 同步）。
	local warpAllowed = true -- 478
	--- 上次写进日期的文字（避免每帧重设 Label 文本）。
	local lastDateText = "" -- 480
	--- >0 = 正在按住这个方向（-1 回退 / +1 加速）；0 = 没按住。
	local warpHoldDir = 0 -- 482
	--- 距离下一次连按还有多久（秒）。
	local warpRepeatIn = 0 -- 484
	local WarpButtonW = 116 -- 485
	local WarpButtonH = 64 -- 486
	local warpButtons = {} -- 487
	local function applyWarpState() -- 488
		local vis = dateSpan > 0 -- 489
		local on = vis and warpAllowed -- 490
		if vis == warpVisible and on == warpOn then -- 490
			return -- 491
		end -- 491
		warpVisible = vis -- 492
		warpOn = on -- 493
		if not on then -- 493
			warpHoldDir = 0 -- 494
		end -- 494
		for ____, b in ipairs(warpButtons) do -- 495
			b.root.visible = vis -- 496
			b:setEnabled(on) -- 497
		end -- 497
		if dateLabel ~= nil then -- 497
			dateLabel.visible = vis -- 499
		end -- 499
		datePlate.visible = vis -- 500
	end -- 488
	local function makeWarpButton(text, dir, x) -- 502
		local btn = createButton( -- 503
			root, -- 503
			{ -- 503
				w = WarpButtonW, -- 504
				h = WarpButtonH, -- 505
				text = text, -- 506
				fontSize = 30, -- 507
				bgHex = ResultButtonAltBgHex, -- 508
				fgHex = ResultButtonFgHex, -- 509
				borderHex = ResultButtonBorderHex, -- 510
				onTap = function() -- 513
				end, -- 513
				onPressBegan = function() -- 514
					print((("[escape-velocity] warp press dir=" .. __TS__NumberToFixed(dir, 0)) .. " on=") .. (warpOn and "1" or "0")) -- 516
					if not warpOn then -- 516
						return -- 517
					end -- 517
					if warpHoldDir == dir then -- 517
						return -- 519
					end -- 519
					warpHoldDir = dir -- 520
					warpRepeatIn = WarpHoldDelaySec -- 521
					if warpHandler ~= nil then -- 521
						warpHandler(dir) -- 522
					end -- 522
				end, -- 514
				onPressEnded = function() -- 524
					print((("[escape-velocity] warp release dir=" .. __TS__NumberToFixed(dir, 0)) .. " hold=") .. __TS__NumberToFixed(warpHoldDir, 0)) -- 525
					if warpHoldDir == dir then -- 525
						warpHoldDir = 0 -- 527
					end -- 527
				end -- 524
			} -- 524
		) -- 524
		btn.root.position = Vec2(x, viewH - 96 - WarpButtonH) -- 533
		warpButtons[#warpButtons + 1] = btn -- 534
	end -- 502
	local warpLeftX = viewW - (WarpButtonW * 2 + 8) - 20 -- 536
	makeWarpButton("◀ 回退", -1, warpLeftX) -- 537
	makeWarpButton("加速 ▶", 1, warpLeftX + WarpButtonW + 8) -- 538
	datePlate = createPanel( -- 540
		root, -- 540
		300, -- 540
		50, -- 540
		658964, -- 540
		{alpha = 0.45} -- 540
	) -- 540
	datePlate.position = Vec2(warpLeftX - 316, viewH - 96 - WarpButtonH + 8) -- 541
	dateLabel = createLabel(root, "发射日期 —", 30, ResultHintHex) -- 542
	if dateLabel ~= nil then -- 542
		dateLabel.anchor = Vec2(1, 0) -- 547
		dateLabel.position = Vec2(warpLeftX - 16, viewH - 96 - WarpButtonH + 18) -- 548
	end -- 548
	local LaunchButtonW = 220 -- 555
	local LaunchButtonH = 112 -- 556
	local launchButton = createButton( -- 557
		root, -- 557
		{ -- 557
			w = LaunchButtonW, -- 558
			h = LaunchButtonH, -- 559
			text = "发射", -- 560
			fontSize = 44, -- 561
			bgHex = ResultButtonBgHex, -- 562
			fgHex = ResultButtonFgHex, -- 563
			borderHex = ResultButtonBorderHex, -- 564
			fireOn = "press", -- 565
			onTap = function() -- 566
				print("[escape-velocity] launch button fire (press)") -- 568
				if launchHandler ~= nil then -- 568
					launchHandler() -- 569
				end -- 569
			end -- 566
		} -- 566
	) -- 566
	launchButton.root.position = Vec2(viewW - LaunchButtonW - 24, 96) -- 572
	launchButton.root.visible = false -- 573
	launchButton:setEnabled(false) -- 574
	local ViewButtonW = 116 -- 582
	local ViewButtonH = 64 -- 583
	local viewHandler = nil -- 584
	local viewButton = createButton( -- 585
		root, -- 585
		{ -- 585
			w = ViewButtonW, -- 586
			h = ViewButtonH, -- 587
			text = "2D", -- 588
			fontSize = 30, -- 589
			bgHex = ResultButtonAltBgHex, -- 590
			fgHex = ResultButtonFgHex, -- 591
			borderHex = ResultButtonBorderHex, -- 592
			fireOn = "press", -- 594
			onTap = function() -- 595
				print("[escape-velocity] view toggle fire (press)") -- 596
				if viewHandler ~= nil then -- 596
					viewHandler() -- 597
				end -- 597
			end -- 595
		} -- 595
	) -- 595
	viewButton.root.position = Vec2(viewW - ViewButtonW - 24, 96 + LaunchButtonH + 12) -- 603
	--- 上次写进按钮的文字（每帧都会被 setViewMode 调用，没变就别碰 Label）。
	local lastViewText = "2D" -- 605
	local PlaybackButtonW = 116 -- 614
	local PlaybackButtonH = 64 -- 615
	local playbackGap = 10 -- 616
	local playbackButtons = {} -- 617
	local playbackSpeeds = {} -- 618
	local playbackHandler = nil -- 619
	local playbackSpeed = FlightPlayback -- 620
	--- 已应用到节点上的显隐状态。初值 false 如实反映"建出来就隐藏"（照 warp 按钮的教训）。
	local playbackVisible = false -- 622
	local function paintPlayback() -- 623
		do -- 623
			local i = 0 -- 624
			while i < #playbackButtons do -- 624
				local on = playbackSpeeds[i + 1] == playbackSpeed -- 625
				playbackButtons[i + 1]:setColors(on and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 626
				i = i + 1 -- 624
			end -- 624
		end -- 624
	end -- 623
	local function makePlaybackButton(speed, x) -- 629
		local btn = createButton( -- 630
			root, -- 630
			{ -- 630
				w = PlaybackButtonW, -- 631
				h = PlaybackButtonH, -- 632
				text = __TS__NumberToFixed(speed, 0) .. "×", -- 633
				fontSize = 30, -- 634
				bgHex = ResultButtonAltBgHex, -- 635
				fgHex = ResultButtonFgHex, -- 636
				borderHex = ResultButtonBorderHex, -- 637
				onTap = function() -- 638
					print(("[escape-velocity] playback button fire " .. __TS__NumberToFixed(speed, 0)) .. "x (release)") -- 640
					playbackSpeed = speed -- 641
					paintPlayback() -- 642
					if playbackHandler ~= nil then -- 642
						playbackHandler(speed) -- 643
					end -- 643
				end -- 638
			} -- 638
		) -- 638
		btn.root.position = Vec2(x, 96) -- 648
		playbackButtons[#playbackButtons + 1] = btn -- 649
		playbackSpeeds[#playbackSpeeds + 1] = speed -- 650
	end -- 629
	makePlaybackButton(1, 24) -- 652
	makePlaybackButton(2, 24 + PlaybackButtonW + playbackGap) -- 653
	makePlaybackButton(4, 24 + (PlaybackButtonW + playbackGap) * 2) -- 654
	paintPlayback() -- 655
	for ____, b in ipairs(playbackButtons) do -- 657
		b.root.visible = false -- 658
		b:setEnabled(false) -- 659
	end -- 659
	local brakeRightX = viewW - BrakeButtonW - 20 -- 662
	makeBrakeButton("惯性", false, brakeRightX - BrakeButtonW - brakeGap) -- 663
	makeBrakeButton("刹车", true, brakeRightX) -- 664
	paintBrake() -- 665
	parent:addChild(root) -- 667
	return { -- 669
		onDrag = function(____, callback) -- 670
			dragHandler = callback -- 671
		end, -- 670
		setEnabled = function(____, value) -- 673
			enabled = value -- 674
			touchLayer.touchEnabled = value -- 677
			if not value then -- 677
				dragging = false -- 678
			end -- 678
		end, -- 673
		onBrake = function(____, callback) -- 680
			brakeHandler = callback -- 681
		end, -- 680
		setBrake = function(____, on) -- 683
			brakeOn = on -- 684
			paintBrake() -- 685
		end, -- 683
		onAimReady = function(____, callback) -- 687
			readyHandler = callback -- 688
		end, -- 687
		onObserve = function(____, callback) -- 690
			observeHandler = callback -- 691
		end, -- 690
		onZoom = function(____, callback) -- 693
			zoomHandler = callback -- 694
		end, -- 693
		onLaunch = function(____, callback) -- 696
			launchHandler = callback -- 697
		end, -- 696
		setArmed = function(____, armed) -- 699
			launchButton.root.visible = armed -- 700
			launchButton:setEnabled(armed) -- 701
		end, -- 699
		onViewToggle = function(____, callback) -- 703
			viewHandler = callback -- 704
		end, -- 703
		setViewMode = function(____, mode) -- 706
			if mode == lastViewText then -- 706
				return -- 707
			end -- 707
			lastViewText = mode -- 708
			viewButton:setText(mode) -- 709
		end, -- 706
		onPlayback = function(____, callback) -- 711
			playbackHandler = callback -- 712
		end, -- 711
		setPlayback = function(____, speed) -- 714
			if speed == playbackSpeed then -- 714
				return -- 715
			end -- 715
			playbackSpeed = speed -- 716
			paintPlayback() -- 717
		end, -- 714
		setPlaybackVisible = function(____, on) -- 719
			if on == playbackVisible then -- 719
				return -- 720
			end -- 720
			playbackVisible = on -- 721
			for ____, b in ipairs(playbackButtons) do -- 722
				b.root.visible = on -- 723
				b:setEnabled(on) -- 724
			end -- 724
		end, -- 719
		setFullScreenAim = function(____, on) -- 727
			fullScreenAim = on -- 728
		end, -- 727
		onWarp = function(____, callback) -- 730
			warpHandler = callback -- 731
		end, -- 730
		setDate = function(____, t0, span) -- 733
			dateSpan = span > 0 and span or 0 -- 734
			applyWarpState() -- 735
			local on = dateSpan > 0 -- 736
			local text = on and (("发射日期 " .. __TS__NumberToFixed(t0, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0) or "发射日期" -- 737
			if text ~= lastDateText then -- 737
				lastDateText = text -- 739
				setLabelText(dateLabel, text) -- 740
			end -- 740
		end, -- 733
		setTimeEnabled = function(____, on) -- 743
			if warpAllowed == on then -- 743
				return -- 744
			end -- 744
			warpAllowed = on -- 745
			applyWarpState() -- 746
		end, -- 743
		update = function(____, dt) -- 748
			if not warpOn or warpHoldDir == 0 then -- 748
				return -- 749
			end -- 749
			warpRepeatIn = warpRepeatIn - dt -- 750
			if warpRepeatIn > 0 then -- 750
				return -- 751
			end -- 751
			warpRepeatIn = TimeWarpStep / TimeWarpRate -- 753
			if warpHandler ~= nil then -- 753
				warpHandler(warpHoldDir) -- 754
			end -- 754
		end, -- 748
		isDragging = function() return dragging end, -- 756
		setBurnInfo = function(____, burn, budget) -- 757
			setLabelText( -- 758
				dvLabel, -- 758
				(("Δv " .. __TS__NumberToFixed(burn, 1)) .. " / ") .. __TS__NumberToFixed(budget, 0) -- 758
			) -- 758
		end, -- 757
		current = function() return aim end, -- 760
		setProbeOffset = function(____, offset) -- 761
			probeOffset = offset -- 762
		end, -- 761
		handleLocal = function(____, ____local) -- 766
			handleDelta(____exports.localToOffset(____local, space)) -- 767
		end, -- 766
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 770
		debugProbeOffset = function() return probeOffset end, -- 771
		root = root -- 772
	} -- 772
end -- 291
local ResultBackdropHex = 329484 -- 789
local ResultCardHex = 1252395 -- 790
local ResultCardBorderHex = 3362938 -- 791
local ResultLevelHex = 9417948 -- 792
local ResultBodyHex = 14149367 -- 793
ResultHintHex = 8229803 -- 794
ResultButtonBgHex = 1919610 -- 795
ResultButtonAltBgHex = 1779509 -- 796
ResultButtonFgHex = 15398143 -- 797
ResultButtonBorderHex = 5211846 -- 798
local TitleSuccessHex = 8381344 -- 799
local TitleMissedHex = 16766073 -- 800
local TitleCrashedHex = 16743019 -- 801
local SelectBackdropHex = 329484 -- 803
local SelectTitleHex = 16777215 -- 804
local SelectSubtitleHex = 10470632 -- 805
local SelectHintHex = 7309478 -- 806
local SelectOpenBgHex = 1919610 -- 807
local SelectOpenFgHex = 15398143 -- 808
local SelectLockedBgHex = 1383204 -- 809
local SelectLockedFgHex = 6912140 -- 810
local SelectBorderHex = 4157096 -- 811
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 814
	if value < lo then -- 814
		return lo -- 815
	end -- 815
	if value > hi then -- 815
		return hi -- 816
	end -- 816
	return value -- 817
end -- 814
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 821
	if result == "success" then -- 821
		return "借力成功" -- 822
	end -- 822
	if result == "crashed" then -- 822
		return "信号中断" -- 823
	end -- 823
	return "错过目标" -- 824
end -- 821
--- 三态说明句（逐字）。
local function resultBody(result) -- 828
	if result == "success" then -- 828
		return "行星把探测器甩了出去，速度够了。" -- 829
	end -- 829
	if result == "crashed" then -- 829
		return "探测器撞上行星，任务到此为止。" -- 830
	end -- 830
	return "从行星身侧掠过，没能借到那一点速度。" -- 831
end -- 828
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 835
	if result == "success" then -- 835
		return TitleSuccessHex -- 836
	end -- 836
	if result == "crashed" then -- 836
		return TitleCrashedHex -- 837
	end -- 837
	return TitleMissedHex -- 838
end -- 835
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 847
	if result == "success" then -- 847
		return "下一关已解锁" -- 848
	end -- 848
	return "可重试本关，或返回关卡选择" -- 849
end -- 847
--- 建结算面板：半透明全屏底 + 居中卡片（宽 = 0.88 × 视宽）+ 4 行内容 + 2 个按钮。
-- 
-- ⚠️ 全屏底**不能**设 `touch: true`（真机验收踩到的坑）：
-- 全屏 + `swallowTouches` 的节点会独占它覆盖范围内的点击，而节点树里它排在瞄准层之前；
-- 只要它存在，进入关卡后怎么拖都没反应（表现为“进关卡不能拖动飞行器”）。
-- 不需要它吞点击：结算态瞄准层本来就已 `setEnabled(false)`（Flying 起就关），
-- 能点的只有卡片里那两个按钮。
-- 
-- @param viewW 视图逻辑宽（`View.size.width`）
-- @param viewH 视图逻辑高
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 878
	local root = createPanel( -- 884
		parent, -- 884
		viewW, -- 884
		viewH, -- 884
		ResultBackdropHex, -- 884
		{alpha = 0.78} -- 884
	) -- 884
	local cardW = viewW * 0.88 -- 889
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 900) -- 890
	local btnH = clampNumber(viewH * 0.13, MinButtonHeight, 150) -- 891
	local padX = (cardW - btnW) / 2 -- 892
	local padY = 44 -- 893
	local fontLevel = 34 -- 895
	local fontTitle = 66 -- 896
	local fontBody = 34 -- 897
	local fontHint = 30 -- 898
	local btnFont = 40 -- 899
	local rowGap = 26 -- 900
	local hLevel = fontLevel + 10 -- 903
	local hTitle = fontTitle + 18 -- 904
	local hBody = fontBody * 2 + 12 -- 905
	local hHint = fontHint + 10 -- 906
	local cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 907
	if cardH > viewH - 24 then -- 907
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 910
		cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 911
	end -- 911
	local card = createPanel( -- 914
		root, -- 914
		cardW, -- 914
		cardH, -- 914
		ResultCardHex, -- 914
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 914
	) -- 914
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 919
	local cursor = cardH - padY -- 922
	cursor = cursor - hLevel -- 924
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 925
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 926
	cursor = cursor - (rowGap + hTitle) -- 928
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 929
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 930
	cursor = cursor - (rowGap + hBody) -- 932
	local bodyLabel = createLabel(card, "", fontBody, ResultBodyHex) -- 933
	setLabelCenter(bodyLabel, cardW / 2, cursor + hBody / 2) -- 934
	if bodyLabel ~= nil then -- 934
		bodyLabel.textWidth = cardW - 80 -- 935
	end -- 935
	cursor = cursor - (rowGap + hHint) -- 937
	local hintLabel = createLabel(card, "", fontHint, ResultHintHex) -- 938
	setLabelCenter(hintLabel, cardW / 2, cursor + hHint / 2) -- 939
	cursor = cursor - (rowGap + btnH) -- 942
	local retryButton = createButton(card, { -- 943
		w = btnW, -- 944
		h = btnH, -- 945
		text = "重试本关", -- 946
		fontSize = btnFont, -- 947
		bgHex = ResultButtonBgHex, -- 948
		fgHex = ResultButtonFgHex, -- 949
		borderHex = ResultButtonBorderHex, -- 950
		fireOn = "press", -- 951
		onTap = opts.onRetry -- 952
	}) -- 952
	retryButton.root.position = Vec2(padX, cursor) -- 954
	cursor = cursor - (22 + btnH) -- 956
	local backButton = createButton(card, { -- 957
		w = btnW, -- 958
		h = btnH, -- 959
		text = "返回关卡选择", -- 960
		fontSize = btnFont, -- 961
		bgHex = ResultButtonAltBgHex, -- 962
		fgHex = ResultButtonFgHex, -- 963
		borderHex = ResultButtonBorderHex, -- 964
		fireOn = "press", -- 965
		onTap = opts.onBackToSelect -- 966
	}) -- 966
	backButton.root.position = Vec2(padX, cursor) -- 968
	root.visible = false -- 970
	retryButton:setEnabled(false) -- 973
	backButton:setEnabled(false) -- 974
	return { -- 976
		root = root, -- 977
		show = function(____, result, levelName) -- 978
			retryButton:setEnabled(true) -- 980
			backButton:setEnabled(true) -- 981
			setLabelText(levelLabel, levelName) -- 982
			setLabelText( -- 983
				titleLabel, -- 983
				resultTitle(result) -- 983
			) -- 983
			setLabelColor( -- 984
				titleLabel, -- 984
				resultTitleColor(result) -- 984
			) -- 984
			setLabelText( -- 985
				bodyLabel, -- 985
				resultBody(result) -- 985
			) -- 985
			setLabelText( -- 986
				hintLabel, -- 986
				resultHint(result) -- 986
			) -- 986
			root.visible = true -- 987
		end, -- 978
		hide = function() -- 989
			root.visible = false -- 990
			retryButton:setEnabled(false) -- 993
			backButton:setEnabled(false) -- 994
		end -- 989
	} -- 989
end -- 878
--- 建关卡选择：标题 + 副标题 + 六关竖排按钮 + 底部提示。
-- 
-- 未解锁的按钮**整块不可点**（`setEnabled(false)` 会关掉 `touchEnabled`）——
-- 只在回调里判断“锁了就 return”是不够的：那样按钮仍会吞掉触摸，
-- 表现为“点了没反应”，玩家分不清是坏了还是锁着。
-- 
-- ⚠️ 全屏底**不设** `touch: true`：全屏 + `swallowTouches` 会独占整屏点击，
-- 而它在节点树里排在瞄准层之前 —— 隐藏后若仍参与命中，进入关卡就再也拖不动
-- （真机验收即为此症状）。选关期间没有任何关卡处于 Aiming，瞄准层本就关着，
-- 不需要全屏底代劳；能点的只有这六个按钮。
-- 
-- @param viewW 视图逻辑宽
-- @param viewH 视图逻辑高
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 1034
	local root = createPanel( -- 1040
		parent, -- 1040
		viewW, -- 1040
		viewH, -- 1040
		SelectBackdropHex, -- 1040
		{alpha = 0.9} -- 1040
	) -- 1040
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 1042
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 1043
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 1045
	setLabelCenter( -- 1046
		subtitleLabel, -- 1046
		viewW / 2, -- 1046
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 1046
	) -- 1046
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 1048
	setLabelCenter( -- 1049
		hintLabel, -- 1049
		viewW / 2, -- 1049
		clampNumber(viewH * 0.045, 36, 90) -- 1049
	) -- 1049
	local count = #opts.levels -- 1051
	local cols = viewH > viewW and 2 or 1 -- 1054
	local rows = math.max( -- 1055
		1, -- 1055
		math.ceil(count / cols) -- 1055
	) -- 1055
	local gap = 18 -- 1056
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 1057
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 1058
	local availW = viewW * 0.84 -- 1059
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 1060
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 1061
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 1062
	local gridW = cols * btnW + gap * (cols - 1) -- 1063
	local topY = viewH - headerH -- 1064
	local buttons = {} -- 1066
	do -- 1066
		local i = 0 -- 1067
		while i < count do -- 1067
			local index = i -- 1069
			local button = createButton( -- 1070
				root, -- 1070
				{ -- 1070
					w = btnW, -- 1071
					h = btnH, -- 1072
					text = opts.levels[index + 1].name, -- 1073
					fontSize = 38, -- 1074
					bgHex = SelectLockedBgHex, -- 1075
					fgHex = SelectLockedFgHex, -- 1076
					borderHex = SelectBorderHex, -- 1077
					fireOn = "press", -- 1079
					onTap = function() return opts:onPick(index) end -- 1080
				} -- 1080
			) -- 1080
			local col = index % cols -- 1082
			local rowIndex = math.floor(index / cols) -- 1083
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 1084
			buttons[#buttons + 1] = button -- 1088
			i = i + 1 -- 1067
		end -- 1067
	end -- 1067
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 1094
		root, -- 1095
		{ -- 1095
			w = clampNumber(viewW * 0.36, 180, 300), -- 1096
			h = MinButtonHeight, -- 1097
			text = "重看开场", -- 1098
			fontSize = 30, -- 1099
			bgHex = SelectLockedBgHex, -- 1100
			fgHex = SelectSubtitleHex, -- 1101
			borderHex = SelectBorderHex, -- 1102
			fireOn = "press", -- 1103
			onTap = function() -- 1104
				if opts.onReplayIntro ~= nil then -- 1104
					opts:onReplayIntro() -- 1105
				end -- 1105
			end -- 1104
		} -- 1104
	) or nil -- 1104
	if replayButton ~= nil then -- 1104
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 1110
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 1111
		replayButton.root.position = Vec2( -- 1112
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 1112
			by -- 1112
		) -- 1112
	end -- 1112
	root.visible = false -- 1115
	do -- 1115
		local i = 0 -- 1116
		while i < count do -- 1116
			buttons[i + 1]:setEnabled(false) -- 1116
			i = i + 1 -- 1116
		end -- 1116
	end -- 1116
	if replayButton ~= nil then -- 1116
		replayButton:setEnabled(false) -- 1117
	end -- 1117
	return { -- 1119
		root = root, -- 1120
		show = function(____, unlocked) -- 1121
			local maxUnlocked = clampNumber( -- 1122
				math.floor(unlocked), -- 1122
				0, -- 1122
				count - 1 -- 1122
			) -- 1122
			setLabelText( -- 1123
				subtitleLabel, -- 1123
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 1123
			) -- 1123
			do -- 1123
				local i = 0 -- 1124
				while i < count do -- 1124
					local button = buttons[i + 1] -- 1125
					local open = i <= maxUnlocked -- 1126
					button:setEnabled(open) -- 1127
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 1128
					if open then -- 1128
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 1129
					else -- 1129
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 1130
					end -- 1130
					i = i + 1 -- 1124
				end -- 1124
			end -- 1124
			root.visible = true -- 1132
			if replayButton ~= nil then -- 1132
				replayButton:setEnabled(true) -- 1133
			end -- 1133
		end, -- 1121
		hide = function() -- 1135
			root.visible = false -- 1136
			do -- 1136
				local i = 0 -- 1138
				while i < count do -- 1138
					buttons[i + 1]:setEnabled(false) -- 1138
					i = i + 1 -- 1138
				end -- 1138
			end -- 1138
			if replayButton ~= nil then -- 1138
				replayButton:setEnabled(false) -- 1139
			end -- 1139
		end -- 1135
	} -- 1135
end -- 1034
return ____exports -- 1034