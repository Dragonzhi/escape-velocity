#!/usr/bin/env node
/**
 * 时间窗设计器（开发工具，不进游戏运行时）。
 *
 * 为什么要有它：六关现在**都有时间轴**，而「日期必须真的有用」是硬门
 * （Test/LevelDataTest.ts 的 lvN-window-matters：峰值 ≥ 3 解，且要么存在**零解的日期**，
 * 要么第 0 天的解数不到峰值的一半）。可窗口的形状（在哪、多宽）不是随便调的 ——
 * 它由「容差 / 节点数 / 行星之间的相对角速度」三件事共同决定。
 *
 * ==== 关键事实：相位与日期是同一个自由度 ====
 * bodyPositionAt(b,t) = phase0 + ω·t，所以把**每颗行星**的 phase0 一起减去 ω·δ，
 * 等价于把整条可行日期带平移 δ 秒（不需要重解相位）。于是「把最好的日期放到第 150 秒」
 * 这件事只要扫一遍 δ 就能做到 —— 本工具就是干这个的，输出 24 档每档的成功数。
 *
 * 用法：
 *   node tools/level-window.mjs 4                          # 当前相位下的窗口形状
 *   node tools/level-window.mjs 4 --shifts -200,-100,0,100 # 试算把窗口平移这些秒数
 *   node tools/level-window.mjs 4 --tol 18,30,45           # 试算改**航点容差**（按 chain 顺序）
 *   node tools/level-window.mjs 4 --dv 45                  # 试算改 Δv 预算
 *   node tools/level-window.mjs 4 --span 400               # 试算改时间轴跨度
 */
import { execFileSync } from "node:child_process";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import Module from "node:module";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const argv = process.argv.slice(2);
function opt(name, dflt) {
	const i = argv.indexOf("--" + name);
	if (i < 0) return dflt;
	if (argv[i + 1] === undefined || argv[i + 1].startsWith("--")) return true;
	return argv[i + 1];
}
const levelArg = Number(argv[0]);
if (!Number.isFinite(levelArg) || levelArg < 1) {
	console.log("用法：node tools/level-window.mjs <关卡号 1-6> [--shifts a,b,c] [--tol a,b,c] [--dv N] [--span N]");
	process.exit(0);
}

// --- 用仓库自带的 tsc 把三个纯模块编成 CommonJS（与 level-sweep 同一套手法）---
const tsc = path.join(root, "tools", "dora-build", "node_modules", "typescript", "bin", "tsc");
const outDir = mkdtempSync(path.join(tmpdir(), "ev-window-"));
execFileSync(process.execPath, [tsc, "--module", "commonjs", "--target", "es2020", "--moduleResolution", "node",
	"--baseUrl", root, "--skipLibCheck", "--outDir", outDir,
	...["Config", "Gravity", "LevelData"].map((n) => path.join(root, "game", n + ".ts"))],
	{ cwd: root, stdio: ["ignore", "ignore", "pipe"] });
const origResolve = Module._resolveFilename;
Module._resolveFilename = function (request, ...rest) {
	if (typeof request === "string" && request.startsWith("game/")) request = path.join(outDir, request.slice(5) + ".js");
	return origResolve.call(this, request, ...rest);
};
const require2 = createRequire(import.meta.url);
const LD = require2(path.join(outDir, "LevelData.js"));
const { simulate } = require2(path.join(outDir, "Gravity.js"));
const { PhysicsStep, AimMinSpeed, AimMaxSpeed } = require2(path.join(outDir, "Config.js"));

let lv = LD.getLevel(levelArg - 1);
if (lv === undefined) { console.log("没有第 " + levelArg + " 关"); process.exit(1); }
const tolArg = opt("tol", null);
if (tolArg !== null) {
	const tol = String(tolArg).split(",").map(Number);
	lv = JSON.parse(JSON.stringify(lv));
	const wps = LD.goalWaypoints(lv.goal);
	for (let i = 0; i < wps.length && i < tol.length; i++) wps[i].tolerance = tol[i];
	lv.goal.tolerance = tol[tol.length - 1];
}
if (opt("dv", null) !== null) { lv = JSON.parse(JSON.stringify(lv)); lv.dvBudget = Number(opt("dv", null)); }
if (opt("span", null) !== null) { lv = JSON.parse(JSON.stringify(lv)); lv.timeWindow = { span: Number(opt("span", null)) }; }

const dvTop = lv.dvBudget !== undefined && lv.dvBudget < AimMaxSpeed ? lv.dvBudget : AimMaxSpeed;
const powers = [0.35, 0.6, 0.85, 1.0];
const sampleEvery = 4;
const t0Samples = 24;
const dirCount = 12;

/** resolveResult 的镜像（与 level-sweep.mjs / game/Game.ts 同一套判据）。 */
function resolveResult(outcome, goalIndex, goal) {
	if (goal.kind === "escape") {
		const wps = goal.chain !== undefined ? goal.chain : [];
		if (outcome === "escaped" && (wps.length === 0 || goalIndex >= 0)) return "success";
	} else if (goalIndex >= 0) {
		return "success";
	}
	if (outcome === "crashed") return "crashed";
	return "missed";
}

/** 把每颗行星的 phase0 一起减 ω·δ（等价于整条日期带平移 δ 秒；卫星连宿主一起转）。
 * --only 只平移指定下标的天体（L1 用：地球一动，探测器的圆轨道就没了）。 */
const onlyArg = opt("only", null);
const onlyIdx = onlyArg === null ? null : String(onlyArg).split(",").map(Number);

function shiftBodies(bodies, delta, idx) {
	const out = [];
	for (let i = 0; i < bodies.length; i++) {
		const b = bodies[i];
		const nb = { ...b, orbitCenter: { x: b.orbitCenter.x, y: b.orbitCenter.y } };
		if (b.orbitPeriod > 0 && b.orbitRadius > 0 && (onlyIdx === null || onlyIdx.indexOf(idx === undefined ? i : idx) >= 0)) {
			nb.phase0 = b.phase0 - b.orbitDirection * (2 * Math.PI / b.orbitPeriod) * delta;
		}
		if (b.host !== undefined) nb.host = shiftBodies([b.host], delta, idx)[0];
		out.push(nb);
	}
	return out;
}
function shiftOld(bodies, delta) {
	const out = [];
	for (const b of bodies) {
		const nb = { ...b, orbitCenter: { x: b.orbitCenter.x, y: b.orbitCenter.y } };
		out.push(b);
	}
	return out;
}

function sweep(bodies, timeWindow) {
	const span = timeWindow !== undefined ? timeWindow.span : 0;
	const perT0 = [];
	let total = 0, ok = 0;
	for (let ti = 0; ti < t0Samples; ti++) {
		const t0 = (span * ti) / t0Samples;
		let hits = 0;
		for (let d = 0; d < dirCount; d++) {
			const angle = (d * 2 * Math.PI) / dirCount;
			for (const p of powers) {
				const speed = AimMinSpeed + (dvTop - AimMinSpeed) * p;
				const v0 = lv.probeVel0 !== undefined ? lv.probeVel0 : { x: 0, y: 0 };
				const vel = { x: Math.cos(angle) * speed + v0.x, y: Math.sin(angle) * speed + v0.y };
				const sim = simulate(
					{ pos: { x: lv.probeStart.x, y: lv.probeStart.y }, vel },
					bodies,
					{ steps: lv.maxSteps, dt: PhysicsStep, sampleEvery, escapeRadius: lv.escapeRadius, t0 },
				);
				const gi = LD.findGoalIndex(sim.points, bodies, lv.goal, PhysicsStep * sampleEvery, t0, sim.velocities);
				total += 1;
				if (resolveResult(sim.outcome, gi, lv.goal) === "success") { ok += 1; hits += 1; }
			}
		}
		perT0.push(hits);
	}
	return { perT0, ok, total };
}

function verdict(perT0, ok) {
	let peak = 0, dead = 0;
	for (const h of perT0) { if (h > peak) peak = h; if (h === 0) dead += 1; }
	const matters = peak >= 3 && (dead >= 1 || perT0[0] * 2 <= peak);
	return "peak=" + peak + " day0=" + perT0[0] + " dead=" + dead + "/" + perT0.length +
		" total=" + ok + "/" + (perT0.length * 48) + (matters ? "  [window-matters PASS]" : "  [window-matters FAIL]");
}

const shifts = String(opt("shifts", "0")).split(",").map(Number);
const base = LD.scaledPlanets(lv);
console.log("L" + lv.id + " " + lv.title + "：span=" + (lv.timeWindow !== undefined ? lv.timeWindow.span : 0) +
	" dv=" + dvTop + " 容差=[" + LD.goalWaypoints(lv.goal).map((w) => w.tolerance.toFixed(0)).join(",") + "]" +
	" 航点=" + LD.goalWaypoints(lv.goal).map((w) => (w.label || w.planetIndex)).join("→"));
for (const d of shifts) {
	const r = sweep(shiftBodies(base, d), lv.timeWindow);
	const shape = r.perT0.map((h) => (h === 0 ? "." : String(Math.min(h, 9)))).join("");
	console.log("  shift=" + String(d).padStart(5) + "s  " + shape + "   " + verdict(r.perT0, r.ok));
}
