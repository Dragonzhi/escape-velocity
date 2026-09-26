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
function ____exports.createAimInput(parent, viewW, viewH, maxSpeed) -- 215
	local speedTop = maxSpeed ~= nil and maxSpeed > AimMinSpeed and maxSpeed or AimMaxSpeed -- 222
	local root = Node() -- 223
	root.size = Size(viewW, viewH) -- 224
	root.anchor = Vec2(0, 0) -- 230
	root.position = Vec2(0, 0) -- 231
	local touchLayer = Node() -- 234
	touchLayer.size = Size(viewW, viewH) -- 235
	touchLayer.anchor = Vec2(0.5, 0.5) -- 236
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 237
	touchLayer.swallowTouches = true -- 238
	root:addChild(touchLayer) -- 239
	local space = {viewW = viewW, viewH = viewH} -- 241
	local enabled = false -- 243
	local dragging = false -- 244
	local aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 245
	local probeOffset = {x = 0, y = 0} -- 248
	local dragHandler = nil -- 250
	local releaseHandler = nil -- 251
	local pressOffset = {x = 0, y = 0} -- 262
	--- 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。
	local function handleDelta(delta) -- 265
		aim = ____exports.computeAim({x = 0, y = 0}, delta, AimMaxDragPx, speedTop) -- 266
		if dragHandler ~= nil then -- 266
			dragHandler(aim) -- 267
		end -- 267
	end -- 265
	touchLayer:onTapBegan(function(touch) -- 270
		if not enabled then -- 270
			return -- 271
		end -- 271
		dragging = true -- 272
		pressOffset = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 273
		handleDelta({x = 0, y = 0}) -- 275
	end) -- 270
	touchLayer:onTapMoved(function(touch) -- 278
		if not enabled or not dragging then -- 278
			return -- 279
		end -- 279
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 280
		handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 281
	end) -- 278
	touchLayer:onTapEnded(function(touch) -- 284
		if not enabled or not dragging then -- 284
			return -- 285
		end -- 285
		dragging = false -- 286
		local cur = ____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space) -- 287
		handleDelta({x = cur.x - pressOffset.x, y = cur.y - pressOffset.y}) -- 288
		if releaseHandler ~= nil then -- 288
			releaseHandler(aim) -- 289
		end -- 289
	end) -- 284
	touchLayer.touchEnabled = false -- 297
	parent:addChild(root) -- 299
	return { -- 301
		onDrag = function(____, callback) -- 302
			dragHandler = callback -- 303
		end, -- 302
		onRelease = function(____, callback) -- 305
			releaseHandler = callback -- 306
		end, -- 305
		setEnabled = function(____, value) -- 308
			enabled = value -- 309
			touchLayer.touchEnabled = value -- 312
			if not value then -- 312
				dragging = false -- 313
			end -- 313
		end, -- 308
		current = function() return aim end, -- 315
		setProbeOffset = function(____, offset) -- 316
			probeOffset = offset -- 317
		end, -- 316
		handleLocal = function(____, ____local) -- 321
			handleDelta(____exports.localToOffset(____local, space)) -- 322
		end, -- 321
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 325
		debugProbeOffset = function() return probeOffset end, -- 326
		root = root -- 327
	} -- 327
end -- 215
local ResultBackdropHex = 329484 -- 344
local ResultCardHex = 1252395 -- 345
local ResultCardBorderHex = 3362938 -- 346
local ResultLevelHex = 9417948 -- 347
local ResultBodyHex = 14149367 -- 348
local ResultHintHex = 8229803 -- 349
local ResultButtonBgHex = 1919610 -- 350
local ResultButtonAltBgHex = 1779509 -- 351
local ResultButtonFgHex = 15398143 -- 352
local ResultButtonBorderHex = 5211846 -- 353
local TitleSuccessHex = 8381344 -- 354
local TitleMissedHex = 16766073 -- 355
local TitleCrashedHex = 16743019 -- 356
local SelectBackdropHex = 329484 -- 358
local SelectTitleHex = 16777215 -- 359
local SelectSubtitleHex = 10470632 -- 360
local SelectHintHex = 7309478 -- 361
local SelectOpenBgHex = 1919610 -- 362
local SelectOpenFgHex = 15398143 -- 363
local SelectLockedBgHex = 1383204 -- 364
local SelectLockedFgHex = 6912140 -- 365
local SelectBorderHex = 4157096 -- 366
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 369
	if value < lo then -- 369
		return lo -- 370
	end -- 370
	if value > hi then -- 370
		return hi -- 371
	end -- 371
	return value -- 372
end -- 369
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 376
	if result == "success" then -- 376
		return "借力成功" -- 377
	end -- 377
	if result == "crashed" then -- 377
		return "信号中断" -- 378
	end -- 378
	return "错过目标" -- 379
end -- 376
--- 三态说明句（逐字）。
local function resultBody(result) -- 383
	if result == "success" then -- 383
		return "行星把探测器甩了出去，速度够了。" -- 384
	end -- 384
	if result == "crashed" then -- 384
		return "探测器撞上行星，任务到此为止。" -- 385
	end -- 385
	return "从行星身侧掠过，没能借到那一点速度。" -- 386
end -- 383
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 390
	if result == "success" then -- 390
		return TitleSuccessHex -- 391
	end -- 391
	if result == "crashed" then -- 391
		return TitleCrashedHex -- 392
	end -- 392
	return TitleMissedHex -- 393
end -- 390
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 402
	if result == "success" then -- 402
		return "下一关已解锁" -- 403
	end -- 403
	return "可重试本关，或返回关卡选择" -- 404
end -- 402
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 433
	local root = createPanel( -- 439
		parent, -- 439
		viewW, -- 439
		viewH, -- 439
		ResultBackdropHex, -- 439
		{alpha = 0.78} -- 439
	) -- 439
	local cardW = viewW * 0.88 -- 444
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 900) -- 445
	local btnH = clampNumber(viewH * 0.13, MinButtonHeight, 150) -- 446
	local padX = (cardW - btnW) / 2 -- 447
	local padY = 44 -- 448
	local fontLevel = 34 -- 450
	local fontTitle = 66 -- 451
	local fontBody = 34 -- 452
	local fontHint = 30 -- 453
	local btnFont = 40 -- 454
	local rowGap = 26 -- 455
	local hLevel = fontLevel + 10 -- 458
	local hTitle = fontTitle + 18 -- 459
	local hBody = fontBody * 2 + 12 -- 460
	local hHint = fontHint + 10 -- 461
	local cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 462
	if cardH > viewH - 24 then -- 462
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 465
		cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 466
	end -- 466
	local card = createPanel( -- 469
		root, -- 469
		cardW, -- 469
		cardH, -- 469
		ResultCardHex, -- 469
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 469
	) -- 469
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 474
	local cursor = cardH - padY -- 477
	cursor = cursor - hLevel -- 479
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 480
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 481
	cursor = cursor - (rowGap + hTitle) -- 483
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 484
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 485
	cursor = cursor - (rowGap + hBody) -- 487
	local bodyLabel = createLabel(card, "", fontBody, ResultBodyHex) -- 488
	setLabelCenter(bodyLabel, cardW / 2, cursor + hBody / 2) -- 489
	if bodyLabel ~= nil then -- 489
		bodyLabel.textWidth = cardW - 80 -- 490
	end -- 490
	cursor = cursor - (rowGap + hHint) -- 492
	local hintLabel = createLabel(card, "", fontHint, ResultHintHex) -- 493
	setLabelCenter(hintLabel, cardW / 2, cursor + hHint / 2) -- 494
	cursor = cursor - (rowGap + btnH) -- 497
	local retryButton = createButton(card, { -- 498
		w = btnW, -- 499
		h = btnH, -- 500
		text = "重试本关", -- 501
		fontSize = btnFont, -- 502
		bgHex = ResultButtonBgHex, -- 503
		fgHex = ResultButtonFgHex, -- 504
		borderHex = ResultButtonBorderHex, -- 505
		onTap = opts.onRetry -- 506
	}) -- 506
	retryButton.root.position = Vec2(padX, cursor) -- 508
	cursor = cursor - (22 + btnH) -- 510
	local backButton = createButton(card, { -- 511
		w = btnW, -- 512
		h = btnH, -- 513
		text = "返回关卡选择", -- 514
		fontSize = btnFont, -- 515
		bgHex = ResultButtonAltBgHex, -- 516
		fgHex = ResultButtonFgHex, -- 517
		borderHex = ResultButtonBorderHex, -- 518
		onTap = opts.onBackToSelect -- 519
	}) -- 519
	backButton.root.position = Vec2(padX, cursor) -- 521
	root.visible = false -- 523
	retryButton:setEnabled(false) -- 526
	backButton:setEnabled(false) -- 527
	return { -- 529
		root = root, -- 530
		show = function(____, result, levelName) -- 531
			retryButton:setEnabled(true) -- 533
			backButton:setEnabled(true) -- 534
			setLabelText(levelLabel, levelName) -- 535
			setLabelText( -- 536
				titleLabel, -- 536
				resultTitle(result) -- 536
			) -- 536
			setLabelColor( -- 537
				titleLabel, -- 537
				resultTitleColor(result) -- 537
			) -- 537
			setLabelText( -- 538
				bodyLabel, -- 538
				resultBody(result) -- 538
			) -- 538
			setLabelText( -- 539
				hintLabel, -- 539
				resultHint(result) -- 539
			) -- 539
			root.visible = true -- 540
		end, -- 531
		hide = function() -- 542
			root.visible = false -- 543
			retryButton:setEnabled(false) -- 546
			backButton:setEnabled(false) -- 547
		end -- 542
	} -- 542
end -- 433
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 587
	local root = createPanel( -- 593
		parent, -- 593
		viewW, -- 593
		viewH, -- 593
		SelectBackdropHex, -- 593
		{alpha = 0.9} -- 593
	) -- 593
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 595
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 596
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 598
	setLabelCenter( -- 599
		subtitleLabel, -- 599
		viewW / 2, -- 599
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 599
	) -- 599
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 601
	setLabelCenter( -- 602
		hintLabel, -- 602
		viewW / 2, -- 602
		clampNumber(viewH * 0.045, 36, 90) -- 602
	) -- 602
	local count = #opts.levels -- 604
	local cols = viewH > viewW and 2 or 1 -- 607
	local rows = math.max( -- 608
		1, -- 608
		math.ceil(count / cols) -- 608
	) -- 608
	local gap = 18 -- 609
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 610
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 611
	local availW = viewW * 0.84 -- 612
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 613
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 614
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 615
	local gridW = cols * btnW + gap * (cols - 1) -- 616
	local topY = viewH - headerH -- 617
	local buttons = {} -- 619
	do -- 619
		local i = 0 -- 620
		while i < count do -- 620
			local index = i -- 622
			local button = createButton( -- 623
				root, -- 623
				{ -- 623
					w = btnW, -- 624
					h = btnH, -- 625
					text = opts.levels[index + 1].name, -- 626
					fontSize = 38, -- 627
					bgHex = SelectLockedBgHex, -- 628
					fgHex = SelectLockedFgHex, -- 629
					borderHex = SelectBorderHex, -- 630
					onTap = function() return opts:onPick(index) end -- 631
				} -- 631
			) -- 631
			local col = index % cols -- 633
			local rowIndex = math.floor(index / cols) -- 634
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 635
			buttons[#buttons + 1] = button -- 639
			i = i + 1 -- 620
		end -- 620
	end -- 620
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 645
		root, -- 646
		{ -- 646
			w = clampNumber(viewW * 0.36, 180, 300), -- 647
			h = MinButtonHeight, -- 648
			text = "重看开场", -- 649
			fontSize = 30, -- 650
			bgHex = SelectLockedBgHex, -- 651
			fgHex = SelectSubtitleHex, -- 652
			borderHex = SelectBorderHex, -- 653
			onTap = function() -- 654
				if opts.onReplayIntro ~= nil then -- 654
					opts:onReplayIntro() -- 655
				end -- 655
			end -- 654
		} -- 654
	) or nil -- 654
	if replayButton ~= nil then -- 654
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 660
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 661
		replayButton.root.position = Vec2( -- 662
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 662
			by -- 662
		) -- 662
	end -- 662
	root.visible = false -- 665
	do -- 665
		local i = 0 -- 666
		while i < count do -- 666
			buttons[i + 1]:setEnabled(false) -- 666
			i = i + 1 -- 666
		end -- 666
	end -- 666
	if replayButton ~= nil then -- 666
		replayButton:setEnabled(false) -- 667
	end -- 667
	return { -- 669
		root = root, -- 670
		show = function(____, unlocked) -- 671
			local maxUnlocked = clampNumber( -- 672
				math.floor(unlocked), -- 672
				0, -- 672
				count - 1 -- 672
			) -- 672
			setLabelText( -- 673
				subtitleLabel, -- 673
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 673
			) -- 673
			do -- 673
				local i = 0 -- 674
				while i < count do -- 674
					local button = buttons[i + 1] -- 675
					local open = i <= maxUnlocked -- 676
					button:setEnabled(open) -- 677
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 678
					if open then -- 678
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 679
					else -- 679
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 680
					end -- 680
					i = i + 1 -- 674
				end -- 674
			end -- 674
			root.visible = true -- 682
			if replayButton ~= nil then -- 682
				replayButton:setEnabled(true) -- 683
			end -- 683
		end, -- 671
		hide = function() -- 685
			root.visible = false -- 686
			do -- 686
				local i = 0 -- 688
				while i < count do -- 688
					buttons[i + 1]:setEnabled(false) -- 688
					i = i + 1 -- 688
				end -- 688
			end -- 688
			if replayButton ~= nil then -- 688
				replayButton:setEnabled(false) -- 689
			end -- 689
		end -- 685
	} -- 685
end -- 587
return ____exports -- 587