-- [ts]: Gravity.ts
local ____exports = {} -- 1
--- 避免除零的极小距离平方。
local MIN_DIST2 = 1e-12 -- 125
--- 两向量差。
function ____exports.sub(a, b) -- 128
	return {x = a.x - b.x, y = a.y - b.y} -- 129
end -- 128
--- 向量长度。
function ____exports.length(a) -- 133
	return math.sqrt(a.x * a.x + a.y * a.y) -- 134
end -- 133
--- 两点距离。
function ____exports.distance(a, b) -- 138
	local dx = a.x - b.x -- 139
	local dy = a.y - b.y -- 140
	return math.sqrt(dx * dx + dy * dy) -- 141
end -- 138
--- 行星在时刻 t 的位置。
-- `t` 的单位是秒，`t = 0` 即 `phase0` 描述的姿态。
function ____exports.bodyPositionAt(b, t) -- 148
	local c = b.host ~= nil and ____exports.bodyPositionAt(b.host, t) or b.orbitCenter -- 150
	local angle = b.phase0 -- 151
	if b.orbitPeriod ~= 0 then -- 151
		angle = angle + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 153
	end -- 153
	return { -- 155
		x = c.x + b.orbitRadius * math.cos(angle), -- 156
		y = c.y + b.orbitRadius * math.sin(angle) -- 157
	} -- 157
end -- 148
--- 点 p 在时刻 t 受到的引力加速度。
-- 平方反比：a = Σ gm_i * (q_i - p) / |q_i - p|³
function ____exports.accelerationAt(bodies, p, t) -- 165
	local ax = 0 -- 166
	local ay = 0 -- 167
	for ____, b in ipairs(bodies) do -- 168
		do -- 168
			local q = ____exports.bodyPositionAt(b, t) -- 169
			local dx = q.x - p.x -- 170
			local dy = q.y - p.y -- 171
			local d2 = dx * dx + dy * dy -- 172
			if d2 < MIN_DIST2 then -- 172
				goto __continue8 -- 173
			end -- 173
			local invd = 1 / math.sqrt(d2) -- 174
			local invd3 = invd * invd * invd -- 175
			ax = ax + b.gm * dx * invd3 -- 176
			ay = ay + b.gm * dy * invd3 -- 177
		end -- 177
		::__continue8:: -- 177
	end -- 177
	return {x = ax, y = ay} -- 179
end -- 165
--- 把全部天体在时刻 t 的位置写进 `out`（**预分配、原地覆盖**）。
-- 
-- 为什么要有它（B1，2026-09-28）：L1 换成真实阿波罗剖面后，一次预测推演要 **8000 步**，
-- 而每一步原本要算 **6 次** `bodyPositionAt`（加速度 3 次 + 碰撞检测 3 次，每次还带一次
-- 宿主链递归的 sin/cos）。滚动缓存之后每步只算 **3 次**，预测线耗时直接减半。
-- 结果与旧实现**逐位相同**（同一时刻、同一批位置、同一套算式，只是不再重复计算）。
local function fillPositions(bodies, t, out) -- 190
	do -- 190
		local i = 0 -- 191
		while i < #bodies do -- 191
			out[i + 1] = ____exports.bodyPositionAt(bodies[i + 1], t) -- 192
			i = i + 1 -- 191
		end -- 191
	end -- 191
end -- 190
--- 用**已算好的**天体位置求引力加速度（= `accelerationAt` 的缓存版，算式逐字相同）。
local function accelerationFrom(bodies, positions, p) -- 197
	local ax = 0 -- 198
	local ay = 0 -- 199
	do -- 199
		local i = 0 -- 200
		while i < #bodies do -- 200
			do -- 200
				local q = positions[i + 1] -- 201
				local dx = q.x - p.x -- 202
				local dy = q.y - p.y -- 203
				local d2 = dx * dx + dy * dy -- 204
				if d2 < MIN_DIST2 then -- 204
					goto __continue16 -- 205
				end -- 205
				local invd = 1 / math.sqrt(d2) -- 206
				local invd3 = invd * invd * invd -- 207
				ax = ax + bodies[i + 1].gm * dx * invd3 -- 208
				ay = ay + bodies[i + 1].gm * dy * invd3 -- 209
			end -- 209
			::__continue16:: -- 209
			i = i + 1 -- 200
		end -- 200
	end -- 200
	return {x = ax, y = ay} -- 211
end -- 197
--- 用**已算好的**天体位置做碰撞检测（= `collisionIndex` 的缓存版）。
local function collisionFrom(bodies, positions, p) -- 215
	do -- 215
		local i = 0 -- 216
		while i < #bodies do -- 216
			local q = positions[i + 1] -- 217
			local dx = q.x - p.x -- 218
			local dy = q.y - p.y -- 219
			if math.sqrt(dx * dx + dy * dy) < bodies[i + 1].radius then -- 219
				return i -- 220
			end -- 220
			i = i + 1 -- 216
		end -- 216
	end -- 216
	return -1 -- 222
end -- 215
--- 推进一步（半隐式欧拉 / 辛欧拉）。
-- 先更新速度、再用新速度更新位置 —— 对轨道运动足够稳定，且实现简单、完全确定。
function ____exports.step(state, bodies, t, dt) -- 229
	local a = ____exports.accelerationAt(bodies, state.pos, t) -- 230
	local vx = state.vel.x + a.x * dt -- 231
	local vy = state.vel.y + a.y * dt -- 232
	return {pos = {x = state.pos.x + vx * dt, y = state.pos.y + vy * dt}, vel = {x = vx, y = vy}} -- 233
end -- 229
--- 返回命中的行星索引；未命中返回 -1。
function ____exports.collisionIndex(bodies, p, t) -- 240
	do -- 240
		local i = 0 -- 241
		while i < #bodies do -- 241
			local b = bodies[i + 1] -- 242
			local q = ____exports.bodyPositionAt(b, t) -- 243
			local dx = q.x - p.x -- 244
			local dy = q.y - p.y -- 245
			if math.sqrt(dx * dx + dy * dy) < b.radius then -- 245
				return i -- 246
			end -- 246
			i = i + 1 -- 241
		end -- 241
	end -- 241
	return -1 -- 248
end -- 240
--- 从初始状态推演一段轨迹。
-- 
-- 确定性的关键：全程只用 `dt` 累加时间，不读任何外部时钟；
-- 同样的 (initial, bodies, opts) 必得同样的结果。
function ____exports.simulate(initial, bodies, opts) -- 257
	local sampleEvery = opts.sampleEvery > 0 and opts.sampleEvery or 1 -- 258
	local s = {pos = {x = initial.pos.x, y = initial.pos.y}, vel = {x = initial.vel.x, y = initial.vel.y}} -- 260
	local points = {{x = s.pos.x, y = s.pos.y}} -- 265
	local velocities = {{x = s.vel.x, y = s.vel.y}} -- 266
	local outcome = "running" -- 267
	local hitIndex = -1 -- 268
	local stepsRun = 0 -- 269
	local t = opts.t0 ~= nil and opts.t0 or 0 -- 270
	local escape2 = opts.escapeRadius > 0 and opts.escapeRadius * opts.escapeRadius or 0 -- 272
	local bufA = {} -- 276
	local bufB = {} -- 277
	fillPositions(bodies, t, bufA) -- 278
	local curPositions = bufA -- 279
	local nextPositions = bufB -- 280
	do -- 280
		local i = 0 -- 282
		while i < opts.steps do -- 282
			local acc = accelerationFrom(bodies, curPositions, s.pos) -- 284
			local burn = opts.initialBurn -- 285
			local burnDt = burn ~= nil and math.max( -- 286
				0, -- 286
				math.min(opts.dt, burn.duration - i * opts.dt) -- 286
			) or 0 -- 286
			local nvx = s.vel.x + acc.x * opts.dt + (burn ~= nil and burn.acceleration.x * burnDt or 0) -- 287
			local nvy = s.vel.y + acc.y * opts.dt + (burn ~= nil and burn.acceleration.y * burnDt or 0) -- 288
			s = {pos = {x = s.pos.x + nvx * opts.dt, y = s.pos.y + nvy * opts.dt}, vel = {x = nvx, y = nvy}} -- 289
			t = t + opts.dt -- 290
			stepsRun = stepsRun + 1 -- 291
			local tmp = curPositions -- 294
			curPositions = nextPositions -- 295
			nextPositions = tmp -- 296
			fillPositions(bodies, t, curPositions) -- 297
			local hit = collisionFrom(bodies, curPositions, s.pos) -- 299
			if hit >= 0 then -- 299
				outcome = "crashed" -- 301
				hitIndex = hit -- 302
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 303
				velocities[#velocities + 1] = {x = s.vel.x, y = s.vel.y} -- 304
				break -- 305
			end -- 305
			if escape2 > 0 and s.pos.x * s.pos.x + s.pos.y * s.pos.y > escape2 then -- 305
				outcome = "escaped" -- 309
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 310
				velocities[#velocities + 1] = {x = s.vel.x, y = s.vel.y} -- 311
				break -- 312
			end -- 312
			if i % sampleEvery == 0 then -- 312
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 316
				velocities[#velocities + 1] = {x = s.vel.x, y = s.vel.y} -- 317
			end -- 317
			i = i + 1 -- 282
		end -- 282
	end -- 282
	return { -- 321
		outcome = outcome, -- 321
		points = points, -- 321
		velocities = velocities, -- 321
		state = s, -- 321
		hitIndex = hitIndex, -- 321
		stepsRun = stepsRun -- 321
	} -- 321
end -- 257
--- 圆轨道速度：在距中心 `radius` 处、中心引力强度为 `gm` 时的环绕速度。
-- 用于关卡设计与测试（验证圆轨道不会向外飞或向内掉）。
function ____exports.orbitalSpeed(gm, radius) -- 328
	if radius <= 0 then -- 328
		return 0 -- 329
	end -- 329
	return math.sqrt(gm / radius) -- 330
end -- 328
--- 应用全局倍率，生成新的行星数组（不修改入参）。
-- 
-- - `gravityScale` 乘到 `gm`（统一调难度）
-- - `orbitScale` 除到 `orbitPeriod`（速度倍率；period 越小越快）
-- 
-- 放在这里而不是各调用方，是为了让“倍率语义”只有一处实现。
function ____exports.applyScales(bodies, gravityScale, orbitScale) -- 341
	local out = {} -- 342
	for ____, b in ipairs(bodies) do -- 343
		out[#out + 1] = { -- 344
			gm = b.gm * gravityScale, -- 345
			radius = b.radius, -- 346
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 347
			orbitRadius = b.orbitRadius, -- 348
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 349
			phase0 = b.phase0, -- 350
			orbitDirection = b.orbitDirection -- 351
		} -- 351
	end -- 351
	return out -- 354
end -- 341
--- 星尘在时刻 t 的位置。
-- 给了轨道就按公转求；没有（或半径为 0）就钉在 fallback 上。
function ____exports.starPositionAt(orbit, fallback, t) -- 367
	if orbit == nil or orbit.orbitRadius <= 0 then -- 367
		return {x = fallback.x, y = fallback.y} -- 368
	end -- 368
	return ____exports.bodyPositionAt(orbit, t) -- 369
end -- 367
--- 评估轨迹收集到的星尘。
-- 纯函数，预测线计算与实时飞行判定共用。
-- `starOrbits` 与 `stars` 一一对应时，用 `times[i]` 求第 i 个采样点当时的星尘位置。
-- 不传 `times` 或轨道 = 星尘静止在 `stars` 上（旧关卡 / 单点判定）。
function ____exports.evaluateCollectedStars(points, stars, collectRadius, starOrbits, times) -- 378
	if collectRadius == nil then -- 378
		collectRadius = 30 -- 381
	end -- 381
	local collected = {} -- 385
	do -- 385
		local i = 0 -- 386
		while i < #stars do -- 386
			collected[#collected + 1] = false -- 387
			i = i + 1 -- 386
		end -- 386
	end -- 386
	local count = 0 -- 389
	local r2 = collectRadius * collectRadius -- 390
	do -- 390
		local pi = 0 -- 391
		while pi < #points do -- 391
			local p = points[pi + 1] -- 392
			local t = times ~= nil and pi < #times and times[pi + 1] or 0 -- 393
			do -- 393
				local i = 0 -- 394
				while i < #stars do -- 394
					if not collected[i + 1] then -- 394
						local orbit = starOrbits ~= nil and starOrbits[i + 1] or nil -- 396
						local st = ____exports.starPositionAt(orbit, stars[i + 1], t) -- 397
						local dx = p.x - st.x -- 398
						local dy = p.y - st.y -- 399
						if dx * dx + dy * dy <= r2 then -- 399
							collected[i + 1] = true -- 401
							count = count + 1 -- 402
						end -- 402
					end -- 402
					i = i + 1 -- 394
				end -- 394
			end -- 394
			pi = pi + 1 -- 391
		end -- 391
	end -- 391
	return {collected = collected, count = count} -- 407
end -- 378
return ____exports -- 378