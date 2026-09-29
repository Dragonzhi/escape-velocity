/**
 * S1.4 单测：拖拽矄准的纯逻辑（手册 §5.7）。
 *
 * 输出格式：首行为 `passed` 或 `failed`。
 *   const m = requireProjectModule("Test.HudTest"); print(m.runTests())
 */
import { AimMaxSpeed, AimMinSpeed } from 'game/Config';
import { computeAim, screenToPlane, defaultMaxDragPx, localToOffset, offsetToLocal, resultPanelLayout, TouchSpace } from 'game/Hud';
import { HANDEDNESS, FLIP_Y, prepareCamera, project } from 'game/Projection';

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

// 探测器在**投影偏移空间**中的位置（屏幕中心为原点，+Y 向下）
const PROBE = { x: -60, y: 120 };

/** 1) 无拖动：不发射，速度取最小值。 */
function testNoDrag(): void {
	const a = computeAim(PROBE, PROBE, 300);
	check('no-drag-power', a.power === 0, `power=${a.power}`);
	const speed = Math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y);
	check('no-drag-speed-min', Math.abs(speed - AimMinSpeed) < 1e-9, `speed=${speed} expected=${AimMinSpeed}`);
	// 方向应为“向前”（平面 -y，即向屏幕上方）
	check('no-drag-forward', a.velocity.y < 0 && Math.abs(a.velocity.x) < 1e-9, `v=(${a.velocity.x}, ${a.velocity.y})`);
}

/** 2) 方向：由“探测器 → 触摸点”决定。
 * 投影偏移空间 +Y 向上（修正后），且修正后的渲染方向是：
 * 平面 -y（朝目标）在屏幕**上方**。所以：
 *   触摸在探测器**上方**（offset.y 更大 → dy > 0）→ 平面 -y（朝目标）
 *   触摸在探测器**下方**（dy < 0）→ 平面 +y（背离目标）
 */
function testDirection(): void {
	// 向上拖（dy > 0）→ 平面 -y（朝目标）
	const up = computeAim(PROBE, { x: PROBE.x, y: PROBE.y + 200 }, 300);
	check('dir-up-toward-goal', up.velocity.y < -1, `vy=${up.velocity.y.toFixed(2)}（应为负 = 朝目标）`);

	// 向下拖（dy < 0）→ 平面 +y
	const down = computeAim(PROBE, { x: PROBE.x, y: PROBE.y - 200 }, 300);
	check('dir-down', down.velocity.y > 1, `vy=${down.velocity.y.toFixed(2)}（应为正）`);

	// 向右拖 → 平面 +x
	const right = computeAim(PROBE, { x: PROBE.x + 200, y: PROBE.y }, 300);
	check('dir-right', right.velocity.x > 1 && Math.abs(right.velocity.y) < 1e-9, `v=(${right.velocity.x.toFixed(2)}, ${right.velocity.y.toFixed(2)})`);

	// 单位向量长度为 1
	const u = Math.sqrt(up.unit.x * up.unit.x + up.unit.y * up.unit.y);
	check('unit-length', Math.abs(u - 1) < 1e-9, `|unit|=${u}`);
}

/** 3) 力度：随拖动距离线性增长并夹紧到 1。 */
function testPower(): void {
	const maxDrag = defaultMaxDragPx();

	// 半力
	const half = computeAim(PROBE, { x: PROBE.x, y: PROBE.y + maxDrag / 2 }, maxDrag);
	check('power-half', Math.abs(half.power - 0.5) < 1e-6, `power=${half.power}`);

	// 满力
	const full = computeAim(PROBE, { x: PROBE.x, y: PROBE.y + maxDrag }, maxDrag);
	check('power-full', Math.abs(full.power - 1) < 1e-6, `power=${full.power}`);

	// 超过满力 → 夹紧到 1，不超出速度上限
	const over = computeAim(PROBE, { x: PROBE.x, y: PROBE.y + maxDrag * 3 }, maxDrag);
	check('power-clamped', over.power === 1, `power=${over.power}`);
	const overSpeed = Math.sqrt(over.velocity.x * over.velocity.x + over.velocity.y * over.velocity.y);
	check('speed-clamped', Math.abs(overSpeed - AimMaxSpeed) < 1e-6, `speed=${overSpeed} expected=${AimMaxSpeed}`);

	// 速度随力度单调增长
	let monotonic = true;
	let prev = -1;
	for (const f of [0, 0.25, 0.5, 0.75, 1]) {
		const r = computeAim(PROBE, { x: PROBE.x, y: PROBE.y + maxDrag * f }, maxDrag);
		const s = Math.sqrt(r.velocity.x * r.velocity.x + r.velocity.y * r.velocity.y);
		if (s < prev - 1e-9) { monotonic = false; break; }
		prev = s;
	}
	check('speed-monotonic', monotonic, '速度未随力度单调增长');
}

/** 4) screenToPlane 与 project() 互逆（验证反投影公式正确）。 */
function testRoundTrip(): void {
	const cam = {
		eye: { x: 0, y: 21.2, z: 21.2 },
		target: { x: 0, y: 0, z: 0 },
		up: { x: 0, y: 1, z: 0 },
		fovYDeg: 45,
		aspect: 0.5625,
		viewW: 1080,
		viewH: 1920,
	};
	const basis = prepareCamera(cam, HANDEDNESS, FLIP_Y);

	// 若干平面点 → 投影（偏移空间）→ 反投影，应回到原点
	const pts = [
		{ x: 0, y: 0 },
		{ x: 5, y: -8 },
		{ x: -6, y: 4 },
	];

	let maxErr = 0;
	for (const p of pts) {
		const world = { x: p.x, y: 0, z: p.y };
		const proj = project(world, cam, HANDEDNESS, FLIP_Y);
		if (proj === undefined) { maxErr = 1e9; break; }
		// project() 输出即偏移空间，直接喂给 screenToPlane
		const back = screenToPlane({ x: proj.x, y: proj.y }, basis);
		if (back === undefined) { maxErr = 1e9; break; }
		const dx = back.x - p.x;
		const dy = back.y - p.y;
		const e = Math.sqrt(dx * dx + dy * dy);
		if (e > maxErr) maxErr = e;
	}
	check('screen-plane-roundtrip', maxErr < 1e-6, `maxErr=${maxErr.toFixed(12)}（应接近 0）`);
}

/** 5) 坐标换算：局部坐标 ↔ 投影偏移空间应互逆，且语义正确。 */
function testSpaceConversion(): void {
	const space: TouchSpace = { viewW: 1080, viewH: 1920 };

	// 屏幕中心 → 偏移 (0,0)
	const center = localToOffset({ x: 540, y: 960 }, space);
	check('space-center', Math.abs(center.x) < 1e-9 && Math.abs(center.y) < 1e-9, `offset=(${center.x}, ${center.y})`);

	// 左下角（局部 0,0）→ 偏移 (-W/2, -H/2)（两个空间都是 +Y 向上，屏底为负）
	const bl = localToOffset({ x: 0, y: 0 }, space);
	check('space-bottom-left', Math.abs(bl.x + 540) < 1e-9 && Math.abs(bl.y + 960) < 1e-9, `offset=(${bl.x}, ${bl.y})`);

	// 左上角（局部 0,H）→ 偏移 (-W/2, +H/2)
	const tl = localToOffset({ x: 0, y: 1920 }, space);
	check('space-top-left', Math.abs(tl.x + 540) < 1e-9 && Math.abs(tl.y - 960) < 1e-9, `offset=(${tl.x}, ${tl.y})`);

	// 互逆
	let allExact = true;
	for (const p of [{ x: 100, y: 200 }, { x: 0, y: 0 }, { x: -300, y: 150 }]) {
		const back = offsetToLocal(localToOffset(p, space), space);
		if (Math.abs(back.x - p.x) > 1e-9 || Math.abs(back.y - p.y) > 1e-9) { allExact = false; break; }
	}
	check('space-roundtrip', allExact, 'localToOffset / offsetToLocal 不互逆');
}

/** 6) 结算卡与操作按钮始终落在竖屏视口内。 */
function testResultPanelLayout(): void {
	for (const size of [{ w: 280, h: 400 }, { w: 320, h: 568 }, { w: 360, h: 640 }, { w: 390, h: 844 }, { w: 430, h: 932 }]) {
		const layout = resultPanelLayout(size.w, size.h);
		check(`result-card-inside-${size.w}`, layout.cardX >= 0 && layout.cardX + layout.cardW <= size.w, `x=${layout.cardX} w=${layout.cardW} view=${size.w}`);
		check(`result-card-height-${size.h}`, layout.cardY >= 0 && layout.cardY + layout.cardH <= size.h, `y=${layout.cardY} h=${layout.cardH} view=${size.h}`);
		const buttonX = layout.cardX + (layout.cardW - layout.buttonW) / 2;
		check(`result-buttons-inside-${size.w}`, buttonX >= 0 && buttonX + layout.buttonW <= size.w, `x=${buttonX} w=${layout.buttonW} view=${size.w}`);
		check(`result-button-target-${size.h}`, layout.buttonH >= 48, `buttonH=${layout.buttonH}`);
	}
}

export function runTests(): string {
	testNoDrag();
	testDirection();
	testPower();
	testRoundTrip();
	testSpaceConversion();
	testResultPanelLayout();

	const lines: string[] = [];
	lines.push(failures.length === 0 ? 'passed' : 'failed');
	lines.push(`checks=${checks} failures=${failures.length}`);
	const limit = failures.length < 12 ? failures.length : 12;
	for (let i = 0; i < limit; i++) {
		lines.push(`FAIL ${failures[i].name}: ${failures[i].detail}`);
	}
	return lines.join('\n');
}
