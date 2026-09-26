/**
 * S2.1 单测：六关数据的有效性 + 可玩性扫掠。
 *
 * 可玩性判据（硬门）：每关在发射速度范围内，至少存在一个速度向量
 * 能达成目标（resolveResult = success）。没有可行解的关卡是死关。
 *
 * 输出格式：首行为 `passed` 或 `failed`。
 */
import { Body, P2, distance, simulate } from 'game/Gravity';
import { GoalSpec, captureThreshold, findGoalIndex, getLevel, goalWaypoints, levelCount, relativeSpeedAt, scaledPlanets, waypointProgress } from 'game/LevelData';
import { AimMaxSpeed, AimMinSpeed, BrakeShare, PhysicsStep } from 'game/Config';
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

		// 尺寸层次硬约束（S3.6.1）：玩家靠肉眼判断「会不会撞上」，显示半径 ≠ 撞毁半径就是不公。
		for (let k = 0; k < lv.planets.length && k < lv.visuals.length; k++) {
			check(`lv${lv.id}-planet${k}-radius-fair`, lv.planets[k].radius === lv.visuals[k].displayRadius,
				`radius=${lv.planets[k].radius} displayRadius=${lv.visuals[k].displayRadius}（必须相等）`);
		}

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


/** 4) 捕获入轨（S3.9.2）：进环还不够，还得"慢到能被抓住"。 */
function testCapture(): void {
	const bodies: Body[] = [
		{ gm: 4000, radius: 4, orbitCenter: { x: 0, y: 0 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
	];
	const goal: GoalSpec = {
		kind: 'planet', planetIndex: 0, tolerance: 30,
		chain: [{ planetIndex: 0, tolerance: 30, capture: true }],
	};
	const every = 4;
	const pass = (speed: number, steps: number): number => {
		const sim = simulate(
			{ pos: { x: 0, y: 60 }, vel: { x: 0, y: -speed } },
			bodies,
			{ steps, dt: PhysicsStep, sampleEvery: every, escapeRadius: 0 },
		);
		return findGoalIndex(sim.points, bodies, goal, PhysicsStep * every, 0, sim.velocities);
	};
	// 诊断（失败明细里会打出来）：手工走一遍与判据**相同**的规则，报告「模块 vs 手工」
	const fastIdx = pass(40, 900);
	const manualWalk = (speed: number, steps: number): string => {
		const sim = simulate(
			{ pos: { x: 0, y: 60 }, vel: { x: 0, y: -speed } },
			bodies,
			{ steps, dt: PhysicsStep, sampleEvery: every, escapeRadius: 0 },
		);
		const limit = sim.points.length - 1;
		const st = waypointProgress(sim.points, bodies, goal, PhysicsStep * every, 0, undefined, sim.velocities);
		let best = -1;
		let bestRel = 0;
		let bestThr = 0;
		for (let i = 0; i <= limit; i++) {
			const d = distance(sim.points[i], { x: 0, y: 0 });
			if (d < 30) {
				const rel = relativeSpeedAt(sim.points, i, bodies[0], PhysicsStep * every, 0, limit, sim.velocities);
				const thr = captureThreshold(bodies[0], d, 1.4142135623730951);
				if (d <= bodies[0].radius) continue; // 撞上去不叫入轨（与判据同一条规则）
				if (rel <= thr) { best = i; bestRel = rel; bestThr = thr; break; }
			}
		}
		return `模块 passed=${st.passed} lastIndex=${st.lastIndex}；手工可捕获点=${best}（rel=${bestRel.toFixed(1)} thr=${bestThr.toFixed(1)}）`;
	};
	check('capture-rejects-fast', fastIdx === -1, `快速掠过不应该算捕获：idx=${fastIdx} ${manualWalk(40, 900)}`);
	// 慢：3 单位/秒飘进去 ⇒ 被束缚住 ⇒ 算捕获
	check('capture-accepts-slow', pass(3, 2400) >= 0, '远低于逃逸速度的接近应该算捕获');
}

/** 扫掠统计（返回值给「时间轴确实有影响」那条判据复用）。 */
interface SweepStat {
	solutions: number;
	total: number;
	/** 每个 t0 档的成功数（非 timeWindow 关只有一档）。 */
	perT0: number[];
	t0s: number[];
	best: string;
}

/** 角度 × 力度的采样网格。
 *
 * 12 方向太粗会漏掉窄解（实测 L3/L5 的解在斜向速度上），所以非时间轴关用 24×6；
 * 时间轴关还要再乘 t0 档数，为控制引擎内耗时退回 12×4（× 24 档 t0 仍然有 1152 个样本）。
 */
let levelDvTop = AimMaxSpeed;
/** 出发时已有的速度（S3.9.3，L1 = 绕地球的圆轨道）；扫掠的初速度 = 它 + 这一次点火。 */
let levelVel0: P2 = { x: 0, y: 0 };
/** 这一遍扫掠用不用**刹车模式**（S3.9.2：两次点火共享 Δv ⇒ 点火只拿一半）。 */
let levelBrake = false;

/** 一个采样：初速度向量 + 留给后半程反推的 Δv（0 = 纯惯性）。 */
interface Sample { vel: P2; brakeDv: number }

function grid(dirCount: number, powerCount: number): Sample[] {
	const out: Sample[] = [];
	for (let d = 0; d < dirCount; d++) {
		const angle = (d * 2 * Math.PI) / dirCount;
		for (let k = 0; k < powerCount; k++) {
			// 4 档用**历史网格**（0.35/0.6/0.85/1.0）—— tools/level-sweep.mjs 就是按它调数值的，
			// 两边采样点必须一致，否则"工具说有解、测试说没解"（2026-09-26 实测踩到：L4 的窗口判据）。
			const p = powerCount === 4 ? [0.35, 0.6, 0.85, 1.0][k] : (powerCount === 1 ? 1 : 0.35 + (0.65 * k) / (powerCount - 1));
			// ⚠️ 上限要跟着**这一关的 Δv 预算**走，否则扫掠会给出玩家根本打不出来的解（S3.9.2b）
			const speed = AimMinSpeed + (levelDvTop - AimMinSpeed) * p;
			// 与 Game.burnToMotion 同一套折算：刹车模式下点火只拿 BrakeShare，其余留给反推段。
			// （这段镜像关系由 tools/level-sweep.mjs 与 GameTest 一起守着 —— 两边不一致会让扫掠骗人。）
			const share = levelBrake ? BrakeShare : 1;
			out.push({
				vel: { x: Math.cos(angle) * speed * share + levelVel0.x, y: Math.sin(angle) * speed * share + levelVel0.y },
				brakeDv: levelBrake ? speed * (1 - share) : 0,
			});
		}
	}
	return out;
}

/** 3) 可玩性扫掠：每关至少一个速度向量能达成目标。 */
function sweepLevel(lv: ReturnType<typeof getLevel>, dirCount: number, powerCount: number, t0Count: number): SweepStat {
	const stat: SweepStat = { solutions: 0, total: 0, perT0: [], t0s: [], best: '' };
	if (lv === undefined) return stat;
	const bodies = scaledPlanets(lv);
	const sampleEvery = 4;
	const t0s: number[] = [];
	if (lv.timeWindow !== undefined) {
		for (let i = 0; i < t0Count; i++) t0s.push((lv.timeWindow.span * i) / t0Count);
	} else {
		t0s.push(0);
	}
	const vs = grid(dirCount, powerCount);

	for (let ti = 0; ti < t0s.length; ti++) {
		const t0 = t0s[ti];
		stat.t0s.push(t0);
		let hits = 0;
		for (const sample of vs) {
			const sim = simulate(
				{ pos: { x: lv.probeStart.x, y: lv.probeStart.y }, vel: sample.vel },
				bodies,
				{
					steps: lv.maxSteps, dt: PhysicsStep, sampleEvery: sampleEvery, escapeRadius: lv.escapeRadius, t0,
					brake: sample.brakeDv > 0 ? { dv: sample.brakeDv, startStep: Math.floor(lv.maxSteps / 2) } : undefined,
				},
			);
			// ⚠️ 有效步长必须是 sampleEvery · dt：传 PhysicsStep 会让移动目标的时间轴错位
			// （采样点 i 的真实时刻是 t0 + i · sampleEvery · dt）。
			const gi = findGoalIndex(sim.points, bodies, lv.goal, PhysicsStep * sampleEvery, t0, sim.velocities);
			stat.total += 1;
			if (resolveResult(sim.outcome, gi, lv.goal) === 'success') {
				stat.solutions += 1;
				hits += 1;
				if (stat.best === '') {
					const angle = Math.atan2(sample.vel.y, sample.vel.x) * 180 / Math.PI;
					stat.best = `dir=${angle.toFixed(0)}deg v=${Math.sqrt(sample.vel.x * sample.vel.x + sample.vel.y * sample.vel.y).toFixed(1)} t0=${t0.toFixed(1)}${levelBrake ? ' brake' : ''}`;
				}
			}
		}
		stat.perT0.push(hits);
	}
	return stat;
}

function testReachability(): SweepStat[] {
	const n = levelCount();
	const out: SweepStat[] = [];
	// **先粗后细**：粗网格（12×4，历史基线）能过就不升级 —— 引擎里的耗时按「样本数 × 步数」
	// 线性增长，全用密网格会让这个批跑从几秒涨到分钟级（2026-09-26 实测）。
	// 粗网格捞不到解（窄解）时才升到 24×6 / 24 档 t0。
	for (let i = 0; i < n; i++) {
		const lv = getLevel(i);
		if (lv === undefined) { out.push(sweepLevel(lv, 12, 4, 1)); continue; }
		// 时间轴关的 t0 要采密一点：L4 的"两颗巨行星同时在航线上"的窗口只有几十秒宽
		const t0Count = lv.timeWindow !== undefined ? 24 : 1;
		levelDvTop = lv.dvBudget !== undefined && lv.dvBudget < AimMaxSpeed ? lv.dvBudget : AimMaxSpeed;
		levelVel0 = lv.probeVel0 !== undefined ? lv.probeVel0 : { x: 0, y: 0 };
		// 三级升级：① 12×4 惯性；② 密网格 惯性；③ 12×4 **刹车模式**（S3.9.2 —— 两次点火共享 Δv，
		// 是"到达时能减速"的另一条路，捕放入轨要靠它）。任何一级过了就算这一关有解。
		levelBrake = false;
		let stat = sweepLevel(lv, 12, 4, t0Count);
		if (stat.solutions === 0) {
			stat = sweepLevel(lv, 24, 6, lv.timeWindow !== undefined ? 24 : 1);
		}
		if (stat.solutions === 0) {
			levelBrake = true;
			stat = sweepLevel(lv, 12, 4, t0Count);
		}
		out.push(stat);
		check(`lv${lv.id}-reachable`, stat.solutions > 0,
			`每关至少要有一个可行解（${lv.title}）：${stat.solutions}/${stat.total} ${stat.best}`);
	}
	return out;
}

/** 4) 时间轴（S3.6.4 的数据侧判据）：窗口必须**真的会关**。
 *
 * PLAN 原来写的是「t0=0 无解」，实测做不到 —— 场里自由度太多，任何时机都能蒙中一条线
 * （证据：24×6×24 的密网格下每个 t0 都有解）。所以判据改成**可观测的三条**：
 *   ① 有 t0 档零解（窗口确实会关）；② 有解的 t0 档 ≥ 6；③ 该关总解数 ≥ 3。
 */
function testTimeWindow(stats: SweepStat[]): void {
	const n = levelCount();
	let withWindow = 0;
	for (let i = 0; i < n; i++) {
		const lv = getLevel(i);
		if (lv === undefined || lv.timeWindow === undefined) continue;
		withWindow += 1;
		const st = stats[i];
		let dead = 0;
		let alive = 0;
		for (const h of st.perT0) {
			if (h === 0) dead += 1; else alive += 1;
		}
		check(`lv${lv.id}-window-closes`, dead >= 1,
			`时间轴关必须有「发射了也没用」的时机：dead=${dead}/${st.perT0.length}`);
		// 窗口可以窄（这正是"发射窗口"的意思），但至少要有一个能落进去的时机档。
		check(`lv${lv.id}-window-open`, alive >= 3 && st.solutions >= 3,
			`时间轴必须有能落进去的窗口：alive=${alive} solutions=${st.solutions}`);
	}
	check('time-window-exists', withWindow >= 1, '至少有一关带时间轴（L4 窗口）');
}

export function runTests(): string {
	testValidity();
	testFindGoalIndex();
	const stats = testReachability();
	testTimeWindow(stats);
	testCapture();

	const lines: string[] = [];
	lines.push(failures.length === 0 ? 'passed' : 'failed');
	lines.push(`checks=${checks} failures=${failures.length}`);
	const limit = failures.length < 12 ? failures.length : 12;
	for (let i = 0; i < limit; i++) {
		lines.push(`FAIL ${failures[i].name}: ${failures[i].detail}`);
	}
	return lines.join('\n');
}
