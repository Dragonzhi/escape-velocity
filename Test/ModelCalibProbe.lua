-- [ts]: ModelCalibProbe.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 24
local App = ____Dora.App -- 24
local Camera3D = ____Dora.Camera3D -- 24
local Color = ____Dora.Color -- 24
local Color3 = ____Dora.Color3 -- 24
local Content = ____Dora.Content -- 24
local Director = ____Dora.Director -- 24
local Model3D = ____Dora.Model3D -- 24
local Path = ____Dora.Path -- 24
local Vec3 = ____Dora.Vec3 -- 24
local View = ____Dora.View -- 24
local threadLoop = ____Dora.threadLoop -- 24
local ____Projection = require("game.Projection") -- 25
local FLIP_Y = ____Projection.FLIP_Y -- 25
local HANDEDNESS = ____Projection.HANDEDNESS -- 25
local project = ____Projection.project -- 25
local ____Vision = require("Test.Vision") -- 26
local asciiMap = ____Vision.asciiMap -- 26
local luminanceAt = ____Vision.luminanceAt -- 26
local parseTga = ____Vision.parseTga -- 26
local searchPaths = Content.searchPaths -- 31
local projRoot = searchPaths[1] -- 32
local rootIdx = 0 -- 33
do -- 33
	local i = 0 -- 34
	while i < 8 do -- 34
		if i >= #searchPaths then -- 34
			break -- 35
		end -- 35
		local p = searchPaths[i + 1] -- 36
		if Content:exist(Path(p, "init.lua")) or Content:exist(Path(p, "init.ts")) then -- 36
			projRoot = p -- 38
			rootIdx = i -- 39
			break -- 40
		end -- 40
		i = i + 1 -- 34
	end -- 34
end -- 34
local assetDir = Path(projRoot, "Assets", "Model") -- 43
local outDir = Path(projRoot, ".agent", "test-results") -- 44
if not Content:exist(outDir) then -- 44
	Content:mkdir(outDir) -- 45
end -- 45
local scaleMarker = Path(outDir, "s31-scale.txt") -- 46
local orientMarker = Path(outDir, "s31-orient.txt") -- 47
local scaleLines = {} -- 49
local orientLines = {} -- 50
local function flushScale() -- 51
	Content:save( -- 51
		scaleMarker, -- 51
		table.concat(scaleLines, "\n") -- 51
	) -- 51
end -- 51
local function flushOrient() -- 52
	Content:save( -- 52
		orientMarker, -- 52
		table.concat(orientLines, "\n") -- 52
	) -- 52
end -- 52
scaleLines[#scaleLines + 1] = "== search paths ==" -- 54
do -- 54
	local i = 0 -- 55
	while i < 4 do -- 55
		if i >= #searchPaths then -- 55
			break -- 56
		end -- 56
		scaleLines[#scaleLines + 1] = (("sp[" .. tostring(i)) .. "]=") .. searchPaths[i + 1] -- 57
		i = i + 1 -- 55
	end -- 55
end -- 55
scaleLines[#scaleLines + 1] = (((("projRoot=" .. projRoot) .. " (index ") .. tostring(rootIdx)) .. ")  assets=") .. assetDir -- 59
scaleLines[#scaleLines + 1] = (("assetAbsExist=" .. tostring(Content:exist(Path(assetDir, "Planet_Mars.glb")))) .. " assetRelExist=") .. tostring(Content:exist("Assets/Model/Planet_Mars.glb")) -- 60
flushScale() -- 62
local function makeSilhouette(fileName) -- 71
	local abs = Path(assetDir, fileName) -- 72
	local model = Model3D(abs) -- 73
	local usedAbs = true -- 74
	if model == nil then -- 74
		model = Model3D("Assets/Model/" .. fileName) -- 76
		usedAbs = false -- 77
	end -- 77
	if model == nil then -- 77
		return {model = nil, mats = 0, usedAbs = usedAbs} -- 79
	end -- 79
	local mats = 0 -- 80
	while mats < 64 do -- 80
		local mat = model:getMaterial(mats) -- 82
		if mat == nil then -- 82
			break -- 83
		end -- 83
		mat.baseColor = Color(255, 255, 255, 255) -- 84
		mat.emissive = Color3(3407735) -- 85
		mats = mats + 1 -- 86
	end -- 86
	return {model = model, mats = mats, usedAbs = usedAbs} -- 88
end -- 71
--- 两遍扫描：先按“行/列里至少 minRun 个亮像素”筛掉孤立噪点（星空壳的星点、残留节点），
-- 再在筛出的矩形里统计面积与重心。返回 raw 极值便于观察筛选效果。
local function scanRect(img, x0, x1, y0, y1, thr, minRun) -- 104
	local ax = math.max( -- 105
		0, -- 105
		math.floor(x0) -- 105
	) -- 105
	local bx = math.min( -- 106
		img.width - 1, -- 106
		math.ceil(x1) -- 106
	) -- 106
	local ay = math.max( -- 107
		0, -- 107
		math.floor(y0) -- 107
	) -- 107
	local by = math.min( -- 108
		img.height - 1, -- 108
		math.ceil(y1) -- 108
	) -- 108
	local w = bx - ax + 1 -- 109
	local h = by - ay + 1 -- 110
	if w <= 0 or h <= 0 then -- 110
		return nil -- 111
	end -- 111
	local colCount = {} -- 112
	do -- 112
		local i = 0 -- 113
		while i < w do -- 113
			colCount[#colCount + 1] = 0 -- 113
			i = i + 1 -- 113
		end -- 113
	end -- 113
	local rowCount = {} -- 114
	do -- 114
		local i = 0 -- 115
		while i < h do -- 115
			rowCount[#rowCount + 1] = 0 -- 115
			i = i + 1 -- 115
		end -- 115
	end -- 115
	local rawMinX = -1 -- 116
	local rawMaxX = -1 -- 116
	local rawMinY = -1 -- 116
	local rawMaxY = -1 -- 116
	local yy = ay -- 117
	while yy <= by do -- 117
		local xx = ax -- 119
		while xx <= bx do -- 119
			if luminanceAt(img, xx, yy) > thr then -- 119
				local ____colCount_0, ____temp_1 = colCount, xx - ax + 1 -- 119
				____colCount_0[____temp_1] = ____colCount_0[____temp_1] + 1 -- 122
				local ____rowCount_2, ____temp_3 = rowCount, yy - ay + 1 -- 122
				____rowCount_2[____temp_3] = ____rowCount_2[____temp_3] + 1 -- 123
				if rawMinX < 0 or xx < rawMinX then -- 123
					rawMinX = xx -- 124
				end -- 124
				if rawMaxX < 0 or xx > rawMaxX then -- 124
					rawMaxX = xx -- 125
				end -- 125
				if rawMinY < 0 or yy < rawMinY then -- 125
					rawMinY = yy -- 126
				end -- 126
				if rawMaxY < 0 or yy > rawMaxY then -- 126
					rawMaxY = yy -- 127
				end -- 127
			end -- 127
			xx = xx + 1 -- 129
		end -- 129
		yy = yy + 1 -- 131
	end -- 131
	if rawMinX < 0 then -- 131
		return nil -- 133
	end -- 133
	local minX = -1 -- 134
	local maxX = -1 -- 134
	local minY = -1 -- 134
	local maxY = -1 -- 134
	do -- 134
		local i = 0 -- 135
		while i < w do -- 135
			if colCount[i + 1] >= minRun then -- 135
				if minX < 0 then -- 135
					minX = i + ax -- 136
				end -- 136
				maxX = i + ax -- 136
			end -- 136
			i = i + 1 -- 135
		end -- 135
	end -- 135
	do -- 135
		local i = 0 -- 138
		while i < h do -- 138
			if rowCount[i + 1] >= minRun then -- 138
				if minY < 0 then -- 138
					minY = i + ay -- 139
				end -- 139
				maxY = i + ay -- 139
			end -- 139
			i = i + 1 -- 138
		end -- 138
	end -- 138
	if minX < 0 or minY < 0 then -- 138
		return nil -- 141
	end -- 141
	local sumX = 0 -- 142
	local sumY = 0 -- 142
	local count = 0 -- 142
	yy = minY -- 143
	while yy <= maxY do -- 143
		local xx = minX -- 145
		while xx <= maxX do -- 145
			if luminanceAt(img, xx, yy) > thr then -- 145
				count = count + 1 -- 147
				sumX = sumX + xx -- 147
				sumY = sumY + yy -- 147
			end -- 147
			xx = xx + 1 -- 148
		end -- 148
		yy = yy + 1 -- 150
	end -- 150
	if count == 0 then -- 150
		return nil -- 152
	end -- 152
	return { -- 153
		minX = minX, -- 154
		maxX = maxX, -- 154
		minY = minY, -- 154
		maxY = maxY, -- 154
		count = count, -- 154
		meanX = sumX / count, -- 155
		meanY = sumY / count, -- 155
		rawMinX = rawMinX, -- 156
		rawMaxX = rawMaxX, -- 156
		rawMinY = rawMinY, -- 156
		rawMaxY = rawMaxY -- 156
	} -- 156
end -- 104
local function readBounds(fileName) -- 165
	local sil = makeSilhouette(fileName) -- 166
	local b = { -- 167
		ok = false, -- 167
		minX = 0, -- 167
		maxX = 0, -- 167
		minY = 0, -- 167
		maxY = 0, -- 167
		minZ = 0, -- 167
		maxZ = 0, -- 167
		mats = sil.mats, -- 167
		scaleDependent = false -- 167
	} -- 167
	if sil.model == nil then -- 167
		return b -- 168
	end -- 168
	local m = sil.model -- 169
	do -- 169
		local function ____catch(e) -- 169
			b.ok = false -- 180
		end -- 180
		local ____try, ____hasReturned = pcall(function() -- 180
			local lo = m:getLocalBoundsMin() -- 171
			local hi = m:getLocalBoundsMax() -- 172
			b.minX = lo.x -- 173
			b.maxX = hi.x -- 173
			b.minY = lo.y -- 173
			b.maxY = hi.y -- 173
			b.minZ = lo.z -- 173
			b.maxZ = hi.z -- 173
			b.ok = true -- 174
			m.scale = Vec3(3, 3, 3) -- 175
			local hi3 = m:getLocalBoundsMax() -- 176
			b.scaleDependent = math.abs(hi3.x - b.maxX) > 0.000001 -- 177
			m.scale = Vec3(1, 1, 1) -- 178
		end) -- 178
		if not ____try then -- 178
			____catch(____hasReturned) -- 178
		end -- 178
	end -- 178
	m.visible = false -- 184
	return b -- 185
end -- 165
local fileList = { -- 188
	"Sphere.gltf", -- 189
	"Planet_Earth.glb", -- 189
	"Planet_Mars.glb", -- 189
	"Planet_Venus.glb", -- 189
	"Planet_Jupiter.glb", -- 189
	"Planet_Saturn.glb", -- 190
	"Planet_Neptune.glb", -- 190
	"Probe.gltf", -- 190
	"Probe_Voyager_v1.glb", -- 190
	"Probe_Voyager.glb", -- 190
	"StarShell.gltf", -- 191
	"StarShellBright.gltf" -- 191
} -- 191
local boundsMap = {} -- 193
scaleLines[#scaleLines + 1] = "" -- 195
scaleLines[#scaleLines + 1] = "== 口径① 模型空间包围盒（unit scale，模型单位）==" -- 196
scaleLines[#scaleLines + 1] = "file  x[min,max]  y[min,max]  z[min,max]  halfX/halfY/halfZ  mats  localBoundsScaleDependent" -- 197
do -- 197
	local i = 0 -- 198
	while i < #fileList do -- 198
		do -- 198
			local b = readBounds(fileList[i + 1]) -- 199
			boundsMap[#boundsMap + 1] = b -- 200
			if not b.ok then -- 200
				scaleLines[#scaleLines + 1] = fileList[i + 1] .. "  BOUNDS_UNAVAILABLE" -- 201
				goto __continue49 -- 201
			end -- 201
			scaleLines[#scaleLines + 1] = ((((((((((((((((((((((((fileList[i + 1] .. "  x[") .. __TS__NumberToFixed(b.minX, 4)) .. ",") .. __TS__NumberToFixed(b.maxX, 4)) .. "]") .. " y[") .. __TS__NumberToFixed(b.minY, 4)) .. ",") .. __TS__NumberToFixed(b.maxY, 4)) .. "]") .. " z[") .. __TS__NumberToFixed(b.minZ, 4)) .. ",") .. __TS__NumberToFixed(b.maxZ, 4)) .. "]") .. "  half=") .. __TS__NumberToFixed((b.maxX - b.minX) / 2, 4)) .. "/") .. __TS__NumberToFixed((b.maxY - b.minY) / 2, 4)) .. "/") .. __TS__NumberToFixed((b.maxZ - b.minZ) / 2, 4)) .. "  mats=") .. __TS__NumberToFixed(b.mats, 0)) .. "  ") .. tostring(b.scaleDependent) -- 202
		end -- 202
		::__continue49:: -- 202
		i = i + 1 -- 198
	end -- 198
end -- 198
flushScale() -- 209
local vw = View.size.width -- 214
local vh = View.size.height -- 215
local fovY = View.fieldOfView -- 216
local aspect = View.aspectRatio -- 217
local tanHalf = math.tan(fovY * math.pi / 360) -- 218
scaleLines[#scaleLines + 1] = "" -- 220
scaleLines[#scaleLines + 1] = "== viewport ==" -- 221
scaleLines[#scaleLines + 1] = (((((((("view=" .. __TS__NumberToFixed(vw, 0)) .. "x") .. __TS__NumberToFixed(vh, 0)) .. " aspect=") .. __TS__NumberToFixed(aspect, 4)) .. " fovY=") .. __TS__NumberToFixed(fovY, 2)) .. " tanHalf=") .. __TS__NumberToFixed(tanHalf, 6) -- 222
local planetNames = { -- 224
	"Planet_Mars", -- 224
	"Planet_Venus", -- 224
	"Planet_Jupiter", -- 224
	"Planet_Saturn", -- 224
	"Planet_Neptune" -- 224
} -- 224
local rowLabel = {"Sphere(REF r=1)"} -- 225
do -- 225
	local i = 0 -- 226
	while i < #planetNames do -- 226
		rowLabel[#rowLabel + 1] = planetNames[i + 1] -- 226
		i = i + 1 -- 226
	end -- 226
end -- 226
local rowSpacing = 5 -- 228
local rowCount = #planetNames + 1 -- 229
local halfSpanWorld = (rowCount - 1) / 2 * rowSpacing + 3.4 -- 230
local camDist = halfSpanWorld / (tanHalf * aspect) * 1.06 -- 231
local ppwFov = vh / 2 / (camDist * tanHalf) -- 232
scaleLines[#scaleLines + 1] = (((((("row=" .. __TS__NumberToFixed(rowCount, 0)) .. " spacing=") .. __TS__NumberToFixed(rowSpacing, 2)) .. " camDist=") .. __TS__NumberToFixed(camDist, 2)) .. " pxPerWorldUnit(由 fov 推算)=") .. __TS__NumberToFixed(ppwFov, 3) -- 234
local rowNodes = {} -- 237
local rowX = {} -- 238
do -- 238
	local i = 0 -- 239
	while i < rowCount do -- 239
		do -- 239
			local fileName = i == 0 and "Sphere.gltf" or planetNames[i] .. ".glb" -- 240
			local sil = makeSilhouette(fileName) -- 241
			if sil.model == nil then -- 241
				scaleLines[#scaleLines + 1] = "LOAD_FAIL " .. rowLabel[i + 1] -- 242
				goto __continue54 -- 242
			end -- 242
			local wx = (i - (rowCount - 1) / 2) * rowSpacing -- 243
			sil.model.position = Vec3(wx, 0, 0) -- 244
			sil.model.scale = Vec3(1, 1, 1) -- 245
			rowX[#rowX + 1] = wx -- 246
			rowNodes[#rowNodes + 1] = sil.model -- 247
			Director.entry:addChild(sil.model) -- 248
		end -- 248
		::__continue54:: -- 248
		i = i + 1 -- 239
	end -- 239
end -- 239
local camRow = Camera3D() -- 251
camRow:lookAt( -- 252
	Vec3(0, 0, camDist), -- 252
	Vec3(0, 0, 0) -- 252
) -- 252
Director:pushCamera(camRow) -- 253
local camViewRow = { -- 255
	eye = {x = 0, y = 0, z = camDist}, -- 256
	target = {x = 0, y = 0, z = 0}, -- 257
	up = {x = 0, y = 1, z = 0}, -- 258
	fovYDeg = fovY, -- 259
	aspect = aspect, -- 260
	viewW = vw, -- 261
	viewH = vh -- 262
} -- 262
local rowPx = {} -- 265
local rowPy = {} -- 266
do -- 266
	local i = 0 -- 267
	while i < #rowX do -- 267
		local pr = project({x = rowX[i + 1], y = 0, z = 0}, camViewRow, HANDEDNESS, FLIP_Y) -- 268
		if pr == nil then -- 268
			rowPx[#rowPx + 1] = vw / 2 -- 269
			rowPy[#rowPy + 1] = vh / 2 -- 269
		else -- 269
			rowPx[#rowPx + 1] = vw / 2 + pr.x -- 270
			rowPy[#rowPy + 1] = vh / 2 - pr.y -- 270
		end -- 270
		i = i + 1 -- 267
	end -- 267
end -- 267
scaleLines[#scaleLines + 1] = "projected centers(px)=" .. table.concat( -- 272
	__TS__ArrayMap( -- 272
		rowPx, -- 272
		function(____, v) return __TS__NumberToFixed(v, 1) end -- 272
	), -- 272
	", " -- 272
) -- 272
flushScale() -- 273
local probeLong = 2 -- 278
do -- 278
	local i = 0 -- 279
	while i < #fileList do -- 279
		do -- 279
			if fileList[i + 1] ~= "Probe.gltf" and fileList[i + 1] ~= "Probe_Voyager_v1.glb" then -- 279
				goto __continue62 -- 280
			end -- 280
			local b = boundsMap[i + 1] -- 281
			if not b.ok then -- 281
				goto __continue62 -- 282
			end -- 282
			local l = math.max(b.maxX - b.minX, b.maxY - b.minY, b.maxZ - b.minZ) -- 283
			if l > probeLong then -- 283
				probeLong = l -- 284
			end -- 284
		end -- 284
		::__continue62:: -- 284
		i = i + 1 -- 279
	end -- 279
end -- 279
local SP = math.max(3.2, probeLong * 1.2) -- 286
local rowR = math.max(3, probeLong * 0.9) -- 287
local markBig = 0.9 -- 288
local markSmall = 0.45 -- 289
local markX = 1.2 * SP + 3.2 -- 290
local halfWc = markX + markBig + 0.5 -- 291
local halfHc = rowR + probeLong * 0.7 + 0.5 -- 292
local camDistC = math.max(halfWc / (tanHalf * aspect), halfHc / tanHalf) * 1.08 -- 293
local ppwC = vh / 2 / (camDistC * tanHalf) -- 294
orientLines[#orientLines + 1] = "== search paths ==" -- 296
orientLines[#orientLines + 1] = ((("projRoot=" .. projRoot) .. " (index ") .. tostring(rootIdx)) .. ")" -- 297
orientLines[#orientLines + 1] = "== viewport ==" -- 298
orientLines[#orientLines + 1] = (((((("view=" .. __TS__NumberToFixed(vw, 0)) .. "x") .. __TS__NumberToFixed(vh, 0)) .. " aspect=") .. __TS__NumberToFixed(aspect, 4)) .. " fovY=") .. __TS__NumberToFixed(fovY, 2) -- 299
orientLines[#orientLines + 1] = (((((((("probeLongestDim(包围盒)=" .. __TS__NumberToFixed(probeLong, 3)) .. " => 列间距 1.2*SP=") .. __TS__NumberToFixed(1.2 * SP, 2)) .. " 行距 R=") .. __TS__NumberToFixed(rowR, 2)) .. " camDist=") .. __TS__NumberToFixed(camDistC, 2)) .. " pxPerWorldUnit=") .. __TS__NumberToFixed(ppwC, 3) -- 300
orientLines[#orientLines + 1] = "" -- 304
orientLines[#orientLines + 1] = "== angleY 世界映射（数值：旧 Probe.gltf 四面体，顶点在局部 +X）==" -- 305
local tetraRef = makeSilhouette("Probe.gltf") -- 306
if tetraRef.model ~= nil then -- 306
	local tm = tetraRef.model -- 308
	tm.position = Vec3(0, 0, 0) -- 309
	tm.scale = Vec3(1, 1, 1) -- 310
	local yaws = {0, 90, 180, 270} -- 311
	do -- 311
		local i = 0 -- 312
		while i < #yaws do -- 312
			tm.angleY = yaws[i + 1] -- 313
			do -- 313
				local function ____catch(e) -- 313
					orientLines[#orientLines + 1] = ("yaw=" .. __TS__NumberToFixed(yaws[i + 1], 0)) .. "  WORLD_BOUNDS_UNAVAILABLE" -- 322
				end -- 322
				local ____try, ____hasReturned = pcall(function() -- 322
					local lo = tm:getWorldBoundsMin() -- 315
					local hi = tm:getWorldBoundsMax() -- 316
					orientLines[#orientLines + 1] = ((((((((((((((("yaw=" .. __TS__NumberToFixed(yaws[i + 1], 0)) .. "  world x[") .. __TS__NumberToFixed(lo.x, 3)) .. ",") .. __TS__NumberToFixed(hi.x, 3)) .. "]") .. " y[") .. __TS__NumberToFixed(lo.y, 3)) .. ",") .. __TS__NumberToFixed(hi.y, 3)) .. "]") .. " z[") .. __TS__NumberToFixed(lo.z, 3)) .. ",") .. __TS__NumberToFixed(hi.z, 3)) .. "]" -- 317
				end) -- 317
				if not ____try then -- 317
					____catch(____hasReturned) -- 317
				end -- 317
			end -- 317
			i = i + 1 -- 312
		end -- 312
	end -- 312
	tm.visible = false -- 325
end -- 325
local yawCols = {0, 180, 90} -- 331
local grid = {} -- 332
do -- 332
	local c = 0 -- 333
	while c < #yawCols do -- 333
		local wx = (c - 1) * 1.2 * SP -- 334
		grid[#grid + 1] = { -- 335
			label = "TETRA yaw" .. __TS__NumberToFixed(yawCols[c + 1], 0), -- 335
			wx = wx, -- 335
			wz = -rowR, -- 335
			yaw = yawCols[c + 1], -- 335
			scale = 1, -- 335
			file = "Probe.gltf" -- 335
		} -- 335
		grid[#grid + 1] = { -- 336
			label = "V1 yaw" .. __TS__NumberToFixed(yawCols[c + 1], 0), -- 336
			wx = wx, -- 336
			wz = rowR, -- 336
			yaw = yawCols[c + 1], -- 336
			scale = 1, -- 336
			file = "Probe_Voyager_v1.glb" -- 336
		} -- 336
		c = c + 1 -- 333
	end -- 333
end -- 333
grid[#grid + 1] = { -- 338
	label = "MARK_BIG(+X)", -- 338
	wx = markX, -- 338
	wz = 0, -- 338
	yaw = 0, -- 338
	scale = markBig, -- 338
	file = "Sphere.gltf" -- 338
} -- 338
grid[#grid + 1] = { -- 339
	label = "MARK_SMALL(-X)", -- 339
	wx = -markX, -- 339
	wz = 0, -- 339
	yaw = 0, -- 339
	scale = markSmall, -- 339
	file = "Sphere.gltf" -- 339
} -- 339
orientLines[#orientLines + 1] = "" -- 341
orientLines[#orientLines + 1] = "== 布局 ==" -- 342
orientLines[#orientLines + 1] = ("  俯视相机：eye=(0," .. __TS__NumberToFixed(camDistC, 1)) .. ",0.001) target=(0,0,0) up=(0,1,0)" -- 343
orientLines[#orientLines + 1] = (((("  z=-R 行(z=" .. __TS__NumberToFixed(-rowR, 2)) .. ")：TETRA yaw0/180/90 @x=-") .. __TS__NumberToFixed(1.2 * SP, 2)) .. "/0/+") .. __TS__NumberToFixed(1.2 * SP, 2) -- 344
orientLines[#orientLines + 1] = (((("  z=+R 行(z=+" .. __TS__NumberToFixed(rowR, 2)) .. ")：V1    yaw0/180/90 @x=-") .. __TS__NumberToFixed(1.2 * SP, 2)) .. "/0/+") .. __TS__NumberToFixed(1.2 * SP, 2) -- 345
orientLines[#orientLines + 1] = ((((((("  标记球：Sphere 半径 " .. __TS__NumberToFixed(markBig, 2)) .. " @x=+") .. __TS__NumberToFixed(markX, 2)) .. "（+X 侧，大）与 ") .. __TS__NumberToFixed(markSmall, 2)) .. " @x=-") .. __TS__NumberToFixed(markX, 2)) .. "（-X 侧，小）" -- 346
orientLines[#orientLines + 1] = "  判读：大标记球在屏幕哪一侧 ⇒ 那一侧的世界 x 为 +X；两行靠面积区分（V1 行面积远大于 TETRA 行）" -- 347
flushOrient() -- 348
local gridNodes = {} -- 350
local gridKeep = {} -- 351
do -- 351
	local i = 0 -- 352
	while i < #grid do -- 352
		do -- 352
			local it = grid[i + 1] -- 353
			local sil = makeSilhouette(it.file) -- 354
			if sil.model == nil then -- 354
				orientLines[#orientLines + 1] = "LOAD_FAIL " .. it.label -- 355
				goto __continue74 -- 355
			end -- 355
			sil.model.position = Vec3(it.wx, 0, it.wz) -- 356
			sil.model.scale = Vec3(it.scale, it.scale, it.scale) -- 357
			sil.model.angleY = it.yaw -- 358
			sil.model.visible = false -- 359
			gridNodes[#gridNodes + 1] = sil.model -- 360
			gridKeep[#gridKeep + 1] = it -- 361
		end -- 361
		::__continue74:: -- 361
		i = i + 1 -- 352
	end -- 352
end -- 352
orientLines[#orientLines + 1] = (("gridNodes=" .. __TS__NumberToFixed(#gridNodes, 0)) .. "/") .. __TS__NumberToFixed(#grid, 0) -- 363
flushOrient() -- 364
local camTop = Camera3D() -- 366
camTop:lookAt( -- 367
	Vec3(0, camDistC, 0.001), -- 367
	Vec3(0, 0, 0), -- 367
	Vec3(0, 1, 0) -- 367
) -- 367
local camViewTop = { -- 371
	eye = {x = 0, y = camDistC, z = 0.001}, -- 372
	target = {x = 0, y = 0, z = 0}, -- 373
	up = {x = 0, y = 1, z = 0}, -- 374
	fovYDeg = fovY, -- 375
	aspect = aspect, -- 376
	viewW = vw, -- 377
	viewH = vh -- 378
} -- 378
local gridPx = {} -- 381
local gridPy = {} -- 382
do -- 382
	local i = 0 -- 383
	while i < #gridKeep do -- 383
		local it = gridKeep[i + 1] -- 384
		local pr = project({x = it.wx, y = 0, z = it.wz}, camViewTop, HANDEDNESS, FLIP_Y) -- 385
		if pr == nil then -- 385
			gridPx[#gridPx + 1] = vw / 2 -- 386
			gridPy[#gridPy + 1] = vh / 2 -- 386
		else -- 386
			gridPx[#gridPx + 1] = vw / 2 + pr.x -- 387
			gridPy[#gridPy + 1] = vh / 2 - pr.y -- 387
		end -- 387
		i = i + 1 -- 383
	end -- 383
end -- 383
orientLines[#orientLines + 1] = "projected centers(px)=" .. table.concat( -- 389
	__TS__ArrayMap( -- 389
		gridPx, -- 389
		function(____, v) return __TS__NumberToFixed(v, 1) end -- 389
	), -- 389
	", " -- 389
) -- 389
flushOrient() -- 390
local THR = 60 -- 395
local frame = 0 -- 396
local stage = 0 -- 397
local shotRow = "" -- 398
local shotTop = "" -- 399
threadLoop(function() -- 401
	frame = frame + 1 -- 402
	if stage == 0 and frame > 6 then -- 402
		stage = 1 -- 405
		shotRow = App:saveScreenshot(Path(outDir, "s31-scale")) -- 406
		scaleLines[#scaleLines + 1] = "shot requested: " .. shotRow -- 407
		flushScale() -- 408
		return false -- 409
	end -- 409
	if stage == 1 and frame > 26 then -- 409
		stage = 2 -- 413
		local data = Content:load(shotRow) -- 414
		local img = parseTga(data) -- 415
		if img == nil then -- 415
			scaleLines[#scaleLines + 1] = "RESULT=FAIL reason=parse-tga len=" .. __TS__NumberToFixed(#data, 0) -- 417
			flushScale() -- 418
		else -- 418
			scaleLines[#scaleLines + 1] = "" -- 420
			scaleLines[#scaleLines + 1] = ("== 口径② 并排渲染像素测量（thr=" .. __TS__NumberToFixed(THR, 0)) .. "）==" -- 421
			scaleLines[#scaleLines + 1] = (((((("image=" .. tostring(img.width)) .. "x") .. tostring(img.height)) .. " bpp=") .. __TS__NumberToFixed(img.bytesPerPixel * 8, 0)) .. " topOrigin=") .. tostring(img.topOrigin) -- 422
			local bandHalf = 0.46 * rowSpacing * ppwFov -- 423
			local refHalf = 0 -- 424
			do -- 424
				local i = 0 -- 425
				while i < #rowPx do -- 425
					do -- 425
						local ex = scanRect( -- 426
							img, -- 426
							rowPx[i + 1] - bandHalf, -- 426
							rowPx[i + 1] + bandHalf, -- 426
							rowPy[i + 1] - 3.2 * ppwFov, -- 427
							rowPy[i + 1] + 3.2 * ppwFov, -- 427
							THR, -- 427
							3 -- 427
						) -- 427
						if ex == nil then -- 427
							scaleLines[#scaleLines + 1] = rowLabel[i + 1] .. ": NO_PIXELS" -- 428
							goto __continue87 -- 428
						end -- 428
						local w = ex.maxX - ex.minX + 1 -- 429
						local h = ex.maxY - ex.minY + 1 -- 430
						local halfW = w / 2 -- 431
						local halfH = h / 2 -- 432
						local rawW = ex.rawMaxX - ex.rawMinX + 1 -- 433
						local rawH = ex.rawMaxY - ex.rawMinY + 1 -- 434
						if i == 0 then -- 434
							refHalf = halfH -- 435
						end -- 435
						scaleLines[#scaleLines + 1] = (((((((((((((((((((rowLabel[i + 1] .. ": pxW=") .. __TS__NumberToFixed(w, 0)) .. " pxH=") .. __TS__NumberToFixed(h, 0)) .. " pxHalfW=") .. __TS__NumberToFixed(halfW, 1)) .. " pxHalfH=") .. __TS__NumberToFixed(halfH, 1)) .. " area=") .. __TS__NumberToFixed(ex.count, 0)) .. " fill=") .. __TS__NumberToFixed(ex.count / (w * h), 3)) .. " massDx=") .. __TS__NumberToFixed(ex.meanX - rowPx[i + 1], 1)) .. " massDy=") .. __TS__NumberToFixed(ex.meanY - rowPy[i + 1], 1)) .. " rawW/H=") .. __TS__NumberToFixed(rawW, 0)) .. "/") .. __TS__NumberToFixed(rawH, 0) -- 436
					end -- 436
					::__continue87:: -- 436
					i = i + 1 -- 425
				end -- 425
			end -- 425
			scaleLines[#scaleLines + 1] = ((((("REF(Sphere r=1) 实测像素半径=" .. __TS__NumberToFixed(refHalf, 2)) .. "  ⇒ 实测 pxPerWorldUnit=") .. __TS__NumberToFixed(refHalf, 3)) .. "（fov 推算 ") .. __TS__NumberToFixed(ppwFov, 3)) .. "）" -- 442
			do -- 442
				local i = 1 -- 444
				while i < #rowPx do -- 444
					do -- 444
						local ex = scanRect( -- 445
							img, -- 445
							rowPx[i + 1] - bandHalf, -- 445
							rowPx[i + 1] + bandHalf, -- 445
							rowPy[i + 1] - 3.2 * ppwFov, -- 446
							rowPy[i + 1] + 3.2 * ppwFov, -- 446
							THR, -- 446
							3 -- 446
						) -- 446
						if ex == nil then -- 446
							goto __continue91 -- 447
						end -- 447
						local halfH = (ex.maxY - ex.minY + 1) / 2 -- 448
						local halfW = (ex.maxX - ex.minX + 1) / 2 -- 449
						local kpx = refHalf > 0 and halfH / refHalf or 0 -- 450
						local kpxW = refHalf > 0 and halfW / refHalf or 0 -- 451
						local bk = boundsMap[1 + i + 1] -- 452
						local kBoundsY = bk.ok and (bk.maxY - bk.minY) / 2 or -1 -- 453
						local kBoundsX = bk.ok and (bk.maxX - bk.minX) / 2 or -1 -- 454
						scaleLines[#scaleLines + 1] = (((((((("k(" .. rowLabel[i + 1]) .. ")  纵向像素口径=") .. __TS__NumberToFixed(kpx, 4)) .. " 横向=") .. __TS__NumberToFixed(kpxW, 4)) .. "  包围盒口径 halfY=") .. (kBoundsY >= 0 and __TS__NumberToFixed(kBoundsY, 4) or "n/a")) .. " halfX=") .. (kBoundsX >= 0 and __TS__NumberToFixed(kBoundsX, 4) or "n/a") -- 455
					end -- 455
					::__continue91:: -- 455
					i = i + 1 -- 444
				end -- 444
			end -- 444
			scaleLines[#scaleLines + 1] = "" -- 459
			scaleLines[#scaleLines + 1] = "== ascii (110x34) ==" -- 460
			local am = asciiMap(img, 110, 34) -- 461
			do -- 461
				local r = 0 -- 462
				while r < #am do -- 462
					scaleLines[#scaleLines + 1] = am[r + 1] -- 462
					r = r + 1 -- 462
				end -- 462
			end -- 462
			scaleLines[#scaleLines + 1] = "RESULT=" .. (refHalf > 0 and "PASS" or "FAIL") -- 463
			flushScale() -- 464
		end -- 464
		do -- 464
			local i = 0 -- 466
			while i < #rowNodes do -- 466
				rowNodes[i + 1].visible = false -- 466
				i = i + 1 -- 466
			end -- 466
		end -- 466
		do -- 466
			local i = 0 -- 467
			while i < #gridNodes do -- 467
				gridNodes[i + 1].visible = true -- 467
				i = i + 1 -- 467
			end -- 467
		end -- 467
		Director:pushCamera(camTop) -- 468
		shotTop = App:saveScreenshot(Path(outDir, "s31-orient")) -- 469
		orientLines[#orientLines + 1] = "shot requested: " .. shotTop -- 470
		flushOrient() -- 471
		return false -- 472
	end -- 472
	if stage == 2 and frame > 52 then -- 472
		stage = 3 -- 476
		local data = Content:load(shotTop) -- 477
		local img = parseTga(data) -- 478
		if img == nil then -- 478
			orientLines[#orientLines + 1] = "RESULT=FAIL reason=parse-tga" -- 480
			flushOrient() -- 481
			return true -- 482
		end -- 482
		orientLines[#orientLines + 1] = "" -- 484
		orientLines[#orientLines + 1] = ("== 像素测量（thr=" .. __TS__NumberToFixed(THR, 0)) .. "）==" -- 485
		orientLines[#orientLines + 1] = (("image=" .. tostring(img.width)) .. "x") .. tostring(img.height) -- 486
		local cellHalfX = 0.58 * 1.2 * SP * ppwC -- 487
		local cellHalfY = 0.42 * rowR * ppwC -- 488
		do -- 488
			local i = 0 -- 489
			while i < #gridKeep do -- 489
				do -- 489
					local it = gridKeep[i + 1] -- 490
					local isMark = (string.find(it.label, "MARK", nil, true) or 0) - 1 == 0 -- 491
					local hx = isMark and it.scale * 1.6 * ppwC or cellHalfX -- 492
					local hy = isMark and it.scale * 1.6 * ppwC or cellHalfY -- 493
					local ex = scanRect( -- 494
						img, -- 494
						gridPx[i + 1] - hx, -- 494
						gridPx[i + 1] + hx, -- 494
						gridPy[i + 1] - hy, -- 494
						gridPy[i + 1] + hy, -- 494
						THR, -- 494
						3 -- 494
					) -- 494
					if ex == nil then -- 494
						orientLines[#orientLines + 1] = it.label .. ": NO_PIXELS" -- 495
						goto __continue102 -- 495
					end -- 495
					local w = ex.maxX - ex.minX + 1 -- 496
					local h = ex.maxY - ex.minY + 1 -- 497
					local clipped = not isMark and (ex.minX <= gridPx[i + 1] - hx + 1 or ex.maxX >= gridPx[i + 1] + hx - 1 or ex.minY <= gridPy[i + 1] - hy + 1 or ex.maxY >= gridPy[i + 1] + hy - 1) -- 498
					orientLines[#orientLines + 1] = ((((((((((((((((((((((((((((((((((it.label .. ": bbox=(") .. tostring(ex.minX)) .. ",") .. tostring(ex.minY)) .. ")-(") .. tostring(ex.maxX)) .. ",") .. tostring(ex.maxY)) .. ")") .. " w=") .. __TS__NumberToFixed(w, 0)) .. " h=") .. __TS__NumberToFixed(h, 0)) .. " area=") .. __TS__NumberToFixed(ex.count, 0)) .. " fill=") .. __TS__NumberToFixed(ex.count / (w * h), 3)) .. " cellC=(") .. __TS__NumberToFixed(gridPx[i + 1], 1)) .. ",") .. __TS__NumberToFixed(gridPy[i + 1], 1)) .. ")") .. " massDx=") .. __TS__NumberToFixed(ex.meanX - gridPx[i + 1], 1)) .. " massDy=") .. __TS__NumberToFixed(ex.meanY - gridPy[i + 1], 1)) .. " L/R=") .. __TS__NumberToFixed(gridPx[i + 1] - ex.minX, 1)) .. "/") .. __TS__NumberToFixed(ex.maxX - gridPx[i + 1], 1)) .. " U/D=") .. __TS__NumberToFixed(gridPy[i + 1] - ex.minY, 1)) .. "/") .. __TS__NumberToFixed(ex.maxY - gridPy[i + 1], 1)) .. (clipped and "  ⚠CLIPPED" or "") -- 500
				end -- 500
				::__continue102:: -- 500
				i = i + 1 -- 489
			end -- 489
		end -- 489
		orientLines[#orientLines + 1] = "" -- 509
		orientLines[#orientLines + 1] = "== ascii (110x40) ==" -- 510
		local am = asciiMap(img, 110, 40) -- 511
		do -- 511
			local r = 0 -- 512
			while r < #am do -- 512
				orientLines[#orientLines + 1] = am[r + 1] -- 512
				r = r + 1 -- 512
			end -- 512
		end -- 512
		orientLines[#orientLines + 1] = "RESULT=PASS" -- 513
		flushOrient() -- 514
		return true -- 515
	end -- 515
	return false -- 518
end) -- 401
return ____exports -- 401