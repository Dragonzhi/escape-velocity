/**
 * 关卡数据（S2.1 建立；S3.6.1 六章重排；S3.7 宏大尺度；**S5 物理归正 = 真实太阳系尺度**）。
 *
 * ===== S5 归正（用户 2026-09-27 拍板）=====
 *
 * 原话：「完全重构一下，把物理系统归正回来。尽量直接照着现实太阳系的尺度进行缩放。」
 *      「天体大小也一并都改一下，改为符合物理的大小。」
 *      「轨道半径可以也改成真实 AU 比，因为飞行过程有 4X 速了，完全可以真正拉开距离，靠倍速来压缩时间。」
 *      「视觉半径和实际影响物理的部分分开来，且要有一个配置文件方便的进行修改。」
 *      「一切以真实物理为准。」
 *
 * 于是本文件里**没有任何手填的半径 / gm / 周期 / 轨道半径**：
 *
 * - 一切都由 `game/Scale.ts` 从真实天文数据（AU、km、km³/s²）换算而来；
 * - 「想调就调」的视觉半径 / 每关步长 / 播放倍速在 `game/Tuning.ts`；
 * - 周期一律 `T = 2π·sqrt(a³/μ)`（**删掉了旧的 KeplerK = r^1.5**，它和 SunGm 差 42.7 倍，
 *   是「行星走假运动、探测器飞真引力」这个总病根）。
 *
 * ==== 归正带来的四个必须知道的结构变化 ====
 *
 * 1. **轨道变成真实 AU 比**：金星 57.9 / 地球 80.0 / 木星 416.2 / 土星 762.9 / 天王星 1535.1 /
 *    海王星 2405.6（旧的压缩值是 55/80/105/135/165/195）。飞行时间因此从十几秒变成 7 / 46 / 101 / 269 / 513 秒，
 *    靠每关自己的播放倍速（Tuning.LEVEL_RUNTIME）压回观感。
 * 2. **天体变成真尺寸**：地球半径 0.0034、木星 0.0374、太阳 0.372 —— 在 3D 里基本都是点。
 *    用户已确认这没问题：「天体在 3D 里面变成点是正常的，只需要在 2D 视角里面让玩家知道在哪里就可以了」。
 *    看得见的那一层在 Tuning.BODY_VISUAL_RADIUS，**不参与任何物理判定**。
 * 3. **六关一律「共轨出发」**：探测器出发时已经在一条日心**圆轨道**上（初速 = 该点圆轨速度），
 *    玩家拖出来的那一下是**点火 Δv**，叠在它上面。旧版 L2–L6 从静止出发 ⇒ 2.6 秒内自由落体撞日。
 * 4. **L2–L6 没有「家园地球」**：旧版把地球当 gm = 0 的布景放在出发点旁边，靠"15 个单位外"回避碰撞。
 *    真实周期下做不到 —— 日期轴跨度至少要覆盖会合周期（金星 26.8s / 海王星 16.9s），
 *    而地球周期只有 16.76 秒 ⇒ **窗口里地球必然扫过整圈**，与固定的出发点 (0, 80) 至少重合一次，
 *    那一天一进关探测器就生成在地球内部；就算躲开，地球的真引力（用户要求必须有）也会把探测器拽偏。
 *    所以六站里**只有 L1 有地球** —— 那一关它是宿主，是「真天体」最合适的位置。
 *    出发轨道仍写进简报与 2D 视图（1 AU 圈），叙事不变。
 *
 * ==== 关卡设计口径 ====
 *
 * 1. **一站一个目的地**（L1 月球 / L2 金星 / L3 木星 / L4 土星 / L5 天王星 / L6 海王星）；
 *    难度 = 距离 + 允许的误差 + 要串几个节点。
 * 2. **日期是一根真旋钮**：六关都带 timeWindow，跨度 ≥ 该目标的会合周期，
 *    于是"同一条航线，换个日期就通/不通"成立。
 * 3. **预测线 = 真实轨迹**：两边都是 `game/Gravity.ts` 的同一个 `simulate`。
 * 4. **相位不许手填**：`orbiter()` 的相位参数由 `node tools/level-phases.mjs <关号>` 解出。
 *    S3.11 的教训：相位曾经是"照一条设计航线排的"，而那条航线撞进太阳 ⇒ 成功率 0.2%，玩家骂「关卡诡异」。
 *
 * 本模块**纯数据 + 纯函数**，不 import 'Dora'，可单测。
 */
import { Body, P2, bodyPositionAt, distance } from 'game/Gravity';
import { GravityScale, OrbitSpeedScale } from 'game/Config';
import {
	EarthGm, EarthRadius, KmPerUnit, MoonOrbitRadius, MoonRadius, REAL, SunGm, SunRadius,
	circularSpeed, period, trueGm, trueOrbit, trueRadius,
} from 'game/Scale';
import { visualRadius } from 'game/Tuning';

/** 行星视觉描述（与 Scene.PlanetVisual 结构兼容，避免跨模块依赖）。 */
export interface PlanetVisualDef {
	r: number;
	g: number;
	b: number;
	/**
	 * **视觉半径**（世界单位）—— 只影响 3D 模型缩放与 2D 图钉，**不参与碰撞 / 到达 / 捕获判定**。
	 *
	 * ⚠️ S5 之前这里有一条硬约束「必须等于 Body.radius」（"玩家靠肉眼判断会不会撞上"）。
	 * 真实尺度下它必须作废：木星物理半径 0.0374，在 416 单位的轨道上是亚像素。
	 * 替代判据 = **2D 到达圈画真实容差**（Test/PlanViewTest 守着）。
	 * 取值一律来自 game/Tuning.ts 的 BODY_VISUAL_RADIUS。
	 */
	displayRadius: number;
	ring: boolean;
	/**
	 * 模型名（不含路径与扩展名，如 'Planet_Mars'），S3.1 已入库的 .glb 之一。
	 * 留空表示回退到代码生成的 Sphere.gltf（单位球）。**只影响视觉，不参与物理**。
	 */
	model?: string;
	/** 自发光（0–1，可选）。太阳必须给：否则它在画面里就是一颗土黄色石球，不像光源。 */
	emissive?: { r: number; g: number; b: number };
}

/** 顺序航线的一个航点（S3.7）。 */
export interface WaypointSpec {
	planetIndex: number;
	/** 掠过容差（平面单位）。 */
	tolerance: number;
	/** 航点名（HUD/简报用，例如 '木星'）。 */
	label?: string;
	/**
	 * 要求**捕获入轨**（S3.9.2，用户："后半段减速的时候，就可以尝试进入某个行星的轨道"）：
	 * 除了进环，还要求**相对行星**的速度 ≤ captureFactor × 该处圆轨道速度。
	 * 中间航点不设（掠过即可）；终点站才设 —— 通常配合「刹车」剖面使用。
	 */
	capture?: boolean;
	/** 捕获的速度上限系数（默认 √2 = 该处**逃逸速度**，即"真的被这颗行星束缚住"）。 */
	captureFactor?: number;
}

/** 目标规格。 */
export interface GoalSpec {
	/** 'planet' = 进入目标容差（掠过/到达）；'escape' = 飞出边界。 */
	kind: 'planet' | 'escape';
	/** 目标行星索引（单目标时有效）。 */
	planetIndex: number;
	/** 到达容差（平面单位）。 */
	tolerance: number;
	/**
	 * 顺序航线（S3.7）：按数组顺序**依次**掠过这些天体才算完成。
	 * 给了 chain 就以它为准（planetIndex/tolerance 只作兼容/工具用）。
	 */
	chain?: WaypointSpec[];
}

/** 单个火箭挑战定义（S7）。 */
export interface RocketChallengeDef {
	/** 挑战目标描述 */
	desc: string;
	/** 判定类型：'success' | 'fuel' | 'distance' | 'speed' | 'eccentricity' */
	type: 'success' | 'fuel' | 'distance' | 'speed' | 'eccentricity';
	/** 判定阈值 */
	threshold?: number;
}

/** 任务元数据（S7：真实深空探测任务）。 */
export interface MissionMeta {
	/** 任务代号：'L1' ~ 'L6' */
	id: string;
	/** 英文代号：'Moon', 'Mariner10', 'Parker', 'Galileo', 'NewHorizons', 'Voyager2' */
	codeName: string;
	/** 历史原型：'阿波罗 / 嫦娥探月', etc. */
	historicalRef: string;
	/** 中文副标题：'启蒙', '潜行', '烈日', '泊入', '狂飙', '奇迹' */
	subtitle: string;
	/** 载具类型：'flyby' | 'orbiter' */
	vehicle: 'flyby' | 'orbiter';
	/** 三枚火箭挑战列表 [第1枚, 第2枚, 第3枚] */
	challenges: [RocketChallengeDef, RocketChallengeDef, RocketChallengeDef];
}

/** 一关的完整定义。 */
export interface LevelDef {
	id: number;
	/** 选关按钮上的名字（= 编年章节名）。 */
	title: string;
	/** 关间"航行日志"体简报：我在哪 / 下一站 / 为什么。 */
	brief: string;
	probeStart: P2;
	/**
	 * 出发时探测器**已经有的速度**（S3.9.3）。
	 *
	 * ⚠️ S5 起**必填**：六关都从一条日心**圆轨道**出发，值是"该点的圆轨速度"。
	 * 旧版 L2–L6 省略它 = 从静止出发 ⇒ 在 r=80 处 2.6 秒内自由落体撞进太阳（已实测）。
	 * 单测（Test/LevelDataTest）守着这条：初速必须等于该点圆轨速度。
	 */
	probeVel0: P2;
	/**
	 * 探测器版本（S3.14 建模交付的两台机体）：
	 * 近处任务（月球 / 金星 / 木星）用**太阳能板版**，木星以外（土星 / 天王星 / 海王星）用 **RTG 核电池版**。
	 * 省略 = 太阳能板版。
	 */
	probeVariant?: 'solar' | 'rtg';
	planets: Body[];
	visuals: PlanetVisualDef[];
	goal: GoalSpec;
	/**
	 * Δv 预算（S3.9.2b，用户要求）：满力对应的速度就是它 —— "力大砖飞要被挡住"。
	 * 有效上限 = `min(Tuning.LEVEL_RUNTIME.aimMax, dvBudget)`；刹车模式下两次点火共享这个数。
	 */
	dvBudget: number;
	/** 越界半径（距原点 = 距太阳）。 */
	escapeRadius: number;
	/** 飞行推演的最大步数（超过就判"没到"）。必须 ≥ 飞行时间 / 该关 physicsStep。 */
	maxSteps: number;
	/** 时间轴（S3.6.4)：「发射日期」的取值范围（秒）。跨度 ≥ 会合周期 ⇒ 保证至少一个可行日期。 */
	timeWindow?: { span: number };
	/**
	 * 2D 规划视图以哪颗天体为中心（S5）。
	 *
	 * 省略 = 以太阳为中心（L2–L6：从 1 AU 看整条航线，太阳就在中间）。
	 * L1 必须填 1（地球）：那一关整个世界只有 0.6 单位宽，以太阳为中心的话
	 * 探测器与月球只是屏幕中心的一个点（0.2/80 = 0.25% 视野）—— 而用户明确说过
	 * 「2D 视角负责让玩家知道东西在哪里」，看不见就等于没有。
	 */
	planCenter?: number;
	/** 任务专属元数据（S7）。 */
	mission?: MissionMeta;
}

/** 任务评价结果详情（S7）。 */
export interface MissionEvaluation {
	rockets: number;
	achieved: [boolean, boolean, boolean];
	burnDv: number;
	stats: {
		closestDist?: number;
		maxSpeed?: number;
		eccentricity?: number;
	};
}

/**
 * 评价一局飞行的火箭星级及逐条达成详情（纯函数）。
 */
export function evaluateRocketsDetailed(
	level: LevelDef,
	result: string,
	burnDv: number,
	extra?: {
		closestDist?: number;
		maxSpeed?: number;
		eccentricity?: number;
	},
): MissionEvaluation {
	const achieved: [boolean, boolean, boolean] = [false, false, false];
	if (result !== 'success') {
		return {
			rockets: 0,
			achieved,
			burnDv,
			stats: extra !== undefined ? extra : {},
		};
	}

	achieved[0] = true;
	let count = 1;
	const challenges = level.mission !== undefined ? level.mission.challenges : undefined;
	if (challenges !== undefined) {
		// 第 2 枚火箭：燃料控制
		const c2 = challenges[1];
		if (c2.type === 'fuel' && c2.threshold !== undefined) {
			if (burnDv <= level.dvBudget * c2.threshold) {
				achieved[1] = true;
				count += 1;
			}
		} else if (burnDv <= level.dvBudget * 0.8) {
			achieved[1] = true;
			count += 1;
		}

		// 第 3 枚火箭：专属挑战
		const c3 = challenges[2];
		if (c3.type === 'distance' && c3.threshold !== undefined) {
			if (extra !== undefined && extra.closestDist !== undefined && extra.closestDist <= c3.threshold) {
				achieved[2] = true;
				count += 1;
			}
		} else if (c3.type === 'speed' && c3.threshold !== undefined) {
			if (extra !== undefined && extra.maxSpeed !== undefined && extra.maxSpeed >= c3.threshold) {
				achieved[2] = true;
				count += 1;
			}
		} else if (c3.type === 'eccentricity' && c3.threshold !== undefined) {
			if (extra !== undefined && extra.eccentricity !== undefined && extra.eccentricity <= c3.threshold) {
				achieved[2] = true;
				count += 1;
			}
		} else if (count === 2 && burnDv <= level.dvBudget * 0.5) {
			achieved[2] = true;
			count += 1;
		}
	}

	return {
		rockets: Math.min(3, Math.max(0, count)),
		achieved,
		burnDv,
		stats: extra !== undefined ? extra : {},
	};
}

/**
 * 评价一局飞行的火箭星级（0 ~ 3 枚火箭，纯函数）。
 */
export function evaluateRockets(
	level: LevelDef,
	result: string,
	burnDv: number,
	extra?: {
		closestDist?: number;
		maxSpeed?: number;
		eccentricity?: number;
	},
): number {
	return evaluateRocketsDetailed(level, result, burnDv, extra).rockets;
}

// ---------------------------------------------------------------------------
// 纯函数（与渲染、引擎无关；预测线与真实轨迹共用）
// ---------------------------------------------------------------------------

/**
 * 行星自身在时刻 t 的速度（圆轨道 = 位置的导数）。
 * 捕获判据要的是"**相对**行星的速度" —— 行星自己也在跑。
 */
/** 导出名与旧版一致（外部调用方按这个名字找）。 */
export function bodyVelocityAt(b: Body, t: number): P2 {
	if (b.orbitPeriod === 0 || b.orbitRadius <= 0) return { x: 0, y: 0 };
	const angle = b.phase0 + b.orbitDirection * (2 * Math.PI) * (t / b.orbitPeriod);
	const w = (b.orbitDirection * 2 * Math.PI) / b.orbitPeriod;
	return { x: -Math.sin(angle) * b.orbitRadius * w, y: Math.cos(angle) * b.orbitRadius * w };
}

/** 航点列表（链式目标取 chain，否则就是唯一目标）。 */
export function goalWaypoints(goal: GoalSpec): WaypointSpec[] {
	if (goal.chain !== undefined) return goal.chain;
	if (goal.kind === 'planet') return [{ planetIndex: goal.planetIndex, tolerance: goal.tolerance }];
	return [];
}

/**
 * 采样点 i 处、相对某天体的速度（捕获判据与诊断共用同一份实现）。
 *
 * points 里只有位置 ⇒ 用相邻采样点差分；`dt` 是**相邻采样点之间的有效步长**。
 * `limit` 是最后一个有效采样点索引（末端夹紧用）。
 */
export function relativeSpeedAt(points: P2[], i: number, body: Body, dt: number, t0: number, limit: number, velocities?: P2[]): number {
	let vx = 0;
	let vy = 0;
	if (velocities !== undefined && velocities[i] !== undefined) {
		// 首选：模拟给出的**精确**速度（S3.9.2 加进 SimResult）
		vx = velocities[i].x;
		vy = velocities[i].y;
	} else {
		// 退路：位置差分。⚠️ 撞毁时推演在那一帧截断，最后一点只跨半步 ⇒ 速度会被低估
		// （实测把"撞进行星"判成"入轨"）。所以**调用方应尽量传 velocities**。
		const j1 = i + 1 <= limit ? i + 1 : i;
		const j0 = i > 0 ? i - 1 : i;
		const spanT = (j1 - j0) * dt;
		if (spanT > 0) {
			vx = (points[j1].x - points[j0].x) / spanT;
			vy = (points[j1].y - points[j0].y) / spanT;
		}
	}
	const pv = bodyVelocityAt(body, t0);
	const rx = vx - pv.x;
	const ry = vy - pv.y;
	return Math.sqrt(rx * rx + ry * ry);
}

/** 捕获阈值：该处逃逸速度（圆轨道速度 × 系数 k，k 默认 √2）。 */
export function captureThreshold(body: Body, d: number, k: number): number {
	if (body.gm <= 0 || d <= 1e-6) return 1e9;
	return k * Math.sqrt(body.gm / d);
}

/**
 * 顺序航线的进度：返回在 points[0..upto] 里**依次**掠过的航点数与最后一个命中索引。
 *
 * 一次线性扫描：航点必须按顺序命中，且后一个必须出现在更晚的采样点上
 * （"先到土星再路过木星"不算数）。upto 用于飞行中查询"到哪一段了"（画环的明暗）。
 */
export function waypointProgress(
	points: P2[],
	bodies: Body[],
	goal: GoalSpec,
	dt: number,
	t0?: number,
	upto?: number,
	velocities?: P2[],
): { passed: number; lastIndex: number } {
	const wps = goalWaypoints(goal);
	const start = t0 !== undefined ? t0 : 0;
	let limit = points.length - 1;
	if (upto !== undefined && upto >= 0 && upto < limit) limit = upto;
	let next = 0;
	let lastIndex = -1;
	for (let i = 0; i <= limit && next < wps.length; i++) {
		const w = wps[next];
		const body = bodies[w.planetIndex];
		if (body === undefined) return { passed: 0, lastIndex: -1 };
		const gp = bodyPositionAt(body, start + i * dt);
		if (distance(points[i], gp) < w.tolerance) {
			// 捕获（S3.9.2）：进环还不够，还得"慢到能被抓住"。太快 ⇒ 不算，继续扫后面的采样点。
			if (w.capture === true) {
				// 默认 √2：相对速度低于**逃逸速度**（= 圆轨道速度 × √2）⇒ 真的被这颗行星束缚住。
				const k = w.captureFactor !== undefined ? w.captureFactor : 1.4142135623730951;
				const d = distance(points[i], gp);
				// ⚠️ 撞上去不叫入轨：simulate 撞毁时会在那一帧截断，最后一个采样点的"差分速度"
				// 会明显偏小（残段），于是"一头撞进行星"反而被判成捕获（实测踩到：rel=34.7 而阈值=43.1）。
				if (d <= body.radius) continue;
				const rel = relativeSpeedAt(points, i, body, dt, start + i * dt, limit, velocities);
				if (rel > captureThreshold(body, d, k)) continue;
			}
			next += 1;
			lastIndex = i;
		}
	}
	return { passed: next, lastIndex: lastIndex };
}

/** 到达目标的采样点索引；没到返回 -1。 */
export function findGoalIndex(points: P2[], bodies: Body[], goal: GoalSpec, dt: number, t0?: number, velocities?: P2[]): number {
	const wps = goalWaypoints(goal);
	if (wps.length === 0) return -1;
	const st = waypointProgress(points, bodies, goal, dt, t0, undefined, velocities);
	return st.passed >= wps.length ? st.lastIndex : -1;
}

// ---------------------------------------------------------------------------
// 天体构造器 —— 半径 / gm / 轨道 / 周期**全部由 Scale 从真实数据算出**
// ---------------------------------------------------------------------------

/** 度 → 弧度（关卡数据里写角度比写弧度好读）。 */
function deg(d: number): number {
	return (d * Math.PI) / 180;
}

/** 太阳（每关的第 0 号天体）。 */
function sun(): Body {
	return { gm: SunGm, radius: SunRadius, orbitCenter: { x: 0, y: 0 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 };
}

/**
 * 绕太阳公转的行星：`key` 是 Scale.REAL 里的键。
 *
 * 真半径 0.0034（地球）到 0.0374（木星），**不再有任何放大** —— 用户要求"天体大小改为符合物理的大小"。
 * 看得见的那一层在 Tuning.BODY_VISUAL_RADIUS。
 */
function orbiter(key: string, phaseDeg: number): Body {
	const real = REAL[key];
	const a = trueOrbit(real.au);
	return {
		gm: trueGm(real.gm),
		radius: trueRadius(real.radiusKm),
		orbitCenter: { x: 0, y: 0 },
		orbitRadius: a,
		orbitPeriod: period(a, SunGm),
		phase0: deg(phaseDeg),
		orbitDirection: 1, // 全太阳系一致：顺行（从北极看逆时针）
	};
}

/**
 * 绕**会动的宿主**公转的卫星（L1 的月球）。
 *
 * 周期用开普勒第三定律 `2π·sqrt(a³/μ)` 算，**μ 取宿主（地球）的 gm** ——
 * 这是最容易搞错的一步：拿月球自己的 gm 去算会得到 11.35 秒（正确值 1.2593 秒）。
 */
function satellite(key: string, host: Body, orbitRadius: number, phaseDeg: number): Body {
	const real = REAL[key];
	return {
		gm: trueGm(real.gm),
		radius: trueRadius(real.radiusKm),
		orbitCenter: { x: 0, y: 0 },
		orbitRadius,
		orbitPeriod: period(orbitRadius, host.gm),
		phase0: deg(phaseDeg),
		orbitDirection: 1,
		host,
	};
}

/** 视觉：`key` 只用来查 Tuning 里的视觉半径，`body.radius` 是查不到时的兜底。 */
/**
 * 视觉描述。`levelIndex` 决定用哪张视觉半径表：0 = L1 用地月系专用表（见 Tuning）。
 */
function planetVisual(key: string, body: Body, r: number, g: number, b: number, model: string, ring: boolean, levelIndex?: number): PlanetVisualDef {
	return { r, g, b, displayRadius: visualRadius(key, body.radius, levelIndex), ring, model };
}

/** 太阳的视觉（自发光 + 光晕）。 */
function sunVisual(levelIndex?: number): PlanetVisualDef {
	// ⚠️ S3.12：太阳自己照不到自己（光在它内部、表面法线朝外）⇒ 必须靠 emissive 把自己点亮。
	return { r: 1.0, g: 0.97, b: 0.88, displayRadius: visualRadius('sun', SunRadius, levelIndex), ring: false, model: 'Sun', emissive: { r: 1.0, g: 0.95, b: 0.82 } };
}

// ---------------------------------------------------------------------------
// 六站数据
// ---------------------------------------------------------------------------

/**
 * 出发轨道半径 = 1 AU（地球轨道）。六关共用 —— L1 的地球就在这里，L2–L6 从这里出发。
 */
export const EarthOrbitRadius = trueOrbit(REAL.earth.au);

/** 该点的日心圆轨速度（30.00 平面单位/秒 —— 全套尺度的速度锚点）。 */
export const EarthOrbitSpeed = circularSpeed(SunGm, EarthOrbitRadius);

/**
 * 相位表 —— **全部由 `node tools/level-phases.mjs <关号> --dirs 240 --dvs 31 --tmax N` 解出**，不许手填。
 *
 * ⚠️ 同一颗行星在**不同关的相位不同**，这是对的：相位代表"哪一天的太阳系"，
 *    每一关的可行发射窗口本来就不一样。物理量（gm / 半径 / 轨道 / 周期）才是六关共用、不许变的。
 *
 * 每一行后面的注释就是它的出处（工具输出），改数值必须重跑工具。
 */
const PH = {
	mercury: 45.0,
	// node tools/level-phases.mjs 2 --dirs 240 --dvs 31 --tmax 40
	venus: 79.6,
	// node tools/level-phases.mjs 3 --dirs 180 --dvs 21  → 186.1°
	// node tools/level-phases.mjs 4 --dirs 240 --dvs 31 --tmax 200 → 184.4°
	// node tools/level-phases.mjs 5 --dirs 240 --dvs 31 --tmax 450 → 175.6°
	// node tools/level-phases.mjs 6 --dirs 240 --dvs 31 --tmax 800 → 175.2°
	jupiter3: 186.1,
	jupiter4: 184.4,
	jupiter5: 175.6,
	jupiter6: 175.2,
	// L4 199.6° / L5 190.8° / L6 190.3°
	saturn4: 199.6,
	saturn5: 190.8,
	saturn6: 190.3,
	// L5 202.8° / L6 201.8°
	uranus5: 202.8,
	uranus6: 201.8,
	// L6 207.6°
	neptune6: 207.6,
	/**
	 * L1 的月球（绕地球的卫星）相位 = **202°**（B 剖面重解，2026-09-28）。
	 *
	 * 旧值 154.7° 是给「0.1 单位停泊轨 + 0.4034 游戏秒转移」算的；换成真实阿波罗剖面后
	 * 停泊轨降到 6,571 km（3.514e-3 单位）、转移到月球要 **4.978 天**，月球在这期间走 **65°**，
	 * 所以相位必须重解 —— 旧值下实测 **0/235 个候选能命中**（死关）。
	 *
	 * 解法：Node 侧用仓库同一份 `Gravity.simulate` + **游戏自己的 `findGoalIndex`** 扫
	 * 「方向 × 力度 × 相位」，取粗网格（12 方向 × 4 档，与 Test/LevelDataTest 同一张网格）
	 * 解数最多的那个相位。202° 下：粗网格 **4/48**、细网格（36×6）**6.0%**，
	 * 命中样本的近月点 3,500–5,300 km（= 2–3 个月球半径，真实擦过）。
	 */
	moon: 202,
};

/**
 * L1：地月系。
 *
 * - 地球是**真天体**：真 gm、真半径，自己在绕日公转（这是"物理统一"的试纸）；
 * - 月球绕地球，周期由开普勒第三定律算出 = 1.2593 秒（真实值）；
 * - 探测器在**真实的阿波罗停泊轨**上：200 km 高度（地心 6,571 km = **3.514e-3 单位**），
 *   停泊周期 **88.4 分钟**、圆轨速度 7.788 km/s；初始速度 = 地球的公转速度 + 绕地圆轨速度（顺行）；
 * - 点火目标：TLI —— 抬到月球轨道 0.2056，需要 **3.133 km/s（≈ 阿波罗实测 3.05–3.15）**，
 *   转移到月球 **4.978 天**（一圈 : 转移 = 1 : 81，这一关的时间跨度就是它）。
 *
 * 数值出处与实测见 [`docs/L1重构设计案.md`](../docs/L1重构设计案.md) 第二节。
 */
function level1(): LevelDef {
	const earthOrbit = EarthOrbitRadius;
	const earth: Body = {
		gm: EarthGm,
		radius: EarthRadius,
		orbitCenter: { x: 0, y: 0 },
		orbitRadius: earthOrbit,
		orbitPeriod: period(earthOrbit, SunGm),
		phase0: deg(90),
		orbitDirection: 1,
	};
	const moon = satellite('moon', earth, MoonOrbitRadius, PH.moon);
	// 停泊轨 = **真实阿波罗剖面**：200 km 高度 ⇒ 地心 6,571 km = 3.514e-3 单位。
	// 半径由 Scale 的真半径 + 高度推出（**不手填**，与"Body.radius 只能由 Scale 算"同一条纪律）。
	const parking = (REAL.earth.radiusKm + 200) / KmPerUnit;
	// 地球在 90°：位置 (0, R)、速度 (-30, 0)。探测器在地球**外侧** parking（径向 +y），
	// 顺行绕地的切向就是 -x ⇒ 相对速度 (-v_c, 0)。
	const earthPos = bodyPositionAt(earth, 0);
	const earthVel = bodyVelocityAt(earth, 0);
	const vCirc = circularSpeed(EarthGm, parking);
	return {
		id: 1,
		title: '月球',
		probeVariant: 'solar',
		brief: '月球任务 · 近地停泊轨 200 km：你正在绕地球飞，月球在 38 万 km 外。点火把它推向月球 —— 这一程要飞 5 天，别对着月球现在的位置点火。',
		probeStart: { x: earthPos.x, y: earthPos.y + parking },
		probeVel0: { x: earthVel.x - vCirc, y: earthVel.y },
		planets: [sun(), earth, moon],
		// ⚠️ 第三参 0 = 用地月系专用视觉半径表（地球 0.06 / 月球 0.02 / 太阳 0.8）。
		//    别关传 undefined 用日心系表 —— L1 的世界只有 0.6 单位宽，
		//    日心系的 0.025 在这里只占 4%，3D 里就是看不见（用户实测）。
		visuals: [
			sunVisual(0),
			planetVisual('earth', earth, 0.42, 0.62, 0.85, 'Planet_Earth', false, 0),
			planetVisual('moon', moon, 0.56, 0.56, 0.60, 'Moon', false, 0),
		],
		// 到达容差 0.02 = 月球物理半径的 21 倍，也是 2D 到达圈的半径（唯一判据）。
		goal: { kind: 'planet', planetIndex: 2, tolerance: 0.02 },
		// Δv 预算 4.6 单位（≈ 4.57 km/s）：TLI 需要 3.1556，实测可行解落在 3.56–4.6 之间（B0 扫掠）。
		dvBudget: 4.6,
		// ⚠️ escapeRadius 量的是**到太阳（原点）的距离**，不是"离地球多远"。
		// 探测器出发时就在 (0, 80.1) ⇒ 写 3 会让它**第一帧就判"已逃逸"**
		// （2026-09-27 实测：0/2880 条弧线可行，全是 outcome=escaped @t=0.001）。
		escapeRadius: 400,
		// 0.1126 游戏秒（= 8000 步 @1.406967e-5，见 Tuning）= 2.46 天。
		// ⚠️ 注意：**可行解不是霍曼转移**（3.1556 要 4.978 天），而是 3.56–4.6 的**快转移 ≈ 0.9 天**
		//    —— B0 扫掠实测命中都在 0.85–0.94 天（第 694~767 个采样点）。8000 步 = 2.46 天留了 2.6 倍余量。
		maxSteps: 8000,
		planCenter: 1, // 以地球为中心（见 LevelDef.planCenter 的说明）
		mission: {
			id: 'L1',
			codeName: 'Moon',
			historicalRef: '阿波罗 / 嫦娥探月',
			subtitle: '启蒙',
			vehicle: 'flyby',
			challenges: [
				{ desc: '成功抵达月球轨道或飞掠月球', type: 'success' },
				{ desc: '发射点火消耗 Δv ≤ 3.68（预算的 80%）', type: 'fuel', threshold: 0.8 },
				{ desc: '近月点距离 r_peri ≤ 0.003（≈ 5,600 km）', type: 'distance', threshold: 0.003 },
			],
		},
		// ⚠️ L1 **没有时间轴**：日期一变地球就转走，而 probeStart 是个固定点 ⇒
		//    探测器会离开地球。月球自己的相位就是这一关的"时机"。
	};
}

/** L2–L6 共用的出发状态：1 AU 圆轨道上的一点，顺行（-x），速度 = 该点圆轨速度。 */
function departure(): { pos: P2; vel: P2 } {
	return {
		pos: { x: 0, y: EarthOrbitRadius },
		vel: { x: -EarthOrbitSpeed, y: 0 },
	};
}

/** L2 水手10号：地球 ➔ 金星 ➔ 水星（人类首次行星引力借力）。 */
function level2(): LevelDef {
	const venus = orbiter('venus', PH.venus);
	const mercury = orbiter('mercury', PH.mercury);
	const d = departure();
	return {
		id: 2,
		title: '水手10号',
		probeVariant: 'solar',
		brief: '水手10号 · 1 AU 出发：人类首次行星引力辅助。向内俯冲，利用金星前向借力大幅削减轨道动能，深潜入水星轨道！',
		probeStart: d.pos,
		probeVel0: d.vel,
		planets: [sun(), venus, mercury],
		visuals: [
			sunVisual(),
			planetVisual('venus', venus, 0.90, 0.78, 0.55, 'Planet_Venus', false),
			planetVisual('mercury', mercury, 0.65, 0.65, 0.65, 'Sphere', false),
		],
		goal: {
			kind: 'planet',
			planetIndex: 2,
			tolerance: 6,
			chain: [
				{ planetIndex: 1, tolerance: 15, label: '金星' },
				{ planetIndex: 2, tolerance: 6, label: '水星' },
			],
		},
		dvBudget: 4.0,
		escapeRadius: 3600,
		maxSteps: 4000,
		timeWindow: { span: 27 }, // ≥ 金星会合周期 26.8 秒
		mission: {
			id: 'L2',
			codeName: 'Mariner 10',
			historicalRef: '水手10号 (1973)',
			subtitle: '潜行',
			vehicle: 'flyby',
			challenges: [
				{ desc: '借力金星并成功抵达水星', type: 'success' },
				{ desc: '初始点火消耗 Δv ≤ 75% 预算', type: 'fuel', threshold: 0.75 },
				{ desc: '金星交会时相对速度降幅 ≥ 12 单位', type: 'speed', threshold: 12.0 },
			],
		},
	};
}

/** L3 帕克号：地球 ➔ 金星 ➔ 太阳日冕区（触碰太阳极热地狱）。 */
function level3(): LevelDef {
	const venus = orbiter('venus', PH.venus);
	const d = departure();
	return {
		id: 3,
		title: '帕克号',
		probeVariant: 'solar',
		brief: '帕克号 · 1 AU 出发：人类制造的最狂暴“触日者”。利用金星大幅削减日心角动量，近距离俯冲入太阳日冕危险带且未撞毁！',
		probeStart: d.pos,
		probeVel0: d.vel,
		planets: [sun(), venus],
		visuals: [
			sunVisual(),
			planetVisual('venus', venus, 0.90, 0.78, 0.55, 'Planet_Venus', false),
		],
		goal: {
			kind: 'planet',
			planetIndex: 0, // 太阳
			tolerance: 15,  // 日冕危险带半径 R_corona = 15
		},
		dvBudget: 6.0,
		escapeRadius: 3600,
		maxSteps: 6000,
		timeWindow: { span: 27 },
		mission: {
			id: 'L3',
			codeName: 'Parker',
			historicalRef: '帕克太阳探测器 (2018)',
			subtitle: '烈日',
			vehicle: 'flyby',
			challenges: [
				{ desc: '近日点深入太阳日冕观测带 (r_peri ≤ 15) 且未撞毁', type: 'success' },
				{ desc: '初始点火消耗 Δv ≤ 80% 预算', type: 'fuel', threshold: 0.8 },
				{ desc: '近日点最高日心速度突破 vmax ≥ 60 单位', type: 'speed', threshold: 60.0 },
			],
		},
	};
}

/** L4 伽利略号：地球 ➔ 木星泊入（轨道器模式正式登场）。 */
function level4(): LevelDef {
	const jupiter = orbiter('jupiter', PH.jupiter4);
	const d = departure();
	return {
		id: 4,
		title: '伽利略号',
		probeVariant: 'rtg',
		brief: '伽利略号 · 1 AU 出发：人类第一艘长期驻留环绕木星的轨道器。抵达木星巨型引力井，在慢动作特写中捕捉制动窗口，按下 [ BRAKE ] 优雅泊入闭合环绕轨！',
		probeStart: d.pos,
		probeVel0: d.vel,
		planets: [sun(), jupiter],
		visuals: [
			sunVisual(),
			planetVisual('jupiter', jupiter, 0.85, 0.72, 0.50, 'Planet_Jupiter', false),
		],
		goal: {
			kind: 'planet',
			planetIndex: 1, // 木星
			tolerance: 40,
			chain: [
				{ planetIndex: 1, tolerance: 40, label: '木星', capture: true },
			],
		},
		dvBudget: 14.0,
		escapeRadius: 3600,
		maxSteps: 25000,
		timeWindow: { span: 18 },
		mission: {
			id: 'L4',
			codeName: 'Galileo',
			historicalRef: '伽利略号 (1989)',
			subtitle: '泊入',
			vehicle: 'orbiter',
			challenges: [
				{ desc: '在制动窗口内成功按下刹车闭合入轨', type: 'success' },
				{ desc: '地面发射点火 Δv ≤ 70% 预算', type: 'fuel', threshold: 0.7 },
				{ desc: '入轨偏心率 e ≤ 0.25', type: 'eccentricity', threshold: 0.25 },
			],
		},
	};
}

/** L5 新视野号：地球 ➔ 木星狂暴加速 ➔ 柯伊伯带深空。 */
function level5(): LevelDef {
	const jupiter = orbiter('jupiter', PH.jupiter5);
	const d = departure();
	return {
		id: 5,
		title: '新视野号',
		probeVariant: 'rtg',
		brief: '新视野号 · 1 AU 出发：人类有史以来最狂暴的深空信使。寻找木星后向加速最佳切角，利用太阳系最强引力弹弓把探测器甩向柯伊伯带深空外边界！',
		probeStart: d.pos,
		probeVel0: d.vel,
		planets: [sun(), jupiter],
		visuals: [
			sunVisual(),
			planetVisual('jupiter', jupiter, 0.85, 0.72, 0.50, 'Planet_Jupiter', false),
		],
		goal: {
			kind: 'escape',
			planetIndex: 1,
			tolerance: 40,
			chain: [
				{ planetIndex: 1, tolerance: 40, label: '木星' },
			],
		},
		dvBudget: 15.0,
		escapeRadius: 3600,
		maxSteps: 35000,
		timeWindow: { span: 17.5 },
		mission: {
			id: 'L5',
			codeName: 'New Horizons',
			historicalRef: '新视野号 (2006)',
			subtitle: '狂飙',
			vehicle: 'flyby',
			challenges: [
				{ desc: '借力木星获得逃逸能量抵达外边界', type: 'success' },
				{ desc: '地面发射初速消耗 Δv ≤ 75% 预算', type: 'fuel', threshold: 0.75 },
				{ desc: '速度增幅 ≥ 15 且逃逸末速度 vend ≥ 40', type: 'speed', threshold: 40.0 },
			],
		},
	};
}

/** L6 旅行者2号：地球 ➔ 木星 ➔ 土星 ➔ 天王星 ➔ 海王星 ➔ 星际空间。 */
function level6(): LevelDef {
	const jupiter = orbiter('jupiter', PH.jupiter6);
	const saturn = orbiter('saturn', PH.saturn6);
	const uranus = orbiter('uranus', PH.uranus6);
	const neptune = orbiter('neptune', PH.neptune6);
	const d = departure();
	return {
		id: 6,
		title: '旅行者2号',
		probeVariant: 'rtg',
		brief: '旅行者2号 · 1 AU 出发：175 年一遇的行星连珠奇迹！对准发射窗口，连续四星接力借力飞出海王星轨道，冲入星际空间，触发暗淡蓝点终章！',
		probeStart: d.pos,
		probeVel0: d.vel,
		planets: [sun(), jupiter, saturn, uranus, neptune],
		visuals: [
			sunVisual(),
			planetVisual('jupiter', jupiter, 0.85, 0.72, 0.50, 'Planet_Jupiter', false),
			planetVisual('saturn', saturn, 0.75, 0.70, 0.60, 'Planet_Saturn', true),
			planetVisual('uranus', uranus, 0.62, 0.82, 0.86, 'Planet_Uranus', false),
			planetVisual('neptune', neptune, 0.34, 0.50, 0.86, 'Planet_Neptune', false),
		],
		goal: {
			kind: 'planet',
			planetIndex: 4,
			tolerance: 120,
			chain: [
				{ planetIndex: 1, tolerance: 40, label: '木星' },
				{ planetIndex: 2, tolerance: 60, label: '土星' },
				{ planetIndex: 3, tolerance: 90, label: '天王星' },
				{ planetIndex: 4, tolerance: 120, label: '海王星' },
			],
		},
		dvBudget: 16.0,
		escapeRadius: 3600,
		maxSteps: 70000,
		timeWindow: { span: 17.5 },
		mission: {
			id: 'L6',
			codeName: 'Voyager 2',
			historicalRef: '旅行者2号 (1977)',
			subtitle: '奇迹',
			vehicle: 'flyby',
			challenges: [
				{ desc: '成功四星连续借力并飞出海王星轨道', type: 'success' },
				{ desc: '初始发射点火 Δv ≤ 80% 预算', type: 'fuel', threshold: 0.8 },
				{ desc: '四星交会无碰撞且近心点精度 ≤ 5%', type: 'distance', threshold: 0.05 },
			],
		},
	};
}

const LEVELS: LevelDef[] = [level1(), level2(), level3(), level4(), level5(), level6()];

/** 关卡总数。 */
export function levelCount(): number {
	return LEVELS.length;
}

/** 取第 index 关（0 起）。越界返回 undefined。 */
export function getLevel(index: number): LevelDef | undefined {
	return LEVELS[index];
}

/** 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。 */
export function scaledPlanets(level: LevelDef): Body[] {
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale);
}

// 局部引用，避免在模块顶层形成对 Gravity 的额外导出依赖
function applyScalesLocal(bodies: Body[], gravityScale: number, orbitScale: number): Body[] {
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
			// ⚠️ 宿主也要一起缩放（否则卫星绕着一颗"没被缩放"的行星转 —— 位置会错开）
			host: b.host !== undefined ? applyScalesLocal([b.host], gravityScale, orbitScale)[0] : undefined,
		});
	}
	return out;
}
