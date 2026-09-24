/**
 * S1.4 运行时探针：拖拽矄准 → 发射向量 → 预测轨迹。
 *
 * 验证：
 *   1) 矄准输入层能创建并挂到 Director.ui
 *   2) 驱动一次拖拽能得到变化的发射向量（力度/方向）
 *   3) 矄准结果能驱动 simulate 并画出预测线
 *
 * ⚠️ 局限：`Touch` 是私有构造，**无法**程序化注入真触摸事件，
 * 因此这里走 `handleLocal`（本条链路上唯一的坐标转换点）。
 * 真触摸的坐标系仍需一次人工校对（手册 §5.7）。
 *
 * 产出：.agent/test-results/s14-hud.txt
 */
import { App, Camera3D, Content, Director, Node3D, Path, Vec3, View, threadLoop } from 'Dora';
import { CameraView, HANDEDNESS, FLIP_Y, prepareCamera, project } from 'game/Projection';
import { Body, P2, ProbeState, simulate } from 'game/Gravity';
import { createCameraRig, defaultRigOptions } from 'game/CameraRig';
import { TrajectoryView, createTrajectoryView, defaultOptions } from 'game/Trajectory';
import { AimInput, AimResult, createAimInput, defaultMaxDragPx } from 'game/Hud';
import { captureReport } from 'Test/Vision';

const root = Content.searchPaths[0];
const outDir = Path(root, '.agent', 'test-results');
if (!Content.exist(outDir)) Content.mkdir(outDir);
const marker = Path(outDir, 's14-hud.txt');

const lines: string[] = [];
function flush(final: boolean): void {
	Content.save(marker, lines.join('\n') + (final ? '\nphase=done' : ''));
}
lines.push('phase=started');
flush(false);

const bodies: Body[] = [{
	gm: 900, radius: 2.2,
	orbitCenter: { x: 0, y: 0 }, orbitRadius: 0,
	orbitPeriod: 0, phase0: 0, orbitDirection: 1,
}];

const probeStart: P2 = { x: 0, y: 16 };
const view = Director.entry;
view.setEnvironmentIntensity(0.35, 0.35, 1);

const camera = Camera3D();
Director.pushCamera(camera);
const rig = createCameraRig(defaultRigOptions());
const traj: TrajectoryView = createTrajectoryView(Director.ui, defaultOptions());

// 相机先对准探测器
const rigFrame = rig.step([probeStart, { x: 0, y: 0 }]);
camera.lookAt(rigFrame.eye, rigFrame.target, Vec3(0, 1, 0));

const W = View.size.width;
const H = View.size.height;

const camView: CameraView = {
	eye: { x: rigFrame.eye.x, y: rigFrame.eye.y, z: rigFrame.eye.z },
	target: { x: rigFrame.target.x, y: rigFrame.target.y, z: rigFrame.target.z },
	up: { x: 0, y: 1, z: 0 },
	fovYDeg: View.fieldOfView,
	aspect: View.aspectRatio,
	viewW: W,
	viewH: H,
};
const basis = prepareCamera(camView, HANDEDNESS, FLIP_Y);

// 探测器在屏幕上的位置（用已标定的投影算）
const probeProj = project({ x: probeStart.x, y: 0, z: probeStart.y }, camView, HANDEDNESS, FLIP_Y);

const aim: AimInput = createAimInput(Director.ui, W, H);
lines.push(`view=${W}x${H}`);
lines.push(`probe screen = ${probeProj !== undefined ? `(${probeProj.x.toFixed(1)}, ${probeProj.y.toFixed(1)})` : 'BEHIND CAMERA'}`);
lines.push(`maxDragPx=${defaultMaxDragPx()}`);

if (probeProj === undefined) {
	lines.push('RESULT=FAIL reason=probe-behind-camera');
	flush(true);
} else {
	// project() 输出即投影偏移空间
	const probeOffset = { x: probeProj.x, y: probeProj.y };
	aim.setProbeOffset(probeOffset);
	aim.setEnabled(true);

	// 收集拖动回调
	let lastAim: AimResult = aim.current();
	let dragCount = 0;
	aim.onDrag((a) => {
		lastAim = a;
		dragCount += 1;
	});
	let released: AimResult | undefined = undefined;
	aim.onRelease((a) => {
		released = a;
	});

	// 驱动一次拖拽：从探测器位置往右下方拖
	const dragTo = { x: probeOffset.x + 40, y: probeOffset.y + 260 };
	aim.handleOffset(dragTo);

	lines.push(`after drag to offset(${dragTo.x.toFixed(0)}, ${dragTo.y.toFixed(0)}):`);
	lines.push(`  dragCount=${dragCount}`);
	lines.push(`  power=${lastAim.power.toFixed(3)}`);
	lines.push(`  unit=(${lastAim.unit.x.toFixed(3)}, ${lastAim.unit.y.toFixed(3)})`);
	lines.push(`  velocity=(${lastAim.velocity.x.toFixed(2)}, ${lastAim.velocity.y.toFixed(2)})`);

	// 验证“松手 = 发射”回调确实触发
	lines.push(`  released=${released !== undefined}`);

	// 用该向量推演预测轨迹并画出来
	const predicted = simulate(
		{ pos: probeStart, vel: lastAim.velocity },
		bodies,
		{ steps: 900, dt: 1 / 120, sampleEvery: 4, escapeRadius: 400 },
	);
	traj.setPrediction(predicted.points, basis);
	traj.setTrail([probeStart], basis);
	lines.push(`  predicted: outcome=${predicted.outcome} points=${predicted.points.length}`);
	flush(false);

	// 运行几帧后截图
	let frame = 0;
	let requested = false;
	let analyzed = false;
	let shot = '';

	threadLoop(() => {
		frame += 1;

		if (!requested && frame > 3) {
			requested = true;
			shot = App.saveScreenshot(Path(outDir, 's14-hud'));
			lines.push(`shot requested at frame=${frame}`);
			flush(false);
		}

		if (requested && !analyzed && frame > 16) {
			analyzed = true;
			lines.push('');
			lines.push('--- aim + prediction frame ---');
			lines.push(captureReport(shot, ['aim-driven prediction line']));
			flush(true);
			return true;
		}

		return false;
	});
}
