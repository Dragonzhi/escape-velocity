-- [ts]: LevelData.ts
local ____exports = {} -- 1
local applyScalesLocal -- 1
local ____Gravity = require("game.Gravity") -- 28
local bodyPositionAt = ____Gravity.bodyPositionAt -- 28
local distance = ____Gravity.distance -- 28
local ____Config = require("game.Config") -- 29
local GravityScale = ____Config.GravityScale -- 29
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 29
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 609
	local out = {} -- 610
	for ____, b in ipairs(bodies) do -- 611
		out[#out + 1] = { -- 612
			gm = b.gm * gravityScale, -- 613
			radius = b.radius, -- 614
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 615
			orbitRadius = b.orbitRadius, -- 616
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 617
			phase0 = b.phase0, -- 618
			orbitDirection = b.orbitDirection, -- 619
			host = b.host ~= nil and applyScalesLocal({b.host}, gravityScale, orbitScale)[1] or nil -- 621
		} -- 621
	end -- 621
	return out -- 624
end -- 624
--- 太阳的引力强度（`v_circ(80) = sqrt(SunGm/80) ≈ 30`，逃逸速度 42.4）。
____exports.SunGm = 72000 -- 118
--- 太阳的半径（撞毁半径 = 显示半径，尺寸公平性硬约束）。
-- 
-- ⚠️ 2026-09-26 用户参考图（docs/比例尺效果展示图.excalidraw）给的比值：
--   最内圈轨道 ≈ **1.9 个太阳半径**、太阳直径 ≈ 屏幕宽度的 0.38、行星 ≈ 太阳的 0.19。
--   原来取 7.0（轨道 = 7.9~27.9 个太阳半径）⇒ 太阳在画面里像一颗行星，"尺度很怪"的根因之一。
--   改成 28 之后：轨道 55/80/105/135/165/195 = 1.96/2.86/3.75/4.8/5.9/7.0 个太阳半径，与参考图一致。
____exports.SunRadius = 28 -- 128
--- 开普勒周期系数：`T = KeplerK · r^1.5`（秒）。
-- 
-- 相对快慢 = 真实开普勒（内快外慢），绝对速率被压缩 —— `KeplerK = 1` 相当于把真实值除以 42.7
-- （真实：`T = 2π·r^1.5/sqrt(SunGm) = 0.0234·r^1.5`）。这样飞行十几秒里行星只挪几度。
____exports.KeplerK = 1 -- 136
--- 开普勒周期（秒）：r 单位是平面单位。r <= 0 返回 0（静止）。
function ____exports.keplerPeriod(orbitRadius) -- 139
	if orbitRadius <= 0 then -- 139
		return 0 -- 140
	end -- 140
	return ____exports.KeplerK * orbitRadius ^ 1.5 -- 141
end -- 139
--- 度 → 弧度（关卡数据里写角度比写弧度好读）。
local function deg(d) -- 145
	return d * math.pi / 180 -- 146
end -- 145
local R_MOON = 1 -- 150
local R_VENUS = 1.72 -- 153
local R_EARTH = 1.76 -- 154
local R_JUPITER = 4.63 -- 155
local R_SATURN = 4.3 -- 156
local R_URANUS = 3.04 -- 157
local R_NEPTUNE = 3 -- 158
--- 巡航轨道半径（压缩太阳系：顺序真实、比例压缩）—— 一律绕原点（太阳）。
local ORBIT = { -- 161
	venus = 55, -- 161
	earth = 80, -- 161
	jupiter = 105, -- 161
	saturn = 135, -- 161
	uranus = 165, -- 161
	neptune = 195 -- 161
} -- 161
--- 掠过环的容差（flyby）：比本体大 13 左右 —— 远距离飞行要有"够得着"的手感。
local FLYBY_PAD = 13 -- 164
--- 引力强度表（S3.13 六站重排）。
-- 
-- ⚠️ 这些是**玩法参数**，不是真实比值：真实木星是地球的 318 倍，这里只有 ~1 倍。
-- 按真实比值，木星会在 40 单位外就把探测器抓住，「绕日弧线」这条主玩法就没了。
-- 但**同一颗行星在六关里必须是同一个值** —— 否则玩家在 L3 学到的「木星能把我掰多少」，
-- 到 L5 就不成立了，那正是「物理不统一」最容易被玩家看出来的地方。
local GM = { -- 174
	venus = 2600, -- 174
	jupiter = 2500, -- 174
	saturn = 12000, -- 174
	uranus = 1200, -- 174
	neptune = 8000 -- 174
} -- 174
--- 行星自身在时刻 t 的速度（圆轨道 = 位置的导数）。
-- 捕获判据要的是"**相对**行星的速度" —— 行星自己也在跑（虽然慢）。
function ____exports.bodyVelocityAt(b, t) -- 187
	if b.orbitPeriod == 0 or b.orbitRadius <= 0 then -- 187
		return {x = 0, y = 0} -- 188
	end -- 188
	local angle = b.phase0 + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 189
	local w = b.orbitDirection * 2 * math.pi / b.orbitPeriod -- 190
	return { -- 191
		x = -math.sin(angle) * b.orbitRadius * w, -- 191
		y = math.cos(angle) * b.orbitRadius * w -- 191
	} -- 191
end -- 187
function ____exports.goalWaypoints(goal) -- 194
	if goal.chain ~= nil then -- 194
		return goal.chain -- 195
	end -- 195
	if goal.kind == "planet" then -- 195
		return {{planetIndex = goal.planetIndex, tolerance = goal.tolerance}} -- 196
	end -- 196
	return {} -- 197
end -- 194
--- 采样点 i 处、相对某天体的速度（捕获判据与诊断共用同一份实现）。
-- 
-- points 里只有位置 ⇒ 用相邻采样点差分；`dt` 是**相邻采样点之间的有效步长**。
-- `limit` 是最后一个有效采样点索引（末端夹紧用）。
function ____exports.relativeSpeedAt(points, i, body, dt, t0, limit, velocities) -- 212
	local vx = 0 -- 213
	local vy = 0 -- 214
	if velocities ~= nil and velocities[i + 1] ~= nil then -- 214
		vx = velocities[i + 1].x -- 217
		vy = velocities[i + 1].y -- 218
	else -- 218
		local j1 = i + 1 <= limit and i + 1 or i -- 222
		local j0 = i > 0 and i - 1 or i -- 223
		local spanT = (j1 - j0) * dt -- 224
		if spanT > 0 then -- 224
			vx = (points[j1 + 1].x - points[j0 + 1].x) / spanT -- 226
			vy = (points[j1 + 1].y - points[j0 + 1].y) / spanT -- 227
		end -- 227
	end -- 227
	local pv = ____exports.bodyVelocityAt(body, t0) -- 230
	local rx = vx - pv.x -- 231
	local ry = vy - pv.y -- 232
	return math.sqrt(rx * rx + ry * ry) -- 233
end -- 212
--- 捕获阈值：该处逃逸速度（圆轨道速度 × 系数 k，k 默认 √2）。
function ____exports.captureThreshold(body, d, k) -- 237
	if body.gm <= 0 or d <= 0.000001 then -- 237
		return 1000000000 -- 238
	end -- 238
	return k * math.sqrt(body.gm / d) -- 239
end -- 237
function ____exports.waypointProgress(points, bodies, goal, dt, t0, upto, velocities) -- 242
	local wps = ____exports.goalWaypoints(goal) -- 252
	local start = t0 ~= nil and t0 or 0 -- 253
	local limit = #points - 1 -- 254
	if upto ~= nil and upto >= 0 and upto < limit then -- 254
		limit = upto -- 255
	end -- 255
	local next = 0 -- 256
	local lastIndex = -1 -- 257
	do -- 257
		local i = 0 -- 258
		while i <= limit and next < #wps do -- 258
			do -- 258
				local w = wps[next + 1] -- 259
				local body = bodies[w.planetIndex + 1] -- 260
				if body == nil then -- 260
					return {passed = 0, lastIndex = -1} -- 261
				end -- 261
				local gp = bodyPositionAt(body, start + i * dt) -- 262
				if distance(points[i + 1], gp) < w.tolerance then -- 262
					if w.capture == true then -- 262
						local k = w.captureFactor ~= nil and w.captureFactor or 1.4142135623730951 -- 268
						local d = distance(points[i + 1], gp) -- 269
						if d <= body.radius then -- 269
							goto __continue19 -- 273
						end -- 273
						local rel = ____exports.relativeSpeedAt( -- 274
							points, -- 274
							i, -- 274
							body, -- 274
							dt, -- 274
							start + i * dt, -- 274
							limit, -- 274
							velocities -- 274
						) -- 274
						if rel > ____exports.captureThreshold(body, d, k) then -- 274
							goto __continue19 -- 275
						end -- 275
					end -- 275
					next = next + 1 -- 277
					lastIndex = i -- 278
				end -- 278
			end -- 278
			::__continue19:: -- 278
			i = i + 1 -- 258
		end -- 258
	end -- 258
	return {passed = next, lastIndex = lastIndex} -- 281
end -- 242
function ____exports.findGoalIndex(points, bodies, goal, dt, t0, velocities) -- 284
	local wps = ____exports.goalWaypoints(goal) -- 285
	if #wps == 0 then -- 285
		return -1 -- 286
	end -- 286
	local st = ____exports.waypointProgress( -- 287
		points, -- 287
		bodies, -- 287
		goal, -- 287
		dt, -- 287
		t0, -- 287
		nil, -- 287
		velocities -- 287
	) -- 287
	return st.passed >= #wps and st.lastIndex or -1 -- 288
end -- 284
--- 太阳（每关的第 0 号天体）。
local function sun() -- 312
	return { -- 313
		gm = ____exports.SunGm, -- 313
		radius = ____exports.SunRadius, -- 313
		orbitCenter = {x = 0, y = 0}, -- 313
		orbitRadius = 0, -- 313
		orbitPeriod = 0, -- 313
		phase0 = 0, -- 313
		orbitDirection = 1 -- 313
	} -- 313
end -- 312
--- 太阳的视觉（亮黄，模型 Sun.glb）。
local function sunVisual() -- 317
	return { -- 320
		r = 1, -- 320
		g = 0.97, -- 320
		b = 0.88, -- 320
		displayRadius = ____exports.SunRadius, -- 320
		ring = false, -- 320
		model = "Sun", -- 320
		emissive = {r = 1, g = 0.95, b = 0.82} -- 320
	} -- 320
end -- 317
--- 绕日公转的行星（圆心 = 太阳 = 原点）。
local function orbiter(gm, radius, orbitRadius, phaseDeg) -- 324
	return { -- 325
		gm = gm, -- 326
		radius = radius, -- 326
		orbitCenter = {x = 0, y = 0}, -- 327
		orbitRadius = orbitRadius, -- 328
		orbitPeriod = ____exports.keplerPeriod(orbitRadius), -- 329
		phase0 = deg(phaseDeg), -- 330
		orbitDirection = 1 -- 331
	} -- 331
end -- 324
--- 绕**会动的行星**公转的卫星（S3.13）：直接把宿主天体对象传进来，位置就随宿主一起走
-- （见 Gravity.Body.host）。periodSec 显式给 —— 月球绕地球的周期不该用「绕日开普勒」算，
-- 而要与**全局时间压缩**一致（本作 K = 1.0 = 真实周期 ÷ 42.7）。
local function satellite(gm, radius, host, orbitRadius, phaseDeg, periodSec) -- 340
	return { -- 341
		gm = gm, -- 342
		radius = radius, -- 342
		orbitCenter = {x = 0, y = 0}, -- 343
		orbitRadius = orbitRadius, -- 344
		orbitPeriod = periodSec, -- 345
		phase0 = deg(phaseDeg), -- 346
		orbitDirection = 1, -- 347
		host = host -- 348
	} -- 348
end -- 340
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
local function homeEarth() -- 366
	return { -- 367
		gm = 0, -- 368
		radius = R_EARTH, -- 368
		orbitCenter = {x = 0, y = 0}, -- 369
		orbitRadius = ORBIT.earth, -- 370
		orbitPeriod = ____exports.keplerPeriod(ORBIT.earth), -- 371
		phase0 = deg(100), -- 372
		orbitDirection = 1 -- 373
	} -- 373
end -- 366
--- 地球（家园）：蓝绿。
local function earthVisual() -- 381
	return { -- 382
		r = 0.42, -- 382
		g = 0.62, -- 382
		b = 0.85, -- 382
		displayRadius = R_EARTH, -- 382
		ring = false, -- 382
		model = "Planet_Earth" -- 382
	} -- 382
end -- 381
--- 月球（L1）：灰。⚠️ 还没有 Moon.glb —— 回退到代码生成的 Sphere.gltf（在 Trae 的交付清单里）。
local function moonVisual() -- 385
	return { -- 386
		r = 0.56, -- 386
		g = 0.56, -- 386
		b = 0.6, -- 386
		displayRadius = R_MOON, -- 386
		ring = false -- 386
	} -- 386
end -- 385
--- 金星：暖黄的硫酸云。
local function venusVisual() -- 389
	return { -- 390
		r = 0.9, -- 390
		g = 0.78, -- 390
		b = 0.55, -- 390
		displayRadius = R_VENUS, -- 390
		ring = false, -- 390
		model = "Planet_Venus" -- 390
	} -- 390
end -- 389
--- 木星：条纹橙褐。
local function jupiterVisual() -- 393
	return { -- 394
		r = 0.85, -- 394
		g = 0.72, -- 394
		b = 0.5, -- 394
		displayRadius = R_JUPITER, -- 394
		ring = false, -- 394
		model = "Planet_Jupiter" -- 394
	} -- 394
end -- 393
--- 土星：淡金 + 环。
local function saturnVisual() -- 397
	return { -- 398
		r = 0.75, -- 398
		g = 0.7, -- 398
		b = 0.6, -- 398
		displayRadius = R_SATURN, -- 398
		ring = true, -- 398
		model = "Planet_Saturn" -- 398
	} -- 398
end -- 397
--- 天王星：青蓝。
local function uranusVisual() -- 401
	return { -- 402
		r = 0.62, -- 402
		g = 0.82, -- 402
		b = 0.86, -- 402
		displayRadius = R_URANUS, -- 402
		ring = false, -- 402
		model = "Planet_Uranus" -- 402
	} -- 402
end -- 401
--- 海王星：深蓝。
local function neptuneVisual() -- 405
	return { -- 406
		r = 0.34, -- 406
		g = 0.5, -- 406
		b = 0.86, -- 406
		displayRadius = R_NEPTUNE, -- 406
		ring = false, -- 406
		model = "Planet_Neptune" -- 406
	} -- 406
end -- 405
--- L1 的地球（S3.13）：它是**真天体**，而且**自己在绕日公转** —— 这是「物理统一」的试纸。
-- 月球用它当 host（见 satellite），于是「月球绕地球、地球绕日」两件事同时成立。
local L1_EARTH = { -- 413
	gm = 2600, -- 414
	radius = R_EARTH, -- 415
	orbitCenter = {x = 0, y = 0}, -- 416
	orbitRadius = ORBIT.earth, -- 417
	orbitPeriod = ____exports.keplerPeriod(ORBIT.earth), -- 418
	phase0 = deg(90), -- 419
	orbitDirection = 1 -- 420
} -- 420
--- L1 的月球：绕上面那颗**会动的**地球公转。
-- 
-- ⚠️ 周期是**玩法参数**，不是物理常数：15 单位的轨道如果按「与全局时间压缩一致」取 276 秒，
-- 月球在 60 秒的时间轴里只走 78°，每个日期都打得到 —— 窗口就没有意义了（实测每个 t0 都有解）。
-- 取 120 秒 ⇒ 60 秒跨度 = 它走过 **180°**，「挑时机」才真的成立；
-- 飞行 2 秒里的漂移 = 6°，远小于容差，不会让瞄准变难。
local L1_MOON_ORBIT_R = 15 -- 431
local L1_MOON_PERIOD = 120 -- 432
local LEVELS = { -- 434
	{ -- 435
		id = 1, -- 436
		title = "月球", -- 437
		brief = "月球任务 · 地球轨道：月球正在绕地球走 —— 别对着它现在的位置点火。这一次点火决定后面的一切。", -- 439
		probeStart = {x = 0, y = 90}, -- 445
		probeVel0 = {x = 16.12, y = 0}, -- 446
		planets = { -- 447
			sun(), -- 448
			L1_EARTH, -- 449
			satellite( -- 451
				0, -- 451
				R_MOON, -- 451
				L1_EARTH, -- 451
				L1_MOON_ORBIT_R, -- 451
				0, -- 451
				L1_MOON_PERIOD -- 451
			) -- 451
		}, -- 451
		visuals = { -- 453
			sunVisual(), -- 453
			earthVisual(), -- 453
			moonVisual() -- 453
		}, -- 453
		goal = {kind = "planet", planetIndex = 2, tolerance = 5}, -- 455
		dvBudget = 45, -- 456
		escapeRadius = 700, -- 457
		maxSteps = 1200, -- 458
		timeWindow = {span = 60} -- 460
	}, -- 460
	{ -- 463
		id = 2, -- 464
		title = "金星", -- 465
		brief = "金星任务 · 地球轨道：太阳会一路把你拽快 —— 向内飞，别飞过头。金星在 55 单位的内圈上等着。", -- 466
		probeStart = {x = 0, y = ORBIT.earth}, -- 467
		planets = { -- 468
			sun(), -- 469
			homeEarth(), -- 470
			orbiter(GM.venus, R_VENUS, ORBIT.venus, 358.12) -- 473
		}, -- 473
		visuals = { -- 475
			sunVisual(), -- 475
			earthVisual(), -- 475
			venusVisual() -- 475
		}, -- 475
		goal = {kind = "planet", planetIndex = 2, tolerance = R_VENUS + FLYBY_PAD}, -- 477
		dvBudget = 45, -- 478
		escapeRadius = 700, -- 479
		maxSteps = 1500, -- 480
		timeWindow = {span = 240} -- 481
	}, -- 481
	{ -- 483
		id = 3, -- 484
		title = "木星", -- 485
		brief = "木星任务 · 地球轨道：第一次真正的行星际飞行。出发得够快，木星才会在你到达时出现在航线上。", -- 486
		probeStart = {x = 0, y = ORBIT.earth}, -- 487
		planets = { -- 488
			sun(), -- 489
			homeEarth(), -- 490
			orbiter(GM.jupiter, R_JUPITER, ORBIT.jupiter, 34.68) -- 494
		}, -- 494
		visuals = { -- 496
			sunVisual(), -- 496
			earthVisual(), -- 496
			jupiterVisual() -- 496
		}, -- 496
		goal = {kind = "planet", planetIndex = 2, tolerance = R_JUPITER + FLYBY_PAD}, -- 497
		dvBudget = 55, -- 498
		escapeRadius = 700, -- 499
		maxSteps = 2400, -- 500
		timeWindow = {span = 300} -- 501
	}, -- 501
	{ -- 503
		id = 4, -- 504
		title = "土星", -- 505
		brief = "土星任务 · 地球轨道：先掠过木星，让它替你掰一下方向 —— 土星还在更外面。", -- 506
		probeStart = {x = 0, y = ORBIT.earth}, -- 507
		planets = { -- 508
			sun(), -- 509
			homeEarth(), -- 510
			orbiter(GM.jupiter, R_JUPITER, ORBIT.jupiter, 33.78), -- 511
			orbiter(GM.saturn, R_SATURN, ORBIT.saturn, 66.7) -- 512
		}, -- 512
		visuals = { -- 514
			sunVisual(), -- 514
			earthVisual(), -- 514
			jupiterVisual(), -- 514
			saturnVisual() -- 514
		}, -- 514
		goal = {kind = "planet", planetIndex = 3, tolerance = 45, chain = {{planetIndex = 2, tolerance = 30, label = "木星"}, {planetIndex = 3, tolerance = 45, label = "土星"}}}, -- 516
		dvBudget = 55, -- 523
		escapeRadius = 700, -- 524
		maxSteps = 2400, -- 525
		timeWindow = {span = 300} -- 526
	}, -- 526
	{ -- 528
		id = 5, -- 529
		title = "天王星", -- 530
		brief = "天王星任务 · 地球轨道：木星、土星，两次借力，越飞越远。一次点火要串起三个节点。", -- 531
		probeStart = {x = 0, y = ORBIT.earth}, -- 532
		planets = { -- 533
			sun(), -- 534
			homeEarth(), -- 535
			orbiter(GM.jupiter, R_JUPITER, ORBIT.jupiter, 48.58), -- 536
			orbiter(GM.saturn, R_SATURN, ORBIT.saturn, 80), -- 537
			orbiter(GM.uranus, R_URANUS, ORBIT.uranus, 96.33) -- 538
		}, -- 538
		visuals = { -- 540
			sunVisual(), -- 540
			earthVisual(), -- 540
			jupiterVisual(), -- 540
			saturnVisual(), -- 540
			uranusVisual() -- 540
		}, -- 540
		goal = {kind = "planet", planetIndex = 4, tolerance = 60, chain = {{planetIndex = 2, tolerance = 40, label = "木星"}, {planetIndex = 3, tolerance = 50, label = "土星"}, {planetIndex = 4, tolerance = 60, label = "天王星"}}}, -- 542
		dvBudget = 55, -- 550
		escapeRadius = 700, -- 551
		maxSteps = 2400, -- 552
		timeWindow = {span = 300} -- 553
	}, -- 553
	{ -- 555
		id = 6, -- 556
		title = "海王星", -- 557
		brief = "海王星任务 · 地球轨道：四颗巨行星连成一条线的那个日期。一次点火串到底，飞向 195 单位外的海王星。", -- 558
		probeStart = {x = 0, y = ORBIT.earth}, -- 559
		planets = { -- 560
			sun(), -- 561
			homeEarth(), -- 562
			orbiter(GM.jupiter, R_JUPITER, ORBIT.jupiter, 29.3), -- 567
			orbiter(GM.saturn, R_SATURN, ORBIT.saturn, 48.2), -- 568
			orbiter(GM.uranus, R_URANUS, ORBIT.uranus, 58.9), -- 569
			orbiter(GM.neptune, R_NEPTUNE, ORBIT.neptune, 65.7) -- 570
		}, -- 570
		visuals = { -- 572
			sunVisual(), -- 572
			earthVisual(), -- 572
			jupiterVisual(), -- 572
			saturnVisual(), -- 572
			uranusVisual(), -- 572
			neptuneVisual() -- 572
		}, -- 572
		goal = {kind = "planet", planetIndex = 5, tolerance = 70, chain = {{planetIndex = 2, tolerance = 40, label = "木星"}, {planetIndex = 3, tolerance = 50, label = "土星"}, {planetIndex = 4, tolerance = 60, label = "天王星"}, {planetIndex = 5, tolerance = 70, label = "海王星"}}}, -- 577
		dvBudget = 55, -- 586
		escapeRadius = 700, -- 587
		maxSteps = 2400, -- 588
		timeWindow = {span = 300} -- 589
	} -- 589
} -- 589
--- 关卡总数。
function ____exports.levelCount() -- 594
	return #LEVELS -- 595
end -- 594
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 599
	return LEVELS[index + 1] -- 600
end -- 599
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 604
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 605
end -- 604
return ____exports -- 604