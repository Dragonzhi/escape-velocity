/**
 * 3D 微缩太阳系沙盘选关中心（S7 · 真实深空出征主界面）。
 *
 * 核心架构：
 * 1. 3D 太阳系微缩沙盘：太阳自发光、各大行星公转与自转、3D 轨道环、星空背景；
 * 2. 交互相机机架：支持全景环视（Panorama）与天体特写（Focus）平滑运镜（Smooth Lerp）；
 * 3. 2D 全息任务图钉（Holographic Mission Pins）：动态 3D->2D 投影跟随目标行星，显示火箭星级；
 * 4. 任务简报抽屉卡（Mission Briefing Card）：展示真实深空任务历史原型、载具类型、三枚火箭挑战列表；
 * 5. 底部微缩任务栏（Mission Dock）与顶部总火箭统计（如 14 / 18 ★）；
 * 6. 全关卡去线性化自由探索（无硬通关锁）。
 */
import {
	Camera3D,
	Color,
	Color3,
	Content,
	DirectionalLight3D,
	Label,
	Model3D,
	Node,
	Node3D,
	PointLight3D,
	Size,
	Touch,
	Vec2,
	Vec3,
} from 'Dora';
import { P2 } from 'game/Gravity';
import { LevelDef, getLevel, levelCount } from 'game/LevelData';
import { Progress, getMissionRockets, getTotalRockets } from 'game/Progress';
import {
	applyPlanetTexture,
	createProbe,
	createStarBackdrop,
	modelRadius,
	planeToWorld,
	pointAntenna,
	probeYawForVelocity,
	ProbeHandle,
} from 'game/Scene';
import {
	CameraBasis,
	CameraView,
	FLIP_Y,
	HANDEDNESS,
	prepareCamera,
	projectPrepared,
	toOverlay,
} from 'game/Projection';
import {
	UiButton,
	createButton,
	createLabel,
	createPanel,
	setLabelCenter,
	setLabelColor,
	setLabelText,
} from 'game/Ui';

const DegToRad = Math.PI / 180;

/** 太阳系沙盘中行星的定义。 */
export interface HubPlanetStation {
	model: string;
	radius: number;
	orbit: number;
	baseAngleDeg: number;
	orbitSpeedDegPerSec: number;
	rotSpeedDegPerSec: number;
	colorHex: number;
	emissiveHex: number;
	levelIndex?: number; // 关联的关卡索引（0 基）
}

/** 太阳系沙盘中的天体排布。 */
export const HUB_STATIONS: HubPlanetStation[] = [
	// 水星（无关卡，作点缀）
	{ model: 'Sphere', radius: 0.85, orbit: 7.5, baseAngleDeg: 340, orbitSpeedDegPerSec: 4.2, rotSpeedDegPerSec: 5.0, colorHex: 0x9a8f86, emissiveHex: 0 },
	// 金星 -> L2 水手10号
	{ model: 'Planet_Venus', radius: 1.60, orbit: 11.5, baseAngleDeg: 300, orbitSpeedDegPerSec: 2.8, rotSpeedDegPerSec: -2.0, colorHex: 0xf0dcae, emissiveHex: 0, levelIndex: 1 },
	// 地球 -> L1 阿波罗/嫦娥探月
	{ model: 'Planet_Earth', radius: 2.20, orbit: 17.0, baseAngleDeg: 262, orbitSpeedDegPerSec: 1.8, rotSpeedDegPerSec: 15.0, colorHex: 0x5b9be0, emissiveHex: 0, levelIndex: 0 },
	// 火星（点缀）
	{ model: 'Planet_Mars', radius: 1.50, orbit: 22.5, baseAngleDeg: 318, orbitSpeedDegPerSec: 1.3, rotSpeedDegPerSec: 14.0, colorHex: 0xd07f4a, emissiveHex: 0 },
	// 木星 -> L3 帕克号
	{ model: 'Planet_Jupiter', radius: 4.60, orbit: 30.0, baseAngleDeg: 12, orbitSpeedDegPerSec: 0.8, rotSpeedDegPerSec: 25.0, colorHex: 0xe0c092, emissiveHex: 0, levelIndex: 2 },
	// 土星 -> L4 伽利略号
	{ model: 'Planet_Saturn', radius: 3.20, orbit: 38.5, baseAngleDeg: 68, orbitSpeedDegPerSec: 0.5, rotSpeedDegPerSec: 22.0, colorHex: 0xd3c49a, emissiveHex: 0, levelIndex: 3 },
	// 天王星 -> L5 新视野号
	{ model: 'Planet_Uranus', radius: 2.00, orbit: 47.0, baseAngleDeg: 124, orbitSpeedDegPerSec: 0.35, rotSpeedDegPerSec: 12.0, colorHex: 0xa8dde4, emissiveHex: 0, levelIndex: 4 },
	// 海王星 -> L6 旅行者2号
	{ model: 'Planet_Neptune', radius: 1.90, orbit: 55.0, baseAngleDeg: 180, orbitSpeedDegPerSec: 0.25, rotSpeedDegPerSec: 11.0, colorHex: 0x7b95f0, emissiveHex: 0, levelIndex: 5 },
];

/** 关卡索引 -> HUB_STATIONS 下标的映射。 */
export const LEVEL_TO_STATION_INDEX: number[] = [2, 1, 4, 5, 6, 7];

/** 视觉配置常量。 */
const SunRadius = 4.8;
const OrbitRingsPath = 'Assets/Model/OrbitRings.gltf';
const OrbitRingsHex = 0x3f5f88;

const CardBgHex = 0x0c1626;
const CardBorderHex = 0x2e4869;
const PrimaryBtnBgHex = 0x1d528f;
const PrimaryBtnFgHex = 0xffffff;
const PrimaryBtnBorderHex = 0x5b95de;
const SecondaryBtnBgHex = 0x152233;
const SecondaryBtnFgHex = 0x9fbcdb;
const SecondaryBtnBorderHex = 0x38557a;
const PinBgHex = 0x0d1f35;
const PinBorderHex = 0x4172a6;
const GoldStarHex = 0xffc83b;
const DimStarHex = 0x566c85;

function clampNumber(value: number, lo: number, hi: number): number {
	if (value < lo) return lo;
	if (value > hi) return hi;
	return value;
}

function lerp(a: number, b: number, t: number): number {
	return a + (b - a) * t;
}

function lerp3(a: Vec3.Type, b: Vec3.Type, t: number): Vec3.Type {
	return Vec3(lerp(a.x, b.x, t), lerp(a.y, b.y, t), lerp(a.z, b.z, t));
}

/** 格式化火箭星级字符：如 2 枚火箭显示「★ ★ ☆」 */
export function formatRocketsString(count: number): string {
	const c = Math.max(0, Math.min(3, Math.floor(count)));
	if (c === 0) return '☆  ☆  ☆';
	if (c === 1) return '★  ☆  ☆';
	if (c === 2) return '★  ★  ☆';
	return '★  ★  ★';
}

/** SolarHub 装配选项。 */
export interface SolarHubOptions {
	root: Node3D.Type;
	camera: Camera3D.Type;
	layer: Node.Type;
	viewW: number;
	viewH: number;
	fovYDeg: number;
	aspect: number;
	spherePath?: string;
	onLaunch: (levelIndex: number) => void;
	onReplayIntro?: () => void;
}

/** SolarHub 句柄接口。 */
/** @noSelf **/
export interface SolarHub {
	show(progress: Progress): void;
	hide(): void;
	step(dt: number): void;
	focusMission(levelIndex: number): void;
	backToPanorama(): void;
	launchCurrentMission(): void;
	relayout(viewW: number, viewH: number): void;
	visible(): boolean;
}

/**
 * 创建微缩 3D 太阳系选关中心。
 */
export function createSolarHub(options: SolarHubOptions): SolarHub {
	let viewW = options.viewW;
	let viewH = options.viewH;
	const root = options.root;
	const camera = options.camera;
	const layer = options.layer;

	// 2D 根节点（layer 内部坐标为 [0, viewW] x [0, viewH]，左下为原点）
	const ui = Node();
	ui.size = Size(viewW, viewH);
	ui.anchor = Vec2(0, 0);
	ui.position = Vec2(0, 0);
	layer.addChild(ui);

	// ---- 3D 场景与光照 ----
	const sunLight = PointLight3D();
	sunLight.color = Color3(0xfff3da);
	sunLight.intensity = 20;
	sunLight.range = 700;
	sunLight.position = Vec3(0, 0, 0);
	root.addChild(sunLight);

	const fillLight = DirectionalLight3D();
	fillLight.color = Color3(0xbad2eb);
	fillLight.intensity = 1.6;
	fillLight.angleX = -38;
	fillLight.angleY = 65;
	root.addChild(fillLight);

	const backdrop = createStarBackdrop(root);

	// 太阳球体
	const sun = Model3D('Assets/Model/Sun.glb');
	if (sun !== undefined) {
		sun.scale = Vec3(SunRadius, SunRadius, SunRadius);
		applyPlanetTexture(sun, 'Sun', 0, 0);
		root.addChild(sun);
	}

	// 3D 轨道线网格
	if (Content.exist(OrbitRingsPath)) {
		const rings = Model3D(OrbitRingsPath);
		if (rings !== undefined) {
			const rm = rings.getMaterial(0);
			if (rm !== undefined) {
				rm.baseColor = Color(0, 0, 0, 255);
				rm.emissive = Color3(OrbitRingsHex);
			}
			root.addChild(rings);
		}
	}

	// 8 颗行星模型实例与公转句柄
	interface PlanetHandle {
		station: HubPlanetStation;
		node: Model3D.Type;
		currentAngleDeg: number;
		currentPos: P2;
	}
	const planets: PlanetHandle[] = [];
	const spherePath = options.spherePath !== undefined ? options.spherePath : 'Assets/Model/Sphere.gltf';

	for (let i = 0; i < HUB_STATIONS.length; i++) {
		const st = HUB_STATIONS[i];
		const modelPath = st.model === 'Sphere' ? spherePath : 'Assets/Model/' + st.model + '.glb';
		const model = Model3D(modelPath);
		if (model !== undefined) {
			const scale = st.radius / modelRadius(st.model);
			model.scale = Vec3(scale, scale, scale);
			applyPlanetTexture(model, st.model, st.colorHex, st.emissiveHex);
			root.addChild(model);
			const a = st.baseAngleDeg * DegToRad;
			const pos: P2 = { x: Math.cos(a) * st.orbit, y: Math.sin(a) * st.orbit };
			model.position = planeToWorld(pos, 0);
			planets.push({
				station: st,
				node: model,
				currentAngleDeg: st.baseAngleDeg,
				currentPos: pos,
			});
		}
	}

	// 地球轨道旁点缀的微缩探测器
	let probeHandle: ProbeHandle | undefined = undefined;
	probeHandle = createProbe(root, {
		scale: 0.95,
		probePath: 'Assets/Model/Probe_Voyager_v1.glb',
		bodyPath: 'Assets/Model/Probe_Solar_Body.glb',
		antennaPath: 'Assets/Model/Probe_Solar_Antenna.glb',
		antennaPivotY: 0.6495,
		bodyRadius: 1.084,
		atlasPath: 'Assets/Image/probe_atlas.jpg',
	});

	// ---- 相机姿态状态机 ----
	let camMode: 'panorama' | 'focus' = 'panorama';
	let focusLevelIndex = -1;

	// 全景相机参数
	let panoYawDeg = 24;
	let panoPitchDeg = 36;
	const PanoDist = 230;

	// 当前与目标相机机位
	let curEye = Vec3(0, 130, 190);
	let curTarget = Vec3(0, 0, 0);
	let targetEye = Vec3(0, 130, 190);
	let targetTarget = Vec3(0, 0, 0);

	/** 计算全景模式下的相机机位。 */
	const calcPanoEye = (): Vec3.Type => {
		const pitchRad = panoPitchDeg * DegToRad;
		const yawRad = panoYawDeg * DegToRad;
		const rHorizontal = PanoDist * Math.cos(pitchRad);
		const y = PanoDist * Math.sin(pitchRad);
		const x = rHorizontal * Math.sin(yawRad);
		const z = rHorizontal * Math.cos(yawRad);
		return Vec3(x, y, z);
	};

	/** 计算特写模式下的相机机位。 */
	const calcFocusPose = (stIndex: number): { eye: Vec3.Type; target: Vec3.Type } => {
		const h = planets[stIndex];
		if (h === undefined) return { eye: calcPanoEye(), target: Vec3(0, 0, 0) };
		const p = h.currentPos;
		const t = planeToWorld(p, 0);
		const planetRadius = h.station.radius;
		const dist = Math.max(14, planetRadius * 4.2);
		const offsetAngle = (h.currentAngleDeg + 45) * DegToRad;
		const eyeX = t.x + Math.cos(offsetAngle) * dist * 0.85;
		const eyeY = t.y + dist * 0.55;
		const eyeZ = t.z + Math.sin(offsetAngle) * dist * 0.85;
		return { eye: Vec3(eyeX, eyeY, eyeZ), target: t };
	};

	// ---- 全屏手势触摸层（空白拖动旋转全景）----
	const gestureLayer = Node();
	gestureLayer.size = Size(viewW, viewH);
	gestureLayer.anchor = Vec2(0, 0);
	gestureLayer.position = Vec2(0, 0);
	gestureLayer.touchEnabled = false;
	ui.addChild(gestureLayer);

	let isDragging = false;
	let lastTouchPos = Vec2(0, 0);

	gestureLayer.onTapBegan((touch: Touch.Type): boolean => {
		isDragging = true;
		lastTouchPos = touch.location;
		return true;
	});

	gestureLayer.onTapMoved((touch: Touch.Type): void => {
		if (!isDragging) return;
		const loc = touch.location;
		const dx = loc.x - lastTouchPos.x;
		const dy = loc.y - lastTouchPos.y;
		lastTouchPos = loc;

		if (camMode === 'panorama') {
			panoYawDeg -= dx * 0.22;
			panoPitchDeg = clampNumber(panoPitchDeg + dy * 0.16, 16, 75);
			targetEye = calcPanoEye();
		}
	});

	gestureLayer.onTapEnded((): void => {
		isDragging = false;
	});

	// ---- 2D 全息任务图钉 (Holographic Pins) ----
	interface MissionPin {
		levelIndex: number;
		stIndex: number;
		root: Node.Type;
		nameLabel?: Label.Type;
		rocketLabel?: Label.Type;
		btn: UiButton;
	}
	const pins: MissionPin[] = [];

	const PinW = 138;
	const PinH = 50;

	for (let i = 0; i < LEVEL_TO_STATION_INDEX.length; i++) {
		const lvIndex = i;
		const stIndex = LEVEL_TO_STATION_INDEX[lvIndex];
		const def = getLevel(lvIndex);
		const title = def !== undefined ? def.title : '';

		const pinRoot = Node();
		pinRoot.size = Size(PinW, PinH);
		pinRoot.anchor = Vec2(0, 0);
		ui.addChild(pinRoot);

		const btn = createButton(pinRoot, {
			w: PinW,
			h: PinH,
			text: '',
			fontSize: 18,
			bgHex: PinBgHex,
			fgHex: 0xffffff,
			borderHex: PinBorderHex,
			fireOn: 'press',
			onTap: (): void => {
				focusMission(lvIndex);
			},
		});
		btn.root.position = Vec2(0, 0);

		const nameLabel = createLabel(btn.root, 'L' + (lvIndex + 1).toFixed(0) + ' · ' + title, 18, 0xeaf4ff);
		setLabelCenter(nameLabel, PinW / 2, PinH - 16);

		const rocketLabel = createLabel(btn.root, '☆  ☆  ☆', 15, GoldStarHex);
		setLabelCenter(rocketLabel, PinW / 2, 14);

		pins.push({
			levelIndex: lvIndex,
			stIndex,
			root: pinRoot,
			nameLabel,
			rocketLabel,
			btn,
		});
	}

	// ---- 顶部信息栏（Top Bar）----
	const topBar = Node();
	topBar.size = Size(viewW, 90);
	topBar.anchor = Vec2(0, 0);
	topBar.position = Vec2(0, viewH - 90);
	ui.addChild(topBar);

	const titleLabel = createLabel(topBar, '深空航迹 · 太阳系沙盘', 32, 0xffffff);
	setLabelCenter(titleLabel, viewW / 2, 60);

	const totalRocketsLabel = createLabel(topBar, '全深空火箭勋章: 0 / 18 ★', 22, 0x9ec5eb);
	setLabelCenter(totalRocketsLabel, viewW / 2, 24);

	let replayIntroBtn: UiButton | undefined = undefined;
	if (options.onReplayIntro !== undefined) {
		replayIntroBtn = createButton(topBar, {
			w: 130,
			h: 44,
			text: '重看开场',
			fontSize: 20,
			bgHex: SecondaryBtnBgHex,
			fgHex: SecondaryBtnFgHex,
			borderHex: SecondaryBtnBorderHex,
			fireOn: 'press',
			onTap: (): void => {
				if (options.onReplayIntro !== undefined) options.onReplayIntro();
			},
		});
		replayIntroBtn.root.position = Vec2(viewW - 146, 22);
	}

	// ---- 底部微缩任务栏 (Bottom Dock) ----
	const dockNode = Node();
	dockNode.size = Size(viewW, 64);
	dockNode.anchor = Vec2(0, 0);
	dockNode.position = Vec2(0, 76);
	ui.addChild(dockNode);

	const dockButtons: UiButton[] = [];
	const dockBtnW = clampNumber((viewW * 0.94 - 10 * 5) / 6, 76, 110);
	const dockBtnH = 50;
	const dockTotalW = dockBtnW * 6 + 10 * 5;
	const dockStartX = (viewW - dockTotalW) / 2;

	for (let i = 0; i < LEVEL_TO_STATION_INDEX.length; i++) {
		const lvIndex = i;
		const btn = createButton(dockNode, {
			w: dockBtnW,
			h: dockBtnH,
			text: 'L' + (lvIndex + 1).toFixed(0),
			fontSize: 20,
			bgHex: PinBgHex,
			fgHex: 0xd6e8fa,
			borderHex: PinBorderHex,
			fireOn: 'press',
			onTap: (): void => {
				focusMission(lvIndex);
			},
		});
		btn.root.position = Vec2(dockStartX + lvIndex * (dockBtnW + 10), 0);
		dockButtons.push(btn);
	}

	// ---- 任务简报抽屉卡 (Mission Briefing Card) ----
	const cardW = clampNumber(viewW * 0.92, 340, 540);
	const cardH = clampNumber(viewH * 0.44, 380, 500);

	const briefCard = createPanel(ui, cardW, cardH, CardBgHex, {
		alpha: 0.96,
		borderHex: CardBorderHex,
		borderWidth: 2,
	});
	briefCard.anchor = Vec2(0, 0);
	briefCard.position = Vec2((viewW - cardW) / 2, 40);
	briefCard.visible = false;

	const bTitleLabel = createLabel(briefCard, '', 28, 0xffffff);
	setLabelCenter(bTitleLabel, cardW / 2, cardH - 34);

	const bSubtitleLabel = createLabel(briefCard, '', 20, 0x8ab4dc);
	setLabelCenter(bSubtitleLabel, cardW / 2, cardH - 66);

	const bVehicleLabel = createLabel(briefCard, '', 18, 0xffd479);
	setLabelCenter(bVehicleLabel, cardW / 2, cardH - 96);

	// 三条挑战条件
	const challengeLabels: Label.Type[] = [];
	for (let k = 0; k < 3; k++) {
		const cl = createLabel(briefCard, '', 19, 0xd0e2f5);
		if (cl !== undefined) {
			cl.textWidth = cardW - 48;
			setLabelCenter(cl, cardW / 2, cardH - 138 - k * 44);
			challengeLabels.push(cl);
		}
	}

	// 按钮组
	const btnRowY = 22;
	const backBtnW = 120;
	const launchBtnW = cardW - backBtnW - 40;
	const btnH = 64;

	const backBtn = createButton(briefCard, {
		w: backBtnW,
		h: btnH,
		text: '❮ 返回',
		fontSize: 22,
		bgHex: SecondaryBtnBgHex,
		fgHex: SecondaryBtnFgHex,
		borderHex: SecondaryBtnBorderHex,
		fireOn: 'press',
		onTap: (): void => {
			backToPanorama();
		},
	});
	backBtn.root.position = Vec2(16, btnRowY);

	const launchBtn = createButton(briefCard, {
		w: launchBtnW,
		h: btnH,
		text: '启动任务 / LAUNCH ★',
		fontSize: 24,
		bgHex: PrimaryBtnBgHex,
		fgHex: PrimaryBtnFgHex,
		borderHex: PrimaryBtnBorderHex,
		fireOn: 'press',
		onTap: (): void => {
			if (focusLevelIndex >= 0) {
				print('[escape-velocity] launch mission: L' + (focusLevelIndex + 1).toFixed(0));
				options.onLaunch(focusLevelIndex);
			}
		},
	});
	launchBtn.root.position = Vec2(backBtnW + 28, btnRowY);

	backBtn.setEnabled(false);
	launchBtn.setEnabled(false);

	// ---- 刷新简报卡内容 ----
	const updateBriefCard = (levelIndex: number, progress: Progress): void => {
		const lv = getLevel(levelIndex);
		if (lv === undefined) return;
		const m = lv.mission;
		if (m === undefined) return;

		setLabelText(bTitleLabel, 'L' + (levelIndex + 1).toFixed(0) + ' · ' + lv.title + ' · ' + m.subtitle);
		setLabelText(bSubtitleLabel, m.historicalRef + ' (' + m.codeName + ')');

		const vehText = m.vehicle === 'orbiter'
			? '【 轨道器型 · 具备变轨制动引擎 】'
			: '【 飞掠型探测器 · 深空高速引力借力 】';
		setLabelText(bVehicleLabel, vehText);
		setLabelColor(bVehicleLabel, m.vehicle === 'orbiter' ? 0xffd479 : 0x7fe3a0);

		const rocketsGot = getMissionRockets(progress, levelIndex);
		for (let k = 0; k < 3; k++) {
			const c = m.challenges[k];
			const achieved = rocketsGot >= k + 1;
			const icon = achieved ? '★' : '☆';
			const prefix = k === 0 ? '一星' : (k === 1 ? '二星' : '三星');
			const text = icon + ' [' + prefix + '] ' + c.desc;
			setLabelText(challengeLabels[k], text);
			setLabelColor(challengeLabels[k], achieved ? GoldStarHex : 0x9cb8d9);
		}
	};

	/** 聚焦某关特写。 */
	const focusMission = (levelIndex: number): void => {
		camMode = 'focus';
		focusLevelIndex = levelIndex;
		const stIndex = LEVEL_TO_STATION_INDEX[levelIndex];
		const pose = calcFocusPose(stIndex);
		targetEye = pose.eye;
		targetTarget = pose.target;

		// 隐藏全息图钉与底部 Dock
		for (let i = 0; i < pins.length; i++) {
			pins[i].root.visible = false;
			pins[i].btn.setEnabled(false);
		}
		dockNode.visible = false;
		for (let i = 0; i < dockButtons.length; i++) dockButtons[i].setEnabled(false);

		// 展开任务简报卡片
		briefCard.visible = true;
		backBtn.setEnabled(true);
		launchBtn.setEnabled(true);

		// 读取当前最新进度
		const curProg = currentProgress;
		if (curProg !== undefined) updateBriefCard(levelIndex, curProg);
	};

	/** 返回全景模式。 */
	const backToPanorama = (): void => {
		camMode = 'panorama';
		focusLevelIndex = -1;
		targetEye = calcPanoEye();
		targetTarget = Vec3(0, 0, 0);

		// 显示全息图钉与底部 Dock
		for (let i = 0; i < pins.length; i++) {
			pins[i].root.visible = true;
			pins[i].btn.setEnabled(true);
		}
		dockNode.visible = true;
		for (let i = 0; i < dockButtons.length; i++) dockButtons[i].setEnabled(true);

		// 收起任务简报卡片
		briefCard.visible = false;
		backBtn.setEnabled(false);
		launchBtn.setEnabled(false);
	};

	let isVisible = false;
	let currentProgress: Progress | undefined = undefined;

	/** 刷新所有火箭指示与统计标签。 */
	const refreshRocketsDisplay = (prog: Progress): void => {
		currentProgress = prog;
		const total = getTotalRockets(prog, levelCount());
		setLabelText(totalRocketsLabel, '全深空火箭勋章: ' + total.toFixed(0) + ' / 18 ★');

		for (let i = 0; i < pins.length; i++) {
			const p = pins[i];
			const count = getMissionRockets(prog, p.levelIndex);
			setLabelText(p.rocketLabel, formatRocketsString(count));
			setLabelColor(p.rocketLabel, count > 0 ? GoldStarHex : DimStarHex);

			// 同步刷新底部 Dock 按钮文字
			dockButtons[i].setText('L' + (p.levelIndex + 1).toFixed(0) + ' ' + (count > 0 ? count.toFixed(0) + '★' : ''));
		}
	};

	/** 执行一帧更新与投影。 */
	const doStep = (dt: number): void => {
		// 1) 推进天体公转与自转
		for (let i = 0; i < planets.length; i++) {
			const h = planets[i];
			h.currentAngleDeg += h.station.orbitSpeedDegPerSec * dt;
			const rad = h.currentAngleDeg * DegToRad;
			h.currentPos = {
				x: Math.cos(rad) * h.station.orbit,
				y: Math.sin(rad) * h.station.orbit,
			};
			h.node.position = planeToWorld(h.currentPos, 0);
			h.node.angleY += h.station.rotSpeedDegPerSec * dt;
		}

		// 地球绕行探测器位置更新
		if (probeHandle !== undefined && planets[2] !== undefined) {
			const earthPos = planets[2].currentPos;
			const probeAngle = planets[2].node.angleY * 2.5 * DegToRad;
			const probeP: P2 = {
				x: earthPos.x + Math.cos(probeAngle) * 4.2,
				y: earthPos.y + Math.sin(probeAngle) * 4.2,
			};
			probeHandle.node.position = planeToWorld(probeP, 0);
			const vel: P2 = {
				x: -Math.sin(probeAngle),
				y: Math.cos(probeAngle),
			};
			const yaw = probeYawForVelocity(vel);
			if (yaw !== undefined) probeHandle.node.angleY = yaw;
			if (probeHandle.antenna !== undefined) {
				pointAntenna(probeHandle.antenna, probeP, earthPos, probeHandle.node.angleY);
			}
		}

		// 2) 全景悠闲自旋
		if (camMode === 'panorama' && !isDragging) {
			panoYawDeg += 0.035;
			targetEye = calcPanoEye();
		} else if (camMode === 'focus') {
			// 特写镜头随天体公转紧紧跟随机位
			const pose = calcFocusPose(LEVEL_TO_STATION_INDEX[focusLevelIndex]);
			targetEye = pose.eye;
			targetTarget = pose.target;
		}

		// 3) 相机机位平滑逼近 (Camera Lerp)
		curEye = dt > 0 ? lerp3(curEye, targetEye, 0.08) : targetEye;
		curTarget = dt > 0 ? lerp3(curTarget, targetTarget, 0.08) : targetTarget;
		camera.lookAt(curEye, curTarget, Vec3(0, 1, 0));
		if (backdrop !== undefined) backdrop.sync(curEye, curTarget);

		// 4) 2D 全息图钉投影更新
		if (camMode === 'panorama') {
			const camView: CameraView = {
				eye: { x: curEye.x, y: curEye.y, z: curEye.z },
				target: { x: curTarget.x, y: curTarget.y, z: curTarget.z },
				up: { x: 0, y: 1, z: 0 },
				fovYDeg: options.fovYDeg,
				aspect: options.aspect,
				viewW,
				viewH,
			};
			const basis: CameraBasis = prepareCamera(camView, HANDEDNESS, FLIP_Y);

			for (let i = 0; i < pins.length; i++) {
				const p = pins[i];
				const planetHandle = planets[p.stIndex];
				if (planetHandle === undefined) continue;

				const worldPos = planeToWorld(planetHandle.currentPos, 0);
				const proj = projectPrepared({ x: worldPos.x, y: worldPos.y, z: worldPos.z }, basis);

				if (proj !== undefined && proj.vz > 1.0) {
					p.root.visible = true;
					const over = toOverlay(proj);
					// 转换为左下原点系统的屏幕坐标
					const screenX = viewW / 2 + over.x;
					const screenY = viewH / 2 + over.y;
					// 交错高低差：内圈地球/月球(stIndex=2)稍高，金星(stIndex=1)居中偏低，其它外圈标准
					const yOffset = p.stIndex === 2 ? 40 : (p.stIndex === 1 ? 16 : 24);
					p.root.position = Vec2(screenX - PinW / 2, screenY + yOffset);
				} else {
					p.root.visible = false;
				}
			}
		}
	};

	const hub: SolarHub = {
		show: (prog: Progress): void => {
			isVisible = true;
			root.visible = true;
			ui.visible = true;
			gestureLayer.touchEnabled = true;

			refreshRocketsDisplay(prog);
			backToPanorama();

			curEye = calcPanoEye();
			curTarget = Vec3(0, 0, 0);
			targetEye = curEye;
			targetTarget = curTarget;
			camera.lookAt(curEye, curTarget, Vec3(0, 1, 0));

			// 主动执行一次初始投影与摆位
			doStep(0);
		},

		hide: (): void => {
			isVisible = false;
			root.visible = false;
			ui.visible = false;
			gestureLayer.touchEnabled = false;

			for (let i = 0; i < pins.length; i++) pins[i].btn.setEnabled(false);
			for (let i = 0; i < dockButtons.length; i++) dockButtons[i].setEnabled(false);
			if (replayIntroBtn !== undefined) replayIntroBtn.setEnabled(false);
			backBtn.setEnabled(false);
			launchBtn.setEnabled(false);
		},

		step: (dt: number): void => {
			if (!isVisible) return;
			doStep(dt);
		},

		focusMission: (levelIndex: number): void => {
			focusMission(levelIndex);
		},

		backToPanorama: (): void => {
			backToPanorama();
		},

		launchCurrentMission: (): void => {
			if (focusLevelIndex >= 0) {
				print('[escape-velocity] launch mission via api: L' + (focusLevelIndex + 1).toFixed(0));
				options.onLaunch(focusLevelIndex);
			}
		},

		relayout: (w: number, h: number): void => {
			viewW = w;
			viewH = h;
			ui.size = Size(viewW, viewH);
			ui.position = Vec2(0, 0);
			gestureLayer.size = Size(viewW, viewH);
			topBar.size = Size(viewW, 90);
			topBar.position = Vec2(0, viewH - 90);
			setLabelCenter(titleLabel, viewW / 2, 60);
			setLabelCenter(totalRocketsLabel, viewW / 2, 24);
			if (replayIntroBtn !== undefined) {
				replayIntroBtn.root.position = Vec2(viewW - 146, 22);
			}
			dockNode.position = Vec2(0, 76);
			briefCard.position = Vec2((viewW - cardW) / 2, 40);
		},

		visible: (): boolean => isVisible,
	};
	currentHubInstance = hub;
	return hub;
}

let currentHubInstance: SolarHub | undefined = undefined;

/** 获取当前处于活动状态的 SolarHub 单例。 */
export function getActiveSolarHub(): SolarHub | undefined {
	return currentHubInstance;
}
