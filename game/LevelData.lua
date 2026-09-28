-- [ts]: LevelData.ts
local ____exports = {} -- 1
local applyScalesLocal -- 1
local ____Gravity = require("game.Gravity") -- 48
local bodyPositionAt = ____Gravity.bodyPositionAt -- 48
local distance = ____Gravity.distance -- 48
local ____Config = require("game.Config") -- 49
local GravityScale = ____Config.GravityScale -- 49
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 49
local ____Scale = require("game.Scale") -- 50
local EarthGm = ____Scale.EarthGm -- 51
local EarthRadius = ____Scale.EarthRadius -- 51
local MoonOrbitRadius = ____Scale.MoonOrbitRadius -- 51
local REAL = ____Scale.REAL -- 51
local SunGm = ____Scale.SunGm -- 51
local SunRadius = ____Scale.SunRadius -- 51
local circularSpeed = ____Scale.circularSpeed -- 52
local period = ____Scale.period -- 52
local trueGm = ____Scale.trueGm -- 52
local trueOrbit = ____Scale.trueOrbit -- 52
local trueRadius = ____Scale.trueRadius -- 52
local ____Tuning = require("game.Tuning") -- 54
local visualRadius = ____Tuning.visualRadius -- 54
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 786
	local out = {} -- 787
	for ____, b in ipairs(bodies) do -- 788
		out[#out + 1] = { -- 789
			gm = b.gm * gravityScale, -- 790
			radius = b.radius, -- 791
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 792
			orbitRadius = b.orbitRadius, -- 793
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 794
			phase0 = b.phase0, -- 795
			orbitDirection = b.orbitDirection, -- 796
			host = b.host ~= nil and applyScalesLocal({b.host}, gravityScale, orbitScale)[1] or nil -- 798
		} -- 798
	end -- 798
	return out -- 801
end -- 801
--- 评价一局飞行的火箭星级（0 ~ 3 枚火箭，纯函数）。
function ____exports.evaluateRockets(level, result, burnDv, extra) -- 190
	if result ~= "success" then -- 190
		return 0 -- 200
	end -- 200
	local count = 1 -- 201
	local challenges = level.mission ~= nil and level.mission.challenges or nil -- 202
	if challenges == nil then -- 202
		return count -- 203
	end -- 203
	local c2 = challenges[2] -- 206
	if c2.type == "fuel" and c2.threshold ~= nil then -- 206
		if burnDv <= level.dvBudget * c2.threshold then -- 206
			count = count + 1 -- 208
		end -- 208
	elseif burnDv <= level.dvBudget * 0.8 then -- 208
		count = count + 1 -- 210
	end -- 210
	local c3 = challenges[3] -- 214
	if c3.type == "distance" and c3.threshold ~= nil then -- 214
		if extra ~= nil and extra.closestDist ~= nil and extra.closestDist <= c3.threshold then -- 214
			count = count + 1 -- 217
		end -- 217
	elseif c3.type == "speed" and c3.threshold ~= nil then -- 217
		if extra ~= nil and extra.maxSpeed ~= nil and extra.maxSpeed >= c3.threshold then -- 217
			count = count + 1 -- 221
		end -- 221
	elseif c3.type == "eccentricity" and c3.threshold ~= nil then -- 221
		if extra ~= nil and extra.eccentricity ~= nil and extra.eccentricity <= c3.threshold then -- 221
			count = count + 1 -- 225
		end -- 225
	elseif count == 2 and burnDv <= level.dvBudget * 0.5 then -- 225
		count = count + 1 -- 228
	end -- 228
	return math.min( -- 231
		3, -- 231
		math.max(0, count) -- 231
	) -- 231
end -- 190
--- 导出名与旧版一致（外部调用方按这个名字找）。
function ____exports.bodyVelocityAt(b, t) -- 243
	if b.orbitPeriod == 0 or b.orbitRadius <= 0 then -- 243
		return {x = 0, y = 0} -- 244
	end -- 244
	local angle = b.phase0 + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 245
	local w = b.orbitDirection * 2 * math.pi / b.orbitPeriod -- 246
	return { -- 247
		x = -math.sin(angle) * b.orbitRadius * w, -- 247
		y = math.cos(angle) * b.orbitRadius * w -- 247
	} -- 247
end -- 243
--- 航点列表（链式目标取 chain，否则就是唯一目标）。
function ____exports.goalWaypoints(goal) -- 251
	if goal.chain ~= nil then -- 251
		return goal.chain -- 252
	end -- 252
	if goal.kind == "planet" then -- 252
		return {{planetIndex = goal.planetIndex, tolerance = goal.tolerance}} -- 253
	end -- 253
	return {} -- 254
end -- 251
--- 采样点 i 处、相对某天体的速度（捕获判据与诊断共用同一份实现）。
-- 
-- points 里只有位置 ⇒ 用相邻采样点差分；`dt` 是**相邻采样点之间的有效步长**。
-- `limit` 是最后一个有效采样点索引（末端夹紧用）。
function ____exports.relativeSpeedAt(points, i, body, dt, t0, limit, velocities) -- 263
	local vx = 0 -- 264
	local vy = 0 -- 265
	if velocities ~= nil and velocities[i + 1] ~= nil then -- 265
		vx = velocities[i + 1].x -- 268
		vy = velocities[i + 1].y -- 269
	else -- 269
		local j1 = i + 1 <= limit and i + 1 or i -- 273
		local j0 = i > 0 and i - 1 or i -- 274
		local spanT = (j1 - j0) * dt -- 275
		if spanT > 0 then -- 275
			vx = (points[j1 + 1].x - points[j0 + 1].x) / spanT -- 277
			vy = (points[j1 + 1].y - points[j0 + 1].y) / spanT -- 278
		end -- 278
	end -- 278
	local pv = ____exports.bodyVelocityAt(body, t0) -- 281
	local rx = vx - pv.x -- 282
	local ry = vy - pv.y -- 283
	return math.sqrt(rx * rx + ry * ry) -- 284
end -- 263
--- 捕获阈值：该处逃逸速度（圆轨道速度 × 系数 k，k 默认 √2）。
function ____exports.captureThreshold(body, d, k) -- 288
	if body.gm <= 0 or d <= 0.000001 then -- 288
		return 1000000000 -- 289
	end -- 289
	return k * math.sqrt(body.gm / d) -- 290
end -- 288
--- 顺序航线的进度：返回在 points[0..upto] 里**依次**掠过的航点数与最后一个命中索引。
-- 
-- 一次线性扫描：航点必须按顺序命中，且后一个必须出现在更晚的采样点上
-- （"先到土星再路过木星"不算数）。upto 用于飞行中查询"到哪一段了"（画环的明暗）。
function ____exports.waypointProgress(points, bodies, goal, dt, t0, upto, velocities) -- 299
	local wps = ____exports.goalWaypoints(goal) -- 308
	local start = t0 ~= nil and t0 or 0 -- 309
	local limit = #points - 1 -- 310
	if upto ~= nil and upto >= 0 and upto < limit then -- 310
		limit = upto -- 311
	end -- 311
	local next = 0 -- 312
	local lastIndex = -1 -- 313
	do -- 313
		local i = 0 -- 314
		while i <= limit and next < #wps do -- 314
			do -- 314
				local w = wps[next + 1] -- 315
				local body = bodies[w.planetIndex + 1] -- 316
				if body == nil then -- 316
					return {passed = 0, lastIndex = -1} -- 317
				end -- 317
				local gp = bodyPositionAt(body, start + i * dt) -- 318
				if distance(points[i + 1], gp) < w.tolerance then -- 318
					if w.capture == true then -- 318
						local k = w.captureFactor ~= nil and w.captureFactor or 1.4142135623730951 -- 323
						local d = distance(points[i + 1], gp) -- 324
						if d <= body.radius then -- 324
							goto __continue29 -- 327
						end -- 327
						local rel = ____exports.relativeSpeedAt( -- 328
							points, -- 328
							i, -- 328
							body, -- 328
							dt, -- 328
							start + i * dt, -- 328
							limit, -- 328
							velocities -- 328
						) -- 328
						if rel > ____exports.captureThreshold(body, d, k) then -- 328
							goto __continue29 -- 329
						end -- 329
					end -- 329
					next = next + 1 -- 331
					lastIndex = i -- 332
				end -- 332
			end -- 332
			::__continue29:: -- 332
			i = i + 1 -- 314
		end -- 314
	end -- 314
	return {passed = next, lastIndex = lastIndex} -- 335
end -- 299
--- 到达目标的采样点索引；没到返回 -1。
function ____exports.findGoalIndex(points, bodies, goal, dt, t0, velocities) -- 339
	local wps = ____exports.goalWaypoints(goal) -- 340
	if #wps == 0 then -- 340
		return -1 -- 341
	end -- 341
	local st = ____exports.waypointProgress( -- 342
		points, -- 342
		bodies, -- 342
		goal, -- 342
		dt, -- 342
		t0, -- 342
		nil, -- 342
		velocities -- 342
	) -- 342
	return st.passed >= #wps and st.lastIndex or -1 -- 343
end -- 339
--- 度 → 弧度（关卡数据里写角度比写弧度好读）。
local function deg(d) -- 351
	return d * math.pi / 180 -- 352
end -- 351
--- 太阳（每关的第 0 号天体）。
local function sun() -- 356
	return { -- 357
		gm = SunGm, -- 357
		radius = SunRadius, -- 357
		orbitCenter = {x = 0, y = 0}, -- 357
		orbitRadius = 0, -- 357
		orbitPeriod = 0, -- 357
		phase0 = 0, -- 357
		orbitDirection = 1 -- 357
	} -- 357
end -- 356
--- 绕太阳公转的行星：`key` 是 Scale.REAL 里的键。
-- 
-- 真半径 0.0034（地球）到 0.0374（木星），**不再有任何放大** —— 用户要求"天体大小改为符合物理的大小"。
-- 看得见的那一层在 Tuning.BODY_VISUAL_RADIUS。
local function orbiter(key, phaseDeg) -- 366
	local real = REAL[key] -- 367
	local a = trueOrbit(real.au) -- 368
	return { -- 369
		gm = trueGm(real.gm), -- 370
		radius = trueRadius(real.radiusKm), -- 371
		orbitCenter = {x = 0, y = 0}, -- 372
		orbitRadius = a, -- 373
		orbitPeriod = period(a, SunGm), -- 374
		phase0 = deg(phaseDeg), -- 375
		orbitDirection = 1 -- 376
	} -- 376
end -- 366
--- 绕**会动的宿主**公转的卫星（L1 的月球）。
-- 
-- 周期用开普勒第三定律 `2π·sqrt(a³/μ)` 算，**μ 取宿主（地球）的 gm** ——
-- 这是最容易搞错的一步：拿月球自己的 gm 去算会得到 11.35 秒（正确值 1.2593 秒）。
local function satellite(key, host, orbitRadius, phaseDeg) -- 386
	local real = REAL[key] -- 387
	return { -- 388
		gm = trueGm(real.gm), -- 389
		radius = trueRadius(real.radiusKm), -- 390
		orbitCenter = {x = 0, y = 0}, -- 391
		orbitRadius = orbitRadius, -- 392
		orbitPeriod = period(orbitRadius, host.gm), -- 393
		phase0 = deg(phaseDeg), -- 394
		orbitDirection = 1, -- 395
		host = host -- 396
	} -- 396
end -- 386
--- 视觉描述。`levelIndex` 决定用哪张视觉半径表：0 = L1 用地月系专用表（见 Tuning）。
local function planetVisual(key, body, r, g, b, model, ring, levelIndex) -- 404
	return { -- 405
		r = r, -- 405
		g = g, -- 405
		b = b, -- 405
		displayRadius = visualRadius(key, body.radius, levelIndex), -- 405
		ring = ring, -- 405
		model = model -- 405
	} -- 405
end -- 404
--- 太阳的视觉（自发光 + 光晕）。
local function sunVisual(levelIndex) -- 409
	return { -- 411
		r = 1, -- 411
		g = 0.97, -- 411
		b = 0.88, -- 411
		displayRadius = visualRadius("sun", SunRadius, levelIndex), -- 411
		ring = false, -- 411
		model = "Sun", -- 411
		emissive = {r = 1, g = 0.95, b = 0.82} -- 411
	} -- 411
end -- 409
--- 出发轨道半径 = 1 AU（地球轨道）。六关共用 —— L1 的地球就在这里，L2–L6 从这里出发。
____exports.EarthOrbitRadius = trueOrbit(REAL.earth.au) -- 421
--- 该点的日心圆轨速度（30.00 平面单位/秒 —— 全套尺度的速度锚点）。
____exports.EarthOrbitSpeed = circularSpeed(SunGm, ____exports.EarthOrbitRadius) -- 424
--- 相位表 —— **全部由 `node tools/level-phases.mjs <关号> --dirs 240 --dvs 31 --tmax N` 解出**，不许手填。
-- 
-- ⚠️ 同一颗行星在**不同关的相位不同**，这是对的：相位代表"哪一天的太阳系"，
--    每一关的可行发射窗口本来就不一样。物理量（gm / 半径 / 轨道 / 周期）才是六关共用、不许变的。
-- 
-- 每一行后面的注释就是它的出处（工具输出），改数值必须重跑工具。
local PH = { -- 434
	mercury = 45, -- 435
	venus = 79.6, -- 437
	jupiter3 = 186.1, -- 442
	jupiter4 = 184.4, -- 443
	jupiter5 = 175.6, -- 444
	jupiter6 = 175.2, -- 445
	saturn4 = 199.6, -- 447
	saturn5 = 190.8, -- 448
	saturn6 = 190.3, -- 449
	uranus5 = 202.8, -- 451
	uranus6 = 201.8, -- 452
	neptune6 = 207.6, -- 454
	moon = 154.7 -- 462
} -- 462
--- L1：地月系。
-- 
-- - 地球是**真天体**：真 gm、真半径，自己在绕日公转（这是"物理统一"的试纸）；
-- - 月球绕地球，周期由开普勒第三定律算出 = 1.2593 秒（真实值）；
-- - 探测器在**绕地圆轨道**上，半径 0.1 单位（= 18.7 万 km = 月球距离的 49%）：
--   初始速度 = 地球的公转速度 + 绕地圆轨速度（顺行），所以预测线一上来就是一条弧线；
-- - 点火目标：抬升到月球轨道 0.2056 做霍曼转移，半程 0.4034 秒。
local function level1() -- 474
	local earthOrbit = ____exports.EarthOrbitRadius -- 475
	local earth = { -- 476
		gm = EarthGm, -- 477
		radius = EarthRadius, -- 478
		orbitCenter = {x = 0, y = 0}, -- 479
		orbitRadius = earthOrbit, -- 480
		orbitPeriod = period(earthOrbit, SunGm), -- 481
		phase0 = deg(90), -- 482
		orbitDirection = 1 -- 483
	} -- 483
	local moon = satellite("moon", earth, MoonOrbitRadius, PH.moon) -- 485
	local parking = 0.1 -- 486
	local earthPos = bodyPositionAt(earth, 0) -- 489
	local earthVel = ____exports.bodyVelocityAt(earth, 0) -- 490
	local vCirc = circularSpeed(EarthGm, parking) -- 491
	return { -- 492
		id = 1, -- 493
		title = "月球", -- 494
		probeVariant = "solar", -- 495
		brief = "月球任务 · 地球轨道：你已经在绕地球飞了 —— 月球也在走。别对着它现在的位置点火，要打提前量。", -- 496
		probeStart = {x = earthPos.x, y = earthPos.y + parking}, -- 497
		probeVel0 = {x = earthVel.x - vCirc, y = earthVel.y}, -- 498
		planets = { -- 499
			sun(), -- 499
			earth, -- 499
			moon -- 499
		}, -- 499
		visuals = { -- 503
			sunVisual(0), -- 504
			planetVisual( -- 505
				"earth", -- 505
				earth, -- 505
				0.42, -- 505
				0.62, -- 505
				0.85, -- 505
				"Planet_Earth", -- 505
				false, -- 505
				0 -- 505
			), -- 505
			planetVisual( -- 506
				"moon", -- 506
				moon, -- 506
				0.56, -- 506
				0.56, -- 506
				0.6, -- 506
				"Moon", -- 506
				false, -- 506
				0 -- 506
			) -- 506
		}, -- 506
		goal = {kind = "planet", planetIndex = 2, tolerance = 0.02}, -- 509
		dvBudget = 0.35, -- 510
		escapeRadius = 400, -- 514
		maxSteps = 2400, -- 517
		planCenter = 1, -- 518
		mission = { -- 519
			id = "L1", -- 520
			codeName = "Moon", -- 521
			historicalRef = "阿波罗 / 嫦娥探月", -- 522
			subtitle = "启蒙", -- 523
			vehicle = "flyby", -- 524
			challenges = {{desc = "成功抵达月球轨道或飞掠月球", type = "success"}, {desc = "发射点火消耗 Δv ≤ 0.28（节省 > 20%）", type = "fuel", threshold = 0.8}, {desc = "近月点距离 r_peri ≤ 0.015", type = "distance", threshold = 0.015}} -- 525
		} -- 525
	} -- 525
end -- 474
--- L2–L6 共用的出发状态：1 AU 圆轨道上的一点，顺行（-x），速度 = 该点圆轨速度。
local function departure() -- 537
	return {pos = {x = 0, y = ____exports.EarthOrbitRadius}, vel = {x = -____exports.EarthOrbitSpeed, y = 0}} -- 538
end -- 537
--- L2 水手10号：地球 ➔ 金星 ➔ 水星（人类首次行星引力借力）。
local function level2() -- 545
	local venus = orbiter("venus", PH.venus) -- 546
	local mercury = orbiter("mercury", PH.mercury) -- 547
	local d = departure() -- 548
	return { -- 549
		id = 2, -- 550
		title = "水手10号", -- 551
		probeVariant = "solar", -- 552
		brief = "水手10号 · 1 AU 出发：人类首次行星引力辅助。向内俯冲，利用金星前向借力大幅削减轨道动能，深潜入水星轨道！", -- 553
		probeStart = d.pos, -- 554
		probeVel0 = d.vel, -- 555
		planets = { -- 556
			sun(), -- 556
			venus, -- 556
			mercury -- 556
		}, -- 556
		visuals = { -- 557
			sunVisual(), -- 558
			planetVisual( -- 559
				"venus", -- 559
				venus, -- 559
				0.9, -- 559
				0.78, -- 559
				0.55, -- 559
				"Planet_Venus", -- 559
				false -- 559
			), -- 559
			planetVisual( -- 560
				"mercury", -- 560
				mercury, -- 560
				0.65, -- 560
				0.65, -- 560
				0.65, -- 560
				"Sphere", -- 560
				false -- 560
			) -- 560
		}, -- 560
		goal = {kind = "planet", planetIndex = 2, tolerance = 6, chain = {{planetIndex = 1, tolerance = 15, label = "金星"}, {planetIndex = 2, tolerance = 6, label = "水星"}}}, -- 562
		dvBudget = 4, -- 571
		escapeRadius = 3600, -- 572
		maxSteps = 4000, -- 573
		timeWindow = {span = 27}, -- 574
		mission = { -- 575
			id = "L2", -- 576
			codeName = "Mariner 10", -- 577
			historicalRef = "水手10号 (1973)", -- 578
			subtitle = "潜行", -- 579
			vehicle = "flyby", -- 580
			challenges = {{desc = "借力金星并成功抵达水星", type = "success"}, {desc = "初始点火消耗 Δv ≤ 75% 预算", type = "fuel", threshold = 0.75}, {desc = "金星交会时相对速度降幅 ≥ 12 单位", type = "speed", threshold = 12}} -- 581
		} -- 581
	} -- 581
end -- 545
--- L3 帕克号：地球 ➔ 金星 ➔ 太阳日冕区（触碰太阳极热地狱）。
local function level3() -- 591
	local venus = orbiter("venus", PH.venus) -- 592
	local d = departure() -- 593
	return { -- 594
		id = 3, -- 595
		title = "帕克号", -- 596
		probeVariant = "solar", -- 597
		brief = "帕克号 · 1 AU 出发：人类制造的最狂暴“触日者”。利用金星大幅削减日心角动量，近距离俯冲入太阳日冕危险带且未撞毁！", -- 598
		probeStart = d.pos, -- 599
		probeVel0 = d.vel, -- 600
		planets = { -- 601
			sun(), -- 601
			venus -- 601
		}, -- 601
		visuals = { -- 602
			sunVisual(), -- 603
			planetVisual( -- 604
				"venus", -- 604
				venus, -- 604
				0.9, -- 604
				0.78, -- 604
				0.55, -- 604
				"Planet_Venus", -- 604
				false -- 604
			) -- 604
		}, -- 604
		goal = {kind = "planet", planetIndex = 0, tolerance = 15}, -- 606
		dvBudget = 6, -- 611
		escapeRadius = 3600, -- 612
		maxSteps = 6000, -- 613
		timeWindow = {span = 27}, -- 614
		mission = { -- 615
			id = "L3", -- 616
			codeName = "Parker", -- 617
			historicalRef = "帕克太阳探测器 (2018)", -- 618
			subtitle = "烈日", -- 619
			vehicle = "flyby", -- 620
			challenges = {{desc = "近日点深入太阳日冕观测带 (r_peri ≤ 15) 且未撞毁", type = "success"}, {desc = "初始点火消耗 Δv ≤ 80% 预算", type = "fuel", threshold = 0.8}, {desc = "近日点最高日心速度突破 vmax ≥ 60 单位", type = "speed", threshold = 60}} -- 621
		} -- 621
	} -- 621
end -- 591
--- L4 伽利略号：地球 ➔ 木星泊入（轨道器模式正式登场）。
local function level4() -- 631
	local jupiter = orbiter("jupiter", PH.jupiter4) -- 632
	local d = departure() -- 633
	return { -- 634
		id = 4, -- 635
		title = "伽利略号", -- 636
		probeVariant = "rtg", -- 637
		brief = "伽利略号 · 1 AU 出发：人类第一艘长期驻留环绕木星的轨道器。抵达木星巨型引力井，在慢动作特写中捕捉制动窗口，按下 [ BRAKE ] 优雅泊入闭合环绕轨！", -- 638
		probeStart = d.pos, -- 639
		probeVel0 = d.vel, -- 640
		planets = { -- 641
			sun(), -- 641
			jupiter -- 641
		}, -- 641
		visuals = { -- 642
			sunVisual(), -- 643
			planetVisual( -- 644
				"jupiter", -- 644
				jupiter, -- 644
				0.85, -- 644
				0.72, -- 644
				0.5, -- 644
				"Planet_Jupiter", -- 644
				false -- 644
			) -- 644
		}, -- 644
		goal = {kind = "planet", planetIndex = 1, tolerance = 40, chain = {{planetIndex = 1, tolerance = 40, label = "木星", capture = true}}}, -- 646
		dvBudget = 14, -- 654
		escapeRadius = 3600, -- 655
		maxSteps = 25000, -- 656
		timeWindow = {span = 18}, -- 657
		mission = { -- 658
			id = "L4", -- 659
			codeName = "Galileo", -- 660
			historicalRef = "伽利略号 (1989)", -- 661
			subtitle = "泊入", -- 662
			vehicle = "orbiter", -- 663
			challenges = {{desc = "在制动窗口内成功按下刹车闭合入轨", type = "success"}, {desc = "地面发射点火 Δv ≤ 70% 预算", type = "fuel", threshold = 0.7}, {desc = "入轨偏心率 e ≤ 0.25", type = "eccentricity", threshold = 0.25}} -- 664
		} -- 664
	} -- 664
end -- 631
--- L5 新视野号：地球 ➔ 木星狂暴加速 ➔ 柯伊伯带深空。
local function level5() -- 674
	local jupiter = orbiter("jupiter", PH.jupiter5) -- 675
	local d = departure() -- 676
	return { -- 677
		id = 5, -- 678
		title = "新视野号", -- 679
		probeVariant = "rtg", -- 680
		brief = "新视野号 · 1 AU 出发：人类有史以来最狂暴的深空信使。寻找木星后向加速最佳切角，利用太阳系最强引力弹弓把探测器甩向柯伊伯带深空外边界！", -- 681
		probeStart = d.pos, -- 682
		probeVel0 = d.vel, -- 683
		planets = { -- 684
			sun(), -- 684
			jupiter -- 684
		}, -- 684
		visuals = { -- 685
			sunVisual(), -- 686
			planetVisual( -- 687
				"jupiter", -- 687
				jupiter, -- 687
				0.85, -- 687
				0.72, -- 687
				0.5, -- 687
				"Planet_Jupiter", -- 687
				false -- 687
			) -- 687
		}, -- 687
		goal = {kind = "escape", planetIndex = 1, tolerance = 40, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}}}, -- 689
		dvBudget = 15, -- 697
		escapeRadius = 3600, -- 698
		maxSteps = 35000, -- 699
		timeWindow = {span = 17.5}, -- 700
		mission = { -- 701
			id = "L5", -- 702
			codeName = "New Horizons", -- 703
			historicalRef = "新视野号 (2006)", -- 704
			subtitle = "狂飙", -- 705
			vehicle = "flyby", -- 706
			challenges = {{desc = "借力木星获得逃逸能量抵达外边界", type = "success"}, {desc = "地面发射初速消耗 Δv ≤ 75% 预算", type = "fuel", threshold = 0.75}, {desc = "速度增幅 ≥ 15 且逃逸末速度 vend ≥ 40", type = "speed", threshold = 40}} -- 707
		} -- 707
	} -- 707
end -- 674
--- L6 旅行者2号：地球 ➔ 木星 ➔ 土星 ➔ 天王星 ➔ 海王星 ➔ 星际空间。
local function level6() -- 717
	local jupiter = orbiter("jupiter", PH.jupiter6) -- 718
	local saturn = orbiter("saturn", PH.saturn6) -- 719
	local uranus = orbiter("uranus", PH.uranus6) -- 720
	local neptune = orbiter("neptune", PH.neptune6) -- 721
	local d = departure() -- 722
	return { -- 723
		id = 6, -- 724
		title = "旅行者2号", -- 725
		probeVariant = "rtg", -- 726
		brief = "旅行者2号 · 1 AU 出发：175 年一遇的行星连珠奇迹！对准发射窗口，连续四星接力借力飞出海王星轨道，冲入星际空间，触发暗淡蓝点终章！", -- 727
		probeStart = d.pos, -- 728
		probeVel0 = d.vel, -- 729
		planets = { -- 730
			sun(), -- 730
			jupiter, -- 730
			saturn, -- 730
			uranus, -- 730
			neptune -- 730
		}, -- 730
		visuals = { -- 731
			sunVisual(), -- 732
			planetVisual( -- 733
				"jupiter", -- 733
				jupiter, -- 733
				0.85, -- 733
				0.72, -- 733
				0.5, -- 733
				"Planet_Jupiter", -- 733
				false -- 733
			), -- 733
			planetVisual( -- 734
				"saturn", -- 734
				saturn, -- 734
				0.75, -- 734
				0.7, -- 734
				0.6, -- 734
				"Planet_Saturn", -- 734
				true -- 734
			), -- 734
			planetVisual( -- 735
				"uranus", -- 735
				uranus, -- 735
				0.62, -- 735
				0.82, -- 735
				0.86, -- 735
				"Planet_Uranus", -- 735
				false -- 735
			), -- 735
			planetVisual( -- 736
				"neptune", -- 736
				neptune, -- 736
				0.34, -- 736
				0.5, -- 736
				0.86, -- 736
				"Planet_Neptune", -- 736
				false -- 736
			) -- 736
		}, -- 736
		goal = {kind = "planet", planetIndex = 4, tolerance = 120, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 60, label = "土星"}, {planetIndex = 3, tolerance = 90, label = "天王星"}, {planetIndex = 4, tolerance = 120, label = "海王星"}}}, -- 738
		dvBudget = 16, -- 749
		escapeRadius = 3600, -- 750
		maxSteps = 70000, -- 751
		timeWindow = {span = 17.5}, -- 752
		mission = { -- 753
			id = "L6", -- 754
			codeName = "Voyager 2", -- 755
			historicalRef = "旅行者2号 (1977)", -- 756
			subtitle = "奇迹", -- 757
			vehicle = "flyby", -- 758
			challenges = {{desc = "成功四星连续借力并飞出海王星轨道", type = "success"}, {desc = "初始发射点火 Δv ≤ 80% 预算", type = "fuel", threshold = 0.8}, {desc = "四星交会无碰撞且近心点精度 ≤ 5%", type = "distance", threshold = 0.05}} -- 759
		} -- 759
	} -- 759
end -- 717
local LEVELS = { -- 768
	level1(), -- 768
	level2(), -- 768
	level3(), -- 768
	level4(), -- 768
	level5(), -- 768
	level6() -- 768
} -- 768
--- 关卡总数。
function ____exports.levelCount() -- 771
	return #LEVELS -- 772
end -- 771
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 776
	return LEVELS[index + 1] -- 777
end -- 776
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 781
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 782
end -- 781
return ____exports -- 781