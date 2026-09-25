-- [ts]: init.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 21
local App = ____Dora.App -- 21
local Camera3D = ____Dora.Camera3D -- 21
local Director = ____Dora.Director -- 21
local Node = ____Dora.Node -- 21
local Node3D = ____Dora.Node3D -- 21
local Size = ____Dora.Size -- 21
local Vec2 = ____Dora.Vec2 -- 21
local View = ____Dora.View -- 21
local threadLoop = ____Dora.threadLoop -- 21
local ____LevelData = require("game.LevelData") -- 22
local getLevel = ____LevelData.getLevel -- 22
local levelCount = ____LevelData.levelCount -- 22
local scaledPlanets = ____LevelData.scaledPlanets -- 22
local ____Scene = require("game.Scene") -- 23
local buildScene = ____Scene.buildScene -- 23
local ____CameraRig = require("game.CameraRig") -- 24
local createCameraRig = ____CameraRig.createCameraRig -- 24
local defaultRigOptions = ____CameraRig.defaultRigOptions -- 24
local ____Trajectory = require("game.Trajectory") -- 25
local createTrajectoryView = ____Trajectory.createTrajectoryView -- 25
local trajectoryOptions = ____Trajectory.defaultOptions -- 25
local ____Hud = require("game.Hud") -- 26
local createAimInput = ____Hud.createAimInput -- 26
local createLevelSelect = ____Hud.createLevelSelect -- 26
local createResultPanel = ____Hud.createResultPanel -- 26
local ____Game = require("game.Game") -- 27
local createGame = ____Game.createGame -- 27
local ____Progress = require("game.Progress") -- 28
local advanceUnlocked = ____Progress.advanceUnlocked -- 28
local loadProgress = ____Progress.loadProgress -- 28
local progressFilePath = ____Progress.progressFilePath -- 28
local saveProgress = ____Progress.saveProgress -- 28
local levelTotal = levelCount() -- 50
if levelTotal <= 0 then -- 50
	print("[escape-velocity] FATAL: no level data") -- 53
else -- 53
	local viewW = View.size.width -- 55
	local viewH = View.size.height -- 56
	Director.entry:setEnvironmentIntensity(0.35, 0.35, 1) -- 58
	local levelLayers = {} -- 64
	do -- 64
		local i = 0 -- 65
		while i < levelTotal do -- 65
			local layer = Node() -- 66
			layer.size = Size(viewW, viewH) -- 67
			layer.anchor = Vec2(0.5, 0.5) -- 68
			layer.position = Vec2(0, 0) -- 69
			Director.ui:addChild(layer) -- 70
			levelLayers[#levelLayers + 1] = layer -- 71
			i = i + 1 -- 65
		end -- 65
	end -- 65
	local uiLayer = Node() -- 75
	uiLayer.size = Size(viewW, viewH) -- 76
	uiLayer.anchor = Vec2(0.5, 0.5) -- 77
	uiLayer.position = Vec2(0, 0) -- 78
	Director.ui:addChild(uiLayer) -- 79
	local levelNames = {} -- 82
	do -- 82
		local i = 0 -- 83
		while i < levelTotal do -- 83
			local def = getLevel(i) -- 84
			local title = def ~= nil and def.title or "" -- 85
			levelNames[#levelNames + 1] = (("L" .. __TS__NumberToFixed(i + 1, 0)) .. " ") .. title -- 86
			i = i + 1 -- 83
		end -- 83
	end -- 83
	local levelEntries = {} -- 88
	do -- 88
		local i = 0 -- 89
		while i < levelTotal do -- 89
			levelEntries[#levelEntries + 1] = {name = levelNames[i + 1]} -- 89
			i = i + 1 -- 89
		end -- 89
	end -- 89
	local progress = loadProgress(levelTotal) -- 92
	print("[escape-velocity] progress file: " .. progressFilePath()) -- 93
	print("[escape-velocity] progress loaded: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 94
	local slots = {} -- 96
	do -- 96
		local i = 0 -- 97
		while i < levelTotal do -- 97
			slots[#slots + 1] = {built = false, runtime = nil} -- 97
			i = i + 1 -- 97
		end -- 97
	end -- 97
	local activeIndex = -1 -- 99
	local select = nil -- 100
	local resultPanel = nil -- 101
	local function activeRuntime() -- 103
		if activeIndex < 0 then -- 103
			return nil -- 104
		end -- 104
		return slots[activeIndex + 1].runtime -- 105
	end -- 103
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 113
		do -- 113
			local i = 0 -- 114
			while i < levelTotal do -- 114
				do -- 114
					local slot = slots[i + 1] -- 115
					if slot.runtime == nil then -- 115
						goto __continue16 -- 116
					end -- 116
					local active = i == index -- 117
					slot.runtime.world.visible = active -- 118
					slot.runtime.aim:setEnabled(active) -- 119
				end -- 119
				::__continue16:: -- 119
				i = i + 1 -- 114
			end -- 114
		end -- 114
	end -- 113
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 128
		local slot = slots[index + 1] -- 129
		if slot.built and slot.runtime ~= nil then -- 129
			return slot.runtime -- 130
		end -- 130
		local def = getLevel(index) -- 132
		if def == nil then -- 132
			return nil -- 133
		end -- 133
		local bodies = scaledPlanets(def) -- 135
		local level = { -- 136
			bodies = bodies, -- 137
			probeStart = def.probeStart, -- 138
			goal = def.goal, -- 139
			escapeRadius = def.escapeRadius, -- 140
			maxSteps = def.maxSteps -- 141
		} -- 141
		local world = Node3D() -- 144
		Director.entry:addChild(world) -- 145
		world.visible = false -- 146
		local scene = buildScene({ -- 148
			root = world, -- 149
			bodies = bodies, -- 150
			visuals = def.visuals, -- 151
			probeStart = level.probeStart, -- 152
			probeScale = 1.2, -- 157
			spherePath = "Assets/Model/Sphere.gltf", -- 158
			ringPath = "Assets/Model/Ring.gltf", -- 159
			probePath = "Assets/Model/Probe_Voyager_v1.glb" -- 160
		}) -- 160
		if scene == nil then -- 160
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 163
			return nil -- 164
		end -- 164
		local camera = Camera3D() -- 167
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio)) -- 170
		local trajectory = createTrajectoryView( -- 171
			levelLayers[index + 1], -- 171
			trajectoryOptions() -- 171
		) -- 171
		local aim = createAimInput(levelLayers[index + 1], viewW, viewH) -- 172
		local game = createGame( -- 174
			level, -- 174
			{ -- 174
				scene = scene, -- 175
				camera = camera, -- 176
				rig = rig, -- 177
				trajectory = trajectory, -- 178
				aim = aim, -- 179
				viewW = viewW, -- 180
				viewH = viewH, -- 181
				fovYDeg = View.fieldOfView, -- 182
				aspect = View.aspectRatio, -- 183
				onPhase = function(____, p) -- 184
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 185
				end, -- 184
				onResult = function(____, r) -- 187
					if r == "success" then -- 187
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 190
						if next ~= progress.unlocked then -- 190
							progress = {unlocked = next} -- 192
							saveProgress(progress) -- 193
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 194
						end -- 194
					end -- 194
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 197
					if resultPanel ~= nil then -- 197
						resultPanel:show(r, levelNames[index + 1]) -- 198
					end -- 198
				end -- 187
			} -- 187
		) -- 187
		aim:onDrag(function(a) -- 205
			game:onAimDrag(a) -- 205
		end) -- 205
		aim:onRelease(function(a) -- 206
			game:launch(a.velocity) -- 206
		end) -- 206
		local runtime = { -- 208
			index = index, -- 209
			name = levelNames[index + 1], -- 210
			world = world, -- 211
			camera = camera, -- 212
			game = game, -- 213
			aim = aim, -- 214
			trajectory = trajectory -- 215
		} -- 215
		slot.built = true -- 217
		slot.runtime = runtime -- 218
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 219
		return runtime -- 220
	end -- 128
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 224
		local runtime = ensureLevel(index) -- 225
		if runtime == nil then -- 225
			return -- 226
		end -- 226
		activeIndex = index -- 227
		showOnlyLevel(index) -- 228
		Director:pushCamera(runtime.camera) -- 229
		runtime.game:startLevel() -- 230
		print("[escape-velocity] enter " .. runtime.name) -- 231
	end -- 224
	local function onRetryTap() -- 234
		if resultPanel ~= nil then -- 234
			resultPanel:hide() -- 235
		end -- 235
		local runtime = activeRuntime() -- 236
		if runtime ~= nil then -- 236
			runtime.game:retry() -- 237
		end -- 237
	end -- 234
	local function onBackToSelectTap() -- 240
		local runtime = activeRuntime() -- 241
		if runtime == nil then -- 241
			return -- 242
		end -- 242
		if not runtime.game:backToSelect() then -- 242
			return -- 244
		end -- 244
		runtime.world.visible = false -- 245
		runtime.aim:setEnabled(false) -- 246
		if resultPanel ~= nil then -- 246
			resultPanel:hide() -- 247
		end -- 247
		progress = loadProgress(levelTotal) -- 249
		if select ~= nil then -- 249
			select:show(progress.unlocked) -- 250
		end -- 250
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 251
	end -- 240
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 264
		resultPanel = createResultPanel( -- 265
			uiLayer, -- 265
			viewW, -- 265
			viewH, -- 265
			{ -- 265
				onRetry = function() return onRetryTap() end, -- 266
				onBackToSelect = function() return onBackToSelectTap() end -- 267
			} -- 267
		) -- 267
		local created = createLevelSelect( -- 269
			uiLayer, -- 269
			viewW, -- 269
			viewH, -- 269
			{ -- 269
				levels = levelEntries, -- 270
				onPick = function(____, index) -- 271
					if select ~= nil then -- 271
						select:hide() -- 272
					end -- 272
					enterLevel(index) -- 273
				end -- 271
			} -- 271
		) -- 271
		select = created -- 276
		return created -- 277
	end -- 264
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 290
		local w = View.size.width -- 291
		local h = View.size.height -- 292
		if w == viewW and h == viewH then -- 292
			return -- 293
		end -- 293
		if select ~= nil then -- 293
			select:hide() -- 296
		end -- 296
		if resultPanel ~= nil then -- 296
			resultPanel:hide() -- 297
		end -- 297
		do -- 297
			local i = 0 -- 298
			while i < levelTotal do -- 298
				local slot = slots[i + 1] -- 299
				if slot.runtime ~= nil then -- 299
					slot.runtime.world.visible = false -- 301
					slot.runtime.aim:setEnabled(false) -- 302
					slot.runtime.trajectory:clearPrediction() -- 305
					slot.runtime.trajectory:clearTrail() -- 306
				end -- 306
				slot.built = false -- 308
				slot.runtime = nil -- 309
				i = i + 1 -- 298
			end -- 298
		end -- 298
		viewW = w -- 313
		viewH = h -- 314
		uiLayer.size = Size(viewW, viewH) -- 315
		do -- 315
			local i = 0 -- 316
			while i < levelTotal do -- 316
				levelLayers[i + 1].size = Size(viewW, viewH) -- 316
				i = i + 1 -- 316
			end -- 316
		end -- 316
		local panel = buildPanels() -- 319
		if activeIndex >= 0 then -- 319
			local keep = activeIndex -- 321
			activeIndex = -1 -- 322
			enterLevel(keep) -- 323
		else -- 323
			panel:show(progress.unlocked) -- 325
		end -- 325
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 327
	end -- 290
	Director.entry:onAppChange(function(name) -- 331
		if name == "Size" then -- 331
			relayoutForViewport() -- 332
		end -- 332
	end) -- 331
	buildPanels():show(progress.unlocked) -- 336
	threadLoop(function() -- 340
		local runtime = activeRuntime() -- 341
		if runtime ~= nil then -- 341
			runtime.game:update(App.deltaTime) -- 342
		end -- 342
		return false -- 344
	end) -- 340
	print(((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", level select shown") -- 348
end -- 348
return ____exports -- 348