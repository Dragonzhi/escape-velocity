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
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 613
	local out = {} -- 614
	for ____, b in ipairs(bodies) do -- 615
		out[#out + 1] = { -- 616
			gm = b.gm * gravityScale, -- 617
			radius = b.radius, -- 618
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 619
			orbitRadius = b.orbitRadius, -- 620
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 621
			phase0 = b.phase0, -- 622
			orbitDirection = b.orbitDirection, -- 623
			host = b.host ~= nil and applyScalesLocal({b.host}, gravityScale, orbitScale)[1] or nil -- 625
		} -- 625
	end -- 625
	return out -- 628
end -- 628
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
		maxSteps = 4000, -- 433
		planCenter = 1 -- 434
	} -- 434
end -- 395
--- L2–L6 共用的出发状态：1 AU 圆轨道上的一点，顺行（-x），速度 = 该点圆轨速度。
local function departure() -- 441
	return {pos = {x = 0, y = ____exports.EarthOrbitRadius}, vel = {x = -____exports.EarthOrbitSpeed, y = 0}} -- 442
end -- 441
--- L2 金星：唯一一次**向内**飞（太阳一路加速你，难点是"收"）。
local function level2() -- 449
	local venus = orbiter("venus", PH.venus) -- 450
	local d = departure() -- 451
	return { -- 452
		id = 2, -- 453
		title = "金星", -- 454
		probeVariant = "solar", -- 455
		brief = "金星任务 · 1 AU 出发：向内飞，太阳会一路把你拽快。金星在 0.72 AU 的内圈上等着 —— 挑对它经过你航线的那一天。", -- 456
		probeStart = d.pos, -- 457
		probeVel0 = d.vel, -- 458
		planets = { -- 459
			sun(), -- 459
			venus -- 459
		}, -- 459
		visuals = { -- 460
			sunVisual(), -- 460
			planetVisual( -- 460
				"venus", -- 460
				venus, -- 460
				0.9, -- 460
				0.78, -- 460
				0.55, -- 460
				"Planet_Venus", -- 460
				false -- 460
			) -- 460
		}, -- 460
		goal = {kind = "planet", planetIndex = 1, tolerance = 3}, -- 461
		dvBudget = 4, -- 462
		escapeRadius = 3600, -- 463
		maxSteps = 4000, -- 464
		timeWindow = {span = 27} -- 465
	} -- 465
end -- 449
--- L3 木星：第一次真正的行星际飞行，也是本作的"核心瞬间"（被木星掰弯）。
local function level3() -- 470
	local jupiter = orbiter("jupiter", PH.jupiter3) -- 471
	local d = departure() -- 472
	return { -- 473
		id = 3, -- 474
		title = "木星", -- 475
		probeVariant = "solar", -- 476
		brief = "木星任务 · 1 AU 出发：5.2 AU 之外，真正的行星际飞行。出发角度要压在木星到达航线的那一天上。", -- 477
		probeStart = d.pos, -- 478
		probeVel0 = d.vel, -- 479
		planets = { -- 480
			sun(), -- 480
			jupiter -- 480
		}, -- 480
		visuals = { -- 481
			sunVisual(), -- 481
			planetVisual( -- 481
				"jupiter", -- 481
				jupiter, -- 481
				0.85, -- 481
				0.72, -- 481
				0.5, -- 481
				"Planet_Jupiter", -- 481
				false -- 481
			) -- 481
		}, -- 481
		goal = {kind = "planet", planetIndex = 1, tolerance = 25}, -- 482
		dvBudget = 12, -- 483
		escapeRadius = 3600, -- 484
		maxSteps = 20000, -- 485
		timeWindow = {span = 19} -- 486
	} -- 486
end -- 470
--- L4 土星：先掠过木星，再被土星接住（一次点火，两个环都要穿对）。
local function level4() -- 491
	local jupiter = orbiter("jupiter", PH.jupiter4) -- 492
	local saturn = orbiter("saturn", PH.saturn4) -- 493
	local d = departure() -- 494
	return { -- 495
		id = 4, -- 496
		title = "土星", -- 497
		probeVariant = "rtg", -- 498
		brief = "土星任务 · 1 AU 出发：9.5 AU，先穿过木星轨道，再到土星。一次点火，两个环都要穿对。", -- 499
		probeStart = d.pos, -- 500
		probeVel0 = d.vel, -- 501
		planets = { -- 502
			sun(), -- 502
			jupiter, -- 502
			saturn -- 502
		}, -- 502
		visuals = { -- 503
			sunVisual(), -- 504
			planetVisual( -- 505
				"jupiter", -- 505
				jupiter, -- 505
				0.85, -- 505
				0.72, -- 505
				0.5, -- 505
				"Planet_Jupiter", -- 505
				false -- 505
			), -- 505
			planetVisual( -- 506
				"saturn", -- 506
				saturn, -- 506
				0.75, -- 506
				0.7, -- 506
				0.6, -- 506
				"Planet_Saturn", -- 506
				true -- 506
			) -- 506
		}, -- 506
		goal = {kind = "planet", planetIndex = 2, tolerance = 45, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 45, label = "土星"}}}, -- 508
		dvBudget = 14, -- 515
		escapeRadius = 3600, -- 516
		maxSteps = 30000, -- 517
		timeWindow = {span = 18} -- 518
	} -- 518
end -- 491
--- L5 天王星：木星、土星两次借力，越飞越远。
local function level5() -- 523
	local jupiter = orbiter("jupiter", PH.jupiter5) -- 524
	local saturn = orbiter("saturn", PH.saturn5) -- 525
	local uranus = orbiter("uranus", PH.uranus5) -- 526
	local d = departure() -- 527
	return { -- 528
		id = 5, -- 529
		title = "天王星", -- 530
		probeVariant = "rtg", -- 531
		brief = "天王星任务 · 1 AU 出发：19 AU。木星、土星，一路向外 —— 一次点火要串起三个节点。", -- 532
		probeStart = d.pos, -- 533
		probeVel0 = d.vel, -- 534
		planets = { -- 535
			sun(), -- 535
			jupiter, -- 535
			saturn, -- 535
			uranus -- 535
		}, -- 535
		visuals = { -- 536
			sunVisual(), -- 537
			planetVisual( -- 538
				"jupiter", -- 538
				jupiter, -- 538
				0.85, -- 538
				0.72, -- 538
				0.5, -- 538
				"Planet_Jupiter", -- 538
				false -- 538
			), -- 538
			planetVisual( -- 539
				"saturn", -- 539
				saturn, -- 539
				0.75, -- 539
				0.7, -- 539
				0.6, -- 539
				"Planet_Saturn", -- 539
				true -- 539
			), -- 539
			planetVisual( -- 540
				"uranus", -- 540
				uranus, -- 540
				0.62, -- 540
				0.82, -- 540
				0.86, -- 540
				"Planet_Uranus", -- 540
				false -- 540
			) -- 540
		}, -- 540
		goal = {kind = "planet", planetIndex = 3, tolerance = 70, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 55, label = "土星"}, {planetIndex = 3, tolerance = 70, label = "天王星"}}}, -- 542
		dvBudget = 15, -- 550
		escapeRadius = 3600, -- 551
		maxSteps = 40000, -- 552
		timeWindow = {span = 17.5} -- 553
	} -- 553
end -- 523
--- L6 海王星：四颗巨行星连成一条线的那一天，一次点火串到底。
local function level6() -- 558
	local jupiter = orbiter("jupiter", PH.jupiter6) -- 559
	local saturn = orbiter("saturn", PH.saturn6) -- 560
	local uranus = orbiter("uranus", PH.uranus6) -- 561
	local neptune = orbiter("neptune", PH.neptune6) -- 562
	local d = departure() -- 563
	return { -- 564
		id = 6, -- 565
		title = "海王星", -- 566
		probeVariant = "rtg", -- 567
		brief = "海王星任务 · 1 AU 出发：30 AU。四颗巨行星排到一条线上的那一天 —— 一次点火串到底。", -- 568
		probeStart = d.pos, -- 569
		probeVel0 = d.vel, -- 570
		planets = { -- 571
			sun(), -- 571
			jupiter, -- 571
			saturn, -- 571
			uranus, -- 571
			neptune -- 571
		}, -- 571
		visuals = { -- 572
			sunVisual(), -- 573
			planetVisual( -- 574
				"jupiter", -- 574
				jupiter, -- 574
				0.85, -- 574
				0.72, -- 574
				0.5, -- 574
				"Planet_Jupiter", -- 574
				false -- 574
			), -- 574
			planetVisual( -- 575
				"saturn", -- 575
				saturn, -- 575
				0.75, -- 575
				0.7, -- 575
				0.6, -- 575
				"Planet_Saturn", -- 575
				true -- 575
			), -- 575
			planetVisual( -- 576
				"uranus", -- 576
				uranus, -- 576
				0.62, -- 576
				0.82, -- 576
				0.86, -- 576
				"Planet_Uranus", -- 576
				false -- 576
			), -- 576
			planetVisual( -- 577
				"neptune", -- 577
				neptune, -- 577
				0.34, -- 577
				0.5, -- 577
				0.86, -- 577
				"Planet_Neptune", -- 577
				false -- 577
			) -- 577
		}, -- 577
		goal = {kind = "planet", planetIndex = 4, tolerance = 120, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 60, label = "土星"}, {planetIndex = 3, tolerance = 90, label = "天王星"}, {planetIndex = 4, tolerance = 120, label = "海王星"}}}, -- 579
		dvBudget = 16, -- 588
		escapeRadius = 3600, -- 589
		maxSteps = 70000, -- 590
		timeWindow = {span = 17.5} -- 591
	} -- 591
end -- 558
local LEVELS = { -- 595
	level1(), -- 595
	level2(), -- 595
	level3(), -- 595
	level4(), -- 595
	level5(), -- 595
	level6() -- 595
} -- 595
--- 关卡总数。
function ____exports.levelCount() -- 598
	return #LEVELS -- 599
end -- 598
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 603
	return LEVELS[index + 1] -- 604
end -- 603
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 608
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 609
end -- 608
return ____exports -- 608