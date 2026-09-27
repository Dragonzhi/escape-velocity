-- [ts]: Game.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 26
local Vec3 = ____Dora.Vec3 -- 26
local ____Gravity = require("game.Gravity") -- 28
local bodyPositionAt = ____Gravity.bodyPositionAt -- 28
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
local TimeWarpStep = ____Config.TimeWarpStep -- 37
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
function ____exports.resolveResult(outcome, goalIndex, goal) -- 70
	if goal.kind == "escape" then -- 70
		local wps = goalWaypoints(goal) -- 72
		if outcome == "escaped" and (#wps == 0 or goalIndex >= 0) then -- 72
			return "success" -- 73
		end -- 73
	elseif goalIndex >= 0 then -- 73
		return "success" -- 75
	end -- 75
	if outcome == "crashed" then -- 75
		return "crashed" -- 77
	end -- 77
	return "missed" -- 78
end -- 70
function ____exports.createCore() -- 130
	return { -- 131
		phase = "Aiming", -- 132
		aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}}, -- 133
		flight = nil, -- 134
		dt = PhysicsStep, -- 135
		brakeMode = false, -- 136
		t0 = 0, -- 137
		flightTime = 0, -- 138
		goalIndex = -1, -- 139
		result = nil, -- 140
		viewMode = "2D" -- 142
	} -- 142
end -- 130
--- 手动切换 2D/3D（右下角那颗按钮的唯一入口，S3.15）。
-- 
-- ⚠️ 按钮**不许自己翻转一个局部变量** —— 视图的唯一事实来源是 `GameCore.viewMode`，
-- 否则"按钮显示的"与"画出来的"迟早会分家（会话 38 那次"点了重试没反应"就是同一类根因）。
-- 
-- @returns 切换后的新视图（调用方据此同步按钮文字）。
function ____exports.coreToggleView(core) -- 154
	core.viewMode = core.viewMode == "2D" and "3D" or "2D" -- 155
	return core.viewMode -- 156
end -- 154
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.burnToMotion(burn, probeVel0, brakeMode, maxSteps) -- 174
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 180
	local share = brakeMode and BrakeShare or 1 -- 181
	local init = {x = v0.x + burn.x * share, y = v0.y + burn.y * share} -- 182
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 183
	local brake = brakeMode and mag > 0 and ({ -- 184
		dv = mag * (1 - share), -- 185
		startStep = math.floor(maxSteps / 2) -- 185
	}) or nil -- 185
	return {init = init, brake = brake} -- 187
end -- 174
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 196
	if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 196
		return -- 198
	end -- 198
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 199
	local motion = ____exports.burnToMotion(burn, base, core.brakeMode, level.maxSteps) -- 200
	local p0 = from ~= nil and from or level.probeStart -- 201
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = motion.init}, level.bodies, { -- 202
		steps = level.maxSteps, -- 205
		dt = core.dt, -- 205
		sampleEvery = 1, -- 205
		escapeRadius = level.escapeRadius, -- 205
		t0 = core.t0, -- 205
		brake = motion.brake -- 205
	}) -- 205
	core.flight = flight -- 207
	core.goalIndex = findGoalIndex( -- 208
		flight.points, -- 208
		level.bodies, -- 208
		level.goal, -- 208
		core.dt, -- 208
		core.t0, -- 208
		flight.velocities -- 208
	) -- 208
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 209
	core.flightTime = 0 -- 210
	core.phase = "Flying" -- 211
	core.viewMode = "3D" -- 213
end -- 196
--- 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
-- 
-- 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
-- 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
function ____exports.coreArm(core) -- 222
	if core.phase ~= "Aiming" then -- 222
		return false -- 223
	end -- 223
	core.phase = "Armed" -- 224
	return true -- 225
end -- 222
--- 取消瞄准（从 Armed 回到 Aiming）。
function ____exports.coreCancelArm(core) -- 229
	if core.phase ~= "Armed" then -- 229
		return false -- 230
	end -- 230
	core.phase = "Aiming" -- 231
	return true -- 232
end -- 229
--- 时间流（改发射日期）在当前相态下是否允许（S3.11）。
-- 
-- 只在**发射前**允许（Aiming / Armed）：
--  - 飞行用的是 `tWorld = t0 + flightTime`，飞行途中改 t0 等于把参考系整个挪走 ——
--    行星会在飞行路径底下跳位（会话 39 亲眼见过同源现象：物理对、模型错）；
--  - 结算之后改日期没有任何意义。
-- 
-- 提成导出函数是为了**可单测**（`Test/GameTest.ts` 的 time-warp-* 三条），
-- HUD 里的按钮开关（`AimInput.setTimeEnabled`）读的是同一个判据。
function ____exports.coreTimeWarpAllowed(core) -- 246
	return core.phase == "Aiming" or core.phase == "Armed" -- 247
end -- 246
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
function ____exports.coreHandoffDate(t0, clock, toT0) -- 263
	if toT0 then -- 263
		return {t0 = clock, clock = 0} -- 264
	end -- 264
	return {t0 = 0, clock = t0} -- 265
end -- 263
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 269
	if core.flight == nil then -- 269
		return 0 -- 270
	end -- 270
	local idx = math.floor(core.flightTime / core.dt) -- 271
	local last = #core.flight.points - 1 -- 272
	if idx > last then -- 272
		idx = last -- 273
	end -- 273
	if idx < 0 then -- 273
		idx = 0 -- 274
	end -- 274
	return idx -- 275
end -- 269
--- 推进核心状态。返回 true 表示这一帧进入了 Result。
-- 
-- 飞行终点 = min(自然终点, 目标到达点)：到达目标即刻成功收束。
-- 收束时把回放时间吸附到终点索引，冻结帧恰好停在到达/终点的位置。
function ____exports.coreUpdate(core, dt) -- 284
	if core.phase ~= "Flying" or core.flight == nil then -- 284
		return false -- 285
	end -- 285
	core.flightTime = core.flightTime + dt * FlightPlayback -- 286
	local naturalEnd = #core.flight.points - 1 -- 287
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 288
	if ____exports.coreProbeIndex(core) >= endIdx then -- 288
		core.flightTime = endIdx * core.dt -- 291
		core.phase = "Result" -- 292
		return true -- 293
	end -- 293
	return false -- 295
end -- 284
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core) -- 299
	core.phase = "Aiming" -- 300
	core.viewMode = "2D" -- 302
	core.flight = nil -- 303
	core.flightTime = 0 -- 304
	core.goalIndex = -1 -- 305
	core.result = nil -- 306
	core.aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 307
end -- 299
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 321
	if core.phase ~= "Result" then -- 321
		return false -- 322
	end -- 322
	core.phase = "LevelSelect" -- 323
	core.viewMode = "2D" -- 325
	core.flight = nil -- 326
	core.flightTime = 0 -- 327
	core.goalIndex = -1 -- 328
	core.result = nil -- 329
	return true -- 330
end -- 321
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 412
	local core = ____exports.createCore() -- 413
	--- 已经应用到节点上的视图（"" = 还没应用过）。每帧 applyView 都拿它对账。
	local appliedMode = "" -- 416
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
	local function applyView() -- 431
		local mode = core.viewMode -- 432
		if mode == appliedMode then -- 432
			return -- 433
		end -- 433
		appliedMode = mode -- 434
		local is2D = mode == "2D" -- 435
		deps.plan:setVisible(is2D) -- 436
		deps.trajectory.root.visible = not is2D -- 437
		deps:setWorldVisible(not is2D) -- 438
		deps.aim:setFullScreenAim(is2D) -- 439
		print(((("[escape-velocity] view -> " .. mode) .. " (phase=") .. core.phase) .. ")") -- 440
	end -- 431
	local function makeBasis(frame) -- 443
		return prepareCamera({ -- 444
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 446
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 447
			up = {x = 0, y = 1, z = 0}, -- 448
			fovYDeg = deps.fovYDeg, -- 449
			aspect = deps.aspect, -- 450
			viewW = deps.viewW, -- 451
			viewH = deps.viewH -- 452
		}, HANDEDNESS, FLIP_Y) -- 452
	end -- 443
	local predKey = "" -- 461
	local predPoints = {} -- 462
	local introT = IntroDurationSec -- 464
	local introLogged = false -- 465
	local clock = 0 -- 471
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 473
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 475
	local obsYawDeg = 0 -- 479
	local obsPitchDeg = 0 -- 480
	local obsZoom = 1 -- 481
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 483
	local idlePath = nil -- 484
	--- 玩家**是否已经瞄过**（S3.12）。
	-- 
	-- 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	-- 调整过了再显示」。所以规则是：
	--   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	--   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	--     直到发射 / 重试 / 退出关卡才清掉。
	-- 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	local aimed = false -- 495
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 497
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 498
	local function prepareIdle() -- 499
		clock = 0 -- 501
		core.t0 = 0 -- 502
		if level.probeVel0 == nil then -- 502
			idlePath = nil -- 504
			return -- 505
		end -- 505
		local idleSteps = level.maxSteps -- 513
		local v0x = level.probeVel0.x -- 514
		local v0y = level.probeVel0.y -- 515
		local v0 = math.sqrt(v0x * v0x + v0y * v0y) -- 516
		if v0 > 0.000001 then -- 516
			local bestD = 1000000000 -- 518
			for ____, b in ipairs(level.bodies) do -- 519
				do -- 519
					if b.gm <= 0 then -- 519
						goto __continue36 -- 520
					end -- 520
					local dx = b.orbitCenter.x - level.probeStart.x -- 521
					local dy = b.orbitCenter.y - level.probeStart.y -- 522
					local d = math.sqrt(dx * dx + dy * dy) -- 523
					if d < bestD then -- 523
						bestD = d -- 524
					end -- 524
				end -- 524
				::__continue36:: -- 524
			end -- 524
			if bestD > 0.000001 and bestD < 100000000 then -- 524
				local n = math.floor(2 * math.pi * bestD / v0 / core.dt + 0.5) -- 527
				if n > 60 and n < 40000 then -- 527
					idleSteps = n -- 528
				end -- 528
			end -- 528
		end -- 528
		idlePath = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = level.probeVel0.x, y = level.probeVel0.y}}, level.bodies, { -- 531
			steps = idleSteps, -- 534
			dt = core.dt, -- 534
			sampleEvery = 1, -- 534
			escapeRadius = level.escapeRadius, -- 534
			t0 = core.t0 -- 534
		}) -- 534
	end -- 499
	local function idleIndex() -- 537
		if idlePath == nil then -- 537
			return 0 -- 538
		end -- 538
		local n = #idlePath.points -- 539
		if n <= 1 then -- 539
			return 0 -- 540
		end -- 540
		local i = math.floor(orbitClock / core.dt) % n -- 541
		if i < 0 then -- 541
			i = 0 -- 542
		end -- 542
		return i -- 543
	end -- 537
	--- **锚点天体**：场里 gm 最大、且不绕别的天体转的那个（S3.12）。
	-- 
	-- L2~L6 是太阳（gm 72000，玩家绕的就是它）；L1 是地球（2600 —— 地月系里玩家绕的是地球，
	-- 而 L1 场里根本没有太阳）。取景与"空间宏大"都靠它：它必须**完整**在画面内。
	local anchorDef = nil -- 552
	for ____, b in ipairs(level.bodies) do -- 553
		do -- 553
			if b.orbitRadius ~= 0 then -- 553
				goto __continue46 -- 554
			end -- 554
			if anchorDef == nil or b.gm > anchorDef.gm then -- 554
				anchorDef = b -- 555
			end -- 555
		end -- 555
		::__continue46:: -- 555
	end -- 555
	--- 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。
	local function nextStationBody() -- 559
		local wps = goalWaypoints(level.goal) -- 560
		if #wps == 0 then -- 560
			return nil -- 561
		end -- 561
		local passed = 0 -- 562
		if core.flight ~= nil then -- 562
			local upto = math.floor(core.flightTime / core.dt) -- 564
			passed = waypointProgress( -- 565
				core.flight.points, -- 565
				level.bodies, -- 565
				level.goal, -- 565
				core.dt, -- 565
				core.t0, -- 565
				upto, -- 565
				core.flight.velocities -- 565
			).passed -- 565
		end -- 565
		if passed >= #wps then -- 565
			return nil -- 567
		end -- 567
		return level.bodies[wps[passed + 1].planetIndex + 1] -- 568
	end -- 559
	--- 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	-- 
	-- 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	-- 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	-- 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	-- 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	local function framingPoints(probe, t) -- 579
		local corePts = {probe} -- 582
		local coreRadii = {deps.scene.probeRadius} -- 583
		local next = nextStationBody() -- 584
		local nextTol = 0 -- 585
		if next ~= nil then -- 585
			corePts[#corePts + 1] = bodyPositionAt(next, t) -- 587
			local wps = goalWaypoints(level.goal) -- 588
			local passed = 0 -- 589
			if core.flight ~= nil then -- 589
				passed = waypointProgress( -- 591
					core.flight.points, -- 591
					level.bodies, -- 591
					level.goal, -- 591
					core.dt, -- 591
					core.t0, -- 591
					math.floor(core.flightTime / core.dt), -- 591
					core.flight.velocities -- 591
				).passed -- 591
			end -- 591
			if passed < #wps then -- 591
				nextTol = wps[passed + 1].tolerance -- 593
			end -- 593
			local r = nextTol > next.radius and nextTol or next.radius -- 594
			coreRadii[#coreRadii + 1] = r -- 595
		end -- 595
		if anchorDef == nil then -- 595
			return {pts = corePts, radii = coreRadii} -- 598
		end -- 598
		local withAnchorPts = { -- 599
			probe, -- 599
			bodyPositionAt(anchorDef, t) -- 599
		} -- 599
		local withAnchorRadii = {deps.scene.probeRadius, anchorDef.radius} -- 600
		do -- 600
			local i = 1 -- 601
			while i < #corePts do -- 601
				withAnchorPts[#withAnchorPts + 1] = corePts[i + 1] -- 602
				withAnchorRadii[#withAnchorRadii + 1] = coreRadii[i + 1] -- 603
				i = i + 1 -- 601
			end -- 601
		end -- 601
		local want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii) -- 605
		if want <= CameraFramingBudget then -- 605
			return {pts = withAnchorPts, radii = withAnchorRadii} -- 606
		end -- 606
		return {pts = corePts, radii = coreRadii} -- 607
	end -- 579
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 611
		local wps = goalWaypoints(level.goal) -- 612
		if #wps == 0 then -- 612
			return {} -- 613
		end -- 613
		local passed = 0 -- 614
		if upto ~= nil and core.flight ~= nil then -- 614
			passed = waypointProgress( -- 616
				core.flight.points, -- 616
				level.bodies, -- 616
				level.goal, -- 616
				core.dt, -- 616
				core.t0, -- 616
				upto, -- 616
				core.flight.velocities -- 616
			).passed -- 616
		end -- 616
		if passed >= #wps then -- 616
			return {} -- 621
		end -- 621
		local nextWp = wps[passed + 1] -- 622
		local body = level.bodies[nextWp.planetIndex + 1] -- 623
		if body == nil then -- 623
			return {} -- 624
		end -- 624
		return {{ -- 625
			center = bodyPositionAt(body, t), -- 625
			radius = nextWp.tolerance, -- 625
			passed = false -- 625
		}} -- 625
	end -- 611
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 629
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 629
			return f -- 630
		end -- 630
		local dx = f.eye.x - f.target.x -- 631
		local dy = f.eye.y - f.target.y -- 632
		local dz = f.eye.z - f.target.z -- 633
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 634
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 635
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 636
		local lo = CameraTiltMin * math.pi / 180 -- 637
		local hi = CameraTiltMax * math.pi / 180 -- 638
		if pitch < lo then -- 638
			pitch = lo -- 639
		end -- 639
		if pitch > hi then -- 639
			pitch = hi -- 640
		end -- 640
		local cp = math.cos(pitch) -- 641
		return { -- 642
			target = f.target, -- 643
			eye = Vec3( -- 644
				f.target.x + r * cp * math.sin(yaw), -- 645
				f.target.y + r * math.sin(pitch), -- 646
				f.target.z + r * cp * math.cos(yaw) -- 647
			) -- 647
		} -- 647
	end -- 629
	local function updateAiming(dt) -- 652
		deps.aim:setEnabled(true) -- 653
		local dragging = deps.aim:isDragging() -- 655
		if core.phase == "Aiming" and not dragging and idlePath ~= nil then -- 655
			clock = clock + dt -- 658
			orbitClock = orbitClock + dt -- 659
		end -- 659
		local idx = idleIndex() -- 661
		probePos = idlePath ~= nil and idlePath.points[idx + 1] or level.probeStart -- 662
		probeVel = idlePath ~= nil and idlePath.velocities[idx + 1] or (level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})) -- 663
		local tNow = core.t0 + clock -- 666
		deps.scene.syncBodies(tNow) -- 668
		deps.scene.syncProbe(probePos) -- 669
		if idlePath ~= nil and idx > 0 then -- 669
			deps.scene.faceVelocity(sub(probePos, idlePath.points[idx])) -- 670
		end -- 670
		deps.plan:syncBodies(level.bodies, deps.visuals, tNow) -- 672
		deps.plan:syncProbe(probePos, probeVel) -- 673
		local fr = framingPoints(probePos, tNow) -- 676
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 677
		if introT < IntroDurationSec then -- 677
			introT = introT + dt -- 681
			local k = introT / IntroDurationSec -- 682
			if k > 1 then -- 682
				k = 1 -- 683
			end -- 683
			if k >= 1 and not introLogged then -- 683
				introLogged = true -- 685
				print("[escape-velocity] intro camera done") -- 686
			end -- 686
			local wps0 = goalWaypoints(level.goal) -- 688
			local wpBody = #wps0 > 0 and level.bodies[wps0[1].planetIndex + 1] or nil -- 689
			local wide = frame -- 690
			local from = wide -- 691
			local to = wide -- 692
			local e = 0 -- 693
			if k < 0.35 then -- 693
				local pw = planeToWorld(probePos, 0) -- 695
				local dx = wide.eye.x - wide.target.x -- 696
				local dy = wide.eye.y - wide.target.y -- 697
				local dz = wide.eye.z - wide.target.z -- 698
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 699
				if len > 0.000001 then -- 699
					local s = IntroCloseDist / len -- 701
					dx = dx * s -- 702
					dy = dy * s -- 702
					dz = dz * s -- 702
				end -- 702
				from = { -- 704
					target = Vec3(pw.x, pw.y, pw.z), -- 704
					eye = Vec3(pw.x + dx, pw.y + dy, pw.z + dz) -- 704
				} -- 704
				e = k / 0.35 -- 705
			elseif k < 0.72 and wpBody ~= nil then -- 705
				local c = planeToWorld( -- 708
					bodyPositionAt(wpBody, tNow), -- 708
					0 -- 708
				) -- 708
				local dx = wide.eye.x - wide.target.x -- 709
				local dy = wide.eye.y - wide.target.y -- 710
				local dz = wide.eye.z - wide.target.z -- 711
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 712
				local want = math.max(24, wpBody.radius * 6) -- 713
				if len > 0.000001 then -- 713
					local s = want / len -- 715
					dx = dx * s -- 716
					dy = dy * s -- 716
					dz = dz * s -- 716
				end -- 716
				to = { -- 718
					target = Vec3(c.x, c.y, c.z), -- 718
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 718
				} -- 718
				e = (k - 0.35) / 0.37 -- 719
			elseif wpBody ~= nil then -- 719
				local c = planeToWorld( -- 722
					bodyPositionAt(wpBody, tNow), -- 722
					0 -- 722
				) -- 722
				local dx = wide.eye.x - wide.target.x -- 723
				local dy = wide.eye.y - wide.target.y -- 724
				local dz = wide.eye.z - wide.target.z -- 725
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 726
				local want = math.max(24, wpBody.radius * 6) -- 727
				if len > 0.000001 then -- 727
					local s = want / len -- 729
					dx = dx * s -- 730
					dy = dy * s -- 730
					dz = dz * s -- 730
				end -- 730
				from = { -- 732
					target = Vec3(c.x, c.y, c.z), -- 732
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 732
				} -- 732
				e = (k - 0.72) / 0.28 -- 733
			end -- 733
			local ease = 1 - (1 - e) * (1 - e) * (1 - e) -- 735
			frame = { -- 736
				target = Vec3(from.target.x + (to.target.x - from.target.x) * ease, from.target.y + (to.target.y - from.target.y) * ease, from.target.z + (to.target.z - from.target.z) * ease), -- 737
				eye = Vec3(from.eye.x + (to.eye.x - from.eye.x) * ease, from.eye.y + (to.eye.y - from.eye.y) * ease, from.eye.z + (to.eye.z - from.eye.z) * ease) -- 742
			} -- 742
		end -- 742
		frame = applyObserve(frame) -- 750
		deps.rig.apply(deps.camera, frame) -- 751
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 752
		local basis = makeBasis(frame) -- 753
		if core.viewMode == "2D" then -- 753
			local sp = deps.plan:probeScreen() -- 759
			deps.aim:setProbeOffset({x = sp.x - deps.viewW / 2, y = sp.y - deps.viewH / 2}) -- 760
		else -- 760
			local pp = projectPrepared( -- 762
				planeToWorld(probePos, 0), -- 762
				basis -- 762
			) -- 762
			if pp ~= nil then -- 762
				deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 763
			end -- 763
		end -- 763
		if not aimed then -- 763
			deps.trajectory:clearPrediction() -- 776
			deps.plan:clearPrediction() -- 777
			predKey = "" -- 778
		else -- 778
			local key = (((((((((((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(tNow, 2)) .. "|") .. __TS__NumberToFixed(probePos.x, 2)) .. ",") .. __TS__NumberToFixed(probePos.y, 2)) .. "|") .. (core.brakeMode and "B" or "C")) .. "|") .. __TS__NumberToFixed(idx, 0) -- 782
			if key ~= predKey then -- 782
				predKey = key -- 786
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 789
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 790
					steps = PredictSteps, -- 793
					dt = core.dt, -- 793
					sampleEvery = 4, -- 793
					escapeRadius = level.escapeRadius, -- 793
					t0 = tNow, -- 793
					brake = motion.brake -- 793
				}).points -- 793
			end -- 793
			deps.trajectory:setPrediction(predPoints, basis) -- 796
			deps.plan:setPrediction(predPoints) -- 798
		end -- 798
		local rings = goalRingsAt(tNow) -- 800
		deps.trajectory:setGoalRings(rings, basis) -- 801
		deps.trajectory:clearTrail() -- 802
		deps.plan:setGoalRings(rings) -- 804
		deps.plan:clearTrail() -- 805
		deps.plan:flush() -- 806
	end -- 652
	local function updateFlying(dt) -- 809
		deps.aim:setEnabled(false) -- 810
		local entered = ____exports.coreUpdate(core, dt) -- 811
		if core.flight == nil then -- 811
			return entered -- 812
		end -- 812
		local idx = ____exports.coreProbeIndex(core) -- 814
		local pos = core.flight.points[idx + 1] -- 815
		local tWorld = core.t0 + core.flightTime -- 819
		deps.scene.syncBodies(tWorld) -- 821
		deps.scene.syncProbe(pos) -- 822
		if idx > 0 then -- 822
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 824
		end -- 824
		local fr = framingPoints(pos, tWorld) -- 827
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 828
		deps.rig.apply(deps.camera, frame) -- 829
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 830
		local basis = makeBasis(frame) -- 831
		local trail = {} -- 834
		do -- 834
			local i = 0 -- 835
			while i <= idx do -- 835
				trail[#trail + 1] = core.flight.points[i + 1] -- 835
				i = i + 1 -- 835
			end -- 835
		end -- 835
		local rings = goalRingsAt(tWorld, idx) -- 836
		deps.trajectory:setTrail(trail, basis) -- 837
		deps.trajectory:setGoalRings(rings, basis) -- 838
		deps.plan:syncBodies(level.bodies, deps.visuals, tWorld) -- 841
		deps.plan:syncProbe(pos, core.flight.velocities[idx + 1]) -- 842
		deps.plan:setTrail(trail) -- 843
		deps.plan:clearPrediction() -- 844
		deps.plan:setGoalRings(rings) -- 845
		deps.plan:flush() -- 846
		return entered -- 848
	end -- 809
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 862
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 863
		core.t0 = next.t0 -- 864
		clock = next.clock -- 865
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 866
	end -- 862
	local function update(dt) -- 869
		applyView() -- 872
		if core.phase == "Aiming" or core.phase == "Armed" then -- 872
			updateAiming(dt) -- 874
		elseif core.phase == "Flying" then -- 874
			local entered = updateFlying(dt) -- 876
			if entered and core.result ~= nil then -- 876
				deps:onResult(core.result) -- 878
				deps:onPhase("Result") -- 879
			end -- 879
		end -- 879
	end -- 869
	return { -- 885
		phase = function() return core.phase end, -- 886
		result = function() return core.result end, -- 887
		onAimDrag = function(____, a) -- 888
			core.aim = a -- 889
			aimed = true -- 890
			introT = IntroDurationSec -- 891
		end, -- 888
		aimReady = function() -- 893
			if not ____exports.coreArm(core) then -- 893
				return -- 894
			end -- 894
			applyView() -- 895
			deps:onPhase("Armed") -- 896
		end, -- 893
		launchArmed = function() -- 898
			if core.phase ~= "Armed" then -- 898
				return -- 900
			end -- 900
			handoffDate(true) -- 901
			____exports.coreLaunch( -- 902
				core, -- 902
				core.aim.velocity, -- 902
				level, -- 902
				probePos, -- 902
				probeVel -- 902
			) -- 902
			deps.trajectory:clearPrediction() -- 903
			deps.plan:clearPrediction() -- 904
			applyView() -- 905
			deps:onPhase("Flying") -- 906
		end, -- 898
		armed = function() return core.phase == "Armed" end, -- 908
		viewMode = function() return core.viewMode end, -- 909
		toggleViewMode = function() -- 910
			____exports.coreToggleView(core) -- 912
			applyView() -- 913
		end, -- 910
		observeDrag = function(____, dx, dy) -- 915
			introT = IntroDurationSec -- 916
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 917
			obsYawDeg = obsYawDeg + dx * 0.35 -- 918
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 919
			if obsPitchDeg > 40 then -- 919
				obsPitchDeg = 40 -- 920
			end -- 920
			if obsPitchDeg < -40 then -- 920
				obsPitchDeg = -40 -- 921
			end -- 921
		end, -- 915
		observeZoom = function(____, deltaDist) -- 923
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 924
			if obsZoom < 0.4 then -- 924
				obsZoom = 0.4 -- 925
			end -- 925
			if obsZoom > 1.8 then -- 925
				obsZoom = 1.8 -- 926
			end -- 926
		end, -- 923
		launch = function(____, v) -- 928
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 928
				return -- 929
			end -- 929
			handoffDate(true) -- 930
			____exports.coreLaunch( -- 932
				core, -- 932
				v, -- 932
				level, -- 932
				probePos, -- 932
				probeVel -- 932
			) -- 932
			deps.trajectory:clearPrediction() -- 933
			deps.plan:clearPrediction() -- 934
			applyView() -- 935
			deps:onPhase("Flying") -- 936
		end, -- 928
		retry = function() -- 938
			if core.phase ~= "Result" then -- 938
				return -- 939
			end -- 939
			handoffDate(false) -- 940
			aimed = false -- 941
			____exports.coreRetry(core) -- 942
			deps.trajectory:clearTrail() -- 943
			deps.trajectory:clearPrediction() -- 944
			deps.trajectory:clearGoalRings() -- 945
			deps.plan:clearTrail() -- 946
			deps.plan:clearPrediction() -- 947
			deps.plan:clearGoalRings() -- 948
			applyView() -- 949
			deps:onPhase("Aiming") -- 950
		end, -- 938
		backToSelect = function() -- 952
			if not ____exports.coreBackToSelect(core) then -- 952
				return false -- 953
			end -- 953
			deps.aim:setEnabled(false) -- 955
			deps.trajectory:clearTrail() -- 956
			deps.trajectory:clearPrediction() -- 957
			deps.trajectory:clearGoalRings() -- 958
			deps.plan:clearTrail() -- 959
			deps.plan:clearPrediction() -- 960
			deps.plan:clearGoalRings() -- 961
			applyView() -- 962
			deps:onPhase("LevelSelect") -- 963
			return true -- 964
		end, -- 952
		startLevel = function() -- 966
			aimed = false -- 969
			____exports.coreRetry(core) -- 970
			introT = 0 -- 971
			introLogged = false -- 972
			prepareIdle() -- 973
			deps.trajectory:clearTrail() -- 974
			deps.trajectory:clearPrediction() -- 975
			deps.trajectory:clearGoalRings() -- 976
			deps.plan:clearTrail() -- 977
			deps.plan:clearPrediction() -- 978
			deps.plan:clearGoalRings() -- 979
			appliedMode = "" -- 982
			applyView() -- 983
			deps:onPhase("Aiming") -- 984
		end, -- 966
		stepTime = function(____, dir, span) -- 986
			if not ____exports.coreTimeWarpAllowed(core) then -- 986
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 990
				return -- 991
			end -- 991
			local span0 = span > 0 and span or 0 -- 993
			clock = clock + dir * TimeWarpStep -- 994
			if clock < 0 then -- 994
				clock = 0 -- 995
			end -- 995
			if span0 > 0 and clock > span0 then -- 995
				clock = span0 -- 996
			end -- 996
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 998
		end, -- 986
		dateNow = function() return core.t0 + clock end, -- 1000
		setBrakeMode = function(____, on) -- 1001
			core.brakeMode = on -- 1002
		end, -- 1001
		brakeMode = function() return core.brakeMode end, -- 1005
		update = function(____, frameDt) return update(frameDt) end -- 1007
	} -- 1007
end -- 412
return ____exports -- 412