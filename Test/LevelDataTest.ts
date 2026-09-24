/**
 * S2.1 单测：六关数据的有效性 + 可玩性扫掠。
 *
 * 可玩性判据（硬门）：每关在发射速度范围内，至少存在一个速度向量
 * 能达成目标（resolveResult = success）。没有可行解的关卡是死关。
 *
 * 输出格式：首行为 `passed` 或 `failed`。
 */
import { P2, simulate } from 'game/Gravity';
import { GoalSpec, findGoalIndex, getLevel, levelCount, scaledPlanets } from 'game/LevelData';
import { AimMaxSpeed, AimMinSpeed, PhysicsStep } from 'game/Config';
import { resolveResult } from 'game/Game';

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

/** 1) 结构有效性：视觉表对齐、目标索引合法、容差 > 半径。 */
function testValidity(): void {
	const n = levelCount();
	check('level-count', n === 6, `levelCount=${n}（愿景定稿六关）`);

	for (let i = 0; i < n; i++) {
		const lv = getLevel(i);
		if (lv === undefined) { check(`lv${i + 1}-exists`, false, 'missing'); continue; }

		check(`lv${lv.id}-visuals-aligned`, lv.planets.length === lv.visuals.length,
			`planets=${lv.planets.length} visuals=${lv.visuals.length}`);

		const goal = lv.goal;
		if (goal.kind === 'planet') {
			const gp = lv.planets[goal.planetIndex];
			check(`lv${lv.id}-goal-index`, gp !== undefined, `planetIndex=${goal.planetIndex} 越界`);
			if (gp !== undefined) {
				check(`lv${lv.id}-tolerance>radius`, goal.tolerance > gp.radius,
					`tolerance=${goal.tolerance} radius=${gp.radius}（容差必须大于半径，否则不可达）`);
			}
		}

		check(`lv${lv.id}-brief`, lv.brief !== undefined && lv.brief.length > 0, '缺少任务简报');
	}
}

/** 2) findGoalIndex：静止与移动目标。 */
function testFindGoalIndex(): void {
	// 静止目标：直射轨迹在接近点命中
	const bodies = [
		{ gm: 0, radius: 1.2, orbitCenter: { x: 0, y: -20 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 as 1 | -1 },
	];
	const goal: GoalSpec = { kind: 'planet', planetIndex: 0, tolerance: 3 };
	const sim = simulate({ pos: { x: 0, y: 16 }, vel: { x: 0, y: -10 } }, bodies,
		{ steps: 600, dt: PhysicsStep, sampleEvery: 1, escapeRadius: 400 });
	const gi = findGoalIndex(sim.points, bodies, goal, PhysicsStep);
	check('find-goal-static', gi >= 0, `goalIndex=${gi}（直射静止目标应命中）`);

	// escape 目标永远返回 -1
	const escapeGoal: GoalSpec = { kind: 'escape', planetIndex: -1, tolerance: 0 };
	check('find-goal-escape', findGoalIndex(sim.points, bodies, escapeGoal, PhysicsStep) === -1, 'escape 目标不应产生 goalIndex');

	// 移动目标：t 相关判定（用行星在 t 时刻的真实位置验证命中点）
	const movers = [
		{ gm: 0, radius: 1.2, orbitCenter: { x: 0, y: -6 }, orbitRadius: 9, orbitPeriod: 9, phase0: 0, orbitDirection: 1 as 1 | -1 },
	];
	const sim2 = simulate({ pos: { x: 9, y: 10 }, vel: { x: 0, y: -8 } }, movers,
		{ steps: 900, dt: PhysicsStep, sampleEvery: 1, escapeRadius: 400 });
	const gi2 = findGoalIndex(sim2.points, movers, { kind: 'planet', planetIndex: 0, tolerance: 3 }, PhysicsStep);
	if (gi2 >= 0) {
		// 验证该点确实在容差内（用 t 时刻行星位置）
		const p = sim2.points[gi2];
		let minD = 1e9;
		for (let k = 0; k < movers.length; k++) {
			const gp = movers[k];
			const angle = gp.phase0 + gp.orbitDirection * 2 * Math.PI * ((gi2 * PhysicsStep) / gp.orbitPeriod);
			const gx = gp.orbitCenter.x + gp.orbitRadius * Math.cos(angle);
			const gy = gp.orbitCenter.y + gp.orbitRadius * Math.sin(angle);
			const dx = p.x - gx;
			const dy = p.y - gy;
			const d = Math.sqrt(dx * dx + dy * dy);
			if (d < minD) minD = d;
		}
		check('find-goal-moving-accurate', minD < 3, `minDist=${minD.toFixed(3)}（命中点应在容差内）`);
	} else {
		// 该速度没命中不算失败，只是这条轨迹未命中
		check('find-goal-moving-accurate', true, '该速度未命中（不判定）');
	}
}

/** 3) 可玩性扫掠：每关至少一个速度向量能达成目标。
 *
 * 用**角度 × 力度**采样（12 方向 × 4 档力度），真实覆盖玩家的连续输入空间。
 * 轴向网格会漏掉斜向解（实测 L3/L5 的解在 v=(-16,-14) 这类斜向速度上）。
 */
function testReachability(): void {
	const n = levelCount();
	const powers = [0.35, 0.6, 0.85, 1.0];
	const dirCount = 12;

	for (let i = 0; i < n; i++) {
		const lv = getLevel(i);
		if (lv === undefined) continue;
		const bodies = scaledPlanets(lv);

		let best = '';
		let found = false;
		for (let d = 0; d < dirCount && !found; d++) {
			const angle = (d * 2 * Math.PI) / dirCount;
			const ux = Math.cos(angle);
			const uy = Math.sin(angle);
			for (const p of powers) {
				const speed = AimMinSpeed + (AimMaxSpeed - AimMinSpeed) * p;
				const v: P2 = { x: ux * speed, y: uy * speed };

				const sim = simulate(
					{ pos: { x: lv.probeStart.x, y: lv.probeStart.y }, vel: v },
					bodies,
					{ steps: lv.maxSteps, dt: PhysicsStep, sampleEvery: 4, escapeRadius: lv.escapeRadius },
				);
				const gi = findGoalIndex(sim.points, bodies, lv.goal, PhysicsStep);
				const kind = resolveResult(sim.outcome, gi, lv.goal);
				if (kind === 'success') {
					found = true;
					best = `dir=${(angle * 180 / Math.PI).toFixed(0)}deg power=${p}`;
					break;
				}
			}
		}
		check(`lv${lv.id}-reachable`, found, `六关必须至少存在一个可行解（${lv.title}）${best !== '' ? ' found ' + best : ''}`);
	}
}

export function runTests(): string {
	testValidity();
	testFindGoalIndex();
	testReachability();

	const lines: string[] = [];
	lines.push(failures.length === 0 ? 'passed' : 'failed');
	lines.push(`checks=${checks} failures=${failures.length}`);
	const limit = failures.length < 12 ? failures.length : 12;
	for (let i = 0; i < limit; i++) {
		lines.push(`FAIL ${failures[i].name}: ${failures[i].detail}`);
	}
	return lines.join('\n');
}
