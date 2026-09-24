-- [ts]: Gravity.ts
local ____exports = {} -- 1
--- 避免除零的极小距离平方。
local MIN_DIST2 = 1e-12 -- 91
--- 两向量差。
function ____exports.sub(a, b) -- 94
	return {x = a.x - b.x, y = a.y - b.y} -- 95
end -- 94
--- 向量长度。
function ____exports.length(a) -- 99
	return math.sqrt(a.x * a.x + a.y * a.y) -- 100
end -- 99
--- 两点距离。
function ____exports.distance(a, b) -- 104
	local dx = a.x - b.x -- 105
	local dy = a.y - b.y -- 106
	return math.sqrt(dx * dx + dy * dy) -- 107
end -- 104
--- 行星在时刻 t 的位置。
-- `t` 的单位是秒，`t = 0` 即 `phase0` 描述的姿态。
function ____exports.bodyPositionAt(b, t) -- 114
	local angle = b.phase0 -- 115
	if b.orbitPeriod ~= 0 then -- 115
		angle = angle + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 117
	end -- 117
	return { -- 119
		x = b.orbitCenter.x + b.orbitRadius * math.cos(angle), -- 120
		y = b.orbitCenter.y + b.orbitRadius * math.sin(angle) -- 121
	} -- 121
end -- 114
--- 点 p 在时刻 t 受到的引力加速度。
-- 平方反比：a = Σ gm_i * (q_i - p) / |q_i - p|³
function ____exports.accelerationAt(bodies, p, t) -- 129
	local ax = 0 -- 130
	local ay = 0 -- 131
	for ____, b in ipairs(bodies) do -- 132
		do -- 132
			local q = ____exports.bodyPositionAt(b, t) -- 133
			local dx = q.x - p.x -- 134
			local dy = q.y - p.y -- 135
			local d2 = dx * dx + dy * dy -- 136
			if d2 < MIN_DIST2 then -- 136
				goto __continue8 -- 137
			end -- 137
			local invd = 1 / math.sqrt(d2) -- 138
			local invd3 = invd * invd * invd -- 139
			ax = ax + b.gm * dx * invd3 -- 140
			ay = ay + b.gm * dy * invd3 -- 141
		end -- 141
		::__continue8:: -- 141
	end -- 141
	return {x = ax, y = ay} -- 143
end -- 129
--- 推进一步（半隐式欧拉 / 辛欧拉）。
-- 先更新速度、再用新速度更新位置 —— 对轨道运动足够稳定，且实现简单、完全确定。
function ____exports.step(state, bodies, t, dt) -- 150
	local a = ____exports.accelerationAt(bodies, state.pos, t) -- 151
	local vx = state.vel.x + a.x * dt -- 152
	local vy = state.vel.y + a.y * dt -- 153
	return {pos = {x = state.pos.x + vx * dt, y = state.pos.y + vy * dt}, vel = {x = vx, y = vy}} -- 154
end -- 150
--- 返回命中的行星索引；未命中返回 -1。
function ____exports.collisionIndex(bodies, p, t) -- 161
	do -- 161
		local i = 0 -- 162
		while i < #bodies do -- 162
			local b = bodies[i + 1] -- 163
			local q = ____exports.bodyPositionAt(b, t) -- 164
			local dx = q.x - p.x -- 165
			local dy = q.y - p.y -- 166
			if math.sqrt(dx * dx + dy * dy) < b.radius then -- 166
				return i -- 167
			end -- 167
			i = i + 1 -- 162
		end -- 162
	end -- 162
	return -1 -- 169
end -- 161
--- 从初始状态推演一段轨迹。
-- 
-- 确定性的关键：全程只用 `dt` 累加时间，不读任何外部时钟；
-- 同样的 (initial, bodies, opts) 必得同样的结果。
function ____exports.simulate(initial, bodies, opts) -- 178
	local sampleEvery = opts.sampleEvery > 0 and opts.sampleEvery or 1 -- 179
	local s = {pos = {x = initial.pos.x, y = initial.pos.y}, vel = {x = initial.vel.x, y = initial.vel.y}} -- 181
	local points = {{x = s.pos.x, y = s.pos.y}} -- 186
	local outcome = "running" -- 187
	local hitIndex = -1 -- 188
	local stepsRun = 0 -- 189
	local t = 0 -- 190
	local escape2 = opts.escapeRadius > 0 and opts.escapeRadius * opts.escapeRadius or 0 -- 192
	do -- 192
		local i = 0 -- 194
		while i < opts.steps do -- 194
			s = ____exports.step(s, bodies, t, opts.dt) -- 195
			t = t + opts.dt -- 196
			stepsRun = stepsRun + 1 -- 197
			local hit = ____exports.collisionIndex(bodies, s.pos, t) -- 199
			if hit >= 0 then -- 199
				outcome = "crashed" -- 201
				hitIndex = hit -- 202
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 203
				break -- 204
			end -- 204
			if escape2 > 0 and s.pos.x * s.pos.x + s.pos.y * s.pos.y > escape2 then -- 204
				outcome = "escaped" -- 208
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 209
				break -- 210
			end -- 210
			if i % sampleEvery == 0 then -- 210
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 214
			end -- 214
			i = i + 1 -- 194
		end -- 194
	end -- 194
	return { -- 218
		outcome = outcome, -- 218
		points = points, -- 218
		state = s, -- 218
		hitIndex = hitIndex, -- 218
		stepsRun = stepsRun -- 218
	} -- 218
end -- 178
--- 圆轨道速度：在距中心 `radius` 处、中心引力强度为 `gm` 时的环绕速度。
-- 用于关卡设计与测试（验证圆轨道不会向外飞或向内掉）。
function ____exports.orbitalSpeed(gm, radius) -- 225
	if radius <= 0 then -- 225
		return 0 -- 226
	end -- 226
	return math.sqrt(gm / radius) -- 227
end -- 225
--- 应用全局倍率，生成新的行星数组（不修改入参）。
-- 
-- - `gravityScale` 乘到 `gm`（统一调难度）
-- - `orbitScale` 除到 `orbitPeriod`（速度倍率；period 越小越快）
-- 
-- 放在这里而不是各调用方，是为了让“倍率语义”只有一处实现。
function ____exports.applyScales(bodies, gravityScale, orbitScale) -- 238
	local out = {} -- 239
	for ____, b in ipairs(bodies) do -- 240
		out[#out + 1] = { -- 241
			gm = b.gm * gravityScale, -- 242
			radius = b.radius, -- 243
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 244
			orbitRadius = b.orbitRadius, -- 245
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 246
			phase0 = b.phase0, -- 247
			orbitDirection = b.orbitDirection -- 248
		} -- 248
	end -- 248
	return out -- 251
end -- 238
return ____exports -- 238