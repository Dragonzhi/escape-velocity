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
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 484
	local out = {} -- 485
	for ____, b in ipairs(bodies) do -- 486
		out[#out + 1] = { -- 487
			gm = b.gm * gravityScale, -- 488
			radius = b.radius, -- 489
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 490
			orbitRadius = b.orbitRadius, -- 491
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 492
			phase0 = b.phase0, -- 493
			orbitDirection = b.orbitDirection, -- 494
			isObstacle = b.isObstacle, -- 495
			name = b.name, -- 496
			host = b.host ~= nil and applyScalesLocal({b.host}, gravityScale, orbitScale)[1] or nil -- 498
		} -- 498
	end -- 498
	return out -- 501
end -- 501
--- **1 真实秒 = 多少游戏秒**。
-- 街机三关的关卡 JSON 用的是屏幕单位，但倍速档位仍读这个换算（pow 0 = 现实 1 秒）。
-- 街机节奏不靠它：每关的 speedDefaultPow 在 Tuning 里另给。
____exports.GameSecondsPerRealSecond = 1 / SecPerGameSec -- 59
--- 评价一局飞行的火箭星级及逐条达成详情（纯函数）。
function ____exports.evaluateRocketsDetailed(level, result, burnDv, extra) -- 231
	local achieved = {false, false, false} -- 243
	if level.transfer ~= nil then -- 243
		achieved[1] = result == "success" -- 245
		return {rockets = achieved[1] and 1 or 0, achieved = achieved, burnDv = burnDv, stats = extra ~= nil and extra or ({})} -- 246
	end -- 246
	if result ~= "success" then -- 246
		return {rockets = 0, achieved = achieved, burnDv = burnDv, stats = extra ~= nil and extra or ({})} -- 249
	end -- 249
	achieved[1] = true -- 257
	local count = 1 -- 258
	local challenges = level.mission ~= nil and level.mission.challenges or nil -- 259
	if challenges ~= nil then -- 259
		local c2 = challenges[2] -- 262
		if c2.type == "stars" and c2.threshold ~= nil then -- 262
			if extra ~= nil and extra.starsCollected ~= nil and extra.starsCollected >= c2.threshold then -- 262
				achieved[2] = true -- 265
				count = count + 1 -- 266
			end -- 266
		elseif c2.type == "fuel" and c2.threshold ~= nil then -- 266
			if burnDv <= level.dvBudget * c2.threshold then -- 266
				achieved[2] = true -- 270
				count = count + 1 -- 271
			end -- 271
		elseif burnDv <= level.dvBudget * 0.8 then -- 271
			achieved[2] = true -- 274
			count = count + 1 -- 275
		end -- 275
		local c3 = challenges[3] -- 279
		if c3.type == "distance" and c3.threshold ~= nil then -- 279
			if extra ~= nil and extra.closestDist ~= nil and extra.closestDist <= c3.threshold then -- 279
				achieved[3] = true -- 282
				count = count + 1 -- 283
			end -- 283
		elseif c3.type == "speed" and c3.threshold ~= nil then -- 283
			if extra ~= nil and extra.maxSpeed ~= nil and extra.maxSpeed >= c3.threshold then -- 283
				achieved[3] = true -- 287
				count = count + 1 -- 288
			end -- 288
		elseif c3.type == "eccentricity" and c3.threshold ~= nil then -- 288
			if extra ~= nil and extra.eccentricity ~= nil and extra.eccentricity <= c3.threshold then -- 288
				achieved[3] = true -- 292
				count = count + 1 -- 293
			end -- 293
		elseif c3.type == "stars" and c3.threshold ~= nil then -- 293
			if extra ~= nil and extra.starsCollected ~= nil and extra.starsCollected >= c3.threshold then -- 293
				achieved[3] = true -- 297
				count = count + 1 -- 298
			end -- 298
		elseif count == 2 and burnDv <= level.dvBudget * 0.5 then -- 298
			achieved[3] = true -- 301
			count = count + 1 -- 302
		end -- 302
	end -- 302
	return { -- 306
		rockets = math.min( -- 307
			3, -- 307
			math.max(0, count) -- 307
		), -- 307
		achieved = achieved, -- 308
		burnDv = burnDv, -- 309
		stats = extra ~= nil and extra or ({}) -- 310
	} -- 310
end -- 231
--- 评价一局飞行的火箭星级（0 ~ 3 枚火箭，纯函数）。
function ____exports.evaluateRockets(level, result, burnDv, extra) -- 317
	return ____exports.evaluateRocketsDetailed(level, result, burnDv, extra).rockets -- 328
end -- 317
--- 导出名与旧版一致（外部调用方按这个名字找）。
function ____exports.bodyVelocityAt(b, t) -- 340
	if b.orbitPeriod == 0 or b.orbitRadius <= 0 then -- 340
		return {x = 0, y = 0} -- 341
	end -- 341
	local angle = b.phase0 + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 342
	local w = b.orbitDirection * 2 * math.pi / b.orbitPeriod -- 343
	return { -- 344
		x = -math.sin(angle) * b.orbitRadius * w, -- 344
		y = math.cos(angle) * b.orbitRadius * w -- 344
	} -- 344
end -- 340
--- 航点列表（链式目标取 chain，否则就是唯一目标）。
function ____exports.goalWaypoints(goal) -- 348
	if goal.chain ~= nil then -- 348
		return goal.chain -- 349
	end -- 349
	if goal.kind == "planet" then -- 349
		return {{planetIndex = goal.planetIndex, tolerance = goal.tolerance, offset = goal.offset}} -- 350
	end -- 350
	return {} -- 351
end -- 348
--- 空域目标随天体公转：offset.x 径向，offset.y 沿公转切向。
function ____exports.goalPositionAt(body, t, offset) -- 355
	local p = bodyPositionAt(body, t) -- 356
	if offset == nil then -- 356
		return p -- 357
	end -- 357
	local center = body.host ~= nil and bodyPositionAt(body.host, t) or body.orbitCenter -- 358
	local dx = p.x - center.x -- 359
	local dy = p.y - center.y -- 360
	local r = math.sqrt(dx * dx + dy * dy) -- 361
	local ux = r > 0 and dx / r or 1 -- 362
	local uy = r > 0 and dy / r or 0 -- 363
	return {x = p.x + ux * offset.x - uy * offset.y * body.orbitDirection, y = p.y + uy * offset.x + ux * offset.y * body.orbitDirection} -- 364
end -- 355
--- 采样点 i 处、相对某天体的速度（捕获判据与诊断共用同一份实现）。
-- 
-- points 里只有位置 ⇒ 用相邻采样点差分；`dt` 是**相邻采样点之间的有效步长**。
-- `limit` 是最后一个有效采样点索引（末端夹紧用）。
function ____exports.relativeSpeedAt(points, i, body, dt, t0, limit, velocities) -- 374
	local vx = 0 -- 375
	local vy = 0 -- 376
	if velocities ~= nil and velocities[i + 1] ~= nil then -- 376
		vx = velocities[i + 1].x -- 379
		vy = velocities[i + 1].y -- 380
	else -- 380
		local j1 = i + 1 <= limit and i + 1 or i -- 384
		local j0 = i > 0 and i - 1 or i -- 385
		local spanT = (j1 - j0) * dt -- 386
		if spanT > 0 then -- 386
			vx = (points[j1 + 1].x - points[j0 + 1].x) / spanT -- 388
			vy = (points[j1 + 1].y - points[j0 + 1].y) / spanT -- 389
		end -- 389
	end -- 389
	local pv = ____exports.bodyVelocityAt(body, t0) -- 392
	local rx = vx - pv.x -- 393
	local ry = vy - pv.y -- 394
	return math.sqrt(rx * rx + ry * ry) -- 395
end -- 374
--- 顺序航线的进度：返回在 points[0..upto] 里**依次**掠过的航点数与最后一个命中索引。
-- 
-- 一次线性扫描：航点必须按顺序命中，且后一个必须出现在更晚的采样点上
-- （"先到土星再路过木星"不算数）。upto 用于飞行中查询"到哪一段了"（画环的明暗）。
function ____exports.waypointProgress(points, bodies, goal, dt, t0, upto, velocities) -- 404
	local wps = ____exports.goalWaypoints(goal) -- 413
	local start = t0 ~= nil and t0 or 0 -- 414
	local limit = #points - 1 -- 415
	if upto ~= nil and upto >= 0 and upto < limit then -- 415
		limit = upto -- 416
	end -- 416
	local next = 0 -- 417
	local lastIndex = -1 -- 418
	do -- 418
		local i = 0 -- 419
		while i <= limit and next < #wps do -- 419
			local w = wps[next + 1] -- 420
			local body = bodies[w.planetIndex + 1] -- 421
			if body == nil then -- 421
				return {passed = 0, lastIndex = -1} -- 422
			end -- 422
			local gp = ____exports.goalPositionAt(body, start + i * dt, w.offset) -- 423
			if distance(points[i + 1], gp) < w.tolerance then -- 423
				next = next + 1 -- 425
				lastIndex = i -- 426
			end -- 426
			i = i + 1 -- 419
		end -- 419
	end -- 419
	return {passed = next, lastIndex = lastIndex} -- 429
end -- 404
--- 到达目标的采样点索引；没到返回 -1。
function ____exports.findGoalIndex(points, bodies, goal, dt, t0, velocities) -- 433
	if goal.marker ~= nil then -- 433
		return -1 -- 434
	end -- 434
	local wps = ____exports.goalWaypoints(goal) -- 435
	if #wps == 0 then -- 435
		return -1 -- 436
	end -- 436
	local st = ____exports.waypointProgress( -- 437
		points, -- 437
		bodies, -- 437
		goal, -- 437
		dt, -- 437
		t0, -- 437
		nil, -- 437
		velocities -- 437
	) -- 437
	return st.passed >= #wps and st.lastIndex or -1 -- 438
end -- 433
--- 三关由 `Assets/Levels/*.json` 装配（见文件末尾的 `installArcadeLevels`）。
-- 没装上之前是空的：入口会停在 FATAL，而不是悄悄退回旧的静态坐标。
local LEVELS = {} -- 446
--- 与 LEVELS 一一对应的星尘轨道（按 t 求位置）。
local STAR_ORBITS = {} -- 448
--- 关卡总数。
function ____exports.levelCount() -- 451
	return #LEVELS -- 452
end -- 451
--- 这一关的星尘轨道。没有（或还没装配）返回空数组。
function ____exports.starOrbits(index) -- 456
	local row = STAR_ORBITS[index + 1] -- 457
	return row ~= nil and row or ({}) -- 458
end -- 456
--- 用两份 JSON 文本替换关卡表。
-- 解析失败或没有任何关时**保持原表不动**，返回 false。
function ____exports.installArcadeLevels(levelsText, bodiesText, decode) -- 465
	local loaded = loadArcadeLevels(levelsText, bodiesText, decode) -- 466
	if #loaded.levels == 0 then -- 466
		return false -- 467
	end -- 467
	LEVELS = loaded.levels -- 468
	STAR_ORBITS = loaded.starOrbits -- 469
	return true -- 470
end -- 465
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 474
	return LEVELS[index + 1] -- 475
end -- 474
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 479
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 480
end -- 479
return ____exports -- 479