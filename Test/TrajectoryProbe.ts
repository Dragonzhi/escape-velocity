/**
 * S1.3 运行时探针：轨迹渲染（预测线 + 真实尾迹）。
 *
 * 验证：
 *   1) 预测线与真实尾迹都能画出来（视觉区域内检出）
 *   2) 二者形状一致（同一套投影 + 同一份物理推演）
 *
 * 产出：.agent/test-results/s13-trajectory.txt
 */
import { App, Camera3D, Content, Director, Path, Vec3, View, threadLoop } from 'Dora';
import { CameraView, HANDEDNESS, FLIP_Y, prepareCamera } from 'game/Projection';
import { Body, P2, ProbeState, simulate } from 'game/Gravity';
import { createCameraRig, defaultRigOptions } from 'game/CameraRig';
import { TrajectoryView, createTrajectoryView, defaultOptions } from 'game/Trajectory';
import { captureReport } from 'Test/Vision';

const root = Content.searchPaths[0];
const outDir = Path(root, '.agent', 'test-results');
if (!Content.exist(outDir)) Content.mkdir(outDir);
const marker = Path(outDir, 's13-trajectory.txt');

const lines: string[] = [];
function flush(final: boolean): void {
	Content.save(marker, lines.join('\n') + (final ? '\nphase=done' : ''));
}
lines.push('phase=started');
flush(false);

// ---- 场景：一个静止行星 ----
const bodies: Body[] = [{
	gm: 900, radius: 2.2,
	orbitCenter: { x: 0, y: 0 }, orbitRadius: 0,
	orbitPeriod: 0, phase0: 0, orbitDirection: 1,
}];

const probeStart: P2 = { x: 0, y: 16 };
const view = Director.entry;
view.setEnvironmentIntensity(0.35, 0.35, 1);

// 探测器用一个可见标记（不加载模型，先用小圆代位；重点是轨迹）
const camera = Camera3D();
Director.pushCamera(camera);

const rig = createCameraRig(defaultRigOptions());
// 2D 轨迹必须挂在 Director.ui（3D 视图根 Director.entry 是 View3D，不能挂 2D Line）
const traj: TrajectoryView = createTrajectoryView(Director.ui, defaultOptions());
lines.push('trajectory view created (on Director.ui)');

// ---- 物理：一条掠过行星的轨迹 ----
// 关键设计：**预测线与真实尾迹来自同一份 simulate 结果**（手册 §5.5）。
// 预测线 = 从发射点算出的完整路径；尾迹 = 其中已飞过的那段前缀。
const initial: ProbeState = { pos: probeStart, vel: { x: 6, y: -12 } };
const simFull = simulate(initial, bodies, { steps: 1500, dt: 1 / 120, sampleEvery: 5, escapeRadius: 400 });
lines.push(`full sim: outcome=${simFull.outcome} points=${simFull.points.length} stepsRun=${simFull.stepsRun}`);
flush(false);

const W = View.size.width;
const H = View.size.height;
const aspect = View.aspectRatio;
lines.push(`view=${W}x${H} aspect=${aspect.toFixed(4)}`);
flush(false);

let frame = 0;
let requested = false;
let analyzed = false;
let trajectoryShot = '';

threadLoop(() => {
	frame += 1;

	// 逐帧推进：探测器沿轨迹前进，尾部累积真实尾迹
	const idx = frame * 3;
	const capped = idx < simFull.points.length ? idx : simFull.points.length - 1;
	const probePos: P2 = simFull.points[capped];

	// 相机跟随
	const rigFrame = rig.step([probePos, { x: 0, y: 0 }]);
	camera.lookAt(rigFrame.eye, rigFrame.target, Vec3(0, 1, 0));

	// 构造当前帧的相机基（投影用）
	const camView: CameraView = {
		eye: { x: rigFrame.eye.x, y: rigFrame.eye.y, z: rigFrame.eye.z },
		target: { x: rigFrame.target.x, y: rigFrame.target.y, z: rigFrame.target.z },
		up: { x: 0, y: 1, z: 0 },
		fovYDeg: View.fieldOfView,
		aspect,
		viewW: W,
		viewH: H,
	};
	const basis = prepareCamera(camView, HANDEDNESS, FLIP_Y);

	// 预测线：完整路径（同一份 simulate 结果）
	traj.setPrediction(simFull.points, basis);

	// 真实尾迹：从起点到当前位置的前缀
	const trail: P2[] = [];
	for (let i = 0; i <= capped && i < simFull.points.length; i++) trail.push(simFull.points[i]);
	traj.setTrail(trail, basis);

	if (!requested && frame > 3) {
		requested = true;
		trajectoryShot = App.saveScreenshot(Path(outDir, 's13-trajectory'));
		lines.push(`shot requested at frame=${frame}`);
		flush(false);
	}

	if (requested && !analyzed && frame > 20) {
		analyzed = true;
		lines.push(`analyzing at frame=${frame}, probe=(${probePos.x.toFixed(1)}, ${probePos.y.toFixed(1)})`);
		lines.push(`trail points=${trail.length} predict points=${simFull.points.length}`);
		lines.push('');
		lines.push('--- trajectory frame (prediction + trail) ---');
		lines.push(captureReport(trajectoryShot, ['prediction line = full path', 'trail = prefix already flown']));
		flush(true);
		return true;
	}

	return false;
});
