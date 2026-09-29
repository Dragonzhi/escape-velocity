/**
 * S1.2 单测：相机机架的纯计算部分（无需运行场景）。
 *
 * 输出格式：首行为 `passed` 或 `failed`。
 *   const m = requireProjectModule("Test.CameraRigTest"); print(m.runTests())
 */
import { RigFrame, RigOptions, createCameraRig, computeFit, defaultRigOptions } from 'game/CameraRig';
import { PlaneToWorldX, PlaneToWorldZ, SlowMoCloseDist } from 'game/Config';
import { P2 } from 'game/Gravity';
import { CameraView, FLIP_Y, HANDEDNESS, prepareCamera, projectPrepared } from 'game/Projection';

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

/** 1) computeFit：包围盒中心与半对角。 */
function testFit(): void {
	const pts: P2[] = [
		{ x: -10, y: -10 },
		{ x: 10, y: 10 },
	];
	const f = computeFit(pts);
	check('fit-center', Math.abs(f.centerX) < 1e-12 && Math.abs(f.centerY) < 1e-12, `center=(${f.centerX}, ${f.centerY})`);
	// 半对角 = sqrt(10^2 + 10^2) = 14.142
	check('fit-extent', Math.abs(f.extent - Math.sqrt(200)) < 1e-9, `extent=${f.extent}`);

	// 空集不应该崩
	const empty = computeFit([]);
	check('fit-empty', empty.extent === 0 && empty.centerX === 0, `extent=${empty.extent}`);

	// 单点：extent 应为 0，中心即该点
	const one = computeFit([{ x: 3, y: -4 }]);
	check('fit-single', one.extent === 0 && one.centerX === 3 && one.centerY === -4, `extent=${one.extent}`);
}

/** 2) 距离单调性：探测器越远，相机距离越大（S1.2 的核心验收点）。 */
function testDistanceMonotonic(): void {
	const opts = defaultRigOptions();
	const planets: P2[] = [{ x: 0, y: 0 }, { x: 0, y: -14 }];

	const rig = createCameraRig(opts);

	// 探测器从近到远推进
	const dists: number[] = [];
	for (const probeY of [14, 20, 30, 50, 80, 120]) {
		const frame = rig.step([{ x: 0, y: probeY }, planets[0], planets[1]]);
		const dx = frame.eye.x - frame.target.x;
		const dy = frame.eye.y - frame.target.y;
		const dz = frame.eye.z - frame.target.z;
		dists.push(Math.sqrt(dx * dx + dy * dy + dz * dz));
	}

	// ⚠️ 容差 1e-3 而不是 1e-9：相机的 eye/target 是 **float32** 的 Vec3（手册 §5 的实测坑），
	//    夹紧在 CameraMinDistance（S3.7 起 = 60）上的几档距离会带 ~1e-5 的噪声，
	//    严格单调在夹紧区里站不住 —— 要判的是"单调不减"，不是"逐位变大"。
	let monotonic = true;
	for (let i = 1; i < dists.length; i++) {
		if (dists[i] < dists[i - 1] - 1e-3) {
			monotonic = false;
			break;
		}
	}
	check('rig-distance-monotonic', monotonic, `distances=${dists.map(d => d.toFixed(1)).join(', ')}`);

	// 应该真的拉远了（不是不变）
	const grew = dists[dists.length - 1] > dists[0] + 1;
	check('rig-distance-grows', grew, `first=${dists[0].toFixed(1)} last=${dists[dists.length - 1].toFixed(1)}`);
}

/**
 * 6) 取景：关键点（**含探测器的模型半径**）必须全部落在画面内。
 *
 * 这是 S3.1 的回归点：旧算法「距离 = min + 半对角 × 1.6」是与相机无关的启发式，
 * 竖屏（aspect 0.5638）下 L3 的探测器中心被投到 ndcX = 1.11 —— 整个跑到画面外，
 * 表现为「进关卡看不到自己的飞行器，预测线从画面外射进来」（截图发现）。
 */
function overflowOf(frame: RigFrame, opts: RigOptions, pts: P2[], radius: number): number {
	const view: CameraView = {
		eye: frame.eye,
		target: frame.target,
		up: { x: 0, y: 1, z: 0 },
		fovYDeg: opts.fovYDeg,
		aspect: opts.aspect,
		viewW: 2,
		viewH: 2,
	};
	const basis = prepareCamera(view, HANDEDNESS, FLIP_Y);
	let worst = 0;
	for (let i = 0; i < pts.length; i++) {
		const p = projectPrepared(
			{ x: pts[i].x * PlaneToWorldX, y: 0, z: pts[i].y * PlaneToWorldZ },
			basis,
		);
		if (p === undefined) return 99; // 在相机后方
		const r = i === 0 ? radius : 0;
		const ry = (r / p.vz) * basis.focal;
		const rx = ry / opts.aspect;
		const ox = Math.abs(p.x) + rx;
		const oy = Math.abs(p.y) + ry;
		if (ox > worst) worst = ox;
		if (oy > worst) worst = oy;
	}
	return worst;
}

function testFraming(): void {
	// L3 实测那组关键点：探测器 (0,18)、木星 (0,-2)、土星 (-26,-26)
	const pts: P2[] = [{ x: 0, y: 18 }, { x: 0, y: -2 }, { x: -26, y: -26 }];
	// Probe_Voyager_v1：局部最长边 3.227 × scale 1.2 × 1.1 余量 ÷ 2
	const probeRadius = 2.13;

	const portrait = defaultRigOptions(45, 601 / 1066);
	const rigP = createCameraRig(portrait);
	const frameP = rigP.step(pts, probeRadius);
	const overP = overflowOf(frameP, portrait, pts, probeRadius);
	const limit = 1 - portrait.margin;
	check('rig-frame-portrait-fits', overP <= limit + 1e-6, `max|ndc|=${overP.toFixed(4)} limit=${limit.toFixed(2)}`);

	// 旧算法会给出 ndcX > 1：新的必须明显留有余量
	check('rig-frame-probe-inside', overP < 0.99, `max|ndc|=${overP.toFixed(4)}（旧算法 1.11 = 出画）`);

	// 距离仍受夹紧约束
	const dx = frameP.eye.x - frameP.target.x;
	const dy = frameP.eye.y - frameP.target.y;
	const dz = frameP.eye.z - frameP.target.z;
	const distP = Math.sqrt(dx * dx + dy * dy + dz * dz);
	check(
		'rig-frame-portrait-distance',
		distP >= portrait.minDistance * 0.999 && distP <= portrait.maxDistance * 1.001,
		`dist=${distP.toFixed(2)} range=[${portrait.minDistance}, ${portrait.maxDistance}]`,
	);

	// 横屏（同一组关键点）：横向空间大得多，要求同样成立
	const landscape = defaultRigOptions(45, 2024 / 1231);
	const rigL = createCameraRig(landscape);
	const frameL = rigL.step(pts, probeRadius);
	const overL = overflowOf(frameL, landscape, pts, probeRadius);
	check('rig-frame-landscape-fits', overL <= 1 - landscape.margin + 1e-6, `max|ndc|=${overL.toFixed(4)}`);

	// 探测器半径变大时必须拉得更远（约束真的在起作用，而不是被忽略）
	const frameFar = createCameraRig(portrait).step(pts, 8.0);
	const fx = frameFar.eye.x - frameFar.target.x;
	const fy = frameFar.eye.y - frameFar.target.y;
	const fz = frameFar.eye.z - frameFar.target.z;
	const distFar = Math.sqrt(fx * fx + fy * fy + fz * fz);
	check('rig-frame-radius-matters', distFar > distP + 0.5, `r=2.13 → ${distP.toFixed(2)}, r=8.0 → ${distFar.toFixed(2)}`);
}

/** 3) 距离夹紧：不超出 [min, max]。 */
function testClamp(): void {
	const opts = defaultRigOptions();
	const rig = createCameraRig(opts);

	// 极端远
	const far = rig.step([{ x: 0, y: 5000 }, { x: 0, y: 0 }]);
	const dx = far.eye.x - far.target.x;
	const dy = far.eye.y - far.target.y;
	const dz = far.eye.z - far.target.z;
	const dFar = Math.sqrt(dx * dx + dy * dy + dz * dz);
	// 用相对容差：距离是由 sin/cos 重建的，存在 ~1e-7 的浮点误差
	check('rig-clamp-max', dFar <= opts.maxDistance * 1.001, `distance=${dFar} max=${opts.maxDistance}`);

	// 全部重合
	const near = rig.step([{ x: 0, y: 0 }, { x: 0, y: 0 }]);
	const ex = near.eye.x - near.target.x;
	const ey = near.eye.y - near.target.y;
	const ez = near.eye.z - near.target.z;
	const dNear = Math.sqrt(ex * ex + ey * ey + ez * ez);
	check('rig-clamp-min', dNear >= opts.minDistance * 0.999, `distance=${dNear} min=${opts.minDistance}`);
}

/** 4) 倾角固定：相机到注视点的方向应始终符合 tilt。 */
function testTilt(): void {
	const opts = defaultRigOptions();
	const rig = createCameraRig(opts);
	const frame = rig.step([{ x: 5, y: 5 }, { x: -5, y: -5 }]);

	const dz = frame.eye.z - frame.target.z;
	const dy = frame.eye.y - frame.target.y;
	const angle = Math.atan2(dy, dz) * 180 / Math.PI;
	check('rig-tilt', Math.abs(angle - opts.tiltDeg) < 0.5, `angle=${angle.toFixed(2)} expected=${opts.tiltDeg}`);
	check('rig-tilt-in-range', opts.tiltDeg >= 20 && opts.tiltDeg <= 60, `tilt=${opts.tiltDeg}（安全区 20–60）`);
}

/** 5) 平滑：lerp 较小时，单帧不会直接跳到目标值。 */
function testSmoothing(): void {
	const opts = defaultRigOptions();
	opts.lerp = 0.1;
	const rig = createCameraRig(opts);

	const a = rig.step([{ x: 0, y: 0 }]);        // 首帧吸附
	const b = rig.step([{ x: 100, y: 0 }]);      // 远处：应只移动一部分

	const moved = Math.abs(b.target.x - a.target.x);
	// 平滑后 x 应明显小于 100，但大于 0
	check('rig-smoothing-partial', moved > 0.5 && moved < 99, `moved=${moved.toFixed(2)}（应在 0 与 100 之间）`);
}


/**
 * 7) 慢动作特写的距离下限（S3.17）：step 的第 4 个参数只换夹紧左端，不另写一套取景。
 *
 * 判据：① 同一组关键点 + 逐点半径，传了更小的下限就**真的更近**（贴近被掠过的天体）；
 * ② 下限只是地板，求解器仍保证全部关键点（含半径）在画面内；③ 日常取景（不传）不受影响。
 */
function testSlowMoCloseup(): void {
	const opts = defaultRigOptions(45, 601 / 1066);
	// L3 掠过瞬间：探测器 (0,13)、木星 (0,0)（阈值 23.2 内），半径 2.13 / 4.63
	const pts: P2[] = [{ x: 0, y: 13 }, { x: 0, y: 0 }];
	const radii = [2.13, 4.63];
	// ⚠️ 宽/近各用一台**全新的 rig**：step 带平滑状态（首帧吸附、之后 lerp），
	//    同一台 rig 连调两次，第二次只向目标移动 10%（实测 60 → 56.6），比不出"贴近"。
	const wide = createCameraRig(opts).step(pts, 2.13, radii);
	const close = createCameraRig(opts).step(pts, 2.13, radii, SlowMoCloseDist);
	const dist = (f: RigFrame): number => {
		const dx = f.eye.x - f.target.x;
		const dy = f.eye.y - f.target.y;
		const dz = f.eye.z - f.target.z;
		return Math.sqrt(dx * dx + dy * dy + dz * dz);
	};
	check('rig-slowmo-closer', dist(close) < dist(wide) - 20,
		'close=' + dist(close).toFixed(1) + ' wide=' + dist(wide).toFixed(1) + '（贴近被掠过的天体）');
	check('rig-slowmo-floor', dist(close) >= SlowMoCloseDist * 0.999,
		'dist=' + dist(close).toFixed(2) + ' floor=' + SlowMoCloseDist);

	// 关键点仍全部在画面内（逐点半径约束没被绕过）—— overflowOf 只算 pts[0] 的半径，这里逐点算
	const view: CameraView = {
		eye: close.eye,
		target: close.target,
		up: { x: 0, y: 1, z: 0 },
		fovYDeg: opts.fovYDeg,
		aspect: opts.aspect,
		viewW: 2,
		viewH: 2,
	};
	const basis = prepareCamera(view, HANDEDNESS, FLIP_Y);
	let worst = 0;
	for (let i = 0; i < pts.length; i++) {
		const p = projectPrepared({ x: pts[i].x * PlaneToWorldX, y: 0, z: pts[i].y * PlaneToWorldZ }, basis);
		if (p === undefined) { worst = 99; break; }
		const ry = (radii[i] / p.vz) * basis.focal;
		const rx = ry / opts.aspect;
		if (Math.abs(p.x) + rx > worst) worst = Math.abs(p.x) + rx;
		if (Math.abs(p.y) + ry > worst) worst = Math.abs(p.y) + ry;
	}
	check('rig-slowmo-fits', worst <= 1 - opts.margin + 1e-6,
		'max|ndc|=' + worst.toFixed(4) + ' limit=' + (1 - opts.margin).toFixed(2));

	// 不传下限 ⇒ 日常取景仍被 CameraMinDistance 夹住（60），不受慢动作参数影响
	const again = createCameraRig(opts).step(pts, 2.13, radii);
	check('rig-slowmo-opt-in', Math.abs(dist(again) - opts.minDistance) < 1,
		'dist=' + dist(again).toFixed(1) + ' 期望夹在 ' + opts.minDistance);
}

export function runTests(): string {
	testFit();
	testDistanceMonotonic();
	testClamp();
	testTilt();
	testSmoothing();
	testFraming();
	testSlowMoCloseup();
	// 分镜改变方位后仍走逐点投影约束；不影响下一次默认机位。
	const shotOpts = defaultRigOptions(45, 601 / 1065, 200, 2000);
	shotOpts.margin = 0.16;
	const shotPts = [{ x: 50, y: 20 }, { x: 0, y: 0 }];
	const shotRadii = [12, 28];
	const shotRig = createCameraRig(shotOpts);
	const shot = shotRig.step(shotPts, 12, shotRadii, 130, { azDeg: 95, tiltDeg: 42, lerp: 1 });
	const shotBasis = prepareCamera({ eye: shot.eye, target: shot.target, up: { x: 0, y: 1, z: 0 }, fovYDeg: 45, aspect: shotOpts.aspect, viewW: 2, viewH: 2 }, HANDEDNESS, FLIP_Y);
	for (let i = 0; i < shotPts.length; i++) {
		const p = projectPrepared({ x: shotPts[i].x, y: 0, z: shotPts[i].y }, shotBasis);
		check('shot-subject-fits-' + i.toFixed(0), p !== undefined && Math.abs(p.x) + shotRadii[i] / p.vz * shotBasis.focal / shotOpts.aspect <= 0.84001
			&& Math.abs(p.y) + shotRadii[i] / p.vz * shotBasis.focal <= 0.84001, '含模型半径的局部机位必须装下两主体');
	}
	check('shot-has-azimuth', Math.abs(shot.eye.x - shot.target.x) > 20, '机位方位覆盖需要生效');
	const defaultShot = shotRig.step(shotPts, 12, shotRadii);
	check('shot-override-does-not-leak', Math.abs(defaultShot.eye.x - defaultShot.target.x) < 0.001, '局部方位覆盖不能改变默认机位');
	shotOpts.screenMinY = 2 * 350 / 1065 - 1;
	shotOpts.screenMaxY = 1 - 2 * 205 / 1065;
	shotOpts.screenBiasY = 0.14;
	const returnPts = [{ x: -130, y: 257 }, { x: 0, y: 0 }];
	const returnRadii = [12, 42];
	const home = createCameraRig(shotOpts).step(returnPts, 12, returnRadii, 180, { azDeg: -27, tiltDeg: 42, lerp: 1 });
	const homeBasis = prepareCamera({ eye: home.eye, target: home.target, up: { x: 0, y: 1, z: 0 }, fovYDeg: 45, aspect: shotOpts.aspect, viewW: 601, viewH: 1065 }, HANDEDNESS, FLIP_Y);
	for (let i = 0; i < returnPts.length; i++) {
		const p = projectPrepared({ x: returnPts[i].x, y: 0, z: returnPts[i].y }, homeBasis);
		const r = p !== undefined ? returnRadii[i] / p.vz * homeBasis.focal * 1065 / 2 : 1e9;
		check('return-subject-clears-hud-' + i.toFixed(0), p !== undefined && 1065 / 2 + p.y - r >= 349.9 && 1065 / 2 + p.y + r <= 860.1, '返回画面中地球与飞船不能被底部按钮/顶部文字遮住');
	}

	const lines: string[] = [];
	lines.push(failures.length === 0 ? 'passed' : 'failed');
	lines.push(`checks=${checks} failures=${failures.length}`);
	const limit = failures.length < 12 ? failures.length : 12;
	for (let i = 0; i < limit; i++) {
		lines.push(`FAIL ${failures[i].name}: ${failures[i].detail}`);
	}
	return lines.join('\n');
}
