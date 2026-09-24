-- [ts]: CameraProbe.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 11
local Content = ____Dora.Content -- 11
local Path = ____Dora.Path -- 11
local View = ____Dora.View -- 11
local ____Projection = require("game.Projection") -- 12
local HANDEDNESS = ____Projection.HANDEDNESS -- 12
local FLIP_Y = ____Projection.FLIP_Y -- 12
local project = ____Projection.project -- 12
local resultPath = Path(Content.searchPaths[1], ".agent", "test-results", "s0-camera.txt") -- 14
local lines = {} -- 15
local DESIGN_W = 1080 -- 18
local DESIGN_H = 1920 -- 19
local PORTRAIT_ASPECT = DESIGN_W / DESIGN_H -- 20
lines[#lines + 1] = (((("portrait design = " .. tostring(DESIGN_W)) .. "x") .. tostring(DESIGN_H)) .. " aspect=") .. __TS__NumberToFixed(PORTRAIT_ASPECT, 4) -- 22
lines[#lines + 1] = ("engine fovY = " .. tostring(View.fieldOfView)) .. " (deg)" -- 23
lines[#lines + 1] = "" -- 24
--- 一条代表性轨道的关键世界点（物理平面为 XZ，y=0）。
local function trackPoints(vertical) -- 27
	local pts = {} -- 28
	if vertical then -- 28
		pts[#pts + 1] = {x = 0, y = 0, z = 9} -- 31
		pts[#pts + 1] = {x = 0, y = 0, z = -13} -- 32
		do -- 32
			local i = 0 -- 34
			while i < 16 do -- 34
				local a = i * math.pi * 2 / 16 -- 35
				pts[#pts + 1] = { -- 36
					x = math.sin(a) * 5, -- 36
					y = 0, -- 36
					z = math.cos(a) * 5 -- 36
				} -- 36
				i = i + 1 -- 34
			end -- 34
		end -- 34
	else -- 34
		pts[#pts + 1] = {x = -6, y = 0, z = 2} -- 40
		pts[#pts + 1] = {x = 10, y = 0, z = 2} -- 41
		do -- 41
			local i = 0 -- 42
			while i < 16 do -- 42
				local a = i * math.pi * 2 / 16 -- 43
				pts[#pts + 1] = { -- 44
					x = 2 + math.sin(a) * 5, -- 44
					y = 0, -- 44
					z = math.cos(a) * 5 -- 44
				} -- 44
				i = i + 1 -- 42
			end -- 42
		end -- 42
	end -- 42
	return pts -- 47
end -- 27
local function evaluate(pts, tiltDeg, dist, aspect, fovY) -- 56
	local tilt = tiltDeg * math.pi / 180 -- 57
	local target = {x = 0, y = 0, z = 0} -- 58
	local eye = { -- 60
		x = 0, -- 61
		y = math.sin(tilt) * dist, -- 62
		z = math.cos(tilt) * dist -- 63
	} -- 63
	local cam = { -- 65
		eye = eye, -- 66
		target = target, -- 67
		up = {x = 0, y = 1, z = 0}, -- 68
		fovYDeg = fovY, -- 69
		aspect = aspect, -- 70
		viewW = 1080, -- 71
		viewH = 1920 -- 72
	} -- 72
	local maxNdcX = 0 -- 75
	local maxNdcY = 0 -- 76
	local behind = false -- 77
	for ____, p in ipairs(pts) do -- 79
		do -- 79
			local q = project(p, cam, HANDEDNESS, FLIP_Y) -- 80
			if q == nil then -- 80
				behind = true -- 81
				goto __continue10 -- 81
			end -- 81
			local ndcX = math.abs(q.x) / (1080 / 2) -- 82
			local ndcY = math.abs(q.y) / (1920 / 2) -- 83
			if ndcX > maxNdcX then -- 83
				maxNdcX = ndcX -- 84
			end -- 84
			if ndcY > maxNdcY then -- 84
				maxNdcY = ndcY -- 85
			end -- 85
		end -- 85
		::__continue10:: -- 85
	end -- 85
	return {maxNdcX = maxNdcX, maxNdcY = maxNdcY, fits = not behind and maxNdcX <= 1 and maxNdcY <= 1} -- 88
end -- 56
lines[#lines + 1] = "== 1) horizontal track in PORTRAIT (aspect 0.5625) ==" -- 92
lines[#lines + 1] = "tilt=45deg, fovY=45" -- 93
local hPts = trackPoints(false) -- 94
lines[#lines + 1] = "dist | maxNdcX maxNdcY | fits" -- 95
for ____, d in ipairs({ -- 96
	10, -- 96
	15, -- 96
	20, -- 96
	25, -- 96
	30, -- 96
	40, -- 96
	50, -- 96
	70, -- 96
	100 -- 96
}) do -- 96
	local f = evaluate( -- 97
		hPts, -- 97
		45, -- 97
		d, -- 97
		PORTRAIT_ASPECT, -- 97
		View.fieldOfView -- 97
	) -- 97
	lines[#lines + 1] = (((((tostring(d) .. " | ") .. __TS__NumberToFixed(f.maxNdcX, 2)) .. " ") .. __TS__NumberToFixed(f.maxNdcY, 2)) .. " | ") .. tostring(f.fits) -- 98
end -- 98
lines[#lines + 1] = "" -- 100
lines[#lines + 1] = "== 2) vertical track in PORTRAIT (aspect 0.5625) ==" -- 103
lines[#lines + 1] = "tilt=45deg, fovY=45" -- 104
local vPts = trackPoints(true) -- 105
lines[#lines + 1] = "dist | maxNdcX maxNdcY | fits" -- 106
for ____, d in ipairs({ -- 107
	10, -- 107
	15, -- 107
	20, -- 107
	25, -- 107
	30, -- 107
	40, -- 107
	50, -- 107
	70, -- 107
	100 -- 107
}) do -- 107
	local f = evaluate( -- 108
		vPts, -- 108
		45, -- 108
		d, -- 108
		PORTRAIT_ASPECT, -- 108
		View.fieldOfView -- 108
	) -- 108
	lines[#lines + 1] = (((((tostring(d) .. " | ") .. __TS__NumberToFixed(f.maxNdcX, 2)) .. " ") .. __TS__NumberToFixed(f.maxNdcY, 2)) .. " | ") .. tostring(f.fits) -- 109
end -- 109
lines[#lines + 1] = "" -- 111
lines[#lines + 1] = "== 3) tilt sweep for VERTICAL track in PORTRAIT (dist=30) ==" -- 114
lines[#lines + 1] = "tilt | maxNdcX maxNdcY | fits" -- 115
for ____, t in ipairs({ -- 116
	20, -- 116
	30, -- 116
	40, -- 116
	50, -- 116
	60, -- 116
	70, -- 116
	80 -- 116
}) do -- 116
	local f = evaluate( -- 117
		vPts, -- 117
		t, -- 117
		30, -- 117
		PORTRAIT_ASPECT, -- 117
		View.fieldOfView -- 117
	) -- 117
	lines[#lines + 1] = (((((tostring(t) .. " | ") .. __TS__NumberToFixed(f.maxNdcX, 2)) .. " ") .. __TS__NumberToFixed(f.maxNdcY, 2)) .. " | ") .. tostring(f.fits) -- 118
end -- 118
lines[#lines + 1] = "" -- 120
lines[#lines + 1] = "== 4) horizontal vs vertical at identical camera (dist=30, tilt=45) ==" -- 123
local fh = evaluate( -- 124
	hPts, -- 124
	45, -- 124
	30, -- 124
	PORTRAIT_ASPECT, -- 124
	View.fieldOfView -- 124
) -- 124
local fv = evaluate( -- 125
	vPts, -- 125
	45, -- 125
	30, -- 125
	PORTRAIT_ASPECT, -- 125
	View.fieldOfView -- 125
) -- 125
lines[#lines + 1] = (((("horizontal: ndcX=" .. __TS__NumberToFixed(fh.maxNdcX, 2)) .. " ndcY=") .. __TS__NumberToFixed(fh.maxNdcY, 2)) .. " fits=") .. tostring(fh.fits) -- 126
lines[#lines + 1] = (((("vertical:   ndcX=" .. __TS__NumberToFixed(fv.maxNdcX, 2)) .. " ndcY=") .. __TS__NumberToFixed(fv.maxNdcY, 2)) .. " fits=") .. tostring(fv.fits) -- 127
lines[#lines + 1] = "" -- 128
lines[#lines + 1] = "== 5) same tracks in LANDSCAPE (aspect 1.6455) ==" -- 131
local land = View.aspectRatio -- 132
local fhL = evaluate( -- 133
	hPts, -- 133
	45, -- 133
	30, -- 133
	land, -- 133
	View.fieldOfView -- 133
) -- 133
local fvL = evaluate( -- 134
	vPts, -- 134
	45, -- 134
	30, -- 134
	land, -- 134
	View.fieldOfView -- 134
) -- 134
lines[#lines + 1] = (((("horizontal: ndcX=" .. __TS__NumberToFixed(fhL.maxNdcX, 2)) .. " ndcY=") .. __TS__NumberToFixed(fhL.maxNdcY, 2)) .. " fits=") .. tostring(fhL.fits) -- 135
lines[#lines + 1] = (((("vertical:   ndcX=" .. __TS__NumberToFixed(fvL.maxNdcX, 2)) .. " ndcY=") .. __TS__NumberToFixed(fvL.maxNdcY, 2)) .. " fits=") .. tostring(fvL.fits) -- 136
lines[#lines + 1] = "" -- 137
local vFit = evaluate( -- 140
	vPts, -- 140
	45, -- 140
	30, -- 140
	PORTRAIT_ASPECT, -- 140
	View.fieldOfView -- 140
) -- 140
lines[#lines + 1] = "RESULT=" .. (vFit.fits and "PASS" or "FAIL") -- 141
lines[#lines + 1] = "note: vertical layout means the flight path runs up the screen (along world Z)." -- 142
Content:save( -- 144
	resultPath, -- 144
	table.concat(lines, "\n") -- 144
) -- 144
return ____exports -- 144