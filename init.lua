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
			probeScale = 1.6, -- 151
			spherePath = "Assets/Model/Sphere.gltf", -- 152
			ringPath = "Assets/Model/Ring.gltf", -- 153
			probePath = "Assets/Model/Probe.gltf" -- 154
		}) -- 154
		if scene == nil then -- 154
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 157
			return nil -- 158
		end -- 158
		local camera = Camera3D() -- 161
		local rig = createCameraRig(defaultRigOptions()) -- 162
		local trajectory = createTrajectoryView( -- 163
			levelLayers[index + 1], -- 163
			trajectoryOptions() -- 163
		) -- 163
		local aim = createAimInput(levelLayers[index + 1], viewW, viewH) -- 164
		local game = createGame( -- 166
			level, -- 166
			{ -- 166
				scene = scene, -- 167
				camera = camera, -- 168
				rig = rig, -- 169
				trajectory = trajectory, -- 170
				aim = aim, -- 171
				viewW = viewW, -- 172
				viewH = viewH, -- 173
				fovYDeg = View.fieldOfView, -- 174
				aspect = View.aspectRatio, -- 175
				onPhase = function(____, p) -- 176
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 177
				end, -- 176
				onResult = function(____, r) -- 179
					if r == "success" then -- 179
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 182
						if next ~= progress.unlocked then -- 182
							progress = {unlocked = next} -- 184
							saveProgress(progress) -- 185
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 186
						end -- 186
					end -- 186
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 189
					if resultPanel ~= nil then -- 189
						resultPanel:show(r, levelNames[index + 1]) -- 190
					end -- 190
				end -- 179
			} -- 179
		) -- 179
		aim:onDrag(function(a) -- 197
			game:onAimDrag(a) -- 197
		end) -- 197
		aim:onRelease(function(a) -- 198
			game:launch(a.velocity) -- 198
		end) -- 198
		local runtime = { -- 200
			index = index, -- 201
			name = levelNames[index + 1], -- 202
			world = world, -- 203
			camera = camera, -- 204
			game = game, -- 205
			aim = aim -- 206
		} -- 206
		slot.built = true -- 208
		slot.runtime = runtime -- 209
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 210
		return runtime -- 211
	end -- 126
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 215
		local runtime = ensureLevel(index) -- 216
		if runtime == nil then -- 216
			return -- 217
		end -- 217
		activeIndex = index -- 218
		showOnlyLevel(index) -- 219
		Director:pushCamera(runtime.camera) -- 220
		runtime.game:startLevel() -- 221
		print("[escape-velocity] enter " .. runtime.name) -- 222
	end -- 215
	local function onRetryTap() -- 225
		if resultPanel ~= nil then -- 225
			resultPanel:hide() -- 226
		end -- 226
		local runtime = activeRuntime() -- 227
		if runtime ~= nil then -- 227
			runtime.game:retry() -- 228
		end -- 228
	end -- 225
	local function onBackToSelectTap() -- 231
		local runtime = activeRuntime() -- 232
		if runtime == nil then -- 232
			return -- 233
		end -- 233
		if not runtime.game:backToSelect() then -- 233
			return -- 235
		end -- 235
		runtime.world.visible = false -- 236
		runtime.aim:setEnabled(false) -- 237
		if resultPanel ~= nil then -- 237
			resultPanel:hide() -- 238
		end -- 238
		progress = loadProgress(levelTotal) -- 240
		if select ~= nil then -- 240
			select:show(progress.unlocked) -- 241
		end -- 241
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 242
	end -- 231
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 255
		resultPanel = createResultPanel( -- 256
			uiLayer, -- 256
			viewW, -- 256
			viewH, -- 256
			{ -- 256
				onRetry = function() return onRetryTap() end, -- 257
				onBackToSelect = function() return onBackToSelectTap() end -- 258
			} -- 258
		) -- 258
		local created = createLevelSelect( -- 260
			uiLayer, -- 260
			viewW, -- 260
			viewH, -- 260
			{ -- 260
				levels = levelEntries, -- 261
				onPick = function(____, index) -- 262
					if select ~= nil then -- 262
						select:hide() -- 263
					end -- 263
					enterLevel(index) -- 264
				end -- 262
			} -- 262
		) -- 262
		select = created -- 267
		return created -- 268
	end -- 255
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 281
		local w = View.size.width -- 282
		local h = View.size.height -- 283
		if w == viewW and h == viewH then -- 283
			return -- 284
		end -- 284
		if select ~= nil then -- 284
			select:hide() -- 287
		end -- 287
		if resultPanel ~= nil then -- 287
			resultPanel:hide() -- 288
		end -- 288
		do -- 288
			local i = 0 -- 289
			while i < levelTotal do -- 289
				local slot = slots[i + 1] -- 290
				if slot.runtime ~= nil then -- 290
					slot.runtime.world.visible = false -- 292
					slot.runtime.aim:setEnabled(false) -- 293
				end -- 293
				slot.built = false -- 295
				slot.runtime = nil -- 296
				i = i + 1 -- 289
			end -- 289
		end -- 289
		viewW = w -- 300
		viewH = h -- 301
		uiLayer.size = Size(viewW, viewH) -- 302
		do -- 302
			local i = 0 -- 303
			while i < levelTotal do -- 303
				levelLayers[i + 1].size = Size(viewW, viewH) -- 303
				i = i + 1 -- 303
			end -- 303
		end -- 303
		local panel = buildPanels() -- 306
		if activeIndex >= 0 then -- 306
			local keep = activeIndex -- 308
			activeIndex = -1 -- 309
			enterLevel(keep) -- 310
		else -- 310
			panel:show(progress.unlocked) -- 312
		end -- 312
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 314
	end -- 281
	Director.entry:onAppChange(function(name) -- 318
		if name == "Size" then -- 318
			relayoutForViewport() -- 319
		end -- 319
	end) -- 318
	buildPanels():show(progress.unlocked) -- 323
	threadLoop(function() -- 327
		local runtime = activeRuntime() -- 328
		if runtime ~= nil then -- 328
			runtime.game:update(App.deltaTime) -- 329
		end -- 329
		return false -- 331
	end) -- 327
	print(((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", level select shown") -- 335
end -- 335
return ____exports -- 335