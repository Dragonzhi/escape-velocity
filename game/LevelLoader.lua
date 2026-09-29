-- [ts]: LevelLoader.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
--- gm = 0 的公转体没写 spin 时用的角速度（rad/s）。内圈陨石必须转，否则「抓住空隙」不存在。
local DEFAULT_SPIN = 0.6 -- 19
local function deg(d) -- 103
	return d * math.pi / 180 -- 104
end -- 103
--- 开普勒周期。μ ≤ 0 或 r ≤ 0 时没有轨道，返回 0（静止）。
function ____exports.keplerPeriod(radius, mu) -- 108
	if radius <= 0 or mu <= 0 then -- 108
		return 0 -- 109
	end -- 109
	return 2 * math.pi * math.sqrt(radius * radius * radius / mu) -- 110
end -- 108
--- 圆轨速度 √(μ/r)。
function ____exports.circularSpeed(mu, radius) -- 114
	if radius <= 0 or mu <= 0 then -- 114
		return 0 -- 115
	end -- 115
	return math.sqrt(mu / radius) -- 116
end -- 114
--- 圆轨上的切向速度。direction +1 = 逆时针，速度 = ω × r 的切向。
-- phaseRad 是此刻的位置角，不是初始角。
function ____exports.tangentialVelocity(mu, radius, phaseRad, direction) -- 123
	local speed = ____exports.circularSpeed(mu, radius) -- 124
	local tx = -math.sin(phaseRad) -- 125
	local ty = math.cos(phaseRad) -- 126
	return {x = direction * tx * speed, y = direction * ty * speed} -- 127
end -- 123
local function protoOf(____table, key) -- 130
	if ____table.bodies == nil then -- 130
		return nil -- 131
	end -- 131
	return ____table.bodies[key] -- 132
end -- 130
local function visualOf(proto) -- 135
	return { -- 136
		emissive = proto.emissive ~= nil and ({r = proto.emissive[1], g = proto.emissive[2], b = proto.emissive[3]}) or nil, -- 137
		r = proto.color[1], -- 138
		g = proto.color[2], -- 139
		b = proto.color[3], -- 140
		displayRadius = proto.radius, -- 141
		ring = proto.ring == true, -- 142
		model = proto.model -- 143
	} -- 143
end -- 135
--- 一颗绕中心天体的圆轨道。
-- mu > 0 时周期由开普勒求出；否则用 spin（rad/s）反推周期，让陨石也能转。
local function orbitBody(proto, orbitRadius, angleDeg, direction, mu, spin) -- 151
	local period = 0 -- 159
	if orbitRadius > 0 then -- 159
		if mu > 0 then -- 159
			period = ____exports.keplerPeriod(orbitRadius, mu) -- 161
		else -- 161
			local w = spin ~= nil and spin > 0 and spin or DEFAULT_SPIN -- 163
			period = 2 * math.pi / w -- 164
		end -- 164
	end -- 164
	return { -- 167
		gm = proto.gm, -- 168
		radius = proto.radius, -- 169
		orbitCenter = {x = 0, y = 0}, -- 170
		orbitRadius = orbitRadius, -- 171
		orbitPeriod = period, -- 172
		phase0 = deg(angleDeg), -- 173
		orbitDirection = direction, -- 174
		name = proto.name -- 175
	} -- 175
end -- 151
--- 把一份关卡 JSON 收成运行时 LevelDef。原型缺失时返回 undefined（这一关整关丢弃）。
function ____exports.convertLevelJson(json, ____table) -- 180
	local center = protoOf(____table, json.centerBody) -- 181
	if center == nil then -- 181
		return nil -- 182
	end -- 182
	local planets = {} -- 184
	local visuals = {} -- 185
	planets[#planets + 1] = { -- 187
		gm = center.gm, -- 188
		radius = center.radius, -- 189
		orbitCenter = {x = 0, y = 0}, -- 190
		orbitRadius = 0, -- 191
		orbitPeriod = 0, -- 192
		phase0 = 0, -- 193
		orbitDirection = 1, -- 194
		name = center.name -- 195
	} -- 195
	visuals[#visuals + 1] = visualOf(center) -- 197
	local targetIndex = -1 -- 199
	local tolerance = 65 -- 200
	local goalOffset = nil -- 201
	do -- 201
		local i = 0 -- 202
		while i < #json.orbiters do -- 202
			local o = json.orbiters[i + 1] -- 203
			local proto = protoOf(____table, o.body) -- 204
			if proto == nil then -- 204
				return nil -- 205
			end -- 205
			local dir = o.direction == -1 and -1 or 1 -- 206
			local body = orbitBody( -- 207
				proto, -- 207
				o.orbitRadius, -- 207
				o.angleDeg, -- 207
				dir, -- 207
				center.gm, -- 207
				o.spin -- 207
			) -- 207
			if proto.gm <= 0 then -- 207
				body.isObstacle = true -- 208
			end -- 208
			planets[#planets + 1] = body -- 209
			visuals[#visuals + 1] = visualOf(proto) -- 210
			if o.type == "target" and targetIndex < 0 then -- 210
				targetIndex = #planets - 1 -- 212
				goalOffset = o.offset -- 213
				if o.tolerance ~= nil and o.tolerance > 0 then -- 213
					tolerance = o.tolerance -- 214
				end -- 214
			end -- 214
			i = i + 1 -- 202
		end -- 202
	end -- 202
	local marker = nil -- 217
	if json.marker ~= nil and json.transfer ~= nil and json.transfer.orbital ~= nil then -- 217
		marker = orbitBody( -- 219
			{ -- 219
				name = "目标光点", -- 219
				gm = 0, -- 219
				radius = 0, -- 219
				model = "", -- 219
				color = {0, 1, 1} -- 219
			}, -- 219
			json.marker.orbitRadius, -- 219
			json.marker.angleDeg, -- 219
			1, -- 219
			center.gm, -- 219
			nil -- 219
		) -- 219
		targetIndex = 0 -- 220
		tolerance = json.marker.tolerance -- 220
		for ____, e in ipairs(json.transfer.orbital.encounters) do -- 221
			if e.planetIndex < 1 or e.planetIndex >= #planets then -- 221
				return nil -- 221
			end -- 221
		end -- 221
	end -- 221
	if targetIndex < 0 then -- 221
		return nil -- 223
	end -- 223
	local stars = {} -- 225
	if json.stars ~= nil then -- 225
		do -- 225
			local s = 0 -- 227
			while s < #json.stars do -- 227
				local st = json.stars[s + 1] -- 228
				local dir = st.direction == -1 and -1 or 1 -- 229
				local phase = deg(st.angleDeg) -- 230
				stars[#stars + 1] = { -- 231
					x = st.orbitRadius * math.cos(dir * phase), -- 232
					y = st.orbitRadius * math.sin(dir * phase) -- 233
				} -- 233
				s = s + 1 -- 227
			end -- 227
		end -- 227
	end -- 227
	local probePhase = deg(json.probe.startAngleDeg) -- 238
	local probeStart = { -- 239
		x = json.probe.orbitRadius * math.cos(probePhase), -- 240
		y = json.probe.orbitRadius * math.sin(probePhase) -- 241
	} -- 241
	local probeVel0 = ____exports.tangentialVelocity(center.gm, json.probe.orbitRadius, probePhase, 1) -- 243
	local escapeRadius = json.environment ~= nil and json.environment.escapeRadius ~= nil and json.environment.escapeRadius or 1400 -- 245
	local maxSteps = json.environment ~= nil and json.environment.maxSteps ~= nil and json.environment.maxSteps or 1000 -- 247
	return { -- 250
		transfer = json.transfer, -- 251
		id = json.id, -- 252
		title = json.title, -- 253
		probeVariant = json.id >= 3 and "rtg" or "solar", -- 254
		brief = json.brief, -- 255
		probeStart = probeStart, -- 256
		probeVel0 = probeVel0, -- 257
		stars = stars, -- 258
		planets = planets, -- 259
		visuals = visuals, -- 260
		goal = { -- 261
			kind = "planet", -- 261
			planetIndex = targetIndex, -- 261
			tolerance = tolerance, -- 261
			offset = goalOffset, -- 261
			marker = marker -- 261
		}, -- 261
		dvBudget = json.probe.dvBudget, -- 262
		escapeRadius = escapeRadius, -- 263
		maxSteps = maxSteps, -- 264
		mission = { -- 265
			id = "L" .. __TS__NumberToFixed(json.id, 0), -- 266
			codeName = "ArcadeSlingshot" .. __TS__NumberToFixed(json.id, 0), -- 267
			historicalRef = "街机引力弹弓", -- 268
			subtitle = json.subtitle ~= nil and json.subtitle or json.title, -- 269
			vehicle = "flyby", -- 270
			challenges = json.transfer ~= nil and ({{desc = json.transfer.orbital ~= nil and "依次借力后进入目标轨道区域" or (json.transfer.flyby ~= nil and "安全完成月球减速掠过" or "抵达月球旁的目标光点"), type = "success"}}) or ({{desc = "穿透星门", type = "success"}, {desc = "收集至少 2 颗星尘", type = "stars", threshold = 2}, {desc = "收集全部 3 颗星尘", type = "stars", threshold = 3}}) -- 271
		} -- 271
	} -- 271
end -- 180
--- 星尘轨道（与 stars 数组顺序一致）。中心 gm 取该关第 0 颗天体。
function ____exports.starOrbitsOf(json, ____table) -- 281
	local center = protoOf(____table, json.centerBody) -- 282
	local mu = center ~= nil and center.gm or 0 -- 283
	local out = {} -- 284
	if json.stars == nil then -- 284
		return out -- 285
	end -- 285
	do -- 285
		local s = 0 -- 286
		while s < #json.stars do -- 286
			local st = json.stars[s + 1] -- 287
			local dir = st.direction == -1 and -1 or 1 -- 288
			out[#out + 1] = { -- 289
				gm = 0, -- 290
				radius = 0, -- 291
				orbitCenter = {x = 0, y = 0}, -- 292
				orbitRadius = st.orbitRadius, -- 293
				orbitPeriod = ____exports.keplerPeriod(st.orbitRadius, mu), -- 294
				phase0 = deg(st.angleDeg), -- 295
				orbitDirection = dir, -- 296
				name = "星尘" -- 297
			} -- 297
			s = s + 1 -- 286
		end -- 286
	end -- 286
	return out -- 300
end -- 281
--- 解析两份 JSON 文本。
-- `decode` 由调用方给：引擎里没有 `JSON.parse`，入口传 Dora 的 `json.decode`。
-- 任一关原型缺失、没有星门、或文本不是 JSON，返回空数组（调用方保留旧关卡）。
function ____exports.loadArcadeLevels(levelsText, bodiesText, decode) -- 308
	local empty = {levels = {}, starOrbits = {}} -- 313
	do -- 313
		local function ____catch(e) -- 313
			return true, empty -- 330
		end -- 330
		local ____try, ____hasReturned, ____returnValue = pcall(function() -- 330
			local ____table = decode(bodiesText) -- 315
			local parsed = decode(levelsText) -- 316
			if ____table == nil or parsed == nil then -- 316
				return true, empty -- 317
			end -- 317
			if ____table == nil or ____table.bodies == nil then -- 317
				return true, empty -- 318
			end -- 318
			if parsed == nil or parsed.levels == nil or #parsed.levels == 0 then -- 318
				return true, empty -- 319
			end -- 319
			local levels = {} -- 320
			local starOrbits = {} -- 321
			do -- 321
				local i = 0 -- 322
				while i < #parsed.levels do -- 322
					local lv = ____exports.convertLevelJson(parsed.levels[i + 1], ____table) -- 323
					if lv == nil then -- 323
						return true, empty -- 324
					end -- 324
					levels[#levels + 1] = lv -- 325
					starOrbits[#starOrbits + 1] = ____exports.starOrbitsOf(parsed.levels[i + 1], ____table) -- 326
					i = i + 1 -- 322
				end -- 322
			end -- 322
			return true, {levels = levels, starOrbits = starOrbits} -- 328
		end) -- 328
		if not ____try then -- 328
			____hasReturned, ____returnValue = ____catch(____hasReturned) -- 328
		end -- 328
		if ____hasReturned then -- 328
			return ____returnValue -- 314
		end -- 314
	end -- 314
end -- 308
return ____exports -- 308