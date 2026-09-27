/**
 * 预测线方向诊断：分离「模拟方向」与「渲染方向」。
 *
 * 已观测：默认矄准（速度 (0,-2)，朝火星/屏幕下方）时，线却向上画。
 * 本探针对比两种矄准下的：模拟终点平面坐标 vs 渲染出来的线走向。
 *
 * 产出：.agent/test-results/s21-line-dir.txt
 */
import { App, Camera3D, Content, Director, Node3D, Path, Vec3, View, threadLoop } from 'Dora';
import { getLevel, scaledPlanets } from 'game/LevelData';
import { P2, simulate } from 'game/Gravity';
import { buildScene } from 'game/Scene';
import { createCameraRig, defaultRigOptions } from 'game/CameraRig';
import { createTrajectoryView, defaultOptions as trajectoryOptions } from 'game/Trajectory';
import { createPlanView, defaultPlanOptions } from 'game/PlanView';
import { createAimInput } from 'game/Hud';
import { GameLevel, GamePhase, createGame } from 'game/Game';
import { PredictSteps } from 'game/Config';
import { captureReport } from 'Test/Vision';

const root = Content.searchPaths[0];
const outDir = Path(root, '.agent', 'test-results');
if (!Content.exist(outDir)) Content.mkdir(outDir);
const marker = Path(outDir, 's21-line-dir.txt');

const lines: string[] = [];
function flush(final: boolean): void {
	Content.save(marker, lines.join('\n') + (final ? '\nphase=done' : ''));
}
lines.push('phase=started');
flush(false);

const levelDef = getLevel(0);
if (levelDef === undefined) {
	lines.push('RESULT=FAIL reason=no-level');
	flush(true);
} else {
	const bodies = scaledPlanets(levelDef);
	const level: GameLevel = {
		bodies,
		probeStart: levelDef.probeStart,
		goal: levelDef.goal,
		escapeRadius: levelDef.escapeRadius,
		maxSteps: levelDef.maxSteps,
	};

	/** 打印一条模拟轨迹的首末平面坐标（与渲染无关，纯物理）。 */
	function logSim(tag: string, vel: P2): void {
		const sim = simulate(
			{ pos: { x: level.probeStart.x, y: level.probeStart.y }, vel },
			level.bodies,
			{ steps: PredictSteps, dt: 1 / 120, sampleEvery: 4, escapeRadius: level.escapeRadius },
		);
		const first = sim.points[0];
		const last = sim.points[sim.points.length - 1];
		lines.push(`${tag}: vel=(${vel.x.toFixed(2)}, ${vel.y.toFixed(2)}) start=(${first.x.toFixed(2)}, ${first.y.toFixed(2)}) end=(${last.x.toFixed(2)}, ${last.y.toFixed(2)}) pts=${sim.points.length}`);
	}

	const view = Director.entry;
	view.setEnvironmentIntensity(0.35, 0.35, 1);
	const scene = buildScene({
		root: view as unknown as Node3D.Type,
		bodies,
		visuals: levelDef.visuals,
		probeStart: level.probeStart,
		probeScale: 1.6,
		spherePath: 'Assets/Model/Sphere.gltf',
		ringPath: 'Assets/Model/Ring.gltf',
		probePath: 'Assets/Model/Probe.gltf',
	});

	if (scene === undefined) {
		lines.push('RESULT=FAIL reason=scene');
		flush(true);
	} else {
		const camera = Camera3D();
		Director.pushCamera(camera);
		const rig = createCameraRig(defaultRigOptions());
		const trajectory = createTrajectoryView(Director.ui, trajectoryOptions());
		// S3.15：本探针量的是 3D 预测线的方向，所以建完 Game 就切回 3D
		const plan = createPlanView(Director.ui, View.size.width, View.size.height, defaultPlanOptions());
		const aim = createAimInput(Director.ui, View.size.width, View.size.height);

		let lastPhase: GamePhase = 'Aiming';
		const game = createGame(level, {
			scene, camera, rig, trajectory, plan,
			visuals: [], setWorldVisible: (): void => {},
			aim,
			viewW: View.size.width, viewH: View.size.height,
			fovYDeg: View.fieldOfView, aspect: View.aspectRatio,
			onPhase: (p) => { lastPhase = p; },
			onResult: () => {},
		});
		game.toggleViewMode(); // 回 3D（本探针量 3D 预测线）
		aim.onDrag((a) => game.onAimDrag(a));

		let frame = 0;
		let shotDefault = '';
		let shotDown = '';

		threadLoop(() => {
			frame += 1;
			game.update(App.deltaTime);

			// 阶段 1：默认矄准（速度 (0,-2)）—— 截图 + 打印模拟方向
			if (frame === 15) {
				logSim('default-aim', { x: 0, y: -2 });
				shotDefault = App.saveScreenshot(Path(outDir, 's21-dir-default'));
				lines.push(`default shot @f${frame}`);
				flush(false);
			}

			// 阶段 2：向下大幅拖拽（大速度朝火星）—— 截图 + 打印模拟方向
			if (frame === 20) {
				aim.handleOffset({ x: 0, y: 300 }); // 探测器在上方，向下拖 = 朝火星
				const a = aim.current();
				logSim('drag-down', a.velocity);
			}
			if (frame === 26) {
				shotDown = App.saveScreenshot(Path(outDir, 's21-dir-down'));
				lines.push(`drag-down shot @f${frame}`);
				flush(false);
			}

			if (frame === 34) {
				lines.push('');
				lines.push('--- default aim (vel (0,-2), toward Mars at bottom) ---');
				lines.push(captureReport(shotDefault, ['line should go DOWN from probe toward Mars']));
				lines.push('');
				lines.push('--- drag down (big forward velocity) ---');
				lines.push(captureReport(shotDown, ['line should go DOWN fast']));
				lines.push('');
				lines.push('RESULT=DONE');
				flush(true);
				return true;
			}

			return false;
		});
	}
}
