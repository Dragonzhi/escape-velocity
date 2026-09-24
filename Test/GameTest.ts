/**
 * S1.5 单测：游戏状态机核心（纯逻辑，无需运行场景）。
 *
 * 输出格式：首行为 `passed` 或 `failed`。
 *   const m = requireProjectModule("Test.GameTest"); print(m.runTests())
 */
import { Body, P2 } from 'game/Gravity';
import { FlightPlayback, PhysicsStep } from 'game/Config';
import { GoalSpec } from 'game/LevelData';
import { GameLevel, coreLaunch, coreProbeIndex, coreRetry, coreUpdate, createCore, resolveResult } from 'game/Game';

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

export function runTests(): string {
	testResolveResult();
	testLaunch();
	testPlayback();
	testRetry();
	testIndexClamp();
	testDeterministicCycle();
	testGoalTruncation();

	const lines: string[] = [];
	lines.push(failures.length === 0 ? 'passed' : 'failed');
	lines.push(`checks=${checks} failures=${failures.length}`);
	const limit = failures.length < 12 ? failures.length : 12;
	for (let i = 0; i < limit; i++) {
		lines.push(`FAIL ${failures[i].name}: ${failures[i].detail}`);
	}
	return lines.join('\n');
}
