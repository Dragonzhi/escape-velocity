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
import { Color, DrawNode, Label, Node, Size, Touch, Vec2 } from 'Dora';
import { CameraBasis, screenToPlaneY } from 'game/Projection';
import { P2 } from 'game/Gravity';
import {
	AimMaxDragPx, AimMaxSpeed, AimMinSpeed, FlightPlayback, PlaneToWorldX, PlaneToWorldZ,
	TimeWarpRate, TimeWarpStep, WarpHoldDelaySec,
} from 'game/Config';
import { ResultKind } from 'game/Game';
// 只作类型用（TSTL 会省掉这条 require）：视图模式的唯一事实来源在 GameCore 里
import { PlanViewMode } from 'game/PlanView';
import { MinButtonHeight, MinButtonWidth, UiButton, createButton, createLabel, createPanel, setLabelCenter, setLabelColor, setLabelText } from 'game/Ui';
import { CameraFocusMode, TransferShot } from 'game/Transfer';

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
	minSpeed?: number,
): AimResult {
	// S5：下限也要按关卡给 —— L1 的 Δv 预算只有 0.35，全局 AimMinSpeed = 5 比整关预算还大，
	//     不按关卡给下限的话 L1 的力度会从 5 起跳（直接飞出地月系）。
	const speedMin = minSpeed !== undefined && minSpeed >= 0 && minSpeed < (maxSpeed !== undefined ? maxSpeed : AimMaxSpeed)
		? minSpeed : AimMinSpeed;
	const speedTop = maxSpeed !== undefined && maxSpeed > speedMin ? maxSpeed : AimMaxSpeed;
	// 方向：从探测器指向触摸点（手册 §5.7）。
	// 屏幕偏移空间是中心原点 +Y 向上（与 project() 一致，见 Projection.ts 约定 5）。
	// 修正后的渲染方向：世界 -z（远离相机 = 平面 -y = 朝目标）在屏幕**上方**。
	// 所以触摸在探测器上方（dy < 0）= 朝目标发射（平面 -y，uy < 0）。
	const dx = touchOffset.x - probeOffset.x;
	const dy = touchOffset.y - probeOffset.y;

	const len = Math.sqrt(dx * dx + dy * dy);
	if (len < 1e-6) {
		// 没有拖动：方向取“平面向前”（-y，朝目标），速度取最小值
		return { velocity: { x: 0, y: -speedMin }, power: 0, unit: { x: 0, y: -1 } };
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

	const speed = speedMin + (speedTop - speedMin) * power;

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

/**
 * 倍速按钮上的文字。
 *
 * ⚠️ 不能一律 `toFixed(0)`：0.05× 会显示成「0×」（S5 的 L1 就是 0.02/0.05/0.1 三档）。
 */
export function playbackLabel(speed: number): string {
	if (speed >= 1) return speed.toFixed(0) + '×';
	if (speed >= 0.1) return speed.toFixed(1) + '×';
	return speed.toFixed(2) + '×';
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
	setTransferInfo?: (apoapsis: number, duration: number, reachable?: boolean) => void;
	onCameraFocus?: (callback: () => void) => void;
	onEndViewing?: (callback: () => void) => void;
	setFlightViewing?: (flying: boolean, completed: boolean, mode: CameraFocusMode, is3D: boolean, stage?: TransferShot) => void;
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
	/** 「取消瞄准」被点（Armed 态，发射按钮左侧）。 */
	onCancelAim: (callback: () => void) => void;
	/** 由主循环同步 Armed 状态：按钮显隐 + 触摸开关都跟着它走。 */
	setArmed: (armed: boolean) => void;
	/**
	 * 「2D/3D」切换按钮被按下（S3.15）。按钮**只表达意图** ——
	 * 真正翻转 `GameCore.viewMode` 的是 Game（状态驱动，见手册 §4.3）。
	 */
	onViewToggle: (callback: () => void) => void;
	/** 由主循环同步当前视图：按钮文字跟着状态走（不自己翻转局部变量）。 */
	setViewMode: (mode: PlanViewMode) => void;
	/**
	 * 「播放倍速」按钮被点（S3.17，飞行中可见）：收到 1 / 2 / 4（玩家的手动兜底档）。
	 * 掠过天体时的自动慢动作叠在这个档位上（× 1/4），不经过按钮 —— 按钮只表达意图，
	 * 状态在 GameCore.playback 里（与其它按钮同一条分层原则）。
	 */
	onPlayback: (callback: (speed: number) => void) => void;
	/** 由主循环同步当前倍速档：三颗按钮的高亮跟着状态走（不自己翻转局部变量）。 */
	setPlayback: (speed: number) => void;
	/**
	 * 倍速按钮的显隐（状态驱动，AGENTS 硬约束 4/5）：只在 **Flying** 态出现。
	 * 隐藏时必须同时断触摸（只设 visible = false 会让隐藏的按钮继续吞点击）。
	 */
	setPlaybackVisible: (on: boolean) => void;
	/**
	 * 整屏瞄准（S3.15）：2D 规划视图里**整屏拖动都算瞄准**。
	 *
	 * 为什么："探测器附近才算瞄准、别处拖动 = 自由观察"那条分区规则是为 3D 服务的；
	 * 2D 模式下 3D 世界整个收起来了，自由观察没有意义，留着分区只会让大半屏变成死区
	 * （玩家在图上按一下、拖半天，什么也没发生）。
	 */
	setFullScreenAim: (on: boolean) => void;
	/**
	 * 时间流按钮（S3.9.4）：回调收到 -1（回退）/ 0（松手）/ +1（加速）。
	 * 只有带 `timeWindow` 的关卡才启用；别的关卡整块隐藏**且断触摸**。
	 */
	onWarp: (callback: (dir: number) => void) => void;
	/**
	 * 相态守卫：只有"能改日期"的相态（Aiming / Armed）才让时间流按钮可点。
	 * 主循环每帧同步 —— 飞行中改日期会让行星在飞行途中跳位（飞行用的是 t0 + flightTime）。
	 */
	setTimeEnabled: (on: boolean) => void;
	/** 每帧推进（秒）：驱动时间流按钮的"按住连按"。 */
	update: (dt: number) => void;
	/**
	 * 设置滑杆的量程与当前值：`span <= 0` = 这一关没有时间轴 ⇒ 滑杆整块隐藏且**断触摸**。
	 * （隐藏而不关触摸的层会吞掉整个区域的点击 —— 真机验收踩过，见 AGENTS 硬约束 4。）
	 */
	setDate: (t0: number, span: number) => void;
	/** 2D 规划视口缩放按钮回调（S8.2）。 */
	onZoomIn: (callback: () => void) => void;
	onZoomOut: (callback: () => void) => void;
	onFitView: (callback: () => void) => void;
	/** 显隐 2D 缩放控制组（仅在 2D 规划且非飞行态时显示）。 */
	setZoomControlsVisible: (on: boolean) => void;
	// ---- 时间控制组（B3，2026-09-28）----
	/** 加速一档（×10）。 */
	onSpeedUp: (callback: () => void) => void;
	/** 减速一档（÷10）。 */
	onSpeedDown: (callback: () => void) => void;
	/** 暂停 / 继续。 */
	onTogglePause: (callback: () => void) => void;
	/** 每帧同步：档位指数、上限、是否暂停、任务时钟（**真实秒**）。 */
	setTimeControl: (pow: number, maxPow: number, paused: boolean, missionSeconds: number, actualRate?: number) => void;
	/** 顶部常驻三火箭任务抽屉（S8.4）。 */
	setMissionDrawer: (levelName: string, challenges: string[], currentRockets: number) => void;
	setMissionDrawerVisible: (visible: boolean) => void;
	/** 瞄准时实时反馈二星燃料达标状态。 */
	setLiveFuelChallengeStatus: (achieved: boolean) => void;
	/** 3D 倒叙入场运镜字幕面板（S8.1 / L1-L3 重构）。 */
	setIntroTourBanner: (title: string, hint?: string) => void;
	setIntroTourBannerVisible: (visible: boolean) => void;
	/** 跳过入场运镜回调。 */
	onSkipTour: (callback: () => void) => void;
	/** 设置运镜状态查询函数（用于触摸任意区域跳过）。 */
	setTourActiveChecker: (fn: () => boolean) => void;
	/** 街机模式：右上角常驻秒速重试回调。 */
	onQuickRetry: (callback: () => void) => void;
	/** 街机模式：顶部三星收集状态指示。 */
	setStarsStatus: (starsGot: number) => void;
	setBonusStatus: (got: number, total: number) => void;
	/** 显示刚获得的独立火箭分数。 */
	setBonusFeedback: (score: number) => void;
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
	/** 力度下限（最小点火 Δv，S5 按关卡给）；省略 = 全局 AimMinSpeed */
	minSpeed?: number,
	/** 三颗倍速按钮的档位（S5 按关卡给：L1 = 0.02/0.05/0.1×，L6 = 8/16/32×）；省略 = 1/2/4 */
	speedChoices?: number[],
	transferTutorial: boolean = false,
	transferMode: 'lunar' | 'inward' | 'outward' = 'lunar',
): AimInput {
	const speedMin = minSpeed !== undefined && minSpeed >= 0 && minSpeed < (maxSpeed !== undefined ? maxSpeed : AimMaxSpeed)
		? minSpeed : AimMinSpeed;
	const speedTop = maxSpeed !== undefined && maxSpeed > speedMin ? maxSpeed : AimMaxSpeed;
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
	// Put the full-screen gesture catcher behind HUD controls in both render and
	// touch order. Dora dispatches overlapping touches by node order; without an
	// explicit order, a planning gesture can win over the time buttons.
	touchLayer.order = -100;
	touchLayer.swallowTouches = true;
	root.addChild(touchLayer);

	const space: TouchSpace = { viewW, viewH };
	const TimeBtnW = 78;
	const TimeBtnH = 64;
	const TimeRowY = 170;

	let enabled = false;
	let dragging = false;
	/** 整屏瞄准（2D 模式）；由 Game 按视图状态同步。 */
	let fullScreenAim = false;
	let aim: AimResult = { velocity: { x: 0, y: -speedMin }, power: 0, unit: { x: 0, y: -1 } };

	// 探测器屏幕偏移：由调用方在拖动前/每帧设定。
	let probeOffset: ScreenOffset = { x: 0, y: 0 };

	let dragHandler: ((a: AimResult) => void) | undefined = undefined;
	let readyHandler: ((a: AimResult) => void) | undefined = undefined;
	let observeHandler: ((dx: number, dy: number) => void) | undefined = undefined;
	let zoomHandler: ((deltaDist: number) => void) | undefined = undefined;
	let launchHandler: (() => void) | undefined = undefined;
	let skipTourHandler: (() => void) | undefined = undefined;
	let tourActiveChecker: (() => boolean) | undefined = undefined;

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
		aim = computeAim({ x: 0, y: 0 }, delta, AimMaxDragPx, speedTop, speedMin);
		if (dragHandler !== undefined) dragHandler(aim);
	};

	// ---- 瞄准 / 观察 分区（S3.10）----
	// 用户定稿：**预测线默认不显示**，只有在"探测器附近"按下拖动才是瞄准；
	// 其他地方拖动 = 转观察视角。只用一个全屏层，**按按下点判模式** ——
	// 开两层（一层瞄准一层观察）必然互相吞点击（AGENTS 硬约束 4）。
	const aimRadius = Math.max(96, viewW * 0.25); // 屏宽 1/4（用户拍板）
	let mode: 'none' | 'aim' | 'observe' = 'none';
	let observeLast: ScreenOffset = { x: 0, y: 0 };
	const hitsTimeControls = (local: ScreenOffset): boolean => {
		const left = 24 - 8;
		const right = 24 + (TimeBtnW + 8) * 2 + TimeBtnW + 8;
		return local.x >= left && local.x <= right && local.y >= TimeRowY - 8 && local.y <= TimeRowY + TimeBtnH + 8;
	};
	touchLayer.onTapBegan((touch) => {
		if (!enabled) return;
		// Defense in depth: even if touch dispatch order changes, a tap over the
		// time-control strip must never start aiming or camera observation.
		if (hitsTimeControls({ x: touch.location.x, y: touch.location.y })) {
			mode = 'none';
			dragging = false;
			return;
		}
		if (tourActiveChecker !== undefined && tourActiveChecker() && skipTourHandler !== undefined) {
			skipTourHandler();
			return;
		}
		const at = localToOffset({ x: touch.location.x, y: touch.location.y }, space);
		const dx = at.x - probeOffset.x;
		const dy = at.y - probeOffset.y;
		if (fullScreenAim || Math.sqrt(dx * dx + dy * dy) <= aimRadius) {
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

	// ---- Δv 读数（S3.9.2b 用户："德塔V的限制没有 UI 的显示，不明不白"）----
	// 左上角一行字：本次点火要花多少 / 这一关给了多少；拖动时实时更新。
	// ⚠️ S3.12：太阳的光晕会扫过左上角，纯文字在亮底上几乎看不见（截图实测）⇒ 底下垫一块
	// **半透明暗板**。UI 是 2D 层、画在 3D 之上，所以垫板是"提高对比度"而不是"遮挡"。
	createPanel(root, 220, 50, 0x0a0e14, { alpha: 0.45 });
	const orbitName = transferMode === 'inward' ? '近日点' : (transferMode === 'outward' ? '远日点' : '远地点高度');
	const dvLabel = createLabel(root, transferTutorial ? '拖动调整' + orbitName : 'Δv — / —', transferTutorial ? 22 : 30, ResultHintHex);
	if (dvLabel !== undefined) {
		dvLabel.position = Vec2(24, viewH - (transferTutorial ? 130 : 44));
		dvLabel.anchor = Vec2(0, 0);
	}

	// ---- 时间流：加速 / 回退（S3.9.4 起是按钮；S3.11 起**按住即走**）----
	// 为什么不是滑杆：滑杆是"瞬间跳到某个日期"，而这一版的核心是**时间在流**（探测器绕地球待机）。
	// 两者语义打架 —— 用户自己也指出来了。
	// 点按 = 走一步（`TimeWarpStep` 15 秒，木星挪 5°，看得出在动）；
	// 按住 = 先走一步、停 `WarpHoldDelaySec` 后开始连按，速率 `TimeWarpRate` 倍（40 倍）
	//   ⇒ L4/L6 的 300 秒时间轴按住约 7.5 秒扫完，松手即停。
	// 只有带 `timeWindow` 的关卡才显示；别的关卡整块隐藏**且断触摸**（AGENTS 硬约束 4）。
	let warpHandler: ((dir: number) => void) | undefined = undefined;
	let dateSpan = 0;
	/** 这一关有时间轴**且**当前相态允许改日期（Flying/Result 时必须是 false）。 */
	// ⚠️ 初始值**故意是 true/true**：Label 与按钮建出来本来就是"可见 + 可点"的，
	//    所以这个初值如实反映了节点的实际状态。第一次 applyWarpState（setDate 里）因此
	//    一定会真的跑一遍 —— 若把初值写成 false（"我想让它隐藏"），第一次 apply 会命中
	//    "状态没变就早退"那条捷径，于是**没有时间轴的关卡会留下一个永远不隐藏的「发射日期」**
	//    和一排能点的「◀ 回退 / 加速 ▶」（实测踩到：L1~L3/L5 的截图里它们都在）。
	let warpOn = true;
	let warpVisible = true;
	/** 相态是否允许改日期（由主循环每帧 setTimeEnabled 同步）。 */
	let warpAllowed = true;
	/** 上次写进日期的文字（避免每帧重设 Label 文本）。 */
	let lastDateText = '';
	/** >0 = 正在按住这个方向（-1 回退 / +1 加速）；0 = 没按住。 */
	let warpHoldDir = 0;
	/** 距离下一次连按还有多久（秒）。 */
	let warpRepeatIn = 0;
	const WarpButtonW = 116;
	const WarpButtonH = 64;
	const warpButtons: UiButton[] = [];
	const applyWarpState = (): void => {
		const vis = dateSpan > 0;
		const on = vis && warpAllowed;
		if (vis === warpVisible && on === warpOn) return; // 每帧都会被调用，状态没变就别重绘
		warpVisible = vis;
		warpOn = on;
		if (!on) warpHoldDir = 0;
		for (const b of warpButtons) {
			b.root.visible = vis;
			b.setEnabled(on);
		}
		if (dateLabel !== undefined) dateLabel.visible = vis;
		datePlate.visible = vis;
	};
	const makeWarpButton = (text: string, dir: number, x: number): void => {
		const btn = createButton(root, {
			w: WarpButtonW,
			h: WarpButtonH,
			text,
			fontSize: 30,
			bgHex: ResultButtonAltBgHex,
			fgHex: ResultButtonFgHex,
			borderHex: ResultButtonBorderHex,
			// ⚠️ `onTap` 故意留空：真正的动作在下面两个"按下 / 松手"钩子里。
			//    `onTap` 带 0.5 秒防抖、而且只在松手时触发 —— 做不了"按住即走"。
			onTap: (): void => {},
			onPressBegan: (): void => {
				// 证据打点（照 AGENTS 的规矩：点按一律留一行带状态的日志，不然"没反应"无法归因）
				print('[escape-velocity] warp press dir=' + dir.toFixed(0) + ' on=' + (warpOn ? '1' : '0'));
				if (!warpOn) return;
				// ⚠️ 同一物理按压可能投递两次（鼠标 + 触摸两条路）⇒ 靠"已经在按住"挡住重复
				if (warpHoldDir === dir) return;
				warpHoldDir = dir;
				warpRepeatIn = WarpHoldDelaySec;
				if (warpHandler !== undefined) warpHandler(dir);
			},
			onPressEnded: (): void => {
				print('[escape-velocity] warp release dir=' + dir.toFixed(0) + ' hold=' + warpHoldDir.toFixed(0));
				// 幂等：这条回调会被投递两次，重复清零没有副作用
				if (warpHoldDir === dir) warpHoldDir = 0;
			},
		});
		// ⚠️ 不能自己往 root 上挂 onTapBegan/onTapEnded：`createButton` 内部已经注册过，
		// 后注册会把它的处理器顶掉（实测：按下去既没视觉反馈、也拿不到回调）。
		// 上面两个钩子是 `createButton` 自己在注册时调用的 —— 外部不碰节点。
		btn.root.position = Vec2(x, viewH - 96 - WarpButtonH);
		warpButtons.push(btn);
	};
	const warpLeftX = viewW - (WarpButtonW * 2 + 8) - 20;
	makeWarpButton('◀ 回退', -1, warpLeftX);
	makeWarpButton('加速 ▶', 1, warpLeftX + WarpButtonW + 8);
	// 日期读数同样垫一块暗板（它横跨到屏幕中部，光晕扫过来时更明显）
	const datePlate = createPanel(root, 300, 50, 0x0a0e14, { alpha: 0.45 });
	datePlate.position = Vec2(warpLeftX - 316, viewH - 96 - WarpButtonH + 8);
	const dateLabel = createLabel(root, '发射日期 —', 30, ResultHintHex);
	if (dateLabel !== undefined) {
		// ⚠️ **右对齐到时间流按钮的左边**（不是从左往 24 起排）：601 宽的竖屏下
		//    "发射日期 180 / 300" 约 270 px，从 x=24 起排会正好压在「◀ 回退」上（截图实测过）。
		//    右对齐之后它向左生长，永远留出按钮那一列。
		dateLabel.anchor = Vec2(1, 0);
		dateLabel.position = Vec2(warpLeftX - 16, viewH - 96 - WarpButtonH + 18);
	}

	// ---- 街机模式：右上角常驻秒速重试按钮 ----
	const QuickRetryW = 110;
	const QuickRetryH = 50;
	let quickRetryHandler: (() => void) | undefined = undefined;
	const quickRetryBtn = createButton(root, {
		w: QuickRetryW,
		h: QuickRetryH,
		text: '↺ 重试',
		fontSize: 26,
		bgHex: 0xc2410c, // 醒目橙红色
		fgHex: 0xffffff,
		borderHex: 0xfbbf24,
		fireOn: 'press',
		onTap: (): void => {
			print('[escape-velocity] quick retry tapped');
			if (quickRetryHandler !== undefined) quickRetryHandler();
		},
	});
	quickRetryBtn.root.position = Vec2(viewW - QuickRetryW - 20, viewH - QuickRetryH - 20);

	// ---- 街机模式：顶部三星收集状态指示 ----
	const starPlateW = 180;
	const starPlateH = 46;
	const starPlate = createPanel(root, starPlateW, starPlateH, 0x0a0e14, { alpha: 0.55 });
	starPlate.position = Vec2(viewW / 2 - starPlateW / 2, viewH - starPlateH - 22);
	starPlate.visible = !transferTutorial;
	const starStatusLabel = createLabel(root, '☆ ☆ ☆', 30, 0xffd700);
	const bonusToastLabel = createLabel(root, '', 34, 0x8cff9b);
	if (bonusToastLabel !== undefined) { bonusToastLabel.position = Vec2(viewW / 2, viewH * 0.68); bonusToastLabel.visible = false; }
	if (starStatusLabel !== undefined) {
		starStatusLabel.anchor = Vec2(0.5, 0.5);
		starStatusLabel.position = Vec2(viewW / 2, viewH - starPlateH / 2 - 22);
	}
	const updateStarsStatus = (count: number): void => {
		if (starStatusLabel === undefined) return;
		if (transferTutorial) { starStatusLabel.visible = false; return; }
		let s = '☆ ☆ ☆';
		if (count === 1) s = '★ ☆ ☆';
		else if (count === 2) s = '★ ★ ☆';
		else if (count >= 3) s = '★ ★ ★';
		setLabelText(starStatusLabel, s);
	};
	const updateBonusStatus = (got: number, total: number): void => {
		if (starStatusLabel === undefined) return;
		starPlate.visible = total > 0;
		starStatusLabel.visible = total > 0;
		if (total > 0) setLabelText(starStatusLabel, '🚀 ' + got.toFixed(0) + ' / ' + total.toFixed(0));
	};

	// ---- 「发射」按钮（S3.10，右下角拇指区；只在 Armed 态出现）----
	// 命中区 220×112，`fireOn: 'press'` 按下即发射
	const LaunchButtonW = 220;
	const LaunchButtonH = 112;
	const launchButton = createButton(root, {
		w: LaunchButtonW,
		h: LaunchButtonH,
		text: '▲ 发射 ▲',
		fontSize: 38,
		bgHex: ResultButtonBgHex,
		fgHex: ResultButtonFgHex,
		borderHex: ResultButtonBorderHex,
		fireOn: 'press',
		onTap: (): void => {
			print('[escape-velocity] launch button fire (press)');
			if (launchHandler !== undefined) launchHandler();
		},
	});
	launchButton.root.position = Vec2(viewW - LaunchButtonW - 24, 96);
	launchButton.root.visible = false;
	launchButton.setEnabled(false); // 隐藏 + 断触摸（硬约束 4）

	// 「取消瞄准」：Armed 时停在发射按钮左边。按下即回到巡航，表继续走。
	const CancelButtonW = 160;
	const CancelButtonH = 72;
	let cancelAimHandler: (() => void) | undefined = undefined;
	const cancelAimButton = createButton(root, {
		w: CancelButtonW,
		h: CancelButtonH,
		text: '✕ 取消',
		fontSize: 28,
		bgHex: ResultButtonAltBgHex,
		fgHex: ResultButtonFgHex,
		borderHex: ResultButtonBorderHex,
		fireOn: 'press',
		onTap: (): void => {
			print('[escape-velocity] cancel aim fire (press)');
			if (cancelAimHandler !== undefined) cancelAimHandler();
		},
	});
	cancelAimButton.root.position = Vec2(viewW - LaunchButtonW - CancelButtonW - 40, 116);
	cancelAimButton.root.visible = false;
	cancelAimButton.setEnabled(false);

	// ---- 「2D / 3D」手动切换（S3.15）----
	// 位置：右下角「发射」按钮正上方
	const ViewButtonW = 116;
	const ViewButtonH = 64;
	let viewHandler: (() => void) | undefined = undefined;
	const viewButton = createButton(root, {
		w: ViewButtonW,
		h: ViewButtonH,
		text: '[ 3D ]',
		fontSize: 26,
		bgHex: ResultButtonAltBgHex,
		fgHex: ResultButtonFgHex,
		borderHex: ResultButtonBorderHex,
		fireOn: 'press',
		onTap: (): void => {
			print('[escape-velocity] view toggle fire (press)');
			if (viewHandler !== undefined) viewHandler();
		},
	});
	viewButton.root.position = Vec2(viewW - ViewButtonW - 24, 96 + LaunchButtonH + 12);
	/** 上次写进按钮的文字（每帧都会被 setViewMode 调用，没变就别碰 Label）。 */
	let lastViewText = '2D';

	// L1：小状态提示不打断掠月；完成后才开放结束观赏。
	let cameraFocusHandler: (() => void) | undefined = undefined;
	let endViewingHandler: (() => void) | undefined = undefined;
	const cameraFocusButton = transferTutorial ? createButton(root, {
		w: 260, h: 58, text: '镜头 · 自动', fontSize: 22,
		bgHex: ResultButtonAltBgHex, fgHex: ResultButtonFgHex, borderHex: ResultButtonBorderHex, fireOn: 'press',
		onTap: (): void => { if (cameraFocusHandler !== undefined) cameraFocusHandler(); },
	}) : undefined;
	const endViewingButton = transferTutorial ? createButton(root, {
		w: 220, h: LaunchButtonH, text: '结束观赏', fontSize: 26,
		bgHex: ResultButtonAltBgHex, fgHex: ResultButtonFgHex, borderHex: ResultButtonBorderHex, fireOn: 'press',
		onTap: (): void => { if (endViewingHandler !== undefined) endViewingHandler(); },
	}) : undefined;
	if (cameraFocusButton !== undefined) { cameraFocusButton.root.position = Vec2(24, 266); cameraFocusButton.root.visible = false; cameraFocusButton.setEnabled(false); }
	if (endViewingButton !== undefined) { endViewingButton.root.position = Vec2(viewW - 244, 96); endViewingButton.root.visible = false; endViewingButton.setEnabled(false); }
	const viewingLabel = transferTutorial ? createLabel(root, '', 24, ResultHintHex) : undefined;
	if (viewingLabel !== undefined) { viewingLabel.position = Vec2(24, viewH - 130); viewingLabel.anchor = Vec2(0, 0); viewingLabel.visible = false; }
	let viewingKey = '';

	// ---- 2D 规划缩放控制组（S8.2，左下角）----
	const ZoomBtnSize = 58;
	const zoomGap = 8;
	const zoomButtons: UiButton[] = [];
	let zoomInHandler: (() => void) | undefined = undefined;
	let zoomOutHandler: (() => void) | undefined = undefined;
	let fitViewHandler: (() => void) | undefined = undefined;

	const makeZoomButton = (text: string, x: number, fontSize: number, onClick: () => void): UiButton => {
		const btn = createButton(root, {
			w: ZoomBtnSize,
			h: ZoomBtnSize,
			text,
			fontSize,
			bgHex: ResultButtonAltBgHex,
			fgHex: ResultButtonFgHex,
			borderHex: ResultButtonBorderHex,
			fireOn: 'press',
			onTap: (): void => {
				print('[escape-velocity] zoom btn ' + text + ' fire');
				onClick();
			},
		});
		btn.root.position = Vec2(x, 96);
		btn.root.visible = false;
		btn.setEnabled(false);
		zoomButtons.push(btn);
		return btn;
	};
	makeZoomButton('−', 24, 32, (): void => {
		if (zoomOutHandler !== undefined) zoomOutHandler();
	});
	makeZoomButton('FIT', 24 + ZoomBtnSize + zoomGap, 20, (): void => {
		if (fitViewHandler !== undefined) fitViewHandler();
	});
	makeZoomButton('+', 24 + (ZoomBtnSize + zoomGap) * 2, 32, (): void => {
		if (zoomInHandler !== undefined) zoomInHandler();
	});
	let zoomControlsVisible: boolean | undefined = undefined;
	const setZoomVisible = (on: boolean): void => {
		if (zoomControlsVisible === on) return;
		zoomControlsVisible = on;
		for (const b of zoomButtons) {
			b.root.visible = on;
			b.setEnabled(on);
		}
	};
	setZoomVisible(false); // 初始隐藏

	// ---- 时间控制组（B3）：减速 / 暂停 / 加速 + 档位读数 + 任务时钟 ----
	// 位置：左下角 y = 170 那一行（2D 缩放组在 y = 96，故意错开一行，两组不再抢位置）。
	// 口径：速率 = 10^pow ÷ SecPerGameSec 游戏秒/真实秒；pow 0 = 1× = 现实 1 秒。
	// ⚠️ 状态型按钮用 fireOn: 'release'（AGENTS 硬约束 9）；每次动作打一行日志。
	let speedUpHandler: (() => void) | undefined = undefined;
	let speedDownHandler: (() => void) | undefined = undefined;
	let pauseHandler: (() => void) | undefined = undefined;

	const slowButton = createButton(root, {
		w: TimeBtnW, h: TimeBtnH, text: '◀ 慢', fontSize: 26,
		bgHex: ResultButtonAltBgHex, fgHex: ResultButtonFgHex, borderHex: ResultButtonBorderHex,
		onTap: (): void => {
			print('[escape-velocity] speed down fire');
			if (speedDownHandler !== undefined) speedDownHandler();
		},
	});
	slowButton.root.position = Vec2(24, TimeRowY);
	slowButton.root.order = 100;
	const pauseButton = createButton(root, {
		w: TimeBtnW, h: TimeBtnH, text: '⏸', fontSize: 30,
		bgHex: ResultButtonAltBgHex, fgHex: ResultButtonFgHex, borderHex: ResultButtonBorderHex,
		onTap: (): void => {
			print('[escape-velocity] pause toggle fire');
			if (pauseHandler !== undefined) pauseHandler();
		},
	});
	pauseButton.root.position = Vec2(24 + TimeBtnW + 8, TimeRowY);
	pauseButton.root.order = 100;
	const fastButton = createButton(root, {
		w: TimeBtnW, h: TimeBtnH, text: '快 ▶', fontSize: 26,
		bgHex: ResultButtonAltBgHex, fgHex: ResultButtonFgHex, borderHex: ResultButtonBorderHex,
		onTap: (): void => {
			print('[escape-velocity] speed up fire');
			if (speedUpHandler !== undefined) speedUpHandler();
		},
	});
	fastButton.root.position = Vec2(24 + (TimeBtnW + 8) * 2, TimeRowY);
	fastButton.root.order = 100;

	// 读数：档位 + 任务时钟（垫暗板，理由与 Δv 读数的光晕问题相同）
	const timePlate = createPanel(root, 300, 50, 0x0a0e14, { alpha: 0.45 });
	timePlate.position = transferTutorial ? Vec2(24, viewH - 190) : Vec2(24 + (TimeBtnW + 8) * 3 + 4, TimeRowY + 7);
	const timeLabel = createLabel(root, '1×（现实）  T+ 0:00', transferTutorial ? 22 : 26, ResultHintHex);
	if (timeLabel !== undefined) {
		timeLabel.anchor = Vec2(0, 0);
		timeLabel.position = transferTutorial ? Vec2(36, viewH - 179) : Vec2(24 + (TimeBtnW + 8) * 3 + 16, TimeRowY + 18);
	}
	/** 档位文字：pow 0 就是"1×（现实）"，别写成 1e0×。 */
	const powText = (pow: number): string => (pow <= 0 ? '1×（现实）' : '1e' + pow.toFixed(0) + '×');
	/** 任务时钟：真实秒 → "T+ 3天 04:12"。1× 下它每秒跳一格 —— 时间在流逝的唯一可见证据。 */
	const missionText = (sec: number): string => {
		const s = sec > 0 ? sec : 0;
		const days = Math.floor(s / 86400);
		const rest = s - days * 86400;
		const hh = Math.floor(rest / 3600);
		const mm = Math.floor((rest - hh * 3600) / 60);
		const pad = (v: number): string => (v < 10 ? '0' : '') + v.toFixed(0);
		return 'T+ ' + (days > 0 ? days.toFixed(0) + '天 ' : '') + pad(hh) + ':' + pad(mm);
	};
	let lastTimeText = '';
	let lastPaused = false;
	const setTimeControl = (pow: number, maxPow: number, paused: boolean, missionSeconds: number, actualRate?: number): void => {
		const txt = (transferTutorial && actualRate !== undefined ? actualRate.toFixed(2) + '×' : powText(pow)) + (paused ? ' ⏸ 暂停' : '') + '  ' + (transferTutorial ? 'T+ ' + missionSeconds.toFixed(1) + 's' : missionText(missionSeconds));
		if (txt !== lastTimeText) {
			lastTimeText = txt;
			if (timeLabel !== undefined) timeLabel.text = txt;
		}
		if (paused !== lastPaused) {
			lastPaused = paused;
			pauseButton.setText(paused ? '▶' : '⏸');
			pauseButton.setColors(paused ? ResultButtonBgHex : ResultButtonAltBgHex, ResultButtonFgHex);
		}
		// 档位到底就不给点（状态驱动，AGENTS 硬约束 5）
		fastButton.setEnabled(pow < maxPow);
		slowButton.setEnabled(pow > 0);
	};

	// ---- 顶部常驻三火箭任务抽屉（S8.4）----
	const DrawerW = 380;
	const DrawerH = 46;
	const missionDrawerPlate = createPanel(root, DrawerW, DrawerH, 0x0a0e14, { alpha: 0.65, borderHex: 0x46586d });
	missionDrawerPlate.position = Vec2(transferTutorial ? 24 : (viewW - DrawerW) / 2, viewH - 56);
	const missionTitleLabel = createLabel(missionDrawerPlate, '', 19, 0xccddee);
	if (missionTitleLabel !== undefined) {
		missionTitleLabel.anchor = Vec2(0, 0.5);
		missionTitleLabel.position = Vec2(14, DrawerH / 2);
	}
	const missionRocketsLabel = createLabel(missionDrawerPlate, '☆  ☆  ☆', 22, 0xffd700);
	if (missionRocketsLabel !== undefined) {
		missionRocketsLabel.anchor = Vec2(1, 0.5);
		missionRocketsLabel.position = Vec2(DrawerW - 14, DrawerH / 2);
	}
	missionDrawerPlate.visible = false;
	let drawerVisible = false;
	let bonusToastSerial = 0;
	let drawerLevelTitle = '';
	let drawerRockets = 0;
	let liveFuelBonus = false;

	const updateDrawerDisplay = (): void => {
		if (missionTitleLabel !== undefined) {
			setLabelText(missionTitleLabel, drawerLevelTitle);
		}
		if (missionRocketsLabel !== undefined) {
			const r1 = drawerRockets >= 1 ? '★' : '☆';
			const r2 = (drawerRockets >= 2 || liveFuelBonus) ? '★' : '☆';
			const r3 = drawerRockets >= 3 ? '★' : '☆';
			setLabelText(missionRocketsLabel, transferTutorial ? (drawerRockets >= 1 ? '已完成' : (transferMode === 'lunar' ? '地月转移练习' : '日心借力练习')) : r1 + '  ' + r2 + '  ' + r3);
		}
	};

	// ---- 3D 倒叙入场运镜字幕面板（S8.1 / L1-L3 重构）----
	const IntroBannerW = Math.min(viewW - 48, 540);
	const IntroBannerH = 68;
	const introBannerPlate = createPanel(root, IntroBannerW, IntroBannerH, 0x0a0e14, { alpha: 0.8, borderHex: 0x46586d });
	introBannerPlate.position = Vec2((viewW - IntroBannerW) / 2, 70);
	const introBannerTitle = createLabel(introBannerPlate, '', 17, 0xeaf4ff);
	if (introBannerTitle !== undefined) {
		introBannerTitle.anchor = Vec2(0.5, 0.5);
		introBannerTitle.position = Vec2(IntroBannerW / 2, IntroBannerH * 0.65);
	}
	const introBannerHint = createLabel(introBannerPlate, '轻触屏幕任意位置跳过运镜', 13, 0x8da5bd);
	if (introBannerHint !== undefined) {
		introBannerHint.anchor = Vec2(0.5, 0.5);
		introBannerHint.position = Vec2(IntroBannerW / 2, IntroBannerH * 0.28);
	}
	introBannerPlate.visible = false;

	// ---- 播放倍速 1× / 2× / 4×（S3.17；只在飞行中出现）----
	// 设计稿定稿十条第 2 条："掠过时自动近景慢动作（1/4 速、贴近行星），平时正常速度；
	// 给玩家 1×/2×/4× 兜底"。自动慢动作叠在玩家选的档位上（× 1/4），不替换它。
	// ⚠️ 状态型按钮 ⇒ 保持 fireOn: 'release'（默认），与时间流按钮共用 createButton 的
	//    0.5 秒防抖；幂等由调用方保证（同一个档位设两遍没有副作用）。
	// ⚠️ 高亮跟着 GameCore.playback 走（setPlayback 每帧同步）—— 按钮不自己存"当前档位"，
	//    否则"按钮显示的"与"播出来的"迟早分家（AGENTS 硬约束 5）。
	const PlaybackButtonW = 116;
	const PlaybackButtonH = 64;
	const playbackGap = 10;
	const playbackButtons: UiButton[] = [];
	const playbackSpeeds: number[] = [];
	let playbackHandler: ((speed: number) => void) | undefined = undefined;
	// S5：档位按关卡给。L1 的转移飞行只有 0.40 游戏秒，要 0.05× 才能看 8 秒；
	// L6 要飞 513 秒，要 16× 才压到 32 秒。全局写死 1/2/4 两头都不成立。
	const speedChoice = speedChoices !== undefined && speedChoices.length > 0 ? speedChoices : [1, 2, 4];
	let playbackSpeed = speedChoice[0];
	/** 已应用到节点上的显隐状态。初值 false 如实反映"建出来就隐藏"（照 warp 按钮的教训）。 */
	let playbackVisible = false;
	const paintPlayback = (): void => {
		for (let i = 0; i < playbackButtons.length; i++) {
			const on = playbackSpeeds[i] === playbackSpeed;
			playbackButtons[i].setColors(on ? ResultButtonBgHex : ResultButtonAltBgHex, ResultButtonFgHex);
		}
	};
	const makePlaybackButton = (speed: number, x: number): void => {
		const btn = createButton(root, {
			w: PlaybackButtonW,
			h: PlaybackButtonH,
			text: playbackLabel(speed),
			fontSize: 30,
			bgHex: ResultButtonAltBgHex,
			fgHex: ResultButtonFgHex,
			borderHex: ResultButtonBorderHex,
			onTap: (): void => {
				// 证据打点（AGENTS：每次动作一行日志 —— 有行 = 事件到了、没行 = 事件没到）
				print('[escape-velocity] playback button fire ' + speed.toFixed(0) + 'x (release)');
				playbackSpeed = speed;
				paintPlayback(); // 先重绘再通知：只通知的话按钮颜色不跟着变（刹车按钮的教训）
				if (playbackHandler !== undefined) playbackHandler(speed);
			},
		});
		// 左下角、与「发射」按钮同一行高（y 96..160）：完全避开引擎底部调试工具条
		// （实测 y=20 一带的鼠标事件会被它整个吃掉，见 viewButton 的注释）
		btn.root.position = Vec2(x, 96);
		playbackButtons.push(btn);
		playbackSpeeds.push(speed);
	};
	for (let i = 0; i < speedChoice.length && i < 3; i++) {
		makePlaybackButton(speedChoice[i], 24 + (PlaybackButtonW + playbackGap) * i);
	}
	paintPlayback();
	// 飞行中才出现：建出来先隐藏 + 断触摸（只设 visible 不够 —— 硬约束 4）
	for (const b of playbackButtons) {
		b.root.visible = false;
		b.setEnabled(false);
	}

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
			if (!value) {
				dragging = false;
			}
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
		onCancelAim: (callback: () => void): void => {
			cancelAimHandler = callback;
		},
		setArmed: (armed: boolean): void => {
			launchButton.root.visible = armed;
			launchButton.setEnabled(armed);
			cancelAimButton.root.visible = armed;
			cancelAimButton.setEnabled(armed);
		},
		onViewToggle: (callback: () => void): void => {
			viewHandler = callback;
		},
		onCameraFocus: (callback: () => void): void => { cameraFocusHandler = callback; },
		onEndViewing: (callback: () => void): void => { endViewingHandler = callback; },
		setFlightViewing: (flying: boolean, completed: boolean, mode: CameraFocusMode, is3D: boolean, stage?: TransferShot): void => {
			if (!transferTutorial) return;
			const key = (flying ? '1' : '0') + (completed ? '1' : '0') + mode + (is3D ? '1' : '0') + (stage !== undefined ? stage : '');
			if (viewingKey === key) return;
			viewingKey = key;
			if (dvLabel !== undefined) dvLabel.visible = !flying;
			if (viewingLabel !== undefined) {
				viewingLabel.visible = flying;
				const near = stage === 'Mercury' ? '安全飞掠水星' : stage === 'Venus' ? '金星减速借力' : (stage === 'Jupiter' ? '木星加速借力' : (stage === 'Saturn' ? '土星加速借力' : (stage === 'Moon' ? '借月球引力 · 观察轨迹转弯' : '滑行 · 观察航线')));
				setLabelText(viewingLabel, completed ? (transferMode === 'lunar' ? '掠月完成 · 继续观察返回' : '目标完成 · 继续观察航线') : (stage === 'Launch' ? (transferMode === 'inward' ? '逆行点火 · 降低近日点' : '顺行点火 · 抬高' + orbitName) : near));
				setLabelColor(viewingLabel, completed ? 0x8fe5ba : ResultHintHex);
			}
			if (cameraFocusButton !== undefined) {
				cameraFocusButton.root.visible = flying && is3D;
				cameraFocusButton.setEnabled(flying && is3D);
				const title = mode === 'Mercury' ? '水星' : mode === 'Auto' ? '自动' : (mode === 'Probe' ? '探测器' : (mode === 'Moon' ? '月球' : (mode === 'Earth' ? '地球' : (mode === 'Venus' ? '金星' : (mode === 'Jupiter' ? '木星' : (mode === 'Saturn' ? '土星' : (mode === 'Sun' ? '太阳' : '总览')))))));
				cameraFocusButton.setText('镜头 · ' + title);
			}
			if (endViewingButton !== undefined) { endViewingButton.root.visible = flying && completed; endViewingButton.setEnabled(flying && completed); }
		},
		setViewMode: (mode: PlanViewMode): void => {
			if (mode === lastViewText) return;
			lastViewText = mode;
			// 2D 状态时按钮提示切去「[ 3D ]」，3D 状态时按钮提示切去「[ 2D ]」
			const btnText = mode === '2D' ? '[ 3D ]' : '[ 2D ]';
			viewButton.setText(btnText);
		},
		onPlayback: (callback: (speed: number) => void): void => {
			playbackHandler = callback;
		},
		setPlayback: (speed: number): void => {
			if (speed === playbackSpeed) return; // 每帧都会被调用：状态没变就别重绘
			playbackSpeed = speed;
			paintPlayback();
		},
		setPlaybackVisible: (on: boolean): void => {
			if (on === playbackVisible) return; // 每帧都会被调用（状态驱动，硬约束 5）
			playbackVisible = on;
			for (const b of playbackButtons) {
				b.root.visible = on;
				b.setEnabled(on);
			}
		},
		setFullScreenAim: (on: boolean): void => {
			fullScreenAim = on;
		},
		onWarp: (callback: (dir: number) => void): void => {
			warpHandler = callback;
		},
		setDate: (t0: number, span: number): void => {
			dateSpan = span > 0 ? span : 0;
			applyWarpState(); // 隐藏 + 断触摸（AGENTS 硬约束 4）：这一关没有时间轴就整块收起来
			const on = dateSpan > 0;
			const text = on ? '发射日期 ' + t0.toFixed(0) + ' / ' + dateSpan.toFixed(0) : '发射日期';
			if (text !== lastDateText) {
				lastDateText = text;
				setLabelText(dateLabel, text);
			}
		},
		setTimeEnabled: (on: boolean): void => {
			if (warpAllowed === on) return; // 每帧调用：状态没变就别动
			warpAllowed = on;
			applyWarpState();
		},
		update: (dt: number): void => {
			if (!warpOn || warpHoldDir === 0) return;
			warpRepeatIn -= dt;
			if (warpRepeatIn > 0) return;
			// 连按速率 = TimeWarpRate 倍（步长 / 倍率 = 间隔秒数）
			warpRepeatIn = TimeWarpStep / TimeWarpRate;
			if (warpHandler !== undefined) warpHandler(warpHoldDir);
		},
		isDragging: (): boolean => dragging,
		setBurnInfo: (burn: number, budget: number): void => {
			if (transferTutorial) return;
			// ⚠️ 预算 < 1 时必须用 2 位小数：L1 的 Δv 预算是 0.35，
			//    toFixed(0) 会把它打成 0，和 burn 的 0 撞在一起，看起来像"这一关没给预算"
			//    （用户 2026-09-27 实测：「2D 状态下，德塔 V 怎么给的是 0」）。
			const b = budget < 1 ? budget.toFixed(2) : budget.toFixed(0);
			const v = burn < 1 ? burn.toFixed(2) : burn.toFixed(1);
			setLabelText(dvLabel, 'Δv ' + v + ' / ' + b);
		},
		current: (): AimResult => aim,
		setTransferInfo: (apoapsis: number, duration: number, reachable?: boolean): void => {
			setLabelText(dvLabel, orbitName + ' ' + apoapsis.toFixed(0) + ' · 点火 ' + duration.toFixed(2) + 's' + (reachable !== undefined ? (reachable ? (transferMode === 'lunar' ? ' · 可减速掠月' : ' · 航线可行') : ' · 等待窗口') : ''));
		},
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
		onSpeedUp: (callback: () => void): void => {
			speedUpHandler = callback;
		},
		onSpeedDown: (callback: () => void): void => {
			speedDownHandler = callback;
		},
		onTogglePause: (callback: () => void): void => {
			pauseHandler = callback;
		},
		setTimeControl: (pow: number, maxPow: number, paused: boolean, missionSeconds: number, actualRate?: number): void => {
			setTimeControl(pow, maxPow, paused, missionSeconds, actualRate);
		},
		onZoomIn: (callback: () => void): void => {
			zoomInHandler = callback;
		},
		onZoomOut: (callback: () => void): void => {
			zoomOutHandler = callback;
		},
		onFitView: (callback: () => void): void => {
			fitViewHandler = callback;
		},
		setZoomControlsVisible: (on: boolean): void => {
			setZoomVisible(on);
		},
		setMissionDrawer: (levelName: string, _challenges: string[], currentRockets: number): void => {
			drawerLevelTitle = levelName;
			drawerRockets = currentRockets;
			updateDrawerDisplay();
		},
		setMissionDrawerVisible: (visible: boolean): void => {
			if (drawerVisible === visible) return;
			drawerVisible = visible;
			missionDrawerPlate.visible = visible;
		},
		setLiveFuelChallengeStatus: (achieved: boolean): void => {
			if (liveFuelBonus === achieved) return;
			liveFuelBonus = achieved;
			updateDrawerDisplay();
		},
		setIntroTourBanner: (title: string, hint?: string): void => {
			if (introBannerTitle !== undefined) setLabelText(introBannerTitle, title);
			if (introBannerHint !== undefined && hint !== undefined) setLabelText(introBannerHint, hint);
		},
		setIntroTourBannerVisible: (visible: boolean): void => {
			introBannerPlate.visible = visible;
		},
		onSkipTour: (callback: () => void): void => {
			skipTourHandler = callback;
		},
		setTourActiveChecker: (fn: () => boolean): void => {
			tourActiveChecker = fn;
		},
		onQuickRetry: (callback: () => void): void => {
			quickRetryHandler = callback;
		},
		setStarsStatus: (starsGot: number): void => {
			updateStarsStatus(starsGot);
		},
		setBonusStatus: (got: number, total: number): void => { updateBonusStatus(got, total); },
		setBonusFeedback: (score: number): void => {
			if (bonusToastLabel === undefined) return;
			bonusToastSerial += 1;
			const serial = bonusToastSerial;
			setLabelText(bonusToastLabel, '🚀 +' + score.toFixed(0));
			bonusToastLabel.visible = true;
			let elapsed = 0;
			root.schedule((deltaTime: number): boolean => {
				elapsed += deltaTime;
				if (elapsed >= 0.6) { if (serial === bonusToastSerial) bonusToastLabel.visible = false; return true; }
				return false;
			});
		},
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

/** 结算详情参数（S7 三枚火箭评价）。 */
export interface ResultDetailParams {
	completionOnly?: boolean;
	bonusPointCount?: number;
	result: ResultKind;
	levelName: string;
	levelIndex: number;
	rocketsGot: number;
	challenges: string[];
	achieved: [boolean, boolean, boolean];
	burnDv: number;
	dvBudget: number;
	flightTime: number;
	totalRockets: number;
	totalPossibleRockets: number;
}

/** 结算面板句柄。 */
export interface ResultPanel {
	/** 根节点（全屏半透明底），调用方自行 addChild 到想要的层级。 */
	root: Node.Type;
	show: (result: ResultKind, levelName: string, detail?: ResultDetailParams) => void;
	hide: () => void;
}

/**
 * 建结算面板：半透明全屏底 + 居中工业级卡片 + 三枚火箭挑战清单 + 遥测数据 + 2 个按钮。
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

	const cardW = clampNumber(viewW * 0.90, 360, 560);
	const btnW = clampNumber(cardW - 60, MinButtonWidth, 480);
	let btnH = clampNumber(viewH * 0.08, 48, 60);
	const padX = (cardW - btnW) / 2;
	const padY = 28;

	const fontLevel = 24;
	const fontRockets = 38;
	const fontTitle = 30;
	const fontTelemetry = 19;
	const fontChallenge = 18;
	const fontTotal = 20;
	const btnFont = 24;
	const rowGap = 12;

	const hLevel = 28;
	const hRockets = 42;
	const hTitle = 34;
	const hTelemetry = 24;
	const hChallengeRow = 30;
	const hChallenges = hChallengeRow * 3;
	const hTotal = 24;

	let cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7;
	if (cardH > viewH - 24) {
		btnH = Math.max(MinButtonHeight, btnH - (cardH - (viewH - 24)) / 2);
		cardH = padY * 2 + hLevel + hRockets + hTitle + hTelemetry + hChallenges + hTotal + btnH * 2 + 14 + rowGap * 7;
	}

	const card = createPanel(root, cardW, cardH, ResultCardHex, {
		alpha: 0.97,
		borderHex: ResultCardBorderHex,
		borderWidth: 3,
	});
	card.position = Vec2((viewW - cardW) / 2, (viewH - cardH) / 2);

	// 垂直排版：从顶部往下累减
	let cursor = cardH - padY;

	cursor -= hLevel;
	const levelLabel = createLabel(card, '', fontLevel, ResultLevelHex);
	setLabelCenter(levelLabel, cardW / 2, cursor + hLevel / 2);

	cursor -= rowGap + hRockets;
	const rocketsLabel = createLabel(card, '', fontRockets, 0xffc83b);
	setLabelCenter(rocketsLabel, cardW / 2, cursor + hRockets / 2);

	cursor -= rowGap + hTitle;
	const titleLabel = createLabel(card, '', fontTitle, TitleSuccessHex);
	setLabelCenter(titleLabel, cardW / 2, cursor + hTitle / 2);

	cursor -= rowGap + hTelemetry;
	const telemetryLabel = createLabel(card, '', fontTelemetry, ResultHintHex);
	setLabelCenter(telemetryLabel, cardW / 2, cursor + hTelemetry / 2);

	cursor -= rowGap;
	const challengeLabels: Label.Type[] = [];
	for (let k = 0; k < 3; k++) {
		cursor -= hChallengeRow;
		const cl = createLabel(card, '', fontChallenge, 0x9ec5eb);
		if (cl !== undefined) {
			cl.textWidth = cardW - 60;
			setLabelCenter(cl, cardW / 2, cursor + hChallengeRow / 2);
			challengeLabels.push(cl);
		}
	}

	cursor -= rowGap + hTotal;
	const totalLabel = createLabel(card, '', fontTotal, 0xffd479);
	setLabelCenter(totalLabel, cardW / 2, cursor + hTotal / 2);

	cursor -= rowGap + btnH;
	const retryButton = createButton(card, {
		w: btnW,
		h: btnH,
		text: '重试本关',
		fontSize: btnFont,
		bgHex: ResultButtonBgHex,
		fgHex: ResultButtonFgHex,
		borderHex: ResultButtonBorderHex,
		fireOn: 'press',
		onTap: opts.onRetry,
	});
	retryButton.root.position = Vec2(padX, cursor);

	cursor -= 14 + btnH;
	const backButton = createButton(card, {
		w: btnW,
		h: btnH,
		text: '返回关卡选择',
		fontSize: btnFont,
		bgHex: ResultButtonAltBgHex,
		fgHex: ResultButtonFgHex,
		borderHex: ResultButtonBorderHex,
		fireOn: 'press',
		onTap: opts.onBackToSelect,
	});
	backButton.root.position = Vec2(padX, cursor);

	root.visible = false;
	retryButton.setEnabled(false);
	backButton.setEnabled(false);

	return {
		root,
		show: (result: ResultKind, levelName: string, detail?: ResultDetailParams): void => {
			retryButton.setEnabled(true);
			backButton.setEnabled(true);
			setLabelText(levelLabel, levelName);
			setLabelText(titleLabel, resultTitle(result));
			setLabelColor(titleLabel, resultTitleColor(result));

			if (detail !== undefined) {
				if (detail.completionOnly === true) setLabelText(titleLabel, result === 'success' ? '引力借力完成' : resultTitle(result));
				const rCount = detail.rocketsGot;
				let rStr = '☆  ☆  ☆';
				if (rCount === 1) rStr = '★  ☆  ☆';
				else if (rCount === 2) rStr = '★  ★  ☆';
				else if (rCount >= 3) rStr = '★  ★  ★';
				setLabelText(rocketsLabel, detail.completionOnly === true ? (result === 'success' ? '目标已完成' : '再试一次') : (detail.bonusPointCount !== undefined ? '火箭得分 ' + rCount.toFixed(0) + ' / ' + detail.bonusPointCount.toFixed(0) : rStr));
				setLabelColor(rocketsLabel, rCount > 0 ? 0xffc83b : 0x607894);

				const pct = detail.dvBudget > 0 ? Math.floor((detail.burnDv / detail.dvBudget) * 100) : 0;
				const telemText = '点火消耗 Δv: ' + detail.burnDv.toFixed(2) + ' / ' + detail.dvBudget.toFixed(2) + ' (' + pct.toFixed(0) + '%) · 用时: ' + detail.flightTime.toFixed(1) + 's';
				setLabelText(telemetryLabel, telemText);

				for (let k = 0; k < 3; k++) {
					if (challengeLabels[k] !== undefined) {
						if (k < detail.challenges.length) {
							const ok = detail.achieved[k];
							const icon = ok ? '★' : '☆';
							const rank = k === 0 ? '一星' : (k === 1 ? '二星' : '三星');
							const text = detail.completionOnly === true ? (ok ? '目标完成 · 记录已保存' : '尚未完成目标') : icon + ' [' + rank + '] ' + detail.challenges[k];
							setLabelText(challengeLabels[k], text);
							setLabelColor(challengeLabels[k], ok ? 0xffc83b : 0x607894);
							challengeLabels[k].visible = true;
						} else {
							challengeLabels[k].visible = false;
						}
					}
				}

				setLabelText(totalLabel, '全深空火箭勋章: ' + detail.totalRockets.toFixed(0) + ' / ' + detail.totalPossibleRockets.toFixed(0) + ' ★');
				if (totalLabel !== undefined) totalLabel.visible = detail.completionOnly !== true;
			} else {
				setLabelText(rocketsLabel, result === 'success' ? '★  ☆  ☆' : '☆  ☆  ☆');
				setLabelColor(rocketsLabel, result === 'success' ? 0xffc83b : 0x607894);
				setLabelText(telemetryLabel, resultBody(result));
				for (let k = 0; k < challengeLabels.length; k++) challengeLabels[k].visible = false;
				if (totalLabel !== undefined) totalLabel.visible = false;
			}
			root.visible = true;
		},
		hide: (): void => {
			root.visible = false;
			retryButton.setEnabled(false);
			backButton.setEnabled(false);
		},
	};
}

// ---------------------------------------------------------------------------
// 终章「暗淡蓝点」（S3.18，规格见 .agent/plan/PLAN.md）
//
// 一屏：星空 + 一行主文案 + 一行小字 + 一颗「返回关卡选择」。
// **不做**动画分镜、**不做**第二段文案（砍线顺序里「终章细节」是第一项可砍的）。
// 显隐由相态驱动（Game.onPhase('Finale') → show；离开 Finale → hide），
// **不许只由点按驱动**（AGENTS 硬约束 5：状态被别的东西改掉之后，
// 只靠点按的面板会留在屏幕上变成一个「点了没反应」的层）。
// ---------------------------------------------------------------------------

const FinaleBackdropHex = 0x05070c;
const FinaleMainHex = 0xeaf4ff;
const FinaleSubHex = 0x9fc4e8;

/**
 * 终章主文案（逐字；改之前先改 PLAN S3.18 与 docs/开发手册.md）。
 */
export const FinaleMainText = '这就是我们整颗星球的样子 —— 而你已经从那里飞到了这里。';

/**
 * 终章小字：飞行距离 / 用时（纯函数，可单测）。
 *
 * 距离是**平面单位**（关卡尺度，不是公里）—— 别在这里换算成天文单位，
 * 那一换就得把整条注释重写一遍，而玩家要的只是「飞了多远、花了多久」。
 */
export function finaleSubtitle(distance: number, time: number): string {
	return '飞行 ' + distance.toFixed(0) + ' 单位 · 用时 ' + time.toFixed(1) + ' 秒';
}

/** 终章面板的装配参数。 */
export interface FinalePanelOptions {
	onBackToSelect: () => void;
}

/** 终章面板句柄。 */
export interface FinalePanel {
	/** 根节点（全屏半透明底），调用方自行 addChild 到想要的层级。 */
	root: Node.Type;
	show: (main: string, sub: string) => void;
	hide: () => void;
}

/**
 * 建终章面板：半透明全屏底 + 主文案 + 小字 + 「返回关卡选择」。
 *
 * ⚠️ 全屏底**不设** `touch: true`（与结算面板同一条规矩）：全屏 + swallowTouches
 * 会独占整屏点击，而它在节点树里排在瞄准层之前。终章态瞄准层本来就已
 * `setEnabled(false)`，能点的只有那一颗按钮。
 *
 * 排版：文案都在**上半屏**（画面中心留给「地球只是一个点」），按钮在底部
 * 但**不贴边**（桌面引擎窗口底部有一条调试工具条，y < 90 一带的鼠标事件会被它吃掉，
 * 见 Hud.ts 里 viewButton 的注释）。
 *
 * @param viewW 视图逻辑宽（`View.size.width`）
 * @param viewH 视图逻辑高
 */
export function createFinalePanel(
	parent: Node.Type,
	viewW: number,
	viewH: number,
	opts: FinalePanelOptions,
): FinalePanel {
	const root = createPanel(parent, viewW, viewH, FinaleBackdropHex, { alpha: 0.55 });

	const fontMain = 34;
	const fontSub = 30;
	const btnFont = 40;

	const mainLabel = createLabel(root, FinaleMainText, fontMain, FinaleMainHex);
	if (mainLabel !== undefined) {
		// 竖屏 601 宽：34 号字一行约 15 个汉字，27 字的主文案会折成两行 ⇒ 必须给 textWidth
		mainLabel.textWidth = viewW * 0.88;
		setLabelCenter(mainLabel, viewW / 2, viewH * 0.80);
	}

	const subLabel = createLabel(root, '', fontSub, FinaleSubHex);
	if (subLabel !== undefined) setLabelCenter(subLabel, viewW / 2, viewH * 0.71);

	const btnW = clampNumber(viewW * 0.62, MinButtonWidth, 560);
	const btnH = clampNumber(viewH * 0.085, MinButtonHeight, 120);
	const backButton = createButton(root, {
		w: btnW,
		h: btnH,
		text: '返回关卡选择',
		fontSize: btnFont,
		bgHex: ResultButtonBgHex,
		fgHex: ResultButtonFgHex,
		borderHex: ResultButtonBorderHex,
		// 一次性动作 ⇒ 按下即生效（与「重试本关 / 返回关卡选择」同一个理由，见 ButtonOptions.fireOn）
		fireOn: 'press',
		onTap: opts.onBackToSelect,
	});
	backButton.root.position = Vec2((viewW - btnW) / 2, 110);

	root.visible = false;
	// 创建即禁用：面板在第一次 show() 之前也在树里，可点的按钮会参与命中并吞掉覆盖区域的点击
	backButton.setEnabled(false);

	return {
		root,
		show: (main: string, sub: string): void => {
			setLabelText(mainLabel, main);
			setLabelText(subLabel, sub);
			backButton.setEnabled(true);
			root.visible = true;
		},
		hide: (): void => {
			root.visible = false;
			// 兜底：隐藏时把按钮的触摸也断掉（任何「隐藏但仍参与命中」的引擎行为都不会再吞点击）
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
			// 一次性动作：按下即选（"点了没反应"的老毛病在选关按钮上同样出现过）
			fireOn: 'press',
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
			fireOn: 'press',
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

