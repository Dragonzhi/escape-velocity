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
	local rockets = p.rockets ~= nil and p.rockets[key] ~= nil and p.rockets[key] or 0 -- 120
	return rockets > 0 or levelIndex < p.unlocked -- 121
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
function ____exports.getTotalRockets(p, levelCount) -- 125
	local total = 0 -- 126
	do -- 126
		local i = 0 -- 127
		while i < levelCount do -- 127
			total = total + ____exports.getMissionRockets(p, i) -- 128
			i = i + 1 -- 127
		end -- 127
	end -- 127
	return total -- 130
end -- 125
--- 解析纯十进制数字。
local function parseDigits(value) -- 134
	local v = __TS__StringTrim(value) -- 135
	if #v == 0 then -- 135
		return 0 / 0 -- 136
	end -- 136
	do -- 136
		local i = 0 -- 137
		while i < #v do -- 137
			local c = __TS__StringCharCodeAt(v, i) -- 138
			if c < 48 or c > 57 then -- 138
				return 0 / 0 -- 139
			end -- 139
			i = i + 1 -- 137
		end -- 137
	end -- 137
	return __TS__ParseInt(v, 10) -- 141
end -- 134
--- 读进度。文件不存在 / 内容损坏 / 数字非法 → `{ unlocked: 0, rockets: {} }`，不抛错。
function ____exports.loadProgress(levelCount) -- 147
	local file = ____exports.progressFilePath() -- 148
	local text = "" -- 149
	do -- 149
		local function ____catch(e) -- 149
			return true, {unlocked = 0, rockets = {}, completed = {}, bestScores = {}} -- 153
		end -- 153
		local ____try, ____hasReturned, ____returnValue = pcall(function() -- 153
			if Content:exist(file) then -- 153
				text = Content:load(file) -- 151
			end -- 151
		end) -- 151
		if not ____try then -- 151
			____hasReturned, ____returnValue = ____catch(____hasReturned) -- 151
		end -- 151
		if ____hasReturned then -- 151
			return ____returnValue -- 150
		end -- 150
	end -- 150
	local unlocked = 0 -- 156
	local rockets = {} -- 157
	local completed = {} -- 158
	local bestScores = {} -- 159
	local lines = __TS__StringSplit(text, "\n") -- 161
	for ____, rawLine in ipairs(lines) do -- 162
		local line = __TS__StringTrim(rawLine) -- 163
		if __TS__StringStartsWith(line, ____exports.ProgressKey) then -- 163
			local val = parseDigits(__TS__StringSubstring(line, #____exports.ProgressKey)) -- 165
			if not __TS__NumberIsNaN(__TS__Number(val)) then -- 165
				unlocked = ____exports.clampUnlocked(val, levelCount) -- 166
			end -- 166
		elseif __TS__StringStartsWith(line, "complete:") then -- 166
			local parts = __TS__StringSplit( -- 168
				__TS__StringSubstring(line, 8), -- 168
				"=" -- 168
			) -- 168
			if #parts == 2 then -- 168
				completed[parts[1]] = parts[2] == "1" -- 169
			end -- 169
		elseif __TS__StringStartsWith(line, "best:") then -- 169
			local parts = __TS__StringSplit( -- 171
				__TS__StringSubstring(line, 5), -- 171
				"=" -- 171
			) -- 171
			if #parts == 2 then -- 171
				local val = parseDigits(parts[2]) -- 172
				if not __TS__NumberIsNaN(__TS__Number(val)) then -- 172
					bestScores[parts[1]] = math.max(0, val) -- 172
				end -- 172
			end -- 172
		elseif __TS__StringStartsWith(line, "L") and (string.find(line, "=", nil, true) or 0) - 1 > 0 then -- 172
			local parts = __TS__StringSplit(line, "=") -- 174
			if #parts == 2 then -- 174
				local key = __TS__StringTrim(parts[1]) -- 176
				local val = parseDigits(parts[2]) -- 177
				if not __TS__NumberIsNaN(__TS__Number(val)) then -- 177
					rockets[key] = math.max( -- 179
						0, -- 179
						math.min(3, val) -- 179
					) -- 179
				end -- 179
			end -- 179
		end -- 179
	end -- 179
	do -- 179
		local i = 0 -- 185
		while i < levelCount do -- 185
			local key = "L" .. __TS__NumberToFixed(i + 1, 0) -- 186
			if completed[key] == nil then -- 186
				completed[key] = rockets[key] ~= nil and rockets[key] > 0 or i < unlocked -- 187
			end -- 187
			if bestScores[key] == nil then -- 187
				bestScores[key] = 0 -- 189
			end -- 189
			i = i + 1 -- 185
		end -- 185
	end -- 185
	return {unlocked = unlocked, rockets = rockets, completed = completed, bestScores = bestScores} -- 191
end -- 147
--- 写进度。保留旧 `unlocked`/`L1` 行，并增加 `complete:L1=1`、`best:L1=N`。
function ____exports.saveProgress(p) -- 197
	local value = math.floor(p.unlocked) -- 198
	if value ~= value or value == math.huge or value == -math.huge then -- 198
		value = 0 -- 199
	end -- 199
	local lines = { -- 201
		____exports.ProgressKey .. __TS__NumberToFixed(value, 0), -- 201
		"version=2" -- 201
	} -- 201
	if p.rockets ~= nil then -- 201
		for k in pairs(p.rockets) do -- 203
			local r = p.rockets[k] -- 204
			if type(r) == "number" and r > 0 then -- 204
				lines[#lines + 1] = (k .. "=") .. __TS__NumberToFixed( -- 206
					math.floor(r), -- 206
					0 -- 206
				) -- 206
			end -- 206
		end -- 206
	end -- 206
	if p.completed ~= nil then -- 206
		for k in pairs(p.completed) do -- 210
			lines[#lines + 1] = (("complete:" .. k) .. "=") .. (p.completed[k] and "1" or "0") -- 210
		end -- 210
	end -- 210
	if p.bestScores ~= nil then -- 210
		for k in pairs(p.bestScores) do -- 211
			lines[#lines + 1] = (("best:" .. k) .. "=") .. __TS__NumberToFixed( -- 211
				math.max( -- 211
					0, -- 211
					math.floor(p.bestScores[k]) -- 211
				), -- 211
				0 -- 211
			) -- 211
		end -- 211
	end -- 211
	Content:save( -- 212
		____exports.progressFilePath(), -- 212
		table.concat(lines, "\n") -- 212
	) -- 212
end -- 197
return ____exports -- 197