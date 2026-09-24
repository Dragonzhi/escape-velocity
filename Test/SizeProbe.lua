--[[
屏幕几何探针（诊断用，可保留）：把 View 的尺寸族打印到标记文件。
用途：把「游戏内视图坐标」换算成「引擎窗口客户区像素」，从而能用合成鼠标事件驱动游戏。
]]
local Dora = require("Dora")
local Content, Path, View, App = Dora.Content, Dora.Path, Dora.View, Dora.App

local root = Content.searchPaths[1]
local dir = Path(root, ".agent/test-results")
if not Content:exist(dir) then Content:mkdir(dir) end
local marker = Path(dir, "size-probe.txt")

local L = {}
local function add(k, v) L[#L + 1] = k .. " = " .. tostring(v) end

local function try(name, fn)
  local ok, v = pcall(fn)
  if ok then add(name, v) else add(name, "ERR " .. tostring(v)) end
end

try("View.size", function() return View.size.width .. " x " .. View.size.height end)
try("View.sizeInPixel", function() return View.sizeInPixel.width .. " x " .. View.sizeInPixel.height end)
try("View.windowSize", function() return View.windowSize.width .. " x " .. View.windowSize.height end)
try("View.designSize", function() return View.designSize.width .. " x " .. View.designSize.height end)
try("View.aspectRatio", function() return View.aspectRatio end)
try("View.fieldOfView", function() return View.fieldOfView end)
try("View.scale", function() return View.scale end)
try("App.platform", function() return App.platform end)
try("App.deltaTime", function() return App.deltaTime end)
add("phase", "done")
Content:save(marker, table.concat(L, "\n"))
print("[size-probe] " .. table.concat(L, " | "))
