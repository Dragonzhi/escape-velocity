-- [ts]: Gravity.ts
local ____exports = {} -- 1
--- 避免除零的极小距离平方。
local MIN_DIST2 = 1e-12 -- 99
--- 两向量差。
function ____exports.sub(a, b) -- 102
	return {x = a.x - b.x, y = a.y - b.y} -- 103
end -- 102
--- 向量长度。
function ____exports.length(a) -- 107
	return math.sqrt(a.x * a.x + a.y * a.y) -- 108
end -- 107
--- 两点距离。
function ____exports.distance(a, b) -- 112
	local dx = a.x - b.x -- 113
	local dy = a.y - b.y -- 114
	return math.sqrt(dx * dx + dy * dy) -- 115
end -- 112
--- 行星在时刻 t 的位置。
-- `t` 的单位是秒，`t = 0` 即 `phase0` 描述的姿态。
function ____exports.bodyPositionAt(b, t) -- 122
	local angle = b.phase0 -- 123
	if b.orbitPeriod ~= 0 then -- 123
		angle = angle + b.orbitDirection * (2 * math.pi) * (t / b.orbitPeriod) -- 125
	end -- 125
	return { -- 127
		x = b.orbitCenter.x + b.orbitRadius * math.cos(angle), -- 128
		y = b.orbitCenter.y + b.orbitRadius * math.sin(angle) -- 129
	} -- 129
end -- 122
--- 点 p 在时刻 t 受到的引力加速度。
-- 平方反比：a = Σ gm_i * (q_i - p) / |q_i - p|³
function ____exports.accelerationAt(bodies, p, t) -- 137
	local ax = 0 -- 138
	local ay = 0 -- 139
	for ____, b in ipairs(bodies) do -- 140
		do -- 140
			local q = ____exports.bodyPositionAt(b, t) -- 141
			local dx = q.x - p.x -- 142
			local dy = q.y - p.y -- 143
			local d2 = dx * dx + dy * dy -- 144
			if d2 < MIN_DIST2 then -- 144
				goto __continue8 -- 145
			end -- 145
			local invd = 1 / math.sqrt(d2) -- 146
			local invd3 = invd * invd * invd -- 147
			ax = ax + b.gm * dx * invd3 -- 148
			ay = ay + b.gm * dy * invd3 -- 149
		end -- 149
		::__continue8:: -- 149
	end -- 149
	return {x = ax, y = ay} -- 151
end -- 137
--- 推进一步（半隐式欧拉 / 辛欧拉）。
-- 先更新速度、再用新速度更新位置 —— 对轨道运动足够稳定，且实现简单、完全确定。
function ____exports.step(state, bodies, t, dt) -- 158
	local a = ____exports.accelerationAt(bodies, state.pos, t) -- 159
	local vx = state.vel.x + a.x * dt -- 160
	local vy = state.vel.y + a.y * dt -- 161
	return {pos = {x = state.pos.x + vx * dt, y = state.pos.y + vy * dt}, vel = {x = vx, y = vy}} -- 162
end -- 158
--- 返回命中的行星索引；未命中返回 -1。
function ____exports.collisionIndex(bodies, p, t) -- 169
	do -- 169
		local i = 0 -- 170
		while i < #bodies do -- 170
			local b = bodies[i + 1] -- 171
			local q = ____exports.bodyPositionAt(b, t) -- 172
			local dx = q.x - p.x -- 173
			local dy = q.y - p.y -- 174
			if math.sqrt(dx * dx + dy * dy) < b.radius then -- 174
				return i -- 175
			end -- 175
			i = i + 1 -- 170
		end -- 170
	end -- 170
	return -1 -- 177
end -- 169
--- 从初始状态推演一段轨迹。
-- 
-- 确定性的关键：全程只用 `dt` 累加时间，不读任何外部时钟；
-- 同样的 (initial, bodies, opts) 必得同样的结果。
function ____exports.simulate(initial, bodies, opts) -- 186
	local sampleEvery = opts.sampleEvery > 0 and opts.sampleEvery or 1 -- 187
	local s = {pos = {x = initial.pos.x, y = initial.pos.y}, vel = {x = initial.vel.x, y = initial.vel.y}} -- 189
	local points = {{x = s.pos.x, y = s.pos.y}} -- 194
	local outcome = "running" -- 195
	local hitIndex = -1 -- 196
	local stepsRun = 0 -- 197
	local t = opts.t0 ~= nil and opts.t0 or 0 -- 198
	local escape2 = opts.escapeRadius > 0 and opts.escapeRadius * opts.escapeRadius or 0 -- 200
	do -- 200
		local i = 0 -- 202
		while i < opts.steps do -- 202
			s = ____exports.step(s, bodies, t, opts.dt) -- 203
			t = t + opts.dt -- 204
			stepsRun = stepsRun + 1 -- 205
			local hit = ____exports.collisionIndex(bodies, s.pos, t) -- 207
			if hit >= 0 then -- 207
				outcome = "crashed" -- 209
				hitIndex = hit -- 210
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 211
				break -- 212
			end -- 212
			if escape2 > 0 and s.pos.x * s.pos.x + s.pos.y * s.pos.y > escape2 then -- 212
				outcome = "escaped" -- 216
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 217
				break -- 218
			end -- 218
			if i % sampleEvery == 0 then -- 218
				points[#points + 1] = {x = s.pos.x, y = s.pos.y} -- 222
			end -- 222
			i = i + 1 -- 202
		end -- 202
	end -- 202
	return { -- 226
		outcome = outcome, -- 226
		points = points, -- 226
		state = s, -- 226
		hitIndex = hitIndex, -- 226
		stepsRun = stepsRun -- 226
	} -- 226
end -- 186
--- 圆轨道速度：在距中心 `radius` 处、中心引力强度为 `gm` 时的环绕速度。
-- 用于关卡设计与测试（验证圆轨道不会向外飞或向内掉）。
function ____exports.orbitalSpeed(gm, radius) -- 233
	if radius <= 0 then -- 233
		return 0 -- 234
	end -- 234
	return math.sqrt(gm / radius) -- 235
end -- 233
--- 应用全局倍率，生成新的行星数组（不修改入参）。
-- 
-- - `gravityScale` 乘到 `gm`（统一调难度）
-- - `orbitScale` 除到 `orbitPeriod`（速度倍率；period 越小越快）
-- 
-- 放在这里而不是各调用方，是为了让“倍率语义”只有一处实现。
function ____exports.applyScales(bodies, gravityScale, orbitScale) -- 246
	local out = {} -- 247
	for ____, b in ipairs(bodies) do -- 248
		out[#out + 1] = { -- 249
			gm = b.gm * gravityScale, -- 250
			radius = b.radius, -- 251
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 252
			orbitRadius = b.orbitRadius, -- 253
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 254
			phase0 = b.phase0, -- 255
			orbitDirection = b.orbitDirection -- 256
		} -- 256
	end -- 256
	return out -- 259
end -- 246
return ____exports -- 246