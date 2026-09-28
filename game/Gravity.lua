-- [ts]: Gravity.ts
local ____exports = {} -- 1
--- 避免除零的极小距离平方。
local MIN_DIST2 = 1e-12 -- 145
--- 两向量差。
function ____exports.sub(a, b) -- 148
	return {x = a.x - b.x, y = a.y - b.y} -- 149
end -- 148
--- 向量长度。
function ____exports.length(a) -- 153
	return math.sqrt(a.x * a.x + a.y * a.y) -- 154
end -- 153
--- 两点距离。
function ____exports.distance(a, b) -- 158
	local dx = a.x - b.x -- 159
	local dy = a.y - b.y -- 160
	return math.sqrt(dx * dx + dy * dy) -- 161
end -- 158
--- 行星在时刻 t 的位置。
-- `t` 的单位是秒，`t = 0` 即 `phase0` 描述的姿态。
function ____exports.bodyPositionAt(b, t) -- 168
	local c = b.host ~= nil and ____exports.bodyPositionAt(b.host, t) or b.orbitCenter -- 170
	local angle = b.phase0 -- 171
	if b.orbitPeriod ~= 0 then -- 171
		angle = angle + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 173
	end -- 173
	return { -- 175
		x = c.x + b.orbitRadius * math.cos(angle), -- 176
		y = c.y + b.orbitRadius * math.sin(angle) -- 177
	} -- 177
end -- 168
--- 点 p 在时刻 t 受到的引力加速度。
-- 平方反比：a = Σ gm_i * (q_i - p) / |q_i - p|³
function ____exports.accelerationAt(bodies, p, t) -- 185
	local ax = 0 -- 186
	local ay = 0 -- 187
	for ____, b in ipairs(bodies) do -- 188
		do -- 188
			local q = ____exports.bodyPositionAt(b, t) -- 189
			local dx = q.x - p.x -- 190
			local dy = q.y - p.y -- 191
			local d2 = dx * dx + dy * dy -- 192
			if d2 < MIN_DIST2 then -- 192
				goto __continue8 -- 193
			end -- 193
			local invd = 1 / math.sqrt(d2) -- 194
			local invd3 = invd * invd * invd -- 195
			ax = ax + b.gm * dx * invd3 -- 196
			ay = ay + b.gm * dy * invd3 -- 197
		end -- 197
		::__continue8:: -- 197
	end -- 197
	return {x = ax, y = ay} -- 199
end -- 185
--- 把全部天体在时刻 t 的位置写进 `out`（**预分配、原地覆盖**）。
-- 
-- 为什么要有它（B1，2026-09-28）：L1 换成真实阿波罗剖面后，一次预测推演要 **8000 步**，
-- 而每一步原本要算 **6 次** `bodyPositionAt`（加速度 3 次 + 碰撞检测 3 次，每次还带一次
-- 宿主链递归的 sin/cos）。滚动缓存之后每步只算 **3 次**，预测线耗时直接减半。
-- 结果与旧实现**逐位相同**（同一时刻、同一批位置、同一套算式，只是不再重复计算）。
local function fillPositions(bodies, t, out) -- 210
	do -- 210
		local i = 0 -- 211
		while i < #bodies do -- 211
			out[i + 1] = ____exports.bodyPositionAt(bodies[i + 1], t) -- 212
			i = i + 1 -- 211
		end -- 211
	end -- 211
end -- 210
--- 用**已算好的**天体位置求引力加速度（= `accelerationAt` 的缓存版，算式逐字相同）。
local function accelerationFrom(bodies, positions, p) -- 217
	local ax = 0 -- 218
	local ay = 0 -- 219
	do -- 219
		local i = 0 -- 220
		while i < #bodies do -- 220
			do -- 220
				local q = positions[i + 1] -- 221
				local dx = q.x - p.x -- 222
				local dy = q.y - p.y -- 223
				local d2 = dx * dx + dy * dy -- 224
				if d2 < MIN_DIST2 then -- 224
					goto __continue16 -- 225
				end -- 225
				local invd = 1 / math.sqrt(d2) -- 226
				local invd3 = invd * invd * invd -- 227
				ax = ax + bodies[i + 1].gm * dx * invd3 -- 228
				ay = ay + bodies[i + 1].gm * dy * invd3 -- 229
			end -- 229
			::__continue16:: -- 229
			i = i + 1 -- 220
		end -- 220
	end -- 220
	return {x = ax, y = ay} -- 231
end -- 217
--- 用**已算好的**天体位置做碰撞检测（= `collisionIndex` 的缓存版）。
local function collisionFrom(bodies, positions, p) -- 235
	do -- 235
		local i = 0 -- 236
		while i < #bodies do -- 236
			local q = positions[i + 1] -- 237
			local dx = q.x - p.x -- 238
			local dy = q.y - p.y -- 239
			if math.sqrt(dx * dx + dy * dy) < bodies[i + 1].radius then -- 239
				return i -- 240
			end -- 240
			i = i + 1 -- 236
		end -- 236
	end -- 236
	return -1 -- 242
end -- 235
--- 推进一步（半隐式欧拉 / 辛欧拉）。
-- 先更新速度、再用新速度更新位置 —— 对轨道运动足够稳定，且实现简单、完全确定。
function ____exports.step(state, bodies, t, dt) -- 249
	local a = ____exports.accelerationAt(bodies, state.pos, t) -- 250
	local vx = state.vel.x + a.x * dt -- 251
	local vy = state.vel.y + a.y * dt -- 252
	return {pos = {x = state.pos.x + vx * dt, y = state.pos.y + vy * dt}, vel = {x = vx, y = vy}} -- 253
end -- 249
--- 返回命中的行星索引；未命中返回 -1。
function ____exports.collisionIndex(bodies, p, t) -- 260
	do -- 260
		local i = 0 -- 261
		while i < #bodies do -- 261
			local b = bodies[i + 1] -- 262
			local q = ____exports.bodyPositionAt(b, t) -- 263
			local dx = q.x - p.x -- 264
			local dy = q.y - p.y -- 265
			if math.sqrt(dx * dx + dy * dy) < b.radius then -- 265
				return i -- 266
			end -- 266
			i = i + 1 -- 261
		end -- 261
	end -- 261
	return -1 -- 268
end -- 260
--- 从初始状态推演一段轨迹。
-- 
-- 确定性的关键：全程只用 `dt` 累加时间，不读任何外部时钟；
-- 同样的 (initial, bodies, opts) 必得同样的结果。
function ____exports.simulate(initial, bodies, opts) -- 277
	local sampleEvery = opts.sampleEvery > 0 and opts.sampleEvery or 1 -- 278
	local s = {pos = {x = initial.pos.x, y = initial.pos.y}, vel = {x = initial.vel.x, y = initial.vel.y}} -- 280
	local points = {{x = s.pos.x, y = s.pos.y}} -- 285
	local velocities = {{x = s.vel.x, y = s.vel.y}} -- 286
	local outcome = "running" -- 287
	local hitIndex = -1 -- 288
	local stepsRun = 0 -- 289
	local t = opts.t0 ~= nil and opts.t0 or 0 -- 290
	local escape2 = opts.escapeRadius > 0 and opts.escapeRadius * opts.escapeRadius or 0 -- 292
	local bufA = {} -- 296
	local bufB = {} -- 297
	fillPositions(bodies, t, bufA) -- 298
	local curPositions = bufA -- 299
	local nextPositions = bufB -- 300
	local brake = opts.brake -- 303
	local brakeStart = brake ~= nil and (brake.startStep ~= nil and brake.startStep or math.floor(opts.steps / 2)) or -1 -- 304
	local brakeSteps = brake ~= nil and math.max(1, opts.steps - brakeStart) or 1 -- 305
	local brakeDvPerStep = brake ~= nil and brake.dv / brakeSteps or 0 -- 306
	do -- 306
		local i = 0 -- 308
		while i < opts.steps do -- 308
			local acc = accelerationFrom(bodies, curPositions, s.pos) -- 310
			local nvx = s.vel.x + acc.x * opts.dt -- 311
			local nvy = s.vel.y + acc.y * opts.dt -- 312
			s = {pos = {x = s.pos.x + nvx * opts.dt, y = s.pos.y + nvy * opts.dt}, vel = {x = nvx, y = nvy}} -- 313
			t = t + opts.dt -- 314
			stepsRun = stepsRun + 1 -- 315
			if brake ~= nil and i >= brakeStart then -- 315
				local sp = math.sqrt(s.vel.x * s.vel.x + s.vel.y * s.vel.y) -- 318
				if sp > 1e-9 then -- 318
					local dv = sp > brakeDvPerStep and brakeDvPerStep or sp -- 321
					s = {pos = s.pos, vel = {x = s.vel.x - s.vel.x / sp * dv, y = s.vel.y - s.vel.y / sp * dv}} -- 322
				end -- 322
			end -- 322
			local tmp = curPositions -- 330
			curPositions = nextPositions -- 331
			nextPositions = tmp -- 332
			fillPositions(bodies, t, curPositions) -- 333
			local hit = collisionFrom(bodies, curPositions, s.pos) -- 335
			if hit >= 0 then -- 335
				outcome = "crashed" -- 337
				hitIndex = hit -- 338
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 339
				velocities[#velocities + 1] = {x = s.vel.x, y = s.vel.y} -- 340
				break -- 341
			end -- 341
			if escape2 > 0 and s.pos.x * s.pos.x + s.pos.y * s.pos.y > escape2 then -- 341
				outcome = "escaped" -- 345
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 346
				velocities[#velocities + 1] = {x = s.vel.x, y = s.vel.y} -- 347
				break -- 348
			end -- 348
			if i % sampleEvery == 0 then -- 348
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 352
				velocities[#velocities + 1] = {x = s.vel.x, y = s.vel.y} -- 353
			end -- 353
			i = i + 1 -- 308
		end -- 308
	end -- 308
	return { -- 357
		outcome = outcome, -- 357
		points = points, -- 357
		velocities = velocities, -- 357
		state = s, -- 357
		hitIndex = hitIndex, -- 357
		stepsRun = stepsRun -- 357
	} -- 357
end -- 277
--- 圆轨道速度：在距中心 `radius` 处、中心引力强度为 `gm` 时的环绕速度。
-- 用于关卡设计与测试（验证圆轨道不会向外飞或向内掉）。
function ____exports.orbitalSpeed(gm, radius) -- 364
	if radius <= 0 then -- 364
		return 0 -- 365
	end -- 365
	return math.sqrt(gm / radius) -- 366
end -- 364
--- 应用全局倍率，生成新的行星数组（不修改入参）。
-- 
-- - `gravityScale` 乘到 `gm`（统一调难度）
-- - `orbitScale` 除到 `orbitPeriod`（速度倍率；period 越小越快）
-- 
-- 放在这里而不是各调用方，是为了让“倍率语义”只有一处实现。
function ____exports.applyScales(bodies, gravityScale, orbitScale) -- 377
	local out = {} -- 378
	for ____, b in ipairs(bodies) do -- 379
		out[#out + 1] = { -- 380
			gm = b.gm * gravityScale, -- 381
			radius = b.radius, -- 382
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 383
			orbitRadius = b.orbitRadius, -- 384
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 385
			phase0 = b.phase0, -- 386
			orbitDirection = b.orbitDirection -- 387
		} -- 387
	end -- 387
	return out -- 390
end -- 377
--- 评估轨迹收集到的星尘。
-- 纯函数，预测线计算与实时飞行判定共用。
function ____exports.evaluateCollectedStars(points, stars, collectRadius) -- 403
	if collectRadius == nil then -- 403
		collectRadius = 30 -- 406
	end -- 406
	local collected = {} -- 408
	do -- 408
		local i = 0 -- 409
		while i < #stars do -- 409
			collected[#collected + 1] = false -- 410
			i = i + 1 -- 409
		end -- 409
	end -- 409
	local count = 0 -- 412
	local r2 = collectRadius * collectRadius -- 413
	for ____, p in ipairs(points) do -- 414
		do -- 414
			local i = 0 -- 415
			while i < #stars do -- 415
				if not collected[i + 1] then -- 415
					local dx = p.x - stars[i + 1].x -- 417
					local dy = p.y - stars[i + 1].y -- 418
					if dx * dx + dy * dy <= r2 then -- 418
						collected[i + 1] = true -- 420
						count = count + 1 -- 421
					end -- 421
				end -- 421
				i = i + 1 -- 415
			end -- 415
		end -- 415
	end -- 415
	return {collected = collected, count = count} -- 426
end -- 403
return ____exports -- 403