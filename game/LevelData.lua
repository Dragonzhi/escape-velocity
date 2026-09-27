-- [ts]: LevelData.ts
local ____exports = {} -- 1
local applyScalesLocal -- 1
local ____Gravity = require("game.Gravity") -- 28
local bodyPositionAt = ____Gravity.bodyPositionAt -- 28
local distance = ____Gravity.distance -- 28
local ____Config = require("game.Config") -- 29
local GravityScale = ____Config.GravityScale -- 29
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 29
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 611
	local out = {} -- 612
	for ____, b in ipairs(bodies) do -- 613
		out[#out + 1] = { -- 614
			gm = b.gm * gravityScale, -- 615
			radius = b.radius, -- 616
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 617
			orbitRadius = b.orbitRadius, -- 618
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 619
			phase0 = b.phase0, -- 620
			orbitDirection = b.orbitDirection, -- 621
			host = b.host ~= nil and applyScalesLocal({b.host}, gravityScale, orbitScale)[1] or nil -- 623
		} -- 623
	end -- 623
	return out -- 626
end -- 626
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
local R_VENUS = 1.72 -- 160
local R_EARTH = 1.76 -- 161
local R_JUPITER = 4.63 -- 162
local R_SATURN = 4.3 -- 163
local R_URANUS = 3.04 -- 164
local R_NEPTUNE = 3 -- 165
--- 巡航轨道半径（压缩太阳系：顺序真实、比例压缩）—— 一律绕原点（太阳）。
local ORBIT = { -- 168
	venus = 55, -- 168
	earth = 80, -- 168
	jupiter = 105, -- 168
	saturn = 135, -- 168
	uranus = 165, -- 168
	neptune = 195 -- 168
} -- 168
--- 掠过环的容差（flyby）：比本体大 13 左右 —— 远距离飞行要有"够得着"的手感。
local FLYBY_PAD = 13 -- 171
--- 行星自身在时刻 t 的速度（圆轨道 = 位置的导数）。
-- 捕获判据要的是"**相对**行星的速度" —— 行星自己也在跑（虽然慢）。
function ____exports.bodyVelocityAt(b, t) -- 184
	if b.orbitPeriod == 0 or b.orbitRadius <= 0 then -- 184
		return {x = 0, y = 0} -- 185
	end -- 185
	local angle = b.phase0 + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 186
	local w = b.orbitDirection * 2 * math.pi / b.orbitPeriod -- 187
	return { -- 188
		x = -math.sin(angle) * b.orbitRadius * w, -- 188
		y = math.cos(angle) * b.orbitRadius * w -- 188
	} -- 188
end -- 184
function ____exports.goalWaypoints(goal) -- 191
	if goal.chain ~= nil then -- 191
		return goal.chain -- 192
	end -- 192
	if goal.kind == "planet" then -- 192
		return {{planetIndex = goal.planetIndex, tolerance = goal.tolerance}} -- 193
	end -- 193
	return {} -- 194
end -- 191
--- 采样点 i 处、相对某天体的速度（捕获判据与诊断共用同一份实现）。
-- 
-- points 里只有位置 ⇒ 用相邻采样点差分；`dt` 是**相邻采样点之间的有效步长**。
-- `limit` 是最后一个有效采样点索引（末端夹紧用）。
function ____exports.relativeSpeedAt(points, i, body, dt, t0, limit, velocities) -- 209
	local vx = 0 -- 210
	local vy = 0 -- 211
	if velocities ~= nil and velocities[i + 1] ~= nil then -- 211
		vx = velocities[i + 1].x -- 214
		vy = velocities[i + 1].y -- 215
	else -- 215
		local j1 = i + 1 <= limit and i + 1 or i -- 219
		local j0 = i > 0 and i - 1 or i -- 220
		local spanT = (j1 - j0) * dt -- 221
		if spanT > 0 then -- 221
			vx = (points[j1 + 1].x - points[j0 + 1].x) / spanT -- 223
			vy = (points[j1 + 1].y - points[j0 + 1].y) / spanT -- 224
		end -- 224
	end -- 224
	local pv = ____exports.bodyVelocityAt(body, t0) -- 227
	local rx = vx - pv.x -- 228
	local ry = vy - pv.y -- 229
	return math.sqrt(rx * rx + ry * ry) -- 230
end -- 209
--- 捕获阈值：该处逃逸速度（圆轨道速度 × 系数 k，k 默认 √2）。
function ____exports.captureThreshold(body, d, k) -- 234
	if body.gm <= 0 or d <= 0.000001 then -- 234
		return 1000000000 -- 235
	end -- 235
	return k * math.sqrt(body.gm / d) -- 236
end -- 234
function ____exports.waypointProgress(points, bodies, goal, dt, t0, upto, velocities) -- 239
	local wps = ____exports.goalWaypoints(goal) -- 249
	local start = t0 ~= nil and t0 or 0 -- 250
	local limit = #points - 1 -- 251
	if upto ~= nil and upto >= 0 and upto < limit then -- 251
		limit = upto -- 252
	end -- 252
	local next = 0 -- 253
	local lastIndex = -1 -- 254
	do -- 254
		local i = 0 -- 255
		while i <= limit and next < #wps do -- 255
			do -- 255
				local w = wps[next + 1] -- 256
				local body = bodies[w.planetIndex + 1] -- 257
				if body == nil then -- 257
					return {passed = 0, lastIndex = -1} -- 258
				end -- 258
				local gp = bodyPositionAt(body, start + i * dt) -- 259
				if distance(points[i + 1], gp) < w.tolerance then -- 259
					if w.capture == true then -- 259
						local k = w.captureFactor ~= nil and w.captureFactor or 1.4142135623730951 -- 265
						local d = distance(points[i + 1], gp) -- 266
						if d <= body.radius then -- 266
							goto __continue19 -- 270
						end -- 270
						local rel = ____exports.relativeSpeedAt( -- 271
							points, -- 271
							i, -- 271
							body, -- 271
							dt, -- 271
							start + i * dt, -- 271
							limit, -- 271
							velocities -- 271
						) -- 271
						if rel > ____exports.captureThreshold(body, d, k) then -- 271
							goto __continue19 -- 272
						end -- 272
					end -- 272
					next = next + 1 -- 274
					lastIndex = i -- 275
				end -- 275
			end -- 275
			::__continue19:: -- 275
			i = i + 1 -- 255
		end -- 255
	end -- 255
	return {passed = next, lastIndex = lastIndex} -- 278
end -- 239
function ____exports.findGoalIndex(points, bodies, goal, dt, t0, velocities) -- 281
	local wps = ____exports.goalWaypoints(goal) -- 282
	if #wps == 0 then -- 282
		return -1 -- 283
	end -- 283
	local st = ____exports.waypointProgress( -- 284
		points, -- 284
		bodies, -- 284
		goal, -- 284
		dt, -- 284
		t0, -- 284
		nil, -- 284
		velocities -- 284
	) -- 284
	return st.passed >= #wps and st.lastIndex or -1 -- 285
end -- 281
--- 太阳（除 L1 外每关的第 0 号天体）。
local function sun() -- 293
	return { -- 294
		gm = ____exports.SunGm, -- 294
		radius = ____exports.SunRadius, -- 294
		orbitCenter = {x = 0, y = 0}, -- 294
		orbitRadius = 0, -- 294
		orbitPeriod = 0, -- 294
		phase0 = 0, -- 294
		orbitDirection = 1 -- 294
	} -- 294
end -- 293
--- 太阳的视觉（亮黄，模型 Sun.glb）。
local function sunVisual() -- 298
	return { -- 302
		r = 1, -- 302
		g = 0.97, -- 302
		b = 0.88, -- 302
		displayRadius = ____exports.SunRadius, -- 302
		ring = false, -- 302
		model = "Sun", -- 302
		emissive = {r = 1, g = 0.95, b = 0.82} -- 302
	} -- 302
end -- 298
--- 绕日公转的行星（S3.7：圆心 = 太阳 = 原点）。
local function orbiter(gm, radius, orbitRadius, phaseDeg) -- 306
	return { -- 307
		gm = gm, -- 308
		radius = radius, -- 308
		orbitCenter = {x = 0, y = 0}, -- 309
		orbitRadius = orbitRadius, -- 310
		orbitPeriod = ____exports.keplerPeriod(orbitRadius), -- 311
		phase0 = deg(phaseDeg), -- 312
		orbitDirection = 1 -- 313
	} -- 313
end -- 306
--- 绕**会动的行星**公转的卫星（S3.13，L1 的月球）：
-- 直接把宿主天体对象传进来，位置就随宿主一起走（见 Gravity.Body.host）。
-- `periodSec` 显式给：月球绕地球的周期不该用"绕日开普勒"算，而要与**全局时间压缩**一致
-- （本作 K = 1.0 = 真实周期 ÷ 42.7）。
local function satellite(gm, radius, host, orbitRadius, phaseDeg, periodSec) -- 323
	return { -- 324
		gm = gm, -- 325
		radius = radius, -- 325
		orbitCenter = {x = 0, y = 0}, -- 326
		orbitRadius = orbitRadius, -- 327
		orbitPeriod = periodSec, -- 328
		phase0 = deg(phaseDeg), -- 329
		orbitDirection = 1, -- 330
		host = host -- 331
	} -- 331
end -- 323
--- L1 的地球（S3.13）：它是**真天体**，而且**自己在绕日公转** —— 这是"物理统一"的试纸。
-- 月球用它当 host（见 satellite），于是"月球绕地球、地球绕日"两件事同时成立。
local L1_EARTH = { -- 339
	gm = 2600, -- 340
	radius = R_EARTH, -- 341
	orbitCenter = {x = 0, y = 0}, -- 342
	orbitRadius = ORBIT.earth, -- 343
	orbitPeriod = ____exports.keplerPeriod(ORBIT.earth), -- 344
	phase0 = deg(90), -- 345
	orbitDirection = 1 -- 346
} -- 346
--- L1 的月球：绕上面那颗**会动的**地球公转，周期 276 秒（见 satellite 的说明）。
local L1_MOON_ORBIT_R = 15 -- 350
local L1_MOON_PERIOD = 120 -- 355
local LEVELS = { -- 357
	{ -- 358
		id = 1, -- 359
		title = "出发", -- 360
		brief = "航行日志 · 第 1 天：地球轨道。探测器在你手里 —— 月球正在绕地球走，别对着它现在的位置打。这一次点火决定后面的一切。", -- 366
		probeStart = {x = 0, y = 90}, -- 367
		probeVel0 = {x = 16.12, y = 0}, -- 375
		homeAnchor = false, -- 376
		planets = { -- 377
			sun(), -- 378
			L1_EARTH, -- 379
			satellite( -- 382
				0, -- 382
				R_MOON, -- 382
				L1_EARTH, -- 382
				L1_MOON_ORBIT_R, -- 382
				180, -- 382
				L1_MOON_PERIOD -- 382
			) -- 382
		}, -- 382
		visuals = { -- 384
			sunVisual(), -- 385
			{ -- 386
				r = 0.42, -- 386
				g = 0.62, -- 386
				b = 0.85, -- 386
				displayRadius = R_EARTH, -- 386
				ring = false, -- 386
				model = "Planet_Earth" -- 386
			}, -- 386
			{ -- 387
				r = 0.56, -- 387
				g = 0.56, -- 387
				b = 0.6, -- 387
				displayRadius = R_MOON, -- 387
				ring = false -- 387
			} -- 387
		}, -- 387
		goal = {kind = "planet", planetIndex = 2, tolerance = 5}, -- 393
		dvBudget = 45, -- 394
		escapeRadius = 700, -- 395
		maxSteps = 1200, -- 396
		homeRadius = 1.75, -- 397
		timeWindow = {span = 60} -- 400
	}, -- 400
	{ -- 402
		id = 2, -- 403
		title = "修正", -- 404
		brief = "航行日志 · 第 12 天：太阳开始拽你了。别直着飞 —— 向内会加速，航线也会被掰弯。目标是掠过金星。", -- 405
		probeStart = {x = 0, y = ORBIT.earth}, -- 406
		planets = { -- 407
			sun(), -- 408
			orbiter(2600, R_VENUS, ORBIT.venus, 180) -- 410
		}, -- 410
		visuals = { -- 412
			sunVisual(), -- 413
			{ -- 414
				r = 0.9, -- 414
				g = 0.78, -- 414
				b = 0.55, -- 414
				displayRadius = R_VENUS, -- 414
				ring = false, -- 414
				model = "Planet_Venus" -- 414
			} -- 414
		}, -- 414
		goal = {kind = "planet", planetIndex = 1, tolerance = R_VENUS + FLYBY_PAD}, -- 416
		dvBudget = 45, -- 417
		escapeRadius = 700, -- 418
		maxSteps = 1500, -- 419
		homeRadius = 1.6 -- 420
	}, -- 420
	{ -- 422
		id = 3, -- 423
		title = "弹弓", -- 424
		brief = "航行日志 · 第 2 年：木星在外圈。想省力就从它背后绕过去 —— 它的引力会把你甩向土星。", -- 425
		probeStart = {x = 0, y = ORBIT.earth}, -- 426
		planets = { -- 427
			sun(), -- 428
			orbiter(4000, R_JUPITER, ORBIT.jupiter, 89.4), -- 435
			orbiter(12000, R_SATURN, ORBIT.saturn, 89) -- 437
		}, -- 437
		visuals = { -- 439
			sunVisual(), -- 440
			{ -- 441
				r = 0.85, -- 441
				g = 0.72, -- 441
				b = 0.5, -- 441
				displayRadius = R_JUPITER, -- 441
				ring = false, -- 441
				model = "Planet_Jupiter" -- 441
			}, -- 441
			{ -- 442
				r = 0.75, -- 442
				g = 0.7, -- 442
				b = 0.6, -- 442
				displayRadius = R_SATURN, -- 442
				ring = true, -- 442
				model = "Planet_Saturn" -- 442
			} -- 442
		}, -- 442
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + 22, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 45, label = "土星"}}}, -- 445
		dvBudget = 55, -- 454
		escapeRadius = 700, -- 455
		maxSteps = 2400, -- 456
		homeRadius = 1.45 -- 457
	}, -- 457
	{ -- 459
		id = 4, -- 460
		title = "窗口", -- 461
		brief = "航行日志 · 第 3 年：木星一直在绕太阳走。挑一个它正好在你航线上的日期起飞 —— 拖动时间轴，看它挪位置。", -- 462
		probeStart = {x = 0, y = ORBIT.earth}, -- 463
		planets = { -- 464
			sun(), -- 465
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 29.3), -- 473
			orbiter(12000, R_SATURN, ORBIT.saturn, 48.2) -- 474
		}, -- 474
		visuals = { -- 476
			sunVisual(), -- 477
			{ -- 478
				r = 0.85, -- 478
				g = 0.72, -- 478
				b = 0.5, -- 478
				displayRadius = R_JUPITER, -- 478
				ring = false, -- 478
				model = "Planet_Jupiter" -- 478
			}, -- 478
			{ -- 479
				r = 0.75, -- 479
				g = 0.7, -- 479
				b = 0.6, -- 479
				displayRadius = R_SATURN, -- 479
				ring = true, -- 479
				model = "Planet_Saturn" -- 479
			} -- 479
		}, -- 479
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 30, label = "土星", capture = true}}}, -- 482
		dvBudget = 50, -- 489
		escapeRadius = 700, -- 490
		maxSteps = 1800, -- 491
		homeRadius = 1.35, -- 492
		timeWindow = {span = 300} -- 496
	}, -- 496
	{ -- 498
		id = 5, -- 499
		title = "大巡游", -- 500
		brief = "航行日志 · 第 5 年：一次点火，四颗巨行星。木星改向、土星续航、天王星微调 —— 最后到海王星。", -- 501
		probeStart = {x = 0, y = ORBIT.earth}, -- 502
		planets = { -- 503
			sun(), -- 504
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 89.5), -- 509
			orbiter(2000, R_SATURN, ORBIT.saturn, 89.5), -- 510
			orbiter(1200, R_URANUS, ORBIT.uranus, 89.5), -- 511
			orbiter(8000, R_NEPTUNE, ORBIT.neptune, 89.5) -- 512
		}, -- 512
		visuals = { -- 514
			sunVisual(), -- 515
			{ -- 516
				r = 0.85, -- 516
				g = 0.72, -- 516
				b = 0.5, -- 516
				displayRadius = R_JUPITER, -- 516
				ring = false, -- 516
				model = "Planet_Jupiter" -- 516
			}, -- 516
			{ -- 517
				r = 0.75, -- 517
				g = 0.7, -- 517
				b = 0.6, -- 517
				displayRadius = R_SATURN, -- 517
				ring = true, -- 517
				model = "Planet_Saturn" -- 517
			}, -- 517
			{ -- 518
				r = 0.62, -- 518
				g = 0.82, -- 518
				b = 0.86, -- 518
				displayRadius = R_URANUS, -- 518
				ring = false, -- 518
				model = "Planet_Uranus" -- 518
			}, -- 518
			{ -- 519
				r = 0.34, -- 519
				g = 0.5, -- 519
				b = 0.86, -- 519
				displayRadius = R_NEPTUNE, -- 519
				ring = false, -- 519
				model = "Planet_Neptune" -- 519
			} -- 519
		}, -- 519
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 50, label = "土星"}, {planetIndex = 3, tolerance = 60, label = "天王星"}, {planetIndex = 4, tolerance = 70, label = "海王星"}}}, -- 522
		dvBudget = 55, -- 537
		escapeRadius = 700, -- 538
		maxSteps = 2400, -- 539
		homeRadius = 1.25 -- 540
	}, -- 540
	{ -- 542
		id = 6, -- 543
		title = "单程", -- 544
		brief = "航行日志 · 第 12 年：没有回程了。四颗巨行星还会连成一条线 —— 等到那一天（拖动时间轴），沿着这条线依次穿过去，再越过 260 单位，就是星际空间。", -- 545
		probeStart = {x = 0, y = ORBIT.earth}, -- 546
		planets = { -- 547
			sun(), -- 548
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 29.3), -- 554
			orbiter(2000, R_SATURN, ORBIT.saturn, 48.2), -- 555
			orbiter(1200, R_URANUS, ORBIT.uranus, 58.9), -- 556
			orbiter(8000, R_NEPTUNE, ORBIT.neptune, 65.7) -- 557
		}, -- 557
		visuals = { -- 559
			sunVisual(), -- 560
			{ -- 561
				r = 0.85, -- 561
				g = 0.72, -- 561
				b = 0.5, -- 561
				displayRadius = R_JUPITER, -- 561
				ring = false, -- 561
				model = "Planet_Jupiter" -- 561
			}, -- 561
			{ -- 562
				r = 0.75, -- 562
				g = 0.7, -- 562
				b = 0.6, -- 562
				displayRadius = R_SATURN, -- 562
				ring = true, -- 562
				model = "Planet_Saturn" -- 562
			}, -- 562
			{ -- 563
				r = 0.62, -- 563
				g = 0.82, -- 563
				b = 0.86, -- 563
				displayRadius = R_URANUS, -- 563
				ring = false, -- 563
				model = "Planet_Uranus" -- 563
			}, -- 563
			{ -- 564
				r = 0.34, -- 564
				g = 0.5, -- 564
				b = 0.86, -- 564
				displayRadius = R_NEPTUNE, -- 564
				ring = false, -- 564
				model = "Planet_Neptune" -- 564
			} -- 564
		}, -- 564
		goal = {kind = "escape", planetIndex = -1, tolerance = 0, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 50, label = "土星"}, {planetIndex = 3, tolerance = 60, label = "天王星"}, {planetIndex = 4, tolerance = 70, label = "海王星"}}}, -- 572
		dvBudget = 50, -- 584
		escapeRadius = 260, -- 585
		maxSteps = 2400, -- 586
		homeRadius = 1, -- 587
		timeWindow = {span = 300} -- 591
	} -- 591
} -- 591
--- 关卡总数。
function ____exports.levelCount() -- 596
	return #LEVELS -- 597
end -- 596
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 601
	return LEVELS[index + 1] -- 602
end -- 601
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 606
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 607
end -- 606
return ____exports -- 606