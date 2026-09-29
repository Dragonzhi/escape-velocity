-- [ts]: PresentationProbe.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 2
local Content = ____Dora.Content -- 2
local Director = ____Dora.Director -- 2
local Node = ____Dora.Node -- 2
local Path = ____Dora.Path -- 2
local Size = ____Dora.Size -- 2
local Vec2 = ____Dora.Vec2 -- 2
local View = ____Dora.View -- 2
local threadLoop = ____Dora.threadLoop -- 2
local root = Path(Content.writablePath, "escape-velocity") -- 3
do -- 3
	local i = 0 -- 4
	while i < #Content.searchPaths do -- 4
		local p = Content.searchPaths[i + 1] -- 5
		if Content:exist(Path(p, "game", "Ui.lua")) and Content:exist(Path(p, "init.lua")) then -- 5
			root = p -- 6
			break -- 6
		end -- 6
		i = i + 1 -- 4
	end -- 4
end -- 4
Content:addSearchPath(root) -- 8
local Ui = require("game.Ui") -- 9
local Vision = require("Test.Vision") -- 10
local marker = Path(root, ".agent", "test-results", "presentation-probe.txt") -- 11
Content:save(marker, "phase=running") -- 12
local icons = { -- 13
	"pause", -- 13
	"play", -- 13
	"slow", -- 13
	"fast", -- 13
	"launch", -- 13
	"cancel", -- 13
	"retry", -- 13
	"back", -- 13
	"camera", -- 13
	"stop", -- 13
	"minus", -- 13
	"plus", -- 13
	"fit" -- 13
} -- 13
local buttons = {} -- 14
local layer = Node() -- 15
layer.size = Size(View.size.width, View.size.height) -- 15
layer.anchor = Vec2(0, 0) -- 15
layer.position = Vec2(-View.size.width / 2, -View.size.height / 2) -- 16
Director.ui:addChild(layer) -- 16
do -- 16
	local i = 0 -- 17
	while i < #icons do -- 17
		local b = Ui.createButton( -- 18
			layer, -- 18
			{ -- 18
				w = 72, -- 18
				h = 72, -- 18
				text = "", -- 18
				icon = icons[i + 1], -- 18
				fontSize = 20, -- 18
				bgHex = 1319732, -- 18
				fgHex = 15398143, -- 18
				borderHex = 5143454, -- 18
				onTap = function() -- 18
				end -- 18
			} -- 18
		) -- 18
		b.root.position = Vec2( -- 19
			24 + i % 5 * 80, -- 19
			View.size.height - 120 - math.floor(i / 5) * 80 -- 19
		) -- 19
		buttons[#buttons + 1] = b -- 19
		i = i + 1 -- 17
	end -- 17
end -- 17
buttons[3]:setEnabled(false) -- 21
buttons[5]:setSelected(true) -- 21
local elapsed = 0 -- 22
local updated = false -- 23
local shot = "" -- 24
threadLoop(function() -- 25
	elapsed = elapsed + App.deltaTime -- 26
	if elapsed < 0.5 then -- 26
		return false -- 27
	end -- 27
	if not updated then -- 27
		buttons[1]:setIcon("play") -- 28
		updated = true -- 28
	end -- 28
	if elapsed < 1 then -- 28
		return false -- 29
	end -- 29
	if shot == "" then -- 29
		shot = App:saveScreenshot(Path(root, ".agent", "test-results", "presentation-buttons")) -- 30
		return false -- 30
	end -- 30
	if elapsed < 1.3 then -- 30
		return false -- 31
	end -- 31
	local report = Vision.captureReport(shot, {"dynamic pause changed to play; compare first two buttons"}) -- 32
	Content:save( -- 33
		marker, -- 33
		((((((("iconSize=" .. tostring(buttons[1].root.width)) .. "x") .. tostring(buttons[1].root.height)) .. "\ndisabledTouch=") .. tostring(buttons[3].root.touchEnabled)) .. "\n") .. report) .. "\nphase=done" -- 33
	) -- 33
	return true -- 34
end) -- 25
return ____exports -- 25