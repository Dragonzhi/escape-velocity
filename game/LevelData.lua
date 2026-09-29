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
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 508
	local out = {} -- 509
	for ____, b in ipairs(bodies) do -- 510
		out[#out + 1] = { -- 511
			gm = b.gm * gravityScale, -- 512
			radius = b.radius, -- 513
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 514
			orbitRadius = b.orbitRadius, -- 515
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 516
			phase0 = b.phase0, -- 517
			orbitDirection = b.orbitDirection, -- 518
			isObstacle = b.isObstacle, -- 519
			name = b.name, -- 520
			host = b.host ~= nil and applyScalesLocal({b.host}, gravityScale, orbitScale)[1] or nil -- 522
		} -- 522
	end -- 522
	return out -- 525
end -- 525
--- **1 真实秒 = 多少游戏秒**。
-- 街机三关的关卡 JSON 用的是屏幕单位，但倍速档位仍读这个换算（pow 0 = 现实 1 秒）。
-- 街机节奏不靠它：每关的 speedDefaultPow 在 Tuning 里另给。
____exports.GameSecondsPerRealSecond = 1 / SecPerGameSec -- 59
--- 评价一局飞行的火箭星级及逐条达成详情（纯函数）。
function ____exports.evaluateRocketsDetailed(level, result, burnDv, extra) -- 239
	local achieved = {false, false, false} -- 251
	if level.transfer ~= nil then -- 251
		achieved[1] = result == "success" -- 253
		return {rockets = achieved[1] and 1 or 0, achieved = achieved, burnDv = burnDv, stats = extra ~= nil and extra or ({})} -- 254
	end -- 254
	if result ~= "success" then -- 254
		return {rockets = 0, achieved = achieved, burnDv = burnDv, stats = extra ~= nil and extra or ({})} -- 257
	end -- 257
	achieved[1] = true -- 265
	local count = 1 -- 266
	local challenges = level.mission ~= nil and level.mission.challenges or nil -- 267
	if challenges ~= nil then -- 267
		local c2 = challenges[2] -- 270
		if c2.type == "stars" and c2.threshold ~= nil then -- 270
			if extra ~= nil and extra.starsCollected ~= nil and extra.starsCollected >= c2.threshold then -- 270
				achieved[2] = true -- 273
				count = count + 1 -- 274
			end -- 274
		elseif c2.type == "fuel" and c2.threshold ~= nil then -- 274
			if burnDv <= level.dvBudget * c2.threshold then -- 274
				achieved[2] = true -- 278
				count = count + 1 -- 279
			end -- 279
		elseif burnDv <= level.dvBudget * 0.8 then -- 279
			achieved[2] = true -- 282
			count = count + 1 -- 283
		end -- 283
		local c3 = challenges[3] -- 287
		if c3.type == "distance" and c3.threshold ~= nil then -- 287
			if extra ~= nil and extra.closestDist ~= nil and extra.closestDist <= c3.threshold then -- 287
				achieved[3] = true -- 290
				count = count + 1 -- 291
			end -- 291
		elseif c3.type == "speed" and c3.threshold ~= nil then -- 291
			if extra ~= nil and extra.maxSpeed ~= nil and extra.maxSpeed >= c3.threshold then -- 291
				achieved[3] = true -- 295
				count = count + 1 -- 296
			end -- 296
		elseif c3.type == "eccentricity" and c3.threshold ~= nil then -- 296
			if extra ~= nil and extra.eccentricity ~= nil and extra.eccentricity <= c3.threshold then -- 296
				achieved[3] = true -- 300
				count = count + 1 -- 301
			end -- 301
		elseif c3.type == "stars" and c3.threshold ~= nil then -- 301
			if extra ~= nil and extra.starsCollected ~= nil and extra.starsCollected >= c3.threshold then -- 301
				achieved[3] = true -- 305
				count = count + 1 -- 306
			end -- 306
		elseif count == 2 and burnDv <= level.dvBudget * 0.5 then -- 306
			achieved[3] = true -- 309
			count = count + 1 -- 310
		end -- 310
	end -- 310
	return { -- 314
		rockets = math.min( -- 315
			3, -- 315
			math.max(0, count) -- 315
		), -- 315
		achieved = achieved, -- 316
		burnDv = burnDv, -- 317
		stats = extra ~= nil and extra or ({}) -- 318
	} -- 318
end -- 239
--- 评价一局飞行的火箭星级（0 ~ 3 枚火箭，纯函数）。
function ____exports.evaluateRockets(level, result, burnDv, extra) -- 325
	return ____exports.evaluateRocketsDetailed(level, result, burnDv, extra).rockets -- 336
end -- 325
--- 导出名与旧版一致（外部调用方按这个名字找）。
function ____exports.bodyVelocityAt(b, t) -- 348
	if b.orbitPeriod == 0 or b.orbitRadius <= 0 then -- 348
		return {x = 0, y = 0} -- 349
	end -- 349
	local angle = b.phase0 + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 350
	local w = b.orbitDirection * 2 * math.pi / b.orbitPeriod -- 351
	return { -- 352
		x = -math.sin(angle) * b.orbitRadius * w, -- 352
		y = math.cos(angle) * b.orbitRadius * w -- 352
	} -- 352
end -- 348
--- 航点列表（链式目标取 chain，否则就是唯一目标）。
function ____exports.goalWaypoints(goal) -- 356
	if goal.chain ~= nil then -- 356
		return goal.chain -- 357
	end -- 357
	if goal.kind == "planet" then -- 357
		return {{planetIndex = goal.planetIndex, tolerance = goal.tolerance, offset = goal.offset}} -- 358
	end -- 358
	return {} -- 359
end -- 356
--- 空域目标随天体公转：offset.x 径向，offset.y 沿公转切向。
function ____exports.goalPositionAt(body, t, offset) -- 363
	local p = bodyPositionAt(body, t) -- 364
	if offset == nil then -- 364
		return p -- 365
	end -- 365
	local center = body.host ~= nil and bodyPositionAt(body.host, t) or body.orbitCenter -- 366
	local dx = p.x - center.x -- 367
	local dy = p.y - center.y -- 368
	local r = math.sqrt(dx * dx + dy * dy) -- 369
	local ux = r > 0 and dx / r or 1 -- 370
	local uy = r > 0 and dy / r or 0 -- 371
	return {x = p.x + ux * offset.x - uy * offset.y * body.orbitDirection, y = p.y + uy * offset.x + ux * offset.y * body.orbitDirection} -- 372
end -- 363
--- 采样点 i 处、相对某天体的速度（捕获判据与诊断共用同一份实现）。
-- 
-- points 里只有位置 ⇒ 用相邻采样点差分；`dt` 是**相邻采样点之间的有效步长**。
-- `limit` 是最后一个有效采样点索引（末端夹紧用）。
function ____exports.relativeSpeedAt(points, i, body, dt, t0, limit, velocities) -- 382
	local vx = 0 -- 383
	local vy = 0 -- 384
	if velocities ~= nil and velocities[i + 1] ~= nil then -- 384
		vx = velocities[i + 1].x -- 387
		vy = velocities[i + 1].y -- 388
	else -- 388
		local j1 = i + 1 <= limit and i + 1 or i -- 392
		local j0 = i > 0 and i - 1 or i -- 393
		local spanT = (j1 - j0) * dt -- 394
		if spanT > 0 then -- 394
			vx = (points[j1 + 1].x - points[j0 + 1].x) / spanT -- 396
			vy = (points[j1 + 1].y - points[j0 + 1].y) / spanT -- 397
		end -- 397
	end -- 397
	local pv = ____exports.bodyVelocityAt(body, t0) -- 400
	local rx = vx - pv.x -- 401
	local ry = vy - pv.y -- 402
	return math.sqrt(rx * rx + ry * ry) -- 403
end -- 382
--- 捕获阈值：该处逃逸速度（圆轨道速度 × 系数 k，k 默认 √2）。
function ____exports.captureThreshold(body, d, k) -- 407
	if body.gm <= 0 or d <= 0.000001 then -- 407
		return 1000000000 -- 408
	end -- 408
	return k * math.sqrt(body.gm / d) -- 409
end -- 407
--- 顺序航线的进度：返回在 points[0..upto] 里**依次**掠过的航点数与最后一个命中索引。
-- 
-- 一次线性扫描：航点必须按顺序命中，且后一个必须出现在更晚的采样点上
-- （"先到土星再路过木星"不算数）。upto 用于飞行中查询"到哪一段了"（画环的明暗）。
function ____exports.waypointProgress(points, bodies, goal, dt, t0, upto, velocities) -- 418
	local wps = ____exports.goalWaypoints(goal) -- 427
	local start = t0 ~= nil and t0 or 0 -- 428
	local limit = #points - 1 -- 429
	if upto ~= nil and upto >= 0 and upto < limit then -- 429
		limit = upto -- 430
	end -- 430
	local next = 0 -- 431
	local lastIndex = -1 -- 432
	do -- 432
		local i = 0 -- 433
		while i <= limit and next < #wps do -- 433
			do -- 433
				local w = wps[next + 1] -- 434
				local body = bodies[w.planetIndex + 1] -- 435
				if body == nil then -- 435
					return {passed = 0, lastIndex = -1} -- 436
				end -- 436
				local gp = ____exports.goalPositionAt(body, start + i * dt, w.offset) -- 437
				if distance(points[i + 1], gp) < w.tolerance then -- 437
					if w.capture == true then -- 437
						local k = w.captureFactor ~= nil and w.captureFactor or 1.4142135623730951 -- 442
						local d = distance(points[i + 1], gp) -- 443
						if d <= body.radius then -- 443
							goto __continue37 -- 446
						end -- 446
						local rel = ____exports.relativeSpeedAt( -- 447
							points, -- 447
							i, -- 447
							body, -- 447
							dt, -- 447
							start + i * dt, -- 447
							limit, -- 447
							velocities -- 447
						) -- 447
						if rel > ____exports.captureThreshold(body, d, k) then -- 447
							goto __continue37 -- 448
						end -- 448
					end -- 448
					next = next + 1 -- 450
					lastIndex = i -- 451
				end -- 451
			end -- 451
			::__continue37:: -- 451
			i = i + 1 -- 433
		end -- 433
	end -- 433
	return {passed = next, lastIndex = lastIndex} -- 454
end -- 418
--- 到达目标的采样点索引；没到返回 -1。
function ____exports.findGoalIndex(points, bodies, goal, dt, t0, velocities) -- 458
	local wps = ____exports.goalWaypoints(goal) -- 459
	if #wps == 0 then -- 459
		return -1 -- 460
	end -- 460
	local st = ____exports.waypointProgress( -- 461
		points, -- 461
		bodies, -- 461
		goal, -- 461
		dt, -- 461
		t0, -- 461
		nil, -- 461
		velocities -- 461
	) -- 461
	return st.passed >= #wps and st.lastIndex or -1 -- 462
end -- 458
--- 三关由 `Assets/Levels/*.json` 装配（见文件末尾的 `installArcadeLevels`）。
-- 没装上之前是空的：入口会停在 FATAL，而不是悄悄退回旧的静态坐标。
local LEVELS = {} -- 470
--- 与 LEVELS 一一对应的星尘轨道（按 t 求位置）。
local STAR_ORBITS = {} -- 472
--- 关卡总数。
function ____exports.levelCount() -- 475
	return #LEVELS -- 476
end -- 475
--- 这一关的星尘轨道。没有（或还没装配）返回空数组。
function ____exports.starOrbits(index) -- 480
	local row = STAR_ORBITS[index + 1] -- 481
	return row ~= nil and row or ({}) -- 482
end -- 480
--- 用两份 JSON 文本替换关卡表。
-- 解析失败或没有任何关时**保持原表不动**，返回 false。
function ____exports.installArcadeLevels(levelsText, bodiesText, decode) -- 489
	local loaded = loadArcadeLevels(levelsText, bodiesText, decode) -- 490
	if #loaded.levels == 0 then -- 490
		return false -- 491
	end -- 491
	LEVELS = loaded.levels -- 492
	STAR_ORBITS = loaded.starOrbits -- 493
	return true -- 494
end -- 489
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 498
	return LEVELS[index + 1] -- 499
end -- 498
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 503
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 504
end -- 503
return ____exports -- 503