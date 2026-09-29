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
function ____exports.createAimInput(parent, viewW, viewH, maxSpeed, minSpeed, speedChoices, transferTutorial, transferMode) -- 341
	if transferTutorial == nil then -- 341
		transferTutorial = false -- 351
	end -- 351
	if transferMode == nil then -- 351
		transferMode = "lunar" -- 352
	end -- 352
	local datePlate, dateLabel -- 352
	local speedMin = minSpeed ~= nil and minSpeed >= 0 and minSpeed < (maxSpeed ~= nil and maxSpeed or AimMaxSpeed) and minSpeed or AimMinSpeed -- 354
	local speedTop = maxSpeed ~= nil and maxSpeed > speedMin and maxSpeed or AimMaxSpeed -- 356
	local root = Node() -- 357
	root.size = Size(viewW, viewH) -- 358
	root.anchor = Vec2(0, 0) -- 364
	root.position = Vec2(0, 0) -- 365
	local touchLayer = Node() -- 368
	touchLayer.size = Size(viewW, viewH) -- 369
	touchLayer.anchor = Vec2(0.5, 0.5) -- 370
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 371
	touchLayer.swallowTouches = true -- 372
	root:addChild(touchLayer) -- 373
	local space = {viewW = viewW, viewH = viewH} -- 375
	local enabled = false -- 377
	local dragging = false -- 378
	--- 整屏瞄准（2D 模式）；由 Game 按视图状态同步。
	local fullScreenAim = false -- 380
	local aim = {velocity = {x = 0, y = -speedMin}, power = 0, unit = {x = 0, y = -1}} -- 381
	local probeOffset = {x = 0, y = 0} -- 384
	local dragHandler = nil -- 386
	local readyHandler = nil -- 387
	local observeHandler = nil -- 388
	local zoomHandler = nil -- 389
	local launchHandler = nil -- 390
	local skipTourHandler = nil -- 391
	local tourActiveChecker = nil -- 392
	local pressOffset = {x = 0, y = 0} -- 403
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 406
		aim = ____exports.computeAim( -- 407
			{x = 0, y = 0}, -- 407
			delta, -- 407
			AimMaxDragPx, -- 407
			speedTop, -- 407
			speedMin -- 407
		) -- 407
		if dragHandler ~= nil then -- 407
			dragHandler(aim) -- 408
		end -- 408
	end -- 406
	local aimRadius = math.max(96, viewW * 0.25) -- 415
	local mode = "none" -- 416
	local observeLast = {x = 0, y = 0} -- 417
	touchLayer:onTapBegan(function(touch) -- 418
		if not enabled then -- 418
			return -- 419
		end -- 419
		if tourActiveChecker ~= nil and tourActiveChecker() and skipTourHandler ~= nil then -- 419
			skipTourHandler() -- 421
			return -- 422
		end -- 422
		local at = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 424
		local dx = at.x - probeOffset.x -- 425
		local dy = at.y - probeOffset.y -- 426
		if fullScreenAim or math.sqrt(dx * dx + dy * dy) <= aimRadius then -- 426
			mode = "aim" -- 428
			dragging = true -- 429
			pressOffset = at -- 430
			handleDelta({x = 0, y = 0}) -- 432
		else -- 432
			mode = "observe" -- 434
			observeLast = at -- 435
		end -- 435
	end) -- 418
	touchLayer:onTapMoved(function(touch) -- 439
		if not enabled then -- 439
			return -- 440
		end -- 440
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 441
		if mode == "aim" and dragging then -- 441
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 443
		elseif mode == "observe" then -- 443
			if observeHandler ~= nil then -- 443
				observeHandler(cur.x - observeLast.x, cur.y - observeLast.y) -- 446
			end -- 446
			observeLast = cur -- 447
		end -- 447
	end) -- 439
	touchLayer:onTapEnded(function(touch) -- 451
		if not enabled then -- 451
			return -- 452
		end -- 452
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 453
		if mode == "aim" then -- 453
			dragging = false -- 455
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 456
			if readyHandler ~= nil then -- 456
				readyHandler(aim) -- 458
			end -- 458
		end -- 458
		mode = "none" -- 460
	end) -- 451
	touchLayer:onGesture(function(_center, numFingers, deltaDist, _deltaAngle) -- 464
		if not enabled or numFingers < 2 then -- 464
			return -- 465
		end -- 465
		if zoomHandler ~= nil then -- 465
			zoomHandler(deltaDist) -- 466
		end -- 466
	end) -- 464
	touchLayer.touchEnabled = false -- 474
	createPanel( -- 480
		root, -- 480
		220, -- 480
		50, -- 480
		658964, -- 480
		{alpha = 0.45} -- 480
	) -- 480
	local orbitName = transferMode == "inward" and "近日点" or (transferMode == "outward" and "远日点" or "远地点高度") -- 481
	local dvLabel = createLabel(root, transferTutorial and "拖动调整" .. orbitName or "Δv — / —", transferTutorial and 22 or 30, ResultHintHex) -- 482
	if dvLabel ~= nil then -- 482
		dvLabel.position = Vec2(24, viewH - (transferTutorial and 130 or 44)) -- 484
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
	local QuickRetryW = 110 -- 580
	local QuickRetryH = 50 -- 581
	local quickRetryHandler = nil -- 582
	local quickRetryBtn = createButton( -- 583
		root, -- 583
		{ -- 583
			w = QuickRetryW, -- 584
			h = QuickRetryH, -- 585
			text = "↺ 重试", -- 586
			fontSize = 26, -- 587
			bgHex = 12730636, -- 588
			fgHex = 16777215, -- 589
			borderHex = 16498468, -- 590
			fireOn = "press", -- 591
			onTap = function() -- 592
				print("[escape-velocity] quick retry tapped") -- 593
				if quickRetryHandler ~= nil then -- 593
					quickRetryHandler() -- 594
				end -- 594
			end -- 592
		} -- 592
	) -- 592
	quickRetryBtn.root.position = Vec2(viewW - QuickRetryW - 20, viewH - QuickRetryH - 20) -- 597
	local starPlateW = 180 -- 600
	local starPlateH = 46 -- 601
	local starPlate = createPanel( -- 602
		root, -- 602
		starPlateW, -- 602
		starPlateH, -- 602
		658964, -- 602
		{alpha = 0.55} -- 602
	) -- 602
	starPlate.position = Vec2(viewW / 2 - starPlateW / 2, viewH - starPlateH - 22) -- 603
	starPlate.visible = not transferTutorial -- 604
	local starStatusLabel = createLabel(root, "☆ ☆ ☆", 30, 16766720) -- 605
	local bonusToastLabel = createLabel(root, "", 34, 9240475) -- 606
	if bonusToastLabel ~= nil then -- 606
		bonusToastLabel.position = Vec2(viewW / 2, viewH * 0.68) -- 607
		bonusToastLabel.visible = false -- 607
	end -- 607
	if starStatusLabel ~= nil then -- 607
		starStatusLabel.anchor = Vec2(0.5, 0.5) -- 609
		starStatusLabel.position = Vec2(viewW / 2, viewH - starPlateH / 2 - 22) -- 610
	end -- 610
	local function updateStarsStatus(count) -- 612
		if starStatusLabel == nil then -- 612
			return -- 613
		end -- 613
		if transferTutorial then -- 613
			starStatusLabel.visible = false -- 614
			return -- 614
		end -- 614
		local s = "☆ ☆ ☆" -- 615
		if count == 1 then -- 615
			s = "★ ☆ ☆" -- 616
		elseif count == 2 then -- 616
			s = "★ ★ ☆" -- 617
		elseif count >= 3 then -- 617
			s = "★ ★ ★" -- 618
		end -- 618
		setLabelText(starStatusLabel, s) -- 619
	end -- 612
	local function updateBonusStatus(got, total) -- 621
		if starStatusLabel == nil then -- 621
			return -- 622
		end -- 622
		starPlate.visible = total > 0 -- 623
		starStatusLabel.visible = total > 0 -- 624
		if total > 0 then -- 624
			setLabelText( -- 625
				starStatusLabel, -- 625
				(("🚀 " .. __TS__NumberToFixed(got, 0)) .. " / ") .. __TS__NumberToFixed(total, 0) -- 625
			) -- 625
		end -- 625
	end -- 621
	local LaunchButtonW = 220 -- 630
	local LaunchButtonH = 112 -- 631
	local launchButton = createButton( -- 632
		root, -- 632
		{ -- 632
			w = LaunchButtonW, -- 633
			h = LaunchButtonH, -- 634
			text = "▲ 发射 ▲", -- 635
			fontSize = 38, -- 636
			bgHex = ResultButtonBgHex, -- 637
			fgHex = ResultButtonFgHex, -- 638
			borderHex = ResultButtonBorderHex, -- 639
			fireOn = "press", -- 640
			onTap = function() -- 641
				print("[escape-velocity] launch button fire (press)") -- 642
				if launchHandler ~= nil then -- 642
					launchHandler() -- 643
				end -- 643
			end -- 641
		} -- 641
	) -- 641
	launchButton.root.position = Vec2(viewW - LaunchButtonW - 24, 96) -- 646
	launchButton.root.visible = false -- 647
	launchButton:setEnabled(false) -- 648
	local CancelButtonW = 160 -- 651
	local CancelButtonH = 72 -- 652
	local cancelAimHandler = nil -- 653
	local cancelAimButton = createButton( -- 654
		root, -- 654
		{ -- 654
			w = CancelButtonW, -- 655
			h = CancelButtonH, -- 656
			text = "✕ 取消", -- 657
			fontSize = 28, -- 658
			bgHex = ResultButtonAltBgHex, -- 659
			fgHex = ResultButtonFgHex, -- 660
			borderHex = ResultButtonBorderHex, -- 661
			fireOn = "press", -- 662
			onTap = function() -- 663
				print("[escape-velocity] cancel aim fire (press)") -- 664
				if cancelAimHandler ~= nil then -- 664
					cancelAimHandler() -- 665
				end -- 665
			end -- 663
		} -- 663
	) -- 663
	cancelAimButton.root.position = Vec2(viewW - LaunchButtonW - CancelButtonW - 40, 116) -- 668
	cancelAimButton.root.visible = false -- 669
	cancelAimButton:setEnabled(false) -- 670
	local ViewButtonW = 116 -- 674
	local ViewButtonH = 64 -- 675
	local viewHandler = nil -- 676
	local viewButton = createButton( -- 677
		root, -- 677
		{ -- 677
			w = ViewButtonW, -- 678
			h = ViewButtonH, -- 679
			text = "[ 3D ]", -- 680
			fontSize = 26, -- 681
			bgHex = ResultButtonAltBgHex, -- 682
			fgHex = ResultButtonFgHex, -- 683
			borderHex = ResultButtonBorderHex, -- 684
			fireOn = "press", -- 685
			onTap = function() -- 686
				print("[escape-velocity] view toggle fire (press)") -- 687
				if viewHandler ~= nil then -- 687
					viewHandler() -- 688
				end -- 688
			end -- 686
		} -- 686
	) -- 686
	viewButton.root.position = Vec2(viewW - ViewButtonW - 24, 96 + LaunchButtonH + 12) -- 691
	--- 上次写进按钮的文字（每帧都会被 setViewMode 调用，没变就别碰 Label）。
	local lastViewText = "2D" -- 693
	local cameraFocusHandler = nil -- 696
	local endViewingHandler = nil -- 697
	local cameraFocusButton = transferTutorial and createButton( -- 698
		root, -- 698
		{ -- 698
			w = 260, -- 699
			h = 58, -- 699
			text = "镜头 · 自动", -- 699
			fontSize = 22, -- 699
			bgHex = ResultButtonAltBgHex, -- 700
			fgHex = ResultButtonFgHex, -- 700
			borderHex = ResultButtonBorderHex, -- 700
			fireOn = "press", -- 700
			onTap = function() -- 701
				if cameraFocusHandler ~= nil then -- 701
					cameraFocusHandler() -- 701
				end -- 701
			end -- 701
		} -- 701
	) or nil -- 701
	local endViewingButton = transferTutorial and createButton( -- 703
		root, -- 703
		{ -- 703
			w = 220, -- 704
			h = LaunchButtonH, -- 704
			text = "结束观赏", -- 704
			fontSize = 26, -- 704
			bgHex = ResultButtonAltBgHex, -- 705
			fgHex = ResultButtonFgHex, -- 705
			borderHex = ResultButtonBorderHex, -- 705
			fireOn = "press", -- 705
			onTap = function() -- 706
				if endViewingHandler ~= nil then -- 706
					endViewingHandler() -- 706
				end -- 706
			end -- 706
		} -- 706
	) or nil -- 706
	if cameraFocusButton ~= nil then -- 706
		cameraFocusButton.root.position = Vec2(24, 266) -- 708
		cameraFocusButton.root.visible = false -- 708
		cameraFocusButton:setEnabled(false) -- 708
	end -- 708
	if endViewingButton ~= nil then -- 708
		endViewingButton.root.position = Vec2(viewW - 244, 96) -- 709
		endViewingButton.root.visible = false -- 709
		endViewingButton:setEnabled(false) -- 709
	end -- 709
	local ____transferTutorial_0 -- 710
	if transferTutorial then -- 710
		____transferTutorial_0 = createLabel(root, "", 24, ResultHintHex) -- 710
	else -- 710
		____transferTutorial_0 = nil -- 710
	end -- 710
	local viewingLabel = ____transferTutorial_0 -- 710
	if viewingLabel ~= nil then -- 710
		viewingLabel.position = Vec2(24, viewH - 130) -- 711
		viewingLabel.anchor = Vec2(0, 0) -- 711
		viewingLabel.visible = false -- 711
	end -- 711
	local viewingKey = "" -- 712
	local ZoomBtnSize = 58 -- 715
	local zoomGap = 8 -- 716
	local zoomButtons = {} -- 717
	local zoomInHandler = nil -- 718
	local zoomOutHandler = nil -- 719
	local fitViewHandler = nil -- 720
	local function makeZoomButton(text, x, fontSize, onClick) -- 722
		local btn = createButton( -- 723
			root, -- 723
			{ -- 723
				w = ZoomBtnSize, -- 724
				h = ZoomBtnSize, -- 725
				text = text, -- 726
				fontSize = fontSize, -- 727
				bgHex = ResultButtonAltBgHex, -- 728
				fgHex = ResultButtonFgHex, -- 729
				borderHex = ResultButtonBorderHex, -- 730
				fireOn = "press", -- 731
				onTap = function() -- 732
					print(("[escape-velocity] zoom btn " .. text) .. " fire") -- 733
					onClick() -- 734
				end -- 732
			} -- 732
		) -- 732
		btn.root.position = Vec2(x, 96) -- 737
		btn.root.visible = false -- 738
		btn:setEnabled(false) -- 739
		zoomButtons[#zoomButtons + 1] = btn -- 740
		return btn -- 741
	end -- 722
	makeZoomButton( -- 743
		"−", -- 743
		24, -- 743
		32, -- 743
		function() -- 743
			if zoomOutHandler ~= nil then -- 743
				zoomOutHandler() -- 744
			end -- 744
		end -- 743
	) -- 743
	makeZoomButton( -- 746
		"FIT", -- 746
		24 + ZoomBtnSize + zoomGap, -- 746
		20, -- 746
		function() -- 746
			if fitViewHandler ~= nil then -- 746
				fitViewHandler() -- 747
			end -- 747
		end -- 746
	) -- 746
	makeZoomButton( -- 749
		"+", -- 749
		24 + (ZoomBtnSize + zoomGap) * 2, -- 749
		32, -- 749
		function() -- 749
			if zoomInHandler ~= nil then -- 749
				zoomInHandler() -- 750
			end -- 750
		end -- 749
	) -- 749
	local zoomControlsVisible = nil -- 752
	local function setZoomVisible(on) -- 753
		if zoomControlsVisible == on then -- 753
			return -- 754
		end -- 754
		zoomControlsVisible = on -- 755
		for ____, b in ipairs(zoomButtons) do -- 756
			b.root.visible = on -- 757
			b:setEnabled(on) -- 758
		end -- 758
	end -- 753
	setZoomVisible(false) -- 761
	local TimeBtnW = 78 -- 767
	local TimeBtnH = 64 -- 768
	local TimeRowY = 170 -- 769
	local speedUpHandler = nil -- 770
	local speedDownHandler = nil -- 771
	local pauseHandler = nil -- 772
	local slowButton = createButton( -- 774
		root, -- 774
		{ -- 774
			w = TimeBtnW, -- 775
			h = TimeBtnH, -- 775
			text = "◀ 慢", -- 775
			fontSize = 26, -- 775
			bgHex = ResultButtonAltBgHex, -- 776
			fgHex = ResultButtonFgHex, -- 776
			borderHex = ResultButtonBorderHex, -- 776
			onTap = function() -- 777
				print("[escape-velocity] speed down fire") -- 778
				if speedDownHandler ~= nil then -- 778
					speedDownHandler() -- 779
				end -- 779
			end -- 777
		} -- 777
	) -- 777
	slowButton.root.position = Vec2(24, TimeRowY) -- 782
	local pauseButton = createButton( -- 783
		root, -- 783
		{ -- 783
			w = TimeBtnW, -- 784
			h = TimeBtnH, -- 784
			text = "⏸", -- 784
			fontSize = 30, -- 784
			bgHex = ResultButtonAltBgHex, -- 785
			fgHex = ResultButtonFgHex, -- 785
			borderHex = ResultButtonBorderHex, -- 785
			onTap = function() -- 786
				print("[escape-velocity] pause toggle fire") -- 787
				if pauseHandler ~= nil then -- 787
					pauseHandler() -- 788
				end -- 788
			end -- 786
		} -- 786
	) -- 786
	pauseButton.root.position = Vec2(24 + TimeBtnW + 8, TimeRowY) -- 791
	local fastButton = createButton( -- 792
		root, -- 792
		{ -- 792
			w = TimeBtnW, -- 793
			h = TimeBtnH, -- 793
			text = "快 ▶", -- 793
			fontSize = 26, -- 793
			bgHex = ResultButtonAltBgHex, -- 794
			fgHex = ResultButtonFgHex, -- 794
			borderHex = ResultButtonBorderHex, -- 794
			onTap = function() -- 795
				print("[escape-velocity] speed up fire") -- 796
				if speedUpHandler ~= nil then -- 796
					speedUpHandler() -- 797
				end -- 797
			end -- 795
		} -- 795
	) -- 795
	fastButton.root.position = Vec2(24 + (TimeBtnW + 8) * 2, TimeRowY) -- 800
	local timePlate = createPanel( -- 803
		root, -- 803
		300, -- 803
		50, -- 803
		658964, -- 803
		{alpha = 0.45} -- 803
	) -- 803
	timePlate.position = transferTutorial and Vec2(24, viewH - 190) or Vec2(24 + (TimeBtnW + 8) * 3 + 4, TimeRowY + 7) -- 804
	local timeLabel = createLabel(root, "1×（现实）  T+ 0:00", transferTutorial and 22 or 26, ResultHintHex) -- 805
	if timeLabel ~= nil then -- 805
		timeLabel.anchor = Vec2(0, 0) -- 807
		timeLabel.position = transferTutorial and Vec2(36, viewH - 179) or Vec2(24 + (TimeBtnW + 8) * 3 + 16, TimeRowY + 18) -- 808
	end -- 808
	--- 档位文字：pow 0 就是"1×（现实）"，别写成 1e0×。
	local function powText(pow) -- 811
		return pow <= 0 and "1×（现实）" or ("1e" .. __TS__NumberToFixed(pow, 0)) .. "×" -- 811
	end -- 811
	--- 任务时钟：真实秒 → "T+ 3天 04:12"。1× 下它每秒跳一格 —— 时间在流逝的唯一可见证据。
	local function missionText(sec) -- 813
		local s = sec > 0 and sec or 0 -- 814
		local days = math.floor(s / 86400) -- 815
		local rest = s - days * 86400 -- 816
		local hh = math.floor(rest / 3600) -- 817
		local mm = math.floor((rest - hh * 3600) / 60) -- 818
		local function pad(v) -- 819
			return (v < 10 and "0" or "") .. __TS__NumberToFixed(v, 0) -- 819
		end -- 819
		return ((("T+ " .. (days > 0 and __TS__NumberToFixed(days, 0) .. "天 " or "")) .. pad(hh)) .. ":") .. pad(mm) -- 820
	end -- 813
	local lastTimeText = "" -- 822
	local lastPaused = false -- 823
	local function setTimeControl(pow, maxPow, paused, missionSeconds, actualRate) -- 824
		local txt = (((transferTutorial and actualRate ~= nil and __TS__NumberToFixed(actualRate, 2) .. "×" or powText(pow)) .. (paused and " ⏸ 暂停" or "")) .. "  ") .. (transferTutorial and ("T+ " .. __TS__NumberToFixed(missionSeconds, 1)) .. "s" or missionText(missionSeconds)) -- 825
		if txt ~= lastTimeText then -- 825
			lastTimeText = txt -- 827
			if timeLabel ~= nil then -- 827
				timeLabel.text = txt -- 828
			end -- 828
		end -- 828
		if paused ~= lastPaused then -- 828
			lastPaused = paused -- 831
			pauseButton:setText(paused and "▶" or "⏸") -- 832
			pauseButton:setColors(paused and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 833
		end -- 833
		fastButton:setEnabled(pow < maxPow) -- 836
		slowButton:setEnabled(pow > 0) -- 837
	end -- 824
	local DrawerW = 380 -- 841
	local DrawerH = 46 -- 842
	local missionDrawerPlate = createPanel( -- 843
		root, -- 843
		DrawerW, -- 843
		DrawerH, -- 843
		658964, -- 843
		{alpha = 0.65, borderHex = 4610157} -- 843
	) -- 843
	missionDrawerPlate.position = Vec2(transferTutorial and 24 or (viewW - DrawerW) / 2, viewH - 56) -- 844
	local missionTitleLabel = createLabel(missionDrawerPlate, "", 19, 13426158) -- 845
	if missionTitleLabel ~= nil then -- 845
		missionTitleLabel.anchor = Vec2(0, 0.5) -- 847
		missionTitleLabel.position = Vec2(14, DrawerH / 2) -- 848
	end -- 848
	local missionRocketsLabel = createLabel(missionDrawerPlate, "☆  ☆  ☆", 22, 16766720) -- 850
	if missionRocketsLabel ~= nil then -- 850
		missionRocketsLabel.anchor = Vec2(1, 0.5) -- 852
		missionRocketsLabel.position = Vec2(DrawerW - 14, DrawerH / 2) -- 853
	end -- 853
	missionDrawerPlate.visible = false -- 855
	local drawerVisible = false -- 856
	local bonusToastSerial = 0 -- 857
	local drawerLevelTitle = "" -- 858
	local drawerRockets = 0 -- 859
	local liveFuelBonus = false -- 860
	local function updateDrawerDisplay() -- 862
		if missionTitleLabel ~= nil then -- 862
			setLabelText(missionTitleLabel, drawerLevelTitle) -- 864
		end -- 864
		if missionRocketsLabel ~= nil then -- 864
			local r1 = drawerRockets >= 1 and "★" or "☆" -- 867
			local r2 = (drawerRockets >= 2 or liveFuelBonus) and "★" or "☆" -- 868
			local r3 = drawerRockets >= 3 and "★" or "☆" -- 869
			setLabelText(missionRocketsLabel, transferTutorial and (drawerRockets >= 1 and "已完成" or (transferMode == "lunar" and "地月转移练习" or "日心借力练习")) or (((r1 .. "  ") .. r2) .. "  ") .. r3) -- 870
		end -- 870
	end -- 862
	local IntroBannerW = math.min(viewW - 48, 540) -- 875
	local IntroBannerH = 68 -- 876
	local introBannerPlate = createPanel( -- 877
		root, -- 877
		IntroBannerW, -- 877
		IntroBannerH, -- 877
		658964, -- 877
		{alpha = 0.8, borderHex = 4610157} -- 877
	) -- 877
	introBannerPlate.position = Vec2((viewW - IntroBannerW) / 2, 70) -- 878
	local introBannerTitle = createLabel(introBannerPlate, "", 17, 15398143) -- 879
	if introBannerTitle ~= nil then -- 879
		introBannerTitle.anchor = Vec2(0.5, 0.5) -- 881
		introBannerTitle.position = Vec2(IntroBannerW / 2, IntroBannerH * 0.65) -- 882
	end -- 882
	local introBannerHint = createLabel(introBannerPlate, "轻触屏幕任意位置跳过运镜", 13, 9283005) -- 884
	if introBannerHint ~= nil then -- 884
		introBannerHint.anchor = Vec2(0.5, 0.5) -- 886
		introBannerHint.position = Vec2(IntroBannerW / 2, IntroBannerH * 0.28) -- 887
	end -- 887
	introBannerPlate.visible = false -- 889
	local PlaybackButtonW = 116 -- 898
	local PlaybackButtonH = 64 -- 899
	local playbackGap = 10 -- 900
	local playbackButtons = {} -- 901
	local playbackSpeeds = {} -- 902
	local playbackHandler = nil -- 903
	local speedChoice = speedChoices ~= nil and #speedChoices > 0 and speedChoices or ({1, 2, 4}) -- 906
	local playbackSpeed = speedChoice[1] -- 907
	--- 已应用到节点上的显隐状态。初值 false 如实反映"建出来就隐藏"（照 warp 按钮的教训）。
	local playbackVisible = false -- 909
	local function paintPlayback() -- 910
		do -- 910
			local i = 0 -- 911
			while i < #playbackButtons do -- 911
				local on = playbackSpeeds[i + 1] == playbackSpeed -- 912
				playbackButtons[i + 1]:setColors(on and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 913
				i = i + 1 -- 911
			end -- 911
		end -- 911
	end -- 910
	local function makePlaybackButton(speed, x) -- 916
		local btn = createButton( -- 917
			root, -- 917
			{ -- 917
				w = PlaybackButtonW, -- 918
				h = PlaybackButtonH, -- 919
				text = ____exports.playbackLabel(speed), -- 920
				fontSize = 30, -- 921
				bgHex = ResultButtonAltBgHex, -- 922
				fgHex = ResultButtonFgHex, -- 923
				borderHex = ResultButtonBorderHex, -- 924
				onTap = function() -- 925
					print(("[escape-velocity] playback button fire " .. __TS__NumberToFixed(speed, 0)) .. "x (release)") -- 927
					playbackSpeed = speed -- 928
					paintPlayback() -- 929
					if playbackHandler ~= nil then -- 929
						playbackHandler(speed) -- 930
					end -- 930
				end -- 925
			} -- 925
		) -- 925
		btn.root.position = Vec2(x, 96) -- 935
		playbackButtons[#playbackButtons + 1] = btn -- 936
		playbackSpeeds[#playbackSpeeds + 1] = speed -- 937
	end -- 916
	do -- 916
		local i = 0 -- 939
		while i < #speedChoice and i < 3 do -- 939
			makePlaybackButton(speedChoice[i + 1], 24 + (PlaybackButtonW + playbackGap) * i) -- 940
			i = i + 1 -- 939
		end -- 939
	end -- 939
	paintPlayback() -- 942
	for ____, b in ipairs(playbackButtons) do -- 944
		b.root.visible = false -- 945
		b:setEnabled(false) -- 946
	end -- 946
	parent:addChild(root) -- 949
	return { -- 951
		onDrag = function(____, callback) -- 952
			dragHandler = callback -- 953
		end, -- 952
		setEnabled = function(____, value) -- 955
			enabled = value -- 956
			touchLayer.touchEnabled = value -- 959
			if not value then -- 959
				dragging = false -- 961
			end -- 961
		end, -- 955
		onAimReady = function(____, callback) -- 964
			readyHandler = callback -- 965
		end, -- 964
		onObserve = function(____, callback) -- 967
			observeHandler = callback -- 968
		end, -- 967
		onZoom = function(____, callback) -- 970
			zoomHandler = callback -- 971
		end, -- 970
		onLaunch = function(____, callback) -- 973
			launchHandler = callback -- 974
		end, -- 973
		onCancelAim = function(____, callback) -- 976
			cancelAimHandler = callback -- 977
		end, -- 976
		setArmed = function(____, armed) -- 979
			launchButton.root.visible = armed -- 980
			launchButton:setEnabled(armed) -- 981
			cancelAimButton.root.visible = armed -- 982
			cancelAimButton:setEnabled(armed) -- 983
		end, -- 979
		onViewToggle = function(____, callback) -- 985
			viewHandler = callback -- 986
		end, -- 985
		onCameraFocus = function(____, callback) -- 988
			cameraFocusHandler = callback -- 988
		end, -- 988
		onEndViewing = function(____, callback) -- 989
			endViewingHandler = callback -- 989
		end, -- 989
		setFlightViewing = function(____, flying, completed, mode, is3D, stage) -- 990
			if not transferTutorial then -- 990
				return -- 991
			end -- 991
			local key = ((((flying and "1" or "0") .. (completed and "1" or "0")) .. mode) .. (is3D and "1" or "0")) .. (stage ~= nil and stage or "") -- 992
			if viewingKey == key then -- 992
				return -- 993
			end -- 993
			viewingKey = key -- 994
			if dvLabel ~= nil then -- 994
				dvLabel.visible = not flying -- 995
			end -- 995
			if viewingLabel ~= nil then -- 995
				viewingLabel.visible = flying -- 997
				local near = stage == "Mercury" and "安全飞掠水星" or (stage == "Venus" and "金星减速借力" or (stage == "Jupiter" and "木星加速借力" or (stage == "Saturn" and "土星加速借力" or (stage == "Moon" and "借月球引力 · 观察轨迹转弯" or "滑行 · 观察航线")))) -- 998
				setLabelText(viewingLabel, completed and (transferMode == "lunar" and "掠月完成 · 继续观察返回" or "目标完成 · 继续观察航线") or (stage == "Launch" and (transferMode == "inward" and "逆行点火 · 降低近日点" or "顺行点火 · 抬高" .. orbitName) or near)) -- 999
				setLabelColor(viewingLabel, completed and 9430458 or ResultHintHex) -- 1000
			end -- 1000
			if cameraFocusButton ~= nil then -- 1000
				cameraFocusButton.root.visible = flying and is3D -- 1003
				cameraFocusButton:setEnabled(flying and is3D) -- 1004
				local title = mode == "Mercury" and "水星" or (mode == "Auto" and "自动" or (mode == "Probe" and "探测器" or (mode == "Moon" and "月球" or (mode == "Earth" and "地球" or (mode == "Venus" and "金星" or (mode == "Jupiter" and "木星" or (mode == "Saturn" and "土星" or (mode == "Sun" and "太阳" or "总览")))))))) -- 1005
				cameraFocusButton:setText("镜头 · " .. title) -- 1006
			end -- 1006
			if endViewingButton ~= nil then -- 1006
				endViewingButton.root.visible = flying and completed -- 1008
				endViewingButton:setEnabled(flying and completed) -- 1008
			end -- 1008
		end, -- 990
		setViewMode = function(____, mode) -- 1010
			if mode == lastViewText then -- 1010
				return -- 1011
			end -- 1011
			lastViewText = mode -- 1012
			local btnText = mode == "2D" and "[ 3D ]" or "[ 2D ]" -- 1014
			viewButton:setText(btnText) -- 1015
		end, -- 1010
		onPlayback = function(____, callback) -- 1017
			playbackHandler = callback -- 1018
		end, -- 1017
		setPlayback = function(____, speed) -- 1020
			if speed == playbackSpeed then -- 1020
				return -- 1021
			end -- 1021
			playbackSpeed = speed -- 1022
			paintPlayback() -- 1023
		end, -- 1020
		setPlaybackVisible = function(____, on) -- 1025
			if on == playbackVisible then -- 1025
				return -- 1026
			end -- 1026
			playbackVisible = on -- 1027
			for ____, b in ipairs(playbackButtons) do -- 1028
				b.root.visible = on -- 1029
				b:setEnabled(on) -- 1030
			end -- 1030
		end, -- 1025
		setFullScreenAim = function(____, on) -- 1033
			fullScreenAim = on -- 1034
		end, -- 1033
		onWarp = function(____, callback) -- 1036
			warpHandler = callback -- 1037
		end, -- 1036
		setDate = function(____, t0, span) -- 1039
			dateSpan = span > 0 and span or 0 -- 1040
			applyWarpState() -- 1041
			local on = dateSpan > 0 -- 1042
			local text = on and (("发射日期 " .. __TS__NumberToFixed(t0, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0) or "发射日期" -- 1043
			if text ~= lastDateText then -- 1043
				lastDateText = text -- 1045
				setLabelText(dateLabel, text) -- 1046
			end -- 1046
		end, -- 1039
		setTimeEnabled = function(____, on) -- 1049
			if warpAllowed == on then -- 1049
				return -- 1050
			end -- 1050
			warpAllowed = on -- 1051
			applyWarpState() -- 1052
		end, -- 1049
		update = function(____, dt) -- 1054
			if not warpOn or warpHoldDir == 0 then -- 1054
				return -- 1055
			end -- 1055
			warpRepeatIn = warpRepeatIn - dt -- 1056
			if warpRepeatIn > 0 then -- 1056
				return -- 1057
			end -- 1057
			warpRepeatIn = TimeWarpStep / TimeWarpRate -- 1059
			if warpHandler ~= nil then -- 1059
				warpHandler(warpHoldDir) -- 1060
			end -- 1060
		end, -- 1054
		isDragging = function() return dragging end, -- 1062
		setBurnInfo = function(____, burn, budget) -- 1063
			if transferTutorial then -- 1063
				return -- 1064
			end -- 1064
			local b = budget < 1 and __TS__NumberToFixed(budget, 2) or __TS__NumberToFixed(budget, 0) -- 1068
			local v = burn < 1 and __TS__NumberToFixed(burn, 2) or __TS__NumberToFixed(burn, 1) -- 1069
			setLabelText(dvLabel, (("Δv " .. v) .. " / ") .. b) -- 1070
		end, -- 1063
		current = function() return aim end, -- 1072
		setTransferInfo = function(____, apoapsis, duration, reachable) -- 1073
			setLabelText( -- 1074
				dvLabel, -- 1074
				(((((orbitName .. " ") .. __TS__NumberToFixed(apoapsis, 0)) .. " · 点火 ") .. __TS__NumberToFixed(duration, 2)) .. "s") .. (reachable ~= nil and (reachable and (transferMode == "lunar" and " · 可减速掠月" or " · 航线可行") or " · 等待窗口") or "") -- 1074
			) -- 1074
		end, -- 1073
		setProbeOffset = function(____, offset) -- 1076
			probeOffset = offset -- 1077
		end, -- 1076
		handleLocal = function(____, ____local) -- 1081
			handleDelta(____exports.localToOffset(____local, space)) -- 1082
		end, -- 1081
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 1085
		debugProbeOffset = function() return probeOffset end, -- 1086
		onSpeedUp = function(____, callback) -- 1087
			speedUpHandler = callback -- 1088
		end, -- 1087
		onSpeedDown = function(____, callback) -- 1090
			speedDownHandler = callback -- 1091
		end, -- 1090
		onTogglePause = function(____, callback) -- 1093
			pauseHandler = callback -- 1094
		end, -- 1093
		setTimeControl = function(____, pow, maxPow, paused, missionSeconds, actualRate) -- 1096
			setTimeControl( -- 1097
				pow, -- 1097
				maxPow, -- 1097
				paused, -- 1097
				missionSeconds, -- 1097
				actualRate -- 1097
			) -- 1097
		end, -- 1096
		onZoomIn = function(____, callback) -- 1099
			zoomInHandler = callback -- 1100
		end, -- 1099
		onZoomOut = function(____, callback) -- 1102
			zoomOutHandler = callback -- 1103
		end, -- 1102
		onFitView = function(____, callback) -- 1105
			fitViewHandler = callback -- 1106
		end, -- 1105
		setZoomControlsVisible = function(____, on) -- 1108
			setZoomVisible(on) -- 1109
		end, -- 1108
		setMissionDrawer = function(____, levelName, _challenges, currentRockets) -- 1111
			drawerLevelTitle = levelName -- 1112
			drawerRockets = currentRockets -- 1113
			updateDrawerDisplay() -- 1114
		end, -- 1111
		setMissionDrawerVisible = function(____, visible) -- 1116
			if drawerVisible == visible then -- 1116
				return -- 1117
			end -- 1117
			drawerVisible = visible -- 1118
			missionDrawerPlate.visible = visible -- 1119
		end, -- 1116
		setLiveFuelChallengeStatus = function(____, achieved) -- 1121
			if liveFuelBonus == achieved then -- 1121
				return -- 1122
			end -- 1122
			liveFuelBonus = achieved -- 1123
			updateDrawerDisplay() -- 1124
		end, -- 1121
		setIntroTourBanner = function(____, title, hint) -- 1126
			if introBannerTitle ~= nil then -- 1126
				setLabelText(introBannerTitle, title) -- 1127
			end -- 1127
			if introBannerHint ~= nil and hint ~= nil then -- 1127
				setLabelText(introBannerHint, hint) -- 1128
			end -- 1128
		end, -- 1126
		setIntroTourBannerVisible = function(____, visible) -- 1130
			introBannerPlate.visible = visible -- 1131
		end, -- 1130
		onSkipTour = function(____, callback) -- 1133
			skipTourHandler = callback -- 1134
		end, -- 1133
		setTourActiveChecker = function(____, fn) -- 1136
			tourActiveChecker = fn -- 1137
		end, -- 1136
		onQuickRetry = function(____, callback) -- 1139
			quickRetryHandler = callback -- 1140
		end, -- 1139
		setStarsStatus = function(____, starsGot) -- 1142
			updateStarsStatus(starsGot) -- 1143
		end, -- 1142
		setBonusStatus = function(____, got, total) -- 1145
			updateBonusStatus(got, total) -- 1145
		end, -- 1145
		setBonusFeedback = function(____, score) -- 1146
			if bonusToastLabel == nil then -- 1146
				return -- 1147
			end -- 1147
			bonusToastSerial = bonusToastSerial + 1 -- 1148
			local serial = bonusToastSerial -- 1149
			setLabelText( -- 1150
				bonusToastLabel, -- 1150
				"🚀 +" .. __TS__NumberToFixed(score, 0) -- 1150
			) -- 1150
			bonusToastLabel.visible = true -- 1151
			local elapsed = 0 -- 1152
			root:schedule(function(deltaTime) -- 1153
				elapsed = elapsed + deltaTime -- 1154
				if elapsed >= 0.6 then -- 1154
					if serial == bonusToastSerial then -- 1154
						bonusToastLabel.visible = false -- 1155
					end -- 1155
					return true -- 1155
				end -- 1155
				return false -- 1156
			end) -- 1153
		end, -- 1146
		root = root -- 1159
	} -- 1159
end -- 341
local ResultBackdropHex = 329484 -- 1176
local ResultCardHex = 1252395 -- 1177
local ResultCardBorderHex = 3362938 -- 1178
local ResultLevelHex = 9417948 -- 1179
local ResultBodyHex = 14149367 -- 1180
ResultHintHex = 8229803 -- 1181
ResultButtonBgHex = 1919610 -- 1182
ResultButtonAltBgHex = 1779509 -- 1183
ResultButtonFgHex = 15398143 -- 1184
ResultButtonBorderHex = 5211846 -- 1185
local TitleSuccessHex = 8381344 -- 1186
local TitleMissedHex = 16766073 -- 1187
local TitleCrashedHex = 16743019 -- 1188
local SelectBackdropHex = 329484 -- 1190
local SelectTitleHex = 16777215 -- 1191
local SelectSubtitleHex = 10470632 -- 1192
local SelectHintHex = 7309478 -- 1193
local SelectOpenBgHex = 1919610 -- 1194
local SelectOpenFgHex = 15398143 -- 1195
local SelectLockedBgHex = 1383204 -- 1196
local SelectLockedFgHex = 6912140 -- 1197
local SelectBorderHex = 4157096 -- 1198
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 1201
	if value < lo then -- 1201
		return lo -- 1202
	end -- 1202
	if value > hi then -- 1202
		return hi -- 1203
	end -- 1203
	return value -- 1204
end -- 1201
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 1208
	if result == "success" then -- 1208
		return "借力成功" -- 1209
	end -- 1209
	if result == "crashed" then -- 1209
		return "信号中断" -- 1210
	end -- 1210
	return "错过目标" -- 1211
end -- 1208
--- 三态说明句（逐字）。
local function resultBody(result) -- 1215
	if result == "success" then -- 1215
		return "行星把探测器甩了出去，速度够了。" -- 1216
	end -- 1216
	if result == "crashed" then -- 1216
		return "探测器撞上行星，任务到此为止。" -- 1217
	end -- 1217
	return "从行星身侧掠过，没能借到那一点速度。" -- 1218
end -- 1215
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 1222
	if result == "success" then -- 1222
		return TitleSuccessHex -- 1223
	end -- 1223
	if result == "crashed" then -- 1223
		return TitleCrashedHex -- 1224
	end -- 1224
	return TitleMissedHex -- 1225
end -- 1222
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 1234
	if result == "success" then -- 1234
		return "下一关已解锁" -- 1235
	end -- 1235
	return "可重试本关，或返回关卡选择" -- 1236
end -- 1234
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 1282
	local root = createPanel( -- 1288
		parent, -- 1288
		viewW, -- 1288
		viewH, -- 1288
		ResultBackdropHex, -- 1288
		{alpha = 0.78} -- 1288
	) -- 1288
	local cardW = clampNumber(viewW * 0.9, 360, 560) -- 1290
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 480) -- 1291
	local btnH = clampNumber(viewH * 0.08, 48, 60) -- 1292
	local padX = (cardW - btnW) / 2 -- 1293
	local padY = 28 -- 1294
	local fontLevel = 24 -- 1296
	local fontRockets = 38 -- 1297
	local fontTitle = 30 -- 1298
	local fontTelemetry = 19 -- 1299
	local fontChallenge = 18 -- 1300
	local fontTotal = 20 -- 1301
	local btnFont = 24 -- 1302
	local rowGap = 12 -- 1303
	local hLevel = 28 -- 1305
	local hRockets = 42 -- 1306
	local hTitle = 34 -- 1307
	local hTelemetry = 24 -- 1308
	local hChallengeRow = 30 -- 1309
	local hChallenges = hChallengeRow * 3 -- 1310
	local hTotal = 24 -- 1311
	local cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7 -- 1313
	if cardH > viewH - 24 then -- 1313
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 1315
		cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7 -- 1316
	end -- 1316
	local card = createPanel( -- 1319
		root, -- 1319
		cardW, -- 1319
		cardH, -- 1319
		ResultCardHex, -- 1319
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 1319
	) -- 1319
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 1324
	local cursor = cardH - padY -- 1327
	cursor = cursor - hLevel -- 1329
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 1330
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 1331
	cursor = cursor - (rowGap + hRockets) -- 1333
	local rocketsLabel = createLabel(card, "", fontRockets, 16762939) -- 1334
	setLabelCenter(rocketsLabel, cardW / 2, cursor + hRockets / 2) -- 1335
	cursor = cursor - (rowGap + hTitle) -- 1337
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 1338
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 1339
	cursor = cursor - (rowGap + hTelemetry) -- 1341
	local telemetryLabel = createLabel(card, "", fontTelemetry, ResultHintHex) -- 1342
	setLabelCenter(telemetryLabel, cardW / 2, cursor + hTelemetry / 2) -- 1343
	cursor = cursor - rowGap -- 1345
	local challengeLabels = {} -- 1346
	do -- 1346
		local k = 0 -- 1347
		while k < 3 do -- 1347
			cursor = cursor - hChallengeRow -- 1348
			local cl = createLabel(card, "", fontChallenge, 10405355) -- 1349
			if cl ~= nil then -- 1349
				cl.textWidth = cardW - 60 -- 1351
				setLabelCenter(cl, cardW / 2, cursor + hChallengeRow / 2) -- 1352
				challengeLabels[#challengeLabels + 1] = cl -- 1353
			end -- 1353
			k = k + 1 -- 1347
		end -- 1347
	end -- 1347
	cursor = cursor - (rowGap + hTotal) -- 1357
	local totalLabel = createLabel(card, "", fontTotal, 16766073) -- 1358
	setLabelCenter(totalLabel, cardW / 2, cursor + hTotal / 2) -- 1359
	cursor = cursor - (rowGap + btnH) -- 1361
	local retryButton = createButton(card, { -- 1362
		w = btnW, -- 1363
		h = btnH, -- 1364
		text = "重试本关", -- 1365
		fontSize = btnFont, -- 1366
		bgHex = ResultButtonBgHex, -- 1367
		fgHex = ResultButtonFgHex, -- 1368
		borderHex = ResultButtonBorderHex, -- 1369
		fireOn = "press", -- 1370
		onTap = opts.onRetry -- 1371
	}) -- 1371
	retryButton.root.position = Vec2(padX, cursor) -- 1373
	cursor = cursor - (14 + btnH) -- 1375
	local backButton = createButton(card, { -- 1376
		w = btnW, -- 1377
		h = btnH, -- 1378
		text = "返回关卡选择", -- 1379
		fontSize = btnFont, -- 1380
		bgHex = ResultButtonAltBgHex, -- 1381
		fgHex = ResultButtonFgHex, -- 1382
		borderHex = ResultButtonBorderHex, -- 1383
		fireOn = "press", -- 1384
		onTap = opts.onBackToSelect -- 1385
	}) -- 1385
	backButton.root.position = Vec2(padX, cursor) -- 1387
	root.visible = false -- 1389
	retryButton:setEnabled(false) -- 1390
	backButton:setEnabled(false) -- 1391
	return { -- 1393
		root = root, -- 1394
		show = function(____, result, levelName, detail) -- 1395
			retryButton:setEnabled(true) -- 1396
			backButton:setEnabled(true) -- 1397
			setLabelText(levelLabel, levelName) -- 1398
			setLabelText( -- 1399
				titleLabel, -- 1399
				resultTitle(result) -- 1399
			) -- 1399
			setLabelColor( -- 1400
				titleLabel, -- 1400
				resultTitleColor(result) -- 1400
			) -- 1400
			if detail ~= nil then -- 1400
				if detail.completionOnly == true then -- 1400
					setLabelText( -- 1403
						titleLabel, -- 1403
						result == "success" and "引力借力完成" or resultTitle(result) -- 1403
					) -- 1403
				end -- 1403
				local rCount = detail.rocketsGot -- 1404
				local rStr = "☆  ☆  ☆" -- 1405
				if rCount == 1 then -- 1405
					rStr = "★  ☆  ☆" -- 1406
				elseif rCount == 2 then -- 1406
					rStr = "★  ★  ☆" -- 1407
				elseif rCount >= 3 then -- 1407
					rStr = "★  ★  ★" -- 1408
				end -- 1408
				setLabelText( -- 1409
					rocketsLabel, -- 1409
					detail.completionOnly == true and (result == "success" and "目标已完成" or "再试一次") or (detail.bonusPointCount ~= nil and (("火箭得分 " .. __TS__NumberToFixed(rCount, 0)) .. " / ") .. __TS__NumberToFixed(detail.bonusPointCount, 0) or rStr) -- 1409
				) -- 1409
				setLabelColor(rocketsLabel, rCount > 0 and 16762939 or 6322324) -- 1410
				local pct = detail.dvBudget > 0 and math.floor(detail.burnDv / detail.dvBudget * 100) or 0 -- 1412
				local telemText = ((((((("点火消耗 Δv: " .. __TS__NumberToFixed(detail.burnDv, 2)) .. " / ") .. __TS__NumberToFixed(detail.dvBudget, 2)) .. " (") .. __TS__NumberToFixed(pct, 0)) .. "%) · 用时: ") .. __TS__NumberToFixed(detail.flightTime, 1)) .. "s" -- 1413
				setLabelText(telemetryLabel, telemText) -- 1414
				do -- 1414
					local k = 0 -- 1416
					while k < 3 do -- 1416
						if challengeLabels[k + 1] ~= nil then -- 1416
							if k < #detail.challenges then -- 1416
								local ok = detail.achieved[k + 1] -- 1419
								local icon = ok and "★" or "☆" -- 1420
								local rank = k == 0 and "一星" or (k == 1 and "二星" or "三星") -- 1421
								local text = detail.completionOnly == true and (ok and "目标完成 · 记录已保存" or "尚未完成目标") or (((icon .. " [") .. rank) .. "] ") .. detail.challenges[k + 1] -- 1422
								setLabelText(challengeLabels[k + 1], text) -- 1423
								setLabelColor(challengeLabels[k + 1], ok and 16762939 or 6322324) -- 1424
								challengeLabels[k + 1].visible = true -- 1425
							else -- 1425
								challengeLabels[k + 1].visible = false -- 1427
							end -- 1427
						end -- 1427
						k = k + 1 -- 1416
					end -- 1416
				end -- 1416
				setLabelText( -- 1432
					totalLabel, -- 1432
					((("全深空火箭勋章: " .. __TS__NumberToFixed(detail.totalRockets, 0)) .. " / ") .. __TS__NumberToFixed(detail.totalPossibleRockets, 0)) .. " ★" -- 1432
				) -- 1432
				if totalLabel ~= nil then -- 1432
					totalLabel.visible = detail.completionOnly ~= true -- 1433
				end -- 1433
			else -- 1433
				setLabelText(rocketsLabel, result == "success" and "★  ☆  ☆" or "☆  ☆  ☆") -- 1435
				setLabelColor(rocketsLabel, result == "success" and 16762939 or 6322324) -- 1436
				setLabelText( -- 1437
					telemetryLabel, -- 1437
					resultBody(result) -- 1437
				) -- 1437
				do -- 1437
					local k = 0 -- 1438
					while k < #challengeLabels do -- 1438
						challengeLabels[k + 1].visible = false -- 1438
						k = k + 1 -- 1438
					end -- 1438
				end -- 1438
				if totalLabel ~= nil then -- 1438
					totalLabel.visible = false -- 1439
				end -- 1439
			end -- 1439
			root.visible = true -- 1441
		end, -- 1395
		hide = function() -- 1443
			root.visible = false -- 1444
			retryButton:setEnabled(false) -- 1445
			backButton:setEnabled(false) -- 1446
		end -- 1443
	} -- 1443
end -- 1282
local FinaleBackdropHex = 329484 -- 1461
local FinaleMainHex = 15398143 -- 1462
local FinaleSubHex = 10470632 -- 1463
--- 终章主文案（逐字；改之前先改 PLAN S3.18 与 docs/开发手册.md）。
____exports.FinaleMainText = "这就是我们整颗星球的样子 —— 而你已经从那里飞到了这里。" -- 1468
--- 终章小字：飞行距离 / 用时（纯函数，可单测）。
-- 
-- 距离是**平面单位**（关卡尺度，不是公里）—— 别在这里换算成天文单位，
-- 那一换就得把整条注释重写一遍，而玩家要的只是「飞了多远、花了多久」。
function ____exports.finaleSubtitle(distance, time) -- 1476
	return ((("飞行 " .. __TS__NumberToFixed(distance, 0)) .. " 单位 · 用时 ") .. __TS__NumberToFixed(time, 1)) .. " 秒" -- 1477
end -- 1476
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
function ____exports.createFinalePanel(parent, viewW, viewH, opts) -- 1507
	local root = createPanel( -- 1513
		parent, -- 1513
		viewW, -- 1513
		viewH, -- 1513
		FinaleBackdropHex, -- 1513
		{alpha = 0.55} -- 1513
	) -- 1513
	local fontMain = 34 -- 1515
	local fontSub = 30 -- 1516
	local btnFont = 40 -- 1517
	local mainLabel = createLabel(root, ____exports.FinaleMainText, fontMain, FinaleMainHex) -- 1519
	if mainLabel ~= nil then -- 1519
		mainLabel.textWidth = viewW * 0.88 -- 1522
		setLabelCenter(mainLabel, viewW / 2, viewH * 0.8) -- 1523
	end -- 1523
	local subLabel = createLabel(root, "", fontSub, FinaleSubHex) -- 1526
	if subLabel ~= nil then -- 1526
		setLabelCenter(subLabel, viewW / 2, viewH * 0.71) -- 1527
	end -- 1527
	local btnW = clampNumber(viewW * 0.62, MinButtonWidth, 560) -- 1529
	local btnH = clampNumber(viewH * 0.085, MinButtonHeight, 120) -- 1530
	local backButton = createButton(root, { -- 1531
		w = btnW, -- 1532
		h = btnH, -- 1533
		text = "返回关卡选择", -- 1534
		fontSize = btnFont, -- 1535
		bgHex = ResultButtonBgHex, -- 1536
		fgHex = ResultButtonFgHex, -- 1537
		borderHex = ResultButtonBorderHex, -- 1538
		fireOn = "press", -- 1540
		onTap = opts.onBackToSelect -- 1541
	}) -- 1541
	backButton.root.position = Vec2((viewW - btnW) / 2, 110) -- 1543
	root.visible = false -- 1545
	backButton:setEnabled(false) -- 1547
	return { -- 1549
		root = root, -- 1550
		show = function(____, main, sub) -- 1551
			setLabelText(mainLabel, main) -- 1552
			setLabelText(subLabel, sub) -- 1553
			backButton:setEnabled(true) -- 1554
			root.visible = true -- 1555
		end, -- 1551
		hide = function() -- 1557
			root.visible = false -- 1558
			backButton:setEnabled(false) -- 1560
		end -- 1557
	} -- 1557
end -- 1507
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 1599
	local root = createPanel( -- 1605
		parent, -- 1605
		viewW, -- 1605
		viewH, -- 1605
		SelectBackdropHex, -- 1605
		{alpha = 0.9} -- 1605
	) -- 1605
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 1607
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 1608
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 1610
	setLabelCenter( -- 1611
		subtitleLabel, -- 1611
		viewW / 2, -- 1611
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 1611
	) -- 1611
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 1613
	setLabelCenter( -- 1614
		hintLabel, -- 1614
		viewW / 2, -- 1614
		clampNumber(viewH * 0.045, 36, 90) -- 1614
	) -- 1614
	local count = #opts.levels -- 1616
	local cols = viewH > viewW and 2 or 1 -- 1619
	local rows = math.max( -- 1620
		1, -- 1620
		math.ceil(count / cols) -- 1620
	) -- 1620
	local gap = 18 -- 1621
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 1622
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 1623
	local availW = viewW * 0.84 -- 1624
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 1625
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 1626
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 1627
	local gridW = cols * btnW + gap * (cols - 1) -- 1628
	local topY = viewH - headerH -- 1629
	local buttons = {} -- 1631
	do -- 1631
		local i = 0 -- 1632
		while i < count do -- 1632
			local index = i -- 1634
			local button = createButton( -- 1635
				root, -- 1635
				{ -- 1635
					w = btnW, -- 1636
					h = btnH, -- 1637
					text = opts.levels[index + 1].name, -- 1638
					fontSize = 38, -- 1639
					bgHex = SelectLockedBgHex, -- 1640
					fgHex = SelectLockedFgHex, -- 1641
					borderHex = SelectBorderHex, -- 1642
					fireOn = "press", -- 1644
					onTap = function() return opts:onPick(index) end -- 1645
				} -- 1645
			) -- 1645
			local col = index % cols -- 1647
			local rowIndex = math.floor(index / cols) -- 1648
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 1649
			buttons[#buttons + 1] = button -- 1653
			i = i + 1 -- 1632
		end -- 1632
	end -- 1632
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 1659
		root, -- 1660
		{ -- 1660
			w = clampNumber(viewW * 0.36, 180, 300), -- 1661
			h = MinButtonHeight, -- 1662
			text = "重看开场", -- 1663
			fontSize = 30, -- 1664
			bgHex = SelectLockedBgHex, -- 1665
			fgHex = SelectSubtitleHex, -- 1666
			borderHex = SelectBorderHex, -- 1667
			fireOn = "press", -- 1668
			onTap = function() -- 1669
				if opts.onReplayIntro ~= nil then -- 1669
					opts:onReplayIntro() -- 1670
				end -- 1670
			end -- 1669
		} -- 1669
	) or nil -- 1669
	if replayButton ~= nil then -- 1669
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 1675
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 1676
		replayButton.root.position = Vec2( -- 1677
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 1677
			by -- 1677
		) -- 1677
	end -- 1677
	root.visible = false -- 1680
	do -- 1680
		local i = 0 -- 1681
		while i < count do -- 1681
			buttons[i + 1]:setEnabled(false) -- 1681
			i = i + 1 -- 1681
		end -- 1681
	end -- 1681
	if replayButton ~= nil then -- 1681
		replayButton:setEnabled(false) -- 1682
	end -- 1682
	return { -- 1684
		root = root, -- 1685
		show = function(____, unlocked) -- 1686
			local maxUnlocked = clampNumber( -- 1687
				math.floor(unlocked), -- 1687
				0, -- 1687
				count - 1 -- 1687
			) -- 1687
			setLabelText( -- 1688
				subtitleLabel, -- 1688
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 1688
			) -- 1688
			do -- 1688
				local i = 0 -- 1689
				while i < count do -- 1689
					local button = buttons[i + 1] -- 1690
					local open = i <= maxUnlocked -- 1691
					button:setEnabled(open) -- 1692
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 1693
					if open then -- 1693
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 1694
					else -- 1694
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 1695
					end -- 1695
					i = i + 1 -- 1689
				end -- 1689
			end -- 1689
			root.visible = true -- 1697
			if replayButton ~= nil then -- 1697
				replayButton:setEnabled(true) -- 1698
			end -- 1698
		end, -- 1686
		hide = function() -- 1700
			root.visible = false -- 1701
			do -- 1701
				local i = 0 -- 1703
				while i < count do -- 1703
					buttons[i + 1]:setEnabled(false) -- 1703
					i = i + 1 -- 1703
				end -- 1703
			end -- 1703
			if replayButton ~= nil then -- 1703
				replayButton:setEnabled(false) -- 1704
			end -- 1704
		end -- 1700
	} -- 1700
end -- 1599
return ____exports -- 1599