-- [ts]: Hud.ts
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
--- 纯计算：由“探测器屏幕偏移”与“当前触摸屏幕偏移”解算发射向量。
-- 
-- 方向语义（手册 §5.7）：发射方向 = **探测器 → 触摸点**。
-- 屏幕上玩家把手指移到探测器**上方**，发射就朝屏幕上方。
-- 
-- @param probeOffset 探测器在投影偏移空间中的位置
-- @param touchOffset 触摸点在投影偏移空间中的位置
-- @param maxDragPx 拖动多少像素算满力
function ____exports.computeAim(probeOffset, touchOffset, maxDragPx) -- 59
	local dx = touchOffset.x - probeOffset.x -- 68
	local dy = touchOffset.y - probeOffset.y -- 69
	local len = math.sqrt(dx * dx + dy * dy) -- 71
	if len < 0.000001 then -- 71
		return {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 74
	end -- 74
	local ux = dx / len -- 77
	local uy = -dy / len -- 82
	local safeMax = maxDragPx > 1 and maxDragPx or 1 -- 84
	local power = len / safeMax -- 85
	if power < 0 then -- 85
		power = 0 -- 86
	end -- 86
	if power > 1 then -- 86
		power = 1 -- 87
	end -- 87
	local speed = AimMinSpeed + (AimMaxSpeed - AimMinSpeed) * power -- 89
	return {velocity = {x = ux * speed, y = uy * speed}, power = power, unit = {x = ux, y = uy}} -- 91
end -- 59
--- 把屏幕位置（**投影偏移空间**，与 `project()` 同空间）转成平面坐标。
-- 
-- 不是矄准必需（矄准只用方向），但调试与关卡设计时有用。
-- 与 `project()` 互逆（已有往返测试守着）。
function ____exports.screenToPlane(viewPoint, basis) -- 104
	local world = screenToPlaneY(viewPoint, basis, 0) -- 108
	if world == nil then -- 108
		return nil -- 109
	end -- 109
	return {x = world.x / PlaneToWorldX, y = world.z / PlaneToWorldZ} -- 111
end -- 104
--- 默认的力度→拖动像素映射（供 UI 层统一引用）。
function ____exports.defaultMaxDragPx() -- 115
	return AimMaxDragPx -- 116
end -- 115
--- 默认速度区间（供 UI 层展示）。
function ____exports.defaultSpeedRange() -- 120
	return {min = AimMinSpeed, max = AimMaxSpeed} -- 121
end -- 120
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
function ____exports.localToOffset(____local, space) -- 142
	return {x = ____local.x - space.viewW / 2, y = ____local.y - space.viewH / 2} -- 143
end -- 142
--- 反向换算（投影偏移空间 → 全屏节点局部坐标）。
function ____exports.offsetToLocal(offset, space) -- 147
	return {x = offset.x + space.viewW / 2, y = offset.y + space.viewH / 2} -- 148
end -- 147
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
function ____exports.createAimInput(parent, viewW, viewH) -- 199
	local root = Node() -- 204
	root.size = Size(viewW, viewH) -- 205
	root.anchor = Vec2(0.5, 0.5) -- 206
	root.position = Vec2(0, 0) -- 207
	local touchLayer = Node() -- 210
	touchLayer.size = Size(viewW, viewH) -- 211
	touchLayer.anchor = Vec2(0.5, 0.5) -- 212
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 213
	touchLayer.touchEnabled = true -- 214
	touchLayer.swallowTouches = true -- 215
	root:addChild(touchLayer) -- 216
	local space = {viewW = viewW, viewH = viewH} -- 218
	local enabled = false -- 220
	local dragging = false -- 221
	local aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 222
	local probeOffset = {x = 0, y = 0} -- 225
	local dragHandler = nil -- 227
	local releaseHandler = nil -- 228
	local function handleOffset(offset) -- 230
		aim = ____exports.computeAim(probeOffset, offset, AimMaxDragPx) -- 231
		if dragHandler ~= nil then -- 231
			dragHandler(aim) -- 232
		end -- 232
	end -- 230
	touchLayer:onTapBegan(function(touch) -- 235
		if not enabled then -- 235
			return -- 236
		end -- 236
		dragging = true -- 237
		handleOffset(____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space)) -- 238
	end) -- 235
	touchLayer:onTapMoved(function(touch) -- 241
		if not enabled or not dragging then -- 241
			return -- 242
		end -- 242
		handleOffset(____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space)) -- 243
	end) -- 241
	touchLayer:onTapEnded(function(touch) -- 246
		if not enabled or not dragging then -- 246
			return -- 247
		end -- 247
		dragging = false -- 248
		handleOffset(____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space)) -- 249
		if releaseHandler ~= nil then -- 249
			releaseHandler(aim) -- 250
		end -- 250
	end) -- 246
	parent:addChild(root) -- 253
	return { -- 255
		onDrag = function(____, callback) -- 256
			dragHandler = callback -- 257
		end, -- 256
		onRelease = function(____, callback) -- 259
			releaseHandler = callback -- 260
		end, -- 259
		setEnabled = function(____, value) -- 262
			enabled = value -- 263
			if not value then -- 263
				dragging = false -- 264
			end -- 264
		end, -- 262
		current = function() return aim end, -- 266
		setProbeOffset = function(____, offset) -- 267
			probeOffset = offset -- 268
		end, -- 267
		handleLocal = function(____, ____local) -- 270
			handleOffset(____exports.localToOffset(____local, space)) -- 271
		end, -- 270
		handleOffset = function(____, offset) return handleOffset(offset) end, -- 274
		root = root -- 275
	} -- 275
end -- 199
return ____exports -- 199