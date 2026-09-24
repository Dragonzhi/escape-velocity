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
 */
export function computeAim(
	probeOffset: ScreenOffset,
	touchOffset: ScreenOffset,
	maxDragPx: number,
): AimResult {
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

	// ⚠️ 必须在**注册完触摸回调之后**再关掉触摸：onTapBegan/onTapMoved/onTapEnded
	// 各会把 node.touchEnabled 置为 true（引擎行为）。
	// 多关并存时，未激活关卡的触摸层若开着 touchEnabled + swallowTouches，
	// 会把整个屏幕的点击独占（被点到的节点独占触摸），表现为
	// “切到第二关后怎么拖都没反应”。
	touchLayer.touchEnabled = false;

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
			// 触摸开关必须跟着走：swallowTouches 的层只要开着，就会把点击独占，
			// 底下的关卡层永远收不到（多关并存时这是致命的）
			touchLayer.touchEnabled = value;
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

	// 尺寸全部按视图逻辑像素推导，不写死：竖屏 1080×1920 与桌面 2024×1230 都要能看
	const cardW = viewW * 0.88;
	const btnW = Math.max(MinButtonWidth, Math.min(cardW - 80, 900));
	const btnH = Math.max(MinButtonHeight, 150);
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
	const cardH = padY * 2 + hLevel + hTitle + hBody + hHint + rowGap * 4 + btnH * 2 + 22;

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
	setLabelCenter(subtitleLabel, viewW / 2, viewH - 168);

	const hintLabel = createLabel(root, '完成一关即解锁下一关', 30, SelectHintHex);
	setLabelCenter(hintLabel, viewW / 2, 64);

	const count = opts.levels.length;
	const btnW = Math.max(MinButtonWidth, Math.min(viewW * 0.8, 820));
	const gap = 18;
	const headerH = 220;
	const footerH = 120;
	const avail = viewH - headerH - footerH - gap * (count - 1);
	// 六关都要塞进一屏，所以按钮高度是“剩下的空间除以关卡数”，
	// 但绝不低于触屏下限（手册 §5.7）
	const btnH = clampNumber(count > 0 ? avail / count : MinButtonHeight, MinButtonHeight, 190);
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
		button.root.position = Vec2((viewW - btnW) / 2, topY - (index + 1) * btnH - index * gap);
		buttons.push(button);
	}

	root.visible = false;

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
		},
		hide: (): void => {
			root.visible = false;
			// 兜底：隐藏时把六个按钮的触摸全部断掉，避免“隐藏但仍命中”吞掉瞄准层的拖动
			for (let i = 0; i < count; i++) buttons[i].setEnabled(false);
		},
	};
}

