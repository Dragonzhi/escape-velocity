-- [ts]: LevelLoader.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
--- gm = 0 的公转体没写 spin 时用的角速度（rad/s）。内圈陨石必须转，否则「抓住空隙」不存在。
local DEFAULT_SPIN = 0.6 -- 19
local function deg(d) -- 101
	return d * math.pi / 180 -- 102
end -- 101
--- 开普勒周期。μ ≤ 0 或 r ≤ 0 时没有轨道，返回 0（静止）。
function ____exports.keplerPeriod(radius, mu) -- 106
	if radius <= 0 or mu <= 0 then -- 106
		return 0 -- 107
	end -- 107
	return 2 * math.pi * math.sqrt(radius * radius * radius / mu) -- 108
end -- 106
--- 圆轨速度 √(μ/r)。
function ____exports.circularSpeed(mu, radius) -- 112
	if radius <= 0 or mu <= 0 then -- 112
		return 0 -- 113
	end -- 113
	return math.sqrt(mu / radius) -- 114
end -- 112
--- 圆轨上的切向速度。direction +1 = 逆时针，速度 = ω × r 的切向。
-- phaseRad 是此刻的位置角，不是初始角。
function ____exports.tangentialVelocity(mu, radius, phaseRad, direction) -- 121
	local speed = ____exports.circularSpeed(mu, radius) -- 122
	local tx = -math.sin(phaseRad) -- 123
	local ty = math.cos(phaseRad) -- 124
	return {x = direction * tx * speed, y = direction * ty * speed} -- 125
end -- 121
local function protoOf(____table, key) -- 128
	if ____table.bodies == nil then -- 128
		return nil -- 129
	end -- 129
	return ____table.bodies[key] -- 130
end -- 128
local function visualOf(proto) -- 133
	return { -- 134
		r = proto.color[1], -- 135
		g = proto.color[2], -- 136
		b = proto.color[3], -- 137
		displayRadius = proto.radius, -- 138
		ring = proto.ring == true, -- 139
		model = proto.model -- 140
	} -- 140
end -- 133
--- 一颗绕中心天体的圆轨道。
-- mu > 0 时周期由开普勒求出；否则用 spin（rad/s）反推周期，让陨石也能转。
local function orbitBody(proto, orbitRadius, angleDeg, direction, mu, spin) -- 148
	local period = 0 -- 156
	if orbitRadius > 0 then -- 156
		if mu > 0 then -- 156
			period = ____exports.keplerPeriod(orbitRadius, mu) -- 158
		else -- 158
			local w = spin ~= nil and spin > 0 and spin or DEFAULT_SPIN -- 160
			period = 2 * math.pi / w -- 161
		end -- 161
	end -- 161
	return { -- 164
		gm = proto.gm, -- 165
		radius = proto.radius, -- 166
		orbitCenter = {x = 0, y = 0}, -- 167
		orbitRadius = orbitRadius, -- 168
		orbitPeriod = period, -- 169
		phase0 = deg(angleDeg), -- 170
		orbitDirection = direction, -- 171
		name = proto.name -- 172
	} -- 172
end -- 148
--- 把一份关卡 JSON 收成运行时 LevelDef。原型缺失时返回 undefined（这一关整关丢弃）。
function ____exports.convertLevelJson(json, ____table) -- 177
	local center = protoOf(____table, json.centerBody) -- 178
	if center == nil then -- 178
		return nil -- 179
	end -- 179
	local planets = {} -- 181
	local visuals = {} -- 182
	planets[#planets + 1] = { -- 184
		gm = center.gm, -- 185
		radius = center.radius, -- 186
		orbitCenter = {x = 0, y = 0}, -- 187
		orbitRadius = 0, -- 188
		orbitPeriod = 0, -- 189
		phase0 = 0, -- 190
		orbitDirection = 1, -- 191
		name = center.name -- 192
	} -- 192
	visuals[#visuals + 1] = visualOf(center) -- 194
	local targetIndex = -1 -- 196
	local tolerance = 65 -- 197
	local goalOffset = nil -- 198
	do -- 198
		local i = 0 -- 199
		while i < #json.orbiters do -- 199
			local o = json.orbiters[i + 1] -- 200
			local proto = protoOf(____table, o.body) -- 201
			if proto == nil then -- 201
				return nil -- 202
			end -- 202
			local dir = o.direction == -1 and -1 or 1 -- 203
			local body = orbitBody( -- 204
				proto, -- 204
				o.orbitRadius, -- 204
				o.angleDeg, -- 204
				dir, -- 204
				center.gm, -- 204
				o.spin -- 204
			) -- 204
			if proto.gm <= 0 then -- 204
				body.isObstacle = true -- 205
			end -- 205
			planets[#planets + 1] = body -- 206
			visuals[#visuals + 1] = visualOf(proto) -- 207
			if o.type == "target" and targetIndex < 0 then -- 207
				targetIndex = #planets - 1 -- 209
				goalOffset = o.offset -- 210
				if o.tolerance ~= nil and o.tolerance > 0 then -- 210
					tolerance = o.tolerance -- 211
				end -- 211
			end -- 211
			i = i + 1 -- 199
		end -- 199
	end -- 199
	if targetIndex < 0 then -- 199
		return nil -- 214
	end -- 214
	local stars = {} -- 216
	if json.stars ~= nil then -- 216
		do -- 216
			local s = 0 -- 218
			while s < #json.stars do -- 218
				local st = json.stars[s + 1] -- 219
				local dir = st.direction == -1 and -1 or 1 -- 220
				local phase = deg(st.angleDeg) -- 221
				stars[#stars + 1] = { -- 222
					x = st.orbitRadius * math.cos(dir * phase), -- 223
					y = st.orbitRadius * math.sin(dir * phase) -- 224
				} -- 224
				s = s + 1 -- 218
			end -- 218
		end -- 218
	end -- 218
	local probePhase = deg(json.probe.startAngleDeg) -- 229
	local probeStart = { -- 230
		x = json.probe.orbitRadius * math.cos(probePhase), -- 231
		y = json.probe.orbitRadius * math.sin(probePhase) -- 232
	} -- 232
	local probeVel0 = ____exports.tangentialVelocity(center.gm, json.probe.orbitRadius, probePhase, 1) -- 234
	local escapeRadius = json.environment ~= nil and json.environment.escapeRadius ~= nil and json.environment.escapeRadius or 1400 -- 236
	local maxSteps = json.environment ~= nil and json.environment.maxSteps ~= nil and json.environment.maxSteps or 1000 -- 238
	return { -- 241
		transfer = json.transfer, -- 242
		id = json.id, -- 243
		title = json.title, -- 244
		probeVariant = json.id >= 3 and "rtg" or "solar", -- 245
		brief = json.brief, -- 246
		probeStart = probeStart, -- 247
		probeVel0 = probeVel0, -- 248
		stars = stars, -- 249
		planets = planets, -- 250
		visuals = visuals, -- 251
		goal = {kind = "planet", planetIndex = targetIndex, tolerance = tolerance, offset = goalOffset}, -- 252
		dvBudget = json.probe.dvBudget, -- 253
		escapeRadius = escapeRadius, -- 254
		maxSteps = maxSteps, -- 255
		mission = { -- 256
			id = "L" .. __TS__NumberToFixed(json.id, 0), -- 257
			codeName = "ArcadeSlingshot" .. __TS__NumberToFixed(json.id, 0), -- 258
			historicalRef = "街机引力弹弓", -- 259
			subtitle = json.subtitle ~= nil and json.subtitle or json.title, -- 260
			vehicle = "flyby", -- 261
			challenges = json.transfer ~= nil and ({{desc = json.transfer.flyby ~= nil and "安全完成月球减速掠过" or "抵达月球旁的目标光点", type = "success"}}) or ({{desc = "穿透星门", type = "success"}, {desc = "收集至少 2 颗星尘", type = "stars", threshold = 2}, {desc = "收集全部 3 颗星尘", type = "stars", threshold = 3}}) -- 262
		} -- 262
	} -- 262
end -- 177
--- 星尘轨道（与 stars 数组顺序一致）。中心 gm 取该关第 0 颗天体。
function ____exports.starOrbitsOf(json, ____table) -- 272
	local center = protoOf(____table, json.centerBody) -- 273
	local mu = center ~= nil and center.gm or 0 -- 274
	local out = {} -- 275
	if json.stars == nil then -- 275
		return out -- 276
	end -- 276
	do -- 276
		local s = 0 -- 277
		while s < #json.stars do -- 277
			local st = json.stars[s + 1] -- 278
			local dir = st.direction == -1 and -1 or 1 -- 279
			out[#out + 1] = { -- 280
				gm = 0, -- 281
				radius = 0, -- 282
				orbitCenter = {x = 0, y = 0}, -- 283
				orbitRadius = st.orbitRadius, -- 284
				orbitPeriod = ____exports.keplerPeriod(st.orbitRadius, mu), -- 285
				phase0 = deg(st.angleDeg), -- 286
				orbitDirection = dir, -- 287
				name = "星尘" -- 288
			} -- 288
			s = s + 1 -- 277
		end -- 277
	end -- 277
	return out -- 291
end -- 272
--- 解析两份 JSON 文本。
-- `decode` 由调用方给：引擎里没有 `JSON.parse`，入口传 Dora 的 `json.decode`。
-- 任一关原型缺失、没有星门、或文本不是 JSON，返回空数组（调用方保留旧关卡）。
function ____exports.loadArcadeLevels(levelsText, bodiesText, decode) -- 299
	local empty = {levels = {}, starOrbits = {}} -- 304
	do -- 304
		local function ____catch(e) -- 304
			return true, empty -- 321
		end -- 321
		local ____try, ____hasReturned, ____returnValue = pcall(function() -- 321
			local ____table = decode(bodiesText) -- 306
			local parsed = decode(levelsText) -- 307
			if ____table == nil or parsed == nil then -- 307
				return true, empty -- 308
			end -- 308
			if ____table == nil or ____table.bodies == nil then -- 308
				return true, empty -- 309
			end -- 309
			if parsed == nil or parsed.levels == nil or #parsed.levels == 0 then -- 309
				return true, empty -- 310
			end -- 310
			local levels = {} -- 311
			local starOrbits = {} -- 312
			do -- 312
				local i = 0 -- 313
				while i < #parsed.levels do -- 313
					local lv = ____exports.convertLevelJson(parsed.levels[i + 1], ____table) -- 314
					if lv == nil then -- 314
						return true, empty -- 315
					end -- 315
					levels[#levels + 1] = lv -- 316
					starOrbits[#starOrbits + 1] = ____exports.starOrbitsOf(parsed.levels[i + 1], ____table) -- 317
					i = i + 1 -- 313
				end -- 313
			end -- 313
			return true, {levels = levels, starOrbits = starOrbits} -- 319
		end) -- 319
		if not ____try then -- 319
			____hasReturned, ____returnValue = ____catch(____hasReturned) -- 319
		end -- 319
		if ____hasReturned then -- 319
			return ____returnValue -- 305
		end -- 305
	end -- 305
end -- 299
return ____exports -- 299