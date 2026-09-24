--[[
离线资产生成器：用代码生成 low poly 基础几何（决策 D6）。

背景：Dora 的 TS 层没有程序化几何工厂，模型只能通过 Model3D(path) 从 glTF 加载；
且当前环境无网络，无法获取外部素材。因此这里用 Lua 的 string.pack 直接生成
合法的 glTF 2.0 文本资产（buffer 以 base64 data URI 内嵌，自包含、零外部依赖）。

运行方式（Agent 侧）：作为 Lua 入口执行一次，产物写入 Assets/Model/。

产出：
  Assets/Model/Sphere.gltf  单位球（半径 1），行星用
  Assets/Model/Ring.gltf    扁平圆环，土星环用
  Assets/Model/Probe.gltf   低多边形四面体，探测器用
]]

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64(s)
  local out = {}
  local n = #s
  local i = 1
  while i + 2 <= n do
    local a, b, c = s:byte(i), s:byte(i + 1), s:byte(i + 2)
    local v = a * 65536 + b * 256 + c
    out[#out + 1] = B64:sub(math.floor(v / 262144) % 64 + 1, math.floor(v / 262144) % 64 + 1)
      .. B64:sub(math.floor(v / 4096) % 64 + 1, math.floor(v / 4096) % 64 + 1)
      .. B64:sub(math.floor(v / 64) % 64 + 1, math.floor(v / 64) % 64 + 1)
      .. B64:sub(v % 64 + 1, v % 64 + 1)
    i = i + 3
  end
  local rem = n - i + 1
  if rem == 1 then
    local a = s:byte(i)
    out[#out + 1] = B64:sub(math.floor(a / 4) % 64 + 1, math.floor(a / 4) % 64 + 1)
      .. B64:sub((a % 4) * 16 + 1, (a % 4) * 16 + 1) .. "=="
  elseif rem == 2 then
    local a, b = s:byte(i), s:byte(i + 1)
    local v = a * 256 + b
    out[#out + 1] = B64:sub(math.floor(v / 1024) % 64 + 1, math.floor(v / 1024) % 64 + 1)
      .. B64:sub(math.floor(v / 16) % 64 + 1, math.floor(v / 16) % 64 + 1)
      .. B64:sub((v % 16) * 4 + 1, (v % 16) * 4 + 1) .. "="
  end
  return table.concat(out)
end

local function num(v)
  -- JSON 数字：避免科学计数法与 -0
  if v == 0 then return "0" end
  local s = string.format("%.6f", v)
  s = s:gsub("0+$", ""):gsub("%.$", "")
  if s == "-0" then s = "0" end
  return s
end

--[[ 写一个自包含的 glTF 文件。
  positions/normals: flat number 数组 (每 3 个一组)
  indices: flat 整数数组
]]
local function writeGltf(relPath, name, positions, normals, indices, color, root)
  local posParts, nrmParts, idxParts = {}, {}, {}
  for _, v in ipairs(positions) do posParts[#posParts + 1] = string.pack("<f", v) end
  for _, v in ipairs(normals) do nrmParts[#nrmParts + 1] = string.pack("<f", v) end
  for _, v in ipairs(indices) do idxParts[#idxParts + 1] = string.pack("<I2", v) end
  local posBin = table.concat(posParts)
  local nrmBin = table.concat(nrmParts)
  local idxBin = table.concat(idxParts)

  local vcount = #positions / 3
  local icount = #indices
  local posOff = 0
  local nrmOff = #posBin
  local idxOff = nrmOff + #nrmBin
  local total = idxOff + #idxBin

  local minV, maxV = {}, {}
  for axis = 1, 3 do
    local lo, hi = math.huge, -math.huge
    for i = axis, #positions, 3 do
      if positions[i] < lo then lo = positions[i] end
      if positions[i] > hi then hi = positions[i] end
    end
    minV[axis], maxV[axis] = lo, hi
  end

  local json = table.concat({
    '{\n  "asset": {"version": "2.0", "generator": "escape-velocity offline generator"},\n',
    '  "scene": 0,\n  "scenes": [{"nodes": [0]}],\n',
    '  "nodes": [{"mesh": 0, "name": "' .. name .. '"}],\n',
    '  "meshes": [{"name": "' .. name .. '", "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1}, "indices": 2, "material": 0}]}],\n',
    '  "materials": [{"name": "Flat", "doubleSided": true, "pbrMetallicRoughness": {"baseColorFactor": ['
      .. num(color[1]) .. ', ' .. num(color[2]) .. ', ' .. num(color[3]) .. ', 1], "metallicFactor": 0, "roughnessFactor": 0.85}}],\n',
    '  "buffers": [{"byteLength": ' .. total .. ', "uri": "data:application/octet-stream;base64,'
      .. base64(posBin .. nrmBin .. idxBin) .. '"}],\n',
    '  "bufferViews": [\n',
    '    {"buffer": 0, "byteOffset": ' .. posOff .. ', "byteLength": ' .. #posBin .. ', "target": 34962},\n',
    '    {"buffer": 0, "byteOffset": ' .. nrmOff .. ', "byteLength": ' .. #nrmBin .. ', "target": 34962},\n',
    '    {"buffer": 0, "byteOffset": ' .. idxOff .. ', "byteLength": ' .. #idxBin .. ', "target": 34963}\n',
    '  ],\n',
    '  "accessors": [\n',
    '    {"bufferView": 0, "componentType": 5126, "count": ' .. vcount .. ', "type": "VEC3", "min": ['
      .. num(minV[1]) .. ', ' .. num(minV[2]) .. ', ' .. num(minV[3]) .. '], "max": ['
      .. num(maxV[1]) .. ', ' .. num(maxV[2]) .. ', ' .. num(maxV[3]) .. ']},\n',
    '    {"bufferView": 1, "componentType": 5126, "count": ' .. vcount .. ', "type": "VEC3"},\n',
    '    {"bufferView": 2, "componentType": 5123, "count": ' .. icount .. ', "type": "SCALAR"}\n',
    '  ]\n}\n',
  })

  local path = Path(root, relPath)
  local ok = Content:save(path, json)
  print(string.format("%-28s save=%s bytes=%d verts=%d tris=%d", relPath, tostring(ok), #json, math.floor(vcount), math.floor(icount / 3)))
  return ok
end

-- 1) 单位球：均匀经纬球
local function buildSphere(SEG, RING)
  local positions, normals, indices = {}, {}, {}
  local function vert(x, y, z)
    local len = math.sqrt(x * x + y * y + z * z)
    positions[#positions + 1] = x
    positions[#positions + 1] = y
    positions[#positions + 1] = z
    normals[#normals + 1] = x / len
    normals[#normals + 1] = y / len
    normals[#normals + 1] = z / len
  end

  vert(0, 1, 0) -- 北极 = 索引 0
  for r = 1, RING - 1 do
    local phi = math.pi * r / RING
    local y = math.cos(phi)
    local rad = math.sin(phi)
    for s = 0, SEG - 1 do
      local theta = 2 * math.pi * s / SEG
      vert(rad * math.cos(theta), y, rad * math.sin(theta))
    end
  end
  local vcount = #positions / 3
  vert(0, -1, 0) -- 南极 = 索引 vcount-1

  local function idx(r, s)
    if r == 0 then return 0 end
    if r == RING then return vcount - 1 end
    return 1 + (r - 1) * SEG + (s % SEG)
  end

  for r = 0, RING - 1 do
    for s = 0, SEG - 1 do
      local a, b = idx(r, s), idx(r, s + 1)
      local c, d = idx(r + 1, s), idx(r + 1, s + 1)
      if r == 0 then
        indices[#indices + 1] = a; indices[#indices + 1] = d; indices[#indices + 1] = c
      elseif r == RING - 1 then
        indices[#indices + 1] = a; indices[#indices + 1] = b; indices[#indices + 1] = c
      else
        indices[#indices + 1] = a; indices[#indices + 1] = d; indices[#indices + 1] = c
        indices[#indices + 1] = a; indices[#indices + 1] = c; indices[#indices + 1] = b
      end
    end
  end
  return positions, normals, indices
end

-- 2) 扁平圆环（土星环）：内外半径之间的环带，双面
local function buildRing(SEG, inner, outer)
  local positions, normals, indices = {}, {}, {}
  for s = 0, SEG - 1 do
    local theta = 2 * math.pi * s / SEG
    local cx, cz = math.cos(theta), math.sin(theta)
    positions[#positions + 1] = inner * cx; positions[#positions + 1] = 0; positions[#positions + 1] = inner * cz
    positions[#positions + 1] = outer * cx; positions[#positions + 1] = 0; positions[#positions + 1] = outer * cz
    normals[#normals + 1] = 0; normals[#normals + 1] = 1; normals[#normals + 1] = 0
    normals[#normals + 1] = 0; normals[#normals + 1] = 1; normals[#normals + 1] = 0
  end
  for s = 0, SEG - 1 do
    local i0 = s * 2
    local i1 = (s * 2 + 1)
    local i2 = ((s + 1) % SEG) * 2
    local i3 = ((s + 1) % SEG) * 2 + 1
    indices[#indices + 1] = i0; indices[#indices + 1] = i2; indices[#indices + 1] = i1
    indices[#indices + 1] = i1; indices[#indices + 1] = i2; indices[#indices + 1] = i3
  end
  return positions, normals, indices
end

-- 3) 探测器：正四面体，指向 +X，简到极致
local function buildProbe()
  local a = 1.0
  local pts = {
    a, 0, 0,
    -a * 0.5, a * 0.5, 0,
    -a * 0.5, -a * 0.5, 0,
    -a * 0.5, 0, a * 0.7,
  }
  local faces = {
    { 0, 1, 3 },
    { 0, 3, 2 },
    { 0, 2, 1 },
    { 1, 2, 3 },
  }
  local positions, normals, indices = {}, {}, {}
  local function get(i)
    return pts[i * 3 + 1], pts[i * 3 + 2], pts[i * 3 + 3]
  end
  for _, f in ipairs(faces) do
    local ax, ay, az = get(f[1])
    local bx, by, bz = get(f[2])
    local cx, cy, cz = get(f[3])
    local ux, uy, uz = bx - ax, by - ay, bz - az
    local vx, vy, vz = cx - ax, cy - ay, cz - az
    local nx = uy * vz - uz * vy
    local ny = uz * vx - ux * vz
    local nz = ux * vy - uy * vx
    local nl = math.sqrt(nx * nx + ny * ny + nz * nz)
    if nl > 0 then nx, ny, nz = nx / nl, ny / nl, nz / nl end
    for _, vi in ipairs(f) do
      local x, y, z = get(vi)
      indices[#indices + 1] = #positions / 3
      positions[#positions + 1] = x; positions[#positions + 1] = y; positions[#positions + 1] = z
      normals[#normals + 1] = nx; normals[#normals + 1] = ny; normals[#normals + 1] = nz
    end
  end
  return positions, normals, indices
end

print("=== escape-velocity offline asset generator ===")

-- 入口环境下 projectDir 可能不存在，项目根取 Content.searchPaths[0]。
local root = projectDir
if root == nil or not Content:exist(Path(root, "init.ts")) then
  root = Content.searchPaths[1]
end
print("root=" .. tostring(root))

local d = Path(root, "Assets/Model")
if not Content:exist(d) then
  Content:mkdir(d)
  print("created Assets/Model")
end

local sp, sn, si = buildSphere(12, 6)
writeGltf("Assets/Model/Sphere.gltf", "Sphere", sp, sn, si, { 0.55, 0.62, 0.78 }, root)

local rp, rn, ri = buildRing(8, 1.35, 2.0)
writeGltf("Assets/Model/Ring.gltf", "Ring", rp, rn, ri, { 0.78, 0.72, 0.58 }, root)

local pp, pn, pi = buildProbe()
writeGltf("Assets/Model/Probe.gltf", "Probe", pp, pn, pi, { 0.95, 0.95, 0.95 }, root)

print("done")
