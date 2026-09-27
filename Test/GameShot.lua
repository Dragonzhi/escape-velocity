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
if root == nil then root = searchPaths[0] end
if root == nil then root = "." end
-- 冷引擎的 searchPaths 里没有项目根 ⇒ "Assets/..." 这类相对路径会解析失败（实测），补上。
Content:addSearchPath(root)

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

-- ⚠️ 引擎启动时会**自动跑一遍本项目**（开机日志里就有 "started: 6 levels ..."）——
--    那一次是在**同一个 Lua 状态**里把 "init" 放进了 package.loaded。若不清掉，
--    下面的 require("init") 会直接返回**缓存**、一行代码都不执行 ⇒ 屏幕上什么都没有、
--    截图整屏只有清屏色（2026-09-26 实测：uniq=1、mean=[26,26,26]，排查了两个小时）。
--    ⚠️ pairs 迭代中置 nil 会改表结构，先收集再删。
local stale = {}
for k in pairs(package.loaded) do
  if k == "init" or string.sub(k, 1, 5) == "game." then stale[#stale + 1] = k end
end
for i = 1, #stale do package.loaded[stale[i]] = nil end
log("cleared stale modules: " .. tostring(#stale) .. " (init=" .. tostring(package.loaded["init"]) .. ")")

-- ⚠️ 不能写 require("init")：Dora 的全局 require 是按 Content.searchPaths 顺序找模块的，
--    而冷引擎里 <proj> **不在**搜索路径里（只有 <proj>/Test 与引擎的 Script/）——
--    于是 require("init") 命中的是**引擎自带的 Script/init.lua**（返回一个表、游戏一行都不跑），
--    屏幕上什么都没有、截图整屏只有清屏色（2026-09-26 实测：uniq=1、mean=[26,26,26]）。
--    改成按**绝对路径**读文件 + load 执行，跳过模块解析这一层。
local initPath = Path(root, "init.lua")
local loader = load or loadstring
local src = Content:load(initPath)
local chunk, lerr = loader(src, "@" .. initPath)
local ok = false
if chunk == nil then
  log("init chunk failed: " .. tostring(lerr))
else
  local runOk, runErr = pcall(chunk)
  ok = runOk
  log("init run ok=" .. tostring(runOk) .. " err=" .. tostring(runErr))
end
print("[gameshot] driver ready ok=" .. tostring(ok) .. " root=" .. tostring(root))

local last = ""
local n = 0
local pendingDelay = 0
local pendingReq = ""

threadLoop(function()
  if Content:exist(reqFile) then
    local want = Content:load(reqFile)
    if want ~= nil and want ~= "" and want ~= last then
      last = want
      pendingReq = want
      
      -- 处理控制指令
      local SolarHub = package.loaded["game.SolarHub"]
      local hub = SolarHub ~= nil and SolarHub.getActiveSolarHub ~= nil and SolarHub.getActiveSolarHub() or nil

      local focusIdx = string.match(want, "focus:(%d+)")
      if focusIdx ~= nil then
        local idx = tonumber(focusIdx)
        if hub ~= nil and hub.focusMission ~= nil then
          hub.focusMission(idx)
          log("invoked focusMission(" .. tostring(idx) .. ")")
        end
        pendingDelay = 40 -- 40 帧延迟，保证镜头平滑推进到位
      elseif want == "back" then
        if hub ~= nil and hub.backToPanorama ~= nil then
          hub.backToPanorama()
          log("invoked backToPanorama()")
        end
        pendingDelay = 30
      elseif want == "launch" then
        if hub ~= nil and hub.launchCurrentMission ~= nil then
          hub.launchCurrentMission()
          log("invoked launchCurrentMission()")
        end
        pendingDelay = 40
      else
        pendingDelay = 2
      end
    end
  end

  if pendingDelay > 0 then
    pendingDelay = pendingDelay - 1
    if pendingDelay == 0 then
      n = n + 1
      local name = string.format("shot-%03d", n)
      App:saveScreenshot(Path(outDir, name))
      Content:save(doneFile, name .. " req=" .. pendingReq .. " n=" .. tostring(n) .. "\n")
      log("capture " .. name .. " <- " .. pendingReq)
    end
  end

  return false
end)
