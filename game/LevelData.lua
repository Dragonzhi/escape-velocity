-- [ts]: LevelData.ts
local ____exports = {} -- 1
local applyScalesLocal -- 1
local ____Gravity = require("game.Gravity") -- 28
local bodyPositionAt = ____Gravity.bodyPositionAt -- 28
local distance = ____Gravity.distance -- 28
local ____Config = require("game.Config") -- 29
local GravityScale = ____Config.GravityScale -- 29
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 29
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 559
	local out = {} -- 560
	for ____, b in ipairs(bodies) do -- 561
		out[#out + 1] = { -- 562
			gm = b.gm * gravityScale, -- 563
			radius = b.radius, -- 564
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 565
			orbitRadius = b.orbitRadius, -- 566
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 567
			phase0 = b.phase0, -- 568
			orbitDirection = b.orbitDirection -- 569
		} -- 569
	end -- 569
	return out -- 572
end -- 572
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
	return { -- 300
		r = 1, -- 300
		g = 0.97, -- 300
		b = 0.88, -- 300
		displayRadius = ____exports.SunRadius, -- 300
		ring = false, -- 300
		model = "Sun", -- 300
		emissive = {r = 1, g = 0.95, b = 0.82} -- 300
	} -- 300
end -- 296
--- 绕日公转的行星（S3.7：圆心 = 太阳 = 原点）。
local function orbiter(gm, radius, orbitRadius, phaseDeg) -- 304
	return { -- 305
		gm = gm, -- 306
		radius = radius, -- 306
		orbitCenter = {x = 0, y = 0}, -- 307
		orbitRadius = orbitRadius, -- 308
		orbitPeriod = ____exports.keplerPeriod(orbitRadius), -- 309
		phase0 = deg(phaseDeg), -- 310
		orbitDirection = 1 -- 311
	} -- 311
end -- 304
local LEVELS = { -- 315
	{ -- 316
		id = 1, -- 317
		title = "出发", -- 318
		brief = "航行日志 · 第 1 天：离开地球。这一段路很干净，没有大天体捣乱 —— 先把拖拽瞄准练熟。月球在正前方。", -- 319
		probeStart = {x = 0, y = 40}, -- 320
		probeVel0 = {x = 9.31, y = 0}, -- 328
		homeAnchor = false, -- 329
		planets = {{ -- 330
			gm = 2600, -- 333
			radius = R_EARTH, -- 333
			orbitCenter = {x = 0, y = 70}, -- 333
			orbitRadius = 0, -- 333
			orbitPeriod = 0, -- 333
			phase0 = 0, -- 333
			orbitDirection = 1 -- 333
		}, { -- 333
			gm = 0, -- 335
			radius = R_MOON, -- 335
			orbitCenter = {x = 0, y = -70}, -- 335
			orbitRadius = 0, -- 335
			orbitPeriod = 0, -- 335
			phase0 = 0, -- 335
			orbitDirection = 1 -- 335
		}}, -- 335
		visuals = {{ -- 337
			r = 0.42, -- 338
			g = 0.62, -- 338
			b = 0.85, -- 338
			displayRadius = R_EARTH, -- 338
			ring = false, -- 338
			model = "Planet_Earth" -- 338
		}, { -- 338
			r = 0.56, -- 339
			g = 0.56, -- 339
			b = 0.6, -- 339
			displayRadius = R_MOON, -- 339
			ring = false -- 339
		}}, -- 339
		goal = {kind = "planet", planetIndex = 1, tolerance = 30}, -- 344
		dvBudget = 45, -- 345
		escapeRadius = 700, -- 346
		maxSteps = 1200, -- 347
		homeRadius = 1.75 -- 348
	}, -- 348
	{ -- 350
		id = 2, -- 351
		title = "修正", -- 352
		brief = "航行日志 · 第 12 天：太阳开始拽你了。别直着飞 —— 向内会加速，航线也会被掰弯。目标是掠过金星。", -- 353
		probeStart = {x = 0, y = ORBIT.earth}, -- 354
		planets = { -- 355
			sun(), -- 356
			orbiter(2600, R_VENUS, ORBIT.venus, 180) -- 358
		}, -- 358
		visuals = { -- 360
			sunVisual(), -- 361
			{ -- 362
				r = 0.9, -- 362
				g = 0.78, -- 362
				b = 0.55, -- 362
				displayRadius = R_VENUS, -- 362
				ring = false, -- 362
				model = "Planet_Venus" -- 362
			} -- 362
		}, -- 362
		goal = {kind = "planet", planetIndex = 1, tolerance = R_VENUS + FLYBY_PAD}, -- 364
		dvBudget = 45, -- 365
		escapeRadius = 700, -- 366
		maxSteps = 1500, -- 367
		homeRadius = 1.6 -- 368
	}, -- 368
	{ -- 370
		id = 3, -- 371
		title = "弹弓", -- 372
		brief = "航行日志 · 第 2 年：木星在外圈。想省力就从它背后绕过去 —— 它的引力会把你甩向土星。", -- 373
		probeStart = {x = 0, y = ORBIT.earth}, -- 374
		planets = { -- 375
			sun(), -- 376
			orbiter(4000, R_JUPITER, ORBIT.jupiter, 89.4), -- 383
			orbiter(12000, R_SATURN, ORBIT.saturn, 89) -- 385
		}, -- 385
		visuals = { -- 387
			sunVisual(), -- 388
			{ -- 389
				r = 0.85, -- 389
				g = 0.72, -- 389
				b = 0.5, -- 389
				displayRadius = R_JUPITER, -- 389
				ring = false, -- 389
				model = "Planet_Jupiter" -- 389
			}, -- 389
			{ -- 390
				r = 0.75, -- 390
				g = 0.7, -- 390
				b = 0.6, -- 390
				displayRadius = R_SATURN, -- 390
				ring = true, -- 390
				model = "Planet_Saturn" -- 390
			} -- 390
		}, -- 390
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + 22, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 45, label = "土星"}}}, -- 393
		dvBudget = 55, -- 402
		escapeRadius = 700, -- 403
		maxSteps = 2400, -- 404
		homeRadius = 1.45 -- 405
	}, -- 405
	{ -- 407
		id = 4, -- 408
		title = "窗口", -- 409
		brief = "航行日志 · 第 3 年：木星一直在绕太阳走。挑一个它正好在你航线上的日期起飞 —— 拖动时间轴，看它挪位置。", -- 410
		probeStart = {x = 0, y = ORBIT.earth}, -- 411
		planets = { -- 412
			sun(), -- 413
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 29.3), -- 421
			orbiter(12000, R_SATURN, ORBIT.saturn, 48.2) -- 422
		}, -- 422
		visuals = { -- 424
			sunVisual(), -- 425
			{ -- 426
				r = 0.85, -- 426
				g = 0.72, -- 426
				b = 0.5, -- 426
				displayRadius = R_JUPITER, -- 426
				ring = false, -- 426
				model = "Planet_Jupiter" -- 426
			}, -- 426
			{ -- 427
				r = 0.75, -- 427
				g = 0.7, -- 427
				b = 0.6, -- 427
				displayRadius = R_SATURN, -- 427
				ring = true, -- 427
				model = "Planet_Saturn" -- 427
			} -- 427
		}, -- 427
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 30, label = "土星", capture = true}}}, -- 430
		dvBudget = 50, -- 437
		escapeRadius = 700, -- 438
		maxSteps = 1800, -- 439
		homeRadius = 1.35, -- 440
		timeWindow = {span = 300} -- 444
	}, -- 444
	{ -- 446
		id = 5, -- 447
		title = "大巡游", -- 448
		brief = "航行日志 · 第 5 年：一次点火，四颗巨行星。木星改向、土星续航、天王星微调 —— 最后到海王星。", -- 449
		probeStart = {x = 0, y = ORBIT.earth}, -- 450
		planets = { -- 451
			sun(), -- 452
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 89.5), -- 457
			orbiter(2000, R_SATURN, ORBIT.saturn, 89.5), -- 458
			orbiter(1200, R_URANUS, ORBIT.uranus, 89.5), -- 459
			orbiter(8000, R_NEPTUNE, ORBIT.neptune, 89.5) -- 460
		}, -- 460
		visuals = { -- 462
			sunVisual(), -- 463
			{ -- 464
				r = 0.85, -- 464
				g = 0.72, -- 464
				b = 0.5, -- 464
				displayRadius = R_JUPITER, -- 464
				ring = false, -- 464
				model = "Planet_Jupiter" -- 464
			}, -- 464
			{ -- 465
				r = 0.75, -- 465
				g = 0.7, -- 465
				b = 0.6, -- 465
				displayRadius = R_SATURN, -- 465
				ring = true, -- 465
				model = "Planet_Saturn" -- 465
			}, -- 465
			{ -- 466
				r = 0.62, -- 466
				g = 0.82, -- 466
				b = 0.86, -- 466
				displayRadius = R_URANUS, -- 466
				ring = false, -- 466
				model = "Planet_Uranus" -- 466
			}, -- 466
			{ -- 467
				r = 0.34, -- 467
				g = 0.5, -- 467
				b = 0.86, -- 467
				displayRadius = R_NEPTUNE, -- 467
				ring = false, -- 467
				model = "Planet_Neptune" -- 467
			} -- 467
		}, -- 467
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 50, label = "土星"}, {planetIndex = 3, tolerance = 60, label = "天王星"}, {planetIndex = 4, tolerance = 70, label = "海王星"}}}, -- 470
		dvBudget = 55, -- 485
		escapeRadius = 700, -- 486
		maxSteps = 2400, -- 487
		homeRadius = 1.25 -- 488
	}, -- 488
	{ -- 490
		id = 6, -- 491
		title = "单程", -- 492
		brief = "航行日志 · 第 12 年：没有回程了。四颗巨行星还会连成一条线 —— 等到那一天（拖动时间轴），沿着这条线依次穿过去，再越过 260 单位，就是星际空间。", -- 493
		probeStart = {x = 0, y = ORBIT.earth}, -- 494
		planets = { -- 495
			sun(), -- 496
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 29.3), -- 502
			orbiter(2000, R_SATURN, ORBIT.saturn, 48.2), -- 503
			orbiter(1200, R_URANUS, ORBIT.uranus, 58.9), -- 504
			orbiter(8000, R_NEPTUNE, ORBIT.neptune, 65.7) -- 505
		}, -- 505
		visuals = { -- 507
			sunVisual(), -- 508
			{ -- 509
				r = 0.85, -- 509
				g = 0.72, -- 509
				b = 0.5, -- 509
				displayRadius = R_JUPITER, -- 509
				ring = false, -- 509
				model = "Planet_Jupiter" -- 509
			}, -- 509
			{ -- 510
				r = 0.75, -- 510
				g = 0.7, -- 510
				b = 0.6, -- 510
				displayRadius = R_SATURN, -- 510
				ring = true, -- 510
				model = "Planet_Saturn" -- 510
			}, -- 510
			{ -- 511
				r = 0.62, -- 511
				g = 0.82, -- 511
				b = 0.86, -- 511
				displayRadius = R_URANUS, -- 511
				ring = false, -- 511
				model = "Planet_Uranus" -- 511
			}, -- 511
			{ -- 512
				r = 0.34, -- 512
				g = 0.5, -- 512
				b = 0.86, -- 512
				displayRadius = R_NEPTUNE, -- 512
				ring = false, -- 512
				model = "Planet_Neptune" -- 512
			} -- 512
		}, -- 512
		goal = {kind = "escape", planetIndex = -1, tolerance = 0, chain = {{planetIndex = 1, tolerance = 40, label = "木星"}, {planetIndex = 2, tolerance = 50, label = "土星"}, {planetIndex = 3, tolerance = 60, label = "天王星"}, {planetIndex = 4, tolerance = 70, label = "海王星"}}}, -- 520
		dvBudget = 50, -- 532
		escapeRadius = 260, -- 533
		maxSteps = 2400, -- 534
		homeRadius = 1, -- 535
		timeWindow = {span = 300} -- 539
	} -- 539
} -- 539
--- 关卡总数。
function ____exports.levelCount() -- 544
	return #LEVELS -- 545
end -- 544
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 549
	return LEVELS[index + 1] -- 550
end -- 549
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 554
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 555
end -- 554
return ____exports -- 554