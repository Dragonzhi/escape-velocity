-- [ts]: LevelData.ts
local ____exports = {} -- 1
local applyScalesLocal -- 1
local ____Gravity = require("game.Gravity") -- 28
local bodyPositionAt = ____Gravity.bodyPositionAt -- 28
local distance = ____Gravity.distance -- 28
local ____Config = require("game.Config") -- 29
local GravityScale = ____Config.GravityScale -- 29
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 29
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 569
	local out = {} -- 570
	for ____, b in ipairs(bodies) do -- 571
		out[#out + 1] = { -- 572
			gm = b.gm * gravityScale, -- 573
			radius = b.radius, -- 574
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 575
			orbitRadius = b.orbitRadius, -- 576
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 577
			phase0 = b.phase0, -- 578
			orbitDirection = b.orbitDirection -- 579
		} -- 579
	end -- 579
	return out -- 582
end -- 582
--- 太阳的引力强度（`v_circ(80) = sqrt(SunGm/80) ≈ 30`，逃逸速度 42.4）。
____exports.SunGm = 72000 -- 125
--- 太阳的半径（撞毁半径 = 显示半径，尺寸公平性硬约束）。
-- 
-- ⚠️ 2026-09-26 用户参考图（docs/比例尺效果展示图.excalidraw）给的比值：
--   最内圈轨道 ≈ **1.9 个太阳半径**、太阳直径 ≈ 屏幕宽度的 0.38、行星 ≈ 太阳的 0.19。
--   原来取 7.0（轨道 = 7.9~27.9 个太阳半径）⇒ 太阳在画面里像一颗行星，"尺度很怪"的根因之一。
--   改成 28 之后：轨道 55/80/105/135/165/195 = 1.96/2.86/3.75/4.8/5.9/7.0 个太阳半径，与参考图一致。
____exports.SunRadius = 28 -- 135
--- 开普勒周期系数：`T = KeplerK · r^1.5`（秒）。
-- 
-- 相对快慢 = 真实开普勒（内快外慢），绝对速率被压缩 —— `KeplerK = 1` 相当于把真实值除以 42.7
-- （真实：`T = 2π·r^1.5/sqrt(SunGm) = 0.0234·r^1.5`）。这样飞行十几秒里行星只挪几度。
____exports.KeplerK = 1 -- 143
--- 开普勒周期（秒）：r 单位是平面单位。r <= 0 返回 0（静止）。
function ____exports.keplerPeriod(orbitRadius) -- 146
	if orbitRadius <= 0 then -- 146
		return 0 -- 147
	end -- 147
	return ____exports.KeplerK * orbitRadius ^ 1.5 -- 148
end -- 146
--- 度 → 弧度（关卡数据里写角度比写弧度好读）。
local function deg(d) -- 152
	return d * math.pi / 180 -- 153
end -- 152
local R_MOON = 1 -- 157
local R_EARTH_BIG = 6 -- 160
local R_MOON_BIG = 3.4 -- 161
local R_VENUS = 1.72 -- 162
local R_EARTH = 1.76 -- 163
local R_JUPITER = 4.63 -- 164
local R_SATURN = 4.3 -- 165
local R_URANUS = 3.04 -- 166
local R_NEPTUNE = 3 -- 167
--- 巡航轨道半径（压缩太阳系：顺序真实、比例压缩）—— 一律绕原点（太阳）。
local ORBIT = { -- 170
	venus = 55, -- 170
	earth = 80, -- 170
	jupiter = 105, -- 170
	saturn = 135, -- 170
	uranus = 165, -- 170
	neptune = 195 -- 170
} -- 170
--- 掠过环的容差（flyby）：比本体大 13 左右 —— 远距离飞行要有"够得着"的手感。
local FLYBY_PAD = 13 -- 173
--- 行星自身在时刻 t 的速度（圆轨道 = 位置的导数）。
-- 捕获判据要的是"**相对**行星的速度" —— 行星自己也在跑（虽然慢）。
function ____exports.bodyVelocityAt(b, t) -- 186
	if b.orbitPeriod == 0 or b.orbitRadius <= 0 then -- 186
		return {x = 0, y = 0} -- 187
	end -- 187
	local angle = b.phase0 + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 188
	local w = b.orbitDirection * 2 * math.pi / b.orbitPeriod -- 189
	return { -- 190
		x = -math.sin(angle) * b.orbitRadius * w, -- 190
		y = math.cos(angle) * b.orbitRadius * w -- 190
	} -- 190
end -- 186
function ____exports.goalWaypoints(goal) -- 193
	if goal.chain ~= nil then -- 193
		return goal.chain -- 194
	end -- 194
	if goal.kind == "planet" then -- 194
		return {{planetIndex = goal.planetIndex, tolerance = goal.tolerance}} -- 195
	end -- 195
	return {} -- 196
end -- 193
--- 采样点 i 处、相对某天体的速度（捕获判据与诊断共用同一份实现）。
-- 
-- points 里只有位置 ⇒ 用相邻采样点差分；`dt` 是**相邻采样点之间的有效步长**。
-- `limit` 是最后一个有效采样点索引（末端夹紧用）。
function ____exports.relativeSpeedAt(points, i, body, dt, t0, limit, velocities) -- 211
	local vx = 0 -- 212
	local vy = 0 -- 213
	if velocities ~= nil and velocities[i + 1] ~= nil then -- 213
		vx = velocities[i + 1].x -- 216
		vy = velocities[i + 1].y -- 217
	else -- 217
		local j1 = i + 1 <= limit and i + 1 or i -- 221
		local j0 = i > 0 and i - 1 or i -- 222
		local spanT = (j1 - j0) * dt -- 223
		if spanT > 0 then -- 223
			vx = (points[j1 + 1].x - points[j0 + 1].x) / spanT -- 225
			vy = (points[j1 + 1].y - points[j0 + 1].y) / spanT -- 226
		end -- 226
	end -- 226
	local pv = ____exports.bodyVelocityAt(body, t0) -- 229
	local rx = vx - pv.x -- 230
	local ry = vy - pv.y -- 231
	return math.sqrt(rx * rx + ry * ry) -- 232
end -- 211
--- 捕获阈值：该处逃逸速度（圆轨道速度 × 系数 k，k 默认 √2）。
function ____exports.captureThreshold(body, d, k) -- 236
	if body.gm <= 0 or d <= 0.000001 then -- 236
		return 1000000000 -- 237
	end -- 237
	return k * math.sqrt(body.gm / d) -- 238
end -- 236
function ____exports.waypointProgress(points, bodies, goal, dt, t0, upto, velocities) -- 241
	local wps = ____exports.goalWaypoints(goal) -- 251
	local start = t0 ~= nil and t0 or 0 -- 252
	local limit = #points - 1 -- 253
	if upto ~= nil and upto >= 0 and upto < limit then -- 253
		limit = upto -- 254
	end -- 254
	local next = 0 -- 255
	local lastIndex = -1 -- 256
	do -- 256
		local i = 0 -- 257
		while i <= limit and next < #wps do -- 257
			do -- 257
				local w = wps[next + 1] -- 258
				local body = bodies[w.planetIndex + 1] -- 259
				if body == nil then -- 259
					return {passed = 0, lastIndex = -1} -- 260
				end -- 260
				local gp = bodyPositionAt(body, start + i * dt) -- 261
				if distance(points[i + 1], gp) < w.tolerance then -- 261
					if w.capture == true then -- 261
						local k = w.captureFactor ~= nil and w.captureFactor or 1.4142135623730951 -- 267
						local d = distance(points[i + 1], gp) -- 268
						if d <= body.radius then -- 268
							goto __continue19 -- 272
						end -- 272
						local rel = ____exports.relativeSpeedAt( -- 273
							points, -- 273
							i, -- 273
							body, -- 273
							dt, -- 273
							start + i * dt, -- 273
							limit, -- 273
							velocities -- 273
						) -- 273
						if rel > ____exports.captureThreshold(body, d, k) then -- 273
							goto __continue19 -- 274
						end -- 274
					end -- 274
					next = next + 1 -- 276
					lastIndex = i -- 277
				end -- 277
			end -- 277
			::__continue19:: -- 277
			i = i + 1 -- 257
		end -- 257
	end -- 257
	return {passed = next, lastIndex = lastIndex} -- 280
end -- 241
function ____exports.findGoalIndex(points, bodies, goal, dt, t0, velocities) -- 283
	local wps = ____exports.goalWaypoints(goal) -- 284
	if #wps == 0 then -- 284
		return -1 -- 285
	end -- 285
	local st = ____exports.waypointProgress( -- 286
		points, -- 286
		bodies, -- 286
		goal, -- 286
		dt, -- 286
		t0, -- 286
		nil, -- 286
		velocities -- 286
	) -- 286
	return st.passed >= #wps and st.lastIndex or -1 -- 287
end -- 283
--- 太阳（除 L1 外每关的第 0 号天体）。
local function sun() -- 295
	return { -- 296
		gm = ____exports.SunGm, -- 296
		radius = ____exports.SunRadius, -- 296
		orbitCenter = {x = 0, y = 0}, -- 296
		orbitRadius = 0, -- 296
		orbitPeriod = 0, -- 296
		phase0 = 0, -- 296
		orbitDirection = 1 -- 296
	} -- 296
end -- 295
--- 太阳的视觉（亮黄，模型 Sun.glb）。
local function sunVisual() -- 300
	return { -- 304
		r = 1, -- 304
		g = 0.97, -- 304
		b = 0.88, -- 304
		displayRadius = ____exports.SunRadius, -- 304
		ring = false, -- 304
		model = "Sun", -- 304
		emissive = {r = 1, g = 0.95, b = 0.82} -- 304
	} -- 304
end -- 300
--- 绕日公转的行星（S3.7：圆心 = 太阳 = 原点）。
local function orbiter(gm, radius, orbitRadius, phaseDeg) -- 308
	return { -- 309
		gm = gm, -- 310
		radius = radius, -- 310
		orbitCenter = {x = 0, y = 0}, -- 311
		orbitRadius = orbitRadius, -- 312
		orbitPeriod = ____exports.keplerPeriod(orbitRadius), -- 313
		phase0 = deg(phaseDeg), -- 314
		orbitDirection = 1 -- 315
	} -- 315
end -- 308
local LEVELS = { -- 319
	{ -- 320
		id = 1, -- 321
		title = "出发", -- 322
		brief = "航行日志 · 第 1 天：地球轨道。探测器在你手里 —— 月球正在绕地球走，别对着它现在的位置打。这一次点火决定后面的一切。", -- 328
		probeStart = {x = 0, y = 46}, -- 329
		probeVel0 = {x = 10.41, y = 0}, -- 337
		homeAnchor = false, -- 338
		planets = { -- 339
			{ -- 342
				gm = 2600, -- 342
				radius = R_EARTH_BIG, -- 342
				orbitCenter = {x = 0, y = 70}, -- 342
				orbitRadius = 0, -- 342
				orbitPeriod = 0, -- 342
				phase0 = 0, -- 342
				orbitDirection = 1 -- 342
			}, -- 342
			{ -- 345
				gm = 0, -- 345
				radius = R_MOON_BIG, -- 345
				orbitCenter = {x = 0, y = 70}, -- 345
				orbitRadius = 100, -- 345
				orbitPeriod = ____exports.keplerPeriod(100), -- 345
				phase0 = deg(-90), -- 345
				orbitDirection = 1 -- 345
			} -- 345
		}, -- 345
		visuals = {{ -- 347
			r = 0.42, -- 348
			g = 0.62, -- 348
			b = 0.85, -- 348
			displayRadius = R_EARTH_BIG, -- 348
			ring = false, -- 348
			model = "Planet_Earth" -- 348
		}, { -- 348
			r = 0.56, -- 349
			g = 0.56, -- 349
			b = 0.6, -- 349
			displayRadius = R_MOON_BIG, -- 349
			ring = false -- 349
		}}, -- 349
		goal = {kind = "planet", planetIndex = 1, tolerance = 30}, -- 354
		dvBudget = 45, -- 355
		escapeRadius = 700, -- 356
		maxSteps = 1200, -- 357
		homeRadius = 1.75 -- 358
	}, -- 358
	{ -- 360
		id = 2, -- 361
		title = "修正", -- 362
		brief = "航行日志 · 第 12 天：太阳开始拽你了。别直着飞 —— 向内会加速，航线也会被掰弯。目标是掠过金星。", -- 363
		probeStart = {x = 0, y = ORBIT.earth}, -- 364
		planets = { -- 365
			sun(), -- 366
			orbiter(2600, R_VENUS, ORBIT.venus, 180) -- 368
		}, -- 368
		visuals = { -- 370
			sunVisual(), -- 371
			{ -- 372
				r = 0.9, -- 372
				g = 0.78, -- 372
				b = 0.55, -- 372
				displayRadius = R_VENUS, -- 372
				ring = false, -- 372
				model = "Planet_Venus" -- 372
			} -- 372
		}, -- 372
		goal = {kind = "planet", planetIndex = 1, tolerance = R_VENUS + FLYBY_PAD}, -- 374
		dvBudget = 45, -- 375
		escapeRadius = 700, -- 376
		maxSteps = 1500, -- 377
		homeRadius = 1.6 -- 378
	}, -- 378
	{ -- 380
		id = 3, -- 381
		title = "弹弓", -- 382
		brief = "航行日志 · 第 2 年：木星在外圈。想省力就从它背后绕过去 —— 它的引力会把你甩向土星。", -- 383
		probeStart = {x = 0, y = ORBIT.earth}, -- 384
		planets = { -- 385
			sun(), -- 386
			orbiter(4000, R_JUPITER, ORBIT.jupiter, 89.4), -- 393
			orbiter(12000, R_SATURN, ORBIT.saturn, 89) -- 395
		}, -- 395
		visuals = { -- 397
			sunVisual(), -- 398
			{ -- 399
				r = 0.85, -- 399
				g = 0.72, -- 399
				b = 0.5, -- 399
				displayRadius = R_JUPITER, -- 399
				ring = false, -- 399
				model = "Planet_Jupiter" -- 399
			}, -- 399
			{ -- 400
				r = 0.75, -- 400
				g = 0.7, -- 400
				b = 0.6, -- 400
				displayRadius = R_SATURN, -- 400
				ring = true, -- 400
				model = "Planet_Saturn" -- 400
			} -- 400
		}, -- 400
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + 22, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 45, label = "土星"}}}, -- 403
		dvBudget = 55, -- 412
		escapeRadius = 700, -- 413
		maxSteps = 2400, -- 414
		homeRadius = 1.45 -- 415
	}, -- 415
	{ -- 417
		id = 4, -- 418
		title = "窗口", -- 419
		brief = "航行日志 · 第 3 年：木星一直在绕太阳走。挑一个它正好在你航线上的日期起飞 —— 拖动时间轴，看它挪位置。", -- 420
		probeStart = {x = 0, y = ORBIT.earth}, -- 421
		planets = { -- 422
			sun(), -- 423
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 29.3), -- 431
			orbiter(12000, R_SATURN, ORBIT.saturn, 48.2) -- 432
		}, -- 432
		visuals = { -- 434
			sunVisual(), -- 435
			{ -- 436
				r = 0.85, -- 436
				g = 0.72, -- 436
				b = 0.5, -- 436
				displayRadius = R_JUPITER, -- 436
				ring = false, -- 436
				model = "Planet_Jupiter" -- 436
			}, -- 436
			{ -- 437
				r = 0.75, -- 437
				g = 0.7, -- 437
				b = 0.6, -- 437
				displayRadius = R_SATURN, -- 437
				ring = true, -- 437
				model = "Planet_Saturn" -- 437
			} -- 437
		}, -- 437
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 30, label = "土星", capture = true}}}, -- 440
		dvBudget = 50, -- 447
		escapeRadius = 700, -- 448
		maxSteps = 1800, -- 449
		homeRadius = 1.35, -- 450
		timeWindow = {span = 300} -- 454
	}, -- 454
	{ -- 456
		id = 5, -- 457
		title = "大巡游", -- 458
		brief = "航行日志 · 第 5 年：一次点火，四颗巨行星。木星改向、土星续航、天王星微调 —— 最后到海王星。", -- 459
		probeStart = {x = 0, y = ORBIT.earth}, -- 460
		planets = { -- 461
			sun(), -- 462
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 89.5), -- 467
			orbiter(2000, R_SATURN, ORBIT.saturn, 89.5), -- 468
			orbiter(1200, R_URANUS, ORBIT.uranus, 89.5), -- 469
			orbiter(8000, R_NEPTUNE, ORBIT.neptune, 89.5) -- 470
		}, -- 470
		visuals = { -- 472
			sunVisual(), -- 473
			{ -- 474
				r = 0.85, -- 474
				g = 0.72, -- 474
				b = 0.5, -- 474
				displayRadius = R_JUPITER, -- 474
				ring = false, -- 474
				model = "Planet_Jupiter" -- 474
			}, -- 474
			{ -- 475
				r = 0.75, -- 475
				g = 0.7, -- 475
				b = 0.6, -- 475
				displayRadius = R_SATURN, -- 475
				ring = true, -- 475
				model = "Planet_Saturn" -- 475
			}, -- 475
			{ -- 476
				r = 0.62, -- 476
				g = 0.82, -- 476
				b = 0.86, -- 476
				displayRadius = R_URANUS, -- 476
				ring = false, -- 476
				model = "Planet_Uranus" -- 476
			}, -- 476
			{ -- 477
				r = 0.34, -- 477
				g = 0.5, -- 477
				b = 0.86, -- 477
				displayRadius = R_NEPTUNE, -- 477
				ring = false, -- 477
				model = "Planet_Neptune" -- 477
			} -- 477
		}, -- 477
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 50, label = "土星"}, {planetIndex = 3, tolerance = 60, label = "天王星"}, {planetIndex = 4, tolerance = 70, label = "海王星"}}}, -- 480
		dvBudget = 55, -- 495
		escapeRadius = 700, -- 496
		maxSteps = 2400, -- 497
		homeRadius = 1.25 -- 498
	}, -- 498
	{ -- 500
		id = 6, -- 501
		title = "单程", -- 502
		brief = "航行日志 · 第 12 年：没有回程了。四颗巨行星还会连成一条线 —— 等到那一天（拖动时间轴），沿着这条线依次穿过去，再越过 260 单位，就是星际空间。", -- 503
		probeStart = {x = 0, y = ORBIT.earth}, -- 504
		planets = { -- 505
			sun(), -- 506
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 29.3), -- 512
			orbiter(2000, R_SATURN, ORBIT.saturn, 48.2), -- 513
			orbiter(1200, R_URANUS, ORBIT.uranus, 58.9), -- 514
			orbiter(8000, R_NEPTUNE, ORBIT.neptune, 65.7) -- 515
		}, -- 515
		visuals = { -- 517
			sunVisual(), -- 518
			{ -- 519
				r = 0.85, -- 519
				g = 0.72, -- 519
				b = 0.5, -- 519
				displayRadius = R_JUPITER, -- 519
				ring = false, -- 519
				model = "Planet_Jupiter" -- 519
			}, -- 519
			{ -- 520
				r = 0.75, -- 520
				g = 0.7, -- 520
				b = 0.6, -- 520
				displayRadius = R_SATURN, -- 520
				ring = true, -- 520
				model = "Planet_Saturn" -- 520
			}, -- 520
			{ -- 521
				r = 0.62, -- 521
				g = 0.82, -- 521
				b = 0.86, -- 521
				displayRadius = R_URANUS, -- 521
				ring = false, -- 521
				model = "Planet_Uranus" -- 521
			}, -- 521
			{ -- 522
				r = 0.34, -- 522
				g = 0.5, -- 522
				b = 0.86, -- 522
				displayRadius = R_NEPTUNE, -- 522
				ring = false, -- 522
				model = "Planet_Neptune" -- 522
			} -- 522
		}, -- 522
		goal = {kind = "escape", planetIndex = -1, tolerance = 0, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 50, label = "土星"}, {planetIndex = 3, tolerance = 60, label = "天王星"}, {planetIndex = 4, tolerance = 70, label = "海王星"}}}, -- 530
		dvBudget = 50, -- 542
		escapeRadius = 260, -- 543
		maxSteps = 2400, -- 544
		homeRadius = 1, -- 545
		timeWindow = {span = 300} -- 549
	} -- 549
} -- 549
--- 关卡总数。
function ____exports.levelCount() -- 554
	return #LEVELS -- 555
end -- 554
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 559
	return LEVELS[index + 1] -- 560
end -- 559
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 564
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 565
end -- 564
return ____exports -- 564