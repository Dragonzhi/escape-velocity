-- [ts]: LevelData.ts
local ____exports = {} -- 1
local applyScalesLocal -- 1
local ____Gravity = require("game.Gravity") -- 28
local bodyPositionAt = ____Gravity.bodyPositionAt -- 28
local distance = ____Gravity.distance -- 28
local ____Config = require("game.Config") -- 29
local GravityScale = ____Config.GravityScale -- 29
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 29
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 403
	local out = {} -- 404
	for ____, b in ipairs(bodies) do -- 405
		out[#out + 1] = { -- 406
			gm = b.gm * gravityScale, -- 407
			radius = b.radius, -- 408
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 409
			orbitRadius = b.orbitRadius, -- 410
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 411
			phase0 = b.phase0, -- 412
			orbitDirection = b.orbitDirection -- 413
		} -- 413
	end -- 413
	return out -- 416
end -- 416
--- 太阳的引力强度（`v_circ(80) = sqrt(SunGm/80) ≈ 30`，逃逸速度 42.4）。
____exports.SunGm = 72000 -- 102
--- 太阳的半径（撞毁半径 = 显示半径，尺寸公平性硬约束）。
-- 
-- ⚠️ 2026-09-26 用户参考图（docs/比例尺效果展示图.excalidraw）给的比值：
--   最内圈轨道 ≈ **1.9 个太阳半径**、太阳直径 ≈ 屏幕宽度的 0.38、行星 ≈ 太阳的 0.19。
--   原来取 7.0（轨道 = 7.9~27.9 个太阳半径）⇒ 太阳在画面里像一颗行星，"尺度很怪"的根因之一。
--   改成 28 之后：轨道 55/80/105/135/165/195 = 1.96/2.86/3.75/4.8/5.9/7.0 个太阳半径，与参考图一致。
____exports.SunRadius = 28 -- 112
--- 开普勒周期系数：`T = KeplerK · r^1.5`（秒）。
-- 
-- 相对快慢 = 真实开普勒（内快外慢），绝对速率被压缩 —— `KeplerK = 1` 相当于把真实值除以 42.7
-- （真实：`T = 2π·r^1.5/sqrt(SunGm) = 0.0234·r^1.5`）。这样飞行十几秒里行星只挪几度。
____exports.KeplerK = 1 -- 120
--- 开普勒周期（秒）：r 单位是平面单位。r <= 0 返回 0（静止）。
function ____exports.keplerPeriod(orbitRadius) -- 123
	if orbitRadius <= 0 then -- 123
		return 0 -- 124
	end -- 124
	return ____exports.KeplerK * orbitRadius ^ 1.5 -- 125
end -- 123
--- 度 → 弧度（关卡数据里写角度比写弧度好读）。
local function deg(d) -- 129
	return d * math.pi / 180 -- 130
end -- 129
local R_MOON = 1 -- 134
local R_VENUS = 1.72 -- 135
local R_EARTH = 1.76 -- 136
local R_JUPITER = 4.63 -- 137
local R_SATURN = 4.3 -- 138
local R_URANUS = 3.04 -- 139
local R_NEPTUNE = 3 -- 140
--- 巡航轨道半径（压缩太阳系：顺序真实、比例压缩）—— 一律绕原点（太阳）。
local ORBIT = { -- 143
	venus = 55, -- 143
	earth = 80, -- 143
	jupiter = 105, -- 143
	saturn = 135, -- 143
	uranus = 165, -- 143
	neptune = 195 -- 143
} -- 143
--- 掠过环的容差（flyby）：比本体大 13 左右 —— 远距离飞行要有"够得着"的手感。
local FLYBY_PAD = 13 -- 146
--- 在飞行采样点中找第一个进入目标容差的索引。
-- 
-- 目标行星在移动，所以逐点用 `t = t0 + i * dt` 时的行星位置判定（`t0` = 发射时刻）。
-- `dt` 必须是**采样点之间的有效步长**（采样间隔 N 步时传 `N * PhysicsStep`）。
-- 返回 -1 表示未到达。
function ____exports.goalWaypoints(goal) -- 155
	if goal.chain ~= nil then -- 155
		return goal.chain -- 156
	end -- 156
	if goal.kind == "planet" then -- 156
		return {{planetIndex = goal.planetIndex, tolerance = goal.tolerance}} -- 157
	end -- 157
	return {} -- 158
end -- 155
--- 顺序航线的进度：返回在 points[0..upto] 里**依次**掠过的航点数与最后一个命中索引。
-- 
-- 一次线性扫描：航点必须按顺序命中，且后一个必须出现在更晚的采样点上
-- （"先到土星再路过木星"不算数）。upto 用于飞行中查询"到哪一段了"（画环的明暗）。
function ____exports.waypointProgress(points, bodies, goal, dt, t0, upto) -- 167
	local wps = ____exports.goalWaypoints(goal) -- 175
	local start = t0 ~= nil and t0 or 0 -- 176
	local limit = #points - 1 -- 177
	if upto ~= nil and upto >= 0 and upto < limit then -- 177
		limit = upto -- 178
	end -- 178
	local next = 0 -- 179
	local lastIndex = -1 -- 180
	do -- 180
		local i = 0 -- 181
		while i <= limit and next < #wps do -- 181
			local w = wps[next + 1] -- 182
			local body = bodies[w.planetIndex + 1] -- 183
			if body == nil then -- 183
				return {passed = 0, lastIndex = -1} -- 184
			end -- 184
			local gp = bodyPositionAt(body, start + i * dt) -- 185
			if distance(points[i + 1], gp) < w.tolerance then -- 185
				next = next + 1 -- 187
				lastIndex = i -- 188
			end -- 188
			i = i + 1 -- 181
		end -- 181
	end -- 181
	return {passed = next, lastIndex = lastIndex} -- 191
end -- 167
function ____exports.findGoalIndex(points, bodies, goal, dt, t0) -- 194
	local wps = ____exports.goalWaypoints(goal) -- 195
	if #wps == 0 then -- 195
		return -1 -- 196
	end -- 196
	local st = ____exports.waypointProgress( -- 197
		points, -- 197
		bodies, -- 197
		goal, -- 197
		dt, -- 197
		t0 -- 197
	) -- 197
	return st.passed >= #wps and st.lastIndex or -1 -- 198
end -- 194
--- 太阳（除 L1 外每关的第 0 号天体）。
local function sun() -- 206
	return { -- 207
		gm = ____exports.SunGm, -- 207
		radius = ____exports.SunRadius, -- 207
		orbitCenter = {x = 0, y = 0}, -- 207
		orbitRadius = 0, -- 207
		orbitPeriod = 0, -- 207
		phase0 = 0, -- 207
		orbitDirection = 1 -- 207
	} -- 207
end -- 206
--- 太阳的视觉（亮黄，模型 Sun.glb）。
local function sunVisual() -- 211
	return { -- 212
		r = 1, -- 212
		g = 0.9, -- 212
		b = 0.62, -- 212
		displayRadius = ____exports.SunRadius, -- 212
		ring = false, -- 212
		model = "Sun", -- 212
		emissive = {r = 0.95, g = 0.72, b = 0.3} -- 212
	} -- 212
end -- 211
--- 绕日公转的行星（S3.7：圆心 = 太阳 = 原点）。
local function orbiter(gm, radius, orbitRadius, phaseDeg) -- 216
	return { -- 217
		gm = gm, -- 218
		radius = radius, -- 218
		orbitCenter = {x = 0, y = 0}, -- 219
		orbitRadius = orbitRadius, -- 220
		orbitPeriod = ____exports.keplerPeriod(orbitRadius), -- 221
		phase0 = deg(phaseDeg), -- 222
		orbitDirection = 1 -- 223
	} -- 223
end -- 216
local LEVELS = { -- 227
	{ -- 228
		id = 1, -- 229
		title = "出发", -- 230
		brief = "航行日志 · 第 1 天：离开地球。这一段路很干净，没有大天体捣乱 —— 先把拖拽瞄准练熟。月球在正前方。", -- 231
		probeStart = {x = 0, y = 40}, -- 232
		planets = {{ -- 233
			gm = 0, -- 235
			radius = R_MOON, -- 235
			orbitCenter = {x = 0, y = -70}, -- 235
			orbitRadius = 0, -- 235
			orbitPeriod = 0, -- 235
			phase0 = 0, -- 235
			orbitDirection = 1 -- 235
		}}, -- 235
		visuals = {{ -- 237
			r = 0.56, -- 238
			g = 0.56, -- 238
			b = 0.6, -- 238
			displayRadius = R_MOON, -- 238
			ring = false -- 238
		}}, -- 238
		goal = {kind = "planet", planetIndex = 0, tolerance = 14}, -- 240
		escapeRadius = 700, -- 241
		maxSteps = 1200, -- 242
		homeRadius = 1.75 -- 243
	}, -- 243
	{ -- 245
		id = 2, -- 246
		title = "修正", -- 247
		brief = "航行日志 · 第 12 天：太阳开始拽你了。别直着飞 —— 向内会加速，航线也会被掰弯。目标是掠过金星。", -- 248
		probeStart = {x = 0, y = ORBIT.earth}, -- 249
		planets = { -- 250
			sun(), -- 251
			orbiter(2600, R_VENUS, ORBIT.venus, 180) -- 253
		}, -- 253
		visuals = { -- 255
			sunVisual(), -- 256
			{ -- 257
				r = 0.9, -- 257
				g = 0.78, -- 257
				b = 0.55, -- 257
				displayRadius = R_VENUS, -- 257
				ring = false, -- 257
				model = "Planet_Venus" -- 257
			} -- 257
		}, -- 257
		goal = {kind = "planet", planetIndex = 1, tolerance = R_VENUS + FLYBY_PAD}, -- 259
		escapeRadius = 700, -- 260
		maxSteps = 1500, -- 261
		homeRadius = 1.6 -- 262
	}, -- 262
	{ -- 264
		id = 3, -- 265
		title = "弹弓", -- 266
		brief = "航行日志 · 第 2 年：木星在外圈。想省力就从它背后绕过去 —— 它的引力会把你甩向土星。", -- 267
		probeStart = {x = 0, y = ORBIT.earth}, -- 268
		planets = { -- 269
			sun(), -- 270
			orbiter(4000, R_JUPITER, ORBIT.jupiter, 195.5), -- 273
			orbiter(0, R_SATURN, ORBIT.saturn, 198) -- 275
		}, -- 275
		visuals = { -- 277
			sunVisual(), -- 278
			{ -- 279
				r = 0.85, -- 279
				g = 0.72, -- 279
				b = 0.5, -- 279
				displayRadius = R_JUPITER, -- 279
				ring = false, -- 279
				model = "Planet_Jupiter" -- 279
			}, -- 279
			{ -- 280
				r = 0.75, -- 280
				g = 0.7, -- 280
				b = 0.6, -- 280
				displayRadius = R_SATURN, -- 280
				ring = true, -- 280
				model = "Planet_Saturn" -- 280
			} -- 280
		}, -- 280
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + 8, chain = {{planetIndex = 1, tolerance = R_JUPITER + 8, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 45, label = "土星"}}}, -- 283
		escapeRadius = 700, -- 290
		maxSteps = 2400, -- 291
		homeRadius = 1.45 -- 292
	}, -- 292
	{ -- 294
		id = 4, -- 295
		title = "窗口", -- 296
		brief = "航行日志 · 第 3 年：木星一直在绕太阳走。挑一个它正好在你航线上的日期起飞 —— 拖动时间轴，看它挪位置。", -- 297
		probeStart = {x = 0, y = ORBIT.earth}, -- 298
		planets = { -- 299
			sun(), -- 300
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 315.5), -- 302
			orbiter(0, R_SATURN, ORBIT.saturn, 288) -- 303
		}, -- 303
		visuals = { -- 305
			sunVisual(), -- 306
			{ -- 307
				r = 0.85, -- 307
				g = 0.72, -- 307
				b = 0.5, -- 307
				displayRadius = R_JUPITER, -- 307
				ring = false, -- 307
				model = "Planet_Jupiter" -- 307
			}, -- 307
			{ -- 308
				r = 0.75, -- 308
				g = 0.7, -- 308
				b = 0.6, -- 308
				displayRadius = R_SATURN, -- 308
				ring = true, -- 308
				model = "Planet_Saturn" -- 308
			} -- 308
		}, -- 308
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 30, label = "土星"}}}, -- 311
		escapeRadius = 700, -- 318
		maxSteps = 1800, -- 319
		homeRadius = 1.35, -- 320
		timeWindow = {span = ____exports.keplerPeriod(ORBIT.jupiter) / 3} -- 323
	}, -- 323
	{ -- 325
		id = 5, -- 326
		title = "大巡游", -- 327
		brief = "航行日志 · 第 5 年：一次点火，四颗巨行星。木星改向、土星续航、天王星微调 —— 最后到海王星。", -- 328
		probeStart = {x = 0, y = ORBIT.earth}, -- 329
		planets = { -- 330
			sun(), -- 331
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 195.5), -- 334
			orbiter(2000, R_SATURN, ORBIT.saturn, 203.1), -- 335
			orbiter(1200, R_URANUS, ORBIT.uranus, 209.7), -- 336
			orbiter(800, R_NEPTUNE, ORBIT.neptune, 216.4) -- 337
		}, -- 337
		visuals = { -- 339
			sunVisual(), -- 340
			{ -- 341
				r = 0.85, -- 341
				g = 0.72, -- 341
				b = 0.5, -- 341
				displayRadius = R_JUPITER, -- 341
				ring = false, -- 341
				model = "Planet_Jupiter" -- 341
			}, -- 341
			{ -- 342
				r = 0.75, -- 342
				g = 0.7, -- 342
				b = 0.6, -- 342
				displayRadius = R_SATURN, -- 342
				ring = true, -- 342
				model = "Planet_Saturn" -- 342
			}, -- 342
			{ -- 343
				r = 0.62, -- 343
				g = 0.82, -- 343
				b = 0.86, -- 343
				displayRadius = R_URANUS, -- 343
				ring = false, -- 343
				model = "Planet_Uranus" -- 343
			}, -- 343
			{ -- 344
				r = 0.34, -- 344
				g = 0.5, -- 344
				b = 0.86, -- 344
				displayRadius = R_NEPTUNE, -- 344
				ring = false, -- 344
				model = "Planet_Neptune" -- 344
			} -- 344
		}, -- 344
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 26, label = "土星"}, {planetIndex = 3, tolerance = R_URANUS + 30, label = "天王星"}, {planetIndex = 4, tolerance = R_NEPTUNE + 34, label = "海王星"}}}, -- 347
		escapeRadius = 700, -- 356
		maxSteps = 2400, -- 357
		homeRadius = 1.25 -- 358
	}, -- 358
	{ -- 360
		id = 6, -- 361
		title = "单程", -- 362
		brief = "航行日志 · 第 12 年：没有回程了。穿过四颗巨行星，飞出太阳系 —— 越过 260 单位就算离开。", -- 363
		probeStart = {x = 0, y = ORBIT.earth}, -- 364
		planets = { -- 365
			sun(), -- 366
			orbiter(9400, R_JUPITER, ORBIT.jupiter, 200), -- 367
			orbiter(7000, R_SATURN, ORBIT.saturn, 245), -- 368
			orbiter(3200, R_URANUS, ORBIT.uranus, 290), -- 369
			orbiter(2200, R_NEPTUNE, ORBIT.neptune, 335) -- 370
		}, -- 370
		visuals = { -- 372
			sunVisual(), -- 373
			{ -- 374
				r = 0.85, -- 374
				g = 0.72, -- 374
				b = 0.5, -- 374
				displayRadius = R_JUPITER, -- 374
				ring = false, -- 374
				model = "Planet_Jupiter" -- 374
			}, -- 374
			{ -- 375
				r = 0.75, -- 375
				g = 0.7, -- 375
				b = 0.6, -- 375
				displayRadius = R_SATURN, -- 375
				ring = true, -- 375
				model = "Planet_Saturn" -- 375
			}, -- 375
			{ -- 376
				r = 0.62, -- 376
				g = 0.82, -- 376
				b = 0.86, -- 376
				displayRadius = R_URANUS, -- 376
				ring = false, -- 376
				model = "Planet_Uranus" -- 376
			}, -- 376
			{ -- 377
				r = 0.34, -- 377
				g = 0.5, -- 377
				b = 0.86, -- 377
				displayRadius = R_NEPTUNE, -- 377
				ring = false, -- 377
				model = "Planet_Neptune" -- 377
			} -- 377
		}, -- 377
		goal = {kind = "escape", planetIndex = -1, tolerance = 0}, -- 380
		escapeRadius = 260, -- 381
		maxSteps = 2400, -- 382
		homeRadius = 1 -- 383
	} -- 383
} -- 383
--- 关卡总数。
function ____exports.levelCount() -- 388
	return #LEVELS -- 389
end -- 388
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 393
	return LEVELS[index + 1] -- 394
end -- 393
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 398
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 399
end -- 398
return ____exports -- 398