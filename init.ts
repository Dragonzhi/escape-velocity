// @preview-file on clear
/**
 * 《单程》Escape Velocity · 游戏入口（S2.1）。
 *
 * 组装：场景 + 相机机架 + 轨迹层 + 矄准输入 + 状态机，单一主循环。
 * 关卡数据来自 game/LevelData（当前玩第一关；S2.3 接入关卡选择）。
 *
 * 阶段流转：Aiming（拖动矄准）→ 松手发射 → Flying（飞行观赏）→ Result（点按重试）。
 */
import { App, Camera3D, Director, Label, Node, Node3D, Size, Vec2, View, threadLoop } from 'Dora';
import { getLevel, scaledPlanets } from 'game/LevelData';
import { buildScene } from 'game/Scene';
import { createCameraRig, defaultRigOptions } from 'game/CameraRig';
import { createTrajectoryView, defaultOptions as trajectoryOptions } from 'game/Trajectory';
import { createAimInput } from 'game/Hud';
import { GameLevel, ResultKind, createGame } from 'game/Game';

// ---- 当前关（S2.3 接入关卡选择后由进度决定；暂玩第一关）----
const levelDef = getLevel(0);

if (levelDef === undefined) {
	print('[escape-velocity] FATAL: no level data');
} else {
	const bodies = scaledPlanets(levelDef);
	const visuals = levelDef.visuals;

	const level: GameLevel = {
		bodies,
		probeStart: levelDef.probeStart,
		goal: levelDef.goal,
		escapeRadius: levelDef.escapeRadius,
		maxSteps: levelDef.maxSteps,
	};

// ---- 场景 ----
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
	print('[escape-velocity] FATAL: scene build failed (model load error?)');
} else {
	const camera = Camera3D();
	Director.pushCamera(camera);

	const rig = createCameraRig(defaultRigOptions());
	const trajectory = createTrajectoryView(Director.ui, trajectoryOptions());
	const aim = createAimInput(Director.ui, View.size.width, View.size.height);

	// ---- 结果面板（S1.5 最小版；S2.2 换正式结算 UI）----
	const resultLabel = Label('sarasa-mono-sc-regular', 52);
	let showResult: (r: ResultKind) => void = () => {};
	let showPhase: (hasResult: boolean) => void = () => {};

	if (resultLabel !== undefined) {
		resultLabel.anchor = Vec2(0.5, 0.5);
		resultLabel.position = Vec2(0, View.size.height / 2 - 320);
		resultLabel.visible = false;
		Director.ui.addChild(resultLabel);

		showResult = (r: ResultKind): void => {
			if (r === 'success') resultLabel.text = '逃逸成功';
			else if (r === 'crashed') resultLabel.text = '撞毁';
			else resultLabel.text = '错过';
			resultLabel.visible = true;
		};
		showPhase = (hasResult: boolean): void => {
			if (!hasResult) resultLabel.visible = false;
		};
	}

	// ---- 重试点按层（叠在矄准层之上，仅 Result 态启用）----
	const retryNode = Node();
	retryNode.size = Size(View.size.width, View.size.height);
	retryNode.anchor = Vec2(0.5, 0.5);
	retryNode.position = Vec2(0, 0);
	retryNode.touchEnabled = false;
	Director.ui.addChild(retryNode);

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
		onPhase: (p) => {
			retryNode.touchEnabled = p === 'Result';
			showPhase(p === 'Result');
			print(`[escape-velocity] phase -> ${p}`);
		},
		onResult: (r) => {
			showResult(r);
			print(`[escape-velocity] result = ${r}`);
		},
	});

	aim.onDrag((a) => game.onAimDrag(a));
	aim.onRelease((a) => game.launch(a.velocity));

	retryNode.onTapEnded(() => {
		if (game.phase() === 'Result') {
			game.retry();
		}
	});

	// ---- 单一主循环 ----
	// ⚠️ threadLoop 回调没有参数，帧间隔用 App.deltaTime
	threadLoop(() => {
		game.update(App.deltaTime);
		return false; // false = 继续
	});

	print(`[escape-velocity] game started: L${levelDef.id} ${levelDef.title}`);
	}
}
