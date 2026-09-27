-- [ts]: LevelData.ts
local ____exports = {} -- 1
local applyScalesLocal -- 1
local ____Gravity = require("game.Gravity") -- 28
local bodyPositionAt = ____Gravity.bodyPositionAt -- 28
local distance = ____Gravity.distance -- 28
local ____Config = require("game.Config") -- 29
local GravityScale = ____Config.GravityScale -- 29
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 29
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 587
	local out = {} -- 588
	for ____, b in ipairs(bodies) do -- 589
		out[#out + 1] = { -- 590
			gm = b.gm * gravityScale, -- 591
			radius = b.radius, -- 592
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 593
			orbitRadius = b.orbitRadius, -- 594
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 595
			phase0 = b.phase0, -- 596
			orbitDirection = b.orbitDirection, -- 597
			host = b.host ~= nil and applyScalesLocal({b.host}, gravityScale, orbitScale)[1] or nil -- 599
		} -- 599
	end -- 599
	return out -- 602
end -- 602
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
--- 绕**会动的行星**公转的卫星（S3.13，L1 的月球）：
-- 直接把宿主天体对象传进来，位置就随宿主一起走（见 Gravity.Body.host）。
-- `periodSec` 显式给：月球绕地球的周期不该用"绕日开普勒"算，而要与**全局时间压缩**一致
-- （本作 K = 1.0 = 真实周期 ÷ 42.7）。
local function satellite(gm, radius, host, orbitRadius, phaseDeg, periodSec) -- 325
	return { -- 326
		gm = gm, -- 327
		radius = radius, -- 327
		orbitCenter = {x = 0, y = 0}, -- 328
		orbitRadius = orbitRadius, -- 329
		orbitPeriod = periodSec, -- 330
		phase0 = deg(phaseDeg), -- 331
		orbitDirection = 1, -- 332
		host = host -- 333
	} -- 333
end -- 325
local LEVELS = { -- 337
	{ -- 338
		id = 1, -- 339
		title = "出发", -- 340
		brief = "航行日志 · 第 1 天：地球轨道。探测器在你手里 —— 月球正在绕地球走，别对着它现在的位置打。这一次点火决定后面的一切。", -- 346
		probeStart = {x = 0, y = 46}, -- 347
		probeVel0 = {x = 10.41, y = 0}, -- 355
		homeAnchor = false, -- 356
		planets = { -- 357
			{ -- 360
				gm = 2600, -- 360
				radius = R_EARTH_BIG, -- 360
				orbitCenter = {x = 0, y = 70}, -- 360
				orbitRadius = 0, -- 360
				orbitPeriod = 0, -- 360
				phase0 = 0, -- 360
				orbitDirection = 1 -- 360
			}, -- 360
			{ -- 363
				gm = 0, -- 363
				radius = R_MOON_BIG, -- 363
				orbitCenter = {x = 0, y = 70}, -- 363
				orbitRadius = 100, -- 363
				orbitPeriod = ____exports.keplerPeriod(100), -- 363
				phase0 = deg(-90), -- 363
				orbitDirection = 1 -- 363
			} -- 363
		}, -- 363
		visuals = {{ -- 365
			r = 0.42, -- 366
			g = 0.62, -- 366
			b = 0.85, -- 366
			displayRadius = R_EARTH_BIG, -- 366
			ring = false, -- 366
			model = "Planet_Earth" -- 366
		}, { -- 366
			r = 0.56, -- 367
			g = 0.56, -- 367
			b = 0.6, -- 367
			displayRadius = R_MOON_BIG, -- 367
			ring = false -- 367
		}}, -- 367
		goal = {kind = "planet", planetIndex = 1, tolerance = 30}, -- 372
		dvBudget = 45, -- 373
		escapeRadius = 700, -- 374
		maxSteps = 1200, -- 375
		homeRadius = 1.75 -- 376
	}, -- 376
	{ -- 378
		id = 2, -- 379
		title = "修正", -- 380
		brief = "航行日志 · 第 12 天：太阳开始拽你了。别直着飞 —— 向内会加速，航线也会被掰弯。目标是掠过金星。", -- 381
		probeStart = {x = 0, y = ORBIT.earth}, -- 382
		planets = { -- 383
			sun(), -- 384
			orbiter(2600, R_VENUS, ORBIT.venus, 180) -- 386
		}, -- 386
		visuals = { -- 388
			sunVisual(), -- 389
			{ -- 390
				r = 0.9, -- 390
				g = 0.78, -- 390
				b = 0.55, -- 390
				displayRadius = R_VENUS, -- 390
				ring = false, -- 390
				model = "Planet_Venus" -- 390
			} -- 390
		}, -- 390
		goal = {kind = "planet", planetIndex = 1, tolerance = R_VENUS + FLYBY_PAD}, -- 392
		dvBudget = 45, -- 393
		escapeRadius = 700, -- 394
		maxSteps = 1500, -- 395
		homeRadius = 1.6 -- 396
	}, -- 396
	{ -- 398
		id = 3, -- 399
		title = "弹弓", -- 400
		brief = "航行日志 · 第 2 年：木星在外圈。想省力就从它背后绕过去 —— 它的引力会把你甩向土星。", -- 401
		probeStart = {x = 0, y = ORBIT.earth}, -- 402
		planets = { -- 403
			sun(), -- 404
			orbiter(4000, R_JUPITER, ORBIT.jupiter, 89.4), -- 411
			orbiter(12000, R_SATURN, ORBIT.saturn, 89) -- 413
		}, -- 413
		visuals = { -- 415
			sunVisual(), -- 416
			{ -- 417
				r = 0.85, -- 417
				g = 0.72, -- 417
				b = 0.5, -- 417
				displayRadius = R_JUPITER, -- 417
				ring = false, -- 417
				model = "Planet_Jupiter" -- 417
			}, -- 417
			{ -- 418
				r = 0.75, -- 418
				g = 0.7, -- 418
				b = 0.6, -- 418
				displayRadius = R_SATURN, -- 418
				ring = true, -- 418
				model = "Planet_Saturn" -- 418
			} -- 418
		}, -- 418
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + 22, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 45, label = "土星"}}}, -- 421
		dvBudget = 55, -- 430
		escapeRadius = 700, -- 431
		maxSteps = 2400, -- 432
		homeRadius = 1.45 -- 433
	}, -- 433
	{ -- 435
		id = 4, -- 436
		title = "窗口", -- 437
		brief = "航行日志 · 第 3 年：木星一直在绕太阳走。挑一个它正好在你航线上的日期起飞 —— 拖动时间轴，看它挪位置。", -- 438
		probeStart = {x = 0, y = ORBIT.earth}, -- 439
		planets = { -- 440
			sun(), -- 441
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 29.3), -- 449
			orbiter(12000, R_SATURN, ORBIT.saturn, 48.2) -- 450
		}, -- 450
		visuals = { -- 452
			sunVisual(), -- 453
			{ -- 454
				r = 0.85, -- 454
				g = 0.72, -- 454
				b = 0.5, -- 454
				displayRadius = R_JUPITER, -- 454
				ring = false, -- 454
				model = "Planet_Jupiter" -- 454
			}, -- 454
			{ -- 455
				r = 0.75, -- 455
				g = 0.7, -- 455
				b = 0.6, -- 455
				displayRadius = R_SATURN, -- 455
				ring = true, -- 455
				model = "Planet_Saturn" -- 455
			} -- 455
		}, -- 455
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 30, label = "土星", capture = true}}}, -- 458
		dvBudget = 50, -- 465
		escapeRadius = 700, -- 466
		maxSteps = 1800, -- 467
		homeRadius = 1.35, -- 468
		timeWindow = {span = 300} -- 472
	}, -- 472
	{ -- 474
		id = 5, -- 475
		title = "大巡游", -- 476
		brief = "航行日志 · 第 5 年：一次点火，四颗巨行星。木星改向、土星续航、天王星微调 —— 最后到海王星。", -- 477
		probeStart = {x = 0, y = ORBIT.earth}, -- 478
		planets = { -- 479
			sun(), -- 480
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 89.5), -- 485
			orbiter(2000, R_SATURN, ORBIT.saturn, 89.5), -- 486
			orbiter(1200, R_URANUS, ORBIT.uranus, 89.5), -- 487
			orbiter(8000, R_NEPTUNE, ORBIT.neptune, 89.5) -- 488
		}, -- 488
		visuals = { -- 490
			sunVisual(), -- 491
			{ -- 492
				r = 0.85, -- 492
				g = 0.72, -- 492
				b = 0.5, -- 492
				displayRadius = R_JUPITER, -- 492
				ring = false, -- 492
				model = "Planet_Jupiter" -- 492
			}, -- 492
			{ -- 493
				r = 0.75, -- 493
				g = 0.7, -- 493
				b = 0.6, -- 493
				displayRadius = R_SATURN, -- 493
				ring = true, -- 493
				model = "Planet_Saturn" -- 493
			}, -- 493
			{ -- 494
				r = 0.62, -- 494
				g = 0.82, -- 494
				b = 0.86, -- 494
				displayRadius = R_URANUS, -- 494
				ring = false, -- 494
				model = "Planet_Uranus" -- 494
			}, -- 494
			{ -- 495
				r = 0.34, -- 495
				g = 0.5, -- 495
				b = 0.86, -- 495
				displayRadius = R_NEPTUNE, -- 495
				ring = false, -- 495
				model = "Planet_Neptune" -- 495
			} -- 495
		}, -- 495
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 50, label = "土星"}, {planetIndex = 3, tolerance = 60, label = "天王星"}, {planetIndex = 4, tolerance = 70, label = "海王星"}}}, -- 498
		dvBudget = 55, -- 513
		escapeRadius = 700, -- 514
		maxSteps = 2400, -- 515
		homeRadius = 1.25 -- 516
	}, -- 516
	{ -- 518
		id = 6, -- 519
		title = "单程", -- 520
		brief = "航行日志 · 第 12 年：没有回程了。四颗巨行星还会连成一条线 —— 等到那一天（拖动时间轴），沿着这条线依次穿过去，再越过 260 单位，就是星际空间。", -- 521
		probeStart = {x = 0, y = ORBIT.earth}, -- 522
		planets = { -- 523
			sun(), -- 524
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 29.3), -- 530
			orbiter(2000, R_SATURN, ORBIT.saturn, 48.2), -- 531
			orbiter(1200, R_URANUS, ORBIT.uranus, 58.9), -- 532
			orbiter(8000, R_NEPTUNE, ORBIT.neptune, 65.7) -- 533
		}, -- 533
		visuals = { -- 535
			sunVisual(), -- 536
			{ -- 537
				r = 0.85, -- 537
				g = 0.72, -- 537
				b = 0.5, -- 537
				displayRadius = R_JUPITER, -- 537
				ring = false, -- 537
				model = "Planet_Jupiter" -- 537
			}, -- 537
			{ -- 538
				r = 0.75, -- 538
				g = 0.7, -- 538
				b = 0.6, -- 538
				displayRadius = R_SATURN, -- 538
				ring = true, -- 538
				model = "Planet_Saturn" -- 538
			}, -- 538
			{ -- 539
				r = 0.62, -- 539
				g = 0.82, -- 539
				b = 0.86, -- 539
				displayRadius = R_URANUS, -- 539
				ring = false, -- 539
				model = "Planet_Uranus" -- 539
			}, -- 539
			{ -- 540
				r = 0.34, -- 540
				g = 0.5, -- 540
				b = 0.86, -- 540
				displayRadius = R_NEPTUNE, -- 540
				ring = false, -- 540
				model = "Planet_Neptune" -- 540
			} -- 540
		}, -- 540
		goal = {kind = "escape", planetIndex = -1, tolerance = 0, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 50, label = "土星"}, {planetIndex = 3, tolerance = 60, label = "天王星"}, {planetIndex = 4, tolerance = 70, label = "海王星"}}}, -- 548
		dvBudget = 50, -- 560
		escapeRadius = 260, -- 561
		maxSteps = 2400, -- 562
		homeRadius = 1, -- 563
		timeWindow = {span = 300} -- 567
	} -- 567
} -- 567
--- 关卡总数。
function ____exports.levelCount() -- 572
	return #LEVELS -- 573
end -- 572
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 577
	return LEVELS[index + 1] -- 578
end -- 577
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 582
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 583
end -- 582
return ____exports -- 582