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
function ____exports.createAimInput(parent, viewW, viewH) -- 201
	local root = Node() -- 206
	root.size = Size(viewW, viewH) -- 207
	root.anchor = Vec2(0.5, 0.5) -- 208
	root.position = Vec2(0, 0) -- 209
	local touchLayer = Node() -- 212
	touchLayer.size = Size(viewW, viewH) -- 213
	touchLayer.anchor = Vec2(0.5, 0.5) -- 214
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 215
	touchLayer.swallowTouches = true -- 216
	root:addChild(touchLayer) -- 217
	local space = {viewW = viewW, viewH = viewH} -- 219
	local enabled = false -- 221
	local dragging = false -- 222
	local aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 223
	local probeOffset = {x = 0, y = 0} -- 226
	local dragHandler = nil -- 228
	local releaseHandler = nil -- 229
	local function handleOffset(offset) -- 231
		aim = ____exports.computeAim(probeOffset, offset, AimMaxDragPx) -- 232
		if dragHandler ~= nil then -- 232
			dragHandler(aim) -- 233
		end -- 233
	end -- 231
	touchLayer:onTapBegan(function(touch) -- 236
		if not enabled then -- 236
			return -- 237
		end -- 237
		dragging = true -- 238
		handleOffset(____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space)) -- 239
	end) -- 236
	touchLayer:onTapMoved(function(touch) -- 242
		if not enabled or not dragging then -- 242
			return -- 243
		end -- 243
		handleOffset(____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space)) -- 244
	end) -- 242
	touchLayer:onTapEnded(function(touch) -- 247
		if not enabled or not dragging then -- 247
			return -- 248
		end -- 248
		dragging = false -- 249
		handleOffset(____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space)) -- 250
		if releaseHandler ~= nil then -- 250
			releaseHandler(aim) -- 251
		end -- 251
	end) -- 247
	touchLayer.touchEnabled = false -- 259
	parent:addChild(root) -- 261
	return { -- 263
		onDrag = function(____, callback) -- 264
			dragHandler = callback -- 265
		end, -- 264
		onRelease = function(____, callback) -- 267
			releaseHandler = callback -- 268
		end, -- 267
		setEnabled = function(____, value) -- 270
			enabled = value -- 271
			touchLayer.touchEnabled = value -- 274
			if not value then -- 274
				dragging = false -- 275
			end -- 275
		end, -- 270
		current = function() return aim end, -- 277
		setProbeOffset = function(____, offset) -- 278
			probeOffset = offset -- 279
		end, -- 278
		handleLocal = function(____, ____local) -- 281
			handleOffset(____exports.localToOffset(____local, space)) -- 282
		end, -- 281
		handleOffset = function(____, offset) return handleOffset(offset) end, -- 285
		root = root -- 286
	} -- 286
end -- 201
local ResultBackdropHex = 329484 -- 303
local ResultCardHex = 1252395 -- 304
local ResultCardBorderHex = 3362938 -- 305
local ResultLevelHex = 9417948 -- 306
local ResultBodyHex = 14149367 -- 307
local ResultHintHex = 8229803 -- 308
local ResultButtonBgHex = 1919610 -- 309
local ResultButtonAltBgHex = 1779509 -- 310
local ResultButtonFgHex = 15398143 -- 311
local ResultButtonBorderHex = 5211846 -- 312
local TitleSuccessHex = 8381344 -- 313
local TitleMissedHex = 16766073 -- 314
local TitleCrashedHex = 16743019 -- 315
local SelectBackdropHex = 329484 -- 317
local SelectTitleHex = 16777215 -- 318
local SelectSubtitleHex = 10470632 -- 319
local SelectHintHex = 7309478 -- 320
local SelectOpenBgHex = 1919610 -- 321
local SelectOpenFgHex = 15398143 -- 322
local SelectLockedBgHex = 1383204 -- 323
local SelectLockedFgHex = 6912140 -- 324
local SelectBorderHex = 4157096 -- 325
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 328
	if value < lo then -- 328
		return lo -- 329
	end -- 329
	if value > hi then -- 329
		return hi -- 330
	end -- 330
	return value -- 331
end -- 328
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 335
	if result == "success" then -- 335
		return "借力成功" -- 336
	end -- 336
	if result == "crashed" then -- 336
		return "信号中断" -- 337
	end -- 337
	return "错过目标" -- 338
end -- 335
--- 三态说明句（逐字）。
local function resultBody(result) -- 342
	if result == "success" then -- 342
		return "行星把探测器甩了出去，速度够了。" -- 343
	end -- 343
	if result == "crashed" then -- 343
		return "探测器撞上行星，任务到此为止。" -- 344
	end -- 344
	return "从行星身侧掠过，没能借到那一点速度。" -- 345
end -- 342
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 349
	if result == "success" then -- 349
		return TitleSuccessHex -- 350
	end -- 350
	if result == "crashed" then -- 350
		return TitleCrashedHex -- 351
	end -- 351
	return TitleMissedHex -- 352
end -- 349
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 361
	if result == "success" then -- 361
		return "下一关已解锁" -- 362
	end -- 362
	return "可重试本关，或返回关卡选择" -- 363
end -- 361
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 392
	local root = createPanel( -- 398
		parent, -- 398
		viewW, -- 398
		viewH, -- 398
		ResultBackdropHex, -- 398
		{alpha = 0.78} -- 398
	) -- 398
	local cardW = viewW * 0.88 -- 401
	local btnW = math.max( -- 402
		MinButtonWidth, -- 402
		math.min(cardW - 80, 900) -- 402
	) -- 402
	local btnH = math.max(MinButtonHeight, 150) -- 403
	local padX = (cardW - btnW) / 2 -- 404
	local padY = 44 -- 405
	local fontLevel = 34 -- 407
	local fontTitle = 66 -- 408
	local fontBody = 34 -- 409
	local fontHint = 30 -- 410
	local btnFont = 40 -- 411
	local rowGap = 26 -- 412
	local hLevel = fontLevel + 10 -- 415
	local hTitle = fontTitle + 18 -- 416
	local hBody = fontBody * 2 + 12 -- 417
	local hHint = fontHint + 10 -- 418
	local cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 419
	local card = createPanel( -- 421
		root, -- 421
		cardW, -- 421
		cardH, -- 421
		ResultCardHex, -- 421
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 421
	) -- 421
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 426
	local cursor = cardH - padY -- 429
	cursor = cursor - hLevel -- 431
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 432
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 433
	cursor = cursor - (rowGap + hTitle) -- 435
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 436
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 437
	cursor = cursor - (rowGap + hBody) -- 439
	local bodyLabel = createLabel(card, "", fontBody, ResultBodyHex) -- 440
	setLabelCenter(bodyLabel, cardW / 2, cursor + hBody / 2) -- 441
	if bodyLabel ~= nil then -- 441
		bodyLabel.textWidth = cardW - 80 -- 442
	end -- 442
	cursor = cursor - (rowGap + hHint) -- 444
	local hintLabel = createLabel(card, "", fontHint, ResultHintHex) -- 445
	setLabelCenter(hintLabel, cardW / 2, cursor + hHint / 2) -- 446
	cursor = cursor - (rowGap + btnH) -- 449
	local retryButton = createButton(card, { -- 450
		w = btnW, -- 451
		h = btnH, -- 452
		text = "重试本关", -- 453
		fontSize = btnFont, -- 454
		bgHex = ResultButtonBgHex, -- 455
		fgHex = ResultButtonFgHex, -- 456
		borderHex = ResultButtonBorderHex, -- 457
		onTap = opts.onRetry -- 458
	}) -- 458
	retryButton.root.position = Vec2(padX, cursor) -- 460
	cursor = cursor - (22 + btnH) -- 462
	local backButton = createButton(card, { -- 463
		w = btnW, -- 464
		h = btnH, -- 465
		text = "返回关卡选择", -- 466
		fontSize = btnFont, -- 467
		bgHex = ResultButtonAltBgHex, -- 468
		fgHex = ResultButtonFgHex, -- 469
		borderHex = ResultButtonBorderHex, -- 470
		onTap = opts.onBackToSelect -- 471
	}) -- 471
	backButton.root.position = Vec2(padX, cursor) -- 473
	root.visible = false -- 475
	retryButton:setEnabled(false) -- 478
	backButton:setEnabled(false) -- 479
	return { -- 481
		root = root, -- 482
		show = function(____, result, levelName) -- 483
			retryButton:setEnabled(true) -- 485
			backButton:setEnabled(true) -- 486
			setLabelText(levelLabel, levelName) -- 487
			setLabelText( -- 488
				titleLabel, -- 488
				resultTitle(result) -- 488
			) -- 488
			setLabelColor( -- 489
				titleLabel, -- 489
				resultTitleColor(result) -- 489
			) -- 489
			setLabelText( -- 490
				bodyLabel, -- 490
				resultBody(result) -- 490
			) -- 490
			setLabelText( -- 491
				hintLabel, -- 491
				resultHint(result) -- 491
			) -- 491
			root.visible = true -- 492
		end, -- 483
		hide = function() -- 494
			root.visible = false -- 495
			retryButton:setEnabled(false) -- 498
			backButton:setEnabled(false) -- 499
		end -- 494
	} -- 494
end -- 392
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 537
	local root = createPanel( -- 543
		parent, -- 543
		viewW, -- 543
		viewH, -- 543
		SelectBackdropHex, -- 543
		{alpha = 0.9} -- 543
	) -- 543
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 545
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 546
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 548
	setLabelCenter(subtitleLabel, viewW / 2, viewH - 168) -- 549
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 551
	setLabelCenter(hintLabel, viewW / 2, 64) -- 552
	local count = #opts.levels -- 554
	local btnW = math.max( -- 555
		MinButtonWidth, -- 555
		math.min(viewW * 0.8, 820) -- 555
	) -- 555
	local gap = 18 -- 556
	local headerH = 220 -- 557
	local footerH = 120 -- 558
	local avail = viewH - headerH - footerH - gap * (count - 1) -- 559
	local btnH = clampNumber(count > 0 and avail / count or MinButtonHeight, MinButtonHeight, 190) -- 562
	local topY = viewH - headerH -- 563
	local buttons = {} -- 565
	do -- 565
		local i = 0 -- 566
		while i < count do -- 566
			local index = i -- 568
			local button = createButton( -- 569
				root, -- 569
				{ -- 569
					w = btnW, -- 570
					h = btnH, -- 571
					text = opts.levels[index + 1].name, -- 572
					fontSize = 38, -- 573
					bgHex = SelectLockedBgHex, -- 574
					fgHex = SelectLockedFgHex, -- 575
					borderHex = SelectBorderHex, -- 576
					onTap = function() return opts:onPick(index) end -- 577
				} -- 577
			) -- 577
			button.root.position = Vec2((viewW - btnW) / 2, topY - (index + 1) * btnH - index * gap) -- 579
			buttons[#buttons + 1] = button -- 580
			i = i + 1 -- 566
		end -- 566
	end -- 566
	root.visible = false -- 583
	do -- 583
		local i = 0 -- 584
		while i < count do -- 584
			buttons[i + 1]:setEnabled(false) -- 584
			i = i + 1 -- 584
		end -- 584
	end -- 584
	return { -- 586
		root = root, -- 587
		show = function(____, unlocked) -- 588
			local maxUnlocked = clampNumber( -- 589
				math.floor(unlocked), -- 589
				0, -- 589
				count - 1 -- 589
			) -- 589
			setLabelText( -- 590
				subtitleLabel, -- 590
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 590
			) -- 590
			do -- 590
				local i = 0 -- 591
				while i < count do -- 591
					local button = buttons[i + 1] -- 592
					local open = i <= maxUnlocked -- 593
					button:setEnabled(open) -- 594
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 595
					if open then -- 595
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 596
					else -- 596
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 597
					end -- 597
					i = i + 1 -- 591
				end -- 591
			end -- 591
			root.visible = true -- 599
		end, -- 588
		hide = function() -- 601
			root.visible = false -- 602
			do -- 602
				local i = 0 -- 604
				while i < count do -- 604
					buttons[i + 1]:setEnabled(false) -- 604
					i = i + 1 -- 604
				end -- 604
			end -- 604
		end -- 601
	} -- 601
end -- 537
return ____exports -- 537