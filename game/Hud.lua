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
function ____exports.computeAim(probeOffset, touchOffset, maxDragPx, maxSpeed) -- 71
	local speedTop = maxSpeed ~= nil and maxSpeed > AimMinSpeed and maxSpeed or AimMaxSpeed -- 77
	local dx = touchOffset.x - probeOffset.x -- 82
	local dy = touchOffset.y - probeOffset.y -- 83
	local len = math.sqrt(dx * dx + dy * dy) -- 85
	if len < 0.000001 then -- 85
		return {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 88
	end -- 88
	local ux = dx / len -- 91
	local uy = -dy / len -- 96
	local safeMax = maxDragPx > 1 and maxDragPx or 1 -- 98
	local power = len / safeMax -- 99
	if power < 0 then -- 99
		power = 0 -- 100
	end -- 100
	if power > 1 then -- 100
		power = 1 -- 101
	end -- 101
	local speed = AimMinSpeed + (speedTop - AimMinSpeed) * power -- 103
	return {velocity = {x = ux * speed, y = uy * speed}, power = power, unit = {x = ux, y = uy}} -- 105
end -- 71
--- 把屏幕位置（**投影偏移空间**，与 `project()` 同空间）转成平面坐标。
-- 
-- 不是矄准必需（矄准只用方向），但调试与关卡设计时有用。
-- 与 `project()` 互逆（已有往返测试守着）。
function ____exports.screenToPlane(viewPoint, basis) -- 118
	local world = screenToPlaneY(viewPoint, basis, 0) -- 122
	if world == nil then -- 122
		return nil -- 123
	end -- 123
	return {x = world.x / PlaneToWorldX, y = world.z / PlaneToWorldZ} -- 125
end -- 118
--- 默认的力度→拖动像素映射（供 UI 层统一引用）。
function ____exports.defaultMaxDragPx() -- 129
	return AimMaxDragPx -- 130
end -- 129
--- 默认速度区间（供 UI 层展示）。
function ____exports.defaultSpeedRange() -- 134
	return {min = AimMinSpeed, max = AimMaxSpeed} -- 135
end -- 134
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
function ____exports.localToOffset(____local, space) -- 156
	return {x = ____local.x - space.viewW / 2, y = ____local.y - space.viewH / 2} -- 157
end -- 156
--- 反向换算（投影偏移空间 → 全屏节点局部坐标）。
function ____exports.offsetToLocal(offset, space) -- 161
	return {x = offset.x + space.viewW / 2, y = offset.y + space.viewH / 2} -- 162
end -- 161
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
function ____exports.createAimInput(parent, viewW, viewH, maxSpeed) -- 278
	local brakeOn, paintBrake, datePlate, dateLabel -- 278
	local speedTop = maxSpeed ~= nil and maxSpeed > AimMinSpeed and maxSpeed or AimMaxSpeed -- 285
	local root = Node() -- 286
	root.size = Size(viewW, viewH) -- 287
	root.anchor = Vec2(0, 0) -- 293
	root.position = Vec2(0, 0) -- 294
	local touchLayer = Node() -- 297
	touchLayer.size = Size(viewW, viewH) -- 298
	touchLayer.anchor = Vec2(0.5, 0.5) -- 299
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 300
	touchLayer.swallowTouches = true -- 301
	root:addChild(touchLayer) -- 302
	local space = {viewW = viewW, viewH = viewH} -- 304
	local enabled = false -- 306
	local dragging = false -- 307
	--- 整屏瞄准（2D 模式）；由 Game 按视图状态同步。
	local fullScreenAim = false -- 309
	local aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 310
	local probeOffset = {x = 0, y = 0} -- 313
	local dragHandler = nil -- 315
	local readyHandler = nil -- 316
	local observeHandler = nil -- 317
	local zoomHandler = nil -- 318
	local launchHandler = nil -- 319
	local pressOffset = {x = 0, y = 0} -- 330
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 333
		aim = ____exports.computeAim({x = 0, y = 0}, delta, AimMaxDragPx, speedTop) -- 334
		if dragHandler ~= nil then -- 334
			dragHandler(aim) -- 335
		end -- 335
	end -- 333
	local aimRadius = math.max(96, viewW * 0.25) -- 342
	local mode = "none" -- 343
	local observeLast = {x = 0, y = 0} -- 344
	touchLayer:onTapBegan(function(touch) -- 345
		if not enabled then -- 345
			return -- 346
		end -- 346
		local at = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 347
		local dx = at.x - probeOffset.x -- 348
		local dy = at.y - probeOffset.y -- 349
		if fullScreenAim or math.sqrt(dx * dx + dy * dy) <= aimRadius then -- 349
			mode = "aim" -- 351
			dragging = true -- 352
			pressOffset = at -- 353
			handleDelta({x = 0, y = 0}) -- 355
		else -- 355
			mode = "observe" -- 357
			observeLast = at -- 358
		end -- 358
	end) -- 345
	touchLayer:onTapMoved(function(touch) -- 362
		if not enabled then -- 362
			return -- 363
		end -- 363
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 364
		if mode == "aim" and dragging then -- 364
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 366
		elseif mode == "observe" then -- 366
			if observeHandler ~= nil then -- 366
				observeHandler(cur.x - observeLast.x, cur.y - observeLast.y) -- 369
			end -- 369
			observeLast = cur -- 370
		end -- 370
	end) -- 362
	touchLayer:onTapEnded(function(touch) -- 374
		if not enabled then -- 374
			return -- 375
		end -- 375
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 376
		if mode == "aim" then -- 376
			dragging = false -- 378
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 379
			if readyHandler ~= nil then -- 379
				readyHandler(aim) -- 381
			end -- 381
		end -- 381
		mode = "none" -- 383
	end) -- 374
	touchLayer:onGesture(function(_center, numFingers, deltaDist, _deltaAngle) -- 387
		if not enabled or numFingers < 2 then -- 387
			return -- 388
		end -- 388
		if zoomHandler ~= nil then -- 388
			zoomHandler(deltaDist) -- 389
		end -- 389
	end) -- 387
	touchLayer.touchEnabled = false -- 397
	local brakeHandler = nil -- 402
	local BrakeButtonW = 116 -- 403
	local BrakeButtonH = 64 -- 404
	local brakeGap = 8 -- 405
	local brakeButtons = {} -- 409
	local function makeBrakeButton(text, on, x) -- 410
		local btn = createButton( -- 411
			root, -- 411
			{ -- 411
				w = BrakeButtonW, -- 412
				h = BrakeButtonH, -- 413
				text = text, -- 414
				fontSize = 30, -- 415
				bgHex = ResultButtonAltBgHex, -- 416
				fgHex = ResultButtonFgHex, -- 417
				borderHex = ResultButtonBorderHex, -- 418
				onTap = function() -- 419
					brakeOn = on -- 422
					paintBrake() -- 423
					if brakeHandler ~= nil then -- 423
						brakeHandler(on) -- 424
					end -- 424
				end -- 419
			} -- 419
		) -- 419
		btn.root.position = Vec2(x, viewH - BrakeButtonH - 20) -- 427
		brakeButtons[#brakeButtons + 1] = btn -- 428
	end -- 410
	brakeOn = false -- 430
	paintBrake = function() -- 431
		if #brakeButtons < 2 then -- 431
			return -- 432
		end -- 432
		brakeButtons[1]:setColors(brakeOn and ResultButtonAltBgHex or ResultButtonBgHex, ResultButtonFgHex) -- 433
		brakeButtons[2]:setColors(brakeOn and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 434
	end -- 431
	createPanel( -- 440
		root, -- 440
		220, -- 440
		50, -- 440
		658964, -- 440
		{alpha = 0.45} -- 440
	) -- 440
	local dvLabel = createLabel(root, "Δv — / —", 30, ResultHintHex) -- 441
	if dvLabel ~= nil then -- 441
		dvLabel.position = Vec2(24, viewH - 44) -- 443
		dvLabel.anchor = Vec2(0, 0) -- 444
	end -- 444
	local warpHandler = nil -- 454
	local dateSpan = 0 -- 455
	--- 这一关有时间轴**且**当前相态允许改日期（Flying/Result 时必须是 false）。
	local warpOn = true -- 462
	local warpVisible = true -- 463
	--- 相态是否允许改日期（由主循环每帧 setTimeEnabled 同步）。
	local warpAllowed = true -- 465
	--- 上次写进日期的文字（避免每帧重设 Label 文本）。
	local lastDateText = "" -- 467
	--- >0 = 正在按住这个方向（-1 回退 / +1 加速）；0 = 没按住。
	local warpHoldDir = 0 -- 469
	--- 距离下一次连按还有多久（秒）。
	local warpRepeatIn = 0 -- 471
	local WarpButtonW = 116 -- 472
	local WarpButtonH = 64 -- 473
	local warpButtons = {} -- 474
	local function applyWarpState() -- 475
		local vis = dateSpan > 0 -- 476
		local on = vis and warpAllowed -- 477
		if vis == warpVisible and on == warpOn then -- 477
			return -- 478
		end -- 478
		warpVisible = vis -- 479
		warpOn = on -- 480
		if not on then -- 480
			warpHoldDir = 0 -- 481
		end -- 481
		for ____, b in ipairs(warpButtons) do -- 482
			b.root.visible = vis -- 483
			b:setEnabled(on) -- 484
		end -- 484
		if dateLabel ~= nil then -- 484
			dateLabel.visible = vis -- 486
		end -- 486
		datePlate.visible = vis -- 487
	end -- 475
	local function makeWarpButton(text, dir, x) -- 489
		local btn = createButton( -- 490
			root, -- 490
			{ -- 490
				w = WarpButtonW, -- 491
				h = WarpButtonH, -- 492
				text = text, -- 493
				fontSize = 30, -- 494
				bgHex = ResultButtonAltBgHex, -- 495
				fgHex = ResultButtonFgHex, -- 496
				borderHex = ResultButtonBorderHex, -- 497
				onTap = function() -- 500
				end, -- 500
				onPressBegan = function() -- 501
					print((("[escape-velocity] warp press dir=" .. __TS__NumberToFixed(dir, 0)) .. " on=") .. (warpOn and "1" or "0")) -- 503
					if not warpOn then -- 503
						return -- 504
					end -- 504
					if warpHoldDir == dir then -- 504
						return -- 506
					end -- 506
					warpHoldDir = dir -- 507
					warpRepeatIn = WarpHoldDelaySec -- 508
					if warpHandler ~= nil then -- 508
						warpHandler(dir) -- 509
					end -- 509
				end, -- 501
				onPressEnded = function() -- 511
					print((("[escape-velocity] warp release dir=" .. __TS__NumberToFixed(dir, 0)) .. " hold=") .. __TS__NumberToFixed(warpHoldDir, 0)) -- 512
					if warpHoldDir == dir then -- 512
						warpHoldDir = 0 -- 514
					end -- 514
				end -- 511
			} -- 511
		) -- 511
		btn.root.position = Vec2(x, viewH - 96 - WarpButtonH) -- 520
		warpButtons[#warpButtons + 1] = btn -- 521
	end -- 489
	local warpLeftX = viewW - (WarpButtonW * 2 + 8) - 20 -- 523
	makeWarpButton("◀ 回退", -1, warpLeftX) -- 524
	makeWarpButton("加速 ▶", 1, warpLeftX + WarpButtonW + 8) -- 525
	datePlate = createPanel( -- 527
		root, -- 527
		300, -- 527
		50, -- 527
		658964, -- 527
		{alpha = 0.45} -- 527
	) -- 527
	datePlate.position = Vec2(warpLeftX - 316, viewH - 96 - WarpButtonH + 8) -- 528
	dateLabel = createLabel(root, "发射日期 —", 30, ResultHintHex) -- 529
	if dateLabel ~= nil then -- 529
		dateLabel.anchor = Vec2(1, 0) -- 534
		dateLabel.position = Vec2(warpLeftX - 16, viewH - 96 - WarpButtonH + 18) -- 535
	end -- 535
	local LaunchButtonW = 220 -- 542
	local LaunchButtonH = 112 -- 543
	local launchButton = createButton( -- 544
		root, -- 544
		{ -- 544
			w = LaunchButtonW, -- 545
			h = LaunchButtonH, -- 546
			text = "发射", -- 547
			fontSize = 44, -- 548
			bgHex = ResultButtonBgHex, -- 549
			fgHex = ResultButtonFgHex, -- 550
			borderHex = ResultButtonBorderHex, -- 551
			fireOn = "press", -- 552
			onTap = function() -- 553
				print("[escape-velocity] launch button fire (press)") -- 555
				if launchHandler ~= nil then -- 555
					launchHandler() -- 556
				end -- 556
			end -- 553
		} -- 553
	) -- 553
	launchButton.root.position = Vec2(viewW - LaunchButtonW - 24, 96) -- 559
	launchButton.root.visible = false -- 560
	launchButton:setEnabled(false) -- 561
	local ViewButtonW = 116 -- 569
	local ViewButtonH = 64 -- 570
	local viewHandler = nil -- 571
	local viewButton = createButton( -- 572
		root, -- 572
		{ -- 572
			w = ViewButtonW, -- 573
			h = ViewButtonH, -- 574
			text = "2D", -- 575
			fontSize = 30, -- 576
			bgHex = ResultButtonAltBgHex, -- 577
			fgHex = ResultButtonFgHex, -- 578
			borderHex = ResultButtonBorderHex, -- 579
			fireOn = "press", -- 581
			onTap = function() -- 582
				print("[escape-velocity] view toggle fire (press)") -- 583
				if viewHandler ~= nil then -- 583
					viewHandler() -- 584
				end -- 584
			end -- 582
		} -- 582
	) -- 582
	viewButton.root.position = Vec2(viewW - ViewButtonW - 24, 96 + LaunchButtonH + 12) -- 590
	--- 上次写进按钮的文字（每帧都会被 setViewMode 调用，没变就别碰 Label）。
	local lastViewText = "2D" -- 592
	local brakeRightX = viewW - BrakeButtonW - 20 -- 594
	makeBrakeButton("惯性", false, brakeRightX - BrakeButtonW - brakeGap) -- 595
	makeBrakeButton("刹车", true, brakeRightX) -- 596
	paintBrake() -- 597
	parent:addChild(root) -- 599
	return { -- 601
		onDrag = function(____, callback) -- 602
			dragHandler = callback -- 603
		end, -- 602
		setEnabled = function(____, value) -- 605
			enabled = value -- 606
			touchLayer.touchEnabled = value -- 609
			if not value then -- 609
				dragging = false -- 610
			end -- 610
		end, -- 605
		onBrake = function(____, callback) -- 612
			brakeHandler = callback -- 613
		end, -- 612
		setBrake = function(____, on) -- 615
			brakeOn = on -- 616
			paintBrake() -- 617
		end, -- 615
		onAimReady = function(____, callback) -- 619
			readyHandler = callback -- 620
		end, -- 619
		onObserve = function(____, callback) -- 622
			observeHandler = callback -- 623
		end, -- 622
		onZoom = function(____, callback) -- 625
			zoomHandler = callback -- 626
		end, -- 625
		onLaunch = function(____, callback) -- 628
			launchHandler = callback -- 629
		end, -- 628
		setArmed = function(____, armed) -- 631
			launchButton.root.visible = armed -- 632
			launchButton:setEnabled(armed) -- 633
		end, -- 631
		onViewToggle = function(____, callback) -- 635
			viewHandler = callback -- 636
		end, -- 635
		setViewMode = function(____, mode) -- 638
			if mode == lastViewText then -- 638
				return -- 639
			end -- 639
			lastViewText = mode -- 640
			viewButton:setText(mode) -- 641
		end, -- 638
		setFullScreenAim = function(____, on) -- 643
			fullScreenAim = on -- 644
		end, -- 643
		onWarp = function(____, callback) -- 646
			warpHandler = callback -- 647
		end, -- 646
		setDate = function(____, t0, span) -- 649
			dateSpan = span > 0 and span or 0 -- 650
			applyWarpState() -- 651
			local on = dateSpan > 0 -- 652
			local text = on and (("发射日期 " .. __TS__NumberToFixed(t0, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0) or "发射日期" -- 653
			if text ~= lastDateText then -- 653
				lastDateText = text -- 655
				setLabelText(dateLabel, text) -- 656
			end -- 656
		end, -- 649
		setTimeEnabled = function(____, on) -- 659
			if warpAllowed == on then -- 659
				return -- 660
			end -- 660
			warpAllowed = on -- 661
			applyWarpState() -- 662
		end, -- 659
		update = function(____, dt) -- 664
			if not warpOn or warpHoldDir == 0 then -- 664
				return -- 665
			end -- 665
			warpRepeatIn = warpRepeatIn - dt -- 666
			if warpRepeatIn > 0 then -- 666
				return -- 667
			end -- 667
			warpRepeatIn = TimeWarpStep / TimeWarpRate -- 669
			if warpHandler ~= nil then -- 669
				warpHandler(warpHoldDir) -- 670
			end -- 670
		end, -- 664
		isDragging = function() return dragging end, -- 672
		setBurnInfo = function(____, burn, budget) -- 673
			setLabelText( -- 674
				dvLabel, -- 674
				(("Δv " .. __TS__NumberToFixed(burn, 1)) .. " / ") .. __TS__NumberToFixed(budget, 0) -- 674
			) -- 674
		end, -- 673
		current = function() return aim end, -- 676
		setProbeOffset = function(____, offset) -- 677
			probeOffset = offset -- 678
		end, -- 677
		handleLocal = function(____, ____local) -- 682
			handleDelta(____exports.localToOffset(____local, space)) -- 683
		end, -- 682
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 686
		debugProbeOffset = function() return probeOffset end, -- 687
		root = root -- 688
	} -- 688
end -- 278
local ResultBackdropHex = 329484 -- 705
local ResultCardHex = 1252395 -- 706
local ResultCardBorderHex = 3362938 -- 707
local ResultLevelHex = 9417948 -- 708
local ResultBodyHex = 14149367 -- 709
ResultHintHex = 8229803 -- 710
ResultButtonBgHex = 1919610 -- 711
ResultButtonAltBgHex = 1779509 -- 712
ResultButtonFgHex = 15398143 -- 713
ResultButtonBorderHex = 5211846 -- 714
local TitleSuccessHex = 8381344 -- 715
local TitleMissedHex = 16766073 -- 716
local TitleCrashedHex = 16743019 -- 717
local SelectBackdropHex = 329484 -- 719
local SelectTitleHex = 16777215 -- 720
local SelectSubtitleHex = 10470632 -- 721
local SelectHintHex = 7309478 -- 722
local SelectOpenBgHex = 1919610 -- 723
local SelectOpenFgHex = 15398143 -- 724
local SelectLockedBgHex = 1383204 -- 725
local SelectLockedFgHex = 6912140 -- 726
local SelectBorderHex = 4157096 -- 727
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 730
	if value < lo then -- 730
		return lo -- 731
	end -- 731
	if value > hi then -- 731
		return hi -- 732
	end -- 732
	return value -- 733
end -- 730
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 737
	if result == "success" then -- 737
		return "借力成功" -- 738
	end -- 738
	if result == "crashed" then -- 738
		return "信号中断" -- 739
	end -- 739
	return "错过目标" -- 740
end -- 737
--- 三态说明句（逐字）。
local function resultBody(result) -- 744
	if result == "success" then -- 744
		return "行星把探测器甩了出去，速度够了。" -- 745
	end -- 745
	if result == "crashed" then -- 745
		return "探测器撞上行星，任务到此为止。" -- 746
	end -- 746
	return "从行星身侧掠过，没能借到那一点速度。" -- 747
end -- 744
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 751
	if result == "success" then -- 751
		return TitleSuccessHex -- 752
	end -- 752
	if result == "crashed" then -- 752
		return TitleCrashedHex -- 753
	end -- 753
	return TitleMissedHex -- 754
end -- 751
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 763
	if result == "success" then -- 763
		return "下一关已解锁" -- 764
	end -- 764
	return "可重试本关，或返回关卡选择" -- 765
end -- 763
--- 建结算面板：半透明全屏底 + 居中卡片（宽 = 0.88 × 视宽）+ 4 行内容 + 2 个按钮。
-- 
-- ⚠️ 全屏底**不能**设 `touch: true`（真机验收踩到的坑）：
-- 全屏 + `swallowTouches` 的节点会独占它覆盖范围内的点击，而节点树里它排在瞄准层之前；
-- 只要它存在，进入关卡后怎么拖都没反应（表现为“进关卡不能拖动飞行器”）。
-- 不需要它吞点击：结算态瞄准层本来就已 `setEnabled(false)`（Flying 起就关），
-- 能点的只有卡片里那两个按钮。
-- 
-- @param viewW 视图逻辑宽（`View.size.width`）
-- @param viewH 视图逻辑高
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 794
	local root = createPanel( -- 800
		parent, -- 800
		viewW, -- 800
		viewH, -- 800
		ResultBackdropHex, -- 800
		{alpha = 0.78} -- 800
	) -- 800
	local cardW = viewW * 0.88 -- 805
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 900) -- 806
	local btnH = clampNumber(viewH * 0.13, MinButtonHeight, 150) -- 807
	local padX = (cardW - btnW) / 2 -- 808
	local padY = 44 -- 809
	local fontLevel = 34 -- 811
	local fontTitle = 66 -- 812
	local fontBody = 34 -- 813
	local fontHint = 30 -- 814
	local btnFont = 40 -- 815
	local rowGap = 26 -- 816
	local hLevel = fontLevel + 10 -- 819
	local hTitle = fontTitle + 18 -- 820
	local hBody = fontBody * 2 + 12 -- 821
	local hHint = fontHint + 10 -- 822
	local cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 823
	if cardH > viewH - 24 then -- 823
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 826
		cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 827
	end -- 827
	local card = createPanel( -- 830
		root, -- 830
		cardW, -- 830
		cardH, -- 830
		ResultCardHex, -- 830
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 830
	) -- 830
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 835
	local cursor = cardH - padY -- 838
	cursor = cursor - hLevel -- 840
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 841
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 842
	cursor = cursor - (rowGap + hTitle) -- 844
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 845
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 846
	cursor = cursor - (rowGap + hBody) -- 848
	local bodyLabel = createLabel(card, "", fontBody, ResultBodyHex) -- 849
	setLabelCenter(bodyLabel, cardW / 2, cursor + hBody / 2) -- 850
	if bodyLabel ~= nil then -- 850
		bodyLabel.textWidth = cardW - 80 -- 851
	end -- 851
	cursor = cursor - (rowGap + hHint) -- 853
	local hintLabel = createLabel(card, "", fontHint, ResultHintHex) -- 854
	setLabelCenter(hintLabel, cardW / 2, cursor + hHint / 2) -- 855
	cursor = cursor - (rowGap + btnH) -- 858
	local retryButton = createButton(card, { -- 859
		w = btnW, -- 860
		h = btnH, -- 861
		text = "重试本关", -- 862
		fontSize = btnFont, -- 863
		bgHex = ResultButtonBgHex, -- 864
		fgHex = ResultButtonFgHex, -- 865
		borderHex = ResultButtonBorderHex, -- 866
		fireOn = "press", -- 867
		onTap = opts.onRetry -- 868
	}) -- 868
	retryButton.root.position = Vec2(padX, cursor) -- 870
	cursor = cursor - (22 + btnH) -- 872
	local backButton = createButton(card, { -- 873
		w = btnW, -- 874
		h = btnH, -- 875
		text = "返回关卡选择", -- 876
		fontSize = btnFont, -- 877
		bgHex = ResultButtonAltBgHex, -- 878
		fgHex = ResultButtonFgHex, -- 879
		borderHex = ResultButtonBorderHex, -- 880
		fireOn = "press", -- 881
		onTap = opts.onBackToSelect -- 882
	}) -- 882
	backButton.root.position = Vec2(padX, cursor) -- 884
	root.visible = false -- 886
	retryButton:setEnabled(false) -- 889
	backButton:setEnabled(false) -- 890
	return { -- 892
		root = root, -- 893
		show = function(____, result, levelName) -- 894
			retryButton:setEnabled(true) -- 896
			backButton:setEnabled(true) -- 897
			setLabelText(levelLabel, levelName) -- 898
			setLabelText( -- 899
				titleLabel, -- 899
				resultTitle(result) -- 899
			) -- 899
			setLabelColor( -- 900
				titleLabel, -- 900
				resultTitleColor(result) -- 900
			) -- 900
			setLabelText( -- 901
				bodyLabel, -- 901
				resultBody(result) -- 901
			) -- 901
			setLabelText( -- 902
				hintLabel, -- 902
				resultHint(result) -- 902
			) -- 902
			root.visible = true -- 903
		end, -- 894
		hide = function() -- 905
			root.visible = false -- 906
			retryButton:setEnabled(false) -- 909
			backButton:setEnabled(false) -- 910
		end -- 905
	} -- 905
end -- 794
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 950
	local root = createPanel( -- 956
		parent, -- 956
		viewW, -- 956
		viewH, -- 956
		SelectBackdropHex, -- 956
		{alpha = 0.9} -- 956
	) -- 956
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 958
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 959
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 961
	setLabelCenter( -- 962
		subtitleLabel, -- 962
		viewW / 2, -- 962
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 962
	) -- 962
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 964
	setLabelCenter( -- 965
		hintLabel, -- 965
		viewW / 2, -- 965
		clampNumber(viewH * 0.045, 36, 90) -- 965
	) -- 965
	local count = #opts.levels -- 967
	local cols = viewH > viewW and 2 or 1 -- 970
	local rows = math.max( -- 971
		1, -- 971
		math.ceil(count / cols) -- 971
	) -- 971
	local gap = 18 -- 972
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 973
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 974
	local availW = viewW * 0.84 -- 975
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 976
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 977
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 978
	local gridW = cols * btnW + gap * (cols - 1) -- 979
	local topY = viewH - headerH -- 980
	local buttons = {} -- 982
	do -- 982
		local i = 0 -- 983
		while i < count do -- 983
			local index = i -- 985
			local button = createButton( -- 986
				root, -- 986
				{ -- 986
					w = btnW, -- 987
					h = btnH, -- 988
					text = opts.levels[index + 1].name, -- 989
					fontSize = 38, -- 990
					bgHex = SelectLockedBgHex, -- 991
					fgHex = SelectLockedFgHex, -- 992
					borderHex = SelectBorderHex, -- 993
					fireOn = "press", -- 995
					onTap = function() return opts:onPick(index) end -- 996
				} -- 996
			) -- 996
			local col = index % cols -- 998
			local rowIndex = math.floor(index / cols) -- 999
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 1000
			buttons[#buttons + 1] = button -- 1004
			i = i + 1 -- 983
		end -- 983
	end -- 983
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 1010
		root, -- 1011
		{ -- 1011
			w = clampNumber(viewW * 0.36, 180, 300), -- 1012
			h = MinButtonHeight, -- 1013
			text = "重看开场", -- 1014
			fontSize = 30, -- 1015
			bgHex = SelectLockedBgHex, -- 1016
			fgHex = SelectSubtitleHex, -- 1017
			borderHex = SelectBorderHex, -- 1018
			fireOn = "press", -- 1019
			onTap = function() -- 1020
				if opts.onReplayIntro ~= nil then -- 1020
					opts:onReplayIntro() -- 1021
				end -- 1021
			end -- 1020
		} -- 1020
	) or nil -- 1020
	if replayButton ~= nil then -- 1020
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 1026
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 1027
		replayButton.root.position = Vec2( -- 1028
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 1028
			by -- 1028
		) -- 1028
	end -- 1028
	root.visible = false -- 1031
	do -- 1031
		local i = 0 -- 1032
		while i < count do -- 1032
			buttons[i + 1]:setEnabled(false) -- 1032
			i = i + 1 -- 1032
		end -- 1032
	end -- 1032
	if replayButton ~= nil then -- 1032
		replayButton:setEnabled(false) -- 1033
	end -- 1033
	return { -- 1035
		root = root, -- 1036
		show = function(____, unlocked) -- 1037
			local maxUnlocked = clampNumber( -- 1038
				math.floor(unlocked), -- 1038
				0, -- 1038
				count - 1 -- 1038
			) -- 1038
			setLabelText( -- 1039
				subtitleLabel, -- 1039
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 1039
			) -- 1039
			do -- 1039
				local i = 0 -- 1040
				while i < count do -- 1040
					local button = buttons[i + 1] -- 1041
					local open = i <= maxUnlocked -- 1042
					button:setEnabled(open) -- 1043
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 1044
					if open then -- 1044
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 1045
					else -- 1045
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 1046
					end -- 1046
					i = i + 1 -- 1040
				end -- 1040
			end -- 1040
			root.visible = true -- 1048
			if replayButton ~= nil then -- 1048
				replayButton:setEnabled(true) -- 1049
			end -- 1049
		end, -- 1037
		hide = function() -- 1051
			root.visible = false -- 1052
			do -- 1052
				local i = 0 -- 1054
				while i < count do -- 1054
					buttons[i + 1]:setEnabled(false) -- 1054
					i = i + 1 -- 1054
				end -- 1054
			end -- 1054
			if replayButton ~= nil then -- 1054
				replayButton:setEnabled(false) -- 1055
			end -- 1055
		end -- 1051
	} -- 1051
end -- 950
return ____exports -- 950