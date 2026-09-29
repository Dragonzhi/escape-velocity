/** 日心任务的借力证据、顺序、目标方向与实际完成时序。 */
import { Content, json } from 'Dora';
import { bodyPositionAt, distance, simulate } from 'game/Gravity';
import { getLevel, installArcadeLevels, findGoalIndex, evaluateRocketsDetailed } from 'game/LevelData';
import { analyzeOrbitalMission, advanceTransferPlayback, orbitalShotAt, planTransfer } from 'game/Transfer';
import { GameLevel, createCore, coreLaunch, coreUpdate, coreEndViewing, coreRetry } from 'game/Game';
import { isSunVisual } from 'game/Scene';

export function runTests(): string {
	let checks = 0;
	const failures: string[] = [];
	const check = (name: string, ok: boolean): void => { checks++; if (!ok) failures.push(name); };
	installArcadeLevels(Content.load('Assets/Levels/levels.json'), Content.load('Assets/Levels/bodies.json'), (s: string): unknown => json.decode(s)[0]);
	const dt = 0.016;
	check('explicit-sun-model', isSunVisual({ r: 1, g: 1, b: 1, displayRadius: 50, ring: false, model: 'Sun' }));
	check('massive-earth-not-sun', !isSunVisual({ r: 1, g: 1, b: 1, displayRadius: 42, ring: false, model: 'Planet_Earth' }));
	check('undefined-not-sun', !isSunVisual(undefined));
	for (let n = 1; n <= 2; n++) {
		const lv = getLevel(n)!;
		if (lv.transfer === undefined || lv.transfer.orbital === undefined) return 'failed\nmissing orbital fixture';
		const tr = lv.transfer, cfg = lv.transfer.orbital, mu = lv.planets[0].gm;
		const r = distance(lv.probeStart, bodyPositionAt(lv.planets[0], 0));
		const power = n === 1 ? 11 / 14 : 0.5;
		const stateAt = (date: number): { pos: { x: number; y: number }; vel: { x: number; y: number } } => {
			const a = Math.atan2(lv.probeStart.y, lv.probeStart.x) + Math.sqrt(mu / (r * r * r)) * date, speed = Math.sqrt(mu / r);
			return { pos: { x: r * Math.cos(a), y: r * Math.sin(a) }, vel: { x: -Math.sin(a) * speed, y: Math.cos(a) * speed } };
		};
		const level: GameLevel = { bodies: lv.planets, probeStart: lv.probeStart, probeVel0: lv.probeVel0, goal: lv.goal, escapeRadius: lv.escapeRadius, maxSteps: lv.maxSteps, transfer: tr };
		const launchAt = (date: number, p: number) => {
			const core = createCore(dt), start = stateAt(date);
			const plan = planTransfer(mu, r, start.vel, p, tr.apoapsisMax, tr.mode, tr.periapsisMin);
			core.t0 = date; coreLaunch(core, plan.velocity, level, start.pos, start.vel); core.playback = 1;
			return core;
		};
		const core = launchAt(1, power), flight = core.flight!, analysis = core.flyby!;
		const prefix = 'L' + (n + 1).toFixed(0) + '-';
		check(prefix + 'sun-center', mu === 800000 && lv.planets[0].radius === 50 && lv.planets[0].orbitRadius === 0);
		check(prefix + 'only-real-bodies', lv.planets.length === n + 1 && lv.stars!.length === 0 && lv.planets.every(b => b.gm > 0 && !b.isObstacle));
		check(prefix + 'marker-independent', lv.goal.marker !== undefined && lv.goal.marker.gm === 0 && lv.goal.marker.radius === 0 && lv.planets.indexOf(lv.goal.marker) < 0);
		check(prefix + 'marker-guidance-only', findGoalIndex([bodyPositionAt(lv.goal.marker!, 0)], lv.planets, lv.goal, dt) < 0);
		check(prefix + 'sun-emissive', lv.visuals[0].emissive !== undefined && lv.visuals[0].emissive!.r === 1);
		check(prefix + 'baseline-success', core.goalIndex > 0 && analysis.encounters!.every(e => e.passed));
		check(prefix + 'short-burn', core.burnDuration > 0.29 && core.burnDuration < 0.31);
		check(prefix + 'not-precompleted', !core.missionCompleted && core.result === undefined && !coreEndViewing(core));
		const start = stateAt(1), plan = planTransfer(mu, r, start.vel, power, tr.apoapsisMax, tr.mode, tr.periapsisMin);
		check(prefix + 'drag-radius', Math.abs(plan.apoapsis - (n === 1 ? 180 : 420)) < 1e-8);
		check(prefix + 'system-tangent', Math.abs(plan.velocity.x * start.vel.y - plan.velocity.y * start.vel.x) < 1e-8 && (plan.velocity.x * start.vel.x + plan.velocity.y * start.vel.y) * (n === 1 ? -1 : 1) > 0);
		check(prefix + 'finite-burn', distance(flight.velocities[0], start.vel) < 1e-10);
		const ref = simulate({ pos: start.pos, vel: { x: start.vel.x + plan.velocity.x, y: start.vel.y + plan.velocity.y } }, lv.planets, { dt, steps: 3600, sampleEvery: 1, escapeRadius: lv.escapeRadius, t0: 1 });
		check(prefix + 'instant-plan-success', analyzeOrbitalMission(ref, lv.planets, cfg, dt, 1).completionIndex > 0);
		for (const e of analysis.encounters!) check(prefix + 'small-drift-' + e.planetIndex.toFixed(0), distance(flight.points[e.periapsisIndex], ref.points[e.periapsisIndex]) < 5);
		check(prefix + 'work-required', analyzeOrbitalMission(flight, lv.planets, { ...cfg, encounters: cfg.encounters.map(e => ({ ...e, minWork: 1e9 })) }, dt, 1).completionIndex < 0);
		check(prefix + 'missing-assist-fails', analyzeOrbitalMission(flight, lv.planets.map((b, i) => i === 1 ? { ...b, gm: 0 } : b), cfg, dt, 1).completionIndex < 0);
		check(prefix + 'energy-required', analyzeOrbitalMission(flight, lv.planets, { ...cfg, encounters: cfg.encounters.map(e => ({ ...e, minEnergyChange: 1e9 })) }, dt, 1).completionIndex < 0);
		check(prefix + 'safe-distance-required', analyzeOrbitalMission(flight, lv.planets, { ...cfg, encounters: cfg.encounters.map(e => ({ ...e, minPeriapsis: 105 })) }, dt, 1).completionIndex < 0);
		const reverse = analyzeOrbitalMission(flight, lv.planets, { ...cfg, region: { ...cfg.region, direction: n === 1 ? 'outward' : 'inward' } }, dt, 1);
		// L2 会先向外穿过内圈，随后才向内回来；第一次向外穿越不能完成配置中的向内任务。
		check(prefix + 'target-direction-required', reverse.completionIndex < 0 || (reverse.completionIndex < analysis.completionIndex && analyzeOrbitalMission({ ...flight, points: flight.points.slice(0, reverse.completionIndex + 1), velocities: flight.velocities.slice(0, reverse.completionIndex + 1) }, lv.planets, cfg, dt, 1).completionIndex < 0));
		if (n === 2) check(prefix + 'order-required', analyzeOrbitalMission(flight, lv.planets, { ...cfg, encounters: [cfg.encounters[1], cfg.encounters[0]] }, dt, 1).completionIndex < 0);
		check(prefix + 'low-power-fails', launchAt(1, 0.04).goalIndex < 0);
		check(prefix + 'wrong-date-fails', launchAt(0, power).goalIndex < 0);
		core.playback = 0; core.flightTime = (core.goalIndex - 1) * dt; coreUpdate(core, 0, level);
		check(prefix + 'before-region-incomplete', !core.missionCompleted);
		core.flightTime = core.goalIndex * dt; coreUpdate(core, 0, level);
		check(prefix + 'actual-region-completes', core.missionCompleted && core.phase === 'Flying' && core.result === 'success');
		check(prefix + 'manual-end', coreEndViewing(core) && core.phase === 'Result');
		const normal = launchAt(1, power), fast = launchAt(1, power);
		fast.playback = 4;
		for (let i = 0; i < 2500 && normal.phase === 'Flying'; i++) coreUpdate(normal, 1 / 60, level);
		for (let i = 0; i < 2500 && fast.phase === 'Flying'; i++) coreUpdate(fast, 1 / 120, level);
		check(prefix + 'natural-end-success', normal.phase === 'Result' && normal.missionCompleted && normal.result === 'success');
		check(prefix + 'speed-deterministic', fast.result === normal.result && fast.flightTime === normal.flightTime && distance(fast.flight!.state.pos, normal.flight!.state.pos) === 0);
		check(prefix + 'view-six-seconds-or-natural-end', analysis.viewEndIndex === Math.min(flight.points.length - 1, core.goalIndex + 375));
		let at30 = 0, at120 = 0;
		for (let i = 0; i < 450; i++) at30 = advanceTransferPlayback(at30, 1 / 30, 1, normal.burnDuration, tr, analysis, dt);
		for (let i = 0; i < 1800; i++) at120 = advanceTransferPlayback(at120, 1 / 120, 1, normal.burnDuration, tr, analysis, dt);
		check(prefix + 'fps-independent', Math.abs(at30 - at120) < 1e-8);
		for (let i = 0; i < analysis.encounters!.length; i++) check(prefix + 'encounter-shot-' + i.toFixed(0), orbitalShotAt(analysis.encounters![i].periapsisIndex * dt, normal.burnDuration, analysis, cfg, dt) === cfg.encounters[i].focus);
		check(prefix + 'one-completion-record', evaluateRocketsDetailed(lv, 'success', plan.dv, { starsCollected: 3 }).rockets === 1);
		const crash = createCore(dt); coreLaunch(crash, { x: 0, y: 0 }, level, { x: 0, y: 0 }, { x: 0, y: 0 }); coreUpdate(crash, 1, level);
		check(prefix + 'early-collision-fails', crash.result === 'crashed' && !crash.missionCompleted);
		coreRetry(core, 0); check(prefix + 'retry-reset', !core.missionCompleted && core.flyby === undefined && core.phase === 'Aiming');
	}
	return (failures.length === 0 ? 'passed' : 'failed') + '\nchecks=' + checks.toFixed(0) + ' failures=' + failures.length.toFixed(0) + (failures.length > 0 ? '\n' + failures.join('\n') : '');
}
