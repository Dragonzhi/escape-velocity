// 与引擎共享纯模块；数字试算不加载 Dora，也不写存档。
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const ts = require('./dora-build/node_modules/typescript');
const root = path.resolve(import.meta.dirname, '..');
const cache = new Map();
function load(name) {
  if (cache.has(name)) return cache.get(name);
  const exports = {}; cache.set(name, exports);
  const src = fs.readFileSync(path.join(root, name + '.ts'), 'utf8');
  const js = ts.transpileModule(src, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText;
  new Function('require', 'exports', js)(load, exports);
  return exports;
}
const { convertLevelJson } = load('game/LevelLoader');
const { simulate, distance } = load('game/Gravity');
const { analyzeOrbitalMission, planTransfer, advanceTransferPlayback } = load('game/Transfer');
const levels = JSON.parse(fs.readFileSync(path.join(root, 'Assets/Levels/levels.json'), 'utf8')).levels;
const bodies = JSON.parse(fs.readFileSync(path.join(root, 'Assets/Levels/bodies.json'), 'utf8'));
const dt = 0.016;
let failures = 0;
for (const json of levels.filter(l => l.id >= 2)) {
  const lv = convertLevelJson(json, bodies), tr = lv.transfer, cfg = tr.orbital;
  const r = json.probe.orbitRadius, mu = lv.planets[0].gm;
  function trial(date, power, instantaneous = false) {
    const a = json.probe.startAngleDeg * Math.PI / 180 + Math.sqrt(mu / r ** 3) * date;
    const speed = Math.sqrt(mu / r), vel = { x: -Math.sin(a) * speed, y: Math.cos(a) * speed };
    const pos = { x: r * Math.cos(a), y: r * Math.sin(a) };
    const plan = planTransfer(mu, r, vel, power, tr.apoapsisMax, tr.mode, tr.periapsisMin), burn = plan.dv / tr.thrustAcceleration;
    const flight = simulate({ pos, vel: instantaneous ? { x: vel.x + plan.velocity.x, y: vel.y + plan.velocity.y } : vel }, lv.planets, {
      dt, steps: lv.maxSteps, sampleEvery: 1, escapeRadius: lv.escapeRadius, t0: date,
      initialBurn: !instantaneous && burn > 0 ? { duration: burn, acceleration: { x: plan.velocity.x / burn, y: plan.velocity.y / burn } } : undefined,
    });
    return { flight, plan, burn, analysis: analyzeOrbitalMission(flight, lv.planets, cfg, dt, date) };
  }
  const power = lv.id === 2 ? 11 / 14 : 0.5;
  const actual = trial(1, power), ref = trial(1, power, true);
  const ci = actual.analysis.completionIndex;
  const now = distance(actual.flight.points[ci], { x: 0, y: 0 }), before = distance(actual.flight.points[ci - 1], { x: 0, y: 0 });
  if (!(cfg.region.direction === 'inward' ? before > cfg.region.maxRadius && now <= cfg.region.maxRadius : before < cfg.region.minRadius && now >= cfg.region.minRadius)) throw new Error('incorrect target crossing');
  let wall = 0, time = 0;
  while (time < actual.analysis.viewEndIndex * dt && wall < 60) { time = advanceTransferPlayback(time, 1 / 120, 1, actual.burn, tr, actual.analysis, dt); wall += 1 / 120; }
  const drift = actual.analysis.encounters.map(e => distance(actual.flight.points[e.periapsisIndex], ref.flight.points[e.periapsisIndex]));
  let successes = 0;
  for (let d = 0; d <= 20; d++) for (let p = -5; p <= 5; p++) if (trial(0.8 + d * 0.02, power + p * 0.01).analysis.completionIndex >= 0) successes++;
  const negative = [trial(1, 0.04), ...[0, 3, 5, 10].map(d => trial(d, power))].every(v => v.analysis.completionIndex < 0);
  const pass = actual.analysis.completionIndex >= 0 && ref.analysis.completionIndex >= 0 && negative && drift.every(v => v < 5);
  if (!pass) failures++;
  console.log(JSON.stringify({ level: lv.id, pass, dv: actual.plan.dv, burn: actual.burn, encounters: actual.analysis.encounters, completionTime: actual.analysis.completionIndex * dt, wallSeconds: wall, referenceDrift: drift, localGrid: successes + '/231', negative }));
}
console.log('RESULT=' + (failures === 0 ? 'PASS' : 'FAIL'));
process.exitCode = failures ? 1 : 0;
