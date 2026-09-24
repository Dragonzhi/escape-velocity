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
		out.push(Vec2(proj.x + originX, proj.y + originY));
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
	/**
	 * 绘制层坐标原点相对投影输出（中心原点）的偏移。
	 *
	 * ⚠️ 实测（标记点法）：本项目的轨迹画在 `levelLayers[i]` 上，该层的真实空间是
	 * **左下原点绝对像素** `[0,W]×[0,H]`，所以偏移 = 半个视图。
	 * 依据：在该层画 (0,0)/(W/2,H/2)，前者落在屏幕左下角、后者落在正中心；
	 * 探测器投影值 (0,-530) 加半个视图后正好落在探测器模型上。
	 */
	layerOriginX: number;
	layerOriginY: number;
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
		// 绘制层是左下原点绝对像素（见 TrajectoryOptions.layerOriginX 的实测说明）
		layerOriginX: View.size.width / 2,
		layerOriginY: View.size.height / 2,
		maxPoints: 240,
		predictRadius: 2.5,
		trailRadius: 3.5,
		// 预测线偏冷色；alpha 不能太低 —— 加法混合下行星亮面上会被洗掉（实测）
		predictColor: Color(120, 200, 255, 180),
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
			const verts = projectPolyline(decimate(points, options.maxPoints), options.y, basis, options.layerOriginX, options.layerOriginY);
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
			const verts = projectPolyline(decimate(points, options.maxPoints), options.y, basis, options.layerOriginX, options.layerOriginY);
			drawPolyline(trailDraw, verts, options.trailRadius, options.trailColor);
		},
		clearTrail(): void {
			trailDraw.clear();
			trailCount = 0;
		},
		root,
	};
}
