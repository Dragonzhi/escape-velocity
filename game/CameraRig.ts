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
 * ===== 取景改为“按真实投影求解”（S3.1 修正，会话 23）=====
 * 旧做法是 `距离 = minDistance + 包围盒半对角 × fitFactor` —— 一个**与相机无关的启发式**。
 * 竖屏（aspect 0.56）下横向可用空间只有纵向的一半，而透视还会放大靠近相机的点，
 * 于是位于包围盒角上的探测器**整个跑到画面外**：L3 真机/截图实测「进关看不到自己的飞行器，
 * 预测线从画面外射进来」（子智能体只报了 stats，是截图看出来的）。
 * 现在改为：在 [minDistance, maxDistance] 上二分求解「所有关键点投影都在画面内缩 margin 内」
 * 的**最小**距离，投影复用 game/Projection.ts（与渲染/预测线同一套已标定公式）；
 * 探测器的模型外接半径也计入（它是**有体积**的，只约束中心点会被画面边缘切掉天线）。
 *
 * 纯逻辑可测：`computeFit` / `computeRigStep` 不碰引擎对象，只有 `apply` 才写回相机。
 */
import { Camera3D, Vec3 } from 'Dora';
import { CameraView, HANDEDNESS, FLIP_Y, prepareCamera, projectPrepared } from 'game/Projection';
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
	/** 垂直视野角（度）；传 `View.fieldOfView`（本机实测 45）。 */
	fovYDeg: number;
	/** 视图宽高比（宽/高）；传 `View.aspectRatio`。竖屏 < 1 ⇒ 横向更挤。 */
	aspect: number;
	/** 关键点距画面边缘的最小留白（占半屏比例）。0.05 = 四边各留 5%。 */
	margin: number;
}

/**
 * 默认参数。
 *
 * @param fovYDeg 垂直视野角，来自 `View.fieldOfView`；省略按 45（引擎默认）算。
 * @param aspect 宽高比，来自 `View.aspectRatio`；省略按 1（正方形）算。
 */
export function defaultRigOptions(fovYDeg?: number, aspect?: number, minDistance?: number, maxDistance?: number): RigOptions {
	return {
		tiltDeg: CameraTiltDefault,
		// S5：夹紧区间按关卡给 —— 六关的世界尺度跨 5 个数量级（L1 的 0.6 单位 vs L6 的 5000）。
		// 全局常量在 L1 会把相机顶在 60 上（比整个世界还大 100 倍），画面里只剩一个点。
		minDistance: minDistance !== undefined && minDistance > 0 ? minDistance : CameraMinDistance,
		maxDistance: maxDistance !== undefined && maxDistance > 0 ? maxDistance : CameraMaxDistance,
		lerp: CameraLerp,
		fovYDeg: fovYDeg !== undefined ? fovYDeg : 45,
		aspect: aspect !== undefined && aspect > 0 ? aspect : 1,
		margin: 0.05,
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
	 * @param points 需要保持在画面内的关键点（探测器、行星、目标）；**约定 points[0] = 探测器**。
	 * @param probeRadius 探测器模型的外接半径（世界单位）；计入取景，免得天线被画面边缘切掉。
	 * @param radii 逐个关键点的外接半径（S3.12）：太阳这类大体量天体必须**完整**在画面内 ——
	 *        只约束中心点会让它压在画面边缘外（截图实测：太阳被裁掉一块）。省略 = 旧行为。
	 * @param minDistance 临时把**距离下限**改小（S3.17 掠过慢动作的特写用）：同一套逐点半径
	 *        求解器，只是把夹紧区间 [minDistance, maxDistance] 的左端换掉 —— 不是另写一套取景。
	 *        只接受比 `options.minDistance` 小的值（放大镜不许把日常取景也顶进去）；
	 *        装不下时求解器自己会往后退，相机不会穿进天体。省略 = 用默认下限。
	 */
	step(points: P2[], probeRadius?: number, radii?: number[], minDistance?: number): RigFrame;
	/** 纯查询：这组关键点需要多远才能全部装下（不改机架状态）。 */
	wantDistance(points: P2[], probeRadius?: number, radii?: number[]): number;
	/** 把机架参数写到真实相机。 */
	apply(camera: Camera3D.Type, frame: RigFrame): void;
	/**
	 * 清掉平滑状态（下一帧直接吸附，不做插值）。
	 *
	 * 什么时候必须调：有人**绕开机架**直接写过相机之后。目前只有终章「暗淡蓝点」
	 * （S3.18）这么做 —— 它要把相机拉到 1000 单位外，而机架的距离夹在 [60, 300]。
	 * 不清的话，终章那一夜留下的 `distance = 1000` 会让下一关的相机从 1000 一路 lerp 回日常取景。
	 * 纯状态复位，不碰相机对象，随时可重入。
	 */
	reset(): void;
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

/** 由注视点（平面坐标）与距离构造一帧相机参数（纯计算，不碰引擎相机对象）。 */
function frameAt(centerX: number, centerY: number, distance: number, opts: RigOptions): RigFrame {
	const targetWorld = planeToWorld({ x: centerX, y: centerY }, 0);
	const tilt = opts.tiltDeg * Math.PI / 180;
	return {
		target: targetWorld,
		eye: Vec3(
			targetWorld.x,
			targetWorld.y + Math.sin(tilt) * distance,
			targetWorld.z + Math.cos(tilt) * distance,
		),
	};
}

/**
 * 这一组关键点在给定距离下，是否**全部**落在“画面内缩 margin”的安全区内。
 *
 * 投影走 game/Projection.ts（与渲染、预测线同一套已标定公式）。
 * 把 viewW/viewH 取 2 ⇒ `projectPrepared` 的返回值就是 NDC（±1 = 画面边缘），
 * 于是安全区就是 ±(1 - margin)。
 *
 * @param probeRadius points[0]（探测器）的模型外接半径（世界单位）；它是**有体积**的，
 *        只约束中心点会让碟形天线被边缘切掉。屏幕上多占的 NDC ≈ (r / 深度) × focal。
 */
function frameFits(
	points: P2[],
	centerX: number,
	centerY: number,
	distance: number,
	probeRadius: number,
	opts: RigOptions,
	/** 逐个关键点的**外接半径**（S3.12）；省略 = 只有 points[0] 用 probeRadius（旧行为）。 */
	radii?: number[],
): boolean {
	const frame = frameAt(centerX, centerY, distance, opts);
	const view: CameraView = {
		eye: frame.eye,
		target: frame.target,
		up: { x: 0, y: 1, z: 0 },
		fovYDeg: opts.fovYDeg,
		aspect: opts.aspect,
		viewW: 2,
		viewH: 2,
	};
	const basis = prepareCamera(view, HANDEDNESS, FLIP_Y);
	const limit = 1 - opts.margin;

	for (let i = 0; i < points.length; i++) {
		const p = projectPrepared(planeToWorld(points[i], 0), basis);
		if (p === undefined) return false; // 落在相机后方：这一帧装不下
		const r = radii !== undefined && radii[i] !== undefined ? radii[i] : (i === 0 ? probeRadius : 0);
		const ry = r > 0 ? (r / p.vz) * basis.focal : 0;
		const rx = ry / opts.aspect;
		if (Math.abs(p.x) + rx > limit) return false;
		if (Math.abs(p.y) + ry > limit) return false;
	}
	return true;
}

/**
 * 把所有关键点塞进画面所需的最小相机距离。
 *
 * 距离越大画面越广 ⇒ 约束单调，可以二分；每一步只在“确实装得下”时收紧上界，
 * 所以返回值**一定**满足约束（两个端点都装不下时退化为 maxDistance）。
 */
function fitDistance(
	points: P2[],
	centerX: number,
	centerY: number,
	probeRadius: number,
	opts: RigOptions,
	radii?: number[],
): number {
	const lo = opts.minDistance;
	const hi = opts.maxDistance;
	if (frameFits(points, centerX, centerY, lo, probeRadius, opts, radii)) return lo;
	if (!frameFits(points, centerX, centerY, hi, probeRadius, opts, radii)) return hi;

	let a = lo;
	let b = hi;
	for (let i = 0; i < 24; i++) {
		const mid = (a + b) / 2;
		if (frameFits(points, centerX, centerY, mid, probeRadius, opts, radii)) b = mid; else a = mid;
	}
	return b;
}

/**
 * 纯计算：根据关键点集合，算出这一帧的相机参数。
 *
 * `points` 中应包含探测器、行星与目标；**约定 points[0] = 探测器**（`probeRadius` 只作用于它）。
 */
export function computeRigStep(
	state: RigState,
	points: P2[],
	opts: RigOptions,
	probeRadius?: number,
	/** 逐个关键点的外接半径（S3.12）：太阳这类大体量天体必须完整在画面内，不能压边。 */
	radii?: number[],
): RigFrame {
	const fit = computeFit(points);
	const radius = probeRadius !== undefined ? probeRadius : 0;

	const wantDistance = fitDistance(points, fit.centerX, fit.centerY, radius, opts, radii);

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

	// 相机在注视点的斜上方：倾角决定高度/进深比例。
	return frameAt(state.focusX, state.focusY, state.distance, opts);
}

/** 创建一个机架（持有平滑状态）。 */
export function createCameraRig(opts?: RigOptions): CameraRig {
	const options = opts !== undefined ? opts : defaultRigOptions();
	const state: RigState = { focusX: 0, focusY: 0, distance: options.minDistance, initialized: false };

	return {
		step: (points: P2[], probeRadius?: number, radii?: number[], minDistance?: number): RigFrame => {
			// S3.17：慢动作特写的下限覆盖。只复制要改的那一个字段（TSTL 对对象展开的支持面窄，
			// 显式列一遍最稳）；传了更大/非法的值就忽略，日常取景的下限不许被顶下去。
			let opts = options;
			if (minDistance !== undefined && minDistance > 0 && minDistance < options.minDistance) {
				opts = {
					tiltDeg: options.tiltDeg,
					minDistance,
					maxDistance: options.maxDistance,
					lerp: options.lerp,
					fovYDeg: options.fovYDeg,
					aspect: options.aspect,
					margin: options.margin,
				};
			}
			return computeRigStep(state, points, opts, probeRadius, radii);
		},
		// 纯查询：**不改机架状态**地算出"这组关键点需要多远"（取景预算判断用，S3.12）
		wantDistance: (points: P2[], probeRadius?: number, radii?: number[]): number => {
			const fit = computeFit(points);
			return fitDistance(points, fit.centerX, fit.centerY, probeRadius !== undefined ? probeRadius : 0, options, radii);
		},
		apply: (camera: Camera3D.Type, frame: RigFrame): void => {
			camera.lookAt(frame.eye, frame.target, Vec3(0, 1, 0));
		},
		reset: (): void => {
			state.focusX = 0;
			state.focusY = 0;
			state.distance = options.minDistance;
			state.initialized = false;
		},
	};
}
