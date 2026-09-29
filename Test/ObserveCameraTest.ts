import { captureObserve, rotateObserve, stepObserve, zoomObserve } from 'game/ObserveCamera';

export function runTests(): string {
	let checks = 0;
	const failures: string[] = [];
	const check = (name: string, ok: boolean): void => { checks++; if (!ok) failures.push(name); };
	const anchor = { x: 10, y: 0, z: 20 };
	const frame = { eye: { x: 60, y: 50, z: 100 }, target: { x: 20, y: 0, z: 30 } };
	const pose = captureObserve(frame, anchor);
	const first = stepObserve(pose, anchor, 0);
	check('handoff eye continuous', Math.abs(first.eye.x - frame.eye.x) < 1e-8 && Math.abs(first.eye.y - frame.eye.y) < 1e-8 && Math.abs(first.eye.z - frame.eye.z) < 1e-8);
	check('handoff target continuous', first.target.x === frame.target.x && first.target.z === frame.target.z);
	rotateObserve(pose, 100, 20);
	check('selection sensitivity', Math.abs(pose.yaw - (Math.atan2(40, 70) * 180 / Math.PI - 22)) < 1e-8);
	const done = stepObserve(pose, anchor, 0.6);
	check('probe centered after blend', done.target.x === anchor.x && done.target.z === anchor.z);
	const moved = stepObserve(pose, { x: 17, y: 3, z: 24 }, 0);
	check('translation preserves player orbit', Math.abs(moved.eye.x - done.eye.x - 7) < 1e-8 && Math.abs(moved.eye.z - done.eye.z - 4) < 1e-8);
	const paused = stepObserve(pose, { x: 17, y: 3, z: 24 }, 0);
	check('paused pose stable', paused.eye.x === moved.eye.x && paused.eye.z === moved.eye.z);
	rotateObserve(pose, 0, 10000); check('upper pitch', pose.pitch === 75);
	rotateObserve(pose, 0, -10000); check('lower pitch', pose.pitch === 16);
	zoomObserve(pose, 100000, 65, 2000); check('near limit', pose.distance === 65 && pose.targetDistance === 65);
	zoomObserve(pose, -100000, 65, 2000); check('far limit', pose.distance === 2000 && pose.targetDistance === 2000);
	const focus = captureObserve(frame, anchor, 432);
	stepObserve(focus, anchor, 0.6);
	check('focus distance blends', Math.abs(Math.sqrt(40 * 40 + 50 * 50 + 70 * 70) - focus.distance) < 1e-8 && focus.targetDistance === 432);
	const a = captureObserve(frame, anchor), b = captureObserve(frame, anchor);
	const af = stepObserve(a, anchor, 0.3);
	let bf = stepObserve(b, anchor, 0);
	for (let i = 0; i < 30; i++) bf = stepObserve(b, anchor, 0.01);
	check('display blend frame rate independent', Math.abs(af.eye.x - bf.eye.x) < 1e-8 && Math.abs(af.target.z - bf.target.z) < 1e-8);
	return (failures.length === 0 ? 'passed' : 'failed') + '\nchecks=' + checks + '\n' + failures.join('\n');
}
