/**
 * 轨迹渲染：预测线（拖动瞄准时实时重画）+ 真实尾迹。
 *
 * 背景（手册 §5.5）：`Line` 只能画 2D（`Vec2[]`），而轨迹在最上面一层，
 * 所以需要把 3D 世界点投影到 2D 覆盖层。复用已标定的
 * `game/Projection.ts`（误差 1 px，R4 已关闭）。
 *
 * 关键约束（手册 §5.5）：**预测线与真实尾迹必须用同一套采样数据**，
 * 否则会出现"看起来一样、其实不一样"。本模块把两种线的绘制
 * 拆成两个函数，但都走同一个 `projectPolyline`。
 *
 * 为什么用 `DrawNode.drawSegment` 而不是 `Line`：
 * `Line` 的线宽不可控（约 1px），且**逐段颜色/宽度不可控**。
 * 2026-09-25 按用户反馈重画（会话 25）：
 * - 预测线 = 愤怒小鸟式**虚线**（画一段空一段）+ **末端渐隐**（alpha 沿线衰减）；
 * - 尾迹 = **彗星拖尾**：只保留最近若干采样点（不再全程显示一条线），
 *   宽度与 alpha 从头部向尾部收窄，头部加一个亮点；
 * - 两条线都垫一层低透明度宽光晕（加法混合）= 原 S3.2 计划的"发光"。
 *
 * 坐标系：投影输出是"中心原点、+Y 向上"（S2 修正后），绘制层用显式
 * `layerOriginX/Y` 换算（见 TrajectoryOptions 的实测说明）。
 */
import { BlendFunc, BlendOp, Color, DrawNode, Node, Vec2, View } from 'Dora';
import { CameraBasis, projectPrepared } from 'game/Projection';
import { P2 } from 'game/Gravity';
import { PlaneToWorldX, PlaneToWorldZ } from 'game/Config';

/**
 * 把平面采样点批量投影成**绘制层坐标**。
 *
 * @param originX 绘制层坐标原点相对"投影输出（中心原点）"的 x 偏移
 * @param originY 同上，y 偏移
 *
 * 为什么必须显式传：投影输出是中心原点偏移，而**绘制层自己的空间不一定是中心原点**
 * （取决于这个节点挂在谁下面）。把空间当成隐式全局（例如直接读 View.size）会让
 * 调用方与测试都无法表达"这一层到底是什么空间"，S2.2 的坐标错位正是这么来的。
 */
export function projectPolyline(points: P2[], y: number, basis: CameraBasis, originX: number, originY: number): Vec2.Type[] {
	const out: Vec2.Type[] = [];
	for (const p of points) {
		const world = {
			x: p.x * PlaneToWorldX,
			y,
			z: p.y * PlaneToWorldZ,
		};
		const proj = projectPrepared(world, basis);
		if (proj === undefined) continue;
		const x = proj.x + originX;
		const yy = proj.y + originY;
		// ⚠️ 相机 lerp 期间（重试/重进关卡）采样点可能掠过相机附近：vz→0 时投影坐标
		//    会爆到 ±1e5 像素以上 ⇒ 虚线走笔卡死 + GPU 挂在巨型三角形上（2026-09-25 用户
		//    卡死实测：帧率塌到 2fps 后引擎崩溃）。钳到屏幕最大边的 5 倍——远超屏外即可。
		const limit = Math.max(View.size.width, View.size.height) * 5;
		out.push(Vec2(
			x > limit ? limit : (x < -limit ? -limit : x),
			yy > limit ? limit : (yy < -limit ? -limit : yy),
		));
	}
	return out;
}

/** 预测线 + 尾迹的渲染句柄。 */
export interface TrajectoryView {
	/**
	 * 重画预测线（虚线 + 末端渐隐 + 光晕）。
	 *
	 * 每帧调用（拖动瞄准时必须实时跟随）；点数多时靠 `maxPoints` 抽稀。
	 * `basis` 是**当前帧**的相机基 —— 相机在动，所以不能缓存。
	 */
	setPrediction(points: P2[], basis: CameraBasis): void;
	/** 隐藏预测线（例如发射后不再需要）。 */
	clearPrediction(): void;
	/** 重画彗星尾迹（只保留最近 `tailPoints` 个采样点）；`basis` 同样必须传当前帧的。 */
	setTrail(points: P2[], basis: CameraBasis): void;
	/** 清空尾迹（重试本关时调用）。 */
	clearTrail(): void;
	/** 底层节点，调用方自行 addChild 到想要的层级。 */
	root: Node.Type;
}

export interface TrajectoryOptions {
	/** 轨迹的**高度偏移**（世界 y）。通常略高于黄道面，避免被行星挡住。 */
	y: number;
	/**
	 * 绘制层坐标原点相对投影输出（中心原点）的偏移。
	 *
	 * ⚠️ 实测（标记点法）：本项目的轨迹画在 `levelLayers[i]` 上，该层的真实空间是
	 * **左下原点绝对像素** `[0,W]×[0,H]`，所以偏移 = 半个视图。
	 */
	layerOriginX: number;
	layerOriginY: number;
	/** 最多绘制多少个点（抽稀上限，防止移动端性能问题）。 */
	maxPoints: number;
	/** 预测线主线半径（像素；光晕层 = 本值 × glowRadiusFactor）。 */
	predictRadius: number;
	/** 虚线的实段长度（像素）。 */
	dashOn: number;
	/** 虚线的空段长度（像素）。 */
	dashOff: number;
	/** 预测线末端残留 alpha（0–1）。不为 0：保留弹弓规划的远端信息，只是"淡出"。 */
	predictFadeMin: number;
	/** 光晕层半径 = 主半径 × glowRadiusFactor。 */
	glowRadiusFactor: number;
	/** 光晕层基础 alpha（0–1，加法混合下再乘沿线衰减）。 */
	glowAlpha: number;
	/** 尾迹保留最近多少个采样点（彗尾长度；播放 2x 下 ≈ 0.8 s）。 */
	tailPoints: number;
	/** 尾迹头部半径（像素）；尾部半径 = 尾迹头 × 0.15。 */
	trailHeadRadius: number;
	/** 尾迹头部 alpha（0–1）；尾部渐到 0。 */
	trailHeadAlpha: number;
	/** 预测线 RGB（0–255）。 */
	predictR: number;
	predictG: number;
	predictB: number;
	/** 尾迹 RGB（0–255）。 */
	trailR: number;
	trailG: number;
	trailB: number;
}

export function defaultOptions(): TrajectoryOptions {
	return {
		y: 0.02,
		// 绘制层是左下原点绝对像素（见 TrajectoryOptions.layerOriginX 的实测说明）
		layerOriginX: View.size.width / 2,
		layerOriginY: View.size.height / 2,
		maxPoints: 240,
		predictRadius: 2.0,
		// dashOff 要明显大于 2×(core+glow 半径)：圆头线帽会向间隙里延伸，间隙太小被桥接成实线（实测）
		dashOn: 12,
		dashOff: 9,
		predictFadeMin: 0.10,
		glowRadiusFactor: 1.9,
		glowAlpha: 0.13,
		tailPoints: 280,
		trailHeadRadius: 3.4,
		trailHeadAlpha: 0.85,
		predictR: 120,
		predictG: 200,
		predictB: 255,
		trailR: 255,
		trailG: 236,
		trailB: 170,
	};
}

/** 均匀抽稀到不超过 maxPoints 个点（保留首尾）。 */
export function decimate(points: P2[], maxPoints: number): P2[] {
	if (maxPoints <= 0 || points.length <= maxPoints) return points;
	const out: P2[] = [];
	const step = (points.length - 1) / (maxPoints - 1);
	for (let i = 0; i < maxPoints; i++) {
		const idx = Math.floor(i * step);
		const safe = idx < points.length ? idx : points.length - 1;
		out.push(points[safe]);
	}
	// 确保最后一个点真的是末点
	out[maxPoints - 1] = points[points.length - 1];
	return out;
}

/**
 * 沿线 alpha 渐变（0 = 起点，1 = 末端）：平滑衰减，末端保留 `minA`。
 * 幂次 1.35 让前半段基本保持实色、后半段加速变淡（愤怒小鸟的观感）。
 */
function fadeAlpha(t: number, minA: number): number {
	const u = t < 0 ? 0 : (t > 1 ? 1 : t);
	return minA + (1 - minA) * Math.pow(1 - u, 1.35);
}

interface RGB { r: number; g: number; b: number; }

function segColor(rgb: RGB, alpha: number): Color.Type {
	// ⚠️ 加法混合（BlendFunc(One, One)）下 color 的 **alpha 分量不参与混合**（实测：
	// 首版把衰减写进 alpha，结果虚线/渐隐完全失效、整条线一样亮）。亮度必须**预乘进 RGB**。
	const a = alpha < 0 ? 0 : (alpha > 1 ? 1 : alpha);
	return Color(Math.round(rgb.r * a), Math.round(rgb.g * a), Math.round(rgb.b * a), 255);
}

/**
 * 虚线 + 渐隐 + 光晕：沿折线按"实段/空段"节奏走笔，
 * 每个实段按其中点的沿线比例取 alpha（光晕层同 alpha、更宽）。
 */
function drawDashed(
	draw: DrawNode.Type,
	verts: Vec2.Type[],
	coreRadius: number,
	rgb: RGB,
	fadeMin: number,
	glowRadiusFactor: number,
	glowAlpha: number,
	dashOn: number,
	dashOff: number,
): void {
	// 单段长度上限（像素）：超过即视为投影退化，跳过不画。
	// ⚠️ 阈值必须紧（800px）：抽稀后正常段长只有 5-50px；阈值松了（如 3×对角线）时
	//    lerp 期间几十个巨型段 × 每段数百次虚线迭代 = 每帧 8 万+ 顶点 => GPU TDR 引擎崩溃（实测）。
	const maxSeg = 800;
	draw.clear();
	const n = verts.length;
	if (n < 2) return;

	// 逐段长度与总弧长（alpha 沿**弧长比例**衰减，而不是沿点序号）
	const segLen: number[] = [];
	let total = 0;
	for (let i = 1; i < n; i++) {
		const dx = verts[i].x - verts[i - 1].x;
		const dy = verts[i].y - verts[i - 1].y;
		const l = Math.sqrt(dx * dx + dy * dy);
		segLen.push(l);
		total += l;
	}
	if (total < 1e-3) return;

	const cycle = dashOn + dashOff;
	const glowRadius = coreRadius * glowRadiusFactor;
	let pen = 0;
	for (let i = 1; i < n; i++) {
		const ax = verts[i - 1].x, ay = verts[i - 1].y;
		const bx = verts[i].x, by = verts[i].y;
		const len = segLen[i - 1];
		// 退化段（点掠过相机附近）直接跳过：走笔要跑 len/周期 次迭代，巨型段 = 卡死
		if (len < 1e-3 || len > maxSeg) continue;
		let s = 0;
		while (s < len - 1e-3) {
			const c = pen % cycle;
			const run = Math.min(cycle - c, len - s);
			if (c < dashOn) {
				const t0 = s / len;
				const t1 = (s + run) / len;
				const x0 = ax + (bx - ax) * t0;
				const y0 = ay + (by - ay) * t0;
				const x1 = ax + (bx - ax) * t1;
				const y1 = ay + (by - ay) * t1;
				const al = fadeAlpha((pen + run * 0.5) / total, fadeMin);
				const p0 = Vec2(x0, y0);
				const p1 = Vec2(x1, y1);
				draw.drawSegment(p0, p1, glowRadius, segColor(rgb, glowAlpha * al));
				draw.drawSegment(p0, p1, coreRadius, segColor(rgb, al));
			}
			pen += run;
			s += run;
		}
	}
}

/** 彗星拖尾：宽度与 alpha 从头部向尾部收窄 + 光晕 + 头部亮点。 */
function drawComet(
	draw: DrawNode.Type,
	verts: Vec2.Type[],
	headRadius: number,
	rgb: RGB,
	headAlpha: number,
	glowRadiusFactor: number,
	glowAlpha: number,
): void {
	draw.clear();
	const n = verts.length;
	if (n < 2) return;
	const tailRadius = headRadius * 0.15;
	const glowRadius = headRadius * glowRadiusFactor;
	const maxSeg = 800; // 同 drawDashed：阈值必须紧，见其注释
	for (let i = 1; i < n; i++) {
		// u: 0 = 尾（最老）→ 1 = 头（最新）
		const u = i / (n - 1);
		const up = Math.pow(u, 1.2);
		const r = tailRadius + (headRadius - tailRadius) * up;
		const al = headAlpha * Math.pow(u, 1.6);
		const dxv = verts[i].x - verts[i - 1].x;
		const dyv = verts[i].y - verts[i - 1].y;
		if (dxv * dxv + dyv * dyv > maxSeg * maxSeg) continue; // 退化段跳过（同 drawDashed）
		draw.drawSegment(verts[i - 1], verts[i], r * glowRadiusFactor, segColor(rgb, glowAlpha * al));
		draw.drawSegment(verts[i - 1], verts[i], r, segColor(rgb, al));
	}
	// 头部亮点（当前探测器位置）
	draw.drawDot(verts[n - 1], headRadius * 1.5, segColor(rgb, headAlpha));
}

/**
 * 创建轨迹视图。
 *
 * @param parent 挂载的父节点。必须是 **2D** 节点（通常是 `Director.ui`）——
 *   `Director.entry` 是 `View3D`，不能挂 2D 绘制节点。
 */
export function createTrajectoryView(
	parent: Node.Type,
	opts?: TrajectoryOptions,
): TrajectoryView {
	const options = opts !== undefined ? opts : defaultOptions();

	// 用一个不设定尺寸的 Node 作为根，保持"中心原点"坐标系。
	const root = Node();

	// 两个独立的 DrawNode：尾迹在底层，预测线在上层。
	const trailDraw = DrawNode();
	// 加法混合（One/One）= 发光感：在暗背景上叠加提亮。
	trailDraw.blendFunc = BlendFunc(BlendOp.One, BlendOp.One);
	root.addChild(trailDraw);

	const predictDraw = DrawNode();
	predictDraw.blendFunc = BlendFunc(BlendOp.One, BlendOp.One);
	root.addChild(predictDraw);

	parent.addChild(root);

	const predictRGB: RGB = { r: options.predictR, g: options.predictG, b: options.predictB };
	const trailRGB: RGB = { r: options.trailR, g: options.trailG, b: options.trailB };

	return {
		setPrediction(points: P2[], basis: CameraBasis): void {
			const verts = projectPolyline(decimate(points, options.maxPoints), options.y, basis, options.layerOriginX, options.layerOriginY);
			drawDashed(
				predictDraw,
				verts,
				options.predictRadius,
				predictRGB,
				options.predictFadeMin,
				options.glowRadiusFactor,
				options.glowAlpha,
				options.dashOn,
				options.dashOff,
			);
		},
		clearPrediction(): void {
			predictDraw.clear();
		},
		setTrail(points: P2[], basis: CameraBasis): void {
			// 彗尾 = 只保留最近 tailPoints 个点；**每帧都重画**（窗口在滑动，且相机在动），
			// 旧的"点数不变就跳过"优化在固定长度尾迹下不再成立。
			if (points.length < 2) {
				trailDraw.clear();
				return;
			}
			const tail = points.length > options.tailPoints
				? points.slice(points.length - options.tailPoints)
				: points;
			const verts = projectPolyline(decimate(tail, options.maxPoints), options.y, basis, options.layerOriginX, options.layerOriginY);
			drawComet(
				trailDraw,
				verts,
				options.trailHeadRadius,
				trailRGB,
				options.trailHeadAlpha,
				options.glowRadiusFactor,
				options.glowAlpha,
			);
		},
		clearTrail(): void {
			trailDraw.clear();
		},
		root,
	};
}
