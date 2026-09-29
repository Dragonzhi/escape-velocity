-- [ts]: ObserveCamera.ts
local ____exports = {} -- 1
function ____exports.captureObserve(frame, anchor, targetDistance) -- 8
	local x = frame.eye.x - frame.target.x -- 9
	local y = frame.eye.y - frame.target.y -- 9
	local z = frame.eye.z - frame.target.z -- 9
	local distance = math.sqrt(x * x + y * y + z * z) -- 10
	return { -- 11
		yaw = math.atan(x, z) * 180 / math.pi, -- 11
		pitch = math.asin(y / math.max(distance, 0.000001)) * 180 / math.pi, -- 11
		distance = distance, -- 12
		targetDistance = targetDistance ~= nil and targetDistance or distance, -- 12
		age = 0, -- 12
		offset = {x = frame.target.x - anchor.x, y = frame.target.y - anchor.y, z = frame.target.z - anchor.z} -- 12
	} -- 12
end -- 8
function ____exports.rotateObserve(pose, dx, dy) -- 14
	pose.yaw = pose.yaw - dx * 0.22 -- 15
	pose.pitch = math.max( -- 16
		16, -- 16
		math.min(75, pose.pitch + dy * 0.16) -- 16
	) -- 16
end -- 14
function ____exports.zoomObserve(pose, delta, min, max) -- 18
	pose.distance = math.max( -- 19
		min, -- 19
		math.min( -- 19
			max, -- 19
			pose.distance * math.exp(-delta * 0.002) -- 19
		) -- 19
	) -- 19
	pose.targetDistance = math.max( -- 20
		min, -- 20
		math.min( -- 20
			max, -- 20
			pose.targetDistance * math.exp(-delta * 0.002) -- 20
		) -- 20
	) -- 20
end -- 18
function ____exports.stepObserve(pose, anchor, dt) -- 22
	pose.age = pose.age + math.max(0, dt) -- 23
	local u = math.min(1, pose.age / 0.6) -- 24
	local remaining = 1 - u * u * (3 - 2 * u) -- 24
	local target = {x = anchor.x + pose.offset.x * remaining, y = anchor.y + pose.offset.y * remaining, z = anchor.z + pose.offset.z * remaining} -- 25
	local yaw = pose.yaw * math.pi / 180 -- 26
	local pitch = pose.pitch * math.pi / 180 -- 26
	local r = pose.distance * remaining + pose.targetDistance * (1 - remaining) -- 26
	return { -- 27
		target = target, -- 27
		eye = { -- 27
			x = target.x + r * math.cos(pitch) * math.sin(yaw), -- 27
			y = target.y + r * math.sin(pitch), -- 27
			z = target.z + r * math.cos(pitch) * math.cos(yaw) -- 27
		} -- 27
	} -- 27
end -- 22
return ____exports -- 22