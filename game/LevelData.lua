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
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 837
	local out = {} -- 838
	for ____, b in ipairs(bodies) do -- 839
		out[#out + 1] = { -- 840
			gm = b.gm * gravityScale, -- 841
			radius = b.radius, -- 842
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 843
			orbitRadius = b.orbitRadius, -- 844
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 845
			phase0 = b.phase0, -- 846
			orbitDirection = b.orbitDirection, -- 847
			host = b.host ~= nil and applyScalesLocal({b.host}, gravityScale, orbitScale)[1] or nil -- 849
		} -- 849
	end -- 849
	return out -- 852
end -- 852
--- 评价一局飞行的火箭星级及逐条达成详情（纯函数）。
function ____exports.evaluateRocketsDetailed(level, result, burnDv, extra) -- 202
	local achieved = {false, false, false} -- 212
	if result ~= "success" then -- 212
		return {rockets = 0, achieved = achieved, burnDv = burnDv, stats = extra ~= nil and extra or ({})} -- 214
	end -- 214
	achieved[1] = true -- 222
	local count = 1 -- 223
	local challenges = level.mission ~= nil and level.mission.challenges or nil -- 224
	if challenges ~= nil then -- 224
		local c2 = challenges[2] -- 227
		if c2.type == "fuel" and c2.threshold ~= nil then -- 227
			if burnDv <= level.dvBudget * c2.threshold then -- 227
				achieved[2] = true -- 230
				count = count + 1 -- 231
			end -- 231
		elseif burnDv <= level.dvBudget * 0.8 then -- 231
			achieved[2] = true -- 234
			count = count + 1 -- 235
		end -- 235
		local c3 = challenges[3] -- 239
		if c3.type == "distance" and c3.threshold ~= nil then -- 239
			if extra ~= nil and extra.closestDist ~= nil and extra.closestDist <= c3.threshold then -- 239
				achieved[3] = true -- 242
				count = count + 1 -- 243
			end -- 243
		elseif c3.type == "speed" and c3.threshold ~= nil then -- 243
			if extra ~= nil and extra.maxSpeed ~= nil and extra.maxSpeed >= c3.threshold then -- 243
				achieved[3] = true -- 247
				count = count + 1 -- 248
			end -- 248
		elseif c3.type == "eccentricity" and c3.threshold ~= nil then -- 248
			if extra ~= nil and extra.eccentricity ~= nil and extra.eccentricity <= c3.threshold then -- 248
				achieved[3] = true -- 252
				count = count + 1 -- 253
			end -- 253
		elseif count == 2 and burnDv <= level.dvBudget * 0.5 then -- 253
			achieved[3] = true -- 256
			count = count + 1 -- 257
		end -- 257
	end -- 257
	return { -- 261
		rockets = math.min( -- 262
			3, -- 262
			math.max(0, count) -- 262
		), -- 262
		achieved = achieved, -- 263
		burnDv = burnDv, -- 264
		stats = extra ~= nil and extra or ({}) -- 265
	} -- 265
end -- 202
--- 评价一局飞行的火箭星级（0 ~ 3 枚火箭，纯函数）。
function ____exports.evaluateRockets(level, result, burnDv, extra) -- 272
	return ____exports.evaluateRocketsDetailed(level, result, burnDv, extra).rockets -- 282
end -- 272
--- 导出名与旧版一致（外部调用方按这个名字找）。
function ____exports.bodyVelocityAt(b, t) -- 294
	if b.orbitPeriod == 0 or b.orbitRadius <= 0 then -- 294
		return {x = 0, y = 0} -- 295
	end -- 295
	local angle = b.phase0 + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 296
	local w = b.orbitDirection * 2 * math.pi / b.orbitPeriod -- 297
	return { -- 298
		x = -math.sin(angle) * b.orbitRadius * w, -- 298
		y = math.cos(angle) * b.orbitRadius * w -- 298
	} -- 298
end -- 294
--- 航点列表（链式目标取 chain，否则就是唯一目标）。
function ____exports.goalWaypoints(goal) -- 302
	if goal.chain ~= nil then -- 302
		return goal.chain -- 303
	end -- 303
	if goal.kind == "planet" then -- 303
		return {{planetIndex = goal.planetIndex, tolerance = goal.tolerance}} -- 304
	end -- 304
	return {} -- 305
end -- 302
--- 采样点 i 处、相对某天体的速度（捕获判据与诊断共用同一份实现）。
-- 
-- points 里只有位置 ⇒ 用相邻采样点差分；`dt` 是**相邻采样点之间的有效步长**。
-- `limit` 是最后一个有效采样点索引（末端夹紧用）。
function ____exports.relativeSpeedAt(points, i, body, dt, t0, limit, velocities) -- 314
	local vx = 0 -- 315
	local vy = 0 -- 316
	if velocities ~= nil and velocities[i + 1] ~= nil then -- 316
		vx = velocities[i + 1].x -- 319
		vy = velocities[i + 1].y -- 320
	else -- 320
		local j1 = i + 1 <= limit and i + 1 or i -- 324
		local j0 = i > 0 and i - 1 or i -- 325
		local spanT = (j1 - j0) * dt -- 326
		if spanT > 0 then -- 326
			vx = (points[j1 + 1].x - points[j0 + 1].x) / spanT -- 328
			vy = (points[j1 + 1].y - points[j0 + 1].y) / spanT -- 329
		end -- 329
	end -- 329
	local pv = ____exports.bodyVelocityAt(body, t0) -- 332
	local rx = vx - pv.x -- 333
	local ry = vy - pv.y -- 334
	return math.sqrt(rx * rx + ry * ry) -- 335
end -- 314
--- 捕获阈值：该处逃逸速度（圆轨道速度 × 系数 k，k 默认 √2）。
function ____exports.captureThreshold(body, d, k) -- 339
	if body.gm <= 0 or d <= 0.000001 then -- 339
		return 1000000000 -- 340
	end -- 340
	return k * math.sqrt(body.gm / d) -- 341
end -- 339
--- 顺序航线的进度：返回在 points[0..upto] 里**依次**掠过的航点数与最后一个命中索引。
-- 
-- 一次线性扫描：航点必须按顺序命中，且后一个必须出现在更晚的采样点上
-- （"先到土星再路过木星"不算数）。upto 用于飞行中查询"到哪一段了"（画环的明暗）。
function ____exports.waypointProgress(points, bodies, goal, dt, t0, upto, velocities) -- 350
	local wps = ____exports.goalWaypoints(goal) -- 359
	local start = t0 ~= nil and t0 or 0 -- 360
	local limit = #points - 1 -- 361
	if upto ~= nil and upto >= 0 and upto < limit then -- 361
		limit = upto -- 362
	end -- 362
	local next = 0 -- 363
	local lastIndex = -1 -- 364
	do -- 364
		local i = 0 -- 365
		while i <= limit and next < #wps do -- 365
			do -- 365
				local w = wps[next + 1] -- 366
				local body = bodies[w.planetIndex + 1] -- 367
				if body == nil then -- 367
					return {passed = 0, lastIndex = -1} -- 368
				end -- 368
				local gp = bodyPositionAt(body, start + i * dt) -- 369
				if distance(points[i + 1], gp) < w.tolerance then -- 369
					if w.capture == true then -- 369
						local k = w.captureFactor ~= nil and w.captureFactor or 1.4142135623730951 -- 374
						local d = distance(points[i + 1], gp) -- 375
						if d <= body.radius then -- 375
							goto __continue30 -- 378
						end -- 378
						local rel = ____exports.relativeSpeedAt( -- 379
							points, -- 379
							i, -- 379
							body, -- 379
							dt, -- 379
							start + i * dt, -- 379
							limit, -- 379
							velocities -- 379
						) -- 379
						if rel > ____exports.captureThreshold(body, d, k) then -- 379
							goto __continue30 -- 380
						end -- 380
					end -- 380
					next = next + 1 -- 382
					lastIndex = i -- 383
				end -- 383
			end -- 383
			::__continue30:: -- 383
			i = i + 1 -- 365
		end -- 365
	end -- 365
	return {passed = next, lastIndex = lastIndex} -- 386
end -- 350
--- 到达目标的采样点索引；没到返回 -1。
function ____exports.findGoalIndex(points, bodies, goal, dt, t0, velocities) -- 390
	local wps = ____exports.goalWaypoints(goal) -- 391
	if #wps == 0 then -- 391
		return -1 -- 392
	end -- 392
	local st = ____exports.waypointProgress( -- 393
		points, -- 393
		bodies, -- 393
		goal, -- 393
		dt, -- 393
		t0, -- 393
		nil, -- 393
		velocities -- 393
	) -- 393
	return st.passed >= #wps and st.lastIndex or -1 -- 394
end -- 390
--- 度 → 弧度（关卡数据里写角度比写弧度好读）。
local function deg(d) -- 402
	return d * math.pi / 180 -- 403
end -- 402
--- 太阳（每关的第 0 号天体）。
local function sun() -- 407
	return { -- 408
		gm = SunGm, -- 408
		radius = SunRadius, -- 408
		orbitCenter = {x = 0, y = 0}, -- 408
		orbitRadius = 0, -- 408
		orbitPeriod = 0, -- 408
		phase0 = 0, -- 408
		orbitDirection = 1 -- 408
	} -- 408
end -- 407
--- 绕太阳公转的行星：`key` 是 Scale.REAL 里的键。
-- 
-- 真半径 0.0034（地球）到 0.0374（木星），**不再有任何放大** —— 用户要求"天体大小改为符合物理的大小"。
-- 看得见的那一层在 Tuning.BODY_VISUAL_RADIUS。
local function orbiter(key, phaseDeg) -- 417
	local real = REAL[key] -- 418
	local a = trueOrbit(real.au) -- 419
	return { -- 420
		gm = trueGm(real.gm), -- 421
		radius = trueRadius(real.radiusKm), -- 422
		orbitCenter = {x = 0, y = 0}, -- 423
		orbitRadius = a, -- 424
		orbitPeriod = period(a, SunGm), -- 425
		phase0 = deg(phaseDeg), -- 426
		orbitDirection = 1 -- 427
	} -- 427
end -- 417
--- 绕**会动的宿主**公转的卫星（L1 的月球）。
-- 
-- 周期用开普勒第三定律 `2π·sqrt(a³/μ)` 算，**μ 取宿主（地球）的 gm** ——
-- 这是最容易搞错的一步：拿月球自己的 gm 去算会得到 11.35 秒（正确值 1.2593 秒）。
local function satellite(key, host, orbitRadius, phaseDeg) -- 437
	local real = REAL[key] -- 438
	return { -- 439
		gm = trueGm(real.gm), -- 440
		radius = trueRadius(real.radiusKm), -- 441
		orbitCenter = {x = 0, y = 0}, -- 442
		orbitRadius = orbitRadius, -- 443
		orbitPeriod = period(orbitRadius, host.gm), -- 444
		phase0 = deg(phaseDeg), -- 445
		orbitDirection = 1, -- 446
		host = host -- 447
	} -- 447
end -- 437
--- 视觉描述。`levelIndex` 决定用哪张视觉半径表：0 = L1 用地月系专用表（见 Tuning）。
local function planetVisual(key, body, r, g, b, model, ring, levelIndex) -- 455
	return { -- 456
		r = r, -- 456
		g = g, -- 456
		b = b, -- 456
		displayRadius = visualRadius(key, body.radius, levelIndex), -- 456
		ring = ring, -- 456
		model = model -- 456
	} -- 456
end -- 455
--- 太阳的视觉（自发光 + 光晕）。
local function sunVisual(levelIndex) -- 460
	return { -- 462
		r = 1, -- 462
		g = 0.97, -- 462
		b = 0.88, -- 462
		displayRadius = visualRadius("sun", SunRadius, levelIndex), -- 462
		ring = false, -- 462
		model = "Sun", -- 462
		emissive = {r = 1, g = 0.95, b = 0.82} -- 462
	} -- 462
end -- 460
--- 出发轨道半径 = 1 AU（地球轨道）。六关共用 —— L1 的地球就在这里，L2–L6 从这里出发。
____exports.EarthOrbitRadius = trueOrbit(REAL.earth.au) -- 472
--- 该点的日心圆轨速度（30.00 平面单位/秒 —— 全套尺度的速度锚点）。
____exports.EarthOrbitSpeed = circularSpeed(SunGm, ____exports.EarthOrbitRadius) -- 475
--- 相位表 —— **全部由 `node tools/level-phases.mjs <关号> --dirs 240 --dvs 31 --tmax N` 解出**，不许手填。
-- 
-- ⚠️ 同一颗行星在**不同关的相位不同**，这是对的：相位代表"哪一天的太阳系"，
--    每一关的可行发射窗口本来就不一样。物理量（gm / 半径 / 轨道 / 周期）才是六关共用、不许变的。
-- 
-- 每一行后面的注释就是它的出处（工具输出），改数值必须重跑工具。
local PH = { -- 485
	mercury = 45, -- 486
	venus = 79.6, -- 488
	jupiter3 = 186.1, -- 493
	jupiter4 = 184.4, -- 494
	jupiter5 = 175.6, -- 495
	jupiter6 = 175.2, -- 496
	saturn4 = 199.6, -- 498
	saturn5 = 190.8, -- 499
	saturn6 = 190.3, -- 500
	uranus5 = 202.8, -- 502
	uranus6 = 201.8, -- 503
	neptune6 = 207.6, -- 505
	moon = 154.7 -- 513
} -- 513
--- L1：地月系。
-- 
-- - 地球是**真天体**：真 gm、真半径，自己在绕日公转（这是"物理统一"的试纸）；
-- - 月球绕地球，周期由开普勒第三定律算出 = 1.2593 秒（真实值）；
-- - 探测器在**绕地圆轨道**上，半径 0.1 单位（= 18.7 万 km = 月球距离的 49%）：
--   初始速度 = 地球的公转速度 + 绕地圆轨速度（顺行），所以预测线一上来就是一条弧线；
-- - 点火目标：抬升到月球轨道 0.2056 做霍曼转移，半程 0.4034 秒。
local function level1() -- 525
	local earthOrbit = ____exports.EarthOrbitRadius -- 526
	local earth = { -- 527
		gm = EarthGm, -- 528
		radius = EarthRadius, -- 529
		orbitCenter = {x = 0, y = 0}, -- 530
		orbitRadius = earthOrbit, -- 531
		orbitPeriod = period(earthOrbit, SunGm), -- 532
		phase0 = deg(90), -- 533
		orbitDirection = 1 -- 534
	} -- 534
	local moon = satellite("moon", earth, MoonOrbitRadius, PH.moon) -- 536
	local parking = 0.1 -- 537
	local earthPos = bodyPositionAt(earth, 0) -- 540
	local earthVel = ____exports.bodyVelocityAt(earth, 0) -- 541
	local vCirc = circularSpeed(EarthGm, parking) -- 542
	return { -- 543
		id = 1, -- 544
		title = "月球", -- 545
		probeVariant = "solar", -- 546
		brief = "月球任务 · 地球轨道：你已经在绕地球飞了 —— 月球也在走。别对着它现在的位置点火，要打提前量。", -- 547
		probeStart = {x = earthPos.x, y = earthPos.y + parking}, -- 548
		probeVel0 = {x = earthVel.x - vCirc, y = earthVel.y}, -- 549
		planets = { -- 550
			sun(), -- 550
			earth, -- 550
			moon -- 550
		}, -- 550
		visuals = { -- 554
			sunVisual(0), -- 555
			planetVisual( -- 556
				"earth", -- 556
				earth, -- 556
				0.42, -- 556
				0.62, -- 556
				0.85, -- 556
				"Planet_Earth", -- 556
				false, -- 556
				0 -- 556
			), -- 556
			planetVisual( -- 557
				"moon", -- 557
				moon, -- 557
				0.56, -- 557
				0.56, -- 557
				0.6, -- 557
				"Moon", -- 557
				false, -- 557
				0 -- 557
			) -- 557
		}, -- 557
		goal = {kind = "planet", planetIndex = 2, tolerance = 0.02}, -- 560
		dvBudget = 0.35, -- 561
		escapeRadius = 400, -- 565
		maxSteps = 2400, -- 568
		planCenter = 1, -- 569
		mission = { -- 570
			id = "L1", -- 571
			codeName = "Moon", -- 572
			historicalRef = "阿波罗 / 嫦娥探月", -- 573
			subtitle = "启蒙", -- 574
			vehicle = "flyby", -- 575
			challenges = {{desc = "成功抵达月球轨道或飞掠月球", type = "success"}, {desc = "发射点火消耗 Δv ≤ 0.28（节省 > 20%）", type = "fuel", threshold = 0.8}, {desc = "近月点距离 r_peri ≤ 0.015", type = "distance", threshold = 0.015}} -- 576
		} -- 576
	} -- 576
end -- 525
--- L2–L6 共用的出发状态：1 AU 圆轨道上的一点，顺行（-x），速度 = 该点圆轨速度。
local function departure() -- 588
	return {pos = {x = 0, y = ____exports.EarthOrbitRadius}, vel = {x = -____exports.EarthOrbitSpeed, y = 0}} -- 589
end -- 588
--- L2 水手10号：地球 ➔ 金星 ➔ 水星（人类首次行星引力借力）。
local function level2() -- 596
	local venus = orbiter("venus", PH.venus) -- 597
	local mercury = orbiter("mercury", PH.mercury) -- 598
	local d = departure() -- 599
	return { -- 600
		id = 2, -- 601
		title = "水手10号", -- 602
		probeVariant = "solar", -- 603
		brief = "水手10号 · 1 AU 出发：人类首次行星引力辅助。向内俯冲，利用金星前向借力大幅削减轨道动能，深潜入水星轨道！", -- 604
		probeStart = d.pos, -- 605
		probeVel0 = d.vel, -- 606
		planets = { -- 607
			sun(), -- 607
			venus, -- 607
			mercury -- 607
		}, -- 607
		visuals = { -- 608
			sunVisual(), -- 609
			planetVisual( -- 610
				"venus", -- 610
				venus, -- 610
				0.9, -- 610
				0.78, -- 610
				0.55, -- 610
				"Planet_Venus", -- 610
				false -- 610
			), -- 610
			planetVisual( -- 611
				"mercury", -- 611
				mercury, -- 611
				0.65, -- 611
				0.65, -- 611
				0.65, -- 611
				"Sphere", -- 611
				false -- 611
			) -- 611
		}, -- 611
		goal = {kind = "planet", planetIndex = 2, tolerance = 6, chain = {{planetIndex = 1, tolerance = 15, label = "金星"}, {planetIndex = 2, tolerance = 6, label = "水星"}}}, -- 613
		dvBudget = 4, -- 622
		escapeRadius = 3600, -- 623
		maxSteps = 4000, -- 624
		timeWindow = {span = 27}, -- 625
		mission = { -- 626
			id = "L2", -- 627
			codeName = "Mariner 10", -- 628
			historicalRef = "水手10号 (1973)", -- 629
			subtitle = "潜行", -- 630
			vehicle = "flyby", -- 631
			challenges = {{desc = "借力金星并成功抵达水星", type = "success"}, {desc = "初始点火消耗 Δv ≤ 75% 预算", type = "fuel", threshold = 0.75}, {desc = "金星交会时相对速度降幅 ≥ 12 单位", type = "speed", threshold = 12}} -- 632
		} -- 632
	} -- 632
end -- 596
--- L3 帕克号：地球 ➔ 金星 ➔ 太阳日冕区（触碰太阳极热地狱）。
local function level3() -- 642
	local venus = orbiter("venus", PH.venus) -- 643
	local d = departure() -- 644
	return { -- 645
		id = 3, -- 646
		title = "帕克号", -- 647
		probeVariant = "solar", -- 648
		brief = "帕克号 · 1 AU 出发：人类制造的最狂暴“触日者”。利用金星大幅削减日心角动量，近距离俯冲入太阳日冕危险带且未撞毁！", -- 649
		probeStart = d.pos, -- 650
		probeVel0 = d.vel, -- 651
		planets = { -- 652
			sun(), -- 652
			venus -- 652
		}, -- 652
		visuals = { -- 653
			sunVisual(), -- 654
			planetVisual( -- 655
				"venus", -- 655
				venus, -- 655
				0.9, -- 655
				0.78, -- 655
				0.55, -- 655
				"Planet_Venus", -- 655
				false -- 655
			) -- 655
		}, -- 655
		goal = {kind = "planet", planetIndex = 0, tolerance = 15}, -- 657
		dvBudget = 6, -- 662
		escapeRadius = 3600, -- 663
		maxSteps = 6000, -- 664
		timeWindow = {span = 27}, -- 665
		mission = { -- 666
			id = "L3", -- 667
			codeName = "Parker", -- 668
			historicalRef = "帕克太阳探测器 (2018)", -- 669
			subtitle = "烈日", -- 670
			vehicle = "flyby", -- 671
			challenges = {{desc = "近日点深入太阳日冕观测带 (r_peri ≤ 15) 且未撞毁", type = "success"}, {desc = "初始点火消耗 Δv ≤ 80% 预算", type = "fuel", threshold = 0.8}, {desc = "近日点最高日心速度突破 vmax ≥ 60 单位", type = "speed", threshold = 60}} -- 672
		} -- 672
	} -- 672
end -- 642
--- L4 伽利略号：地球 ➔ 木星泊入（轨道器模式正式登场）。
local function level4() -- 682
	local jupiter = orbiter("jupiter", PH.jupiter4) -- 683
	local d = departure() -- 684
	return { -- 685
		id = 4, -- 686
		title = "伽利略号", -- 687
		probeVariant = "rtg", -- 688
		brief = "伽利略号 · 1 AU 出发：人类第一艘长期驻留环绕木星的轨道器。抵达木星巨型引力井，在慢动作特写中捕捉制动窗口，按下 [ BRAKE ] 优雅泊入闭合环绕轨！", -- 689
		probeStart = d.pos, -- 690
		probeVel0 = d.vel, -- 691
		planets = { -- 692
			sun(), -- 692
			jupiter -- 692
		}, -- 692
		visuals = { -- 693
			sunVisual(), -- 694
			planetVisual( -- 695
				"jupiter", -- 695
				jupiter, -- 695
				0.85, -- 695
				0.72, -- 695
				0.5, -- 695
				"Planet_Jupiter", -- 695
				false -- 695
			) -- 695
		}, -- 695
		goal = {kind = "planet", planetIndex = 1, tolerance = 40, chain = {{planetIndex = 1, tolerance = 40, label = "木星", capture = true}}}, -- 697
		dvBudget = 14, -- 705
		escapeRadius = 3600, -- 706
		maxSteps = 25000, -- 707
		timeWindow = {span = 18}, -- 708
		mission = { -- 709
			id = "L4", -- 710
			codeName = "Galileo", -- 711
			historicalRef = "伽利略号 (1989)", -- 712
			subtitle = "泊入", -- 713
			vehicle = "orbiter", -- 714
			challenges = {{desc = "在制动窗口内成功按下刹车闭合入轨", type = "success"}, {desc = "地面发射点火 Δv ≤ 70% 预算", type = "fuel", threshold = 0.7}, {desc = "入轨偏心率 e ≤ 0.25", type = "eccentricity", threshold = 0.25}} -- 715
		} -- 715
	} -- 715
end -- 682
--- L5 新视野号：地球 ➔ 木星狂暴加速 ➔ 柯伊伯带深空。
local function level5() -- 725
	local jupiter = orbiter("jupiter", PH.jupiter5) -- 726
	local d = departure() -- 727
	return { -- 728
		id = 5, -- 729
		title = "新视野号", -- 730
		probeVariant = "rtg", -- 731
		brief = "新视野号 · 1 AU 出发：人类有史以来最狂暴的深空信使。寻找木星后向加速最佳切角，利用太阳系最强引力弹弓把探测器甩向柯伊伯带深空外边界！", -- 732
		probeStart = d.pos, -- 733
		probeVel0 = d.vel, -- 734
		planets = { -- 735
			sun(), -- 735
			jupiter -- 735
		}, -- 735
		visuals = { -- 736
			sunVisual(), -- 737
			planetVisual( -- 738
				"jupiter", -- 738
				jupiter, -- 738
				0.85, -- 738
				0.72, -- 738
				0.5, -- 738
				"Planet_Jupiter", -- 738
				false -- 738
			) -- 738
		}, -- 738
		goal = {kind = "escape", planetIndex = 1, tolerance = 40, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}}}, -- 740
		dvBudget = 15, -- 748
		escapeRadius = 3600, -- 749
		maxSteps = 35000, -- 750
		timeWindow = {span = 17.5}, -- 751
		mission = { -- 752
			id = "L5", -- 753
			codeName = "New Horizons", -- 754
			historicalRef = "新视野号 (2006)", -- 755
			subtitle = "狂飙", -- 756
			vehicle = "flyby", -- 757
			challenges = {{desc = "借力木星获得逃逸能量抵达外边界", type = "success"}, {desc = "地面发射初速消耗 Δv ≤ 75% 预算", type = "fuel", threshold = 0.75}, {desc = "速度增幅 ≥ 15 且逃逸末速度 vend ≥ 40", type = "speed", threshold = 40}} -- 758
		} -- 758
	} -- 758
end -- 725
--- L6 旅行者2号：地球 ➔ 木星 ➔ 土星 ➔ 天王星 ➔ 海王星 ➔ 星际空间。
local function level6() -- 768
	local jupiter = orbiter("jupiter", PH.jupiter6) -- 769
	local saturn = orbiter("saturn", PH.saturn6) -- 770
	local uranus = orbiter("uranus", PH.uranus6) -- 771
	local neptune = orbiter("neptune", PH.neptune6) -- 772
	local d = departure() -- 773
	return { -- 774
		id = 6, -- 775
		title = "旅行者2号", -- 776
		probeVariant = "rtg", -- 777
		brief = "旅行者2号 · 1 AU 出发：175 年一遇的行星连珠奇迹！对准发射窗口，连续四星接力借力飞出海王星轨道，冲入星际空间，触发暗淡蓝点终章！", -- 778
		probeStart = d.pos, -- 779
		probeVel0 = d.vel, -- 780
		planets = { -- 781
			sun(), -- 781
			jupiter, -- 781
			saturn, -- 781
			uranus, -- 781
			neptune -- 781
		}, -- 781
		visuals = { -- 782
			sunVisual(), -- 783
			planetVisual( -- 784
				"jupiter", -- 784
				jupiter, -- 784
				0.85, -- 784
				0.72, -- 784
				0.5, -- 784
				"Planet_Jupiter", -- 784
				false -- 784
			), -- 784
			planetVisual( -- 785
				"saturn", -- 785
				saturn, -- 785
				0.75, -- 785
				0.7, -- 785
				0.6, -- 785
				"Planet_Saturn", -- 785
				true -- 785
			), -- 785
			planetVisual( -- 786
				"uranus", -- 786
				uranus, -- 786
				0.62, -- 786
				0.82, -- 786
				0.86, -- 786
				"Planet_Uranus", -- 786
				false -- 786
			), -- 786
			planetVisual( -- 787
				"neptune", -- 787
				neptune, -- 787
				0.34, -- 787
				0.5, -- 787
				0.86, -- 787
				"Planet_Neptune", -- 787
				false -- 787
			) -- 787
		}, -- 787
		goal = {kind = "planet", planetIndex = 4, tolerance = 120, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 60, label = "土星"}, {planetIndex = 3, tolerance = 90, label = "天王星"}, {planetIndex = 4, tolerance = 120, label = "海王星"}}}, -- 789
		dvBudget = 16, -- 800
		escapeRadius = 3600, -- 801
		maxSteps = 70000, -- 802
		timeWindow = {span = 17.5}, -- 803
		mission = { -- 804
			id = "L6", -- 805
			codeName = "Voyager 2", -- 806
			historicalRef = "旅行者2号 (1977)", -- 807
			subtitle = "奇迹", -- 808
			vehicle = "flyby", -- 809
			challenges = {{desc = "成功四星连续借力并飞出海王星轨道", type = "success"}, {desc = "初始发射点火 Δv ≤ 80% 预算", type = "fuel", threshold = 0.8}, {desc = "四星交会无碰撞且近心点精度 ≤ 5%", type = "distance", threshold = 0.05}} -- 810
		} -- 810
	} -- 810
end -- 768
local LEVELS = { -- 819
	level1(), -- 819
	level2(), -- 819
	level3(), -- 819
	level4(), -- 819
	level5(), -- 819
	level6() -- 819
} -- 819
--- 关卡总数。
function ____exports.levelCount() -- 822
	return #LEVELS -- 823
end -- 822
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 827
	return LEVELS[index + 1] -- 828
end -- 827
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 832
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 833
end -- 832
return ____exports -- 832