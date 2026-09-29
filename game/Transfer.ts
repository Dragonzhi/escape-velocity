/** L1 顺行转移规划；纯函数，单位与关卡 JSON 一致。 */
import { Body, P2, SimResult, bodyPositionAt, distance } from 'game/Gravity';

export interface TransferTutorial {
	apoapsisMax: number;
	mode?: 'raiseApoapsis' | 'lowerPeriapsis';
	periapsisMin?: number;
	orbital?: OrbitalTutorial;
	thrustAcceleration: number;
	coastPlayback: number;
	/** 安全减速掠月才完成；省略沿用旧的到达光点教程。 */
	flyby?: FlybyTutorial;
}

export interface EncounterSpec {
	planetIndex: number;
	focus: CameraFocusMode;
	encounterRadius: number;
	minPeriapsis: number;
	maxPeriapsis: number;
	energyDirection: 'gain' | 'loss';
	minEnergyChange: number;
	minWork: number;
}

export interface OrbitalTutorial {
	standbyPlayback: number;
	slowWindow: number;
	maxViewingTime: number;
	encounters: EncounterSpec[];
	region: { minRadius: number; maxRadius: number; direction: 'inward' | 'outward' };
}

export interface EncounterAnalysis {
	planetIndex: number;
	entryIndex: number;
	periapsisIndex: number;
	exitIndex: number;
	periapsis: number;
	energyChange: number;
	work: number;
	passed: boolean;
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
	encounters?: EncounterAnalysis[];
	entryIndex: number;
	periapsisIndex: number;
	exitIndex: number;
	completionIndex: number;
	viewEndIndex: number;
	periapsis: number;
	energyDrop: number;
}

/** 完整会遇的日心能量变化与对应行星做功，两者共同验证借力。 */
export function analyzeOrbitalMission(flight: SimResult, bodies: Body[], cfg: OrbitalTutorial, dt: number, t0: number): FlybyAnalysis {
	const stages: EncounterAnalysis[] = [];
	const last = flight.points.length - 1;
	let after = -1;
	let ordered: boolean = true;
	for (const spec of cfg.encounters) {
		const body = bodies[spec.planetIndex];
		let entry = -1, peri = -1, exit = -1, nearest = 1e9;
		if (body !== undefined) for (let i = 0; i <= last; i++) {
			const d = distance(flight.points[i], bodyPositionAt(body, t0 + i * dt));
			if (entry < 0 && d <= spec.encounterRadius) entry = i;
			if (entry < 0) continue;
			if (d < nearest) { nearest = d; peri = i; }
			if (i > entry && d >= spec.encounterRadius) { exit = i; break; }
		}
		const change = entry >= 0 && exit >= 0 ? specificEnergy(flight, exit, bodies[0], t0 + exit * dt) - specificEnergy(flight, entry, bodies[0], t0 + entry * dt) : 0;
		let work = 0;
		if (body !== undefined && entry >= 0 && exit >= 0) for (let i = entry; i < exit; i++) {
			let power = 0;
			for (let k = i; k <= i + 1; k++) {
				const bp = bodyPositionAt(body, t0 + k * dt), p = flight.points[k], v = flight.velocities[k];
				const x = bp.x - p.x, y = bp.y - p.y, r = Math.sqrt(x * x + y * y);
				if (r > 0) power += body.gm * (v.x * x + v.y * y) / (r * r * r);
			}
			work += power * dt / 2;
		}
		const sign = spec.energyDirection === 'gain' ? 1 : -1;
		const passed: boolean = ordered && body !== undefined && entry > after && entry > 0 && peri > entry && exit > peri
			&& nearest >= Math.max(body.radius, spec.minPeriapsis) && nearest <= spec.maxPeriapsis
			&& sign * change >= spec.minEnergyChange && sign * work >= spec.minWork;
		stages.push({ planetIndex: spec.planetIndex, entryIndex: entry, periapsisIndex: peri, exitIndex: exit, periapsis: nearest, energyChange: change, work, passed });
		ordered = passed; after = exit;
	}
	let complete = -1;
	if (ordered && stages.length > 0) for (let i = Math.max(1, after + 1); i <= last; i++) {
		const r = distance(flight.points[i], bodyPositionAt(bodies[0], t0 + i * dt));
		const prev = distance(flight.points[i - 1], bodyPositionAt(bodies[0], t0 + (i - 1) * dt));
		const rg = cfg.region;
		if (r >= rg.minRadius && r <= rg.maxRadius && (rg.direction === 'inward' ? prev > rg.maxRadius && r < prev : prev < rg.minRadius && r > prev)) { complete = i; break; }
	}
	const first = stages.length > 0 ? stages[0] : undefined;
	return { encounters: stages, entryIndex: first !== undefined ? first.entryIndex : -1, periapsisIndex: first !== undefined ? first.periapsisIndex : -1,
		exitIndex: first !== undefined ? first.exitIndex : -1, periapsis: first !== undefined ? first.periapsis : 1e9, energyDrop: first !== undefined ? -first.energyChange : 0,
		completionIndex: complete, viewEndIndex: complete >= 0 ? Math.min(last, complete + Math.floor(cfg.maxViewingTime / dt)) : last };
}

export function analyzeTransfer(flight: SimResult, bodies: Body[], targetIndex: number, tr: TransferTutorial, dt: number, t0: number): FlybyAnalysis | undefined {
	if (tr.orbital !== undefined) return analyzeOrbitalMission(flight, bodies, tr.orbital, dt, t0);
	return tr.flyby !== undefined ? analyzeFlyby(flight, bodies[0], bodies[targetIndex], tr.flyby, dt, t0) : undefined;
}

export function transferCinematic(tr: TransferTutorial | undefined): boolean {
	return tr !== undefined && (tr.flyby !== undefined || tr.orbital !== undefined);
}

function slowTimes(tr: TransferTutorial, analysis: FlybyAnalysis | undefined, dt: number): number[] {
	const out: number[] = [];
	if (analysis === undefined) return out;
	const cfg = tr.orbital !== undefined ? tr.orbital : tr.flyby;
	if (cfg === undefined) return out;
	const indices = analysis.encounters !== undefined ? analysis.encounters.map(e => e.periapsisIndex) : [analysis.periapsisIndex];
	for (const i of indices) if (i >= 0) out.push(i * dt - cfg.slowWindow, i * dt + cfg.slowWindow);
	return out;
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
	const times = slowTimes(tr, analysis, dt);
	for (let i = 0; i < times.length; i += 2) if (time >= times[i] && time < times[i + 1]) return 1;
	return tr.coastPlayback;
}

/** 跨倍率边界分段推进，30/60/120 FPS 下点火和近月观赏段的时长相同。 */
export function advanceTransferPlayback(time: number, wallDt: number, baseRate: number, burn: number, tr: TransferTutorial, analysis: FlybyAnalysis | undefined, dt: number): number {
	if (baseRate <= 0 || wallDt <= 0) return time;
	let remaining = wallDt;
	const boundaries = [burn, ...slowTimes(tr, analysis, dt)];
	for (let n = 0; n <= boundaries.length && remaining > 1e-10; n++) {
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

export type CameraFocusMode = 'Auto' | 'Probe' | 'Moon' | 'Earth' | 'Venus' | 'Jupiter' | 'Saturn' | 'Sun' | 'Overview';
export type TransferShot = 'Launch' | 'Cruise' | 'Moon' | 'Overview' | 'Earth' | 'Venus' | 'Jupiter' | 'Saturn' | 'Sun';

export function nextCameraFocus(mode: CameraFocusMode, modes?: CameraFocusMode[]): CameraFocusMode {
	if (modes !== undefined) {
		const i = modes.indexOf(mode);
		return modes[(i + 1) % modes.length];
	}
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
export function planTransfer(mu: number, radius: number, vel: P2, power: number, maxRadius: number, mode?: 'raiseApoapsis' | 'lowerPeriapsis', minRadius?: number): TransferPlan {
	const p = Math.max(0, Math.min(1, power));
	const ra = mode === 'lowerPeriapsis' ? radius + (Math.max(1, Math.min(radius, minRadius !== undefined ? minRadius : radius)) - radius) * p : radius + (Math.max(radius, maxRadius) - radius) * p;
	const a = (radius + ra) / 2;
	const dv = mu > 0 && radius > 0 ? Math.sqrt(mu * (2 / radius - 1 / a)) - Math.sqrt(mu / radius) : 0;
	const speed = Math.sqrt(vel.x * vel.x + vel.y * vel.y);
	return { apoapsis: ra, dv: Math.abs(dv), velocity: { x: speed > 0 ? vel.x * dv / speed : 0, y: speed > 0 ? vel.y * dv / speed : 0 } };
}

export function orbitalShotAt(time: number, burn: number, analysis: FlybyAnalysis | undefined, cfg: OrbitalTutorial, dt: number): TransferShot {
	if (time <= burn + 1.2) return 'Launch';
	if (analysis !== undefined && analysis.encounters !== undefined) for (let i = 0; i < analysis.encounters.length; i++) {
		const e = analysis.encounters[i];
		if (e.entryIndex >= 0 && time >= e.entryIndex * dt && (e.exitIndex < 0 || time <= e.exitIndex * dt)) return cfg.encounters[i].focus as TransferShot;
	}
	return analysis !== undefined && analysis.exitIndex >= 0 && analysis.encounters !== undefined && analysis.encounters.every(e => e.passed && time > e.exitIndex * dt) ? 'Overview' : 'Cruise';
}

/** 独立显示时间；调用方每帧累加 wallDt，暂停与物理倍率不参与。 */
export function successMarkerFrame(elapsed: number): { visible: boolean; alpha: number; scale: number; ring: number } {
	if (elapsed < 0) return { visible: true, alpha: 1, scale: 1, ring: 0 };
	if (elapsed >= 0.6) return { visible: false, alpha: 0, scale: 1, ring: 0 };
	const u = Math.max(0, (elapsed - 0.12) / 0.48);
	return { visible: true, alpha: 1 - u, scale: elapsed < 0.12 ? 1 + elapsed / 0.12 : 2 - u, ring: elapsed < 0.12 ? 0 : 8 + 30 * u };
}
