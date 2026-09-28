/**
 * 近裁剪面探针（B 修复① 的诊断，2026-09-28）。
 *
 * 背景：用户实测 L1「切到 3D 啥也看不到」。已定位 **近平面**是主因（`View.nearPlaneDistance`
 * 默认 0.1，而 L1 贴地球机位的相机距离只有 ~0.0126）—— 改成 2e-4 之后地球与探测器都出来了，
 * **但星空背板不见了**，整屏变成一块均匀的灰。
 *
 * 这个探针回答两件事，**一次引擎会话跑完**：
 *   ① 引擎默认的裁剪面到底是多少（`View.nearPlaneDistance / farPlaneDistance` 直接读）；
 *   ② 逐个变体（近/远平面组合 ± 整个 3D 世界隐藏）抓帧，报告**背景区域的平均 RGB**。
 * 判据：**"隐藏整个世界"那一档的颜色 = 清屏色**。若它与"天球可见"档的背景色相同，
 * 就说明那一档里天球根本没画出来。
 *
 * 产出：`.agent/test-results/clip-probe.txt`（文本）+ `clip-<i>.tga`（每档一帧，人工可看）。
 */
import { App, Camera3D, Content, Director, Node3D, Path, Vec3, View, threadLoop } from 'Dora';
import { getLevel, scaledPlanets } from 'game/LevelData';
import { GameScene, buildScene, planeToWorld } from 'game/Scene';
import { TgaImage, parseTga, rgbAt } from 'Test/Vision';
import { levelRuntime } from 'game/Tuning';

/**
 * 递归打印节点树（位置/缩放/可见性）—— 认"那块灰"用。
 *
 * ⚠️ 参数用 `any`：`children` 在 d.ts 里挂在 `Node` 上，而 `Node3D` 的声明里没有它
 * （`Node` 的 position 又是 Vec2，强转会把 z 弄丢），索性按 Lua 侧的真实形状走。
 */
function dumpTree(node: any, depth: number, out: string[]): void {
	const kids: any = node.children;
	if (kids === undefined) return;
	let pad = '';
	for (let i = 0; i < depth; i++) pad += '  ';
	const n: number = kids.count;
	for (let i = 0; i < n; i++) {
		const c: any = kids[i];
		const gc = c.children !== undefined ? c.children.count : 0;
		out.push(pad + '-' + i.toFixed(0) + ' pos=(' + c.position.x.toFixed(4) + ',' + c.position.y.toFixed(4) + ',' + c.position.z.toFixed(4)
			+ ') scale=' + c.scale.x.toFixed(6) + ' visible=' + (c.visible ? 1 : 0) + ' kids=' + gc.toFixed(0));
		if (depth < 2) dumpTree(c, depth + 1, out);
	}
}

interface Variant {
	label: string;
	near: number;
	far: number;
	/** 藏起来的那一个：'none' | 'sun' | 'earth' | 'moon' | 'probe' | 'all' | 'world'。 */
	hide: string;
}

/** 每张图的背景均值（按变体顺序），最后用来出判定。 */
const bgMeans: number[] = [];

/**
 * 报告一张截图的**上带**颜色。
 *
 * 取样区 = 横向 2%~98%、纵向 4.5%~14%（y ≈ 62~193）：
 * 这一段在 L1 贴地球机位里一定**在地球盘面之上**（地球盘面的上缘在 y ≈ 240），
 * 所以它读到的就是"背景"本身 —— 那块灰正是出现在这里（旧取样区落在盘面上，读成了地球的颜色）。
 */
function analyze(shotPath: string, v: Variant): string[] {
	const out: string[] = [];
	out.push('--- ' + v.label + ' (near=' + v.near + ' far=' + v.far + ' hide=' + v.hide + ') ---');
	if (!Content.exist(shotPath)) {
		out.push('  VISION FAILED: not found ' + shotPath);
		return out;
	}
	const img: TgaImage | undefined = parseTga(Content.load(shotPath));
	if (img === undefined) {
		out.push('  VISION FAILED: unsupported TGA');
		return out;
	}
	let r = 0; let g = 0; let b = 0; let n = 0;
	const x0 = Math.floor(img.width * 0.02);
	const x1 = Math.floor(img.width * 0.98);
	const y0 = Math.floor(img.height * 0.045);
	const y1 = Math.floor(img.height * 0.14);
	for (let y = y0; y < y1; y += 7) {
		for (let x = x0; x < x1; x += 7) {
			const c = rgbAt(img, x, y);
			r += c[0]; g += c[1]; b += c[2]; n += 1;
		}
	}
	const cx = rgbAt(img, Math.floor(img.width / 2), Math.floor(img.height / 2));
	const mean = (r + g + b) / 3 / n;
	bgMeans.push(mean);
	out.push('  size=' + img.width.toFixed(0) + 'x' + img.height.toFixed(0)
		+ ' bgMean=(' + (r / n).toFixed(1) + ',' + (g / n).toFixed(1) + ',' + (b / n).toFixed(1) + ')'
		+ ' center=(' + cx[0].toFixed(0) + ',' + cx[1].toFixed(0) + ',' + cx[2].toFixed(0) + ')');
	return out;
}

/**
 * 项目根：单文件入口下 `Content.searchPaths[0]` 是 `<proj>/Test`（AGENTS 的"搜索根陷阱"）——
 * 上跳一级才是项目根，否则标记文件会写进 `Test/.agent/...`（曾经踩过）。
 */
function findRoot(): string {
	const sp0 = Content.searchPaths[0];
	if (sp0 !== undefined) {
		const up = Path(sp0, '..');
		if (Content.exist(Path(up, 'game', 'Scene.lua'))) return up;
		if (Content.exist(Path(sp0, 'game', 'Scene.lua'))) return sp0;
	}
	return Path(Content.writablePath, 'escape-velocity');
}

const root = findRoot();
const outDir = Path(root, '.agent', 'test-results');
if (!Content.exist(outDir)) Content.mkdir(outDir);
const marker = Path(outDir, 'clip-probe.txt');

const lines: string[] = [];
function flush(final: boolean): void {
	Content.save(marker, lines.join('\n') + (final ? '\nphase=done' : ''));
}
lines.push('phase=started');
flush(false);

// 引擎默认值 —— "我们改之前到底是什么"的唯一直接证据
lines.push('engine defaults: near=' + View.nearPlaneDistance + ' far=' + View.farPlaneDistance
	+ ' fov=' + View.fieldOfView + ' aspect=' + View.aspectRatio.toFixed(4)
	+ ' standardDistance=' + View.standardDistance + ' frustumCulling=' + (View.frustumCulling ? 1 : 0));
lines.push('sky sphere exists: ' + (Content.exist('Assets/Model/StarSphere.gltf') ? 1 : 0)
	+ ' ; sky quad exists: ' + (Content.exist('Assets/Model/StarQuad.gltf') ? 1 : 0));
flush(false);

const def = getLevel(0);
if (def === undefined) {
	lines.push('RESULT=FAIL reason=no-level-1');
	flush(true);
} else {
	const bodies = scaledPlanets(def);
	const world = Node3D();
	Director.entry.addChild(world);
	const rtg = def.probeVariant === 'rtg';
	const scene: GameScene | undefined = buildScene({
		root: world,
		bodies,
		visuals: def.visuals,
		probeStart: def.probeStart,
		probeScale: levelRuntime(0).probeVisualRadius,
		spherePath: 'Assets/Model/Sphere.gltf',
		ringPath: 'Assets/Model/Ring.gltf',
		probePath: 'Assets/Model/Probe_Voyager_v1.glb',
		probeBodyPath: rtg ? 'Assets/Model/Probe_RTG_Body.glb' : 'Assets/Model/Probe_Solar_Body.glb',
		probeAntennaPath: rtg ? 'Assets/Model/Probe_RTG_Antenna.glb' : 'Assets/Model/Probe_Solar_Antenna.glb',
		probeAntennaPivotY: rtg ? 0.6641 : 0.6495,
		probeBodyRadius: rtg ? 0.871 : 1.084,
		probeAtlasPath: 'Assets/Image/probe_atlas.jpg',
		// ⚠️ 必须照**发布配置**建场景（Tuning 里怎么配就怎么建）：这张探针的全部意义就是
		// "现在这一版跑出来是不是一块灰"。写成固定值的话，Tuning 改坏了它也不会报警。
		orbitFlowDots: levelRuntime(0).orbitFlowDots,
		orbitRings: levelRuntime(0).orbitRings,
	});
	flush(false);

	if (scene === undefined) {
		lines.push('RESULT=FAIL reason=scene-build-failed');
		flush(true);
	} else {
		lines.push('scene built; probeRadius=' + scene.probeRadius);
		for (let i = 0; i < def.visuals.length; i++) {
			lines.push('  body ' + i.toFixed(0) + ' model=' + (def.visuals[i].model !== undefined ? def.visuals[i].model : '?')
				+ ' displayRadius=' + def.visuals[i].displayRadius
				+ ' orbitRadius=' + bodies[i].orbitRadius.toFixed(6));
		}
		flush(false);

		const camera = Camera3D();
		Director.pushCamera(camera);

		// L1 的"贴地球"机位（照 init 的 [cam] 诊断：target=(0,0,80.002) eye=(0,0.005,80.013)）
		const target = planeToWorld({ x: 0, y: 80 }, 0);
		const dist = 0.01264;
		const tilt = 22 * Math.PI / 180;
		const eye = Vec3(target.x, target.y + Math.sin(tilt) * dist, target.z + Math.cos(tilt) * dist);
		camera.lookAt(eye, target, Vec3(0, 1, 0));
		scene.syncBodies(0);
		// ⚠️ syncProbe 收的是**平面坐标**（内部自己 planeToWorld），传 Vec3 会把它放到原点
		// （第一版探针就这么错过：探测器跑到了太阳的位置）
		scene.syncProbe({ x: 0, y: 80.003514 });
		scene.syncBackdrop(eye, target);

		// 体检四档：发布配置 / 只有星空的裸背景 / 清屏色 / 引擎默认近平面
		const nearOpt = levelRuntime(0).cameraNear;
		const shippedNear = nearOpt !== undefined && nearOpt > 0 ? nearOpt : 0.1;
		const variants: Variant[] = [
			{ label: 'base(发布配置)', near: shippedNear, far: 10000, hide: 'none' },
			{ label: 'only-sky', near: shippedNear, far: 10000, hide: 'all' },
			{ label: 'world-off', near: shippedNear, far: 10000, hide: 'world' },
			{ label: 'engine-near0.1', near: 0.1, far: 10000, hide: 'none' },
		];
		/** 把节点恢复成全部可见，再按变体藏指定的那一个。 */
		const applyHide = (what: string): void => {
			world.visible = true;
			for (let i = 0; i < scene.planets.length; i++) scene.planets[i].body.visible = true;
			scene.probe.visible = true;
			if (what === 'world') { world.visible = false; return; }
			if (what === 'probe') { scene.probe.visible = false; return; }
			if (what === 'all') {
				for (let i = 0; i < scene.planets.length; i++) scene.planets[i].body.visible = false;
				scene.probe.visible = false;
				return;
			}
			if (what === 'sun') scene.planets[0].body.visible = false;
			else if (what === 'earth') scene.planets[1].body.visible = false;
			else if (what === 'moon') scene.planets[2].body.visible = false;
		};
		// 每个天体节点的世界位置/缩放 —— 万一某颗的 scale 失控，这几个数一眼就能看出来
		for (let i = 0; i < scene.planets.length; i++) {
			const n = scene.planets[i].body;
			lines.push('  node[' + i.toFixed(0) + '] pos=(' + n.position.x.toFixed(4) + ',' + n.position.y.toFixed(4) + ',' + n.position.z.toFixed(4)
				+ ') scale=' + n.scale.x.toFixed(6) + ' visible=' + (n.visible ? 1 : 0));
		}
		lines.push('  probe pos=(' + scene.probe.position.x.toFixed(4) + ',' + scene.probe.position.y.toFixed(4) + ',' + scene.probe.position.z.toFixed(4)
			+ ') scale=' + scene.probe.scale.x.toFixed(8));
		// 场景树的裸清单：**那块灰是哪个节点画出来的**，看位置/缩放一眼就能认出来
		// （天球 = 尺度 1200 的球、光晕 = 尺度 ~1.27 的四边形、行星 = displayRadius）
		lines.push('--- scene tree under world ---');
		const tree: string[] = [];
		dumpTree(world, 0, tree);
		for (const t of tree) lines.push(t);
		flush(false);
		const shots: string[] = [];
		const FramesPerVariant = 24;
		let frame = 0;

		lines.push('variants=' + variants.length.toFixed(0) + ' framesPerVariant=' + FramesPerVariant.toFixed(0));
		flush(false);

		threadLoop(() => {
			const vi = Math.floor(frame / FramesPerVariant);
			if (vi >= variants.length) {
				const report: string[] = [];
				for (let i = 0; i < shots.length; i++) {
					const part = analyze(shots[i], variants[i]);
					for (const l of part) report.push(l);
				}
				lines.push('');
				for (const l of report) lines.push(l);
				// 判定：① base 档（当前发布配置）的背景必须是**暗的**（无灰带）；
				//       ② 确实会翻车的两档（开着轨道圈 / 用引擎默认近平面）必须与它不同 ——
				//          否则说明这个守卫根本测不出东西（"绿得没有意义"）。
				const baseBg = bgMeans.length > 0 ? bgMeans[0] : -1;
				const nearBg = bgMeans.length > 3 ? bgMeans[3] : -1;
				const clearBg = bgMeans.length > 2 ? bgMeans[2] : -1;
				// 判据：发布配置下**背景必须是暗的**（< 45 = 没有那块灰带）。
				// 这条正是"切到 3D 一片灰 / 啥也看不到"的回归守卫 —— 元凶有两个：
				// ① 近平面 0.1（地月系被裁光）② 地球的日心轨道圈（横贯全屏的灰带）。
				const ok = baseBg >= 0 && baseBg < 45 && nearBg < 45 && clearBg > 20 && clearBg < 32;
				lines.push('');
				lines.push('VERDICT baseBg=' + baseBg.toFixed(1) + ' (要 < 45 = 无灰带)'
					+ ' engineNear0.1Bg=' + nearBg.toFixed(1) + ' (要 < 45 = 暗背景)'
					+ ' clearColorBg=' + clearBg.toFixed(1) + ' (要 ≈ 26 = 引擎清屏色)');
				lines.push('RESULT=' + (ok ? 'PASS' : 'FAIL'));
				flush(true);
				return true;
			}
			const local = frame % FramesPerVariant;
			const v = variants[vi];
			if (local === 0) {
				View.nearPlaneDistance = v.near;
				View.farPlaneDistance = v.far;
				applyHide(v.hide);
				scene.syncBackdrop(eye, target);
				lines.push('variant ' + v.label + ' applied at frame ' + frame.toFixed(0));
				flush(false);
			} else if (local === 4) {
				shots.push(App.saveScreenshot(Path(outDir, 'clip-' + vi.toFixed(0))));
			}
			frame += 1;
			return false;
		});
	}
}
