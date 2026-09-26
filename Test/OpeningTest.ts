/**
 * S3.3 单测：开场分镜的**纯计算**部分（时间线相态 / 机位 / 探测器入轨 / 站点表）。
 *
 * 为什么值得测：这些量都是"帧号的纯函数"，肉眼只能看几张截图，而相机从全景俯冲到特写
 * 再拉回的整条曲线上任何一帧出问题（穿到地平线以下、距离跳变、探测器飞出画面）都会难看；
 * 逐帧断言能把"看起来差不多"变成"每一帧都在范围内"。
 *
 * 输出格式：首行为 `passed` 或 `failed`。
 */
import { Vec3 } from 'Dora';
import { P2 } from 'game/Gravity';
import {
	EarthStationIndex,
	ProbeOrbitRadius,
	PullBackFrames,
	Stations,
	TotalFrames,
	WideFrames,
	FocusFrames,
	openingBlend,
	openingPhase,
	openingPose,
	probeOrbitPos,
	probeOrbitVel,
	stationPlane,
} from 'game/Opening';

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

function dist3(a: Vec3.Type, b: Vec3.Type): number {
	const dx = a.x - b.x;
	const dy = a.y - b.y;
	const dz = a.z - b.z;
	return Math.sqrt(dx * dx + dy * dy + dz * dz);
}

/** 1) 相态边界：每一段的起止帧都必须落在正确的相态里。 */
function testPhases(): void {
	check('phase-off', openingPhase(-1) === 'off', '负帧号 = off');
	check('phase-wide-start', openingPhase(0) === 'wide', '第 0 帧是全景');
	check('phase-wide-end', openingPhase(WideFrames - 1) === 'wide', '全景最后一帧');
	check('phase-focus-start', openingPhase(WideFrames) === 'focus', '聚焦第一帧');
	check('phase-focus-end', openingPhase(WideFrames + FocusFrames - 1) === 'focus', '聚焦最后一帧');
	check('phase-hold-start', openingPhase(WideFrames + FocusFrames) === 'hold', '停留第一帧');
	check('phase-hold-end', openingPhase(TotalFrames) === 'hold', '交还选关那一帧仍是 hold');
	check('phase-pullback', openingPhase(TotalFrames + 1) === 'pullback', '之后是拉回段');
}

/** 2) 混合系数：0 → 1 → 0，且两端与中间单调。 */
function testBlend(): void {
	check('blend-zero', openingBlend(0) === 0, '全景起点 = 0');
	check('blend-plateau', openingBlend(WideFrames) === 0, '全景段结束仍是 0');
	const mid = openingBlend(WideFrames + FocusFrames * 0.5);
	check('blend-mid', mid > 0.4 && mid < 0.6, `中点 ${mid.toFixed(3)} 应接近 0.5`);
	check('blend-one', openingBlend(WideFrames + FocusFrames) === 1, '聚焦结束 = 1');
	check('blend-hold', openingBlend(TotalFrames) === 1, '停留段末尾仍是 1');
	check('blend-return', openingBlend(TotalFrames + PullBackFrames) === 0, '拉回结束回到 0');
	check('blend-return-stay', openingBlend(TotalFrames + PullBackFrames * 3) === 0, '拉回后一直保持 0');
	let mono = true;
	let prev = -1;
	for (let f = WideFrames; f <= WideFrames + FocusFrames; f += 10) {
		const v = openingBlend(f);
		if (v < prev - 1e-9) mono = false;
		prev = v;
	}
	check('blend-monotonic-in', mono, '聚焦段单调不减');
	mono = true;
	prev = 2;
	for (let f = TotalFrames; f <= TotalFrames + PullBackFrames; f += 10) {
		const v = openingBlend(f);
		if (v > prev + 1e-9) mono = false;
		prev = v;
	}
	check('blend-monotonic-out', mono, '拉回段单调不增');
}

/** 3) 站点表：轨道严格外扩、模型名非空、地球下标合法。 */
function testStations(): void {
	let ordered = true;
	for (let i = 1; i < Stations.length; i++) {
		if (Stations[i].orbit <= Stations[i - 1].orbit) ordered = false;
	}
	check('stations-ordered', ordered, '轨道半径必须由内到外严格递增（否则全景里行星会互相穿）');
	check('stations-earth-index', EarthStationIndex >= 0 && EarthStationIndex < Stations.length, `地球下标 ${EarthStationIndex}`);
	check('stations-earth-model', Stations[EarthStationIndex].model === 'Planet_Earth', '聚焦目标必须是地球');
	let named = true;
	for (const st of Stations) {
		if (st.model.length < 3) named = false;
	}
	check('stations-named', named, '每站都要有模型名');
	const outside = stationPlane(-1);
	check('station-out-of-range', outside.x === 0 && outside.y === 0, '越界下标返回原点，不抛错');
	const earth = stationPlane(EarthStationIndex);
	const r = Math.sqrt(earth.x * earth.x + earth.y * earth.y);
	check('station-radius', Math.abs(r - Stations[EarthStationIndex].orbit) < 1e-9, `地球到太阳 ${r.toFixed(3)} 应等于轨道半径`);
}

/** 4) 机位：全景距离 / 特写距离 / 始终在黄道面上方 / 注视点跟着混合走。 */
function testPose(): void {
	const earth = stationPlane(EarthStationIndex);
	const p0 = openingPose(0, earth);
	const d0 = dist3(p0.eye, p0.target);
	// ⚠️ Vec3 是**单精度**（引擎侧 float）——容差别往 1e-6 以下写，实测 1e-9 会假失败
	check('pose-wide-distance', Math.abs(d0 - 205) < 1e-2, `第 0 帧距离 ${d0.toFixed(2)} 应为 205`);
	check('pose-wide-target', dist3(p0.target, Vec3(0, 0, 0)) < 1e-9, '全景注视点是太阳');
	const p1 = openingPose(TotalFrames, earth);
	const d1 = dist3(p1.eye, p1.target);
	check('pose-close-distance', Math.abs(d1 - 12) < 1e-2, `停留段距离 ${d1.toFixed(2)} 应为 12`);
	const t1 = p1.target;
	const earthWorldDist = Math.sqrt((t1.x - earth.x) * (t1.x - earth.x) + (t1.z - earth.y) * (t1.z - earth.y));
	check('pose-close-target', earthWorldDist < 1e-3, '特写注视点落在地球上');
	let above = true;
	for (let f = 0; f <= TotalFrames + PullBackFrames; f += 20) {
		const p = openingPose(f, earth);
		if (p.eye.y <= p.target.y) above = false;
	}
	check('pose-above-plane', above, '相机必须始终在黄道面之上（否则全景会变成仰视）');
}

/** 5) 探测器入轨：绕地球、半径恒定、角速度恒定、切线速度垂直于半径。 */
function testProbeOrbit(): void {
	const earth = stationPlane(EarthStationIndex);
	let radiusOk = true;
	for (let f = 0; f <= TotalFrames; f += 30) {
		const p = probeOrbitPos(f, earth);
		const dx = p.x - earth.x;
		const dy = p.y - earth.y;
		const r = Math.sqrt(dx * dx + dy * dy);
		if (Math.abs(r - ProbeOrbitRadius) > 1e-9) radiusOk = false;
	}
	check('probe-orbit-radius', radiusOk, '每一帧都在半径 ' + ProbeOrbitRadius.toFixed(2) + ' 的圆上');

	const p0 = probeOrbitPos(0, earth);
	const v0 = probeOrbitVel(0);
	const rx = p0.x - earth.x;
	const ry = p0.y - earth.y;
	check('probe-velocity-perpendicular', Math.abs(rx * v0.x + ry * v0.y) < 1e-9, '速度必须沿切线（与半径垂直）');
	const speed = Math.sqrt(v0.x * v0.x + v0.y * v0.y);
	check('probe-velocity-nonzero', speed > 1e-6, '速度不能为 0（否则朝向计算会退化）');

	// 角速度恒定：等间隔帧的夹角相同
	const a0 = Math.atan2(probeOrbitPos(0, earth).y - earth.y, probeOrbitPos(0, earth).x - earth.x);
	const a1 = Math.atan2(probeOrbitPos(60, earth).y - earth.y, probeOrbitPos(60, earth).x - earth.x);
	const a2 = Math.atan2(probeOrbitPos(120, earth).y - earth.y, probeOrbitPos(120, earth).x - earth.x);
	const step1 = a1 - a0;
	const step2 = a2 - a1;
	check('probe-orbit-uniform', Math.abs(step1 - step2) < 1e-9, '公转角速度恒定');
	// 一整个开场转过的角度要看得见（> 一个屏幕半圈的观感）
	const total = (a2 - a0) / 120 * TotalFrames;
	check('probe-orbit-visible', Math.abs(total) > 3.0, `整个开场转过 ${(Math.abs(total) * 180 / Math.PI).toFixed(0)}°（应 > 170°）`);
}

export function runTests(): string {
	testPhases();
	testBlend();
	testStations();
	testPose();
	testProbeOrbit();

	const out: string[] = [];
	out.push(failures.length === 0 ? 'passed' : 'failed');
	out.push(`checks=${checks} failures=${failures.length}`);
	const limit = failures.length < 12 ? failures.length : 12;
	for (let i = 0; i < limit; i++) out.push(`FAIL ${failures[i].name}: ${failures[i].detail}`);
	return out.join('\n');
}
