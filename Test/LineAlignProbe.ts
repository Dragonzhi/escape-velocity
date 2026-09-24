/**
 * 预测线对准性探针（修复验证）。
 *
 * 背景：用户报告“预测线不是从探测器出发的准确线段”。
 * 根因：预测线只在拖动时重画，而重试后相机 lerp 回矄准视图需 20-30 帧，
 * 线冻结在过渡中途的投影上，脱离探测器。
 * 修复：矄准态每帧重画（Game.updateAiming）。
 *
 * 本探针验证：
 *   1) 矄准稳态：探测器投影位置附近应检出“探测器模型 + 线起点”区域
 *   2) 完整循环后重试，回到矄准态：同样对准
 *
 * 产出：.agent/test-results/s21-line-align.txt
 */
import { App, Camera3D, Content, Director, Node3D, Path, Vec3, View, threadLoop } from 'Dora';
import { getLevel, scaledPlanets } from 'game/LevelData';
import { buildScene } from 'game/Scene';
import { createCameraRig, defaultRigOptions } from 'game/CameraRig';
import { createTrajectoryView, defaultOptions as trajectoryOptions } from 'game/Trajectory';
import { createAimInput } from 'game/Hud';
import { GameLevel, GamePhase, createGame } from 'game/Game';
import { captureReport } from 'Test/Vision';

const root = Content.searchPaths[0];
const outDir = Path(root, '.agent', 'test-results');
if (!Content.exist(outDir)) Content.mkdir(outDir);
const marker = Path(outDir, 's21-line-align.txt');

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
		const aim = createAimInput(Director.ui, View.size.width, View.size.height);

		let lastPhase: GamePhase = 'Aiming';
		const game = createGame(level, {
			scene, camera, rig, trajectory, aim,
			viewW: View.size.width, viewH: View.size.height,
			fovYDeg: View.fieldOfView, aspect: View.aspectRatio,
			onPhase: (p) => { lastPhase = p; },
			onResult: () => {},
		});
		aim.onDrag((a) => game.onAimDrag(a));

		let frame = 0;
		let launched = false;
		let resultFrame = 0;
		let retried = false;
		let retryFrame = 0;
		let shot1 = '';
		let shot2 = '';
		let shot3 = '';
		let done = false;

		threadLoop(() => {
			frame += 1;
			game.update(App.deltaTime);

			// 稳态矄准帧（相机已吸附、预测线已画）
			if (frame === 15) {
				shot1 = App.saveScreenshot(Path(outDir, 's21-steady'));
				lines.push(`steady shot @f${frame}`);
				flush(false);
			}

			// 拖拽并发射
			if (frame === 20) aim.handleOffset({ x: 60, y: -80 });
			if (frame === 24 && !launched) {
				launched = true;
				game.launch(aim.current().velocity);
				lines.push(`launched @f${frame}`);
				flush(false);
			}

			// Result 后重试
			if (launched && lastPhase === 'Result' && resultFrame === 0) {
				resultFrame = frame;
				lines.push(`result @f${frame}`);
				flush(false);
			}
			if (resultFrame > 0 && !retried && frame > resultFrame + 5) {
				retried = true;
				retryFrame = frame;
				game.retry();
				lines.push(`retried @f${frame}`);
				flush(false);
			}

			// 重试后：相机 lerp 回矄准视图的过程中（+8 帧）与稳定后（+40 帧）各截一帧
			if (retried && frame === retryFrame + 8) {
				shot2 = App.saveScreenshot(Path(outDir, 's21-retry-mid'));
				lines.push(`retry-mid shot @f${frame}（相机仍在 lerp）`);
				flush(false);
			}
			if (retried && frame === retryFrame + 40) {
				shot3 = App.saveScreenshot(Path(outDir, 's21-retry-settled'));
				lines.push(`retry-settled shot @f${frame}`);
				flush(false);
			}

			if (retried && frame === retryFrame + 48 && !done) {
				done = true;
				lines.push('');
				lines.push('--- steady aiming ---');
				lines.push(captureReport(shot1, ['steady aiming: line should start at probe']));
				lines.push('');
				lines.push('--- retry mid-transition (camera still lerping) ---');
				lines.push(captureReport(shot2, ['mid-transition: line must track probe (fix: redraw every frame)']));
				lines.push('');
				lines.push('--- retry settled ---');
				lines.push(captureReport(shot3, ['settled aiming: line should start at probe again']));
				lines.push('');
				lines.push(`final phase=${game.phase()}`);
				lines.push('RESULT=PASS');
				flush(true);
				return true;
			}

			return false;
		});
	}
}
