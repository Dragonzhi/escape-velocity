-- 单点光源灰球标定：太阳两侧，距离 220 / 350 / 650，固定相机与材质。
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
local marker = P(out, 'sun-light-probe.txt')
C:save(marker, 'phase=running')
D.Director.entry:setEnvironmentMap('')
D.Director.entry:setEnvironmentIntensity(0, 0, 1) -- 第三参是曝光，0 会把直射光也压黑。
D.View.nearPlaneDistance = 0.1
D.View.farPlaneDistance = 12000
local model = D.Model3D(P(root, 'Assets', 'Model', 'Moon.glb'))
assert(model, 'missing repository sphere model')
local extent = model:getLocalBoundsMax()
local k = math.max(math.abs(extent.x), math.abs(extent.y), math.abs(extent.z))
model.scale = D.Vec3(40 / k, 40 / k, 40 / k)
local slot = 0
while true do
  local m = model:getMaterial(slot)
  if not m then break end
  m.baseColor = D.Color(0xffaaaaaa)
  m.metallic = 0
  m.roughness = 1
  slot = slot + 1
end
D.Director.entry:addChild(model)
local light = D.PointLight3D()
light.position = D.Vec3(0, 0, 0)
light.color = D.Color3(0xffffff)
light.range = 1800
D.Director.entry:addChild(light)
local camera = D.Camera3D()
D.Director:pushCamera(camera)
local settings = {0, 5.5, 50000, 200000, 500000, 1000000}
local radii = {220, 350, 650}
local cases = {}
for _, intensity in ipairs(settings) do
  for _, radius in ipairs(radii) do
    for _, side in ipairs({-1, 1}) do
      cases[#cases + 1] = {intensity=intensity, radius=radius, side=side}
    end
  end
end
for _, intensity in ipairs({0, 500, 2000, 4000}) do
  for _, radius in ipairs({17, 30, 55}) do
    for _, side in ipairs({-1, 1}) do
      cases[#cases + 1] = {intensity=intensity, radius=radius, side=side, mini=true}
    end
  end
end
local index, frame = 1, 0
local lines = {'range=1800', 'environment=0', 'directional=0'}
local function setup()
  local c = cases[index]
  local x = c.radius * c.side
  local size = c.mini and 3 or 40
  model.scale = D.Vec3(size / k, size / k, size / k)
  model.position = D.Vec3(x, 0, 0)
  camera:lookAt(D.Vec3(x, size * 1.375, size * 4.75), D.Vec3(x, 0, 0))
  light.intensity = c.intensity
  light.range = c.mini and 700 or 1800
end
setup()
D.threadLoop(function()
  frame = frame + 1
  if frame == 12 then
    local c = cases[index]
    local name = (c.mini and 'sun-light-mini-I' or 'sun-light-I') .. tostring(c.intensity) .. '-R' .. c.radius .. (c.side < 0 and '-left' or '-right')
    D.App:saveScreenshot(P(out, name .. '.tga'))
    lines[#lines + 1] = name
  end
  if frame >= 20 then
    index = index + 1
    if index > #cases then
      lines[#lines + 1] = 'phase=done'
      C:save(marker, table.concat(lines, '\n'))
      return true
    end
    frame = 0
    setup()
  end
  return false
end)
