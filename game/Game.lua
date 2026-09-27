-- [ts]: Game.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 26
local Vec3 = ____Dora.Vec3 -- 26
local ____Gravity = require("game.Gravity") -- 28
local bodyPositionAt = ____Gravity.bodyPositionAt -- 28
local distance = ____Gravity.distance -- 28
local simulate = ____Gravity.simulate -- 28
local sub = ____Gravity.sub -- 28
local ____Scene = require("game.Scene") -- 29
local planeToWorld = ____Scene.planeToWorld -- 29
local ____Projection = require("game.Projection") -- 32
local FLIP_Y = ____Projection.FLIP_Y -- 32
local HANDEDNESS = ____Projection.HANDEDNESS -- 32
local prepareCamera = ____Projection.prepareCamera -- 32
local projectPrepared = ____Projection.projectPrepared -- 32
local ____LevelData = require("game.LevelData") -- 33
local findGoalIndex = ____LevelData.findGoalIndex -- 33
local goalWaypoints = ____LevelData.goalWaypoints -- 33
local waypointProgress = ____LevelData.waypointProgress -- 33
local ____Config = require("game.Config") -- 35
local AimMinSpeed = ____Config.AimMinSpeed -- 36
local BrakeShare = ____Config.BrakeShare -- 36
local CameraFramingBudget = ____Config.CameraFramingBudget -- 36
local CameraTiltMax = ____Config.CameraTiltMax -- 36
local CameraTiltMin = ____Config.CameraTiltMin -- 36
local FlightPlayback = ____Config.FlightPlayback -- 36
local IntroCloseDist = ____Config.IntroCloseDist -- 36
local IntroDurationSec = ____Config.IntroDurationSec -- 37
local PhysicsStep = ____Config.PhysicsStep -- 37
local PredictSteps = ____Config.PredictSteps -- 37
local SlowMoCloseDist = ____Config.SlowMoCloseDist -- 37
local SlowMoFactor = ____Config.SlowMoFactor -- 37
local SlowMoFloorDist = ____Config.SlowMoFloorDist -- 37
local SlowMoRadiusFactor = ____Config.SlowMoRadiusFactor -- 38
local TimeWarpStep = ____Config.TimeWarpStep -- 38
--- 结算三态判定（手册 §5.8）。
-- 
-- 优先级：到达目标 > 逃逸目标达成 > 撞毁 > 错过。
-- （到达目标优先于撞毁：轨迹在到达点截断，撞毁点根本不会发生。）
-- 
-- ⚠️ **逃逸关 + 航线（chain）**：两个条件**都要**满足 —— 既走完航线，又真的越界（S3.11）。
-- L6「单程」用的就是这条：终章是"综合"，不能只朝任何方向猛推一下就赢。
-- 只走完航线没出去、或只出去没走航线，都是「错过」。
-- 
-- 全部输入在**发射瞬间**即可确定 —— 结算与飞行一样是确定性的。
function ____exports.resolveResult(outcome, goalIndex, goal) -- 71
	if goal.kind == "escape" then -- 71
		local wps = goalWaypoints(goal) -- 73
		if outcome == "escaped" and (#wps == 0 or goalIndex >= 0) then -- 73
			return "success" -- 74
		end -- 74
	elseif goalIndex >= 0 then -- 74
		return "success" -- 76
	end -- 76
	if outcome == "crashed" then -- 76
		return "crashed" -- 78
	end -- 78
	return "missed" -- 79
end -- 71
function ____exports.createCore() -- 141
	return { -- 142
		phase = "Aiming", -- 143
		aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}}, -- 144
		flight = nil, -- 145
		dt = PhysicsStep, -- 146
		brakeMode = false, -- 147
		t0 = 0, -- 148
		flightTime = 0, -- 149
		goalIndex = -1, -- 150
		result = nil, -- 151
		viewMode = "2D", -- 153
		playback = FlightPlayback, -- 155
		slowmo = false, -- 156
		slowmoBody = -1 -- 157
	} -- 157
end -- 141
--- 手动切换 2D/3D（右下角那颗按钮的唯一入口，S3.15）。
-- 
-- ⚠️ 按钮**不许自己翻转一个局部变量** —— 视图的唯一事实来源是 `GameCore.viewMode`，
-- 否则"按钮显示的"与"画出来的"迟早会分家（会话 38 那次"点了重试没反应"就是同一类根因）。
-- 
-- @returns 切换后的新视图（调用方据此同步按钮文字）。
function ____exports.coreToggleView(core) -- 169
	core.viewMode = core.viewMode == "2D" and "3D" or "2D" -- 170
	return core.viewMode -- 171
end -- 169
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.burnToMotion(burn, probeVel0, brakeMode, maxSteps) -- 189
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 195
	local share = brakeMode and BrakeShare or 1 -- 196
	local init = {x = v0.x + burn.x * share, y = v0.y + burn.y * share} -- 197
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 198
	local brake = brakeMode and mag > 0 and ({ -- 199
		dv = mag * (1 - share), -- 200
		startStep = math.floor(maxSteps / 2) -- 200
	}) or nil -- 200
	return {init = init, brake = brake} -- 202
end -- 189
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 211
	if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 211
		return -- 213
	end -- 213
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 214
	local motion = ____exports.burnToMotion(burn, base, core.brakeMode, level.maxSteps) -- 215
	local p0 = from ~= nil and from or level.probeStart -- 216
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = motion.init}, level.bodies, { -- 217
		steps = level.maxSteps, -- 220
		dt = core.dt, -- 220
		sampleEvery = 1, -- 220
		escapeRadius = level.escapeRadius, -- 220
		t0 = core.t0, -- 220
		brake = motion.brake -- 220
	}) -- 220
	core.flight = flight -- 222
	core.goalIndex = findGoalIndex( -- 223
		flight.points, -- 223
		level.bodies, -- 223
		level.goal, -- 223
		core.dt, -- 223
		core.t0, -- 223
		flight.velocities -- 223
	) -- 223
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 224
	core.flightTime = 0 -- 225
	core.slowmo = false -- 227
	core.slowmoBody = -1 -- 228
	core.phase = "Flying" -- 229
	core.viewMode = "3D" -- 231
end -- 211
--- 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
-- 
-- 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
-- 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
function ____exports.coreArm(core) -- 240
	if core.phase ~= "Aiming" then -- 240
		return false -- 241
	end -- 241
	core.phase = "Armed" -- 242
	return true -- 243
end -- 240
--- 取消瞄准（从 Armed 回到 Aiming）。
function ____exports.coreCancelArm(core) -- 247
	if core.phase ~= "Armed" then -- 247
		return false -- 248
	end -- 248
	core.phase = "Aiming" -- 249
	return true -- 250
end -- 247
--- 时间流（改发射日期）在当前相态下是否允许（S3.11）。
-- 
-- 只在**发射前**允许（Aiming / Armed）：
--  - 飞行用的是 `tWorld = t0 + flightTime`，飞行途中改 t0 等于把参考系整个挪走 ——
--    行星会在飞行路径底下跳位（会话 39 亲眼见过同源现象：物理对、模型错）；
--  - 结算之后改日期没有任何意义。
-- 
-- 提成导出函数是为了**可单测**（`Test/GameTest.ts` 的 time-warp-* 三条），
-- HUD 里的按钮开关（`AimInput.setTimeEnabled`）读的是同一个判据。
function ____exports.coreTimeWarpAllowed(core) -- 264
	return core.phase == "Aiming" or core.phase == "Armed" -- 265
end -- 264
--- 发射日期的**交棒**（S3.12 修 bug①，纯算术、可单测）。
-- 
-- 事实来源只有一个：`tWorld = core.t0 + core.flightTime`。发射前玩家用「加速 / 回退」
-- 拨出来的是瞄准期的世界时钟 `clock`，而 `coreLaunch` 是纯函数、只认 `core.t0` ——
-- 两者之间过去**没有人接**，于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"。
-- 
-- - `toT0 = true`（发射）：`clock → t0`；
-- - `toT0 = false`（重试）：`t0 → clock`（保留玩家挑好的日期，才能就着它继续调）。
-- 
-- ⚠️ 两种方向的 `t0 + clock` **都守恒** —— 这正是"交棒时画面不跳"的数学表述
-- （`dateNow()` 与瞄准期的 `tNow` 都等于 `t0 + clock`）。
function ____exports.coreHandoffDate(t0, clock, toT0) -- 281
	if toT0 then -- 281
		return {t0 = clock, clock = 0} -- 282
	end -- 282
	return {t0 = 0, clock = t0} -- 283
end -- 281
--- 取景锚点的索引（S3.12 的同款逻辑，提成纯函数）。
-- 
-- L2~L6 是太阳（gm 72000、不绕别的天体转）；L1 场里也有太阳（物理统一），所以六关一致。
-- 返回 -1 = 场里没有「不绕别人转」的天体。
-- 
-- S3.17 的慢动作触发也要用它：**锚点是舞台中心，不是被掠过的对象** ——
-- 太阳半径 28，任何 ≥3 的阈值系数都会让「整个太阳系」落在慢动作阈值里，机制直接失效。
function ____exports.anchorBodyIndex(bodies) -- 295
	local best = -1 -- 296
	do -- 296
		local i = 0 -- 297
		while i < #bodies do -- 297
			do -- 297
				local b = bodies[i + 1] -- 298
				if b.orbitRadius ~= 0 then -- 298
					goto __continue21 -- 299
				end -- 299
				if best < 0 or b.gm > bodies[best + 1].gm then -- 299
					best = i -- 300
				end -- 300
			end -- 300
			::__continue21:: -- 300
			i = i + 1 -- 297
		end -- 297
	end -- 297
	return best -- 302
end -- 295
--- S3.17 慢动作触发判定（纯函数，可单测）：「**最近接近任何天体**」。
-- 
-- 探测器与某个天体的距离进入阈值即算数 —— 抵达月球与掠过木星因此共用同一套手感。
-- 阈值 = `max(天体半径 × SlowMoRadiusFactor, SlowMoFloorDist)`（世界单位，理由见 Config）：
--   - 半径 × 系数：木星 23.2 / 土星 21.5 / 月球 8（地板）；
--   - **锚点天体（太阳）不参与**：它半径 28，乘出来比探测器出发距离（80）还大，
--     不排除就是六关全程慢动作。掠过景由取景里的锚点预算负责，不由慢动作负责。
-- 
-- @param anchor 锚点天体索引（-1 = 没有锚点）；传 anchorBodyIndex(bodies) 的结果。
-- @returns 触发的天体索引（**最近**的那个）；-1 = 不在任何天体的阈值内。
function ____exports.slowMotionBody(bodies, probe, t, anchor) -- 317
	local best = -1 -- 318
	local bestD = 1000000000 -- 319
	do -- 319
		local i = 0 -- 320
		while i < #bodies do -- 320
			do -- 320
				if i == anchor then -- 320
					goto __continue26 -- 321
				end -- 321
				local b = bodies[i + 1] -- 322
				local threshold = math.max(b.radius * SlowMoRadiusFactor, SlowMoFloorDist) -- 323
				local d = distance( -- 324
					probe, -- 324
					bodyPositionAt(b, t) -- 324
				) -- 324
				if d < threshold and d < bestD then -- 324
					bestD = d -- 326
					best = i -- 327
				end -- 327
			end -- 327
			::__continue26:: -- 327
			i = i + 1 -- 320
		end -- 320
	end -- 320
	return best -- 330
end -- 317
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 334
	if core.flight == nil then -- 334
		return 0 -- 335
	end -- 335
	local idx = math.floor(core.flightTime / core.dt) -- 336
	local last = #core.flight.points - 1 -- 337
	if idx > last then -- 337
		idx = last -- 338
	end -- 338
	if idx < 0 then -- 338
		idx = 0 -- 339
	end -- 339
	return idx -- 340
end -- 334
--- 推进核心状态。返回 true 表示这一帧进入了 Result。
-- 
-- 飞行终点 = min(自然终点, 目标到达点)：到达目标即刻成功收束。
-- 收束时把回放时间吸附到终点索引，冻结帧恰好停在到达/终点的位置。
-- 
-- ===== S3.17 掠过自动慢动作：全项目**唯一**的播放速度入口 =====
-- 
-- `level` 给了才判定（天体位置随时间动，需要 bodies + tWorld；测试与旧路径省略 = 不触发）。
-- 判定写在**推进之前**（用这一帧起始位置的探测器），结果落回 `core.slowmo` / `core.slowmoBody`
-- —— 相机取景与 HUD 读的就是这两个字段，全项目只有这一个地方写它们。
-- 有效倍速 = 手动档（1×/2×/4×）× (慢动作 ? SlowMoFactor : 1)，只改「每帧推进多少模拟时间」：
-- **不重算物理、不动确定性、不引入第二套时钟**（轨迹在发射那刻就已算完）。
function ____exports.coreUpdate(core, dt, level) -- 357
	if core.phase ~= "Flying" or core.flight == nil then -- 357
		return false -- 358
	end -- 358
	if level ~= nil then -- 358
		local idx = ____exports.coreProbeIndex(core) -- 362
		core.slowmoBody = ____exports.slowMotionBody( -- 363
			level.bodies, -- 363
			core.flight.points[idx + 1], -- 363
			core.t0 + core.flightTime, -- 363
			____exports.anchorBodyIndex(level.bodies) -- 363
		) -- 363
		core.slowmo = core.slowmoBody >= 0 -- 364
	end -- 364
	local speed = core.playback * (core.slowmo and SlowMoFactor or 1) -- 367
	core.flightTime = core.flightTime + dt * speed -- 368
	local naturalEnd = #core.flight.points - 1 -- 369
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 370
	if ____exports.coreProbeIndex(core) >= endIdx then -- 370
		core.flightTime = endIdx * core.dt -- 373
		core.phase = "Result" -- 374
		return true -- 375
	end -- 375
	return false -- 377
end -- 357
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core) -- 381
	core.phase = "Aiming" -- 382
	core.viewMode = "2D" -- 384
	core.flight = nil -- 385
	core.flightTime = 0 -- 386
	core.goalIndex = -1 -- 387
	core.result = nil -- 388
	core.slowmo = false -- 389
	core.slowmoBody = -1 -- 390
	core.aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 391
end -- 381
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 405
	if core.phase ~= "Result" then -- 405
		return false -- 406
	end -- 406
	core.phase = "LevelSelect" -- 407
	core.viewMode = "2D" -- 409
	core.flight = nil -- 410
	core.flightTime = 0 -- 411
	core.goalIndex = -1 -- 412
	core.result = nil -- 413
	core.slowmo = false -- 414
	core.slowmoBody = -1 -- 415
	return true -- 416
end -- 405
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 505
	local core = ____exports.createCore() -- 506
	--- 已经应用到节点上的视图（"" = 还没应用过）。每帧 applyView 都拿它对账。
	local appliedMode = "" -- 509
	--- **视图切换的唯一落点**（S3.15）。
	-- 
	-- 设计稿第 4 条："进关/瞄准在 2D → 按下发射自动切 3D → 飞行与结算留 3D → 重试回 2D"，
	-- 右下角再给一颗手动按钮兜底。这里读的是 `core.viewMode`（状态），**不读按钮**：
	-- 于是自动切换与手动切换走的是同一条路，也不会有"按钮显示的与画出来的分家"。
	-- 
	-- - 2D：收起 3D 世界 + 收起 3D 轨迹层（`trajectory.root`，它就是投影出来的预测线/尾迹/到达环），
	--   打开 2D 规划层，并让瞄准层**整屏**都能瞄（2D 里没有"自由观察"可做，"探测器附近"那条分区
	--   规则会把大半屏变成死区）；
	-- - 3D：反过来。两边的 DrawNode 都挂在关卡 2D 层上，**隐藏时必须清空**（硬约束 8）。
	-- 
	-- 每帧调用一次是**幂等**的：`mode === appliedMode` 直接早退（不动节点、不刷日志）。
	local function applyView() -- 524
		local mode = core.viewMode -- 525
		if mode == appliedMode then -- 525
			return -- 526
		end -- 526
		appliedMode = mode -- 527
		local is2D = mode == "2D" -- 528
		deps.plan:setVisible(is2D) -- 529
		deps.trajectory.root.visible = not is2D -- 530
		deps:setWorldVisible(not is2D) -- 531
		deps.aim:setFullScreenAim(is2D) -- 532
		print(((("[escape-velocity] view -> " .. mode) .. " (phase=") .. core.phase) .. ")") -- 533
	end -- 524
	local function makeBasis(frame) -- 536
		return prepareCamera({ -- 537
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 539
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 540
			up = {x = 0, y = 1, z = 0}, -- 541
			fovYDeg = deps.fovYDeg, -- 542
			aspect = deps.aspect, -- 543
			viewW = deps.viewW, -- 544
			viewH = deps.viewH -- 545
		}, HANDEDNESS, FLIP_Y) -- 545
	end -- 536
	local predKey = "" -- 554
	local predPoints = {} -- 555
	local introT = IntroDurationSec -- 557
	local introLogged = false -- 558
	local clock = 0 -- 564
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 566
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 568
	local obsYawDeg = 0 -- 572
	local obsPitchDeg = 0 -- 573
	local obsZoom = 1 -- 574
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 576
	local idlePath = nil -- 577
	--- 玩家**是否已经瞄过**（S3.12）。
	-- 
	-- 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	-- 调整过了再显示」。所以规则是：
	--   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	--   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	--     直到发射 / 重试 / 退出关卡才清掉。
	-- 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	local aimed = false -- 588
	--- S3.17：慢动作的上一帧状态（打迁移日志用）与飞行日志累加器（每 0.5 真实秒一行）。
	local lastSlowmo = false -- 590
	local lastSlowmoBody = -1 -- 591
	local flightLogT = 0 -- 592
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 594
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 595
	local function prepareIdle() -- 596
		clock = 0 -- 598
		core.t0 = 0 -- 599
		if level.probeVel0 == nil then -- 599
			idlePath = nil -- 601
			return -- 602
		end -- 602
		local idleSteps = level.maxSteps -- 610
		local v0x = level.probeVel0.x -- 611
		local v0y = level.probeVel0.y -- 612
		local v0 = math.sqrt(v0x * v0x + v0y * v0y) -- 613
		if v0 > 0.000001 then -- 613
			local bestD = 1000000000 -- 615
			for ____, b in ipairs(level.bodies) do -- 616
				do -- 616
					if b.gm <= 0 then -- 616
						goto __continue47 -- 617
					end -- 617
					local dx = b.orbitCenter.x - level.probeStart.x -- 618
					local dy = b.orbitCenter.y - level.probeStart.y -- 619
					local d = math.sqrt(dx * dx + dy * dy) -- 620
					if d < bestD then -- 620
						bestD = d -- 621
					end -- 621
				end -- 621
				::__continue47:: -- 621
			end -- 621
			if bestD > 0.000001 and bestD < 100000000 then -- 621
				local n = math.floor(2 * math.pi * bestD / v0 / core.dt + 0.5) -- 624
				if n > 60 and n < 40000 then -- 624
					idleSteps = n -- 625
				end -- 625
			end -- 625
		end -- 625
		idlePath = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = level.probeVel0.x, y = level.probeVel0.y}}, level.bodies, { -- 628
			steps = idleSteps, -- 631
			dt = core.dt, -- 631
			sampleEvery = 1, -- 631
			escapeRadius = level.escapeRadius, -- 631
			t0 = core.t0 -- 631
		}) -- 631
	end -- 596
	local function idleIndex() -- 634
		if idlePath == nil then -- 634
			return 0 -- 635
		end -- 635
		local n = #idlePath.points -- 636
		if n <= 1 then -- 636
			return 0 -- 637
		end -- 637
		local i = math.floor(orbitClock / core.dt) % n -- 638
		if i < 0 then -- 638
			i = 0 -- 639
		end -- 639
		return i -- 640
	end -- 634
	--- **锚点天体**：场里 gm 最大、且不绕别的天体转的那个（S3.12）。
	-- 
	-- L2~L6 是太阳（gm 72000，玩家绕的就是它）；L1 是地球（2600 —— 地月系里玩家绕的是地球，
	-- 而 L1 场里根本没有太阳）。取景与"空间宏大"都靠它：它必须**完整**在画面内。
	local anchorIdx = ____exports.anchorBodyIndex(level.bodies) -- 650
	local anchorDef = anchorIdx >= 0 and level.bodies[anchorIdx + 1] or nil -- 651
	--- 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。
	local function nextStationBody() -- 654
		local wps = goalWaypoints(level.goal) -- 655
		if #wps == 0 then -- 655
			return nil -- 656
		end -- 656
		local passed = 0 -- 657
		if core.flight ~= nil then -- 657
			local upto = math.floor(core.flightTime / core.dt) -- 659
			passed = waypointProgress( -- 660
				core.flight.points, -- 660
				level.bodies, -- 660
				level.goal, -- 660
				core.dt, -- 660
				core.t0, -- 660
				upto, -- 660
				core.flight.velocities -- 660
			).passed -- 660
		end -- 660
		if passed >= #wps then -- 660
			return nil -- 662
		end -- 662
		return level.bodies[wps[passed + 1].planetIndex + 1] -- 663
	end -- 654
	--- 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	-- 
	-- 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	-- 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	-- 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	-- 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	local function framingPoints(probe, t) -- 674
		local corePts = {probe} -- 677
		local coreRadii = {deps.scene.probeRadius} -- 678
		local next = nextStationBody() -- 679
		local nextTol = 0 -- 680
		if next ~= nil then -- 680
			corePts[#corePts + 1] = bodyPositionAt(next, t) -- 682
			local wps = goalWaypoints(level.goal) -- 683
			local passed = 0 -- 684
			if core.flight ~= nil then -- 684
				passed = waypointProgress( -- 686
					core.flight.points, -- 686
					level.bodies, -- 686
					level.goal, -- 686
					core.dt, -- 686
					core.t0, -- 686
					math.floor(core.flightTime / core.dt), -- 686
					core.flight.velocities -- 686
				).passed -- 686
			end -- 686
			if passed < #wps then -- 686
				nextTol = wps[passed + 1].tolerance -- 688
			end -- 688
			local r = nextTol > next.radius and nextTol or next.radius -- 689
			coreRadii[#coreRadii + 1] = r -- 690
		end -- 690
		if anchorDef == nil then -- 690
			return {pts = corePts, radii = coreRadii} -- 693
		end -- 693
		local withAnchorPts = { -- 694
			probe, -- 694
			bodyPositionAt(anchorDef, t) -- 694
		} -- 694
		local withAnchorRadii = {deps.scene.probeRadius, anchorDef.radius} -- 695
		do -- 695
			local i = 1 -- 696
			while i < #corePts do -- 696
				withAnchorPts[#withAnchorPts + 1] = corePts[i + 1] -- 697
				withAnchorRadii[#withAnchorRadii + 1] = coreRadii[i + 1] -- 698
				i = i + 1 -- 696
			end -- 696
		end -- 696
		local want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii) -- 700
		if want <= CameraFramingBudget then -- 700
			return {pts = withAnchorPts, radii = withAnchorRadii} -- 701
		end -- 701
		return {pts = corePts, radii = coreRadii} -- 702
	end -- 674
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 706
		local wps = goalWaypoints(level.goal) -- 707
		if #wps == 0 then -- 707
			return {} -- 708
		end -- 708
		local passed = 0 -- 709
		if upto ~= nil and core.flight ~= nil then -- 709
			passed = waypointProgress( -- 711
				core.flight.points, -- 711
				level.bodies, -- 711
				level.goal, -- 711
				core.dt, -- 711
				core.t0, -- 711
				upto, -- 711
				core.flight.velocities -- 711
			).passed -- 711
		end -- 711
		if passed >= #wps then -- 711
			return {} -- 716
		end -- 716
		local nextWp = wps[passed + 1] -- 717
		local body = level.bodies[nextWp.planetIndex + 1] -- 718
		if body == nil then -- 718
			return {} -- 719
		end -- 719
		return {{ -- 720
			center = bodyPositionAt(body, t), -- 720
			radius = nextWp.tolerance, -- 720
			passed = false -- 720
		}} -- 720
	end -- 706
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 724
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 724
			return f -- 725
		end -- 725
		local dx = f.eye.x - f.target.x -- 726
		local dy = f.eye.y - f.target.y -- 727
		local dz = f.eye.z - f.target.z -- 728
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 729
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 730
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 731
		local lo = CameraTiltMin * math.pi / 180 -- 732
		local hi = CameraTiltMax * math.pi / 180 -- 733
		if pitch < lo then -- 733
			pitch = lo -- 734
		end -- 734
		if pitch > hi then -- 734
			pitch = hi -- 735
		end -- 735
		local cp = math.cos(pitch) -- 736
		return { -- 737
			target = f.target, -- 738
			eye = Vec3( -- 739
				f.target.x + r * cp * math.sin(yaw), -- 740
				f.target.y + r * math.sin(pitch), -- 741
				f.target.z + r * cp * math.cos(yaw) -- 742
			) -- 742
		} -- 742
	end -- 724
	local function updateAiming(dt) -- 747
		deps.aim:setEnabled(true) -- 748
		local dragging = deps.aim:isDragging() -- 750
		if core.phase == "Aiming" and not dragging and idlePath ~= nil then -- 750
			clock = clock + dt -- 753
			orbitClock = orbitClock + dt -- 754
		end -- 754
		local idx = idleIndex() -- 756
		probePos = idlePath ~= nil and idlePath.points[idx + 1] or level.probeStart -- 757
		probeVel = idlePath ~= nil and idlePath.velocities[idx + 1] or (level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})) -- 758
		local tNow = core.t0 + clock -- 761
		deps.scene.syncBodies(tNow) -- 763
		deps.scene.syncProbe(probePos) -- 764
		if idlePath ~= nil and idx > 0 then -- 764
			deps.scene.faceVelocity(sub(probePos, idlePath.points[idx])) -- 765
		end -- 765
		deps.plan:syncBodies(level.bodies, deps.visuals, tNow) -- 767
		deps.plan:syncProbe(probePos, probeVel) -- 768
		local fr = framingPoints(probePos, tNow) -- 771
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 772
		if introT < IntroDurationSec then -- 772
			introT = introT + dt -- 776
			local k = introT / IntroDurationSec -- 777
			if k > 1 then -- 777
				k = 1 -- 778
			end -- 778
			if k >= 1 and not introLogged then -- 778
				introLogged = true -- 780
				print("[escape-velocity] intro camera done") -- 781
			end -- 781
			local wps0 = goalWaypoints(level.goal) -- 783
			local wpBody = #wps0 > 0 and level.bodies[wps0[1].planetIndex + 1] or nil -- 784
			local wide = frame -- 785
			local from = wide -- 786
			local to = wide -- 787
			local e = 0 -- 788
			if k < 0.35 then -- 788
				local pw = planeToWorld(probePos, 0) -- 790
				local dx = wide.eye.x - wide.target.x -- 791
				local dy = wide.eye.y - wide.target.y -- 792
				local dz = wide.eye.z - wide.target.z -- 793
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 794
				if len > 0.000001 then -- 794
					local s = IntroCloseDist / len -- 796
					dx = dx * s -- 797
					dy = dy * s -- 797
					dz = dz * s -- 797
				end -- 797
				from = { -- 799
					target = Vec3(pw.x, pw.y, pw.z), -- 799
					eye = Vec3(pw.x + dx, pw.y + dy, pw.z + dz) -- 799
				} -- 799
				e = k / 0.35 -- 800
			elseif k < 0.72 and wpBody ~= nil then -- 800
				local c = planeToWorld( -- 803
					bodyPositionAt(wpBody, tNow), -- 803
					0 -- 803
				) -- 803
				local dx = wide.eye.x - wide.target.x -- 804
				local dy = wide.eye.y - wide.target.y -- 805
				local dz = wide.eye.z - wide.target.z -- 806
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 807
				local want = math.max(24, wpBody.radius * 6) -- 808
				if len > 0.000001 then -- 808
					local s = want / len -- 810
					dx = dx * s -- 811
					dy = dy * s -- 811
					dz = dz * s -- 811
				end -- 811
				to = { -- 813
					target = Vec3(c.x, c.y, c.z), -- 813
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 813
				} -- 813
				e = (k - 0.35) / 0.37 -- 814
			elseif wpBody ~= nil then -- 814
				local c = planeToWorld( -- 817
					bodyPositionAt(wpBody, tNow), -- 817
					0 -- 817
				) -- 817
				local dx = wide.eye.x - wide.target.x -- 818
				local dy = wide.eye.y - wide.target.y -- 819
				local dz = wide.eye.z - wide.target.z -- 820
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 821
				local want = math.max(24, wpBody.radius * 6) -- 822
				if len > 0.000001 then -- 822
					local s = want / len -- 824
					dx = dx * s -- 825
					dy = dy * s -- 825
					dz = dz * s -- 825
				end -- 825
				from = { -- 827
					target = Vec3(c.x, c.y, c.z), -- 827
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 827
				} -- 827
				e = (k - 0.72) / 0.28 -- 828
			end -- 828
			local ease = 1 - (1 - e) * (1 - e) * (1 - e) -- 830
			frame = { -- 831
				target = Vec3(from.target.x + (to.target.x - from.target.x) * ease, from.target.y + (to.target.y - from.target.y) * ease, from.target.z + (to.target.z - from.target.z) * ease), -- 832
				eye = Vec3(from.eye.x + (to.eye.x - from.eye.x) * ease, from.eye.y + (to.eye.y - from.eye.y) * ease, from.eye.z + (to.eye.z - from.eye.z) * ease) -- 837
			} -- 837
		end -- 837
		frame = applyObserve(frame) -- 845
		deps.rig.apply(deps.camera, frame) -- 846
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 847
		local basis = makeBasis(frame) -- 848
		if core.viewMode == "2D" then -- 848
			local sp = deps.plan:probeScreen() -- 854
			deps.aim:setProbeOffset({x = sp.x - deps.viewW / 2, y = sp.y - deps.viewH / 2}) -- 855
		else -- 855
			local pp = projectPrepared( -- 857
				planeToWorld(probePos, 0), -- 857
				basis -- 857
			) -- 857
			if pp ~= nil then -- 857
				deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 858
			end -- 858
		end -- 858
		if not aimed then -- 858
			deps.trajectory:clearPrediction() -- 871
			deps.plan:clearPrediction() -- 872
			predKey = "" -- 873
		else -- 873
			local key = (((((((((((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(tNow, 2)) .. "|") .. __TS__NumberToFixed(probePos.x, 2)) .. ",") .. __TS__NumberToFixed(probePos.y, 2)) .. "|") .. (core.brakeMode and "B" or "C")) .. "|") .. __TS__NumberToFixed(idx, 0) -- 877
			if key ~= predKey then -- 877
				predKey = key -- 881
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 884
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 885
					steps = PredictSteps, -- 888
					dt = core.dt, -- 888
					sampleEvery = 4, -- 888
					escapeRadius = level.escapeRadius, -- 888
					t0 = tNow, -- 888
					brake = motion.brake -- 888
				}).points -- 888
			end -- 888
			deps.trajectory:setPrediction(predPoints, basis) -- 891
			deps.plan:setPrediction(predPoints) -- 893
		end -- 893
		local rings = goalRingsAt(tNow) -- 895
		deps.trajectory:setGoalRings(rings, basis) -- 896
		deps.trajectory:clearTrail() -- 897
		deps.plan:setGoalRings(rings) -- 899
		deps.plan:clearTrail() -- 900
		deps.plan:flush() -- 901
	end -- 747
	local function updateFlying(dt) -- 904
		deps.aim:setEnabled(false) -- 905
		local entered = ____exports.coreUpdate(core, dt, level) -- 908
		if core.flight == nil then -- 908
			return entered -- 909
		end -- 909
		local idx = ____exports.coreProbeIndex(core) -- 911
		local pos = core.flight.points[idx + 1] -- 912
		local tWorld = core.t0 + core.flightTime -- 916
		if core.slowmo ~= lastSlowmo or core.slowmoBody ~= lastSlowmoBody then -- 916
			lastSlowmo = core.slowmo -- 920
			lastSlowmoBody = core.slowmoBody -- 921
			local near = core.slowmoBody >= 0 and level.bodies[core.slowmoBody + 1] or nil -- 922
			local nearD = near ~= nil and distance( -- 923
				pos, -- 923
				bodyPositionAt(near, tWorld) -- 923
			) or 0 -- 923
			print((((((((("[escape-velocity] slow-mo " .. (core.slowmo and "engage" or "release")) .. " body#") .. __TS__NumberToFixed(core.slowmoBody, 0)) .. " r=") .. (near ~= nil and __TS__NumberToFixed(near.radius, 2) or "-")) .. " d=") .. __TS__NumberToFixed(nearD, 1)) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 924
		end -- 924
		flightLogT = flightLogT + dt -- 931
		if flightLogT >= 0.5 then -- 931
			flightLogT = 0 -- 933
			local total = (#core.flight.points - 1) * core.dt -- 934
			print(((((((((((("[escape-velocity] flight t=" .. __TS__NumberToFixed(core.flightTime, 2)) .. "/") .. __TS__NumberToFixed(total, 1)) .. " idx=") .. __TS__NumberToFixed(idx, 0)) .. " speed=") .. __TS__NumberToFixed(core.playback * (core.slowmo and SlowMoFactor or 1), 2)) .. " (playback=") .. __TS__NumberToFixed(core.playback, 0)) .. "x slowmo=") .. (core.slowmo and "1" or "0")) .. ")") -- 935
		end -- 935
		deps.scene.syncBodies(tWorld) -- 941
		deps.scene.syncProbe(pos) -- 942
		if idx > 0 then -- 942
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 944
		end -- 944
		local fr -- 951
		local closeDist = nil -- 952
		if core.slowmo and core.slowmoBody >= 0 then -- 952
			local near = level.bodies[core.slowmoBody + 1] -- 954
			fr = { -- 955
				pts = { -- 955
					pos, -- 955
					bodyPositionAt(near, tWorld) -- 955
				}, -- 955
				radii = {deps.scene.probeRadius, near.radius} -- 955
			} -- 955
			closeDist = SlowMoCloseDist -- 956
		else -- 956
			fr = framingPoints(pos, tWorld) -- 958
		end -- 958
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii, closeDist) -- 960
		deps.rig.apply(deps.camera, frame) -- 961
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 962
		local basis = makeBasis(frame) -- 963
		local trail = {} -- 966
		do -- 966
			local i = 0 -- 967
			while i <= idx do -- 967
				trail[#trail + 1] = core.flight.points[i + 1] -- 967
				i = i + 1 -- 967
			end -- 967
		end -- 967
		local rings = goalRingsAt(tWorld, idx) -- 968
		deps.trajectory:setTrail(trail, basis) -- 969
		deps.trajectory:setGoalRings(rings, basis) -- 970
		deps.plan:syncBodies(level.bodies, deps.visuals, tWorld) -- 973
		deps.plan:syncProbe(pos, core.flight.velocities[idx + 1]) -- 974
		deps.plan:setTrail(trail) -- 975
		deps.plan:clearPrediction() -- 976
		deps.plan:setGoalRings(rings) -- 977
		deps.plan:flush() -- 978
		return entered -- 980
	end -- 904
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 994
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 995
		core.t0 = next.t0 -- 996
		clock = next.clock -- 997
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 998
	end -- 994
	local function update(dt) -- 1001
		applyView() -- 1004
		if core.phase == "Aiming" or core.phase == "Armed" then -- 1004
			updateAiming(dt) -- 1006
		elseif core.phase == "Flying" then -- 1006
			local entered = updateFlying(dt) -- 1008
			if entered and core.result ~= nil then -- 1008
				deps:onResult(core.result) -- 1010
				deps:onPhase("Result") -- 1011
			end -- 1011
		end -- 1011
	end -- 1001
	return { -- 1017
		phase = function() return core.phase end, -- 1018
		result = function() return core.result end, -- 1019
		onAimDrag = function(____, a) -- 1020
			core.aim = a -- 1021
			aimed = true -- 1022
			introT = IntroDurationSec -- 1023
		end, -- 1020
		aimReady = function() -- 1025
			if not ____exports.coreArm(core) then -- 1025
				return -- 1026
			end -- 1026
			applyView() -- 1027
			deps:onPhase("Armed") -- 1028
		end, -- 1025
		launchArmed = function() -- 1030
			if core.phase ~= "Armed" then -- 1030
				return -- 1032
			end -- 1032
			handoffDate(true) -- 1033
			____exports.coreLaunch( -- 1034
				core, -- 1034
				core.aim.velocity, -- 1034
				level, -- 1034
				probePos, -- 1034
				probeVel -- 1034
			) -- 1034
			deps.trajectory:clearPrediction() -- 1035
			deps.plan:clearPrediction() -- 1036
			applyView() -- 1037
			deps:onPhase("Flying") -- 1038
		end, -- 1030
		armed = function() return core.phase == "Armed" end, -- 1040
		viewMode = function() return core.viewMode end, -- 1041
		toggleViewMode = function() -- 1042
			____exports.coreToggleView(core) -- 1044
			applyView() -- 1045
		end, -- 1042
		observeDrag = function(____, dx, dy) -- 1047
			introT = IntroDurationSec -- 1048
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 1049
			obsYawDeg = obsYawDeg + dx * 0.35 -- 1050
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 1051
			if obsPitchDeg > 40 then -- 1051
				obsPitchDeg = 40 -- 1052
			end -- 1052
			if obsPitchDeg < -40 then -- 1052
				obsPitchDeg = -40 -- 1053
			end -- 1053
		end, -- 1047
		observeZoom = function(____, deltaDist) -- 1055
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 1056
			if obsZoom < 0.4 then -- 1056
				obsZoom = 0.4 -- 1057
			end -- 1057
			if obsZoom > 1.8 then -- 1057
				obsZoom = 1.8 -- 1058
			end -- 1058
		end, -- 1055
		launch = function(____, v) -- 1060
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 1060
				return -- 1061
			end -- 1061
			handoffDate(true) -- 1062
			____exports.coreLaunch( -- 1064
				core, -- 1064
				v, -- 1064
				level, -- 1064
				probePos, -- 1064
				probeVel -- 1064
			) -- 1064
			deps.trajectory:clearPrediction() -- 1065
			deps.plan:clearPrediction() -- 1066
			applyView() -- 1067
			deps:onPhase("Flying") -- 1068
		end, -- 1060
		retry = function() -- 1070
			if core.phase ~= "Result" then -- 1070
				return -- 1071
			end -- 1071
			handoffDate(false) -- 1072
			aimed = false -- 1073
			____exports.coreRetry(core) -- 1074
			deps.trajectory:clearTrail() -- 1075
			deps.trajectory:clearPrediction() -- 1076
			deps.trajectory:clearGoalRings() -- 1077
			deps.plan:clearTrail() -- 1078
			deps.plan:clearPrediction() -- 1079
			deps.plan:clearGoalRings() -- 1080
			applyView() -- 1081
			deps:onPhase("Aiming") -- 1082
		end, -- 1070
		backToSelect = function() -- 1084
			if not ____exports.coreBackToSelect(core) then -- 1084
				return false -- 1085
			end -- 1085
			deps.aim:setEnabled(false) -- 1087
			deps.trajectory:clearTrail() -- 1088
			deps.trajectory:clearPrediction() -- 1089
			deps.trajectory:clearGoalRings() -- 1090
			deps.plan:clearTrail() -- 1091
			deps.plan:clearPrediction() -- 1092
			deps.plan:clearGoalRings() -- 1093
			applyView() -- 1094
			deps:onPhase("LevelSelect") -- 1095
			return true -- 1096
		end, -- 1084
		startLevel = function() -- 1098
			aimed = false -- 1101
			____exports.coreRetry(core) -- 1102
			introT = 0 -- 1103
			introLogged = false -- 1104
			prepareIdle() -- 1105
			deps.trajectory:clearTrail() -- 1106
			deps.trajectory:clearPrediction() -- 1107
			deps.trajectory:clearGoalRings() -- 1108
			deps.plan:clearTrail() -- 1109
			deps.plan:clearPrediction() -- 1110
			deps.plan:clearGoalRings() -- 1111
			appliedMode = "" -- 1114
			applyView() -- 1115
			deps:onPhase("Aiming") -- 1116
		end, -- 1098
		stepTime = function(____, dir, span) -- 1118
			if not ____exports.coreTimeWarpAllowed(core) then -- 1118
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 1122
				return -- 1123
			end -- 1123
			local span0 = span > 0 and span or 0 -- 1125
			clock = clock + dir * TimeWarpStep -- 1126
			if clock < 0 then -- 1126
				clock = 0 -- 1127
			end -- 1127
			if span0 > 0 and clock > span0 then -- 1127
				clock = span0 -- 1128
			end -- 1128
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 1130
		end, -- 1118
		dateNow = function() return core.t0 + clock end, -- 1132
		setBrakeMode = function(____, on) -- 1133
			core.brakeMode = on -- 1134
		end, -- 1133
		brakeMode = function() return core.brakeMode end, -- 1137
		setPlaybackSpeed = function(____, speed) -- 1138
			if speed ~= 1 and speed ~= 2 and speed ~= 4 then -- 1138
				return -- 1140
			end -- 1140
			core.playback = speed -- 1141
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (phase=") .. core.phase) .. ")") -- 1142
		end, -- 1138
		playbackSpeed = function() return core.playback end, -- 1144
		update = function(____, frameDt) return update(frameDt) end -- 1146
	} -- 1146
end -- 505
return ____exports -- 505