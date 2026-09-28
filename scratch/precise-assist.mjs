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
const outDir = mkdtempSync(path.join(tmpdir(), "ev-l2-precise-"));
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

const MercuryOrbitRadius = Scale.trueOrbit(Scale.REAL.mercury.au);
const MercuryGm = Scale.trueGm(Scale.REAL.mercury.gm);
const MercuryRadius = Scale.trueRadius(Scale.REAL.mercury.radiusKm);
const MercuryPeriod = Scale.period(MercuryOrbitRadius, SunGm);
const MercuryOmega = (2 * Math.PI) / MercuryPeriod;

const dt = Config.PhysicsStep;
function degToRad(d) { return (d * Math.PI) / 180; }
function radToDeg(r) { return (r * 180) / Math.PI; }
function normDeg(d) {
	let res = d % 360;
	if (res < 0) res += 360;
	return res;
}

const sunBody = {
	gm: SunGm,
	radius: SunRadius,
	orbitCenter: { x: 0, y: 0 },
	orbitRadius: 0,
	orbitPeriod: 0,
	phase0: 0,
	orbitDirection: 1,
};

// 我们针对 dv = 2.65, 2.8, 3.0, 3.2 做超高精度金星初相扫描 (步长 0.002 度)
for (const dv of [2.65, 2.85, 3.0, 3.2, 3.4]) {
	const startPos = { x: 0, y: EarthOrbitRadius };
	const startVel = { x: -EarthOrbitSpeed + dv, y: 0 };

	// 先求纯太阳引力下到达金星轨道 (r=57.87) 的时刻与日心角
	const unp = Gravity.simulate({ pos: startPos, vel: startVel }, [sunBody], { steps: 2000, dt, sampleEvery: 1, escapeRadius: 2000, t0: 0 });
	let tAtVenus = 0;
	let angleAtVenus = 0;
	for (let i = 0; i < unp.points.length; i++) {
		const p = unp.points[i];
		const r = Math.sqrt(p.x * p.x + p.y * p.y);
		if (r <= VenusOrbitRadius) {
			tAtVenus = i * dt;
			angleAtVenus = (Math.atan2(p.y, p.x) * 180 / Math.PI + 360) % 360;
			break;
		}
	}
	const phiVApprox = normDeg(angleAtVenus - (360 / VenusPeriod) * tAtVenus);
	console.log(`\n=== Testing dv=${dv}: tAtVenus=${tAtVenus.toFixed(2)}s, angle=${angleAtVenus.toFixed(1)}°, phiVApprox=${phiVApprox.toFixed(2)}° ===`);

	// 在 phiVApprox 附近 ±1.5 度，步长 0.005 度密集搜索
	let best = null;
	for (let phiV = phiVApprox - 1.5; phiV <= phiVApprox + 1.5; phiV += 0.005) {
		const venusBody = {
			gm: VenusGm,
			radius: VenusRadius,
			orbitCenter: { x: 0, y: 0 },
			orbitRadius: VenusOrbitRadius,
			orbitPeriod: VenusPeriod,
			phase0: degToRad(phiV),
			orbitDirection: 1,
		};

		const sim = Gravity.simulate(
			{ pos: startPos, vel: startVel },
			[sunBody, venusBody],
			{ steps: 3500, dt, sampleEvery: 1, escapeRadius: 2000, t0: 0 }
		);

		let minVenusDist = Infinity;
		let idxVenusMin = -1;
		let minSunR = Infinity;
		let tMercury = 0;
		let ptMercury = null;

		for (let i = 0; i < sim.points.length; i++) {
			const t = i * dt;
			const p = sim.points[i];
			const vPos = Gravity.bodyPositionAt(venusBody, t);
			const dV = Math.sqrt((p.x - vPos.x)**2 + (p.y - vPos.y)**2);
			if (dV < minVenusDist) {
				minVenusDist = dV;
				idxVenusMin = i;
			}
			if (idxVenusMin > 50 && i > idxVenusMin) {
				const rSun = Math.sqrt(p.x * p.x + p.y * p.y);
				if (rSun < minSunR) {
					minSunR = rSun;
				}
				if (Math.abs(rSun - MercuryOrbitRadius) <= 2.0 && ptMercury === null) {
					ptMercury = p;
					tMercury = t;
				}
			}
		}

		if (minSunR < 50.0) {
			if (!best || minSunR < best.minSunR) {
				best = { phiV, minVenusDist, minSunR, tMercury, ptMercury };
			}
		}
	}

	if (best) {
		console.log(`BEST for dv=${dv}: phiV=${best.phiV.toFixed(3)}°, minVenusDist=${best.minVenusDist.toFixed(4)}, minSunR=${best.minSunR.toFixed(2)} (Mercury=${MercuryOrbitRadius.toFixed(2)})`);
		if (best.ptMercury) {
			const probeTheta = Math.atan2(best.ptMercury.y, best.ptMercury.x);
			let phiM0 = normDeg(radToDeg(probeTheta - MercuryOmega * best.tMercury));
			console.log(`  -> Mercury arrival at t=${best.tMercury.toFixed(2)}s, required phiM0 = ${phiM0.toFixed(2)}°`);
		}
	} else {
		console.log(`No deep assist found for dv=${dv}`);
	}
}

