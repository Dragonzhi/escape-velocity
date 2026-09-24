/**
 * 视图空间 2D UI 原语（S2.2 / S2.3）。
 *
 * 为什么单独成模块：结算面板与关卡选择都要“实心矩形 + 文字 + 可点区域”，
 * 直接写在 Hud.ts / init.ts 会把同一段 DrawNode 代码抄三遍；而本模块只做
 * “画一个矩形 / 一个居中文字 / 一个可点按钮”，**不认识任何游戏语义**。
 *
 * ===== 锚点与坐标系约定（关键，别改）=====
 *
 * 本模块创建的节点统一 `anchor = (0,0)`，**局部坐标原点 = 节点的 position**，
 * 绘制多边形用局部 `[0,w]×[0,h]`。这样“画出来的矩形”与“触摸命中矩形”在两种
 * 可能的 Dora 内部实现下都重合（d.ts 没有写明 anchor 是否参与命中判定：
 * 纯 Node 命中按局部 `[0,size]`，Sprite 按锚点展开；anchor=0 时两者相同）。
 * 代价：调用方按**左下角**摆放。
 *
 * 由此，面板内部的自定义局部坐标就是 `[0,W]×[0,H]`（左下原点、+Y 向上），
 * 与 Hud.ts 的触摸层、Projection 的输出空间同向，少一次心算。
 *
 * 字体：`Label()` 可能返回 undefined（字体缺失）。所有创建函数都把 undefined
 * 原样交给调用方，由调用方决定是“跳过这一行字”还是报错（手册 §7.1）。
 */
import { Color, DrawNode, Label, Node, Size, Vec2 } from 'Dora';

/** 项目统一字体（与现有 UI 一致）。 */
export const FontName = 'sarasa-mono-sc-regular';

/**
 * 触屏目标下限（视图逻辑像素）。
 *
 * 竖屏单手可达是硬要求（手册 §5.7），所以按钮不许做小：
 * 高度 130、宽度 560 是**下限**，不是推荐值。
 */
/**
 * 触屏目标的**绝对下限**（视图逻辑像素）—— 不是“按钮就该这么大”。
 *
 * ⚠️ 曾经写成 560/130，结果在竖屏窄屏（实测 View.size = 601×1066）里：
 * 560 宽的按钮几乎顶满屏宽，六行 130 高的关卡按钮直接从屏幕底部溢出（L6 被裁、底部提示被挤没）。
 * 真正的尺寸应由布局按**可用空间**算，这里只保一个“不要小到点不中”的地板。
 */
export const MinButtonHeight = 72;
export const MinButtonWidth = 160;

/**
 * 0xRRGGBB + alpha(0–1) → Color。
 *
 * 用除法取通道而不用 `>>` / `&`：位运算在 TSTL 的不同 Lua 目标上支持面更窄，
 * 而这里只有三次算术，代价可忽略。
 */
export function colorFromHex(hex: number, alpha: number): Color.Type {
	const r = Math.floor(hex / 65536) % 256;
	const g = Math.floor(hex / 256) % 256;
	const b = hex % 256;
	let a = alpha * 255;
	if (a < 0) a = 0;
	if (a > 255) a = 255;
	return Color(r, g, b, Math.floor(a));
}

/** 把颜色整体调亮（factor > 1）；按下态用它，避免再写一套配色常量。 */
export function shadeHex(hex: number, factor: number): number {
	const r0 = Math.floor(hex / 65536) % 256;
	const g0 = Math.floor(hex / 256) % 256;
	const b0 = hex % 256;
	const r = Math.min(255, Math.floor(r0 * factor));
	const g = Math.min(255, Math.floor(g0 * factor));
	const b = Math.min(255, Math.floor(b0 * factor));
	return r * 65536 + g * 256 + b;
}

/** 局部矩形的四个顶点（左下 → 右下 → 右上 → 左上）。 */
export function rectVerts(w: number, h: number): Vec2.Type[] {
	return [Vec2(0, 0), Vec2(w, 0), Vec2(w, h), Vec2(0, h)];
}

export interface PanelOptions {
	/** 填充色的 alpha（0–1），默认 1。半透明底用它。 */
	alpha?: number;
	/** 边框颜色（0xRRGGBB）；省略 = 无边框。 */
	borderHex?: number;
	/** 边框宽度（像素），默认 2。 */
	borderWidth?: number;
	/**
	 * 是否吞掉落在面板上的触摸，默认 false。
	 *
	 * 结算/关卡选择的全屏底必须设 true：否则底下的矄准层仍会收到拖动，
	 * 玩家在结算界面“拖一下”会意外影响瞄准。
	 */
	touch?: boolean;
}

/**
 * 建一个实心矩形面板（局部 `[0,w]×[0,h]`）。
 *
 * @returns 面板节点；调用方用 `position`（左下角）摆放。
 */
export function createPanel(
	parent: Node.Type,
	w: number,
	h: number,
	fillHex: number,
	opts?: PanelOptions,
): Node.Type {
	const root = Node();
	root.size = Size(w, h);
	root.anchor = Vec2(0, 0);

	const alpha = opts !== undefined && opts.alpha !== undefined ? opts.alpha : 1;
	const borderWidth = opts !== undefined && opts.borderWidth !== undefined ? opts.borderWidth : 2;
	const borderHex = opts !== undefined ? opts.borderHex : undefined;

	const draw = DrawNode();
	draw.drawPolygon(rectVerts(w, h), colorFromHex(fillHex, alpha));
	if (borderHex !== undefined) {
		// 只画边框：填充给全透明色，描边色才是可见的那一圈
		draw.drawPolygon(rectVerts(w, h), colorFromHex(0x000000, 0), borderWidth, colorFromHex(borderHex, alpha));
	}
	root.addChild(draw);

	if (opts !== undefined && opts.touch === true) {
		root.touchEnabled = true;
		root.swallowTouches = true;
	}

	parent.addChild(root);
	return root;
}

/**
 * 建一个居中锚点的文字（`anchor = (0.5,0.5)`，用 `position` 指定文字中心）。
 *
 * @returns Label；字体缺失时返回 undefined（不是异常，也不是空字符串）。
 */
export function createLabel(
	parent: Node.Type,
	text: string,
	fontSize: number,
	colorHex: number,
): Label.Type | undefined {
	const label = Label(FontName, fontSize);
	if (label === undefined) return undefined;
	label.text = text;
	label.color = colorFromHex(colorHex, 1);
	label.anchor = Vec2(0.5, 0.5);
	parent.addChild(label);
	return label;
}

/** 安全写文字：label 可能是 undefined（字体缺失），调用点不该到处写 if。 */
export function setLabelText(label: Label.Type | undefined, text: string): void {
	if (label !== undefined) label.text = text;
}

/** 安全改颜色。 */
export function setLabelColor(label: Label.Type | undefined, colorHex: number): void {
	if (label !== undefined) label.color = colorFromHex(colorHex, 1);
}

/** 安全改位置（居中锚点语义：给的是文字中心）。 */
export function setLabelCenter(label: Label.Type | undefined, x: number, y: number): void {
	if (label !== undefined) label.position = Vec2(x, y);
}

/** 安全显隐。 */
export function setLabelVisible(label: Label.Type | undefined, visible: boolean): void {
	if (label !== undefined) label.visible = visible;
}

export interface ButtonOptions {
	w: number;
	h: number;
	text: string;
	fontSize: number;
	bgHex: number;
	fgHex: number;
	borderHex?: number;
	/** 点击（松手）回调。 */
	onTap: () => void;
}

/** 按钮句柄：自身是**可点节点**（底色 + 居中 Label + 触摸开关）。 */
export interface UiButton {
	/** 按钮节点，用 `position`（左下角）摆放。 */
	root: Node.Type;
	setText: (text: string) => void;
	setEnabled: (enabled: boolean) => void;
	/** 换配色（关卡选择的“已解锁 / 未解锁”两态用它，不重建节点）。 */
	setColors: (bgHex: number, fgHex: number) => void;
}

/**
 * 建一个可点按钮。
 *
 * 为什么不用 Label 当按钮：`Label` 的命中区域依赖文本尺寸，触摸目标不稳定；
 * 这里用固定 `size` 的 `Node` 承接触摸（手册 §5.7 要求触屏目标足够大），
 * 文字只是它的一个子树。
 *
 * 按下态：`onTapBegan` 把底色调亮一档，`onTapEnded` 复原 —— 没有视觉反馈的
 * 按钮在触屏上会被当成“没反应”。
 *
 * ⚠️ 已知局限：Dora 没有“触摸取消”回调，手指按下后划出按钮再松开，`onTapEnded`
 * 仍会触发。这里不做坐标过滤 —— `touch.location` 的局部空间在无头环境无法标定
 * （`Touch` 构造是私有的），错误的空间假设会让按钮整块点不到，比“多触发一次”更糟。
 */
export function createButton(parent: Node.Type, opts: ButtonOptions): UiButton {
	const root = Node();
	root.size = Size(opts.w, opts.h);
	root.anchor = Vec2(0, 0);
	root.touchEnabled = true;
	root.swallowTouches = true;

	const draw = DrawNode();
	root.addChild(draw);

	// 居中锚点的文字，位置取按钮的几何中心
	const label = createLabel(root, opts.text, opts.fontSize, opts.fgHex);
	if (label !== undefined) label.position = Vec2(opts.w / 2, opts.h / 2);

	let bgHex = opts.bgHex;
	let fgHex = opts.fgHex;
	let enabled = true;
	let pressed = false;

	const repaint = (): void => {
		const bg = pressed ? shadeHex(bgHex, 1.45) : bgHex;
		draw.clear();
		draw.drawPolygon(rectVerts(opts.w, opts.h), colorFromHex(bg, 1));
		if (opts.borderHex !== undefined) {
			draw.drawPolygon(rectVerts(opts.w, opts.h), colorFromHex(0x000000, 0), 2, colorFromHex(opts.borderHex, 1));
		}
		setLabelColor(label, fgHex);
	};

	root.onTapBegan(() => {
		if (!enabled) return;
		pressed = true;
		repaint();
	});
	root.onTapEnded(() => {
		if (!enabled) return;
		pressed = false;
		repaint();
		opts.onTap();
	});

	repaint();
	parent.addChild(root);

	return {
		root,
		setText: (text: string): void => setLabelText(label, text),
		setEnabled: (value: boolean): void => {
			enabled = value;
			// 不可点 = 连触摸都不该收到：只在回调里 return 会让“未解锁”按钮
			// 吞掉本该传给下面图层的点击。
			root.touchEnabled = value;
			pressed = false;
			repaint();
		},
		setColors: (bg: number, fg: number): void => {
			bgHex = bg;
			fgHex = fg;
			repaint();
		},
	};
}
