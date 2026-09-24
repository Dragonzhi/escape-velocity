/**
 * S0 裸测：验证离线生成的 glTF 资产能被 Model3D 加载并渲染。
 *
 * 产出证据到 .agent/test-results/s0-assets.txt：
 *   status=PASS/FAIL + view.stats 的绘制与可见统计。
 * 用法：作为入口运行（不是 init.ts）。
 */
import { App, Camera3D, Color3, Content, Director, DirectionalLight3D, Model3D, Path, Vec3, threadLoop } from 'Dora';

const resultDir = Path(Content.searchPaths[0], '.agent', 'test-results');
if (!Content.exist(resultDir)) Content.mkdir(resultDir);

const view = Director.entry;
view.setEnvironmentIntensity(0.35, 0.35, 1);

const camera = Camera3D();
camera.lookAt(Vec3(0, 3, 7), Vec3(0, 0, 0));
Director.pushCamera(camera);

const light = DirectionalLight3D();
light.color = Color3(0xffffff);
light.intensity = 3;
light.angleX = -50;
light.angleY = 25;
view.addChild(light);

const missing: string[] = [];

const sphere = Model3D('Assets/Model/Sphere.gltf');
if (sphere !== undefined) {
	sphere.position = Vec3(-2.2, 0, 0);
	sphere.scale = Vec3(1, 1, 1);
	view.addChild(sphere);
} else {
	missing.push('Sphere.gltf');
}

const ring = Model3D('Assets/Model/Ring.gltf');
if (ring !== undefined) {
	ring.position = Vec3(0, 0, 0);
	view.addChild(ring);
} else {
	missing.push('Ring.gltf');
}

const probe = Model3D('Assets/Model/Probe.gltf');
if (probe !== undefined) {
	probe.position = Vec3(2.2, 0, 0);
	view.addChild(probe);
} else {
	missing.push('Probe.gltf');
}

let elapsed = 0;
let checked = false;
threadLoop(() => {
	if (probe !== undefined) probe.angleY += App.deltaTime * 60;
	if (sphere !== undefined) sphere.angleY += App.deltaTime * 30;
	elapsed += App.deltaTime;
	if (!checked && elapsed > 1.5) {
		checked = true;
		const stats = view.stats;
		const ok = missing.length === 0 && stats.drawCalls > 0 && stats.visibleVisuals > 0;
		Content.save(
			Path(resultDir, 's0-assets.txt'),
			`status=${ok ? 'PASS' : 'FAIL'} draws=${stats.drawCalls} visible=${stats.visibleVisuals} triangles=${stats.triangles} missing=${missing.join(',')}`,
		);
	}
	return false;
});
