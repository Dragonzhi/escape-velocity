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
	touchLayer.order = -100 -- 375
	touchLayer.swallowTouches = true -- 376
	root:addChild(touchLayer) -- 377
	local space = {viewW = viewW, viewH = viewH} -- 379
	local TimeBtnW = 78 -- 380
	local TimeBtnH = 64 -- 381
	local TimeRowY = 170 -- 382
	local enabled = false -- 384
	local dragging = false -- 385
	--- 整屏瞄准（2D 模式）；由 Game 按视图状态同步。
	local fullScreenAim = false -- 387
	local aim = {velocity = {x = 0, y = -speedMin}, power = 0, unit = {x = 0, y = -1}} -- 388
	local probeOffset = {x = 0, y = 0} -- 391
	local dragHandler = nil -- 393
	local readyHandler = nil -- 394
	local observeHandler = nil -- 395
	local zoomHandler = nil -- 396
	local launchHandler = nil -- 397
	local skipTourHandler = nil -- 398
	local tourActiveChecker = nil -- 399
	local pressOffset = {x = 0, y = 0} -- 410
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 413
		aim = ____exports.computeAim( -- 414
			{x = 0, y = 0}, -- 414
			delta, -- 414
			AimMaxDragPx, -- 414
			speedTop, -- 414
			speedMin -- 414
		) -- 414
		if dragHandler ~= nil then -- 414
			dragHandler(aim) -- 415
		end -- 415
	end -- 413
	local aimRadius = math.max(96, viewW * 0.25) -- 422
	local mode = "none" -- 423
	local observeLast = {x = 0, y = 0} -- 424
	local function hitsTimeControls(____local) -- 425
		local left = 24 - 8 -- 426
		local right = 24 + (TimeBtnW + 8) * 2 + TimeBtnW + 8 -- 427
		return ____local.x >= left and ____local.x <= right and ____local.y >= TimeRowY - 8 and ____local.y <= TimeRowY + TimeBtnH + 8 -- 428
	end -- 425
	touchLayer:onTapBegan(function(touch) -- 430
		if not enabled then -- 430
			return -- 431
		end -- 431
		if hitsTimeControls({x = touch.location.x, y = touch.location.y}) then -- 431
			mode = "none" -- 435
			dragging = false -- 436
			return -- 437
		end -- 437
		if tourActiveChecker ~= nil and tourActiveChecker() and skipTourHandler ~= nil then -- 437
			skipTourHandler() -- 440
			return -- 441
		end -- 441
		local at = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 443
		local dx = at.x - probeOffset.x -- 444
		local dy = at.y - probeOffset.y -- 445
		if fullScreenAim or math.sqrt(dx * dx + dy * dy) <= aimRadius then -- 445
			mode = "aim" -- 447
			dragging = true -- 448
			pressOffset = at -- 449
			handleDelta({x = 0, y = 0}) -- 451
		else -- 451
			mode = "observe" -- 453
			observeLast = at -- 454
		end -- 454
	end) -- 430
	touchLayer:onTapMoved(function(touch) -- 458
		if not enabled then -- 458
			return -- 459
		end -- 459
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 460
		if mode == "aim" and dragging then -- 460
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 462
		elseif mode == "observe" then -- 462
			if observeHandler ~= nil then -- 462
				observeHandler(cur.x - observeLast.x, cur.y - observeLast.y) -- 465
			end -- 465
			observeLast = cur -- 466
		end -- 466
	end) -- 458
	touchLayer:onTapEnded(function(touch) -- 470
		if not enabled then -- 470
			return -- 471
		end -- 471
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 472
		if mode == "aim" then -- 472
			dragging = false -- 474
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 475
			if readyHandler ~= nil then -- 475
				readyHandler(aim) -- 477
			end -- 477
		end -- 477
		mode = "none" -- 479
	end) -- 470
	touchLayer:onGesture(function(_center, numFingers, deltaDist, _deltaAngle) -- 483
		if not enabled or numFingers < 2 then -- 483
			return -- 484
		end -- 484
		if zoomHandler ~= nil then -- 484
			zoomHandler(deltaDist) -- 485
		end -- 485
	end) -- 483
	touchLayer.touchEnabled = false -- 493
	createPanel( -- 499
		root, -- 499
		220, -- 499
		50, -- 499
		658964, -- 499
		{alpha = 0.45} -- 499
	) -- 499
	local orbitName = transferMode == "inward" and "近日点" or (transferMode == "outward" and "远日点" or "远地点高度") -- 500
	local dvLabel = createLabel(root, transferTutorial and "拖动调整" .. orbitName or "Δv — / —", transferTutorial and 22 or 30, ResultHintHex) -- 501
	if dvLabel ~= nil then -- 501
		dvLabel.position = Vec2(24, viewH - (transferTutorial and 130 or 44)) -- 503
		dvLabel.anchor = Vec2(0, 0) -- 504
	end -- 504
	local warpHandler = nil -- 514
	local dateSpan = 0 -- 515
	--- 这一关有时间轴**且**当前相态允许改日期（Flying/Result 时必须是 false）。
	local warpOn = true -- 522
	local warpVisible = true -- 523
	--- 相态是否允许改日期（由主循环每帧 setTimeEnabled 同步）。
	local warpAllowed = true -- 525
	--- 上次写进日期的文字（避免每帧重设 Label 文本）。
	local lastDateText = "" -- 527
	--- >0 = 正在按住这个方向（-1 回退 / +1 加速）；0 = 没按住。
	local warpHoldDir = 0 -- 529
	--- 距离下一次连按还有多久（秒）。
	local warpRepeatIn = 0 -- 531
	local WarpButtonW = 116 -- 532
	local WarpButtonH = 64 -- 533
	local warpButtons = {} -- 534
	local function applyWarpState() -- 535
		local vis = dateSpan > 0 -- 536
		local on = vis and warpAllowed -- 537
		if vis == warpVisible and on == warpOn then -- 537
			return -- 538
		end -- 538
		warpVisible = vis -- 539
		warpOn = on -- 540
		if not on then -- 540
			warpHoldDir = 0 -- 541
		end -- 541
		for ____, b in ipairs(warpButtons) do -- 542
			b.root.visible = vis -- 543
			b:setEnabled(on) -- 544
		end -- 544
		if dateLabel ~= nil then -- 544
			dateLabel.visible = vis -- 546
		end -- 546
		datePlate.visible = vis -- 547
	end -- 535
	local function makeWarpButton(text, dir, x) -- 549
		local btn = createButton( -- 550
			root, -- 550
			{ -- 550
				w = WarpButtonW, -- 551
				h = WarpButtonH, -- 552
				text = text, -- 553
				fontSize = 30, -- 554
				bgHex = ResultButtonAltBgHex, -- 555
				fgHex = ResultButtonFgHex, -- 556
				borderHex = ResultButtonBorderHex, -- 557
				onTap = function() -- 560
				end, -- 560
				onPressBegan = function() -- 561
					print((("[escape-velocity] warp press dir=" .. __TS__NumberToFixed(dir, 0)) .. " on=") .. (warpOn and "1" or "0")) -- 563
					if not warpOn then -- 563
						return -- 564
					end -- 564
					if warpHoldDir == dir then -- 564
						return -- 566
					end -- 566
					warpHoldDir = dir -- 567
					warpRepeatIn = WarpHoldDelaySec -- 568
					if warpHandler ~= nil then -- 568
						warpHandler(dir) -- 569
					end -- 569
				end, -- 561
				onPressEnded = function() -- 571
					print((("[escape-velocity] warp release dir=" .. __TS__NumberToFixed(dir, 0)) .. " hold=") .. __TS__NumberToFixed(warpHoldDir, 0)) -- 572
					if warpHoldDir == dir then -- 572
						warpHoldDir = 0 -- 574
					end -- 574
				end -- 571
			} -- 571
		) -- 571
		btn.root.position = Vec2(x, viewH - 96 - WarpButtonH) -- 580
		warpButtons[#warpButtons + 1] = btn -- 581
	end -- 549
	local warpLeftX = viewW - (WarpButtonW * 2 + 8) - 20 -- 583
	makeWarpButton("◀ 回退", -1, warpLeftX) -- 584
	makeWarpButton("加速 ▶", 1, warpLeftX + WarpButtonW + 8) -- 585
	datePlate = createPanel( -- 587
		root, -- 587
		300, -- 587
		50, -- 587
		658964, -- 587
		{alpha = 0.45} -- 587
	) -- 587
	datePlate.position = Vec2(warpLeftX - 316, viewH - 96 - WarpButtonH + 8) -- 588
	dateLabel = createLabel(root, "发射日期 —", 30, ResultHintHex) -- 589
	if dateLabel ~= nil then -- 589
		dateLabel.anchor = Vec2(1, 0) -- 594
		dateLabel.position = Vec2(warpLeftX - 16, viewH - 96 - WarpButtonH + 18) -- 595
	end -- 595
	local QuickRetryW = 110 -- 599
	local QuickRetryH = 50 -- 600
	local quickRetryHandler = nil -- 601
	local quickRetryBtn = createButton( -- 602
		root, -- 602
		{ -- 602
			w = QuickRetryW, -- 603
			h = QuickRetryH, -- 604
			text = "↺ 重试", -- 605
			fontSize = 26, -- 606
			bgHex = 12730636, -- 607
			fgHex = 16777215, -- 608
			borderHex = 16498468, -- 609
			fireOn = "press", -- 610
			onTap = function() -- 611
				print("[escape-velocity] quick retry tapped") -- 612
				if quickRetryHandler ~= nil then -- 612
					quickRetryHandler() -- 613
				end -- 613
			end -- 611
		} -- 611
	) -- 611
	quickRetryBtn.root.position = Vec2(viewW - QuickRetryW - 20, viewH - QuickRetryH - 20) -- 616
	local starPlateW = 180 -- 619
	local starPlateH = 46 -- 620
	local starPlate = createPanel( -- 621
		root, -- 621
		starPlateW, -- 621
		starPlateH, -- 621
		658964, -- 621
		{alpha = 0.55} -- 621
	) -- 621
	starPlate.position = Vec2(viewW / 2 - starPlateW / 2, viewH - starPlateH - 22) -- 622
	starPlate.visible = not transferTutorial -- 623
	local starStatusLabel = createLabel(root, "☆ ☆ ☆", 30, 16766720) -- 624
	local bonusToastLabel = createLabel(root, "", 34, 9240475) -- 625
	if bonusToastLabel ~= nil then -- 625
		bonusToastLabel.position = Vec2(viewW / 2, viewH * 0.68) -- 626
		bonusToastLabel.visible = false -- 626
	end -- 626
	if starStatusLabel ~= nil then -- 626
		starStatusLabel.anchor = Vec2(0.5, 0.5) -- 628
		starStatusLabel.position = Vec2(viewW / 2, viewH - starPlateH / 2 - 22) -- 629
	end -- 629
	local function updateStarsStatus(count) -- 631
		if starStatusLabel == nil then -- 631
			return -- 632
		end -- 632
		if transferTutorial then -- 632
			starStatusLabel.visible = false -- 633
			return -- 633
		end -- 633
		local s = "☆ ☆ ☆" -- 634
		if count == 1 then -- 634
			s = "★ ☆ ☆" -- 635
		elseif count == 2 then -- 635
			s = "★ ★ ☆" -- 636
		elseif count >= 3 then -- 636
			s = "★ ★ ★" -- 637
		end -- 637
		setLabelText(starStatusLabel, s) -- 638
	end -- 631
	local function updateBonusStatus(got, total) -- 640
		if starStatusLabel == nil then -- 640
			return -- 641
		end -- 641
		starPlate.visible = total > 0 -- 642
		starStatusLabel.visible = total > 0 -- 643
		if total > 0 then -- 643
			setLabelText( -- 644
				starStatusLabel, -- 644
				(("🚀 " .. __TS__NumberToFixed(got, 0)) .. " / ") .. __TS__NumberToFixed(total, 0) -- 644
			) -- 644
		end -- 644
	end -- 640
	local LaunchButtonW = 220 -- 649
	local LaunchButtonH = 112 -- 650
	local launchButton = createButton( -- 651
		root, -- 651
		{ -- 651
			w = LaunchButtonW, -- 652
			h = LaunchButtonH, -- 653
			text = "▲ 发射 ▲", -- 654
			fontSize = 38, -- 655
			bgHex = ResultButtonBgHex, -- 656
			fgHex = ResultButtonFgHex, -- 657
			borderHex = ResultButtonBorderHex, -- 658
			fireOn = "press", -- 659
			onTap = function() -- 660
				print("[escape-velocity] launch button fire (press)") -- 661
				if launchHandler ~= nil then -- 661
					launchHandler() -- 662
				end -- 662
			end -- 660
		} -- 660
	) -- 660
	launchButton.root.position = Vec2(viewW - LaunchButtonW - 24, 96) -- 665
	launchButton.root.visible = false -- 666
	launchButton:setEnabled(false) -- 667
	local CancelButtonW = 160 -- 670
	local CancelButtonH = 72 -- 671
	local cancelAimHandler = nil -- 672
	local cancelAimButton = createButton( -- 673
		root, -- 673
		{ -- 673
			w = CancelButtonW, -- 674
			h = CancelButtonH, -- 675
			text = "✕ 取消", -- 676
			fontSize = 28, -- 677
			bgHex = ResultButtonAltBgHex, -- 678
			fgHex = ResultButtonFgHex, -- 679
			borderHex = ResultButtonBorderHex, -- 680
			fireOn = "press", -- 681
			onTap = function() -- 682
				print("[escape-velocity] cancel aim fire (press)") -- 683
				if cancelAimHandler ~= nil then -- 683
					cancelAimHandler() -- 684
				end -- 684
			end -- 682
		} -- 682
	) -- 682
	cancelAimButton.root.position = Vec2(viewW - LaunchButtonW - CancelButtonW - 40, 116) -- 687
	cancelAimButton.root.visible = false -- 688
	cancelAimButton:setEnabled(false) -- 689
	local ViewButtonW = 116 -- 693
	local ViewButtonH = 64 -- 694
	local viewHandler = nil -- 695
	local viewButton = createButton( -- 696
		root, -- 696
		{ -- 696
			w = ViewButtonW, -- 697
			h = ViewButtonH, -- 698
			text = "[ 3D ]", -- 699
			fontSize = 26, -- 700
			bgHex = ResultButtonAltBgHex, -- 701
			fgHex = ResultButtonFgHex, -- 702
			borderHex = ResultButtonBorderHex, -- 703
			fireOn = "press", -- 704
			onTap = function() -- 705
				print("[escape-velocity] view toggle fire (press)") -- 706
				if viewHandler ~= nil then -- 706
					viewHandler() -- 707
				end -- 707
			end -- 705
		} -- 705
	) -- 705
	viewButton.root.position = Vec2(viewW - ViewButtonW - 24, 96 + LaunchButtonH + 12) -- 710
	--- 上次写进按钮的文字（每帧都会被 setViewMode 调用，没变就别碰 Label）。
	local lastViewText = "2D" -- 712
	local cameraFocusHandler = nil -- 715
	local endViewingHandler = nil -- 716
	local cameraFocusButton = transferTutorial and createButton( -- 717
		root, -- 717
		{ -- 717
			w = 260, -- 718
			h = 58, -- 718
			text = "镜头 · 自动", -- 718
			fontSize = 22, -- 718
			bgHex = ResultButtonAltBgHex, -- 719
			fgHex = ResultButtonFgHex, -- 719
			borderHex = ResultButtonBorderHex, -- 719
			fireOn = "press", -- 719
			onTap = function() -- 720
				if cameraFocusHandler ~= nil then -- 720
					cameraFocusHandler() -- 720
				end -- 720
			end -- 720
		} -- 720
	) or nil -- 720
	local endViewingButton = transferTutorial and createButton( -- 722
		root, -- 722
		{ -- 722
			w = 220, -- 723
			h = LaunchButtonH, -- 723
			text = "结束观赏", -- 723
			fontSize = 26, -- 723
			bgHex = ResultButtonAltBgHex, -- 724
			fgHex = ResultButtonFgHex, -- 724
			borderHex = ResultButtonBorderHex, -- 724
			fireOn = "press", -- 724
			onTap = function() -- 725
				if endViewingHandler ~= nil then -- 725
					endViewingHandler() -- 725
				end -- 725
			end -- 725
		} -- 725
	) or nil -- 725
	if cameraFocusButton ~= nil then -- 725
		cameraFocusButton.root.position = Vec2(24, 266) -- 727
		cameraFocusButton.root.visible = false -- 727
		cameraFocusButton:setEnabled(false) -- 727
	end -- 727
	if endViewingButton ~= nil then -- 727
		endViewingButton.root.position = Vec2(viewW - 244, 96) -- 728
		endViewingButton.root.visible = false -- 728
		endViewingButton:setEnabled(false) -- 728
	end -- 728
	local ____transferTutorial_0 -- 729
	if transferTutorial then -- 729
		____transferTutorial_0 = createLabel(root, "", 24, ResultHintHex) -- 729
	else -- 729
		____transferTutorial_0 = nil -- 729
	end -- 729
	local viewingLabel = ____transferTutorial_0 -- 729
	if viewingLabel ~= nil then -- 729
		viewingLabel.position = Vec2(24, viewH - 130) -- 730
		viewingLabel.anchor = Vec2(0, 0) -- 730
		viewingLabel.visible = false -- 730
	end -- 730
	local viewingKey = "" -- 731
	local ZoomBtnSize = 58 -- 734
	local zoomGap = 8 -- 735
	local zoomButtons = {} -- 736
	local zoomInHandler = nil -- 737
	local zoomOutHandler = nil -- 738
	local fitViewHandler = nil -- 739
	local function makeZoomButton(text, x, fontSize, onClick) -- 741
		local btn = createButton( -- 742
			root, -- 742
			{ -- 742
				w = ZoomBtnSize, -- 743
				h = ZoomBtnSize, -- 744
				text = text, -- 745
				fontSize = fontSize, -- 746
				bgHex = ResultButtonAltBgHex, -- 747
				fgHex = ResultButtonFgHex, -- 748
				borderHex = ResultButtonBorderHex, -- 749
				fireOn = "press", -- 750
				onTap = function() -- 751
					print(("[escape-velocity] zoom btn " .. text) .. " fire") -- 752
					onClick() -- 753
				end -- 751
			} -- 751
		) -- 751
		btn.root.position = Vec2(x, 96) -- 756
		btn.root.visible = false -- 757
		btn:setEnabled(false) -- 758
		zoomButtons[#zoomButtons + 1] = btn -- 759
		return btn -- 760
	end -- 741
	makeZoomButton( -- 762
		"−", -- 762
		24, -- 762
		32, -- 762
		function() -- 762
			if zoomOutHandler ~= nil then -- 762
				zoomOutHandler() -- 763
			end -- 763
		end -- 762
	) -- 762
	makeZoomButton( -- 765
		"FIT", -- 765
		24 + ZoomBtnSize + zoomGap, -- 765
		20, -- 765
		function() -- 765
			if fitViewHandler ~= nil then -- 765
				fitViewHandler() -- 766
			end -- 766
		end -- 765
	) -- 765
	makeZoomButton( -- 768
		"+", -- 768
		24 + (ZoomBtnSize + zoomGap) * 2, -- 768
		32, -- 768
		function() -- 768
			if zoomInHandler ~= nil then -- 768
				zoomInHandler() -- 769
			end -- 769
		end -- 768
	) -- 768
	local zoomControlsVisible = nil -- 771
	local function setZoomVisible(on) -- 772
		if zoomControlsVisible == on then -- 772
			return -- 773
		end -- 773
		zoomControlsVisible = on -- 774
		for ____, b in ipairs(zoomButtons) do -- 775
			b.root.visible = on -- 776
			b:setEnabled(on) -- 777
		end -- 777
	end -- 772
	setZoomVisible(false) -- 780
	local speedUpHandler = nil -- 786
	local speedDownHandler = nil -- 787
	local pauseHandler = nil -- 788
	local slowButton = createButton( -- 790
		root, -- 790
		{ -- 790
			w = TimeBtnW, -- 791
			h = TimeBtnH, -- 791
			text = "◀ 慢", -- 791
			fontSize = 26, -- 791
			bgHex = ResultButtonAltBgHex, -- 792
			fgHex = ResultButtonFgHex, -- 792
			borderHex = ResultButtonBorderHex, -- 792
			onTap = function() -- 793
				print("[escape-velocity] speed down fire") -- 794
				if speedDownHandler ~= nil then -- 794
					speedDownHandler() -- 795
				end -- 795
			end -- 793
		} -- 793
	) -- 793
	slowButton.root.position = Vec2(24, TimeRowY) -- 798
	slowButton.root.order = 100 -- 799
	local pauseButton = createButton( -- 800
		root, -- 800
		{ -- 800
			w = TimeBtnW, -- 801
			h = TimeBtnH, -- 801
			text = "⏸", -- 801
			fontSize = 30, -- 801
			bgHex = ResultButtonAltBgHex, -- 802
			fgHex = ResultButtonFgHex, -- 802
			borderHex = ResultButtonBorderHex, -- 802
			onTap = function() -- 803
				print("[escape-velocity] pause toggle fire") -- 804
				if pauseHandler ~= nil then -- 804
					pauseHandler() -- 805
				end -- 805
			end -- 803
		} -- 803
	) -- 803
	pauseButton.root.position = Vec2(24 + TimeBtnW + 8, TimeRowY) -- 808
	pauseButton.root.order = 100 -- 809
	local fastButton = createButton( -- 810
		root, -- 810
		{ -- 810
			w = TimeBtnW, -- 811
			h = TimeBtnH, -- 811
			text = "快 ▶", -- 811
			fontSize = 26, -- 811
			bgHex = ResultButtonAltBgHex, -- 812
			fgHex = ResultButtonFgHex, -- 812
			borderHex = ResultButtonBorderHex, -- 812
			onTap = function() -- 813
				print("[escape-velocity] speed up fire") -- 814
				if speedUpHandler ~= nil then -- 814
					speedUpHandler() -- 815
				end -- 815
			end -- 813
		} -- 813
	) -- 813
	fastButton.root.position = Vec2(24 + (TimeBtnW + 8) * 2, TimeRowY) -- 818
	fastButton.root.order = 100 -- 819
	local timePlate = createPanel( -- 822
		root, -- 822
		300, -- 822
		50, -- 822
		658964, -- 822
		{alpha = 0.45} -- 822
	) -- 822
	timePlate.position = transferTutorial and Vec2(24, viewH - 190) or Vec2(24 + (TimeBtnW + 8) * 3 + 4, TimeRowY + 7) -- 823
	local timeLabel = createLabel(root, "1×（现实）  T+ 0:00", transferTutorial and 22 or 26, ResultHintHex) -- 824
	if timeLabel ~= nil then -- 824
		timeLabel.anchor = Vec2(0, 0) -- 826
		timeLabel.position = transferTutorial and Vec2(36, viewH - 179) or Vec2(24 + (TimeBtnW + 8) * 3 + 16, TimeRowY + 18) -- 827
	end -- 827
	--- 档位文字：pow 0 就是"1×（现实）"，别写成 1e0×。
	local function powText(pow) -- 830
		return pow <= 0 and "1×（现实）" or ("1e" .. __TS__NumberToFixed(pow, 0)) .. "×" -- 830
	end -- 830
	--- 任务时钟：真实秒 → "T+ 3天 04:12"。1× 下它每秒跳一格 —— 时间在流逝的唯一可见证据。
	local function missionText(sec) -- 832
		local s = sec > 0 and sec or 0 -- 833
		local days = math.floor(s / 86400) -- 834
		local rest = s - days * 86400 -- 835
		local hh = math.floor(rest / 3600) -- 836
		local mm = math.floor((rest - hh * 3600) / 60) -- 837
		local function pad(v) -- 838
			return (v < 10 and "0" or "") .. __TS__NumberToFixed(v, 0) -- 838
		end -- 838
		return ((("T+ " .. (days > 0 and __TS__NumberToFixed(days, 0) .. "天 " or "")) .. pad(hh)) .. ":") .. pad(mm) -- 839
	end -- 832
	local lastTimeText = "" -- 841
	local lastPaused = false -- 842
	local function setTimeControl(pow, minPow, maxPow, paused, missionSeconds, actualRate) -- 843
		local rateText = actualRate ~= nil and __TS__NumberToFixed(actualRate, actualRate > 0 and actualRate < 0.1 and 3 or 2) .. "×" or powText(pow) -- 844
		local txt = (((transferTutorial and rateText or powText(pow)) .. (paused and " ⏸ 暂停" or "")) .. "  ") .. (transferTutorial and ("T+ " .. __TS__NumberToFixed(missionSeconds, 1)) .. "s" or missionText(missionSeconds)) -- 845
		if txt ~= lastTimeText then -- 845
			lastTimeText = txt -- 847
			if timeLabel ~= nil then -- 847
				timeLabel.text = txt -- 848
			end -- 848
		end -- 848
		if paused ~= lastPaused then -- 848
			lastPaused = paused -- 851
			pauseButton:setText(paused and "▶" or "⏸") -- 852
			pauseButton:setColors(paused and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 853
		end -- 853
		fastButton:setEnabled(pow < maxPow) -- 856
		slowButton:setEnabled(pow > minPow) -- 857
	end -- 843
	local DrawerW = 380 -- 861
	local DrawerH = 46 -- 862
	local missionDrawerPlate = createPanel( -- 863
		root, -- 863
		DrawerW, -- 863
		DrawerH, -- 863
		658964, -- 863
		{alpha = 0.65, borderHex = 4610157} -- 863
	) -- 863
	missionDrawerPlate.position = Vec2(transferTutorial and 24 or (viewW - DrawerW) / 2, viewH - 56) -- 864
	local missionTitleLabel = createLabel(missionDrawerPlate, "", 19, 13426158) -- 865
	if missionTitleLabel ~= nil then -- 865
		missionTitleLabel.anchor = Vec2(0, 0.5) -- 867
		missionTitleLabel.position = Vec2(14, DrawerH / 2) -- 868
	end -- 868
	local missionRocketsLabel = createLabel(missionDrawerPlate, "☆  ☆  ☆", 22, 16766720) -- 870
	if missionRocketsLabel ~= nil then -- 870
		missionRocketsLabel.anchor = Vec2(1, 0.5) -- 872
		missionRocketsLabel.position = Vec2(DrawerW - 14, DrawerH / 2) -- 873
	end -- 873
	missionDrawerPlate.visible = false -- 875
	local drawerVisible = false -- 876
	local bonusToastSerial = 0 -- 877
	local drawerLevelTitle = "" -- 878
	local drawerRockets = 0 -- 879
	local liveFuelBonus = false -- 880
	local function updateDrawerDisplay() -- 882
		if missionTitleLabel ~= nil then -- 882
			setLabelText(missionTitleLabel, drawerLevelTitle) -- 884
		end -- 884
		if missionRocketsLabel ~= nil then -- 884
			local r1 = drawerRockets >= 1 and "★" or "☆" -- 887
			local r2 = (drawerRockets >= 2 or liveFuelBonus) and "★" or "☆" -- 888
			local r3 = drawerRockets >= 3 and "★" or "☆" -- 889
			setLabelText(missionRocketsLabel, transferTutorial and (drawerRockets >= 1 and "已完成" or (transferMode == "lunar" and "地月转移练习" or "日心借力练习")) or (((r1 .. "  ") .. r2) .. "  ") .. r3) -- 890
		end -- 890
	end -- 882
	local IntroBannerW = math.min(viewW - 48, 540) -- 895
	local IntroBannerH = 68 -- 896
	local introBannerPlate = createPanel( -- 897
		root, -- 897
		IntroBannerW, -- 897
		IntroBannerH, -- 897
		658964, -- 897
		{alpha = 0.8, borderHex = 4610157} -- 897
	) -- 897
	introBannerPlate.position = Vec2((viewW - IntroBannerW) / 2, 70) -- 898
	local introBannerTitle = createLabel(introBannerPlate, "", 17, 15398143) -- 899
	if introBannerTitle ~= nil then -- 899
		introBannerTitle.anchor = Vec2(0.5, 0.5) -- 901
		introBannerTitle.position = Vec2(IntroBannerW / 2, IntroBannerH * 0.65) -- 902
	end -- 902
	local introBannerHint = createLabel(introBannerPlate, "轻触屏幕任意位置跳过运镜", 13, 9283005) -- 904
	if introBannerHint ~= nil then -- 904
		introBannerHint.anchor = Vec2(0.5, 0.5) -- 906
		introBannerHint.position = Vec2(IntroBannerW / 2, IntroBannerH * 0.28) -- 907
	end -- 907
	introBannerPlate.visible = false -- 909
	local PlaybackButtonW = 116 -- 918
	local PlaybackButtonH = 64 -- 919
	local playbackGap = 10 -- 920
	local playbackButtons = {} -- 921
	local playbackSpeeds = {} -- 922
	local playbackHandler = nil -- 923
	local speedChoice = speedChoices ~= nil and #speedChoices > 0 and speedChoices or ({1, 2, 4}) -- 926
	local playbackSpeed = speedChoice[1] -- 927
	--- 已应用到节点上的显隐状态。初值 false 如实反映"建出来就隐藏"（照 warp 按钮的教训）。
	local playbackVisible = false -- 929
	local function paintPlayback() -- 930
		do -- 930
			local i = 0 -- 931
			while i < #playbackButtons do -- 931
				local on = playbackSpeeds[i + 1] == playbackSpeed -- 932
				playbackButtons[i + 1]:setColors(on and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 933
				i = i + 1 -- 931
			end -- 931
		end -- 931
	end -- 930
	local function makePlaybackButton(speed, x) -- 936
		local btn = createButton( -- 937
			root, -- 937
			{ -- 937
				w = PlaybackButtonW, -- 938
				h = PlaybackButtonH, -- 939
				text = ____exports.playbackLabel(speed), -- 940
				fontSize = 30, -- 941
				bgHex = ResultButtonAltBgHex, -- 942
				fgHex = ResultButtonFgHex, -- 943
				borderHex = ResultButtonBorderHex, -- 944
				onTap = function() -- 945
					print(("[escape-velocity] playback button fire " .. __TS__NumberToFixed(speed, 0)) .. "x (release)") -- 947
					playbackSpeed = speed -- 948
					paintPlayback() -- 949
					if playbackHandler ~= nil then -- 949
						playbackHandler(speed) -- 950
					end -- 950
				end -- 945
			} -- 945
		) -- 945
		btn.root.position = Vec2(x, 96) -- 955
		playbackButtons[#playbackButtons + 1] = btn -- 956
		playbackSpeeds[#playbackSpeeds + 1] = speed -- 957
	end -- 936
	do -- 936
		local i = 0 -- 959
		while i < #speedChoice and i < 3 do -- 959
			makePlaybackButton(speedChoice[i + 1], 24 + (PlaybackButtonW + playbackGap) * i) -- 960
			i = i + 1 -- 959
		end -- 959
	end -- 959
	paintPlayback() -- 962
	for ____, b in ipairs(playbackButtons) do -- 964
		b.root.visible = false -- 965
		b:setEnabled(false) -- 966
	end -- 966
	parent:addChild(root) -- 969
	return { -- 971
		onDrag = function(____, callback) -- 972
			dragHandler = callback -- 973
		end, -- 972
		setEnabled = function(____, value) -- 975
			enabled = value -- 976
			touchLayer.touchEnabled = value -- 979
			if not value then -- 979
				dragging = false -- 981
			end -- 981
		end, -- 975
		onAimReady = function(____, callback) -- 984
			readyHandler = callback -- 985
		end, -- 984
		onObserve = function(____, callback) -- 987
			observeHandler = callback -- 988
		end, -- 987
		onZoom = function(____, callback) -- 990
			zoomHandler = callback -- 991
		end, -- 990
		onLaunch = function(____, callback) -- 993
			launchHandler = callback -- 994
		end, -- 993
		onCancelAim = function(____, callback) -- 996
			cancelAimHandler = callback -- 997
		end, -- 996
		setArmed = function(____, armed) -- 999
			launchButton.root.visible = armed -- 1000
			launchButton:setEnabled(armed) -- 1001
			cancelAimButton.root.visible = armed -- 1002
			cancelAimButton:setEnabled(armed) -- 1003
		end, -- 999
		onViewToggle = function(____, callback) -- 1005
			viewHandler = callback -- 1006
		end, -- 1005
		onCameraFocus = function(____, callback) -- 1008
			cameraFocusHandler = callback -- 1008
		end, -- 1008
		onEndViewing = function(____, callback) -- 1009
			endViewingHandler = callback -- 1009
		end, -- 1009
		setFlightViewing = function(____, flying, completed, mode, is3D, stage) -- 1010
			if not transferTutorial then -- 1010
				return -- 1011
			end -- 1011
			local key = ((((flying and "1" or "0") .. (completed and "1" or "0")) .. mode) .. (is3D and "1" or "0")) .. (stage ~= nil and stage or "") -- 1012
			if viewingKey == key then -- 1012
				return -- 1013
			end -- 1013
			viewingKey = key -- 1014
			if dvLabel ~= nil then -- 1014
				dvLabel.visible = not flying -- 1015
			end -- 1015
			if viewingLabel ~= nil then -- 1015
				viewingLabel.visible = flying -- 1017
				local near = stage == "Mercury" and "安全飞掠水星" or (stage == "Venus" and "金星减速借力" or (stage == "Jupiter" and "木星加速借力" or (stage == "Saturn" and "土星加速借力" or (stage == "Moon" and "借月球引力 · 观察轨迹转弯" or "滑行 · 观察航线")))) -- 1018
				setLabelText(viewingLabel, completed and (transferMode == "lunar" and "掠月完成 · 继续观察返回" or "目标完成 · 继续观察航线") or (stage == "Launch" and (transferMode == "inward" and "逆行点火 · 降低近日点" or "顺行点火 · 抬高" .. orbitName) or near)) -- 1019
				setLabelColor(viewingLabel, completed and 9430458 or ResultHintHex) -- 1020
			end -- 1020
			if cameraFocusButton ~= nil then -- 1020
				cameraFocusButton.root.visible = flying and is3D -- 1023
				cameraFocusButton:setEnabled(flying and is3D) -- 1024
				local title = mode == "Mercury" and "水星" or (mode == "Auto" and "自动" or (mode == "Probe" and "探测器" or (mode == "Moon" and "月球" or (mode == "Earth" and "地球" or (mode == "Venus" and "金星" or (mode == "Jupiter" and "木星" or (mode == "Saturn" and "土星" or (mode == "Sun" and "太阳" or "总览")))))))) -- 1025
				cameraFocusButton:setText("镜头 · " .. title) -- 1026
			end -- 1026
			if endViewingButton ~= nil then -- 1026
				endViewingButton.root.visible = flying and completed -- 1028
				endViewingButton:setEnabled(flying and completed) -- 1028
			end -- 1028
		end, -- 1010
		setViewMode = function(____, mode) -- 1030
			if mode == lastViewText then -- 1030
				return -- 1031
			end -- 1031
			lastViewText = mode -- 1032
			local btnText = mode == "2D" and "[ 3D ]" or "[ 2D ]" -- 1034
			viewButton:setText(btnText) -- 1035
		end, -- 1030
		onPlayback = function(____, callback) -- 1037
			playbackHandler = callback -- 1038
		end, -- 1037
		setPlayback = function(____, speed) -- 1040
			if speed == playbackSpeed then -- 1040
				return -- 1041
			end -- 1041
			playbackSpeed = speed -- 1042
			paintPlayback() -- 1043
		end, -- 1040
		setPlaybackVisible = function(____, on) -- 1045
			if on == playbackVisible then -- 1045
				return -- 1046
			end -- 1046
			playbackVisible = on -- 1047
			for ____, b in ipairs(playbackButtons) do -- 1048
				b.root.visible = on -- 1049
				b:setEnabled(on) -- 1050
			end -- 1050
		end, -- 1045
		setFullScreenAim = function(____, on) -- 1053
			fullScreenAim = on -- 1054
		end, -- 1053
		onWarp = function(____, callback) -- 1056
			warpHandler = callback -- 1057
		end, -- 1056
		setDate = function(____, t0, span) -- 1059
			dateSpan = span > 0 and span or 0 -- 1060
			applyWarpState() -- 1061
			local on = dateSpan > 0 -- 1062
			local text = on and (("发射日期 " .. __TS__NumberToFixed(t0, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0) or "发射日期" -- 1063
			if text ~= lastDateText then -- 1063
				lastDateText = text -- 1065
				setLabelText(dateLabel, text) -- 1066
			end -- 1066
		end, -- 1059
		setTimeEnabled = function(____, on) -- 1069
			if warpAllowed == on then -- 1069
				return -- 1070
			end -- 1070
			warpAllowed = on -- 1071
			applyWarpState() -- 1072
		end, -- 1069
		update = function(____, dt) -- 1074
			if not warpOn or warpHoldDir == 0 then -- 1074
				return -- 1075
			end -- 1075
			warpRepeatIn = warpRepeatIn - dt -- 1076
			if warpRepeatIn > 0 then -- 1076
				return -- 1077
			end -- 1077
			warpRepeatIn = TimeWarpStep / TimeWarpRate -- 1079
			if warpHandler ~= nil then -- 1079
				warpHandler(warpHoldDir) -- 1080
			end -- 1080
		end, -- 1074
		isDragging = function() return dragging end, -- 1082
		setBurnInfo = function(____, burn, budget) -- 1083
			if transferTutorial then -- 1083
				return -- 1084
			end -- 1084
			local b = budget < 1 and __TS__NumberToFixed(budget, 2) or __TS__NumberToFixed(budget, 0) -- 1088
			local v = burn < 1 and __TS__NumberToFixed(burn, 2) or __TS__NumberToFixed(burn, 1) -- 1089
			setLabelText(dvLabel, (("Δv " .. v) .. " / ") .. b) -- 1090
		end, -- 1083
		current = function() return aim end, -- 1092
		setTransferInfo = function(____, apoapsis, duration, reachable) -- 1093
			setLabelText( -- 1094
				dvLabel, -- 1094
				(((((orbitName .. " ") .. __TS__NumberToFixed(apoapsis, 0)) .. " · 点火 ") .. __TS__NumberToFixed(duration, 2)) .. "s") .. (reachable ~= nil and (reachable and (transferMode == "lunar" and " · 可减速掠月" or " · 航线可行") or " · 等待窗口") or "") -- 1094
			) -- 1094
		end, -- 1093
		setProbeOffset = function(____, offset) -- 1096
			probeOffset = offset -- 1097
		end, -- 1096
		handleLocal = function(____, ____local) -- 1101
			handleDelta(____exports.localToOffset(____local, space)) -- 1102
		end, -- 1101
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 1105
		debugProbeOffset = function() return probeOffset end, -- 1106
		onSpeedUp = function(____, callback) -- 1107
			speedUpHandler = callback -- 1108
		end, -- 1107
		onSpeedDown = function(____, callback) -- 1110
			speedDownHandler = callback -- 1111
		end, -- 1110
		onTogglePause = function(____, callback) -- 1113
			pauseHandler = callback -- 1114
		end, -- 1113
		setTimeControl = function(____, pow, minPow, maxPow, paused, missionSeconds, actualRate) -- 1116
			setTimeControl( -- 1117
				pow, -- 1117
				minPow, -- 1117
				maxPow, -- 1117
				paused, -- 1117
				missionSeconds, -- 1117
				actualRate -- 1117
			) -- 1117
		end, -- 1116
		onZoomIn = function(____, callback) -- 1119
			zoomInHandler = callback -- 1120
		end, -- 1119
		onZoomOut = function(____, callback) -- 1122
			zoomOutHandler = callback -- 1123
		end, -- 1122
		onFitView = function(____, callback) -- 1125
			fitViewHandler = callback -- 1126
		end, -- 1125
		setZoomControlsVisible = function(____, on) -- 1128
			setZoomVisible(on) -- 1129
		end, -- 1128
		setMissionDrawer = function(____, levelName, _challenges, currentRockets) -- 1131
			drawerLevelTitle = levelName -- 1132
			drawerRockets = currentRockets -- 1133
			updateDrawerDisplay() -- 1134
		end, -- 1131
		setMissionDrawerVisible = function(____, visible) -- 1136
			if drawerVisible == visible then -- 1136
				return -- 1137
			end -- 1137
			drawerVisible = visible -- 1138
			missionDrawerPlate.visible = visible -- 1139
		end, -- 1136
		setLiveFuelChallengeStatus = function(____, achieved) -- 1141
			if liveFuelBonus == achieved then -- 1141
				return -- 1142
			end -- 1142
			liveFuelBonus = achieved -- 1143
			updateDrawerDisplay() -- 1144
		end, -- 1141
		setIntroTourBanner = function(____, title, hint) -- 1146
			if introBannerTitle ~= nil then -- 1146
				setLabelText(introBannerTitle, title) -- 1147
			end -- 1147
			if introBannerHint ~= nil and hint ~= nil then -- 1147
				setLabelText(introBannerHint, hint) -- 1148
			end -- 1148
		end, -- 1146
		setIntroTourBannerVisible = function(____, visible) -- 1150
			introBannerPlate.visible = visible -- 1151
		end, -- 1150
		onSkipTour = function(____, callback) -- 1153
			skipTourHandler = callback -- 1154
		end, -- 1153
		setTourActiveChecker = function(____, fn) -- 1156
			tourActiveChecker = fn -- 1157
		end, -- 1156
		onQuickRetry = function(____, callback) -- 1159
			quickRetryHandler = callback -- 1160
		end, -- 1159
		setStarsStatus = function(____, starsGot) -- 1162
			updateStarsStatus(starsGot) -- 1163
		end, -- 1162
		setBonusStatus = function(____, got, total) -- 1165
			updateBonusStatus(got, total) -- 1165
		end, -- 1165
		setBonusFeedback = function(____, score) -- 1166
			if bonusToastLabel == nil then -- 1166
				return -- 1167
			end -- 1167
			bonusToastSerial = bonusToastSerial + 1 -- 1168
			local serial = bonusToastSerial -- 1169
			setLabelText( -- 1170
				bonusToastLabel, -- 1170
				"🚀 +" .. __TS__NumberToFixed(score, 0) -- 1170
			) -- 1170
			bonusToastLabel.visible = true -- 1171
			local elapsed = 0 -- 1172
			root:schedule(function(deltaTime) -- 1173
				elapsed = elapsed + deltaTime -- 1174
				if elapsed >= 0.6 then -- 1174
					if serial == bonusToastSerial then -- 1174
						bonusToastLabel.visible = false -- 1175
					end -- 1175
					return true -- 1175
				end -- 1175
				return false -- 1176
			end) -- 1173
		end, -- 1166
		root = root -- 1179
	} -- 1179
end -- 341
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 1302
	local root = createPanel( -- 1308
		parent, -- 1308
		viewW, -- 1308
		viewH, -- 1308
		ResultBackdropHex, -- 1308
		{alpha = 0.78} -- 1308
	) -- 1308
	local cardW = clampNumber(viewW * 0.9, 360, 560) -- 1310
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 480) -- 1311
	local btnH = clampNumber(viewH * 0.08, 48, 60) -- 1312
	local padX = (cardW - btnW) / 2 -- 1313
	local padY = 28 -- 1314
	local fontLevel = 24 -- 1316
	local fontRockets = 38 -- 1317
	local fontTitle = 30 -- 1318
	local fontTelemetry = 19 -- 1319
	local fontChallenge = 18 -- 1320
	local fontTotal = 20 -- 1321
	local btnFont = 24 -- 1322
	local rowGap = 12 -- 1323
	local hLevel = 28 -- 1325
	local hRockets = 42 -- 1326
	local hTitle = 34 -- 1327
	local hTelemetry = 24 -- 1328
	local hChallengeRow = 30 -- 1329
	local hChallenges = hChallengeRow * 3 -- 1330
	local hTotal = 24 -- 1331
	local cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7 -- 1333
	if cardH > viewH - 24 then -- 1333
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 1335
		cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7 -- 1336
	end -- 1336
	local card = createPanel( -- 1339
		root, -- 1339
		cardW, -- 1339
		cardH, -- 1339
		ResultCardHex, -- 1339
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 1339
	) -- 1339
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 1344
	local cursor = cardH - padY -- 1347
	cursor = cursor - hLevel -- 1349
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 1350
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 1351
	cursor = cursor - (rowGap + hRockets) -- 1353
	local rocketsLabel = createLabel(card, "", fontRockets, 16762939) -- 1354
	setLabelCenter(rocketsLabel, cardW / 2, cursor + hRockets / 2) -- 1355
	cursor = cursor - (rowGap + hTitle) -- 1357
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 1358
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 1359
	cursor = cursor - (rowGap + hTelemetry) -- 1361
	local telemetryLabel = createLabel(card, "", fontTelemetry, ResultHintHex) -- 1362
	setLabelCenter(telemetryLabel, cardW / 2, cursor + hTelemetry / 2) -- 1363
	cursor = cursor - rowGap -- 1365
	local challengeLabels = {} -- 1366
	do -- 1366
		local k = 0 -- 1367
		while k < 3 do -- 1367
			cursor = cursor - hChallengeRow -- 1368
			local cl = createLabel(card, "", fontChallenge, 10405355) -- 1369
			if cl ~= nil then -- 1369
				cl.textWidth = cardW - 60 -- 1371
				setLabelCenter(cl, cardW / 2, cursor + hChallengeRow / 2) -- 1372
				challengeLabels[#challengeLabels + 1] = cl -- 1373
			end -- 1373
			k = k + 1 -- 1367
		end -- 1367
	end -- 1367
	cursor = cursor - (rowGap + hTotal) -- 1377
	local totalLabel = createLabel(card, "", fontTotal, 16766073) -- 1378
	setLabelCenter(totalLabel, cardW / 2, cursor + hTotal / 2) -- 1379
	cursor = cursor - (rowGap + btnH) -- 1381
	local retryButton = createButton(card, { -- 1382
		w = btnW, -- 1383
		h = btnH, -- 1384
		text = "重试本关", -- 1385
		fontSize = btnFont, -- 1386
		bgHex = ResultButtonBgHex, -- 1387
		fgHex = ResultButtonFgHex, -- 1388
		borderHex = ResultButtonBorderHex, -- 1389
		fireOn = "press", -- 1390
		onTap = opts.onRetry -- 1391
	}) -- 1391
	retryButton.root.position = Vec2(padX, cursor) -- 1393
	cursor = cursor - (14 + btnH) -- 1395
	local backButton = createButton(card, { -- 1396
		w = btnW, -- 1397
		h = btnH, -- 1398
		text = "返回关卡选择", -- 1399
		fontSize = btnFont, -- 1400
		bgHex = ResultButtonAltBgHex, -- 1401
		fgHex = ResultButtonFgHex, -- 1402
		borderHex = ResultButtonBorderHex, -- 1403
		fireOn = "press", -- 1404
		onTap = opts.onBackToSelect -- 1405
	}) -- 1405
	backButton.root.position = Vec2(padX, cursor) -- 1407
	root.visible = false -- 1409
	retryButton:setEnabled(false) -- 1410
	backButton:setEnabled(false) -- 1411
	return { -- 1413
		root = root, -- 1414
		show = function(____, result, levelName, detail) -- 1415
			retryButton:setEnabled(true) -- 1416
			backButton:setEnabled(true) -- 1417
			setLabelText(levelLabel, levelName) -- 1418
			setLabelText( -- 1419
				titleLabel, -- 1419
				resultTitle(result) -- 1419
			) -- 1419
			setLabelColor( -- 1420
				titleLabel, -- 1420
				resultTitleColor(result) -- 1420
			) -- 1420
			if detail ~= nil then -- 1420
				if detail.completionOnly == true then -- 1420
					setLabelText( -- 1423
						titleLabel, -- 1423
						result == "success" and "引力借力完成" or resultTitle(result) -- 1423
					) -- 1423
				end -- 1423
				local rCount = detail.rocketsGot -- 1424
				local rStr = "☆  ☆  ☆" -- 1425
				if rCount == 1 then -- 1425
					rStr = "★  ☆  ☆" -- 1426
				elseif rCount == 2 then -- 1426
					rStr = "★  ★  ☆" -- 1427
				elseif rCount >= 3 then -- 1427
					rStr = "★  ★  ★" -- 1428
				end -- 1428
				setLabelText( -- 1429
					rocketsLabel, -- 1429
					detail.completionOnly == true and (result == "success" and "目标已完成" or "再试一次") or (detail.bonusPointCount ~= nil and (("火箭得分 " .. __TS__NumberToFixed(rCount, 0)) .. " / ") .. __TS__NumberToFixed(detail.bonusPointCount, 0) or rStr) -- 1429
				) -- 1429
				setLabelColor(rocketsLabel, rCount > 0 and 16762939 or 6322324) -- 1430
				local pct = detail.dvBudget > 0 and math.floor(detail.burnDv / detail.dvBudget * 100) or 0 -- 1432
				local telemText = ((((((("点火消耗 Δv: " .. __TS__NumberToFixed(detail.burnDv, 2)) .. " / ") .. __TS__NumberToFixed(detail.dvBudget, 2)) .. " (") .. __TS__NumberToFixed(pct, 0)) .. "%) · 用时: ") .. __TS__NumberToFixed(detail.flightTime, 1)) .. "s" -- 1433
				setLabelText(telemetryLabel, telemText) -- 1434
				do -- 1434
					local k = 0 -- 1436
					while k < 3 do -- 1436
						if challengeLabels[k + 1] ~= nil then -- 1436
							if k < #detail.challenges then -- 1436
								local ok = detail.achieved[k + 1] -- 1439
								local icon = ok and "★" or "☆" -- 1440
								local rank = k == 0 and "一星" or (k == 1 and "二星" or "三星") -- 1441
								local text = detail.completionOnly == true and (ok and "目标完成 · 记录已保存" or "尚未完成目标") or (((icon .. " [") .. rank) .. "] ") .. detail.challenges[k + 1] -- 1442
								setLabelText(challengeLabels[k + 1], text) -- 1443
								setLabelColor(challengeLabels[k + 1], ok and 16762939 or 6322324) -- 1444
								challengeLabels[k + 1].visible = true -- 1445
							else -- 1445
								challengeLabels[k + 1].visible = false -- 1447
							end -- 1447
						end -- 1447
						k = k + 1 -- 1436
					end -- 1436
				end -- 1436
				setLabelText( -- 1452
					totalLabel, -- 1452
					((("全深空火箭勋章: " .. __TS__NumberToFixed(detail.totalRockets, 0)) .. " / ") .. __TS__NumberToFixed(detail.totalPossibleRockets, 0)) .. " ★" -- 1452
				) -- 1452
				if totalLabel ~= nil then -- 1452
					totalLabel.visible = detail.completionOnly ~= true -- 1453
				end -- 1453
			else -- 1453
				setLabelText(rocketsLabel, result == "success" and "★  ☆  ☆" or "☆  ☆  ☆") -- 1455
				setLabelColor(rocketsLabel, result == "success" and 16762939 or 6322324) -- 1456
				setLabelText( -- 1457
					telemetryLabel, -- 1457
					resultBody(result) -- 1457
				) -- 1457
				do -- 1457
					local k = 0 -- 1458
					while k < #challengeLabels do -- 1458
						challengeLabels[k + 1].visible = false -- 1458
						k = k + 1 -- 1458
					end -- 1458
				end -- 1458
				if totalLabel ~= nil then -- 1458
					totalLabel.visible = false -- 1459
				end -- 1459
			end -- 1459
			root.visible = true -- 1461
		end, -- 1415
		hide = function() -- 1463
			root.visible = false -- 1464
			retryButton:setEnabled(false) -- 1465
			backButton:setEnabled(false) -- 1466
		end -- 1463
	} -- 1463
end -- 1302
local FinaleBackdropHex = 329484 -- 1481
local FinaleMainHex = 15398143 -- 1482
local FinaleSubHex = 10470632 -- 1483
--- 终章主文案（逐字；改之前先改 PLAN S3.18 与 docs/开发手册.md）。
____exports.FinaleMainText = "这就是我们整颗星球的样子 —— 而你已经从那里飞到了这里。" -- 1488
--- 终章小字：飞行距离 / 用时（纯函数，可单测）。
-- 
-- 距离是**平面单位**（关卡尺度，不是公里）—— 别在这里换算成天文单位，
-- 那一换就得把整条注释重写一遍，而玩家要的只是「飞了多远、花了多久」。
function ____exports.finaleSubtitle(distance, time) -- 1496
	return ((("飞行 " .. __TS__NumberToFixed(distance, 0)) .. " 单位 · 用时 ") .. __TS__NumberToFixed(time, 1)) .. " 秒" -- 1497
end -- 1496
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
function ____exports.createFinalePanel(parent, viewW, viewH, opts) -- 1527
	local root = createPanel( -- 1533
		parent, -- 1533
		viewW, -- 1533
		viewH, -- 1533
		FinaleBackdropHex, -- 1533
		{alpha = 0.55} -- 1533
	) -- 1533
	local fontMain = 34 -- 1535
	local fontSub = 30 -- 1536
	local btnFont = 40 -- 1537
	local mainLabel = createLabel(root, ____exports.FinaleMainText, fontMain, FinaleMainHex) -- 1539
	if mainLabel ~= nil then -- 1539
		mainLabel.textWidth = viewW * 0.88 -- 1542
		setLabelCenter(mainLabel, viewW / 2, viewH * 0.8) -- 1543
	end -- 1543
	local subLabel = createLabel(root, "", fontSub, FinaleSubHex) -- 1546
	if subLabel ~= nil then -- 1546
		setLabelCenter(subLabel, viewW / 2, viewH * 0.71) -- 1547
	end -- 1547
	local btnW = clampNumber(viewW * 0.62, MinButtonWidth, 560) -- 1549
	local btnH = clampNumber(viewH * 0.085, MinButtonHeight, 120) -- 1550
	local backButton = createButton(root, { -- 1551
		w = btnW, -- 1552
		h = btnH, -- 1553
		text = "返回关卡选择", -- 1554
		fontSize = btnFont, -- 1555
		bgHex = ResultButtonBgHex, -- 1556
		fgHex = ResultButtonFgHex, -- 1557
		borderHex = ResultButtonBorderHex, -- 1558
		fireOn = "press", -- 1560
		onTap = opts.onBackToSelect -- 1561
	}) -- 1561
	backButton.root.position = Vec2((viewW - btnW) / 2, 110) -- 1563
	root.visible = false -- 1565
	backButton:setEnabled(false) -- 1567
	return { -- 1569
		root = root, -- 1570
		show = function(____, main, sub) -- 1571
			setLabelText(mainLabel, main) -- 1572
			setLabelText(subLabel, sub) -- 1573
			backButton:setEnabled(true) -- 1574
			root.visible = true -- 1575
		end, -- 1571
		hide = function() -- 1577
			root.visible = false -- 1578
			backButton:setEnabled(false) -- 1580
		end -- 1577
	} -- 1577
end -- 1527
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 1619
	local root = createPanel( -- 1625
		parent, -- 1625
		viewW, -- 1625
		viewH, -- 1625
		SelectBackdropHex, -- 1625
		{alpha = 0.9} -- 1625
	) -- 1625
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 1627
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 1628
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 1630
	setLabelCenter( -- 1631
		subtitleLabel, -- 1631
		viewW / 2, -- 1631
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 1631
	) -- 1631
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 1633
	setLabelCenter( -- 1634
		hintLabel, -- 1634
		viewW / 2, -- 1634
		clampNumber(viewH * 0.045, 36, 90) -- 1634
	) -- 1634
	local count = #opts.levels -- 1636
	local cols = viewH > viewW and 2 or 1 -- 1639
	local rows = math.max( -- 1640
		1, -- 1640
		math.ceil(count / cols) -- 1640
	) -- 1640
	local gap = 18 -- 1641
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 1642
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 1643
	local availW = viewW * 0.84 -- 1644
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 1645
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 1646
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 1647
	local gridW = cols * btnW + gap * (cols - 1) -- 1648
	local topY = viewH - headerH -- 1649
	local buttons = {} -- 1651
	do -- 1651
		local i = 0 -- 1652
		while i < count do -- 1652
			local index = i -- 1654
			local button = createButton( -- 1655
				root, -- 1655
				{ -- 1655
					w = btnW, -- 1656
					h = btnH, -- 1657
					text = opts.levels[index + 1].name, -- 1658
					fontSize = 38, -- 1659
					bgHex = SelectLockedBgHex, -- 1660
					fgHex = SelectLockedFgHex, -- 1661
					borderHex = SelectBorderHex, -- 1662
					fireOn = "press", -- 1664
					onTap = function() return opts:onPick(index) end -- 1665
				} -- 1665
			) -- 1665
			local col = index % cols -- 1667
			local rowIndex = math.floor(index / cols) -- 1668
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 1669
			buttons[#buttons + 1] = button -- 1673
			i = i + 1 -- 1652
		end -- 1652
	end -- 1652
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 1679
		root, -- 1680
		{ -- 1680
			w = clampNumber(viewW * 0.36, 180, 300), -- 1681
			h = MinButtonHeight, -- 1682
			text = "重看开场", -- 1683
			fontSize = 30, -- 1684
			bgHex = SelectLockedBgHex, -- 1685
			fgHex = SelectSubtitleHex, -- 1686
			borderHex = SelectBorderHex, -- 1687
			fireOn = "press", -- 1688
			onTap = function() -- 1689
				if opts.onReplayIntro ~= nil then -- 1689
					opts:onReplayIntro() -- 1690
				end -- 1690
			end -- 1689
		} -- 1689
	) or nil -- 1689
	if replayButton ~= nil then -- 1689
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 1695
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 1696
		replayButton.root.position = Vec2( -- 1697
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 1697
			by -- 1697
		) -- 1697
	end -- 1697
	root.visible = false -- 1700
	do -- 1700
		local i = 0 -- 1701
		while i < count do -- 1701
			buttons[i + 1]:setEnabled(false) -- 1701
			i = i + 1 -- 1701
		end -- 1701
	end -- 1701
	if replayButton ~= nil then -- 1701
		replayButton:setEnabled(false) -- 1702
	end -- 1702
	return { -- 1704
		root = root, -- 1705
		show = function(____, unlocked) -- 1706
			local maxUnlocked = clampNumber( -- 1707
				math.floor(unlocked), -- 1707
				0, -- 1707
				count - 1 -- 1707
			) -- 1707
			setLabelText( -- 1708
				subtitleLabel, -- 1708
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 1708
			) -- 1708
			do -- 1708
				local i = 0 -- 1709
				while i < count do -- 1709
					local button = buttons[i + 1] -- 1710
					local open = i <= maxUnlocked -- 1711
					button:setEnabled(open) -- 1712
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 1713
					if open then -- 1713
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 1714
					else -- 1714
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 1715
					end -- 1715
					i = i + 1 -- 1709
				end -- 1709
			end -- 1709
			root.visible = true -- 1717
			if replayButton ~= nil then -- 1717
				replayButton:setEnabled(true) -- 1718
			end -- 1718
		end, -- 1706
		hide = function() -- 1720
			root.visible = false -- 1721
			do -- 1721
				local i = 0 -- 1723
				while i < count do -- 1723
					buttons[i + 1]:setEnabled(false) -- 1723
					i = i + 1 -- 1723
				end -- 1723
			end -- 1723
			if replayButton ~= nil then -- 1723
				replayButton:setEnabled(false) -- 1724
			end -- 1724
		end -- 1720
	} -- 1720
end -- 1619
return ____exports -- 1619