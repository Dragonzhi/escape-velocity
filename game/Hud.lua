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
local AimMaxDragPx = ____Config.AimMaxDragPx -- 35
local AimMaxSpeed = ____Config.AimMaxSpeed -- 35
local AimMinSpeed = ____Config.AimMinSpeed -- 35
local PlaneToWorldX = ____Config.PlaneToWorldX -- 35
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 35
local ____Ui = require("game.Ui") -- 37
local MinButtonHeight = ____Ui.MinButtonHeight -- 37
local MinButtonWidth = ____Ui.MinButtonWidth -- 37
local createButton = ____Ui.createButton -- 37
local createLabel = ____Ui.createLabel -- 37
local createPanel = ____Ui.createPanel -- 37
local setLabelCenter = ____Ui.setLabelCenter -- 37
local setLabelColor = ____Ui.setLabelColor -- 37
local setLabelText = ____Ui.setLabelText -- 37
--- 纯计算：由“探测器屏幕偏移”与“当前触摸屏幕偏移”解算发射向量。
-- 
-- 方向语义（手册 §5.7）：发射方向 = **探测器 → 触摸点**。
-- 屏幕上玩家把手指移到探测器**上方**，发射就朝屏幕上方。
-- 
-- @param probeOffset 探测器在投影偏移空间中的位置
-- @param touchOffset 触摸点在投影偏移空间中的位置
-- @param maxDragPx 拖动多少像素算满力
-- @param maxSpeed 满力对应的速度（= 这一关的 Δv 预算）；省略 = 全局上限 `AimMaxSpeed`
function ____exports.computeAim(probeOffset, touchOffset, maxDragPx, maxSpeed) -- 66
	local speedTop = maxSpeed ~= nil and maxSpeed > AimMinSpeed and maxSpeed or AimMaxSpeed -- 72
	local dx = touchOffset.x - probeOffset.x -- 77
	local dy = touchOffset.y - probeOffset.y -- 78
	local len = math.sqrt(dx * dx + dy * dy) -- 80
	if len < 0.000001 then -- 80
		return {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 83
	end -- 83
	local ux = dx / len -- 86
	local uy = -dy / len -- 91
	local safeMax = maxDragPx > 1 and maxDragPx or 1 -- 93
	local power = len / safeMax -- 94
	if power < 0 then -- 94
		power = 0 -- 95
	end -- 95
	if power > 1 then -- 95
		power = 1 -- 96
	end -- 96
	local speed = AimMinSpeed + (speedTop - AimMinSpeed) * power -- 98
	return {velocity = {x = ux * speed, y = uy * speed}, power = power, unit = {x = ux, y = uy}} -- 100
end -- 66
--- 把屏幕位置（**投影偏移空间**，与 `project()` 同空间）转成平面坐标。
-- 
-- 不是矄准必需（矄准只用方向），但调试与关卡设计时有用。
-- 与 `project()` 互逆（已有往返测试守着）。
function ____exports.screenToPlane(viewPoint, basis) -- 113
	local world = screenToPlaneY(viewPoint, basis, 0) -- 117
	if world == nil then -- 117
		return nil -- 118
	end -- 118
	return {x = world.x / PlaneToWorldX, y = world.z / PlaneToWorldZ} -- 120
end -- 113
--- 默认的力度→拖动像素映射（供 UI 层统一引用）。
function ____exports.defaultMaxDragPx() -- 124
	return AimMaxDragPx -- 125
end -- 124
--- 默认速度区间（供 UI 层展示）。
function ____exports.defaultSpeedRange() -- 129
	return {min = AimMinSpeed, max = AimMaxSpeed} -- 130
end -- 129
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
function ____exports.localToOffset(____local, space) -- 151
	return {x = ____local.x - space.viewW / 2, y = ____local.y - space.viewH / 2} -- 152
end -- 151
--- 反向换算（投影偏移空间 → 全屏节点局部坐标）。
function ____exports.offsetToLocal(offset, space) -- 156
	return {x = offset.x + space.viewW / 2, y = offset.y + space.viewH / 2} -- 157
end -- 156
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
function ____exports.createAimInput(parent, viewW, viewH, maxSpeed) -- 251
	local brakeOn, paintBrake -- 251
	local speedTop = maxSpeed ~= nil and maxSpeed > AimMinSpeed and maxSpeed or AimMaxSpeed -- 258
	local root = Node() -- 259
	root.size = Size(viewW, viewH) -- 260
	root.anchor = Vec2(0, 0) -- 266
	root.position = Vec2(0, 0) -- 267
	local touchLayer = Node() -- 270
	touchLayer.size = Size(viewW, viewH) -- 271
	touchLayer.anchor = Vec2(0.5, 0.5) -- 272
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 273
	touchLayer.swallowTouches = true -- 274
	root:addChild(touchLayer) -- 275
	local space = {viewW = viewW, viewH = viewH} -- 277
	local enabled = false -- 279
	local dragging = false -- 280
	local aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 281
	local probeOffset = {x = 0, y = 0} -- 284
	local dragHandler = nil -- 286
	local readyHandler = nil -- 287
	local observeHandler = nil -- 288
	local zoomHandler = nil -- 289
	local launchHandler = nil -- 290
	local pressOffset = {x = 0, y = 0} -- 301
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 304
		aim = ____exports.computeAim({x = 0, y = 0}, delta, AimMaxDragPx, speedTop) -- 305
		if dragHandler ~= nil then -- 305
			dragHandler(aim) -- 306
		end -- 306
	end -- 304
	local aimRadius = math.max(96, viewW * 0.25) -- 313
	local mode = "none" -- 314
	local observeLast = {x = 0, y = 0} -- 315
	touchLayer:onTapBegan(function(touch) -- 316
		if not enabled then -- 316
			return -- 317
		end -- 317
		local at = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 318
		local dx = at.x - probeOffset.x -- 319
		local dy = at.y - probeOffset.y -- 320
		if math.sqrt(dx * dx + dy * dy) <= aimRadius then -- 320
			mode = "aim" -- 322
			dragging = true -- 323
			pressOffset = at -- 324
			handleDelta({x = 0, y = 0}) -- 326
		else -- 326
			mode = "observe" -- 328
			observeLast = at -- 329
		end -- 329
	end) -- 316
	touchLayer:onTapMoved(function(touch) -- 333
		if not enabled then -- 333
			return -- 334
		end -- 334
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 335
		if mode == "aim" and dragging then -- 335
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 337
		elseif mode == "observe" then -- 337
			if observeHandler ~= nil then -- 337
				observeHandler(cur.x - observeLast.x, cur.y - observeLast.y) -- 340
			end -- 340
			observeLast = cur -- 341
		end -- 341
	end) -- 333
	touchLayer:onTapEnded(function(touch) -- 345
		if not enabled then -- 345
			return -- 346
		end -- 346
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 347
		if mode == "aim" then -- 347
			dragging = false -- 349
			handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 350
			if readyHandler ~= nil then -- 350
				readyHandler(aim) -- 352
			end -- 352
		end -- 352
		mode = "none" -- 354
	end) -- 345
	touchLayer:onGesture(function(_center, numFingers, deltaDist, _deltaAngle) -- 358
		if not enabled or numFingers < 2 then -- 358
			return -- 359
		end -- 359
		if zoomHandler ~= nil then -- 359
			zoomHandler(deltaDist) -- 360
		end -- 360
	end) -- 358
	touchLayer.touchEnabled = false -- 368
	local brakeHandler = nil -- 373
	local BrakeButtonW = 116 -- 374
	local BrakeButtonH = 64 -- 375
	local brakeGap = 8 -- 376
	local brakeButtons = {} -- 380
	local function makeBrakeButton(text, on, x) -- 381
		local btn = createButton( -- 382
			root, -- 382
			{ -- 382
				w = BrakeButtonW, -- 383
				h = BrakeButtonH, -- 384
				text = text, -- 385
				fontSize = 30, -- 386
				bgHex = ResultButtonAltBgHex, -- 387
				fgHex = ResultButtonFgHex, -- 388
				borderHex = ResultButtonBorderHex, -- 389
				onTap = function() -- 390
					brakeOn = on -- 393
					paintBrake() -- 394
					if brakeHandler ~= nil then -- 394
						brakeHandler(on) -- 395
					end -- 395
				end -- 390
			} -- 390
		) -- 390
		btn.root.position = Vec2(x, viewH - BrakeButtonH - 20) -- 398
		brakeButtons[#brakeButtons + 1] = btn -- 399
	end -- 381
	brakeOn = false -- 401
	paintBrake = function() -- 402
		if #brakeButtons < 2 then -- 402
			return -- 403
		end -- 403
		brakeButtons[1]:setColors(brakeOn and ResultButtonAltBgHex or ResultButtonBgHex, ResultButtonFgHex) -- 404
		brakeButtons[2]:setColors(brakeOn and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 405
	end -- 402
	local dvLabel = createLabel(root, "Δv — / —", 30, ResultHintHex) -- 409
	if dvLabel ~= nil then -- 409
		dvLabel.position = Vec2(24, viewH - 44) -- 411
		dvLabel.anchor = Vec2(0, 0) -- 412
	end -- 412
	local warpHandler = nil -- 419
	local dateSpan = 0 -- 420
	local WarpButtonW = 116 -- 421
	local WarpButtonH = 64 -- 422
	local warpButtons = {} -- 423
	local function makeWarpButton(text, dir, x) -- 424
		local btn = createButton( -- 425
			root, -- 425
			{ -- 425
				w = WarpButtonW, -- 426
				h = WarpButtonH, -- 427
				text = text, -- 428
				fontSize = 30, -- 429
				bgHex = ResultButtonAltBgHex, -- 430
				fgHex = ResultButtonFgHex, -- 431
				borderHex = ResultButtonBorderHex, -- 432
				onTap = function() -- 433
					if warpHandler ~= nil then -- 433
						warpHandler(dir) -- 435
					end -- 435
				end -- 433
			} -- 433
		) -- 433
		btn.root.position = Vec2(x, viewH - 96 - WarpButtonH) -- 441
		warpButtons[#warpButtons + 1] = btn -- 442
	end -- 424
	local warpLeftX = viewW - (WarpButtonW * 2 + 8) - 20 -- 444
	makeWarpButton("◀ 回退", -1, warpLeftX) -- 445
	makeWarpButton("加速 ▶", 1, warpLeftX + WarpButtonW + 8) -- 446
	local dateLabel = createLabel(root, "发射日期 —", 30, ResultHintHex) -- 447
	if dateLabel ~= nil then -- 447
		dateLabel.position = Vec2(24, viewH - 96 - WarpButtonH + 16) -- 449
		dateLabel.anchor = Vec2(0, 0) -- 450
	end -- 450
	local LaunchButtonW = 200 -- 455
	local LaunchButtonH = 96 -- 456
	local launchButton = createButton( -- 457
		root, -- 457
		{ -- 457
			w = LaunchButtonW, -- 458
			h = LaunchButtonH, -- 459
			text = "发射", -- 460
			fontSize = 44, -- 461
			bgHex = ResultButtonBgHex, -- 462
			fgHex = ResultButtonFgHex, -- 463
			borderHex = ResultButtonBorderHex, -- 464
			onTap = function() -- 465
				if launchHandler ~= nil then -- 465
					launchHandler() -- 467
				end -- 467
			end -- 465
		} -- 465
	) -- 465
	launchButton.root.position = Vec2(viewW - LaunchButtonW - 24, 96) -- 470
	launchButton.root.visible = false -- 471
	launchButton:setEnabled(false) -- 472
	local brakeRightX = viewW - BrakeButtonW - 20 -- 474
	makeBrakeButton("惯性", false, brakeRightX - BrakeButtonW - brakeGap) -- 475
	makeBrakeButton("刹车", true, brakeRightX) -- 476
	paintBrake() -- 477
	parent:addChild(root) -- 479
	return { -- 481
		onDrag = function(____, callback) -- 482
			dragHandler = callback -- 483
		end, -- 482
		setEnabled = function(____, value) -- 485
			enabled = value -- 486
			touchLayer.touchEnabled = value -- 489
			if not value then -- 489
				dragging = false -- 490
			end -- 490
		end, -- 485
		onBrake = function(____, callback) -- 492
			brakeHandler = callback -- 493
		end, -- 492
		setBrake = function(____, on) -- 495
			brakeOn = on -- 496
			paintBrake() -- 497
		end, -- 495
		onAimReady = function(____, callback) -- 499
			readyHandler = callback -- 500
		end, -- 499
		onObserve = function(____, callback) -- 502
			observeHandler = callback -- 503
		end, -- 502
		onZoom = function(____, callback) -- 505
			zoomHandler = callback -- 506
		end, -- 505
		onLaunch = function(____, callback) -- 508
			launchHandler = callback -- 509
		end, -- 508
		setArmed = function(____, armed) -- 511
			launchButton.root.visible = armed -- 512
			launchButton:setEnabled(armed) -- 513
		end, -- 511
		onWarp = function(____, callback) -- 515
			warpHandler = callback -- 516
		end, -- 515
		setDate = function(____, t0, span) -- 518
			dateSpan = span > 0 and span or 0 -- 519
			local on = dateSpan > 0 -- 520
			for ____, b in ipairs(warpButtons) do -- 521
				b.root.visible = on -- 522
				b:setEnabled(on) -- 523
			end -- 523
			if dateLabel ~= nil then -- 523
				dateLabel.visible = on -- 525
			end -- 525
			setLabelText( -- 526
				dateLabel, -- 526
				on and ((("发射日期 " .. __TS__NumberToFixed(t0, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0)) .. " 秒" or "发射日期" -- 526
			) -- 526
		end, -- 518
		isDragging = function() return dragging end, -- 528
		setBurnInfo = function(____, burn, budget) -- 529
			setLabelText( -- 530
				dvLabel, -- 530
				(("Δv " .. __TS__NumberToFixed(burn, 1)) .. " / ") .. __TS__NumberToFixed(budget, 0) -- 530
			) -- 530
		end, -- 529
		current = function() return aim end, -- 532
		setProbeOffset = function(____, offset) -- 533
			probeOffset = offset -- 534
		end, -- 533
		handleLocal = function(____, ____local) -- 538
			handleDelta(____exports.localToOffset(____local, space)) -- 539
		end, -- 538
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 542
		debugProbeOffset = function() return probeOffset end, -- 543
		root = root -- 544
	} -- 544
end -- 251
local ResultBackdropHex = 329484 -- 561
local ResultCardHex = 1252395 -- 562
local ResultCardBorderHex = 3362938 -- 563
local ResultLevelHex = 9417948 -- 564
local ResultBodyHex = 14149367 -- 565
ResultHintHex = 8229803 -- 566
ResultButtonBgHex = 1919610 -- 567
ResultButtonAltBgHex = 1779509 -- 568
ResultButtonFgHex = 15398143 -- 569
ResultButtonBorderHex = 5211846 -- 570
local TitleSuccessHex = 8381344 -- 571
local TitleMissedHex = 16766073 -- 572
local TitleCrashedHex = 16743019 -- 573
local SelectBackdropHex = 329484 -- 575
local SelectTitleHex = 16777215 -- 576
local SelectSubtitleHex = 10470632 -- 577
local SelectHintHex = 7309478 -- 578
local SelectOpenBgHex = 1919610 -- 579
local SelectOpenFgHex = 15398143 -- 580
local SelectLockedBgHex = 1383204 -- 581
local SelectLockedFgHex = 6912140 -- 582
local SelectBorderHex = 4157096 -- 583
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 586
	if value < lo then -- 586
		return lo -- 587
	end -- 587
	if value > hi then -- 587
		return hi -- 588
	end -- 588
	return value -- 589
end -- 586
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 593
	if result == "success" then -- 593
		return "借力成功" -- 594
	end -- 594
	if result == "crashed" then -- 594
		return "信号中断" -- 595
	end -- 595
	return "错过目标" -- 596
end -- 593
--- 三态说明句（逐字）。
local function resultBody(result) -- 600
	if result == "success" then -- 600
		return "行星把探测器甩了出去，速度够了。" -- 601
	end -- 601
	if result == "crashed" then -- 601
		return "探测器撞上行星，任务到此为止。" -- 602
	end -- 602
	return "从行星身侧掠过，没能借到那一点速度。" -- 603
end -- 600
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 607
	if result == "success" then -- 607
		return TitleSuccessHex -- 608
	end -- 608
	if result == "crashed" then -- 608
		return TitleCrashedHex -- 609
	end -- 609
	return TitleMissedHex -- 610
end -- 607
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 619
	if result == "success" then -- 619
		return "下一关已解锁" -- 620
	end -- 620
	return "可重试本关，或返回关卡选择" -- 621
end -- 619
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 650
	local root = createPanel( -- 656
		parent, -- 656
		viewW, -- 656
		viewH, -- 656
		ResultBackdropHex, -- 656
		{alpha = 0.78} -- 656
	) -- 656
	local cardW = viewW * 0.88 -- 661
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 900) -- 662
	local btnH = clampNumber(viewH * 0.13, MinButtonHeight, 150) -- 663
	local padX = (cardW - btnW) / 2 -- 664
	local padY = 44 -- 665
	local fontLevel = 34 -- 667
	local fontTitle = 66 -- 668
	local fontBody = 34 -- 669
	local fontHint = 30 -- 670
	local btnFont = 40 -- 671
	local rowGap = 26 -- 672
	local hLevel = fontLevel + 10 -- 675
	local hTitle = fontTitle + 18 -- 676
	local hBody = fontBody * 2 + 12 -- 677
	local hHint = fontHint + 10 -- 678
	local cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 679
	if cardH > viewH - 24 then -- 679
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 682
		cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 683
	end -- 683
	local card = createPanel( -- 686
		root, -- 686
		cardW, -- 686
		cardH, -- 686
		ResultCardHex, -- 686
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 686
	) -- 686
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 691
	local cursor = cardH - padY -- 694
	cursor = cursor - hLevel -- 696
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 697
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 698
	cursor = cursor - (rowGap + hTitle) -- 700
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 701
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 702
	cursor = cursor - (rowGap + hBody) -- 704
	local bodyLabel = createLabel(card, "", fontBody, ResultBodyHex) -- 705
	setLabelCenter(bodyLabel, cardW / 2, cursor + hBody / 2) -- 706
	if bodyLabel ~= nil then -- 706
		bodyLabel.textWidth = cardW - 80 -- 707
	end -- 707
	cursor = cursor - (rowGap + hHint) -- 709
	local hintLabel = createLabel(card, "", fontHint, ResultHintHex) -- 710
	setLabelCenter(hintLabel, cardW / 2, cursor + hHint / 2) -- 711
	cursor = cursor - (rowGap + btnH) -- 714
	local retryButton = createButton(card, { -- 715
		w = btnW, -- 716
		h = btnH, -- 717
		text = "重试本关", -- 718
		fontSize = btnFont, -- 719
		bgHex = ResultButtonBgHex, -- 720
		fgHex = ResultButtonFgHex, -- 721
		borderHex = ResultButtonBorderHex, -- 722
		onTap = opts.onRetry -- 723
	}) -- 723
	retryButton.root.position = Vec2(padX, cursor) -- 725
	cursor = cursor - (22 + btnH) -- 727
	local backButton = createButton(card, { -- 728
		w = btnW, -- 729
		h = btnH, -- 730
		text = "返回关卡选择", -- 731
		fontSize = btnFont, -- 732
		bgHex = ResultButtonAltBgHex, -- 733
		fgHex = ResultButtonFgHex, -- 734
		borderHex = ResultButtonBorderHex, -- 735
		onTap = opts.onBackToSelect -- 736
	}) -- 736
	backButton.root.position = Vec2(padX, cursor) -- 738
	root.visible = false -- 740
	retryButton:setEnabled(false) -- 743
	backButton:setEnabled(false) -- 744
	return { -- 746
		root = root, -- 747
		show = function(____, result, levelName) -- 748
			retryButton:setEnabled(true) -- 750
			backButton:setEnabled(true) -- 751
			setLabelText(levelLabel, levelName) -- 752
			setLabelText( -- 753
				titleLabel, -- 753
				resultTitle(result) -- 753
			) -- 753
			setLabelColor( -- 754
				titleLabel, -- 754
				resultTitleColor(result) -- 754
			) -- 754
			setLabelText( -- 755
				bodyLabel, -- 755
				resultBody(result) -- 755
			) -- 755
			setLabelText( -- 756
				hintLabel, -- 756
				resultHint(result) -- 756
			) -- 756
			root.visible = true -- 757
		end, -- 748
		hide = function() -- 759
			root.visible = false -- 760
			retryButton:setEnabled(false) -- 763
			backButton:setEnabled(false) -- 764
		end -- 759
	} -- 759
end -- 650
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 804
	local root = createPanel( -- 810
		parent, -- 810
		viewW, -- 810
		viewH, -- 810
		SelectBackdropHex, -- 810
		{alpha = 0.9} -- 810
	) -- 810
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 812
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 813
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 815
	setLabelCenter( -- 816
		subtitleLabel, -- 816
		viewW / 2, -- 816
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 816
	) -- 816
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 818
	setLabelCenter( -- 819
		hintLabel, -- 819
		viewW / 2, -- 819
		clampNumber(viewH * 0.045, 36, 90) -- 819
	) -- 819
	local count = #opts.levels -- 821
	local cols = viewH > viewW and 2 or 1 -- 824
	local rows = math.max( -- 825
		1, -- 825
		math.ceil(count / cols) -- 825
	) -- 825
	local gap = 18 -- 826
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 827
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 828
	local availW = viewW * 0.84 -- 829
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 830
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 831
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 832
	local gridW = cols * btnW + gap * (cols - 1) -- 833
	local topY = viewH - headerH -- 834
	local buttons = {} -- 836
	do -- 836
		local i = 0 -- 837
		while i < count do -- 837
			local index = i -- 839
			local button = createButton( -- 840
				root, -- 840
				{ -- 840
					w = btnW, -- 841
					h = btnH, -- 842
					text = opts.levels[index + 1].name, -- 843
					fontSize = 38, -- 844
					bgHex = SelectLockedBgHex, -- 845
					fgHex = SelectLockedFgHex, -- 846
					borderHex = SelectBorderHex, -- 847
					onTap = function() return opts:onPick(index) end -- 848
				} -- 848
			) -- 848
			local col = index % cols -- 850
			local rowIndex = math.floor(index / cols) -- 851
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 852
			buttons[#buttons + 1] = button -- 856
			i = i + 1 -- 837
		end -- 837
	end -- 837
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 862
		root, -- 863
		{ -- 863
			w = clampNumber(viewW * 0.36, 180, 300), -- 864
			h = MinButtonHeight, -- 865
			text = "重看开场", -- 866
			fontSize = 30, -- 867
			bgHex = SelectLockedBgHex, -- 868
			fgHex = SelectSubtitleHex, -- 869
			borderHex = SelectBorderHex, -- 870
			onTap = function() -- 871
				if opts.onReplayIntro ~= nil then -- 871
					opts:onReplayIntro() -- 872
				end -- 872
			end -- 871
		} -- 871
	) or nil -- 871
	if replayButton ~= nil then -- 871
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 877
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 878
		replayButton.root.position = Vec2( -- 879
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 879
			by -- 879
		) -- 879
	end -- 879
	root.visible = false -- 882
	do -- 882
		local i = 0 -- 883
		while i < count do -- 883
			buttons[i + 1]:setEnabled(false) -- 883
			i = i + 1 -- 883
		end -- 883
	end -- 883
	if replayButton ~= nil then -- 883
		replayButton:setEnabled(false) -- 884
	end -- 884
	return { -- 886
		root = root, -- 887
		show = function(____, unlocked) -- 888
			local maxUnlocked = clampNumber( -- 889
				math.floor(unlocked), -- 889
				0, -- 889
				count - 1 -- 889
			) -- 889
			setLabelText( -- 890
				subtitleLabel, -- 890
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 890
			) -- 890
			do -- 890
				local i = 0 -- 891
				while i < count do -- 891
					local button = buttons[i + 1] -- 892
					local open = i <= maxUnlocked -- 893
					button:setEnabled(open) -- 894
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 895
					if open then -- 895
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 896
					else -- 896
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 897
					end -- 897
					i = i + 1 -- 891
				end -- 891
			end -- 891
			root.visible = true -- 899
			if replayButton ~= nil then -- 899
				replayButton:setEnabled(true) -- 900
			end -- 900
		end, -- 888
		hide = function() -- 902
			root.visible = false -- 903
			do -- 903
				local i = 0 -- 905
				while i < count do -- 905
					buttons[i + 1]:setEnabled(false) -- 905
					i = i + 1 -- 905
				end -- 905
			end -- 905
			if replayButton ~= nil then -- 905
				replayButton:setEnabled(false) -- 906
			end -- 906
		end -- 902
	} -- 902
end -- 804
return ____exports -- 804