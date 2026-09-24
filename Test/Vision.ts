/**
 * 视觉验证工具库：把截图变成可读文本。
 *
 * 为什么需要：Agent 无法直接看图片（read_file 拒读二进制、无图像分析工具）。
 * 但 App.saveScreenshot 输出的是**未压缩 TGA**（type=2，24/32bpp），
 * 而入口是引擎脚本，能用 Content.load 读到像素字节。
 * 于是可以在引擎内解码、降采样、输出 ASCII 灰阶图 + 亮度统计 + 物体区域定位。
 * 把“看图”变成“读文本”。
 *
 * 用法（在任意测试入口里）：
 *   const shotPath = App.saveScreenshot(Path(outDir, 'shot'));
 *   const report = captureReport(shotPath, '场景标题', ['stats: draws=4']);
 *   Content.save(Path(outDir, 'vision-report.txt'), report);
 *
 * ⚠️ 性能：截图约 2024×1230×4 ≈ 10 MB。必须用**步长采样**而不是物化像素数组，
 * 否则会把千万个数字塞进 Lua 表而失败（实测过）。
 */
import { Content } from 'Dora';

export interface TgaImage {
	width: number;
	height: number;
	/** true = 图像自上而下存储；false = 自下而上（TGA 默认）。 */
	topOrigin: boolean;
	bytesPerPixel: number;
	dataOffset: number;
	data: string;
}

/** 解析 TGA 头部；仅支持未压缩真彩/灰度（type 2/3，24/32bpp）。 */
export function parseTga(data: string): TgaImage | undefined {
	const n = data.length;
	if (n < 18) return undefined;

	const idLength = data.charCodeAt(0);
	const colorMapType = data.charCodeAt(1);
	const imageType = data.charCodeAt(2);
	const width = data.charCodeAt(12) + data.charCodeAt(13) * 256;
	const height = data.charCodeAt(14) + data.charCodeAt(15) * 256;
	const bpp = data.charCodeAt(16);
	const descriptor = data.charCodeAt(17);

	if (colorMapType !== 0) return undefined;
	if (imageType !== 2 && imageType !== 3) return undefined;
	if (bpp !== 24 && bpp !== 32) return undefined;

	const bytesPerPixel = bpp / 8;
	const dataOffset = 18 + idLength;
	if (n - dataOffset < width * height * bytesPerPixel) return undefined;

	return {
		width,
		height,
		topOrigin: (descriptor & 0x20) !== 0,
		bytesPerPixel,
		dataOffset,
		data,
	};
}

/** 读一个像素的亮度（0–255）。按坐标直接索引，不物化数组。 */
export function luminanceAt(img: TgaImage, x: number, y: number): number {
	const srcRow = img.topOrigin ? y : img.height - 1 - y;
	const i = img.dataOffset + srcRow * img.width * img.bytesPerPixel + x * img.bytesPerPixel;
	const b = img.data.charCodeAt(i);
	const g = img.data.charCodeAt(i + 1);
	const r = img.data.charCodeAt(i + 2);
	return (r * 299 + g * 587 + b * 114) / 1000;
}

/** 读一个像素的 RGB（返回 [r, g, b]）。 */
export function rgbAt(img: TgaImage, x: number, y: number): number[] {
	const srcRow = img.topOrigin ? y : img.height - 1 - y;
	const i = img.dataOffset + srcRow * img.width * img.bytesPerPixel + x * img.bytesPerPixel;
	return [img.data.charCodeAt(i + 2), img.data.charCodeAt(i + 1), img.data.charCodeAt(i)];
}

export interface Region {
	/** 像素坐标包围盒。 */
	minX: number;
	maxX: number;
	minY: number;
	maxY: number;
	/** 组成该区域的网格单元数（面积代理）。 */
	cells: number;
	/** 网格坐标重心。 */
	cx: number;
	cy: number;
}

/**
 * 在降采样网格上做连通域检测，找出画面中每一个“亮块”（= 物体）。
 * 用于可判定地验证“物体是否显形、有几个、在哪、是否分离”。
 */
export function detectRegions(img: TgaImage, threshold: number, cell: number): Region[] {
	const gw = Math.floor(img.width / cell);
	const gh = Math.floor(img.height / cell);
	const total = gw * gh;

	// 构建亮/暗掩码（取单元格中心采样）
	const mask: number[] = [];
	for (let gy = 0; gy < gh; gy++) {
		for (let gx = 0; gx < gw; gx++) {
			const x = Math.min(img.width - 1, gx * cell + Math.floor(cell / 2));
			const y = Math.min(img.height - 1, gy * cell + Math.floor(cell / 2));
			mask.push(luminanceAt(img, x, y) > threshold ? 1 : 0);
		}
	}

	const visited: number[] = [];
	for (let i = 0; i < total; i++) visited.push(0);

	const regions: Region[] = [];

	for (let start = 0; start < total; start++) {
		if (mask[start] !== 1 || visited[start] !== 0) continue;

		const stack: number[] = [];
		stack.push(start);
		visited[start] = 1;

		let minX = gw;
		let maxX = -1;
		let minY = gh;
		let maxY = -1;
		let cells = 0;
		let sumX = 0;
		let sumY = 0;

		while (stack.length > 0) {
			const idx = stack.pop();
			if (idx === undefined) break;
			const qx = idx % gw;
			const qy = Math.floor(idx / gw);

			cells += 1;
			sumX += qx;
			sumY += qy;
			if (qx < minX) minX = qx;
			if (qx > maxX) maxX = qx;
			if (qy < minY) minY = qy;
			if (qy > maxY) maxY = qy;

			if (qx + 1 < gw) {
				const nIdx = idx + 1;
				if (mask[nIdx] === 1 && visited[nIdx] === 0) { visited[nIdx] = 1; stack.push(nIdx); }
			}
			if (qx - 1 >= 0) {
				const nIdx = idx - 1;
				if (mask[nIdx] === 1 && visited[nIdx] === 0) { visited[nIdx] = 1; stack.push(nIdx); }
			}
			if (qy + 1 < gh) {
				const nIdx = idx + gw;
				if (mask[nIdx] === 1 && visited[nIdx] === 0) { visited[nIdx] = 1; stack.push(nIdx); }
			}
			if (qy - 1 >= 0) {
				const nIdx = idx - gw;
				if (mask[nIdx] === 1 && visited[nIdx] === 0) { visited[nIdx] = 1; stack.push(nIdx); }
			}
		}

		regions.push({
			minX: minX * cell,
			maxX: Math.min(img.width - 1, (maxX + 1) * cell),
			minY: minY * cell,
			maxY: Math.min(img.height - 1, (maxY + 1) * cell),
			cells,
			cx: sumX / cells,
			cy: sumY / cells,
		});
	}

	// 按面积从大到小排序（插入排序，避免依赖不稳定排序）
	for (let i = 1; i < regions.length; i++) {
		const cur = regions[i];
		let j = i - 1;
		while (j >= 0 && regions[j].cells < cur.cells) {
			regions[j + 1] = regions[j];
			j -= 1;
		}
		regions[j + 1] = cur;
	}

	return regions;
}

/** 生成 ASCII 灰阶图（每行一个字符串）。 */
export function asciiMap(img: TgaImage, cols: number, rows: number): string[] {
	const ramp = ' .:-=+*#%@';
	const out: string[] = [];
	for (let ry = 0; ry < rows; ry++) {
		let line = '';
		for (let rx = 0; rx < cols; rx++) {
			const x0 = Math.floor(rx * img.width / cols);
			const x1 = Math.max(x0 + 1, Math.floor((rx + 1) * img.width / cols));
			const y0 = Math.floor(ry * img.height / rows);
			const y1 = Math.max(y0 + 1, Math.floor((ry + 1) * img.height / rows));
			let sum = 0;
			let cnt = 0;
			let y = y0;
			while (y < y1) {
				let x = x0;
				while (x < x1) {
					sum += luminanceAt(img, x, y);
					cnt += 1;
					x += 4;
				}
				y += 4;
			}
			const avg = cnt > 0 ? sum / cnt : 0;
			const idx = Math.min(ramp.length - 1, Math.floor(avg / 256 * ramp.length));
			line += ramp.charAt(idx);
		}
		out.push(line);
	}
	return out;
}

export interface AnalyzeOptions {
	/** 亮像素阈值（默认 60）。 */
	threshold: number;
	/** 区域检测的网格单元边长（默认 12）。 */
	cell: number;
	/** 采样步长（默认 4）。 */
	stride: number;
	/** ASCII 图列数（默认 96）。 */
	cols: number;
	/** ASCII 图行数（默认根据宽高比自动计算）。 */
	rows: number;
}

export function defaultOptions(): AnalyzeOptions {
	return { threshold: 60, cell: 12, stride: 4, cols: 96, rows: 40 };
}

/**
 * 完整分析，返回可写入文件的报告文本。
 *
 * @param img 已解析的图像
 * @param sceneLines 调用方提供的场景上下文（模型数量、draws 等）
 * @param opts 可选参数
 */
export function buildReport(img: TgaImage, sceneLines: string[], opts: AnalyzeOptions): string {
	const report: string[] = [];
	const w = img.width;
	const h = img.height;

	report.push('== image ==');
	report.push(`size=${w}x${h} bpp=${img.bytesPerPixel * 8} topOrigin=${img.topOrigin}`);
	report.push('');
	report.push('== scene ==');
	for (const line of sceneLines) report.push(line);

	// 亮度统计
	let sumLum = 0;
	let minLum = 255;
	let maxLum = 0;
	let samples = 0;
	let bright = 0;
	const hist = [0, 0, 0, 0, 0, 0, 0, 0];
	for (let y = 0; y < h; y += opts.stride) {
		for (let x = 0; x < w; x += opts.stride) {
			const lum = luminanceAt(img, x, y);
			sumLum += lum;
			if (lum < minLum) minLum = lum;
			if (lum > maxLum) maxLum = lum;
			if (lum > opts.threshold) bright += 1;
			hist[Math.min(7, Math.floor(lum / 32))] += 1;
			samples += 1;
		}
	}
	report.push('');
	report.push(`== luminance (stride ${opts.stride}) ==`);
	report.push(`samples=${samples} mean=${(sumLum / samples).toFixed(1)} min=${minLum.toFixed(0)} max=${maxLum.toFixed(0)}`);
	report.push(`histogram[8x32]: ${hist.join(', ')}`);
	report.push(`bright(lum>${opts.threshold})=${(bright * 100 / samples).toFixed(2)}%`);

	// 区域检测
	report.push('');
	report.push(`== regions (threshold ${opts.threshold}, cell ${opts.cell}) ==`);
	const regions = detectRegions(img, opts.threshold, opts.cell);
	if (regions.length === 0) {
		report.push('NONE — 画面可能全黑或物体未渲染');
	}
	for (let i = 0; i < regions.length && i < 12; i++) {
		const r = regions[i];
		const rw = r.maxX - r.minX;
		const rh = r.maxY - r.minY;
		report.push(`#${i + 1}: bbox=(${r.minX},${r.minY})-(${r.maxX},${r.maxY}) size=${rw}x${rh} cells=${r.cells} centroidNorm=(${(r.cx * opts.cell / w).toFixed(3)}, ${(r.cy * opts.cell / h).toFixed(3)})`);
	}
	if (regions.length > 12) report.push(`... and ${regions.length - 12} more`);

	// 列剖面：把画面按列分桶，统计每桶的亮像素占比。
	// 比连通域更可靠地判定“有几个物体、各自在哪个 x 位置”。
	report.push('');
	report.push('== column profile (48 bins) ==');
	const BINS = 48;
	const binBright: number[] = [];
	const binTotal: number[] = [];
	for (let i = 0; i < BINS; i++) { binBright.push(0); binTotal.push(0); }
	for (let y = 0; y < h; y += opts.stride) {
		for (let x = 0; x < w; x += opts.stride) {
			const b = Math.min(BINS - 1, Math.floor(x * BINS / w));
			binTotal[b] += 1;
			if (luminanceAt(img, x, y) > opts.threshold) binBright[b] += 1;
		}
	}
	let profile = '';
	for (let i = 0; i < BINS; i++) {
		const denom = binTotal[i] > 0 ? binTotal[i] : 1;
		const pct = binBright[i] * 100 / denom;
		// 每桶 0–100% 映射到 0–9 的字符
		const lvl = Math.min(9, Math.floor(pct / 10));
		profile += '0123456789'.charAt(lvl);
	}
	report.push(`0%=................. 100%=9   (each char = 1/${BINS} of width, ~${Math.floor(w / BINS)}px)`);
	report.push(profile);

	// 统计：有多少个“分离的物体列段”（连续非零桶）
	let segments = 0;
	let inSeg = false;
	const segInfo: string[] = [];
	let segStart = 0;
	for (let i = 0; i < BINS; i++) {
		const denom = binTotal[i] > 0 ? binTotal[i] : 1;
		const pct = binBright[i] * 100 / denom;
		const isOn = pct >= 2;
		if (isOn && !inSeg) { inSeg = true; segStart = i; }
		if (!isOn && inSeg) {
			inSeg = false;
			segments += 1;
			segInfo.push(`x~${Math.floor(segStart * w / BINS)}-${Math.floor(i * w / BINS)}`);
		}
	}
	if (inSeg) {
		segments += 1;
		segInfo.push(`x~${Math.floor(segStart * w / BINS)}-${w}`);
	}
	report.push(`horizontal segments (>=2% bright): ${segments}`);
	for (const info of segInfo) report.push(`  segment ${info}`);

	// ASCII 图
	report.push('');
	report.push(`== ascii map (${opts.cols}x${opts.rows}) ==`);
	const rows = opts.rows > 0 ? opts.rows : Math.max(12, Math.floor(opts.cols * h / w / 2));
	for (const line of asciiMap(img, opts.cols, rows)) report.push(line);

	return report.join('\n');
}

/**
 * 一站式入口：读取截图文件 → 解析 → 分析 → 返回报告文本。
 * 失败时返回带 FAILED 说明的文本，不会抛异常。
 */
export function captureReport(shotPath: string, sceneLines: string[], opts?: AnalyzeOptions): string {
	const options = opts !== undefined ? opts : defaultOptions();

	if (!Content.exist(shotPath)) {
		return `VISION FAILED: screenshot not found: ${shotPath}`;
	}

	let data = '';
	try {
		data = Content.load(shotPath);
	} catch (e) {
		return `VISION FAILED: cannot read screenshot: ${shotPath}`;
	}

	const img = parseTga(data);
	if (img === undefined) {
		return `VISION FAILED: unsupported TGA (${data.length} bytes). Only uncompressed 24/32bpp is supported.`;
	}

	return buildReport(img, sceneLines, options);
}
