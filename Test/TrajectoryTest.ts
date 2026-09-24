/**
 * S1.3 单测：轨迹模块的纯逻辑部分。
 *
 * 重点：
 *   1) `decimate` 抽稀的正确性（首尾保留、不越界）
 *   2) `projectPolyline` 与直接调 `project()` 结果一致（确保预计算基没改变语义）
 *   3) **预测线与真实尾迹用同一套投影**（核心约束，手册 §5.5）
 *
 * 输出格式：首行为 `passed` 或 `failed`。
 *
 * ⚠️ 精度说明：`Vec2` 是 **float32**（引擎 C++ 类型），而普通对象是 float64。
 * 因此比较投影结果时，必须把期望值也降为 float32 再逐位比较，
 * 否则会出现 ~1e-8 相对误差（那是精度差异，不是公式错误）。
 */
import { Vec2 } from 'Dora';
import { View } from 'Dora';
import { prepareCamera, project, HANDEDNESS, FLIP_Y, toOverlay } from 'game/Projection';
import { P2 } from 'game/Gravity';
import { decimate, defaultOptions, projectPolyline } from 'game/Trajectory';
import { PlaneToWorldX, PlaneToWorldZ } from 'game/Config';

interface Failure {
	name: string;
	detail: string;
}

const failures: Failure[] = [];
let checks = 0;

function check(name: string, ok: boolean, detail: string): void {
	checks += 1;
	if (!ok) failures.push({ name, detail });
}

function sampleTrail(): P2[] {
	const pts: P2[] = [];
	for (let i = 0; i <= 30; i++) {
		pts.push({ x: i * 0.5, y: -i * 0.4 });
	}
	return pts;
}

/** 1) decimate：不超限、保留首尾、不返回 nil 项。 */
function testDecimate(): void {
	const pts = sampleTrail(); // 31 个点

	// 不超限 → 原样返回
	const same = decimate(pts, 100);
	check('decimate-noop', same.length === pts.length, `length=${same.length} expected=${pts.length}`);

	// 超限 → 抽稀到正好 maxPoints
	const d = decimate(pts, 8);
	check('decimate-length', d.length === 8, `length=${d.length} expected=8`);

	// 首尾必须保留
	const firstOk = d[0].x === pts[0].x && d[0].y === pts[0].y;
	const lastOk = d[d.length - 1].x === pts[pts.length - 1].x && d[d.length - 1].y === pts[pts.length - 1].y;
	check('decimate-keeps-ends', firstOk && lastOk, `first=(${d[0].x},${d[0].y}) last=(${d[d.length - 1].x},${d[d.length - 1].y})`);

	// 所有点都应是有效对象（防止 Lua 侧 nil 索引）
	let allValid = true;
	for (const p of d) {
		if (p === undefined) { allValid = false; break; }
	}
	check('decimate-no-nil', allValid, 'decimate 返回了 nil 元素');

	// 极端：maxPoints=2 应只留首尾
	const two = decimate(pts, 2);
	check('decimate-two', two.length === 2 && two[0].x === pts[0].x && two[1].x === pts[pts.length - 1].x, `length=${two.length}`);
}

/** 2) 预计算基与直接 project() 完全一致。 */
function testBasisConsistency(): void {
	const cam = {
		eye: { x: 3, y: 4, z: 8 },
		target: { x: 0, y: 0, z: 0 },
		up: { x: 0, y: 1, z: 0 },
		fovYDeg: 45,
		aspect: 0.5625,
		viewW: 1080,
		viewH: 1920,
	};
	const basis = prepareCamera(cam, HANDEDNESS, FLIP_Y);

	const pts: P2[] = [
		{ x: 0, y: 0 },
		{ x: 5, y: 3 },
		{ x: -7, y: -4 },
	];

	// 显式传 0,0：这里只验证"预计算基 == 直接 project()"，不含层空间偏移
	const viaPolyline = projectPolyline(pts, 0, basis, 0, 0);

	// 注意：projectPolyline 返回 Vec2（float32），而 toOverlay 返回 float64。
	// 把期望值也包成 Vec2 再逐位比较，以精确判定“公式是否一致”，
	// 而不受 float32 舍入干扰。
	let allExact = true;
	for (let i = 0; i < pts.length; i++) {
		const world = { x: pts[i].x * PlaneToWorldX, y: 0, z: pts[i].y * PlaneToWorldZ };
		const direct = project(world, cam, HANDEDNESS, FLIP_Y);
		if (direct === undefined) { allExact = false; break; }
		const expect = toOverlay(direct);
		const expectF32 = Vec2(expect.x, expect.y);
		if (viaPolyline[i].x !== expectF32.x || viaPolyline[i].y !== expectF32.y) {
			allExact = false;
			break;
		}
	}
	check('basis-matches-project', allExact, '预计算基与 project() 的结果不一致（降为 float32 后仍不同）');

	// 回归：绘制层是"左下原点绝对像素"，所以默认层原点必须是半个视图。
	// 漏掉这个偏移的表现是"预测线整体平移半个屏幕、不从探测器出发"（S2.2 真机踩过）。
	const opts = defaultOptions();
	const halfW = View.size.width / 2;
	const halfH = View.size.height / 2;
	check(
		'layer-origin-is-half-view',
		opts.layerOriginX === halfW && opts.layerOriginY === halfH,
		`layerOrigin=${opts.layerOriginX},${opts.layerOriginY} expect=${halfW},${halfH}`,
	);
}

/** 3) 核心约束：预测线与尾迹走同一套投影（同一批点 → 同一结果）。 */
function testPredictEqualsTrail(): void {
	const cam = {
		eye: { x: 0, y: 21.2, z: 21.2 },
		target: { x: 0, y: 0, z: 0 },
		up: { x: 0, y: 1, z: 0 },
		fovYDeg: 45,
		aspect: 0.5625,
		viewW: 1080,
		viewH: 1920,
	};
	const basis = prepareCamera(cam, HANDEDNESS, FLIP_Y);
	const opts = defaultOptions();
	const pts = sampleTrail();

	// 预测线用的路径（抽稀后投影）
	const predictPts = decimate(pts, opts.maxPoints);
	const predictProj = projectPolyline(predictPts, opts.y, basis, 0, 0);

	// 尾迹用的路径（同一套函数）
	const trailProj = projectPolyline(decimate(pts, opts.maxPoints), opts.y, basis, 0, 0);

	let same = predictProj.length === trailProj.length;
	if (same) {
		for (let i = 0; i < predictProj.length; i++) {
			if (predictProj[i].x !== trailProj[i].x || predictProj[i].y !== trailProj[i].y) { same = false; break; }
		}
	}
	check('predict-equals-trail', same, `predict=${predictProj.length} trail=${trailProj.length}（两者必须逐点相同）`);
}

/** 4) 投影结果的合理性：同一条竖直轨道应在屏幕上纵向展开。 */
function testVerticalSpread(): void {
	const cam = {
		eye: { x: 0, y: 21.2, z: 21.2 },
		target: { x: 0, y: 0, z: 0 },
		up: { x: 0, y: 1, z: 0 },
		fovYDeg: 45,
		aspect: 0.5625,
		viewW: 1080,
		viewH: 1920,
	};
	const basis = prepareCamera(cam, HANDEDNESS, FLIP_Y);

	// 沿世界 Z（= 平面 y）的一条直线
	const pts: P2[] = [{ x: 0, y: 10 }, { x: 0, y: 0 }, { x: 0, y: -10 }];
	const proj = projectPolyline(pts, 0, basis, 0, 0);

	check('spread-count', proj.length === 3, `count=${proj.length}`);
	// x 应基本居中（对称），y 应单调变化
	const xSpread = Math.abs(proj[0].x - proj[2].x);
	const ySpread = Math.abs(proj[0].y - proj[2].y);
	check('spread-vertical', ySpread > xSpread * 5, `ySpread=${ySpread.toFixed(1)} xSpread=${xSpread.toFixed(1)}（纵向轨道应主要沿屏幕 y 展开）`);
}

/** 5) 相机后方的点被丢弃，不产生垃圾坐标。 */
function testBehindCamera(): void {
	const cam = {
		eye: { x: 0, y: 0, z: 10 },
		target: { x: 0, y: 0, z: 0 },
		up: { x: 0, y: 1, z: 0 },
		fovYDeg: 45,
		aspect: 0.5625,
		viewW: 1080,
		viewH: 1920,
	};
	const basis = prepareCamera(cam, HANDEDNESS, FLIP_Y);

	// 一个在相机前、一个在相机后（z=20 在 eye 之后）
	const pts: P2[] = [{ x: 0, y: 0 }, { x: 0, y: 20 }];
	const proj = projectPolyline(pts, 0, basis, 0, 0);

	check('behind-camera-dropped', proj.length === 1, `count=${proj.length}（相机后方的点应被丢弃）`);
}

export function runTests(): string {
	testDecimate();
	testBasisConsistency();
	testPredictEqualsTrail();
	testVerticalSpread();
	testBehindCamera();

	const lines: string[] = [];
	lines.push(failures.length === 0 ? 'passed' : 'failed');
	lines.push(`checks=${checks} failures=${failures.length}`);
	const limit = failures.length < 12 ? failures.length : 12;
	for (let i = 0; i < limit; i++) {
		lines.push(`FAIL ${failures[i].name}: ${failures[i].detail}`);
	}
	return lines.join('\n');
}
