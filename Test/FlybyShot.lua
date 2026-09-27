--[[
S3.17 掠过瞬间截图驱动器（手写 Lua，与 Test/GameShot.lua 同类；**不碰 game/ 任何文件**）。

为什么单写一个（GameShot 不够用）：GameShot 是「等外部写 shot-request.txt 再抓一帧」，
而掠过慢动作窗口只有 ~0.6 **真实秒**（L3：slow-mo engage t=5.55 → 抵达结算 t=5.85 模拟秒，
0.5× 实时）—— 外部轮询 /log 再写请求，等请求被轮询到窗口已经过去了。这个驱动器**自己判时刻**：

  1) 按 GameShot.lua 的办法找项目根（遍历 Content.searchPaths + 两级兜底 + addSearchPath）；
  2) 自己写 .agent/test-results/enter-request.txt = "3@120:15.045:19.966"
     （L3 木星，deg=53/power=0.4 的那发弹：vx=15.045 / vy=19.966 / t0=0。
      Node 侧用同一套 Gravity 公式复算：木星阈值 23.15、进入阈值 t=5.53、
      goalIndex=702（容差 17.63）⇒ 飞行在 t=5.85 收束 ⇒ 慢动作窗口 5.53–5.85）；
  3) 按绝对路径 load + 执行 init.lua（跑**真正的游戏代码**，不复制、不 require("init")）；
  4) 自己挂 threadLoop 数帧：enter-request 的第 F 帧自动发射，而本驱动器与 init 的两个
     threadLoop 每帧各跑一次 ⇒ **驱动器数到第 F 帧就是发射那一刻**（不用猜帧率）；
  5) 从 发射+1.6s 到 发射+4.0s 每 0.1s 抓一帧（App:saveScreenshot，绝对路径），
     覆盖「宽取景接近 → slow-mo engage → 特写 → 抵达结算」整段；
  6) 写 flyby.txt（每帧的 App.elapsedTime / 距发射秒数，用来和引擎日志对时）
     + flyby-done.txt 标记。

运行：POST /run {"file":"<proj>\\Test\\FlybyShot","asProj":false}
产出：.agent/test-results/flyby-NNN.tga + flyby.txt + flyby-done.txt
]]
local Dora = require("Dora")
local App = Dora.App
local Content = Dora.Content
local Path = Dora.Path
local threadLoop = Dora.threadLoop

-- enter-request 规格（与下面写进文件的一致）：L3、第 120 帧以 (15.045, 19.966) 发射
local LaunchFrame = 120
local VX = 15.045
local VY = 19.966

-- 连拍参数（真实秒，相对发射那一刻）
local BurstStart = 1.6
local BurstEnd = 4.0
local Interval = 0.1

-- ⚠️ searchPaths 是 0 基数组、且引擎自带 Script\init.lua 会误中 —— 照 Test/GameShot.lua
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
if root == nil then root = searchPaths[0] end
if root == nil then root = "." end
-- 冷引擎的 searchPaths 里没有项目根 ⇒ "Assets/..." 这类相对路径会解析失败（实测），补上
Content:addSearchPath(root)

local outDir = Path(root, ".agent/test-results")
if not Content:exist(outDir) then Content:mkdir(outDir) end
local reqFile = Path(outDir, "enter-request.txt")
local doneFile = Path(outDir, "flyby-done.txt")
local logFile = Path(outDir, "flyby.txt")

local lines = {}
local function log(s)
  lines[#lines + 1] = s
  Content:save(logFile, table.concat(lines, "\n"))
end

-- 清掉上一轮的帧与标记（Content:remove 返回 bool，失败不致命）
for i = 1, 60 do
  local old = Path(outDir, string.format("flyby-%03d.tga", i))
  if Content:exist(old) then Content:remove(old) end
end
if Content:exist(doneFile) then Content:remove(doneFile) end

-- 1) 自己写 enter-request（init 只在启动时读一次；**读过的文件会劫持下一次启动**，跑完即删）
local spec = "3@" .. tostring(LaunchFrame) .. ":" .. tostring(VX) .. ":" .. tostring(VY)
Content:save(reqFile, spec)
log("driver=FlybyShot root=" .. tostring(root))
log("enter-request=" .. spec)
log("view=" .. tostring(App.visualWidth) .. "x" .. tostring(App.visualHeight))

package.path = Path(root, "?.lua") .. ";" .. Path(root, "?", "init.lua") .. ";" .. package.path

-- 清掉可能被缓存的前一次 init / game.* 模块（照 GameShot 的坑：不清就跑的是旧代码）
local stale = {}
for k in pairs(package.loaded) do
  if k == "init" or string.sub(k, 1, 5) == "game." then stale[#stale + 1] = k end
end
for i = 1, #stale do package.loaded[stale[i]] = nil end
log("cleared stale modules: " .. tostring(#stale))

-- 2) 按绝对路径 load + 执行 init.lua（跳过 require 的模块解析，照 GameShot 的坑）
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
-- enter-request 已被 init 读走，立刻删掉（否则它会劫持下一次引擎启动）
if Content:exist(reqFile) then Content:remove(reqFile) end
log("enter-request removed=" .. tostring(not Content:exist(reqFile)))

-- 3) 数帧 + 连拍
local frames = 0
local acc = 0
local launchAcc = -1
local launchElapsed = -1
local nextShot = -1
local n = 0
local saved = 0
local finished = false
local dtSum = 0
threadLoop(function()
  frames = frames + 1
  acc = acc + App.deltaTime
  dtSum = dtSum + App.deltaTime
  if launchAcc < 0 and frames >= LaunchFrame then
    launchAcc = acc
    launchElapsed = App.elapsedTime
    nextShot = BurstStart
    log(string.format("launch frame=%d acc=%.3f appElapsed=%.3f avgDt=%.4f", frames, acc, App.elapsedTime, dtSum / frames))
  end
  if launchAcc >= 0 and not finished then
    local since = acc - launchAcc
    if since >= BurstEnd then
      finished = true
      Content:save(doneFile, "phase=done shots=" .. tostring(saved)
        .. " launchAcc=" .. string.format("%.3f", launchAcc)
        .. " launchAppElapsed=" .. string.format("%.3f", launchElapsed) .. "\n")
      log("burst done shots=" .. tostring(saved))
    elseif since >= nextShot then
      nextShot = nextShot + Interval
      n = n + 1
      local name = string.format("flyby-%03d", n)
      App:saveScreenshot(Path(outDir, name))
      saved = saved + 1
      log(string.format("shot %s sinceLaunch=%.3f appElapsed=%.3f", name, since, App.elapsedTime))
    end
  end
  -- 兜底：半天没等到发射（init 没跑起来 / 没进关）也要写标记，别让外部干等
  if launchAcc < 0 and frames > 1800 and not finished then
    finished = true
    Content:save(doneFile, "phase=error reason=no-launch frames=" .. tostring(frames) .. "\n")
    log("no launch detected after " .. tostring(frames) .. " frames")
  end
  return false
end)

print("[flyby] driver ready ok=" .. tostring(ok) .. " root=" .. tostring(root))
