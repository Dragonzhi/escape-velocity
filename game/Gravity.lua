-- [ts]: Gravity.ts
local ____exports = {} -- 1
--- 避免除零的极小距离平方。
local MIN_DIST2 = 1e-12 -- 140
--- 两向量差。
function ____exports.sub(a, b) -- 143
	return {x = a.x - b.x, y = a.y - b.y} -- 144
end -- 143
--- 向量长度。
function ____exports.length(a) -- 148
	return math.sqrt(a.x * a.x + a.y * a.y) -- 149
end -- 148
--- 两点距离。
function ____exports.distance(a, b) -- 153
	local dx = a.x - b.x -- 154
	local dy = a.y - b.y -- 155
	return math.sqrt(dx * dx + dy * dy) -- 156
end -- 153
--- 行星在时刻 t 的位置。
-- `t` 的单位是秒，`t = 0` 即 `phase0` 描述的姿态。
function ____exports.bodyPositionAt(b, t) -- 163
	local c = b.host ~= nil and ____exports.bodyPositionAt(b.host, t) or b.orbitCenter -- 165
	local angle = b.phase0 -- 166
	if b.orbitPeriod ~= 0 then -- 166
		angle = angle + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 168
	end -- 168
	return { -- 170
		x = c.x + b.orbitRadius * math.cos(angle), -- 171
		y = c.y + b.orbitRadius * math.sin(angle) -- 172
	} -- 172
end -- 163
--- 点 p 在时刻 t 受到的引力加速度。
-- 平方反比：a = Σ gm_i * (q_i - p) / |q_i - p|³
function ____exports.accelerationAt(bodies, p, t) -- 180
	local ax = 0 -- 181
	local ay = 0 -- 182
	for ____, b in ipairs(bodies) do -- 183
		do -- 183
			local q = ____exports.bodyPositionAt(b, t) -- 184
			local dx = q.x - p.x -- 185
			local dy = q.y - p.y -- 186
			local d2 = dx * dx + dy * dy -- 187
			if d2 < MIN_DIST2 then -- 187
				goto __continue8 -- 188
			end -- 188
			local invd = 1 / math.sqrt(d2) -- 189
			local invd3 = invd * invd * invd -- 190
			ax = ax + b.gm * dx * invd3 -- 191
			ay = ay + b.gm * dy * invd3 -- 192
		end -- 192
		::__continue8:: -- 192
	end -- 192
	return {x = ax, y = ay} -- 194
end -- 180
--- 把全部天体在时刻 t 的位置写进 `out`（**预分配、原地覆盖**）。
-- 
-- 为什么要有它（B1，2026-09-28）：L1 换成真实阿波罗剖面后，一次预测推演要 **8000 步**，
-- 而每一步原本要算 **6 次** `bodyPositionAt`（加速度 3 次 + 碰撞检测 3 次，每次还带一次
-- 宿主链递归的 sin/cos）。滚动缓存之后每步只算 **3 次**，预测线耗时直接减半。
-- 结果与旧实现**逐位相同**（同一时刻、同一批位置、同一套算式，只是不再重复计算）。
local function fillPositions(bodies, t, out) -- 205
	do -- 205
		local i = 0 -- 206
		while i < #bodies do -- 206
			out[i + 1] = ____exports.bodyPositionAt(bodies[i + 1], t) -- 207
			i = i + 1 -- 206
		end -- 206
	end -- 206
end -- 205
--- 用**已算好的**天体位置求引力加速度（= `accelerationAt` 的缓存版，算式逐字相同）。
local function accelerationFrom(bodies, positions, p) -- 212
	local ax = 0 -- 213
	local ay = 0 -- 214
	do -- 214
		local i = 0 -- 215
		while i < #bodies do -- 215
			do -- 215
				local q = positions[i + 1] -- 216
				local dx = q.x - p.x -- 217
				local dy = q.y - p.y -- 218
				local d2 = dx * dx + dy * dy -- 219
				if d2 < MIN_DIST2 then -- 219
					goto __continue16 -- 220
				end -- 220
				local invd = 1 / math.sqrt(d2) -- 221
				local invd3 = invd * invd * invd -- 222
				ax = ax + bodies[i + 1].gm * dx * invd3 -- 223
				ay = ay + bodies[i + 1].gm * dy * invd3 -- 224
			end -- 224
			::__continue16:: -- 224
			i = i + 1 -- 215
		end -- 215
	end -- 215
	return {x = ax, y = ay} -- 226
end -- 212
--- 用**已算好的**天体位置做碰撞检测（= `collisionIndex` 的缓存版）。
local function collisionFrom(bodies, positions, p) -- 230
	do -- 230
		local i = 0 -- 231
		while i < #bodies do -- 231
			local q = positions[i + 1] -- 232
			local dx = q.x - p.x -- 233
			local dy = q.y - p.y -- 234
			if math.sqrt(dx * dx + dy * dy) < bodies[i + 1].radius then -- 234
				return i -- 235
			end -- 235
			i = i + 1 -- 231
		end -- 231
	end -- 231
	return -1 -- 237
end -- 230
--- 推进一步（半隐式欧拉 / 辛欧拉）。
-- 先更新速度、再用新速度更新位置 —— 对轨道运动足够稳定，且实现简单、完全确定。
function ____exports.step(state, bodies, t, dt) -- 244
	local a = ____exports.accelerationAt(bodies, state.pos, t) -- 245
	local vx = state.vel.x + a.x * dt -- 246
	local vy = state.vel.y + a.y * dt -- 247
	return {pos = {x = state.pos.x + vx * dt, y = state.pos.y + vy * dt}, vel = {x = vx, y = vy}} -- 248
end -- 244
--- 返回命中的行星索引；未命中返回 -1。
function ____exports.collisionIndex(bodies, p, t) -- 255
	do -- 255
		local i = 0 -- 256
		while i < #bodies do -- 256
			local b = bodies[i + 1] -- 257
			local q = ____exports.bodyPositionAt(b, t) -- 258
			local dx = q.x - p.x -- 259
			local dy = q.y - p.y -- 260
			if math.sqrt(dx * dx + dy * dy) < b.radius then -- 260
				return i -- 261
			end -- 261
			i = i + 1 -- 256
		end -- 256
	end -- 256
	return -1 -- 263
end -- 255
--- 从初始状态推演一段轨迹。
-- 
-- 确定性的关键：全程只用 `dt` 累加时间，不读任何外部时钟；
-- 同样的 (initial, bodies, opts) 必得同样的结果。
function ____exports.simulate(initial, bodies, opts) -- 272
	local sampleEvery = opts.sampleEvery > 0 and opts.sampleEvery or 1 -- 273
	local s = {pos = {x = initial.pos.x, y = initial.pos.y}, vel = {x = initial.vel.x, y = initial.vel.y}} -- 275
	local points = {{x = s.pos.x, y = s.pos.y}} -- 280
	local velocities = {{x = s.vel.x, y = s.vel.y}} -- 281
	local outcome = "running" -- 282
	local hitIndex = -1 -- 283
	local stepsRun = 0 -- 284
	local t = opts.t0 ~= nil and opts.t0 or 0 -- 285
	local escape2 = opts.escapeRadius > 0 and opts.escapeRadius * opts.escapeRadius or 0 -- 287
	local bufA = {} -- 291
	local bufB = {} -- 292
	fillPositions(bodies, t, bufA) -- 293
	local curPositions = bufA -- 294
	local nextPositions = bufB -- 295
	local brake = opts.brake -- 298
	local brakeStart = brake ~= nil and (brake.startStep ~= nil and brake.startStep or math.floor(opts.steps / 2)) or -1 -- 299
	local brakeSteps = brake ~= nil and math.max(1, opts.steps - brakeStart) or 1 -- 300
	local brakeDvPerStep = brake ~= nil and brake.dv / brakeSteps or 0 -- 301
	do -- 301
		local i = 0 -- 303
		while i < opts.steps do -- 303
			local acc = accelerationFrom(bodies, curPositions, s.pos) -- 305
			local nvx = s.vel.x + acc.x * opts.dt -- 306
			local nvy = s.vel.y + acc.y * opts.dt -- 307
			s = {pos = {x = s.pos.x + nvx * opts.dt, y = s.pos.y + nvy * opts.dt}, vel = {x = nvx, y = nvy}} -- 308
			t = t + opts.dt -- 309
			stepsRun = stepsRun + 1 -- 310
			if brake ~= nil and i >= brakeStart then -- 310
				local sp = math.sqrt(s.vel.x * s.vel.x + s.vel.y * s.vel.y) -- 313
				if sp > 1e-9 then -- 313
					local dv = sp > brakeDvPerStep and brakeDvPerStep or sp -- 316
					s = {pos = s.pos, vel = {x = s.vel.x - s.vel.x / sp * dv, y = s.vel.y - s.vel.y / sp * dv}} -- 317
				end -- 317
			end -- 317
			local tmp = curPositions -- 325
			curPositions = nextPositions -- 326
			nextPositions = tmp -- 327
			fillPositions(bodies, t, curPositions) -- 328
			local hit = collisionFrom(bodies, curPositions, s.pos) -- 330
			if hit >= 0 then -- 330
				outcome = "crashed" -- 332
				hitIndex = hit -- 333
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 334
				velocities[#velocities + 1] = {x = s.vel.x, y = s.vel.y} -- 335
				break -- 336
			end -- 336
			if escape2 > 0 and s.pos.x * s.pos.x + s.pos.y * s.pos.y > escape2 then -- 336
				outcome = "escaped" -- 340
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 341
				velocities[#velocities + 1] = {x = s.vel.x, y = s.vel.y} -- 342
				break -- 343
			end -- 343
			if i % sampleEvery == 0 then -- 343
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 347
				velocities[#velocities + 1] = {x = s.vel.x, y = s.vel.y} -- 348
			end -- 348
			i = i + 1 -- 303
		end -- 303
	end -- 303
	return { -- 352
		outcome = outcome, -- 352
		points = points, -- 352
		velocities = velocities, -- 352
		state = s, -- 352
		hitIndex = hitIndex, -- 352
		stepsRun = stepsRun -- 352
	} -- 352
end -- 272
--- 圆轨道速度：在距中心 `radius` 处、中心引力强度为 `gm` 时的环绕速度。
-- 用于关卡设计与测试（验证圆轨道不会向外飞或向内掉）。
function ____exports.orbitalSpeed(gm, radius) -- 359
	if radius <= 0 then -- 359
		return 0 -- 360
	end -- 360
	return math.sqrt(gm / radius) -- 361
end -- 359
--- 应用全局倍率，生成新的行星数组（不修改入参）。
-- 
-- - `gravityScale` 乘到 `gm`（统一调难度）
-- - `orbitScale` 除到 `orbitPeriod`（速度倍率；period 越小越快）
-- 
-- 放在这里而不是各调用方，是为了让“倍率语义”只有一处实现。
function ____exports.applyScales(bodies, gravityScale, orbitScale) -- 372
	local out = {} -- 373
	for ____, b in ipairs(bodies) do -- 374
		out[#out + 1] = { -- 375
			gm = b.gm * gravityScale, -- 376
			radius = b.radius, -- 377
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 378
			orbitRadius = b.orbitRadius, -- 379
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 380
			phase0 = b.phase0, -- 381
			orbitDirection = b.orbitDirection -- 382
		} -- 382
	end -- 382
	return out -- 385
end -- 372
return ____exports -- 372