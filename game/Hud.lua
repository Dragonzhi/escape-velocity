-- [ts]: Hud.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ResultHintHex, ResultButtonBgHex, ResultButtonAltBgHex, ResultButtonFgHex, ResultButtonBorderHex -- 1
local ____Dora = require("Dora") -- 32
local Color = ____Dora.Color -- 32
local DrawNode = ____Dora.DrawNode -- 32
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
function ____exports.createAimInput(parent, viewW, viewH, maxSpeed) -- 239
	local brakeOn, paintBrake -- 239
	local speedTop = maxSpeed ~= nil and maxSpeed > AimMinSpeed and maxSpeed or AimMaxSpeed -- 246
	local root = Node() -- 247
	root.size = Size(viewW, viewH) -- 248
	root.anchor = Vec2(0, 0) -- 254
	root.position = Vec2(0, 0) -- 255
	local touchLayer = Node() -- 258
	touchLayer.size = Size(viewW, viewH) -- 259
	touchLayer.anchor = Vec2(0.5, 0.5) -- 260
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 261
	touchLayer.swallowTouches = true -- 262
	root:addChild(touchLayer) -- 263
	local space = {viewW = viewW, viewH = viewH} -- 265
	local enabled = false -- 267
	local dragging = false -- 268
	local aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 269
	local probeOffset = {x = 0, y = 0} -- 272
	local dragHandler = nil -- 274
	local releaseHandler = nil -- 275
	local pressOffset = {x = 0, y = 0} -- 286
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 289
		aim = ____exports.computeAim({x = 0, y = 0}, delta, AimMaxDragPx, speedTop) -- 290
		if dragHandler ~= nil then -- 290
			dragHandler(aim) -- 291
		end -- 291
	end -- 289
	touchLayer:onTapBegan(function(touch) -- 294
		if not enabled then -- 294
			return -- 295
		end -- 295
		dragging = true -- 296
		pressOffset = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 297
		handleDelta({x = 0, y = 0}) -- 299
	end) -- 294
	touchLayer:onTapMoved(function(touch) -- 302
		if not enabled or not dragging then -- 302
			return -- 303
		end -- 303
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 304
		handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 305
	end) -- 302
	touchLayer:onTapEnded(function(touch) -- 308
		if not enabled or not dragging then -- 308
			return -- 309
		end -- 309
		dragging = false -- 310
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 311
		handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 312
		if releaseHandler ~= nil then -- 312
			releaseHandler(aim) -- 313
		end -- 313
	end) -- 308
	touchLayer.touchEnabled = false -- 321
	local brakeHandler = nil -- 326
	local BrakeButtonW = 116 -- 327
	local BrakeButtonH = 64 -- 328
	local brakeGap = 8 -- 329
	local brakeButtons = {} -- 333
	local function makeBrakeButton(text, on, x) -- 334
		local btn = createButton( -- 335
			root, -- 335
			{ -- 335
				w = BrakeButtonW, -- 336
				h = BrakeButtonH, -- 337
				text = text, -- 338
				fontSize = 30, -- 339
				bgHex = ResultButtonAltBgHex, -- 340
				fgHex = ResultButtonFgHex, -- 341
				borderHex = ResultButtonBorderHex, -- 342
				onTap = function() -- 343
					brakeOn = on -- 346
					paintBrake() -- 347
					if brakeHandler ~= nil then -- 347
						brakeHandler(on) -- 348
					end -- 348
				end -- 343
			} -- 343
		) -- 343
		btn.root.position = Vec2(x, viewH - BrakeButtonH - 20) -- 351
		brakeButtons[#brakeButtons + 1] = btn -- 352
	end -- 334
	brakeOn = false -- 354
	paintBrake = function() -- 355
		if #brakeButtons < 2 then -- 355
			return -- 356
		end -- 356
		brakeButtons[1]:setColors(brakeOn and ResultButtonAltBgHex or ResultButtonBgHex, ResultButtonFgHex) -- 357
		brakeButtons[2]:setColors(brakeOn and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 358
	end -- 355
	local dvLabel = createLabel(root, "Δv — / —", 30, ResultHintHex) -- 362
	if dvLabel ~= nil then -- 362
		dvLabel.position = Vec2(24, viewH - 44) -- 364
		dvLabel.anchor = Vec2(0, 0) -- 365
	end -- 365
	local dateHandler = nil -- 370
	local dateSpan = 0 -- 371
	local dateValue = 0 -- 372
	local SliderH = 72 -- 373
	local SliderW = math.max(220, viewW - 48) -- 374
	local slider = Node() -- 375
	slider.size = Size(SliderW, SliderH) -- 376
	slider.anchor = Vec2(0, 0) -- 377
	slider.touchEnabled = false -- 378
	slider.swallowTouches = true -- 379
	slider.position = Vec2(24, viewH - 96 - SliderH) -- 380
	local sliderDraw = DrawNode() -- 381
	slider:addChild(sliderDraw) -- 382
	local sliderLabel = createLabel(slider, "发射日期", 30, ResultHintHex) -- 383
	if sliderLabel ~= nil then -- 383
		sliderLabel.position = Vec2(0, SliderH - 4) -- 385
		sliderLabel.anchor = Vec2(0, 0) -- 386
	end -- 386
	local function paintSlider() -- 388
		sliderDraw:clear() -- 389
		sliderDraw:drawPolygon( -- 391
			{ -- 391
				Vec2(0, 10), -- 391
				Vec2(SliderW, 10), -- 391
				Vec2(SliderW, 22), -- 391
				Vec2(0, 22) -- 391
			}, -- 391
			Color(40, 55, 74, 255) -- 391
		) -- 391
		local k = dateSpan > 0 and dateValue / dateSpan or 0 -- 393
		local kx = k * (SliderW - 18) -- 394
		sliderDraw:drawPolygon( -- 395
			{ -- 395
				Vec2(kx, 4), -- 395
				Vec2(kx + 18, 4), -- 395
				Vec2(kx + 18, 28), -- 395
				Vec2(kx, 28) -- 395
			}, -- 395
			Color(120, 200, 255, 255) -- 395
		) -- 395
	end -- 388
	local function setDateFromLocal(localX) -- 397
		if dateSpan <= 0 then -- 397
			return -- 398
		end -- 398
		local k = localX / SliderW -- 399
		if k < 0 then -- 399
			k = 0 -- 400
		end -- 400
		if k > 1 then -- 400
			k = 1 -- 401
		end -- 401
		dateValue = k * dateSpan -- 402
		paintSlider() -- 403
		setLabelText( -- 404
			sliderLabel, -- 404
			((("发射日期 " .. __TS__NumberToFixed(dateValue, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0)) .. " 秒" -- 404
		) -- 404
		if dateHandler ~= nil then -- 404
			dateHandler(dateValue) -- 405
		end -- 405
	end -- 397
	slider:onTapBegan(function(touch) -- 407
		setDateFromLocal(touch.location.x) -- 407
	end) -- 407
	slider:onTapMoved(function(touch) -- 408
		setDateFromLocal(touch.location.x) -- 408
	end) -- 408
	slider.touchEnabled = false -- 410
	paintSlider() -- 411
	root:addChild(slider) -- 412
	local brakeRightX = viewW - BrakeButtonW - 20 -- 414
	makeBrakeButton("惯性", false, brakeRightX - BrakeButtonW - brakeGap) -- 415
	makeBrakeButton("刹车", true, brakeRightX) -- 416
	paintBrake() -- 417
	parent:addChild(root) -- 419
	return { -- 421
		onDrag = function(____, callback) -- 422
			dragHandler = callback -- 423
		end, -- 422
		onRelease = function(____, callback) -- 425
			releaseHandler = callback -- 426
		end, -- 425
		setEnabled = function(____, value) -- 428
			enabled = value -- 429
			touchLayer.touchEnabled = value -- 432
			if not value then -- 432
				dragging = false -- 433
			end -- 433
		end, -- 428
		onBrake = function(____, callback) -- 435
			brakeHandler = callback -- 436
		end, -- 435
		setBrake = function(____, on) -- 438
			brakeOn = on -- 439
			paintBrake() -- 440
		end, -- 438
		onDate = function(____, callback) -- 442
			dateHandler = callback -- 443
		end, -- 442
		setDate = function(____, t0, span) -- 445
			dateSpan = span > 0 and span or 0 -- 446
			dateValue = t0 < 0 and 0 or (t0 > dateSpan and dateSpan or t0) -- 447
			slider.visible = dateSpan > 0 -- 449
			slider.touchEnabled = dateSpan > 0 -- 450
			setLabelText( -- 451
				sliderLabel, -- 451
				dateSpan > 0 and ((("发射日期 " .. __TS__NumberToFixed(dateValue, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0)) .. " 秒" or "发射日期" -- 451
			) -- 451
			paintSlider() -- 454
		end, -- 445
		isDragging = function() return dragging end, -- 456
		setBurnInfo = function(____, burn, budget) -- 457
			setLabelText( -- 458
				dvLabel, -- 458
				(("Δv " .. __TS__NumberToFixed(burn, 1)) .. " / ") .. __TS__NumberToFixed(budget, 0) -- 458
			) -- 458
		end, -- 457
		current = function() return aim end, -- 460
		setProbeOffset = function(____, offset) -- 461
			probeOffset = offset -- 462
		end, -- 461
		handleLocal = function(____, ____local) -- 466
			handleDelta(____exports.localToOffset(____local, space)) -- 467
		end, -- 466
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 470
		debugProbeOffset = function() return probeOffset end, -- 471
		root = root -- 472
	} -- 472
end -- 239
local ResultBackdropHex = 329484 -- 489
local ResultCardHex = 1252395 -- 490
local ResultCardBorderHex = 3362938 -- 491
local ResultLevelHex = 9417948 -- 492
local ResultBodyHex = 14149367 -- 493
ResultHintHex = 8229803 -- 494
ResultButtonBgHex = 1919610 -- 495
ResultButtonAltBgHex = 1779509 -- 496
ResultButtonFgHex = 15398143 -- 497
ResultButtonBorderHex = 5211846 -- 498
local TitleSuccessHex = 8381344 -- 499
local TitleMissedHex = 16766073 -- 500
local TitleCrashedHex = 16743019 -- 501
local SelectBackdropHex = 329484 -- 503
local SelectTitleHex = 16777215 -- 504
local SelectSubtitleHex = 10470632 -- 505
local SelectHintHex = 7309478 -- 506
local SelectOpenBgHex = 1919610 -- 507
local SelectOpenFgHex = 15398143 -- 508
local SelectLockedBgHex = 1383204 -- 509
local SelectLockedFgHex = 6912140 -- 510
local SelectBorderHex = 4157096 -- 511
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 514
	if value < lo then -- 514
		return lo -- 515
	end -- 515
	if value > hi then -- 515
		return hi -- 516
	end -- 516
	return value -- 517
end -- 514
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 521
	if result == "success" then -- 521
		return "借力成功" -- 522
	end -- 522
	if result == "crashed" then -- 522
		return "信号中断" -- 523
	end -- 523
	return "错过目标" -- 524
end -- 521
--- 三态说明句（逐字）。
local function resultBody(result) -- 528
	if result == "success" then -- 528
		return "行星把探测器甩了出去，速度够了。" -- 529
	end -- 529
	if result == "crashed" then -- 529
		return "探测器撞上行星，任务到此为止。" -- 530
	end -- 530
	return "从行星身侧掠过，没能借到那一点速度。" -- 531
end -- 528
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 535
	if result == "success" then -- 535
		return TitleSuccessHex -- 536
	end -- 536
	if result == "crashed" then -- 536
		return TitleCrashedHex -- 537
	end -- 537
	return TitleMissedHex -- 538
end -- 535
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 547
	if result == "success" then -- 547
		return "下一关已解锁" -- 548
	end -- 548
	return "可重试本关，或返回关卡选择" -- 549
end -- 547
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 578
	local root = createPanel( -- 584
		parent, -- 584
		viewW, -- 584
		viewH, -- 584
		ResultBackdropHex, -- 584
		{alpha = 0.78} -- 584
	) -- 584
	local cardW = viewW * 0.88 -- 589
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 900) -- 590
	local btnH = clampNumber(viewH * 0.13, MinButtonHeight, 150) -- 591
	local padX = (cardW - btnW) / 2 -- 592
	local padY = 44 -- 593
	local fontLevel = 34 -- 595
	local fontTitle = 66 -- 596
	local fontBody = 34 -- 597
	local fontHint = 30 -- 598
	local btnFont = 40 -- 599
	local rowGap = 26 -- 600
	local hLevel = fontLevel + 10 -- 603
	local hTitle = fontTitle + 18 -- 604
	local hBody = fontBody * 2 + 12 -- 605
	local hHint = fontHint + 10 -- 606
	local cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 607
	if cardH > viewH - 24 then -- 607
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 610
		cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 611
	end -- 611
	local card = createPanel( -- 614
		root, -- 614
		cardW, -- 614
		cardH, -- 614
		ResultCardHex, -- 614
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 614
	) -- 614
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 619
	local cursor = cardH - padY -- 622
	cursor = cursor - hLevel -- 624
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 625
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 626
	cursor = cursor - (rowGap + hTitle) -- 628
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 629
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 630
	cursor = cursor - (rowGap + hBody) -- 632
	local bodyLabel = createLabel(card, "", fontBody, ResultBodyHex) -- 633
	setLabelCenter(bodyLabel, cardW / 2, cursor + hBody / 2) -- 634
	if bodyLabel ~= nil then -- 634
		bodyLabel.textWidth = cardW - 80 -- 635
	end -- 635
	cursor = cursor - (rowGap + hHint) -- 637
	local hintLabel = createLabel(card, "", fontHint, ResultHintHex) -- 638
	setLabelCenter(hintLabel, cardW / 2, cursor + hHint / 2) -- 639
	cursor = cursor - (rowGap + btnH) -- 642
	local retryButton = createButton(card, { -- 643
		w = btnW, -- 644
		h = btnH, -- 645
		text = "重试本关", -- 646
		fontSize = btnFont, -- 647
		bgHex = ResultButtonBgHex, -- 648
		fgHex = ResultButtonFgHex, -- 649
		borderHex = ResultButtonBorderHex, -- 650
		onTap = opts.onRetry -- 651
	}) -- 651
	retryButton.root.position = Vec2(padX, cursor) -- 653
	cursor = cursor - (22 + btnH) -- 655
	local backButton = createButton(card, { -- 656
		w = btnW, -- 657
		h = btnH, -- 658
		text = "返回关卡选择", -- 659
		fontSize = btnFont, -- 660
		bgHex = ResultButtonAltBgHex, -- 661
		fgHex = ResultButtonFgHex, -- 662
		borderHex = ResultButtonBorderHex, -- 663
		onTap = opts.onBackToSelect -- 664
	}) -- 664
	backButton.root.position = Vec2(padX, cursor) -- 666
	root.visible = false -- 668
	retryButton:setEnabled(false) -- 671
	backButton:setEnabled(false) -- 672
	return { -- 674
		root = root, -- 675
		show = function(____, result, levelName) -- 676
			retryButton:setEnabled(true) -- 678
			backButton:setEnabled(true) -- 679
			setLabelText(levelLabel, levelName) -- 680
			setLabelText( -- 681
				titleLabel, -- 681
				resultTitle(result) -- 681
			) -- 681
			setLabelColor( -- 682
				titleLabel, -- 682
				resultTitleColor(result) -- 682
			) -- 682
			setLabelText( -- 683
				bodyLabel, -- 683
				resultBody(result) -- 683
			) -- 683
			setLabelText( -- 684
				hintLabel, -- 684
				resultHint(result) -- 684
			) -- 684
			root.visible = true -- 685
		end, -- 676
		hide = function() -- 687
			root.visible = false -- 688
			retryButton:setEnabled(false) -- 691
			backButton:setEnabled(false) -- 692
		end -- 687
	} -- 687
end -- 578
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 732
	local root = createPanel( -- 738
		parent, -- 738
		viewW, -- 738
		viewH, -- 738
		SelectBackdropHex, -- 738
		{alpha = 0.9} -- 738
	) -- 738
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 740
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 741
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 743
	setLabelCenter( -- 744
		subtitleLabel, -- 744
		viewW / 2, -- 744
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 744
	) -- 744
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 746
	setLabelCenter( -- 747
		hintLabel, -- 747
		viewW / 2, -- 747
		clampNumber(viewH * 0.045, 36, 90) -- 747
	) -- 747
	local count = #opts.levels -- 749
	local cols = viewH > viewW and 2 or 1 -- 752
	local rows = math.max( -- 753
		1, -- 753
		math.ceil(count / cols) -- 753
	) -- 753
	local gap = 18 -- 754
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 755
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 756
	local availW = viewW * 0.84 -- 757
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 758
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 759
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 760
	local gridW = cols * btnW + gap * (cols - 1) -- 761
	local topY = viewH - headerH -- 762
	local buttons = {} -- 764
	do -- 764
		local i = 0 -- 765
		while i < count do -- 765
			local index = i -- 767
			local button = createButton( -- 768
				root, -- 768
				{ -- 768
					w = btnW, -- 769
					h = btnH, -- 770
					text = opts.levels[index + 1].name, -- 771
					fontSize = 38, -- 772
					bgHex = SelectLockedBgHex, -- 773
					fgHex = SelectLockedFgHex, -- 774
					borderHex = SelectBorderHex, -- 775
					onTap = function() return opts:onPick(index) end -- 776
				} -- 776
			) -- 776
			local col = index % cols -- 778
			local rowIndex = math.floor(index / cols) -- 779
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 780
			buttons[#buttons + 1] = button -- 784
			i = i + 1 -- 765
		end -- 765
	end -- 765
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 790
		root, -- 791
		{ -- 791
			w = clampNumber(viewW * 0.36, 180, 300), -- 792
			h = MinButtonHeight, -- 793
			text = "重看开场", -- 794
			fontSize = 30, -- 795
			bgHex = SelectLockedBgHex, -- 796
			fgHex = SelectSubtitleHex, -- 797
			borderHex = SelectBorderHex, -- 798
			onTap = function() -- 799
				if opts.onReplayIntro ~= nil then -- 799
					opts:onReplayIntro() -- 800
				end -- 800
			end -- 799
		} -- 799
	) or nil -- 799
	if replayButton ~= nil then -- 799
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 805
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 806
		replayButton.root.position = Vec2( -- 807
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 807
			by -- 807
		) -- 807
	end -- 807
	root.visible = false -- 810
	do -- 810
		local i = 0 -- 811
		while i < count do -- 811
			buttons[i + 1]:setEnabled(false) -- 811
			i = i + 1 -- 811
		end -- 811
	end -- 811
	if replayButton ~= nil then -- 811
		replayButton:setEnabled(false) -- 812
	end -- 812
	return { -- 814
		root = root, -- 815
		show = function(____, unlocked) -- 816
			local maxUnlocked = clampNumber( -- 817
				math.floor(unlocked), -- 817
				0, -- 817
				count - 1 -- 817
			) -- 817
			setLabelText( -- 818
				subtitleLabel, -- 818
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 818
			) -- 818
			do -- 818
				local i = 0 -- 819
				while i < count do -- 819
					local button = buttons[i + 1] -- 820
					local open = i <= maxUnlocked -- 821
					button:setEnabled(open) -- 822
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 823
					if open then -- 823
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 824
					else -- 824
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 825
					end -- 825
					i = i + 1 -- 819
				end -- 819
			end -- 819
			root.visible = true -- 827
			if replayButton ~= nil then -- 827
				replayButton:setEnabled(true) -- 828
			end -- 828
		end, -- 816
		hide = function() -- 830
			root.visible = false -- 831
			do -- 831
				local i = 0 -- 833
				while i < count do -- 833
					buttons[i + 1]:setEnabled(false) -- 833
					i = i + 1 -- 833
				end -- 833
			end -- 833
			if replayButton ~= nil then -- 833
				replayButton:setEnabled(false) -- 834
			end -- 834
		end -- 830
	} -- 830
end -- 732
return ____exports -- 732