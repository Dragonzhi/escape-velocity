-- [ts]: LevelData.ts
local ____exports = {} -- 1
local applyScalesLocal -- 1
local ____Gravity = require("game.Gravity") -- 28
local bodyPositionAt = ____Gravity.bodyPositionAt -- 28
local distance = ____Gravity.distance -- 28
local ____Config = require("game.Config") -- 29
local GravityScale = ____Config.GravityScale -- 29
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 29
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 434
	local out = {} -- 435
	for ____, b in ipairs(bodies) do -- 436
		out[#out + 1] = { -- 437
			gm = b.gm * gravityScale, -- 438
			radius = b.radius, -- 439
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 440
			orbitRadius = b.orbitRadius, -- 441
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 442
			phase0 = b.phase0, -- 443
			orbitDirection = b.orbitDirection -- 444
		} -- 444
	end -- 444
	return out -- 447
end -- 447
--- 太阳的引力强度（`v_circ(80) = sqrt(SunGm/80) ≈ 30`，逃逸速度 42.4）。
____exports.SunGm = 72000 -- 117
--- 太阳的半径（撞毁半径 = 显示半径，尺寸公平性硬约束）。
-- 
-- ⚠️ 2026-09-26 用户参考图（docs/比例尺效果展示图.excalidraw）给的比值：
--   最内圈轨道 ≈ **1.9 个太阳半径**、太阳直径 ≈ 屏幕宽度的 0.38、行星 ≈ 太阳的 0.19。
--   原来取 7.0（轨道 = 7.9~27.9 个太阳半径）⇒ 太阳在画面里像一颗行星，"尺度很怪"的根因之一。
--   改成 28 之后：轨道 55/80/105/135/165/195 = 1.96/2.86/3.75/4.8/5.9/7.0 个太阳半径，与参考图一致。
____exports.SunRadius = 28 -- 127
--- 开普勒周期系数：`T = KeplerK · r^1.5`（秒）。
-- 
-- 相对快慢 = 真实开普勒（内快外慢），绝对速率被压缩 —— `KeplerK = 1` 相当于把真实值除以 42.7
-- （真实：`T = 2π·r^1.5/sqrt(SunGm) = 0.0234·r^1.5`）。这样飞行十几秒里行星只挪几度。
____exports.KeplerK = 1 -- 135
--- 开普勒周期（秒）：r 单位是平面单位。r <= 0 返回 0（静止）。
function ____exports.keplerPeriod(orbitRadius) -- 138
	if orbitRadius <= 0 then -- 138
		return 0 -- 139
	end -- 139
	return ____exports.KeplerK * orbitRadius ^ 1.5 -- 140
end -- 138
--- 度 → 弧度（关卡数据里写角度比写弧度好读）。
local function deg(d) -- 144
	return d * math.pi / 180 -- 145
end -- 144
local R_MOON = 1 -- 149
local R_VENUS = 1.72 -- 150
local R_EARTH = 1.76 -- 151
local R_JUPITER = 4.63 -- 152
local R_SATURN = 4.3 -- 153
local R_URANUS = 3.04 -- 154
local R_NEPTUNE = 3 -- 155
--- 巡航轨道半径（压缩太阳系：顺序真实、比例压缩）—— 一律绕原点（太阳）。
local ORBIT = { -- 158
	venus = 55, -- 158
	earth = 80, -- 158
	jupiter = 105, -- 158
	saturn = 135, -- 158
	uranus = 165, -- 158
	neptune = 195 -- 158
} -- 158
--- 掠过环的容差（flyby）：比本体大 13 左右 —— 远距离飞行要有"够得着"的手感。
local FLYBY_PAD = 13 -- 161
--- 在飞行采样点中找第一个进入目标容差的索引。
-- 
-- 目标行星在移动，所以逐点用 `t = t0 + i * dt` 时的行星位置判定（`t0` = 发射时刻）。
-- `dt` 必须是**采样点之间的有效步长**（采样间隔 N 步时传 `N * PhysicsStep`）。
-- 返回 -1 表示未到达。
function ____exports.goalWaypoints(goal) -- 170
	if goal.chain ~= nil then -- 170
		return goal.chain -- 171
	end -- 171
	if goal.kind == "planet" then -- 171
		return {{planetIndex = goal.planetIndex, tolerance = goal.tolerance}} -- 172
	end -- 172
	return {} -- 173
end -- 170
--- 顺序航线的进度：返回在 points[0..upto] 里**依次**掠过的航点数与最后一个命中索引。
-- 
-- 一次线性扫描：航点必须按顺序命中，且后一个必须出现在更晚的采样点上
-- （"先到土星再路过木星"不算数）。upto 用于飞行中查询"到哪一段了"（画环的明暗）。
function ____exports.waypointProgress(points, bodies, goal, dt, t0, upto) -- 182
	local wps = ____exports.goalWaypoints(goal) -- 190
	local start = t0 ~= nil and t0 or 0 -- 191
	local limit = #points - 1 -- 192
	if upto ~= nil and upto >= 0 and upto < limit then -- 192
		limit = upto -- 193
	end -- 193
	local next = 0 -- 194
	local lastIndex = -1 -- 195
	do -- 195
		local i = 0 -- 196
		while i <= limit and next < #wps do -- 196
			local w = wps[next + 1] -- 197
			local body = bodies[w.planetIndex + 1] -- 198
			if body == nil then -- 198
				return {passed = 0, lastIndex = -1} -- 199
			end -- 199
			local gp = bodyPositionAt(body, start + i * dt) -- 200
			if distance(points[i + 1], gp) < w.tolerance then -- 200
				next = next + 1 -- 202
				lastIndex = i -- 203
			end -- 203
			i = i + 1 -- 196
		end -- 196
	end -- 196
	return {passed = next, lastIndex = lastIndex} -- 206
end -- 182
function ____exports.findGoalIndex(points, bodies, goal, dt, t0) -- 209
	local wps = ____exports.goalWaypoints(goal) -- 210
	if #wps == 0 then -- 210
		return -1 -- 211
	end -- 211
	local st = ____exports.waypointProgress( -- 212
		points, -- 212
		bodies, -- 212
		goal, -- 212
		dt, -- 212
		t0 -- 212
	) -- 212
	return st.passed >= #wps and st.lastIndex or -1 -- 213
end -- 209
--- 太阳（除 L1 外每关的第 0 号天体）。
local function sun() -- 221
	return { -- 222
		gm = ____exports.SunGm, -- 222
		radius = ____exports.SunRadius, -- 222
		orbitCenter = {x = 0, y = 0}, -- 222
		orbitRadius = 0, -- 222
		orbitPeriod = 0, -- 222
		phase0 = 0, -- 222
		orbitDirection = 1 -- 222
	} -- 222
end -- 221
--- 太阳的视觉（亮黄，模型 Sun.glb）。
local function sunVisual() -- 226
	return { -- 227
		r = 1, -- 227
		g = 0.9, -- 227
		b = 0.62, -- 227
		displayRadius = ____exports.SunRadius, -- 227
		ring = false, -- 227
		model = "Sun", -- 227
		emissive = {r = 0.95, g = 0.72, b = 0.3} -- 227
	} -- 227
end -- 226
--- 绕日公转的行星（S3.7：圆心 = 太阳 = 原点）。
local function orbiter(gm, radius, orbitRadius, phaseDeg) -- 231
	return { -- 232
		gm = gm, -- 233
		radius = radius, -- 233
		orbitCenter = {x = 0, y = 0}, -- 234
		orbitRadius = orbitRadius, -- 235
		orbitPeriod = ____exports.keplerPeriod(orbitRadius), -- 236
		phase0 = deg(phaseDeg), -- 237
		orbitDirection = 1 -- 238
	} -- 238
end -- 231
local LEVELS = { -- 242
	{ -- 243
		id = 1, -- 244
		title = "出发", -- 245
		brief = "航行日志 · 第 1 天：离开地球。这一段路很干净，没有大天体捣乱 —— 先把拖拽瞄准练熟。月球在正前方。", -- 246
		probeStart = {x = 0, y = 40}, -- 247
		probeVel0 = {x = 12, y = 0}, -- 251
		homeAnchor = false, -- 252
		planets = {{ -- 253
			gm = 2600, -- 256
			radius = R_EARTH, -- 256
			orbitCenter = {x = 0, y = 70}, -- 256
			orbitRadius = 0, -- 256
			orbitPeriod = 0, -- 256
			phase0 = 0, -- 256
			orbitDirection = 1 -- 256
		}, { -- 256
			gm = 0, -- 258
			radius = R_MOON, -- 258
			orbitCenter = {x = 0, y = -70}, -- 258
			orbitRadius = 0, -- 258
			orbitPeriod = 0, -- 258
			phase0 = 0, -- 258
			orbitDirection = 1 -- 258
		}}, -- 258
		visuals = {{ -- 260
			r = 0.42, -- 261
			g = 0.62, -- 261
			b = 0.85, -- 261
			displayRadius = R_EARTH, -- 261
			ring = false, -- 261
			model = "Planet_Earth" -- 261
		}, { -- 261
			r = 0.56, -- 262
			g = 0.56, -- 262
			b = 0.6, -- 262
			displayRadius = R_MOON, -- 262
			ring = false -- 262
		}}, -- 262
		goal = {kind = "planet", planetIndex = 1, tolerance = 24}, -- 265
		dvBudget = 45, -- 266
		escapeRadius = 700, -- 267
		maxSteps = 1200, -- 268
		homeRadius = 1.75 -- 269
	}, -- 269
	{ -- 271
		id = 2, -- 272
		title = "修正", -- 273
		brief = "航行日志 · 第 12 天：太阳开始拽你了。别直着飞 —— 向内会加速，航线也会被掰弯。目标是掠过金星。", -- 274
		probeStart = {x = 0, y = ORBIT.earth}, -- 275
		planets = { -- 276
			sun(), -- 277
			orbiter(2600, R_VENUS, ORBIT.venus, 180) -- 279
		}, -- 279
		visuals = { -- 281
			sunVisual(), -- 282
			{ -- 283
				r = 0.9, -- 283
				g = 0.78, -- 283
				b = 0.55, -- 283
				displayRadius = R_VENUS, -- 283
				ring = false, -- 283
				model = "Planet_Venus" -- 283
			} -- 283
		}, -- 283
		goal = {kind = "planet", planetIndex = 1, tolerance = R_VENUS + FLYBY_PAD}, -- 285
		dvBudget = 45, -- 286
		escapeRadius = 700, -- 287
		maxSteps = 1500, -- 288
		homeRadius = 1.6 -- 289
	}, -- 289
	{ -- 291
		id = 3, -- 292
		title = "弹弓", -- 293
		brief = "航行日志 · 第 2 年：木星在外圈。想省力就从它背后绕过去 —— 它的引力会把你甩向土星。", -- 294
		probeStart = {x = 0, y = ORBIT.earth}, -- 295
		planets = { -- 296
			sun(), -- 297
			orbiter(4000, R_JUPITER, ORBIT.jupiter, 195.5), -- 300
			orbiter(0, R_SATURN, ORBIT.saturn, 198) -- 302
		}, -- 302
		visuals = { -- 304
			sunVisual(), -- 305
			{ -- 306
				r = 0.85, -- 306
				g = 0.72, -- 306
				b = 0.5, -- 306
				displayRadius = R_JUPITER, -- 306
				ring = false, -- 306
				model = "Planet_Jupiter" -- 306
			}, -- 306
			{ -- 307
				r = 0.75, -- 307
				g = 0.7, -- 307
				b = 0.6, -- 307
				displayRadius = R_SATURN, -- 307
				ring = true, -- 307
				model = "Planet_Saturn" -- 307
			} -- 307
		}, -- 307
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + 8, chain = {{planetIndex = 1, tolerance = R_JUPITER + 8, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 45, label = "土星"}}}, -- 310
		dvBudget = 55, -- 317
		escapeRadius = 700, -- 318
		maxSteps = 2400, -- 319
		homeRadius = 1.45 -- 320
	}, -- 320
	{ -- 322
		id = 4, -- 323
		title = "窗口", -- 324
		brief = "航行日志 · 第 3 年：木星一直在绕太阳走。挑一个它正好在你航线上的日期起飞 —— 拖动时间轴，看它挪位置。", -- 325
		probeStart = {x = 0, y = ORBIT.earth}, -- 326
		planets = { -- 327
			sun(), -- 328
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 315.5), -- 330
			orbiter(0, R_SATURN, ORBIT.saturn, 288) -- 331
		}, -- 331
		visuals = { -- 333
			sunVisual(), -- 334
			{ -- 335
				r = 0.85, -- 335
				g = 0.72, -- 335
				b = 0.5, -- 335
				displayRadius = R_JUPITER, -- 335
				ring = false, -- 335
				model = "Planet_Jupiter" -- 335
			}, -- 335
			{ -- 336
				r = 0.75, -- 336
				g = 0.7, -- 336
				b = 0.6, -- 336
				displayRadius = R_SATURN, -- 336
				ring = true, -- 336
				model = "Planet_Saturn" -- 336
			} -- 336
		}, -- 336
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 30, label = "土星"}}}, -- 339
		dvBudget = 50, -- 346
		escapeRadius = 700, -- 347
		maxSteps = 1800, -- 348
		homeRadius = 1.35, -- 349
		timeWindow = {span = ____exports.keplerPeriod(ORBIT.jupiter) / 3} -- 352
	}, -- 352
	{ -- 354
		id = 5, -- 355
		title = "大巡游", -- 356
		brief = "航行日志 · 第 5 年：一次点火，四颗巨行星。木星改向、土星续航、天王星微调 —— 最后到海王星。", -- 357
		probeStart = {x = 0, y = ORBIT.earth}, -- 358
		planets = { -- 359
			sun(), -- 360
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 195.5), -- 363
			orbiter(2000, R_SATURN, ORBIT.saturn, 203.1), -- 364
			orbiter(1200, R_URANUS, ORBIT.uranus, 209.7), -- 365
			orbiter(800, R_NEPTUNE, ORBIT.neptune, 216.4) -- 366
		}, -- 366
		visuals = { -- 368
			sunVisual(), -- 369
			{ -- 370
				r = 0.85, -- 370
				g = 0.72, -- 370
				b = 0.5, -- 370
				displayRadius = R_JUPITER, -- 370
				ring = false, -- 370
				model = "Planet_Jupiter" -- 370
			}, -- 370
			{ -- 371
				r = 0.75, -- 371
				g = 0.7, -- 371
				b = 0.6, -- 371
				displayRadius = R_SATURN, -- 371
				ring = true, -- 371
				model = "Planet_Saturn" -- 371
			}, -- 371
			{ -- 372
				r = 0.62, -- 372
				g = 0.82, -- 372
				b = 0.86, -- 372
				displayRadius = R_URANUS, -- 372
				ring = false, -- 372
				model = "Planet_Uranus" -- 372
			}, -- 372
			{ -- 373
				r = 0.34, -- 373
				g = 0.5, -- 373
				b = 0.86, -- 373
				displayRadius = R_NEPTUNE, -- 373
				ring = false, -- 373
				model = "Planet_Neptune" -- 373
			} -- 373
		}, -- 373
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 26, label = "土星"}, {planetIndex = 3, tolerance = R_URANUS + 30, label = "天王星"}, {planetIndex = 4, tolerance = R_NEPTUNE + 34, label = "海王星"}}}, -- 376
		dvBudget = 55, -- 385
		escapeRadius = 700, -- 386
		maxSteps = 2400, -- 387
		homeRadius = 1.25 -- 388
	}, -- 388
	{ -- 390
		id = 6, -- 391
		title = "单程", -- 392
		brief = "航行日志 · 第 12 年：没有回程了。穿过四颗巨行星，飞出太阳系 —— 越过 260 单位就算离开。", -- 393
		probeStart = {x = 0, y = ORBIT.earth}, -- 394
		planets = { -- 395
			sun(), -- 396
			orbiter(9400, R_JUPITER, ORBIT.jupiter, 200), -- 397
			orbiter(7000, R_SATURN, ORBIT.saturn, 245), -- 398
			orbiter(3200, R_URANUS, ORBIT.uranus, 290), -- 399
			orbiter(2200, R_NEPTUNE, ORBIT.neptune, 335) -- 400
		}, -- 400
		visuals = { -- 402
			sunVisual(), -- 403
			{ -- 404
				r = 0.85, -- 404
				g = 0.72, -- 404
				b = 0.5, -- 404
				displayRadius = R_JUPITER, -- 404
				ring = false, -- 404
				model = "Planet_Jupiter" -- 404
			}, -- 404
			{ -- 405
				r = 0.75, -- 405
				g = 0.7, -- 405
				b = 0.6, -- 405
				displayRadius = R_SATURN, -- 405
				ring = true, -- 405
				model = "Planet_Saturn" -- 405
			}, -- 405
			{ -- 406
				r = 0.62, -- 406
				g = 0.82, -- 406
				b = 0.86, -- 406
				displayRadius = R_URANUS, -- 406
				ring = false, -- 406
				model = "Planet_Uranus" -- 406
			}, -- 406
			{ -- 407
				r = 0.34, -- 407
				g = 0.5, -- 407
				b = 0.86, -- 407
				displayRadius = R_NEPTUNE, -- 407
				ring = false, -- 407
				model = "Planet_Neptune" -- 407
			} -- 407
		}, -- 407
		goal = {kind = "escape", planetIndex = -1, tolerance = 0}, -- 410
		dvBudget = 50, -- 411
		escapeRadius = 260, -- 412
		maxSteps = 2400, -- 413
		homeRadius = 1 -- 414
	} -- 414
} -- 414
--- 关卡总数。
function ____exports.levelCount() -- 419
	return #LEVELS -- 420
end -- 419
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 424
	return LEVELS[index + 1] -- 425
end -- 424
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 429
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 430
end -- 429
return ____exports -- 429