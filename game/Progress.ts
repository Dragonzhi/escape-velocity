/**
 * 解锁进度（S2.3，决策 D5：解锁制，只记已解锁关卡）。
 *
 * 语义（手册 §4.3 / §5.8）：
 * - `unlocked` 是**已解锁的最高关卡索引（0 基）**，不是“已解锁数量”。
 *   `unlocked = 0` 表示只开第一关；`unlocked = 5` 表示六关全开。
 * - 只有 `success` 才解锁 `levelIndex + 1`；`missed` / `crashed` 不动进度。
 * - 重复通关旧关卡**不回退**进度（见 `advanceUnlocked` 的说明）。
 *
 * 存档：`<writablePath>/escape-velocity.progress`，内容只有一行 `unlocked=N`。
 * ⚠️ 任务简报里写的是 `App.writablePath`，但 v1.9.3 的 Dora.d.ts 里 **`App`
 * 没有这个名字**，可写目录挂在 `Content.writablePath`（已核对 d.ts，全库仅此一处）。
 * 按“以引擎声明为准”的规矩改用 `Content.writablePath`。
 *
 * 纯函数（`clampUnlocked` / `advanceUnlocked`）不碰引擎对象，可被单测直接调用；
 * 读写函数对任何异常输入**都不抛错**（存档坏了只是回到 0，不该让游戏起不来）。
 */
import { Content, Path } from 'Dora';
import { ResultKind } from 'game/Game';

/** 进度。`unlocked` = 已解锁的最高关卡索引（0 基）。 */
export interface Progress {
	unlocked: number;
}

/** 存档文件名（相对 `Content.writablePath`）。 */
export const ProgressFileName = 'escape-velocity.progress';

/** 存档里的键名，独占一行：`unlocked=N`。 */
export const ProgressKey = 'unlocked=';

/** 存档文件的绝对路径。 */
export function progressFilePath(): string {
	return Path(Content.writablePath, ProgressFileName);
}

/**
 * 把任意数字夹到 `[0, levelCount - 1]`，非法输入归 0。
 *
 * “非法”定义（写死在这里，避免各处自行判断）：NaN、±Infinity、
 * 关卡数 <= 0、负数。非整数向下取整（存档只会有整数，读盘时不该因为
 * 出现 `2.0` 这类浮点写法就整份作废）。
 */
export function clampUnlocked(value: number, levelCount: number): number {
	if (levelCount <= 0) return 0;
	if (value !== value) return 0; // NaN：Lua 里 NaN ~= NaN 同样成立
	if (value === Infinity || value === -Infinity) return 0;
	if (value < 0) return 0;
	const max = levelCount - 1;
	if (value > max) return max;
	return Math.floor(value);
}

/**
 * 结算后推进解锁进度（纯函数）。
 *
 * - 只有 `success` 才解锁 `levelIndex + 1`；
 * - `missed` / `crashed` 原样返回（再夹紧）；
 * - **不回退**：重玩已解锁的旧关并成功时，取 `max(已解锁, levelIndex + 1)`。
 *   任务简报只要求“success 解锁 levelIndex+1”，但纯字面实现会让
 *   `advanceUnlocked(3, 'success', 0, 6)` 从 3 掉回 1 —— 玩家重玩第一关
 *   反而锁掉后面几关。解锁制（D5）只有“解锁”没有“上锁”，所以取较大值；
 *   在正常推进（levelIndex >= unlocked）时与字面语义完全一致。
 */
export function advanceUnlocked(
	unlocked: number,
	result: ResultKind,
	levelIndex: number,
	levelCount: number,
): number {
	if (result !== 'success') return clampUnlocked(unlocked, levelCount);
	const next = levelIndex + 1;
	const keep = unlocked > next ? unlocked : next;
	return clampUnlocked(keep, levelCount);
}

/**
 * 从 `unlocked=N` 这一行里取数字。
 *
 * 不用正则：只认“纯十进制数字”，其余（缺行、空值、`abc`、`2.0`、多行垃圾）
 * 一律返回 NaN —— 由 `clampUnlocked` 统一转成 0。
 */
function parseUnlockedValue(text: string): number {
	const lines = text.split('\n');
	for (const rawLine of lines) {
		const line = rawLine.trim();
		if (!line.startsWith(ProgressKey)) continue;
		const value = line.substring(ProgressKey.length).trim();
		if (value.length === 0) continue;
		let digits = true;
		for (let i = 0; i < value.length; i++) {
			const c = value.charCodeAt(i);
			if (c < 48 || c > 57) digits = false;
		}
		if (!digits) continue;
		return Number.parseInt(value, 10);
	}
	return NaN;
}

/**
 * 读进度。文件不存在 / 内容损坏 / 数字非法 → `{ unlocked: 0 }`，**不抛错**。
 */
export function loadProgress(levelCount: number): Progress {
	const file = progressFilePath();
	let text = '';
	try {
		if (Content.exist(file)) text = Content.load(file);
	} catch (e) {
		// 读盘失败（权限、编码、半截文件）等同于“没有存档”
		return { unlocked: 0 };
	}
	return { unlocked: clampUnlocked(parseUnlockedValue(text), levelCount) };
}

/**
 * 写进度。覆盖写，内容严格是 `unlocked=N` 一行。
 *
 * 用 `toFixed(0)` 而不是 `String()`：Lua 5.3+ 的 `tostring(2.0)` 会输出
 * `"2.0"`，而存档解析只认纯数字，写出去会变成“读回来是 0”。
 */
export function saveProgress(p: Progress): void {
	let value = Math.floor(p.unlocked);
	if (value !== value || value === Infinity || value === -Infinity) value = 0;
	Content.save(progressFilePath(), ProgressKey + value.toFixed(0));
}
