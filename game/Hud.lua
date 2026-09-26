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
local ____Ui = require("game.Ui") -- 40
local MinButtonHeight = ____Ui.MinButtonHeight -- 40
local MinButtonWidth = ____Ui.MinButtonWidth -- 40
local createButton = ____Ui.createButton -- 40
local createLabel = ____Ui.createLabel -- 40
local createPanel = ____Ui.createPanel -- 40
local setLabelCenter = ____Ui.setLabelCenter -- 40
local setLabelColor = ____Ui.setLabelColor -- 40
local setLabelText = ____Ui.setLabelText -- 40
--- 纯计算：由“探测器屏幕偏移”与“当前触摸屏幕偏移”解算发射向量。
-- 
-- 方向语义（手册 §5.7）：发射方向 = **探测器 → 触摸点**。
-- 屏幕上玩家把手指移到探测器**上方**，发射就朝屏幕上方。
-- 
-- @param probeOffset 探测器在投影偏移空间中的位置
-- @param touchOffset 触摸点在投影偏移空间中的位置
-- @param maxDragPx 拖动多少像素算满力
-- @param maxSpeed 满力对应的速度（= 这一关的 Δv 预算）；省略 = 全局上限 `AimMaxSpeed`
function ____exports.computeAim(probeOffset, touchOffset, maxDragPx, maxSpeed) -- 69
	local speedTop = maxSpeed ~= nil and maxSpeed > AimMinSpeed and maxSpeed or AimMaxSpeed -- 75
	local dx = touchOffset.x - probeOffset.x -- 80
	local dy = touchOffset.y - probeOffset.y -- 81
	local len = math.sqrt(dx * dx + dy * dy) -- 83
	if len < 0.000001 then -- 83
		return {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 86
	end -- 86
	local ux = dx / len -- 89
	local uy = -dy / len -- 94
	local safeMax = maxDragPx > 1 and maxDragPx or 1 -- 96
	local power = len / safeMax -- 97
	if power < 0 then -- 97
		power = 0 -- 98
	end -- 98
	if power > 1 then -- 98
		power = 1 -- 99
	end -- 99
	local speed = AimMinSpeed + (speedTop - AimMinSpeed) * power -- 101
	return {velocity = {x = ux * speed, y = uy * speed}, power = power, unit = {x = ux, y = uy}} -- 103
end -- 69
--- 把屏幕位置（**投影偏移空间**，与 `project()` 同空间）转成平面坐标。
-- 
-- 不是矄准必需（矄准只用方向），但调试与关卡设计时有用。
-- 与 `project()` 互逆（已有往返测试守着）。
function ____exports.screenToPlane(viewPoint, basis) -- 116
	local world = screenToPlaneY(viewPoint, basis, 0) -- 120
	if world == nil then -- 120
		return nil -- 121
	end -- 121
	return {x = world.x / PlaneToWorldX, y = world.z / PlaneToWorldZ} -- 123
end -- 116
--- 默认的力度→拖动像素映射（供 UI 层统一引用）。
function ____exports.defaultMaxDragPx() -- 127
	return AimMaxDragPx -- 128
end -- 127
--- 默认速度区间（供 UI 层展示）。
function ____exports.defaultSpeedRange() -- 132
	return {min = AimMinSpeed, max = AimMaxSpeed} -- 133
end -- 132
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
function ____exports.localToOffset(____local, space) -- 154
	return {x = ____local.x - space.viewW / 2, y = ____local.y - space.viewH / 2} -- 155
end -- 154
--- 反向换算（投影偏移空间 → 全屏节点局部坐标）。
function ____exports.offsetToLocal(offset, space) -- 159
	return {x = offset.x + space.viewW / 2, y = offset.y + space.viewH / 2} -- 160
end -- 159
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
function ____exports.createAimInput(parent, viewW, viewH, maxSpeed) -- 261
	local brakeOn, paintBrake, dateLabel -- 261
	local speedTop = maxSpeed ~= nil and maxSpeed > AimMinSpeed and maxSpeed or AimMaxSpeed -- 268
	local root = Node() -- 269
	root.size = Size(viewW, viewH) -- 270
	root.anchor = Vec2(0, 0) -- 276
	root.position = Vec2(0, 0) -- 277
	local touchLayer = Node() -- 280
	touchLayer.size = Size(viewW, viewH) -- 281
	touchLayer.anchor = Vec2(0.5, 0.5) -- 282
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 283
	touchLayer.swallowTouches = true -- 284
	root:addChild(touchLayer) -- 285
	local space = {viewW = viewW, viewH = viewH} -- 287
	local enabled = false -- 289
	local dragging = false -- 290
	local aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 291
	local probeOffset = {x = 0, y = 0} -- 294
	local dragHandler = nil -- 296
	local readyHandler = nil -- 297
	local observeHandler = nil -- 298
	local zoomHandler = nil -- 299
	local launchHandler = nil -- 300
	local pressOffset = {x = 0, y = 0} -- 311
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 314
		aim = ____exports.computeAim({x = 0, y = 0}, delta, AimMaxDragPx, speedTop) -- 315
		if dragHandler ~= nil then -- 315
			dragHandler(aim) -- 316
		end -- 316
	end -- 314
	local aimRadius = math.max(96, viewW * 0.25) -- 323
	local mode = "none" -- 324
	local observeLast = {x = 0, y = 0} -- 325
	touchLayer:onTapBegan(function(touch) -- 326
		if not enabled then -- 326
			return -- 327
		end -- 327
		local at = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 328
		local dx = at.x - probeOffset.x -- 329
		local dy = at.y - probeOffset.y -- 330
		if math.sqrt(dx * dx + dy * dy) <= aimRadius then -- 330
			mode = "aim" -- 332
			dragging = true -- 333
			pressOffset = at -- 334
			handleDelta({x = 0, y = 0}) -- 336
		else -- 336
			mode = "observe" -- 338
			observeLast = at -- 339
		end -- 339
	end) -- 326
	touchLayer:onTapMoved(function(touch) -- 343
		if not enabled then -- 343
			return -- 344
		end -- 344
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 345
		if mode == "aim" and dragging then -- 345
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 347
		elseif mode == "observe" then -- 347
			if observeHandler ~= nil then -- 347
				observeHandler(cur.x - observeLast.x, cur.y - observeLast.y) -- 350
			end -- 350
			observeLast = cur -- 351
		end -- 351
	end) -- 343
	touchLayer:onTapEnded(function(touch) -- 355
		if not enabled then -- 355
			return -- 356
		end -- 356
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 357
		if mode == "aim" then -- 357
			dragging = false -- 359
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 360
			if readyHandler ~= nil then -- 360
				readyHandler(aim) -- 362
			end -- 362
		end -- 362
		mode = "none" -- 364
	end) -- 355
	touchLayer:onGesture(function(_center, numFingers, deltaDist, _deltaAngle) -- 368
		if not enabled or numFingers < 2 then -- 368
			return -- 369
		end -- 369
		if zoomHandler ~= nil then -- 369
			zoomHandler(deltaDist) -- 370
		end -- 370
	end) -- 368
	touchLayer.touchEnabled = false -- 378
	local brakeHandler = nil -- 383
	local BrakeButtonW = 116 -- 384
	local BrakeButtonH = 64 -- 385
	local brakeGap = 8 -- 386
	local brakeButtons = {} -- 390
	local function makeBrakeButton(text, on, x) -- 391
		local btn = createButton( -- 392
			root, -- 392
			{ -- 392
				w = BrakeButtonW, -- 393
				h = BrakeButtonH, -- 394
				text = text, -- 395
				fontSize = 30, -- 396
				bgHex = ResultButtonAltBgHex, -- 397
				fgHex = ResultButtonFgHex, -- 398
				borderHex = ResultButtonBorderHex, -- 399
				onTap = function() -- 400
					brakeOn = on -- 403
					paintBrake() -- 404
					if brakeHandler ~= nil then -- 404
						brakeHandler(on) -- 405
					end -- 405
				end -- 400
			} -- 400
		) -- 400
		btn.root.position = Vec2(x, viewH - BrakeButtonH - 20) -- 408
		brakeButtons[#brakeButtons + 1] = btn -- 409
	end -- 391
	brakeOn = false -- 411
	paintBrake = function() -- 412
		if #brakeButtons < 2 then -- 412
			return -- 413
		end -- 413
		brakeButtons[1]:setColors(brakeOn and ResultButtonAltBgHex or ResultButtonBgHex, ResultButtonFgHex) -- 414
		brakeButtons[2]:setColors(brakeOn and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 415
	end -- 412
	local dvLabel = createLabel(root, "Δv — / —", 30, ResultHintHex) -- 419
	if dvLabel ~= nil then -- 419
		dvLabel.position = Vec2(24, viewH - 44) -- 421
		dvLabel.anchor = Vec2(0, 0) -- 422
	end -- 422
	local warpHandler = nil -- 432
	local dateSpan = 0 -- 433
	--- 这一关有时间轴**且**当前相态允许改日期（Flying/Result 时必须是 false）。
	local warpOn = true -- 440
	local warpVisible = true -- 441
	--- 相态是否允许改日期（由主循环每帧 setTimeEnabled 同步）。
	local warpAllowed = true -- 443
	--- 上次写进日期的文字（避免每帧重设 Label 文本）。
	local lastDateText = "" -- 445
	--- >0 = 正在按住这个方向（-1 回退 / +1 加速）；0 = 没按住。
	local warpHoldDir = 0 -- 447
	--- 距离下一次连按还有多久（秒）。
	local warpRepeatIn = 0 -- 449
	local WarpButtonW = 116 -- 450
	local WarpButtonH = 64 -- 451
	local warpButtons = {} -- 452
	local function applyWarpState() -- 453
		local vis = dateSpan > 0 -- 454
		local on = vis and warpAllowed -- 455
		if vis == warpVisible and on == warpOn then -- 455
			return -- 456
		end -- 456
		warpVisible = vis -- 457
		warpOn = on -- 458
		if not on then -- 458
			warpHoldDir = 0 -- 459
		end -- 459
		for ____, b in ipairs(warpButtons) do -- 460
			b.root.visible = vis -- 461
			b:setEnabled(on) -- 462
		end -- 462
		if dateLabel ~= nil then -- 462
			dateLabel.visible = vis -- 464
		end -- 464
	end -- 453
	local function makeWarpButton(text, dir, x) -- 466
		local btn = createButton( -- 467
			root, -- 467
			{ -- 467
				w = WarpButtonW, -- 468
				h = WarpButtonH, -- 469
				text = text, -- 470
				fontSize = 30, -- 471
				bgHex = ResultButtonAltBgHex, -- 472
				fgHex = ResultButtonFgHex, -- 473
				borderHex = ResultButtonBorderHex, -- 474
				onTap = function() -- 477
				end, -- 477
				onPressBegan = function() -- 478
					print((("[escape-velocity] warp press dir=" .. __TS__NumberToFixed(dir, 0)) .. " on=") .. (warpOn and "1" or "0")) -- 480
					if not warpOn then -- 480
						return -- 481
					end -- 481
					if warpHoldDir == dir then -- 481
						return -- 483
					end -- 483
					warpHoldDir = dir -- 484
					warpRepeatIn = WarpHoldDelaySec -- 485
					if warpHandler ~= nil then -- 485
						warpHandler(dir) -- 486
					end -- 486
				end, -- 478
				onPressEnded = function() -- 488
					print((("[escape-velocity] warp release dir=" .. __TS__NumberToFixed(dir, 0)) .. " hold=") .. __TS__NumberToFixed(warpHoldDir, 0)) -- 489
					if warpHoldDir == dir then -- 489
						warpHoldDir = 0 -- 491
					end -- 491
				end -- 488
			} -- 488
		) -- 488
		btn.root.position = Vec2(x, viewH - 96 - WarpButtonH) -- 497
		warpButtons[#warpButtons + 1] = btn -- 498
	end -- 466
	local warpLeftX = viewW - (WarpButtonW * 2 + 8) - 20 -- 500
	makeWarpButton("◀ 回退", -1, warpLeftX) -- 501
	makeWarpButton("加速 ▶", 1, warpLeftX + WarpButtonW + 8) -- 502
	dateLabel = createLabel(root, "发射日期 —", 30, ResultHintHex) -- 503
	if dateLabel ~= nil then -- 503
		dateLabel.anchor = Vec2(1, 0) -- 508
		dateLabel.position = Vec2(warpLeftX - 16, viewH - 96 - WarpButtonH + 18) -- 509
	end -- 509
	local LaunchButtonW = 220 -- 516
	local LaunchButtonH = 112 -- 517
	local launchButton = createButton( -- 518
		root, -- 518
		{ -- 518
			w = LaunchButtonW, -- 519
			h = LaunchButtonH, -- 520
			text = "发射", -- 521
			fontSize = 44, -- 522
			bgHex = ResultButtonBgHex, -- 523
			fgHex = ResultButtonFgHex, -- 524
			borderHex = ResultButtonBorderHex, -- 525
			fireOn = "press", -- 526
			onTap = function() -- 527
				print("[escape-velocity] launch button fire (press)") -- 529
				if launchHandler ~= nil then -- 529
					launchHandler() -- 530
				end -- 530
			end -- 527
		} -- 527
	) -- 527
	launchButton.root.position = Vec2(viewW - LaunchButtonW - 24, 96) -- 533
	launchButton.root.visible = false -- 534
	launchButton:setEnabled(false) -- 535
	local brakeRightX = viewW - BrakeButtonW - 20 -- 537
	makeBrakeButton("惯性", false, brakeRightX - BrakeButtonW - brakeGap) -- 538
	makeBrakeButton("刹车", true, brakeRightX) -- 539
	paintBrake() -- 540
	parent:addChild(root) -- 542
	return { -- 544
		onDrag = function(____, callback) -- 545
			dragHandler = callback -- 546
		end, -- 545
		setEnabled = function(____, value) -- 548
			enabled = value -- 549
			touchLayer.touchEnabled = value -- 552
			if not value then -- 552
				dragging = false -- 553
			end -- 553
		end, -- 548
		onBrake = function(____, callback) -- 555
			brakeHandler = callback -- 556
		end, -- 555
		setBrake = function(____, on) -- 558
			brakeOn = on -- 559
			paintBrake() -- 560
		end, -- 558
		onAimReady = function(____, callback) -- 562
			readyHandler = callback -- 563
		end, -- 562
		onObserve = function(____, callback) -- 565
			observeHandler = callback -- 566
		end, -- 565
		onZoom = function(____, callback) -- 568
			zoomHandler = callback -- 569
		end, -- 568
		onLaunch = function(____, callback) -- 571
			launchHandler = callback -- 572
		end, -- 571
		setArmed = function(____, armed) -- 574
			launchButton.root.visible = armed -- 575
			launchButton:setEnabled(armed) -- 576
		end, -- 574
		onWarp = function(____, callback) -- 578
			warpHandler = callback -- 579
		end, -- 578
		setDate = function(____, t0, span) -- 581
			dateSpan = span > 0 and span or 0 -- 582
			applyWarpState() -- 583
			local on = dateSpan > 0 -- 584
			local text = on and (("发射日期 " .. __TS__NumberToFixed(t0, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0) or "发射日期" -- 585
			if text ~= lastDateText then -- 585
				lastDateText = text -- 587
				setLabelText(dateLabel, text) -- 588
			end -- 588
		end, -- 581
		setTimeEnabled = function(____, on) -- 591
			if warpAllowed == on then -- 591
				return -- 592
			end -- 592
			warpAllowed = on -- 593
			applyWarpState() -- 594
		end, -- 591
		update = function(____, dt) -- 596
			if not warpOn or warpHoldDir == 0 then -- 596
				return -- 597
			end -- 597
			warpRepeatIn = warpRepeatIn - dt -- 598
			if warpRepeatIn > 0 then -- 598
				return -- 599
			end -- 599
			warpRepeatIn = TimeWarpStep / TimeWarpRate -- 601
			if warpHandler ~= nil then -- 601
				warpHandler(warpHoldDir) -- 602
			end -- 602
		end, -- 596
		isDragging = function() return dragging end, -- 604
		setBurnInfo = function(____, burn, budget) -- 605
			setLabelText( -- 606
				dvLabel, -- 606
				(("Δv " .. __TS__NumberToFixed(burn, 1)) .. " / ") .. __TS__NumberToFixed(budget, 0) -- 606
			) -- 606
		end, -- 605
		current = function() return aim end, -- 608
		setProbeOffset = function(____, offset) -- 609
			probeOffset = offset -- 610
		end, -- 609
		handleLocal = function(____, ____local) -- 614
			handleDelta(____exports.localToOffset(____local, space)) -- 615
		end, -- 614
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 618
		debugProbeOffset = function() return probeOffset end, -- 619
		root = root -- 620
	} -- 620
end -- 261
local ResultBackdropHex = 329484 -- 637
local ResultCardHex = 1252395 -- 638
local ResultCardBorderHex = 3362938 -- 639
local ResultLevelHex = 9417948 -- 640
local ResultBodyHex = 14149367 -- 641
ResultHintHex = 8229803 -- 642
ResultButtonBgHex = 1919610 -- 643
ResultButtonAltBgHex = 1779509 -- 644
ResultButtonFgHex = 15398143 -- 645
ResultButtonBorderHex = 5211846 -- 646
local TitleSuccessHex = 8381344 -- 647
local TitleMissedHex = 16766073 -- 648
local TitleCrashedHex = 16743019 -- 649
local SelectBackdropHex = 329484 -- 651
local SelectTitleHex = 16777215 -- 652
local SelectSubtitleHex = 10470632 -- 653
local SelectHintHex = 7309478 -- 654
local SelectOpenBgHex = 1919610 -- 655
local SelectOpenFgHex = 15398143 -- 656
local SelectLockedBgHex = 1383204 -- 657
local SelectLockedFgHex = 6912140 -- 658
local SelectBorderHex = 4157096 -- 659
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 662
	if value < lo then -- 662
		return lo -- 663
	end -- 663
	if value > hi then -- 663
		return hi -- 664
	end -- 664
	return value -- 665
end -- 662
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 669
	if result == "success" then -- 669
		return "借力成功" -- 670
	end -- 670
	if result == "crashed" then -- 670
		return "信号中断" -- 671
	end -- 671
	return "错过目标" -- 672
end -- 669
--- 三态说明句（逐字）。
local function resultBody(result) -- 676
	if result == "success" then -- 676
		return "行星把探测器甩了出去，速度够了。" -- 677
	end -- 677
	if result == "crashed" then -- 677
		return "探测器撞上行星，任务到此为止。" -- 678
	end -- 678
	return "从行星身侧掠过，没能借到那一点速度。" -- 679
end -- 676
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 683
	if result == "success" then -- 683
		return TitleSuccessHex -- 684
	end -- 684
	if result == "crashed" then -- 684
		return TitleCrashedHex -- 685
	end -- 685
	return TitleMissedHex -- 686
end -- 683
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 695
	if result == "success" then -- 695
		return "下一关已解锁" -- 696
	end -- 696
	return "可重试本关，或返回关卡选择" -- 697
end -- 695
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 726
	local root = createPanel( -- 732
		parent, -- 732
		viewW, -- 732
		viewH, -- 732
		ResultBackdropHex, -- 732
		{alpha = 0.78} -- 732
	) -- 732
	local cardW = viewW * 0.88 -- 737
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 900) -- 738
	local btnH = clampNumber(viewH * 0.13, MinButtonHeight, 150) -- 739
	local padX = (cardW - btnW) / 2 -- 740
	local padY = 44 -- 741
	local fontLevel = 34 -- 743
	local fontTitle = 66 -- 744
	local fontBody = 34 -- 745
	local fontHint = 30 -- 746
	local btnFont = 40 -- 747
	local rowGap = 26 -- 748
	local hLevel = fontLevel + 10 -- 751
	local hTitle = fontTitle + 18 -- 752
	local hBody = fontBody * 2 + 12 -- 753
	local hHint = fontHint + 10 -- 754
	local cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 755
	if cardH > viewH - 24 then -- 755
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 758
		cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 759
	end -- 759
	local card = createPanel( -- 762
		root, -- 762
		cardW, -- 762
		cardH, -- 762
		ResultCardHex, -- 762
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 762
	) -- 762
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 767
	local cursor = cardH - padY -- 770
	cursor = cursor - hLevel -- 772
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 773
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 774
	cursor = cursor - (rowGap + hTitle) -- 776
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 777
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 778
	cursor = cursor - (rowGap + hBody) -- 780
	local bodyLabel = createLabel(card, "", fontBody, ResultBodyHex) -- 781
	setLabelCenter(bodyLabel, cardW / 2, cursor + hBody / 2) -- 782
	if bodyLabel ~= nil then -- 782
		bodyLabel.textWidth = cardW - 80 -- 783
	end -- 783
	cursor = cursor - (rowGap + hHint) -- 785
	local hintLabel = createLabel(card, "", fontHint, ResultHintHex) -- 786
	setLabelCenter(hintLabel, cardW / 2, cursor + hHint / 2) -- 787
	cursor = cursor - (rowGap + btnH) -- 790
	local retryButton = createButton(card, { -- 791
		w = btnW, -- 792
		h = btnH, -- 793
		text = "重试本关", -- 794
		fontSize = btnFont, -- 795
		bgHex = ResultButtonBgHex, -- 796
		fgHex = ResultButtonFgHex, -- 797
		borderHex = ResultButtonBorderHex, -- 798
		fireOn = "press", -- 799
		onTap = opts.onRetry -- 800
	}) -- 800
	retryButton.root.position = Vec2(padX, cursor) -- 802
	cursor = cursor - (22 + btnH) -- 804
	local backButton = createButton(card, { -- 805
		w = btnW, -- 806
		h = btnH, -- 807
		text = "返回关卡选择", -- 808
		fontSize = btnFont, -- 809
		bgHex = ResultButtonAltBgHex, -- 810
		fgHex = ResultButtonFgHex, -- 811
		borderHex = ResultButtonBorderHex, -- 812
		fireOn = "press", -- 813
		onTap = opts.onBackToSelect -- 814
	}) -- 814
	backButton.root.position = Vec2(padX, cursor) -- 816
	root.visible = false -- 818
	retryButton:setEnabled(false) -- 821
	backButton:setEnabled(false) -- 822
	return { -- 824
		root = root, -- 825
		show = function(____, result, levelName) -- 826
			retryButton:setEnabled(true) -- 828
			backButton:setEnabled(true) -- 829
			setLabelText(levelLabel, levelName) -- 830
			setLabelText( -- 831
				titleLabel, -- 831
				resultTitle(result) -- 831
			) -- 831
			setLabelColor( -- 832
				titleLabel, -- 832
				resultTitleColor(result) -- 832
			) -- 832
			setLabelText( -- 833
				bodyLabel, -- 833
				resultBody(result) -- 833
			) -- 833
			setLabelText( -- 834
				hintLabel, -- 834
				resultHint(result) -- 834
			) -- 834
			root.visible = true -- 835
		end, -- 826
		hide = function() -- 837
			root.visible = false -- 838
			retryButton:setEnabled(false) -- 841
			backButton:setEnabled(false) -- 842
		end -- 837
	} -- 837
end -- 726
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 882
	local root = createPanel( -- 888
		parent, -- 888
		viewW, -- 888
		viewH, -- 888
		SelectBackdropHex, -- 888
		{alpha = 0.9} -- 888
	) -- 888
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 890
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 891
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 893
	setLabelCenter( -- 894
		subtitleLabel, -- 894
		viewW / 2, -- 894
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 894
	) -- 894
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 896
	setLabelCenter( -- 897
		hintLabel, -- 897
		viewW / 2, -- 897
		clampNumber(viewH * 0.045, 36, 90) -- 897
	) -- 897
	local count = #opts.levels -- 899
	local cols = viewH > viewW and 2 or 1 -- 902
	local rows = math.max( -- 903
		1, -- 903
		math.ceil(count / cols) -- 903
	) -- 903
	local gap = 18 -- 904
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 905
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 906
	local availW = viewW * 0.84 -- 907
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 908
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 909
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 910
	local gridW = cols * btnW + gap * (cols - 1) -- 911
	local topY = viewH - headerH -- 912
	local buttons = {} -- 914
	do -- 914
		local i = 0 -- 915
		while i < count do -- 915
			local index = i -- 917
			local button = createButton( -- 918
				root, -- 918
				{ -- 918
					w = btnW, -- 919
					h = btnH, -- 920
					text = opts.levels[index + 1].name, -- 921
					fontSize = 38, -- 922
					bgHex = SelectLockedBgHex, -- 923
					fgHex = SelectLockedFgHex, -- 924
					borderHex = SelectBorderHex, -- 925
					fireOn = "press", -- 927
					onTap = function() return opts:onPick(index) end -- 928
				} -- 928
			) -- 928
			local col = index % cols -- 930
			local rowIndex = math.floor(index / cols) -- 931
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 932
			buttons[#buttons + 1] = button -- 936
			i = i + 1 -- 915
		end -- 915
	end -- 915
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 942
		root, -- 943
		{ -- 943
			w = clampNumber(viewW * 0.36, 180, 300), -- 944
			h = MinButtonHeight, -- 945
			text = "重看开场", -- 946
			fontSize = 30, -- 947
			bgHex = SelectLockedBgHex, -- 948
			fgHex = SelectSubtitleHex, -- 949
			borderHex = SelectBorderHex, -- 950
			fireOn = "press", -- 951
			onTap = function() -- 952
				if opts.onReplayIntro ~= nil then -- 952
					opts:onReplayIntro() -- 953
				end -- 953
			end -- 952
		} -- 952
	) or nil -- 952
	if replayButton ~= nil then -- 952
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 958
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 959
		replayButton.root.position = Vec2( -- 960
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 960
			by -- 960
		) -- 960
	end -- 960
	root.visible = false -- 963
	do -- 963
		local i = 0 -- 964
		while i < count do -- 964
			buttons[i + 1]:setEnabled(false) -- 964
			i = i + 1 -- 964
		end -- 964
	end -- 964
	if replayButton ~= nil then -- 964
		replayButton:setEnabled(false) -- 965
	end -- 965
	return { -- 967
		root = root, -- 968
		show = function(____, unlocked) -- 969
			local maxUnlocked = clampNumber( -- 970
				math.floor(unlocked), -- 970
				0, -- 970
				count - 1 -- 970
			) -- 970
			setLabelText( -- 971
				subtitleLabel, -- 971
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 971
			) -- 971
			do -- 971
				local i = 0 -- 972
				while i < count do -- 972
					local button = buttons[i + 1] -- 973
					local open = i <= maxUnlocked -- 974
					button:setEnabled(open) -- 975
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 976
					if open then -- 976
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 977
					else -- 977
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 978
					end -- 978
					i = i + 1 -- 972
				end -- 972
			end -- 972
			root.visible = true -- 980
			if replayButton ~= nil then -- 980
				replayButton:setEnabled(true) -- 981
			end -- 981
		end, -- 969
		hide = function() -- 983
			root.visible = false -- 984
			do -- 984
				local i = 0 -- 986
				while i < count do -- 986
					buttons[i + 1]:setEnabled(false) -- 986
					i = i + 1 -- 986
				end -- 986
			end -- 986
			if replayButton ~= nil then -- 986
				replayButton:setEnabled(false) -- 987
			end -- 987
		end -- 983
	} -- 983
end -- 882
return ____exports -- 882