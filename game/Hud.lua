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
	local brakeOn, paintBrake, datePlate, dateLabel -- 261
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
	createPanel( -- 421
		root, -- 421
		220, -- 421
		50, -- 421
		658964, -- 421
		{alpha = 0.45} -- 421
	) -- 421
	local dvLabel = createLabel(root, "Δv — / —", 30, ResultHintHex) -- 422
	if dvLabel ~= nil then -- 422
		dvLabel.position = Vec2(24, viewH - 44) -- 424
		dvLabel.anchor = Vec2(0, 0) -- 425
	end -- 425
	local warpHandler = nil -- 435
	local dateSpan = 0 -- 436
	--- 这一关有时间轴**且**当前相态允许改日期（Flying/Result 时必须是 false）。
	local warpOn = true -- 443
	local warpVisible = true -- 444
	--- 相态是否允许改日期（由主循环每帧 setTimeEnabled 同步）。
	local warpAllowed = true -- 446
	--- 上次写进日期的文字（避免每帧重设 Label 文本）。
	local lastDateText = "" -- 448
	--- >0 = 正在按住这个方向（-1 回退 / +1 加速）；0 = 没按住。
	local warpHoldDir = 0 -- 450
	--- 距离下一次连按还有多久（秒）。
	local warpRepeatIn = 0 -- 452
	local WarpButtonW = 116 -- 453
	local WarpButtonH = 64 -- 454
	local warpButtons = {} -- 455
	local function applyWarpState() -- 456
		local vis = dateSpan > 0 -- 457
		local on = vis and warpAllowed -- 458
		if vis == warpVisible and on == warpOn then -- 458
			return -- 459
		end -- 459
		warpVisible = vis -- 460
		warpOn = on -- 461
		if not on then -- 461
			warpHoldDir = 0 -- 462
		end -- 462
		for ____, b in ipairs(warpButtons) do -- 463
			b.root.visible = vis -- 464
			b:setEnabled(on) -- 465
		end -- 465
		if dateLabel ~= nil then -- 465
			dateLabel.visible = vis -- 467
		end -- 467
		datePlate.visible = vis -- 468
	end -- 456
	local function makeWarpButton(text, dir, x) -- 470
		local btn = createButton( -- 471
			root, -- 471
			{ -- 471
				w = WarpButtonW, -- 472
				h = WarpButtonH, -- 473
				text = text, -- 474
				fontSize = 30, -- 475
				bgHex = ResultButtonAltBgHex, -- 476
				fgHex = ResultButtonFgHex, -- 477
				borderHex = ResultButtonBorderHex, -- 478
				onTap = function() -- 481
				end, -- 481
				onPressBegan = function() -- 482
					print((("[escape-velocity] warp press dir=" .. __TS__NumberToFixed(dir, 0)) .. " on=") .. (warpOn and "1" or "0")) -- 484
					if not warpOn then -- 484
						return -- 485
					end -- 485
					if warpHoldDir == dir then -- 485
						return -- 487
					end -- 487
					warpHoldDir = dir -- 488
					warpRepeatIn = WarpHoldDelaySec -- 489
					if warpHandler ~= nil then -- 489
						warpHandler(dir) -- 490
					end -- 490
				end, -- 482
				onPressEnded = function() -- 492
					print((("[escape-velocity] warp release dir=" .. __TS__NumberToFixed(dir, 0)) .. " hold=") .. __TS__NumberToFixed(warpHoldDir, 0)) -- 493
					if warpHoldDir == dir then -- 493
						warpHoldDir = 0 -- 495
					end -- 495
				end -- 492
			} -- 492
		) -- 492
		btn.root.position = Vec2(x, viewH - 96 - WarpButtonH) -- 501
		warpButtons[#warpButtons + 1] = btn -- 502
	end -- 470
	local warpLeftX = viewW - (WarpButtonW * 2 + 8) - 20 -- 504
	makeWarpButton("◀ 回退", -1, warpLeftX) -- 505
	makeWarpButton("加速 ▶", 1, warpLeftX + WarpButtonW + 8) -- 506
	datePlate = createPanel( -- 508
		root, -- 508
		300, -- 508
		50, -- 508
		658964, -- 508
		{alpha = 0.45} -- 508
	) -- 508
	datePlate.position = Vec2(warpLeftX - 316, viewH - 96 - WarpButtonH + 8) -- 509
	dateLabel = createLabel(root, "发射日期 —", 30, ResultHintHex) -- 510
	if dateLabel ~= nil then -- 510
		dateLabel.anchor = Vec2(1, 0) -- 515
		dateLabel.position = Vec2(warpLeftX - 16, viewH - 96 - WarpButtonH + 18) -- 516
	end -- 516
	local LaunchButtonW = 220 -- 523
	local LaunchButtonH = 112 -- 524
	local launchButton = createButton( -- 525
		root, -- 525
		{ -- 525
			w = LaunchButtonW, -- 526
			h = LaunchButtonH, -- 527
			text = "发射", -- 528
			fontSize = 44, -- 529
			bgHex = ResultButtonBgHex, -- 530
			fgHex = ResultButtonFgHex, -- 531
			borderHex = ResultButtonBorderHex, -- 532
			fireOn = "press", -- 533
			onTap = function() -- 534
				print("[escape-velocity] launch button fire (press)") -- 536
				if launchHandler ~= nil then -- 536
					launchHandler() -- 537
				end -- 537
			end -- 534
		} -- 534
	) -- 534
	launchButton.root.position = Vec2(viewW - LaunchButtonW - 24, 96) -- 540
	launchButton.root.visible = false -- 541
	launchButton:setEnabled(false) -- 542
	local brakeRightX = viewW - BrakeButtonW - 20 -- 544
	makeBrakeButton("惯性", false, brakeRightX - BrakeButtonW - brakeGap) -- 545
	makeBrakeButton("刹车", true, brakeRightX) -- 546
	paintBrake() -- 547
	parent:addChild(root) -- 549
	return { -- 551
		onDrag = function(____, callback) -- 552
			dragHandler = callback -- 553
		end, -- 552
		setEnabled = function(____, value) -- 555
			enabled = value -- 556
			touchLayer.touchEnabled = value -- 559
			if not value then -- 559
				dragging = false -- 560
			end -- 560
		end, -- 555
		onBrake = function(____, callback) -- 562
			brakeHandler = callback -- 563
		end, -- 562
		setBrake = function(____, on) -- 565
			brakeOn = on -- 566
			paintBrake() -- 567
		end, -- 565
		onAimReady = function(____, callback) -- 569
			readyHandler = callback -- 570
		end, -- 569
		onObserve = function(____, callback) -- 572
			observeHandler = callback -- 573
		end, -- 572
		onZoom = function(____, callback) -- 575
			zoomHandler = callback -- 576
		end, -- 575
		onLaunch = function(____, callback) -- 578
			launchHandler = callback -- 579
		end, -- 578
		setArmed = function(____, armed) -- 581
			launchButton.root.visible = armed -- 582
			launchButton:setEnabled(armed) -- 583
		end, -- 581
		onWarp = function(____, callback) -- 585
			warpHandler = callback -- 586
		end, -- 585
		setDate = function(____, t0, span) -- 588
			dateSpan = span > 0 and span or 0 -- 589
			applyWarpState() -- 590
			local on = dateSpan > 0 -- 591
			local text = on and (("发射日期 " .. __TS__NumberToFixed(t0, 0)) .. " / ") .. __TS__NumberToFixed(dateSpan, 0) or "发射日期" -- 592
			if text ~= lastDateText then -- 592
				lastDateText = text -- 594
				setLabelText(dateLabel, text) -- 595
			end -- 595
		end, -- 588
		setTimeEnabled = function(____, on) -- 598
			if warpAllowed == on then -- 598
				return -- 599
			end -- 599
			warpAllowed = on -- 600
			applyWarpState() -- 601
		end, -- 598
		update = function(____, dt) -- 603
			if not warpOn or warpHoldDir == 0 then -- 603
				return -- 604
			end -- 604
			warpRepeatIn = warpRepeatIn - dt -- 605
			if warpRepeatIn > 0 then -- 605
				return -- 606
			end -- 606
			warpRepeatIn = TimeWarpStep / TimeWarpRate -- 608
			if warpHandler ~= nil then -- 608
				warpHandler(warpHoldDir) -- 609
			end -- 609
		end, -- 603
		isDragging = function() return dragging end, -- 611
		setBurnInfo = function(____, burn, budget) -- 612
			setLabelText( -- 613
				dvLabel, -- 613
				(("Δv " .. __TS__NumberToFixed(burn, 1)) .. " / ") .. __TS__NumberToFixed(budget, 0) -- 613
			) -- 613
		end, -- 612
		current = function() return aim end, -- 615
		setProbeOffset = function(____, offset) -- 616
			probeOffset = offset -- 617
		end, -- 616
		handleLocal = function(____, ____local) -- 621
			handleDelta(____exports.localToOffset(____local, space)) -- 622
		end, -- 621
		handleOffset = function(____, delta) return handleDelta(delta) end, -- 625
		debugProbeOffset = function() return probeOffset end, -- 626
		root = root -- 627
	} -- 627
end -- 261
local ResultBackdropHex = 329484 -- 644
local ResultCardHex = 1252395 -- 645
local ResultCardBorderHex = 3362938 -- 646
local ResultLevelHex = 9417948 -- 647
local ResultBodyHex = 14149367 -- 648
ResultHintHex = 8229803 -- 649
ResultButtonBgHex = 1919610 -- 650
ResultButtonAltBgHex = 1779509 -- 651
ResultButtonFgHex = 15398143 -- 652
ResultButtonBorderHex = 5211846 -- 653
local TitleSuccessHex = 8381344 -- 654
local TitleMissedHex = 16766073 -- 655
local TitleCrashedHex = 16743019 -- 656
local SelectBackdropHex = 329484 -- 658
local SelectTitleHex = 16777215 -- 659
local SelectSubtitleHex = 10470632 -- 660
local SelectHintHex = 7309478 -- 661
local SelectOpenBgHex = 1919610 -- 662
local SelectOpenFgHex = 15398143 -- 663
local SelectLockedBgHex = 1383204 -- 664
local SelectLockedFgHex = 6912140 -- 665
local SelectBorderHex = 4157096 -- 666
--- 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。
local function clampNumber(value, lo, hi) -- 669
	if value < lo then -- 669
		return lo -- 670
	end -- 670
	if value > hi then -- 670
		return hi -- 671
	end -- 671
	return value -- 672
end -- 669
--- 三态标题（逐字，手册 §5.8）。
local function resultTitle(result) -- 676
	if result == "success" then -- 676
		return "借力成功" -- 677
	end -- 677
	if result == "crashed" then -- 677
		return "信号中断" -- 678
	end -- 678
	return "错过目标" -- 679
end -- 676
--- 三态说明句（逐字）。
local function resultBody(result) -- 683
	if result == "success" then -- 683
		return "行星把探测器甩了出去，速度够了。" -- 684
	end -- 684
	if result == "crashed" then -- 684
		return "探测器撞上行星，任务到此为止。" -- 685
	end -- 685
	return "从行星身侧掠过，没能借到那一点速度。" -- 686
end -- 683
--- 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。
local function resultTitleColor(result) -- 690
	if result == "success" then -- 690
		return TitleSuccessHex -- 691
	end -- 691
	if result == "crashed" then -- 691
		return TitleCrashedHex -- 692
	end -- 692
	return TitleMissedHex -- 693
end -- 690
--- 第四行提示（面板自有文案，不属于三态说明句）。
-- 
-- 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
-- “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
local function resultHint(result) -- 702
	if result == "success" then -- 702
		return "下一关已解锁" -- 703
	end -- 703
	return "可重试本关，或返回关卡选择" -- 704
end -- 702
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
function ____exports.createResultPanel(parent, viewW, viewH, opts) -- 733
	local root = createPanel( -- 739
		parent, -- 739
		viewW, -- 739
		viewH, -- 739
		ResultBackdropHex, -- 739
		{alpha = 0.78} -- 739
	) -- 739
	local cardW = viewW * 0.88 -- 744
	local btnW = clampNumber(cardW - 60, MinButtonWidth, 900) -- 745
	local btnH = clampNumber(viewH * 0.13, MinButtonHeight, 150) -- 746
	local padX = (cardW - btnW) / 2 -- 747
	local padY = 44 -- 748
	local fontLevel = 34 -- 750
	local fontTitle = 66 -- 751
	local fontBody = 34 -- 752
	local fontHint = 30 -- 753
	local btnFont = 40 -- 754
	local rowGap = 26 -- 755
	local hLevel = fontLevel + 10 -- 758
	local hTitle = fontTitle + 18 -- 759
	local hBody = fontBody * 2 + 12 -- 760
	local hHint = fontHint + 10 -- 761
	local cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 762
	if cardH > viewH - 24 then -- 762
		btnH = math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2) -- 765
		cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22 -- 766
	end -- 766
	local card = createPanel( -- 769
		root, -- 769
		cardW, -- 769
		cardH, -- 769
		ResultCardHex, -- 769
		{alpha = 0.97, borderHex = ResultCardBorderHex, borderWidth = 3} -- 769
	) -- 769
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2) -- 774
	local cursor = cardH - padY -- 777
	cursor = cursor - hLevel -- 779
	local levelLabel = createLabel(card, "", fontLevel, ResultLevelHex) -- 780
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2) -- 781
	cursor = cursor - (rowGap + hTitle) -- 783
	local titleLabel = createLabel(card, "", fontTitle, TitleSuccessHex) -- 784
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2) -- 785
	cursor = cursor - (rowGap + hBody) -- 787
	local bodyLabel = createLabel(card, "", fontBody, ResultBodyHex) -- 788
	setLabelCenter(bodyLabel, cardW / 2, cursor + hBody / 2) -- 789
	if bodyLabel ~= nil then -- 789
		bodyLabel.textWidth = cardW - 80 -- 790
	end -- 790
	cursor = cursor - (rowGap + hHint) -- 792
	local hintLabel = createLabel(card, "", fontHint, ResultHintHex) -- 793
	setLabelCenter(hintLabel, cardW / 2, cursor + hHint / 2) -- 794
	cursor = cursor - (rowGap + btnH) -- 797
	local retryButton = createButton(card, { -- 798
		w = btnW, -- 799
		h = btnH, -- 800
		text = "重试本关", -- 801
		fontSize = btnFont, -- 802
		bgHex = ResultButtonBgHex, -- 803
		fgHex = ResultButtonFgHex, -- 804
		borderHex = ResultButtonBorderHex, -- 805
		fireOn = "press", -- 806
		onTap = opts.onRetry -- 807
	}) -- 807
	retryButton.root.position = Vec2(padX, cursor) -- 809
	cursor = cursor - (22 + btnH) -- 811
	local backButton = createButton(card, { -- 812
		w = btnW, -- 813
		h = btnH, -- 814
		text = "返回关卡选择", -- 815
		fontSize = btnFont, -- 816
		bgHex = ResultButtonAltBgHex, -- 817
		fgHex = ResultButtonFgHex, -- 818
		borderHex = ResultButtonBorderHex, -- 819
		fireOn = "press", -- 820
		onTap = opts.onBackToSelect -- 821
	}) -- 821
	backButton.root.position = Vec2(padX, cursor) -- 823
	root.visible = false -- 825
	retryButton:setEnabled(false) -- 828
	backButton:setEnabled(false) -- 829
	return { -- 831
		root = root, -- 832
		show = function(____, result, levelName) -- 833
			retryButton:setEnabled(true) -- 835
			backButton:setEnabled(true) -- 836
			setLabelText(levelLabel, levelName) -- 837
			setLabelText( -- 838
				titleLabel, -- 838
				resultTitle(result) -- 838
			) -- 838
			setLabelColor( -- 839
				titleLabel, -- 839
				resultTitleColor(result) -- 839
			) -- 839
			setLabelText( -- 840
				bodyLabel, -- 840
				resultBody(result) -- 840
			) -- 840
			setLabelText( -- 841
				hintLabel, -- 841
				resultHint(result) -- 841
			) -- 841
			root.visible = true -- 842
		end, -- 833
		hide = function() -- 844
			root.visible = false -- 845
			retryButton:setEnabled(false) -- 848
			backButton:setEnabled(false) -- 849
		end -- 844
	} -- 844
end -- 733
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
function ____exports.createLevelSelect(parent, viewW, viewH, opts) -- 889
	local root = createPanel( -- 895
		parent, -- 895
		viewW, -- 895
		viewH, -- 895
		SelectBackdropHex, -- 895
		{alpha = 0.9} -- 895
	) -- 895
	local titleLabel = createLabel(root, "选择任务", 60, SelectTitleHex) -- 897
	setLabelCenter(titleLabel, viewW / 2, viewH - 96) -- 898
	local subtitleLabel = createLabel(root, "", 34, SelectSubtitleHex) -- 900
	setLabelCenter( -- 901
		subtitleLabel, -- 901
		viewW / 2, -- 901
		viewH - clampNumber(viewH * 0.13, 110, 260) -- 901
	) -- 901
	local hintLabel = createLabel(root, "完成一关即解锁下一关", 30, SelectHintHex) -- 903
	setLabelCenter( -- 904
		hintLabel, -- 904
		viewW / 2, -- 904
		clampNumber(viewH * 0.045, 36, 90) -- 904
	) -- 904
	local count = #opts.levels -- 906
	local cols = viewH > viewW and 2 or 1 -- 909
	local rows = math.max( -- 910
		1, -- 910
		math.ceil(count / cols) -- 910
	) -- 910
	local gap = 18 -- 911
	local headerH = clampNumber(viewH * 0.16, 120, 320) -- 912
	local footerH = clampNumber(viewH * 0.1, 80, 200) -- 913
	local availW = viewW * 0.84 -- 914
	local availH = viewH - headerH - footerH - gap * (rows - 1) -- 915
	local btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820) -- 916
	local btnH = clampNumber(rows > 0 and availH / rows or MinButtonHeight, MinButtonHeight, 190) -- 917
	local gridW = cols * btnW + gap * (cols - 1) -- 918
	local topY = viewH - headerH -- 919
	local buttons = {} -- 921
	do -- 921
		local i = 0 -- 922
		while i < count do -- 922
			local index = i -- 924
			local button = createButton( -- 925
				root, -- 925
				{ -- 925
					w = btnW, -- 926
					h = btnH, -- 927
					text = opts.levels[index + 1].name, -- 928
					fontSize = 38, -- 929
					bgHex = SelectLockedBgHex, -- 930
					fgHex = SelectLockedFgHex, -- 931
					borderHex = SelectBorderHex, -- 932
					fireOn = "press", -- 934
					onTap = function() return opts:onPick(index) end -- 935
				} -- 935
			) -- 935
			local col = index % cols -- 937
			local rowIndex = math.floor(index / cols) -- 938
			button.root.position = Vec2((viewW - gridW) / 2 + col * (btnW + gap), topY - (rowIndex + 1) * btnH - rowIndex * gap) -- 939
			buttons[#buttons + 1] = button -- 943
			i = i + 1 -- 922
		end -- 922
	end -- 922
	local replayButton = opts.onReplayIntro ~= nil and createButton( -- 949
		root, -- 950
		{ -- 950
			w = clampNumber(viewW * 0.36, 180, 300), -- 951
			h = MinButtonHeight, -- 952
			text = "重看开场", -- 953
			fontSize = 30, -- 954
			bgHex = SelectLockedBgHex, -- 955
			fgHex = SelectSubtitleHex, -- 956
			borderHex = SelectBorderHex, -- 957
			fireOn = "press", -- 958
			onTap = function() -- 959
				if opts.onReplayIntro ~= nil then -- 959
					opts:onReplayIntro() -- 960
				end -- 960
			end -- 959
		} -- 959
	) or nil -- 959
	if replayButton ~= nil then -- 959
		local gridBottom = topY - rows * btnH - (rows - 1) * gap -- 965
		local by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH) -- 966
		replayButton.root.position = Vec2( -- 967
			(viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, -- 967
			by -- 967
		) -- 967
	end -- 967
	root.visible = false -- 970
	do -- 970
		local i = 0 -- 971
		while i < count do -- 971
			buttons[i + 1]:setEnabled(false) -- 971
			i = i + 1 -- 971
		end -- 971
	end -- 971
	if replayButton ~= nil then -- 971
		replayButton:setEnabled(false) -- 972
	end -- 972
	return { -- 974
		root = root, -- 975
		show = function(____, unlocked) -- 976
			local maxUnlocked = clampNumber( -- 977
				math.floor(unlocked), -- 977
				0, -- 977
				count - 1 -- 977
			) -- 977
			setLabelText( -- 978
				subtitleLabel, -- 978
				(("已解锁 " .. __TS__NumberToFixed(maxUnlocked + 1, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 978
			) -- 978
			do -- 978
				local i = 0 -- 979
				while i < count do -- 979
					local button = buttons[i + 1] -- 980
					local open = i <= maxUnlocked -- 981
					button:setEnabled(open) -- 982
					button:setText(open and opts.levels[i + 1].name or opts.levels[i + 1].name .. " 未解锁") -- 983
					if open then -- 983
						button:setColors(SelectOpenBgHex, SelectOpenFgHex) -- 984
					else -- 984
						button:setColors(SelectLockedBgHex, SelectLockedFgHex) -- 985
					end -- 985
					i = i + 1 -- 979
				end -- 979
			end -- 979
			root.visible = true -- 987
			if replayButton ~= nil then -- 987
				replayButton:setEnabled(true) -- 988
			end -- 988
		end, -- 976
		hide = function() -- 990
			root.visible = false -- 991
			do -- 991
				local i = 0 -- 993
				while i < count do -- 993
					buttons[i + 1]:setEnabled(false) -- 993
					i = i + 1 -- 993
				end -- 993
			end -- 993
			if replayButton ~= nil then -- 993
				replayButton:setEnabled(false) -- 994
			end -- 994
		end -- 990
	} -- 990
end -- 889
return ____exports -- 889