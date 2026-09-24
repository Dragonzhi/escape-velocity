/**
 * S3.1 资产冒烟：验证 Blender 导出的 11 个 .glb 能被 Model3D 加载、逐实例染色并渲染。
 *
 * 为什么要探针而不是"看文件在不在"：.glb 是二进制容器，能不能被引擎吃下只有运行时知道；
 * 统计口径用 view.stats（drawCalls / visibleVisuals / triangles），
 * 期望 triangles == 离线统计的 3136（各文件三角面之和），visible == 11。
 *
 * 产出：.agent/test-results/s3-gltf.txt（统计 + 每个模型的材质数）与 s3-gltf.tga（造型截图）。
 * 用法：作为入口运行（不是 init.ts）。
 */
import { App, Camera3D, Color, Color3, Content, Director, DirectionalLight3D, Model3D, Path, Vec3, threadLoop } from 'Dora';

const resultDir = Path(Content.searchPaths[0], '.agent', 'test-results');
if (!Content.exist(resultDir)) Content.mkdir(resultDir);
const marker = Path(resultDir, 's3-gltf.txt');

const view = Director.entry;
view.setEnvironmentIntensity(0.35, 0.35, 1);

const camera = Camera3D();
camera.lookAt(Vec3(0, 9, 19), Vec3(0, 0, 0));
Director.pushCamera(camera);

const light = DirectionalLight3D();
light.color = Color3(0xfff3da);
light.intensity = 3.2;
light.angleX = -50;
light.angleY = 25;
view.addChild(light);

/** 文件名（不含扩展名）、染色、是否自发光。 */
const specs: { name: string; hex: number; glow: boolean }[] = [
	{ name: 'Planet_Earth', hex: 0x4a7fbf, glow: false },
	{ name: 'Planet_Mars', hex: 0xc1553a, glow: false },
	{ name: 'Planet_Venus', hex: 0xd9a05b, glow: false },
	{ name: 'Planet_Neptune', hex: 0x4a6fd9, glow: false },
	{ name: 'Planet_Jupiter', hex: 0xd8b48a, glow: false },
	{ name: 'Planet_Saturn', hex: 0xd9c07a, glow: false },
	{ name: 'Sun', hex: 0xffd24a, glow: true },
	{ name: 'BlackHole', hex: 0x14141c, glow: false },
	{ name: 'Asteroid_01', hex: 0x6b6b6b, glow: false },
	{ name: 'Probe_Voyager', hex: 0xdcdcdc, glow: false },
	{ name: 'Probe_Voyager_v1', hex: 0xdcdcdc, glow: false },
];

const missing: string[] = [];
const detail: string[] = [];
let built = 0;

for (let i = 0; i < specs.length; i++) {
	const spec = specs[i];
	const col = i % 4;
	const row = Math.floor(i / 4);
	const model = Model3D('Assets/Model/' + spec.name + '.glb');
	if (model === undefined) {
		missing.push(spec.name);
		continue;
	}
	model.position = Vec3((col - 1.5) * 3.6, 0, (row - 1) * 3.6);

	// 逐实例染色（与 Scene.ts 同一路径），并数材质个数
	let mats = 0;
	for (let k = 0; k < 12; k++) {
		const mat = model.getMaterial(k);
		if (mat === undefined) break;
		mats += 1;
		const r = Math.floor(spec.hex / 65536) % 256;
		const g = Math.floor(spec.hex / 256) % 256;
		const b = spec.hex % 256;
		mat.baseColor = Color(r, g, b, 255);
		if (spec.glow) mat.emissive = Color3(0xffcc66);
	}
	detail.push(spec.name + ':mats=' + mats.toFixed(0));
	view.addChild(model);
	built += 1;
}

let elapsed = 0;
let dumped = false;
threadLoop(() => {
	elapsed += App.deltaTime;
	if (!dumped && elapsed > 1.5) {
		dumped = true;
		const stats = view.stats;
		const ok = missing.length === 0 && stats.visibleVisuals >= built && built === specs.length;
		Content.save(
			marker,
			'status=' + (ok ? 'PASS' : 'FAIL')
			+ '\nbuilt=' + built.toFixed(0) + '/' + specs.length.toFixed(0)
			+ '\ndraws=' + stats.drawCalls.toFixed(0)
			+ '\nvisible=' + stats.visibleVisuals.toFixed(0)
			+ '\ntriangles=' + stats.triangles.toFixed(0)
			+ '\nmissing=' + missing.join(',')
			+ '\n' + detail.join('\n'),
		);
		App.saveScreenshot(Path(resultDir, 's3-gltf'));
	}
	return false;
});
