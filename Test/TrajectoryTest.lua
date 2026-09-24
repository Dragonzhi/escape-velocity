-- [ts]: TrajectoryTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 15
local Vec2 = ____Dora.Vec2 -- 15
local ____Projection = require("game.Projection") -- 16
local prepareCamera = ____Projection.prepareCamera -- 16
local project = ____Projection.project -- 16
local HANDEDNESS = ____Projection.HANDEDNESS -- 16
local FLIP_Y = ____Projection.FLIP_Y -- 16
local toOverlay = ____Projection.toOverlay -- 16
local ____Trajectory = require("game.Trajectory") -- 18
local decimate = ____Trajectory.decimate -- 18
local defaultOptions = ____Trajectory.defaultOptions -- 18
local projectPolyline = ____Trajectory.projectPolyline -- 18
local ____Config = require("game.Config") -- 19
local PlaneToWorldX = ____Config.PlaneToWorldX -- 19
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 19
local failures = {} -- 26
local checks = 0 -- 27
local function check(name, ok, detail) -- 29
	checks = checks + 1 -- 30
	if not ok then -- 30
		failures[#failures + 1] = {name = name, detail = detail} -- 31
	end -- 31
end -- 29
local function sampleTrail() -- 34
	local pts = {} -- 35
	do -- 35
		local i = 0 -- 36
		while i <= 30 do -- 36
			pts[#pts + 1] = {x = i * 0.5, y = -i * 0.4} -- 37
			i = i + 1 -- 36
		end -- 36
	end -- 36
	return pts -- 39
end -- 34
--- 1) decimate：不超限、保留首尾、不返回 nil 项。
local function testDecimate() -- 43
	local pts = sampleTrail() -- 44
	local same = decimate(pts, 100) -- 47
	check( -- 48
		"decimate-noop", -- 48
		#same == #pts, -- 48
		(("length=" .. tostring(#same)) .. " expected=") .. tostring(#pts) -- 48
	) -- 48
	local d = decimate(pts, 8) -- 51
	check( -- 52
		"decimate-length", -- 52
		#d == 8, -- 52
		("length=" .. tostring(#d)) .. " expected=8" -- 52
	) -- 52
	local firstOk = d[1].x == pts[1].x and d[1].y == pts[1].y -- 55
	local lastOk = d[#d].x == pts[#pts].x and d[#d].y == pts[#pts].y -- 56
	check( -- 57
		"decimate-keeps-ends", -- 57
		firstOk and lastOk, -- 57
		((((((("first=(" .. tostring(d[1].x)) .. ",") .. tostring(d[1].y)) .. ") last=(") .. tostring(d[#d].x)) .. ",") .. tostring(d[#d].y)) .. ")" -- 57
	) -- 57
	local allValid = true -- 60
	for ____, p in ipairs(d) do -- 61
		if p == nil then -- 61
			allValid = false -- 62
			break -- 62
		end -- 62
	end -- 62
	check("decimate-no-nil", allValid, "decimate 返回了 nil 元素") -- 64
	local two = decimate(pts, 2) -- 67
	check( -- 68
		"decimate-two", -- 68
		#two == 2 and two[1].x == pts[1].x and two[2].x == pts[#pts].x, -- 68
		"length=" .. tostring(#two) -- 68
	) -- 68
end -- 43
--- 2) 预计算基与直接 project() 完全一致。
local function testBasisConsistency() -- 72
	local cam = { -- 73
		eye = {x = 3, y = 4, z = 8}, -- 74
		target = {x = 0, y = 0, z = 0}, -- 75
		up = {x = 0, y = 1, z = 0}, -- 76
		fovYDeg = 45, -- 77
		aspect = 0.5625, -- 78
		viewW = 1080, -- 79
		viewH = 1920 -- 80
	} -- 80
	local basis = prepareCamera(cam, HANDEDNESS, FLIP_Y) -- 82
	local pts = {{x = 0, y = 0}, {x = 5, y = 3}, {x = -7, y = -4}} -- 84
	local viaPolyline = projectPolyline(pts, 0, basis) -- 90
	local allExact = true -- 95
	do -- 95
		local i = 0 -- 96
		while i < #pts do -- 96
			local world = {x = pts[i + 1].x * PlaneToWorldX, y = 0, z = pts[i + 1].y * PlaneToWorldZ} -- 97
			local direct = project(world, cam, HANDEDNESS, FLIP_Y) -- 98
			if direct == nil then -- 98
				allExact = false -- 99
				break -- 99
			end -- 99
			local expect = toOverlay(direct) -- 100
			local expectF32 = Vec2(expect.x, expect.y) -- 101
			if viaPolyline[i + 1].x ~= expectF32.x or viaPolyline[i + 1].y ~= expectF32.y then -- 101
				allExact = false -- 103
				break -- 104
			end -- 104
			i = i + 1 -- 96
		end -- 96
	end -- 96
	check("basis-matches-project", allExact, "预计算基与 project() 的结果不一致（降为 float32 后仍不同）") -- 107
end -- 72
--- 3) 核心约束：预测线与尾迹走同一套投影（同一批点 → 同一结果）。
local function testPredictEqualsTrail() -- 111
	local cam = { -- 112
		eye = {x = 0, y = 21.2, z = 21.2}, -- 113
		target = {x = 0, y = 0, z = 0}, -- 114
		up = {x = 0, y = 1, z = 0}, -- 115
		fovYDeg = 45, -- 116
		aspect = 0.5625, -- 117
		viewW = 1080, -- 118
		viewH = 1920 -- 119
	} -- 119
	local basis = prepareCamera(cam, HANDEDNESS, FLIP_Y) -- 121
	local opts = defaultOptions() -- 122
	local pts = sampleTrail() -- 123
	local predictPts = decimate(pts, opts.maxPoints) -- 126
	local predictProj = projectPolyline(predictPts, opts.y, basis) -- 127
	local trailProj = projectPolyline( -- 130
		decimate(pts, opts.maxPoints), -- 130
		opts.y, -- 130
		basis -- 130
	) -- 130
	local same = #predictProj == #trailProj -- 132
	if same then -- 132
		do -- 132
			local i = 0 -- 134
			while i < #predictProj do -- 134
				if predictProj[i + 1].x ~= trailProj[i + 1].x or predictProj[i + 1].y ~= trailProj[i + 1].y then -- 134
					same = false -- 135
					break -- 135
				end -- 135
				i = i + 1 -- 134
			end -- 134
		end -- 134
	end -- 134
	check( -- 138
		"predict-equals-trail", -- 138
		same, -- 138
		((("predict=" .. tostring(#predictProj)) .. " trail=") .. tostring(#trailProj)) .. "（两者必须逐点相同）" -- 138
	) -- 138
end -- 111
--- 4) 投影结果的合理性：同一条竖直轨道应在屏幕上纵向展开。
local function testVerticalSpread() -- 142
	local cam = { -- 143
		eye = {x = 0, y = 21.2, z = 21.2}, -- 144
		target = {x = 0, y = 0, z = 0}, -- 145
		up = {x = 0, y = 1, z = 0}, -- 146
		fovYDeg = 45, -- 147
		aspect = 0.5625, -- 148
		viewW = 1080, -- 149
		viewH = 1920 -- 150
	} -- 150
	local basis = prepareCamera(cam, HANDEDNESS, FLIP_Y) -- 152
	local pts = {{x = 0, y = 10}, {x = 0, y = 0}, {x = 0, y = -10}} -- 155
	local proj = projectPolyline(pts, 0, basis) -- 156
	check( -- 158
		"spread-count", -- 158
		#proj == 3, -- 158
		"count=" .. tostring(#proj) -- 158
	) -- 158
	local xSpread = math.abs(proj[1].x - proj[3].x) -- 160
	local ySpread = math.abs(proj[1].y - proj[3].y) -- 161
	check( -- 162
		"spread-vertical", -- 162
		ySpread > xSpread * 5, -- 162
		((("ySpread=" .. __TS__NumberToFixed(ySpread, 1)) .. " xSpread=") .. __TS__NumberToFixed(xSpread, 1)) .. "（纵向轨道应主要沿屏幕 y 展开）" -- 162
	) -- 162
end -- 142
--- 5) 相机后方的点被丢弃，不产生垃圾坐标。
local function testBehindCamera() -- 166
	local cam = { -- 167
		eye = {x = 0, y = 0, z = 10}, -- 168
		target = {x = 0, y = 0, z = 0}, -- 169
		up = {x = 0, y = 1, z = 0}, -- 170
		fovYDeg = 45, -- 171
		aspect = 0.5625, -- 172
		viewW = 1080, -- 173
		viewH = 1920 -- 174
	} -- 174
	local basis = prepareCamera(cam, HANDEDNESS, FLIP_Y) -- 176
	local pts = {{x = 0, y = 0}, {x = 0, y = 20}} -- 179
	local proj = projectPolyline(pts, 0, basis) -- 180
	check( -- 182
		"behind-camera-dropped", -- 182
		#proj == 1, -- 182
		("count=" .. tostring(#proj)) .. "（相机后方的点应被丢弃）" -- 182
	) -- 182
end -- 166
function ____exports.runTests() -- 185
	testDecimate() -- 186
	testBasisConsistency() -- 187
	testPredictEqualsTrail() -- 188
	testVerticalSpread() -- 189
	testBehindCamera() -- 190
	local lines = {} -- 192
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 193
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 194
	local limit = #failures < 12 and #failures or 12 -- 195
	do -- 195
		local i = 0 -- 196
		while i < limit do -- 196
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 197
			i = i + 1 -- 196
		end -- 196
	end -- 196
	return table.concat(lines, "\n") -- 199
end -- 185
return ____exports -- 185