-- [ts]: Ui.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 22
local Color = ____Dora.Color -- 22
local DrawNode = ____Dora.DrawNode -- 22
local Label = ____Dora.Label -- 22
local Node = ____Dora.Node -- 22
local Size = ____Dora.Size -- 22
local Vec2 = ____Dora.Vec2 -- 22
--- 项目统一字体（与现有 UI 一致）。
____exports.FontName = "sarasa-mono-sc-regular" -- 25
--- 触屏目标的**绝对下限**（视图逻辑像素）—— 不是“按钮就该这么大”。
-- 
-- ⚠️ 曾经写成 560/130，结果在竖屏窄屏（实测 View.size = 601×1066）里：
-- 560 宽的按钮几乎顶满屏宽，六行 130 高的关卡按钮直接从屏幕底部溢出（L6 被裁、底部提示被挤没）。
-- 真正的尺寸应由布局按**可用空间**算，这里只保一个“不要小到点不中”的地板。
____exports.MinButtonHeight = 72 -- 40
____exports.MinButtonWidth = 160 -- 41
--- 0xRRGGBB + alpha(0–1) → Color。
-- 
-- 用除法取通道而不用 `>>` / `&`：位运算在 TSTL 的不同 Lua 目标上支持面更窄，
-- 而这里只有三次算术，代价可忽略。
function ____exports.colorFromHex(hex, alpha) -- 49
	local r = math.floor(hex / 65536) % 256 -- 50
	local g = math.floor(hex / 256) % 256 -- 51
	local b = hex % 256 -- 52
	local a = alpha * 255 -- 53
	if a < 0 then -- 53
		a = 0 -- 54
	end -- 54
	if a > 255 then -- 54
		a = 255 -- 55
	end -- 55
	return Color( -- 56
		r, -- 56
		g, -- 56
		b, -- 56
		math.floor(a) -- 56
	) -- 56
end -- 49
--- 把颜色整体调亮（factor > 1）；按下态用它，避免再写一套配色常量。
function ____exports.shadeHex(hex, factor) -- 60
	local r0 = math.floor(hex / 65536) % 256 -- 61
	local g0 = math.floor(hex / 256) % 256 -- 62
	local b0 = hex % 256 -- 63
	local r = math.min( -- 64
		255, -- 64
		math.floor(r0 * factor) -- 64
	) -- 64
	local g = math.min( -- 65
		255, -- 65
		math.floor(g0 * factor) -- 65
	) -- 65
	local b = math.min( -- 66
		255, -- 66
		math.floor(b0 * factor) -- 66
	) -- 66
	return r * 65536 + g * 256 + b -- 67
end -- 60
--- 局部矩形的四个顶点（左下 → 右下 → 右上 → 左上）。
function ____exports.rectVerts(w, h) -- 71
	return { -- 72
		Vec2(0, 0), -- 72
		Vec2(w, 0), -- 72
		Vec2(w, h), -- 72
		Vec2(0, h) -- 72
	} -- 72
end -- 71
--- 建一个实心矩形面板（局部 `[0,w]×[0,h]`）。
-- 
-- @returns 面板节点；调用方用 `position`（左下角）摆放。
function ____exports.createPanel(parent, w, h, fillHex, opts) -- 96
	local root = Node() -- 103
	root.size = Size(w, h) -- 104
	root.anchor = Vec2(0, 0) -- 105
	local alpha = opts ~= nil and opts.alpha ~= nil and opts.alpha or 1 -- 107
	local borderWidth = opts ~= nil and opts.borderWidth ~= nil and opts.borderWidth or 2 -- 108
	local ____temp_0 -- 109
	if opts ~= nil then -- 109
		____temp_0 = opts.borderHex -- 109
	else -- 109
		____temp_0 = nil -- 109
	end -- 109
	local borderHex = ____temp_0 -- 109
	local draw = DrawNode() -- 111
	draw:drawPolygon( -- 112
		____exports.rectVerts(w, h), -- 112
		____exports.colorFromHex(fillHex, alpha) -- 112
	) -- 112
	if borderHex ~= nil then -- 112
		draw:drawPolygon( -- 115
			____exports.rectVerts(w, h), -- 115
			____exports.colorFromHex(0, 0), -- 115
			borderWidth, -- 115
			____exports.colorFromHex(borderHex, alpha) -- 115
		) -- 115
	end -- 115
	root:addChild(draw) -- 117
	if opts ~= nil and opts.touch == true then -- 117
		root.touchEnabled = true -- 120
		root.swallowTouches = true -- 121
	end -- 121
	parent:addChild(root) -- 124
	return root -- 125
end -- 96
--- 建一个居中锚点的文字（`anchor = (0.5,0.5)`，用 `position` 指定文字中心）。
-- 
-- @returns Label；字体缺失时返回 undefined（不是异常，也不是空字符串）。
function ____exports.createLabel(parent, text, fontSize, colorHex) -- 133
	local label = Label(____exports.FontName, fontSize) -- 139
	if label == nil then -- 139
		return nil -- 140
	end -- 140
	label.text = text -- 141
	label.color = ____exports.colorFromHex(colorHex, 1) -- 142
	label.anchor = Vec2(0.5, 0.5) -- 143
	parent:addChild(label) -- 144
	return label -- 145
end -- 133
--- 安全写文字：label 可能是 undefined（字体缺失），调用点不该到处写 if。
function ____exports.setLabelText(label, text) -- 149
	if label ~= nil then -- 149
		label.text = text -- 150
	end -- 150
end -- 149
--- 安全改颜色。
function ____exports.setLabelColor(label, colorHex) -- 154
	if label ~= nil then -- 154
		label.color = ____exports.colorFromHex(colorHex, 1) -- 155
	end -- 155
end -- 154
--- 安全改位置（居中锚点语义：给的是文字中心）。
function ____exports.setLabelCenter(label, x, y) -- 159
	if label ~= nil then -- 159
		label.position = Vec2(x, y) -- 160
	end -- 160
end -- 159
--- 安全显隐。
function ____exports.setLabelVisible(label, visible) -- 164
	if label ~= nil then -- 164
		label.visible = visible -- 165
	end -- 165
end -- 164
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
function ____exports.createButton(parent, opts) -- 204
	local root = Node() -- 205
	root.size = Size(opts.w, opts.h) -- 206
	root.anchor = Vec2(0, 0) -- 207
	root.touchEnabled = true -- 208
	root.swallowTouches = true -- 209
	local draw = DrawNode() -- 211
	root:addChild(draw) -- 212
	local label = ____exports.createLabel(root, opts.text, opts.fontSize, opts.fgHex) -- 215
	if label ~= nil then -- 215
		label.position = Vec2(opts.w / 2, opts.h / 2) -- 216
	end -- 216
	local bgHex = opts.bgHex -- 218
	local fgHex = opts.fgHex -- 219
	local enabled = true -- 220
	local pressed = false -- 221
	local function repaint() -- 223
		local bg = pressed and ____exports.shadeHex(bgHex, 1.45) or bgHex -- 224
		draw:clear() -- 225
		draw:drawPolygon( -- 226
			____exports.rectVerts(opts.w, opts.h), -- 226
			____exports.colorFromHex(bg, 1) -- 226
		) -- 226
		if opts.borderHex ~= nil then -- 226
			draw:drawPolygon( -- 228
				____exports.rectVerts(opts.w, opts.h), -- 228
				____exports.colorFromHex(0, 0), -- 228
				2, -- 228
				____exports.colorFromHex(opts.borderHex, 1) -- 228
			) -- 228
		end -- 228
		____exports.setLabelColor(label, fgHex) -- 230
	end -- 223
	root:onTapBegan(function() -- 233
		if not enabled then -- 233
			return -- 234
		end -- 234
		pressed = true -- 235
		repaint() -- 236
	end) -- 233
	root:onTapEnded(function() -- 238
		if not enabled then -- 238
			return -- 239
		end -- 239
		pressed = false -- 240
		repaint() -- 241
		opts:onTap() -- 242
	end) -- 238
	repaint() -- 245
	parent:addChild(root) -- 246
	return { -- 248
		root = root, -- 249
		setText = function(____, text) return ____exports.setLabelText(label, text) end, -- 250
		setEnabled = function(____, value) -- 251
			enabled = value -- 252
			root.touchEnabled = value -- 255
			pressed = false -- 256
			repaint() -- 257
		end, -- 251
		setColors = function(____, bg, fg) -- 259
			bgHex = bg -- 260
			fgHex = fg -- 261
			repaint() -- 262
		end -- 259
	} -- 259
end -- 204
return ____exports -- 204