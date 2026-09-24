-- [ts]: ClearTest.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 12
local App = ____Dora.App -- 12
local BlendFunc = ____Dora.BlendFunc -- 12
local Color = ____Dora.Color -- 12
local Content = ____Dora.Content -- 12
local Director = ____Dora.Director -- 12
local DrawNode = ____Dora.DrawNode -- 12
local Path = ____Dora.Path -- 12
local Vec2 = ____Dora.Vec2 -- 12
local threadLoop = ____Dora.threadLoop -- 12
local ____Vision = require("Test.Vision") -- 13
local captureReport = ____Vision.captureReport -- 13
local root = Content.searchPaths[1] -- 15
local outDir = Path(root, ".agent", "test-results") -- 16
if not Content:exist(outDir) then -- 16
	Content:mkdir(outDir) -- 17
end -- 17
local marker = Path(outDir, "s21-clear-test.txt") -- 18
local lines = {} -- 20
local function flush(final) -- 21
	Content:save( -- 22
		marker, -- 22
		table.concat(lines, "\n") .. (final and "\nphase=done" or "") -- 22
	) -- 22
end -- 21
lines[#lines + 1] = "phase=started" -- 24
flush(false) -- 25
local draw = DrawNode() -- 27
draw.blendFunc = BlendFunc("One", "One") -- 28
Director.ui:addChild(draw) -- 29
local white = Color(255, 255, 255, 255) -- 32
draw:drawSegment( -- 33
	Vec2(-300, 300), -- 33
	Vec2(300, 300), -- 33
	6, -- 33
	white -- 33
) -- 33
draw:drawDot( -- 34
	Vec2(0, 300), -- 34
	10, -- 34
	white -- 34
) -- 34
local frame = 0 -- 36
local shotA = "" -- 37
local shotB = "" -- 38
local cleared = false -- 39
threadLoop(function() -- 41
	frame = frame + 1 -- 42
	if frame == 5 then -- 42
		shotA = App:saveScreenshot(Path(outDir, "s21-clear-before")) -- 46
		lines[#lines + 1] = "shot A (line drawn) @f" .. tostring(frame) -- 47
		flush(false) -- 48
	end -- 48
	if frame == 8 and not cleared then -- 48
		cleared = true -- 53
		draw:clear() -- 54
		lines[#lines + 1] = "clear() called @f" .. tostring(frame) -- 55
		flush(false) -- 56
	end -- 56
	if frame == 15 then -- 56
		shotB = App:saveScreenshot(Path(outDir, "s21-clear-after")) -- 61
		lines[#lines + 1] = "shot B (after clear) @f" .. tostring(frame) -- 62
		flush(false) -- 63
	end -- 63
	if frame == 20 then -- 63
		lines[#lines + 1] = "" -- 67
		lines[#lines + 1] = "--- BEFORE clear (line should be visible at upper area) ---"
		lines[#lines + 1] = captureReport(shotA, {"expect: bright horizontal line at upper area"}) -- 69
		lines[#lines + 1] = "" -- 70
		lines[#lines + 1] = "--- AFTER clear (line should be GONE) ---"
		lines[#lines + 1] = captureReport(shotB, {"expect: empty (no line)"}) -- 72
		lines[#lines + 1] = "" -- 73
		lines[#lines + 1] = "RESULT=DONE" -- 74
		flush(true) -- 75
		return true -- 76
	end -- 76
	return false -- 79
end) -- 41
return ____exports -- 41