-- [ts]: UiProbe.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__StringTrim = ____lualib.__TS__StringTrim -- 1
local __TS__StringStartsWith = ____lualib.__TS__StringStartsWith -- 1
local __TS__StringSubstring = ____lualib.__TS__StringSubstring -- 1
local __TS__ParseFloat = ____lualib.__TS__ParseFloat -- 1
local __TS__StringSplit = ____lualib.__TS__StringSplit -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 18
local App = ____Dora.App -- 18
local Camera3D = ____Dora.Camera3D -- 18
local Content = ____Dora.Content -- 18
local Director = ____Dora.Director -- 18
local Node = ____Dora.Node -- 18
local Node3D = ____Dora.Node3D -- 18
local Path = ____Dora.Path -- 18
local Size = ____Dora.Size -- 18
local Vec2 = ____Dora.Vec2 -- 18
local View = ____Dora.View -- 18
local threadLoop = ____Dora.threadLoop -- 18
local ____Hud = require("game.Hud") -- 19
local createAimInput = ____Hud.createAimInput -- 19
local createLevelSelect = ____Hud.createLevelSelect -- 19
local createResultPanel = ____Hud.createResultPanel -- 19
local ____Game = require("game.Game") -- 20
local createGame = ____Game.createGame -- 20
local ____LevelData = require("game.LevelData") -- 21
local getLevel = ____LevelData.getLevel -- 21
local scaledPlanets = ____LevelData.scaledPlanets -- 21
local ____Scene = require("game.Scene") -- 22
local buildScene = ____Scene.buildScene -- 22
local ____CameraRig = require("game.CameraRig") -- 23
local createCameraRig = ____CameraRig.createCameraRig -- 23
local defaultRigOptions = ____CameraRig.defaultRigOptions -- 23
local ____Trajectory = require("game.Trajectory") -- 24
local createTrajectoryView = ____Trajectory.createTrajectoryView -- 24
local trajectoryOptions = ____Trajectory.defaultOptions -- 24
local ____Vision = require("Test.Vision") -- 25
local captureReport = ____Vision.captureReport -- 25
local root = Content.searchPaths[1] -- 27
local outDir = Path(root, ".agent", "test-results") -- 28
if not Content:exist(outDir) then -- 28
	Content:mkdir(outDir) -- 29
end -- 29
local marker = Path(outDir, "s22-ui.txt") -- 30
local lines = {} -- 32
local function flush(final) -- 33
	Content:save( -- 34
		marker, -- 34
		table.concat(lines, "\n") .. (final and "\nphase=done" or "") -- 34
	) -- 34
end -- 33
lines[#lines + 1] = "phase=started" -- 36
flush(false) -- 37
--- 从 captureReport 的文本里取平均亮度（报告里是 `samples=N mean=X min=.. max=..`）。
local function reportMean(report) -- 40
	for ____, rawLine in ipairs(__TS__StringSplit(report, "\n")) do -- 41
		do -- 41
			local line = __TS__StringTrim(rawLine) -- 42
			if (string.find(line, "mean=", nil, true) or 0) - 1 < 0 then -- 42
				goto __continue5 -- 43
			end -- 43
			for ____, token in ipairs(__TS__StringSplit(line, " ")) do -- 44
				if __TS__StringStartsWith(token, "mean=") then -- 44
					return __TS__ParseFloat(__TS__StringSubstring(token, 5)) -- 45
				end -- 45
			end -- 45
		end -- 45
		::__continue5:: -- 45
	end -- 45
	return -1 -- 48
end -- 40
--- 报告里是否检出了区域（Vision 在没有任何亮块时会写 NONE）。
local function reportHasRegions(report) -- 52
	return (string.find(report, "== regions", nil, true) or 0) - 1 >= 0 and (string.find(report, "NONE", nil, true) or 0) - 1 < 0 -- 53
end -- 52
local levelTotal = 6 -- 56
local levelDef = getLevel(0) -- 57
if levelDef == nil then -- 57
	lines[#lines + 1] = "RESULT=FAIL reason=no-level-data" -- 60
	flush(true) -- 61
else -- 61
	local viewW = View.size.width -- 63
	local viewH = View.size.height -- 64
	lines[#lines + 1] = (("view=" .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0) -- 65
	local bodies = scaledPlanets(levelDef) -- 67
	local level = { -- 68
		bodies = bodies, -- 69
		probeStart = levelDef.probeStart, -- 70
		goal = levelDef.goal, -- 71
		escapeRadius = levelDef.escapeRadius, -- 72
		maxSteps = levelDef.maxSteps -- 73
	} -- 73
	Director.entry:setEnvironmentIntensity(0.35, 0.35, 1) -- 76
	local levelLayer = Node() -- 79
	levelLayer.size = Size(viewW, viewH) -- 80
	levelLayer.anchor = Vec2(0.5, 0.5) -- 81
	levelLayer.position = Vec2(0, 0) -- 82
	Director.ui:addChild(levelLayer) -- 83
	local uiLayer = Node() -- 85
	uiLayer.size = Size(viewW, viewH) -- 86
	uiLayer.anchor = Vec2(0.5, 0.5) -- 87
	uiLayer.position = Vec2(0, 0) -- 88
	Director.ui:addChild(uiLayer) -- 89
	local world = Node3D() -- 91
	Director.entry:addChild(world) -- 92
	local scene = buildScene({ -- 94
		root = world, -- 95
		bodies = bodies, -- 96
		visuals = levelDef.visuals, -- 97
		probeStart = level.probeStart, -- 98
		probeScale = 1.6, -- 99
		spherePath = "Assets/Model/Sphere.gltf", -- 100
		ringPath = "Assets/Model/Ring.gltf", -- 101
		probePath = "Assets/Model/Probe.gltf" -- 102
	}) -- 102
	if scene == nil then -- 102
		lines[#lines + 1] = "RESULT=FAIL reason=scene" -- 106
		flush(true) -- 107
	else -- 107
		local camera = Camera3D() -- 109
		Director:pushCamera(camera) -- 110
		local rig = createCameraRig(defaultRigOptions()) -- 111
		local trajectory = createTrajectoryView( -- 112
			levelLayer, -- 112
			trajectoryOptions() -- 112
		) -- 112
		local aim = createAimInput(levelLayer, viewW, viewH) -- 113
		local game = createGame( -- 115
			level, -- 115
			{ -- 115
				scene = scene, -- 116
				camera = camera, -- 117
				rig = rig, -- 118
				trajectory = trajectory, -- 119
				aim = aim, -- 120
				viewW = viewW, -- 121
				viewH = viewH, -- 122
				fovYDeg = View.fieldOfView, -- 123
				aspect = View.aspectRatio, -- 124
				onPhase = function() -- 125
				end, -- 125
				onResult = function() -- 126
				end -- 126
			} -- 126
		) -- 126
		aim:onDrag(function(a) return game:onAimDrag(a) end) -- 128
		--- 关卡切换检查（S2.3 的真正风险点）。
		-- 
		-- init.ts 的 ensureLevel 要按同样的调用序列再建一关：Node3D 容器 → buildScene
		-- → 相机 → 轨迹/矄准 → createGame，然后切 visible + pushCamera + startLevel。
		-- 这些调用**只有真跑一遍才知道会不会 nil**，所以探针照抄这条路径
		-- （探针不能 import init.ts —— 入口脚本不可被 require）。
		-- 
		-- @returns 失败原因（空数组 = 全过）
		local function probeLevelSwitch() -- 140
			local problems = {} -- 141
			local def2 = getLevel(1) -- 142
			if def2 == nil then -- 142
				problems[#problems + 1] = "level 2 data missing" -- 144
				return problems -- 145
			end -- 145
			local bodies2 = scaledPlanets(def2) -- 148
			local level2 = { -- 149
				bodies = bodies2, -- 150
				probeStart = def2.probeStart, -- 151
				goal = def2.goal, -- 152
				escapeRadius = def2.escapeRadius, -- 153
				maxSteps = def2.maxSteps -- 154
			} -- 154
			local layer2 = Node() -- 158
			layer2.size = Size(viewW, viewH) -- 159
			layer2.anchor = Vec2(0.5, 0.5) -- 160
			layer2.position = Vec2(0, 0) -- 161
			Director.ui:addChild(layer2) -- 162
			local world2 = Node3D() -- 164
			Director.entry:addChild(world2) -- 165
			world2.visible = false -- 166
			local scene2 = buildScene({ -- 168
				root = world2, -- 169
				bodies = bodies2, -- 170
				visuals = def2.visuals, -- 171
				probeStart = level2.probeStart, -- 172
				probeScale = 1.6, -- 173
				spherePath = "Assets/Model/Sphere.gltf", -- 174
				ringPath = "Assets/Model/Ring.gltf", -- 175
				probePath = "Assets/Model/Probe.gltf" -- 176
			}) -- 176
			if scene2 == nil then -- 176
				problems[#problems + 1] = "level 2 scene build failed" -- 179
				return problems -- 180
			end -- 180
			local camera2 = Camera3D() -- 183
			local rig2 = createCameraRig(defaultRigOptions()) -- 184
			local trajectory2 = createTrajectoryView( -- 185
				layer2, -- 185
				trajectoryOptions() -- 185
			) -- 185
			local aim2 = createAimInput(layer2, viewW, viewH) -- 186
			local game2 = createGame( -- 187
				level2, -- 187
				{ -- 187
					scene = scene2, -- 188
					camera = camera2, -- 189
					rig = rig2, -- 190
					trajectory = trajectory2, -- 191
					aim = aim2, -- 192
					viewW = viewW, -- 193
					viewH = viewH, -- 194
					fovYDeg = View.fieldOfView, -- 195
					aspect = View.aspectRatio, -- 196
					onPhase = function() -- 197
					end, -- 197
					onResult = function() -- 198
					end -- 198
				} -- 198
			) -- 198
			world.visible = false -- 202
			aim:setEnabled(false) -- 203
			world2.visible = true -- 204
			Director:pushCamera(camera2) -- 205
			game2:startLevel() -- 206
			game2:update(App.deltaTime) -- 207
			if game2:phase() ~= "Aiming" then -- 207
				problems[#problems + 1] = "level 2 did not enter Aiming: " .. game2:phase() -- 209
			end -- 209
			if world.visible then -- 209
				problems[#problems + 1] = "level 1 world still visible after switch" -- 210
			end -- 210
			if not world2.visible then -- 210
				problems[#problems + 1] = "level 2 world not visible after switch" -- 211
			end -- 211
			if game:phase() ~= "Aiming" then -- 211
				problems[#problems + 1] = "level 1 core phase changed: " .. game:phase() -- 212
			end -- 212
			world2.visible = false -- 215
			aim2:setEnabled(false) -- 216
			world.visible = true -- 217
			Director:pushCamera(camera) -- 218
			game:startLevel() -- 219
			game:update(App.deltaTime) -- 220
			if game:phase() ~= "Aiming" then -- 220
				problems[#problems + 1] = "level 1 did not return to Aiming: " .. game:phase() -- 221
			end -- 221
			lines[#lines + 1] = "level switch L1 -> L2 -> L1 done, game2.phase=" .. game2:phase() -- 223
			return problems -- 224
		end -- 140
		local switchProblems = probeLevelSwitch() -- 228
		lines[#lines + 1] = "switchProblems=" .. __TS__NumberToFixed(#switchProblems, 0) -- 229
		flush(false) -- 230
		local unlockedForShot = 2 -- 234
		local panel = createResultPanel( -- 236
			uiLayer, -- 236
			viewW, -- 236
			viewH, -- 236
			{ -- 236
				onRetry = function() -- 237
					lines[#lines + 1] = "tap: retry button" -- 238
					flush(false) -- 239
				end, -- 237
				onBackToSelect = function() -- 241
					lines[#lines + 1] = "tap: back-to-select button" -- 242
					flush(false) -- 243
				end -- 241
			} -- 241
		) -- 241
		local select = createLevelSelect( -- 246
			uiLayer, -- 246
			viewW, -- 246
			viewH, -- 246
			{ -- 246
				levels = { -- 247
					{name = "L1 直飞"}, -- 248
					{name = "L2 第一次弯曲"}, -- 249
					{name = "L3 从背后抄过去"}, -- 250
					{name = "L4 它动了"}, -- 251
					{name = "L5 两连弹"}, -- 252
					{name = "L6 贴着过去"} -- 253
				}, -- 253
				onPick = function(____, index) -- 255
					lines[#lines + 1] = "tap: level button " .. __TS__NumberToFixed(index + 1, 0) -- 256
					flush(false) -- 257
				end -- 255
			} -- 255
		) -- 255
		local frame = 0 -- 261
		local shotSuccess = "" -- 262
		local shotMissed = "" -- 263
		local shotCrashed = "" -- 264
		local shotBaseline = "" -- 265
		local shotSelect = "" -- 266
		local done = false -- 267
		threadLoop(function() -- 269
			frame = frame + 1 -- 270
			game:update(App.deltaTime) -- 271
			if frame == 15 then -- 271
				panel:show("success", "L1 直飞") -- 275
				lines[#lines + 1] = "show success @f" .. __TS__NumberToFixed(frame, 0) -- 276
				flush(false) -- 277
			end -- 277
			if frame == 18 then -- 277
				shotSuccess = App:saveScreenshot(Path(outDir, "s22-result-success")) -- 280
			end -- 280
			if frame == 26 then -- 280
				panel:show("missed", "L1 直飞") -- 284
				lines[#lines + 1] = "show missed @f" .. __TS__NumberToFixed(frame, 0) -- 285
				flush(false) -- 286
			end -- 286
			if frame == 29 then -- 286
				shotMissed = App:saveScreenshot(Path(outDir, "s22-result-missed")) -- 289
			end -- 289
			if frame == 37 then -- 289
				panel:show("crashed", "L1 直飞") -- 293
				lines[#lines + 1] = "show crashed @f" .. __TS__NumberToFixed(frame, 0) -- 294
				flush(false) -- 295
			end -- 295
			if frame == 40 then -- 295
				shotCrashed = App:saveScreenshot(Path(outDir, "s22-result-crashed")) -- 298
			end -- 298
			if frame == 48 then -- 298
				panel:hide() -- 303
				lines[#lines + 1] = "panel hidden @f" .. __TS__NumberToFixed(frame, 0) -- 304
				flush(false) -- 305
			end -- 305
			if frame == 51 then -- 305
				shotBaseline = App:saveScreenshot(Path(outDir, "s22-nopanel")) -- 308
			end -- 308
			if frame == 59 then -- 308
				select:show(unlockedForShot) -- 312
				lines[#lines + 1] = (("level select shown @f" .. __TS__NumberToFixed(frame, 0)) .. " unlocked=") .. __TS__NumberToFixed(unlockedForShot, 0) -- 313
				flush(false) -- 314
			end -- 314
			if frame == 62 then -- 314
				shotSelect = App:saveScreenshot(Path(outDir, "s22-levelselect")) -- 317
			end -- 317
			if frame == 72 and not done then -- 317
				done = true -- 322
				lines[#lines + 1] = "" -- 323
				lines[#lines + 1] = "--- result panel: success ---"
				local rSuccess = captureReport(shotSuccess, {"s22 result panel: success"}) -- 325
				lines[#lines + 1] = rSuccess -- 326
				lines[#lines + 1] = "" -- 327
				lines[#lines + 1] = "--- result panel: missed ---"
				local rMissed = captureReport(shotMissed, {"s22 result panel: missed"}) -- 329
				lines[#lines + 1] = rMissed -- 330
				lines[#lines + 1] = "" -- 331
				lines[#lines + 1] = "--- result panel: crashed ---"
				local rCrashed = captureReport(shotCrashed, {"s22 result panel: crashed"}) -- 333
				lines[#lines + 1] = rCrashed -- 334
				lines[#lines + 1] = "" -- 335
				lines[#lines + 1] = "--- baseline: no panel (same camera) ---"
				local rBase = captureReport(shotBaseline, {"s22 baseline without panel"}) -- 337
				lines[#lines + 1] = rBase -- 338
				lines[#lines + 1] = "" -- 339
				lines[#lines + 1] = "--- level select (unlocked=2 -> 3/6) ---"
				local rSelect = captureReport(shotSelect, {"s22 level select, unlocked=2"}) -- 341
				lines[#lines + 1] = rSelect -- 342
				local meanSuccess = reportMean(rSuccess) -- 344
				local meanMissed = reportMean(rMissed) -- 345
				local meanCrashed = reportMean(rCrashed) -- 346
				local meanBase = reportMean(rBase) -- 347
				local meanSelect = reportMean(rSelect) -- 348
				lines[#lines + 1] = "" -- 350
				lines[#lines + 1] = "--- checks ---"
				lines[#lines + 1] = "shot success=" .. shotSuccess -- 352
				lines[#lines + 1] = "shot missed=" .. shotMissed -- 353
				lines[#lines + 1] = "shot crashed=" .. shotCrashed -- 354
				lines[#lines + 1] = "shot baseline=" .. shotBaseline -- 355
				lines[#lines + 1] = "shot select=" .. shotSelect -- 356
				lines[#lines + 1] = (((((((("mean success=" .. __TS__NumberToFixed(meanSuccess, 1)) .. " missed=") .. __TS__NumberToFixed(meanMissed, 1)) .. " crashed=") .. __TS__NumberToFixed(meanCrashed, 1)) .. " baseline=") .. __TS__NumberToFixed(meanBase, 1)) .. " select=") .. __TS__NumberToFixed(meanSelect, 1) -- 357
				local failures = {} -- 361
				for ____, p in ipairs(switchProblems) do -- 362
					failures[#failures + 1] = "level switch: " .. p -- 362
				end -- 362
				if meanSuccess < 0 then -- 362
					failures[#failures + 1] = "success shot unreadable" -- 363
				end -- 363
				if meanMissed < 0 then -- 363
					failures[#failures + 1] = "missed shot unreadable" -- 364
				end -- 364
				if meanCrashed < 0 then -- 364
					failures[#failures + 1] = "crashed shot unreadable" -- 365
				end -- 365
				if meanBase < 0 then -- 365
					failures[#failures + 1] = "baseline shot unreadable" -- 366
				end -- 366
				if meanSelect < 0 then -- 366
					failures[#failures + 1] = "level select shot unreadable" -- 367
				end -- 367
				if not reportHasRegions(rSuccess) then -- 367
					failures[#failures + 1] = "success panel has no rendered region" -- 368
				end -- 368
				if not reportHasRegions(rCrashed) then -- 368
					failures[#failures + 1] = "crashed panel has no rendered region" -- 369
				end -- 369
				if not reportHasRegions(rSelect) then -- 369
					failures[#failures + 1] = "level select has no rendered region" -- 370
				end -- 370
				if meanBase >= 0 and meanCrashed >= 0 and not (meanCrashed < meanBase) then -- 370
					failures[#failures + 1] = ((("panel is not drawn above the scene (mean " .. __TS__NumberToFixed(meanCrashed, 1)) .. " >= ") .. __TS__NumberToFixed(meanBase, 1)) .. ")" -- 372
				end -- 372
				if meanBase >= 0 and meanSelect >= 0 and not (meanSelect < meanBase) then -- 372
					failures[#failures + 1] = ((("level select is not drawn above the scene (mean " .. __TS__NumberToFixed(meanSelect, 1)) .. " >= ") .. __TS__NumberToFixed(meanBase, 1)) .. ")" -- 375
				end -- 375
				lines[#lines + 1] = (("levels=" .. __TS__NumberToFixed(levelTotal, 0)) .. " failures=") .. __TS__NumberToFixed(#failures, 0) -- 377
				if #failures == 0 then -- 377
					lines[#lines + 1] = "RESULT=PASS" -- 380
				else -- 380
					for ____, f in ipairs(failures) do -- 382
						lines[#lines + 1] = "reason: " .. f -- 382
					end -- 382
					lines[#lines + 1] = "RESULT=FAIL" -- 383
				end -- 383
				flush(true) -- 385
				return true -- 386
			end -- 386
			return false -- 389
		end) -- 269
	end -- 269
end -- 269
return ____exports -- 269