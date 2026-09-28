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
function ____exports.createAimInput(parent, viewW, viewH, maxSpeed, minSpeed, speedChoices) -- 313
	local brakeOn, paintBrake, datePlate, dateLabel -- 313
	local speedMin = minSpeed ~= nil and minSpeed >= 0 and minSpeed < (maxSpeed ~= nil and maxSpeed or AimMaxSpeed) and minSpeed or AimMinSpeed -- 324
	local speedTop = maxSpeed ~= nil and maxSpeed > speedMin and maxSpeed or AimMaxSpeed -- 326
	local root = Node() -- 327
	root.size = Size(viewW, viewH) -- 328
	root.anchor = Vec2(0, 0) -- 334
	root.position = Vec2(0, 0) -- 335
	local touchLayer = Node() -- 338
	touchLayer.size = Size(viewW, viewH) -- 339
	touchLayer.anchor = Vec2(0.5, 0.5) -- 340
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 341
	touchLayer.swallowTouches = true -- 342
	root:addChild(touchLayer) -- 343
	local space = {viewW = viewW, viewH = viewH} -- 345
	local enabled = false -- 347
	local dragging = false -- 348
	--- 整屏瞄准（2D 模式）；由 Game 按视图状态同步。
	local fullScreenAim = false -- 350
	local aim = {velocity = {x = 0, y = -speedMin}, power = 0, unit = {x = 0, y = -1}} -- 351
	local probeOffset = {x = 0, y = 0} -- 354
	local dragHandler = nil -- 356
	local readyHandler = nil -- 357
	local observeHandler = nil -- 358
	local zoomHandler = nil -- 359
	local launchHandler = nil -- 360
	local pressOffset = {x = 0, y = 0} -- 371
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 374
		aim = ____exports.computeAim( -- 375
			{x = 0, y = 0}, -- 375
			delta, -- 375
			AimMaxDragPx, -- 375
			speedTop, -- 375
			speedMin -- 375
		) -- 375
		if dragHandler ~= nil then -- 375
			dragHandler(aim) -- 376
		end -- 376
	end -- 374
	local aimRadius = math.max(96, viewW * 0.25) -- 383
	local mode = "none" -- 384
	local observeLast = {x = 0, y = 0} -- 385
	touchLayer:onTapBegan(function(touch) -- 386
		if not enabled then -- 386
			return -- 387
		end -- 387
		local at = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 388
		local dx = at.x - probeOffset.x -- 389
		local dy = at.y - probeOffset.y -- 390
		if fullScreenAim or math.sqrt(dx * dx + dy * dy) <= aimRadius then -- 390
			mode = "aim" -- 392
			dragging = true -- 393
			pressOffset = at -- 394
			handleDelta({x = 0, y = 0}) -- 396
		else -- 396
			mode = "observe" -- 398
			observeLast = at -- 399
		end -- 399
	end) -- 386
	touchLayer:onTapMoved(function(touch) -- 403
		if not enabled then -- 403
			return -- 404
		end -- 404
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 405
		if mode == "aim" and dragging then -- 405
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 407
		elseif mode == "observe" then -- 407
			if observeHandler ~= nil then -- 407
				observeHandler(cur.x - observeLast.x, cur.y - observeLast.y) -- 410
			end -- 410
			observeLast = cur -- 411
		end -- 411
	end) -- 403
	touchLayer:onTapEnded(function(touch) -- 415
		if not enabled then -- 415
			return -- 416
		end -- 416
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 417
		if mode == "aim" then -- 417
			dragging = false -- 419
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 420
			if readyHandler ~= nil then -- 420
				readyHandler(aim) -- 422
			end -- 422
		end -- 422
		mode = "none" -- 424
	end) -- 415
	touchLayer:onGesture(function(_center, numFingers, deltaDist, _deltaAngle) -- 428
		if not enabled or numFingers < 2 then -- 428
			return -- 429
		end -- 429
		if zoomHandler ~= nil then -- 429
			zoomHandler(deltaDist) -- 430
		end -- 430
	end) -- 428
	touchLayer.touchEnabled = false -- 438
	local brakeHandler = nil -- 443
	local BrakeButtonW = 116 -- 444
	local BrakeButtonH = 64 -- 445
	local brakeGap = 8 -- 446
	local brakeButtons = {} -- 450
	local function makeBrakeButton(text, on, x) -- 451
		local btn = createButton( -- 452
			root, -- 452
			{ -- 452
				w = BrakeButtonW, -- 453
				h = BrakeButtonH, -- 454
				text = text, -- 455
				fontSize = 30, -- 456
				bgHex = ResultButtonAltBgHex, -- 457
				fgHex = ResultButtonFgHex, -- 458
				borderHex = ResultButtonBorderHex, -- 459
				onTap = function() -- 460
					brakeOn = on -- 463
					paintBrake() -- 464
					if brakeHandler ~= nil then -- 464
						brakeHandler(on) -- 465
					end -- 465
				end -- 460
			} -- 460
		) -- 460
		btn.root.position = Vec2(x, viewH - BrakeButtonH - 20) -- 468
		brakeButtons[#brakeButtons + 1] = btn -- 469
	end -- 451
	brakeOn = false -- 471
	paintBrake = function() -- 472
		if #brakeButtons < 2 then -- 472
			return -- 473
		end -- 473
		brakeButtons[1]:setColors(brakeOn and ResultButtonAltBgHex or ResultButtonBgHex, ResultButtonFgHex) -- 474
		brakeButtons[2]:setColors(brakeOn and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 475
	end -- 472
	createPanel( -- 481
		root, -- 481
		220, -- 481
		50, -- 481
		658964, -- 481
		{alpha = 0.45} -- 481
	) -- 481
	local dvLabel = createLabel(root, "Δv — / —", 30, ResultHintHex) -- 482
	if dvLabel ~= nil then -- 482
		dvLabel.position = Vec2(24, viewH - 44) -- 484
		dvLabel.anchor = Vec2(0, 0) -- 485
	end -- 485
	local warpHandler = nil -- 495
	local dateSpan = 0 -- 496
	--- 这一关有时间轴**且**当前相态允许改日期（Flying/Result 时必须是 false）。
	local warpOn = true -- 503
	local warpVisible = true -- 504
	--- 相态是否允许改日期（由主循环每帧 setTimeEnabled 同步）。
	local warpAllowed = true -- 506
	--- 上次写进日期的文字（避免每帧重设 Label 文本）。
	local lastDateText = "" -- 508
	--- >0 = 正在按住这个方向（-1 回退 / +1 加速）；0 = 没按住。
	local warpHoldDir = 0 -- 510
	--- 距离下一次连按还有多久（秒）。
	local warpRepeatIn = 0 -- 512
	local WarpButtonW = 116 -- 513
	local WarpButtonH = 64 -- 514
	local warpButtons = {} -- 515
	local function applyWarpState() -- 516
		local vis = dateSpan > 0 -- 517
		local on = vis and warpAllowed -- 518
		if vis == warpVisible and on == warpOn then -- 518
			return -- 519
		end -- 519
		warpVisible = vis -- 520
		warpOn = on -- 521
		if not on then -- 521
			warpHoldDir = 0 -- 522
		end -- 522
		for ____, b in ipairs(warpButtons) do -- 523
			b.root.visible = vis -- 524
			b:setEnabled(on) -- 525
		end -- 525
		if dateLabel ~= nil then -- 525
			dateLabel.visible = vis -- 527
		end -- 527
		datePlate.visible = vis -- 528
	end -- 516
	local function makeWarpButton(text, dir, x) -- 530
		local btn = createButton( -- 531
			root, -- 531
			{ -- 531
				w = WarpButtonW, -- 532
				h = WarpButtonH, -- 533
				text = text, -- 534
				fontSize = 30, -- 535
				bgHex = ResultButtonAltBgHex, -- 536
				fgHex = ResultButtonFgHex, -- 537
				borderHex = ResultButtonBorderHex, -- 538
				onTap = function() -- 541
				end, -- 541
				onPressBegan = function() -- 542
					print((("[escape-velocity] warp press dir=" .. __TS__NumberToFixed(dir, 0)) .. " on=") .. (warpOn and "1" or "0")) -- 544
					if not warpOn then -- 544
						return -- 545
					end -- 545
					if warpHoldDir == dir then -- 545
						return -- 547
					end -- 547
					warpHoldDir = dir -- 548
					warpRepeatIn = WarpHoldDelaySec -- 549
					if warpHandler ~= nil then -- 549
						warpHandler(dir) -- 550
					end -- 550
				end, -- 542
				onPressEnded = function() -- 552
					print((("[escape-velocity] warp release dir=" .. __TS__NumberToFixed(dir, 0)) .. " hold=") .. __TS__NumberToFixed(warpHoldDir, 0)) -- 553
					if warpHoldDir == dir then -- 553
						warpHoldDir = 0 -- 555
					end -- 555
				end -- 552
			} -- 552
		) -- 552
		btn.root.position = Vec2(x, viewH - 96 - WarpButtonH) -- 561
		warpButtons[#warpButtons + 1] = btn -- 562
	end -- 530
	local warpLeftX = viewW - (WarpButtonW * 2 + 8) - 20 -- 564
	makeWarpButton("◀ 回退", -1, warpLeftX) -- 565
	makeWarpButton("加速 ▶", 1, warpLeftX + WarpButtonW + 8) -- 566
	datePlate = createPanel( -- 568
		root, -- 568
		300, -- 568
		50, -- 568
		658964, -- 568
		{alpha = 0.45} -- 568
	) -- 568
	datePlate.position = Vec2(warpLeftX - 316, viewH - 96 - WarpButtonH + 8) -- 569
	dateLabel = createLabel(root, "发射日期 —", 30, ResultHintHex) -- 570
	if dateLabel ~= nil then -- 570
		dateLabel.anchor = Vec2(1, 0) -- 575
		dateLabel.position = Vec2(warpLeftX - 16, viewH - 96 - WarpButtonH + 18) -- 576
	end -- 576
	local LaunchButtonW = 220 -- 583
	local LaunchButtonH = 112 -- 584
	local launchButton = createButton( -- 585
		root, -- 585
		{ -- 585
			w = LaunchButtonW, -- 586
			h = LaunchButtonH, -- 587
			text = "发射", -- 588
			fontSize = 44, -- 589
			bgHex = ResultButtonBgHex, -- 590
			fgHex = ResultButtonFgHex, -- 591
			borderHex = ResultButtonBorderHex, -- 592
			fireOn = "press", -- 593
			onTap = function() -- 594
				print("[escape-velocity] launch button fire (press)") -- 596
				if launchHandler ~= nil then -- 596
					launchHandler() -- 597
				end -- 597
			end -- 594
		} -- 594
	) -- 594
	launchButton.root.position = Vec2(viewW - LaunchButtonW - 24, 96) -- 600
	launchButton.root.visible = false -- 601
	launchButton:setEnabled(false) -- 602
	local ViewButtonW = 116 -- 610
	local ViewButtonH = 64 -- 611
	local viewHandler = nil -- 612
	local viewButton = createButton( -- 613
		root, -- 613
		{ -- 613
			w = ViewButtonW, -- 614
			h = ViewButtonH, -- 615
			text = "2D", -- 616
			fontSize = 30, -- 617
			bgHex = ResultButtonAltBgHex, -- 618
			fgHex = ResultButtonFgHex, -- 619
			borderHex = ResultButtonBorderHex, -- 620
			fireOn = "press", -- 622
			onTap = function() -- 623
				print("[escape-velocity] view toggle fire (press)") -- 624
				if viewHandler ~= nil then -- 624
					viewHandler() -- 625
				end -- 625
			end -- 623
		} -- 623
	) -- 623
	viewButton.root.position = Vec2(viewW - ViewButtonW - 24, 96 + LaunchButtonH + 12) -- 631
	--- 上次写进按钮的文字（每帧都会被 setViewMode 调用，没变就别碰 Label）。
	local lastViewText = "2D" -- 633
	local PlaybackButtonW = 116 -- 642
	local PlaybackButtonH = 64 -- 643
	local playbackGap = 10 -- 644
	local playbackButtons = {} -- 645
	local playbackSpeeds = {} -- 646
	local playbackHandler = nil -- 647
	local speedChoice = speedChoices ~= nil and #speedChoices > 0 and speedChoices or ({1, 2, 4}) -- 650
	local playbackSpeed = speedChoice[1] -- 651
	--- 已应用到节点上的显隐状态。初值 false 如实反映"建出来就隐藏"（照 warp 按钮的教训）。
	local playbackVisible = false -- 653
	local function paintPlayback() -- 654
		do -- 654
			local i = 0 -- 655
			while i < #playbackButtons do -- 655
				local on = playbackSpeeds[i + 1] == playbackSpeed -- 656
				playbackButtons[i + 1]:setColors(on and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 657
				i = i + 1 -- 655
			end -- 655
		end -- 655
	end -- 654
	local function makePlaybackButton(speed, x) -- 660
		local btn = createButton( -- 661
			root, -- 661
			{ -- 661
				w = PlaybackButtonW, -- 662
				h = PlaybackButtonH, -- 663
				text = ____exports.playbackLabel(speed), -- 664
				fontSize = 30, -- 665
				bgHex = ResultButtonAltBgHex, -- 666
				fgHex = ResultButtonFgHex, -- 667
				borderHex = ResultButtonBorderHex, -- 668
				onTap = function() -- 669
					print(("[escape-velocity] playback button fire " .. __TS__NumberToFixed(speed, 0)) .. "x (release)") -- 671
					playbackSpeed = speed -- 672
					paintPlayback() -- 673
					if playbackHandler ~= nil then -- 673
						playbackHandler(speed) -- 674
					end -- 674
				end -- 669
			} -- 669
		) -- 669
		btn.root.position = Vec2(x, 96) -- 679
		playbackButtons[#playbackButtons + 1] = btn -- 680
		playbackSpeeds[#playbackSpeeds + 1] = speed -- 681
	end -- 660
	do -- 660
		local i = 0 -- 683
		while i < #speedChoice and i < 3 do -- 683
			makePlaybackButton(speedChoice[i + 1], 24 + (PlaybackButtonW + playbackGap) * i) -- 684
			i = i + 1 -- 683
		end -- 683
	end -- 683
	paintPlayback() -- 686
	for ____, b in ipairs(playbackButtons) do -- 688
		b.root.visible = false -- 689
		b:setEnabled(false) -- 690
	end -- 690
	local brakeRightX = viewW - BrakeButtonW - 20 -- 693
	makeBrakeButton("惯性", false, brakeRightX - BrakeButtonW - brakeGap) -- 694
	makeBrakeButton("刹车", true, brakeRightX) -- 695
	paintBrake() -- 696
	local liveBrakeHandler = nil -- 699
	local liveBrakeActive = false -- 700
	local liveBrakedState = false -- 701
	local LiveBrakeW = 220 -- 702
	local LiveBrakeH = 100 -- 703
	local liveBrakeButton = createButton( -- 704
		root, -- 704
		{ -- 704
			w = LiveBrakeW, -- 705
			h = LiveBrakeH, -- 706
			text = "BRAKE 逆喷", -- 707
			fontSize = 36, -- 708
			bgHex = 10899464, -- 709
			fgHex = 16775392, -- 710
			borderHex = 16755251, -- 711
			fireOn = "press", -- 712
			onTap = function() -- 713
				print("[escape-velocity] live brake button fire (press)") -- 714
				if liveBrakeHandler ~= nil then -- 714
					liveBrakeHandler() -- 715
				end -- 715
			end -- 713
		} -- 713
	) -- 713
	liveBrakeButton.root.position = Vec2(viewW - LiveBrakeW - 24, 96) -- 718
	liveBrakeButton.root.visible = false -- 719
	liveBrakeButton:setEnabled(false) -- 720
	local hintW = 440 -- 723
	local hintH = 50 -- 724
	local brakeHintPlate = createPanel( -- 725
		root, -- 725
		hintW, -- 725
		hintH, -- 725
		658964, -- 725
		{alpha = 0.65, borderHex = 16755251} -- 725
	) -- 725
	brakeHintPlate.position = Vec2((viewW - hintW) / 2, viewH - 240) -- 726
	local brakeHintLabel = createLabel(brakeHintPlate, "【木星捕获窗口已开启 · 按下 BRAKE 逆喷入轨】", 22, 16762939) -- 727
	if brakeHintLabel ~= nil then -- 727
		setLabelCenter(brakeHintLabel, hintW / 2, hintH / 2) -- 729
	end -- 729
	brakeHintPlate.visible = false -- 731
	parent:addChild(root) -- 733
	return { -- 735
		onDrag = function(____, callback) -- 736
			dragHandler = callback -- 737
		end, -- 736
		setEnabled = function(____, value) -- 739
			enabled = value -- 740
			touchLayer.touchEnabled = value -- 743
			if not value then -- 743
				dragging = false -- 745
				liveBrakeActive = false -- 746
				liveBrakeButton.root.visible = false -- 747
				liveBrakeButton:setEnabled(false) -- 748
				brakeHintPlate.visible = false -- 749
			end -- 749
		end, -- 739
		onBrake = function(____, callback) -- 752
			brakeHandler = callback -- 753
		end, -- 752
		setBrake = function(____, on) -- 755
			brakeOn = on -- 756
			paintBrake() -- 757
		end, -- 755
		onAimReady = function(____, callback) -- 759
			readyHandler = callback -- 760
		end, -- 759
		onObserve = function(____, callback) -- 762
			observeHandler = callback -- 763
		end, -- 762
		onZoom = function(____, callback) -- 765
			zoomHandler = callback -- 766
		end, -- 765
		onLaunch = function(____, callback) -- 768
			launchHandler = callback -- 769
		end, -- 768
		setArmed = function(____, armed) -- 771
			launchButton.root.visible = armed -- 772
			launchButton:setEnabled(armed) -- 773
		end, -- 771
		onViewToggle = function(____, callback) -- 775
			viewHandler = callback -- 776
		end, -- 775
		setViewMode = function(____, mode) -- 778
			if mode == lastViewText then -- 778
				return -- 779
			end -- 779
			lastViewText = mode -- 780
			viewButton:setText(mode) -- 781
		end, -- 778
		onPlayback = function(____, callback) -- 783
			playbackHandler = callback -- 784
		end, -- 783
		setPlayback = function(____, speed) -- 786
			if speed == playbackSpeed then -- 786
				return -- 787
			end -- 787
			playbackSpeed = speed -- 788
			paintPlayback() -- 789
		end, -- 786
		setPlaybackVisible = function(____, on) -- 791
			if on == playbackVisible then -- 791
				return -- 792
			end -- 792
			playbackVisible = on -- 793
			for ____, b in ipairs(playbackButtons) do -- 794
				b.root.visible = on -- 795
				b:setEnabled(on) -- 796
			end -- 796
		end, -- 791
		setFullScreenAim = function(____, on) -- 799
			fullScreenAim = on -- 800
		end, -- 799
		onWarp = function(____, callback) -- 802
			warpHandler = callback -- 803
		end, -- 802
		setDate = function(____, t0, span) -- 805
			dateSpan = span > 0 and span or 0 -- 806
			applyWarpState() -- 807
			local on = dateSpan > 0 -- 808
			local text = on and (("发射日期 " .. __TS__NumberToFixed(t0, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0) or "发射日期" -- 809
			if text ~= lastDateText then -- 809
				lastDateText = text -- 811
				setLabelText(dateLabel, text) -- 812
			end -- 812
		end, -- 805
		setTimeEnabled = function(____, on) -- 815
			if warpAllowed == on then -- 815
				return -- 816
			end -- 816
			warpAllowed = on -- 817
			applyWarpState() -- 818
		end, -- 815
		update = function(____, dt) -- 820
			if not warpOn or warpHoldDir == 0 then -- 820
				return -- 821
			end -- 821
			warpRepeatIn = warpRepeatIn - dt -- 822
			if warpRepeatIn > 0 then -- 822
				return -- 823
			end -- 823
			warpRepeatIn = TimeWarpStep / TimeWarpRate -- 825
			if warpHandler ~= nil then -- 825
				warpHandler(warpHoldDir) -- 826
			end -- 826
		end, -- 820
		isDragging = function() return dragging end, -- 828
		setBurnInfo = function(____, burn, budget) -- 829
			local b = budget < 1 and __TS__NumberToFixed(budget, 2) or __TS__NumberToFixed(budget, 0) -- 833
			local v = burn < 1 and __TS__NumberToFixed(burn, 2) or __TS__NumberToFixed(burn, 1) -- 834
			setLabelText(dvLabel, (("Δv " .. v) .. " / ") .. b) -- 835
		end, -- 829
		current = function() return aim end, -- 837
		setProbeOffset = function(____, offset) -- 838
			probeOffset = offset -- 839
		end, -- 838
		handleLocal = function(____, ____local) -- 843
			handleDelta(____exports.localToOffset(____local, space)) -- 844
		end, -- 843
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 847
		debugProbeOffset = function() return probeOffset end, -- 848
		onLiveBrake = function(____, callback) -- 849
			liveBrakeHandler = callback -- 850
		end, -- 849
		setLiveBrakeVisible = function(____, visible) -- 852
			if liveBrakeActive == visible then -- 852
				return -- 853
			end -- 853
			liveBrakeActive = visible -- 854
			liveBrakeButton.root.visible = visible -- 855
			liveBrakeButton:setEnabled(visible) -- 856
			brakeHintPlate.visible = visible -- 857
		end, -- 852
		setLiveBraked = function(____, braked) -- 859
			if liveBrakedState == braked then -- 859
				return -- 860
			end -- 860
			liveBrakedState = braked -- 861
			if braked then -- 861
				liveBrakeButton:setText("已捕获入轨") -- 863
				liveBrakeButton:setColors(1589810, 13697002) -- 864
				liveBrakeButton:setEnabled(false) -- 865
				if brakeHintLabel ~= nil then -- 865
					setLabelText(brakeHintLabel, "【主发动机逆喷成功！已捕获入轨】") -- 867
					setLabelColor(brakeHintLabel, 4122272) -- 868
				end -- 868
			else -- 868
				liveBrakeButton:setText("BRAKE 逆喷") -- 871
				liveBrakeButton:setColors(10899464, 16775392) -- 872
				if brakeHintLabel ~= nil then -- 872
					setLabelText(brakeHintLabel, "【木星捕获窗口已开启 · 按下 BRAKE 逆喷入轨】") -- 874
					setLabelColor(brakeHintLabel, 16762939) -- 875
				end -- 875
			end -- 875
		end, -- 859
		root = root -- 879
	} -- 879
end -- 313
local ResultBackdropHex = 329484 -- 896
local ResultCardHex = 1252395 -- 897
local ResultCardBorderHex = 3362938 -- 898
local ResultLevelHex = 9417948 -- 899
local ResultBodyHex = 14149367 -- 900
ResultHintHex = 8229803 -- 901
ResultButtonBgHex = 1919610 -- 902
ResultButtonAltBgHex = 1779509 -- 903
ResultButtonFgHex = 15398143 -- 904
ResultButtonBorderHex = 5211846 -- 905
local TitleSuccessHex = 8381344 -- 906
local TitleMissedHex = 16766073 -- 907
local TitleCrashedHex = 16743019 -- 908
local SelectBackdropHex = 329484 -- 910
local SelectTitleHex = 16777215 -- 911
local SelectSubtitleHex = 10470632 -- 912
local SelectHintHex = 7309478 -- 913
local SelectOpenBgHex = 1919610 -- 914
local SelectOpenFgHex = 15398143 -- 915
local SelectLockedBgHex = 1383204 -- 916
local SelectLockedFgHex = 6912140 -- 917
local SelectBorderHex = 4157096 -- 918
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 921
	if value < lo then -- 921
		return lo -- 922
	end -- 922
	if value > hi then -- 922
		return hi -- 923
	end -- 923
	return value -- 924
end -- 921
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 928
	if result == "success" then -- 928
		return "借力成功" -- 929
	end -- 929
	if result == "crashed" then -- 929
		return "信号中断" -- 930
	end -- 930
	return "错过目标" -- 931
end -- 928
--- 三态说明句（逐字）。
local function resultBody(result) -- 935
	if result == "success" then -- 935
		return "行星把探测器甩了出去，速度够了。" -- 936
	end -- 936
	if result == "crashed" then -- 936
		return "探测器撞上行星，任务到此为止。" -- 937
	end -- 937
	return "从行星身侧掠过，没能借到那一点速度。" -- 938
end -- 935
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 942
	if result == "success" then -- 942
		return TitleSuccessHex -- 943
	end -- 943
	if result == "crashed" then -- 943
		return TitleCrashedHex -- 944
	end -- 944
	return TitleMissedHex -- 945
end -- 942
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 954
	if result == "success" then -- 954
		return "下一关已解锁" -- 955
	end -- 955
	return "可重试本关，或返回关卡选择" -- 956
end -- 954
--- 建结算面板：半透明全屏底 + 居中工业级卡片 + 三枚火箭挑战清单 + 遥测数据 + 2 个按钮。
-- 
-- ⚠️ 全屏底**不能**设 `touch: true`（真机验收踩到的坑）：
-- 全屏 + `swallowTouches` 的节点会独占它覆盖范围内的点击，而节点树里它排在瞄准层之前；
-- 只要它存在，进入关卡后怎么拖都没反应（表现为“进关卡不能拖动飞行器”）。
-- 不需要它吞点击：结算态瞄准层本来就已 `setEnabled(false)`（Flying 起就关），
-- 能点的只有卡片里那两个按钮。
-- 
-- @param viewW 视图逻辑宽（`View.size.width`）
-- @param viewH 视图逻辑高
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 1000
	local root = createPanel( -- 1006
		parent, -- 1006
		viewW, -- 1006
		viewH, -- 1006
		ResultBackdropHex, -- 1006
		{alpha = 0.78} -- 1006
	) -- 1006
	local cardW = clampNumber(viewW * 0.9, 360, 560) -- 1008
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 480) -- 1009
	local btnH = clampNumber(viewH * 0.08, 48, 60) -- 1010
	local padX = (cardW - btnW) / 2 -- 1011
	local padY = 28 -- 1012
	local fontLevel = 24 -- 1014
	local fontRockets = 38 -- 1015
	local fontTitle = 30 -- 1016
	local fontTelemetry = 19 -- 1017
	local fontChallenge = 18 -- 1018
	local fontTotal = 20 -- 1019
	local btnFont = 24 -- 1020
	local rowGap = 12 -- 1021
	local hLevel = 28 -- 1023
	local hRockets = 42 -- 1024
	local hTitle = 34 -- 1025
	local hTelemetry = 24 -- 1026
	local hChallengeRow = 30 -- 1027
	local hChallenges = hChallengeRow * 3 -- 1028
	local hTotal = 24 -- 1029
	local cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7 -- 1031
	if cardH > viewH - 24 then -- 1031
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 1033
		cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7 -- 1034
	end -- 1034
	local card = createPanel( -- 1037
		root, -- 1037
		cardW, -- 1037
		cardH, -- 1037
		ResultCardHex, -- 1037
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 1037
	) -- 1037
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 1042
	local cursor = cardH - padY -- 1045
	cursor = cursor - hLevel -- 1047
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 1048
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 1049
	cursor = cursor - (rowGap + hRockets) -- 1051
	local rocketsLabel = createLabel(card, "", fontRockets, 16762939) -- 1052
	setLabelCenter(rocketsLabel, cardW / 2, cursor + hRockets / 2) -- 1053
	cursor = cursor - (rowGap + hTitle) -- 1055
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 1056
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 1057
	cursor = cursor - (rowGap + hTelemetry) -- 1059
	local telemetryLabel = createLabel(card, "", fontTelemetry, ResultHintHex) -- 1060
	setLabelCenter(telemetryLabel, cardW / 2, cursor + hTelemetry / 2) -- 1061
	cursor = cursor - rowGap -- 1063
	local challengeLabels = {} -- 1064
	do -- 1064
		local k = 0 -- 1065
		while k < 3 do -- 1065
			cursor = cursor - hChallengeRow -- 1066
			local cl = createLabel(card, "", fontChallenge, 10405355) -- 1067
			if cl ~= nil then -- 1067
				cl.textWidth = cardW - 60 -- 1069
				setLabelCenter(cl, cardW / 2, cursor + hChallengeRow / 2) -- 1070
				challengeLabels[#challengeLabels + 1] = cl -- 1071
			end -- 1071
			k = k + 1 -- 1065
		end -- 1065
	end -- 1065
	cursor = cursor - (rowGap + hTotal) -- 1075
	local totalLabel = createLabel(card, "", fontTotal, 16766073) -- 1076
	setLabelCenter(totalLabel, cardW / 2, cursor + hTotal / 2) -- 1077
	cursor = cursor - (rowGap + btnH) -- 1079
	local retryButton = createButton(card, { -- 1080
		w = btnW, -- 1081
		h = btnH, -- 1082
		text = "重试本关", -- 1083
		fontSize = btnFont, -- 1084
		bgHex = ResultButtonBgHex, -- 1085
		fgHex = ResultButtonFgHex, -- 1086
		borderHex = ResultButtonBorderHex, -- 1087
		fireOn = "press", -- 1088
		onTap = opts.onRetry -- 1089
	}) -- 1089
	retryButton.root.position = Vec2(padX, cursor) -- 1091
	cursor = cursor - (14 + btnH) -- 1093
	local backButton = createButton(card, { -- 1094
		w = btnW, -- 1095
		h = btnH, -- 1096
		text = "返回关卡选择", -- 1097
		fontSize = btnFont, -- 1098
		bgHex = ResultButtonAltBgHex, -- 1099
		fgHex = ResultButtonFgHex, -- 1100
		borderHex = ResultButtonBorderHex, -- 1101
		fireOn = "press", -- 1102
		onTap = opts.onBackToSelect -- 1103
	}) -- 1103
	backButton.root.position = Vec2(padX, cursor) -- 1105
	root.visible = false -- 1107
	retryButton:setEnabled(false) -- 1108
	backButton:setEnabled(false) -- 1109
	return { -- 1111
		root = root, -- 1112
		show = function(____, result, levelName, detail) -- 1113
			retryButton:setEnabled(true) -- 1114
			backButton:setEnabled(true) -- 1115
			setLabelText(levelLabel, levelName) -- 1116
			setLabelText( -- 1117
				titleLabel, -- 1117
				resultTitle(result) -- 1117
			) -- 1117
			setLabelColor( -- 1118
				titleLabel, -- 1118
				resultTitleColor(result) -- 1118
			) -- 1118
			if detail ~= nil then -- 1118
				local rCount = detail.rocketsGot -- 1121
				local rStr = "☆  ☆  ☆" -- 1122
				if rCount == 1 then -- 1122
					rStr = "★  ☆  ☆" -- 1123
				elseif rCount == 2 then -- 1123
					rStr = "★  ★  ☆" -- 1124
				elseif rCount >= 3 then -- 1124
					rStr = "★  ★  ★" -- 1125
				end -- 1125
				setLabelText(rocketsLabel, rStr) -- 1126
				setLabelColor(rocketsLabel, rCount > 0 and 16762939 or 6322324) -- 1127
				local pct = detail.dvBudget > 0 and math.floor(detail.burnDv / detail.dvBudget * 100) or 0 -- 1129
				local telemText = ((((((("点火消耗 Δv: " .. __TS__NumberToFixed(detail.burnDv, 2)) .. " / ") .. __TS__NumberToFixed(detail.dvBudget, 2)) .. " (") .. __TS__NumberToFixed(pct, 0)) .. "%) · 用时: ") .. __TS__NumberToFixed(detail.flightTime, 1)) .. "s" -- 1130
				setLabelText(telemetryLabel, telemText) -- 1131
				do -- 1131
					local k = 0 -- 1133
					while k < 3 do -- 1133
						if challengeLabels[k + 1] ~= nil then -- 1133
							if k < #detail.challenges then -- 1133
								local ok = detail.achieved[k + 1] -- 1136
								local icon = ok and "★" or "☆" -- 1137
								local rank = k == 0 and "一星" or (k == 1 and "二星" or "三星") -- 1138
								local text = (((icon .. " [") .. rank) .. "] ") .. detail.challenges[k + 1] -- 1139
								setLabelText(challengeLabels[k + 1], text) -- 1140
								setLabelColor(challengeLabels[k + 1], ok and 16762939 or 6322324) -- 1141
								challengeLabels[k + 1].visible = true -- 1142
							else -- 1142
								challengeLabels[k + 1].visible = false -- 1144
							end -- 1144
						end -- 1144
						k = k + 1 -- 1133
					end -- 1133
				end -- 1133
				setLabelText( -- 1149
					totalLabel, -- 1149
					((("全深空火箭勋章: " .. __TS__NumberToFixed(detail.totalRockets, 0)) .. " / ") .. __TS__NumberToFixed(detail.totalPossibleRockets, 0)) .. " ★" -- 1149
				) -- 1149
				if totalLabel ~= nil then -- 1149
					totalLabel.visible = true -- 1150
				end -- 1150
			else -- 1150
				setLabelText(rocketsLabel, result == "success" and "★  ☆  ☆" or "☆  ☆  ☆") -- 1152
				setLabelColor(rocketsLabel, result == "success" and 16762939 or 6322324) -- 1153
				setLabelText( -- 1154
					telemetryLabel, -- 1154
					resultBody(result) -- 1154
				) -- 1154
				do -- 1154
					local k = 0 -- 1155
					while k < #challengeLabels do -- 1155
						challengeLabels[k + 1].visible = false -- 1155
						k = k + 1 -- 1155
					end -- 1155
				end -- 1155
				if totalLabel ~= nil then -- 1155
					totalLabel.visible = false -- 1156
				end -- 1156
			end -- 1156
			root.visible = true -- 1158
		end, -- 1113
		hide = function() -- 1160
			root.visible = false -- 1161
			retryButton:setEnabled(false) -- 1162
			backButton:setEnabled(false) -- 1163
		end -- 1160
	} -- 1160
end -- 1000
local FinaleBackdropHex = 329484 -- 1178
local FinaleMainHex = 15398143 -- 1179
local FinaleSubHex = 10470632 -- 1180
--- 终章主文案（逐字；改之前先改 PLAN S3.18 与 docs/开发手册.md）。
____exports.FinaleMainText = "这就是我们整颗星球的样子 —— 而你已经从那里飞到了这里。" -- 1185
--- 终章小字：飞行距离 / 用时（纯函数，可单测）。
-- 
-- 距离是**平面单位**（关卡尺度，不是公里）—— 别在这里换算成天文单位，
-- 那一换就得把整条注释重写一遍，而玩家要的只是「飞了多远、花了多久」。
function ____exports.finaleSubtitle(distance, time) -- 1193
	return ((("飞行 " .. __TS__NumberToFixed(distance, 0)) .. " 单位 · 用时 ") .. __TS__NumberToFixed(time, 1)) .. " 秒" -- 1194
end -- 1193
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
function ____exports.createFinalePanel(parent, viewW, viewH, opts) -- 1224
	local root = createPanel( -- 1230
		parent, -- 1230
		viewW, -- 1230
		viewH, -- 1230
		FinaleBackdropHex, -- 1230
		{alpha = 0.55} -- 1230
	) -- 1230
	local fontMain = 34 -- 1232
	local fontSub = 30 -- 1233
	local btnFont = 40 -- 1234
	local mainLabel = createLabel(root, ____exports.FinaleMainText, fontMain, FinaleMainHex) -- 1236
	if mainLabel ~= nil then -- 1236
		mainLabel.textWidth = viewW * 0.88 -- 1239
		setLabelCenter(mainLabel, viewW / 2, viewH * 0.8) -- 1240
	end -- 1240
	local subLabel = createLabel(root, "", fontSub, FinaleSubHex) -- 1243
	if subLabel ~= nil then -- 1243
		setLabelCenter(subLabel, viewW / 2, viewH * 0.71) -- 1244
	end -- 1244
	local btnW = clampNumber(viewW * 0.62, MinButtonWidth, 560) -- 1246
	local btnH = clampNumber(viewH * 0.085, MinButtonHeight, 120) -- 1247
	local backButton = createButton(root, { -- 1248
		w = btnW, -- 1249
		h = btnH, -- 1250
		text = "返回关卡选择", -- 1251
		fontSize = btnFont, -- 1252
		bgHex = ResultButtonBgHex, -- 1253
		fgHex = ResultButtonFgHex, -- 1254
		borderHex = ResultButtonBorderHex, -- 1255
		fireOn = "press", -- 1257
		onTap = opts.onBackToSelect -- 1258
	}) -- 1258
	backButton.root.position = Vec2((viewW - btnW) / 2, 110) -- 1260
	root.visible = false -- 1262
	backButton:setEnabled(false) -- 1264
	return { -- 1266
		root = root, -- 1267
		show = function(____, main, sub) -- 1268
			setLabelText(mainLabel, main) -- 1269
			setLabelText(subLabel, sub) -- 1270
			backButton:setEnabled(true) -- 1271
			root.visible = true -- 1272
		end, -- 1268
		hide = function() -- 1274
			root.visible = false -- 1275
			backButton:setEnabled(false) -- 1277
		end -- 1274
	} -- 1274
end -- 1224
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 1316
	local root = createPanel( -- 1322
		parent, -- 1322
		viewW, -- 1322
		viewH, -- 1322
		SelectBackdropHex, -- 1322
		{alpha = 0.9} -- 1322
	) -- 1322
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 1324
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 1325
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 1327
	setLabelCenter( -- 1328
		subtitleLabel, -- 1328
		viewW / 2, -- 1328
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 1328
	) -- 1328
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 1330
	setLabelCenter( -- 1331
		hintLabel, -- 1331
		viewW / 2, -- 1331
		clampNumber(viewH * 0.045, 36, 90) -- 1331
	) -- 1331
	local count = #opts.levels -- 1333
	local cols = viewH > viewW and 2 or 1 -- 1336
	local rows = math.max( -- 1337
		1, -- 1337
		math.ceil(count / cols) -- 1337
	) -- 1337
	local gap = 18 -- 1338
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 1339
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 1340
	local availW = viewW * 0.84 -- 1341
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 1342
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 1343
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 1344
	local gridW = cols * btnW + gap * (cols - 1) -- 1345
	local topY = viewH - headerH -- 1346
	local buttons = {} -- 1348
	do -- 1348
		local i = 0 -- 1349
		while i < count do -- 1349
			local index = i -- 1351
			local button = createButton( -- 1352
				root, -- 1352
				{ -- 1352
					w = btnW, -- 1353
					h = btnH, -- 1354
					text = opts.levels[index + 1].name, -- 1355
					fontSize = 38, -- 1356
					bgHex = SelectLockedBgHex, -- 1357
					fgHex = SelectLockedFgHex, -- 1358
					borderHex = SelectBorderHex, -- 1359
					fireOn = "press", -- 1361
					onTap = function() return opts:onPick(index) end -- 1362
				} -- 1362
			) -- 1362
			local col = index % cols -- 1364
			local rowIndex = math.floor(index / cols) -- 1365
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 1366
			buttons[#buttons + 1] = button -- 1370
			i = i + 1 -- 1349
		end -- 1349
	end -- 1349
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 1376
		root, -- 1377
		{ -- 1377
			w = clampNumber(viewW * 0.36, 180, 300), -- 1378
			h = MinButtonHeight, -- 1379
			text = "重看开场", -- 1380
			fontSize = 30, -- 1381
			bgHex = SelectLockedBgHex, -- 1382
			fgHex = SelectSubtitleHex, -- 1383
			borderHex = SelectBorderHex, -- 1384
			fireOn = "press", -- 1385
			onTap = function() -- 1386
				if opts.onReplayIntro ~= nil then -- 1386
					opts:onReplayIntro() -- 1387
				end -- 1387
			end -- 1386
		} -- 1386
	) or nil -- 1386
	if replayButton ~= nil then -- 1386
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 1392
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 1393
		replayButton.root.position = Vec2( -- 1394
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 1394
			by -- 1394
		) -- 1394
	end -- 1394
	root.visible = false -- 1397
	do -- 1397
		local i = 0 -- 1398
		while i < count do -- 1398
			buttons[i + 1]:setEnabled(false) -- 1398
			i = i + 1 -- 1398
		end -- 1398
	end -- 1398
	if replayButton ~= nil then -- 1398
		replayButton:setEnabled(false) -- 1399
	end -- 1399
	return { -- 1401
		root = root, -- 1402
		show = function(____, unlocked) -- 1403
			local maxUnlocked = clampNumber( -- 1404
				math.floor(unlocked), -- 1404
				0, -- 1404
				count - 1 -- 1404
			) -- 1404
			setLabelText( -- 1405
				subtitleLabel, -- 1405
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 1405
			) -- 1405
			do -- 1405
				local i = 0 -- 1406
				while i < count do -- 1406
					local button = buttons[i + 1] -- 1407
					local open = i <= maxUnlocked -- 1408
					button:setEnabled(open) -- 1409
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 1410
					if open then -- 1410
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 1411
					else -- 1411
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 1412
					end -- 1412
					i = i + 1 -- 1406
				end -- 1406
			end -- 1406
			root.visible = true -- 1414
			if replayButton ~= nil then -- 1414
				replayButton:setEnabled(true) -- 1415
			end -- 1415
		end, -- 1403
		hide = function() -- 1417
			root.visible = false -- 1418
			do -- 1418
				local i = 0 -- 1420
				while i < count do -- 1420
					buttons[i + 1]:setEnabled(false) -- 1420
					i = i + 1 -- 1420
				end -- 1420
			end -- 1420
			if replayButton ~= nil then -- 1420
				replayButton:setEnabled(false) -- 1421
			end -- 1421
		end -- 1417
	} -- 1417
end -- 1316
return ____exports -- 1316