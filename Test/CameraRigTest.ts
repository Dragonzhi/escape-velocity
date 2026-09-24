/**
 * S1.2 单测：相机机架的纯计算部分（无需运行场景）。
 *
 * 输出格式：首行为 `passed` 或 `failed`。
 *   const m = requireProjectModule("Test.CameraRigTest"); print(m.runTests())
 */
import { createCameraRig, computeFit, defaultRigOptions } from 'game/CameraRig';
import { P2 } from 'game/Gravity';

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

	let monotonic = true;
	for (let i = 1; i < dists.length; i++) {
		if (dists[i] < dists[i - 1] - 1e-9) {
			monotonic = false;
			break;
		}
	}
	check('rig-distance-monotonic', monotonic, `distances=${dists.map(d => d.toFixed(1)).join(', ')}`);

	// 应该真的拉远了（不是不变）
	const grew = dists[dists.length - 1] > dists[0] + 1;
	check('rig-distance-grows', grew, `first=${dists[0].toFixed(1)} last=${dists[dists.length - 1].toFixed(1)}`);
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

export function runTests(): string {
	testFit();
	testDistanceMonotonic();
	testClamp();
	testTilt();
	testSmoothing();

	const lines: string[] = [];
	lines.push(failures.length === 0 ? 'passed' : 'failed');
	lines.push(`checks=${checks} failures=${failures.length}`);
	const limit = failures.length < 12 ? failures.length : 12;
	for (let i = 0; i < limit; i++) {
		lines.push(`FAIL ${failures[i].name}: ${failures[i].detail}`);
	}
	return lines.join('\n');
}
