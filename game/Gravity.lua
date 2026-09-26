-- [ts]: Gravity.ts
local ____exports = {} -- 1
--- 避免除零的极小距离平方。
local MIN_DIST2 = 1e-12 -- 120
--- 两向量差。
function ____exports.sub(a, b) -- 123
	return {x = a.x - b.x, y = a.y - b.y} -- 124
end -- 123
--- 向量长度。
function ____exports.length(a) -- 128
	return math.sqrt(a.x * a.x + a.y * a.y) -- 129
end -- 128
--- 两点距离。
function ____exports.distance(a, b) -- 133
	local dx = a.x - b.x -- 134
	local dy = a.y - b.y -- 135
	return math.sqrt(dx * dx + dy * dy) -- 136
end -- 133
--- 行星在时刻 t 的位置。
-- `t` 的单位是秒，`t = 0` 即 `phase0` 描述的姿态。
function ____exports.bodyPositionAt(b, t) -- 143
	local angle = b.phase0 -- 144
	if b.orbitPeriod ~= 0 then -- 144
		angle = angle + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 146
	end -- 146
	return { -- 148
		x = b.orbitCenter.x + b.orbitRadius * math.cos(angle), -- 149
		y = b.orbitCenter.y + b.orbitRadius * math.sin(angle) -- 150
	} -- 150
end -- 143
--- 点 p 在时刻 t 受到的引力加速度。
-- 平方反比：a = Σ gm_i * (q_i - p) / |q_i - p|³
function ____exports.accelerationAt(bodies, p, t) -- 158
	local ax = 0 -- 159
	local ay = 0 -- 160
	for ____, b in ipairs(bodies) do -- 161
		do -- 161
			local q = ____exports.bodyPositionAt(b, t) -- 162
			local dx = q.x - p.x -- 163
			local dy = q.y - p.y -- 164
			local d2 = dx * dx + dy * dy -- 165
			if d2 < MIN_DIST2 then -- 165
				goto __continue8 -- 166
			end -- 166
			local invd = 1 / math.sqrt(d2) -- 167
			local invd3 = invd * invd * invd -- 168
			ax = ax + b.gm * dx * invd3 -- 169
			ay = ay + b.gm * dy * invd3 -- 170
		end -- 170
		::__continue8:: -- 170
	end -- 170
	return {x = ax, y = ay} -- 172
end -- 158
--- 推进一步（半隐式欧拉 / 辛欧拉）。
-- 先更新速度、再用新速度更新位置 —— 对轨道运动足够稳定，且实现简单、完全确定。
function ____exports.step(state, bodies, t, dt) -- 179
	local a = ____exports.accelerationAt(bodies, state.pos, t) -- 180
	local vx = state.vel.x + a.x * dt -- 181
	local vy = state.vel.y + a.y * dt -- 182
	return {pos = {x = state.pos.x + vx * dt, y = state.pos.y + vy * dt}, vel = {x = vx, y = vy}} -- 183
end -- 179
--- 返回命中的行星索引；未命中返回 -1。
function ____exports.collisionIndex(bodies, p, t) -- 190
	do -- 190
		local i = 0 -- 191
		while i < #bodies do -- 191
			local b = bodies[i + 1] -- 192
			local q = ____exports.bodyPositionAt(b, t) -- 193
			local dx = q.x - p.x -- 194
			local dy = q.y - p.y -- 195
			if math.sqrt(dx * dx + dy * dy) < b.radius then -- 195
				return i -- 196
			end -- 196
			i = i + 1 -- 191
		end -- 191
	end -- 191
	return -1 -- 198
end -- 190
--- 从初始状态推演一段轨迹。
-- 
-- 确定性的关键：全程只用 `dt` 累加时间，不读任何外部时钟；
-- 同样的 (initial, bodies, opts) 必得同样的结果。
function ____exports.simulate(initial, bodies, opts) -- 207
	local sampleEvery = opts.sampleEvery > 0 and opts.sampleEvery or 1 -- 208
	local s = {pos = {x = initial.pos.x, y = initial.pos.y}, vel = {x = initial.vel.x, y = initial.vel.y}} -- 210
	local points = {{x = s.pos.x, y = s.pos.y}} -- 215
	local outcome = "running" -- 216
	local hitIndex = -1 -- 217
	local stepsRun = 0 -- 218
	local t = opts.t0 ~= nil and opts.t0 or 0 -- 219
	local escape2 = opts.escapeRadius > 0 and opts.escapeRadius * opts.escapeRadius or 0 -- 221
	local brake = opts.brake -- 224
	local brakeStart = brake ~= nil and (brake.startStep ~= nil and brake.startStep or math.floor(opts.steps / 2)) or -1 -- 225
	local brakeSteps = brake ~= nil and math.max(1, opts.steps - brakeStart) or 1 -- 226
	local brakeDvPerStep = brake ~= nil and brake.dv / brakeSteps or 0 -- 227
	do -- 227
		local i = 0 -- 229
		while i < opts.steps do -- 229
			s = ____exports.step(s, bodies, t, opts.dt) -- 230
			t = t + opts.dt -- 231
			stepsRun = stepsRun + 1 -- 232
			if brake ~= nil and i >= brakeStart then -- 232
				local sp = math.sqrt(s.vel.x * s.vel.x + s.vel.y * s.vel.y) -- 235
				if sp > 1e-9 then -- 235
					local dv = sp > brakeDvPerStep and brakeDvPerStep or sp -- 238
					s = {pos = s.pos, vel = {x = s.vel.x - s.vel.x / sp * dv, y = s.vel.y - s.vel.y / sp * dv}} -- 239
				end -- 239
			end -- 239
			local hit = ____exports.collisionIndex(bodies, s.pos, t) -- 246
			if hit >= 0 then -- 246
				outcome = "crashed" -- 248
				hitIndex = hit -- 249
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 250
				break -- 251
			end -- 251
			if escape2 > 0 and s.pos.x * s.pos.x + s.pos.y * s.pos.y > escape2 then -- 251
				outcome = "escaped" -- 255
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 256
				break -- 257
			end -- 257
			if i % sampleEvery == 0 then -- 257
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 261
			end -- 261
			i = i + 1 -- 229
		end -- 229
	end -- 229
	return { -- 265
		outcome = outcome, -- 265
		points = points, -- 265
		state = s, -- 265
		hitIndex = hitIndex, -- 265
		stepsRun = stepsRun -- 265
	} -- 265
end -- 207
--- 圆轨道速度：在距中心 `radius` 处、中心引力强度为 `gm` 时的环绕速度。
-- 用于关卡设计与测试（验证圆轨道不会向外飞或向内掉）。
function ____exports.orbitalSpeed(gm, radius) -- 272
	if radius <= 0 then -- 272
		return 0 -- 273
	end -- 273
	return math.sqrt(gm / radius) -- 274
end -- 272
--- 应用全局倍率，生成新的行星数组（不修改入参）。
-- 
-- - `gravityScale` 乘到 `gm`（统一调难度）
-- - `orbitScale` 除到 `orbitPeriod`（速度倍率；period 越小越快）
-- 
-- 放在这里而不是各调用方，是为了让“倍率语义”只有一处实现。
function ____exports.applyScales(bodies, gravityScale, orbitScale) -- 285
	local out = {} -- 286
	for ____, b in ipairs(bodies) do -- 287
		out[#out + 1] = { -- 288
			gm = b.gm * gravityScale, -- 289
			radius = b.radius, -- 290
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 291
			orbitRadius = b.orbitRadius, -- 292
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 293
			phase0 = b.phase0, -- 294
			orbitDirection = b.orbitDirection -- 295
		} -- 295
	end -- 295
	return out -- 298
end -- 285
return ____exports -- 285