/**
 * S1.5 单测：游戏状态机核心（纯逻辑，无需运行场景）。
 *
 * 输出格式：首行为 `passed` 或 `failed`。
 *   const m = requireProjectModule("Test.GameTest"); print(m.runTests())
 */
import { Body, P2 } from 'game/Gravity';
import { FlightPlayback, PhysicsStep, SlowMoFactor, SlowMoFloorDist, SlowMoRadiusFactor } from 'game/Config';
import { GoalSpec } from 'game/LevelData';
import {
	GameLevel, anchorBodyIndex, coreArm, coreBackToSelect, coreCancelArm, coreHandoffDate, coreLaunch,
	coreProbeIndex, coreRetry, coreTimeWarpAllowed, coreToggleView, coreUpdate,
	createCore, resolveResult, slowMotionBody,
} from 'game/Game';

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

/** 测试关：一颗静止行星在原点，探测器从 (0,16) 出发，目标 = 逃逸。 */
function testLevel(): GameLevel {
	const bodies: Body[] = [{
		gm: 900, radius: 2.2,
		orbitCenter: { x: 0, y: 0 }, orbitRadius: 0,
		orbitPeriod: 0, phase0: 0, orbitDirection: 1,
	}];
	return {
		bodies,
		probeStart: { x: 0, y: 16 },
		goal: { kind: 'escape', planetIndex: -1, tolerance: 0 },
		escapeRadius: 400,
		maxSteps: 1500,
	};
}

/** 1) 结算判定（手册 §5.8）。 */
function testResolveResult(): void {
	const escapeGoal: GoalSpec = { kind: 'escape', planetIndex: -1, tolerance: 0 };
	const planetGoal: GoalSpec = { kind: 'planet', planetIndex: 0, tolerance: 3 };

	// 到达目标优先于一切
	check('resolve-goal-first', resolveResult('crashed', 5, planetGoal) === 'success', '到达目标应优先于撞毁（轨迹在到达点截断）');
	check('resolve-goal-running', resolveResult('running', 3, planetGoal) === 'success', '到达目标即成功');

	// escape 目标
	check('resolve-escape-success', resolveResult('escaped', -1, escapeGoal) === 'success', '逃逸目标达成 = 成功');
	check('resolve-escape-timeout', resolveResult('running', -1, escapeGoal) === 'missed', '超时 = 错过');

	// planet 目标但未到达
	check('resolve-planet-escaped', resolveResult('escaped', -1, planetGoal) === 'missed', '飞出边界但未到达目标 = 错过');
	check('resolve-planet-crashed', resolveResult('crashed', -1, planetGoal) === 'crashed', '撞毁 = 撞毁');

	// 逃逸 + 航线（S3.11，L6 单程）：两个条件都要
	const chainedEscape: GoalSpec = {
		kind: 'escape', planetIndex: -1, tolerance: 0,
		chain: [{ planetIndex: 0, tolerance: 4, label: 'A' }, { planetIndex: 1, tolerance: 4, label: 'B' }],
	};
	check('resolve-escape-chain-both', resolveResult('escaped', 7, chainedEscape) === 'success', '逃逸关：走完航线 + 越界 = 成功');
	check('resolve-escape-chain-no-route', resolveResult('escaped', -1, chainedEscape) === 'missed', '逃逸关：只有越界、没走完航线 = 错过');
	check('resolve-escape-chain-no-escape', resolveResult('running', 7, chainedEscape) === 'missed', '逃逸关：只走完航线、没越界 = 错过');
	check('resolve-escape-chain-crashed', resolveResult('crashed', -1, chainedEscape) === 'crashed', '逃逸关：撞毁 = 撞毁');
}

/**
 * 1b) 时间流的相态守卫（S3.11）。
 *
 * 为什么要有它：飞行用的是 tWorld = t0 + flightTime，飞行途中改 t0 等于把参考系整个挪走，
 * 行星会在飞行路径底下跳位。所以"能不能改日期"必须由**相态**决定，而不是由按钮决定。
 */
function testTimeWarpGuard(): void {
	const level = testLevel();
	const core = createCore();
	check('time-warp-aiming', coreTimeWarpAllowed(core), `Aiming 应允许改日期：phase=${core.phase}`);
	coreArm(core);
	check('time-warp-armed', coreTimeWarpAllowed(core), `Armed 也应允许（瞄好了再挑日期）：phase=${core.phase}`);
	coreCancelArm(core);

	coreLaunch(core, { x: 6, y: -12 }, level);
	check('time-warp-flying', !coreTimeWarpAllowed(core), `Flying 必须禁止改日期：phase=${core.phase}`);

	let entered = false;
	let frames = 0;
	while (!entered && frames < 100000) {
		entered = coreUpdate(core, 1 / 60);
		frames += 1;
		if (core.phase === 'Result') break;
	}
	check('time-warp-result', !coreTimeWarpAllowed(core), `Result 必须禁止改日期：phase=${core.phase}`);
}

/**
 * 1c) 发射日期交棒（S3.12 修 bug：L4/L6 按下「发射」后行星跳回原位）。
 *
 * 守两件事：① 交棒方向对（发射 clock→t0 / 重试 t0→clock）；
 * ② **`t0 + clock` 守恒** —— 这是"交棒瞬间画面不跳"的数学表述。
 * 引擎侧的端到端证据见 PROGRESS 会话 44（发射前后两张截图的像素差）。
 */
function testDateHandoff(): void {
	const launch = coreHandoffDate(0, 180, true);
	check('handoff-launch-t0', launch.t0 === 180 && launch.clock === 0, `发射应交棒成 t0=${launch.t0} clock=${launch.clock}`);
	const retry = coreHandoffDate(180, 0, false);
	check('handoff-retry-clock', retry.t0 === 0 && retry.clock === 180, `重试应交棒成 t0=${retry.t0} clock=${retry.clock}`);
	check('handoff-sum-preserved-launch', 0 + 180 === launch.t0 + launch.clock, '交棒前后 t0+clock 必须守恒（发射）');
	check('handoff-sum-preserved-retry', 180 + 0 === retry.t0 + retry.clock, '交棒前后 t0+clock 必须守恒（重试）');

	// 日期必须真的进物理：同一发点火，在不同 t0 下结果不同（一颗会动的靶子）
	const T = 400;
	const bodies: Body[] = [{
		gm: 0, radius: 1.4,
		orbitCenter: { x: 0, y: 0 }, orbitRadius: 40, orbitPeriod: T,
		phase0: 0, orbitDirection: 1,
	}];
	const level: GameLevel = {
		bodies,
		probeStart: { x: 0, y: 16 },
		goal: { kind: 'planet', planetIndex: 0, tolerance: 3 },
		escapeRadius: 900,
		maxSteps: 1500,
	};
	// 直飞拦截：从 (0,16) 朝靶子 2.15 秒后的位置打（靶子在 400 秒里走 360°，此时走了 1.94°）
	const ang = (-20.1 * Math.PI) / 180;
	const burn = { x: Math.cos(ang) * 19.8, y: Math.sin(ang) * 19.8 };
	const a = createCore();
	a.t0 = 0;
	coreLaunch(a, burn, level);
	check('launch-date-hits-at-zero', a.goalIndex >= 0, `t0=0 应命中：goalIndex=${a.goalIndex}`);
	const b = createCore();
	b.t0 = T / 2; // 靶子转到对面去了
	coreLaunch(b, burn, level);
	check('launch-date-misses-at-half', b.goalIndex < 0, `t0=${T / 2} 应打空：goalIndex=${b.goalIndex}`);
}

/** 2) 发射：预推演、阶段切换、重复发射被拒绝。 */
function testLaunch(): void {
	const level = testLevel();
	const core = createCore();

	coreLaunch(core, { x: 6, y: -12 }, level);
	check('launch-phase', core.phase === 'Flying', `phase=${core.phase}`);
	check('launch-flight', core.flight !== undefined && core.flight.points.length > 1, '飞行轨迹未预推演');
	check('launch-time-zero', core.flightTime === 0, `flightTime=${core.flightTime}`);

	// Flying 态再发射应被拒绝
	const before = core.flight !== undefined ? core.flight.points.length : 0;
	coreLaunch(core, { x: 0, y: -20 }, level);
	const after = core.flight !== undefined ? core.flight.points.length : 0;
	check('launch-guard', before === after, 'Flying 态发射未被拒绝');
}

/** 3) 回放：时间推进 → 索引推进；到达终点恰好进入 Result。 */
function testPlayback(): void {
	const level = testLevel();
	const core = createCore();
	coreLaunch(core, { x: 6, y: -12 }, level);
	const flight = core.flight;
	if (flight === undefined) { check('playback-flight', false, 'no flight'); return; }

	const total = flight.points.length - 1;
	check('playback-start-index', coreProbeIndex(core) === 0, `idx=${coreProbeIndex(core)}`);

	// 推进一小段时间
	let entered = false;
	let frames = 0;
	while (!entered && frames < 100000) {
		entered = coreUpdate(core, 1 / 60);
		frames += 1;
		if (core.phase === 'Result') break;
	}

	check('playback-enters-result', entered && core.phase === 'Result', `phase=${core.phase} frames=${frames}`);
	check('playback-final-index', coreProbeIndex(core) === total, `idx=${coreProbeIndex(core)} total=${total}`);
	check('playback-result-kind', core.result === resolveResult(flight.outcome, core.goalIndex, level.goal), `result=${core.result} outcome=${flight.outcome}`);

	// 回放时长应与 FlightPlayback 一致：总物理时间 = total * dt，真实时间 = 物理时间 / FlightPlayback
	const expectedRealSeconds = (total * PhysicsStep) / FlightPlayback;
	const actualRealSeconds = frames / 60;
	const tolerance = expectedRealSeconds * 0.05 + 0.05;
	check('playback-duration', Math.abs(actualRealSeconds - expectedRealSeconds) < tolerance,
		`expected≈${expectedRealSeconds.toFixed(2)}s actual=${actualRealSeconds.toFixed(2)}s`);
}

/** 4) 重试：清空飞行与结算，回到 Aiming；非 Result 态重试被拒绝。 */
function testRetry(): void {
	const level = testLevel();
	const core = createCore();

	// Aiming 态重试应被拒绝（无副作用）
	coreRetry(core);
	check('retry-guard-aiming', core.phase === 'Aiming', `phase=${core.phase}`);

	coreLaunch(core, { x: 6, y: -12 }, level);
	let entered = false;
	let guard = 0;
	while (!entered && guard < 100000) {
		entered = coreUpdate(core, 1 / 60);
		guard += 1;
	}
	check('retry-reached-result', core.phase === 'Result', `phase=${core.phase}`);

	coreRetry(core);
	check('retry-phase', core.phase === 'Aiming', `phase=${core.phase}`);
	check('retry-flight-cleared', core.flight === undefined, '飞行轨迹未清空');
	check('retry-result-cleared', core.result === undefined, '结算未清空');
	check('retry-goal-cleared', core.goalIndex === -1, '目标索引未清空');
	check('retry-time-reset', core.flightTime === 0, `flightTime=${core.flightTime}`);

	// 重试后可再次发射（完整循环）
	coreLaunch(core, { x: 0, y: -20 }, level);
	check('retry-relaunch', core.phase === 'Flying' && core.flight !== undefined, `phase=${core.phase}`);
}

/** 5) 索引夹紧：极端时间不越界。 */
function testIndexClamp(): void {
	const level = testLevel();
	const core = createCore();
	coreLaunch(core, { x: 6, y: -12 }, level);
	const flight = core.flight;
	if (flight === undefined) { check('clamp-flight', false, 'no flight'); return; }

	core.flightTime = -100;
	check('clamp-negative', coreProbeIndex(core) === 0, `idx=${coreProbeIndex(core)}`);

	core.flightTime = 1e9;
	check('clamp-huge', coreProbeIndex(core) === flight.points.length - 1, `idx=${coreProbeIndex(core)}`);
}

/** 6) 确定性贯穿状态机：同一发射向量两次完整流程，结局一致。 */
function testDeterministicCycle(): void {
	const level = testLevel();
	const results: string[] = [];
	for (let run = 0; run < 2; run++) {
		const core = createCore();
		coreLaunch(core, { x: 6, y: -12 }, level);
		let guard = 0;
		while (core.phase !== 'Result' && guard < 100000) {
			coreUpdate(core, 1 / 60);
			guard += 1;
		}
		results.push(`${core.result}:${core.flight !== undefined ? core.flight.outcome : 'none'}:${core.flight !== undefined ? core.flight.points.length : 0}`);
	}
	check('cycle-deterministic', results[0] === results[1], `${results[0]} vs ${results[1]}`);
}

/** 7) 目标截断：到达目标后飞行提前结束，结算为成功。 */
function testGoalTruncation(): void {
	// 目标行星在正前方 (0,-20)，容差 3；直射即可到达
	const bodies: Body[] = [
		{ gm: 0, radius: 1.2, orbitCenter: { x: 0, y: -20 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
	];
	const level: GameLevel = {
		bodies,
		probeStart: { x: 0, y: 16 },
		goal: { kind: 'planet', planetIndex: 0, tolerance: 3 },
		escapeRadius: 400,
		maxSteps: 1500,
	};

	const core = createCore();
	coreLaunch(core, { x: 0, y: -10 }, level);

	check('goal-found', core.goalIndex >= 0, `goalIndex=${core.goalIndex}`);
	check('goal-result-at-launch', core.result === 'success', `result=${core.result}（结算应在发射瞬间确定）`);

	const flight = core.flight;
	if (flight === undefined || core.goalIndex < 0) { check('goal-flight', false, 'no flight'); return; }

	// 回放应在 goalIndex 处提前收束（早于自然终点）
	let guard = 0;
	while (core.phase !== 'Result' && guard < 100000) {
		coreUpdate(core, 1 / 60);
		guard += 1;
	}
	check('goal-ends-early', core.phase === 'Result' && coreProbeIndex(core) === core.goalIndex,
		`idx=${coreProbeIndex(core)} goal=${core.goalIndex} natural=${flight.points.length - 1}`);
	check('goal-still-success', core.result === 'success', `result=${core.result}`);
}

/**
 * 11) Armed 状态（S3.10）：松手进 Armed、点「发射」才真的打出去。
 *
 * 这几条是"松手不发射"这条交互的**纯逻辑证据** —— 合成鼠标那一路受引擎丢事件影响，
 * 状态机这一路必须自己站稳。
 */
function testArmed(): void {
	const level = testLevel();
	const core = createCore();
	check('arm-from-aiming', coreArm(core) === true && core.phase === 'Armed', `phase=${core.phase}`);
	check('arm-idempotent', coreArm(core) === false, '已在 Armed 时 coreArm 应返回 false（不能重复 arm）');
	// Armed 下依然可以发射（这就是「发射」按钮走的路径）
	coreLaunch(core, { x: 0, y: -20 }, level);
	check('launch-from-armed', core.phase === 'Flying', `phase=${core.phase}`);
	// 取消瞄准：只在 Armed 有效
	const core2 = createCore();
	check('cancel-guard', coreCancelArm(core2) === false, 'Aiming 态调用 coreCancelArm 应返回 false');
	coreArm(core2);
	check('cancel-armed', coreCancelArm(core2) === true && core2.phase === 'Aiming', `phase=${core2.phase}`);
	// 重试后回到 Aiming（不是 Armed）
	const core3 = createCore();
	coreArm(core3);
	coreRetry(core3);
	check('retry-clears-armed', core3.phase === 'Aiming', `phase=${core3.phase}`);
}

/**
 * 12) 视图模式（S3.15）：2D 规划 ⇄ 3D 观赏。
 *
 * 设计稿第 4 条的自动切换**必须是相态流转的副产品**，不是 UI 的补丁：
 *   Aiming/Armed → 2D；coreLaunch → 3D；Result 留 3D；coreRetry → 2D；coreBackToSelect → 2D。
 * 手动切换（右下角按钮）走 `coreToggleView`，状态仍然只有一个（`GameCore.viewMode`）。
 *
 * 引擎侧端到端证据（截图 + 日志行）见 PROGRESS 会话 47。
 */
function testViewMode(): void {
	const level = testLevel();
	const core = createCore();
	check('view-aiming-2d', core.viewMode === '2D', `进关应为 2D：viewMode=${core.viewMode}`);

	coreArm(core);
	check('view-armed-2d', core.viewMode === '2D', `Armed（还没发射）应留 2D：viewMode=${core.viewMode}`);

	// 手动切换：状态翻转 + 返回值就是新状态（按钮文字读它）
	const flipped = coreToggleView(core);
	check('view-toggle-to-3d', flipped === '3D' && core.viewMode === '3D', `flip=${flipped} viewMode=${core.viewMode}`);
	check('view-toggle-back', coreToggleView(core) === '2D' && core.viewMode === '2D', `viewMode=${core.viewMode}`);

	// 按下发射 ⇒ 无论玩家之前手动切到哪，都进 3D
	coreToggleView(core); // 又切回 3D
	coreLaunch(core, { x: 6, y: -12 }, level);
	check('view-launch-3d', core.viewMode === '3D' && core.phase === 'Flying', `viewMode=${core.viewMode} phase=${core.phase}`);

	// 飞行与结算都留在 3D
	let guard = 0;
	while (core.phase !== 'Result' && guard < 100000) {
		coreUpdate(core, 1 / 60);
		guard += 1;
	}
	check('view-result-3d', core.viewMode === '3D' && core.phase === 'Result', `viewMode=${core.viewMode} phase=${core.phase}`);

	// 重试 ⇒ 回 2D（重新规划）
	coreRetry(core);
	check('view-retry-2d', core.viewMode === '2D' && core.phase === 'Aiming', `viewMode=${core.viewMode} phase=${core.phase}`);

	// 返回关卡选择 ⇒ 也回 2D（下一关是从 2D 开始的）
	// ⚠️ coreBackToSelect **只在 Result 态有效**（"飞行途中不许撤退"）：先推进到结算再退，
	// 否则它返回 false、视图也不会变 —— 第一版就漏了这一步，断言把测试自己的 bug 报成了实现 bug
	const core2 = createCore();
	coreLaunch(core2, { x: 0, y: -20 }, level);
	let guard2 = 0;
	while (core2.phase !== 'Result' && guard2 < 100000) {
		coreUpdate(core2, 1 / 60);
		guard2 += 1;
	}
	check('view-back-to-select-2d', coreBackToSelect(core2) === true && core2.viewMode === '2D', `viewMode=${core2.viewMode} phase=${core2.phase}`);
}


/**
 * 13) 掠过自动慢动作（S3.17）：触发口径「最近接近任何天体」+ 播放倍速。
 *
 * 守四件事：① 阈值 = max(半径 × 5, 8)，锚点（太阳）不参与；② 阈值内取**最近**的天体；
 * ③ 慢动作 = 手动档 × 1/4（默认 2× ⇒ 0.5× 实时，不是 0.25× 实时也不是 1.5×）；
 * ④ **同样帧数下推进的世界时间更少** —— 这是"真的放慢了"的确定性表述。
 */
function testSlowMotion(): void {
	// 场：太阳（锚点，半径 28）+ 一颗绕日行星（半径 4.63，t=0 时在 (60,0)）
	const bodies: Body[] = [
		{ gm: 72000, radius: 28, orbitCenter: { x: 0, y: 0 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
		{ gm: 0, radius: 4.63, orbitCenter: { x: 0, y: 0 }, orbitRadius: 60, orbitPeriod: 600, phase0: 0, orbitDirection: 1 },
	];
	const anchor = anchorBodyIndex(bodies);
	check('slowmo-anchor-sun', anchor === 0, 'anchor=' + anchor + '（应是不绕别人转的太阳）');

	// 阈值 = max(4.63 × 5, 8) = 23.15
	const threshold = Math.max(4.63 * SlowMoRadiusFactor, SlowMoFloorDist);
	check('slowmo-threshold-value', Math.abs(threshold - 23.15) < 1e-9, 'threshold=' + threshold);
	check('slowmo-outside', slowMotionBody(bodies, { x: 30, y: 0 }, 0, anchor) === -1, '距行星 30 > 23.15 不该触发');
	check('slowmo-inside', slowMotionBody(bodies, { x: 50, y: 0 }, 0, anchor) === 1, '距行星 10 < 23.15 应触发');
	// 锚点排除：太阳半径 28 × 5 = 140 > 探测器出发距离 80 ⇒ 不排除就是六关全程慢动作
	check('slowmo-anchor-excluded', slowMotionBody(bodies, { x: 20, y: 0 }, 0, anchor) === -1,
		'太阳（锚点）即使在阈值内也不触发');
	// 小天体走地板：半径 1 ⇒ 阈值 8（不是 5）—— 月球抵达容差 5 必须被盖住
	const tiny: Body[] = [
		bodies[0],
		{ gm: 0, radius: 1.0, orbitCenter: { x: 0, y: 0 }, orbitRadius: 60, orbitPeriod: 600, phase0: 0, orbitDirection: 1 },
	];
	check('slowmo-floor-in', slowMotionBody(tiny, { x: 55, y: 0 }, 0, anchor) === 1, '距 5 < 地板 8 ⇒ 触发');
	check('slowmo-floor-out', slowMotionBody(tiny, { x: 50, y: 0 }, 0, anchor) === -1, '距 10 > 地板 8 ⇒ 不触发');
	// 多个天体在阈值内 ⇒ 最近的那个赢（"最近接近任何天体"）
	const two: Body[] = [
		bodies[0],
		{ gm: 0, radius: 4.63, orbitCenter: { x: 0, y: 0 }, orbitRadius: 60, orbitPeriod: 600, phase0: 0, orbitDirection: 1 },
		{ gm: 0, radius: 3.04, orbitCenter: { x: 0, y: 0 }, orbitRadius: 60, orbitPeriod: 600, phase0: (20 * Math.PI) / 180, orbitDirection: 1 },
	];
	check('slowmo-nearest-a', slowMotionBody(two, { x: 58, y: 10 }, 0, anchor) === 1, '离 1 号更近 ⇒ 选 1 号');
	check('slowmo-nearest-b', slowMotionBody(two, { x: 57, y: 15 }, 0, anchor) === 2, '离 2 号更近 ⇒ 选 2 号');
}

/** 13b) 播放倍速：手动档 1/2/4 × 慢动作 1/4；同样帧数下世界时间更少。 */
function testPlaybackSpeed(): void {
	const level = testLevel();

	// 默认手动档 = FlightPlayback = 2×（历史行为不变）
	const core = createCore();
	check('playback-default', core.playback === FlightPlayback && core.playback === 2, 'playback=' + core.playback);
	coreLaunch(core, { x: 6, y: -12 }, level);
	core.playback = 4;
	const t0 = core.flightTime;
	for (let i = 0; i < 60; i++) coreUpdate(core, 1 / 60);
	check('playback-4x', Math.abs(core.flightTime - t0 - 4) < 1e-9,
		'60 帧 × 1/60 秒 × 4× = 4.000，实际 Δt=' + (core.flightTime - t0).toFixed(3));

	// 慢动作：同样 60 帧只推进 1 秒（4 × 0.25）——"同样帧数下推进的世界时间更少"
	core.slowmo = true;
	const t1 = core.flightTime;
	for (let i = 0; i < 60; i++) coreUpdate(core, 1 / 60);
	check('playback-slowmo-quarter', Math.abs(core.flightTime - t1 - 1) < 1e-9,
		'4× 慢动作 60 帧应推进 1.000，实际 Δt=' + (core.flightTime - t1).toFixed(3));

	// 基准口径（写进注释的那个）：默认手动档 2× 的慢动作 = 0.5× 实时
	const core2 = createCore();
	coreLaunch(core2, { x: 6, y: -12 }, level);
	core2.slowmo = true;
	const t2 = core2.flightTime;
	for (let i = 0; i < 60; i++) coreUpdate(core2, 1 / 60);
	check('playback-default-slowmo-half', Math.abs(core2.flightTime - t2 - 0.5) < 1e-9,
		'2× 慢动作 60 帧应推进 0.500（≈0.5× 实时），实际 Δt=' + (core2.flightTime - t2).toFixed(3));

	// 不传 level ⇒ 不判定慢动作（旧路径/测试行为不变）
	const core3 = createCore();
	coreLaunch(core3, { x: 6, y: -12 }, level);
	for (let i = 0; i < 30; i++) coreUpdate(core3, 1 / 60);
	check('playback-no-level', !core3.slowmo && core3.slowmoBody === -1, 'slowmo=' + core3.slowmo + ' body=' + core3.slowmoBody);

	// level 驱动：出发就在阈值内 ⇒ coreUpdate 自己打开慢动作，速度掉到 2 × 0.25
	const bodies: Body[] = [
		{ gm: 72000, radius: 28, orbitCenter: { x: 0, y: 0 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
		{ gm: 0, radius: 4.63, orbitCenter: { x: 0, y: 0 }, orbitRadius: 60, orbitPeriod: 600, phase0: 0, orbitDirection: 1 },
	];
	const nearLevel: GameLevel = {
		bodies,
		probeStart: { x: 50, y: 0 }, // 距行星 (60,0) 10 < 23.15 ⇒ 出发即在慢动作里（gm=0：不被引力搅局）
		goal: { kind: 'escape', planetIndex: -1, tolerance: 0 },
		escapeRadius: 400,
		maxSteps: 600,
	};
	const core4 = createCore();
	coreLaunch(core4, { x: 0, y: 5 }, nearLevel);
	const t3 = core4.flightTime;
	for (let i = 0; i < 60; i++) coreUpdate(core4, 1 / 60, nearLevel);
	check('playback-level-driven', core4.slowmo && core4.slowmoBody === 1 && Math.abs(core4.flightTime - t3 - 0.5) < 1e-9,
		'slowmo=' + core4.slowmo + ' body=' + core4.slowmoBody + ' Δt=' + (core4.flightTime - t3).toFixed(3) + ' 期望 0.500');
}

export function runTests(): string {
	testResolveResult();
	testTimeWarpGuard();
	testDateHandoff();
	testLaunch();
	testArmed();
	testPlayback();
	testRetry();
	testIndexClamp();
	testDeterministicCycle();
	testGoalTruncation();
	testViewMode();
	testSlowMotion();
	testPlaybackSpeed();

	const lines: string[] = [];
	lines.push(failures.length === 0 ? 'passed' : 'failed');
	lines.push(`checks=${checks} failures=${failures.length}`);
	const limit = failures.length < 12 ? failures.length : 12;
	for (let i = 0; i < limit; i++) {
		lines.push(`FAIL ${failures[i].name}: ${failures[i].detail}`);
	}
	return lines.join('\n');
}
