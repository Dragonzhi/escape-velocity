-- [ts]: LevelData.ts
local ____exports = {} -- 1
local applyScalesLocal -- 1
local ____Gravity = require("game.Gravity") -- 28
local bodyPositionAt = ____Gravity.bodyPositionAt -- 28
local distance = ____Gravity.distance -- 28
local ____Config = require("game.Config") -- 29
local GravityScale = ____Config.GravityScale -- 29
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 29
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 507
	local out = {} -- 508
	for ____, b in ipairs(bodies) do -- 509
		out[#out + 1] = { -- 510
			gm = b.gm * gravityScale, -- 511
			radius = b.radius, -- 512
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 513
			orbitRadius = b.orbitRadius, -- 514
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 515
			phase0 = b.phase0, -- 516
			orbitDirection = b.orbitDirection -- 517
		} -- 517
	end -- 517
	return out -- 520
end -- 520
--- 太阳的引力强度（`v_circ(80) = sqrt(SunGm/80) ≈ 30`，逃逸速度 42.4）。
____exports.SunGm = 72000 -- 125
--- 太阳的半径（撞毁半径 = 显示半径，尺寸公平性硬约束）。
-- 
-- ⚠️ 2026-09-26 用户参考图（docs/比例尺效果展示图.excalidraw）给的比值：
--   最内圈轨道 ≈ **1.9 个太阳半径**、太阳直径 ≈ 屏幕宽度的 0.38、行星 ≈ 太阳的 0.19。
--   原来取 7.0（轨道 = 7.9~27.9 个太阳半径）⇒ 太阳在画面里像一颗行星，"尺度很怪"的根因之一。
--   改成 28 之后：轨道 55/80/105/135/165/195 = 1.96/2.86/3.75/4.8/5.9/7.0 个太阳半径，与参考图一致。
____exports.SunRadius = 28 -- 135
--- 开普勒周期系数：`T = KeplerK · r^1.5`（秒）。
-- 
-- 相对快慢 = 真实开普勒（内快外慢），绝对速率被压缩 —— `KeplerK = 1` 相当于把真实值除以 42.7
-- （真实：`T = 2π·r^1.5/sqrt(SunGm) = 0.0234·r^1.5`）。这样飞行十几秒里行星只挪几度。
____exports.KeplerK = 1 -- 143
--- 开普勒周期（秒）：r 单位是平面单位。r <= 0 返回 0（静止）。
function ____exports.keplerPeriod(orbitRadius) -- 146
	if orbitRadius <= 0 then -- 146
		return 0 -- 147
	end -- 147
	return ____exports.KeplerK * orbitRadius ^ 1.5 -- 148
end -- 146
--- 度 → 弧度（关卡数据里写角度比写弧度好读）。
local function deg(d) -- 152
	return d * math.pi / 180 -- 153
end -- 152
local R_MOON = 1 -- 157
local R_VENUS = 1.72 -- 158
local R_EARTH = 1.76 -- 159
local R_JUPITER = 4.63 -- 160
local R_SATURN = 4.3 -- 161
local R_URANUS = 3.04 -- 162
local R_NEPTUNE = 3 -- 163
--- 巡航轨道半径（压缩太阳系：顺序真实、比例压缩）—— 一律绕原点（太阳）。
local ORBIT = { -- 166
	venus = 55, -- 166
	earth = 80, -- 166
	jupiter = 105, -- 166
	saturn = 135, -- 166
	uranus = 165, -- 166
	neptune = 195 -- 166
} -- 166
--- 掠过环的容差（flyby）：比本体大 13 左右 —— 远距离飞行要有"够得着"的手感。
local FLYBY_PAD = 13 -- 169
--- 行星自身在时刻 t 的速度（圆轨道 = 位置的导数）。
-- 捕获判据要的是"**相对**行星的速度" —— 行星自己也在跑（虽然慢）。
function ____exports.bodyVelocityAt(b, t) -- 182
	if b.orbitPeriod == 0 or b.orbitRadius <= 0 then -- 182
		return {x = 0, y = 0} -- 183
	end -- 183
	local angle = b.phase0 + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 184
	local w = b.orbitDirection * 2 * math.pi / b.orbitPeriod -- 185
	return { -- 186
		x = -math.sin(angle) * b.orbitRadius * w, -- 186
		y = math.cos(angle) * b.orbitRadius * w -- 186
	} -- 186
end -- 182
function ____exports.goalWaypoints(goal) -- 189
	if goal.chain ~= nil then -- 189
		return goal.chain -- 190
	end -- 190
	if goal.kind == "planet" then -- 190
		return {{planetIndex = goal.planetIndex, tolerance = goal.tolerance}} -- 191
	end -- 191
	return {} -- 192
end -- 189
--- 采样点 i 处、相对某天体的速度（捕获判据与诊断共用同一份实现）。
-- 
-- points 里只有位置 ⇒ 用相邻采样点差分；`dt` 是**相邻采样点之间的有效步长**。
-- `limit` 是最后一个有效采样点索引（末端夹紧用）。
function ____exports.relativeSpeedAt(points, i, body, dt, t0, limit, velocities) -- 207
	local vx = 0 -- 208
	local vy = 0 -- 209
	if velocities ~= nil and velocities[i + 1] ~= nil then -- 209
		vx = velocities[i + 1].x -- 212
		vy = velocities[i + 1].y -- 213
	else -- 213
		local j1 = i + 1 <= limit and i + 1 or i -- 217
		local j0 = i > 0 and i - 1 or i -- 218
		local spanT = (j1 - j0) * dt -- 219
		if spanT > 0 then -- 219
			vx = (points[j1 + 1].x - points[j0 + 1].x) / spanT -- 221
			vy = (points[j1 + 1].y - points[j0 + 1].y) / spanT -- 222
		end -- 222
	end -- 222
	local pv = ____exports.bodyVelocityAt(body, t0) -- 225
	local rx = vx - pv.x -- 226
	local ry = vy - pv.y -- 227
	return math.sqrt(rx * rx + ry * ry) -- 228
end -- 207
--- 捕获阈值：该处逃逸速度（圆轨道速度 × 系数 k，k 默认 √2）。
function ____exports.captureThreshold(body, d, k) -- 232
	if body.gm <= 0 or d <= 0.000001 then -- 232
		return 1000000000 -- 233
	end -- 233
	return k * math.sqrt(body.gm / d) -- 234
end -- 232
function ____exports.waypointProgress(points, bodies, goal, dt, t0, upto, velocities) -- 237
	local wps = ____exports.goalWaypoints(goal) -- 247
	local start = t0 ~= nil and t0 or 0 -- 248
	local limit = #points - 1 -- 249
	if upto ~= nil and upto >= 0 and upto < limit then -- 249
		limit = upto -- 250
	end -- 250
	local next = 0 -- 251
	local lastIndex = -1 -- 252
	do -- 252
		local i = 0 -- 253
		while i <= limit and next < #wps do -- 253
			do -- 253
				local w = wps[next + 1] -- 254
				local body = bodies[w.planetIndex + 1] -- 255
				if body == nil then -- 255
					return {passed = 0, lastIndex = -1} -- 256
				end -- 256
				local gp = bodyPositionAt(body, start + i * dt) -- 257
				if distance(points[i + 1], gp) < w.tolerance then -- 257
					if w.capture == true then -- 257
						local k = w.captureFactor ~= nil and w.captureFactor or 1.4142135623730951 -- 263
						local d = distance(points[i + 1], gp) -- 264
						if d <= body.radius then -- 264
							goto __continue19 -- 268
						end -- 268
						local rel = ____exports.relativeSpeedAt( -- 269
							points, -- 269
							i, -- 269
							body, -- 269
							dt, -- 269
							start + i * dt, -- 269
							limit, -- 269
							velocities -- 269
						) -- 269
						if rel > ____exports.captureThreshold(body, d, k) then -- 269
							goto __continue19 -- 270
						end -- 270
					end -- 270
					next = next + 1 -- 272
					lastIndex = i -- 273
				end -- 273
			end -- 273
			::__continue19:: -- 273
			i = i + 1 -- 253
		end -- 253
	end -- 253
	return {passed = next, lastIndex = lastIndex} -- 276
end -- 237
function ____exports.findGoalIndex(points, bodies, goal, dt, t0, velocities) -- 279
	local wps = ____exports.goalWaypoints(goal) -- 280
	if #wps == 0 then -- 280
		return -1 -- 281
	end -- 281
	local st = ____exports.waypointProgress( -- 282
		points, -- 282
		bodies, -- 282
		goal, -- 282
		dt, -- 282
		t0, -- 282
		nil, -- 282
		velocities -- 282
	) -- 282
	return st.passed >= #wps and st.lastIndex or -1 -- 283
end -- 279
--- 太阳（除 L1 外每关的第 0 号天体）。
local function sun() -- 291
	return { -- 292
		gm = ____exports.SunGm, -- 292
		radius = ____exports.SunRadius, -- 292
		orbitCenter = {x = 0, y = 0}, -- 292
		orbitRadius = 0, -- 292
		orbitPeriod = 0, -- 292
		phase0 = 0, -- 292
		orbitDirection = 1 -- 292
	} -- 292
end -- 291
--- 太阳的视觉（亮黄，模型 Sun.glb）。
local function sunVisual() -- 296
	return { -- 297
		r = 1, -- 297
		g = 0.9, -- 297
		b = 0.62, -- 297
		displayRadius = ____exports.SunRadius, -- 297
		ring = false, -- 297
		model = "Sun", -- 297
		emissive = {r = 0.95, g = 0.72, b = 0.3} -- 297
	} -- 297
end -- 296
--- 绕日公转的行星（S3.7：圆心 = 太阳 = 原点）。
local function orbiter(gm, radius, orbitRadius, phaseDeg) -- 301
	return { -- 302
		gm = gm, -- 303
		radius = radius, -- 303
		orbitCenter = {x = 0, y = 0}, -- 304
		orbitRadius = orbitRadius, -- 305
		orbitPeriod = ____exports.keplerPeriod(orbitRadius), -- 306
		phase0 = deg(phaseDeg), -- 307
		orbitDirection = 1 -- 308
	} -- 308
end -- 301
local LEVELS = { -- 312
	{ -- 313
		id = 1, -- 314
		title = "出发", -- 315
		brief = "航行日志 · 第 1 天：离开地球。这一段路很干净，没有大天体捣乱 —— 先把拖拽瞄准练熟。月球在正前方。", -- 316
		probeStart = {x = 0, y = 40}, -- 317
		probeVel0 = {x = 12, y = 0}, -- 321
		homeAnchor = false, -- 322
		planets = {{ -- 323
			gm = 2600, -- 326
			radius = R_EARTH, -- 326
			orbitCenter = {x = 0, y = 70}, -- 326
			orbitRadius = 0, -- 326
			orbitPeriod = 0, -- 326
			phase0 = 0, -- 326
			orbitDirection = 1 -- 326
		}, { -- 326
			gm = 0, -- 328
			radius = R_MOON, -- 328
			orbitCenter = {x = 0, y = -70}, -- 328
			orbitRadius = 0, -- 328
			orbitPeriod = 0, -- 328
			phase0 = 0, -- 328
			orbitDirection = 1 -- 328
		}}, -- 328
		visuals = {{ -- 330
			r = 0.42, -- 331
			g = 0.62, -- 331
			b = 0.85, -- 331
			displayRadius = R_EARTH, -- 331
			ring = false, -- 331
			model = "Planet_Earth" -- 331
		}, { -- 331
			r = 0.56, -- 332
			g = 0.56, -- 332
			b = 0.6, -- 332
			displayRadius = R_MOON, -- 332
			ring = false -- 332
		}}, -- 332
		goal = {kind = "planet", planetIndex = 1, tolerance = 24}, -- 335
		dvBudget = 45, -- 336
		escapeRadius = 700, -- 337
		maxSteps = 1200, -- 338
		homeRadius = 1.75 -- 339
	}, -- 339
	{ -- 341
		id = 2, -- 342
		title = "修正", -- 343
		brief = "航行日志 · 第 12 天：太阳开始拽你了。别直着飞 —— 向内会加速，航线也会被掰弯。目标是掠过金星。", -- 344
		probeStart = {x = 0, y = ORBIT.earth}, -- 345
		planets = { -- 346
			sun(), -- 347
			orbiter(2600, R_VENUS, ORBIT.venus, 180) -- 349
		}, -- 349
		visuals = { -- 351
			sunVisual(), -- 352
			{ -- 353
				r = 0.9, -- 353
				g = 0.78, -- 353
				b = 0.55, -- 353
				displayRadius = R_VENUS, -- 353
				ring = false, -- 353
				model = "Planet_Venus" -- 353
			} -- 353
		}, -- 353
		goal = {kind = "planet", planetIndex = 1, tolerance = R_VENUS + FLYBY_PAD}, -- 355
		dvBudget = 45, -- 356
		escapeRadius = 700, -- 357
		maxSteps = 1500, -- 358
		homeRadius = 1.6 -- 359
	}, -- 359
	{ -- 361
		id = 3, -- 362
		title = "弹弓", -- 363
		brief = "航行日志 · 第 2 年：木星在外圈。想省力就从它背后绕过去 —— 它的引力会把你甩向土星。", -- 364
		probeStart = {x = 0, y = ORBIT.earth}, -- 365
		planets = { -- 366
			sun(), -- 367
			orbiter(4000, R_JUPITER, ORBIT.jupiter, 195.5), -- 370
			orbiter(12000, R_SATURN, ORBIT.saturn, 198) -- 373
		}, -- 373
		visuals = { -- 375
			sunVisual(), -- 376
			{ -- 377
				r = 0.85, -- 377
				g = 0.72, -- 377
				b = 0.5, -- 377
				displayRadius = R_JUPITER, -- 377
				ring = false, -- 377
				model = "Planet_Jupiter" -- 377
			}, -- 377
			{ -- 378
				r = 0.75, -- 378
				g = 0.7, -- 378
				b = 0.6, -- 378
				displayRadius = R_SATURN, -- 378
				ring = true, -- 378
				model = "Planet_Saturn" -- 378
			} -- 378
		}, -- 378
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + 22, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 45, label = "土星"}}}, -- 381
		dvBudget = 55, -- 390
		escapeRadius = 700, -- 391
		maxSteps = 2400, -- 392
		homeRadius = 1.45 -- 393
	}, -- 393
	{ -- 395
		id = 4, -- 396
		title = "窗口", -- 397
		brief = "航行日志 · 第 3 年：木星一直在绕太阳走。挑一个它正好在你航线上的日期起飞 —— 拖动时间轴，看它挪位置。", -- 398
		probeStart = {x = 0, y = ORBIT.earth}, -- 399
		planets = { -- 400
			sun(), -- 401
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 315.5), -- 403
			orbiter(12000, R_SATURN, ORBIT.saturn, 288) -- 404
		}, -- 404
		visuals = { -- 406
			sunVisual(), -- 407
			{ -- 408
				r = 0.85, -- 408
				g = 0.72, -- 408
				b = 0.5, -- 408
				displayRadius = R_JUPITER, -- 408
				ring = false, -- 408
				model = "Planet_Jupiter" -- 408
			}, -- 408
			{ -- 409
				r = 0.75, -- 409
				g = 0.7, -- 409
				b = 0.6, -- 409
				displayRadius = R_SATURN, -- 409
				ring = true, -- 409
				model = "Planet_Saturn" -- 409
			} -- 409
		}, -- 409
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 30, label = "土星", capture = true}}}, -- 412
		dvBudget = 50, -- 419
		escapeRadius = 700, -- 420
		maxSteps = 1800, -- 421
		homeRadius = 1.35, -- 422
		timeWindow = {span = ____exports.keplerPeriod(ORBIT.jupiter) / 3} -- 425
	}, -- 425
	{ -- 427
		id = 5, -- 428
		title = "大巡游", -- 429
		brief = "航行日志 · 第 5 年：一次点火，四颗巨行星。木星改向、土星续航、天王星微调 —— 最后到海王星。", -- 430
		probeStart = {x = 0, y = ORBIT.earth}, -- 431
		planets = { -- 432
			sun(), -- 433
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 195.5), -- 436
			orbiter(2000, R_SATURN, ORBIT.saturn, 203.1), -- 437
			orbiter(1200, R_URANUS, ORBIT.uranus, 209.7), -- 438
			orbiter(8000, R_NEPTUNE, ORBIT.neptune, 216.4) -- 439
		}, -- 439
		visuals = { -- 441
			sunVisual(), -- 442
			{ -- 443
				r = 0.85, -- 443
				g = 0.72, -- 443
				b = 0.5, -- 443
				displayRadius = R_JUPITER, -- 443
				ring = false, -- 443
				model = "Planet_Jupiter" -- 443
			}, -- 443
			{ -- 444
				r = 0.75, -- 444
				g = 0.7, -- 444
				b = 0.6, -- 444
				displayRadius = R_SATURN, -- 444
				ring = true, -- 444
				model = "Planet_Saturn" -- 444
			}, -- 444
			{ -- 445
				r = 0.62, -- 445
				g = 0.82, -- 445
				b = 0.86, -- 445
				displayRadius = R_URANUS, -- 445
				ring = false, -- 445
				model = "Planet_Uranus" -- 445
			}, -- 445
			{ -- 446
				r = 0.34, -- 446
				g = 0.5, -- 446
				b = 0.86, -- 446
				displayRadius = R_NEPTUNE, -- 446
				ring = false, -- 446
				model = "Planet_Neptune" -- 446
			} -- 446
		}, -- 446
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 26, label = "土星"}, {planetIndex = 3, tolerance = R_URANUS + 30, label = "天王星"}, {planetIndex = 4, tolerance = R_NEPTUNE + 34, label = "海王星", capture = true}}}, -- 449
		dvBudget = 55, -- 458
		escapeRadius = 700, -- 459
		maxSteps = 2400, -- 460
		homeRadius = 1.25 -- 461
	}, -- 461
	{ -- 463
		id = 6, -- 464
		title = "单程", -- 465
		brief = "航行日志 · 第 12 年：没有回程了。穿过四颗巨行星，飞出太阳系 —— 越过 260 单位就算离开。", -- 466
		probeStart = {x = 0, y = ORBIT.earth}, -- 467
		planets = { -- 468
			sun(), -- 469
			orbiter(9400, R_JUPITER, ORBIT.jupiter, 200), -- 470
			orbiter(7000, R_SATURN, ORBIT.saturn, 245), -- 471
			orbiter(3200, R_URANUS, ORBIT.uranus, 290), -- 472
			orbiter(2200, R_NEPTUNE, ORBIT.neptune, 335) -- 473
		}, -- 473
		visuals = { -- 475
			sunVisual(), -- 476
			{ -- 477
				r = 0.85, -- 477
				g = 0.72, -- 477
				b = 0.5, -- 477
				displayRadius = R_JUPITER, -- 477
				ring = false, -- 477
				model = "Planet_Jupiter" -- 477
			}, -- 477
			{ -- 478
				r = 0.75, -- 478
				g = 0.7, -- 478
				b = 0.6, -- 478
				displayRadius = R_SATURN, -- 478
				ring = true, -- 478
				model = "Planet_Saturn" -- 478
			}, -- 478
			{ -- 479
				r = 0.62, -- 479
				g = 0.82, -- 479
				b = 0.86, -- 479
				displayRadius = R_URANUS, -- 479
				ring = false, -- 479
				model = "Planet_Uranus" -- 479
			}, -- 479
			{ -- 480
				r = 0.34, -- 480
				g = 0.5, -- 480
				b = 0.86, -- 480
				displayRadius = R_NEPTUNE, -- 480
				ring = false, -- 480
				model = "Planet_Neptune" -- 480
			} -- 480
		}, -- 480
		goal = {kind = "escape", planetIndex = -1, tolerance = 0}, -- 483
		dvBudget = 50, -- 484
		escapeRadius = 260, -- 485
		maxSteps = 2400, -- 486
		homeRadius = 1 -- 487
	} -- 487
} -- 487
--- 关卡总数。
function ____exports.levelCount() -- 492
	return #LEVELS -- 493
end -- 492
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 497
	return LEVELS[index + 1] -- 498
end -- 497
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 502
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 503
end -- 502
return ____exports -- 502