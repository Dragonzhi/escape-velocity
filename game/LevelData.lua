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
--- 导出名与旧版一致（外部调用方按这个名字找）。
function ____exports.bodyVelocityAt(b, t) -- 345
	if b.orbitPeriod == 0 or b.orbitRadius <= 0 then -- 345
		return {x = 0, y = 0} -- 346
	end -- 346
	local angle = b.phase0 + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 347
	local w = b.orbitDirection * 2 * math.pi / b.orbitPeriod -- 348
	return { -- 349
		x = -math.sin(angle) * b.orbitRadius * w, -- 349
		y = math.cos(angle) * b.orbitRadius * w -- 349
	} -- 349
end -- 345
--- 固定步长轨迹首次进入目标高度环；使用线段距离覆盖两采样间的薄环。
function ____exports.findGoalRegionIndex(points, velocities, bodies, region, dt, t0) -- 448
	local body = bodies[region.bodyIndex + 1] -- 449
	if body == nil then -- 449
		return -1 -- 450
	end -- 450
	local inner = body.radius + region.minAltitude -- 451
	local outer = body.radius + region.maxAltitude -- 452
	do -- 452
		local i = 0 -- 453
		while i < #points do -- 453
			do -- 453
				local p = points[i + 1] -- 454
				local c = bodyPositionAt(body, t0 + i * dt) -- 455
				local dx = p.x - c.x -- 456
				local dy = p.y - c.y -- 456
				local r = math.sqrt(dx * dx + dy * dy) -- 457
				if r < inner or r > outer then -- 457
					goto __continue45 -- 458
				end -- 458
				if region.direction == "outward" and i > 0 then -- 458
					local prev = points[i] -- 460
					local pc = bodyPositionAt(body, t0 + (i - 1) * dt) -- 460
					if r < math.sqrt((prev.x - pc.x) * (prev.x - pc.x) + (prev.y - pc.y) * (prev.y - pc.y)) then -- 460
						goto __continue45 -- 461
					end -- 461
				end -- 461
				if region.direction == "inward" and i > 0 then -- 461
					local prev = points[i] -- 464
					local pc = bodyPositionAt(body, t0 + (i - 1) * dt) -- 464
					if r > math.sqrt((prev.x - pc.x) * (prev.x - pc.x) + (prev.y - pc.y) * (prev.y - pc.y)) then -- 464
						goto __continue45 -- 465
					end -- 465
				end -- 465
				if region.requiresEscape then -- 465
					local v = velocities ~= nil and velocities[i + 1] or nil -- 468
					if v == nil or body.gm <= 0 then -- 468
						goto __continue45 -- 469
					end -- 469
					local bv = ____exports.bodyVelocityAt(body, t0 + i * dt) -- 470
					local vx = v.x - bv.x -- 471
					local vy = v.y - bv.y -- 471
					if (vx * vx + vy * vy) / 2 - body.gm / math.max(r, 1e-9) < 0 then -- 471
						goto __continue45 -- 472
					end -- 472
				end -- 472
				return i -- 474
			end -- 474
			::__continue45:: -- 474
			i = i + 1 -- 453
		end -- 453
	end -- 453
	return -1 -- 476
end -- 448
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 522
	local out = {} -- 523
	for ____, b in ipairs(bodies) do -- 524
		out[#out + 1] = { -- 525
			gm = b.gm * gravityScale, -- 526
			radius = b.radius, -- 527
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 528
			orbitRadius = b.orbitRadius, -- 529
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 530
			phase0 = b.phase0, -- 531
			orbitDirection = b.orbitDirection, -- 532
			isObstacle = b.isObstacle, -- 533
			name = b.name, -- 534
			host = b.host ~= nil and applyScalesLocal({b.host}, gravityScale, orbitScale)[1] or nil -- 536
		} -- 536
	end -- 536
	return out -- 539
end -- 539
--- **1 真实秒 = 多少游戏秒**。
-- 街机三关的关卡 JSON 用的是屏幕单位，但倍速档位仍读这个换算（pow 0 = 现实 1 秒）。
-- 街机节奏不靠它：每关的 speedDefaultPow 在 Tuning 里另给。
____exports.GameSecondsPerRealSecond = 1 / SecPerGameSec -- 59
--- 评价一局飞行的火箭星级及逐条达成详情（纯函数）。
function ____exports.evaluateRocketsDetailed(level, result, burnDv, extra) -- 236
	local achieved = {false, false, false} -- 248
	if level.transfer ~= nil then -- 248
		achieved[1] = result == "success" -- 250
		return {rockets = achieved[1] and 1 or 0, achieved = achieved, burnDv = burnDv, stats = extra ~= nil and extra or ({})} -- 251
	end -- 251
	if result ~= "success" then -- 251
		return {rockets = 0, achieved = achieved, burnDv = burnDv, stats = extra ~= nil and extra or ({})} -- 254
	end -- 254
	achieved[1] = true -- 262
	local count = 1 -- 263
	local challenges = level.mission ~= nil and level.mission.challenges or nil -- 264
	if challenges ~= nil then -- 264
		local c2 = challenges[2] -- 267
		if c2.type == "stars" and c2.threshold ~= nil then -- 267
			if extra ~= nil and extra.starsCollected ~= nil and extra.starsCollected >= c2.threshold then -- 267
				achieved[2] = true -- 270
				count = count + 1 -- 271
			end -- 271
		elseif c2.type == "fuel" and c2.threshold ~= nil then -- 271
			if burnDv <= level.dvBudget * c2.threshold then -- 271
				achieved[2] = true -- 275
				count = count + 1 -- 276
			end -- 276
		elseif burnDv <= level.dvBudget * 0.8 then -- 276
			achieved[2] = true -- 279
			count = count + 1 -- 280
		end -- 280
		local c3 = challenges[3] -- 284
		if c3.type == "distance" and c3.threshold ~= nil then -- 284
			if extra ~= nil and extra.closestDist ~= nil and extra.closestDist <= c3.threshold then -- 284
				achieved[3] = true -- 287
				count = count + 1 -- 288
			end -- 288
		elseif c3.type == "speed" and c3.threshold ~= nil then -- 288
			if extra ~= nil and extra.maxSpeed ~= nil and extra.maxSpeed >= c3.threshold then -- 288
				achieved[3] = true -- 292
				count = count + 1 -- 293
			end -- 293
		elseif c3.type == "eccentricity" and c3.threshold ~= nil then -- 293
			if extra ~= nil and extra.eccentricity ~= nil and extra.eccentricity <= c3.threshold then -- 293
				achieved[3] = true -- 297
				count = count + 1 -- 298
			end -- 298
		elseif c3.type == "stars" and c3.threshold ~= nil then -- 298
			if extra ~= nil and extra.starsCollected ~= nil and extra.starsCollected >= c3.threshold then -- 298
				achieved[3] = true -- 302
				count = count + 1 -- 303
			end -- 303
		elseif count == 2 and burnDv <= level.dvBudget * 0.5 then -- 303
			achieved[3] = true -- 306
			count = count + 1 -- 307
		end -- 307
	end -- 307
	return { -- 311
		rockets = math.min( -- 312
			3, -- 312
			math.max(0, count) -- 312
		), -- 312
		achieved = achieved, -- 313
		burnDv = burnDv, -- 314
		stats = extra ~= nil and extra or ({}) -- 315
	} -- 315
end -- 236
--- 评价一局飞行的火箭星级（0 ~ 3 枚火箭，纯函数）。
function ____exports.evaluateRockets(level, result, burnDv, extra) -- 322
	return ____exports.evaluateRocketsDetailed(level, result, burnDv, extra).rockets -- 333
end -- 322
--- 航点列表（链式目标取 chain，否则就是唯一目标）。
function ____exports.goalWaypoints(goal) -- 353
	if goal.chain ~= nil then -- 353
		return goal.chain -- 354
	end -- 354
	if goal.kind == "planet" then -- 354
		return {{planetIndex = goal.planetIndex, tolerance = goal.tolerance, offset = goal.offset}} -- 355
	end -- 355
	return {} -- 356
end -- 353
--- 空域目标随天体公转：offset.x 径向，offset.y 沿公转切向。
function ____exports.goalPositionAt(body, t, offset) -- 360
	local p = bodyPositionAt(body, t) -- 361
	if offset == nil then -- 361
		return p -- 362
	end -- 362
	local center = body.host ~= nil and bodyPositionAt(body.host, t) or body.orbitCenter -- 363
	local dx = p.x - center.x -- 364
	local dy = p.y - center.y -- 365
	local r = math.sqrt(dx * dx + dy * dy) -- 366
	local ux = r > 0 and dx / r or 1 -- 367
	local uy = r > 0 and dy / r or 0 -- 368
	return {x = p.x + ux * offset.x - uy * offset.y * body.orbitDirection, y = p.y + uy * offset.x + ux * offset.y * body.orbitDirection} -- 369
end -- 360
--- 采样点 i 处、相对某天体的速度（捕获判据与诊断共用同一份实现）。
-- 
-- points 里只有位置 ⇒ 用相邻采样点差分；`dt` 是**相邻采样点之间的有效步长**。
-- `limit` 是最后一个有效采样点索引（末端夹紧用）。
function ____exports.relativeSpeedAt(points, i, body, dt, t0, limit, velocities) -- 379
	local vx = 0 -- 380
	local vy = 0 -- 381
	if velocities ~= nil and velocities[i + 1] ~= nil then -- 381
		vx = velocities[i + 1].x -- 384
		vy = velocities[i + 1].y -- 385
	else -- 385
		local j1 = i + 1 <= limit and i + 1 or i -- 389
		local j0 = i > 0 and i - 1 or i -- 390
		local spanT = (j1 - j0) * dt -- 391
		if spanT > 0 then -- 391
			vx = (points[j1 + 1].x - points[j0 + 1].x) / spanT -- 393
			vy = (points[j1 + 1].y - points[j0 + 1].y) / spanT -- 394
		end -- 394
	end -- 394
	local pv = ____exports.bodyVelocityAt(body, t0) -- 397
	local rx = vx - pv.x -- 398
	local ry = vy - pv.y -- 399
	return math.sqrt(rx * rx + ry * ry) -- 400
end -- 379
--- 顺序航线的进度：返回在 points[0..upto] 里**依次**掠过的航点数与最后一个命中索引。
-- 
-- 一次线性扫描：航点必须按顺序命中，且后一个必须出现在更晚的采样点上
-- （"先到土星再路过木星"不算数）。upto 用于飞行中查询"到哪一段了"（画环的明暗）。
function ____exports.waypointProgress(points, bodies, goal, dt, t0, upto, velocities) -- 409
	local wps = ____exports.goalWaypoints(goal) -- 418
	local start = t0 ~= nil and t0 or 0 -- 419
	local limit = #points - 1 -- 420
	if upto ~= nil and upto >= 0 and upto < limit then -- 420
		limit = upto -- 421
	end -- 421
	local next = 0 -- 422
	local lastIndex = -1 -- 423
	do -- 423
		local i = 0 -- 424
		while i <= limit and next < #wps do -- 424
			local w = wps[next + 1] -- 425
			local body = bodies[w.planetIndex + 1] -- 426
			if body == nil then -- 426
				return {passed = 0, lastIndex = -1} -- 427
			end -- 427
			local gp = ____exports.goalPositionAt(body, start + i * dt, w.offset) -- 428
			if distance(points[i + 1], gp) < w.tolerance then -- 428
				next = next + 1 -- 430
				lastIndex = i -- 431
			end -- 431
			i = i + 1 -- 424
		end -- 424
	end -- 424
	return {passed = next, lastIndex = lastIndex} -- 434
end -- 409
--- 到达目标的采样点索引；没到返回 -1。
function ____exports.findGoalIndex(points, bodies, goal, dt, t0, velocities) -- 438
	if goal.region ~= nil then -- 438
		return ____exports.findGoalRegionIndex( -- 439
			points, -- 439
			velocities, -- 439
			bodies, -- 439
			goal.region, -- 439
			dt, -- 439
			t0 ~= nil and t0 or 0 -- 439
		) -- 439
	end -- 439
	if goal.marker ~= nil then -- 439
		return -1 -- 440
	end -- 440
	local wps = ____exports.goalWaypoints(goal) -- 441
	if #wps == 0 then -- 441
		return -1 -- 442
	end -- 442
	local st = ____exports.waypointProgress( -- 443
		points, -- 443
		bodies, -- 443
		goal, -- 443
		dt, -- 443
		t0, -- 443
		nil, -- 443
		velocities -- 443
	) -- 443
	return st.passed >= #wps and st.lastIndex or -1 -- 444
end -- 438
--- 三关由 `Assets/Levels/*.json` 装配（见文件末尾的 `installArcadeLevels`）。
-- 没装上之前是空的：入口会停在 FATAL，而不是悄悄退回旧的静态坐标。
local LEVELS = {} -- 484
--- 与 LEVELS 一一对应的星尘轨道（按 t 求位置）。
local STAR_ORBITS = {} -- 486
--- 关卡总数。
function ____exports.levelCount() -- 489
	return #LEVELS -- 490
end -- 489
--- 这一关的星尘轨道。没有（或还没装配）返回空数组。
function ____exports.starOrbits(index) -- 494
	local row = STAR_ORBITS[index + 1] -- 495
	return row ~= nil and row or ({}) -- 496
end -- 494
--- 用两份 JSON 文本替换关卡表。
-- 解析失败或没有任何关时**保持原表不动**，返回 false。
function ____exports.installArcadeLevels(levelsText, bodiesText, decode) -- 503
	local loaded = loadArcadeLevels(levelsText, bodiesText, decode) -- 504
	if #loaded.levels == 0 then -- 504
		return false -- 505
	end -- 505
	LEVELS = loaded.levels -- 506
	STAR_ORBITS = loaded.starOrbits -- 507
	return true -- 508
end -- 503
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 512
	return LEVELS[index + 1] -- 513
end -- 512
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 517
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 518
end -- 517
return ____exports -- 517