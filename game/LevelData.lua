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
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 621
	local out = {} -- 622
	for ____, b in ipairs(bodies) do -- 623
		out[#out + 1] = { -- 624
			gm = b.gm * gravityScale, -- 625
			radius = b.radius, -- 626
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 627
			orbitRadius = b.orbitRadius, -- 628
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 629
			phase0 = b.phase0, -- 630
			orbitDirection = b.orbitDirection, -- 631
			host = b.host ~= nil and applyScalesLocal({b.host}, gravityScale, orbitScale)[1] or nil -- 633
		} -- 633
	end -- 633
	return out -- 636
end -- 636
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
--- 视觉描述。`levelIndex` 决定用哪张视觉半径表：0 = L1 用地月系专用表（见 Tuning）。
local function planetVisual(key, body, r, g, b, model, ring, levelIndex) -- 329
	return { -- 330
		r = r, -- 330
		g = g, -- 330
		b = b, -- 330
		displayRadius = visualRadius(key, body.radius, levelIndex), -- 330
		ring = ring, -- 330
		model = model -- 330
	} -- 330
end -- 329
--- 太阳的视觉（自发光 + 光晕）。
local function sunVisual(levelIndex) -- 334
	return { -- 336
		r = 1, -- 336
		g = 0.97, -- 336
		b = 0.88, -- 336
		displayRadius = visualRadius("sun", SunRadius, levelIndex), -- 336
		ring = false, -- 336
		model = "Sun", -- 336
		emissive = {r = 1, g = 0.95, b = 0.82} -- 336
	} -- 336
end -- 334
--- 出发轨道半径 = 1 AU（地球轨道）。六关共用 —— L1 的地球就在这里，L2–L6 从这里出发。
____exports.EarthOrbitRadius = trueOrbit(REAL.earth.au) -- 346
--- 该点的日心圆轨速度（30.00 平面单位/秒 —— 全套尺度的速度锚点）。
____exports.EarthOrbitSpeed = circularSpeed(SunGm, ____exports.EarthOrbitRadius) -- 349
--- 相位表 —— **全部由 `node tools/level-phases.mjs <关号> --dirs 240 --dvs 31 --tmax N` 解出**，不许手填。
-- 
-- ⚠️ 同一颗行星在**不同关的相位不同**，这是对的：相位代表"哪一天的太阳系"，
--    每一关的可行发射窗口本来就不一样。物理量（gm / 半径 / 轨道 / 周期）才是六关共用、不许变的。
-- 
-- 每一行后面的注释就是它的出处（工具输出），改数值必须重跑工具。
local PH = { -- 359
	venus = 79.6, -- 361
	jupiter3 = 186.1, -- 366
	jupiter4 = 184.4, -- 367
	jupiter5 = 175.6, -- 368
	jupiter6 = 175.2, -- 369
	saturn4 = 199.6, -- 371
	saturn5 = 190.8, -- 372
	saturn6 = 190.3, -- 373
	uranus5 = 202.8, -- 375
	uranus6 = 201.8, -- 376
	neptune6 = 207.6, -- 378
	moon = 154.7 -- 386
} -- 386
--- L1：地月系。
-- 
-- - 地球是**真天体**：真 gm、真半径，自己在绕日公转（这是"物理统一"的试纸）；
-- - 月球绕地球，周期由开普勒第三定律算出 = 1.2593 秒（真实值）；
-- - 探测器在**绕地圆轨道**上，半径 0.1 单位（= 18.7 万 km = 月球距离的 49%）：
--   初始速度 = 地球的公转速度 + 绕地圆轨速度（顺行），所以预测线一上来就是一条弧线；
-- - 点火目标：抬升到月球轨道 0.2056 做霍曼转移，半程 0.4034 秒。
local function level1() -- 398
	local earthOrbit = ____exports.EarthOrbitRadius -- 399
	local earth = { -- 400
		gm = EarthGm, -- 401
		radius = EarthRadius, -- 402
		orbitCenter = {x = 0, y = 0}, -- 403
		orbitRadius = earthOrbit, -- 404
		orbitPeriod = period(earthOrbit, SunGm), -- 405
		phase0 = deg(90), -- 406
		orbitDirection = 1 -- 407
	} -- 407
	local moon = satellite("moon", earth, MoonOrbitRadius, PH.moon) -- 409
	local parking = 0.1 -- 410
	local earthPos = bodyPositionAt(earth, 0) -- 413
	local earthVel = ____exports.bodyVelocityAt(earth, 0) -- 414
	local vCirc = circularSpeed(EarthGm, parking) -- 415
	return { -- 416
		id = 1, -- 417
		title = "月球", -- 418
		probeVariant = "solar", -- 419
		brief = "月球任务 · 地球轨道：你已经在绕地球飞了 —— 月球也在走。别对着它现在的位置点火，要打提前量。", -- 420
		probeStart = {x = earthPos.x, y = earthPos.y + parking}, -- 421
		probeVel0 = {x = earthVel.x - vCirc, y = earthVel.y}, -- 422
		planets = { -- 423
			sun(), -- 423
			earth, -- 423
			moon -- 423
		}, -- 423
		visuals = { -- 427
			sunVisual(0), -- 428
			planetVisual( -- 429
				"earth", -- 429
				earth, -- 429
				0.42, -- 429
				0.62, -- 429
				0.85, -- 429
				"Planet_Earth", -- 429
				false, -- 429
				0 -- 429
			), -- 429
			planetVisual( -- 430
				"moon", -- 430
				moon, -- 430
				0.56, -- 430
				0.56, -- 430
				0.6, -- 430
				"Moon", -- 430
				false, -- 430
				0 -- 430
			) -- 430
		}, -- 430
		goal = {kind = "planet", planetIndex = 2, tolerance = 0.02}, -- 433
		dvBudget = 0.35, -- 434
		escapeRadius = 400, -- 438
		maxSteps = 2400, -- 441
		planCenter = 1 -- 442
	} -- 442
end -- 398
--- L2–L6 共用的出发状态：1 AU 圆轨道上的一点，顺行（-x），速度 = 该点圆轨速度。
local function departure() -- 449
	return {pos = {x = 0, y = ____exports.EarthOrbitRadius}, vel = {x = -____exports.EarthOrbitSpeed, y = 0}} -- 450
end -- 449
--- L2 金星：唯一一次**向内**飞（太阳一路加速你，难点是"收"）。
local function level2() -- 457
	local venus = orbiter("venus", PH.venus) -- 458
	local d = departure() -- 459
	return { -- 460
		id = 2, -- 461
		title = "金星", -- 462
		probeVariant = "solar", -- 463
		brief = "金星任务 · 1 AU 出发：向内飞，太阳会一路把你拽快。金星在 0.72 AU 的内圈上等着 —— 挑对它经过你航线的那一天。", -- 464
		probeStart = d.pos, -- 465
		probeVel0 = d.vel, -- 466
		planets = { -- 467
			sun(), -- 467
			venus -- 467
		}, -- 467
		visuals = { -- 468
			sunVisual(), -- 468
			planetVisual( -- 468
				"venus", -- 468
				venus, -- 468
				0.9, -- 468
				0.78, -- 468
				0.55, -- 468
				"Planet_Venus", -- 468
				false -- 468
			) -- 468
		}, -- 468
		goal = {kind = "planet", planetIndex = 1, tolerance = 3}, -- 469
		dvBudget = 4, -- 470
		escapeRadius = 3600, -- 471
		maxSteps = 4000, -- 472
		timeWindow = {span = 27} -- 473
	} -- 473
end -- 457
--- L3 木星：第一次真正的行星际飞行，也是本作的"核心瞬间"（被木星掰弯）。
local function level3() -- 478
	local jupiter = orbiter("jupiter", PH.jupiter3) -- 479
	local d = departure() -- 480
	return { -- 481
		id = 3, -- 482
		title = "木星", -- 483
		probeVariant = "solar", -- 484
		brief = "木星任务 · 1 AU 出发：5.2 AU 之外，真正的行星际飞行。出发角度要压在木星到达航线的那一天上。", -- 485
		probeStart = d.pos, -- 486
		probeVel0 = d.vel, -- 487
		planets = { -- 488
			sun(), -- 488
			jupiter -- 488
		}, -- 488
		visuals = { -- 489
			sunVisual(), -- 489
			planetVisual( -- 489
				"jupiter", -- 489
				jupiter, -- 489
				0.85, -- 489
				0.72, -- 489
				0.5, -- 489
				"Planet_Jupiter", -- 489
				false -- 489
			) -- 489
		}, -- 489
		goal = {kind = "planet", planetIndex = 1, tolerance = 25}, -- 490
		dvBudget = 12, -- 491
		escapeRadius = 3600, -- 492
		maxSteps = 20000, -- 493
		timeWindow = {span = 19} -- 494
	} -- 494
end -- 478
--- L4 土星：先掠过木星，再被土星接住（一次点火，两个环都要穿对）。
local function level4() -- 499
	local jupiter = orbiter("jupiter", PH.jupiter4) -- 500
	local saturn = orbiter("saturn", PH.saturn4) -- 501
	local d = departure() -- 502
	return { -- 503
		id = 4, -- 504
		title = "土星", -- 505
		probeVariant = "rtg", -- 506
		brief = "土星任务 · 1 AU 出发：9.5 AU，先穿过木星轨道，再到土星。一次点火，两个环都要穿对。", -- 507
		probeStart = d.pos, -- 508
		probeVel0 = d.vel, -- 509
		planets = { -- 510
			sun(), -- 510
			jupiter, -- 510
			saturn -- 510
		}, -- 510
		visuals = { -- 511
			sunVisual(), -- 512
			planetVisual( -- 513
				"jupiter", -- 513
				jupiter, -- 513
				0.85, -- 513
				0.72, -- 513
				0.5, -- 513
				"Planet_Jupiter", -- 513
				false -- 513
			), -- 513
			planetVisual( -- 514
				"saturn", -- 514
				saturn, -- 514
				0.75, -- 514
				0.7, -- 514
				0.6, -- 514
				"Planet_Saturn", -- 514
				true -- 514
			) -- 514
		}, -- 514
		goal = {kind = "planet", planetIndex = 2, tolerance = 45, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 45, label = "土星"}}}, -- 516
		dvBudget = 14, -- 523
		escapeRadius = 3600, -- 524
		maxSteps = 30000, -- 525
		timeWindow = {span = 18} -- 526
	} -- 526
end -- 499
--- L5 天王星：木星、土星两次借力，越飞越远。
local function level5() -- 531
	local jupiter = orbiter("jupiter", PH.jupiter5) -- 532
	local saturn = orbiter("saturn", PH.saturn5) -- 533
	local uranus = orbiter("uranus", PH.uranus5) -- 534
	local d = departure() -- 535
	return { -- 536
		id = 5, -- 537
		title = "天王星", -- 538
		probeVariant = "rtg", -- 539
		brief = "天王星任务 · 1 AU 出发：19 AU。木星、土星，一路向外 —— 一次点火要串起三个节点。", -- 540
		probeStart = d.pos, -- 541
		probeVel0 = d.vel, -- 542
		planets = { -- 543
			sun(), -- 543
			jupiter, -- 543
			saturn, -- 543
			uranus -- 543
		}, -- 543
		visuals = { -- 544
			sunVisual(), -- 545
			planetVisual( -- 546
				"jupiter", -- 546
				jupiter, -- 546
				0.85, -- 546
				0.72, -- 546
				0.5, -- 546
				"Planet_Jupiter", -- 546
				false -- 546
			), -- 546
			planetVisual( -- 547
				"saturn", -- 547
				saturn, -- 547
				0.75, -- 547
				0.7, -- 547
				0.6, -- 547
				"Planet_Saturn", -- 547
				true -- 547
			), -- 547
			planetVisual( -- 548
				"uranus", -- 548
				uranus, -- 548
				0.62, -- 548
				0.82, -- 548
				0.86, -- 548
				"Planet_Uranus", -- 548
				false -- 548
			) -- 548
		}, -- 548
		goal = {kind = "planet", planetIndex = 3, tolerance = 70, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 55, label = "土星"}, {planetIndex = 3, tolerance = 70, label = "天王星"}}}, -- 550
		dvBudget = 15, -- 558
		escapeRadius = 3600, -- 559
		maxSteps = 40000, -- 560
		timeWindow = {span = 17.5} -- 561
	} -- 561
end -- 531
--- L6 海王星：四颗巨行星连成一条线的那一天，一次点火串到底。
local function level6() -- 566
	local jupiter = orbiter("jupiter", PH.jupiter6) -- 567
	local saturn = orbiter("saturn", PH.saturn6) -- 568
	local uranus = orbiter("uranus", PH.uranus6) -- 569
	local neptune = orbiter("neptune", PH.neptune6) -- 570
	local d = departure() -- 571
	return { -- 572
		id = 6, -- 573
		title = "海王星", -- 574
		probeVariant = "rtg", -- 575
		brief = "海王星任务 · 1 AU 出发：30 AU。四颗巨行星排到一条线上的那一天 —— 一次点火串到底。", -- 576
		probeStart = d.pos, -- 577
		probeVel0 = d.vel, -- 578
		planets = { -- 579
			sun(), -- 579
			jupiter, -- 579
			saturn, -- 579
			uranus, -- 579
			neptune -- 579
		}, -- 579
		visuals = { -- 580
			sunVisual(), -- 581
			planetVisual( -- 582
				"jupiter", -- 582
				jupiter, -- 582
				0.85, -- 582
				0.72, -- 582
				0.5, -- 582
				"Planet_Jupiter", -- 582
				false -- 582
			), -- 582
			planetVisual( -- 583
				"saturn", -- 583
				saturn, -- 583
				0.75, -- 583
				0.7, -- 583
				0.6, -- 583
				"Planet_Saturn", -- 583
				true -- 583
			), -- 583
			planetVisual( -- 584
				"uranus", -- 584
				uranus, -- 584
				0.62, -- 584
				0.82, -- 584
				0.86, -- 584
				"Planet_Uranus", -- 584
				false -- 584
			), -- 584
			planetVisual( -- 585
				"neptune", -- 585
				neptune, -- 585
				0.34, -- 585
				0.5, -- 585
				0.86, -- 585
				"Planet_Neptune", -- 585
				false -- 585
			) -- 585
		}, -- 585
		goal = {kind = "planet", planetIndex = 4, tolerance = 120, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 60, label = "土星"}, {planetIndex = 3, tolerance = 90, label = "天王星"}, {planetIndex = 4, tolerance = 120, label = "海王星"}}}, -- 587
		dvBudget = 16, -- 596
		escapeRadius = 3600, -- 597
		maxSteps = 70000, -- 598
		timeWindow = {span = 17.5} -- 599
	} -- 599
end -- 566
local LEVELS = { -- 603
	level1(), -- 603
	level2(), -- 603
	level3(), -- 603
	level4(), -- 603
	level5(), -- 603
	level6() -- 603
} -- 603
--- 关卡总数。
function ____exports.levelCount() -- 606
	return #LEVELS -- 607
end -- 606
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 611
	return LEVELS[index + 1] -- 612
end -- 611
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 616
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 617
end -- 616
return ____exports -- 616