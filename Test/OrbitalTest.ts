/** 日心任务的借力证据、顺序、目标方向与实际完成时序。 */
import { Content, json } from 'Dora';
import { bodyPositionAt, distance, simulate } from 'game/Gravity';
import { getLevel, goalPositionAt, installArcadeLevels, findGoalIndex, evaluateRocketsDetailed } from 'game/LevelData';
import { analyzeOrbitalMission, advanceTransferPlayback, orbitalShotAt, planTransfer } from 'game/Transfer';
import { convertLevelJson, BodiesConfigJson, LevelsConfigJson } from 'game/LevelLoader';
import { GameLevel, createCore, coreLaunch, coreUpdate, coreEndViewing, coreRetry } from 'game/Game';
import { isSunVisual } from 'game/Scene';

export function runTests(): string {
	let checks = 0;
	const failures: string[] = [];
	const check = (name: string, ok: boolean): void => { checks++; if (!ok) failures.push(name); };
	installArcadeLevels(Content.load('Assets/Levels/levels.json'), Content.load('Assets/Levels/bodies.json'), (s: string): unknown => json.decode(s)[0]);
	const dt = 0.016;
	const table = json.decode(Content.load('Assets/Levels/bodies.json'))[0] as BodiesConfigJson;
	const configs = json.decode(Content.load('Assets/Levels/levels.json'))[0] as LevelsConfigJson;
	const baseSunRadius = table.bodies.sun.radius, baseVenusRadius = table.bodies.venus.radius;
	const l2 = convertLevelJson(configs.levels[1], table)!;
	check('l2-body-overrides', l2.planets[0].radius === 72 && l2.planets[1].radius === 12 && l2.planets[2].radius === 6 && l2.planets[2].gm === 800);
	check('l2-model-collision-size', l2.visuals.every((v, i) => v.displayRadius === l2.planets[i].radius));
	check('shared-prototypes-unchanged', table.bodies.sun.radius === baseSunRadius && table.bodies.venus.radius === baseVenusRadius && getLevel(2)!.planets[0].radius === 72);
	check('exclusive-terminal-config', convertLevelJson({ ...configs.levels[1], transfer: { ...configs.levels[1].transfer!, orbital: { ...configs.levels[1].transfer!.orbital!, region: { minRadius: 150, maxRadius: 170, direction: 'inward' } } } }, table) === undefined);
	const missingTerminal = { ...configs.levels[2].transfer!.orbital! }; missingTerminal.region = undefined;
	check('missing-terminal-config', convertLevelJson({ ...configs.levels[2], transfer: { ...configs.levels[2].transfer!, orbital: missingTerminal } }, table) === undefined);
	check('invalid-destination-index', convertLevelJson({ ...configs.levels[1], transfer: { ...configs.levels[1].transfer!, orbital: { ...configs.levels[1].transfer!.orbital!, targetFlyby: { ...configs.levels[1].transfer!.orbital!.targetFlyby!, planetIndex: 9 } } } }, table) === undefined);

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
		const level: GameLevel = { levelId: n + 1, viewingSeconds: n === 1 ? 12 : 6, bonusPoints: lv.bonusPoints, bodies: lv.planets, probeStart: lv.probeStart, probeVel0: lv.probeVel0, goal: lv.goal, escapeRadius: lv.escapeRadius, maxSteps: lv.maxSteps, transfer: tr };
		const launchAt = (date: number, p: number) => {
			const core = createCore(dt), start = stateAt(date);
			const plan = planTransfer(mu, r, start.vel, p, tr.apoapsisMax, tr.mode, tr.periapsisMin);
			core.t0 = date; coreLaunch(core, plan.velocity, level, start.pos, start.vel); core.playback = 1;
			return core;
		};
		const core = launchAt(1, power), flight = core.flight!, analysis = core.flyby!;
		const prefix = 'L' + (n + 1).toFixed(0) + '-';
		check(prefix + 'sun-center', mu === 800000 && lv.planets[0].radius === 72 && lv.planets[0].orbitRadius === 0);
		check(prefix + 'only-real-bodies', lv.planets.length === 3 && lv.stars!.length === 0 && lv.planets.every(b => b.gm > 0 && !b.isObstacle));
		if (n === 1) {
			const body = lv.planets[2], point = goalPositionAt(body, 1, lv.goal.offset);
			check(prefix + 'mercury-guidance', lv.goal.marker === undefined && lv.goal.planetIndex === 2 && lv.goal.tolerance === 6 && Math.abs(distance(point, bodyPositionAt(body, 1)) - 14) < 1e-8);
			check(prefix + 'marker-safe-gap', distance(point, bodyPositionAt(body, 1)) - lv.goal.tolerance > body.radius);
		} else {
			check(prefix + 'marker-independent', lv.goal.marker !== undefined && lv.goal.marker.gm === 0 && lv.planets.indexOf(lv.goal.marker) < 0);
			check(prefix + 'marker-guidance-only', findGoalIndex([bodyPositionAt(lv.goal.marker!, 0)], lv.planets, lv.goal, dt) < 0);
		}
		check(prefix + 'sun-emissive', lv.visuals[0].emissive !== undefined && lv.visuals[0].emissive!.r === 1);
		check(prefix + 'baseline-success', core.goalIndex > 0 && analysis.encounters!.every(e => e.passed));
		check(prefix + 'short-burn', core.burnDuration > 0.29 && core.burnDuration < 0.31);
		check(prefix + 'not-precompleted', !core.missionCompleted && !coreEndViewing(core));
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
		if (cfg.targetFlyby !== undefined) {
			const dest = analysis.destination!;
			check(prefix + 'complete-mercury-flyby', dest.passed && dest.entryIndex > analysis.encounters![0].exitIndex && dest.periapsisIndex > dest.entryIndex && dest.exitIndex > dest.periapsisIndex && core.goalIndex >= dest.entryIndex && core.goalIndex < dest.exitIndex && dest.periapsis >= 12 && dest.periapsis <= 28);
			check(prefix + 'mercury-small-planning-drift', distance(flight.points[dest.periapsisIndex], ref.points[dest.periapsisIndex]) < 5);
			const truncated = { ...flight, points: flight.points.slice(0, dest.exitIndex), velocities: flight.velocities.slice(0, dest.exitIndex) };
			check(prefix + 'entry-peri-without-exit-fails', analyzeOrbitalMission(truncated, lv.planets, cfg, dt, 1).completionIndex < 0);
			check(prefix + 'unsafe-mercury-fails', analyzeOrbitalMission(flight, lv.planets, { ...cfg, targetFlyby: { ...cfg.targetFlyby, minPeriapsis: 25 } }, dt, 1).completionIndex < 0);
			check(prefix + 'missed-mercury-fails', analyzeOrbitalMission(flight, lv.planets, { ...cfg, targetFlyby: { ...cfg.targetFlyby, maxPeriapsis: 12 } }, dt, 1).completionIndex < 0);
			const missed = launchAt(1, 0.9);
			const oldBand = { ...cfg }; oldBand.targetFlyby = undefined; oldBand.region = { minRadius: 150, maxRadius: 170, direction: 'inward' };
			check(prefix + 'old-band-alone-insufficient', missed.goalIndex < 0 && analyzeOrbitalMission(missed.flight!, lv.planets, oldBand, dt, 1).completionIndex >= 0);
			check(prefix + 'mercury-camera', orbitalShotAt(dest.periapsisIndex * dt, core.burnDuration, analysis, cfg, dt) === 'Mercury');
			check(prefix + 'between-planets-cruise', orbitalShotAt((analysis.encounters![0].exitIndex + 1) * dt, core.burnDuration, analysis, cfg, dt) === 'Cruise');
		} else {
			const reverse = analyzeOrbitalMission(flight, lv.planets, { ...cfg, region: { ...cfg.region!, direction: 'inward' } }, dt, 1);
			check(prefix + 'target-direction-required', reverse.completionIndex < 0);
			check(prefix + 'order-required', analyzeOrbitalMission(flight, lv.planets, { ...cfg, encounters: [cfg.encounters[1], cfg.encounters[0]] }, dt, 1).completionIndex < 0);
		}
		const lowPower = launchAt(1, 0.04);
		check(prefix + (n === 1 ? 'low-power-fails' : 'low-power-escape-allowed'), n === 1 ? lowPower.goalIndex < 0 : lowPower.goalIndex >= 0);
		check(prefix + 'wrong-date-fails', launchAt(10, power).goalIndex < 0);
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
		check(prefix + 'viewing-bounded', normal.flightTime > core.goalIndex * dt && normal.flightTime <= (core.goalIndex + Math.floor(level.viewingSeconds! / dt)) * dt);
		let at30 = 0, at120 = 0;
		for (let i = 0; i < 450; i++) at30 = advanceTransferPlayback(at30, 1 / 30, 1, normal.burnDuration, tr, analysis, dt);
		for (let i = 0; i < 1800; i++) at120 = advanceTransferPlayback(at120, 1 / 120, 1, normal.burnDuration, tr, analysis, dt);
		check(prefix + 'fps-independent', Math.abs(at30 - at120) < 1e-8);
		for (let i = 0; i < analysis.encounters!.length; i++) check(prefix + 'encounter-shot-' + i.toFixed(0), orbitalShotAt(analysis.encounters![i].periapsisIndex * dt, normal.burnDuration, analysis, cfg, dt) === cfg.encounters[i].focus);
		check(prefix + 'one-completion-record', evaluateRocketsDetailed(lv, 'success', plan.dv, { starsCollected: 3 }).rockets === 1);
		for (let i = 0; i < lv.planets.length; i++) {
			const crash = createCore(dt); coreLaunch(crash, { x: 0, y: 0 }, level, bodyPositionAt(lv.planets[i], 0), { x: 0, y: 0 }); coreUpdate(crash, 1, level);
			check(prefix + 'early-collision-fails-' + i.toFixed(0), crash.result === 'crashed' && !crash.missionCompleted);
		}
		coreRetry(core, 0); check(prefix + 'retry-reset', !core.missionCompleted && core.flyby === undefined && core.phase === 'Aiming');
	}
	return (failures.length === 0 ? 'passed' : 'failed') + '\nchecks=' + checks.toFixed(0) + ' failures=' + failures.length.toFixed(0) + (failures.length > 0 ? '\n' + failures.join('\n') : '');
}
