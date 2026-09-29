-- [ts]: LevelData.ts
local ____exports = {} -- 1
local applyScalesLocal -- 1
local ____Gravity = require("game.Gravity") -- 48
local bodyPositionAt = ____Gravity.bodyPositionAt -- 48
local distance = ____Gravity.distance -- 48
local ____LevelLoader = require("game.LevelLoader") -- 49
local loadArcadeLevels = ____LevelLoader.loadArcadeLevels -- 49
local ____Config = require("game.Config") -- 51
local GravityScale = ____Config.GravityScale -- 51
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 51
local ____Scale = require("game.Scale") -- 52
local SecPerGameSec = ____Scale.SecPerGameSec -- 52
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 511
	local out = {} -- 512
	for ____, b in ipairs(bodies) do -- 513
		out[#out + 1] = { -- 514
			gm = b.gm * gravityScale, -- 515
			radius = b.radius, -- 516
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 517
			orbitRadius = b.orbitRadius, -- 518
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 519
			phase0 = b.phase0, -- 520
			orbitDirection = b.orbitDirection, -- 521
			isObstacle = b.isObstacle, -- 522
			name = b.name, -- 523
			host = b.host ~= nil and applyScalesLocal({b.host}, gravityScale, orbitScale)[1] or nil -- 525
		} -- 525
	end -- 525
	return out -- 528
end -- 528
--- **1 真实秒 = 多少游戏秒**。
-- 街机三关的关卡 JSON 用的是屏幕单位，但倍速档位仍读这个换算（pow 0 = 现实 1 秒）。
-- 街机节奏不靠它：每关的 speedDefaultPow 在 Tuning 里另给。
____exports.GameSecondsPerRealSecond = 1 / SecPerGameSec -- 59
--- 评价一局飞行的火箭星级及逐条达成详情（纯函数）。
function ____exports.evaluateRocketsDetailed(level, result, burnDv, extra) -- 241
	local achieved = {false, false, false} -- 253
	if level.transfer ~= nil then -- 253
		achieved[1] = result == "success" -- 255
		return {rockets = achieved[1] and 1 or 0, achieved = achieved, burnDv = burnDv, stats = extra ~= nil and extra or ({})} -- 256
	end -- 256
	if result ~= "success" then -- 256
		return {rockets = 0, achieved = achieved, burnDv = burnDv, stats = extra ~= nil and extra or ({})} -- 259
	end -- 259
	achieved[1] = true -- 267
	local count = 1 -- 268
	local challenges = level.mission ~= nil and level.mission.challenges or nil -- 269
	if challenges ~= nil then -- 269
		local c2 = challenges[2] -- 272
		if c2.type == "stars" and c2.threshold ~= nil then -- 272
			if extra ~= nil and extra.starsCollected ~= nil and extra.starsCollected >= c2.threshold then -- 272
				achieved[2] = true -- 275
				count = count + 1 -- 276
			end -- 276
		elseif c2.type == "fuel" and c2.threshold ~= nil then -- 276
			if burnDv <= level.dvBudget * c2.threshold then -- 276
				achieved[2] = true -- 280
				count = count + 1 -- 281
			end -- 281
		elseif burnDv <= level.dvBudget * 0.8 then -- 281
			achieved[2] = true -- 284
			count = count + 1 -- 285
		end -- 285
		local c3 = challenges[3] -- 289
		if c3.type == "distance" and c3.threshold ~= nil then -- 289
			if extra ~= nil and extra.closestDist ~= nil and extra.closestDist <= c3.threshold then -- 289
				achieved[3] = true -- 292
				count = count + 1 -- 293
			end -- 293
		elseif c3.type == "speed" and c3.threshold ~= nil then -- 293
			if extra ~= nil and extra.maxSpeed ~= nil and extra.maxSpeed >= c3.threshold then -- 293
				achieved[3] = true -- 297
				count = count + 1 -- 298
			end -- 298
		elseif c3.type == "eccentricity" and c3.threshold ~= nil then -- 298
			if extra ~= nil and extra.eccentricity ~= nil and extra.eccentricity <= c3.threshold then -- 298
				achieved[3] = true -- 302
				count = count + 1 -- 303
			end -- 303
		elseif c3.type == "stars" and c3.threshold ~= nil then -- 303
			if extra ~= nil and extra.starsCollected ~= nil and extra.starsCollected >= c3.threshold then -- 303
				achieved[3] = true -- 307
				count = count + 1 -- 308
			end -- 308
		elseif count == 2 and burnDv <= level.dvBudget * 0.5 then -- 308
			achieved[3] = true -- 311
			count = count + 1 -- 312
		end -- 312
	end -- 312
	return { -- 316
		rockets = math.min( -- 317
			3, -- 317
			math.max(0, count) -- 317
		), -- 317
		achieved = achieved, -- 318
		burnDv = burnDv, -- 319
		stats = extra ~= nil and extra or ({}) -- 320
	} -- 320
end -- 241
--- 评价一局飞行的火箭星级（0 ~ 3 枚火箭，纯函数）。
function ____exports.evaluateRockets(level, result, burnDv, extra) -- 327
	return ____exports.evaluateRocketsDetailed(level, result, burnDv, extra).rockets -- 338
end -- 327
--- 导出名与旧版一致（外部调用方按这个名字找）。
function ____exports.bodyVelocityAt(b, t) -- 350
	if b.orbitPeriod == 0 or b.orbitRadius <= 0 then -- 350
		return {x = 0, y = 0} -- 351
	end -- 351
	local angle = b.phase0 + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 352
	local w = b.orbitDirection * 2 * math.pi / b.orbitPeriod -- 353
	return { -- 354
		x = -math.sin(angle) * b.orbitRadius * w, -- 354
		y = math.cos(angle) * b.orbitRadius * w -- 354
	} -- 354
end -- 350
--- 航点列表（链式目标取 chain，否则就是唯一目标）。
function ____exports.goalWaypoints(goal) -- 358
	if goal.chain ~= nil then -- 358
		return goal.chain -- 359
	end -- 359
	if goal.kind == "planet" then -- 359
		return {{planetIndex = goal.planetIndex, tolerance = goal.tolerance, offset = goal.offset}} -- 360
	end -- 360
	return {} -- 361
end -- 358
--- 空域目标随天体公转：offset.x 径向，offset.y 沿公转切向。
function ____exports.goalPositionAt(body, t, offset) -- 365
	local p = bodyPositionAt(body, t) -- 366
	if offset == nil then -- 366
		return p -- 367
	end -- 367
	local center = body.host ~= nil and bodyPositionAt(body.host, t) or body.orbitCenter -- 368
	local dx = p.x - center.x -- 369
	local dy = p.y - center.y -- 370
	local r = math.sqrt(dx * dx + dy * dy) -- 371
	local ux = r > 0 and dx / r or 1 -- 372
	local uy = r > 0 and dy / r or 0 -- 373
	return {x = p.x + ux * offset.x - uy * offset.y * body.orbitDirection, y = p.y + uy * offset.x + ux * offset.y * body.orbitDirection} -- 374
end -- 365
--- 采样点 i 处、相对某天体的速度（捕获判据与诊断共用同一份实现）。
-- 
-- points 里只有位置 ⇒ 用相邻采样点差分；`dt` 是**相邻采样点之间的有效步长**。
-- `limit` 是最后一个有效采样点索引（末端夹紧用）。
function ____exports.relativeSpeedAt(points, i, body, dt, t0, limit, velocities) -- 384
	local vx = 0 -- 385
	local vy = 0 -- 386
	if velocities ~= nil and velocities[i + 1] ~= nil then -- 386
		vx = velocities[i + 1].x -- 389
		vy = velocities[i + 1].y -- 390
	else -- 390
		local j1 = i + 1 <= limit and i + 1 or i -- 394
		local j0 = i > 0 and i - 1 or i -- 395
		local spanT = (j1 - j0) * dt -- 396
		if spanT > 0 then -- 396
			vx = (points[j1 + 1].x - points[j0 + 1].x) / spanT -- 398
			vy = (points[j1 + 1].y - points[j0 + 1].y) / spanT -- 399
		end -- 399
	end -- 399
	local pv = ____exports.bodyVelocityAt(body, t0) -- 402
	local rx = vx - pv.x -- 403
	local ry = vy - pv.y -- 404
	return math.sqrt(rx * rx + ry * ry) -- 405
end -- 384
--- 捕获阈值：该处逃逸速度（圆轨道速度 × 系数 k，k 默认 √2）。
function ____exports.captureThreshold(body, d, k) -- 409
	if body.gm <= 0 or d <= 0.000001 then -- 409
		return 1000000000 -- 410
	end -- 410
	return k * math.sqrt(body.gm / d) -- 411
end -- 409
--- 顺序航线的进度：返回在 points[0..upto] 里**依次**掠过的航点数与最后一个命中索引。
-- 
-- 一次线性扫描：航点必须按顺序命中，且后一个必须出现在更晚的采样点上
-- （"先到土星再路过木星"不算数）。upto 用于飞行中查询"到哪一段了"（画环的明暗）。
function ____exports.waypointProgress(points, bodies, goal, dt, t0, upto, velocities) -- 420
	local wps = ____exports.goalWaypoints(goal) -- 429
	local start = t0 ~= nil and t0 or 0 -- 430
	local limit = #points - 1 -- 431
	if upto ~= nil and upto >= 0 and upto < limit then -- 431
		limit = upto -- 432
	end -- 432
	local next = 0 -- 433
	local lastIndex = -1 -- 434
	do -- 434
		local i = 0 -- 435
		while i <= limit and next < #wps do -- 435
			do -- 435
				local w = wps[next + 1] -- 436
				local body = bodies[w.planetIndex + 1] -- 437
				if body == nil then -- 437
					return {passed = 0, lastIndex = -1} -- 438
				end -- 438
				local gp = ____exports.goalPositionAt(body, start + i * dt, w.offset) -- 439
				if distance(points[i + 1], gp) < w.tolerance then -- 439
					if w.capture == true then -- 439
						local k = w.captureFactor ~= nil and w.captureFactor or 1.4142135623730951 -- 444
						local d = distance(points[i + 1], gp) -- 445
						if d <= body.radius then -- 445
							goto __continue37 -- 448
						end -- 448
						local rel = ____exports.relativeSpeedAt( -- 449
							points, -- 449
							i, -- 449
							body, -- 449
							dt, -- 449
							start + i * dt, -- 449
							limit, -- 449
							velocities -- 449
						) -- 449
						if rel > ____exports.captureThreshold(body, d, k) then -- 449
							goto __continue37 -- 450
						end -- 450
					end -- 450
					next = next + 1 -- 452
					lastIndex = i -- 453
				end -- 453
			end -- 453
			::__continue37:: -- 453
			i = i + 1 -- 435
		end -- 435
	end -- 435
	return {passed = next, lastIndex = lastIndex} -- 456
end -- 420
--- 到达目标的采样点索引；没到返回 -1。
function ____exports.findGoalIndex(points, bodies, goal, dt, t0, velocities) -- 460
	if goal.marker ~= nil then -- 460
		return -1 -- 461
	end -- 461
	local wps = ____exports.goalWaypoints(goal) -- 462
	if #wps == 0 then -- 462
		return -1 -- 463
	end -- 463
	local st = ____exports.waypointProgress( -- 464
		points, -- 464
		bodies, -- 464
		goal, -- 464
		dt, -- 464
		t0, -- 464
		nil, -- 464
		velocities -- 464
	) -- 464
	return st.passed >= #wps and st.lastIndex or -1 -- 465
end -- 460
--- 三关由 `Assets/Levels/*.json` 装配（见文件末尾的 `installArcadeLevels`）。
-- 没装上之前是空的：入口会停在 FATAL，而不是悄悄退回旧的静态坐标。
local LEVELS = {} -- 473
--- 与 LEVELS 一一对应的星尘轨道（按 t 求位置）。
local STAR_ORBITS = {} -- 475
--- 关卡总数。
function ____exports.levelCount() -- 478
	return #LEVELS -- 479
end -- 478
--- 这一关的星尘轨道。没有（或还没装配）返回空数组。
function ____exports.starOrbits(index) -- 483
	local row = STAR_ORBITS[index + 1] -- 484
	return row ~= nil and row or ({}) -- 485
end -- 483
--- 用两份 JSON 文本替换关卡表。
-- 解析失败或没有任何关时**保持原表不动**，返回 false。
function ____exports.installArcadeLevels(levelsText, bodiesText, decode) -- 492
	local loaded = loadArcadeLevels(levelsText, bodiesText, decode) -- 493
	if #loaded.levels == 0 then -- 493
		return false -- 494
	end -- 494
	LEVELS = loaded.levels -- 495
	STAR_ORBITS = loaded.starOrbits -- 496
	return true -- 497
end -- 492
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 501
	return LEVELS[index + 1] -- 502
end -- 501
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 506
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 507
end -- 506
return ____exports -- 506