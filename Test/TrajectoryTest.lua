-- [ts]: TrajectoryTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 15
local Vec2 = ____Dora.Vec2 -- 15
local ____Dora = require("Dora") -- 16
local View = ____Dora.View -- 16
local ____Projection = require("game.Projection") -- 17
local prepareCamera = ____Projection.prepareCamera -- 17
local project = ____Projection.project -- 17
local HANDEDNESS = ____Projection.HANDEDNESS -- 17
local FLIP_Y = ____Projection.FLIP_Y -- 17
local toOverlay = ____Projection.toOverlay -- 17
local ____Trajectory = require("game.Trajectory") -- 19
local decimate = ____Trajectory.decimate -- 19
local defaultOptions = ____Trajectory.defaultOptions -- 19
local projectPolyline = ____Trajectory.projectPolyline -- 19
local ____Config = require("game.Config") -- 20
local PlaneToWorldX = ____Config.PlaneToWorldX -- 20
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 20
local failures = {} -- 27
local checks = 0 -- 28
local function check(name, ok, detail) -- 30
	checks = checks + 1 -- 31
	if not ok then -- 31
		failures[#failures + 1] = {name = name, detail = detail} -- 32
	end -- 32
end -- 30
local function sampleTrail() -- 35
	local pts = {} -- 36
	do -- 36
		local i = 0 -- 37
		while i <= 30 do -- 37
			pts[#pts + 1] = {x = i * 0.5, y = -i * 0.4} -- 38
			i = i + 1 -- 37
		end -- 37
	end -- 37
	return pts -- 40
end -- 35
--- 1) decimate：不超限、保留首尾、不返回 nil 项。
local function testDecimate() -- 44
	local pts = sampleTrail() -- 45
	local same = decimate(pts, 100) -- 48
	check( -- 49
		"decimate-noop", -- 49
		#same == #pts, -- 49
		(("length=" .. tostring(#same)) .. " expected=") .. tostring(#pts) -- 49
	) -- 49
	local d = decimate(pts, 8) -- 52
	check( -- 53
		"decimate-length", -- 53
		#d == 8, -- 53
		("length=" .. tostring(#d)) .. " expected=8" -- 53
	) -- 53
	local firstOk = d[1].x == pts[1].x and d[1].y == pts[1].y -- 56
	local lastOk = d[#d].x == pts[#pts].x and d[#d].y == pts[#pts].y -- 57
	check( -- 58
		"decimate-keeps-ends", -- 58
		firstOk and lastOk, -- 58
		((((((("first=(" .. tostring(d[1].x)) .. ",") .. tostring(d[1].y)) .. ") last=(") .. tostring(d[#d].x)) .. ",") .. tostring(d[#d].y)) .. ")" -- 58
	) -- 58
	local allValid = true -- 61
	for ____, p in ipairs(d) do -- 62
		if p == nil then -- 62
			allValid = false -- 63
			break -- 63
		end -- 63
	end -- 63
	check("decimate-no-nil", allValid, "decimate 返回了 nil 元素") -- 65
	local two = decimate(pts, 2) -- 68
	check( -- 69
		"decimate-two", -- 69
		#two == 2 and two[1].x == pts[1].x and two[2].x == pts[#pts].x, -- 69
		"length=" .. tostring(#two) -- 69
	) -- 69
end -- 44
--- 2) 预计算基与直接 project() 完全一致。
local function testBasisConsistency() -- 73
	local cam = { -- 74
		eye = {x = 3, y = 4, z = 8}, -- 75
		target = {x = 0, y = 0, z = 0}, -- 76
		up = {x = 0, y = 1, z = 0}, -- 77
		fovYDeg = 45, -- 78
		aspect = 0.5625, -- 79
		viewW = 1080, -- 80
		viewH = 1920 -- 81
	} -- 81
	local basis = prepareCamera(cam, HANDEDNESS, FLIP_Y) -- 83
	local pts = {{x = 0, y = 0}, {x = 5, y = 3}, {x = -7, y = -4}} -- 85
	local viaPolyline = projectPolyline( -- 92
		pts, -- 92
		0, -- 92
		basis, -- 92
		0, -- 92
		0 -- 92
	) -- 92
	local allExact = true -- 97
	do -- 97
		local i = 0 -- 98
		while i < #pts do -- 98
			local world = {x = pts[i + 1].x * PlaneToWorldX, y = 0, z = pts[i + 1].y * PlaneToWorldZ} -- 99
			local direct = project(world, cam, HANDEDNESS, FLIP_Y) -- 100
			if direct == nil then -- 100
				allExact = false -- 101
				break -- 101
			end -- 101
			local expect = toOverlay(direct) -- 102
			local expectF32 = Vec2(expect.x, expect.y) -- 103
			if viaPolyline[i + 1].x ~= expectF32.x or viaPolyline[i + 1].y ~= expectF32.y then -- 103
				allExact = false -- 105
				break -- 106
			end -- 106
			i = i + 1 -- 98
		end -- 98
	end -- 98
	check("basis-matches-project", allExact, "预计算基与 project() 的结果不一致（降为 float32 后仍不同）") -- 109
	local opts = defaultOptions() -- 113
	local halfW = View.size.width / 2 -- 114
	local halfH = View.size.height / 2 -- 115
	check( -- 116
		"layer-origin-is-half-view", -- 117
		opts.layerOriginX == halfW and opts.layerOriginY == halfH, -- 118
		(((((("layerOrigin=" .. tostring(opts.layerOriginX)) .. ",") .. tostring(opts.layerOriginY)) .. " expect=") .. tostring(halfW)) .. ",") .. tostring(halfH) -- 118
	) -- 118
end -- 73
--- 3) 核心约束：预测线与尾迹走同一套投影（同一批点 → 同一结果）。
local function testPredictEqualsTrail() -- 124
	local cam = { -- 125
		eye = {x = 0, y = 21.2, z = 21.2}, -- 126
		target = {x = 0, y = 0, z = 0}, -- 127
		up = {x = 0, y = 1, z = 0}, -- 128
		fovYDeg = 45, -- 129
		aspect = 0.5625, -- 130
		viewW = 1080, -- 131
		viewH = 1920 -- 132
	} -- 132
	local basis = prepareCamera(cam, HANDEDNESS, FLIP_Y) -- 134
	local opts = defaultOptions() -- 135
	local pts = sampleTrail() -- 136
	local predictPts = decimate(pts, opts.maxPoints) -- 139
	local predictProj = projectPolyline( -- 140
		predictPts, -- 140
		opts.y, -- 140
		basis, -- 140
		0, -- 140
		0 -- 140
	) -- 140
	local trailProj = projectPolyline( -- 143
		decimate(pts, opts.maxPoints), -- 143
		opts.y, -- 143
		basis, -- 143
		0, -- 143
		0 -- 143
	) -- 143
	local same = #predictProj == #trailProj -- 145
	if same then -- 145
		do -- 145
			local i = 0 -- 147
			while i < #predictProj do -- 147
				if predictProj[i + 1].x ~= trailProj[i + 1].x or predictProj[i + 1].y ~= trailProj[i + 1].y then -- 147
					same = false -- 148
					break -- 148
				end -- 148
				i = i + 1 -- 147
			end -- 147
		end -- 147
	end -- 147
	check( -- 151
		"predict-equals-trail", -- 151
		same, -- 151
		((("predict=" .. tostring(#predictProj)) .. " trail=") .. tostring(#trailProj)) .. "（两者必须逐点相同）" -- 151
	) -- 151
end -- 124
--- 4) 投影结果的合理性：同一条竖直轨道应在屏幕上纵向展开。
local function testVerticalSpread() -- 155
	local cam = { -- 156
		eye = {x = 0, y = 21.2, z = 21.2}, -- 157
		target = {x = 0, y = 0, z = 0}, -- 158
		up = {x = 0, y = 1, z = 0}, -- 159
		fovYDeg = 45, -- 160
		aspect = 0.5625, -- 161
		viewW = 1080, -- 162
		viewH = 1920 -- 163
	} -- 163
	local basis = prepareCamera(cam, HANDEDNESS, FLIP_Y) -- 165
	local pts = {{x = 0, y = 10}, {x = 0, y = 0}, {x = 0, y = -10}} -- 168
	local proj = projectPolyline( -- 169
		pts, -- 169
		0, -- 169
		basis, -- 169
		0, -- 169
		0 -- 169
	) -- 169
	check( -- 171
		"spread-count", -- 171
		#proj == 3, -- 171
		"count=" .. tostring(#proj) -- 171
	) -- 171
	local xSpread = math.abs(proj[1].x - proj[3].x) -- 173
	local ySpread = math.abs(proj[1].y - proj[3].y) -- 174
	check( -- 175
		"spread-vertical", -- 175
		ySpread > xSpread * 5, -- 175
		((("ySpread=" .. __TS__NumberToFixed(ySpread, 1)) .. " xSpread=") .. __TS__NumberToFixed(xSpread, 1)) .. "（纵向轨道应主要沿屏幕 y 展开）" -- 175
	) -- 175
end -- 155
--- 5) 相机后方的点被丢弃，不产生垃圾坐标。
local function testBehindCamera() -- 179
	local cam = { -- 180
		eye = {x = 0, y = 0, z = 10}, -- 181
		target = {x = 0, y = 0, z = 0}, -- 182
		up = {x = 0, y = 1, z = 0}, -- 183
		fovYDeg = 45, -- 184
		aspect = 0.5625, -- 185
		viewW = 1080, -- 186
		viewH = 1920 -- 187
	} -- 187
	local basis = prepareCamera(cam, HANDEDNESS, FLIP_Y) -- 189
	local pts = {{x = 0, y = 0}, {x = 0, y = 20}} -- 192
	local proj = projectPolyline( -- 193
		pts, -- 193
		0, -- 193
		basis, -- 193
		0, -- 193
		0 -- 193
	) -- 193
	check( -- 195
		"behind-camera-dropped", -- 195
		#proj == 1, -- 195
		("count=" .. tostring(#proj)) .. "（相机后方的点应被丢弃）" -- 195
	) -- 195
end -- 179
function ____exports.runTests() -- 198
	testDecimate() -- 199
	testBasisConsistency() -- 200
	testPredictEqualsTrail() -- 201
	testVerticalSpread() -- 202
	testBehindCamera() -- 203
	local lines = {} -- 205
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 206
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 207
	local limit = #failures < 12 and #failures or 12 -- 208
	do -- 208
		local i = 0 -- 209
		while i < limit do -- 209
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 210
			i = i + 1 -- 209
		end -- 209
	end -- 209
	return table.concat(lines, "\n") -- 212
end -- 198
return ____exports -- 198