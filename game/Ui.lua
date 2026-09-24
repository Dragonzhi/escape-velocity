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
--- 触屏目标下限（视图逻辑像素）。
-- 
-- 竖屏单手可达是硬要求（手册 §5.7），所以按钮不许做小：
-- 高度 130、宽度 560 是**下限**，不是推荐值。
____exports.MinButtonHeight = 130 -- 33
____exports.MinButtonWidth = 560 -- 34
--- 0xRRGGBB + alpha(0–1) → Color。
-- 
-- 用除法取通道而不用 `>>` / `&`：位运算在 TSTL 的不同 Lua 目标上支持面更窄，
-- 而这里只有三次算术，代价可忽略。
function ____exports.colorFromHex(hex, alpha) -- 42
	local r = math.floor(hex / 65536) % 256 -- 43
	local g = math.floor(hex / 256) % 256 -- 44
	local b = hex % 256 -- 45
	local a = alpha * 255 -- 46
	if a < 0 then -- 46
		a = 0 -- 47
	end -- 47
	if a > 255 then -- 47
		a = 255 -- 48
	end -- 48
	return Color( -- 49
		r, -- 49
		g, -- 49
		b, -- 49
		math.floor(a) -- 49
	) -- 49
end -- 42
--- 把颜色整体调亮（factor > 1）；按下态用它，避免再写一套配色常量。
function ____exports.shadeHex(hex, factor) -- 53
	local r0 = math.floor(hex / 65536) % 256 -- 54
	local g0 = math.floor(hex / 256) % 256 -- 55
	local b0 = hex % 256 -- 56
	local r = math.min( -- 57
		255, -- 57
		math.floor(r0 * factor) -- 57
	) -- 57
	local g = math.min( -- 58
		255, -- 58
		math.floor(g0 * factor) -- 58
	) -- 58
	local b = math.min( -- 59
		255, -- 59
		math.floor(b0 * factor) -- 59
	) -- 59
	return r * 65536 + g * 256 + b -- 60
end -- 53
--- 局部矩形的四个顶点（左下 → 右下 → 右上 → 左上）。
function ____exports.rectVerts(w, h) -- 64
	return { -- 65
		Vec2(0, 0), -- 65
		Vec2(w, 0), -- 65
		Vec2(w, h), -- 65
		Vec2(0, h) -- 65
	} -- 65
end -- 64
--- 建一个实心矩形面板（局部 `[0,w]×[0,h]`）。
-- 
-- @returns 面板节点；调用方用 `position`（左下角）摆放。
function ____exports.createPanel(parent, w, h, fillHex, opts) -- 89
	local root = Node() -- 96
	root.size = Size(w, h) -- 97
	root.anchor = Vec2(0, 0) -- 98
	local alpha = opts ~= nil and opts.alpha ~= nil and opts.alpha or 1 -- 100
	local borderWidth = opts ~= nil and opts.borderWidth ~= nil and opts.borderWidth or 2 -- 101
	local ____temp_0 -- 102
	if opts ~= nil then -- 102
		____temp_0 = opts.borderHex -- 102
	else -- 102
		____temp_0 = nil -- 102
	end -- 102
	local borderHex = ____temp_0 -- 102
	local draw = DrawNode() -- 104
	draw:drawPolygon( -- 105
		____exports.rectVerts(w, h), -- 105
		____exports.colorFromHex(fillHex, alpha) -- 105
	) -- 105
	if borderHex ~= nil then -- 105
		draw:drawPolygon( -- 108
			____exports.rectVerts(w, h), -- 108
			____exports.colorFromHex(0, 0), -- 108
			borderWidth, -- 108
			____exports.colorFromHex(borderHex, alpha) -- 108
		) -- 108
	end -- 108
	root:addChild(draw) -- 110
	if opts ~= nil and opts.touch == true then -- 110
		root.touchEnabled = true -- 113
		root.swallowTouches = true -- 114
	end -- 114
	parent:addChild(root) -- 117
	return root -- 118
end -- 89
--- 建一个居中锚点的文字（`anchor = (0.5,0.5)`，用 `position` 指定文字中心）。
-- 
-- @returns Label；字体缺失时返回 undefined（不是异常，也不是空字符串）。
function ____exports.createLabel(parent, text, fontSize, colorHex) -- 126
	local label = Label(____exports.FontName, fontSize) -- 132
	if label == nil then -- 132
		return nil -- 133
	end -- 133
	label.text = text -- 134
	label.color = ____exports.colorFromHex(colorHex, 1) -- 135
	label.anchor = Vec2(0.5, 0.5) -- 136
	parent:addChild(label) -- 137
	return label -- 138
end -- 126
--- 安全写文字：label 可能是 undefined（字体缺失），调用点不该到处写 if。
function ____exports.setLabelText(label, text) -- 142
	if label ~= nil then -- 142
		label.text = text -- 143
	end -- 143
end -- 142
--- 安全改颜色。
function ____exports.setLabelColor(label, colorHex) -- 147
	if label ~= nil then -- 147
		label.color = ____exports.colorFromHex(colorHex, 1) -- 148
	end -- 148
end -- 147
--- 安全改位置（居中锚点语义：给的是文字中心）。
function ____exports.setLabelCenter(label, x, y) -- 152
	if label ~= nil then -- 152
		label.position = Vec2(x, y) -- 153
	end -- 153
end -- 152
--- 安全显隐。
function ____exports.setLabelVisible(label, visible) -- 157
	if label ~= nil then -- 157
		label.visible = visible -- 158
	end -- 158
end -- 157
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
function ____exports.createButton(parent, opts) -- 197
	local root = Node() -- 198
	root.size = Size(opts.w, opts.h) -- 199
	root.anchor = Vec2(0, 0) -- 200
	root.touchEnabled = true -- 201
	root.swallowTouches = true -- 202
	local draw = DrawNode() -- 204
	root:addChild(draw) -- 205
	local label = ____exports.createLabel(root, opts.text, opts.fontSize, opts.fgHex) -- 208
	if label ~= nil then -- 208
		label.position = Vec2(opts.w / 2, opts.h / 2) -- 209
	end -- 209
	local bgHex = opts.bgHex -- 211
	local fgHex = opts.fgHex -- 212
	local enabled = true -- 213
	local pressed = false -- 214
	local function repaint() -- 216
		local bg = pressed and ____exports.shadeHex(bgHex, 1.45) or bgHex -- 217
		draw:clear() -- 218
		draw:drawPolygon( -- 219
			____exports.rectVerts(opts.w, opts.h), -- 219
			____exports.colorFromHex(bg, 1) -- 219
		) -- 219
		if opts.borderHex ~= nil then -- 219
			draw:drawPolygon( -- 221
				____exports.rectVerts(opts.w, opts.h), -- 221
				____exports.colorFromHex(0, 0), -- 221
				2, -- 221
				____exports.colorFromHex(opts.borderHex, 1) -- 221
			) -- 221
		end -- 221
		____exports.setLabelColor(label, fgHex) -- 223
	end -- 216
	root:onTapBegan(function() -- 226
		if not enabled then -- 226
			return -- 227
		end -- 227
		pressed = true -- 228
		repaint() -- 229
	end) -- 226
	root:onTapEnded(function() -- 231
		if not enabled then -- 231
			return -- 232
		end -- 232
		pressed = false -- 233
		repaint() -- 234
		opts:onTap() -- 235
	end) -- 231
	repaint() -- 238
	parent:addChild(root) -- 239
	return { -- 241
		root = root, -- 242
		setText = function(____, text) return ____exports.setLabelText(label, text) end, -- 243
		setEnabled = function(____, value) -- 244
			enabled = value -- 245
			root.touchEnabled = value -- 248
			pressed = false -- 249
			repaint() -- 250
		end, -- 244
		setColors = function(____, bg, fg) -- 252
			bgHex = bg -- 253
			fgHex = fg -- 254
			repaint() -- 255
		end -- 252
	} -- 252
end -- 197
return ____exports -- 197