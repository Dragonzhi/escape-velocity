/**
 * 进度与评价系统（S2.3 建立，S7 升级：任务三枚火箭 🚀🚀🚀 评价与非线性存档，决策 D5）。
 *
 * 语义（手册 §4.3.1 与设计案 §3.2/§4.3）：
 * - `unlocked`：已解锁最高关卡索引（兼容旧版线性流程）；
 * - `rockets`：各关卡历史获得的最高火箭数（0 ~ 3 枚），键为 "L1" ~ "L6"；
 * - 关卡去线性化后，全部关卡对玩家开放，进度主要用于记录与展示已获得的 🚀 勋章；
 * - 存档：`<writablePath>/escape-velocity.progress`，首行保留 `unlocked=N` 兼容旧版，后续行记录 `L1=3`、`L2=2` 等。
 *
 * 纯函数不碰引擎对象，可被单测直接调用；读写函数对任何异常输入均不抛错。
 */
import { Content, Path } from 'Dora';
import { ResultKind } from 'game/Game';

/** 进度：完成记录与新点位最高分分开；rockets 保留旧版本历史字段。 */
export interface Progress {
	unlocked: number;
	rockets?: Record<string, number>;
	completed?: Record<string, boolean>;
	bestScores?: Record<string, number>;
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
 */
export function clampUnlocked(value: number, levelCount: number): number {
	if (levelCount <= 0) return 0;
	if (value !== value) return 0;
	if (value === Infinity || value === -Infinity) return 0;
	if (value < 0) return 0;
	const max = levelCount - 1;
	if (value > max) return max;
	return Math.floor(value);
}

/**
 * 结算后推进解锁进度（纯函数）。
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

/** 获取关卡点位火箭最高分；未迁移的旧内存结构仍可读取历史火箭字段。 */
export function getMissionRockets(p: Progress, levelIndex: number): number {
	const key = 'L' + (levelIndex + 1).toFixed(0);
	if (p.bestScores !== undefined && typeof p.bestScores[key] === 'number') return Math.max(0, Math.min(99, Math.floor(p.bestScores[key])));
	if (p.rockets !== undefined && typeof p.rockets[key] === 'number') {
		const r = Math.floor(p.rockets[key]);
		if (r >= 0 && r <= 3) return r;
		if (r > 3) return 3;
		return 0;
	}
	// 兼容旧存档：若旧存档已解锁到本关之后，默认至少达成 1 枚火箭
	if (levelIndex < p.unlocked) return 1;
	return 0;
}

/** 记录关卡评价，更新火箭数并推进解锁（不回退）。 */
export function recordMissionResult(
	p: Progress,
	levelIndex: number,
	rocketCount: number,
	levelCount: number,
	completed?: boolean,
): Progress {
	const didComplete = completed !== undefined ? completed : rocketCount > 0;
	const clampedRockets = didComplete ? Math.max(0, Math.min(99, Math.floor(rocketCount))) : 0;
	const key = 'L' + (levelIndex + 1).toFixed(0);
	const oldRockets = p.bestScores !== undefined && p.bestScores[key] !== undefined ? p.bestScores[key] : 0;
	const bestRockets = Math.max(oldRockets, clampedRockets);
	const nextUnlocked = didComplete
		? advanceUnlocked(p.unlocked, 'success', levelIndex, levelCount)
		: clampUnlocked(p.unlocked, levelCount);

	const nextMap: Record<string, number> = {};
	if (p.rockets !== undefined) {
		for (const k in p.rockets) {
			nextMap[k] = p.rockets[k];
		}
	}
	const completedMap: Record<string, boolean> = {};
	if (p.completed !== undefined) for (const k in p.completed) completedMap[k] = p.completed[k];
	const bestMap: Record<string, number> = {};
	if (p.bestScores !== undefined) for (const k in p.bestScores) bestMap[k] = p.bestScores[k];
	completedMap[key] = didComplete || getMissionCompleted(p, levelIndex);
	bestMap[key] = bestRockets;
	// Preserve legacy rocket records for old clients/statistics without treating them as new point scores.
	if (nextMap[key] === undefined) nextMap[key] = p.rockets !== undefined && p.rockets[key] !== undefined ? p.rockets[key] : 0;

	return {
		unlocked: nextUnlocked,
		rockets: nextMap,
		completed: completedMap,
		bestScores: bestMap,
	};
}

export function getMissionCompleted(p: Progress, levelIndex: number): boolean {
	const key = 'L' + (levelIndex + 1).toFixed(0);
	if (p.completed !== undefined && p.completed[key] !== undefined) return p.completed[key];
	const rockets = p.rockets !== undefined && p.rockets[key] !== undefined ? p.rockets[key] : 0;
	return rockets > 0 || levelIndex < p.unlocked;
}

/** 统计全太阳系获得的火箭总数。 */
export function getTotalRockets(p: Progress, levelCount: number): number {
	let total = 0;
	for (let i = 0; i < levelCount; i++) {
		total += getMissionRockets(p, i);
	}
	return total;
}

/** 解析纯十进制数字。 */
function parseDigits(value: string): number {
	const v = value.trim();
	if (v.length === 0) return NaN;
	for (let i = 0; i < v.length; i++) {
		const c = v.charCodeAt(i);
		if (c < 48 || c > 57) return NaN;
	}
	return Number.parseInt(v, 10);
}

/**
 * 读进度。文件不存在 / 内容损坏 / 数字非法 → `{ unlocked: 0, rockets: {} }`，不抛错。
 */
export function loadProgress(levelCount: number): Progress {
	const file = progressFilePath();
	let text = '';
	try {
		if (Content.exist(file)) text = Content.load(file);
	} catch (e) {
		return { unlocked: 0, rockets: {}, completed: {}, bestScores: {} };
	}

	let unlocked = 0;
	const rockets: Record<string, number> = {};
	const completed: Record<string, boolean> = {};
	const bestScores: Record<string, number> = {};

	const lines = text.split('\n');
	for (const rawLine of lines) {
		const line = rawLine.trim();
		if (line.startsWith(ProgressKey)) {
			const val = parseDigits(line.substring(ProgressKey.length));
			if (!isNaN(val)) unlocked = clampUnlocked(val, levelCount);
		} else if (line.startsWith('complete:')) {
			const parts = line.substring(8).split('=');
			if (parts.length === 2) completed[parts[0]] = parts[1] === '1';
		} else if (line.startsWith('best:')) {
			const parts = line.substring(5).split('=');
			if (parts.length === 2) { const val = parseDigits(parts[1]); if (!isNaN(val)) bestScores[parts[0]] = Math.max(0, val); }
		} else if (line.startsWith('L') && line.indexOf('=') > 0) {
			const parts = line.split('=');
			if (parts.length === 2) {
				const key = parts[0].trim();
				const val = parseDigits(parts[1]);
				if (!isNaN(val)) {
					rockets[key] = Math.max(0, Math.min(3, val));
				}
			}
		}
	}

	for (let i = 0; i < levelCount; i++) {
		const key = 'L' + (i + 1).toFixed(0);
		if (completed[key] === undefined) completed[key] = (rockets[key] !== undefined && rockets[key] > 0) || i < unlocked;
		// Existing rocket counts are historical only; new bonus-point scores start at zero.
		if (bestScores[key] === undefined) bestScores[key] = 0;
	}
	return { unlocked, rockets, completed, bestScores };
}

/**
 * 写进度。保留旧 `unlocked`/`L1` 行，并增加 `complete:L1=1`、`best:L1=N`。
 */
export function saveProgress(p: Progress): void {
	let value = Math.floor(p.unlocked);
	if (value !== value || value === Infinity || value === -Infinity) value = 0;

	const lines: string[] = [ProgressKey + value.toFixed(0), 'version=2'];
	if (p.rockets !== undefined) {
		for (const k in p.rockets) {
			const r = p.rockets[k];
			if (typeof r === 'number' && r > 0) {
				lines.push(k + '=' + Math.floor(r).toFixed(0));
			}
		}
	}
	if (p.completed !== undefined) for (const k in p.completed) lines.push('complete:' + k + '=' + (p.completed[k] ? '1' : '0'));
	if (p.bestScores !== undefined) for (const k in p.bestScores) lines.push('best:' + k + '=' + Math.max(0, Math.floor(p.bestScores[k])).toFixed(0));
	Content.save(progressFilePath(), lines.join('\n'));
}

