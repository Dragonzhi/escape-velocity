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
	local dx = touchOffset.x - probeOffset.x -- 65
	local dy = touchOffset.y - probeOffset.y -- 66
	local len = math.sqrt(dx * dx + dy * dy) -- 68
	if len < 0.000001 then -- 68
		return {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 71
	end -- 71
	local ux = dx / len -- 76
	local uy = -dy / len -- 77
	local safeMax = maxDragPx > 1 and maxDragPx or 1 -- 79
	local power = len / safeMax -- 80
	if power < 0 then -- 80
		power = 0 -- 81
	end -- 81
	if power > 1 then -- 81
		power = 1 -- 82
	end -- 82
	local speed = AimMinSpeed + (AimMaxSpeed - AimMinSpeed) * power -- 84
	return {velocity = {x = ux * speed, y = uy * speed}, power = power, unit = {x = ux, y = uy}} -- 86
end -- 59
--- 把屏幕位置（**投影偏移空间**，与 `project()` 同空间）转成平面坐标。
-- 
-- 不是矄准必需（矄准只用方向），但调试与关卡设计时有用。
-- 与 `project()` 互逆（已有往返测试守着）。
function ____exports.screenToPlane(viewPoint, basis) -- 99
	local world = screenToPlaneY(viewPoint, basis, 0) -- 103
	if world == nil then -- 103
		return nil -- 104
	end -- 104
	return {x = world.x / PlaneToWorldX, y = world.z / PlaneToWorldZ} -- 106
end -- 99
--- 默认的力度→拖动像素映射（供 UI 层统一引用）。
function ____exports.defaultMaxDragPx() -- 110
	return AimMaxDragPx -- 111
end -- 110
--- 默认速度区间（供 UI 层展示）。
function ____exports.defaultSpeedRange() -- 115
	return {min = AimMinSpeed, max = AimMaxSpeed} -- 116
end -- 115
--- 全屏输入节点的局部坐标 → 投影偏移空间。
-- 
-- 两个空间的差异（已核对 `Projection.ts` 的 R4 标定结论）：
-- 
-- | | 原点 | 范围 | Y 方向 |
-- |---|---|---|---|
-- | 全屏节点局部坐标 | **左下角** | [0,W]×[0,H] | **+Y 向上** |
-- | 投影偏移空间 | **屏幕中心** | ±W/2, ±H/2 | **+Y 向下** |
-- 
-- 换算：`offset.x = local.x - W/2`，`offset.y = H/2 - local.y`。
function ____exports.localToOffset(____local, space) -- 137
	return {x = ____local.x - space.viewW / 2, y = space.viewH / 2 - ____local.y} -- 138
end -- 137
--- 反向换算（投影偏移空间 → 全屏节点局部坐标）。
function ____exports.offsetToLocal(offset, space) -- 142
	return {x = offset.x + space.viewW / 2, y = space.viewH / 2 - offset.y} -- 143
end -- 142
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
function ____exports.createAimInput(parent, viewW, viewH) -- 194
	local root = Node() -- 199
	root.size = Size(viewW, viewH) -- 200
	root.anchor = Vec2(0.5, 0.5) -- 201
	root.position = Vec2(0, 0) -- 202
	local touchLayer = Node() -- 205
	touchLayer.size = Size(viewW, viewH) -- 206
	touchLayer.anchor = Vec2(0.5, 0.5) -- 207
	touchLayer.position = Vec2(viewW / 2, viewH / 2) -- 208
	touchLayer.touchEnabled = true -- 209
	touchLayer.swallowTouches = true -- 210
	root:addChild(touchLayer) -- 211
	local space = {viewW = viewW, viewH = viewH} -- 213
	local enabled = false -- 215
	local dragging = false -- 216
	local aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 217
	local probeOffset = {x = 0, y = 0} -- 220
	local dragHandler = nil -- 222
	local releaseHandler = nil -- 223
	local function handleOffset(offset) -- 225
		aim = ____exports.computeAim(probeOffset, offset, AimMaxDragPx) -- 226
		if dragHandler ~= nil then -- 226
			dragHandler(aim) -- 227
		end -- 227
	end -- 225
	touchLayer:onTapBegan(function(touch) -- 230
		if not enabled then -- 230
			return -- 231
		end -- 231
		dragging = true -- 232
		handleOffset(____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space)) -- 233
	end) -- 230
	touchLayer:onTapMoved(function(touch) -- 236
		if not enabled or not dragging then -- 236
			return -- 237
		end -- 237
		handleOffset(____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space)) -- 238
	end) -- 236
	touchLayer:onTapEnded(function(touch) -- 241
		if not enabled or not dragging then -- 241
			return -- 242
		end -- 242
		dragging = false -- 243
		handleOffset(____exports.localToOffset({x = touch.location.x, y = touch.location.y}, space)) -- 244
		if releaseHandler ~= nil then -- 244
			releaseHandler(aim) -- 245
		end -- 245
	end) -- 241
	parent:addChild(root) -- 248
	return { -- 250
		onDrag = function(____, callback) -- 251
			dragHandler = callback -- 252
		end, -- 251
		onRelease = function(____, callback) -- 254
			releaseHandler = callback -- 255
		end, -- 254
		setEnabled = function(____, value) -- 257
			enabled = value -- 258
			if not value then -- 258
				dragging = false -- 259
			end -- 259
		end, -- 257
		current = function() return aim end, -- 261
		setProbeOffset = function(____, offset) -- 262
			probeOffset = offset -- 263
		end, -- 262
		handleLocal = function(____, ____local) -- 265
			handleOffset(____exports.localToOffset(____local, space)) -- 266
		end, -- 265
		handleOffset = function(____, offset) return handleOffset(offset) end, -- 269
		root = root -- 270
	} -- 270
end -- 194
return ____exports -- 194