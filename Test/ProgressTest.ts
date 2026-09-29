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
import { advanceUnlocked, clampUnlocked, getMissionCompleted, getMissionRockets, getTotalRockets, loadProgress, progressFilePath, recordMissionResult, saveProgress } from 'game/Progress';

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

/** 5) testRockets：多火箭记录、不降级、统计与兼容性 */
function testRockets(): void {
	const p0 = { unlocked: 0 };
	check('rocket-empty-l0', getMissionRockets(p0, 0) === 0, '未解锁关卡应为 0 颗火箭');
	const p1 = recordMissionResult(p0, 0, 2, 6);
	check('rocket-record-l0', getMissionRockets(p1, 0) === 2, '达成 2 枚火箭应返回 2');
	check('rocket-advance-unlocked', p1.unlocked === 1, '达成火箭应同时推进解锁');
	const p2 = recordMissionResult(p1, 0, 1, 6);
	check('rocket-no-downgrade', getMissionRockets(p2, 0) === 2, '低分不应覆盖高分');
	const p3 = recordMissionResult(p2, 1, 3, 6);
	check('rocket-record-l1', getMissionRockets(p3, 1) === 3, 'L2 达成 3 枚火箭应返回 3');
	check('rocket-total', getTotalRockets(p3, 6) === 5, '总火箭数应为 2+3=5');

	// 兼容性：旧存档 unlocked=2，没写 rockets 字段时，前两关应默认至少 1 枚火箭
	const pLegacy = { unlocked: 2 };
	check('rocket-legacy-l0', getMissionRockets(pLegacy, 0) === 1, '纯旧内存结构应兼容旧火箭读取');
	check('rocket-legacy-l1', getMissionRockets(pLegacy, 1) === 1, '纯旧内存结构应兼容旧火箭读取');
	check('rocket-legacy-l2', getMissionRockets(pLegacy, 2) === 0, '旧存档未通关的关卡应为 0');
	const zeroScoreClear = recordMissionResult({ unlocked: 0 }, 0, 0, 6, true);
	check('zero-score-clear', getMissionCompleted(zeroScoreClear, 0) && getMissionRockets(zeroScoreClear, 0) === 0 && zeroScoreClear.unlocked === 1, '零火箭成功应独立保存完成与解锁');

	// 存档往返测试
	const levelCountForSave = 6;
	const before = loadProgress(levelCountForSave);
	saveProgress(p3);
	const reloaded = loadProgress(levelCountForSave);
	check('rocket-save-roundtrip-l0', getMissionRockets(reloaded, 0) === 2, '写盘读回 L1 应为 2');
	check('rocket-save-roundtrip-l1', getMissionRockets(reloaded, 1) === 3, '写盘读回 L2 应为 3');
	check('rocket-save-roundtrip-unlocked', reloaded.unlocked === 2, '写盘读回 unlocked 应为 2');
	saveProgress({ unlocked: 2, rockets: { L1: 3, L2: 2 } });
	const migrated = loadProgress(levelCountForSave);
	check('legacy-completion-migrates', getMissionCompleted(migrated, 0) && getMissionCompleted(migrated, 1), '旧火箭记录应迁移为已完成');
	check('legacy-score-starts-zero', getMissionRockets(migrated, 0) === 0 && getMissionRockets(migrated, 1) === 0, '旧火箭评价不能折算为新点位分数');
	saveProgress(before);
}

export function runTests(): string {
	testClamp();
	testAdvance();
	testPersistence();
	testBackToSelect();
	testRockets();

	const lines: string[] = [];
	lines.push(failures.length === 0 ? 'passed' : 'failed');
	lines.push(`checks=${checks} failures=${failures.length}`);
	const limit = failures.length < 12 ? failures.length : 12;
	for (let i = 0; i < limit; i++) {
		lines.push(`FAIL ${failures[i].name}: ${failures[i].detail}`);
	}
	return lines.join('\n');
}
