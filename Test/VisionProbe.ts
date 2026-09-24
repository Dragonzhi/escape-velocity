/**
 * 视觉验证探针：验证 Test/Vision.ts 工具库可用。
 *
 * 场景：球体 / 土星环 / 探测器三个物体水平排开，用 ASCII 图 + 区域检测确认。
 *
 * 产物：
 *   .agent/test-results/vision-report.txt  可读文本报告
 *   .agent/test-results/shot.tga           原始截图（供人工复核）
 */
import { App, Camera3D, Color3, Content, Director, DirectionalLight3D, Model3D, Path, Vec3, threadLoop } from 'Dora';
import { captureReport } from 'Test/Vision';

const root = Content.searchPaths[0];
const outDir = Path(root, '.agent', 'test-results');
if (!Content.exist(outDir)) Content.mkdir(outDir);

const marker = Path(outDir, 'vision-capture.txt');
const reportPath = Path(outDir, 'vision-report.txt');
Content.save(marker, 'phase=started');

// ---------------- 场景 ----------------
const view = Director.entry;
view.setEnvironmentIntensity(0.35, 0.35, 1);

const camera = Camera3D();
camera.lookAt(Vec3(0, 4.5, 11), Vec3(0, 0, 0));
Director.pushCamera(camera);

const light = DirectionalLight3D();
light.color = Color3(0xfff3da);
light.intensity = 3.2;
light.angleX = -48;
light.angleY = 28;
view.addChild(light);

const planet = Model3D('Assets/Model/Sphere.gltf');
if (planet !== undefined) {
	planet.position = Vec3(-6.5, 0, 0);
	planet.scale = Vec3(1.6, 1.6, 1.6);
	view.addChild(planet);
}
const ringedPlanet = Model3D('Assets/Model/Sphere.gltf');
if (ringedPlanet !== undefined) {
	ringedPlanet.position = Vec3(0, 0, 0);
	ringedPlanet.scale = Vec3(1.6, 1.6, 1.6);
	view.addChild(ringedPlanet);
}
const probe = Model3D('Assets/Model/Probe.gltf');
if (probe !== undefined) {
	probe.position = Vec3(6.5, 0, 0);
	probe.scale = Vec3(3.2, 3.2, 3.2);
	view.addChild(probe);
}

// 故意不加土星环：让三个物体在水平方向完全分离，用于检验工具的判定力。

let elapsed = 0;
let requested = false;
let analyzed = false;
let shotPath = '';

threadLoop(() => {
	elapsed += App.deltaTime;

	// 阶段 1：请求截图（saveScreenshot 是异步落盘，不能立即读）
	if (!requested && elapsed > 1.5) {
		requested = true;
		shotPath = App.saveScreenshot(Path(outDir, 'shot'));
		Content.save(marker, 'phase=requested');
	}

	// 阶段 2：等几帧让落盘完成，再解析
	if (requested && !analyzed && elapsed > 2.5) {
		analyzed = true;
		const stats = view.stats;
		const sceneLines = [
			`models: planet=${planet !== undefined} ringed=${ringedPlanet !== undefined} probe=${probe !== undefined}`,
			`expected: 3 horizontally separated objects at x=-6.5 / 0 / +6.5`,
			`stats: draws=${stats.drawCalls} visible=${stats.visibleVisuals} triangles=${stats.triangles}`,
			`shotPath=${shotPath}`,
			`shotBytes=${Content.exist(shotPath) ? Content.getAttr(shotPath) : -1}`,
		];
		const report = captureReport(shotPath, sceneLines);
		Content.save(reportPath, report);
		Content.save(marker, 'phase=done');
	}
	return false;
});
