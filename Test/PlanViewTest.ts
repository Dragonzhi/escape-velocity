/**
 * S3.15 单测：2D 规划视图的**纯逻辑部分**（映射 / 视野半径）。
 *
 * 为什么只测纯函数：绘制本身（DrawNode）没有可断言的接口，它的证据是**截图**
 * （`.agent/test-results/level-1.png`，见 PROGRESS 会话 47）。但"平面 → 屏幕"这套换算
 * 一旦错了，屏幕上的图会整体偏/整体反向 —— 那是可以在引擎里逐条断言的，而且
 * 与 3D 引擎状态无关（纯算术）。
 *
 * 输出格式：首行为 `passed` 或 `failed`（与其他测试模块一致）。
 */
import { Body } from 'game/Gravity';
import { getLevel, scaledPlanets } from 'game/LevelData';
import { arrivalRingRadius, computePlanMapping, planeToScreen, planFitRadius, screenToPlane } from 'game/PlanView';

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

/** 造一颗绕原点公转的行星。 */
function orbiter(radius: number, orbitRadius: number): Body {
	return {
		gm: 0, radius,
		orbitCenter: { x: 0, y: 0 }, orbitRadius,
		orbitPeriod: orbitRadius > 0 ? 1 : 0, phase0: 0, orbitDirection: 1,
	};
}

/** 造一颗绕**别的天体**转的卫星（月球：圆心跟着地球走）。 */
function satellite(radius: number, host: Body, orbitRadius: number): Body {
	return {
		gm: 0, radius,
		orbitCenter: { x: 0, y: 0 }, orbitRadius,
		orbitPeriod: 10, phase0: 0, orbitDirection: 1, host,
	};
}

/** 1) 映射：等比、留白、退化半径兜底。 */
function testMapping(): void {
	const W = 601;   // 真机竖屏实测（Test/SizeProbe.lua）
	const H = 1066;
	const R = 265;   // L6 的视野半径（海王星 195 + 容差 70）
	const m = computePlanMapping(W, H, R, 0.12);

	// 竖屏是**宽度**受限：601×0.76 / 530 = 0.8619；高度方向还富余
	const expect = (W * 0.76) / (2 * R);
	check('map-width-limited', Math.abs(m.scale - expect) < 1e-9, `scale=${m.scale.toFixed(4)} expect=${expect.toFixed(4)}`);
	check('map-fits-height', R * m.scale <= H * 0.4 + 1e-6, `R*scale=${(R * m.scale).toFixed(1)} halfH=${(H * 0.4).toFixed(1)}`);

	// 最外圈必须落在留白之内（12% ⇒ 可用区间是 [0.12W, 0.88W]）
	const right = planeToScreen({ x: R, y: 0 }, m);
	const left = planeToScreen({ x: -R, y: 0 }, m);
	check('map-margin-respected',
		right.x <= W * 0.88 + 1e-6 && left.x >= W * 0.12 - 1e-6,
		`x=[${left.x.toFixed(1)},${right.x.toFixed(1)}] limit=[${(W * 0.12).toFixed(1)},${(W * 0.88).toFixed(1)}]`);

	// 横屏（2024×1230）时改成高度受限：100 单位 → 1230×0.76/200 = 4.674
	const mLand = computePlanMapping(2024, 1230, 100, 0.12);
	check('map-height-limited', Math.abs(mLand.scale - (1230 * 0.76) / 200) < 1e-9, `scale=${mLand.scale.toFixed(4)}`);

	// 等比 = 两个方向同一个 scale（圆在屏幕上还是圆）
	const cx = m.originX;
	const cy = m.originY;
	const px = planeToScreen({ x: 40, y: 0 }, m);
	const py = planeToScreen({ x: 0, y: 40 }, m);
	const dxx = px.x - cx;
	const dxy = px.y - cy;
	const dyx = py.x - cx;
	const dyy = py.y - cy;
	const rx = Math.sqrt(dxx * dxx + dxy * dxy);
	const ry = Math.sqrt(dyx * dyx + dyy * dyy);
	check('map-no-distortion', Math.abs(rx - ry) < 1e-9, `rx=${rx.toFixed(4)} ry=${ry.toFixed(4)}`);

	// 退化输入：半径 0 / 负数 都不能产生 Infinity 或 0（否则整张图消失或爆成一片）
	const m0 = computePlanMapping(W, H, 0, 0.12);
	check('map-degenerate-radius', m0.scale > 0 && m0.scale < 1e9, `scale=${m0.scale}`);
	// margin 越界要夹住（>0.5 会把可用区域算成负数）
	const mBig = computePlanMapping(W, H, 100, 0.9);
	check('map-margin-clamped', mBig.scale > 0 && mBig.scale < 1e9, `scale=${mBig.scale}`);
}

/** 2) 平面 → 屏幕：中心对原点、**y 反向**、可逆。 */
function testPlaneToScreen(): void {
	const W = 601;
	const H = 1066;
	const m = computePlanMapping(W, H, 100, 0.12);

	const o = planeToScreen({ x: 0, y: 0 }, m);
	check('screen-origin-at-center', o.x === W / 2 && o.y === H / 2, `(${o.x},${o.y}) expect=(${W / 2},${H / 2})`);

	// ⚠️ 核心：平面 +y 画在屏幕**下方**（= 往上拖 = 平面 -y = 画面上方，与 computeAim 的 uy = -dy/len 自洽）
	const up = planeToScreen({ x: 0, y: 50 }, m);
	const down = planeToScreen({ x: 0, y: -50 }, m);
	check('screen-y-flipped', up.y < o.y && down.y > o.y, `plane+50 -> y=${up.y.toFixed(1)} plane-50 -> y=${down.y.toFixed(1)} center=${o.y}`);

	// 往返：屏幕 → 平面 → 屏幕
	const p = { x: 37.5, y: -18.25 };
	const back = screenToPlane(planeToScreen(p, m), m);
	check('screen-roundtrip', Math.abs(back.x - p.x) < 1e-9 && Math.abs(back.y - p.y) < 1e-9, `(${back.x},${back.y}) vs (${p.x},${p.y})`);
}

/** 3) 视野半径：最外圈轨道 + 目标容差（含卫星的宿主链）。 */
function testFitRadius(): void {
	// L1 复刻：太阳(28) + 地球轨道 80 + 月球（绕地球 15，容差 5）
	const sun = orbiter(28, 0);
	const earth = orbiter(1.76, 80);
	const moon = satellite(1.0, earth, 15);
	const fit1 = planFitRadius([sun, earth, moon], { x: 0, y: 90 }, 2, 5);
	const expect1 = 80 + 15 + 5;
	check('fit-l1-moon-host-chain', Math.abs(fit1 - expect1) < 1e-9, `fit=${fit1.toFixed(2)} expect=${expect1}`);

	// L6 复刻：最外圈海王星 195 + 容差 70
	const jup = orbiter(4.63, 105);
	const sat = orbiter(4.30, 135);
	const ura = orbiter(3.04, 165);
	const nep = orbiter(3.00, 195);
	const fit6 = planFitRadius([sun, orbiter(1.76, 80), jup, sat, ura, nep], { x: 0, y: 80 }, 5, 70);
	check('fit-l6-outer-orbit-plus-tolerance', Math.abs(fit6 - 265) < 1e-9, `fit=${fit6.toFixed(2)} expect=265`);

	// 探测器的出发点也要在画面里（否则它跑出视野、玩家找不到自己）
	const fitProbe = planFitRadius([orbiter(1, 10)], { x: 0, y: 300 }, 0, 0);
	check('fit-includes-probe', fitProbe >= 300, `fit=${fitProbe.toFixed(2)}`);

	// 空场也要给一个正数（0 会让 scale 变成 Infinity）
	const fitEmpty = planFitRadius([], { x: 0, y: 0 }, -1, 0);
	check('fit-nonzero', fitEmpty > 0 && fitEmpty < 1e9, `fit=${fitEmpty}`);

	// 真实关卡数据（唯一事实来源）：L1 与 L6
	const l1 = getLevel(0);
	if (l1 === undefined) {
		check('fit-real-l1', false, 'getLevel(0) 返回 undefined');
	} else {
		// S5：L1 以**地球**为中心取景（planCenter = 1）。整个世界只有 0.6 单位宽，
		// 以太阳为中心的话探测器与月球只是屏幕中心的一个点（0.2/80 = 0.25% 视野）。
		const real1 = planFitRadius(scaledPlanets(l1), l1.probeStart, l1.goal.planetIndex, l1.goal.tolerance, l1.planCenter);
		// 应 ≈ 月球轨道 0.2056 + 容差 0.02
		check('fit-real-l1-earth-centred', real1 > 0.2 && real1 < 0.26,
			`L1 fit=${real1.toFixed(4)}（应 ≈ 0.2056 + 0.02 = 0.2256）`);
		// 地心取景**不能**把太阳算进来（太阳离地球 80 单位，一算进来就退回太阳系全景）
		check('fit-real-l1-excludes-sun', real1 < 1, `L1 fit=${real1.toFixed(4)}（若含太阳会是 80+）`);
	}
	const l6 = getLevel(5);
	if (l6 === undefined) {
		check('fit-real-l6', false, 'getLevel(5) 返回 undefined');
	} else {
		// 链式目标：取链上最大容差（L6 最后一站 120）
		const real6 = planFitRadius(scaledPlanets(l6), l6.probeStart, l6.goal.planetIndex, 120);
		check('fit-real-l6', real6 >= 2400 && real6 < 2600, `L6 fit=${real6.toFixed(2)}（应 ≈ 海王星 2405.6 + 120）`);
	}
}

/** S5 §3.8 规则 3：2D 到达圈画的必须是**真实容差**，不是视觉半径。 */
function testArrivalRingIsRealTolerance(): void {
	const l1 = getLevel(0);
	if (l1 === undefined) { check('ring-l1', false, 'getLevel(0) undefined'); return; }
	check('ring-l1-equals-tolerance', Math.abs(arrivalRingRadius(l1.goal) - l1.goal.tolerance) < 1e-12,
		`ring=${arrivalRingRadius(l1.goal)} tol=${l1.goal.tolerance}`);
	// ⚠️ 不能写成"两者必须不相等"：视觉半径与到达容差在数值上可能撞车（S5 的 L1 就撞过），
	//    数值相等会让这条断言误判成"画的是视觉半径"。改成**结构性**判据：把视觉半径改掉之后，
	//    到达圈半径必须**不动** —— 动的就是拿视觉半径当圈了。
	const ringBefore = arrivalRingRadius(l1.goal);
	const savedRadius = l1.visuals[2].displayRadius;
	l1.visuals[2].displayRadius = savedRadius * 3 + 1;
	const ringAfter = arrivalRingRadius(l1.goal);
	l1.visuals[2].displayRadius = savedRadius; // 还原，别污染后面的断言
	check('ring-l1-ignores-visual-radius', ringBefore === ringAfter,
		`ring=${ringBefore} -> ${ringAfter}（视觉半径从 ${savedRadius} 改成 ${savedRadius * 3 + 1} 后到达圈必须不变）`);
	// 链式关卡取链上最大容差（L6：J40/S60/U90/N120 ⇒ 120）
	const l6 = getLevel(5);
	if (l6 !== undefined) {
		check('ring-l6-chain-max', Math.abs(arrivalRingRadius(l6.goal) - 120) < 1e-9,
			`ring=${arrivalRingRadius(l6.goal)}（链上最大容差）`);
	}
}

export function runTests(): string {
	testArrivalRingIsRealTolerance();
	testMapping();
	testPlaneToScreen();
	testFitRadius();

	const lines: string[] = [];
	lines.push(failures.length === 0 ? 'passed' : 'failed');
	lines.push(`checks=${checks} failures=${failures.length}`);
	const limit = failures.length < 12 ? failures.length : 12;
	for (let i = 0; i < limit; i++) {
		lines.push(`FAIL ${failures[i].name}: ${failures[i].detail}`);
	}
	return lines.join('\n');
}
