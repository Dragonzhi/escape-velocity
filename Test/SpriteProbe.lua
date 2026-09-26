--[[
最小渲染+截图探针（2026-09-26，排查"GameShot 截图全黑"时写的一次性工具）。

用途：把「引擎在我的实例里到底渲染不渲染、App:saveScreenshot 到底抓不抓得到东西」这件事
与游戏代码彻底分开 —— 只画一个巨大的红色粗线（= 红屏），第 60 帧截图 + 写标记。
若截图仍是纯色，说明问题在引擎/实例侧，不在游戏；若红屏，则问题在加载路径。

运行：pwsh tools/engine-run.ps1 -Run Test/SpriteProbe -SettleSec 4
]]
local Dora = require("Dora")
local App = Dora.App
local Content = Dora.Content
local Director = Dora.Director
local Path = Dora.Path
local Vec2 = Dora.Vec2
local Color = Dora.Color
local DrawNode = Dora.DrawNode
local threadLoop = Dora.threadLoop

local outDir = "C:/Users/32485/AppData/Roaming/IppClub/DoraSSR/escape-velocity/.agent/test-results"

local draw = DrawNode()
draw:drawSegment(Vec2(300, 500), Vec2(301, 500), 900, Color(255, 0, 0, 255))
Director.entry:addChild(draw)
Content:save(Path(outDir, "spriteprobe.txt"), "attached\n")

local n = 0
threadLoop(function()
  n = n + 1
  if n == 60 then
    App:saveScreenshot(Path(outDir, "spriteprobe"))
    Content:save(Path(outDir, "spriteprobe.txt"), "attached n=" .. tostring(n) .. "\n")
  end
  return false
end)
