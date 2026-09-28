/**
 * 纯物理内核：平面引力积分 + 轨迹推演。
 *
 * 设计约束（见 docs/开发手册.md §4.1 / §5.1，PLAN S1.1）：
 *
 * - **纯函数**：不依赖任何引擎对象（不 import 'Dora'），可用普通单测验证。
 * - **固定步长**：调用方传入 dt；本模块内部不读时间、不看帧率。
 *   这是“同一输入 → 同一结果”（验收硬指标）的前提。
 * - **预测与真实共用**：瞄准预览和松手后的真实飞行必须调用同一个 `simulate`，
 *   否则会出现“看起来一样、其实不一样”。
 *
 * 坐标系：物理平面（2D）。平面 → 世界的映射由 Config 的
 * `PlaneToWorldX` / `PlaneToWorldZ` 决定（已实测：平面必须沿屏幕纵向展开）。
 * 本模块只认平面坐标，不关心世界坐标。
 *
 * 调参分离：`GravityScale` / `OrbitSpeedScale` 由调用方在构造 `Body` 前应用
 * （见 `applyScales`），本模块自身不读配置。
 *
 * ⚠️ 命名：`P2` 是平面内的二维向量，与 Dora 的 `Vec2`（引擎对象）无关。
 * 不复用 `Vec2` 是为了保持本模块零引擎依赖、可独立测试。
 */

/** 平面内的二维向量（纯数据）。 */
export interface P2 {
	x: number;
	y: number;
}

/**
 * 一颗引力源（行星），视为点质量。
 *
 * 位置由公转描述：以 `orbitCenter` 为圆心、`orbitRadius` 为半径，
 * 按 `orbitPeriod` 周期运动（`orbitPeriod === 0` 表示静止，对应第 2 关）。
 */
export interface Body {
	/** 引力强度 GM（引力常数 × 质量，合并成一个可调数字）。 */
	gm: number;
	/** 碳毁半径（探测器中心进入此半径即撞毁）。 */
	radius: number;
	/** 公转圆心（平面坐标）。 */
	orbitCenter: P2;
	/** 公转半径。 */
	orbitRadius: number;
	/** 公转周期（秒）；0 = 静止。 */
	orbitPeriod: number;
	/** 初始相位（弧度）。t=0 时行星的位置角。 */
	phase0: number;
	/** 公转方向：+1 逆时针（数学正向），-1 顺时针。 */
	orbitDirection: 1 | -1;
	/**
	 * **宿主的轨道**（卫星用，S3.13）：当这颗天体绕的是另一颗**自己也在动**的天体时
	 * （月球绕地球），`orbitCenter` 这个常量就不够用了 —— 把宿主的整套轨道参数在这里
	 * 再描述一遍，位置就能**解析求出**。
	 *
	 * 为什么不给 `bodyPositionAt` 加参数：它被物理、预测线、到达环、取景到处调用，
	 * 加参数等于全仓库改签名。嵌套一份宿主既不动签名，也保持了"纯数据"。
	 *
	 * ⚠️ 这份参数必须与宿主天体自己**逐字段一致**；`applyScales` 会一起缩放它。
	 * 关卡数据里用 `satellite(...)` 构造（直接把宿主对象传进去），单测守着。
	 */
	/** 宿主的轨道（卫星用）。 */
	host?: Body;
	/** 障碍物标识（街机模式：纯碰撞体，gm=0）。 */
	isObstacle?: boolean;
	/** 天体/障碍物名称。 */
	name?: string;
}

/** 探测器状态。 */
export interface ProbeState {
	pos: P2;
	vel: P2;
}

/** 推演结果。 */
export type Outcome =
	/** 推演步数用尽，仍在飞行（瞄准预览的常态）。 */
	| 'running'
	/** 撞上某颗行星。 */
	| 'crashed'
	/** 飞出 escapeRadius 范围。 */
	| 'escaped';

export interface SimOptions {
	/** 最多推进的物理步数。 */
	steps: number;
	/** 固定步长（秒）。 */
	dt: number;
	/** 采样间隔（每 N 步记录一个点）；<=0 视为 1。 */
	sampleEvery: number;
	/** 越界半径（距原点的距离）；<=0 表示不检查。 */
	escapeRadius: number;
	/**
	 * 起始时刻（秒，S3.6.4 时间轴）。
	 *
	 * 时间轴的**唯一**物理入口：行星位置本来就是 t 的函数，从 t0 起积分
	 * 就等于「把发射时刻往后拨 t0」。省略 = 0（与旧行为逐位一致）。
	 * ⚠️ 预测线与真实飞行必须传同一个 t0，否则又是「看到的 ≠ 飞到的」。
	 */
	t0?: number;
	/**
	 * 反推段（S3.9.2「刹车模式」）：从第 startStep 步起，每步沿 **-v̂** 扣掉固定 Δv。
	 *
	 * 为什么用"恒定推力"而不是一次性反向脉冲：① 视觉上预测线**后半段变平**（用户要的"前半段加速、
	 * 后半段减速"）；② 总量 = brake.dv（只跟步数有关、与帧率无关，确定性不破）。
	 * 省略 = 不反推（= 旧的"点火后惯性滑行"）。
	 */
	brake?: BrakeThrust;
}

/**
 * 反推段参数。
 *
 * ⚠️ Δv 预算是**共享**的：点火用它、反推也用它（`Game.dvSplit` 决定怎么分），
 * 所以"刹得越狠 ⇒ 冲得越慢"是算术，不是口号。
 */
export interface BrakeThrust {
	/** 反推总 Δv（速度单位）。 */
	dv: number;
	/** 从第几步开始反推；省略 = steps / 2（"后半程减速"）。 */
	startStep?: number;
}

export interface SimResult {
	outcome: Outcome;
	/** 采样点（含起点与终点），用于绘制轨迹。 */
	points: P2[];
	/**
	 * 与 `points` 一一对应的**速度向量**（S3.9.2）：载具判据（捕获入轨要算"相对行星的速度"）
	 * 与 HUD 的读数都需要它。
	 *
	 * ⚠️ 为什么不是"让调用方用位置差分去估"：撞毁时推演会在那一帧**截断**，最后一个采样点只跨了
	 * 半步，差分出来的速度明显偏小 —— 实测把"一头撞进行星"判成了"成功入轨"（rel=34.7 vs 阈值 43.1）。
	 */
	velocities: P2[];
	/** 推演结束时的状态。 */
	state: ProbeState;
	/** 撞毁的行星索引；-1 表示未撞毁。 */
	hitIndex: number;
	/** 实际推进的步数。 */
	stepsRun: number;
}

/** 避免除零的极小距离平方。 */
const MIN_DIST2 = 1e-12;

/** 两向量差。 */
export function sub(a: P2, b: P2): P2 {
	return { x: a.x - b.x, y: a.y - b.y };
}

/** 向量长度。 */
export function length(a: P2): number {
	return Math.sqrt(a.x * a.x + a.y * a.y);
}

/** 两点距离。 */
export function distance(a: P2, b: P2): number {
	const dx = a.x - b.x;
	const dy = a.y - b.y;
	return Math.sqrt(dx * dx + dy * dy);
}

/**
 * 行星在时刻 t 的位置。
 * `t` 的单位是秒，`t = 0` 即 `phase0` 描述的姿态。
 */
export function bodyPositionAt(b: Body, t: number): P2 {
	// 圆心：有宿主就解析宿主此刻的位置（月球绕地球，而地球自己在绕日）
	const c = b.host !== undefined ? bodyPositionAt(b.host, t) : b.orbitCenter;
	let angle = b.phase0;
	if (b.orbitPeriod !== 0) {
		angle += b.orbitDirection * (2 * Math.PI) * (t / b.orbitPeriod);
	}
	return {
		x: c.x + b.orbitRadius * Math.cos(angle),
		y: c.y + b.orbitRadius * Math.sin(angle),
	};
}

/**
 * 点 p 在时刻 t 受到的引力加速度。
 * 平方反比：a = Σ gm_i * (q_i - p) / |q_i - p|³
 */
export function accelerationAt(bodies: Body[], p: P2, t: number): P2 {
	let ax = 0;
	let ay = 0;
	for (const b of bodies) {
		const q = bodyPositionAt(b, t);
		const dx = q.x - p.x;
		const dy = q.y - p.y;
		const d2 = dx * dx + dy * dy;
		if (d2 < MIN_DIST2) continue;
		const invd = 1 / Math.sqrt(d2);
		const invd3 = invd * invd * invd;
		ax += b.gm * dx * invd3;
		ay += b.gm * dy * invd3;
	}
	return { x: ax, y: ay };
}

/**
 * 把全部天体在时刻 t 的位置写进 `out`（**预分配、原地覆盖**）。
 *
 * 为什么要有它（B1，2026-09-28）：L1 换成真实阿波罗剖面后，一次预测推演要 **8000 步**，
 * 而每一步原本要算 **6 次** `bodyPositionAt`（加速度 3 次 + 碰撞检测 3 次，每次还带一次
 * 宿主链递归的 sin/cos）。滚动缓存之后每步只算 **3 次**，预测线耗时直接减半。
 * 结果与旧实现**逐位相同**（同一时刻、同一批位置、同一套算式，只是不再重复计算）。
 */
function fillPositions(bodies: Body[], t: number, out: P2[]): void {
	for (let i = 0; i < bodies.length; i++) {
		out[i] = bodyPositionAt(bodies[i], t);
	}
}

/** 用**已算好的**天体位置求引力加速度（= `accelerationAt` 的缓存版，算式逐字相同）。 */
function accelerationFrom(bodies: Body[], positions: P2[], p: P2): P2 {
	let ax = 0;
	let ay = 0;
	for (let i = 0; i < bodies.length; i++) {
		const q = positions[i];
		const dx = q.x - p.x;
		const dy = q.y - p.y;
		const d2 = dx * dx + dy * dy;
		if (d2 < MIN_DIST2) continue;
		const invd = 1 / Math.sqrt(d2);
		const invd3 = invd * invd * invd;
		ax += bodies[i].gm * dx * invd3;
		ay += bodies[i].gm * dy * invd3;
	}
	return { x: ax, y: ay };
}

/** 用**已算好的**天体位置做碰撞检测（= `collisionIndex` 的缓存版）。 */
function collisionFrom(bodies: Body[], positions: P2[], p: P2): number {
	for (let i = 0; i < bodies.length; i++) {
		const q = positions[i];
		const dx = q.x - p.x;
		const dy = q.y - p.y;
		if (Math.sqrt(dx * dx + dy * dy) < bodies[i].radius) return i;
	}
	return -1;
}

/**
 * 推进一步（半隐式欧拉 / 辛欧拉）。
 * 先更新速度、再用新速度更新位置 —— 对轨道运动足够稳定，且实现简单、完全确定。
 */
export function step(state: ProbeState, bodies: Body[], t: number, dt: number): ProbeState {
	const a = accelerationAt(bodies, state.pos, t);
	const vx = state.vel.x + a.x * dt;
	const vy = state.vel.y + a.y * dt;
	return {
		pos: { x: state.pos.x + vx * dt, y: state.pos.y + vy * dt },
		vel: { x: vx, y: vy },
	};
}

/** 返回命中的行星索引；未命中返回 -1。 */
export function collisionIndex(bodies: Body[], p: P2, t: number): number {
	for (let i = 0; i < bodies.length; i++) {
		const b = bodies[i];
		const q = bodyPositionAt(b, t);
		const dx = q.x - p.x;
		const dy = q.y - p.y;
		if (Math.sqrt(dx * dx + dy * dy) < b.radius) return i;
	}
	return -1;
}

/**
 * 从初始状态推演一段轨迹。
 *
 * 确定性的关键：全程只用 `dt` 累加时间，不读任何外部时钟；
 * 同样的 (initial, bodies, opts) 必得同样的结果。
 */
export function simulate(initial: ProbeState, bodies: Body[], opts: SimOptions): SimResult {
	const sampleEvery = opts.sampleEvery > 0 ? opts.sampleEvery : 1;

	let s: ProbeState = {
		pos: { x: initial.pos.x, y: initial.pos.y },
		vel: { x: initial.vel.x, y: initial.vel.y },
	};

	const points: P2[] = [{ x: s.pos.x, y: s.pos.y }];
	const velocities: P2[] = [{ x: s.vel.x, y: s.vel.y }];
	let outcome: Outcome = 'running';
	let hitIndex = -1;
	let stepsRun = 0;
	let t = opts.t0 !== undefined ? opts.t0 : 0;

	const escape2 = opts.escapeRadius > 0 ? opts.escapeRadius * opts.escapeRadius : 0;

	// 天体位置的**滚动缓存**（见 fillPositions）：每步只更新一次，
	// 加速度用「这一刻」的位置、碰撞检测用「推进之后」的位置 —— 与旧实现逐位一致。
	const bufA: P2[] = [];
	const bufB: P2[] = [];
	fillPositions(bodies, t, bufA);
	let curPositions: P2[] = bufA;
	let nextPositions: P2[] = bufB;

	// 反推段（见 SimOptions.brake）：总 Δv 均摊到剩余步数 ⇒ 每步固定的减速度。
	const brake = opts.brake;
	const brakeStart = brake !== undefined ? (brake.startStep !== undefined ? brake.startStep : Math.floor(opts.steps / 2)) : -1;
	const brakeSteps = brake !== undefined ? Math.max(1, opts.steps - brakeStart) : 1;
	const brakeDvPerStep = brake !== undefined ? brake.dv / brakeSteps : 0;

	for (let i = 0; i < opts.steps; i++) {
		// 半隐式欧拉（= step()，只是复用已缓存的天体位置）
		const acc = accelerationFrom(bodies, curPositions, s.pos);
		const nvx = s.vel.x + acc.x * opts.dt;
		const nvy = s.vel.y + acc.y * opts.dt;
		s = { pos: { x: s.pos.x + nvx * opts.dt, y: s.pos.y + nvy * opts.dt }, vel: { x: nvx, y: nvy } };
		t += opts.dt;
		stepsRun += 1;

		if (brake !== undefined && i >= brakeStart) {
			const sp = Math.sqrt(s.vel.x * s.vel.x + s.vel.y * s.vel.y);
			if (sp > 1e-9) {
				// 不越过 0：反推不会把探测器推成"倒着走"（那读起来像 bug，而且不物理）
				const dv = sp > brakeDvPerStep ? brakeDvPerStep : sp;
				s = {
					pos: s.pos,
					vel: { x: s.vel.x - (s.vel.x / sp) * dv, y: s.vel.y - (s.vel.y / sp) * dv },
				};
			}
		}

		// 推进之后的位置（碰撞检测用），并把它留给下一步当"当前"位置 —— 一次计算两处用
		const tmp = curPositions;
		curPositions = nextPositions;
		nextPositions = tmp;
		fillPositions(bodies, t, curPositions);

		const hit = collisionFrom(bodies, curPositions, s.pos);
		if (hit >= 0) {
			outcome = 'crashed';
			hitIndex = hit;
			points.push({ x: s.pos.x, y: s.pos.y });
			velocities.push({ x: s.vel.x, y: s.vel.y });
			break;
		}

		if (escape2 > 0 && s.pos.x * s.pos.x + s.pos.y * s.pos.y > escape2) {
			outcome = 'escaped';
			points.push({ x: s.pos.x, y: s.pos.y });
			velocities.push({ x: s.vel.x, y: s.vel.y });
			break;
		}

		if (i % sampleEvery === 0) {
			points.push({ x: s.pos.x, y: s.pos.y });
			velocities.push({ x: s.vel.x, y: s.vel.y });
		}
	}

	return { outcome, points, velocities, state: s, hitIndex, stepsRun };
}

/**
 * 圆轨道速度：在距中心 `radius` 处、中心引力强度为 `gm` 时的环绕速度。
 * 用于关卡设计与测试（验证圆轨道不会向外飞或向内掉）。
 */
export function orbitalSpeed(gm: number, radius: number): number {
	if (radius <= 0) return 0;
	return Math.sqrt(gm / radius);
}

/**
 * 应用全局倍率，生成新的行星数组（不修改入参）。
 *
 * - `gravityScale` 乘到 `gm`（统一调难度）
 * - `orbitScale` 除到 `orbitPeriod`（速度倍率；period 越小越快）
 *
 * 放在这里而不是各调用方，是为了让“倍率语义”只有一处实现。
 */
export function applyScales(bodies: Body[], gravityScale: number, orbitScale: number): Body[] {
	const out: Body[] = [];
	for (const b of bodies) {
		out.push({
			gm: b.gm * gravityScale,
			radius: b.radius,
			orbitCenter: { x: b.orbitCenter.x, y: b.orbitCenter.y },
			orbitRadius: b.orbitRadius,
			orbitPeriod: b.orbitPeriod === 0 || orbitScale <= 0 ? b.orbitPeriod : b.orbitPeriod / orbitScale,
			phase0: b.phase0,
			orbitDirection: b.orbitDirection,
		});
	}
	return out;
}

/** 街机模式星尘收集结果。 */
export interface StarCollectResult {
	collected: boolean[];
	count: number;
}

/**
 * 评估轨迹收集到的星尘。
 * 纯函数，预测线计算与实时飞行判定共用。
 */
export function evaluateCollectedStars(
	points: P2[],
	stars: P2[],
	collectRadius = 30
): StarCollectResult {
	const collected: boolean[] = [];
	for (let i = 0; i < stars.length; i++) {
		collected.push(false);
	}
	let count = 0;
	const r2 = collectRadius * collectRadius;
	for (const p of points) {
		for (let i = 0; i < stars.length; i++) {
			if (!collected[i]) {
				const dx = p.x - stars[i].x;
				const dy = p.y - stars[i].y;
				if (dx * dx + dy * dy <= r2) {
					collected[i] = true;
					count++;
				}
			}
		}
	}
	return { collected, count };
}
