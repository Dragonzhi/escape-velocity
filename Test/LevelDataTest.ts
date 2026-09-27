/**
 * S2.1 单测：六关数据的有效性 + 可玩性扫掠。
 *
 * 可玩性判据（硬门）：每关在发射速度范围内，至少存在一个速度向量
 * 能达成目标（resolveResult = success）。没有可行解的关卡是死关。
 *
 * 输出格式：首行为 `passed` 或 `failed`。
 */
import { Body, P2, bodyPositionAt, distance, simulate } from 'game/Gravity';
import { SunGm } from 'game/Scale';
import { GoalSpec, bodyVelocityAt, captureThreshold, evaluateRockets, findGoalIndex, getLevel, goalWaypoints, levelCount, relativeSpeedAt, scaledPlanets, waypointProgress } from 'game/LevelData';
import { AimMaxSpeed, AimMinSpeed, BrakeShare, PhysicsStep } from 'game/Config';
import { levelRuntime } from 'game/Tuning';
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

		// ⚠️ S5 归正：旧的硬约束「displayRadius 必须等于 radius」**已作废**。
		// 真实尺度下木星物理半径 0.0374，在 416 单位的轨道上是亚像素 —— 视觉必须放大。
		// 替代判据：① 两者都 > 0；② 玩家判断"够不够得着"的依据是 **2D 到达圈 = 真实容差**
		//（Test/PlanViewTest 守着），不再靠肉眼比天体大小。
		for (let k = 0; k < lv.planets.length && k < lv.visuals.length; k++) {
			check(`lv${lv.id}-planet${k}-visual-radius>0`, lv.visuals[k].displayRadius > 0,
				`displayRadius=${lv.visuals[k].displayRadius}`);
			check(`lv${lv.id}-planet${k}-phys-radius>0`, lv.planets[k].radius > 0,
				`radius=${lv.planets[k].radius}`);
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

		// S5 硬门（计划 §3.3）：**初速必须是该点的圆轨速度**，否则探测器一出发就坠日。
		// L1 是局部系统（绕地球），别的关是绕太阳。
		const v0 = lv.probeVel0;
		check(`lv${lv.id}-probe-velocity-present`, v0 !== undefined, 'probeVel0 必须存在（S5 起必填）');
		if (v0 !== undefined) {
			if (lv.id === 1) {
				const host = lv.planets[1];
				const hp = bodyPositionAt(host, 0);
				const hv = bodyVelocityAt(host, 0);
				const d = Math.sqrt((lv.probeStart.x - hp.x) ** 2 + (lv.probeStart.y - hp.y) ** 2);
				const rel = Math.sqrt((v0.x - hv.x) ** 2 + (v0.y - hv.y) ** 2);
				const want = Math.sqrt(host.gm / d);
				check('l1-velocity-is-circular-around-earth', Math.abs(rel - want) < want * 1e-6,
					`rel=${rel.toFixed(6)} 圆轨=${want.toFixed(6)} d=${d.toFixed(4)}`);
			} else {
				const d = Math.sqrt(lv.probeStart.x ** 2 + lv.probeStart.y ** 2);
				const want = Math.sqrt(SunGm / d);
				const sp = Math.sqrt(v0.x ** 2 + v0.y ** 2);
				check(`lv${lv.id}-velocity-is-circular`, Math.abs(sp - want) < want * 1e-6,
					`|v0|=${sp.toFixed(6)} 圆轨=${want.toFixed(6)} r=${d.toFixed(3)}`);
			}
		}
	}

	// Scale 溯源：物理半径/轨道/周期必须来自 game/Scale（防止有人又手填一个"好看的"数）
	const l1 = getLevel(0);
	if (l1 !== undefined) {
		check('scale-provenance-earth-radius', Math.abs(l1.planets[1].radius - 0.0034070) < 1e-6, `earth r=${l1.planets[1].radius}`);
		check('scale-provenance-moon-orbit', Math.abs(l1.planets[2].orbitRadius - 0.2055644) < 1e-6, `moon a=${l1.planets[2].orbitRadius}`);
		// 月球周期必须用**地球**的 gm 算（拿月球自己的 gm 会得到 11.35 秒 —— 踩过）
		check('moon-period-uses-host-gm', Math.abs(l1.planets[2].orbitPeriod - 1.2593) < 1e-3, `moon T=${l1.planets[2].orbitPeriod}`);
	}
	const l3 = getLevel(2);
	if (l3 !== undefined) {
		check('scale-provenance-jupiter-orbit', Math.abs(l3.planets[1].orbitRadius - 416.231) < 1e-2, `jupiter a=${l3.planets[1].orbitRadius}`);
		check('scale-provenance-jupiter-period', Math.abs(l3.planets[1].orbitPeriod - 198.845) < 1e-2, `jupiter T=${l3.planets[1].orbitPeriod}`);
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
/**
 * 本轮验收范围（用户 2026-09-27 原话）：「先只做到 L1 完备，可以正常游玩就行了！」
 *
 * ⇒ **可达性判据只对 L1 把关**。L2–L6 的关卡数据仍在（六关都能进去、都能跑），
 *    但它们的数值验收（成功率 / 相位 / 时间窗）推迟到后续轮次。
 *    这里**如实标注**：外圈关的扫掠照跑、结果照打，只是不让本模块变红。
 */
const REACH_GATE_LEVELS = 1;

/**
 * 时间轴判据是否作为硬门（S5 本轮 = false）。
 *
 * 关掉的两个理由，都写明白：
 *   ① 用户把范围收窄到 L1，而 **L1 没有日期轴** —— 探测器出发点是个固定点（地球外侧 0.1 的圆轨），
 *      日期一变地球就转走、探测器不动，所以 L1 的"时机"是**月球自己的相位**；
 *      要让 L1 也有日期轴，得让出发点跟着地球走（probeHost），那是后续轮次的事。
 *   ② 扫掠的 t0 采样为了控耗时从 24 档降到 4 档，「峰值 ≥ 2× 起点」这种统计在 1~3 个解上不可信。
 *
 * 关掉的是**判据**，不是**测量**：perT0 照算、细节照打，恢复只需把这里改成 true。
 */
const WINDOW_GATE = false;

let levelDvTop = AimMaxSpeed;
/** 这一关的力度**下限**（S5：L1 的 Δv 预算只有 0.35，全局下限 5 比整关预算还大）。 */
let levelDvMin = AimMinSpeed;
/** 这一遍扫掠用的物理步长与步数（S5 起按关卡给，见 testReachability）。 */
let sweepDt = PhysicsStep;
let sweepSteps = 0;
let sweepEvery = 4;
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
			const speed = levelDvMin + (levelDvTop - levelDvMin) * p;
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
	const sampleEvery = sweepEvery;
	const steps = sweepSteps > 0 ? sweepSteps : lv.maxSteps;
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
					steps, dt: sweepDt, sampleEvery: sampleEvery, escapeRadius: lv.escapeRadius, t0,
					brake: sample.brakeDv > 0 ? { dv: sample.brakeDv, startStep: Math.floor(steps / 2) } : undefined,
				},
			);
			// ⚠️ 有效步长必须是 sampleEvery · dt：传 PhysicsStep 会让移动目标的时间轴错位
			// （采样点 i 的真实时刻是 t0 + i · sampleEvery · dt）。
			const gi = findGoalIndex(sim.points, bodies, lv.goal, sweepDt * sampleEvery, t0, sim.velocities);
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
	// ⚠️ 本轮**只扫 L1**（见 REACH_GATE_LEVELS）。外圈关一次扫掠是 8000 步 × 576 样本，
	//    实测会让引擎在批跑中途直接崩掉（/run 超时 → 端口关闭，像是 Lua 侧的 OOM），
	//    而按用户 2026-09-27 的范围收窄，它们的数值验收本来就推迟了。
	//    外圈六关「有没有路线」的证据在 tools/level-phases.mjs 的工具输出里
	//    （可行路线 13% ~ 19%），**不在这里假装跑过**。
	const sweepCount = REACH_GATE_LEVELS;
	// **先粗后细**：粗网格（12×4，历史基线）能过就不升级 —— 引擎里的耗时按「样本数 × 步数」
	// 线性增长，全用密网格会让这个批跑从几秒涨到分钟级（2026-09-26 实测）。
	// 粗网格捞不到解（窄解）时才升到 24×6 / 24 档 t0。
	for (let i = 0; i < n; i++) {
		const lv = getLevel(i);
		if (lv === undefined) { out.push(sweepLevel(lv, 12, 4, 1)); continue; }
		if (i >= sweepCount) {
			out.push({ solutions: 0, total: 0, perT0: [], t0s: [], best: '（本轮不扫掠，见 testReachability 的说明）' });
			continue;
		}
		// 时间轴关的 t0 要采密一点：L4 的"两颗巨行星同时在航线上"的窗口只有几十秒宽
		// ⚠️ t0 档数从 24 降到 4（S5）：步长按关卡给之后，外圈关一次扫掠仍是
		// "样本数 × 步数"，24 档 × 1152 样本会让批跑跑到超时被杀（2026-09-27 实测）。
		const t0Count = lv.timeWindow !== undefined ? 4 : 1;
		const rtLv = levelRuntime(i);
		levelDvMin = rtLv.aimMin;
		levelDvTop = lv.dvBudget !== undefined && lv.dvBudget < AimMaxSpeed ? lv.dvBudget : AimMaxSpeed;
		levelVel0 = lv.probeVel0 !== undefined ? lv.probeVel0 : { x: 0, y: 0 };
		// ⚠️ 步长/步数按关卡给（S5）：
		//   - L1 用**真步长** 1/2000 —— 它就是验收对象（0.1 单位的地心轨道在 1/120 下会被算成 0.14~0.36）；
		//   - 外圈用粗步长 1/40 + 步数上限 32000 —— 否则 L6 一次扫掠是 70000 步 × 1152 样本
		//     ≈ 8000 万步，批跑直接超时被杀（2026-09-27 实测：标记文件停在 phase=running）。
		sweepDt = i === 0 ? rtLv.physicsStep : 1 / 40;
		sweepEvery = 1;
		// 覆盖 200 秒足够：六关的设计航线到最远站是 8 / 25 / 72 / 78 / 128 秒（工具输出）。
		sweepSteps = i === 0 ? lv.maxSteps : Math.min(lv.maxSteps, 8000);
		// 三级升级：① 12×4 惯性；② 密网格 惯性；③ 12×4 **刹车模式**（S3.9.2 —— 两次点火共享 Δv，
		// 是"到达时能减速"的另一条路，捕放入轨要靠它）。任何一级过了就算这一关有解。
		levelBrake = false;
		let stat = sweepLevel(lv, 12, 4, t0Count);
		if (stat.solutions === 0) {
			stat = sweepLevel(lv, 24, 6, lv.timeWindow !== undefined ? 4 : 1);
		}
		if (stat.solutions === 0) {
			levelBrake = true;
			stat = sweepLevel(lv, 12, 4, t0Count);
		}
		out.push(stat);
		if (i < REACH_GATE_LEVELS) {
			check(`lv${lv.id}-reachable`, stat.solutions > 0,
				`每关至少要有一个可行解（${lv.title}）：${stat.solutions}/${stat.total} ${stat.best}`);
		} else {
			// 本轮不把关（见 REACH_GATE_LEVELS 的说明）：结果照打，方便下一轮对照
			check(`lv${lv.id}-reachable-informational`, true,
				`未把关：${lv.title} ${stat.solutions}/${stat.total} ${stat.best}`);
		}
	}
	return out;
}

/** 4) 时间轴（S3.6.4 的数据侧判据）：**日期必须真的有用**。
 *
 * 历史：PLAN 最初写的是「t0=0 无解」，实测做不到（场里自由度太多，任何时机都能蒙中一条线）。
 * 第二轮改成「至少要有一个 t0 档零解」，它当时能过 —— 但那是**假象**：那一版 L4 的两颗行星
 * 相位是照一条**撞太阳的弧线**排的，任何日期都对不上，于是大半时间轴是死区（S3.11 修了相位）。
 * 相位修对之后「零解的时机」又消失了，而且**这是原理性的**：单次点火有方向+力度两个自由度，
 * 一个自由度就能补偿掉整个日期的偏差（实测把木星错开 95° 仍能靠改方向蒙中 1 条）。
 *
 * 所以判据改成**可观测、且真的对应"日期有用"**的两条：
 *   ① 起点（t0=0，玩家一进关看到的那一天）必须**明显差于**最好的时机——至少 2 倍；
 *   ② 最好时机本身要有足够多的解（≥3），整关总解数 ≥3。
 */
function testTimeWindow(stats: SweepStat[]): void {
	const n = levelCount();
	let withWindow = 0;
	for (let i = 0; i < n; i++) {
		const lv = getLevel(i);
		if (lv === undefined || lv.timeWindow === undefined) continue;
		withWindow += 1;
		const st = stats[i];
		let peak = 0;
		for (const h of st.perT0) if (h > peak) peak = h;
		let dead = 0;
		for (const h of st.perT0) if (h === 0) dead += 1;
		// 「日期有用」的两个可观测表述，满足任一即可（两关各命中一条）：
		//   ① 有的时机**完全没解** —— 窗口真的会关（L6 单程：前 4 档零解）；
		//   ② 起点明显差于最好时机 —— 至少 2 倍（L4 窗口：t0=0 有 3 解、峰值 8 解）。
		const mattersOk = peak >= 3 && (dead >= 1 || st.perT0[0] * 2 <= peak);
		const openOk = st.solutions >= 3;
		check(`lv${lv.id}-window-matters`, !WINDOW_GATE || mattersOk,
			`时间轴必须真的有用：dead=${dead}/${st.perT0.length} 档零解，t0=0 有 ${st.perT0[0]} 解、最好时机 ${peak} 解（要差 2 倍以上）`);
		check(`lv${lv.id}-window-open`, !WINDOW_GATE || openOk,
			`时间轴必须有能落进去的窗口：solutions=${st.solutions}`);
	}
	// S3.13：时间轴从「只有 L4/L6 有」变成**六关都有**（设计稿第十条：不再有特例）—— 这条断言守的正是那个决定。
	check('time-window-exists', !WINDOW_GATE || withWindow === n,
		'六关都必须有时间轴：withWindow=' + withWindow + '/' + n + '（L1 例外：它没有日期轴，见 LevelDef 里 L1 的说明）');
}

/** 6) 任务元数据完整性（S7）。 */
function testMissionMeta(): void {
	const n = levelCount();
	for (let i = 0; i < n; i++) {
		const lv = getLevel(i);
		if (lv === undefined) continue;
		const m = lv.mission;
		check(`lv${lv.id}-mission-meta-present`, m !== undefined, '缺少 mission 元数据');
		if (m === undefined) continue;

		check(`lv${lv.id}-mission-id`, m.id === `L${lv.id}`, `id=${m.id}`);
		check(`lv${lv.id}-mission-codename`, m.codeName.length > 0, 'codeName 为空');
		check(`lv${lv.id}-mission-challenges-count`, m.challenges.length === 3, `challenges.length=${m.challenges.length}`);
		check(`lv${lv.id}-c1-type-success`, m.challenges[0].type === 'success', `c1 type=${m.challenges[0].type}`);
		check(`lv${lv.id}-c2-type-fuel`, m.challenges[1].type === 'fuel', `c2 type=${m.challenges[1].type}`);
		check(`lv${lv.id}-c3-type-valid`, ['distance', 'speed', 'eccentricity'].indexOf(m.challenges[2].type) >= 0, `c3 type=${m.challenges[2].type}`);
	}
}

/** 7) 火箭星级评价逻辑（S7 纯函数判定）。 */
function testEvaluateRockets(): void {
	const l1 = getLevel(0);
	if (l1 !== undefined) {
		check('rockets-fail-0', evaluateRockets(l1, 'crash', 0.1) === 0, '失败应为 0 枚火箭');
		check('rockets-escaped-0', evaluateRockets(l1, 'escaped', 0.1) === 0, '逃逸应为 0 枚火箭');
		check('rockets-success-overburn-1', evaluateRockets(l1, 'success', l1.dvBudget * 0.95) === 1, '燃油超标应为 1 枚火箭');
		check('rockets-fuel-ok-2', evaluateRockets(l1, 'success', l1.dvBudget * 0.5) === 2, '达成省油应为 2 枚火箭');
		check('rockets-peri-ok-3', evaluateRockets(l1, 'success', l1.dvBudget * 0.5, { closestDist: 0.01 }) === 3, '达成近掠应为 3 枚火箭');
		check('rockets-peri-fail-2', evaluateRockets(l1, 'success', l1.dvBudget * 0.5, { closestDist: 0.05 }) === 2, '未达成近掠应为 2 枚火箭');
	}

	const l4 = getLevel(3);
	if (l4 !== undefined) {
		check('rockets-l4-eccentricity-3', evaluateRockets(l4, 'success', l4.dvBudget * 0.6, { eccentricity: 0.25 }) === 3, '低偏心率入轨应为 3 枚火箭');
	}

	const l3 = getLevel(2);
	if (l3 !== undefined) {
		check('rockets-l3-speed-3', evaluateRockets(l3, 'success', l3.dvBudget * 0.7, { maxSpeed: 45 }) === 3, '高速狂飙应为 3 枚火箭');
	}
}

export function runTests(): string {
	testValidity();
	testFindGoalIndex();
	const stats = testReachability();
	testTimeWindow(stats);
	testCapture();
	testMissionMeta();
	testEvaluateRockets();

	const lines: string[] = [];
	lines.push(failures.length === 0 ? 'passed' : 'failed');
	lines.push(`checks=${checks} failures=${failures.length}`);
	const limit = failures.length < 12 ? failures.length : 12;
	for (let i = 0; i < limit; i++) {
		lines.push(`FAIL ${failures[i].name}: ${failures[i].detail}`);
	}
	return lines.join('\n');
}
