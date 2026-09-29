/** L1 顺行转移规划；纯函数，单位与关卡 JSON 一致。 */
import { Body, P2, SimResult, bodyPositionAt, distance } from 'game/Gravity';

export interface TransferTutorial {
	apoapsisMax: number;
	thrustAcceleration: number;
	coastPlayback: number;
	/** 安全减速掠月才完成；省略沿用旧的到达光点教程。 */
	flyby?: FlybyTutorial;
}

export interface FlybyTutorial {
	standbyPlayback: number;
	encounterRadius: number;
	minPeriapsis: number;
	maxPeriapsis: number;
	minEnergyDrop: number;
	returnRadius: number;
	maxViewingTime: number;
	/** 近月点前/后各多少游戏秒按 1× 播放。 */
	slowWindow: number;
	/** 掠月后总览持续的游戏秒（巡航 3× 时，3 秒 = 1 真实秒）。 */
	overviewDuration: number;
}

export interface FlybyAnalysis {
	entryIndex: number;
	periapsisIndex: number;
	exitIndex: number;
	completionIndex: number;
	viewEndIndex: number;
	periapsis: number;
	energyDrop: number;
}

/** 地心比能；使用相对中心天体的速度，避免混入参考系的平移。 */
function specificEnergy(flight: SimResult, index: number, center: Body, t: number): number {
	const pos = bodyPositionAt(center, t);
	// 中心体在街机配置中静止；宿主链/公转体则按解析位置求导。
	const before = bodyPositionAt(center, t - 0.001);
	const after = bodyPositionAt(center, t + 0.001);
	const vx = flight.velocities[index].x - (after.x - before.x) / 0.002;
	const vy = flight.velocities[index].y - (after.y - before.y) / 0.002;
	const r = distance(flight.points[index], pos);
	return r > 0 ? (vx * vx + vy * vy) / 2 - center.gm / r : -1e9;
}

/** 只分析首次会遇；光点无关，必须安全走完进入→近月点→离开。 */
export function analyzeFlyby(flight: SimResult, center: Body, moon: Body, cfg: FlybyTutorial, dt: number, t0: number): FlybyAnalysis {
	let entry = -1, peri = -1, exit = -1, nearest = 1e9;
	const last = flight.points.length - 1;
	for (let i = 0; i <= last; i++) {
		const d = distance(flight.points[i], bodyPositionAt(moon, t0 + i * dt));
		if (entry < 0 && d <= cfg.encounterRadius) entry = i;
		if (entry < 0) continue;
		if (d < nearest) { nearest = d; peri = i; }
		if (i > entry && d >= cfg.encounterRadius) { exit = i; break; }
	}
	const drop = entry >= 0 && exit >= 0
		? specificEnergy(flight, entry, center, t0 + entry * dt) - specificEnergy(flight, exit, center, t0 + exit * dt) : 0;
	const complete = entry > 0 && peri > entry && exit > peri && nearest >= Math.max(moon.radius, cfg.minPeriapsis)
		&& nearest <= cfg.maxPeriapsis && drop >= cfg.minEnergyDrop ? exit : -1;
	let end = last;
	if (complete >= 0) {
		end = Math.min(last, complete + Math.floor(cfg.maxViewingTime / dt));
		for (let i = complete + 1; i <= end; i++) {
			const r = distance(flight.points[i], bodyPositionAt(center, t0 + i * dt));
			const prev = distance(flight.points[i - 1], bodyPositionAt(center, t0 + (i - 1) * dt));
			if (prev > cfg.returnRadius && r <= cfg.returnRadius) { end = i; break; }
		}
	}
	return { entryIndex: entry, periapsisIndex: peri, exitIndex: exit, completionIndex: complete, viewEndIndex: end, periapsis: nearest, energyDrop: drop };
}

export function transferPlaybackRate(time: number, burn: number, tr: TransferTutorial, analysis: FlybyAnalysis | undefined, dt: number): number {
	if (time < burn) return 1;
	if (tr.flyby !== undefined && analysis !== undefined && analysis.periapsisIndex >= 0) {
		const periTime = analysis.periapsisIndex * dt;
		if (time >= periTime - tr.flyby.slowWindow && time < periTime + tr.flyby.slowWindow) return 1;
	}
	return tr.coastPlayback;
}

/** 跨倍率边界分段推进，30/60/120 FPS 下点火和近月观赏段的时长相同。 */
export function advanceTransferPlayback(time: number, wallDt: number, baseRate: number, burn: number, tr: TransferTutorial, analysis: FlybyAnalysis | undefined, dt: number): number {
	if (baseRate <= 0 || wallDt <= 0) return time;
	let remaining = wallDt;
	const boundaries = [burn];
	if (tr.flyby !== undefined && analysis !== undefined && analysis.periapsisIndex >= 0) {
		const periTime = analysis.periapsisIndex * dt;
		boundaries.push(periTime - tr.flyby.slowWindow, periTime + tr.flyby.slowWindow);
	}
	for (let n = 0; n < 4 && remaining > 1e-10; n++) {
		const rate = baseRate * transferPlaybackRate(time, burn, tr, analysis, dt);
		let next = 1e9;
		for (let i = 0; i < boundaries.length; i++) if (boundaries[i] > time + 1e-10 && boundaries[i] < next) next = boundaries[i];
		const until = (next - time) / rate;
		if (until >= remaining) return time + remaining * rate;
		time = next;
		remaining -= until;
	}
	return time;
}

export type CameraFocusMode = 'Auto' | 'Probe' | 'Moon' | 'Earth' | 'Overview';
export type TransferShot = 'Launch' | 'Cruise' | 'Moon' | 'Overview' | 'Earth';

export function nextCameraFocus(mode: CameraFocusMode): CameraFocusMode {
	if (mode === 'Auto') return 'Probe';
	if (mode === 'Probe') return 'Moon';
	if (mode === 'Moon') return 'Earth';
	if (mode === 'Earth') return 'Overview';
	return 'Auto';
}

export function transferShotAt(time: number, burn: number, analysis: FlybyAnalysis | undefined, cfg: FlybyTutorial, dt: number): TransferShot {
	if (time <= burn + 1.2) return 'Launch';
	if (analysis !== undefined && analysis.entryIndex >= 0 && time >= analysis.entryIndex * dt) {
		if (analysis.completionIndex >= 0 && time >= analysis.completionIndex * dt) {
			return time < analysis.completionIndex * dt + cfg.overviewDuration ? 'Overview' : 'Earth';
		}
		if (analysis.exitIndex < 0 || time <= analysis.exitIndex * dt) return 'Moon';
	}
	return 'Cruise';
}

export interface TransferPlan {
	apoapsis: number;
	dv: number;
	velocity: P2;
}

/** 拖动长度只改变远地点；方向由出发圆轨的顺行切线确定。 */
export function planTransfer(mu: number, radius: number, vel: P2, power: number, maxRadius: number): TransferPlan {
	const p = Math.max(0, Math.min(1, power));
	const ra = radius + (Math.max(radius, maxRadius) - radius) * p;
	const a = (radius + ra) / 2;
	const dv = mu > 0 && radius > 0 ? Math.sqrt(mu * (2 / radius - 1 / a)) - Math.sqrt(mu / radius) : 0;
	const speed = Math.sqrt(vel.x * vel.x + vel.y * vel.y);
	return { apoapsis: ra, dv, velocity: { x: speed > 0 ? vel.x * dv / speed : 0, y: speed > 0 ? vel.y * dv / speed : 0 } };
}
