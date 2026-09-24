# Project Memory

### Project Facts

- 项目：《单程》Escape Velocity。Dora SSR × Agent 社区小游戏征集的参赛项目（AtomGit 公开仓库）。
- 形态：竖屏 1080×1920 设计分辨率、单指触屏、六关、一次性发射的物理规划小游戏。
- 技术：TypeScript（编译为 Lua）+ Dora SSR；low poly 3D + 纯色 flat 零贴图；**物理 2D 平面积分，渲染 3D**。
- 许可：AGPL-3.0-only（`LICENSE` = gnu.org 官方全文 34,523 B，SHA256 校验通过）；版权人 **Dragonzhi**（2026）；**已测设备：Web 浏览器**。
- 唯一事实来源：`docs/开发手册.md`；产品愿景：`单程-项目愿景.md`；计划：`.agent/plan/`（`PLAN.md`、`PROGRESS.md`）。
- **开发方式（会话 13 起）**：改用外部 Coding Agent（DSH）+ 引擎本体；DSH 负责读写/编译/驱动/验证，引擎只当运行时。本 `.agent/` 目录仍是记忆与进度的载体，需持续维护。能力对照见 `docs/DSH-vs-Dora内置Agent-能力对照.md`；内置 Agent 提示词存档见 `.agent/dora-agent-prompts.md`。

### Build And Run

- 入口：项目根 `init.ts`（真实游戏入口 = 场景 + 相机机架 + 轨迹层 + 瞄准输入 + 状态机 + 单一 `threadLoop`；从 `LevelData` 加载关卡）。
- 🔴 **Web 导出**：用 **Web IDE 自带的「导出 HTML / 打包 / 下载」**即可，浏览器内 3D 正常（用户实测）。**无需**从源码编译引擎 —— 引擎是预编译发行版（只有 `Dora.exe`/`wa.dll`/`LICENSES`），`Tools/`、`Projects/`、`Source/` 不存在；CLI 也没有 Web 构建命令。
- 纯逻辑单测（**批跑入口**）：引擎内运行 `Test/UnitRunner.lua` → `.agent/test-results/unit-summary.txt`。单模块也可 `requireProjectModule("Test.<X>").runTests()`（先 `package.loaded[...] = nil` 清缓存）。
- **引擎命令行**（`<引擎>\Dora.exe cli …`）：`status` / `build -p <项目>` / `run` / `buildrun` / `stop` / `log -n` / `doc search|read` / `ts install`。`cli build` 全量编译并给逐文件诊断（`Duplicate compiler file: lualib_bundle.lua` 是已知噪音）。
- **引擎 HTTP API（8866）**：关掉引擎设置里的「访问验证 / Auth Required」后无鉴权可用；常用 `POST /status`、`/run`、`/stop`、`/run/status`、`/log`、`/ts/build`、`/doc/search`。⚠️ `/ts/build` 要求 Web IDE 浏览器已连接；WS 在 8868。
- **本地 TS→Lua 构建（不依赖引擎与浏览器）**：`node tools/dora-build/build.mjs --all`（仓库内，不是 `.temp/`），产物与引擎逐字节一致；
  版本钉死 **tstl 1.37.1 + TS 5.9.3**，安装必须 `npm i --legacy-peer-deps`；一致性门禁 `--out <tmp>` + `compare-all.mjs`（标定见 `tools/dora-build/REPORT.md`）。
  ⚠️ **提交前必须 36/36 全绿**（曾提交过构建失败的状态 `e62c07d`）。
- **看图**：引擎截图是未压缩 TGA → `python -c "from PIL import Image; Image.open('x.tga').save('x.png')"` 后可直接查看。
- 运行时探针：`enterEntryAsync({fileName="Test/<X>Probe.ts"})` + 轮询标记文件到 `phase=done`。
  ⚠️ **入口租约**：Web IDE 占用入口时无法运行；`stopEntry()` 也不能释放。
  ⚠️ **轮询诀窍**：探针会先写 `phase=started`，轮询循环必须等到出现 `phase=done`（或 `RESULT=PASS/FAIL`）才停。
- **合成鼠标 = 真实触摸路径**：`tools/input-inject/mousectl.ps1`（`click/drag/press/move/release`，`-HoldMs` 做分段时序）驱动**真实命中判定**与状态机；
  坐标换算基准是 `Test/SizeProbe.lua` 读出的 `View.size`（**不要写死分辨率**）：`client_x = view_x·(clientW/W)`、`client_y = (H − view_y)·(clientH/H)`。
- **竖屏窗口**：`tools/input-inject/set-window.ps1 -Shape portrait|landscape`（Win32 `MoveWindow`；客户区 400×710 → `View.size` 601×1066）。
  ⚠️ `.ps1` 必须 CRLF（here-string 在纯 LF 下解析失败）。日志用 `POST /log` 读（`log.txt` 有缓冲与轮转）。
- 离线资产生成：`Test/gen_shapes.lua`（在入口内执行才能写文件；命令模式 Content 只读）。
- ⚠️ **增量构建有时不重新转译**（本会话在 `Config.lua`、`Projection.lua` 上各踩一次）：`build` 报成功但 `.lua` 未更新 → 改一次 `.ts`（哪怕改注释）强制重编，然后 grep 编译产物确认。
- 🚨 **包体积**：Web 导出实测 **17 MB** > 8 MB 目标（用户已决定暂不处理）。
- ⚠️ **TS 编译产物与源同目录**：`init.ts`→`init.lua`、`game/*.ts`→`game/*.lua`、`Test/*.ts`→`Test/*.lua`；但 `Test/gen_shapes.lua` 是手写源。→ `.gitignore` **不能笼统忽略 `*.lua`**（手册 §8.1）。

### Git History

- `283e9cb` / `138e6ce` 守则：提交前必须构建全绿；删掉重复条目
- `e62c07d` / `4c160f9` 清理 init.ts 残留截图钩子（构建曾失败）；启动日志补视口尺寸与平台
- `31cba6e` **视口尺寸变化时整体重建**（手机真机：预测线偏移 / 竖屏没适配的根因，会话 20）
- `21a5c78` **竖屏（交付形态）实测与修复**：关卡选择溢出、结算按钮戳出卡片（会话 19）
- `bd12af8` **交互改为相对拖动 + 修触摸命中框只剩左下象限**（会话 18）
- `238cc95` **修复预测线整体平移半个屏幕**：绘制层坐标空间 ≠ 投影输出空间（会话 17）
- `09645a5` **修复真机“进关卡拖不动”的真正根因**：瞄准层没接到状态机（会话 16）
- `c0179fc` 仓库级守则与 Dora 引擎技能：`AGENTS.md` + `.dsh/skills/dora-ssr-engine`
- `dddb404` 修复全屏吞触摸层独占点击（会话 15，当时判断非最终根因）
- `029bdad` **工具链：本地 TS→Lua 构建纳入仓库 + 单测入口与许可补齐**（会话 13；`tools/dora-build/`、`Test/UnitRunner.lua`、LICENSE 官方全文、README 作者/设备）
- `4033e09` **S2.2 + S2.3：结算三态面板与关卡选择、解锁进度**（会话 14）

- `2f2cbb6` init（仅 init.ts）
- `89be60e` **S0 裸测完成：关闭 R1/R2/R3/R4**（37 文件；提交信息有错别字，选择不改写历史）
- `ed29f75` **S1.1 物理内核**（`game/Gravity.ts` + `Test/GravityTest.ts`）
- `94b77af` **S1.2 场景与相机跟随**（`game/Scene.ts` + `game/CameraRig.ts` + 测试）
- `eb75f07` **S1.3 轨迹渲染**（`game/Trajectory.ts` + `Projection.prepareCamera` + 测试；含 Line→DrawNode 修正）
- `3205cb8` **S1.4 拖拽瞄准与发射**（`game/Hud.ts` + Config 瞄准参数 + `Projection.screenToPlaneY` + 测试）
- `4125b1a` **S1.5 状态机与主循环**（`game/Game.ts` + `init.ts` 改写 + `FlightPlayback` + 测试）
- `9d080b6` **S2.1 六关数据与目标判定**（`game/LevelData.ts` + Game 接入 `resolveResult` + 测试）
- `7cb72b0` **修复预测线垂直镜像**（Projection/Trajectory/Hud/Game + 测试；根因见 Known Issues）

### Files And Architecture

- `game/Ui.ts`（会话 14 新增）：视图空间 2D 原语 `createPanel` / `createLabel` / `createButton`（按钮自身可点：`touchEnabled`+`swallowTouches`+`onTapEnded`；配色与触屏下限集中于此）。
- `game/Progress.ts`（会话 14 新增）：`clampUnlocked` / `advanceUnlocked`（纯函数，仅 success 解锁、重玩不回退）+ `loadProgress` / `saveProgress`（`Content.writablePath/escape-velocity.progress`，一行 `unlocked=N`，损坏即 0）。⚠️ v1.9.3 的 `App` 无 `writablePath`，只有 `Content.writablePath`。
- `game/Hud.ts`：`createResultPanel`（三态 + 重试/返回）与 `createLevelSelect`（六关；竖屏 2 列×3 行 / 横屏 1 列×6 行）。
  **瞄准层 `createAimInput` 的根节点 `anchor` 必须是 `(0,0)`**（见 Known Issues 第 11 条）；交互语义 = **相对拖动**（按下点 = 摇杆零点 → 位移决定方向/力度 → 松手发射）。
- `game/Game.ts`：`GamePhase` 增加 `'LevelSelect'`；`coreBackToSelect`（仅 Result 态）与 `startLevel`；`coreLaunch`/`coreUpdate`/`coreRetry` 语义未改。
- `init.ts`（336 行）：启动即 LevelSelect；`ensureLevel(i)` 惰性建每关运行时（只让当前关 `visible` + 只开当前关的瞄准层）；单一 `threadLoop`；
  `buildPanels()` 可重复调用 + `relayoutForViewport()`（`onAppChange === 'Size'` 时整体重建，会话 20）。
- `game/Trajectory.ts`：`projectPolyline(points, y, basis, originX, originY)` —— **层原点显式传参**（`TrajectoryOptions.layerOriginX/Y`，默认 `View.size/2`）。

- `docs/开发手册.md`：架构分层与模块清单、参数表、编码规范、验收标准与证据分级（§2 D1–D7、§5.5 轨迹、§5.6 关卡数据、§5.7 输入、§5.8 结算、§7.2.1 TSTL 坑、§8.1 lua 忽略、§9.1 视觉验证、§11 R1/R6）。
- `game/Config.ts`：全局常量与调参表（`PlaneToWorldX/Z`、`CameraTilt*`、`CameraMin/MaxDistance`、`PhysicsStep`、`MaxStepsPerFrame`、`PredictSteps`、`GravityScale`、`OrbitSpeedScale`、**`AimMinSpeed=2`/`AimMaxSpeed=22`/`AimMaxDragPx=380`**、**`FlightPlayback=2`**）。
- `game/Projection.ts`（**已标定，Y 轴已修正**，纯函数）：`project`/`unprojectDirectionPrepared`、`prepareCamera(cam,…)`、`projectPrepared(p, basis)`、`projectPolyline`、`screenToPlaneY`（射线与 y=0 平面求交）、`toOverlay`（**恒等变换**）。手性 `right=cross(forward,up)`；`HANDEDNESS=1`、`FLIP_Y=false`。viewPoint = **左下原点、+Y 向上**；`project()` 输出 = 中心原点 +Y 向上偏移（= Dora 2D 空间）。实测最大误差 **1.00 px**（2024×1230）。
- `game/Gravity.ts`（S1.1，零引擎依赖）：类型 `P2`/`Body`/`ProbeState`/`SimOptions`/`SimResult`/`Outcome`；`bodyPositionAt`、`accelerationAt`、`step`（半隐式欧拉）、`collisionIndex`、`simulate`（**预测与真实共用的唯一推演实现**）、`orbitalSpeed`/`applyScales`/`sub`/`length`/`distance`。固定步长由调用方传入。
- `game/Scene.ts`（S1.2）：`planeToWorld(p, y)`、`buildScene(options)` → `GameScene{ syncBodies, syncProbe, faceVelocity, probe, planets }`；行星用 `Model3D(path).getMaterial(0).baseColor` 逐实例染色。
- `game/CameraRig.ts`（S1.2）：`computeFit`（包围盒中心 + 半对角）、`computeRigStep`、`createCameraRig`、`defaultRigOptions`（tilt=45、dist 25–100、lerp=0.1）。接口成员函数必须标 `/** @noSelf **/`。
- `game/Trajectory.ts`（S1.3）：`decimate`、`defaultOptions`（含 `y=0.02`、predict/trail 颜色与半径）、`projectPolyline`、`createTrajectoryView`（`setPrediction`/`clearPrediction`/`setTrail`/`clearTrail`）——预测线 + 真实尾迹共用同一 `simulate` 结果；用 `DrawNode.drawSegment` + 顶点 `drawDot`（圆头）。
- `game/Hud.ts`（S1.4）：`computeAim(probeOffset, touchOffset, maxDragPx)`（方向 = 探测器→触摸点；**`uy = -dy/len`：平面 y 轴与偏移 y 轴反向，负号必须保留**）、`screenToPlane`、`localToOffset`/`offsetToLocal`（**统一为 +Y 向上**）、`TouchSpace`、`AimInput`（属性式箭头函数接口）、`createAimInput`（带尺寸全屏触摸节点，`onDrag`/`onRelease`/`setEnabled`/`handleLocal`/`handleOffset`）。职责边界：只把触摸变成发射向量，不碰物理/渲染。
- `game/LevelData.ts`（S2.1，227 行，纯数据 + 纯函数，**不 import 'Dora'**）：六关定义（每关一旋钮 + 任务简报）+ `findGoalIndex`（支持移动目标：逐点用该采样时刻的行星位置判定）+ `scaledPlanets`/`getLevel`/`levelCount`。
- `game/Game.ts`（S1.5 + S2.1，~300 行）：
  - **纯逻辑 `GameCore`**：`coreLaunch`（发射时预推演整段飞行 + 算 goalIndex + 定 result）、`coreUpdate`（逐帧回放 + 判进入 Result）、`coreRetry`、`coreProbeIndex`、`resolveResult(outcome, goalIndex, goal)`（到达目标 > 逃逸达成 > 撞毁 > 错过）。
  - **引擎驱动层 `createGame(level, deps)`**：驱动场景/相机/轨迹/瞄准，回调 `onPhase`/`onResult`；瞄准态**每帧**重画预测线（相机可能仍在 lerp）。
- `Assets/Model/`：离线生成的自包含 glTF（Sphere 61v/120f、Ring 16/16、Probe 12v/4f）。
- 测试/探针（`Test/`）：
  - 单测（7 模块 / 164 断言）：`GravityTest`(25)、`CameraRigTest`(11)、`TrajectoryTest`(11，含 `layer-origin-is-half-view`)、`HudTest`(17)、`GameTest`(30)、`LevelDataTest`(34)、`ProgressTest`(36)；批跑入口 `UnitRunner.lua`。
  - 运行时探针：`Smoke`、`ProjectionProbe`（`RESULT=PASS maxPxErr=1.00`）、`CameraProbe`、`CameraVisual`、`SceneProbe`、`TrajectoryProbe`、`HudProbe`、`GameProbe`（完整循环 `RESULT=PASS`）、`VisionProbe`。
  - 诊断探针（镜像 bug 期间新增）：`ClearTest`（验证 `DrawNode.clear()` 正常）、`ProjCheckProbe`（`project()` vs `getRayDirection`）、`VerdictProbe`（颜色标记球裁决）、`LineDirProbe`、`LineAlignProbe`。
  - 工具库：`Vision.ts`（TGA → ASCII/亮度/列剖面/连通域/rgbAt）；`SizeProbe.lua`（读 `View.size` 等，合成鼠标坐标基准）。
  - 仓库工具：`tools/dora-build/`（本地构建）、`tools/input-inject/`（`mousectl.ps1` 合成鼠标、`set-window.ps1` 竖屏窗口）。
- 仓库骨架：`README.md`、`.gitignore`、`LICENSE`、`Assets/`、`Test/`、`game/`、`.agent/plan/PLAN.md`。

### Decisions

- D1 引力弹弓：行星公转 + 真实弹弓（相对速度自然产生加速/减速），行星轨道速度调到肉眼可见。
- D2 时间：瞄准时全局冻结；松手瞬间行星从相位 0 开始公转、探测器同时发射。
- D3 相机：单一 Camera3D + 动态跟随拉远，不做视角硬切。
- D4 世界观：借真实天体名与视觉，但不守真实轨道比例。
- D5 失败流程：重试本关 / 返回关卡选择；进度只记已解锁关卡，无星级。
- D6 几何资产：代码能生成就用代码，其余用公开素材。**实际落地：外部取物不可用（R8），全部用 `Test/gen_shapes.lua` 代码生成。**
- D7 文档双落点：手册 + `.agent/plan/`。

### Level Design (S2.1 六关)

| 关 | 新旋钮 | 设计 |
|---|---|---|
| 1 直飞 | 无引力 | 火星纯靶（gm=0） |
| 2 第一次弯曲 | 一颗静止行星 | 金星挡在航线右侧 |
| 3 从背后抄过去 | 必须借力 | 木星 gm=1500 挡路，土星藏侧后 |
| 4 它动了 | 公转 + 时机 | 火星绕行，既是障碍也是目标 |
| 5 两连弹 | 两颗行星 | 木星 + 土星两级弹弓，目标天王星 |
| 6 贴着过去 | 容差收窄 | 掠过土星（容差 2.2 vs 半径 1.6） |

- **可玩性硬门**（`LevelDataTest`）：每关必须至少存在一个可行解 —— 扫掠用**角度×力度**（12 方向 × 4 档力度）；**轴向网格扫掠会漏掉斜向解**（曾误报 L3/L5 不可达）。关卡手感（难度曲线）仍需真人试玩校准。

### Camera And Layout Facts (S0/S1.2 实测)

- **竖屏 1080×1920（宽高比 0.5625）**；`View.fieldOfView` = 45°（垂直 FOV）。
- **`View.size` = 窗口客户区像素 × 1.5**（引擎渲染逻辑尺寸）。桌面上**可以**在运行时改窗口（`tools/input-inject/set-window.ps1` 用 Win32 `MoveWindow`），改完 `View.size` 跟着变：
  **横屏 1349×820 客户区 → 2024×1230**（投影标定在此分辨率完成，`aspect≈1.6455`）；**竖屏 400×710 客户区 → 601×1066**（交付形态）。
- 🚨 **视口变化必须整体重建**（会话 20）：手机浏览器画布在启动后还会变一次；`onAppChange === 'Size'` → `init.ts` 的 `relayoutForViewport()`
  （更新 `uiLayer`/`levelLayers[i]` 的 `size` → 重建面板 → 按需重建关卡运行时；旧层只隐藏 + 断触摸，不销毁）。
- **物理平面必须沿屏幕纵向（世界 Z）展开**：横向展开的轨道在竖屏下 `maxNdcX=1.50` 被裁；纵向展开 `maxNdcX=0.72`/`maxNdcY=0.65` 完整可见（dist=30/tilt=45）。
- **倾角安全区间 20–60°**（>70° 贴边）；**纵向轨道 `dist ≥ 25`** 即可框住整条轨道；横向轨道需 `dist ≥ 50`。
- ⚠️ 修正后屏幕方向语义：**世界 +z（靠近相机）在屏幕下方**，-z 在上方（近景在画面下方，与真实相机一致）→ 探测器在下、目标在上，向上发射。

### Known Issues

- **内置 Agent 已不可用（会话 13）**：主会话上下文 40–52 万 tokens/请求，压缩连续 524（`log.txt` 有原文）；它其实支持 `/compact`/`/clear`（`DoraAgent.ts:688`），但界面未暴露。
- **关闭「访问验证」后，同一局域网内其他设备也能无鉴权调用 8866 API**（本机开发可接受；勿在不安全网络下长期关闭）。
- Dora TS 层**无**程序化几何工厂 → 已用代码生成 glTF 解决。
- Dora TS 层**无** `Matrix4`/矩阵 API，也**无** world→screen 投影 → **已自建并标定**（`game/Projection.ts`）。
- **`View3D.getRayOrigin` 返回的不是视点**（相差 0.16）；正确做法是用 `getRayDirection` 搜索法标定（dot 最大）。
- 🔴 **`getRayDirection`/`pick` 的 viewPoint = 左下原点 +Y 向上**（R4 曾误判为左上原点 +Y 向下；中心点对 Y 翻转不敏感）→ `toOverlay` 必须恒等、`projectPolyline` 不翻转 y。修正前所有 2D 覆盖层垂直镜像。
- `Line` 只能画 2D 且**线宽不可控（~1px，2024×1230 下几乎不可见）** → 轨迹改 `DrawNode.drawSegment`；`View3D.pick(viewPoint)` 可作模型命中真值源。
- **`Touch` 私有构造，无法程序化注入** → 真实触摸坐标系需一次人工校对（`localToOffset` 是唯一校准点；`handleLocal`/`handleOffset` 是保留的输入缝隙）。
- 🔴 **TSTL 坑（编译期不报错，运行时报错）**：
  1. **接口/对象成员函数默认带 self** → 生成 `obj:method(arg)` 冒号调用，参数错位，报 "attempt to perform arithmetic on a nil value (field 'x')"。解法：接口加 `/** @noSelf **/`（**属性式函数类型无效**，仍生成冒号调用）。
  2. **`threadLoop` 返回 `false` 继续、`true` 停止**；且**回调没有参数** —— 帧间隔用 `App.deltaTime`（签名 `(this: void) => boolean`）。
  3. **工厂命名空间不是类型**：标注用 `Vec3.Type` / `Node3D.Type` / `Model3D.Type`（否则 TS2709 “Cannot use namespace … as a type”）。
  4. **`Director.entry` 是 `View3D`（Node3D）**，2D 绘制节点（`DrawNode`/`Line`/`Label`）必须挂 `Director.ui`。
  5. **`Vec2` 是 float32**：与 float64 普通对象比较有 ~1e-8 相对误差；断言时应两边都降为 float32 再逐位比较。
  6. **`null` 不支持**（TS100038，用 `undefined`）；**`toExponential` 不支持**（用 `toFixed`）；**`saveScreenshot` 异步落盘**（需隔几帧再读）。
  7. **TS100016**：返回对象/接口里用简写属性引用局部函数会报"无 this 转换"，包一层箭头函数即可。
  8. **TS100037**：Lua 里只有 `false`/`nil` 为假，条件判断须显式 `!== undefined`。
  9. **字面量类型比较**：`const PlaneToWorldX = 1`（字面量 1）与 `!== 0` 比较会被 TS 判为无意义（TS2367）→ 避免这类判断。
  10. **增量构建有时不重新转译**：`build` 报成功但 `.lua` 未更新 → 改一次 `.ts` 强制重编；批处理编辑若报 "saved N/M operations" 说明有编辑静默失败，需重试。
 11. 🔴 **子坐标原点 = 位置 − anchor × 尺寸**：全屏容器/层 `anchor` 必须 `(0,0)`；(0.5,0.5) 会把**触摸命中框**与 2D 绘制原点推走半个屏幕
     （踩两次：预测线平移半屏、命中框只剩左下象限）。需要居中时显式设 `position = (W/2, H/2)`。
 12. 🔴 **投影输出的空间 ≠ 绘制层的空间**：`project()` = 中心原点偏移，`levelLayers[i]` 子空间 = 左下原点绝对像素；
     偏移量必须显式传参（`TrajectoryOptions.layerOriginX/Y`），不要在函数里读全局 `View.size`。
 13. 🔴 **Windows PowerShell 脚本必须 CRLF**（here-string 在纯 LF 下解析失败，`set-window.ps1` 踩过）。
  详见手册 §7.2.1、§5.5 第 6 条与 §5.7 第 2 条。
- **Lua 无 `io` 库**（`io=nil`，`os.execute`/`os.rename`/`os.remove` 均 nil，仅 `os.getenv` 可用）；支持 `string.pack`/`string.unpack`/位运算（Lua 5.5）。
- **命令模式 Content 只读且被沙箱限制**（见 Core Memory）。
- **入口租约**：Web IDE 占用入口时 `stopEntry()` 不释放，`enterEntryAsync`/`previewGame` 报 `Dora entry runtime is in use`。
- **R8 网络取物不可用**：`fetch_url` 落盘 0 字节 / 移入目标路径失败；`git clone` 到 github 超时。
- 🚨 **R6：Web 导出实测 17 MB**，超 8 MB 目标（包体由引擎 WASM 主导，项目侧无法解决）。
- ⚠️ **区域检测（cell=12 中心采样）会漏掉 ~5px 宽的细竖线** → 诊断细线改用 ASCII 图。
- ✅ **结算 UI 已交付**（S2.2/S2.3）：三态面板（借力成功 / 错过目标 / 信号中断）+ 重试 / 返回关卡选择 + 关卡选择与解锁存档；
  ⚠️ 但**手机 Web 导出尚未复测**（两轮真机问题已修：命中框 anchor、视口变化重建）。
- ⚠️ **关卡手感需真人试玩校准**（数据只能证明"可解"，不能证明"好玩"）。