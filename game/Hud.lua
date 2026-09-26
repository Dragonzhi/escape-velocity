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
	local warpHandler = nil -- 372
	local dateSpan = 0 -- 373
	local WarpButtonW = 116 -- 374
	local WarpButtonH = 64 -- 375
	local warpButtons = {} -- 376
	local function makeWarpButton(text, dir, x) -- 377
		local btn = createButton( -- 378
			root, -- 378
			{ -- 378
				w = WarpButtonW, -- 379
				h = WarpButtonH, -- 380
				text = text, -- 381
				fontSize = 30, -- 382
				bgHex = ResultButtonAltBgHex, -- 383
				fgHex = ResultButtonFgHex, -- 384
				borderHex = ResultButtonBorderHex, -- 385
				onTap = function() -- 386
					if warpHandler ~= nil then -- 386
						warpHandler(dir) -- 388
					end -- 388
				end -- 386
			} -- 386
		) -- 386
		btn.root.position = Vec2(x, viewH - 96 - WarpButtonH) -- 394
		warpButtons[#warpButtons + 1] = btn -- 395
	end -- 377
	local warpLeftX = viewW - (WarpButtonW * 2 + 8) - 20 -- 397
	makeWarpButton("◀ 回退", -1, warpLeftX) -- 398
	makeWarpButton("加速 ▶", 1, warpLeftX + WarpButtonW + 8) -- 399
	local dateLabel = createLabel(root, "发射日期 —", 30, ResultHintHex) -- 400
	if dateLabel ~= nil then -- 400
		dateLabel.position = Vec2(24, viewH - 96 - WarpButtonH + 16) -- 402
		dateLabel.anchor = Vec2(0, 0) -- 403
	end -- 403
	local brakeRightX = viewW - BrakeButtonW - 20 -- 406
	makeBrakeButton("惯性", false, brakeRightX - BrakeButtonW - brakeGap) -- 407
	makeBrakeButton("刹车", true, brakeRightX) -- 408
	paintBrake() -- 409
	parent:addChild(root) -- 411
	return { -- 413
		onDrag = function(____, callback) -- 414
			dragHandler = callback -- 415
		end, -- 414
		onRelease = function(____, callback) -- 417
			releaseHandler = callback -- 418
		end, -- 417
		setEnabled = function(____, value) -- 420
			enabled = value -- 421
			touchLayer.touchEnabled = value -- 424
			if not value then -- 424
				dragging = false -- 425
			end -- 425
		end, -- 420
		onBrake = function(____, callback) -- 427
			brakeHandler = callback -- 428
		end, -- 427
		setBrake = function(____, on) -- 430
			brakeOn = on -- 431
			paintBrake() -- 432
		end, -- 430
		onWarp = function(____, callback) -- 434
			warpHandler = callback -- 435
		end, -- 434
		setDate = function(____, t0, span) -- 437
			dateSpan = span > 0 and span or 0 -- 438
			local on = dateSpan > 0 -- 439
			for ____, b in ipairs(warpButtons) do -- 440
				b.root.visible = on -- 441
				b:setEnabled(on) -- 442
			end -- 442
			if dateLabel ~= nil then -- 442
				dateLabel.visible = on -- 444
			end -- 444
			setLabelText( -- 445
				dateLabel, -- 445
				on and ((("发射日期 " .. __TS__NumberToFixed(t0, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0)) .. " 秒" or "发射日期" -- 445
			) -- 445
		end, -- 437
		isDragging = function() return dragging end, -- 447
		setBurnInfo = function(____, burn, budget) -- 448
			setLabelText( -- 449
				dvLabel, -- 449
				(("Δv " .. __TS__NumberToFixed(burn, 1)) .. " / ") .. __TS__NumberToFixed(budget, 0) -- 449
			) -- 449
		end, -- 448
		current = function() return aim end, -- 451
		setProbeOffset = function(____, offset) -- 452
			probeOffset = offset -- 453
		end, -- 452
		handleLocal = function(____, ____local) -- 457
			handleDelta(____exports.localToOffset(____local, space)) -- 458
		end, -- 457
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 461
		debugProbeOffset = function() return probeOffset end, -- 462
		root = root -- 463
	} -- 463
end -- 239
local ResultBackdropHex = 329484 -- 480
local ResultCardHex = 1252395 -- 481
local ResultCardBorderHex = 3362938 -- 482
local ResultLevelHex = 9417948 -- 483
local ResultBodyHex = 14149367 -- 484
ResultHintHex = 8229803 -- 485
ResultButtonBgHex = 1919610 -- 486
ResultButtonAltBgHex = 1779509 -- 487
ResultButtonFgHex = 15398143 -- 488
ResultButtonBorderHex = 5211846 -- 489
local TitleSuccessHex = 8381344 -- 490
local TitleMissedHex = 16766073 -- 491
local TitleCrashedHex = 16743019 -- 492
local SelectBackdropHex = 329484 -- 494
local SelectTitleHex = 16777215 -- 495
local SelectSubtitleHex = 10470632 -- 496
local SelectHintHex = 7309478 -- 497
local SelectOpenBgHex = 1919610 -- 498
local SelectOpenFgHex = 15398143 -- 499
local SelectLockedBgHex = 1383204 -- 500
local SelectLockedFgHex = 6912140 -- 501
local SelectBorderHex = 4157096 -- 502
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 505
	if value < lo then -- 505
		return lo -- 506
	end -- 506
	if value > hi then -- 506
		return hi -- 507
	end -- 507
	return value -- 508
end -- 505
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 512
	if result == "success" then -- 512
		return "借力成功" -- 513
	end -- 513
	if result == "crashed" then -- 513
		return "信号中断" -- 514
	end -- 514
	return "错过目标" -- 515
end -- 512
--- 三态说明句（逐字）。
local function resultBody(result) -- 519
	if result == "success" then -- 519
		return "行星把探测器甩了出去，速度够了。" -- 520
	end -- 520
	if result == "crashed" then -- 520
		return "探测器撞上行星，任务到此为止。" -- 521
	end -- 521
	return "从行星身侧掠过，没能借到那一点速度。" -- 522
end -- 519
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 526
	if result == "success" then -- 526
		return TitleSuccessHex -- 527
	end -- 527
	if result == "crashed" then -- 527
		return TitleCrashedHex -- 528
	end -- 528
	return TitleMissedHex -- 529
end -- 526
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 538
	if result == "success" then -- 538
		return "下一关已解锁" -- 539
	end -- 539
	return "可重试本关，或返回关卡选择" -- 540
end -- 538
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 569
	local root = createPanel( -- 575
		parent, -- 575
		viewW, -- 575
		viewH, -- 575
		ResultBackdropHex, -- 575
		{alpha = 0.78} -- 575
	) -- 575
	local cardW = viewW * 0.88 -- 580
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 900) -- 581
	local btnH = clampNumber(viewH * 0.13, MinButtonHeight, 150) -- 582
	local padX = (cardW - btnW) / 2 -- 583
	local padY = 44 -- 584
	local fontLevel = 34 -- 586
	local fontTitle = 66 -- 587
	local fontBody = 34 -- 588
	local fontHint = 30 -- 589
	local btnFont = 40 -- 590
	local rowGap = 26 -- 591
	local hLevel = fontLevel + 10 -- 594
	local hTitle = fontTitle + 18 -- 595
	local hBody = fontBody * 2 + 12 -- 596
	local hHint = fontHint + 10 -- 597
	local cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 598
	if cardH > viewH - 24 then -- 598
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 601
		cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 602
	end -- 602
	local card = createPanel( -- 605
		root, -- 605
		cardW, -- 605
		cardH, -- 605
		ResultCardHex, -- 605
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 605
	) -- 605
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 610
	local cursor = cardH - padY -- 613
	cursor = cursor - hLevel -- 615
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 616
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 617
	cursor = cursor - (rowGap + hTitle) -- 619
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 620
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 621
	cursor = cursor - (rowGap + hBody) -- 623
	local bodyLabel = createLabel(card, "", fontBody, ResultBodyHex) -- 624
	setLabelCenter(bodyLabel, cardW / 2, cursor + hBody / 2) -- 625
	if bodyLabel ~= nil then -- 625
		bodyLabel.textWidth = cardW - 80 -- 626
	end -- 626
	cursor = cursor - (rowGap + hHint) -- 628
	local hintLabel = createLabel(card, "", fontHint, ResultHintHex) -- 629
	setLabelCenter(hintLabel, cardW / 2, cursor + hHint / 2) -- 630
	cursor = cursor - (rowGap + btnH) -- 633
	local retryButton = createButton(card, { -- 634
		w = btnW, -- 635
		h = btnH, -- 636
		text = "重试本关", -- 637
		fontSize = btnFont, -- 638
		bgHex = ResultButtonBgHex, -- 639
		fgHex = ResultButtonFgHex, -- 640
		borderHex = ResultButtonBorderHex, -- 641
		onTap = opts.onRetry -- 642
	}) -- 642
	retryButton.root.position = Vec2(padX, cursor) -- 644
	cursor = cursor - (22 + btnH) -- 646
	local backButton = createButton(card, { -- 647
		w = btnW, -- 648
		h = btnH, -- 649
		text = "返回关卡选择", -- 650
		fontSize = btnFont, -- 651
		bgHex = ResultButtonAltBgHex, -- 652
		fgHex = ResultButtonFgHex, -- 653
		borderHex = ResultButtonBorderHex, -- 654
		onTap = opts.onBackToSelect -- 655
	}) -- 655
	backButton.root.position = Vec2(padX, cursor) -- 657
	root.visible = false -- 659
	retryButton:setEnabled(false) -- 662
	backButton:setEnabled(false) -- 663
	return { -- 665
		root = root, -- 666
		show = function(____, result, levelName) -- 667
			retryButton:setEnabled(true) -- 669
			backButton:setEnabled(true) -- 670
			setLabelText(levelLabel, levelName) -- 671
			setLabelText( -- 672
				titleLabel, -- 672
				resultTitle(result) -- 672
			) -- 672
			setLabelColor( -- 673
				titleLabel, -- 673
				resultTitleColor(result) -- 673
			) -- 673
			setLabelText( -- 674
				bodyLabel, -- 674
				resultBody(result) -- 674
			) -- 674
			setLabelText( -- 675
				hintLabel, -- 675
				resultHint(result) -- 675
			) -- 675
			root.visible = true -- 676
		end, -- 667
		hide = function() -- 678
			root.visible = false -- 679
			retryButton:setEnabled(false) -- 682
			backButton:setEnabled(false) -- 683
		end -- 678
	} -- 678
end -- 569
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 723
	local root = createPanel( -- 729
		parent, -- 729
		viewW, -- 729
		viewH, -- 729
		SelectBackdropHex, -- 729
		{alpha = 0.9} -- 729
	) -- 729
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 731
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 732
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 734
	setLabelCenter( -- 735
		subtitleLabel, -- 735
		viewW / 2, -- 735
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 735
	) -- 735
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 737
	setLabelCenter( -- 738
		hintLabel, -- 738
		viewW / 2, -- 738
		clampNumber(viewH * 0.045, 36, 90) -- 738
	) -- 738
	local count = #opts.levels -- 740
	local cols = viewH > viewW and 2 or 1 -- 743
	local rows = math.max( -- 744
		1, -- 744
		math.ceil(count / cols) -- 744
	) -- 744
	local gap = 18 -- 745
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 746
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 747
	local availW = viewW * 0.84 -- 748
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 749
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 750
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 751
	local gridW = cols * btnW + gap * (cols - 1) -- 752
	local topY = viewH - headerH -- 753
	local buttons = {} -- 755
	do -- 755
		local i = 0 -- 756
		while i < count do -- 756
			local index = i -- 758
			local button = createButton( -- 759
				root, -- 759
				{ -- 759
					w = btnW, -- 760
					h = btnH, -- 761
					text = opts.levels[index + 1].name, -- 762
					fontSize = 38, -- 763
					bgHex = SelectLockedBgHex, -- 764
					fgHex = SelectLockedFgHex, -- 765
					borderHex = SelectBorderHex, -- 766
					onTap = function() return opts:onPick(index) end -- 767
				} -- 767
			) -- 767
			local col = index % cols -- 769
			local rowIndex = math.floor(index / cols) -- 770
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 771
			buttons[#buttons + 1] = button -- 775
			i = i + 1 -- 756
		end -- 756
	end -- 756
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 781
		root, -- 782
		{ -- 782
			w = clampNumber(viewW * 0.36, 180, 300), -- 783
			h = MinButtonHeight, -- 784
			text = "重看开场", -- 785
			fontSize = 30, -- 786
			bgHex = SelectLockedBgHex, -- 787
			fgHex = SelectSubtitleHex, -- 788
			borderHex = SelectBorderHex, -- 789
			onTap = function() -- 790
				if opts.onReplayIntro ~= nil then -- 790
					opts:onReplayIntro() -- 791
				end -- 791
			end -- 790
		} -- 790
	) or nil -- 790
	if replayButton ~= nil then -- 790
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 796
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 797
		replayButton.root.position = Vec2( -- 798
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 798
			by -- 798
		) -- 798
	end -- 798
	root.visible = false -- 801
	do -- 801
		local i = 0 -- 802
		while i < count do -- 802
			buttons[i + 1]:setEnabled(false) -- 802
			i = i + 1 -- 802
		end -- 802
	end -- 802
	if replayButton ~= nil then -- 802
		replayButton:setEnabled(false) -- 803
	end -- 803
	return { -- 805
		root = root, -- 806
		show = function(____, unlocked) -- 807
			local maxUnlocked = clampNumber( -- 808
				math.floor(unlocked), -- 808
				0, -- 808
				count - 1 -- 808
			) -- 808
			setLabelText( -- 809
				subtitleLabel, -- 809
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 809
			) -- 809
			do -- 809
				local i = 0 -- 810
				while i < count do -- 810
					local button = buttons[i + 1] -- 811
					local open = i <= maxUnlocked -- 812
					button:setEnabled(open) -- 813
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 814
					if open then -- 814
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 815
					else -- 815
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 816
					end -- 816
					i = i + 1 -- 810
				end -- 810
			end -- 810
			root.visible = true -- 818
			if replayButton ~= nil then -- 818
				replayButton:setEnabled(true) -- 819
			end -- 819
		end, -- 807
		hide = function() -- 821
			root.visible = false -- 822
			do -- 822
				local i = 0 -- 824
				while i < count do -- 824
					buttons[i + 1]:setEnabled(false) -- 824
					i = i + 1 -- 824
				end -- 824
			end -- 824
			if replayButton ~= nil then -- 824
				replayButton:setEnabled(false) -- 825
			end -- 825
		end -- 821
	} -- 821
end -- 723
return ____exports -- 723