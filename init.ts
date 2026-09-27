// @preview-file on clear
/**
 * 《单程》Escape Velocity · 游戏入口（S2.2 结算面板 / S2.3 关卡选择）。
 *
 * 装配：关卡选择 ⇄ 单关运行时（场景 + 相机 + 轨迹 + 矄准 + 状态机），单一主循环。
 *
 * ===== 为什么每关一套“运行时”，而不是切关时重建 =====
 * - 关卡的 3D 容器用 `Node3D()` 惰性创建，**只切 `visible`**：切关要能在
 *   一帧内完成（不能有 glTF 重建的卡顿），而且不依赖“移除节点”的语义
 *   （手册 §4.3 未定义 destroy API，S2.3 明确不走这条路）。
 * - 每关各有一份相机与 2D 层；切关时 `Director.pushCamera` 指到当前关的相机。
 *
 * ===== 2D 层的层级（踩过就会看不见面板）=====
 * 每关一个 2D 层节点，在**所有关卡**都先建好，UI 叠层（结算面板 / 关卡选择）
 * 最后建 —— Dora 按子节点顺序绘制，后加的画在上面，于是面板永远盖住轨迹线。
 *
 * 阶段流转（手册 §4.3）：
 *   LevelSelect --选关--> Aiming（拖动矄准）→ 松手发射 → Flying → Result
 *   Result --重试本关--> Aiming ；Result --返回关卡选择--> LevelSelect
 */
import { App, Camera3D, Content, Director, Node, Node3D, Path, Size, Vec2, View, threadLoop } from 'Dora';
import { getLevel, goalWaypoints, levelCount, scaledPlanets } from 'game/LevelData';
import { buildScene } from 'game/Scene';
import { createCameraRig, defaultRigOptions } from 'game/CameraRig';
import { TrajectoryView, createTrajectoryView, defaultOptions as trajectoryOptions } from 'game/Trajectory';
import { PlanView, createPlanView, defaultPlanOptions, planFitRadius } from 'game/PlanView';
import { AimInput, AimResult, LevelSelect, ResultPanel, createAimInput, createLevelSelect, createResultPanel } from 'game/Hud';
import { Game, GameLevel, GamePhase, ResultKind, createGame } from 'game/Game';
import { Progress, advanceUnlocked, loadProgress, progressFilePath, saveProgress } from 'game/Progress';
import { Opening, createOpening, loadIntroSeen, saveIntroSeen } from 'game/Opening';

/** 一关的运行时（惰性创建，切关只切 visible）。 */
interface LevelRuntime {
	index: number;
	name: string;
	/** 本关的 3D 根；隐藏它即可让整关（行星 + 探测器）不渲染。 */
	world: Node3D.Type;
	/** 本关的相机；进入本关时 pushCamera。 */
	camera: Camera3D.Type;
	game: Game;
	aim: AimInput;
	/** 本关的轨迹视图（预测线/尾迹的 DrawNode 挂在关卡 2D 层上）。 */
	trajectory: TrajectoryView;
	/** 本关的 2D 规划视图（S3.15）：轨道圈 / 图钉 / 到达圈 / 预测线也在同一个 2D 层上。 */
	plan: PlanView;
	/** 这一关有没有"时间流"（= 关卡数据里有 timeWindow）。 */
	levelHasTimeWindow: boolean;
	/** 时间流量程（秒）；没有时间轴时为 0。 */
	dateSpan: number;
}

/** 关卡槽位：`built` 与 `runtime` 分开，避免出现带空洞的数组（手册 §7.2）。 */
interface LevelSlot {
	built: boolean;
	runtime: LevelRuntime | undefined;
}

const levelTotal = levelCount();

if (levelTotal <= 0) {
	print('[escape-velocity] FATAL: no level data');
} else {
	let viewW = View.size.width;
	let viewH = View.size.height; // 视口变化时会更新（见 relayoutForViewport）

	// 晨昏线（2026-09-25）：环境光从 0.35 压到 0.12——暗面沉下去，方向光的明暗界线才出得来
	Director.entry.setEnvironmentIntensity(0.12, 0.12, 1);

	// ---- 每关一个 2D 层 ----
	// 这几个节点必须先于 UI 叠层创建，否则后建的轨迹线会画在面板上面。
	// size = 视图、anchor 居中、position = 原点 ⇒ 局部原点仍是屏幕中心，
	// 与“直接挂 Director.ui”完全等价（Hud 的触摸层按这个假设换算坐标）。
	const levelLayers: Node.Type[] = [];
	for (let i = 0; i < levelTotal; i++) {
		const layer = Node();
		layer.size = Size(viewW, viewH);
		layer.anchor = Vec2(0.5, 0.5);
		layer.position = Vec2(0, 0);
		Director.ui.addChild(layer);
		levelLayers.push(layer);
	}

	// ---- 开场的 2D 层（S3.3）：轨道虚线圈 + 标题 + 跳过层 ----
	// 位置在关卡层之后、UI 叠层之前 ⇒ 选关/结算面板永远盖住开场文案（与轨迹线同一套层级规矩）。
	const openingLayer = Node();
	openingLayer.size = Size(viewW, viewH);
	openingLayer.anchor = Vec2(0.5, 0.5);
	openingLayer.position = Vec2(0, 0);
	Director.ui.addChild(openingLayer);

	// 开场的 3D 根与相机（懒启动：introSeen 时整块不显示、零开销）
	const openingRoot = Node3D();
	openingRoot.visible = false;
	Director.entry.addChild(openingRoot);
	const openingCamera = Camera3D();

	// ---- UI 叠层（最后加 = 画在最上层）----
	const uiLayer = Node();
	uiLayer.size = Size(viewW, viewH);
	uiLayer.anchor = Vec2(0.5, 0.5);
	uiLayer.position = Vec2(0, 0);
	Director.ui.addChild(uiLayer);

	// ---- 关卡名（`L1 直飞`）：关卡选择与结算面板共用同一份文案 ----
	const levelNames: string[] = [];
	for (let i = 0; i < levelTotal; i++) {
		const def = getLevel(i);
		const title = def !== undefined ? def.title : '';
		levelNames.push('L' + (i + 1).toFixed(0) + ' ' + title);
	}
	const levelEntries: { name: string }[] = [];
	for (let i = 0; i < levelTotal; i++) levelEntries.push({ name: levelNames[i] });

	// ---- 进度（S2.3：解锁制，存 writablePath 下的一个文件）----
	let progress: Progress = loadProgress(levelTotal);
	print('[escape-velocity] progress file: ' + progressFilePath());
	print('[escape-velocity] progress loaded: unlocked=' + progress.unlocked.toFixed(0));

	const slots: LevelSlot[] = [];
	for (let i = 0; i < levelTotal; i++) slots.push({ built: false, runtime: undefined });

	let activeIndex = -1;
	let select: LevelSelect | undefined = undefined;
	let resultPanel: ResultPanel | undefined = undefined;
	// ⚠️ 面板是**全局唯一**的，但结算属于某一关：记住这个 index，
	// 点按只作用在**它自己那一关**的运行时上。
	// 之前用 activeRuntime()：一旦 activeIndex 与面板显示的关卡不一致（切关/自动回归序列），
	// 回调就会作用到另一关（那一关在 Aiming 态）⇒ 点了完全没反应（用户报的"有时没效果"）。
	let resultIndex = -1;

	const activeRuntime = (): LevelRuntime | undefined => {
		if (activeIndex < 0) return undefined;
		return slots[activeIndex].runtime;
	};

	/**
	 * 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	 * 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	 * 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	 */
	const showOnlyLevel = (index: number): void => {
		for (let i = 0; i < levelTotal; i++) {
			const slot = slots[i];
			// 2D 层也要切：轨迹 DrawNode 挂在 levelLayers[i] 上，不切的话
			// 上一关画的预测线/尾迹会一直叠在当前关画面里（2026-09-25 截图实测）
			levelLayers[i].visible = i === index;
			if (slot.runtime === undefined) continue;
			const active = i === index;
			slot.runtime.world.visible = active;
			slot.runtime.aim.setEnabled(active);
			// 切到这一关时把刹车按钮同步成它的当前状态（每关一份 runtime ⇒ 按钮文字会各记一份）
			if (active) slot.runtime.aim.setBrake(slot.runtime.game.brakeMode());
		}
	};

	/**
	 * 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	 *
	 * @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	 */
	const ensureLevel = (index: number): LevelRuntime | undefined => {
		const slot = slots[index];
		if (slot.built && slot.runtime !== undefined) return slot.runtime;

		const def = getLevel(index);
		if (def === undefined) return undefined;

		const bodies = scaledPlanets(def);
		const level: GameLevel = {
			bodies,
			probeStart: def.probeStart,
			// S3.9.3：出发时已有的速度（L1 = 绕地球的圆轨道速度）—— 玩家拖出来的是点火 Δv，落在它上面。
			probeVel0: def.probeVel0,
			goal: def.goal,
			escapeRadius: def.escapeRadius,
			maxSteps: def.maxSteps,
		};

		const world = Node3D();
		Director.entry.addChild(world);
		world.visible = false;

		const rtg = def.probeVariant === 'rtg';
		const scene = buildScene({
			root: world,
			bodies,
			visuals: def.visuals,
			probeStart: level.probeStart,
			// S3.14 建模交付：探测器分成**两版**（太阳能板 / RTG 核电池），见 LevelDef.probeVariant。
			// 每版都是「机体 + 天线」两个文件（引擎拿不到 glTF 子节点 ⇒ 不拆文件就没法转天线）。
			// scale 2.2：新机体的最长轴是 Z ±0.87（旧单体是 3.227）⇒ 屏幕上的尺寸和以前相当。
			probeScale: 2.2,
			spherePath: 'Assets/Model/Sphere.gltf',
			ringPath: 'Assets/Model/Ring.gltf',
			probePath: 'Assets/Model/Probe_Voyager_v1.glb',
			// ⚠️ S3.13：家园地球不再是**纯视觉锚点**，而是每关 planets 里的一个**布景天体**
			// （homeEarth()：沿地球轨道运行、gm = 0、半径 = R_EARTH）⇒ 这里不再传 home。
			// Scene 的 home/homeRadius 因此暂时闲置："大天线回头指向地球"要改成指向那颗布景地球，
			// 等 3D 镜头那一轮再接（见 .agent/plan/PROGRESS.md）。
			// 探测器版本：近处任务（月球 / 金星 / 木星）→ 太阳能板版；木星以外 → RTG 版。
			// 交付文档 §A.3 的两组常数（天线转轴 / 机体外接半径）逐版本不同，别写死。
			probeBodyPath: rtg ? 'Assets/Model/Probe_RTG_Body.glb' : 'Assets/Model/Probe_Solar_Body.glb',
			probeAntennaPath: rtg ? 'Assets/Model/Probe_RTG_Antenna.glb' : 'Assets/Model/Probe_Solar_Antenna.glb',
			probeAntennaPivotY: rtg ? 0.6641 : 0.6495,
			probeBodyRadius: rtg ? 0.871 : 1.084,
			// 两版共用同一张细节图集（UV 已按分区排好，材质色与它相乘）
			probeAtlasPath: 'Assets/Image/probe_atlas.jpg',
		});
		if (scene === undefined) {
			print('[escape-velocity] FATAL: scene build failed for L' + (index + 1).toFixed(0));
			return undefined;
		}

		const camera = Camera3D();
		// 取景要按真实投影求解，所以必须把当前的视野角与宽高比一起传进去
		// （竖屏 aspect 0.56 ⇒ 横向可用空间只有纵向一半，这两个值直接决定相机拉多远）
		const rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio));
		const trajectory = createTrajectoryView(levelLayers[index], trajectoryOptions());
		// 2D 规划视图（S3.15）：与 trajectory 同一个 2D 层。视野 = 「最外圈轨道 + 目标容差」，
		// 于是整条最外圈与它那个到达圈都装得下（设计稿第 6 条"够不够得着"要能一眼看出来）。
		const plan = createPlanView(levelLayers[index], viewW, viewH, defaultPlanOptions());
		let planTolerance = def.goal.tolerance;
		const planChain = goalWaypoints(def.goal);
		for (let w = 0; w < planChain.length; w++) {
			if (planChain[w].tolerance > planTolerance) planTolerance = planChain[w].tolerance;
		}
		plan.fitTo(planFitRadius(bodies, level.probeStart, def.goal.planetIndex, planTolerance));
		// S3.9.2b：满力速度 = 这一关的 Δv 预算（不再是全局 55）—— "力大砖飞"从这里被挡住。
		const aim = createAimInput(levelLayers[index], viewW, viewH, def.dvBudget);
		// 进关先给一个初值：满力 = 这一关的 Δv 预算
		aim.setBurnInfo(0, def.dvBudget);
		// 时间流按钮（S3.9.4）：只有带 timeWindow 的关卡才启用
		const dateSpan = def.timeWindow !== undefined ? def.timeWindow.span : 0;
		aim.setDate(0, dateSpan); // 读数在每帧循环里刷新
		aim.onWarp((dir: number): void => {
			game.stepTime(dir, dateSpan);
			print('[escape-velocity] time warp dir=' + dir.toFixed(0) + ' (L' + (index + 1).toFixed(0) + ')');
		});

		const game = createGame(level, {
			scene,
			camera,
			rig,
			trajectory,
			plan,
			// 2D 图钉的颜色取自关卡自己的视觉描述：同一颗行星在两个视图里同色
			visuals: def.visuals,
			// 2D 模式要把 3D 世界整个收掉（两套画面不能叠在一起）
			setWorldVisible: (on: boolean): void => {
				world.visible = on;
			},
			aim,
			viewW,
			viewH,
			fovYDeg: View.fieldOfView,
			aspect: View.aspectRatio,
			onPhase: (p: GamePhase): void => {
				print('[escape-velocity] phase -> ' + p + ' (L' + (index + 1).toFixed(0) + ')');
				// ⚠️ 面板显隐**由状态驱动**，不由点按驱动（2026-09-26 用户："点了重试，UI 有反应但界面没变化"）。
				// 只要状态被别的东西改了（切关、视口重建、自动回归序列），点按驱动就会留下一个"留在屏幕上
				// 但已经没东西可改"的面板 —— 点它看起来完全没反应。状态是唯一事实来源：
				// 一旦离开 Result 态，面板必须消失（其余阶段都不该有结算面板）。
				if (p !== 'Result' && index === activeIndex && resultPanel !== undefined) resultPanel.hide();
			},
			onResult: (r: ResultKind): void => {
				// 结算在发射瞬间就已确定，这里只是“飞行播完了”的时刻
				if (r === 'success') {
					const next = advanceUnlocked(progress.unlocked, r, index, levelTotal);
					if (next !== progress.unlocked) {
						progress = { unlocked: next };
						saveProgress(progress);
						print('[escape-velocity] unlocked -> ' + next.toFixed(0) + ' (saved)');
					}
				}
				print('[escape-velocity] result = ' + r + ' on ' + levelNames[index]);
				resultIndex = index; // 面板显示的是**这一关**的结算（见 resultIndex 的说明）
				if (resultPanel !== undefined) resultPanel.show(r, levelNames[index]);
			},
		});

		// ⚠️ 把瞄准层接到状态机上（S2.2 重写 init.ts 时漏掉这两行，真机表现为
		// “进关卡拖不动飞行器”：触摸收到了，但 aim 的拖动/松手回调没人接，
		// 于是预测线不跟手、松手也不发射。旧版 init.ts(7cb72b0) 里就是这两行。）
		aim.onDrag((a: AimResult): void => {
			game.onAimDrag(a);
			// Δv 读数：本次点火的大小（拖动时实时变）
			aim.setBurnInfo(Math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), def.dvBudget);
		});
		// S3.10：松手**不发射** —— 进 Armed（出「发射」按钮），点按钮才真的打出去
		aim.onAimReady((a: AimResult): void => {
			game.onAimDrag(a);
			game.aimReady();
			print('[escape-velocity] aim ready -> Armed');
		});
		aim.onLaunch((): void => {
			print('[escape-velocity] launch button tap');
			game.launchArmed();
		});
		// 观察：拖动增量 -> 转相机；捏合 -> 远近
		aim.onObserve((dx: number, dy: number): void => {
			game.observeDrag(dx, dy);
		});
		aim.onZoom((deltaDist: number): void => {
			game.observeZoom(deltaDist);
		});
		// 「2D / 3D」手动切换（S3.15）：按钮只表达意图，翻转与节点切换都在 Game 里（状态驱动）
		aim.onViewToggle((): void => {
			game.toggleViewMode();
			print('[escape-velocity] view toggle -> ' + game.viewMode() + ' (L' + (index + 1).toFixed(0) + ')');
		});
		// 刹车模式（S3.9.2）：按钮只表达意图，状态在 GameCore 里；顺手打一行日志便于回归验证。
		aim.onBrake((on: boolean): void => {
			game.setBrakeMode(on);
			print('[escape-velocity] brake mode = ' + (on ? 'on' : 'off') + ' (L' + (index + 1).toFixed(0) + ')');
		});
		aim.setBrake(game.brakeMode());

			const runtime: LevelRuntime = {
			index,
			name: levelNames[index],
			world,
			camera,
			game,
			aim,
			trajectory,
			plan,
			levelHasTimeWindow: def.timeWindow !== undefined,
			dateSpan,
		};
		slot.built = true;
		slot.runtime = runtime;
		print('[escape-velocity] built L' + (index + 1).toFixed(0) + ' ' + levelNames[index]);
		return runtime;
	};

	/** 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。 */
	const enterLevel = (index: number): void => {
		const runtime = ensureLevel(index);
		if (runtime === undefined) return;
		// [二分 2b] 仅在真正切换关卡时压相机栈：重进已激活的关不重复压
		// （用户卡死路径 = 重进已建 runtime；怀疑同一相机被重复 push 后渲染遍历异常）
		const wasActive = activeIndex === index;
		// 开场那套 3D（全景）与关卡各有一套相机；进关卡就把它收掉，别让两套场景一起渲染
		if (opening !== undefined) opening.hide();
		if (select !== undefined) select.hide();
		activeIndex = index;
		showOnlyLevel(index);
		if (!wasActive) Director.pushCamera(runtime.camera);
		runtime.game.startLevel();
		print('[escape-velocity] enter ' + runtime.name);
	};

/** 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。 */
	const resultRuntime = (): LevelRuntime | undefined => {
		if (resultIndex >= 0 && resultIndex < levelTotal) {
			const rt = slots[resultIndex].runtime;
			if (rt !== undefined) return rt;
		}
		return activeRuntime();
	};

	const onRetryTap = (): void => {
		// 打点：区分"按钮没触发"与"触发了但状态机没动"（用户报过"结算按钮有时没反应"）
		const rt = resultRuntime();
		print('[escape-velocity] tap: retry (resultIndex=' + resultIndex.toFixed(0) + ' phase=' + (rt !== undefined ? rt.game.phase() : 'none') + ')');
		if (resultPanel !== undefined) resultPanel.hide();
		if (rt !== undefined) rt.game.retry();
	};

	const onBackToSelectTap = (): void => {
		const rt = resultRuntime();
		print('[escape-velocity] tap: back-to-select (resultIndex=' + resultIndex.toFixed(0) + ' phase=' + (rt !== undefined ? rt.game.phase() : 'none') + ')');
		if (rt === undefined) return;
		const runtime = rt;
		// 只有 Result 态才允许返回（coreBackToSelect 会把关），否则这次点按作废
		if (!runtime.game.backToSelect()) return;
		runtime.world.visible = false;
		runtime.aim.setEnabled(false);
		if (resultPanel !== undefined) resultPanel.hide();
		// 以存档为准刷新：成功那一局已经写过盘了
		progress = loadProgress(levelTotal);
		if (select !== undefined) select.show(progress.unlocked);
		print('[escape-velocity] back to select: unlocked=' + progress.unlocked.toFixed(0));
	};

	/**
	 * 建（或重建）UI 面板。
	 *
	 * 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	 * 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	 * 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	 *
	 * ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	 * TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	 */
	const buildPanels = (): LevelSelect => {
		resultPanel = createResultPanel(uiLayer, viewW, viewH, {
			onRetry: (): void => onRetryTap(),
			onBackToSelect: (): void => onBackToSelectTap(),
		});
		const created = createLevelSelect(uiLayer, viewW, viewH, {
			levels: levelEntries,
			onPick: (index: number): void => {
				print('[escape-velocity] tap: pick L' + (index + 1).toFixed(0));
				if (select !== undefined) select.hide();
				enterLevel(index);
			},
			// 「重看开场」：复用同一个开场实例（start() 会把帧号归零）；开场期间选关面板先收起
			onReplayIntro: (): void => {
				if (select !== undefined) select.hide();
				startOpening();
				print('[escape-velocity] opening replay (user)');
			},
		});
		select = created;
		return created;
	};

	/**
	 * 视口尺寸变化时的整体重建。
	 *
	 * 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	 * 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	 * 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	 *
	 * 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	 * 关卡运行时按需重建（slots 标记为未建）。
	 */
	const relayoutForViewport = (): void => {
		const w = View.size.width;
		const h = View.size.height;
		if (w === viewW && h === viewH) return;

		// 1) 旧 UI 与旧关卡运行时：隐藏 + 断触摸
		// 开场实例整块丢掉：它的文案坐标与轨道线像素都是按旧视口算的（新实例由 startOpening 重建；
		// 这次重建意味着玩家错过了开场，**不写标记** ⇒ 下次启动还会播一遍）
		if (opening !== undefined) {
			opening.hide();
			opening = undefined;
		}
		if (select !== undefined) select.hide();
		if (resultPanel !== undefined) resultPanel.hide();
		for (let i = 0; i < levelTotal; i++) {
			const slot = slots[i];
			if (slot.runtime !== undefined) {
				slot.runtime.world.visible = false;
				slot.runtime.aim.setEnabled(false);
				// ⚠️ 轨迹的 DrawNode 挂在**关卡 2D 层**上（不随 runtime 消失），不清的话
				// 旧视口算出的线会残留到新视口（2026-09-25 横屏截图实测：画面左侧多出一段游离的旧预测线）
				slot.runtime.trajectory.clearPrediction();
				slot.runtime.trajectory.clearTrail();
				// S3.7：到达环也挂在关卡 2D 层上 —— 不 clearing 会留下旧视口算出的椭圆
				slot.runtime.trajectory.clearGoalRings();
				// S3.15：2D 规划层同样是**挂在关卡 2D 层上的 DrawNode**（不随 runtime 消失）
				// ⇒ 旧视口算出的轨道圈/图钉/预测线必须一起清掉，否则新视口下会残留一层鬼影
				slot.runtime.plan.setVisible(false);
				slot.runtime.plan.clear();
			}
			slot.built = false;
			slot.runtime = undefined;
		}

		// 2) 更新容器尺寸（子坐标原点随之变化，必须与新的 View.size 一致）
		viewW = w;
		viewH = h;
		uiLayer.size = Size(viewW, viewH);
		openingLayer.size = Size(viewW, viewH);
		for (let i = 0; i < levelTotal; i++) levelLayers[i].size = Size(viewW, viewH);

		// 3) 重建面板并恢复当前状态
		const panel = buildPanels();
		if (activeIndex >= 0) {
			const keep = activeIndex;
			activeIndex = -1;
			enterLevel(keep);
		} else {
			panel.show(progress.unlocked);
		}
		print('[escape-velocity] viewport rebuilt: ' + viewW.toFixed(0) + 'x' + viewH.toFixed(0));
	};

	// 手机/浏览器里画布尺寸会在启动后变化 → 跟随重建（引擎的 AppChange/Size 事件）
	Director.entry.onAppChange((name) => {
		if (name === 'Size') relayoutForViewport();
	});

	// ---- 开场（S3.3）----
	// 分镜：太阳系全景 → 聚焦到地球旁已入轨的探测器 → 交还选关（此后相机缓缓拉回全景当背景）。
	// 播放策略（用户 2026-09-25 拍板）：**首次启动完整播，之后每次直接进选关**；任何时刻点击跳过。
	// 存档标记 = writablePath 下的 escape-velocity.intro（存在即看过）——不碰 Progress 的格式，
	// 免得"开场看没看过"和"解锁到第几关"互相拖累（ProgressTest 有格式断言）。
	let introSeen = loadIntroSeen();
	let forceIntro = false;
	let opening: Opening | undefined = undefined;

	const startOpening = (): void => {
		if (opening === undefined) {
			opening = createOpening({
				root: openingRoot,
				camera: openingCamera,
				layer: openingLayer,
				viewW: viewW,
				viewH: viewH,
				fovYDeg: View.fieldOfView,
				aspect: View.aspectRatio,
				spherePath: 'Assets/Model/Sphere.gltf',
				probePath: 'Assets/Model/Probe_Voyager_v1.glb',
				probeBodyPath: 'Assets/Model/Probe_Body.glb',
				probeAntennaPath: 'Assets/Model/Probe_Antenna.glb',
				onFinish: (): void => {
					introHold = -1; // 解冻（跳过关或自然播完）
					if (!introSeen) {
						saveIntroSeen();
						introSeen = true;
						print('[escape-velocity] intro seen -> saved');
					}
					// 播完/跳过 → 交还选关（panorama 留着当活背景，见 game/Opening.ts 的拉回段）
					if (select !== undefined) select.show(progress.unlocked);
					print('[escape-velocity] opening finished: frame=' + (opening !== undefined ? opening.frameIndex().toFixed(0) : '?'));
				},
			});
		}
		if (opening === undefined) return;
		Director.pushCamera(openingCamera);
		opening.start();
		print('[escape-velocity] opening start (first launch)');
	};

	const startupPanel = buildPanels();

	// 开发便利钩子（会话 25）：存在 .agent/test-results/enter-request.txt（内容 = 关卡号 N）时
	// 自动进第 N 关。生产/Web 导出该文件不存在 => 零开销；验证脚本因此可以绕开
	// 合成鼠标的选关坐标点击（2026-09-25 实测同一坐标两次进了 L6 而不是 L1，原因未查明）。
	//   内容格式：
	//     "N"             —— 自动进第 N 关（不开场）
	//     "N@frames:vx:vy"—— 进关后第 frames 帧以 (vx,vy) 自动发射（+ 回选关 + 重进的回归序列）
	//     "intro"         —— 强制播完整开场（不看存档标记）
	//     "intro@hold:N"  —— 强制播开场并**冻结在第 N 帧**（抓固定机位/分镜截图用；冻结后仍可跳过关）
	// 截图仍旧走 Test/GameShot.lua 驱动（见该文件的 shot-request 轮询）：
	// ⚠️ App.saveScreenshot 必须给**绝对路径**，相对路径实测让引擎原生崩溃（0xc0000374，二次复现）。
	const enterReq = Path(Path(".", ".agent", "test-results"), "enter-request.txt");
	let autoLaunchAt = -1;
	/** "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。 */
	let autoArmAt = -1;
	let autoFrame = 0;
	let autoVX = 0;
	let autoVY = 0;
	// 回归序列: 发射后回选关再重进 (复用 runtime, 相机 lerp), 复现用户卡死路径
	let autoBackAt = -1;
	let autoReenterAt = -1;
	let autoEntered = false;
	// 开场冻结帧（enter-request 的 @hold）：到这一帧就不再推进，方便按帧抓图
	let introHold = -1;
	if (Content.exist(enterReq)) {
		const spec = Content.load(enterReq);
		const at = spec.indexOf('@');
		const head = (at < 0 ? spec : spec.substring(0, at)).trim();
		if (head === 'intro') {
			forceIntro = true;
			if (at >= 0) {
				const rest = spec.substring(at + 1);
				const colon = rest.indexOf(':');
				if (colon > 0 && rest.substring(0, colon).trim() === 'hold') {
					const v = tonumber(rest.substring(colon + 1));
					if (v !== undefined && v >= 0) {
						introHold = v;
						print('[escape-velocity] opening hold at frame ' + v.toFixed(0));
					}
				}
			}
		}
		const n = tonumber(head);
		if (n !== undefined && n >= 1 && n <= levelTotal) {
			print('[escape-velocity] auto enter L' + n.toFixed(0) + ' (enter-request)');
			enterLevel(n - 1);
			autoEntered = true;
			if (at >= 0) {
				const rest = spec.substring(at + 1);
				// "N@arm:<frames>"：第 frames 帧自动"瞄好并松手"（进 Armed）——
				// 自动化测试要验证「发射」按钮本身，就不能靠"在探测器附近拖一次"
				// （那需要先知道探测器在屏幕上的坐标）。生产/Web 导出没有这个文件 ⇒ 零开销。
				if (rest.substring(0, 4) === 'arm:') {
					const f = tonumber(rest.substring(4));
					if (f !== undefined && f >= 0) {
						autoArmAt = f;
						print('[escape-velocity] auto arm scheduled: frame ' + f.toFixed(0));
					}
				} else {
				const c1 = rest.indexOf(':');
				const c2 = rest.indexOf(':', c1 + 1);
				if (c1 > 0 && c2 > c1) {
					const frames = tonumber(rest.substring(0, c1));
					const vx = tonumber(rest.substring(c1 + 1, c2));
					const vy = tonumber(rest.substring(c2 + 1));
					if (frames !== undefined && vx !== undefined && vy !== undefined) {
						autoLaunchAt = frames;
						autoVX = vx;
						autoVY = vy;
						print('[escape-velocity] auto launch scheduled: frame ' + frames.toFixed(0) + ' v=(' + vx.toFixed(1) + ',' + vy.toFixed(1) + ')');
					}
				}
				}
			}
		}
	}

	// ---- 启动决策（S3.3）：首次启动完整播开场，之后直接进选关 ----
	// 开发钩子优先：自动进关时不播开场（否则开场相机会盖住关卡画面）。
	if (autoEntered) {
		print('[escape-velocity] opening skipped (auto enter)');
	} else if (forceIntro || !introSeen) {
		startOpening();
	} else {
		startupPanel.show(progress.unlocked);
		print('[escape-velocity] opening skipped (already seen)');
	}

	// ---- 单一主循环（手册 §4.3）：只驱动当前激活的关（+ 开场）----
	// ⚠️ threadLoop 回调没有参数，帧间隔用 App.deltaTime
	threadLoop(() => {
		// 开场先推进（它在场时没有激活的关；播完转 idle，继续当选关界面的背景）
		if (opening !== undefined && opening.running()) {
			// @hold:N —— 冻结在第 N 帧不动（抓分镜截图用）；轻触跳过时 onFinish 会解冻
			if (introHold < 0 || opening.frameIndex() < introHold) opening.step();
			// 开场卡顿的现场证据（用户 2026-09-26 第 3 条反馈"首播卡、重看不卡"）：
			// 超过 50ms 的帧打一行，带开场帧号 —— 分帧建之后这几行应该消失
			if (App.deltaTime > 0.05) {
				print('[escape-velocity] hitch ' + (App.deltaTime * 1000).toFixed(0) + 'ms @ opening frame ' + opening.frameIndex().toFixed(0));
			}
		}

		const runtime = activeRuntime();
		if (runtime !== undefined) {
			runtime.game.update(App.deltaTime);
			// 时间流读数：每帧刷新（日期在走，滑杆/按钮本身不存状态）
			if (runtime.levelHasTimeWindow) {
				runtime.aim.setDate(runtime.game.dateNow(), runtime.dateSpan);
			}
			// 时间流只在"能改日期"的相态里可点（飞行中改日期会让行星在飞行途中跳位），
			// 并驱动"按住连按"（S3.11）—— 两件都是状态驱动，不能只靠点按（AGENTS 硬约束 5）
			const phaseNow = runtime.game.phase();
			runtime.aim.setTimeEnabled(phaseNow === 'Aiming' || phaseNow === 'Armed');
			runtime.aim.update(App.deltaTime);
			// Armed 是状态，按钮显隐跟着状态走（AGENTS 硬约束 5）
			runtime.aim.setArmed(runtime.game.armed());
			// 视图也是状态：右下角那颗按钮的文字跟着 core.viewMode 走（别自己翻转局部变量）
			runtime.aim.setViewMode(runtime.game.viewMode());
			// 开发钩子的自动发射（见上方 enter-request 说明）
			if (autoLaunchAt >= 0 || autoBackAt >= 0 || autoReenterAt >= 0 || autoArmAt >= 0) {
				autoFrame += 1;
				// "N@arm:<frames>"：自动进 Armed（出「发射」按钮），用于验证按钮本身
				if (autoArmAt >= 0 && autoFrame >= autoArmAt) {
					autoArmAt = -1;
					print('[escape-velocity] auto arm (enter-request)');
					runtime.game.aimReady();
				}
				if (autoLaunchAt >= 0 && autoFrame >= autoLaunchAt) {
					autoLaunchAt = -1;
					print('[escape-velocity] auto launch');
					runtime.game.launch({ x: autoVX, y: autoVY });
					autoBackAt = autoFrame + 320;
					autoReenterAt = autoFrame + 380;
				}
				// [二分 1：注释掉回选关+重进，定位崩溃触发器]
				if (autoBackAt >= 0 && autoFrame >= autoBackAt) {
					autoBackAt = -1;
					if (runtime.game.backToSelect()) print('[escape-velocity] auto back to select');
				}
				if (autoReenterAt >= 0 && autoFrame >= autoReenterAt) {
					autoReenterAt = -1;
					print('[escape-velocity] auto re-enter');
					enterLevel(0);
				}
			}
		}

		return false; // false = 继续
	});

	// 带上视口尺寸与平台：真机（手机浏览器）排查全靠这一行——手机上的 View.size 只能从这里看
	print('[escape-velocity] started: ' + levelTotal.toFixed(0) + ' levels, unlocked=' + progress.unlocked.toFixed(0) + ', view=' + viewW.toFixed(0) + 'x' + viewH.toFixed(0) + ', platform=' + App.platform + ', introSeen=' + (introSeen ? 'yes' : 'no'));
}
