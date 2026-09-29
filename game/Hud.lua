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
function ____exports.createAimInput(parent, viewW, viewH, maxSpeed, minSpeed, speedChoices, transferTutorial, transferMode) -- 343
	if transferTutorial == nil then -- 343
		transferTutorial = false -- 353
	end -- 353
	if transferMode == nil then -- 353
		transferMode = "lunar" -- 354
	end -- 354
	local datePlate, dateLabel -- 354
	local speedMin = minSpeed ~= nil and minSpeed >= 0 and minSpeed < (maxSpeed ~= nil and maxSpeed or AimMaxSpeed) and minSpeed or AimMinSpeed -- 356
	local speedTop = maxSpeed ~= nil and maxSpeed > speedMin and maxSpeed or AimMaxSpeed -- 358
	local root = Node() -- 359
	root.size = Size(viewW, viewH) -- 360
	root.anchor = Vec2(0, 0) -- 366
	root.position = Vec2(0, 0) -- 367
	local controls = {} -- 368
	local function makeHudButton(parent, opts) -- 369
		local button = createButton(parent, opts) -- 370
		controls[#controls + 1] = button -- 371
		return button -- 372
	end -- 369
	local touchLayer = Node() -- 376
	touchLayer.size = Size(viewW, viewH) -- 377
	touchLayer.anchor = Vec2(0.5, 0.5) -- 378
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 379
	touchLayer.order = -100 -- 383
	touchLayer.swallowTouches = true -- 384
	root:addChild(touchLayer) -- 385
	local space = {viewW = viewW, viewH = viewH} -- 387
	local TimeBtnW = 72 -- 388
	local TimeBtnH = 72 -- 389
	local TimeRowY = 176 -- 390
	local enabled = false -- 392
	local observing = false -- 393
	local dragging = false -- 394
	--- 整屏瞄准（2D 模式）；由 Game 按视图状态同步。
	local fullScreenAim = false -- 396
	local aim = {velocity = {x = 0, y = -speedMin}, power = 0, unit = {x = 0, y = -1}} -- 397
	local probeOffset = {x = 0, y = 0} -- 400
	local dragHandler = nil -- 402
	local readyHandler = nil -- 403
	local observeHandler = nil -- 404
	local zoomHandler = nil -- 405
	local launchHandler = nil -- 406
	local skipTourHandler = nil -- 407
	local tourActiveChecker = nil -- 408
	local pressOffset = {x = 0, y = 0} -- 419
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 422
		aim = ____exports.computeAim( -- 423
			{x = 0, y = 0}, -- 423
			delta, -- 423
			AimMaxDragPx, -- 423
			speedTop, -- 423
			speedMin -- 423
		) -- 423
		if dragHandler ~= nil then -- 423
			dragHandler(aim) -- 424
		end -- 424
	end -- 422
	local aimRadius = math.max(96, viewW * 0.25) -- 431
	local mode = "none" -- 432
	local observeLast = {x = 0, y = 0} -- 433
	local function hitsTimeControls(____local) -- 434
		local left = 24 - 8 -- 435
		local right = 24 + (TimeBtnW + 8) * 2 + TimeBtnW + 8 -- 436
		return ____local.x >= left and ____local.x <= right and ____local.y >= TimeRowY - 8 and ____local.y <= TimeRowY + TimeBtnH + 8 -- 437
	end -- 434
	local function hitsHudControls(____local) -- 439
		for ____, b in ipairs(controls) do -- 440
			do -- 440
				local n = b.root -- 441
				if not n.visible then -- 441
					goto __continue21 -- 442
				end -- 442
				if ____local.x >= n.position.x - 4 and ____local.x <= n.position.x + n.width + 4 and ____local.y >= n.position.y - 4 and ____local.y <= n.position.y + n.height + 4 then -- 442
					return true -- 443
				end -- 443
			end -- 443
			::__continue21:: -- 443
		end -- 443
		return false -- 445
	end -- 439
	touchLayer:onTapBegan(function(touch) -- 447
		if not enabled then -- 447
			return -- 448
		end -- 448
		if hitsTimeControls({x = touch.location.x, y = touch.location.y}) or hitsHudControls({x = touch.location.x, y = touch.location.y}) then -- 448
			mode = "none" -- 452
			dragging = false -- 453
			return -- 454
		end -- 454
		if tourActiveChecker ~= nil and tourActiveChecker() and skipTourHandler ~= nil then -- 454
			skipTourHandler() -- 457
			return -- 458
		end -- 458
		local at = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 460
		local dx = at.x - probeOffset.x -- 461
		local dy = at.y - probeOffset.y -- 462
		if not observing and (fullScreenAim or math.sqrt(dx * dx + dy * dy) <= aimRadius) then -- 462
			mode = "aim" -- 464
			dragging = true -- 465
			pressOffset = at -- 466
			handleDelta({x = 0, y = 0}) -- 468
		else -- 468
			mode = "observe" -- 470
			observeLast = at -- 471
		end -- 471
	end) -- 447
	touchLayer:onTapMoved(function(touch) -- 475
		if not enabled then -- 475
			return -- 476
		end -- 476
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 477
		if mode == "aim" and dragging then -- 477
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 479
		elseif mode == "observe" then -- 479
			if observeHandler ~= nil then -- 479
				observeHandler(cur.x - observeLast.x, cur.y - observeLast.y) -- 482
			end -- 482
			observeLast = cur -- 483
		end -- 483
	end) -- 475
	touchLayer:onTapEnded(function(touch) -- 487
		if not enabled then -- 487
			return -- 488
		end -- 488
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 489
		if mode == "aim" then -- 489
			dragging = false -- 491
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 492
			if readyHandler ~= nil then -- 492
				readyHandler(aim) -- 494
			end -- 494
		end -- 494
		mode = "none" -- 496
	end) -- 487
	touchLayer:onGesture(function(_center, numFingers, deltaDist, _deltaAngle) -- 500
		if not enabled or numFingers < 2 then -- 500
			return -- 501
		end -- 501
		if mode == "aim" then -- 501
			return -- 502
		end -- 502
		if zoomHandler ~= nil then -- 502
			zoomHandler(deltaDist) -- 503
		end -- 503
	end) -- 500
	touchLayer:onMouseWheel(function(delta) -- 505
		if enabled and observing and zoomHandler ~= nil then -- 505
			zoomHandler(delta.y * 60) -- 506
		end -- 506
	end) -- 505
	touchLayer.touchEnabled = false -- 514
	createPanel( -- 520
		root, -- 520
		220, -- 520
		50, -- 520
		658964, -- 520
		{alpha = 0.45} -- 520
	) -- 520
	local orbitName = transferMode == "inward" and "近日点" or (transferMode == "outward" and "远日点" or "远地点高度") -- 521
	local dvLabel = createLabel(root, transferTutorial and "拖动调整" .. orbitName or "Δv — / —", transferTutorial and 22 or 30, ResultHintHex) -- 522
	if dvLabel ~= nil then -- 522
		dvLabel.position = Vec2(24, viewH - (transferTutorial and 130 or 44)) -- 524
		dvLabel.anchor = Vec2(0, 0) -- 525
	end -- 525
	local warpHandler = nil -- 535
	local dateSpan = 0 -- 536
	--- 这一关有时间轴**且**当前相态允许改日期（Flying/Result 时必须是 false）。
	local warpOn = true -- 543
	local warpVisible = true -- 544
	--- 相态是否允许改日期（由主循环每帧 setTimeEnabled 同步）。
	local warpAllowed = true -- 546
	--- 上次写进日期的文字（避免每帧重设 Label 文本）。
	local lastDateText = "" -- 548
	--- >0 = 正在按住这个方向（-1 回退 / +1 加速）；0 = 没按住。
	local warpHoldDir = 0 -- 550
	--- 距离下一次连按还有多久（秒）。
	local warpRepeatIn = 0 -- 552
	local WarpButtonW = 72 -- 553
	local WarpButtonH = 72 -- 554
	local warpButtons = {} -- 555
	local function applyWarpState() -- 556
		local vis = dateSpan > 0 -- 557
		local on = vis and warpAllowed -- 558
		if vis == warpVisible and on == warpOn then -- 558
			return -- 559
		end -- 559
		warpVisible = vis -- 560
		warpOn = on -- 561
		if not on then -- 561
			warpHoldDir = 0 -- 562
		end -- 562
		for ____, b in ipairs(warpButtons) do -- 563
			b.root.visible = vis -- 564
			b:setEnabled(on) -- 565
		end -- 565
		if dateLabel ~= nil then -- 565
			dateLabel.visible = vis -- 567
		end -- 567
		datePlate.visible = vis -- 568
	end -- 556
	local function makeWarpButton(text, dir, x) -- 570
		local btn = makeHudButton( -- 571
			root, -- 571
			{ -- 571
				w = WarpButtonW, -- 572
				h = WarpButtonH, -- 573
				text = text, -- 574
				fontSize = 30, -- 575
				bgHex = ResultButtonAltBgHex, -- 576
				fgHex = ResultButtonFgHex, -- 577
				borderHex = ResultButtonBorderHex, -- 578
				onTap = function() -- 581
				end, -- 581
				onPressBegan = function() -- 582
					print((("[escape-velocity] warp press dir=" .. __TS__NumberToFixed(dir, 0)) .. " on=") .. (warpOn and "1" or "0")) -- 584
					if not warpOn then -- 584
						return -- 585
					end -- 585
					if warpHoldDir == dir then -- 585
						return -- 587
					end -- 587
					warpHoldDir = dir -- 588
					warpRepeatIn = WarpHoldDelaySec -- 589
					if warpHandler ~= nil then -- 589
						warpHandler(dir) -- 590
					end -- 590
				end, -- 582
				onPressEnded = function() -- 592
					print((("[escape-velocity] warp release dir=" .. __TS__NumberToFixed(dir, 0)) .. " hold=") .. __TS__NumberToFixed(warpHoldDir, 0)) -- 593
					if warpHoldDir == dir then -- 593
						warpHoldDir = 0 -- 595
					end -- 595
				end -- 592
			} -- 592
		) -- 592
		btn.root.position = Vec2(x, viewH - 96 - WarpButtonH) -- 601
		warpButtons[#warpButtons + 1] = btn -- 602
	end -- 570
	local warpLeftX = viewW - (WarpButtonW * 2 + 8) - 20 -- 604
	makeWarpButton("◀ 回退", -1, warpLeftX) -- 605
	makeWarpButton("加速 ▶", 1, warpLeftX + WarpButtonW + 8) -- 606
	datePlate = createPanel( -- 608
		root, -- 608
		300, -- 608
		50, -- 608
		658964, -- 608
		{alpha = 0.45} -- 608
	) -- 608
	datePlate.position = Vec2(warpLeftX - 316, viewH - 96 - WarpButtonH + 8) -- 609
	dateLabel = createLabel(root, "发射日期 —", 30, ResultHintHex) -- 610
	if dateLabel ~= nil then -- 610
		dateLabel.anchor = Vec2(1, 0) -- 615
		dateLabel.position = Vec2(warpLeftX - 16, viewH - 96 - WarpButtonH + 18) -- 616
	end -- 616
	local QuickRetryW = 72 -- 620
	local QuickRetryH = 72 -- 621
	local quickRetryHandler = nil -- 622
	local quickRetryBtn = makeHudButton( -- 623
		root, -- 623
		{ -- 623
			w = QuickRetryW, -- 624
			h = QuickRetryH, -- 625
			text = "", -- 626
			icon = "retry", -- 626
			fontSize = 26, -- 627
			bgHex = ResultButtonAltBgHex, -- 628
			fgHex = 16777215, -- 629
			borderHex = ResultButtonBorderHex, -- 630
			fireOn = "press", -- 631
			onTap = function() -- 632
				print("[escape-velocity] quick retry tapped") -- 633
				if quickRetryHandler ~= nil then -- 633
					quickRetryHandler() -- 634
				end -- 634
			end -- 632
		} -- 632
	) -- 632
	quickRetryBtn.root.position = Vec2(viewW - QuickRetryW - 20, viewH - QuickRetryH - 20) -- 637
	local starPlateW = 180 -- 640
	local starPlateH = 46 -- 641
	local starPlate = createPanel( -- 642
		root, -- 642
		starPlateW, -- 642
		starPlateH, -- 642
		658964, -- 642
		{alpha = 0.55} -- 642
	) -- 642
	starPlate.position = Vec2(viewW - starPlateW - 24, viewH - 164) -- 643
	starPlate.visible = not transferTutorial -- 644
	local starStatusLabel = createLabel(root, "☆ ☆ ☆", 30, 16766720) -- 645
	local bonusToastLabel = createLabel(root, "", 34, 9240475) -- 646
	if bonusToastLabel ~= nil then -- 646
		bonusToastLabel.position = Vec2(viewW / 2, viewH * 0.68) -- 647
		bonusToastLabel.visible = false -- 647
	end -- 647
	if starStatusLabel ~= nil then -- 647
		starStatusLabel.anchor = Vec2(0.5, 0.5) -- 649
		starStatusLabel.position = Vec2(viewW - starPlateW / 2 - 24, viewH - 141) -- 650
	end -- 650
	local function updateStarsStatus(count) -- 652
		if starStatusLabel == nil then -- 652
			return -- 653
		end -- 653
		if transferTutorial then -- 653
			starStatusLabel.visible = false -- 654
			return -- 654
		end -- 654
		local s = "☆ ☆ ☆" -- 655
		if count == 1 then -- 655
			s = "★ ☆ ☆" -- 656
		elseif count == 2 then -- 656
			s = "★ ★ ☆" -- 657
		elseif count >= 3 then -- 657
			s = "★ ★ ★" -- 658
		end -- 658
		setLabelText(starStatusLabel, s) -- 659
	end -- 652
	local function updateBonusStatus(got, total) -- 661
		if starStatusLabel == nil then -- 661
			return -- 662
		end -- 662
		starPlate.visible = total > 0 -- 663
		starStatusLabel.visible = total > 0 -- 664
		if total > 0 then -- 664
			setLabelText( -- 665
				starStatusLabel, -- 665
				(("火箭 " .. __TS__NumberToFixed(got, 0)) .. " / ") .. __TS__NumberToFixed(total, 0) -- 665
			) -- 665
		end -- 665
	end -- 661
	local LaunchButtonW = 72 -- 670
	local LaunchButtonH = 72 -- 671
	local launchButton = makeHudButton( -- 672
		root, -- 672
		{ -- 672
			w = LaunchButtonW, -- 673
			h = LaunchButtonH, -- 674
			text = "", -- 675
			icon = "launch", -- 675
			fontSize = 38, -- 676
			bgHex = ResultButtonBgHex, -- 677
			fgHex = ResultButtonFgHex, -- 678
			borderHex = ResultButtonBorderHex, -- 679
			fireOn = "press", -- 680
			onTap = function() -- 681
				print("[escape-velocity] launch button fire (press)") -- 682
				if launchHandler ~= nil then -- 682
					launchHandler() -- 683
				end -- 683
			end -- 681
		} -- 681
	) -- 681
	launchButton.root.position = Vec2(viewW - LaunchButtonW - 24, 96) -- 686
	launchButton.root.visible = false -- 687
	launchButton:setEnabled(false) -- 688
	local CancelButtonW = 72 -- 691
	local CancelButtonH = 72 -- 692
	local cancelAimHandler = nil -- 693
	local cancelAimButton = makeHudButton( -- 694
		root, -- 694
		{ -- 694
			w = CancelButtonW, -- 695
			h = CancelButtonH, -- 696
			text = "", -- 697
			icon = "cancel", -- 697
			fontSize = 28, -- 698
			bgHex = ResultButtonAltBgHex, -- 699
			fgHex = ResultButtonFgHex, -- 700
			borderHex = ResultButtonBorderHex, -- 701
			fireOn = "press", -- 702
			onTap = function() -- 703
				print("[escape-velocity] cancel aim fire (press)") -- 704
				if cancelAimHandler ~= nil then -- 704
					cancelAimHandler() -- 705
				end -- 705
			end -- 703
		} -- 703
	) -- 703
	cancelAimButton.root.position = Vec2(viewW - LaunchButtonW - CancelButtonW - 32, 96) -- 708
	cancelAimButton.root.visible = false -- 709
	cancelAimButton:setEnabled(false) -- 710
	local ViewButtonW = 72 -- 714
	local ViewButtonH = 72 -- 715
	local viewHandler = nil -- 716
	local viewButton = makeHudButton( -- 717
		root, -- 717
		{ -- 717
			w = ViewButtonW, -- 718
			h = ViewButtonH, -- 719
			text = "3D", -- 720
			fontSize = 26, -- 721
			bgHex = ResultButtonAltBgHex, -- 722
			fgHex = ResultButtonFgHex, -- 723
			borderHex = ResultButtonBorderHex, -- 724
			fireOn = "press", -- 725
			onTap = function() -- 726
				print("[escape-velocity] view toggle fire (press)") -- 727
				if viewHandler ~= nil then -- 727
					viewHandler() -- 728
				end -- 728
			end -- 726
		} -- 726
	) -- 726
	viewButton.root.position = Vec2(viewW - ViewButtonW - 24, 96 + LaunchButtonH + 8) -- 731
	--- 上次写进按钮的文字（每帧都会被 setViewMode 调用，没变就别碰 Label）。
	local lastViewText = "2D" -- 733
	local cameraFocusHandler = nil -- 736
	local endViewingHandler = nil -- 737
	local cameraFocusButton = transferTutorial and makeHudButton( -- 738
		root, -- 738
		{ -- 738
			w = 144, -- 739
			h = 72, -- 739
			text = "自动", -- 739
			icon = "camera", -- 739
			fontSize = 22, -- 739
			bgHex = ResultButtonAltBgHex, -- 740
			fgHex = ResultButtonFgHex, -- 740
			borderHex = ResultButtonBorderHex, -- 740
			fireOn = "press", -- 740
			onTap = function() -- 741
				if cameraFocusHandler ~= nil then -- 741
					cameraFocusHandler() -- 741
				end -- 741
			end -- 741
		} -- 741
	) or nil -- 741
	local endViewingButton = transferTutorial and makeHudButton( -- 743
		root, -- 743
		{ -- 743
			w = 72, -- 744
			h = 72, -- 744
			text = "", -- 744
			icon = "stop", -- 744
			fontSize = 26, -- 744
			bgHex = ResultButtonAltBgHex, -- 745
			fgHex = ResultButtonFgHex, -- 745
			borderHex = ResultButtonBorderHex, -- 745
			fireOn = "press", -- 745
			onTap = function() -- 746
				if endViewingHandler ~= nil then -- 746
					endViewingHandler() -- 746
				end -- 746
			end -- 746
		} -- 746
	) or nil -- 746
	if cameraFocusButton ~= nil then -- 746
		cameraFocusButton.root.position = Vec2(24, 256) -- 748
		cameraFocusButton.root.visible = false -- 748
		cameraFocusButton:setEnabled(false) -- 748
	end -- 748
	if endViewingButton ~= nil then -- 748
		endViewingButton.root.position = Vec2(viewW - 96, 96) -- 749
		endViewingButton.root.visible = false -- 749
		endViewingButton:setEnabled(false) -- 749
	end -- 749
	local ____transferTutorial_0 -- 750
	if transferTutorial then -- 750
		____transferTutorial_0 = createLabel(root, "", 24, ResultHintHex) -- 750
	else -- 750
		____transferTutorial_0 = nil -- 750
	end -- 750
	local viewingLabel = ____transferTutorial_0 -- 750
	if viewingLabel ~= nil then -- 750
		viewingLabel.position = Vec2(24, viewH - 130) -- 751
		viewingLabel.anchor = Vec2(0, 0) -- 751
		viewingLabel.visible = false -- 751
	end -- 751
	local viewingKey = "" -- 752
	local ZoomBtnSize = 72 -- 755
	local zoomGap = 8 -- 756
	local zoomButtons = {} -- 757
	local zoomInHandler = nil -- 758
	local zoomOutHandler = nil -- 759
	local fitViewHandler = nil -- 760
	local function makeZoomButton(text, x, fontSize, onClick) -- 762
		local btn = makeHudButton( -- 763
			root, -- 763
			{ -- 763
				w = ZoomBtnSize, -- 764
				h = ZoomBtnSize, -- 765
				text = "", -- 766
				icon = text == "−" and "minus" or (text == "+" and "plus" or "fit"), -- 766
				fontSize = fontSize, -- 767
				bgHex = ResultButtonAltBgHex, -- 768
				fgHex = ResultButtonFgHex, -- 769
				borderHex = ResultButtonBorderHex, -- 770
				fireOn = "press", -- 771
				onTap = function() -- 772
					print(("[escape-velocity] zoom btn " .. text) .. " fire") -- 773
					onClick() -- 774
				end -- 772
			} -- 772
		) -- 772
		btn.root.position = Vec2(x, 96) -- 777
		btn.root.visible = false -- 778
		btn:setEnabled(false) -- 779
		zoomButtons[#zoomButtons + 1] = btn -- 780
		return btn -- 781
	end -- 762
	makeZoomButton( -- 783
		"−", -- 783
		24, -- 783
		32, -- 783
		function() -- 783
			if zoomOutHandler ~= nil then -- 783
				zoomOutHandler() -- 784
			end -- 784
		end -- 783
	) -- 783
	makeZoomButton( -- 786
		"FIT", -- 786
		24 + ZoomBtnSize + zoomGap, -- 786
		20, -- 786
		function() -- 786
			if fitViewHandler ~= nil then -- 786
				fitViewHandler() -- 787
			end -- 787
		end -- 786
	) -- 786
	makeZoomButton( -- 789
		"+", -- 789
		24 + (ZoomBtnSize + zoomGap) * 2, -- 789
		32, -- 789
		function() -- 789
			if zoomInHandler ~= nil then -- 789
				zoomInHandler() -- 790
			end -- 790
		end -- 789
	) -- 789
	local zoomControlsVisible = nil -- 792
	local function setZoomVisible(on) -- 793
		if zoomControlsVisible == on then -- 793
			return -- 794
		end -- 794
		zoomControlsVisible = on -- 795
		for ____, b in ipairs(zoomButtons) do -- 796
			b.root.visible = on -- 797
			b:setEnabled(on) -- 798
		end -- 798
	end -- 793
	setZoomVisible(false) -- 801
	local speedUpHandler = nil -- 807
	local speedDownHandler = nil -- 808
	local pauseHandler = nil -- 809
	local slowButton = makeHudButton( -- 811
		root, -- 811
		{ -- 811
			w = TimeBtnW, -- 812
			h = TimeBtnH, -- 812
			text = "", -- 812
			icon = "slow", -- 812
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
	slowButton.root.order = 100 -- 820
	local pauseButton = makeHudButton( -- 821
		root, -- 821
		{ -- 821
			w = TimeBtnW, -- 822
			h = TimeBtnH, -- 822
			text = "", -- 822
			icon = "pause", -- 822
			fontSize = 30, -- 822
			bgHex = ResultButtonAltBgHex, -- 823
			fgHex = ResultButtonFgHex, -- 823
			borderHex = ResultButtonBorderHex, -- 823
			onTap = function() -- 824
				print("[escape-velocity] pause toggle fire") -- 825
				if pauseHandler ~= nil then -- 825
					pauseHandler() -- 826
				end -- 826
			end -- 824
		} -- 824
	) -- 824
	pauseButton.root.position = Vec2(24 + TimeBtnW + 8, TimeRowY) -- 829
	pauseButton.root.order = 100 -- 830
	local fastButton = makeHudButton( -- 831
		root, -- 831
		{ -- 831
			w = TimeBtnW, -- 832
			h = TimeBtnH, -- 832
			text = "", -- 832
			icon = "fast", -- 832
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
	fastButton.root.order = 100 -- 840
	local timePlate = createPanel( -- 843
		root, -- 843
		300, -- 843
		50, -- 843
		658964, -- 843
		{alpha = 0.45} -- 843
	) -- 843
	timePlate.position = transferTutorial and Vec2(24, viewH - 190) or Vec2(24 + (TimeBtnW + 8) * 3 + 4, TimeRowY + 7) -- 844
	local timeLabel = createLabel(root, "1×（现实）  T+ 0:00", transferTutorial and 22 or 26, ResultHintHex) -- 845
	if timeLabel ~= nil then -- 845
		timeLabel.anchor = Vec2(0, 0) -- 847
		timeLabel.position = transferTutorial and Vec2(36, viewH - 179) or Vec2(24 + (TimeBtnW + 8) * 3 + 16, TimeRowY + 18) -- 848
	end -- 848
	--- 档位文字：pow 0 就是"1×（现实）"，别写成 1e0×。
	local function powText(pow) -- 851
		return pow <= 0 and "1×（现实）" or ("1e" .. __TS__NumberToFixed(pow, 0)) .. "×" -- 851
	end -- 851
	--- 任务时钟：真实秒 → "T+ 3天 04:12"。1× 下它每秒跳一格 —— 时间在流逝的唯一可见证据。
	local function missionText(sec) -- 853
		local s = sec > 0 and sec or 0 -- 854
		local days = math.floor(s / 86400) -- 855
		local rest = s - days * 86400 -- 856
		local hh = math.floor(rest / 3600) -- 857
		local mm = math.floor((rest - hh * 3600) / 60) -- 858
		local function pad(v) -- 859
			return (v < 10 and "0" or "") .. __TS__NumberToFixed(v, 0) -- 859
		end -- 859
		return ((("T+ " .. (days > 0 and __TS__NumberToFixed(days, 0) .. "天 " or "")) .. pad(hh)) .. ":") .. pad(mm) -- 860
	end -- 853
	local lastTimeText = "" -- 862
	local lastPaused = false -- 863
	local function setTimeControl(pow, minPow, maxPow, paused, missionSeconds, actualRate) -- 864
		local rateText = actualRate ~= nil and __TS__NumberToFixed(actualRate, actualRate > 0 and actualRate < 0.1 and 3 or 2) .. "×" or powText(pow) -- 865
		local txt = (((transferTutorial and rateText or powText(pow)) .. (paused and " 暂停" or "")) .. "  ") .. (transferTutorial and ("T+ " .. __TS__NumberToFixed(missionSeconds, 1)) .. "s" or missionText(missionSeconds)) -- 866
		if txt ~= lastTimeText then -- 866
			lastTimeText = txt -- 868
			if timeLabel ~= nil then -- 868
				timeLabel.text = txt -- 869
			end -- 869
		end -- 869
		if paused ~= lastPaused then -- 869
			lastPaused = paused -- 872
			pauseButton:setIcon(paused and "play" or "pause") -- 873
			pauseButton:setSelected(paused) -- 873
			pauseButton:setColors(paused and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 874
		end -- 874
		fastButton:setEnabled(pow < maxPow) -- 877
		slowButton:setEnabled(pow > minPow) -- 878
	end -- 864
	local DrawerW = math.max( -- 882
		1, -- 882
		math.min(380, viewW - 24) -- 882
	) -- 882
	local DrawerH = 46 -- 883
	local missionDrawerPlate = createPanel( -- 884
		root, -- 884
		DrawerW, -- 884
		DrawerH, -- 884
		658964, -- 884
		{alpha = 0.65, borderHex = 4610157} -- 884
	) -- 884
	missionDrawerPlate.position = Vec2(transferTutorial and 24 or (viewW - DrawerW) / 2, viewH - 56) -- 885
	local missionTitleLabel = createLabel(missionDrawerPlate, "", 19, 13426158) -- 886
	if missionTitleLabel ~= nil then -- 886
		missionTitleLabel.anchor = Vec2(0, 0.5) -- 888
		missionTitleLabel.position = Vec2(14, DrawerH / 2) -- 889
	end -- 889
	local missionRocketsLabel = createLabel(missionDrawerPlate, "☆  ☆  ☆", 22, 16766720) -- 891
	if missionRocketsLabel ~= nil then -- 891
		missionRocketsLabel.anchor = Vec2(1, 0.5) -- 893
		missionRocketsLabel.position = Vec2(DrawerW - 14, DrawerH / 2) -- 894
	end -- 894
	missionDrawerPlate.visible = false -- 896
	local drawerVisible = false -- 897
	local bonusToastSerial = 0 -- 898
	local drawerLevelTitle = "" -- 899
	local drawerRockets = 0 -- 900
	local liveFuelBonus = false -- 901
	local function updateDrawerDisplay() -- 903
		if missionTitleLabel ~= nil then -- 903
			setLabelText(missionTitleLabel, drawerLevelTitle) -- 905
		end -- 905
		if missionRocketsLabel ~= nil then -- 905
			local r1 = drawerRockets >= 1 and "★" or "☆" -- 908
			local r2 = (drawerRockets >= 2 or liveFuelBonus) and "★" or "☆" -- 909
			local r3 = drawerRockets >= 3 and "★" or "☆" -- 910
			setLabelText(missionRocketsLabel, transferTutorial and (drawerRockets >= 1 and "已完成" or (transferMode == "lunar" and "地月转移练习" or "日心借力练习")) or (((r1 .. "  ") .. r2) .. "  ") .. r3) -- 911
		end -- 911
	end -- 903
	local IntroBannerW = math.min(viewW - 48, 540) -- 916
	local IntroBannerH = 68 -- 917
	local introBannerPlate = createPanel( -- 918
		root, -- 918
		IntroBannerW, -- 918
		IntroBannerH, -- 918
		658964, -- 918
		{alpha = 0.8, borderHex = 4610157} -- 918
	) -- 918
	introBannerPlate.position = Vec2((viewW - IntroBannerW) / 2, 70) -- 919
	local introBannerTitle = createLabel(introBannerPlate, "", 17, 15398143) -- 920
	if introBannerTitle ~= nil then -- 920
		introBannerTitle.anchor = Vec2(0.5, 0.5) -- 922
		introBannerTitle.position = Vec2(IntroBannerW / 2, IntroBannerH * 0.65) -- 923
	end -- 923
	local introBannerHint = createLabel(introBannerPlate, "轻触屏幕任意位置跳过运镜", 13, 9283005) -- 925
	if introBannerHint ~= nil then -- 925
		introBannerHint.anchor = Vec2(0.5, 0.5) -- 927
		introBannerHint.position = Vec2(IntroBannerW / 2, IntroBannerH * 0.28) -- 928
	end -- 928
	introBannerPlate.visible = false -- 930
	local PlaybackButtonW = 72 -- 939
	local PlaybackButtonH = 72 -- 940
	local playbackGap = 10 -- 941
	local playbackButtons = {} -- 942
	local playbackSpeeds = {} -- 943
	local playbackHandler = nil -- 944
	local speedChoice = speedChoices ~= nil and #speedChoices > 0 and speedChoices or ({1, 2, 4}) -- 947
	local playbackSpeed = speedChoice[1] -- 948
	--- 已应用到节点上的显隐状态。初值 false 如实反映"建出来就隐藏"（照 warp 按钮的教训）。
	local playbackVisible = false -- 950
	local function paintPlayback() -- 951
		do -- 951
			local i = 0 -- 952
			while i < #playbackButtons do -- 952
				local on = playbackSpeeds[i + 1] == playbackSpeed -- 953
				playbackButtons[i + 1]:setColors(on and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 954
				i = i + 1 -- 952
			end -- 952
		end -- 952
	end -- 951
	local function makePlaybackButton(speed, x) -- 957
		local btn = makeHudButton( -- 958
			root, -- 958
			{ -- 958
				w = PlaybackButtonW, -- 959
				h = PlaybackButtonH, -- 960
				text = ____exports.playbackLabel(speed), -- 961
				fontSize = 30, -- 962
				bgHex = ResultButtonAltBgHex, -- 963
				fgHex = ResultButtonFgHex, -- 964
				borderHex = ResultButtonBorderHex, -- 965
				onTap = function() -- 966
					print(("[escape-velocity] playback button fire " .. __TS__NumberToFixed(speed, 0)) .. "x (release)") -- 968
					playbackSpeed = speed -- 969
					paintPlayback() -- 970
					if playbackHandler ~= nil then -- 970
						playbackHandler(speed) -- 971
					end -- 971
				end -- 966
			} -- 966
		) -- 966
		btn.root.position = Vec2(x, 96) -- 976
		playbackButtons[#playbackButtons + 1] = btn -- 977
		playbackSpeeds[#playbackSpeeds + 1] = speed -- 978
	end -- 957
	do -- 957
		local i = 0 -- 980
		while i < #speedChoice and i < 3 do -- 980
			makePlaybackButton(speedChoice[i + 1], 24 + (PlaybackButtonW + playbackGap) * i) -- 981
			i = i + 1 -- 980
		end -- 980
	end -- 980
	paintPlayback() -- 983
	for ____, b in ipairs(playbackButtons) do -- 985
		b.root.visible = false -- 986
		b:setEnabled(false) -- 987
	end -- 987
	parent:addChild(root) -- 990
	return { -- 992
		setObserveEnabled = function(____, value) -- 993
			if enabled ~= value or observing ~= value then -- 993
				mode = "none" -- 994
				dragging = false -- 994
			end -- 994
			enabled = value -- 995
			observing = value -- 995
			touchLayer.touchEnabled = value -- 995
		end, -- 993
		onDrag = function(____, callback) -- 997
			dragHandler = callback -- 998
		end, -- 997
		setEnabled = function(____, value) -- 1000
			if enabled ~= value or observing then -- 1000
				mode = "none" -- 1001
			end -- 1001
			observing = false -- 1002
			enabled = value -- 1003
			touchLayer.touchEnabled = value -- 1006
			if not value then -- 1006
				dragging = false -- 1008
			end -- 1008
		end, -- 1000
		onAimReady = function(____, callback) -- 1011
			readyHandler = callback -- 1012
		end, -- 1011
		onObserve = function(____, callback) -- 1014
			observeHandler = callback -- 1015
		end, -- 1014
		onZoom = function(____, callback) -- 1017
			zoomHandler = callback -- 1018
		end, -- 1017
		onLaunch = function(____, callback) -- 1020
			launchHandler = callback -- 1021
		end, -- 1020
		onCancelAim = function(____, callback) -- 1023
			cancelAimHandler = callback -- 1024
		end, -- 1023
		setArmed = function(____, armed) -- 1026
			launchButton.root.visible = armed -- 1027
			launchButton:setEnabled(armed) -- 1028
			cancelAimButton.root.visible = armed -- 1029
			cancelAimButton:setEnabled(armed) -- 1030
		end, -- 1026
		onViewToggle = function(____, callback) -- 1032
			viewHandler = callback -- 1033
		end, -- 1032
		onCameraFocus = function(____, callback) -- 1035
			cameraFocusHandler = callback -- 1035
		end, -- 1035
		onEndViewing = function(____, callback) -- 1036
			endViewingHandler = callback -- 1036
		end, -- 1036
		setFlightViewing = function(____, flying, completed, mode, is3D, stage) -- 1037
			if not transferTutorial then -- 1037
				return -- 1038
			end -- 1038
			local key = ((((flying and "1" or "0") .. (completed and "1" or "0")) .. mode) .. (is3D and "1" or "0")) .. (stage ~= nil and stage or "") -- 1039
			if viewingKey == key then -- 1039
				return -- 1040
			end -- 1040
			viewingKey = key -- 1041
			if dvLabel ~= nil then -- 1041
				dvLabel.visible = not flying -- 1042
			end -- 1042
			if viewingLabel ~= nil then -- 1042
				viewingLabel.visible = flying -- 1044
				local near = stage == "Mercury" and "安全飞掠水星" or (stage == "Venus" and "金星减速借力" or (stage == "Jupiter" and "木星加速借力" or (stage == "Saturn" and "土星加速借力" or (stage == "Moon" and "借月球引力 · 观察轨迹转弯" or "滑行 · 观察航线")))) -- 1045
				setLabelText(viewingLabel, completed and (transferMode == "lunar" and "掠月完成 · 继续观察返回" or "目标完成 · 继续观察航线") or (stage == "Launch" and (transferMode == "inward" and "逆行点火 · 降低近日点" or "顺行点火 · 抬高" .. orbitName) or near)) -- 1046
				setLabelColor(viewingLabel, completed and 9430458 or ResultHintHex) -- 1047
			end -- 1047
			if cameraFocusButton ~= nil then -- 1047
				cameraFocusButton.root.visible = flying and is3D -- 1050
				cameraFocusButton:setEnabled(flying and is3D) -- 1051
				local title = mode == "Mercury" and "水星" or (mode == "Auto" and "自动" or (mode == "Probe" and "探测器" or (mode == "Moon" and "月球" or (mode == "Earth" and "地球" or (mode == "Venus" and "金星" or (mode == "Jupiter" and "木星" or (mode == "Saturn" and "土星" or (mode == "Sun" and "太阳" or "总览")))))))) -- 1052
				cameraFocusButton:setText(title) -- 1053
				cameraFocusButton:setSelected(mode ~= "Auto") -- 1053
			end -- 1053
			if endViewingButton ~= nil then -- 1053
				endViewingButton.root.visible = flying and completed -- 1055
				endViewingButton:setEnabled(flying and completed) -- 1055
			end -- 1055
		end, -- 1037
		setViewMode = function(____, mode) -- 1057
			if mode == lastViewText then -- 1057
				return -- 1058
			end -- 1058
			lastViewText = mode -- 1059
			local btnText = mode == "2D" and "3D" or "2D" -- 1061
			viewButton:setText(btnText) -- 1062
		end, -- 1057
		onPlayback = function(____, callback) -- 1064
			playbackHandler = callback -- 1065
		end, -- 1064
		setPlayback = function(____, speed) -- 1067
			if speed == playbackSpeed then -- 1067
				return -- 1068
			end -- 1068
			playbackSpeed = speed -- 1069
			paintPlayback() -- 1070
		end, -- 1067
		setPlaybackVisible = function(____, on) -- 1072
			if on == playbackVisible then -- 1072
				return -- 1073
			end -- 1073
			playbackVisible = on -- 1074
			for ____, b in ipairs(playbackButtons) do -- 1075
				b.root.visible = on -- 1076
				b:setEnabled(on) -- 1077
			end -- 1077
		end, -- 1072
		setFullScreenAim = function(____, on) -- 1080
			fullScreenAim = on -- 1081
		end, -- 1080
		onWarp = function(____, callback) -- 1083
			warpHandler = callback -- 1084
		end, -- 1083
		setDate = function(____, t0, span) -- 1086
			dateSpan = span > 0 and span or 0 -- 1087
			applyWarpState() -- 1088
			local on = dateSpan > 0 -- 1089
			local text = on and (("发射日期 " .. __TS__NumberToFixed(t0, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0) or "发射日期" -- 1090
			if text ~= lastDateText then -- 1090
				lastDateText = text -- 1092
				setLabelText(dateLabel, text) -- 1093
			end -- 1093
		end, -- 1086
		setTimeEnabled = function(____, on) -- 1096
			if warpAllowed == on then -- 1096
				return -- 1097
			end -- 1097
			warpAllowed = on -- 1098
			applyWarpState() -- 1099
		end, -- 1096
		update = function(____, dt) -- 1101
			if not warpOn or warpHoldDir == 0 then -- 1101
				return -- 1102
			end -- 1102
			warpRepeatIn = warpRepeatIn - dt -- 1103
			if warpRepeatIn > 0 then -- 1103
				return -- 1104
			end -- 1104
			warpRepeatIn = TimeWarpStep / TimeWarpRate -- 1106
			if warpHandler ~= nil then -- 1106
				warpHandler(warpHoldDir) -- 1107
			end -- 1107
		end, -- 1101
		isDragging = function() return dragging end, -- 1109
		setBurnInfo = function(____, burn, budget) -- 1110
			if transferTutorial then -- 1110
				return -- 1111
			end -- 1111
			local b = budget < 1 and __TS__NumberToFixed(budget, 2) or __TS__NumberToFixed(budget, 0) -- 1115
			local v = burn < 1 and __TS__NumberToFixed(burn, 2) or __TS__NumberToFixed(burn, 1) -- 1116
			setLabelText(dvLabel, (("Δv " .. v) .. " / ") .. b) -- 1117
		end, -- 1110
		current = function() return aim end, -- 1119
		setTransferInfo = function(____, apoapsis, duration, reachable) -- 1120
			setLabelText( -- 1121
				dvLabel, -- 1121
				(((((orbitName .. " ") .. __TS__NumberToFixed(apoapsis, 0)) .. " · 点火 ") .. __TS__NumberToFixed(duration, 2)) .. "s") .. (reachable ~= nil and (reachable and (transferMode == "lunar" and " · 可减速掠月" or " · 航线可行") or " · 等待窗口") or "") -- 1121
			) -- 1121
		end, -- 1120
		setProbeOffset = function(____, offset) -- 1123
			probeOffset = offset -- 1124
		end, -- 1123
		handleLocal = function(____, ____local) -- 1128
			handleDelta(____exports.localToOffset(____local, space)) -- 1129
		end, -- 1128
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 1132
		debugProbeOffset = function() return probeOffset end, -- 1133
		onSpeedUp = function(____, callback) -- 1134
			speedUpHandler = callback -- 1135
		end, -- 1134
		onSpeedDown = function(____, callback) -- 1137
			speedDownHandler = callback -- 1138
		end, -- 1137
		onTogglePause = function(____, callback) -- 1140
			pauseHandler = callback -- 1141
		end, -- 1140
		setTimeControl = function(____, pow, minPow, maxPow, paused, missionSeconds, actualRate) -- 1143
			setTimeControl( -- 1144
				pow, -- 1144
				minPow, -- 1144
				maxPow, -- 1144
				paused, -- 1144
				missionSeconds, -- 1144
				actualRate -- 1144
			) -- 1144
		end, -- 1143
		onZoomIn = function(____, callback) -- 1146
			zoomInHandler = callback -- 1147
		end, -- 1146
		onZoomOut = function(____, callback) -- 1149
			zoomOutHandler = callback -- 1150
		end, -- 1149
		onFitView = function(____, callback) -- 1152
			fitViewHandler = callback -- 1153
		end, -- 1152
		setZoomControlsVisible = function(____, on) -- 1155
			setZoomVisible(on) -- 1156
		end, -- 1155
		setMissionDrawer = function(____, levelName, _challenges, currentRockets) -- 1158
			drawerLevelTitle = levelName -- 1159
			drawerRockets = currentRockets -- 1160
			updateDrawerDisplay() -- 1161
		end, -- 1158
		setMissionDrawerVisible = function(____, visible) -- 1163
			if drawerVisible == visible then -- 1163
				return -- 1164
			end -- 1164
			drawerVisible = visible -- 1165
			missionDrawerPlate.visible = visible -- 1166
		end, -- 1163
		setLiveFuelChallengeStatus = function(____, achieved) -- 1168
			if liveFuelBonus == achieved then -- 1168
				return -- 1169
			end -- 1169
			liveFuelBonus = achieved -- 1170
			updateDrawerDisplay() -- 1171
		end, -- 1168
		setIntroTourBanner = function(____, title, hint) -- 1173
			if introBannerTitle ~= nil then -- 1173
				setLabelText(introBannerTitle, title) -- 1174
			end -- 1174
			if introBannerHint ~= nil and hint ~= nil then -- 1174
				setLabelText(introBannerHint, hint) -- 1175
			end -- 1175
		end, -- 1173
		setIntroTourBannerVisible = function(____, visible) -- 1177
			introBannerPlate.visible = visible -- 1178
		end, -- 1177
		onSkipTour = function(____, callback) -- 1180
			skipTourHandler = callback -- 1181
		end, -- 1180
		setTourActiveChecker = function(____, fn) -- 1183
			tourActiveChecker = fn -- 1184
		end, -- 1183
		onQuickRetry = function(____, callback) -- 1186
			quickRetryHandler = callback -- 1187
		end, -- 1186
		setStarsStatus = function(____, starsGot) -- 1189
			updateStarsStatus(starsGot) -- 1190
		end, -- 1189
		setBonusStatus = function(____, got, total) -- 1192
			updateBonusStatus(got, total) -- 1192
		end, -- 1192
		setBonusFeedback = function(____, score) -- 1193
			if bonusToastLabel == nil then -- 1193
				return -- 1194
			end -- 1194
			bonusToastSerial = bonusToastSerial + 1 -- 1195
			local serial = bonusToastSerial -- 1196
			setLabelText( -- 1197
				bonusToastLabel, -- 1197
				"🚀 +" .. __TS__NumberToFixed(score, 0) -- 1197
			) -- 1197
			bonusToastLabel.visible = true -- 1198
			local elapsed = 0 -- 1199
			root:schedule(function(deltaTime) -- 1200
				elapsed = elapsed + deltaTime -- 1201
				if elapsed >= 0.6 then -- 1201
					if serial == bonusToastSerial then -- 1201
						bonusToastLabel.visible = false -- 1202
					end -- 1202
					return true -- 1202
				end -- 1202
				return false -- 1203
			end) -- 1200
		end, -- 1193
		root = root -- 1206
	} -- 1206
end -- 343
local ResultBackdropHex = 329484 -- 1223
local ResultCardHex = 1252395 -- 1224
local ResultCardBorderHex = 3362938 -- 1225
local ResultLevelHex = 9417948 -- 1226
local ResultBodyHex = 14149367 -- 1227
ResultHintHex = 8229803 -- 1228
ResultButtonBgHex = 1319732 -- 1229
ResultButtonAltBgHex = 1319732 -- 1230
ResultButtonFgHex = 15398143 -- 1231
ResultButtonBorderHex = 5143454 -- 1232
local TitleSuccessHex = 8381344 -- 1233
local TitleMissedHex = 16766073 -- 1234
local TitleCrashedHex = 16743019 -- 1235
local SelectBackdropHex = 329484 -- 1237
local SelectTitleHex = 16777215 -- 1238
local SelectSubtitleHex = 10470632 -- 1239
local SelectHintHex = 7309478 -- 1240
local SelectOpenBgHex = 1919610 -- 1241
local SelectOpenFgHex = 15398143 -- 1242
local SelectLockedBgHex = 1383204 -- 1243
local SelectLockedFgHex = 6912140 -- 1244
local SelectBorderHex = 4157096 -- 1245
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 1248
	if value < lo then -- 1248
		return lo -- 1249
	end -- 1249
	if value > hi then -- 1249
		return hi -- 1250
	end -- 1250
	return value -- 1251
end -- 1248
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 1255
	if result == "success" then -- 1255
		return "借力成功" -- 1256
	end -- 1256
	if result == "crashed" then -- 1256
		return "信号中断" -- 1257
	end -- 1257
	return "错过目标" -- 1258
end -- 1255
--- 三态说明句（逐字）。
local function resultBody(result) -- 1262
	if result == "success" then -- 1262
		return "行星把探测器甩了出去，速度够了。" -- 1263
	end -- 1263
	if result == "crashed" then -- 1263
		return "探测器撞上行星，任务到此为止。" -- 1264
	end -- 1264
	return "从行星身侧掠过，没能借到那一点速度。" -- 1265
end -- 1262
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 1269
	if result == "success" then -- 1269
		return TitleSuccessHex -- 1270
	end -- 1270
	if result == "crashed" then -- 1270
		return TitleCrashedHex -- 1271
	end -- 1271
	return TitleMissedHex -- 1272
end -- 1269
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 1281
	if result == "success" then -- 1281
		return "下一关已解锁" -- 1282
	end -- 1282
	return "可重试本关，或返回关卡选择" -- 1283
end -- 1281
--- 结算卡按可用视口收缩，避免窄屏/短屏时卡片与按钮超出画布。
function ____exports.resultPanelLayout(viewW, viewH) -- 1328
	local cardW = math.max( -- 1329
		1, -- 1329
		math.min( -- 1329
			viewW - 24, -- 1329
			clampNumber(viewW * 0.9, 280, 560) -- 1329
		) -- 1329
	) -- 1329
	local buttonW = math.min( -- 1330
		144, -- 1330
		math.max(120, cardW - 24) -- 1330
	) -- 1330
	local buttonH = math.min( -- 1331
		72, -- 1331
		math.max( -- 1331
			48, -- 1331
			math.floor(viewH * 0.12) -- 1331
		) -- 1331
	) -- 1331
	local contentScale = math.min( -- 1332
		1, -- 1332
		math.max(0.2, (viewH - 24 - buttonH * 2) / 396) -- 1332
	) -- 1332
	local cardH = math.ceil(396 * contentScale + buttonH * 2) -- 1333
	return { -- 1334
		cardX = (viewW - cardW) / 2, -- 1335
		cardY = (viewH - cardH) / 2, -- 1336
		cardW = cardW, -- 1337
		cardH = cardH, -- 1338
		buttonW = buttonW, -- 1339
		buttonH = buttonH, -- 1340
		contentScale = contentScale -- 1341
	} -- 1341
end -- 1328
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 1357
	local root = createPanel( -- 1363
		parent, -- 1363
		viewW, -- 1363
		viewH, -- 1363
		ResultBackdropHex, -- 1363
		{alpha = 0.78} -- 1363
	) -- 1363
	local layout = ____exports.resultPanelLayout(viewW, viewH) -- 1364
	local cardW = layout.cardW -- 1364
	local cardH = layout.cardH -- 1364
	local btnW = layout.buttonW -- 1364
	local btnH = layout.buttonH -- 1364
	local contentScale = layout.contentScale -- 1364
	local padX = (cardW - btnW) / 2 -- 1366
	local padY = 28 * contentScale -- 1367
	local function scaled(value) -- 1368
		return math.max( -- 1368
			1, -- 1368
			math.floor(value * contentScale + 0.5) -- 1368
		) -- 1368
	end -- 1368
	local fontLevel = scaled(24) -- 1370
	local fontRockets = scaled(38) -- 1371
	local fontTitle = scaled(30) -- 1372
	local fontTelemetry = scaled(19) -- 1373
	local fontChallenge = scaled(18) -- 1374
	local fontTotal = scaled(20) -- 1375
	local btnFont = scaled(20) -- 1376
	local rowGap = 12 * contentScale -- 1377
	local hLevel = scaled(28) -- 1379
	local hRockets = scaled(42) -- 1380
	local hTitle = scaled(34) -- 1381
	local hTelemetry = scaled(24) -- 1382
	local hChallengeRow = scaled(30) -- 1383
	local hChallenges = hChallengeRow * 3 -- 1384
	local hTotal = scaled(24) -- 1385
	local card = createPanel( -- 1387
		root, -- 1387
		cardW, -- 1387
		cardH, -- 1387
		ResultCardHex, -- 1387
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 1387
	) -- 1387
	card.position = Vec2(layout.cardX, layout.cardY) -- 1392
	local cursor = cardH - padY -- 1395
	cursor = cursor - hLevel -- 1397
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 1398
	if levelLabel ~= nil then -- 1398
		levelLabel.textWidth = cardW - 24 -- 1399
	end -- 1399
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 1400
	cursor = cursor - (rowGap + hRockets) -- 1402
	local rocketsLabel = createLabel(card, "", fontRockets, 16762939) -- 1403
	setLabelCenter(rocketsLabel, cardW / 2, cursor + hRockets / 2) -- 1404
	cursor = cursor - (rowGap + hTitle) -- 1406
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 1407
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 1408
	cursor = cursor - (rowGap + hTelemetry) -- 1410
	local telemetryLabel = createLabel(card, "", fontTelemetry, ResultHintHex) -- 1411
	if telemetryLabel ~= nil then -- 1411
		telemetryLabel.textWidth = cardW - 32 -- 1412
	end -- 1412
	setLabelCenter(telemetryLabel, cardW / 2, cursor + hTelemetry / 2) -- 1413
	cursor = cursor - rowGap -- 1415
	local challengeLabels = {} -- 1416
	do -- 1416
		local k = 0 -- 1417
		while k < 3 do -- 1417
			cursor = cursor - hChallengeRow -- 1418
			local cl = createLabel(card, "", fontChallenge, 10405355) -- 1419
			if cl ~= nil then -- 1419
				cl.textWidth = cardW - 60 -- 1421
				setLabelCenter(cl, cardW / 2, cursor + hChallengeRow / 2) -- 1422
				challengeLabels[#challengeLabels + 1] = cl -- 1423
			end -- 1423
			k = k + 1 -- 1417
		end -- 1417
	end -- 1417
	cursor = cursor - (rowGap + hTotal) -- 1427
	local totalLabel = createLabel(card, "", fontTotal, 16766073) -- 1428
	if totalLabel ~= nil then -- 1428
		totalLabel.textWidth = cardW - 24 -- 1429
	end -- 1429
	setLabelCenter(totalLabel, cardW / 2, cursor + hTotal / 2) -- 1430
	cursor = cursor - (rowGap + btnH) -- 1432
	local retryButton = createButton(card, { -- 1433
		w = btnW, -- 1434
		h = btnH, -- 1435
		text = "重试", -- 1436
		icon = "retry", -- 1436
		fontSize = btnFont, -- 1437
		bgHex = ResultButtonBgHex, -- 1438
		fgHex = ResultButtonFgHex, -- 1439
		borderHex = ResultButtonBorderHex, -- 1440
		fireOn = "press", -- 1441
		onTap = opts.onRetry -- 1442
	}) -- 1442
	retryButton.root.position = Vec2(padX, cursor) -- 1444
	cursor = cursor - (8 + btnH) -- 1446
	local backButton = createButton(card, { -- 1447
		w = btnW, -- 1448
		h = btnH, -- 1449
		text = "选关", -- 1450
		icon = "back", -- 1450
		fontSize = btnFont, -- 1451
		bgHex = ResultButtonAltBgHex, -- 1452
		fgHex = ResultButtonFgHex, -- 1453
		borderHex = ResultButtonBorderHex, -- 1454
		fireOn = "press", -- 1455
		onTap = opts.onBackToSelect -- 1456
	}) -- 1456
	backButton.root.position = Vec2(padX, cursor) -- 1458
	root.visible = false -- 1460
	retryButton:setEnabled(false) -- 1461
	backButton:setEnabled(false) -- 1462
	return { -- 1464
		root = root, -- 1465
		show = function(____, result, levelName, detail) -- 1466
			retryButton:setEnabled(true) -- 1467
			backButton:setEnabled(true) -- 1468
			setLabelText(levelLabel, levelName) -- 1469
			setLabelText( -- 1470
				titleLabel, -- 1470
				resultTitle(result) -- 1470
			) -- 1470
			setLabelColor( -- 1471
				titleLabel, -- 1471
				resultTitleColor(result) -- 1471
			) -- 1471
			if detail ~= nil then -- 1471
				if detail.completionOnly == true then -- 1471
					setLabelText( -- 1474
						titleLabel, -- 1474
						result == "success" and "引力借力完成" or resultTitle(result) -- 1474
					) -- 1474
				end -- 1474
				local rCount = detail.rocketsGot -- 1475
				local rStr = "☆  ☆  ☆" -- 1476
				if rCount == 1 then -- 1476
					rStr = "★  ☆  ☆" -- 1477
				elseif rCount == 2 then -- 1477
					rStr = "★  ★  ☆" -- 1478
				elseif rCount >= 3 then -- 1478
					rStr = "★  ★  ★" -- 1479
				end -- 1479
				setLabelText( -- 1480
					rocketsLabel, -- 1480
					detail.completionOnly == true and (result == "success" and "目标已完成" or "再试一次") or (detail.bonusPointCount ~= nil and (("火箭得分 " .. __TS__NumberToFixed(rCount, 0)) .. " / ") .. __TS__NumberToFixed(detail.bonusPointCount, 0) or rStr) -- 1480
				) -- 1480
				setLabelColor(rocketsLabel, rCount > 0 and 16762939 or 6322324) -- 1481
				local pct = detail.dvBudget > 0 and math.floor(detail.burnDv / detail.dvBudget * 100) or 0 -- 1483
				local telemText = ((((((("点火消耗 Δv: " .. __TS__NumberToFixed(detail.burnDv, 2)) .. " / ") .. __TS__NumberToFixed(detail.dvBudget, 2)) .. " (") .. __TS__NumberToFixed(pct, 0)) .. "%) · 用时: ") .. __TS__NumberToFixed(detail.flightTime, 1)) .. "s" -- 1484
				setLabelText(telemetryLabel, telemText) -- 1485
				do -- 1485
					local k = 0 -- 1487
					while k < 3 do -- 1487
						if challengeLabels[k + 1] ~= nil then -- 1487
							if k < #detail.challenges then -- 1487
								local ok = detail.achieved[k + 1] -- 1490
								local icon = ok and "★" or "☆" -- 1491
								local rank = k == 0 and "一星" or (k == 1 and "二星" or "三星") -- 1492
								local text = detail.completionOnly == true and (ok and "目标完成 · 记录已保存" or "尚未完成目标") or (((icon .. " [") .. rank) .. "] ") .. detail.challenges[k + 1] -- 1493
								setLabelText(challengeLabels[k + 1], text) -- 1494
								setLabelColor(challengeLabels[k + 1], ok and 16762939 or 6322324) -- 1495
								challengeLabels[k + 1].visible = true -- 1496
							else -- 1496
								challengeLabels[k + 1].visible = false -- 1498
							end -- 1498
						end -- 1498
						k = k + 1 -- 1487
					end -- 1487
				end -- 1487
				setLabelText( -- 1503
					totalLabel, -- 1503
					((("全深空火箭勋章: " .. __TS__NumberToFixed(detail.totalRockets, 0)) .. " / ") .. __TS__NumberToFixed(detail.totalPossibleRockets, 0)) .. " ★" -- 1503
				) -- 1503
				if totalLabel ~= nil then -- 1503
					totalLabel.visible = detail.completionOnly ~= true -- 1504
				end -- 1504
			else -- 1504
				setLabelText(rocketsLabel, result == "success" and "★  ☆  ☆" or "☆  ☆  ☆") -- 1506
				setLabelColor(rocketsLabel, result == "success" and 16762939 or 6322324) -- 1507
				setLabelText( -- 1508
					telemetryLabel, -- 1508
					resultBody(result) -- 1508
				) -- 1508
				do -- 1508
					local k = 0 -- 1509
					while k < #challengeLabels do -- 1509
						challengeLabels[k + 1].visible = false -- 1509
						k = k + 1 -- 1509
					end -- 1509
				end -- 1509
				if totalLabel ~= nil then -- 1509
					totalLabel.visible = false -- 1510
				end -- 1510
			end -- 1510
			root.visible = true -- 1512
		end, -- 1466
		hide = function() -- 1514
			root.visible = false -- 1515
			retryButton:setEnabled(false) -- 1516
			backButton:setEnabled(false) -- 1517
		end -- 1514
	} -- 1514
end -- 1357
local FinaleBackdropHex = 329484 -- 1532
local FinaleMainHex = 15398143 -- 1533
local FinaleSubHex = 10470632 -- 1534
--- 终章主文案（逐字；改之前先改 PLAN S3.18 与 docs/开发手册.md）。
____exports.FinaleMainText = "这就是我们整颗星球的样子 —— 而你已经从那里飞到了这里。" -- 1539
--- 终章小字：飞行距离 / 用时（纯函数，可单测）。
-- 
-- 距离是**平面单位**（关卡尺度，不是公里）—— 别在这里换算成天文单位，
-- 那一换就得把整条注释重写一遍，而玩家要的只是「飞了多远、花了多久」。
function ____exports.finaleSubtitle(distance, time) -- 1547
	return ((("飞行 " .. __TS__NumberToFixed(distance, 0)) .. " 单位 · 用时 ") .. __TS__NumberToFixed(time, 1)) .. " 秒" -- 1548
end -- 1547
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
function ____exports.createFinalePanel(parent, viewW, viewH, opts) -- 1578
	local root = createPanel( -- 1584
		parent, -- 1584
		viewW, -- 1584
		viewH, -- 1584
		FinaleBackdropHex, -- 1584
		{alpha = 0.55} -- 1584
	) -- 1584
	local fontMain = 34 -- 1586
	local fontSub = 30 -- 1587
	local btnFont = 40 -- 1588
	local mainLabel = createLabel(root, ____exports.FinaleMainText, fontMain, FinaleMainHex) -- 1590
	if mainLabel ~= nil then -- 1590
		mainLabel.textWidth = viewW * 0.88 -- 1593
		setLabelCenter(mainLabel, viewW / 2, viewH * 0.8) -- 1594
	end -- 1594
	local subLabel = createLabel(root, "", fontSub, FinaleSubHex) -- 1597
	if subLabel ~= nil then -- 1597
		setLabelCenter(subLabel, viewW / 2, viewH * 0.71) -- 1598
	end -- 1598
	local btnW = 72 -- 1600
	local btnH = 72 -- 1601
	local backButton = createButton(root, { -- 1602
		w = btnW, -- 1603
		h = btnH, -- 1604
		text = "", -- 1605
		icon = "back", -- 1605
		fontSize = btnFont, -- 1606
		bgHex = ResultButtonBgHex, -- 1607
		fgHex = ResultButtonFgHex, -- 1608
		borderHex = ResultButtonBorderHex, -- 1609
		fireOn = "press", -- 1611
		onTap = opts.onBackToSelect -- 1612
	}) -- 1612
	backButton.root.position = Vec2((viewW - btnW) / 2, 110) -- 1614
	root.visible = false -- 1616
	backButton:setEnabled(false) -- 1618
	return { -- 1620
		root = root, -- 1621
		show = function(____, main, sub) -- 1622
			setLabelText(mainLabel, main) -- 1623
			setLabelText(subLabel, sub) -- 1624
			backButton:setEnabled(true) -- 1625
			root.visible = true -- 1626
		end, -- 1622
		hide = function() -- 1628
			root.visible = false -- 1629
			backButton:setEnabled(false) -- 1631
		end -- 1628
	} -- 1628
end -- 1578
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 1670
	local root = createPanel( -- 1676
		parent, -- 1676
		viewW, -- 1676
		viewH, -- 1676
		SelectBackdropHex, -- 1676
		{alpha = 0.9} -- 1676
	) -- 1676
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 1678
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 1679
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 1681
	setLabelCenter( -- 1682
		subtitleLabel, -- 1682
		viewW / 2, -- 1682
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 1682
	) -- 1682
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 1684
	setLabelCenter( -- 1685
		hintLabel, -- 1685
		viewW / 2, -- 1685
		clampNumber(viewH * 0.045, 36, 90) -- 1685
	) -- 1685
	local count = #opts.levels -- 1687
	local cols = viewH > viewW and 2 or 1 -- 1690
	local rows = math.max( -- 1691
		1, -- 1691
		math.ceil(count / cols) -- 1691
	) -- 1691
	local gap = 18 -- 1692
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 1693
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 1694
	local availW = viewW * 0.84 -- 1695
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 1696
	local btnW = math.max(1, (availW - gap * (cols - 1)) / cols) -- 1697
	local btnH = clampNumber( -- 1698
		rows > 0 and availH / rows or MinButtonHeight, -- 1698
		math.min( -- 1698
			MinButtonHeight, -- 1698
			math.max(48, availH / rows) -- 1698
		), -- 1698
		190 -- 1698
	) -- 1698
	local gridW = cols * btnW + gap * (cols - 1) -- 1699
	local topY = viewH - headerH -- 1700
	local buttons = {} -- 1702
	do -- 1702
		local i = 0 -- 1703
		while i < count do -- 1703
			local index = i -- 1705
			local button = createButton( -- 1706
				root, -- 1706
				{ -- 1706
					w = btnW, -- 1707
					h = btnH, -- 1708
					text = opts.levels[index + 1].name, -- 1709
					fontSize = 38, -- 1710
					bgHex = SelectLockedBgHex, -- 1711
					fgHex = SelectLockedFgHex, -- 1712
					borderHex = SelectBorderHex, -- 1713
					fireOn = "press", -- 1715
					onTap = function() return opts:onPick(index) end -- 1716
				} -- 1716
			) -- 1716
			local col = index % cols -- 1718
			local rowIndex = math.floor(index / cols) -- 1719
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 1720
			buttons[#buttons + 1] = button -- 1724
			i = i + 1 -- 1703
		end -- 1703
	end -- 1703
	local replayW = math.min( -- 1730
		144, -- 1730
		math.max(120, viewW - 24) -- 1730
	) -- 1730
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 1731
		root, -- 1732
		{ -- 1732
			w = replayW, -- 1733
			h = MinButtonHeight, -- 1734
			text = "重看开场", -- 1735
			fontSize = 30, -- 1736
			bgHex = SelectLockedBgHex, -- 1737
			fgHex = SelectSubtitleHex, -- 1738
			borderHex = SelectBorderHex, -- 1739
			fireOn = "press", -- 1740
			onTap = function() -- 1741
				if opts.onReplayIntro ~= nil then -- 1741
					opts:onReplayIntro() -- 1742
				end -- 1742
			end -- 1741
		} -- 1741
	) or nil -- 1741
	if replayButton ~= nil then -- 1741
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 1747
		local by = clampNumber( -- 1748
			gridBottom - MinButtonHeight - 20, -- 1748
			8, -- 1748
			math.max(8, viewH - MinButtonHeight - 8) -- 1748
		) -- 1748
		replayButton.root.position = Vec2((viewW - replayW) / 2, by) -- 1749
	end -- 1749
	root.visible = false -- 1752
	do -- 1752
		local i = 0 -- 1753
		while i < count do -- 1753
			buttons[i + 1]:setEnabled(false) -- 1753
			i = i + 1 -- 1753
		end -- 1753
	end -- 1753
	if replayButton ~= nil then -- 1753
		replayButton:setEnabled(false) -- 1754
	end -- 1754
	return { -- 1756
		root = root, -- 1757
		show = function(____, unlocked) -- 1758
			local maxUnlocked = clampNumber( -- 1759
				math.floor(unlocked), -- 1759
				0, -- 1759
				count - 1 -- 1759
			) -- 1759
			setLabelText( -- 1760
				subtitleLabel, -- 1760
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 1760
			) -- 1760
			do -- 1760
				local i = 0 -- 1761
				while i < count do -- 1761
					local button = buttons[i + 1] -- 1762
					local open = i <= maxUnlocked -- 1763
					button:setEnabled(open) -- 1764
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 1765
					if open then -- 1765
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 1766
					else -- 1766
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 1767
					end -- 1767
					i = i + 1 -- 1761
				end -- 1761
			end -- 1761
			root.visible = true -- 1769
			if replayButton ~= nil then -- 1769
				replayButton:setEnabled(true) -- 1770
			end -- 1770
		end, -- 1758
		hide = function() -- 1772
			root.visible = false -- 1773
			do -- 1773
				local i = 0 -- 1775
				while i < count do -- 1775
					buttons[i + 1]:setEnabled(false) -- 1775
					i = i + 1 -- 1775
				end -- 1775
			end -- 1775
			if replayButton ~= nil then -- 1775
				replayButton:setEnabled(false) -- 1776
			end -- 1776
		end -- 1772
	} -- 1772
end -- 1670
return ____exports -- 1670