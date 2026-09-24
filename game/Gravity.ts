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
}

export interface SimResult {
	outcome: Outcome;
	/** 采样点（含起点与终点），用于绘制轨迹。 */
	points: P2[];
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
	let angle = b.phase0;
	if (b.orbitPeriod !== 0) {
		angle += b.orbitDirection * (2 * Math.PI) * (t / b.orbitPeriod);
	}
	return {
		x: b.orbitCenter.x + b.orbitRadius * Math.cos(angle),
		y: b.orbitCenter.y + b.orbitRadius * Math.sin(angle),
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
	let outcome: Outcome = 'running';
	let hitIndex = -1;
	let stepsRun = 0;
	let t = 0;

	const escape2 = opts.escapeRadius > 0 ? opts.escapeRadius * opts.escapeRadius : 0;

	for (let i = 0; i < opts.steps; i++) {
		s = step(s, bodies, t, opts.dt);
		t += opts.dt;
		stepsRun += 1;

		const hit = collisionIndex(bodies, s.pos, t);
		if (hit >= 0) {
			outcome = 'crashed';
			hitIndex = hit;
			points.push({ x: s.pos.x, y: s.pos.y });
			break;
		}

		if (escape2 > 0 && s.pos.x * s.pos.x + s.pos.y * s.pos.y > escape2) {
			outcome = 'escaped';
			points.push({ x: s.pos.x, y: s.pos.y });
			break;
		}

		if (i % sampleEvery === 0) {
			points.push({ x: s.pos.x, y: s.pos.y });
		}
	}

	return { outcome, points, state: s, hitIndex, stepsRun };
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
