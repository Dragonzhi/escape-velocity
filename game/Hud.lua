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
function ____exports.createAimInput(parent, viewW, viewH, maxSpeed, minSpeed, speedChoices) -- 324
	local brakeOn, paintBrake, datePlate, dateLabel -- 324
	local speedMin = minSpeed ~= nil and minSpeed >= 0 and minSpeed < (maxSpeed ~= nil and maxSpeed or AimMaxSpeed) and minSpeed or AimMinSpeed -- 335
	local speedTop = maxSpeed ~= nil and maxSpeed > speedMin and maxSpeed or AimMaxSpeed -- 337
	local root = Node() -- 338
	root.size = Size(viewW, viewH) -- 339
	root.anchor = Vec2(0, 0) -- 345
	root.position = Vec2(0, 0) -- 346
	local touchLayer = Node() -- 349
	touchLayer.size = Size(viewW, viewH) -- 350
	touchLayer.anchor = Vec2(0.5, 0.5) -- 351
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 352
	touchLayer.swallowTouches = true -- 353
	root:addChild(touchLayer) -- 354
	local space = {viewW = viewW, viewH = viewH} -- 356
	local enabled = false -- 358
	local dragging = false -- 359
	--- 整屏瞄准（2D 模式）；由 Game 按视图状态同步。
	local fullScreenAim = false -- 361
	local aim = {velocity = {x = 0, y = -speedMin}, power = 0, unit = {x = 0, y = -1}} -- 362
	local probeOffset = {x = 0, y = 0} -- 365
	local dragHandler = nil -- 367
	local readyHandler = nil -- 368
	local observeHandler = nil -- 369
	local zoomHandler = nil -- 370
	local launchHandler = nil -- 371
	local pressOffset = {x = 0, y = 0} -- 382
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 385
		aim = ____exports.computeAim( -- 386
			{x = 0, y = 0}, -- 386
			delta, -- 386
			AimMaxDragPx, -- 386
			speedTop, -- 386
			speedMin -- 386
		) -- 386
		if dragHandler ~= nil then -- 386
			dragHandler(aim) -- 387
		end -- 387
	end -- 385
	local aimRadius = math.max(96, viewW * 0.25) -- 394
	local mode = "none" -- 395
	local observeLast = {x = 0, y = 0} -- 396
	touchLayer:onTapBegan(function(touch) -- 397
		if not enabled then -- 397
			return -- 398
		end -- 398
		local at = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 399
		local dx = at.x - probeOffset.x -- 400
		local dy = at.y - probeOffset.y -- 401
		if fullScreenAim or math.sqrt(dx * dx + dy * dy) <= aimRadius then -- 401
			mode = "aim" -- 403
			dragging = true -- 404
			pressOffset = at -- 405
			handleDelta({x = 0, y = 0}) -- 407
		else -- 407
			mode = "observe" -- 409
			observeLast = at -- 410
		end -- 410
	end) -- 397
	touchLayer:onTapMoved(function(touch) -- 414
		if not enabled then -- 414
			return -- 415
		end -- 415
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 416
		if mode == "aim" and dragging then -- 416
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 418
		elseif mode == "observe" then -- 418
			if observeHandler ~= nil then -- 418
				observeHandler(cur.x - observeLast.x, cur.y - observeLast.y) -- 421
			end -- 421
			observeLast = cur -- 422
		end -- 422
	end) -- 414
	touchLayer:onTapEnded(function(touch) -- 426
		if not enabled then -- 426
			return -- 427
		end -- 427
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 428
		if mode == "aim" then -- 428
			dragging = false -- 430
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 431
			if readyHandler ~= nil then -- 431
				readyHandler(aim) -- 433
			end -- 433
		end -- 433
		mode = "none" -- 435
	end) -- 426
	touchLayer:onGesture(function(_center, numFingers, deltaDist, _deltaAngle) -- 439
		if not enabled or numFingers < 2 then -- 439
			return -- 440
		end -- 440
		if zoomHandler ~= nil then -- 440
			zoomHandler(deltaDist) -- 441
		end -- 441
	end) -- 439
	touchLayer.touchEnabled = false -- 449
	local brakeHandler = nil -- 454
	local BrakeButtonW = 116 -- 455
	local BrakeButtonH = 64 -- 456
	local brakeGap = 8 -- 457
	local brakeButtons = {} -- 461
	local function makeBrakeButton(text, on, x) -- 462
		local btn = createButton( -- 463
			root, -- 463
			{ -- 463
				w = BrakeButtonW, -- 464
				h = BrakeButtonH, -- 465
				text = text, -- 466
				fontSize = 30, -- 467
				bgHex = ResultButtonAltBgHex, -- 468
				fgHex = ResultButtonFgHex, -- 469
				borderHex = ResultButtonBorderHex, -- 470
				onTap = function() -- 471
					brakeOn = on -- 474
					paintBrake() -- 475
					if brakeHandler ~= nil then -- 475
						brakeHandler(on) -- 476
					end -- 476
				end -- 471
			} -- 471
		) -- 471
		btn.root.position = Vec2(x, viewH - BrakeButtonH - 20) -- 479
		brakeButtons[#brakeButtons + 1] = btn -- 480
	end -- 462
	brakeOn = false -- 482
	paintBrake = function() -- 483
		if #brakeButtons < 2 then -- 483
			return -- 484
		end -- 484
		brakeButtons[1]:setColors(brakeOn and ResultButtonAltBgHex or ResultButtonBgHex, ResultButtonFgHex) -- 485
		brakeButtons[2]:setColors(brakeOn and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 486
	end -- 483
	createPanel( -- 492
		root, -- 492
		220, -- 492
		50, -- 492
		658964, -- 492
		{alpha = 0.45} -- 492
	) -- 492
	local dvLabel = createLabel(root, "Δv — / —", 30, ResultHintHex) -- 493
	if dvLabel ~= nil then -- 493
		dvLabel.position = Vec2(24, viewH - 44) -- 495
		dvLabel.anchor = Vec2(0, 0) -- 496
	end -- 496
	local warpHandler = nil -- 506
	local dateSpan = 0 -- 507
	--- 这一关有时间轴**且**当前相态允许改日期（Flying/Result 时必须是 false）。
	local warpOn = true -- 514
	local warpVisible = true -- 515
	--- 相态是否允许改日期（由主循环每帧 setTimeEnabled 同步）。
	local warpAllowed = true -- 517
	--- 上次写进日期的文字（避免每帧重设 Label 文本）。
	local lastDateText = "" -- 519
	--- >0 = 正在按住这个方向（-1 回退 / +1 加速）；0 = 没按住。
	local warpHoldDir = 0 -- 521
	--- 距离下一次连按还有多久（秒）。
	local warpRepeatIn = 0 -- 523
	local WarpButtonW = 116 -- 524
	local WarpButtonH = 64 -- 525
	local warpButtons = {} -- 526
	local function applyWarpState() -- 527
		local vis = dateSpan > 0 -- 528
		local on = vis and warpAllowed -- 529
		if vis == warpVisible and on == warpOn then -- 529
			return -- 530
		end -- 530
		warpVisible = vis -- 531
		warpOn = on -- 532
		if not on then -- 532
			warpHoldDir = 0 -- 533
		end -- 533
		for ____, b in ipairs(warpButtons) do -- 534
			b.root.visible = vis -- 535
			b:setEnabled(on) -- 536
		end -- 536
		if dateLabel ~= nil then -- 536
			dateLabel.visible = vis -- 538
		end -- 538
		datePlate.visible = vis -- 539
	end -- 527
	local function makeWarpButton(text, dir, x) -- 541
		local btn = createButton( -- 542
			root, -- 542
			{ -- 542
				w = WarpButtonW, -- 543
				h = WarpButtonH, -- 544
				text = text, -- 545
				fontSize = 30, -- 546
				bgHex = ResultButtonAltBgHex, -- 547
				fgHex = ResultButtonFgHex, -- 548
				borderHex = ResultButtonBorderHex, -- 549
				onTap = function() -- 552
				end, -- 552
				onPressBegan = function() -- 553
					print((("[escape-velocity] warp press dir=" .. __TS__NumberToFixed(dir, 0)) .. " on=") .. (warpOn and "1" or "0")) -- 555
					if not warpOn then -- 555
						return -- 556
					end -- 556
					if warpHoldDir == dir then -- 556
						return -- 558
					end -- 558
					warpHoldDir = dir -- 559
					warpRepeatIn = WarpHoldDelaySec -- 560
					if warpHandler ~= nil then -- 560
						warpHandler(dir) -- 561
					end -- 561
				end, -- 553
				onPressEnded = function() -- 563
					print((("[escape-velocity] warp release dir=" .. __TS__NumberToFixed(dir, 0)) .. " hold=") .. __TS__NumberToFixed(warpHoldDir, 0)) -- 564
					if warpHoldDir == dir then -- 564
						warpHoldDir = 0 -- 566
					end -- 566
				end -- 563
			} -- 563
		) -- 563
		btn.root.position = Vec2(x, viewH - 96 - WarpButtonH) -- 572
		warpButtons[#warpButtons + 1] = btn -- 573
	end -- 541
	local warpLeftX = viewW - (WarpButtonW * 2 + 8) - 20 -- 575
	makeWarpButton("◀ 回退", -1, warpLeftX) -- 576
	makeWarpButton("加速 ▶", 1, warpLeftX + WarpButtonW + 8) -- 577
	datePlate = createPanel( -- 579
		root, -- 579
		300, -- 579
		50, -- 579
		658964, -- 579
		{alpha = 0.45} -- 579
	) -- 579
	datePlate.position = Vec2(warpLeftX - 316, viewH - 96 - WarpButtonH + 8) -- 580
	dateLabel = createLabel(root, "发射日期 —", 30, ResultHintHex) -- 581
	if dateLabel ~= nil then -- 581
		dateLabel.anchor = Vec2(1, 0) -- 586
		dateLabel.position = Vec2(warpLeftX - 16, viewH - 96 - WarpButtonH + 18) -- 587
	end -- 587
	local LaunchButtonW = 220 -- 592
	local LaunchButtonH = 112 -- 593
	local launchButton = createButton( -- 594
		root, -- 594
		{ -- 594
			w = LaunchButtonW, -- 595
			h = LaunchButtonH, -- 596
			text = "▲ 发射 ▲", -- 597
			fontSize = 38, -- 598
			bgHex = ResultButtonBgHex, -- 599
			fgHex = ResultButtonFgHex, -- 600
			borderHex = ResultButtonBorderHex, -- 601
			fireOn = "press", -- 602
			onTap = function() -- 603
				print("[escape-velocity] launch button fire (press)") -- 604
				if launchHandler ~= nil then -- 604
					launchHandler() -- 605
				end -- 605
			end -- 603
		} -- 603
	) -- 603
	launchButton.root.position = Vec2(viewW - LaunchButtonW - 24, 96) -- 608
	launchButton.root.visible = false -- 609
	launchButton:setEnabled(false) -- 610
	local ViewButtonW = 116 -- 614
	local ViewButtonH = 64 -- 615
	local viewHandler = nil -- 616
	local viewButton = createButton( -- 617
		root, -- 617
		{ -- 617
			w = ViewButtonW, -- 618
			h = ViewButtonH, -- 619
			text = "[ 3D ]", -- 620
			fontSize = 26, -- 621
			bgHex = ResultButtonAltBgHex, -- 622
			fgHex = ResultButtonFgHex, -- 623
			borderHex = ResultButtonBorderHex, -- 624
			fireOn = "press", -- 625
			onTap = function() -- 626
				print("[escape-velocity] view toggle fire (press)") -- 627
				if viewHandler ~= nil then -- 627
					viewHandler() -- 628
				end -- 628
			end -- 626
		} -- 626
	) -- 626
	viewButton.root.position = Vec2(viewW - ViewButtonW - 24, 96 + LaunchButtonH + 12) -- 631
	--- 上次写进按钮的文字（每帧都会被 setViewMode 调用，没变就别碰 Label）。
	local lastViewText = "2D" -- 633
	local ZoomBtnSize = 58 -- 636
	local zoomGap = 8 -- 637
	local zoomButtons = {} -- 638
	local zoomInHandler = nil -- 639
	local zoomOutHandler = nil -- 640
	local fitViewHandler = nil -- 641
	local function makeZoomButton(text, x, fontSize, onClick) -- 643
		local btn = createButton( -- 644
			root, -- 644
			{ -- 644
				w = ZoomBtnSize, -- 645
				h = ZoomBtnSize, -- 646
				text = text, -- 647
				fontSize = fontSize, -- 648
				bgHex = ResultButtonAltBgHex, -- 649
				fgHex = ResultButtonFgHex, -- 650
				borderHex = ResultButtonBorderHex, -- 651
				fireOn = "press", -- 652
				onTap = function() -- 653
					print(("[escape-velocity] zoom btn " .. text) .. " fire") -- 654
					onClick() -- 655
				end -- 653
			} -- 653
		) -- 653
		btn.root.position = Vec2(x, 96) -- 658
		btn.root.visible = false -- 659
		btn:setEnabled(false) -- 660
		zoomButtons[#zoomButtons + 1] = btn -- 661
		return btn -- 662
	end -- 643
	makeZoomButton( -- 664
		"−", -- 664
		24, -- 664
		32, -- 664
		function() -- 664
			if zoomOutHandler ~= nil then -- 664
				zoomOutHandler() -- 665
			end -- 665
		end -- 664
	) -- 664
	makeZoomButton( -- 667
		"FIT", -- 667
		24 + ZoomBtnSize + zoomGap, -- 667
		20, -- 667
		function() -- 667
			if fitViewHandler ~= nil then -- 667
				fitViewHandler() -- 668
			end -- 668
		end -- 667
	) -- 667
	makeZoomButton( -- 670
		"+", -- 670
		24 + (ZoomBtnSize + zoomGap) * 2, -- 670
		32, -- 670
		function() -- 670
			if zoomInHandler ~= nil then -- 670
				zoomInHandler() -- 671
			end -- 671
		end -- 670
	) -- 670
	local zoomControlsVisible = nil -- 673
	local function setZoomVisible(on) -- 674
		if zoomControlsVisible == on then -- 674
			return -- 675
		end -- 675
		zoomControlsVisible = on -- 676
		for ____, b in ipairs(zoomButtons) do -- 677
			b.root.visible = on -- 678
			b:setEnabled(on) -- 679
		end -- 679
	end -- 674
	setZoomVisible(false) -- 682
	local DrawerW = 380 -- 685
	local DrawerH = 46 -- 686
	local missionDrawerPlate = createPanel( -- 687
		root, -- 687
		DrawerW, -- 687
		DrawerH, -- 687
		658964, -- 687
		{alpha = 0.65, borderHex = 4610157} -- 687
	) -- 687
	missionDrawerPlate.position = Vec2((viewW - DrawerW) / 2, viewH - 56) -- 688
	local missionTitleLabel = createLabel(missionDrawerPlate, "", 19, 13426158) -- 689
	if missionTitleLabel ~= nil then -- 689
		missionTitleLabel.anchor = Vec2(0, 0.5) -- 691
		missionTitleLabel.position = Vec2(14, DrawerH / 2) -- 692
	end -- 692
	local missionRocketsLabel = createLabel(missionDrawerPlate, "☆  ☆  ☆", 22, 16766720) -- 694
	if missionRocketsLabel ~= nil then -- 694
		missionRocketsLabel.anchor = Vec2(1, 0.5) -- 696
		missionRocketsLabel.position = Vec2(DrawerW - 14, DrawerH / 2) -- 697
	end -- 697
	missionDrawerPlate.visible = false -- 699
	local drawerVisible = false -- 700
	local drawerLevelTitle = "" -- 701
	local drawerRockets = 0 -- 702
	local liveFuelBonus = false -- 703
	local function updateDrawerDisplay() -- 705
		if missionTitleLabel ~= nil then -- 705
			setLabelText(missionTitleLabel, drawerLevelTitle) -- 707
		end -- 707
		if missionRocketsLabel ~= nil then -- 707
			local r1 = drawerRockets >= 1 and "★" or "☆" -- 710
			local r2 = (drawerRockets >= 2 or liveFuelBonus) and "★" or "☆" -- 711
			local r3 = drawerRockets >= 3 and "★" or "☆" -- 712
			setLabelText(missionRocketsLabel, (((r1 .. "  ") .. r2) .. "  ") .. r3) -- 713
		end -- 713
	end -- 705
	local PlaybackButtonW = 116 -- 724
	local PlaybackButtonH = 64 -- 725
	local playbackGap = 10 -- 726
	local playbackButtons = {} -- 727
	local playbackSpeeds = {} -- 728
	local playbackHandler = nil -- 729
	local speedChoice = speedChoices ~= nil and #speedChoices > 0 and speedChoices or ({1, 2, 4}) -- 732
	local playbackSpeed = speedChoice[1] -- 733
	--- 已应用到节点上的显隐状态。初值 false 如实反映"建出来就隐藏"（照 warp 按钮的教训）。
	local playbackVisible = false -- 735
	local function paintPlayback() -- 736
		do -- 736
			local i = 0 -- 737
			while i < #playbackButtons do -- 737
				local on = playbackSpeeds[i + 1] == playbackSpeed -- 738
				playbackButtons[i + 1]:setColors(on and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 739
				i = i + 1 -- 737
			end -- 737
		end -- 737
	end -- 736
	local function makePlaybackButton(speed, x) -- 742
		local btn = createButton( -- 743
			root, -- 743
			{ -- 743
				w = PlaybackButtonW, -- 744
				h = PlaybackButtonH, -- 745
				text = ____exports.playbackLabel(speed), -- 746
				fontSize = 30, -- 747
				bgHex = ResultButtonAltBgHex, -- 748
				fgHex = ResultButtonFgHex, -- 749
				borderHex = ResultButtonBorderHex, -- 750
				onTap = function() -- 751
					print(("[escape-velocity] playback button fire " .. __TS__NumberToFixed(speed, 0)) .. "x (release)") -- 753
					playbackSpeed = speed -- 754
					paintPlayback() -- 755
					if playbackHandler ~= nil then -- 755
						playbackHandler(speed) -- 756
					end -- 756
				end -- 751
			} -- 751
		) -- 751
		btn.root.position = Vec2(x, 96) -- 761
		playbackButtons[#playbackButtons + 1] = btn -- 762
		playbackSpeeds[#playbackSpeeds + 1] = speed -- 763
	end -- 742
	do -- 742
		local i = 0 -- 765
		while i < #speedChoice and i < 3 do -- 765
			makePlaybackButton(speedChoice[i + 1], 24 + (PlaybackButtonW + playbackGap) * i) -- 766
			i = i + 1 -- 765
		end -- 765
	end -- 765
	paintPlayback() -- 768
	for ____, b in ipairs(playbackButtons) do -- 770
		b.root.visible = false -- 771
		b:setEnabled(false) -- 772
	end -- 772
	local brakeRightX = viewW - BrakeButtonW - 20 -- 775
	makeBrakeButton("惯性", false, brakeRightX - BrakeButtonW - brakeGap) -- 776
	makeBrakeButton("刹车", true, brakeRightX) -- 777
	paintBrake() -- 778
	local liveBrakeHandler = nil -- 781
	local liveBrakeActive = false -- 782
	local liveBrakedState = false -- 783
	local LiveBrakeW = 220 -- 784
	local LiveBrakeH = 100 -- 785
	local liveBrakeButton = createButton( -- 786
		root, -- 786
		{ -- 786
			w = LiveBrakeW, -- 787
			h = LiveBrakeH, -- 788
			text = "BRAKE 逆喷", -- 789
			fontSize = 36, -- 790
			bgHex = 10899464, -- 791
			fgHex = 16775392, -- 792
			borderHex = 16755251, -- 793
			fireOn = "press", -- 794
			onTap = function() -- 795
				print("[escape-velocity] live brake button fire (press)") -- 796
				if liveBrakeHandler ~= nil then -- 796
					liveBrakeHandler() -- 797
				end -- 797
			end -- 795
		} -- 795
	) -- 795
	liveBrakeButton.root.position = Vec2(viewW - LiveBrakeW - 24, 96) -- 800
	liveBrakeButton.root.visible = false -- 801
	liveBrakeButton:setEnabled(false) -- 802
	local hintW = 440 -- 805
	local hintH = 50 -- 806
	local brakeHintPlate = createPanel( -- 807
		root, -- 807
		hintW, -- 807
		hintH, -- 807
		658964, -- 807
		{alpha = 0.65, borderHex = 16755251} -- 807
	) -- 807
	brakeHintPlate.position = Vec2((viewW - hintW) / 2, viewH - 240) -- 808
	local brakeHintLabel = createLabel(brakeHintPlate, "【木星捕获窗口已开启 · 按下 BRAKE 逆喷入轨】", 22, 16762939) -- 809
	if brakeHintLabel ~= nil then -- 809
		setLabelCenter(brakeHintLabel, hintW / 2, hintH / 2) -- 811
	end -- 811
	brakeHintPlate.visible = false -- 813
	parent:addChild(root) -- 815
	return { -- 817
		onDrag = function(____, callback) -- 818
			dragHandler = callback -- 819
		end, -- 818
		setEnabled = function(____, value) -- 821
			enabled = value -- 822
			touchLayer.touchEnabled = value -- 825
			if not value then -- 825
				dragging = false -- 827
				liveBrakeActive = false -- 828
				liveBrakeButton.root.visible = false -- 829
				liveBrakeButton:setEnabled(false) -- 830
				brakeHintPlate.visible = false -- 831
			end -- 831
		end, -- 821
		onBrake = function(____, callback) -- 834
			brakeHandler = callback -- 835
		end, -- 834
		setBrake = function(____, on) -- 837
			brakeOn = on -- 838
			paintBrake() -- 839
		end, -- 837
		onAimReady = function(____, callback) -- 841
			readyHandler = callback -- 842
		end, -- 841
		onObserve = function(____, callback) -- 844
			observeHandler = callback -- 845
		end, -- 844
		onZoom = function(____, callback) -- 847
			zoomHandler = callback -- 848
		end, -- 847
		onLaunch = function(____, callback) -- 850
			launchHandler = callback -- 851
		end, -- 850
		setArmed = function(____, armed) -- 853
			launchButton.root.visible = armed -- 854
			launchButton:setEnabled(armed) -- 855
		end, -- 853
		onViewToggle = function(____, callback) -- 857
			viewHandler = callback -- 858
		end, -- 857
		setViewMode = function(____, mode) -- 860
			if mode == lastViewText then -- 860
				return -- 861
			end -- 861
			lastViewText = mode -- 862
			local btnText = mode == "2D" and "[ 3D ]" or "[ 2D ]" -- 864
			viewButton:setText(btnText) -- 865
		end, -- 860
		onPlayback = function(____, callback) -- 867
			playbackHandler = callback -- 868
		end, -- 867
		setPlayback = function(____, speed) -- 870
			if speed == playbackSpeed then -- 870
				return -- 871
			end -- 871
			playbackSpeed = speed -- 872
			paintPlayback() -- 873
		end, -- 870
		setPlaybackVisible = function(____, on) -- 875
			if on == playbackVisible then -- 875
				return -- 876
			end -- 876
			playbackVisible = on -- 877
			for ____, b in ipairs(playbackButtons) do -- 878
				b.root.visible = on -- 879
				b:setEnabled(on) -- 880
			end -- 880
		end, -- 875
		setFullScreenAim = function(____, on) -- 883
			fullScreenAim = on -- 884
		end, -- 883
		onWarp = function(____, callback) -- 886
			warpHandler = callback -- 887
		end, -- 886
		setDate = function(____, t0, span) -- 889
			dateSpan = span > 0 and span or 0 -- 890
			applyWarpState() -- 891
			local on = dateSpan > 0 -- 892
			local text = on and (("发射日期 " .. __TS__NumberToFixed(t0, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0) or "发射日期" -- 893
			if text ~= lastDateText then -- 893
				lastDateText = text -- 895
				setLabelText(dateLabel, text) -- 896
			end -- 896
		end, -- 889
		setTimeEnabled = function(____, on) -- 899
			if warpAllowed == on then -- 899
				return -- 900
			end -- 900
			warpAllowed = on -- 901
			applyWarpState() -- 902
		end, -- 899
		update = function(____, dt) -- 904
			if not warpOn or warpHoldDir == 0 then -- 904
				return -- 905
			end -- 905
			warpRepeatIn = warpRepeatIn - dt -- 906
			if warpRepeatIn > 0 then -- 906
				return -- 907
			end -- 907
			warpRepeatIn = TimeWarpStep / TimeWarpRate -- 909
			if warpHandler ~= nil then -- 909
				warpHandler(warpHoldDir) -- 910
			end -- 910
		end, -- 904
		isDragging = function() return dragging end, -- 912
		setBurnInfo = function(____, burn, budget) -- 913
			local b = budget < 1 and __TS__NumberToFixed(budget, 2) or __TS__NumberToFixed(budget, 0) -- 917
			local v = burn < 1 and __TS__NumberToFixed(burn, 2) or __TS__NumberToFixed(burn, 1) -- 918
			setLabelText(dvLabel, (("Δv " .. v) .. " / ") .. b) -- 919
		end, -- 913
		current = function() return aim end, -- 921
		setProbeOffset = function(____, offset) -- 922
			probeOffset = offset -- 923
		end, -- 922
		handleLocal = function(____, ____local) -- 927
			handleDelta(____exports.localToOffset(____local, space)) -- 928
		end, -- 927
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 931
		debugProbeOffset = function() return probeOffset end, -- 932
		onLiveBrake = function(____, callback) -- 933
			liveBrakeHandler = callback -- 934
		end, -- 933
		setLiveBrakeVisible = function(____, visible) -- 936
			if liveBrakeActive == visible then -- 936
				return -- 937
			end -- 937
			liveBrakeActive = visible -- 938
			liveBrakeButton.root.visible = visible -- 939
			liveBrakeButton:setEnabled(visible) -- 940
			brakeHintPlate.visible = visible -- 941
		end, -- 936
		setLiveBraked = function(____, braked) -- 943
			if liveBrakedState == braked then -- 943
				return -- 944
			end -- 944
			liveBrakedState = braked -- 945
			if braked then -- 945
				liveBrakeButton:setText("已捕获入轨") -- 947
				liveBrakeButton:setColors(1589810, 13697002) -- 948
				liveBrakeButton:setEnabled(false) -- 949
				if brakeHintLabel ~= nil then -- 949
					setLabelText(brakeHintLabel, "【主发动机逆喷成功！已捕获入轨】") -- 951
					setLabelColor(brakeHintLabel, 4122272) -- 952
				end -- 952
			else -- 952
				liveBrakeButton:setText("BRAKE 逆喷") -- 955
				liveBrakeButton:setColors(10899464, 16775392) -- 956
				if brakeHintLabel ~= nil then -- 956
					setLabelText(brakeHintLabel, "【木星捕获窗口已开启 · 按下 BRAKE 逆喷入轨】") -- 958
					setLabelColor(brakeHintLabel, 16762939) -- 959
				end -- 959
			end -- 959
		end, -- 943
		onZoomIn = function(____, callback) -- 963
			zoomInHandler = callback -- 964
		end, -- 963
		onZoomOut = function(____, callback) -- 966
			zoomOutHandler = callback -- 967
		end, -- 966
		onFitView = function(____, callback) -- 969
			fitViewHandler = callback -- 970
		end, -- 969
		setZoomControlsVisible = function(____, on) -- 972
			setZoomVisible(on) -- 973
		end, -- 972
		setMissionDrawer = function(____, levelName, _challenges, currentRockets) -- 975
			drawerLevelTitle = levelName -- 976
			drawerRockets = currentRockets -- 977
			updateDrawerDisplay() -- 978
		end, -- 975
		setMissionDrawerVisible = function(____, visible) -- 980
			if drawerVisible == visible then -- 980
				return -- 981
			end -- 981
			drawerVisible = visible -- 982
			missionDrawerPlate.visible = visible -- 983
		end, -- 980
		setLiveFuelChallengeStatus = function(____, achieved) -- 985
			if liveFuelBonus == achieved then -- 985
				return -- 986
			end -- 986
			liveFuelBonus = achieved -- 987
			updateDrawerDisplay() -- 988
		end, -- 985
		root = root -- 990
	} -- 990
end -- 324
local ResultBackdropHex = 329484 -- 1007
local ResultCardHex = 1252395 -- 1008
local ResultCardBorderHex = 3362938 -- 1009
local ResultLevelHex = 9417948 -- 1010
local ResultBodyHex = 14149367 -- 1011
ResultHintHex = 8229803 -- 1012
ResultButtonBgHex = 1919610 -- 1013
ResultButtonAltBgHex = 1779509 -- 1014
ResultButtonFgHex = 15398143 -- 1015
ResultButtonBorderHex = 5211846 -- 1016
local TitleSuccessHex = 8381344 -- 1017
local TitleMissedHex = 16766073 -- 1018
local TitleCrashedHex = 16743019 -- 1019
local SelectBackdropHex = 329484 -- 1021
local SelectTitleHex = 16777215 -- 1022
local SelectSubtitleHex = 10470632 -- 1023
local SelectHintHex = 7309478 -- 1024
local SelectOpenBgHex = 1919610 -- 1025
local SelectOpenFgHex = 15398143 -- 1026
local SelectLockedBgHex = 1383204 -- 1027
local SelectLockedFgHex = 6912140 -- 1028
local SelectBorderHex = 4157096 -- 1029
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 1032
	if value < lo then -- 1032
		return lo -- 1033
	end -- 1033
	if value > hi then -- 1033
		return hi -- 1034
	end -- 1034
	return value -- 1035
end -- 1032
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 1039
	if result == "success" then -- 1039
		return "借力成功" -- 1040
	end -- 1040
	if result == "crashed" then -- 1040
		return "信号中断" -- 1041
	end -- 1041
	return "错过目标" -- 1042
end -- 1039
--- 三态说明句（逐字）。
local function resultBody(result) -- 1046
	if result == "success" then -- 1046
		return "行星把探测器甩了出去，速度够了。" -- 1047
	end -- 1047
	if result == "crashed" then -- 1047
		return "探测器撞上行星，任务到此为止。" -- 1048
	end -- 1048
	return "从行星身侧掠过，没能借到那一点速度。" -- 1049
end -- 1046
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 1053
	if result == "success" then -- 1053
		return TitleSuccessHex -- 1054
	end -- 1054
	if result == "crashed" then -- 1054
		return TitleCrashedHex -- 1055
	end -- 1055
	return TitleMissedHex -- 1056
end -- 1053
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 1065
	if result == "success" then -- 1065
		return "下一关已解锁" -- 1066
	end -- 1066
	return "可重试本关，或返回关卡选择" -- 1067
end -- 1065
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 1111
	local root = createPanel( -- 1117
		parent, -- 1117
		viewW, -- 1117
		viewH, -- 1117
		ResultBackdropHex, -- 1117
		{alpha = 0.78} -- 1117
	) -- 1117
	local cardW = clampNumber(viewW * 0.9, 360, 560) -- 1119
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 480) -- 1120
	local btnH = clampNumber(viewH * 0.08, 48, 60) -- 1121
	local padX = (cardW - btnW) / 2 -- 1122
	local padY = 28 -- 1123
	local fontLevel = 24 -- 1125
	local fontRockets = 38 -- 1126
	local fontTitle = 30 -- 1127
	local fontTelemetry = 19 -- 1128
	local fontChallenge = 18 -- 1129
	local fontTotal = 20 -- 1130
	local btnFont = 24 -- 1131
	local rowGap = 12 -- 1132
	local hLevel = 28 -- 1134
	local hRockets = 42 -- 1135
	local hTitle = 34 -- 1136
	local hTelemetry = 24 -- 1137
	local hChallengeRow = 30 -- 1138
	local hChallenges = hChallengeRow * 3 -- 1139
	local hTotal = 24 -- 1140
	local cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7 -- 1142
	if cardH > viewH - 24 then -- 1142
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 1144
		cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7 -- 1145
	end -- 1145
	local card = createPanel( -- 1148
		root, -- 1148
		cardW, -- 1148
		cardH, -- 1148
		ResultCardHex, -- 1148
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 1148
	) -- 1148
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 1153
	local cursor = cardH - padY -- 1156
	cursor = cursor - hLevel -- 1158
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 1159
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 1160
	cursor = cursor - (rowGap + hRockets) -- 1162
	local rocketsLabel = createLabel(card, "", fontRockets, 16762939) -- 1163
	setLabelCenter(rocketsLabel, cardW / 2, cursor + hRockets / 2) -- 1164
	cursor = cursor - (rowGap + hTitle) -- 1166
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 1167
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 1168
	cursor = cursor - (rowGap + hTelemetry) -- 1170
	local telemetryLabel = createLabel(card, "", fontTelemetry, ResultHintHex) -- 1171
	setLabelCenter(telemetryLabel, cardW / 2, cursor + hTelemetry / 2) -- 1172
	cursor = cursor - rowGap -- 1174
	local challengeLabels = {} -- 1175
	do -- 1175
		local k = 0 -- 1176
		while k < 3 do -- 1176
			cursor = cursor - hChallengeRow -- 1177
			local cl = createLabel(card, "", fontChallenge, 10405355) -- 1178
			if cl ~= nil then -- 1178
				cl.textWidth = cardW - 60 -- 1180
				setLabelCenter(cl, cardW / 2, cursor + hChallengeRow / 2) -- 1181
				challengeLabels[#challengeLabels + 1] = cl -- 1182
			end -- 1182
			k = k + 1 -- 1176
		end -- 1176
	end -- 1176
	cursor = cursor - (rowGap + hTotal) -- 1186
	local totalLabel = createLabel(card, "", fontTotal, 16766073) -- 1187
	setLabelCenter(totalLabel, cardW / 2, cursor + hTotal / 2) -- 1188
	cursor = cursor - (rowGap + btnH) -- 1190
	local retryButton = createButton(card, { -- 1191
		w = btnW, -- 1192
		h = btnH, -- 1193
		text = "重试本关", -- 1194
		fontSize = btnFont, -- 1195
		bgHex = ResultButtonBgHex, -- 1196
		fgHex = ResultButtonFgHex, -- 1197
		borderHex = ResultButtonBorderHex, -- 1198
		fireOn = "press", -- 1199
		onTap = opts.onRetry -- 1200
	}) -- 1200
	retryButton.root.position = Vec2(padX, cursor) -- 1202
	cursor = cursor - (14 + btnH) -- 1204
	local backButton = createButton(card, { -- 1205
		w = btnW, -- 1206
		h = btnH, -- 1207
		text = "返回关卡选择", -- 1208
		fontSize = btnFont, -- 1209
		bgHex = ResultButtonAltBgHex, -- 1210
		fgHex = ResultButtonFgHex, -- 1211
		borderHex = ResultButtonBorderHex, -- 1212
		fireOn = "press", -- 1213
		onTap = opts.onBackToSelect -- 1214
	}) -- 1214
	backButton.root.position = Vec2(padX, cursor) -- 1216
	root.visible = false -- 1218
	retryButton:setEnabled(false) -- 1219
	backButton:setEnabled(false) -- 1220
	return { -- 1222
		root = root, -- 1223
		show = function(____, result, levelName, detail) -- 1224
			retryButton:setEnabled(true) -- 1225
			backButton:setEnabled(true) -- 1226
			setLabelText(levelLabel, levelName) -- 1227
			setLabelText( -- 1228
				titleLabel, -- 1228
				resultTitle(result) -- 1228
			) -- 1228
			setLabelColor( -- 1229
				titleLabel, -- 1229
				resultTitleColor(result) -- 1229
			) -- 1229
			if detail ~= nil then -- 1229
				local rCount = detail.rocketsGot -- 1232
				local rStr = "☆  ☆  ☆" -- 1233
				if rCount == 1 then -- 1233
					rStr = "★  ☆  ☆" -- 1234
				elseif rCount == 2 then -- 1234
					rStr = "★  ★  ☆" -- 1235
				elseif rCount >= 3 then -- 1235
					rStr = "★  ★  ★" -- 1236
				end -- 1236
				setLabelText(rocketsLabel, rStr) -- 1237
				setLabelColor(rocketsLabel, rCount > 0 and 16762939 or 6322324) -- 1238
				local pct = detail.dvBudget > 0 and math.floor(detail.burnDv / detail.dvBudget * 100) or 0 -- 1240
				local telemText = ((((((("点火消耗 Δv: " .. __TS__NumberToFixed(detail.burnDv, 2)) .. " / ") .. __TS__NumberToFixed(detail.dvBudget, 2)) .. " (") .. __TS__NumberToFixed(pct, 0)) .. "%) · 用时: ") .. __TS__NumberToFixed(detail.flightTime, 1)) .. "s" -- 1241
				setLabelText(telemetryLabel, telemText) -- 1242
				do -- 1242
					local k = 0 -- 1244
					while k < 3 do -- 1244
						if challengeLabels[k + 1] ~= nil then -- 1244
							if k < #detail.challenges then -- 1244
								local ok = detail.achieved[k + 1] -- 1247
								local icon = ok and "★" or "☆" -- 1248
								local rank = k == 0 and "一星" or (k == 1 and "二星" or "三星") -- 1249
								local text = (((icon .. " [") .. rank) .. "] ") .. detail.challenges[k + 1] -- 1250
								setLabelText(challengeLabels[k + 1], text) -- 1251
								setLabelColor(challengeLabels[k + 1], ok and 16762939 or 6322324) -- 1252
								challengeLabels[k + 1].visible = true -- 1253
							else -- 1253
								challengeLabels[k + 1].visible = false -- 1255
							end -- 1255
						end -- 1255
						k = k + 1 -- 1244
					end -- 1244
				end -- 1244
				setLabelText( -- 1260
					totalLabel, -- 1260
					((("全深空火箭勋章: " .. __TS__NumberToFixed(detail.totalRockets, 0)) .. " / ") .. __TS__NumberToFixed(detail.totalPossibleRockets, 0)) .. " ★" -- 1260
				) -- 1260
				if totalLabel ~= nil then -- 1260
					totalLabel.visible = true -- 1261
				end -- 1261
			else -- 1261
				setLabelText(rocketsLabel, result == "success" and "★  ☆  ☆" or "☆  ☆  ☆") -- 1263
				setLabelColor(rocketsLabel, result == "success" and 16762939 or 6322324) -- 1264
				setLabelText( -- 1265
					telemetryLabel, -- 1265
					resultBody(result) -- 1265
				) -- 1265
				do -- 1265
					local k = 0 -- 1266
					while k < #challengeLabels do -- 1266
						challengeLabels[k + 1].visible = false -- 1266
						k = k + 1 -- 1266
					end -- 1266
				end -- 1266
				if totalLabel ~= nil then -- 1266
					totalLabel.visible = false -- 1267
				end -- 1267
			end -- 1267
			root.visible = true -- 1269
		end, -- 1224
		hide = function() -- 1271
			root.visible = false -- 1272
			retryButton:setEnabled(false) -- 1273
			backButton:setEnabled(false) -- 1274
		end -- 1271
	} -- 1271
end -- 1111
local FinaleBackdropHex = 329484 -- 1289
local FinaleMainHex = 15398143 -- 1290
local FinaleSubHex = 10470632 -- 1291
--- 终章主文案（逐字；改之前先改 PLAN S3.18 与 docs/开发手册.md）。
____exports.FinaleMainText = "这就是我们整颗星球的样子 —— 而你已经从那里飞到了这里。" -- 1296
--- 终章小字：飞行距离 / 用时（纯函数，可单测）。
-- 
-- 距离是**平面单位**（关卡尺度，不是公里）—— 别在这里换算成天文单位，
-- 那一换就得把整条注释重写一遍，而玩家要的只是「飞了多远、花了多久」。
function ____exports.finaleSubtitle(distance, time) -- 1304
	return ((("飞行 " .. __TS__NumberToFixed(distance, 0)) .. " 单位 · 用时 ") .. __TS__NumberToFixed(time, 1)) .. " 秒" -- 1305
end -- 1304
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
function ____exports.createFinalePanel(parent, viewW, viewH, opts) -- 1335
	local root = createPanel( -- 1341
		parent, -- 1341
		viewW, -- 1341
		viewH, -- 1341
		FinaleBackdropHex, -- 1341
		{alpha = 0.55} -- 1341
	) -- 1341
	local fontMain = 34 -- 1343
	local fontSub = 30 -- 1344
	local btnFont = 40 -- 1345
	local mainLabel = createLabel(root, ____exports.FinaleMainText, fontMain, FinaleMainHex) -- 1347
	if mainLabel ~= nil then -- 1347
		mainLabel.textWidth = viewW * 0.88 -- 1350
		setLabelCenter(mainLabel, viewW / 2, viewH * 0.8) -- 1351
	end -- 1351
	local subLabel = createLabel(root, "", fontSub, FinaleSubHex) -- 1354
	if subLabel ~= nil then -- 1354
		setLabelCenter(subLabel, viewW / 2, viewH * 0.71) -- 1355
	end -- 1355
	local btnW = clampNumber(viewW * 0.62, MinButtonWidth, 560) -- 1357
	local btnH = clampNumber(viewH * 0.085, MinButtonHeight, 120) -- 1358
	local backButton = createButton(root, { -- 1359
		w = btnW, -- 1360
		h = btnH, -- 1361
		text = "返回关卡选择", -- 1362
		fontSize = btnFont, -- 1363
		bgHex = ResultButtonBgHex, -- 1364
		fgHex = ResultButtonFgHex, -- 1365
		borderHex = ResultButtonBorderHex, -- 1366
		fireOn = "press", -- 1368
		onTap = opts.onBackToSelect -- 1369
	}) -- 1369
	backButton.root.position = Vec2((viewW - btnW) / 2, 110) -- 1371
	root.visible = false -- 1373
	backButton:setEnabled(false) -- 1375
	return { -- 1377
		root = root, -- 1378
		show = function(____, main, sub) -- 1379
			setLabelText(mainLabel, main) -- 1380
			setLabelText(subLabel, sub) -- 1381
			backButton:setEnabled(true) -- 1382
			root.visible = true -- 1383
		end, -- 1379
		hide = function() -- 1385
			root.visible = false -- 1386
			backButton:setEnabled(false) -- 1388
		end -- 1385
	} -- 1385
end -- 1335
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 1427
	local root = createPanel( -- 1433
		parent, -- 1433
		viewW, -- 1433
		viewH, -- 1433
		SelectBackdropHex, -- 1433
		{alpha = 0.9} -- 1433
	) -- 1433
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 1435
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 1436
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 1438
	setLabelCenter( -- 1439
		subtitleLabel, -- 1439
		viewW / 2, -- 1439
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 1439
	) -- 1439
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 1441
	setLabelCenter( -- 1442
		hintLabel, -- 1442
		viewW / 2, -- 1442
		clampNumber(viewH * 0.045, 36, 90) -- 1442
	) -- 1442
	local count = #opts.levels -- 1444
	local cols = viewH > viewW and 2 or 1 -- 1447
	local rows = math.max( -- 1448
		1, -- 1448
		math.ceil(count / cols) -- 1448
	) -- 1448
	local gap = 18 -- 1449
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 1450
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 1451
	local availW = viewW * 0.84 -- 1452
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 1453
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 1454
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 1455
	local gridW = cols * btnW + gap * (cols - 1) -- 1456
	local topY = viewH - headerH -- 1457
	local buttons = {} -- 1459
	do -- 1459
		local i = 0 -- 1460
		while i < count do -- 1460
			local index = i -- 1462
			local button = createButton( -- 1463
				root, -- 1463
				{ -- 1463
					w = btnW, -- 1464
					h = btnH, -- 1465
					text = opts.levels[index + 1].name, -- 1466
					fontSize = 38, -- 1467
					bgHex = SelectLockedBgHex, -- 1468
					fgHex = SelectLockedFgHex, -- 1469
					borderHex = SelectBorderHex, -- 1470
					fireOn = "press", -- 1472
					onTap = function() return opts:onPick(index) end -- 1473
				} -- 1473
			) -- 1473
			local col = index % cols -- 1475
			local rowIndex = math.floor(index / cols) -- 1476
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 1477
			buttons[#buttons + 1] = button -- 1481
			i = i + 1 -- 1460
		end -- 1460
	end -- 1460
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 1487
		root, -- 1488
		{ -- 1488
			w = clampNumber(viewW * 0.36, 180, 300), -- 1489
			h = MinButtonHeight, -- 1490
			text = "重看开场", -- 1491
			fontSize = 30, -- 1492
			bgHex = SelectLockedBgHex, -- 1493
			fgHex = SelectSubtitleHex, -- 1494
			borderHex = SelectBorderHex, -- 1495
			fireOn = "press", -- 1496
			onTap = function() -- 1497
				if opts.onReplayIntro ~= nil then -- 1497
					opts:onReplayIntro() -- 1498
				end -- 1498
			end -- 1497
		} -- 1497
	) or nil -- 1497
	if replayButton ~= nil then -- 1497
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 1503
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 1504
		replayButton.root.position = Vec2( -- 1505
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 1505
			by -- 1505
		) -- 1505
	end -- 1505
	root.visible = false -- 1508
	do -- 1508
		local i = 0 -- 1509
		while i < count do -- 1509
			buttons[i + 1]:setEnabled(false) -- 1509
			i = i + 1 -- 1509
		end -- 1509
	end -- 1509
	if replayButton ~= nil then -- 1509
		replayButton:setEnabled(false) -- 1510
	end -- 1510
	return { -- 1512
		root = root, -- 1513
		show = function(____, unlocked) -- 1514
			local maxUnlocked = clampNumber( -- 1515
				math.floor(unlocked), -- 1515
				0, -- 1515
				count - 1 -- 1515
			) -- 1515
			setLabelText( -- 1516
				subtitleLabel, -- 1516
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 1516
			) -- 1516
			do -- 1516
				local i = 0 -- 1517
				while i < count do -- 1517
					local button = buttons[i + 1] -- 1518
					local open = i <= maxUnlocked -- 1519
					button:setEnabled(open) -- 1520
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 1521
					if open then -- 1521
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 1522
					else -- 1522
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 1523
					end -- 1523
					i = i + 1 -- 1517
				end -- 1517
			end -- 1517
			root.visible = true -- 1525
			if replayButton ~= nil then -- 1525
				replayButton:setEnabled(true) -- 1526
			end -- 1526
		end, -- 1514
		hide = function() -- 1528
			root.visible = false -- 1529
			do -- 1529
				local i = 0 -- 1531
				while i < count do -- 1531
					buttons[i + 1]:setEnabled(false) -- 1531
					i = i + 1 -- 1531
				end -- 1531
			end -- 1531
			if replayButton ~= nil then -- 1531
				replayButton:setEnabled(false) -- 1532
			end -- 1532
		end -- 1528
	} -- 1528
end -- 1427
return ____exports -- 1427