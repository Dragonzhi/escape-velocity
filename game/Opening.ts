/**
 * 开场分镜（S3.3）：太阳系全景 → 相机俯冲聚焦到地球旁**已入轨**的探测器 → 交还选关。
 *
 * ===== 分镜（用户 2026-09-25 口述定稿）=====
 *   ① 全景  ：太阳居中，七颗行星沿虚线轨道排开成一条螺旋「航线」，相机缓慢环绕。
 *   ② 聚焦  ：相机从全景俯冲下去，落到地球旁边已成轨道的探测器上（探测器在绕地球转圈，
 *              大天线始终回头指着地球——与关卡内同一份算式）。
 *   ③ 交还  ：全屏任意处轻触即跳过；播完（或跳过）后交还选关，此后相机**缓缓拉回全景**，
 *              当作选关界面的活背景（路线图的雏形）。
 *
 * ===== 为什么单独一个模块 =====
 * - 时间线与机位是**帧号的纯函数**（openingBlend / openingPose / probeOrbitPos），
 *   可以脱离引擎对象在 Test/OpeningTest.ts 里逐帧断言，不必靠肉眼；
 * - 开场是一次性的过场，与关卡运行时（Game/Scene/CameraRig）零共享状态：
 *   唯一复用的是资产构造（createStarBackdrop / createProbe / modelRadius / pointAntenna）。
 *
 * ===== 踩过的坑（沿用关卡侧结论，别再踩）=====
 * - 每帧旋转**普通空 Node3D 容器**会触发引擎堆损坏（0xc0000374）→ 探测器根节点只写
 *   angleY（单分量，关卡侧实测稳定），天线走 pointAntenna 直接转 Model3D 节点；
 * - 全屏触摸层隐藏时**必须同时断掉 touchEnabled**（swallowTouches 会独占整屏）；
 * - onTapBegan/onTapEnded 注册时会把 touchEnabled 置回 true ⇒ 开关写在注册之后；
 * - Model3D 对不存在的文件**抛错**，可选资产一律先 Content.exist 守卫。
 */
import { Camera3D, Color, Color3, Content, DirectionalLight3D, Label, Material3D, Model3D, Node, Node3D, Path, PointLight3D, Size, Vec2, Vec3 } from 'Dora';
import { P2 } from 'game/Gravity';
import { ProbeHandle, applyPlanetTexture, createProbe, createStarBackdrop, modelRadius, planeToWorld, pointAntenna, probeYawForVelocity } from 'game/Scene';
import { colorFromHex, createLabel, setLabelCenter } from 'game/Ui';

const DegToRad = Math.PI / 180;

// ---- 时间线（帧；引擎固定步长 60 fps ⇒ 540 帧 ≈ 9 秒）----
/** 全景时长。 */
export const WideFrames = 170;
/** 俯冲聚焦时长。 */
export const FocusFrames = 260;
/** 聚焦后的停留时长（探测器继续绕地球转）。 */
export const HoldFrames = 110;
/** 开场总帧数：到这一帧交还选关。 */
export const TotalFrames = WideFrames + FocusFrames + HoldFrames;
/** 交还选关后，相机拉回全景所用的帧数。 */
export const PullBackFrames = 240;

// ---- 机位（世界单位 / 度）----
/** 全景时的相机距离：刚好装下最外圈（海王星轨道 55 → 竖屏半宽 0.2335·d ⇒ d ≈ 235，留一点余量）。 */
const WideDist = 245;
const WideTiltDeg = 42;
const WideAzDeg = 18;
/**
 * 聚焦时的相机距离：装下「地球 + 轨道上的探测器」（轨道 3.0 + 探测器半径 ~0.7）。
 * 竖屏半宽 = 0.2335·d；探测器轨道 4.6 要留在画面内 ⇒ d ≥ 20（取 22）：
 * 地球在画面里约 260 px 直径，探测器在 4.6 单位外的轨道上绕行、始终在框内。
 */
const CloseDist = 22;
const CloseTiltDeg = 20;
/**
 * 特写的方位角：与「地球 → 太阳」方向**差约 90° 的侧后方**，太阳因此完全在画面外，
 * 地球呈半明半暗（晨昏线正好对着镜头）。orbitEye 的平面方位 = 90° − az；
 * 地球轨道方位 262°、日地方位 82° ⇒ 取相机水平方位 156° ⇒ az = 278°。
 * （首版取 56°、次版取 188° 时太阳都压在画面左下角抢戏——2026-09-26 截图实测。）
 */
const CloseAzDeg = 278;
/** 方位角漂移（度/帧）：全景与特写共用一个缓慢环绕速度，交叠时不打转。 */
const AzDriftDegPerFrame = 0.035;

/** 太阳半径（世界单位）。 */
const SunRadius = 4.8;

/** 探测器在开场里的缩放与轨道（比关卡内小一号：全景尺度下才协调）。 */
// S3.14：新机体最长轴 0.87（旧单体 3.227）⇒ 0.55 → 1.15 才是屏幕上同样的尺寸。
export const ProbeScale = 1.15;
export const ProbeOrbitRadius = 4.6;
export const ProbeOrbitStartDeg = 40;
/** 探测器绕地球的公转角速度（度/帧）——540 帧转约 297°，看得见「在轨」。 */
export const ProbeOrbitDegPerFrame = 0.55;

/**
 * 轨道线改成 **3D 网格**（2026-09-26 用户第 4 条反馈）：
 * 2D 虚线永远画在 3D 之上，行星挡不住线（"线压在行星上"）；烘成网格后由深度缓冲决定遮挡。
 * 资产 = Assets/Model/OrbitRings.gltf（八条轨道一个 mesh，1 draw call，
 * 半径与世界单位一致 ⇒ 不做缩放；由 Test/gen_orbit_assets.py 从本文件的 Stations 解析生成）。
 */
const OrbitRingsPath = 'Assets/Model/OrbitRings.gltf';
/** 轨道线亮度（emissive 0xRRGGBB）。压暗过一版：用户反馈"线条过分明显"。 */
const OrbitRingsHex = 0x3f5f88;
/**
 * 混合系数超过它就**整条藏掉**轨道线。
 *
 * 为什么不能只"调暗"：环是不透明的网格（baseColor 黑 + emissive 亮），调暗只是让它变黑 ——
 * 贴脸时线宽会涨到几十像素，画面里就成了一根根**黑棍子**，比亮线更糟（实测截图）。
 * 全景/拉回段看得到，俯冲进特写就收起来（它是"地图"元素，不是场景元素）。
 */
const OrbitRingsHideBlend = 0.45;

/**
 * 全景里的一站（= 一条轨道 + 一颗行星）。
 *
 * 航线与关卡重主题后的走法一致：地球 → 金星 → 木星 → 土星 → 天王星 → 海王星
 * （金星在地球内圈——第二关是「向内」的弹弓）。火星只作点缀，不挂关卡。
 */
export interface OpeningStation {
	/** 模型名（不含路径与扩展名）。 */
	model: string;
	/** 显示半径（世界单位）。 */
	radius: number;
	/** 轨道半径（平面单位）。 */
	orbit: number;
	/** 初始方位角（度）。 */
	angleDeg: number;
	/** 染色（0xRRGGBB）。 */
	colorHex: number;
	/** 自发光（0xRRGGBB）；0 = 不吃自发光。 */
	emissiveHex: number;
}

/** 地球在 Stations 里的下标（聚焦目标）。 */
export const EarthStationIndex = 2;

export const Stations: OpeningStation[] = [
	// 水星（2026-09-26 用户："水星怎么不见了"）：模型库里**没有** Planet_Mercury，
	// 用代码生成的单位球 Sphere.gltf 染成灰色 —— 它在全景里只有 ~9 px，光滑灰球足够。
	{ model: 'Sphere', radius: 0.85, orbit: 7.5, angleDeg: 340, colorHex: 0x9a8f86, emissiveHex: 0 },
	// ⚠️ 金星的角度按**特写机位**定：机位在地球背光侧约 (-12,-12) 处，
	// 原先 205°（金星在该方向的延长线上）会让它在特写里只有 9.7 单位远、占掉半个屏幕（实测截图）。
	{ model: 'Planet_Venus', radius: 1.60, orbit: 11.5, angleDeg: 300, colorHex: 0xf0dcae, emissiveHex: 0 },
	// 地球：特写里是主角，自发光比关卡里那版略亮（正交光方向固定，夜面太黑会看不出是地球）
	{ model: 'Planet_Earth', radius: 2.20, orbit: 17.0, angleDeg: 262, colorHex: 0x5b9be0, emissiveHex: 0 },
	{ model: 'Planet_Mars', radius: 1.50, orbit: 22.5, angleDeg: 318, colorHex: 0xd07f4a, emissiveHex: 0 },
	{ model: 'Planet_Jupiter', radius: 4.60, orbit: 30.0, angleDeg: 12, colorHex: 0xe0c092, emissiveHex: 0 },
	// 土星环是模型自带的（外径 ≈ 本体 2.24 倍）⇒ 本体 3.2 时环外径 7.2，
	// 轨道取 38.5 让环正好落在木星(30)与天王星(47)之间，不压邻轨。
	{ model: 'Planet_Saturn', radius: 3.20, orbit: 38.5, angleDeg: 68, colorHex: 0xd3c49a, emissiveHex: 0 },
	{ model: 'Planet_Uranus', radius: 2.00, orbit: 47.0, angleDeg: 124, colorHex: 0xa8dde4, emissiveHex: 0 },
	{ model: 'Planet_Neptune', radius: 1.90, orbit: 55.0, angleDeg: 180, colorHex: 0x7b95f0, emissiveHex: 0 },
];

/** 一站所在的平面坐标。下标越界返回原点（调用方不必再判空）。 */
export function stationPlane(index: number): P2 {
	if (index < 0 || index >= Stations.length) return { x: 0, y: 0 };
	const st = Stations[index];
	const a = st.angleDeg * DegToRad;
	return { x: Math.cos(a) * st.orbit, y: Math.sin(a) * st.orbit };
}

function smoothstep(t: number): number {
	const u = t < 0 ? 0 : (t > 1 ? 1 : t);
	return u * u * (3 - 2 * u);
}

function lerp3(a: Vec3.Type, b: Vec3.Type, k: number): Vec3.Type {
	return Vec3(a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k, a.z + (b.z - a.z) * k);
}

/** 绕注视点的一圈机位：方位角 az、俯角 tilt、距离 dist。 */
function orbitEye(focus: P2, dist: number, tiltDeg: number, azDeg: number): Vec3.Type {
	const target = planeToWorld(focus, 0);
	const tilt = tiltDeg * DegToRad;
	const az = azDeg * DegToRad;
	const horiz = Math.cos(tilt) * dist;
	return Vec3(
		target.x + Math.sin(az) * horiz,
		target.y + Math.sin(tilt) * dist,
		target.z + Math.cos(az) * horiz,
	);
}

/**
 * 全景 ↔ 特写的混合系数（纯函数）：
 *   0 = 全景（太阳系全貌）→ 1 = 特写（地球旁的探测器）→ 交还选关后缓缓退回 0（全景）。
 */
export function openingBlend(frame: number): number {
	if (frame <= WideFrames) return 0;
	if (frame < WideFrames + FocusFrames) return smoothstep((frame - WideFrames) / FocusFrames);
	if (frame <= TotalFrames) return 1;
	const back = (frame - TotalFrames) / PullBackFrames;
	return back >= 1 ? 0 : 1 - smoothstep(back);
}

/** 开场相态。 */
export type OpeningPhase = 'wide' | 'focus' | 'hold' | 'pullback' | 'off';

/** 第 frame 帧所处的相态（纯函数，供日志与测试断言）。 */
export function openingPhase(frame: number): OpeningPhase {
	if (frame < 0) return 'off';
	if (frame < WideFrames) return 'wide';
	if (frame < WideFrames + FocusFrames) return 'focus';
	if (frame <= TotalFrames) return 'hold';
	return 'pullback';
}

/** 一帧的相机参数。 */
export interface OpeningPose {
	eye: Vec3.Type;
	target: Vec3.Type;
}

/** 第 frame 帧的机位（纯函数；earth = 聚焦目标在地球轨道上的平面坐标）。 */
export function openingPose(frame: number, earth: P2): OpeningPose {
	const k = openingBlend(frame);
	const az = AzDriftDegPerFrame * frame;
	const wideEye = orbitEye({ x: 0, y: 0 }, WideDist, WideTiltDeg, WideAzDeg + az);
	const closeEye = orbitEye(earth, CloseDist, CloseTiltDeg, CloseAzDeg + az);
	return {
		eye: lerp3(wideEye, closeEye, k),
		target: lerp3(planeToWorld({ x: 0, y: 0 }, 0), planeToWorld(earth, 0), k),
	};
}

/** 第 frame 帧探测器在地球轨道上的平面位置（纯函数）。 */
export function probeOrbitPos(frame: number, earth: P2): P2 {
	const a = (ProbeOrbitStartDeg + frame * ProbeOrbitDegPerFrame) * DegToRad;
	return { x: earth.x + Math.cos(a) * ProbeOrbitRadius, y: earth.y + Math.sin(a) * ProbeOrbitRadius };
}

/** 第 frame 帧探测器的平面速度（轨道切线；纯函数）。 */
export function probeOrbitVel(frame: number): P2 {
	const a = (ProbeOrbitStartDeg + frame * ProbeOrbitDegPerFrame) * DegToRad;
	const v = ProbeOrbitRadius * ProbeOrbitDegPerFrame * DegToRad;
	return { x: -Math.sin(a) * v, y: Math.cos(a) * v };
}

// ---- 开场「已看过」标记（首次启动完整播，之后直接进选关）----
/** 标记文件名（相对 Content.writablePath）。文件存在 = 看过；内容无所谓。 */
export const IntroFlagFileName = 'escape-velocity.intro';
/** 标记文件绝对路径。 */
export function introFlagPath(): string {
	return Path(Content.writablePath, IntroFlagFileName);
}
/** 是否已经看过开场（存档语义就是「文件在不在」）。 */
export function loadIntroSeen(): boolean {
	return Content.exist(introFlagPath());
}
/** 记下「看过开场」。 */
export function saveIntroSeen(): void {
	Content.save(introFlagPath(), 'seen=1');
}

/** 开场选项。 */
export interface OpeningOptions {
	/** 3D 根（调用方负责 addChild 到 Director.entry）。 */
	root: Node3D.Type;
	/** 开场相机（调用方负责 pushCamera）。 */
	camera: Camera3D.Type;
	/** 2D 层（调用方负责**建在 UI 叠层之下**：轨道线/文案/跳过层都挂这里）。 */
	layer: Node.Type;
	viewW: number;
	viewH: number;
	/** 垂直视野角与宽高比（View.fieldOfView / View.aspectRatio）——投影必须与渲染一致。 */
	fovYDeg: number;
	aspect: number;
	probePath: string;
	probeBodyPath?: string;
	probeAntennaPath?: string;
	/** 代码生成单位球的路径（回退模型；水星用它）。省略按 Assets/Model/Sphere.gltf。 */
	spherePath?: string;
	/** 开场结束（自然播完或跳过）时回调一次。 */
	onFinish: () => void;
}

/**
 * 开场句柄。
 *
 * @noSelf
 */
export interface Opening {
	/** 从头播完整开场。 */
	start(): void;
	/** 每帧推进（主循环调用）。 */
	step(): void;
	/** 跳过（等价于「立刻播完」）。 */
	skip(): void;
	/** 当前帧号（-1 = 还没开始）。 */
	frameIndex(): number;
	/** 当前相态。 */
	phase(): OpeningPhase;
	/** 是否还在场（含「播完但全景留着当背景」的 idle 态）。 */
	running(): boolean;
	/** 只留全景当背景（不播文案、不吃触摸）——视口重建后恢复选关背景用。 */
	idle(): void;
	/** 整体隐藏（视口重建 / 进关卡时）。 */
	hide(): void;
}

const TitleHex = 0xeaf4ff;
const SubtitleHex = 0x9fc4e8;
const TaglineHex = 0x6f88a6;
const NarrationHex = 0xd7e6f7;
const SkipHex = 0x7d93ab;

function clampNumber(value: number, lo: number, hi: number): number {
	if (value < lo) return lo;
	if (value > hi) return hi;
	return value;
}


/** 淡入淡出窗口：返回某一帧的不透明度（0–1）。 */
function fadeWindow(f: number, inStart: number, inEnd: number, outStart: number, outEnd: number): number {
	if (f < inStart) return 0;
	if (f < inEnd) return smoothstep((f - inStart) / (inEnd - inStart));
	if (f < outStart) return 1;
	if (f < outEnd) return 1 - smoothstep((f - outStart) / (outEnd - outStart));
	return 0;
}

function hideLabel(label: Label.Type | undefined): void {
	if (label !== undefined) label.visible = false;
}

function applyAlpha(label: Label.Type | undefined, colorHex: number, alpha: number): void {
	if (label === undefined) return;
	const on = alpha > 0.01;
	label.visible = on;
	if (on) label.color = colorFromHex(colorHex, alpha);
}

/** 建立开场（只建一次场景；播放由 start 驱动）。 */
export function createOpening(options: OpeningOptions): Opening {
	const viewW = options.viewW;
	const viewH = options.viewH;
	const root = options.root;
	const layer = options.layer;

	// 每次实例化都建一个**自己的**子容器：视口重建时要能整块丢掉旧实例
	// （旧文字/DrawNode 若还挂在同一个容器上，新实例 start() 会把它们一起显示出来）。
	// 容器本身留在永久的 openingLayer 下 ⇒ 层级永远在选关/结算面板**之下**（不能后插整层，
	// 因为 Director.ui 的子节点顺序 = 绘制顺序，后插的层会盖住面板）。
	const ui = Node();
	ui.size = Size(options.viewW, options.viewH);
	ui.anchor = Vec2(0, 0);
	ui.position = Vec2(0, 0);
	layer.addChild(ui);

	// ---- 光照：**放在太阳位置的点光源**（2026-09-26 用户拍板）----
	// 方向光在这里是错的：晨昏线方向与太阳位置无关，特写里的地球会出现"夜面朝着太阳"这种硬伤。
	// 点光源从原点（太阳）向外照 ⇒ 每颗行星的晨昏线都自然朝外。
	// 关卡里没有太阳这个实体，所以那边仍旧用方向光（Scene.ts），两边不必一致。
	const sunLight = PointLight3D();
	sunLight.color = Color3(0xfff3da);
	sunLight.intensity = 0; // 每帧按混合系数给（见 updateWorld）
	sunLight.range = 600;
	sunLight.position = Vec3(0, 0, 0);
	root.addChild(sunLight);

	// 全景段的均匀补光：点光源有距离衰减，外圈（海王星轨道 55）会明显比内圈暗，
	// 宽景看起来就是"外面几颗发黑"。所以两盏灯**交叉淡入**：
	// 全景（blend 0）= 方向光为主（均匀、可读），俯冲进特写（blend 1）= 太阳点光源为主（晨昏线正确）。
	// 底光 0.9 一直留着，避免过渡中间出现"全黑一瞬"。
	const fillLight = DirectionalLight3D();
	fillLight.color = Color3(0xfff3da);
	fillLight.intensity = 3.6;
	fillLight.angleX = -42;
	fillLight.angleY = 75;
	root.addChild(fillLight);

	// ---- 星空背板（与关卡同一份材质与亮度旋钮）----
	const backdrop = createStarBackdrop(root);

	// ---- 太阳 + 七站行星 ----
	const sun = Model3D('Assets/Model/Sun.glb');
	if (sun !== undefined) {
		sun.scale = Vec3(SunRadius, SunRadius, SunRadius);
		// S3.14：太阳走 sun.jpg（既当 baseColor 又当 emissive，乘数满值）——
		// 以前这里是一块纯色，现在有表面细节与边缘变暗。
		applyPlanetTexture(sun, 'Sun', 0, 0);
		root.addChild(sun);
	}

	// ---- 分帧建：八颗行星 + 分体探测器不是一次性加载 ----
	// 为什么（2026-09-26 用户第 3 条反馈：**第一次播会卡，重看就顺**）：一次性 Model3D 建 9 个网格
	// 会在开场头几帧里阻塞（磁盘 + 材质/着色器首次编译），重看时引擎已缓存所以不卡。
	// 摊到开场头十几帧（≈0.25s，正好在标题淡入、行星还只有几个像素的时候）就看不出来了。
	const spherePath = options.spherePath !== undefined ? options.spherePath : 'Assets/Model/Sphere.gltf';
	const buildQueue: (() => void)[] = [];
	for (let i = 0; i < Stations.length; i++) {
		const st = Stations[i];
		const p = stationPlane(i);
		buildQueue.push((): void => {
			// 水星没有专用资产，用代码生成的单位球（Sphere.gltf）
			const model = Model3D(st.model === 'Sphere' ? spherePath : 'Assets/Model/' + st.model + '.glb');
			if (model === undefined) {
				print('[escape-velocity] opening model MISSING: ' + st.model);
				return;
			}
			const scale = st.radius / modelRadius(st.model);
			model.scale = Vec3(scale, scale, scale);
			// S3.14：有交付贴图的行星走贴图（S3.14 交付了全部行星的 UV + 贴图），
			// 没有贴图的（水星那个回退球）继续走 colorHex。
			applyPlanetTexture(model, st.model, st.colorHex, st.emissiveHex);
			model.position = planeToWorld(p, 0);
			root.addChild(model);
		});
	}

	// ---- 轨道线：3D 网格（行星能挡住它；见 OrbitRingsPath 注释）----
	let rings: Model3D.Type | undefined = undefined;
	if (Content.exist(OrbitRingsPath)) {
		rings = Model3D(OrbitRingsPath);
		if (rings !== undefined) {
			const rm = rings.getMaterial(0);
			if (rm !== undefined) {
				rm.baseColor = Color(0, 0, 0, 255);
				rm.emissive = Color3(OrbitRingsHex);
			}
			root.addChild(rings);
		}
	}

	// ---- 探测器（分体约定与关卡一致）——排在队尾，最后建 ----
	let probe: ProbeHandle | undefined = undefined;
	buildQueue.push((): void => {
		probe = createProbe(root, {
			// 开场固定用**太阳能板版** —— 它就停在地球旁边，与 L1–L3 同一台（木星以外才换 RTG）。
			scale: ProbeScale,
			probePath: options.probePath,
			bodyPath: 'Assets/Model/Probe_Solar_Body.glb',
			antennaPath: 'Assets/Model/Probe_Solar_Antenna.glb',
			antennaPivotY: 0.6495,
			bodyRadius: 1.084,
			atlasPath: 'Assets/Image/probe_atlas.jpg',
		});
	});

	// ---- 2D：文案 + 跳过层 ----

	const titleSize = Math.round(clampNumber(viewH * 0.085, 54, 104));
	const taglineSize = Math.round(clampNumber(viewH * 0.028, 22, 34));
	const titleY = viewH * 0.63;
	const title = createLabel(ui, '单程', titleSize, TitleHex);
	setLabelCenter(title, viewW / 2, titleY);
	const subtitle = createLabel(ui, 'ESCAPE VELOCITY', taglineSize, SubtitleHex);
	setLabelCenter(subtitle, viewW / 2, titleY - titleSize * 0.95);
	const tagline = createLabel(ui, '一次没有返程的旅行', taglineSize, TaglineHex);
	setLabelCenter(tagline, viewW / 2, titleY - titleSize * 0.95 - taglineSize * 1.8);
	const narration = createLabel(ui, '地球轨道上，最后一次告别', taglineSize, NarrationHex);
	setLabelCenter(narration, viewW / 2, viewH * 0.26);
	const skip = createLabel(ui, '轻触跳过', taglineSize, SkipHex);
	setLabelCenter(skip, viewW / 2, clampNumber(viewH * 0.06, 34, 88));

	// 全屏跳过层：只有它在播的时候吃触摸（隐藏时必须断掉 touchEnabled）
	const skipLayer = Node();
	skipLayer.size = Size(viewW, viewH);
	skipLayer.anchor = Vec2(0, 0);
	skipLayer.position = Vec2(0, 0);
	skipLayer.swallowTouches = true;
	skipLayer.touchEnabled = true;
	ui.addChild(skipLayer);

	// 资产诊断：缺件时开场不会崩（都有回退），但日志要留痕
	print('[escape-velocity] opening assets: rings=' + (rings !== undefined ? 'ok' : 'MISSING')
		+ ' sky=' + (backdrop !== undefined ? 'ok' : 'MISSING'));

	const earth = stationPlane(EarthStationIndex);

	let mode: 'off' | 'intro' | 'idle' = 'off';
	let frame = -1;
	let bodyYawDeg = 0;

	// 轨道线材质的取用口。
	// 行星/探测器是**分帧建**的（见上方 buildQueue）：赋值发生在闭包里，TS 的控制流分析
	// 会以为外层 probe 恒为 undefined（narrowing 成 never）⇒ 取用一律走这个函数。
	const probeNow = (): ProbeHandle | undefined => probe;

	/** 把某一帧的世界状态摆好。 */
	const updateWorld = (f: number): void => {
		const hp = probeNow();
		if (hp !== undefined) {
			const p = probeOrbitPos(f, earth);
			hp.node.position = planeToWorld(p, 0);
			const yaw = probeYawForVelocity(probeOrbitVel(f));
			if (yaw !== undefined) {
				bodyYawDeg = yaw;
				hp.node.angleY = yaw;
			}
			if (hp.antenna !== undefined) pointAntenna(hp.antenna, p, earth, bodyYawDeg);
		}

		const pose = openingPose(f, earth);
		options.camera.lookAt(pose.eye, pose.target, Vec3(0, 1, 0));
		if (backdrop !== undefined) backdrop.sync(pose.eye, pose.target);

		// 两盏灯的交叉淡入（理由见 sunLight / fillLight 的注释）
		const k = openingBlend(f);
		fillLight.intensity = 3.6 * (1 - k) + 0.9;
		sunLight.intensity = 90 * k * k;

		// 轨道线：俯冲进特写就整条收起（理由见 OrbitRingsHideBlend）
		if (rings !== undefined) rings.visible = k < OrbitRingsHideBlend;
	};

	/** 文案的呼吸节奏（帧号写死在这里 = 分镜表）。 */
	const updateLabels = (f: number): void => {
		// idle 态只当背景：文案一律不显示
		if (mode === 'idle') {
			hideLabel(title);
			hideLabel(subtitle);
			hideLabel(tagline);
			hideLabel(narration);
			hideLabel(skip);
			return;
		}
		const outA = WideFrames - 10;
		const outB = WideFrames + 40;
		applyAlpha(title, TitleHex, fadeWindow(f, 14, 48, outA, outB));
		applyAlpha(subtitle, SubtitleHex, fadeWindow(f, 20, 54, outA, outB));
		applyAlpha(tagline, TaglineHex, fadeWindow(f, 26, 62, outA, outB));
		applyAlpha(narration, NarrationHex,
			fadeWindow(f, WideFrames + 70, WideFrames + 130, TotalFrames - 70, TotalFrames - 10));
		applyAlpha(skip, SkipHex, fadeWindow(f, 60, 100, TotalFrames - 40, TotalFrames + 10));
	};

	const update = (f: number): void => {
		// 分帧建：一帧建一件（8 行星 + 探测器 ⇒ 9 帧建完，约 0.15s，落在标题淡入里）
		if (buildQueue.length > 0) {
			const job = buildQueue.shift();
			if (job !== undefined) job();
		}
		updateWorld(f);
		updateLabels(f);
	};

	const finish = (): void => {
		if (mode !== 'intro') return;
		mode = 'idle';
		skipLayer.touchEnabled = false;
		options.onFinish();
	};

	skipLayer.onTapEnded((): void => {
		finish();
	});
	// ⚠️ 注册回调会把 touchEnabled 置回 true ⇒ 初始状态写在注册之后（见 game/Hud.ts 同名注释）
	skipLayer.touchEnabled = false;
	ui.visible = false;

	return {
		start: (): void => {
			mode = 'intro';
			frame = 0;
			root.visible = true;
			ui.visible = true;
			skipLayer.touchEnabled = true;
			update(0);
		},
		step: (): void => {
			if (mode === 'off') return;
			frame += 1;
			update(frame);
			if (mode === 'intro' && frame >= TotalFrames) finish();
		},
		skip: (): void => {
			finish();
		},
		frameIndex: (): number => frame,
		idle: (): void => {
			mode = 'idle';
			root.visible = true;
			ui.visible = true;
			skipLayer.touchEnabled = false;
			update(frame < 0 ? 0 : frame);
		},
		phase: (): OpeningPhase => (mode === 'off' ? 'off' : openingPhase(frame)),
		running: (): boolean => mode !== 'off',
		hide: (): void => {
			mode = 'off';
			root.visible = false;
			ui.visible = false;
			skipLayer.touchEnabled = false;
		},
	};
}
