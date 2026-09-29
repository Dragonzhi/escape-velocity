-- [ts]: Transfer.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local __TS__ArrayPush = ____lualib.__TS__ArrayPush -- 1
local __TS__ArrayIndexOf = ____lualib.__TS__ArrayIndexOf -- 1
local __TS__ArrayEvery = ____lualib.__TS__ArrayEvery -- 1
local ____exports = {} -- 1
local specificEnergy -- 1
local ____Gravity = require("game.Gravity") -- 2
local bodyPositionAt = ____Gravity.bodyPositionAt -- 2
local distance = ____Gravity.distance -- 2
function specificEnergy(flight, index, center, t) -- 137
	local pos = bodyPositionAt(center, t) -- 138
	local before = bodyPositionAt(center, t - 0.001) -- 140
	local after = bodyPositionAt(center, t + 0.001) -- 141
	local vx = flight.velocities[index + 1].x - (after.x - before.x) / 0.002 -- 142
	local vy = flight.velocities[index + 1].y - (after.y - before.y) / 0.002 -- 143
	local r = distance(flight.points[index + 1], pos) -- 144
	return r > 0 and (vx * vx + vy * vy) / 2 - center.gm / r or -1000000000 -- 145
end -- 145
--- 只分析首次会遇；光点无关，必须安全走完进入→近月点→离开。
function ____exports.analyzeFlyby(flight, center, moon, cfg, dt, t0) -- 149
	local entry = -1 -- 150
	local peri = -1 -- 150
	local exit = -1 -- 150
	local nearest = 1000000000 -- 150
	local last = #flight.points - 1 -- 151
	do -- 151
		local i = 0 -- 152
		while i <= last do -- 152
			do -- 152
				local d = distance( -- 153
					flight.points[i + 1], -- 153
					bodyPositionAt(moon, t0 + i * dt) -- 153
				) -- 153
				if entry < 0 and d <= cfg.encounterRadius then -- 153
					entry = i -- 154
				end -- 154
				if entry < 0 then -- 154
					goto __continue35 -- 155
				end -- 155
				if d < nearest then -- 155
					nearest = d -- 156
					peri = i -- 156
				end -- 156
				if i > entry and d >= cfg.encounterRadius then -- 156
					exit = i -- 157
					break -- 157
				end -- 157
			end -- 157
			::__continue35:: -- 157
			i = i + 1 -- 152
		end -- 152
	end -- 152
	local drop = entry >= 0 and exit >= 0 and specificEnergy(flight, entry, center, t0 + entry * dt) - specificEnergy(flight, exit, center, t0 + exit * dt) or 0 -- 159
	local complete = entry > 0 and peri > entry and exit > peri and nearest >= math.max(moon.radius, cfg.minPeriapsis) and nearest <= cfg.maxPeriapsis and drop >= cfg.minEnergyDrop and exit or -1 -- 161
	local ____end = last -- 163
	if complete >= 0 then -- 163
		____end = math.min( -- 165
			last, -- 165
			complete + math.floor(cfg.maxViewingTime / dt) -- 165
		) -- 165
		do -- 165
			local i = complete + 1 -- 166
			while i <= ____end do -- 166
				local r = distance( -- 167
					flight.points[i + 1], -- 167
					bodyPositionAt(center, t0 + i * dt) -- 167
				) -- 167
				local prev = distance( -- 168
					flight.points[i], -- 168
					bodyPositionAt(center, t0 + (i - 1) * dt) -- 168
				) -- 168
				if prev > cfg.returnRadius and r <= cfg.returnRadius then -- 168
					____end = i -- 169
					break -- 169
				end -- 169
				i = i + 1 -- 166
			end -- 166
		end -- 166
	end -- 166
	return { -- 172
		entryIndex = entry, -- 172
		periapsisIndex = peri, -- 172
		exitIndex = exit, -- 172
		completionIndex = complete, -- 172
		viewEndIndex = ____end, -- 172
		periapsis = nearest, -- 172
		energyDrop = drop -- 172
	} -- 172
end -- 149
--- 完整会遇的日心能量变化与对应行星做功，两者共同验证借力。
function ____exports.analyzeOrbitalMission(flight, bodies, cfg, dt, t0) -- 71
	local stages = {} -- 72
	local last = #flight.points - 1 -- 73
	local after = -1 -- 74
	local ordered = true -- 75
	for ____, spec in ipairs(cfg.encounters) do -- 76
		local body = bodies[spec.planetIndex + 1] -- 77
		local entry = -1 -- 78
		local peri = -1 -- 78
		local exit = -1 -- 78
		local nearest = 1000000000 -- 78
		if body ~= nil then -- 78
			do -- 78
				local i = 0 -- 79
				while i <= last do -- 79
					do -- 79
						local d = distance( -- 80
							flight.points[i + 1], -- 80
							bodyPositionAt(body, t0 + i * dt) -- 80
						) -- 80
						if entry < 0 and d <= spec.encounterRadius then -- 80
							entry = i -- 81
						end -- 81
						if entry < 0 then -- 81
							goto __continue6 -- 82
						end -- 82
						if d < nearest then -- 82
							nearest = d -- 83
							peri = i -- 83
						end -- 83
						if i > entry and d >= spec.encounterRadius then -- 83
							exit = i -- 84
							break -- 84
						end -- 84
					end -- 84
					::__continue6:: -- 84
					i = i + 1 -- 79
				end -- 79
			end -- 79
		end -- 79
		local change = entry >= 0 and exit >= 0 and specificEnergy(flight, exit, bodies[1], t0 + exit * dt) - specificEnergy(flight, entry, bodies[1], t0 + entry * dt) or 0 -- 86
		local work = 0 -- 87
		if body ~= nil and entry >= 0 and exit >= 0 then -- 87
			do -- 87
				local i = entry -- 88
				while i < exit do -- 88
					local power = 0 -- 89
					do -- 89
						local k = i -- 90
						while k <= i + 1 do -- 90
							local bp = bodyPositionAt(body, t0 + k * dt) -- 91
							local p = flight.points[k + 1] -- 91
							local v = flight.velocities[k + 1] -- 91
							local x = bp.x - p.x -- 92
							local y = bp.y - p.y -- 92
							local r = math.sqrt(x * x + y * y) -- 92
							if r > 0 then -- 92
								power = power + body.gm * (v.x * x + v.y * y) / (r * r * r) -- 93
							end -- 93
							k = k + 1 -- 90
						end -- 90
					end -- 90
					work = work + power * dt / 2 -- 95
					i = i + 1 -- 88
				end -- 88
			end -- 88
		end -- 88
		local sign = spec.energyDirection == "gain" and 1 or -1 -- 97
		local passed = ordered and body ~= nil and entry > after and entry > 0 and peri > entry and exit > peri and nearest >= math.max(body.radius, spec.minPeriapsis) and nearest <= spec.maxPeriapsis and sign * change >= spec.minEnergyChange and sign * work >= spec.minWork -- 98
		stages[#stages + 1] = { -- 101
			planetIndex = spec.planetIndex, -- 101
			entryIndex = entry, -- 101
			periapsisIndex = peri, -- 101
			exitIndex = exit, -- 101
			periapsis = nearest, -- 101
			energyChange = change, -- 101
			work = work, -- 101
			passed = passed -- 101
		} -- 101
		ordered = passed -- 102
		after = exit -- 102
	end -- 102
	local complete = -1 -- 104
	if ordered and #stages > 0 then -- 104
		do -- 104
			local i = math.max(1, after + 1) -- 105
			while i <= last do -- 105
				local r = distance( -- 106
					flight.points[i + 1], -- 106
					bodyPositionAt(bodies[1], t0 + i * dt) -- 106
				) -- 106
				local prev = distance( -- 107
					flight.points[i], -- 107
					bodyPositionAt(bodies[1], t0 + (i - 1) * dt) -- 107
				) -- 107
				local rg = cfg.region -- 108
				local ____temp_1 = r >= rg.minRadius and r <= rg.maxRadius -- 109
				if ____temp_1 then -- 109
					local ____temp_0 -- 109
					if rg.direction == "inward" then -- 109
						____temp_0 = prev > rg.maxRadius and r < prev -- 109
					else -- 109
						____temp_0 = prev < rg.minRadius and r > prev -- 109
					end -- 109
					____temp_1 = ____temp_0 -- 109
				end -- 109
				if ____temp_1 then -- 109
					complete = i -- 109
					break -- 109
				end -- 109
				i = i + 1 -- 105
			end -- 105
		end -- 105
	end -- 105
	local first = #stages > 0 and stages[1] or nil -- 111
	return { -- 112
		encounters = stages, -- 112
		entryIndex = first ~= nil and first.entryIndex or -1, -- 112
		periapsisIndex = first ~= nil and first.periapsisIndex or -1, -- 112
		exitIndex = first ~= nil and first.exitIndex or -1, -- 113
		periapsis = first ~= nil and first.periapsis or 1000000000, -- 113
		energyDrop = first ~= nil and -first.energyChange or 0, -- 113
		completionIndex = complete, -- 114
		viewEndIndex = complete >= 0 and math.min( -- 114
			last, -- 114
			complete + math.floor(cfg.maxViewingTime / dt) -- 114
		) or last -- 114
	} -- 114
end -- 71
function ____exports.analyzeTransfer(flight, bodies, targetIndex, tr, dt, t0) -- 117
	if tr.orbital ~= nil then -- 117
		return ____exports.analyzeOrbitalMission( -- 118
			flight, -- 118
			bodies, -- 118
			tr.orbital, -- 118
			dt, -- 118
			t0 -- 118
		) -- 118
	end -- 118
	return tr.flyby ~= nil and ____exports.analyzeFlyby( -- 119
		flight, -- 119
		bodies[1], -- 119
		bodies[targetIndex + 1], -- 119
		tr.flyby, -- 119
		dt, -- 119
		t0 -- 119
	) or nil -- 119
end -- 117
function ____exports.transferCinematic(tr) -- 122
	return tr ~= nil and (tr.flyby ~= nil or tr.orbital ~= nil) -- 123
end -- 122
local function slowTimes(tr, analysis, dt) -- 126
	local out = {} -- 127
	if analysis == nil then -- 127
		return out -- 128
	end -- 128
	local cfg = tr.orbital ~= nil and tr.orbital or tr.flyby -- 129
	if cfg == nil then -- 129
		return out -- 130
	end -- 130
	local indices = analysis.encounters ~= nil and __TS__ArrayMap( -- 131
		analysis.encounters, -- 131
		function(____, e) return e.periapsisIndex end -- 131
	) or ({analysis.periapsisIndex}) -- 131
	for ____, i in ipairs(indices) do -- 132
		if i >= 0 then -- 132
			__TS__ArrayPush(out, i * dt - cfg.slowWindow, i * dt + cfg.slowWindow) -- 132
		end -- 132
	end -- 132
	return out -- 133
end -- 126
function ____exports.transferPlaybackRate(time, burn, tr, analysis, dt) -- 175
	if time < burn then -- 175
		return 1 -- 176
	end -- 176
	local times = slowTimes(tr, analysis, dt) -- 177
	do -- 177
		local i = 0 -- 178
		while i < #times do -- 178
			if time >= times[i + 1] and time < times[i + 1 + 1] then -- 178
				return 1 -- 178
			end -- 178
			i = i + 2 -- 178
		end -- 178
	end -- 178
	return tr.coastPlayback -- 179
end -- 175
--- 跨倍率边界分段推进，30/60/120 FPS 下点火和近月观赏段的时长相同。
function ____exports.advanceTransferPlayback(time, wallDt, baseRate, burn, tr, analysis, dt) -- 183
	if baseRate <= 0 or wallDt <= 0 then -- 183
		return time -- 184
	end -- 184
	local remaining = wallDt -- 185
	local boundaries = { -- 186
		burn, -- 186
		table.unpack(slowTimes(tr, analysis, dt)) -- 186
	} -- 186
	do -- 186
		local n = 0 -- 187
		while n <= #boundaries and remaining > 1e-10 do -- 187
			local rate = baseRate * ____exports.transferPlaybackRate( -- 188
				time, -- 188
				burn, -- 188
				tr, -- 188
				analysis, -- 188
				dt -- 188
			) -- 188
			local next = 1000000000 -- 189
			do -- 189
				local i = 0 -- 190
				while i < #boundaries do -- 190
					if boundaries[i + 1] > time + 1e-10 and boundaries[i + 1] < next then -- 190
						next = boundaries[i + 1] -- 190
					end -- 190
					i = i + 1 -- 190
				end -- 190
			end -- 190
			local ____until = (next - time) / rate -- 191
			if ____until >= remaining then -- 191
				return time + remaining * rate -- 192
			end -- 192
			time = next -- 193
			remaining = remaining - ____until -- 194
			n = n + 1 -- 187
		end -- 187
	end -- 187
	return time -- 196
end -- 183
function ____exports.nextCameraFocus(mode, modes) -- 202
	if modes ~= nil then -- 202
		local i = __TS__ArrayIndexOf(modes, mode) -- 204
		return modes[(i + 1) % #modes + 1] -- 205
	end -- 205
	if mode == "Auto" then -- 205
		return "Probe" -- 207
	end -- 207
	if mode == "Probe" then -- 207
		return "Moon" -- 208
	end -- 208
	if mode == "Moon" then -- 208
		return "Earth" -- 209
	end -- 209
	if mode == "Earth" then -- 209
		return "Overview" -- 210
	end -- 210
	return "Auto" -- 211
end -- 202
function ____exports.transferShotAt(time, burn, analysis, cfg, dt) -- 214
	if time <= burn + 1.2 then -- 214
		return "Launch" -- 215
	end -- 215
	if analysis ~= nil and analysis.entryIndex >= 0 and time >= analysis.entryIndex * dt then -- 215
		if analysis.completionIndex >= 0 and time >= analysis.completionIndex * dt then -- 215
			return time < analysis.completionIndex * dt + cfg.overviewDuration and "Overview" or "Earth" -- 218
		end -- 218
		if analysis.exitIndex < 0 or time <= analysis.exitIndex * dt then -- 218
			return "Moon" -- 220
		end -- 220
	end -- 220
	return "Cruise" -- 222
end -- 214
--- 拖动长度只改变远地点；方向由出发圆轨的顺行切线确定。
function ____exports.planTransfer(mu, radius, vel, power, maxRadius, mode, minRadius) -- 232
	local p = math.max( -- 233
		0, -- 233
		math.min(1, power) -- 233
	) -- 233
	local ra = mode == "lowerPeriapsis" and radius + (math.max( -- 234
		1, -- 234
		math.min(radius, minRadius ~= nil and minRadius or radius) -- 234
	) - radius) * p or radius + (math.max(radius, maxRadius) - radius) * p -- 234
	local a = (radius + ra) / 2 -- 235
	local dv = mu > 0 and radius > 0 and math.sqrt(mu * (2 / radius - 1 / a)) - math.sqrt(mu / radius) or 0 -- 236
	local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y) -- 237
	return { -- 238
		apoapsis = ra, -- 238
		dv = math.abs(dv), -- 238
		velocity = {x = speed > 0 and vel.x * dv / speed or 0, y = speed > 0 and vel.y * dv / speed or 0} -- 238
	} -- 238
end -- 232
function ____exports.orbitalShotAt(time, burn, analysis, cfg, dt) -- 241
	if time <= burn + 1.2 then -- 241
		return "Launch" -- 242
	end -- 242
	if analysis ~= nil and analysis.encounters ~= nil then -- 242
		do -- 242
			local i = 0 -- 243
			while i < #analysis.encounters do -- 243
				local e = analysis.encounters[i + 1] -- 244
				if e.entryIndex >= 0 and time >= e.entryIndex * dt and (e.exitIndex < 0 or time <= e.exitIndex * dt) then -- 244
					return cfg.encounters[i + 1].focus -- 245
				end -- 245
				i = i + 1 -- 243
			end -- 243
		end -- 243
	end -- 243
	return analysis ~= nil and analysis.exitIndex >= 0 and analysis.encounters ~= nil and __TS__ArrayEvery( -- 247
		analysis.encounters, -- 247
		function(____, e) return e.passed and time > e.exitIndex * dt end -- 247
	) and "Overview" or "Cruise" -- 247
end -- 241
--- 独立显示时间；调用方每帧累加 wallDt，暂停与物理倍率不参与。
function ____exports.successMarkerFrame(elapsed) -- 251
	if elapsed < 0 then -- 251
		return {visible = true, alpha = 1, scale = 1, ring = 0} -- 252
	end -- 252
	if elapsed >= 0.6 then -- 252
		return {visible = false, alpha = 0, scale = 1, ring = 0} -- 253
	end -- 253
	local u = math.max(0, (elapsed - 0.12) / 0.48) -- 254
	return {visible = true, alpha = 1 - u, scale = elapsed < 0.12 and 1 + elapsed / 0.12 or 2 - u, ring = elapsed < 0.12 and 0 or 8 + 30 * u} -- 255
end -- 251
return ____exports -- 251