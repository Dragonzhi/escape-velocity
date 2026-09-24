/**
 * S0.3 回归测试（R4）：投影标定的固化版本。
 *
 * 用 View3D.getRayDirection 做真值（对已知世界点搜索"方向点积最大"的屏幕位置），
 * 验证 game/Projection.ts 的 project() 在已标定的约定下与渲染一致。
 *
 * 判据：中位像素误差 < 2 px。
 * 产出：.agent/test-results/s0-projection.txt（首行 RESULT=PASS/FAIL）
 */
import { App, Camera3D, Content, Director, Path, Vec2, Vec3, View, threadLoop } from 'Dora';
import { CameraView, HANDEDNESS, FLIP_Y, V3, project } from 'game/Projection';

const resultDir = Path(Content.searchPaths[0], '.agent', 'test-results');
if (!Content.exist(resultDir)) Content.mkdir(resultDir);
const markerPath = Path(resultDir, 's0-projection.txt');

const lines: string[] = [];
function flush(result: string): void {
	Content.save(markerPath, `${result}\n${lines.join('\n')}`);
}

const EYE: V3 = { x: 3, y: 4, z: 8 };
const WORLD: V3[] = [
	{ x: 0, y: 0, z: 0 },
	{ x: 4, y: 0, z: 0 },
	{ x: -4, y: 0, z: 0 },
	{ x: 0, y: 3, z: 0 },
	{ x: 0, y: -3, z: 0 },
];
const TAGS = ['origin', '+x', '-x', '+y', '-y'];

lines.push('phase=started');
flush('RESULT=PENDING');

try {
	const camera = Camera3D();
	camera.lookAt(Vec3(EYE.x, EYE.y, EYE.z), Vec3(0, 0, 0));
	Director.pushCamera(camera);

	const W = View.size.width;
	const H = View.size.height;
	const cam: CameraView = {
		eye: EYE,
		target: { x: 0, y: 0, z: 0 },
		up: { x: 0, y: 1, z: 0 },
		fovYDeg: View.fieldOfView,
		aspect: View.aspectRatio,
		viewW: W,
		viewH: H,
	};
	lines.push(`view=${W}x${H} fov=${View.fieldOfView} aspect=${View.aspectRatio}`);

	function evalAt(px: number, py: number, p: V3): number {
		const d = Director.entry.getRayDirection(Vec2(px, py));
		const ox = p.x - EYE.x, oy = p.y - EYE.y, oz = p.z - EYE.z;
		const ol = Math.sqrt(ox * ox + oy * oy + oz * oz);
		if (ol < 1e-6) return -2;
		return d.x * (ox / ol) + d.y * (oy / ol) + d.z * (oz / ol);
	}

	const truePos: { x: number; y: number }[] = [];
	let pi = 0;
	let coarse = true;
	let step = 48;
	let bestX = 0, bestY = 0, bestDot = -2;
	let cx = 0, cy = 0;
	let frames = 0;

	threadLoop(() => {
		frames += 1;
		if (pi >= WORLD.length || frames > 4000) {
			// 计算误差
			const errors: number[] = [];
			for (let k = 0; k < truePos.length; k++) {
				const p = project(WORLD[k], cam, HANDEDNESS, FLIP_Y);
				if (p === undefined) { errors.push(1e9); continue; }
				const vx = W / 2 + p.x;
				const vy = H / 2 + p.y;
				const ex = vx - truePos[k].x;
				const ey = vy - truePos[k].y;
				const e = Math.sqrt(ex * ex + ey * ey);
				errors.push(e);
				lines.push(`[${TAGS[k]}] true=(${truePos[k].x}, ${truePos[k].y}) mine=(${vx.toFixed(1)}, ${vy.toFixed(1)}) err=${e.toFixed(2)}px`);
			}
			let maxErr = 0;
			for (const e of errors) if (e > maxErr) maxErr = e;
			lines.push(`maxPxErr=${maxErr.toFixed(2)}`);
			const pass = errors.length === WORLD.length && maxErr < 2;
			flush(pass ? 'RESULT=PASS' : 'RESULT=FAIL');
			return false;
		}

		let ops = 0;
		while (ops < 400 && pi < WORLD.length) {
			const d = evalAt(cx, cy, WORLD[pi]);
			if (d > bestDot) { bestDot = d; bestX = cx; bestY = cy; }
			cx += step;
			const xStart = Math.max(0, bestX - 48);
			const yStart = Math.max(0, bestY - 48);
			if (coarse) {
				if (cx > W) { cx = 0; cy += step; }
				if (cy > H) {
					coarse = false;
					step = 2;
					cx = xStart;
					cy = yStart;
					bestDot = -2;
				}
			} else {
				if (cx > Math.min(W, bestX + 48)) { cx = xStart; cy += step; }
				if (cy > Math.min(H, bestY + 48)) {
					truePos.push({ x: bestX, y: bestY });
					pi += 1;
					coarse = true;
					step = 48;
					cx = 0;
					cy = 0;
					bestDot = -2;
				}
			}
			ops += 1;
		}
		return false;
	});
} catch (e) {
	lines.push('phase=exception');
	flush('RESULT=FAIL');
}
