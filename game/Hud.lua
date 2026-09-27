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
function ____exports.computeAim(probeOffset, touchOffset, maxDragPx, maxSpeed, minSpeed) -- 71
	local speedMin = minSpeed ~= nil and minSpeed >= 0 and minSpeed < (maxSpeed ~= nil and maxSpeed or AimMaxSpeed) and minSpeed or AimMinSpeed -- 80
	local speedTop = maxSpeed ~= nil and maxSpeed > speedMin and maxSpeed or AimMaxSpeed -- 82
	local dx = touchOffset.x - probeOffset.x -- 87
	local dy = touchOffset.y - probeOffset.y -- 88
	local len = math.sqrt(dx * dx + dy * dy) -- 90
	if len < 0.000001 then -- 90
		return {velocity = {x = 0, y = -speedMin}, power = 0, unit = {x = 0, y = -1}} -- 93
	end -- 93
	local ux = dx / len -- 96
	local uy = -dy / len -- 101
	local safeMax = maxDragPx > 1 and maxDragPx or 1 -- 103
	local power = len / safeMax -- 104
	if power < 0 then -- 104
		power = 0 -- 105
	end -- 105
	if power > 1 then -- 105
		power = 1 -- 106
	end -- 106
	local speed = speedMin + (speedTop - speedMin) * power -- 108
	return {velocity = {x = ux * speed, y = uy * speed}, power = power, unit = {x = ux, y = uy}} -- 110
end -- 71
--- 把屏幕位置（**投影偏移空间**，与 `project()` 同空间）转成平面坐标。
-- 
-- 不是矄准必需（矄准只用方向），但调试与关卡设计时有用。
-- 与 `project()` 互逆（已有往返测试守着）。
function ____exports.screenToPlane(viewPoint, basis) -- 123
	local world = screenToPlaneY(viewPoint, basis, 0) -- 127
	if world == nil then -- 127
		return nil -- 128
	end -- 128
	return {x = world.x / PlaneToWorldX, y = world.z / PlaneToWorldZ} -- 130
end -- 123
--- 倍速按钮上的文字。
-- 
-- ⚠️ 不能一律 `toFixed(0)`：0.05× 会显示成「0×」（S5 的 L1 就是 0.02/0.05/0.1 三档）。
function ____exports.playbackLabel(speed) -- 138
	if speed >= 1 then -- 138
		return __TS__NumberToFixed(speed, 0) .. "×" -- 139
	end -- 139
	if speed >= 0.1 then -- 139
		return __TS__NumberToFixed(speed, 1) .. "×" -- 140
	end -- 140
	return __TS__NumberToFixed(speed, 2) .. "×" -- 141
end -- 138
--- 默认的力度→拖动像素映射（供 UI 层统一引用）。
function ____exports.defaultMaxDragPx() -- 145
	return AimMaxDragPx -- 146
end -- 145
--- 默认速度区间（供 UI 层展示）。
function ____exports.defaultSpeedRange() -- 150
	return {min = AimMinSpeed, max = AimMaxSpeed} -- 151
end -- 150
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
function ____exports.localToOffset(____local, space) -- 172
	return {x = ____local.x - space.viewW / 2, y = ____local.y - space.viewH / 2} -- 173
end -- 172
--- 反向换算（投影偏移空间 → 全屏节点局部坐标）。
function ____exports.offsetToLocal(offset, space) -- 177
	return {x = offset.x + space.viewW / 2, y = offset.y + space.viewH / 2} -- 178
end -- 177
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
function ____exports.createAimInput(parent, viewW, viewH, maxSpeed, minSpeed, speedChoices) -- 307
	local brakeOn, paintBrake, datePlate, dateLabel -- 307
	local speedMin = minSpeed ~= nil and minSpeed >= 0 and minSpeed < (maxSpeed ~= nil and maxSpeed or AimMaxSpeed) and minSpeed or AimMinSpeed -- 318
	local speedTop = maxSpeed ~= nil and maxSpeed > speedMin and maxSpeed or AimMaxSpeed -- 320
	local root = Node() -- 321
	root.size = Size(viewW, viewH) -- 322
	root.anchor = Vec2(0, 0) -- 328
	root.position = Vec2(0, 0) -- 329
	local touchLayer = Node() -- 332
	touchLayer.size = Size(viewW, viewH) -- 333
	touchLayer.anchor = Vec2(0.5, 0.5) -- 334
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 335
	touchLayer.swallowTouches = true -- 336
	root:addChild(touchLayer) -- 337
	local space = {viewW = viewW, viewH = viewH} -- 339
	local enabled = false -- 341
	local dragging = false -- 342
	--- 整屏瞄准（2D 模式）；由 Game 按视图状态同步。
	local fullScreenAim = false -- 344
	local aim = {velocity = {x = 0, y = -speedMin}, power = 0, unit = {x = 0, y = -1}} -- 345
	local probeOffset = {x = 0, y = 0} -- 348
	local dragHandler = nil -- 350
	local readyHandler = nil -- 351
	local observeHandler = nil -- 352
	local zoomHandler = nil -- 353
	local launchHandler = nil -- 354
	local pressOffset = {x = 0, y = 0} -- 365
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 368
		aim = ____exports.computeAim( -- 369
			{x = 0, y = 0}, -- 369
			delta, -- 369
			AimMaxDragPx, -- 369
			speedTop, -- 369
			speedMin -- 369
		) -- 369
		if dragHandler ~= nil then -- 369
			dragHandler(aim) -- 370
		end -- 370
	end -- 368
	local aimRadius = math.max(96, viewW * 0.25) -- 377
	local mode = "none" -- 378
	local observeLast = {x = 0, y = 0} -- 379
	touchLayer:onTapBegan(function(touch) -- 380
		if not enabled then -- 380
			return -- 381
		end -- 381
		local at = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 382
		local dx = at.x - probeOffset.x -- 383
		local dy = at.y - probeOffset.y -- 384
		if fullScreenAim or math.sqrt(dx * dx + dy * dy) <= aimRadius then -- 384
			mode = "aim" -- 386
			dragging = true -- 387
			pressOffset = at -- 388
			handleDelta({x = 0, y = 0}) -- 390
		else -- 390
			mode = "observe" -- 392
			observeLast = at -- 393
		end -- 393
	end) -- 380
	touchLayer:onTapMoved(function(touch) -- 397
		if not enabled then -- 397
			return -- 398
		end -- 398
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 399
		if mode == "aim" and dragging then -- 399
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 401
		elseif mode == "observe" then -- 401
			if observeHandler ~= nil then -- 401
				observeHandler(cur.x - observeLast.x, cur.y - observeLast.y) -- 404
			end -- 404
			observeLast = cur -- 405
		end -- 405
	end) -- 397
	touchLayer:onTapEnded(function(touch) -- 409
		if not enabled then -- 409
			return -- 410
		end -- 410
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 411
		if mode == "aim" then -- 411
			dragging = false -- 413
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 414
			if readyHandler ~= nil then -- 414
				readyHandler(aim) -- 416
			end -- 416
		end -- 416
		mode = "none" -- 418
	end) -- 409
	touchLayer:onGesture(function(_center, numFingers, deltaDist, _deltaAngle) -- 422
		if not enabled or numFingers < 2 then -- 422
			return -- 423
		end -- 423
		if zoomHandler ~= nil then -- 423
			zoomHandler(deltaDist) -- 424
		end -- 424
	end) -- 422
	touchLayer.touchEnabled = false -- 432
	local brakeHandler = nil -- 437
	local BrakeButtonW = 116 -- 438
	local BrakeButtonH = 64 -- 439
	local brakeGap = 8 -- 440
	local brakeButtons = {} -- 444
	local function makeBrakeButton(text, on, x) -- 445
		local btn = createButton( -- 446
			root, -- 446
			{ -- 446
				w = BrakeButtonW, -- 447
				h = BrakeButtonH, -- 448
				text = text, -- 449
				fontSize = 30, -- 450
				bgHex = ResultButtonAltBgHex, -- 451
				fgHex = ResultButtonFgHex, -- 452
				borderHex = ResultButtonBorderHex, -- 453
				onTap = function() -- 454
					brakeOn = on -- 457
					paintBrake() -- 458
					if brakeHandler ~= nil then -- 458
						brakeHandler(on) -- 459
					end -- 459
				end -- 454
			} -- 454
		) -- 454
		btn.root.position = Vec2(x, viewH - BrakeButtonH - 20) -- 462
		brakeButtons[#brakeButtons + 1] = btn -- 463
	end -- 445
	brakeOn = false -- 465
	paintBrake = function() -- 466
		if #brakeButtons < 2 then -- 466
			return -- 467
		end -- 467
		brakeButtons[1]:setColors(brakeOn and ResultButtonAltBgHex or ResultButtonBgHex, ResultButtonFgHex) -- 468
		brakeButtons[2]:setColors(brakeOn and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 469
	end -- 466
	createPanel( -- 475
		root, -- 475
		220, -- 475
		50, -- 475
		658964, -- 475
		{alpha = 0.45} -- 475
	) -- 475
	local dvLabel = createLabel(root, "Δv — / —", 30, ResultHintHex) -- 476
	if dvLabel ~= nil then -- 476
		dvLabel.position = Vec2(24, viewH - 44) -- 478
		dvLabel.anchor = Vec2(0, 0) -- 479
	end -- 479
	local warpHandler = nil -- 489
	local dateSpan = 0 -- 490
	--- 这一关有时间轴**且**当前相态允许改日期（Flying/Result 时必须是 false）。
	local warpOn = true -- 497
	local warpVisible = true -- 498
	--- 相态是否允许改日期（由主循环每帧 setTimeEnabled 同步）。
	local warpAllowed = true -- 500
	--- 上次写进日期的文字（避免每帧重设 Label 文本）。
	local lastDateText = "" -- 502
	--- >0 = 正在按住这个方向（-1 回退 / +1 加速）；0 = 没按住。
	local warpHoldDir = 0 -- 504
	--- 距离下一次连按还有多久（秒）。
	local warpRepeatIn = 0 -- 506
	local WarpButtonW = 116 -- 507
	local WarpButtonH = 64 -- 508
	local warpButtons = {} -- 509
	local function applyWarpState() -- 510
		local vis = dateSpan > 0 -- 511
		local on = vis and warpAllowed -- 512
		if vis == warpVisible and on == warpOn then -- 512
			return -- 513
		end -- 513
		warpVisible = vis -- 514
		warpOn = on -- 515
		if not on then -- 515
			warpHoldDir = 0 -- 516
		end -- 516
		for ____, b in ipairs(warpButtons) do -- 517
			b.root.visible = vis -- 518
			b:setEnabled(on) -- 519
		end -- 519
		if dateLabel ~= nil then -- 519
			dateLabel.visible = vis -- 521
		end -- 521
		datePlate.visible = vis -- 522
	end -- 510
	local function makeWarpButton(text, dir, x) -- 524
		local btn = createButton( -- 525
			root, -- 525
			{ -- 525
				w = WarpButtonW, -- 526
				h = WarpButtonH, -- 527
				text = text, -- 528
				fontSize = 30, -- 529
				bgHex = ResultButtonAltBgHex, -- 530
				fgHex = ResultButtonFgHex, -- 531
				borderHex = ResultButtonBorderHex, -- 532
				onTap = function() -- 535
				end, -- 535
				onPressBegan = function() -- 536
					print((("[escape-velocity] warp press dir=" .. __TS__NumberToFixed(dir, 0)) .. " on=") .. (warpOn and "1" or "0")) -- 538
					if not warpOn then -- 538
						return -- 539
					end -- 539
					if warpHoldDir == dir then -- 539
						return -- 541
					end -- 541
					warpHoldDir = dir -- 542
					warpRepeatIn = WarpHoldDelaySec -- 543
					if warpHandler ~= nil then -- 543
						warpHandler(dir) -- 544
					end -- 544
				end, -- 536
				onPressEnded = function() -- 546
					print((("[escape-velocity] warp release dir=" .. __TS__NumberToFixed(dir, 0)) .. " hold=") .. __TS__NumberToFixed(warpHoldDir, 0)) -- 547
					if warpHoldDir == dir then -- 547
						warpHoldDir = 0 -- 549
					end -- 549
				end -- 546
			} -- 546
		) -- 546
		btn.root.position = Vec2(x, viewH - 96 - WarpButtonH) -- 555
		warpButtons[#warpButtons + 1] = btn -- 556
	end -- 524
	local warpLeftX = viewW - (WarpButtonW * 2 + 8) - 20 -- 558
	makeWarpButton("◀ 回退", -1, warpLeftX) -- 559
	makeWarpButton("加速 ▶", 1, warpLeftX + WarpButtonW + 8) -- 560
	datePlate = createPanel( -- 562
		root, -- 562
		300, -- 562
		50, -- 562
		658964, -- 562
		{alpha = 0.45} -- 562
	) -- 562
	datePlate.position = Vec2(warpLeftX - 316, viewH - 96 - WarpButtonH + 8) -- 563
	dateLabel = createLabel(root, "发射日期 —", 30, ResultHintHex) -- 564
	if dateLabel ~= nil then -- 564
		dateLabel.anchor = Vec2(1, 0) -- 569
		dateLabel.position = Vec2(warpLeftX - 16, viewH - 96 - WarpButtonH + 18) -- 570
	end -- 570
	local LaunchButtonW = 220 -- 577
	local LaunchButtonH = 112 -- 578
	local launchButton = createButton( -- 579
		root, -- 579
		{ -- 579
			w = LaunchButtonW, -- 580
			h = LaunchButtonH, -- 581
			text = "发射", -- 582
			fontSize = 44, -- 583
			bgHex = ResultButtonBgHex, -- 584
			fgHex = ResultButtonFgHex, -- 585
			borderHex = ResultButtonBorderHex, -- 586
			fireOn = "press", -- 587
			onTap = function() -- 588
				print("[escape-velocity] launch button fire (press)") -- 590
				if launchHandler ~= nil then -- 590
					launchHandler() -- 591
				end -- 591
			end -- 588
		} -- 588
	) -- 588
	launchButton.root.position = Vec2(viewW - LaunchButtonW - 24, 96) -- 594
	launchButton.root.visible = false -- 595
	launchButton:setEnabled(false) -- 596
	local ViewButtonW = 116 -- 604
	local ViewButtonH = 64 -- 605
	local viewHandler = nil -- 606
	local viewButton = createButton( -- 607
		root, -- 607
		{ -- 607
			w = ViewButtonW, -- 608
			h = ViewButtonH, -- 609
			text = "2D", -- 610
			fontSize = 30, -- 611
			bgHex = ResultButtonAltBgHex, -- 612
			fgHex = ResultButtonFgHex, -- 613
			borderHex = ResultButtonBorderHex, -- 614
			fireOn = "press", -- 616
			onTap = function() -- 617
				print("[escape-velocity] view toggle fire (press)") -- 618
				if viewHandler ~= nil then -- 618
					viewHandler() -- 619
				end -- 619
			end -- 617
		} -- 617
	) -- 617
	viewButton.root.position = Vec2(viewW - ViewButtonW - 24, 96 + LaunchButtonH + 12) -- 625
	--- 上次写进按钮的文字（每帧都会被 setViewMode 调用，没变就别碰 Label）。
	local lastViewText = "2D" -- 627
	local PlaybackButtonW = 116 -- 636
	local PlaybackButtonH = 64 -- 637
	local playbackGap = 10 -- 638
	local playbackButtons = {} -- 639
	local playbackSpeeds = {} -- 640
	local playbackHandler = nil -- 641
	local speedChoice = speedChoices ~= nil and #speedChoices > 0 and speedChoices or ({1, 2, 4}) -- 644
	local playbackSpeed = speedChoice[1] -- 645
	--- 已应用到节点上的显隐状态。初值 false 如实反映"建出来就隐藏"（照 warp 按钮的教训）。
	local playbackVisible = false -- 647
	local function paintPlayback() -- 648
		do -- 648
			local i = 0 -- 649
			while i < #playbackButtons do -- 649
				local on = playbackSpeeds[i + 1] == playbackSpeed -- 650
				playbackButtons[i + 1]:setColors(on and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 651
				i = i + 1 -- 649
			end -- 649
		end -- 649
	end -- 648
	local function makePlaybackButton(speed, x) -- 654
		local btn = createButton( -- 655
			root, -- 655
			{ -- 655
				w = PlaybackButtonW, -- 656
				h = PlaybackButtonH, -- 657
				text = ____exports.playbackLabel(speed), -- 658
				fontSize = 30, -- 659
				bgHex = ResultButtonAltBgHex, -- 660
				fgHex = ResultButtonFgHex, -- 661
				borderHex = ResultButtonBorderHex, -- 662
				onTap = function() -- 663
					print(("[escape-velocity] playback button fire " .. __TS__NumberToFixed(speed, 0)) .. "x (release)") -- 665
					playbackSpeed = speed -- 666
					paintPlayback() -- 667
					if playbackHandler ~= nil then -- 667
						playbackHandler(speed) -- 668
					end -- 668
				end -- 663
			} -- 663
		) -- 663
		btn.root.position = Vec2(x, 96) -- 673
		playbackButtons[#playbackButtons + 1] = btn -- 674
		playbackSpeeds[#playbackSpeeds + 1] = speed -- 675
	end -- 654
	do -- 654
		local i = 0 -- 677
		while i < #speedChoice and i < 3 do -- 677
			makePlaybackButton(speedChoice[i + 1], 24 + (PlaybackButtonW + playbackGap) * i) -- 678
			i = i + 1 -- 677
		end -- 677
	end -- 677
	paintPlayback() -- 680
	for ____, b in ipairs(playbackButtons) do -- 682
		b.root.visible = false -- 683
		b:setEnabled(false) -- 684
	end -- 684
	local brakeRightX = viewW - BrakeButtonW - 20 -- 687
	makeBrakeButton("惯性", false, brakeRightX - BrakeButtonW - brakeGap) -- 688
	makeBrakeButton("刹车", true, brakeRightX) -- 689
	paintBrake() -- 690
	parent:addChild(root) -- 692
	return { -- 694
		onDrag = function(____, callback) -- 695
			dragHandler = callback -- 696
		end, -- 695
		setEnabled = function(____, value) -- 698
			enabled = value -- 699
			touchLayer.touchEnabled = value -- 702
			if not value then -- 702
				dragging = false -- 703
			end -- 703
		end, -- 698
		onBrake = function(____, callback) -- 705
			brakeHandler = callback -- 706
		end, -- 705
		setBrake = function(____, on) -- 708
			brakeOn = on -- 709
			paintBrake() -- 710
		end, -- 708
		onAimReady = function(____, callback) -- 712
			readyHandler = callback -- 713
		end, -- 712
		onObserve = function(____, callback) -- 715
			observeHandler = callback -- 716
		end, -- 715
		onZoom = function(____, callback) -- 718
			zoomHandler = callback -- 719
		end, -- 718
		onLaunch = function(____, callback) -- 721
			launchHandler = callback -- 722
		end, -- 721
		setArmed = function(____, armed) -- 724
			launchButton.root.visible = armed -- 725
			launchButton:setEnabled(armed) -- 726
		end, -- 724
		onViewToggle = function(____, callback) -- 728
			viewHandler = callback -- 729
		end, -- 728
		setViewMode = function(____, mode) -- 731
			if mode == lastViewText then -- 731
				return -- 732
			end -- 732
			lastViewText = mode -- 733
			viewButton:setText(mode) -- 734
		end, -- 731
		onPlayback = function(____, callback) -- 736
			playbackHandler = callback -- 737
		end, -- 736
		setPlayback = function(____, speed) -- 739
			if speed == playbackSpeed then -- 739
				return -- 740
			end -- 740
			playbackSpeed = speed -- 741
			paintPlayback() -- 742
		end, -- 739
		setPlaybackVisible = function(____, on) -- 744
			if on == playbackVisible then -- 744
				return -- 745
			end -- 745
			playbackVisible = on -- 746
			for ____, b in ipairs(playbackButtons) do -- 747
				b.root.visible = on -- 748
				b:setEnabled(on) -- 749
			end -- 749
		end, -- 744
		setFullScreenAim = function(____, on) -- 752
			fullScreenAim = on -- 753
		end, -- 752
		onWarp = function(____, callback) -- 755
			warpHandler = callback -- 756
		end, -- 755
		setDate = function(____, t0, span) -- 758
			dateSpan = span > 0 and span or 0 -- 759
			applyWarpState() -- 760
			local on = dateSpan > 0 -- 761
			local text = on and (("发射日期 " .. __TS__NumberToFixed(t0, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0) or "发射日期" -- 762
			if text ~= lastDateText then -- 762
				lastDateText = text -- 764
				setLabelText(dateLabel, text) -- 765
			end -- 765
		end, -- 758
		setTimeEnabled = function(____, on) -- 768
			if warpAllowed == on then -- 768
				return -- 769
			end -- 769
			warpAllowed = on -- 770
			applyWarpState() -- 771
		end, -- 768
		update = function(____, dt) -- 773
			if not warpOn or warpHoldDir == 0 then -- 773
				return -- 774
			end -- 774
			warpRepeatIn = warpRepeatIn - dt -- 775
			if warpRepeatIn > 0 then -- 775
				return -- 776
			end -- 776
			warpRepeatIn = TimeWarpStep / TimeWarpRate -- 778
			if warpHandler ~= nil then -- 778
				warpHandler(warpHoldDir) -- 779
			end -- 779
		end, -- 773
		isDragging = function() return dragging end, -- 781
		setBurnInfo = function(____, burn, budget) -- 782
			setLabelText( -- 783
				dvLabel, -- 783
				(("Δv " .. __TS__NumberToFixed(burn, 1)) .. " / ") .. __TS__NumberToFixed(budget, 0) -- 783
			) -- 783
		end, -- 782
		current = function() return aim end, -- 785
		setProbeOffset = function(____, offset) -- 786
			probeOffset = offset -- 787
		end, -- 786
		handleLocal = function(____, ____local) -- 791
			handleDelta(____exports.localToOffset(____local, space)) -- 792
		end, -- 791
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 795
		debugProbeOffset = function() return probeOffset end, -- 796
		root = root -- 797
	} -- 797
end -- 307
local ResultBackdropHex = 329484 -- 814
local ResultCardHex = 1252395 -- 815
local ResultCardBorderHex = 3362938 -- 816
local ResultLevelHex = 9417948 -- 817
local ResultBodyHex = 14149367 -- 818
ResultHintHex = 8229803 -- 819
ResultButtonBgHex = 1919610 -- 820
ResultButtonAltBgHex = 1779509 -- 821
ResultButtonFgHex = 15398143 -- 822
ResultButtonBorderHex = 5211846 -- 823
local TitleSuccessHex = 8381344 -- 824
local TitleMissedHex = 16766073 -- 825
local TitleCrashedHex = 16743019 -- 826
local SelectBackdropHex = 329484 -- 828
local SelectTitleHex = 16777215 -- 829
local SelectSubtitleHex = 10470632 -- 830
local SelectHintHex = 7309478 -- 831
local SelectOpenBgHex = 1919610 -- 832
local SelectOpenFgHex = 15398143 -- 833
local SelectLockedBgHex = 1383204 -- 834
local SelectLockedFgHex = 6912140 -- 835
local SelectBorderHex = 4157096 -- 836
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 839
	if value < lo then -- 839
		return lo -- 840
	end -- 840
	if value > hi then -- 840
		return hi -- 841
	end -- 841
	return value -- 842
end -- 839
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 846
	if result == "success" then -- 846
		return "借力成功" -- 847
	end -- 847
	if result == "crashed" then -- 847
		return "信号中断" -- 848
	end -- 848
	return "错过目标" -- 849
end -- 846
--- 三态说明句（逐字）。
local function resultBody(result) -- 853
	if result == "success" then -- 853
		return "行星把探测器甩了出去，速度够了。" -- 854
	end -- 854
	if result == "crashed" then -- 854
		return "探测器撞上行星，任务到此为止。" -- 855
	end -- 855
	return "从行星身侧掠过，没能借到那一点速度。" -- 856
end -- 853
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 860
	if result == "success" then -- 860
		return TitleSuccessHex -- 861
	end -- 861
	if result == "crashed" then -- 861
		return TitleCrashedHex -- 862
	end -- 862
	return TitleMissedHex -- 863
end -- 860
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 872
	if result == "success" then -- 872
		return "下一关已解锁" -- 873
	end -- 873
	return "可重试本关，或返回关卡选择" -- 874
end -- 872
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 903
	local root = createPanel( -- 909
		parent, -- 909
		viewW, -- 909
		viewH, -- 909
		ResultBackdropHex, -- 909
		{alpha = 0.78} -- 909
	) -- 909
	local cardW = viewW * 0.88 -- 914
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 900) -- 915
	local btnH = clampNumber(viewH * 0.13, MinButtonHeight, 150) -- 916
	local padX = (cardW - btnW) / 2 -- 917
	local padY = 44 -- 918
	local fontLevel = 34 -- 920
	local fontTitle = 66 -- 921
	local fontBody = 34 -- 922
	local fontHint = 30 -- 923
	local btnFont = 40 -- 924
	local rowGap = 26 -- 925
	local hLevel = fontLevel + 10 -- 928
	local hTitle = fontTitle + 18 -- 929
	local hBody = fontBody * 2 + 12 -- 930
	local hHint = fontHint + 10 -- 931
	local cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 932
	if cardH > viewH - 24 then -- 932
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 935
		cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 936
	end -- 936
	local card = createPanel( -- 939
		root, -- 939
		cardW, -- 939
		cardH, -- 939
		ResultCardHex, -- 939
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 939
	) -- 939
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 944
	local cursor = cardH - padY -- 947
	cursor = cursor - hLevel -- 949
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 950
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 951
	cursor = cursor - (rowGap + hTitle) -- 953
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 954
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 955
	cursor = cursor - (rowGap + hBody) -- 957
	local bodyLabel = createLabel(card, "", fontBody, ResultBodyHex) -- 958
	setLabelCenter(bodyLabel, cardW / 2, cursor + hBody / 2) -- 959
	if bodyLabel ~= nil then -- 959
		bodyLabel.textWidth = cardW - 80 -- 960
	end -- 960
	cursor = cursor - (rowGap + hHint) -- 962
	local hintLabel = createLabel(card, "", fontHint, ResultHintHex) -- 963
	setLabelCenter(hintLabel, cardW / 2, cursor + hHint / 2) -- 964
	cursor = cursor - (rowGap + btnH) -- 967
	local retryButton = createButton(card, { -- 968
		w = btnW, -- 969
		h = btnH, -- 970
		text = "重试本关", -- 971
		fontSize = btnFont, -- 972
		bgHex = ResultButtonBgHex, -- 973
		fgHex = ResultButtonFgHex, -- 974
		borderHex = ResultButtonBorderHex, -- 975
		fireOn = "press", -- 976
		onTap = opts.onRetry -- 977
	}) -- 977
	retryButton.root.position = Vec2(padX, cursor) -- 979
	cursor = cursor - (22 + btnH) -- 981
	local backButton = createButton(card, { -- 982
		w = btnW, -- 983
		h = btnH, -- 984
		text = "返回关卡选择", -- 985
		fontSize = btnFont, -- 986
		bgHex = ResultButtonAltBgHex, -- 987
		fgHex = ResultButtonFgHex, -- 988
		borderHex = ResultButtonBorderHex, -- 989
		fireOn = "press", -- 990
		onTap = opts.onBackToSelect -- 991
	}) -- 991
	backButton.root.position = Vec2(padX, cursor) -- 993
	root.visible = false -- 995
	retryButton:setEnabled(false) -- 998
	backButton:setEnabled(false) -- 999
	return { -- 1001
		root = root, -- 1002
		show = function(____, result, levelName) -- 1003
			retryButton:setEnabled(true) -- 1005
			backButton:setEnabled(true) -- 1006
			setLabelText(levelLabel, levelName) -- 1007
			setLabelText( -- 1008
				titleLabel, -- 1008
				resultTitle(result) -- 1008
			) -- 1008
			setLabelColor( -- 1009
				titleLabel, -- 1009
				resultTitleColor(result) -- 1009
			) -- 1009
			setLabelText( -- 1010
				bodyLabel, -- 1010
				resultBody(result) -- 1010
			) -- 1010
			setLabelText( -- 1011
				hintLabel, -- 1011
				resultHint(result) -- 1011
			) -- 1011
			root.visible = true -- 1012
		end, -- 1003
		hide = function() -- 1014
			root.visible = false -- 1015
			retryButton:setEnabled(false) -- 1018
			backButton:setEnabled(false) -- 1019
		end -- 1014
	} -- 1014
end -- 903
local FinaleBackdropHex = 329484 -- 1034
local FinaleMainHex = 15398143 -- 1035
local FinaleSubHex = 10470632 -- 1036
--- 终章主文案（逐字；改之前先改 PLAN S3.18 与 docs/开发手册.md）。
____exports.FinaleMainText = "这就是我们整颗星球的样子 —— 而你已经从那里飞到了这里。" -- 1041
--- 终章小字：飞行距离 / 用时（纯函数，可单测）。
-- 
-- 距离是**平面单位**（关卡尺度，不是公里）—— 别在这里换算成天文单位，
-- 那一换就得把整条注释重写一遍，而玩家要的只是「飞了多远、花了多久」。
function ____exports.finaleSubtitle(distance, time) -- 1049
	return ((("飞行 " .. __TS__NumberToFixed(distance, 0)) .. " 单位 · 用时 ") .. __TS__NumberToFixed(time, 1)) .. " 秒" -- 1050
end -- 1049
--- 建终章面板：半透明全屏底 + 主文案 + 小字 + 「返回关卡选择」。
-- 
-- ⚠️ 全屏底**不设** `touch: true`（与结算面板同一条规矩）：全屏 + swallowTouches
-- 会独占整屏点击，而它在节点树里排在瞄准层之前。终章态瞄准层本来就已
-- `setEnabled(false)`，能点的只有那一颗按钮。
-- 
-- 排版：文案都在**上半屏**（画面中心留给「地球只是一个点」），按钮在底部
-- 但**不贴边**（桌面引擎窗口底部有一条调试工具条，y < 90 一带的鼠标事件会被它吃掉，
-- 见 Hud.ts 里 viewButton 的注释）。
-- 
-- @param viewW 视图逻辑宽（`View.size.width`）
-- @param viewH 视图逻辑高
function ____exports.createFinalePanel(parent, viewW, viewH, opts) -- 1080
	local root = createPanel( -- 1086
		parent, -- 1086
		viewW, -- 1086
		viewH, -- 1086
		FinaleBackdropHex, -- 1086
		{alpha = 0.55} -- 1086
	) -- 1086
	local fontMain = 34 -- 1088
	local fontSub = 30 -- 1089
	local btnFont = 40 -- 1090
	local mainLabel = createLabel(root, ____exports.FinaleMainText, fontMain, FinaleMainHex) -- 1092
	if mainLabel ~= nil then -- 1092
		mainLabel.textWidth = viewW * 0.88 -- 1095
		setLabelCenter(mainLabel, viewW / 2, viewH * 0.8) -- 1096
	end -- 1096
	local subLabel = createLabel(root, "", fontSub, FinaleSubHex) -- 1099
	if subLabel ~= nil then -- 1099
		setLabelCenter(subLabel, viewW / 2, viewH * 0.71) -- 1100
	end -- 1100
	local btnW = clampNumber(viewW * 0.62, MinButtonWidth, 560) -- 1102
	local btnH = clampNumber(viewH * 0.085, MinButtonHeight, 120) -- 1103
	local backButton = createButton(root, { -- 1104
		w = btnW, -- 1105
		h = btnH, -- 1106
		text = "返回关卡选择", -- 1107
		fontSize = btnFont, -- 1108
		bgHex = ResultButtonBgHex, -- 1109
		fgHex = ResultButtonFgHex, -- 1110
		borderHex = ResultButtonBorderHex, -- 1111
		fireOn = "press", -- 1113
		onTap = opts.onBackToSelect -- 1114
	}) -- 1114
	backButton.root.position = Vec2((viewW - btnW) / 2, 110) -- 1116
	root.visible = false -- 1118
	backButton:setEnabled(false) -- 1120
	return { -- 1122
		root = root, -- 1123
		show = function(____, main, sub) -- 1124
			setLabelText(mainLabel, main) -- 1125
			setLabelText(subLabel, sub) -- 1126
			backButton:setEnabled(true) -- 1127
			root.visible = true -- 1128
		end, -- 1124
		hide = function() -- 1130
			root.visible = false -- 1131
			backButton:setEnabled(false) -- 1133
		end -- 1130
	} -- 1130
end -- 1080
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 1172
	local root = createPanel( -- 1178
		parent, -- 1178
		viewW, -- 1178
		viewH, -- 1178
		SelectBackdropHex, -- 1178
		{alpha = 0.9} -- 1178
	) -- 1178
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 1180
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 1181
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 1183
	setLabelCenter( -- 1184
		subtitleLabel, -- 1184
		viewW / 2, -- 1184
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 1184
	) -- 1184
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 1186
	setLabelCenter( -- 1187
		hintLabel, -- 1187
		viewW / 2, -- 1187
		clampNumber(viewH * 0.045, 36, 90) -- 1187
	) -- 1187
	local count = #opts.levels -- 1189
	local cols = viewH > viewW and 2 or 1 -- 1192
	local rows = math.max( -- 1193
		1, -- 1193
		math.ceil(count / cols) -- 1193
	) -- 1193
	local gap = 18 -- 1194
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 1195
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 1196
	local availW = viewW * 0.84 -- 1197
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 1198
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 1199
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 1200
	local gridW = cols * btnW + gap * (cols - 1) -- 1201
	local topY = viewH - headerH -- 1202
	local buttons = {} -- 1204
	do -- 1204
		local i = 0 -- 1205
		while i < count do -- 1205
			local index = i -- 1207
			local button = createButton( -- 1208
				root, -- 1208
				{ -- 1208
					w = btnW, -- 1209
					h = btnH, -- 1210
					text = opts.levels[index + 1].name, -- 1211
					fontSize = 38, -- 1212
					bgHex = SelectLockedBgHex, -- 1213
					fgHex = SelectLockedFgHex, -- 1214
					borderHex = SelectBorderHex, -- 1215
					fireOn = "press", -- 1217
					onTap = function() return opts:onPick(index) end -- 1218
				} -- 1218
			) -- 1218
			local col = index % cols -- 1220
			local rowIndex = math.floor(index / cols) -- 1221
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 1222
			buttons[#buttons + 1] = button -- 1226
			i = i + 1 -- 1205
		end -- 1205
	end -- 1205
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 1232
		root, -- 1233
		{ -- 1233
			w = clampNumber(viewW * 0.36, 180, 300), -- 1234
			h = MinButtonHeight, -- 1235
			text = "重看开场", -- 1236
			fontSize = 30, -- 1237
			bgHex = SelectLockedBgHex, -- 1238
			fgHex = SelectSubtitleHex, -- 1239
			borderHex = SelectBorderHex, -- 1240
			fireOn = "press", -- 1241
			onTap = function() -- 1242
				if opts.onReplayIntro ~= nil then -- 1242
					opts:onReplayIntro() -- 1243
				end -- 1243
			end -- 1242
		} -- 1242
	) or nil -- 1242
	if replayButton ~= nil then -- 1242
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 1248
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 1249
		replayButton.root.position = Vec2( -- 1250
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 1250
			by -- 1250
		) -- 1250
	end -- 1250
	root.visible = false -- 1253
	do -- 1253
		local i = 0 -- 1254
		while i < count do -- 1254
			buttons[i + 1]:setEnabled(false) -- 1254
			i = i + 1 -- 1254
		end -- 1254
	end -- 1254
	if replayButton ~= nil then -- 1254
		replayButton:setEnabled(false) -- 1255
	end -- 1255
	return { -- 1257
		root = root, -- 1258
		show = function(____, unlocked) -- 1259
			local maxUnlocked = clampNumber( -- 1260
				math.floor(unlocked), -- 1260
				0, -- 1260
				count - 1 -- 1260
			) -- 1260
			setLabelText( -- 1261
				subtitleLabel, -- 1261
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 1261
			) -- 1261
			do -- 1261
				local i = 0 -- 1262
				while i < count do -- 1262
					local button = buttons[i + 1] -- 1263
					local open = i <= maxUnlocked -- 1264
					button:setEnabled(open) -- 1265
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 1266
					if open then -- 1266
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 1267
					else -- 1267
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 1268
					end -- 1268
					i = i + 1 -- 1262
				end -- 1262
			end -- 1262
			root.visible = true -- 1270
			if replayButton ~= nil then -- 1270
				replayButton:setEnabled(true) -- 1271
			end -- 1271
		end, -- 1259
		hide = function() -- 1273
			root.visible = false -- 1274
			do -- 1274
				local i = 0 -- 1276
				while i < count do -- 1276
					buttons[i + 1]:setEnabled(false) -- 1276
					i = i + 1 -- 1276
				end -- 1276
			end -- 1276
			if replayButton ~= nil then -- 1276
				replayButton:setEnabled(false) -- 1277
			end -- 1277
		end -- 1273
	} -- 1273
end -- 1172
return ____exports -- 1172