-- [ts]: Ui.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 22
local Audio = ____Dora.Audio -- 22
local Color = ____Dora.Color -- 22
local DrawNode = ____Dora.DrawNode -- 22
local Label = ____Dora.Label -- 22
local Node = ____Dora.Node -- 22
local Size = ____Dora.Size -- 22
local Vec2 = ____Dora.Vec2 -- 22
local VGNode = ____Dora.VGNode -- 22
local nvg = require("nvg") -- 23
--- 0xRRGGBB + alpha(0–1) → Color。
-- 用除法取通道而不用 `>>` / `&`：位运算在 TSTL 的不同 Lua 目标上支持面更窄，
-- 而这里只有三次算术，代价可忽略。
function ____exports.colorFromHex(hex, alpha) -- 95
	local r = math.floor(hex / 65536) % 256 -- 96
	local g = math.floor(hex / 256) % 256 -- 97
	local b = hex % 256 -- 98
	local a = alpha * 255 -- 99
	if a < 0 then -- 99
		a = 0 -- 100
	end -- 100
	if a > 255 then -- 100
		a = 255 -- 101
	end -- 101
	return Color( -- 102
		r, -- 102
		g, -- 102
		b, -- 102
		math.floor(a) -- 102
	) -- 102
end -- 95
--- UI 自己的时钟（秒）—— **不要改用 `App.elapsedTime`**。
-- 
-- ⚠️ 实测（2026-09-27，探针在引擎里连打 12 帧）：`App.deltaTime` 正常（0.016667/帧），
--    但 `App.elapsedTime` **一直冻结在 0.0001 附近不动**。于是下面 0.5 秒防抖里的
--    `now - lastTapAt` 恒为 0 ⇒ **每个按钮一辈子只能按动一次**（第二次起被当成「同一次点击的重复投递」吞掉）。
--    用户报的「2D/3D 按钮只能单向切一次」「刹车/发射按第二次没反应」全是这一个根因。
-- 
-- 修法：时钟自己累加，由主循环（`init.ts` 的 `threadLoop`）每帧喂 `App.deltaTime`。
-- 这样防抖语义不变（挡掉同一瞬间鼠标+触摸的双投递），但不依赖引擎那个坏掉的读数。
local uiClock = 0 -- 36
--- 推进 UI 时钟；主循环每帧调一次（在对话框、选关、关卡、结算里都要走）。
function ____exports.advanceUiClock(dt) -- 39
	uiClock = uiClock + dt -- 40
end -- 39
--- 当前 UI 时钟读数（秒，进程内单调递增）。
function ____exports.uiClockNow() -- 44
	return uiClock -- 45
end -- 44
--- 项目统一字体（与现有 UI 一致）。
____exports.FontName = "sarasa-mono-sc-regular" -- 49
--- 触屏目标的**绝对下限**（视图逻辑像素）—— 不是“按钮就该这么大”。
-- 
-- ⚠️ 曾经写成 560/130，结果在竖屏窄屏（实测 View.size = 601×1066）里：
-- 560 宽的按钮几乎顶满屏宽，六行 130 高的关卡按钮直接从屏幕底部溢出（L6 被裁、底部提示被挤没）。
-- 真正的尺寸应由布局按**可用空间**算，这里只保一个“不要小到点不中”的地板。
____exports.MinButtonHeight = 72 -- 58
____exports.MinButtonWidth = 144 -- 59
____exports.IconButtonSize = 72 -- 60
____exports.TextButtonWidth = 144 -- 61
____exports.ButtonGap = 8 -- 62
--- NanoVG paths; icon meaning does not depend on the installed font.
local function renderButtonIcon(node, icon, hex) -- 66
	node:render(function() -- 67
		nvg.StrokeColor(____exports.colorFromHex(hex, 1)) -- 68
		nvg.StrokeWidth(2.4) -- 68
		nvg.LineCap("Round") -- 68
		nvg.LineJoin("Round") -- 68
		local function line(points) -- 69
			nvg.BeginPath() -- 70
			nvg.MoveTo(points[1], points[2]) -- 70
			do -- 70
				local i = 2 -- 71
				while i < #points do -- 71
					nvg.LineTo(points[i + 1], points[i + 1 + 1]) -- 71
					i = i + 2 -- 71
				end -- 71
			end -- 71
			nvg.Stroke() -- 72
		end -- 69
		if icon == "pause" then -- 69
			line({12, 7, 12, 29}) -- 74
			line({24, 7, 24, 29}) -- 74
		elseif icon == "play" then -- 74
			line({ -- 75
				11, -- 75
				7, -- 75
				27, -- 75
				18, -- 75
				11, -- 75
				29, -- 75
				11, -- 75
				7 -- 75
			}) -- 75
		elseif icon == "slow" or icon == "fast" then -- 75
			local a = icon == "slow" and 1 or -1 -- 77
			local c = icon == "slow" and 0 or 36 -- 77
			line({ -- 78
				c + 17 * a, -- 78
				8, -- 78
				c + 7 * a, -- 78
				18, -- 78
				c + 17 * a, -- 78
				28 -- 78
			}) -- 78
			line({ -- 78
				c + 29 * a, -- 78
				8, -- 78
				c + 19 * a, -- 78
				18, -- 78
				c + 29 * a, -- 78
				28 -- 78
			}) -- 78
		elseif icon == "cancel" then -- 78
			line({9, 9, 27, 27}) -- 79
			line({27, 9, 9, 27}) -- 79
		elseif icon == "back" then -- 79
			line({ -- 80
				19, -- 80
				7, -- 80
				8, -- 80
				18, -- 80
				19, -- 80
				29 -- 80
			}) -- 80
			line({8, 18, 29, 18}) -- 80
		elseif icon == "stop" then -- 80
			line({ -- 81
				9, -- 81
				9, -- 81
				27, -- 81
				9, -- 81
				27, -- 81
				27, -- 81
				9, -- 81
				27, -- 81
				9, -- 81
				9 -- 81
			}) -- 81
		elseif icon == "retry" then -- 81
			nvg.BeginPath() -- 82
			nvg.Arc( -- 82
				18, -- 82
				18, -- 82
				11, -- 82
				-1.5, -- 82
				3.9, -- 82
				"CW" -- 82
			) -- 82
			nvg.Stroke() -- 82
			line({ -- 82
				6, -- 82
				9, -- 82
				6, -- 82
				18, -- 82
				14, -- 82
				15 -- 82
			}) -- 82
		elseif icon == "camera" then -- 82
			line({ -- 83
				6, -- 83
				12, -- 83
				12, -- 83
				12, -- 83
				15, -- 83
				8, -- 83
				24, -- 83
				8, -- 83
				27, -- 83
				12, -- 83
				30, -- 83
				12, -- 83
				30, -- 83
				28, -- 83
				6, -- 83
				28, -- 83
				6, -- 83
				12 -- 83
			}) -- 83
			nvg.BeginPath() -- 83
			nvg.Circle(18, 20, 6) -- 83
			nvg.Stroke() -- 83
		elseif icon == "launch" then -- 83
			line({ -- 84
				13, -- 84
				25, -- 84
				13, -- 84
				14, -- 84
				18, -- 84
				5, -- 84
				23, -- 84
				14, -- 84
				23, -- 84
				25, -- 84
				13, -- 84
				25 -- 84
			}) -- 84
			line({ -- 84
				13, -- 84
				18, -- 84
				7, -- 84
				26, -- 84
				13, -- 84
				25 -- 84
			}) -- 84
			line({ -- 84
				23, -- 84
				18, -- 84
				29, -- 84
				26, -- 84
				23, -- 84
				25 -- 84
			}) -- 84
			line({16, 29, 16, 33}) -- 84
			line({20, 29, 20, 33}) -- 84
		elseif icon == "minus" or icon == "plus" then -- 84
			line({8, 18, 28, 18}) -- 85
			if icon == "plus" then -- 85
				line({18, 8, 18, 28}) -- 85
			end -- 85
		else -- 85
			line({ -- 86
				7, -- 86
				14, -- 86
				7, -- 86
				7, -- 86
				14, -- 86
				7 -- 86
			}) -- 86
			line({ -- 86
				22, -- 86
				7, -- 86
				29, -- 86
				7, -- 86
				29, -- 86
				14 -- 86
			}) -- 86
			line({ -- 86
				29, -- 86
				22, -- 86
				29, -- 86
				29, -- 86
				22, -- 86
				29 -- 86
			}) -- 86
			line({ -- 86
				14, -- 86
				29, -- 86
				7, -- 86
				29, -- 86
				7, -- 86
				22 -- 86
			}) -- 86
		end -- 86
	end) -- 67
end -- 66
--- 把颜色整体调亮（factor > 1）；按下态用它，避免再写一套配色常量。
function ____exports.shadeHex(hex, factor) -- 106
	local r0 = math.floor(hex / 65536) % 256 -- 107
	local g0 = math.floor(hex / 256) % 256 -- 108
	local b0 = hex % 256 -- 109
	local r = math.min( -- 110
		255, -- 110
		math.floor(r0 * factor) -- 110
	) -- 110
	local g = math.min( -- 111
		255, -- 111
		math.floor(g0 * factor) -- 111
	) -- 111
	local b = math.min( -- 112
		255, -- 112
		math.floor(b0 * factor) -- 112
	) -- 112
	return r * 65536 + g * 256 + b -- 113
end -- 106
--- 局部矩形的四个顶点（左下 → 右下 → 右上 → 左上）。
function ____exports.rectVerts(w, h) -- 117
	return { -- 118
		Vec2(0, 0), -- 118
		Vec2(w, 0), -- 118
		Vec2(w, h), -- 118
		Vec2(0, h) -- 118
	} -- 118
end -- 117
--- 建一个实心矩形面板（局部 `[0,w]×[0,h]`）。
-- 
-- @returns 面板节点；调用方用 `position`（左下角）摆放。
function ____exports.createPanel(parent, w, h, fillHex, opts) -- 142
	local root = Node() -- 149
	root.size = Size(w, h) -- 150
	root.anchor = Vec2(0, 0) -- 151
	local alpha = opts ~= nil and opts.alpha ~= nil and opts.alpha or 1 -- 153
	local borderWidth = opts ~= nil and opts.borderWidth ~= nil and opts.borderWidth or 2 -- 154
	local ____temp_0 -- 155
	if opts ~= nil then -- 155
		____temp_0 = opts.borderHex -- 155
	else -- 155
		____temp_0 = nil -- 155
	end -- 155
	local borderHex = ____temp_0 -- 155
	local draw = DrawNode() -- 157
	draw:drawPolygon( -- 158
		____exports.rectVerts(w, h), -- 158
		____exports.colorFromHex(fillHex, alpha) -- 158
	) -- 158
	if borderHex ~= nil then -- 158
		draw:drawPolygon( -- 161
			____exports.rectVerts(w, h), -- 161
			____exports.colorFromHex(0, 0), -- 161
			borderWidth, -- 161
			____exports.colorFromHex(borderHex, alpha) -- 161
		) -- 161
	end -- 161
	root:addChild(draw) -- 163
	if opts ~= nil and opts.touch == true then -- 163
		root.touchEnabled = true -- 166
		root.swallowTouches = true -- 167
	end -- 167
	parent:addChild(root) -- 170
	return root -- 171
end -- 142
--- 建一个居中锚点的文字（`anchor = (0.5,0.5)`，用 `position` 指定文字中心）。
-- 
-- @returns Label；字体缺失时返回 undefined（不是异常，也不是空字符串）。
function ____exports.createLabel(parent, text, fontSize, colorHex) -- 179
	local label = Label(____exports.FontName, fontSize) -- 185
	if label == nil then -- 185
		return nil -- 186
	end -- 186
	label.text = text -- 187
	label.color = ____exports.colorFromHex(colorHex, 1) -- 188
	label.anchor = Vec2(0.5, 0.5) -- 189
	parent:addChild(label) -- 190
	return label -- 191
end -- 179
--- 安全写文字：label 可能是 undefined（字体缺失），调用点不该到处写 if。
function ____exports.setLabelText(label, text) -- 195
	if label ~= nil then -- 195
		label.text = text -- 196
	end -- 196
end -- 195
--- 安全改颜色。
function ____exports.setLabelColor(label, colorHex) -- 200
	if label ~= nil then -- 200
		label.color = ____exports.colorFromHex(colorHex, 1) -- 201
	end -- 201
end -- 200
--- 安全改位置（居中锚点语义：给的是文字中心）。
function ____exports.setLabelCenter(label, x, y) -- 205
	if label ~= nil then -- 205
		label.position = Vec2(x, y) -- 206
	end -- 206
end -- 205
--- 安全显隐。
function ____exports.setLabelVisible(label, visible) -- 210
	if label ~= nil then -- 210
		label.visible = visible -- 211
	end -- 211
end -- 210
--- 建一个可点按钮。
-- 
-- 为什么不用 Label 当按钮：`Label` 的命中区域依赖文本尺寸，触摸目标不稳定；
-- 这里用固定 `size` 的 `Node` 承接触摸（手册 §5.7 要求触屏目标足够大），
-- 文字只是它的一个子树。
-- 
-- 按下态：`onTapBegan` 把底色调亮一档，`onTapEnded` 复原 —— 没有视觉反馈的
-- 按钮在触屏上会被当成“没反应”。
-- 
-- ⚠️ 已知局限：Dora 没有“触摸取消”回调，手指按下后划出按钮再松开，`onTapEnded`
-- 仍会触发。这里不做坐标过滤 —— `touch.location` 的局部空间在无头环境无法标定
-- （`Touch` 构造是私有的），错误的空间假设会让按钮整块点不到，比“多触发一次”更糟。
function ____exports.createButton(parent, opts) -- 274
	local root = Node() -- 275
	root.size = Size(opts.w, opts.h) -- 276
	root.anchor = Vec2(0, 0) -- 277
	root.touchEnabled = true -- 278
	root.swallowTouches = true -- 279
	local draw = DrawNode() -- 281
	root:addChild(draw) -- 282
	local lastTapAt = -1 -- 285
	local label = ____exports.createLabel(root, opts.text, opts.fontSize, opts.fgHex) -- 288
	if label ~= nil then -- 288
		label.position = Vec2(opts.w / 2, opts.h / 2) -- 289
	end -- 289
	local icon = opts.icon -- 290
	local iconNode = nil -- 291
	local renderedIcon = nil -- 292
	local renderedHex = -1 -- 293
	local buttonText = opts.text -- 294
	local selected = false -- 295
	local function layoutContent() -- 296
		if icon ~= nil then -- 296
			if iconNode == nil then -- 296
				iconNode = VGNode(36, 36) -- 298
				root:addChild(iconNode) -- 298
			end -- 298
			iconNode.position = Vec2(buttonText == "" and opts.w / 2 or 26, opts.h / 2) -- 299
		end -- 299
		if label ~= nil then -- 299
			label.position = Vec2(icon ~= nil and buttonText ~= "" and (opts.w + 40) / 2 or opts.w / 2, opts.h / 2) -- 301
		end -- 301
	end -- 296
	layoutContent() -- 303
	local bgHex = opts.bgHex -- 305
	local fgHex = opts.fgHex -- 306
	local enabled = true -- 307
	local pressed = false -- 308
	local function repaint() -- 310
		local baseBg = enabled and bgHex or ____exports.shadeHex(bgHex, 0.48) -- 311
		local bg = pressed and ____exports.shadeHex(baseBg, 1.45) or (selected and enabled and ____exports.shadeHex(baseBg, 1.25) or baseBg) -- 312
		draw:clear() -- 313
		draw:drawPolygon( -- 314
			____exports.rectVerts(opts.w, opts.h), -- 314
			____exports.colorFromHex(bg, 1) -- 314
		) -- 314
		if opts.borderHex ~= nil then -- 314
			draw:drawPolygon( -- 316
				____exports.rectVerts(opts.w, opts.h), -- 316
				____exports.colorFromHex(0, 0), -- 316
				2, -- 316
				____exports.colorFromHex( -- 316
					enabled and opts.borderHex or ____exports.shadeHex(opts.borderHex, 0.48), -- 316
					1 -- 316
				) -- 316
			) -- 316
		end -- 316
		____exports.setLabelColor( -- 318
			label, -- 318
			enabled and fgHex or ____exports.shadeHex(fgHex, 0.55) -- 318
		) -- 318
		if iconNode ~= nil and icon ~= nil then -- 318
			iconNode.opacity = enabled and 1 or 0.55 -- 320
			if renderedIcon ~= icon or renderedHex ~= fgHex then -- 320
				renderButtonIcon(iconNode, icon, fgHex) -- 322
				renderedIcon = icon -- 322
				renderedHex = fgHex -- 322
			end -- 322
		end -- 322
	end -- 310
	local function fireTap() -- 331
		local now = ____exports.uiClockNow() -- 332
		if lastTapAt >= 0 and now - lastTapAt < 0.5 then -- 332
			return -- 333
		end -- 333
		lastTapAt = now -- 334
		Audio:play("Assets/Audio/ui_click.wav") -- 335
		opts:onTap() -- 336
	end -- 331
	root:onTapBegan(function() -- 338
		if not enabled then -- 338
			return -- 339
		end -- 339
		pressed = true -- 340
		repaint() -- 341
		if opts.onPressBegan ~= nil then -- 341
			opts:onPressBegan() -- 342
		end -- 342
		if opts.fireOn == "press" then -- 342
			fireTap() -- 344
		end -- 344
	end) -- 338
	root:onTapEnded(function() -- 346
		if not enabled then -- 346
			return -- 347
		end -- 347
		pressed = false -- 348
		repaint() -- 349
		if opts.onPressEnded ~= nil then -- 349
			opts:onPressEnded() -- 352
		end -- 352
		if opts.fireOn ~= "press" then -- 352
			fireTap() -- 353
		end -- 353
	end) -- 346
	repaint() -- 356
	parent:addChild(root) -- 357
	return { -- 359
		root = root, -- 360
		setIcon = function(____, value) -- 361
			if icon == value then -- 361
				return -- 361
			end -- 361
			icon = value -- 361
			layoutContent() -- 361
			repaint() -- 361
		end, -- 361
		setSelected = function(____, value) -- 362
			if selected == value then -- 362
				return -- 362
			end -- 362
			selected = value -- 362
			repaint() -- 362
		end, -- 362
		setText = function(____, text) -- 363
			if buttonText == text then -- 363
				return -- 363
			end -- 363
			buttonText = text -- 363
			____exports.setLabelText(label, text) -- 363
			layoutContent() -- 363
		end, -- 363
		setEnabled = function(____, value) -- 364
			if enabled == value then -- 364
				return -- 365
			end -- 365
			enabled = value -- 366
			root.touchEnabled = value -- 369
			pressed = false -- 370
			repaint() -- 371
		end, -- 364
		setColors = function(____, bg, fg) -- 373
			if bgHex == bg and fgHex == fg then -- 373
				return -- 374
			end -- 374
			bgHex = bg -- 375
			fgHex = fg -- 376
			repaint() -- 377
		end -- 373
	} -- 373
end -- 274
return ____exports -- 274