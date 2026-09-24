/**
 * 投影对照诊断：我的 projectPrepared vs 引擎真值。
 *
 * 已观测：预测线起点（世界 (0,0,16) 的投影）与 3D 探测器模型的
 * 实际渲染位置差约 200px（竖直方向）。
 * 本探针：同一相机下，打印两个已知世界点的我的投影结果（像素），
 * 截图检出两个模型的实际位置，并用 View3D.pick 验证。
 *
 * 产出：.agent/test-results/s21-proj-check.txt
 */
import { App, Camera3D, Content, Director, Node3D, Path, Vec2, Vec3, View, threadLoop } from 'Dora';
import { getLevel, scaledPlanets } from 'game/LevelData';
import { buildScene } from 'game/Scene';
import { createCameraRig, defaultRigOptions } from 'game/CameraRig';
import { CameraView, FLIP_Y, HANDEDNESS, prepareCamera, projectPrepared } from 'game/Projection';
import { captureReport } from 'Test/Vision';

const root = Content.searchPaths[0];
const outDir = Path(root, '.agent', 'test-results');
if (!Content.exist(outDir)) Content.mkdir(outDir);
const marker = Path(outDir, 's21-proj-check.txt');

const lines: string[] = [];
function flush(final: boolean): void {
	Content.save(marker, lines.join('\n') + (final ? '\nphase=done' : ''));
}
lines.push('phase=started');
flush(false);

const levelDef = getLevel(0);
if (levelDef === undefined) {
	lines.push('RESULT=FAIL');
	flush(true);
} else {
	const bodies = scaledPlanets(levelDef);
	const probeStart = levelDef.probeStart; // (0,16)
	const mars = levelDef.planets[0].orbitCenter; // (0,-30)

	const view = Director.entry;
	view.setEnvironmentIntensity(0.35, 0.35, 1);
	const scene = buildScene({
		root: view as unknown as Node3D.Type,
		bodies,
		visuals: levelDef.visuals,
		probeStart,
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

		scene.syncProbe(probeStart);
		scene.syncBodies(0);

		let frame = 0;
		let shot = '';
		let printed = false;

		threadLoop(() => {
			frame += 1;

			// 与 Game.updateAiming 完全相同的相机流程
			const pts = [probeStart, mars];
			const rigFrame = rig.step(pts);
			rig.apply(camera, rigFrame);

			if (frame === 12 && !printed) {
				printed = true;
				const camView: CameraView = {
					eye: { x: rigFrame.eye.x, y: rigFrame.eye.y, z: rigFrame.eye.z },
					target: { x: rigFrame.target.x, y: rigFrame.target.y, z: rigFrame.target.z },
					up: { x: 0, y: 1, z: 0 },
					fovYDeg: View.fieldOfView,
					aspect: View.aspectRatio,
					viewW: View.size.width,
					viewH: View.size.height,
				};
				const basis = prepareCamera(camView, HANDEDNESS, FLIP_Y);

				lines.push(`camera: eye=(${rigFrame.eye.x.toFixed(2)}, ${rigFrame.eye.y.toFixed(2)}, ${rigFrame.eye.z.toFixed(2)}) target=(${rigFrame.target.x.toFixed(2)}, ${rigFrame.target.y.toFixed(2)}, ${rigFrame.target.z.toFixed(2)})`);
				lines.push(`basis: fwd=(${basis.forward.x.toFixed(4)}, ${basis.forward.y.toFixed(4)}, ${basis.forward.z.toFixed(4)}) up=(${basis.up.x.toFixed(4)}, ${basis.up.y.toFixed(4)}, ${basis.up.z.toFixed(4)}) focal=${basis.focal.toFixed(4)}`);

				// 我的投影（偏移 -> 像素）
				const probeWorld = { x: 0, y: 0, z: 16 };
				const marsWorld = { x: 0, y: 0, z: -30 };
				const pp = projectPrepared(probeWorld, basis);
				const pm = projectPrepared(marsWorld, basis);
				if (pp !== undefined) lines.push(`my projection: probe(0,0,16) -> pixel (${(View.size.width / 2 + pp.x).toFixed(1)}, ${(View.size.height / 2 + pp.y).toFixed(1)})`);
				if (pm !== undefined) lines.push(`my projection: mars (0,0,-30) -> pixel (${(View.size.width / 2 + pm.x).toFixed(1)}, ${(View.size.height / 2 + pm.y).toFixed(1)})`);

				// 引擎真值 1：pick 我的投影像素处，看是否有模型
				if (pp !== undefined) {
					const vpX = View.size.width / 2 + pp.x;
					const vpY = View.size.height / 2 + pp.y;
					const hit = view.pick(Vec2(vpX, vpY));
					lines.push(`engine pick at my-probe-pixel (${vpX.toFixed(0)}, ${vpY.toFixed(0)}): ${hit !== undefined ? 'HIT a model' : 'no model'}`);
				}

				// 引擎真值 2：getRayDirection 直接测引擎相机的朝向（R4 标定用过的真值源）
				const centerRay = view.getRayDirection(Vec2(View.size.width / 2, View.size.height / 2));
				lines.push(`engine ray @center: (${centerRay.x.toFixed(4)}, ${centerRay.y.toFixed(4)}, ${centerRay.z.toFixed(4)})`);
				lines.push(`my forward:        (${basis.forward.x.toFixed(4)}, ${basis.forward.y.toFixed(4)}, ${basis.forward.z.toFixed(4)})`);

				const topRay = view.getRayDirection(Vec2(View.size.width / 2, 100));
				lines.push(`engine ray @(1012,100): (${topRay.x.toFixed(4)}, ${topRay.y.toFixed(4)}, ${topRay.z.toFixed(4)})`);
				// 我的基在像素 (1012,100) 处的射线：offset=(0, -515)
				const myTop = {
					x: basis.forward.x + (0) * basis.right.x + (-515 / (View.size.height / 2) / basis.focal) * basis.up.x,
					y: basis.forward.y + (0) * basis.right.y + (-515 / (View.size.height / 2) / basis.focal) * basis.up.y,
					z: basis.forward.z + (0) * basis.right.z + (-515 / (View.size.height / 2) / basis.focal) * basis.up.z,
				};
				const myTopLen = Math.sqrt(myTop.x * myTop.x + myTop.y * myTop.y + myTop.z * myTop.z);
				lines.push(`my ray @(1012,100):     (${(myTop.x / myTopLen).toFixed(4)}, ${(myTop.y / myTopLen).toFixed(4)}, ${(myTop.z / myTopLen).toFixed(4)})`);

				shot = App.saveScreenshot(Path(outDir, 's21-proj'));
				lines.push(`shot @f${frame}`);
				flush(false);
			}

			if (frame === 22) {
				lines.push('');
				lines.push('--- rendered positions (ground truth) ---');
				lines.push(captureReport(shot, ['probe tetra + mars sphere; compare with my projection above']));
				lines.push('');
				lines.push('RESULT=DONE');
				flush(true);
				return true;
			}

			return false;
		});
	}
}
