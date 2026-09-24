-- [ts]: Vision.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__StringCharCodeAt = ____lualib.__TS__StringCharCodeAt -- 1
local __TS__StringCharAt = ____lualib.__TS__StringCharAt -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 18
local Content = ____Dora.Content -- 18
--- 解析 TGA 头部；仅支持未压缩真彩/灰度（type 2/3，24/32bpp）。
function ____exports.parseTga(data) -- 31
	local n = #data -- 32
	if n < 18 then -- 32
		return nil -- 33
	end -- 33
	local idLength = string.byte(data, 1) or 0 / 0 -- 35
	local colorMapType = string.byte(data, 2) or 0 / 0 -- 36
	local imageType = string.byte(data, 3) or 0 / 0 -- 37
	local width = (string.byte(data, 13) or 0 / 0) + (string.byte(data, 14) or 0 / 0) * 256 -- 38
	local height = (string.byte(data, 15) or 0 / 0) + (string.byte(data, 16) or 0 / 0) * 256 -- 39
	local bpp = string.byte(data, 17) or 0 / 0 -- 40
	local descriptor = string.byte(data, 18) or 0 / 0 -- 41
	if colorMapType ~= 0 then -- 41
		return nil -- 43
	end -- 43
	if imageType ~= 2 and imageType ~= 3 then -- 43
		return nil -- 44
	end -- 44
	if bpp ~= 24 and bpp ~= 32 then -- 44
		return nil -- 45
	end -- 45
	local bytesPerPixel = bpp / 8 -- 47
	local dataOffset = 18 + idLength -- 48
	if n - dataOffset < width * height * bytesPerPixel then -- 48
		return nil -- 49
	end -- 49
	return { -- 51
		width = width, -- 52
		height = height, -- 53
		topOrigin = descriptor & 32 ~= 0, -- 54
		bytesPerPixel = bytesPerPixel, -- 55
		dataOffset = dataOffset, -- 56
		data = data -- 57
	} -- 57
end -- 31
--- 读一个像素的亮度（0–255）。按坐标直接索引，不物化数组。
function ____exports.luminanceAt(img, x, y) -- 62
	local srcRow = img.topOrigin and y or img.height - 1 - y -- 63
	local i = img.dataOffset + srcRow * img.width * img.bytesPerPixel + x * img.bytesPerPixel -- 64
	local b = __TS__StringCharCodeAt(img.data, i) -- 65
	local g = __TS__StringCharCodeAt(img.data, i + 1) -- 66
	local r = __TS__StringCharCodeAt(img.data, i + 2) -- 67
	return (r * 299 + g * 587 + b * 114) / 1000 -- 68
end -- 62
--- 读一个像素的 RGB（返回 [r, g, b]）。
function ____exports.rgbAt(img, x, y) -- 72
	local srcRow = img.topOrigin and y or img.height - 1 - y -- 73
	local i = img.dataOffset + srcRow * img.width * img.bytesPerPixel + x * img.bytesPerPixel -- 74
	return { -- 75
		__TS__StringCharCodeAt(img.data, i + 2), -- 75
		__TS__StringCharCodeAt(img.data, i + 1), -- 75
		__TS__StringCharCodeAt(img.data, i) -- 75
	} -- 75
end -- 72
--- 在降采样网格上做连通域检测，找出画面中每一个“亮块”（= 物体）。
-- 用于可判定地验证“物体是否显形、有几个、在哪、是否分离”。
function ____exports.detectRegions(img, threshold, cell) -- 95
	local gw = math.floor(img.width / cell) -- 96
	local gh = math.floor(img.height / cell) -- 97
	local total = gw * gh -- 98
	local mask = {} -- 101
	do -- 101
		local gy = 0 -- 102
		while gy < gh do -- 102
			do -- 102
				local gx = 0 -- 103
				while gx < gw do -- 103
					local x = math.min( -- 104
						img.width - 1, -- 104
						gx * cell + math.floor(cell / 2) -- 104
					) -- 104
					local y = math.min( -- 105
						img.height - 1, -- 105
						gy * cell + math.floor(cell / 2) -- 105
					) -- 105
					mask[#mask + 1] = ____exports.luminanceAt(img, x, y) > threshold and 1 or 0 -- 106
					gx = gx + 1 -- 103
				end -- 103
			end -- 103
			gy = gy + 1 -- 102
		end -- 102
	end -- 102
	local visited = {} -- 110
	do -- 110
		local i = 0 -- 111
		while i < total do -- 111
			visited[#visited + 1] = 0 -- 111
			i = i + 1 -- 111
		end -- 111
	end -- 111
	local regions = {} -- 113
	do -- 113
		local start = 0 -- 115
		while start < total do -- 115
			do -- 115
				if mask[start + 1] ~= 1 or visited[start + 1] ~= 0 then -- 115
					goto __continue18 -- 116
				end -- 116
				local stack = {} -- 118
				stack[#stack + 1] = start -- 119
				visited[start + 1] = 1 -- 120
				local minX = gw -- 122
				local maxX = -1 -- 123
				local minY = gh -- 124
				local maxY = -1 -- 125
				local cells = 0 -- 126
				local sumX = 0 -- 127
				local sumY = 0 -- 128
				while #stack > 0 do -- 128
					local idx = table.remove(stack) -- 131
					if idx == nil then -- 131
						break -- 132
					end -- 132
					local qx = idx % gw -- 133
					local qy = math.floor(idx / gw) -- 134
					cells = cells + 1 -- 136
					sumX = sumX + qx -- 137
					sumY = sumY + qy -- 138
					if qx < minX then -- 138
						minX = qx -- 139
					end -- 139
					if qx > maxX then -- 139
						maxX = qx -- 140
					end -- 140
					if qy < minY then -- 140
						minY = qy -- 141
					end -- 141
					if qy > maxY then -- 141
						maxY = qy -- 142
					end -- 142
					if qx + 1 < gw then -- 142
						local nIdx = idx + 1 -- 145
						if mask[nIdx + 1] == 1 and visited[nIdx + 1] == 0 then -- 145
							visited[nIdx + 1] = 1 -- 146
							stack[#stack + 1] = nIdx -- 146
						end -- 146
					end -- 146
					if qx - 1 >= 0 then -- 146
						local nIdx = idx - 1 -- 149
						if mask[nIdx + 1] == 1 and visited[nIdx + 1] == 0 then -- 149
							visited[nIdx + 1] = 1 -- 150
							stack[#stack + 1] = nIdx -- 150
						end -- 150
					end -- 150
					if qy + 1 < gh then -- 150
						local nIdx = idx + gw -- 153
						if mask[nIdx + 1] == 1 and visited[nIdx + 1] == 0 then -- 153
							visited[nIdx + 1] = 1 -- 154
							stack[#stack + 1] = nIdx -- 154
						end -- 154
					end -- 154
					if qy - 1 >= 0 then -- 154
						local nIdx = idx - gw -- 157
						if mask[nIdx + 1] == 1 and visited[nIdx + 1] == 0 then -- 157
							visited[nIdx + 1] = 1 -- 158
							stack[#stack + 1] = nIdx -- 158
						end -- 158
					end -- 158
				end -- 158
				regions[#regions + 1] = { -- 162
					minX = minX * cell, -- 163
					maxX = math.min(img.width - 1, (maxX + 1) * cell), -- 164
					minY = minY * cell, -- 165
					maxY = math.min(img.height - 1, (maxY + 1) * cell), -- 166
					cells = cells, -- 167
					cx = sumX / cells, -- 168
					cy = sumY / cells -- 169
				} -- 169
			end -- 169
			::__continue18:: -- 169
			start = start + 1 -- 115
		end -- 115
	end -- 115
	do -- 115
		local i = 1 -- 174
		while i < #regions do -- 174
			local cur = regions[i + 1] -- 175
			local j = i - 1 -- 176
			while j >= 0 and regions[j + 1].cells < cur.cells do -- 176
				regions[j + 1 + 1] = regions[j + 1] -- 178
				j = j - 1 -- 179
			end -- 179
			regions[j + 1 + 1] = cur -- 181
			i = i + 1 -- 174
		end -- 174
	end -- 174
	return regions -- 184
end -- 95
--- 生成 ASCII 灰阶图（每行一个字符串）。
function ____exports.asciiMap(img, cols, rows) -- 188
	local ramp = " .:-=+*#%@" -- 189
	local out = {} -- 190
	do -- 190
		local ry = 0 -- 191
		while ry < rows do -- 191
			local line = "" -- 192
			do -- 192
				local rx = 0 -- 193
				while rx < cols do -- 193
					local x0 = math.floor(rx * img.width / cols) -- 194
					local x1 = math.max( -- 195
						x0 + 1, -- 195
						math.floor((rx + 1) * img.width / cols) -- 195
					) -- 195
					local y0 = math.floor(ry * img.height / rows) -- 196
					local y1 = math.max( -- 197
						y0 + 1, -- 197
						math.floor((ry + 1) * img.height / rows) -- 197
					) -- 197
					local sum = 0 -- 198
					local cnt = 0 -- 199
					local y = y0 -- 200
					while y < y1 do -- 200
						local x = x0 -- 202
						while x < x1 do -- 202
							sum = sum + ____exports.luminanceAt(img, x, y) -- 204
							cnt = cnt + 1 -- 205
							x = x + 4 -- 206
						end -- 206
						y = y + 4 -- 208
					end -- 208
					local avg = cnt > 0 and sum / cnt or 0 -- 210
					local idx = math.min( -- 211
						#ramp - 1, -- 211
						math.floor(avg / 256 * #ramp) -- 211
					) -- 211
					line = line .. __TS__StringCharAt(ramp, idx) -- 212
					rx = rx + 1 -- 193
				end -- 193
			end -- 193
			out[#out + 1] = line -- 214
			ry = ry + 1 -- 191
		end -- 191
	end -- 191
	return out -- 216
end -- 188
function ____exports.defaultOptions() -- 232
	return { -- 233
		threshold = 60, -- 233
		cell = 12, -- 233
		stride = 4, -- 233
		cols = 96, -- 233
		rows = 40 -- 233
	} -- 233
end -- 232
--- 完整分析，返回可写入文件的报告文本。
-- 
-- @param img 已解析的图像
-- @param sceneLines 调用方提供的场景上下文（模型数量、draws 等）
-- @param opts 可选参数
function ____exports.buildReport(img, sceneLines, opts) -- 243
	local report = {} -- 244
	local w = img.width -- 245
	local h = img.height -- 246
	report[#report + 1] = "== image ==" -- 248
	report[#report + 1] = (((((("size=" .. tostring(w)) .. "x") .. tostring(h)) .. " bpp=") .. tostring(img.bytesPerPixel * 8)) .. " topOrigin=") .. tostring(img.topOrigin) -- 249
	report[#report + 1] = "" -- 250
	report[#report + 1] = "== scene ==" -- 251
	for ____, line in ipairs(sceneLines) do -- 252
		report[#report + 1] = line -- 252
	end -- 252
	local sumLum = 0 -- 255
	local minLum = 255 -- 256
	local maxLum = 0 -- 257
	local samples = 0 -- 258
	local bright = 0 -- 259
	local hist = { -- 260
		0, -- 260
		0, -- 260
		0, -- 260
		0, -- 260
		0, -- 260
		0, -- 260
		0, -- 260
		0 -- 260
	} -- 260
	do -- 260
		local y = 0 -- 261
		while y < h do -- 261
			do -- 261
				local x = 0 -- 262
				while x < w do -- 262
					local lum = ____exports.luminanceAt(img, x, y) -- 263
					sumLum = sumLum + lum -- 264
					if lum < minLum then -- 264
						minLum = lum -- 265
					end -- 265
					if lum > maxLum then -- 265
						maxLum = lum -- 266
					end -- 266
					if lum > opts.threshold then -- 266
						bright = bright + 1 -- 267
					end -- 267
					local ____hist_0, ____temp_1 = hist, math.min( -- 267
						7, -- 268
						math.floor(lum / 32) -- 268
					) + 1 -- 268
					____hist_0[____temp_1] = ____hist_0[____temp_1] + 1 -- 268
					samples = samples + 1 -- 269
					x = x + opts.stride -- 262
				end -- 262
			end -- 262
			y = y + opts.stride -- 261
		end -- 261
	end -- 261
	report[#report + 1] = "" -- 272
	report[#report + 1] = ("== luminance (stride " .. tostring(opts.stride)) .. ") ==" -- 273
	report[#report + 1] = (((((("samples=" .. tostring(samples)) .. " mean=") .. __TS__NumberToFixed(sumLum / samples, 1)) .. " min=") .. __TS__NumberToFixed(minLum, 0)) .. " max=") .. __TS__NumberToFixed(maxLum, 0) -- 274
	report[#report + 1] = "histogram[8x32]: " .. table.concat(hist, ", ") -- 275
	report[#report + 1] = ((("bright(lum>" .. tostring(opts.threshold)) .. ")=") .. __TS__NumberToFixed(bright * 100 / samples, 2)) .. "%" -- 276
	report[#report + 1] = "" -- 279
	report[#report + 1] = ((("== regions (threshold " .. tostring(opts.threshold)) .. ", cell ") .. tostring(opts.cell)) .. ") ==" -- 280
	local regions = ____exports.detectRegions(img, opts.threshold, opts.cell) -- 281
	if #regions == 0 then -- 281
		report[#report + 1] = "NONE — 画面可能全黑或物体未渲染" -- 283
	end -- 283
	do -- 283
		local i = 0 -- 285
		while i < #regions and i < 12 do -- 285
			local r = regions[i + 1] -- 286
			local rw = r.maxX - r.minX -- 287
			local rh = r.maxY - r.minY -- 288
			report[#report + 1] = ((((((((((((((((((("#" .. tostring(i + 1)) .. ": bbox=(") .. tostring(r.minX)) .. ",") .. tostring(r.minY)) .. ")-(") .. tostring(r.maxX)) .. ",") .. tostring(r.maxY)) .. ") size=") .. tostring(rw)) .. "x") .. tostring(rh)) .. " cells=") .. tostring(r.cells)) .. " centroidNorm=(") .. __TS__NumberToFixed(r.cx * opts.cell / w, 3)) .. ", ") .. __TS__NumberToFixed(r.cy * opts.cell / h, 3)) .. ")" -- 289
			i = i + 1 -- 285
		end -- 285
	end -- 285
	if #regions > 12 then -- 285
		report[#report + 1] = ("... and " .. tostring(#regions - 12)) .. " more" -- 291
	end -- 291
	report[#report + 1] = "" -- 295
	report[#report + 1] = "== column profile (48 bins) ==" -- 296
	local BINS = 48 -- 297
	local binBright = {} -- 298
	local binTotal = {} -- 299
	do -- 299
		local i = 0 -- 300
		while i < BINS do -- 300
			binBright[#binBright + 1] = 0 -- 300
			binTotal[#binTotal + 1] = 0 -- 300
			i = i + 1 -- 300
		end -- 300
	end -- 300
	do -- 300
		local y = 0 -- 301
		while y < h do -- 301
			do -- 301
				local x = 0 -- 302
				while x < w do -- 302
					local b = math.min( -- 303
						BINS - 1, -- 303
						math.floor(x * BINS / w) -- 303
					) -- 303
					local ____binTotal_2, ____temp_3 = binTotal, b + 1 -- 303
					____binTotal_2[____temp_3] = ____binTotal_2[____temp_3] + 1 -- 304
					if ____exports.luminanceAt(img, x, y) > opts.threshold then -- 304
						local ____binBright_4, ____temp_5 = binBright, b + 1 -- 304
						____binBright_4[____temp_5] = ____binBright_4[____temp_5] + 1 -- 305
					end -- 305
					x = x + opts.stride -- 302
				end -- 302
			end -- 302
			y = y + opts.stride -- 301
		end -- 301
	end -- 301
	local profile = "" -- 308
	do -- 308
		local i = 0 -- 309
		while i < BINS do -- 309
			local denom = binTotal[i + 1] > 0 and binTotal[i + 1] or 1 -- 310
			local pct = binBright[i + 1] * 100 / denom -- 311
			local lvl = math.min( -- 313
				9, -- 313
				math.floor(pct / 10) -- 313
			) -- 313
			profile = profile .. __TS__StringCharAt("0123456789", lvl) -- 314
			i = i + 1 -- 309
		end -- 309
	end -- 309
	report[#report + 1] = ((("0%=................. 100%=9   (each char = 1/" .. tostring(BINS)) .. " of width, ~") .. tostring(math.floor(w / BINS))) .. "px)" -- 316
	report[#report + 1] = profile -- 317
	local segments = 0 -- 320
	local inSeg = false -- 321
	local segInfo = {} -- 322
	local segStart = 0 -- 323
	do -- 323
		local i = 0 -- 324
		while i < BINS do -- 324
			local denom = binTotal[i + 1] > 0 and binTotal[i + 1] or 1 -- 325
			local pct = binBright[i + 1] * 100 / denom -- 326
			local isOn = pct >= 2 -- 327
			if isOn and not inSeg then -- 327
				inSeg = true -- 328
				segStart = i -- 328
			end -- 328
			if not isOn and inSeg then -- 328
				inSeg = false -- 330
				segments = segments + 1 -- 331
				segInfo[#segInfo + 1] = (("x~" .. tostring(math.floor(segStart * w / BINS))) .. "-") .. tostring(math.floor(i * w / BINS)) -- 332
			end -- 332
			i = i + 1 -- 324
		end -- 324
	end -- 324
	if inSeg then -- 324
		segments = segments + 1 -- 336
		segInfo[#segInfo + 1] = (("x~" .. tostring(math.floor(segStart * w / BINS))) .. "-") .. tostring(w) -- 337
	end -- 337
	report[#report + 1] = "horizontal segments (>=2% bright): " .. tostring(segments) -- 339
	for ____, info in ipairs(segInfo) do -- 340
		report[#report + 1] = "  segment " .. info -- 340
	end -- 340
	report[#report + 1] = "" -- 343
	report[#report + 1] = ((("== ascii map (" .. tostring(opts.cols)) .. "x") .. tostring(opts.rows)) .. ") ==" -- 344
	local rows = opts.rows > 0 and opts.rows or math.max( -- 345
		12, -- 345
		math.floor(opts.cols * h / w / 2) -- 345
	) -- 345
	for ____, line in ipairs(____exports.asciiMap(img, opts.cols, rows)) do -- 346
		report[#report + 1] = line -- 346
	end -- 346
	return table.concat(report, "\n") -- 348
end -- 243
--- 一站式入口：读取截图文件 → 解析 → 分析 → 返回报告文本。
-- 失败时返回带 FAILED 说明的文本，不会抛异常。
function ____exports.captureReport(shotPath, sceneLines, opts) -- 355
	local options = opts ~= nil and opts or ____exports.defaultOptions() -- 356
	if not Content:exist(shotPath) then -- 356
		return "VISION FAILED: screenshot not found: " .. shotPath -- 359
	end -- 359
	local data = "" -- 362
	do -- 362
		local function ____catch(e) -- 362
			return true, "VISION FAILED: cannot read screenshot: " .. shotPath -- 366
		end -- 366
		local ____try, ____hasReturned, ____returnValue = pcall(function() -- 366
			data = Content:load(shotPath) -- 364
		end) -- 364
		if not ____try then -- 364
			____hasReturned, ____returnValue = ____catch(____hasReturned) -- 364
		end -- 364
		if ____hasReturned then -- 364
			return ____returnValue -- 363
		end -- 363
	end -- 363
	local img = ____exports.parseTga(data) -- 369
	if img == nil then -- 369
		return ("VISION FAILED: unsupported TGA (" .. tostring(#data)) .. " bytes). Only uncompressed 24/32bpp is supported." -- 371
	end -- 371
	return ____exports.buildReport(img, sceneLines, options) -- 374
end -- 355
return ____exports -- 355