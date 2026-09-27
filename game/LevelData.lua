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
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 768
	local out = {} -- 769
	for ____, b in ipairs(bodies) do -- 770
		out[#out + 1] = { -- 771
			gm = b.gm * gravityScale, -- 772
			radius = b.radius, -- 773
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 774
			orbitRadius = b.orbitRadius, -- 775
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 776
			phase0 = b.phase0, -- 777
			orbitDirection = b.orbitDirection, -- 778
			host = b.host ~= nil and applyScalesLocal({b.host}, gravityScale, orbitScale)[1] or nil -- 780
		} -- 780
	end -- 780
	return out -- 783
end -- 783
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
	venus = 79.6, -- 436
	jupiter3 = 186.1, -- 441
	jupiter4 = 184.4, -- 442
	jupiter5 = 175.6, -- 443
	jupiter6 = 175.2, -- 444
	saturn4 = 199.6, -- 446
	saturn5 = 190.8, -- 447
	saturn6 = 190.3, -- 448
	uranus5 = 202.8, -- 450
	uranus6 = 201.8, -- 451
	neptune6 = 207.6, -- 453
	moon = 154.7 -- 461
} -- 461
--- L1：地月系。
-- 
-- - 地球是**真天体**：真 gm、真半径，自己在绕日公转（这是"物理统一"的试纸）；
-- - 月球绕地球，周期由开普勒第三定律算出 = 1.2593 秒（真实值）；
-- - 探测器在**绕地圆轨道**上，半径 0.1 单位（= 18.7 万 km = 月球距离的 49%）：
--   初始速度 = 地球的公转速度 + 绕地圆轨速度（顺行），所以预测线一上来就是一条弧线；
-- - 点火目标：抬升到月球轨道 0.2056 做霍曼转移，半程 0.4034 秒。
local function level1() -- 473
	local earthOrbit = ____exports.EarthOrbitRadius -- 474
	local earth = { -- 475
		gm = EarthGm, -- 476
		radius = EarthRadius, -- 477
		orbitCenter = {x = 0, y = 0}, -- 478
		orbitRadius = earthOrbit, -- 479
		orbitPeriod = period(earthOrbit, SunGm), -- 480
		phase0 = deg(90), -- 481
		orbitDirection = 1 -- 482
	} -- 482
	local moon = satellite("moon", earth, MoonOrbitRadius, PH.moon) -- 484
	local parking = 0.1 -- 485
	local earthPos = bodyPositionAt(earth, 0) -- 488
	local earthVel = ____exports.bodyVelocityAt(earth, 0) -- 489
	local vCirc = circularSpeed(EarthGm, parking) -- 490
	return { -- 491
		id = 1, -- 492
		title = "月球", -- 493
		probeVariant = "solar", -- 494
		brief = "月球任务 · 地球轨道：你已经在绕地球飞了 —— 月球也在走。别对着它现在的位置点火，要打提前量。", -- 495
		probeStart = {x = earthPos.x, y = earthPos.y + parking}, -- 496
		probeVel0 = {x = earthVel.x - vCirc, y = earthVel.y}, -- 497
		planets = { -- 498
			sun(), -- 498
			earth, -- 498
			moon -- 498
		}, -- 498
		visuals = { -- 502
			sunVisual(0), -- 503
			planetVisual( -- 504
				"earth", -- 504
				earth, -- 504
				0.42, -- 504
				0.62, -- 504
				0.85, -- 504
				"Planet_Earth", -- 504
				false, -- 504
				0 -- 504
			), -- 504
			planetVisual( -- 505
				"moon", -- 505
				moon, -- 505
				0.56, -- 505
				0.56, -- 505
				0.6, -- 505
				"Moon", -- 505
				false, -- 505
				0 -- 505
			) -- 505
		}, -- 505
		goal = {kind = "planet", planetIndex = 2, tolerance = 0.02}, -- 508
		dvBudget = 0.35, -- 509
		escapeRadius = 400, -- 513
		maxSteps = 2400, -- 516
		planCenter = 1, -- 517
		mission = { -- 518
			id = "L1", -- 519
			codeName = "Moon", -- 520
			historicalRef = "阿波罗 / 嫦娥探月", -- 521
			subtitle = "启蒙", -- 522
			vehicle = "flyby", -- 523
			challenges = {{desc = "成功抵达月球轨道或飞掠月球", type = "success"}, {desc = "发射点火消耗 Δv ≤ 0.28（节省 > 20%）", type = "fuel", threshold = 0.8}, {desc = "近月点距离 r_peri ≤ 0.015", type = "distance", threshold = 0.015}} -- 524
		} -- 524
	} -- 524
end -- 473
--- L2–L6 共用的出发状态：1 AU 圆轨道上的一点，顺行（-x），速度 = 该点圆轨速度。
local function departure() -- 536
	return {pos = {x = 0, y = ____exports.EarthOrbitRadius}, vel = {x = -____exports.EarthOrbitSpeed, y = 0}} -- 537
end -- 536
--- L2 金星：唯一一次**向内**飞（太阳一路加速你，难点是"收"）。
local function level2() -- 544
	local venus = orbiter("venus", PH.venus) -- 545
	local d = departure() -- 546
	return { -- 547
		id = 2, -- 548
		title = "金星", -- 549
		probeVariant = "solar", -- 550
		brief = "金星任务 · 1 AU 出发：向内飞，太阳会一路把你拽快。金星在 0.72 AU 的内圈上等着 —— 挑对它经过你航线的那一天。", -- 551
		probeStart = d.pos, -- 552
		probeVel0 = d.vel, -- 553
		planets = { -- 554
			sun(), -- 554
			venus -- 554
		}, -- 554
		visuals = { -- 555
			sunVisual(), -- 555
			planetVisual( -- 555
				"venus", -- 555
				venus, -- 555
				0.9, -- 555
				0.78, -- 555
				0.55, -- 555
				"Planet_Venus", -- 555
				false -- 555
			) -- 555
		}, -- 555
		goal = {kind = "planet", planetIndex = 1, tolerance = 3}, -- 556
		dvBudget = 4, -- 557
		escapeRadius = 3600, -- 558
		maxSteps = 4000, -- 559
		timeWindow = {span = 27}, -- 560
		mission = { -- 561
			id = "L2", -- 562
			codeName = "Mariner10", -- 563
			historicalRef = "水手10号 (Mariner 10)", -- 564
			subtitle = "潜行", -- 565
			vehicle = "flyby", -- 566
			challenges = {{desc = "借力金星并成功抵达金星轨道", type = "success"}, {desc = "初始点火消耗 Δv ≤ 75% 预算", type = "fuel", threshold = 0.75}, {desc = "近星距离 ≤ 2.0 单位", type = "distance", threshold = 2}} -- 567
		} -- 567
	} -- 567
end -- 544
--- L3 木星：第一次真正的行星际飞行，也是本作的"核心瞬间"（被木星掰弯）。
local function level3() -- 577
	local jupiter = orbiter("jupiter", PH.jupiter3) -- 578
	local d = departure() -- 579
	return { -- 580
		id = 3, -- 581
		title = "木星", -- 582
		probeVariant = "solar", -- 583
		brief = "木星任务 · 1 AU 出发：5.2 AU 之外，真正的行星际飞行。出发角度要压在木星到达航线的那一天上。", -- 584
		probeStart = d.pos, -- 585
		probeVel0 = d.vel, -- 586
		planets = { -- 587
			sun(), -- 587
			jupiter -- 587
		}, -- 587
		visuals = { -- 588
			sunVisual(), -- 588
			planetVisual( -- 588
				"jupiter", -- 588
				jupiter, -- 588
				0.85, -- 588
				0.72, -- 588
				0.5, -- 588
				"Planet_Jupiter", -- 588
				false -- 588
			) -- 588
		}, -- 588
		goal = {kind = "planet", planetIndex = 1, tolerance = 25}, -- 589
		dvBudget = 12, -- 590
		escapeRadius = 3600, -- 591
		maxSteps = 20000, -- 592
		timeWindow = {span = 19}, -- 593
		mission = { -- 594
			id = "L3", -- 595
			codeName = "Parker", -- 596
			historicalRef = "帕克太阳探测器 (Parker Solar Probe)", -- 597
			subtitle = "烈日", -- 598
			vehicle = "flyby", -- 599
			challenges = {{desc = "成功抵达木星引力范围", type = "success"}, {desc = "初始点火消耗 Δv ≤ 80% 预算", type = "fuel", threshold = 0.8}, {desc = "航行最高速度 vmax ≥ 40", type = "speed", threshold = 40}} -- 600
		} -- 600
	} -- 600
end -- 577
--- L4 土星：先掠过木星，再被土星接住（一次点火，两个环都要穿对）。
local function level4() -- 610
	local jupiter = orbiter("jupiter", PH.jupiter4) -- 611
	local saturn = orbiter("saturn", PH.saturn4) -- 612
	local d = departure() -- 613
	return { -- 614
		id = 4, -- 615
		title = "土星", -- 616
		probeVariant = "rtg", -- 617
		brief = "土星任务 · 1 AU 出发：9.5 AU，先穿过木星轨道，再到土星。一次点火，两个环都要穿对。", -- 618
		probeStart = d.pos, -- 619
		probeVel0 = d.vel, -- 620
		planets = { -- 621
			sun(), -- 621
			jupiter, -- 621
			saturn -- 621
		}, -- 621
		visuals = { -- 622
			sunVisual(), -- 623
			planetVisual( -- 624
				"jupiter", -- 624
				jupiter, -- 624
				0.85, -- 624
				0.72, -- 624
				0.5, -- 624
				"Planet_Jupiter", -- 624
				false -- 624
			), -- 624
			planetVisual( -- 625
				"saturn", -- 625
				saturn, -- 625
				0.75, -- 625
				0.7, -- 625
				0.6, -- 625
				"Planet_Saturn", -- 625
				true -- 625
			) -- 625
		}, -- 625
		goal = {kind = "planet", planetIndex = 2, tolerance = 45, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 45, label = "土星"}}}, -- 627
		dvBudget = 14, -- 634
		escapeRadius = 3600, -- 635
		maxSteps = 30000, -- 636
		timeWindow = {span = 18}, -- 637
		mission = { -- 638
			id = "L4", -- 639
			codeName = "Galileo", -- 640
			historicalRef = "伽利略号 (Galileo)", -- 641
			subtitle = "泊入", -- 642
			vehicle = "orbiter", -- 643
			challenges = {{desc = "连续飞掠木星并抵达土星", type = "success"}, {desc = "地面发射点火 Δv ≤ 70% 预算", type = "fuel", threshold = 0.7}, {desc = "闭合轨道偏心率 e ≤ 0.35", type = "eccentricity", threshold = 0.35}} -- 644
		} -- 644
	} -- 644
end -- 610
--- L5 天王星：木星、土星两次借力，越飞越远。
local function level5() -- 654
	local jupiter = orbiter("jupiter", PH.jupiter5) -- 655
	local saturn = orbiter("saturn", PH.saturn5) -- 656
	local uranus = orbiter("uranus", PH.uranus5) -- 657
	local d = departure() -- 658
	return { -- 659
		id = 5, -- 660
		title = "天王星", -- 661
		probeVariant = "rtg", -- 662
		brief = "天王星任务 · 1 AU 出发：19 AU。木星、土星，一路向外 —— 一次点火要串起三个节点。", -- 663
		probeStart = d.pos, -- 664
		probeVel0 = d.vel, -- 665
		planets = { -- 666
			sun(), -- 666
			jupiter, -- 666
			saturn, -- 666
			uranus -- 666
		}, -- 666
		visuals = { -- 667
			sunVisual(), -- 668
			planetVisual( -- 669
				"jupiter", -- 669
				jupiter, -- 669
				0.85, -- 669
				0.72, -- 669
				0.5, -- 669
				"Planet_Jupiter", -- 669
				false -- 669
			), -- 669
			planetVisual( -- 670
				"saturn", -- 670
				saturn, -- 670
				0.75, -- 670
				0.7, -- 670
				0.6, -- 670
				"Planet_Saturn", -- 670
				true -- 670
			), -- 670
			planetVisual( -- 671
				"uranus", -- 671
				uranus, -- 671
				0.62, -- 671
				0.82, -- 671
				0.86, -- 671
				"Planet_Uranus", -- 671
				false -- 671
			) -- 671
		}, -- 671
		goal = {kind = "planet", planetIndex = 3, tolerance = 70, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 55, label = "土星"}, {planetIndex = 3, tolerance = 70, label = "天王星"}}}, -- 673
		dvBudget = 15, -- 681
		escapeRadius = 3600, -- 682
		maxSteps = 40000, -- 683
		timeWindow = {span = 17.5}, -- 684
		mission = { -- 685
			id = "L5", -- 686
			codeName = "NewHorizons", -- 687
			historicalRef = "新视野号 (New Horizons)", -- 688
			subtitle = "狂飙", -- 689
			vehicle = "flyby", -- 690
			challenges = {{desc = "借力木星与土星抵达天王星", type = "success"}, {desc = "地面发射初速消耗 Δv ≤ 75% 预算", type = "fuel", threshold = 0.75}, {desc = "航行最高速度 vmax ≥ 45", type = "speed", threshold = 45}} -- 691
		} -- 691
	} -- 691
end -- 654
--- L6 海王星：四颗巨行星连成一条线的那一天，一次点火串到底。
local function level6() -- 701
	local jupiter = orbiter("jupiter", PH.jupiter6) -- 702
	local saturn = orbiter("saturn", PH.saturn6) -- 703
	local uranus = orbiter("uranus", PH.uranus6) -- 704
	local neptune = orbiter("neptune", PH.neptune6) -- 705
	local d = departure() -- 706
	return { -- 707
		id = 6, -- 708
		title = "海王星", -- 709
		probeVariant = "rtg", -- 710
		brief = "海王星任务 · 1 AU 出发：30 AU。四颗巨行星排到一条线上的那一天 —— 一次点火串到底。", -- 711
		probeStart = d.pos, -- 712
		probeVel0 = d.vel, -- 713
		planets = { -- 714
			sun(), -- 714
			jupiter, -- 714
			saturn, -- 714
			uranus, -- 714
			neptune -- 714
		}, -- 714
		visuals = { -- 715
			sunVisual(), -- 716
			planetVisual( -- 717
				"jupiter", -- 717
				jupiter, -- 717
				0.85, -- 717
				0.72, -- 717
				0.5, -- 717
				"Planet_Jupiter", -- 717
				false -- 717
			), -- 717
			planetVisual( -- 718
				"saturn", -- 718
				saturn, -- 718
				0.75, -- 718
				0.7, -- 718
				0.6, -- 718
				"Planet_Saturn", -- 718
				true -- 718
			), -- 718
			planetVisual( -- 719
				"uranus", -- 719
				uranus, -- 719
				0.62, -- 719
				0.82, -- 719
				0.86, -- 719
				"Planet_Uranus", -- 719
				false -- 719
			), -- 719
			planetVisual( -- 720
				"neptune", -- 720
				neptune, -- 720
				0.34, -- 720
				0.5, -- 720
				0.86, -- 720
				"Planet_Neptune", -- 720
				false -- 720
			) -- 720
		}, -- 720
		goal = {kind = "planet", planetIndex = 4, tolerance = 120, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 60, label = "土星"}, {planetIndex = 3, tolerance = 90, label = "天王星"}, {planetIndex = 4, tolerance = 120, label = "海王星"}}}, -- 722
		dvBudget = 16, -- 731
		escapeRadius = 3600, -- 732
		maxSteps = 70000, -- 733
		timeWindow = {span = 17.5}, -- 734
		mission = { -- 735
			id = "L6", -- 736
			codeName = "Voyager2", -- 737
			historicalRef = "旅行者2号 (Voyager 2)", -- 738
			subtitle = "奇迹", -- 739
			vehicle = "flyby", -- 740
			challenges = {{desc = "四星连珠大巡游抵达海王星", type = "success"}, {desc = "初始发射点火 Δv ≤ 80% 预算", type = "fuel", threshold = 0.8}, {desc = "航行最高速度 vmax ≥ 50", type = "speed", threshold = 50}} -- 741
		} -- 741
	} -- 741
end -- 701
local LEVELS = { -- 750
	level1(), -- 750
	level2(), -- 750
	level3(), -- 750
	level4(), -- 750
	level5(), -- 750
	level6() -- 750
} -- 750
--- 关卡总数。
function ____exports.levelCount() -- 753
	return #LEVELS -- 754
end -- 753
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 758
	return LEVELS[index + 1] -- 759
end -- 758
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 763
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 764
end -- 763
return ____exports -- 763