/**
 * S1.1 单测：验证 game/Gravity.ts 的确定性（验收硬指标）。
 *
 * 输出格式：首行为 `passed` 或 `failed`，后续为明细。
 * 加载方式（纯逻辑，无需运行场景）：
 *   const m = requireProjectModule("Test.GravityTest")
 *   print(m.runTests())
 */
import { Body, ProbeState, SimOptions, accelerationAt, applyScales, bodyPositionAt, distance, length, orbitalSpeed, simulate } from 'game/Gravity';

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

function fmtP2(p: { x: number; y: number }): string {
	return `(${p.x.toFixed(4)}, ${p.y.toFixed(4)})`;
}

/** 测试用行星：静止在原点，强度 100、半径 0.5。 */
function staticBody(): Body {
	return {
		gm: 100,
		radius: 0.5,
		orbitCenter: { x: 0, y: 0 },
		orbitRadius: 0,
		orbitPeriod: 0,
		phase0: 0,
		orbitDirection: 1,
	};
}

/** 测试用行星：绕原点公转。 */
function orbitingBody(): Body {
	return {
		gm: 0,
		radius: 0.1,
		orbitCenter: { x: 0, y: 0 },
		orbitRadius: 10,
		orbitPeriod: 8,
		phase0: 0,
		orbitDirection: 1,
	};
}

/** 1) 确定性：同一输入两次推演必须逐点完全相同。 */
function testDeterminism(): void {
	const bodies = [orbitingBody(), staticBody()];
	const init: ProbeState = { pos: { x: -20, y: 3 }, vel: { x: 5, y: 1.5 } };
	const opts: SimOptions = { steps: 500, dt: 1 / 120, sampleEvery: 5, escapeRadius: 500 };

	const a = simulate(init, bodies, opts);
	const b = simulate(init, bodies, opts);

	let same = a.points.length === b.points.length && a.outcome === b.outcome && a.stepsRun === b.stepsRun;
	if (same) {
		for (let i = 0; i < a.points.length; i++) {
			if (a.points[i].x !== b.points[i].x || a.points[i].y !== b.points[i].y) {
				same = false;
				break;
			}
		}
	}
	check('determinism', same, `twice-run mismatch: points ${a.points.length} vs ${b.points.length}, outcome ${a.outcome} vs ${b.outcome}`);

	// 不同输入必须给出不同结果（防止“实现返回常量”这类假通过）
	const c = simulate({ pos: { x: -20, y: 3 }, vel: { x: 6, y: 1.5 } }, bodies, opts);
	let differs = c.points.length !== a.points.length;
	if (!differs) {
		for (let i = 0; i < a.points.length && i < c.points.length; i++) {
			if (a.points[i].x !== c.points[i].x || a.points[i].y !== c.points[i].y) { differs = true; break; }
		}
	}
	check('determinism-input-matters', differs, 'changing velocity produced identical trajectory');
}

/** 2) 无引力 = 匀速直线。 */
function testStraightLine(): void {
	const init: ProbeState = { pos: { x: -10, y: 0 }, vel: { x: 4, y: 0 } };
	const opts: SimOptions = { steps: 240, dt: 1 / 120, sampleEvery: 1, escapeRadius: 0 };
	const r = simulate(init, [], opts);

	const expectedX = -10 + 4 * (1 / 120) * 240; // = -2
	const errX = Math.abs(r.state.pos.x - expectedX);
	const errY = Math.abs(r.state.pos.y - 0);
	check('straight-line', errX < 1e-9 && errY < 1e-9, `pos=${fmtP2(r.state.pos)} expected x=${expectedX.toFixed(6)}`);
	check('straight-line-outcome', r.outcome === 'running', `outcome=${r.outcome}`);
	check('straight-line-velocity', Math.abs(r.state.vel.x - 4) < 1e-12 && Math.abs(r.state.vel.y) < 1e-12, `vel=${fmtP2(r.state.vel)}`);
}

/** 3) 圆轨道：用 orbitalSpeed 发射，半径应基本不变。 */
function testCircularOrbit(): void {
	const b = staticBody();
	const R = 20;
	const v = orbitalSpeed(b.gm, R);
	const init: ProbeState = { pos: { x: R, y: 0 }, vel: { x: 0, y: v } };

	// 推进一个完整周期 T = 2πR/v
	const period = 2 * Math.PI * R / v;
	const dt = 1 / 240;
	const steps = Math.floor(period / dt);
	const r = simulate(init, [b], { steps, dt, sampleEvery: 1, escapeRadius: 0 });

	// 半径漂移：半隐式欧拉会略有偏移，容许 3%
	const finalR = length(r.state.pos);
	const drift = Math.abs(finalR - R) / R;
	check('circular-orbit-radius', drift < 0.03, `radius drifted ${(drift * 100).toFixed(2)}% (${R} -> ${finalR.toFixed(3)})`);
	check('circular-orbit-no-crash', r.outcome === 'running', `outcome=${r.outcome}`);
}

/** 4) 撞毁：直接朝行星中心飞。 */
function testCrash(): void {
	const b = staticBody();
	const init: ProbeState = { pos: { x: -10, y: 0 }, vel: { x: 10, y: 0 } };
	const r = simulate(init, [b], { steps: 600, dt: 1 / 120, sampleEvery: 1, escapeRadius: 0 });
	check('crash-detected', r.outcome === 'crashed', `outcome=${r.outcome} stepsRun=${r.stepsRun}`);
	check('crash-index', r.hitIndex === 0, `hitIndex=${r.hitIndex}`);
	const d = distance(r.state.pos, { x: 0, y: 0 });
	check('crash-inside-radius', d < b.radius, `final distance=${d.toFixed(4)} radius=${b.radius}`);
}

/** 5) 逃逸：高速飞出越界半径。 */
function testEscape(): void {
	const b = staticBody();
	const init: ProbeState = { pos: { x: 5, y: 0 }, vel: { x: 40, y: 0 } };
	const r = simulate(init, [b], { steps: 2000, dt: 1 / 120, sampleEvery: 1, escapeRadius: 100 });
	check('escape-detected', r.outcome === 'escaped', `outcome=${r.outcome} stepsRun=${r.stepsRun}`);
}

/** 6) 公转：周期 0 静止；经过一个周期回到起点。 */
function testOrbit(): void {
	const stat = staticBody();
	stat.orbitRadius = 3;
	stat.phase0 = 0.7;
	const p0 = bodyPositionAt(stat, 0);
	const p1 = bodyPositionAt(stat, 123.456);
	check('static-body-fixed', p0.x === p1.x && p0.y === p1.y, `moved: ${fmtP2(p0)} -> ${fmtP2(p1)}`);

	const orb = orbitingBody();
	const q0 = bodyPositionAt(orb, 0);
	const qT = bodyPositionAt(orb, orb.orbitPeriod);
	const err = distance(q0, qT);
	check('orbit-period-returns', err < 1e-9, `after one period: ${fmtP2(q0)} -> ${fmtP2(qT)} err=${err.toFixed(12)}`);

	const qHalf = bodyPositionAt(orb, orb.orbitPeriod / 2);
	const opposite = distance(q0, qHalf);
	check('orbit-halfway-opposite', Math.abs(opposite - 2 * orb.orbitRadius) < 1e-9, `halfway distance=${opposite.toFixed(6)} expected=${(2 * orb.orbitRadius).toFixed(6)}`);

	// 逆时针方向校验：t 很小时相位应沿 +y 增大
	const orbCCW = orbitingBody();
	const small = bodyPositionAt(orbCCW, orbCCW.orbitPeriod * 0.02);
	check('orbit-direction-ccw', small.y > 0, `t=2% period 时 y=${small.y.toFixed(4)}（应为正 = 逆时针）`);
}

/** 7) 平方反比：距离翻倍，加速度降为 1/4。 */
function testInverseSquare(): void {
	const b = staticBody();
	const a1 = length(accelerationAt([b], { x: 1, y: 0 }, 0));
	const a2 = length(accelerationAt([b], { x: 2, y: 0 }, 0));
	const ratio = a1 / a2;
	check('inverse-square', Math.abs(ratio - 4) < 1e-9, `a(1)/a(2)=${ratio.toFixed(6)} expected 4`);
}

/** 8) 倍率：applyScales 不修改入参，且语义正确。 */
function testScales(): void {
	const bodies = [staticBody(), orbitingBody()];
	const gm0 = bodies[0].gm;
	const period0 = bodies[1].orbitPeriod;

	const scaled = applyScales(bodies, 2, 4);

	check('scales-no-mutation', bodies[0].gm === gm0 && bodies[1].orbitPeriod === period0, 'applyScales 修改了入参');
	check('scales-gravity', scaled[0].gm === gm0 * 2, `gm=${scaled[0].gm} expected=${gm0 * 2}`);
	check('scales-orbit', scaled[1].orbitPeriod === period0 / 4, `period=${scaled[1].orbitPeriod} expected=${period0 / 4}`);
	check('scales-static-stays-static', scaled[0].orbitPeriod === 0, `静止行星的周期被改成 ${scaled[0].orbitPeriod}`);
}

/** 9) 采样：点数为步数/采样间隔 + 1（含起点），且不超限。 */
function testSampling(): void {
	const init: ProbeState = { pos: { x: -10, y: 0 }, vel: { x: 1, y: 0 } };
	const r = simulate(init, [], { steps: 100, dt: 1 / 120, sampleEvery: 10, escapeRadius: 0 });
	// 起点 + 第 0,10,...,90 步 = 1 + 10
	check('sampling-count', r.points.length === 11, `points=${r.points.length} expected=11`);
	check('sampling-steps', r.stepsRun === 100, `stepsRun=${r.stepsRun}`);

	const r2 = simulate(init, [], { steps: 0, dt: 1 / 120, sampleEvery: 1, escapeRadius: 0 });
	check('sampling-zero-steps', r2.points.length === 1 && r2.stepsRun === 0, `points=${r2.points.length} stepsRun=${r2.stepsRun}`);
}

/** 10) 穿过行星后方：验证引力确实改变了方向（为 S1.3 弹弓铺路）。 */
function testGravityBends(): void {
	const b = staticBody();
	// 从旁边掠过（miss distance 足够大，不撞毁）
	const init: ProbeState = { pos: { x: -20, y: 4 }, vel: { x: 10, y: 0 } };
	const r = simulate(init, [b], { steps: 600, dt: 1 / 120, sampleEvery: 1, escapeRadius: 0 });

	const straightY = 4;
	const bent = Math.abs(r.state.pos.y - straightY);
	check('gravity-bends-path', r.outcome === 'running' && bent > 0.05, `outcome=${r.outcome} y=${r.state.pos.y.toFixed(4)}（直线应为 4）`);
	check('gravity-pulls-inward', r.state.pos.y < straightY, `y=${r.state.pos.y.toFixed(4)} 应小于 ${straightY}（被吸向原点）`);
}

/** 入口：运行全部测试并返回报告。首行为 passed / failed。 */
export function runTests(): string {
	testDeterminism();
	testStraightLine();
	testCircularOrbit();
	testCrash();
	testEscape();
	testOrbit();
	testInverseSquare();
	testScales();
	testSampling();
	testGravityBends();

	const lines: string[] = [];
	if (failures.length === 0) {
		lines.push('passed');
	} else {
		lines.push('failed');
	}
	lines.push(`checks=${checks} failures=${failures.length}`);
	const limit = failures.length < 12 ? failures.length : 12;
	for (let i = 0; i < limit; i++) {
		lines.push(`FAIL ${failures[i].name}: ${failures[i].detail}`);
	}
	if (failures.length > limit) lines.push(`... and ${failures.length - limit} more failures`);
	return lines.join('\n');
}
