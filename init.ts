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
import { getLevel, levelCount, scaledPlanets } from 'game/LevelData';
import { buildScene } from 'game/Scene';
import { createCameraRig, defaultRigOptions } from 'game/CameraRig';
import { createTrajectoryView, defaultOptions as trajectoryOptions } from 'game/Trajectory';
import { AimInput, AimResult, LevelSelect, ResultPanel, createAimInput, createLevelSelect, createResultPanel } from 'game/Hud';
import { Game, GameLevel, GamePhase, ResultKind, createGame } from 'game/Game';
import { Progress, advanceUnlocked, loadProgress, progressFilePath, saveProgress } from 'game/Progress';

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

	Director.entry.setEnvironmentIntensity(0.35, 0.35, 1);

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
			if (slot.runtime === undefined) continue;
			const active = i === index;
			slot.runtime.world.visible = active;
			slot.runtime.aim.setEnabled(active);
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
			goal: def.goal,
			escapeRadius: def.escapeRadius,
			maxSteps: def.maxSteps,
		};

		const world = Node3D();
		Director.entry.addChild(world);
		world.visible = false;

		const scene = buildScene({
			root: world,
			bodies,
			visuals: def.visuals,
			probeStart: level.probeStart,
			probeScale: 1.6,
			spherePath: 'Assets/Model/Sphere.gltf',
			ringPath: 'Assets/Model/Ring.gltf',
			probePath: 'Assets/Model/Probe.gltf',
		});
		if (scene === undefined) {
			print('[escape-velocity] FATAL: scene build failed for L' + (index + 1).toFixed(0));
			return undefined;
		}

		const camera = Camera3D();
		const rig = createCameraRig(defaultRigOptions());
		const trajectory = createTrajectoryView(levelLayers[index], trajectoryOptions());
		const aim = createAimInput(levelLayers[index], viewW, viewH);

		const game = createGame(level, {
			scene,
			camera,
			rig,
			trajectory,
			aim,
			viewW,
			viewH,
			fovYDeg: View.fieldOfView,
			aspect: View.aspectRatio,
			onPhase: (p: GamePhase): void => {
				print('[escape-velocity] phase -> ' + p + ' (L' + (index + 1).toFixed(0) + ')');
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
				if (resultPanel !== undefined) resultPanel.show(r, levelNames[index]);
			},
		});

		// ⚠️ 把瞄准层接到状态机上（S2.2 重写 init.ts 时漏掉这两行，真机表现为
		// “进关卡拖不动飞行器”：触摸收到了，但 aim 的拖动/松手回调没人接，
		// 于是预测线不跟手、松手也不发射。旧版 init.ts(7cb72b0) 里就是这两行。）
		aim.onDrag((a: AimResult): void => { game.onAimDrag(a); });
		aim.onRelease((a: AimResult): void => { game.launch(a.velocity); });

		const runtime: LevelRuntime = {
			index,
			name: levelNames[index],
			world,
			camera,
			game,
			aim,
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
		activeIndex = index;
		showOnlyLevel(index);
		Director.pushCamera(runtime.camera);
		runtime.game.startLevel();
		print('[escape-velocity] enter ' + runtime.name);
	};

	const onRetryTap = (): void => {
		if (resultPanel !== undefined) resultPanel.hide();
		const runtime = activeRuntime();
		if (runtime !== undefined) runtime.game.retry();
	};

	const onBackToSelectTap = (): void => {
		const runtime = activeRuntime();
		if (runtime === undefined) return;
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
				if (select !== undefined) select.hide();
				enterLevel(index);
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
		if (select !== undefined) select.hide();
		if (resultPanel !== undefined) resultPanel.hide();
		for (let i = 0; i < levelTotal; i++) {
			const slot = slots[i];
			if (slot.runtime !== undefined) {
				slot.runtime.world.visible = false;
				slot.runtime.aim.setEnabled(false);
			}
			slot.built = false;
			slot.runtime = undefined;
		}

		// 2) 更新容器尺寸（子坐标原点随之变化，必须与新的 View.size 一致）
		viewW = w;
		viewH = h;
		uiLayer.size = Size(viewW, viewH);
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

	// ---- 启动即进入关卡选择（Title/金唱片开场属 S3.3）----
	buildPanels().show(progress.unlocked);

	// ---- 单一主循环（手册 §4.3）：只驱动当前激活的关 ----
	// ⚠️ threadLoop 回调没有参数，帧间隔用 App.deltaTime
	threadLoop(() => {
		const runtime = activeRuntime();
		if (runtime !== undefined) runtime.game.update(App.deltaTime);
		// TEMP SHOT：视口重建前后各一张 + 进关后一张
		shotFrame += 1;
		if (shotFrame === 240) { const d = Path(Content.searchPaths[0], '.agent/test-results'); App.saveScreenshot(Path(d, 'r-pre')); print('[shot] r-pre'); }
		if (shotFrame === 600) { const d2 = Path(Content.searchPaths[0], '.agent/test-results'); App.saveScreenshot(Path(d2, 'r-post')); print('[shot] r-post'); }
		if (shotFrame === 900) { const d3 = Path(Content.searchPaths[0], '.agent/test-results'); App.saveScreenshot(Path(d3, 'r-aim')); print('[shot] r-aim'); }

		return false; // false = 继续
	});

	// 带上视口尺寸与平台：真机（手机浏览器）排查全靠这一行——手机上的 View.size 只能从这里看
	print('[escape-velocity] started: ' + levelTotal.toFixed(0) + ' levels, unlocked=' + progress.unlocked.toFixed(0) + ', view=' + viewW.toFixed(0) + 'x' + viewH.toFixed(0) + ', platform=' + App.platform + ', level select shown');
}
