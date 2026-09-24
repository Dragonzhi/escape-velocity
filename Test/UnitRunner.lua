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

local searchPaths = Content.searchPaths
local root = nil
for i = 1, 8 do
  local p = searchPaths[i]
  if p ~= nil and (Content:exist(Path(p, "init.lua")) or Content:exist(Path(p, "init.ts"))) then
    root = p
    break
  end
end
if root == nil then
  root = searchPaths[1]
end

local outDir = Path(root, ".agent/test-results")
if not Content:exist(outDir) then
  Content:mkdir(outDir)
end
local marker = Path(outDir, "unit-summary.txt")

local lines = { "root=" .. tostring(root) }
for i = 1, 4 do
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
