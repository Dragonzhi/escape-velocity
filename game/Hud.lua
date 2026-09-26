-- [ts]: Hud.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ResultButtonBgHex, ResultButtonAltBgHex, ResultButtonFgHex, ResultButtonBorderHex -- 1
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
function ____exports.createAimInput(parent, viewW, viewH, maxSpeed) -- 222
	local brakeOn, paintBrake -- 222
	local speedTop = maxSpeed ~= nil and maxSpeed > AimMinSpeed and maxSpeed or AimMaxSpeed -- 229
	local root = Node() -- 230
	root.size = Size(viewW, viewH) -- 231
	root.anchor = Vec2(0, 0) -- 237
	root.position = Vec2(0, 0) -- 238
	local touchLayer = Node() -- 241
	touchLayer.size = Size(viewW, viewH) -- 242
	touchLayer.anchor = Vec2(0.5, 0.5) -- 243
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 244
	touchLayer.swallowTouches = true -- 245
	root:addChild(touchLayer) -- 246
	local space = {viewW = viewW, viewH = viewH} -- 248
	local enabled = false -- 250
	local dragging = false -- 251
	local aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 252
	local probeOffset = {x = 0, y = 0} -- 255
	local dragHandler = nil -- 257
	local releaseHandler = nil -- 258
	local pressOffset = {x = 0, y = 0} -- 269
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 272
		aim = ____exports.computeAim({x = 0, y = 0}, delta, AimMaxDragPx, speedTop) -- 273
		if dragHandler ~= nil then -- 273
			dragHandler(aim) -- 274
		end -- 274
	end -- 272
	touchLayer:onTapBegan(function(touch) -- 277
		if not enabled then -- 277
			return -- 278
		end -- 278
		dragging = true -- 279
		pressOffset = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 280
		handleDelta({x = 0, y = 0}) -- 282
	end) -- 277
	touchLayer:onTapMoved(function(touch) -- 285
		if not enabled or not dragging then -- 285
			return -- 286
		end -- 286
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 287
		handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 288
	end) -- 285
	touchLayer:onTapEnded(function(touch) -- 291
		if not enabled or not dragging then -- 291
			return -- 292
		end -- 292
		dragging = false -- 293
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 294
		handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 295
		if releaseHandler ~= nil then -- 295
			releaseHandler(aim) -- 296
		end -- 296
	end) -- 291
	touchLayer.touchEnabled = false -- 304
	local brakeHandler = nil -- 309
	local BrakeButtonW = 116 -- 310
	local BrakeButtonH = 64 -- 311
	local brakeGap = 8 -- 312
	local brakeButtons = {} -- 316
	local function makeBrakeButton(text, on, x) -- 317
		local btn = createButton( -- 318
			root, -- 318
			{ -- 318
				w = BrakeButtonW, -- 319
				h = BrakeButtonH, -- 320
				text = text, -- 321
				fontSize = 30, -- 322
				bgHex = ResultButtonAltBgHex, -- 323
				fgHex = ResultButtonFgHex, -- 324
				borderHex = ResultButtonBorderHex, -- 325
				onTap = function() -- 326
					brakeOn = on -- 329
					paintBrake() -- 330
					if brakeHandler ~= nil then -- 330
						brakeHandler(on) -- 331
					end -- 331
				end -- 326
			} -- 326
		) -- 326
		btn.root.position = Vec2(x, viewH - BrakeButtonH - 20) -- 334
		brakeButtons[#brakeButtons + 1] = btn -- 335
	end -- 317
	brakeOn = false -- 337
	paintBrake = function() -- 338
		if #brakeButtons < 2 then -- 338
			return -- 339
		end -- 339
		brakeButtons[1]:setColors(brakeOn and ResultButtonAltBgHex or ResultButtonBgHex, ResultButtonFgHex) -- 340
		brakeButtons[2]:setColors(brakeOn and ResultButtonBgHex or ResultButtonAltBgHex, ResultButtonFgHex) -- 341
	end -- 338
	local brakeRightX = viewW - BrakeButtonW - 20 -- 343
	makeBrakeButton("惯性", false, brakeRightX - BrakeButtonW - brakeGap) -- 344
	makeBrakeButton("刹车", true, brakeRightX) -- 345
	paintBrake() -- 346
	parent:addChild(root) -- 348
	return { -- 350
		onDrag = function(____, callback) -- 351
			dragHandler = callback -- 352
		end, -- 351
		onRelease = function(____, callback) -- 354
			releaseHandler = callback -- 355
		end, -- 354
		setEnabled = function(____, value) -- 357
			enabled = value -- 358
			touchLayer.touchEnabled = value -- 361
			if not value then -- 361
				dragging = false -- 362
			end -- 362
		end, -- 357
		onBrake = function(____, callback) -- 364
			brakeHandler = callback -- 365
		end, -- 364
		setBrake = function(____, on) -- 367
			brakeOn = on -- 368
			paintBrake() -- 369
		end, -- 367
		current = function() return aim end, -- 371
		setProbeOffset = function(____, offset) -- 372
			probeOffset = offset -- 373
		end, -- 372
		handleLocal = function(____, ____local) -- 377
			handleDelta(____exports.localToOffset(____local, space)) -- 378
		end, -- 377
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 381
		debugProbeOffset = function() return probeOffset end, -- 382
		root = root -- 383
	} -- 383
end -- 222
local ResultBackdropHex = 329484 -- 400
local ResultCardHex = 1252395 -- 401
local ResultCardBorderHex = 3362938 -- 402
local ResultLevelHex = 9417948 -- 403
local ResultBodyHex = 14149367 -- 404
local ResultHintHex = 8229803 -- 405
ResultButtonBgHex = 1919610 -- 406
ResultButtonAltBgHex = 1779509 -- 407
ResultButtonFgHex = 15398143 -- 408
ResultButtonBorderHex = 5211846 -- 409
local TitleSuccessHex = 8381344 -- 410
local TitleMissedHex = 16766073 -- 411
local TitleCrashedHex = 16743019 -- 412
local SelectBackdropHex = 329484 -- 414
local SelectTitleHex = 16777215 -- 415
local SelectSubtitleHex = 10470632 -- 416
local SelectHintHex = 7309478 -- 417
local SelectOpenBgHex = 1919610 -- 418
local SelectOpenFgHex = 15398143 -- 419
local SelectLockedBgHex = 1383204 -- 420
local SelectLockedFgHex = 6912140 -- 421
local SelectBorderHex = 4157096 -- 422
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 425
	if value < lo then -- 425
		return lo -- 426
	end -- 426
	if value > hi then -- 426
		return hi -- 427
	end -- 427
	return value -- 428
end -- 425
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 432
	if result == "success" then -- 432
		return "借力成功" -- 433
	end -- 433
	if result == "crashed" then -- 433
		return "信号中断" -- 434
	end -- 434
	return "错过目标" -- 435
end -- 432
--- 三态说明句（逐字）。
local function resultBody(result) -- 439
	if result == "success" then -- 439
		return "行星把探测器甩了出去，速度够了。" -- 440
	end -- 440
	if result == "crashed" then -- 440
		return "探测器撞上行星，任务到此为止。" -- 441
	end -- 441
	return "从行星身侧掠过，没能借到那一点速度。" -- 442
end -- 439
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 446
	if result == "success" then -- 446
		return TitleSuccessHex -- 447
	end -- 447
	if result == "crashed" then -- 447
		return TitleCrashedHex -- 448
	end -- 448
	return TitleMissedHex -- 449
end -- 446
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 458
	if result == "success" then -- 458
		return "下一关已解锁" -- 459
	end -- 459
	return "可重试本关，或返回关卡选择" -- 460
end -- 458
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 489
	local root = createPanel( -- 495
		parent, -- 495
		viewW, -- 495
		viewH, -- 495
		ResultBackdropHex, -- 495
		{alpha = 0.78} -- 495
	) -- 495
	local cardW = viewW * 0.88 -- 500
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 900) -- 501
	local btnH = clampNumber(viewH * 0.13, MinButtonHeight, 150) -- 502
	local padX = (cardW - btnW) / 2 -- 503
	local padY = 44 -- 504
	local fontLevel = 34 -- 506
	local fontTitle = 66 -- 507
	local fontBody = 34 -- 508
	local fontHint = 30 -- 509
	local btnFont = 40 -- 510
	local rowGap = 26 -- 511
	local hLevel = fontLevel + 10 -- 514
	local hTitle = fontTitle + 18 -- 515
	local hBody = fontBody * 2 + 12 -- 516
	local hHint = fontHint + 10 -- 517
	local cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 518
	if cardH > viewH - 24 then -- 518
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 521
		cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 522
	end -- 522
	local card = createPanel( -- 525
		root, -- 525
		cardW, -- 525
		cardH, -- 525
		ResultCardHex, -- 525
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 525
	) -- 525
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 530
	local cursor = cardH - padY -- 533
	cursor = cursor - hLevel -- 535
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 536
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 537
	cursor = cursor - (rowGap + hTitle) -- 539
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 540
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 541
	cursor = cursor - (rowGap + hBody) -- 543
	local bodyLabel = createLabel(card, "", fontBody, ResultBodyHex) -- 544
	setLabelCenter(bodyLabel, cardW / 2, cursor + hBody / 2) -- 545
	if bodyLabel ~= nil then -- 545
		bodyLabel.textWidth = cardW - 80 -- 546
	end -- 546
	cursor = cursor - (rowGap + hHint) -- 548
	local hintLabel = createLabel(card, "", fontHint, ResultHintHex) -- 549
	setLabelCenter(hintLabel, cardW / 2, cursor + hHint / 2) -- 550
	cursor = cursor - (rowGap + btnH) -- 553
	local retryButton = createButton(card, { -- 554
		w = btnW, -- 555
		h = btnH, -- 556
		text = "重试本关", -- 557
		fontSize = btnFont, -- 558
		bgHex = ResultButtonBgHex, -- 559
		fgHex = ResultButtonFgHex, -- 560
		borderHex = ResultButtonBorderHex, -- 561
		onTap = opts.onRetry -- 562
	}) -- 562
	retryButton.root.position = Vec2(padX, cursor) -- 564
	cursor = cursor - (22 + btnH) -- 566
	local backButton = createButton(card, { -- 567
		w = btnW, -- 568
		h = btnH, -- 569
		text = "返回关卡选择", -- 570
		fontSize = btnFont, -- 571
		bgHex = ResultButtonAltBgHex, -- 572
		fgHex = ResultButtonFgHex, -- 573
		borderHex = ResultButtonBorderHex, -- 574
		onTap = opts.onBackToSelect -- 575
	}) -- 575
	backButton.root.position = Vec2(padX, cursor) -- 577
	root.visible = false -- 579
	retryButton:setEnabled(false) -- 582
	backButton:setEnabled(false) -- 583
	return { -- 585
		root = root, -- 586
		show = function(____, result, levelName) -- 587
			retryButton:setEnabled(true) -- 589
			backButton:setEnabled(true) -- 590
			setLabelText(levelLabel, levelName) -- 591
			setLabelText( -- 592
				titleLabel, -- 592
				resultTitle(result) -- 592
			) -- 592
			setLabelColor( -- 593
				titleLabel, -- 593
				resultTitleColor(result) -- 593
			) -- 593
			setLabelText( -- 594
				bodyLabel, -- 594
				resultBody(result) -- 594
			) -- 594
			setLabelText( -- 595
				hintLabel, -- 595
				resultHint(result) -- 595
			) -- 595
			root.visible = true -- 596
		end, -- 587
		hide = function() -- 598
			root.visible = false -- 599
			retryButton:setEnabled(false) -- 602
			backButton:setEnabled(false) -- 603
		end -- 598
	} -- 598
end -- 489
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 643
	local root = createPanel( -- 649
		parent, -- 649
		viewW, -- 649
		viewH, -- 649
		SelectBackdropHex, -- 649
		{alpha = 0.9} -- 649
	) -- 649
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 651
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 652
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 654
	setLabelCenter( -- 655
		subtitleLabel, -- 655
		viewW / 2, -- 655
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 655
	) -- 655
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 657
	setLabelCenter( -- 658
		hintLabel, -- 658
		viewW / 2, -- 658
		clampNumber(viewH * 0.045, 36, 90) -- 658
	) -- 658
	local count = #opts.levels -- 660
	local cols = viewH > viewW and 2 or 1 -- 663
	local rows = math.max( -- 664
		1, -- 664
		math.ceil(count / cols) -- 664
	) -- 664
	local gap = 18 -- 665
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 666
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 667
	local availW = viewW * 0.84 -- 668
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 669
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 670
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 671
	local gridW = cols * btnW + gap * (cols - 1) -- 672
	local topY = viewH - headerH -- 673
	local buttons = {} -- 675
	do -- 675
		local i = 0 -- 676
		while i < count do -- 676
			local index = i -- 678
			local button = createButton( -- 679
				root, -- 679
				{ -- 679
					w = btnW, -- 680
					h = btnH, -- 681
					text = opts.levels[index + 1].name, -- 682
					fontSize = 38, -- 683
					bgHex = SelectLockedBgHex, -- 684
					fgHex = SelectLockedFgHex, -- 685
					borderHex = SelectBorderHex, -- 686
					onTap = function() return opts:onPick(index) end -- 687
				} -- 687
			) -- 687
			local col = index % cols -- 689
			local rowIndex = math.floor(index / cols) -- 690
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 691
			buttons[#buttons + 1] = button -- 695
			i = i + 1 -- 676
		end -- 676
	end -- 676
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 701
		root, -- 702
		{ -- 702
			w = clampNumber(viewW * 0.36, 180, 300), -- 703
			h = MinButtonHeight, -- 704
			text = "重看开场", -- 705
			fontSize = 30, -- 706
			bgHex = SelectLockedBgHex, -- 707
			fgHex = SelectSubtitleHex, -- 708
			borderHex = SelectBorderHex, -- 709
			onTap = function() -- 710
				if opts.onReplayIntro ~= nil then -- 710
					opts:onReplayIntro() -- 711
				end -- 711
			end -- 710
		} -- 710
	) or nil -- 710
	if replayButton ~= nil then -- 710
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 716
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 717
		replayButton.root.position = Vec2( -- 718
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 718
			by -- 718
		) -- 718
	end -- 718
	root.visible = false -- 721
	do -- 721
		local i = 0 -- 722
		while i < count do -- 722
			buttons[i + 1]:setEnabled(false) -- 722
			i = i + 1 -- 722
		end -- 722
	end -- 722
	if replayButton ~= nil then -- 722
		replayButton:setEnabled(false) -- 723
	end -- 723
	return { -- 725
		root = root, -- 726
		show = function(____, unlocked) -- 727
			local maxUnlocked = clampNumber( -- 728
				math.floor(unlocked), -- 728
				0, -- 728
				count - 1 -- 728
			) -- 728
			setLabelText( -- 729
				subtitleLabel, -- 729
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 729
			) -- 729
			do -- 729
				local i = 0 -- 730
				while i < count do -- 730
					local button = buttons[i + 1] -- 731
					local open = i <= maxUnlocked -- 732
					button:setEnabled(open) -- 733
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 734
					if open then -- 734
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 735
					else -- 735
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 736
					end -- 736
					i = i + 1 -- 730
				end -- 730
			end -- 730
			root.visible = true -- 738
			if replayButton ~= nil then -- 738
				replayButton:setEnabled(true) -- 739
			end -- 739
		end, -- 727
		hide = function() -- 741
			root.visible = false -- 742
			do -- 742
				local i = 0 -- 744
				while i < count do -- 744
					buttons[i + 1]:setEnabled(false) -- 744
					i = i + 1 -- 744
				end -- 744
			end -- 744
			if replayButton ~= nil then -- 744
				replayButton:setEnabled(false) -- 745
			end -- 745
		end -- 741
	} -- 741
end -- 643
return ____exports -- 643