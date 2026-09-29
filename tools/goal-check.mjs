// 三关目标环与点位的 Node 数值门禁；调用与运行时相同的纯 TS 模块。
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url), ts = require('./dora-build/node_modules/typescript');
const root = path.resolve(import.meta.dirname, '..'), cache = new Map();
function load(name) {
  if (cache.has(name)) return cache.get(name);
  if (name === 'Dora') { const stub = { Content: { exist: () => false, load: () => '', save: () => {} }, Path: (...parts) => parts.join('/') }; cache.set(name, stub); return stub; }
  const out = {}; cache.set(name, out);
  const source = fs.readFileSync(path.join(root, name + '.ts'), 'utf8');
  new Function('require', 'exports', ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText)(load, out);
  return out;
}
const { convertLevelJson } = load('game/LevelLoader');
const { simulate, distance, bodyPositionAt } = load('game/Gravity');
const { findGoalIndex, goalPositionAt } = load('game/LevelData');
const { getMissionCompleted, getMissionRockets, recordMissionResult } = load('game/Progress');
const { planTransfer } = load('game/Transfer');
const data = JSON.parse(fs.readFileSync(path.join(root, 'Assets/Levels/levels.json'), 'utf8'));
const bodies = JSON.parse(fs.readFileSync(path.join(root, 'Assets/Levels/bodies.json'), 'utf8'));
const dt = 0.016; let failed = 0;
for (const json of data.levels) {
  const lv = convertLevelJson(json, bodies), tr = lv.transfer, mu = lv.planets[0].gm, r = json.probe.orbitRadius;
  const power = [0, 0.875, 11 / 14, 0.5][lv.id];
  const phase = json.probe.startAngleDeg * Math.PI / 180 + Math.sqrt(mu / r ** 3);
  const p = { x: r * Math.cos(phase), y: r * Math.sin(phase) };
  const speed = Math.sqrt(mu / r), v = { x: -Math.sin(phase) * speed, y: Math.cos(phase) * speed };
  const plan = planTransfer(mu, r, v, power, tr.apoapsisMax, tr.mode, tr.periapsisMin);
  const burn = plan.dv / tr.thrustAcceleration;
  const flight = simulate({ pos: p, vel: v }, lv.planets, { dt, steps: lv.maxSteps, sampleEvery: 1, escapeRadius: lv.escapeRadius, t0: 1,
    initialBurn: burn > 0 ? { duration: burn, acceleration: { x: plan.velocity.x / burn, y: plan.velocity.y / burn } } : undefined });
  const goalIndex = findGoalIndex(flight.points, lv.planets, lv.goal, dt, 1, flight.velocities);
  const instant = simulate({ pos: p, vel: { x: v.x + plan.velocity.x, y: v.y + plan.velocity.y } }, lv.planets, { dt, steps: lv.maxSteps, sampleEvery: 1, escapeRadius: lv.escapeRadius, t0: 1 });
  const instantIndex = findGoalIndex(instant.points, lv.planets, lv.goal, dt, 1, instant.velocities);
  const hit = [];
  for (let b = 0; b < lv.bonusPoints.length; b++) {
    const bonus = lv.bonusPoints[b], target = bonus.bodyIndex !== undefined ? lv.planets[bonus.bodyIndex] : bonus.orbit;
    let index = -1;
    for (let i = 0; i < flight.points.length; i++) if (distance(flight.points[i], goalPositionAt(target, 1 + i * dt, bonus.offset)) <= bonus.tolerance) { index = i; break; }
    hit.push({ id: bonus.id, index });
  }
  const ok = goalIndex > 0 && instantIndex > 0 && hit.every(x => x.index > 0);
  if (!ok) failed++;
  console.log(JSON.stringify({ level: lv.id, actualGoal: goalIndex, instantGoal: instantIndex, outcome: flight.outcome, bonus: hit, pass: ok }));
}
const cleared = recordMissionResult({ unlocked: 0 }, 0, 0, 3, true);
const scored = recordMissionResult(cleared, 0, 2, 3, true);
const failedRun = recordMissionResult(scored, 0, 3, 3, false);
const legacy = { unlocked: 2, rockets: { L1: 3, L2: 2 } };
const progressPass = getMissionCompleted(cleared, 0) && getMissionRockets(cleared, 0) === 0
  && getMissionRockets(scored, 0) === 2 && getMissionRockets(failedRun, 0) === 2
  && getMissionCompleted(legacy, 0) && getMissionCompleted(legacy, 1);
console.log(JSON.stringify({ progressPass, zeroScoreClear: getMissionCompleted(cleared, 0), failedRunBest: getMissionRockets(failedRun, 0), legacyComplete: [getMissionCompleted(legacy, 0), getMissionCompleted(legacy, 1)] }));
console.log('RESULT=' + (failed === 0 && progressPass ? 'PASS' : 'FAIL'));
if (failed !== 0 || !progressPass) process.exitCode = 1;
process.exitCode = failed ? 1 : 0;
