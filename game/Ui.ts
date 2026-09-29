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
/// <reference path="../tools/dora-build/dora-types/nvg.d.ts" />
import { Audio, Color, DrawNode, Label, Node, Size, Vec2, VGNode } from 'Dora';
import * as nvg from 'nvg';

/**
 * UI 自己的时钟（秒）—— **不要改用 `App.elapsedTime`**。
 *
 * ⚠️ 实测（2026-09-27，探针在引擎里连打 12 帧）：`App.deltaTime` 正常（0.016667/帧），
 *    但 `App.elapsedTime` **一直冻结在 0.0001 附近不动**。于是下面 0.5 秒防抖里的
 *    `now - lastTapAt` 恒为 0 ⇒ **每个按钮一辈子只能按动一次**（第二次起被当成「同一次点击的重复投递」吞掉）。
 *    用户报的「2D/3D 按钮只能单向切一次」「刹车/发射按第二次没反应」全是这一个根因。
 *
 * 修法：时钟自己累加，由主循环（`init.ts` 的 `threadLoop`）每帧喂 `App.deltaTime`。
 * 这样防抖语义不变（挡掉同一瞬间鼠标+触摸的双投递），但不依赖引擎那个坏掉的读数。
 */
let uiClock = 0;

/** 推进 UI 时钟；主循环每帧调一次（在对话框、选关、关卡、结算里都要走）。 */
export function advanceUiClock(dt: number): void {
	uiClock += dt;
}

/** 当前 UI 时钟读数（秒，进程内单调递增）。 */
export function uiClockNow(): number {
	return uiClock;
}

/** 项目统一字体（与现有 UI 一致）。 */
export const FontName = 'sarasa-mono-sc-regular';

/**
 * 触屏目标的**绝对下限**（视图逻辑像素）—— 不是“按钮就该这么大”。
 *
 * ⚠️ 曾经写成 560/130，结果在竖屏窄屏（实测 View.size = 601×1066）里：
 * 560 宽的按钮几乎顶满屏宽，六行 130 高的关卡按钮直接从屏幕底部溢出（L6 被裁、底部提示被挤没）。
 * 真正的尺寸应由布局按**可用空间**算，这里只保一个“不要小到点不中”的地板。
 */
export const MinButtonHeight = 72;
export const MinButtonWidth = 144;
export const IconButtonSize = 72;
export const TextButtonWidth = 144;
export const ButtonGap = 8;
export type ButtonIcon = 'slow' | 'fast' | 'play' | 'pause' | 'launch' | 'cancel' | 'retry' | 'back' | 'camera' | 'stop' | 'minus' | 'plus' | 'fit';

/** NanoVG paths; icon meaning does not depend on the installed font. */
function renderButtonIcon(node: VGNode.Type, icon: ButtonIcon, hex: number): void {
	node.render((): void => {
		nvg.StrokeColor(colorFromHex(hex, 1)); nvg.StrokeWidth(2.4); nvg.LineCap(nvg.LineCapMode.Round); nvg.LineJoin(nvg.LineJoinMode.Round);
		const line = (points: number[]): void => {
			nvg.BeginPath(); nvg.MoveTo(points[0], points[1]);
			for (let i = 2; i < points.length; i += 2) nvg.LineTo(points[i], points[i + 1]);
			nvg.Stroke();
		};
		if (icon === 'pause') { line([12, 7, 12, 29]); line([24, 7, 24, 29]); }
		else if (icon === 'play') line([11, 7, 27, 18, 11, 29, 11, 7]);
		else if (icon === 'slow' || icon === 'fast') {
			const a = icon === 'slow' ? 1 : -1, c = icon === 'slow' ? 0 : 36;
			line([c + 17 * a, 8, c + 7 * a, 18, c + 17 * a, 28]); line([c + 29 * a, 8, c + 19 * a, 18, c + 29 * a, 28]);
		} else if (icon === 'cancel') { line([9, 9, 27, 27]); line([27, 9, 9, 27]); }
		else if (icon === 'back') { line([19, 7, 8, 18, 19, 29]); line([8, 18, 29, 18]); }
		else if (icon === 'stop') line([9, 9, 27, 9, 27, 27, 9, 27, 9, 9]);
		else if (icon === 'retry') { nvg.BeginPath(); nvg.Arc(18, 18, 11, -1.5, 3.9, nvg.ArcDir.CW); nvg.Stroke(); line([6, 9, 6, 18, 14, 15]); }
		else if (icon === 'camera') { line([6, 12, 12, 12, 15, 8, 24, 8, 27, 12, 30, 12, 30, 28, 6, 28, 6, 12]); nvg.BeginPath(); nvg.Circle(18, 20, 6); nvg.Stroke(); }
		else if (icon === 'launch') { line([13, 25, 13, 14, 18, 5, 23, 14, 23, 25, 13, 25]); line([13, 18, 7, 26, 13, 25]); line([23, 18, 29, 26, 23, 25]); line([16, 29, 16, 33]); line([20, 29, 20, 33]); }
		else if (icon === 'minus' || icon === 'plus') { line([8, 18, 28, 18]); if (icon === 'plus') line([18, 8, 18, 28]); }
		else { line([7, 14, 7, 7, 14, 7]); line([22, 7, 29, 7, 29, 14]); line([29, 22, 29, 29, 22, 29]); line([14, 29, 7, 29, 7, 22]); }
	});
}

/**
 * 0xRRGGBB + alpha(0–1) → Color。
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
	icon?: ButtonIcon;
	w: number;
	h: number;
	text: string;
	fontSize: number;
	bgHex: number;
	fgHex: number;
	borderHex?: number;
	/** 点击回调。⚠️ 带 0.5 秒防抖（见 createButton 里的说明）。 */
	onTap: () => void;
	/**
	 * 什么时候触发 `onTap`（S3.12）：
	 * - `'release'`（默认）：松手时触发，历史行为；
	 * - `'press'`：**按下即触发** —— 给"点火 / 重试 / 返回"这类**一次性**动作。
	 *
	 * 为什么需要它：Dora 的 `onTap` 挂在 `onTapEnded` 上，而引擎**会丢事件**、
	 * 也**没有"触摸取消"回调** —— 手指按下后划出按钮再松开，那一下可能落到别的节点上，
	 * 表现就是"按了没反应"（用户会话 44：「有的时候还是会出现按钮点击了没有反应，比如发射按钮」）。
	 * 一次性动作挂在按下那一刻，就与"松手落在哪"无关了。
	 * 幂等由调用方保证（本项目里：发射后相态立刻离开 Armed，重试后面板立刻收起）。
	 */
	fireOn?: 'release' | 'press';
	/**
	 * 按下（还没松手）回调。给"按住即走"这类需要**按下/松手两个时刻**的按钮用。
	 *
	 * ⚠️ 与 `onTap` 不同，它**不做防抖** —— 同一物理按压可能被投递两次（鼠标 + 触摸两条路），
	 * 所以实现必须是**幂等**的（例如"已经在按住同一个方向就直接 return"）。
	 */
	onPressBegan?: () => void;
	/** 松手回调。同样不防抖、同样可能被投递两次 ⇒ 实现要幂等。 */
	onPressEnded?: () => void;
}

/** 按钮句柄：自身是**可点节点**（底色 + 居中 Label + 触摸开关）。 */
export interface UiButton {
	setIcon: (icon: ButtonIcon) => void;
	setSelected: (selected: boolean) => void;
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

	// 防抖时间戳（秒）：见 onTapEnded 里的说明
	let lastTapAt = -1;

	// 居中锚点的文字，位置取按钮的几何中心
	const label = createLabel(root, opts.text, opts.fontSize, opts.fgHex);
	if (label !== undefined) label.position = Vec2(opts.w / 2, opts.h / 2);
	let icon = opts.icon;
	let iconNode: VGNode.Type | undefined = undefined;
	let renderedIcon: ButtonIcon | undefined = undefined;
	let renderedHex = -1;
	let buttonText = opts.text;
	let selected = false;
	const layoutContent = (): void => {
		if (icon !== undefined) {
			if (iconNode === undefined) { iconNode = VGNode(36, 36); root.addChild(iconNode); }
			iconNode.position = Vec2(buttonText === '' ? opts.w / 2 : 26, opts.h / 2);
		}
		if (label !== undefined) label.position = Vec2(icon !== undefined && buttonText !== '' ? (opts.w + 40) / 2 : opts.w / 2, opts.h / 2);
	};
	layoutContent();

	let bgHex = opts.bgHex;
	let fgHex = opts.fgHex;
	let enabled = true;
	let pressed = false;

	const repaint = (): void => {
		const baseBg = enabled ? bgHex : shadeHex(bgHex, 0.48);
		const bg = pressed ? shadeHex(baseBg, 1.45) : (selected && enabled ? shadeHex(baseBg, 1.25) : baseBg);
		draw.clear();
		draw.drawPolygon(rectVerts(opts.w, opts.h), colorFromHex(bg, 1));
		if (opts.borderHex !== undefined) {
			draw.drawPolygon(rectVerts(opts.w, opts.h), colorFromHex(0x000000, 0), 2, colorFromHex(enabled ? opts.borderHex : shadeHex(opts.borderHex, 0.48), 1));
		}
		setLabelColor(label, enabled ? fgHex : shadeHex(fgHex, 0.55));
		if (iconNode !== undefined && icon !== undefined) {
			iconNode.opacity = enabled ? 1 : 0.55;
			if (renderedIcon !== icon || renderedHex !== fgHex) {
				renderButtonIcon(iconNode, icon, fgHex); renderedIcon = icon; renderedHex = fgHex;
			}
		}
	};

	// ⚠️ 实测（2026-09-26，合成点击点「刹车」按钮）：**一次点击会被投递两次** ——
	//    引擎的鼠标与触摸两条路都会走到回调，切换型按钮因此"开了又立刻关"。
	//    0.5 秒防抖：双投递是同一瞬间，而人不可能 0.5 秒内在同一按钮上点两次。
	//    （fireOn='press' 时同样吃这条防抖：重复投递由幂等守卫 + 这里一起挡掉。）
	const fireTap = (): void => {
		const now = uiClockNow();
		if (lastTapAt >= 0 && now - lastTapAt < 0.5) return;
		lastTapAt = now;
		Audio.play('Assets/Audio/ui_click.wav');
		opts.onTap();
	};
	root.onTapBegan(() => {
		if (!enabled) return;
		pressed = true;
		repaint();
		if (opts.onPressBegan !== undefined) opts.onPressBegan();
		// S3.12：一次性动作在**按下**那一刻就做（见 ButtonOptions.fireOn 的说明）
		if (opts.fireOn === 'press') fireTap();
	});
	root.onTapEnded(() => {
		if (!enabled) return;
		pressed = false;
		repaint();
		// ⚠️ 松手这条**不走 0.5 秒防抖**：防抖是给 `onTap`（同一瞬间双投递）的，
		//    而"按住即走"必须在真的松手时立刻停 —— 幂等由调用方保证。
		if (opts.onPressEnded !== undefined) opts.onPressEnded();
		if (opts.fireOn !== 'press') fireTap();
	});

	repaint();
	parent.addChild(root);

	return {
		root,
		setIcon: (value: ButtonIcon): void => { if (icon === value) return; icon = value; layoutContent(); repaint(); },
		setSelected: (value: boolean): void => { if (selected === value) return; selected = value; repaint(); },
		setText: (text: string): void => { if (buttonText === text) return; buttonText = text; setLabelText(label, text); layoutContent(); },
		setEnabled: (value: boolean): void => {
			if (enabled === value) return;
			enabled = value;
			// 不可点 = 连触摸都不该收到：只在回调里 return 会让“未解锁”按钮
			// 吞掉本该传给下面图层的点击。
			root.touchEnabled = value;
			pressed = false;
			repaint();
		},
		setColors: (bg: number, fg: number): void => {
			if (bgHex === bg && fgHex === fg) return;
			bgHex = bg;
			fgHex = fg;
			repaint();
		},
	};
}
