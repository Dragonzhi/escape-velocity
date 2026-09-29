-- [ts]: Ui.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 23
local Audio = ____Dora.Audio -- 23
local Color = ____Dora.Color -- 23
local DrawNode = ____Dora.DrawNode -- 23
local Label = ____Dora.Label -- 23
local Node = ____Dora.Node -- 23
local Size = ____Dora.Size -- 23
local Vec2 = ____Dora.Vec2 -- 23
local VGNode = ____Dora.VGNode -- 23
local nvg = require("nvg") -- 24
--- 0xRRGGBB + alpha(0–1) → Color。
-- 用除法取通道而不用 `>>` / `&`：位运算在 TSTL 的不同 Lua 目标上支持面更窄，
-- 而这里只有三次算术，代价可忽略。
function ____exports.colorFromHex(hex, alpha) -- 96
	local r = math.floor(hex / 65536) % 256 -- 97
	local g = math.floor(hex / 256) % 256 -- 98
	local b = hex % 256 -- 99
	local a = alpha * 255 -- 100
	if a < 0 then -- 100
		a = 0 -- 101
	end -- 101
	if a > 255 then -- 101
		a = 255 -- 102
	end -- 102
	return Color( -- 103
		r, -- 103
		g, -- 103
		b, -- 103
		math.floor(a) -- 103
	) -- 103
end -- 96
--- UI 自己的时钟（秒）—— **不要改用 `App.elapsedTime`**。
-- 
-- ⚠️ 实测（2026-09-27，探针在引擎里连打 12 帧）：`App.deltaTime` 正常（0.016667/帧），
--    但 `App.elapsedTime` **一直冻结在 0.0001 附近不动**。于是下面 0.5 秒防抖里的
--    `now - lastTapAt` 恒为 0 ⇒ **每个按钮一辈子只能按动一次**（第二次起被当成「同一次点击的重复投递」吞掉）。
--    用户报的「2D/3D 按钮只能单向切一次」「刹车/发射按第二次没反应」全是这一个根因。
-- 
-- 修法：时钟自己累加，由主循环（`init.ts` 的 `threadLoop`）每帧喂 `App.deltaTime`。
-- 这样防抖语义不变（挡掉同一瞬间鼠标+触摸的双投递），但不依赖引擎那个坏掉的读数。
local uiClock = 0 -- 37
--- 推进 UI 时钟；主循环每帧调一次（在对话框、选关、关卡、结算里都要走）。
function ____exports.advanceUiClock(dt) -- 40
	uiClock = uiClock + dt -- 41
end -- 40
--- 当前 UI 时钟读数（秒，进程内单调递增）。
function ____exports.uiClockNow() -- 45
	return uiClock -- 46
end -- 45
--- 项目统一字体（与现有 UI 一致）。
____exports.FontName = "sarasa-mono-sc-regular" -- 50
--- 触屏目标的**绝对下限**（视图逻辑像素）—— 不是“按钮就该这么大”。
-- 
-- ⚠️ 曾经写成 560/130，结果在竖屏窄屏（实测 View.size = 601×1066）里：
-- 560 宽的按钮几乎顶满屏宽，六行 130 高的关卡按钮直接从屏幕底部溢出（L6 被裁、底部提示被挤没）。
-- 真正的尺寸应由布局按**可用空间**算，这里只保一个“不要小到点不中”的地板。
____exports.MinButtonHeight = 72 -- 59
____exports.MinButtonWidth = 144 -- 60
____exports.IconButtonSize = 72 -- 61
____exports.TextButtonWidth = 144 -- 62
____exports.ButtonGap = 8 -- 63
--- NanoVG paths; icon meaning does not depend on the installed font.
local function renderButtonIcon(node, icon, hex) -- 67
	node:render(function() -- 68
		nvg.StrokeColor(____exports.colorFromHex(hex, 1)) -- 69
		nvg.StrokeWidth(2.4) -- 69
		nvg.LineCap("Round") -- 69
		nvg.LineJoin("Round") -- 69
		local function line(points) -- 70
			nvg.BeginPath() -- 71
			nvg.MoveTo(points[1], points[2]) -- 71
			do -- 71
				local i = 2 -- 72
				while i < #points do -- 72
					nvg.LineTo(points[i + 1], points[i + 1 + 1]) -- 72
					i = i + 2 -- 72
				end -- 72
			end -- 72
			nvg.Stroke() -- 73
		end -- 70
		if icon == "pause" then -- 70
			line({12, 7, 12, 29}) -- 75
			line({24, 7, 24, 29}) -- 75
		elseif icon == "play" then -- 75
			line({ -- 76
				11, -- 76
				7, -- 76
				27, -- 76
				18, -- 76
				11, -- 76
				29, -- 76
				11, -- 76
				7 -- 76
			}) -- 76
		elseif icon == "slow" or icon == "fast" then -- 76
			local a = icon == "slow" and 1 or -1 -- 78
			local c = icon == "slow" and 0 or 36 -- 78
			line({ -- 79
				c + 17 * a, -- 79
				8, -- 79
				c + 7 * a, -- 79
				18, -- 79
				c + 17 * a, -- 79
				28 -- 79
			}) -- 79
			line({ -- 79
				c + 29 * a, -- 79
				8, -- 79
				c + 19 * a, -- 79
				18, -- 79
				c + 29 * a, -- 79
				28 -- 79
			}) -- 79
		elseif icon == "cancel" then -- 79
			line({9, 9, 27, 27}) -- 80
			line({27, 9, 9, 27}) -- 80
		elseif icon == "back" then -- 80
			line({ -- 81
				19, -- 81
				7, -- 81
				8, -- 81
				18, -- 81
				19, -- 81
				29 -- 81
			}) -- 81
			line({8, 18, 29, 18}) -- 81
		elseif icon == "stop" then -- 81
			line({ -- 82
				9, -- 82
				9, -- 82
				27, -- 82
				9, -- 82
				27, -- 82
				27, -- 82
				9, -- 82
				27, -- 82
				9, -- 82
				9 -- 82
			}) -- 82
		elseif icon == "retry" then -- 82
			nvg.BeginPath() -- 83
			nvg.Arc( -- 83
				18, -- 83
				18, -- 83
				11, -- 83
				-1.5, -- 83
				3.9, -- 83
				"CW" -- 83
			) -- 83
			nvg.Stroke() -- 83
			line({ -- 83
				6, -- 83
				9, -- 83
				6, -- 83
				18, -- 83
				14, -- 83
				15 -- 83
			}) -- 83
		elseif icon == "camera" then -- 83
			line({ -- 84
				6, -- 84
				12, -- 84
				12, -- 84
				12, -- 84
				15, -- 84
				8, -- 84
				24, -- 84
				8, -- 84
				27, -- 84
				12, -- 84
				30, -- 84
				12, -- 84
				30, -- 84
				28, -- 84
				6, -- 84
				28, -- 84
				6, -- 84
				12 -- 84
			}) -- 84
			nvg.BeginPath() -- 84
			nvg.Circle(18, 20, 6) -- 84
			nvg.Stroke() -- 84
		elseif icon == "launch" then -- 84
			line({ -- 85
				13, -- 85
				25, -- 85
				13, -- 85
				14, -- 85
				18, -- 85
				5, -- 85
				23, -- 85
				14, -- 85
				23, -- 85
				25, -- 85
				13, -- 85
				25 -- 85
			}) -- 85
			line({ -- 85
				13, -- 85
				18, -- 85
				7, -- 85
				26, -- 85
				13, -- 85
				25 -- 85
			}) -- 85
			line({ -- 85
				23, -- 85
				18, -- 85
				29, -- 85
				26, -- 85
				23, -- 85
				25 -- 85
			}) -- 85
			line({16, 29, 16, 33}) -- 85
			line({20, 29, 20, 33}) -- 85
		elseif icon == "minus" or icon == "plus" then -- 85
			line({8, 18, 28, 18}) -- 86
			if icon == "plus" then -- 86
				line({18, 8, 18, 28}) -- 86
			end -- 86
		else -- 86
			line({ -- 87
				7, -- 87
				14, -- 87
				7, -- 87
				7, -- 87
				14, -- 87
				7 -- 87
			}) -- 87
			line({ -- 87
				22, -- 87
				7, -- 87
				29, -- 87
				7, -- 87
				29, -- 87
				14 -- 87
			}) -- 87
			line({ -- 87
				29, -- 87
				22, -- 87
				29, -- 87
				29, -- 87
				22, -- 87
				29 -- 87
			}) -- 87
			line({ -- 87
				14, -- 87
				29, -- 87
				7, -- 87
				29, -- 87
				7, -- 87
				22 -- 87
			}) -- 87
		end -- 87
	end) -- 68
end -- 67
--- 把颜色整体调亮（factor > 1）；按下态用它，避免再写一套配色常量。
function ____exports.shadeHex(hex, factor) -- 107
	local r0 = math.floor(hex / 65536) % 256 -- 108
	local g0 = math.floor(hex / 256) % 256 -- 109
	local b0 = hex % 256 -- 110
	local r = math.min( -- 111
		255, -- 111
		math.floor(r0 * factor) -- 111
	) -- 111
	local g = math.min( -- 112
		255, -- 112
		math.floor(g0 * factor) -- 112
	) -- 112
	local b = math.min( -- 113
		255, -- 113
		math.floor(b0 * factor) -- 113
	) -- 113
	return r * 65536 + g * 256 + b -- 114
end -- 107
--- 局部矩形的四个顶点（左下 → 右下 → 右上 → 左上）。
function ____exports.rectVerts(w, h) -- 118
	return { -- 119
		Vec2(0, 0), -- 119
		Vec2(w, 0), -- 119
		Vec2(w, h), -- 119
		Vec2(0, h) -- 119
	} -- 119
end -- 118
--- 建一个实心矩形面板（局部 `[0,w]×[0,h]`）。
-- 
-- @returns 面板节点；调用方用 `position`（左下角）摆放。
function ____exports.createPanel(parent, w, h, fillHex, opts) -- 143
	local root = Node() -- 150
	root.size = Size(w, h) -- 151
	root.anchor = Vec2(0, 0) -- 152
	local alpha = opts ~= nil and opts.alpha ~= nil and opts.alpha or 1 -- 154
	local borderWidth = opts ~= nil and opts.borderWidth ~= nil and opts.borderWidth or 2 -- 155
	local ____temp_0 -- 156
	if opts ~= nil then -- 156
		____temp_0 = opts.borderHex -- 156
	else -- 156
		____temp_0 = nil -- 156
	end -- 156
	local borderHex = ____temp_0 -- 156
	local draw = DrawNode() -- 158
	draw:drawPolygon( -- 159
		____exports.rectVerts(w, h), -- 159
		____exports.colorFromHex(fillHex, alpha) -- 159
	) -- 159
	if borderHex ~= nil then -- 159
		draw:drawPolygon( -- 162
			____exports.rectVerts(w, h), -- 162
			____exports.colorFromHex(0, 0), -- 162
			borderWidth, -- 162
			____exports.colorFromHex(borderHex, alpha) -- 162
		) -- 162
	end -- 162
	root:addChild(draw) -- 164
	if opts ~= nil and opts.touch == true then -- 164
		root.touchEnabled = true -- 167
		root.swallowTouches = true -- 168
	end -- 168
	parent:addChild(root) -- 171
	return root -- 172
end -- 143
--- 建一个居中锚点的文字（`anchor = (0.5,0.5)`，用 `position` 指定文字中心）。
-- 
-- @returns Label；字体缺失时返回 undefined（不是异常，也不是空字符串）。
function ____exports.createLabel(parent, text, fontSize, colorHex) -- 180
	local label = Label(____exports.FontName, fontSize) -- 186
	if label == nil then -- 186
		return nil -- 187
	end -- 187
	label.text = text -- 188
	label.color = ____exports.colorFromHex(colorHex, 1) -- 189
	label.anchor = Vec2(0.5, 0.5) -- 190
	parent:addChild(label) -- 191
	return label -- 192
end -- 180
--- 安全写文字：label 可能是 undefined（字体缺失），调用点不该到处写 if。
function ____exports.setLabelText(label, text) -- 196
	if label ~= nil then -- 196
		label.text = text -- 197
	end -- 197
end -- 196
--- 安全改颜色。
function ____exports.setLabelColor(label, colorHex) -- 201
	if label ~= nil then -- 201
		label.color = ____exports.colorFromHex(colorHex, 1) -- 202
	end -- 202
end -- 201
--- 安全改位置（居中锚点语义：给的是文字中心）。
function ____exports.setLabelCenter(label, x, y) -- 206
	if label ~= nil then -- 206
		label.position = Vec2(x, y) -- 207
	end -- 207
end -- 206
--- 安全显隐。
function ____exports.setLabelVisible(label, visible) -- 211
	if label ~= nil then -- 211
		label.visible = visible -- 212
	end -- 212
end -- 211
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
function ____exports.createButton(parent, opts) -- 275
	local root = Node() -- 276
	root.size = Size(opts.w, opts.h) -- 277
	root.anchor = Vec2(0, 0) -- 278
	root.touchEnabled = true -- 279
	root.swallowTouches = true -- 280
	local draw = DrawNode() -- 282
	root:addChild(draw) -- 283
	local lastTapAt = -1 -- 286
	local label = ____exports.createLabel(root, opts.text, opts.fontSize, opts.fgHex) -- 289
	if label ~= nil then -- 289
		label.position = Vec2(opts.w / 2, opts.h / 2) -- 290
	end -- 290
	local icon = opts.icon -- 291
	local iconNode = nil -- 292
	local renderedIcon = nil -- 293
	local renderedHex = -1 -- 294
	local buttonText = opts.text -- 295
	local selected = false -- 296
	local function layoutContent() -- 297
		if icon ~= nil then -- 297
			if iconNode == nil then -- 297
				iconNode = VGNode(36, 36) -- 299
				root:addChild(iconNode) -- 299
			end -- 299
			iconNode.position = Vec2(buttonText == "" and opts.w / 2 or 26, opts.h / 2) -- 300
		end -- 300
		if label ~= nil then -- 300
			label.position = Vec2(icon ~= nil and buttonText ~= "" and (opts.w + 40) / 2 or opts.w / 2, opts.h / 2) -- 302
		end -- 302
	end -- 297
	layoutContent() -- 304
	local bgHex = opts.bgHex -- 306
	local fgHex = opts.fgHex -- 307
	local enabled = true -- 308
	local pressed = false -- 309
	local function repaint() -- 311
		local baseBg = enabled and bgHex or ____exports.shadeHex(bgHex, 0.48) -- 312
		local bg = pressed and ____exports.shadeHex(baseBg, 1.45) or (selected and enabled and ____exports.shadeHex(baseBg, 1.25) or baseBg) -- 313
		draw:clear() -- 314
		draw:drawPolygon( -- 315
			____exports.rectVerts(opts.w, opts.h), -- 315
			____exports.colorFromHex(bg, 1) -- 315
		) -- 315
		if opts.borderHex ~= nil then -- 315
			draw:drawPolygon( -- 317
				____exports.rectVerts(opts.w, opts.h), -- 317
				____exports.colorFromHex(0, 0), -- 317
				2, -- 317
				____exports.colorFromHex( -- 317
					enabled and opts.borderHex or ____exports.shadeHex(opts.borderHex, 0.48), -- 317
					1 -- 317
				) -- 317
			) -- 317
		end -- 317
		____exports.setLabelColor( -- 319
			label, -- 319
			enabled and fgHex or ____exports.shadeHex(fgHex, 0.55) -- 319
		) -- 319
		if iconNode ~= nil and icon ~= nil then -- 319
			iconNode.opacity = enabled and 1 or 0.55 -- 321
			if renderedIcon ~= icon or renderedHex ~= fgHex then -- 321
				renderButtonIcon(iconNode, icon, fgHex) -- 323
				renderedIcon = icon -- 323
				renderedHex = fgHex -- 323
			end -- 323
		end -- 323
	end -- 311
	local function fireTap() -- 332
		local now = ____exports.uiClockNow() -- 333
		if lastTapAt >= 0 and now - lastTapAt < 0.5 then -- 333
			return -- 334
		end -- 334
		lastTapAt = now -- 335
		Audio:play("Assets/Audio/ui_click.wav") -- 336
		opts:onTap() -- 337
	end -- 332
	root:onTapBegan(function() -- 339
		if not enabled then -- 339
			return -- 340
		end -- 340
		pressed = true -- 341
		repaint() -- 342
		if opts.onPressBegan ~= nil then -- 342
			opts:onPressBegan() -- 343
		end -- 343
		if opts.fireOn == "press" then -- 343
			fireTap() -- 345
		end -- 345
	end) -- 339
	root:onTapEnded(function() -- 347
		if not enabled then -- 347
			return -- 348
		end -- 348
		pressed = false -- 349
		repaint() -- 350
		if opts.onPressEnded ~= nil then -- 350
			opts:onPressEnded() -- 353
		end -- 353
		if opts.fireOn ~= "press" then -- 353
			fireTap() -- 354
		end -- 354
	end) -- 347
	repaint() -- 357
	parent:addChild(root) -- 358
	return { -- 360
		root = root, -- 361
		setIcon = function(____, value) -- 362
			if icon == value then -- 362
				return -- 362
			end -- 362
			icon = value -- 362
			layoutContent() -- 362
			repaint() -- 362
		end, -- 362
		setSelected = function(____, value) -- 363
			if selected == value then -- 363
				return -- 363
			end -- 363
			selected = value -- 363
			repaint() -- 363
		end, -- 363
		setText = function(____, text) -- 364
			if buttonText == text then -- 364
				return -- 364
			end -- 364
			buttonText = text -- 364
			____exports.setLabelText(label, text) -- 364
			layoutContent() -- 364
		end, -- 364
		setEnabled = function(____, value) -- 365
			if enabled == value then -- 365
				return -- 366
			end -- 366
			enabled = value -- 367
			root.touchEnabled = value -- 370
			pressed = false -- 371
			repaint() -- 372
		end, -- 365
		setColors = function(____, bg, fg) -- 374
			if bgHex == bg and fgHex == fg then -- 374
				return -- 375
			end -- 375
			bgHex = bg -- 376
			fgHex = fg -- 377
			repaint() -- 378
		end -- 374
	} -- 374
end -- 275
return ____exports -- 275