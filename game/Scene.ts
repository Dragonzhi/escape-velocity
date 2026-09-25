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
 * - 地球：家园锚点（纯视觉，不进物理），大天线的指向目标。
 * - 星空：一张程序化星图贴在贴着相机的四边形背板上（方案 B，2026-09-25 用户拍板；
 *   每帧由 syncBackdrop 钉到视线前方），见 buildScene 内注释。
 */
import { Color, Color3, Content, DirectionalLight3D, Model3D, Node3D, Texture2D, Vec3 } from 'Dora';
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

/**
 * 天线转轴在探测器本地系的位置（y，模型单位）。
 * 取自拆分前单体文件里 Probe_Antenna 空物体的 translation（建模把它放在碟面背面与
 * 支撑腿的汇交点）。天线文件按"转轴 = 原点"导出，游戏把天线模型放到本常量 × scale 处。
 */
const AntennaPivotY = 0.20;

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
	/** 探测器**身体**文件（去掉天线）。与 probeAntennaPath 同时给出才启用分体。 */
	probeBodyPath?: string;
	/** 探测器**天线**文件（仅 8 个天线零件，转轴在文件原点）。 */
	probeAntennaPath?: string;
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

/**
 * 构建场景。
 *
 * @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
 */
export function buildScene(options: SceneOptions): GameScene | undefined {
	const { root, bodies, visuals, probeStart } = options;

	// ---- 光源：一盏方向光（愿景 §6）----
	// ⚠️ 晨昏线（2026-09-25 用户反馈“行星没有晨昏线”）：光的**方位角必须与相机视线错开**——
	// 相机沿 -Z 俯视，若光也大致从 +Z 侧照过来，亮面正对镜头，只剩边缘渐变、看不出明暗界线。
	// angleY 转到 ~75°（从画面侧面来光）+ 环境光压到 0.12（init.ts），暗面才沉得下去。
	// 符号/角度按截图标定（教程基准 angleX=-48/angleY=-35 的同族取值）。
	const light = DirectionalLight3D();
	light.color = Color3(0xfff3da);
	light.intensity = 3.6;
	light.angleX = -42;
	light.angleY = 75;
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

	// ---- 地球（家园锚点，会话 25 用户需求“游戏里需要添加一个地球”）----
	// 纯视觉：**不进 bodies**（无引力、不参与碰撞判定，L1–L6 的轨迹确定性不变）、
	// 不进相机取景点（Game.ts 的 fit 点只来自探测器与行星）。
	// 用自己的蓝绿配色、**不走关卡染色**——避免被误读成目标行星。
	if (options.home !== undefined) {
		const earth = Model3D('Assets/Model/Planet_Earth.glb');
		if (earth !== undefined) {
			const ke = modelRadius('Planet_Earth');
			const es = 1.15 / ke;
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
	const probeScale = options.probeScale;
	// ⚠️ Model3D 对**不存在的文件**不是返回 nil 而是**抛运行时错误**（"can not locate full path"
	//    → Object::createNotNull failed，实测把整个建关流程炸掉、画面全黑）——
	//    所以"可选资产"必须先用 Content.exist 守卫，绝不能拿 Model3D 的返回值做存在性判断。
	const bodyModel = options.probeBodyPath !== undefined && Content.exist(options.probeBodyPath)
		? Model3D(options.probeBodyPath)
		: undefined;
	const antennaModel = bodyModel !== undefined && options.probeAntennaPath !== undefined && Content.exist(options.probeAntennaPath)
		? Model3D(options.probeAntennaPath)
		: undefined;
	const singleModel = bodyModel === undefined ? Model3D(options.probePath) : undefined;
	if (bodyModel === undefined && singleModel === undefined) return undefined;

	const probeNode = Node3D();
	root.addChild(probeNode);

	if (bodyModel !== undefined) {
		bodyModel.scale = Vec3(probeScale, probeScale, probeScale);
		probeNode.addChild(bodyModel);
	}
	if (singleModel !== undefined) {
		singleModel.scale = Vec3(probeScale, probeScale, probeScale);
		probeNode.addChild(singleModel);
	}

	// 天线挂在**枢轴节点**下：枢轴位于转轴处（模型本地 (0, AntennaPivotY, 0)）。
	// 转枢轴 = 天线绕转轴摆动；机身的 angleY 由 probeNode 承担，子节点自动跟随。
	let antennaPivot: Node3D.Type | undefined = undefined;
	if (bodyModel !== undefined && antennaModel !== undefined) {
		antennaModel.scale = Vec3(probeScale, probeScale, probeScale);
		antennaPivot = Node3D();
		antennaPivot.position = Vec3(0, AntennaPivotY * probeScale, 0);
		antennaPivot.addChild(antennaModel);
		probeNode.addChild(antennaPivot);
	}

	// 取景用：探测器的世界外接半径。
	// 相机只把关键点当**质点**，于是碟形天线会被画面边缘切掉（L3 实测踩过），
	// 所以把“探测器有体积”这一项也算进取景求解（见 game/CameraRig.ts 的 frameFits）。
	// 口径：**实测常数** —— 拆分前单体文件 AABB 最大边 3.227（碟面直径，ModelCalibProbe 标定），
	// 半长 × scale × 1.1。拆分后身体/天线各自的包围盒都不完整，不再逐文件量；
	// 不取外接球：两根吊杆沿飞行轴伸出（z -1.85…1.00），屏幕上不占宽度。
	const probeRadius = 0.5 * 3.227 * probeScale * 1.1;

	// 机身当前的世界朝向（faceVelocity 维护；Aiming 态保持最后一次的值）
	let bodyYawDeg = 0;

	// ---- 星空背板（2026-09-25 用户拍板：方案 B「程序化星图贴图」，放弃 C2 星点壳）----
	// 素材全部由 Test/gen_star_assets.py 代码生成：Assets/Image/starfield.png（1024×1024）
	// + Assets/Model/StarQuad.gltf（顶点 ±1 ⇒ **scale = 半边长**；材质自带 doubleSided）。
	// 相比 C2：72 KB vs 180 KB、2 三角面 vs 1940、软圆点 vs 横屏下的白色方块/菱形。
	// 项目约束相应放宽：「零贴图」→「素材全部由本仓库代码生成，不引入第三方素材」。
	//
	// 为什么每帧贴着相机放（见下方 syncBackdrop）：相机距离在 [25,100] 内随包围盒变化、注视点也会移动，
	// 固定位置的背板会被移出画面或露出边缘；钉在「视线前方 600」相当于把星空放在无穷远（无视差），
	// 任何距离/宽高比下都正好铺满（半边长 560 > 需求 600·tan(fov/2)·1.645 ≈ 490）。
	// 远裁剪面实测 >2000（Test/FarPlaneProbe，2026-09-25；早前“z=-900 不可见”的结论是误报）。
	const BackdropDist = 600;
	const BackdropHalf = 560;
	let backdropNode: Model3D.Type | undefined = undefined;
	const backdrop = Model3D('Assets/Model/StarQuad.gltf');
	if (backdrop !== undefined) {
		const tex = Texture2D('Assets/Image/starfield.png');
		const bm = backdrop.getMaterial(0);
		if (bm !== undefined && tex !== undefined) {
			// ⚠️ 星空**不吃光照**：只走 emissive 槽（baseColor 留黑），总亮度 = emissive 一个旋钮。
			// 首版双槽全白 = 贴图亮度 ×2，用户反馈“喧宾夺主”后压到 ~55%（0x8c）。
			bm.setEmissiveTexture(tex);
			bm.baseColor = Color(0, 0, 0, 255);
			bm.emissive = Color3(0x8c8c8c);
			bm.roughness = 1.0;
			bm.metallic = 0.0;
		}
		backdrop.scale = Vec3(BackdropHalf, BackdropHalf, BackdropHalf);
		// 相机从斜上方俯视：把四边形绕 X 转到⊥视线。符号 -45 是按右手系推的——
		// 首次截图必须确认背板真的铺满画面；若只见一条细缝就是转成了 90°，翻成 +45。
		backdrop.angleX = -45;
		backdrop.position = Vec3(0, 0, -BackdropDist);
		root.addChild(backdrop);
		backdropNode = backdrop;
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
		// 大天线“回头指向地球”（2026-09-25 用户需求）：
		// 目标法线 = 从“朝上”向地球方向倾斜（倾角随距离渐入——刚出发距离≈0，不倾）；
		// 方位角在**机身本地系**里算（机身自己会被 faceVelocity 转到速度方向）。
		// Euler 次序（angleY 后 angleZ）按截图标定；若天线倾倒方向不随位置变，说明次序反了。
		if (antennaPivot !== undefined && options.home !== undefined) {
			const ex = (options.home.x - p.x) * PlaneToWorldX;
			const ez = (options.home.y - p.y) * PlaneToWorldZ;
			const dist = Math.sqrt(ex * ex + ez * ez);
			if (dist > 1e-4) {
				let tiltFactor = (dist - 0.5) / 3.0;
				if (tiltFactor < 0) tiltFactor = 0;
				if (tiltFactor > 1) tiltFactor = 1;
				const tilt = 46 * tiltFactor;
				const phiWorld = Math.atan2(-ez, ex) * 180 / Math.PI;
				antennaPivot.angleY = phiWorld - bodyYawDeg;
				antennaPivot.angleZ = -tilt;
			}
		}
	};

	// 需要让探测器朝速度方向：绕世界 Y 轴旋转。
	// 世界方向 (dx, 0, dz) 对应角度 atan2(-dz, dx)（已用旧 Probe.gltf 实测标定）。
	// 模型自身“朝前的轴”不是 +X 时用 ProbeYawOffsetDeg 补正（见其注释）。
	const faceVelocity = (v: P2): void => {
		const wx = v.x * PlaneToWorldX;
		const wz = v.y * PlaneToWorldZ;
		if (wx * wx + wz * wz < 1e-12) return;
		bodyYawDeg = Math.atan2(-wz, wx) * 180 / Math.PI + ProbeYawOffsetDeg;
		probeNode.angleY = bodyYawDeg;
	};

	// 每帧把背板钉到「相机视线前方 BackdropDist」处（eye/target 来自机架当前帧；理由见上方背板注释）
	const syncBackdrop = (eye: Vec3.Type, target: Vec3.Type): void => {
		if (backdropNode === undefined) return;
		const dx = target.x - eye.x;
		const dy = target.y - eye.y;
		const dz = target.z - eye.z;
		const len = Math.sqrt(dx * dx + dy * dy + dz * dz);
		if (len < 1e-6) return;
		const s = BackdropDist / len;
		backdropNode.position = Vec3(eye.x + dx * s, eye.y + dy * s, eye.z + dz * s);
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
