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
local ____PlanView = require("game.PlanView") -- 25
local createPlanView = ____PlanView.createPlanView -- 25
local defaultPlanOptions = ____PlanView.defaultPlanOptions -- 25
local ____Vision = require("Test.Vision") -- 26
local captureReport = ____Vision.captureReport -- 26
local root = Content.searchPaths[1] -- 28
local outDir = Path(root, ".agent", "test-results") -- 29
if not Content:exist(outDir) then -- 29
	Content:mkdir(outDir) -- 30
end -- 30
local marker = Path(outDir, "s22-ui.txt") -- 31
local lines = {} -- 33
local function flush(final) -- 34
	Content:save( -- 35
		marker, -- 35
		table.concat(lines, "\n") .. (final and "\nphase=done" or "") -- 35
	) -- 35
end -- 34
lines[#lines + 1] = "phase=started" -- 37
flush(false) -- 38
--- 从 captureReport 的文本里取平均亮度（报告里是 `samples=N mean=X min=.. max=..`）。
local function reportMean(report) -- 41
	for ____, rawLine in ipairs(__TS__StringSplit(report, "\n")) do -- 42
		do -- 42
			local line = __TS__StringTrim(rawLine) -- 43
			if (string.find(line, "mean=", nil, true) or 0) - 1 < 0 then -- 43
				goto __continue5 -- 44
			end -- 44
			for ____, token in ipairs(__TS__StringSplit(line, " ")) do -- 45
				if __TS__StringStartsWith(token, "mean=") then -- 45
					return __TS__ParseFloat(__TS__StringSubstring(token, 5)) -- 46
				end -- 46
			end -- 46
		end -- 46
		::__continue5:: -- 46
	end -- 46
	return -1 -- 49
end -- 41
--- 报告里是否检出了区域（Vision 在没有任何亮块时会写 NONE）。
local function reportHasRegions(report) -- 53
	return (string.find(report, "== regions", nil, true) or 0) - 1 >= 0 and (string.find(report, "NONE", nil, true) or 0) - 1 < 0 -- 54
end -- 53
local levelTotal = 6 -- 57
local levelDef = getLevel(0) -- 58
if levelDef == nil then -- 58
	lines[#lines + 1] = "RESULT=FAIL reason=no-level-data" -- 61
	flush(true) -- 62
else -- 62
	local viewW = View.size.width -- 64
	local viewH = View.size.height -- 65
	lines[#lines + 1] = (("view=" .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0) -- 66
	local bodies = scaledPlanets(levelDef) -- 68
	local level = { -- 69
		bodies = bodies, -- 70
		probeStart = levelDef.probeStart, -- 71
		goal = levelDef.goal, -- 72
		escapeRadius = levelDef.escapeRadius, -- 73
		maxSteps = levelDef.maxSteps -- 74
	} -- 74
	Director.entry:setEnvironmentIntensity(0.35, 0.35, 1) -- 77
	local levelLayer = Node() -- 80
	levelLayer.size = Size(viewW, viewH) -- 81
	levelLayer.anchor = Vec2(0.5, 0.5) -- 82
	levelLayer.position = Vec2(0, 0) -- 83
	Director.ui:addChild(levelLayer) -- 84
	local uiLayer = Node() -- 86
	uiLayer.size = Size(viewW, viewH) -- 87
	uiLayer.anchor = Vec2(0.5, 0.5) -- 88
	uiLayer.position = Vec2(0, 0) -- 89
	Director.ui:addChild(uiLayer) -- 90
	local world = Node3D() -- 92
	Director.entry:addChild(world) -- 93
	local scene = buildScene({ -- 95
		root = world, -- 96
		bodies = bodies, -- 97
		visuals = levelDef.visuals, -- 98
		probeStart = level.probeStart, -- 99
		probeScale = 1.6, -- 100
		spherePath = "Assets/Model/Sphere.gltf", -- 101
		ringPath = "Assets/Model/Ring.gltf", -- 102
		probePath = "Assets/Model/Probe.gltf" -- 103
	}) -- 103
	if scene == nil then -- 103
		lines[#lines + 1] = "RESULT=FAIL reason=scene" -- 107
		flush(true) -- 108
	else -- 108
		local camera = Camera3D() -- 110
		Director:pushCamera(camera) -- 111
		local rig = createCameraRig(defaultRigOptions()) -- 112
		local trajectory = createTrajectoryView( -- 113
			levelLayer, -- 113
			trajectoryOptions() -- 113
		) -- 113
		local plan = createPlanView( -- 115
			levelLayer, -- 115
			viewW, -- 115
			viewH, -- 115
			defaultPlanOptions() -- 115
		) -- 115
		local aim = createAimInput(levelLayer, viewW, viewH) -- 116
		local game = createGame( -- 118
			level, -- 118
			{ -- 118
				scene = scene, -- 119
				camera = camera, -- 120
				rig = rig, -- 121
				trajectory = trajectory, -- 122
				plan = plan, -- 123
				visuals = {}, -- 124
				setWorldVisible = function() -- 125
				end, -- 125
				aim = aim, -- 126
				viewW = viewW, -- 127
				viewH = viewH, -- 128
				fovYDeg = View.fieldOfView, -- 129
				aspect = View.aspectRatio, -- 130
				onPhase = function() -- 131
				end, -- 131
				onResult = function() -- 132
				end -- 132
			} -- 132
		) -- 132
		game:toggleViewMode() -- 134
		aim:onDrag(function(a) return game:onAimDrag(a) end) -- 135
		--- 关卡切换检查（S2.3 的真正风险点）。
		-- 
		-- init.ts 的 ensureLevel 要按同样的调用序列再建一关：Node3D 容器 → buildScene
		-- → 相机 → 轨迹/矄准 → createGame，然后切 visible + pushCamera + startLevel。
		-- 这些调用**只有真跑一遍才知道会不会 nil**，所以探针照抄这条路径
		-- （探针不能 import init.ts —— 入口脚本不可被 require）。
		-- 
		-- @returns 失败原因（空数组 = 全过）
		local function probeLevelSwitch() -- 147
			local problems = {} -- 148
			local def2 = getLevel(1) -- 149
			if def2 == nil then -- 149
				problems[#problems + 1] = "level 2 data missing" -- 151
				return problems -- 152
			end -- 152
			local bodies2 = scaledPlanets(def2) -- 155
			local level2 = { -- 156
				bodies = bodies2, -- 157
				probeStart = def2.probeStart, -- 158
				goal = def2.goal, -- 159
				escapeRadius = def2.escapeRadius, -- 160
				maxSteps = def2.maxSteps -- 161
			} -- 161
			local layer2 = Node() -- 165
			layer2.size = Size(viewW, viewH) -- 166
			layer2.anchor = Vec2(0.5, 0.5) -- 167
			layer2.position = Vec2(0, 0) -- 168
			Director.ui:addChild(layer2) -- 169
			local world2 = Node3D() -- 171
			Director.entry:addChild(world2) -- 172
			world2.visible = false -- 173
			local scene2 = buildScene({ -- 175
				root = world2, -- 176
				bodies = bodies2, -- 177
				visuals = def2.visuals, -- 178
				probeStart = level2.probeStart, -- 179
				probeScale = 1.6, -- 180
				spherePath = "Assets/Model/Sphere.gltf", -- 181
				ringPath = "Assets/Model/Ring.gltf", -- 182
				probePath = "Assets/Model/Probe.gltf" -- 183
			}) -- 183
			if scene2 == nil then -- 183
				problems[#problems + 1] = "level 2 scene build failed" -- 186
				return problems -- 187
			end -- 187
			local camera2 = Camera3D() -- 190
			local rig2 = createCameraRig(defaultRigOptions()) -- 191
			local trajectory2 = createTrajectoryView( -- 192
				layer2, -- 192
				trajectoryOptions() -- 192
			) -- 192
			local plan2 = createPlanView( -- 193
				layer2, -- 193
				viewW, -- 193
				viewH, -- 193
				defaultPlanOptions() -- 193
			) -- 193
			local aim2 = createAimInput(layer2, viewW, viewH) -- 194
			local game2 = createGame( -- 195
				level2, -- 195
				{ -- 195
					scene = scene2, -- 196
					camera = camera2, -- 197
					rig = rig2, -- 198
					trajectory = trajectory2, -- 199
					plan = plan2, -- 200
					visuals = {}, -- 201
					setWorldVisible = function() -- 202
					end, -- 202
					aim = aim2, -- 203
					viewW = viewW, -- 204
					viewH = viewH, -- 205
					fovYDeg = View.fieldOfView, -- 206
					aspect = View.aspectRatio, -- 207
					onPhase = function() -- 208
					end, -- 208
					onResult = function() -- 209
					end -- 209
				} -- 209
			) -- 209
			world.visible = false -- 213
			aim:setEnabled(false) -- 214
			world2.visible = true -- 215
			Director:pushCamera(camera2) -- 216
			game2:startLevel() -- 217
			game2:update(App.deltaTime) -- 218
			if game2:phase() ~= "Aiming" then -- 218
				problems[#problems + 1] = "level 2 did not enter Aiming: " .. game2:phase() -- 220
			end -- 220
			if world.visible then -- 220
				problems[#problems + 1] = "level 1 world still visible after switch" -- 221
			end -- 221
			if not world2.visible then -- 221
				problems[#problems + 1] = "level 2 world not visible after switch" -- 222
			end -- 222
			if game:phase() ~= "Aiming" then -- 222
				problems[#problems + 1] = "level 1 core phase changed: " .. game:phase() -- 223
			end -- 223
			world2.visible = false -- 226
			aim2:setEnabled(false) -- 227
			world.visible = true -- 228
			Director:pushCamera(camera) -- 229
			game:startLevel() -- 230
			game:update(App.deltaTime) -- 231
			if game:phase() ~= "Aiming" then -- 231
				problems[#problems + 1] = "level 1 did not return to Aiming: " .. game:phase() -- 232
			end -- 232
			lines[#lines + 1] = "level switch L1 -> L2 -> L1 done, game2.phase=" .. game2:phase() -- 234
			return problems -- 235
		end -- 147
		local switchProblems = probeLevelSwitch() -- 239
		lines[#lines + 1] = "switchProblems=" .. __TS__NumberToFixed(#switchProblems, 0) -- 240
		flush(false) -- 241
		local unlockedForShot = 2 -- 245
		local panel = createResultPanel( -- 247
			uiLayer, -- 247
			viewW, -- 247
			viewH, -- 247
			{ -- 247
				onRetry = function() -- 248
					lines[#lines + 1] = "tap: retry button" -- 249
					flush(false) -- 250
				end, -- 248
				onBackToSelect = function() -- 252
					lines[#lines + 1] = "tap: back-to-select button" -- 253
					flush(false) -- 254
				end -- 252
			} -- 252
		) -- 252
		local select = createLevelSelect( -- 257
			uiLayer, -- 257
			viewW, -- 257
			viewH, -- 257
			{ -- 257
				levels = { -- 258
					{name = "L1 直飞"}, -- 259
					{name = "L2 第一次弯曲"}, -- 260
					{name = "L3 从背后抄过去"}, -- 261
					{name = "L4 它动了"}, -- 262
					{name = "L5 两连弹"}, -- 263
					{name = "L6 贴着过去"} -- 264
				}, -- 264
				onPick = function(____, index) -- 266
					lines[#lines + 1] = "tap: level button " .. __TS__NumberToFixed(index + 1, 0) -- 267
					flush(false) -- 268
				end -- 266
			} -- 266
		) -- 266
		local frame = 0 -- 272
		local shotSuccess = "" -- 273
		local shotMissed = "" -- 274
		local shotCrashed = "" -- 275
		local shotBaseline = "" -- 276
		local shotSelect = "" -- 277
		local done = false -- 278
		threadLoop(function() -- 280
			frame = frame + 1 -- 281
			game:update(App.deltaTime) -- 282
			if frame == 15 then -- 282
				panel:show("success", "L1 直飞") -- 286
				lines[#lines + 1] = "show success @f" .. __TS__NumberToFixed(frame, 0) -- 287
				flush(false) -- 288
			end -- 288
			if frame == 18 then -- 288
				shotSuccess = App:saveScreenshot(Path(outDir, "s22-result-success")) -- 291
			end -- 291
			if frame == 26 then -- 291
				panel:show("missed", "L1 直飞") -- 295
				lines[#lines + 1] = "show missed @f" .. __TS__NumberToFixed(frame, 0) -- 296
				flush(false) -- 297
			end -- 297
			if frame == 29 then -- 297
				shotMissed = App:saveScreenshot(Path(outDir, "s22-result-missed")) -- 300
			end -- 300
			if frame == 37 then -- 300
				panel:show("crashed", "L1 直飞") -- 304
				lines[#lines + 1] = "show crashed @f" .. __TS__NumberToFixed(frame, 0) -- 305
				flush(false) -- 306
			end -- 306
			if frame == 40 then -- 306
				shotCrashed = App:saveScreenshot(Path(outDir, "s22-result-crashed")) -- 309
			end -- 309
			if frame == 48 then -- 309
				panel:hide() -- 314
				lines[#lines + 1] = "panel hidden @f" .. __TS__NumberToFixed(frame, 0) -- 315
				flush(false) -- 316
			end -- 316
			if frame == 51 then -- 316
				shotBaseline = App:saveScreenshot(Path(outDir, "s22-nopanel")) -- 319
			end -- 319
			if frame == 59 then -- 319
				select:show(unlockedForShot) -- 323
				lines[#lines + 1] = (("level select shown @f" .. __TS__NumberToFixed(frame, 0)) .. " unlocked=") .. __TS__NumberToFixed(unlockedForShot, 0) -- 324
				flush(false) -- 325
			end -- 325
			if frame == 62 then -- 325
				shotSelect = App:saveScreenshot(Path(outDir, "s22-levelselect")) -- 328
			end -- 328
			if frame == 72 and not done then -- 328
				done = true -- 333
				lines[#lines + 1] = "" -- 334
				lines[#lines + 1] = "--- result panel: success ---"
				local rSuccess = captureReport(shotSuccess, {"s22 result panel: success"}) -- 336
				lines[#lines + 1] = rSuccess -- 337
				lines[#lines + 1] = "" -- 338
				lines[#lines + 1] = "--- result panel: missed ---"
				local rMissed = captureReport(shotMissed, {"s22 result panel: missed"}) -- 340
				lines[#lines + 1] = rMissed -- 341
				lines[#lines + 1] = "" -- 342
				lines[#lines + 1] = "--- result panel: crashed ---"
				local rCrashed = captureReport(shotCrashed, {"s22 result panel: crashed"}) -- 344
				lines[#lines + 1] = rCrashed -- 345
				lines[#lines + 1] = "" -- 346
				lines[#lines + 1] = "--- baseline: no panel (same camera) ---"
				local rBase = captureReport(shotBaseline, {"s22 baseline without panel"}) -- 348
				lines[#lines + 1] = rBase -- 349
				lines[#lines + 1] = "" -- 350
				lines[#lines + 1] = "--- level select (unlocked=2 -> 3/6) ---"
				local rSelect = captureReport(shotSelect, {"s22 level select, unlocked=2"}) -- 352
				lines[#lines + 1] = rSelect -- 353
				local meanSuccess = reportMean(rSuccess) -- 355
				local meanMissed = reportMean(rMissed) -- 356
				local meanCrashed = reportMean(rCrashed) -- 357
				local meanBase = reportMean(rBase) -- 358
				local meanSelect = reportMean(rSelect) -- 359
				lines[#lines + 1] = "" -- 361
				lines[#lines + 1] = "--- checks ---"
				lines[#lines + 1] = "shot success=" .. shotSuccess -- 363
				lines[#lines + 1] = "shot missed=" .. shotMissed -- 364
				lines[#lines + 1] = "shot crashed=" .. shotCrashed -- 365
				lines[#lines + 1] = "shot baseline=" .. shotBaseline -- 366
				lines[#lines + 1] = "shot select=" .. shotSelect -- 367
				lines[#lines + 1] = (((((((("mean success=" .. __TS__NumberToFixed(meanSuccess, 1)) .. " missed=") .. __TS__NumberToFixed(meanMissed, 1)) .. " crashed=") .. __TS__NumberToFixed(meanCrashed, 1)) .. " baseline=") .. __TS__NumberToFixed(meanBase, 1)) .. " select=") .. __TS__NumberToFixed(meanSelect, 1) -- 368
				local failures = {} -- 372
				for ____, p in ipairs(switchProblems) do -- 373
					failures[#failures + 1] = "level switch: " .. p -- 373
				end -- 373
				if meanSuccess < 0 then -- 373
					failures[#failures + 1] = "success shot unreadable" -- 374
				end -- 374
				if meanMissed < 0 then -- 374
					failures[#failures + 1] = "missed shot unreadable" -- 375
				end -- 375
				if meanCrashed < 0 then -- 375
					failures[#failures + 1] = "crashed shot unreadable" -- 376
				end -- 376
				if meanBase < 0 then -- 376
					failures[#failures + 1] = "baseline shot unreadable" -- 377
				end -- 377
				if meanSelect < 0 then -- 377
					failures[#failures + 1] = "level select shot unreadable" -- 378
				end -- 378
				if not reportHasRegions(rSuccess) then -- 378
					failures[#failures + 1] = "success panel has no rendered region" -- 379
				end -- 379
				if not reportHasRegions(rCrashed) then -- 379
					failures[#failures + 1] = "crashed panel has no rendered region" -- 380
				end -- 380
				if not reportHasRegions(rSelect) then -- 380
					failures[#failures + 1] = "level select has no rendered region" -- 381
				end -- 381
				if meanBase >= 0 and meanCrashed >= 0 and not (meanCrashed < meanBase) then -- 381
					failures[#failures + 1] = ((("panel is not drawn above the scene (mean " .. __TS__NumberToFixed(meanCrashed, 1)) .. " >= ") .. __TS__NumberToFixed(meanBase, 1)) .. ")" -- 383
				end -- 383
				if meanBase >= 0 and meanSelect >= 0 and not (meanSelect < meanBase) then -- 383
					failures[#failures + 1] = ((("level select is not drawn above the scene (mean " .. __TS__NumberToFixed(meanSelect, 1)) .. " >= ") .. __TS__NumberToFixed(meanBase, 1)) .. ")" -- 386
				end -- 386
				lines[#lines + 1] = (("levels=" .. __TS__NumberToFixed(levelTotal, 0)) .. " failures=") .. __TS__NumberToFixed(#failures, 0) -- 388
				if #failures == 0 then -- 388
					lines[#lines + 1] = "RESULT=PASS" -- 391
				else -- 391
					for ____, f in ipairs(failures) do -- 393
						lines[#lines + 1] = "reason: " .. f -- 393
					end -- 393
					lines[#lines + 1] = "RESULT=FAIL" -- 394
				end -- 394
				flush(true) -- 396
				return true -- 397
			end -- 397
			return false -- 400
		end) -- 280
	end -- 280
end -- 280
return ____exports -- 280