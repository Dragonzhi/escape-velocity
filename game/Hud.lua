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
function ____exports.createAimInput(parent, viewW, viewH, maxSpeed, minSpeed, speedChoices, transferTutorial, transferMode) -- 338
	if transferTutorial == nil then -- 338
		transferTutorial = false -- 348
	end -- 348
	if transferMode == nil then -- 348
		transferMode = "lunar" -- 349
	end -- 349
	local datePlate, dateLabel -- 349
	local speedMin = minSpeed ~= nil and minSpeed >= 0 and minSpeed < (maxSpeed ~= nil and maxSpeed or AimMaxSpeed) and minSpeed or AimMinSpeed -- 351
	local speedTop = maxSpeed ~= nil and maxSpeed > speedMin and maxSpeed or AimMaxSpeed -- 353
	local root = Node() -- 354
	root.size = Size(viewW, viewH) -- 355
	root.anchor = Vec2(0, 0) -- 361
	root.position = Vec2(0, 0) -- 362
	local touchLayer = Node() -- 365
	touchLayer.size = Size(viewW, viewH) -- 366
	touchLayer.anchor = Vec2(0.5, 0.5) -- 367
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 368
	touchLayer.swallowTouches = true -- 369
	root:addChild(touchLayer) -- 370
	local space = {viewW = viewW, viewH = viewH} -- 372
	local enabled = false -- 374
	local dragging = false -- 375
	--- 整屏瞄准（2D 模式）；由 Game 按视图状态同步。
	local fullScreenAim = false -- 377
	local aim = {velocity = {x = 0, y = -speedMin}, power = 0, unit = {x = 0, y = -1}} -- 378
	local probeOffset = {x = 0, y = 0} -- 381
	local dragHandler = nil -- 383
	local readyHandler = nil -- 384
	local observeHandler = nil -- 385
	local zoomHandler = nil -- 386
	local launchHandler = nil -- 387
	local skipTourHandler = nil -- 388
	local tourActiveChecker = nil -- 389
	local pressOffset = {x = 0, y = 0} -- 400
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 403
		aim = ____exports.computeAim( -- 404
			{x = 0, y = 0}, -- 404
			delta, -- 404
			AimMaxDragPx, -- 404
			speedTop, -- 404
			speedMin -- 404
		) -- 404
		if dragHandler ~= nil then -- 404
			dragHandler(aim) -- 405
		end -- 405
	end -- 403
	local aimRadius = math.max(96, viewW * 0.25) -- 412
	local mode = "none" -- 413
	local observeLast = {x = 0, y = 0} -- 414
	touchLayer:onTapBegan(function(touch) -- 415
		if not enabled then -- 415
			return -- 416
		end -- 416
		if tourActiveChecker ~= nil and tourActiveChecker() and skipTourHandler ~= nil then -- 416
			skipTourHandler() -- 418
			return -- 419
		end -- 419
		local at = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 421
		local dx = at.x - probeOffset.x -- 422
		local dy = at.y - probeOffset.y -- 423
		if fullScreenAim or math.sqrt(dx * dx + dy * dy) <= aimRadius then -- 423
			mode = "aim" -- 425
			dragging = true -- 426
			pressOffset = at -- 427
			handleDelta({x = 0, y = 0}) -- 429
		else -- 429
			mode = "observe" -- 431
			observeLast = at -- 432
		end -- 432
	end) -- 415
	touchLayer:onTapMoved(function(touch) -- 436
		if not enabled then -- 436
			return -- 437
		end -- 437
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 438
		if mode == "aim" and dragging then -- 438
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 440
		elseif mode == "observe" then -- 440
			if observeHandler ~= nil then -- 440
				observeHandler(cur.x - observeLast.x, cur.y - observeLast.y) -- 443
			end -- 443
			observeLast = cur -- 444
		end -- 444
	end) -- 436
	touchLayer:onTapEnded(function(touch) -- 448
		if not enabled then -- 448
			return -- 449
		end -- 449
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 450
		if mode == "aim" then -- 450
			dragging = false -- 452
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 453
			if readyHandler ~= nil then -- 453
				readyHandler(aim) -- 455
			end -- 455
		end -- 455
		mode = "none" -- 457
	end) -- 448
	touchLayer:onGesture(function(_center, numFingers, deltaDist, _deltaAngle) -- 461
		if not enabled or numFingers < 2 then -- 461
			return -- 462
		end -- 462
		if zoomHandler ~= nil then -- 462
			zoomHandler(deltaDist) -- 463
		end -- 463
	end) -- 461
	touchLayer.touchEnabled = false -- 471
	createPanel( -- 477
		root, -- 477
		220, -- 477
		50, -- 477
		658964, -- 477
		{alpha = 0.45} -- 477
	) -- 477
	local orbitName = transferMode == "inward" and "近日点" or (transferMode == "outward" and "远日点" or "远地点高度") -- 478
	local dvLabel = createLabel(root, transferTutorial and "拖动调整" .. orbitName or "Δv — / —", transferTutorial and 22 or 30, ResultHintHex) -- 479
	if dvLabel ~= nil then -- 479
		dvLabel.position = Vec2(24, viewH - (transferTutorial and 130 or 44)) -- 481
		dvLabel.anchor = Vec2(0, 0) -- 482
	end -- 482
	local warpHandler = nil -- 492
	local dateSpan = 0 -- 493
	--- 这一关有时间轴**且**当前相态允许改日期（Flying/Result 时必须是 false）。
	local warpOn = true -- 500
	local warpVisible = true -- 501
	--- 相态是否允许改日期（由主循环每帧 setTimeEnabled 同步）。
	local warpAllowed = true -- 503
	--- 上次写进日期的文字（避免每帧重设 Label 文本）。
	local lastDateText = "" -- 505
	--- >0 = 正在按住这个方向（-1 回退 / +1 加速）；0 = 没按住。
	local warpHoldDir = 0 -- 507
	--- 距离下一次连按还有多久（秒）。
	local warpRepeatIn = 0 -- 509
	local WarpButtonW = 116 -- 510
	local WarpButtonH = 64 -- 511
	local warpButtons = {} -- 512
	local function applyWarpState() -- 513
		local vis = dateSpan > 0 -- 514
		local on = vis and warpAllowed -- 515
		if vis == warpVisible and on == warpOn then -- 515
			return -- 516
		end -- 516
		warpVisible = vis -- 517
		warpOn = on -- 518
		if not on then -- 518
			warpHoldDir = 0 -- 519
		end -- 519
		for ____, b in ipairs(warpButtons) do -- 520
			b.root.visible = vis -- 521
			b:setEnabled(on) -- 522
		end -- 522
		if dateLabel ~= nil then -- 522
			dateLabel.visible = vis -- 524
		end -- 524
		datePlate.visible = vis -- 525
	end -- 513
	local function makeWarpButton(text, dir, x) -- 527
		local btn = createButton( -- 528
			root, -- 528
			{ -- 528
				w = WarpButtonW, -- 529
				h = WarpButtonH, -- 530
				text = text, -- 531
				fontSize = 30, -- 532
				bgHex = ResultButtonAltBgHex, -- 533
				fgHex = ResultButtonFgHex, -- 534
				borderHex = ResultButtonBorderHex, -- 535
				onTap = function() -- 538
				end, -- 538
				onPressBegan = function() -- 539
					print((("[escape-velocity] warp press dir=" .. __TS__NumberToFixed(dir, 0)) .. " on=") .. (warpOn and "1" or "0")) -- 541
					if not warpOn then -- 541
						return -- 542
					end -- 542
					if warpHoldDir == dir then -- 542
						return -- 544
					end -- 544
					warpHoldDir = dir -- 545
					warpRepeatIn = WarpHoldDelaySec -- 546
					if warpHandler ~= nil then -- 546
						warpHandler(dir) -- 547
					end -- 547
				end, -- 539
				onPressEnded = function() -- 549
					print((("[escape-velocity] warp release dir=" .. __TS__NumberToFixed(dir, 0)) .. " hold=") .. __TS__NumberToFixed(warpHoldDir, 0)) -- 550
					if warpHoldDir == dir then -- 550
						warpHoldDir = 0 -- 552
					end -- 552
				end -- 549
			} -- 549
		) -- 549
		btn.root.position = Vec2(x, viewH - 96 - WarpButtonH) -- 558
		warpButtons[#warpButtons + 1] = btn -- 559
	end -- 527
	local warpLeftX = viewW - (WarpButtonW * 2 + 8) - 20 -- 561
	makeWarpButton("◀ 回退", -1, warpLeftX) -- 562
	makeWarpButton("加速 ▶", 1, warpLeftX + WarpButtonW + 8) -- 563
	datePlate = createPanel( -- 565
		root, -- 565
		300, -- 565
		50, -- 565
		658964, -- 565
		{alpha = 0.45} -- 565
	) -- 565
	datePlate.position = Vec2(warpLeftX - 316, viewH - 96 - WarpButtonH + 8) -- 566
	dateLabel = createLabel(root, "发射日期 —", 30, ResultHintHex) -- 567
	if dateLabel ~= nil then -- 567
		dateLabel.anchor = Vec2(1, 0) -- 572
		dateLabel.position = Vec2(warpLeftX - 16, viewH - 96 - WarpButtonH + 18) -- 573
	end -- 573
	local QuickRetryW = 110 -- 577
	local QuickRetryH = 50 -- 578
	local quickRetryHandler = nil -- 579
	local quickRetryBtn = createButton( -- 580
		root, -- 580
		{ -- 580
			w = QuickRetryW, -- 581
			h = QuickRetryH, -- 582
			text = "↺ 重试", -- 583
			fontSize = 26, -- 584
			bgHex = 12730636, -- 585
			fgHex = 16777215, -- 586
			borderHex = 16498468, -- 587
			fireOn = "press", -- 588
			onTap = function() -- 589
				print("[escape-velocity] quick retry tapped") -- 590
				if quickRetryHandler ~= nil then -- 590
					quickRetryHandler() -- 591
				end -- 591
			end -- 589
		} -- 589
	) -- 589
	quickRetryBtn.root.position = Vec2(viewW - QuickRetryW - 20, viewH - QuickRetryH - 20) -- 594
	local starPlateW = 180 -- 597
	local starPlateH = 46 -- 598
	local starPlate = createPanel( -- 599
		root, -- 599
		starPlateW, -- 599
		starPlateH, -- 599
		658964, -- 599
		{alpha = 0.55} -- 599
	) -- 599
	starPlate.position = Vec2(viewW / 2 - starPlateW / 2, viewH - starPlateH - 22) -- 600
	starPlate.visible = not transferTutorial -- 601
	local starStatusLabel = createLabel(root, "☆ ☆ ☆", 30, 16766720) -- 602
	if starStatusLabel ~= nil then -- 602
		starStatusLabel.anchor = Vec2(0.5, 0.5) -- 604
		starStatusLabel.position = Vec2(viewW / 2, viewH - starPlateH / 2 - 22) -- 605
	end -- 605
	local function updateStarsStatus(count) -- 607
		if starStatusLabel == nil then -- 607
			return -- 608
		end -- 608
		if transferTutorial then -- 608
			starStatusLabel.visible = false -- 609
			return -- 609
		end -- 609
		local s = "☆ ☆ ☆" -- 610
		if count == 1 then -- 610
			s = "★ ☆ ☆" -- 611
		elseif count == 2 then -- 611
			s = "★ ★ ☆" -- 612
		elseif count >= 3 then -- 612
			s = "★ ★ ★" -- 613
		end -- 613
		setLabelText(starStatusLabel, s) -- 614
	end -- 607
	local LaunchButtonW = 220 -- 619
	local LaunchButtonH = 112 -- 620
	local launchButton = createButton( -- 621
		root, -- 621
		{ -- 621
			w = LaunchButtonW, -- 622
			h = LaunchButtonH, -- 623
			text = "▲ 发射 ▲", -- 624
			fontSize = 38, -- 625
			bgHex = ResultButtonBgHex, -- 626
			fgHex = ResultButtonFgHex, -- 627
			borderHex = ResultButtonBorderHex, -- 628
			fireOn = "press", -- 629
			onTap = function() -- 630
				print("[escape-velocity] launch button fire (press)") -- 631
				if launchHandler ~= nil then -- 631
					launchHandler() -- 632
				end -- 632
			end -- 630
		} -- 630
	) -- 630
	launchButton.root.position = Vec2(viewW - LaunchButtonW - 24, 96) -- 635
	launchButton.root.visible = false -- 636
	launchButton:setEnabled(false) -- 637
	local CancelButtonW = 160 -- 640
	local CancelButtonH = 72 -- 641
	local cancelAimHandler = nil -- 642
	local cancelAimButton = createButton( -- 643
		root, -- 643
		{ -- 643
			w = CancelButtonW, -- 644
			h = CancelButtonH, -- 645
			text = "✕ 取消", -- 646
			fontSize = 28, -- 647
			bgHex = ResultButtonAltBgHex, -- 648
			fgHex = ResultButtonFgHex, -- 649
			borderHex = ResultButtonBorderHex, -- 650
			fireOn = "press", -- 651
			onTap = function() -- 652
				print("[escape-velocity] cancel aim fire (press)") -- 653
				if cancelAimHandler ~= nil then -- 653
					cancelAimHandler() -- 654
				end -- 654
			end -- 652
		} -- 652
	) -- 652
	cancelAimButton.root.position = Vec2(viewW - LaunchButtonW - CancelButtonW - 40, 116) -- 657
	cancelAimButton.root.visible = false -- 658
	cancelAimButton:setEnabled(false) -- 659
	local ViewButtonW = 116 -- 663
	local ViewButtonH = 64 -- 664
	local viewHandler = nil -- 665
	local viewButton = createButton( -- 666
		root, -- 666
		{ -- 666
			w = ViewButtonW, -- 667
			h = ViewButtonH, -- 668
			text = "[ 3D ]", -- 669
			fontSize = 26, -- 670
			bgHex = ResultButtonAltBgHex, -- 671
			fgHex = ResultButtonFgHex, -- 672
			borderHex = ResultButtonBorderHex, -- 673
			fireOn = "press", -- 674
			onTap = function() -- 675
				print("[escape-velocity] view toggle fire (press)") -- 676
				if viewHandler ~= nil then -- 676
					viewHandler() -- 677
				end -- 677
			end -- 675
		} -- 675
	) -- 675
	viewButton.root.position = Vec2(viewW - ViewButtonW - 24, 96 + LaunchButtonH + 12) -- 680
	--- 上次写进按钮的文字（每帧都会被 setViewMode 调用，没变就别碰 Label）。
	local lastViewText = "2D" -- 682
	local cameraFocusHandler = nil -- 685
	local endViewingHandler = nil -- 686
	local cameraFocusButton = transferTutorial and createButton( -- 687
		root, -- 687
		{ -- 687
			w = 260, -- 688
			h = 58, -- 688
			text = "镜头 · 自动", -- 688
			fontSize = 22, -- 688
			bgHex = ResultButtonAltBgHex, -- 689
			fgHex = ResultButtonFgHex, -- 689
			borderHex = ResultButtonBorderHex, -- 689
			fireOn = "press", -- 689
			onTap = function() -- 690
				if cameraFocusHandler ~= nil then -- 690
					cameraFocusHandler() -- 690
				end -- 690
			end -- 690
		} -- 690
	) or nil -- 690
	local endViewingButton = transferTutorial and createButton( -- 692
		root, -- 692
		{ -- 692
			w = 220, -- 693
			h = LaunchButtonH, -- 693
			text = "结束观赏", -- 693
			fontSize = 26, -- 693
			bgHex = ResultButtonAltBgHex, -- 694
			fgHex = ResultButtonFgHex, -- 694
			borderHex = ResultButtonBorderHex, -- 694
			fireOn = "press", -- 694
			onTap = function() -- 695
				if endViewingHandler ~= nil then -- 695
					endViewingHandler() -- 695
				end -- 695
			end -- 695
		} -- 695
	) or nil -- 695
	if cameraFocusButton ~= nil then -- 695
		cameraFocusButton.root.position = Vec2(24, 266) -- 697
		cameraFocusButton.root.visible = false -- 697
		cameraFocusButton:setEnabled(false) -- 697
	end -- 697
	if endViewingButton ~= nil then -- 697
		endViewingButton.root.position = Vec2(viewW - 244, 96) -- 698
		endViewingButton.root.visible = false -- 698
		endViewingButton:setEnabled(false) -- 698
	end -- 698
	local ____transferTutorial_0 -- 699
	if transferTutorial then -- 699
		____transferTutorial_0 = createLabel(root, "", 24, ResultHintHex) -- 699
	else -- 699
		____transferTutorial_0 = nil -- 699
	end -- 699
	local viewingLabel = ____transferTutorial_0 -- 699
	if viewingLabel ~= nil then -- 699
		viewingLabel.position = Vec2(24, viewH - 130) -- 700
		viewingLabel.anchor = Vec2(0, 0) -- 700
		viewingLabel.visible = false -- 700
	end -- 700
	local viewingKey = "" -- 701
	local ZoomBtnSize = 58 -- 704
	local zoomGap = 8 -- 705
	local zoomButtons = {} -- 706
	local zoomInHandler = nil -- 707
	local zoomOutHandler = nil -- 708
	local fitViewHandler = nil -- 709
	local function makeZoomButton(text, x, fontSize, onClick) -- 711
		local btn = createButton( -- 712
			root, -- 712
			{ -- 712
				w = ZoomBtnSize, -- 713
				h = ZoomBtnSize, -- 714
				text = text, -- 715
				fontSize = fontSize, -- 716
				bgHex = ResultButtonAltBgHex, -- 717
				fgHex = ResultButtonFgHex, -- 718
				borderHex = ResultButtonBorderHex, -- 719
				fireOn = "press", -- 720
				onTap = function() -- 721
					print(("[escape-velocity] zoom btn " .. text) .. " fire") -- 722
					onClick() -- 723
				end -- 721
			} -- 721
		) -- 721
		btn.root.position = Vec2(x, 96) -- 726
		btn.root.visible = false -- 727
		btn:setEnabled(false) -- 728
		zoomButtons[#zoomButtons + 1] = btn -- 729
		return btn -- 730
	end -- 711
	makeZoomButton( -- 732
		"−", -- 732
		24, -- 732
		32, -- 732
		function() -- 732
			if zoomOutHandler ~= nil then -- 732
				zoomOutHandler() -- 733
			end -- 733
		end -- 732
	) -- 732
	makeZoomButton( -- 735
		"FIT", -- 735
		24 + ZoomBtnSize + zoomGap, -- 735
		20, -- 735
		function() -- 735
			if fitViewHandler ~= nil then -- 735
				fitViewHandler() -- 736
			end -- 736
		end -- 735
	) -- 735
	makeZoomButton( -- 738
		"+", -- 738
		24 + (ZoomBtnSize + zoomGap) * 2, -- 738
		32, -- 738
		function() -- 738
			if zoomInHandler ~= nil then -- 738
				zoomInHandler() -- 739
			end -- 739
		end -- 738
	) -- 738
	local zoomControlsVisible = nil -- 741
	local function setZoomVisible(on) -- 742
		if zoomControlsVisible == on then -- 742
			return -- 743
		end -- 743
		zoomControlsVisible = on -- 744
		for ____, b in ipairs(zoomButtons) do -- 745
			b.root.visible = on -- 746
			b:setEnabled(on) -- 747
		end -- 747
	end -- 742
	setZoomVisible(false) -- 750
	local TimeBtnW = 78 -- 756
	local TimeBtnH = 64 -- 757
	local TimeRowY = 170 -- 758
	local speedUpHandler = nil -- 759
	local speedDownHandler = nil -- 760
	local pauseHandler = nil -- 761
	local slowButton = createButton( -- 763
		root, -- 763
		{ -- 763
			w = TimeBtnW, -- 764
			h = TimeBtnH, -- 764
			text = "◀ 慢", -- 764
			fontSize = 26, -- 764
			bgHex = ResultButtonAltBgHex, -- 765
			fgHex = ResultButtonFgHex, -- 765
			borderHex = ResultButtonBorderHex, -- 765
			onTap = function() -- 766
				print("[escape-velocity] speed down fire") -- 767
				if speedDownHandler ~= nil then -- 767
					speedDownHandler() -- 768
				end -- 768
			end -- 766
		} -- 766
	) -- 766
	slowButton.root.position = Vec2(24, TimeRowY) -- 771
	local pauseButton = createButton( -- 772
		root, -- 772
		{ -- 772
			w = TimeBtnW, -- 773
			h = TimeBtnH, -- 773
			text = "⏸", -- 773
			fontSize = 30, -- 773
			bgHex = ResultButtonAltBgHex, -- 774
			fgHex = ResultButtonFgHex, -- 774
			borderHex = ResultButtonBorderHex, -- 774
			onTap = function() -- 775
				print("[escape-velocity] pause toggle fire") -- 776
				if pauseHandler ~= nil then -- 776
					pauseHandler() -- 777
				end -- 777
			end -- 775
		} -- 775
	) -- 775
	pauseButton.root.position = Vec2(24 + TimeBtnW + 8, TimeRowY) -- 780
	local fastButton = createButton( -- 781
		root, -- 781
		{ -- 781
			w = TimeBtnW, -- 782
			h = TimeBtnH, -- 782
			text = "快 ▶", -- 782
			fontSize = 26, -- 782
			bgHex = ResultButtonAltBgHex, -- 783
			fgHex = ResultButtonFgHex, -- 783
			borderHex = ResultButtonBorderHex, -- 783
			onTap = function() -- 784
				print("[escape-velocity] speed up fire") -- 785
				if speedUpHandler ~= nil then -- 785
					speedUpHandler() -- 786
				end -- 786
			end -- 784
		} -- 784
	) -- 784
	fastButton.root.position = Vec2(24 + (TimeBtnW + 8) * 2, TimeRowY) -- 789
	local timePlate = createPanel( -- 792
		root, -- 792
		300, -- 792
		50, -- 792
		658964, -- 792
		{alpha = 0.45} -- 792
	) -- 792
	timePlate.position = transferTutorial and Vec2(24, viewH - 190) or Vec2(24 + (TimeBtnW + 8) * 3 + 4, TimeRowY + 7) -- 793
	local timeLabel = createLabel(root, "1×（现实）  T+ 0:00", transferTutorial and 22 or 26, ResultHintHex) -- 794
	if timeLabel ~= nil then -- 794
		timeLabel.anchor = Vec2(0, 0) -- 796
		timeLabel.position = transferTutorial and Vec2(36, viewH - 179) or Vec2(24 + (TimeBtnW + 8) * 3 + 16, TimeRowY + 18) -- 797
	end -- 797
	--- 档位文字：pow 0 就是"1×（现实）"，别写成 1e0×。
	local function powText(pow) -- 800
		return pow <= 0 and "1×（现实）" or ("1e" .. __TS__NumberToFixed(pow, 0)) .. "×" -- 800
	end -- 800
	--- 任务时钟：真实秒 → "T+ 3天 04:12"。1× 下它每秒跳一格 —— 时间在流逝的唯一可见证据。
	local function missionText(sec) -- 802
		local s = sec > 0 and sec or 0 -- 803
		local days = math.floor(s / 86400) -- 804
		local rest = s - days * 86400 -- 805
		local hh = math.floor(rest / 3600) -- 806
		local mm = math.floor((rest - hh * 3600) / 60) -- 807
		local function pad(v) -- 808
			return (v < 10 and "0" or "") .. __TS__NumberToFixed(v, 0) -- 808
		end -- 808
		return ((("T+ " .. (days > 0 and __TS__NumberToFixed(days, 0) .. "天 " or "")) .. pad(hh)) .. ":") .. pad(mm) -- 809
	end -- 802
	local lastTimeText = "" -- 811
	local lastPaused = false -- 812
	local function setTimeControl(pow, maxPow, paused, missionSeconds, actualRate) -- 813
		local txt = (((transferTutorial and actualRate ~= nil and __TS__NumberToFixed(actualRate, 2) .. "×" or powText(pow)) .. (paused and " ⏸ 暂停" or "")) .. "  ") .. (transferTutorial and ("T+ " .. __TS__NumberToFixed(missionSeconds, 1)) .. "s" or missionText(missionSeconds)) -- 814
		if txt ~= lastTimeText then -- 814
			lastTimeText = txt -- 816
			if timeLabel ~= nil then -- 816
				timeLabel.text = txt -- 817
			end -- 817
		end -- 817
		if paused ~= lastPaused then -- 817
			lastPaused = paused -- 820
			pauseButton:setText(paused and "▶" or "⏸") -- 821
			pauseButton:setColors(paused and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 822
		end -- 822
		fastButton:setEnabled(pow < maxPow) -- 825
		slowButton:setEnabled(pow > 0) -- 826
	end -- 813
	local DrawerW = 380 -- 830
	local DrawerH = 46 -- 831
	local missionDrawerPlate = createPanel( -- 832
		root, -- 832
		DrawerW, -- 832
		DrawerH, -- 832
		658964, -- 832
		{alpha = 0.65, borderHex = 4610157} -- 832
	) -- 832
	missionDrawerPlate.position = Vec2(transferTutorial and 24 or (viewW - DrawerW) / 2, viewH - 56) -- 833
	local missionTitleLabel = createLabel(missionDrawerPlate, "", 19, 13426158) -- 834
	if missionTitleLabel ~= nil then -- 834
		missionTitleLabel.anchor = Vec2(0, 0.5) -- 836
		missionTitleLabel.position = Vec2(14, DrawerH / 2) -- 837
	end -- 837
	local missionRocketsLabel = createLabel(missionDrawerPlate, "☆  ☆  ☆", 22, 16766720) -- 839
	if missionRocketsLabel ~= nil then -- 839
		missionRocketsLabel.anchor = Vec2(1, 0.5) -- 841
		missionRocketsLabel.position = Vec2(DrawerW - 14, DrawerH / 2) -- 842
	end -- 842
	missionDrawerPlate.visible = false -- 844
	local drawerVisible = false -- 845
	local drawerLevelTitle = "" -- 846
	local drawerRockets = 0 -- 847
	local liveFuelBonus = false -- 848
	local function updateDrawerDisplay() -- 850
		if missionTitleLabel ~= nil then -- 850
			setLabelText(missionTitleLabel, drawerLevelTitle) -- 852
		end -- 852
		if missionRocketsLabel ~= nil then -- 852
			local r1 = drawerRockets >= 1 and "★" or "☆" -- 855
			local r2 = (drawerRockets >= 2 or liveFuelBonus) and "★" or "☆" -- 856
			local r3 = drawerRockets >= 3 and "★" or "☆" -- 857
			setLabelText(missionRocketsLabel, transferTutorial and (drawerRockets >= 1 and "已完成" or (transferMode == "lunar" and "地月转移练习" or "日心借力练习")) or (((r1 .. "  ") .. r2) .. "  ") .. r3) -- 858
		end -- 858
	end -- 850
	local IntroBannerW = math.min(viewW - 48, 540) -- 863
	local IntroBannerH = 68 -- 864
	local introBannerPlate = createPanel( -- 865
		root, -- 865
		IntroBannerW, -- 865
		IntroBannerH, -- 865
		658964, -- 865
		{alpha = 0.8, borderHex = 4610157} -- 865
	) -- 865
	introBannerPlate.position = Vec2((viewW - IntroBannerW) / 2, 70) -- 866
	local introBannerTitle = createLabel(introBannerPlate, "", 17, 15398143) -- 867
	if introBannerTitle ~= nil then -- 867
		introBannerTitle.anchor = Vec2(0.5, 0.5) -- 869
		introBannerTitle.position = Vec2(IntroBannerW / 2, IntroBannerH * 0.65) -- 870
	end -- 870
	local introBannerHint = createLabel(introBannerPlate, "轻触屏幕任意位置跳过运镜", 13, 9283005) -- 872
	if introBannerHint ~= nil then -- 872
		introBannerHint.anchor = Vec2(0.5, 0.5) -- 874
		introBannerHint.position = Vec2(IntroBannerW / 2, IntroBannerH * 0.28) -- 875
	end -- 875
	introBannerPlate.visible = false -- 877
	local PlaybackButtonW = 116 -- 886
	local PlaybackButtonH = 64 -- 887
	local playbackGap = 10 -- 888
	local playbackButtons = {} -- 889
	local playbackSpeeds = {} -- 890
	local playbackHandler = nil -- 891
	local speedChoice = speedChoices ~= nil and #speedChoices > 0 and speedChoices or ({1, 2, 4}) -- 894
	local playbackSpeed = speedChoice[1] -- 895
	--- 已应用到节点上的显隐状态。初值 false 如实反映"建出来就隐藏"（照 warp 按钮的教训）。
	local playbackVisible = false -- 897
	local function paintPlayback() -- 898
		do -- 898
			local i = 0 -- 899
			while i < #playbackButtons do -- 899
				local on = playbackSpeeds[i + 1] == playbackSpeed -- 900
				playbackButtons[i + 1]:setColors(on and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 901
				i = i + 1 -- 899
			end -- 899
		end -- 899
	end -- 898
	local function makePlaybackButton(speed, x) -- 904
		local btn = createButton( -- 905
			root, -- 905
			{ -- 905
				w = PlaybackButtonW, -- 906
				h = PlaybackButtonH, -- 907
				text = ____exports.playbackLabel(speed), -- 908
				fontSize = 30, -- 909
				bgHex = ResultButtonAltBgHex, -- 910
				fgHex = ResultButtonFgHex, -- 911
				borderHex = ResultButtonBorderHex, -- 912
				onTap = function() -- 913
					print(("[escape-velocity] playback button fire " .. __TS__NumberToFixed(speed, 0)) .. "x (release)") -- 915
					playbackSpeed = speed -- 916
					paintPlayback() -- 917
					if playbackHandler ~= nil then -- 917
						playbackHandler(speed) -- 918
					end -- 918
				end -- 913
			} -- 913
		) -- 913
		btn.root.position = Vec2(x, 96) -- 923
		playbackButtons[#playbackButtons + 1] = btn -- 924
		playbackSpeeds[#playbackSpeeds + 1] = speed -- 925
	end -- 904
	do -- 904
		local i = 0 -- 927
		while i < #speedChoice and i < 3 do -- 927
			makePlaybackButton(speedChoice[i + 1], 24 + (PlaybackButtonW + playbackGap) * i) -- 928
			i = i + 1 -- 927
		end -- 927
	end -- 927
	paintPlayback() -- 930
	for ____, b in ipairs(playbackButtons) do -- 932
		b.root.visible = false -- 933
		b:setEnabled(false) -- 934
	end -- 934
	parent:addChild(root) -- 937
	return { -- 939
		onDrag = function(____, callback) -- 940
			dragHandler = callback -- 941
		end, -- 940
		setEnabled = function(____, value) -- 943
			enabled = value -- 944
			touchLayer.touchEnabled = value -- 947
			if not value then -- 947
				dragging = false -- 949
			end -- 949
		end, -- 943
		onAimReady = function(____, callback) -- 952
			readyHandler = callback -- 953
		end, -- 952
		onObserve = function(____, callback) -- 955
			observeHandler = callback -- 956
		end, -- 955
		onZoom = function(____, callback) -- 958
			zoomHandler = callback -- 959
		end, -- 958
		onLaunch = function(____, callback) -- 961
			launchHandler = callback -- 962
		end, -- 961
		onCancelAim = function(____, callback) -- 964
			cancelAimHandler = callback -- 965
		end, -- 964
		setArmed = function(____, armed) -- 967
			launchButton.root.visible = armed -- 968
			launchButton:setEnabled(armed) -- 969
			cancelAimButton.root.visible = armed -- 970
			cancelAimButton:setEnabled(armed) -- 971
		end, -- 967
		onViewToggle = function(____, callback) -- 973
			viewHandler = callback -- 974
		end, -- 973
		onCameraFocus = function(____, callback) -- 976
			cameraFocusHandler = callback -- 976
		end, -- 976
		onEndViewing = function(____, callback) -- 977
			endViewingHandler = callback -- 977
		end, -- 977
		setFlightViewing = function(____, flying, completed, mode, is3D, stage) -- 978
			if not transferTutorial then -- 978
				return -- 979
			end -- 979
			local key = ((((flying and "1" or "0") .. (completed and "1" or "0")) .. mode) .. (is3D and "1" or "0")) .. (stage ~= nil and stage or "") -- 980
			if viewingKey == key then -- 980
				return -- 981
			end -- 981
			viewingKey = key -- 982
			if dvLabel ~= nil then -- 982
				dvLabel.visible = not flying -- 983
			end -- 983
			if viewingLabel ~= nil then -- 983
				viewingLabel.visible = flying -- 985
				local near = stage == "Mercury" and "安全飞掠水星" or (stage == "Venus" and "金星减速借力" or (stage == "Jupiter" and "木星加速借力" or (stage == "Saturn" and "土星加速借力" or (stage == "Moon" and "借月球引力 · 观察轨迹转弯" or "滑行 · 观察航线")))) -- 986
				setLabelText(viewingLabel, completed and (transferMode == "lunar" and "掠月完成 · 继续观察返回" or "目标完成 · 继续观察航线") or (stage == "Launch" and (transferMode == "inward" and "逆行点火 · 降低近日点" or "顺行点火 · 抬高" .. orbitName) or near)) -- 987
				setLabelColor(viewingLabel, completed and 9430458 or ResultHintHex) -- 988
			end -- 988
			if cameraFocusButton ~= nil then -- 988
				cameraFocusButton.root.visible = flying and is3D -- 991
				cameraFocusButton:setEnabled(flying and is3D) -- 992
				local title = mode == "Mercury" and "水星" or (mode == "Auto" and "自动" or (mode == "Probe" and "探测器" or (mode == "Moon" and "月球" or (mode == "Earth" and "地球" or (mode == "Venus" and "金星" or (mode == "Jupiter" and "木星" or (mode == "Saturn" and "土星" or (mode == "Sun" and "太阳" or "总览")))))))) -- 993
				cameraFocusButton:setText("镜头 · " .. title) -- 994
			end -- 994
			if endViewingButton ~= nil then -- 994
				endViewingButton.root.visible = flying and completed -- 996
				endViewingButton:setEnabled(flying and completed) -- 996
			end -- 996
		end, -- 978
		setViewMode = function(____, mode) -- 998
			if mode == lastViewText then -- 998
				return -- 999
			end -- 999
			lastViewText = mode -- 1000
			local btnText = mode == "2D" and "[ 3D ]" or "[ 2D ]" -- 1002
			viewButton:setText(btnText) -- 1003
		end, -- 998
		onPlayback = function(____, callback) -- 1005
			playbackHandler = callback -- 1006
		end, -- 1005
		setPlayback = function(____, speed) -- 1008
			if speed == playbackSpeed then -- 1008
				return -- 1009
			end -- 1009
			playbackSpeed = speed -- 1010
			paintPlayback() -- 1011
		end, -- 1008
		setPlaybackVisible = function(____, on) -- 1013
			if on == playbackVisible then -- 1013
				return -- 1014
			end -- 1014
			playbackVisible = on -- 1015
			for ____, b in ipairs(playbackButtons) do -- 1016
				b.root.visible = on -- 1017
				b:setEnabled(on) -- 1018
			end -- 1018
		end, -- 1013
		setFullScreenAim = function(____, on) -- 1021
			fullScreenAim = on -- 1022
		end, -- 1021
		onWarp = function(____, callback) -- 1024
			warpHandler = callback -- 1025
		end, -- 1024
		setDate = function(____, t0, span) -- 1027
			dateSpan = span > 0 and span or 0 -- 1028
			applyWarpState() -- 1029
			local on = dateSpan > 0 -- 1030
			local text = on and (("发射日期 " .. __TS__NumberToFixed(t0, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0) or "发射日期" -- 1031
			if text ~= lastDateText then -- 1031
				lastDateText = text -- 1033
				setLabelText(dateLabel, text) -- 1034
			end -- 1034
		end, -- 1027
		setTimeEnabled = function(____, on) -- 1037
			if warpAllowed == on then -- 1037
				return -- 1038
			end -- 1038
			warpAllowed = on -- 1039
			applyWarpState() -- 1040
		end, -- 1037
		update = function(____, dt) -- 1042
			if not warpOn or warpHoldDir == 0 then -- 1042
				return -- 1043
			end -- 1043
			warpRepeatIn = warpRepeatIn - dt -- 1044
			if warpRepeatIn > 0 then -- 1044
				return -- 1045
			end -- 1045
			warpRepeatIn = TimeWarpStep / TimeWarpRate -- 1047
			if warpHandler ~= nil then -- 1047
				warpHandler(warpHoldDir) -- 1048
			end -- 1048
		end, -- 1042
		isDragging = function() return dragging end, -- 1050
		setBurnInfo = function(____, burn, budget) -- 1051
			if transferTutorial then -- 1051
				return -- 1052
			end -- 1052
			local b = budget < 1 and __TS__NumberToFixed(budget, 2) or __TS__NumberToFixed(budget, 0) -- 1056
			local v = burn < 1 and __TS__NumberToFixed(burn, 2) or __TS__NumberToFixed(burn, 1) -- 1057
			setLabelText(dvLabel, (("Δv " .. v) .. " / ") .. b) -- 1058
		end, -- 1051
		current = function() return aim end, -- 1060
		setTransferInfo = function(____, apoapsis, duration, reachable) -- 1061
			setLabelText( -- 1062
				dvLabel, -- 1062
				(((((orbitName .. " ") .. __TS__NumberToFixed(apoapsis, 0)) .. " · 点火 ") .. __TS__NumberToFixed(duration, 2)) .. "s") .. (reachable ~= nil and (reachable and (transferMode == "lunar" and " · 可减速掠月" or " · 航线可行") or " · 等待窗口") or "") -- 1062
			) -- 1062
		end, -- 1061
		setProbeOffset = function(____, offset) -- 1064
			probeOffset = offset -- 1065
		end, -- 1064
		handleLocal = function(____, ____local) -- 1069
			handleDelta(____exports.localToOffset(____local, space)) -- 1070
		end, -- 1069
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 1073
		debugProbeOffset = function() return probeOffset end, -- 1074
		onSpeedUp = function(____, callback) -- 1075
			speedUpHandler = callback -- 1076
		end, -- 1075
		onSpeedDown = function(____, callback) -- 1078
			speedDownHandler = callback -- 1079
		end, -- 1078
		onTogglePause = function(____, callback) -- 1081
			pauseHandler = callback -- 1082
		end, -- 1081
		setTimeControl = function(____, pow, maxPow, paused, missionSeconds, actualRate) -- 1084
			setTimeControl( -- 1085
				pow, -- 1085
				maxPow, -- 1085
				paused, -- 1085
				missionSeconds, -- 1085
				actualRate -- 1085
			) -- 1085
		end, -- 1084
		onZoomIn = function(____, callback) -- 1087
			zoomInHandler = callback -- 1088
		end, -- 1087
		onZoomOut = function(____, callback) -- 1090
			zoomOutHandler = callback -- 1091
		end, -- 1090
		onFitView = function(____, callback) -- 1093
			fitViewHandler = callback -- 1094
		end, -- 1093
		setZoomControlsVisible = function(____, on) -- 1096
			setZoomVisible(on) -- 1097
		end, -- 1096
		setMissionDrawer = function(____, levelName, _challenges, currentRockets) -- 1099
			drawerLevelTitle = levelName -- 1100
			drawerRockets = currentRockets -- 1101
			updateDrawerDisplay() -- 1102
		end, -- 1099
		setMissionDrawerVisible = function(____, visible) -- 1104
			if drawerVisible == visible then -- 1104
				return -- 1105
			end -- 1105
			drawerVisible = visible -- 1106
			missionDrawerPlate.visible = visible -- 1107
		end, -- 1104
		setLiveFuelChallengeStatus = function(____, achieved) -- 1109
			if liveFuelBonus == achieved then -- 1109
				return -- 1110
			end -- 1110
			liveFuelBonus = achieved -- 1111
			updateDrawerDisplay() -- 1112
		end, -- 1109
		setIntroTourBanner = function(____, title, hint) -- 1114
			if introBannerTitle ~= nil then -- 1114
				setLabelText(introBannerTitle, title) -- 1115
			end -- 1115
			if introBannerHint ~= nil and hint ~= nil then -- 1115
				setLabelText(introBannerHint, hint) -- 1116
			end -- 1116
		end, -- 1114
		setIntroTourBannerVisible = function(____, visible) -- 1118
			introBannerPlate.visible = visible -- 1119
		end, -- 1118
		onSkipTour = function(____, callback) -- 1121
			skipTourHandler = callback -- 1122
		end, -- 1121
		setTourActiveChecker = function(____, fn) -- 1124
			tourActiveChecker = fn -- 1125
		end, -- 1124
		onQuickRetry = function(____, callback) -- 1127
			quickRetryHandler = callback -- 1128
		end, -- 1127
		setStarsStatus = function(____, starsGot) -- 1130
			updateStarsStatus(starsGot) -- 1131
		end, -- 1130
		root = root -- 1133
	} -- 1133
end -- 338
local ResultBackdropHex = 329484 -- 1150
local ResultCardHex = 1252395 -- 1151
local ResultCardBorderHex = 3362938 -- 1152
local ResultLevelHex = 9417948 -- 1153
local ResultBodyHex = 14149367 -- 1154
ResultHintHex = 8229803 -- 1155
ResultButtonBgHex = 1919610 -- 1156
ResultButtonAltBgHex = 1779509 -- 1157
ResultButtonFgHex = 15398143 -- 1158
ResultButtonBorderHex = 5211846 -- 1159
local TitleSuccessHex = 8381344 -- 1160
local TitleMissedHex = 16766073 -- 1161
local TitleCrashedHex = 16743019 -- 1162
local SelectBackdropHex = 329484 -- 1164
local SelectTitleHex = 16777215 -- 1165
local SelectSubtitleHex = 10470632 -- 1166
local SelectHintHex = 7309478 -- 1167
local SelectOpenBgHex = 1919610 -- 1168
local SelectOpenFgHex = 15398143 -- 1169
local SelectLockedBgHex = 1383204 -- 1170
local SelectLockedFgHex = 6912140 -- 1171
local SelectBorderHex = 4157096 -- 1172
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 1175
	if value < lo then -- 1175
		return lo -- 1176
	end -- 1176
	if value > hi then -- 1176
		return hi -- 1177
	end -- 1177
	return value -- 1178
end -- 1175
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 1182
	if result == "success" then -- 1182
		return "借力成功" -- 1183
	end -- 1183
	if result == "crashed" then -- 1183
		return "信号中断" -- 1184
	end -- 1184
	return "错过目标" -- 1185
end -- 1182
--- 三态说明句（逐字）。
local function resultBody(result) -- 1189
	if result == "success" then -- 1189
		return "行星把探测器甩了出去，速度够了。" -- 1190
	end -- 1190
	if result == "crashed" then -- 1190
		return "探测器撞上行星，任务到此为止。" -- 1191
	end -- 1191
	return "从行星身侧掠过，没能借到那一点速度。" -- 1192
end -- 1189
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 1196
	if result == "success" then -- 1196
		return TitleSuccessHex -- 1197
	end -- 1197
	if result == "crashed" then -- 1197
		return TitleCrashedHex -- 1198
	end -- 1198
	return TitleMissedHex -- 1199
end -- 1196
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 1208
	if result == "success" then -- 1208
		return "下一关已解锁" -- 1209
	end -- 1209
	return "可重试本关，或返回关卡选择" -- 1210
end -- 1208
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 1255
	local root = createPanel( -- 1261
		parent, -- 1261
		viewW, -- 1261
		viewH, -- 1261
		ResultBackdropHex, -- 1261
		{alpha = 0.78} -- 1261
	) -- 1261
	local cardW = clampNumber(viewW * 0.9, 360, 560) -- 1263
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 480) -- 1264
	local btnH = clampNumber(viewH * 0.08, 48, 60) -- 1265
	local padX = (cardW - btnW) / 2 -- 1266
	local padY = 28 -- 1267
	local fontLevel = 24 -- 1269
	local fontRockets = 38 -- 1270
	local fontTitle = 30 -- 1271
	local fontTelemetry = 19 -- 1272
	local fontChallenge = 18 -- 1273
	local fontTotal = 20 -- 1274
	local btnFont = 24 -- 1275
	local rowGap = 12 -- 1276
	local hLevel = 28 -- 1278
	local hRockets = 42 -- 1279
	local hTitle = 34 -- 1280
	local hTelemetry = 24 -- 1281
	local hChallengeRow = 30 -- 1282
	local hChallenges = hChallengeRow * 3 -- 1283
	local hTotal = 24 -- 1284
	local cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7 -- 1286
	if cardH > viewH - 24 then -- 1286
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 1288
		cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7 -- 1289
	end -- 1289
	local card = createPanel( -- 1292
		root, -- 1292
		cardW, -- 1292
		cardH, -- 1292
		ResultCardHex, -- 1292
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 1292
	) -- 1292
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 1297
	local cursor = cardH - padY -- 1300
	cursor = cursor - hLevel -- 1302
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 1303
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 1304
	cursor = cursor - (rowGap + hRockets) -- 1306
	local rocketsLabel = createLabel(card, "", fontRockets, 16762939) -- 1307
	setLabelCenter(rocketsLabel, cardW / 2, cursor + hRockets / 2) -- 1308
	cursor = cursor - (rowGap + hTitle) -- 1310
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 1311
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 1312
	cursor = cursor - (rowGap + hTelemetry) -- 1314
	local telemetryLabel = createLabel(card, "", fontTelemetry, ResultHintHex) -- 1315
	setLabelCenter(telemetryLabel, cardW / 2, cursor + hTelemetry / 2) -- 1316
	cursor = cursor - rowGap -- 1318
	local challengeLabels = {} -- 1319
	do -- 1319
		local k = 0 -- 1320
		while k < 3 do -- 1320
			cursor = cursor - hChallengeRow -- 1321
			local cl = createLabel(card, "", fontChallenge, 10405355) -- 1322
			if cl ~= nil then -- 1322
				cl.textWidth = cardW - 60 -- 1324
				setLabelCenter(cl, cardW / 2, cursor + hChallengeRow / 2) -- 1325
				challengeLabels[#challengeLabels + 1] = cl -- 1326
			end -- 1326
			k = k + 1 -- 1320
		end -- 1320
	end -- 1320
	cursor = cursor - (rowGap + hTotal) -- 1330
	local totalLabel = createLabel(card, "", fontTotal, 16766073) -- 1331
	setLabelCenter(totalLabel, cardW / 2, cursor + hTotal / 2) -- 1332
	cursor = cursor - (rowGap + btnH) -- 1334
	local retryButton = createButton(card, { -- 1335
		w = btnW, -- 1336
		h = btnH, -- 1337
		text = "重试本关", -- 1338
		fontSize = btnFont, -- 1339
		bgHex = ResultButtonBgHex, -- 1340
		fgHex = ResultButtonFgHex, -- 1341
		borderHex = ResultButtonBorderHex, -- 1342
		fireOn = "press", -- 1343
		onTap = opts.onRetry -- 1344
	}) -- 1344
	retryButton.root.position = Vec2(padX, cursor) -- 1346
	cursor = cursor - (14 + btnH) -- 1348
	local backButton = createButton(card, { -- 1349
		w = btnW, -- 1350
		h = btnH, -- 1351
		text = "返回关卡选择", -- 1352
		fontSize = btnFont, -- 1353
		bgHex = ResultButtonAltBgHex, -- 1354
		fgHex = ResultButtonFgHex, -- 1355
		borderHex = ResultButtonBorderHex, -- 1356
		fireOn = "press", -- 1357
		onTap = opts.onBackToSelect -- 1358
	}) -- 1358
	backButton.root.position = Vec2(padX, cursor) -- 1360
	root.visible = false -- 1362
	retryButton:setEnabled(false) -- 1363
	backButton:setEnabled(false) -- 1364
	return { -- 1366
		root = root, -- 1367
		show = function(____, result, levelName, detail) -- 1368
			retryButton:setEnabled(true) -- 1369
			backButton:setEnabled(true) -- 1370
			setLabelText(levelLabel, levelName) -- 1371
			setLabelText( -- 1372
				titleLabel, -- 1372
				resultTitle(result) -- 1372
			) -- 1372
			setLabelColor( -- 1373
				titleLabel, -- 1373
				resultTitleColor(result) -- 1373
			) -- 1373
			if detail ~= nil then -- 1373
				if detail.completionOnly == true then -- 1373
					setLabelText( -- 1376
						titleLabel, -- 1376
						result == "success" and "引力借力完成" or resultTitle(result) -- 1376
					) -- 1376
				end -- 1376
				local rCount = detail.rocketsGot -- 1377
				local rStr = "☆  ☆  ☆" -- 1378
				if rCount == 1 then -- 1378
					rStr = "★  ☆  ☆" -- 1379
				elseif rCount == 2 then -- 1379
					rStr = "★  ★  ☆" -- 1380
				elseif rCount >= 3 then -- 1380
					rStr = "★  ★  ★" -- 1381
				end -- 1381
				setLabelText(rocketsLabel, detail.completionOnly == true and (result == "success" and "目标已完成" or "再试一次") or rStr) -- 1382
				setLabelColor(rocketsLabel, rCount > 0 and 16762939 or 6322324) -- 1383
				local pct = detail.dvBudget > 0 and math.floor(detail.burnDv / detail.dvBudget * 100) or 0 -- 1385
				local telemText = ((((((("点火消耗 Δv: " .. __TS__NumberToFixed(detail.burnDv, 2)) .. " / ") .. __TS__NumberToFixed(detail.dvBudget, 2)) .. " (") .. __TS__NumberToFixed(pct, 0)) .. "%) · 用时: ") .. __TS__NumberToFixed(detail.flightTime, 1)) .. "s" -- 1386
				setLabelText(telemetryLabel, telemText) -- 1387
				do -- 1387
					local k = 0 -- 1389
					while k < 3 do -- 1389
						if challengeLabels[k + 1] ~= nil then -- 1389
							if k < #detail.challenges then -- 1389
								local ok = detail.achieved[k + 1] -- 1392
								local icon = ok and "★" or "☆" -- 1393
								local rank = k == 0 and "一星" or (k == 1 and "二星" or "三星") -- 1394
								local text = detail.completionOnly == true and (ok and "目标完成 · 记录已保存" or "尚未完成目标") or (((icon .. " [") .. rank) .. "] ") .. detail.challenges[k + 1] -- 1395
								setLabelText(challengeLabels[k + 1], text) -- 1396
								setLabelColor(challengeLabels[k + 1], ok and 16762939 or 6322324) -- 1397
								challengeLabels[k + 1].visible = true -- 1398
							else -- 1398
								challengeLabels[k + 1].visible = false -- 1400
							end -- 1400
						end -- 1400
						k = k + 1 -- 1389
					end -- 1389
				end -- 1389
				setLabelText( -- 1405
					totalLabel, -- 1405
					((("全深空火箭勋章: " .. __TS__NumberToFixed(detail.totalRockets, 0)) .. " / ") .. __TS__NumberToFixed(detail.totalPossibleRockets, 0)) .. " ★" -- 1405
				) -- 1405
				if totalLabel ~= nil then -- 1405
					totalLabel.visible = detail.completionOnly ~= true -- 1406
				end -- 1406
			else -- 1406
				setLabelText(rocketsLabel, result == "success" and "★  ☆  ☆" or "☆  ☆  ☆") -- 1408
				setLabelColor(rocketsLabel, result == "success" and 16762939 or 6322324) -- 1409
				setLabelText( -- 1410
					telemetryLabel, -- 1410
					resultBody(result) -- 1410
				) -- 1410
				do -- 1410
					local k = 0 -- 1411
					while k < #challengeLabels do -- 1411
						challengeLabels[k + 1].visible = false -- 1411
						k = k + 1 -- 1411
					end -- 1411
				end -- 1411
				if totalLabel ~= nil then -- 1411
					totalLabel.visible = false -- 1412
				end -- 1412
			end -- 1412
			root.visible = true -- 1414
		end, -- 1368
		hide = function() -- 1416
			root.visible = false -- 1417
			retryButton:setEnabled(false) -- 1418
			backButton:setEnabled(false) -- 1419
		end -- 1416
	} -- 1416
end -- 1255
local FinaleBackdropHex = 329484 -- 1434
local FinaleMainHex = 15398143 -- 1435
local FinaleSubHex = 10470632 -- 1436
--- 终章主文案（逐字；改之前先改 PLAN S3.18 与 docs/开发手册.md）。
____exports.FinaleMainText = "这就是我们整颗星球的样子 —— 而你已经从那里飞到了这里。" -- 1441
--- 终章小字：飞行距离 / 用时（纯函数，可单测）。
-- 
-- 距离是**平面单位**（关卡尺度，不是公里）—— 别在这里换算成天文单位，
-- 那一换就得把整条注释重写一遍，而玩家要的只是「飞了多远、花了多久」。
function ____exports.finaleSubtitle(distance, time) -- 1449
	return ((("飞行 " .. __TS__NumberToFixed(distance, 0)) .. " 单位 · 用时 ") .. __TS__NumberToFixed(time, 1)) .. " 秒" -- 1450
end -- 1449
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
function ____exports.createFinalePanel(parent, viewW, viewH, opts) -- 1480
	local root = createPanel( -- 1486
		parent, -- 1486
		viewW, -- 1486
		viewH, -- 1486
		FinaleBackdropHex, -- 1486
		{alpha = 0.55} -- 1486
	) -- 1486
	local fontMain = 34 -- 1488
	local fontSub = 30 -- 1489
	local btnFont = 40 -- 1490
	local mainLabel = createLabel(root, ____exports.FinaleMainText, fontMain, FinaleMainHex) -- 1492
	if mainLabel ~= nil then -- 1492
		mainLabel.textWidth = viewW * 0.88 -- 1495
		setLabelCenter(mainLabel, viewW / 2, viewH * 0.8) -- 1496
	end -- 1496
	local subLabel = createLabel(root, "", fontSub, FinaleSubHex) -- 1499
	if subLabel ~= nil then -- 1499
		setLabelCenter(subLabel, viewW / 2, viewH * 0.71) -- 1500
	end -- 1500
	local btnW = clampNumber(viewW * 0.62, MinButtonWidth, 560) -- 1502
	local btnH = clampNumber(viewH * 0.085, MinButtonHeight, 120) -- 1503
	local backButton = createButton(root, { -- 1504
		w = btnW, -- 1505
		h = btnH, -- 1506
		text = "返回关卡选择", -- 1507
		fontSize = btnFont, -- 1508
		bgHex = ResultButtonBgHex, -- 1509
		fgHex = ResultButtonFgHex, -- 1510
		borderHex = ResultButtonBorderHex, -- 1511
		fireOn = "press", -- 1513
		onTap = opts.onBackToSelect -- 1514
	}) -- 1514
	backButton.root.position = Vec2((viewW - btnW) / 2, 110) -- 1516
	root.visible = false -- 1518
	backButton:setEnabled(false) -- 1520
	return { -- 1522
		root = root, -- 1523
		show = function(____, main, sub) -- 1524
			setLabelText(mainLabel, main) -- 1525
			setLabelText(subLabel, sub) -- 1526
			backButton:setEnabled(true) -- 1527
			root.visible = true -- 1528
		end, -- 1524
		hide = function() -- 1530
			root.visible = false -- 1531
			backButton:setEnabled(false) -- 1533
		end -- 1530
	} -- 1530
end -- 1480
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 1572
	local root = createPanel( -- 1578
		parent, -- 1578
		viewW, -- 1578
		viewH, -- 1578
		SelectBackdropHex, -- 1578
		{alpha = 0.9} -- 1578
	) -- 1578
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 1580
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 1581
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 1583
	setLabelCenter( -- 1584
		subtitleLabel, -- 1584
		viewW / 2, -- 1584
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 1584
	) -- 1584
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 1586
	setLabelCenter( -- 1587
		hintLabel, -- 1587
		viewW / 2, -- 1587
		clampNumber(viewH * 0.045, 36, 90) -- 1587
	) -- 1587
	local count = #opts.levels -- 1589
	local cols = viewH > viewW and 2 or 1 -- 1592
	local rows = math.max( -- 1593
		1, -- 1593
		math.ceil(count / cols) -- 1593
	) -- 1593
	local gap = 18 -- 1594
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 1595
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 1596
	local availW = viewW * 0.84 -- 1597
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 1598
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 1599
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 1600
	local gridW = cols * btnW + gap * (cols - 1) -- 1601
	local topY = viewH - headerH -- 1602
	local buttons = {} -- 1604
	do -- 1604
		local i = 0 -- 1605
		while i < count do -- 1605
			local index = i -- 1607
			local button = createButton( -- 1608
				root, -- 1608
				{ -- 1608
					w = btnW, -- 1609
					h = btnH, -- 1610
					text = opts.levels[index + 1].name, -- 1611
					fontSize = 38, -- 1612
					bgHex = SelectLockedBgHex, -- 1613
					fgHex = SelectLockedFgHex, -- 1614
					borderHex = SelectBorderHex, -- 1615
					fireOn = "press", -- 1617
					onTap = function() return opts:onPick(index) end -- 1618
				} -- 1618
			) -- 1618
			local col = index % cols -- 1620
			local rowIndex = math.floor(index / cols) -- 1621
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 1622
			buttons[#buttons + 1] = button -- 1626
			i = i + 1 -- 1605
		end -- 1605
	end -- 1605
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 1632
		root, -- 1633
		{ -- 1633
			w = clampNumber(viewW * 0.36, 180, 300), -- 1634
			h = MinButtonHeight, -- 1635
			text = "重看开场", -- 1636
			fontSize = 30, -- 1637
			bgHex = SelectLockedBgHex, -- 1638
			fgHex = SelectSubtitleHex, -- 1639
			borderHex = SelectBorderHex, -- 1640
			fireOn = "press", -- 1641
			onTap = function() -- 1642
				if opts.onReplayIntro ~= nil then -- 1642
					opts:onReplayIntro() -- 1643
				end -- 1643
			end -- 1642
		} -- 1642
	) or nil -- 1642
	if replayButton ~= nil then -- 1642
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 1648
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 1649
		replayButton.root.position = Vec2( -- 1650
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 1650
			by -- 1650
		) -- 1650
	end -- 1650
	root.visible = false -- 1653
	do -- 1653
		local i = 0 -- 1654
		while i < count do -- 1654
			buttons[i + 1]:setEnabled(false) -- 1654
			i = i + 1 -- 1654
		end -- 1654
	end -- 1654
	if replayButton ~= nil then -- 1654
		replayButton:setEnabled(false) -- 1655
	end -- 1655
	return { -- 1657
		root = root, -- 1658
		show = function(____, unlocked) -- 1659
			local maxUnlocked = clampNumber( -- 1660
				math.floor(unlocked), -- 1660
				0, -- 1660
				count - 1 -- 1660
			) -- 1660
			setLabelText( -- 1661
				subtitleLabel, -- 1661
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 1661
			) -- 1661
			do -- 1661
				local i = 0 -- 1662
				while i < count do -- 1662
					local button = buttons[i + 1] -- 1663
					local open = i <= maxUnlocked -- 1664
					button:setEnabled(open) -- 1665
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 1666
					if open then -- 1666
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 1667
					else -- 1667
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 1668
					end -- 1668
					i = i + 1 -- 1662
				end -- 1662
			end -- 1662
			root.visible = true -- 1670
			if replayButton ~= nil then -- 1670
				replayButton:setEnabled(true) -- 1671
			end -- 1671
		end, -- 1659
		hide = function() -- 1673
			root.visible = false -- 1674
			do -- 1674
				local i = 0 -- 1676
				while i < count do -- 1676
					buttons[i + 1]:setEnabled(false) -- 1676
					i = i + 1 -- 1676
				end -- 1676
			end -- 1676
			if replayButton ~= nil then -- 1676
				replayButton:setEnabled(false) -- 1677
			end -- 1677
		end -- 1673
	} -- 1673
end -- 1572
return ____exports -- 1572