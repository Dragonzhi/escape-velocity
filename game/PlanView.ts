/**
 * 2D 规划视图（S3.15）—— **俯视线稿示意图**。
 *
 * 设计稿（docs/关卡舞台表.md 第二节第 3 条）：**2D 线稿示意图 = 规划；3D = 观赏与回报**。
 * 本模块只负责 2D 那一半，而且是**简化版**（第 10 条押注口径）：轨道圈 + 图钉 + 预测线 + 到达圈。
 * **沿轨道流动的光点**（S3.16，设计稿第二节第 5 条）也画在这里：方向 = orbitDirection、
 * 快慢 ∝ 角速度 ω = 2π/orbitPeriod，位置由 tWorld 解析求出（数学在 game/OrbitFlow.ts，
 * 3D 那一半在 game/Scene.ts）。标注文字与时间轴提示仍是砍线项，不在本模块里。
 *
 * ===== 三条硬约束（照做，别自作主张）=====
 *
 * 1. **几何只有一份事实来源**：预测线用的是 Game.ts 里 `simulate` 出来的**同一批采样点**
 *    （`predPoints` / 尾迹数组），本模块**只换投影**（平面 → 屏幕），一次物理都不重算。
 * 2. **图钉与圈的分辨率与物理半径解耦**：图钉是**固定像素尺寸**（不然直径 1.0 的月球与
 *    直径 4.63 的木星在图上一颗看不见、一颗糊住半屏）；到达圈的半径则**按平面单位换算**
 *    （`radius × scale`）—— 圈的大小本身就是玩法信息（"够不够得着"）。
 * 3. **平面 +y 映射到屏幕下方**（`planeToScreen` 的 y 取负）。两个理由：
 *    ① 与 3D 视图同向（世界 +z 渲染在屏幕下方，见开发手册 §5.5）；
 *    ② **与拖拽语义一致** —— 瞄准用 computeAim（`uy = -dy/len`），往上拖 = 平面 -y，
 *    所以平面 -y 必须在画面上方，否则"手指往上拖、线却往下跑"。
 *
 * ===== 坐标系 =====
 *
 * 本模块画在**关卡 2D 层**（`levelLayers[i]`，size = View.size、anchor = (0.5,0.5)、position = (0,0)）上，
 * 该层的子空间是**左下原点绝对像素 [0,W]×[0,H]、+Y 向上**（与 Trajectory 的 layerOrigin 同一套约定，
 * 见开发手册 §5.5 第 7 条）。所以这里直接用像素坐标，不加任何居中偏移。
 */
import { Color, DrawNode, Label, Node, Vec2 } from 'Dora';
import { Body, P2, bodyPositionAt, distance } from 'game/Gravity';
import { FlowDotsPerOrbit, flowDotPosition } from 'game/OrbitFlow';
import { GoalRing, decimate } from 'game/Trajectory';
import { PlanetVisualDef } from 'game/LevelData';
import { KmPerUnit } from 'game/Scale';
import { PROBE_VISUAL_RADIUS, bodyLabel } from 'game/Tuning';
import { colorFromHex, createLabel, setLabelCenter, setLabelText, setLabelVisible } from 'game/Ui';

/** 视图模式：`'2D'` = 规划（线稿示意图），`'3D'` = 观赏（发光太阳、真实比例、掠过被掰弯）。 */
export type PlanViewMode = '2D' | '3D';

/**
 * 平面 → 屏幕的**等比**映射。
 *
 * `scale` 对 x/y 是同一个数 ⇒ 圆在屏幕上还是圆（不失真，硬要求）。
 */
export interface PlanMapping {
	/** 平面单位 → 像素。 */
	scale: number;
	/** 平面原点 (0,0) 落在屏幕的哪个像素（左下原点、+Y 向上）。 */
	originX: number;
	originY: number;
	/**
	 * 落在屏幕正中的**平面点**（S5）。
	 *
	 * 默认 (0,0) = 以太阳为中心（L2–L6）。
	 * L1 要设成**地球的位置**：那一关整个世界只有 0.6 单位宽，若仍以太阳为中心，
	 * 探测器与月球会挤成屏幕中心的一个点（0.2 / 80 = 0.25% 视野），2D 视图就废了
	 * —— 而用户明确说过「2D 视角负责让玩家知道东西在哪里」。
	 */
	centerX: number;
	centerY: number;
}

/**
 * 求"把半径 `radius` 的圆完整放进视口"的等比映射，四周留 `marginFrac` 的边距。
 *
 * 取 x / y 两个方向里**更紧**的那个比例 ⇒ 至少一个方向正好贴住边距，另一个方向更宽松。
 * `marginFrac` 夹在 [0, 0.45]：写 0.5 会让可用区域变成 0（映射退化）。
 */
export function computePlanMapping(viewW: number, viewH: number, radius: number, marginFrac: number, centerX?: number, centerY?: number): PlanMapping {
	let m = marginFrac;
	if (m < 0) m = 0;
	if (m > 0.45) m = 0.45;
	const usable = 1 - 2 * m;
	const r = radius > 1e-6 ? radius : 1;
	const sx = (viewW * usable) / (2 * r);
	const sy = (viewH * usable) / (2 * r);
	let scale = sx < sy ? sx : sy;
	if (!(scale > 0)) scale = 1; // NaN / 0 兜底（映射退化会让整张图消失）
	return {
		scale,
		originX: viewW / 2,
		originY: viewH / 2,
		centerX: centerX !== undefined ? centerX : 0,
		centerY: centerY !== undefined ? centerY : 0,
	};
}

/**
 * 平面点 → 屏幕像素（左下原点、+Y 向上）。
 *
 * ⚠️ **y 取负**：平面 +y 画在屏幕**下方**（理由见文件头第 3 条）。
 */
export function planeToScreen(p: P2, m: PlanMapping): P2 {
	// 减去中心：中心点落在屏幕正中（L1 以地球为中心，见 PlanMapping.centerX 的说明）
	return { x: m.originX + (p.x - m.centerX) * m.scale, y: m.originY - (p.y - m.centerY) * m.scale };
}

/** `planeToScreen` 的逆（诊断、以及将来"点图定位"用）。 */
export function screenToPlane(q: P2, m: PlanMapping): P2 {
	return { x: (q.x - m.originX) / m.scale + m.centerX, y: (m.originY - q.y) / m.scale + m.centerY };
}

/**
 * 天体（含卫星的宿主链）到平面原点的**最大**距离。
 *
 * 月球这种卫星的圆心是**会动的宿主**（地球），所以它的最远距离 = 宿主的轨道半径 + 自己的轨道半径。
 */
function bodyCenterDist(b: Body): number {
	const own = b.orbitRadius > 0 ? b.orbitRadius : 0;
	if (b.host !== undefined) return bodyCenterDist(b.host) + own;
	return own;
}

/**
 * 2D 视图要装下的**平面半径** = 最外圈轨道 + 到达容差（设计稿："最外圈轨道 + 目标容差"）。
 *
 * - 每颗天体：自己的最远距离 + `max(本体半径, 目标容差)`（目标那颗要留出圈的余量）；
 * - 探测器的出发点也要在画面内（L1 的探测器在 90，比地球轨道 80 还远）。
 */
export function planFitRadius(bodies: Body[], probeStart: P2, goalIndex: number, goalTolerance: number, centerIndex?: number, starOrbits?: Body[]): number {
	// 给了 centerIndex ⇒ 以那颗天体为中心取景（L1 用：那一关的全局尺度与局部尺度差 80 倍）
	if (centerIndex !== undefined && centerIndex >= 0 && centerIndex < bodies.length) {
		const c = bodies[centerIndex];
		const cp = bodyPositionAt(c, 0);
		let r = 0;
		// 「局部系统」的判据用**尺度**而不是对象身份：
		// ⚠️ scaledPlanets 会为每个天体**各自拷贝一份宿主链**，所以 b.host === c 永远是 false
		//    （踩过：L1 的 fit 算成 0.1，月球被整个漏掉）。改用"轨道半径 < c 轨道半径的一半"
		//    + "离 c 足够近"两条 —— L1 的地球 80 ⇒ 限 40，月球 0.2056 / 探测器 0.1 都在里面，
		//    太阳（orbitRadius = 0）与别的行星被排除。
		const lim = c.orbitRadius * 0.5;
		for (let i = 0; i < bodies.length; i++) {
			const b = bodies[i];
			if (b !== c) {
				if (b.orbitRadius <= 0 || b.orbitRadius >= lim) continue;
				if (distance(bodyPositionAt(b, 0), cp) >= lim) continue;
			}
			const p = bodyPositionAt(b, 0);
			const pad = i === goalIndex && goalTolerance > b.radius ? goalTolerance : b.radius;
			const d = distance(p, cp) + pad;
			if (d > r) r = d;
		}
		const pd = distance(probeStart, cp);
		if (pd > r) r = pd;
		return r > 1e-6 ? r : 1;
	}
	let r = 0;
	for (let i = 0; i < bodies.length; i++) {
		const b = bodies[i];
		const pad = i === goalIndex && goalTolerance > b.radius ? goalTolerance : b.radius;
		const d = bodyCenterDist(b) + pad;
		if (d > r) r = d;
	}
	const pd = Math.sqrt(probeStart.x * probeStart.x + probeStart.y * probeStart.y);
	if (pd > r) r = pd;
	// 星尘是公转的，最远就是它的轨道半径（静态星尘则是坐标本身）
	if (starOrbits !== undefined) {
		for (let i = 0; i < starOrbits.length; i++) {
			const sd = starOrbits[i].orbitRadius > 0
				? starOrbits[i].orbitRadius
				: Math.sqrt(starOrbits[i].orbitCenter.x * starOrbits[i].orbitCenter.x + starOrbits[i].orbitCenter.y * starOrbits[i].orbitCenter.y);
			if (sd > r) r = sd;
		}
	}
	return r > 1e-6 ? r : 1;
}

/** 判定"这两个天体是不是同一个"（scaledPlanets 拷贝过宿主链 ⇒ 不能比对象身份，比位置与 gm）。 */
export function sameBody(a: Body, b: Body): boolean {
	return a.gm === b.gm && a.radius === b.radius && a.orbitRadius === b.orbitRadius;
}

/**
 * 2D 到达圈的半径（平面单位）—— **就是航点容差，绝不是视觉半径**。
 *
 * S5 §3.8 规则 3：旧的硬约束「视觉半径必须等于物理半径」作废之后，
 * 玩家判断"够不够得着"的唯一依据变成了这个圈。所以它必须由容差算出，
 * 且**不随视觉半径变化** —— Test/PlanViewTest 有断言守着这两条。
 */
export function arrivalRingRadius(goal: { tolerance: number; chain?: { tolerance: number }[] }): number {
	let r = goal.tolerance;
	if (goal.chain !== undefined) {
		for (let i = 0; i < goal.chain.length; i++) {
			if (goal.chain[i].tolerance > r) r = goal.chain[i].tolerance;
		}
	}
	return r;
}

/** 2D 规划视图的可调参数（配色与 3D 的 Trajectory 对齐：同一颗行星在两个视图里颜色一致）。 */
export interface PlanOptions {
	actualBodySizes?: boolean;
	transferTutorial?: boolean;
	/** 四周留白比例（0.12 = 各留 12%）。 */
	marginFrac: number;
	/** 轨道圈颜色（0xRRGGBB）。 */
	orbitHex: number;
	orbitWidth: number;
	/** 轨道圈的圆周分段数。 */
	orbitSegments: number;
	/** 到达圈颜色：与 3D 的到达环同色（150,235,220）。 */
	ringHex: number;
	ringWidth: number;
	ringSegments: number;
	/** 行星图钉半径（**固定像素**）。 */
	pinRadius: number;
	/** 恒星的图钉半径（大一点，一眼找到太阳）。 */
	sunPinRadius: number;
	/** 探测器图钉半径。 */
	probePinRadius: number;
	/**
	 * 图钉半径的**上限**（像素，S5）。
	 * 半径改成了 max(固定像素, 真实视觉半径 × scale)，L1 的地球视觉半径 0.06 × scale ≈ 63px，
	 * 不设上限会让"行星图钉"大过一个按钮，把 2D 图变成卡通画。
	 */
	maxPinRadius: number;
	/** 探测器"此刻速度方向"的小短线长度（像素）。 */
	probeTickLen: number;
	/** 预测线颜色（120,200,255，与 3D 预测线同色）。 */
	predictHex: number;
	predictWidth: number;
	/** 折线抽稀上限（与 3D 一样防止移动端性能问题）。 */
	polylineMaxPoints: number;
	/** 尾迹颜色（255,236,170）。 */
	trailHex: number;
	trailWidth: number;
	/** 沿轨道流动的光点（S3.16）半径（**固定像素**：不随地图缩放，与图钉同一口径）。 */
	flowDotRadius: number;
	/** 光点颜色（0xRRGGBB）：暖白，和行星图钉/尾迹区分开 —— 一眼认出"这是光不是天体"。 */
	flowDotHex: number;
	/** 探测器图钉的颜色（近白）。 */
	probeHex: number;
	/** 探测器停泊轨的颜色（比行星轨更暗更冷：它是"我在哪条轨道上"的参考线）。 */
	probeOrbitHex: number;
	// ---- 读数标签（B 修复③，2026-09-28）----
	/** 标签字号（像素）。 */
	labelFontSize: number;
	/** 标签颜色（比轨道亮、比图钉暗：它是"说明书"，不该抢图钉的视线）。 */
	labelHex: number;
	/** 标签离图钉中心的垂直距离（像素）；正数 = 画在**上方**。 */
	labelGapY: number;
	/**
	 * 探测器的**视觉半径**（世界单位，B 修复⑤）。
	 *
	 * 省略 = 全局的 `PROBE_VISUAL_RADIUS`。为什么要按关卡给：它决定
	 * `图钉半径 = max(固定像素, 视觉半径 × scale)` 的上限到不到 —— 60× 放大下
	 * `scale ≈ 8.2e4 像素/单位`，用全局的 0.0015 会算出 122px（被 maxPinRadius 压到 26），
	 * 而 L1 现在真实的探测器视觉半径是 **0.00015**（12px）—— 图钉会**吹大 2 倍**，
	 * 在"贴地球"那一帧里看起来像一颗小行星。这就是 AGENTS 说的"写死世界单位的常量要按关卡问一遍"。
	 */
	probeVisualRadius?: number;
}

export function defaultPlanOptions(): PlanOptions {
	return {
		marginFrac: 0.12,
		orbitHex: 0x46586d,
		orbitWidth: 1.5,
		orbitSegments: 72,
		ringHex: 0x96ebdc,
		ringWidth: 2.5,
		ringSegments: 48,
		pinRadius: 8,
		sunPinRadius: 13,
		probePinRadius: 11,
	maxPinRadius: 26,
		probeTickLen: 22,
		predictHex: 0x78c8ff,
		predictWidth: 2.5,
		polylineMaxPoints: 240,
		trailHex: 0xffecaa,
		trailWidth: 3.5,
		flowDotRadius: 3.5,
		flowDotHex: 0xfff0cf,
		probeHex: 0xeaf4ff,
		probeOrbitHex: 0x5d7fa6,
		labelFontSize: 20,
		labelHex: 0xc3d6e8,
		labelGapY: 18,
		probeVisualRadius: PROBE_VISUAL_RADIUS,
	};
}

/**
 * 公里数 → 中文读数（航天模拟器那种）。
 *
 * 口径：< 1 万 km 给整数带千分位（「6,571 km」）、< 1 亿给「万」（「38.4 万 km」）、
 * 再往上给「亿」（「1.50 亿 km」）。**不做科学计数法**：tstl 没有 toExponential（AGENTS 第 21 条），
 * 而且玩家读数要的是"38.4 万"这种人话，不是 3.844e5。
 */
export function formatKm(km: number): string {
	if (!(km > 0)) return '0 km';
	if (km < 1e4) {
		// 千分位：从右往左每三位插一个逗号
		let s = Math.round(km).toFixed(0);
		let out = '';
		let count = 0;
		for (let i = s.length - 1; i >= 0; i--) {
			out = s.charAt(i) + out;
			count += 1;
			if (count % 3 === 0 && i > 0) out = ',' + out;
		}
		return out + ' km';
	}
	if (km < 1e8) return (km / 1e4).toFixed(1) + ' 万 km';
	return (km / 1e8).toFixed(2) + ' 亿 km';
}

/** 2D 规划视图句柄（属性式方法，见 Trajectory 的同款约定）。 */
export interface PlanView {
	setBurn?: (direction: P2, on: boolean) => void;
	/**
	 * 显隐（状态驱动，由 Game 按 `viewMode` 切）。
	 *
	 * ⚠️ 隐藏时**顺手清空**绘制：DrawNode 挂在关卡 2D 层上、**不随 runtime 消失**
	 * （AGENTS 硬约束 8），不清的话视口重建后旧像素会留在屏幕上。
	 */
	setVisible(on: boolean): void;
	visible(): boolean;
	/** 设定要装下的平面半径（= `planFitRadius` 的结果）；再调一次即可改视野。 */
	fitTo(radius: number): void;
	/** 每帧同步天体（位置按 `tWorld` 算：轨道圈跟着宿主走、图钉跟着行星走）。 */
	syncBodies(bodies: Body[], visuals: PlanetVisualDef[], tWorld: number): void;
	/** 每帧同步探测器（`v` = 此刻速度，画一根方向短线）。 */
	syncProbe(p: P2, v: P2): void;
	/** **玩家自己的预测线**：直接喂 3D 用的那批采样点，本模块只换投影、不重算物理。 */
	setPrediction(points: P2[]): void;
	clearPrediction(): void;
	/** 真实尾迹（飞行中手动切到 2D 时看得见自己飞过哪）。 */
	setTrail(points: P2[]): void;
	clearTrail(): void;
	/** 到达圈（下一个航点）：与 3D 共用同一批 GoalRing（唯一的"下一站"判定）。 */
	setGoalRings(rings: GoalRing[]): void;
	clearGoalRings(): void;
	/** 探测器停泊轨（B2）：以宿主天体为圆心的细环（半径 = 相对宿主的轨道半径）。 */
	setProbeOrbit(center: P2, radius: number): void;
	clearProbeOrbit(): void;
	/** 街机模式：更新星尘收集状态。 */
	setStars(stars: P2[], collected: boolean[]): void;
	/** 把本帧的改动一次性画出来（每帧由 Game 在所有 set* 之后调用一次）。 */
	flush(): void;
	/** 清空全部绘制（隐藏 / 视口重建 / 离开关卡时调用）。 */
	clear(): void;
	/** 探测器在**关卡层局部像素**里的位置（HUD 的"探测器附近才算瞄准"读它，保证与画面同一套换算）。 */
	probeScreen(): P2;
	/** 当前映射（诊断与单测用）。 */
	mapping(): PlanMapping;
	/** 2D 规划视图多级缩放接口（S8.2）。 */
	zoomIn(): void;
	zoomOut(): void;
	resetView(): void;
	pan(dx: number, dy: number): void;
	getZoom(): number;
	/** 底层节点，调用方自行 addChild 到想要的层级。 */
	root: Node.Type;
}

/**
 * 创建 2D 规划视图。
 *
 * @param layer 挂载的父节点，必须是**关卡 2D 层**（左下原点绝对像素空间，见文件头）
 * @param viewW 视图逻辑宽（`View.size.width`）
 * @param viewH 视图逻辑高
 */
export function createPlanView(layer: Node.Type, viewW: number, viewH: number, opts?: PlanOptions, centerBodyIndex?: number): PlanView {
	const options = opts !== undefined ? opts : defaultPlanOptions();

	// 六层 DrawNode，自下而上：轨道 → 光点 → 到达圈 → 轨迹 → 图钉 → 屏幕外信标
	const root = Node();
	const orbitDraw = DrawNode();
	const dotDraw = DrawNode();
	const ringDraw = DrawNode();
	const pathDraw = DrawNode();
	const pinDraw = DrawNode();
	const beaconDraw = DrawNode();
	root.addChild(orbitDraw);
	root.addChild(dotDraw);
	root.addChild(ringDraw);
	root.addChild(pathDraw);
	root.addChild(pinDraw);
	root.addChild(beaconDraw);
	// 读数层（B 修复③，2026-09-28）：**DrawNode 画不出字**，所以单开一层 Label 节点，
	// 放在 root 的最后 = 压在图钉与信标之上（它就是"地图上那种贴在天体旁边的说明"）。
	// 坐标与 DrawNode 同一套（左下原点绝对像素，见文件头"坐标系"）。
	const labelRoot = Node();
	root.addChild(labelRoot);
	/** 探测器读数标签（惰性建一次）。 */
	let probeLabel: Label.Type | undefined = undefined;
	/** 天体读数标签（与 bodies 一一对应，惰性建）。 */
	let bodyLabels: (Label.Type | undefined)[] = [];
	/** 探测器的读数文字（在 syncProbe 里按"此刻离哪个天体最近"算出来）。 */
	let probeReadout = '探测器';
	/** 上次写进 Label 的文字（**没变就别碰 Label**：文字布局每帧重算是纯浪费，Hud 同款纪律）。 */
	let lastProbeReadout = '';
	const lastBodyReadout: string[] = [];
	layer.addChild(root);

	const orbitColor = colorFromHex(options.orbitHex, 1);
	const ringColor = colorFromHex(options.ringHex, 1);
	const predictColor = colorFromHex(options.predictHex, 1);
	const trailColor = colorFromHex(options.trailHex, 1);
	const probeColor = colorFromHex(options.probeHex, 1);
	const probeOrbitColor = colorFromHex(options.probeOrbitHex, 1);
	const flowDotColor = colorFromHex(options.flowDotHex, 1);
	/** 只描边不填充：`drawPolygon` 的填充用全透明色（与 Ui.createPanel 的手法一致）。 */
	const noFill = colorFromHex(0x000000, 0);

	let isVisible = true;
	let currentZoom = 1.0;
	let panOffsetX = 0;
	let panOffsetY = 0;
	let baseFitRadius = 1.0;
	let map = computePlanMapping(viewW, viewH, 1, options.marginFrac);
	let dirty = true;

	const recomputeMap = (): void => {
		const effectiveR = baseFitRadius / currentZoom;
		const newMap = computePlanMapping(viewW, viewH, effectiveR, options.marginFrac, map.centerX, map.centerY);
		newMap.originX = viewW / 2 + panOffsetX;
		newMap.originY = viewH / 2 + panOffsetY;
		map = newMap;
		dirty = true;
	};

	// 状态：隐藏时也照常存着 ⇒ 切回 2D 的下一帧立刻能画（不用等下一次 sync）
	let bodies: Body[] = [];
	let visuals: PlanetVisualDef[] = [];
	let burning = false;
	let burnDirection: P2 = { x: 0, y: 0 };
	// 探测器停泊轨（B2）：宿主中心 + 相对半径（0 = 不画）
	let probeOrbitCenter: P2 = { x: 0, y: 0 };
	let probeOrbitRadius = 0;
	let tWorld = 0;
	let probe: P2 = { x: 0, y: 0 };
	let probeVel: P2 = { x: 0, y: 0 };
	let pred: P2[] = [];
	let trail: P2[] = [];
	let rings: GoalRing[] = [];
	let stars: P2[] = [];
	let collectedStars: boolean[] = [];

	/**
	 * 标签贴边时别被切掉。
	 *
	 * Label 是**居中锚点**（anchor 0.5/0.5），所以左右各留 1/6 屏宽 —— 够放 7–11 个字
	 * （「月球 · 38.4 万 km」在 20px 下约 150px，竖屏 840 宽 ⇒ 140 的余量正好）。
	 */
	const clampLabelX = (x: number): number => {
		const pad = viewW / 6;
		if (x < pad) return pad;
		if (x > viewW - pad) return viewW - pad;
		return x;
	};
	/** 上下留 26px（字号 20 的半高 + 一点余地）。 */
	const clampLabelY = (y: number): number => {
		if (y < 26) return 26;
		if (y > viewH - 26) return viewH - 26;
		return y;
	};

	const clearAll = (): void => {
		orbitDraw.clear();
		dotDraw.clear();
		ringDraw.clear();
		pathDraw.clear();
		pinDraw.clear();
		beaconDraw.clear();
	};

	/** 圆周顶点（`n` 段；返回 Vec2 给 drawPolygon 描边用）。 */
	const circleVerts = (cx: number, cy: number, rPx: number, n: number): Vec2.Type[] => {
		const seg = n > 8 ? n : 8;
		const out: Vec2.Type[] = [];
		for (let i = 0; i < seg; i++) {
			const a = (i / seg) * 2 * Math.PI;
			out.push(Vec2(cx + rPx * Math.cos(a), cy + rPx * Math.sin(a)));
		}
		return out;
	};

	/** 平面折线 → 屏幕折线（抽稀后逐段画）。 */
	const drawPolyline = (pts: P2[], color: Color.Type, width: number): void => {
		if (pts.length < 2) return;
		const dec = decimate(pts, options.polylineMaxPoints);
		let prev: Vec2.Type | undefined = undefined;
		for (const p of dec) {
			const s = planeToScreen(p, map);
			const cur = Vec2(s.x, s.y);
			if (prev !== undefined) pathDraw.drawSegment(prev, cur, width, color);
			prev = cur;
		}
	};

	const redraw = (): void => {
		clearAll();
		if (!isVisible) return;

		// ① 轨道圈：每一个"在绕东西转"的天体一条。卫星的圆心是**会动的宿主**（月球绕地球）。
		for (const b of bodies) {
			if (b.orbitRadius <= 0) continue;
			const center = b.host !== undefined ? bodyPositionAt(b.host, tWorld) : b.orbitCenter;
			const s = planeToScreen(center, map);
			const rPx = b.orbitRadius * map.scale;
			if (rPx < 1) continue;
			orbitDraw.drawPolygon(circleVerts(s.x, s.y, rPx, options.orbitSegments), noFill, options.orbitWidth, orbitColor);
		}

		// ①c 探测器停泊轨（B2）：细、暗。它是"我在哪条轨道上"，与月球轨同款但更弱。
		if (probeOrbitRadius > 0) {
			const ps = planeToScreen(probeOrbitCenter, map);
			const pr = probeOrbitRadius * map.scale;
			if (pr >= 1) orbitDraw.drawPolygon(circleVerts(ps.x, ps.y, pr, options.orbitSegments), noFill, options.orbitWidth, probeOrbitColor);
		}

		// ①b 沿轨道流动的光点（S3.16）：第 k 个光点的角 = 行星此刻的角 + k·2π/N
		// ⇒ 整条链以角速度 ω 公转：方向 = orbitDirection（字段，不写死），快慢 ∝ 2π/orbitPeriod
		// （内圈快、外圈慢 = 开普勒的视觉效果）。位置只由 tWorld 解析求出（ OrbitFlow.ts ），
		// 所以拨发射日期时行星与光点一起动；静止天体（orbitPeriod = 0）没有可流动的轨道。
		if (options.flowDotRadius > 0) for (const b of bodies) {
			if (b.orbitRadius <= 0 || b.orbitPeriod === 0) continue;
			const rPx = b.orbitRadius * map.scale;
			if (rPx < 1) continue;
			for (let k = 0; k < FlowDotsPerOrbit; k++) {
				const s = planeToScreen(flowDotPosition(b, tWorld, k, FlowDotsPerOrbit), map);
				dotDraw.drawDot(Vec2(s.x, s.y), options.flowDotRadius, flowDotColor);
			}
		}

		// ①d 街机引力场呼吸圈（引力影响范围）
		const gravityRingColor = Color(100, 180, 255, 70);
		for (const b of bodies) {
			if (b.gm > 0 && !b.isObstacle) {
				const center = options.transferTutorial === true ? bodyPositionAt(b, tWorld) : b.host !== undefined ? bodyPositionAt(b.host, tWorld) : b.orbitCenter;
				const s = planeToScreen(center, map);
				const gravR = (b.radius * 3.6 + Math.sin(tWorld * 3) * 4) * map.scale;
				if (gravR >= 5) {
					orbitDraw.drawPolygon(circleVerts(s.x, s.y, gravR, 48), noFill, 1.5, gravityRingColor);
				}
			}
		}

		// ② 到达圈：半径 = 该航点的容差 **按平面单位换算**（圈的像素大小就是"够不够得着"的信息）
		for (const ring of rings) {
			const s = planeToScreen(ring.center, map);
			if (ring.point === true) {
				const alpha = ring.pointAlpha !== undefined ? ring.pointAlpha : 1;
				const scale = ring.pulse !== undefined ? ring.pulse : 1;
				ringDraw.drawDot(Vec2(s.x, s.y), 10 * scale, Color(70, 245, 105, Math.floor(55 * alpha * Math.min(2, scale))));
				ringDraw.drawDot(Vec2(s.x, s.y), 3.5 * scale, Color(200, 255, 205, Math.floor(255 * alpha)));
				if (ring.burstRadius !== undefined && ring.burstRadius > 0) ringDraw.drawPolygon(circleVerts(s.x, s.y, ring.burstRadius, 32), noFill, 1.5, Color(120, 255, 145, Math.floor(180 * alpha)));
			}
			if (ring.showRange === false) continue;
			const rPx = ring.radius * map.scale;
			if (rPx < 1) continue;
			if (ring.bandOuterRadius !== undefined && ring.bandOuterRadius > ring.radius) {
				const inner = circleVerts(s.x, s.y, rPx, options.ringSegments);
				const outer = circleVerts(s.x, s.y, ring.bandOuterRadius * map.scale, options.ringSegments);
				for (let i = 1; i < inner.length && i < outer.length; i++) ringDraw.drawPolygon([inner[i - 1], outer[i - 1], outer[i], inner[i]], Color(80, 255, 130, 18), 0, Color(80, 255, 130, 0));
			}
			const ringTint = ring.point === true ? colorFromHex(0x66ff88, ring.pointAlpha !== undefined ? ring.pointAlpha : 1) : (ring.pointAlpha !== undefined ? colorFromHex(options.ringHex, ring.pointAlpha) : ringColor);
			ringDraw.drawPolygon(circleVerts(s.x, s.y, rPx, options.ringSegments), noFill, options.ringWidth, ringTint);
		}

		// ③ 轨迹：尾迹在下、预测线在上（预测线是玩家此刻要发的那一发，必须压在最上面）
		drawPolyline(trail, trailColor, options.trailWidth);
		drawPolyline(pred, predictColor, options.predictWidth);

		// ④ 图钉：行星用关卡自己的视觉色（与 3D 里同一颗行星同色）。
		// ⚠️ S5：半径 = max(固定像素, **真实视觉半径 × scale**)。
		//    只用固定像素的话，L1 的探测器图钉（11px）在 0.2256 视野下 ≈ 0.0105 单位，
		//    而它真实的视觉半径只有 0.0015 —— 图钉被**放大了 7 倍**，
		//    "位置感觉不对"就是这么来的（用户 2026-09-27 实测）。
		//    L2–L6 视野大（半径上百单位），视觉半径 × scale 远小于固定像素 ⇒ 行为不变。
		for (let i = 0; i < bodies.length; i++) {
			const b = bodies[i];
			const s = planeToScreen(bodyPositionAt(b, tWorld), map);
			let r = i < visuals.length && visuals[i].model === 'Sun' ? options.sunPinRadius : options.pinRadius;
			if (i < visuals.length) {
				const v = visuals[i];
				const vr = v.displayRadius > 0 ? v.displayRadius * map.scale : 0;
				if (vr > r) r = vr;
				if (options.actualBodySizes) r = vr;
				else if (r > options.maxPinRadius) r = options.maxPinRadius;
			}
			let col = orbitColor;
			if (i < visuals.length) {
				const v = visuals[i];
				col = Color(Math.floor(v.r * 255), Math.floor(v.g * 255), Math.floor(v.b * 255), 255);
			}
			pinDraw.drawDot(Vec2(s.x, s.y), r, col);

			// ④b 读数（B 修复③）：名字 + 它离**宿主**多远（「月球 · 38.4 万 km」）。
			// 根天体（太阳 / L1 的地球）没有宿主 ⇒ 只写名字，不编一个数字。
			if (i < bodyLabels.length) {
				const lb = bodyLabels[i];
				// ⚠️ 画外天体**不给读数**：贴边夹紧会让"太阳"这种远在天边的天体把标签糊在屏幕角上
				// （实测：L1 的太阳在平面 (0,0)，离这张图十万八千里，标签却被夹到了标题栏上）。
				// 只保留"刚好出画"的（±60px）—— 那种情况玩家确实需要知道"它就在那边"。
				const near = s.x > -60 && s.x < viewW + 60 && s.y > -60 && s.y < viewH + 60;
				setLabelVisible(lb, near);
				if (!near) continue;
				const name = i < visuals.length ? bodyLabel(visuals[i].model) : '天体';
				const text = name;
				if (i >= lastBodyReadout.length || lastBodyReadout[i] !== text) {
					lastBodyReadout[i] = text;
					setLabelText(lb, text);
				}
				setLabelCenter(lb, clampLabelX(s.x), clampLabelY(s.y + r + options.labelGapY));
			}
		}

		// ⑤ 探测器：亮点 + 一圈细环（一眼分清"我"与行星）+ 速度方向短线
		const ps = planeToScreen(probe, map);
		let pr = options.probePinRadius;
		const pvr = options.probeVisualRadius !== undefined ? options.probeVisualRadius : PROBE_VISUAL_RADIUS;
		if (pvr > 0 && pvr * map.scale > pr) pr = pvr * map.scale;
		if (pr > options.maxPinRadius) pr = options.maxPinRadius;
		pinDraw.drawDot(Vec2(ps.x, ps.y), pr, probeColor);
		pinDraw.drawPolygon(circleVerts(ps.x, ps.y, pr + 5, 24), noFill, 1.5, probeColor);
		const vlen = Math.sqrt(probeVel.x * probeVel.x + probeVel.y * probeVel.y);
		if (vlen > 1e-6) {
			const dx = probeVel.x / vlen;
			const dy = probeVel.y / vlen;
			pinDraw.drawSegment(
				Vec2(ps.x, ps.y),
				Vec2(ps.x + dx * options.probeTickLen, ps.y - dy * options.probeTickLen),
				2,
				probeColor,
			);
		}

		// ⑤c 街机金色星尘（🌟）
		const burnMag = Math.sqrt(burnDirection.x * burnDirection.x + burnDirection.y * burnDirection.y);
		if (burning && burnMag > 0) {
			const end = planeToScreen({ x: probe.x - burnDirection.x * 32 / burnMag, y: probe.y - burnDirection.y * 32 / burnMag }, map);
			pinDraw.drawSegment(Vec2(ps.x, ps.y), Vec2(end.x, end.y), 4, Color(255, 135, 35, 160));
			pinDraw.drawSegment(Vec2(ps.x, ps.y), Vec2(end.x, end.y), 1.5, Color(255, 235, 145, 255));
		}
		for (let i = 0; i < stars.length; i++) {
			const st = stars[i];
			const isCol = i < collectedStars.length && collectedStars[i];
			const ss = planeToScreen(st, map);
			if (!isCol) {
				pinDraw.drawDot(Vec2(ss.x, ss.y), 8, Color(255, 215, 0, 255));
				pinDraw.drawPolygon(circleVerts(ss.x, ss.y, 14, 16), noFill, 1.5, Color(255, 230, 100, 200));
			} else {
				pinDraw.drawDot(Vec2(ss.x, ss.y), 5, Color(120, 120, 120, 100));
			}
		}

		// ⑤b 探测器读数（B 修复③）：贴在图钉**下方**（它在 L1 里与地球几乎重叠，写在上方会打架）
		if (probeLabel === undefined) {
			probeLabel = createLabel(labelRoot, probeReadout, options.labelFontSize, options.labelHex);
			lastProbeReadout = probeReadout;
		} else if (lastProbeReadout !== probeReadout) {
			lastProbeReadout = probeReadout;
			setLabelText(probeLabel, probeReadout);
		}
		setLabelVisible(probeLabel, ps.x > -60 && ps.x < viewW + 60 && ps.y > -60 && ps.y < viewH + 60);
		setLabelCenter(probeLabel, clampLabelX(ps.x), clampLabelY(ps.y - pr - options.labelGapY));

		// ⑥ 屏幕外目标雷达指示指针（S8.4）
		if (rings.length > 0) {
			const targetScreen = planeToScreen(rings[0].center, map);
			const pad = 48;
			const isOffscreen = targetScreen.x < pad || targetScreen.x > viewW - pad || targetScreen.y < pad || targetScreen.y > viewH - pad;
			if (isOffscreen) {
				const cx = viewW / 2;
				const cy = viewH / 2;
				const dirX = targetScreen.x - cx;
				const dirY = targetScreen.y - cy;
				const len = Math.sqrt(dirX * dirX + dirY * dirY);
				if (len > 1e-4) {
					const ux = dirX / len;
					const uy = dirY / len;
					const halfW = viewW / 2 - pad;
					const halfH = viewH / 2 - pad;
					const scaleX = Math.abs(ux) > 1e-6 ? halfW / Math.abs(ux) : 1e9;
					const scaleY = Math.abs(uy) > 1e-6 ? halfH / Math.abs(uy) : 1e9;
					const tHit = Math.min(scaleX, scaleY);
					const hitX = cx + ux * tHit;
					const hitY = cy + uy * tHit;
					const arrowLen = 18;
					const arrowHalf = 9;
					const tip = Vec2(hitX + ux * 6, hitY + uy * 6);
					const back = Vec2(hitX - ux * arrowLen, hitY - uy * arrowLen);
					const left = Vec2(back.x - uy * arrowHalf, back.y + ux * arrowHalf);
					const right = Vec2(back.x + uy * arrowHalf, back.y - ux * arrowHalf);
					beaconDraw.drawPolygon([tip, left, right], ringColor, 1.5, ringColor);
					beaconDraw.drawDot(Vec2(hitX, hitY), 4, ringColor);
				}
			}
		}
		dirty = false;
	};

	return {
		setVisible(on: boolean): void {
			isVisible = on;
			root.visible = on;
			if (!on) {
				// 隐藏 = 同时清空（DrawNode 不随 runtime 消失，见接口说明）
				clearAll();
				dirty = false;
			} else {
				dirty = true;
			}
		},
		visible(): boolean {
			return isVisible;
		},
		fitTo(radius: number): void {
			baseFitRadius = radius;
			recomputeMap();
		},
		syncBodies(bs: Body[], vs: PlanetVisualDef[], t: number): void {
			bodies = bs;
			visuals = vs;
			tWorld = t;
			// 读数标签按天体数量惰性建一次（数量在一关内是固定的，所以只会建一次）
			if (bodyLabels.length !== bs.length) {
				bodyLabels = [];
				for (let i = 0; i < bs.length; i++) {
					bodyLabels.push(createLabel(labelRoot, '', options.labelFontSize, options.labelHex));
				}
			}
			// S5：以某颗天体为中心时，**中心跟着它走** —— L1 的地球在绕日公转，
			// 中心固定在地球 t=0 的位置会让整张图随时间漂出屏幕。
			if (centerBodyIndex !== undefined && centerBodyIndex >= 0 && centerBodyIndex < bs.length) {
				const cp = bodyPositionAt(bs[centerBodyIndex], t);
				map.centerX = cp.x;
				map.centerY = cp.y;
				// 中心一动，圈与图钉的屏幕位全变 —— 不能沿用上一帧的绘制结果
				dirty = true;
			}
			dirty = true;
		},
		syncProbe(p: P2, v: P2): void {
			probe = p;
			probeVel = v;
			dirty = true;
			// 探测器读数 = **高度**（离"此刻引力最强的那个天体"表面的距离）。
			// 口径：谁的 gm/d² 最大就是谁 —— L1 是地球（gm 0.216 / d 0.0035，压过太阳的 72000/6400），
			// 外圈五关是太阳（那时读数就是日心距，对那几关同样说得通）。
			// ⚠️ 不写死"宿主索引"：L1 的地球与月球、外圈关的太阳，尺度差 5 个数量级，
			//    写死一定会错一关。
			let best = -1;
			let bestPull = 0;
			let bestDist = 0;
			for (let i = 0; i < bodies.length; i++) {
				const b = bodies[i];
				const d = distance(p, bodyPositionAt(b, tWorld));
				if (d < 1e-9) continue;
				const pull = b.gm / (d * d);
				if (pull > bestPull) {
					bestPull = pull;
					best = i;
					bestDist = d;
				}
			}
			if (best >= 0) {
				const alt = bestDist - bodies[best].radius;
				probeReadout = '探测器 · ' + (alt > 0 ? alt : 0).toFixed(0);
			} else {
				probeReadout = '探测器';
			}
		},
		setPrediction(points: P2[]): void {
			pred = points;
			dirty = true;
		},
		clearPrediction(): void {
			pred = [];
			dirty = true;
		},
		setTrail(points: P2[]): void {
			trail = points;
			dirty = true;
		},
		clearTrail(): void {
			trail = [];
			dirty = true;
		},
		setProbeOrbit(center: P2, radius: number): void {
			probeOrbitCenter = center;
			probeOrbitRadius = radius;
			dirty = true;
		},
		clearProbeOrbit(): void {
			probeOrbitRadius = 0;
			dirty = true;
		},
		setGoalRings(rs: GoalRing[]): void {
			rings = rs;
			dirty = true;
		},
		setBurn: (direction: P2, on: boolean): void => { burnDirection = direction; burning = on; },
		clearGoalRings(): void {
			rings = [];
			dirty = true;
		},
		setStars(s: P2[], c: boolean[]): void {
			stars = s;
			collectedStars = c;
			dirty = true;
		},
		flush(): void {
			// 隐藏时不画（每帧都会被调用：3D 模式下这里是纯开销）
			if (!isVisible) return;
			if (!dirty) return;
			redraw();
		},
		clear(): void {
			clearAll();
			dirty = true;
		},
		probeScreen(): P2 {
			return planeToScreen(probe, map);
		},
		mapping(): PlanMapping {
			return map;
		},
		zoomIn(): void {
			// B2：上限 6 → **60**。真实阿波罗剖面下停泊轨（3.514e-3）只有月球轨（0.2056）的 1.7%，
			// 6× 根本看不到"地球 + 探测器轨"；步进 1.35 → 1.5（60× 约 10 次点击到位）。
			currentZoom = Math.min(60.0, currentZoom * 1.5);
			recomputeMap();
		},
		zoomOut(): void {
			currentZoom = Math.max(0.25, currentZoom / 1.5);
			recomputeMap();
		},
		resetView(): void {
			currentZoom = 1.0;
			panOffsetX = 0;
			panOffsetY = 0;
			recomputeMap();
		},
		pan(dx: number, dy: number): void {
			panOffsetX += dx;
			panOffsetY += dy;
			recomputeMap();
		},
		getZoom(): number {
			return currentZoom;
		},
		root,
	};
}
