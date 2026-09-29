-- [ts]: Sound.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Audio = ____Dora.Audio -- 1
local AudioRoot = "Assets/Audio/" -- 5
local musicStarted = false -- 6
--- 从应用启动时开始的单条循环配乐；关卡切换与重试不重启。
function ____exports.startBackgroundMusic() -- 9
	if musicStarted then -- 9
		return -- 10
	end -- 10
	musicStarted = true -- 11
	Audio:playStream(AudioRoot .. "bgm_deep_space.ogg", true, 1.2) -- 12
	print("[escape-velocity] audio: background music started") -- 13
end -- 9
--- 播放一个已打包的 WAV 音效。
function ____exports.playSound(cue) -- 17
	Audio:play((AudioRoot .. cue) .. ".wav") -- 18
end -- 17
return ____exports -- 17