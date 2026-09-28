-- [ts]: ScaleTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Scale = require("game.Scale") -- 12
local EarthGm = ____Scale.EarthGm -- 13
local EarthRadius = ____Scale.EarthRadius -- 13
local GmFactor = ____Scale.GmFactor -- 13
local KmPerSecPerUnit = ____Scale.KmPerSecPerUnit -- 13
local KmPerUnit = ____Scale.KmPerUnit -- 13
local MoonGm = ____Scale.MoonGm -- 14
local MoonOrbitRadius = ____Scale.MoonOrbitRadius -- 14
local MoonRadius = ____Scale.MoonRadius -- 14
local RealSpeedAtAu = ____Scale.RealSpeedAtAu -- 14
local SecPerGameSec = ____Scale.SecPerGameSec -- 14
local SunGm = ____Scale.SunGm -- 14
local SunRadius = ____Scale.SunRadius -- 15
local UnitsPerAu = ____Scale.UnitsPerAu -- 15
local circularSpeed = ____Scale.circularSpeed -- 15
local escapeSpeed = ____Scale.escapeSpeed -- 15
local hillRadius = ____Scale.hillRadius -- 15
local period = ____Scale.period -- 15
local trueGm = ____Scale.trueGm -- 16
local trueOrbit = ____Scale.trueOrbit -- 16
local trueRadius = ____Scale.trueRadius -- 16
local failures = {} -- 24
local checks = 0 -- 25
local function check(name, ok, detail) -- 27
	checks = checks + 1 -- 28
	if not ok then -- 28
		failures[#failures + 1] = {name = name, detail = detail} -- 29
	end -- 29
end -- 27
--- 科学计数法字符串。**不能写 toExponential** —— tstl 不支持（手册 §7.1 的同族坑：
-- Math.hypot / Math.imul / toExponential，编译期不报错、运行时报错）。
local function sci(x) -- 36
	if x == 0 then -- 36
		return "0" -- 37
	end -- 37
	local e = 0 -- 38
	local m = x < 0 and -x or x -- 39
	while m >= 10 do -- 39
		m = m / 10 -- 40
		e = e + 1 -- 40
	end -- 40
	while m < 1 do -- 40
		m = m * 10 -- 41
		e = e - 1 -- 41
	end -- 41
	return (((x < 0 and "-" or "") .. __TS__NumberToFixed(m, 4)) .. "e") .. tostring(e) -- 42
end -- 36
--- 相对误差判定（跨 10 个数量级的尺度量，绝对误差没有意义）。
local function near(name, got, want, relTol) -- 46
	local d = math.abs(got - want) -- 47
	local tol = math.abs(want) * relTol -- 48
	check( -- 49
		name, -- 49
		d <= tol, -- 49
		(((((("got=" .. tostring(got)) .. " want=") .. tostring(want)) .. " |d|=") .. sci(d)) .. " tol=") .. sci(tol) -- 49
	) -- 49
end -- 46
--- 1) 尺度常量：三个锚点必须与真实天文数据自洽，且量纲关系成立。
local function testConstants() -- 53
	near("km-per-unit", KmPerUnit, 149597870.7 / 80, 1e-12) -- 54
	check( -- 55
		"units-per-au", -- 55
		UnitsPerAu == 80, -- 55
		"UnitsPerAu=" .. tostring(UnitsPerAu) -- 55
	) -- 55
	near("real-speed-1au", RealSpeedAtAu, 29.7847, 0.0001) -- 56
	near("km-per-sec-per-unit", KmPerSecPerUnit, 29.7846918317 / 30, 1e-9) -- 57
	near("sec-per-game-sec", SecPerGameSec, 1883491, 0.00001) -- 58
	near("gm-factor", GmFactor, 5.425264e-7, 0.00001) -- 59
	near("gm-factor-is-tau2-over-l3", GmFactor, SecPerGameSec * SecPerGameSec / (KmPerUnit * KmPerUnit * KmPerUnit), 1e-12) -- 61
	check( -- 63
		"sec-per-game-sec-is-21-8-days", -- 63
		math.abs(SecPerGameSec / 86400 - 21.8) < 0.05, -- 63
		("1 game-sec = " .. __TS__NumberToFixed(SecPerGameSec / 86400, 3)) .. " days (want ~21.8)" -- 64
	) -- 64
end -- 53
--- 2) 换算函数：正向、往返、退化输入。
local function testConversions() -- 68
	near( -- 69
		"true-radius-earth", -- 69
		trueRadius(6371), -- 69
		0.003407, -- 69
		0.00001 -- 69
	) -- 69
	near( -- 70
		"true-radius-sun", -- 70
		trueRadius(695700), -- 70
		0.372037, -- 70
		0.00001 -- 70
	) -- 70
	near( -- 71
		"true-gm-earth", -- 71
		trueGm(398600.4418), -- 71
		0.2162513, -- 71
		0.000001 -- 71
	) -- 71
	near( -- 72
		"true-orbit-1au", -- 72
		trueOrbit(1), -- 72
		80, -- 72
		1e-12 -- 72
	) -- 72
	near( -- 73
		"true-orbit-jupiter", -- 73
		trueOrbit(5.202887), -- 73
		416.231, -- 73
		0.000001 -- 73
	) -- 73
	near( -- 74
		"roundtrip-radius", -- 74
		trueRadius(6371) * KmPerUnit, -- 74
		6371, -- 74
		1e-9 -- 74
	) -- 74
	near( -- 75
		"roundtrip-gm", -- 75
		trueGm(132712440018) / GmFactor, -- 75
		132712440018, -- 75
		1e-9 -- 75
	) -- 75
	check( -- 76
		"degenerate-radius-zero", -- 76
		trueRadius(0) == 0, -- 76
		"trueRadius(0)=" .. tostring(trueRadius(0)) -- 76
	) -- 76
end -- 68
--- 3) 太阳：trueGm 必须**恰好**落回归正前手填的 72000 —— 病根诊断的落点。
local function testSun() -- 80
	near("sun-gm-is-72000", SunGm, 72000, 1e-9) -- 81
	near("sun-radius", SunRadius, 0.3720374, 0.00001) -- 82
	check( -- 84
		"sun-radius-shrunk-70x", -- 84
		SunRadius < 28 / 70, -- 84
		"sunRadius=" .. __TS__NumberToFixed(SunRadius, 4) -- 84
	) -- 84
	near( -- 86
		"anchor-v-circ-80-is-30", -- 86
		circularSpeed(SunGm, 80), -- 86
		30, -- 86
		1e-9 -- 86
	) -- 86
	near( -- 87
		"earth-orbit-speed-anchor", -- 87
		circularSpeed( -- 87
			SunGm, -- 87
			trueOrbit(1.00000011) -- 87
		), -- 87
		30, -- 87
		0.000001 -- 87
	) -- 87
end -- 80
--- 4) 开普勒第三定律：周期必须与真实行星周期同构（比值 = a^1.5）。
local function testKepler() -- 91
	local earthA = trueOrbit(1.00000011) -- 92
	local jupA = trueOrbit(5.202887) -- 93
	near( -- 94
		"earth-period", -- 94
		period(earthA, SunGm), -- 94
		16.7552, -- 94
		0.0001 -- 94
	) -- 94
	near( -- 95
		"venus-period", -- 95
		period( -- 95
			trueOrbit(0.72333199), -- 95
			SunGm -- 95
		), -- 95
		10.3075, -- 95
		0.0001 -- 95
	) -- 95
	near( -- 96
		"jupiter-period", -- 96
		period(jupA, SunGm), -- 96
		198.8452, -- 96
		0.0001 -- 96
	) -- 96
	near( -- 97
		"saturn-period", -- 97
		period( -- 97
			trueOrbit(9.53667594), -- 97
			SunGm -- 97
		), -- 97
		493.4511, -- 97
		0.0001 -- 97
	) -- 97
	near( -- 98
		"uranus-period", -- 98
		period( -- 98
			trueOrbit(19.18916464), -- 98
			SunGm -- 98
		), -- 98
		1408.4217, -- 98
		0.0001 -- 98
	) -- 98
	near( -- 99
		"neptune-period", -- 99
		period( -- 99
			trueOrbit(30.06992276), -- 99
			SunGm -- 99
		), -- 99
		2762.7849, -- 99
		0.0001 -- 99
	) -- 99
	near( -- 103
		"kepler-ratio-jupiter-over-earth", -- 103
		period(jupA, SunGm) / period(earthA, SunGm), -- 103
		(jupA / earthA) ^ 1.5, -- 103
		1e-9 -- 103
	) -- 103
	near( -- 104
		"kepler-ratio-neptune-over-earth", -- 104
		period( -- 104
			trueOrbit(30.06992276), -- 104
			SunGm -- 104
		) / period(earthA, SunGm), -- 104
		(trueOrbit(30.06992276) / earthA) ^ 1.5, -- 105
		1e-9 -- 105
	) -- 105
	near( -- 107
		"moon-period-around-earth", -- 107
		period(MoonOrbitRadius, EarthGm), -- 107
		1.2593, -- 107
		0.0001 -- 107
	) -- 107
	near( -- 108
		"moon-orbits-per-earth-year", -- 108
		period(earthA, SunGm) / period(MoonOrbitRadius, EarthGm), -- 108
		13.31, -- 108
		0.002 -- 108
	) -- 108
	check( -- 109
		"real-moon-orbits-13-4", -- 109
		math.abs(period(earthA, SunGm) / period(MoonOrbitRadius, EarthGm) - 13.37) < 0.2, -- 109
		("got=" .. __TS__NumberToFixed( -- 110
			period(earthA, SunGm) / period(MoonOrbitRadius, EarthGm), -- 110
			3 -- 110
		)) .. " (真实 13.37)" -- 110
	) -- 110
	check( -- 111
		"degenerate-period-zero", -- 111
		period(0, SunGm) == 0 and period(80, 0) == 0, -- 111
		"period(0,mu)/period(a,0) 必须为 0" -- 111
	) -- 111
end -- 91
--- 5) 判别力：把 KeplerK 那条错公式拿来对照，差 42.7 倍必须**被测出来**。
local function testKeplerKIsGone() -- 115
	local earthA = trueOrbit(1.00000011) -- 116
	local wrong = earthA ^ 1.5 -- 117
	local right = period(earthA, SunGm) -- 118
	local ratio = wrong / right -- 119
	check( -- 120
		"kepler-k-would-be-42-7x-off", -- 120
		math.abs(ratio - 42.7) < 0.5, -- 120
		("ratio=" .. __TS__NumberToFixed(ratio, 2)) .. " (want ~42.7)" -- 120
	) -- 120
	check( -- 121
		"kepler-k-not-reintroduced", -- 121
		right < 20, -- 121
		("T_earth=" .. __TS__NumberToFixed(right, 3)) .. "s (KeplerK 会让它是 715s)" -- 121
	) -- 121
end -- 115
--- 6) 希尔球与逃逸速度：L1「探测器绕地球」的物理可行性判据。
local function testHillAndEscape() -- 125
	local earthA = trueOrbit(1.00000011) -- 126
	near( -- 127
		"hill-radius-earth", -- 127
		hillRadius(earthA, EarthGm, SunGm), -- 127
		0.80031, -- 127
		0.00001 -- 127
	) -- 127
	near( -- 128
		"hill-radius-ratio", -- 128
		hillRadius(earthA, EarthGm, SunGm) / earthA, -- 128
		0.010004, -- 128
		0.0001 -- 128
	) -- 128
	local parking = EarthRadius + 200 / KmPerUnit -- 132
	local frac = parking / hillRadius(earthA, EarthGm, SunGm) -- 133
	check( -- 134
		"parking-inside-hill", -- 134
		frac > 0.001 and frac < 0.01, -- 134
		("r/r_H=" .. __TS__NumberToFixed(frac, 5)) .. " (want 0.0044)" -- 134
	) -- 134
	near( -- 136
		"parking-period", -- 136
		period(parking, EarthGm), -- 136
		0.00281446, -- 136
		0.00001 -- 136
	) -- 136
	near( -- 137
		"parking-v-circ", -- 137
		circularSpeed(EarthGm, parking), -- 137
		7.8448, -- 137
		0.001 -- 137
	) -- 137
	near( -- 138
		"parking-v-escape", -- 138
		escapeSpeed(EarthGm, parking), -- 138
		11.0942, -- 138
		0.001 -- 138
	) -- 138
	near( -- 139
		"escape-is-sqrt2-circular", -- 139
		escapeSpeed(EarthGm, parking) / circularSpeed(EarthGm, parking), -- 139
		1.4142135623730951, -- 139
		1e-12 -- 139
	) -- 139
	near( -- 141
		"moon-orbit-v-circ", -- 141
		circularSpeed(EarthGm, MoonOrbitRadius), -- 141
		1.02566, -- 141
		0.0001 -- 141
	) -- 141
	check( -- 142
		"degenerate-hill-zero", -- 142
		hillRadius(80, 0, SunGm) == 0 and hillRadius(0, EarthGm, SunGm) == 0, -- 142
		"hillRadius 退化输入必须为 0" -- 142
	) -- 142
end -- 125
--- 7) 派生常量与真实数据表一致（防止有人在表里改了数、派生值没跟着走）。
local function testDerived() -- 146
	near("earth-gm", EarthGm, 0.2162513, 0.000001) -- 147
	near("earth-radius", EarthRadius, 0.003407, 0.00001) -- 148
	near("moon-gm", MoonGm, 0.0026599, 0.00001) -- 149
	near("moon-radius", MoonRadius, 0.0009291, 0.00001) -- 150
	near("moon-orbit-radius", MoonOrbitRadius, 0.2055644, 0.000001) -- 151
	near("moon-orbit-over-earth-radius", MoonOrbitRadius / EarthRadius, 60.34, 0.001) -- 153
	near( -- 155
		"jupiter-radius-over-earth", -- 155
		trueRadius(69911) / EarthRadius, -- 155
		10.97, -- 155
		0.002 -- 155
	) -- 155
	near( -- 156
		"saturn-radius-over-earth", -- 156
		trueRadius(58232) / EarthRadius, -- 156
		9.14, -- 156
		0.002 -- 156
	) -- 156
	near("sun-radius-over-earth", SunRadius / EarthRadius, 109.2, 0.002) -- 157
end -- 146
function ____exports.runTests() -- 160
	testConstants() -- 161
	testConversions() -- 162
	testSun() -- 163
	testKepler() -- 164
	testKeplerKIsGone() -- 165
	testHillAndEscape() -- 166
	testDerived() -- 167
	local lines = {} -- 169
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 170
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 171
	local limit = #failures < 12 and #failures or 12 -- 172
	do -- 172
		local i = 0 -- 173
		while i < limit do -- 173
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 174
			i = i + 1 -- 173
		end -- 173
	end -- 173
	return table.concat( -- 176
		lines, -- 176
		string.char(10) or "," -- 176
	) -- 176
end -- 160
return ____exports -- 160