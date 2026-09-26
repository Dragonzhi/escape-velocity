-- [ts]: OpeningTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 10
local Vec3 = ____Dora.Vec3 -- 10
local ____Opening = require("game.Opening") -- 12
local EarthStationIndex = ____Opening.EarthStationIndex -- 13
local ProbeOrbitRadius = ____Opening.ProbeOrbitRadius -- 14
local PullBackFrames = ____Opening.PullBackFrames -- 15
local Stations = ____Opening.Stations -- 16
local TotalFrames = ____Opening.TotalFrames -- 17
local WideFrames = ____Opening.WideFrames -- 18
local FocusFrames = ____Opening.FocusFrames -- 19
local openingBlend = ____Opening.openingBlend -- 20
local openingPhase = ____Opening.openingPhase -- 21
local openingPose = ____Opening.openingPose -- 22
local probeOrbitPos = ____Opening.probeOrbitPos -- 23
local probeOrbitVel = ____Opening.probeOrbitVel -- 24
local stationPlane = ____Opening.stationPlane -- 25
local failures = {} -- 33
local checks = 0 -- 34
local function check(name, ok, detail) -- 36
	checks = checks + 1 -- 37
	if not ok then -- 37
		failures[#failures + 1] = {name = name, detail = detail} -- 38
	end -- 38
end -- 36
local function dist3(a, b) -- 41
	local dx = a.x - b.x -- 42
	local dy = a.y - b.y -- 43
	local dz = a.z - b.z -- 44
	return math.sqrt(dx * dx + dy * dy + dz * dz) -- 45
end -- 41
--- 1) 相态边界：每一段的起止帧都必须落在正确的相态里。
local function testPhases() -- 49
	check( -- 50
		"phase-off", -- 50
		openingPhase(-1) == "off", -- 50
		"负帧号 = off" -- 50
	) -- 50
	check( -- 51
		"phase-wide-start", -- 51
		openingPhase(0) == "wide", -- 51
		"第 0 帧是全景" -- 51
	) -- 51
	check( -- 52
		"phase-wide-end", -- 52
		openingPhase(WideFrames - 1) == "wide", -- 52
		"全景最后一帧" -- 52
	) -- 52
	check( -- 53
		"phase-focus-start", -- 53
		openingPhase(WideFrames) == "focus", -- 53
		"聚焦第一帧" -- 53
	) -- 53
	check( -- 54
		"phase-focus-end", -- 54
		openingPhase(WideFrames + FocusFrames - 1) == "focus", -- 54
		"聚焦最后一帧" -- 54
	) -- 54
	check( -- 55
		"phase-hold-start", -- 55
		openingPhase(WideFrames + FocusFrames) == "hold", -- 55
		"停留第一帧" -- 55
	) -- 55
	check( -- 56
		"phase-hold-end", -- 56
		openingPhase(TotalFrames) == "hold", -- 56
		"交还选关那一帧仍是 hold" -- 56
	) -- 56
	check( -- 57
		"phase-pullback", -- 57
		openingPhase(TotalFrames + 1) == "pullback", -- 57
		"之后是拉回段" -- 57
	) -- 57
end -- 49
--- 2) 混合系数：0 → 1 → 0，且两端与中间单调。
local function testBlend() -- 61
	check( -- 62
		"blend-zero", -- 62
		openingBlend(0) == 0, -- 62
		"全景起点 = 0" -- 62
	) -- 62
	check( -- 63
		"blend-plateau", -- 63
		openingBlend(WideFrames) == 0, -- 63
		"全景段结束仍是 0" -- 63
	) -- 63
	local mid = openingBlend(WideFrames + FocusFrames * 0.5) -- 64
	check( -- 65
		"blend-mid", -- 65
		mid > 0.4 and mid < 0.6, -- 65
		("中点 " .. __TS__NumberToFixed(mid, 3)) .. " 应接近 0.5" -- 65
	) -- 65
	check( -- 66
		"blend-one", -- 66
		openingBlend(WideFrames + FocusFrames) == 1, -- 66
		"聚焦结束 = 1" -- 66
	) -- 66
	check( -- 67
		"blend-hold", -- 67
		openingBlend(TotalFrames) == 1, -- 67
		"停留段末尾仍是 1" -- 67
	) -- 67
	check( -- 68
		"blend-return", -- 68
		openingBlend(TotalFrames + PullBackFrames) == 0, -- 68
		"拉回结束回到 0" -- 68
	) -- 68
	check( -- 69
		"blend-return-stay", -- 69
		openingBlend(TotalFrames + PullBackFrames * 3) == 0, -- 69
		"拉回后一直保持 0" -- 69
	) -- 69
	local mono = true -- 70
	local prev = -1 -- 71
	do -- 71
		local f = WideFrames -- 72
		while f <= WideFrames + FocusFrames do -- 72
			local v = openingBlend(f) -- 73
			if v < prev - 1e-9 then -- 73
				mono = false -- 74
			end -- 74
			prev = v -- 75
			f = f + 10 -- 72
		end -- 72
	end -- 72
	check("blend-monotonic-in", mono, "聚焦段单调不减") -- 77
	mono = true -- 78
	prev = 2 -- 79
	do -- 79
		local f = TotalFrames -- 80
		while f <= TotalFrames + PullBackFrames do -- 80
			local v = openingBlend(f) -- 81
			if v > prev + 1e-9 then -- 81
				mono = false -- 82
			end -- 82
			prev = v -- 83
			f = f + 10 -- 80
		end -- 80
	end -- 80
	check("blend-monotonic-out", mono, "拉回段单调不增") -- 85
end -- 61
--- 3) 站点表：轨道严格外扩、模型名非空、地球下标合法。
local function testStations() -- 89
	local ordered = true -- 90
	do -- 90
		local i = 1 -- 91
		while i < #Stations do -- 91
			if Stations[i + 1].orbit <= Stations[i].orbit then -- 91
				ordered = false -- 92
			end -- 92
			i = i + 1 -- 91
		end -- 91
	end -- 91
	check("stations-ordered", ordered, "轨道半径必须由内到外严格递增（否则全景里行星会互相穿）") -- 94
	check( -- 95
		"stations-earth-index", -- 95
		EarthStationIndex >= 0 and EarthStationIndex < #Stations, -- 95
		"地球下标 " .. tostring(EarthStationIndex) -- 95
	) -- 95
	check("stations-earth-model", Stations[EarthStationIndex + 1].model == "Planet_Earth", "聚焦目标必须是地球") -- 96
	local named = true -- 97
	for ____, st in ipairs(Stations) do -- 98
		if #st.model < 3 then -- 98
			named = false -- 99
		end -- 99
	end -- 99
	check("stations-named", named, "每站都要有模型名") -- 101
	local outside = stationPlane(-1) -- 102
	check("station-out-of-range", outside.x == 0 and outside.y == 0, "越界下标返回原点，不抛错") -- 103
	local earth = stationPlane(EarthStationIndex) -- 104
	local r = math.sqrt(earth.x * earth.x + earth.y * earth.y) -- 105
	check( -- 106
		"station-radius", -- 106
		math.abs(r - Stations[EarthStationIndex + 1].orbit) < 1e-9, -- 106
		("地球到太阳 " .. __TS__NumberToFixed(r, 3)) .. " 应等于轨道半径" -- 106
	) -- 106
end -- 89
--- 4) 机位：全景距离 / 特写距离 / 始终在黄道面上方 / 注视点跟着混合走。
local function testPose() -- 110
	local earth = stationPlane(EarthStationIndex) -- 111
	local p0 = openingPose(0, earth) -- 112
	local d0 = dist3(p0.eye, p0.target) -- 113
	check( -- 115
		"pose-wide-distance", -- 115
		math.abs(d0 - 245) < 0.01, -- 115
		("第 0 帧距离 " .. __TS__NumberToFixed(d0, 2)) .. " 应为 245" -- 115
	) -- 115
	check( -- 116
		"pose-wide-target", -- 116
		dist3( -- 116
			p0.target, -- 116
			Vec3(0, 0, 0) -- 116
		) < 1e-9, -- 116
		"全景注视点是太阳" -- 116
	) -- 116
	local p1 = openingPose(TotalFrames, earth) -- 117
	local d1 = dist3(p1.eye, p1.target) -- 118
	check( -- 119
		"pose-close-distance", -- 119
		math.abs(d1 - 22) < 0.01, -- 119
		("停留段距离 " .. __TS__NumberToFixed(d1, 2)) .. " 应为 22" -- 119
	) -- 119
	local t1 = p1.target -- 120
	local earthWorldDist = math.sqrt((t1.x - earth.x) * (t1.x - earth.x) + (t1.z - earth.y) * (t1.z - earth.y)) -- 121
	check("pose-close-target", earthWorldDist < 0.001, "特写注视点落在地球上") -- 122
	local above = true -- 123
	do -- 123
		local f = 0 -- 124
		while f <= TotalFrames + PullBackFrames do -- 124
			local p = openingPose(f, earth) -- 125
			if p.eye.y <= p.target.y then -- 125
				above = false -- 126
			end -- 126
			f = f + 20 -- 124
		end -- 124
	end -- 124
	check("pose-above-plane", above, "相机必须始终在黄道面之上（否则全景会变成仰视）") -- 128
end -- 110
--- 5) 探测器入轨：绕地球、半径恒定、角速度恒定、切线速度垂直于半径。
local function testProbeOrbit() -- 132
	local earth = stationPlane(EarthStationIndex) -- 133
	local radiusOk = true -- 134
	do -- 134
		local f = 0 -- 135
		while f <= TotalFrames do -- 135
			local p = probeOrbitPos(f, earth) -- 136
			local dx = p.x - earth.x -- 137
			local dy = p.y - earth.y -- 138
			local r = math.sqrt(dx * dx + dy * dy) -- 139
			if math.abs(r - ProbeOrbitRadius) > 1e-9 then -- 139
				radiusOk = false -- 140
			end -- 140
			f = f + 30 -- 135
		end -- 135
	end -- 135
	check( -- 142
		"probe-orbit-radius", -- 142
		radiusOk, -- 142
		("每一帧都在半径 " .. __TS__NumberToFixed(ProbeOrbitRadius, 2)) .. " 的圆上" -- 142
	) -- 142
	local p0 = probeOrbitPos(0, earth) -- 144
	local v0 = probeOrbitVel(0) -- 145
	local rx = p0.x - earth.x -- 146
	local ry = p0.y - earth.y -- 147
	check( -- 148
		"probe-velocity-perpendicular", -- 148
		math.abs(rx * v0.x + ry * v0.y) < 1e-9, -- 148
		"速度必须沿切线（与半径垂直）" -- 148
	) -- 148
	local speed = math.sqrt(v0.x * v0.x + v0.y * v0.y) -- 149
	check("probe-velocity-nonzero", speed > 0.000001, "速度不能为 0（否则朝向计算会退化）") -- 150
	local a0 = math.atan( -- 153
		probeOrbitPos(0, earth).y - earth.y, -- 153
		probeOrbitPos(0, earth).x - earth.x -- 153
	) -- 153
	local a1 = math.atan( -- 154
		probeOrbitPos(60, earth).y - earth.y, -- 154
		probeOrbitPos(60, earth).x - earth.x -- 154
	) -- 154
	local a2 = math.atan( -- 155
		probeOrbitPos(120, earth).y - earth.y, -- 155
		probeOrbitPos(120, earth).x - earth.x -- 155
	) -- 155
	local step1 = a1 - a0 -- 156
	local step2 = a2 - a1 -- 157
	check( -- 158
		"probe-orbit-uniform", -- 158
		math.abs(step1 - step2) < 1e-9, -- 158
		"公转角速度恒定" -- 158
	) -- 158
	local total = (a2 - a0) / 120 * TotalFrames -- 160
	check( -- 161
		"probe-orbit-visible", -- 161
		math.abs(total) > 3, -- 161
		("整个开场转过 " .. __TS__NumberToFixed( -- 161
			math.abs(total) * 180 / math.pi, -- 161
			0 -- 161
		)) .. "°（应 > 170°）" -- 161
	) -- 161
end -- 132
function ____exports.runTests() -- 164
	testPhases() -- 165
	testBlend() -- 166
	testStations() -- 167
	testPose() -- 168
	testProbeOrbit() -- 169
	local out = {} -- 171
	out[#out + 1] = #failures == 0 and "passed" or "failed" -- 172
	out[#out + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 173
	local limit = #failures < 12 and #failures or 12 -- 174
	do -- 174
		local i = 0 -- 175
		while i < limit do -- 175
			out[#out + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 175
			i = i + 1 -- 175
		end -- 175
	end -- 175
	return table.concat(out, "\n") -- 176
end -- 164
return ____exports -- 164