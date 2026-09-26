-- [ts]: LevelData.ts
local ____exports = {} -- 1
local applyScalesLocal -- 1
local ____Gravity = require("game.Gravity") -- 28
local bodyPositionAt = ____Gravity.bodyPositionAt -- 28
local distance = ____Gravity.distance -- 28
local ____Config = require("game.Config") -- 29
local GravityScale = ____Config.GravityScale -- 29
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 29
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 396
	local out = {} -- 397
	for ____, b in ipairs(bodies) do -- 398
		out[#out + 1] = { -- 399
			gm = b.gm * gravityScale, -- 400
			radius = b.radius, -- 401
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 402
			orbitRadius = b.orbitRadius, -- 403
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 404
			phase0 = b.phase0, -- 405
			orbitDirection = b.orbitDirection -- 406
		} -- 406
	end -- 406
	return out -- 409
end -- 409
--- 太阳的引力强度（`v_circ(80) = sqrt(SunGm/80) ≈ 30`，逃逸速度 42.4）。
____exports.SunGm = 72000 -- 102
--- 太阳的撞毁半径（视觉上也用这个值，模型 k 未知时按单位球算）。
____exports.SunRadius = 7 -- 105
--- 开普勒周期系数：`T = KeplerK · r^1.5`（秒）。
-- 
-- 相对快慢 = 真实开普勒（内快外慢），绝对速率被压缩 —— `KeplerK = 1` 相当于把真实值除以 42.7
-- （真实：`T = 2π·r^1.5/sqrt(SunGm) = 0.0234·r^1.5`）。这样飞行十几秒里行星只挪几度。
____exports.KeplerK = 1 -- 113
--- 开普勒周期（秒）：r 单位是平面单位。r <= 0 返回 0（静止）。
function ____exports.keplerPeriod(orbitRadius) -- 116
	if orbitRadius <= 0 then -- 116
		return 0 -- 117
	end -- 117
	return ____exports.KeplerK * orbitRadius ^ 1.5 -- 118
end -- 116
--- 度 → 弧度（关卡数据里写角度比写弧度好读）。
local function deg(d) -- 122
	return d * math.pi / 180 -- 123
end -- 122
local R_MOON = 1 -- 127
local R_VENUS = 1.72 -- 128
local R_EARTH = 1.76 -- 129
local R_JUPITER = 4.63 -- 130
local R_SATURN = 4.3 -- 131
local R_URANUS = 3.04 -- 132
local R_NEPTUNE = 3 -- 133
--- 巡航轨道半径（压缩太阳系：顺序真实、比例压缩）—— 一律绕原点（太阳）。
local ORBIT = { -- 136
	venus = 55, -- 136
	earth = 80, -- 136
	jupiter = 105, -- 136
	saturn = 135, -- 136
	uranus = 165, -- 136
	neptune = 195 -- 136
} -- 136
--- 掠过环的容差（flyby）：比本体大 13 左右 —— 远距离飞行要有"够得着"的手感。
local FLYBY_PAD = 13 -- 139
--- 在飞行采样点中找第一个进入目标容差的索引。
-- 
-- 目标行星在移动，所以逐点用 `t = t0 + i * dt` 时的行星位置判定（`t0` = 发射时刻）。
-- `dt` 必须是**采样点之间的有效步长**（采样间隔 N 步时传 `N * PhysicsStep`）。
-- 返回 -1 表示未到达。
function ____exports.goalWaypoints(goal) -- 148
	if goal.chain ~= nil then -- 148
		return goal.chain -- 149
	end -- 149
	if goal.kind == "planet" then -- 149
		return {{planetIndex = goal.planetIndex, tolerance = goal.tolerance}} -- 150
	end -- 150
	return {} -- 151
end -- 148
--- 顺序航线的进度：返回在 points[0..upto] 里**依次**掠过的航点数与最后一个命中索引。
-- 
-- 一次线性扫描：航点必须按顺序命中，且后一个必须出现在更晚的采样点上
-- （"先到土星再路过木星"不算数）。upto 用于飞行中查询"到哪一段了"（画环的明暗）。
function ____exports.waypointProgress(points, bodies, goal, dt, t0, upto) -- 160
	local wps = ____exports.goalWaypoints(goal) -- 168
	local start = t0 ~= nil and t0 or 0 -- 169
	local limit = #points - 1 -- 170
	if upto ~= nil and upto >= 0 and upto < limit then -- 170
		limit = upto -- 171
	end -- 171
	local next = 0 -- 172
	local lastIndex = -1 -- 173
	do -- 173
		local i = 0 -- 174
		while i <= limit and next < #wps do -- 174
			local w = wps[next + 1] -- 175
			local body = bodies[w.planetIndex + 1] -- 176
			if body == nil then -- 176
				return {passed = 0, lastIndex = -1} -- 177
			end -- 177
			local gp = bodyPositionAt(body, start + i * dt) -- 178
			if distance(points[i + 1], gp) < w.tolerance then -- 178
				next = next + 1 -- 180
				lastIndex = i -- 181
			end -- 181
			i = i + 1 -- 174
		end -- 174
	end -- 174
	return {passed = next, lastIndex = lastIndex} -- 184
end -- 160
function ____exports.findGoalIndex(points, bodies, goal, dt, t0) -- 187
	local wps = ____exports.goalWaypoints(goal) -- 188
	if #wps == 0 then -- 188
		return -1 -- 189
	end -- 189
	local st = ____exports.waypointProgress( -- 190
		points, -- 190
		bodies, -- 190
		goal, -- 190
		dt, -- 190
		t0 -- 190
	) -- 190
	return st.passed >= #wps and st.lastIndex or -1 -- 191
end -- 187
--- 太阳（除 L1 外每关的第 0 号天体）。
local function sun() -- 199
	return { -- 200
		gm = ____exports.SunGm, -- 200
		radius = ____exports.SunRadius, -- 200
		orbitCenter = {x = 0, y = 0}, -- 200
		orbitRadius = 0, -- 200
		orbitPeriod = 0, -- 200
		phase0 = 0, -- 200
		orbitDirection = 1 -- 200
	} -- 200
end -- 199
--- 太阳的视觉（亮黄，模型 Sun.glb）。
local function sunVisual() -- 204
	return { -- 205
		r = 1, -- 205
		g = 0.9, -- 205
		b = 0.62, -- 205
		displayRadius = ____exports.SunRadius, -- 205
		ring = false, -- 205
		model = "Sun", -- 205
		emissive = {r = 0.95, g = 0.72, b = 0.3} -- 205
	} -- 205
end -- 204
--- 绕日公转的行星（S3.7：圆心 = 太阳 = 原点）。
local function orbiter(gm, radius, orbitRadius, phaseDeg) -- 209
	return { -- 210
		gm = gm, -- 211
		radius = radius, -- 211
		orbitCenter = {x = 0, y = 0}, -- 212
		orbitRadius = orbitRadius, -- 213
		orbitPeriod = ____exports.keplerPeriod(orbitRadius), -- 214
		phase0 = deg(phaseDeg), -- 215
		orbitDirection = 1 -- 216
	} -- 216
end -- 209
local LEVELS = { -- 220
	{ -- 221
		id = 1, -- 222
		title = "出发", -- 223
		brief = "航行日志 · 第 1 天：离开地球。这一段路很干净，没有大天体捣乱 —— 先把拖拽瞄准练熟。月球在正前方。", -- 224
		probeStart = {x = 0, y = 40}, -- 225
		planets = {{ -- 226
			gm = 0, -- 228
			radius = R_MOON, -- 228
			orbitCenter = {x = 0, y = -70}, -- 228
			orbitRadius = 0, -- 228
			orbitPeriod = 0, -- 228
			phase0 = 0, -- 228
			orbitDirection = 1 -- 228
		}}, -- 228
		visuals = {{ -- 230
			r = 0.56, -- 231
			g = 0.56, -- 231
			b = 0.6, -- 231
			displayRadius = R_MOON, -- 231
			ring = false -- 231
		}}, -- 231
		goal = {kind = "planet", planetIndex = 0, tolerance = 14}, -- 233
		escapeRadius = 700, -- 234
		maxSteps = 1200, -- 235
		homeRadius = 1.75 -- 236
	}, -- 236
	{ -- 238
		id = 2, -- 239
		title = "修正", -- 240
		brief = "航行日志 · 第 12 天：太阳开始拽你了。别直着飞 —— 向内会加速，航线也会被掰弯。目标是掠过金星。", -- 241
		probeStart = {x = 0, y = ORBIT.earth}, -- 242
		planets = { -- 243
			sun(), -- 244
			orbiter(2600, R_VENUS, ORBIT.venus, 180) -- 246
		}, -- 246
		visuals = { -- 248
			sunVisual(), -- 249
			{ -- 250
				r = 0.9, -- 250
				g = 0.78, -- 250
				b = 0.55, -- 250
				displayRadius = R_VENUS, -- 250
				ring = false, -- 250
				model = "Planet_Venus" -- 250
			} -- 250
		}, -- 250
		goal = {kind = "planet", planetIndex = 1, tolerance = R_VENUS + FLYBY_PAD}, -- 252
		escapeRadius = 700, -- 253
		maxSteps = 1500, -- 254
		homeRadius = 1.6 -- 255
	}, -- 255
	{ -- 257
		id = 3, -- 258
		title = "弹弓", -- 259
		brief = "航行日志 · 第 2 年：木星在外圈。想省力就从它背后绕过去 —— 它的引力会把你甩向土星。", -- 260
		probeStart = {x = 0, y = ORBIT.earth}, -- 261
		planets = { -- 262
			sun(), -- 263
			orbiter(4000, R_JUPITER, ORBIT.jupiter, 195.5), -- 266
			orbiter(0, R_SATURN, ORBIT.saturn, 198) -- 268
		}, -- 268
		visuals = { -- 270
			sunVisual(), -- 271
			{ -- 272
				r = 0.85, -- 272
				g = 0.72, -- 272
				b = 0.5, -- 272
				displayRadius = R_JUPITER, -- 272
				ring = false, -- 272
				model = "Planet_Jupiter" -- 272
			}, -- 272
			{ -- 273
				r = 0.75, -- 273
				g = 0.7, -- 273
				b = 0.6, -- 273
				displayRadius = R_SATURN, -- 273
				ring = true, -- 273
				model = "Planet_Saturn" -- 273
			} -- 273
		}, -- 273
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + 8, chain = {{planetIndex = 1, tolerance = R_JUPITER + 8, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 45, label = "土星"}}}, -- 276
		escapeRadius = 700, -- 283
		maxSteps = 2400, -- 284
		homeRadius = 1.45 -- 285
	}, -- 285
	{ -- 287
		id = 4, -- 288
		title = "窗口", -- 289
		brief = "航行日志 · 第 3 年：木星一直在绕太阳走。挑一个它正好在你航线上的日期起飞 —— 拖动时间轴，看它挪位置。", -- 290
		probeStart = {x = 0, y = ORBIT.earth}, -- 291
		planets = { -- 292
			sun(), -- 293
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 315.5), -- 295
			orbiter(0, R_SATURN, ORBIT.saturn, 288) -- 296
		}, -- 296
		visuals = { -- 298
			sunVisual(), -- 299
			{ -- 300
				r = 0.85, -- 300
				g = 0.72, -- 300
				b = 0.5, -- 300
				displayRadius = R_JUPITER, -- 300
				ring = false, -- 300
				model = "Planet_Jupiter" -- 300
			}, -- 300
			{ -- 301
				r = 0.75, -- 301
				g = 0.7, -- 301
				b = 0.6, -- 301
				displayRadius = R_SATURN, -- 301
				ring = true, -- 301
				model = "Planet_Saturn" -- 301
			} -- 301
		}, -- 301
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 30, label = "土星"}}}, -- 304
		escapeRadius = 700, -- 311
		maxSteps = 1800, -- 312
		homeRadius = 1.35, -- 313
		timeWindow = {span = ____exports.keplerPeriod(ORBIT.jupiter) / 3} -- 316
	}, -- 316
	{ -- 318
		id = 5, -- 319
		title = "大巡游", -- 320
		brief = "航行日志 · 第 5 年：一次点火，四颗巨行星。木星改向、土星续航、天王星微调 —— 最后到海王星。", -- 321
		probeStart = {x = 0, y = ORBIT.earth}, -- 322
		planets = { -- 323
			sun(), -- 324
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 195.5), -- 327
			orbiter(2000, R_SATURN, ORBIT.saturn, 203.1), -- 328
			orbiter(1200, R_URANUS, ORBIT.uranus, 209.7), -- 329
			orbiter(800, R_NEPTUNE, ORBIT.neptune, 216.4) -- 330
		}, -- 330
		visuals = { -- 332
			sunVisual(), -- 333
			{ -- 334
				r = 0.85, -- 334
				g = 0.72, -- 334
				b = 0.5, -- 334
				displayRadius = R_JUPITER, -- 334
				ring = false, -- 334
				model = "Planet_Jupiter" -- 334
			}, -- 334
			{ -- 335
				r = 0.75, -- 335
				g = 0.7, -- 335
				b = 0.6, -- 335
				displayRadius = R_SATURN, -- 335
				ring = true, -- 335
				model = "Planet_Saturn" -- 335
			}, -- 335
			{ -- 336
				r = 0.62, -- 336
				g = 0.82, -- 336
				b = 0.86, -- 336
				displayRadius = R_URANUS, -- 336
				ring = false, -- 336
				model = "Planet_Uranus" -- 336
			}, -- 336
			{ -- 337
				r = 0.34, -- 337
				g = 0.5, -- 337
				b = 0.86, -- 337
				displayRadius = R_NEPTUNE, -- 337
				ring = false, -- 337
				model = "Planet_Neptune" -- 337
			} -- 337
		}, -- 337
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 26, label = "土星"}, {planetIndex = 3, tolerance = R_URANUS + 30, label = "天王星"}, {planetIndex = 4, tolerance = R_NEPTUNE + 34, label = "海王星"}}}, -- 340
		escapeRadius = 700, -- 349
		maxSteps = 2400, -- 350
		homeRadius = 1.25 -- 351
	}, -- 351
	{ -- 353
		id = 6, -- 354
		title = "单程", -- 355
		brief = "航行日志 · 第 12 年：没有回程了。穿过四颗巨行星，飞出太阳系 —— 越过 260 单位就算离开。", -- 356
		probeStart = {x = 0, y = ORBIT.earth}, -- 357
		planets = { -- 358
			sun(), -- 359
			orbiter(9400, R_JUPITER, ORBIT.jupiter, 200), -- 360
			orbiter(7000, R_SATURN, ORBIT.saturn, 245), -- 361
			orbiter(3200, R_URANUS, ORBIT.uranus, 290), -- 362
			orbiter(2200, R_NEPTUNE, ORBIT.neptune, 335) -- 363
		}, -- 363
		visuals = { -- 365
			sunVisual(), -- 366
			{ -- 367
				r = 0.85, -- 367
				g = 0.72, -- 367
				b = 0.5, -- 367
				displayRadius = R_JUPITER, -- 367
				ring = false, -- 367
				model = "Planet_Jupiter" -- 367
			}, -- 367
			{ -- 368
				r = 0.75, -- 368
				g = 0.7, -- 368
				b = 0.6, -- 368
				displayRadius = R_SATURN, -- 368
				ring = true, -- 368
				model = "Planet_Saturn" -- 368
			}, -- 368
			{ -- 369
				r = 0.62, -- 369
				g = 0.82, -- 369
				b = 0.86, -- 369
				displayRadius = R_URANUS, -- 369
				ring = false, -- 369
				model = "Planet_Uranus" -- 369
			}, -- 369
			{ -- 370
				r = 0.34, -- 370
				g = 0.5, -- 370
				b = 0.86, -- 370
				displayRadius = R_NEPTUNE, -- 370
				ring = false, -- 370
				model = "Planet_Neptune" -- 370
			} -- 370
		}, -- 370
		goal = {kind = "escape", planetIndex = -1, tolerance = 0}, -- 373
		escapeRadius = 260, -- 374
		maxSteps = 2400, -- 375
		homeRadius = 1 -- 376
	} -- 376
} -- 376
--- 关卡总数。
function ____exports.levelCount() -- 381
	return #LEVELS -- 382
end -- 381
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 386
	return LEVELS[index + 1] -- 387
end -- 386
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 391
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 392
end -- 391
return ____exports -- 391