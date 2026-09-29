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
import { loadArcadeLevels } from 'game/LevelLoader';
import { TransferTutorial } from 'game/Transfer';
import { GravityScale, OrbitSpeedScale } from 'game/Config';
import { SecPerGameSec } from 'game/Scale';

/**
 * **1 真实秒 = 多少游戏秒**。
 * 街机三关的关卡 JSON 用的是屏幕单位，但倍速档位仍读这个换算（pow 0 = 现实 1 秒）。
 * 街机节奏不靠它：每关的 speedDefaultPow 在 Tuning 里另给。
 */
export const GameSecondsPerRealSecond = 1 / SecPerGameSec;

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
	offset?: P2;
	planetIndex: number;
	/** 掠过容差（平面单位）。 */
	tolerance: number;
	/** 航点名（HUD/简报用，例如 '木星'）。 */
	label?: string;
}

/** 目标规格。 */
export interface GoalSpec {
	/** 独立引导点的解析轨道，不加入天体列表。 */
	marker?: Body;
	/** 目标光点相对天体的径向/切向偏移，不参与引力与实体碰撞。 */
	offset?: P2;
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
	/** 以天体实体表面为基准的到达圆环。 */
	region?: { bodyIndex: number; minAltitude: number; maxAltitude: number; direction?: 'outward' | 'inward'; requiresEscape?: boolean };
}

export interface BonusPointSpec { id: string; bodyIndex?: number; orbit?: Body; offset?: P2; position?: P2; tolerance: number; }

/** 单个火箭挑战定义（S7）。 */
export interface RocketChallengeDef {
	/** 挑战目标描述 */
	desc: string;
	/** 判定类型。'stars' = 本局拾取的星尘数 ≥ threshold（街机三星）。 */
	type: 'success' | 'fuel' | 'distance' | 'speed' | 'eccentricity' | 'stars';
	/** 判定阈值 */
	threshold?: number;
	/** 关心的目标天体索引（用于计算 closestDist，默认取 goal.planetIndex） */
	targetPlanetIndex?: number;
}

/** 入场 3D 倒叙长镜头运镜单幕定义（S8.1）。 */
export interface IntroTourSegment {
	/** 该段时长（秒） */
	duration: number;
	/** 关注的目标天体索引（-1 或省略表示探测器） */
	targetPlanetIndex?: number;
	/** 相机水平方位角（度） */
	azDeg?: number;
	/** 相机俯仰角（度） */
	tiltDeg?: number;
	/** 相机距离（世界单位；未填则根据天体/探测器视觉半径自适应） */
	camDist?: number;
	/** 运镜期间展示的仪式感字幕 */
	banner: string;
}

/** 入场 3D 倒叙长镜头运镜配置。 */
export interface IntroTourDef {
	totalDuration: number;
	segments: IntroTourSegment[];
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
	/** 三枚火箭挑战列表 [第1枚, 第2枚, 第3枚] */
	challenges: RocketChallengeDef[];
	/** 入场 3D 倒叙长镜头运镜（S8.1） */
	introTour?: IntroTourDef;
}

/** 一关的完整定义。 */
export interface LevelDef {
	transfer?: TransferTutorial;
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
	/** 街机模式：沿途 3 颗金色星尘的平面位置。 */
	stars?: P2[];
	goal: GoalSpec;
	bonusPoints?: BonusPointSpec[];
	/**
	 * Δv 预算（S3.9.2b，用户要求）：满力对应的速度就是它 —— "力大砖飞要被挡住"。
	 * 有效上限 = `min(Tuning.LEVEL_RUNTIME.aimMax, dvBudget)`，用于出发点火。
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
		/** 本局拾取的星尘数（街机三星）。 */
		starsCollected?: number;
	},
): MissionEvaluation {
	const achieved: [boolean, boolean, boolean] = [false, false, false];
	if (level.transfer !== undefined) {
		achieved[0] = result === 'success';
		return { rockets: achieved[0] ? 1 : 0, achieved, burnDv, stats: extra !== undefined ? extra : {} };
	}
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
		if (c2.type === 'stars' && c2.threshold !== undefined) {
			if (extra !== undefined && extra.starsCollected !== undefined && extra.starsCollected >= c2.threshold) {
				achieved[1] = true;
				count += 1;
			}
		} else if (c2.type === 'fuel' && c2.threshold !== undefined) {
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
		} else if (c3.type === 'stars' && c3.threshold !== undefined) {
			if (extra !== undefined && extra.starsCollected !== undefined && extra.starsCollected >= c3.threshold) {
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
		starsCollected?: number;
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
	if (goal.kind === 'planet') return [{ planetIndex: goal.planetIndex, tolerance: goal.tolerance, offset: goal.offset }];
	return [];
}

/** 空域目标随天体公转：offset.x 径向，offset.y 沿公转切向。 */
export function goalPositionAt(body: Body, t: number, offset?: P2): P2 {
	const p = bodyPositionAt(body, t);
	if (offset === undefined) return p;
	const center = body.host !== undefined ? bodyPositionAt(body.host, t) : body.orbitCenter;
	const dx = p.x - center.x;
	const dy = p.y - center.y;
	const r = Math.sqrt(dx * dx + dy * dy);
	const ux = r > 0 ? dx / r : 1;
	const uy = r > 0 ? dy / r : 0;
	return { x: p.x + ux * offset.x - uy * offset.y * body.orbitDirection,
		y: p.y + uy * offset.x + ux * offset.y * body.orbitDirection };
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
		const gp = goalPositionAt(body, start + i * dt, w.offset);
		if (distance(points[i], gp) < w.tolerance) {
			next += 1;
			lastIndex = i;
		}
	}
	return { passed: next, lastIndex: lastIndex };
}

/** 到达目标的采样点索引；没到返回 -1。 */
export function findGoalIndex(points: P2[], bodies: Body[], goal: GoalSpec, dt: number, t0?: number, velocities?: P2[]): number {
	if (goal.region !== undefined) return findGoalRegionIndex(points, velocities, bodies, goal.region, dt, t0 !== undefined ? t0 : 0);
	if (goal.marker !== undefined) return -1; // 日心任务由顺序会遇与轨道区域判定，光点只有引导作用。
	const wps = goalWaypoints(goal);
	if (wps.length === 0) return -1;
	const st = waypointProgress(points, bodies, goal, dt, t0, undefined, velocities);
	return st.passed >= wps.length ? st.lastIndex : -1;
}

/** 固定步长轨迹首次进入目标高度环；使用线段距离覆盖两采样间的薄环。 */
export function findGoalRegionIndex(points: P2[], velocities: P2[] | undefined, bodies: Body[], region: NonNullable<GoalSpec['region']>, dt: number, t0: number): number {
	const body = bodies[region.bodyIndex];
	if (body === undefined) return -1;
	const inner = body.radius + region.minAltitude;
	const outer = body.radius + region.maxAltitude;
	for (let i = 0; i < points.length; i++) {
		const p = points[i];
		const c = bodyPositionAt(body, t0 + i * dt);
		const dx = p.x - c.x, dy = p.y - c.y;
		const r = Math.sqrt(dx * dx + dy * dy);
		if (r < inner || r > outer) continue;
		if (region.direction === 'outward' && i > 0) {
			const prev = points[i - 1], pc = bodyPositionAt(body, t0 + (i - 1) * dt);
			if (r < Math.sqrt((prev.x - pc.x) * (prev.x - pc.x) + (prev.y - pc.y) * (prev.y - pc.y))) continue;
		}
		if (region.direction === 'inward' && i > 0) {
			const prev = points[i - 1], pc = bodyPositionAt(body, t0 + (i - 1) * dt);
			if (r > Math.sqrt((prev.x - pc.x) * (prev.x - pc.x) + (prev.y - pc.y) * (prev.y - pc.y))) continue;
		}
		if (region.requiresEscape) {
			const v = velocities !== undefined ? velocities[i] : undefined;
			if (v === undefined || body.gm <= 0) continue;
			const bv = bodyVelocityAt(body, t0 + i * dt);
			const vx = v.x - bv.x, vy = v.y - bv.y;
			if ((vx * vx + vy * vy) / 2 - body.gm / Math.max(r, 1e-9) < 0) continue;
		}
		return i;
	}
	return -1;
}


/**
 * 三关由 `Assets/Levels/*.json` 装配（见文件末尾的 `installArcadeLevels`）。
 * 没装上之前是空的：入口会停在 FATAL，而不是悄悄退回旧的静态坐标。
 */
let LEVELS: LevelDef[] = [];
/** 与 LEVELS 一一对应的星尘轨道（按 t 求位置）。 */
let STAR_ORBITS: Body[][] = [];

/** 关卡总数。 */
export function levelCount(): number {
	return LEVELS.length;
}

/** 这一关的星尘轨道。没有（或还没装配）返回空数组。 */
export function starOrbits(index: number): Body[] {
	const row = STAR_ORBITS[index];
	return row !== undefined ? row : [];
}

/**
 * 用两份 JSON 文本替换关卡表。
 * 解析失败或没有任何关时**保持原表不动**，返回 false。
 */
export function installArcadeLevels(levelsText: string, bodiesText: string, decode: (text: string) => unknown): boolean {
	const loaded = loadArcadeLevels(levelsText, bodiesText, decode);
	if (loaded.levels.length === 0) return false;
	LEVELS = loaded.levels;
	STAR_ORBITS = loaded.starOrbits;
	return true;
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
			isObstacle: b.isObstacle,
			name: b.name,
			// ⚠️ 宿主也要一起缩放（否则卫星绕着一颗"没被缩放"的行星转 —— 位置会错开）
			host: b.host !== undefined ? applyScalesLocal([b.host], gravityScale, orbitScale)[0] : undefined,
		});
	}
	return out;
}
