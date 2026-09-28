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
const outDir = mkdtempSync(path.join(tmpdir(), "ev-l2-verify-"));
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

const dt = Config.PhysicsStep;
function degToRad(d) { return (d * Math.PI) / 180; }

// 测试初相
const PH_VENUS = 36.5;
const PH_MERCURY = 10.0;

const sunBody = {
	gm: SunGm,
	radius: SunRadius,
	orbitCenter: { x: 0, y: 0 },
	orbitRadius: 0,
	orbitPeriod: 0,
	phase0: 0,
	orbitDirection: 1,
};
const venusBody = {
	gm: VenusGm,
	radius: VenusRadius,
	orbitCenter: { x: 0, y: 0 },
	orbitRadius: VenusOrbitRadius,
	orbitPeriod: VenusPeriod,
	phase0: degToRad(PH_VENUS),
	orbitDirection: 1,
};
const mercuryBody = {
	gm: MercuryGm,
	radius: MercuryRadius,
	orbitCenter: { x: 0, y: 0 },
	orbitRadius: MercuryOrbitRadius,
	orbitPeriod: MercuryPeriod,
	phase0: degToRad(PH_MERCURY),
	orbitDirection: 1,
};
const bodies = [sunBody, venusBody, mercuryBody];

let hitCount = 0;
let totalCount = 0;
const hits = [];

// 扫掠发射参数：方向角 -5 到 5 度，力度 2.5 到 3.2，时间轴 t0 涵盖微调
for (let dv = 2.5; dv <= 3.2; dv += 0.05) {
	for (let angDeg = -5; angDeg <= 5; angDeg += 0.5) {
		for (let t0 = 0; t0 <= 2.0; t0 += 0.2) {
			totalCount++;
			const angRad = degToRad(angDeg);
			const startPos = { x: 0, y: EarthOrbitRadius };
			const startVel = { x: -EarthOrbitSpeed + dv * Math.cos(angRad), y: dv * Math.sin(angRad) };

			const sim = Gravity.simulate(
				{ pos: startPos, vel: startVel },
				bodies,
				{ steps: 2500, dt, sampleEvery: 1, escapeRadius: 2000, t0 }
			);

			// 目标判定：依次经过金星（走廊 r <= 0.40）和水星（tolerance <= 4.0）
			let passedVenus = false;
			let minVenusD = Infinity;
			let passedMercury = false;
			let minMercD = Infinity;

			for (let i = 0; i < sim.points.length; i++) {
				const t = t0 + i * dt;
				const p = sim.points[i];
				const vPos = Gravity.bodyPositionAt(venusBody, t);
				const dV = Math.sqrt((p.x - vPos.x)**2 + (p.y - vPos.y)**2);
				if (dV < minVenusD) minVenusD = dV;
				if (dV <= 0.40) passedVenus = true;

				if (passedVenus) {
					const mPos = Gravity.bodyPositionAt(mercuryBody, t);
					const dM = Math.sqrt((p.x - mPos.x)**2 + (p.y - mPos.y)**2);
					if (dM < minMercD) minMercD = dM;
					if (dM <= 4.0) {
						passedMercury = true;
						break;
					}
				}
			}

			if (passedMercury) {
				hitCount++;
				hits.push({ dv, angDeg, t0, minVenusD, minMercD });
			}
		}
	}
}

console.log(`Scan completed: ${hitCount} / ${totalCount} (${(hitCount*100/totalCount).toFixed(2)}%) hits!`);
if (hits.length > 0) {
	console.log("Sample hits:");
	for (let i = 0; i < Math.min(10, hits.length); i++) {
		const h = hits[i];
		console.log(`  dv=${h.dv.toFixed(2)}, ang=${h.angDeg.toFixed(1)}°, t0=${h.t0.toFixed(1)}s -> minVenusD=${h.minVenusD.toFixed(4)}, minMercD=${h.minMercD.toFixed(3)}`);
	}
}

