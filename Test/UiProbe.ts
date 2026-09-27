/**
 * S2.2 / S2.3 运行时探针：结算三态面板 + 关卡选择。
 *
 * 骨架照 `Test/LineAlignProbe.ts`：真场景 + 真状态机 + 真 UI，逐帧驱动，
 * 每张截图用 `Test/Vision.captureReport` 转成文本报告（ASCII 灰阶 + 连通域 +
 * 亮度统计）—— Agent 看不到图，只能靠它自检“东西确实画出来了、画在哪”。
 *
 * 三条自动判定（写进标记文件，必要时可人工复核截图）：
 *   1. 4 张必需截图都存在且能被 TGA 解析（不是 "VISION FAILED"）；
 *   2. 面板截图的区域检测不为 NONE（说明文字真的渲染了，不是空面板）；
 *   3. 面板/关卡选择截图的平均亮度 < 同机位“无面板”基线（说明面板盖在场景上，
 *      即 UI 层的绘制顺序确实高于轨迹层）。
 *
 * 产出：`.agent/test-results/s22-ui.txt` + 5 张 `.tga`
 * （`s22-result-success` / `s22-result-missed` / `s22-result-crashed` /
 *   `s22-levelselect` 为任务要求的四张，`s22-nopanel` 是判定 3 的对照帧）。
 */
import { App, Camera3D, Content, Director, Node, Node3D, Path, Size, Vec2, View, threadLoop } from 'Dora';
import { LevelSelect, ResultPanel, createAimInput, createLevelSelect, createResultPanel } from 'game/Hud';
import { GameLevel, createGame } from 'game/Game';
import { getLevel, scaledPlanets } from 'game/LevelData';
import { buildScene } from 'game/Scene';
import { createCameraRig, defaultRigOptions } from 'game/CameraRig';
import { createTrajectoryView, defaultOptions as trajectoryOptions } from 'game/Trajectory';
import { createPlanView, defaultPlanOptions } from 'game/PlanView';
import { captureReport } from 'Test/Vision';

const root = Content.searchPaths[0];
const outDir = Path(root, '.agent', 'test-results');
if (!Content.exist(outDir)) Content.mkdir(outDir);
const marker = Path(outDir, 's22-ui.txt');

const lines: string[] = [];
function flush(final: boolean): void {
	Content.save(marker, lines.join('\n') + (final ? '\nphase=done' : ''));
}
lines.push('phase=started');
flush(false);

/** 从 captureReport 的文本里取平均亮度（报告里是 `samples=N mean=X min=.. max=..`）。 */
function reportMean(report: string): number {
	for (const rawLine of report.split('\n')) {
		const line = rawLine.trim();
		if (line.indexOf('mean=') < 0) continue;
		for (const token of line.split(' ')) {
			if (token.startsWith('mean=')) return Number.parseFloat(token.substring(5));
		}
	}
	return -1;
}

/** 报告里是否检出了区域（Vision 在没有任何亮块时会写 NONE）。 */
function reportHasRegions(report: string): boolean {
	return report.indexOf('== regions') >= 0 && report.indexOf('NONE') < 0;
}

const levelTotal = 6;
const levelDef = getLevel(0);

if (levelDef === undefined) {
	lines.push('RESULT=FAIL reason=no-level-data');
	flush(true);
} else {
	const viewW = View.size.width;
	const viewH = View.size.height;
	lines.push('view=' + viewW.toFixed(0) + 'x' + viewH.toFixed(0));

	const bodies = scaledPlanets(levelDef);
	const level: GameLevel = {
		bodies,
		probeStart: levelDef.probeStart,
		goal: levelDef.goal,
		escapeRadius: levelDef.escapeRadius,
		maxSteps: levelDef.maxSteps,
	};

	Director.entry.setEnvironmentIntensity(0.35, 0.35, 1);

	// 与 init.ts 同样的层级：关卡 2D 层先建，UI 叠层后建（后建的画在上面）
	const levelLayer = Node();
	levelLayer.size = Size(viewW, viewH);
	levelLayer.anchor = Vec2(0.5, 0.5);
	levelLayer.position = Vec2(0, 0);
	Director.ui.addChild(levelLayer);

	const uiLayer = Node();
	uiLayer.size = Size(viewW, viewH);
	uiLayer.anchor = Vec2(0.5, 0.5);
	uiLayer.position = Vec2(0, 0);
	Director.ui.addChild(uiLayer);

	const world = Node3D();
	Director.entry.addChild(world);

	const scene = buildScene({
		root: world,
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
		const trajectory = createTrajectoryView(levelLayer, trajectoryOptions());
		// S3.15：本探针量的是 3D 轨迹/面板，所以建完 Game 立刻切回 3D
		const plan = createPlanView(levelLayer, viewW, viewH, defaultPlanOptions());
		const aim = createAimInput(levelLayer, viewW, viewH);

		const game = createGame(level, {
			scene,
			camera,
			rig,
			trajectory,
			plan,
			visuals: [],
			setWorldVisible: (): void => {},
			aim,
			viewW,
			viewH,
			fovYDeg: View.fieldOfView,
			aspect: View.aspectRatio,
			onPhase: (): void => {},
			onResult: (): void => {},
		});
		game.toggleViewMode(); // 回 3D
		aim.onDrag((a) => game.onAimDrag(a));

		/**
		 * 关卡切换检查（S2.3 的真正风险点）。
		 *
		 * init.ts 的 ensureLevel 要按同样的调用序列再建一关：Node3D 容器 → buildScene
		 * → 相机 → 轨迹/矄准 → createGame，然后切 visible + pushCamera + startLevel。
		 * 这些调用**只有真跑一遍才知道会不会 nil**，所以探针照抄这条路径
		 * （探针不能 import init.ts —— 入口脚本不可被 require）。
		 *
		 * @returns 失败原因（空数组 = 全过）
		 */
		const probeLevelSwitch = (): string[] => {
			const problems: string[] = [];
			const def2 = getLevel(1);
			if (def2 === undefined) {
				problems.push('level 2 data missing');
				return problems;
			}

			const bodies2 = scaledPlanets(def2);
			const level2: GameLevel = {
				bodies: bodies2,
				probeStart: def2.probeStart,
				goal: def2.goal,
				escapeRadius: def2.escapeRadius,
				maxSteps: def2.maxSteps,
			};

			// 第二关的 2D 层建在关卡层里（在 UI 叠层之下）
			const layer2 = Node();
			layer2.size = Size(viewW, viewH);
			layer2.anchor = Vec2(0.5, 0.5);
			layer2.position = Vec2(0, 0);
			Director.ui.addChild(layer2);

			const world2 = Node3D();
			Director.entry.addChild(world2);
			world2.visible = false;

			const scene2 = buildScene({
				root: world2,
				bodies: bodies2,
				visuals: def2.visuals,
				probeStart: level2.probeStart,
				probeScale: 1.6,
				spherePath: 'Assets/Model/Sphere.gltf',
				ringPath: 'Assets/Model/Ring.gltf',
				probePath: 'Assets/Model/Probe.gltf',
			});
			if (scene2 === undefined) {
				problems.push('level 2 scene build failed');
				return problems;
			}

			const camera2 = Camera3D();
			const rig2 = createCameraRig(defaultRigOptions());
			const trajectory2 = createTrajectoryView(layer2, trajectoryOptions());
			const plan2 = createPlanView(layer2, viewW, viewH, defaultPlanOptions());
			const aim2 = createAimInput(layer2, viewW, viewH);
			const game2 = createGame(level2, {
				scene: scene2,
				camera: camera2,
				rig: rig2,
				trajectory: trajectory2,
				plan: plan2,
				visuals: [],
				setWorldVisible: (): void => {},
				aim: aim2,
				viewW,
				viewH,
				fovYDeg: View.fieldOfView,
				aspect: View.aspectRatio,
				onPhase: (): void => {},
				onResult: (): void => {},
			});

			// 切到第二关（与 init.ts 的 enterLevel 同序）
			world.visible = false;
			aim.setEnabled(false);
			world2.visible = true;
			Director.pushCamera(camera2);
			game2.startLevel();
			game2.update(App.deltaTime);

			if (game2.phase() !== 'Aiming') problems.push('level 2 did not enter Aiming: ' + game2.phase());
			if (world.visible) problems.push('level 1 world still visible after switch');
			if (!world2.visible) problems.push('level 2 world not visible after switch');
			if (game.phase() !== 'Aiming') problems.push('level 1 core phase changed: ' + game.phase());

			// 再切回第一关
			world2.visible = false;
			aim2.setEnabled(false);
			world.visible = true;
			Director.pushCamera(camera);
			game.startLevel();
			game.update(App.deltaTime);
			if (game.phase() !== 'Aiming') problems.push('level 1 did not return to Aiming: ' + game.phase());

			lines.push('level switch L1 -> L2 -> L1 done, game2.phase=' + game2.phase());
			return problems;
		};

		// ---- 关卡切换检查（惰性建第二关 → 切过去 → 切回来）----
		const switchProblems = probeLevelSwitch();
		lines.push('switchProblems=' + switchProblems.length.toFixed(0));
		flush(false);


		// 探针不改存档：进度值只喂给 UI，用来演示“已解锁 3 / 6”
		const unlockedForShot = 2;

		const panel: ResultPanel = createResultPanel(uiLayer, viewW, viewH, {
			onRetry: (): void => {
				lines.push('tap: retry button');
				flush(false);
			},
			onBackToSelect: (): void => {
				lines.push('tap: back-to-select button');
				flush(false);
			},
		});
		const select: LevelSelect = createLevelSelect(uiLayer, viewW, viewH, {
			levels: [
				{ name: 'L1 直飞' },
				{ name: 'L2 第一次弯曲' },
				{ name: 'L3 从背后抄过去' },
				{ name: 'L4 它动了' },
				{ name: 'L5 两连弹' },
				{ name: 'L6 贴着过去' },
			],
			onPick: (index: number): void => {
				lines.push('tap: level button ' + (index + 1).toFixed(0));
				flush(false);
			},
		});

		let frame = 0;
		let shotSuccess = '';
		let shotMissed = '';
		let shotCrashed = '';
		let shotBaseline = '';
		let shotSelect = '';
		let done = false;

		threadLoop(() => {
			frame += 1;
			game.update(App.deltaTime);

			// 先让相机与预测线稳定（与 LineAlignProbe 同一节奏）
			if (frame === 15) {
				panel.show('success', 'L1 直飞');
				lines.push('show success @f' + frame.toFixed(0));
				flush(false);
			}
			if (frame === 18) {
				shotSuccess = App.saveScreenshot(Path(outDir, 's22-result-success'));
			}

			if (frame === 26) {
				panel.show('missed', 'L1 直飞');
				lines.push('show missed @f' + frame.toFixed(0));
				flush(false);
			}
			if (frame === 29) {
				shotMissed = App.saveScreenshot(Path(outDir, 's22-result-missed'));
			}

			if (frame === 37) {
				panel.show('crashed', 'L1 直飞');
				lines.push('show crashed @f' + frame.toFixed(0));
				flush(false);
			}
			if (frame === 40) {
				shotCrashed = App.saveScreenshot(Path(outDir, 's22-result-crashed'));
			}

			// 对照帧：同一机位、同样有轨迹线，但没有面板
			if (frame === 48) {
				panel.hide();
				lines.push('panel hidden @f' + frame.toFixed(0));
				flush(false);
			}
			if (frame === 51) {
				shotBaseline = App.saveScreenshot(Path(outDir, 's22-nopanel'));
			}

			if (frame === 59) {
				select.show(unlockedForShot);
				lines.push('level select shown @f' + frame.toFixed(0) + ' unlocked=' + unlockedForShot.toFixed(0));
				flush(false);
			}
			if (frame === 62) {
				shotSelect = App.saveScreenshot(Path(outDir, 's22-levelselect'));
			}

			// ⚠️ saveScreenshot 是异步落盘：最后一次请求后必须再隔几帧才读
			if (frame === 72 && !done) {
				done = true;
				lines.push('');
				lines.push('--- result panel: success ---');
				const rSuccess = captureReport(shotSuccess, ['s22 result panel: success']);
				lines.push(rSuccess);
				lines.push('');
				lines.push('--- result panel: missed ---');
				const rMissed = captureReport(shotMissed, ['s22 result panel: missed']);
				lines.push(rMissed);
				lines.push('');
				lines.push('--- result panel: crashed ---');
				const rCrashed = captureReport(shotCrashed, ['s22 result panel: crashed']);
				lines.push(rCrashed);
				lines.push('');
				lines.push('--- baseline: no panel (same camera) ---');
				const rBase = captureReport(shotBaseline, ['s22 baseline without panel']);
				lines.push(rBase);
				lines.push('');
				lines.push('--- level select (unlocked=2 -> 3/6) ---');
				const rSelect = captureReport(shotSelect, ['s22 level select, unlocked=2']);
				lines.push(rSelect);

				const meanSuccess = reportMean(rSuccess);
				const meanMissed = reportMean(rMissed);
				const meanCrashed = reportMean(rCrashed);
				const meanBase = reportMean(rBase);
				const meanSelect = reportMean(rSelect);

				lines.push('');
				lines.push('--- checks ---');
				lines.push('shot success=' + shotSuccess);
				lines.push('shot missed=' + shotMissed);
				lines.push('shot crashed=' + shotCrashed);
				lines.push('shot baseline=' + shotBaseline);
				lines.push('shot select=' + shotSelect);
				lines.push('mean success=' + meanSuccess.toFixed(1) + ' missed=' + meanMissed.toFixed(1)
					+ ' crashed=' + meanCrashed.toFixed(1) + ' baseline=' + meanBase.toFixed(1)
					+ ' select=' + meanSelect.toFixed(1));

				const failures: string[] = [];
				for (const p of switchProblems) failures.push('level switch: ' + p);
				if (meanSuccess < 0) failures.push('success shot unreadable');
				if (meanMissed < 0) failures.push('missed shot unreadable');
				if (meanCrashed < 0) failures.push('crashed shot unreadable');
				if (meanBase < 0) failures.push('baseline shot unreadable');
				if (meanSelect < 0) failures.push('level select shot unreadable');
				if (!reportHasRegions(rSuccess)) failures.push('success panel has no rendered region');
				if (!reportHasRegions(rCrashed)) failures.push('crashed panel has no rendered region');
				if (!reportHasRegions(rSelect)) failures.push('level select has no rendered region');
				if (meanBase >= 0 && meanCrashed >= 0 && !(meanCrashed < meanBase)) {
					failures.push('panel is not drawn above the scene (mean ' + meanCrashed.toFixed(1) + ' >= ' + meanBase.toFixed(1) + ')');
				}
				if (meanBase >= 0 && meanSelect >= 0 && !(meanSelect < meanBase)) {
					failures.push('level select is not drawn above the scene (mean ' + meanSelect.toFixed(1) + ' >= ' + meanBase.toFixed(1) + ')');
				}
				lines.push('levels=' + levelTotal.toFixed(0) + ' failures=' + failures.length.toFixed(0));

				if (failures.length === 0) {
					lines.push('RESULT=PASS');
				} else {
					for (const f of failures) lines.push('reason: ' + f);
					lines.push('RESULT=FAIL');
				}
				flush(true);
				return true; // 停止循环 → 由外部 POST /stop 结束入口
			}

			return false;
		});
	}
}
