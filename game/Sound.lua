-- [ts]: Sound.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Audio = ____Dora.Audio -- 1
local AudioSource = ____Dora.AudioSource -- 1
local Content = ____Dora.Content -- 1
local Director = ____Dora.Director -- 1
local AudioRoot = "Assets/Audio/" -- 5
local music = nil -- 6
local musicStarts = 0 -- 7
--- 从应用启动时开始的单条循环配乐；关卡切换与重试不重启。
function ____exports.startBackgroundMusic() -- 10
	if music ~= nil and music.playing then -- 10
		return -- 11
	end -- 11
	local path = AudioRoot .. "bgm_galactic_temple.ogg" -- 12
	if not Content:exist(path) then -- 12
		print("[escape-velocity] audio: missing music " .. path) -- 13
		return -- 13
	end -- 13
	local source = AudioSource(path, false) -- 14
	if source == nil then -- 14
		print("[escape-velocity] audio: music load failed " .. path) -- 15
		return -- 15
	end -- 15
	source.looping = true -- 16
	source.volume = 0.5 -- 17
	source:setProtected(true) -- 18
	Director.entry:addChild(source) -- 19
	if not source:playBackground() then -- 19
		source:removeFromParent() -- 21
		print("[escape-velocity] audio: music playback failed " .. path) -- 22
		return -- 23
	end -- 23
	music = source -- 25
	musicStarts = musicStarts + 1 -- 26
	print((((("[escape-velocity] audio: Galactic Temple playing=" .. tostring(source.playing)) .. " loop=") .. tostring(source.looping)) .. " volume=") .. tostring(source.volume)) -- 27
end -- 10
--- Read-only probe: no lifecycle or playback changes.
function ____exports.backgroundMusicState() -- 31
	return music == nil and "missing" or (((((("playing=" .. tostring(music.playing)) .. " loop=") .. tostring(music.looping)) .. " volume=") .. tostring(music.volume)) .. " starts=") .. tostring(musicStarts) -- 32
end -- 31
--- 播放一个已打包的 WAV 音效。
function ____exports.playSound(cue) -- 36
	Audio:play((AudioRoot .. cue) .. ".wav") -- 37
end -- 36
return ____exports -- 36