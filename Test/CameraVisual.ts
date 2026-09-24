/**
 * S0.4 视觉确认：验证“物理平面沿世界 Z 纵向展开”在真实渲染中确实可行。
 *
 * 场景：出发点在 +Z（近）、“目标”在 -Z（远），中间一颗行星环。
 * 相机 dist=30 / tilt=45。用 Test/Vision.ts 输出 ASCII 图 + 区域检测，
 * 确认整条纵向路径都在画面内（不被裁切）。
 *
 * 产出：.agent/test-results/s04-camera-visual.txt
 */
import { App, Camera3D, Color3, Content, Director, DirectionalLight3D, Model3D, Path, Vec3, View, threadLoop } from 'Dora';
import { captureReport } from 'Test/Vision';

const root = Content.searchPaths[0];
const outDir = Path(root, '.agent', 'test-results');
if (!Content.exist(outDir)) Content.mkdir(outDir);
const marker = Path(outDir, 's04-camera-visual.txt');
Content.save(marker, 'phase=started');

const view = Director.entry;
view.setEnvironmentIntensity(0.35, 0.35, 1);

// 竖屏构图：dist=30、tilt=45°（见 Config.ts 的 CameraTiltDefault / CameraMinDistance）
const DIST = 30;
const TILT = 45 * Math.PI / 180;
const eye = Vec3(0, Math.sin(TILT) * DIST, Math.cos(TILT) * DIST);
const camera = Camera3D();
camera.lookAt(eye, Vec3(0, 0, 0));
Director.pushCamera(camera);

const light = DirectionalLight3D();
light.color = Color3(0xfff3da);
light.intensity = 3.2;
light.angleX = -48;
light.angleY = 28;
view.addChild(light);

// 纵向轨道（沿世界 Z）：出发点近、目标点远
const startProbe = Model3D('Assets/Model/Probe.gltf');
if (startProbe !== undefined) {
	startProbe.position = Vec3(0, 0, 9);
	startProbe.scale = Vec3(1.6, 1.6, 1.6);
	view.addChild(startProbe);
}
const midPlanet = Model3D('Assets/Model/Sphere.gltf');
if (midPlanet !== undefined) {
	midPlanet.position = Vec3(0, 0, 0);
	midPlanet.scale = Vec3(3, 3, 3);
	view.addChild(midPlanet);
}
const goalPlanet = Model3D('Assets/Model/Sphere.gltf');
if (goalPlanet !== undefined) {
	goalPlanet.position = Vec3(0, 0, -13);
	goalPlanet.scale = Vec3(2.2, 2.2, 2.2);
	view.addChild(goalPlanet);
}

let elapsed = 0;
let requested = false;
let analyzed = false;
let shotPath = '';

threadLoop(() => {
	elapsed += App.deltaTime;
	if (!requested && elapsed > 1.5) {
		requested = true;
		shotPath = App.saveScreenshot(Path(outDir, 's04-shot'));
	}
	if (requested && !analyzed && elapsed > 2.5) {
		analyzed = true;
		const stats = view.stats;
		const sceneLines = [
			`camera: dist=${DIST} tilt=45deg fovY=${View.fieldOfView} view=${View.size.width}x${View.size.height}`,
			`scene: startProbe at z=+9, midPlanet z=0, goalPlanet z=-13 (vertical track along world Z)`,
			`stats: draws=${stats.drawCalls} visible=${stats.visibleVisuals} triangles=${stats.triangles}`,
		];
		const report = captureReport(shotPath, sceneLines);
		Content.save(marker, report + '\n\nphase=done');
	}
	return false;
});
