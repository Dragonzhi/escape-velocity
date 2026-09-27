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
import { Color, DrawNode, Node, Vec2 } from 'Dora';
import { Body, P2, bodyPositionAt, distance } from 'game/Gravity';
import { FlowDotsPerOrbit, flowDotPosition } from 'game/OrbitFlow';
import { GoalRing, decimate } from 'game/Trajectory';
import { PlanetVisualDef } from 'game/LevelData';
import { colorFromHex } from 'game/Ui';

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
export function planFitRadius(bodies: Body[], probeStart: P2, goalIndex: number, goalTolerance: number, centerIndex?: number): number {
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
	/** 认定"这是一颗恒星"的 gm 下限（与 Config.SunMinGmForLight 同源）。 */
	sunGmMin: number;
	/** 探测器图钉半径。 */
	probePinRadius: number;
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
		sunGmMin: 10000,
		probePinRadius: 11,
		probeTickLen: 22,
		predictHex: 0x78c8ff,
		predictWidth: 2.5,
		polylineMaxPoints: 240,
		trailHex: 0xffecaa,
		trailWidth: 3.5,
		flowDotRadius: 3.5,
		flowDotHex: 0xfff0cf,
		probeHex: 0xeaf4ff,
	};
}

/** 2D 规划视图句柄（属性式方法，见 Trajectory 的同款约定）。 */
export interface PlanView {
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
	/** 把本帧的改动一次性画出来（每帧由 Game 在所有 set* 之后调用一次）。 */
	flush(): void;
	/** 清空全部绘制（隐藏 / 视口重建 / 离开关卡时调用）。 */
	clear(): void;
	/** 探测器在**关卡层局部像素**里的位置（HUD 的"探测器附近才算瞄准"读它，保证与画面同一套换算）。 */
	probeScreen(): P2;
	/** 当前映射（诊断与单测用）。 */
	mapping(): PlanMapping;
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

	// 五层 DrawNode，自下而上：轨道 → 光点 → 到达圈 → 轨迹 → 图钉
	const root = Node();
	const orbitDraw = DrawNode();
	const dotDraw = DrawNode();
	const ringDraw = DrawNode();
	const pathDraw = DrawNode();
	const pinDraw = DrawNode();
	root.addChild(orbitDraw);
	root.addChild(dotDraw);
	root.addChild(ringDraw);
	root.addChild(pathDraw);
	root.addChild(pinDraw);
	layer.addChild(root);

	const orbitColor = colorFromHex(options.orbitHex, 1);
	const ringColor = colorFromHex(options.ringHex, 1);
	const predictColor = colorFromHex(options.predictHex, 1);
	const trailColor = colorFromHex(options.trailHex, 1);
	const probeColor = colorFromHex(options.probeHex, 1);
	const flowDotColor = colorFromHex(options.flowDotHex, 1);
	/** 只描边不填充：`drawPolygon` 的填充用全透明色（与 Ui.createPanel 的手法一致）。 */
	const noFill = colorFromHex(0x000000, 0);

	let isVisible = true;
	let map = computePlanMapping(viewW, viewH, 1, options.marginFrac);
	let dirty = true;

	// 状态：隐藏时也照常存着 ⇒ 切回 2D 的下一帧立刻能画（不用等下一次 sync）
	let bodies: Body[] = [];
	let visuals: PlanetVisualDef[] = [];
	let tWorld = 0;
	let probe: P2 = { x: 0, y: 0 };
	let probeVel: P2 = { x: 0, y: 0 };
	let pred: P2[] = [];
	let trail: P2[] = [];
	let rings: GoalRing[] = [];

	const clearAll = (): void => {
		orbitDraw.clear();
		dotDraw.clear();
		ringDraw.clear();
		pathDraw.clear();
		pinDraw.clear();
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

		// ①b 沿轨道流动的光点（S3.16）：第 k 个光点的角 = 行星此刻的角 + k·2π/N
		// ⇒ 整条链以角速度 ω 公转：方向 = orbitDirection（字段，不写死），快慢 ∝ 2π/orbitPeriod
		// （内圈快、外圈慢 = 开普勒的视觉效果）。位置只由 tWorld 解析求出（ OrbitFlow.ts ），
		// 所以拨发射日期时行星与光点一起动；静止天体（orbitPeriod = 0）没有可流动的轨道。
		for (const b of bodies) {
			if (b.orbitRadius <= 0 || b.orbitPeriod === 0) continue;
			const rPx = b.orbitRadius * map.scale;
			if (rPx < 1) continue;
			for (let k = 0; k < FlowDotsPerOrbit; k++) {
				const s = planeToScreen(flowDotPosition(b, tWorld, k, FlowDotsPerOrbit), map);
				dotDraw.drawDot(Vec2(s.x, s.y), options.flowDotRadius, flowDotColor);
			}
		}

		// ② 到达圈：半径 = 该航点的容差 **按平面单位换算**（圈的像素大小就是"够不够得着"的信息）
		for (const ring of rings) {
			const s = planeToScreen(ring.center, map);
			const rPx = ring.radius * map.scale;
			if (rPx < 1) continue;
			ringDraw.drawPolygon(circleVerts(s.x, s.y, rPx, options.ringSegments), noFill, options.ringWidth, ringColor);
		}

		// ③ 轨迹：尾迹在下、预测线在上（预测线是玩家此刻要发的那一发，必须压在最上面）
		drawPolyline(trail, trailColor, options.trailWidth);
		drawPolyline(pred, predictColor, options.predictWidth);

		// ④ 图钉：行星用关卡自己的视觉色（与 3D 里同一颗行星同色），固定像素大小
		for (let i = 0; i < bodies.length; i++) {
			const b = bodies[i];
			const s = planeToScreen(bodyPositionAt(b, tWorld), map);
			const r = b.gm >= options.sunGmMin ? options.sunPinRadius : options.pinRadius;
			let col = orbitColor;
			if (i < visuals.length) {
				const v = visuals[i];
				col = Color(Math.floor(v.r * 255), Math.floor(v.g * 255), Math.floor(v.b * 255), 255);
			}
			pinDraw.drawDot(Vec2(s.x, s.y), r, col);
		}

		// ⑤ 探测器：亮点 + 一圈细环（一眼分清"我"与行星）+ 速度方向短线
		const ps = planeToScreen(probe, map);
		pinDraw.drawDot(Vec2(ps.x, ps.y), options.probePinRadius, probeColor);
		pinDraw.drawPolygon(circleVerts(ps.x, ps.y, options.probePinRadius + 5, 24), noFill, 1.5, probeColor);
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
			map = computePlanMapping(viewW, viewH, radius, options.marginFrac);
			dirty = true;
		},
		syncBodies(bs: Body[], vs: PlanetVisualDef[], t: number): void {
			bodies = bs;
			visuals = vs;
			tWorld = t;
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
		setGoalRings(rs: GoalRing[]): void {
			rings = rs;
			dirty = true;
		},
		clearGoalRings(): void {
			rings = [];
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
		root,
	};
}
