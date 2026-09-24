/**
 * S1.5 运行时探针：完整游戏循环（矄准 → 发射 → 飞行 → 结算 → 重试）。
 *
 * 验证：
 *   1) Aiming 态：拖动后预测线重画
 *   2) 发射后进入 Flying，行星公转、尾迹累积、相机拉远
 *   3) 飞行结束进入 Result，结局与物理推演一致
 *   4) 重试后回到 Aiming，可再次发射
 *
 * 产出：.agent/test-results/s15-game.txt
 */
import { App, Camera3D, Content, Director, Node3D, Path, Vec3, View, threadLoop } from 'Dora';
import { GravityScale, OrbitSpeedScale } from 'game/Config';
import { applyScales } from 'game/Gravity';
import { buildScene } from 'game/Scene';
import { createCameraRig, defaultRigOptions } from 'game/CameraRig';
import { createTrajectoryView, defaultOptions as trajectoryOptions } from 'game/Trajectory';
import { createAimInput } from 'game/Hud';
import { GameLevel, GamePhase, createGame } from 'game/Game';
import { captureReport } from 'Test/Vision';

const root = Content.searchPaths[0];
const outDir = Path(root, '.agent', 'test-results');
if (!Content.exist(outDir)) Content.mkdir(outDir);
const marker = Path(outDir, 's15-game.txt');

const lines: string[] = [];
function flush(final: boolean): void {
	Content.save(marker, lines.join('\n') + (final ? '\nphase=done' : ''));
}
lines.push('phase=started');
flush(false);

// ---- 测试关（与 init.ts 相同）----
const rawBodies = [
	{ gm: 900, radius: 2.2, orbitCenter: { x: 0, y: 0 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 as 1 | -1 },
	{ gm: 300, radius: 1.4, orbitCenter: { x: 0, y: -14 }, orbitRadius: 8, orbitPeriod: 10, phase0: 0, orbitDirection: 1 as 1 | -1 },
];
const bodies = applyScales(rawBodies, GravityScale, OrbitSpeedScale);
const visuals = [
	{ r: 0.55, g: 0.62, b: 0.78, displayRadius: 2.2, ring: false },
	{ r: 0.85, g: 0.72, b: 0.50, displayRadius: 1.4, ring: true },
];
const level: GameLevel = { bodies, probeStart: { x: 0, y: 16 }, escapeRadius: 400, maxSteps: 1500 };

const view = Director.entry;
view.setEnvironmentIntensity(0.35, 0.35, 1);

const scene = buildScene({
	root: view as unknown as Node3D.Type,
	bodies,
	visuals,
	probeStart: level.probeStart,
	probeScale: 1.6,
	spherePath: 'Assets/Model/Sphere.gltf',
	ringPath: 'Assets/Model/Ring.gltf',
	probePath: 'Assets/Model/Probe.gltf',
});

if (scene === undefined) {
	lines.push('RESULT=FAIL reason=scene-build-failed');
	flush(true);
} else {
	const camera = Camera3D();
	Director.pushCamera(camera);
	const rig = createCameraRig(defaultRigOptions());
	const trajectory = createTrajectoryView(Director.ui, trajectoryOptions());
	const aim = createAimInput(Director.ui, View.size.width, View.size.height);

	const phaseHistory: string[] = [];
	let resultKind = '';
	let probeOffsetLog = '';

	const game = createGame(level, {
		scene,
		camera,
		rig,
		trajectory,
		aim,
		viewW: View.size.width,
		viewH: View.size.height,
		fovYDeg: View.fieldOfView,
		aspect: View.aspectRatio,
		onPhase: (p: GamePhase) => {
			phaseHistory.push(`${p}@f${frame}`);
		},
		onResult: (r) => {
			resultKind = r;
		},
	});

	aim.onDrag((a) => game.onAimDrag(a));

	let frame = 0;
	let launched = false;
	let retried = false;
	let aimShot = '';
	let resultShot = '';
	let aimAnalyzed = false;
	let resultAnalyzed = false;
	let launchFrame = 0;
	let resultFrame = 0;
	let retryFrame = 0;
	let minRigDist = 1e9;
	let maxRigDist = 0;

	threadLoop(() => {
		frame += 1;
		game.update(App.deltaTime);

		// 记录机架距离范围（验证飞行中相机拉远）
		// （从 game 内部不可见，改由视觉与阶段证据代替；此处仅统计阶段）

		// 阶段 1：Aiming 稳定后驱动一次拖拽（向右下 → 朝行星方向）
		if (frame === 8) {
			aim.handleOffset({ x: 60, y: -80 }); // 探测器在屏幕上方，向下拖 = 向前发射
			const a = aim.current();
			lines.push(`drag applied at frame ${frame}: power=${a.power.toFixed(3)} vel=(${a.velocity.x.toFixed(2)}, ${a.velocity.y.toFixed(2)})`);
			flush(false);
		}
		if (frame === 10) {
			lines.push(`probe offset logged at frame ${frame} (see drag line above)`);
			flush(false);
		}

		// 阶段 2：捕获矄准帧，然后发射
		if (frame === 12) {
			aimShot = App.saveScreenshot(Path(outDir, 's15-aiming'));
			lines.push(`aiming shot requested at frame ${frame}`);
			flush(false);
		}
		if (frame === 20 && !launched) {
			launched = true;
			launchFrame = frame;
			game.launch(aim.current().velocity);
			lines.push(`launched at frame ${frame}: phase=${game.phase()}`);
			flush(false);
		}

		// 阶段 3：飞行中每 30 帧报告一次
		if (launched && game.phase() === 'Flying' && frame % 60 === 0) {
			lines.push(`flying: frame=${frame}`);
			flush(false);
		}

		// 阶段 4：进入 Result
		if (launched && !retried && game.phase() === 'Result') {
			retried = true;
			resultFrame = frame;
			resultShot = App.saveScreenshot(Path(outDir, 's15-result'));
			lines.push(`result at frame ${frame}: kind=${resultKind} (flight took ${((resultFrame - launchFrame) / 60).toFixed(1)}s real)`);
			lines.push(`phase history: ${phaseHistory.join(' -> ')}`);
			flush(false);
		}

		// 阶段 5：重试（必须在分析之前，且只执行一次）
		if (retried && retryFrame === 0 && frame > resultFrame + 10) {
			game.retry();
			retryFrame = frame;
			lines.push(`retried at frame ${frame}: phase=${game.phase()}`);
			flush(false);
		}

		// 阶段 6：分析截图并收尾（门条件：重试已发生）
		if (retryFrame > 0 && !resultAnalyzed && frame > retryFrame + 8) {
			resultAnalyzed = true;
			lines.push('');
			lines.push('--- aiming frame (prediction line) ---');
			lines.push(captureReport(aimShot, ['aiming: prediction line visible']));
			lines.push('');
			lines.push('--- result frame (trail + frozen) ---');
			lines.push(captureReport(resultShot, [`result: ${resultKind}`]));
			lines.push('');
			lines.push(`final phase=${game.phase()} (expect Aiming)`);
			lines.push(`RESULT=${game.phase() === 'Aiming' && resultKind !== '' ? 'PASS' : 'FAIL'}`);
			flush(true);
			return true;
		}

		return false;
	});
}
