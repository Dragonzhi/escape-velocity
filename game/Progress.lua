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
--- 存档文件名（相对 `Content.writablePath`）。
____exports.ProgressFileName = "escape-velocity.progress" -- 22
--- 存档里的键名，独占一行：`unlocked=N`。
____exports.ProgressKey = "unlocked=" -- 25
--- 存档文件的绝对路径。
function ____exports.progressFilePath() -- 28
	return Path(Content.writablePath, ____exports.ProgressFileName) -- 29
end -- 28
--- 把任意数字夹到 `[0, levelCount - 1]`，非法输入归 0。
function ____exports.clampUnlocked(value, levelCount) -- 35
	if levelCount <= 0 then -- 35
		return 0 -- 36
	end -- 36
	if value ~= value then -- 36
		return 0 -- 37
	end -- 37
	if value == math.huge or value == -math.huge then -- 37
		return 0 -- 38
	end -- 38
	if value < 0 then -- 38
		return 0 -- 39
	end -- 39
	local max = levelCount - 1 -- 40
	if value > max then -- 40
		return max -- 41
	end -- 41
	return math.floor(value) -- 42
end -- 35
--- 结算后推进解锁进度（纯函数）。
function ____exports.advanceUnlocked(unlocked, result, levelIndex, levelCount) -- 48
	if result ~= "success" then -- 48
		return ____exports.clampUnlocked(unlocked, levelCount) -- 54
	end -- 54
	local next = levelIndex + 1 -- 55
	local keep = unlocked > next and unlocked or next -- 56
	return ____exports.clampUnlocked(keep, levelCount) -- 57
end -- 48
--- 获取关卡的火箭数（0 ~ 3），自动处理兼容性。
function ____exports.getMissionRockets(p, levelIndex) -- 61
	local key = "L" .. __TS__NumberToFixed(levelIndex + 1, 0) -- 62
	if p.rockets ~= nil and type(p.rockets[key]) == "number" then -- 62
		local r = math.floor(p.rockets[key]) -- 64
		if r >= 0 and r <= 3 then -- 64
			return r -- 65
		end -- 65
		if r > 3 then -- 65
			return 3 -- 66
		end -- 66
		return 0 -- 67
	end -- 67
	if levelIndex < p.unlocked then -- 67
		return 1 -- 70
	end -- 70
	return 0 -- 71
end -- 61
--- 记录关卡评价，更新火箭数并推进解锁（不回退）。
function ____exports.recordMissionResult(p, levelIndex, rocketCount, levelCount) -- 75
	local clampedRockets = math.max( -- 81
		0, -- 81
		math.min( -- 81
			3, -- 81
			math.floor(rocketCount) -- 81
		) -- 81
	) -- 81
	local key = "L" .. __TS__NumberToFixed(levelIndex + 1, 0) -- 82
	local oldRockets = ____exports.getMissionRockets(p, levelIndex) -- 83
	local bestRockets = math.max(oldRockets, clampedRockets) -- 84
	local nextUnlocked = clampedRockets > 0 and ____exports.advanceUnlocked(p.unlocked, "success", levelIndex, levelCount) or ____exports.clampUnlocked(p.unlocked, levelCount) -- 86
	local nextMap = {} -- 90
	if p.rockets ~= nil then -- 90
		for k in pairs(p.rockets) do -- 92
			nextMap[k] = p.rockets[k] -- 93
		end -- 93
	end -- 93
	nextMap[key] = bestRockets -- 96
	return {unlocked = nextUnlocked, rockets = nextMap} -- 98
end -- 75
--- 统计全太阳系获得的火箭总数。
function ____exports.getTotalRockets(p, levelCount) -- 105
	local total = 0 -- 106
	do -- 106
		local i = 0 -- 107
		while i < levelCount do -- 107
			total = total + ____exports.getMissionRockets(p, i) -- 108
			i = i + 1 -- 107
		end -- 107
	end -- 107
	return total -- 110
end -- 105
--- 解析纯十进制数字。
local function parseDigits(value) -- 114
	local v = __TS__StringTrim(value) -- 115
	if #v == 0 then -- 115
		return 0 / 0 -- 116
	end -- 116
	do -- 116
		local i = 0 -- 117
		while i < #v do -- 117
			local c = __TS__StringCharCodeAt(v, i) -- 118
			if c < 48 or c > 57 then -- 118
				return 0 / 0 -- 119
			end -- 119
			i = i + 1 -- 117
		end -- 117
	end -- 117
	return __TS__ParseInt(v, 10) -- 121
end -- 114
--- 读进度。文件不存在 / 内容损坏 / 数字非法 → `{ unlocked: 0, rockets: {} }`，不抛错。
function ____exports.loadProgress(levelCount) -- 127
	local file = ____exports.progressFilePath() -- 128
	local text = "" -- 129
	do -- 129
		local function ____catch(e) -- 129
			return true, {unlocked = 0, rockets = {}} -- 133
		end -- 133
		local ____try, ____hasReturned, ____returnValue = pcall(function() -- 133
			if Content:exist(file) then -- 133
				text = Content:load(file) -- 131
			end -- 131
		end) -- 131
		if not ____try then -- 131
			____hasReturned, ____returnValue = ____catch(____hasReturned) -- 131
		end -- 131
		if ____hasReturned then -- 131
			return ____returnValue -- 130
		end -- 130
	end -- 130
	local unlocked = 0 -- 136
	local rockets = {} -- 137
	local lines = __TS__StringSplit(text, "\n") -- 139
	for ____, rawLine in ipairs(lines) do -- 140
		local line = __TS__StringTrim(rawLine) -- 141
		if __TS__StringStartsWith(line, ____exports.ProgressKey) then -- 141
			local val = parseDigits(__TS__StringSubstring(line, #____exports.ProgressKey)) -- 143
			if not __TS__NumberIsNaN(__TS__Number(val)) then -- 143
				unlocked = ____exports.clampUnlocked(val, levelCount) -- 144
			end -- 144
		elseif __TS__StringStartsWith(line, "L") and (string.find(line, "=", nil, true) or 0) - 1 > 0 then -- 144
			local parts = __TS__StringSplit(line, "=") -- 146
			if #parts == 2 then -- 146
				local key = __TS__StringTrim(parts[1]) -- 148
				local val = parseDigits(parts[2]) -- 149
				if not __TS__NumberIsNaN(__TS__Number(val)) then -- 149
					rockets[key] = math.max( -- 151
						0, -- 151
						math.min(3, val) -- 151
					) -- 151
				end -- 151
			end -- 151
		end -- 151
	end -- 151
	return {unlocked = unlocked, rockets = rockets} -- 157
end -- 127
--- 写进度。首行严格为 `unlocked=N`，后续各行记录 `L1=X`...
function ____exports.saveProgress(p) -- 163
	local value = math.floor(p.unlocked) -- 164
	if value ~= value or value == math.huge or value == -math.huge then -- 164
		value = 0 -- 165
	end -- 165
	local lines = {____exports.ProgressKey .. __TS__NumberToFixed(value, 0)} -- 167
	if p.rockets ~= nil then -- 167
		for k in pairs(p.rockets) do -- 169
			local r = p.rockets[k] -- 170
			if type(r) == "number" and r > 0 then -- 170
				lines[#lines + 1] = (k .. "=") .. __TS__NumberToFixed( -- 172
					math.floor(r), -- 172
					0 -- 172
				) -- 172
			end -- 172
		end -- 172
	end -- 172
	Content:save( -- 176
		____exports.progressFilePath(), -- 176
		table.concat(lines, "\n") -- 176
	) -- 176
end -- 163
return ____exports -- 163