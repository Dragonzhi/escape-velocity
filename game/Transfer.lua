-- [ts]: Transfer.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArrayPush = ____lualib.__TS__ArrayPush -- 1
local ____exports = {} -- 1
local ____Gravity = require("game.Gravity") -- 2
local bodyPositionAt = ____Gravity.bodyPositionAt -- 2
local distance = ____Gravity.distance -- 2
--- 地心比能；使用相对中心天体的速度，避免混入参考系的平移。
local function specificEnergy(flight, index, center, t) -- 37
	local pos = bodyPositionAt(center, t) -- 38
	local before = bodyPositionAt(center, t - 0.001) -- 40
	local after = bodyPositionAt(center, t + 0.001) -- 41
	local vx = flight.velocities[index + 1].x - (after.x - before.x) / 0.002 -- 42
	local vy = flight.velocities[index + 1].y - (after.y - before.y) / 0.002 -- 43
	local r = distance(flight.points[index + 1], pos) -- 44
	return r > 0 and (vx * vx + vy * vy) / 2 - center.gm / r or -1000000000 -- 45
end -- 37
--- 只分析首次会遇；光点无关，必须安全走完进入→近月点→离开。
function ____exports.analyzeFlyby(flight, center, moon, cfg, dt, t0) -- 49
	local entry = -1 -- 50
	local peri = -1 -- 50
	local exit = -1 -- 50
	local nearest = 1000000000 -- 50
	local last = #flight.points - 1 -- 51
	do -- 51
		local i = 0 -- 52
		while i <= last do -- 52
			do -- 52
				local d = distance( -- 53
					flight.points[i + 1], -- 53
					bodyPositionAt(moon, t0 + i * dt) -- 53
				) -- 53
				if entry < 0 and d <= cfg.encounterRadius then -- 53
					entry = i -- 54
				end -- 54
				if entry < 0 then -- 54
					goto __continue5 -- 55
				end -- 55
				if d < nearest then -- 55
					nearest = d -- 56
					peri = i -- 56
				end -- 56
				if i > entry and d >= cfg.encounterRadius then -- 56
					exit = i -- 57
					break -- 57
				end -- 57
			end -- 57
			::__continue5:: -- 57
			i = i + 1 -- 52
		end -- 52
	end -- 52
	local drop = entry >= 0 and exit >= 0 and specificEnergy(flight, entry, center, t0 + entry * dt) - specificEnergy(flight, exit, center, t0 + exit * dt) or 0 -- 59
	local complete = entry > 0 and peri > entry and exit > peri and nearest >= math.max(moon.radius, cfg.minPeriapsis) and nearest <= cfg.maxPeriapsis and drop >= cfg.minEnergyDrop and exit or -1 -- 61
	local ____end = last -- 63
	if complete >= 0 then -- 63
		____end = math.min( -- 65
			last, -- 65
			complete + math.floor(cfg.maxViewingTime / dt) -- 65
		) -- 65
		do -- 65
			local i = complete + 1 -- 66
			while i <= ____end do -- 66
				local r = distance( -- 67
					flight.points[i + 1], -- 67
					bodyPositionAt(center, t0 + i * dt) -- 67
				) -- 67
				local prev = distance( -- 68
					flight.points[i], -- 68
					bodyPositionAt(center, t0 + (i - 1) * dt) -- 68
				) -- 68
				if prev > cfg.returnRadius and r <= cfg.returnRadius then -- 68
					____end = i -- 69
					break -- 69
				end -- 69
				i = i + 1 -- 66
			end -- 66
		end -- 66
	end -- 66
	return { -- 72
		entryIndex = entry, -- 72
		periapsisIndex = peri, -- 72
		exitIndex = exit, -- 72
		completionIndex = complete, -- 72
		viewEndIndex = ____end, -- 72
		periapsis = nearest, -- 72
		energyDrop = drop -- 72
	} -- 72
end -- 49
function ____exports.transferPlaybackRate(time, burn, tr, analysis, dt) -- 75
	if time < burn then -- 75
		return 1 -- 76
	end -- 76
	if tr.flyby ~= nil and analysis ~= nil and analysis.periapsisIndex >= 0 then -- 76
		local periTime = analysis.periapsisIndex * dt -- 78
		if time >= periTime - tr.flyby.slowWindow and time < periTime + tr.flyby.slowWindow then -- 78
			return 1 -- 79
		end -- 79
	end -- 79
	return tr.coastPlayback -- 81
end -- 75
--- 跨倍率边界分段推进，30/60/120 FPS 下点火和近月观赏段的时长相同。
function ____exports.advanceTransferPlayback(time, wallDt, baseRate, burn, tr, analysis, dt) -- 85
	if baseRate <= 0 or wallDt <= 0 then -- 85
		return time -- 86
	end -- 86
	local remaining = wallDt -- 87
	local boundaries = {burn} -- 88
	if tr.flyby ~= nil and analysis ~= nil and analysis.periapsisIndex >= 0 then -- 88
		local periTime = analysis.periapsisIndex * dt -- 90
		__TS__ArrayPush(boundaries, periTime - tr.flyby.slowWindow, periTime + tr.flyby.slowWindow) -- 91
	end -- 91
	do -- 91
		local n = 0 -- 93
		while n < 4 and remaining > 1e-10 do -- 93
			local rate = baseRate * ____exports.transferPlaybackRate( -- 94
				time, -- 94
				burn, -- 94
				tr, -- 94
				analysis, -- 94
				dt -- 94
			) -- 94
			local next = 1000000000 -- 95
			do -- 95
				local i = 0 -- 96
				while i < #boundaries do -- 96
					if boundaries[i + 1] > time + 1e-10 and boundaries[i + 1] < next then -- 96
						next = boundaries[i + 1] -- 96
					end -- 96
					i = i + 1 -- 96
				end -- 96
			end -- 96
			local ____until = (next - time) / rate -- 97
			if ____until >= remaining then -- 97
				return time + remaining * rate -- 98
			end -- 98
			time = next -- 99
			remaining = remaining - ____until -- 100
			n = n + 1 -- 93
		end -- 93
	end -- 93
	return time -- 102
end -- 85
function ____exports.nextCameraFocus(mode) -- 108
	if mode == "Auto" then -- 108
		return "Probe" -- 109
	end -- 109
	if mode == "Probe" then -- 109
		return "Moon" -- 110
	end -- 110
	if mode == "Moon" then -- 110
		return "Earth" -- 111
	end -- 111
	if mode == "Earth" then -- 111
		return "Overview" -- 112
	end -- 112
	return "Auto" -- 113
end -- 108
function ____exports.transferShotAt(time, burn, analysis, cfg, dt) -- 116
	if time <= burn + 1.2 then -- 116
		return "Launch" -- 117
	end -- 117
	if analysis ~= nil and analysis.entryIndex >= 0 and time >= analysis.entryIndex * dt then -- 117
		if analysis.completionIndex >= 0 and time >= analysis.completionIndex * dt then -- 117
			return time < analysis.completionIndex * dt + cfg.overviewDuration and "Overview" or "Earth" -- 120
		end -- 120
		if analysis.exitIndex < 0 or time <= analysis.exitIndex * dt then -- 120
			return "Moon" -- 122
		end -- 122
	end -- 122
	return "Cruise" -- 124
end -- 116
--- 拖动长度只改变远地点；方向由出发圆轨的顺行切线确定。
function ____exports.planTransfer(mu, radius, vel, power, maxRadius) -- 134
	local p = math.max( -- 135
		0, -- 135
		math.min(1, power) -- 135
	) -- 135
	local ra = radius + (math.max(radius, maxRadius) - radius) * p -- 136
	local a = (radius + ra) / 2 -- 137
	local dv = mu > 0 and radius > 0 and math.sqrt(mu * (2 / radius - 1 / a)) - math.sqrt(mu / radius) or 0 -- 138
	local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y) -- 139
	return {apoapsis = ra, dv = dv, velocity = {x = speed > 0 and vel.x * dv / speed or 0, y = speed > 0 and vel.y * dv / speed or 0}} -- 140
end -- 134
return ____exports -- 134