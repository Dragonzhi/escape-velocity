/**
 * S3.16 单测：沿轨道流动的光点（game/OrbitFlow.ts）—— **纯逻辑**，零引擎依赖。
 *
 * 守三条设计硬要求（缺一不可；用户会话 46 的唯一一条「奇怪」就是轨道圈看不出方向与快慢）：
 *   ① **方向 = Body.orbitDirection**（字段，不写死顺行；逆行天体的光点必须反向流）；
 *   ② **快慢 ∝ 角速度 ω = 2π/orbitPeriod**（开普勒：内圈快、外圈慢）；
 *   ③ **位置只由 t 解析求出**（与 Gravity.bodyPositionAt 同一个角公式）⇒ 拨发射日期时
 *      行星与光点一起动，且不存在第二时间源。
 * 外加两条几何不变量：第 0 个光点压在行星身上（与物理位置逐点一致）、所有光点落在轨道上。
 *
 * 输出格式：首行为 passed 或 failed（与其他测试模块一致）。
 */
import { Body, bodyPositionAt } from 'game/Gravity';
import {
	FlowDotsPerOrbit, flowDotAngle, flowDotPosition, orbitAngleAt, orbitAngularRate, orbitCenterAt,
} from 'game/OrbitFlow';
import { getLevel, scaledPlanets } from 'game/LevelData';
import { SunGm } from 'game/Scale';

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

/** 度 → 弧度。 */
function deg(d: number): number {
	return (d * Math.PI) / 180;
}

/** 造一颗绕原点公转的天体（dir = +1 顺行 / -1 逆行）。 */
function orbiter(orbitRadius: number, period: number, dir: 1 | -1, phaseDeg: number): Body {
	return {
		gm: 0, radius: 1,
		orbitCenter: { x: 0, y: 0 },
		orbitRadius, orbitPeriod: period,
		phase0: deg(phaseDeg), orbitDirection: dir,
	};
}

/** 造一颗绕**会动的宿主**的卫星（圆心 = 宿主此刻的位置）。 */
function satellite(host: Body, orbitRadius: number, period: number): Body {
	return {
		gm: 0, radius: 1,
		orbitCenter: { x: 0, y: 0 },
		orbitRadius, orbitPeriod: period,
		phase0: 0, orbitDirection: 1, host,
	};
}

/** 1) 第 0 个光点 == 行星位置（与物理几何不可能分家）。 */
function testDotZeroOnPlanet(): void {
	const b = orbiter(80, 700, 1, 37);
	const host = orbiter(80, 700, 1, 10);
	const moon = satellite(host, 15, 120);
	for (const t of [0, 1, 7.5, 123.25]) {
		const dot = flowDotPosition(b, t, 0, FlowDotsPerOrbit);
		const planet = bodyPositionAt(b, t);
		check('dot0-equals-planet',
			Math.abs(dot.x - planet.x) < 1e-9 && Math.abs(dot.y - planet.y) < 1e-9,
			't=' + t.toFixed(2) + ' dot=(' + dot.x.toFixed(4) + ',' + dot.y.toFixed(4) + ') planet=(' + planet.x.toFixed(4) + ',' + planet.y.toFixed(4) + ')');
		// 卫星：光点圆心是会动的宿主（月球绕地球、地球绕日）
		const mdot = flowDotPosition(moon, t, 0, FlowDotsPerOrbit);
		const mplanet = bodyPositionAt(moon, t);
		check('dot0-equals-planet-host-chain',
			Math.abs(mdot.x - mplanet.x) < 1e-9 && Math.abs(mdot.y - mplanet.y) < 1e-9,
			't=' + t.toFixed(2) + ' dot=(' + mdot.x.toFixed(4) + ',' + mdot.y.toFixed(4) + ') planet=(' + mplanet.x.toFixed(4) + ',' + mplanet.y.toFixed(4) + ')');
	}
}

/** 2) 光点均匀分布、且全部落在轨道上（半径 = orbitRadius，圆心 = 宿主/轨道圆心）。 */
function testDotsOnOrbit(): void {
	const b = orbiter(105, 1076, 1, 0);
	const host = orbiter(80, 700, 1, 200);
	const moon = satellite(host, 15, 120);
	const t = 42;
	const c = orbitCenterAt(b, t);
	let okSpacing = true;
	let okRadius = true;
	let okWrap = true;
	for (let k = 0; k < FlowDotsPerOrbit; k++) {
		const a0 = flowDotAngle(b, t, k, FlowDotsPerOrbit);
		if (k + 1 < FlowDotsPerOrbit) {
			const a1 = flowDotAngle(b, t, k + 1, FlowDotsPerOrbit);
			if (Math.abs((a1 - a0) - (2 * Math.PI) / FlowDotsPerOrbit) > 1e-9) okSpacing = false;
		} else {
			// 第 N 个与第 0 个重合（取模归位）⇒ 链在轨道上闭合
			const wrapped = flowDotAngle(b, t, FlowDotsPerOrbit, FlowDotsPerOrbit);
			if (Math.abs(wrapped - flowDotAngle(b, t, 0, FlowDotsPerOrbit)) > 1e-9) okWrap = false;
		}
		const p = flowDotPosition(b, t, k, FlowDotsPerOrbit);
		const d = Math.sqrt((p.x - c.x) * (p.x - c.x) + (p.y - c.y) * (p.y - c.y));
		if (Math.abs(d - 105) > 1e-9) okRadius = false;
	}
	check('dot-spacing-uniform', okSpacing, 'step=' + ((2 * Math.PI) / FlowDotsPerOrbit).toFixed(4) + ' rad');
	check('dot-chain-closes', okWrap, 'dot N wraps back to dot 0');
	check('dots-on-orbit', okRadius, 'every dot at distance orbitRadius from center');
	// 卫星：圆心跟着宿主走
	const mc = orbitCenterAt(moon, t);
	const hp = bodyPositionAt(host, t);
	check('center-follows-host',
		Math.abs(mc.x - hp.x) < 1e-9 && Math.abs(mc.y - hp.y) < 1e-9,
		'center=(' + mc.x.toFixed(3) + ',' + mc.y.toFixed(3) + ') host=(' + hp.x.toFixed(3) + ',' + hp.y.toFixed(3) + ')');
}

/** 3) 方向 = orbitDirection（顺行逆时针、逆行顺时针；不写死）。 */
function testDirectionFromField(): void {
	const pro = orbiter(55, 400, 1, 0);
	const retro = orbiter(55, 400, -1, 0);
	const dt = 5;
	const dPro = flowDotAngle(pro, dt, 0, FlowDotsPerOrbit) - flowDotAngle(pro, 0, 0, FlowDotsPerOrbit);
	const dRetro = flowDotAngle(retro, dt, 0, FlowDotsPerOrbit) - flowDotAngle(retro, 0, 0, FlowDotsPerOrbit);
	check('direction-prograde', dPro > 0, 'delta=' + dPro.toFixed(4) + ' rad over ' + dt + 's');
	check('direction-retrograde', dRetro < 0, 'delta=' + dRetro.toFixed(4) + ' rad over ' + dt + 's');
	// 整条链（任意 k）方向一致
	let allPro = true;
	let allRetro = true;
	for (let k = 0; k < FlowDotsPerOrbit; k++) {
		if (flowDotAngle(pro, dt, k, FlowDotsPerOrbit) - flowDotAngle(pro, 0, k, FlowDotsPerOrbit) <= 0) allPro = false;
		if (flowDotAngle(retro, dt, k, FlowDotsPerOrbit) - flowDotAngle(retro, 0, k, FlowDotsPerOrbit) >= 0) allRetro = false;
	}
	check('direction-whole-chain', allPro && allRetro, 'every dot of the chain flows the same way');
}

/** 4) 快慢 ∝ 角速度：delta = omega*dt（精确等式），且周期 4 倍的天体慢 4 倍。 */
function testSpeedProportionalToOmega(): void {
	const fast = orbiter(55, 400, 1, 0);   // omega = 2pi/400
	const slow = orbiter(195, 1600, 1, 0); // omega = 2pi/1600（周期的 4 倍）
	const dt = 3.7;
	const dFast = flowDotAngle(fast, dt, 0, FlowDotsPerOrbit) - flowDotAngle(fast, 0, 0, FlowDotsPerOrbit);
	const dSlow = flowDotAngle(slow, dt, 0, FlowDotsPerOrbit) - flowDotAngle(slow, 0, 0, FlowDotsPerOrbit);
	check('speed-equals-omega-times-dt',
		Math.abs(dFast - orbitAngularRate(fast) * dt) < 1e-9 && Math.abs(dSlow - orbitAngularRate(slow) * dt) < 1e-9,
		'fast=' + dFast.toFixed(5) + ' slow=' + dSlow.toFixed(5) + ' rad');
	check('speed-quarter-period-quarter-angle',
		Math.abs(dFast / dSlow - 4) < 1e-9,
		'ratio=' + (dFast / dSlow).toFixed(4) + ' expect=4（T 4 倍 => 角速度 1/4）');
	// 线速度也内快外慢：v = omega*r
	const vFast = Math.abs(orbitAngularRate(fast)) * 55;
	const vSlow = Math.abs(orbitAngularRate(slow)) * 195;
	check('linear-speed-inner-faster', vFast > vSlow, 'v(55)=' + vFast.toFixed(4) + ' v(195)=' + vSlow.toFixed(4));
}

/** 5) 静止天体（太阳 / orbitPeriod = 0）：没有可流动的轨道，角速度 0、光点不动。 */
function testStaticBody(): void {
	const sun = orbiter(28, 0, 1, 0);
	check('static-zero-rate', orbitAngularRate(sun) === 0, 'orbitPeriod=0 => omega=0');
	const a0 = flowDotAngle(sun, 0, 3, FlowDotsPerOrbit);
	const a1 = flowDotAngle(sun, 999, 3, FlowDotsPerOrbit);
	check('static-dots-frozen', a0 === a1, 'angle stays ' + a0.toFixed(4));
}

/** 6) 位置是 t 的**纯函数**（同一个 t 两次调用逐位一致）；拨日期光点必须动。 */
function testPureFunctionOfTime(): void {
	const b = orbiter(135, 1569, 1, 88);
	const p1 = flowDotPosition(b, 12.5, 2, FlowDotsPerOrbit);
	const p2 = flowDotPosition(b, 12.5, 2, FlowDotsPerOrbit);
	check('pure-function-of-t', p1.x === p2.x && p1.y === p2.y, '(' + p1.x.toFixed(6) + ',' + p1.y.toFixed(6) + ')');
	const moved = flowDotPosition(b, 12.5 + 30, 2, FlowDotsPerOrbit);
	const dist = Math.sqrt((moved.x - p1.x) * (moved.x - p1.x) + (moved.y - p1.y) * (moved.y - p1.y));
	check('dots-move-with-date', dist > 1, '30s 后同一点移动了 ' + dist.toFixed(2) + ' 单位');
}

/** 7) 真实关卡数据（唯一事实来源）：六关都有可流动的轨道，|omega| 随半径严格递减（开普勒）。 */
function testRealLevels(): void {
	let allHaveOrbits = true;
	let keplerOk = true;
	let orderOk = true;
	const detail: string[] = [];
	for (let li = 0; li < 6; li++) {
		const lv = getLevel(li);
		if (lv === undefined) {
			allHaveOrbits = false;
			continue;
		}
		const bodies = scaledPlanets(lv);
		const movers: Body[] = [];
		for (const b of bodies) {
			if (b.orbitRadius > 0 && b.orbitPeriod > 0) movers.push(b);
		}
		// S5：从 2 降到 1 —— L2/L3 只有一颗目标行星（旧的"家园地球"布景已移除，
		// 理由见 LevelData 文件头第 4 条）。L1 仍有 2 个（地球 + 月球）。
		if (movers.length < 1) allHaveOrbits = false;
		// S5 归正：不变量从 **omega·r^1.5 = 2π·KeplerK**（那条手设公式）换成**真开普勒第三定律**
		//    omega² · r³ = μ_host
		// 也就是"每条绕日轨道的这个积必须等于**同一个**太阳 gm"。
		// ⚠️ 卫星（有 host 的）用宿主自己的 gm —— L1 月球绕地球，μ = 地球 gm，不是太阳 gm。
		//    它算出来仍是同一个常数（每颗行星的 gm 是固定的），所以照样能当不变量用。
		for (const b of movers) {
			const mu = b.host !== undefined ? b.host.gm : SunGm;
			const om = Math.abs(orbitAngularRate(b));
			const kk = om * om * b.orbitRadius * b.orbitRadius * b.orbitRadius;
			if (Math.abs(kk - mu) > Math.abs(mu) * 1e-9) keplerOk = false;
		}
		// 按半径排序后 |omega| 必须严格递减（内圈快）
		const sorted = movers.slice().sort((a, b2) => a.orbitRadius - b2.orbitRadius);
		for (let i = 1; i < sorted.length; i++) {
			if (!(Math.abs(orbitAngularRate(sorted[i])) < Math.abs(orbitAngularRate(sorted[i - 1])))) orderOk = false;
		}
		detail.push('L' + lv.id + ':' + movers.length);
	}
	check('every-level-has-flow-orbits', allHaveOrbits, 'movers per level = ' + detail.join(' '));
	check('kepler-third-law', keplerOk, 'omega^2 * r^3 = mu_host for every orbit（真开普勒，S5 归正）');
	check('inner-orbit-faster', orderOk, '|omega| strictly decreases with orbit radius');
}

export function runTests(): string {
	testDotZeroOnPlanet();
	testDotsOnOrbit();
	testDirectionFromField();
	testSpeedProportionalToOmega();
	testStaticBody();
	testPureFunctionOfTime();
	testRealLevels();

	const lines: string[] = [];
	lines.push(failures.length === 0 ? 'passed' : 'failed');
	lines.push('checks=' + checks + ' failures=' + failures.length);
	const limit = failures.length < 12 ? failures.length : 12;
	for (let i = 0; i < limit; i++) {
		lines.push('FAIL ' + failures[i].name + ': ' + failures[i].detail);
	}
	return lines.join('\n');
}
