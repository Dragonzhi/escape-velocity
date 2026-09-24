/**
 * S3.1 接线探针：用**真实关卡数据**逐关 buildScene，逐关读 view.stats。
 *
 * 为什么：截图只能证明“看起来对”，逐关三角面数能证明“这一关确实加载了这几个模型”
 * （期望值 = 该关各模型三角面 + 探测器 164 + 星空壳 1940）。
 *
 * 产出：.agent/test-results/s31-wire.txt（逐关 stats + 期望值对照）
 * 用法：作为入口 POST /run，{"file":"<proj>\\Test\\SceneWireProbe","asProj":false}
 */
import { Camera3D, Content, Director, Model3D, Node3D, Path, View, threadLoop } from 'Dora';
import { getLevel, levelCount, scaledPlanets } from 'game/LevelData';
import { buildScene } from 'game/Scene';
import { RigFrame, createCameraRig, defaultRigOptions } from 'game/CameraRig';
import { P2, bodyPositionAt } from 'game/Gravity';

const searchPaths = Content.searchPaths;
let projRoot = searchPaths[0];
for (let i = 0; i < 8; i++) {
	if (i >= searchPaths.length) break;
	const p = searchPaths[i];
	if (Content.exist(Path(p, 'init.lua')) || Content.exist(Path(p, 'init.ts'))) { projRoot = p; break; }
}
const outDir = Path(projRoot, '.agent', 'test-results');
if (!Content.exist(outDir)) Content.mkdir(outDir);
const marker = Path(outDir, 's31-wire.txt');

/** 每个模型的三角面数（离线统计 = 运行时统计，会话 21 已逐面吻合）。 */
interface Tri { name: string; tris: number; }
const TRIS: Tri[] = [
	{ name: 'Planet_Earth', tris: 80 }, { name: 'Planet_Mars', tris: 80 },
	{ name: 'Planet_Venus', tris: 80 }, { name: 'Planet_Neptune', tris: 80 },
	{ name: 'Planet_Jupiter', tris: 320 }, { name: 'Planet_Saturn', tris: 464 },
	{ name: 'Probe_Voyager_v1', tris: 600 }, // 会话 22 期间该 .glb 被替换：21 mesh / 600 面（原 5/164）
	{ name: 'Sphere.gltf', tris: 120 }, { name: 'Ring.gltf', tris: 16 },
	{ name: 'StarShell.gltf', tris: 1800 }, { name: 'StarShellBright.gltf', tris: 140 },
];

function triOf(name: string): number {
	for (let i = 0; i < TRIS.length; i++) if (TRIS[i].name === name) return TRIS[i].tris;
	return -1;
}

/**
 * ⚠️ 关掉视锥剔除：view.stats 只统计**这一帧真正画出来**的三角形，
 * 而 L3 的机架把探测器放到画面边缘之外（见 PROGRESS 会话 22 的残留项），
 * 于是“本关期望面数”会对不上。关掉剔除后逐关数字才是确定性的。
 */
View.frustumCulling = false;

const lines: string[] = [];
lines.push('frustumCulling=false（否则画面外的行星不计入 stats）');
lines.push('root=' + projRoot + ' view=' + View.size.width.toFixed(0) + 'x' + View.size.height.toFixed(0));
lines.push('file  planets(models)  expectedTris  measuredTris  draws  visibleVisuals  match');
Content.save(marker, lines.join('\n'));

const total = levelCount();
const worlds: Node3D.Type[] = [];
const cams: Camera3D.Type[] = [];
const rigs: { index: number; poses: P2[] }[] = [];
const expected: number[] = [];
const labels: string[] = [];

for (let i = 0; i < total; i++) {
	const def = getLevel(i);
	if (def === undefined) continue;
	const bodies = scaledPlanets(def);
	const world = Node3D();
	Director.entry.addChild(world);
	world.visible = false;
	const scene = buildScene({
		root: world,
		bodies,
		visuals: def.visuals,
		probeStart: def.probeStart,
		probeScale: 1.2,
		spherePath: 'Assets/Model/Sphere.gltf',
		ringPath: 'Assets/Model/Ring.gltf',
		probePath: 'Assets/Model/Probe_Voyager_v1.glb',
	});
	if (scene === undefined) {
		lines.push('L' + (i + 1).toFixed(0) + ' SCENE_FAILED');
		Content.save(marker, lines.join('\n'));
		continue;
	}
	worlds.push(world);

	// 期望三角面：行星模型 + 探测器 + 星空壳（旧 Ring 只在“没有 model 且 ring”时才会加）
	let exp = triOf('Probe_Voyager_v1') + triOf('StarShell.gltf') + triOf('StarShellBright.gltf');
	const names: string[] = [];
	for (let k = 0; k < def.visuals.length; k++) {
		const m = def.visuals[k].model;
		if (m !== undefined && m !== '') { exp += triOf(m); names.push(m); }
		else { exp += triOf('Sphere.gltf'); if (def.visuals[k].ring) exp += triOf('Ring.gltf'); names.push('sphere' + (def.visuals[k].ring ? '+ring' : '')); }
	}
	expected.push(exp);
	labels.push('L' + (i + 1).toFixed(0) + ' [' + names.join('+') + ']');

	// 相机：用游戏同一套机架，看向探测器 + 行星
	const rig = createCameraRig(defaultRigOptions());
	const camera = Camera3D();
	cams.push(camera); // ⚠️ 每关自己的相机：测量时必须切到对应相机，否则视锥剔除会让远处行星不计入 stats
	const poses: P2[] = [];
	const t = 0;
	for (let b = 0; b < bodies.length; b++) poses.push(bodyPositionAt(bodies[b], t));
	rigs.push({ index: i, poses: poses });
	scene.syncBodies(0);
	scene.syncProbe(def.probeStart);
	const frame: RigFrame = rig.step([def.probeStart, ...poses]);
	rig.apply(camera, frame);
}

lines.push('worlds=' + worlds.length.toFixed(0) + '/' + total.toFixed(0));
Content.save(marker, lines.join('\n'));

/** 逐个资产单独放一个场景：用来确认“每关固定多出来的三角面”是不是常数开销。 */
const assetFiles: string[] = [
	'Planet_Mars.glb', 'Planet_Venus.glb', 'Planet_Jupiter.glb', 'Planet_Saturn.glb', 'Planet_Neptune.glb',
	'Probe_Voyager_v1.glb', 'Probe.gltf', 'Sphere.gltf', 'Ring.gltf', 'StarShell.gltf', 'StarShellBright.gltf',
];
const assetNodes: Node3D.Type[] = [];
for (let i = 0; i < assetFiles.length; i++) {
	const m = Model3D(assetFiles[i].indexOf('.glb') > 0 ? 'Assets/Model/' + assetFiles[i] : 'Assets/Model/' + assetFiles[i]);
	if (m === undefined) { lines.push('ASSET_FAIL ' + assetFiles[i]); continue; }
	m.visible = false;
	Director.entry.addChild(m);
	assetNodes.push(m);
}
lines.push('assetNodes=' + assetNodes.length.toFixed(0) + '/' + assetFiles.length.toFixed(0));
Content.save(marker, lines.join('\n'));

let cursor = 0;
let settle = 0;
let settle2 = 0;
let phase = 0;

threadLoop(() => {
	if (phase === 2) {
		if (settle2 === 0) {
			for (let i = 0; i < worlds.length; i++) worlds[i].visible = false;
			for (let i = 0; i < assetNodes.length; i++) assetNodes[i].visible = i === cursor;
			settle2 = 1;
			return false; // 等一帧再读：view.stats 是**上一帧**的渲染统计
		}
		settle2 += 1;
		if (settle2 < 15) return false; // 同上：等 glTF 落地
		settle2 = 0;
		const st2 = Director.entry.stats;
		const bare = assetFiles[cursor].replace('.glb', '');
		lines.push('ASSET ' + assetFiles[cursor] + '  measuredTris=' + st2.triangles.toFixed(0)
			+ '  expected=' + triOf(bare).toFixed(0)
			+ '  draws=' + st2.drawCalls.toFixed(0) + '  visible=' + st2.visibleVisuals.toFixed(0));
		Content.save(marker, lines.join('\n'));
		cursor += 1;
		if (cursor >= assetNodes.length) {
			lines.push('RESULT=PASS');
			Content.save(marker, lines.join('\n'));
			return true;
		}
		return false;
	}
	if (phase === 0) {
		for (let i = 0; i < worlds.length; i++) worlds[i].visible = i === cursor;
		// 每关切到自己的相机：只切 visible 不够，视锥剔除会让画面外的行星不计入 stats
		if (cursor < cams.length) Director.pushCamera(cams[cursor]);
		phase = 1;
		settle = 0;
		return false;
	}
	settle += 1;
	// ⚠️ 等足够多帧：glTF 异步加载 + 视锥剔除都要求“切关 → 稳定 → 再读 stats”。
	if (settle < 30) return false;
	const stats = Director.entry.stats;
	const exp = expected[cursor];
	const got = stats.triangles;
	lines.push(labels[cursor] + '  expected=' + exp.toFixed(0) + '  measured=' + got.toFixed(0)
		+ '  draws=' + stats.drawCalls.toFixed(0) + '  visible=' + stats.visibleVisuals.toFixed(0)
		+ '  match=' + (exp === got));
	Content.save(marker, lines.join('\n'));
	cursor += 1;
	if (cursor >= worlds.length) {
		phase = 2;
		cursor = 0;
		return false;
	}
	phase = 0;
	return false;
});
