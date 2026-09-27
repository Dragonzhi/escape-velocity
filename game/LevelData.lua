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
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 615
	local out = {} -- 616
	for ____, b in ipairs(bodies) do -- 617
		out[#out + 1] = { -- 618
			gm = b.gm * gravityScale, -- 619
			radius = b.radius, -- 620
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 621
			orbitRadius = b.orbitRadius, -- 622
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 623
			phase0 = b.phase0, -- 624
			orbitDirection = b.orbitDirection, -- 625
			host = b.host ~= nil and applyScalesLocal({b.host}, gravityScale, orbitScale)[1] or nil -- 627
		} -- 627
	end -- 627
	return out -- 630
end -- 630
--- 导出名与旧版一致（外部调用方按这个名字找）。
function ____exports.bodyVelocityAt(b, t) -- 168
	if b.orbitPeriod == 0 or b.orbitRadius <= 0 then -- 168
		return {x = 0, y = 0} -- 169
	end -- 169
	local angle = b.phase0 + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 170
	local w = b.orbitDirection * 2 * math.pi / b.orbitPeriod -- 171
	return { -- 172
		x = -math.sin(angle) * b.orbitRadius * w, -- 172
		y = math.cos(angle) * b.orbitRadius * w -- 172
	} -- 172
end -- 168
--- 航点列表（链式目标取 chain，否则就是唯一目标）。
function ____exports.goalWaypoints(goal) -- 176
	if goal.chain ~= nil then -- 176
		return goal.chain -- 177
	end -- 177
	if goal.kind == "planet" then -- 177
		return {{planetIndex = goal.planetIndex, tolerance = goal.tolerance}} -- 178
	end -- 178
	return {} -- 179
end -- 176
--- 采样点 i 处、相对某天体的速度（捕获判据与诊断共用同一份实现）。
-- 
-- points 里只有位置 ⇒ 用相邻采样点差分；`dt` 是**相邻采样点之间的有效步长**。
-- `limit` 是最后一个有效采样点索引（末端夹紧用）。
function ____exports.relativeSpeedAt(points, i, body, dt, t0, limit, velocities) -- 188
	local vx = 0 -- 189
	local vy = 0 -- 190
	if velocities ~= nil and velocities[i + 1] ~= nil then -- 190
		vx = velocities[i + 1].x -- 193
		vy = velocities[i + 1].y -- 194
	else -- 194
		local j1 = i + 1 <= limit and i + 1 or i -- 198
		local j0 = i > 0 and i - 1 or i -- 199
		local spanT = (j1 - j0) * dt -- 200
		if spanT > 0 then -- 200
			vx = (points[j1 + 1].x - points[j0 + 1].x) / spanT -- 202
			vy = (points[j1 + 1].y - points[j0 + 1].y) / spanT -- 203
		end -- 203
	end -- 203
	local pv = ____exports.bodyVelocityAt(body, t0) -- 206
	local rx = vx - pv.x -- 207
	local ry = vy - pv.y -- 208
	return math.sqrt(rx * rx + ry * ry) -- 209
end -- 188
--- 捕获阈值：该处逃逸速度（圆轨道速度 × 系数 k，k 默认 √2）。
function ____exports.captureThreshold(body, d, k) -- 213
	if body.gm <= 0 or d <= 0.000001 then -- 213
		return 1000000000 -- 214
	end -- 214
	return k * math.sqrt(body.gm / d) -- 215
end -- 213
--- 顺序航线的进度：返回在 points[0..upto] 里**依次**掠过的航点数与最后一个命中索引。
-- 
-- 一次线性扫描：航点必须按顺序命中，且后一个必须出现在更晚的采样点上
-- （"先到土星再路过木星"不算数）。upto 用于飞行中查询"到哪一段了"（画环的明暗）。
function ____exports.waypointProgress(points, bodies, goal, dt, t0, upto, velocities) -- 224
	local wps = ____exports.goalWaypoints(goal) -- 233
	local start = t0 ~= nil and t0 or 0 -- 234
	local limit = #points - 1 -- 235
	if upto ~= nil and upto >= 0 and upto < limit then -- 235
		limit = upto -- 236
	end -- 236
	local next = 0 -- 237
	local lastIndex = -1 -- 238
	do -- 238
		local i = 0 -- 239
		while i <= limit and next < #wps do -- 239
			do -- 239
				local w = wps[next + 1] -- 240
				local body = bodies[w.planetIndex + 1] -- 241
				if body == nil then -- 241
					return {passed = 0, lastIndex = -1} -- 242
				end -- 242
				local gp = bodyPositionAt(body, start + i * dt) -- 243
				if distance(points[i + 1], gp) < w.tolerance then -- 243
					if w.capture == true then -- 243
						local k = w.captureFactor ~= nil and w.captureFactor or 1.4142135623730951 -- 248
						local d = distance(points[i + 1], gp) -- 249
						if d <= body.radius then -- 249
							goto __continue16 -- 252
						end -- 252
						local rel = ____exports.relativeSpeedAt( -- 253
							points, -- 253
							i, -- 253
							body, -- 253
							dt, -- 253
							start + i * dt, -- 253
							limit, -- 253
							velocities -- 253
						) -- 253
						if rel > ____exports.captureThreshold(body, d, k) then -- 253
							goto __continue16 -- 254
						end -- 254
					end -- 254
					next = next + 1 -- 256
					lastIndex = i -- 257
				end -- 257
			end -- 257
			::__continue16:: -- 257
			i = i + 1 -- 239
		end -- 239
	end -- 239
	return {passed = next, lastIndex = lastIndex} -- 260
end -- 224
--- 到达目标的采样点索引；没到返回 -1。
function ____exports.findGoalIndex(points, bodies, goal, dt, t0, velocities) -- 264
	local wps = ____exports.goalWaypoints(goal) -- 265
	if #wps == 0 then -- 265
		return -1 -- 266
	end -- 266
	local st = ____exports.waypointProgress( -- 267
		points, -- 267
		bodies, -- 267
		goal, -- 267
		dt, -- 267
		t0, -- 267
		nil, -- 267
		velocities -- 267
	) -- 267
	return st.passed >= #wps and st.lastIndex or -1 -- 268
end -- 264
--- 度 → 弧度（关卡数据里写角度比写弧度好读）。
local function deg(d) -- 276
	return d * math.pi / 180 -- 277
end -- 276
--- 太阳（每关的第 0 号天体）。
local function sun() -- 281
	return { -- 282
		gm = SunGm, -- 282
		radius = SunRadius, -- 282
		orbitCenter = {x = 0, y = 0}, -- 282
		orbitRadius = 0, -- 282
		orbitPeriod = 0, -- 282
		phase0 = 0, -- 282
		orbitDirection = 1 -- 282
	} -- 282
end -- 281
--- 绕太阳公转的行星：`key` 是 Scale.REAL 里的键。
-- 
-- 真半径 0.0034（地球）到 0.0374（木星），**不再有任何放大** —— 用户要求"天体大小改为符合物理的大小"。
-- 看得见的那一层在 Tuning.BODY_VISUAL_RADIUS。
local function orbiter(key, phaseDeg) -- 291
	local real = REAL[key] -- 292
	local a = trueOrbit(real.au) -- 293
	return { -- 294
		gm = trueGm(real.gm), -- 295
		radius = trueRadius(real.radiusKm), -- 296
		orbitCenter = {x = 0, y = 0}, -- 297
		orbitRadius = a, -- 298
		orbitPeriod = period(a, SunGm), -- 299
		phase0 = deg(phaseDeg), -- 300
		orbitDirection = 1 -- 301
	} -- 301
end -- 291
--- 绕**会动的宿主**公转的卫星（L1 的月球）。
-- 
-- 周期用开普勒第三定律 `2π·sqrt(a³/μ)` 算，**μ 取宿主（地球）的 gm** ——
-- 这是最容易搞错的一步：拿月球自己的 gm 去算会得到 11.35 秒（正确值 1.2593 秒）。
local function satellite(key, host, orbitRadius, phaseDeg) -- 311
	local real = REAL[key] -- 312
	return { -- 313
		gm = trueGm(real.gm), -- 314
		radius = trueRadius(real.radiusKm), -- 315
		orbitCenter = {x = 0, y = 0}, -- 316
		orbitRadius = orbitRadius, -- 317
		orbitPeriod = period(orbitRadius, host.gm), -- 318
		phase0 = deg(phaseDeg), -- 319
		orbitDirection = 1, -- 320
		host = host -- 321
	} -- 321
end -- 311
--- 视觉：`key` 只用来查 Tuning 里的视觉半径，`body.radius` 是查不到时的兜底。
local function planetVisual(key, body, r, g, b, model, ring) -- 326
	return { -- 327
		r = r, -- 327
		g = g, -- 327
		b = b, -- 327
		displayRadius = visualRadius(key, body.radius), -- 327
		ring = ring, -- 327
		model = model -- 327
	} -- 327
end -- 326
--- 太阳的视觉（自发光 + 光晕）。
local function sunVisual() -- 331
	return { -- 333
		r = 1, -- 333
		g = 0.97, -- 333
		b = 0.88, -- 333
		displayRadius = visualRadius("sun", SunRadius), -- 333
		ring = false, -- 333
		model = "Sun", -- 333
		emissive = {r = 1, g = 0.95, b = 0.82} -- 333
	} -- 333
end -- 331
--- 出发轨道半径 = 1 AU（地球轨道）。六关共用 —— L1 的地球就在这里，L2–L6 从这里出发。
____exports.EarthOrbitRadius = trueOrbit(REAL.earth.au) -- 343
--- 该点的日心圆轨速度（30.00 平面单位/秒 —— 全套尺度的速度锚点）。
____exports.EarthOrbitSpeed = circularSpeed(SunGm, ____exports.EarthOrbitRadius) -- 346
--- 相位表 —— **全部由 `node tools/level-phases.mjs <关号> --dirs 240 --dvs 31 --tmax N` 解出**，不许手填。
-- 
-- ⚠️ 同一颗行星在**不同关的相位不同**，这是对的：相位代表"哪一天的太阳系"，
--    每一关的可行发射窗口本来就不一样。物理量（gm / 半径 / 轨道 / 周期）才是六关共用、不许变的。
-- 
-- 每一行后面的注释就是它的出处（工具输出），改数值必须重跑工具。
local PH = { -- 356
	venus = 79.6, -- 358
	jupiter3 = 186.1, -- 363
	jupiter4 = 184.4, -- 364
	jupiter5 = 175.6, -- 365
	jupiter6 = 175.2, -- 366
	saturn4 = 199.6, -- 368
	saturn5 = 190.8, -- 369
	saturn6 = 190.3, -- 370
	uranus5 = 202.8, -- 372
	uranus6 = 201.8, -- 373
	neptune6 = 207.6, -- 375
	moon = 154.7 -- 383
} -- 383
--- L1：地月系。
-- 
-- - 地球是**真天体**：真 gm、真半径，自己在绕日公转（这是"物理统一"的试纸）；
-- - 月球绕地球，周期由开普勒第三定律算出 = 1.2593 秒（真实值）；
-- - 探测器在**绕地圆轨道**上，半径 0.1 单位（= 18.7 万 km = 月球距离的 49%）：
--   初始速度 = 地球的公转速度 + 绕地圆轨速度（顺行），所以预测线一上来就是一条弧线；
-- - 点火目标：抬升到月球轨道 0.2056 做霍曼转移，半程 0.4034 秒。
local function level1() -- 395
	local earthOrbit = ____exports.EarthOrbitRadius -- 396
	local earth = { -- 397
		gm = EarthGm, -- 398
		radius = EarthRadius, -- 399
		orbitCenter = {x = 0, y = 0}, -- 400
		orbitRadius = earthOrbit, -- 401
		orbitPeriod = period(earthOrbit, SunGm), -- 402
		phase0 = deg(90), -- 403
		orbitDirection = 1 -- 404
	} -- 404
	local moon = satellite("moon", earth, MoonOrbitRadius, PH.moon) -- 406
	local parking = 0.1 -- 407
	local earthPos = bodyPositionAt(earth, 0) -- 410
	local earthVel = ____exports.bodyVelocityAt(earth, 0) -- 411
	local vCirc = circularSpeed(EarthGm, parking) -- 412
	return { -- 413
		id = 1, -- 414
		title = "月球", -- 415
		probeVariant = "solar", -- 416
		brief = "月球任务 · 地球轨道：你已经在绕地球飞了 —— 月球也在走。别对着它现在的位置点火，要打提前量。", -- 417
		probeStart = {x = earthPos.x, y = earthPos.y + parking}, -- 418
		probeVel0 = {x = earthVel.x - vCirc, y = earthVel.y}, -- 419
		planets = { -- 420
			sun(), -- 420
			earth, -- 420
			moon -- 420
		}, -- 420
		visuals = { -- 421
			sunVisual(), -- 422
			planetVisual( -- 423
				"earth", -- 423
				earth, -- 423
				0.42, -- 423
				0.62, -- 423
				0.85, -- 423
				"Planet_Earth", -- 423
				false -- 423
			), -- 423
			planetVisual( -- 424
				"moon", -- 424
				moon, -- 424
				0.56, -- 424
				0.56, -- 424
				0.6, -- 424
				"Moon", -- 424
				false -- 424
			) -- 424
		}, -- 424
		goal = {kind = "planet", planetIndex = 2, tolerance = 0.02}, -- 427
		dvBudget = 0.35, -- 428
		escapeRadius = 400, -- 432
		maxSteps = 2400, -- 435
		planCenter = 1 -- 436
	} -- 436
end -- 395
--- L2–L6 共用的出发状态：1 AU 圆轨道上的一点，顺行（-x），速度 = 该点圆轨速度。
local function departure() -- 443
	return {pos = {x = 0, y = ____exports.EarthOrbitRadius}, vel = {x = -____exports.EarthOrbitSpeed, y = 0}} -- 444
end -- 443
--- L2 金星：唯一一次**向内**飞（太阳一路加速你，难点是"收"）。
local function level2() -- 451
	local venus = orbiter("venus", PH.venus) -- 452
	local d = departure() -- 453
	return { -- 454
		id = 2, -- 455
		title = "金星", -- 456
		probeVariant = "solar", -- 457
		brief = "金星任务 · 1 AU 出发：向内飞，太阳会一路把你拽快。金星在 0.72 AU 的内圈上等着 —— 挑对它经过你航线的那一天。", -- 458
		probeStart = d.pos, -- 459
		probeVel0 = d.vel, -- 460
		planets = { -- 461
			sun(), -- 461
			venus -- 461
		}, -- 461
		visuals = { -- 462
			sunVisual(), -- 462
			planetVisual( -- 462
				"venus", -- 462
				venus, -- 462
				0.9, -- 462
				0.78, -- 462
				0.55, -- 462
				"Planet_Venus", -- 462
				false -- 462
			) -- 462
		}, -- 462
		goal = {kind = "planet", planetIndex = 1, tolerance = 3}, -- 463
		dvBudget = 4, -- 464
		escapeRadius = 3600, -- 465
		maxSteps = 4000, -- 466
		timeWindow = {span = 27} -- 467
	} -- 467
end -- 451
--- L3 木星：第一次真正的行星际飞行，也是本作的"核心瞬间"（被木星掰弯）。
local function level3() -- 472
	local jupiter = orbiter("jupiter", PH.jupiter3) -- 473
	local d = departure() -- 474
	return { -- 475
		id = 3, -- 476
		title = "木星", -- 477
		probeVariant = "solar", -- 478
		brief = "木星任务 · 1 AU 出发：5.2 AU 之外，真正的行星际飞行。出发角度要压在木星到达航线的那一天上。", -- 479
		probeStart = d.pos, -- 480
		probeVel0 = d.vel, -- 481
		planets = { -- 482
			sun(), -- 482
			jupiter -- 482
		}, -- 482
		visuals = { -- 483
			sunVisual(), -- 483
			planetVisual( -- 483
				"jupiter", -- 483
				jupiter, -- 483
				0.85, -- 483
				0.72, -- 483
				0.5, -- 483
				"Planet_Jupiter", -- 483
				false -- 483
			) -- 483
		}, -- 483
		goal = {kind = "planet", planetIndex = 1, tolerance = 25}, -- 484
		dvBudget = 12, -- 485
		escapeRadius = 3600, -- 486
		maxSteps = 20000, -- 487
		timeWindow = {span = 19} -- 488
	} -- 488
end -- 472
--- L4 土星：先掠过木星，再被土星接住（一次点火，两个环都要穿对）。
local function level4() -- 493
	local jupiter = orbiter("jupiter", PH.jupiter4) -- 494
	local saturn = orbiter("saturn", PH.saturn4) -- 495
	local d = departure() -- 496
	return { -- 497
		id = 4, -- 498
		title = "土星", -- 499
		probeVariant = "rtg", -- 500
		brief = "土星任务 · 1 AU 出发：9.5 AU，先穿过木星轨道，再到土星。一次点火，两个环都要穿对。", -- 501
		probeStart = d.pos, -- 502
		probeVel0 = d.vel, -- 503
		planets = { -- 504
			sun(), -- 504
			jupiter, -- 504
			saturn -- 504
		}, -- 504
		visuals = { -- 505
			sunVisual(), -- 506
			planetVisual( -- 507
				"jupiter", -- 507
				jupiter, -- 507
				0.85, -- 507
				0.72, -- 507
				0.5, -- 507
				"Planet_Jupiter", -- 507
				false -- 507
			), -- 507
			planetVisual( -- 508
				"saturn", -- 508
				saturn, -- 508
				0.75, -- 508
				0.7, -- 508
				0.6, -- 508
				"Planet_Saturn", -- 508
				true -- 508
			) -- 508
		}, -- 508
		goal = {kind = "planet", planetIndex = 2, tolerance = 45, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 45, label = "土星"}}}, -- 510
		dvBudget = 14, -- 517
		escapeRadius = 3600, -- 518
		maxSteps = 30000, -- 519
		timeWindow = {span = 18} -- 520
	} -- 520
end -- 493
--- L5 天王星：木星、土星两次借力，越飞越远。
local function level5() -- 525
	local jupiter = orbiter("jupiter", PH.jupiter5) -- 526
	local saturn = orbiter("saturn", PH.saturn5) -- 527
	local uranus = orbiter("uranus", PH.uranus5) -- 528
	local d = departure() -- 529
	return { -- 530
		id = 5, -- 531
		title = "天王星", -- 532
		probeVariant = "rtg", -- 533
		brief = "天王星任务 · 1 AU 出发：19 AU。木星、土星，一路向外 —— 一次点火要串起三个节点。", -- 534
		probeStart = d.pos, -- 535
		probeVel0 = d.vel, -- 536
		planets = { -- 537
			sun(), -- 537
			jupiter, -- 537
			saturn, -- 537
			uranus -- 537
		}, -- 537
		visuals = { -- 538
			sunVisual(), -- 539
			planetVisual( -- 540
				"jupiter", -- 540
				jupiter, -- 540
				0.85, -- 540
				0.72, -- 540
				0.5, -- 540
				"Planet_Jupiter", -- 540
				false -- 540
			), -- 540
			planetVisual( -- 541
				"saturn", -- 541
				saturn, -- 541
				0.75, -- 541
				0.7, -- 541
				0.6, -- 541
				"Planet_Saturn", -- 541
				true -- 541
			), -- 541
			planetVisual( -- 542
				"uranus", -- 542
				uranus, -- 542
				0.62, -- 542
				0.82, -- 542
				0.86, -- 542
				"Planet_Uranus", -- 542
				false -- 542
			) -- 542
		}, -- 542
		goal = {kind = "planet", planetIndex = 3, tolerance = 70, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 55, label = "土星"}, {planetIndex = 3, tolerance = 70, label = "天王星"}}}, -- 544
		dvBudget = 15, -- 552
		escapeRadius = 3600, -- 553
		maxSteps = 40000, -- 554
		timeWindow = {span = 17.5} -- 555
	} -- 555
end -- 525
--- L6 海王星：四颗巨行星连成一条线的那一天，一次点火串到底。
local function level6() -- 560
	local jupiter = orbiter("jupiter", PH.jupiter6) -- 561
	local saturn = orbiter("saturn", PH.saturn6) -- 562
	local uranus = orbiter("uranus", PH.uranus6) -- 563
	local neptune = orbiter("neptune", PH.neptune6) -- 564
	local d = departure() -- 565
	return { -- 566
		id = 6, -- 567
		title = "海王星", -- 568
		probeVariant = "rtg", -- 569
		brief = "海王星任务 · 1 AU 出发：30 AU。四颗巨行星排到一条线上的那一天 —— 一次点火串到底。", -- 570
		probeStart = d.pos, -- 571
		probeVel0 = d.vel, -- 572
		planets = { -- 573
			sun(), -- 573
			jupiter, -- 573
			saturn, -- 573
			uranus, -- 573
			neptune -- 573
		}, -- 573
		visuals = { -- 574
			sunVisual(), -- 575
			planetVisual( -- 576
				"jupiter", -- 576
				jupiter, -- 576
				0.85, -- 576
				0.72, -- 576
				0.5, -- 576
				"Planet_Jupiter", -- 576
				false -- 576
			), -- 576
			planetVisual( -- 577
				"saturn", -- 577
				saturn, -- 577
				0.75, -- 577
				0.7, -- 577
				0.6, -- 577
				"Planet_Saturn", -- 577
				true -- 577
			), -- 577
			planetVisual( -- 578
				"uranus", -- 578
				uranus, -- 578
				0.62, -- 578
				0.82, -- 578
				0.86, -- 578
				"Planet_Uranus", -- 578
				false -- 578
			), -- 578
			planetVisual( -- 579
				"neptune", -- 579
				neptune, -- 579
				0.34, -- 579
				0.5, -- 579
				0.86, -- 579
				"Planet_Neptune", -- 579
				false -- 579
			) -- 579
		}, -- 579
		goal = {kind = "planet", planetIndex = 4, tolerance = 120, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 60, label = "土星"}, {planetIndex = 3, tolerance = 90, label = "天王星"}, {planetIndex = 4, tolerance = 120, label = "海王星"}}}, -- 581
		dvBudget = 16, -- 590
		escapeRadius = 3600, -- 591
		maxSteps = 70000, -- 592
		timeWindow = {span = 17.5} -- 593
	} -- 593
end -- 560
local LEVELS = { -- 597
	level1(), -- 597
	level2(), -- 597
	level3(), -- 597
	level4(), -- 597
	level5(), -- 597
	level6() -- 597
} -- 597
--- 关卡总数。
function ____exports.levelCount() -- 600
	return #LEVELS -- 601
end -- 600
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 605
	return LEVELS[index + 1] -- 606
end -- 605
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 610
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 611
end -- 610
return ____exports -- 610