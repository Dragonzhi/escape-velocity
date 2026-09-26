/**
 * 拖拽矄准与发射（手册 §5.7）。
 *
 * 矄准语义（手册 §5.7，2026-09-24 按用户真机反馈改为**相对拖动**）：
 * - 按下点即“摇杆零点”：按下瞬间瞄准**归零到直飞**（正对目标、最小力度）；
 * - 之后的**位移**（相对按下点）决定方向与力度 —— 所以**按在哪里都能瞄**；
 * - 位移方向 = 发射方向（屏幕上 = 直飞，右 = 右偏），位移长度 = 力度（夹紧到 [AimMinSpeed, AimMaxSpeed]）；
 * - 抬起 = 松手 = 发射（不可撤销，愿景 §3）。
 *
 * 为什么不用“探测器 → 触摸点”的绝对方向（旧模型）：真机上按下位置与探测器位置无关联，
 * 玩家一按就已经按距离拿到了力度、方向也由按下点决定，手感与预期不符。
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
import { Color, DrawNode, Node, Size, Touch, Vec2 } from 'Dora';
import { CameraBasis, screenToPlaneY } from 'game/Projection';
import { P2 } from 'game/Gravity';
import { AimMaxDragPx, AimMaxSpeed, AimMinSpeed, PlaneToWorldX, PlaneToWorldZ } from 'game/Config';
import { ResultKind } from 'game/Game';
import { MinButtonHeight, MinButtonWidth, UiButton, createButton, createLabel, createPanel, setLabelCenter, setLabelColor, setLabelText } from 'game/Ui';

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
 * @param maxSpeed 满力对应的速度（= 这一关的 Δv 预算）；省略 = 全局上限 `AimMaxSpeed`
 */
export function computeAim(
	probeOffset: ScreenOffset,
	touchOffset: ScreenOffset,
	maxDragPx: number,
	maxSpeed?: number,
): AimResult {
	const speedTop = maxSpeed !== undefined && maxSpeed > AimMinSpeed ? maxSpeed : AimMaxSpeed;
	// 方向：从探测器指向触摸点（手册 §5.7）。
	// 屏幕偏移空间是中心原点 +Y 向上（与 project() 一致，见 Projection.ts 约定 5）。
	// 修正后的渲染方向：世界 -z（远离相机 = 平面 -y = 朝目标）在屏幕**上方**。
	// 所以触摸在探测器上方（dy < 0）= 朝目标发射（平面 -y，uy < 0）。
	const dx = touchOffset.x - probeOffset.x;
	const dy = touchOffset.y - probeOffset.y;

	const len = Math.sqrt(dx * dx + dy * dy);
	if (len < 1e-6) {
		// 没有拖动：方向取“平面向前”（-y，朝目标），速度取最小值
		return { velocity: { x: 0, y: -AimMinSpeed }, power: 0, unit: { x: 0, y: -1 } };
	}

	const ux = dx / len;
	// ⚠️ 保留负号（修正后的推导）：偏移空间 +Y 向上，而修正后的渲染是
	 // 平面 -y（朝目标）在屏幕上方 = 偏移 +y。即平面 y 轴与偏移 y 轴**反向**。
	 // 所以“拖向目标”（dy > 0）→ 平面 -y（uy < 0）需要取相反数。
	 // （S2 修投影镜像时曾误删此负号，被 HudTest 当场抓回。）
	const uy = -dy / len;

	const safeMax = maxDragPx > 1 ? maxDragPx : 1;
	let power = len / safeMax;
	if (power < 0) power = 0;
	if (power > 1) power = 1;

	const speed = AimMinSpeed + (speedTop - AimMinSpeed) * power;

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
 * 全屏输入节点的局部坐标 → 投影偏移空间（中心原点、+Y 向上）。
 *
 * 两个空间的差异（已核对 `Projection.ts` 的修正后约定）：
 *
 * | | 原点 | 范围 | Y 方向 |
 * |---|---|---|---|
 * | 全屏节点局部坐标 | **左下角** | [0,W]×[0,H] | **+Y 向上** |
 * | 投影偏移空间 | **屏幕中心** | ±W/2, ±H/2 | **+Y 向上** |
 *
 * 换算：`offset.x = local.x - W/2`，`offset.y = local.y - H/2`。
 */
export function localToOffset(local: ScreenOffset, space: TouchSpace): ScreenOffset {
	return { x: local.x - space.viewW / 2, y: local.y - space.viewH / 2 };
}

/** 反向换算（投影偏移空间 → 全屏节点局部坐标）。 */
export function offsetToLocal(offset: ScreenOffset, space: TouchSpace): ScreenOffset {
	return { x: offset.x + space.viewW / 2, y: offset.y + space.viewH / 2 };
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
	// （S3.10 删掉了 onRelease：松手不再等于发射 —— 改走 onAimReady + 「发射」按钮的 onLaunch）
	/** 是否监听输入（矄准态才开，飞行/结算态要关）。 */
	setEnabled: (enabled: boolean) => void;
	/** 当前矄准结果（未拖动时是默认值）。 */
	current: () => AimResult;
	/**
	 * 设定探测器当前的屏幕位置（**投影偏移空间**）。每帧由主循环更新。
	 *
	 * ⚠️ 相对拖动模型下瞄准**不再**用它（方向只由"相对按下点的位移"决定）；
	 * 保留供诊断（见 `debugProbeOffset`）与将来可能的手柄 UI 使用。
	 */
	setProbeOffset: (offset: ScreenOffset) => void;
	/**
	 * 直接以“全屏节点局部坐标”驱动一次拖动。
	 *
	 * 用途：键盘控制降级、回放，以及无头测试（`Touch` 无法程序化构造，
	 * 因此不能 `emit` 真触摸事件）。这是为“输入源可替换”保留的缝隙。
	 */
	handleLocal: (local: ScreenOffset) => void;
	/**
	 * 读取瞄准数学使用的探测器屏幕偏移（**投影偏移空间**，中心原点 +Y 向上）。
	 * 仅供诊断与回归脚本使用（例如与截图里探测器的实际像素位置比对）。
	 */
	debugProbeOffset: () => ScreenOffset;
	/** 直接以“投影偏移空间坐标”驱动一次拖动（测试用，跳过坐标转换）。 */
	handleOffset: (offset: ScreenOffset) => void;
	/**
	 * 刹车模式（S3.9.2）：注册"点了刹车按钮"的回调；init 把它接到 `Game.setBrakeMode`。
	 * 按钮只负责表达意图，不碰 GameCore（分层原则见手册 §4.1）。
	 */
	onBrake: (callback: (on: boolean) => void) => void;
	/** 由主循环同步当前刹车状态（切关卡/重试后按钮文字要跟着变）。 */
	setBrake: (on: boolean) => void;
	/**
	 * 是否正在操控（S3.9.4）：没在拖的时候世界照常走（探测器绕地球转），
	 * 一按下就冻结 —— 玩家看到的预测线永远是他"此刻"要发的这一发。
	 */
	isDragging: () => boolean;
	/** 更新 Δv 读数（本次点火要花多少 / 这一关给了多少），拖动时由主循环调用。 */
	setBurnInfo: (burn: number, budget: number) => void;
	/**
	 * 瞄准完成（松手）：S3.10 起**不直接发射**，而是进入 Armed（由 Game 决定），
	 * 屏幕上出现「发射」按钮，点它才真的打出去。
	 */
	onAimReady: (callback: (a: AimResult) => void) => void;
	/** 观察拖动（每帧增量，像素）：非"探测器附近"的拖动会送到这里转相机。 */
	onObserve: (callback: (dx: number, dy: number) => void) => void;
	/** 捏合缩放（引擎的 onGesture 的 deltaDist）。 */
	onZoom: (callback: (deltaDist: number) => void) => void;
	/** 「发射」按钮被点（右下角，只在 Armed 态出现）。 */
	onLaunch: (callback: () => void) => void;
	/** 由主循环同步 Armed 状态：按钮显隐 + 触摸开关都跟着它走。 */
	setArmed: (armed: boolean) => void;
	/**
	 * 时间流按钮（S3.9.4）：回调收到 -1（回退）/ 0（松手）/ +1（加速）。
	 * 只有带 `timeWindow` 的关卡才启用；别的关卡整块隐藏**且断触摸**。
	 */
	onWarp: (callback: (dir: number) => void) => void;
	/**
	 * 设置滑杆的量程与当前值：`span <= 0` = 这一关没有时间轴 ⇒ 滑杆整块隐藏且**断触摸**。
	 * （隐藏而不关触摸的层会吞掉整个区域的点击 —— 真机验收踩过，见 AGENTS 硬约束 4。）
	 */
	setDate: (t0: number, span: number) => void;
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
	/** 满力速度 = 这一关的 Δv 预算（S3.9.2b）；省略 = 全局上限 */
	maxSpeed?: number,
): AimInput {
	const speedTop = maxSpeed !== undefined && maxSpeed > AimMinSpeed ? maxSpeed : AimMaxSpeed;
	const root = Node();
	root.size = Size(viewW, viewH);
	// ⚠️ anchor 必须是 (0,0)：子节点坐标以“位置 − anchor×尺寸”为原点，
	// (0.5,0.5) 会把整棵子树再推走半个屏幕 —— 触摸命中框因此只剩左下象限
	// （真机表现：“不是按哪里都能瞄”：view x > W/2 或 y > H/2 处按下无效）。
	// 父层（levelLayers[i]）的子空间是“左下原点绝对像素”，取 (0,0) 后命中框
	// 正好等于整屏 [0,W]×[0,H]，且 touch.location 与 localToOffset 的假设一致。
	root.anchor = Vec2(0, 0);
	root.position = Vec2(0, 0);

	// 一个不可见的全屏层，只用来接收触摸。
	const touchLayer = Node();
	touchLayer.size = Size(viewW, viewH);
	touchLayer.anchor = Vec2(0.5, 0.5);
	touchLayer.position = Vec2(viewW / 2, viewH / 2);
	touchLayer.swallowTouches = true;
	root.addChild(touchLayer);

	const space: TouchSpace = { viewW, viewH };

	let enabled = false;
	let dragging = false;
	let aim: AimResult = { velocity: { x: 0, y: -AimMinSpeed }, power: 0, unit: { x: 0, y: -1 } };

	// 探测器屏幕偏移：由调用方在拖动前/每帧设定。
	let probeOffset: ScreenOffset = { x: 0, y: 0 };

	let dragHandler: ((a: AimResult) => void) | undefined = undefined;
	let readyHandler: ((a: AimResult) => void) | undefined = undefined;
	let observeHandler: ((dx: number, dy: number) => void) | undefined = undefined;
	let zoomHandler: ((deltaDist: number) => void) | undefined = undefined;
	let launchHandler: (() => void) | undefined = undefined;

	// ---- 相对拖动模型（用户 2026-09-24 真机反馈后确定）----
	//
	// 按下点 = 摇杆零点：按下瞬间**瞄准归零到"直飞"**（正对目标、最小力度），
	// 之后的位移（相对按下点）才决定方向与力度，因此**按在哪里都能瞄**，
	// 且松手才发射。旧模型是"探测器 → 手指"的绝对方向，按下即按距离给力度，
	// 与手感预期不符（真机反馈："按下的地方不是飞行器所在的地方"）。
	//
	// 位移语义复用 computeAim：把按下点当作它的 probeOffset，则
	//   方向 = 位移方向（屏幕上方 = 直飞，向右 = 右偏），力度 = |位移| / AimMaxDragPx。
	let pressOffset: ScreenOffset = { x: 0, y: 0 };

	/** 用"相对按下点的位移"驱动一次瞄准（位移为 0 时即 computeAim 的中性解 = 直飞）。 */
	const handleDelta = (delta: ScreenOffset): void => {
		aim = computeAim({ x: 0, y: 0 }, delta, AimMaxDragPx, speedTop);
		if (dragHandler !== undefined) dragHandler(aim);
	};

	// ---- 瞄准 / 观察 分区（S3.10）----
	// 用户定稿：**预测线默认不显示**，只有在"探测器附近"按下拖动才是瞄准；
	// 其他地方拖动 = 转观察视角。只用一个全屏层，**按按下点判模式** ——
	// 开两层（一层瞄准一层观察）必然互相吞点击（AGENTS 硬约束 4）。
	const aimRadius = Math.max(96, viewW * 0.25); // 屏宽 1/4（用户拍板）
	let mode: 'none' | 'aim' | 'observe' = 'none';
	let observeLast: ScreenOffset = { x: 0, y: 0 };
	touchLayer.onTapBegan((touch) => {
		if (!enabled) return;
		const at = localToOffset({ x: touch.location.x, y: touch.location.y }, space);
		const dx = at.x - probeOffset.x;
		const dy = at.y - probeOffset.y;
		if (Math.sqrt(dx * dx + dy * dy) <= aimRadius) {
			mode = 'aim';
			dragging = true;
			pressOffset = at;
			// 按下即回到直飞：立刻让预测线显示中性方向（不等到第一次移动）
			handleDelta({ x: 0, y: 0 });
		} else {
			mode = 'observe';
			observeLast = at;
		}
	});

	touchLayer.onTapMoved((touch) => {
		if (!enabled) return;
		const cur = localToOffset({ x: touch.location.x, y: touch.location.y }, space);
		if (mode === 'aim' && dragging) {
			handleDelta({ x: cur.x - pressOffset.x, y: cur.y - pressOffset.y });
		} else if (mode === 'observe') {
			// 观察：把增量交给相机（像素增量，Game 里换算成角度）
			if (observeHandler !== undefined) observeHandler(cur.x - observeLast.x, cur.y - observeLast.y);
			observeLast = cur;
		}
	});

	touchLayer.onTapEnded((touch) => {
		if (!enabled) return;
		const cur = localToOffset({ x: touch.location.x, y: touch.location.y }, space);
		if (mode === 'aim') {
			dragging = false;
			handleDelta({ x: cur.x - pressOffset.x, y: cur.y - pressOffset.y });
			// ⚠️ S3.10：松手**不发射** —— 交给 Game 决定是不是进入 Armed（用户定的交互）
			if (readyHandler !== undefined) readyHandler(aim);
		}
		mode = 'none';
	});

	// 捏合缩放：引擎自带的多点手势（d.ts: onGesture(center, numFingers, deltaDist, deltaAngle)）
	touchLayer.onGesture((_center: Vec2.Type, numFingers: number, deltaDist: number, _deltaAngle: number): void => {
		if (!enabled || numFingers < 2) return;
		if (zoomHandler !== undefined) zoomHandler(deltaDist);
	});

	// ⚠️ 必须在**注册完触摸回调之后**再关掉触摸：onTapBegan/onTapMoved/onTapEnded
	// 各会把 node.touchEnabled 置为 true（引擎行为）。
	// 多关并存时，未激活关卡的触摸层若开着 touchEnabled + swallowTouches，
	// 会把整个屏幕的点击独占（被点到的节点独占触摸），表现为
	// “切到第二关后怎么拖都没反应”。
	touchLayer.touchEnabled = false;

	// ---- 刹车模式开关（S3.9.2）----
	// 位置：右上角。⚠️ 必须在 touchLayer **之后** addChild：Dora 的命中按节点顺序取最上面的那个，
	// 放在前面会被全屏的触摸层独吞（"按钮点不到、只当成一次瞄准拖动"）。
	let brakeHandler: ((on: boolean) => void) | undefined = undefined;
	const BrakeButtonW = 116;
	const BrakeButtonH = 64;
	const brakeGap = 8;
	// ⚠️ 为什么是**两个按钮**而不是一个开关：实测一次合成点击会被引擎投递两次
	//    （鼠标 + 触摸两条路）⇒ 单按钮的"取反"会开了又关（净效果 = 没反应）。
	//    两段式天然幂等：双击同一侧只是把同一个状态设两遍。
	const brakeButtons: UiButton[] = [];
	const makeBrakeButton = (text: string, on: boolean, x: number): void => {
		const btn = createButton(root, {
			w: BrakeButtonW,
			h: BrakeButtonH,
			text,
			fontSize: 30,
			bgHex: ResultButtonAltBgHex,
			fgHex: ResultButtonFgHex,
			borderHex: ResultButtonBorderHex,
			onTap: (): void => {
				// 先更新本地状态并重绘，再通知外面 —— 只通知的话按钮颜色不会跟着变
				// （实测：状态切了、日志也对，但玩家看不出自己点中了哪一个）。
				brakeOn = on;
				paintBrake();
				if (brakeHandler !== undefined) brakeHandler(on);
			},
		});
		btn.root.position = Vec2(x, viewH - BrakeButtonH - 20);
		brakeButtons.push(btn);
	};
	let brakeOn = false;
	const paintBrake = (): void => {
		if (brakeButtons.length < 2) return;
		brakeButtons[0].setColors(brakeOn ? ResultButtonAltBgHex : ResultButtonBgHex, ResultButtonFgHex);
		brakeButtons[1].setColors(brakeOn ? ResultButtonBgHex : ResultButtonAltBgHex, ResultButtonFgHex);
	};
	// ---- Δv 读数（S3.9.2b 用户："德塔V的限制没有 UI 的显示，不明不白"）----
	// 左上角一行字：本次点火要花多少 / 这一关给了多少；拖动时实时更新。
	const dvLabel = createLabel(root, 'Δv — / —', 30, ResultHintHex);
	if (dvLabel !== undefined) {
		dvLabel.position = Vec2(24, viewH - 44);
		dvLabel.anchor = Vec2(0, 0);
	}

	// ---- 时间流：加速 / 回退（S3.9.4，用户提议替换日期滑杆）----
	// 为什么不是滑杆：滑杆是"瞬间跳到某个日期"，而这一版的核心是**时间在流**（探测器绕地球待机）。
	// 两者语义打架 —— 用户自己也指出来了。改成"按住即走"的两个按钮：等窗口时转时间，松手就停。
	// 只有带 `timeWindow` 的关卡才启用；别的关卡整块隐藏**且断触摸**（AGENTS 硬约束 4）。
	let warpHandler: ((dir: number) => void) | undefined = undefined;
	let dateSpan = 0;
	const WarpButtonW = 116;
	const WarpButtonH = 64;
	const warpButtons: UiButton[] = [];
	const makeWarpButton = (text: string, dir: number, x: number): void => {
		const btn = createButton(root, {
			w: WarpButtonW,
			h: WarpButtonH,
			text,
			fontSize: 30,
			bgHex: ResultButtonAltBgHex,
			fgHex: ResultButtonFgHex,
			borderHex: ResultButtonBorderHex,
			onTap: (): void => {
				// 按一次 = 时间走一步（步长在 Config.TimeWarpStep）
				if (warpHandler !== undefined) warpHandler(dir);
			},
		});
		// ⚠️ 不能自己往 root 上挂 onTapBegan/onTapEnded：`createButton` 内部已经注册过，
		// 后注册会把它的处理器顶掉（实测：按下去既没视觉反馈、也拿不到回调）。
		// 走它自己的 `onTap`（松手时触发）—— 这也是"两个按钮"该有的语义：按一次，时间走一步。
		btn.root.position = Vec2(x, viewH - 96 - WarpButtonH);
		warpButtons.push(btn);
	};
	const warpLeftX = viewW - (WarpButtonW * 2 + 8) - 20;
	makeWarpButton('◀ 回退', -1, warpLeftX);
	makeWarpButton('加速 ▶', 1, warpLeftX + WarpButtonW + 8);
	const dateLabel = createLabel(root, '发射日期 —', 30, ResultHintHex);
	if (dateLabel !== undefined) {
		dateLabel.position = Vec2(24, viewH - 96 - WarpButtonH + 16);
		dateLabel.anchor = Vec2(0, 0);
	}

	// ---- 「发射」按钮（S3.10，右下角拇指区；只在 Armed 态出现）----
	// ⚠️ 用户已定：按钮之后都要换成**图标**（竖屏文字太占地方）。这里是文字占位。
	const LaunchButtonW = 200;
	const LaunchButtonH = 96;
	const launchButton = createButton(root, {
		w: LaunchButtonW,
		h: LaunchButtonH,
		text: '发射',
		fontSize: 44,
		bgHex: ResultButtonBgHex,
		fgHex: ResultButtonFgHex,
		borderHex: ResultButtonBorderHex,
		onTap: (): void => {
			// 防抖在 Ui.createButton 里（0.5 秒）；这里再加一道状态守卫（见 Game.launchArmed）
			if (launchHandler !== undefined) launchHandler();
		},
	});
	launchButton.root.position = Vec2(viewW - LaunchButtonW - 24, 96);
	launchButton.root.visible = false;
	launchButton.setEnabled(false); // 隐藏 + 断触摸（硬约束 4）

	const brakeRightX = viewW - BrakeButtonW - 20;
	makeBrakeButton('惯性', false, brakeRightX - BrakeButtonW - brakeGap);
	makeBrakeButton('刹车', true, brakeRightX);
	paintBrake();

	parent.addChild(root);

	return {
		onDrag: (callback: (a: AimResult) => void): void => {
			dragHandler = callback;
		},
		setEnabled: (value: boolean): void => {
			enabled = value;
			// 触摸开关必须跟着走：swallowTouches 的层只要开着，就会把点击独占，
			// 底下的关卡层永远收不到（多关并存时这是致命的）
			touchLayer.touchEnabled = value;
			if (!value) dragging = false;
		},
		onBrake: (callback: (on: boolean) => void): void => {
			brakeHandler = callback;
		},
		setBrake: (on: boolean): void => {
			brakeOn = on;
			paintBrake();
		},
		onAimReady: (callback: (a: AimResult) => void): void => {
			readyHandler = callback;
		},
		onObserve: (callback: (dx: number, dy: number) => void): void => {
			observeHandler = callback;
		},
		onZoom: (callback: (deltaDist: number) => void): void => {
			zoomHandler = callback;
		},
		onLaunch: (callback: () => void): void => {
			launchHandler = callback;
		},
		setArmed: (armed: boolean): void => {
			launchButton.root.visible = armed;
			launchButton.setEnabled(armed);
		},
		onWarp: (callback: (dir: number) => void): void => {
			warpHandler = callback;
		},
		setDate: (t0: number, span: number): void => {
			dateSpan = span > 0 ? span : 0;
			const on = dateSpan > 0;
			for (const b of warpButtons) {
				b.root.visible = on;
				b.setEnabled(on); // 隐藏 + 断触摸（AGENTS 硬约束 4）
			}
			if (dateLabel !== undefined) dateLabel.visible = on;
			setLabelText(dateLabel, on ? '发射日期 ' + t0.toFixed(0) + ' / ' + dateSpan.toFixed(0) + ' 秒' : '发射日期');
		},
		isDragging: (): boolean => dragging,
		setBurnInfo: (burn: number, budget: number): void => {
			setLabelText(dvLabel, 'Δv ' + burn.toFixed(1) + ' / ' + budget.toFixed(0));
		},
		current: (): AimResult => aim,
		setProbeOffset: (offset: ScreenOffset): void => {
			probeOffset = offset;
		},
		// 程序化缝隙（键盘降级/回放/无头测试）：参数是**相对按下点的位移**，
		// 不是绝对屏幕位置 —— 与真实拖动同语义。
		handleLocal: (local: ScreenOffset): void => {
			handleDelta(localToOffset(local, space));
		},
		// 包一层箭头函数：简写属性会让 TSTL 为对象成员函数引入 self
		handleOffset: (delta: ScreenOffset): void => handleDelta(delta),
		debugProbeOffset: (): ScreenOffset => probeOffset,
		root,
	};
}

// ---------------------------------------------------------------------------
// S2.2 结算面板 / S2.3 关卡选择
//
// 这两个 UI 只做两件事：**把三态文案与解锁状态显示出来**、**把点按变成意图回调**
// （onRetry / onBackToSelect / onPick）。它们不碰 GameCore，也不读存档 ——
// 状态推进由 init.ts 串起来（手册 §4.1 分层原则 3）。
//
// 文案（逐字，改之前先改手册 §5.8 / PLAN）：
//   结算：关卡名 / 借力成功·错过目标·信号中断 / 对应说明句
//   按钮：重试本关（上·主位）、返回关卡选择（下）
//   关卡选择：选择任务 / 已解锁 N / 6 / 完成一关即解锁下一关 / 未解锁后缀
// ---------------------------------------------------------------------------

const ResultBackdropHex = 0x05070c;
const ResultCardHex = 0x131c2b;
const ResultCardBorderHex = 0x33507a;
const ResultLevelHex = 0x8fb4dc;
const ResultBodyHex = 0xd7e6f7;
const ResultHintHex = 0x7d93ab;
const ResultButtonBgHex = 0x1d4a7a;
const ResultButtonAltBgHex = 0x1b2735;
const ResultButtonFgHex = 0xeaf4ff;
const ResultButtonBorderHex = 0x4f86c6;
const TitleSuccessHex = 0x7fe3a0;
const TitleMissedHex = 0xffd479;
const TitleCrashedHex = 0xff7a6b;

const SelectBackdropHex = 0x05070c;
const SelectTitleHex = 0xffffff;
const SelectSubtitleHex = 0x9fc4e8;
const SelectHintHex = 0x6f88a6;
const SelectOpenBgHex = 0x1d4a7a;
const SelectOpenFgHex = 0xeaf4ff;
const SelectLockedBgHex = 0x151b24;
const SelectLockedFgHex = 0x69788c;
const SelectBorderHex = 0x3f6ea8;

/** 夹紧到 [lo, hi]（NaN 会原样穿过去，所以调用方必须传已校验的数）。 */
function clampNumber(value: number, lo: number, hi: number): number {
	if (value < lo) return lo;
	if (value > hi) return hi;
	return value;
}

/** 三态标题（逐字，手册 §5.8）。 */
function resultTitle(result: ResultKind): string {
	if (result === 'success') return '借力成功';
	if (result === 'crashed') return '信号中断';
	return '错过目标';
}

/** 三态说明句（逐字）。 */
function resultBody(result: ResultKind): string {
	if (result === 'success') return '行星把探测器甩了出去，速度够了。';
	if (result === 'crashed') return '探测器撞上行星，任务到此为止。';
	return '从行星身侧掠过，没能借到那一点速度。';
}

/** 标题配色：成功偏青绿、错过偏暖黄、撞毁偏红。 */
function resultTitleColor(result: ResultKind): number {
	if (result === 'success') return TitleSuccessHex;
	if (result === 'crashed') return TitleCrashedHex;
	return TitleMissedHex;
}

/**
 * 第四行提示（面板自有文案，不属于三态说明句）。
 *
 * 为什么要有这一行：解锁是 S2.3 的核心反馈，玩家成功时必须**当场**看到
 * “下一关开了”，否则只会以为“回到关卡选择还要自己找”。
 */
function resultHint(result: ResultKind): string {
	if (result === 'success') return '下一关已解锁';
	return '可重试本关，或返回关卡选择';
}

/** 结算面板的装配参数。 */
export interface ResultPanelOptions {
	onRetry: () => void;
	onBackToSelect: () => void;
}

/** 结算面板句柄。 */
export interface ResultPanel {
	/** 根节点（全屏半透明底），调用方自行 addChild 到想要的层级。 */
	root: Node.Type;
	show: (result: ResultKind, levelName: string) => void;
	hide: () => void;
}

/**
 * 建结算面板：半透明全屏底 + 居中卡片（宽 = 0.88 × 视宽）+ 4 行内容 + 2 个按钮。
 *
 * ⚠️ 全屏底**不能**设 `touch: true`（真机验收踩到的坑）：
 * 全屏 + `swallowTouches` 的节点会独占它覆盖范围内的点击，而节点树里它排在瞄准层之前；
 * 只要它存在，进入关卡后怎么拖都没反应（表现为“进关卡不能拖动飞行器”）。
 * 不需要它吞点击：结算态瞄准层本来就已 `setEnabled(false)`（Flying 起就关），
 * 能点的只有卡片里那两个按钮。
 *
 * @param viewW 视图逻辑宽（`View.size.width`）
 * @param viewH 视图逻辑高
 */
export function createResultPanel(
	parent: Node.Type,
	viewW: number,
	viewH: number,
	opts: ResultPanelOptions,
): ResultPanel {
	const root = createPanel(parent, viewW, viewH, ResultBackdropHex, { alpha: 0.78 });

	// 尺寸全部按视图逻辑像素推导：竖屏 601×1066 到桌面 2024×1230 都要能看。
	// ⚠️ 按钮宽度必须**留在卡片内**：早前写成 max(560, …)，竖屏卡片只有 529 宽，
	// 按钮横向戳出卡片外（真机竖屏实测截图可见）。
	const cardW = viewW * 0.88;
	const btnW = clampNumber(cardW - 60, MinButtonWidth, 900);
	let btnH = clampNumber(viewH * 0.13, MinButtonHeight, 150);
	const padX = (cardW - btnW) / 2;
	const padY = 44;

	const fontLevel = 34;
	const fontTitle = 66;
	const fontBody = 34;
	const fontHint = 30;
	const btnFont = 40;
	const rowGap = 26;

	// 行高按“字号 + 余量”给；说明句预留两行，窄屏换行时不会被按钮压住
	const hLevel = fontLevel + 10;
	const hTitle = fontTitle + 18;
	const hBody = fontBody * 2 + 12;
	const hHint = fontHint + 10;
	let cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22;
	// 卡片不得超出屏幕：超了先压按钮高度（最大项），而不是让内容被裁掉
	if (cardH > viewH - 24) {
		btnH = Math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2);
		cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22;
	}

	const card = createPanel(root, cardW, cardH, ResultCardHex, {
		alpha: 0.97,
		borderHex: ResultCardBorderHex,
		borderWidth: 3,
	});
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2);

	// 垂直排版：卡片局部坐标是**左下原点**，所以从顶部往下累减
	let cursor = cardH - padY;

	cursor -= hLevel;
	const levelLabel = createLabel(card, '', fontLevel, ResultLevelHex);
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2);

	cursor -= rowGap + hTitle;
	const titleLabel = createLabel(card, '', fontTitle, TitleSuccessHex);
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2);

	cursor -= rowGap + hBody;
	const bodyLabel = createLabel(card, '', fontBody, ResultBodyHex);
	setLabelCenter(bodyLabel, cardW / 2, cursor + hBody / 2);
	if (bodyLabel !== undefined) bodyLabel.textWidth = cardW - 80;

	cursor -= rowGap + hHint;
	const hintLabel = createLabel(card, '', fontHint, ResultHintHex);
	setLabelCenter(hintLabel, cardW / 2, cursor + hHint / 2);

	// 按钮：重试本关在上（主位，拇指落点），返回关卡选择在下
	cursor -= rowGap + btnH;
	const retryButton = createButton(card, {
		w: btnW,
		h: btnH,
		text: '重试本关',
		fontSize: btnFont,
		bgHex: ResultButtonBgHex,
		fgHex: ResultButtonFgHex,
		borderHex: ResultButtonBorderHex,
		onTap: opts.onRetry,
	});
	retryButton.root.position = Vec2(padX, cursor);

	cursor -= 22 + btnH;
	const backButton = createButton(card, {
		w: btnW,
		h: btnH,
		text: '返回关卡选择',
		fontSize: btnFont,
		bgHex: ResultButtonAltBgHex,
		fgHex: ResultButtonFgHex,
		borderHex: ResultButtonBorderHex,
		onTap: opts.onBackToSelect,
	});
	backButton.root.position = Vec2(padX, cursor);

	root.visible = false;
	// ⚠️ 创建即禁用：面板在第一次 show() 之前也处于树里，若按钮此刻是可点的，
	// 隐藏面板会继续参与命中并吞掉覆盖区域的点击（真机验收踩到的坑）。
	retryButton.setEnabled(false);
	backButton.setEnabled(false);

	return {
		root,
		show: (result: ResultKind, levelName: string): void => {
			// 只让面板在显示时才可点（见 hide 的兜底说明）
			retryButton.setEnabled(true);
			backButton.setEnabled(true);
			setLabelText(levelLabel, levelName);
			setLabelText(titleLabel, resultTitle(result));
			setLabelColor(titleLabel, resultTitleColor(result));
			setLabelText(bodyLabel, resultBody(result));
			setLabelText(hintLabel, resultHint(result));
			root.visible = true;
		},
		hide: (): void => {
			root.visible = false;
			// 兜底：隐藏时把两个按钮的触摸也断掉 —— 任何“隐藏但仍参与命中”的引擎行为
			// 都不会再吞掉点击（瞄准层在下面，收不到就拖不动）
			retryButton.setEnabled(false);
			backButton.setEnabled(false);
		},
	};
}

/** 关卡选择里的一项（只要显示名，进度由 unlocked 单独给）。 */
export interface LevelSelectEntry {
	name: string;
}

export interface LevelSelectOptions {
	levels: LevelSelectEntry[];
	onPick: (index: number) => void;
	/** 重看开场（S3.3）。省略 = 不建这个按钮（探针/测试里不必有）。 */
	onReplayIntro?: () => void;
}

/** 关卡选择句柄。 */
export interface LevelSelect {
	root: Node.Type;
	/** 按“已解锁的最高关卡索引（0 基）”刷新可用性，然后显示。 */
	show: (unlocked: number) => void;
	hide: () => void;
}

/**
 * 建关卡选择：标题 + 副标题 + 六关竖排按钮 + 底部提示。
 *
 * 未解锁的按钮**整块不可点**（`setEnabled(false)` 会关掉 `touchEnabled`）——
 * 只在回调里判断“锁了就 return”是不够的：那样按钮仍会吞掉触摸，
 * 表现为“点了没反应”，玩家分不清是坏了还是锁着。
 *
 * ⚠️ 全屏底**不设** `touch: true`：全屏 + `swallowTouches` 会独占整屏点击，
 * 而它在节点树里排在瞄准层之前 —— 隐藏后若仍参与命中，进入关卡就再也拖不动
 * （真机验收即为此症状）。选关期间没有任何关卡处于 Aiming，瞄准层本就关着，
 * 不需要全屏底代劳；能点的只有这六个按钮。
 *
 * @param viewW 视图逻辑宽
 * @param viewH 视图逻辑高
 */
export function createLevelSelect(
	parent: Node.Type,
	viewW: number,
	viewH: number,
	opts: LevelSelectOptions,
): LevelSelect {
	const root = createPanel(parent, viewW, viewH, SelectBackdropHex, { alpha: 0.9 });

	const titleLabel = createLabel(root, '选择任务', 60, SelectTitleHex);
	setLabelCenter(titleLabel, viewW / 2, viewH - 96);

	const subtitleLabel = createLabel(root, '', 34, SelectSubtitleHex);
	setLabelCenter(subtitleLabel, viewW / 2, viewH - clampNumber(viewH * 0.13, 110, 260));

	const hintLabel = createLabel(root, '完成一关即解锁下一关', 30, SelectHintHex);
	setLabelCenter(hintLabel, viewW / 2, clampNumber(viewH * 0.045, 36, 90));

	const count = opts.levels.length;
	// 竖屏两列三行、横屏一列六行：竖屏单列时 6×130 高必然溢出屏幕（真机竖屏实测：
	// L6 被裁一半、底部提示整条被挤出屏外）。列数随宽高比自适应，尺寸随可用空间算。
	const cols = viewH > viewW ? 2 : 1;
	const rows = Math.max(1, Math.ceil(count / cols));
	const gap = 18;
	const headerH = clampNumber(viewH * 0.16, 120, 320);
	const footerH = clampNumber(viewH * 0.10, 80, 200);
	const availW = viewW * 0.84;
	const availH = viewH - headerH - footerH - gap * (rows - 1);
	const btnW = clampNumber((availW - gap * (cols - 1)) / cols, MinButtonWidth, 820);
	const btnH = clampNumber(rows > 0 ? availH / rows : MinButtonHeight, MinButtonHeight, 190);
	const gridW = cols * btnW + gap * (cols - 1);
	const topY = viewH - headerH;

	const buttons: UiButton[] = [];
	for (let i = 0; i < count; i++) {
		// 用 const 固定索引：避免闭包捕获循环变量（写 Lua 时这是个经典坑）
		const index = i;
		const button = createButton(root, {
			w: btnW,
			h: btnH,
			text: opts.levels[index].name,
			fontSize: 38,
			bgHex: SelectLockedBgHex,
			fgHex: SelectLockedFgHex,
			borderHex: SelectBorderHex,
			onTap: (): void => opts.onPick(index),
		});
		const col = index % cols;
		const rowIndex = Math.floor(index / cols);
		button.root.position = Vec2(
			(viewW - gridW) / 2 + col * (btnW + gap),
			topY - (rowIndex + 1) * btnH - rowIndex * gap,
		);
		buttons.push(button);
	}

	// ---- 「重看开场」（S3.3）----
	// 开场只在**首次启动**播（存档标记）；想再看一遍又不方便删标记文件，就在这里给个入口。
	// 位置：网格下沿与页脚提示之间的空档（竖屏 601×1066 实测有 180 px 余量），网格算完才定得下来。
	const replayButton = opts.onReplayIntro !== undefined
		? createButton(root, {
			w: clampNumber(viewW * 0.36, 180, 300),
			h: MinButtonHeight,
			text: '重看开场',
			fontSize: 30,
			bgHex: SelectLockedBgHex,
			fgHex: SelectSubtitleHex,
			borderHex: SelectBorderHex,
			onTap: (): void => {
				if (opts.onReplayIntro !== undefined) opts.onReplayIntro();
			},
		})
		: undefined;
	if (replayButton !== undefined) {
		const gridBottom = topY - rows * btnH - (rows - 1) * gap;
		const by = clampNumber(gridBottom - MinButtonHeight - 20, 8, viewH);
		replayButton.root.position = Vec2((viewW - clampNumber(viewW * 0.36, 180, 300)) / 2, by);
	}

	root.visible = false;
	for (let i = 0; i < count; i++) buttons[i].setEnabled(false); // 创建即禁用（同上）
	if (replayButton !== undefined) replayButton.setEnabled(false);

	return {
		root,
		show: (unlocked: number): void => {
			const maxUnlocked = clampNumber(Math.floor(unlocked), 0, count - 1);
			setLabelText(subtitleLabel, '已解锁 ' + (maxUnlocked + 1).toFixed(0) + ' / ' + count.toFixed(0));
			for (let i = 0; i < count; i++) {
				const button = buttons[i];
				const open = i <= maxUnlocked;
				button.setEnabled(open);
				button.setText(open ? opts.levels[i].name : opts.levels[i].name + ' 未解锁');
				if (open) button.setColors(SelectOpenBgHex, SelectOpenFgHex);
				else button.setColors(SelectLockedBgHex, SelectLockedFgHex);
			}
			root.visible = true;
			if (replayButton !== undefined) replayButton.setEnabled(true);
		},
		hide: (): void => {
			root.visible = false;
			// 兜底：隐藏时把六个按钮的触摸全部断掉，避免“隐藏但仍命中”吞掉瞄准层的拖动
			for (let i = 0; i < count; i++) buttons[i].setEnabled(false);
			if (replayButton !== undefined) replayButton.setEnabled(false);
		},
	};
}

