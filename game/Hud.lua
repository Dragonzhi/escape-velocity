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
function ____exports.computeAim(probeOffset, touchOffset, maxDragPx, maxSpeed, minSpeed) -- 72
	local speedMin = minSpeed ~= nil and minSpeed >= 0 and minSpeed < (maxSpeed ~= nil and maxSpeed or AimMaxSpeed) and minSpeed or AimMinSpeed -- 81
	local speedTop = maxSpeed ~= nil and maxSpeed > speedMin and maxSpeed or AimMaxSpeed -- 83
	local dx = touchOffset.x - probeOffset.x -- 88
	local dy = touchOffset.y - probeOffset.y -- 89
	local len = math.sqrt(dx * dx + dy * dy) -- 91
	if len < 0.000001 then -- 91
		return {velocity = {x = 0, y = -speedMin}, power = 0, unit = {x = 0, y = -1}} -- 94
	end -- 94
	local ux = dx / len -- 97
	local uy = -dy / len -- 102
	local safeMax = maxDragPx > 1 and maxDragPx or 1 -- 104
	local power = len / safeMax -- 105
	if power < 0 then -- 105
		power = 0 -- 106
	end -- 106
	if power > 1 then -- 106
		power = 1 -- 107
	end -- 107
	local speed = speedMin + (speedTop - speedMin) * power -- 109
	return {velocity = {x = ux * speed, y = uy * speed}, power = power, unit = {x = ux, y = uy}} -- 111
end -- 72
--- 把屏幕位置（**投影偏移空间**，与 `project()` 同空间）转成平面坐标。
-- 
-- 不是矄准必需（矄准只用方向），但调试与关卡设计时有用。
-- 与 `project()` 互逆（已有往返测试守着）。
function ____exports.screenToPlane(viewPoint, basis) -- 124
	local world = screenToPlaneY(viewPoint, basis, 0) -- 128
	if world == nil then -- 128
		return nil -- 129
	end -- 129
	return {x = world.x / PlaneToWorldX, y = world.z / PlaneToWorldZ} -- 131
end -- 124
--- 倍速按钮上的文字。
-- 
-- ⚠️ 不能一律 `toFixed(0)`：0.05× 会显示成「0×」（S5 的 L1 就是 0.02/0.05/0.1 三档）。
function ____exports.playbackLabel(speed) -- 139
	if speed >= 1 then -- 139
		return __TS__NumberToFixed(speed, 0) .. "×" -- 140
	end -- 140
	if speed >= 0.1 then -- 140
		return __TS__NumberToFixed(speed, 1) .. "×" -- 141
	end -- 141
	return __TS__NumberToFixed(speed, 2) .. "×" -- 142
end -- 139
--- 默认的力度→拖动像素映射（供 UI 层统一引用）。
function ____exports.defaultMaxDragPx() -- 146
	return AimMaxDragPx -- 147
end -- 146
--- 默认速度区间（供 UI 层展示）。
function ____exports.defaultSpeedRange() -- 151
	return {min = AimMinSpeed, max = AimMaxSpeed} -- 152
end -- 151
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
function ____exports.localToOffset(____local, space) -- 173
	return {x = ____local.x - space.viewW / 2, y = ____local.y - space.viewH / 2} -- 174
end -- 173
--- 反向换算（投影偏移空间 → 全屏节点局部坐标）。
function ____exports.offsetToLocal(offset, space) -- 178
	return {x = offset.x + space.viewW / 2, y = offset.y + space.viewH / 2} -- 179
end -- 178
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
function ____exports.createAimInput(parent, viewW, viewH, maxSpeed, minSpeed, speedChoices, transferTutorial) -- 351
	if transferTutorial == nil then -- 351
		transferTutorial = false -- 361
	end -- 361
	local brakeOn, paintBrake, datePlate, dateLabel -- 361
	local speedMin = minSpeed ~= nil and minSpeed >= 0 and minSpeed < (maxSpeed ~= nil and maxSpeed or AimMaxSpeed) and minSpeed or AimMinSpeed -- 363
	local speedTop = maxSpeed ~= nil and maxSpeed > speedMin and maxSpeed or AimMaxSpeed -- 365
	local root = Node() -- 366
	root.size = Size(viewW, viewH) -- 367
	root.anchor = Vec2(0, 0) -- 373
	root.position = Vec2(0, 0) -- 374
	local touchLayer = Node() -- 377
	touchLayer.size = Size(viewW, viewH) -- 378
	touchLayer.anchor = Vec2(0.5, 0.5) -- 379
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 380
	touchLayer.swallowTouches = true -- 381
	root:addChild(touchLayer) -- 382
	local space = {viewW = viewW, viewH = viewH} -- 384
	local enabled = false -- 386
	local dragging = false -- 387
	--- 整屏瞄准（2D 模式）；由 Game 按视图状态同步。
	local fullScreenAim = false -- 389
	local aim = {velocity = {x = 0, y = -speedMin}, power = 0, unit = {x = 0, y = -1}} -- 390
	local probeOffset = {x = 0, y = 0} -- 393
	local dragHandler = nil -- 395
	local readyHandler = nil -- 396
	local observeHandler = nil -- 397
	local zoomHandler = nil -- 398
	local launchHandler = nil -- 399
	local skipTourHandler = nil -- 400
	local tourActiveChecker = nil -- 401
	local pressOffset = {x = 0, y = 0} -- 412
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 415
		aim = ____exports.computeAim( -- 416
			{x = 0, y = 0}, -- 416
			delta, -- 416
			AimMaxDragPx, -- 416
			speedTop, -- 416
			speedMin -- 416
		) -- 416
		if dragHandler ~= nil then -- 416
			dragHandler(aim) -- 417
		end -- 417
	end -- 415
	local aimRadius = math.max(96, viewW * 0.25) -- 424
	local mode = "none" -- 425
	local observeLast = {x = 0, y = 0} -- 426
	touchLayer:onTapBegan(function(touch) -- 427
		if not enabled then -- 427
			return -- 428
		end -- 428
		if tourActiveChecker ~= nil and tourActiveChecker() and skipTourHandler ~= nil then -- 428
			skipTourHandler() -- 430
			return -- 431
		end -- 431
		local at = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 433
		local dx = at.x - probeOffset.x -- 434
		local dy = at.y - probeOffset.y -- 435
		if fullScreenAim or math.sqrt(dx * dx + dy * dy) <= aimRadius then -- 435
			mode = "aim" -- 437
			dragging = true -- 438
			pressOffset = at -- 439
			handleDelta({x = 0, y = 0}) -- 441
		else -- 441
			mode = "observe" -- 443
			observeLast = at -- 444
		end -- 444
	end) -- 427
	touchLayer:onTapMoved(function(touch) -- 448
		if not enabled then -- 448
			return -- 449
		end -- 449
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 450
		if mode == "aim" and dragging then -- 450
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 452
		elseif mode == "observe" then -- 452
			if observeHandler ~= nil then -- 452
				observeHandler(cur.x - observeLast.x, cur.y - observeLast.y) -- 455
			end -- 455
			observeLast = cur -- 456
		end -- 456
	end) -- 448
	touchLayer:onTapEnded(function(touch) -- 460
		if not enabled then -- 460
			return -- 461
		end -- 461
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 462
		if mode == "aim" then -- 462
			dragging = false -- 464
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 465
			if readyHandler ~= nil then -- 465
				readyHandler(aim) -- 467
			end -- 467
		end -- 467
		mode = "none" -- 469
	end) -- 460
	touchLayer:onGesture(function(_center, numFingers, deltaDist, _deltaAngle) -- 473
		if not enabled or numFingers < 2 then -- 473
			return -- 474
		end -- 474
		if zoomHandler ~= nil then -- 474
			zoomHandler(deltaDist) -- 475
		end -- 475
	end) -- 473
	touchLayer.touchEnabled = false -- 483
	local brakeHandler = nil -- 488
	local BrakeButtonW = 116 -- 489
	local BrakeButtonH = 64 -- 490
	local brakeGap = 8 -- 491
	local brakeButtons = {} -- 495
	local function makeBrakeButton(text, on, x) -- 496
		local btn = createButton( -- 497
			root, -- 497
			{ -- 497
				w = BrakeButtonW, -- 498
				h = BrakeButtonH, -- 499
				text = text, -- 500
				fontSize = 30, -- 501
				bgHex = ResultButtonAltBgHex, -- 502
				fgHex = ResultButtonFgHex, -- 503
				borderHex = ResultButtonBorderHex, -- 504
				onTap = function() -- 505
					brakeOn = on -- 508
					paintBrake() -- 509
					if brakeHandler ~= nil then -- 509
						brakeHandler(on) -- 510
					end -- 510
				end -- 505
			} -- 505
		) -- 505
		btn.root.position = Vec2(x, viewH - BrakeButtonH - 20) -- 513
		brakeButtons[#brakeButtons + 1] = btn -- 514
	end -- 496
	brakeOn = false -- 516
	paintBrake = function() -- 517
		if #brakeButtons < 2 then -- 517
			return -- 518
		end -- 518
		brakeButtons[1]:setColors(brakeOn and ResultButtonAltBgHex or ResultButtonBgHex, ResultButtonFgHex) -- 519
		brakeButtons[2]:setColors(brakeOn and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 520
	end -- 517
	createPanel( -- 526
		root, -- 526
		220, -- 526
		50, -- 526
		658964, -- 526
		{alpha = 0.45} -- 526
	) -- 526
	local dvLabel = createLabel(root, transferTutorial and "拖动调整远地点" or "Δv — / —", transferTutorial and 22 or 30, ResultHintHex) -- 527
	if dvLabel ~= nil then -- 527
		dvLabel.position = Vec2(24, viewH - (transferTutorial and 130 or 44)) -- 529
		dvLabel.anchor = Vec2(0, 0) -- 530
	end -- 530
	local warpHandler = nil -- 540
	local dateSpan = 0 -- 541
	--- 这一关有时间轴**且**当前相态允许改日期（Flying/Result 时必须是 false）。
	local warpOn = true -- 548
	local warpVisible = true -- 549
	--- 相态是否允许改日期（由主循环每帧 setTimeEnabled 同步）。
	local warpAllowed = true -- 551
	--- 上次写进日期的文字（避免每帧重设 Label 文本）。
	local lastDateText = "" -- 553
	--- >0 = 正在按住这个方向（-1 回退 / +1 加速）；0 = 没按住。
	local warpHoldDir = 0 -- 555
	--- 距离下一次连按还有多久（秒）。
	local warpRepeatIn = 0 -- 557
	local WarpButtonW = 116 -- 558
	local WarpButtonH = 64 -- 559
	local warpButtons = {} -- 560
	local function applyWarpState() -- 561
		local vis = dateSpan > 0 -- 562
		local on = vis and warpAllowed -- 563
		if vis == warpVisible and on == warpOn then -- 563
			return -- 564
		end -- 564
		warpVisible = vis -- 565
		warpOn = on -- 566
		if not on then -- 566
			warpHoldDir = 0 -- 567
		end -- 567
		for ____, b in ipairs(warpButtons) do -- 568
			b.root.visible = vis -- 569
			b:setEnabled(on) -- 570
		end -- 570
		if dateLabel ~= nil then -- 570
			dateLabel.visible = vis -- 572
		end -- 572
		datePlate.visible = vis -- 573
	end -- 561
	local function makeWarpButton(text, dir, x) -- 575
		local btn = createButton( -- 576
			root, -- 576
			{ -- 576
				w = WarpButtonW, -- 577
				h = WarpButtonH, -- 578
				text = text, -- 579
				fontSize = 30, -- 580
				bgHex = ResultButtonAltBgHex, -- 581
				fgHex = ResultButtonFgHex, -- 582
				borderHex = ResultButtonBorderHex, -- 583
				onTap = function() -- 586
				end, -- 586
				onPressBegan = function() -- 587
					print((("[escape-velocity] warp press dir=" .. __TS__NumberToFixed(dir, 0)) .. " on=") .. (warpOn and "1" or "0")) -- 589
					if not warpOn then -- 589
						return -- 590
					end -- 590
					if warpHoldDir == dir then -- 590
						return -- 592
					end -- 592
					warpHoldDir = dir -- 593
					warpRepeatIn = WarpHoldDelaySec -- 594
					if warpHandler ~= nil then -- 594
						warpHandler(dir) -- 595
					end -- 595
				end, -- 587
				onPressEnded = function() -- 597
					print((("[escape-velocity] warp release dir=" .. __TS__NumberToFixed(dir, 0)) .. " hold=") .. __TS__NumberToFixed(warpHoldDir, 0)) -- 598
					if warpHoldDir == dir then -- 598
						warpHoldDir = 0 -- 600
					end -- 600
				end -- 597
			} -- 597
		) -- 597
		btn.root.position = Vec2(x, viewH - 96 - WarpButtonH) -- 606
		warpButtons[#warpButtons + 1] = btn -- 607
	end -- 575
	local warpLeftX = viewW - (WarpButtonW * 2 + 8) - 20 -- 609
	makeWarpButton("◀ 回退", -1, warpLeftX) -- 610
	makeWarpButton("加速 ▶", 1, warpLeftX + WarpButtonW + 8) -- 611
	datePlate = createPanel( -- 613
		root, -- 613
		300, -- 613
		50, -- 613
		658964, -- 613
		{alpha = 0.45} -- 613
	) -- 613
	datePlate.position = Vec2(warpLeftX - 316, viewH - 96 - WarpButtonH + 8) -- 614
	dateLabel = createLabel(root, "发射日期 —", 30, ResultHintHex) -- 615
	if dateLabel ~= nil then -- 615
		dateLabel.anchor = Vec2(1, 0) -- 620
		dateLabel.position = Vec2(warpLeftX - 16, viewH - 96 - WarpButtonH + 18) -- 621
	end -- 621
	local QuickRetryW = 110 -- 625
	local QuickRetryH = 50 -- 626
	local quickRetryHandler = nil -- 627
	local quickRetryBtn = createButton( -- 628
		root, -- 628
		{ -- 628
			w = QuickRetryW, -- 629
			h = QuickRetryH, -- 630
			text = "↺ 重试", -- 631
			fontSize = 26, -- 632
			bgHex = 12730636, -- 633
			fgHex = 16777215, -- 634
			borderHex = 16498468, -- 635
			fireOn = "press", -- 636
			onTap = function() -- 637
				print("[escape-velocity] quick retry tapped") -- 638
				if quickRetryHandler ~= nil then -- 638
					quickRetryHandler() -- 639
				end -- 639
			end -- 637
		} -- 637
	) -- 637
	quickRetryBtn.root.position = Vec2(viewW - QuickRetryW - 20, viewH - QuickRetryH - 20) -- 642
	local starPlateW = 180 -- 645
	local starPlateH = 46 -- 646
	local starPlate = createPanel( -- 647
		root, -- 647
		starPlateW, -- 647
		starPlateH, -- 647
		658964, -- 647
		{alpha = 0.55} -- 647
	) -- 647
	starPlate.position = Vec2(viewW / 2 - starPlateW / 2, viewH - starPlateH - 22) -- 648
	starPlate.visible = not transferTutorial -- 649
	local starStatusLabel = createLabel(root, "☆ ☆ ☆", 30, 16766720) -- 650
	if starStatusLabel ~= nil then -- 650
		starStatusLabel.anchor = Vec2(0.5, 0.5) -- 652
		starStatusLabel.position = Vec2(viewW / 2, viewH - starPlateH / 2 - 22) -- 653
	end -- 653
	local function updateStarsStatus(count) -- 655
		if starStatusLabel == nil then -- 655
			return -- 656
		end -- 656
		if transferTutorial then -- 656
			starStatusLabel.visible = false -- 657
			return -- 657
		end -- 657
		local s = "☆ ☆ ☆" -- 658
		if count == 1 then -- 658
			s = "★ ☆ ☆" -- 659
		elseif count == 2 then -- 659
			s = "★ ★ ☆" -- 660
		elseif count >= 3 then -- 660
			s = "★ ★ ★" -- 661
		end -- 661
		setLabelText(starStatusLabel, s) -- 662
	end -- 655
	local LaunchButtonW = 220 -- 667
	local LaunchButtonH = 112 -- 668
	local launchButton = createButton( -- 669
		root, -- 669
		{ -- 669
			w = LaunchButtonW, -- 670
			h = LaunchButtonH, -- 671
			text = "▲ 发射 ▲", -- 672
			fontSize = 38, -- 673
			bgHex = ResultButtonBgHex, -- 674
			fgHex = ResultButtonFgHex, -- 675
			borderHex = ResultButtonBorderHex, -- 676
			fireOn = "press", -- 677
			onTap = function() -- 678
				print("[escape-velocity] launch button fire (press)") -- 679
				if launchHandler ~= nil then -- 679
					launchHandler() -- 680
				end -- 680
			end -- 678
		} -- 678
	) -- 678
	launchButton.root.position = Vec2(viewW - LaunchButtonW - 24, 96) -- 683
	launchButton.root.visible = false -- 684
	launchButton:setEnabled(false) -- 685
	local CancelButtonW = 160 -- 688
	local CancelButtonH = 72 -- 689
	local cancelAimHandler = nil -- 690
	local cancelAimButton = createButton( -- 691
		root, -- 691
		{ -- 691
			w = CancelButtonW, -- 692
			h = CancelButtonH, -- 693
			text = "✕ 取消", -- 694
			fontSize = 28, -- 695
			bgHex = ResultButtonAltBgHex, -- 696
			fgHex = ResultButtonFgHex, -- 697
			borderHex = ResultButtonBorderHex, -- 698
			fireOn = "press", -- 699
			onTap = function() -- 700
				print("[escape-velocity] cancel aim fire (press)") -- 701
				if cancelAimHandler ~= nil then -- 701
					cancelAimHandler() -- 702
				end -- 702
			end -- 700
		} -- 700
	) -- 700
	cancelAimButton.root.position = Vec2(viewW - LaunchButtonW - CancelButtonW - 40, 116) -- 705
	cancelAimButton.root.visible = false -- 706
	cancelAimButton:setEnabled(false) -- 707
	local ViewButtonW = 116 -- 711
	local ViewButtonH = 64 -- 712
	local viewHandler = nil -- 713
	local viewButton = createButton( -- 714
		root, -- 714
		{ -- 714
			w = ViewButtonW, -- 715
			h = ViewButtonH, -- 716
			text = "[ 3D ]", -- 717
			fontSize = 26, -- 718
			bgHex = ResultButtonAltBgHex, -- 719
			fgHex = ResultButtonFgHex, -- 720
			borderHex = ResultButtonBorderHex, -- 721
			fireOn = "press", -- 722
			onTap = function() -- 723
				print("[escape-velocity] view toggle fire (press)") -- 724
				if viewHandler ~= nil then -- 724
					viewHandler() -- 725
				end -- 725
			end -- 723
		} -- 723
	) -- 723
	viewButton.root.position = Vec2(viewW - ViewButtonW - 24, 96 + LaunchButtonH + 12) -- 728
	--- 上次写进按钮的文字（每帧都会被 setViewMode 调用，没变就别碰 Label）。
	local lastViewText = "2D" -- 730
	local cameraFocusHandler = nil -- 733
	local endViewingHandler = nil -- 734
	local cameraFocusButton = transferTutorial and createButton( -- 735
		root, -- 735
		{ -- 735
			w = 260, -- 736
			h = 58, -- 736
			text = "镜头 · 自动", -- 736
			fontSize = 22, -- 736
			bgHex = ResultButtonAltBgHex, -- 737
			fgHex = ResultButtonFgHex, -- 737
			borderHex = ResultButtonBorderHex, -- 737
			fireOn = "press", -- 737
			onTap = function() -- 738
				if cameraFocusHandler ~= nil then -- 738
					cameraFocusHandler() -- 738
				end -- 738
			end -- 738
		} -- 738
	) or nil -- 738
	local endViewingButton = transferTutorial and createButton( -- 740
		root, -- 740
		{ -- 740
			w = 220, -- 741
			h = LaunchButtonH, -- 741
			text = "结束观赏", -- 741
			fontSize = 26, -- 741
			bgHex = ResultButtonAltBgHex, -- 742
			fgHex = ResultButtonFgHex, -- 742
			borderHex = ResultButtonBorderHex, -- 742
			fireOn = "press", -- 742
			onTap = function() -- 743
				if endViewingHandler ~= nil then -- 743
					endViewingHandler() -- 743
				end -- 743
			end -- 743
		} -- 743
	) or nil -- 743
	if cameraFocusButton ~= nil then -- 743
		cameraFocusButton.root.position = Vec2(24, 266) -- 745
		cameraFocusButton.root.visible = false -- 745
		cameraFocusButton:setEnabled(false) -- 745
	end -- 745
	if endViewingButton ~= nil then -- 745
		endViewingButton.root.position = Vec2(viewW - 244, 96) -- 746
		endViewingButton.root.visible = false -- 746
		endViewingButton:setEnabled(false) -- 746
	end -- 746
	local ____transferTutorial_0 -- 747
	if transferTutorial then -- 747
		____transferTutorial_0 = createLabel(root, "", 24, ResultHintHex) -- 747
	else -- 747
		____transferTutorial_0 = nil -- 747
	end -- 747
	local viewingLabel = ____transferTutorial_0 -- 747
	if viewingLabel ~= nil then -- 747
		viewingLabel.position = Vec2(24, viewH - 130) -- 748
		viewingLabel.anchor = Vec2(0, 0) -- 748
		viewingLabel.visible = false -- 748
	end -- 748
	local viewingKey = "" -- 749
	local ZoomBtnSize = 58 -- 752
	local zoomGap = 8 -- 753
	local zoomButtons = {} -- 754
	local zoomInHandler = nil -- 755
	local zoomOutHandler = nil -- 756
	local fitViewHandler = nil -- 757
	local function makeZoomButton(text, x, fontSize, onClick) -- 759
		local btn = createButton( -- 760
			root, -- 760
			{ -- 760
				w = ZoomBtnSize, -- 761
				h = ZoomBtnSize, -- 762
				text = text, -- 763
				fontSize = fontSize, -- 764
				bgHex = ResultButtonAltBgHex, -- 765
				fgHex = ResultButtonFgHex, -- 766
				borderHex = ResultButtonBorderHex, -- 767
				fireOn = "press", -- 768
				onTap = function() -- 769
					print(("[escape-velocity] zoom btn " .. text) .. " fire") -- 770
					onClick() -- 771
				end -- 769
			} -- 769
		) -- 769
		btn.root.position = Vec2(x, 96) -- 774
		btn.root.visible = false -- 775
		btn:setEnabled(false) -- 776
		zoomButtons[#zoomButtons + 1] = btn -- 777
		return btn -- 778
	end -- 759
	makeZoomButton( -- 780
		"−", -- 780
		24, -- 780
		32, -- 780
		function() -- 780
			if zoomOutHandler ~= nil then -- 780
				zoomOutHandler() -- 781
			end -- 781
		end -- 780
	) -- 780
	makeZoomButton( -- 783
		"FIT", -- 783
		24 + ZoomBtnSize + zoomGap, -- 783
		20, -- 783
		function() -- 783
			if fitViewHandler ~= nil then -- 783
				fitViewHandler() -- 784
			end -- 784
		end -- 783
	) -- 783
	makeZoomButton( -- 786
		"+", -- 786
		24 + (ZoomBtnSize + zoomGap) * 2, -- 786
		32, -- 786
		function() -- 786
			if zoomInHandler ~= nil then -- 786
				zoomInHandler() -- 787
			end -- 787
		end -- 786
	) -- 786
	local zoomControlsVisible = nil -- 789
	local function setZoomVisible(on) -- 790
		if zoomControlsVisible == on then -- 790
			return -- 791
		end -- 791
		zoomControlsVisible = on -- 792
		for ____, b in ipairs(zoomButtons) do -- 793
			b.root.visible = on -- 794
			b:setEnabled(on) -- 795
		end -- 795
	end -- 790
	setZoomVisible(false) -- 798
	local TimeBtnW = 78 -- 804
	local TimeBtnH = 64 -- 805
	local TimeRowY = 170 -- 806
	local speedUpHandler = nil -- 807
	local speedDownHandler = nil -- 808
	local pauseHandler = nil -- 809
	local slowButton = createButton( -- 811
		root, -- 811
		{ -- 811
			w = TimeBtnW, -- 812
			h = TimeBtnH, -- 812
			text = "◀ 慢", -- 812
			fontSize = 26, -- 812
			bgHex = ResultButtonAltBgHex, -- 813
			fgHex = ResultButtonFgHex, -- 813
			borderHex = ResultButtonBorderHex, -- 813
			onTap = function() -- 814
				print("[escape-velocity] speed down fire") -- 815
				if speedDownHandler ~= nil then -- 815
					speedDownHandler() -- 816
				end -- 816
			end -- 814
		} -- 814
	) -- 814
	slowButton.root.position = Vec2(24, TimeRowY) -- 819
	local pauseButton = createButton( -- 820
		root, -- 820
		{ -- 820
			w = TimeBtnW, -- 821
			h = TimeBtnH, -- 821
			text = "⏸", -- 821
			fontSize = 30, -- 821
			bgHex = ResultButtonAltBgHex, -- 822
			fgHex = ResultButtonFgHex, -- 822
			borderHex = ResultButtonBorderHex, -- 822
			onTap = function() -- 823
				print("[escape-velocity] pause toggle fire") -- 824
				if pauseHandler ~= nil then -- 824
					pauseHandler() -- 825
				end -- 825
			end -- 823
		} -- 823
	) -- 823
	pauseButton.root.position = Vec2(24 + TimeBtnW + 8, TimeRowY) -- 828
	local fastButton = createButton( -- 829
		root, -- 829
		{ -- 829
			w = TimeBtnW, -- 830
			h = TimeBtnH, -- 830
			text = "快 ▶", -- 830
			fontSize = 26, -- 830
			bgHex = ResultButtonAltBgHex, -- 831
			fgHex = ResultButtonFgHex, -- 831
			borderHex = ResultButtonBorderHex, -- 831
			onTap = function() -- 832
				print("[escape-velocity] speed up fire") -- 833
				if speedUpHandler ~= nil then -- 833
					speedUpHandler() -- 834
				end -- 834
			end -- 832
		} -- 832
	) -- 832
	fastButton.root.position = Vec2(24 + (TimeBtnW + 8) * 2, TimeRowY) -- 837
	local timePlate = createPanel( -- 840
		root, -- 840
		300, -- 840
		50, -- 840
		658964, -- 840
		{alpha = 0.45} -- 840
	) -- 840
	timePlate.position = transferTutorial and Vec2(24, viewH - 190) or Vec2(24 + (TimeBtnW + 8) * 3 + 4, TimeRowY + 7) -- 841
	local timeLabel = createLabel(root, "1×（现实）  T+ 0:00", transferTutorial and 22 or 26, ResultHintHex) -- 842
	if timeLabel ~= nil then -- 842
		timeLabel.anchor = Vec2(0, 0) -- 844
		timeLabel.position = transferTutorial and Vec2(36, viewH - 179) or Vec2(24 + (TimeBtnW + 8) * 3 + 16, TimeRowY + 18) -- 845
	end -- 845
	--- 档位文字：pow 0 就是"1×（现实）"，别写成 1e0×。
	local function powText(pow) -- 848
		return pow <= 0 and "1×（现实）" or ("1e" .. __TS__NumberToFixed(pow, 0)) .. "×" -- 848
	end -- 848
	--- 任务时钟：真实秒 → "T+ 3天 04:12"。1× 下它每秒跳一格 —— 时间在流逝的唯一可见证据。
	local function missionText(sec) -- 850
		local s = sec > 0 and sec or 0 -- 851
		local days = math.floor(s / 86400) -- 852
		local rest = s - days * 86400 -- 853
		local hh = math.floor(rest / 3600) -- 854
		local mm = math.floor((rest - hh * 3600) / 60) -- 855
		local function pad(v) -- 856
			return (v < 10 and "0" or "") .. __TS__NumberToFixed(v, 0) -- 856
		end -- 856
		return ((("T+ " .. (days > 0 and __TS__NumberToFixed(days, 0) .. "天 " or "")) .. pad(hh)) .. ":") .. pad(mm) -- 857
	end -- 850
	local lastTimeText = "" -- 859
	local lastPaused = false -- 860
	local function setTimeControl(pow, maxPow, paused, missionSeconds, actualRate) -- 861
		local txt = (((transferTutorial and actualRate ~= nil and __TS__NumberToFixed(actualRate, 2) .. "×" or powText(pow)) .. (paused and " ⏸ 暂停" or "")) .. "  ") .. (transferTutorial and ("T+ " .. __TS__NumberToFixed(missionSeconds, 1)) .. "s" or missionText(missionSeconds)) -- 862
		if txt ~= lastTimeText then -- 862
			lastTimeText = txt -- 864
			if timeLabel ~= nil then -- 864
				timeLabel.text = txt -- 865
			end -- 865
		end -- 865
		if paused ~= lastPaused then -- 865
			lastPaused = paused -- 868
			pauseButton:setText(paused and "▶" or "⏸") -- 869
			pauseButton:setColors(paused and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 870
		end -- 870
		fastButton:setEnabled(pow < maxPow) -- 873
		slowButton:setEnabled(pow > 0) -- 874
	end -- 861
	local DrawerW = 380 -- 878
	local DrawerH = 46 -- 879
	local missionDrawerPlate = createPanel( -- 880
		root, -- 880
		DrawerW, -- 880
		DrawerH, -- 880
		658964, -- 880
		{alpha = 0.65, borderHex = 4610157} -- 880
	) -- 880
	missionDrawerPlate.position = Vec2(transferTutorial and 24 or (viewW - DrawerW) / 2, viewH - 56) -- 881
	local missionTitleLabel = createLabel(missionDrawerPlate, "", 19, 13426158) -- 882
	if missionTitleLabel ~= nil then -- 882
		missionTitleLabel.anchor = Vec2(0, 0.5) -- 884
		missionTitleLabel.position = Vec2(14, DrawerH / 2) -- 885
	end -- 885
	local missionRocketsLabel = createLabel(missionDrawerPlate, "☆  ☆  ☆", 22, 16766720) -- 887
	if missionRocketsLabel ~= nil then -- 887
		missionRocketsLabel.anchor = Vec2(1, 0.5) -- 889
		missionRocketsLabel.position = Vec2(DrawerW - 14, DrawerH / 2) -- 890
	end -- 890
	missionDrawerPlate.visible = false -- 892
	local drawerVisible = false -- 893
	local drawerLevelTitle = "" -- 894
	local drawerRockets = 0 -- 895
	local liveFuelBonus = false -- 896
	local function updateDrawerDisplay() -- 898
		if missionTitleLabel ~= nil then -- 898
			setLabelText(missionTitleLabel, drawerLevelTitle) -- 900
		end -- 900
		if missionRocketsLabel ~= nil then -- 900
			local r1 = drawerRockets >= 1 and "★" or "☆" -- 903
			local r2 = (drawerRockets >= 2 or liveFuelBonus) and "★" or "☆" -- 904
			local r3 = drawerRockets >= 3 and "★" or "☆" -- 905
			setLabelText(missionRocketsLabel, transferTutorial and (drawerRockets >= 1 and "已完成" or "地月转移练习") or (((r1 .. "  ") .. r2) .. "  ") .. r3) -- 906
		end -- 906
	end -- 898
	local IntroBannerW = math.min(viewW - 48, 540) -- 911
	local IntroBannerH = 68 -- 912
	local introBannerPlate = createPanel( -- 913
		root, -- 913
		IntroBannerW, -- 913
		IntroBannerH, -- 913
		658964, -- 913
		{alpha = 0.8, borderHex = 4610157} -- 913
	) -- 913
	introBannerPlate.position = Vec2((viewW - IntroBannerW) / 2, 70) -- 914
	local introBannerTitle = createLabel(introBannerPlate, "", 17, 15398143) -- 915
	if introBannerTitle ~= nil then -- 915
		introBannerTitle.anchor = Vec2(0.5, 0.5) -- 917
		introBannerTitle.position = Vec2(IntroBannerW / 2, IntroBannerH * 0.65) -- 918
	end -- 918
	local introBannerHint = createLabel(introBannerPlate, "轻触屏幕任意位置跳过运镜", 13, 9283005) -- 920
	if introBannerHint ~= nil then -- 920
		introBannerHint.anchor = Vec2(0.5, 0.5) -- 922
		introBannerHint.position = Vec2(IntroBannerW / 2, IntroBannerH * 0.28) -- 923
	end -- 923
	introBannerPlate.visible = false -- 925
	local PlaybackButtonW = 116 -- 934
	local PlaybackButtonH = 64 -- 935
	local playbackGap = 10 -- 936
	local playbackButtons = {} -- 937
	local playbackSpeeds = {} -- 938
	local playbackHandler = nil -- 939
	local speedChoice = speedChoices ~= nil and #speedChoices > 0 and speedChoices or ({1, 2, 4}) -- 942
	local playbackSpeed = speedChoice[1] -- 943
	--- 已应用到节点上的显隐状态。初值 false 如实反映"建出来就隐藏"（照 warp 按钮的教训）。
	local playbackVisible = false -- 945
	local function paintPlayback() -- 946
		do -- 946
			local i = 0 -- 947
			while i < #playbackButtons do -- 947
				local on = playbackSpeeds[i + 1] == playbackSpeed -- 948
				playbackButtons[i + 1]:setColors(on and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 949
				i = i + 1 -- 947
			end -- 947
		end -- 947
	end -- 946
	local function makePlaybackButton(speed, x) -- 952
		local btn = createButton( -- 953
			root, -- 953
			{ -- 953
				w = PlaybackButtonW, -- 954
				h = PlaybackButtonH, -- 955
				text = ____exports.playbackLabel(speed), -- 956
				fontSize = 30, -- 957
				bgHex = ResultButtonAltBgHex, -- 958
				fgHex = ResultButtonFgHex, -- 959
				borderHex = ResultButtonBorderHex, -- 960
				onTap = function() -- 961
					print(("[escape-velocity] playback button fire " .. __TS__NumberToFixed(speed, 0)) .. "x (release)") -- 963
					playbackSpeed = speed -- 964
					paintPlayback() -- 965
					if playbackHandler ~= nil then -- 965
						playbackHandler(speed) -- 966
					end -- 966
				end -- 961
			} -- 961
		) -- 961
		btn.root.position = Vec2(x, 96) -- 971
		playbackButtons[#playbackButtons + 1] = btn -- 972
		playbackSpeeds[#playbackSpeeds + 1] = speed -- 973
	end -- 952
	do -- 952
		local i = 0 -- 975
		while i < #speedChoice and i < 3 do -- 975
			makePlaybackButton(speedChoice[i + 1], 24 + (PlaybackButtonW + playbackGap) * i) -- 976
			i = i + 1 -- 975
		end -- 975
	end -- 975
	paintPlayback() -- 978
	for ____, b in ipairs(playbackButtons) do -- 980
		b.root.visible = false -- 981
		b:setEnabled(false) -- 982
	end -- 982
	local brakeRightX = viewW - BrakeButtonW - 20 -- 985
	if not transferTutorial then -- 985
		makeBrakeButton("惯性", false, brakeRightX - BrakeButtonW - brakeGap) -- 987
		makeBrakeButton("刹车", true, brakeRightX) -- 988
	end -- 988
	paintBrake() -- 990
	local liveBrakeHandler = nil -- 993
	local liveBrakeActive = false -- 994
	local liveBrakedState = false -- 995
	local LiveBrakeW = 220 -- 996
	local LiveBrakeH = 100 -- 997
	local liveBrakeButton = createButton( -- 998
		root, -- 998
		{ -- 998
			w = LiveBrakeW, -- 999
			h = LiveBrakeH, -- 1000
			text = "BRAKE 逆喷", -- 1001
			fontSize = 36, -- 1002
			bgHex = 10899464, -- 1003
			fgHex = 16775392, -- 1004
			borderHex = 16755251, -- 1005
			fireOn = "press", -- 1006
			onTap = function() -- 1007
				print("[escape-velocity] live brake button fire (press)") -- 1008
				if liveBrakeHandler ~= nil then -- 1008
					liveBrakeHandler() -- 1009
				end -- 1009
			end -- 1007
		} -- 1007
	) -- 1007
	liveBrakeButton.root.position = Vec2(viewW - LiveBrakeW - 24, 96) -- 1012
	liveBrakeButton.root.visible = false -- 1013
	liveBrakeButton:setEnabled(false) -- 1014
	local hintW = 440 -- 1017
	local hintH = 50 -- 1018
	local brakeHintPlate = createPanel( -- 1019
		root, -- 1019
		hintW, -- 1019
		hintH, -- 1019
		658964, -- 1019
		{alpha = 0.65, borderHex = 16755251} -- 1019
	) -- 1019
	brakeHintPlate.position = Vec2((viewW - hintW) / 2, viewH - 240) -- 1020
	local brakeHintLabel = createLabel(brakeHintPlate, "【木星捕获窗口已开启 · 按下 BRAKE 逆喷入轨】", 22, 16762939) -- 1021
	if brakeHintLabel ~= nil then -- 1021
		setLabelCenter(brakeHintLabel, hintW / 2, hintH / 2) -- 1023
	end -- 1023
	brakeHintPlate.visible = false -- 1025
	parent:addChild(root) -- 1027
	return { -- 1029
		onDrag = function(____, callback) -- 1030
			dragHandler = callback -- 1031
		end, -- 1030
		setEnabled = function(____, value) -- 1033
			enabled = value -- 1034
			touchLayer.touchEnabled = value -- 1037
			if not value then -- 1037
				dragging = false -- 1039
				liveBrakeActive = false -- 1040
				liveBrakeButton.root.visible = false -- 1041
				liveBrakeButton:setEnabled(false) -- 1042
				brakeHintPlate.visible = false -- 1043
			end -- 1043
		end, -- 1033
		onBrake = function(____, callback) -- 1046
			brakeHandler = callback -- 1047
		end, -- 1046
		setBrake = function(____, on) -- 1049
			brakeOn = on -- 1050
			paintBrake() -- 1051
		end, -- 1049
		onAimReady = function(____, callback) -- 1053
			readyHandler = callback -- 1054
		end, -- 1053
		onObserve = function(____, callback) -- 1056
			observeHandler = callback -- 1057
		end, -- 1056
		onZoom = function(____, callback) -- 1059
			zoomHandler = callback -- 1060
		end, -- 1059
		onLaunch = function(____, callback) -- 1062
			launchHandler = callback -- 1063
		end, -- 1062
		onCancelAim = function(____, callback) -- 1065
			cancelAimHandler = callback -- 1066
		end, -- 1065
		setArmed = function(____, armed) -- 1068
			launchButton.root.visible = armed -- 1069
			launchButton:setEnabled(armed) -- 1070
			cancelAimButton.root.visible = armed -- 1071
			cancelAimButton:setEnabled(armed) -- 1072
		end, -- 1068
		onViewToggle = function(____, callback) -- 1074
			viewHandler = callback -- 1075
		end, -- 1074
		onCameraFocus = function(____, callback) -- 1077
			cameraFocusHandler = callback -- 1077
		end, -- 1077
		onEndViewing = function(____, callback) -- 1078
			endViewingHandler = callback -- 1078
		end, -- 1078
		setFlightViewing = function(____, flying, completed, mode, is3D, stage) -- 1079
			if not transferTutorial then -- 1079
				return -- 1080
			end -- 1080
			local key = ((((flying and "1" or "0") .. (completed and "1" or "0")) .. mode) .. (is3D and "1" or "0")) .. (stage ~= nil and stage or "") -- 1081
			if viewingKey == key then -- 1081
				return -- 1082
			end -- 1082
			viewingKey = key -- 1083
			if dvLabel ~= nil then -- 1083
				dvLabel.visible = not flying -- 1084
			end -- 1084
			if viewingLabel ~= nil then -- 1084
				viewingLabel.visible = flying -- 1086
				setLabelText(viewingLabel, completed and "掠月完成 · 继续观察返回" or (stage == "Launch" and "顺行点火 · 抬高远地点" or (stage == "Moon" and "借月球引力 · 观察轨迹转弯" or "滑行接近月球"))) -- 1087
				setLabelColor(viewingLabel, completed and 9430458 or ResultHintHex) -- 1088
			end -- 1088
			if cameraFocusButton ~= nil then -- 1088
				cameraFocusButton.root.visible = flying and is3D -- 1091
				cameraFocusButton:setEnabled(flying and is3D) -- 1092
				local title = mode == "Auto" and "自动" or (mode == "Probe" and "探测器" or (mode == "Moon" and "月球" or (mode == "Earth" and "地球" or "总览"))) -- 1093
				cameraFocusButton:setText("镜头 · " .. title) -- 1094
			end -- 1094
			if endViewingButton ~= nil then -- 1094
				endViewingButton.root.visible = flying and completed -- 1096
				endViewingButton:setEnabled(flying and completed) -- 1096
			end -- 1096
		end, -- 1079
		setViewMode = function(____, mode) -- 1098
			if mode == lastViewText then -- 1098
				return -- 1099
			end -- 1099
			lastViewText = mode -- 1100
			local btnText = mode == "2D" and "[ 3D ]" or "[ 2D ]" -- 1102
			viewButton:setText(btnText) -- 1103
		end, -- 1098
		onPlayback = function(____, callback) -- 1105
			playbackHandler = callback -- 1106
		end, -- 1105
		setPlayback = function(____, speed) -- 1108
			if speed == playbackSpeed then -- 1108
				return -- 1109
			end -- 1109
			playbackSpeed = speed -- 1110
			paintPlayback() -- 1111
		end, -- 1108
		setPlaybackVisible = function(____, on) -- 1113
			if on == playbackVisible then -- 1113
				return -- 1114
			end -- 1114
			playbackVisible = on -- 1115
			for ____, b in ipairs(playbackButtons) do -- 1116
				b.root.visible = on -- 1117
				b:setEnabled(on) -- 1118
			end -- 1118
		end, -- 1113
		setFullScreenAim = function(____, on) -- 1121
			fullScreenAim = on -- 1122
		end, -- 1121
		onWarp = function(____, callback) -- 1124
			warpHandler = callback -- 1125
		end, -- 1124
		setDate = function(____, t0, span) -- 1127
			dateSpan = span > 0 and span or 0 -- 1128
			applyWarpState() -- 1129
			local on = dateSpan > 0 -- 1130
			local text = on and (("发射日期 " .. __TS__NumberToFixed(t0, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0) or "发射日期" -- 1131
			if text ~= lastDateText then -- 1131
				lastDateText = text -- 1133
				setLabelText(dateLabel, text) -- 1134
			end -- 1134
		end, -- 1127
		setTimeEnabled = function(____, on) -- 1137
			if warpAllowed == on then -- 1137
				return -- 1138
			end -- 1138
			warpAllowed = on -- 1139
			applyWarpState() -- 1140
		end, -- 1137
		update = function(____, dt) -- 1142
			if not warpOn or warpHoldDir == 0 then -- 1142
				return -- 1143
			end -- 1143
			warpRepeatIn = warpRepeatIn - dt -- 1144
			if warpRepeatIn > 0 then -- 1144
				return -- 1145
			end -- 1145
			warpRepeatIn = TimeWarpStep / TimeWarpRate -- 1147
			if warpHandler ~= nil then -- 1147
				warpHandler(warpHoldDir) -- 1148
			end -- 1148
		end, -- 1142
		isDragging = function() return dragging end, -- 1150
		setBurnInfo = function(____, burn, budget) -- 1151
			if transferTutorial then -- 1151
				return -- 1152
			end -- 1152
			local b = budget < 1 and __TS__NumberToFixed(budget, 2) or __TS__NumberToFixed(budget, 0) -- 1156
			local v = burn < 1 and __TS__NumberToFixed(burn, 2) or __TS__NumberToFixed(burn, 1) -- 1157
			setLabelText(dvLabel, (("Δv " .. v) .. " / ") .. b) -- 1158
		end, -- 1151
		current = function() return aim end, -- 1160
		setTransferInfo = function(____, apoapsis, duration, reachable) -- 1161
			setLabelText( -- 1162
				dvLabel, -- 1162
				(((("远地点高度 " .. __TS__NumberToFixed(apoapsis, 0)) .. " · 点火 ") .. __TS__NumberToFixed(duration, 2)) .. "s") .. (reachable ~= nil and (reachable and " · 可减速掠月" or " · 等待窗口") or "") -- 1162
			) -- 1162
		end, -- 1161
		setProbeOffset = function(____, offset) -- 1164
			probeOffset = offset -- 1165
		end, -- 1164
		handleLocal = function(____, ____local) -- 1169
			handleDelta(____exports.localToOffset(____local, space)) -- 1170
		end, -- 1169
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 1173
		debugProbeOffset = function() return probeOffset end, -- 1174
		onLiveBrake = function(____, callback) -- 1175
			liveBrakeHandler = callback -- 1176
		end, -- 1175
		setLiveBrakeVisible = function(____, visible) -- 1178
			if liveBrakeActive == visible then -- 1178
				return -- 1179
			end -- 1179
			liveBrakeActive = visible -- 1180
			liveBrakeButton.root.visible = visible -- 1181
			liveBrakeButton:setEnabled(visible) -- 1182
			brakeHintPlate.visible = visible -- 1183
		end, -- 1178
		setLiveBraked = function(____, braked) -- 1185
			if liveBrakedState == braked then -- 1185
				return -- 1186
			end -- 1186
			liveBrakedState = braked -- 1187
			if braked then -- 1187
				liveBrakeButton:setText("已捕获入轨") -- 1189
				liveBrakeButton:setColors(1589810, 13697002) -- 1190
				liveBrakeButton:setEnabled(false) -- 1191
				if brakeHintLabel ~= nil then -- 1191
					setLabelText(brakeHintLabel, "【主发动机逆喷成功！已捕获入轨】") -- 1193
					setLabelColor(brakeHintLabel, 4122272) -- 1194
				end -- 1194
			else -- 1194
				liveBrakeButton:setText("BRAKE 逆喷") -- 1197
				liveBrakeButton:setColors(10899464, 16775392) -- 1198
				if brakeHintLabel ~= nil then -- 1198
					setLabelText(brakeHintLabel, "【木星捕获窗口已开启 · 按下 BRAKE 逆喷入轨】") -- 1200
					setLabelColor(brakeHintLabel, 16762939) -- 1201
				end -- 1201
			end -- 1201
		end, -- 1185
		onSpeedUp = function(____, callback) -- 1205
			speedUpHandler = callback -- 1206
		end, -- 1205
		onSpeedDown = function(____, callback) -- 1208
			speedDownHandler = callback -- 1209
		end, -- 1208
		onTogglePause = function(____, callback) -- 1211
			pauseHandler = callback -- 1212
		end, -- 1211
		setTimeControl = function(____, pow, maxPow, paused, missionSeconds, actualRate) -- 1214
			setTimeControl( -- 1215
				pow, -- 1215
				maxPow, -- 1215
				paused, -- 1215
				missionSeconds, -- 1215
				actualRate -- 1215
			) -- 1215
		end, -- 1214
		onZoomIn = function(____, callback) -- 1217
			zoomInHandler = callback -- 1218
		end, -- 1217
		onZoomOut = function(____, callback) -- 1220
			zoomOutHandler = callback -- 1221
		end, -- 1220
		onFitView = function(____, callback) -- 1223
			fitViewHandler = callback -- 1224
		end, -- 1223
		setZoomControlsVisible = function(____, on) -- 1226
			setZoomVisible(on) -- 1227
		end, -- 1226
		setMissionDrawer = function(____, levelName, _challenges, currentRockets) -- 1229
			drawerLevelTitle = levelName -- 1230
			drawerRockets = currentRockets -- 1231
			updateDrawerDisplay() -- 1232
		end, -- 1229
		setMissionDrawerVisible = function(____, visible) -- 1234
			if drawerVisible == visible then -- 1234
				return -- 1235
			end -- 1235
			drawerVisible = visible -- 1236
			missionDrawerPlate.visible = visible -- 1237
		end, -- 1234
		setLiveFuelChallengeStatus = function(____, achieved) -- 1239
			if liveFuelBonus == achieved then -- 1239
				return -- 1240
			end -- 1240
			liveFuelBonus = achieved -- 1241
			updateDrawerDisplay() -- 1242
		end, -- 1239
		setIntroTourBanner = function(____, title, hint) -- 1244
			if introBannerTitle ~= nil then -- 1244
				setLabelText(introBannerTitle, title) -- 1245
			end -- 1245
			if introBannerHint ~= nil and hint ~= nil then -- 1245
				setLabelText(introBannerHint, hint) -- 1246
			end -- 1246
		end, -- 1244
		setIntroTourBannerVisible = function(____, visible) -- 1248
			introBannerPlate.visible = visible -- 1249
		end, -- 1248
		onSkipTour = function(____, callback) -- 1251
			skipTourHandler = callback -- 1252
		end, -- 1251
		setTourActiveChecker = function(____, fn) -- 1254
			tourActiveChecker = fn -- 1255
		end, -- 1254
		onQuickRetry = function(____, callback) -- 1257
			quickRetryHandler = callback -- 1258
		end, -- 1257
		setStarsStatus = function(____, starsGot) -- 1260
			updateStarsStatus(starsGot) -- 1261
		end, -- 1260
		root = root -- 1263
	} -- 1263
end -- 351
local ResultBackdropHex = 329484 -- 1280
local ResultCardHex = 1252395 -- 1281
local ResultCardBorderHex = 3362938 -- 1282
local ResultLevelHex = 9417948 -- 1283
local ResultBodyHex = 14149367 -- 1284
ResultHintHex = 8229803 -- 1285
ResultButtonBgHex = 1919610 -- 1286
ResultButtonAltBgHex = 1779509 -- 1287
ResultButtonFgHex = 15398143 -- 1288
ResultButtonBorderHex = 5211846 -- 1289
local TitleSuccessHex = 8381344 -- 1290
local TitleMissedHex = 16766073 -- 1291
local TitleCrashedHex = 16743019 -- 1292
local SelectBackdropHex = 329484 -- 1294
local SelectTitleHex = 16777215 -- 1295
local SelectSubtitleHex = 10470632 -- 1296
local SelectHintHex = 7309478 -- 1297
local SelectOpenBgHex = 1919610 -- 1298
local SelectOpenFgHex = 15398143 -- 1299
local SelectLockedBgHex = 1383204 -- 1300
local SelectLockedFgHex = 6912140 -- 1301
local SelectBorderHex = 4157096 -- 1302
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 1305
	if value < lo then -- 1305
		return lo -- 1306
	end -- 1306
	if value > hi then -- 1306
		return hi -- 1307
	end -- 1307
	return value -- 1308
end -- 1305
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 1312
	if result == "success" then -- 1312
		return "借力成功" -- 1313
	end -- 1313
	if result == "crashed" then -- 1313
		return "信号中断" -- 1314
	end -- 1314
	return "错过目标" -- 1315
end -- 1312
--- 三态说明句（逐字）。
local function resultBody(result) -- 1319
	if result == "success" then -- 1319
		return "行星把探测器甩了出去，速度够了。" -- 1320
	end -- 1320
	if result == "crashed" then -- 1320
		return "探测器撞上行星，任务到此为止。" -- 1321
	end -- 1321
	return "从行星身侧掠过，没能借到那一点速度。" -- 1322
end -- 1319
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 1326
	if result == "success" then -- 1326
		return TitleSuccessHex -- 1327
	end -- 1327
	if result == "crashed" then -- 1327
		return TitleCrashedHex -- 1328
	end -- 1328
	return TitleMissedHex -- 1329
end -- 1326
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 1338
	if result == "success" then -- 1338
		return "下一关已解锁" -- 1339
	end -- 1339
	return "可重试本关，或返回关卡选择" -- 1340
end -- 1338
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 1385
	local root = createPanel( -- 1391
		parent, -- 1391
		viewW, -- 1391
		viewH, -- 1391
		ResultBackdropHex, -- 1391
		{alpha = 0.78} -- 1391
	) -- 1391
	local cardW = clampNumber(viewW * 0.9, 360, 560) -- 1393
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 480) -- 1394
	local btnH = clampNumber(viewH * 0.08, 48, 60) -- 1395
	local padX = (cardW - btnW) / 2 -- 1396
	local padY = 28 -- 1397
	local fontLevel = 24 -- 1399
	local fontRockets = 38 -- 1400
	local fontTitle = 30 -- 1401
	local fontTelemetry = 19 -- 1402
	local fontChallenge = 18 -- 1403
	local fontTotal = 20 -- 1404
	local btnFont = 24 -- 1405
	local rowGap = 12 -- 1406
	local hLevel = 28 -- 1408
	local hRockets = 42 -- 1409
	local hTitle = 34 -- 1410
	local hTelemetry = 24 -- 1411
	local hChallengeRow = 30 -- 1412
	local hChallenges = hChallengeRow * 3 -- 1413
	local hTotal = 24 -- 1414
	local cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7 -- 1416
	if cardH > viewH - 24 then -- 1416
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 1418
		cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7 -- 1419
	end -- 1419
	local card = createPanel( -- 1422
		root, -- 1422
		cardW, -- 1422
		cardH, -- 1422
		ResultCardHex, -- 1422
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 1422
	) -- 1422
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 1427
	local cursor = cardH - padY -- 1430
	cursor = cursor - hLevel -- 1432
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 1433
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 1434
	cursor = cursor - (rowGap + hRockets) -- 1436
	local rocketsLabel = createLabel(card, "", fontRockets, 16762939) -- 1437
	setLabelCenter(rocketsLabel, cardW / 2, cursor + hRockets / 2) -- 1438
	cursor = cursor - (rowGap + hTitle) -- 1440
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 1441
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 1442
	cursor = cursor - (rowGap + hTelemetry) -- 1444
	local telemetryLabel = createLabel(card, "", fontTelemetry, ResultHintHex) -- 1445
	setLabelCenter(telemetryLabel, cardW / 2, cursor + hTelemetry / 2) -- 1446
	cursor = cursor - rowGap -- 1448
	local challengeLabels = {} -- 1449
	do -- 1449
		local k = 0 -- 1450
		while k < 3 do -- 1450
			cursor = cursor - hChallengeRow -- 1451
			local cl = createLabel(card, "", fontChallenge, 10405355) -- 1452
			if cl ~= nil then -- 1452
				cl.textWidth = cardW - 60 -- 1454
				setLabelCenter(cl, cardW / 2, cursor + hChallengeRow / 2) -- 1455
				challengeLabels[#challengeLabels + 1] = cl -- 1456
			end -- 1456
			k = k + 1 -- 1450
		end -- 1450
	end -- 1450
	cursor = cursor - (rowGap + hTotal) -- 1460
	local totalLabel = createLabel(card, "", fontTotal, 16766073) -- 1461
	setLabelCenter(totalLabel, cardW / 2, cursor + hTotal / 2) -- 1462
	cursor = cursor - (rowGap + btnH) -- 1464
	local retryButton = createButton(card, { -- 1465
		w = btnW, -- 1466
		h = btnH, -- 1467
		text = "重试本关", -- 1468
		fontSize = btnFont, -- 1469
		bgHex = ResultButtonBgHex, -- 1470
		fgHex = ResultButtonFgHex, -- 1471
		borderHex = ResultButtonBorderHex, -- 1472
		fireOn = "press", -- 1473
		onTap = opts.onRetry -- 1474
	}) -- 1474
	retryButton.root.position = Vec2(padX, cursor) -- 1476
	cursor = cursor - (14 + btnH) -- 1478
	local backButton = createButton(card, { -- 1479
		w = btnW, -- 1480
		h = btnH, -- 1481
		text = "返回关卡选择", -- 1482
		fontSize = btnFont, -- 1483
		bgHex = ResultButtonAltBgHex, -- 1484
		fgHex = ResultButtonFgHex, -- 1485
		borderHex = ResultButtonBorderHex, -- 1486
		fireOn = "press", -- 1487
		onTap = opts.onBackToSelect -- 1488
	}) -- 1488
	backButton.root.position = Vec2(padX, cursor) -- 1490
	root.visible = false -- 1492
	retryButton:setEnabled(false) -- 1493
	backButton:setEnabled(false) -- 1494
	return { -- 1496
		root = root, -- 1497
		show = function(____, result, levelName, detail) -- 1498
			retryButton:setEnabled(true) -- 1499
			backButton:setEnabled(true) -- 1500
			setLabelText(levelLabel, levelName) -- 1501
			setLabelText( -- 1502
				titleLabel, -- 1502
				resultTitle(result) -- 1502
			) -- 1502
			setLabelColor( -- 1503
				titleLabel, -- 1503
				resultTitleColor(result) -- 1503
			) -- 1503
			if detail ~= nil then -- 1503
				if detail.completionOnly == true then -- 1503
					setLabelText( -- 1506
						titleLabel, -- 1506
						result == "success" and "月球减速掠过完成" or resultTitle(result) -- 1506
					) -- 1506
				end -- 1506
				local rCount = detail.rocketsGot -- 1507
				local rStr = "☆  ☆  ☆" -- 1508
				if rCount == 1 then -- 1508
					rStr = "★  ☆  ☆" -- 1509
				elseif rCount == 2 then -- 1509
					rStr = "★  ★  ☆" -- 1510
				elseif rCount >= 3 then -- 1510
					rStr = "★  ★  ★" -- 1511
				end -- 1511
				setLabelText(rocketsLabel, detail.completionOnly == true and (result == "success" and "地月转移完成" or "再试一次") or rStr) -- 1512
				setLabelColor(rocketsLabel, rCount > 0 and 16762939 or 6322324) -- 1513
				local pct = detail.dvBudget > 0 and math.floor(detail.burnDv / detail.dvBudget * 100) or 0 -- 1515
				local telemText = ((((((("点火消耗 Δv: " .. __TS__NumberToFixed(detail.burnDv, 2)) .. " / ") .. __TS__NumberToFixed(detail.dvBudget, 2)) .. " (") .. __TS__NumberToFixed(pct, 0)) .. "%) · 用时: ") .. __TS__NumberToFixed(detail.flightTime, 1)) .. "s" -- 1516
				setLabelText(telemetryLabel, telemText) -- 1517
				do -- 1517
					local k = 0 -- 1519
					while k < 3 do -- 1519
						if challengeLabels[k + 1] ~= nil then -- 1519
							if k < #detail.challenges then -- 1519
								local ok = detail.achieved[k + 1] -- 1522
								local icon = ok and "★" or "☆" -- 1523
								local rank = k == 0 and "一星" or (k == 1 and "二星" or "三星") -- 1524
								local text = detail.completionOnly == true and (ok and "安全掠月 · 完成记录已保存" or "尚未完成安全减速掠月") or (((icon .. " [") .. rank) .. "] ") .. detail.challenges[k + 1] -- 1525
								setLabelText(challengeLabels[k + 1], text) -- 1526
								setLabelColor(challengeLabels[k + 1], ok and 16762939 or 6322324) -- 1527
								challengeLabels[k + 1].visible = true -- 1528
							else -- 1528
								challengeLabels[k + 1].visible = false -- 1530
							end -- 1530
						end -- 1530
						k = k + 1 -- 1519
					end -- 1519
				end -- 1519
				setLabelText( -- 1535
					totalLabel, -- 1535
					((("全深空火箭勋章: " .. __TS__NumberToFixed(detail.totalRockets, 0)) .. " / ") .. __TS__NumberToFixed(detail.totalPossibleRockets, 0)) .. " ★" -- 1535
				) -- 1535
				if totalLabel ~= nil then -- 1535
					totalLabel.visible = detail.completionOnly ~= true -- 1536
				end -- 1536
			else -- 1536
				setLabelText(rocketsLabel, result == "success" and "★  ☆  ☆" or "☆  ☆  ☆") -- 1538
				setLabelColor(rocketsLabel, result == "success" and 16762939 or 6322324) -- 1539
				setLabelText( -- 1540
					telemetryLabel, -- 1540
					resultBody(result) -- 1540
				) -- 1540
				do -- 1540
					local k = 0 -- 1541
					while k < #challengeLabels do -- 1541
						challengeLabels[k + 1].visible = false -- 1541
						k = k + 1 -- 1541
					end -- 1541
				end -- 1541
				if totalLabel ~= nil then -- 1541
					totalLabel.visible = false -- 1542
				end -- 1542
			end -- 1542
			root.visible = true -- 1544
		end, -- 1498
		hide = function() -- 1546
			root.visible = false -- 1547
			retryButton:setEnabled(false) -- 1548
			backButton:setEnabled(false) -- 1549
		end -- 1546
	} -- 1546
end -- 1385
local FinaleBackdropHex = 329484 -- 1564
local FinaleMainHex = 15398143 -- 1565
local FinaleSubHex = 10470632 -- 1566
--- 终章主文案（逐字；改之前先改 PLAN S3.18 与 docs/开发手册.md）。
____exports.FinaleMainText = "这就是我们整颗星球的样子 —— 而你已经从那里飞到了这里。" -- 1571
--- 终章小字：飞行距离 / 用时（纯函数，可单测）。
-- 
-- 距离是**平面单位**（关卡尺度，不是公里）—— 别在这里换算成天文单位，
-- 那一换就得把整条注释重写一遍，而玩家要的只是「飞了多远、花了多久」。
function ____exports.finaleSubtitle(distance, time) -- 1579
	return ((("飞行 " .. __TS__NumberToFixed(distance, 0)) .. " 单位 · 用时 ") .. __TS__NumberToFixed(time, 1)) .. " 秒" -- 1580
end -- 1579
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
function ____exports.createFinalePanel(parent, viewW, viewH, opts) -- 1610
	local root = createPanel( -- 1616
		parent, -- 1616
		viewW, -- 1616
		viewH, -- 1616
		FinaleBackdropHex, -- 1616
		{alpha = 0.55} -- 1616
	) -- 1616
	local fontMain = 34 -- 1618
	local fontSub = 30 -- 1619
	local btnFont = 40 -- 1620
	local mainLabel = createLabel(root, ____exports.FinaleMainText, fontMain, FinaleMainHex) -- 1622
	if mainLabel ~= nil then -- 1622
		mainLabel.textWidth = viewW * 0.88 -- 1625
		setLabelCenter(mainLabel, viewW / 2, viewH * 0.8) -- 1626
	end -- 1626
	local subLabel = createLabel(root, "", fontSub, FinaleSubHex) -- 1629
	if subLabel ~= nil then -- 1629
		setLabelCenter(subLabel, viewW / 2, viewH * 0.71) -- 1630
	end -- 1630
	local btnW = clampNumber(viewW * 0.62, MinButtonWidth, 560) -- 1632
	local btnH = clampNumber(viewH * 0.085, MinButtonHeight, 120) -- 1633
	local backButton = createButton(root, { -- 1634
		w = btnW, -- 1635
		h = btnH, -- 1636
		text = "返回关卡选择", -- 1637
		fontSize = btnFont, -- 1638
		bgHex = ResultButtonBgHex, -- 1639
		fgHex = ResultButtonFgHex, -- 1640
		borderHex = ResultButtonBorderHex, -- 1641
		fireOn = "press", -- 1643
		onTap = opts.onBackToSelect -- 1644
	}) -- 1644
	backButton.root.position = Vec2((viewW - btnW) / 2, 110) -- 1646
	root.visible = false -- 1648
	backButton:setEnabled(false) -- 1650
	return { -- 1652
		root = root, -- 1653
		show = function(____, main, sub) -- 1654
			setLabelText(mainLabel, main) -- 1655
			setLabelText(subLabel, sub) -- 1656
			backButton:setEnabled(true) -- 1657
			root.visible = true -- 1658
		end, -- 1654
		hide = function() -- 1660
			root.visible = false -- 1661
			backButton:setEnabled(false) -- 1663
		end -- 1660
	} -- 1660
end -- 1610
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 1702
	local root = createPanel( -- 1708
		parent, -- 1708
		viewW, -- 1708
		viewH, -- 1708
		SelectBackdropHex, -- 1708
		{alpha = 0.9} -- 1708
	) -- 1708
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 1710
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 1711
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 1713
	setLabelCenter( -- 1714
		subtitleLabel, -- 1714
		viewW / 2, -- 1714
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 1714
	) -- 1714
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 1716
	setLabelCenter( -- 1717
		hintLabel, -- 1717
		viewW / 2, -- 1717
		clampNumber(viewH * 0.045, 36, 90) -- 1717
	) -- 1717
	local count = #opts.levels -- 1719
	local cols = viewH > viewW and 2 or 1 -- 1722
	local rows = math.max( -- 1723
		1, -- 1723
		math.ceil(count / cols) -- 1723
	) -- 1723
	local gap = 18 -- 1724
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 1725
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 1726
	local availW = viewW * 0.84 -- 1727
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 1728
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 1729
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 1730
	local gridW = cols * btnW + gap * (cols - 1) -- 1731
	local topY = viewH - headerH -- 1732
	local buttons = {} -- 1734
	do -- 1734
		local i = 0 -- 1735
		while i < count do -- 1735
			local index = i -- 1737
			local button = createButton( -- 1738
				root, -- 1738
				{ -- 1738
					w = btnW, -- 1739
					h = btnH, -- 1740
					text = opts.levels[index + 1].name, -- 1741
					fontSize = 38, -- 1742
					bgHex = SelectLockedBgHex, -- 1743
					fgHex = SelectLockedFgHex, -- 1744
					borderHex = SelectBorderHex, -- 1745
					fireOn = "press", -- 1747
					onTap = function() return opts:onPick(index) end -- 1748
				} -- 1748
			) -- 1748
			local col = index % cols -- 1750
			local rowIndex = math.floor(index / cols) -- 1751
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 1752
			buttons[#buttons + 1] = button -- 1756
			i = i + 1 -- 1735
		end -- 1735
	end -- 1735
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 1762
		root, -- 1763
		{ -- 1763
			w = clampNumber(viewW * 0.36, 180, 300), -- 1764
			h = MinButtonHeight, -- 1765
			text = "重看开场", -- 1766
			fontSize = 30, -- 1767
			bgHex = SelectLockedBgHex, -- 1768
			fgHex = SelectSubtitleHex, -- 1769
			borderHex = SelectBorderHex, -- 1770
			fireOn = "press", -- 1771
			onTap = function() -- 1772
				if opts.onReplayIntro ~= nil then -- 1772
					opts:onReplayIntro() -- 1773
				end -- 1773
			end -- 1772
		} -- 1772
	) or nil -- 1772
	if replayButton ~= nil then -- 1772
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 1778
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 1779
		replayButton.root.position = Vec2( -- 1780
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 1780
			by -- 1780
		) -- 1780
	end -- 1780
	root.visible = false -- 1783
	do -- 1783
		local i = 0 -- 1784
		while i < count do -- 1784
			buttons[i + 1]:setEnabled(false) -- 1784
			i = i + 1 -- 1784
		end -- 1784
	end -- 1784
	if replayButton ~= nil then -- 1784
		replayButton:setEnabled(false) -- 1785
	end -- 1785
	return { -- 1787
		root = root, -- 1788
		show = function(____, unlocked) -- 1789
			local maxUnlocked = clampNumber( -- 1790
				math.floor(unlocked), -- 1790
				0, -- 1790
				count - 1 -- 1790
			) -- 1790
			setLabelText( -- 1791
				subtitleLabel, -- 1791
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 1791
			) -- 1791
			do -- 1791
				local i = 0 -- 1792
				while i < count do -- 1792
					local button = buttons[i + 1] -- 1793
					local open = i <= maxUnlocked -- 1794
					button:setEnabled(open) -- 1795
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 1796
					if open then -- 1796
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 1797
					else -- 1797
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 1798
					end -- 1798
					i = i + 1 -- 1792
				end -- 1792
			end -- 1792
			root.visible = true -- 1800
			if replayButton ~= nil then -- 1800
				replayButton:setEnabled(true) -- 1801
			end -- 1801
		end, -- 1789
		hide = function() -- 1803
			root.visible = false -- 1804
			do -- 1804
				local i = 0 -- 1806
				while i < count do -- 1806
					buttons[i + 1]:setEnabled(false) -- 1806
					i = i + 1 -- 1806
				end -- 1806
			end -- 1806
			if replayButton ~= nil then -- 1806
				replayButton:setEnabled(false) -- 1807
			end -- 1807
		end -- 1803
	} -- 1803
end -- 1702
return ____exports -- 1702