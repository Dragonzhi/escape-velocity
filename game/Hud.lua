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
-- 层级用意：全屏底设 `touch: true`，把落在结算界面上的点击全部吞掉 ——
-- 否则底下的矄准触摸层仍会收到拖动，玩家“关掉结算”时会顺手改掉下一发的方向。
-- 
-- @param viewW 视图逻辑宽（`View.size.width`）
-- @param viewH 视图逻辑高
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 389
	local root = createPanel( -- 395
		parent, -- 395
		viewW, -- 395
		viewH, -- 395
		ResultBackdropHex, -- 395
		{alpha = 0.78, touch = true} -- 395
	) -- 395
	local cardW = viewW * 0.88 -- 398
	local btnW = math.max( -- 399
		MinButtonWidth, -- 399
		math.min(cardW - 80, 900) -- 399
	) -- 399
	local btnH = math.max(MinButtonHeight, 150) -- 400
	local padX = (cardW - btnW) / 2 -- 401
	local padY = 44 -- 402
	local fontLevel = 34 -- 404
	local fontTitle = 66 -- 405
	local fontBody = 34 -- 406
	local fontHint = 30 -- 407
	local btnFont = 40 -- 408
	local rowGap = 26 -- 409
	local hLevel = fontLevel + 10 -- 412
	local hTitle = fontTitle + 18 -- 413
	local hBody = fontBody * 2 + 12 -- 414
	local hHint = fontHint + 10 -- 415
	local cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 416
	local card = createPanel( -- 418
		root, -- 418
		cardW, -- 418
		cardH, -- 418
		ResultCardHex, -- 418
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 418
	) -- 418
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 423
	local cursor = cardH - padY -- 426
	cursor = cursor - hLevel -- 428
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 429
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 430
	cursor = cursor - (rowGap + hTitle) -- 432
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 433
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 434
	cursor = cursor - (rowGap + hBody) -- 436
	local bodyLabel = createLabel(card, "", fontBody, ResultBodyHex) -- 437
	setLabelCenter(bodyLabel, cardW / 2, cursor + hBody / 2) -- 438
	if bodyLabel ~= nil then -- 438
		bodyLabel.textWidth = cardW - 80 -- 439
	end -- 439
	cursor = cursor - (rowGap + hHint) -- 441
	local hintLabel = createLabel(card, "", fontHint, ResultHintHex) -- 442
	setLabelCenter(hintLabel, cardW / 2, cursor + hHint / 2) -- 443
	cursor = cursor - (rowGap + btnH) -- 446
	local retryButton = createButton(card, { -- 447
		w = btnW, -- 448
		h = btnH, -- 449
		text = "重试本关", -- 450
		fontSize = btnFont, -- 451
		bgHex = ResultButtonBgHex, -- 452
		fgHex = ResultButtonFgHex, -- 453
		borderHex = ResultButtonBorderHex, -- 454
		onTap = opts.onRetry -- 455
	}) -- 455
	retryButton.root.position = Vec2(padX, cursor) -- 457
	cursor = cursor - (22 + btnH) -- 459
	local backButton = createButton(card, { -- 460
		w = btnW, -- 461
		h = btnH, -- 462
		text = "返回关卡选择", -- 463
		fontSize = btnFont, -- 464
		bgHex = ResultButtonAltBgHex, -- 465
		fgHex = ResultButtonFgHex, -- 466
		borderHex = ResultButtonBorderHex, -- 467
		onTap = opts.onBackToSelect -- 468
	}) -- 468
	backButton.root.position = Vec2(padX, cursor) -- 470
	root.visible = false -- 472
	return { -- 474
		root = root, -- 475
		show = function(____, result, levelName) -- 476
			setLabelText(levelLabel, levelName) -- 477
			setLabelText( -- 478
				titleLabel, -- 478
				resultTitle(result) -- 478
			) -- 478
			setLabelColor( -- 479
				titleLabel, -- 479
				resultTitleColor(result) -- 479
			) -- 479
			setLabelText( -- 480
				bodyLabel, -- 480
				resultBody(result) -- 480
			) -- 480
			setLabelText( -- 481
				hintLabel, -- 481
				resultHint(result) -- 481
			) -- 481
			root.visible = true -- 482
		end, -- 476
		hide = function() -- 484
			root.visible = false -- 485
		end -- 484
	} -- 484
end -- 389
--- 建关卡选择：标题 + 副标题 + 六关竖排按钮 + 底部提示。
-- 
-- 未解锁的按钮**整块不可点**（`setEnabled(false)` 会关掉 `touchEnabled`）——
-- 只在回调里判断“锁了就 return”是不够的：那样按钮仍会吞掉触摸，
-- 表现为“点了没反应”，玩家分不清是坏了还是锁着。
-- 
-- @param viewW 视图逻辑宽
-- @param viewH 视图逻辑高
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 518
	local root = createPanel( -- 524
		parent, -- 524
		viewW, -- 524
		viewH, -- 524
		SelectBackdropHex, -- 524
		{alpha = 0.9, touch = true} -- 524
	) -- 524
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 526
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 527
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 529
	setLabelCenter(subtitleLabel, viewW / 2, viewH - 168) -- 530
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 532
	setLabelCenter(hintLabel, viewW / 2, 64) -- 533
	local count = #opts.levels -- 535
	local btnW = math.max( -- 536
		MinButtonWidth, -- 536
		math.min(viewW * 0.8, 820) -- 536
	) -- 536
	local gap = 18 -- 537
	local headerH = 220 -- 538
	local footerH = 120 -- 539
	local avail = viewH - headerH - footerH - gap * (count - 1) -- 540
	local btnH = clampNumber(count > 0 and avail / count or MinButtonHeight, MinButtonHeight, 190) -- 543
	local topY = viewH - headerH -- 544
	local buttons = {} -- 546
	do -- 546
		local i = 0 -- 547
		while i < count do -- 547
			local index = i -- 549
			local button = createButton( -- 550
				root, -- 550
				{ -- 550
					w = btnW, -- 551
					h = btnH, -- 552
					text = opts.levels[index + 1].name, -- 553
					fontSize = 38, -- 554
					bgHex = SelectLockedBgHex, -- 555
					fgHex = SelectLockedFgHex, -- 556
					borderHex = SelectBorderHex, -- 557
					onTap = function() return opts:onPick(index) end -- 558
				} -- 558
			) -- 558
			button.root.position = Vec2((viewW - btnW) / 2, topY - (index + 1) * btnH - index * gap) -- 560
			buttons[#buttons + 1] = button -- 561
			i = i + 1 -- 547
		end -- 547
	end -- 547
	root.visible = false -- 564
	return { -- 566
		root = root, -- 567
		show = function(____, unlocked) -- 568
			local maxUnlocked = clampNumber( -- 569
				math.floor(unlocked), -- 569
				0, -- 569
				count - 1 -- 569
			) -- 569
			setLabelText( -- 570
				subtitleLabel, -- 570
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 570
			) -- 570
			do -- 570
				local i = 0 -- 571
				while i < count do -- 571
					local button = buttons[i + 1] -- 572
					local open = i <= maxUnlocked -- 573
					button:setEnabled(open) -- 574
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 575
					if open then -- 575
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 576
					else -- 576
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 577
					end -- 577
					i = i + 1 -- 571
				end -- 571
			end -- 571
			root.visible = true -- 579
		end, -- 568
		hide = function() -- 581
			root.visible = false -- 582
		end -- 581
	} -- 581
end -- 518
return ____exports -- 518