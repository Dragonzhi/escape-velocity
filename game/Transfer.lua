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
function specificEnergy(flight, index, center, t) -- 160
	local pos = bodyPositionAt(center, t) -- 161
	local before = bodyPositionAt(center, t - 0.001) -- 163
	local after = bodyPositionAt(center, t + 0.001) -- 164
	local vx = flight.velocities[index + 1].x - (after.x - before.x) / 0.002 -- 165
	local vy = flight.velocities[index + 1].y - (after.y - before.y) / 0.002 -- 166
	local r = distance(flight.points[index + 1], pos) -- 167
	return r > 0 and (vx * vx + vy * vy) / 2 - center.gm / r or -1000000000 -- 168
end -- 168
--- 只分析首次会遇；光点无关，必须安全走完进入→近月点→离开。
function ____exports.analyzeFlyby(flight, center, moon, cfg, dt, t0) -- 172
	local entry = -1 -- 173
	local peri = -1 -- 173
	local exit = -1 -- 173
	local nearest = 1000000000 -- 173
	local last = #flight.points - 1 -- 174
	do -- 174
		local i = 0 -- 175
		while i <= last do -- 175
			do -- 175
				local d = distance( -- 176
					flight.points[i + 1], -- 176
					bodyPositionAt(moon, t0 + i * dt) -- 176
				) -- 176
				if entry < 0 and d <= cfg.encounterRadius then -- 176
					entry = i -- 177
				end -- 177
				if entry < 0 then -- 177
					goto __continue44 -- 178
				end -- 178
				if d < nearest then -- 178
					nearest = d -- 179
					peri = i -- 179
				end -- 179
				if i > entry and d >= cfg.encounterRadius then -- 179
					exit = i -- 180
					break -- 180
				end -- 180
			end -- 180
			::__continue44:: -- 180
			i = i + 1 -- 175
		end -- 175
	end -- 175
	local drop = entry >= 0 and exit >= 0 and specificEnergy(flight, entry, center, t0 + entry * dt) - specificEnergy(flight, exit, center, t0 + exit * dt) or 0 -- 182
	local complete = entry > 0 and peri > entry and exit > peri and nearest >= math.max(moon.radius, cfg.minPeriapsis) and nearest <= cfg.maxPeriapsis and drop >= cfg.minEnergyDrop and exit or -1 -- 184
	local ____end = last -- 186
	if complete >= 0 then -- 186
		____end = math.min( -- 188
			last, -- 188
			complete + math.floor(cfg.maxViewingTime / dt) -- 188
		) -- 188
		do -- 188
			local i = complete + 1 -- 189
			while i <= ____end do -- 189
				local r = distance( -- 190
					flight.points[i + 1], -- 190
					bodyPositionAt(center, t0 + i * dt) -- 190
				) -- 190
				local prev = distance( -- 191
					flight.points[i], -- 191
					bodyPositionAt(center, t0 + (i - 1) * dt) -- 191
				) -- 191
				if prev > cfg.returnRadius and r <= cfg.returnRadius then -- 191
					____end = i -- 192
					break -- 192
				end -- 192
				i = i + 1 -- 189
			end -- 189
		end -- 189
	end -- 189
	return { -- 195
		entryIndex = entry, -- 195
		periapsisIndex = peri, -- 195
		exitIndex = exit, -- 195
		completionIndex = complete, -- 195
		viewEndIndex = ____end, -- 195
		periapsis = nearest, -- 195
		energyDrop = drop -- 195
	} -- 195
end -- 172
--- 完整会遇的日心能量变化与对应行星做功，两者共同验证借力。
function ____exports.analyzeOrbitalMission(flight, bodies, cfg, dt, t0) -- 76
	local stages = {} -- 77
	local last = #flight.points - 1 -- 78
	local after = -1 -- 79
	local ordered = true -- 80
	for ____, spec in ipairs(cfg.encounters) do -- 81
		local body = bodies[spec.planetIndex + 1] -- 82
		local entry = -1 -- 83
		local peri = -1 -- 83
		local exit = -1 -- 83
		local nearest = 1000000000 -- 83
		if body ~= nil then -- 83
			do -- 83
				local i = 0 -- 84
				while i <= last do -- 84
					do -- 84
						local d = distance( -- 85
							flight.points[i + 1], -- 85
							bodyPositionAt(body, t0 + i * dt) -- 85
						) -- 85
						if entry < 0 and d <= spec.encounterRadius then -- 85
							entry = i -- 86
						end -- 86
						if entry < 0 then -- 86
							goto __continue6 -- 87
						end -- 87
						if d < nearest then -- 87
							nearest = d -- 88
							peri = i -- 88
						end -- 88
						if i > entry and d >= spec.encounterRadius then -- 88
							exit = i -- 89
							break -- 89
						end -- 89
					end -- 89
					::__continue6:: -- 89
					i = i + 1 -- 84
				end -- 84
			end -- 84
		end -- 84
		local change = entry >= 0 and exit >= 0 and specificEnergy(flight, exit, bodies[1], t0 + exit * dt) - specificEnergy(flight, entry, bodies[1], t0 + entry * dt) or 0 -- 91
		local work = 0 -- 92
		if body ~= nil and entry >= 0 and exit >= 0 then -- 92
			do -- 92
				local i = entry -- 93
				while i < exit do -- 93
					local power = 0 -- 94
					do -- 94
						local k = i -- 95
						while k <= i + 1 do -- 95
							local bp = bodyPositionAt(body, t0 + k * dt) -- 96
							local p = flight.points[k + 1] -- 96
							local v = flight.velocities[k + 1] -- 96
							local x = bp.x - p.x -- 97
							local y = bp.y - p.y -- 97
							local r = math.sqrt(x * x + y * y) -- 97
							if r > 0 then -- 97
								power = power + body.gm * (v.x * x + v.y * y) / (r * r * r) -- 98
							end -- 98
							k = k + 1 -- 95
						end -- 95
					end -- 95
					work = work + power * dt / 2 -- 100
					i = i + 1 -- 93
				end -- 93
			end -- 93
		end -- 93
		local sign = spec.energyDirection == "gain" and 1 or -1 -- 102
		local passed = ordered and body ~= nil and entry > after and entry > 0 and peri > entry and exit > peri and nearest >= math.max(body.radius, spec.minPeriapsis) and nearest <= spec.maxPeriapsis and sign * change >= spec.minEnergyChange and sign * work >= spec.minWork -- 103
		stages[#stages + 1] = { -- 106
			planetIndex = spec.planetIndex, -- 106
			entryIndex = entry, -- 106
			periapsisIndex = peri, -- 106
			exitIndex = exit, -- 106
			periapsis = nearest, -- 106
			energyChange = change, -- 106
			work = work, -- 106
			passed = passed -- 106
		} -- 106
		ordered = passed -- 107
		after = exit -- 107
	end -- 107
	local destination = nil -- 109
	local target = cfg.targetFlyby -- 110
	if target ~= nil then -- 110
		local body = bodies[target.planetIndex + 1] -- 112
		local entry = -1 -- 113
		local peri = -1 -- 113
		local exit = -1 -- 113
		local nearest = 1000000000 -- 113
		if body ~= nil and after >= 0 then -- 113
			do -- 113
				local i = after + 1 -- 114
				while i <= last do -- 114
					do -- 114
						local d = distance( -- 115
							flight.points[i + 1], -- 115
							bodyPositionAt(body, t0 + i * dt) -- 115
						) -- 115
						local prev = distance( -- 116
							flight.points[i], -- 116
							bodyPositionAt(body, t0 + (i - 1) * dt) -- 116
						) -- 116
						if entry < 0 and prev > target.encounterRadius and d <= target.encounterRadius then -- 116
							entry = i -- 117
						end -- 117
						if entry < 0 then -- 117
							goto __continue21 -- 118
						end -- 118
						if d < nearest then -- 118
							nearest = d -- 119
							peri = i -- 119
						end -- 119
						if i > entry and d >= target.encounterRadius then -- 119
							exit = i -- 120
							break -- 120
						end -- 120
					end -- 120
					::__continue21:: -- 120
					i = i + 1 -- 114
				end -- 114
			end -- 114
		end -- 114
		local passed = ordered and body ~= nil and entry > after and peri > entry and exit > peri and nearest >= math.max(body.radius, target.minPeriapsis) and nearest <= target.maxPeriapsis -- 122
		destination = { -- 124
			planetIndex = target.planetIndex, -- 124
			entryIndex = entry, -- 124
			periapsisIndex = peri, -- 124
			exitIndex = exit, -- 124
			periapsis = nearest, -- 124
			energyChange = 0, -- 124
			work = 0, -- 124
			passed = passed -- 124
		} -- 124
	end -- 124
	local complete = destination ~= nil and destination.passed and destination.exitIndex or -1 -- 126
	if cfg.region ~= nil and ordered and #stages > 0 then -- 126
		do -- 126
			local i = math.max(1, after + 1) -- 127
			while i <= last do -- 127
				local r = distance( -- 128
					flight.points[i + 1], -- 128
					bodyPositionAt(bodies[1], t0 + i * dt) -- 128
				) -- 128
				local prev = distance( -- 129
					flight.points[i], -- 129
					bodyPositionAt(bodies[1], t0 + (i - 1) * dt) -- 129
				) -- 129
				local rg = cfg.region -- 130
				local ____temp_1 = r >= rg.minRadius and r <= rg.maxRadius -- 131
				if ____temp_1 then -- 131
					local ____temp_0 -- 131
					if rg.direction == "inward" then -- 131
						____temp_0 = prev > rg.maxRadius and r < prev -- 131
					else -- 131
						____temp_0 = prev < rg.minRadius and r > prev -- 131
					end -- 131
					____temp_1 = ____temp_0 -- 131
				end -- 131
				if ____temp_1 then -- 131
					complete = i -- 131
					break -- 131
				end -- 131
				i = i + 1 -- 127
			end -- 127
		end -- 127
	end -- 127
	local first = #stages > 0 and stages[1] or nil -- 133
	return { -- 134
		encounters = stages, -- 134
		destination = destination, -- 134
		entryIndex = first ~= nil and first.entryIndex or -1, -- 134
		periapsisIndex = first ~= nil and first.periapsisIndex or -1, -- 134
		exitIndex = first ~= nil and first.exitIndex or -1, -- 135
		periapsis = first ~= nil and first.periapsis or 1000000000, -- 135
		energyDrop = first ~= nil and -first.energyChange or 0, -- 135
		completionIndex = complete, -- 136
		viewEndIndex = complete >= 0 and math.min( -- 136
			last, -- 136
			complete + math.floor(cfg.maxViewingTime / dt) -- 136
		) or last -- 136
	} -- 136
end -- 76
function ____exports.analyzeTransfer(flight, bodies, targetIndex, tr, dt, t0) -- 139
	if tr.orbital ~= nil then -- 139
		return ____exports.analyzeOrbitalMission( -- 140
			flight, -- 140
			bodies, -- 140
			tr.orbital, -- 140
			dt, -- 140
			t0 -- 140
		) -- 140
	end -- 140
	return tr.flyby ~= nil and ____exports.analyzeFlyby( -- 141
		flight, -- 141
		bodies[1], -- 141
		bodies[targetIndex + 1], -- 141
		tr.flyby, -- 141
		dt, -- 141
		t0 -- 141
	) or nil -- 141
end -- 139
function ____exports.transferCinematic(tr) -- 144
	return tr ~= nil and (tr.flyby ~= nil or tr.orbital ~= nil) -- 145
end -- 144
local function slowTimes(tr, analysis, dt) -- 148
	local out = {} -- 149
	if analysis == nil then -- 149
		return out -- 150
	end -- 150
	local cfg = tr.orbital ~= nil and tr.orbital or tr.flyby -- 151
	if cfg == nil then -- 151
		return out -- 152
	end -- 152
	local indices = analysis.encounters ~= nil and __TS__ArrayMap( -- 153
		analysis.encounters, -- 153
		function(____, e) return e.periapsisIndex end -- 153
	) or ({analysis.periapsisIndex}) -- 153
	if analysis.destination ~= nil then -- 153
		indices[#indices + 1] = analysis.destination.periapsisIndex -- 154
	end -- 154
	for ____, i in ipairs(indices) do -- 155
		if i >= 0 then -- 155
			__TS__ArrayPush(out, i * dt - cfg.slowWindow, i * dt + cfg.slowWindow) -- 155
		end -- 155
	end -- 155
	return out -- 156
end -- 148
function ____exports.transferPlaybackRate(time, burn, tr, analysis, dt) -- 198
	if time < burn then -- 198
		return 1 -- 199
	end -- 199
	local times = slowTimes(tr, analysis, dt) -- 200
	do -- 200
		local i = 0 -- 201
		while i < #times do -- 201
			if time >= times[i + 1] and time < times[i + 1 + 1] then -- 201
				return 1 -- 201
			end -- 201
			i = i + 2 -- 201
		end -- 201
	end -- 201
	return tr.coastPlayback -- 202
end -- 198
--- 跨倍率边界分段推进，30/60/120 FPS 下点火和近月观赏段的时长相同。
function ____exports.advanceTransferPlayback(time, wallDt, baseRate, burn, tr, analysis, dt) -- 206
	if baseRate <= 0 or wallDt <= 0 then -- 206
		return time -- 207
	end -- 207
	local remaining = wallDt -- 208
	local boundaries = { -- 209
		burn, -- 209
		table.unpack(slowTimes(tr, analysis, dt)) -- 209
	} -- 209
	do -- 209
		local n = 0 -- 210
		while n <= #boundaries and remaining > 1e-10 do -- 210
			local rate = baseRate * ____exports.transferPlaybackRate( -- 211
				time, -- 211
				burn, -- 211
				tr, -- 211
				analysis, -- 211
				dt -- 211
			) -- 211
			local next = 1000000000 -- 212
			do -- 212
				local i = 0 -- 213
				while i < #boundaries do -- 213
					if boundaries[i + 1] > time + 1e-10 and boundaries[i + 1] < next then -- 213
						next = boundaries[i + 1] -- 213
					end -- 213
					i = i + 1 -- 213
				end -- 213
			end -- 213
			local ____until = (next - time) / rate -- 214
			if ____until >= remaining then -- 214
				return time + remaining * rate -- 215
			end -- 215
			time = next -- 216
			remaining = remaining - ____until -- 217
			n = n + 1 -- 210
		end -- 210
	end -- 210
	return time -- 219
end -- 206
function ____exports.nextCameraFocus(mode, modes) -- 225
	if modes ~= nil then -- 225
		local i = __TS__ArrayIndexOf(modes, mode) -- 227
		return modes[(i + 1) % #modes + 1] -- 228
	end -- 228
	if mode == "Auto" then -- 228
		return "Probe" -- 230
	end -- 230
	if mode == "Probe" then -- 230
		return "Moon" -- 231
	end -- 231
	if mode == "Moon" then -- 231
		return "Earth" -- 232
	end -- 232
	if mode == "Earth" then -- 232
		return "Overview" -- 233
	end -- 233
	return "Auto" -- 234
end -- 225
function ____exports.transferShotAt(time, burn, analysis, cfg, dt) -- 237
	if time <= burn + 1.2 then -- 237
		return "Launch" -- 238
	end -- 238
	if analysis ~= nil and analysis.entryIndex >= 0 and time >= analysis.entryIndex * dt then -- 238
		if analysis.completionIndex >= 0 and time >= analysis.completionIndex * dt then -- 238
			return time < analysis.completionIndex * dt + cfg.overviewDuration and "Overview" or "Earth" -- 241
		end -- 241
		if analysis.exitIndex < 0 or time <= analysis.exitIndex * dt then -- 241
			return "Moon" -- 243
		end -- 243
	end -- 243
	return "Cruise" -- 245
end -- 237
--- 拖动长度只改变远地点；方向由出发圆轨的顺行切线确定。
function ____exports.planTransfer(mu, radius, vel, power, maxRadius, mode, minRadius) -- 255
	local p = math.max( -- 256
		0, -- 256
		math.min(1, power) -- 256
	) -- 256
	local ra = mode == "lowerPeriapsis" and radius + (math.max( -- 257
		1, -- 257
		math.min(radius, minRadius ~= nil and minRadius or radius) -- 257
	) - radius) * p or radius + (math.max(radius, maxRadius) - radius) * p -- 257
	local a = (radius + ra) / 2 -- 258
	local dv = mu > 0 and radius > 0 and math.sqrt(mu * (2 / radius - 1 / a)) - math.sqrt(mu / radius) or 0 -- 259
	local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y) -- 260
	return { -- 261
		apoapsis = ra, -- 261
		dv = math.abs(dv), -- 261
		velocity = {x = speed > 0 and vel.x * dv / speed or 0, y = speed > 0 and vel.y * dv / speed or 0} -- 261
	} -- 261
end -- 255
function ____exports.orbitalShotAt(time, burn, analysis, cfg, dt) -- 264
	if time <= burn + 1.2 then -- 264
		return "Launch" -- 265
	end -- 265
	if analysis ~= nil and analysis.encounters ~= nil then -- 265
		do -- 265
			local i = 0 -- 266
			while i < #analysis.encounters do -- 266
				local e = analysis.encounters[i + 1] -- 267
				if e.entryIndex >= 0 and time >= e.entryIndex * dt and (e.exitIndex < 0 or time <= e.exitIndex * dt) then -- 267
					return cfg.encounters[i + 1].focus -- 268
				end -- 268
				i = i + 1 -- 266
			end -- 266
		end -- 266
	end -- 266
	if cfg.targetFlyby ~= nil then -- 266
		local ____temp_2 -- 271
		if analysis ~= nil then -- 271
			____temp_2 = analysis.destination -- 271
		else -- 271
			____temp_2 = nil -- 271
		end -- 271
		local e = ____temp_2 -- 271
		if e ~= nil and e.entryIndex >= 0 and time >= e.entryIndex * dt and (e.exitIndex < 0 or time <= e.exitIndex * dt) then -- 271
			return cfg.targetFlyby.focus -- 272
		end -- 272
		return e ~= nil and e.passed and time > e.exitIndex * dt and "Overview" or "Cruise" -- 273
	end -- 273
	return analysis ~= nil and analysis.exitIndex >= 0 and analysis.encounters ~= nil and __TS__ArrayEvery( -- 275
		analysis.encounters, -- 275
		function(____, e) return e.passed and time > e.exitIndex * dt end -- 275
	) and "Overview" or "Cruise" -- 275
end -- 264
--- 独立显示时间；调用方每帧累加 wallDt，暂停与物理倍率不参与。
function ____exports.successMarkerFrame(elapsed) -- 279
	if elapsed < 0 then -- 279
		return {visible = true, alpha = 1, scale = 1, ring = 0} -- 280
	end -- 280
	if elapsed >= 0.6 then -- 280
		return {visible = false, alpha = 0, scale = 1, ring = 0} -- 281
	end -- 281
	local u = math.max(0, (elapsed - 0.12) / 0.48) -- 282
	return {visible = true, alpha = 1 - u, scale = elapsed < 0.12 and 1 + elapsed / 0.12 or 2 - u, ring = elapsed < 0.12 and 0 or 8 + 30 * u} -- 283
end -- 279
return ____exports -- 279