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
const outDir = mkdtempSync(path.join(tmpdir(), "ev-l2-single-"));
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

const PH_VENUS = 37.587;
const PH_MERCURY = 2.18;

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

const dv = 2.85;
const startPos = { x: 0, y: EarthOrbitRadius };
const startVel = { x: -EarthOrbitSpeed + dv, y: 0 };

const sim = Gravity.simulate(
	{ pos: startPos, vel: startVel },
	bodies,
	{ steps: 2500, dt, sampleEvery: 1, escapeRadius: 2000, t0: 0 }
);

let minVenusD = Infinity;
let minVenusT = 0;
let minMercD = Infinity;
let minMercT = 0;

for (let i = 0; i < sim.points.length; i++) {
	const t = i * dt;
	const p = sim.points[i];
	const vPos = Gravity.bodyPositionAt(venusBody, t);
	const dV = Math.sqrt((p.x - vPos.x)**2 + (p.y - vPos.y)**2);
	if (dV < minVenusD) {
		minVenusD = dV;
		minVenusT = t;
	}

	const mPos = Gravity.bodyPositionAt(mercuryBody, t);
	const dM = Math.sqrt((p.x - mPos.x)**2 + (p.y - mPos.y)**2);
	if (dM < minMercD) {
		minMercD = dM;
		minMercT = t;
	}
}

console.log(`Single run with dv=2.85, ang=0:`);
console.log(`Venus min dist: ${minVenusD.toFixed(4)} at t=${minVenusT.toFixed(2)}s`);
console.log(`Mercury min dist: ${minMercD.toFixed(4)} at t=${minMercT.toFixed(2)}s`);

