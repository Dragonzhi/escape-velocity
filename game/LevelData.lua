-- [ts]: LevelData.ts
local ____exports = {} -- 1
local applyScalesLocal -- 1
local ____Gravity = require("game.Gravity") -- 25
local bodyPositionAt = ____Gravity.bodyPositionAt -- 25
local distance = ____Gravity.distance -- 25
local ____Config = require("game.Config") -- 26
local GravityScale = ____Config.GravityScale -- 26
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 26
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 212
	local out = {} -- 213
	for ____, b in ipairs(bodies) do -- 214
		out[#out + 1] = { -- 215
			gm = b.gm * gravityScale, -- 216
			radius = b.radius, -- 217
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 218
			orbitRadius = b.orbitRadius, -- 219
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 220
			phase0 = b.phase0, -- 221
			orbitDirection = b.orbitDirection -- 222
		} -- 222
	end -- 222
	return out -- 225
end -- 225
--- 在飞行采样点中找第一个进入目标容差的索引。
-- 
-- 目标行星在移动，所以逐点用 `t = i * dt` 时的行星位置判定。
-- 返回 -1 表示未到达。
function ____exports.findGoalIndex(points, bodies, goal, dt) -- 67
	if goal.kind ~= "planet" then -- 67
		return -1 -- 68
	end -- 68
	local body = bodies[goal.planetIndex + 1] -- 69
	if body == nil then -- 69
		return -1 -- 70
	end -- 70
	do -- 70
		local i = 0 -- 71
		while i < #points do -- 71
			local gp = bodyPositionAt(body, i * dt) -- 72
			if distance(points[i + 1], gp) < goal.tolerance then -- 72
				return i -- 73
			end -- 73
			i = i + 1 -- 71
		end -- 71
	end -- 71
	return -1 -- 75
end -- 67
local LEVELS = { -- 82
	{ -- 83
		id = 1, -- 84
		title = "直飞", -- 85
		brief = "1977 年，旅行者号启程。先学会瞄准：拖动，看线，松手。", -- 86
		probeStart = {x = 0, y = 16}, -- 87
		planets = {{ -- 88
			gm = 0, -- 90
			radius = 1.2, -- 90
			orbitCenter = {x = 0, y = -30}, -- 90
			orbitRadius = 0, -- 90
			orbitPeriod = 0, -- 90
			phase0 = 0, -- 90
			orbitDirection = 1 -- 90
		}}, -- 90
		visuals = {{ -- 92
			r = 0.8, -- 93
			g = 0.45, -- 93
			b = 0.3, -- 93
			displayRadius = 1.2, -- 93
			ring = false -- 93
		}}, -- 93
		goal = {kind = "planet", planetIndex = 0, tolerance = 3}, -- 95
		escapeRadius = 400, -- 96
		maxSteps = 1500 -- 97
	}, -- 97
	{ -- 99
		id = 2, -- 100
		title = "第一次弯曲", -- 101
		brief = "金唱片已上路。注意：引力会掰弯你的航线。", -- 102
		probeStart = {x = 0, y = 16}, -- 103
		planets = {{ -- 104
			gm = 700, -- 106
			radius = 1.8, -- 106
			orbitCenter = {x = 7, y = -4}, -- 106
			orbitRadius = 0, -- 106
			orbitPeriod = 0, -- 106
			phase0 = 0, -- 106
			orbitDirection = 1 -- 106
		}, { -- 106
			gm = 0, -- 108
			radius = 1.2, -- 108
			orbitCenter = {x = -2, y = -32}, -- 108
			orbitRadius = 0, -- 108
			orbitPeriod = 0, -- 108
			phase0 = 0, -- 108
			orbitDirection = 1 -- 108
		}}, -- 108
		visuals = {{ -- 110
			r = 0.9, -- 111
			g = 0.78, -- 111
			b = 0.55, -- 111
			displayRadius = 1.8, -- 111
			ring = false -- 111
		}, { -- 111
			r = 0.8, -- 112
			g = 0.45, -- 112
			b = 0.3, -- 112
			displayRadius = 1.2, -- 112
			ring = false -- 112
		}}, -- 112
		goal = {kind = "planet", planetIndex = 1, tolerance = 3}, -- 114
		escapeRadius = 400, -- 115
		maxSteps = 1500 -- 116
	}, -- 116
	{ -- 118
		id = 3, -- 119
		title = "从背后抄过去", -- 120
		brief = "燃料只够一次发射。借木星的引力，从背后抄过去。", -- 121
		probeStart = {x = 0, y = 18}, -- 122
		planets = {{ -- 123
			gm = 1500, -- 125
			radius = 2.6, -- 125
			orbitCenter = {x = 0, y = -2}, -- 125
			orbitRadius = 0, -- 125
			orbitPeriod = 0, -- 125
			phase0 = 0, -- 125
			orbitDirection = 1 -- 125
		}, { -- 125
			gm = 0, -- 127
			radius = 1.4, -- 127
			orbitCenter = {x = -26, y = -26}, -- 127
			orbitRadius = 0, -- 127
			orbitPeriod = 0, -- 127
			phase0 = 0, -- 127
			orbitDirection = 1 -- 127
		}}, -- 127
		visuals = {{ -- 129
			r = 0.85, -- 130
			g = 0.72, -- 130
			b = 0.5, -- 130
			displayRadius = 2.6, -- 130
			ring = false -- 130
		}, { -- 130
			r = 0.75, -- 131
			g = 0.7, -- 131
			b = 0.6, -- 131
			displayRadius = 1.4, -- 131
			ring = true -- 131
		}}, -- 131
		goal = {kind = "planet", planetIndex = 1, tolerance = 3}, -- 133
		escapeRadius = 400, -- 134
		maxSteps = 1800 -- 135
	}, -- 135
	{ -- 137
		id = 4, -- 138
		title = "它动了", -- 139
		brief = "行星不会等你。算好它到位的时机。", -- 140
		probeStart = {x = 0, y = 16}, -- 141
		planets = {{ -- 142
			gm = 500, -- 144
			radius = 1.6, -- 144
			orbitCenter = {x = 0, y = -6}, -- 144
			orbitRadius = 9, -- 144
			orbitPeriod = 9, -- 144
			phase0 = 0, -- 144
			orbitDirection = 1 -- 144
		}}, -- 144
		visuals = {{ -- 146
			r = 0.8, -- 147
			g = 0.45, -- 147
			b = 0.3, -- 147
			displayRadius = 1.6, -- 147
			ring = false -- 147
		}}, -- 147
		goal = {kind = "planet", planetIndex = 0, tolerance = 3.2}, -- 149
		escapeRadius = 400, -- 150
		maxSteps = 1800 -- 151
	}, -- 151
	{ -- 153
		id = 5, -- 154
		title = "两连弹", -- 155
		brief = "两颗巨行星排成一线。规划两次弹弓。", -- 156
		probeStart = {x = 0, y = 18}, -- 157
		planets = {{ -- 158
			gm = 1400, -- 160
			radius = 2.4, -- 160
			orbitCenter = {x = 5, y = -2}, -- 160
			orbitRadius = 0, -- 160
			orbitPeriod = 0, -- 160
			phase0 = 0, -- 160
			orbitDirection = 1 -- 160
		}, { -- 160
			gm = 1000, -- 162
			radius = 2.2, -- 162
			orbitCenter = {x = -7, y = -18}, -- 162
			orbitRadius = 0, -- 162
			orbitPeriod = 0, -- 162
			phase0 = 0, -- 162
			orbitDirection = 1 -- 162
		}, { -- 162
			gm = 0, -- 164
			radius = 1.3, -- 164
			orbitCenter = {x = -20, y = -34}, -- 164
			orbitRadius = 0, -- 164
			orbitPeriod = 0, -- 164
			phase0 = 0, -- 164
			orbitDirection = 1 -- 164
		}}, -- 164
		visuals = {{ -- 166
			r = 0.85, -- 167
			g = 0.72, -- 167
			b = 0.5, -- 167
			displayRadius = 2.4, -- 167
			ring = false -- 167
		}, { -- 167
			r = 0.75, -- 168
			g = 0.7, -- 168
			b = 0.6, -- 168
			displayRadius = 2.2, -- 168
			ring = true -- 168
		}, { -- 168
			r = 0.55, -- 169
			g = 0.75, -- 169
			b = 0.8, -- 169
			displayRadius = 1.3, -- 169
			ring = false -- 169
		}}, -- 169
		goal = {kind = "planet", planetIndex = 2, tolerance = 3}, -- 171
		escapeRadius = 400, -- 172
		maxSteps = 1800 -- 173
	}, -- 173
	{ -- 175
		id = 6, -- 176
		title = "贴着过去", -- 177
		brief = "最后一次机会。贴着土星环过去，别碰它。", -- 178
		probeStart = {x = 0, y = 16}, -- 179
		planets = {{ -- 180
			gm = 1100, -- 182
			radius = 1.6, -- 182
			orbitCenter = {x = 4, y = -6}, -- 182
			orbitRadius = 0, -- 182
			orbitPeriod = 0, -- 182
			phase0 = 0, -- 182
			orbitDirection = 1 -- 182
		}}, -- 182
		visuals = {{ -- 184
			r = 0.75, -- 185
			g = 0.7, -- 185
			b = 0.6, -- 185
			displayRadius = 1.6, -- 185
			ring = true -- 185
		}}, -- 185
		goal = {kind = "planet", planetIndex = 0, tolerance = 2.2}, -- 187
		escapeRadius = 400, -- 188
		maxSteps = 1800 -- 189
	} -- 189
} -- 189
--- 关卡总数。
function ____exports.levelCount() -- 194
	return #LEVELS -- 195
end -- 194
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 199
	return LEVELS[index + 1] -- 200
end -- 199
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。
-- 不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 207
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 208
end -- 207
return ____exports -- 207