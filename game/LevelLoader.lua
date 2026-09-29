-- [ts]: LevelLoader.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ObjectAssign = ____lualib.__TS__ObjectAssign -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
--- gm = 0 的公转体没写 spin 时用的角速度（rad/s）。内圈陨石必须转，否则「抓住空隙」不存在。
local DEFAULT_SPIN = 0.6 -- 19
local function deg(d) -- 104
	return d * math.pi / 180 -- 105
end -- 104
--- 开普勒周期。μ ≤ 0 或 r ≤ 0 时没有轨道，返回 0（静止）。
function ____exports.keplerPeriod(radius, mu) -- 109
	if radius <= 0 or mu <= 0 then -- 109
		return 0 -- 110
	end -- 110
	return 2 * math.pi * math.sqrt(radius * radius * radius / mu) -- 111
end -- 109
--- 圆轨速度 √(μ/r)。
function ____exports.circularSpeed(mu, radius) -- 115
	if radius <= 0 or mu <= 0 then -- 115
		return 0 -- 116
	end -- 116
	return math.sqrt(mu / radius) -- 117
end -- 115
--- 圆轨上的切向速度。direction +1 = 逆时针，速度 = ω × r 的切向。
-- phaseRad 是此刻的位置角，不是初始角。
function ____exports.tangentialVelocity(mu, radius, phaseRad, direction) -- 124
	local speed = ____exports.circularSpeed(mu, radius) -- 125
	local tx = -math.sin(phaseRad) -- 126
	local ty = math.cos(phaseRad) -- 127
	return {x = direction * tx * speed, y = direction * ty * speed} -- 128
end -- 124
local function protoOf(____table, key, json) -- 131
	if ____table.bodies == nil then -- 131
		return nil -- 132
	end -- 132
	local base = ____table.bodies[key] -- 133
	if base == nil then -- 133
		return nil -- 134
	end -- 134
	local override = json.bodyOverrides ~= nil and json.bodyOverrides[key] or nil -- 135
	if override == nil then -- 135
		return base -- 136
	end -- 136
	return __TS__ObjectAssign({}, base, {gm = override.gm ~= nil and override.gm or base.gm, radius = override.radius ~= nil and override.radius or base.radius}) -- 137
end -- 131
local function visualOf(proto) -- 140
	return { -- 141
		emissive = proto.emissive ~= nil and ({r = proto.emissive[1], g = proto.emissive[2], b = proto.emissive[3]}) or nil, -- 142
		r = proto.color[1], -- 143
		g = proto.color[2], -- 144
		b = proto.color[3], -- 145
		displayRadius = proto.radius, -- 146
		ring = proto.ring == true, -- 147
		model = proto.model -- 148
	} -- 148
end -- 140
--- 一颗绕中心天体的圆轨道。
-- mu > 0 时周期由开普勒求出；否则用 spin（rad/s）反推周期，让陨石也能转。
local function orbitBody(proto, orbitRadius, angleDeg, direction, mu, spin) -- 156
	local period = 0 -- 164
	if orbitRadius > 0 then -- 164
		if mu > 0 then -- 164
			period = ____exports.keplerPeriod(orbitRadius, mu) -- 166
		else -- 166
			local w = spin ~= nil and spin > 0 and spin or DEFAULT_SPIN -- 168
			period = 2 * math.pi / w -- 169
		end -- 169
	end -- 169
	return { -- 172
		gm = proto.gm, -- 173
		radius = proto.radius, -- 174
		orbitCenter = {x = 0, y = 0}, -- 175
		orbitRadius = orbitRadius, -- 176
		orbitPeriod = period, -- 177
		phase0 = deg(angleDeg), -- 178
		orbitDirection = direction, -- 179
		name = proto.name -- 180
	} -- 180
end -- 156
--- 把一份关卡 JSON 收成运行时 LevelDef。原型缺失时返回 undefined（这一关整关丢弃）。
function ____exports.convertLevelJson(json, ____table) -- 185
	local center = protoOf(____table, json.centerBody, json) -- 186
	if center == nil then -- 186
		return nil -- 187
	end -- 187
	local planets = {} -- 189
	local visuals = {} -- 190
	planets[#planets + 1] = { -- 192
		gm = center.gm, -- 193
		radius = center.radius, -- 194
		orbitCenter = {x = 0, y = 0}, -- 195
		orbitRadius = 0, -- 196
		orbitPeriod = 0, -- 197
		phase0 = 0, -- 198
		orbitDirection = 1, -- 199
		name = center.name -- 200
	} -- 200
	visuals[#visuals + 1] = visualOf(center) -- 202
	local targetIndex = -1 -- 204
	local tolerance = 65 -- 205
	local goalOffset = nil -- 206
	do -- 206
		local i = 0 -- 207
		while i < #json.orbiters do -- 207
			local o = json.orbiters[i + 1] -- 208
			local proto = protoOf(____table, o.body, json) -- 209
			if proto == nil then -- 209
				return nil -- 210
			end -- 210
			local dir = o.direction == -1 and -1 or 1 -- 211
			local body = orbitBody( -- 212
				proto, -- 212
				o.orbitRadius, -- 212
				o.angleDeg, -- 212
				dir, -- 212
				center.gm, -- 212
				o.spin -- 212
			) -- 212
			if proto.gm <= 0 then -- 212
				body.isObstacle = true -- 213
			end -- 213
			planets[#planets + 1] = body -- 214
			visuals[#visuals + 1] = visualOf(proto) -- 215
			if o.type == "target" and targetIndex < 0 then -- 215
				targetIndex = #planets - 1 -- 217
				goalOffset = o.offset -- 218
				if o.tolerance ~= nil and o.tolerance > 0 then -- 218
					tolerance = o.tolerance -- 219
				end -- 219
			end -- 219
			i = i + 1 -- 207
		end -- 207
	end -- 207
	local marker = nil -- 222
	if json.marker ~= nil and json.transfer ~= nil and json.transfer.orbital ~= nil then -- 222
		marker = orbitBody( -- 224
			{ -- 224
				name = "目标光点", -- 224
				gm = 0, -- 224
				radius = 0, -- 224
				model = "", -- 224
				color = {0, 1, 1} -- 224
			}, -- 224
			json.marker.orbitRadius, -- 224
			json.marker.angleDeg, -- 224
			1, -- 224
			center.gm, -- 224
			nil -- 224
		) -- 224
		targetIndex = 0 -- 225
		tolerance = json.marker.tolerance -- 225
	end -- 225
	local ____temp_0 -- 227
	if json.transfer ~= nil then -- 227
		____temp_0 = json.transfer.orbital -- 227
	else -- 227
		____temp_0 = nil -- 227
	end -- 227
	local orbital = ____temp_0 -- 227
	if orbital ~= nil then -- 227
		if orbital.region == nil == (orbital.targetFlyby == nil) then -- 227
			return nil -- 229
		end -- 229
		for ____, e in ipairs(orbital.encounters) do -- 230
			if e.planetIndex < 1 or e.planetIndex >= #planets then -- 230
				return nil -- 230
			end -- 230
		end -- 230
		local target = orbital.targetFlyby -- 231
		if target ~= nil and (target.planetIndex < 1 or target.planetIndex >= #planets) then -- 231
			return nil -- 232
		end -- 232
	end -- 232
	if targetIndex < 0 then -- 232
		return nil -- 234
	end -- 234
	local stars = {} -- 236
	if json.stars ~= nil then -- 236
		do -- 236
			local s = 0 -- 238
			while s < #json.stars do -- 238
				local st = json.stars[s + 1] -- 239
				local dir = st.direction == -1 and -1 or 1 -- 240
				local phase = deg(st.angleDeg) -- 241
				stars[#stars + 1] = { -- 242
					x = st.orbitRadius * math.cos(dir * phase), -- 243
					y = st.orbitRadius * math.sin(dir * phase) -- 244
				} -- 244
				s = s + 1 -- 238
			end -- 238
		end -- 238
	end -- 238
	local probePhase = deg(json.probe.startAngleDeg) -- 249
	local probeStart = { -- 250
		x = json.probe.orbitRadius * math.cos(probePhase), -- 251
		y = json.probe.orbitRadius * math.sin(probePhase) -- 252
	} -- 252
	local probeVel0 = ____exports.tangentialVelocity(center.gm, json.probe.orbitRadius, probePhase, 1) -- 254
	local escapeRadius = json.environment ~= nil and json.environment.escapeRadius ~= nil and json.environment.escapeRadius or 1400 -- 256
	local maxSteps = json.environment ~= nil and json.environment.maxSteps ~= nil and json.environment.maxSteps or 1000 -- 258
	return { -- 261
		transfer = json.transfer, -- 262
		id = json.id, -- 263
		title = json.title, -- 264
		probeVariant = json.id >= 3 and "rtg" or "solar", -- 265
		brief = json.brief, -- 266
		probeStart = probeStart, -- 267
		probeVel0 = probeVel0, -- 268
		stars = stars, -- 269
		planets = planets, -- 270
		visuals = visuals, -- 271
		goal = { -- 272
			kind = "planet", -- 272
			planetIndex = targetIndex, -- 272
			tolerance = tolerance, -- 272
			offset = goalOffset, -- 272
			marker = marker -- 272
		}, -- 272
		dvBudget = json.probe.dvBudget, -- 273
		escapeRadius = escapeRadius, -- 274
		maxSteps = maxSteps, -- 275
		mission = { -- 276
			id = "L" .. __TS__NumberToFixed(json.id, 0), -- 277
			codeName = "ArcadeSlingshot" .. __TS__NumberToFixed(json.id, 0), -- 278
			historicalRef = "街机引力弹弓", -- 279
			subtitle = json.subtitle ~= nil and json.subtitle or json.title, -- 280
			challenges = json.transfer ~= nil and ({{desc = json.transfer.orbital ~= nil and (json.transfer.orbital.targetFlyby ~= nil and "借金星减速，飞掠水星" or "依次借力后进入目标轨道区域") or (json.transfer.flyby ~= nil and "安全完成月球减速掠过" or "抵达月球旁的目标光点"), type = "success"}}) or ({{desc = "穿透星门", type = "success"}, {desc = "收集至少 2 颗星尘", type = "stars", threshold = 2}, {desc = "收集全部 3 颗星尘", type = "stars", threshold = 3}}) -- 281
		} -- 281
	} -- 281
end -- 185
--- 星尘轨道（与 stars 数组顺序一致）。中心 gm 取该关第 0 颗天体。
function ____exports.starOrbitsOf(json, ____table) -- 291
	local center = protoOf(____table, json.centerBody, json) -- 292
	local mu = center ~= nil and center.gm or 0 -- 293
	local out = {} -- 294
	if json.stars == nil then -- 294
		return out -- 295
	end -- 295
	do -- 295
		local s = 0 -- 296
		while s < #json.stars do -- 296
			local st = json.stars[s + 1] -- 297
			local dir = st.direction == -1 and -1 or 1 -- 298
			out[#out + 1] = { -- 299
				gm = 0, -- 300
				radius = 0, -- 301
				orbitCenter = {x = 0, y = 0}, -- 302
				orbitRadius = st.orbitRadius, -- 303
				orbitPeriod = ____exports.keplerPeriod(st.orbitRadius, mu), -- 304
				phase0 = deg(st.angleDeg), -- 305
				orbitDirection = dir, -- 306
				name = "星尘" -- 307
			} -- 307
			s = s + 1 -- 296
		end -- 296
	end -- 296
	return out -- 310
end -- 291
--- 解析两份 JSON 文本。
-- `decode` 由调用方给：引擎里没有 `JSON.parse`，入口传 Dora 的 `json.decode`。
-- 任一关原型缺失、没有星门、或文本不是 JSON，返回空数组（调用方保留旧关卡）。
function ____exports.loadArcadeLevels(levelsText, bodiesText, decode) -- 318
	local empty = {levels = {}, starOrbits = {}} -- 323
	do -- 323
		local function ____catch(e) -- 323
			return true, empty -- 340
		end -- 340
		local ____try, ____hasReturned, ____returnValue = pcall(function() -- 340
			local ____table = decode(bodiesText) -- 325
			local parsed = decode(levelsText) -- 326
			if ____table == nil or parsed == nil then -- 326
				return true, empty -- 327
			end -- 327
			if ____table == nil or ____table.bodies == nil then -- 327
				return true, empty -- 328
			end -- 328
			if parsed == nil or parsed.levels == nil or #parsed.levels == 0 then -- 328
				return true, empty -- 329
			end -- 329
			local levels = {} -- 330
			local starOrbits = {} -- 331
			do -- 331
				local i = 0 -- 332
				while i < #parsed.levels do -- 332
					local lv = ____exports.convertLevelJson(parsed.levels[i + 1], ____table) -- 333
					if lv == nil then -- 333
						return true, empty -- 334
					end -- 334
					levels[#levels + 1] = lv -- 335
					starOrbits[#starOrbits + 1] = ____exports.starOrbitsOf(parsed.levels[i + 1], ____table) -- 336
					i = i + 1 -- 332
				end -- 332
			end -- 332
			return true, {levels = levels, starOrbits = starOrbits} -- 338
		end) -- 338
		if not ____try then -- 338
			____hasReturned, ____returnValue = ____catch(____hasReturned) -- 338
		end -- 338
		if ____hasReturned then -- 338
			return ____returnValue -- 324
		end -- 324
	end -- 324
end -- 318
return ____exports -- 318