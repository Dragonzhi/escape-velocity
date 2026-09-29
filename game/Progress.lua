-- [ts]: Progress.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__StringTrim = ____lualib.__TS__StringTrim -- 1
local __TS__StringCharCodeAt = ____lualib.__TS__StringCharCodeAt -- 1
local __TS__ParseInt = ____lualib.__TS__ParseInt -- 1
local __TS__StringSplit = ____lualib.__TS__StringSplit -- 1
local __TS__StringStartsWith = ____lualib.__TS__StringStartsWith -- 1
local __TS__StringSubstring = ____lualib.__TS__StringSubstring -- 1
local __TS__Number = ____lualib.__TS__Number -- 1
local __TS__NumberIsNaN = ____lualib.__TS__NumberIsNaN -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 12
local Content = ____Dora.Content -- 12
local Path = ____Dora.Path -- 12
function ____exports.getMissionCompleted(p, levelIndex) -- 117
	local key = "L" .. __TS__NumberToFixed(levelIndex + 1, 0) -- 118
	if p.completed ~= nil and p.completed[key] ~= nil then -- 118
		return p.completed[key] -- 119
	end -- 119
	return p.rockets ~= nil and (p.rockets[key] or 0) > 0 or levelIndex < p.unlocked -- 120
end -- 117
--- 存档文件名（相对 `Content.writablePath`）。
____exports.ProgressFileName = "escape-velocity.progress" -- 24
--- 存档里的键名，独占一行：`unlocked=N`。
____exports.ProgressKey = "unlocked=" -- 27
--- 存档文件的绝对路径。
function ____exports.progressFilePath() -- 30
	return Path(Content.writablePath, ____exports.ProgressFileName) -- 31
end -- 30
--- 把任意数字夹到 `[0, levelCount - 1]`，非法输入归 0。
function ____exports.clampUnlocked(value, levelCount) -- 37
	if levelCount <= 0 then -- 37
		return 0 -- 38
	end -- 38
	if value ~= value then -- 38
		return 0 -- 39
	end -- 39
	if value == math.huge or value == -math.huge then -- 39
		return 0 -- 40
	end -- 40
	if value < 0 then -- 40
		return 0 -- 41
	end -- 41
	local max = levelCount - 1 -- 42
	if value > max then -- 42
		return max -- 43
	end -- 43
	return math.floor(value) -- 44
end -- 37
--- 结算后推进解锁进度（纯函数）。
function ____exports.advanceUnlocked(unlocked, result, levelIndex, levelCount) -- 50
	if result ~= "success" then -- 50
		return ____exports.clampUnlocked(unlocked, levelCount) -- 56
	end -- 56
	local next = levelIndex + 1 -- 57
	local keep = unlocked > next and unlocked or next -- 58
	return ____exports.clampUnlocked(keep, levelCount) -- 59
end -- 50
--- 获取关卡点位火箭最高分；未迁移的旧内存结构仍可读取历史火箭字段。
function ____exports.getMissionRockets(p, levelIndex) -- 63
	local key = "L" .. __TS__NumberToFixed(levelIndex + 1, 0) -- 64
	if p.bestScores ~= nil and type(p.bestScores[key]) == "number" then -- 64
		return math.max( -- 65
			0, -- 65
			math.min( -- 65
				99, -- 65
				math.floor(p.bestScores[key]) -- 65
			) -- 65
		) -- 65
	end -- 65
	if p.rockets ~= nil and type(p.rockets[key]) == "number" then -- 65
		local r = math.floor(p.rockets[key]) -- 67
		if r >= 0 and r <= 3 then -- 67
			return r -- 68
		end -- 68
		if r > 3 then -- 68
			return 3 -- 69
		end -- 69
		return 0 -- 70
	end -- 70
	if levelIndex < p.unlocked then -- 70
		return 1 -- 73
	end -- 73
	return 0 -- 74
end -- 63
--- 记录关卡评价，更新火箭数并推进解锁（不回退）。
function ____exports.recordMissionResult(p, levelIndex, rocketCount, levelCount, completed) -- 78
	local ____temp_0 -- 85
	if completed ~= nil then -- 85
		____temp_0 = completed -- 85
	else -- 85
		____temp_0 = rocketCount > 0 -- 85
	end -- 85
	local didComplete = ____temp_0 -- 85
	local clampedRockets = didComplete and math.max( -- 86
		0, -- 86
		math.min( -- 86
			99, -- 86
			math.floor(rocketCount) -- 86
		) -- 86
	) or 0 -- 86
	local key = "L" .. __TS__NumberToFixed(levelIndex + 1, 0) -- 87
	local oldRockets = p.bestScores ~= nil and p.bestScores[key] ~= nil and p.bestScores[key] or 0 -- 88
	local bestRockets = math.max(oldRockets, clampedRockets) -- 89
	local nextUnlocked = didComplete and ____exports.advanceUnlocked(p.unlocked, "success", levelIndex, levelCount) or ____exports.clampUnlocked(p.unlocked, levelCount) -- 90
	local nextMap = {} -- 94
	if p.rockets ~= nil then -- 94
		for k in pairs(p.rockets) do -- 96
			nextMap[k] = p.rockets[k] -- 97
		end -- 97
	end -- 97
	local completedMap = {} -- 100
	if p.completed ~= nil then -- 100
		for k in pairs(p.completed) do -- 101
			completedMap[k] = p.completed[k] -- 101
		end -- 101
	end -- 101
	local bestMap = {} -- 102
	if p.bestScores ~= nil then -- 102
		for k in pairs(p.bestScores) do -- 103
			bestMap[k] = p.bestScores[k] -- 103
		end -- 103
	end -- 103
	completedMap[key] = didComplete or ____exports.getMissionCompleted(p, levelIndex) -- 104
	bestMap[key] = bestRockets -- 105
	if nextMap[key] == nil then -- 105
		nextMap[key] = p.rockets ~= nil and p.rockets[key] ~= nil and p.rockets[key] or 0 -- 107
	end -- 107
	return {unlocked = nextUnlocked, rockets = nextMap, completed = completedMap, bestScores = bestMap} -- 109
end -- 78
--- 统计全太阳系获得的火箭总数。
function ____exports.getTotalRockets(p, levelCount) -- 124
	local total = 0 -- 125
	do -- 125
		local i = 0 -- 126
		while i < levelCount do -- 126
			total = total + ____exports.getMissionRockets(p, i) -- 127
			i = i + 1 -- 126
		end -- 126
	end -- 126
	return total -- 129
end -- 124
--- 解析纯十进制数字。
local function parseDigits(value) -- 133
	local v = __TS__StringTrim(value) -- 134
	if #v == 0 then -- 134
		return 0 / 0 -- 135
	end -- 135
	do -- 135
		local i = 0 -- 136
		while i < #v do -- 136
			local c = __TS__StringCharCodeAt(v, i) -- 137
			if c < 48 or c > 57 then -- 137
				return 0 / 0 -- 138
			end -- 138
			i = i + 1 -- 136
		end -- 136
	end -- 136
	return __TS__ParseInt(v, 10) -- 140
end -- 133
--- 读进度。文件不存在 / 内容损坏 / 数字非法 → `{ unlocked: 0, rockets: {} }`，不抛错。
function ____exports.loadProgress(levelCount) -- 146
	local file = ____exports.progressFilePath() -- 147
	local text = "" -- 148
	do -- 148
		local function ____catch(e) -- 148
			return true, {unlocked = 0, rockets = {}, completed = {}, bestScores = {}} -- 152
		end -- 152
		local ____try, ____hasReturned, ____returnValue = pcall(function() -- 152
			if Content:exist(file) then -- 152
				text = Content:load(file) -- 150
			end -- 150
		end) -- 150
		if not ____try then -- 150
			____hasReturned, ____returnValue = ____catch(____hasReturned) -- 150
		end -- 150
		if ____hasReturned then -- 150
			return ____returnValue -- 149
		end -- 149
	end -- 149
	local unlocked = 0 -- 155
	local rockets = {} -- 156
	local completed = {} -- 157
	local bestScores = {} -- 158
	local lines = __TS__StringSplit(text, "\n") -- 160
	for ____, rawLine in ipairs(lines) do -- 161
		local line = __TS__StringTrim(rawLine) -- 162
		if __TS__StringStartsWith(line, ____exports.ProgressKey) then -- 162
			local val = parseDigits(__TS__StringSubstring(line, #____exports.ProgressKey)) -- 164
			if not __TS__NumberIsNaN(__TS__Number(val)) then -- 164
				unlocked = ____exports.clampUnlocked(val, levelCount) -- 165
			end -- 165
		elseif __TS__StringStartsWith(line, "complete:") then -- 165
			local parts = __TS__StringSplit( -- 167
				__TS__StringSubstring(line, 8), -- 167
				"=" -- 167
			) -- 167
			if #parts == 2 then -- 167
				completed[parts[1]] = parts[2] == "1" -- 168
			end -- 168
		elseif __TS__StringStartsWith(line, "best:") then -- 168
			local parts = __TS__StringSplit( -- 170
				__TS__StringSubstring(line, 5), -- 170
				"=" -- 170
			) -- 170
			if #parts == 2 then -- 170
				local val = parseDigits(parts[2]) -- 171
				if not __TS__NumberIsNaN(__TS__Number(val)) then -- 171
					bestScores[parts[1]] = math.max(0, val) -- 171
				end -- 171
			end -- 171
		elseif __TS__StringStartsWith(line, "L") and (string.find(line, "=", nil, true) or 0) - 1 > 0 then -- 171
			local parts = __TS__StringSplit(line, "=") -- 173
			if #parts == 2 then -- 173
				local key = __TS__StringTrim(parts[1]) -- 175
				local val = parseDigits(parts[2]) -- 176
				if not __TS__NumberIsNaN(__TS__Number(val)) then -- 176
					rockets[key] = math.max( -- 178
						0, -- 178
						math.min(3, val) -- 178
					) -- 178
				end -- 178
			end -- 178
		end -- 178
	end -- 178
	do -- 178
		local i = 0 -- 184
		while i < levelCount do -- 184
			local key = "L" .. __TS__NumberToFixed(i + 1, 0) -- 185
			if completed[key] == nil then -- 185
				completed[key] = rockets[key] ~= nil and rockets[key] > 0 or i < unlocked -- 186
			end -- 186
			if bestScores[key] == nil then -- 186
				bestScores[key] = 0 -- 188
			end -- 188
			i = i + 1 -- 184
		end -- 184
	end -- 184
	return {unlocked = unlocked, rockets = rockets, completed = completed, bestScores = bestScores} -- 190
end -- 146
--- 写进度。保留旧 `unlocked`/`L1` 行，并增加 `complete:L1=1`、`best:L1=N`。
function ____exports.saveProgress(p) -- 196
	local value = math.floor(p.unlocked) -- 197
	if value ~= value or value == math.huge or value == -math.huge then -- 197
		value = 0 -- 198
	end -- 198
	local lines = { -- 200
		____exports.ProgressKey .. __TS__NumberToFixed(value, 0), -- 200
		"version=2" -- 200
	} -- 200
	if p.rockets ~= nil then -- 200
		for k in pairs(p.rockets) do -- 202
			local r = p.rockets[k] -- 203
			if type(r) == "number" and r > 0 then -- 203
				lines[#lines + 1] = (k .. "=") .. __TS__NumberToFixed( -- 205
					math.floor(r), -- 205
					0 -- 205
				) -- 205
			end -- 205
		end -- 205
	end -- 205
	if p.completed ~= nil then -- 205
		for k in pairs(p.completed) do -- 209
			lines[#lines + 1] = (("complete:" .. k) .. "=") .. (p.completed[k] and "1" or "0") -- 209
		end -- 209
	end -- 209
	if p.bestScores ~= nil then -- 209
		for k in pairs(p.bestScores) do -- 210
			lines[#lines + 1] = (("best:" .. k) .. "=") .. __TS__NumberToFixed( -- 210
				math.max( -- 210
					0, -- 210
					math.floor(p.bestScores[k]) -- 210
				), -- 210
				0 -- 210
			) -- 210
		end -- 210
	end -- 210
	Content:save( -- 211
		____exports.progressFilePath(), -- 211
		table.concat(lines, "\n") -- 211
	) -- 211
end -- 196
return ____exports -- 196