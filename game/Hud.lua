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
function ____exports.createAimInput(parent, viewW, viewH, maxSpeed, minSpeed, speedChoices) -- 344
	local brakeOn, paintBrake, datePlate, dateLabel -- 344
	local speedMin = minSpeed ~= nil and minSpeed >= 0 and minSpeed < (maxSpeed ~= nil and maxSpeed or AimMaxSpeed) and minSpeed or AimMinSpeed -- 355
	local speedTop = maxSpeed ~= nil and maxSpeed > speedMin and maxSpeed or AimMaxSpeed -- 357
	local root = Node() -- 358
	root.size = Size(viewW, viewH) -- 359
	root.anchor = Vec2(0, 0) -- 365
	root.position = Vec2(0, 0) -- 366
	local touchLayer = Node() -- 369
	touchLayer.size = Size(viewW, viewH) -- 370
	touchLayer.anchor = Vec2(0.5, 0.5) -- 371
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 372
	touchLayer.swallowTouches = true -- 373
	root:addChild(touchLayer) -- 374
	local space = {viewW = viewW, viewH = viewH} -- 376
	local enabled = false -- 378
	local dragging = false -- 379
	--- 整屏瞄准（2D 模式）；由 Game 按视图状态同步。
	local fullScreenAim = false -- 381
	local aim = {velocity = {x = 0, y = -speedMin}, power = 0, unit = {x = 0, y = -1}} -- 382
	local probeOffset = {x = 0, y = 0} -- 385
	local dragHandler = nil -- 387
	local readyHandler = nil -- 388
	local observeHandler = nil -- 389
	local zoomHandler = nil -- 390
	local launchHandler = nil -- 391
	local skipTourHandler = nil -- 392
	local tourActiveChecker = nil -- 393
	local pressOffset = {x = 0, y = 0} -- 404
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 407
		aim = ____exports.computeAim( -- 408
			{x = 0, y = 0}, -- 408
			delta, -- 408
			AimMaxDragPx, -- 408
			speedTop, -- 408
			speedMin -- 408
		) -- 408
		if dragHandler ~= nil then -- 408
			dragHandler(aim) -- 409
		end -- 409
	end -- 407
	local aimRadius = math.max(96, viewW * 0.25) -- 416
	local mode = "none" -- 417
	local observeLast = {x = 0, y = 0} -- 418
	touchLayer:onTapBegan(function(touch) -- 419
		if not enabled then -- 419
			return -- 420
		end -- 420
		if tourActiveChecker ~= nil and tourActiveChecker() and skipTourHandler ~= nil then -- 420
			skipTourHandler() -- 422
			return -- 423
		end -- 423
		local at = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 425
		local dx = at.x - probeOffset.x -- 426
		local dy = at.y - probeOffset.y -- 427
		if fullScreenAim or math.sqrt(dx * dx + dy * dy) <= aimRadius then -- 427
			mode = "aim" -- 429
			dragging = true -- 430
			pressOffset = at -- 431
			handleDelta({x = 0, y = 0}) -- 433
		else -- 433
			mode = "observe" -- 435
			observeLast = at -- 436
		end -- 436
	end) -- 419
	touchLayer:onTapMoved(function(touch) -- 440
		if not enabled then -- 440
			return -- 441
		end -- 441
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 442
		if mode == "aim" and dragging then -- 442
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 444
		elseif mode == "observe" then -- 444
			if observeHandler ~= nil then -- 444
				observeHandler(cur.x - observeLast.x, cur.y - observeLast.y) -- 447
			end -- 447
			observeLast = cur -- 448
		end -- 448
	end) -- 440
	touchLayer:onTapEnded(function(touch) -- 452
		if not enabled then -- 452
			return -- 453
		end -- 453
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 454
		if mode == "aim" then -- 454
			dragging = false -- 456
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 457
			if readyHandler ~= nil then -- 457
				readyHandler(aim) -- 459
			end -- 459
		end -- 459
		mode = "none" -- 461
	end) -- 452
	touchLayer:onGesture(function(_center, numFingers, deltaDist, _deltaAngle) -- 465
		if not enabled or numFingers < 2 then -- 465
			return -- 466
		end -- 466
		if zoomHandler ~= nil then -- 466
			zoomHandler(deltaDist) -- 467
		end -- 467
	end) -- 465
	touchLayer.touchEnabled = false -- 475
	local brakeHandler = nil -- 480
	local BrakeButtonW = 116 -- 481
	local BrakeButtonH = 64 -- 482
	local brakeGap = 8 -- 483
	local brakeButtons = {} -- 487
	local function makeBrakeButton(text, on, x) -- 488
		local btn = createButton( -- 489
			root, -- 489
			{ -- 489
				w = BrakeButtonW, -- 490
				h = BrakeButtonH, -- 491
				text = text, -- 492
				fontSize = 30, -- 493
				bgHex = ResultButtonAltBgHex, -- 494
				fgHex = ResultButtonFgHex, -- 495
				borderHex = ResultButtonBorderHex, -- 496
				onTap = function() -- 497
					brakeOn = on -- 500
					paintBrake() -- 501
					if brakeHandler ~= nil then -- 501
						brakeHandler(on) -- 502
					end -- 502
				end -- 497
			} -- 497
		) -- 497
		btn.root.position = Vec2(x, viewH - BrakeButtonH - 20) -- 505
		brakeButtons[#brakeButtons + 1] = btn -- 506
	end -- 488
	brakeOn = false -- 508
	paintBrake = function() -- 509
		if #brakeButtons < 2 then -- 509
			return -- 510
		end -- 510
		brakeButtons[1]:setColors(brakeOn and ResultButtonAltBgHex or ResultButtonBgHex, ResultButtonFgHex) -- 511
		brakeButtons[2]:setColors(brakeOn and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 512
	end -- 509
	createPanel( -- 518
		root, -- 518
		220, -- 518
		50, -- 518
		658964, -- 518
		{alpha = 0.45} -- 518
	) -- 518
	local dvLabel = createLabel(root, "Δv — / —", 30, ResultHintHex) -- 519
	if dvLabel ~= nil then -- 519
		dvLabel.position = Vec2(24, viewH - 44) -- 521
		dvLabel.anchor = Vec2(0, 0) -- 522
	end -- 522
	local warpHandler = nil -- 532
	local dateSpan = 0 -- 533
	--- 这一关有时间轴**且**当前相态允许改日期（Flying/Result 时必须是 false）。
	local warpOn = true -- 540
	local warpVisible = true -- 541
	--- 相态是否允许改日期（由主循环每帧 setTimeEnabled 同步）。
	local warpAllowed = true -- 543
	--- 上次写进日期的文字（避免每帧重设 Label 文本）。
	local lastDateText = "" -- 545
	--- >0 = 正在按住这个方向（-1 回退 / +1 加速）；0 = 没按住。
	local warpHoldDir = 0 -- 547
	--- 距离下一次连按还有多久（秒）。
	local warpRepeatIn = 0 -- 549
	local WarpButtonW = 116 -- 550
	local WarpButtonH = 64 -- 551
	local warpButtons = {} -- 552
	local function applyWarpState() -- 553
		local vis = dateSpan > 0 -- 554
		local on = vis and warpAllowed -- 555
		if vis == warpVisible and on == warpOn then -- 555
			return -- 556
		end -- 556
		warpVisible = vis -- 557
		warpOn = on -- 558
		if not on then -- 558
			warpHoldDir = 0 -- 559
		end -- 559
		for ____, b in ipairs(warpButtons) do -- 560
			b.root.visible = vis -- 561
			b:setEnabled(on) -- 562
		end -- 562
		if dateLabel ~= nil then -- 562
			dateLabel.visible = vis -- 564
		end -- 564
		datePlate.visible = vis -- 565
	end -- 553
	local function makeWarpButton(text, dir, x) -- 567
		local btn = createButton( -- 568
			root, -- 568
			{ -- 568
				w = WarpButtonW, -- 569
				h = WarpButtonH, -- 570
				text = text, -- 571
				fontSize = 30, -- 572
				bgHex = ResultButtonAltBgHex, -- 573
				fgHex = ResultButtonFgHex, -- 574
				borderHex = ResultButtonBorderHex, -- 575
				onTap = function() -- 578
				end, -- 578
				onPressBegan = function() -- 579
					print((("[escape-velocity] warp press dir=" .. __TS__NumberToFixed(dir, 0)) .. " on=") .. (warpOn and "1" or "0")) -- 581
					if not warpOn then -- 581
						return -- 582
					end -- 582
					if warpHoldDir == dir then -- 582
						return -- 584
					end -- 584
					warpHoldDir = dir -- 585
					warpRepeatIn = WarpHoldDelaySec -- 586
					if warpHandler ~= nil then -- 586
						warpHandler(dir) -- 587
					end -- 587
				end, -- 579
				onPressEnded = function() -- 589
					print((("[escape-velocity] warp release dir=" .. __TS__NumberToFixed(dir, 0)) .. " hold=") .. __TS__NumberToFixed(warpHoldDir, 0)) -- 590
					if warpHoldDir == dir then -- 590
						warpHoldDir = 0 -- 592
					end -- 592
				end -- 589
			} -- 589
		) -- 589
		btn.root.position = Vec2(x, viewH - 96 - WarpButtonH) -- 598
		warpButtons[#warpButtons + 1] = btn -- 599
	end -- 567
	local warpLeftX = viewW - (WarpButtonW * 2 + 8) - 20 -- 601
	makeWarpButton("◀ 回退", -1, warpLeftX) -- 602
	makeWarpButton("加速 ▶", 1, warpLeftX + WarpButtonW + 8) -- 603
	datePlate = createPanel( -- 605
		root, -- 605
		300, -- 605
		50, -- 605
		658964, -- 605
		{alpha = 0.45} -- 605
	) -- 605
	datePlate.position = Vec2(warpLeftX - 316, viewH - 96 - WarpButtonH + 8) -- 606
	dateLabel = createLabel(root, "发射日期 —", 30, ResultHintHex) -- 607
	if dateLabel ~= nil then -- 607
		dateLabel.anchor = Vec2(1, 0) -- 612
		dateLabel.position = Vec2(warpLeftX - 16, viewH - 96 - WarpButtonH + 18) -- 613
	end -- 613
	local QuickRetryW = 110 -- 617
	local QuickRetryH = 50 -- 618
	local quickRetryHandler = nil -- 619
	local quickRetryBtn = createButton( -- 620
		root, -- 620
		{ -- 620
			w = QuickRetryW, -- 621
			h = QuickRetryH, -- 622
			text = "↺ 重试", -- 623
			fontSize = 26, -- 624
			bgHex = 12730636, -- 625
			fgHex = 16777215, -- 626
			borderHex = 16498468, -- 627
			fireOn = "press", -- 628
			onTap = function() -- 629
				print("[escape-velocity] quick retry tapped") -- 630
				if quickRetryHandler ~= nil then -- 630
					quickRetryHandler() -- 631
				end -- 631
			end -- 629
		} -- 629
	) -- 629
	quickRetryBtn.root.position = Vec2(viewW - QuickRetryW - 20, viewH - QuickRetryH - 20) -- 634
	local starPlateW = 180 -- 637
	local starPlateH = 46 -- 638
	createPanel( -- 639
		root, -- 639
		starPlateW, -- 639
		starPlateH, -- 639
		658964, -- 639
		{alpha = 0.55} -- 639
	).position = Vec2(viewW / 2 - starPlateW / 2, viewH - starPlateH - 22) -- 639
	local starStatusLabel = createLabel(root, "☆ ☆ ☆", 30, 16766720) -- 640
	if starStatusLabel ~= nil then -- 640
		starStatusLabel.anchor = Vec2(0.5, 0.5) -- 642
		starStatusLabel.position = Vec2(viewW / 2, viewH - starPlateH / 2 - 22) -- 643
	end -- 643
	local function updateStarsStatus(count) -- 645
		if starStatusLabel == nil then -- 645
			return -- 646
		end -- 646
		local s = "☆ ☆ ☆" -- 647
		if count == 1 then -- 647
			s = "★ ☆ ☆" -- 648
		elseif count == 2 then -- 648
			s = "★ ★ ☆" -- 649
		elseif count >= 3 then -- 649
			s = "★ ★ ★" -- 650
		end -- 650
		setLabelText(starStatusLabel, s) -- 651
	end -- 645
	local LaunchButtonW = 220 -- 656
	local LaunchButtonH = 112 -- 657
	local launchButton = createButton( -- 658
		root, -- 658
		{ -- 658
			w = LaunchButtonW, -- 659
			h = LaunchButtonH, -- 660
			text = "▲ 发射 ▲", -- 661
			fontSize = 38, -- 662
			bgHex = ResultButtonBgHex, -- 663
			fgHex = ResultButtonFgHex, -- 664
			borderHex = ResultButtonBorderHex, -- 665
			fireOn = "press", -- 666
			onTap = function() -- 667
				print("[escape-velocity] launch button fire (press)") -- 668
				if launchHandler ~= nil then -- 668
					launchHandler() -- 669
				end -- 669
			end -- 667
		} -- 667
	) -- 667
	launchButton.root.position = Vec2(viewW - LaunchButtonW - 24, 96) -- 672
	launchButton.root.visible = false -- 673
	launchButton:setEnabled(false) -- 674
	local ViewButtonW = 116 -- 678
	local ViewButtonH = 64 -- 679
	local viewHandler = nil -- 680
	local viewButton = createButton( -- 681
		root, -- 681
		{ -- 681
			w = ViewButtonW, -- 682
			h = ViewButtonH, -- 683
			text = "[ 3D ]", -- 684
			fontSize = 26, -- 685
			bgHex = ResultButtonAltBgHex, -- 686
			fgHex = ResultButtonFgHex, -- 687
			borderHex = ResultButtonBorderHex, -- 688
			fireOn = "press", -- 689
			onTap = function() -- 690
				print("[escape-velocity] view toggle fire (press)") -- 691
				if viewHandler ~= nil then -- 691
					viewHandler() -- 692
				end -- 692
			end -- 690
		} -- 690
	) -- 690
	viewButton.root.position = Vec2(viewW - ViewButtonW - 24, 96 + LaunchButtonH + 12) -- 695
	--- 上次写进按钮的文字（每帧都会被 setViewMode 调用，没变就别碰 Label）。
	local lastViewText = "2D" -- 697
	local ZoomBtnSize = 58 -- 700
	local zoomGap = 8 -- 701
	local zoomButtons = {} -- 702
	local zoomInHandler = nil -- 703
	local zoomOutHandler = nil -- 704
	local fitViewHandler = nil -- 705
	local function makeZoomButton(text, x, fontSize, onClick) -- 707
		local btn = createButton( -- 708
			root, -- 708
			{ -- 708
				w = ZoomBtnSize, -- 709
				h = ZoomBtnSize, -- 710
				text = text, -- 711
				fontSize = fontSize, -- 712
				bgHex = ResultButtonAltBgHex, -- 713
				fgHex = ResultButtonFgHex, -- 714
				borderHex = ResultButtonBorderHex, -- 715
				fireOn = "press", -- 716
				onTap = function() -- 717
					print(("[escape-velocity] zoom btn " .. text) .. " fire") -- 718
					onClick() -- 719
				end -- 717
			} -- 717
		) -- 717
		btn.root.position = Vec2(x, 96) -- 722
		btn.root.visible = false -- 723
		btn:setEnabled(false) -- 724
		zoomButtons[#zoomButtons + 1] = btn -- 725
		return btn -- 726
	end -- 707
	makeZoomButton( -- 728
		"−", -- 728
		24, -- 728
		32, -- 728
		function() -- 728
			if zoomOutHandler ~= nil then -- 728
				zoomOutHandler() -- 729
			end -- 729
		end -- 728
	) -- 728
	makeZoomButton( -- 731
		"FIT", -- 731
		24 + ZoomBtnSize + zoomGap, -- 731
		20, -- 731
		function() -- 731
			if fitViewHandler ~= nil then -- 731
				fitViewHandler() -- 732
			end -- 732
		end -- 731
	) -- 731
	makeZoomButton( -- 734
		"+", -- 734
		24 + (ZoomBtnSize + zoomGap) * 2, -- 734
		32, -- 734
		function() -- 734
			if zoomInHandler ~= nil then -- 734
				zoomInHandler() -- 735
			end -- 735
		end -- 734
	) -- 734
	local zoomControlsVisible = nil -- 737
	local function setZoomVisible(on) -- 738
		if zoomControlsVisible == on then -- 738
			return -- 739
		end -- 739
		zoomControlsVisible = on -- 740
		for ____, b in ipairs(zoomButtons) do -- 741
			b.root.visible = on -- 742
			b:setEnabled(on) -- 743
		end -- 743
	end -- 738
	setZoomVisible(false) -- 746
	local TimeBtnW = 78 -- 752
	local TimeBtnH = 64 -- 753
	local TimeRowY = 170 -- 754
	local speedUpHandler = nil -- 755
	local speedDownHandler = nil -- 756
	local pauseHandler = nil -- 757
	local slowButton = createButton( -- 759
		root, -- 759
		{ -- 759
			w = TimeBtnW, -- 760
			h = TimeBtnH, -- 760
			text = "◀ 慢", -- 760
			fontSize = 26, -- 760
			bgHex = ResultButtonAltBgHex, -- 761
			fgHex = ResultButtonFgHex, -- 761
			borderHex = ResultButtonBorderHex, -- 761
			onTap = function() -- 762
				print("[escape-velocity] speed down fire") -- 763
				if speedDownHandler ~= nil then -- 763
					speedDownHandler() -- 764
				end -- 764
			end -- 762
		} -- 762
	) -- 762
	slowButton.root.position = Vec2(24, TimeRowY) -- 767
	local pauseButton = createButton( -- 768
		root, -- 768
		{ -- 768
			w = TimeBtnW, -- 769
			h = TimeBtnH, -- 769
			text = "⏸", -- 769
			fontSize = 30, -- 769
			bgHex = ResultButtonAltBgHex, -- 770
			fgHex = ResultButtonFgHex, -- 770
			borderHex = ResultButtonBorderHex, -- 770
			onTap = function() -- 771
				print("[escape-velocity] pause toggle fire") -- 772
				if pauseHandler ~= nil then -- 772
					pauseHandler() -- 773
				end -- 773
			end -- 771
		} -- 771
	) -- 771
	pauseButton.root.position = Vec2(24 + TimeBtnW + 8, TimeRowY) -- 776
	local fastButton = createButton( -- 777
		root, -- 777
		{ -- 777
			w = TimeBtnW, -- 778
			h = TimeBtnH, -- 778
			text = "快 ▶", -- 778
			fontSize = 26, -- 778
			bgHex = ResultButtonAltBgHex, -- 779
			fgHex = ResultButtonFgHex, -- 779
			borderHex = ResultButtonBorderHex, -- 779
			onTap = function() -- 780
				print("[escape-velocity] speed up fire") -- 781
				if speedUpHandler ~= nil then -- 781
					speedUpHandler() -- 782
				end -- 782
			end -- 780
		} -- 780
	) -- 780
	fastButton.root.position = Vec2(24 + (TimeBtnW + 8) * 2, TimeRowY) -- 785
	local timePlate = createPanel( -- 788
		root, -- 788
		300, -- 788
		50, -- 788
		658964, -- 788
		{alpha = 0.45} -- 788
	) -- 788
	timePlate.position = Vec2(24 + (TimeBtnW + 8) * 3 + 4, TimeRowY + 7) -- 789
	local timeLabel = createLabel(root, "1×（现实）  T+ 0:00", 26, ResultHintHex) -- 790
	if timeLabel ~= nil then -- 790
		timeLabel.anchor = Vec2(0, 0) -- 792
		timeLabel.position = Vec2(24 + (TimeBtnW + 8) * 3 + 16, TimeRowY + 18) -- 793
	end -- 793
	--- 档位文字：pow 0 就是"1×（现实）"，别写成 1e0×。
	local function powText(pow) -- 796
		return pow <= 0 and "1×（现实）" or ("1e" .. __TS__NumberToFixed(pow, 0)) .. "×" -- 796
	end -- 796
	--- 任务时钟：真实秒 → "T+ 3天 04:12"。1× 下它每秒跳一格 —— 时间在流逝的唯一可见证据。
	local function missionText(sec) -- 798
		local s = sec > 0 and sec or 0 -- 799
		local days = math.floor(s / 86400) -- 800
		local rest = s - days * 86400 -- 801
		local hh = math.floor(rest / 3600) -- 802
		local mm = math.floor((rest - hh * 3600) / 60) -- 803
		local function pad(v) -- 804
			return (v < 10 and "0" or "") .. __TS__NumberToFixed(v, 0) -- 804
		end -- 804
		return ((("T+ " .. (days > 0 and __TS__NumberToFixed(days, 0) .. "天 " or "")) .. pad(hh)) .. ":") .. pad(mm) -- 805
	end -- 798
	local lastTimeText = "" -- 807
	local lastPaused = false -- 808
	local function setTimeControl(pow, maxPow, paused, missionSeconds) -- 809
		local txt = ((powText(pow) .. (paused and " ⏸ 暂停" or "")) .. "  ") .. missionText(missionSeconds) -- 810
		if txt ~= lastTimeText then -- 810
			lastTimeText = txt -- 812
			if timeLabel ~= nil then -- 812
				timeLabel.text = txt -- 813
			end -- 813
		end -- 813
		if paused ~= lastPaused then -- 813
			lastPaused = paused -- 816
			pauseButton:setText(paused and "▶" or "⏸") -- 817
			pauseButton:setColors(paused and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 818
		end -- 818
		fastButton:setEnabled(pow < maxPow) -- 821
		slowButton:setEnabled(pow > 0) -- 822
	end -- 809
	local DrawerW = 380 -- 826
	local DrawerH = 46 -- 827
	local missionDrawerPlate = createPanel( -- 828
		root, -- 828
		DrawerW, -- 828
		DrawerH, -- 828
		658964, -- 828
		{alpha = 0.65, borderHex = 4610157} -- 828
	) -- 828
	missionDrawerPlate.position = Vec2((viewW - DrawerW) / 2, viewH - 56) -- 829
	local missionTitleLabel = createLabel(missionDrawerPlate, "", 19, 13426158) -- 830
	if missionTitleLabel ~= nil then -- 830
		missionTitleLabel.anchor = Vec2(0, 0.5) -- 832
		missionTitleLabel.position = Vec2(14, DrawerH / 2) -- 833
	end -- 833
	local missionRocketsLabel = createLabel(missionDrawerPlate, "☆  ☆  ☆", 22, 16766720) -- 835
	if missionRocketsLabel ~= nil then -- 835
		missionRocketsLabel.anchor = Vec2(1, 0.5) -- 837
		missionRocketsLabel.position = Vec2(DrawerW - 14, DrawerH / 2) -- 838
	end -- 838
	missionDrawerPlate.visible = false -- 840
	local drawerVisible = false -- 841
	local drawerLevelTitle = "" -- 842
	local drawerRockets = 0 -- 843
	local liveFuelBonus = false -- 844
	local function updateDrawerDisplay() -- 846
		if missionTitleLabel ~= nil then -- 846
			setLabelText(missionTitleLabel, drawerLevelTitle) -- 848
		end -- 848
		if missionRocketsLabel ~= nil then -- 848
			local r1 = drawerRockets >= 1 and "★" or "☆" -- 851
			local r2 = (drawerRockets >= 2 or liveFuelBonus) and "★" or "☆" -- 852
			local r3 = drawerRockets >= 3 and "★" or "☆" -- 853
			setLabelText(missionRocketsLabel, (((r1 .. "  ") .. r2) .. "  ") .. r3) -- 854
		end -- 854
	end -- 846
	local IntroBannerW = math.min(viewW - 48, 540) -- 859
	local IntroBannerH = 68 -- 860
	local introBannerPlate = createPanel( -- 861
		root, -- 861
		IntroBannerW, -- 861
		IntroBannerH, -- 861
		658964, -- 861
		{alpha = 0.8, borderHex = 4610157} -- 861
	) -- 861
	introBannerPlate.position = Vec2((viewW - IntroBannerW) / 2, 70) -- 862
	local introBannerTitle = createLabel(introBannerPlate, "", 17, 15398143) -- 863
	if introBannerTitle ~= nil then -- 863
		introBannerTitle.anchor = Vec2(0.5, 0.5) -- 865
		introBannerTitle.position = Vec2(IntroBannerW / 2, IntroBannerH * 0.65) -- 866
	end -- 866
	local introBannerHint = createLabel(introBannerPlate, "轻触屏幕任意位置跳过运镜", 13, 9283005) -- 868
	if introBannerHint ~= nil then -- 868
		introBannerHint.anchor = Vec2(0.5, 0.5) -- 870
		introBannerHint.position = Vec2(IntroBannerW / 2, IntroBannerH * 0.28) -- 871
	end -- 871
	introBannerPlate.visible = false -- 873
	local PlaybackButtonW = 116 -- 882
	local PlaybackButtonH = 64 -- 883
	local playbackGap = 10 -- 884
	local playbackButtons = {} -- 885
	local playbackSpeeds = {} -- 886
	local playbackHandler = nil -- 887
	local speedChoice = speedChoices ~= nil and #speedChoices > 0 and speedChoices or ({1, 2, 4}) -- 890
	local playbackSpeed = speedChoice[1] -- 891
	--- 已应用到节点上的显隐状态。初值 false 如实反映"建出来就隐藏"（照 warp 按钮的教训）。
	local playbackVisible = false -- 893
	local function paintPlayback() -- 894
		do -- 894
			local i = 0 -- 895
			while i < #playbackButtons do -- 895
				local on = playbackSpeeds[i + 1] == playbackSpeed -- 896
				playbackButtons[i + 1]:setColors(on and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 897
				i = i + 1 -- 895
			end -- 895
		end -- 895
	end -- 894
	local function makePlaybackButton(speed, x) -- 900
		local btn = createButton( -- 901
			root, -- 901
			{ -- 901
				w = PlaybackButtonW, -- 902
				h = PlaybackButtonH, -- 903
				text = ____exports.playbackLabel(speed), -- 904
				fontSize = 30, -- 905
				bgHex = ResultButtonAltBgHex, -- 906
				fgHex = ResultButtonFgHex, -- 907
				borderHex = ResultButtonBorderHex, -- 908
				onTap = function() -- 909
					print(("[escape-velocity] playback button fire " .. __TS__NumberToFixed(speed, 0)) .. "x (release)") -- 911
					playbackSpeed = speed -- 912
					paintPlayback() -- 913
					if playbackHandler ~= nil then -- 913
						playbackHandler(speed) -- 914
					end -- 914
				end -- 909
			} -- 909
		) -- 909
		btn.root.position = Vec2(x, 96) -- 919
		playbackButtons[#playbackButtons + 1] = btn -- 920
		playbackSpeeds[#playbackSpeeds + 1] = speed -- 921
	end -- 900
	do -- 900
		local i = 0 -- 923
		while i < #speedChoice and i < 3 do -- 923
			makePlaybackButton(speedChoice[i + 1], 24 + (PlaybackButtonW + playbackGap) * i) -- 924
			i = i + 1 -- 923
		end -- 923
	end -- 923
	paintPlayback() -- 926
	for ____, b in ipairs(playbackButtons) do -- 928
		b.root.visible = false -- 929
		b:setEnabled(false) -- 930
	end -- 930
	local brakeRightX = viewW - BrakeButtonW - 20 -- 933
	makeBrakeButton("惯性", false, brakeRightX - BrakeButtonW - brakeGap) -- 934
	makeBrakeButton("刹车", true, brakeRightX) -- 935
	paintBrake() -- 936
	local liveBrakeHandler = nil -- 939
	local liveBrakeActive = false -- 940
	local liveBrakedState = false -- 941
	local LiveBrakeW = 220 -- 942
	local LiveBrakeH = 100 -- 943
	local liveBrakeButton = createButton( -- 944
		root, -- 944
		{ -- 944
			w = LiveBrakeW, -- 945
			h = LiveBrakeH, -- 946
			text = "BRAKE 逆喷", -- 947
			fontSize = 36, -- 948
			bgHex = 10899464, -- 949
			fgHex = 16775392, -- 950
			borderHex = 16755251, -- 951
			fireOn = "press", -- 952
			onTap = function() -- 953
				print("[escape-velocity] live brake button fire (press)") -- 954
				if liveBrakeHandler ~= nil then -- 954
					liveBrakeHandler() -- 955
				end -- 955
			end -- 953
		} -- 953
	) -- 953
	liveBrakeButton.root.position = Vec2(viewW - LiveBrakeW - 24, 96) -- 958
	liveBrakeButton.root.visible = false -- 959
	liveBrakeButton:setEnabled(false) -- 960
	local hintW = 440 -- 963
	local hintH = 50 -- 964
	local brakeHintPlate = createPanel( -- 965
		root, -- 965
		hintW, -- 965
		hintH, -- 965
		658964, -- 965
		{alpha = 0.65, borderHex = 16755251} -- 965
	) -- 965
	brakeHintPlate.position = Vec2((viewW - hintW) / 2, viewH - 240) -- 966
	local brakeHintLabel = createLabel(brakeHintPlate, "【木星捕获窗口已开启 · 按下 BRAKE 逆喷入轨】", 22, 16762939) -- 967
	if brakeHintLabel ~= nil then -- 967
		setLabelCenter(brakeHintLabel, hintW / 2, hintH / 2) -- 969
	end -- 969
	brakeHintPlate.visible = false -- 971
	parent:addChild(root) -- 973
	return { -- 975
		onDrag = function(____, callback) -- 976
			dragHandler = callback -- 977
		end, -- 976
		setEnabled = function(____, value) -- 979
			enabled = value -- 980
			touchLayer.touchEnabled = value -- 983
			if not value then -- 983
				dragging = false -- 985
				liveBrakeActive = false -- 986
				liveBrakeButton.root.visible = false -- 987
				liveBrakeButton:setEnabled(false) -- 988
				brakeHintPlate.visible = false -- 989
			end -- 989
		end, -- 979
		onBrake = function(____, callback) -- 992
			brakeHandler = callback -- 993
		end, -- 992
		setBrake = function(____, on) -- 995
			brakeOn = on -- 996
			paintBrake() -- 997
		end, -- 995
		onAimReady = function(____, callback) -- 999
			readyHandler = callback -- 1000
		end, -- 999
		onObserve = function(____, callback) -- 1002
			observeHandler = callback -- 1003
		end, -- 1002
		onZoom = function(____, callback) -- 1005
			zoomHandler = callback -- 1006
		end, -- 1005
		onLaunch = function(____, callback) -- 1008
			launchHandler = callback -- 1009
		end, -- 1008
		setArmed = function(____, armed) -- 1011
			launchButton.root.visible = armed -- 1012
			launchButton:setEnabled(armed) -- 1013
		end, -- 1011
		onViewToggle = function(____, callback) -- 1015
			viewHandler = callback -- 1016
		end, -- 1015
		setViewMode = function(____, mode) -- 1018
			if mode == lastViewText then -- 1018
				return -- 1019
			end -- 1019
			lastViewText = mode -- 1020
			local btnText = mode == "2D" and "[ 3D ]" or "[ 2D ]" -- 1022
			viewButton:setText(btnText) -- 1023
		end, -- 1018
		onPlayback = function(____, callback) -- 1025
			playbackHandler = callback -- 1026
		end, -- 1025
		setPlayback = function(____, speed) -- 1028
			if speed == playbackSpeed then -- 1028
				return -- 1029
			end -- 1029
			playbackSpeed = speed -- 1030
			paintPlayback() -- 1031
		end, -- 1028
		setPlaybackVisible = function(____, on) -- 1033
			if on == playbackVisible then -- 1033
				return -- 1034
			end -- 1034
			playbackVisible = on -- 1035
			for ____, b in ipairs(playbackButtons) do -- 1036
				b.root.visible = on -- 1037
				b:setEnabled(on) -- 1038
			end -- 1038
		end, -- 1033
		setFullScreenAim = function(____, on) -- 1041
			fullScreenAim = on -- 1042
		end, -- 1041
		onWarp = function(____, callback) -- 1044
			warpHandler = callback -- 1045
		end, -- 1044
		setDate = function(____, t0, span) -- 1047
			dateSpan = span > 0 and span or 0 -- 1048
			applyWarpState() -- 1049
			local on = dateSpan > 0 -- 1050
			local text = on and (("发射日期 " .. __TS__NumberToFixed(t0, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0) or "发射日期" -- 1051
			if text ~= lastDateText then -- 1051
				lastDateText = text -- 1053
				setLabelText(dateLabel, text) -- 1054
			end -- 1054
		end, -- 1047
		setTimeEnabled = function(____, on) -- 1057
			if warpAllowed == on then -- 1057
				return -- 1058
			end -- 1058
			warpAllowed = on -- 1059
			applyWarpState() -- 1060
		end, -- 1057
		update = function(____, dt) -- 1062
			if not warpOn or warpHoldDir == 0 then -- 1062
				return -- 1063
			end -- 1063
			warpRepeatIn = warpRepeatIn - dt -- 1064
			if warpRepeatIn > 0 then -- 1064
				return -- 1065
			end -- 1065
			warpRepeatIn = TimeWarpStep / TimeWarpRate -- 1067
			if warpHandler ~= nil then -- 1067
				warpHandler(warpHoldDir) -- 1068
			end -- 1068
		end, -- 1062
		isDragging = function() return dragging end, -- 1070
		setBurnInfo = function(____, burn, budget) -- 1071
			local b = budget < 1 and __TS__NumberToFixed(budget, 2) or __TS__NumberToFixed(budget, 0) -- 1075
			local v = burn < 1 and __TS__NumberToFixed(burn, 2) or __TS__NumberToFixed(burn, 1) -- 1076
			setLabelText(dvLabel, (("Δv " .. v) .. " / ") .. b) -- 1077
		end, -- 1071
		current = function() return aim end, -- 1079
		setProbeOffset = function(____, offset) -- 1080
			probeOffset = offset -- 1081
		end, -- 1080
		handleLocal = function(____, ____local) -- 1085
			handleDelta(____exports.localToOffset(____local, space)) -- 1086
		end, -- 1085
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 1089
		debugProbeOffset = function() return probeOffset end, -- 1090
		onLiveBrake = function(____, callback) -- 1091
			liveBrakeHandler = callback -- 1092
		end, -- 1091
		setLiveBrakeVisible = function(____, visible) -- 1094
			if liveBrakeActive == visible then -- 1094
				return -- 1095
			end -- 1095
			liveBrakeActive = visible -- 1096
			liveBrakeButton.root.visible = visible -- 1097
			liveBrakeButton:setEnabled(visible) -- 1098
			brakeHintPlate.visible = visible -- 1099
		end, -- 1094
		setLiveBraked = function(____, braked) -- 1101
			if liveBrakedState == braked then -- 1101
				return -- 1102
			end -- 1102
			liveBrakedState = braked -- 1103
			if braked then -- 1103
				liveBrakeButton:setText("已捕获入轨") -- 1105
				liveBrakeButton:setColors(1589810, 13697002) -- 1106
				liveBrakeButton:setEnabled(false) -- 1107
				if brakeHintLabel ~= nil then -- 1107
					setLabelText(brakeHintLabel, "【主发动机逆喷成功！已捕获入轨】") -- 1109
					setLabelColor(brakeHintLabel, 4122272) -- 1110
				end -- 1110
			else -- 1110
				liveBrakeButton:setText("BRAKE 逆喷") -- 1113
				liveBrakeButton:setColors(10899464, 16775392) -- 1114
				if brakeHintLabel ~= nil then -- 1114
					setLabelText(brakeHintLabel, "【木星捕获窗口已开启 · 按下 BRAKE 逆喷入轨】") -- 1116
					setLabelColor(brakeHintLabel, 16762939) -- 1117
				end -- 1117
			end -- 1117
		end, -- 1101
		onSpeedUp = function(____, callback) -- 1121
			speedUpHandler = callback -- 1122
		end, -- 1121
		onSpeedDown = function(____, callback) -- 1124
			speedDownHandler = callback -- 1125
		end, -- 1124
		onTogglePause = function(____, callback) -- 1127
			pauseHandler = callback -- 1128
		end, -- 1127
		setTimeControl = function(____, pow, maxPow, paused, missionSeconds) -- 1130
			setTimeControl(pow, maxPow, paused, missionSeconds) -- 1131
		end, -- 1130
		onZoomIn = function(____, callback) -- 1133
			zoomInHandler = callback -- 1134
		end, -- 1133
		onZoomOut = function(____, callback) -- 1136
			zoomOutHandler = callback -- 1137
		end, -- 1136
		onFitView = function(____, callback) -- 1139
			fitViewHandler = callback -- 1140
		end, -- 1139
		setZoomControlsVisible = function(____, on) -- 1142
			setZoomVisible(on) -- 1143
		end, -- 1142
		setMissionDrawer = function(____, levelName, _challenges, currentRockets) -- 1145
			drawerLevelTitle = levelName -- 1146
			drawerRockets = currentRockets -- 1147
			updateDrawerDisplay() -- 1148
		end, -- 1145
		setMissionDrawerVisible = function(____, visible) -- 1150
			if drawerVisible == visible then -- 1150
				return -- 1151
			end -- 1151
			drawerVisible = visible -- 1152
			missionDrawerPlate.visible = visible -- 1153
		end, -- 1150
		setLiveFuelChallengeStatus = function(____, achieved) -- 1155
			if liveFuelBonus == achieved then -- 1155
				return -- 1156
			end -- 1156
			liveFuelBonus = achieved -- 1157
			updateDrawerDisplay() -- 1158
		end, -- 1155
		setIntroTourBanner = function(____, title, hint) -- 1160
			if introBannerTitle ~= nil then -- 1160
				setLabelText(introBannerTitle, title) -- 1161
			end -- 1161
			if introBannerHint ~= nil and hint ~= nil then -- 1161
				setLabelText(introBannerHint, hint) -- 1162
			end -- 1162
		end, -- 1160
		setIntroTourBannerVisible = function(____, visible) -- 1164
			introBannerPlate.visible = visible -- 1165
		end, -- 1164
		onSkipTour = function(____, callback) -- 1167
			skipTourHandler = callback -- 1168
		end, -- 1167
		setTourActiveChecker = function(____, fn) -- 1170
			tourActiveChecker = fn -- 1171
		end, -- 1170
		onQuickRetry = function(____, callback) -- 1173
			quickRetryHandler = callback -- 1174
		end, -- 1173
		setStarsStatus = function(____, starsGot) -- 1176
			updateStarsStatus(starsGot) -- 1177
		end, -- 1176
		root = root -- 1179
	} -- 1179
end -- 344
local ResultBackdropHex = 329484 -- 1196
local ResultCardHex = 1252395 -- 1197
local ResultCardBorderHex = 3362938 -- 1198
local ResultLevelHex = 9417948 -- 1199
local ResultBodyHex = 14149367 -- 1200
ResultHintHex = 8229803 -- 1201
ResultButtonBgHex = 1919610 -- 1202
ResultButtonAltBgHex = 1779509 -- 1203
ResultButtonFgHex = 15398143 -- 1204
ResultButtonBorderHex = 5211846 -- 1205
local TitleSuccessHex = 8381344 -- 1206
local TitleMissedHex = 16766073 -- 1207
local TitleCrashedHex = 16743019 -- 1208
local SelectBackdropHex = 329484 -- 1210
local SelectTitleHex = 16777215 -- 1211
local SelectSubtitleHex = 10470632 -- 1212
local SelectHintHex = 7309478 -- 1213
local SelectOpenBgHex = 1919610 -- 1214
local SelectOpenFgHex = 15398143 -- 1215
local SelectLockedBgHex = 1383204 -- 1216
local SelectLockedFgHex = 6912140 -- 1217
local SelectBorderHex = 4157096 -- 1218
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 1221
	if value < lo then -- 1221
		return lo -- 1222
	end -- 1222
	if value > hi then -- 1222
		return hi -- 1223
	end -- 1223
	return value -- 1224
end -- 1221
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 1228
	if result == "success" then -- 1228
		return "借力成功" -- 1229
	end -- 1229
	if result == "crashed" then -- 1229
		return "信号中断" -- 1230
	end -- 1230
	return "错过目标" -- 1231
end -- 1228
--- 三态说明句（逐字）。
local function resultBody(result) -- 1235
	if result == "success" then -- 1235
		return "行星把探测器甩了出去，速度够了。" -- 1236
	end -- 1236
	if result == "crashed" then -- 1236
		return "探测器撞上行星，任务到此为止。" -- 1237
	end -- 1237
	return "从行星身侧掠过，没能借到那一点速度。" -- 1238
end -- 1235
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 1242
	if result == "success" then -- 1242
		return TitleSuccessHex -- 1243
	end -- 1243
	if result == "crashed" then -- 1243
		return TitleCrashedHex -- 1244
	end -- 1244
	return TitleMissedHex -- 1245
end -- 1242
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 1254
	if result == "success" then -- 1254
		return "下一关已解锁" -- 1255
	end -- 1255
	return "可重试本关，或返回关卡选择" -- 1256
end -- 1254
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 1300
	local root = createPanel( -- 1306
		parent, -- 1306
		viewW, -- 1306
		viewH, -- 1306
		ResultBackdropHex, -- 1306
		{alpha = 0.78} -- 1306
	) -- 1306
	local cardW = clampNumber(viewW * 0.9, 360, 560) -- 1308
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 480) -- 1309
	local btnH = clampNumber(viewH * 0.08, 48, 60) -- 1310
	local padX = (cardW - btnW) / 2 -- 1311
	local padY = 28 -- 1312
	local fontLevel = 24 -- 1314
	local fontRockets = 38 -- 1315
	local fontTitle = 30 -- 1316
	local fontTelemetry = 19 -- 1317
	local fontChallenge = 18 -- 1318
	local fontTotal = 20 -- 1319
	local btnFont = 24 -- 1320
	local rowGap = 12 -- 1321
	local hLevel = 28 -- 1323
	local hRockets = 42 -- 1324
	local hTitle = 34 -- 1325
	local hTelemetry = 24 -- 1326
	local hChallengeRow = 30 -- 1327
	local hChallenges = hChallengeRow * 3 -- 1328
	local hTotal = 24 -- 1329
	local cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7 -- 1331
	if cardH > viewH - 24 then -- 1331
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 1333
		cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7 -- 1334
	end -- 1334
	local card = createPanel( -- 1337
		root, -- 1337
		cardW, -- 1337
		cardH, -- 1337
		ResultCardHex, -- 1337
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 1337
	) -- 1337
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 1342
	local cursor = cardH - padY -- 1345
	cursor = cursor - hLevel -- 1347
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 1348
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 1349
	cursor = cursor - (rowGap + hRockets) -- 1351
	local rocketsLabel = createLabel(card, "", fontRockets, 16762939) -- 1352
	setLabelCenter(rocketsLabel, cardW / 2, cursor + hRockets / 2) -- 1353
	cursor = cursor - (rowGap + hTitle) -- 1355
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 1356
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 1357
	cursor = cursor - (rowGap + hTelemetry) -- 1359
	local telemetryLabel = createLabel(card, "", fontTelemetry, ResultHintHex) -- 1360
	setLabelCenter(telemetryLabel, cardW / 2, cursor + hTelemetry / 2) -- 1361
	cursor = cursor - rowGap -- 1363
	local challengeLabels = {} -- 1364
	do -- 1364
		local k = 0 -- 1365
		while k < 3 do -- 1365
			cursor = cursor - hChallengeRow -- 1366
			local cl = createLabel(card, "", fontChallenge, 10405355) -- 1367
			if cl ~= nil then -- 1367
				cl.textWidth = cardW - 60 -- 1369
				setLabelCenter(cl, cardW / 2, cursor + hChallengeRow / 2) -- 1370
				challengeLabels[#challengeLabels + 1] = cl -- 1371
			end -- 1371
			k = k + 1 -- 1365
		end -- 1365
	end -- 1365
	cursor = cursor - (rowGap + hTotal) -- 1375
	local totalLabel = createLabel(card, "", fontTotal, 16766073) -- 1376
	setLabelCenter(totalLabel, cardW / 2, cursor + hTotal / 2) -- 1377
	cursor = cursor - (rowGap + btnH) -- 1379
	local retryButton = createButton(card, { -- 1380
		w = btnW, -- 1381
		h = btnH, -- 1382
		text = "重试本关", -- 1383
		fontSize = btnFont, -- 1384
		bgHex = ResultButtonBgHex, -- 1385
		fgHex = ResultButtonFgHex, -- 1386
		borderHex = ResultButtonBorderHex, -- 1387
		fireOn = "press", -- 1388
		onTap = opts.onRetry -- 1389
	}) -- 1389
	retryButton.root.position = Vec2(padX, cursor) -- 1391
	cursor = cursor - (14 + btnH) -- 1393
	local backButton = createButton(card, { -- 1394
		w = btnW, -- 1395
		h = btnH, -- 1396
		text = "返回关卡选择", -- 1397
		fontSize = btnFont, -- 1398
		bgHex = ResultButtonAltBgHex, -- 1399
		fgHex = ResultButtonFgHex, -- 1400
		borderHex = ResultButtonBorderHex, -- 1401
		fireOn = "press", -- 1402
		onTap = opts.onBackToSelect -- 1403
	}) -- 1403
	backButton.root.position = Vec2(padX, cursor) -- 1405
	root.visible = false -- 1407
	retryButton:setEnabled(false) -- 1408
	backButton:setEnabled(false) -- 1409
	return { -- 1411
		root = root, -- 1412
		show = function(____, result, levelName, detail) -- 1413
			retryButton:setEnabled(true) -- 1414
			backButton:setEnabled(true) -- 1415
			setLabelText(levelLabel, levelName) -- 1416
			setLabelText( -- 1417
				titleLabel, -- 1417
				resultTitle(result) -- 1417
			) -- 1417
			setLabelColor( -- 1418
				titleLabel, -- 1418
				resultTitleColor(result) -- 1418
			) -- 1418
			if detail ~= nil then -- 1418
				local rCount = detail.rocketsGot -- 1421
				local rStr = "☆  ☆  ☆" -- 1422
				if rCount == 1 then -- 1422
					rStr = "★  ☆  ☆" -- 1423
				elseif rCount == 2 then -- 1423
					rStr = "★  ★  ☆" -- 1424
				elseif rCount >= 3 then -- 1424
					rStr = "★  ★  ★" -- 1425
				end -- 1425
				setLabelText(rocketsLabel, rStr) -- 1426
				setLabelColor(rocketsLabel, rCount > 0 and 16762939 or 6322324) -- 1427
				local pct = detail.dvBudget > 0 and math.floor(detail.burnDv / detail.dvBudget * 100) or 0 -- 1429
				local telemText = ((((((("点火消耗 Δv: " .. __TS__NumberToFixed(detail.burnDv, 2)) .. " / ") .. __TS__NumberToFixed(detail.dvBudget, 2)) .. " (") .. __TS__NumberToFixed(pct, 0)) .. "%) · 用时: ") .. __TS__NumberToFixed(detail.flightTime, 1)) .. "s" -- 1430
				setLabelText(telemetryLabel, telemText) -- 1431
				do -- 1431
					local k = 0 -- 1433
					while k < 3 do -- 1433
						if challengeLabels[k + 1] ~= nil then -- 1433
							if k < #detail.challenges then -- 1433
								local ok = detail.achieved[k + 1] -- 1436
								local icon = ok and "★" or "☆" -- 1437
								local rank = k == 0 and "一星" or (k == 1 and "二星" or "三星") -- 1438
								local text = (((icon .. " [") .. rank) .. "] ") .. detail.challenges[k + 1] -- 1439
								setLabelText(challengeLabels[k + 1], text) -- 1440
								setLabelColor(challengeLabels[k + 1], ok and 16762939 or 6322324) -- 1441
								challengeLabels[k + 1].visible = true -- 1442
							else -- 1442
								challengeLabels[k + 1].visible = false -- 1444
							end -- 1444
						end -- 1444
						k = k + 1 -- 1433
					end -- 1433
				end -- 1433
				setLabelText( -- 1449
					totalLabel, -- 1449
					((("全深空火箭勋章: " .. __TS__NumberToFixed(detail.totalRockets, 0)) .. " / ") .. __TS__NumberToFixed(detail.totalPossibleRockets, 0)) .. " ★" -- 1449
				) -- 1449
				if totalLabel ~= nil then -- 1449
					totalLabel.visible = true -- 1450
				end -- 1450
			else -- 1450
				setLabelText(rocketsLabel, result == "success" and "★  ☆  ☆" or "☆  ☆  ☆") -- 1452
				setLabelColor(rocketsLabel, result == "success" and 16762939 or 6322324) -- 1453
				setLabelText( -- 1454
					telemetryLabel, -- 1454
					resultBody(result) -- 1454
				) -- 1454
				do -- 1454
					local k = 0 -- 1455
					while k < #challengeLabels do -- 1455
						challengeLabels[k + 1].visible = false -- 1455
						k = k + 1 -- 1455
					end -- 1455
				end -- 1455
				if totalLabel ~= nil then -- 1455
					totalLabel.visible = false -- 1456
				end -- 1456
			end -- 1456
			root.visible = true -- 1458
		end, -- 1413
		hide = function() -- 1460
			root.visible = false -- 1461
			retryButton:setEnabled(false) -- 1462
			backButton:setEnabled(false) -- 1463
		end -- 1460
	} -- 1460
end -- 1300
local FinaleBackdropHex = 329484 -- 1478
local FinaleMainHex = 15398143 -- 1479
local FinaleSubHex = 10470632 -- 1480
--- 终章主文案（逐字；改之前先改 PLAN S3.18 与 docs/开发手册.md）。
____exports.FinaleMainText = "这就是我们整颗星球的样子 —— 而你已经从那里飞到了这里。" -- 1485
--- 终章小字：飞行距离 / 用时（纯函数，可单测）。
-- 
-- 距离是**平面单位**（关卡尺度，不是公里）—— 别在这里换算成天文单位，
-- 那一换就得把整条注释重写一遍，而玩家要的只是「飞了多远、花了多久」。
function ____exports.finaleSubtitle(distance, time) -- 1493
	return ((("飞行 " .. __TS__NumberToFixed(distance, 0)) .. " 单位 · 用时 ") .. __TS__NumberToFixed(time, 1)) .. " 秒" -- 1494
end -- 1493
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
function ____exports.createFinalePanel(parent, viewW, viewH, opts) -- 1524
	local root = createPanel( -- 1530
		parent, -- 1530
		viewW, -- 1530
		viewH, -- 1530
		FinaleBackdropHex, -- 1530
		{alpha = 0.55} -- 1530
	) -- 1530
	local fontMain = 34 -- 1532
	local fontSub = 30 -- 1533
	local btnFont = 40 -- 1534
	local mainLabel = createLabel(root, ____exports.FinaleMainText, fontMain, FinaleMainHex) -- 1536
	if mainLabel ~= nil then -- 1536
		mainLabel.textWidth = viewW * 0.88 -- 1539
		setLabelCenter(mainLabel, viewW / 2, viewH * 0.8) -- 1540
	end -- 1540
	local subLabel = createLabel(root, "", fontSub, FinaleSubHex) -- 1543
	if subLabel ~= nil then -- 1543
		setLabelCenter(subLabel, viewW / 2, viewH * 0.71) -- 1544
	end -- 1544
	local btnW = clampNumber(viewW * 0.62, MinButtonWidth, 560) -- 1546
	local btnH = clampNumber(viewH * 0.085, MinButtonHeight, 120) -- 1547
	local backButton = createButton(root, { -- 1548
		w = btnW, -- 1549
		h = btnH, -- 1550
		text = "返回关卡选择", -- 1551
		fontSize = btnFont, -- 1552
		bgHex = ResultButtonBgHex, -- 1553
		fgHex = ResultButtonFgHex, -- 1554
		borderHex = ResultButtonBorderHex, -- 1555
		fireOn = "press", -- 1557
		onTap = opts.onBackToSelect -- 1558
	}) -- 1558
	backButton.root.position = Vec2((viewW - btnW) / 2, 110) -- 1560
	root.visible = false -- 1562
	backButton:setEnabled(false) -- 1564
	return { -- 1566
		root = root, -- 1567
		show = function(____, main, sub) -- 1568
			setLabelText(mainLabel, main) -- 1569
			setLabelText(subLabel, sub) -- 1570
			backButton:setEnabled(true) -- 1571
			root.visible = true -- 1572
		end, -- 1568
		hide = function() -- 1574
			root.visible = false -- 1575
			backButton:setEnabled(false) -- 1577
		end -- 1574
	} -- 1574
end -- 1524
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 1616
	local root = createPanel( -- 1622
		parent, -- 1622
		viewW, -- 1622
		viewH, -- 1622
		SelectBackdropHex, -- 1622
		{alpha = 0.9} -- 1622
	) -- 1622
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 1624
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 1625
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 1627
	setLabelCenter( -- 1628
		subtitleLabel, -- 1628
		viewW / 2, -- 1628
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 1628
	) -- 1628
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 1630
	setLabelCenter( -- 1631
		hintLabel, -- 1631
		viewW / 2, -- 1631
		clampNumber(viewH * 0.045, 36, 90) -- 1631
	) -- 1631
	local count = #opts.levels -- 1633
	local cols = viewH > viewW and 2 or 1 -- 1636
	local rows = math.max( -- 1637
		1, -- 1637
		math.ceil(count / cols) -- 1637
	) -- 1637
	local gap = 18 -- 1638
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 1639
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 1640
	local availW = viewW * 0.84 -- 1641
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 1642
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 1643
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 1644
	local gridW = cols * btnW + gap * (cols - 1) -- 1645
	local topY = viewH - headerH -- 1646
	local buttons = {} -- 1648
	do -- 1648
		local i = 0 -- 1649
		while i < count do -- 1649
			local index = i -- 1651
			local button = createButton( -- 1652
				root, -- 1652
				{ -- 1652
					w = btnW, -- 1653
					h = btnH, -- 1654
					text = opts.levels[index + 1].name, -- 1655
					fontSize = 38, -- 1656
					bgHex = SelectLockedBgHex, -- 1657
					fgHex = SelectLockedFgHex, -- 1658
					borderHex = SelectBorderHex, -- 1659
					fireOn = "press", -- 1661
					onTap = function() return opts:onPick(index) end -- 1662
				} -- 1662
			) -- 1662
			local col = index % cols -- 1664
			local rowIndex = math.floor(index / cols) -- 1665
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 1666
			buttons[#buttons + 1] = button -- 1670
			i = i + 1 -- 1649
		end -- 1649
	end -- 1649
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 1676
		root, -- 1677
		{ -- 1677
			w = clampNumber(viewW * 0.36, 180, 300), -- 1678
			h = MinButtonHeight, -- 1679
			text = "重看开场", -- 1680
			fontSize = 30, -- 1681
			bgHex = SelectLockedBgHex, -- 1682
			fgHex = SelectSubtitleHex, -- 1683
			borderHex = SelectBorderHex, -- 1684
			fireOn = "press", -- 1685
			onTap = function() -- 1686
				if opts.onReplayIntro ~= nil then -- 1686
					opts:onReplayIntro() -- 1687
				end -- 1687
			end -- 1686
		} -- 1686
	) or nil -- 1686
	if replayButton ~= nil then -- 1686
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 1692
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 1693
		replayButton.root.position = Vec2( -- 1694
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 1694
			by -- 1694
		) -- 1694
	end -- 1694
	root.visible = false -- 1697
	do -- 1697
		local i = 0 -- 1698
		while i < count do -- 1698
			buttons[i + 1]:setEnabled(false) -- 1698
			i = i + 1 -- 1698
		end -- 1698
	end -- 1698
	if replayButton ~= nil then -- 1698
		replayButton:setEnabled(false) -- 1699
	end -- 1699
	return { -- 1701
		root = root, -- 1702
		show = function(____, unlocked) -- 1703
			local maxUnlocked = clampNumber( -- 1704
				math.floor(unlocked), -- 1704
				0, -- 1704
				count - 1 -- 1704
			) -- 1704
			setLabelText( -- 1705
				subtitleLabel, -- 1705
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 1705
			) -- 1705
			do -- 1705
				local i = 0 -- 1706
				while i < count do -- 1706
					local button = buttons[i + 1] -- 1707
					local open = i <= maxUnlocked -- 1708
					button:setEnabled(open) -- 1709
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 1710
					if open then -- 1710
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 1711
					else -- 1711
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 1712
					end -- 1712
					i = i + 1 -- 1706
				end -- 1706
			end -- 1706
			root.visible = true -- 1714
			if replayButton ~= nil then -- 1714
				replayButton:setEnabled(true) -- 1715
			end -- 1715
		end, -- 1703
		hide = function() -- 1717
			root.visible = false -- 1718
			do -- 1718
				local i = 0 -- 1720
				while i < count do -- 1720
					buttons[i + 1]:setEnabled(false) -- 1720
					i = i + 1 -- 1720
				end -- 1720
			end -- 1720
			if replayButton ~= nil then -- 1720
				replayButton:setEnabled(false) -- 1721
			end -- 1721
		end -- 1717
	} -- 1717
end -- 1616
return ____exports -- 1616