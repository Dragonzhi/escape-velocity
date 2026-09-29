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
function ____exports.createAimInput(parent, viewW, viewH, maxSpeed, minSpeed, speedChoices, transferTutorial, transferMode) -- 351
	if transferTutorial == nil then -- 351
		transferTutorial = false -- 361
	end -- 361
	if transferMode == nil then -- 361
		transferMode = "lunar" -- 362
	end -- 362
	local brakeOn, paintBrake, datePlate, dateLabel -- 362
	local speedMin = minSpeed ~= nil and minSpeed >= 0 and minSpeed < (maxSpeed ~= nil and maxSpeed or AimMaxSpeed) and minSpeed or AimMinSpeed -- 364
	local speedTop = maxSpeed ~= nil and maxSpeed > speedMin and maxSpeed or AimMaxSpeed -- 366
	local root = Node() -- 367
	root.size = Size(viewW, viewH) -- 368
	root.anchor = Vec2(0, 0) -- 374
	root.position = Vec2(0, 0) -- 375
	local touchLayer = Node() -- 378
	touchLayer.size = Size(viewW, viewH) -- 379
	touchLayer.anchor = Vec2(0.5, 0.5) -- 380
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 381
	touchLayer.swallowTouches = true -- 382
	root:addChild(touchLayer) -- 383
	local space = {viewW = viewW, viewH = viewH} -- 385
	local enabled = false -- 387
	local dragging = false -- 388
	--- 整屏瞄准（2D 模式）；由 Game 按视图状态同步。
	local fullScreenAim = false -- 390
	local aim = {velocity = {x = 0, y = -speedMin}, power = 0, unit = {x = 0, y = -1}} -- 391
	local probeOffset = {x = 0, y = 0} -- 394
	local dragHandler = nil -- 396
	local readyHandler = nil -- 397
	local observeHandler = nil -- 398
	local zoomHandler = nil -- 399
	local launchHandler = nil -- 400
	local skipTourHandler = nil -- 401
	local tourActiveChecker = nil -- 402
	local pressOffset = {x = 0, y = 0} -- 413
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 416
		aim = ____exports.computeAim( -- 417
			{x = 0, y = 0}, -- 417
			delta, -- 417
			AimMaxDragPx, -- 417
			speedTop, -- 417
			speedMin -- 417
		) -- 417
		if dragHandler ~= nil then -- 417
			dragHandler(aim) -- 418
		end -- 418
	end -- 416
	local aimRadius = math.max(96, viewW * 0.25) -- 425
	local mode = "none" -- 426
	local observeLast = {x = 0, y = 0} -- 427
	touchLayer:onTapBegan(function(touch) -- 428
		if not enabled then -- 428
			return -- 429
		end -- 429
		if tourActiveChecker ~= nil and tourActiveChecker() and skipTourHandler ~= nil then -- 429
			skipTourHandler() -- 431
			return -- 432
		end -- 432
		local at = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 434
		local dx = at.x - probeOffset.x -- 435
		local dy = at.y - probeOffset.y -- 436
		if fullScreenAim or math.sqrt(dx * dx + dy * dy) <= aimRadius then -- 436
			mode = "aim" -- 438
			dragging = true -- 439
			pressOffset = at -- 440
			handleDelta({x = 0, y = 0}) -- 442
		else -- 442
			mode = "observe" -- 444
			observeLast = at -- 445
		end -- 445
	end) -- 428
	touchLayer:onTapMoved(function(touch) -- 449
		if not enabled then -- 449
			return -- 450
		end -- 450
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 451
		if mode == "aim" and dragging then -- 451
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 453
		elseif mode == "observe" then -- 453
			if observeHandler ~= nil then -- 453
				observeHandler(cur.x - observeLast.x, cur.y - observeLast.y) -- 456
			end -- 456
			observeLast = cur -- 457
		end -- 457
	end) -- 449
	touchLayer:onTapEnded(function(touch) -- 461
		if not enabled then -- 461
			return -- 462
		end -- 462
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 463
		if mode == "aim" then -- 463
			dragging = false -- 465
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 466
			if readyHandler ~= nil then -- 466
				readyHandler(aim) -- 468
			end -- 468
		end -- 468
		mode = "none" -- 470
	end) -- 461
	touchLayer:onGesture(function(_center, numFingers, deltaDist, _deltaAngle) -- 474
		if not enabled or numFingers < 2 then -- 474
			return -- 475
		end -- 475
		if zoomHandler ~= nil then -- 475
			zoomHandler(deltaDist) -- 476
		end -- 476
	end) -- 474
	touchLayer.touchEnabled = false -- 484
	local brakeHandler = nil -- 489
	local BrakeButtonW = 116 -- 490
	local BrakeButtonH = 64 -- 491
	local brakeGap = 8 -- 492
	local brakeButtons = {} -- 496
	local function makeBrakeButton(text, on, x) -- 497
		local btn = createButton( -- 498
			root, -- 498
			{ -- 498
				w = BrakeButtonW, -- 499
				h = BrakeButtonH, -- 500
				text = text, -- 501
				fontSize = 30, -- 502
				bgHex = ResultButtonAltBgHex, -- 503
				fgHex = ResultButtonFgHex, -- 504
				borderHex = ResultButtonBorderHex, -- 505
				onTap = function() -- 506
					brakeOn = on -- 509
					paintBrake() -- 510
					if brakeHandler ~= nil then -- 510
						brakeHandler(on) -- 511
					end -- 511
				end -- 506
			} -- 506
		) -- 506
		btn.root.position = Vec2(x, viewH - BrakeButtonH - 20) -- 514
		brakeButtons[#brakeButtons + 1] = btn -- 515
	end -- 497
	brakeOn = false -- 517
	paintBrake = function() -- 518
		if #brakeButtons < 2 then -- 518
			return -- 519
		end -- 519
		brakeButtons[1]:setColors(brakeOn and ResultButtonAltBgHex or ResultButtonBgHex, ResultButtonFgHex) -- 520
		brakeButtons[2]:setColors(brakeOn and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 521
	end -- 518
	createPanel( -- 527
		root, -- 527
		220, -- 527
		50, -- 527
		658964, -- 527
		{alpha = 0.45} -- 527
	) -- 527
	local orbitName = transferMode == "inward" and "近日点" or (transferMode == "outward" and "远日点" or "远地点高度") -- 528
	local dvLabel = createLabel(root, transferTutorial and "拖动调整" .. orbitName or "Δv — / —", transferTutorial and 22 or 30, ResultHintHex) -- 529
	if dvLabel ~= nil then -- 529
		dvLabel.position = Vec2(24, viewH - (transferTutorial and 130 or 44)) -- 531
		dvLabel.anchor = Vec2(0, 0) -- 532
	end -- 532
	local warpHandler = nil -- 542
	local dateSpan = 0 -- 543
	--- 这一关有时间轴**且**当前相态允许改日期（Flying/Result 时必须是 false）。
	local warpOn = true -- 550
	local warpVisible = true -- 551
	--- 相态是否允许改日期（由主循环每帧 setTimeEnabled 同步）。
	local warpAllowed = true -- 553
	--- 上次写进日期的文字（避免每帧重设 Label 文本）。
	local lastDateText = "" -- 555
	--- >0 = 正在按住这个方向（-1 回退 / +1 加速）；0 = 没按住。
	local warpHoldDir = 0 -- 557
	--- 距离下一次连按还有多久（秒）。
	local warpRepeatIn = 0 -- 559
	local WarpButtonW = 116 -- 560
	local WarpButtonH = 64 -- 561
	local warpButtons = {} -- 562
	local function applyWarpState() -- 563
		local vis = dateSpan > 0 -- 564
		local on = vis and warpAllowed -- 565
		if vis == warpVisible and on == warpOn then -- 565
			return -- 566
		end -- 566
		warpVisible = vis -- 567
		warpOn = on -- 568
		if not on then -- 568
			warpHoldDir = 0 -- 569
		end -- 569
		for ____, b in ipairs(warpButtons) do -- 570
			b.root.visible = vis -- 571
			b:setEnabled(on) -- 572
		end -- 572
		if dateLabel ~= nil then -- 572
			dateLabel.visible = vis -- 574
		end -- 574
		datePlate.visible = vis -- 575
	end -- 563
	local function makeWarpButton(text, dir, x) -- 577
		local btn = createButton( -- 578
			root, -- 578
			{ -- 578
				w = WarpButtonW, -- 579
				h = WarpButtonH, -- 580
				text = text, -- 581
				fontSize = 30, -- 582
				bgHex = ResultButtonAltBgHex, -- 583
				fgHex = ResultButtonFgHex, -- 584
				borderHex = ResultButtonBorderHex, -- 585
				onTap = function() -- 588
				end, -- 588
				onPressBegan = function() -- 589
					print((("[escape-velocity] warp press dir=" .. __TS__NumberToFixed(dir, 0)) .. " on=") .. (warpOn and "1" or "0")) -- 591
					if not warpOn then -- 591
						return -- 592
					end -- 592
					if warpHoldDir == dir then -- 592
						return -- 594
					end -- 594
					warpHoldDir = dir -- 595
					warpRepeatIn = WarpHoldDelaySec -- 596
					if warpHandler ~= nil then -- 596
						warpHandler(dir) -- 597
					end -- 597
				end, -- 589
				onPressEnded = function() -- 599
					print((("[escape-velocity] warp release dir=" .. __TS__NumberToFixed(dir, 0)) .. " hold=") .. __TS__NumberToFixed(warpHoldDir, 0)) -- 600
					if warpHoldDir == dir then -- 600
						warpHoldDir = 0 -- 602
					end -- 602
				end -- 599
			} -- 599
		) -- 599
		btn.root.position = Vec2(x, viewH - 96 - WarpButtonH) -- 608
		warpButtons[#warpButtons + 1] = btn -- 609
	end -- 577
	local warpLeftX = viewW - (WarpButtonW * 2 + 8) - 20 -- 611
	makeWarpButton("◀ 回退", -1, warpLeftX) -- 612
	makeWarpButton("加速 ▶", 1, warpLeftX + WarpButtonW + 8) -- 613
	datePlate = createPanel( -- 615
		root, -- 615
		300, -- 615
		50, -- 615
		658964, -- 615
		{alpha = 0.45} -- 615
	) -- 615
	datePlate.position = Vec2(warpLeftX - 316, viewH - 96 - WarpButtonH + 8) -- 616
	dateLabel = createLabel(root, "发射日期 —", 30, ResultHintHex) -- 617
	if dateLabel ~= nil then -- 617
		dateLabel.anchor = Vec2(1, 0) -- 622
		dateLabel.position = Vec2(warpLeftX - 16, viewH - 96 - WarpButtonH + 18) -- 623
	end -- 623
	local QuickRetryW = 110 -- 627
	local QuickRetryH = 50 -- 628
	local quickRetryHandler = nil -- 629
	local quickRetryBtn = createButton( -- 630
		root, -- 630
		{ -- 630
			w = QuickRetryW, -- 631
			h = QuickRetryH, -- 632
			text = "↺ 重试", -- 633
			fontSize = 26, -- 634
			bgHex = 12730636, -- 635
			fgHex = 16777215, -- 636
			borderHex = 16498468, -- 637
			fireOn = "press", -- 638
			onTap = function() -- 639
				print("[escape-velocity] quick retry tapped") -- 640
				if quickRetryHandler ~= nil then -- 640
					quickRetryHandler() -- 641
				end -- 641
			end -- 639
		} -- 639
	) -- 639
	quickRetryBtn.root.position = Vec2(viewW - QuickRetryW - 20, viewH - QuickRetryH - 20) -- 644
	local starPlateW = 180 -- 647
	local starPlateH = 46 -- 648
	local starPlate = createPanel( -- 649
		root, -- 649
		starPlateW, -- 649
		starPlateH, -- 649
		658964, -- 649
		{alpha = 0.55} -- 649
	) -- 649
	starPlate.position = Vec2(viewW / 2 - starPlateW / 2, viewH - starPlateH - 22) -- 650
	starPlate.visible = not transferTutorial -- 651
	local starStatusLabel = createLabel(root, "☆ ☆ ☆", 30, 16766720) -- 652
	if starStatusLabel ~= nil then -- 652
		starStatusLabel.anchor = Vec2(0.5, 0.5) -- 654
		starStatusLabel.position = Vec2(viewW / 2, viewH - starPlateH / 2 - 22) -- 655
	end -- 655
	local function updateStarsStatus(count) -- 657
		if starStatusLabel == nil then -- 657
			return -- 658
		end -- 658
		if transferTutorial then -- 658
			starStatusLabel.visible = false -- 659
			return -- 659
		end -- 659
		local s = "☆ ☆ ☆" -- 660
		if count == 1 then -- 660
			s = "★ ☆ ☆" -- 661
		elseif count == 2 then -- 661
			s = "★ ★ ☆" -- 662
		elseif count >= 3 then -- 662
			s = "★ ★ ★" -- 663
		end -- 663
		setLabelText(starStatusLabel, s) -- 664
	end -- 657
	local LaunchButtonW = 220 -- 669
	local LaunchButtonH = 112 -- 670
	local launchButton = createButton( -- 671
		root, -- 671
		{ -- 671
			w = LaunchButtonW, -- 672
			h = LaunchButtonH, -- 673
			text = "▲ 发射 ▲", -- 674
			fontSize = 38, -- 675
			bgHex = ResultButtonBgHex, -- 676
			fgHex = ResultButtonFgHex, -- 677
			borderHex = ResultButtonBorderHex, -- 678
			fireOn = "press", -- 679
			onTap = function() -- 680
				print("[escape-velocity] launch button fire (press)") -- 681
				if launchHandler ~= nil then -- 681
					launchHandler() -- 682
				end -- 682
			end -- 680
		} -- 680
	) -- 680
	launchButton.root.position = Vec2(viewW - LaunchButtonW - 24, 96) -- 685
	launchButton.root.visible = false -- 686
	launchButton:setEnabled(false) -- 687
	local CancelButtonW = 160 -- 690
	local CancelButtonH = 72 -- 691
	local cancelAimHandler = nil -- 692
	local cancelAimButton = createButton( -- 693
		root, -- 693
		{ -- 693
			w = CancelButtonW, -- 694
			h = CancelButtonH, -- 695
			text = "✕ 取消", -- 696
			fontSize = 28, -- 697
			bgHex = ResultButtonAltBgHex, -- 698
			fgHex = ResultButtonFgHex, -- 699
			borderHex = ResultButtonBorderHex, -- 700
			fireOn = "press", -- 701
			onTap = function() -- 702
				print("[escape-velocity] cancel aim fire (press)") -- 703
				if cancelAimHandler ~= nil then -- 703
					cancelAimHandler() -- 704
				end -- 704
			end -- 702
		} -- 702
	) -- 702
	cancelAimButton.root.position = Vec2(viewW - LaunchButtonW - CancelButtonW - 40, 116) -- 707
	cancelAimButton.root.visible = false -- 708
	cancelAimButton:setEnabled(false) -- 709
	local ViewButtonW = 116 -- 713
	local ViewButtonH = 64 -- 714
	local viewHandler = nil -- 715
	local viewButton = createButton( -- 716
		root, -- 716
		{ -- 716
			w = ViewButtonW, -- 717
			h = ViewButtonH, -- 718
			text = "[ 3D ]", -- 719
			fontSize = 26, -- 720
			bgHex = ResultButtonAltBgHex, -- 721
			fgHex = ResultButtonFgHex, -- 722
			borderHex = ResultButtonBorderHex, -- 723
			fireOn = "press", -- 724
			onTap = function() -- 725
				print("[escape-velocity] view toggle fire (press)") -- 726
				if viewHandler ~= nil then -- 726
					viewHandler() -- 727
				end -- 727
			end -- 725
		} -- 725
	) -- 725
	viewButton.root.position = Vec2(viewW - ViewButtonW - 24, 96 + LaunchButtonH + 12) -- 730
	--- 上次写进按钮的文字（每帧都会被 setViewMode 调用，没变就别碰 Label）。
	local lastViewText = "2D" -- 732
	local cameraFocusHandler = nil -- 735
	local endViewingHandler = nil -- 736
	local cameraFocusButton = transferTutorial and createButton( -- 737
		root, -- 737
		{ -- 737
			w = 260, -- 738
			h = 58, -- 738
			text = "镜头 · 自动", -- 738
			fontSize = 22, -- 738
			bgHex = ResultButtonAltBgHex, -- 739
			fgHex = ResultButtonFgHex, -- 739
			borderHex = ResultButtonBorderHex, -- 739
			fireOn = "press", -- 739
			onTap = function() -- 740
				if cameraFocusHandler ~= nil then -- 740
					cameraFocusHandler() -- 740
				end -- 740
			end -- 740
		} -- 740
	) or nil -- 740
	local endViewingButton = transferTutorial and createButton( -- 742
		root, -- 742
		{ -- 742
			w = 220, -- 743
			h = LaunchButtonH, -- 743
			text = "结束观赏", -- 743
			fontSize = 26, -- 743
			bgHex = ResultButtonAltBgHex, -- 744
			fgHex = ResultButtonFgHex, -- 744
			borderHex = ResultButtonBorderHex, -- 744
			fireOn = "press", -- 744
			onTap = function() -- 745
				if endViewingHandler ~= nil then -- 745
					endViewingHandler() -- 745
				end -- 745
			end -- 745
		} -- 745
	) or nil -- 745
	if cameraFocusButton ~= nil then -- 745
		cameraFocusButton.root.position = Vec2(24, 266) -- 747
		cameraFocusButton.root.visible = false -- 747
		cameraFocusButton:setEnabled(false) -- 747
	end -- 747
	if endViewingButton ~= nil then -- 747
		endViewingButton.root.position = Vec2(viewW - 244, 96) -- 748
		endViewingButton.root.visible = false -- 748
		endViewingButton:setEnabled(false) -- 748
	end -- 748
	local ____transferTutorial_0 -- 749
	if transferTutorial then -- 749
		____transferTutorial_0 = createLabel(root, "", 24, ResultHintHex) -- 749
	else -- 749
		____transferTutorial_0 = nil -- 749
	end -- 749
	local viewingLabel = ____transferTutorial_0 -- 749
	if viewingLabel ~= nil then -- 749
		viewingLabel.position = Vec2(24, viewH - 130) -- 750
		viewingLabel.anchor = Vec2(0, 0) -- 750
		viewingLabel.visible = false -- 750
	end -- 750
	local viewingKey = "" -- 751
	local ZoomBtnSize = 58 -- 754
	local zoomGap = 8 -- 755
	local zoomButtons = {} -- 756
	local zoomInHandler = nil -- 757
	local zoomOutHandler = nil -- 758
	local fitViewHandler = nil -- 759
	local function makeZoomButton(text, x, fontSize, onClick) -- 761
		local btn = createButton( -- 762
			root, -- 762
			{ -- 762
				w = ZoomBtnSize, -- 763
				h = ZoomBtnSize, -- 764
				text = text, -- 765
				fontSize = fontSize, -- 766
				bgHex = ResultButtonAltBgHex, -- 767
				fgHex = ResultButtonFgHex, -- 768
				borderHex = ResultButtonBorderHex, -- 769
				fireOn = "press", -- 770
				onTap = function() -- 771
					print(("[escape-velocity] zoom btn " .. text) .. " fire") -- 772
					onClick() -- 773
				end -- 771
			} -- 771
		) -- 771
		btn.root.position = Vec2(x, 96) -- 776
		btn.root.visible = false -- 777
		btn:setEnabled(false) -- 778
		zoomButtons[#zoomButtons + 1] = btn -- 779
		return btn -- 780
	end -- 761
	makeZoomButton( -- 782
		"−", -- 782
		24, -- 782
		32, -- 782
		function() -- 782
			if zoomOutHandler ~= nil then -- 782
				zoomOutHandler() -- 783
			end -- 783
		end -- 782
	) -- 782
	makeZoomButton( -- 785
		"FIT", -- 785
		24 + ZoomBtnSize + zoomGap, -- 785
		20, -- 785
		function() -- 785
			if fitViewHandler ~= nil then -- 785
				fitViewHandler() -- 786
			end -- 786
		end -- 785
	) -- 785
	makeZoomButton( -- 788
		"+", -- 788
		24 + (ZoomBtnSize + zoomGap) * 2, -- 788
		32, -- 788
		function() -- 788
			if zoomInHandler ~= nil then -- 788
				zoomInHandler() -- 789
			end -- 789
		end -- 788
	) -- 788
	local zoomControlsVisible = nil -- 791
	local function setZoomVisible(on) -- 792
		if zoomControlsVisible == on then -- 792
			return -- 793
		end -- 793
		zoomControlsVisible = on -- 794
		for ____, b in ipairs(zoomButtons) do -- 795
			b.root.visible = on -- 796
			b:setEnabled(on) -- 797
		end -- 797
	end -- 792
	setZoomVisible(false) -- 800
	local TimeBtnW = 78 -- 806
	local TimeBtnH = 64 -- 807
	local TimeRowY = 170 -- 808
	local speedUpHandler = nil -- 809
	local speedDownHandler = nil -- 810
	local pauseHandler = nil -- 811
	local slowButton = createButton( -- 813
		root, -- 813
		{ -- 813
			w = TimeBtnW, -- 814
			h = TimeBtnH, -- 814
			text = "◀ 慢", -- 814
			fontSize = 26, -- 814
			bgHex = ResultButtonAltBgHex, -- 815
			fgHex = ResultButtonFgHex, -- 815
			borderHex = ResultButtonBorderHex, -- 815
			onTap = function() -- 816
				print("[escape-velocity] speed down fire") -- 817
				if speedDownHandler ~= nil then -- 817
					speedDownHandler() -- 818
				end -- 818
			end -- 816
		} -- 816
	) -- 816
	slowButton.root.position = Vec2(24, TimeRowY) -- 821
	local pauseButton = createButton( -- 822
		root, -- 822
		{ -- 822
			w = TimeBtnW, -- 823
			h = TimeBtnH, -- 823
			text = "⏸", -- 823
			fontSize = 30, -- 823
			bgHex = ResultButtonAltBgHex, -- 824
			fgHex = ResultButtonFgHex, -- 824
			borderHex = ResultButtonBorderHex, -- 824
			onTap = function() -- 825
				print("[escape-velocity] pause toggle fire") -- 826
				if pauseHandler ~= nil then -- 826
					pauseHandler() -- 827
				end -- 827
			end -- 825
		} -- 825
	) -- 825
	pauseButton.root.position = Vec2(24 + TimeBtnW + 8, TimeRowY) -- 830
	local fastButton = createButton( -- 831
		root, -- 831
		{ -- 831
			w = TimeBtnW, -- 832
			h = TimeBtnH, -- 832
			text = "快 ▶", -- 832
			fontSize = 26, -- 832
			bgHex = ResultButtonAltBgHex, -- 833
			fgHex = ResultButtonFgHex, -- 833
			borderHex = ResultButtonBorderHex, -- 833
			onTap = function() -- 834
				print("[escape-velocity] speed up fire") -- 835
				if speedUpHandler ~= nil then -- 835
					speedUpHandler() -- 836
				end -- 836
			end -- 834
		} -- 834
	) -- 834
	fastButton.root.position = Vec2(24 + (TimeBtnW + 8) * 2, TimeRowY) -- 839
	local timePlate = createPanel( -- 842
		root, -- 842
		300, -- 842
		50, -- 842
		658964, -- 842
		{alpha = 0.45} -- 842
	) -- 842
	timePlate.position = transferTutorial and Vec2(24, viewH - 190) or Vec2(24 + (TimeBtnW + 8) * 3 + 4, TimeRowY + 7) -- 843
	local timeLabel = createLabel(root, "1×（现实）  T+ 0:00", transferTutorial and 22 or 26, ResultHintHex) -- 844
	if timeLabel ~= nil then -- 844
		timeLabel.anchor = Vec2(0, 0) -- 846
		timeLabel.position = transferTutorial and Vec2(36, viewH - 179) or Vec2(24 + (TimeBtnW + 8) * 3 + 16, TimeRowY + 18) -- 847
	end -- 847
	--- 档位文字：pow 0 就是"1×（现实）"，别写成 1e0×。
	local function powText(pow) -- 850
		return pow <= 0 and "1×（现实）" or ("1e" .. __TS__NumberToFixed(pow, 0)) .. "×" -- 850
	end -- 850
	--- 任务时钟：真实秒 → "T+ 3天 04:12"。1× 下它每秒跳一格 —— 时间在流逝的唯一可见证据。
	local function missionText(sec) -- 852
		local s = sec > 0 and sec or 0 -- 853
		local days = math.floor(s / 86400) -- 854
		local rest = s - days * 86400 -- 855
		local hh = math.floor(rest / 3600) -- 856
		local mm = math.floor((rest - hh * 3600) / 60) -- 857
		local function pad(v) -- 858
			return (v < 10 and "0" or "") .. __TS__NumberToFixed(v, 0) -- 858
		end -- 858
		return ((("T+ " .. (days > 0 and __TS__NumberToFixed(days, 0) .. "天 " or "")) .. pad(hh)) .. ":") .. pad(mm) -- 859
	end -- 852
	local lastTimeText = "" -- 861
	local lastPaused = false -- 862
	local function setTimeControl(pow, maxPow, paused, missionSeconds, actualRate) -- 863
		local txt = (((transferTutorial and actualRate ~= nil and __TS__NumberToFixed(actualRate, 2) .. "×" or powText(pow)) .. (paused and " ⏸ 暂停" or "")) .. "  ") .. (transferTutorial and ("T+ " .. __TS__NumberToFixed(missionSeconds, 1)) .. "s" or missionText(missionSeconds)) -- 864
		if txt ~= lastTimeText then -- 864
			lastTimeText = txt -- 866
			if timeLabel ~= nil then -- 866
				timeLabel.text = txt -- 867
			end -- 867
		end -- 867
		if paused ~= lastPaused then -- 867
			lastPaused = paused -- 870
			pauseButton:setText(paused and "▶" or "⏸") -- 871
			pauseButton:setColors(paused and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 872
		end -- 872
		fastButton:setEnabled(pow < maxPow) -- 875
		slowButton:setEnabled(pow > 0) -- 876
	end -- 863
	local DrawerW = 380 -- 880
	local DrawerH = 46 -- 881
	local missionDrawerPlate = createPanel( -- 882
		root, -- 882
		DrawerW, -- 882
		DrawerH, -- 882
		658964, -- 882
		{alpha = 0.65, borderHex = 4610157} -- 882
	) -- 882
	missionDrawerPlate.position = Vec2(transferTutorial and 24 or (viewW - DrawerW) / 2, viewH - 56) -- 883
	local missionTitleLabel = createLabel(missionDrawerPlate, "", 19, 13426158) -- 884
	if missionTitleLabel ~= nil then -- 884
		missionTitleLabel.anchor = Vec2(0, 0.5) -- 886
		missionTitleLabel.position = Vec2(14, DrawerH / 2) -- 887
	end -- 887
	local missionRocketsLabel = createLabel(missionDrawerPlate, "☆  ☆  ☆", 22, 16766720) -- 889
	if missionRocketsLabel ~= nil then -- 889
		missionRocketsLabel.anchor = Vec2(1, 0.5) -- 891
		missionRocketsLabel.position = Vec2(DrawerW - 14, DrawerH / 2) -- 892
	end -- 892
	missionDrawerPlate.visible = false -- 894
	local drawerVisible = false -- 895
	local drawerLevelTitle = "" -- 896
	local drawerRockets = 0 -- 897
	local liveFuelBonus = false -- 898
	local function updateDrawerDisplay() -- 900
		if missionTitleLabel ~= nil then -- 900
			setLabelText(missionTitleLabel, drawerLevelTitle) -- 902
		end -- 902
		if missionRocketsLabel ~= nil then -- 902
			local r1 = drawerRockets >= 1 and "★" or "☆" -- 905
			local r2 = (drawerRockets >= 2 or liveFuelBonus) and "★" or "☆" -- 906
			local r3 = drawerRockets >= 3 and "★" or "☆" -- 907
			setLabelText(missionRocketsLabel, transferTutorial and (drawerRockets >= 1 and "已完成" or (transferMode == "lunar" and "地月转移练习" or "日心借力练习")) or (((r1 .. "  ") .. r2) .. "  ") .. r3) -- 908
		end -- 908
	end -- 900
	local IntroBannerW = math.min(viewW - 48, 540) -- 913
	local IntroBannerH = 68 -- 914
	local introBannerPlate = createPanel( -- 915
		root, -- 915
		IntroBannerW, -- 915
		IntroBannerH, -- 915
		658964, -- 915
		{alpha = 0.8, borderHex = 4610157} -- 915
	) -- 915
	introBannerPlate.position = Vec2((viewW - IntroBannerW) / 2, 70) -- 916
	local introBannerTitle = createLabel(introBannerPlate, "", 17, 15398143) -- 917
	if introBannerTitle ~= nil then -- 917
		introBannerTitle.anchor = Vec2(0.5, 0.5) -- 919
		introBannerTitle.position = Vec2(IntroBannerW / 2, IntroBannerH * 0.65) -- 920
	end -- 920
	local introBannerHint = createLabel(introBannerPlate, "轻触屏幕任意位置跳过运镜", 13, 9283005) -- 922
	if introBannerHint ~= nil then -- 922
		introBannerHint.anchor = Vec2(0.5, 0.5) -- 924
		introBannerHint.position = Vec2(IntroBannerW / 2, IntroBannerH * 0.28) -- 925
	end -- 925
	introBannerPlate.visible = false -- 927
	local PlaybackButtonW = 116 -- 936
	local PlaybackButtonH = 64 -- 937
	local playbackGap = 10 -- 938
	local playbackButtons = {} -- 939
	local playbackSpeeds = {} -- 940
	local playbackHandler = nil -- 941
	local speedChoice = speedChoices ~= nil and #speedChoices > 0 and speedChoices or ({1, 2, 4}) -- 944
	local playbackSpeed = speedChoice[1] -- 945
	--- 已应用到节点上的显隐状态。初值 false 如实反映"建出来就隐藏"（照 warp 按钮的教训）。
	local playbackVisible = false -- 947
	local function paintPlayback() -- 948
		do -- 948
			local i = 0 -- 949
			while i < #playbackButtons do -- 949
				local on = playbackSpeeds[i + 1] == playbackSpeed -- 950
				playbackButtons[i + 1]:setColors(on and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 951
				i = i + 1 -- 949
			end -- 949
		end -- 949
	end -- 948
	local function makePlaybackButton(speed, x) -- 954
		local btn = createButton( -- 955
			root, -- 955
			{ -- 955
				w = PlaybackButtonW, -- 956
				h = PlaybackButtonH, -- 957
				text = ____exports.playbackLabel(speed), -- 958
				fontSize = 30, -- 959
				bgHex = ResultButtonAltBgHex, -- 960
				fgHex = ResultButtonFgHex, -- 961
				borderHex = ResultButtonBorderHex, -- 962
				onTap = function() -- 963
					print(("[escape-velocity] playback button fire " .. __TS__NumberToFixed(speed, 0)) .. "x (release)") -- 965
					playbackSpeed = speed -- 966
					paintPlayback() -- 967
					if playbackHandler ~= nil then -- 967
						playbackHandler(speed) -- 968
					end -- 968
				end -- 963
			} -- 963
		) -- 963
		btn.root.position = Vec2(x, 96) -- 973
		playbackButtons[#playbackButtons + 1] = btn -- 974
		playbackSpeeds[#playbackSpeeds + 1] = speed -- 975
	end -- 954
	do -- 954
		local i = 0 -- 977
		while i < #speedChoice and i < 3 do -- 977
			makePlaybackButton(speedChoice[i + 1], 24 + (PlaybackButtonW + playbackGap) * i) -- 978
			i = i + 1 -- 977
		end -- 977
	end -- 977
	paintPlayback() -- 980
	for ____, b in ipairs(playbackButtons) do -- 982
		b.root.visible = false -- 983
		b:setEnabled(false) -- 984
	end -- 984
	local brakeRightX = viewW - BrakeButtonW - 20 -- 987
	if not transferTutorial then -- 987
		makeBrakeButton("惯性", false, brakeRightX - BrakeButtonW - brakeGap) -- 989
		makeBrakeButton("刹车", true, brakeRightX) -- 990
	end -- 990
	paintBrake() -- 992
	local liveBrakeHandler = nil -- 995
	local liveBrakeActive = false -- 996
	local liveBrakedState = false -- 997
	local LiveBrakeW = 220 -- 998
	local LiveBrakeH = 100 -- 999
	local liveBrakeButton = createButton( -- 1000
		root, -- 1000
		{ -- 1000
			w = LiveBrakeW, -- 1001
			h = LiveBrakeH, -- 1002
			text = "BRAKE 逆喷", -- 1003
			fontSize = 36, -- 1004
			bgHex = 10899464, -- 1005
			fgHex = 16775392, -- 1006
			borderHex = 16755251, -- 1007
			fireOn = "press", -- 1008
			onTap = function() -- 1009
				print("[escape-velocity] live brake button fire (press)") -- 1010
				if liveBrakeHandler ~= nil then -- 1010
					liveBrakeHandler() -- 1011
				end -- 1011
			end -- 1009
		} -- 1009
	) -- 1009
	liveBrakeButton.root.position = Vec2(viewW - LiveBrakeW - 24, 96) -- 1014
	liveBrakeButton.root.visible = false -- 1015
	liveBrakeButton:setEnabled(false) -- 1016
	local hintW = 440 -- 1019
	local hintH = 50 -- 1020
	local brakeHintPlate = createPanel( -- 1021
		root, -- 1021
		hintW, -- 1021
		hintH, -- 1021
		658964, -- 1021
		{alpha = 0.65, borderHex = 16755251} -- 1021
	) -- 1021
	brakeHintPlate.position = Vec2((viewW - hintW) / 2, viewH - 240) -- 1022
	local brakeHintLabel = createLabel(brakeHintPlate, "【木星捕获窗口已开启 · 按下 BRAKE 逆喷入轨】", 22, 16762939) -- 1023
	if brakeHintLabel ~= nil then -- 1023
		setLabelCenter(brakeHintLabel, hintW / 2, hintH / 2) -- 1025
	end -- 1025
	brakeHintPlate.visible = false -- 1027
	parent:addChild(root) -- 1029
	return { -- 1031
		onDrag = function(____, callback) -- 1032
			dragHandler = callback -- 1033
		end, -- 1032
		setEnabled = function(____, value) -- 1035
			enabled = value -- 1036
			touchLayer.touchEnabled = value -- 1039
			if not value then -- 1039
				dragging = false -- 1041
				liveBrakeActive = false -- 1042
				liveBrakeButton.root.visible = false -- 1043
				liveBrakeButton:setEnabled(false) -- 1044
				brakeHintPlate.visible = false -- 1045
			end -- 1045
		end, -- 1035
		onBrake = function(____, callback) -- 1048
			brakeHandler = callback -- 1049
		end, -- 1048
		setBrake = function(____, on) -- 1051
			brakeOn = on -- 1052
			paintBrake() -- 1053
		end, -- 1051
		onAimReady = function(____, callback) -- 1055
			readyHandler = callback -- 1056
		end, -- 1055
		onObserve = function(____, callback) -- 1058
			observeHandler = callback -- 1059
		end, -- 1058
		onZoom = function(____, callback) -- 1061
			zoomHandler = callback -- 1062
		end, -- 1061
		onLaunch = function(____, callback) -- 1064
			launchHandler = callback -- 1065
		end, -- 1064
		onCancelAim = function(____, callback) -- 1067
			cancelAimHandler = callback -- 1068
		end, -- 1067
		setArmed = function(____, armed) -- 1070
			launchButton.root.visible = armed -- 1071
			launchButton:setEnabled(armed) -- 1072
			cancelAimButton.root.visible = armed -- 1073
			cancelAimButton:setEnabled(armed) -- 1074
		end, -- 1070
		onViewToggle = function(____, callback) -- 1076
			viewHandler = callback -- 1077
		end, -- 1076
		onCameraFocus = function(____, callback) -- 1079
			cameraFocusHandler = callback -- 1079
		end, -- 1079
		onEndViewing = function(____, callback) -- 1080
			endViewingHandler = callback -- 1080
		end, -- 1080
		setFlightViewing = function(____, flying, completed, mode, is3D, stage) -- 1081
			if not transferTutorial then -- 1081
				return -- 1082
			end -- 1082
			local key = ((((flying and "1" or "0") .. (completed and "1" or "0")) .. mode) .. (is3D and "1" or "0")) .. (stage ~= nil and stage or "") -- 1083
			if viewingKey == key then -- 1083
				return -- 1084
			end -- 1084
			viewingKey = key -- 1085
			if dvLabel ~= nil then -- 1085
				dvLabel.visible = not flying -- 1086
			end -- 1086
			if viewingLabel ~= nil then -- 1086
				viewingLabel.visible = flying -- 1088
				local near = stage == "Venus" and "金星减速借力" or (stage == "Jupiter" and "木星加速借力" or (stage == "Saturn" and "土星加速借力" or (stage == "Moon" and "借月球引力 · 观察轨迹转弯" or "滑行 · 观察航线"))) -- 1089
				setLabelText(viewingLabel, completed and (transferMode == "lunar" and "掠月完成 · 继续观察返回" or "目标完成 · 继续观察航线") or (stage == "Launch" and (transferMode == "inward" and "逆行点火 · 降低近日点" or "顺行点火 · 抬高" .. orbitName) or near)) -- 1090
				setLabelColor(viewingLabel, completed and 9430458 or ResultHintHex) -- 1091
			end -- 1091
			if cameraFocusButton ~= nil then -- 1091
				cameraFocusButton.root.visible = flying and is3D -- 1094
				cameraFocusButton:setEnabled(flying and is3D) -- 1095
				local title = mode == "Auto" and "自动" or (mode == "Probe" and "探测器" or (mode == "Moon" and "月球" or (mode == "Earth" and "地球" or (mode == "Venus" and "金星" or (mode == "Jupiter" and "木星" or (mode == "Saturn" and "土星" or (mode == "Sun" and "太阳" or "总览"))))))) -- 1096
				cameraFocusButton:setText("镜头 · " .. title) -- 1097
			end -- 1097
			if endViewingButton ~= nil then -- 1097
				endViewingButton.root.visible = flying and completed -- 1099
				endViewingButton:setEnabled(flying and completed) -- 1099
			end -- 1099
		end, -- 1081
		setViewMode = function(____, mode) -- 1101
			if mode == lastViewText then -- 1101
				return -- 1102
			end -- 1102
			lastViewText = mode -- 1103
			local btnText = mode == "2D" and "[ 3D ]" or "[ 2D ]" -- 1105
			viewButton:setText(btnText) -- 1106
		end, -- 1101
		onPlayback = function(____, callback) -- 1108
			playbackHandler = callback -- 1109
		end, -- 1108
		setPlayback = function(____, speed) -- 1111
			if speed == playbackSpeed then -- 1111
				return -- 1112
			end -- 1112
			playbackSpeed = speed -- 1113
			paintPlayback() -- 1114
		end, -- 1111
		setPlaybackVisible = function(____, on) -- 1116
			if on == playbackVisible then -- 1116
				return -- 1117
			end -- 1117
			playbackVisible = on -- 1118
			for ____, b in ipairs(playbackButtons) do -- 1119
				b.root.visible = on -- 1120
				b:setEnabled(on) -- 1121
			end -- 1121
		end, -- 1116
		setFullScreenAim = function(____, on) -- 1124
			fullScreenAim = on -- 1125
		end, -- 1124
		onWarp = function(____, callback) -- 1127
			warpHandler = callback -- 1128
		end, -- 1127
		setDate = function(____, t0, span) -- 1130
			dateSpan = span > 0 and span or 0 -- 1131
			applyWarpState() -- 1132
			local on = dateSpan > 0 -- 1133
			local text = on and (("发射日期 " .. __TS__NumberToFixed(t0, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0) or "发射日期" -- 1134
			if text ~= lastDateText then -- 1134
				lastDateText = text -- 1136
				setLabelText(dateLabel, text) -- 1137
			end -- 1137
		end, -- 1130
		setTimeEnabled = function(____, on) -- 1140
			if warpAllowed == on then -- 1140
				return -- 1141
			end -- 1141
			warpAllowed = on -- 1142
			applyWarpState() -- 1143
		end, -- 1140
		update = function(____, dt) -- 1145
			if not warpOn or warpHoldDir == 0 then -- 1145
				return -- 1146
			end -- 1146
			warpRepeatIn = warpRepeatIn - dt -- 1147
			if warpRepeatIn > 0 then -- 1147
				return -- 1148
			end -- 1148
			warpRepeatIn = TimeWarpStep / TimeWarpRate -- 1150
			if warpHandler ~= nil then -- 1150
				warpHandler(warpHoldDir) -- 1151
			end -- 1151
		end, -- 1145
		isDragging = function() return dragging end, -- 1153
		setBurnInfo = function(____, burn, budget) -- 1154
			if transferTutorial then -- 1154
				return -- 1155
			end -- 1155
			local b = budget < 1 and __TS__NumberToFixed(budget, 2) or __TS__NumberToFixed(budget, 0) -- 1159
			local v = burn < 1 and __TS__NumberToFixed(burn, 2) or __TS__NumberToFixed(burn, 1) -- 1160
			setLabelText(dvLabel, (("Δv " .. v) .. " / ") .. b) -- 1161
		end, -- 1154
		current = function() return aim end, -- 1163
		setTransferInfo = function(____, apoapsis, duration, reachable) -- 1164
			setLabelText( -- 1165
				dvLabel, -- 1165
				(((((orbitName .. " ") .. __TS__NumberToFixed(apoapsis, 0)) .. " · 点火 ") .. __TS__NumberToFixed(duration, 2)) .. "s") .. (reachable ~= nil and (reachable and (transferMode == "lunar" and " · 可减速掠月" or " · 航线可行") or " · 等待窗口") or "") -- 1165
			) -- 1165
		end, -- 1164
		setProbeOffset = function(____, offset) -- 1167
			probeOffset = offset -- 1168
		end, -- 1167
		handleLocal = function(____, ____local) -- 1172
			handleDelta(____exports.localToOffset(____local, space)) -- 1173
		end, -- 1172
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 1176
		debugProbeOffset = function() return probeOffset end, -- 1177
		onLiveBrake = function(____, callback) -- 1178
			liveBrakeHandler = callback -- 1179
		end, -- 1178
		setLiveBrakeVisible = function(____, visible) -- 1181
			if liveBrakeActive == visible then -- 1181
				return -- 1182
			end -- 1182
			liveBrakeActive = visible -- 1183
			liveBrakeButton.root.visible = visible -- 1184
			liveBrakeButton:setEnabled(visible) -- 1185
			brakeHintPlate.visible = visible -- 1186
		end, -- 1181
		setLiveBraked = function(____, braked) -- 1188
			if liveBrakedState == braked then -- 1188
				return -- 1189
			end -- 1189
			liveBrakedState = braked -- 1190
			if braked then -- 1190
				liveBrakeButton:setText("已捕获入轨") -- 1192
				liveBrakeButton:setColors(1589810, 13697002) -- 1193
				liveBrakeButton:setEnabled(false) -- 1194
				if brakeHintLabel ~= nil then -- 1194
					setLabelText(brakeHintLabel, "【主发动机逆喷成功！已捕获入轨】") -- 1196
					setLabelColor(brakeHintLabel, 4122272) -- 1197
				end -- 1197
			else -- 1197
				liveBrakeButton:setText("BRAKE 逆喷") -- 1200
				liveBrakeButton:setColors(10899464, 16775392) -- 1201
				if brakeHintLabel ~= nil then -- 1201
					setLabelText(brakeHintLabel, "【木星捕获窗口已开启 · 按下 BRAKE 逆喷入轨】") -- 1203
					setLabelColor(brakeHintLabel, 16762939) -- 1204
				end -- 1204
			end -- 1204
		end, -- 1188
		onSpeedUp = function(____, callback) -- 1208
			speedUpHandler = callback -- 1209
		end, -- 1208
		onSpeedDown = function(____, callback) -- 1211
			speedDownHandler = callback -- 1212
		end, -- 1211
		onTogglePause = function(____, callback) -- 1214
			pauseHandler = callback -- 1215
		end, -- 1214
		setTimeControl = function(____, pow, maxPow, paused, missionSeconds, actualRate) -- 1217
			setTimeControl( -- 1218
				pow, -- 1218
				maxPow, -- 1218
				paused, -- 1218
				missionSeconds, -- 1218
				actualRate -- 1218
			) -- 1218
		end, -- 1217
		onZoomIn = function(____, callback) -- 1220
			zoomInHandler = callback -- 1221
		end, -- 1220
		onZoomOut = function(____, callback) -- 1223
			zoomOutHandler = callback -- 1224
		end, -- 1223
		onFitView = function(____, callback) -- 1226
			fitViewHandler = callback -- 1227
		end, -- 1226
		setZoomControlsVisible = function(____, on) -- 1229
			setZoomVisible(on) -- 1230
		end, -- 1229
		setMissionDrawer = function(____, levelName, _challenges, currentRockets) -- 1232
			drawerLevelTitle = levelName -- 1233
			drawerRockets = currentRockets -- 1234
			updateDrawerDisplay() -- 1235
		end, -- 1232
		setMissionDrawerVisible = function(____, visible) -- 1237
			if drawerVisible == visible then -- 1237
				return -- 1238
			end -- 1238
			drawerVisible = visible -- 1239
			missionDrawerPlate.visible = visible -- 1240
		end, -- 1237
		setLiveFuelChallengeStatus = function(____, achieved) -- 1242
			if liveFuelBonus == achieved then -- 1242
				return -- 1243
			end -- 1243
			liveFuelBonus = achieved -- 1244
			updateDrawerDisplay() -- 1245
		end, -- 1242
		setIntroTourBanner = function(____, title, hint) -- 1247
			if introBannerTitle ~= nil then -- 1247
				setLabelText(introBannerTitle, title) -- 1248
			end -- 1248
			if introBannerHint ~= nil and hint ~= nil then -- 1248
				setLabelText(introBannerHint, hint) -- 1249
			end -- 1249
		end, -- 1247
		setIntroTourBannerVisible = function(____, visible) -- 1251
			introBannerPlate.visible = visible -- 1252
		end, -- 1251
		onSkipTour = function(____, callback) -- 1254
			skipTourHandler = callback -- 1255
		end, -- 1254
		setTourActiveChecker = function(____, fn) -- 1257
			tourActiveChecker = fn -- 1258
		end, -- 1257
		onQuickRetry = function(____, callback) -- 1260
			quickRetryHandler = callback -- 1261
		end, -- 1260
		setStarsStatus = function(____, starsGot) -- 1263
			updateStarsStatus(starsGot) -- 1264
		end, -- 1263
		root = root -- 1266
	} -- 1266
end -- 351
local ResultBackdropHex = 329484 -- 1283
local ResultCardHex = 1252395 -- 1284
local ResultCardBorderHex = 3362938 -- 1285
local ResultLevelHex = 9417948 -- 1286
local ResultBodyHex = 14149367 -- 1287
ResultHintHex = 8229803 -- 1288
ResultButtonBgHex = 1919610 -- 1289
ResultButtonAltBgHex = 1779509 -- 1290
ResultButtonFgHex = 15398143 -- 1291
ResultButtonBorderHex = 5211846 -- 1292
local TitleSuccessHex = 8381344 -- 1293
local TitleMissedHex = 16766073 -- 1294
local TitleCrashedHex = 16743019 -- 1295
local SelectBackdropHex = 329484 -- 1297
local SelectTitleHex = 16777215 -- 1298
local SelectSubtitleHex = 10470632 -- 1299
local SelectHintHex = 7309478 -- 1300
local SelectOpenBgHex = 1919610 -- 1301
local SelectOpenFgHex = 15398143 -- 1302
local SelectLockedBgHex = 1383204 -- 1303
local SelectLockedFgHex = 6912140 -- 1304
local SelectBorderHex = 4157096 -- 1305
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 1308
	if value < lo then -- 1308
		return lo -- 1309
	end -- 1309
	if value > hi then -- 1309
		return hi -- 1310
	end -- 1310
	return value -- 1311
end -- 1308
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 1315
	if result == "success" then -- 1315
		return "借力成功" -- 1316
	end -- 1316
	if result == "crashed" then -- 1316
		return "信号中断" -- 1317
	end -- 1317
	return "错过目标" -- 1318
end -- 1315
--- 三态说明句（逐字）。
local function resultBody(result) -- 1322
	if result == "success" then -- 1322
		return "行星把探测器甩了出去，速度够了。" -- 1323
	end -- 1323
	if result == "crashed" then -- 1323
		return "探测器撞上行星，任务到此为止。" -- 1324
	end -- 1324
	return "从行星身侧掠过，没能借到那一点速度。" -- 1325
end -- 1322
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 1329
	if result == "success" then -- 1329
		return TitleSuccessHex -- 1330
	end -- 1330
	if result == "crashed" then -- 1330
		return TitleCrashedHex -- 1331
	end -- 1331
	return TitleMissedHex -- 1332
end -- 1329
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 1341
	if result == "success" then -- 1341
		return "下一关已解锁" -- 1342
	end -- 1342
	return "可重试本关，或返回关卡选择" -- 1343
end -- 1341
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 1388
	local root = createPanel( -- 1394
		parent, -- 1394
		viewW, -- 1394
		viewH, -- 1394
		ResultBackdropHex, -- 1394
		{alpha = 0.78} -- 1394
	) -- 1394
	local cardW = clampNumber(viewW * 0.9, 360, 560) -- 1396
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 480) -- 1397
	local btnH = clampNumber(viewH * 0.08, 48, 60) -- 1398
	local padX = (cardW - btnW) / 2 -- 1399
	local padY = 28 -- 1400
	local fontLevel = 24 -- 1402
	local fontRockets = 38 -- 1403
	local fontTitle = 30 -- 1404
	local fontTelemetry = 19 -- 1405
	local fontChallenge = 18 -- 1406
	local fontTotal = 20 -- 1407
	local btnFont = 24 -- 1408
	local rowGap = 12 -- 1409
	local hLevel = 28 -- 1411
	local hRockets = 42 -- 1412
	local hTitle = 34 -- 1413
	local hTelemetry = 24 -- 1414
	local hChallengeRow = 30 -- 1415
	local hChallenges = hChallengeRow * 3 -- 1416
	local hTotal = 24 -- 1417
	local cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7 -- 1419
	if cardH > viewH - 24 then -- 1419
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 1421
		cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7 -- 1422
	end -- 1422
	local card = createPanel( -- 1425
		root, -- 1425
		cardW, -- 1425
		cardH, -- 1425
		ResultCardHex, -- 1425
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 1425
	) -- 1425
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 1430
	local cursor = cardH - padY -- 1433
	cursor = cursor - hLevel -- 1435
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 1436
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 1437
	cursor = cursor - (rowGap + hRockets) -- 1439
	local rocketsLabel = createLabel(card, "", fontRockets, 16762939) -- 1440
	setLabelCenter(rocketsLabel, cardW / 2, cursor + hRockets / 2) -- 1441
	cursor = cursor - (rowGap + hTitle) -- 1443
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 1444
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 1445
	cursor = cursor - (rowGap + hTelemetry) -- 1447
	local telemetryLabel = createLabel(card, "", fontTelemetry, ResultHintHex) -- 1448
	setLabelCenter(telemetryLabel, cardW / 2, cursor + hTelemetry / 2) -- 1449
	cursor = cursor - rowGap -- 1451
	local challengeLabels = {} -- 1452
	do -- 1452
		local k = 0 -- 1453
		while k < 3 do -- 1453
			cursor = cursor - hChallengeRow -- 1454
			local cl = createLabel(card, "", fontChallenge, 10405355) -- 1455
			if cl ~= nil then -- 1455
				cl.textWidth = cardW - 60 -- 1457
				setLabelCenter(cl, cardW / 2, cursor + hChallengeRow / 2) -- 1458
				challengeLabels[#challengeLabels + 1] = cl -- 1459
			end -- 1459
			k = k + 1 -- 1453
		end -- 1453
	end -- 1453
	cursor = cursor - (rowGap + hTotal) -- 1463
	local totalLabel = createLabel(card, "", fontTotal, 16766073) -- 1464
	setLabelCenter(totalLabel, cardW / 2, cursor + hTotal / 2) -- 1465
	cursor = cursor - (rowGap + btnH) -- 1467
	local retryButton = createButton(card, { -- 1468
		w = btnW, -- 1469
		h = btnH, -- 1470
		text = "重试本关", -- 1471
		fontSize = btnFont, -- 1472
		bgHex = ResultButtonBgHex, -- 1473
		fgHex = ResultButtonFgHex, -- 1474
		borderHex = ResultButtonBorderHex, -- 1475
		fireOn = "press", -- 1476
		onTap = opts.onRetry -- 1477
	}) -- 1477
	retryButton.root.position = Vec2(padX, cursor) -- 1479
	cursor = cursor - (14 + btnH) -- 1481
	local backButton = createButton(card, { -- 1482
		w = btnW, -- 1483
		h = btnH, -- 1484
		text = "返回关卡选择", -- 1485
		fontSize = btnFont, -- 1486
		bgHex = ResultButtonAltBgHex, -- 1487
		fgHex = ResultButtonFgHex, -- 1488
		borderHex = ResultButtonBorderHex, -- 1489
		fireOn = "press", -- 1490
		onTap = opts.onBackToSelect -- 1491
	}) -- 1491
	backButton.root.position = Vec2(padX, cursor) -- 1493
	root.visible = false -- 1495
	retryButton:setEnabled(false) -- 1496
	backButton:setEnabled(false) -- 1497
	return { -- 1499
		root = root, -- 1500
		show = function(____, result, levelName, detail) -- 1501
			retryButton:setEnabled(true) -- 1502
			backButton:setEnabled(true) -- 1503
			setLabelText(levelLabel, levelName) -- 1504
			setLabelText( -- 1505
				titleLabel, -- 1505
				resultTitle(result) -- 1505
			) -- 1505
			setLabelColor( -- 1506
				titleLabel, -- 1506
				resultTitleColor(result) -- 1506
			) -- 1506
			if detail ~= nil then -- 1506
				if detail.completionOnly == true then -- 1506
					setLabelText( -- 1509
						titleLabel, -- 1509
						result == "success" and "引力借力完成" or resultTitle(result) -- 1509
					) -- 1509
				end -- 1509
				local rCount = detail.rocketsGot -- 1510
				local rStr = "☆  ☆  ☆" -- 1511
				if rCount == 1 then -- 1511
					rStr = "★  ☆  ☆" -- 1512
				elseif rCount == 2 then -- 1512
					rStr = "★  ★  ☆" -- 1513
				elseif rCount >= 3 then -- 1513
					rStr = "★  ★  ★" -- 1514
				end -- 1514
				setLabelText(rocketsLabel, detail.completionOnly == true and (result == "success" and "目标已完成" or "再试一次") or rStr) -- 1515
				setLabelColor(rocketsLabel, rCount > 0 and 16762939 or 6322324) -- 1516
				local pct = detail.dvBudget > 0 and math.floor(detail.burnDv / detail.dvBudget * 100) or 0 -- 1518
				local telemText = ((((((("点火消耗 Δv: " .. __TS__NumberToFixed(detail.burnDv, 2)) .. " / ") .. __TS__NumberToFixed(detail.dvBudget, 2)) .. " (") .. __TS__NumberToFixed(pct, 0)) .. "%) · 用时: ") .. __TS__NumberToFixed(detail.flightTime, 1)) .. "s" -- 1519
				setLabelText(telemetryLabel, telemText) -- 1520
				do -- 1520
					local k = 0 -- 1522
					while k < 3 do -- 1522
						if challengeLabels[k + 1] ~= nil then -- 1522
							if k < #detail.challenges then -- 1522
								local ok = detail.achieved[k + 1] -- 1525
								local icon = ok and "★" or "☆" -- 1526
								local rank = k == 0 and "一星" or (k == 1 and "二星" or "三星") -- 1527
								local text = detail.completionOnly == true and (ok and "目标完成 · 记录已保存" or "尚未完成目标") or (((icon .. " [") .. rank) .. "] ") .. detail.challenges[k + 1] -- 1528
								setLabelText(challengeLabels[k + 1], text) -- 1529
								setLabelColor(challengeLabels[k + 1], ok and 16762939 or 6322324) -- 1530
								challengeLabels[k + 1].visible = true -- 1531
							else -- 1531
								challengeLabels[k + 1].visible = false -- 1533
							end -- 1533
						end -- 1533
						k = k + 1 -- 1522
					end -- 1522
				end -- 1522
				setLabelText( -- 1538
					totalLabel, -- 1538
					((("全深空火箭勋章: " .. __TS__NumberToFixed(detail.totalRockets, 0)) .. " / ") .. __TS__NumberToFixed(detail.totalPossibleRockets, 0)) .. " ★" -- 1538
				) -- 1538
				if totalLabel ~= nil then -- 1538
					totalLabel.visible = detail.completionOnly ~= true -- 1539
				end -- 1539
			else -- 1539
				setLabelText(rocketsLabel, result == "success" and "★  ☆  ☆" or "☆  ☆  ☆") -- 1541
				setLabelColor(rocketsLabel, result == "success" and 16762939 or 6322324) -- 1542
				setLabelText( -- 1543
					telemetryLabel, -- 1543
					resultBody(result) -- 1543
				) -- 1543
				do -- 1543
					local k = 0 -- 1544
					while k < #challengeLabels do -- 1544
						challengeLabels[k + 1].visible = false -- 1544
						k = k + 1 -- 1544
					end -- 1544
				end -- 1544
				if totalLabel ~= nil then -- 1544
					totalLabel.visible = false -- 1545
				end -- 1545
			end -- 1545
			root.visible = true -- 1547
		end, -- 1501
		hide = function() -- 1549
			root.visible = false -- 1550
			retryButton:setEnabled(false) -- 1551
			backButton:setEnabled(false) -- 1552
		end -- 1549
	} -- 1549
end -- 1388
local FinaleBackdropHex = 329484 -- 1567
local FinaleMainHex = 15398143 -- 1568
local FinaleSubHex = 10470632 -- 1569
--- 终章主文案（逐字；改之前先改 PLAN S3.18 与 docs/开发手册.md）。
____exports.FinaleMainText = "这就是我们整颗星球的样子 —— 而你已经从那里飞到了这里。" -- 1574
--- 终章小字：飞行距离 / 用时（纯函数，可单测）。
-- 
-- 距离是**平面单位**（关卡尺度，不是公里）—— 别在这里换算成天文单位，
-- 那一换就得把整条注释重写一遍，而玩家要的只是「飞了多远、花了多久」。
function ____exports.finaleSubtitle(distance, time) -- 1582
	return ((("飞行 " .. __TS__NumberToFixed(distance, 0)) .. " 单位 · 用时 ") .. __TS__NumberToFixed(time, 1)) .. " 秒" -- 1583
end -- 1582
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
function ____exports.createFinalePanel(parent, viewW, viewH, opts) -- 1613
	local root = createPanel( -- 1619
		parent, -- 1619
		viewW, -- 1619
		viewH, -- 1619
		FinaleBackdropHex, -- 1619
		{alpha = 0.55} -- 1619
	) -- 1619
	local fontMain = 34 -- 1621
	local fontSub = 30 -- 1622
	local btnFont = 40 -- 1623
	local mainLabel = createLabel(root, ____exports.FinaleMainText, fontMain, FinaleMainHex) -- 1625
	if mainLabel ~= nil then -- 1625
		mainLabel.textWidth = viewW * 0.88 -- 1628
		setLabelCenter(mainLabel, viewW / 2, viewH * 0.8) -- 1629
	end -- 1629
	local subLabel = createLabel(root, "", fontSub, FinaleSubHex) -- 1632
	if subLabel ~= nil then -- 1632
		setLabelCenter(subLabel, viewW / 2, viewH * 0.71) -- 1633
	end -- 1633
	local btnW = clampNumber(viewW * 0.62, MinButtonWidth, 560) -- 1635
	local btnH = clampNumber(viewH * 0.085, MinButtonHeight, 120) -- 1636
	local backButton = createButton(root, { -- 1637
		w = btnW, -- 1638
		h = btnH, -- 1639
		text = "返回关卡选择", -- 1640
		fontSize = btnFont, -- 1641
		bgHex = ResultButtonBgHex, -- 1642
		fgHex = ResultButtonFgHex, -- 1643
		borderHex = ResultButtonBorderHex, -- 1644
		fireOn = "press", -- 1646
		onTap = opts.onBackToSelect -- 1647
	}) -- 1647
	backButton.root.position = Vec2((viewW - btnW) / 2, 110) -- 1649
	root.visible = false -- 1651
	backButton:setEnabled(false) -- 1653
	return { -- 1655
		root = root, -- 1656
		show = function(____, main, sub) -- 1657
			setLabelText(mainLabel, main) -- 1658
			setLabelText(subLabel, sub) -- 1659
			backButton:setEnabled(true) -- 1660
			root.visible = true -- 1661
		end, -- 1657
		hide = function() -- 1663
			root.visible = false -- 1664
			backButton:setEnabled(false) -- 1666
		end -- 1663
	} -- 1663
end -- 1613
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 1705
	local root = createPanel( -- 1711
		parent, -- 1711
		viewW, -- 1711
		viewH, -- 1711
		SelectBackdropHex, -- 1711
		{alpha = 0.9} -- 1711
	) -- 1711
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 1713
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 1714
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 1716
	setLabelCenter( -- 1717
		subtitleLabel, -- 1717
		viewW / 2, -- 1717
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 1717
	) -- 1717
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 1719
	setLabelCenter( -- 1720
		hintLabel, -- 1720
		viewW / 2, -- 1720
		clampNumber(viewH * 0.045, 36, 90) -- 1720
	) -- 1720
	local count = #opts.levels -- 1722
	local cols = viewH > viewW and 2 or 1 -- 1725
	local rows = math.max( -- 1726
		1, -- 1726
		math.ceil(count / cols) -- 1726
	) -- 1726
	local gap = 18 -- 1727
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 1728
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 1729
	local availW = viewW * 0.84 -- 1730
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 1731
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 1732
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 1733
	local gridW = cols * btnW + gap * (cols - 1) -- 1734
	local topY = viewH - headerH -- 1735
	local buttons = {} -- 1737
	do -- 1737
		local i = 0 -- 1738
		while i < count do -- 1738
			local index = i -- 1740
			local button = createButton( -- 1741
				root, -- 1741
				{ -- 1741
					w = btnW, -- 1742
					h = btnH, -- 1743
					text = opts.levels[index + 1].name, -- 1744
					fontSize = 38, -- 1745
					bgHex = SelectLockedBgHex, -- 1746
					fgHex = SelectLockedFgHex, -- 1747
					borderHex = SelectBorderHex, -- 1748
					fireOn = "press", -- 1750
					onTap = function() return opts:onPick(index) end -- 1751
				} -- 1751
			) -- 1751
			local col = index % cols -- 1753
			local rowIndex = math.floor(index / cols) -- 1754
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 1755
			buttons[#buttons + 1] = button -- 1759
			i = i + 1 -- 1738
		end -- 1738
	end -- 1738
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 1765
		root, -- 1766
		{ -- 1766
			w = clampNumber(viewW * 0.36, 180, 300), -- 1767
			h = MinButtonHeight, -- 1768
			text = "重看开场", -- 1769
			fontSize = 30, -- 1770
			bgHex = SelectLockedBgHex, -- 1771
			fgHex = SelectSubtitleHex, -- 1772
			borderHex = SelectBorderHex, -- 1773
			fireOn = "press", -- 1774
			onTap = function() -- 1775
				if opts.onReplayIntro ~= nil then -- 1775
					opts:onReplayIntro() -- 1776
				end -- 1776
			end -- 1775
		} -- 1775
	) or nil -- 1775
	if replayButton ~= nil then -- 1775
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 1781
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 1782
		replayButton.root.position = Vec2( -- 1783
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 1783
			by -- 1783
		) -- 1783
	end -- 1783
	root.visible = false -- 1786
	do -- 1786
		local i = 0 -- 1787
		while i < count do -- 1787
			buttons[i + 1]:setEnabled(false) -- 1787
			i = i + 1 -- 1787
		end -- 1787
	end -- 1787
	if replayButton ~= nil then -- 1787
		replayButton:setEnabled(false) -- 1788
	end -- 1788
	return { -- 1790
		root = root, -- 1791
		show = function(____, unlocked) -- 1792
			local maxUnlocked = clampNumber( -- 1793
				math.floor(unlocked), -- 1793
				0, -- 1793
				count - 1 -- 1793
			) -- 1793
			setLabelText( -- 1794
				subtitleLabel, -- 1794
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 1794
			) -- 1794
			do -- 1794
				local i = 0 -- 1795
				while i < count do -- 1795
					local button = buttons[i + 1] -- 1796
					local open = i <= maxUnlocked -- 1797
					button:setEnabled(open) -- 1798
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 1799
					if open then -- 1799
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 1800
					else -- 1800
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 1801
					end -- 1801
					i = i + 1 -- 1795
				end -- 1795
			end -- 1795
			root.visible = true -- 1803
			if replayButton ~= nil then -- 1803
				replayButton:setEnabled(true) -- 1804
			end -- 1804
		end, -- 1792
		hide = function() -- 1806
			root.visible = false -- 1807
			do -- 1807
				local i = 0 -- 1809
				while i < count do -- 1809
					buttons[i + 1]:setEnabled(false) -- 1809
					i = i + 1 -- 1809
				end -- 1809
			end -- 1809
			if replayButton ~= nil then -- 1809
				replayButton:setEnabled(false) -- 1810
			end -- 1810
		end -- 1806
	} -- 1806
end -- 1705
return ____exports -- 1705