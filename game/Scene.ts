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
 * ===== 资产（S3.1 已接线，会话 22；会话 25 更新）=====
 * - 行星：关卡数据给了 model 就用 Blender 导出的 Assets/Model/<model>.glb，
 *   否则回退到代码生成的 Sphere.gltf（单位球，半径 1）。同路径的 Model3D 共享底层网格。
 * - 逐实例染色：**循环 getMaterial(k) 直到 undefined**（材质数量不写死 —— 引擎的材质槽
 *   粒度与 GLB JSON 的 materials 数组不等价）。
 * - 尺度：scale = displayRadius / k，k = 模型在 scale=1 时的外接半径（实测见 MODEL_RADIUS）。
 * - 土星环：Planet_Saturn.glb **自带环**，所以只对“没有 model 且 ring=true”的行星才叠 Ring.gltf。
 * - 探测器：**分体**（会话 25）—— Probe_Body.glb（身体）+ Probe_Antenna.glb（天线，转轴在文件
 *   原点），天线可绕转轴独立旋转（"回头指向地球"）；单体 Probe_Voyager_v1.glb 作为回退。
 *   ⚠️ 为什么拆文件：引擎的 Node3D 不把 glTF 子节点暴露成可寻址节点（Test/AntennaProbe 实测）。
 * - 沿轨道流动的光点（S3.16）：每条会公转的轨道一串 StarQuad 自发光面片，方向 = orbitDirection、
 *   快慢 ∝ ω = 2π/orbitPeriod，每帧只改位置（数学与 2D 共用 game/OrbitFlow.ts）。
 * - 地球：家园锚点（纯视觉，不进物理），大天线的指向目标。
 * - 星空：一张程序化星图贴在贴着相机的四边形背板上（方案 B，2026-09-25 用户拍板；
 *   每帧由 syncBackdrop 钉到视线前方），见 buildScene 内注释。
 */
import {
	Color, Color3, Content, DirectionalLight3D, MaterialAlphaMode3D, Model3D, Node3D, PointLight3D, Texture2D, Vec3,
} from 'Dora';
import {
	OrbitRingTintHex, PlaneToWorldX, PlaneToWorldZ,
	SunGlowScale, SunLightIntensity, SunLightRange, SunMinGmForLight,
} from 'game/Config';
import { Body, P2, bodyPositionAt } from 'game/Gravity';
import { FlowDotsPerOrbit, flowDotAngle, orbitCenterAt } from 'game/OrbitFlow';

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
	// S3.14 建模交付（docs/交付清单_Trae.md）：天体全部重做成**单位球**（半径 1.0、球心在原点），
	// 所以 k = 1.000 —— 由 tools/glb-check.mjs 核对过 POSITION 的 min/max 都是 ±1.00。
	{ name: 'Sun', k: 1.0000 },
	{ name: 'Moon', k: 1.0000 },
	{ name: 'Planet_Earth', k: 1.0000 },
	{ name: 'Planet_Venus', k: 1.0000 },
	{ name: 'Planet_Mars', k: 1.0000 },
	{ name: 'Planet_Jupiter', k: 1.0000 },
	{ name: 'Planet_Neptune', k: 1.0000 },
	// ⚠️ 带环的两颗：k 取**本体**半径（1.000），环不参与标定 —— 土星环在 xz 平面（法线 y，±2.2）、
	// 天王星环在 xy 平面（法线 z，±1.95，对应真实 98° 轴倾）；否则环会被 displayRadius 二次放大。
	// 两者的环现在都是**模型自带**的（不再叠 Ring.gltf，见行星循环里的判断）。
	{ name: 'Planet_Saturn', k: 1.0000 },
	{ name: 'Planet_Uranus', k: 1.0000 },
];

/** 取模型半径系数；表里没有的名字按 1.0 处理（等价于旧行为）。 */
export function modelRadius(name: string): number {
	for (let i = 0; i < MODEL_RADIUS.length; i++) {
		if (MODEL_RADIUS[i].name === name) return MODEL_RADIUS[i].k;
	}
	return 1.0;
}

/** 一个天体的贴图（文件名按 §3.6 全小写下划线，全部在 Assets/Image/ 下）。 */
interface PlanetTexDef {
	/** 模型名（不含路径与扩展名）。 */
	name: string;
	/** baseColor 贴图文件名。 */
	base: string;
	/** 自发光贴图（地球夜面灯光 / 太阳表面）。省略 = 不用自发光贴图。 */
	emissive?: string;
	/** 自发光乘数（0xRRGGBB）。太阳要满值，地球夜灯要很暗（贴图大部分是黑的）。 */
	emisMul?: number;
	/** 环条带（只对**环材质**用：alphaMode = Blend 的那个材质）。 */
	ring?: string;
}

/**
 * 贴图表（S3.14 建模交付）。
 *
 * ⚠️ 交付的 .glb **不含内嵌贴图**（tools/glb-check.mjs 核对：images = 0），贴图一律走外部文件、
 *    由这里在运行时绑定。行星有 UV（等距圆柱：U 沿经度、接缝在 +Z 背面；V 沿纬度，北极 v=1）。
 * ⚠️ 环的贴图要给**环材质**，而引擎拿不到 glTF 材质名（Material3D 没有 name 字段）——
 *    所以用建模约定的 **alphaMode = Blend** 认它（实测 Saturn_Ring_Mat / Uranus_Ring_Mat 都是 BLEND，
 *    本体材质是 OPAQUE）。环的 UV 是径向的：U = 0 内环 → U = 1 外环。
 */
const PLANET_TEX: PlanetTexDef[] = [
	{ name: 'Sun', base: 'sun.jpg', emissive: 'sun.jpg', emisMul: 0xffffff },
	{ name: 'Moon', base: 'moon.jpg' },
	{ name: 'Planet_Earth', base: 'planet_earth.jpg', emissive: 'planet_earth_emissive.png', emisMul: 0x2a2a2a },
	{ name: 'Planet_Venus', base: 'planet_venus.jpg' },
	{ name: 'Planet_Mars', base: 'planet_mars.jpg' },
	{ name: 'Planet_Jupiter', base: 'planet_jupiter.jpg' },
	{ name: 'Planet_Saturn', base: 'planet_saturn.jpg', ring: 'planet_saturn_ring.png' },
	{ name: 'Planet_Uranus', base: 'planet_uranus.jpg', ring: 'planet_uranus_ring.png' },
	{ name: 'Planet_Neptune', base: 'planet_neptune.jpg' },
];

/** 0xRRGGBB → 通道（不用位运算：tstl 对算术右移会编译失败，见手册 §7.1）。 */
function redOf(hex: number): number { return Math.floor(hex / 65536) % 256; }
function greenOf(hex: number): number { return Math.floor(hex / 256) % 256; }
function blueOf(hex: number): number { return Math.floor(hex) % 256; }

/** 0–1 的视觉色 → 0xRRGGBB（给「没有贴图时」的回退染色用）。 */
export function packColor(r: number, g: number, b: number): number {
	return Math.round(r * 255) * 65536 + Math.round(g * 255) * 256 + Math.round(b * 255);
}

/** 按文件名安全取贴图（引擎遇到不存在的文件会**抛异常**，所以先 Content.exist）。 */
function textureOf(file: string): Texture2D.Type | undefined {
	if (file === '') return undefined;
	const path = 'Assets/Image/' + file;
	if (!Content.exist(path)) return undefined;
	return Texture2D(path);
}

/**
 * 给一颗天体模型绑贴图 / 回退染色（关卡与开场共用同一份）。
 *
 * @param model 已加载的模型
 * @param modelName 模型名（不含路径与扩展名）
 * @param tintHex 没有贴图时的回退色（0xRRGGBB；0 = 不动 baseColor）
 * @param emissiveHex 自发光乘数（0xRRGGBB；0 = 用贴图表里的默认值）
 */
export function applyPlanetTexture(model: Model3D.Type, modelName: string, tintHex: number, emissiveHex: number): void {
	let def: PlanetTexDef | undefined = undefined;
	for (let i = 0; i < PLANET_TEX.length; i++) {
		if (PLANET_TEX[i].name === modelName) def = PLANET_TEX[i];
	}
	const baseTex = textureOf(def !== undefined ? def.base : '');
	const emiTex = textureOf(def !== undefined && def.emissive !== undefined ? def.emissive : '');
	const ringTex = textureOf(def !== undefined && def.ring !== undefined ? def.ring : '');
	let emiMul = emissiveHex;
	if (emiMul === 0 && emiTex !== undefined) {
		emiMul = def !== undefined && def.emisMul !== undefined ? def.emisMul : 0x2a2a2a;
	}
	// 循环到 getMaterial 返回 undefined：**不写死材质数量**（带环的行星有 2 个材质）
	let i = 0;
	while (i < 64) {
		const mat = model.getMaterial(i);
		if (mat === undefined) break;
		const isRing = ringTex !== undefined && mat.alphaMode === MaterialAlphaMode3D.Blend;
		if (isRing) {
			mat.setBaseColorTexture(ringTex);
			mat.baseColor = Color(255, 255, 255, 255);
		} else if (baseTex !== undefined) {
			// 贴图自带颜色 ⇒ baseColor 置白，否则会和视觉色相乘变成脏色
			mat.setBaseColorTexture(baseTex);
			mat.baseColor = Color(255, 255, 255, 255);
		} else if (tintHex > 0) {
			mat.baseColor = Color(redOf(tintHex), greenOf(tintHex), blueOf(tintHex), 255);
		}
		if (!isRing && emiTex !== undefined && emiMul > 0) {
			mat.setEmissiveTexture(emiTex);
			mat.emissive = Color3(emiMul);
		}
		i += 1;
	}
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

/**
 * 天线转轴在探测器本地系的位置（y，模型单位）。
 * 取自拆分前单体文件里 Probe_Antenna 空物体的 translation（建模把它放在碟面背面与
 * 支撑腿的汇交点）。天线文件按"转轴 = 原点"导出，游戏把天线模型放到本常量 × scale 处。
 */
export const AntennaPivotY = 0.20;

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
	/** 自发光（0–1，可选）—— 太阳用，让它看起来是光源而不是一颗石球（S3.7）。 */
	emissive?: { r: number; g: number; b: number };
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
	/**
	 * 地球（家园锚点）的平面位置，通常 = 出发点正下方几格。
	 * **纯视觉**：不进物理（无引力/碰撞）、不进相机取景点；大天线的指向目标。
	 * 省略 = 不放地球（天线也不转）。
	 */
	home?: P2;
	/** 家园锚点（地球）的显示半径（世界单位）；省略 = 1.15（旧行为）。 */
	homeRadius?: number;
	/** 探测器**身体**文件（去掉天线）。与 probeAntennaPath 同时给出才启用分体。 */
	probeBodyPath?: string;
	/** 探测器**天线**文件（仅 8 个天线零件，转轴在文件原点）。 */
	probeAntennaPath?: string;
	/** 天线转轴（机体本地 y，模型单位）。省略 = 0.20（旧单体文件）。 */
	probeAntennaPivotY?: number;
	/** 机体外接半径（模型单位）。省略 = 旧单体文件实测值。 */
	probeBodyRadius?: number;
	/** 探测器细节图集（只给带 UV 的新模型）。 */
	probeAtlasPath?: string;
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
	/** 把探测器同步到平面位置（含大天线"回头指向地球"的更新）。 */
	syncProbe(p: P2): void;
	/** 把探测器朝向对齐到速度方向（只看平面内方向）。 */
	faceVelocity(v: P2): void;
	/** 每帧把星空背板钉到「相机视线前方」（eye/target 来自相机机架的当前帧）。 */
	syncBackdrop(eye: Vec3.Type, target: Vec3.Type): void;
	/** 当前探测器根节点（定位 + 朝速度方向）。 */
	probe: Node3D.Type;
	/** 天线模型（分体模式）；单体回退时为 undefined。 */
	antenna?: Node3D.Type;
	/** 行星节点表。 */
	planets: PlanetNode[];
	/** 探测器模型的**世界**外接半径，喂给相机取景（否则天线会被画面边缘切掉）。 */
	probeRadius: number;
}

/** 探测器组装参数。 */
export interface ProbeOptions {
	/** 世界缩放（模型单位 → 世界单位）。 */
	scale: number;
	/** 单体文件（回退用；分体两个文件都在时不加载）。 */
	probePath: string;
	/** 分体：身体（去掉天线）。 */
	bodyPath?: string;
	/** 分体：天线（**文件原点 = 转轴**）。 */
	antennaPath?: string;
	/**
	 * 天线转轴在**机体本地系**里的 y（模型单位）。省略 = 0.20（旧单体文件的值）。
	 * S3.14 的建模交付：太阳能板版 **0.6495**、RTG 版 **0.6641**（两版机身高度不同）。
	 */
	antennaPivotY?: number;
	/**
	 * 机体模型的外接半径（模型单位）。省略 = 旧单体文件的实测值（0.5 × 3.227）。
	 * S3.14：Probe_Solar_Body **1.084**、Probe_RTG_Body **0.871**（交付文档 §A.2 实测）。
	 */
	bodyRadius?: number;
	/**
	 * 细节图集（如 'Assets/Image/probe_atlas.jpg'）：绑到机体与天线的**所有**材质当 baseColor 贴图。
	 * 只对**有 UV** 的新模型给（旧分体文件没有 UV，绑了会取到未定义 UV ⇒ 花屏）。
	 */
	atlasPath?: string;
}

/** 探测器句柄。 */
export interface ProbeHandle {
	/** 根节点（拿去定位 / 朝速度方向）。 */
	node: Node3D.Type;
	/** 天线模型（分体模式）；单体回退时为 undefined。 */
	antenna?: Node3D.Type;
	/** 模型的**世界**外接半径，喂给相机取景（否则天线会被画面边缘切掉）。 */
	radius: number;
}

/**
 * 按"分体"约定组装探测器（关卡与 S3.3 开场共用）。
 *
 * ⚠️ 引擎的 Node3D **不把 glTF 子节点暴露成可寻址节点**（Test/AntennaProbe 实测：
 *    children/eachChild/name 全部不可访问，hasChildren 恒 false），所以"大天线回头指向地球"
 *    只能靠**拆文件**：Probe_Body.glb（去掉天线）+ Probe_Antenna.glb（仅天线，转轴在文件原点）。
 *    两个文件都在 → 天线可绕转轴旋转；缺任何一个 → 回退单体（天线刚性，不影响玩法）。
 * ⚠️ Model3D 对**不存在的文件**不是返回 nil 而是**抛运行时错误**（"can not locate full path"
 *    → Object::createNotNull failed，实测把整个建关流程炸掉、画面全黑）——
 *    所以"可选资产"必须先用 Content.exist 守卫，绝不能拿 Model3D 的返回值做存在性判断。
 * ⚠️ 不要给天线再套一层普通 Node3D 枢轴容器并每帧旋转它：会触发引擎堆损坏（0xc0000374）。
 *
 * @returns 句柄；连单体文件都加载不上时返回 undefined（调用方应报错）。
 */
/** 把细节图集绑到模型的每个材质（**不改 baseColor**：建模的材质色就是要和图集相乘的）。 */
function applyAtlas(model: Model3D.Type, tex: Texture2D.Type): void {
	let i = 0;
	while (i < 64) {
		const mat = model.getMaterial(i);
		if (mat === undefined) break;
		mat.setBaseColorTexture(tex);
		i += 1;
	}
}

export function createProbe(parent: Node3D.Type, opts: ProbeOptions): ProbeHandle | undefined {
	const scale = opts.scale;
	const pivotY = opts.antennaPivotY !== undefined ? opts.antennaPivotY : AntennaPivotY;
	const bodyRadius = opts.bodyRadius !== undefined ? opts.bodyRadius : 0.5 * 3.227;
	const bodyModel = opts.bodyPath !== undefined && Content.exist(opts.bodyPath)
		? Model3D(opts.bodyPath)
		: undefined;
	const antennaModel = bodyModel !== undefined && opts.antennaPath !== undefined && Content.exist(opts.antennaPath)
		? Model3D(opts.antennaPath)
		: undefined;
	const singleModel = bodyModel === undefined ? Model3D(opts.probePath) : undefined;
	if (bodyModel === undefined && singleModel === undefined) return undefined;

	const node = Node3D();
	parent.addChild(node);

	if (bodyModel !== undefined) {
		bodyModel.scale = Vec3(scale, scale, scale);
		node.addChild(bodyModel);
	}
	if (singleModel !== undefined) {
		singleModel.scale = Vec3(scale, scale, scale);
		node.addChild(singleModel);
	}

	// 天线模型直接挂在探测器根下、位置在转轴处（模型本地 (0, pivotY, 0)·scale）；
	// 建模约定：天线文件以转轴为原点 ⇒ 旋转天线模型节点 = 绕转轴摆动。
	// ⚠️ pivotY 是**逐版本**的（S3.14：太阳能 0.6495 / RTG 0.6641 —— 两版机身高度不同）。
	if (bodyModel !== undefined && antennaModel !== undefined) {
		antennaModel.scale = Vec3(scale, scale, scale);
		antennaModel.position = Vec3(0, pivotY * scale, 0);
		node.addChild(antennaModel);
	}

	// 细节图集（S3.14 交付：探测器带 UV，probe_atlas.jpg 按分区排好）。只给新模型 ——
	// 旧分体文件（Probe_Body/Probe_Antenna）没有 UV，绑了会取到未定义 UV。
	if (opts.atlasPath !== undefined && Content.exist(opts.atlasPath)) {
		const atlas = Texture2D(opts.atlasPath);
		if (atlas !== undefined) {
			if (bodyModel !== undefined) applyAtlas(bodyModel, atlas);
			if (singleModel !== undefined) applyAtlas(singleModel, atlas);
			if (antennaModel !== undefined) applyAtlas(antennaModel, atlas);
		}
	}

	return {
		node,
		antenna: antennaModel,
		// 口径：**外接半径 × scale × 1.1** —— 旧单体文件是实测的 AABB 最大边 3.227 的一半
		// （碟面直径，ModelCalibProbe 标定），S3.14 的两版新机体由 `bodyRadius` 传进来
		// （Solar 1.084 / RTG 0.871，交付文档实测）。不取外接球：两根吊杆沿飞行轴伸出，
		// 屏幕上不占宽度。
		radius: bodyRadius * scale * 1.1,
	};
}

/**
 * "大天线回头指向地球"的目标法线（关卡与 S3.3 开场共用同一份算式）。
 *
 * 目标法线 = 从"朝上"向目标方向倾斜（倾角随距离渐入——刚出发距离 ≈ 0 时不倾）；
 * 方位角在**机身本地系**里算（机身自己会被 faceVelocity 转到速度方向）。
 * Euler 次序（angleY 后 angleZ）按截图标定；若天线倾倒方向不随位置变，说明次序反了。
 *
 * ⚠️ 不要拆成 angleY/angleZ 两次赋值：每帧两次独立 Euler setter 会触发引擎
 *    堆损坏（0xc0000374，二分 C1 实测定位）；一次性写 angles 整体更新则稳定。
 *
 * @param probe 探测器位置（平面坐标）
 * @param target 指向目标（平面坐标；关卡传地球锚点，开场传地球）
 * @param bodyYawDeg 机身当前朝向（度；由 probeYawForVelocity 维护）
 */
export function pointAntenna(antenna: Node3D.Type, probe: P2, target: P2, bodyYawDeg: number): void {
	const ex = (target.x - probe.x) * PlaneToWorldX;
	const ez = (target.y - probe.y) * PlaneToWorldZ;
	const dist = Math.sqrt(ex * ex + ez * ez);
	if (dist <= 1e-4) return;
	let tiltFactor = (dist - 0.5) / 3.0;
	if (tiltFactor < 0) tiltFactor = 0;
	if (tiltFactor > 1) tiltFactor = 1;
	const tilt = 46 * tiltFactor;
	const phiWorld = Math.atan2(-ez, ex) * 180 / Math.PI;
	antenna.angles = Vec3(0, phiWorld - bodyYawDeg, -tilt);
}

/**
 * 速度方向 → 机身 yaw（度）。返回 undefined 表示速度太小（保持原朝向）。
 *
 * 世界方向 (dx, 0, dz) 对应 yaw = atan2(-dz, dx)（用已知朝 +X 的旧 Probe.gltf 在
 * yaw=0/90/180/270 读世界包围盒标定过）；模型自身"朝前的轴"不是 +X 时由
 * ProbeYawOffsetDeg 补正。
 */
export function probeYawForVelocity(v: P2): number | undefined {
	const wx = v.x * PlaneToWorldX;
	const wz = v.y * PlaneToWorldZ;
	if (wx * wx + wz * wz < 1e-12) return undefined;
	return Math.atan2(-wz, wx) * 180 / Math.PI + ProbeYawOffsetDeg;
}

/** 星空背板距相机的距离（世界单位）与半边尺寸；理由见 createStarBackdrop。 */
const BackdropDist = 600;
const BackdropHalf = 560;

/** 天球半径（世界单位）。 */
const SkyRadius = 1200;
/** 天球资产（Test/gen_orbit_assets.py 生成）。 */
const SkySpherePath = 'Assets/Model/StarSphere.gltf';
/**
 * 星空总亮度（emissive 0xRRGGBB）。
 *
 * 2026-09-26 换天球时把 0x8c 调到 0x7a：新贴图是 2048×1024（1 texel ≈ 4.2 屏幕像素，
 * 星点直径 1.5–6 px），比旧面片版（1024²，1 texel ≈ 2.3 px）的点更大更亮，
 * 同样的 emissive 会显得"星点变大变吵"，压一档回到原来的观感。
 */
const StarBrightnessHex = 0x7a7a7a;

/** 星图背板句柄（关卡与开场共用）。 */
export interface StarBackdrop {
	/** 节点本身（天球；回退模式下是四边形）。 */
	node: Model3D.Type;
	/** 每帧跟随相机（天球 = 球心挪到 eye；回退模式 = 钉在视线前方）。 */
	sync(eye: Vec3.Type, target: Vec3.Type): void;
}

/**
 * 建星空：**世界尺度的天球 + 每帧把球心挪到相机位置**（2026-09-26，用户第 5 条反馈）。
 *
 * 为什么换掉面片：旧的四边形是"钉在视线前方 600"的，但它**朝向写死**（angleX = -45）。
 * 开场里相机要从全景俯冲到特写（俯角 42°→20°、方位角差 60°+），朝向不匹配时星图会被拉伸/透视错位，
 * 一眼看出是块贴片。天球没有朝向问题：转到哪个角度看都对。
 * 球心跟着相机 ⇒ 旋转带着星空一起转（正确），平移不产生视差（等价于无穷远，也正确）。
 *
 * 天球半径 1200：远大于任何场景跨度（全景最外轨道 55、关卡 25–100），
 * 又远小于远裁剪面（实测 > 2000，Test/FarPlaneProbe，2026-09-25）。
 *
 * 素材由 Test/gen_orbit_assets.py 代码生成：starfield.png（2048×1024 等距圆柱）
 * + StarSphere.gltf（单位球，**scale = 天球半径**，材质自带 doubleSided）。
 * 旧的 StarQuad.gltf / 1024² 贴图保留作回退。
 */
export function createStarBackdrop(root: Node3D.Type): StarBackdrop | undefined {
	const tex = Texture2D('Assets/Image/starfield.png');

	// 主路：天球
	if (Content.exist(SkySpherePath)) {
		const sphere = Model3D(SkySpherePath);
		if (sphere !== undefined) {
			const sm = sphere.getMaterial(0);
			if (sm !== undefined && tex !== undefined) {
				// ⚠️ 星空**不吃光照**：只走 emissive 槽（baseColor 留黑），总亮度 = emissive 一个旋钮。
				// 首版双槽全白 = 贴图亮度 ×2，用户反馈"喧宾夺主"后压到 ~55%（0x8c）。
				sm.setEmissiveTexture(tex);
				sm.baseColor = Color(0, 0, 0, 255);
				sm.emissive = Color3(StarBrightnessHex);
				sm.roughness = 1.0;
				sm.metallic = 0.0;
			}
			sphere.scale = Vec3(SkyRadius, SkyRadius, SkyRadius);
			sphere.position = Vec3(0, 0, 0);
			root.addChild(sphere);
			return {
				node: sphere,
				sync: (eye: Vec3.Type, target: Vec3.Type): void => {
					sphere.position = Vec3(eye.x, eye.y, eye.z);
				},
			};
		}
	}

	// 回退：旧的面片（资产缺失时仍能看）
	const backdrop = Model3D('Assets/Model/StarQuad.gltf');
	if (backdrop === undefined) return undefined;
	const bm = backdrop.getMaterial(0);
	if (bm !== undefined && tex !== undefined) {
		bm.setEmissiveTexture(tex);
		bm.baseColor = Color(0, 0, 0, 255);
		bm.emissive = Color3(StarBrightnessHex);
		bm.roughness = 1.0;
		bm.metallic = 0.0;
	}
	backdrop.scale = Vec3(BackdropHalf, BackdropHalf, BackdropHalf);
	backdrop.angleX = -45;
	backdrop.position = Vec3(0, 0, -BackdropDist);
	root.addChild(backdrop);
	return {
		node: backdrop,
		sync: (eye: Vec3.Type, target: Vec3.Type): void => {
			const dx = target.x - eye.x;
			const dy = target.y - eye.y;
			const dz = target.z - eye.z;
			const len = Math.sqrt(dx * dx + dy * dy + dz * dz);
			if (len < 1e-6) return;
			const s = BackdropDist / len;
			backdrop.position = Vec3(eye.x + dx * s, eye.y + dy * s, eye.z + dz * s);
		},
	};
}

/** ---- 沿轨道流动的光点（S3.16，用户原话："轨道圈看不出运动方向与快慢"）---- */
/** 光点面片与贴图：与太阳光晕**同源**的仓库内资产（单位四边形 + 径向渐变），不引入新素材。 */
const FlowDotModelPath = 'Assets/Model/StarQuad.gltf';
const FlowDotTexturePath = 'Assets/Image/glow.png';
/**
 * 光点面片的缩放（StarQuad 顶点是 ±1 ⇒ scale = 直径的一半）。
 * 随轨道半径放大（外圈离相机远，同样屏幕尺寸要更大的世界尺寸），夹在 [min, max]。
 */
const FlowDotMinScale = 0.8;
const FlowDotMaxScale = 2.0;
const FlowDotScalePerRadius = 0.012;
/** 光点的自发光色（0xRRGGBB）：暖白，与 2D 规划视图的光点同色系（PlanView 的 flowDotHex）。 */
const FlowDotEmissiveHex = 0xffd9a0;

/** 一条轨道上的光点池：建场景时一次建好，之后每帧只改 position（不重建节点）。 */
interface FlowOrbit {
	def: Body;
	dots: Node3D.Type[];
}

/**
 * 构建场景。
 *
 * @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
 */
export function buildScene(options: SceneOptions): GameScene | undefined {
	const { root, bodies, visuals, probeStart } = options;

	// ---- 恒星（太阳）：它就是光源本身（S3.12）----
	// 判据：**场里 gm 最大、且不绕别的天体转**的那个天体 = 恒星（L2~L6 是 bodies[0] 的太阳；
	// L1 是地月系，只有地球 gm 2600 ⇒ 低于 SunMinGmForLight，退回方向光）。
	// 从前这里无条件是一盏方向光，方位角写死（angleX=-42/angleY=75）——
	// 于是"太阳在哪"与"光从哪来"毫无关系：行星的明暗交界线不指向太阳，太阳自己也只是
	// 一颗被照亮的土黄球（用户会话 44 原话："太阳本身不发光"）。
	let starWorld: Vec3.Type | undefined = undefined;
	let starRadius = 0;
	let starGm = 0;
	for (let i = 0; i < bodies.length; i++) {
		const b = bodies[i];
		if (b.orbitRadius !== 0) continue; // 会绕别的天体转的不可能是恒星
		if (b.gm <= starGm) continue;
		starGm = b.gm;
		starRadius = b.radius;
		starWorld = planeToWorld({ x: b.orbitCenter.x, y: b.orbitCenter.y }, 0);
	}
	const hasStar = starWorld !== undefined && starGm >= SunMinGmForLight;
	// ⚠️ **为什么最终还是方向光**（S3.12 实测过一版点光源）：
	// 把点光源放在太阳中心（几何上唯一正确的位置）之后，光照按距离衰减 ——
	// 太阳半径 28、行星轨道 55~195，同一盏灯的强度没法同时照亮金星与海王星：
	// 实测强度 2.4 与 8.0 两档，**外圈行星全部发黑**（截图对比：木星/土星从暖褐变成暗灰）。
	// 用户要的"发光"是**视觉**上的（原话："太阳本身不发光就算了"），那件事由
	// ①太阳本体的自发光贴图 + ②朝向相机的光晕面片完成（见 buildSunGlow），
	// 行星的晨昏线继续由这盏方向光负责（它的方位角是按截图标定的）。
	{
		const light = DirectionalLight3D();
		light.color = Color3(0xfff3da);
		light.intensity = 3.6;
		light.angleX = -42;
		light.angleY = 75;
		root.addChild(light);
	}
	// 恒星索引：它的表面照不到自己（光在球心）⇒ 必须靠自发光贴图把自己点亮
	let starIndex = -1;
	if (hasStar) {
		let best = 0;
		for (let i = 0; i < bodies.length; i++) {
			const b = bodies[i];
			if (b.orbitRadius === 0 && b.gm > best) {
				best = b.gm;
				starIndex = i;
			}
		}
	}

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

		// 染色 / 绑贴图（S3.14 建模交付：行星与月球都带 UV + 外部贴图，配方在 PLANET_TEX）。
		// ⚠️ Color3/Color 吃的是 0–255 的整数（或 0xRRGGBB），不是 0–1 的浮点。
		// ⚠️ 太阳的自发光**只能靠贴图**：实测 Material3D.emissive 只有配了自发光贴图才看得出来
		//    （星空背板就是这么用的），而恒星表面照不到自己（光的来向都在它内部或背后）——
		//    所以它的照片（sun.jpg）既当 baseColor 又当 emissive（乘数满值）。
		applyPlanetTexture(bodyModel, modelName, packColor(vis.r, vis.g, vis.b),
			vis.emissive !== undefined ? packColor(vis.emissive.r, vis.emissive.g, vis.emissive.b) : 0);

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

	// ---- 行星轨道圈（S3.9）----
	// 用户要求：行星会运动 ⇒ 得有轨道指示；"不起眼的灰就行"。
	// ⚠️ 必须用 3D 网格而不是 2D 画线：2D 永远盖在 3D 之上，行星挡不住线（会话 27 的用户反馈）。
	// 半径 = 世界单位、**不缩放**（缩放会把线宽一起放大）；资产由 Test/gen_level_orbits.py
	// 从 game/LevelData.ts 的 ORBIT 表生成，所以改轨道半径后要重跑那个脚本。
	for (let i = 0; i < bodies.length; i++) {
		const def = bodies[i];
		if (def.orbitRadius <= 0) continue;
		const ringPath = 'Assets/Model/OrbitRing_' + def.orbitRadius.toFixed(0) + '.gltf';
		// ⚠️ Model3D 遇到不存在的文件会**抛异常**（手册 §5 的坑），所以先存在性检查。
		if (!Content.exist(ringPath)) continue;
		const orbitNode = Model3D(ringPath);
		if (orbitNode === undefined) continue;
		let oi = 0;
		while (oi < 8) {
			const om = orbitNode.getMaterial(oi);
			if (om === undefined) break;
			// ⚠️ tstl：Lua 5.3+ 没有算术右移，`>>` 会直接编译失败（TS100026）—— 拆通道要用 `>>>`
om.baseColor = Color((OrbitRingTintHex >>> 16) & 0xff, (OrbitRingTintHex >>> 8) & 0xff, OrbitRingTintHex & 0xff, 255);
			oi += 1;
		}
		const oc = planeToWorld(def.orbitCenter, 0);
		orbitNode.position = Vec3(oc.x, oc.y, oc.z);
		root.addChild(orbitNode);
	}

	// ---- 沿轨道流动的光点（S3.16）----
	// 处方（docs/关卡舞台表.md 第二节第 5 条）：每条轨道一串光点，**方向 = orbitDirection**（读字段，
	// 不写死顺行）、**快慢 ∝ 角速度 ω = 2π/orbitPeriod**（内圈快外圈慢 = 开普勒的视觉效果），
	// 位置由 tWorld 解析求出（game/OrbitFlow.ts，与 bodyPositionAt 同一个角公式）。
	// ⚠️ 性能：节点池**建场景时一次建好**（≤ 6 轨道 × 6 点 = 36 个 Model3D，同路径共享底层网格），
	//    之后每帧只改 position —— 不创建/销毁节点。
	// ⚠️ 只给"真的在绕东西转"的天体：太阳（orbitRadius = 0）与静止天体（orbitPeriod = 0）
	//    没有可流动的轨道。卫星（月球）的圆心是**会动的宿主**，由 orbitCenterAt 现场求。
	// ⚠️ 面片绕 X 转 90° **一次性**躺进黄道面（y = 0，与轨道圈同一平面）⇒ 不必每帧朝相机转，
	//    每帧只有一个 position 写入；俯视 20–60° 下它是略扁的软光斑（cos 0.5–0.94），观感即"光点"。
	const flowOrbits: FlowOrbit[] = [];
	const flowDotTex = Content.exist(FlowDotTexturePath) ? Texture2D(FlowDotTexturePath) : undefined;
	if (Content.exist(FlowDotModelPath)) {
		for (let i = 0; i < bodies.length; i++) {
			const def = bodies[i];
			// 卫星微观轨道（如月球 orbitRadius=0.2056）公转极快（1.25s），不加 3D 大面片，避免特写穿模贴脸遮挡
			if (def.orbitRadius < 2.0 || def.orbitPeriod === 0) continue;
			const dots: Node3D.Type[] = [];
			for (let k = 0; k < FlowDotsPerOrbit; k++) {
				const dot = Model3D(FlowDotModelPath);
				if (dot === undefined) break;
				// 配方与太阳光晕/星空背板同源：baseColor 留黑、只吃 emissive 贴图 ⇒ 不吃光照、
				// 不挡后面的星点；alphaMode = Blend 让边缘融进背景。
				// （引擎实测：Material3D.emissive 只有配了自发光贴图才看得出来。）
				const dm = dot.getMaterial(0);
				if (dm !== undefined) {
					if (flowDotTex !== undefined) {
						dm.setBaseColorTexture(flowDotTex);
						dm.setEmissiveTexture(flowDotTex);
					}
					dm.baseColor = Color(0, 0, 0, 255);
					dm.emissive = Color3(FlowDotEmissiveHex);
					dm.roughness = 1.0;
					dm.metallic = 0.0;
					dm.alphaMode = MaterialAlphaMode3D.Blend;
				}
				let s = def.orbitRadius * FlowDotScalePerRadius;
				if (s < FlowDotMinScale) s = FlowDotMinScale;
				if (s > FlowDotMaxScale) s = FlowDotMaxScale;
				dot.scale = Vec3(s, s, s);
				dot.angleX = -90;
				root.addChild(dot);
				dots.push(dot);
			}
			if (dots.length === 0) continue;
			flowOrbits.push({ def, dots });
		}
		if (flowOrbits.length > 0) {
			print('[escape-velocity] flow dots: ' + flowOrbits.length.toFixed(0) + ' orbits x ' + FlowDotsPerOrbit.toFixed(0));
		}
	}

	// ---- 地球（家园锚点，会话 25 用户需求“游戏里需要添加一个地球”）----
	// 纯视觉：**不进 bodies**（无引力、不参与碰撞判定，L1–L6 的轨迹确定性不变）、
	// 不进相机取景点（Game.ts 的 fit 点只来自探测器与行星）。
	// 用自己的蓝绿配色、**不走关卡染色**——避免被误读成目标行星。
	if (options.home !== undefined) {
		const earth = Model3D('Assets/Model/Planet_Earth.glb');
		if (earth !== undefined) {
			const ke = modelRadius('Planet_Earth');
			const hr = options.homeRadius !== undefined ? options.homeRadius : 1.15;
			const es = hr / ke;
			earth.scale = Vec3(es, es, es);
			let emi = 0;
			while (emi < 64) {
				const em = earth.getMaterial(emi);
				if (em === undefined) break;
				em.baseColor = Color(110, 170, 235, 255);
				// 微弱的自发光：地球在画面下缘只露夜面，全黑会像洞（一点"蓝色弹珠"的暗示）
				em.emissive = Color3(0x0c1622);
				emi += 1;
			}
			earth.position = planeToWorld(options.home, 0);
			root.addChild(earth);
		}
	}

	// ---- 探测器（会话 25 拆分：身体 + 可独立旋转的天线）----
	// ⚠️ 引擎的 Node3D **不把 glTF 子节点暴露成可寻址节点**（Test/AntennaProbe 实测：
	//    children/eachChild/name 全部不可访问，hasChildren 恒 false），所以“大天线回头指向地球”
	//    只能靠**拆文件**：Probe_Body.glb（去掉天线）+ Probe_Antenna.glb（仅天线，转轴在文件原点）。
	//    两个文件都在 → 天线可绕转轴旋转；缺任何一个 → 回退单体（天线刚性，不影响玩法）。
	// 探测器（分体约定收在 createProbe 里，S3.3 开场复用同一份组装逻辑）
	const probe = createProbe(root, {
		scale: options.probeScale,
		probePath: options.probePath,
		bodyPath: options.probeBodyPath,
		antennaPath: options.probeAntennaPath,
		antennaPivotY: options.probeAntennaPivotY,
		bodyRadius: options.probeBodyRadius,
		atlasPath: options.probeAtlasPath,
	});
	if (probe === undefined) return undefined;
	const probeNode = probe.node;
	const antennaModel = probe.antenna;
	const probeRadius = probe.radius;

	// 机身当前的世界朝向（faceVelocity 维护；Aiming 态保持最后一次的值）
	let bodyYawDeg = 0;

	// ---- 星空背板（2026-09-25 用户拍板：方案 B「程序化星图贴图」，放弃 C2 星点壳）----
	// 素材、亮度旋钮与"每帧钉在视线前方"的理由都收在 createStarBackdrop 里（S3.3 开场复用同一份）。
	const backdrop = createStarBackdrop(root);

	// ---- 太阳光晕（S3.12）：一张朝向相机的自发光面片 ----
	// 引擎不做后处理，所以"发光"只能靠**自发光贴图 + 面片**（Assets/Image/glow.png 由
	// Test/gen_glow.py 生成）。配方与星空背板同源：baseColor 留黑、只吃 emissive；
	// 区别是这张要**混合**（alphaMode=Blend），否则会是一块黑方块盖住星空。
	// ⚠️ 只绕 Y 转（"圆筒式"朝向相机）—— 引擎的 Euler 次序没标定过，只转一个轴就不受次序影响；
	//    俯视造成的 Y 方向压缩用 1/cos(tilt) 在 scale 上补回来（见 syncBackdrop）。
	let glowNode: Model3D.Type | undefined = undefined;
	// `StarQuad.gltf` 是单位四边形（±0.5）⇒ scale **就是直径**。
	// 所以"光晕直径 = SunGlowScale × 恒星直径"要写成 scale = SunGlowScale × 半径 × 2。
	let glowScale = 0;
	if (hasStar && starWorld !== undefined) {
		glowScale = SunGlowScale * starRadius * 2;
		const glowPath = 'Assets/Model/StarQuad.gltf';
		if (Content.exist(glowPath)) {
			const glowModel = Model3D(glowPath);
			if (glowModel !== undefined) {
				const glowTex = Texture2D('Assets/Image/glow.png');
				const gl = glowModel.getMaterial(0);
				if (gl !== undefined && glowTex !== undefined) {
					gl.setBaseColorTexture(glowTex);
					gl.setEmissiveTexture(glowTex);
					gl.baseColor = Color(0, 0, 0, 255);
					gl.emissive = Color3(0xc8b898);
					gl.roughness = 1.0;
					gl.metallic = 0.0;
					gl.alphaMode = MaterialAlphaMode3D.Blend;
				}
				glowModel.scale = Vec3(glowScale, glowScale, glowScale);
				glowModel.position = starWorld;
				root.addChild(glowModel);
				glowNode = glowModel;
			}
		}
	}

	// ---- 同步函数 ----
	const syncBodies = (t: number): void => {
		for (const p of planets) {
			const wp = planeToWorld(bodyPositionAt(p.def, t), 0);
			p.body.position = wp;
			if (p.ring !== undefined) p.ring.position = wp;
		}
		// 沿轨道流动的光点（S3.16）：每帧只改 position。
		// 第 k 个光点的角 = 行星此刻的角 + k·2π/N（OrbitFlow.flowDotAngle，与 bodyPositionAt
		// 同一个式子）⇒ 方向 = orbitDirection、快慢 ∝ ω。t 就是 Game.ts 传下来的 tWorld
		// （= core.t0 + core.flightTime）—— 没有第二时间源，拨日期时行星与光点一起动。
		for (const fo of flowOrbits) {
			const c = orbitCenterAt(fo.def, t);
			const r = fo.def.orbitRadius;
			const n = fo.dots.length;
			for (let k = 0; k < n; k++) {
				const a = flowDotAngle(fo.def, t, k, n);
				fo.dots[k].position = Vec3(
					(c.x + r * Math.cos(a)) * PlaneToWorldX,
					0,
					(c.y + r * Math.sin(a)) * PlaneToWorldZ,
				);
			}
		}
	};

	const syncProbe = (p: P2): void => {
		probeNode.position = planeToWorld(p, 0);
		// 大天线“回头指向地球”（2026-09-25 用户需求）：
		// 目标法线 = 从“朝上”向地球方向倾斜（倾角随距离渐入——刚出发距离≈0，不倾）；
		// 方位角在**机身本地系**里算（机身自己会被 faceVelocity 转到速度方向）。
		// Euler 次序（angleY 后 angleZ）按截图标定；若天线倾倒方向不随位置变，说明次序反了。
		if (antennaModel !== undefined && options.home !== undefined) {
			pointAntenna(antennaModel, p, options.home, bodyYawDeg);
		}
	};

	// 需要让探测器朝速度方向：绕世界 Y 轴旋转。
	// 世界方向 (dx, 0, dz) 对应角度 atan2(-dz, dx)（已用旧 Probe.gltf 实测标定）。
	// 模型自身“朝前的轴”不是 +X 时用 ProbeYawOffsetDeg 补正（见其注释）。
	const faceVelocity = (v: P2): void => {
		const yaw = probeYawForVelocity(v);
		if (yaw === undefined) return;
		bodyYawDeg = yaw;
		probeNode.angleY = bodyYawDeg;
	};

	// 每帧把背板钉到「相机视线前方 BackdropDist」处（eye/target 来自机架当前帧；理由见背板注释）
	const syncBackdrop = (eye: Vec3.Type, target: Vec3.Type): void => {
		if (backdrop !== undefined) backdrop.sync(eye, target);
		// 光晕面片：绕 Y 转到"正对相机"，再把俯视压缩补回 Y 方向
		if (glowNode !== undefined && starWorld !== undefined) {
			const dx = eye.x - starWorld.x;
			const dy = eye.y - starWorld.y;
			const dz = eye.z - starWorld.z;
			if (Math.abs(dx) > 1e-6 || Math.abs(dz) > 1e-6) {
				glowNode.angleY = (Math.atan2(dx, dz) * 180) / Math.PI;
			}
			// 相机越俯视，世界 Y 在屏幕上被压得越扁 ⇒ 把面片的 Y 拉长补回来（夹在 1~2.2）
			const flat = Math.sqrt(dy * dy + dz * dz);
			const tilt = flat > 1e-6 ? Math.atan2(Math.abs(dy), flat) : 0;
			const c = Math.cos(tilt);
			const stretch = c > 0.45 ? 1 / c : 2.2;
			glowNode.scale = Vec3(glowScale, glowScale * stretch, glowScale);
		}
	};

	// 初始化到 t=0 的姿态
	syncBodies(0);
	syncProbe(probeStart);

	return {
		syncBodies,
		syncProbe,
		faceVelocity,
		syncBackdrop,
		probe: probeNode,
		antenna: antennaModel,
		planets,
		probeRadius,
	};
}
