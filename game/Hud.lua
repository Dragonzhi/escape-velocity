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
function ____exports.createAimInput(parent, viewW, viewH, maxSpeed, minSpeed, speedChoices) -- 333
	local brakeOn, paintBrake, datePlate, dateLabel -- 333
	local speedMin = minSpeed ~= nil and minSpeed >= 0 and minSpeed < (maxSpeed ~= nil and maxSpeed or AimMaxSpeed) and minSpeed or AimMinSpeed -- 344
	local speedTop = maxSpeed ~= nil and maxSpeed > speedMin and maxSpeed or AimMaxSpeed -- 346
	local root = Node() -- 347
	root.size = Size(viewW, viewH) -- 348
	root.anchor = Vec2(0, 0) -- 354
	root.position = Vec2(0, 0) -- 355
	local touchLayer = Node() -- 358
	touchLayer.size = Size(viewW, viewH) -- 359
	touchLayer.anchor = Vec2(0.5, 0.5) -- 360
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 361
	touchLayer.swallowTouches = true -- 362
	root:addChild(touchLayer) -- 363
	local space = {viewW = viewW, viewH = viewH} -- 365
	local enabled = false -- 367
	local dragging = false -- 368
	--- 整屏瞄准（2D 模式）；由 Game 按视图状态同步。
	local fullScreenAim = false -- 370
	local aim = {velocity = {x = 0, y = -speedMin}, power = 0, unit = {x = 0, y = -1}} -- 371
	local probeOffset = {x = 0, y = 0} -- 374
	local dragHandler = nil -- 376
	local readyHandler = nil -- 377
	local observeHandler = nil -- 378
	local zoomHandler = nil -- 379
	local launchHandler = nil -- 380
	local pressOffset = {x = 0, y = 0} -- 391
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 394
		aim = ____exports.computeAim( -- 395
			{x = 0, y = 0}, -- 395
			delta, -- 395
			AimMaxDragPx, -- 395
			speedTop, -- 395
			speedMin -- 395
		) -- 395
		if dragHandler ~= nil then -- 395
			dragHandler(aim) -- 396
		end -- 396
	end -- 394
	local aimRadius = math.max(96, viewW * 0.25) -- 403
	local mode = "none" -- 404
	local observeLast = {x = 0, y = 0} -- 405
	touchLayer:onTapBegan(function(touch) -- 406
		if not enabled then -- 406
			return -- 407
		end -- 407
		local at = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 408
		local dx = at.x - probeOffset.x -- 409
		local dy = at.y - probeOffset.y -- 410
		if fullScreenAim or math.sqrt(dx * dx + dy * dy) <= aimRadius then -- 410
			mode = "aim" -- 412
			dragging = true -- 413
			pressOffset = at -- 414
			handleDelta({x = 0, y = 0}) -- 416
		else -- 416
			mode = "observe" -- 418
			observeLast = at -- 419
		end -- 419
	end) -- 406
	touchLayer:onTapMoved(function(touch) -- 423
		if not enabled then -- 423
			return -- 424
		end -- 424
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 425
		if mode == "aim" and dragging then -- 425
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 427
		elseif mode == "observe" then -- 427
			if observeHandler ~= nil then -- 427
				observeHandler(cur.x - observeLast.x, cur.y - observeLast.y) -- 430
			end -- 430
			observeLast = cur -- 431
		end -- 431
	end) -- 423
	touchLayer:onTapEnded(function(touch) -- 435
		if not enabled then -- 435
			return -- 436
		end -- 436
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 437
		if mode == "aim" then -- 437
			dragging = false -- 439
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 440
			if readyHandler ~= nil then -- 440
				readyHandler(aim) -- 442
			end -- 442
		end -- 442
		mode = "none" -- 444
	end) -- 435
	touchLayer:onGesture(function(_center, numFingers, deltaDist, _deltaAngle) -- 448
		if not enabled or numFingers < 2 then -- 448
			return -- 449
		end -- 449
		if zoomHandler ~= nil then -- 449
			zoomHandler(deltaDist) -- 450
		end -- 450
	end) -- 448
	touchLayer.touchEnabled = false -- 458
	local brakeHandler = nil -- 463
	local BrakeButtonW = 116 -- 464
	local BrakeButtonH = 64 -- 465
	local brakeGap = 8 -- 466
	local brakeButtons = {} -- 470
	local function makeBrakeButton(text, on, x) -- 471
		local btn = createButton( -- 472
			root, -- 472
			{ -- 472
				w = BrakeButtonW, -- 473
				h = BrakeButtonH, -- 474
				text = text, -- 475
				fontSize = 30, -- 476
				bgHex = ResultButtonAltBgHex, -- 477
				fgHex = ResultButtonFgHex, -- 478
				borderHex = ResultButtonBorderHex, -- 479
				onTap = function() -- 480
					brakeOn = on -- 483
					paintBrake() -- 484
					if brakeHandler ~= nil then -- 484
						brakeHandler(on) -- 485
					end -- 485
				end -- 480
			} -- 480
		) -- 480
		btn.root.position = Vec2(x, viewH - BrakeButtonH - 20) -- 488
		brakeButtons[#brakeButtons + 1] = btn -- 489
	end -- 471
	brakeOn = false -- 491
	paintBrake = function() -- 492
		if #brakeButtons < 2 then -- 492
			return -- 493
		end -- 493
		brakeButtons[1]:setColors(brakeOn and ResultButtonAltBgHex or ResultButtonBgHex, ResultButtonFgHex) -- 494
		brakeButtons[2]:setColors(brakeOn and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 495
	end -- 492
	createPanel( -- 501
		root, -- 501
		220, -- 501
		50, -- 501
		658964, -- 501
		{alpha = 0.45} -- 501
	) -- 501
	local dvLabel = createLabel(root, "Δv — / —", 30, ResultHintHex) -- 502
	if dvLabel ~= nil then -- 502
		dvLabel.position = Vec2(24, viewH - 44) -- 504
		dvLabel.anchor = Vec2(0, 0) -- 505
	end -- 505
	local warpHandler = nil -- 515
	local dateSpan = 0 -- 516
	--- 这一关有时间轴**且**当前相态允许改日期（Flying/Result 时必须是 false）。
	local warpOn = true -- 523
	local warpVisible = true -- 524
	--- 相态是否允许改日期（由主循环每帧 setTimeEnabled 同步）。
	local warpAllowed = true -- 526
	--- 上次写进日期的文字（避免每帧重设 Label 文本）。
	local lastDateText = "" -- 528
	--- >0 = 正在按住这个方向（-1 回退 / +1 加速）；0 = 没按住。
	local warpHoldDir = 0 -- 530
	--- 距离下一次连按还有多久（秒）。
	local warpRepeatIn = 0 -- 532
	local WarpButtonW = 116 -- 533
	local WarpButtonH = 64 -- 534
	local warpButtons = {} -- 535
	local function applyWarpState() -- 536
		local vis = dateSpan > 0 -- 537
		local on = vis and warpAllowed -- 538
		if vis == warpVisible and on == warpOn then -- 538
			return -- 539
		end -- 539
		warpVisible = vis -- 540
		warpOn = on -- 541
		if not on then -- 541
			warpHoldDir = 0 -- 542
		end -- 542
		for ____, b in ipairs(warpButtons) do -- 543
			b.root.visible = vis -- 544
			b:setEnabled(on) -- 545
		end -- 545
		if dateLabel ~= nil then -- 545
			dateLabel.visible = vis -- 547
		end -- 547
		datePlate.visible = vis -- 548
	end -- 536
	local function makeWarpButton(text, dir, x) -- 550
		local btn = createButton( -- 551
			root, -- 551
			{ -- 551
				w = WarpButtonW, -- 552
				h = WarpButtonH, -- 553
				text = text, -- 554
				fontSize = 30, -- 555
				bgHex = ResultButtonAltBgHex, -- 556
				fgHex = ResultButtonFgHex, -- 557
				borderHex = ResultButtonBorderHex, -- 558
				onTap = function() -- 561
				end, -- 561
				onPressBegan = function() -- 562
					print((("[escape-velocity] warp press dir=" .. __TS__NumberToFixed(dir, 0)) .. " on=") .. (warpOn and "1" or "0")) -- 564
					if not warpOn then -- 564
						return -- 565
					end -- 565
					if warpHoldDir == dir then -- 565
						return -- 567
					end -- 567
					warpHoldDir = dir -- 568
					warpRepeatIn = WarpHoldDelaySec -- 569
					if warpHandler ~= nil then -- 569
						warpHandler(dir) -- 570
					end -- 570
				end, -- 562
				onPressEnded = function() -- 572
					print((("[escape-velocity] warp release dir=" .. __TS__NumberToFixed(dir, 0)) .. " hold=") .. __TS__NumberToFixed(warpHoldDir, 0)) -- 573
					if warpHoldDir == dir then -- 573
						warpHoldDir = 0 -- 575
					end -- 575
				end -- 572
			} -- 572
		) -- 572
		btn.root.position = Vec2(x, viewH - 96 - WarpButtonH) -- 581
		warpButtons[#warpButtons + 1] = btn -- 582
	end -- 550
	local warpLeftX = viewW - (WarpButtonW * 2 + 8) - 20 -- 584
	makeWarpButton("◀ 回退", -1, warpLeftX) -- 585
	makeWarpButton("加速 ▶", 1, warpLeftX + WarpButtonW + 8) -- 586
	datePlate = createPanel( -- 588
		root, -- 588
		300, -- 588
		50, -- 588
		658964, -- 588
		{alpha = 0.45} -- 588
	) -- 588
	datePlate.position = Vec2(warpLeftX - 316, viewH - 96 - WarpButtonH + 8) -- 589
	dateLabel = createLabel(root, "发射日期 —", 30, ResultHintHex) -- 590
	if dateLabel ~= nil then -- 590
		dateLabel.anchor = Vec2(1, 0) -- 595
		dateLabel.position = Vec2(warpLeftX - 16, viewH - 96 - WarpButtonH + 18) -- 596
	end -- 596
	local LaunchButtonW = 220 -- 601
	local LaunchButtonH = 112 -- 602
	local launchButton = createButton( -- 603
		root, -- 603
		{ -- 603
			w = LaunchButtonW, -- 604
			h = LaunchButtonH, -- 605
			text = "▲ 发射 ▲", -- 606
			fontSize = 38, -- 607
			bgHex = ResultButtonBgHex, -- 608
			fgHex = ResultButtonFgHex, -- 609
			borderHex = ResultButtonBorderHex, -- 610
			fireOn = "press", -- 611
			onTap = function() -- 612
				print("[escape-velocity] launch button fire (press)") -- 613
				if launchHandler ~= nil then -- 613
					launchHandler() -- 614
				end -- 614
			end -- 612
		} -- 612
	) -- 612
	launchButton.root.position = Vec2(viewW - LaunchButtonW - 24, 96) -- 617
	launchButton.root.visible = false -- 618
	launchButton:setEnabled(false) -- 619
	local ViewButtonW = 116 -- 623
	local ViewButtonH = 64 -- 624
	local viewHandler = nil -- 625
	local viewButton = createButton( -- 626
		root, -- 626
		{ -- 626
			w = ViewButtonW, -- 627
			h = ViewButtonH, -- 628
			text = "[ 3D ]", -- 629
			fontSize = 26, -- 630
			bgHex = ResultButtonAltBgHex, -- 631
			fgHex = ResultButtonFgHex, -- 632
			borderHex = ResultButtonBorderHex, -- 633
			fireOn = "press", -- 634
			onTap = function() -- 635
				print("[escape-velocity] view toggle fire (press)") -- 636
				if viewHandler ~= nil then -- 636
					viewHandler() -- 637
				end -- 637
			end -- 635
		} -- 635
	) -- 635
	viewButton.root.position = Vec2(viewW - ViewButtonW - 24, 96 + LaunchButtonH + 12) -- 640
	--- 上次写进按钮的文字（每帧都会被 setViewMode 调用，没变就别碰 Label）。
	local lastViewText = "2D" -- 642
	local ZoomBtnSize = 58 -- 645
	local zoomGap = 8 -- 646
	local zoomButtons = {} -- 647
	local zoomInHandler = nil -- 648
	local zoomOutHandler = nil -- 649
	local fitViewHandler = nil -- 650
	local function makeZoomButton(text, x, fontSize, onClick) -- 652
		local btn = createButton( -- 653
			root, -- 653
			{ -- 653
				w = ZoomBtnSize, -- 654
				h = ZoomBtnSize, -- 655
				text = text, -- 656
				fontSize = fontSize, -- 657
				bgHex = ResultButtonAltBgHex, -- 658
				fgHex = ResultButtonFgHex, -- 659
				borderHex = ResultButtonBorderHex, -- 660
				fireOn = "press", -- 661
				onTap = function() -- 662
					print(("[escape-velocity] zoom btn " .. text) .. " fire") -- 663
					onClick() -- 664
				end -- 662
			} -- 662
		) -- 662
		btn.root.position = Vec2(x, 96) -- 667
		btn.root.visible = false -- 668
		btn:setEnabled(false) -- 669
		zoomButtons[#zoomButtons + 1] = btn -- 670
		return btn -- 671
	end -- 652
	makeZoomButton( -- 673
		"−", -- 673
		24, -- 673
		32, -- 673
		function() -- 673
			if zoomOutHandler ~= nil then -- 673
				zoomOutHandler() -- 674
			end -- 674
		end -- 673
	) -- 673
	makeZoomButton( -- 676
		"FIT", -- 676
		24 + ZoomBtnSize + zoomGap, -- 676
		20, -- 676
		function() -- 676
			if fitViewHandler ~= nil then -- 676
				fitViewHandler() -- 677
			end -- 677
		end -- 676
	) -- 676
	makeZoomButton( -- 679
		"+", -- 679
		24 + (ZoomBtnSize + zoomGap) * 2, -- 679
		32, -- 679
		function() -- 679
			if zoomInHandler ~= nil then -- 679
				zoomInHandler() -- 680
			end -- 680
		end -- 679
	) -- 679
	local zoomControlsVisible = nil -- 682
	local function setZoomVisible(on) -- 683
		if zoomControlsVisible == on then -- 683
			return -- 684
		end -- 684
		zoomControlsVisible = on -- 685
		for ____, b in ipairs(zoomButtons) do -- 686
			b.root.visible = on -- 687
			b:setEnabled(on) -- 688
		end -- 688
	end -- 683
	setZoomVisible(false) -- 691
	local TimeBtnW = 78 -- 697
	local TimeBtnH = 64 -- 698
	local TimeRowY = 170 -- 699
	local speedUpHandler = nil -- 700
	local speedDownHandler = nil -- 701
	local pauseHandler = nil -- 702
	local slowButton = createButton( -- 704
		root, -- 704
		{ -- 704
			w = TimeBtnW, -- 705
			h = TimeBtnH, -- 705
			text = "◀ 慢", -- 705
			fontSize = 26, -- 705
			bgHex = ResultButtonAltBgHex, -- 706
			fgHex = ResultButtonFgHex, -- 706
			borderHex = ResultButtonBorderHex, -- 706
			onTap = function() -- 707
				print("[escape-velocity] speed down fire") -- 708
				if speedDownHandler ~= nil then -- 708
					speedDownHandler() -- 709
				end -- 709
			end -- 707
		} -- 707
	) -- 707
	slowButton.root.position = Vec2(24, TimeRowY) -- 712
	local pauseButton = createButton( -- 713
		root, -- 713
		{ -- 713
			w = TimeBtnW, -- 714
			h = TimeBtnH, -- 714
			text = "⏸", -- 714
			fontSize = 30, -- 714
			bgHex = ResultButtonAltBgHex, -- 715
			fgHex = ResultButtonFgHex, -- 715
			borderHex = ResultButtonBorderHex, -- 715
			onTap = function() -- 716
				print("[escape-velocity] pause toggle fire") -- 717
				if pauseHandler ~= nil then -- 717
					pauseHandler() -- 718
				end -- 718
			end -- 716
		} -- 716
	) -- 716
	pauseButton.root.position = Vec2(24 + TimeBtnW + 8, TimeRowY) -- 721
	local fastButton = createButton( -- 722
		root, -- 722
		{ -- 722
			w = TimeBtnW, -- 723
			h = TimeBtnH, -- 723
			text = "快 ▶", -- 723
			fontSize = 26, -- 723
			bgHex = ResultButtonAltBgHex, -- 724
			fgHex = ResultButtonFgHex, -- 724
			borderHex = ResultButtonBorderHex, -- 724
			onTap = function() -- 725
				print("[escape-velocity] speed up fire") -- 726
				if speedUpHandler ~= nil then -- 726
					speedUpHandler() -- 727
				end -- 727
			end -- 725
		} -- 725
	) -- 725
	fastButton.root.position = Vec2(24 + (TimeBtnW + 8) * 2, TimeRowY) -- 730
	local timePlate = createPanel( -- 733
		root, -- 733
		300, -- 733
		50, -- 733
		658964, -- 733
		{alpha = 0.45} -- 733
	) -- 733
	timePlate.position = Vec2(24 + (TimeBtnW + 8) * 3 + 4, TimeRowY + 7) -- 734
	local timeLabel = createLabel(root, "1×（现实）  T+ 0:00", 26, ResultHintHex) -- 735
	if timeLabel ~= nil then -- 735
		timeLabel.anchor = Vec2(0, 0) -- 737
		timeLabel.position = Vec2(24 + (TimeBtnW + 8) * 3 + 16, TimeRowY + 18) -- 738
	end -- 738
	--- 档位文字：pow 0 就是"1×（现实）"，别写成 1e0×。
	local function powText(pow) -- 741
		return pow <= 0 and "1×（现实）" or ("1e" .. __TS__NumberToFixed(pow, 0)) .. "×" -- 741
	end -- 741
	--- 任务时钟：真实秒 → "T+ 3天 04:12"。1× 下它每秒跳一格 —— 时间在流逝的唯一可见证据。
	local function missionText(sec) -- 743
		local s = sec > 0 and sec or 0 -- 744
		local days = math.floor(s / 86400) -- 745
		local rest = s - days * 86400 -- 746
		local hh = math.floor(rest / 3600) -- 747
		local mm = math.floor((rest - hh * 3600) / 60) -- 748
		local function pad(v) -- 749
			return (v < 10 and "0" or "") .. __TS__NumberToFixed(v, 0) -- 749
		end -- 749
		return ((("T+ " .. (days > 0 and __TS__NumberToFixed(days, 0) .. "天 " or "")) .. pad(hh)) .. ":") .. pad(mm) -- 750
	end -- 743
	local lastTimeText = "" -- 752
	local lastPaused = false -- 753
	local function setTimeControl(pow, maxPow, paused, missionSeconds) -- 754
		local txt = ((powText(pow) .. (paused and " ⏸ 暂停" or "")) .. "  ") .. missionText(missionSeconds) -- 755
		if txt ~= lastTimeText then -- 755
			lastTimeText = txt -- 757
			if timeLabel ~= nil then -- 757
				timeLabel.text = txt -- 758
			end -- 758
		end -- 758
		if paused ~= lastPaused then -- 758
			lastPaused = paused -- 761
			pauseButton:setText(paused and "▶" or "⏸") -- 762
			pauseButton:setColors(paused and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 763
		end -- 763
		fastButton:setEnabled(pow < maxPow) -- 766
		slowButton:setEnabled(pow > 0) -- 767
	end -- 754
	local DrawerW = 380 -- 771
	local DrawerH = 46 -- 772
	local missionDrawerPlate = createPanel( -- 773
		root, -- 773
		DrawerW, -- 773
		DrawerH, -- 773
		658964, -- 773
		{alpha = 0.65, borderHex = 4610157} -- 773
	) -- 773
	missionDrawerPlate.position = Vec2((viewW - DrawerW) / 2, viewH - 56) -- 774
	local missionTitleLabel = createLabel(missionDrawerPlate, "", 19, 13426158) -- 775
	if missionTitleLabel ~= nil then -- 775
		missionTitleLabel.anchor = Vec2(0, 0.5) -- 777
		missionTitleLabel.position = Vec2(14, DrawerH / 2) -- 778
	end -- 778
	local missionRocketsLabel = createLabel(missionDrawerPlate, "☆  ☆  ☆", 22, 16766720) -- 780
	if missionRocketsLabel ~= nil then -- 780
		missionRocketsLabel.anchor = Vec2(1, 0.5) -- 782
		missionRocketsLabel.position = Vec2(DrawerW - 14, DrawerH / 2) -- 783
	end -- 783
	missionDrawerPlate.visible = false -- 785
	local drawerVisible = false -- 786
	local drawerLevelTitle = "" -- 787
	local drawerRockets = 0 -- 788
	local liveFuelBonus = false -- 789
	local function updateDrawerDisplay() -- 791
		if missionTitleLabel ~= nil then -- 791
			setLabelText(missionTitleLabel, drawerLevelTitle) -- 793
		end -- 793
		if missionRocketsLabel ~= nil then -- 793
			local r1 = drawerRockets >= 1 and "★" or "☆" -- 796
			local r2 = (drawerRockets >= 2 or liveFuelBonus) and "★" or "☆" -- 797
			local r3 = drawerRockets >= 3 and "★" or "☆" -- 798
			setLabelText(missionRocketsLabel, (((r1 .. "  ") .. r2) .. "  ") .. r3) -- 799
		end -- 799
	end -- 791
	local PlaybackButtonW = 116 -- 810
	local PlaybackButtonH = 64 -- 811
	local playbackGap = 10 -- 812
	local playbackButtons = {} -- 813
	local playbackSpeeds = {} -- 814
	local playbackHandler = nil -- 815
	local speedChoice = speedChoices ~= nil and #speedChoices > 0 and speedChoices or ({1, 2, 4}) -- 818
	local playbackSpeed = speedChoice[1] -- 819
	--- 已应用到节点上的显隐状态。初值 false 如实反映"建出来就隐藏"（照 warp 按钮的教训）。
	local playbackVisible = false -- 821
	local function paintPlayback() -- 822
		do -- 822
			local i = 0 -- 823
			while i < #playbackButtons do -- 823
				local on = playbackSpeeds[i + 1] == playbackSpeed -- 824
				playbackButtons[i + 1]:setColors(on and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 825
				i = i + 1 -- 823
			end -- 823
		end -- 823
	end -- 822
	local function makePlaybackButton(speed, x) -- 828
		local btn = createButton( -- 829
			root, -- 829
			{ -- 829
				w = PlaybackButtonW, -- 830
				h = PlaybackButtonH, -- 831
				text = ____exports.playbackLabel(speed), -- 832
				fontSize = 30, -- 833
				bgHex = ResultButtonAltBgHex, -- 834
				fgHex = ResultButtonFgHex, -- 835
				borderHex = ResultButtonBorderHex, -- 836
				onTap = function() -- 837
					print(("[escape-velocity] playback button fire " .. __TS__NumberToFixed(speed, 0)) .. "x (release)") -- 839
					playbackSpeed = speed -- 840
					paintPlayback() -- 841
					if playbackHandler ~= nil then -- 841
						playbackHandler(speed) -- 842
					end -- 842
				end -- 837
			} -- 837
		) -- 837
		btn.root.position = Vec2(x, 96) -- 847
		playbackButtons[#playbackButtons + 1] = btn -- 848
		playbackSpeeds[#playbackSpeeds + 1] = speed -- 849
	end -- 828
	do -- 828
		local i = 0 -- 851
		while i < #speedChoice and i < 3 do -- 851
			makePlaybackButton(speedChoice[i + 1], 24 + (PlaybackButtonW + playbackGap) * i) -- 852
			i = i + 1 -- 851
		end -- 851
	end -- 851
	paintPlayback() -- 854
	for ____, b in ipairs(playbackButtons) do -- 856
		b.root.visible = false -- 857
		b:setEnabled(false) -- 858
	end -- 858
	local brakeRightX = viewW - BrakeButtonW - 20 -- 861
	makeBrakeButton("惯性", false, brakeRightX - BrakeButtonW - brakeGap) -- 862
	makeBrakeButton("刹车", true, brakeRightX) -- 863
	paintBrake() -- 864
	local liveBrakeHandler = nil -- 867
	local liveBrakeActive = false -- 868
	local liveBrakedState = false -- 869
	local LiveBrakeW = 220 -- 870
	local LiveBrakeH = 100 -- 871
	local liveBrakeButton = createButton( -- 872
		root, -- 872
		{ -- 872
			w = LiveBrakeW, -- 873
			h = LiveBrakeH, -- 874
			text = "BRAKE 逆喷", -- 875
			fontSize = 36, -- 876
			bgHex = 10899464, -- 877
			fgHex = 16775392, -- 878
			borderHex = 16755251, -- 879
			fireOn = "press", -- 880
			onTap = function() -- 881
				print("[escape-velocity] live brake button fire (press)") -- 882
				if liveBrakeHandler ~= nil then -- 882
					liveBrakeHandler() -- 883
				end -- 883
			end -- 881
		} -- 881
	) -- 881
	liveBrakeButton.root.position = Vec2(viewW - LiveBrakeW - 24, 96) -- 886
	liveBrakeButton.root.visible = false -- 887
	liveBrakeButton:setEnabled(false) -- 888
	local hintW = 440 -- 891
	local hintH = 50 -- 892
	local brakeHintPlate = createPanel( -- 893
		root, -- 893
		hintW, -- 893
		hintH, -- 893
		658964, -- 893
		{alpha = 0.65, borderHex = 16755251} -- 893
	) -- 893
	brakeHintPlate.position = Vec2((viewW - hintW) / 2, viewH - 240) -- 894
	local brakeHintLabel = createLabel(brakeHintPlate, "【木星捕获窗口已开启 · 按下 BRAKE 逆喷入轨】", 22, 16762939) -- 895
	if brakeHintLabel ~= nil then -- 895
		setLabelCenter(brakeHintLabel, hintW / 2, hintH / 2) -- 897
	end -- 897
	brakeHintPlate.visible = false -- 899
	parent:addChild(root) -- 901
	return { -- 903
		onDrag = function(____, callback) -- 904
			dragHandler = callback -- 905
		end, -- 904
		setEnabled = function(____, value) -- 907
			enabled = value -- 908
			touchLayer.touchEnabled = value -- 911
			if not value then -- 911
				dragging = false -- 913
				liveBrakeActive = false -- 914
				liveBrakeButton.root.visible = false -- 915
				liveBrakeButton:setEnabled(false) -- 916
				brakeHintPlate.visible = false -- 917
			end -- 917
		end, -- 907
		onBrake = function(____, callback) -- 920
			brakeHandler = callback -- 921
		end, -- 920
		setBrake = function(____, on) -- 923
			brakeOn = on -- 924
			paintBrake() -- 925
		end, -- 923
		onAimReady = function(____, callback) -- 927
			readyHandler = callback -- 928
		end, -- 927
		onObserve = function(____, callback) -- 930
			observeHandler = callback -- 931
		end, -- 930
		onZoom = function(____, callback) -- 933
			zoomHandler = callback -- 934
		end, -- 933
		onLaunch = function(____, callback) -- 936
			launchHandler = callback -- 937
		end, -- 936
		setArmed = function(____, armed) -- 939
			launchButton.root.visible = armed -- 940
			launchButton:setEnabled(armed) -- 941
		end, -- 939
		onViewToggle = function(____, callback) -- 943
			viewHandler = callback -- 944
		end, -- 943
		setViewMode = function(____, mode) -- 946
			if mode == lastViewText then -- 946
				return -- 947
			end -- 947
			lastViewText = mode -- 948
			local btnText = mode == "2D" and "[ 3D ]" or "[ 2D ]" -- 950
			viewButton:setText(btnText) -- 951
		end, -- 946
		onPlayback = function(____, callback) -- 953
			playbackHandler = callback -- 954
		end, -- 953
		setPlayback = function(____, speed) -- 956
			if speed == playbackSpeed then -- 956
				return -- 957
			end -- 957
			playbackSpeed = speed -- 958
			paintPlayback() -- 959
		end, -- 956
		setPlaybackVisible = function(____, on) -- 961
			if on == playbackVisible then -- 961
				return -- 962
			end -- 962
			playbackVisible = on -- 963
			for ____, b in ipairs(playbackButtons) do -- 964
				b.root.visible = on -- 965
				b:setEnabled(on) -- 966
			end -- 966
		end, -- 961
		setFullScreenAim = function(____, on) -- 969
			fullScreenAim = on -- 970
		end, -- 969
		onWarp = function(____, callback) -- 972
			warpHandler = callback -- 973
		end, -- 972
		setDate = function(____, t0, span) -- 975
			dateSpan = span > 0 and span or 0 -- 976
			applyWarpState() -- 977
			local on = dateSpan > 0 -- 978
			local text = on and (("发射日期 " .. __TS__NumberToFixed(t0, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0) or "发射日期" -- 979
			if text ~= lastDateText then -- 979
				lastDateText = text -- 981
				setLabelText(dateLabel, text) -- 982
			end -- 982
		end, -- 975
		setTimeEnabled = function(____, on) -- 985
			if warpAllowed == on then -- 985
				return -- 986
			end -- 986
			warpAllowed = on -- 987
			applyWarpState() -- 988
		end, -- 985
		update = function(____, dt) -- 990
			if not warpOn or warpHoldDir == 0 then -- 990
				return -- 991
			end -- 991
			warpRepeatIn = warpRepeatIn - dt -- 992
			if warpRepeatIn > 0 then -- 992
				return -- 993
			end -- 993
			warpRepeatIn = TimeWarpStep / TimeWarpRate -- 995
			if warpHandler ~= nil then -- 995
				warpHandler(warpHoldDir) -- 996
			end -- 996
		end, -- 990
		isDragging = function() return dragging end, -- 998
		setBurnInfo = function(____, burn, budget) -- 999
			local b = budget < 1 and __TS__NumberToFixed(budget, 2) or __TS__NumberToFixed(budget, 0) -- 1003
			local v = burn < 1 and __TS__NumberToFixed(burn, 2) or __TS__NumberToFixed(burn, 1) -- 1004
			setLabelText(dvLabel, (("Δv " .. v) .. " / ") .. b) -- 1005
		end, -- 999
		current = function() return aim end, -- 1007
		setProbeOffset = function(____, offset) -- 1008
			probeOffset = offset -- 1009
		end, -- 1008
		handleLocal = function(____, ____local) -- 1013
			handleDelta(____exports.localToOffset(____local, space)) -- 1014
		end, -- 1013
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 1017
		debugProbeOffset = function() return probeOffset end, -- 1018
		onLiveBrake = function(____, callback) -- 1019
			liveBrakeHandler = callback -- 1020
		end, -- 1019
		setLiveBrakeVisible = function(____, visible) -- 1022
			if liveBrakeActive == visible then -- 1022
				return -- 1023
			end -- 1023
			liveBrakeActive = visible -- 1024
			liveBrakeButton.root.visible = visible -- 1025
			liveBrakeButton:setEnabled(visible) -- 1026
			brakeHintPlate.visible = visible -- 1027
		end, -- 1022
		setLiveBraked = function(____, braked) -- 1029
			if liveBrakedState == braked then -- 1029
				return -- 1030
			end -- 1030
			liveBrakedState = braked -- 1031
			if braked then -- 1031
				liveBrakeButton:setText("已捕获入轨") -- 1033
				liveBrakeButton:setColors(1589810, 13697002) -- 1034
				liveBrakeButton:setEnabled(false) -- 1035
				if brakeHintLabel ~= nil then -- 1035
					setLabelText(brakeHintLabel, "【主发动机逆喷成功！已捕获入轨】") -- 1037
					setLabelColor(brakeHintLabel, 4122272) -- 1038
				end -- 1038
			else -- 1038
				liveBrakeButton:setText("BRAKE 逆喷") -- 1041
				liveBrakeButton:setColors(10899464, 16775392) -- 1042
				if brakeHintLabel ~= nil then -- 1042
					setLabelText(brakeHintLabel, "【木星捕获窗口已开启 · 按下 BRAKE 逆喷入轨】") -- 1044
					setLabelColor(brakeHintLabel, 16762939) -- 1045
				end -- 1045
			end -- 1045
		end, -- 1029
		onSpeedUp = function(____, callback) -- 1049
			speedUpHandler = callback -- 1050
		end, -- 1049
		onSpeedDown = function(____, callback) -- 1052
			speedDownHandler = callback -- 1053
		end, -- 1052
		onTogglePause = function(____, callback) -- 1055
			pauseHandler = callback -- 1056
		end, -- 1055
		setTimeControl = function(____, pow, maxPow, paused, missionSeconds) -- 1058
			setTimeControl(pow, maxPow, paused, missionSeconds) -- 1059
		end, -- 1058
		onZoomIn = function(____, callback) -- 1061
			zoomInHandler = callback -- 1062
		end, -- 1061
		onZoomOut = function(____, callback) -- 1064
			zoomOutHandler = callback -- 1065
		end, -- 1064
		onFitView = function(____, callback) -- 1067
			fitViewHandler = callback -- 1068
		end, -- 1067
		setZoomControlsVisible = function(____, on) -- 1070
			setZoomVisible(on) -- 1071
		end, -- 1070
		setMissionDrawer = function(____, levelName, _challenges, currentRockets) -- 1073
			drawerLevelTitle = levelName -- 1074
			drawerRockets = currentRockets -- 1075
			updateDrawerDisplay() -- 1076
		end, -- 1073
		setMissionDrawerVisible = function(____, visible) -- 1078
			if drawerVisible == visible then -- 1078
				return -- 1079
			end -- 1079
			drawerVisible = visible -- 1080
			missionDrawerPlate.visible = visible -- 1081
		end, -- 1078
		setLiveFuelChallengeStatus = function(____, achieved) -- 1083
			if liveFuelBonus == achieved then -- 1083
				return -- 1084
			end -- 1084
			liveFuelBonus = achieved -- 1085
			updateDrawerDisplay() -- 1086
		end, -- 1083
		root = root -- 1088
	} -- 1088
end -- 333
local ResultBackdropHex = 329484 -- 1105
local ResultCardHex = 1252395 -- 1106
local ResultCardBorderHex = 3362938 -- 1107
local ResultLevelHex = 9417948 -- 1108
local ResultBodyHex = 14149367 -- 1109
ResultHintHex = 8229803 -- 1110
ResultButtonBgHex = 1919610 -- 1111
ResultButtonAltBgHex = 1779509 -- 1112
ResultButtonFgHex = 15398143 -- 1113
ResultButtonBorderHex = 5211846 -- 1114
local TitleSuccessHex = 8381344 -- 1115
local TitleMissedHex = 16766073 -- 1116
local TitleCrashedHex = 16743019 -- 1117
local SelectBackdropHex = 329484 -- 1119
local SelectTitleHex = 16777215 -- 1120
local SelectSubtitleHex = 10470632 -- 1121
local SelectHintHex = 7309478 -- 1122
local SelectOpenBgHex = 1919610 -- 1123
local SelectOpenFgHex = 15398143 -- 1124
local SelectLockedBgHex = 1383204 -- 1125
local SelectLockedFgHex = 6912140 -- 1126
local SelectBorderHex = 4157096 -- 1127
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 1130
	if value < lo then -- 1130
		return lo -- 1131
	end -- 1131
	if value > hi then -- 1131
		return hi -- 1132
	end -- 1132
	return value -- 1133
end -- 1130
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 1137
	if result == "success" then -- 1137
		return "借力成功" -- 1138
	end -- 1138
	if result == "crashed" then -- 1138
		return "信号中断" -- 1139
	end -- 1139
	return "错过目标" -- 1140
end -- 1137
--- 三态说明句（逐字）。
local function resultBody(result) -- 1144
	if result == "success" then -- 1144
		return "行星把探测器甩了出去，速度够了。" -- 1145
	end -- 1145
	if result == "crashed" then -- 1145
		return "探测器撞上行星，任务到此为止。" -- 1146
	end -- 1146
	return "从行星身侧掠过，没能借到那一点速度。" -- 1147
end -- 1144
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 1151
	if result == "success" then -- 1151
		return TitleSuccessHex -- 1152
	end -- 1152
	if result == "crashed" then -- 1152
		return TitleCrashedHex -- 1153
	end -- 1153
	return TitleMissedHex -- 1154
end -- 1151
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 1163
	if result == "success" then -- 1163
		return "下一关已解锁" -- 1164
	end -- 1164
	return "可重试本关，或返回关卡选择" -- 1165
end -- 1163
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 1209
	local root = createPanel( -- 1215
		parent, -- 1215
		viewW, -- 1215
		viewH, -- 1215
		ResultBackdropHex, -- 1215
		{alpha = 0.78} -- 1215
	) -- 1215
	local cardW = clampNumber(viewW * 0.9, 360, 560) -- 1217
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 480) -- 1218
	local btnH = clampNumber(viewH * 0.08, 48, 60) -- 1219
	local padX = (cardW - btnW) / 2 -- 1220
	local padY = 28 -- 1221
	local fontLevel = 24 -- 1223
	local fontRockets = 38 -- 1224
	local fontTitle = 30 -- 1225
	local fontTelemetry = 19 -- 1226
	local fontChallenge = 18 -- 1227
	local fontTotal = 20 -- 1228
	local btnFont = 24 -- 1229
	local rowGap = 12 -- 1230
	local hLevel = 28 -- 1232
	local hRockets = 42 -- 1233
	local hTitle = 34 -- 1234
	local hTelemetry = 24 -- 1235
	local hChallengeRow = 30 -- 1236
	local hChallenges = hChallengeRow * 3 -- 1237
	local hTotal = 24 -- 1238
	local cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7 -- 1240
	if cardH > viewH - 24 then -- 1240
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 1242
		cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7 -- 1243
	end -- 1243
	local card = createPanel( -- 1246
		root, -- 1246
		cardW, -- 1246
		cardH, -- 1246
		ResultCardHex, -- 1246
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 1246
	) -- 1246
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 1251
	local cursor = cardH - padY -- 1254
	cursor = cursor - hLevel -- 1256
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 1257
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 1258
	cursor = cursor - (rowGap + hRockets) -- 1260
	local rocketsLabel = createLabel(card, "", fontRockets, 16762939) -- 1261
	setLabelCenter(rocketsLabel, cardW / 2, cursor + hRockets / 2) -- 1262
	cursor = cursor - (rowGap + hTitle) -- 1264
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 1265
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 1266
	cursor = cursor - (rowGap + hTelemetry) -- 1268
	local telemetryLabel = createLabel(card, "", fontTelemetry, ResultHintHex) -- 1269
	setLabelCenter(telemetryLabel, cardW / 2, cursor + hTelemetry / 2) -- 1270
	cursor = cursor - rowGap -- 1272
	local challengeLabels = {} -- 1273
	do -- 1273
		local k = 0 -- 1274
		while k < 3 do -- 1274
			cursor = cursor - hChallengeRow -- 1275
			local cl = createLabel(card, "", fontChallenge, 10405355) -- 1276
			if cl ~= nil then -- 1276
				cl.textWidth = cardW - 60 -- 1278
				setLabelCenter(cl, cardW / 2, cursor + hChallengeRow / 2) -- 1279
				challengeLabels[#challengeLabels + 1] = cl -- 1280
			end -- 1280
			k = k + 1 -- 1274
		end -- 1274
	end -- 1274
	cursor = cursor - (rowGap + hTotal) -- 1284
	local totalLabel = createLabel(card, "", fontTotal, 16766073) -- 1285
	setLabelCenter(totalLabel, cardW / 2, cursor + hTotal / 2) -- 1286
	cursor = cursor - (rowGap + btnH) -- 1288
	local retryButton = createButton(card, { -- 1289
		w = btnW, -- 1290
		h = btnH, -- 1291
		text = "重试本关", -- 1292
		fontSize = btnFont, -- 1293
		bgHex = ResultButtonBgHex, -- 1294
		fgHex = ResultButtonFgHex, -- 1295
		borderHex = ResultButtonBorderHex, -- 1296
		fireOn = "press", -- 1297
		onTap = opts.onRetry -- 1298
	}) -- 1298
	retryButton.root.position = Vec2(padX, cursor) -- 1300
	cursor = cursor - (14 + btnH) -- 1302
	local backButton = createButton(card, { -- 1303
		w = btnW, -- 1304
		h = btnH, -- 1305
		text = "返回关卡选择", -- 1306
		fontSize = btnFont, -- 1307
		bgHex = ResultButtonAltBgHex, -- 1308
		fgHex = ResultButtonFgHex, -- 1309
		borderHex = ResultButtonBorderHex, -- 1310
		fireOn = "press", -- 1311
		onTap = opts.onBackToSelect -- 1312
	}) -- 1312
	backButton.root.position = Vec2(padX, cursor) -- 1314
	root.visible = false -- 1316
	retryButton:setEnabled(false) -- 1317
	backButton:setEnabled(false) -- 1318
	return { -- 1320
		root = root, -- 1321
		show = function(____, result, levelName, detail) -- 1322
			retryButton:setEnabled(true) -- 1323
			backButton:setEnabled(true) -- 1324
			setLabelText(levelLabel, levelName) -- 1325
			setLabelText( -- 1326
				titleLabel, -- 1326
				resultTitle(result) -- 1326
			) -- 1326
			setLabelColor( -- 1327
				titleLabel, -- 1327
				resultTitleColor(result) -- 1327
			) -- 1327
			if detail ~= nil then -- 1327
				local rCount = detail.rocketsGot -- 1330
				local rStr = "☆  ☆  ☆" -- 1331
				if rCount == 1 then -- 1331
					rStr = "★  ☆  ☆" -- 1332
				elseif rCount == 2 then -- 1332
					rStr = "★  ★  ☆" -- 1333
				elseif rCount >= 3 then -- 1333
					rStr = "★  ★  ★" -- 1334
				end -- 1334
				setLabelText(rocketsLabel, rStr) -- 1335
				setLabelColor(rocketsLabel, rCount > 0 and 16762939 or 6322324) -- 1336
				local pct = detail.dvBudget > 0 and math.floor(detail.burnDv / detail.dvBudget * 100) or 0 -- 1338
				local telemText = ((((((("点火消耗 Δv: " .. __TS__NumberToFixed(detail.burnDv, 2)) .. " / ") .. __TS__NumberToFixed(detail.dvBudget, 2)) .. " (") .. __TS__NumberToFixed(pct, 0)) .. "%) · 用时: ") .. __TS__NumberToFixed(detail.flightTime, 1)) .. "s" -- 1339
				setLabelText(telemetryLabel, telemText) -- 1340
				do -- 1340
					local k = 0 -- 1342
					while k < 3 do -- 1342
						if challengeLabels[k + 1] ~= nil then -- 1342
							if k < #detail.challenges then -- 1342
								local ok = detail.achieved[k + 1] -- 1345
								local icon = ok and "★" or "☆" -- 1346
								local rank = k == 0 and "一星" or (k == 1 and "二星" or "三星") -- 1347
								local text = (((icon .. " [") .. rank) .. "] ") .. detail.challenges[k + 1] -- 1348
								setLabelText(challengeLabels[k + 1], text) -- 1349
								setLabelColor(challengeLabels[k + 1], ok and 16762939 or 6322324) -- 1350
								challengeLabels[k + 1].visible = true -- 1351
							else -- 1351
								challengeLabels[k + 1].visible = false -- 1353
							end -- 1353
						end -- 1353
						k = k + 1 -- 1342
					end -- 1342
				end -- 1342
				setLabelText( -- 1358
					totalLabel, -- 1358
					((("全深空火箭勋章: " .. __TS__NumberToFixed(detail.totalRockets, 0)) .. " / ") .. __TS__NumberToFixed(detail.totalPossibleRockets, 0)) .. " ★" -- 1358
				) -- 1358
				if totalLabel ~= nil then -- 1358
					totalLabel.visible = true -- 1359
				end -- 1359
			else -- 1359
				setLabelText(rocketsLabel, result == "success" and "★  ☆  ☆" or "☆  ☆  ☆") -- 1361
				setLabelColor(rocketsLabel, result == "success" and 16762939 or 6322324) -- 1362
				setLabelText( -- 1363
					telemetryLabel, -- 1363
					resultBody(result) -- 1363
				) -- 1363
				do -- 1363
					local k = 0 -- 1364
					while k < #challengeLabels do -- 1364
						challengeLabels[k + 1].visible = false -- 1364
						k = k + 1 -- 1364
					end -- 1364
				end -- 1364
				if totalLabel ~= nil then -- 1364
					totalLabel.visible = false -- 1365
				end -- 1365
			end -- 1365
			root.visible = true -- 1367
		end, -- 1322
		hide = function() -- 1369
			root.visible = false -- 1370
			retryButton:setEnabled(false) -- 1371
			backButton:setEnabled(false) -- 1372
		end -- 1369
	} -- 1369
end -- 1209
local FinaleBackdropHex = 329484 -- 1387
local FinaleMainHex = 15398143 -- 1388
local FinaleSubHex = 10470632 -- 1389
--- 终章主文案（逐字；改之前先改 PLAN S3.18 与 docs/开发手册.md）。
____exports.FinaleMainText = "这就是我们整颗星球的样子 —— 而你已经从那里飞到了这里。" -- 1394
--- 终章小字：飞行距离 / 用时（纯函数，可单测）。
-- 
-- 距离是**平面单位**（关卡尺度，不是公里）—— 别在这里换算成天文单位，
-- 那一换就得把整条注释重写一遍，而玩家要的只是「飞了多远、花了多久」。
function ____exports.finaleSubtitle(distance, time) -- 1402
	return ((("飞行 " .. __TS__NumberToFixed(distance, 0)) .. " 单位 · 用时 ") .. __TS__NumberToFixed(time, 1)) .. " 秒" -- 1403
end -- 1402
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
function ____exports.createFinalePanel(parent, viewW, viewH, opts) -- 1433
	local root = createPanel( -- 1439
		parent, -- 1439
		viewW, -- 1439
		viewH, -- 1439
		FinaleBackdropHex, -- 1439
		{alpha = 0.55} -- 1439
	) -- 1439
	local fontMain = 34 -- 1441
	local fontSub = 30 -- 1442
	local btnFont = 40 -- 1443
	local mainLabel = createLabel(root, ____exports.FinaleMainText, fontMain, FinaleMainHex) -- 1445
	if mainLabel ~= nil then -- 1445
		mainLabel.textWidth = viewW * 0.88 -- 1448
		setLabelCenter(mainLabel, viewW / 2, viewH * 0.8) -- 1449
	end -- 1449
	local subLabel = createLabel(root, "", fontSub, FinaleSubHex) -- 1452
	if subLabel ~= nil then -- 1452
		setLabelCenter(subLabel, viewW / 2, viewH * 0.71) -- 1453
	end -- 1453
	local btnW = clampNumber(viewW * 0.62, MinButtonWidth, 560) -- 1455
	local btnH = clampNumber(viewH * 0.085, MinButtonHeight, 120) -- 1456
	local backButton = createButton(root, { -- 1457
		w = btnW, -- 1458
		h = btnH, -- 1459
		text = "返回关卡选择", -- 1460
		fontSize = btnFont, -- 1461
		bgHex = ResultButtonBgHex, -- 1462
		fgHex = ResultButtonFgHex, -- 1463
		borderHex = ResultButtonBorderHex, -- 1464
		fireOn = "press", -- 1466
		onTap = opts.onBackToSelect -- 1467
	}) -- 1467
	backButton.root.position = Vec2((viewW - btnW) / 2, 110) -- 1469
	root.visible = false -- 1471
	backButton:setEnabled(false) -- 1473
	return { -- 1475
		root = root, -- 1476
		show = function(____, main, sub) -- 1477
			setLabelText(mainLabel, main) -- 1478
			setLabelText(subLabel, sub) -- 1479
			backButton:setEnabled(true) -- 1480
			root.visible = true -- 1481
		end, -- 1477
		hide = function() -- 1483
			root.visible = false -- 1484
			backButton:setEnabled(false) -- 1486
		end -- 1483
	} -- 1483
end -- 1433
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 1525
	local root = createPanel( -- 1531
		parent, -- 1531
		viewW, -- 1531
		viewH, -- 1531
		SelectBackdropHex, -- 1531
		{alpha = 0.9} -- 1531
	) -- 1531
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 1533
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 1534
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 1536
	setLabelCenter( -- 1537
		subtitleLabel, -- 1537
		viewW / 2, -- 1537
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 1537
	) -- 1537
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 1539
	setLabelCenter( -- 1540
		hintLabel, -- 1540
		viewW / 2, -- 1540
		clampNumber(viewH * 0.045, 36, 90) -- 1540
	) -- 1540
	local count = #opts.levels -- 1542
	local cols = viewH > viewW and 2 or 1 -- 1545
	local rows = math.max( -- 1546
		1, -- 1546
		math.ceil(count / cols) -- 1546
	) -- 1546
	local gap = 18 -- 1547
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 1548
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 1549
	local availW = viewW * 0.84 -- 1550
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 1551
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 1552
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 1553
	local gridW = cols * btnW + gap * (cols - 1) -- 1554
	local topY = viewH - headerH -- 1555
	local buttons = {} -- 1557
	do -- 1557
		local i = 0 -- 1558
		while i < count do -- 1558
			local index = i -- 1560
			local button = createButton( -- 1561
				root, -- 1561
				{ -- 1561
					w = btnW, -- 1562
					h = btnH, -- 1563
					text = opts.levels[index + 1].name, -- 1564
					fontSize = 38, -- 1565
					bgHex = SelectLockedBgHex, -- 1566
					fgHex = SelectLockedFgHex, -- 1567
					borderHex = SelectBorderHex, -- 1568
					fireOn = "press", -- 1570
					onTap = function() return opts:onPick(index) end -- 1571
				} -- 1571
			) -- 1571
			local col = index % cols -- 1573
			local rowIndex = math.floor(index / cols) -- 1574
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 1575
			buttons[#buttons + 1] = button -- 1579
			i = i + 1 -- 1558
		end -- 1558
	end -- 1558
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 1585
		root, -- 1586
		{ -- 1586
			w = clampNumber(viewW * 0.36, 180, 300), -- 1587
			h = MinButtonHeight, -- 1588
			text = "重看开场", -- 1589
			fontSize = 30, -- 1590
			bgHex = SelectLockedBgHex, -- 1591
			fgHex = SelectSubtitleHex, -- 1592
			borderHex = SelectBorderHex, -- 1593
			fireOn = "press", -- 1594
			onTap = function() -- 1595
				if opts.onReplayIntro ~= nil then -- 1595
					opts:onReplayIntro() -- 1596
				end -- 1596
			end -- 1595
		} -- 1595
	) or nil -- 1595
	if replayButton ~= nil then -- 1595
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 1601
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 1602
		replayButton.root.position = Vec2( -- 1603
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 1603
			by -- 1603
		) -- 1603
	end -- 1603
	root.visible = false -- 1606
	do -- 1606
		local i = 0 -- 1607
		while i < count do -- 1607
			buttons[i + 1]:setEnabled(false) -- 1607
			i = i + 1 -- 1607
		end -- 1607
	end -- 1607
	if replayButton ~= nil then -- 1607
		replayButton:setEnabled(false) -- 1608
	end -- 1608
	return { -- 1610
		root = root, -- 1611
		show = function(____, unlocked) -- 1612
			local maxUnlocked = clampNumber( -- 1613
				math.floor(unlocked), -- 1613
				0, -- 1613
				count - 1 -- 1613
			) -- 1613
			setLabelText( -- 1614
				subtitleLabel, -- 1614
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 1614
			) -- 1614
			do -- 1614
				local i = 0 -- 1615
				while i < count do -- 1615
					local button = buttons[i + 1] -- 1616
					local open = i <= maxUnlocked -- 1617
					button:setEnabled(open) -- 1618
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 1619
					if open then -- 1619
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 1620
					else -- 1620
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 1621
					end -- 1621
					i = i + 1 -- 1615
				end -- 1615
			end -- 1615
			root.visible = true -- 1623
			if replayButton ~= nil then -- 1623
				replayButton:setEnabled(true) -- 1624
			end -- 1624
		end, -- 1612
		hide = function() -- 1626
			root.visible = false -- 1627
			do -- 1627
				local i = 0 -- 1629
				while i < count do -- 1629
					buttons[i + 1]:setEnabled(false) -- 1629
					i = i + 1 -- 1629
				end -- 1629
			end -- 1629
			if replayButton ~= nil then -- 1629
				replayButton:setEnabled(false) -- 1630
			end -- 1630
		end -- 1626
	} -- 1626
end -- 1525
return ____exports -- 1525