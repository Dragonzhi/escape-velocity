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
--- UI 自己的时钟（秒）—— **不要改用 `App.elapsedTime`**。
-- 
-- ⚠️ 实测（2026-09-27，探针在引擎里连打 12 帧）：`App.deltaTime` 正常（0.016667/帧），
--    但 `App.elapsedTime` **一直冻结在 0.0001 附近不动**。于是下面 0.5 秒防抖里的
--    `now - lastTapAt` 恒为 0 ⇒ **每个按钮一辈子只能按动一次**（第二次起被当成「同一次点击的重复投递」吞掉）。
--    用户报的「2D/3D 按钮只能单向切一次」「刹车/发射按第二次没反应」全是这一个根因。
-- 
-- 修法：时钟自己累加，由主循环（`init.ts` 的 `threadLoop`）每帧喂 `App.deltaTime`。
-- 这样防抖语义不变（挡掉同一瞬间鼠标+触摸的双投递），但不依赖引擎那个坏掉的读数。
local uiClock = 0 -- 35
--- 推进 UI 时钟；主循环每帧调一次（在对话框、选关、关卡、结算里都要走）。
function ____exports.advanceUiClock(dt) -- 38
	uiClock = uiClock + dt -- 39
end -- 38
--- 当前 UI 时钟读数（秒，进程内单调递增）。
function ____exports.uiClockNow() -- 43
	return uiClock -- 44
end -- 43
--- 项目统一字体（与现有 UI 一致）。
____exports.FontName = "sarasa-mono-sc-regular" -- 48
--- 触屏目标的**绝对下限**（视图逻辑像素）—— 不是“按钮就该这么大”。
-- 
-- ⚠️ 曾经写成 560/130，结果在竖屏窄屏（实测 View.size = 601×1066）里：
-- 560 宽的按钮几乎顶满屏宽，六行 130 高的关卡按钮直接从屏幕底部溢出（L6 被裁、底部提示被挤没）。
-- 真正的尺寸应由布局按**可用空间**算，这里只保一个“不要小到点不中”的地板。
____exports.MinButtonHeight = 72 -- 63
____exports.MinButtonWidth = 160 -- 64
--- 0xRRGGBB + alpha(0–1) → Color。
-- 
-- 用除法取通道而不用 `>>` / `&`：位运算在 TSTL 的不同 Lua 目标上支持面更窄，
-- 而这里只有三次算术，代价可忽略。
function ____exports.colorFromHex(hex, alpha) -- 72
	local r = math.floor(hex / 65536) % 256 -- 73
	local g = math.floor(hex / 256) % 256 -- 74
	local b = hex % 256 -- 75
	local a = alpha * 255 -- 76
	if a < 0 then -- 76
		a = 0 -- 77
	end -- 77
	if a > 255 then -- 77
		a = 255 -- 78
	end -- 78
	return Color( -- 79
		r, -- 79
		g, -- 79
		b, -- 79
		math.floor(a) -- 79
	) -- 79
end -- 72
--- 把颜色整体调亮（factor > 1）；按下态用它，避免再写一套配色常量。
function ____exports.shadeHex(hex, factor) -- 83
	local r0 = math.floor(hex / 65536) % 256 -- 84
	local g0 = math.floor(hex / 256) % 256 -- 85
	local b0 = hex % 256 -- 86
	local r = math.min( -- 87
		255, -- 87
		math.floor(r0 * factor) -- 87
	) -- 87
	local g = math.min( -- 88
		255, -- 88
		math.floor(g0 * factor) -- 88
	) -- 88
	local b = math.min( -- 89
		255, -- 89
		math.floor(b0 * factor) -- 89
	) -- 89
	return r * 65536 + g * 256 + b -- 90
end -- 83
--- 局部矩形的四个顶点（左下 → 右下 → 右上 → 左上）。
function ____exports.rectVerts(w, h) -- 94
	return { -- 95
		Vec2(0, 0), -- 95
		Vec2(w, 0), -- 95
		Vec2(w, h), -- 95
		Vec2(0, h) -- 95
	} -- 95
end -- 94
--- 建一个实心矩形面板（局部 `[0,w]×[0,h]`）。
-- 
-- @returns 面板节点；调用方用 `position`（左下角）摆放。
function ____exports.createPanel(parent, w, h, fillHex, opts) -- 119
	local root = Node() -- 126
	root.size = Size(w, h) -- 127
	root.anchor = Vec2(0, 0) -- 128
	local alpha = opts ~= nil and opts.alpha ~= nil and opts.alpha or 1 -- 130
	local borderWidth = opts ~= nil and opts.borderWidth ~= nil and opts.borderWidth or 2 -- 131
	local ____temp_0 -- 132
	if opts ~= nil then -- 132
		____temp_0 = opts.borderHex -- 132
	else -- 132
		____temp_0 = nil -- 132
	end -- 132
	local borderHex = ____temp_0 -- 132
	local draw = DrawNode() -- 134
	draw:drawPolygon( -- 135
		____exports.rectVerts(w, h), -- 135
		____exports.colorFromHex(fillHex, alpha) -- 135
	) -- 135
	if borderHex ~= nil then -- 135
		draw:drawPolygon( -- 138
			____exports.rectVerts(w, h), -- 138
			____exports.colorFromHex(0, 0), -- 138
			borderWidth, -- 138
			____exports.colorFromHex(borderHex, alpha) -- 138
		) -- 138
	end -- 138
	root:addChild(draw) -- 140
	if opts ~= nil and opts.touch == true then -- 140
		root.touchEnabled = true -- 143
		root.swallowTouches = true -- 144
	end -- 144
	parent:addChild(root) -- 147
	return root -- 148
end -- 119
--- 建一个居中锚点的文字（`anchor = (0.5,0.5)`，用 `position` 指定文字中心）。
-- 
-- @returns Label；字体缺失时返回 undefined（不是异常，也不是空字符串）。
function ____exports.createLabel(parent, text, fontSize, colorHex) -- 156
	local label = Label(____exports.FontName, fontSize) -- 162
	if label == nil then -- 162
		return nil -- 163
	end -- 163
	label.text = text -- 164
	label.color = ____exports.colorFromHex(colorHex, 1) -- 165
	label.anchor = Vec2(0.5, 0.5) -- 166
	parent:addChild(label) -- 167
	return label -- 168
end -- 156
--- 安全写文字：label 可能是 undefined（字体缺失），调用点不该到处写 if。
function ____exports.setLabelText(label, text) -- 172
	if label ~= nil then -- 172
		label.text = text -- 173
	end -- 173
end -- 172
--- 安全改颜色。
function ____exports.setLabelColor(label, colorHex) -- 177
	if label ~= nil then -- 177
		label.color = ____exports.colorFromHex(colorHex, 1) -- 178
	end -- 178
end -- 177
--- 安全改位置（居中锚点语义：给的是文字中心）。
function ____exports.setLabelCenter(label, x, y) -- 182
	if label ~= nil then -- 182
		label.position = Vec2(x, y) -- 183
	end -- 183
end -- 182
--- 安全显隐。
function ____exports.setLabelVisible(label, visible) -- 187
	if label ~= nil then -- 187
		label.visible = visible -- 188
	end -- 188
end -- 187
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
function ____exports.createButton(parent, opts) -- 248
	local root = Node() -- 249
	root.size = Size(opts.w, opts.h) -- 250
	root.anchor = Vec2(0, 0) -- 251
	root.touchEnabled = true -- 252
	root.swallowTouches = true -- 253
	local draw = DrawNode() -- 255
	root:addChild(draw) -- 256
	local lastTapAt = -1 -- 259
	local label = ____exports.createLabel(root, opts.text, opts.fontSize, opts.fgHex) -- 262
	if label ~= nil then -- 262
		label.position = Vec2(opts.w / 2, opts.h / 2) -- 263
	end -- 263
	local bgHex = opts.bgHex -- 265
	local fgHex = opts.fgHex -- 266
	local enabled = true -- 267
	local pressed = false -- 268
	local function repaint() -- 270
		local baseBg = enabled and bgHex or ____exports.shadeHex(bgHex, 0.48) -- 271
		local bg = pressed and ____exports.shadeHex(baseBg, 1.45) or baseBg -- 272
		draw:clear() -- 273
		draw:drawPolygon( -- 274
			____exports.rectVerts(opts.w, opts.h), -- 274
			____exports.colorFromHex(bg, 1) -- 274
		) -- 274
		if opts.borderHex ~= nil then -- 274
			draw:drawPolygon( -- 276
				____exports.rectVerts(opts.w, opts.h), -- 276
				____exports.colorFromHex(0, 0), -- 276
				2, -- 276
				____exports.colorFromHex( -- 276
					enabled and opts.borderHex or ____exports.shadeHex(opts.borderHex, 0.48), -- 276
					1 -- 276
				) -- 276
			) -- 276
		end -- 276
		____exports.setLabelColor( -- 278
			label, -- 278
			enabled and fgHex or ____exports.shadeHex(fgHex, 0.55) -- 278
		) -- 278
	end -- 270
	local function fireTap() -- 285
		local now = ____exports.uiClockNow() -- 286
		if lastTapAt >= 0 and now - lastTapAt < 0.5 then -- 286
			return -- 287
		end -- 287
		lastTapAt = now -- 288
		Audio:play("Assets/Audio/ui_click.wav") -- 289
		opts:onTap() -- 290
	end -- 285
	root:onTapBegan(function() -- 292
		if not enabled then -- 292
			return -- 293
		end -- 293
		pressed = true -- 294
		repaint() -- 295
		if opts.onPressBegan ~= nil then -- 295
			opts:onPressBegan() -- 296
		end -- 296
		if opts.fireOn == "press" then -- 296
			fireTap() -- 298
		end -- 298
	end) -- 292
	root:onTapEnded(function() -- 300
		if not enabled then -- 300
			return -- 301
		end -- 301
		pressed = false -- 302
		repaint() -- 303
		if opts.onPressEnded ~= nil then -- 303
			opts:onPressEnded() -- 306
		end -- 306
		if opts.fireOn ~= "press" then -- 306
			fireTap() -- 307
		end -- 307
	end) -- 300
	repaint() -- 310
	parent:addChild(root) -- 311
	return { -- 313
		root = root, -- 314
		setText = function(____, text) return ____exports.setLabelText(label, text) end, -- 315
		setEnabled = function(____, value) -- 316
			enabled = value -- 317
			root.touchEnabled = value -- 320
			pressed = false -- 321
			repaint() -- 322
		end, -- 316
		setColors = function(____, bg, fg) -- 324
			bgHex = bg -- 325
			fgHex = fg -- 326
			repaint() -- 327
		end -- 324
	} -- 324
end -- 248
return ____exports -- 248