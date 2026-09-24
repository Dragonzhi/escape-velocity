-- [ts]: Hud.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 28
local Node = ____Dora.Node -- 28
local Size = ____Dora.Size -- 28
local Vec2 = ____Dora.Vec2 -- 28
local ____Projection = require("game.Projection") -- 29
local screenToPlaneY = ____Projection.screenToPlaneY -- 29
local ____Config = require("game.Config") -- 31
local AimMaxDragPx = ____Config.AimMaxDragPx -- 31
local AimMaxSpeed = ____Config.AimMaxSpeed -- 31
local AimMinSpeed = ____Config.AimMinSpeed -- 31
local PlaneToWorldX = ____Config.PlaneToWorldX -- 31
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 31
local ____Ui = require("game.Ui") -- 33
local MinButtonHeight = ____Ui.MinButtonHeight -- 33
local MinButtonWidth = ____Ui.MinButtonWidth -- 33
local createButton = ____Ui.createButton -- 33
local createLabel = ____Ui.createLabel -- 33
local createPanel = ____Ui.createPanel -- 33
local setLabelCenter = ____Ui.setLabelCenter -- 33
local setLabelColor = ____Ui.setLabelColor -- 33
local setLabelText = ____Ui.setLabelText -- 33
--- 纯计算：由“探测器屏幕偏移”与“当前触摸屏幕偏移”解算发射向量。
-- 
-- 方向语义（手册 §5.7）：发射方向 = **探测器 → 触摸点**。
-- 屏幕上玩家把手指移到探测器**上方**，发射就朝屏幕上方。
-- 
-- @param probeOffset 探测器在投影偏移空间中的位置
-- @param touchOffset 触摸点在投影偏移空间中的位置
-- @param maxDragPx 拖动多少像素算满力
function ____exports.computeAim(probeOffset, touchOffset, maxDragPx) -- 61
	local dx = touchOffset.x - probeOffset.x -- 70
	local dy = touchOffset.y - probeOffset.y -- 71
	local len = math.sqrt(dx * dx + dy * dy) -- 73
	if len < 0.000001 then -- 73
		return {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 76
	end -- 76
	local ux = dx / len -- 79
	local uy = -dy / len -- 84
	local safeMax = maxDragPx > 1 and maxDragPx or 1 -- 86
	local power = len / safeMax -- 87
	if power < 0 then -- 87
		power = 0 -- 88
	end -- 88
	if power > 1 then -- 88
		power = 1 -- 89
	end -- 89
	local speed = AimMinSpeed + (AimMaxSpeed - AimMinSpeed) * power -- 91
	return {velocity = {x = ux * speed, y = uy * speed}, power = power, unit = {x = ux, y = uy}} -- 93
end -- 61
--- 把屏幕位置（**投影偏移空间**，与 `project()` 同空间）转成平面坐标。
-- 
-- 不是矄准必需（矄准只用方向），但调试与关卡设计时有用。
-- 与 `project()` 互逆（已有往返测试守着）。
function ____exports.screenToPlane(viewPoint, basis) -- 106
	local world = screenToPlaneY(viewPoint, basis, 0) -- 110
	if world == nil then -- 110
		return nil -- 111
	end -- 111
	return {x = world.x / PlaneToWorldX, y = world.z / PlaneToWorldZ} -- 113
end -- 106
--- 默认的力度→拖动像素映射（供 UI 层统一引用）。
function ____exports.defaultMaxDragPx() -- 117
	return AimMaxDragPx -- 118
end -- 117
--- 默认速度区间（供 UI 层展示）。
function ____exports.defaultSpeedRange() -- 122
	return {min = AimMinSpeed, max = AimMaxSpeed} -- 123
end -- 122
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
function ____exports.localToOffset(____local, space) -- 144
	return {x = ____local.x - space.viewW / 2, y = ____local.y - space.viewH / 2} -- 145
end -- 144
--- 反向换算（投影偏移空间 → 全屏节点局部坐标）。
function ____exports.offsetToLocal(offset, space) -- 149
	return {x = offset.x + space.viewW / 2, y = offset.y + space.viewH / 2} -- 150
end -- 149
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
function ____exports.createAimInput(parent, viewW, viewH) -- 206
	local root = Node() -- 211
	root.size = Size(viewW, viewH) -- 212
	root.anchor = Vec2(0.5, 0.5) -- 213
	root.position = Vec2(0, 0) -- 214
	local touchLayer = Node() -- 217
	touchLayer.size = Size(viewW, viewH) -- 218
	touchLayer.anchor = Vec2(0.5, 0.5) -- 219
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 220
	touchLayer.swallowTouches = true -- 221
	root:addChild(touchLayer) -- 222
	local space = {viewW = viewW, viewH = viewH} -- 224
	local enabled = false -- 226
	local dragging = false -- 227
	local aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 228
	local probeOffset = {x = 0, y = 0} -- 231
	local dragHandler = nil -- 233
	local releaseHandler = nil -- 234
	local function handleOffset(offset) -- 236
		aim = ____exports.computeAim(probeOffset, offset, AimMaxDragPx) -- 237
		if dragHandler ~= nil then -- 237
			dragHandler(aim) -- 238
		end -- 238
	end -- 236
	touchLayer:onTapBegan(function(touch) -- 241
		if not enabled then -- 241
			return -- 242
		end -- 242
		dragging = true -- 243
		handleOffset(____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space)) -- 244
	end) -- 241
	touchLayer:onTapMoved(function(touch) -- 247
		if not enabled or not dragging then -- 247
			return -- 248
		end -- 248
		handleOffset(____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space)) -- 249
	end) -- 247
	touchLayer:onTapEnded(function(touch) -- 252
		if not enabled or not dragging then -- 252
			return -- 253
		end -- 253
		dragging = false -- 254
		handleOffset(____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space)) -- 255
		if releaseHandler ~= nil then -- 255
			releaseHandler(aim) -- 256
		end -- 256
	end) -- 252
	touchLayer.touchEnabled = false -- 264
	parent:addChild(root) -- 266
	return { -- 268
		onDrag = function(____, callback) -- 269
			dragHandler = callback -- 270
		end, -- 269
		onRelease = function(____, callback) -- 272
			releaseHandler = callback -- 273
		end, -- 272
		setEnabled = function(____, value) -- 275
			enabled = value -- 276
			touchLayer.touchEnabled = value -- 279
			if not value then -- 279
				dragging = false -- 280
			end -- 280
		end, -- 275
		current = function() return aim end, -- 282
		setProbeOffset = function(____, offset) -- 283
			probeOffset = offset -- 284
		end, -- 283
		handleLocal = function(____, ____local) -- 286
			handleOffset(____exports.localToOffset(____local, space)) -- 287
		end, -- 286
		handleOffset = function(____, offset) return handleOffset(offset) end, -- 290
		debugProbeOffset = function() return probeOffset end, -- 291
		root = root -- 292
	} -- 292
end -- 206
local ResultBackdropHex = 329484 -- 309
local ResultCardHex = 1252395 -- 310
local ResultCardBorderHex = 3362938 -- 311
local ResultLevelHex = 9417948 -- 312
local ResultBodyHex = 14149367 -- 313
local ResultHintHex = 8229803 -- 314
local ResultButtonBgHex = 1919610 -- 315
local ResultButtonAltBgHex = 1779509 -- 316
local ResultButtonFgHex = 15398143 -- 317
local ResultButtonBorderHex = 5211846 -- 318
local TitleSuccessHex = 8381344 -- 319
local TitleMissedHex = 16766073 -- 320
local TitleCrashedHex = 16743019 -- 321
local SelectBackdropHex = 329484 -- 323
local SelectTitleHex = 16777215 -- 324
local SelectSubtitleHex = 10470632 -- 325
local SelectHintHex = 7309478 -- 326
local SelectOpenBgHex = 1919610 -- 327
local SelectOpenFgHex = 15398143 -- 328
local SelectLockedBgHex = 1383204 -- 329
local SelectLockedFgHex = 6912140 -- 330
local SelectBorderHex = 4157096 -- 331
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 334
	if value < lo then -- 334
		return lo -- 335
	end -- 335
	if value > hi then -- 335
		return hi -- 336
	end -- 336
	return value -- 337
end -- 334
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 341
	if result == "success" then -- 341
		return "借力成功" -- 342
	end -- 342
	if result == "crashed" then -- 342
		return "信号中断" -- 343
	end -- 343
	return "错过目标" -- 344
end -- 341
--- 三态说明句（逐字）。
local function resultBody(result) -- 348
	if result == "success" then -- 348
		return "行星把探测器甩了出去，速度够了。" -- 349
	end -- 349
	if result == "crashed" then -- 349
		return "探测器撞上行星，任务到此为止。" -- 350
	end -- 350
	return "从行星身侧掠过，没能借到那一点速度。" -- 351
end -- 348
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 355
	if result == "success" then -- 355
		return TitleSuccessHex -- 356
	end -- 356
	if result == "crashed" then -- 356
		return TitleCrashedHex -- 357
	end -- 357
	return TitleMissedHex -- 358
end -- 355
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 367
	if result == "success" then -- 367
		return "下一关已解锁" -- 368
	end -- 368
	return "可重试本关，或返回关卡选择" -- 369
end -- 367
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 398
	local root = createPanel( -- 404
		parent, -- 404
		viewW, -- 404
		viewH, -- 404
		ResultBackdropHex, -- 404
		{alpha = 0.78} -- 404
	) -- 404
	local cardW = viewW * 0.88 -- 407
	local btnW = math.max( -- 408
		MinButtonWidth, -- 408
		math.min(cardW - 80, 900) -- 408
	) -- 408
	local btnH = math.max(MinButtonHeight, 150) -- 409
	local padX = (cardW - btnW) / 2 -- 410
	local padY = 44 -- 411
	local fontLevel = 34 -- 413
	local fontTitle = 66 -- 414
	local fontBody = 34 -- 415
	local fontHint = 30 -- 416
	local btnFont = 40 -- 417
	local rowGap = 26 -- 418
	local hLevel = fontLevel + 10 -- 421
	local hTitle = fontTitle + 18 -- 422
	local hBody = fontBody * 2 + 12 -- 423
	local hHint = fontHint + 10 -- 424
	local cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 425
	local card = createPanel( -- 427
		root, -- 427
		cardW, -- 427
		cardH, -- 427
		ResultCardHex, -- 427
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 427
	) -- 427
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 432
	local cursor = cardH - padY -- 435
	cursor = cursor - hLevel -- 437
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 438
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 439
	cursor = cursor - (rowGap + hTitle) -- 441
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 442
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 443
	cursor = cursor - (rowGap + hBody) -- 445
	local bodyLabel = createLabel(card, "", fontBody, ResultBodyHex) -- 446
	setLabelCenter(bodyLabel, cardW / 2, cursor + hBody / 2) -- 447
	if bodyLabel ~= nil then -- 447
		bodyLabel.textWidth = cardW - 80 -- 448
	end -- 448
	cursor = cursor - (rowGap + hHint) -- 450
	local hintLabel = createLabel(card, "", fontHint, ResultHintHex) -- 451
	setLabelCenter(hintLabel, cardW / 2, cursor + hHint / 2) -- 452
	cursor = cursor - (rowGap + btnH) -- 455
	local retryButton = createButton(card, { -- 456
		w = btnW, -- 457
		h = btnH, -- 458
		text = "重试本关", -- 459
		fontSize = btnFont, -- 460
		bgHex = ResultButtonBgHex, -- 461
		fgHex = ResultButtonFgHex, -- 462
		borderHex = ResultButtonBorderHex, -- 463
		onTap = opts.onRetry -- 464
	}) -- 464
	retryButton.root.position = Vec2(padX, cursor) -- 466
	cursor = cursor - (22 + btnH) -- 468
	local backButton = createButton(card, { -- 469
		w = btnW, -- 470
		h = btnH, -- 471
		text = "返回关卡选择", -- 472
		fontSize = btnFont, -- 473
		bgHex = ResultButtonAltBgHex, -- 474
		fgHex = ResultButtonFgHex, -- 475
		borderHex = ResultButtonBorderHex, -- 476
		onTap = opts.onBackToSelect -- 477
	}) -- 477
	backButton.root.position = Vec2(padX, cursor) -- 479
	root.visible = false -- 481
	retryButton:setEnabled(false) -- 484
	backButton:setEnabled(false) -- 485
	return { -- 487
		root = root, -- 488
		show = function(____, result, levelName) -- 489
			retryButton:setEnabled(true) -- 491
			backButton:setEnabled(true) -- 492
			setLabelText(levelLabel, levelName) -- 493
			setLabelText( -- 494
				titleLabel, -- 494
				resultTitle(result) -- 494
			) -- 494
			setLabelColor( -- 495
				titleLabel, -- 495
				resultTitleColor(result) -- 495
			) -- 495
			setLabelText( -- 496
				bodyLabel, -- 496
				resultBody(result) -- 496
			) -- 496
			setLabelText( -- 497
				hintLabel, -- 497
				resultHint(result) -- 497
			) -- 497
			root.visible = true -- 498
		end, -- 489
		hide = function() -- 500
			root.visible = false -- 501
			retryButton:setEnabled(false) -- 504
			backButton:setEnabled(false) -- 505
		end -- 500
	} -- 500
end -- 398
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 543
	local root = createPanel( -- 549
		parent, -- 549
		viewW, -- 549
		viewH, -- 549
		SelectBackdropHex, -- 549
		{alpha = 0.9} -- 549
	) -- 549
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 551
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 552
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 554
	setLabelCenter(subtitleLabel, viewW / 2, viewH - 168) -- 555
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 557
	setLabelCenter(hintLabel, viewW / 2, 64) -- 558
	local count = #opts.levels -- 560
	local btnW = math.max( -- 561
		MinButtonWidth, -- 561
		math.min(viewW * 0.8, 820) -- 561
	) -- 561
	local gap = 18 -- 562
	local headerH = 220 -- 563
	local footerH = 120 -- 564
	local avail = viewH - headerH - footerH - gap * (count - 1) -- 565
	local btnH = clampNumber(count > 0 and avail / count or MinButtonHeight, MinButtonHeight, 190) -- 568
	local topY = viewH - headerH -- 569
	local buttons = {} -- 571
	do -- 571
		local i = 0 -- 572
		while i < count do -- 572
			local index = i -- 574
			local button = createButton( -- 575
				root, -- 575
				{ -- 575
					w = btnW, -- 576
					h = btnH, -- 577
					text = opts.levels[index + 1].name, -- 578
					fontSize = 38, -- 579
					bgHex = SelectLockedBgHex, -- 580
					fgHex = SelectLockedFgHex, -- 581
					borderHex = SelectBorderHex, -- 582
					onTap = function() return opts:onPick(index) end -- 583
				} -- 583
			) -- 583
			button.root.position = Vec2((viewW - btnW) / 2, topY - (index + 1) * btnH - index * gap) -- 585
			buttons[#buttons + 1] = button -- 586
			i = i + 1 -- 572
		end -- 572
	end -- 572
	root.visible = false -- 589
	do -- 589
		local i = 0 -- 590
		while i < count do -- 590
			buttons[i + 1]:setEnabled(false) -- 590
			i = i + 1 -- 590
		end -- 590
	end -- 590
	return { -- 592
		root = root, -- 593
		show = function(____, unlocked) -- 594
			local maxUnlocked = clampNumber( -- 595
				math.floor(unlocked), -- 595
				0, -- 595
				count - 1 -- 595
			) -- 595
			setLabelText( -- 596
				subtitleLabel, -- 596
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 596
			) -- 596
			do -- 596
				local i = 0 -- 597
				while i < count do -- 597
					local button = buttons[i + 1] -- 598
					local open = i <= maxUnlocked -- 599
					button:setEnabled(open) -- 600
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 601
					if open then -- 601
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 602
					else -- 602
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 603
					end -- 603
					i = i + 1 -- 597
				end -- 597
			end -- 597
			root.visible = true -- 605
		end, -- 594
		hide = function() -- 607
			root.visible = false -- 608
			do -- 608
				local i = 0 -- 610
				while i < count do -- 610
					buttons[i + 1]:setEnabled(false) -- 610
					i = i + 1 -- 610
				end -- 610
			end -- 610
		end -- 607
	} -- 607
end -- 543
return ____exports -- 543