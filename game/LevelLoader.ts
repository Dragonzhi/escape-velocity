/**
 * 数据驱动关卡加载器。
 *
 * 策划改两份 JSON 即可改关，不必动 TypeScript：
 * - `Assets/Levels/bodies.json`：天体原型（gm、半径、模型、颜色）
 * - `Assets/Levels/levels.json`：中心天体、公转体、星尘、探测器待命轨道
 *
 * 公转周期不手填。中心引力 μ 已知时 T = 2π·√(r³/μ)；
 * gm = 0 的障碍（陨石）没有引力可推周期，用 spin 角速度，缺省 0.6 rad/s。
 * 星尘同样绕中心天体走，拾取判定才能和预测线用同一个时刻。
 *
 * 本模块纯函数、不 import Dora，单测可以直接喂 JSON 文本。
 */
import { Body, P2 } from 'game/Gravity';
import type { LevelDef, PlanetVisualDef } from 'game/LevelData';
import type { TransferTutorial } from 'game/Transfer';

/** gm = 0 的公转体没写 spin 时用的角速度（rad/s）。内圈陨石必须转，否则「抓住空隙」不存在。 */
const DEFAULT_SPIN = 0.6;

export interface BodyProtoJson {
	emissive?: [number, number, number];
	name: string;
	gm: number;
	radius: number;
	model: string;
	color: [number, number, number];
	/** 有环的天体（土星）。省略 = 无环。 */
	ring?: boolean;
}

export interface BodiesConfigJson {
	version?: string;
	bodies: { [key: string]: BodyProtoJson };
}

export interface ProbeJson {
	/** 绕中心天体的待命轨道半径。 */
	orbitRadius: number;
	/** t = 0 时探测器在轨道上的角度（度）。 */
	startAngleDeg: number;
	minSpeed: number;
	maxSpeed: number;
	dvBudget: number;
}

export interface OrbiterJson {
	offset?: P2;
	/** bodies.json 里的原型键。 */
	body: string;
	orbitRadius: number;
	/** t = 0 的初始角度（度）。 */
	angleDeg: number;
	/** +1 逆时针，-1 顺时针。省略 = +1。 */
	direction?: 1 | -1;
	/**
	 * 只有中心天体 gm 推不出周期时才需要（陨石 gm = 0）。
	 * 单位 rad/s。省略 = DEFAULT_SPIN。
	 */
	spin?: number;
	/** `'target'` = 引导光点相对定位的天体。一关只认第一颗。 */
	type?: 'target';
	/** 光点提示范围（平面单位）。只在 type = target 时有效，省略 = 65。 */
	tolerance?: number;
}

export interface StarJson {
	orbitRadius: number;
	angleDeg: number;
	/** 省略 = 与中心天体同向（+1），角速度由中心 gm 按开普勒求出。 */
	direction?: 1 | -1;
}

export interface LevelJson {
	bodyOverrides?: { [key: string]: { gm?: number; radius?: number } };
	marker?: { orbitRadius: number; angleDeg: number; tolerance: number };
	transfer?: TransferTutorial;
	id: number;
	title: string;
	subtitle?: string;
	brief: string;
	/** bodies.json 里的原型键。中心天体静止在原点。 */
	centerBody: string;
	probe: ProbeJson;
	orbiters: OrbiterJson[];
	stars?: StarJson[];
	environment?: {
		escapeRadius?: number;
		maxSteps?: number;
	};
}

export interface LevelsConfigJson {
	version?: string;
	levels: LevelJson[];
}

export interface OrbitLayout {
	levels: LevelDef[];
	/** 与 levels 一一对应：星尘的轨道参数（运行时按 t 求位置）。 */
	starOrbits: Body[][];
}

function deg(d: number): number {
	return (d * Math.PI) / 180;
}

/** 开普勒周期。μ ≤ 0 或 r ≤ 0 时没有轨道，返回 0（静止）。 */
export function keplerPeriod(radius: number, mu: number): number {
	if (radius <= 0 || mu <= 0) return 0;
	return 2 * Math.PI * Math.sqrt((radius * radius * radius) / mu);
}

/** 圆轨速度 √(μ/r)。 */
export function circularSpeed(mu: number, radius: number): number {
	if (radius <= 0 || mu <= 0) return 0;
	return Math.sqrt(mu / radius);
}

/**
 * 圆轨上的切向速度。direction +1 = 逆时针，速度 = ω × r 的切向。
 * phaseRad 是此刻的位置角，不是初始角。
 */
export function tangentialVelocity(mu: number, radius: number, phaseRad: number, direction: 1 | -1): P2 {
	const speed = circularSpeed(mu, radius);
	const tx = -Math.sin(phaseRad);
	const ty = Math.cos(phaseRad);
	return { x: direction * tx * speed, y: direction * ty * speed };
}

function protoOf(table: BodiesConfigJson, key: string, json: LevelJson): BodyProtoJson | undefined {
	if (table.bodies === undefined) return undefined;
	const base = table.bodies[key];
	if (base === undefined) return undefined;
	const override = json.bodyOverrides !== undefined ? json.bodyOverrides[key] : undefined;
	if (override === undefined) return base;
	return { ...base, gm: override.gm !== undefined ? override.gm : base.gm, radius: override.radius !== undefined ? override.radius : base.radius };
}

function visualOf(proto: BodyProtoJson): PlanetVisualDef {
	return {
		emissive: proto.emissive !== undefined ? { r: proto.emissive[0], g: proto.emissive[1], b: proto.emissive[2] } : undefined,
		r: proto.color[0],
		g: proto.color[1],
		b: proto.color[2],
		displayRadius: proto.radius,
		ring: proto.ring === true,
		model: proto.model,
	};
}

/**
 * 一颗绕中心天体的圆轨道。
 * mu > 0 时周期由开普勒求出；否则用 spin（rad/s）反推周期，让陨石也能转。
 */
function orbitBody(
	proto: BodyProtoJson,
	orbitRadius: number,
	angleDeg: number,
	direction: 1 | -1,
	mu: number,
	spin: number | undefined,
): Body {
	let period = 0;
	if (orbitRadius > 0) {
		if (mu > 0) period = keplerPeriod(orbitRadius, mu);
		else {
			const w = spin !== undefined && spin > 0 ? spin : DEFAULT_SPIN;
			period = (2 * Math.PI) / w;
		}
	}
	return {
		gm: proto.gm,
		radius: proto.radius,
		orbitCenter: { x: 0, y: 0 },
		orbitRadius,
		orbitPeriod: period,
		phase0: deg(angleDeg),
		orbitDirection: direction,
		name: proto.name,
	};
}

/** 把一份关卡 JSON 收成运行时 LevelDef。原型缺失时返回 undefined（这一关整关丢弃）。 */
export function convertLevelJson(json: LevelJson, table: BodiesConfigJson): LevelDef | undefined {
	const center = protoOf(table, json.centerBody, json);
	if (center === undefined) return undefined;

	const planets: Body[] = [];
	const visuals: PlanetVisualDef[] = [];

	planets.push({
		gm: center.gm,
		radius: center.radius,
		orbitCenter: { x: 0, y: 0 },
		orbitRadius: 0,
		orbitPeriod: 0,
		phase0: 0,
		orbitDirection: 1,
		name: center.name,
	});
	visuals.push(visualOf(center));

	let targetIndex = -1;
	let tolerance = 65;
	let goalOffset: P2 | undefined = undefined;
	for (let i = 0; i < json.orbiters.length; i++) {
		const o = json.orbiters[i];
		const proto = protoOf(table, o.body, json);
		if (proto === undefined) return undefined;
		const dir: 1 | -1 = o.direction === -1 ? -1 : 1;
		const body = orbitBody(proto, o.orbitRadius, o.angleDeg, dir, center.gm, o.spin);
		if (proto.gm <= 0) body.isObstacle = true;
		planets.push(body);
		visuals.push(visualOf(proto));
		if (o.type === 'target' && targetIndex < 0) {
			targetIndex = planets.length - 1;
			goalOffset = o.offset;
			if (o.tolerance !== undefined && o.tolerance > 0) tolerance = o.tolerance;
		}
	}
	let marker: Body | undefined = undefined;
	if (json.marker !== undefined && json.transfer !== undefined && json.transfer.orbital !== undefined) {
		marker = orbitBody({ name: '目标光点', gm: 0, radius: 0, model: '', color: [0, 1, 1] }, json.marker.orbitRadius, json.marker.angleDeg, 1, center.gm, undefined);
		targetIndex = 0; tolerance = json.marker.tolerance;
	}
	const orbital = json.transfer !== undefined ? json.transfer.orbital : undefined;
	if (orbital !== undefined) {
		if ((orbital.region === undefined) === (orbital.targetFlyby === undefined)) return undefined;
		for (const e of orbital.encounters) if (e.planetIndex < 1 || e.planetIndex >= planets.length) return undefined;
		const target = orbital.targetFlyby;
		if (target !== undefined && (target.planetIndex < 1 || target.planetIndex >= planets.length)) return undefined;
	}
	if (targetIndex < 0) return undefined;

	const stars: P2[] = [];
	if (json.stars !== undefined) {
		for (let s = 0; s < json.stars.length; s++) {
			const st = json.stars[s];
			const dir: 1 | -1 = st.direction === -1 ? -1 : 1;
			const phase = deg(st.angleDeg);
			stars.push({
				x: st.orbitRadius * Math.cos(dir * phase),
				y: st.orbitRadius * Math.sin(dir * phase),
			});
		}
	}

	const probePhase = deg(json.probe.startAngleDeg);
	const probeStart = {
		x: json.probe.orbitRadius * Math.cos(probePhase),
		y: json.probe.orbitRadius * Math.sin(probePhase),
	};
	const probeVel0 = tangentialVelocity(center.gm, json.probe.orbitRadius, probePhase, 1);

	const escapeRadius = json.environment !== undefined && json.environment.escapeRadius !== undefined
		? json.environment.escapeRadius : 1400;
	const maxSteps = json.environment !== undefined && json.environment.maxSteps !== undefined
		? json.environment.maxSteps : 1000;

	return {
		transfer: json.transfer,
		id: json.id,
		title: json.title,
		probeVariant: json.id >= 3 ? 'rtg' : 'solar',
		brief: json.brief,
		probeStart,
		probeVel0,
		stars,
		planets,
		visuals,
		goal: { kind: 'planet', planetIndex: targetIndex, tolerance, offset: goalOffset, marker },
		dvBudget: json.probe.dvBudget,
		escapeRadius,
		maxSteps,
		mission: {
			id: 'L' + json.id.toFixed(0),
			codeName: 'ArcadeSlingshot' + json.id.toFixed(0),
			historicalRef: '街机引力弹弓',
			subtitle: json.subtitle !== undefined ? json.subtitle : json.title,
			challenges: json.transfer !== undefined ? [{ desc: json.transfer.orbital !== undefined ? (json.transfer.orbital.targetFlyby !== undefined ? '借金星减速，飞掠水星' : '依次借力后进入目标轨道区域') : (json.transfer.flyby !== undefined ? '安全完成月球减速掠过' : '抵达月球旁的目标光点'), type: 'success' }] : [
				{ desc: '穿透星门', type: 'success' },
				{ desc: '收集至少 2 颗星尘', type: 'stars', threshold: 2 },
				{ desc: '收集全部 3 颗星尘', type: 'stars', threshold: 3 },
			],
		},
	};
}

/** 星尘轨道（与 stars 数组顺序一致）。中心 gm 取该关第 0 颗天体。 */
export function starOrbitsOf(json: LevelJson, table: BodiesConfigJson): Body[] {
	const center = protoOf(table, json.centerBody, json);
	const mu = center !== undefined ? center.gm : 0;
	const out: Body[] = [];
	if (json.stars === undefined) return out;
	for (let s = 0; s < json.stars.length; s++) {
		const st = json.stars[s];
		const dir: 1 | -1 = st.direction === -1 ? -1 : 1;
		out.push({
			gm: 0,
			radius: 0,
			orbitCenter: { x: 0, y: 0 },
			orbitRadius: st.orbitRadius,
			orbitPeriod: keplerPeriod(st.orbitRadius, mu),
			phase0: deg(st.angleDeg),
			orbitDirection: dir,
			name: '星尘',
		});
	}
	return out;
}

/**
 * 解析两份 JSON 文本。
 * `decode` 由调用方给：引擎里没有 `JSON.parse`，入口传 Dora 的 `json.decode`。
 * 任一关原型缺失、没有星门、或文本不是 JSON，返回空数组（调用方保留旧关卡）。
 */
export function loadArcadeLevels(
	levelsText: string,
	bodiesText: string,
	decode: (text: string) => unknown,
): OrbitLayout {
	const empty: OrbitLayout = { levels: [], starOrbits: [] };
	try {
		const table = decode(bodiesText) as BodiesConfigJson | undefined;
		const parsed = decode(levelsText) as LevelsConfigJson | undefined;
		if (table === undefined || parsed === undefined) return empty;
		if (table === undefined || table.bodies === undefined) return empty;
		if (parsed === undefined || parsed.levels === undefined || parsed.levels.length === 0) return empty;
		const levels: LevelDef[] = [];
		const starOrbits: Body[][] = [];
		for (let i = 0; i < parsed.levels.length; i++) {
			const lv = convertLevelJson(parsed.levels[i], table);
			if (lv === undefined) return empty;
			levels.push(lv);
			starOrbits.push(starOrbitsOf(parsed.levels[i], table));
		}
		return { levels, starOrbits };
	} catch (e) {
		return empty;
	}
}
