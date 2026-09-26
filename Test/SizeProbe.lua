--[[
屏幕几何探针（诊断用，可保留）：把 View 的尺寸族打印到标记文件 + 引擎日志。
用途：把「游戏内视图坐标」换算成「引擎窗口客户区像素」，从而能用合成鼠标事件驱动游戏。
⚠️ 读取一律走 **引擎日志**（tools/level-play.ps1 就是这么读的）：`/log` 返回的是定长尾部，
   而标记文件在冷引擎/单文件入口下会落到 Test/.agent/... （2026-09-27 把仓库根污染出一个 Test/.agent/）。
]]
local Dora = require("Dora")
local Content, Path, View, App = Dora.Content, Dora.Path, Dora.View, Dora.App

-- 找项目根：**同时含 init.lua 与 game/Scene.lua** 的那条搜索路径（0 基数组，照 Test/UnitRunner.lua）
local searchPaths = Content.searchPaths
local root = nil
for i = 0, 8 do
  local p = searchPaths[i]
  if p ~= nil and Content:exist(Path(p, "init.lua")) and Content:exist(Path(p, "game", "Scene.lua")) then
    root = p
    break
  end
end
-- 三级兜底（照 Test/UnitRunner.lua）：① 单文件入口 searchPaths[0]=<proj>/Test ⇒ 上跳一级；
--   ② 项目就躺在 writablePath 下（<writablePath>/escape-velocity）。
if root == nil and searchPaths[0] ~= nil then
  local up = Path(searchPaths[0], "..")
  if Content:exist(Path(up, "init.lua")) and Content:exist(Path(up, "game", "Scene.lua")) then root = up end
end
if root == nil then
  local byWritable = Path(Content.writablePath, "escape-velocity")
  if Content:exist(Path(byWritable, "init.lua")) and Content:exist(Path(byWritable, "game", "Scene.lua")) then root = byWritable end
end
if root == nil then root = "." end

local dir = Path(root, ".agent/test-results")
if Content:exist(Path(root, ".agent")) and not Content:exist(dir) then Content:mkdir(dir) end
local marker = Path(dir, "size-probe.txt")

local L = {}
local function add(k, v) L[#L + 1] = k .. " = " .. tostring(v) end

local function try(name, fn)
  local ok, v = pcall(fn)
  if ok then add(name, v) else add(name, "ERR " .. tostring(v)) end
end

try("View.size", function() return View.size.width .. " x " .. View.size.height end)
try("View.aspectRatio", function() return View.aspectRatio end)
try("View.fieldOfView", function() return View.fieldOfView end)
try("View.scale", function() return View.scale end)
try("App.platform", function() return App.platform end)
try("App.deltaTime", function() return App.deltaTime end)
add("root", root)
add("phase", "done")
local ok = pcall(function() Content:save(marker, table.concat(L, "\n")) end)
if not ok then print("[size-probe] marker save failed (root=" .. tostring(root) .. ")") end
print("[size-probe] " .. table.concat(L, " | "))
