-- [ts]: Gravity.ts
local ____exports = {} -- 1
--- 避免除零的极小距离平方。
local MIN_DIST2 = 1e-12 -- 147
--- 两向量差。
function ____exports.sub(a, b) -- 150
	return {x = a.x - b.x, y = a.y - b.y} -- 151
end -- 150
--- 向量长度。
function ____exports.length(a) -- 155
	return math.sqrt(a.x * a.x + a.y * a.y) -- 156
end -- 155
--- 两点距离。
function ____exports.distance(a, b) -- 160
	local dx = a.x - b.x -- 161
	local dy = a.y - b.y -- 162
	return math.sqrt(dx * dx + dy * dy) -- 163
end -- 160
--- 行星在时刻 t 的位置。
-- `t` 的单位是秒，`t = 0` 即 `phase0` 描述的姿态。
function ____exports.bodyPositionAt(b, t) -- 170
	local c = b.host ~= nil and ____exports.bodyPositionAt(b.host, t) or b.orbitCenter -- 172
	local angle = b.phase0 -- 173
	if b.orbitPeriod ~= 0 then -- 173
		angle = angle + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 175
	end -- 175
	return { -- 177
		x = c.x + b.orbitRadius * math.cos(angle), -- 178
		y = c.y + b.orbitRadius * math.sin(angle) -- 179
	} -- 179
end -- 170
--- 点 p 在时刻 t 受到的引力加速度。
-- 平方反比：a = Σ gm_i * (q_i - p) / |q_i - p|³
function ____exports.accelerationAt(bodies, p, t) -- 187
	local ax = 0 -- 188
	local ay = 0 -- 189
	for ____, b in ipairs(bodies) do -- 190
		do -- 190
			local q = ____exports.bodyPositionAt(b, t) -- 191
			local dx = q.x - p.x -- 192
			local dy = q.y - p.y -- 193
			local d2 = dx * dx + dy * dy -- 194
			if d2 < MIN_DIST2 then -- 194
				goto __continue8 -- 195
			end -- 195
			local invd = 1 / math.sqrt(d2) -- 196
			local invd3 = invd * invd * invd -- 197
			ax = ax + b.gm * dx * invd3 -- 198
			ay = ay + b.gm * dy * invd3 -- 199
		end -- 199
		::__continue8:: -- 199
	end -- 199
	return {x = ax, y = ay} -- 201
end -- 187
--- 把全部天体在时刻 t 的位置写进 `out`（**预分配、原地覆盖**）。
-- 
-- 为什么要有它（B1，2026-09-28）：L1 换成真实阿波罗剖面后，一次预测推演要 **8000 步**，
-- 而每一步原本要算 **6 次** `bodyPositionAt`（加速度 3 次 + 碰撞检测 3 次，每次还带一次
-- 宿主链递归的 sin/cos）。滚动缓存之后每步只算 **3 次**，预测线耗时直接减半。
-- 结果与旧实现**逐位相同**（同一时刻、同一批位置、同一套算式，只是不再重复计算）。
local function fillPositions(bodies, t, out) -- 212
	do -- 212
		local i = 0 -- 213
		while i < #bodies do -- 213
			out[i + 1] = ____exports.bodyPositionAt(bodies[i + 1], t) -- 214
			i = i + 1 -- 213
		end -- 213
	end -- 213
end -- 212
--- 用**已算好的**天体位置求引力加速度（= `accelerationAt` 的缓存版，算式逐字相同）。
local function accelerationFrom(bodies, positions, p) -- 219
	local ax = 0 -- 220
	local ay = 0 -- 221
	do -- 221
		local i = 0 -- 222
		while i < #bodies do -- 222
			do -- 222
				local q = positions[i + 1] -- 223
				local dx = q.x - p.x -- 224
				local dy = q.y - p.y -- 225
				local d2 = dx * dx + dy * dy -- 226
				if d2 < MIN_DIST2 then -- 226
					goto __continue16 -- 227
				end -- 227
				local invd = 1 / math.sqrt(d2) -- 228
				local invd3 = invd * invd * invd -- 229
				ax = ax + bodies[i + 1].gm * dx * invd3 -- 230
				ay = ay + bodies[i + 1].gm * dy * invd3 -- 231
			end -- 231
			::__continue16:: -- 231
			i = i + 1 -- 222
		end -- 222
	end -- 222
	return {x = ax, y = ay} -- 233
end -- 219
--- 用**已算好的**天体位置做碰撞检测（= `collisionIndex` 的缓存版）。
local function collisionFrom(bodies, positions, p) -- 237
	do -- 237
		local i = 0 -- 238
		while i < #bodies do -- 238
			local q = positions[i + 1] -- 239
			local dx = q.x - p.x -- 240
			local dy = q.y - p.y -- 241
			if math.sqrt(dx * dx + dy * dy) < bodies[i + 1].radius then -- 241
				return i -- 242
			end -- 242
			i = i + 1 -- 238
		end -- 238
	end -- 238
	return -1 -- 244
end -- 237
--- 推进一步（半隐式欧拉 / 辛欧拉）。
-- 先更新速度、再用新速度更新位置 —— 对轨道运动足够稳定，且实现简单、完全确定。
function ____exports.step(state, bodies, t, dt) -- 251
	local a = ____exports.accelerationAt(bodies, state.pos, t) -- 252
	local vx = state.vel.x + a.x * dt -- 253
	local vy = state.vel.y + a.y * dt -- 254
	return {pos = {x = state.pos.x + vx * dt, y = state.pos.y + vy * dt}, vel = {x = vx, y = vy}} -- 255
end -- 251
--- 返回命中的行星索引；未命中返回 -1。
function ____exports.collisionIndex(bodies, p, t) -- 262
	do -- 262
		local i = 0 -- 263
		while i < #bodies do -- 263
			local b = bodies[i + 1] -- 264
			local q = ____exports.bodyPositionAt(b, t) -- 265
			local dx = q.x - p.x -- 266
			local dy = q.y - p.y -- 267
			if math.sqrt(dx * dx + dy * dy) < b.radius then -- 267
				return i -- 268
			end -- 268
			i = i + 1 -- 263
		end -- 263
	end -- 263
	return -1 -- 270
end -- 262
--- 从初始状态推演一段轨迹。
-- 
-- 确定性的关键：全程只用 `dt` 累加时间，不读任何外部时钟；
-- 同样的 (initial, bodies, opts) 必得同样的结果。
function ____exports.simulate(initial, bodies, opts) -- 279
	local sampleEvery = opts.sampleEvery > 0 and opts.sampleEvery or 1 -- 280
	local s = {pos = {x = initial.pos.x, y = initial.pos.y}, vel = {x = initial.vel.x, y = initial.vel.y}} -- 282
	local points = {{x = s.pos.x, y = s.pos.y}} -- 287
	local velocities = {{x = s.vel.x, y = s.vel.y}} -- 288
	local outcome = "running" -- 289
	local hitIndex = -1 -- 290
	local stepsRun = 0 -- 291
	local t = opts.t0 ~= nil and opts.t0 or 0 -- 292
	local escape2 = opts.escapeRadius > 0 and opts.escapeRadius * opts.escapeRadius or 0 -- 294
	local bufA = {} -- 298
	local bufB = {} -- 299
	fillPositions(bodies, t, bufA) -- 300
	local curPositions = bufA -- 301
	local nextPositions = bufB -- 302
	local brake = opts.brake -- 305
	local brakeStart = brake ~= nil and (brake.startStep ~= nil and brake.startStep or math.floor(opts.steps / 2)) or -1 -- 306
	local brakeSteps = brake ~= nil and math.max(1, opts.steps - brakeStart) or 1 -- 307
	local brakeDvPerStep = brake ~= nil and brake.dv / brakeSteps or 0 -- 308
	do -- 308
		local i = 0 -- 310
		while i < opts.steps do -- 310
			local acc = accelerationFrom(bodies, curPositions, s.pos) -- 312
			local burn = opts.initialBurn -- 313
			local burnDt = burn ~= nil and math.max( -- 314
				0, -- 314
				math.min(opts.dt, burn.duration - i * opts.dt) -- 314
			) or 0 -- 314
			local nvx = s.vel.x + acc.x * opts.dt + (burn ~= nil and burn.acceleration.x * burnDt or 0) -- 315
			local nvy = s.vel.y + acc.y * opts.dt + (burn ~= nil and burn.acceleration.y * burnDt or 0) -- 316
			s = {pos = {x = s.pos.x + nvx * opts.dt, y = s.pos.y + nvy * opts.dt}, vel = {x = nvx, y = nvy}} -- 317
			t = t + opts.dt -- 318
			stepsRun = stepsRun + 1 -- 319
			if brake ~= nil and i >= brakeStart then -- 319
				local sp = math.sqrt(s.vel.x * s.vel.x + s.vel.y * s.vel.y) -- 322
				if sp > 1e-9 then -- 322
					local dv = sp > brakeDvPerStep and brakeDvPerStep or sp -- 325
					s = {pos = s.pos, vel = {x = s.vel.x - s.vel.x / sp * dv, y = s.vel.y - s.vel.y / sp * dv}} -- 326
				end -- 326
			end -- 326
			local tmp = curPositions -- 334
			curPositions = nextPositions -- 335
			nextPositions = tmp -- 336
			fillPositions(bodies, t, curPositions) -- 337
			local hit = collisionFrom(bodies, curPositions, s.pos) -- 339
			if hit >= 0 then -- 339
				outcome = "crashed" -- 341
				hitIndex = hit -- 342
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 343
				velocities[#velocities + 1] = {x = s.vel.x, y = s.vel.y} -- 344
				break -- 345
			end -- 345
			if escape2 > 0 and s.pos.x * s.pos.x + s.pos.y * s.pos.y > escape2 then -- 345
				outcome = "escaped" -- 349
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 350
				velocities[#velocities + 1] = {x = s.vel.x, y = s.vel.y} -- 351
				break -- 352
			end -- 352
			if i % sampleEvery == 0 then -- 352
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 356
				velocities[#velocities + 1] = {x = s.vel.x, y = s.vel.y} -- 357
			end -- 357
			i = i + 1 -- 310
		end -- 310
	end -- 310
	return { -- 361
		outcome = outcome, -- 361
		points = points, -- 361
		velocities = velocities, -- 361
		state = s, -- 361
		hitIndex = hitIndex, -- 361
		stepsRun = stepsRun -- 361
	} -- 361
end -- 279
--- 圆轨道速度：在距中心 `radius` 处、中心引力强度为 `gm` 时的环绕速度。
-- 用于关卡设计与测试（验证圆轨道不会向外飞或向内掉）。
function ____exports.orbitalSpeed(gm, radius) -- 368
	if radius <= 0 then -- 368
		return 0 -- 369
	end -- 369
	return math.sqrt(gm / radius) -- 370
end -- 368
--- 应用全局倍率，生成新的行星数组（不修改入参）。
-- 
-- - `gravityScale` 乘到 `gm`（统一调难度）
-- - `orbitScale` 除到 `orbitPeriod`（速度倍率；period 越小越快）
-- 
-- 放在这里而不是各调用方，是为了让“倍率语义”只有一处实现。
function ____exports.applyScales(bodies, gravityScale, orbitScale) -- 381
	local out = {} -- 382
	for ____, b in ipairs(bodies) do -- 383
		out[#out + 1] = { -- 384
			gm = b.gm * gravityScale, -- 385
			radius = b.radius, -- 386
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 387
			orbitRadius = b.orbitRadius, -- 388
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 389
			phase0 = b.phase0, -- 390
			orbitDirection = b.orbitDirection -- 391
		} -- 391
	end -- 391
	return out -- 394
end -- 381
--- 星尘在时刻 t 的位置。
-- 给了轨道就按公转求；没有（或半径为 0）就钉在 fallback 上。
function ____exports.starPositionAt(orbit, fallback, t) -- 407
	if orbit == nil or orbit.orbitRadius <= 0 then -- 407
		return {x = fallback.x, y = fallback.y} -- 408
	end -- 408
	return ____exports.bodyPositionAt(orbit, t) -- 409
end -- 407
--- 评估轨迹收集到的星尘。
-- 纯函数，预测线计算与实时飞行判定共用。
-- `starOrbits` 与 `stars` 一一对应时，用 `times[i]` 求第 i 个采样点当时的星尘位置。
-- 不传 `times` 或轨道 = 星尘静止在 `stars` 上（旧关卡 / 单点判定）。
function ____exports.evaluateCollectedStars(points, stars, collectRadius, starOrbits, times) -- 418
	if collectRadius == nil then -- 418
		collectRadius = 30 -- 421
	end -- 421
	local collected = {} -- 425
	do -- 425
		local i = 0 -- 426
		while i < #stars do -- 426
			collected[#collected + 1] = false -- 427
			i = i + 1 -- 426
		end -- 426
	end -- 426
	local count = 0 -- 429
	local r2 = collectRadius * collectRadius -- 430
	do -- 430
		local pi = 0 -- 431
		while pi < #points do -- 431
			local p = points[pi + 1] -- 432
			local t = times ~= nil and pi < #times and times[pi + 1] or 0 -- 433
			do -- 433
				local i = 0 -- 434
				while i < #stars do -- 434
					if not collected[i + 1] then -- 434
						local orbit = starOrbits ~= nil and starOrbits[i + 1] or nil -- 436
						local st = ____exports.starPositionAt(orbit, stars[i + 1], t) -- 437
						local dx = p.x - st.x -- 438
						local dy = p.y - st.y -- 439
						if dx * dx + dy * dy <= r2 then -- 439
							collected[i + 1] = true -- 441
							count = count + 1 -- 442
						end -- 442
					end -- 442
					i = i + 1 -- 434
				end -- 434
			end -- 434
			pi = pi + 1 -- 431
		end -- 431
	end -- 431
	return {collected = collected, count = count} -- 447
end -- 418
return ____exports -- 418