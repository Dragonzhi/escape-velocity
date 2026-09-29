-- [ts]: ObserveCameraTest.ts
local ____exports = {} -- 1
local ____ObserveCamera = require("game.ObserveCamera") -- 1
local captureObserve = ____ObserveCamera.captureObserve -- 1
local rotateObserve = ____ObserveCamera.rotateObserve -- 1
local stepObserve = ____ObserveCamera.stepObserve -- 1
local zoomObserve = ____ObserveCamera.zoomObserve -- 1
function ____exports.runTests() -- 3
	local checks = 0 -- 4
	local failures = {} -- 5
	local function check(name, ok) -- 6
		checks = checks + 1 -- 6
		if not ok then -- 6
			failures[#failures + 1] = name -- 6
		end -- 6
	end -- 6
	local anchor = {x = 10, y = 0, z = 20} -- 7
	local frame = {eye = {x = 60, y = 50, z = 100}, target = {x = 20, y = 0, z = 30}} -- 8
	local pose = captureObserve(frame, anchor) -- 9
	local first = stepObserve(pose, anchor, 0) -- 10
	check( -- 11
		"handoff eye continuous", -- 11
		math.abs(first.eye.x - frame.eye.x) < 1e-8 and math.abs(first.eye.y - frame.eye.y) < 1e-8 and math.abs(first.eye.z - frame.eye.z) < 1e-8 -- 11
	) -- 11
	check("handoff target continuous", first.target.x == frame.target.x and first.target.z == frame.target.z) -- 12
	rotateObserve(pose, 100, 20) -- 13
	check( -- 14
		"selection sensitivity", -- 14
		math.abs(pose.yaw - (math.atan(40, 70) * 180 / math.pi - 22)) < 1e-8 -- 14
	) -- 14
	local done = stepObserve(pose, anchor, 0.6) -- 15
	check("probe centered after blend", done.target.x == anchor.x and done.target.z == anchor.z) -- 16
	local moved = stepObserve(pose, {x = 17, y = 3, z = 24}, 0) -- 17
	check( -- 18
		"translation preserves player orbit", -- 18
		math.abs(moved.eye.x - done.eye.x - 7) < 1e-8 and math.abs(moved.eye.z - done.eye.z - 4) < 1e-8 -- 18
	) -- 18
	local paused = stepObserve(pose, {x = 17, y = 3, z = 24}, 0) -- 19
	check("paused pose stable", paused.eye.x == moved.eye.x and paused.eye.z == moved.eye.z) -- 20
	rotateObserve(pose, 0, 10000) -- 21
	check("upper pitch", pose.pitch == 75) -- 21
	rotateObserve(pose, 0, -10000) -- 22
	check("lower pitch", pose.pitch == 16) -- 22
	zoomObserve(pose, 100000, 65, 2000) -- 23
	check("near limit", pose.distance == 65 and pose.targetDistance == 65) -- 23
	zoomObserve(pose, -100000, 65, 2000) -- 24
	check("far limit", pose.distance == 2000 and pose.targetDistance == 2000) -- 24
	local focus = captureObserve(frame, anchor, 432) -- 25
	stepObserve(focus, anchor, 0.6) -- 26
	check( -- 27
		"focus distance blends", -- 27
		math.abs(math.sqrt(40 * 40 + 50 * 50 + 70 * 70) - focus.distance) < 1e-8 and focus.targetDistance == 432 -- 27
	) -- 27
	local a = captureObserve(frame, anchor) -- 28
	local b = captureObserve(frame, anchor) -- 28
	local af = stepObserve(a, anchor, 0.3) -- 29
	local bf = stepObserve(b, anchor, 0) -- 30
	do -- 30
		local i = 0 -- 31
		while i < 30 do -- 31
			bf = stepObserve(b, anchor, 0.01) -- 31
			i = i + 1 -- 31
		end -- 31
	end -- 31
	check( -- 32
		"display blend frame rate independent", -- 32
		math.abs(af.eye.x - bf.eye.x) < 1e-8 and math.abs(af.target.z - bf.target.z) < 1e-8 -- 32
	) -- 32
	return ((((#failures == 0 and "passed" or "failed") .. "\nchecks=") .. tostring(checks)) .. "\n") .. table.concat(failures, "\n") -- 33
end -- 3
return ____exports -- 3