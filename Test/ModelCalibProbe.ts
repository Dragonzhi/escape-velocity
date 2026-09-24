/**
 * S3.1 接线标定探针：行星模型的**半径系数 k** 与探测器的**朝向**。
 *
 * 为什么必须实测：Blender 导出的 .glb 里“1 个模型单位”不一定等于“半径 1”。
 * 若沿用旧的 scale = displayRadius，行星就会整体变大/变小。这里用**两个独立口径**测量：
 *
 *   口径 ①  引擎的模型空间包围盒 getLocalBoundsMin/Max（数值，精确）
 *   口径 ②  与已知半径 1 的 Sphere.gltf **并排、同 scale(=1) 渲染**后，
 *            在截图里量屏幕像素直径（渲染口径，不受 GLB 内部节点变换欺骗）
 * 两者一致 ⇒ k 可信；不一致 ⇒ 以 ②（渲染口径）为准。
 *
 * 探测器朝向：用**已知指向局部 +X 的旧 Probe.gltf（正四面体）**当参照物：
 *   a) 数值：读它在 yaw=0/90/180/270 的**世界**包围盒 ⇒ 定出 angleY 的世界映射（含符号）；
 *   b) 像素：俯视相机下把 yaw=0/180/90 的形状渲染出来，量“质量偏向哪一侧”。
 *
 * ⚠️ 搜索根陷阱（AGENTS.md）：单文件入口（asProj:false）时 Content.searchPaths[0] 可能是
 *    <proj>/Test，于是 .agent/test-results 会落到 Test/.agent/。这里遍历 searchPaths 找含
 *    init.lua/init.ts 的那个当项目根，并用**绝对路径**访问 Assets。
 *
 * 产出（仓库根 .agent/test-results/）：
 *   s31-scale.txt / s31-scale.tga     尺度标定
 *   s31-orient.txt / s31-orient.tga   朝向标定
 */
import { App, Camera3D, Color, Color3, Content, Director, Model3D, Node3D, Path, Vec3, View, threadLoop } from 'Dora';
import { CameraView, FLIP_Y, HANDEDNESS, project } from 'game/Projection';
import { TgaImage, asciiMap, luminanceAt, parseTga } from 'Test/Vision';

// ---------------------------------------------------------------------------
// 项目根：遍历 searchPaths 找含 init.lua/init.ts 的那个
// ---------------------------------------------------------------------------
const searchPaths = Content.searchPaths;
let projRoot = searchPaths[0];
let rootIdx = 0;
for (let i = 0; i < 8; i++) {
	if (i >= searchPaths.length) break;
	const p = searchPaths[i];
	if (Content.exist(Path(p, 'init.lua')) || Content.exist(Path(p, 'init.ts'))) {
		projRoot = p;
		rootIdx = i;
		break;
	}
}
const assetDir = Path(projRoot, 'Assets', 'Model');
const outDir = Path(projRoot, '.agent', 'test-results');
if (!Content.exist(outDir)) Content.mkdir(outDir);
const scaleMarker = Path(outDir, 's31-scale.txt');
const orientMarker = Path(outDir, 's31-orient.txt');

const scaleLines: string[] = [];
const orientLines: string[] = [];
function flushScale(): void { Content.save(scaleMarker, scaleLines.join('\n')); }
function flushOrient(): void { Content.save(orientMarker, orientLines.join('\n')); }

scaleLines.push('== search paths ==');
for (let i = 0; i < 4; i++) {
	if (i >= searchPaths.length) break;
	scaleLines.push('sp[' + i + ']=' + searchPaths[i]);
}
scaleLines.push('projRoot=' + projRoot + ' (index ' + rootIdx + ')  assets=' + assetDir);
scaleLines.push('assetAbsExist=' + Content.exist(Path(assetDir, 'Planet_Mars.glb'))
	+ ' assetRelExist=' + Content.exist('Assets/Model/Planet_Mars.glb'));
flushScale();

// ---------------------------------------------------------------------------
// 造型工具：所有材质染成“自发光亮绿 + 白底” ⇒ 与光照无关的纯色剪影
// ⚠️ getMaterial 的粒度与 GLB 的 materials 数组不等价（Probe_Voyager: JSON 6 / 引擎 12）
//    所以只按“取到 undefined 为止”循环，不写死数量。
// ---------------------------------------------------------------------------
interface Silhouette { model: Model3D.Type | undefined; mats: number; usedAbs: boolean; }

function makeSilhouette(fileName: string): Silhouette {
	const abs = Path(assetDir, fileName);
	let model: Model3D.Type | undefined = Model3D(abs);
	let usedAbs = true;
	if (model === undefined) {
		model = Model3D('Assets/Model/' + fileName);
		usedAbs = false;
	}
	if (model === undefined) return { model: undefined, mats: 0, usedAbs: usedAbs };
	let mats = 0;
	while (mats < 64) {
		const mat = model.getMaterial(mats);
		if (mat === undefined) break;
		mat.baseColor = Color(255, 255, 255, 255);
		mat.emissive = Color3(0x33ff77);
		mats += 1;
	}
	return { model: model, mats: mats, usedAbs: usedAbs };
}

// ---------------------------------------------------------------------------
// 像素扫描（Vision 约定：y 从图像上边往下数）
// ---------------------------------------------------------------------------
interface Extent {
	minX: number; maxX: number; minY: number; maxY: number;
	count: number; meanX: number; meanY: number;
	rawMinX: number; rawMaxX: number; rawMinY: number; rawMaxY: number;
}

/**
 * 两遍扫描：先按“行/列里至少 minRun 个亮像素”筛掉孤立噪点（星空壳的星点、残留节点），
 * 再在筛出的矩形里统计面积与重心。返回 raw 极值便于观察筛选效果。
 */
function scanRect(img: TgaImage, x0: number, x1: number, y0: number, y1: number, thr: number, minRun: number): Extent | undefined {
	const ax = Math.max(0, Math.floor(x0));
	const bx = Math.min(img.width - 1, Math.ceil(x1));
	const ay = Math.max(0, Math.floor(y0));
	const by = Math.min(img.height - 1, Math.ceil(y1));
	const w = bx - ax + 1;
	const h = by - ay + 1;
	if (w <= 0 || h <= 0) return undefined;
	const colCount: number[] = [];
	for (let i = 0; i < w; i++) colCount.push(0);
	const rowCount: number[] = [];
	for (let i = 0; i < h; i++) rowCount.push(0);
	let rawMinX = -1; let rawMaxX = -1; let rawMinY = -1; let rawMaxY = -1;
	let yy = ay;
	while (yy <= by) {
		let xx = ax;
		while (xx <= bx) {
			if (luminanceAt(img, xx, yy) > thr) {
				colCount[xx - ax] += 1;
				rowCount[yy - ay] += 1;
				if (rawMinX < 0 || xx < rawMinX) rawMinX = xx;
				if (rawMaxX < 0 || xx > rawMaxX) rawMaxX = xx;
				if (rawMinY < 0 || yy < rawMinY) rawMinY = yy;
				if (rawMaxY < 0 || yy > rawMaxY) rawMaxY = yy;
			}
			xx += 1;
		}
		yy += 1;
	}
	if (rawMinX < 0) return undefined;
	let minX = -1; let maxX = -1; let minY = -1; let maxY = -1;
	for (let i = 0; i < w; i++) {
		if (colCount[i] >= minRun) { if (minX < 0) minX = i + ax; maxX = i + ax; }
	}
	for (let i = 0; i < h; i++) {
		if (rowCount[i] >= minRun) { if (minY < 0) minY = i + ay; maxY = i + ay; }
	}
	if (minX < 0 || minY < 0) return undefined;
	let sumX = 0; let sumY = 0; let count = 0;
	yy = minY;
	while (yy <= maxY) {
		let xx = minX;
		while (xx <= maxX) {
			if (luminanceAt(img, xx, yy) > thr) { count += 1; sumX += xx; sumY += yy; }
			xx += 1;
		}
		yy += 1;
	}
	if (count === 0) return undefined;
	return {
		minX: minX, maxX: maxX, minY: minY, maxY: maxY, count: count,
		meanX: sumX / count, meanY: sumY / count,
		rawMinX: rawMinX, rawMaxX: rawMaxX, rawMinY: rawMinY, rawMaxY: rawMaxY,
	};
}

// ---------------------------------------------------------------------------
// 口径① 模型空间包围盒
// ---------------------------------------------------------------------------
interface Bounds { ok: boolean; minX: number; maxX: number; minY: number; maxY: number; minZ: number; maxZ: number; mats: number; scaleDependent: boolean; }

function readBounds(fileName: string): Bounds {
	const sil = makeSilhouette(fileName);
	const b: Bounds = { ok: false, minX: 0, maxX: 0, minY: 0, maxY: 0, minZ: 0, maxZ: 0, mats: sil.mats, scaleDependent: false };
	if (sil.model === undefined) return b;
	const m = sil.model;
	try {
		const lo = m.getLocalBoundsMin();
		const hi = m.getLocalBoundsMax();
		b.minX = lo.x; b.maxX = hi.x; b.minY = lo.y; b.maxY = hi.y; b.minZ = lo.z; b.maxZ = hi.z;
		b.ok = true;
		m.scale = Vec3(3, 3, 3);
		const hi3 = m.getLocalBoundsMax();
		b.scaleDependent = Math.abs(hi3.x - b.maxX) > 1e-6;
		m.scale = Vec3(1, 1, 1);
	} catch (e) {
		b.ok = false;
	}
	// ⚠️ 实测：没有挂到任何父节点的 Model3D 依然会被渲染（默认落在世界原点）——
	//    量包围盒用的临时实例必须手动隐藏，否则会串进截图（踩过：Saturn 的环 + 星壳的星点）。
	m.visible = false;
	return b;
}

const fileList: string[] = [
	'Sphere.gltf', 'Planet_Earth.glb', 'Planet_Mars.glb', 'Planet_Venus.glb', 'Planet_Jupiter.glb',
	'Planet_Saturn.glb', 'Planet_Neptune.glb', 'Probe.gltf', 'Probe_Voyager_v1.glb', 'Probe_Voyager.glb',
	'StarShell.gltf', 'StarShellBright.gltf',
];
const boundsMap: Bounds[] = [];

scaleLines.push('');
scaleLines.push('== 口径① 模型空间包围盒（unit scale，模型单位）==');
scaleLines.push('file  x[min,max]  y[min,max]  z[min,max]  halfX/halfY/halfZ  mats  localBoundsScaleDependent');
for (let i = 0; i < fileList.length; i++) {
	const b = readBounds(fileList[i]);
	boundsMap.push(b);
	if (!b.ok) { scaleLines.push(fileList[i] + '  BOUNDS_UNAVAILABLE'); continue; }
	scaleLines.push(fileList[i]
		+ '  x[' + b.minX.toFixed(4) + ',' + b.maxX.toFixed(4) + ']'
		+ ' y[' + b.minY.toFixed(4) + ',' + b.maxY.toFixed(4) + ']'
		+ ' z[' + b.minZ.toFixed(4) + ',' + b.maxZ.toFixed(4) + ']'
		+ '  half=' + ((b.maxX - b.minX) / 2).toFixed(4) + '/' + ((b.maxY - b.minY) / 2).toFixed(4) + '/' + ((b.maxZ - b.minZ) / 2).toFixed(4)
		+ '  mats=' + b.mats.toFixed(0) + '  ' + b.scaleDependent);
}
flushScale();

// ---------------------------------------------------------------------------
// 阶段 B：正面并排（参考球 r=1 与 5 个行星模型，同 z=0 平面、同 scale=1）
// ---------------------------------------------------------------------------
const vw = View.size.width;
const vh = View.size.height;
const fovY = View.fieldOfView;
const aspect = View.aspectRatio;
const tanHalf = Math.tan((fovY * Math.PI) / 360);

scaleLines.push('');
scaleLines.push('== viewport ==');
scaleLines.push('view=' + vw.toFixed(0) + 'x' + vh.toFixed(0) + ' aspect=' + aspect.toFixed(4) + ' fovY=' + fovY.toFixed(2) + ' tanHalf=' + tanHalf.toFixed(6));

const planetNames: string[] = ['Planet_Mars', 'Planet_Venus', 'Planet_Jupiter', 'Planet_Saturn', 'Planet_Neptune'];
const rowLabel: string[] = ['Sphere(REF r=1)'];
for (let i = 0; i < planetNames.length; i++) rowLabel.push(planetNames[i]);

const rowSpacing = 5.0;
const rowCount = planetNames.length + 1;
const halfSpanWorld = ((rowCount - 1) / 2) * rowSpacing + 3.4;
const camDist = (halfSpanWorld / (tanHalf * aspect)) * 1.06;
const ppwFov = (vh / 2) / (camDist * tanHalf);

scaleLines.push('row=' + rowCount.toFixed(0) + ' spacing=' + rowSpacing.toFixed(2)
	+ ' camDist=' + camDist.toFixed(2) + ' pxPerWorldUnit(由 fov 推算)=' + ppwFov.toFixed(3));

const rowNodes: Node3D.Type[] = [];
const rowX: number[] = [];
for (let i = 0; i < rowCount; i++) {
	const fileName = i === 0 ? 'Sphere.gltf' : planetNames[i - 1] + '.glb';
	const sil = makeSilhouette(fileName);
	if (sil.model === undefined) { scaleLines.push('LOAD_FAIL ' + rowLabel[i]); continue; }
	const wx = (i - (rowCount - 1) / 2) * rowSpacing;
	sil.model.position = Vec3(wx, 0, 0);
	sil.model.scale = Vec3(1, 1, 1);
	rowX.push(wx);
	rowNodes.push(sil.model);
	Director.entry.addChild(sil.model);
}

const camRow = Camera3D();
camRow.lookAt(Vec3(0, 0, camDist), Vec3(0, 0, 0));
Director.pushCamera(camRow);

const camViewRow: CameraView = {
	eye: { x: 0, y: 0, z: camDist },
	target: { x: 0, y: 0, z: 0 },
	up: { x: 0, y: 1, z: 0 },
	fovYDeg: fovY,
	aspect: aspect,
	viewW: vw,
	viewH: vh,
};

const rowPx: number[] = [];
const rowPy: number[] = [];
for (let i = 0; i < rowX.length; i++) {
	const pr = project({ x: rowX[i], y: 0, z: 0 }, camViewRow, HANDEDNESS, FLIP_Y);
	if (pr === undefined) { rowPx.push(vw / 2); rowPy.push(vh / 2); }
	else { rowPx.push(vw / 2 + pr.x); rowPy.push(vh / 2 - pr.y); }
}
scaleLines.push('projected centers(px)=' + rowPx.map((v) => v.toFixed(1)).join(', '));
flushScale();

// ---------------------------------------------------------------------------
// 阶段 C：俯视网格（旧四面体 vs Probe_Voyager_v1，各 3 个 yaw）
// ---------------------------------------------------------------------------
let probeLong = 2.0;
for (let i = 0; i < fileList.length; i++) {
	if (fileList[i] !== 'Probe.gltf' && fileList[i] !== 'Probe_Voyager_v1.glb') continue;
	const b = boundsMap[i];
	if (!b.ok) continue;
	const l = Math.max(b.maxX - b.minX, b.maxY - b.minY, b.maxZ - b.minZ);
	if (l > probeLong) probeLong = l;
}
const SP = Math.max(3.2, probeLong * 1.2);
const rowR = Math.max(3.0, probeLong * 0.9);
const markBig = 0.9;
const markSmall = 0.45;
const markX = 1.2 * SP + 3.2;
const halfWc = markX + markBig + 0.5;
const halfHc = rowR + probeLong * 0.7 + 0.5;
const camDistC = Math.max(halfWc / (tanHalf * aspect), halfHc / tanHalf) * 1.08;
const ppwC = (vh / 2) / (camDistC * tanHalf);

orientLines.push('== search paths ==');
orientLines.push('projRoot=' + projRoot + ' (index ' + rootIdx + ')');
orientLines.push('== viewport ==');
orientLines.push('view=' + vw.toFixed(0) + 'x' + vh.toFixed(0) + ' aspect=' + aspect.toFixed(4) + ' fovY=' + fovY.toFixed(2));
orientLines.push('probeLongestDim(包围盒)=' + probeLong.toFixed(3) + ' => 列间距 1.2*SP=' + (1.2 * SP).toFixed(2)
	+ ' 行距 R=' + rowR.toFixed(2) + ' camDist=' + camDistC.toFixed(2) + ' pxPerWorldUnit=' + ppwC.toFixed(3));

// --- 数值口径：angleY 的世界映射（用已知朝 +X 的旧四面体）---
orientLines.push('');
orientLines.push('== angleY 世界映射（数值：旧 Probe.gltf 四面体，顶点在局部 +X）==');
const tetraRef = makeSilhouette('Probe.gltf');
if (tetraRef.model !== undefined) {
	const tm = tetraRef.model;
	tm.position = Vec3(0, 0, 0);
	tm.scale = Vec3(1, 1, 1);
	const yaws = [0, 90, 180, 270];
	for (let i = 0; i < yaws.length; i++) {
		tm.angleY = yaws[i];
		try {
			const lo = tm.getWorldBoundsMin();
			const hi = tm.getWorldBoundsMax();
			orientLines.push('yaw=' + yaws[i].toFixed(0)
				+ '  world x[' + lo.x.toFixed(3) + ',' + hi.x.toFixed(3) + ']'
				+ ' y[' + lo.y.toFixed(3) + ',' + hi.y.toFixed(3) + ']'
				+ ' z[' + lo.z.toFixed(3) + ',' + hi.z.toFixed(3) + ']');
		} catch (e) {
			orientLines.push('yaw=' + yaws[i].toFixed(0) + '  WORLD_BOUNDS_UNAVAILABLE');
		}
	}
	tm.visible = false;
}

// --- 像素口径：俯视网格 ---
interface GridItem { label: string; wx: number; wz: number; yaw: number; scale: number; file: string; }

const yawCols = [0, 180, 90];
const grid: GridItem[] = [];
for (let c = 0; c < yawCols.length; c++) {
	const wx = (c - 1) * 1.2 * SP;
	grid.push({ label: 'TETRA yaw' + yawCols[c].toFixed(0), wx: wx, wz: -rowR, yaw: yawCols[c], scale: 1, file: 'Probe.gltf' });
	grid.push({ label: 'V1 yaw' + yawCols[c].toFixed(0), wx: wx, wz: rowR, yaw: yawCols[c], scale: 1, file: 'Probe_Voyager_v1.glb' });
}
grid.push({ label: 'MARK_BIG(+X)', wx: markX, wz: 0, yaw: 0, scale: markBig, file: 'Sphere.gltf' });
grid.push({ label: 'MARK_SMALL(-X)', wx: -markX, wz: 0, yaw: 0, scale: markSmall, file: 'Sphere.gltf' });

orientLines.push('');
orientLines.push('== 布局 ==');
orientLines.push('  俯视相机：eye=(0,' + camDistC.toFixed(1) + ',0.001) target=(0,0,0) up=(0,1,0)');
orientLines.push('  z=-R 行(z=' + (-rowR).toFixed(2) + ')：TETRA yaw0/180/90 @x=-' + (1.2 * SP).toFixed(2) + '/0/+' + (1.2 * SP).toFixed(2));
orientLines.push('  z=+R 行(z=+' + rowR.toFixed(2) + ')：V1    yaw0/180/90 @x=-' + (1.2 * SP).toFixed(2) + '/0/+' + (1.2 * SP).toFixed(2));
orientLines.push('  标记球：Sphere 半径 ' + markBig.toFixed(2) + ' @x=+' + markX.toFixed(2) + '（+X 侧，大）与 ' + markSmall.toFixed(2) + ' @x=-' + markX.toFixed(2) + '（-X 侧，小）');
orientLines.push('  判读：大标记球在屏幕哪一侧 ⇒ 那一侧的世界 x 为 +X；两行靠面积区分（V1 行面积远大于 TETRA 行）');
flushOrient();

const gridNodes: Node3D.Type[] = [];
const gridKeep: GridItem[] = [];
for (let i = 0; i < grid.length; i++) {
	const it = grid[i];
	const sil = makeSilhouette(it.file);
	if (sil.model === undefined) { orientLines.push('LOAD_FAIL ' + it.label); continue; }
	sil.model.position = Vec3(it.wx, 0, it.wz);
	sil.model.scale = Vec3(it.scale, it.scale, it.scale);
	sil.model.angleY = it.yaw;
	sil.model.visible = false; // 俯视阶段才显示（否则会串进正面镜头）
	gridNodes.push(sil.model);
	gridKeep.push(it);
}
orientLines.push('gridNodes=' + gridNodes.length.toFixed(0) + '/' + grid.length.toFixed(0));
flushOrient();

const camTop = Camera3D();
camTop.lookAt(Vec3(0, camDistC, 0.001), Vec3(0, 0, 0), Vec3(0, 1, 0));
// ⚠️ 不能在这里 pushCamera：最后 push 的相机才是渲染用的，会把正面镜头顶掉。
//    切到俯视阶段时再 push（见主循环 stage 1）。

const camViewTop: CameraView = {
	eye: { x: 0, y: camDistC, z: 0.001 },
	target: { x: 0, y: 0, z: 0 },
	up: { x: 0, y: 1, z: 0 },
	fovYDeg: fovY,
	aspect: aspect,
	viewW: vw,
	viewH: vh,
};

const gridPx: number[] = [];
const gridPy: number[] = [];
for (let i = 0; i < gridKeep.length; i++) {
	const it = gridKeep[i];
	const pr = project({ x: it.wx, y: 0, z: it.wz }, camViewTop, HANDEDNESS, FLIP_Y);
	if (pr === undefined) { gridPx.push(vw / 2); gridPy.push(vh / 2); }
	else { gridPx.push(vw / 2 + pr.x); gridPy.push(vh / 2 - pr.y); }
}
orientLines.push('projected centers(px)=' + gridPx.map((v) => v.toFixed(1)).join(', '));
flushOrient();

// ---------------------------------------------------------------------------
// 主循环
// ---------------------------------------------------------------------------
const THR = 60;
let frame = 0;
let stage = 0;
let shotRow = '';
let shotTop = '';

threadLoop(() => {
	frame += 1;

	if (stage === 0 && frame > 6) {
		stage = 1;
		shotRow = App.saveScreenshot(Path(outDir, 's31-scale'));
		scaleLines.push('shot requested: ' + shotRow);
		flushScale();
		return false;
	}

	if (stage === 1 && frame > 26) {
		stage = 2;
		const data = Content.load(shotRow);
		const img = parseTga(data);
		if (img === undefined) {
			scaleLines.push('RESULT=FAIL reason=parse-tga len=' + data.length.toFixed(0));
			flushScale();
		} else {
			scaleLines.push('');
			scaleLines.push('== 口径② 并排渲染像素测量（thr=' + THR.toFixed(0) + '）==');
			scaleLines.push('image=' + img.width + 'x' + img.height + ' bpp=' + (img.bytesPerPixel * 8).toFixed(0) + ' topOrigin=' + img.topOrigin);
			const bandHalf = 0.46 * rowSpacing * ppwFov;
			let refHalf = 0;
			for (let i = 0; i < rowPx.length; i++) {
				const ex = scanRect(img, rowPx[i] - bandHalf, rowPx[i] + bandHalf,
					rowPy[i] - 3.2 * ppwFov, rowPy[i] + 3.2 * ppwFov, THR, 3);
				if (ex === undefined) { scaleLines.push(rowLabel[i] + ': NO_PIXELS'); continue; }
				const w = ex.maxX - ex.minX + 1;
				const h = ex.maxY - ex.minY + 1;
				const halfW = w / 2;
				const halfH = h / 2;
				const rawW = ex.rawMaxX - ex.rawMinX + 1;
				const rawH = ex.rawMaxY - ex.rawMinY + 1;
				if (i === 0) refHalf = halfH;
				scaleLines.push(rowLabel[i] + ': pxW=' + w.toFixed(0) + ' pxH=' + h.toFixed(0)
					+ ' pxHalfW=' + halfW.toFixed(1) + ' pxHalfH=' + halfH.toFixed(1)
					+ ' area=' + ex.count.toFixed(0) + ' fill=' + (ex.count / (w * h)).toFixed(3)
					+ ' massDx=' + (ex.meanX - rowPx[i]).toFixed(1) + ' massDy=' + (ex.meanY - rowPy[i]).toFixed(1)
					+ ' rawW/H=' + rawW.toFixed(0) + '/' + rawH.toFixed(0));
			}
			scaleLines.push('REF(Sphere r=1) 实测像素半径=' + refHalf.toFixed(2)
				+ '  ⇒ 实测 pxPerWorldUnit=' + refHalf.toFixed(3) + '（fov 推算 ' + ppwFov.toFixed(3) + '）');
			for (let i = 1; i < rowPx.length; i++) {
				const ex = scanRect(img, rowPx[i] - bandHalf, rowPx[i] + bandHalf,
					rowPy[i] - 3.2 * ppwFov, rowPy[i] + 3.2 * ppwFov, THR, 3);
				if (ex === undefined) continue;
				const halfH = (ex.maxY - ex.minY + 1) / 2;
				const halfW = (ex.maxX - ex.minX + 1) / 2;
				const kpx = refHalf > 0 ? halfH / refHalf : 0;
				const kpxW = refHalf > 0 ? halfW / refHalf : 0;
				const bk = boundsMap[1 + i];
				const kBoundsY = bk.ok ? (bk.maxY - bk.minY) / 2 : -1;
				const kBoundsX = bk.ok ? (bk.maxX - bk.minX) / 2 : -1;
				scaleLines.push('k(' + rowLabel[i] + ')  纵向像素口径=' + kpx.toFixed(4) + ' 横向=' + kpxW.toFixed(4)
					+ '  包围盒口径 halfY=' + (kBoundsY >= 0 ? kBoundsY.toFixed(4) : 'n/a')
					+ ' halfX=' + (kBoundsX >= 0 ? kBoundsX.toFixed(4) : 'n/a'));
			}
			scaleLines.push('');
			scaleLines.push('== ascii (110x34) ==');
			const am = asciiMap(img, 110, 34);
			for (let r = 0; r < am.length; r++) scaleLines.push(am[r]);
			scaleLines.push('RESULT=' + (refHalf > 0 ? 'PASS' : 'FAIL'));
			flushScale();
		}
		for (let i = 0; i < rowNodes.length; i++) rowNodes[i].visible = false;
		for (let i = 0; i < gridNodes.length; i++) gridNodes[i].visible = true;
		Director.pushCamera(camTop);
		shotTop = App.saveScreenshot(Path(outDir, 's31-orient'));
		orientLines.push('shot requested: ' + shotTop);
		flushOrient();
		return false;
	}

	if (stage === 2 && frame > 52) {
		stage = 3;
		const data = Content.load(shotTop);
		const img = parseTga(data);
		if (img === undefined) {
			orientLines.push('RESULT=FAIL reason=parse-tga');
			flushOrient();
			return true;
		}
		orientLines.push('');
		orientLines.push('== 像素测量（thr=' + THR.toFixed(0) + '）==');
		orientLines.push('image=' + img.width + 'x' + img.height);
		const cellHalfX = 0.58 * 1.2 * SP * ppwC;
		const cellHalfY = 0.42 * rowR * ppwC;
		for (let i = 0; i < gridKeep.length; i++) {
			const it = gridKeep[i];
			const isMark = it.label.indexOf('MARK') === 0;
			const hx = isMark ? (it.scale * 1.6 * ppwC) : cellHalfX;
			const hy = isMark ? (it.scale * 1.6 * ppwC) : cellHalfY;
			const ex = scanRect(img, gridPx[i] - hx, gridPx[i] + hx, gridPy[i] - hy, gridPy[i] + hy, THR, 3);
			if (ex === undefined) { orientLines.push(it.label + ': NO_PIXELS'); continue; }
			const w = ex.maxX - ex.minX + 1;
			const h = ex.maxY - ex.minY + 1;
			const clipped = (!isMark) && ((ex.minX <= gridPx[i] - hx + 1) || (ex.maxX >= gridPx[i] + hx - 1)
				|| (ex.minY <= gridPy[i] - hy + 1) || (ex.maxY >= gridPy[i] + hy - 1));
			orientLines.push(it.label + ': bbox=(' + ex.minX + ',' + ex.minY + ')-(' + ex.maxX + ',' + ex.maxY + ')'
				+ ' w=' + w.toFixed(0) + ' h=' + h.toFixed(0) + ' area=' + ex.count.toFixed(0)
				+ ' fill=' + (ex.count / (w * h)).toFixed(3)
				+ ' cellC=(' + gridPx[i].toFixed(1) + ',' + gridPy[i].toFixed(1) + ')'
				+ ' massDx=' + (ex.meanX - gridPx[i]).toFixed(1) + ' massDy=' + (ex.meanY - gridPy[i]).toFixed(1)
				+ ' L/R=' + (gridPx[i] - ex.minX).toFixed(1) + '/' + (ex.maxX - gridPx[i]).toFixed(1)
				+ ' U/D=' + (gridPy[i] - ex.minY).toFixed(1) + '/' + (ex.maxY - gridPy[i]).toFixed(1)
				+ (clipped ? '  ⚠CLIPPED' : ''));
		}
		orientLines.push('');
		orientLines.push('== ascii (110x40) ==');
		const am = asciiMap(img, 110, 40);
		for (let r = 0; r < am.length; r++) orientLines.push(am[r]);
		orientLines.push('RESULT=PASS');
		flushOrient();
		return true;
	}

	return false;
});
