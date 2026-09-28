--[[
探针引导（**故意是手写 Lua、不是 TS**）。

为什么需要它：TSTL 编译出来的模块在**文件头**就 require("game.X")，而单文件入口
（/run asProj=false）的搜索根是 <proj>/Test ⇒ 那些 require 必然报
"module 'game.LevelData' not found"（2026-09-28 实测两次，等 12 秒让项目先跑起来也没用）。
这里照 Test/UnitRunner.lua 的办法：先把项目根塞进 Content.searchPaths，再按绝对路径 load 探针。

用法：pwsh tools/engine-run.ps1 -Run Test/ClipProbe -WaitFile .agent/test-results/clip-probe.txt
]]
local Dora = require("Dora")
local Content = Dora.Content
local Path = Dora.Path

local searchPaths = Content.searchPaths
local root = nil
for i = 0, 8 do
  local p = searchPaths[i]
  if p ~= nil
    and (Content:exist(Path(p, "init.lua")) or Content:exist(Path(p, "init.ts")))
    and Content:exist(Path(p, "game", "Scene.lua")) then
    root = p
    break
  end
end
if root == nil and searchPaths[0] ~= nil then
  local up = Path(searchPaths[0], "..")
  if Content:exist(Path(up, "init.lua")) and Content:exist(Path(up, "game", "Scene.lua")) then
    root = up
  end
end
if root == nil then
  local byWritable = Path(Content.writablePath, "escape-velocity")
  if Content:exist(Path(byWritable, "init.lua")) and Content:exist(Path(byWritable, "game", "Scene.lua")) then
    root = byWritable
  end
end
if root == nil then root = "." end
Content:addSearchPath(root)
print("[escape-velocity][clip-probe] project root = " .. root)

local target = Path(root, "Test", "ClipPlaneProbe.lua")
if not Content:exist(target) then
  print("[escape-velocity][clip-probe] missing " .. target)
  return
end
local chunk, err = load(Content:load(target), "ClipPlaneProbe")
if chunk == nil then
  print("[escape-velocity][clip-probe] load failed: " .. tostring(err))
  return
end
chunk()
print("[escape-velocity][clip-probe] entry done")
