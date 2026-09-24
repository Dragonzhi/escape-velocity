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
		local runtime = { -- 194
			index = index, -- 195
			name = levelNames[index + 1], -- 196
			world = world, -- 197
			camera = camera, -- 198
			game = game, -- 199
			aim = aim -- 200
		} -- 200
		slot.built = true -- 202
		slot.runtime = runtime -- 203
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 204
		return runtime -- 205
	end -- 126
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 209
		local runtime = ensureLevel(index) -- 210
		if runtime == nil then -- 210
			return -- 211
		end -- 211
		activeIndex = index -- 212
		showOnlyLevel(index) -- 213
		Director:pushCamera(runtime.camera) -- 214
		runtime.game:startLevel() -- 215
		print("[escape-velocity] enter " .. runtime.name) -- 216
	end -- 209
	local function onRetryTap() -- 219
		if resultPanel ~= nil then -- 219
			resultPanel:hide() -- 220
		end -- 220
		local runtime = activeRuntime() -- 221
		if runtime ~= nil then -- 221
			runtime.game:retry() -- 222
		end -- 222
	end -- 219
	local function onBackToSelectTap() -- 225
		local runtime = activeRuntime() -- 226
		if runtime == nil then -- 226
			return -- 227
		end -- 227
		if not runtime.game:backToSelect() then -- 227
			return -- 229
		end -- 229
		runtime.world.visible = false -- 230
		runtime.aim:setEnabled(false) -- 231
		if resultPanel ~= nil then -- 231
			resultPanel:hide() -- 232
		end -- 232
		progress = loadProgress(levelTotal) -- 234
		if select ~= nil then -- 234
			select:show(progress.unlocked) -- 235
		end -- 235
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 236
	end -- 225
	resultPanel = createResultPanel( -- 241
		uiLayer, -- 241
		viewW, -- 241
		viewH, -- 241
		{ -- 241
			onRetry = function() return onRetryTap() end, -- 242
			onBackToSelect = function() return onBackToSelectTap() end -- 243
		} -- 243
	) -- 243
	select = createLevelSelect( -- 246
		uiLayer, -- 246
		viewW, -- 246
		viewH, -- 246
		{ -- 246
			levels = levelEntries, -- 247
			onPick = function(____, index) -- 248
				if select ~= nil then -- 248
					select:hide() -- 249
				end -- 249
				enterLevel(index) -- 250
			end -- 248
		} -- 248
	) -- 248
	select:show(progress.unlocked) -- 255
	threadLoop(function() -- 259
		local runtime = activeRuntime() -- 260
		if runtime ~= nil then -- 260
			runtime.game:update(App.deltaTime) -- 261
		end -- 261
		return false -- 262
	end) -- 259
	print(((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", level select shown") -- 265
end -- 265
return ____exports -- 265