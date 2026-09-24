/**
 * S2.3 单测：解锁进度（纯函数 + 存档往返）与“返回关卡选择”的相态守卫。
 *
 * 为什么 `coreBackToSelect` 放在这里而不是 GameTest：它属于 S2.3 新增的
 * “结算 → 返回关卡选择 → 刷新解锁”这一条流程，和进度推进是一个整体故事；
 * GameTest 保持 S1.5 的发射 / 回放 / 重试职责不变（不把新断言塞进旧文件）。
 *
 * 输出格式（与其它单测一致）：首行 `passed` 或 `failed`，
 * 第二行 `checks=N failures=M`，之后每个失败一行 `FAIL name: detail`。
 *
 * 运行：`Test/UnitRunner.lua` 已把本模块列进 modules。
 */
import { Content } from 'Dora';
import { GameLevel, coreBackToSelect, coreLaunch, coreUpdate, createCore } from 'game/Game';
import { getLevel, scaledPlanets } from 'game/LevelData';
import { advanceUnlocked, clampUnlocked, loadProgress, progressFilePath, saveProgress } from 'game/Progress';

interface Failure {
	name: string;
	detail: string;
}

const failures: Failure[] = [];
let checks = 0;

function check(name: string, ok: boolean, detail: string): void {
	checks += 1;
	if (!ok) failures.push({ name, detail });
}

/** 测试关：直接用第一关的数据（真实数据比自造数字更能守住回归）。 */
function testLevel(): GameLevel | undefined {
	const def = getLevel(0);
	if (def === undefined) return undefined;
	return {
		bodies: scaledPlanets(def),
		probeStart: def.probeStart,
		goal: def.goal,
		escapeRadius: def.escapeRadius,
		maxSteps: def.maxSteps,
	};
}

/** 1) clampUnlocked：边界与非法输入。 */
function testClamp(): void {
	check('clamp-zero', clampUnlocked(0, 6) === 0, `got ${clampUnlocked(0, 6)}`);
	check('clamp-max', clampUnlocked(5, 6) === 5, `got ${clampUnlocked(5, 6)}`);
	check('clamp-over', clampUnlocked(9, 6) === 5, '超过上限必须夹到 levelCount-1');
	check('clamp-negative', clampUnlocked(-1, 6) === 0, '负数归 0');
	check('clamp-nan', clampUnlocked(NaN, 6) === 0, 'NaN 归 0');
	check('clamp-inf', clampUnlocked(Infinity, 6) === 0, 'Infinity 归 0');
	check('clamp-neg-inf', clampUnlocked(-Infinity, 6) === 0, '-Infinity 归 0');
	check('clamp-fraction', clampUnlocked(2.7, 6) === 2, '非整数向下取整');
	check('clamp-no-levels', clampUnlocked(3, 0) === 0, '关卡数为 0 时只能给 0');
	check('clamp-negative-levels', clampUnlocked(3, -2) === 0, '关卡数为负时只能给 0');
}

/** 2) advanceUnlocked：只有 success 解锁下一关，且不越界、不回退。 */
function testAdvance(): void {
	check('advance-first-success', advanceUnlocked(0, 'success', 0, 6) === 1, '通关第 1 关应解锁第 2 关');
	check('advance-mid-success', advanceUnlocked(2, 'success', 2, 6) === 3, '通关第 3 关应解锁第 4 关');
	check('advance-missed', advanceUnlocked(1, 'missed', 1, 6) === 1, '错过不解锁');
	check('advance-crashed', advanceUnlocked(1, 'crashed', 1, 6) === 1, '撞毁不解锁');
	check('advance-missed-zero', advanceUnlocked(0, 'missed', 0, 6) === 0, '错过不该凭空解锁');
	check('advance-last-level', advanceUnlocked(5, 'success', 5, 6) === 5, '最后一关通关不越界（仍是 5）');
	check('advance-no-downgrade', advanceUnlocked(3, 'success', 0, 6) === 3, '重玩旧关不回退进度');
	check('advance-clamps-junk', advanceUnlocked(99, 'missed', 0, 6) === 5, '非法入参也要夹紧');
	check('advance-nan-input', advanceUnlocked(NaN, 'success', 0, 6) === 1, 'NaN 进度 + 通关 = 解锁第 2 关');
}

/**
 * 3) 存档往返（真实读写 writablePath 下的文件）。
 *
 * 会**先读后还原**：单测不该把玩家进度改掉。测试期间会临时写入
 * `unlocked=3`、垃圾内容等，最后恢复测试前的值。
 */
function testPersistence(): void {
	const levelCountForSave = 6;
	const file = progressFilePath();
	// 测试前有没有存档不作断言（首次跑必然没有）；只保证结束时值被还原
	const before = loadProgress(levelCountForSave);

	// 正常写入 → 读出同样的值
	saveProgress({ unlocked: 3 });
	const raw = Content.exist(file) ? Content.load(file) : '';
	check('save-format', raw === 'unlocked=3', `文件内容应为单行 unlocked=3，实际 "${raw}"`);
	check('load-roundtrip', loadProgress(levelCountForSave).unlocked === 3, '存 3 读回来应是 3');

	// 越界值读回时夹紧
	saveProgress({ unlocked: 99 });
	check('load-clamps', loadProgress(levelCountForSave).unlocked === 5, '存档里的越界值读回应夹到 5');

	// 损坏内容一律视为 0，且不抛错
	Content.save(file, 'garbage');
	check('load-garbage', loadProgress(levelCountForSave).unlocked === 0, '垃圾内容应视为 0');
	Content.save(file, 'unlocked=abc');
	check('load-nonnumeric', loadProgress(levelCountForSave).unlocked === 0, '非数字值应视为 0');
	Content.save(file, '');
	check('load-empty', loadProgress(levelCountForSave).unlocked === 0, '空文件应视为 0');
	Content.save(file, 'other=4\nunlocked=2\n');
	check('load-extra-lines', loadProgress(levelCountForSave).unlocked === 2, '多行时应取 unlocked 行');

	// 还原
	saveProgress(before);
	check('restore', loadProgress(levelCountForSave).unlocked === before.unlocked,
		'还原失败：before=' + before.unlocked.toFixed(0) + ' after=' + loadProgress(levelCountForSave).unlocked.toFixed(0));
}

/** 4) coreBackToSelect：只有 Result 态可切，且切换后清空飞行/结算数据。 */
function testBackToSelect(): void {
	const level = testLevel();
	if (level === undefined) {
		check('back-level', false, '无法取得第一关数据');
		return;
	}

	// Aiming 态：不可用
	const core = createCore();
	check('back-guard-aiming', coreBackToSelect(core) === false && core.phase === 'Aiming',
		`Aiming 态应拒绝并保持相态，实际 phase=${core.phase}`);

	// Flying 态：不可用（松手后不可撤销，必须走完结算）
	coreLaunch(core, { x: 6, y: -12 }, level);
	check('back-guard-flying', coreBackToSelect(core) === false && core.phase === 'Flying',
		`Flying 态应拒绝并保持相态，实际 phase=${core.phase}`);

	// 推进到 Result 态：可用
	let guard = 0;
	while (core.phase !== 'Result' && guard < 100000) {
		coreUpdate(core, 1 / 60);
		guard += 1;
	}
	check('back-reached-result', core.phase === 'Result', `未能进入 Result，phase=${core.phase}`);
	check('back-from-result', coreBackToSelect(core) === true && core.phase === 'LevelSelect',
		`Result 态应成功切到 LevelSelect，实际 phase=${core.phase}`);
	check('back-clears-flight', core.flight === undefined, '返回后应清空飞行轨迹');
	check('back-clears-result', core.result === undefined, '返回后应清空结算');
	check('back-clears-goal', core.goalIndex === -1, '返回后应清空目标索引');
	check('back-clears-time', core.flightTime === 0, `返回后应清零回放时间，实际 ${core.flightTime}`);

	// 已经不在 Result：再次返回应被拒绝（幂等，不报错）
	check('back-twice', coreBackToSelect(core) === false && core.phase === 'LevelSelect',
		`重复返回应被拒绝且相态不变，实际 phase=${core.phase}`);
}

export function runTests(): string {
	testClamp();
	testAdvance();
	testPersistence();
	testBackToSelect();

	const lines: string[] = [];
	lines.push(failures.length === 0 ? 'passed' : 'failed');
	lines.push(`checks=${checks} failures=${failures.length}`);
	const limit = failures.length < 12 ? failures.length : 12;
	for (let i = 0; i < limit; i++) {
		lines.push(`FAIL ${failures[i].name}: ${failures[i].detail}`);
	}
	return lines.join('\n');
}
