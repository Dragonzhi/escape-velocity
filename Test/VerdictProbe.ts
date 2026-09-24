/**
 * 最终裁决探针：用颜色标记 + 注视点标记球，确定渲染与投影的关系。
 *
 * - 探测器染纯绿，火星染纯红 → 截图后用 rgbAt 读两个亮斑的颜色，身份无疑
 * - 在相机注视点 (target) 放一个白色标记球 → 它必然渲染在主点上，
 *   直接测出引擎渲染的主点位置（我的投影认为主点 = 窗口中心 615）
 *
 * 产出：.agent/test-results/s21-verdict.txt
 */
import { App, Camera3D, Color, Content, Director, Node3D, Path, Vec2, Vec3, View, threadLoop } from 'Dora';
import { getLevel, scaledPlanets } from 'game/LevelData';
import { buildScene } from 'game/Scene';
import { createCameraRig, defaultRigOptions } from 'game/CameraRig';
import { CameraView, FLIP_Y, HANDEDNESS, prepareCamera, projectPrepared } from 'game/Projection';
import { Model3D } from 'Dora';
import { luminanceAt, parseTga, rgbAt } from 'Test/Vision';
import { Content as C } from 'Dora';

const root = Content.searchPaths[0];
const outDir = Path(root, '.agent', 'test-results');
if (!Content.exist(outDir)) Content.mkdir(outDir);
const marker = Path(outDir, 's21-verdict.txt');

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
	const probeStart = levelDef.probeStart;
	const marsDef = levelDef.planets[0];

	const view = Director.entry;
	view.setEnvironmentIntensity(0.5, 0.5, 1);
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
		// 颜色标记：探测器纯绿、火星纯红（GameScene 暴露的是 Node3D 类型，实际是 Model3D）
		const pm = (scene.probe as unknown as Model3D.Type).getMaterial(0);
		if (pm !== undefined) pm.baseColor = Color(0, 255, 0, 255);
		const mm = (scene.planets[0].body as unknown as Model3D.Type).getMaterial(0);
		if (mm !== undefined) mm.baseColor = Color(255, 0, 0, 255);

		const camera = Camera3D();
		Director.pushCamera(camera);
		const rig = createCameraRig(defaultRigOptions());

		scene.syncProbe(probeStart);
		scene.syncBodies(0);

		// 注视点标记球：放在 rig 的 target（世界坐标）处
		const pts = [probeStart, { x: marsDef.orbitCenter.x, y: marsDef.orbitCenter.y }];
		const rigFrame = rig.step(pts);
		rig.apply(camera, rigFrame);
		const targetW = rigFrame.target;

		const markerSphere = Model3D('Assets/Model/Sphere.gltf');
		if (markerSphere !== undefined) {
			markerSphere.position = Vec3(targetW.x, targetW.y, targetW.z);
			markerSphere.scale = Vec3(0.8, 0.8, 0.8);
			const mm2 = markerSphere.getMaterial(0);
			if (mm2 !== undefined) mm2.baseColor = Color(255, 255, 255, 255);
			view.addChild(markerSphere);
		}

		let frame = 0;
		let shot = '';

		threadLoop(() => {
			frame += 1;

			if (frame === 12) {
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

				const pp = projectPrepared({ x: 0, y: 0, z: 16 }, basis);
				const pmars = projectPrepared({ x: 0, y: 0, z: -30 }, basis);
				const pt = projectPrepared({ x: targetW.x, y: targetW.y, z: targetW.z }, basis);
				if (pp !== undefined) lines.push(`my projection: probe(green) -> pixel (${(View.size.width / 2 + pp.x).toFixed(0)}, ${(View.size.height / 2 + pp.y).toFixed(0)})`);
				if (pmars !== undefined) lines.push(`my projection: mars(red)   -> pixel (${(View.size.width / 2 + pmars.x).toFixed(0)}, ${(View.size.height / 2 + pmars.y).toFixed(0)})`);
				if (pt !== undefined) lines.push(`my projection: target(marker) -> pixel (${(View.size.width / 2 + pt.x).toFixed(0)}, ${(View.size.height / 2 + pt.y).toFixed(0)})  <- 应为主点`);

				shot = App.saveScreenshot(Path(outDir, 's21-verdict'));
				lines.push(`shot @f${frame}`);
				flush(false);
			}

			if (frame === 24) {
				// 读截图：找绿/红/白斑的位置
				const data = Content.load(shot);
				const img = parseTga(data);
				if (img !== undefined) {
					let green = '';
					let red = '';
					let white = '';
					let gN = 0;
					let rN = 0;
					let wN = 0;
					let gx = 0;
					let gy = 0;
					let rx = 0;
					let ry = 0;
					let wx = 0;
					let wy = 0;
					for (let y = 0; y < img.height; y += 4) {
						for (let x = 0; x < img.width; x += 4) {
							const rgb = rgbAt(img, x, y);
							const r = rgb[0];
							const g = rgb[1];
							const b = rgb[2];
							if (g > 150 && r < 100 && b < 100) { gx += x; gy += y; gN += 1; }
							else if (r > 150 && g < 100 && b < 100) { rx += x; ry += y; rN += 1; }
							else if (r > 200 && g > 200 && b > 200) { wx += x; wy += y; wN += 1; }
						}
					}
					if (gN > 0) green = `probe(GREEN) rendered at (${(gx / gN).toFixed(0)}, ${(gy / gN).toFixed(0)}) samples=${gN}`;
					if (rN > 0) red = `mars(RED) rendered at (${(rx / rN).toFixed(0)}, ${(ry / rN).toFixed(0)}) samples=${rN}`;
					if (wN > 0) white = `target-marker(WHITE) rendered at (${(wx / wN).toFixed(0)}, ${(wy / wN).toFixed(0)}) samples=${wN}  <- 主点真值`;
					lines.push(green === '' ? 'probe(GREEN): NOT FOUND' : green);
					lines.push(red === '' ? 'mars(RED): NOT FOUND' : red);
					lines.push(white === '' ? 'target-marker(WHITE): NOT FOUND' : white);
				}
				lines.push('');
				lines.push('RESULT=DONE');
				flush(true);
				return true;
			}

			return false;
		});
	}
}
