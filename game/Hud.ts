/**
 * 拖拽矄准与发射（手册 §5.7）。
 *
 * 矄准语义（严格按手册 §5.7，不自行发挥）：
 * - 按下并拖动 → 由“**探测器位置 → 触摸点**”的方向决定发射角；
 * - 拖动距离决定力度（夹紧到 [AimMinSpeed, AimMaxSpeed]）；
 * - 抬起 = 松手 = 发射（不可撤销，愿景 §3）。
 *
 * 职责边界：本模块只负责“把触摸变成发射向量”，**不碰物理、不碰渲染**。
 * 预测线重画由调用方（S1.5 主循环）拿到新向量后自己做。
 *
 * ===== 坐标空间（关键，之前搞错过一次）=====
 *
 * 本模块统一使用**投影偏移空间**，即 `game/Projection.project()` 的输出空间：
 *
 *     offset.x = viewPoint.x - W/2
 *     offset.y = viewPoint.y - H/2     // **+Y 向下**（图像坐标）
 *
 * 为什么用它而不是绝对像素：因为探测器的屏幕位置来自 `project()` 的输出，
 * 直接就是偏移量，不用先加 W/2、H/2 再减回去。
 *
 * 触摸位置（全屏节点局部坐标：左下原点、+Y 向上）→ 偏移空间的换算见
 * `localToOffset()`。这是本模块**唯一需要平台校准**的一处，已隔离成函数。
 *
 * 全部使用**属性式箭头函数类型**，避免 TSTL 为对象成员函数引入隐式 self
 * （见手册 §7.2.1 坑 1）。
 */
import { Node, Size, Vec2 } from 'Dora';
import { CameraBasis, screenToPlaneY } from 'game/Projection';
import { P2 } from 'game/Gravity';
import { AimMaxDragPx, AimMaxSpeed, AimMinSpeed, PlaneToWorldX, PlaneToWorldZ } from 'game/Config';

/** 投影偏移空间中的屏幕点。 */
export interface ScreenOffset {
	x: number;
	y: number;
}

/** 一次矄准的解算结果。 */
export interface AimResult {
	/** 发射速度（平面坐标系的向量）。 */
	velocity: P2;
	/** 力度归一化值 0–1（用于 HUD 显示）。 */
	power: number;
	/** 发射方向单位向量（平面坐标系）。 */
	unit: P2;
}

/**
 * 纯计算：由“探测器屏幕偏移”与“当前触摸屏幕偏移”解算发射向量。
 *
 * 方向语义（手册 §5.7）：发射方向 = **探测器 → 触摸点**。
 * 屏幕上玩家把手指移到探测器**上方**，发射就朝屏幕上方。
 *
 * @param probeOffset 探测器在投影偏移空间中的位置
 * @param touchOffset 触摸点在投影偏移空间中的位置
 * @param maxDragPx 拖动多少像素算满力
 */
export function computeAim(
	probeOffset: ScreenOffset,
	touchOffset: ScreenOffset,
	maxDragPx: number,
): AimResult {
	// 屏幕方向：从探测器指向触摸点（+Y 向下）
	const dx = touchOffset.x - probeOffset.x;
	const dy = touchOffset.y - probeOffset.y;

	const len = Math.sqrt(dx * dx + dy * dy);
	if (len < 1e-6) {
		// 没有拖动：方向取“平面向前”（-y），速度取最小值
		return { velocity: { x: 0, y: -AimMinSpeed }, power: 0, unit: { x: 0, y: -1 } };
	}

	// 屏幕 +Y 向下；平面 +y 对应世界 +z（靠近相机），在屏幕上表现为**向上**。
	// 所以平面方向的 y 分量取屏幕 dy 的**相反数**。
	const ux = dx / len;
	const uy = -dy / len;

	const safeMax = maxDragPx > 1 ? maxDragPx : 1;
	let power = len / safeMax;
	if (power < 0) power = 0;
	if (power > 1) power = 1;

	const speed = AimMinSpeed + (AimMaxSpeed - AimMinSpeed) * power;

	return {
		velocity: { x: ux * speed, y: uy * speed },
		power,
		unit: { x: ux, y: uy },
	};
}

/**
 * 把屏幕位置（**投影偏移空间**，与 `project()` 同空间）转成平面坐标。
 *
 * 不是矄准必需（矄准只用方向），但调试与关卡设计时有用。
 * 与 `project()` 互逆（已有往返测试守着）。
 */
export function screenToPlane(
	viewPoint: ScreenOffset,
	basis: CameraBasis,
): P2 | undefined {
	const world = screenToPlaneY(viewPoint, basis, 0);
	if (world === undefined) return undefined;
	// 世界 → 平面（与 Scene.planeToWorld 互为逆）
	return { x: world.x / PlaneToWorldX, y: world.z / PlaneToWorldZ };
}

/** 默认的力度→拖动像素映射（供 UI 层统一引用）。 */
export function defaultMaxDragPx(): number {
	return AimMaxDragPx;
}

/** 默认速度区间（供 UI 层展示）。 */
export function defaultSpeedRange(): { min: number; max: number } {
	return { min: AimMinSpeed, max: AimMaxSpeed };
}

/** 视图逻辑宽高。 */
export interface TouchSpace {
	viewW: number;
	viewH: number;
}

/**
 * 全屏输入节点的局部坐标 → 投影偏移空间。
 *
 * 两个空间的差异（已核对 `Projection.ts` 的 R4 标定结论）：
 *
 * | | 原点 | 范围 | Y 方向 |
 * |---|---|---|---|
 * | 全屏节点局部坐标 | **左下角** | [0,W]×[0,H] | **+Y 向上** |
 * | 投影偏移空间 | **屏幕中心** | ±W/2, ±H/2 | **+Y 向下** |
 *
 * 换算：`offset.x = local.x - W/2`，`offset.y = H/2 - local.y`。
 */
export function localToOffset(local: ScreenOffset, space: TouchSpace): ScreenOffset {
	return { x: local.x - space.viewW / 2, y: space.viewH / 2 - local.y };
}

/** 反向换算（投影偏移空间 → 全屏节点局部坐标）。 */
export function offsetToLocal(offset: ScreenOffset, space: TouchSpace): ScreenOffset {
	return { x: offset.x + space.viewW / 2, y: space.viewH / 2 - offset.y };
}

/**
 * 拖拽矄准的输入句柄。
 *
 * 全部用**属性式箭头函数类型**（不用方法语法），这样 TSTL 不会引入隐式 self，
 * 也不会出现“无 this 的函数不能赋给带 this 的成员”的转换错误
 * （self-parameter 教程 §3）。
 */
export interface AimInput {
	/** 注册拖动回调（拖动中每次移动触发）。 */
	onDrag: (callback: (aim: AimResult) => void) => void;
	/** 松手（发射）回调。不可撤销。 */
	onRelease: (callback: (aim: AimResult) => void) => void;
	/** 是否监听输入（矄准态才开，飞行/结算态要关）。 */
	setEnabled: (enabled: boolean) => void;
	/** 当前矄准结果（未拖动时是默认值）。 */
	current: () => AimResult;
	/**
	 * 设定探测器当前的屏幕位置（**投影偏移空间**）。
	 * 每帧由主循环根据相机投影更新。
	 */
	setProbeOffset: (offset: ScreenOffset) => void;
	/**
	 * 直接以“全屏节点局部坐标”驱动一次拖动。
	 *
	 * 用途：键盘控制降级、回放，以及无头测试（`Touch` 无法程序化构造，
	 * 因此不能 `emit` 真触摸事件）。这是为“输入源可替换”保留的缝隙。
	 */
	handleLocal: (local: ScreenOffset) => void;
	/** 直接以“投影偏移空间坐标”驱动一次拖动（测试用，跳过坐标转换）。 */
	handleOffset: (offset: ScreenOffset) => void;
	/** 根节点：调用方自行 addChild 到想要的层级。 */
	root: Node.Type;
}

/**
 * 创建拖拽矄准输入层。
 *
 * ### 为何要一个带尺寸的全屏节点
 * `touch.location` 是**接收节点局部坐标**。若直接挂在未设尺寸的
 * `Director.ui` 根上，其局部坐标就是屏幕中心原点（+Y 向上），
 * 与投影空间不一致，容易搞错。这里用一个 `size = View.size`、
 * `anchor = (0.5,0.5)` 的全屏节点，使 `touch.location` 落在
 * `[0,W]×[0,H]`、左下原点、+Y 向上，再用 `localToOffset()` 显式换算。
 *
 * @param parent 挂载父节点（通常是 Director.ui）
 * @param viewW 视图宽（`View.size.width`）
 * @param viewH 视图高（`View.size.height`）
 */
export function createAimInput(
	parent: Node.Type,
	viewW: number,
	viewH: number,
): AimInput {
	const root = Node();
	root.size = Size(viewW, viewH);
	root.anchor = Vec2(0.5, 0.5);
	root.position = Vec2(0, 0);

	// 一个不可见的全屏层，只用来接收触摸。
	const touchLayer = Node();
	touchLayer.size = Size(viewW, viewH);
	touchLayer.anchor = Vec2(0.5, 0.5);
	touchLayer.position = Vec2(viewW / 2, viewH / 2);
	touchLayer.touchEnabled = true;
	touchLayer.swallowTouches = true;
	root.addChild(touchLayer);

	const space: TouchSpace = { viewW, viewH };

	let enabled = false;
	let dragging = false;
	let aim: AimResult = { velocity: { x: 0, y: -AimMinSpeed }, power: 0, unit: { x: 0, y: -1 } };

	// 探测器屏幕偏移：由调用方在拖动前/每帧设定。
	let probeOffset: ScreenOffset = { x: 0, y: 0 };

	let dragHandler: ((a: AimResult) => void) | undefined = undefined;
	let releaseHandler: ((a: AimResult) => void) | undefined = undefined;

	const handleOffset = (offset: ScreenOffset): void => {
		aim = computeAim(probeOffset, offset, AimMaxDragPx);
		if (dragHandler !== undefined) dragHandler(aim);
	};

	touchLayer.onTapBegan((touch) => {
		if (!enabled) return;
		dragging = true;
		handleOffset(localToOffset({ x: touch.location.x, y: touch.location.y }, space));
	});

	touchLayer.onTapMoved((touch) => {
		if (!enabled || !dragging) return;
		handleOffset(localToOffset({ x: touch.location.x, y: touch.location.y }, space));
	});

	touchLayer.onTapEnded((touch) => {
		if (!enabled || !dragging) return;
		dragging = false;
		handleOffset(localToOffset({ x: touch.location.x, y: touch.location.y }, space));
		if (releaseHandler !== undefined) releaseHandler(aim);
	});

	parent.addChild(root);

	return {
		onDrag: (callback: (a: AimResult) => void): void => {
			dragHandler = callback;
		},
		onRelease: (callback: (a: AimResult) => void): void => {
			releaseHandler = callback;
		},
		setEnabled: (value: boolean): void => {
			enabled = value;
			if (!value) dragging = false;
		},
		current: (): AimResult => aim,
		setProbeOffset: (offset: ScreenOffset): void => {
			probeOffset = offset;
		},
		handleLocal: (local: ScreenOffset): void => {
			handleOffset(localToOffset(local, space));
		},
		// 包一层箭头函数：简写属性会让 TSTL 为对象成员函数引入 self
		handleOffset: (offset: ScreenOffset): void => handleOffset(offset),
		root,
	};
}
