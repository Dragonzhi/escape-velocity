/**
 * S0.4 裸测（R3）：竖屏相机能否框住整条轨道。
 *
 * 约束：运行时无法切换窗口尺寸（View.size 只读），所以不能直接截竖屏图。
 * 但 game/Projection.ts 已用 getRayDirection 标定到 1px 误差，
 * 因此可以把它当作“已验证的投影计算器”，对任意宽高比（含竖屏 1080×1920）
 * 精确算出画面坐标 —— 直接回答“整条轨道装不装得下”。
 *
 * 产出：.agent/test-results/s0-camera.txt
 */
import { Content, Path, View } from 'Dora';
import { CameraView, HANDEDNESS, FLIP_Y, V3, project } from 'game/Projection';

const resultPath = Path(Content.searchPaths[0], '.agent', 'test-results', 's0-camera.txt');
const lines: string[] = [];

// 设计分辨率（竖屏）
const DESIGN_W = 1080;
const DESIGN_H = 1920;
const PORTRAIT_ASPECT = DESIGN_W / DESIGN_H; // 0.5625

lines.push(`portrait design = ${DESIGN_W}x${DESIGN_H} aspect=${PORTRAIT_ASPECT.toFixed(4)}`);
lines.push(`engine fovY = ${View.fieldOfView} (deg)`);
lines.push('');

/** 一条代表性轨道的关键世界点（物理平面为 XZ，y=0）。 */
function trackPoints(vertical: boolean): V3[] {
	const pts: V3[] = [];
	if (vertical) {
		// 轨道沿屏幕纵向展开（沿 Z 进深）：出发点近、目标点远
		pts.push({ x: 0, y: 0, z: 9 });   // start（近）
		pts.push({ x: 0, y: 0, z: -13 }); // goal（远）
		// 行星轨道（半径 5）
		for (let i = 0; i < 16; i++) {
			const a = i * Math.PI * 2 / 16;
			pts.push({ x: Math.sin(a) * 5, y: 0, z: Math.cos(a) * 5 });
		}
	} else {
		// 轨道沿屏幕横向展开（沿 X）
		pts.push({ x: -6, y: 0, z: 2 });
		pts.push({ x: 10, y: 0, z: 2 });
		for (let i = 0; i < 16; i++) {
			const a = i * Math.PI * 2 / 16;
			pts.push({ x: 2 + Math.sin(a) * 5, y: 0, z: Math.cos(a) * 5 });
		}
	}
	return pts;
}

interface Fit {
	maxNdcX: number;
	maxNdcY: number;
	fits: boolean;
}

function evaluate(pts: V3[], tiltDeg: number, dist: number, aspect: number, fovY: number): Fit {
	const tilt = tiltDeg * Math.PI / 180;
	const target: V3 = { x: 0, y: 0, z: 0 };
	// 相机在 target 上方后方：由倾角与距离决定位置
	const eye: V3 = {
		x: 0,
		y: Math.sin(tilt) * dist,
		z: Math.cos(tilt) * dist,
	};
	const cam: CameraView = {
		eye,
		target,
		up: { x: 0, y: 1, z: 0 },
		fovYDeg: fovY,
		aspect,
		viewW: 1080,
		viewH: 1920,
	};

	let maxNdcX = 0;
	let maxNdcY = 0;
	let behind = false;

	for (const p of pts) {
		const q = project(p, cam, HANDEDNESS, FLIP_Y);
		if (q === undefined) { behind = true; continue; }
		const ndcX = Math.abs(q.x) / (1080 / 2);
		const ndcY = Math.abs(q.y) / (1920 / 2);
		if (ndcX > maxNdcX) maxNdcX = ndcX;
		if (ndcY > maxNdcY) maxNdcY = ndcY;
	}

	return { maxNdcX, maxNdcY, fits: !behind && maxNdcX <= 1 && maxNdcY <= 1 };
}

// ---- 1) 横向轨道在竖屏下：扫描距离找最小可用值 ----
lines.push('== 1) horizontal track in PORTRAIT (aspect 0.5625) ==');
lines.push('tilt=45deg, fovY=45');
const hPts = trackPoints(false);
lines.push('dist | maxNdcX maxNdcY | fits');
for (const d of [10, 15, 20, 25, 30, 40, 50, 70, 100]) {
	const f = evaluate(hPts, 45, d, PORTRAIT_ASPECT, View.fieldOfView);
	lines.push(`${d} | ${f.maxNdcX.toFixed(2)} ${f.maxNdcY.toFixed(2)} | ${f.fits}`);
}
lines.push('');

// ---- 2) 纵向轨道在竖屏下：扫描距离 ----
lines.push('== 2) vertical track in PORTRAIT (aspect 0.5625) ==');
lines.push('tilt=45deg, fovY=45');
const vPts = trackPoints(true);
lines.push('dist | maxNdcX maxNdcY | fits');
for (const d of [10, 15, 20, 25, 30, 40, 50, 70, 100]) {
	const f = evaluate(vPts, 45, d, PORTRAIT_ASPECT, View.fieldOfView);
	lines.push(`${d} | ${f.maxNdcX.toFixed(2)} ${f.maxNdcY.toFixed(2)} | ${f.fits}`);
}
lines.push('');

// ---- 3) 倾角的影响（纵向轨道，固定距离 30） ----
lines.push('== 3) tilt sweep for VERTICAL track in PORTRAIT (dist=30) ==');
lines.push('tilt | maxNdcX maxNdcY | fits');
for (const t of [20, 30, 40, 50, 60, 70, 80]) {
	const f = evaluate(vPts, t, 30, PORTRAIT_ASPECT, View.fieldOfView);
	lines.push(`${t} | ${f.maxNdcX.toFixed(2)} ${f.maxNdcY.toFixed(2)} | ${f.fits}`);
}
lines.push('');

// ---- 4) 同样参数下横向轨道 vs 纵向轨道对比 ----
lines.push('== 4) horizontal vs vertical at identical camera (dist=30, tilt=45) ==');
const fh = evaluate(hPts, 45, 30, PORTRAIT_ASPECT, View.fieldOfView);
const fv = evaluate(vPts, 45, 30, PORTRAIT_ASPECT, View.fieldOfView);
lines.push(`horizontal: ndcX=${fh.maxNdcX.toFixed(2)} ndcY=${fh.maxNdcY.toFixed(2)} fits=${fh.fits}`);
lines.push(`vertical:   ndcX=${fv.maxNdcX.toFixed(2)} ndcY=${fv.maxNdcY.toFixed(2)} fits=${fv.fits}`);
lines.push('');

// ---- 5) 对比横屏（当前引擎窗口 2024x1230） ----
lines.push('== 5) same tracks in LANDSCAPE (aspect 1.6455) ==');
const land = View.aspectRatio;
const fhL = evaluate(hPts, 45, 30, land, View.fieldOfView);
const fvL = evaluate(vPts, 45, 30, land, View.fieldOfView);
lines.push(`horizontal: ndcX=${fhL.maxNdcX.toFixed(2)} ndcY=${fhL.maxNdcY.toFixed(2)} fits=${fhL.fits}`);
lines.push(`vertical:   ndcX=${fvL.maxNdcX.toFixed(2)} ndcY=${fvL.maxNdcY.toFixed(2)} fits=${fvL.fits}`);
lines.push('');

// 结论
const vFit = evaluate(vPts, 45, 30, PORTRAIT_ASPECT, View.fieldOfView);
lines.push(`RESULT=${vFit.fits ? 'PASS' : 'FAIL'}`);
lines.push('note: vertical layout means the flight path runs up the screen (along world Z).');

Content.save(resultPath, lines.join('\n'));
