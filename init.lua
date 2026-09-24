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
local levelTotal = levelCount() -- 48
if levelTotal <= 0 then -- 48
	print("[escape-velocity] FATAL: no level data") -- 51
else -- 51
	local viewW = View.size.width -- 53
	local viewH = View.size.height -- 54
	Director.entry:setEnvironmentIntensity(0.35, 0.35, 1) -- 56
	local levelLayers = {} -- 62
	do -- 62
		local i = 0 -- 63
		while i < levelTotal do -- 63
			local layer = Node() -- 64
			layer.size = Size(viewW, viewH) -- 65
			layer.anchor = Vec2(0.5, 0.5) -- 66
			layer.position = Vec2(0, 0) -- 67
			Director.ui:addChild(layer) -- 68
			levelLayers[#levelLayers + 1] = layer -- 69
			i = i + 1 -- 63
		end -- 63
	end -- 63
	local uiLayer = Node() -- 73
	uiLayer.size = Size(viewW, viewH) -- 74
	uiLayer.anchor = Vec2(0.5, 0.5) -- 75
	uiLayer.position = Vec2(0, 0) -- 76
	Director.ui:addChild(uiLayer) -- 77
	local levelNames = {} -- 80
	do -- 80
		local i = 0 -- 81
		while i < levelTotal do -- 81
			local def = getLevel(i) -- 82
			local title = def ~= nil and def.title or "" -- 83
			levelNames[#levelNames + 1] = (("L" .. __TS__NumberToFixed(i + 1, 0)) .. " ") .. title -- 84
			i = i + 1 -- 81
		end -- 81
	end -- 81
	local levelEntries = {} -- 86
	do -- 86
		local i = 0 -- 87
		while i < levelTotal do -- 87
			levelEntries[#levelEntries + 1] = {name = levelNames[i + 1]} -- 87
			i = i + 1 -- 87
		end -- 87
	end -- 87
	local progress = loadProgress(levelTotal) -- 90
	print("[escape-velocity] progress file: " .. progressFilePath()) -- 91
	print("[escape-velocity] progress loaded: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 92
	local slots = {} -- 94
	do -- 94
		local i = 0 -- 95
		while i < levelTotal do -- 95
			slots[#slots + 1] = {built = false, runtime = nil} -- 95
			i = i + 1 -- 95
		end -- 95
	end -- 95
	local activeIndex = -1 -- 97
	local select = nil -- 98
	local resultPanel = nil -- 99
	local function activeRuntime() -- 101
		if activeIndex < 0 then -- 101
			return nil -- 102
		end -- 102
		return slots[activeIndex + 1].runtime -- 103
	end -- 101
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 111
		do -- 111
			local i = 0 -- 112
			while i < levelTotal do -- 112
				do -- 112
					local slot = slots[i + 1] -- 113
					if slot.runtime == nil then -- 113
						goto __continue16 -- 114
					end -- 114
					local active = i == index -- 115
					slot.runtime.world.visible = active -- 116
					slot.runtime.aim:setEnabled(active) -- 117
				end -- 117
				::__continue16:: -- 117
				i = i + 1 -- 112
			end -- 112
		end -- 112
	end -- 111
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 126
		local slot = slots[index + 1] -- 127
		if slot.built and slot.runtime ~= nil then -- 127
			return slot.runtime -- 128
		end -- 128
		local def = getLevel(index) -- 130
		if def == nil then -- 130
			return nil -- 131
		end -- 131
		local bodies = scaledPlanets(def) -- 133
		local level = { -- 134
			bodies = bodies, -- 135
			probeStart = def.probeStart, -- 136
			goal = def.goal, -- 137
			escapeRadius = def.escapeRadius, -- 138
			maxSteps = def.maxSteps -- 139
		} -- 139
		local world = Node3D() -- 142
		Director.entry:addChild(world) -- 143
		world.visible = false -- 144
		local scene = buildScene({ -- 146
			root = world, -- 147
			bodies = bodies, -- 148
			visuals = def.visuals, -- 149
			probeStart = level.probeStart, -- 150
			probeScale = 1.2, -- 155
			spherePath = "Assets/Model/Sphere.gltf", -- 156
			ringPath = "Assets/Model/Ring.gltf", -- 157
			probePath = "Assets/Model/Probe_Voyager_v1.glb" -- 158
		}) -- 158
		if scene == nil then -- 158
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 161
			return nil -- 162
		end -- 162
		local camera = Camera3D() -- 165
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio)) -- 168
		local trajectory = createTrajectoryView( -- 169
			levelLayers[index + 1], -- 169
			trajectoryOptions() -- 169
		) -- 169
		local aim = createAimInput(levelLayers[index + 1], viewW, viewH) -- 170
		local game = createGame( -- 172
			level, -- 172
			{ -- 172
				scene = scene, -- 173
				camera = camera, -- 174
				rig = rig, -- 175
				trajectory = trajectory, -- 176
				aim = aim, -- 177
				viewW = viewW, -- 178
				viewH = viewH, -- 179
				fovYDeg = View.fieldOfView, -- 180
				aspect = View.aspectRatio, -- 181
				onPhase = function(____, p) -- 182
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 183
				end, -- 182
				onResult = function(____, r) -- 185
					if r == "success" then -- 185
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 188
						if next ~= progress.unlocked then -- 188
							progress = {unlocked = next} -- 190
							saveProgress(progress) -- 191
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 192
						end -- 192
					end -- 192
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 195
					if resultPanel ~= nil then -- 195
						resultPanel:show(r, levelNames[index + 1]) -- 196
					end -- 196
				end -- 185
			} -- 185
		) -- 185
		aim:onDrag(function(a) -- 203
			game:onAimDrag(a) -- 203
		end) -- 203
		aim:onRelease(function(a) -- 204
			game:launch(a.velocity) -- 204
		end) -- 204
		local runtime = { -- 206
			index = index, -- 207
			name = levelNames[index + 1], -- 208
			world = world, -- 209
			camera = camera, -- 210
			game = game, -- 211
			aim = aim -- 212
		} -- 212
		slot.built = true -- 214
		slot.runtime = runtime -- 215
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 216
		return runtime -- 217
	end -- 126
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 221
		local runtime = ensureLevel(index) -- 222
		if runtime == nil then -- 222
			return -- 223
		end -- 223
		activeIndex = index -- 224
		showOnlyLevel(index) -- 225
		Director:pushCamera(runtime.camera) -- 226
		runtime.game:startLevel() -- 227
		print("[escape-velocity] enter " .. runtime.name) -- 228
	end -- 221
	local function onRetryTap() -- 231
		if resultPanel ~= nil then -- 231
			resultPanel:hide() -- 232
		end -- 232
		local runtime = activeRuntime() -- 233
		if runtime ~= nil then -- 233
			runtime.game:retry() -- 234
		end -- 234
	end -- 231
	local function onBackToSelectTap() -- 237
		local runtime = activeRuntime() -- 238
		if runtime == nil then -- 238
			return -- 239
		end -- 239
		if not runtime.game:backToSelect() then -- 239
			return -- 241
		end -- 241
		runtime.world.visible = false -- 242
		runtime.aim:setEnabled(false) -- 243
		if resultPanel ~= nil then -- 243
			resultPanel:hide() -- 244
		end -- 244
		progress = loadProgress(levelTotal) -- 246
		if select ~= nil then -- 246
			select:show(progress.unlocked) -- 247
		end -- 247
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 248
	end -- 237
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 261
		resultPanel = createResultPanel( -- 262
			uiLayer, -- 262
			viewW, -- 262
			viewH, -- 262
			{ -- 262
				onRetry = function() return onRetryTap() end, -- 263
				onBackToSelect = function() return onBackToSelectTap() end -- 264
			} -- 264
		) -- 264
		local created = createLevelSelect( -- 266
			uiLayer, -- 266
			viewW, -- 266
			viewH, -- 266
			{ -- 266
				levels = levelEntries, -- 267
				onPick = function(____, index) -- 268
					if select ~= nil then -- 268
						select:hide() -- 269
					end -- 269
					enterLevel(index) -- 270
				end -- 268
			} -- 268
		) -- 268
		select = created -- 273
		return created -- 274
	end -- 261
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 287
		local w = View.size.width -- 288
		local h = View.size.height -- 289
		if w == viewW and h == viewH then -- 289
			return -- 290
		end -- 290
		if select ~= nil then -- 290
			select:hide() -- 293
		end -- 293
		if resultPanel ~= nil then -- 293
			resultPanel:hide() -- 294
		end -- 294
		do -- 294
			local i = 0 -- 295
			while i < levelTotal do -- 295
				local slot = slots[i + 1] -- 296
				if slot.runtime ~= nil then -- 296
					slot.runtime.world.visible = false -- 298
					slot.runtime.aim:setEnabled(false) -- 299
				end -- 299
				slot.built = false -- 301
				slot.runtime = nil -- 302
				i = i + 1 -- 295
			end -- 295
		end -- 295
		viewW = w -- 306
		viewH = h -- 307
		uiLayer.size = Size(viewW, viewH) -- 308
		do -- 308
			local i = 0 -- 309
			while i < levelTotal do -- 309
				levelLayers[i + 1].size = Size(viewW, viewH) -- 309
				i = i + 1 -- 309
			end -- 309
		end -- 309
		local panel = buildPanels() -- 312
		if activeIndex >= 0 then -- 312
			local keep = activeIndex -- 314
			activeIndex = -1 -- 315
			enterLevel(keep) -- 316
		else -- 316
			panel:show(progress.unlocked) -- 318
		end -- 318
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 320
	end -- 287
	Director.entry:onAppChange(function(name) -- 324
		if name == "Size" then -- 324
			relayoutForViewport() -- 325
		end -- 325
	end) -- 324
	buildPanels():show(progress.unlocked) -- 329
	threadLoop(function() -- 333
		local runtime = activeRuntime() -- 334
		if runtime ~= nil then -- 334
			runtime.game:update(App.deltaTime) -- 335
		end -- 335
		return false -- 337
	end) -- 333
	print(((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", level select shown") -- 341
end -- 341
return ____exports -- 341