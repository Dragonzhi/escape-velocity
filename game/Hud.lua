-- [ts]: Hud.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
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
function ____exports.computeAim(probeOffset, touchOffset, maxDragPx) -- 65
	local dx = touchOffset.x - probeOffset.x -- 74
	local dy = touchOffset.y - probeOffset.y -- 75
	local len = math.sqrt(dx * dx + dy * dy) -- 77
	if len < 0.000001 then -- 77
		return {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 80
	end -- 80
	local ux = dx / len -- 83
	local uy = -dy / len -- 88
	local safeMax = maxDragPx > 1 and maxDragPx or 1 -- 90
	local power = len / safeMax -- 91
	if power < 0 then -- 91
		power = 0 -- 92
	end -- 92
	if power > 1 then -- 92
		power = 1 -- 93
	end -- 93
	local speed = AimMinSpeed + (AimMaxSpeed - AimMinSpeed) * power -- 95
	return {velocity = {x = ux * speed, y = uy * speed}, power = power, unit = {x = ux, y = uy}} -- 97
end -- 65
--- 把屏幕位置（**投影偏移空间**，与 `project()` 同空间）转成平面坐标。
-- 
-- 不是矄准必需（矄准只用方向），但调试与关卡设计时有用。
-- 与 `project()` 互逆（已有往返测试守着）。
function ____exports.screenToPlane(viewPoint, basis) -- 110
	local world = screenToPlaneY(viewPoint, basis, 0) -- 114
	if world == nil then -- 114
		return nil -- 115
	end -- 115
	return {x = world.x / PlaneToWorldX, y = world.z / PlaneToWorldZ} -- 117
end -- 110
--- 默认的力度→拖动像素映射（供 UI 层统一引用）。
function ____exports.defaultMaxDragPx() -- 121
	return AimMaxDragPx -- 122
end -- 121
--- 默认速度区间（供 UI 层展示）。
function ____exports.defaultSpeedRange() -- 126
	return {min = AimMinSpeed, max = AimMaxSpeed} -- 127
end -- 126
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
function ____exports.localToOffset(____local, space) -- 148
	return {x = ____local.x - space.viewW / 2, y = ____local.y - space.viewH / 2} -- 149
end -- 148
--- 反向换算（投影偏移空间 → 全屏节点局部坐标）。
function ____exports.offsetToLocal(offset, space) -- 153
	return {x = offset.x + space.viewW / 2, y = offset.y + space.viewH / 2} -- 154
end -- 153
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
function ____exports.createAimInput(parent, viewW, viewH) -- 212
	local root = Node() -- 217
	root.size = Size(viewW, viewH) -- 218
	root.anchor = Vec2(0, 0) -- 224
	root.position = Vec2(0, 0) -- 225
	local touchLayer = Node() -- 228
	touchLayer.size = Size(viewW, viewH) -- 229
	touchLayer.anchor = Vec2(0.5, 0.5) -- 230
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 231
	touchLayer.swallowTouches = true -- 232
	root:addChild(touchLayer) -- 233
	local space = {viewW = viewW, viewH = viewH} -- 235
	local enabled = false -- 237
	local dragging = false -- 238
	local aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 239
	local probeOffset = {x = 0, y = 0} -- 242
	local dragHandler = nil -- 244
	local releaseHandler = nil -- 245
	local pressOffset = {x = 0, y = 0} -- 256
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 259
		aim = ____exports.computeAim({x = 0, y = 0}, delta, AimMaxDragPx) -- 260
		if dragHandler ~= nil then -- 260
			dragHandler(aim) -- 261
		end -- 261
	end -- 259
	touchLayer:onTapBegan(function(touch) -- 264
		if not enabled then -- 264
			return -- 265
		end -- 265
		dragging = true -- 266
		pressOffset = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 267
		handleDelta({x = 0, y = 0}) -- 269
	end) -- 264
	touchLayer:onTapMoved(function(touch) -- 272
		if not enabled or not dragging then -- 272
			return -- 273
		end -- 273
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 274
		handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 275
	end) -- 272
	touchLayer:onTapEnded(function(touch) -- 278
		if not enabled or not dragging then -- 278
			return -- 279
		end -- 279
		dragging = false -- 280
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 281
		handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 282
		if releaseHandler ~= nil then -- 282
			releaseHandler(aim) -- 283
		end -- 283
	end) -- 278
	touchLayer.touchEnabled = false -- 291
	parent:addChild(root) -- 293
	return { -- 295
		onDrag = function(____, callback) -- 296
			dragHandler = callback -- 297
		end, -- 296
		onRelease = function(____, callback) -- 299
			releaseHandler = callback -- 300
		end, -- 299
		setEnabled = function(____, value) -- 302
			enabled = value -- 303
			touchLayer.touchEnabled = value -- 306
			if not value then -- 306
				dragging = false -- 307
			end -- 307
		end, -- 302
		current = function() return aim end, -- 309
		setProbeOffset = function(____, offset) -- 310
			probeOffset = offset -- 311
		end, -- 310
		handleLocal = function(____, ____local) -- 315
			handleDelta(____exports.localToOffset(____local, space)) -- 316
		end, -- 315
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 319
		debugProbeOffset = function() return probeOffset end, -- 320
		root = root -- 321
	} -- 321
end -- 212
local ResultBackdropHex = 329484 -- 338
local ResultCardHex = 1252395 -- 339
local ResultCardBorderHex = 3362938 -- 340
local ResultLevelHex = 9417948 -- 341
local ResultBodyHex = 14149367 -- 342
local ResultHintHex = 8229803 -- 343
local ResultButtonBgHex = 1919610 -- 344
local ResultButtonAltBgHex = 1779509 -- 345
local ResultButtonFgHex = 15398143 -- 346
local ResultButtonBorderHex = 5211846 -- 347
local TitleSuccessHex = 8381344 -- 348
local TitleMissedHex = 16766073 -- 349
local TitleCrashedHex = 16743019 -- 350
local SelectBackdropHex = 329484 -- 352
local SelectTitleHex = 16777215 -- 353
local SelectSubtitleHex = 10470632 -- 354
local SelectHintHex = 7309478 -- 355
local SelectOpenBgHex = 1919610 -- 356
local SelectOpenFgHex = 15398143 -- 357
local SelectLockedBgHex = 1383204 -- 358
local SelectLockedFgHex = 6912140 -- 359
local SelectBorderHex = 4157096 -- 360
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 363
	if value < lo then -- 363
		return lo -- 364
	end -- 364
	if value > hi then -- 364
		return hi -- 365
	end -- 365
	return value -- 366
end -- 363
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 370
	if result == "success" then -- 370
		return "借力成功" -- 371
	end -- 371
	if result == "crashed" then -- 371
		return "信号中断" -- 372
	end -- 372
	return "错过目标" -- 373
end -- 370
--- 三态说明句（逐字）。
local function resultBody(result) -- 377
	if result == "success" then -- 377
		return "行星把探测器甩了出去，速度够了。" -- 378
	end -- 378
	if result == "crashed" then -- 378
		return "探测器撞上行星，任务到此为止。" -- 379
	end -- 379
	return "从行星身侧掠过，没能借到那一点速度。" -- 380
end -- 377
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 384
	if result == "success" then -- 384
		return TitleSuccessHex -- 385
	end -- 385
	if result == "crashed" then -- 385
		return TitleCrashedHex -- 386
	end -- 386
	return TitleMissedHex -- 387
end -- 384
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 396
	if result == "success" then -- 396
		return "下一关已解锁" -- 397
	end -- 397
	return "可重试本关，或返回关卡选择" -- 398
end -- 396
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 427
	local root = createPanel( -- 433
		parent, -- 433
		viewW, -- 433
		viewH, -- 433
		ResultBackdropHex, -- 433
		{alpha = 0.78} -- 433
	) -- 433
	local cardW = viewW * 0.88 -- 436
	local btnW = math.max( -- 437
		MinButtonWidth, -- 437
		math.min(cardW - 80, 900) -- 437
	) -- 437
	local btnH = math.max(MinButtonHeight, 150) -- 438
	local padX = (cardW - btnW) / 2 -- 439
	local padY = 44 -- 440
	local fontLevel = 34 -- 442
	local fontTitle = 66 -- 443
	local fontBody = 34 -- 444
	local fontHint = 30 -- 445
	local btnFont = 40 -- 446
	local rowGap = 26 -- 447
	local hLevel = fontLevel + 10 -- 450
	local hTitle = fontTitle + 18 -- 451
	local hBody = fontBody * 2 + 12 -- 452
	local hHint = fontHint + 10 -- 453
	local cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 454
	local card = createPanel( -- 456
		root, -- 456
		cardW, -- 456
		cardH, -- 456
		ResultCardHex, -- 456
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 456
	) -- 456
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 461
	local cursor = cardH - padY -- 464
	cursor = cursor - hLevel -- 466
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 467
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 468
	cursor = cursor - (rowGap + hTitle) -- 470
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 471
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 472
	cursor = cursor - (rowGap + hBody) -- 474
	local bodyLabel = createLabel(card, "", fontBody, ResultBodyHex) -- 475
	setLabelCenter(bodyLabel, cardW / 2, cursor + hBody / 2) -- 476
	if bodyLabel ~= nil then -- 476
		bodyLabel.textWidth = cardW - 80 -- 477
	end -- 477
	cursor = cursor - (rowGap + hHint) -- 479
	local hintLabel = createLabel(card, "", fontHint, ResultHintHex) -- 480
	setLabelCenter(hintLabel, cardW / 2, cursor + hHint / 2) -- 481
	cursor = cursor - (rowGap + btnH) -- 484
	local retryButton = createButton(card, { -- 485
		w = btnW, -- 486
		h = btnH, -- 487
		text = "重试本关", -- 488
		fontSize = btnFont, -- 489
		bgHex = ResultButtonBgHex, -- 490
		fgHex = ResultButtonFgHex, -- 491
		borderHex = ResultButtonBorderHex, -- 492
		onTap = opts.onRetry -- 493
	}) -- 493
	retryButton.root.position = Vec2(padX, cursor) -- 495
	cursor = cursor - (22 + btnH) -- 497
	local backButton = createButton(card, { -- 498
		w = btnW, -- 499
		h = btnH, -- 500
		text = "返回关卡选择", -- 501
		fontSize = btnFont, -- 502
		bgHex = ResultButtonAltBgHex, -- 503
		fgHex = ResultButtonFgHex, -- 504
		borderHex = ResultButtonBorderHex, -- 505
		onTap = opts.onBackToSelect -- 506
	}) -- 506
	backButton.root.position = Vec2(padX, cursor) -- 508
	root.visible = false -- 510
	retryButton:setEnabled(false) -- 513
	backButton:setEnabled(false) -- 514
	return { -- 516
		root = root, -- 517
		show = function(____, result, levelName) -- 518
			retryButton:setEnabled(true) -- 520
			backButton:setEnabled(true) -- 521
			setLabelText(levelLabel, levelName) -- 522
			setLabelText( -- 523
				titleLabel, -- 523
				resultTitle(result) -- 523
			) -- 523
			setLabelColor( -- 524
				titleLabel, -- 524
				resultTitleColor(result) -- 524
			) -- 524
			setLabelText( -- 525
				bodyLabel, -- 525
				resultBody(result) -- 525
			) -- 525
			setLabelText( -- 526
				hintLabel, -- 526
				resultHint(result) -- 526
			) -- 526
			root.visible = true -- 527
		end, -- 518
		hide = function() -- 529
			root.visible = false -- 530
			retryButton:setEnabled(false) -- 533
			backButton:setEnabled(false) -- 534
		end -- 529
	} -- 529
end -- 427
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 572
	local root = createPanel( -- 578
		parent, -- 578
		viewW, -- 578
		viewH, -- 578
		SelectBackdropHex, -- 578
		{alpha = 0.9} -- 578
	) -- 578
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 580
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 581
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 583
	setLabelCenter(subtitleLabel, viewW / 2, viewH - 168) -- 584
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 586
	setLabelCenter(hintLabel, viewW / 2, 64) -- 587
	local count = #opts.levels -- 589
	local btnW = math.max( -- 590
		MinButtonWidth, -- 590
		math.min(viewW * 0.8, 820) -- 590
	) -- 590
	local gap = 18 -- 591
	local headerH = 220 -- 592
	local footerH = 120 -- 593
	local avail = viewH - headerH - footerH - gap * (count - 1) -- 594
	local btnH = clampNumber(count > 0 and avail / count or MinButtonHeight, MinButtonHeight, 190) -- 597
	local topY = viewH - headerH -- 598
	local buttons = {} -- 600
	do -- 600
		local i = 0 -- 601
		while i < count do -- 601
			local index = i -- 603
			local button = createButton( -- 604
				root, -- 604
				{ -- 604
					w = btnW, -- 605
					h = btnH, -- 606
					text = opts.levels[index + 1].name, -- 607
					fontSize = 38, -- 608
					bgHex = SelectLockedBgHex, -- 609
					fgHex = SelectLockedFgHex, -- 610
					borderHex = SelectBorderHex, -- 611
					onTap = function() return opts:onPick(index) end -- 612
				} -- 612
			) -- 612
			button.root.position = Vec2((viewW - btnW) / 2, topY - (index + 1) * btnH - index * gap) -- 614
			buttons[#buttons + 1] = button -- 615
			i = i + 1 -- 601
		end -- 601
	end -- 601
	root.visible = false -- 618
	do -- 618
		local i = 0 -- 619
		while i < count do -- 619
			buttons[i + 1]:setEnabled(false) -- 619
			i = i + 1 -- 619
		end -- 619
	end -- 619
	return { -- 621
		root = root, -- 622
		show = function(____, unlocked) -- 623
			local maxUnlocked = clampNumber( -- 624
				math.floor(unlocked), -- 624
				0, -- 624
				count - 1 -- 624
			) -- 624
			setLabelText( -- 625
				subtitleLabel, -- 625
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 625
			) -- 625
			do -- 625
				local i = 0 -- 626
				while i < count do -- 626
					local button = buttons[i + 1] -- 627
					local open = i <= maxUnlocked -- 628
					button:setEnabled(open) -- 629
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 630
					if open then -- 630
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 631
					else -- 631
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 632
					end -- 632
					i = i + 1 -- 626
				end -- 626
			end -- 626
			root.visible = true -- 634
		end, -- 623
		hide = function() -- 636
			root.visible = false -- 637
			do -- 637
				local i = 0 -- 639
				while i < count do -- 639
					buttons[i + 1]:setEnabled(false) -- 639
					i = i + 1 -- 639
				end -- 639
			end -- 639
		end -- 636
	} -- 636
end -- 572
return ____exports -- 572