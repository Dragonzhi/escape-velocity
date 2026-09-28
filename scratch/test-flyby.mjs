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
const outDir = mkdtempSync(path.join(tmpdir(), "ev-l2-test-"));
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

const dt = Config.PhysicsStep;

function degToRad(d) { return (d * Math.PI) / 180; }

const sunBody = {
	gm: SunGm,
	radius: SunRadius,
	orbitCenter: { x: 0, y: 0 },
	orbitRadius: 0,
	orbitPeriod: 0,
	phase0: 0,
	orbitDirection: 1,
};

const dv = 2.6;
const startPos = { x: 0, y: EarthOrbitRadius };
const startVel = { x: -EarthOrbitSpeed + dv, y: 0 };

console.log("Testing Venus flyby around phiV0 = 35.95..36.15 deg:");
for (let phiV = 35.95; phiV <= 36.15; phiV += 0.005) {
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
		{ steps: 3000, dt, sampleEvery: 1, escapeRadius: 2000, t0: 0 }
	);

	let minVenusDist = Infinity;
	let minVenusTime = 0;
	let minSunR = Infinity;
	for (let i = 0; i < sim.points.length; i++) {
		const t = i * dt;
		const p = sim.points[i];
		const vPos = Gravity.bodyPositionAt(venusBody, t);
		const dV = Math.sqrt((p.x - vPos.x)**2 + (p.y - vPos.y)**2);
		if (dV < minVenusDist) {
			minVenusDist = dV;
			minVenusTime = t;
		}
		const rSun = Math.sqrt(p.x * p.x + p.y * p.y);
		if (rSun < minSunR) {
			minSunR = rSun;
		}
	}

	console.log(`phiV=${phiV.toFixed(1)}°: minVenusDist=${minVenusDist.toFixed(4)}, tFlyby=${minVenusTime.toFixed(2)}s, minSunR=${minSunR.toFixed(2)} (outcome: ${sim.result ? sim.result.outcome : 'null'})`);
}
