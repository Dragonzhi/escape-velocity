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
local KmPerUnit = ____Scale.KmPerUnit -- 51
local MoonOrbitRadius = ____Scale.MoonOrbitRadius -- 51
local REAL = ____Scale.REAL -- 51
local SecPerGameSec = ____Scale.SecPerGameSec -- 51
local SunGm = ____Scale.SunGm -- 51
local SunRadius = ____Scale.SunRadius -- 51
local circularSpeed = ____Scale.circularSpeed -- 52
local period = ____Scale.period -- 52
local trueGm = ____Scale.trueGm -- 52
local trueOrbit = ____Scale.trueOrbit -- 52
local trueRadius = ____Scale.trueRadius -- 52
local ____Tuning = require("game.Tuning") -- 54
local visualRadius = ____Tuning.visualRadius -- 54
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 865
	local out = {} -- 866
	for ____, b in ipairs(bodies) do -- 867
		out[#out + 1] = { -- 868
			gm = b.gm * gravityScale, -- 869
			radius = b.radius, -- 870
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 871
			orbitRadius = b.orbitRadius, -- 872
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 873
			phase0 = b.phase0, -- 874
			orbitDirection = b.orbitDirection, -- 875
			host = b.host ~= nil and applyScalesLocal({b.host}, gravityScale, orbitScale)[1] or nil -- 877
		} -- 877
	end -- 877
	return out -- 880
end -- 880
--- 评价一局飞行的火箭星级及逐条达成详情（纯函数）。
function ____exports.evaluateRocketsDetailed(level, result, burnDv, extra) -- 204
	local achieved = {false, false, false} -- 214
	if result ~= "success" then -- 214
		return {rockets = 0, achieved = achieved, burnDv = burnDv, stats = extra ~= nil and extra or ({})} -- 216
	end -- 216
	achieved[1] = true -- 224
	local count = 1 -- 225
	local challenges = level.mission ~= nil and level.mission.challenges or nil -- 226
	if challenges ~= nil then -- 226
		local c2 = challenges[2] -- 229
		if c2.type == "fuel" and c2.threshold ~= nil then -- 229
			if burnDv <= level.dvBudget * c2.threshold then -- 229
				achieved[2] = true -- 232
				count = count + 1 -- 233
			end -- 233
		elseif burnDv <= level.dvBudget * 0.8 then -- 233
			achieved[2] = true -- 236
			count = count + 1 -- 237
		end -- 237
		local c3 = challenges[3] -- 241
		if c3.type == "distance" and c3.threshold ~= nil then -- 241
			if extra ~= nil and extra.closestDist ~= nil and extra.closestDist <= c3.threshold then -- 241
				achieved[3] = true -- 244
				count = count + 1 -- 245
			end -- 245
		elseif c3.type == "speed" and c3.threshold ~= nil then -- 245
			if extra ~= nil and extra.maxSpeed ~= nil and extra.maxSpeed >= c3.threshold then -- 245
				achieved[3] = true -- 249
				count = count + 1 -- 250
			end -- 250
		elseif c3.type == "eccentricity" and c3.threshold ~= nil then -- 250
			if extra ~= nil and extra.eccentricity ~= nil and extra.eccentricity <= c3.threshold then -- 250
				achieved[3] = true -- 254
				count = count + 1 -- 255
			end -- 255
		elseif count == 2 and burnDv <= level.dvBudget * 0.5 then -- 255
			achieved[3] = true -- 258
			count = count + 1 -- 259
		end -- 259
	end -- 259
	return { -- 263
		rockets = math.min( -- 264
			3, -- 264
			math.max(0, count) -- 264
		), -- 264
		achieved = achieved, -- 265
		burnDv = burnDv, -- 266
		stats = extra ~= nil and extra or ({}) -- 267
	} -- 267
end -- 204
--- 评价一局飞行的火箭星级（0 ~ 3 枚火箭，纯函数）。
function ____exports.evaluateRockets(level, result, burnDv, extra) -- 274
	return ____exports.evaluateRocketsDetailed(level, result, burnDv, extra).rockets -- 284
end -- 274
--- 导出名与旧版一致（外部调用方按这个名字找）。
function ____exports.bodyVelocityAt(b, t) -- 296
	if b.orbitPeriod == 0 or b.orbitRadius <= 0 then -- 296
		return {x = 0, y = 0} -- 297
	end -- 297
	local angle = b.phase0 + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 298
	local w = b.orbitDirection * 2 * math.pi / b.orbitPeriod -- 299
	return { -- 300
		x = -math.sin(angle) * b.orbitRadius * w, -- 300
		y = math.cos(angle) * b.orbitRadius * w -- 300
	} -- 300
end -- 296
--- 航点列表（链式目标取 chain，否则就是唯一目标）。
function ____exports.goalWaypoints(goal) -- 304
	if goal.chain ~= nil then -- 304
		return goal.chain -- 305
	end -- 305
	if goal.kind == "planet" then -- 305
		return {{planetIndex = goal.planetIndex, tolerance = goal.tolerance}} -- 306
	end -- 306
	return {} -- 307
end -- 304
--- 采样点 i 处、相对某天体的速度（捕获判据与诊断共用同一份实现）。
-- 
-- points 里只有位置 ⇒ 用相邻采样点差分；`dt` 是**相邻采样点之间的有效步长**。
-- `limit` 是最后一个有效采样点索引（末端夹紧用）。
function ____exports.relativeSpeedAt(points, i, body, dt, t0, limit, velocities) -- 316
	local vx = 0 -- 317
	local vy = 0 -- 318
	if velocities ~= nil and velocities[i + 1] ~= nil then -- 318
		vx = velocities[i + 1].x -- 321
		vy = velocities[i + 1].y -- 322
	else -- 322
		local j1 = i + 1 <= limit and i + 1 or i -- 326
		local j0 = i > 0 and i - 1 or i -- 327
		local spanT = (j1 - j0) * dt -- 328
		if spanT > 0 then -- 328
			vx = (points[j1 + 1].x - points[j0 + 1].x) / spanT -- 330
			vy = (points[j1 + 1].y - points[j0 + 1].y) / spanT -- 331
		end -- 331
	end -- 331
	local pv = ____exports.bodyVelocityAt(body, t0) -- 334
	local rx = vx - pv.x -- 335
	local ry = vy - pv.y -- 336
	return math.sqrt(rx * rx + ry * ry) -- 337
end -- 316
--- 捕获阈值：该处逃逸速度（圆轨道速度 × 系数 k，k 默认 √2）。
function ____exports.captureThreshold(body, d, k) -- 341
	if body.gm <= 0 or d <= 0.000001 then -- 341
		return 1000000000 -- 342
	end -- 342
	return k * math.sqrt(body.gm / d) -- 343
end -- 341
--- 顺序航线的进度：返回在 points[0..upto] 里**依次**掠过的航点数与最后一个命中索引。
-- 
-- 一次线性扫描：航点必须按顺序命中，且后一个必须出现在更晚的采样点上
-- （"先到土星再路过木星"不算数）。upto 用于飞行中查询"到哪一段了"（画环的明暗）。
function ____exports.waypointProgress(points, bodies, goal, dt, t0, upto, velocities) -- 352
	local wps = ____exports.goalWaypoints(goal) -- 361
	local start = t0 ~= nil and t0 or 0 -- 362
	local limit = #points - 1 -- 363
	if upto ~= nil and upto >= 0 and upto < limit then -- 363
		limit = upto -- 364
	end -- 364
	local next = 0 -- 365
	local lastIndex = -1 -- 366
	do -- 366
		local i = 0 -- 367
		while i <= limit and next < #wps do -- 367
			do -- 367
				local w = wps[next + 1] -- 368
				local body = bodies[w.planetIndex + 1] -- 369
				if body == nil then -- 369
					return {passed = 0, lastIndex = -1} -- 370
				end -- 370
				local gp = bodyPositionAt(body, start + i * dt) -- 371
				if distance(points[i + 1], gp) < w.tolerance then -- 371
					if w.capture == true then -- 371
						local k = w.captureFactor ~= nil and w.captureFactor or 1.4142135623730951 -- 376
						local d = distance(points[i + 1], gp) -- 377
						if d <= body.radius then -- 377
							goto __continue30 -- 380
						end -- 380
						local rel = ____exports.relativeSpeedAt( -- 381
							points, -- 381
							i, -- 381
							body, -- 381
							dt, -- 381
							start + i * dt, -- 381
							limit, -- 381
							velocities -- 381
						) -- 381
						if rel > ____exports.captureThreshold(body, d, k) then -- 381
							goto __continue30 -- 382
						end -- 382
					end -- 382
					next = next + 1 -- 384
					lastIndex = i -- 385
				end -- 385
			end -- 385
			::__continue30:: -- 385
			i = i + 1 -- 367
		end -- 367
	end -- 367
	return {passed = next, lastIndex = lastIndex} -- 388
end -- 352
--- 到达目标的采样点索引；没到返回 -1。
function ____exports.findGoalIndex(points, bodies, goal, dt, t0, velocities) -- 392
	local wps = ____exports.goalWaypoints(goal) -- 393
	if #wps == 0 then -- 393
		return -1 -- 394
	end -- 394
	local st = ____exports.waypointProgress( -- 395
		points, -- 395
		bodies, -- 395
		goal, -- 395
		dt, -- 395
		t0, -- 395
		nil, -- 395
		velocities -- 395
	) -- 395
	return st.passed >= #wps and st.lastIndex or -1 -- 396
end -- 392
--- 度 → 弧度（关卡数据里写角度比写弧度好读）。
local function deg(d) -- 404
	return d * math.pi / 180 -- 405
end -- 404
--- 太阳（每关的第 0 号天体）。
local function sun() -- 409
	return { -- 410
		gm = SunGm, -- 410
		radius = SunRadius, -- 410
		orbitCenter = {x = 0, y = 0}, -- 410
		orbitRadius = 0, -- 410
		orbitPeriod = 0, -- 410
		phase0 = 0, -- 410
		orbitDirection = 1 -- 410
	} -- 410
end -- 409
--- 绕太阳公转的行星：`key` 是 Scale.REAL 里的键。
-- 
-- 真半径 0.0034（地球）到 0.0374（木星），**不再有任何放大** —— 用户要求"天体大小改为符合物理的大小"。
-- 看得见的那一层在 Tuning.BODY_VISUAL_RADIUS。
local function orbiter(key, phaseDeg) -- 419
	local real = REAL[key] -- 420
	local a = trueOrbit(real.au) -- 421
	return { -- 422
		gm = trueGm(real.gm), -- 423
		radius = trueRadius(real.radiusKm), -- 424
		orbitCenter = {x = 0, y = 0}, -- 425
		orbitRadius = a, -- 426
		orbitPeriod = period(a, SunGm), -- 427
		phase0 = deg(phaseDeg), -- 428
		orbitDirection = 1 -- 429
	} -- 429
end -- 419
--- 绕**会动的宿主**公转的卫星（L1 的月球）。
-- 
-- 周期用开普勒第三定律 `2π·sqrt(a³/μ)` 算，**μ 取宿主（地球）的 gm** ——
-- 这是最容易搞错的一步：拿月球自己的 gm 去算会得到 11.35 秒（正确值 1.2593 秒）。
local function satellite(key, host, orbitRadius, phaseDeg) -- 439
	local real = REAL[key] -- 440
	return { -- 441
		gm = trueGm(real.gm), -- 442
		radius = trueRadius(real.radiusKm), -- 443
		orbitCenter = {x = 0, y = 0}, -- 444
		orbitRadius = orbitRadius, -- 445
		orbitPeriod = period(orbitRadius, host.gm), -- 446
		phase0 = deg(phaseDeg), -- 447
		orbitDirection = 1, -- 448
		host = host -- 449
	} -- 449
end -- 439
--- 视觉描述。`levelIndex` 决定用哪张视觉半径表：0 = L1 用地月系专用表（见 Tuning）。
local function planetVisual(key, body, r, g, b, model, ring, levelIndex) -- 457
	return { -- 458
		r = r, -- 458
		g = g, -- 458
		b = b, -- 458
		displayRadius = visualRadius(key, body.radius, levelIndex), -- 458
		ring = ring, -- 458
		model = model -- 458
	} -- 458
end -- 457
--- 太阳的视觉（自发光 + 光晕）。
local function sunVisual(levelIndex) -- 462
	return { -- 464
		r = 1, -- 464
		g = 0.97, -- 464
		b = 0.88, -- 464
		displayRadius = visualRadius("sun", SunRadius, levelIndex), -- 464
		ring = false, -- 464
		model = "Sun", -- 464
		emissive = {r = 1, g = 0.95, b = 0.82} -- 464
	} -- 464
end -- 462
--- 出发轨道半径 = 1 AU（地球轨道）。六关共用 —— L1 的地球就在这里，L2–L6 从这里出发。
____exports.EarthOrbitRadius = trueOrbit(REAL.earth.au) -- 474
--- **1 真实秒 = 多少游戏秒**（B3，2026-09-28）。
-- 
-- 全项目只有这里读 Scale，别处（Game / Hud / init）都从这里拿 —— 于是"倍速档位"
-- 的单位可以老实写成「×现实时间」：档位 pow ⇒ 速率 = 10^pow × 本常数。
-- pow = 0 就是 1×（现实 1 秒）。
____exports.GameSecondsPerRealSecond = 1 / SecPerGameSec -- 483
--- 该点的日心圆轨速度（30.00 平面单位/秒 —— 全套尺度的速度锚点）。
____exports.EarthOrbitSpeed = circularSpeed(SunGm, ____exports.EarthOrbitRadius) -- 486
--- 相位表 —— **全部由 `node tools/level-phases.mjs <关号> --dirs 240 --dvs 31 --tmax N` 解出**，不许手填。
-- 
-- ⚠️ 同一颗行星在**不同关的相位不同**，这是对的：相位代表"哪一天的太阳系"，
--    每一关的可行发射窗口本来就不一样。物理量（gm / 半径 / 轨道 / 周期）才是六关共用、不许变的。
-- 
-- 每一行后面的注释就是它的出处（工具输出），改数值必须重跑工具。
local PH = { -- 496
	mercury = 2.2, -- 503
	venus = 37.6, -- 504
	jupiter3 = 186.1, -- 509
	jupiter4 = 184.4, -- 510
	jupiter5 = 175.6, -- 511
	jupiter6 = 175.2, -- 512
	saturn4 = 199.6, -- 514
	saturn5 = 190.8, -- 515
	saturn6 = 190.3, -- 516
	uranus5 = 202.8, -- 518
	uranus6 = 201.8, -- 519
	neptune6 = 207.6, -- 521
	moon = 202 -- 534
} -- 534
--- L1：地月系。
-- 
-- - 地球是**真天体**：真 gm、真半径，自己在绕日公转（这是"物理统一"的试纸）；
-- - 月球绕地球，周期由开普勒第三定律算出 = 1.2593 秒（真实值）；
-- - 探测器在**真实的阿波罗停泊轨**上：200 km 高度（地心 6,571 km = **3.514e-3 单位**），
--   停泊周期 **88.4 分钟**、圆轨速度 7.788 km/s；初始速度 = 地球的公转速度 + 绕地圆轨速度（顺行）；
-- - 点火目标：TLI —— 抬到月球轨道 0.2056，需要 **3.133 km/s（≈ 阿波罗实测 3.05–3.15）**，
--   转移到月球 **4.978 天**（一圈 : 转移 = 1 : 81，这一关的时间跨度就是它）。
-- 
-- 数值出处与实测见 [`docs/L1重构设计案.md`](../docs/L1重构设计案.md) 第二节。
local function level1() -- 549
	local earthOrbit = ____exports.EarthOrbitRadius -- 550
	local earth = { -- 551
		gm = EarthGm, -- 552
		radius = EarthRadius, -- 553
		orbitCenter = {x = 0, y = 0}, -- 554
		orbitRadius = earthOrbit, -- 555
		orbitPeriod = period(earthOrbit, SunGm), -- 556
		phase0 = deg(90), -- 557
		orbitDirection = 1 -- 558
	} -- 558
	local moon = satellite("moon", earth, MoonOrbitRadius, PH.moon) -- 560
	local parking = (REAL.earth.radiusKm + 200) / KmPerUnit -- 563
	local earthPos = bodyPositionAt(earth, 0) -- 566
	local earthVel = ____exports.bodyVelocityAt(earth, 0) -- 567
	local vCirc = circularSpeed(EarthGm, parking) -- 568
	return { -- 569
		id = 1, -- 570
		title = "月球", -- 571
		probeVariant = "solar", -- 572
		brief = "月球任务 · 近地停泊轨 200 km：你正在绕地球飞，月球在 38 万 km 外。点火把它推向月球 —— 这一程要飞 5 天，别对着月球现在的位置点火。", -- 573
		probeStart = {x = earthPos.x, y = earthPos.y + parking}, -- 574
		probeVel0 = {x = earthVel.x - vCirc, y = earthVel.y}, -- 575
		planets = { -- 576
			sun(), -- 576
			earth, -- 576
			moon -- 576
		}, -- 576
		visuals = { -- 580
			sunVisual(0), -- 581
			planetVisual( -- 582
				"earth", -- 582
				earth, -- 582
				0.42, -- 582
				0.62, -- 582
				0.85, -- 582
				"Planet_Earth", -- 582
				false, -- 582
				0 -- 582
			), -- 582
			planetVisual( -- 583
				"moon", -- 583
				moon, -- 583
				0.56, -- 583
				0.56, -- 583
				0.6, -- 583
				"Moon", -- 583
				false, -- 583
				0 -- 583
			) -- 583
		}, -- 583
		goal = {kind = "planet", planetIndex = 2, tolerance = 0.02}, -- 586
		dvBudget = 4.6, -- 588
		escapeRadius = 400, -- 592
		maxSteps = 8000, -- 596
		planCenter = 1, -- 597
		mission = { -- 598
			id = "L1", -- 599
			codeName = "Moon", -- 600
			historicalRef = "阿波罗 / 嫦娥探月", -- 601
			subtitle = "启蒙", -- 602
			vehicle = "flyby", -- 603
			challenges = {{desc = "成功抵达月球轨道或飞掠月球", type = "success"}, {desc = "发射点火消耗 Δv ≤ 3.68（预算的 80%）", type = "fuel", threshold = 0.8}, {desc = "近月点距离 r_peri ≤ 0.003（≈ 5,600 km）", type = "distance", threshold = 0.003}} -- 604
		} -- 604
	} -- 604
end -- 549
--- L2–L6 共用的出发状态：1 AU 圆轨道上的一点，顺行（-x），速度 = 该点圆轨速度。
local function departure() -- 616
	return {pos = {x = 0, y = ____exports.EarthOrbitRadius}, vel = {x = -____exports.EarthOrbitSpeed, y = 0}} -- 617
end -- 616
--- L2 水手10号：地球 ➔ 金星 ➔ 水星（人类首次行星引力借力）。
local function level2() -- 624
	local venus = orbiter("venus", PH.venus) -- 625
	local mercury = orbiter("mercury", PH.mercury) -- 626
	local d = departure() -- 627
	return { -- 628
		id = 2, -- 629
		title = "水手10号", -- 630
		probeVariant = "solar", -- 631
		brief = "水手10号 · 1 AU 出发：人类首次行星引力辅助。向内俯冲，利用金星前向借力大幅削减轨道动能，深潜入水星轨道！", -- 632
		probeStart = d.pos, -- 633
		probeVel0 = d.vel, -- 634
		planets = { -- 635
			sun(), -- 635
			venus, -- 635
			mercury -- 635
		}, -- 635
		visuals = { -- 636
			sunVisual(), -- 637
			planetVisual( -- 638
				"venus", -- 638
				venus, -- 638
				0.9, -- 638
				0.78, -- 638
				0.55, -- 638
				"Planet_Venus", -- 638
				false -- 638
			), -- 638
			planetVisual( -- 639
				"mercury", -- 639
				mercury, -- 639
				0.65, -- 639
				0.65, -- 639
				0.65, -- 639
				"Planet_Mercury", -- 639
				false -- 639
			) -- 639
		}, -- 639
		goal = {kind = "planet", planetIndex = 2, tolerance = 6, chain = {{planetIndex = 1, tolerance = 0.4, label = "金星"}, {planetIndex = 2, tolerance = 6, label = "水星"}}}, -- 641
		dvBudget = 3.5, -- 650
		escapeRadius = 3600, -- 651
		maxSteps = 4000, -- 652
		timeWindow = {span = 27}, -- 653
		mission = { -- 654
			id = "L2", -- 655
			codeName = "Mariner 10", -- 656
			historicalRef = "水手10号 (1973)", -- 657
			subtitle = "潜行", -- 658
			vehicle = "flyby", -- 659
			challenges = {{desc = "借力金星并成功抵达水星", type = "success"}, {desc = "初始点火消耗 Δv ≤ 2.65", type = "fuel", threshold = 0.75}, {desc = "金星近心点距离 r_peri ≤ 0.35", type = "distance", threshold = 0.35, targetPlanetIndex = 1}} -- 660
		} -- 660
	} -- 660
end -- 624
--- L3 帕克号：地球 ➔ 金星 ➔ 太阳日冕区（触碰太阳极热地狱）。
local function level3() -- 670
	local venus = orbiter("venus", PH.venus) -- 671
	local d = departure() -- 672
	return { -- 673
		id = 3, -- 674
		title = "帕克号", -- 675
		probeVariant = "solar", -- 676
		brief = "帕克号 · 1 AU 出发：人类制造的最狂暴“触日者”。利用金星大幅削减日心角动量，近距离俯冲入太阳日冕危险带且未撞毁！", -- 677
		probeStart = d.pos, -- 678
		probeVel0 = d.vel, -- 679
		planets = { -- 680
			sun(), -- 680
			venus -- 680
		}, -- 680
		visuals = { -- 681
			sunVisual(), -- 682
			planetVisual( -- 683
				"venus", -- 683
				venus, -- 683
				0.9, -- 683
				0.78, -- 683
				0.55, -- 683
				"Planet_Venus", -- 683
				false -- 683
			) -- 683
		}, -- 683
		goal = {kind = "planet", planetIndex = 0, tolerance = 15}, -- 685
		dvBudget = 6, -- 690
		escapeRadius = 3600, -- 691
		maxSteps = 6000, -- 692
		timeWindow = {span = 27}, -- 693
		mission = { -- 694
			id = "L3", -- 695
			codeName = "Parker", -- 696
			historicalRef = "帕克太阳探测器 (2018)", -- 697
			subtitle = "烈日", -- 698
			vehicle = "flyby", -- 699
			challenges = {{desc = "近日点深入太阳日冕观测带 (r_peri ≤ 15) 且未撞毁", type = "success"}, {desc = "初始点火消耗 Δv ≤ 80% 预算", type = "fuel", threshold = 0.8}, {desc = "近日点最高日心速度突破 vmax ≥ 60 单位", type = "speed", threshold = 60}} -- 700
		} -- 700
	} -- 700
end -- 670
--- L4 伽利略号：地球 ➔ 木星泊入（轨道器模式正式登场）。
local function level4() -- 710
	local jupiter = orbiter("jupiter", PH.jupiter4) -- 711
	local d = departure() -- 712
	return { -- 713
		id = 4, -- 714
		title = "伽利略号", -- 715
		probeVariant = "rtg", -- 716
		brief = "伽利略号 · 1 AU 出发：人类第一艘长期驻留环绕木星的轨道器。抵达木星巨型引力井，在慢动作特写中捕捉制动窗口，按下 [ BRAKE ] 优雅泊入闭合环绕轨！", -- 717
		probeStart = d.pos, -- 718
		probeVel0 = d.vel, -- 719
		planets = { -- 720
			sun(), -- 720
			jupiter -- 720
		}, -- 720
		visuals = { -- 721
			sunVisual(), -- 722
			planetVisual( -- 723
				"jupiter", -- 723
				jupiter, -- 723
				0.85, -- 723
				0.72, -- 723
				0.5, -- 723
				"Planet_Jupiter", -- 723
				false -- 723
			) -- 723
		}, -- 723
		goal = {kind = "planet", planetIndex = 1, tolerance = 40, chain = {{planetIndex = 1, tolerance = 40, label = "木星", capture = true}}}, -- 725
		dvBudget = 14, -- 733
		escapeRadius = 3600, -- 734
		maxSteps = 25000, -- 735
		timeWindow = {span = 18}, -- 736
		mission = { -- 737
			id = "L4", -- 738
			codeName = "Galileo", -- 739
			historicalRef = "伽利略号 (1989)", -- 740
			subtitle = "泊入", -- 741
			vehicle = "orbiter", -- 742
			challenges = {{desc = "在制动窗口内成功按下刹车闭合入轨", type = "success"}, {desc = "地面发射点火 Δv ≤ 70% 预算", type = "fuel", threshold = 0.7}, {desc = "入轨偏心率 e ≤ 0.25", type = "eccentricity", threshold = 0.25}} -- 743
		} -- 743
	} -- 743
end -- 710
--- L5 新视野号：地球 ➔ 木星狂暴加速 ➔ 柯伊伯带深空。
local function level5() -- 753
	local jupiter = orbiter("jupiter", PH.jupiter5) -- 754
	local d = departure() -- 755
	return { -- 756
		id = 5, -- 757
		title = "新视野号", -- 758
		probeVariant = "rtg", -- 759
		brief = "新视野号 · 1 AU 出发：人类有史以来最狂暴的深空信使。寻找木星后向加速最佳切角，利用太阳系最强引力弹弓把探测器甩向柯伊伯带深空外边界！", -- 760
		probeStart = d.pos, -- 761
		probeVel0 = d.vel, -- 762
		planets = { -- 763
			sun(), -- 763
			jupiter -- 763
		}, -- 763
		visuals = { -- 764
			sunVisual(), -- 765
			planetVisual( -- 766
				"jupiter", -- 766
				jupiter, -- 766
				0.85, -- 766
				0.72, -- 766
				0.5, -- 766
				"Planet_Jupiter", -- 766
				false -- 766
			) -- 766
		}, -- 766
		goal = {kind = "escape", planetIndex = 1, tolerance = 40, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}}}, -- 768
		dvBudget = 15, -- 776
		escapeRadius = 3600, -- 777
		maxSteps = 35000, -- 778
		timeWindow = {span = 17.5}, -- 779
		mission = { -- 780
			id = "L5", -- 781
			codeName = "New Horizons", -- 782
			historicalRef = "新视野号 (2006)", -- 783
			subtitle = "狂飙", -- 784
			vehicle = "flyby", -- 785
			challenges = {{desc = "借力木星获得逃逸能量抵达外边界", type = "success"}, {desc = "地面发射初速消耗 Δv ≤ 75% 预算", type = "fuel", threshold = 0.75}, {desc = "速度增幅 ≥ 15 且逃逸末速度 vend ≥ 40", type = "speed", threshold = 40}} -- 786
		} -- 786
	} -- 786
end -- 753
--- L6 旅行者2号：地球 ➔ 木星 ➔ 土星 ➔ 天王星 ➔ 海王星 ➔ 星际空间。
local function level6() -- 796
	local jupiter = orbiter("jupiter", PH.jupiter6) -- 797
	local saturn = orbiter("saturn", PH.saturn6) -- 798
	local uranus = orbiter("uranus", PH.uranus6) -- 799
	local neptune = orbiter("neptune", PH.neptune6) -- 800
	local d = departure() -- 801
	return { -- 802
		id = 6, -- 803
		title = "旅行者2号", -- 804
		probeVariant = "rtg", -- 805
		brief = "旅行者2号 · 1 AU 出发：175 年一遇的行星连珠奇迹！对准发射窗口，连续四星接力借力飞出海王星轨道，冲入星际空间，触发暗淡蓝点终章！", -- 806
		probeStart = d.pos, -- 807
		probeVel0 = d.vel, -- 808
		planets = { -- 809
			sun(), -- 809
			jupiter, -- 809
			saturn, -- 809
			uranus, -- 809
			neptune -- 809
		}, -- 809
		visuals = { -- 810
			sunVisual(), -- 811
			planetVisual( -- 812
				"jupiter", -- 812
				jupiter, -- 812
				0.85, -- 812
				0.72, -- 812
				0.5, -- 812
				"Planet_Jupiter", -- 812
				false -- 812
			), -- 812
			planetVisual( -- 813
				"saturn", -- 813
				saturn, -- 813
				0.75, -- 813
				0.7, -- 813
				0.6, -- 813
				"Planet_Saturn", -- 813
				true -- 813
			), -- 813
			planetVisual( -- 814
				"uranus", -- 814
				uranus, -- 814
				0.62, -- 814
				0.82, -- 814
				0.86, -- 814
				"Planet_Uranus", -- 814
				false -- 814
			), -- 814
			planetVisual( -- 815
				"neptune", -- 815
				neptune, -- 815
				0.34, -- 815
				0.5, -- 815
				0.86, -- 815
				"Planet_Neptune", -- 815
				false -- 815
			) -- 815
		}, -- 815
		goal = {kind = "planet", planetIndex = 4, tolerance = 120, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 60, label = "土星"}, {planetIndex = 3, tolerance = 90, label = "天王星"}, {planetIndex = 4, tolerance = 120, label = "海王星"}}}, -- 817
		dvBudget = 16, -- 828
		escapeRadius = 3600, -- 829
		maxSteps = 70000, -- 830
		timeWindow = {span = 17.5}, -- 831
		mission = { -- 832
			id = "L6", -- 833
			codeName = "Voyager 2", -- 834
			historicalRef = "旅行者2号 (1977)", -- 835
			subtitle = "奇迹", -- 836
			vehicle = "flyby", -- 837
			challenges = {{desc = "成功四星连续借力并飞出海王星轨道", type = "success"}, {desc = "初始发射点火 Δv ≤ 80% 预算", type = "fuel", threshold = 0.8}, {desc = "四星交会无碰撞且近心点精度 ≤ 5%", type = "distance", threshold = 0.05}} -- 838
		} -- 838
	} -- 838
end -- 796
local LEVELS = { -- 847
	level1(), -- 847
	level2(), -- 847
	level3(), -- 847
	level4(), -- 847
	level5(), -- 847
	level6() -- 847
} -- 847
--- 关卡总数。
function ____exports.levelCount() -- 850
	return #LEVELS -- 851
end -- 850
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 855
	return LEVELS[index + 1] -- 856
end -- 855
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 860
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 861
end -- 860
return ____exports -- 860