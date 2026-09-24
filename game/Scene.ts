/**
 * 3D 场景搭建：把物理状态“画出来”。
 *
 * 职责边界（手册 §4.1）：
 * - 本模块只负责“把状态画出来”，**不修改物理状态**。
 * - 物理真相在 game/Gravity.ts；本模块只读它的结果。
 *
 * 关键映射（已实测，手册 §5.1 / R3）：
 *   物理平面 (u, v) → 世界 (u * PlaneToWorldX, 0, v * PlaneToWorldZ)
 * 平面沿屏幕**纵向**（世界 Z）展开，因为竖屏下横向轨道会被裁切。
 *
 * ===== 资产（S3.1 已接线，会话 22）=====
 * - 行星：关卡数据给了 model 就用 Blender 导出的 Assets/Model/<model>.glb，
 *   否则回退到代码生成的 Sphere.gltf（单位球，半径 1）。同路径的 Model3D 共享底层网格。
 * - 逐实例染色：**循环 getMaterial(k) 直到 undefined**（材质数量不写死 —— 引擎的材质槽
 *   粒度与 GLB JSON 的 materials 数组不等价）。
 * - 尺度：scale = displayRadius / k，k = 模型在 scale=1 时的外接半径（实测见 MODEL_RADIUS）。
 * - 土星环：Planet_Saturn.glb **自带环**，所以只对“没有 model 且 ring=true”的行星才叠 Ring.gltf。
 * - 探测器：Probe_Voyager_v1.glb（21 mesh / 600 面）；朝向偏移见 ProbeYawOffsetDeg。
 * - 星空：两个“星点烤进网格”的壳（各 1 draw call、零贴图、天然在远景），见 buildScene 内注释。
 */
import { Color, Color3, DirectionalLight3D, Model3D, Node3D, Vec3 } from 'Dora';
import { PlaneToWorldX, PlaneToWorldZ } from 'game/Config';
import { Body, P2, bodyPositionAt } from 'game/Gravity';

/** 平面坐标 → 世界坐标（y 恒为 0，黄道面水平）。 */
export function planeToWorld(p: P2, y: number): Vec3.Type {
	return Vec3(p.x * PlaneToWorldX, y, p.y * PlaneToWorldZ);
}

/**
 * 模型半径系数表：k = 该 .glb 在 scale=1 时的**外接半径**（世界单位）。
 *
 * 实测（Test/ModelCalibProbe.ts → .agent/test-results/s31-scale.txt，两个独立口径）：
 *   ① 引擎 getLocalBoundsMin/Max 的最大半宽（精确；下表取值）
 *   ② 与已知半径 1 的 Sphere.gltf 并排、同 scale(=1) 渲染后的屏幕像素直径比
 *      ⇒ 逐模型 1.00 / 1.00 / 1.06 / 1.03 / 1.00（与①在 ±4% 内一致，差值是低多边形顶点不规则）
 * 结论：这批行星模型的半径就是 **1.0 左右**（不是 0.1、也不是 10），
 * 因此 scale = displayRadius / k 与旧的“单位球 × displayRadius”在观感上等价。
 *
 * Planet_Saturn 的 k 取**本体**半径（y 半宽）：环在 x/z 平面（±2.2），不参与 k，
 * 否则环会被 displayRadius 二次放大。
 */
interface ModelRadius { name: string; k: number; }

const MODEL_RADIUS: ModelRadius[] = [
	{ name: 'Planet_Earth', k: 1.0343 },
	{ name: 'Planet_Mars', k: 1.0227 },
	{ name: 'Planet_Venus', k: 1.0215 },
	{ name: 'Planet_Jupiter', k: 1.0000 },
	{ name: 'Planet_Saturn', k: 0.9837 },
	{ name: 'Planet_Neptune', k: 1.0170 },
];

/** 取模型半径系数；表里没有的名字按 1.0 处理（等价于旧行为）。 */
function modelRadius(name: string): number {
	for (let i = 0; i < MODEL_RADIUS.length; i++) {
		if (MODEL_RADIUS[i].name === name) return MODEL_RADIUS[i].k;
	}
	return 1.0;
}

/**
 * 探测器朝向偏移（度）。
 *
 * 实测（Test/ModelCalibProbe.ts → .agent/test-results/s31-orient.txt）：
 * - 引擎的 angleY 把**局部 +X** 旋到世界 (cos θ, 0, -sin θ)、局部 +Z 旋到 (sin θ, 0, cos θ)——
 *   用已知朝 +X 的旧 Probe.gltf（正四面体）在 yaw=0/90/180/270 读**世界**包围盒验证
 *   （yaw=0: 顶点在 world x=+1；yaw=90: 顶点在 world z=-1）。所以 faceVelocity 里
 *   现有的 atan2(-wz, wx) 含义就是“让局部 +X 对准速度方向”。
 * - Probe_Voyager_v1.glb 的体轴**不是 X 而是 Z**（俯视 yaw=0 实测）：
 *   抛物面天线是一块朝上的圆盘（直径 3.227 = 模型最长边），
 *   两根粗主杆沿 **+Z** 伸出（到 z=+1.00，图中朝屏幕下方），
 *   一根细长磁强计杆沿 **-Z** 伸出（到 z=-1.85，图中朝屏幕上方）。
 *   ⇒ 让 **-Z（细杆）朝前、+Z（两根主杆）拖在后**，就是飞船“在飞”的样子。
 *   即需要 局部 +Z → 速度的反方向：θ = θ_faceVelocity - 90°。
 */
const ProbeYawOffsetDeg = -90;

/** 一颗行星的视觉描述。 */
export interface PlanetVisual {
	/** sRGB 基础色，0–1。 */
	r: number;
	g: number;
	b: number;
	/** 行星网格的显示半径（世界单位）。 */
	displayRadius: number;
	/** 是否附带土星环（白送的关卡风景，愿景 §6）；模型自带环时不生效。 */
	ring: boolean;
	/** 模型名（不含路径与扩展名，如 'Planet_Mars'）；留空表示回退到 spherePath。 */
	model?: string;
}

/** 行星在场景中的句柄。 */
export interface PlanetNode {
	/** 行星本体（球体或 .glb 模型）。 */
	body: Node3D.Type;
	/** 土星环（可能不存在；模型自带环时为 undefined）。 */
	ring?: Node3D.Type;
	/** 对应的物理定义。 */
	def: Body;
}

/** 探测器在场景中的句柄。 */
export interface ProbeNode {
	node: Node3D.Type;
}

export interface SceneOptions {
	/** 场景根节点（通常是 Director.entry）。 */
	root: Node3D.Type;
	/** 行星定义（已应用过倍率）。 */
	bodies: Body[];
	/** 与 bodies 一一对应的视觉描述。 */
	visuals: PlanetVisual[];
	/** 探测器初始平面位置。 */
	probeStart: P2;
	/** 探测器模型显示缩放。 */
	probeScale: number;
	/** 模型资产路径（回退用）。 */
	spherePath: string;
	ringPath: string;
	probePath: string;
}

/**
 * 场景运行时对象。
 *
 * ⚠️ 必须加 @noSelf（见 self-parameter 教程）：
 * Dora 的 TSTL 启用了 noImplicitSelf，但**对象成员函数依然默认带 self**，
 * 除非声明 this: void 或用 @noSelf。不加时生成 scene:syncProbe(pos) 冒号调用，
 * scene 会变成第一个参数，导致闭包参数错位（已实测报错 “field 'x' is nil”）。
 *
 * @noSelf
 */
export interface GameScene {
	/** 每帧把行星同步到时刻 t 的位置（t 来自物理推演）。 */
	syncBodies(t: number): void;
	/** 把探测器同步到平面位置。 */
	syncProbe(p: P2): void;
	/** 把探测器朝向对齐到速度方向（只看平面内方向）。 */
	faceVelocity(v: P2): void;
	/** 当前探测器节点（供相机读取世界位置）。 */
	probe: Node3D.Type;
	/** 行星节点表。 */
	planets: PlanetNode[];
	/** 探测器模型的**世界**外接半径，喂给相机取景（否则天线会被画面边缘切掉）。 */
	probeRadius: number;
}

/**
 * 构建场景。
 *
 * @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
 */
export function buildScene(options: SceneOptions): GameScene | undefined {
	const { root, bodies, visuals, probeStart } = options;

	// ---- 光源：一盏方向光（愿景 §6） ----
	const light = DirectionalLight3D();
	light.color = Color3(0xfff3da);
	light.intensity = 3.2;
	light.angleX = -48;
	light.angleY = 28;
	root.addChild(light);

	// ---- 行星 ----
	const planets: PlanetNode[] = [];
	for (let i = 0; i < bodies.length; i++) {
		const def = bodies[i];
		const vis = visuals[i];

		// 优先用关卡指定的 .glb；没有（或没加载上）则回退到代码生成的单位球。
		let bodyModel: Model3D.Type | undefined = undefined;
		let k = 1.0;
		const modelName = vis.model !== undefined ? vis.model : '';
		if (modelName !== '') {
			const loaded = Model3D('Assets/Model/' + modelName + '.glb');
			if (loaded !== undefined) {
				bodyModel = loaded;
				k = modelRadius(modelName);
			}
		}
		if (bodyModel === undefined) {
			bodyModel = Model3D(options.spherePath);
			k = 1.0;
		}
		if (bodyModel === undefined) return undefined;

		// displayRadius 的语义 = 行星本体半径：scale = displayRadius / k
		const scale = vis.displayRadius / k;
		bodyModel.scale = Vec3(scale, scale, scale);

		// 逐实例染色：循环到 getMaterial 返回 undefined（**不写死材质数量**）。
		let mi = 0;
		while (mi < 64) {
			const mat = bodyModel.getMaterial(mi);
			if (mat === undefined) break;
			mat.baseColor = Color(vis.r * 255, vis.g * 255, vis.b * 255, 255);
			mi += 1;
		}

		root.addChild(bodyModel);

		// 土星环：模型自带环的（Planet_Saturn）不再叠 Ring.gltf。
		let ringNode: Node3D.Type | undefined = undefined;
		if (modelName === '' && vis.ring) {
			const ring = Model3D(options.ringPath);
			if (ring !== undefined) {
				// 土星环半径在人设里是 1.35–2.0，相对于行星半径换算。
				const rs = scale * 1.5;
				ring.scale = Vec3(rs, rs, rs);
				root.addChild(ring);
				ringNode = ring;
			}
		}

		planets.push({ body: bodyModel, ring: ringNode, def });
	}

	// ---- 探测器 ----
	const probeModel = Model3D(options.probePath);
	if (probeModel === undefined) return undefined;
	probeModel.scale = Vec3(options.probeScale, options.probeScale, options.probeScale);
	root.addChild(probeModel);

	const probeNode = probeModel;

	// 取景用：探测器的世界外接半径。
	// 相机只把关键点当**质点**，于是碟形天线会被画面边缘切掉（L3 实测踩过），
	// 所以把“探测器有体积”这一项也算进取景求解（见 game/CameraRig.ts 的 frameFits）。
	// 口径：局部 AABB 的**最大边一半** × scale × 1.1，不取外接球 —— 两根吊杆是沿飞行轴
	// 伸出去的（z -1.85…1.00），在屏幕上并不占宽度，用外接球会把相机推得过远。
	let probeRadius = 1.5 * options.probeScale;
	try {
		const lo = probeModel.getLocalBoundsMin();
		const hi = probeModel.getLocalBoundsMax();
		const ex = hi.x - lo.x;
		const ey = hi.y - lo.y;
		const ez = hi.z - lo.z;
		let maxDim = ex > ey ? ex : ey;
		if (ez > maxDim) maxDim = ez;
		if (maxDim > 0) probeRadius = 0.5 * maxDim * options.probeScale * 1.1;
	} catch (e) {
		// 没有包围盒的资产（或 API 不可用）：保留兜底值，不影响正确性
		print('[escape-velocity] probe bounds unavailable, using fallback radius ' + probeRadius.toFixed(2));
	}

	// ---- 星空壳（S3.2 选定方案 C2：星点烤进网格）----
	// 1 draw call / 零贴图 / 深度天然正确（壳半径 120–380，远在行星与轨迹之后）。
	// ⚠️ 星空**不吃光照**（用 emissive），否则方向光会让它变暗变色；
	//    也**不要**放大 scale（实测距离 >400 的 Model3D 不可见）。
	const shell = Model3D('Assets/Model/StarShell.gltf');
	if (shell !== undefined) {
		const sm = shell.getMaterial(0);
		if (sm !== undefined) {
			sm.baseColor = Color(255, 255, 255, 255);
			sm.emissive = Color3(0xffffff);
			sm.roughness = 1.0;
			sm.metallic = 0.0;
		}
		root.addChild(shell);
	}
	const shellBright = Model3D('Assets/Model/StarShellBright.gltf');
	if (shellBright !== undefined) {
		const bm = shellBright.getMaterial(0);
		if (bm !== undefined) {
			bm.baseColor = Color(255, 255, 255, 255);
			bm.emissive = Color3(0xfff2d0);
			bm.roughness = 1.0;
			bm.metallic = 0.0;
		}
		root.addChild(shellBright);
	}

	// ---- 同步函数 ----
	const syncBodies = (t: number): void => {
		for (const p of planets) {
			const wp = planeToWorld(bodyPositionAt(p.def, t), 0);
			p.body.position = wp;
			if (p.ring !== undefined) p.ring.position = wp;
		}
	};

	const syncProbe = (p: P2): void => {
		probeNode.position = planeToWorld(p, 0);
	};

	// 需要让探测器朝速度方向：绕世界 Y 轴旋转。
	// 世界方向 (dx, 0, dz) 对应角度 atan2(-dz, dx)（已用旧 Probe.gltf 实测标定）。
	// 模型自身“朝前的轴”不是 +X 时用 ProbeYawOffsetDeg 补正（见其注释）。
	const faceVelocity = (v: P2): void => {
		const wx = v.x * PlaneToWorldX;
		const wz = v.y * PlaneToWorldZ;
		if (wx * wx + wz * wz < 1e-12) return;
		probeNode.angleY = Math.atan2(-wz, wx) * 180 / Math.PI + ProbeYawOffsetDeg;
	};

	// 初始化到 t=0 的姿态
	syncBodies(0);
	syncProbe(probeStart);

	return { syncBodies, syncProbe, faceVelocity, probe: probeNode, planets, probeRadius };
}
