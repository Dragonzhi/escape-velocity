-- [ts]: LevelData.ts
local ____exports = {} -- 1
local applyScalesLocal -- 1
local ____Gravity = require("game.Gravity") -- 28
local bodyPositionAt = ____Gravity.bodyPositionAt -- 28
local distance = ____Gravity.distance -- 28
local ____Config = require("game.Config") -- 29
local GravityScale = ____Config.GravityScale -- 29
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 29
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 622
	local out = {} -- 623
	for ____, b in ipairs(bodies) do -- 624
		out[#out + 1] = { -- 625
			gm = b.gm * gravityScale, -- 626
			radius = b.radius, -- 627
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 628
			orbitRadius = b.orbitRadius, -- 629
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 630
			phase0 = b.phase0, -- 631
			orbitDirection = b.orbitDirection, -- 632
			host = b.host ~= nil and applyScalesLocal({b.host}, gravityScale, orbitScale)[1] or nil -- 634
		} -- 634
	end -- 634
	return out -- 637
end -- 637
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
--- 引力强度表（S3.13 六站重排）。
-- 
-- ⚠️ 这些是**玩法参数**，不是真实比值：真实木星是地球的 318 倍，这里只有 ~1 倍。
-- 按真实比值，木星会在 40 单位外就把探测器抓住，「绕日弧线」这条主玩法就没了。
-- 但**同一颗行星在六关里必须是同一个值** —— 否则玩家在 L3 学到的「木星能把我掰多少」，
-- 到 L5 就不成立了，那正是「物理不统一」最容易被玩家看出来的地方。
local GM = { -- 181
	venus = 2600, -- 181
	jupiter = 2500, -- 181
	saturn = 12000, -- 181
	uranus = 1200, -- 181
	neptune = 8000 -- 181
} -- 181
--- 行星自身在时刻 t 的速度（圆轨道 = 位置的导数）。
-- 捕获判据要的是"**相对**行星的速度" —— 行星自己也在跑（虽然慢）。
function ____exports.bodyVelocityAt(b, t) -- 194
	if b.orbitPeriod == 0 or b.orbitRadius <= 0 then -- 194
		return {x = 0, y = 0} -- 195
	end -- 195
	local angle = b.phase0 + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 196
	local w = b.orbitDirection * 2 * math.pi / b.orbitPeriod -- 197
	return { -- 198
		x = -math.sin(angle) * b.orbitRadius * w, -- 198
		y = math.cos(angle) * b.orbitRadius * w -- 198
	} -- 198
end -- 194
function ____exports.goalWaypoints(goal) -- 201
	if goal.chain ~= nil then -- 201
		return goal.chain -- 202
	end -- 202
	if goal.kind == "planet" then -- 202
		return {{planetIndex = goal.planetIndex, tolerance = goal.tolerance}} -- 203
	end -- 203
	return {} -- 204
end -- 201
--- 采样点 i 处、相对某天体的速度（捕获判据与诊断共用同一份实现）。
-- 
-- points 里只有位置 ⇒ 用相邻采样点差分；`dt` 是**相邻采样点之间的有效步长**。
-- `limit` 是最后一个有效采样点索引（末端夹紧用）。
function ____exports.relativeSpeedAt(points, i, body, dt, t0, limit, velocities) -- 219
	local vx = 0 -- 220
	local vy = 0 -- 221
	if velocities ~= nil and velocities[i + 1] ~= nil then -- 221
		vx = velocities[i + 1].x -- 224
		vy = velocities[i + 1].y -- 225
	else -- 225
		local j1 = i + 1 <= limit and i + 1 or i -- 229
		local j0 = i > 0 and i - 1 or i -- 230
		local spanT = (j1 - j0) * dt -- 231
		if spanT > 0 then -- 231
			vx = (points[j1 + 1].x - points[j0 + 1].x) / spanT -- 233
			vy = (points[j1 + 1].y - points[j0 + 1].y) / spanT -- 234
		end -- 234
	end -- 234
	local pv = ____exports.bodyVelocityAt(body, t0) -- 237
	local rx = vx - pv.x -- 238
	local ry = vy - pv.y -- 239
	return math.sqrt(rx * rx + ry * ry) -- 240
end -- 219
--- 捕获阈值：该处逃逸速度（圆轨道速度 × 系数 k，k 默认 √2）。
function ____exports.captureThreshold(body, d, k) -- 244
	if body.gm <= 0 or d <= 0.000001 then -- 244
		return 1000000000 -- 245
	end -- 245
	return k * math.sqrt(body.gm / d) -- 246
end -- 244
function ____exports.waypointProgress(points, bodies, goal, dt, t0, upto, velocities) -- 249
	local wps = ____exports.goalWaypoints(goal) -- 259
	local start = t0 ~= nil and t0 or 0 -- 260
	local limit = #points - 1 -- 261
	if upto ~= nil and upto >= 0 and upto < limit then -- 261
		limit = upto -- 262
	end -- 262
	local next = 0 -- 263
	local lastIndex = -1 -- 264
	do -- 264
		local i = 0 -- 265
		while i <= limit and next < #wps do -- 265
			do -- 265
				local w = wps[next + 1] -- 266
				local body = bodies[w.planetIndex + 1] -- 267
				if body == nil then -- 267
					return {passed = 0, lastIndex = -1} -- 268
				end -- 268
				local gp = bodyPositionAt(body, start + i * dt) -- 269
				if distance(points[i + 1], gp) < w.tolerance then -- 269
					if w.capture == true then -- 269
						local k = w.captureFactor ~= nil and w.captureFactor or 1.4142135623730951 -- 275
						local d = distance(points[i + 1], gp) -- 276
						if d <= body.radius then -- 276
							goto __continue19 -- 280
						end -- 280
						local rel = ____exports.relativeSpeedAt( -- 281
							points, -- 281
							i, -- 281
							body, -- 281
							dt, -- 281
							start + i * dt, -- 281
							limit, -- 281
							velocities -- 281
						) -- 281
						if rel > ____exports.captureThreshold(body, d, k) then -- 281
							goto __continue19 -- 282
						end -- 282
					end -- 282
					next = next + 1 -- 284
					lastIndex = i -- 285
				end -- 285
			end -- 285
			::__continue19:: -- 285
			i = i + 1 -- 265
		end -- 265
	end -- 265
	return {passed = next, lastIndex = lastIndex} -- 288
end -- 249
function ____exports.findGoalIndex(points, bodies, goal, dt, t0, velocities) -- 291
	local wps = ____exports.goalWaypoints(goal) -- 292
	if #wps == 0 then -- 292
		return -1 -- 293
	end -- 293
	local st = ____exports.waypointProgress( -- 294
		points, -- 294
		bodies, -- 294
		goal, -- 294
		dt, -- 294
		t0, -- 294
		nil, -- 294
		velocities -- 294
	) -- 294
	return st.passed >= #wps and st.lastIndex or -1 -- 295
end -- 291
--- 太阳（每关的第 0 号天体）。
local function sun() -- 319
	return { -- 320
		gm = ____exports.SunGm, -- 320
		radius = ____exports.SunRadius, -- 320
		orbitCenter = {x = 0, y = 0}, -- 320
		orbitRadius = 0, -- 320
		orbitPeriod = 0, -- 320
		phase0 = 0, -- 320
		orbitDirection = 1 -- 320
	} -- 320
end -- 319
--- 太阳的视觉（亮黄，模型 Sun.glb）。
local function sunVisual() -- 324
	return { -- 327
		r = 1, -- 327
		g = 0.97, -- 327
		b = 0.88, -- 327
		displayRadius = ____exports.SunRadius, -- 327
		ring = false, -- 327
		model = "Sun", -- 327
		emissive = {r = 1, g = 0.95, b = 0.82} -- 327
	} -- 327
end -- 324
--- 绕日公转的行星（圆心 = 太阳 = 原点）。
local function orbiter(gm, radius, orbitRadius, phaseDeg) -- 331
	return { -- 332
		gm = gm, -- 333
		radius = radius, -- 333
		orbitCenter = {x = 0, y = 0}, -- 334
		orbitRadius = orbitRadius, -- 335
		orbitPeriod = ____exports.keplerPeriod(orbitRadius), -- 336
		phase0 = deg(phaseDeg), -- 337
		orbitDirection = 1 -- 338
	} -- 338
end -- 331
--- 绕**会动的行星**公转的卫星（S3.13）：直接把宿主天体对象传进来，位置就随宿主一起走
-- （见 Gravity.Body.host）。periodSec 显式给 —— 月球绕地球的周期不该用「绕日开普勒」算，
-- 而要与**全局时间压缩**一致（本作 K = 1.0 = 真实周期 ÷ 42.7）。
local function satellite(gm, radius, host, orbitRadius, phaseDeg, periodSec) -- 347
	return { -- 348
		gm = gm, -- 349
		radius = radius, -- 349
		orbitCenter = {x = 0, y = 0}, -- 350
		orbitRadius = orbitRadius, -- 351
		orbitPeriod = periodSec, -- 352
		phase0 = deg(phaseDeg), -- 353
		orbitDirection = 1, -- 354
		host = host -- 355
	} -- 355
end -- 347
--- 家园地球（L2–L6 的布景天体）：**沿自己的轨道走**，但不参与引力。
-- 
-- 为什么 gm = 0：每关都从**地球轨道上的一点**出发（probeStart 固定在 (0,80)），
-- 如果这颗地球带引力，出发点就在它 8 个单位以内 —— 那就等于「从地球引力井里起飞」
-- （a ≈ 37 单位/秒²，一秒内就能把你甩飞），六关的几何 / 相位 / 容差全部要重解；
-- 而太阳系其余部分是按 KeplerK = 1 压缩过的：地球近在咫尺、别处却那么慢，那不是统一物理。
-- 所以它是「**看得见的家**」，不是「拉得动你的家」。真天体的地球在 L1（gm 2600）。
-- 
-- ⚠️ 相位 100° 是**挑过的**：出发点在 90°，地球领先 10°（约 14 单位，视觉上「家就在前面」）。
-- 为什么不能随便放：撞毁判定只看半径、**不看 gm**（Gravity.bodyHitIndex），所以地球一旦挪到
-- 出发点上，那一天一进关探测器就直接生成在地球内部。它在时间轴里最多走 151°（span 300 秒），
-- 所以只要让 [phase0, phase0+151°] 不跨过 90°±3° 就行 —— 100° 满足，而且对六关所有 span 都满足。
local function homeEarth() -- 373
	return { -- 374
		gm = 0, -- 375
		radius = R_EARTH, -- 375
		orbitCenter = {x = 0, y = 0}, -- 376
		orbitRadius = ORBIT.earth, -- 377
		orbitPeriod = ____exports.keplerPeriod(ORBIT.earth), -- 378
		phase0 = deg(100), -- 379
		orbitDirection = 1 -- 380
	} -- 380
end -- 373
--- 地球（家园）：蓝绿。
local function earthVisual() -- 388
	return { -- 389
		r = 0.42, -- 389
		g = 0.62, -- 389
		b = 0.85, -- 389
		displayRadius = R_EARTH, -- 389
		ring = false, -- 389
		model = "Planet_Earth" -- 389
	} -- 389
end -- 388
--- 月球（L1）：S3.14 交付了 Moon.glb（5040 面 + moon.jpg 环形山贴图）。
local function moonVisual() -- 392
	return { -- 393
		r = 0.56, -- 393
		g = 0.56, -- 393
		b = 0.6, -- 393
		displayRadius = R_MOON, -- 393
		ring = false, -- 393
		model = "Moon" -- 393
	} -- 393
end -- 392
--- 金星：暖黄的硫酸云。
local function venusVisual() -- 396
	return { -- 397
		r = 0.9, -- 397
		g = 0.78, -- 397
		b = 0.55, -- 397
		displayRadius = R_VENUS, -- 397
		ring = false, -- 397
		model = "Planet_Venus" -- 397
	} -- 397
end -- 396
--- 木星：条纹橙褐。
local function jupiterVisual() -- 400
	return { -- 401
		r = 0.85, -- 401
		g = 0.72, -- 401
		b = 0.5, -- 401
		displayRadius = R_JUPITER, -- 401
		ring = false, -- 401
		model = "Planet_Jupiter" -- 401
	} -- 401
end -- 400
--- 土星：淡金 + 环。
local function saturnVisual() -- 404
	return { -- 405
		r = 0.75, -- 405
		g = 0.7, -- 405
		b = 0.6, -- 405
		displayRadius = R_SATURN, -- 405
		ring = true, -- 405
		model = "Planet_Saturn" -- 405
	} -- 405
end -- 404
--- 天王星：青蓝。
local function uranusVisual() -- 408
	return { -- 409
		r = 0.62, -- 409
		g = 0.82, -- 409
		b = 0.86, -- 409
		displayRadius = R_URANUS, -- 409
		ring = false, -- 409
		model = "Planet_Uranus" -- 409
	} -- 409
end -- 408
--- 海王星：深蓝。
local function neptuneVisual() -- 412
	return { -- 413
		r = 0.34, -- 413
		g = 0.5, -- 413
		b = 0.86, -- 413
		displayRadius = R_NEPTUNE, -- 413
		ring = false, -- 413
		model = "Planet_Neptune" -- 413
	} -- 413
end -- 412
--- L1 的地球（S3.13）：它是**真天体**，而且**自己在绕日公转** —— 这是「物理统一」的试纸。
-- 月球用它当 host（见 satellite），于是「月球绕地球、地球绕日」两件事同时成立。
local L1_EARTH = { -- 420
	gm = 2600, -- 421
	radius = R_EARTH, -- 422
	orbitCenter = {x = 0, y = 0}, -- 423
	orbitRadius = ORBIT.earth, -- 424
	orbitPeriod = ____exports.keplerPeriod(ORBIT.earth), -- 425
	phase0 = deg(90), -- 426
	orbitDirection = 1 -- 427
} -- 427
--- L1 的月球：绕上面那颗**会动的**地球公转。
-- 
-- ⚠️ 周期是**玩法参数**，不是物理常数：15 单位的轨道如果按「与全局时间压缩一致」取 276 秒，
-- 月球在 60 秒的时间轴里只走 78°，每个日期都打得到 —— 窗口就没有意义了（实测每个 t0 都有解）。
-- 取 120 秒 ⇒ 60 秒跨度 = 它走过 **180°**，「挑时机」才真的成立；
-- 飞行 2 秒里的漂移 = 6°，远小于容差，不会让瞄准变难。
local L1_MOON_ORBIT_R = 15 -- 438
local L1_MOON_PERIOD = 120 -- 439
local LEVELS = { -- 441
	{ -- 442
		id = 1, -- 443
		title = "月球", -- 444
		probeVariant = "solar", -- 445
		brief = "月球任务 · 地球轨道：月球正在绕地球走 —— 别对着它现在的位置点火。这一次点火决定后面的一切。", -- 447
		probeStart = {x = 0, y = 90}, -- 453
		probeVel0 = {x = 16.12, y = 0}, -- 454
		planets = { -- 455
			sun(), -- 456
			L1_EARTH, -- 457
			satellite( -- 459
				0, -- 459
				R_MOON, -- 459
				L1_EARTH, -- 459
				L1_MOON_ORBIT_R, -- 459
				0, -- 459
				L1_MOON_PERIOD -- 459
			) -- 459
		}, -- 459
		visuals = { -- 461
			sunVisual(), -- 461
			earthVisual(), -- 461
			moonVisual() -- 461
		}, -- 461
		goal = {kind = "planet", planetIndex = 2, tolerance = 5}, -- 463
		dvBudget = 45, -- 464
		escapeRadius = 700, -- 465
		maxSteps = 1200, -- 466
		timeWindow = {span = 60} -- 468
	}, -- 468
	{ -- 471
		id = 2, -- 472
		title = "金星", -- 473
		probeVariant = "solar", -- 474
		brief = "金星任务 · 地球轨道：太阳会一路把你拽快 —— 向内飞，别飞过头。金星在 55 单位的内圈上等着。", -- 475
		probeStart = {x = 0, y = ORBIT.earth}, -- 476
		planets = { -- 477
			sun(), -- 478
			homeEarth(), -- 479
			orbiter(GM.venus, R_VENUS, ORBIT.venus, 358.12) -- 482
		}, -- 482
		visuals = { -- 484
			sunVisual(), -- 484
			earthVisual(), -- 484
			venusVisual() -- 484
		}, -- 484
		goal = {kind = "planet", planetIndex = 2, tolerance = R_VENUS + FLYBY_PAD}, -- 486
		dvBudget = 45, -- 487
		escapeRadius = 700, -- 488
		maxSteps = 1500, -- 489
		timeWindow = {span = 240} -- 490
	}, -- 490
	{ -- 492
		id = 3, -- 493
		title = "木星", -- 494
		probeVariant = "solar", -- 495
		brief = "木星任务 · 地球轨道：第一次真正的行星际飞行。出发得够快，木星才会在你到达时出现在航线上。", -- 496
		probeStart = {x = 0, y = ORBIT.earth}, -- 497
		planets = { -- 498
			sun(), -- 499
			homeEarth(), -- 500
			orbiter(GM.jupiter, R_JUPITER, ORBIT.jupiter, 34.68) -- 504
		}, -- 504
		visuals = { -- 506
			sunVisual(), -- 506
			earthVisual(), -- 506
			jupiterVisual() -- 506
		}, -- 506
		goal = {kind = "planet", planetIndex = 2, tolerance = R_JUPITER + FLYBY_PAD}, -- 507
		dvBudget = 55, -- 508
		escapeRadius = 700, -- 509
		maxSteps = 2400, -- 510
		timeWindow = {span = 300} -- 511
	}, -- 511
	{ -- 513
		id = 4, -- 514
		title = "土星", -- 515
		probeVariant = "rtg", -- 516
		brief = "土星任务 · 地球轨道：先掠过木星，让它替你掰一下方向 —— 土星还在更外面。", -- 517
		probeStart = {x = 0, y = ORBIT.earth}, -- 518
		planets = { -- 519
			sun(), -- 520
			homeEarth(), -- 521
			orbiter(GM.jupiter, R_JUPITER, ORBIT.jupiter, 33.78), -- 522
			orbiter(GM.saturn, R_SATURN, ORBIT.saturn, 66.7) -- 523
		}, -- 523
		visuals = { -- 525
			sunVisual(), -- 525
			earthVisual(), -- 525
			jupiterVisual(), -- 525
			saturnVisual() -- 525
		}, -- 525
		goal = {kind = "planet", planetIndex = 3, tolerance = 45, chain = {{planetIndex = 2, tolerance = 30, label = "木星"}, {planetIndex = 3, tolerance = 45, label = "土星"}}}, -- 527
		dvBudget = 55, -- 534
		escapeRadius = 700, -- 535
		maxSteps = 2400, -- 536
		timeWindow = {span = 300} -- 537
	}, -- 537
	{ -- 539
		id = 5, -- 540
		title = "天王星", -- 541
		probeVariant = "rtg", -- 542
		brief = "天王星任务 · 地球轨道：木星、土星，两次借力，越飞越远。一次点火要串起三个节点。", -- 543
		probeStart = {x = 0, y = ORBIT.earth}, -- 544
		planets = { -- 545
			sun(), -- 546
			homeEarth(), -- 547
			orbiter(GM.jupiter, R_JUPITER, ORBIT.jupiter, 48.58), -- 548
			orbiter(GM.saturn, R_SATURN, ORBIT.saturn, 80), -- 549
			orbiter(GM.uranus, R_URANUS, ORBIT.uranus, 96.33) -- 550
		}, -- 550
		visuals = { -- 552
			sunVisual(), -- 552
			earthVisual(), -- 552
			jupiterVisual(), -- 552
			saturnVisual(), -- 552
			uranusVisual() -- 552
		}, -- 552
		goal = {kind = "planet", planetIndex = 4, tolerance = 60, chain = {{planetIndex = 2, tolerance = 40, label = "木星"}, {planetIndex = 3, tolerance = 50, label = "土星"}, {planetIndex = 4, tolerance = 60, label = "天王星"}}}, -- 554
		dvBudget = 55, -- 562
		escapeRadius = 700, -- 563
		maxSteps = 2400, -- 564
		timeWindow = {span = 300} -- 565
	}, -- 565
	{ -- 567
		id = 6, -- 568
		title = "海王星", -- 569
		probeVariant = "rtg", -- 570
		brief = "海王星任务 · 地球轨道：四颗巨行星连成一条线的那个日期。一次点火串到底，飞向 195 单位外的海王星。", -- 571
		probeStart = {x = 0, y = ORBIT.earth}, -- 572
		planets = { -- 573
			sun(), -- 574
			homeEarth(), -- 575
			orbiter(GM.jupiter, R_JUPITER, ORBIT.jupiter, 29.3), -- 580
			orbiter(GM.saturn, R_SATURN, ORBIT.saturn, 48.2), -- 581
			orbiter(GM.uranus, R_URANUS, ORBIT.uranus, 58.9), -- 582
			orbiter(GM.neptune, R_NEPTUNE, ORBIT.neptune, 65.7) -- 583
		}, -- 583
		visuals = { -- 585
			sunVisual(), -- 585
			earthVisual(), -- 585
			jupiterVisual(), -- 585
			saturnVisual(), -- 585
			uranusVisual(), -- 585
			neptuneVisual() -- 585
		}, -- 585
		goal = {kind = "planet", planetIndex = 5, tolerance = 70, chain = {{planetIndex = 2, tolerance = 40, label = "木星"}, {planetIndex = 3, tolerance = 50, label = "土星"}, {planetIndex = 4, tolerance = 60, label = "天王星"}, {planetIndex = 5, tolerance = 70, label = "海王星"}}}, -- 590
		dvBudget = 55, -- 599
		escapeRadius = 700, -- 600
		maxSteps = 2400, -- 601
		timeWindow = {span = 300} -- 602
	} -- 602
} -- 602
--- 关卡总数。
function ____exports.levelCount() -- 607
	return #LEVELS -- 608
end -- 607
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 612
	return LEVELS[index + 1] -- 613
end -- 612
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 617
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 618
end -- 617
return ____exports -- 617