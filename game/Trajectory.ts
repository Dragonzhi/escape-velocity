/**
 * 轨迹渲染：预测线（拖动瞄准时实时重画）+ 真实尾迹。
 *
 * 背景（手册 §5.5）：`Line` 只能画 2D（`Vec2[]`），而轨迹在最上面一层，
 * 所以需要把 3D 世界点投影到 2D 覆盖层。复用已标定的
 * `game/Projection.ts`（误差 1 px，R4 已关闭）。
 *
 * 关键约束（手册 §5.5）：**预测线与真实尾迹必须用同一套采样数据**，
 * 否则会出现“看起来一样、其实不一样”。本模块把两种线的绘制
 * 拆成两个函数，但都走同一个 `projectPolyline`。
 *
 * 为什么用 `DrawNode.drawSegment` 而不是 `Line`：
 * `Line` 的线宽不可控（约 1px），在 1080p 竖屏下太细、几乎看不见。
 * `drawSegment` 可以指定半径，才能做出手册要求的“发光轨迹”。
 * 代价是逐段绘制；已经在 `maxPoints` 里抽稀控制段数。
 *
 * 坐标系：投影输出是“中心原点、+Y 向下”；2D 覆盖层节点挂在 Director.ui
 * 下，也是中心原点但 +Y 向上，所以统一用 `-proj.y` 翻转。
 */
import { BlendFunc, BlendOp, Color, DrawNode, Node, Vec2 } from 'Dora';
import { CameraBasis, projectPrepared } from 'game/Projection';
import { P2 } from 'game/Gravity';
import { PlaneToWorldX, PlaneToWorldZ } from 'game/Config';

/** 把平面采样点批量投影成覆盖层坐标。 */
export function projectPolyline(points: P2[], y: number, basis: CameraBasis): Vec2.Type[] {
	const out: Vec2.Type[] = [];
	for (const p of points) {
		const world = {
			x: p.x * PlaneToWorldX,
			y,
			z: p.y * PlaneToWorldZ,
		};
		const proj = projectPrepared(world, basis);
		if (proj === undefined) continue;
		// 图像坐标（+Y 向下）→ 覆盖层坐标（+Y 向上）
		out.push(Vec2(proj.x, -proj.y));
	}
	return out;
}

/** 预测线 + 尾迹的渲染句柄。 */
export interface TrajectoryView {
	/**
	 * 重画预测线。
	 *
	 * 每帧调用（拖动瞄准时必须实时跟随）；点数多时靠 `maxPoints` 抽稀。
	 * `basis` 是**当前帧**的相机基 —— 相机在动，所以不能缓存。
	 */
	setPrediction(points: P2[], basis: CameraBasis): void;
	/** 隐藏预测线（例如发射后不再需要）。 */
	clearPrediction(): void;
	/** 追加重画真实尾迹；`basis` 同样必须传当前帧的。 */
	setTrail(points: P2[], basis: CameraBasis): void;
	/** 清空尾迹（重试本关时调用）。 */
	clearTrail(): void;
	/** 底层节点，调用方自行 addChild 到想要的层级。 */
	root: Node.Type;
}

export interface TrajectoryOptions {
	/** 轨迹的**高度偏移**（世界 y）。通常略高于黄道面，避免被行星挡住。 */
	y: number;
	/** 最多绘制多少个点（抽稀上限，防止移动端性能问题）。 */
	maxPoints: number;
	/** 预测线的粗细（像素）。 */
	predictRadius: number;
	/** 尾迹的粗细（像素）。 */
	trailRadius: number;
	/** 预测线颜色（RGBA，0–255）。 */
	predictColor: Color.Type;
	/** 尾迹颜色（RGBA，0–255）。 */
	trailColor: Color.Type;
}

export function defaultOptions(): TrajectoryOptions {
	return {
		y: 0.02,
		maxPoints: 240,
		predictRadius: 2.0,
		trailRadius: 3.5,
		// 预测线偏冷色且半透明（“可能的未来”）
		predictColor: Color(120, 200, 255, 110),
		// 尾迹偏暖色且更实（已发生的路径）
		trailColor: Color(255, 236, 170, 235),
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

	// 用一个不设定尺寸的 Node 作为根，保持“中心原点”坐标系。
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

	let trailCount = 0;

	/** 把投影后的顶点用圆头线段连成一条光滑折线。 */
	function drawPolyline(draw: DrawNode.Type, verts: Vec2.Type[], radius: number, color: Color.Type): void {
		draw.clear();
		for (let i = 1; i < verts.length; i++) {
			draw.drawSegment(verts[i - 1], verts[i], radius, color);
		}
		// 在关节处补圆点，消除折角缝隙（圆头效果）
		for (const v of verts) {
			draw.drawDot(v, radius, color);
		}
	}

	return {
		setPrediction(points: P2[], basis: CameraBasis): void {
			const verts = projectPolyline(decimate(points, options.maxPoints), options.y, basis);
			drawPolyline(predictDraw, verts, options.predictRadius, options.predictColor);
		},
		clearPrediction(): void {
			predictDraw.clear();
		},
		setTrail(points: P2[], basis: CameraBasis): void {
			if (points.length < 2) {
				trailDraw.clear();
				trailCount = 0;
				return;
			}
			// 尾迹只在新增点时才重画，减少开销
			if (points.length === trailCount) return;
			trailCount = points.length;
			const verts = projectPolyline(decimate(points, options.maxPoints), options.y, basis);
			drawPolyline(trailDraw, verts, options.trailRadius, options.trailColor);
		},
		clearTrail(): void {
			trailDraw.clear();
			trailCount = 0;
		},
		root,
	};
}
