-- [ts]: ProjectionProbe.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 10
local Camera3D = ____Dora.Camera3D -- 10
local Content = ____Dora.Content -- 10
local Director = ____Dora.Director -- 10
local Path = ____Dora.Path -- 10
local Vec2 = ____Dora.Vec2 -- 10
local Vec3 = ____Dora.Vec3 -- 10
local View = ____Dora.View -- 10
local threadLoop = ____Dora.threadLoop -- 10
local ____Projection = require("game.Projection") -- 11
local HANDEDNESS = ____Projection.HANDEDNESS -- 11
local FLIP_Y = ____Projection.FLIP_Y -- 11
local project = ____Projection.project -- 11
local resultDir = Path(Content.searchPaths[1], ".agent", "test-results") -- 13
if not Content:exist(resultDir) then -- 13
	Content:mkdir(resultDir) -- 14
end -- 14
local markerPath = Path(resultDir, "s0-projection.txt") -- 15
local lines = {} -- 17
local function flush(result) -- 18
	Content:save( -- 19
		markerPath, -- 19
		(result .. "\n") .. table.concat(lines, "\n") -- 19
	) -- 19
end -- 18
local EYE = {x = 3, y = 4, z = 8} -- 22
local WORLD = { -- 23
	{x = 0, y = 0, z = 0}, -- 24
	{x = 4, y = 0, z = 0}, -- 25
	{x = -4, y = 0, z = 0}, -- 26
	{x = 0, y = 3, z = 0}, -- 27
	{x = 0, y = -3, z = 0} -- 28
} -- 28
local TAGS = { -- 30
	"origin", -- 30
	"+x", -- 30
	"-x", -- 30
	"+y", -- 30
	"-y" -- 30
} -- 30
lines[#lines + 1] = "phase=started" -- 32
flush("RESULT=PENDING") -- 33
do -- 33
	local function ____catch(e) -- 33
		lines[#lines + 1] = "phase=exception" -- 126
		flush("RESULT=FAIL") -- 127
	end -- 127
	local ____try, ____hasReturned = pcall(function() -- 127
		local camera = Camera3D() -- 36
		camera:lookAt( -- 37
			Vec3(EYE.x, EYE.y, EYE.z), -- 37
			Vec3(0, 0, 0) -- 37
		) -- 37
		Director:pushCamera(camera) -- 38
		local W = View.size.width -- 40
		local H = View.size.height -- 41
		local cam = { -- 42
			eye = EYE, -- 43
			target = {x = 0, y = 0, z = 0}, -- 44
			up = {x = 0, y = 1, z = 0}, -- 45
			fovYDeg = View.fieldOfView, -- 46
			aspect = View.aspectRatio, -- 47
			viewW = W, -- 48
			viewH = H -- 49
		} -- 49
		lines[#lines + 1] = (((((("view=" .. tostring(W)) .. "x") .. tostring(H)) .. " fov=") .. tostring(View.fieldOfView)) .. " aspect=") .. tostring(View.aspectRatio) -- 51
		local function evalAt(px, py, p) -- 53
			local d = Director.entry:getRayDirection(Vec2(px, py)) -- 54
			local ox = p.x - EYE.x -- 55
			local oy = p.y - EYE.y -- 55
			local oz = p.z - EYE.z -- 55
			local ol = math.sqrt(ox * ox + oy * oy + oz * oz) -- 56
			if ol < 0.000001 then -- 56
				return -2 -- 57
			end -- 57
			return d.x * (ox / ol) + d.y * (oy / ol) + d.z * (oz / ol) -- 58
		end -- 53
		local truePos = {} -- 61
		local pi = 0 -- 62
		local coarse = true -- 63
		local step = 48 -- 64
		local bestX = 0 -- 65
		local bestY = 0 -- 65
		local bestDot = -2 -- 65
		local cx = 0 -- 66
		local cy = 0 -- 66
		local frames = 0 -- 67
		threadLoop(function() -- 69
			frames = frames + 1 -- 70
			if pi >= #WORLD or frames > 4000 then -- 70
				local errors = {} -- 73
				do -- 73
					local k = 0 -- 74
					while k < #truePos do -- 74
						do -- 74
							local p = project(WORLD[k + 1], cam, HANDEDNESS, FLIP_Y) -- 75
							if p == nil then -- 75
								errors[#errors + 1] = 1000000000 -- 76
								goto __continue10 -- 76
							end -- 76
							local vx = W / 2 + p.x -- 77
							local vy = H / 2 + p.y -- 78
							local ex = vx - truePos[k + 1].x -- 79
							local ey = vy - truePos[k + 1].y -- 80
							local e = math.sqrt(ex * ex + ey * ey) -- 81
							errors[#errors + 1] = e -- 82
							lines[#lines + 1] = ((((((((((("[" .. TAGS[k + 1]) .. "] true=(") .. tostring(truePos[k + 1].x)) .. ", ") .. tostring(truePos[k + 1].y)) .. ") mine=(") .. __TS__NumberToFixed(vx, 1)) .. ", ") .. __TS__NumberToFixed(vy, 1)) .. ") err=") .. __TS__NumberToFixed(e, 2)) .. "px" -- 83
						end -- 83
						::__continue10:: -- 83
						k = k + 1 -- 74
					end -- 74
				end -- 74
				local maxErr = 0 -- 85
				for ____, e in ipairs(errors) do -- 86
					if e > maxErr then -- 86
						maxErr = e -- 86
					end -- 86
				end -- 86
				lines[#lines + 1] = "maxPxErr=" .. __TS__NumberToFixed(maxErr, 2) -- 87
				local pass = #errors == #WORLD and maxErr < 2 -- 88
				flush(pass and "RESULT=PASS" or "RESULT=FAIL") -- 89
				return false -- 90
			end -- 90
			local ops = 0 -- 93
			while ops < 400 and pi < #WORLD do -- 93
				local d = evalAt(cx, cy, WORLD[pi + 1]) -- 95
				if d > bestDot then -- 95
					bestDot = d -- 96
					bestX = cx -- 96
					bestY = cy -- 96
				end -- 96
				cx = cx + step -- 97
				local xStart = math.max(0, bestX - 48) -- 98
				local yStart = math.max(0, bestY - 48) -- 99
				if coarse then -- 99
					if cx > W then -- 99
						cx = 0 -- 101
						cy = cy + step -- 101
					end -- 101
					if cy > H then -- 101
						coarse = false -- 103
						step = 2 -- 104
						cx = xStart -- 105
						cy = yStart -- 106
						bestDot = -2 -- 107
					end -- 107
				else -- 107
					if cx > math.min(W, bestX + 48) then -- 107
						cx = xStart -- 110
						cy = cy + step -- 110
					end -- 110
					if cy > math.min(H, bestY + 48) then -- 110
						truePos[#truePos + 1] = {x = bestX, y = bestY} -- 112
						pi = pi + 1 -- 113
						coarse = true -- 114
						step = 48 -- 115
						cx = 0 -- 116
						cy = 0 -- 117
						bestDot = -2 -- 118
					end -- 118
				end -- 118
				ops = ops + 1 -- 121
			end -- 121
			return false -- 123
		end) -- 69
	end) -- 69
	if not ____try then -- 69
		____catch(____hasReturned) -- 69
	end -- 69
end -- 69
return ____exports -- 69