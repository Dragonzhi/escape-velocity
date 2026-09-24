/**
 * S1.2 运行时测试：场景搭建 + 相机动态跟随。
 *
 * 用 Test/Vision.ts 自己验证画面（不用人工看截图）：
 *   1) 场景能渲染出行星与探测器（区域检测）
 *   2) 相机跟随：探测器飞远后，视点随动、距离拉大
 *
 * 产出：.agent/test-results/s12-scene.txt
 */
import { App, Camera3D, Color3, Content, Director, Node3D, Path, Vec3, View, threadLoop } from 'Dora';
import { CameraRig, createCameraRig, defaultRigOptions } from 'game/CameraRig';
import { Body, P2, ProbeState, bodyPositionAt, simulate } from 'game/Gravity';
import { SceneOptions, GameScene, PlanetVisual, buildScene } from 'game/Scene';
import { captureReport } from 'Test/Vision';

const root = Content.searchPaths[0];
const outDir = Path(root, '.agent', 'test-results');
if (!Content.exist(outDir)) Content.mkdir(outDir);
const marker = Path(outDir, 's12-scene.txt');

const lines: string[] = [];
function flush(final: boolean): void {
	Content.save(marker, lines.join('\n') + (final ? '\nphase=done' : ''));
}
lines.push('phase=started');
flush(false);

// ---- 物理定义：两颗行星（一颗静止、一颗公转）+ 探测器 ----
const bodies: Body[] = [
	{
		gm: 900, radius: 2.2,
		orbitCenter: { x: 0, y: 0 }, orbitRadius: 0,
		orbitPeriod: 0, phase0: 0, orbitDirection: 1,
	},
	{
		gm: 300, radius: 1.4,
		orbitCenter: { x: 0, y: -14 }, orbitRadius: 8,
		orbitPeriod: 10, phase0: 0, orbitDirection: 1,
	},
];

// ---- 视觉描述：同一份球体资产，染不同色 ----
const visuals: PlanetVisual[] = [
	{ r: 0.55, g: 0.62, b: 0.78, displayRadius: 2.2, ring: false },
	{ r: 0.85, g: 0.72, b: 0.50, displayRadius: 1.4, ring: true },
];

const probeStart: P2 = { x: 0, y: 14 };

// ---- 场景 ----
const view = Director.entry;
view.setEnvironmentIntensity(0.35, 0.35, 1);

const sceneOptions: SceneOptions = {
	root: view as unknown as Node3D.Type,
	bodies,
	visuals,
	probeStart,
	probeScale: 1.6,
	spherePath: 'Assets/Model/Sphere.gltf',
	ringPath: 'Assets/Model/Ring.gltf',
	probePath: 'Assets/Model/Probe.gltf',
};

const scene = buildScene(sceneOptions);
if (scene === undefined) {
	lines.push('RESULT=FAIL reason=scene-build-failed');
	flush(true);
} else {
	lines.push('scene built OK');
	flush(false);

	const camera = Camera3D();
	Director.pushCamera(camera);
	lines.push('camera OK');
	flush(false);

	const rig: CameraRig = createCameraRig(defaultRigOptions());
	lines.push('rig OK');
	flush(false);

	// ---- 物理：选一条能飞远的掠过轨迹（已验证 running） ----
	const initial: ProbeState = { pos: probeStart, vel: { x: 6, y: -12 } };
	const sim = simulate(initial, bodies, {
		steps: 1500, dt: 1 / 120, sampleEvery: 5, escapeRadius: 400,
	});
	lines.push(`sim: outcome=${sim.outcome} points=${sim.points.length} stepsRun=${sim.stepsRun}`);

	// 目标：远处的行星轨道区域
	const goal: P2 = { x: 0, y: -30 };
	const planet0Pos: P2 = bodyPositionAt(bodies[0], 0);
	const planet1Pos: P2 = bodyPositionAt(bodies[1], 0);
	lines.push(`goal = (${goal.x.toFixed(2)}, ${goal.y.toFixed(2)})`);
	flush(false);
	lines.push('entering threadLoop');
	flush(false);

	// ---- 逐帧推进：应用物理 + 同步场景 + 更新相机 ----
	const opts = defaultRigOptions();
	let frame = 0;
	let requested = false;
	let analyzed = false;
	let lateShot = '';
	let firstEye = Vec3(0, 0, 0);
	let lastEye = Vec3(0, 0, 0);
	let firstTarget = Vec3(0, 0, 0);
	let lastTarget = Vec3(0, 0, 0);
	let initialShot = '';
	let minRigDistance = 1e9;
	let maxRigDistance = 0;

	threadLoop(() => {
		// 每帧推进若干物理步（看到动画依次展开）
		frame += 1;
		if (frame === 1) {
			lines.push('frame 1 entered');
			flush(false);
		}
		const idx = frame * 4;
		const pos: P2 = idx < sim.points.length ? sim.points[idx] : sim.points[sim.points.length - 1];

		try {
			scene.syncProbe(pos);
			scene.syncBodies(0);

			const rigFrame = rig.step([pos, goal, planet0Pos, planet1Pos]);
			rig.apply(camera, rigFrame);

			if (frame === 1) {
				firstEye = rigFrame.eye;
				firstTarget = rigFrame.target;
			}
			lastEye = rigFrame.eye;
			lastTarget = rigFrame.target;

			// 记录整段轨迹中机架距离的极值（验证“相机确实会拉远”）
			const rdx = rigFrame.eye.x - rigFrame.target.x;
			const rdy = rigFrame.eye.y - rigFrame.target.y;
			const rdz = rigFrame.eye.z - rigFrame.target.z;
			const rigDist = Math.sqrt(rdx * rdx + rdy * rdy + rdz * rdz);
			if (rigDist < minRigDistance) minRigDistance = rigDist;
			if (rigDist > maxRigDistance) maxRigDistance = rigDist;
		} catch (e) {
			if (frame < 3) {
				lines.push(`EXCEPTION at frame ${frame}: sync/rig failed`);
				flush(false);
			}
		}

		// 阶段 1：早期捕获一帧，用于验证“初始构图”
		if (!requested && frame > 3) {
			requested = true;
			initialShot = App.saveScreenshot(Path(outDir, 's12-initial'));
			lines.push(`initial shot requested at frame=${frame}`);
			flush(false);
		}

		// 阶段 2：飞行后期再请求一帧（异步落盘，需隔几帧再读）
		if (frame === 76) {
			lateShot = App.saveScreenshot(Path(outDir, 's12-late'));
			lines.push(`late shot requested at frame=${frame}`);
			flush(false);
		}

		// 阶段 3：隔几帧后读取并分析
		if (requested && !analyzed && frame > 84) {
			analyzed = true;
			const stats = view.stats;
			lines.push(`stats: draws=${stats.drawCalls} visible=${stats.visibleVisuals} triangles=${stats.triangles}`);
			lines.push(`rig distance range over flight: min=${minRigDistance.toFixed(2)} max=${maxRigDistance.toFixed(2)}`);
			lines.push(`camera pulled back=${maxRigDistance > minRigDistance + 1}`);
			lines.push('');
			lines.push('--- initial frame analysis (aiming view) ---');
			lines.push(captureReport(initialShot, ['initial frame (aiming view)']));
			lines.push('');
			lines.push('--- late frame analysis (after flight) ---');
			lines.push(captureReport(lateShot, [`late frame (frame ${frame}, probe at far end)`]));
			flush(true);
			return true;
		}

		// threadLoop 语义：返回 true 停止，返回 false 继续（易搞反！）
		return false;
	});
}
