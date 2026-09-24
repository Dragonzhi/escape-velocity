/**
 * 3D 世界 → 2D 屏幕投影（纯函数，不依赖引擎，可测）。
 *
 * 背景（手册 §11 R4）：Dora 的 View3D 只提供屏幕→世界的射线
 * （getRayOrigin / getRayDirection），**没有**反向投影，也没有矩阵 API。
 * 但轨迹线要画在 2D 覆盖层上（Line 只吃 Vec2[]），所以必须自建投影。
 *
 * ===== 已实测标定的约定（Test/ProjectionProbe.ts，R4 已关闭）=====
 *
 * 1) `View3D.getRayDirection/getRayOrigin/getRayOrigin.pick` 的 viewPoint
 *    使用 **像素坐标、原点在屏幕左上角**：`x ∈ [0, W]`、`y ∈ [0, H]`（Y 向下）。
 *    实测：世界原点投影到 (W/2, H/2)。
 * 2) 相机手性为 **right = cross(forward, up)**（即本文件的 `HANDEDNESS = 1`）。
 * 3) `project()` 输出与 viewPoint **同一坐标空间的偏移量**，即：
 *      viewPoint.x = viewW / 2 + project().x
 *      viewPoint.y = viewH / 2 + project().y
 *    （`FLIP_Y = false`）。实测最大像素误差 1.56 px（2024×1230）。
 * 4) 渲染器会自动处理相机后方的点。
 *
 * ⚠️ 重要：本输出 **+Y 向下**（图像坐标），而 Dora 2D 节点（Director.ui 等）
 * 是 **中心原点、+Y 向上**。把投影结果画到覆盖层时，用 `toOverlay()` 转换，
 * 不要直接写下 `p.y`。
 */

/** 已实测确认的默认约定，业务代码直接用这两个常量。 */
export const HANDEDNESS: Handedness = 1;
export const FLIP_Y = false;

/** 用预计算的基把屏幕偏移量（与 project() 同空间）反投影成世界射线方向。 */
export function unprojectDirectionPrepared(screen: { x: number; y: number }, b: CameraBasis): V3 {
	const ndcX = (screen.x * 2) / b.viewW;
	const ndcY = ((b.flipY ? -screen.y : screen.y) * 2) / b.viewH;

	const vx = (ndcX * b.aspect) / b.focal;
	const vy = ndcY / b.focal;

	return normalize({
		x: b.forward.x + vx * b.right.x + vy * b.up.x,
		y: b.forward.y + vx * b.right.y + vy * b.up.y,
		z: b.forward.z + vx * b.right.z + vy * b.up.z,
	});
}

/**
 * 把屏幕偏移量（与 project() 同空间）反投影到世界 y = planeY 平面上。
 *
 * 用于“玩家拖到哪里” → “平面上的哪个点”。
 * 射线与平面平行、或交点在相机后方时返回 undefined。
 */
export function screenToPlaneY(
	screen: { x: number; y: number },
	b: CameraBasis,
	planeY: number,
): V3 | undefined {
	const dir = unprojectDirectionPrepared(screen, b);
	if (Math.abs(dir.y) < 1e-9) return undefined;

	// eye.y + t * dir.y = planeY
	const t = (planeY - b.eye.y) / dir.y;
	if (t <= 1e-6) return undefined;

	return {
		x: b.eye.x + t * dir.x,
		y: planeY,
		z: b.eye.z + t * dir.z,
	};
}

/**
 * 把 project() 的输出转成 Dora 2D 覆盖层坐标（中心原点、+Y 向上）。
 *
 * project() 输出 +Y 向下（图像坐标），而 Director.ui 等 2D 节点是
 * 中心原点 +Y 向上，所以这里只需翻转 y。
 */
export function toOverlay(p: Projected): { x: number; y: number } {
	return { x: p.x, y: -p.y };
}

/**
 * 预计算的相机基。
 *
 * 轨迹每帧要投影数百个点。`project()` 每次都重算
 * f / r / u / focal，变成大量重复运算。
 * 这里把相机的基向量算一次，然后用 `projectPrepared` 逐个投影。
 * 两者必须给出**完全一致**的结果（由回归测试守着）。
 */
export interface CameraBasis {
	eye: V3;
	forward: V3;
	right: V3;
	up: V3;
	focal: number;
	aspect: number;
	viewW: number;
	viewH: number;
	flipY: boolean;
}

/** 预计算相机基（每帧调一次）。 */
export function prepareCamera(
	cam: CameraView,
	handedness: Handedness,
	flipY: boolean,
): CameraBasis {
	const f = normalize(sub(cam.target, cam.eye));
	const up = normalize(cam.up);
	const r = handedness === 0 ? normalize(cross(up, f)) : normalize(cross(f, up));
	const u = handedness === 0 ? cross(f, r) : cross(r, f);

	return {
		eye: { x: cam.eye.x, y: cam.eye.y, z: cam.eye.z },
		forward: f,
		right: r,
		up: u,
		focal: 1 / Math.tan((cam.fovYDeg * Math.PI / 180) / 2),
		aspect: cam.aspect,
		viewW: cam.viewW,
		viewH: cam.viewH,
		flipY,
	};
}

/** 用预计算的基投影一个点。语义与 `project()` 一致。 */
export function projectPrepared(p: V3, b: CameraBasis): Projected | undefined {
	const dx = p.x - b.eye.x;
	const dy = p.y - b.eye.y;
	const dz = p.z - b.eye.z;

	const vz = dx * b.forward.x + dy * b.forward.y + dz * b.forward.z;
	if (vz <= 1e-6) return undefined;

	const vx = dx * b.right.x + dy * b.right.y + dz * b.right.z;
	const vy = dx * b.up.x + dy * b.up.y + dz * b.up.z;

	const ndcX = (vx / vz) * b.focal / b.aspect;
	const ndcY = (vy / vz) * b.focal;

	return {
		x: (ndcX * b.viewW) / 2,
		y: ((b.flipY ? -ndcY : ndcY) * b.viewH) / 2,
		vz,
	};
}

export interface V3 {
	x: number;
	y: number;
	z: number;
}

/** 相机与视图参数（全部为纯数字，脱离引擎对象）。 */
export interface CameraView {
	eye: V3;
	target: V3;
	up: V3;
	/** 垂直视野角，单位度。 */
	fovYDeg: number;
	/** 视图宽高比 width / height。 */
	aspect: number;
	viewW: number;
	viewH: number;
}

/** 手性约定：0 = right = cross(up, forward)（左手系）；1 = right = cross(forward, up)。 */
export type Handedness = 0 | 1;

export interface Projected {
	x: number;
	y: number;
	/** 相机空间深度（正值 = 相机前方）。 */
	vz: number;
}

function sub(a: V3, b: V3): V3 {
	return { x: a.x - b.x, y: a.y - b.y, z: a.z - b.z };
}

function cross(a: V3, b: V3): V3 {
	return {
		x: a.y * b.z - a.z * b.y,
		y: a.z * b.x - a.x * b.z,
		z: a.x * b.y - a.y * b.x,
	};
}

function dot(a: V3, b: V3): number {
	return a.x * b.x + a.y * b.y + a.z * b.z;
}

function length(a: V3): number {
	return Math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z);
}

function normalize(a: V3): V3 {
	const l = length(a);
	if (l < 1e-9) return { x: 0, y: 0, z: 0 };
	return { x: a.x / l, y: a.y / l, z: a.z / l };
}

/** 两向量叉积的模长（并行度度量，用于一致性校验）。 */
export function crossLength(a: V3, b: V3): number {
	return length(cross(a, b));
}

export function dotProduct(a: V3, b: V3): number {
	return dot(a, b);
}

export function vecLength(a: V3): number {
	return length(a);
}

/**
 * 把世界坐标点投影到屏幕视图坐标。
 *
 * 默认调用参数用 `HANDEDNESS` / `FLIP_Y`（已实测标定）。
 * 输出语义见文件头：viewPoint = view 中心 + 本返回值，+Y 向下。
 *
 * @returns 投影结果；点在相机后方（或太近）时返回 undefined。
 */
export function project(
	p: V3,
	cam: CameraView,
	handedness: Handedness,
	flipY: boolean,
): Projected | undefined {
	const f = normalize(sub(cam.target, cam.eye));
	const up = normalize(cam.up);

	const r = handedness === 0 ? normalize(cross(up, f)) : normalize(cross(f, up));
	const u = handedness === 0 ? cross(f, r) : cross(r, f);

	const d = sub(p, cam.eye);
	const vz = dot(d, f);
	if (vz <= 1e-6) return undefined;

	const vx = dot(d, r);
	const vy = dot(d, u);

	// 透视：ndc = (v / vz) / tan(fov/2)，x 再除宽高比。
	const focal = 1 / Math.tan((cam.fovYDeg * Math.PI / 180) / 2);
	const ndcX = (vx / vz) * focal / cam.aspect;
	const ndcY = (vy / vz) * focal;

	return {
		x: (ndcX * cam.viewW) / 2,
		y: ((flipY ? -ndcY : ndcY) * cam.viewH) / 2,
		vz,
	};
}

/**
 * 把一个屏幕视图坐标点（中心原点，+Y 向上）反投影成世界坐标射线。
 * 用于自测：应该与 View3D.getRayOrigin/getRayDirection 一致。
 */
export function unprojectDirection(
	screen: { x: number; y: number },
	cam: CameraView,
	handedness: Handedness,
	flipY: boolean,
): V3 {
	const f = normalize(sub(cam.target, cam.eye));
	const up = normalize(cam.up);
	const r = handedness === 0 ? normalize(cross(up, f)) : normalize(cross(f, up));
	const u = handedness === 0 ? cross(f, r) : cross(r, f);

	const focal = 1 / Math.tan((cam.fovYDeg * Math.PI / 180) / 2);
	const ndcX = (screen.x * 2) / cam.viewW;
	const ndcY = ((flipY ? -screen.y : screen.y) * 2) / cam.viewH;

	const vx = (ndcX * cam.aspect / focal) * 1;
	const vy = (ndcY / focal) * 1;

	// 方向 = f + vx * r + vy * u（透视射线）。
	return normalize({
		x: f.x + vx * r.x + vy * u.x,
		y: f.y + vx * r.y + vy * u.y,
		z: f.z + vx * r.z + vy * u.z,
	});
}
