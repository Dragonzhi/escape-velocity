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
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 825
	local out = {} -- 826
	for ____, b in ipairs(bodies) do -- 827
		out[#out + 1] = { -- 828
			gm = b.gm * gravityScale, -- 829
			radius = b.radius, -- 830
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 831
			orbitRadius = b.orbitRadius, -- 832
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 833
			phase0 = b.phase0, -- 834
			orbitDirection = b.orbitDirection, -- 835
			isObstacle = b.isObstacle, -- 836
			name = b.name, -- 837
			host = b.host ~= nil and applyScalesLocal({b.host}, gravityScale, orbitScale)[1] or nil -- 839
		} -- 839
	end -- 839
	return out -- 842
end -- 842
--- 评价一局飞行的火箭星级及逐条达成详情（纯函数）。
function ____exports.evaluateRocketsDetailed(level, result, burnDv, extra) -- 230
	local achieved = {false, false, false} -- 240
	if result ~= "success" then -- 240
		return {rockets = 0, achieved = achieved, burnDv = burnDv, stats = extra ~= nil and extra or ({})} -- 242
	end -- 242
	achieved[1] = true -- 250
	local count = 1 -- 251
	local challenges = level.mission ~= nil and level.mission.challenges or nil -- 252
	if challenges ~= nil then -- 252
		local c2 = challenges[2] -- 255
		if c2.type == "fuel" and c2.threshold ~= nil then -- 255
			if burnDv <= level.dvBudget * c2.threshold then -- 255
				achieved[2] = true -- 258
				count = count + 1 -- 259
			end -- 259
		elseif burnDv <= level.dvBudget * 0.8 then -- 259
			achieved[2] = true -- 262
			count = count + 1 -- 263
		end -- 263
		local c3 = challenges[3] -- 267
		if c3.type == "distance" and c3.threshold ~= nil then -- 267
			if extra ~= nil and extra.closestDist ~= nil and extra.closestDist <= c3.threshold then -- 267
				achieved[3] = true -- 270
				count = count + 1 -- 271
			end -- 271
		elseif c3.type == "speed" and c3.threshold ~= nil then -- 271
			if extra ~= nil and extra.maxSpeed ~= nil and extra.maxSpeed >= c3.threshold then -- 271
				achieved[3] = true -- 275
				count = count + 1 -- 276
			end -- 276
		elseif c3.type == "eccentricity" and c3.threshold ~= nil then -- 276
			if extra ~= nil and extra.eccentricity ~= nil and extra.eccentricity <= c3.threshold then -- 276
				achieved[3] = true -- 280
				count = count + 1 -- 281
			end -- 281
		elseif count == 2 and burnDv <= level.dvBudget * 0.5 then -- 281
			achieved[3] = true -- 284
			count = count + 1 -- 285
		end -- 285
	end -- 285
	return { -- 289
		rockets = math.min( -- 290
			3, -- 290
			math.max(0, count) -- 290
		), -- 290
		achieved = achieved, -- 291
		burnDv = burnDv, -- 292
		stats = extra ~= nil and extra or ({}) -- 293
	} -- 293
end -- 230
--- 评价一局飞行的火箭星级（0 ~ 3 枚火箭，纯函数）。
function ____exports.evaluateRockets(level, result, burnDv, extra) -- 300
	return ____exports.evaluateRocketsDetailed(level, result, burnDv, extra).rockets -- 310
end -- 300
--- 导出名与旧版一致（外部调用方按这个名字找）。
function ____exports.bodyVelocityAt(b, t) -- 322
	if b.orbitPeriod == 0 or b.orbitRadius <= 0 then -- 322
		return {x = 0, y = 0} -- 323
	end -- 323
	local angle = b.phase0 + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 324
	local w = b.orbitDirection * 2 * math.pi / b.orbitPeriod -- 325
	return { -- 326
		x = -math.sin(angle) * b.orbitRadius * w, -- 326
		y = math.cos(angle) * b.orbitRadius * w -- 326
	} -- 326
end -- 322
--- 航点列表（链式目标取 chain，否则就是唯一目标）。
function ____exports.goalWaypoints(goal) -- 330
	if goal.chain ~= nil then -- 330
		return goal.chain -- 331
	end -- 331
	if goal.kind == "planet" then -- 331
		return {{planetIndex = goal.planetIndex, tolerance = goal.tolerance}} -- 332
	end -- 332
	return {} -- 333
end -- 330
--- 采样点 i 处、相对某天体的速度（捕获判据与诊断共用同一份实现）。
-- 
-- points 里只有位置 ⇒ 用相邻采样点差分；`dt` 是**相邻采样点之间的有效步长**。
-- `limit` 是最后一个有效采样点索引（末端夹紧用）。
function ____exports.relativeSpeedAt(points, i, body, dt, t0, limit, velocities) -- 342
	local vx = 0 -- 343
	local vy = 0 -- 344
	if velocities ~= nil and velocities[i + 1] ~= nil then -- 344
		vx = velocities[i + 1].x -- 347
		vy = velocities[i + 1].y -- 348
	else -- 348
		local j1 = i + 1 <= limit and i + 1 or i -- 352
		local j0 = i > 0 and i - 1 or i -- 353
		local spanT = (j1 - j0) * dt -- 354
		if spanT > 0 then -- 354
			vx = (points[j1 + 1].x - points[j0 + 1].x) / spanT -- 356
			vy = (points[j1 + 1].y - points[j0 + 1].y) / spanT -- 357
		end -- 357
	end -- 357
	local pv = ____exports.bodyVelocityAt(body, t0) -- 360
	local rx = vx - pv.x -- 361
	local ry = vy - pv.y -- 362
	return math.sqrt(rx * rx + ry * ry) -- 363
end -- 342
--- 捕获阈值：该处逃逸速度（圆轨道速度 × 系数 k，k 默认 √2）。
function ____exports.captureThreshold(body, d, k) -- 367
	if body.gm <= 0 or d <= 0.000001 then -- 367
		return 1000000000 -- 368
	end -- 368
	return k * math.sqrt(body.gm / d) -- 369
end -- 367
--- 顺序航线的进度：返回在 points[0..upto] 里**依次**掠过的航点数与最后一个命中索引。
-- 
-- 一次线性扫描：航点必须按顺序命中，且后一个必须出现在更晚的采样点上
-- （"先到土星再路过木星"不算数）。upto 用于飞行中查询"到哪一段了"（画环的明暗）。
function ____exports.waypointProgress(points, bodies, goal, dt, t0, upto, velocities) -- 378
	local wps = ____exports.goalWaypoints(goal) -- 387
	local start = t0 ~= nil and t0 or 0 -- 388
	local limit = #points - 1 -- 389
	if upto ~= nil and upto >= 0 and upto < limit then -- 389
		limit = upto -- 390
	end -- 390
	local next = 0 -- 391
	local lastIndex = -1 -- 392
	do -- 392
		local i = 0 -- 393
		while i <= limit and next < #wps do -- 393
			do -- 393
				local w = wps[next + 1] -- 394
				local body = bodies[w.planetIndex + 1] -- 395
				if body == nil then -- 395
					return {passed = 0, lastIndex = -1} -- 396
				end -- 396
				local gp = bodyPositionAt(body, start + i * dt) -- 397
				if distance(points[i + 1], gp) < w.tolerance then -- 397
					if w.capture == true then -- 397
						local k = w.captureFactor ~= nil and w.captureFactor or 1.4142135623730951 -- 402
						local d = distance(points[i + 1], gp) -- 403
						if d <= body.radius then -- 403
							goto __continue30 -- 406
						end -- 406
						local rel = ____exports.relativeSpeedAt( -- 407
							points, -- 407
							i, -- 407
							body, -- 407
							dt, -- 407
							start + i * dt, -- 407
							limit, -- 407
							velocities -- 407
						) -- 407
						if rel > ____exports.captureThreshold(body, d, k) then -- 407
							goto __continue30 -- 408
						end -- 408
					end -- 408
					next = next + 1 -- 410
					lastIndex = i -- 411
				end -- 411
			end -- 411
			::__continue30:: -- 411
			i = i + 1 -- 393
		end -- 393
	end -- 393
	return {passed = next, lastIndex = lastIndex} -- 414
end -- 378
--- 到达目标的采样点索引；没到返回 -1。
function ____exports.findGoalIndex(points, bodies, goal, dt, t0, velocities) -- 418
	local wps = ____exports.goalWaypoints(goal) -- 419
	if #wps == 0 then -- 419
		return -1 -- 420
	end -- 420
	local st = ____exports.waypointProgress( -- 421
		points, -- 421
		bodies, -- 421
		goal, -- 421
		dt, -- 421
		t0, -- 421
		nil, -- 421
		velocities -- 421
	) -- 421
	return st.passed >= #wps and st.lastIndex or -1 -- 422
end -- 418
--- 度 → 弧度（关卡数据里写角度比写弧度好读）。
local function deg(d) -- 430
	return d * math.pi / 180 -- 431
end -- 430
--- 太阳（每关的第 0 号天体）。
local function sun() -- 435
	return { -- 436
		gm = SunGm, -- 436
		radius = SunRadius, -- 436
		orbitCenter = {x = 0, y = 0}, -- 436
		orbitRadius = 0, -- 436
		orbitPeriod = 0, -- 436
		phase0 = 0, -- 436
		orbitDirection = 1 -- 436
	} -- 436
end -- 435
--- 绕太阳公转的行星：`key` 是 Scale.REAL 里的键。
-- 
-- 真半径 0.0034（地球）到 0.0374（木星），**不再有任何放大** —— 用户要求"天体大小改为符合物理的大小"。
-- 看得见的那一层在 Tuning.BODY_VISUAL_RADIUS。
local function orbiter(key, phaseDeg) -- 445
	local real = REAL[key] -- 446
	local a = trueOrbit(real.au) -- 447
	return { -- 448
		gm = trueGm(real.gm), -- 449
		radius = trueRadius(real.radiusKm), -- 450
		orbitCenter = {x = 0, y = 0}, -- 451
		orbitRadius = a, -- 452
		orbitPeriod = period(a, SunGm), -- 453
		phase0 = deg(phaseDeg), -- 454
		orbitDirection = 1 -- 455
	} -- 455
end -- 445
--- 绕**会动的宿主**公转的卫星（L1 的月球）。
-- 
-- 周期用开普勒第三定律 `2π·sqrt(a³/μ)` 算，**μ 取宿主（地球）的 gm** ——
-- 这是最容易搞错的一步：拿月球自己的 gm 去算会得到 11.35 秒（正确值 1.2593 秒）。
local function satellite(key, host, orbitRadius, phaseDeg) -- 465
	local real = REAL[key] -- 466
	return { -- 467
		gm = trueGm(real.gm), -- 468
		radius = trueRadius(real.radiusKm), -- 469
		orbitCenter = {x = 0, y = 0}, -- 470
		orbitRadius = orbitRadius, -- 471
		orbitPeriod = period(orbitRadius, host.gm), -- 472
		phase0 = deg(phaseDeg), -- 473
		orbitDirection = 1, -- 474
		host = host -- 475
	} -- 475
end -- 465
--- 视觉描述。`levelIndex` 决定用哪张视觉半径表：0 = L1 用地月系专用表（见 Tuning）。
local function planetVisual(key, body, r, g, b, model, ring, levelIndex) -- 483
	return { -- 484
		r = r, -- 484
		g = g, -- 484
		b = b, -- 484
		displayRadius = visualRadius(key, body.radius, levelIndex), -- 484
		ring = ring, -- 484
		model = model -- 484
	} -- 484
end -- 483
--- 太阳的视觉（自发光 + 光晕）。
local function sunVisual(levelIndex) -- 488
	return { -- 490
		r = 1, -- 490
		g = 0.97, -- 490
		b = 0.88, -- 490
		displayRadius = visualRadius("sun", SunRadius, levelIndex), -- 490
		ring = false, -- 490
		model = "Sun", -- 490
		emissive = {r = 1, g = 0.95, b = 0.82} -- 490
	} -- 490
end -- 488
--- 出发轨道半径 = 1 AU（地球轨道）。六关共用 —— L1 的地球就在这里，L2–L6 从这里出发。
____exports.EarthOrbitRadius = trueOrbit(REAL.earth.au) -- 500
--- **1 真实秒 = 多少游戏秒**（B3，2026-09-28）。
-- 
-- 全项目只有这里读 Scale，别处（Game / Hud / init）都从这里拿 —— 于是"倍速档位"
-- 的单位可以老实写成「×现实时间」：档位 pow ⇒ 速率 = 10^pow × 本常数。
-- pow = 0 就是 1×（现实 1 秒）。
____exports.GameSecondsPerRealSecond = 1 / SecPerGameSec -- 509
--- 该点的日心圆轨速度（30.00 平面单位/秒 —— 全套尺度的速度锚点）。
____exports.EarthOrbitSpeed = circularSpeed(SunGm, ____exports.EarthOrbitRadius) -- 512
--- 相位表 —— **全部由 `node tools/level-phases.mjs <关号> --dirs 240 --dvs 31 --tmax N` 解出**，不许手填。
-- 
-- ⚠️ 同一颗行星在**不同关的相位不同**，这是对的：相位代表"哪一天的太阳系"，
--    每一关的可行发射窗口本来就不一样。物理量（gm / 半径 / 轨道 / 周期）才是六关共用、不许变的。
-- 
-- 每一行后面的注释就是它的出处（工具输出），改数值必须重跑工具。
local PH = { -- 522
	mercury = 2.18, -- 529
	venus = 37.587, -- 530
	jupiter3 = 186.1, -- 535
	jupiter4 = 184.4, -- 536
	jupiter5 = 175.6, -- 537
	jupiter6 = 175.2, -- 538
	saturn4 = 199.6, -- 540
	saturn5 = 190.8, -- 541
	saturn6 = 190.3, -- 542
	uranus5 = 202.8, -- 544
	uranus6 = 201.8, -- 545
	neptune6 = 207.6, -- 547
	moon = 202 -- 560
} -- 560
--- 街机第 1 关：地月弯道 (Moon Curve)。
-- 
-- 核心玩法：引力转弯教学，正前方碎石墙阻挡直射，利用地球引力弯折变向绕过陨石，吃 3 颗星尘进入月球靶心！
local function level1() -- 568
	local earth = { -- 569
		gm = 460000, -- 570
		radius = 42, -- 571
		orbitCenter = {x = 35, y = -15}, -- 572
		orbitRadius = 0, -- 573
		orbitPeriod = 0, -- 574
		phase0 = 0, -- 575
		orbitDirection = 1, -- 576
		name = "地球" -- 577
	} -- 577
	local asteroid = { -- 579
		gm = 0, -- 580
		radius = 32, -- 581
		orbitCenter = {x = -40, y = 5}, -- 582
		orbitRadius = 0, -- 583
		orbitPeriod = 0, -- 584
		phase0 = 0, -- 585
		orbitDirection = 1, -- 586
		isObstacle = true, -- 587
		name = "陨石障碍" -- 588
	} -- 588
	local moon = { -- 590
		gm = 40000, -- 591
		radius = 28, -- 592
		orbitCenter = {x = 140, y = 320}, -- 593
		orbitRadius = 0, -- 594
		orbitPeriod = 0, -- 595
		phase0 = 0, -- 596
		orbitDirection = 1, -- 597
		name = "月球" -- 598
	} -- 598
	return { -- 601
		id = 1, -- 602
		title = "第 1 关 · 地月弯道", -- 603
		probeVariant = "solar", -- 604
		brief = "【街机引力转弯教学】直射路线被太空碎石墙阻挡！后拉弹弓瞄准，利用地球引力弯折变向，绕过陨石并收集 3 颗金色星尘，滑入月球靶心！", -- 605
		probeStart = {x = -140, y = -340}, -- 606
		probeVel0 = {x = 0, y = 0}, -- 607
		stars = {{x = -70, y = -220}, {x = 130, y = 15}, {x = 160, y = 220}}, -- 608
		planets = {earth, asteroid, moon}, -- 613
		visuals = {{ -- 614
			r = 0.42, -- 615
			g = 0.62, -- 615
			b = 0.85, -- 615
			displayRadius = 42, -- 615
			ring = false, -- 615
			model = "Planet_Earth" -- 615
		}, { -- 615
			r = 0.7, -- 616
			g = 0.6, -- 616
			b = 0.5, -- 616
			displayRadius = 32, -- 616
			ring = false, -- 616
			model = "Asteroid_Rock" -- 616
		}, { -- 616
			r = 0.8, -- 617
			g = 0.8, -- 617
			b = 0.85, -- 617
			displayRadius = 28, -- 617
			ring = false, -- 617
			model = "Moon" -- 617
		}}, -- 617
		goal = {kind = "planet", planetIndex = 2, tolerance = 65}, -- 619
		dvBudget = 450, -- 620
		escapeRadius = 1200, -- 621
		maxSteps = 1000, -- 622
		mission = { -- 623
			id = "L1", -- 624
			codeName = "MoonCurve", -- 625
			historicalRef = "街机引力弹弓", -- 626
			subtitle = "地月弯道", -- 627
			vehicle = "flyby", -- 628
			challenges = {{desc = "成功穿过月球靶心星门", type = "success"}, {desc = "收集至少 2 颗金色星尘", type = "fuel", threshold = 0.8}, {desc = "完美收集全部 3 颗金色星尘", type = "speed", threshold = 300}} -- 629
		} -- 629
	} -- 629
end -- 568
--- L2–L6 共用的出发状态：1 AU 圆轨道上的一点，顺行（-x），速度 = 该点圆轨速度。
local function departure() -- 639
	return {pos = {x = 0, y = ____exports.EarthOrbitRadius}, vel = {x = -____exports.EarthOrbitSpeed, y = 0}} -- 640
end -- 639
--- 街机第 2 关：金星逆向漂移 (Venus Drift)。
-- 
-- 核心玩法：逆向引力减速，上方发射，下方水星靶心。中间陨石墙阻挡，必须迎头切入金星引力井反向减速并大角度转弯，平稳滑入水星靶心！
local function level2() -- 651
	local venus = { -- 652
		gm = 520000, -- 653
		radius = 40, -- 654
		orbitCenter = {x = -40, y = 40}, -- 655
		orbitRadius = 0, -- 656
		orbitPeriod = 0, -- 657
		phase0 = 0, -- 658
		orbitDirection = 1, -- 659
		name = "金星" -- 660
	} -- 660
	local asteroid = { -- 662
		gm = 0, -- 663
		radius = 35, -- 664
		orbitCenter = {x = -30, y = -100}, -- 665
		orbitRadius = 0, -- 666
		orbitPeriod = 0, -- 667
		phase0 = 0, -- 668
		orbitDirection = 1, -- 669
		isObstacle = true, -- 670
		name = "陨石障碍" -- 671
	} -- 671
	local mercury = { -- 673
		gm = 30000, -- 674
		radius = 26, -- 675
		orbitCenter = {x = -160, y = -280}, -- 676
		orbitRadius = 0, -- 677
		orbitPeriod = 0, -- 678
		phase0 = 0, -- 679
		orbitDirection = 1, -- 680
		name = "水星" -- 681
	} -- 681
	return { -- 684
		id = 2, -- 685
		title = "第 2 关 · 金星逆向漂移", -- 686
		probeVariant = "solar", -- 687
		brief = "【逆向引力减速】上方发射，下方水星靶心。碎石带封锁直落通道！向金星右侧迎面切入逆向引力井，借力减速并完成大角度转弯，进入水星狭窄靶心！", -- 688
		probeStart = {x = 30, y = 380}, -- 689
		probeVel0 = {x = 0, y = 0}, -- 690
		stars = {{x = 10, y = 200}, {x = -20, y = 30}, {x = -120, y = -160}}, -- 691
		planets = {venus, asteroid, mercury}, -- 696
		visuals = {{ -- 697
			r = 0.9, -- 698
			g = 0.78, -- 698
			b = 0.55, -- 698
			displayRadius = 40, -- 698
			ring = false, -- 698
			model = "Planet_Venus" -- 698
		}, { -- 698
			r = 0.7, -- 699
			g = 0.6, -- 699
			b = 0.5, -- 699
			displayRadius = 35, -- 699
			ring = false, -- 699
			model = "Asteroid_Rock" -- 699
		}, { -- 699
			r = 0.65, -- 700
			g = 0.65, -- 700
			b = 0.65, -- 700
			displayRadius = 26, -- 700
			ring = false, -- 700
			model = "Planet_Mercury" -- 700
		}}, -- 700
		goal = {kind = "planet", planetIndex = 2, tolerance = 65}, -- 702
		dvBudget = 450, -- 703
		escapeRadius = 1200, -- 704
		maxSteps = 1000, -- 705
		mission = { -- 706
			id = "L2", -- 707
			codeName = "VenusDrift", -- 708
			historicalRef = "街机引力弹弓", -- 709
			subtitle = "逆向减速", -- 710
			vehicle = "flyby", -- 711
			challenges = {{desc = "成功穿过水星靶心星门", type = "success"}, {desc = "收集至少 2 颗金色星尘", type = "fuel", threshold = 0.8}, {desc = "完美收集全部 3 颗金色星尘", type = "speed", threshold = 300}} -- 712
		} -- 712
	} -- 712
end -- 651
--- 街机第 3 关：双星大甩尾 (Grand Slingshot)。
-- 
-- 核心玩法：木星 90° 强力大甩尾变向将探测器抛向土星，土星二次加速飞越深空障碍墙，连续借力冲入海王星靶心星门！
local function level3() -- 726
	local jupiter = { -- 727
		gm = 550000, -- 728
		radius = 46, -- 729
		orbitCenter = {x = -90, y = -60}, -- 730
		orbitRadius = 0, -- 731
		orbitPeriod = 0, -- 732
		phase0 = 0, -- 733
		orbitDirection = 1, -- 734
		name = "木星" -- 735
	} -- 735
	local saturn = { -- 737
		gm = 480000, -- 738
		radius = 42, -- 739
		orbitCenter = {x = 70, y = 80}, -- 740
		orbitRadius = 0, -- 741
		orbitPeriod = 0, -- 742
		phase0 = 0, -- 743
		orbitDirection = 1, -- 744
		name = "土星" -- 745
	} -- 745
	local asteroid = { -- 747
		gm = 0, -- 748
		radius = 35, -- 749
		orbitCenter = {x = 40, y = -40}, -- 750
		orbitRadius = 0, -- 751
		orbitPeriod = 0, -- 752
		phase0 = 0, -- 753
		orbitDirection = 1, -- 754
		isObstacle = true, -- 755
		name = "陨石障碍" -- 756
	} -- 756
	local neptune = { -- 758
		gm = 35000, -- 759
		radius = 30, -- 760
		orbitCenter = {x = 200, y = 320}, -- 761
		orbitRadius = 0, -- 762
		orbitPeriod = 0, -- 763
		phase0 = 0, -- 764
		orbitDirection = 1, -- 765
		name = "海王星" -- 766
	} -- 766
	return { -- 769
		id = 3, -- 770
		title = "第 3 关 · 双星大甩尾", -- 771
		probeVariant = "rtg", -- 772
		brief = "【双星极限接力弹弓】木星 90° 强力甩尾变向将探测器抛向土星，土星二次加速飞越深空障碍墙，呼啸冲入海王星靶心星门！", -- 773
		probeStart = {x = -220, y = -320}, -- 774
		probeVel0 = {x = 0, y = 0}, -- 775
		stars = {{x = -130, y = -250}, {x = 130, y = 15}, {x = 230, y = 230}}, -- 776
		planets = {jupiter, saturn, asteroid, neptune}, -- 781
		visuals = {{ -- 782
			r = 0.85, -- 783
			g = 0.72, -- 783
			b = 0.5, -- 783
			displayRadius = 46, -- 783
			ring = false, -- 783
			model = "Planet_Jupiter" -- 783
		}, { -- 783
			r = 0.75, -- 784
			g = 0.7, -- 784
			b = 0.6, -- 784
			displayRadius = 42, -- 784
			ring = true, -- 784
			model = "Planet_Saturn" -- 784
		}, { -- 784
			r = 0.7, -- 785
			g = 0.6, -- 785
			b = 0.5, -- 785
			displayRadius = 35, -- 785
			ring = false, -- 785
			model = "Asteroid_Rock" -- 785
		}, { -- 785
			r = 0.34, -- 786
			g = 0.5, -- 786
			b = 0.86, -- 786
			displayRadius = 30, -- 786
			ring = false, -- 786
			model = "Planet_Neptune" -- 786
		}}, -- 786
		goal = {kind = "planet", planetIndex = 3, tolerance = 70}, -- 788
		dvBudget = 480, -- 789
		escapeRadius = 1200, -- 790
		maxSteps = 1000, -- 791
		mission = { -- 792
			id = "L3", -- 793
			codeName = "GrandSlingshot", -- 794
			historicalRef = "街机引力弹弓", -- 795
			subtitle = "双星连环甩尾", -- 796
			vehicle = "flyby", -- 797
			challenges = {{desc = "成功穿过海王星靶心星门", type = "success"}, {desc = "收集至少 2 颗金色星尘", type = "fuel", threshold = 0.8}, {desc = "完美收集全部 3 颗金色星尘", type = "speed", threshold = 300}} -- 798
		} -- 798
	} -- 798
end -- 726
local LEVELS = { -- 807
	level1(), -- 807
	level2(), -- 807
	level3() -- 807
} -- 807
--- 关卡总数。
function ____exports.levelCount() -- 810
	return #LEVELS -- 811
end -- 810
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 815
	return LEVELS[index + 1] -- 816
end -- 815
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 820
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 821
end -- 820
return ____exports -- 820