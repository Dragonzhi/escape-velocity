// @preview-file on clear
/**
 * 《单程》Escape Velocity · 入口
 *
 * 当前阶段（S0 裸测）：在 3D 场景中放置球体 / 土星环 / 探测器，验证：
 *   1) 自产 glTF 能被 Model3D 加载渲染（R2）
 *   2) 同样的场景在 Web 导出后依然有 3D（R1）
 *
 * 尚无玩法逻辑；核心循环见开发手册 §4.3 与 .agent/plan/PLAN.md 的 S1。
 */
import { App, Camera3D, Color3, DirectionalLight3D, Director, Model3D, Vec3, View, threadLoop } from 'Dora';

const view = Director.entry;

// 环境光：让纯色 flat 材质的背面也有一点亮度，避免死黑。
view.setEnvironmentIntensity(0.35, 0.35, 1);

// 相机：斜俯视，保证"从行星后方掠过"这类方向在屏幕上可读。
const camera = Camera3D();
camera.lookAt(Vec3(0, 4.5, 11), Vec3(0, 0, 0));
Director.pushCamera(camera);

// 唯一的方向光（愿景 §6：一盏方向光，阴影可关）。
const light = DirectionalLight3D();
light.color = Color3(0xfff3da);
light.intensity = 3.2;
light.angleX = -48;
light.angleY = 28;
view.addChild(light);

// 行星：单位球，靠 scale 区分为不同大小。
const planet = Model3D('Assets/Model/Sphere.gltf');
if (planet !== undefined) {
	planet.position = Vec3(-3.2, 0, 0);
	planet.scale = Vec3(2.2, 2.2, 2.2);
	view.addChild(planet);
}

// 土星环：扁平的环带，包在中间那颗行星外侧。
const ring = Model3D('Assets/Model/Ring.gltf');
if (ring !== undefined) {
	ring.position = Vec3(0, 0, 0);
	ring.scale = Vec3(1.6, 1, 1.6);
	view.addChild(ring);
}

const ringedPlanet = Model3D('Assets/Model/Sphere.gltf');
if (ringedPlanet !== undefined) {
	ringedPlanet.position = Vec3(0, 0, 0);
	ringedPlanet.scale = Vec3(1.4, 1.4, 1.4);
	view.addChild(ringedPlanet);
}

// 探测器：正四面体，指向 +X。
const probe = Model3D('Assets/Model/Probe.gltf');
if (probe !== undefined) {
	probe.position = Vec3(3.4, 0, 0);
	probe.scale = Vec3(1.1, 1.1, 1.1);
	view.addChild(probe);
}

// 缓慢自转，确认场景在动、不是卡住的静帧。
let elapsed = 0;
let reported = false;
threadLoop(() => {
	const dt = App.deltaTime;
	if (planet !== undefined) planet.angleY += dt * 18;
	if (ringedPlanet !== undefined) ringedPlanet.angleY += dt * 26;
	if (probe !== undefined) probe.angleY += dt * 60;

	elapsed += dt;
	if (!reported && elapsed > 2) {
		reported = true;
		const stats = view.stats;
		print(`[escape-velocity] draws=${stats.drawCalls} visible=${stats.visibleVisuals} triangles=${stats.triangles} view=${View.size.width}x${View.size.height}`);
	}
	return false;
});
