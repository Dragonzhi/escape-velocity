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
local SunGm = ____Scale.SunGm -- 51
local SunRadius = ____Scale.SunRadius -- 51
local circularSpeed = ____Scale.circularSpeed -- 52
local period = ____Scale.period -- 52
local trueGm = ____Scale.trueGm -- 52
local trueOrbit = ____Scale.trueOrbit -- 52
local trueRadius = ____Scale.trueRadius -- 52
local ____Tuning = require("game.Tuning") -- 54
local visualRadius = ____Tuning.visualRadius -- 54
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 849
	local out = {} -- 850
	for ____, b in ipairs(bodies) do -- 851
		out[#out + 1] = { -- 852
			gm = b.gm * gravityScale, -- 853
			radius = b.radius, -- 854
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 855
			orbitRadius = b.orbitRadius, -- 856
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 857
			phase0 = b.phase0, -- 858
			orbitDirection = b.orbitDirection, -- 859
			host = b.host ~= nil and applyScalesLocal({b.host}, gravityScale, orbitScale)[1] or nil -- 861
		} -- 861
	end -- 861
	return out -- 864
end -- 864
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
	moon = 202 -- 518
} -- 518
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
local function level1() -- 533
	local earthOrbit = ____exports.EarthOrbitRadius -- 534
	local earth = { -- 535
		gm = EarthGm, -- 536
		radius = EarthRadius, -- 537
		orbitCenter = {x = 0, y = 0}, -- 538
		orbitRadius = earthOrbit, -- 539
		orbitPeriod = period(earthOrbit, SunGm), -- 540
		phase0 = deg(90), -- 541
		orbitDirection = 1 -- 542
	} -- 542
	local moon = satellite("moon", earth, MoonOrbitRadius, PH.moon) -- 544
	local parking = (REAL.earth.radiusKm + 200) / KmPerUnit -- 547
	local earthPos = bodyPositionAt(earth, 0) -- 550
	local earthVel = ____exports.bodyVelocityAt(earth, 0) -- 551
	local vCirc = circularSpeed(EarthGm, parking) -- 552
	return { -- 553
		id = 1, -- 554
		title = "月球", -- 555
		probeVariant = "solar", -- 556
		brief = "月球任务 · 近地停泊轨 200 km：你正在绕地球飞，月球在 38 万 km 外。点火把它推向月球 —— 这一程要飞 5 天，别对着月球现在的位置点火。", -- 557
		probeStart = {x = earthPos.x, y = earthPos.y + parking}, -- 558
		probeVel0 = {x = earthVel.x - vCirc, y = earthVel.y}, -- 559
		planets = { -- 560
			sun(), -- 560
			earth, -- 560
			moon -- 560
		}, -- 560
		visuals = { -- 564
			sunVisual(0), -- 565
			planetVisual( -- 566
				"earth", -- 566
				earth, -- 566
				0.42, -- 566
				0.62, -- 566
				0.85, -- 566
				"Planet_Earth", -- 566
				false, -- 566
				0 -- 566
			), -- 566
			planetVisual( -- 567
				"moon", -- 567
				moon, -- 567
				0.56, -- 567
				0.56, -- 567
				0.6, -- 567
				"Moon", -- 567
				false, -- 567
				0 -- 567
			) -- 567
		}, -- 567
		goal = {kind = "planet", planetIndex = 2, tolerance = 0.02}, -- 570
		dvBudget = 4.6, -- 572
		escapeRadius = 400, -- 576
		maxSteps = 8000, -- 580
		planCenter = 1, -- 581
		mission = { -- 582
			id = "L1", -- 583
			codeName = "Moon", -- 584
			historicalRef = "阿波罗 / 嫦娥探月", -- 585
			subtitle = "启蒙", -- 586
			vehicle = "flyby", -- 587
			challenges = {{desc = "成功抵达月球轨道或飞掠月球", type = "success"}, {desc = "发射点火消耗 Δv ≤ 3.68（预算的 80%）", type = "fuel", threshold = 0.8}, {desc = "近月点距离 r_peri ≤ 0.003（≈ 5,600 km）", type = "distance", threshold = 0.003}} -- 588
		} -- 588
	} -- 588
end -- 533
--- L2–L6 共用的出发状态：1 AU 圆轨道上的一点，顺行（-x），速度 = 该点圆轨速度。
local function departure() -- 600
	return {pos = {x = 0, y = ____exports.EarthOrbitRadius}, vel = {x = -____exports.EarthOrbitSpeed, y = 0}} -- 601
end -- 600
--- L2 水手10号：地球 ➔ 金星 ➔ 水星（人类首次行星引力借力）。
local function level2() -- 608
	local venus = orbiter("venus", PH.venus) -- 609
	local mercury = orbiter("mercury", PH.mercury) -- 610
	local d = departure() -- 611
	return { -- 612
		id = 2, -- 613
		title = "水手10号", -- 614
		probeVariant = "solar", -- 615
		brief = "水手10号 · 1 AU 出发：人类首次行星引力辅助。向内俯冲，利用金星前向借力大幅削减轨道动能，深潜入水星轨道！", -- 616
		probeStart = d.pos, -- 617
		probeVel0 = d.vel, -- 618
		planets = { -- 619
			sun(), -- 619
			venus, -- 619
			mercury -- 619
		}, -- 619
		visuals = { -- 620
			sunVisual(), -- 621
			planetVisual( -- 622
				"venus", -- 622
				venus, -- 622
				0.9, -- 622
				0.78, -- 622
				0.55, -- 622
				"Planet_Venus", -- 622
				false -- 622
			), -- 622
			planetVisual( -- 623
				"mercury", -- 623
				mercury, -- 623
				0.65, -- 623
				0.65, -- 623
				0.65, -- 623
				"Sphere", -- 623
				false -- 623
			) -- 623
		}, -- 623
		goal = {kind = "planet", planetIndex = 2, tolerance = 6, chain = {{planetIndex = 1, tolerance = 15, label = "金星"}, {planetIndex = 2, tolerance = 6, label = "水星"}}}, -- 625
		dvBudget = 4, -- 634
		escapeRadius = 3600, -- 635
		maxSteps = 4000, -- 636
		timeWindow = {span = 27}, -- 637
		mission = { -- 638
			id = "L2", -- 639
			codeName = "Mariner 10", -- 640
			historicalRef = "水手10号 (1973)", -- 641
			subtitle = "潜行", -- 642
			vehicle = "flyby", -- 643
			challenges = {{desc = "借力金星并成功抵达水星", type = "success"}, {desc = "初始点火消耗 Δv ≤ 75% 预算", type = "fuel", threshold = 0.75}, {desc = "金星交会时相对速度降幅 ≥ 12 单位", type = "speed", threshold = 12}} -- 644
		} -- 644
	} -- 644
end -- 608
--- L3 帕克号：地球 ➔ 金星 ➔ 太阳日冕区（触碰太阳极热地狱）。
local function level3() -- 654
	local venus = orbiter("venus", PH.venus) -- 655
	local d = departure() -- 656
	return { -- 657
		id = 3, -- 658
		title = "帕克号", -- 659
		probeVariant = "solar", -- 660
		brief = "帕克号 · 1 AU 出发：人类制造的最狂暴“触日者”。利用金星大幅削减日心角动量，近距离俯冲入太阳日冕危险带且未撞毁！", -- 661
		probeStart = d.pos, -- 662
		probeVel0 = d.vel, -- 663
		planets = { -- 664
			sun(), -- 664
			venus -- 664
		}, -- 664
		visuals = { -- 665
			sunVisual(), -- 666
			planetVisual( -- 667
				"venus", -- 667
				venus, -- 667
				0.9, -- 667
				0.78, -- 667
				0.55, -- 667
				"Planet_Venus", -- 667
				false -- 667
			) -- 667
		}, -- 667
		goal = {kind = "planet", planetIndex = 0, tolerance = 15}, -- 669
		dvBudget = 6, -- 674
		escapeRadius = 3600, -- 675
		maxSteps = 6000, -- 676
		timeWindow = {span = 27}, -- 677
		mission = { -- 678
			id = "L3", -- 679
			codeName = "Parker", -- 680
			historicalRef = "帕克太阳探测器 (2018)", -- 681
			subtitle = "烈日", -- 682
			vehicle = "flyby", -- 683
			challenges = {{desc = "近日点深入太阳日冕观测带 (r_peri ≤ 15) 且未撞毁", type = "success"}, {desc = "初始点火消耗 Δv ≤ 80% 预算", type = "fuel", threshold = 0.8}, {desc = "近日点最高日心速度突破 vmax ≥ 60 单位", type = "speed", threshold = 60}} -- 684
		} -- 684
	} -- 684
end -- 654
--- L4 伽利略号：地球 ➔ 木星泊入（轨道器模式正式登场）。
local function level4() -- 694
	local jupiter = orbiter("jupiter", PH.jupiter4) -- 695
	local d = departure() -- 696
	return { -- 697
		id = 4, -- 698
		title = "伽利略号", -- 699
		probeVariant = "rtg", -- 700
		brief = "伽利略号 · 1 AU 出发：人类第一艘长期驻留环绕木星的轨道器。抵达木星巨型引力井，在慢动作特写中捕捉制动窗口，按下 [ BRAKE ] 优雅泊入闭合环绕轨！", -- 701
		probeStart = d.pos, -- 702
		probeVel0 = d.vel, -- 703
		planets = { -- 704
			sun(), -- 704
			jupiter -- 704
		}, -- 704
		visuals = { -- 705
			sunVisual(), -- 706
			planetVisual( -- 707
				"jupiter", -- 707
				jupiter, -- 707
				0.85, -- 707
				0.72, -- 707
				0.5, -- 707
				"Planet_Jupiter", -- 707
				false -- 707
			) -- 707
		}, -- 707
		goal = {kind = "planet", planetIndex = 1, tolerance = 40, chain = {{planetIndex = 1, tolerance = 40, label = "木星", capture = true}}}, -- 709
		dvBudget = 14, -- 717
		escapeRadius = 3600, -- 718
		maxSteps = 25000, -- 719
		timeWindow = {span = 18}, -- 720
		mission = { -- 721
			id = "L4", -- 722
			codeName = "Galileo", -- 723
			historicalRef = "伽利略号 (1989)", -- 724
			subtitle = "泊入", -- 725
			vehicle = "orbiter", -- 726
			challenges = {{desc = "在制动窗口内成功按下刹车闭合入轨", type = "success"}, {desc = "地面发射点火 Δv ≤ 70% 预算", type = "fuel", threshold = 0.7}, {desc = "入轨偏心率 e ≤ 0.25", type = "eccentricity", threshold = 0.25}} -- 727
		} -- 727
	} -- 727
end -- 694
--- L5 新视野号：地球 ➔ 木星狂暴加速 ➔ 柯伊伯带深空。
local function level5() -- 737
	local jupiter = orbiter("jupiter", PH.jupiter5) -- 738
	local d = departure() -- 739
	return { -- 740
		id = 5, -- 741
		title = "新视野号", -- 742
		probeVariant = "rtg", -- 743
		brief = "新视野号 · 1 AU 出发：人类有史以来最狂暴的深空信使。寻找木星后向加速最佳切角，利用太阳系最强引力弹弓把探测器甩向柯伊伯带深空外边界！", -- 744
		probeStart = d.pos, -- 745
		probeVel0 = d.vel, -- 746
		planets = { -- 747
			sun(), -- 747
			jupiter -- 747
		}, -- 747
		visuals = { -- 748
			sunVisual(), -- 749
			planetVisual( -- 750
				"jupiter", -- 750
				jupiter, -- 750
				0.85, -- 750
				0.72, -- 750
				0.5, -- 750
				"Planet_Jupiter", -- 750
				false -- 750
			) -- 750
		}, -- 750
		goal = {kind = "escape", planetIndex = 1, tolerance = 40, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}}}, -- 752
		dvBudget = 15, -- 760
		escapeRadius = 3600, -- 761
		maxSteps = 35000, -- 762
		timeWindow = {span = 17.5}, -- 763
		mission = { -- 764
			id = "L5", -- 765
			codeName = "New Horizons", -- 766
			historicalRef = "新视野号 (2006)", -- 767
			subtitle = "狂飙", -- 768
			vehicle = "flyby", -- 769
			challenges = {{desc = "借力木星获得逃逸能量抵达外边界", type = "success"}, {desc = "地面发射初速消耗 Δv ≤ 75% 预算", type = "fuel", threshold = 0.75}, {desc = "速度增幅 ≥ 15 且逃逸末速度 vend ≥ 40", type = "speed", threshold = 40}} -- 770
		} -- 770
	} -- 770
end -- 737
--- L6 旅行者2号：地球 ➔ 木星 ➔ 土星 ➔ 天王星 ➔ 海王星 ➔ 星际空间。
local function level6() -- 780
	local jupiter = orbiter("jupiter", PH.jupiter6) -- 781
	local saturn = orbiter("saturn", PH.saturn6) -- 782
	local uranus = orbiter("uranus", PH.uranus6) -- 783
	local neptune = orbiter("neptune", PH.neptune6) -- 784
	local d = departure() -- 785
	return { -- 786
		id = 6, -- 787
		title = "旅行者2号", -- 788
		probeVariant = "rtg", -- 789
		brief = "旅行者2号 · 1 AU 出发：175 年一遇的行星连珠奇迹！对准发射窗口，连续四星接力借力飞出海王星轨道，冲入星际空间，触发暗淡蓝点终章！", -- 790
		probeStart = d.pos, -- 791
		probeVel0 = d.vel, -- 792
		planets = { -- 793
			sun(), -- 793
			jupiter, -- 793
			saturn, -- 793
			uranus, -- 793
			neptune -- 793
		}, -- 793
		visuals = { -- 794
			sunVisual(), -- 795
			planetVisual( -- 796
				"jupiter", -- 796
				jupiter, -- 796
				0.85, -- 796
				0.72, -- 796
				0.5, -- 796
				"Planet_Jupiter", -- 796
				false -- 796
			), -- 796
			planetVisual( -- 797
				"saturn", -- 797
				saturn, -- 797
				0.75, -- 797
				0.7, -- 797
				0.6, -- 797
				"Planet_Saturn", -- 797
				true -- 797
			), -- 797
			planetVisual( -- 798
				"uranus", -- 798
				uranus, -- 798
				0.62, -- 798
				0.82, -- 798
				0.86, -- 798
				"Planet_Uranus", -- 798
				false -- 798
			), -- 798
			planetVisual( -- 799
				"neptune", -- 799
				neptune, -- 799
				0.34, -- 799
				0.5, -- 799
				0.86, -- 799
				"Planet_Neptune", -- 799
				false -- 799
			) -- 799
		}, -- 799
		goal = {kind = "planet", planetIndex = 4, tolerance = 120, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 60, label = "土星"}, {planetIndex = 3, tolerance = 90, label = "天王星"}, {planetIndex = 4, tolerance = 120, label = "海王星"}}}, -- 801
		dvBudget = 16, -- 812
		escapeRadius = 3600, -- 813
		maxSteps = 70000, -- 814
		timeWindow = {span = 17.5}, -- 815
		mission = { -- 816
			id = "L6", -- 817
			codeName = "Voyager 2", -- 818
			historicalRef = "旅行者2号 (1977)", -- 819
			subtitle = "奇迹", -- 820
			vehicle = "flyby", -- 821
			challenges = {{desc = "成功四星连续借力并飞出海王星轨道", type = "success"}, {desc = "初始发射点火 Δv ≤ 80% 预算", type = "fuel", threshold = 0.8}, {desc = "四星交会无碰撞且近心点精度 ≤ 5%", type = "distance", threshold = 0.05}} -- 822
		} -- 822
	} -- 822
end -- 780
local LEVELS = { -- 831
	level1(), -- 831
	level2(), -- 831
	level3(), -- 831
	level4(), -- 831
	level5(), -- 831
	level6() -- 831
} -- 831
--- 关卡总数。
function ____exports.levelCount() -- 834
	return #LEVELS -- 835
end -- 834
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 839
	return LEVELS[index + 1] -- 840
end -- 839
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 844
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 845
end -- 844
return ____exports -- 844