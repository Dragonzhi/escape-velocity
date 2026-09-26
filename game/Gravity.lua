-- [ts]: Gravity.ts
local ____exports = {} -- 1
--- 避免除零的极小距离平方。
local MIN_DIST2 = 1e-12 -- 128
--- 两向量差。
function ____exports.sub(a, b) -- 131
	return {x = a.x - b.x, y = a.y - b.y} -- 132
end -- 131
--- 向量长度。
function ____exports.length(a) -- 136
	return math.sqrt(a.x * a.x + a.y * a.y) -- 137
end -- 136
--- 两点距离。
function ____exports.distance(a, b) -- 141
	local dx = a.x - b.x -- 142
	local dy = a.y - b.y -- 143
	return math.sqrt(dx * dx + dy * dy) -- 144
end -- 141
--- 行星在时刻 t 的位置。
-- `t` 的单位是秒，`t = 0` 即 `phase0` 描述的姿态。
function ____exports.bodyPositionAt(b, t) -- 151
	local angle = b.phase0 -- 152
	if b.orbitPeriod ~= 0 then -- 152
		angle = angle + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 154
	end -- 154
	return { -- 156
		x = b.orbitCenter.x + b.orbitRadius * math.cos(angle), -- 157
		y = b.orbitCenter.y + b.orbitRadius * math.sin(angle) -- 158
	} -- 158
end -- 151
--- 点 p 在时刻 t 受到的引力加速度。
-- 平方反比：a = Σ gm_i * (q_i - p) / |q_i - p|³
function ____exports.accelerationAt(bodies, p, t) -- 166
	local ax = 0 -- 167
	local ay = 0 -- 168
	for ____, b in ipairs(bodies) do -- 169
		do -- 169
			local q = ____exports.bodyPositionAt(b, t) -- 170
			local dx = q.x - p.x -- 171
			local dy = q.y - p.y -- 172
			local d2 = dx * dx + dy * dy -- 173
			if d2 < MIN_DIST2 then -- 173
				goto __continue8 -- 174
			end -- 174
			local invd = 1 / math.sqrt(d2) -- 175
			local invd3 = invd * invd * invd -- 176
			ax = ax + b.gm * dx * invd3 -- 177
			ay = ay + b.gm * dy * invd3 -- 178
		end -- 178
		::__continue8:: -- 178
	end -- 178
	return {x = ax, y = ay} -- 180
end -- 166
--- 推进一步（半隐式欧拉 / 辛欧拉）。
-- 先更新速度、再用新速度更新位置 —— 对轨道运动足够稳定，且实现简单、完全确定。
function ____exports.step(state, bodies, t, dt) -- 187
	local a = ____exports.accelerationAt(bodies, state.pos, t) -- 188
	local vx = state.vel.x + a.x * dt -- 189
	local vy = state.vel.y + a.y * dt -- 190
	return {pos = {x = state.pos.x + vx * dt, y = state.pos.y + vy * dt}, vel = {x = vx, y = vy}} -- 191
end -- 187
--- 返回命中的行星索引；未命中返回 -1。
function ____exports.collisionIndex(bodies, p, t) -- 198
	do -- 198
		local i = 0 -- 199
		while i < #bodies do -- 199
			local b = bodies[i + 1] -- 200
			local q = ____exports.bodyPositionAt(b, t) -- 201
			local dx = q.x - p.x -- 202
			local dy = q.y - p.y -- 203
			if math.sqrt(dx * dx + dy * dy) < b.radius then -- 203
				return i -- 204
			end -- 204
			i = i + 1 -- 199
		end -- 199
	end -- 199
	return -1 -- 206
end -- 198
--- 从初始状态推演一段轨迹。
-- 
-- 确定性的关键：全程只用 `dt` 累加时间，不读任何外部时钟；
-- 同样的 (initial, bodies, opts) 必得同样的结果。
function ____exports.simulate(initial, bodies, opts) -- 215
	local sampleEvery = opts.sampleEvery > 0 and opts.sampleEvery or 1 -- 216
	local s = {pos = {x = initial.pos.x, y = initial.pos.y}, vel = {x = initial.vel.x, y = initial.vel.y}} -- 218
	local points = {{x = s.pos.x, y = s.pos.y}} -- 223
	local velocities = {{x = s.vel.x, y = s.vel.y}} -- 224
	local outcome = "running" -- 225
	local hitIndex = -1 -- 226
	local stepsRun = 0 -- 227
	local t = opts.t0 ~= nil and opts.t0 or 0 -- 228
	local escape2 = opts.escapeRadius > 0 and opts.escapeRadius * opts.escapeRadius or 0 -- 230
	local brake = opts.brake -- 233
	local brakeStart = brake ~= nil and (brake.startStep ~= nil and brake.startStep or math.floor(opts.steps / 2)) or -1 -- 234
	local brakeSteps = brake ~= nil and math.max(1, opts.steps - brakeStart) or 1 -- 235
	local brakeDvPerStep = brake ~= nil and brake.dv / brakeSteps or 0 -- 236
	do -- 236
		local i = 0 -- 238
		while i < opts.steps do -- 238
			s = ____exports.step(s, bodies, t, opts.dt) -- 239
			t = t + opts.dt -- 240
			stepsRun = stepsRun + 1 -- 241
			if brake ~= nil and i >= brakeStart then -- 241
				local sp = math.sqrt(s.vel.x * s.vel.x + s.vel.y * s.vel.y) -- 244
				if sp > 1e-9 then -- 244
					local dv = sp > brakeDvPerStep and brakeDvPerStep or sp -- 247
					s = {pos = s.pos, vel = {x = s.vel.x - s.vel.x / sp * dv, y = s.vel.y - s.vel.y / sp * dv}} -- 248
				end -- 248
			end -- 248
			local hit = ____exports.collisionIndex(bodies, s.pos, t) -- 255
			if hit >= 0 then -- 255
				outcome = "crashed" -- 257
				hitIndex = hit -- 258
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 259
				velocities[#velocities + 1] = {x = s.vel.x, y = s.vel.y} -- 260
				break -- 261
			end -- 261
			if escape2 > 0 and s.pos.x * s.pos.x + s.pos.y * s.pos.y > escape2 then -- 261
				outcome = "escaped" -- 265
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 266
				velocities[#velocities + 1] = {x = s.vel.x, y = s.vel.y} -- 267
				break -- 268
			end -- 268
			if i % sampleEvery == 0 then -- 268
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 272
				velocities[#velocities + 1] = {x = s.vel.x, y = s.vel.y} -- 273
			end -- 273
			i = i + 1 -- 238
		end -- 238
	end -- 238
	return { -- 277
		outcome = outcome, -- 277
		points = points, -- 277
		velocities = velocities, -- 277
		state = s, -- 277
		hitIndex = hitIndex, -- 277
		stepsRun = stepsRun -- 277
	} -- 277
end -- 215
--- 圆轨道速度：在距中心 `radius` 处、中心引力强度为 `gm` 时的环绕速度。
-- 用于关卡设计与测试（验证圆轨道不会向外飞或向内掉）。
function ____exports.orbitalSpeed(gm, radius) -- 284
	if radius <= 0 then -- 284
		return 0 -- 285
	end -- 285
	return math.sqrt(gm / radius) -- 286
end -- 284
--- 应用全局倍率，生成新的行星数组（不修改入参）。
-- 
-- - `gravityScale` 乘到 `gm`（统一调难度）
-- - `orbitScale` 除到 `orbitPeriod`（速度倍率；period 越小越快）
-- 
-- 放在这里而不是各调用方，是为了让“倍率语义”只有一处实现。
function ____exports.applyScales(bodies, gravityScale, orbitScale) -- 297
	local out = {} -- 298
	for ____, b in ipairs(bodies) do -- 299
		out[#out + 1] = { -- 300
			gm = b.gm * gravityScale, -- 301
			radius = b.radius, -- 302
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 303
			orbitRadius = b.orbitRadius, -- 304
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 305
			phase0 = b.phase0, -- 306
			orbitDirection = b.orbitDirection -- 307
		} -- 307
	end -- 307
	return out -- 310
end -- 297
return ____exports -- 297