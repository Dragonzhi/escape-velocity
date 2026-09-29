/** Player-owned orbit pose. Display time only; never changes simulation. */
export interface ObservePoint { x: number; y: number; z: number; }
export interface ObserveFrame { eye: ObservePoint; target: ObservePoint; }
export interface ObservePose {
	yaw: number; pitch: number; distance: number; targetDistance: number; age: number;
	offset: ObservePoint;
}
export function captureObserve(frame: ObserveFrame, anchor: ObservePoint, targetDistance?: number): ObservePose {
	const x = frame.eye.x - frame.target.x, y = frame.eye.y - frame.target.y, z = frame.eye.z - frame.target.z;
	const distance = Math.sqrt(x * x + y * y + z * z);
	return { yaw: Math.atan2(x, z) * 180 / Math.PI, pitch: Math.asin(y / Math.max(distance, 0.000001)) * 180 / Math.PI,
		distance, targetDistance: targetDistance !== undefined ? targetDistance : distance, age: 0, offset: { x: frame.target.x - anchor.x, y: frame.target.y - anchor.y, z: frame.target.z - anchor.z } };
}
export function rotateObserve(pose: ObservePose, dx: number, dy: number): void {
	pose.yaw -= dx * 0.22;
	pose.pitch = Math.max(16, Math.min(75, pose.pitch + dy * 0.16));
}
export function zoomObserve(pose: ObservePose, delta: number, min: number, max: number): void {
	pose.distance = Math.max(min, Math.min(max, pose.distance * Math.exp(-delta * 0.002)));
	pose.targetDistance = Math.max(min, Math.min(max, pose.targetDistance * Math.exp(-delta * 0.002)));
}
export function stepObserve(pose: ObservePose, anchor: ObservePoint, dt: number): ObserveFrame {
	pose.age += Math.max(0, dt);
	const u = Math.min(1, pose.age / 0.6), remaining = 1 - u * u * (3 - 2 * u);
	const target = { x: anchor.x + pose.offset.x * remaining, y: anchor.y + pose.offset.y * remaining, z: anchor.z + pose.offset.z * remaining };
	const yaw = pose.yaw * Math.PI / 180, pitch = pose.pitch * Math.PI / 180, r = pose.distance * remaining + pose.targetDistance * (1 - remaining);
	return { target, eye: { x: target.x + r * Math.cos(pitch) * Math.sin(yaw), y: target.y + r * Math.sin(pitch), z: target.z + r * Math.cos(pitch) * Math.cos(yaw) } };
}
