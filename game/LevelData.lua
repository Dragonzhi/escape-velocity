-- [ts]: LevelData.ts
local ____exports = {} -- 1
local applyScalesLocal -- 1
local ____Gravity = require("game.Gravity") -- 28
local bodyPositionAt = ____Gravity.bodyPositionAt -- 28
local distance = ____Gravity.distance -- 28
local ____Config = require("game.Config") -- 29
local GravityScale = ____Config.GravityScale -- 29
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 29
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 556
	local out = {} -- 557
	for ____, b in ipairs(bodies) do -- 558
		out[#out + 1] = { -- 559
			gm = b.gm * gravityScale, -- 560
			radius = b.radius, -- 561
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 562
			orbitRadius = b.orbitRadius, -- 563
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 564
			phase0 = b.phase0, -- 565
			orbitDirection = b.orbitDirection -- 566
		} -- 566
	end -- 566
	return out -- 569
end -- 569
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
		probeVel0 = {x = 9.31, y = 0}, -- 325
		homeAnchor = false, -- 326
		planets = {{ -- 327
			gm = 2600, -- 330
			radius = R_EARTH, -- 330
			orbitCenter = {x = 0, y = 70}, -- 330
			orbitRadius = 0, -- 330
			orbitPeriod = 0, -- 330
			phase0 = 0, -- 330
			orbitDirection = 1 -- 330
		}, { -- 330
			gm = 0, -- 332
			radius = R_MOON, -- 332
			orbitCenter = {x = 0, y = -70}, -- 332
			orbitRadius = 0, -- 332
			orbitPeriod = 0, -- 332
			phase0 = 0, -- 332
			orbitDirection = 1 -- 332
		}}, -- 332
		visuals = {{ -- 334
			r = 0.42, -- 335
			g = 0.62, -- 335
			b = 0.85, -- 335
			displayRadius = R_EARTH, -- 335
			ring = false, -- 335
			model = "Planet_Earth" -- 335
		}, { -- 335
			r = 0.56, -- 336
			g = 0.56, -- 336
			b = 0.6, -- 336
			displayRadius = R_MOON, -- 336
			ring = false -- 336
		}}, -- 336
		goal = {kind = "planet", planetIndex = 1, tolerance = 30}, -- 341
		dvBudget = 45, -- 342
		escapeRadius = 700, -- 343
		maxSteps = 1200, -- 344
		homeRadius = 1.75 -- 345
	}, -- 345
	{ -- 347
		id = 2, -- 348
		title = "修正", -- 349
		brief = "航行日志 · 第 12 天：太阳开始拽你了。别直着飞 —— 向内会加速，航线也会被掰弯。目标是掠过金星。", -- 350
		probeStart = {x = 0, y = ORBIT.earth}, -- 351
		planets = { -- 352
			sun(), -- 353
			orbiter(2600, R_VENUS, ORBIT.venus, 180) -- 355
		}, -- 355
		visuals = { -- 357
			sunVisual(), -- 358
			{ -- 359
				r = 0.9, -- 359
				g = 0.78, -- 359
				b = 0.55, -- 359
				displayRadius = R_VENUS, -- 359
				ring = false, -- 359
				model = "Planet_Venus" -- 359
			} -- 359
		}, -- 359
		goal = {kind = "planet", planetIndex = 1, tolerance = R_VENUS + FLYBY_PAD}, -- 361
		dvBudget = 45, -- 362
		escapeRadius = 700, -- 363
		maxSteps = 1500, -- 364
		homeRadius = 1.6 -- 365
	}, -- 365
	{ -- 367
		id = 3, -- 368
		title = "弹弓", -- 369
		brief = "航行日志 · 第 2 年：木星在外圈。想省力就从它背后绕过去 —— 它的引力会把你甩向土星。", -- 370
		probeStart = {x = 0, y = ORBIT.earth}, -- 371
		planets = { -- 372
			sun(), -- 373
			orbiter(4000, R_JUPITER, ORBIT.jupiter, 89.4), -- 380
			orbiter(12000, R_SATURN, ORBIT.saturn, 89) -- 382
		}, -- 382
		visuals = { -- 384
			sunVisual(), -- 385
			{ -- 386
				r = 0.85, -- 386
				g = 0.72, -- 386
				b = 0.5, -- 386
				displayRadius = R_JUPITER, -- 386
				ring = false, -- 386
				model = "Planet_Jupiter" -- 386
			}, -- 386
			{ -- 387
				r = 0.75, -- 387
				g = 0.7, -- 387
				b = 0.6, -- 387
				displayRadius = R_SATURN, -- 387
				ring = true, -- 387
				model = "Planet_Saturn" -- 387
			} -- 387
		}, -- 387
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + 22, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 45, label = "土星"}}}, -- 390
		dvBudget = 55, -- 399
		escapeRadius = 700, -- 400
		maxSteps = 2400, -- 401
		homeRadius = 1.45 -- 402
	}, -- 402
	{ -- 404
		id = 4, -- 405
		title = "窗口", -- 406
		brief = "航行日志 · 第 3 年：木星一直在绕太阳走。挑一个它正好在你航线上的日期起飞 —— 拖动时间轴，看它挪位置。", -- 407
		probeStart = {x = 0, y = ORBIT.earth}, -- 408
		planets = { -- 409
			sun(), -- 410
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 29.3), -- 418
			orbiter(12000, R_SATURN, ORBIT.saturn, 48.2) -- 419
		}, -- 419
		visuals = { -- 421
			sunVisual(), -- 422
			{ -- 423
				r = 0.85, -- 423
				g = 0.72, -- 423
				b = 0.5, -- 423
				displayRadius = R_JUPITER, -- 423
				ring = false, -- 423
				model = "Planet_Jupiter" -- 423
			}, -- 423
			{ -- 424
				r = 0.75, -- 424
				g = 0.7, -- 424
				b = 0.6, -- 424
				displayRadius = R_SATURN, -- 424
				ring = true, -- 424
				model = "Planet_Saturn" -- 424
			} -- 424
		}, -- 424
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 30, label = "土星", capture = true}}}, -- 427
		dvBudget = 50, -- 434
		escapeRadius = 700, -- 435
		maxSteps = 1800, -- 436
		homeRadius = 1.35, -- 437
		timeWindow = {span = 300} -- 441
	}, -- 441
	{ -- 443
		id = 5, -- 444
		title = "大巡游", -- 445
		brief = "航行日志 · 第 5 年：一次点火，四颗巨行星。木星改向、土星续航、天王星微调 —— 最后到海王星。", -- 446
		probeStart = {x = 0, y = ORBIT.earth}, -- 447
		planets = { -- 448
			sun(), -- 449
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 89.5), -- 454
			orbiter(2000, R_SATURN, ORBIT.saturn, 89.5), -- 455
			orbiter(1200, R_URANUS, ORBIT.uranus, 89.5), -- 456
			orbiter(8000, R_NEPTUNE, ORBIT.neptune, 89.5) -- 457
		}, -- 457
		visuals = { -- 459
			sunVisual(), -- 460
			{ -- 461
				r = 0.85, -- 461
				g = 0.72, -- 461
				b = 0.5, -- 461
				displayRadius = R_JUPITER, -- 461
				ring = false, -- 461
				model = "Planet_Jupiter" -- 461
			}, -- 461
			{ -- 462
				r = 0.75, -- 462
				g = 0.7, -- 462
				b = 0.6, -- 462
				displayRadius = R_SATURN, -- 462
				ring = true, -- 462
				model = "Planet_Saturn" -- 462
			}, -- 462
			{ -- 463
				r = 0.62, -- 463
				g = 0.82, -- 463
				b = 0.86, -- 463
				displayRadius = R_URANUS, -- 463
				ring = false, -- 463
				model = "Planet_Uranus" -- 463
			}, -- 463
			{ -- 464
				r = 0.34, -- 464
				g = 0.5, -- 464
				b = 0.86, -- 464
				displayRadius = R_NEPTUNE, -- 464
				ring = false, -- 464
				model = "Planet_Neptune" -- 464
			} -- 464
		}, -- 464
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 50, label = "土星"}, {planetIndex = 3, tolerance = 60, label = "天王星"}, {planetIndex = 4, tolerance = 70, label = "海王星"}}}, -- 467
		dvBudget = 55, -- 482
		escapeRadius = 700, -- 483
		maxSteps = 2400, -- 484
		homeRadius = 1.25 -- 485
	}, -- 485
	{ -- 487
		id = 6, -- 488
		title = "单程", -- 489
		brief = "航行日志 · 第 12 年：没有回程了。四颗巨行星还会连成一条线 —— 等到那一天（拖动时间轴），沿着这条线依次穿过去，再越过 260 单位，就是星际空间。", -- 490
		probeStart = {x = 0, y = ORBIT.earth}, -- 491
		planets = { -- 492
			sun(), -- 493
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 29.3), -- 499
			orbiter(2000, R_SATURN, ORBIT.saturn, 48.2), -- 500
			orbiter(1200, R_URANUS, ORBIT.uranus, 58.9), -- 501
			orbiter(8000, R_NEPTUNE, ORBIT.neptune, 65.7) -- 502
		}, -- 502
		visuals = { -- 504
			sunVisual(), -- 505
			{ -- 506
				r = 0.85, -- 506
				g = 0.72, -- 506
				b = 0.5, -- 506
				displayRadius = R_JUPITER, -- 506
				ring = false, -- 506
				model = "Planet_Jupiter" -- 506
			}, -- 506
			{ -- 507
				r = 0.75, -- 507
				g = 0.7, -- 507
				b = 0.6, -- 507
				displayRadius = R_SATURN, -- 507
				ring = true, -- 507
				model = "Planet_Saturn" -- 507
			}, -- 507
			{ -- 508
				r = 0.62, -- 508
				g = 0.82, -- 508
				b = 0.86, -- 508
				displayRadius = R_URANUS, -- 508
				ring = false, -- 508
				model = "Planet_Uranus" -- 508
			}, -- 508
			{ -- 509
				r = 0.34, -- 509
				g = 0.5, -- 509
				b = 0.86, -- 509
				displayRadius = R_NEPTUNE, -- 509
				ring = false, -- 509
				model = "Planet_Neptune" -- 509
			} -- 509
		}, -- 509
		goal = {kind = "escape", planetIndex = -1, tolerance = 0, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 50, label = "土星"}, {planetIndex = 3, tolerance = 60, label = "天王星"}, {planetIndex = 4, tolerance = 70, label = "海王星"}}}, -- 517
		dvBudget = 50, -- 529
		escapeRadius = 260, -- 530
		maxSteps = 2400, -- 531
		homeRadius = 1, -- 532
		timeWindow = {span = 300} -- 536
	} -- 536
} -- 536
--- 关卡总数。
function ____exports.levelCount() -- 541
	return #LEVELS -- 542
end -- 541
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 546
	return LEVELS[index + 1] -- 547
end -- 546
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 551
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 552
end -- 551
return ____exports -- 551