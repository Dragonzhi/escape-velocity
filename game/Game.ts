/**
 * 游戏状态机与主循环逻辑（S1.5）。
 *
 * 阶段流转（手册 §4.3）：
 *
 *     Aiming --松手--> Flying --结局确定--> Result --重试--> Aiming
 *
 * - **Aiming**：全局冻结（D2）。行星停在相位 0，探测器在起点；
 *   拖动实时重画预测线；松手即发射（不可撤销）。
 * - **Flying**：物理时间从 0 推进；行星公转、探测器沿预推演轨迹飞行；
 *   相机跟随拉远；尾迹逐帧累积。
 * - **Result**：冻结画面，展示三态（成功/错过/撞毁，§5.8）；
 *   等待“重试本关”（返回关卡选择在 S2.3）。
 *
 * ===== 确定性设计（验收硬指标）=====
 *
 * 发射瞬间用与预测线**完全相同的** `simulate` 预推演整段飞行，
 * 之后逐帧**回放**。因为物理是确定性的（S1.1 已证逐位一致），
 * 回放 == 实时积分，但保证了“预测线看见的就是飞出来的”，
 * 且结局判定（§5.8）也在发射瞬间就确定 —— 与 D2 的时间模型自洽。
 *
 * 分层：`GameCore`（纯逻辑，可单测）+ `createGame`（驱动引擎对象）。
 */
import { Camera3D } from 'Dora';
import { AimInput, AimResult } from 'game/Hud';
import { Body, Outcome, P2, SimResult, bodyPositionAt, simulate, sub } from 'game/Gravity';
import { GameScene, planeToWorld } from 'game/Scene';
import { CameraRig } from 'game/CameraRig';
import { TrajectoryView } from 'game/Trajectory';
import { CameraBasis, FLIP_Y, HANDEDNESS, prepareCamera, projectPrepared } from 'game/Projection';
import { AimMinSpeed, FlightPlayback, PhysicsStep, PredictSteps } from 'game/Config';

/** 游戏阶段。 */
export type GamePhase = 'Aiming' | 'Flying' | 'Result';

/** 结算三态（手册 §5.8）。 */
export type ResultKind = 'success' | 'missed' | 'crashed';

/**
 * 物理结局 → 结算三态。
 *
 * S1 测试关：飞出边界 = 逃逸成功。
 * S2 接入关卡数据后，按“目标行星到达容差”细化（§5.8）。
 */
export function resolveOutcome(outcome: Outcome): ResultKind {
	if (outcome === 'crashed') return 'crashed';
	if (outcome === 'escaped') return 'success';
	return 'missed'; // 步数用尽 = 超时错过
}

/** 一关的物理定义（S2 会扩展视觉与文案）。 */
export interface GameLevel {
	bodies: Body[];
	probeStart: P2;
	escapeRadius: number;
	maxSteps: number;
}

/**
 * 状态机核心（纯逻辑，不碰引擎对象，可单测）。
 */
export interface GameCore {
	phase: GamePhase;
	/** 当前矄准（Aiming 态有意义）。 */
	aim: AimResult;
	/** 发射时预推演的完整轨迹（Flying/Result 态有意义）。 */
	flight: SimResult | undefined;
	/** 物理步长（回放索引用）。 */
	dt: number;
	/** 飞行已播放的物理时间（秒）。 */
	flightTime: number;
	/** 结算三态（Result 态有意义）。 */
	result: ResultKind | undefined;
}

export function createCore(): GameCore {
	return {
		phase: 'Aiming',
		aim: { velocity: { x: 0, y: -AimMinSpeed }, power: 0, unit: { x: 0, y: -1 } },
		flight: undefined,
		dt: PhysicsStep,
		flightTime: 0,
		result: undefined,
	};
}

/** 发射：预推演整段飞行并进入 Flying。只在 Aiming 态有效。 */
export function coreLaunch(core: GameCore, velocity: P2, level: GameLevel): void {
	if (core.phase !== 'Aiming') return;
	core.flight = simulate(
		{ pos: { x: level.probeStart.x, y: level.probeStart.y }, vel: { x: velocity.x, y: velocity.y } },
		level.bodies,
		{ steps: level.maxSteps, dt: core.dt, sampleEvery: 1, escapeRadius: level.escapeRadius },
	);
	core.flightTime = 0;
	core.phase = 'Flying';
}

/** 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。 */
export function coreProbeIndex(core: GameCore): number {
	if (core.flight === undefined) return 0;
	let idx = Math.floor(core.flightTime / core.dt);
	const last = core.flight.points.length - 1;
	if (idx > last) idx = last;
	if (idx < 0) idx = 0;
	return idx;
}

/**
 * 推进核心状态。返回 true 表示这一帧进入了 Result。
 */
export function coreUpdate(core: GameCore, dt: number): boolean {
	if (core.phase !== 'Flying' || core.flight === undefined) return false;
	core.flightTime += dt * FlightPlayback;
	if (coreProbeIndex(core) >= core.flight.points.length - 1) {
		core.phase = 'Result';
		core.result = resolveOutcome(core.flight.outcome);
		return true;
	}
	return false;
}

/** 重试本关：回到 Aiming，清空飞行与结算。 */
export function coreRetry(core: GameCore): void {
	core.phase = 'Aiming';
	core.flight = undefined;
	core.flightTime = 0;
	core.result = undefined;
	core.aim = { velocity: { x: 0, y: -AimMinSpeed }, power: 0, unit: { x: 0, y: -1 } };
}

/** 引擎侧依赖（由 init.ts 组装）。 */
export interface GameDeps {
	scene: GameScene;
	camera: Camera3D.Type;
	rig: CameraRig;
	trajectory: TrajectoryView;
	aim: AimInput;
	viewW: number;
	viewH: number;
	fovYDeg: number;
	aspect: number;
	/** 阶段变化回调（驱动 UI 显隐）。 */
	onPhase: (p: GamePhase) => void;
	/** 结算回调（驱动结果面板）。 */
	onResult: (r: ResultKind) => void;
}

/** 游戏句柄（全部属性式函数，见 Hud.ts 的说明）。 */
export interface Game {
	phase: () => GamePhase;
	result: () => ResultKind | undefined;
	/** 拖动回调（接到 aim.onDrag）。 */
	onAimDrag: (a: AimResult) => void;
	/** 发射（接到 aim.onRelease）。 */
	launch: (v: P2) => void;
	/** 重试本关。 */
	retry: () => void;
	/** 每帧调用一次。 */
	update: (dt: number) => void;
}

/** 组装游戏（状态机 + 引擎驱动）。 */
export function createGame(level: GameLevel, deps: GameDeps): Game {
	const core = createCore();
	let aimDirty = true;

	const makeBasis = (frame: { eye: { x: number; y: number; z: number }; target: { x: number; y: number; z: number } }): CameraBasis => {
		return prepareCamera(
			{
				eye: { x: frame.eye.x, y: frame.eye.y, z: frame.eye.z },
				target: { x: frame.target.x, y: frame.target.y, z: frame.target.z },
				up: { x: 0, y: 1, z: 0 },
				fovYDeg: deps.fovYDeg,
				aspect: deps.aspect,
				viewW: deps.viewW,
				viewH: deps.viewH,
			},
			HANDEDNESS,
			FLIP_Y,
		);
	};

	const updateAiming = (): void => {
		deps.aim.setEnabled(true);
		deps.scene.syncBodies(0); // D2：矄准态全局冻结
		deps.scene.syncProbe(level.probeStart);

		const planetPts: P2[] = [];
		for (const p of deps.scene.planets) planetPts.push(bodyPositionAt(p.def, 0));

		const frame = deps.rig.step([level.probeStart, ...planetPts]);
		deps.rig.apply(deps.camera, frame);
		const basis = makeBasis(frame);

		// 探测器屏幕位置（拖动方向的基准）
		const pp = projectPrepared(planeToWorld(level.probeStart, 0), basis);
		if (pp !== undefined) deps.aim.setProbeOffset({ x: pp.x, y: pp.y });

		if (aimDirty) {
			const pred = simulate(
				{ pos: { x: level.probeStart.x, y: level.probeStart.y }, vel: { x: core.aim.velocity.x, y: core.aim.velocity.y } },
				level.bodies,
				{ steps: PredictSteps, dt: core.dt, sampleEvery: 4, escapeRadius: level.escapeRadius },
			);
			deps.trajectory.setPrediction(pred.points, basis);
			deps.trajectory.clearTrail();
			aimDirty = false;
		}
	};

	const updateFlying = (dt: number): boolean => {
		deps.aim.setEnabled(false);
		const entered = coreUpdate(core, dt);
		if (core.flight === undefined) return entered;

		const idx = coreProbeIndex(core);
		const pos = core.flight.points[idx];
		const t = core.flightTime;

		deps.scene.syncBodies(t);
		deps.scene.syncProbe(pos);
		if (idx > 0) {
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx - 1]));
		}

		const planetPts: P2[] = [];
		for (const p of deps.scene.planets) planetPts.push(bodyPositionAt(p.def, t));

		const frame = deps.rig.step([pos, ...planetPts]);
		deps.rig.apply(deps.camera, frame);
		const basis = makeBasis(frame);

		// 尾迹 = 已飞过的前缀
		const trail: P2[] = [];
		for (let i = 0; i <= idx; i++) trail.push(core.flight.points[i]);
		deps.trajectory.setTrail(trail, basis);

		return entered;
	};

	const update = (dt: number): void => {
		if (core.phase === 'Aiming') {
			updateAiming();
		} else if (core.phase === 'Flying') {
			const entered = updateFlying(dt);
			if (entered && core.result !== undefined) {
				deps.onResult(core.result);
				deps.onPhase('Result');
			}
		}
		// Result：画面冻结，等待重试输入
	};

	return {
		phase: (): GamePhase => core.phase,
		result: (): ResultKind | undefined => core.result,
		onAimDrag: (a: AimResult): void => {
			core.aim = a;
			aimDirty = true;
		},
		launch: (v: P2): void => {
			if (core.phase !== 'Aiming') return;
			coreLaunch(core, v, level);
			deps.trajectory.clearPrediction();
			deps.onPhase('Flying');
		},
		retry: (): void => {
			if (core.phase !== 'Result') return;
			coreRetry(core);
			deps.trajectory.clearTrail();
			deps.trajectory.clearPrediction();
			aimDirty = true;
			deps.onPhase('Aiming');
		},
		// 包一层箭头函数：简写属性会触发 TS100016（见 Hud.ts 同名注释）
		update: (frameDt: number): void => update(frameDt),
	};
}
