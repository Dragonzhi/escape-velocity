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
 * 资产复用：所有行星共用同一份 Sphere.gltf，靠每实例
 * `getMaterial(i).baseColor` 染色，并靠 `scale` 区分大小。
 * 同路径的 Model3D 共享底层网格（引擎缓存），内存只存一份。
 */
import { Color, Color3, DirectionalLight3D, Model3D, Node3D, Vec3 } from 'Dora';
import { PlaneToWorldX, PlaneToWorldZ } from 'game/Config';
import { Body, P2, bodyPositionAt } from 'game/Gravity';

/** 平面坐标 → 世界坐标（y 恒为 0，黄道面水平）。 */
export function planeToWorld(p: P2, y: number): Vec3.Type {
	return Vec3(p.x * PlaneToWorldX, y, p.y * PlaneToWorldZ);
}

/** 一颗行星的视觉描述。 */
export interface PlanetVisual {
	/** sRGB 基础色，0–1。 */
	r: number;
	g: number;
	b: number;
	/** 行星网格的显示半径（世界单位）。 */
	displayRadius: number;
	/** 是否附带土星环（白送的关卡风景，愿景 §6）。 */
	ring: boolean;
}

/** 行星在场景中的句柄。 */
export interface PlanetNode {
	/** 行星本体（球体）。 */
	body: Node3D.Type;
	/** 土星环（可能不存在）。 */
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
	/** 模型资产路径。 */
	spherePath: string;
	ringPath: string;
	probePath: string;
}

/**
 * 场景运行时对象。
 *
 * ⚠️ 必须加 `@noSelf`（见 self-parameter 教程）：
 * Dora 的 TSTL 启用了 `noImplicitSelf`，但**对象成员函数依然默认带 self**，
 * 除非声明 `this: void` 或用 `@noSelf`。
 * 不加时生成 `scene:syncProbe(pos)` 冒号调用，`scene` 会变成第一个参数，
 * 导致闭包参数错位（已实测报错 “field 'x' is nil”）。
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

		const sphere = Model3D(options.spherePath);
		if (sphere === undefined) return undefined;

		const scale = vis.displayRadius;
		sphere.scale = Vec3(scale, scale, scale);

		// 逐实例染色：同一份球体资产画出不同行星。
		const mat = sphere.getMaterial(0);
		if (mat !== undefined) {
			mat.baseColor = Color(vis.r * 255, vis.g * 255, vis.b * 255, 255);
		}

		root.addChild(sphere);

		let ringNode: Node3D.Type | undefined = undefined;
		if (vis.ring) {
			const ring = Model3D(options.ringPath);
			if (ring !== undefined) {
				// 土星环半径在人设里是 1.35–2.0，相对于行星半径换算。
				const rs = scale * 1.5;
				ring.scale = Vec3(rs, rs, rs);
				root.addChild(ring);
				ringNode = ring;
			}
		}

		planets.push({ body: sphere, ring: ringNode, def });
	}

	// ---- 探测器 ----
	const probeModel = Model3D(options.probePath);
	if (probeModel === undefined) return undefined;
	probeModel.scale = Vec3(options.probeScale, options.probeScale, options.probeScale);
	root.addChild(probeModel);

	const probeNode = probeModel;

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

	// 探测器模型指向 +X（见 Test/gen_shapes.lua 的 buildProbe）。
	// 需要让它朝速度方向：绕世界 Y 轴旋转。世界方向 (dx, 0, dz) 对应角度 atan2(-dz, dx)。
	const faceVelocity = (v: P2): void => {
		const wx = v.x * PlaneToWorldX;
		const wz = v.y * PlaneToWorldZ;
		if (wx * wx + wz * wz < 1e-12) return;
		probeNode.angleY = Math.atan2(-wz, wx) * 180 / Math.PI;
	};

	// 初始化到 t=0 的姿态
	syncBodies(0);
	syncProbe(probeStart);

	return { syncBodies, syncProbe, faceVelocity, probe: probeNode, planets };
}
