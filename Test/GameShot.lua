--[[
游戏内截图驱动器（S3.1 验收用，手写 Lua，与 UnitRunner.lua 同类）。

为什么需要：/run 一次只能跑一个入口。跑真正的 init.lua 时没有旁路可以抓帧
（引擎的 POST /command 是给内置 Agent 用的，本环境没有监听者，实测无效）。
于是这个驱动器：
  1) 先按 UnitRunner.lua 的办法找到项目根（遍历 Content.searchPaths 找含 init.lua 的目录），
     并把它塞进 package.path（单文件入口时 searchPaths[1] 可能是 <proj>/Test）；
  2) require("init") —— 跑的就是**真正的游戏代码**，不是复制品；
  3) 自己再挂一个 threadLoop，轮询 .agent/test-results/shot-request.txt：
     内容一变就 App:saveScreenshot("shot-NNN")，并把结果写进 shot-done.txt。
     外部（PowerShell + 合成鼠标）因此可以精确控制抓帧时机。

运行：POST /run {"file":"<proj>\\Test\\GameShot","asProj":false}
产出：.agent/test-results/shot-NNN.tga + shot-done.txt + gameshot.txt
]]
local Dora = require("Dora")
local App = Dora.App
local Content = Dora.Content
local Path = Dora.Path
local threadLoop = Dora.threadLoop

-- ⚠️ searchPaths 是 0 基数组、且引擎自带 Script\init.lua 会误中 —— 照 Test/UnitRunner.lua 的写法
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
if root == nil then root = searchPaths[0] end

local outDir = Path(root, ".agent/test-results")
if not Content:exist(outDir) then Content:mkdir(outDir) end
local reqFile = Path(outDir, "shot-request.txt")
local doneFile = Path(outDir, "shot-done.txt")
local logFile = Path(outDir, "gameshot.txt")

local lines = {}
local function log(s)
  lines[#lines + 1] = s
  Content:save(logFile, table.concat(lines, "\n"))
end

log("driver=GameShot root=" .. tostring(root))
log("searchPaths[1]=" .. tostring(searchPaths[1]))
log("assetsAbs=" .. tostring(Content:exist(Path(root, "Assets/Model/Planet_Mars.glb")))
  .. " assetsRel=" .. tostring(Content:exist("Assets/Model/Planet_Mars.glb"))
  .. " starShell=" .. tostring(Content:exist("Assets/Model/StarShell.gltf")))

package.path = Path(root, "?.lua") .. ";" .. Path(root, "?", "init.lua") .. ";" .. package.path

local ok, err = pcall(require, "init")
log("require init ok=" .. tostring(ok) .. " err=" .. tostring(err))
print("[gameshot] driver ready ok=" .. tostring(ok) .. " root=" .. tostring(root))

local last = ""
local n = 0
threadLoop(function()
  if Content:exist(reqFile) then
    local want = Content:load(reqFile)
    if want ~= nil and want ~= "" and want ~= last then
      last = want
      n = n + 1
      local name = string.format("shot-%03d", n)
      App:saveScreenshot(Path(outDir, name))
      Content:save(doneFile, name .. " req=" .. want .. " n=" .. tostring(n) .. "\n")
      log("capture " .. name .. " <- " .. want)
    end
  end
  return false
end)
