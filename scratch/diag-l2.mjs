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
const outDir = mkdtempSync(path.join(tmpdir(), "ev-l2-diag-"));
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

const dt = Config.PhysicsStep;
const sunBody = {
	gm: SunGm,
	radius: SunRadius,
	orbitCenter: { x: 0, y: 0 },
	orbitRadius: 0,
	orbitPeriod: 0,
	phase0: 0,
	orbitDirection: 1,
};

for (let dv = 2.4; dv <= 3.2; dv += 0.2) {
	const startPos = { x: 0, y: EarthOrbitRadius };
	const startVel = { x: -EarthOrbitSpeed + dv, y: 0 };
	const sim = Gravity.simulate(
		{ pos: startPos, vel: startVel },
		[sunBody],
		{ steps: 2000, dt, sampleEvery: 1, escapeRadius: 2000, t0: 0 }
	);

	let periR = Infinity;
	let periT = 0;
	let periPt = null;
	for (let i = 0; i < sim.points.length; i++) {
		const p = sim.points[i];
		const r = Math.sqrt(p.x * p.x + p.y * p.y);
		if (r < periR) {
			periR = r;
			periT = i * dt;
			periPt = p;
		}
	}
	const angleDeg = (Math.atan2(periPt.y, periPt.x) * 180 / Math.PI + 360) % 360;
	console.log(`dv=${dv.toFixed(2)}: periR=${periR.toFixed(2)} (Venus r=${VenusOrbitRadius.toFixed(2)}), periT=${periT.toFixed(3)}s, periAngle=${angleDeg.toFixed(1)}°`);
}

