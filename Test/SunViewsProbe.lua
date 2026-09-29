-- 最终光照视觉回归：直接运行真实 init，经开场自然进入沙盘，不改存档格式。
local D = require('Dora')
local C, P = D.Content, D.Path
local root
for i = 0, 8 do
  local s = C.searchPaths[i]
  if s and C:exist(P(s, 'game', 'Scene.lua')) then root = s; break end
end
if not root then root = P(C.writablePath, 'escape-velocity') end
C:addSearchPath(root)
local out = P(root, '.agent', 'test-results')
local marker = P(out, 'sun-views-probe.txt')
C:save(marker, 'phase=running')
C:save(P(out, 'enter-request.txt'), 'intro')
local chunk = assert(load(C:load(P(root, 'Test', 'GameShot.lua')), '@SunViews/GameShot'))
chunk()
C:remove(P(out, 'enter-request.txt')) -- init 已读取，避免验收请求劫持下一次启动。
local frame, shots = 0, {}
local function capture(name)
  D.App:saveScreenshot(P(out, name .. '.tga'))
  shots[#shots + 1] = name
end
D.threadLoop(function()
  frame = frame + 1
  if frame == 130 then capture('sun-opening-wide') end
  if frame == 470 then capture('sun-opening-earth') end
  if frame == 640 then capture('sun-hub-wide') end
  if frame == 680 then
    local hub = require('game.SolarHub').getActiveSolarHub()
    assert(hub and hub.visible(), 'opening did not naturally enter hub')
    hub.focusMission(0)
  end
  if frame == 800 then capture('sun-hub-earth') end
  if frame == 820 then
    shots[#shots + 1] = 'RESULT=PASS'
    shots[#shots + 1] = 'phase=done'
    C:save(marker, table.concat(shots, '\n'))
    return true
  end
  return false
end)
