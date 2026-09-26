#!/usr/bin/env node
/**
 * 关卡数值扫掠（开发工具，不进游戏运行时）。
 *
 * 为什么要有它：`Test/LevelDataTest.ts` 的「每关至少一个可行解」是硬门，但它在**引擎内**跑
 * （改数 → 构建 → 引擎内跑 ≈ 半分钟）。调六关数值要试几十组，用引擎跑太慢。本工具用仓库自带的
 * tsc 把三个纯模块（Config / Gravity / LevelData）编成 CommonJS 到临时目录，在 Node 里按
 * **同一份数据、同一套公式**扫掠，秒级出结果。
 *
 * ⚠️ 唯一一处刻意的重复：`resolveResult`（在 game/Game.ts，那里 import 了 Dora，Node 跑不了）。
 * 它是 5 行纯函数，这里照抄一份；**权威判定仍然是引擎内的 UnitRunner**（本工具只负责快速收敛）。
 *
 * 用法：
 *   node tools/level-sweep.mjs                     # 仓库六关，12 方向 × 4 档力度（= 测试网格）
 *   node tools/level-sweep.mjs --grid 24x6         # 更密的网格（粗网格找不到解时用）
 *   node tools/level-sweep.mjs --level 4           # 只看第 4 关
 *   node tools/level-sweep.mjs --file cand.json    # 扫**候选关卡**（JSON 数组，字段同 LevelDef）
 *   node tools/level-sweep.mjs --detail            # 打印全部可行解（要抄进关卡数据时用）
 *   node tools/level-sweep.mjs --json out.json     # 导出逐样本结果
 *
 * 判据同测试：能达成 goal（success）即算可行解。经验值：成功率 ≥1% 且 ≥3 个样本才算宽容；
 * 只有一个孤立解 = 玩家会骂人。timeWindow 关额外打印每个 t0 档的成功数（`.` = 该时机无解）。
 */
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
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
const gridRaw = String(opt("grid", "12x4"));
const [dirCount, powerCount] = gridRaw.split("x").map((s) => parseInt(s, 10));
const onlyLevel = opt("level", null);
const t0Samples = parseInt(String(opt("t0", "24")), 10);
const jsonOut = opt("json", null);
const candFile = opt("file", null);
const detail = opt("detail", false) !== false;

// --- 1) 用仓库自带的 tsc 把三个纯模块编成 CommonJS -------------------------
const tsc = path.join(root, "tools", "dora-build", "node_modules", "typescript", "bin", "tsc");
const outDir = mkdtempSync(path.join(tmpdir(), "ev-sweep-"));
const srcFiles = ["Config", "Gravity", "LevelData"].map((n) => path.join(root, "game", n + ".ts"));
execFileSync(
	process.execPath,
	[tsc, "--module", "commonjs", "--target", "es2020", "--moduleResolution", "node",
	 "--baseUrl", root, "--skipLibCheck", "--outDir", outDir, ...srcFiles],
	{ cwd: root, stdio: ["ignore", "ignore", "pipe"] },
);

// --- 2) 让 require("game/X") 落到刚才的临时目录 ---------------------------
const origResolve = Module._resolveFilename;
Module._resolveFilename = function (request, ...rest) {
	if (typeof request === "string" && request.startsWith("game/")) {
		request = path.join(outDir, request.slice(5) + ".js");
	}
	return origResolve.call(this, request, ...rest);
};
const require2 = createRequire(import.meta.url);
const { getLevel, levelCount, scaledPlanets, findGoalIndex } = require2(path.join(outDir, "LevelData.js"));
const { simulate } = require2(path.join(outDir, "Gravity.js"));
const { PhysicsStep, AimMinSpeed, AimMaxSpeed } = require2(path.join(outDir, "Config.js"));

/** game/Game.ts resolveResult 的镜像（见文件头说明）。 */
function resolveResult(outcome, goalIndex, goal) {
	if (goalIndex >= 0) return "success";
	if (goal.kind === "escape" && outcome === "escaped") return "success";
	if (outcome === "crashed") return "crashed";
	return "missed";
}

function powers() {
	// 与 Test/LevelDataTest.ts 的网格对齐（0.35/0.6/0.85/1.0）；换密度时按 0.35→1.0 均分。
	if (powerCount === 4) return [0.35, 0.6, 0.85, 1.0];
	const out = [];
	for (let i = 0; i < powerCount; i++) {
		out.push(powerCount === 1 ? 1 : 0.35 + (0.65 * i) / (powerCount - 1));
	}
	return out;
}

function sweepLevel(lv) {
	const bodies = scaledPlanets(lv);
	const t0s = [];
	if (lv.timeWindow) {
		for (let i = 0; i < t0Samples; i++) t0s.push((lv.timeWindow.span * i) / t0Samples);
	} else {
		t0s.push(0);
	}
	const samples = [];
	const ps = powers();
	for (const t0 of t0s) {
		for (let d = 0; d < dirCount; d++) {
			const angle = (d * 2 * Math.PI) / dirCount;
			for (const p of ps) {
				const speed = AimMinSpeed + (AimMaxSpeed - AimMinSpeed) * p;
				const vel = { x: Math.cos(angle) * speed, y: Math.sin(angle) * speed };
				// ⚠️ sampleEvery=4 时必须把有效步长（4·dt）传给 findGoalIndex，
				// 否则移动目标的时间轴是错的（测试里原来就是错的，已一并修）。
				const every = 4;
				const sim = simulate(
					{ pos: { x: lv.probeStart.x, y: lv.probeStart.y }, vel },
					bodies,
					{ steps: lv.maxSteps, dt: PhysicsStep, sampleEvery: every, escapeRadius: lv.escapeRadius, t0 },
				);
				const gi = findGoalIndex(sim.points, bodies, lv.goal, PhysicsStep * every, t0);
				const kind = resolveResult(sim.outcome, gi, lv.goal);
				const speedOut = Math.hypot(sim.state.vel.x, sim.state.vel.y);
				let peak = Math.hypot(sim.state.pos.x, sim.state.pos.y);
				for (const q of sim.points) { const s = Math.hypot(q.x, q.y); if (s > peak) peak = s; }
				samples.push({ t0, dir: (angle * 180) / Math.PI, power: p, kind, outcome: sim.outcome, gi, speedOut, peak, steps: sim.stepsRun });
			}
		}
	}
	return { lv, samples, t0s };
}

const source = candFile !== null
	? JSON.parse(readFileSync(String(candFile), "utf8"))
	: null;

const results = [];
if (source !== null) {
	for (const lv of source) {
		if (onlyLevel !== null && String(lv.id) !== String(onlyLevel)) continue;
		results.push(sweepLevel(lv));
	}
} else {
	const n = levelCount();
	for (let i = 0; i < n; i++) {
		if (onlyLevel !== null && String(i + 1) !== String(onlyLevel)) continue;
		const lv = getLevel(i);
		if (lv !== undefined) results.push(sweepLevel(lv));
	}
}

console.log("label                          ok/total   rate     best(dir/power/t0)        exit(dist/speed)");
for (const r of results) {
	const ok = r.samples.filter((s) => s.kind === "success");
	const rate = ((ok.length / r.samples.length) * 100).toFixed(1) + "%";
	const b = ok.length > 0 ? ok[Math.floor(ok.length / 2)] : null;
	const best = b === null ? "-" : b.dir.toFixed(0) + "deg/" + b.power.toFixed(2) + "/" + b.t0.toFixed(1);
	const exit = ok.length > 0 ? ok[0].peak.toFixed(0) + "/" + ok[0].speedOut.toFixed(1) : "-";
	const label = (String(r.lv.id) + " " + r.lv.title + "                              ").slice(0, 30);
	// 全样本的极值：peakDist 决定 escape 类关卡是否**可能**（< escapeRadius 就是死关），
	// speedMax 用来看「这一关能不能真的加速」（静止行星永远只能改方向、不能加能量）。
	let peakDist = 0;
	let speedMax = 0;
	for (const s of r.samples) {
		if (s.peak > peakDist) peakDist = s.peak;
		if (s.speedOut > speedMax) speedMax = s.speedOut;
	}
	const scan = "peakMax=" + peakDist.toFixed(0) + " vMax=" + speedMax.toFixed(1);
	console.log(label, String(ok.length + "/" + r.samples.length).padEnd(10), rate.padEnd(8), best.padEnd(26), exit.padEnd(14), scan);
	if (r.lv.timeWindow) {
		const perT0 = [];
		for (let k = 0; k < r.t0s.length; k++) {
			const kk = r.samples.filter((s) => s.t0 === r.t0s[k] && s.kind === "success").length;
			perT0.push(kk === 0 ? "." : String(Math.min(kk, 9)));
		}
		console.log("      timeWindow span=" + r.lv.timeWindow.span + "  t0 0..span 每档成功数: " + perT0.join("") + "  (. = 该时机无解)");
	}
	if (detail) {
		for (const s of ok) {
			console.log("      ok dir=" + s.dir.toFixed(0) + " power=" + s.power + " t0=" + s.t0.toFixed(2) +
				" peak=" + s.peak.toFixed(0) + " speedOut=" + s.speedOut.toFixed(1) + " steps=" + s.steps + " outcome=" + s.outcome);
		}
	}
}

if (jsonOut !== null) {
	writeFileSync(String(jsonOut), JSON.stringify(results.map((r) => ({
		id: r.lv.id, title: r.lv.title, timeWindow: r.lv.timeWindow || null, samples: r.samples,
	})), null, 1));
	console.log("\n[json] " + jsonOut);
}
