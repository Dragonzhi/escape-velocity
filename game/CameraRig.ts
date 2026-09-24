/**
 * 相机机架：单一 Camera3D + 动态跟随拉远（决策 D3）。
 *
 * 设计要点（手册 §5.4）：
 * - **不做视角硬切**：不区分“全局视角 / 跟随视角”，只有一个连续计算的 rig。
 * - 依据是“**所有关键点的包围盒展开程度**”，而不是“探测器到目标的距离”。
 *   （前者在探测器飞过目标时仍然单调；后者会先增后减，导致相机反直觉地拉近。）
 * - 距离与注视点都做**一阶平滑**，避免抖动。
 * - 俯视倾角固定在安全区间（20–60°，实测 >70° 会贴边）。
 *
 * 纯逻辑可测：`computeFit` / `computeRigStep` 不碰引擎对象，只有 `apply` 才写回相机。
 */
import { Camera3D, Vec3 } from 'Dora';
import { CameraLerp, CameraMaxDistance, CameraMinDistance, CameraTiltDefault } from 'game/Config';
import { P2 } from 'game/Gravity';
import { planeToWorld } from 'game/Scene';

/** 机架的可调参数。 */
export interface RigOptions {
	/** 俯视倾角（度）。 */
	tiltDeg: number;
	/** 距离夹紧范围。 */
	minDistance: number;
	maxDistance: number;
	/** 平滑系数（0–1）；1 = 不平滑。 */
	lerp: number;
	/** 距离 = minDistance + 包围盒半对角 * fitFactor。 */
	fitFactor: number;
}

export function defaultRigOptions(): RigOptions {
	return {
		tiltDeg: CameraTiltDefault,
		minDistance: CameraMinDistance,
		maxDistance: CameraMaxDistance,
		lerp: CameraLerp,
		fitFactor: 1.6,
	};
}

/** 机架的连续状态。 */
interface RigState {
	/** 平滑后的注视点（平面坐标）。 */
	focusX: number;
	focusY: number;
	/** 平滑后的距离。 */
	distance: number;
	/** 是否已初始化（第一次调用直接吸附，不做插值）。 */
	initialized: boolean;
}

/**
 * 相机机架句柄。
 *
 * ⚠️ 必须加 `@noSelf`，否则 TSTL 会生成 `rig:step(...)` 冒号调用，
 * 把 `rig` 当作第一个参数传入，导致参数错位（详见 game/Scene.ts 同名注释）。
 *
 * @noSelf
 */
export interface CameraRig {
	/**
	 * 推进一帧，返回新的相机参数（纯计算）。
	 *
	 * @param points 需要保持在画面内的关键点（探测器、行星、目标）。
	 */
	step(points: P2[]): RigFrame;
	/** 把机架参数写到真实相机。 */
	apply(camera: Camera3D.Type, frame: RigFrame): void;
}

/** 一帧的相机参数（纯数据，便于测试）。 */
export interface RigFrame {
	/** 注视点（世界坐标）。 */
	target: Vec3.Type;
	/** 相机位置（世界坐标）。 */
	eye: Vec3.Type;
}

/** 画面拟合结果。 */
export interface Fit {
	/** 包围盒中心（平面坐标）。 */
	centerX: number;
	centerY: number;
	/** 包围盒半对角长度。 */
	extent: number;
}

/**
 * 计算所有关键点的包围盒中心与半对角。
 *
 * 关键点通常包含：探测器、所有行星、目标点。
 * 半对角随“探测器飞离场景中心”单调增长 → 相机单调拉远。
 */
export function computeFit(points: P2[]): Fit {
	if (points.length === 0) return { centerX: 0, centerY: 0, extent: 0 };

	let minX = points[0].x;
	let maxX = points[0].x;
	let minY = points[0].y;
	let maxY = points[0].y;
	for (let i = 1; i < points.length; i++) {
		const p = points[i];
		if (p.x < minX) minX = p.x;
		if (p.x > maxX) maxX = p.x;
		if (p.y < minY) minY = p.y;
		if (p.y > maxY) maxY = p.y;
	}

	const hw = (maxX - minX) / 2;
	const hh = (maxY - minY) / 2;
	return {
		centerX: (minX + maxX) / 2,
		centerY: (minY + maxY) / 2,
		extent: Math.sqrt(hw * hw + hh * hh),
	};
}

/**
 * 纯计算：根据关键点集合，算出这一帧的相机参数。
 *
 * `points` 中应包含探测器、行星与目标；顺序无关。
 */
export function computeRigStep(
	state: RigState,
	points: P2[],
	opts: RigOptions,
): RigFrame {
	const fit = computeFit(points);

	let wantDistance = opts.minDistance + fit.extent * opts.fitFactor;
	if (wantDistance < opts.minDistance) wantDistance = opts.minDistance;
	if (wantDistance > opts.maxDistance) wantDistance = opts.maxDistance;

	if (!state.initialized) {
		// 首帧直接吸附，避免从原点“飞过去”的镜头运动
		state.focusX = fit.centerX;
		state.focusY = fit.centerY;
		state.distance = wantDistance;
		state.initialized = true;
	} else {
		const k = opts.lerp < 0 ? 0 : (opts.lerp > 1 ? 1 : opts.lerp);
		state.focusX += (fit.centerX - state.focusX) * k;
		state.focusY += (fit.centerY - state.focusY) * k;
		state.distance += (wantDistance - state.distance) * k;
	}

	const targetWorld = planeToWorld({ x: state.focusX, y: state.focusY }, 0);

	// 相机在注视点的斜上方：倾角决定高度/进深比例。
	const tilt = opts.tiltDeg * Math.PI / 180;
	const eye = Vec3(
		targetWorld.x,
		targetWorld.y + Math.sin(tilt) * state.distance,
		targetWorld.z + Math.cos(tilt) * state.distance,
	);

	return { target: targetWorld, eye };
}

/** 创建一个机架（持有平滑状态）。 */
export function createCameraRig(opts?: RigOptions): CameraRig {
	const options = opts !== undefined ? opts : defaultRigOptions();
	const state: RigState = { focusX: 0, focusY: 0, distance: options.minDistance, initialized: false };

	return {
		step: (points: P2[]): RigFrame => {
			return computeRigStep(state, points, options);
		},
		apply: (camera: Camera3D.Type, frame: RigFrame): void => {
			camera.lookAt(frame.eye, frame.target, Vec3(0, 1, 0));
		},
	};
}
