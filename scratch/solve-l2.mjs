import { execFileSync } from "node:child_process";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import Module from "node:module";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");

const tsc = path.join(root, "tools", "dora-build", "node_modules", "typescript", "bin", "tsc");
const outDir = mkdtempSync(path.join(tmpdir(), "ev-l2-"));
const srcFiles = ["Config", "Gravity", "Scale", "Tuning"].map((n) => path.join(root, "game", n + ".ts"));
execFileSync(
	process.execPath,
	[tsc, "--module", "commonjs", "--target", "es2020", "--moduleResolution", "node",
	 "--baseUrl", root, "--skipLibCheck", "--outDir", outDir, ...srcFiles],
	{ cwd: root, stdio: ["ignore", "ignore", "pipe"] }
);

const origResolve = Module._resolveFilename;
Module._resolveFilename = function (request, ...rest) {
	if (typeof request === "string" && request.startsWith("game/")) {
		request = path.join(outDir, request.slice(5) + ".js");
	}
	return origResolve.call(this, request, ...rest);
};
const require2 = createRequire(import.meta.url);
const Gravity = require2(path.join(outDir, "Gravity.js"));
const Scale = require2(path.join(outDir, "Scale.js"));
const Config = require2(path.join(outDir, "Config.js"));

const SunGm = Scale.SunGm;
const SunRadius = Scale.SunRadius;
const EarthOrbitRadius = Scale.trueOrbit(Scale.REAL.earth.au);
const EarthOrbitSpeed = Scale.circularSpeed(SunGm, EarthOrbitRadius);

const VenusOrbitRadius = Scale.trueOrbit(Scale.REAL.venus.au);
const VenusGm = Scale.trueGm(Scale.REAL.venus.gm);
const VenusRadius = Scale.trueRadius(Scale.REAL.venus.radiusKm);
const VenusPeriod = Scale.period(VenusOrbitRadius, SunGm);
const VenusOmega = (2 * Math.PI) / VenusPeriod;

const MercuryOrbitRadius = Scale.trueOrbit(Scale.REAL.mercury.au);
const MercuryGm = Scale.trueGm(Scale.REAL.mercury.gm);
const MercuryRadius = Scale.trueRadius(Scale.REAL.mercury.radiusKm);
const MercuryPeriod = Scale.period(MercuryOrbitRadius, SunGm);
const MercuryOmega = (2 * Math.PI) / MercuryPeriod;

console.log(`Sun GM: ${SunGm.toFixed(1)}`);
console.log(`Venus: r=${VenusOrbitRadius.toFixed(2)}, T=${VenusPeriod.toFixed(3)}s, gm=${VenusGm.toFixed(4)}, Hill=${Scale.hillRadius(VenusOrbitRadius, VenusGm, SunGm).toFixed(3)}`);
console.log(`Mercury: r=${MercuryOrbitRadius.toFixed(2)}, T=${MercuryPeriod.toFixed(3)}s, gm=${MercuryGm.toFixed(4)}`);

// 探索：从 (0, 80) 出发，霍曼降轨需要向切向减速（初速是 (-30, 0)，向 +x 点火是减速）。
// 设点火 dv 在 [2.5, 3.2] 之间，点火角度在 [-20 deg, +20 deg]（以 +x 为 0 度，y 轴为 90 度）。
// 探测器在纯太阳引力下，飞到金星轨道 (r = VenusOrbitRadius) 的时间约为 6.6 秒。
// 当探测器到达金星轨道附近时，我们选择不同的金星初相 phiV，使金星在探测器身后掠过（探测器在金星运动方向前方）。
// 记录发生近距离掠过 (r_peri in [0.03, 0.40]) 并且近日点成功降到水星轨道 (r_min <= MercuryOrbitRadius + 1.0) 的解！

function degToRad(d) { return (d * Math.PI) / 180; }
function radToDeg(r) { return (r * 180) / Math.PI; }
function normDeg(d) {
	let res = d % 360;
	if (res < 0) res += 360;
	return res;
}

const dt = Config.PhysicsStep;
console.log(`Physics dt: ${dt}`);

const solutions = [];

// 扫掠 dv 和角度
for (let dv = 2.6; dv <= 2.8; dv += 0.1) {
	for (let angleDeg = -4; angleDeg <= 4; angleDeg += 2) {
		const angleRad = degToRad(angleDeg);
		const burnX = dv * Math.cos(angleRad);
		const burnY = dv * Math.sin(angleRad);
		const vx0 = -EarthOrbitSpeed + burnX;
		const vy0 = burnY;

		for (let phiV0Deg = 0; phiV0Deg < 360; phiV0Deg += 2) {
			const phiV0 = degToRad(phiV0Deg);
			const venusBody = {
				gm: VenusGm,
				radius: VenusRadius,
				orbitCenter: { x: 0, y: 0 },
				orbitRadius: VenusOrbitRadius,
				orbitPeriod: VenusPeriod,
				phase0: phiV0,
				orbitDirection: 1,
			};
			const sunBody = {
				gm: SunGm,
				radius: SunRadius,
				orbitCenter: { x: 0, y: 0 },
				orbitRadius: 0,
				orbitPeriod: 0,
				phase0: 0,
				orbitDirection: 1,
			};

			const bodies = [sunBody, venusBody];
			const startPos = { x: 0, y: EarthOrbitRadius };
			const startVel = { x: vx0, y: vy0 };

			const sim = Gravity.simulate(
				{ pos: startPos, vel: startVel },
				bodies,
				{
					steps: 2500,
					dt: dt,
					sampleEvery: 1,
					escapeRadius: 2000,
					t0: 0,
				}
			);

			// 检查是否与金星发生有效借力：
			// 1. 金星最近距离 rVenusMin
			// 2. 借力后的近日点 rSunMin 后期是否到达水星轨道 (MercuryOrbitRadius = 30.97)
			let rVenusMin = Infinity;
			let tVenusMin = 0;
			let idxVenusMin = 0;

			for (let i = 0; i < sim.points.length; i++) {
				const t = i * dt;
				const p = sim.points[i];
				const vPos = Gravity.bodyPositionAt(venusBody, t);
				const d = Math.hypot ? Math.hypot(p.x - vPos.x, p.y - vPos.y) : Math.sqrt((p.x - vPos.x)**2 + (p.y - vPos.y)**2);
				if (d < rVenusMin) {
					rVenusMin = d;
					tVenusMin = t;
					idxVenusMin = i;
				}
			}

			// 如果金星最近距离在有效减速走廊 [0.03, 0.40] 内
			if (rVenusMin >= 0.03 && rVenusMin <= 0.40 && idxVenusMin > 100) {
				// 检查金星掠过之后的近日点
				let rSunMinAfter = Infinity;
				let tSunMinAfter = 0;
				let ptMercury = null;
				let tMercury = 0;

				for (let i = idxVenusMin; i < sim.points.length; i++) {
					const t = i * dt;
					const p = sim.points[i];
					const rSun = Math.sqrt(p.x * p.x + p.y * p.y);
					if (rSun < rSunMinAfter) {
						rSunMinAfter = rSun;
						tSunMinAfter = t;
					}
					// 穿过水星轨道半径 30.97
					if (Math.abs(rSun - MercuryOrbitRadius) <= 1.0 && ptMercury === null) {
						ptMercury = p;
						tMercury = t;
					}
				}

				if (rSunMinAfter <= MercuryOrbitRadius + 1.0 && ptMercury !== null) {
					// 算水星需要设为多少初相才能正好在 tMercury 相遇
					// 水星位置: x = r * cos(phiM0 + omegaM * t), y = r * sin(phiM0 + omegaM * t)
					const probeTheta = Math.atan2(ptMercury.y, ptMercury.x);
					const reqMercuryPhaseAtT = probeTheta;
					let reqMercuryPhase0 = reqMercuryPhaseAtT - MercuryOmega * tMercury;
					reqMercuryPhase0 = normDeg(radToDeg(reqMercuryPhase0));

					solutions.push({
						dv,
						angleDeg,
						phiV0Deg,
						rVenusMin,
						tVenusMin,
						rSunMinAfter,
						tMercury,
						phiM0Deg: reqMercuryPhase0,
						finalResult: sim.result
					});
				}
			}
		}
	}
}

console.log(`Found ${solutions.length} candidate gravity-assist solutions!`);
if (solutions.length > 0) {
	// 按 rVenusMin 排序或者挑选代表性的解
	solutions.sort((a, b) => a.rVenusMin - b.rVenusMin);
	console.log("Top 10 solutions:");
	for (let i = 0; i < Math.min(10, solutions.length); i++) {
		const s = solutions[i];
		console.log(`[#${i+1}] dv=${s.dv.toFixed(2)}, ang=${s.angleDeg}°, phiV0=${s.phiV0Deg}°, rV=${s.rVenusMin.toFixed(3)} at t=${s.tVenusMin.toFixed(2)}s | rMin=${s.rSunMinAfter.toFixed(2)} at t=${s.tMercury.toFixed(2)}s | phiM0=${s.phiM0Deg.toFixed(1)}°`);
	}
}
