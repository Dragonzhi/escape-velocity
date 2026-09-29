-- 场景光源绑定验收，独立于像素单灯标定。使用真实关卡 JSON 与 buildScene。
local D = require('Dora')
local C, P = D.Content, D.Path
local root
for i = 0, 8 do
  local s = C.searchPaths[i]
  if s and C:exist(P(s, 'game', 'Scene.lua')) then root = s; break end
end
if not root then root = P(C.writablePath, 'escape-velocity') end
C:addSearchPath(root)
local marker = P(root, '.agent', 'test-results', 'sun-scene-probe.txt')
C:save(marker, 'phase=running')
local Loader, Scene = require('game.LevelLoader'), require('game.Scene')
local levels = D.json.decode(C:load(P(root, 'Assets', 'Levels', 'levels.json')))
local bodies = D.json.decode(C:load(P(root, 'Assets', 'Levels', 'bodies.json')))
local lines = {}
for i, cfg in ipairs(levels.levels) do
  local lv = Loader.convertLevelJson(cfg, bodies)
  local container = D.Node3D()
  local scene = Scene.buildScene({root=container, bodies=lv.planets, visuals=lv.visuals, probeStart=lv.probeStart,
    probeScale=1, spherePath=P(root,'Assets','Model','Sphere.gltf'), ringPath=P(root,'Assets','Model','Ring.gltf'), probePath=P(root,'Assets','Model','Probe.gltf')})
  assert(scene, 'scene failed')
  assert((scene.sunLight ~= nil) == (i > 1), 'explicit Sun identity failed')
  if scene.sunLight then
    scene.syncBodies(7)
    local p, sun = scene.sunLight.position, scene.planets[1].body.position
    assert(p.x == sun.x and p.y == sun.y and p.z == sun.z, 'source not at Sun center')
    local before = {x=p.x,y=p.y,z=p.z}
    scene.syncBackdrop(D.Vec3(500,300,900),D.Vec3(200,0,100))
    p = scene.sunLight.position
    assert(p.x == before.x and p.y == before.y and p.z == before.z, 'camera moved Sun source')
    assert(scene.sunLight.range == 1800 and scene.sunLight.intensity == 500000, 'calibration not applied')
  end
  lines[#lines+1] = 'L' .. i .. ' source=' .. (scene.sunLight and 'Sun-center' or 'offscreen-sunlight') .. ' PASS'
  container:cleanup()
end
lines[#lines+1] = 'RESULT=PASS'
lines[#lines+1] = 'phase=done'
C:save(marker, table.concat(lines,'\n'))
