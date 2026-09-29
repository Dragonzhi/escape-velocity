-- [ts]: LevelLoader.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ObjectAssign = ____lualib.__TS__ObjectAssign -- 1
local __TS__ArrayIndexOf = ____lualib.__TS__ArrayIndexOf -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
--- gm = 0 的公转体没写 spin 时用的角速度（rad/s）。内圈陨石必须转，否则「抓住空隙」不存在。
local DEFAULT_SPIN = 0.6 -- 19
local function deg(d) -- 106
	return d * math.pi / 180 -- 107
end -- 106
--- 开普勒周期。μ ≤ 0 或 r ≤ 0 时没有轨道，返回 0（静止）。
function ____exports.keplerPeriod(radius, mu) -- 111
	if radius <= 0 or mu <= 0 then -- 111
		return 0 -- 112
	end -- 112
	return 2 * math.pi * math.sqrt(radius * radius * radius / mu) -- 113
end -- 111
--- 圆轨速度 √(μ/r)。
function ____exports.circularSpeed(mu, radius) -- 117
	if radius <= 0 or mu <= 0 then -- 117
		return 0 -- 118
	end -- 118
	return math.sqrt(mu / radius) -- 119
end -- 117
--- 圆轨上的切向速度。direction +1 = 逆时针，速度 = ω × r 的切向。
-- phaseRad 是此刻的位置角，不是初始角。
function ____exports.tangentialVelocity(mu, radius, phaseRad, direction) -- 126
	local speed = ____exports.circularSpeed(mu, radius) -- 127
	local tx = -math.sin(phaseRad) -- 128
	local ty = math.cos(phaseRad) -- 129
	return {x = direction * tx * speed, y = direction * ty * speed} -- 130
end -- 126
local function protoOf(____table, key, json) -- 133
	if ____table.bodies == nil then -- 133
		return nil -- 134
	end -- 134
	local base = ____table.bodies[key] -- 135
	if base == nil then -- 135
		return nil -- 136
	end -- 136
	local override = json.bodyOverrides ~= nil and json.bodyOverrides[key] or nil -- 137
	if override == nil then -- 137
		return base -- 138
	end -- 138
	return __TS__ObjectAssign({}, base, {gm = override.gm ~= nil and override.gm or base.gm, radius = override.radius ~= nil and override.radius or base.radius}) -- 139
end -- 133
local function visualOf(proto) -- 142
	return { -- 143
		emissive = proto.emissive ~= nil and ({r = proto.emissive[1], g = proto.emissive[2], b = proto.emissive[3]}) or nil, -- 144
		r = proto.color[1], -- 145
		g = proto.color[2], -- 146
		b = proto.color[3], -- 147
		displayRadius = proto.radius, -- 148
		ring = proto.ring == true, -- 149
		model = proto.model -- 150
	} -- 150
end -- 142
--- 一颗绕中心天体的圆轨道。
-- mu > 0 时周期由开普勒求出；否则用 spin（rad/s）反推周期，让陨石也能转。
local function orbitBody(proto, orbitRadius, angleDeg, direction, mu, spin) -- 158
	local period = 0 -- 166
	if orbitRadius > 0 then -- 166
		if mu > 0 then -- 166
			period = ____exports.keplerPeriod(orbitRadius, mu) -- 168
		else -- 168
			local w = spin ~= nil and spin > 0 and spin or DEFAULT_SPIN -- 170
			period = 2 * math.pi / w -- 171
		end -- 171
	end -- 171
	return { -- 174
		gm = proto.gm, -- 175
		radius = proto.radius, -- 176
		orbitCenter = {x = 0, y = 0}, -- 177
		orbitRadius = orbitRadius, -- 178
		orbitPeriod = period, -- 179
		phase0 = deg(angleDeg), -- 180
		orbitDirection = direction, -- 181
		name = proto.name -- 182
	} -- 182
end -- 158
--- 把一份关卡 JSON 收成运行时 LevelDef。原型缺失时返回 undefined（这一关整关丢弃）。
function ____exports.convertLevelJson(json, ____table) -- 187
	local center = protoOf(____table, json.centerBody, json) -- 188
	if center == nil then -- 188
		return nil -- 189
	end -- 189
	local planets = {} -- 191
	local visuals = {} -- 192
	local bodyKeys = {} -- 193
	planets[#planets + 1] = { -- 195
		gm = center.gm, -- 196
		radius = center.radius, -- 197
		orbitCenter = {x = 0, y = 0}, -- 198
		orbitRadius = 0, -- 199
		orbitPeriod = 0, -- 200
		phase0 = 0, -- 201
		orbitDirection = 1, -- 202
		name = center.name -- 203
	} -- 203
	visuals[#visuals + 1] = visualOf(center) -- 205
	bodyKeys[#bodyKeys + 1] = json.centerBody -- 206
	local targetIndex = -1 -- 208
	local tolerance = 65 -- 209
	local goalOffset = nil -- 210
	do -- 210
		local i = 0 -- 211
		while i < #json.orbiters do -- 211
			local o = json.orbiters[i + 1] -- 212
			local proto = protoOf(____table, o.body, json) -- 213
			if proto == nil then -- 213
				return nil -- 214
			end -- 214
			local dir = o.direction == -1 and -1 or 1 -- 215
			local body = orbitBody( -- 216
				proto, -- 216
				o.orbitRadius, -- 216
				o.angleDeg, -- 216
				dir, -- 216
				center.gm, -- 216
				o.spin -- 216
			) -- 216
			if proto.gm <= 0 then -- 216
				body.isObstacle = true -- 217
			end -- 217
			planets[#planets + 1] = body -- 218
			visuals[#visuals + 1] = visualOf(proto) -- 219
			bodyKeys[#bodyKeys + 1] = o.body -- 220
			if o.type == "target" and targetIndex < 0 then -- 220
				targetIndex = #planets - 1 -- 222
				goalOffset = o.offset -- 223
				if o.tolerance ~= nil and o.tolerance > 0 then -- 223
					tolerance = o.tolerance -- 224
				end -- 224
			end -- 224
			i = i + 1 -- 211
		end -- 211
	end -- 211
	local marker = nil -- 227
	if json.marker ~= nil and json.transfer ~= nil and json.transfer.orbital ~= nil then -- 227
		marker = orbitBody( -- 229
			{ -- 229
				name = "目标光点", -- 229
				gm = 0, -- 229
				radius = 0, -- 229
				model = "", -- 229
				color = {0, 1, 1} -- 229
			}, -- 229
			json.marker.orbitRadius, -- 229
			json.marker.angleDeg, -- 229
			1, -- 229
			center.gm, -- 229
			nil -- 229
		) -- 229
		targetIndex = 0 -- 230
		tolerance = json.marker.tolerance -- 230
	end -- 230
	local ____temp_0 -- 232
	if json.transfer ~= nil then -- 232
		____temp_0 = json.transfer.orbital -- 232
	else -- 232
		____temp_0 = nil -- 232
	end -- 232
	local orbital = ____temp_0 -- 232
	if orbital ~= nil then -- 232
		if orbital.region == nil == (orbital.targetFlyby == nil) then -- 232
			return nil -- 234
		end -- 234
		for ____, e in ipairs(orbital.encounters) do -- 235
			if e.planetIndex < 1 or e.planetIndex >= #planets then -- 235
				return nil -- 235
			end -- 235
		end -- 235
		local target = orbital.targetFlyby -- 236
		if target ~= nil and (target.planetIndex < 1 or target.planetIndex >= #planets) then -- 236
			return nil -- 237
		end -- 237
	end -- 237
	local region -- 239
	if json.goal ~= nil then -- 239
		local bodyIndex = __TS__ArrayIndexOf(bodyKeys, json.goal.body) -- 241
		if bodyIndex < 0 or json.goal.minAltitude < 0 or json.goal.maxAltitude < json.goal.minAltitude then -- 241
			return nil -- 242
		end -- 242
		region = { -- 243
			bodyIndex = bodyIndex, -- 243
			minAltitude = json.goal.minAltitude, -- 243
			maxAltitude = json.goal.maxAltitude, -- 243
			direction = json.goal.direction, -- 243
			requiresEscape = json.goal.requiresEscape -- 243
		} -- 243
		if targetIndex < 0 then -- 243
			targetIndex = bodyIndex -- 244
			tolerance = json.goal.maxAltitude -- 244
		end -- 244
	end -- 244
	if targetIndex < 0 then -- 244
		return nil -- 246
	end -- 246
	local bonusPoints = {} -- 247
	if json.bonusPoints ~= nil then -- 247
		for ____, point in ipairs(json.bonusPoints) do -- 248
			if #point.id == 0 or point.tolerance <= 0 then -- 248
				return nil -- 249
			end -- 249
			if point.body ~= nil then -- 249
				local bodyIndex = __TS__ArrayIndexOf(bodyKeys, point.body) -- 251
				if bodyIndex < 0 then -- 251
					return nil -- 252
				end -- 252
				bonusPoints[#bonusPoints + 1] = {id = point.id, bodyIndex = bodyIndex, offset = point.offset, tolerance = point.tolerance} -- 253
			elseif point.orbitRadius ~= nil and point.angleDeg ~= nil then -- 253
				local orbit = orbitBody( -- 255
					{ -- 255
						name = point.id, -- 255
						gm = 0, -- 255
						radius = 0, -- 255
						model = "", -- 255
						color = {0, 1, 0} -- 255
					}, -- 255
					point.orbitRadius, -- 255
					point.angleDeg, -- 255
					point.direction == -1 and -1 or 1, -- 255
					center.gm, -- 255
					nil -- 255
				) -- 255
				bonusPoints[#bonusPoints + 1] = {id = point.id, orbit = orbit, tolerance = point.tolerance} -- 256
			else -- 256
				return nil -- 257
			end -- 257
		end -- 257
	end -- 257
	local stars = {} -- 260
	if json.stars ~= nil then -- 260
		do -- 260
			local s = 0 -- 262
			while s < #json.stars do -- 262
				local st = json.stars[s + 1] -- 263
				local dir = st.direction == -1 and -1 or 1 -- 264
				local phase = deg(st.angleDeg) -- 265
				stars[#stars + 1] = { -- 266
					x = st.orbitRadius * math.cos(dir * phase), -- 267
					y = st.orbitRadius * math.sin(dir * phase) -- 268
				} -- 268
				s = s + 1 -- 262
			end -- 262
		end -- 262
	end -- 262
	local probePhase = deg(json.probe.startAngleDeg) -- 273
	local probeStart = { -- 274
		x = json.probe.orbitRadius * math.cos(probePhase), -- 275
		y = json.probe.orbitRadius * math.sin(probePhase) -- 276
	} -- 276
	local probeVel0 = ____exports.tangentialVelocity(center.gm, json.probe.orbitRadius, probePhase, 1) -- 278
	local escapeRadius = json.environment ~= nil and json.environment.escapeRadius ~= nil and json.environment.escapeRadius or 1400 -- 280
	local maxSteps = json.environment ~= nil and json.environment.maxSteps ~= nil and json.environment.maxSteps or 1000 -- 282
	return { -- 285
		transfer = json.transfer, -- 286
		id = json.id, -- 287
		title = json.title, -- 288
		probeVariant = json.id >= 3 and "rtg" or "solar", -- 289
		brief = json.brief, -- 290
		probeStart = probeStart, -- 291
		probeVel0 = probeVel0, -- 292
		stars = stars, -- 293
		planets = planets, -- 294
		visuals = visuals, -- 295
		goal = { -- 296
			kind = "planet", -- 296
			planetIndex = targetIndex, -- 296
			tolerance = tolerance, -- 296
			offset = goalOffset, -- 296
			marker = marker, -- 296
			region = region -- 296
		}, -- 296
		bonusPoints = bonusPoints, -- 297
		dvBudget = json.probe.dvBudget, -- 298
		escapeRadius = escapeRadius, -- 299
		maxSteps = maxSteps, -- 300
		mission = { -- 301
			id = "L" .. __TS__NumberToFixed(json.id, 0), -- 302
			codeName = "ArcadeSlingshot" .. __TS__NumberToFixed(json.id, 0), -- 303
			historicalRef = "街机引力弹弓", -- 304
			subtitle = json.subtitle ~= nil and json.subtitle or json.title, -- 305
			challenges = json.transfer ~= nil and ({{desc = json.transfer.orbital ~= nil and (json.transfer.orbital.targetFlyby ~= nil and "借金星减速，飞掠水星" or "依次借力后进入目标轨道区域") or (json.transfer.flyby ~= nil and "安全完成月球减速掠过" or "抵达月球旁的目标光点"), type = "success"}}) or ({{desc = "穿透星门", type = "success"}, {desc = "收集至少 2 颗星尘", type = "stars", threshold = 2}, {desc = "收集全部 3 颗星尘", type = "stars", threshold = 3}}) -- 306
		} -- 306
	} -- 306
end -- 187
--- 星尘轨道（与 stars 数组顺序一致）。中心 gm 取该关第 0 颗天体。
function ____exports.starOrbitsOf(json, ____table) -- 316
	local center = protoOf(____table, json.centerBody, json) -- 317
	local mu = center ~= nil and center.gm or 0 -- 318
	local out = {} -- 319
	if json.stars == nil then -- 319
		return out -- 320
	end -- 320
	do -- 320
		local s = 0 -- 321
		while s < #json.stars do -- 321
			local st = json.stars[s + 1] -- 322
			local dir = st.direction == -1 and -1 or 1 -- 323
			out[#out + 1] = { -- 324
				gm = 0, -- 325
				radius = 0, -- 326
				orbitCenter = {x = 0, y = 0}, -- 327
				orbitRadius = st.orbitRadius, -- 328
				orbitPeriod = ____exports.keplerPeriod(st.orbitRadius, mu), -- 329
				phase0 = deg(st.angleDeg), -- 330
				orbitDirection = dir, -- 331
				name = "星尘" -- 332
			} -- 332
			s = s + 1 -- 321
		end -- 321
	end -- 321
	return out -- 335
end -- 316
--- 解析两份 JSON 文本。
-- `decode` 由调用方给：引擎里没有 `JSON.parse`，入口传 Dora 的 `json.decode`。
-- 任一关原型缺失、没有星门、或文本不是 JSON，返回空数组（调用方保留旧关卡）。
function ____exports.loadArcadeLevels(levelsText, bodiesText, decode) -- 343
	local empty = {levels = {}, starOrbits = {}} -- 348
	do -- 348
		local function ____catch(e) -- 348
			return true, empty -- 365
		end -- 365
		local ____try, ____hasReturned, ____returnValue = pcall(function() -- 365
			local ____table = decode(bodiesText) -- 350
			local parsed = decode(levelsText) -- 351
			if ____table == nil or parsed == nil then -- 351
				return true, empty -- 352
			end -- 352
			if ____table == nil or ____table.bodies == nil then -- 352
				return true, empty -- 353
			end -- 353
			if parsed == nil or parsed.levels == nil or #parsed.levels == 0 then -- 353
				return true, empty -- 354
			end -- 354
			local levels = {} -- 355
			local starOrbits = {} -- 356
			do -- 356
				local i = 0 -- 357
				while i < #parsed.levels do -- 357
					local lv = ____exports.convertLevelJson(parsed.levels[i + 1], ____table) -- 358
					if lv == nil then -- 358
						return true, empty -- 359
					end -- 359
					levels[#levels + 1] = lv -- 360
					starOrbits[#starOrbits + 1] = ____exports.starOrbitsOf(parsed.levels[i + 1], ____table) -- 361
					i = i + 1 -- 357
				end -- 357
			end -- 357
			return true, {levels = levels, starOrbits = starOrbits} -- 363
		end) -- 363
		if not ____try then -- 363
			____hasReturned, ____returnValue = ____catch(____hasReturned) -- 363
		end -- 363
		if ____hasReturned then -- 363
			return ____returnValue -- 349
		end -- 349
	end -- 349
end -- 343
return ____exports -- 343