/**
 * 游戏状态机与主循环逻辑（S1.5）。
 *
 * 阶段流转（手册 §4.3）：
 *
 *     LevelSelect --选关--> Aiming --松手--> Flying --结局确定--> Result
 *        ^                                                            |
 *        +---------------- 返回关卡选择 ---------------+--重试--> Aiming
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
import { GoalSpec, findGoalIndex } from 'game/LevelData';
import { AimMinSpeed, FlightPlayback, PhysicsStep, PredictSteps } from 'game/Config';

/**
 * 游戏阶段。
 *
 * `LevelSelect`（S2.3）：关卡选择界面。核心状态机在这个阶段**什么也不推进**
 * （不跑物理、不画预测线），驱动它的只有 init.ts 的 UI 回调。
 */
export type GamePhase = 'Aiming' | 'Flying' | 'Result' | 'LevelSelect';

/** 结算三态（手册 §5.8）。 */
export type ResultKind = 'success' | 'missed' | 'crashed';

/**
 * 结算三态判定（手册 §5.8）。
 *
 * 优先级：到达目标 > 逃逸目标达成 > 撞毁 > 错过。
 * （到达目标优先于撞毁：轨迹在到达点截断，撞毁点根本不会发生。）
 *
 * 全部输入在**发射瞬间**即可确定 —— 结算与飞行一样是确定性的。
 */
export function resolveResult(outcome: Outcome, goalIndex: number, goal: GoalSpec): ResultKind {
	if (goalIndex >= 0) return 'success';
	if (goal.kind === 'escape' && outcome === 'escaped') return 'success';
	if (outcome === 'crashed') return 'crashed';
	return 'missed';
}

/** 一关的物理定义（由 LevelData 转换而来）。 */
export interface GameLevel {
	bodies: Body[];
	probeStart: P2;
	goal: GoalSpec;
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
	/** 第一个进入目标容差的采样点索引；-1 = 未到达。 */
	goalIndex: number;
	/** 结算三态（发射瞬间即确定；Result 态对外可见）。 */
	result: ResultKind | undefined;
}

export function createCore(): GameCore {
	return {
		phase: 'Aiming',
		aim: { velocity: { x: 0, y: -AimMinSpeed }, power: 0, unit: { x: 0, y: -1 } },
		flight: undefined,
		dt: PhysicsStep,
		flightTime: 0,
		goalIndex: -1,
		result: undefined,
	};
}

/**
 * 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
 * 只在 Aiming 态有效。
 *
 * 结算在**这一刻**就完全确定（确定性设计的直接推论）：
 * 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
 */
export function coreLaunch(core: GameCore, velocity: P2, level: GameLevel): void {
	if (core.phase !== 'Aiming') return;
	const flight = simulate(
		{ pos: { x: level.probeStart.x, y: level.probeStart.y }, vel: { x: velocity.x, y: velocity.y } },
		level.bodies,
		{ steps: level.maxSteps, dt: core.dt, sampleEvery: 1, escapeRadius: level.escapeRadius },
	);
	core.flight = flight;
	core.goalIndex = findGoalIndex(flight.points, level.bodies, level.goal, core.dt);
	core.result = resolveResult(flight.outcome, core.goalIndex, level.goal);
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
 *
 * 飞行终点 = min(自然终点, 目标到达点)：到达目标即刻成功收束。
 * 收束时把回放时间吸附到终点索引，冻结帧恰好停在到达/终点的位置。
 */
export function coreUpdate(core: GameCore, dt: number): boolean {
	if (core.phase !== 'Flying' || core.flight === undefined) return false;
	core.flightTime += dt * FlightPlayback;
	const naturalEnd = core.flight.points.length - 1;
	const endIdx = core.goalIndex >= 0 && core.goalIndex < naturalEnd ? core.goalIndex : naturalEnd;
	if (coreProbeIndex(core) >= endIdx) {
		// 吸附到终点：回放每帧跳多个索引，可能越过终点几个采样点
		core.flightTime = endIdx * core.dt;
		core.phase = 'Result';
		return true;
	}
	return false;
}

/** 重试本关：回到 Aiming，清空飞行与结算。 */
export function coreRetry(core: GameCore): void {
	core.phase = 'Aiming';
	core.flight = undefined;
	core.flightTime = 0;
	core.goalIndex = -1;
	core.result = undefined;
	core.aim = { velocity: { x: 0, y: -AimMinSpeed }, power: 0, unit: { x: 0, y: -1 } };
}

/**
 * 返回关卡选择（S2.3，决策 D5）。
 *
 * **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
 * 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
 *
 * 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
 * 时短暂读到上一局的终态。
 *
 * @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
 */
export function coreBackToSelect(core: GameCore): boolean {
	if (core.phase !== 'Result') return false;
	core.phase = 'LevelSelect';
	core.flight = undefined;
	core.flightTime = 0;
	core.goalIndex = -1;
	core.result = undefined;
	return true;
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
	/** 重试本关（仅 Result 态有效）。 */
	retry: () => void;
	/**
	 * 返回关卡选择（仅 Result 态有效；非 Result 态什么都不做）。
	 *
	 * @returns 是否切换成功。
	 */
	backToSelect: () => boolean;
	/**
	 * 从关卡选择**进入本关**：把核心重置回 Aiming（S2.3）。
	 *
	 * 与 `retry` 的区别：`retry` 只允许从 Result 出（“再来一次刚才那局”），
	 * 而选关是“开始一局新的”，必须能从 LevelSelect 进。
	 */
	startLevel: () => void;
	/** 每帧调用一次。 */
	update: (dt: number) => void;
}

/** 组装游戏（状态机 + 引擎驱动）。 */
export function createGame(level: GameLevel, deps: GameDeps): Game {
	const core = createCore();

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

		// ⚠️ 预测线必须**每帧**重画，不能只在拖动时重画：
		// 重试后相机会用 lerp 从飞行终点视图滑回矄准视图（约 20-30 帧），
		// 若只在 aimDirty 时画一次，线会冻结在过渡中途的投影上，
		// 看起来“不是从探测器出发”（实测踩过）。
		// 代价：每帧 600 步 simulate + ~150 点投影，可忽略。
		const pred = simulate(
			{ pos: { x: level.probeStart.x, y: level.probeStart.y }, vel: { x: core.aim.velocity.x, y: core.aim.velocity.y } },
			level.bodies,
			{ steps: PredictSteps, dt: core.dt, sampleEvery: 4, escapeRadius: level.escapeRadius },
		);
		deps.trajectory.setPrediction(pred.points, basis);
		deps.trajectory.clearTrail();
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
			deps.onPhase('Aiming');
		},
		backToSelect: (): boolean => {
			if (!coreBackToSelect(core)) return false;
			// 离开本关：线不能留在屏幕上（下一关会画自己的）
			deps.aim.setEnabled(false);
			deps.trajectory.clearTrail();
			deps.trajectory.clearPrediction();
			deps.onPhase('LevelSelect');
			return true;
		},
		startLevel: (): void => {
			// 复用 coreRetry 的“清空一切回到 Aiming”：它对相态没有守卫，
			// 正好当作“重置本关”用（coreRetry 本身不改）。
			coreRetry(core);
			deps.trajectory.clearTrail();
			deps.trajectory.clearPrediction();
			deps.onPhase('Aiming');
		},
		// 包一层箭头函数：简写属性会触发 TS100016（见 Hud.ts 同名注释）
		update: (frameDt: number): void => update(frameDt),
	};
}
