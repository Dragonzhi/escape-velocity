-- [ts]: LevelData.ts
local ____exports = {} -- 1
local applyScalesLocal -- 1
local ____Gravity = require("game.Gravity") -- 25
local bodyPositionAt = ____Gravity.bodyPositionAt -- 25
local distance = ____Gravity.distance -- 25
local ____Config = require("game.Config") -- 26
local GravityScale = ____Config.GravityScale -- 26
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 26
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 218
	local out = {} -- 219
	for ____, b in ipairs(bodies) do -- 220
		out[#out + 1] = { -- 221
			gm = b.gm * gravityScale, -- 222
			radius = b.radius, -- 223
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 224
			orbitRadius = b.orbitRadius, -- 225
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 226
			phase0 = b.phase0, -- 227
			orbitDirection = b.orbitDirection -- 228
		} -- 228
	end -- 228
	return out -- 231
end -- 231
--- 在飞行采样点中找第一个进入目标容差的索引。
-- 
-- 目标行星在移动，所以逐点用 `t = i * dt` 时的行星位置判定。
-- 返回 -1 表示未到达。
function ____exports.findGoalIndex(points, bodies, goal, dt) -- 72
	if goal.kind ~= "planet" then -- 72
		return -1 -- 73
	end -- 73
	local body = bodies[goal.planetIndex + 1] -- 74
	if body == nil then -- 74
		return -1 -- 75
	end -- 75
	do -- 75
		local i = 0 -- 76
		while i < #points do -- 76
			local gp = bodyPositionAt(body, i * dt) -- 77
			if distance(points[i + 1], gp) < goal.tolerance then -- 77
				return i -- 78
			end -- 78
			i = i + 1 -- 76
		end -- 76
	end -- 76
	return -1 -- 80
end -- 72
local LEVELS = { -- 87
	{ -- 88
		id = 1, -- 89
		title = "直飞", -- 90
		brief = "1977 年，旅行者号启程。先学会瞄准：拖动，看线，松手。", -- 91
		probeStart = {x = 0, y = 16}, -- 92
		planets = {{ -- 93
			gm = 0, -- 95
			radius = 1.2, -- 95
			orbitCenter = {x = 0, y = -30}, -- 95
			orbitRadius = 0, -- 95
			orbitPeriod = 0, -- 95
			phase0 = 0, -- 95
			orbitDirection = 1 -- 95
		}}, -- 95
		visuals = {{ -- 97
			r = 0.8, -- 98
			g = 0.45, -- 98
			b = 0.3, -- 98
			displayRadius = 1.2, -- 98
			ring = false, -- 98
			model = "Planet_Mars" -- 98
		}}, -- 98
		goal = {kind = "planet", planetIndex = 0, tolerance = 3}, -- 100
		escapeRadius = 400, -- 101
		maxSteps = 1500 -- 102
	}, -- 102
	{ -- 104
		id = 2, -- 105
		title = "第一次弯曲", -- 106
		brief = "金唱片已上路。注意：引力会掰弯你的航线。", -- 107
		probeStart = {x = 0, y = 16}, -- 108
		planets = {{ -- 109
			gm = 700, -- 111
			radius = 1.8, -- 111
			orbitCenter = {x = 7, y = -4}, -- 111
			orbitRadius = 0, -- 111
			orbitPeriod = 0, -- 111
			phase0 = 0, -- 111
			orbitDirection = 1 -- 111
		}, { -- 111
			gm = 0, -- 113
			radius = 1.2, -- 113
			orbitCenter = {x = -2, y = -32}, -- 113
			orbitRadius = 0, -- 113
			orbitPeriod = 0, -- 113
			phase0 = 0, -- 113
			orbitDirection = 1 -- 113
		}}, -- 113
		visuals = {{ -- 115
			r = 0.9, -- 116
			g = 0.78, -- 116
			b = 0.55, -- 116
			displayRadius = 1.8, -- 116
			ring = false, -- 116
			model = "Planet_Venus" -- 116
		}, { -- 116
			r = 0.8, -- 117
			g = 0.45, -- 117
			b = 0.3, -- 117
			displayRadius = 1.2, -- 117
			ring = false, -- 117
			model = "Planet_Mars" -- 117
		}}, -- 117
		goal = {kind = "planet", planetIndex = 1, tolerance = 3}, -- 119
		escapeRadius = 400, -- 120
		maxSteps = 1500 -- 121
	}, -- 121
	{ -- 123
		id = 3, -- 124
		title = "从背后抄过去", -- 125
		brief = "燃料只够一次发射。借木星的引力，从背后抄过去。", -- 126
		probeStart = {x = 0, y = 18}, -- 127
		planets = {{ -- 128
			gm = 1500, -- 130
			radius = 2.6, -- 130
			orbitCenter = {x = 0, y = -2}, -- 130
			orbitRadius = 0, -- 130
			orbitPeriod = 0, -- 130
			phase0 = 0, -- 130
			orbitDirection = 1 -- 130
		}, { -- 130
			gm = 0, -- 132
			radius = 1.4, -- 132
			orbitCenter = {x = -26, y = -26}, -- 132
			orbitRadius = 0, -- 132
			orbitPeriod = 0, -- 132
			phase0 = 0, -- 132
			orbitDirection = 1 -- 132
		}}, -- 132
		visuals = {{ -- 134
			r = 0.85, -- 135
			g = 0.72, -- 135
			b = 0.5, -- 135
			displayRadius = 2.6, -- 135
			ring = false, -- 135
			model = "Planet_Jupiter" -- 135
		}, { -- 135
			r = 0.75, -- 136
			g = 0.7, -- 136
			b = 0.6, -- 136
			displayRadius = 1.4, -- 136
			ring = true, -- 136
			model = "Planet_Saturn" -- 136
		}}, -- 136
		goal = {kind = "planet", planetIndex = 1, tolerance = 3}, -- 138
		escapeRadius = 400, -- 139
		maxSteps = 1800 -- 140
	}, -- 140
	{ -- 142
		id = 4, -- 143
		title = "它动了", -- 144
		brief = "行星不会等你。算好它到位的时机。", -- 145
		probeStart = {x = 0, y = 16}, -- 146
		planets = {{ -- 147
			gm = 500, -- 149
			radius = 1.6, -- 149
			orbitCenter = {x = 0, y = -6}, -- 149
			orbitRadius = 9, -- 149
			orbitPeriod = 9, -- 149
			phase0 = 0, -- 149
			orbitDirection = 1 -- 149
		}}, -- 149
		visuals = {{ -- 151
			r = 0.8, -- 152
			g = 0.45, -- 152
			b = 0.3, -- 152
			displayRadius = 1.6, -- 152
			ring = false, -- 152
			model = "Planet_Mars" -- 152
		}}, -- 152
		goal = {kind = "planet", planetIndex = 0, tolerance = 3.2}, -- 154
		escapeRadius = 400, -- 155
		maxSteps = 1800 -- 156
	}, -- 156
	{ -- 158
		id = 5, -- 159
		title = "两连弹", -- 160
		brief = "两颗巨行星排成一线。规划两次弹弓。", -- 161
		probeStart = {x = 0, y = 18}, -- 162
		planets = {{ -- 163
			gm = 1400, -- 165
			radius = 2.4, -- 165
			orbitCenter = {x = 5, y = -2}, -- 165
			orbitRadius = 0, -- 165
			orbitPeriod = 0, -- 165
			phase0 = 0, -- 165
			orbitDirection = 1 -- 165
		}, { -- 165
			gm = 1000, -- 167
			radius = 2.2, -- 167
			orbitCenter = {x = -7, y = -18}, -- 167
			orbitRadius = 0, -- 167
			orbitPeriod = 0, -- 167
			phase0 = 0, -- 167
			orbitDirection = 1 -- 167
		}, { -- 167
			gm = 0, -- 169
			radius = 1.3, -- 169
			orbitCenter = {x = -20, y = -34}, -- 169
			orbitRadius = 0, -- 169
			orbitPeriod = 0, -- 169
			phase0 = 0, -- 169
			orbitDirection = 1 -- 169
		}}, -- 169
		visuals = {{ -- 171
			r = 0.85, -- 172
			g = 0.72, -- 172
			b = 0.5, -- 172
			displayRadius = 2.4, -- 172
			ring = false, -- 172
			model = "Planet_Jupiter" -- 172
		}, { -- 172
			r = 0.75, -- 173
			g = 0.7, -- 173
			b = 0.6, -- 173
			displayRadius = 2.2, -- 173
			ring = true, -- 173
			model = "Planet_Saturn" -- 173
		}, { -- 173
			r = 0.55, -- 175
			g = 0.75, -- 175
			b = 0.8, -- 175
			displayRadius = 1.3, -- 175
			ring = false, -- 175
			model = "Planet_Neptune" -- 175
		}}, -- 175
		goal = {kind = "planet", planetIndex = 2, tolerance = 3}, -- 177
		escapeRadius = 400, -- 178
		maxSteps = 1800 -- 179
	}, -- 179
	{ -- 181
		id = 6, -- 182
		title = "贴着过去", -- 183
		brief = "最后一次机会。贴着土星环过去，别碰它。", -- 184
		probeStart = {x = 0, y = 16}, -- 185
		planets = {{ -- 186
			gm = 1100, -- 188
			radius = 1.6, -- 188
			orbitCenter = {x = 4, y = -6}, -- 188
			orbitRadius = 0, -- 188
			orbitPeriod = 0, -- 188
			phase0 = 0, -- 188
			orbitDirection = 1 -- 188
		}}, -- 188
		visuals = {{ -- 190
			r = 0.75, -- 191
			g = 0.7, -- 191
			b = 0.6, -- 191
			displayRadius = 1.6, -- 191
			ring = true, -- 191
			model = "Planet_Saturn" -- 191
		}}, -- 191
		goal = {kind = "planet", planetIndex = 0, tolerance = 2.2}, -- 193
		escapeRadius = 400, -- 194
		maxSteps = 1800 -- 195
	} -- 195
} -- 195
--- 关卡总数。
function ____exports.levelCount() -- 200
	return #LEVELS -- 201
end -- 200
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 205
	return LEVELS[index + 1] -- 206
end -- 205
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。
-- 不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 213
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 214
end -- 213
return ____exports -- 213