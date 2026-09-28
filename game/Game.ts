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
import { Body, BrakeThrust, Outcome, P2, SimResult, bodyPositionAt, distance, simulate, sub } from 'game/Gravity';
import { GameScene, planeToWorld } from 'game/Scene';
import { CameraRig } from 'game/CameraRig';
import { GoalRing, TrajectoryView } from 'game/Trajectory';
import { CameraBasis, FLIP_Y, HANDEDNESS, prepareCamera, projectPrepared } from 'game/Projection';
import { GameSecondsPerRealSecond, GoalSpec, PlanetVisualDef, bodyVelocityAt, findGoalIndex, goalWaypoints, waypointProgress } from 'game/LevelData';
import { PlanView, PlanViewMode } from 'game/PlanView';
import {
	AimMinSpeed, BrakeShare, CameraFramingBudget, CameraTiltMax, CameraTiltMin, FlightPlayback, IntroCloseDist,
	IntroDurationSec, PhysicsStep, PredictSteps, SlowMoCloseDist, SlowMoFactor, SlowMoFloorDist,
	SlowMoRadiusFactor, TimeWarpStep,
	FinaleCamDist, FinaleCamTiltDeg, PlaneToWorldX, PlaneToWorldZ,
} from 'game/Config';

/**
 * 游戏阶段。
 *
 * `LevelSelect`（S2.3）：关卡选择界面。核心状态机在这个阶段**什么也不推进**
 * （不跑物理、不画预测线），驱动它的只有 init.ts 的 UI 回调。
 */
/**
 * 游戏阶段。
 *
 * `Armed`（S3.10）："已经瞄好、等玩家按发射"。用户定的交互是**松手不发射** ——
 * 松手进入 Armed，屏幕上出现「发射」按钮，点它才真的打出去。
 * 它是**真正的状态**而不是一个布尔：面板/按钮的显隐必须由状态驱动（AGENTS 硬约束 5）。
 */
export type GamePhase = 'Aiming' | 'Armed' | 'Flying' | 'Result' | 'Finale' | 'LevelSelect';

/** 结算三态（手册 §5.8）。 */
export type ResultKind = 'success' | 'missed' | 'crashed';

/**
 * 结算三态判定（手册 §5.8）。
 *
 * 优先级：到达目标 > 逃逸目标达成 > 撞毁 > 错过。
 * （到达目标优先于撞毁：轨迹在到达点截断，撞毁点根本不会发生。）
 *
 * ⚠️ **逃逸关 + 航线（chain）**：两个条件**都要**满足 —— 既走完航线，又真的越界（S3.11）。
 * L6「单程」用的就是这条：终章是"综合"，不能只朝任何方向猛推一下就赢。
 * 只走完航线没出去、或只出去没走航线，都是「错过」。
 *
 * 全部输入在**发射瞬间**即可确定 —— 结算与飞行一样是确定性的。
 */
export function resolveResult(outcome: Outcome, goalIndex: number, goal: GoalSpec): ResultKind {
	if (goal.kind === 'escape') {
		const wps = goalWaypoints(goal);
		if (outcome === 'escaped' && (wps.length === 0 || goalIndex >= 0)) return 'success';
	} else if (goalIndex >= 0) {
		return 'success';
	}
	if (outcome === 'crashed') return 'crashed';
	return 'missed';
}

/** 一关的物理定义（由 LevelData 转换而来）。 */
export interface GameLevel {
	bodies: Body[];
	probeStart: P2;
	/** 出发时已有的速度（S3.9.3）；S5 起六关都必填 = 该点的圆轨速度。 */
	probeVel0?: P2;
	goal: GoalSpec;
	escapeRadius: number;
	maxSteps: number;
	/**
	 * 预测线的推演步数（B1，来自 Tuning.predictSteps）；省略 = 全局 Config.PredictSteps（2400）。
	 * L1 现在是 8000（= maxSteps）：真实阿波罗剖面下这一发要飞 0.9 天，2400 步只画得到 1/3 路程。
	 */
	predictSteps?: number;
	/**
	 * **1 真实秒 = 多少游戏秒**（B3，来自 `LevelData.GameSecondsPerRealSecond`）。
	 * 档位速率的换算基准：速率 = 10^pow × 本值。省略 = 用 LevelData 的默认（测试/探针不必填）。
	 */
	speedUnit?: number;
	/** 进关默认档位（B3，来自 Tuning.speedDefaultPow）；省略 = 0（1× = 现实 1 秒）。 */
	speedDefaultPow?: number;
	/** 档位上限（B3）；省略 = 7（1000 万×）。 */
	speedMaxPow?: number;
	/** 发射瞬间自动提到的那一档（B3，来自 Tuning.flightSpeedPow）。 */
	flightSpeedPow?: number;
	/** 3D 取景口径（B2，'local' = 只装探测器 + 锚点天体）；见 Tuning.LevelRuntime.aimFraming。 */
	aimFraming?: 'local';
	/**
	 * 物理步长（S5，来自 Tuning.levelRuntime）。
	 * 省略 = 全局 Config.PhysicsStep。**必须按关卡给**：L1 的探测器日心速度 30、
	 * 绕地轨道半径 0.1 ⇒ 全局的 1/120 一步走 0.25，比整条轨道还大（实测把 0.1 算成 0.139~0.361）。
	 */
	physicsStep?: number;
	/** 飞行回放的默认倍速（S5，来自 Tuning）：L1 要 0.05×，L6 要 16×。省略 = Config.FlightPlayback。 */
	playback?: number;
	/**
	 * 瞄准期的世界时钟速率（S5，来自 Tuning）；省略 = 1（真实速度）。
	 * 真实尺度下 L1 的绕地周期只有 0.427 秒 —— 1× 时目标每秒转 2.3 圈，玩家来不及瞄。
	 */
	aimClockRate?: number;
	/** 慢动作阈值地板（S5，来自 Tuning）；省略 = Config.SlowMoFloorDist。 */
	slowMoFloor?: number;
	/**
	 * 瞄准力度**下限**（最小点火 Δv，S5，来自 Tuning.aimMin）。
	 * 省略 = Config.AimMinSpeed（5）。L1 必须给 0.02：它的 Δv 预算总共才 0.35，
	 * 用全局的 5 会让静止态读数显示 5.0、一出手就飞出地月系。
	 */
	aimMin?: number;
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
	/**
	 * 当前视图（S3.15）：`'2D'` = 规划（线稿示意图）/ `'3D'` = 观赏。
	 *
	 * **它是状态机的一部分，不是按钮的局部变量**（AGENTS 硬约束 5：显隐必须由状态驱动）：
	 * 发射瞬间由 `coreLaunch` 切 3D、`coreRetry` 切回 2D —— 于是"按下发射自动切 3D、
	 * 重试回 2D"是相态流转的副产品，而右下角那颗按钮只是 `coreToggleView` 的另一条入口。
	 * 手动切过之后，下一次相态流转会把视图拉回该相态该有的样子（发射一定进 3D）。
	 */
	viewMode: PlanViewMode;
	/**
	 * 飞行回放的**手动倍速档**（S3.17）：1 / 2 / 4，默认 `FlightPlayback`（2×）。
	 * 玩家用 HUD 的 1×/2×/4× 三颗状态型按钮覆盖它；掠过天体的自动慢动作**叠在**它上面
	 * （× SlowMoFactor = 1/4），不替换它。
	 */
	playback: number;
	/** 当前是否处于「掠过自动慢动作」（S3.17）。由 coreUpdate 按 level 判定，取景与日志读它。 */
	slowmo: boolean;
	/** 触发慢动作的天体索引（-1 = 没有）。取景时相机贴近这颗天体。 */
	slowmoBody: number;
	/** 是否在飞行中已触发逆喷制动（L4 伽利略号等轨道器关卡）。 */
	hasBraked: boolean;
	/** 逆喷制动生效时的采样点索引（-1 = 未制动）。 */
	brakePointIndex: number;
}

/** 飞行遥测数据（S7：用于任务结算与三枚火箭挑战判定）。 */
export interface FlightTelemetry {
	burnDv: number;
	flightTime: number;
	closestDist: number;
	maxSpeed: number;
	eccentricity?: number;
}

/** 中性瞄准（没拖过时的姿态）：朝目标、力度取这一关的下限。 */
/**
 * **档位 → 世界时钟速率**（游戏秒 / 真实秒，B3，2026-09-28）。
 *
 * 口径（用户 2026-09-28）：「1X 就是模拟的真实情况下的地月系的 1 秒」—— 也就是
 * `pow = 0` 时速率 = 1/SecPerGameSec（现实 1 秒走 1 秒；挂机一天，地球自转一圈）。
 * 加速 = pow + 1（**后面加个 0**），减速 = pow − 1（下限 0）。纯函数、可单测；物理层一行不动。
 */
export function speedRateOf(pow: number, gameSecPerRealSec: number): number {
	let rate = gameSecPerRealSec > 0 ? gameSecPerRealSec : 1;
	let n = Math.floor(pow);
	while (n > 0) {
		rate *= 10;
		n -= 1;
	}
	while (n < 0) {
		rate /= 10;
		n += 1;
	}
	return rate;
}

function neutralAim(minSpeed: number): AimResult {
	return { velocity: { x: 0, y: -minSpeed }, power: 0, unit: { x: 0, y: -1 } };
}

/** 这一关的瞄准力度下限（省略 = 全局 AimMinSpeed）。 */
function levelAimMin(aimMin: number | undefined): number {
	return aimMin !== undefined && aimMin >= 0 ? aimMin : AimMinSpeed;
}

export function createCore(dt?: number): GameCore {
	return {
		phase: 'Aiming',
		aim: neutralAim(AimMinSpeed),
		flight: undefined,
		dt: dt !== undefined && dt > 0 ? dt : PhysicsStep,
		brakeMode: false,
		t0: 0,
		flightTime: 0,
		goalIndex: -1,
		result: undefined,
		// 进关先给 2D：设计稿第 4 条"进关/瞄准在 2D"（发射那一刻才切 3D）
		viewMode: '2D',
		// S3.17：默认 2×（历史行为不变）；慢动作字段每帧由 coreUpdate 重算，这里给初值
		playback: FlightPlayback,
		slowmo: false,
		slowmoBody: -1,
		hasBraked: false,
		brakePointIndex: -1,
	};
}

/**
 * 手动切换 2D/3D（右下角那颗按钮的唯一入口，S3.15）。
 *
 * ⚠️ 按钮**不许自己翻转一个局部变量** —— 视图的唯一事实来源是 `GameCore.viewMode`，
 * 否则"按钮显示的"与"画出来的"迟早会分家（会话 38 那次"点了重试没反应"就是同一类根因）。
 *
 * @returns 切换后的新视图（调用方据此同步按钮文字）。
 */
export function coreToggleView(core: GameCore): PlanViewMode {
	core.viewMode = core.viewMode === '2D' ? '3D' : '2D';
	return core.viewMode;
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
	// 允许从 Aiming（老路径/回归脚本）或 Armed（松手后再按发射）出
	if (core.phase !== 'Aiming' && core.phase !== 'Armed') return;
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
	// 诊断（S5 L1 验收）：把"发射那一刻的真实起点与初速"打全精度。
	// 排查"Node 侧算得出解、引擎里却 missed"时必须看这几个数 —— 差一点就是几何完全不同。
	print('[escape-velocity][dbg] launch p0=(' + p0.x.toFixed(6) + ',' + p0.y.toFixed(6)
		+ ') v=(' + motion.init.x.toFixed(5) + ',' + motion.init.y.toFixed(5)
		+ ') t0=' + core.t0.toFixed(6) + ' dt=' + core.dt.toFixed(6)
		+ ' pts=' + flight.points.length.toFixed(0) + ' gi=' + core.goalIndex.toFixed(0)
		+ ' outcome=' + flight.outcome + ' result=' + core.result);
	core.flightTime = 0;
	// S3.17：慢动作状态由 coreUpdate 逐帧重算，这里给干净的初值（发射瞬间不可能在慢动作里）
	core.slowmo = false;
	core.slowmoBody = -1;
	core.hasBraked = false;
	core.brakePointIndex = -1;
	core.phase = 'Flying';
	// 设计稿第 4 条：**按下发射自动切 3D** —— 它是相态流转的一部分，不是 UI 的补丁
	core.viewMode = '3D';
}

/**
 * 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
 *
 * 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
 * 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
 */
export function coreArm(core: GameCore): boolean {
	if (core.phase !== 'Aiming') return false;
	core.phase = 'Armed';
	return true;
}

/** 取消瞄准（从 Armed 回到 Aiming）。 */
export function coreCancelArm(core: GameCore): boolean {
	if (core.phase !== 'Armed') return false;
	core.phase = 'Aiming';
	return true;
}

/**
 * 时间流（改发射日期）在当前相态下是否允许（S3.11）。
 *
 * 只在**发射前**允许（Aiming / Armed）：
 *  - 飞行用的是 `tWorld = t0 + flightTime`，飞行途中改 t0 等于把参考系整个挪走 ——
 *    行星会在飞行路径底下跳位（会话 39 亲眼见过同源现象：物理对、模型错）；
 *  - 结算之后改日期没有任何意义。
 *
 * 提成导出函数是为了**可单测**（`Test/GameTest.ts` 的 time-warp-* 三条），
 * HUD 里的按钮开关（`AimInput.setTimeEnabled`）读的是同一个判据。
 */
export function coreTimeWarpAllowed(core: GameCore): boolean {
	return core.phase === 'Aiming' || core.phase === 'Armed';
}

/**
 * 发射日期的**交棒**（S3.12 修 bug①，纯算术、可单测）。
 *
 * 事实来源只有一个：`tWorld = core.t0 + core.flightTime`。发射前玩家用「加速 / 回退」
 * 拨出来的是瞄准期的世界时钟 `clock`，而 `coreLaunch` 是纯函数、只认 `core.t0` ——
 * 两者之间过去**没有人接**，于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"。
 *
 * - `toT0 = true`（发射）：`clock → t0`；
 * - `toT0 = false`（重试）：`t0 → clock`（保留玩家挑好的日期，才能就着它继续调）。
 *
 * ⚠️ 两种方向的 `t0 + clock` **都守恒** —— 这正是"交棒时画面不跳"的数学表述
 * （`dateNow()` 与瞄准期的 `tNow` 都等于 `t0 + clock`）。
 */
export function coreHandoffDate(t0: number, clock: number, toT0: boolean): { t0: number; clock: number } {
	if (toT0) return { t0: clock, clock: 0 };
	return { t0: 0, clock: t0 };
}

/**
 * 取景锚点的索引（S3.12 的同款逻辑，提成纯函数）。
 *
 * L2~L6 是太阳（gm 72000、不绕别的天体转）；L1 场里也有太阳（物理统一），所以六关一致。
 * 返回 -1 = 场里没有「不绕别人转」的天体。
 *
 * S3.17 的慢动作触发也要用它：**锚点是舞台中心，不是被掠过的对象** ——
 * 太阳半径 28，任何 ≥3 的阈值系数都会让「整个太阳系」落在慢动作阈值里，机制直接失效。
 */
export function anchorBodyIndex(bodies: Body[]): number {
	// S5：先找"有别的天体绕着它转"的那个（L1 的地球 —— 月球 host = 地球）。
	// 它是这一关真正的世界中心：探测器围着它转、取景该以它为主。
	//
	// ⚠️ 判据**不能比对象身份**（bodies[j].host === b）：LevelData.scaledPlanets 会为每个天体
	//    各自拷贝一份宿主链（applyScalesLocal 递归复制 host），于是 moon.host 与 bodies[1]
	//    是两个不同对象，身份比较永远 false —— 宿主链"看起来断了"，锚点就被挑回太阳，
	//    取景包围盒被拉到 80 单位宽（实测 target 的 y 被拽到 40，3D 里只剩星空）。
	//    同一个坑在 PlanView.planFitRadius 踩过一次（2026-09-27）。
	// ⇒ 用**结构等价**：同 gm、同半径、同轨道半径就认为是同一颗天体。
	let host = -1;
	for (let i = 0; i < bodies.length; i++) {
		const b = bodies[i];
		let isHost = false;
		for (let j = 0; j < bodies.length; j++) {
			const h = bodies[j].host;
			if (h === undefined) continue;
			if (h.gm === b.gm && h.radius === b.radius && h.orbitRadius === b.orbitRadius) { isHost = true; break; }
		}
		if (!isHost) continue;
		if (host < 0 || b.gm > bodies[host].gm) host = i;
	}
	if (host >= 0) return host;
	// 没有宿主链（L2~L6）⇒ 退回原口径：不绕转且 gm 最大（太阳）
	let best = -1;
	for (let i = 0; i < bodies.length; i++) {
		const b = bodies[i];
		if (b.orbitRadius !== 0) continue;
		if (best < 0 || b.gm > bodies[best].gm) best = i;
	}
	return best;
}

/**
 * S3.17 慢动作触发判定（纯函数，可单测）：「**最近接近任何天体**」。
 *
 * 探测器与某个天体的距离进入阈值即算数 —— 抵达月球与掠过木星因此共用同一套手感。
 * 阈值 = `max(天体半径 × SlowMoRadiusFactor, SlowMoFloorDist)`（世界单位，理由见 Config）：
 *   - 半径 × 系数：木星 23.2 / 土星 21.5 / 月球 8（地板）；
 *   - **锚点天体（太阳）不参与**：它半径 28，乘出来比探测器出发距离（80）还大，
 *     不排除就是六关全程慢动作。掠过景由取景里的锚点预算负责，不由慢动作负责。
 *
 * @param anchor 锚点天体索引（-1 = 没有锚点）；传 anchorBodyIndex(bodies) 的结果。
 * @param floor 阈值的地板（世界单位）。**必须按关卡给**：L1 的世界只有 0.6 单位宽，
 *        用全局的 8 会让"整段飞行 100% 处于慢动作特写"（用户实测「发射后屏幕被探测器占满」）。
 *        省略 = Config.SlowMoFloorDist（L2–L6 的历史行为）。
 * @returns 触发的天体索引（**最近**的那个）；-1 = 不在任何天体的阈值内。
 */
export function slowMotionBody(bodies: Body[], probe: P2, t: number, anchor: number, floor?: number): number {
	const floorDist = floor !== undefined && floor > 0 ? floor : SlowMoFloorDist;
	let best = -1;
	let bestD = 1e9;
	for (let i = 0; i < bodies.length; i++) {
		if (i === anchor) continue;
		const b = bodies[i];
		const threshold = Math.max(b.radius * SlowMoRadiusFactor, floorDist);
		const d = distance(probe, bodyPositionAt(b, t));
		if (d < threshold && d < bestD) {
			bestD = d;
			best = i;
		}
	}
	return best;
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
 *
 * ===== S3.17 掠过自动慢动作：全项目**唯一**的播放速度入口 =====
 *
 * `level` 给了才判定（天体位置随时间动，需要 bodies + tWorld；测试与旧路径省略 = 不触发）。
 * 判定写在**推进之前**（用这一帧起始位置的探测器），结果落回 `core.slowmo` / `core.slowmoBody`
 * —— 相机取景与 HUD 读的就是这两个字段，全项目只有这一个地方写它们。
 * 有效倍速 = 手动档（1×/2×/4×）× (慢动作 ? SlowMoFactor : 1)，只改「每帧推进多少模拟时间」：
 * **不重算物理、不动确定性、不引入第二套时钟**（轨迹在发射那刻就已算完）。
 */
export function coreUpdate(core: GameCore, dt: number, level?: GameLevel): boolean {
	if (core.phase !== 'Flying' || core.flight === undefined) return false;
	// ⚠️ 不传 level = **不判定**（不清标志）：测试与回归脚本可以直接驱动 core.slowmo。
	//    真实游戏里 updateFlying 每帧都传 level ⇒ 标志每帧重算，不会留下陈旧值。
	if (level !== undefined) {
		const idx = coreProbeIndex(core);
		core.slowmoBody = slowMotionBody(level.bodies, core.flight.points[idx], core.t0 + core.flightTime, anchorBodyIndex(level.bodies), level.slowMoFloor);
		core.slowmo = core.slowmoBody >= 0;
	}
	// 基准（别算错）：默认手动档 2× ⇒ 慢动作期间 2 × 0.25 = 0.5× 实时
	const speed = core.playback * (core.slowmo ? SlowMoFactor : 1);
	core.flightTime += dt * speed;
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

/**
 * 从飞行回放结果中解算遥测数据（纯计算，可单测）。
 */
export function calcFlightTelemetry(
	core: GameCore,
	level: GameLevel,
): FlightTelemetry {
	const burnDv = Math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y);
	let maxSpeed = 0;
	let closestDist = 1e9;
	let eccentricity: number | undefined = undefined;

	if (core.flight !== undefined) {
		const pts = core.flight.points;
		const vels = core.flight.velocities;
		const end = coreProbeIndex(core);
		const targetIdx = level.goal.planetIndex;
		const targetBody = targetIdx >= 0 && targetIdx < level.bodies.length ? level.bodies[targetIdx] : undefined;

		for (let k = 0; k <= end && k < pts.length; k++) {
			const p = pts[k];
			if (vels !== undefined && k < vels.length) {
				const v = vels[k];
				const spd = Math.sqrt(v.x * v.x + v.y * v.y);
				if (spd > maxSpeed) maxSpeed = spd;
			}
			if (targetBody !== undefined) {
				const t = core.t0 + k * core.dt;
				const tp = bodyPositionAt(targetBody, t);
				const d = distance(p, tp);
				if (d < closestDist) closestDist = d;
			}
		}

		if (targetBody !== undefined && targetBody.gm > 0 && vels !== undefined && end < pts.length && end < vels.length) {
			const tEnd = core.t0 + end * core.dt;
			const tpEnd = bodyPositionAt(targetBody, tEnd);
			const tvEnd = bodyVelocityAt(targetBody, tEnd);
			const rx = pts[end].x - tpEnd.x;
			const ry = pts[end].y - tpEnd.y;
			const vx = vels[end].x - tvEnd.x;
			const vy = vels[end].y - tvEnd.y;
			const r = Math.sqrt(rx * rx + ry * ry);
			const v2 = vx * vx + vy * vy;
			const mu = targetBody.gm;
			if (r > 0 && mu > 0) {
				const energy = v2 / 2 - mu / r;
				const h = rx * vy - ry * vx;
				const term = 1 + (2 * energy * h * h) / (mu * mu);
				if (term >= 0) {
					eccentricity = Math.sqrt(term);
				}
			}
		}
	}

	return {
		burnDv,
		flightTime: core.flightTime,
		closestDist: closestDist < 1e8 ? closestDist : 0,
		maxSpeed,
		eccentricity,
	};
}

/** 重试本关：回到 Aiming，清空飞行与结算。 */
export function coreRetry(core: GameCore, aimMin?: number): void {
	core.phase = 'Aiming';
	// 重试 = 重新规划：回 2D（设计稿第 4 条）
	core.viewMode = '2D';
	core.flight = undefined;
	core.flightTime = 0;
	core.goalIndex = -1;
	core.result = undefined;
	core.slowmo = false;
	core.slowmoBody = -1;
	core.hasBraked = false;
	core.brakePointIndex = -1;
	core.aim = neutralAim(levelAimMin(aimMin));
}

/**
 * 判定当前飞行状态下是否处于可逆喷制动窗口。
 * 纯函数，可单测。
 */
export function isBrakeWindowActive(core: GameCore, level: GameLevel): boolean {
	if (core.phase !== 'Flying' || core.flight === undefined || core.hasBraked) return false;
	const curIdx = coreProbeIndex(core);
	const pts = core.flight.points;
	if (curIdx < 0 || curIdx >= pts.length) return false;

	const targetIdx = level.goal.planetIndex;
	if (targetIdx < 0 || targetIdx >= level.bodies.length) return false;
	const targetBody = level.bodies[targetIdx];
	const tNow = core.t0 + core.flightTime;
	const targetPos = bodyPositionAt(targetBody, tNow);
	const dist = distance(pts[curIdx], targetPos);

	// 制动窗口有效距离：靠近目标天体（进入慢动作影响区或容差的 1.5 倍）且未撞毁
	const floorD = level.slowMoFloor !== undefined && level.slowMoFloor > 0 ? level.slowMoFloor : SlowMoFloorDist;
	const brakeDistLimit = Math.max(level.goal.tolerance * 1.5, targetBody.radius * SlowMoRadiusFactor, floorD);
	return dist <= brakeDistLimit && dist > targetBody.radius;
}

/**
 * 飞行中逆喷制动（L4 伽利略号等轨道器核心玩法）。
 * 纯函数逻辑，更新 core.flight 及其后续轨迹，并重新判定目标与结果。
 * 返回 true 表示制动成功应用。
 */
export function applyInFlightBrake(core: GameCore, level: GameLevel): boolean {
	if (!isBrakeWindowActive(core, level)) return false;
	if (core.flight === undefined) return false;

	const curIdx = coreProbeIndex(core);
	const curPos = core.flight.points[curIdx];
	const curVel = core.flight.velocities !== undefined && curIdx < core.flight.velocities.length
		? core.flight.velocities[curIdx]
		: { x: 0, y: 0 };
	const tNow = core.t0 + core.flightTime;

	const targetIdx = level.goal.planetIndex;
	const targetBody = level.bodies[targetIdx];
	const targetPos = bodyPositionAt(targetBody, tNow);
	const targetVel = bodyVelocityAt(targetBody, tNow);

	// 探测器相对目标天体（木星）的速度
	const relVel = { x: curVel.x - targetVel.x, y: curVel.y - targetVel.y };
	const relSpeed = Math.sqrt(relVel.x * relVel.x + relVel.y * relVel.y);
	const dist = distance(curPos, targetPos);

	if (relSpeed <= 1e-6 || dist <= 1e-6) return false;

	// 木星局部圆轨道速度 v_circ = sqrt(mu / r)
	const vCirc = Math.sqrt(targetBody.gm / dist);

	// 将相对速度削减至捕获速度（闭合椭圆，0.98 * vCirc 保证机械能 < 0）
	const targetRelSpeed = vCirc * 0.98;
	const reductionFactor = targetRelSpeed / relSpeed;
	const clampedFactor = Math.min(0.95, reductionFactor);

	const newRelVel = {
		x: relVel.x * clampedFactor,
		y: relVel.y * clampedFactor,
	};
	const newVel: P2 = {
		x: targetVel.x + newRelVel.x,
		y: targetVel.y + newRelVel.y,
	};

	// 从当前点出发，推演后续的捕获闭合轨道
	const remainingSteps = Math.max(1000, level.maxSteps - curIdx);
	const postBrakeSim = simulate(
		{ pos: curPos, vel: newVel },
		level.bodies,
		{
			steps: remainingSteps,
			dt: core.dt,
			sampleEvery: 1,
			escapeRadius: level.escapeRadius,
			t0: tNow,
		}
	);

	// 拼接轨迹点与速度
	const mergedPoints: P2[] = core.flight.points.slice(0, curIdx);
	for (let i = 0; i < postBrakeSim.points.length; i++) {
		mergedPoints.push(postBrakeSim.points[i]);
	}
	const mergedVelocities: P2[] = (core.flight.velocities || []).slice(0, curIdx);
	if (postBrakeSim.velocities !== undefined) {
		for (let i = 0; i < postBrakeSim.velocities.length; i++) {
			mergedVelocities.push(postBrakeSim.velocities[i]);
		}
	}

	core.flight = {
		outcome: postBrakeSim.outcome,
		points: mergedPoints,
		velocities: mergedVelocities,
		state: postBrakeSim.state,
		hitIndex: postBrakeSim.hitIndex,
		stepsRun: curIdx + postBrakeSim.stepsRun,
	};

	core.hasBraked = true;
	core.brakePointIndex = curIdx;

	// 重新判定目标和结算
	core.goalIndex = findGoalIndex(mergedPoints, level.bodies, level.goal, core.dt, core.t0, mergedVelocities);
	core.result = resolveResult(postBrakeSim.outcome, core.goalIndex, level.goal);

	print('[escape-velocity] in-flight brake applied at t=' + tNow.toFixed(2)
		+ ' curIdx=' + curIdx.toFixed(0)
		+ ' relSpeed=' + relSpeed.toFixed(3) + ' -> ' + Math.sqrt(newRelVel.x * newRelVel.x + newRelVel.y * newRelVel.y).toFixed(3)
		+ ' vCirc=' + vCirc.toFixed(3)
		+ ' result=' + core.result);

	return true;
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
	// 终章（S3.18）也允许：它就是结算之后的最后一屏，按钮只有一颗「返回关卡选择」
	if (core.phase !== 'Result' && core.phase !== 'Finale') return false;
	core.phase = 'LevelSelect';
	// 离开关卡也回 2D：下一关是从"进关/瞄准在 2D"开始的
	core.viewMode = '2D';
	core.flight = undefined;
	core.flightTime = 0;
	core.goalIndex = -1;
	core.result = undefined;
	core.slowmo = false;
	core.slowmoBody = -1;
	return true;
}

/**
 * 终章「暗淡蓝点」的数据（S3.18）。
 *
 * 一行小字（飞行距离 / 用时）要用的两个数。距离 = 出发点 → 终点的**直线距离**
 * （平面单位）；用时 = 这一段飞了多久（模拟秒）。都从发射那一刻就定死的轨迹上读，
 * 不重新积分 —— 与「预测线看见的就是飞出来的」是同一条确定性链路。
 */
export interface FinaleInfo {
	/** 飞行距离（平面单位，出发点 → 终点）。 */
	distance: number;
	/** 飞行用时（模拟秒）。 */
	time: number;
	/** 终点时刻的世界时刻（= core.t0 + core.flightTime；取地球位置必须用它）。 */
	tWorld: number;
}

/**
 * 进入终章（S3.18）。只在 **Result** 态有效。
 *
 * 为什么是 Result 的延续而不是另一套结算：L6 成功后玩家已经看过一次「借力成功」了，
 * 终章是**同一局的收尾一屏**（回望地球缩成一点）。所以它保留结算数据
 * （core.result / core.flight），只把相态往前推一格 —— 「返回关卡选择」因此可以复用
 * coreBackToSelect（它现在也认 Finale）。
 *
 * @returns 是否真的切过去了（非 Result 态返回 false，什么都不做）。
 */
export function coreEnterFinale(core: GameCore): boolean {
	if (core.phase !== 'Result') return false;
	core.phase = 'Finale';
	return true;
}

/**
 * 终章的相机机位（纯函数，可单测）。
 *
 * 「相机拉到尽可能远，回望整条太阳系」：机位在**探测器逃逸方向**上、距太阳
 * `distance` 处抬起 `tiltDeg`，注视太阳（世界原点）。于是
 *   - 太阳缩成一个亮点（半径 28 @ 1000 ≈ 1.6°）；
 *   - 地球按真实比例缩成一个点（半径 1.76 @ ~1000 ≈ 0.10°，直径约 5 px）——
 *     **不放大**（用户否掉过「为画面放大行星」，docs/关卡舞台表.md 第二节第 9 条）。
 *
 * ⚠️ 这是唯一一处**绕开 CameraRig** 的取景：机架的距离夹在 [CameraMinDistance, CameraMaxDistance]
 * （60–300）里，装不下「尽可能远」。绕开的代价是机架内部的平滑状态会停在 1000 上，
 * 所以进关时（Game.startLevel）必须 `deps.rig.reset()`，否则下一关的相机会从 1000 一路 lerp 回去。
 *
 * @param probe 探测器**当前**位置（平面坐标）；只在逃逸方向上有意义，零向量时退回 +Y。
 */
export function finaleCamera(probe: P2, distance: number, tiltDeg: number): { eye: Vec3.Type; target: Vec3.Type } {
	const dist = distance > 1 ? distance : 1;
	// 逃逸方向（平面 → 世界：u→X、v→Z，见 Config 的映射表）
	let ux = probe.x;
	let uy = probe.y;
	const len = Math.sqrt(ux * ux + uy * uy);
	if (len < 1e-6) { ux = 0; uy = 1; } else { ux /= len; uy /= len; }
	const tilt = (tiltDeg * Math.PI) / 180;
	const flat = Math.cos(tilt) * dist;
	return {
		// 注视太阳：平面原点即世界原点（planeToWorld({0,0},0) === (0,0,0)）
		target: Vec3(0, 0, 0),
		eye: Vec3(ux * flat * PlaneToWorldX, Math.sin(tilt) * dist, uy * flat * PlaneToWorldZ),
	};
}
/** 引擎侧依赖（由 init.ts 组装）。 */
export interface GameDeps {
	scene: GameScene;
	camera: Camera3D.Type;
	rig: CameraRig;
	trajectory: TrajectoryView;
	/** 2D 规划视图（S3.15）：轨道圈 / 图钉 / 到达圈 / 预测线。 */
	plan: PlanView;
	/** 每关的视觉描述（2D 图钉的颜色取自它：同一颗行星在两个视图里同色）。 */
	visuals: PlanetVisualDef[];
	/** 3D 世界根节点的显隐（2D 模式要把它整个收掉，否则两套画面会叠在一起）。 */
	setWorldVisible: (on: boolean) => void;
	aim: AimInput;
	viewW: number;
	viewH: number;
	fovYDeg: number;
	aspect: number;
	/** 阶段变化回调（驱动 UI 显隐）。 */
	onPhase: (p: GamePhase) => void;
	/** 结算回调（驱动结果面板，携带遥测数据）。 */
	onResult: (r: ResultKind, telemetry?: FlightTelemetry) => void;
	/**
	 * 这一关成功之后是否进**终章「暗淡蓝点」**（S3.18）。
	 *
	 * 由 init.ts 给（只有最后一关 = L6 海王星为 true）。不读 goal.kind 是不是 escape：
	 * S3.13 起 L6 就是普通的目的地任务（逃逸归终章），所以判据只能是「这是最后一关」。
	 *
	 * 为什么是**可选字段**而不是必填：Test/ 下的一批探针（GameProbe / UiProbe /
	 * LineDirProbe / LineAlignProbe）自己拼 GameDeps，加必填字段会让它们整批编译失败
	 * （构建直接掉到 41/45）。省略 = 不进终章（旧行为：直接弹普通结算面板）。
	 */
	finale?: boolean;
	/**
	 * 终章数据回调：进终章那一刻调一次（之后画面冻结，不再变）。
	 * 文案小字（飞行距离 / 用时）的两个数从这里来 —— 面板只负责显示，不算账。
	 * 同样可选：探针不传就只是不打那行日志。
	 */
	onFinale?: (info: FinaleInfo) => void;

}
export interface Game {
	phase: () => GamePhase;
	result: () => ResultKind | undefined;
	/** 拖动回调（接到 aim.onDrag）。 */
	onAimDrag: (a: AimResult) => void;
	/** 发射（接到 aim.onRelease）。 */
	launch: (v: P2) => void;
	/**
	 * 瞄准完成（松手）→ 进入 Armed（S3.10：松手不发射，出「发射」按钮）。
	 */
	aimReady: () => void;
	/** 「发射」按钮：从 Armed 真的打出去（带状态守卫 + Ui 的防抖）。 */
	launchArmed: () => void;
	/** 当前是否 Armed（HUD 按钮显隐同步用）。 */
	armed: () => boolean;
	/** 当前视图（HUD 的 2D/3D 按钮文字同步用；状态是唯一事实来源）。 */
	viewMode: () => PlanViewMode;
	/** 手动切换 2D/3D（右下角那颗按钮）。 */
	toggleViewMode: () => void;
	/** 观察拖动（像素增量）→ 绕目标转。 */
	observeDrag: (dx: number, dy: number) => void;
	/** 捏合缩放（deltaDist；>0 放大/拉远，见 applyObserve）。 */
	observeZoom: (deltaDist: number) => void;
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
	 * 时间流（S3.9.4，用户提议替换日期滑杆）：按一次走一步，dir = -1 回退 / +1 加速。
	 * **世界时钟**走（行星绕太阳转，等发射窗口），而**探测器自己的轨道相位不动** ——
	 * 这正是用户指出的冲突：滑杆是"瞬间跳"，而待机是"时间在流"，两者必须分开。
	 */
	stepTime: (dir: number, span: number) => void;
	/** 当前发射日期（秒）= 基准日期 + 世界时钟；HUD 读数用。 */
	dateNow: () => number;
	/** 刹车模式（S3.9.2）：开 = 一半点火、一半留给后半程反推。默认关。 */
	setBrakeMode: (on: boolean) => void;
	/** 读当前刹车模式（HUD 按钮同步用）。 */
	brakeMode: () => boolean;
	/**
	 * 播放倍速（S3.17）：玩家手动兜底档 1 / 2 / 4。掠过天体的自动慢动作**叠在**它上面
	 * （× 1/4），不替换它 —— 所以 HUD 上高亮的一直是玩家选的那个档。
	 */
	setPlaybackSpeed: (speed: number) => void;
	/** 当前手动倍速档（HUD 三颗按钮的高亮同步用；状态是唯一事实来源）。 */
	playbackSpeed: () => number;
	/**
	 * 当前瞄准的 Δv 大小（点火向量的模；静止态 = 力度下限）。
	 *
	 * 存在的理由：HUD 的 Δv 读数要**每帧**刷新（用户实测「2D 状态下德塔 V 怎么给的是 0」——
	 * 旧实现只在拖动回调里更新，静止态永远停在初始值 0）。
	 */
	burnNow: () => number;
	/** 飞行中实时制动窗口是否开启（L4 伽利略号等轨道器关卡）。 */
	isBrakeWindowActive: () => boolean;
	/** 触发飞行中实时逆喷制动。 */
	applyInFlightBrake: () => boolean;
	/** 是否已经执行过实时制动。 */
	hasBraked: () => boolean;
	/** 跳过 3D 入场倒叙运镜。 */
	skipIntroTour: () => void;
	/** 当前是否正在进行 3D 入场倒叙运镜。 */
	isIntroTourActive: () => boolean;
	/** 当前档位指数（B3）：速率 = 10^pow ÷ SecPerGameSec 游戏秒/真实秒。 */
	speedPow: () => number;
	/** 档位上限（HUD 用它决定"加速"是否还点得动）。 */
	speedMaxPow: () => number;
	/** 当前是否暂停（暂停 = 速率 0）。 */
	isPaused: () => boolean;
	/** 当前速率（游戏秒 / 真实秒）；暂停时是 0。 */
	speedRate: () => number;
	/** 任务时钟（**真实秒**）：从进关起世界流逝了多少现实时间 —— 1× 下它就等于挂钟。 */
	missionSeconds: () => number;
	/** 加速一档（×10）。 */
	speedUp: () => void;
	/** 减速一档（÷10，下限 0 = 1×）。 */
	speedDown: () => void;
	/** 暂停 / 继续（状态型，任何相态都有效）。 */
	togglePause: () => void;
	/** 每帧调用一次。 */
	update: (dt: number) => void;
}

/** 组装游戏（状态机 + 引擎驱动）。 */
export function createGame(level: GameLevel, deps: GameDeps): Game {
	const core = createCore(level.physicsStep);

	// ---- 时间档位（B3，2026-09-28）----
	// `core.playback` 从此就是"**当前速率**"（游戏秒/真实秒），瞄准期与飞行期共用它 ——
	// 全项目仍然只有一个时钟（硬约束 10：tWorld = t0 + flightTime / t0 + clock）。
	// 暂停 = 速率 0（飞行段也因此免费获得暂停：coreUpdate 里 speed = playback × slowmo）。
	let speedPow = level.speedDefaultPow !== undefined ? level.speedDefaultPow : 0;
	let paused = false;
	const speedMaxPow = level.speedMaxPow !== undefined ? level.speedMaxPow : 7;
	/** 换算基准（1 真实秒 = 多少游戏秒）：关卡没给就用 LevelData 的默认值。 */
	const speedUnit = level.speedUnit !== undefined && level.speedUnit > 0 ? level.speedUnit : GameSecondsPerRealSecond;
	const applySpeedRate = (): void => {
		core.playback = paused ? 0 : speedRateOf(speedPow, speedUnit);
	};
	// S5：飞行回放的默认倍速**按关卡**给。L1 的转移飞行只有 0.40 游戏秒，
	// 2× 播放下是 0.2 真实秒 —— 玩家什么都看不见（这正是"每关一个播放速度"的理由）。
	// B3：速率不再来自 level.playback，而是**档位**（pow 0 = 1× = 现实 1 秒）。
	// level.playback / level.aimClockRate / Tuning.playbackSpeeds 三个字段就此退役。
	applySpeedRate();

	/** 已经应用到节点上的视图（"" = 还没应用过）。每帧 applyView 都拿它对账。 */
	let appliedMode: PlanViewMode | '' = '';
	/**
	 * **视图切换的唯一落点**（S3.15）。
	 *
	 * 设计稿第 4 条："进关/瞄准在 2D → 按下发射自动切 3D → 飞行与结算留 3D → 重试回 2D"，
	 * 右下角再给一颗手动按钮兜底。这里读的是 `core.viewMode`（状态），**不读按钮**：
	 * 于是自动切换与手动切换走的是同一条路，也不会有"按钮显示的与画出来的分家"。
	 *
	 * - 2D：收起 3D 世界 + 收起 3D 轨迹层（`trajectory.root`，它就是投影出来的预测线/尾迹/到达环），
	 *   打开 2D 规划层，并让瞄准层**整屏**都能瞄（2D 里没有"自由观察"可做，"探测器附近"那条分区
	 *   规则会把大半屏变成死区）；
	 * - 3D：反过来。两边的 DrawNode 都挂在关卡 2D 层上，**隐藏时必须清空**（硬约束 8）。
	 *
	 * 每帧调用一次是**幂等**的：`mode === appliedMode` 直接早退（不动节点、不刷日志）。
	 */
	const applyView = (): void => {
		const mode = core.viewMode;
		if (mode === appliedMode) return;
		appliedMode = mode;
		const is2D = mode === '2D';
		deps.plan.setVisible(is2D);
		deps.trajectory.root.visible = !is2D;
		deps.setWorldVisible(!is2D);
		deps.aim.setFullScreenAim(is2D);
		print('[escape-velocity] view -> ' + mode + ' (phase=' + core.phase + ')');
	};

	const finishIntroTour = (): void => {
		if (!introTourActive) return;
		introTourActive = false;
		introTourT = IntroTourDuration;
		core.viewMode = '2D';
		applyView();
		print('[escape-velocity] intro tour completed -> enter 2D');
	};

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
	// 预测线重算的节流（B1，2026-09-28）：L1 的预测是 8000 步 ≈ 20–40 ms（Lua），
	// 每帧重算会把拖动掉到 25 fps。口径：**瞄准/位置任一变化**才重算，且两次之间至少隔
	// PredMinIntervalSec；松手（Armed）时 predForce 强制算一次 —— 保证"最后那一下"精确。
	const PredMinIntervalSec = 0.08;
	let predAimKey = '';
	let predPosKey = '';
	let predAccum = 1;
	let predForce = true;
	let predPoints: P2[] = [];
	// 进关影视化倒叙/溯源运镜（S8.1）：先在 3D 下目标特写 ➔ 飞掠 ➔ 地球探测器 ➔ 切入 2D
	const IntroTourDuration = 3.2;
	let introTourActive = false;
	let introTourT = IntroTourDuration;
	let introLogged = false;
	/** 相机诊断行的打印计数（只打前几帧，别刷屏）。 */
	let frameLogged = 0;

	// ---- 待机时钟（S3.9.4）----
	// 用户："飞行器不进行操控的时候会按照时间尺度绕地球转，在操控的时候时间变成超级慢或者干脆暂停。"
	// 实现：`clock` 只在**没在拖**的时候走；`idlePath` 是"不点火时探测器自己会飞成什么样"（进关时算一次），
	// 于是待机时探测器沿着它走、预测线就是它的后半段 —— 不用每帧重算，也不会和真实飞行分家。
	let clock = 0;
	/** 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。 */
	let orbitClock = 0;
	/** 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。 */
	let warpDir = 0;
	// ---- 自由观察（S3.10）----
	// 不做"另起一套相机"，而是**在自动取景的基础上叠加**：绕目标转（yaw/pitch）+ 缩放。
	// 好处：转完之后相机仍然跟着探测器走（自动取景每帧重算 ✓），玩家不会"看着看着丢了自己的船"。
	let obsYawDeg = 0;
	let obsPitchDeg = 0;
	let obsZoom = 1;
	/** 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。 */
	let warpSpan = 0;
	// 待机轨道的解析模型（B1，见 prepareIdle）：宿主索引 + 相对圆轨的半径/初相/角速度。
	let idleOrbit: { hostIndex: number; r: number; phase0: number; omega: number } | undefined = undefined;
	/**
	 * 玩家**是否已经瞄过**（S3.12）。
	 *
	 * 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	 * 调整过了再显示」。所以规则是：
	 *   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	 *   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	 *     直到发射 / 重试 / 退出关卡才清掉。
	 * 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	 */
	let aimed = false;
	/** S3.17：慢动作的上一帧状态（打迁移日志用）与飞行日志累加器（每 0.5 真实秒一行）。 */
	let lastSlowmo = false;
	let lastSlowmoBody = -1;
	let flightLogT = 0;
	/** 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。 */
	let probePos: P2 = { x: level.probeStart.x, y: level.probeStart.y };
	let probeVel: P2 = level.probeVel0 !== undefined ? level.probeVel0 : { x: 0, y: 0 };
	/**
	 * 进关 / 重新进关：把待机轨道的**解析模型**算出来。
	 *
	 * 为什么必须是解析的（B1，2026-09-28）：待机轨是相对**宿主天体**（L1 = 地球）的圆轨，
	 * 而宿主自己在动 —— 地球在一个停泊周期（88.4 分钟）里沿日心轨道走
	 * `30 × 2.8145e-3 = 0.0844` 单位，是停泊轨半径（3.514e-3）的 **24 倍**。
	 * 旧实现把"惯性系里的一段轨迹"按点数取模循环播放，于是每绕一圈探测器就相对地球跳一次；
	 * 冻结时钟的时代（aimClockRate = 0）看不出来，时间一流动就现形。
	 * 现在写成「宿主位置 + 相对圆轨」：接缝天然连续，且就是真实二体圆轨
	 * （太阳潮汐在 L1 只是地球引力的 0.004%，忽略 —— 正是用户说的「能感受到就行」）。
	 *
	 * ⚠️ 圆轨速度取的是**相对宿主**的速度，不是含地球公转的总速度（旧代码拿错了总速度，
	 *    推出来的周期是错的）。
	 */
	const prepareIdle = (): void => {
		// 进关 / 重新进关 = 全新的一天（日期、待机时钟都归零）
		clock = 0;
		core.t0 = 0;
		idleOrbit = undefined;
		if (level.probeVel0 === undefined) return;
		// ① 宿主 = 离出发点最近的、有引力的天体（L1 = 地球）
		let hostIndex = -1;
		let bestD = 1e9;
		for (let i = 0; i < level.bodies.length; i++) {
			const b = level.bodies[i];
			if (b.gm <= 0) continue;
			const d = distance(bodyPositionAt(b, 0), level.probeStart);
			if (d < bestD) {
				bestD = d;
				hostIndex = i;
			}
		}
		if (hostIndex < 0 || bestD < 1e-9) return;
		const host = level.bodies[hostIndex];
		const hp = bodyPositionAt(host, 0);
		const hv = bodyVelocityAt(host, 0);
		// ② 相对位置 / 相对速度
		const rx = level.probeStart.x - hp.x;
		const ry = level.probeStart.y - hp.y;
		const vx = level.probeVel0.x - hv.x;
		const vy = level.probeVel0.y - hv.y;
		const r = Math.sqrt(rx * rx + ry * ry);
		if (r < 1e-12) return;
		// ③ 圆轨角速度 ω = √(gm/r³)；方向 = r × v 的符号（顺行/逆行都支持，不写死）
		const omega = Math.sqrt(host.gm / (r * r * r));
		const dir = rx * vy - ry * vx >= 0 ? 1 : -1;
		idleOrbit = { hostIndex, r, phase0: Math.atan2(ry, rx), omega: dir * omega };
	};

	/** 待机时探测器在 `tWorld` 时刻的状态（解析：宿主位置 + 相对圆轨）。 */
	const idleProbeAt = (tWorld: number): { pos: P2; vel: P2 } => {
		if (idleOrbit === undefined) {
			return {
				pos: { x: level.probeStart.x, y: level.probeStart.y },
				vel: level.probeVel0 !== undefined ? level.probeVel0 : { x: 0, y: 0 },
			};
		}
		const host = level.bodies[idleOrbit.hostIndex];
		const hp = bodyPositionAt(host, tWorld);
		const hv = bodyVelocityAt(host, tWorld);
		const a = idleOrbit.phase0 + idleOrbit.omega * tWorld;
		const ca = Math.cos(a);
		const sa = Math.sin(a);
		return {
			pos: { x: hp.x + idleOrbit.r * ca, y: hp.y + idleOrbit.r * sa },
			// 相对速度 = ω·r·(−sin a, cos a)（切向）；总速度 = 宿主速度 + 相对速度
			vel: { x: hv.x - idleOrbit.omega * idleOrbit.r * sa, y: hv.y + idleOrbit.omega * idleOrbit.r * ca },
		};
	};

	/**
	 * **锚点天体**：这一关的"世界中心"（S3.12；**S5 修订口径**）。
	 *
	 * L2~L6 是太阳（玩家绕的就是它）；L1 是**地球** —— 地月系里玩家绕的是地球。
	 *
	 * ⚠️ S5 之前的口径是「不绕转（orbitRadius = 0）且 gm 最大」，归正后它**挑错了**：
	 *    L1 的太阳 orbitRadius = 0、gm 72000，地球 orbitRadius = 80 ⇒ 锚点变成太阳，
	 *    取景包围盒被拉到 80 单位宽，地球被压成远处一个点（用户实测「3D 完全看不到地球」）。
	 *    新口径（见 anchorBodyIndex 的文档）：**有别的天体绕着它转的优先**，其次才是不绕转且 gm 最大。
	 */
	const anchorIdx = anchorBodyIndex(level.bodies);
	const anchorDef: Body | undefined = anchorIdx >= 0 ? level.bodies[anchorIdx] : undefined;

	/** 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。 */
	const nextStationBody = (): Body | undefined => {
		const wps = goalWaypoints(level.goal);
		if (wps.length === 0) return undefined;
		let passed = 0;
		if (core.flight !== undefined) {
			const upto = Math.floor(core.flightTime / core.dt);
			passed = waypointProgress(core.flight.points, level.bodies, level.goal, core.dt, core.t0, upto, core.flight.velocities).passed;
		}
		if (passed >= wps.length) return undefined;
		return level.bodies[wps[passed].planetIndex];
	};

	/**
	 * 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	 *
	 * 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	 * 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	 * 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	 * 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	 */
	const framingPoints = (probe: P2, t: number): { pts: P2[]; radii: number[] } => {
		// ⓪ **贴局部天体**（B2，L1 专用）：只装「探测器 + 锚点天体」，月球允许出画。
		//    L1 的停泊轨 3.514e-3，而月球轨 0.2056 = 59 倍 ⇒ 装进月球就看不见停泊轨了。
		if (level.aimFraming === 'local' && anchorDef !== undefined) {
			let hr = anchorDef.radius;
			for (let i = 0; i < level.bodies.length; i++) {
				const b = level.bodies[i];
				if (b.gm === anchorDef.gm && b.radius === anchorDef.radius && b.orbitRadius === anchorDef.orbitRadius) {
					if (i < deps.visuals.length && deps.visuals[i].displayRadius > hr) hr = deps.visuals[i].displayRadius;
					break;
				}
			}
			return { pts: [probe, bodyPositionAt(anchorDef, t)], radii: [deps.scene.probeRadius, hr] };
		}
		// ① 核心：探测器 + 下一站。下一站的半径取 **max(本体半径, 到达容差)** ——
		//    玩家真正要够的是那个"圈"，圈被画面切掉就没法瞄了。
		const corePts: P2[] = [probe];
		const coreRadii: number[] = [deps.scene.probeRadius];
		const next = nextStationBody();
		let nextTol = 0;
		if (next !== undefined) {
			corePts.push(bodyPositionAt(next, t));
			const wps = goalWaypoints(level.goal);
			let passed = 0;
			if (core.flight !== undefined) {
				passed = waypointProgress(core.flight.points, level.bodies, level.goal, core.dt, core.t0, Math.floor(core.flightTime / core.dt), core.flight.velocities).passed;
			}
			if (passed < wps.length) nextTol = wps[passed].tolerance;
			const r = nextTol > next.radius ? nextTol : next.radius;
			coreRadii.push(r);
		}
		// ② 锚点天体（太阳/地球）：**装得下才装**（见 Config.CameraFramingBudget 的取舍说明）
		if (anchorDef === undefined) return { pts: corePts, radii: coreRadii };
		// ⚠️ S5.1：锚点的半径要用**视觉半径**（visuals 里的 displayRadius），不能用物理半径。
		//    真实尺度下地球物理半径 0.0034、视觉 0.06 —— 差 17 倍。相机只保证"中心点入画"的话，
		//    地球会被切掉一大块（用户实测 3D 里地球占满屏幕、月球被挤出画面）。
		//    取景的职责就是"看得见"，所以它必须知道模型实际有多大。
		let anchorR = anchorDef.radius;
		for (let i = 0; i < level.bodies.length; i++) {
			const b = level.bodies[i];
			if (b.gm === anchorDef.gm && b.radius === anchorDef.radius && b.orbitRadius === anchorDef.orbitRadius) {
				if (i < deps.visuals.length && deps.visuals[i].displayRadius > anchorR) anchorR = deps.visuals[i].displayRadius;
				break;
			}
		}
		const withAnchorPts: P2[] = [probe, bodyPositionAt(anchorDef, t)];
		const withAnchorRadii: number[] = [deps.scene.probeRadius, anchorR];
		for (let i = 1; i < corePts.length; i++) {
			withAnchorPts.push(corePts[i]);
			withAnchorRadii.push(coreRadii[i]);
		}
		const want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii);
		if (want <= CameraFramingBudget) return { pts: withAnchorPts, radii: withAnchorRadii };
		return { pts: corePts, radii: coreRadii };
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

	/** 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。 */
	const applyObserve = (f: { eye: Vec3.Type; target: Vec3.Type }): { eye: Vec3.Type; target: Vec3.Type } => {
		if (obsYawDeg === 0 && obsPitchDeg === 0 && obsZoom === 1) return f;
		const dx = f.eye.x - f.target.x;
		const dy = f.eye.y - f.target.y;
		const dz = f.eye.z - f.target.z;
		const r = Math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom;
		const yaw = Math.atan2(dx, dz) + (obsYawDeg * Math.PI) / 180;
		let pitch = Math.asin(dy / (r > 1e-6 ? r / obsZoom : 1)) + (obsPitchDeg * Math.PI) / 180;
		const lo = (CameraTiltMin * Math.PI) / 180;
		const hi = (CameraTiltMax * Math.PI) / 180;
		if (pitch < lo) pitch = lo;
		if (pitch > hi) pitch = hi;
		const cp = Math.cos(pitch);
		return {
			target: f.target,
			eye: Vec3(
				f.target.x + r * cp * Math.sin(yaw),
				f.target.y + r * Math.sin(pitch),
				f.target.z + r * cp * Math.cos(yaw),
			),
		};
	};

	const updateAiming = (dt: number): void => {
		deps.aim.setEnabled(true);
		// S3.9.4 待机时钟：**没在操控**时世界照常走（探测器沿自己的轨道绕地球转），一按下就冻结。
		const dragging = deps.aim.isDragging();
		// 只在**纯瞄准态**流时间：Armed（已瞄好等发射）时冻结 —— 否则目标会从瞄准线下面跑掉。
		// B3：`Aiming`（没在拖）与 `Armed` 都按档位流；**瞄准中（按住探测器附近拖动）自动暂停**
		// —— 用户口径：「只有对探测器进行瞄准的时候，时间暂停」。
		if ((core.phase === 'Aiming' || core.phase === 'Armed') && !dragging && idleOrbit !== undefined) {
			// ⚠️ 0 = **冻结**（不是"回退成 1"）：L1 是教学关，开局状态必须完全确定，
			//    否则"进关那几十帧"就足以让探测器自己转掉十几度（实测 0.017 秒 = 14°），
			//    而且玩家没有任何读数可以据此瞄准。
			// ⚠️ **两个时钟必须用同一个速率**（S5 踩过）：`clock` 管日期与行星，
			//    `orbitClock` 管**待机动画**（探测器沿自己的轨道飞）。只冻住前者的话，
			//    探测器会在你瞄准的这几帧里照样飞走 —— 实测冻结后发射点仍是 (−18.93, 77.63)
			//    （= 探测器日心轨道上 0.64 秒后的位置），而 probeStart 是 (0, 80.10)，
			//    于是"Node 侧算得出解、引擎里却 missed"。
			// 速率 = core.playback（档位 × 10^pow ÷ SecPerGameSec；暂停时是 0）
			clock += dt * core.playback;
			orbitClock += dt * core.playback;
		}
		const tNow = core.t0 + clock;
		// 待机位置/速度：**解析求**（宿主位置 + 相对圆轨），不再查惯性轨迹表（B1）
		const idleState = idleProbeAt(tNow);
		probePos = idleState.pos;
		probeVel = idleState.vel;

		deps.scene.syncBodies(tNow);
		deps.scene.syncProbe(probePos);
		if (idleOrbit !== undefined) deps.scene.faceVelocity(probeVel);
		// 2D 规划视图：轨道圈与图钉按**同一个 tWorld**（硬约束 7：待机会绕地球走，日期也会动）
		deps.plan.syncBodies(level.bodies, deps.visuals, tNow);
		deps.plan.syncProbe(probePos, probeVel);

		// 取景（S3.12）：探测器 + 锚点天体（太阳/地球）+ 下一站 —— 远处的行星允许出画
		const fr = framingPoints(probePos, tNow);
		let frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii);
		// 诊断（S5.1 L1 呈现层验收）：把取景点与相机参数打出来。
		// 「3D 看不到地球」这类问题，看这几个数就能定位是 target 被拽走还是距离被解太大。
		if (frameLogged < 6) {
			frameLogged += 1;
			const d = Math.sqrt(
				(frame.eye.x - frame.target.x) * (frame.eye.x - frame.target.x)
				+ (frame.eye.y - frame.target.y) * (frame.eye.y - frame.target.y)
				+ (frame.eye.z - frame.target.z) * (frame.eye.z - frame.target.z));
			const sunD = Math.sqrt(frame.eye.x * frame.eye.x + frame.eye.z * frame.eye.z);
			print('[escape-velocity][cam] aim pts=' + fr.pts.length
				+ ' target=(' + frame.target.x.toFixed(3) + ',' + frame.target.y.toFixed(3) + ',' + frame.target.z.toFixed(3) + ')'
				+ ' eye=(' + frame.eye.x.toFixed(3) + ',' + frame.eye.y.toFixed(3) + ',' + frame.eye.z.toFixed(3) + ')'
				+ ' dist=' + d.toFixed(4) + ' sunDist=' + sunD.toFixed(3)
				+ ' probeR=' + deps.scene.probeRadius.toFixed(7)
				+ ' slowmo=' + (core.slowmo ? 1 : 0)
				+ ' pts=[' + fr.pts.map((p) => '(' + p.x.toFixed(3) + ',' + p.y.toFixed(3) + ')').join(' ') + ']');
		}
		// 进关影视化倒叙/溯源运镜（S8.1）：① 目标天体特写 ➔ ② 逆序飞掠路线 ➔ ③ 探测器特写 ➔ ④ 切入 2D
		if (introTourActive && introTourT < IntroTourDuration) {
			introTourT += dt;
			let k = introTourT / IntroTourDuration;
			if (k >= 1) {
				finishIntroTour();
			} else {
				if (k >= 0.95 && !introLogged) {
					introLogged = true;
					print('[escape-velocity] intro camera finishing');
				}
				let targetBody: Body | undefined = undefined;
				const wps = goalWaypoints(level.goal);
				if (wps.length > 0) {
					targetBody = level.bodies[wps[wps.length - 1].planetIndex];
				} else if (level.goal.planetIndex >= 0 && level.goal.planetIndex < level.bodies.length) {
					targetBody = level.bodies[level.goal.planetIndex];
				}
				if (targetBody === undefined && level.bodies.length > 0) {
					targetBody = level.bodies[level.bodies.length - 1];
				}

				if (targetBody !== undefined) {
					const pwTarget = planeToWorld(bodyPositionAt(targetBody, tNow), 0);
					const pwProbe = planeToWorld(probePos, 0);
					const isMicroSystem = targetBody.orbitRadius < 2.0;
					const distTarget = isMicroSystem ? Math.max(0.18, targetBody.radius * 180) : Math.max(8, targetBody.radius * 350);
					const distProbe = isMicroSystem ? Math.max(0.015, deps.scene.probeRadius * 10) : Math.max(1.5, deps.scene.probeRadius * 6);

					if (k < 0.35) {
						// 幕一：目标星球特写
						const e1 = k / 0.35;
						const az = (0.2 + e1 * 0.15) * Math.PI;
						const tilt = 0.35 * Math.PI;
						const eye = Vec3(
							pwTarget.x + Math.sin(az) * Math.cos(tilt) * distTarget,
							pwTarget.y + Math.sin(tilt) * distTarget,
							pwTarget.z + Math.cos(az) * Math.cos(tilt) * distTarget,
						);
						frame = { target: pwTarget, eye };
					} else if (k < 0.72) {
						// 幕二：溯源拉升与飞掠
						const e2 = (k - 0.35) / 0.37;
						const ease2 = e2 * e2 * (3 - 2 * e2);
						const az = (0.35 + (1 - ease2) * 0.1) * Math.PI;
						const peakDist = isMicroSystem ? 1.2 : Math.max(distTarget * 2.2, 45);
						const curDist = distTarget + (peakDist - distTarget) * Math.sin(ease2 * Math.PI) + (distProbe - distTarget) * ease2;
						const targetCenter = Vec3(
							pwTarget.x + (pwProbe.x - pwTarget.x) * ease2,
							pwTarget.y + (pwProbe.y - pwTarget.y) * ease2,
							pwTarget.z + (pwProbe.z - pwTarget.z) * ease2,
						);
						const eye = Vec3(
							targetCenter.x + Math.sin(az) * 0.5 * curDist,
							targetCenter.y + curDist * 0.8,
							targetCenter.z + Math.cos(az) * 0.5 * curDist,
						);
						frame = { target: targetCenter, eye };
					} else {
						// 幕三：归巢探测器特写
						const e3 = (k - 0.72) / 0.28;
						const ease3 = 1 - (1 - e3) * (1 - e3);
						const az = 0.25 * Math.PI;
						const tilt = 0.36 * Math.PI;
						const curDist = (distTarget * 0.4) * (1 - ease3) + distProbe * ease3;
						const eye = Vec3(
							pwProbe.x + Math.sin(az) * Math.cos(tilt) * curDist,
							pwProbe.y + Math.sin(tilt) * curDist,
							pwProbe.z + Math.cos(az) * Math.cos(tilt) * curDist,
						);
						frame = { target: pwProbe, eye };
					}
				}
			}
		}
		// 自由观察的叠加（绕目标转 + 缩放）—— 转完相机依然跟着探测器走
		frame = applyObserve(frame);
		deps.rig.apply(deps.camera, frame);
		deps.scene.syncBackdrop(frame.eye, frame.target);
		const basis = makeBasis(frame);

		// 探测器屏幕位置（拖动方向的基准）：**必须与玩家看到的那个视图一致** ——
		// 2D 里探测器的位置来自 2D 映射（plan.probeScreen 就是图上那个像素），
		// 拿 3D 投影去判"按下点离探测器近不近"会让瞄准区跑到屏幕另一边。
		if (core.viewMode === '2D') {
			const sp = deps.plan.probeScreen();
			deps.aim.setProbeOffset({ x: sp.x - deps.viewW / 2, y: sp.y - deps.viewH / 2 });
		} else {
			const pp = projectPrepared(planeToWorld(probePos, 0), basis);
			if (pp !== undefined) deps.aim.setProbeOffset({ x: pp.x, y: pp.y });
		}

		// ⚠️ 预测线必须**每帧**重画，不能只在拖动时重画：
		// 重试后相机会用 lerp 从飞行终点视图滑回瞄准视图（约 20-30 帧），
		// 若只在 aimDirty 时画一次，线会冻结在过渡中途的投影上，
		// 看起来“不是从探测器出发”（实测踩过）。
		// 代价：每帧 600 步 simulate + ~150 点投影，可忽略。
		// 只在瞄准/日期变化时重算（同一次拖动里每帧都算一遍是浪费；投影仍然每帧做）。
		if (!aimed) {
			// 还没瞄过：**不画预测线**（用户 S3.12 明确要求"默认不要显示预览线"）。
			// 从前这里画的是"什么都不做会飞到哪"（待机轨道），既不是玩家的意图，
			// 又会在玩家松手后把他的线**覆盖**掉。
			deps.trajectory.clearPrediction();
			deps.plan.clearPrediction();
			predForce = true; // 下次需要画线时立刻重算（缓存键被清掉了）
		} else {
			// ⚠️ 缓存键必须带上**日期**与**探测器此刻的位置**：行星位置随日期变、L1 的探测器自己在动，
			//    漏掉任何一项都会留下一条"对不上此刻物理"的旧线（看到的 ≠ 飞到的）。
			// ⚠️ 位置精度从 toFixed(2) 提到 toFixed(7)：真实阿波罗剖面下停泊轨半径只有 3.514e-3，
			//    两位小数会把整条轨道压成一个点 ⇒ 预测线永远不刷新（旧口径在 0.1 单位时代刚好够用）。
			const aimKey = core.aim.velocity.x.toFixed(4) + '|' + core.aim.velocity.y.toFixed(4) + '|' + (core.brakeMode ? 'B' : 'C');
			const posKey = tNow.toFixed(4) + '|' + probePos.x.toFixed(7) + ',' + probePos.y.toFixed(7);
			predAccum += dt;
			const needIt = predForce || ((aimKey !== predAimKey || posKey !== predPosKey) && predAccum >= PredMinIntervalSec);
			if (needIt) {
				predForce = false;
				predAccum = 0;
				predAimKey = aimKey;
				predPosKey = posKey;
				// ⚠️ 与 coreLaunch 共用 burnToMotion：预测线里必须带上反推段，否则"看到的 ≠ 飞到的"
				// 基准是**此刻**的探测器状态（待机时它在动，不是 probeStart）。
				const motion = burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps);
				predPoints = simulate(
					{ pos: { x: probePos.x, y: probePos.y }, vel: motion.init },
					level.bodies,
					{ steps: level.predictSteps !== undefined ? level.predictSteps : PredictSteps, dt: core.dt, sampleEvery: 4, escapeRadius: level.escapeRadius, t0: tNow, brake: motion.brake },
				).points;
			}
			deps.trajectory.setPrediction(predPoints, basis);
			// 2D 用的是**同一批采样点**（硬约束 5）：只换投影，不重跑 simulate
			deps.plan.setPrediction(predPoints);
		}
		// 探测器停泊轨（B2）：3D 走投影折线（远侧压暗），2D 直接画圆 —— 同一份 (中心, 半径)
		if (idleOrbit !== undefined) {
			const hc = bodyPositionAt(level.bodies[idleOrbit.hostIndex], tNow);
			deps.trajectory.setOrbitRing(hc, idleOrbit.r, basis);
			deps.plan.setProbeOrbit(hc, idleOrbit.r);
		}
		const rings = goalRingsAt(tNow);
		deps.trajectory.setGoalRings(rings, basis);
		deps.trajectory.clearTrail();
		// 2D 的到达圈与 3D 共用同一批 GoalRing —— "下一站在哪"只有一个事实来源
		deps.plan.setGoalRings(rings);
		deps.plan.clearTrail();
		deps.plan.flush();
	};

	/**
	 * 终章「暗淡蓝点」（S3.18）：一屏，不做动画分镜、不做第二段文案（砍线顺序里终章细节是第一项）。
	 *
	 * 画面 = 复用现有 3D 场景与星空背板，相机拉到**尽可能远**回望太阳系：
	 *   - 太阳缩成一个亮点；
	 *   - 地球按**真实比例**缩成一个点（半径 1.76 @ ~1000 单位，直径约 5 px）——
	 *     **不放大**（用户当初否掉过「为画面放大行星」，docs/关卡舞台表.md 第二节第 9 条）。
	 *
	 * 世界时刻仍然只有一个事实来源：`tWorld = core.t0 + core.flightTime`（硬约束 7）。
	 * ⚠️ 地球此时是 L6 planets 里的 `homeEarth()`（gm = 0 的布景天体，位置随日期变）⇒
	 *    必须按 tWorld 取它，写死 t = 0 会让地球跳回相位 0（物理对、画面错）。
	 */
	const updateFinale = (): void => {
		deps.aim.setEnabled(false);
		if (core.flight === undefined) return;
		const idx = coreProbeIndex(core);
		const pos = core.flight.points[idx];
		const tWorld = core.t0 + core.flightTime;

		// 行星 / 地球 / 流动光点都按同一个 tWorld 同步（没有第二时间源）
		deps.scene.syncBodies(tWorld);
		deps.scene.syncProbe(pos);
		deps.scene.faceVelocity(core.flight.velocities[idx]);

		// 取景：绕开机架（它的距离夹在 60–300，装不下「尽可能远」），直接写相机
		const frame = finaleCamera(pos, FinaleCamDist, FinaleCamTiltDeg);
		deps.camera.lookAt(frame.eye, frame.target, Vec3(0, 1, 0));
		deps.scene.syncBackdrop(frame.eye, frame.target);

		// 尾迹 = 已经飞过的前缀（同一批采样点，只是投影换成终章机位）
		const trail: P2[] = [];
		for (let i = 0; i <= idx; i++) trail.push(core.flight.points[i]);
		const rings = goalRingsAt(tWorld, idx);
		const basis = makeBasis(frame);
		// 飞行期不再画停泊轨（B2）：它属于"出发前"，留着会冻结在发射那一刻
		deps.trajectory.clearOrbitRing();
		deps.plan.clearProbeOrbit();
		deps.trajectory.setTrail(trail, basis);
		deps.trajectory.setGoalRings(rings, basis);
		deps.plan.clearPrediction();
		deps.plan.setGoalRings(rings);
		deps.plan.flush();
	};
	const updateFlying = (dt: number): boolean => {
		deps.aim.setEnabled(false);
		// S3.17：慢动作判定在 coreUpdate 里做（要 level：天体位置随时间动），
		// 结果写回 core.slowmo / core.slowmoBody —— 这一帧的取景与日志读它们
		const entered = coreUpdate(core, dt, level);
		if (core.flight === undefined) return entered;

		const idx = coreProbeIndex(core);
		const pos = core.flight.points[idx];
		// 飞行段的世界时刻 = 发射日期 + 已飞行时间。
		// 之前这里直接用 flightTime 同步行星：发射日期调晚之后，物理用的是 t0（对），
		// 行星模型却回到 t=0 的姿态（错）-- 用户实测到的「模型位置跳回时间 0」。
		const tWorld = core.t0 + core.flightTime;

		// 慢动作状态迁移打点（AGENTS：每次动作一行日志 —— 有行 = 状态真的换了）
		if (core.slowmo !== lastSlowmo || core.slowmoBody !== lastSlowmoBody) {
			lastSlowmo = core.slowmo;
			lastSlowmoBody = core.slowmoBody;
			const near = core.slowmoBody >= 0 ? level.bodies[core.slowmoBody] : undefined;
			const nearD = near !== undefined ? distance(pos, bodyPositionAt(near, tWorld)) : 0;
			print('[escape-velocity] slow-mo ' + (core.slowmo ? 'engage' : 'release') +
				' body#' + core.slowmoBody.toFixed(0) +
				' r=' + (near !== undefined ? near.radius.toFixed(2) : '-') +
				' d=' + nearD.toFixed(1) + ' t=' + core.flightTime.toFixed(2));
		}
		// 定频飞行日志（每 0.5 真实秒一行）：**同样帧数下推进的世界时间更少**就是"真的放慢了"
		// 的直接证据（S3.17 验收第 4 条）。慢动作期间 speed 从 2.00 掉到 0.50，一行就看得出。
		flightLogT += dt;
		if (flightLogT >= 0.5) {
			flightLogT = 0;
			const total = (core.flight.points.length - 1) * core.dt;
			print('[escape-velocity] flight t=' + core.flightTime.toFixed(2) + '/' + total.toFixed(1) +
				' idx=' + idx.toFixed(0) +
				' speed=' + (core.playback * (core.slowmo ? SlowMoFactor : 1)).toFixed(2) +
				' (playback=' + core.playback.toFixed(0) + 'x slowmo=' + (core.slowmo ? '1' : '0') + ')');
		}

		deps.scene.syncBodies(tWorld);
		deps.scene.syncProbe(pos);
		if (idx > 0) {
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx - 1]));
		}

		// 取景（S3.17）：慢动作期间**贴近被掠过的天体** —— 复用 CameraRig 的逐点半径求解，
		// 关键点换成 [探测器, 被掠天体]（锚点/目标环出画，特写让位），距离下限放到
		// SlowMoCloseDist（否则 CameraMinDistance=60 把"贴近"吃掉：实测相机只从 ~110 收到
		// 60、木星在画面里只大 1.8 倍，不像特写）。
		let fr: { pts: P2[]; radii: number[] };
		let closeDist: number | undefined = undefined;
		if (core.slowmo && core.slowmoBody >= 0) {
			const near = level.bodies[core.slowmoBody];
			// S5.1：同 framingPoints —— 特写也要用视觉半径，否则模型被画面切掉
			let nearR = near.radius;
			for (let i = 0; i < level.bodies.length; i++) {
				const b = level.bodies[i];
				if (b.gm === near.gm && b.radius === near.radius && b.orbitRadius === near.orbitRadius) {
					if (i < deps.visuals.length && deps.visuals[i].displayRadius > nearR) nearR = deps.visuals[i].displayRadius;
					break;
				}
			}
			fr = { pts: [pos, bodyPositionAt(near, tWorld)], radii: [deps.scene.probeRadius, nearR] };
			closeDist = SlowMoCloseDist;
		} else {
			fr = framingPoints(pos, tWorld);
		}
		const frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii, closeDist);
		deps.rig.apply(deps.camera, frame);
		deps.scene.syncBackdrop(frame.eye, frame.target);
		const basis = makeBasis(frame);

		// 尾迹 = 已飞过的前缀
		const trail: P2[] = [];
		for (let i = 0; i <= idx; i++) trail.push(core.flight.points[i]);
		const rings = goalRingsAt(tWorld, idx);
		// 飞行期不再画停泊轨（B2）：它属于"出发前"，留着会冻结在发射那一刻
		deps.trajectory.clearOrbitRing();
		deps.plan.clearProbeOrbit();
		deps.trajectory.setTrail(trail, basis);
		deps.trajectory.setGoalRings(rings, basis);

		// 2D（玩家手动切过去时看得见自己飞过哪）：同一批采样点、同一个 tWorld
		deps.plan.syncBodies(level.bodies, deps.visuals, tWorld);
		deps.plan.syncProbe(pos, core.flight.velocities[idx]);
		deps.plan.setTrail(trail);
		deps.plan.clearPrediction();
		deps.plan.setGoalRings(rings);
		deps.plan.flush();

		return entered;
	};

	/**
	 * **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	 *
	 * 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	 * 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	 * 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	 * 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	 *
	 * toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	 * toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	 */
	const handoffDate = (toT0: boolean): void => {
		const next = coreHandoffDate(core.t0, clock, toT0);
		core.t0 = next.t0;
		clock = next.clock;
		print('[escape-velocity] date handoff ' + (toT0 ? 'clock->t0' : 't0->clock') + ' t0=' + core.t0.toFixed(1) + ' clock=' + clock.toFixed(1));
	};

	const update = (dt: number): void => {
		// 视图也必须**状态驱动**（AGENTS 硬约束 5）：每帧按 core.viewMode 对一次节点，
		// 别只靠"点按钮时切一下" —— 切关/重建/自动回归序列会留下一个对不上的视图。
		applyView();
		if (core.phase === 'Aiming' || core.phase === 'Armed') {
			updateAiming(dt);
		} else if (core.phase === 'Flying') {
			const entered = updateFlying(dt);
			if (entered && core.result !== undefined) {
				// S3.18：最后一关成功 ⇒ 进终章（不弹普通结算面板；终章要回选关只有那一颗按钮）
				const toFinale = deps.finale === true && core.result === 'success';
				if (toFinale) coreEnterFinale(core);
				// onResult 先走：解锁 / 存档只有这一条路（面板显隐完全交给 onPhase，见 init.ts）
				const telem = calcFlightTelemetry(core, level);
				deps.onResult(core.result, telem);
				if (toFinale && core.flight !== undefined && deps.onFinale !== undefined) {
					const end = core.flight.points.length - 1;
					deps.onFinale({
						distance: distance(core.flight.points[end], level.probeStart),
						time: core.flightTime,
						tWorld: core.t0 + core.flightTime,
					});
				}
				deps.onPhase(toFinale ? 'Finale' : 'Result');
			}
		} else if (core.phase === 'Finale') {
			updateFinale();
		}
		// Result / Finale：画面冻结，等待输入（终章只有一颗「返回关卡选择」）
	};

	return {
		phase: (): GamePhase => core.phase,
		speedPow: (): number => speedPow,
		speedMaxPow: (): number => speedMaxPow,
		isPaused: (): boolean => paused,
		speedRate: (): number => core.playback,
		missionSeconds: (): number => {
			const w = core.phase === 'Flying' || core.phase === 'Result' ? core.t0 + core.flightTime : core.t0 + clock;
			return speedUnit > 0 ? w / speedUnit : 0;
		},
		speedUp: (): void => {
			if (speedPow >= speedMaxPow) return;
			speedPow += 1;
			paused = false;
			applySpeedRate();
			print('[escape-velocity] speed -> 1e' + speedPow.toFixed(0) + 'x (' + core.playback.toFixed(6) + ' 游戏秒/真实秒)');
		},
		speedDown: (): void => {
			if (speedPow <= 0) return;
			speedPow -= 1;
			paused = false;
			applySpeedRate();
			print('[escape-velocity] speed -> 1e' + speedPow.toFixed(0) + 'x (' + core.playback.toFixed(6) + ' 游戏秒/真实秒)');
		},
		togglePause: (): void => {
			paused = !paused;
			applySpeedRate();
			print('[escape-velocity] ' + (paused ? 'paused' : 'resumed') + ' (speedPow=1e' + speedPow.toFixed(0) + ')');
		},
		result: (): ResultKind | undefined => core.result,
		onAimDrag: (a: AimResult): void => {
			if (introTourActive) finishIntroTour();
			core.aim = a;
			aimed = true; // 玩家动过手了 ⇒ 从他拖动的那一刻起，预测线才属于他（S3.12）
		},
		aimReady: (): void => {
			// B1：松手进 Armed 时**强制**重算一次预测线（拖动期间是节流的，最后那一下必须精确）
			predForce = true;
			if (!coreArm(core)) return;
			applyView(); // Armed 仍是"瞄准期" ⇒ 留在 2D（除非玩家自己切过）
			deps.onPhase('Armed');
		},
		launchArmed: (): void => {
			// 状态守卫：只有 Armed 才能打出去（连点/迟到的回调一律无效）
			if (core.phase !== 'Armed') return;
			handoffDate(true); // ⚠️ 必须在 coreLaunch 之前：飞行/结算只认 core.t0
			coreLaunch(core, core.aim.velocity, level, probePos, probeVel);
			deps.trajectory.clearPrediction();
			deps.plan.clearPrediction();
			applyView(); // 按下发射 ⇒ 切 3D（日志行 view -> 3D 就是这条路径的证据）
			deps.onPhase('Flying');
		},
		armed: (): boolean => core.phase === 'Armed',
		viewMode: (): PlanViewMode => core.viewMode,
		toggleViewMode: (): void => {
			// 按钮只表达意图：翻转发生在 core 里（viewMode 是唯一事实来源）
			coreToggleView(core);
			applyView();
		},
		skipIntroTour: (): void => {
			finishIntroTour();
		},
		isIntroTourActive: (): boolean => introTourActive,
		observeDrag: (dx: number, dy: number): void => {
			if (introTourActive) {
				finishIntroTour();
				return;
			}
			print('[escape-velocity] observe drag dx=' + dx.toFixed(0) + ' dy=' + dy.toFixed(0) + ' yaw=' + obsYawDeg.toFixed(0));
			obsYawDeg += dx * 0.35;
			obsPitchDeg += dy * 0.25;
			if (obsPitchDeg > 40) obsPitchDeg = 40;
			if (obsPitchDeg < -40) obsPitchDeg = -40;
		},
		observeZoom: (deltaDist: number): void => {
			obsZoom *= 1 + deltaDist * 0.002;
			if (obsZoom < 0.4) obsZoom = 0.4;
			if (obsZoom > 1.8) obsZoom = 1.8;
		},
		launch: (v: P2): void => {
			// B3：发射瞬间把档位提到"飞行观赏档"（L1 = 10,000× ⇒ 0.9 天的快转移 8.6 秒打完）。
			// 这是**唯一**一处替玩家改档位的地方 —— 1× 下这一发要飞 ~22 小时，等不起。
			if (level.flightSpeedPow !== undefined && level.flightSpeedPow > speedPow) {
				speedPow = level.flightSpeedPow;
				paused = false;
				applySpeedRate();
				print('[escape-velocity] speed auto -> 1e' + speedPow.toFixed(0) + 'x (launch)');
			}
			if (core.phase !== 'Aiming' && core.phase !== 'Armed') return;
			handoffDate(true); // ⚠️ 同上：日期必须在 coreLaunch 之前交给 t0
			// v 是"点火"；从**此刻**的探测器状态出发（待机时它一直在绕地球走）
			coreLaunch(core, v, level, probePos, probeVel);
			deps.trajectory.clearPrediction();
			deps.plan.clearPrediction();
			applyView(); // 开发钩子/回归脚本的发射与按钮走同一条相态流转（同样自动切 3D）
			deps.onPhase('Flying');
		},
		retry: (): void => {
			if (core.phase !== 'Result') return;
			handoffDate(false); // 把日期从 t0 拿回 clock：重试保留玩家挑好的时机
			aimed = false;      // 重新瞄准：预测线回到"还没瞄过"的状态
			introTourActive = false; // 重试不重放运镜
			coreRetry(core, level.aimMin);
			deps.trajectory.clearTrail();
			deps.trajectory.clearPrediction();
			deps.trajectory.clearGoalRings();
			deps.plan.clearTrail();
			deps.plan.clearPrediction();
			deps.plan.clearGoalRings();
			applyView(); // 重试 = 重新规划 ⇒ 回 2D
			deps.onPhase('Aiming');
		},
		backToSelect: (): boolean => {
			if (!coreBackToSelect(core)) return false;
			// 离开本关：线不能留在屏幕上（下一关会画自己的）
			deps.aim.setEnabled(false);
			deps.trajectory.clearTrail();
			deps.trajectory.clearPrediction();
			deps.trajectory.clearGoalRings();
			deps.plan.clearTrail();
			deps.plan.clearPrediction();
			deps.plan.clearGoalRings();
			applyView();
			deps.onPhase('LevelSelect');
			return true;
		},
		startLevel: (): void => {
			aimed = false;
			coreRetry(core, level.aimMin);
			deps.rig.reset();
			// 进关开启 3D 倒叙溯源运镜：特写目标 ➔ 飞掠 ➔ 探测器 ➔ 切入 2D
			introTourActive = true;
			introTourT = 0;
			introLogged = false;
			core.viewMode = '3D';
			appliedMode = '';
			applyView(); // 进关先展示 3D 世界
			prepareIdle();
			deps.trajectory.clearTrail();
			deps.trajectory.clearPrediction();
			deps.trajectory.clearGoalRings();
			deps.plan.clearTrail();
			deps.plan.clearPrediction();
			deps.plan.clearGoalRings();
			deps.onPhase('Aiming');
		},
		stepTime: (dir: number, span: number): void => {
			// 相态守卫（S3.11）：时间轴只在**发射前**能动。飞行用的是 tWorld = t0 + flightTime，
			// 这时候改 t0 等于把参考系整个挪走（行星会在飞行途中跳位）；结算后更没意义。
			if (!coreTimeWarpAllowed(core)) {
				print('[escape-velocity] stepTime ignored (phase=' + core.phase + ')');
				return;
			}
			const span0 = span > 0 ? span : 0;
			clock += dir * TimeWarpStep;
			if (clock < 0) clock = 0;
			if (span0 > 0 && clock > span0) clock = span0;
			// 证据打点（放在 Game 里：HUD→Game 这一路的真相在这里，省得被别处的旧日志带偏）
			print('[escape-velocity] stepTime dir=' + dir.toFixed(0) + ' clock=' + clock.toFixed(0));
		},
		dateNow: (): number => core.t0 + clock,
		setBrakeMode: (on: boolean): void => {
			core.brakeMode = on;
			// 预测线要跟着重算（缓存键里带了 brakeMode，下一帧自然会重算）
		},
		brakeMode: (): boolean => core.brakeMode,
		setPlaybackSpeed: (speed: number): void => {
			// 只认 HUD 那三个档（1/2/4）；别的值忽略，别把 playback 写成奇怪的比例
			if (speed !== 1 && speed !== 2 && speed !== 4) return;
			core.playback = speed;
			print('[escape-velocity] playback speed -> ' + speed.toFixed(0) + 'x (phase=' + core.phase + ')');
		},
		playbackSpeed: (): number => core.playback,
		burnNow: (): number => Math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y),
		isBrakeWindowActive: (): boolean => isBrakeWindowActive(core, level),
		applyInFlightBrake: (): boolean => applyInFlightBrake(core, level),
		hasBraked: (): boolean => core.hasBraked,
		// 包一层箭头函数：简写属性会触发 TS100016（见 Hud.ts 同名注释）
		update: (frameDt: number): void => update(frameDt),
	};
}
