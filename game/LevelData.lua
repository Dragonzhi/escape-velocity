-- [ts]: LevelData.ts
local ____exports = {} -- 1
local applyScalesLocal -- 1
local ____Gravity = require("game.Gravity") -- 34
local bodyPositionAt = ____Gravity.bodyPositionAt -- 34
local distance = ____Gravity.distance -- 34
local ____Config = require("game.Config") -- 35
local GravityScale = ____Config.GravityScale -- 35
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 35
function applyScalesLocal(bodies, gravityScale, orbitScale) -- 271
	local out = {} -- 272
	for ____, b in ipairs(bodies) do -- 273
		out[#out + 1] = { -- 274
			gm = b.gm * gravityScale, -- 275
			radius = b.radius, -- 276
			orbitCenter = {x = b.orbitCenter.x, y = b.orbitCenter.y}, -- 277
			orbitRadius = b.orbitRadius, -- 278
			orbitPeriod = (b.orbitPeriod == 0 or orbitScale <= 0) and b.orbitPeriod or b.orbitPeriod / orbitScale, -- 279
			phase0 = b.phase0, -- 280
			orbitDirection = b.orbitDirection -- 281
		} -- 281
	end -- 281
	return out -- 284
end -- 284
--- 在飞行采样点中找第一个进入目标容差的索引。
-- 
-- 目标行星在移动，所以逐点用 `t = t0 + i * dt` 时的行星位置判定（`t0` = 发射时刻，见 Gravity.SimOptions）。
-- `dt` 必须是**采样点之间的有效步长**（采样间隔 N 步时要传 `N * PhysicsStep`，否则移动目标的时间轴是错的）。
-- 返回 -1 表示未到达。
function ____exports.findGoalIndex(points, bodies, goal, dt, t0) -- 96
	if goal.kind ~= "planet" then -- 96
		return -1 -- 97
	end -- 97
	local body = bodies[goal.planetIndex + 1] -- 98
	if body == nil then -- 98
		return -1 -- 99
	end -- 99
	local start = t0 ~= nil and t0 or 0 -- 100
	do -- 100
		local i = 0 -- 101
		while i < #points do -- 101
			local gp = bodyPositionAt(body, start + i * dt) -- 102
			if distance(points[i + 1], gp) < goal.tolerance then -- 102
				return i -- 103
			end -- 103
			i = i + 1 -- 101
		end -- 101
	end -- 101
	return -1 -- 105
end -- 96
local LEVELS = { -- 116
	{ -- 117
		id = 1, -- 118
		title = "出发", -- 119
		brief = "1977 年 9 月 5 日，旅行者号离开地球。拖动瞄准，松手发射 —— 先学会让它听话。", -- 120
		probeStart = {x = 0, y = 16}, -- 121
		planets = {{ -- 122
			gm = 0, -- 124
			radius = 0.75, -- 124
			orbitCenter = {x = 0, y = -30}, -- 124
			orbitRadius = 0, -- 124
			orbitPeriod = 0, -- 124
			phase0 = 0, -- 124
			orbitDirection = 1 -- 124
		}}, -- 124
		visuals = {{ -- 126
			r = 0.56, -- 127
			g = 0.56, -- 127
			b = 0.6, -- 127
			displayRadius = 0.75, -- 127
			ring = false -- 127
		}}, -- 127
		goal = {kind = "planet", planetIndex = 0, tolerance = 3.75}, -- 129
		escapeRadius = 400, -- 130
		maxSteps = 1500, -- 131
		homeRadius = 1.35 -- 132
	}, -- 132
	{ -- 134
		id = 2, -- 135
		title = "借力", -- 136
		brief = "别对准目标，对准木星。它的引力会把你的航线掰过去 —— 但别撞上去。", -- 137
		probeStart = {x = 0, y = 16}, -- 138
		planets = {{ -- 139
			gm = 1500, -- 141
			radius = 3.56, -- 141
			orbitCenter = {x = 0, y = -6}, -- 141
			orbitRadius = 0, -- 141
			orbitPeriod = 0, -- 141
			phase0 = 0, -- 141
			orbitDirection = 1 -- 141
		}, { -- 141
			gm = 0, -- 143
			radius = 3.31, -- 143
			orbitCenter = {x = -26, y = -26}, -- 143
			orbitRadius = 0, -- 143
			orbitPeriod = 0, -- 143
			phase0 = 0, -- 143
			orbitDirection = 1 -- 143
		}}, -- 143
		visuals = {{ -- 145
			r = 0.85, -- 146
			g = 0.72, -- 146
			b = 0.5, -- 146
			displayRadius = 3.56, -- 146
			ring = false, -- 146
			model = "Planet_Jupiter" -- 146
		}, { -- 146
			r = 0.75, -- 147
			g = 0.7, -- 147
			b = 0.6, -- 147
			displayRadius = 3.31, -- 147
			ring = true, -- 147
			model = "Planet_Saturn" -- 147
		}}, -- 147
		goal = {kind = "planet", planetIndex = 1, tolerance = 6.31}, -- 149
		escapeRadius = 400, -- 150
		maxSteps = 1800, -- 151
		homeRadius = 1.2 -- 152
	}, -- 152
	{ -- 154
		id = 3, -- 155
		title = "加速", -- 156
		brief = "土星在动。从它背后追上去，你会被带着加速；迎头撞进它的引力，你会被拖慢。", -- 157
		probeStart = {x = 0, y = 16}, -- 158
		planets = {{ -- 159
			gm = 1100, -- 161
			radius = 3.31, -- 161
			orbitCenter = {x = 0, y = -4}, -- 161
			orbitRadius = 10, -- 161
			orbitPeriod = 12, -- 161
			phase0 = -1.0471975511965976, -- 161
			orbitDirection = 1 -- 161
		}, { -- 161
			gm = 0, -- 163
			radius = 2.34, -- 163
			orbitCenter = {x = -24, y = -28}, -- 163
			orbitRadius = 0, -- 163
			orbitPeriod = 0, -- 163
			phase0 = 0, -- 163
			orbitDirection = 1 -- 163
		}}, -- 163
		visuals = {{ -- 165
			r = 0.75, -- 166
			g = 0.7, -- 166
			b = 0.6, -- 166
			displayRadius = 3.31, -- 166
			ring = true, -- 166
			model = "Planet_Saturn" -- 166
		}, { -- 166
			r = 0.62, -- 167
			g = 0.82, -- 167
			b = 0.86, -- 167
			displayRadius = 2.34, -- 167
			ring = false, -- 167
			model = "Planet_Uranus" -- 167
		}}, -- 167
		goal = {kind = "planet", planetIndex = 1, tolerance = 5.34}, -- 169
		escapeRadius = 400, -- 170
		maxSteps = 1800, -- 171
		homeRadius = 1.05 -- 172
	}, -- 172
	{ -- 174
		id = 4, -- 175
		title = "窗口", -- 176
		brief = "木星和土星都在公转，发射时机就是你的第三个旋钮。拖动时间轴，看它们挪位置。", -- 177
		probeStart = {x = 0, y = 16}, -- 178
		planets = {{ -- 179
			gm = 2000, -- 182
			radius = 3.56, -- 182
			orbitCenter = {x = 0, y = -6}, -- 182
			orbitRadius = 8, -- 182
			orbitPeriod = 6, -- 182
			phase0 = 3.141592653589793, -- 182
			orbitDirection = 1 -- 182
		}, { -- 182
			gm = 1400, -- 183
			radius = 3.31, -- 183
			orbitCenter = {x = -12, y = -16}, -- 183
			orbitRadius = 8, -- 183
			orbitPeriod = 8, -- 183
			phase0 = 4.71238898038469, -- 183
			orbitDirection = 1 -- 183
		}, { -- 183
			gm = 0, -- 185
			radius = 2.31, -- 185
			orbitCenter = {x = -28, y = -38}, -- 185
			orbitRadius = 0, -- 185
			orbitPeriod = 0, -- 185
			phase0 = 0, -- 185
			orbitDirection = 1 -- 185
		}}, -- 185
		visuals = {{ -- 187
			r = 0.85, -- 188
			g = 0.72, -- 188
			b = 0.5, -- 188
			displayRadius = 3.56, -- 188
			ring = false, -- 188
			model = "Planet_Jupiter" -- 188
		}, { -- 188
			r = 0.75, -- 189
			g = 0.7, -- 189
			b = 0.6, -- 189
			displayRadius = 3.31, -- 189
			ring = true, -- 189
			model = "Planet_Saturn" -- 189
		}, { -- 189
			r = 0.34, -- 190
			g = 0.5, -- 190
			b = 0.86, -- 190
			displayRadius = 2.31, -- 190
			ring = false, -- 190
			model = "Planet_Neptune" -- 190
		}}, -- 190
		goal = {kind = "planet", planetIndex = 2, tolerance = 2.91}, -- 192
		escapeRadius = 400, -- 193
		maxSteps = 1800, -- 194
		homeRadius = 0.95, -- 195
		timeWindow = {span = 16} -- 197
	}, -- 197
	{ -- 199
		id = 5, -- 200
		title = "连锁", -- 201
		brief = "接力：木星把你甩向土星，土星把你交给那颗小行星，最后由它把航线掰到海王星。", -- 202
		probeStart = {x = 0, y = 18}, -- 203
		planets = {{ -- 204
			gm = 2240, -- 206
			radius = 3.56, -- 206
			orbitCenter = {x = 5, y = -2}, -- 206
			orbitRadius = 0, -- 206
			orbitPeriod = 0, -- 206
			phase0 = 0, -- 206
			orbitDirection = 1 -- 206
		}, { -- 206
			gm = 1600, -- 207
			radius = 3.31, -- 207
			orbitCenter = {x = -7, y = -18}, -- 207
			orbitRadius = 0, -- 207
			orbitPeriod = 0, -- 207
			phase0 = 0, -- 207
			orbitDirection = 1 -- 207
		}, { -- 207
			gm = 300, -- 208
			radius = 0.6, -- 208
			orbitCenter = {x = -16, y = -27}, -- 208
			orbitRadius = 0, -- 208
			orbitPeriod = 0, -- 208
			phase0 = 0, -- 208
			orbitDirection = 1 -- 208
		}, { -- 208
			gm = 0, -- 210
			radius = 2.31, -- 210
			orbitCenter = {x = -26, y = -42}, -- 210
			orbitRadius = 0, -- 210
			orbitPeriod = 0, -- 210
			phase0 = 0, -- 210
			orbitDirection = 1 -- 210
		}}, -- 210
		visuals = {{ -- 212
			r = 0.85, -- 213
			g = 0.72, -- 213
			b = 0.5, -- 213
			displayRadius = 3.56, -- 213
			ring = false, -- 213
			model = "Planet_Jupiter" -- 213
		}, { -- 213
			r = 0.75, -- 214
			g = 0.7, -- 214
			b = 0.6, -- 214
			displayRadius = 3.31, -- 214
			ring = true, -- 214
			model = "Planet_Saturn" -- 214
		}, { -- 214
			r = 0.52, -- 216
			g = 0.5, -- 216
			b = 0.46, -- 216
			displayRadius = 0.6, -- 216
			ring = false -- 216
		}, { -- 216
			r = 0.34, -- 217
			g = 0.5, -- 217
			b = 0.86, -- 217
			displayRadius = 2.31, -- 217
			ring = false, -- 217
			model = "Planet_Neptune" -- 217
		}}, -- 217
		goal = {kind = "planet", planetIndex = 3, tolerance = 5.31}, -- 219
		escapeRadius = 400, -- 220
		maxSteps = 1800, -- 221
		homeRadius = 0.85 -- 222
	}, -- 222
	{ -- 224
		id = 6, -- 225
		title = "单程", -- 226
		brief = "最后一次点火。四颗巨行星串成一条路，飞出太阳系 —— 没有回程。", -- 227
		probeStart = {x = 0, y = 16}, -- 228
		planets = {{ -- 229
			gm = 2600, -- 231
			radius = 3.56, -- 231
			orbitCenter = {x = 0, y = -10}, -- 231
			orbitRadius = 10, -- 231
			orbitPeriod = 5, -- 231
			phase0 = 3.141592653589793, -- 231
			orbitDirection = 1 -- 231
		}, { -- 231
			gm = 700, -- 233
			radius = 3.31, -- 233
			orbitCenter = {x = -14, y = -30}, -- 233
			orbitRadius = 0, -- 233
			orbitPeriod = 0, -- 233
			phase0 = 0, -- 233
			orbitDirection = 1 -- 233
		}, { -- 233
			gm = 350, -- 234
			radius = 2.34, -- 234
			orbitCenter = {x = 15, y = -32}, -- 234
			orbitRadius = 0, -- 234
			orbitPeriod = 0, -- 234
			phase0 = 0, -- 234
			orbitDirection = 1 -- 234
		}, { -- 234
			gm = 250, -- 235
			radius = 2.31, -- 235
			orbitCenter = {x = -22, y = -40}, -- 235
			orbitRadius = 0, -- 235
			orbitPeriod = 0, -- 235
			phase0 = 0, -- 235
			orbitDirection = 1 -- 235
		}}, -- 235
		visuals = {{ -- 237
			r = 0.85, -- 238
			g = 0.72, -- 238
			b = 0.5, -- 238
			displayRadius = 3.56, -- 238
			ring = false, -- 238
			model = "Planet_Jupiter" -- 238
		}, { -- 238
			r = 0.75, -- 239
			g = 0.7, -- 239
			b = 0.6, -- 239
			displayRadius = 3.31, -- 239
			ring = true, -- 239
			model = "Planet_Saturn" -- 239
		}, { -- 239
			r = 0.62, -- 240
			g = 0.82, -- 240
			b = 0.86, -- 240
			displayRadius = 2.34, -- 240
			ring = false, -- 240
			model = "Planet_Uranus" -- 240
		}, { -- 240
			r = 0.34, -- 241
			g = 0.5, -- 241
			b = 0.86, -- 241
			displayRadius = 2.31, -- 241
			ring = false, -- 241
			model = "Planet_Neptune" -- 241
		}}, -- 241
		goal = {kind = "escape", planetIndex = -1, tolerance = 0}, -- 244
		escapeRadius = 400, -- 245
		maxSteps = 2400, -- 247
		homeRadius = 0.75 -- 248
	} -- 248
} -- 248
--- 关卡总数。
function ____exports.levelCount() -- 253
	return #LEVELS -- 254
end -- 253
--- 取第 index 关（0 起）。越界返回 undefined。
function ____exports.getLevel(index) -- 258
	return LEVELS[index + 1] -- 259
end -- 258
--- 应用全局倍率，返回可直接喂给 createGame 的行星数组。
-- 不修改关卡原始数据。
function ____exports.scaledPlanets(level) -- 266
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale) -- 267
end -- 266
return ____exports -- 266