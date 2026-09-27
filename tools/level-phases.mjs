#!/usr/bin/env node
/**
 * 相位设计器（开发工具，不进游戏运行时）。
 *
 * 为什么要有它：这一版的关卡是"**一条绕日弧线串起几颗行星**"。行星摆在哪个相位
 * (\`orbiter()\` 的第 4 个参数)决定了有没有可行解 —— 而这**不能靠手填**。
 *
 * 2026-09-26 的实际教训：L3/L4/L5 的相位原先是"照一条设计航线排的"（注释说 240° 方向、
 * Δv 35），可那条弧线**撞进太阳**（peakR 只有 80）—— 于是相位和任何真实航线都对不上，
 * 扫掠成功率被压到 0.2%~6%，玩家骂"关卡诡异、不知所云"。用本工具重解之后：
 *
 *   关卡           相位(旧→新)                细网格成功率
 *   L3 弹弓        195.5/198 → 89.4/89.0      8.6% → 42.5%
 *   L5 大巡游      195.5~216.4 → 89.5×4       0.2% → 17.5%
 *   L4 窗口        315.5/288 → 29.3/48.2      1.1% → 8.9%（且窗口真的会开合）
 *
 * ==== 原理 ====
 * 只留太阳做仿真（行星的引力置 0）⇒ 得到"一族弧线"，每条记下它**依次穿过每个航点环**
 * 的 (角度 θ, 时刻 t, 速度 v)。把航点 i 的行星摆成
 *
 *     phase0_i = θ_A,i − ω_i · (t_A,i + t0*)        ω_i = orbitDirection · 2π / orbitPeriod
 *
 * （= "让弧线 A 在第 t0* 秒正好撞上它"），那么另一条弧线 B 想在第 i 站被接受就要
 * \`r_i · angdiff(θ_B,i, phase0_i + ω_i·t_B,i) ≤ tol_i\`（+ 捕获站还要满足相对速度阈值）。
 * 于是"有多少条弧线能走通" = **这一关有多少条路线**，正是设计稿第五章要的"多条路线"。
 * 最后对 phase0 做局部爬坡，取路线数最多的那一组。
 *
 * ⚠️ 这是**解析近似**（忽略行星引力与星球半径遮挡），只用来**产生相位**；
 *    权威判定仍然是 \`tools/level-sweep.mjs\`（真实物理）与引擎内的 \`Test/UnitRunner\`。
 *    标准流程：本工具出相位 → 写进 game/LevelData.ts → \`level-sweep\` 复扫 → 引擎验收。
 *
 * 用法：
 *   node tools/level-phases.mjs 5                    # 解 L5：最佳相位 + 有多少条路线
 *   node tools/level-phases.mjs 4 --t0 180           # 解"第 180 秒才对齐"的相位（L4/L6 用）
 *   node tools/level-phases.mjs 5 --tol 40,50,60,70  # 试算把容差放宽到这套值的效果
 *   node tools/level-phases.mjs 6 --nocapture --json .agent/tmp/l6.json   # 导出候选给 level-sweep --file
 */
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
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
	console.log("用法：node tools/level-phases.mjs <关卡号 1-6> [--dirs N] [--dvs N] [--tol a,b,c] [--nocapture] [--t0 N] [--json out.json]");
	process.exit(0);
}
const dirCount = Number(opt("dirs", "360"));
const dvCount = Number(opt("dvs", "41"));
const t0Target = Number(opt("t0", "0"));
const noCapture = opt("nocapture", false) !== false;
const tolArg = opt("tol", null);
const jsonOut = opt("json", null);

// --- 1) 用仓库自带的 tsc 把三个纯模块编成 CommonJS（与 level-sweep 同一套手法）---
const tsc = path.join(root, "tools", "dora-build", "node_modules", "typescript", "bin", "tsc");
const outDir = mkdtempSync(path.join(tmpdir(), "ev-phases-"));
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
const TN = require2(path.join(outDir, "Tuning.js"));

const TAU = Math.PI * 2;
const angDiff = (a, b) => { let d = (a - b) % TAU; if (d > Math.PI) d -= TAU; if (d < -Math.PI) d += TAU; return d; };
const deg = (r) => ((r * 180) / Math.PI + 360) % 360;

const lv = LD.getLevel(levelArg - 1);
if (lv === undefined) { console.log("没有第 " + levelArg + " 关"); process.exit(1); }
const bodies = LD.scaledPlanets(lv);
const wps = LD.goalWaypoints(lv.goal);
if (wps.length === 0) { console.log("这一关没有航点（纯逃逸关），不需要相位"); process.exit(0); }
const rings = wps.map((w, i) => {
	const b = bodies[w.planetIndex];
	// ⚠️ 判据必须同时看 orbitCenter：L1 的月球绕的是**地球**（orbitRadius 100 但圆心不是原点），
	// 只判 orbitRadius > 0 会把它当成"绕日行星"去解相位 —— 算出来的东西毫无意义。
	if (b.orbitRadius <= 0 || b.orbitCenter.x !== 0 || b.orbitCenter.y !== 0) {
		console.log("航点 " + (w.label || i) + " 不是**绕原点的**行星（它绕的是别的天体），相位求解器不适用");
		process.exit(0);
	}
	return {
		wp: w, body: b, or: b.orbitRadius,
		tol: tolArg !== null ? Number(String(tolArg).split(",")[i]) : w.tolerance,
		omega: (b.orbitDirection * TAU) / b.orbitPeriod,
		capture: noCapture ? false : w.capture === true,
	};
});
const dvTop = lv.dvBudget !== undefined && lv.dvBudget < AimMaxSpeed ? lv.dvBudget : AimMaxSpeed;
const every = 4;

// --- 2) 采样弧线：只留太阳（行星引力置 0），记下每条弧线穿过每个环的 (θ,t,v) ---
//
// ⚠️ S5 起两处关键改动：
//   ① 初速必须叠加 `probeVel0`（六关都从日心共轨圆轨道出发，不再是静止）；
//   ② 设计搜索用**粗步长**（默认 1/20）。这是解析近似，只用来产生相位；
//      权威判定仍然是 tools/level-sweep.mjs（真实步长）与引擎内的 Test/UnitRunner。
//      不这么做的话：L6 一次采样是 70000 步 × 14760 条 ≈ 10 亿步，跑不完。
const dtSearch = Number(opt("dt", String(1 / 20)));
const tMax = Number(opt("tmax", "0"));
const stepsSearch = tMax > 0 ? Math.ceil(tMax / dtSearch) : lv.maxSteps;
const v0 = lv.probeVel0 || { x: 0, y: 0 };
console.log("设计搜索：dt=" + dtSearch.toFixed(4) + " steps=" + stepsSearch + "（覆盖 " +
	(stepsSearch * dtSearch).toFixed(1) + " 秒）  dirs=" + dirCount + " dvs=" + dvCount +
	"  初速=(" + v0.x.toFixed(3) + ", " + v0.y.toFixed(3) + ")");
const onlySun = bodies.map((b) => (b.orbitRadius > 0 ? { ...b, gm: 0 } : b));
const samples = [];
for (let d = 0; d < dirCount; d++) {
	const dirDeg = (d * 360) / dirCount;
	const a = (dirDeg * Math.PI) / 180;
	for (let k = 0; k < dvCount; k++) {
		const dv = AimMinSpeed + (dvTop - AimMinSpeed) * (dvCount === 1 ? 1 : k / (dvCount - 1));
		const sim = simulate(
			{ pos: { x: lv.probeStart.x, y: lv.probeStart.y }, vel: { x: v0.x + Math.cos(a) * dv, y: v0.y + Math.sin(a) * dv } },
			onlySun,
			{ steps: stepsSearch, dt: dtSearch, sampleEvery: every, escapeRadius: lv.escapeRadius, t0: 0 },
		);
		const cross = [];
		let next = 0;
		for (let i = 1; i < sim.points.length && next < rings.length; i++) {
			const r0 = Math.hypot(sim.points[i - 1].x, sim.points[i - 1].y);
			const r1 = Math.hypot(sim.points[i].x, sim.points[i].y);
			if (r0 < rings[next].or && r1 >= rings[next].or) {
				const f = (rings[next].or - r0) / (r1 - r0);
				const px = sim.points[i - 1].x + (sim.points[i].x - sim.points[i - 1].x) * f;
				const py = sim.points[i - 1].y + (sim.points[i].y - sim.points[i - 1].y) * f;
				cross.push({
					angle: Math.atan2(py, px),
					t: (i - 1 + f) * every * dtSearch,
					speed: Math.hypot(sim.velocities[i].x, sim.velocities[i].y),
				});
				next++;
			}
		}
		if (cross.length === rings.length) samples.push({ dirDeg, dv, cross });
	}
}
console.log("L" + lv.id + " " + lv.title + "：采样 " + dirCount + "×" + dvCount + " 条弧线，其中 " +
	samples.length + " 条能**依次**穿过全部 " + rings.length + " 个环" +
	"（环 " + rings.map((r) => r.or).join("/") + "，容差 " + rings.map((r) => r.tol.toFixed(0)).join("/") +
	(rings.some((r) => r.capture) ? "，含捕获站" : "") + "）");
if (samples.length === 0) { console.log("没有任何弧线能穿过全部环 ⇒ 这一关的几何根本不通"); process.exit(1); }

/**
 * 给定各组 phase0（弧度）+ **发射日期**，有几条弧线能走通。
 *
 * ⚠️ 发射日期的口径很容易错：本工具的弧线一律以 t0=0 积出来，所以"第 t0* 秒发射"这件事
 * 必须体现在**行星那一侧**（`omega·(t + t0*)`），不能去改弧线。
 */
function scoreAt(phi, t0Launch) {
	let n = 0;
	for (const s of samples) {
		let ok = true;
		for (let i = 0; i < rings.length; i++) {
			const R = rings[i], c = s.cross[i];
			if (Math.abs(angDiff(c.angle, phi[i] + R.omega * (c.t + t0Launch))) * R.or > R.tol) { ok = false; break; }
			if (i === rings.length - 1 && R.capture) {
				const vp = R.body.orbitRadius * Math.abs(R.omega);
				if (Math.abs(c.speed - vp) > Math.sqrt((2 * R.body.gm) / R.tol)) { ok = false; break; }
			}
		}
		if (ok) n++;
	}
	return n;
}
/** 设计搜索用的分数：φ 本身就定义在 t0=0 那一帧。 */
function score(phi) { return scoreAt(phi, 0); }
/** "第 t0 秒才对齐"的相位：phase0_i = θ_A,i − ω_i·(t_A,i + t0)。 */
const phasesOf = (A, t0) => rings.map((R, i) => A.cross[i].angle - R.omega * (A.cross[i].t + t0));

// 现状对照：直接拿关卡数据里**当前**的 phase0 算一遍 —— 改前/改后的差别一眼看得出
// （这正是"相位排错了"最容易被忽略的地方：数据看着像回事，分数却低得离谱）
const curPhi = rings.map((R) => R.body.phase0);
console.log("现状 phase0 = " + curPhi.map((p) => deg(p).toFixed(1) + "°").join(" / ") +
	"  ⇒ 在发射日期 " + t0Target + "s 上可行路线 " + scoreAt(curPhi, t0Target) + " / " + samples.length +
	"，在日期 0s 上 " + scoreAt(curPhi, 0) + " / " + samples.length);

let best = null;
for (const A of samples) {
	const phi = phasesOf(A, t0Target);
	const sc = score(phi);
	if (best === null || sc > best.sc) best = { sc, phi, A };
}
// 局部爬坡（每个 phase 在 ±3° 内小步走）
let cur = best.sc;
let phi = best.phi.slice();
for (let pass = 0; pass < 6; pass++) {
	let improved = false;
	for (let i = 0; i < phi.length; i++) {
		for (const stepDeg of [3, 1.5, 0.75, 0.3]) {
			for (const sgn of [1, -1]) {
				const cand = phi.slice();
				cand[i] += (sgn * stepDeg * Math.PI) / 180;
				const sc = score(cand);
				if (sc > cur) { cur = sc; phi = cand; improved = true; }
			}
		}
	}
	if (!improved) break;
}
console.log("最佳设计航线：点火方向 " + best.A.dirDeg.toFixed(1) + "°、Δv " + best.A.dv.toFixed(1) +
	"（预算 " + dvTop + "）  穿环时刻 " + best.A.cross.map((c) => c.t.toFixed(1) + "s").join(" / ") +
	"  穿环速度 " + best.A.cross.map((c) => c.speed.toFixed(1)).join(" / "));
console.log("可行路线 " + cur + " / " + samples.length + " = " + ((cur / samples.length) * 100).toFixed(1) + "%" +
	"（占全部采样 " + ((cur / (dirCount * dvCount)) * 100).toFixed(1) + "%）");
console.log("建议 phase0（写进 game/LevelData.ts 的 orbiter 第 4 个参数，单位：度）：");
for (let i = 0; i < rings.length; i++) {
	console.log("  " + ((rings[i].wp.label || ("天体" + rings[i].wp.planetIndex)) + "        ").slice(0, 8) +
		" orbitRadius=" + rings[i].or + "  容差=" + rings[i].tol.toFixed(1) +
		(rings[i].capture ? "  [捕获]" : "") + "  ==>  phase0 = " + deg(phi[i]).toFixed(1) + "°");
}
const okList = samples.filter((s) => score([s.cross[0].angle - rings[0].omega * s.cross[0].t]) >= 0 && (() => {
	for (let i = 0; i < rings.length; i++) {
		const R = rings[i], c = s.cross[i];
		if (Math.abs(angDiff(c.angle, phi[i] + R.omega * c.t)) * R.or > R.tol) return false;
		if (i === rings.length - 1 && R.capture && Math.abs(c.speed - R.body.orbitRadius * Math.abs(R.omega)) > Math.sqrt((2 * R.body.gm) / R.tol)) return false;
	}
	return true;
})());
if (okList.length > 0) {
	const dirs = okList.map((s) => s.dirDeg);
	const dvs = okList.map((s) => s.dv);
	const uniq = new Set(dirs.map((x) => Math.round(x)));
	console.log("可行方向 " + Math.min(...dirs).toFixed(0) + "°–" + Math.max(...dirs).toFixed(0) + "°（" + uniq.size + " 个方向档）" +
		"、Δv " + Math.min(...dvs).toFixed(1) + "–" + Math.max(...dvs).toFixed(1));
}
if (jsonOut !== null) {
	const cand = JSON.parse(JSON.stringify(lv));
	cand.title = lv.title + "(phases)";
	cand.timeWindow = t0Target > 0 ? { span: Math.max(300, t0Target * 2) } : lv.timeWindow;
	for (let i = 0; i < rings.length; i++) cand.planets[rings[i].wp.planetIndex].phase0 = phi[i];
	writeFileSync(String(jsonOut), JSON.stringify([cand]));
	console.log("[json] " + jsonOut + "（可直接 node tools/level-sweep.mjs --file " + jsonOut + "）");
}
