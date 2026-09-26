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
import { Camera3D, Vec3 } from 'Dora';
import { AimInput, AimResult } from 'game/Hud';
import { Body, BrakeThrust, Outcome, P2, SimResult, bodyPositionAt, simulate, sub } from 'game/Gravity';
import { GameScene, planeToWorld } from 'game/Scene';
import { CameraRig } from 'game/CameraRig';
import { GoalRing, TrajectoryView } from 'game/Trajectory';
import { CameraBasis, FLIP_Y, HANDEDNESS, prepareCamera, projectPrepared } from 'game/Projection';
import { GoalSpec, findGoalIndex, goalWaypoints, waypointProgress } from 'game/LevelData';
import { AimMinSpeed, BrakeShare, FlightPlayback, IntroCloseDist, IntroDurationSec, PhysicsStep, PredictSteps } from 'game/Config';

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
	/** 出发时已有的速度（S3.9.3，L1 = 绕地球的圆轨道）；省略 = 静止出发。 */
	probeVel0?: P2;
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
	/**
	 * 刹车模式（S3.9.2）：开 = 点火只拿一半 Δv，另一半留给后半程反推（`maxSteps / 2` 起）。
	 * 玩家用 HUD 上的一颗按钮切；默认关（关 = 旧的"点火后惯性滑行"，手感不变）。
	 */
	brakeMode: boolean;
	/**
	 * 发射时刻（秒）= S3.6.4 时间轴上的"发射日期"。
	 * 行星位置、预测线、真实飞行**必须**用同一个 t0（否则又变成"看到的 ≠ 飞到的"）。
	 */
	t0: number;
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
		brakeMode: false,
		t0: 0,
		flightTime: 0,
		goalIndex: -1,
		result: undefined,
	};
}

/**
 * 把"点火"折算成 (初始速度, 反推段) —— **预测线与真实发射共用这一份**（S3.9.2）。
 *
 * - 总初速度 = 出发时已有的速度（L1 = 绕地球的圆轨道）+ 点火；
 * - 刹车模式下点火只拿 `BrakeShare`，剩下的 Δv 交给后半程反推（开始于 `maxSteps / 2`）。
 *
 * 两边各写一份是这类系统最容易烂的地方：改了一边忘了另一边，就变成"看到的 ≠ 飞到的"。
 */
/**
 * 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
 * 只在 Aiming 态有效。
 *
 * 结算在**这一刻**就完全确定（确定性设计的直接推论）：
 * 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
 */
export function burnToMotion(
	burn: P2,
	probeVel0: P2 | undefined,
	brakeMode: boolean,
	maxSteps: number,
): { init: P2; brake: BrakeThrust | undefined } {
	const v0 = probeVel0 !== undefined ? probeVel0 : { x: 0, y: 0 };
	const share = brakeMode ? BrakeShare : 1;
	const init: P2 = { x: v0.x + burn.x * share, y: v0.y + burn.y * share };
	const mag = Math.sqrt(burn.x * burn.x + burn.y * burn.y);
	const brake = brakeMode && mag > 0
		? { dv: mag * (1 - share), startStep: Math.floor(maxSteps / 2) }
		: undefined;
	return { init, brake };
}

/**
 * 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
 *
 * `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
 * 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
 */
export function coreLaunch(core: GameCore, burn: P2, level: GameLevel, from?: P2, vel0?: P2): void {
	if (core.phase !== 'Aiming') return;
	const base = vel0 !== undefined ? vel0 : level.probeVel0;
	const motion = burnToMotion(burn, base, core.brakeMode, level.maxSteps);
	const p0 = from !== undefined ? from : level.probeStart;
	const flight = simulate(
		{ pos: { x: p0.x, y: p0.y }, vel: motion.init },
		level.bodies,
		{ steps: level.maxSteps, dt: core.dt, sampleEvery: 1, escapeRadius: level.escapeRadius, t0: core.t0, brake: motion.brake },
	);
	core.flight = flight;
	core.goalIndex = findGoalIndex(flight.points, level.bodies, level.goal, core.dt, core.t0, flight.velocities);
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
	/**
	 * 设定发射日期（S3.9.2c，秒）：行星相位、预测线、待机轨迹都跟着它走。
	 * 只有带 `timeWindow` 的关卡会调它。
	 */
	setLaunchDate: (t0: number) => void;
	/** 刹车模式（S3.9.2）：开 = 一半点火、一半留给后半程反推。默认关。 */
	setBrakeMode: (on: boolean) => void;
	/** 读当前刹车模式（HUD 按钮同步用）。 */
	brakeMode: () => boolean;
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

	// 预测线的缓存（S3.7）：PredictSteps 提到 2400（覆盖整段飞行）之后，**每帧重算**会吃掉整帧预算
	// （引擎启动时实测把主线程堵到 API 都超时）。所以只在"瞄准或日期变了"时重算，其余帧只重投影。
	let predKey = '';
	let predPoints: P2[] = [];
	// 进关镜头（S3.9）：从"贴着探测器"缓动到"自动取景"（能看见下一站），1.4 秒；一拖就跳过。
	let introT = IntroDurationSec;
	let introLogged = false;

	// ---- 待机时钟（S3.9.4）----
	// 用户："飞行器不进行操控的时候会按照时间尺度绕地球转，在操控的时候时间变成超级慢或者干脆暂停。"
	// 实现：`clock` 只在**没在拖**的时候走；`idlePath` 是"不点火时探测器自己会飞成什么样"（进关时算一次），
	// 于是待机时探测器沿着它走、预测线就是它的后半段 —— 不用每帧重算，也不会和真实飞行分家。
	let clock = 0;
	let idlePath: SimResult | undefined = undefined;
	/** 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。 */
	let probePos: P2 = { x: level.probeStart.x, y: level.probeStart.y };
	let probeVel: P2 = level.probeVel0 !== undefined ? level.probeVel0 : { x: 0, y: 0 };
	const prepareIdle = (): void => {
		clock = 0;
		if (level.probeVel0 === undefined) {
			idlePath = undefined;
			return;
		}
		idlePath = simulate(
			{ pos: { x: level.probeStart.x, y: level.probeStart.y }, vel: { x: level.probeVel0.x, y: level.probeVel0.y } },
			level.bodies,
			{ steps: level.maxSteps, dt: core.dt, sampleEvery: 1, escapeRadius: level.escapeRadius, t0: core.t0 },
		);
	};
	const idleIndex = (): number => {
		if (idlePath === undefined) return 0;
		const n = idlePath.points.length;
		if (n <= 1) return 0;
		let i = Math.floor(clock / core.dt) % n;
		if (i < 0) i = 0;
		return i;
	};

	/** 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。 */
	const goalRingsAt = (t: number, upto?: number): GoalRing[] => {
		const wps = goalWaypoints(level.goal);
		if (wps.length === 0) return [];
		let passed = 0;
		if (upto !== undefined && core.flight !== undefined) {
			passed = waypointProgress(core.flight.points, level.bodies, level.goal, core.dt, core.t0, upto, core.flight.velocities).passed;
		}
		// 只画**下一个**航点的环（S3.9 用户反馈："行星旁边的蓝色虚线圈是什么？"）。
		// 四个航点同时亮四个圈，加上灰色的行星轨道圈，看起来像两套轨道 —— 目标环的语义只有"下一站"，
		// 所以已经掠过的、还没轮到的都不画；掠过的航点靠 HUD 的航点灯表示。
		if (passed >= wps.length) return [];
		const nextWp = wps[passed];
		const body = level.bodies[nextWp.planetIndex];
		if (body === undefined) return [];
		return [{ center: bodyPositionAt(body, t), radius: nextWp.tolerance, passed: false }];
	};

	const updateAiming = (dt: number): void => {
		deps.aim.setEnabled(true);
		// S3.9.4 待机时钟：**没在操控**时世界照常走（探测器沿自己的轨道绕地球转），一按下就冻结。
		const dragging = deps.aim.isDragging();
		if (!dragging && idlePath !== undefined) clock += dt;
		const idx = idleIndex();
		probePos = idlePath !== undefined ? idlePath.points[idx] : level.probeStart;
		probeVel = idlePath !== undefined
			? idlePath.velocities[idx]
			: (level.probeVel0 !== undefined ? level.probeVel0 : { x: 0, y: 0 });
		const tNow = core.t0 + clock;

		deps.scene.syncBodies(tNow);
		deps.scene.syncProbe(probePos);
		if (idlePath !== undefined && idx > 0) deps.scene.faceVelocity(sub(probePos, idlePath.points[idx - 1]));

		const planetPts: P2[] = [];
		for (const p of deps.scene.planets) planetPts.push(bodyPositionAt(p.def, tNow));

		let frame = deps.rig.step([probePos, ...planetPts], deps.scene.probeRadius);
		// 进关镜头（S3.9）：先贴住探测器（"你正在轨道上"），再缓动到能看见下一站的取景。
		if (introT < IntroDurationSec) {
			introT += dt;
			let k = introT / IntroDurationSec;
			if (k > 1) k = 1;
			// 证据打点（只打一次）：进关镜头确实从"贴着探测器"拉到了"自动取景"。
			if (k >= 1 && !introLogged) {
				introLogged = true;
				const t = frame.target;
				print('[escape-velocity] intro camera: close=' + IntroCloseDist.toFixed(0) + ' -> wide=' + Math.sqrt((frame.eye.x - t.x) * (frame.eye.x - t.x) + (frame.eye.y - t.y) * (frame.eye.y - t.y) + (frame.eye.z - t.z) * (frame.eye.z - t.z)).toFixed(0));
			}
			const ease = 1 - (1 - k) * (1 - k) * (1 - k);
			const pw = planeToWorld(probePos, 0);
			let dx = frame.eye.x - frame.target.x;
			let dy = frame.eye.y - frame.target.y;
			let dz = frame.eye.z - frame.target.z;
			const len = Math.sqrt(dx * dx + dy * dy + dz * dz);
			if (len > 1e-6) {
				const s = IntroCloseDist / len;
				dx *= s; dy *= s; dz *= s;
			}
			const ctx = pw.x, cty = pw.y, ctz = pw.z;
			const cex = pw.x + dx, cey = pw.y + dy, cez = pw.z + dz;
			frame = {
				target: Vec3(ctx + (frame.target.x - ctx) * ease, cty + (frame.target.y - cty) * ease, ctz + (frame.target.z - ctz) * ease),
				eye: Vec3(cex + (frame.eye.x - cex) * ease, cey + (frame.eye.y - cey) * ease, cez + (frame.eye.z - cez) * ease),
			};
		}
		deps.rig.apply(deps.camera, frame);
		deps.scene.syncBackdrop(frame.eye, frame.target);
		const basis = makeBasis(frame);

		// 探测器屏幕位置（拖动方向的基准）
		const pp = projectPrepared(planeToWorld(probePos, 0), basis);
		if (pp !== undefined) deps.aim.setProbeOffset({ x: pp.x, y: pp.y });

		// ⚠️ 预测线必须**每帧**重画，不能只在拖动时重画：
		// 重试后相机会用 lerp 从飞行终点视图滑回瞄准视图（约 20-30 帧），
		// 若只在 aimDirty 时画一次，线会冻结在过渡中途的投影上，
		// 看起来“不是从探测器出发”（实测踩过）。
		// 代价：每帧 600 步 simulate + ~150 点投影，可忽略。
		// 只在瞄准/日期变化时重算（同一次拖动里每帧都算一遍是浪费；投影仍然每帧做）。
		if (!dragging && idlePath !== undefined) {
			// 待机：预测线 = "什么都不做会飞到哪" = 待机轨迹的**后半段**（不必重算）
			deps.trajectory.setPrediction(idlePath.points.slice(idx), basis);
		} else {
			const key = core.aim.velocity.x.toFixed(3) + '|' + core.aim.velocity.y.toFixed(3) + '|' + core.t0.toFixed(3) +
				'|' + (core.brakeMode ? 'B' : 'C') + '|' + idx.toFixed(0);
			if (key !== predKey) {
				predKey = key;
				// ⚠️ 与 coreLaunch 共用 burnToMotion：预测线里必须带上反推段，否则"看到的 ≠ 飞到的"
				// 基准是**此刻**的探测器状态（待机时它在动，不是 probeStart）。
				const motion = burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps);
				predPoints = simulate(
					{ pos: { x: probePos.x, y: probePos.y }, vel: motion.init },
					level.bodies,
					{ steps: PredictSteps, dt: core.dt, sampleEvery: 4, escapeRadius: level.escapeRadius, t0: tNow, brake: motion.brake },
				).points;
			}
			deps.trajectory.setPrediction(predPoints, basis);
		}
		deps.trajectory.setGoalRings(goalRingsAt(tNow), basis);
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

		const frame = deps.rig.step([pos, ...planetPts], deps.scene.probeRadius);
		deps.rig.apply(deps.camera, frame);
		deps.scene.syncBackdrop(frame.eye, frame.target);
		const basis = makeBasis(frame);

		// 尾迹 = 已飞过的前缀
		const trail: P2[] = [];
		for (let i = 0; i <= idx; i++) trail.push(core.flight.points[i]);
		deps.trajectory.setTrail(trail, basis);
		deps.trajectory.setGoalRings(goalRingsAt(t, idx), basis);

		return entered;
	};

	const update = (dt: number): void => {
		if (core.phase === 'Aiming') {
			updateAiming(dt);
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
			introT = IntroDurationSec; // 玩家一动手就跳过进关镜头（操作权优先）
		},
		launch: (v: P2): void => {
			if (core.phase !== 'Aiming') return;
			// v 是"点火"；从**此刻**的探测器状态出发（待机时它一直在绕地球走）
			coreLaunch(core, v, level, probePos, probeVel);
			deps.trajectory.clearPrediction();
			deps.onPhase('Flying');
		},
		retry: (): void => {
			if (core.phase !== 'Result') return;
			coreRetry(core);
			deps.trajectory.clearTrail();
			deps.trajectory.clearPrediction();
			deps.trajectory.clearGoalRings();
			deps.onPhase('Aiming');
		},
		backToSelect: (): boolean => {
			if (!coreBackToSelect(core)) return false;
			// 离开本关：线不能留在屏幕上（下一关会画自己的）
			deps.aim.setEnabled(false);
			deps.trajectory.clearTrail();
			deps.trajectory.clearPrediction();
			deps.trajectory.clearGoalRings();
			deps.onPhase('LevelSelect');
			return true;
		},
		startLevel: (): void => {
			// 复用 coreRetry 的“清空一切回到 Aiming”：它对相态没有守卫，
			// 正好当作“重置本关”用（coreRetry 本身不改）。
			coreRetry(core);
			introT = 0; // 从选关进来才放一遍进关镜头（重试不重放）
			introLogged = false;
			prepareIdle();
			deps.trajectory.clearTrail();
			deps.trajectory.clearPrediction();
			deps.trajectory.clearGoalRings();
			deps.onPhase('Aiming');
		},
		setLaunchDate: (t0: number): void => {
			core.t0 = t0;
			// 待机轨迹要按新日期重算（行星相位变了 ⇒ 探测器局部的轨道几乎不变，但预测线的相位要对）
			prepareIdle();
		},
		setBrakeMode: (on: boolean): void => {
			core.brakeMode = on;
			// 预测线要跟着重算（缓存键里带了 brakeMode，下一帧自然会重算）
		},
		brakeMode: (): boolean => core.brakeMode,
		// 包一层箭头函数：简写属性会触发 TS100016（见 Hud.ts 同名注释）
		update: (frameDt: number): void => update(frameDt),
	};
}
