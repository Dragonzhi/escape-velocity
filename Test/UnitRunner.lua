--[[
单测批跑入口（DSH 维护）。

为什么存在：六个单测模块（gravity/game/leveldata/hud/trajectory/camerarig）是纯逻辑测试，
但必须在引擎内 require 才能覆盖 lualib 的真实行为；引擎侧没有现成的批跑入口，
所以用这个 Lua 入口一次跑完，把结果写进标记文件，方便反复回归。

注意：作为独立入口（runKind=file）执行时，引擎不会注入 Content/Path 等全局量
（那是 Agent 命令模式才有的），必须显式 require("Dora")；Content 的方法是冒号调用。

运行：作为 Lua 入口执行一次，产物 .agent/test-results/unit-summary.txt。
每行格式：<module> :: passed|failed checks=N failures=M（失败明细用 " | " 连接）
]]

local Dora = require("Dora")
local Content = Dora.Content
local Path = Dora.Path

-- ⚠️ searchPaths 是 **0 基**的 tolua 数组（2026-09-25 两次实测：[0]=项目根，而 [1] 可能是引擎的
--    Script 目录）—— 从 1 扫起会漏掉项目根、回退进引擎目录（FarPlaneProbe 踩过：标记文件写进引擎目录）。
-- ⚠️ 只认 init.lua 会误中引擎自带的 Script\init.lua —— 必须再加项目独有文件 game/Scene.lua 判别。
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
-- ⚠️ 2026-09-26 补：引擎**刚起来、本项目没在跑**时（例如 cli run 之后又被 /run 顶掉，
--    或者冷启动直接 /run 探针），searchPaths 可能整个是空的 —— 于是 root=nil，
--    下一行 Path(root, ...) 直接报 "argument 2 is 'nil', 'string' expected"。
--    两级兜底：① 单文件入口 searchPaths[0]=<proj>/Test ⇒ 上跳一级；
--              ② 项目就躺在 writablePath 下（<writablePath>/escape-velocity）。
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
if root == nil then
  root = searchPaths[0]
end
if root == nil then
  root = "."
end
-- 冷引擎的 searchPaths 里没有项目根 ⇒ "Assets/..." 这类相对路径会解析失败（实测），补上。
Content:addSearchPath(root)

local outDir = Path(root, ".agent/test-results")
if not Content:exist(outDir) then
  Content:mkdir(outDir)
end
local marker = Path(outDir, "unit-summary.txt")
-- 冷引擎下 root 找不到时这会写进相对路径 ⇒ 静默失败；所以先把诊断打到引擎日志（POST /log 能读到）。
print("[dsh-unit] root=" .. tostring(root)
  .. " wp=" .. tostring(Content.writablePath)
  .. " sp0=" .. tostring(searchPaths[0])
  .. " sp1=" .. tostring(searchPaths[1])
  .. " marker=" .. tostring(marker))

local lines = { "root=" .. tostring(root) }
for i = 0, 4 do
  if searchPaths[i] ~= nil then
    lines[#lines + 1] = "searchPath[" .. i .. "]=" .. tostring(searchPaths[i])
  end
end
lines[#lines + 1] = "phase=running"
Content:save(marker, table.concat(lines, "\n"))

local modules = {
  "Test.GravityTest",
  "Test.GameTest",
  "Test.LevelDataTest",
  "Test.HudTest",
  "Test.TrajectoryTest",
  "Test.CameraRigTest",
  "Test.ProgressTest",
  "Test.OpeningTest",
}

package.path = Path(root, "?.lua") .. ";" .. Path(root, "?", "init.lua") .. ";" .. package.path

local passed, failed = 0, 0
for _, name in ipairs(modules) do
  package.loaded[name] = nil
  local ok, mod = pcall(require, name)
  if not ok then
    failed = failed + 1
    lines[#lines + 1] = "FAIL " .. name .. " :: LOAD " .. tostring(mod)
  elseif type(mod) ~= "table" or type(mod.runTests) ~= "function" then
    failed = failed + 1
    lines[#lines + 1] = "FAIL " .. name .. " :: NO runTests"
  else
    local ok2, report = pcall(mod.runTests)
    if not ok2 then
      failed = failed + 1
      lines[#lines + 1] = "FAIL " .. name .. " :: ERROR " .. tostring(report)
    else
      local text = tostring(report)
      local head = text:match("^[^\n]*") or ""
      if head == "passed" then passed = passed + 1 else failed = failed + 1 end
      lines[#lines + 1] = name .. " :: " .. text:gsub("\n", " | ")
    end
  end
end
lines[#lines + 1] = string.format("SUMMARY passed=%d failed=%d total=%d", passed, failed, #modules)
lines[#lines + 1] = "phase=done"
Content:save(marker, table.concat(lines, "\n"))
print("[dsh-unit] " .. lines[#lines - 1])
