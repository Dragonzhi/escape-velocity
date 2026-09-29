/** 在 Node 中执行仓库的纯 TS 模块；不写编译产物，不依赖引擎。 */
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const ts = require('./dora-build/node_modules/typescript');
const root = path.resolve(import.meta.dirname, '..');
const cache = new Map();
function load(name) {
  if (cache.has(name)) return cache.get(name);
  const exports = {};
  cache.set(name, exports);
  const source = fs.readFileSync(path.join(root, name + '.ts'), 'utf8');
  const code = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText;
  new Function('require', 'exports', code)(load, exports);
  return exports;
}
const { simulate, bodyPositionAt, distance } = load('game/Gravity');
const { convertLevelJson } = load('game/LevelLoader');
const { findGoalIndex, goalPositionAt } = load('game/LevelData');
const { planTransfer, analyzeFlyby } = load('game/Transfer');
const table = JSON.parse(fs.readFileSync(path.join(root, 'Assets/Levels/bodies.json')));
const json = JSON.parse(fs.readFileSync(path.join(root, 'Assets/Levels/levels.json'))).levels[0];
const dt = 0.016;
function run(power, phase, t0 = 1) {
  const copy = structuredClone(json);
  copy.orbiters[0].angleDeg = phase;
  const level = convertLevelJson(copy, table);
  const r = json.probe.orbitRadius, mu = level.planets[0].gm;
  const angle = json.probe.startAngleDeg * Math.PI / 180 + Math.sqrt(mu / (r*r*r)) * t0;
  const p0 = { x: r*Math.cos(angle), y:r*Math.sin(angle) };
  const speed = Math.sqrt(mu/r);
  const v0 = {x:-Math.sin(angle)*speed,y:Math.cos(angle)*speed};
  const plan = planTransfer(mu,r,v0,power,level.transfer.apoapsisMax);
  const duration = plan.dv / level.transfer.thrustAcceleration;
  const opts = {dt, steps:level.maxSteps,sampleEvery:1,escapeRadius:level.escapeRadius,t0};
  const ref = simulate({pos:p0,vel:{x:v0.x+plan.velocity.x,y:v0.y+plan.velocity.y}},level.planets,opts);
  const flight = simulate({pos:p0,vel:v0},level.planets,{...opts,initialBurn:{duration,acceleration:{x:plan.velocity.x/duration,y:plan.velocity.y/duration}}});
  const gi = findGoalIndex(flight.points,level.planets,level.goal,dt,t0);
  const analysis=analyzeFlyby(flight,level.planets[0],level.planets[1],level.transfer.flyby,dt,t0);
  const reference=analyzeFlyby(ref,level.planets[0],level.planets[1],level.transfer.flyby,dt,t0);
  const index=analysis.periapsisIndex;
  const at=index>=0?index:0;
  const end=analysis.viewEndIndex*dt;
  const slowStart=Math.max(duration,index*dt-level.transfer.flyby.slowWindow);
  const slowEnd=Math.min(end,index*dt+level.transfer.flyby.slowWindow);
  const slow=index>=0?Math.max(0,slowEnd-slowStart):0;
  return {power,phase,t0,dv:plan.dv,apoapsis:plan.apoapsis,burnSeconds:duration,success:analysis.completionIndex>=0,
    lightSeconds:gi>=0?gi*dt:null,completionSeconds:analysis.completionIndex>=0?analysis.completionIndex*dt:null,
    endSeconds:end,periapsisSeconds:index*dt,periapsis:analysis.periapsis,energyDrop:analysis.energyDrop,
    referenceSuccess:reference.completionIndex>=0,referencePeriapsis:reference.periapsis,
    referenceDrift:distance(ref.points[Math.min(at,ref.points.length-1)],flight.points[at]),
    outcome:flight.outcome,viewSeconds:duration+slow+(end-duration-slow)/level.transfer.coastPlayback};
}
const nominalPower=0.875;
if(process.argv.includes('--solve')) {
  let best;
  for(let phase=0;phase<360;phase+=1) {
    const value=run(nominalPower,phase);
    if(value.success && (!best || Math.abs(value.periapsis-55)<Math.abs(best.periapsis-55)))best=value;
  }
  console.log('BEST',JSON.stringify(best));
} else {
  const phase=json.orbiters[0].angleDeg;
  const nominal=run(nominalPower,phase);
  console.log('NOMINAL',JSON.stringify(nominal));
  let successes=0;
  let samples=0;
  for(let p=0.65;p<=1.001;p+=0.025)for(let t=0;t<=2.001;t+=0.05){samples++;if(run(p,phase,t).success)successes++;}
  console.log('WINDOW',JSON.stringify({samples,successes,lowPower:run(0.05,phase).success,wrongTime:run(nominalPower,phase,1.8).success}));
  if(!nominal.success || !nominal.referenceSuccess || nominal.referenceDrift>20 || nominal.viewSeconds<12 || nominal.viewSeconds>18 || nominal.endSeconds<=nominal.completionSeconds || run(0.05,phase).success || run(nominalPower,phase,1.8).success)process.exitCode=1;
}
