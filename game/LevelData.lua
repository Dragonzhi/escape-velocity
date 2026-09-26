-- [ts]: LevelData.ts
local ____exports = {} -- 1
local applyScalesLocal -- 1
local ____Gravity = require("game.Gravity") -- 28
local bodyPositionAt = ____Gravity.bodyPositionAt -- 28
local distance = ____Gravity.distance -- 28
local ____Config = require("game.Config") -- 29
local GravityScale = ____Config.GravityScale -- 29
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 29
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 414
	local out = {} -- 415
	for ____, b in ipairs(bodies) do -- 416
		out[#out + 1] = { -- 417
			gm = b.gm * gravityScale, -- 418
			radius = b.radius, -- 419
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 420
			orbitRadius = b.orbitRadius, -- 421
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 422
			phase0 = b.phase0, -- 423
			orbitDirection = b.orbitDirection -- 424
		} -- 424
	end -- 424
	return out -- 427
end -- 427
--- 太阳的引力强度（`v_circ(80) = sqrt(SunGm/80) ≈ 30`，逃逸速度 42.4）。
____exports.SunGm = 72000 -- 107
--- 太阳的半径（撞毁半径 = 显示半径，尺寸公平性硬约束）。
-- 
-- ⚠️ 2026-09-26 用户参考图（docs/比例尺效果展示图.excalidraw）给的比值：
--   最内圈轨道 ≈ **1.9 个太阳半径**、太阳直径 ≈ 屏幕宽度的 0.38、行星 ≈ 太阳的 0.19。
--   原来取 7.0（轨道 = 7.9~27.9 个太阳半径）⇒ 太阳在画面里像一颗行星，"尺度很怪"的根因之一。
--   改成 28 之后：轨道 55/80/105/135/165/195 = 1.96/2.86/3.75/4.8/5.9/7.0 个太阳半径，与参考图一致。
____exports.SunRadius = 28 -- 117
--- 开普勒周期系数：`T = KeplerK · r^1.5`（秒）。
-- 
-- 相对快慢 = 真实开普勒（内快外慢），绝对速率被压缩 —— `KeplerK = 1` 相当于把真实值除以 42.7
-- （真实：`T = 2π·r^1.5/sqrt(SunGm) = 0.0234·r^1.5`）。这样飞行十几秒里行星只挪几度。
____exports.KeplerK = 1 -- 125
--- 开普勒周期（秒）：r 单位是平面单位。r <= 0 返回 0（静止）。
function ____exports.keplerPeriod(orbitRadius) -- 128
	if orbitRadius <= 0 then -- 128
		return 0 -- 129
	end -- 129
	return ____exports.KeplerK * orbitRadius ^ 1.5 -- 130
end -- 128
--- 度 → 弧度（关卡数据里写角度比写弧度好读）。
local function deg(d) -- 134
	return d * math.pi / 180 -- 135
end -- 134
local R_MOON = 1 -- 139
local R_VENUS = 1.72 -- 140
local R_EARTH = 1.76 -- 141
local R_JUPITER = 4.63 -- 142
local R_SATURN = 4.3 -- 143
local R_URANUS = 3.04 -- 144
local R_NEPTUNE = 3 -- 145
--- 巡航轨道半径（压缩太阳系：顺序真实、比例压缩）—— 一律绕原点（太阳）。
local ORBIT = { -- 148
	venus = 55, -- 148
	earth = 80, -- 148
	jupiter = 105, -- 148
	saturn = 135, -- 148
	uranus = 165, -- 148
	neptune = 195 -- 148
} -- 148
--- 掠过环的容差（flyby）：比本体大 13 左右 —— 远距离飞行要有"够得着"的手感。
local FLYBY_PAD = 13 -- 151
--- 在飞行采样点中找第一个进入目标容差的索引。
-- 
-- 目标行星在移动，所以逐点用 `t = t0 + i * dt` 时的行星位置判定（`t0` = 发射时刻）。
-- `dt` 必须是**采样点之间的有效步长**（采样间隔 N 步时传 `N * PhysicsStep`）。
-- 返回 -1 表示未到达。
function ____exports.goalWaypoints(goal) -- 160
	if goal.chain ~= nil then -- 160
		return goal.chain -- 161
	end -- 161
	if goal.kind == "planet" then -- 161
		return {{planetIndex = goal.planetIndex, tolerance = goal.tolerance}} -- 162
	end -- 162
	return {} -- 163
end -- 160
--- 顺序航线的进度：返回在 points[0..upto] 里**依次**掠过的航点数与最后一个命中索引。
-- 
-- 一次线性扫描：航点必须按顺序命中，且后一个必须出现在更晚的采样点上
-- （"先到土星再路过木星"不算数）。upto 用于飞行中查询"到哪一段了"（画环的明暗）。
function ____exports.waypointProgress(points, bodies, goal, dt, t0, upto) -- 172
	local wps = ____exports.goalWaypoints(goal) -- 180
	local start = t0 ~= nil and t0 or 0 -- 181
	local limit = #points - 1 -- 182
	if upto ~= nil and upto >= 0 and upto < limit then -- 182
		limit = upto -- 183
	end -- 183
	local next = 0 -- 184
	local lastIndex = -1 -- 185
	do -- 185
		local i = 0 -- 186
		while i <= limit and next < #wps do -- 186
			local w = wps[next + 1] -- 187
			local body = bodies[w.planetIndex + 1] -- 188
			if body == nil then -- 188
				return {passed = 0, lastIndex = -1} -- 189
			end -- 189
			local gp = bodyPositionAt(body, start + i * dt) -- 190
			if distance(points[i + 1], gp) < w.tolerance then -- 190
				next = next + 1 -- 192
				lastIndex = i -- 193
			end -- 193
			i = i + 1 -- 186
		end -- 186
	end -- 186
	return {passed = next, lastIndex = lastIndex} -- 196
end -- 172
function ____exports.findGoalIndex(points, bodies, goal, dt, t0) -- 199
	local wps = ____exports.goalWaypoints(goal) -- 200
	if #wps == 0 then -- 200
		return -1 -- 201
	end -- 201
	local st = ____exports.waypointProgress( -- 202
		points, -- 202
		bodies, -- 202
		goal, -- 202
		dt, -- 202
		t0 -- 202
	) -- 202
	return st.passed >= #wps and st.lastIndex or -1 -- 203
end -- 199
--- 太阳（除 L1 外每关的第 0 号天体）。
local function sun() -- 211
	return { -- 212
		gm = ____exports.SunGm, -- 212
		radius = ____exports.SunRadius, -- 212
		orbitCenter = {x = 0, y = 0}, -- 212
		orbitRadius = 0, -- 212
		orbitPeriod = 0, -- 212
		phase0 = 0, -- 212
		orbitDirection = 1 -- 212
	} -- 212
end -- 211
--- 太阳的视觉（亮黄，模型 Sun.glb）。
local function sunVisual() -- 216
	return { -- 217
		r = 1, -- 217
		g = 0.9, -- 217
		b = 0.62, -- 217
		displayRadius = ____exports.SunRadius, -- 217
		ring = false, -- 217
		model = "Sun", -- 217
		emissive = {r = 0.95, g = 0.72, b = 0.3} -- 217
	} -- 217
end -- 216
--- 绕日公转的行星（S3.7：圆心 = 太阳 = 原点）。
local function orbiter(gm, radius, orbitRadius, phaseDeg) -- 221
	return { -- 222
		gm = gm, -- 223
		radius = radius, -- 223
		orbitCenter = {x = 0, y = 0}, -- 224
		orbitRadius = orbitRadius, -- 225
		orbitPeriod = ____exports.keplerPeriod(orbitRadius), -- 226
		phase0 = deg(phaseDeg), -- 227
		orbitDirection = 1 -- 228
	} -- 228
end -- 221
local LEVELS = { -- 232
	{ -- 233
		id = 1, -- 234
		title = "出发", -- 235
		brief = "航行日志 · 第 1 天：离开地球。这一段路很干净，没有大天体捣乱 —— 先把拖拽瞄准练熟。月球在正前方。", -- 236
		probeStart = {x = 0, y = 40}, -- 237
		planets = {{ -- 238
			gm = 0, -- 240
			radius = R_MOON, -- 240
			orbitCenter = {x = 0, y = -70}, -- 240
			orbitRadius = 0, -- 240
			orbitPeriod = 0, -- 240
			phase0 = 0, -- 240
			orbitDirection = 1 -- 240
		}}, -- 240
		visuals = {{ -- 242
			r = 0.56, -- 243
			g = 0.56, -- 243
			b = 0.6, -- 243
			displayRadius = R_MOON, -- 243
			ring = false -- 243
		}}, -- 243
		goal = {kind = "planet", planetIndex = 0, tolerance = 14}, -- 245
		dvBudget = 40, -- 246
		escapeRadius = 700, -- 247
		maxSteps = 1200, -- 248
		homeRadius = 1.75 -- 249
	}, -- 249
	{ -- 251
		id = 2, -- 252
		title = "修正", -- 253
		brief = "航行日志 · 第 12 天：太阳开始拽你了。别直着飞 —— 向内会加速，航线也会被掰弯。目标是掠过金星。", -- 254
		probeStart = {x = 0, y = ORBIT.earth}, -- 255
		planets = { -- 256
			sun(), -- 257
			orbiter(2600, R_VENUS, ORBIT.venus, 180) -- 259
		}, -- 259
		visuals = { -- 261
			sunVisual(), -- 262
			{ -- 263
				r = 0.9, -- 263
				g = 0.78, -- 263
				b = 0.55, -- 263
				displayRadius = R_VENUS, -- 263
				ring = false, -- 263
				model = "Planet_Venus" -- 263
			} -- 263
		}, -- 263
		goal = {kind = "planet", planetIndex = 1, tolerance = R_VENUS + FLYBY_PAD}, -- 265
		dvBudget = 45, -- 266
		escapeRadius = 700, -- 267
		maxSteps = 1500, -- 268
		homeRadius = 1.6 -- 269
	}, -- 269
	{ -- 271
		id = 3, -- 272
		title = "弹弓", -- 273
		brief = "航行日志 · 第 2 年：木星在外圈。想省力就从它背后绕过去 —— 它的引力会把你甩向土星。", -- 274
		probeStart = {x = 0, y = ORBIT.earth}, -- 275
		planets = { -- 276
			sun(), -- 277
			orbiter(4000, R_JUPITER, ORBIT.jupiter, 195.5), -- 280
			orbiter(0, R_SATURN, ORBIT.saturn, 198) -- 282
		}, -- 282
		visuals = { -- 284
			sunVisual(), -- 285
			{ -- 286
				r = 0.85, -- 286
				g = 0.72, -- 286
				b = 0.5, -- 286
				displayRadius = R_JUPITER, -- 286
				ring = false, -- 286
				model = "Planet_Jupiter" -- 286
			}, -- 286
			{ -- 287
				r = 0.75, -- 287
				g = 0.7, -- 287
				b = 0.6, -- 287
				displayRadius = R_SATURN, -- 287
				ring = true, -- 287
				model = "Planet_Saturn" -- 287
			} -- 287
		}, -- 287
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + 8, chain = {{planetIndex = 1, tolerance = R_JUPITER + 8, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 45, label = "土星"}}}, -- 290
		dvBudget = 55, -- 297
		escapeRadius = 700, -- 298
		maxSteps = 2400, -- 299
		homeRadius = 1.45 -- 300
	}, -- 300
	{ -- 302
		id = 4, -- 303
		title = "窗口", -- 304
		brief = "航行日志 · 第 3 年：木星一直在绕太阳走。挑一个它正好在你航线上的日期起飞 —— 拖动时间轴，看它挪位置。", -- 305
		probeStart = {x = 0, y = ORBIT.earth}, -- 306
		planets = { -- 307
			sun(), -- 308
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 315.5), -- 310
			orbiter(0, R_SATURN, ORBIT.saturn, 288) -- 311
		}, -- 311
		visuals = { -- 313
			sunVisual(), -- 314
			{ -- 315
				r = 0.85, -- 315
				g = 0.72, -- 315
				b = 0.5, -- 315
				displayRadius = R_JUPITER, -- 315
				ring = false, -- 315
				model = "Planet_Jupiter" -- 315
			}, -- 315
			{ -- 316
				r = 0.75, -- 316
				g = 0.7, -- 316
				b = 0.6, -- 316
				displayRadius = R_SATURN, -- 316
				ring = true, -- 316
				model = "Planet_Saturn" -- 316
			} -- 316
		}, -- 316
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 30, label = "土星"}}}, -- 319
		dvBudget = 50, -- 326
		escapeRadius = 700, -- 327
		maxSteps = 1800, -- 328
		homeRadius = 1.35, -- 329
		timeWindow = {span = ____exports.keplerPeriod(ORBIT.jupiter) / 3} -- 332
	}, -- 332
	{ -- 334
		id = 5, -- 335
		title = "大巡游", -- 336
		brief = "航行日志 · 第 5 年：一次点火，四颗巨行星。木星改向、土星续航、天王星微调 —— 最后到海王星。", -- 337
		probeStart = {x = 0, y = ORBIT.earth}, -- 338
		planets = { -- 339
			sun(), -- 340
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 195.5), -- 343
			orbiter(2000, R_SATURN, ORBIT.saturn, 203.1), -- 344
			orbiter(1200, R_URANUS, ORBIT.uranus, 209.7), -- 345
			orbiter(800, R_NEPTUNE, ORBIT.neptune, 216.4) -- 346
		}, -- 346
		visuals = { -- 348
			sunVisual(), -- 349
			{ -- 350
				r = 0.85, -- 350
				g = 0.72, -- 350
				b = 0.5, -- 350
				displayRadius = R_JUPITER, -- 350
				ring = false, -- 350
				model = "Planet_Jupiter" -- 350
			}, -- 350
			{ -- 351
				r = 0.75, -- 351
				g = 0.7, -- 351
				b = 0.6, -- 351
				displayRadius = R_SATURN, -- 351
				ring = true, -- 351
				model = "Planet_Saturn" -- 351
			}, -- 351
			{ -- 352
				r = 0.62, -- 352
				g = 0.82, -- 352
				b = 0.86, -- 352
				displayRadius = R_URANUS, -- 352
				ring = false, -- 352
				model = "Planet_Uranus" -- 352
			}, -- 352
			{ -- 353
				r = 0.34, -- 353
				g = 0.5, -- 353
				b = 0.86, -- 353
				displayRadius = R_NEPTUNE, -- 353
				ring = false, -- 353
				model = "Planet_Neptune" -- 353
			} -- 353
		}, -- 353
		goal = {kind = "planet", planetIndex = 1, tolerance = R_JUPITER + FLYBY_PAD, chain = {{planetIndex = 1, tolerance = R_JUPITER + 22, label = "木星"}, {planetIndex = 2, tolerance = R_SATURN + 26, label = "土星"}, {planetIndex = 3, tolerance = R_URANUS + 30, label = "天王星"}, {planetIndex = 4, tolerance = R_NEPTUNE + 34, label = "海王星"}}}, -- 356
		dvBudget = 55, -- 365
		escapeRadius = 700, -- 366
		maxSteps = 2400, -- 367
		homeRadius = 1.25 -- 368
	}, -- 368
	{ -- 370
		id = 6, -- 371
		title = "单程", -- 372
		brief = "航行日志 · 第 12 年：没有回程了。穿过四颗巨行星，飞出太阳系 —— 越过 260 单位就算离开。", -- 373
		probeStart = {x = 0, y = ORBIT.earth}, -- 374
		planets = { -- 375
			sun(), -- 376
			orbiter(9400, R_JUPITER, ORBIT.jupiter, 200), -- 377
			orbiter(7000, R_SATURN, ORBIT.saturn, 245), -- 378
			orbiter(3200, R_URANUS, ORBIT.uranus, 290), -- 379
			orbiter(2200, R_NEPTUNE, ORBIT.neptune, 335) -- 380
		}, -- 380
		visuals = { -- 382
			sunVisual(), -- 383
			{ -- 384
				r = 0.85, -- 384
				g = 0.72, -- 384
				b = 0.5, -- 384
				displayRadius = R_JUPITER, -- 384
				ring = false, -- 384
				model = "Planet_Jupiter" -- 384
			}, -- 384
			{ -- 385
				r = 0.75, -- 385
				g = 0.7, -- 385
				b = 0.6, -- 385
				displayRadius = R_SATURN, -- 385
				ring = true, -- 385
				model = "Planet_Saturn" -- 385
			}, -- 385
			{ -- 386
				r = 0.62, -- 386
				g = 0.82, -- 386
				b = 0.86, -- 386
				displayRadius = R_URANUS, -- 386
				ring = false, -- 386
				model = "Planet_Uranus" -- 386
			}, -- 386
			{ -- 387
				r = 0.34, -- 387
				g = 0.5, -- 387
				b = 0.86, -- 387
				displayRadius = R_NEPTUNE, -- 387
				ring = false, -- 387
				model = "Planet_Neptune" -- 387
			} -- 387
		}, -- 387
		goal = {kind = "escape", planetIndex = -1, tolerance = 0}, -- 390
		dvBudget = 50, -- 391
		escapeRadius = 260, -- 392
		maxSteps = 2400, -- 393
		homeRadius = 1 -- 394
	} -- 394
} -- 394
--- 关卡总数。
function ____exports.levelCount() -- 399
	return #LEVELS -- 400
end -- 399
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 404
	return LEVELS[index + 1] -- 405
end -- 404
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 409
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 410
end -- 409
return ____exports -- 409