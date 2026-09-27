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
--- 推进一步（半隐式欧拉 / 辛欧拉）。
-- 先更新速度、再用新速度更新位置 —— 对轨道运动足够稳定，且实现简单、完全确定。
function ____exports.step(state, bodies, t, dt) -- 201
	local a = ____exports.accelerationAt(bodies, state.pos, t) -- 202
	local vx = state.vel.x + a.x * dt -- 203
	local vy = state.vel.y + a.y * dt -- 204
	return {pos = {x = state.pos.x + vx * dt, y = state.pos.y + vy * dt}, vel = {x = vx, y = vy}} -- 205
end -- 201
--- 返回命中的行星索引；未命中返回 -1。
function ____exports.collisionIndex(bodies, p, t) -- 212
	do -- 212
		local i = 0 -- 213
		while i < #bodies do -- 213
			local b = bodies[i + 1] -- 214
			local q = ____exports.bodyPositionAt(b, t) -- 215
			local dx = q.x - p.x -- 216
			local dy = q.y - p.y -- 217
			if math.sqrt(dx * dx + dy * dy) < b.radius then -- 217
				return i -- 218
			end -- 218
			i = i + 1 -- 213
		end -- 213
	end -- 213
	return -1 -- 220
end -- 212
--- 从初始状态推演一段轨迹。
-- 
-- 确定性的关键：全程只用 `dt` 累加时间，不读任何外部时钟；
-- 同样的 (initial, bodies, opts) 必得同样的结果。
function ____exports.simulate(initial, bodies, opts) -- 229
	local sampleEvery = opts.sampleEvery > 0 and opts.sampleEvery or 1 -- 230
	local s = {pos = {x = initial.pos.x, y = initial.pos.y}, vel = {x = initial.vel.x, y = initial.vel.y}} -- 232
	local points = {{x = s.pos.x, y = s.pos.y}} -- 237
	local velocities = {{x = s.vel.x, y = s.vel.y}} -- 238
	local outcome = "running" -- 239
	local hitIndex = -1 -- 240
	local stepsRun = 0 -- 241
	local t = opts.t0 ~= nil and opts.t0 or 0 -- 242
	local escape2 = opts.escapeRadius > 0 and opts.escapeRadius * opts.escapeRadius or 0 -- 244
	local brake = opts.brake -- 247
	local brakeStart = brake ~= nil and (brake.startStep ~= nil and brake.startStep or math.floor(opts.steps / 2)) or -1 -- 248
	local brakeSteps = brake ~= nil and math.max(1, opts.steps - brakeStart) or 1 -- 249
	local brakeDvPerStep = brake ~= nil and brake.dv / brakeSteps or 0 -- 250
	do -- 250
		local i = 0 -- 252
		while i < opts.steps do -- 252
			s = ____exports.step(s, bodies, t, opts.dt) -- 253
			t = t + opts.dt -- 254
			stepsRun = stepsRun + 1 -- 255
			if brake ~= nil and i >= brakeStart then -- 255
				local sp = math.sqrt(s.vel.x * s.vel.x + s.vel.y * s.vel.y) -- 258
				if sp > 1e-9 then -- 258
					local dv = sp > brakeDvPerStep and brakeDvPerStep or sp -- 261
					s = {pos = s.pos, vel = {x = s.vel.x - s.vel.x / sp * dv, y = s.vel.y - s.vel.y / sp * dv}} -- 262
				end -- 262
			end -- 262
			local hit = ____exports.collisionIndex(bodies, s.pos, t) -- 269
			if hit >= 0 then -- 269
				outcome = "crashed" -- 271
				hitIndex = hit -- 272
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 273
				velocities[#velocities + 1] = {x = s.vel.x, y = s.vel.y} -- 274
				break -- 275
			end -- 275
			if escape2 > 0 and s.pos.x * s.pos.x + s.pos.y * s.pos.y > escape2 then -- 275
				outcome = "escaped" -- 279
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 280
				velocities[#velocities + 1] = {x = s.vel.x, y = s.vel.y} -- 281
				break -- 282
			end -- 282
			if i % sampleEvery == 0 then -- 282
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 286
				velocities[#velocities + 1] = {x = s.vel.x, y = s.vel.y} -- 287
			end -- 287
			i = i + 1 -- 252
		end -- 252
	end -- 252
	return { -- 291
		outcome = outcome, -- 291
		points = points, -- 291
		velocities = velocities, -- 291
		state = s, -- 291
		hitIndex = hitIndex, -- 291
		stepsRun = stepsRun -- 291
	} -- 291
end -- 229
--- 圆轨道速度：在距中心 `radius` 处、中心引力强度为 `gm` 时的环绕速度。
-- 用于关卡设计与测试（验证圆轨道不会向外飞或向内掉）。
function ____exports.orbitalSpeed(gm, radius) -- 298
	if radius <= 0 then -- 298
		return 0 -- 299
	end -- 299
	return math.sqrt(gm / radius) -- 300
end -- 298
--- 应用全局倍率，生成新的行星数组（不修改入参）。
-- 
-- - `gravityScale` 乘到 `gm`（统一调难度）
-- - `orbitScale` 除到 `orbitPeriod`（速度倍率；period 越小越快）
-- 
-- 放在这里而不是各调用方，是为了让“倍率语义”只有一处实现。
function ____exports.applyScales(bodies, gravityScale, orbitScale) -- 311
	local out = {} -- 312
	for ____, b in ipairs(bodies) do -- 313
		out[#out + 1] = { -- 314
			gm = b.gm * gravityScale, -- 315
			radius = b.radius, -- 316
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 317
			orbitRadius = b.orbitRadius, -- 318
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 319
			phase0 = b.phase0, -- 320
			orbitDirection = b.orbitDirection -- 321
		} -- 321
	end -- 321
	return out -- 324
end -- 311
return ____exports -- 311