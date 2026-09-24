-- [ts]: Progress.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__StringSplit = ____lualib.__TS__StringSplit -- 1
local __TS__StringTrim = ____lualib.__TS__StringTrim -- 1
local __TS__StringStartsWith = ____lualib.__TS__StringStartsWith -- 1
local __TS__StringSubstring = ____lualib.__TS__StringSubstring -- 1
local __TS__StringCharCodeAt = ____lualib.__TS__StringCharCodeAt -- 1
local __TS__ParseInt = ____lualib.__TS__ParseInt -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 18
local Content = ____Dora.Content -- 18
local Path = ____Dora.Path -- 18
--- 存档文件名（相对 `Content.writablePath`）。
____exports.ProgressFileName = "escape-velocity.progress" -- 27
--- 存档里的键名，独占一行：`unlocked=N`。
____exports.ProgressKey = "unlocked=" -- 30
--- 存档文件的绝对路径。
function ____exports.progressFilePath() -- 33
	return Path(Content.writablePath, ____exports.ProgressFileName) -- 34
end -- 33
--- 把任意数字夹到 `[0, levelCount - 1]`，非法输入归 0。
-- 
-- “非法”定义（写死在这里，避免各处自行判断）：NaN、±Infinity、
-- 关卡数 <= 0、负数。非整数向下取整（存档只会有整数，读盘时不该因为
-- 出现 `2.0` 这类浮点写法就整份作废）。
function ____exports.clampUnlocked(value, levelCount) -- 44
	if levelCount <= 0 then -- 44
		return 0 -- 45
	end -- 45
	if value ~= value then -- 45
		return 0 -- 46
	end -- 46
	if value == math.huge or value == -math.huge then -- 46
		return 0 -- 47
	end -- 47
	if value < 0 then -- 47
		return 0 -- 48
	end -- 48
	local max = levelCount - 1 -- 49
	if value > max then -- 49
		return max -- 50
	end -- 50
	return math.floor(value) -- 51
end -- 44
--- 结算后推进解锁进度（纯函数）。
-- 
-- - 只有 `success` 才解锁 `levelIndex + 1`；
-- - `missed` / `crashed` 原样返回（再夹紧）；
-- - **不回退**：重玩已解锁的旧关并成功时，取 `max(已解锁, levelIndex + 1)`。
--   任务简报只要求“success 解锁 levelIndex+1”，但纯字面实现会让
--   `advanceUnlocked(3, 'success', 0, 6)` 从 3 掉回 1 —— 玩家重玩第一关
--   反而锁掉后面几关。解锁制（D5）只有“解锁”没有“上锁”，所以取较大值；
--   在正常推进（levelIndex >= unlocked）时与字面语义完全一致。
function ____exports.advanceUnlocked(unlocked, result, levelIndex, levelCount) -- 65
	if result ~= "success" then -- 65
		return ____exports.clampUnlocked(unlocked, levelCount) -- 71
	end -- 71
	local next = levelIndex + 1 -- 72
	local keep = unlocked > next and unlocked or next -- 73
	return ____exports.clampUnlocked(keep, levelCount) -- 74
end -- 65
--- 从 `unlocked=N` 这一行里取数字。
-- 
-- 不用正则：只认“纯十进制数字”，其余（缺行、空值、`abc`、`2.0`、多行垃圾）
-- 一律返回 NaN —— 由 `clampUnlocked` 统一转成 0。
local function parseUnlockedValue(text) -- 83
	local lines = __TS__StringSplit(text, "\n") -- 84
	for ____, rawLine in ipairs(lines) do -- 85
		do -- 85
			local line = __TS__StringTrim(rawLine) -- 86
			if not __TS__StringStartsWith(line, ____exports.ProgressKey) then -- 86
				goto __continue12 -- 87
			end -- 87
			local value = __TS__StringTrim(__TS__StringSubstring(line, #____exports.ProgressKey)) -- 88
			if #value == 0 then -- 88
				goto __continue12 -- 89
			end -- 89
			local digits = true -- 90
			do -- 90
				local i = 0 -- 91
				while i < #value do -- 91
					local c = __TS__StringCharCodeAt(value, i) -- 92
					if c < 48 or c > 57 then -- 92
						digits = false -- 93
					end -- 93
					i = i + 1 -- 91
				end -- 91
			end -- 91
			if not digits then -- 91
				goto __continue12 -- 95
			end -- 95
			return __TS__ParseInt(value, 10) -- 96
		end -- 96
		::__continue12:: -- 96
	end -- 96
	return 0 / 0 -- 98
end -- 83
--- 读进度。文件不存在 / 内容损坏 / 数字非法 → `{ unlocked: 0 }`，**不抛错**。
function ____exports.loadProgress(levelCount) -- 104
	local file = ____exports.progressFilePath() -- 105
	local text = "" -- 106
	do -- 106
		local function ____catch(e) -- 106
			return true, {unlocked = 0} -- 111
		end -- 111
		local ____try, ____hasReturned, ____returnValue = pcall(function() -- 111
			if Content:exist(file) then -- 111
				text = Content:load(file) -- 108
			end -- 108
		end) -- 108
		if not ____try then -- 108
			____hasReturned, ____returnValue = ____catch(____hasReturned) -- 108
		end -- 108
		if ____hasReturned then -- 108
			return ____returnValue -- 107
		end -- 107
	end -- 107
	return {unlocked = ____exports.clampUnlocked( -- 113
		parseUnlockedValue(text), -- 113
		levelCount -- 113
	)} -- 113
end -- 104
--- 写进度。覆盖写，内容严格是 `unlocked=N` 一行。
-- 
-- 用 `toFixed(0)` 而不是 `String()`：Lua 5.3+ 的 `tostring(2.0)` 会输出
-- `"2.0"`，而存档解析只认纯数字，写出去会变成“读回来是 0”。
function ____exports.saveProgress(p) -- 122
	local value = math.floor(p.unlocked) -- 123
	if value ~= value or value == math.huge or value == -math.huge then -- 123
		value = 0 -- 124
	end -- 124
	Content:save( -- 125
		____exports.progressFilePath(), -- 125
		____exports.ProgressKey .. __TS__NumberToFixed(value, 0) -- 125
	) -- 125
end -- 122
return ____exports -- 122