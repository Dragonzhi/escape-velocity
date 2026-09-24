# 实施进度

> 状态只能根据**已观察到的证据**更新。写了代码 = 已实现；构建通过 = 构建通过；进程存活 = 运行时存活。它们都不能证明未测试的输入、状态转换、输赢流程、持久化、时序或视觉行为。
> 步骤定义见 [`PLAN.md`](./PLAN.md)，技术细节见 [`docs/开发手册.md`](../../docs/开发手册.md)。

## 当前阶段

**S2 关卡与结算已交付（S2.1 / S2.2 / S2.3 全部完成）**。S0、S1 全部完成；启动即进关卡选择，
结算三态面板 + 解锁制进度已落地并有运行时证据；**只差真机触屏验收**（Agent 无法注入 Touch）。
下一步 S3 视觉。

## 变更日志

### 会话 20 · 手机真机两处问题的根因与修复：视口尺寸变化没处理

**用户真机反馈（Web 导出在手机浏览器）**：「预览线又跑到别的地方了；竖屏情况下没有适配」，并建议「开发时把分辨率调竖屏」。

**根因**：所有几何（UI 层尺寸、触摸层尺寸、投影原点、相机宽高比）都在**启动时**读一次 `View.size` 就算死了；
而手机浏览器的画布尺寸在启动后还会变一次（地址栏/视口稳定、全屏切换等）⇒
容器的子坐标原点（= 位置 − anchor×尺寸）与新区域覆盖都还停在旧尺寸上：预测线整体偏移、新区域收不到触摸。
桌面端此前两次竖屏实测都是「先改成竖屏再启动」，所以没能暴露这个问题。

**修复**（`init.ts`）：

- 面板创建抽成 `buildPanels()`（可重复调用）；新增 `relayoutForViewport()`：
  隐藏旧面板与旧关卡运行时（**隐藏 + 断触摸，不销毁**）→ 更新 `viewW/viewH` →
  更新 `uiLayer` / `levelLayers[i]` 的 `size` → 重建面板 → 恢复当前状态（在关卡里则重建该关并回到 Aiming，否则回到选关）。
- 监听 `Director.entry.onAppChange(name === 'Size')` 触发重建；尺寸没变则直接返回。
- 新增开发工具 `tools/input-inject/set-window.ps1`（一键竖屏/横屏；客户区 400×710 → View.size 601×1066）。
  ⚠️ 该脚本必须 CRLF 换行：Windows PowerShell 5.1 的 here-string 在纯 LF 下解析失败（踩过）。

**验证（运行中改窗口 = 复现手机场景）**

- 日志：`started: 6 levels, unlocked=5, level select shown`（横屏 2192×1231）→ `viewport rebuilt: 601x1066`
  → `phase -> Aiming (L1)` / `enter L1 直飞`（点击用的是**竖屏坐标**，说明重建后的 UI 位置正确）。
- 截图人工查看：重建后的选关界面是 **2 列×3 行、六关全可见、底部提示归位** ✓；
  重建后进关的瞄准态：预测线**从探测器出发**笔直向上 ✓（修复前正是"跑到别的地方"）。
- 构建 36/36；临时诊断代码已全部移除。

**仍待真机复测**：Web 导出包在手机浏览器里重跑一遍（导出 → 手机打开 → 选关 → 拖 → 松手 → 结算）。

### 会话 19 · 竖屏（交付形态）实测：修掉两处布局溢出

**背景**：用户问「最后要交竖屏游戏，现在窗口还是横屏，有影响吗？」—— 影响确实有，而且是被绝对值的布局下限害的。

**实测方法**：用 Win32 MoveWindow 把引擎窗口改成竖屏手机比例（客户区 400×710），引擎渲染尺寸 View.size 随之变为 **601×1066**（= 客户区 ×1.5，引擎固定系数）；再用合成输入跑完整流程并截图（选关 / 瞄准 / 结算）。

**发现的两处溢出（有截图证据）**

| 位置 | 现象 | 原因 |
|---|---|---|
| 关卡选择 | **L6 被裁一半、底部提示「完成一关即解锁下一关」整条被挤出屏外** | 六关竖排：6×130 + 5×18 = 870 > 可用 636 |
| 结算面板 | **两个按钮横向戳出卡片外**（按钮 ≥560 vs 卡片 529） | 按钮宽写死 max(560, …) |

**修复**（game/Ui.ts + game/Hud.ts）

- 关卡选择：列数随宽高比自适应 —— **竖屏 2 列×3 行**、横屏 1 列×6 行；按钮尺寸由可用空间推算；headerH/footerH 改为视高比例（含夹紧），副标题与底部提示位置改为相对定位。
- 结算面板：按钮宽 = 卡片宽 − 60（去掉 560 硬下限）；卡片高于屏幕时先压按钮高度。
- MinButtonWidth/MinButtonHeight 从 560/130 降到 **160/72**（只保「小到点不中」的地板）。
- 手册 §5.7 第 10 条重写、新增第 13 条（View.size = 客户区 ×1.5）。

**验收证据（截图人工查看）**

- 竖屏 601×1066：选关 **2×3 全部可见**、底部提示归位 ✓；结算卡片居中、**按钮完全在卡片内** ✓；瞄准态预测线从探测器出发且正常弯曲 ✓。
- 横屏 2024×1231（回归）：选关单列六行全部可见 ✓；结算按钮在卡片内 ✓。
- 竖屏实跑闭环：点 L1 → 拖动 → phase -> Flying → **result = success（借力成功）** → 结算 ✓。
- 构建 36/36；提交后工作区 clean。

**仍待人工的设备侧验收**：Web 导出包在**手机浏览器**里的竖屏表现（本机只能模拟竖屏比例，真机的 DPR/视口与手指遮挡仍需一次实机确认）⇒ 设计分辨率待定项可关闭（布局已与分辨率解耦）。

### 会话 18 · 交互改为"相对拖动"，并修掉触摸命中框只有左下象限的问题（已修，双证据验收）

**用户新需求（2026-09-24）**：「按哪里都能瞄准；松手才发射；按下的时候预测线回到直飞，拖动才改变方向。」

**这一轮修了两件事**

#### 1）触摸命中框只剩"左下象限" —— "不是按哪里都能瞄"的真因

`createAimInput` 的根节点原本 `anchor=(0.5,0.5)`。节点的**子坐标原点是「位置 − anchor×尺寸」**，
于是整棵子树（含触摸层）被再推走半个屏幕：命中框只剩左下象限 ——
实测坐标可证：view x ≤ ~1012 与 y ≤ ~615 处按下有效，之外**完全无事件**（当时误以为是"多进程注入"问题）。

修复：`root.anchor = Vec2(0, 0)`（父层 `levelLayers[i]` 的子空间是"左下原点绝对像素"，
取 (0,0) 后命中框正好等于整屏，且 `touch.location` 与 `localToOffset` 的假设一致）。

**证据（六点网格实测，每点都重新进关）**

| 按点（view） | 结果 |
|---|---|
| (200,200) 左下 | `began view=199,199 local=199,199` |
| (1800,200) 右下 | `began view=1800,199 local=1800,199` |
| (200,1000) 左上 | `began view=199,1000 local=199,1000` |
| (1800,1000) 右上 | `began view=1800,1000 local=1800,1000` |
| (1012,615) 中心 | `began view=1011,615 local=1011,615` |
| (600,400) 偏左 | `began view=600,430 local=600,430` |

#### 2）瞄准语义改为"相对拖动（虚拟摇杆）"

旧模型：方向 =「探测器 → 手指」，力度 = 按下点到探测器的距离 —— 按下瞬间就已经按距离拿到力度，
方向也由按下点决定，手感与预期不符（用户原话："按下的地方也不是飞行器所在的地方"）。

新模型（手册 §5.7 已同步）：**按下点 = 摇杆零点**；按下瞬间瞄准归零到"直飞"（正对目标、最小力度）；
之后的**位移**决定方向与力度（位移方向 = 发射方向，长度 = 力度，夹紧 min/max）；松手才发射。
实现上复用 `computeAim`：把按下点当作它的 `probeOffset`；程序化缝隙 `handleOffset/handleLocal` 的参数
语义同步改为"相对按下点的位移"。

**证据（合成输入 + 截图 + 日志）**

- 按下不动（在 view≈(1350,675) 远离探测器处按住）：截图显示预测线**从探测器笔直向上**（直飞）✓
- 向右拖动：截图显示预测线**水平指向右侧**；日志 `ended unit=1.00,-0.00 power=1.00`（方向=右、力度满）✓
- 松手：日志 `phase -> Flying (L1)` ✓（松手才发射）
- 干净构建端到端（无诊断代码）：进关 → 拖动 → `phase -> Flying` → `result = missed` → `phase -> Result` ✓
- 单测：`SUMMARY passed=7 failed=0 total=7` ✓（`computeAim` 纯函数语义未变，HudTest 17 断言全过）

**工具链教训**：`.temp/` 下留过一份 `mousectl.ps1` 旧副本，参数不一致导致脚本**静默失败**
（报的是 `A parameter cannot be found`，但输出被 Out-Null 吞掉，白跑一轮）。旧副本已删除，
仓库版 `tools/input-inject/mousectl.ps1` 为唯一入口，并新增 `press/move/release` 与 `-HoldMs` 支持分段验证。

### 会话 17 · 预测线整体平移半个屏幕：绘制层的坐标空间变了（已修，视觉+单测双验收）

**用户真机反馈**：「线不是从飞行器位置发射出去的；鼠标按下的地方也不是飞行器所在的地方」——
会话 16 修好接线后暴露出来的第二个问题（当时拖动已能响应，只是画错了地方）。

**根因（用标记点实测出来的，不靠推**）**：S2.2 把 2D 层从"直接挂 `Director.ui`"改成"挂 `levelLayers[i]` / `uiLayer` 容器"，
**绘制层的坐标空间随之改变**：

- `project()` 输出 = **中心原点偏移**（+Y 向上）—— 瞄准数学与 `Trajectory` 都按这个约定写；
- 而 `levelLayers[i]`（`size=(W,H)`、`anchor=(0.5,0.5)`、`position=(0,0)`）的实际子空间是 **左下原点绝对像素 [0,W]×[0,H]**。

实测方法：在该层画 (0,0) / (W/2,H/2) / (W/2,H/2-530) 三个标记点后截图 ——
红点落在屏幕左下角、绿点落在正中心、黄点**正好压在探测器模型上**；而探测器投影值本身是 (0,-530)。
结论：预测线被整体平移 (+W/2, +H/2) 半个屏幕 —— 静止时整条线在画面外（截图里根本看不到线），拖动时才出现在错误位置。

**修复**：`game/Trajectory.ts` 的 `projectPolyline()` 增加**显式**的层原点参数 `originX/originY`；
`TrajectoryOptions` 增加 `layerOriginX/layerOriginY`（`defaultOptions()` 取半个 `View.size`，附实测依据）。
不再把"这一层是什么空间"当成隐式全局 —— S2.2 的错位正是这么来的。

**验收证据**

- **视觉**：`App.saveScreenshot` → PIL 转 PNG → 人工看图：预测线**从探测器出发**笔直向上 ✓（修复前同角度截图里没有线）。
- **单测**：新增回归断言 `layer-origin-is-half-view`（默认层原点必须等于半个视图）；TrajectoryTest 10 → **11** 断言；
  全套 `SUMMARY passed=7 failed=0 total=7` ✓。
  这条断言有判别力：第一版改动（读全局 `View.size` 而非显式参数）当场被 `basis-matches-project` 判失败，确认测试抓得住。
- **端到端**：点选关 → `phase -> Flying`（拖动松手）→ `result = missed` → `phase -> Result` ✓。

### 会话 16 · 真机"进关卡拖不动"的真正根因：瞄准层没接到状态机（已修，已自动验收）

**上一轮的结论是错的，如实纠正**：会话 15 判断为"S2.2 的全屏吞触摸层独占点击"，据此移除了两块全屏底板的
`touch: true` 并加了"隐藏即断触摸"的兜底。那些加固本身是对的（与引擎自身 UI 写法一致），但**不是这次故障的原因**。

**真正的根因**：`init.ts` 在 S2.2 重写时**漏掉了把瞄准层接到状态机的两行**。旧版（`7cb72b0`）里有
`aim.onDrag((a) => game.onAimDrag(a))` 与 `aim.onRelease((a) => game.launch(a.velocity))`，新版没有。
后果：触摸能到达瞄准层，但拖动不更新 `core.aim`（预测线不跟手）、松手也不发射 —— 玩家的感受就是"进关卡拖不动飞行器"。

**怎么找到的（新增能力：合成鼠标输入注入）**：Dora 的 `Touch` 同时代表鼠标点击，用 Win32 合成鼠标事件驱动窗口
即可复现真实触摸路径。先实测几何：`View.size = 2024×1230`（逻辑坐标，UI 用它），窗口客户区 1349×820，
`client_x = view_x·(clientW/2024)`、`client_y = (1230−view_y)·(clientH/1230)`。
随后在 `init.ts` 临时挂一层最顶层监听层（`swallowTouches=false`）记录每次触摸，并在瞄准层回调里打点 ——
一次拖动就同时拿到"事件是否到达"与"瞄准层是否收到"。

**证据（真实日志）**

- 修复前：`[aim] tapBegan enabled=Y nodeTouch=Y view=1011,480` → `[aim] tapEnded enabled=Y dragging=Y`，
  但**没有任何 `phase ->` 变化** —— 触摸到了、状态机没动（接线缺失的指纹）。
- 修复后（干净构建、已移除全部诊断代码）：点选关 `enter L1` → 拖动松手 `phase -> Flying (L1)` →
  `result = missed` / `phase -> Result` → 点「重试本关」`phase -> Aiming (L1)` →
  再拖再发射 `phase -> Flying (L1)` → `result = missed` / `phase -> Result`。

**新增工具（已入库）**：`tools/input-inject/mousectl.ps1` + README（坐标换算、常用点位、回归流程模板）。
触摸类改动不再必须人工点一次；真机多点触控/手势差异仍建议抽查。`AGENTS.md` 的验证章节同步更新。

### 会话 15 · 真机验收发现的触摸 bug：全屏"吞触摸层"独占点击（已修，待复测）

**用户真机反馈**：「进入关卡不能拖动飞行器了」。日志可见用户确实点进了 L1：
`built L1 L1 直飞 / phase -> Aiming (L1) / enter L1 直飞`（`log.txt` 21:51:08）—— 即**关卡能进、瞄准收不到触摸**。

**根因（代码定位）**：S2.2 给结算面板与关卡选择各加了一层**全屏、`touchEnabled + swallowTouches`** 的底板
（`createPanel(..., { touch: true })`），用意是"吞掉落在面板上的点击"。问题在于：

- 这两层在节点树里排在**瞄准层之后**（`init.ts` 先建 `levelLayers` 再建 `uiLayer`），全屏 + `swallowTouches`
  意味着它们会独占覆盖范围内的点击；
- `hide()` 只关 `visible`，**没有关 `touchEnabled`** —— 选关界面隐藏后仍参与命中，
  于是瞄准层永远收不到触摸，表现就是"进关卡拖不动"。
- 为什么之前没发现：探针用 `handleOffset` 程序化驱动瞄准，**完全绕过引擎命中判定**；
  `Touch` 是私有构造，无头注入不了真实触摸 —— 这正是"人工触摸验收"不可省的原因。

**修复（`game/Hud.ts`）**：两块全屏底板**都不再设 `touch: true`**（面板不需要代劳吞点击：
结算态瞄准层本就 `setEnabled(false)`，选关期间没有任何关卡处于 Aiming）；并做兜底 ——
`hide()` 里一并 `setEnabled(false)` 面板按钮/六个关卡按钮，任何"隐藏但仍命中"的行为都不会再吞掉拖动。

**已验证的证据**

- `node tools/dora-build/build.mjs --all` → **36/36 成功**；编译产物 `game/Hud.lua` 里
  `swallowTouches = true` **只剩瞄准层一处**（`touchEnabled` 写入也只剩瞄准层的创建与 `setEnabled`）——
  即全屏独占层已被彻底移除。
- 整项目 `POST /run init.lua` → `running=true`，日志 `started: 6 levels, unlocked=0, level select shown`，
  `POST /stop` → `running=false`（启动路径未破坏）。

**未验证**：真实触摸复测（需用户再点一次）——本次修复的判定依据是"移除全屏独占层"，
真实命中判定无法无头执行。
### 会话 14 · S2.2 结算面板 + S2.3 关卡选择与解锁进度

**已实现（源码）**

- `game/Ui.ts`（新）— 视图空间 2D 原语：`createPanel` / `createLabel` / `createButton`
  （自身即可点节点：底色 + 居中 Label + `touchEnabled`/`swallowTouches`/`onTapEnded` + 按下换底色）。
  配色、字体名、触屏下限（高 ≥ 130 / 宽 ≥ 560）集中在这个文件；颜色通道用除法而非位移运算。
  节点统一 `anchor = (0,0)`、局部绘制 `[0,w]×[0,h]` —— d.ts 没写明 anchor 与命中矩形的关系，
  `anchor = 0` 时两种解释重合，画出来的矩形与命中矩形必然一致。
- `game/Progress.ts`（新）— 解锁进度：`clampUnlocked` / `advanceUnlocked`（纯函数；只有 success 解锁，
  重玩旧关不回退）+ `loadProgress` / `saveProgress`（一行 `unlocked=N`，损坏即 0，**不抛错**）。
  ⚠️ 任务简报写的是 `App.writablePath`，但 v1.9.3 的 d.ts 里**只有** `Content.writablePath`，已按引擎声明改。
- `game/Hud.ts`（扩展，277 → 586 行）— `createResultPanel`（半透明全屏底 + 0.88 视宽卡片 +
  4 行内容 + `重试本关` / `返回关卡选择`）与 `createLevelSelect`（`选择任务` / `已解锁 N / 6` /
  六关竖排 / `完成一关即解锁下一关`；未解锁整块不可点）。
  **顺带修掉一个多关并存的真坑**：`AimInput.setEnabled` 现在同步 `touchLayer.touchEnabled` ——
  `swallowTouches` 的全屏层会独占触摸，未激活关卡的层会把整个屏幕的点击吞掉。
  （另注意 `onTap*` 注册时会把 `touchEnabled` 置回 true，初始关闭必须写在注册之后。）
- `game/Game.ts`（改）— `GamePhase` 增加 `'LevelSelect'`；新增 `coreBackToSelect`（**仅 Result 态**）
  与 `Game.backToSelect` / `Game.startLevel`。`coreLaunch`/`coreUpdate`/`coreRetry` 的语义未改。
- `init.ts`（改，129 → 266 行）— 启动即 LevelSelect；`ensureLevel(i)` **惰性**建每关运行时
  （`Node3D()` 容器 → `buildScene` → 相机/机架/轨迹/矄准 → `createGame`），切关只切 `visible`
  + `Director.pushCamera` + `startLevel`，**不销毁节点**；每关 2D 层先建、UI 叠层最后建
  （后建的画在上面 ⇒ 面板永远盖住轨迹线）；仍然只有一个 `threadLoop`，只驱动当前激活关。
- `Test/ProgressTest.ts`（新，36 断言）已加进 `Test/UnitRunner.lua` 的 modules；
  `Test/UiProbe.ts`（新运行时探针，5 张截图 + 文本化视觉判定）。

**已验证的证据**

- **编译（引擎）**：`Dora.exe cli build -p <proj>` → 69 个文件全部 `Compilation complete`；
  `[error]` **69 条全部**是 `Duplicate compiler file: lualib_bundle.lua`（已知噪音），
  TS 诊断 0 条（`nonLualibErrors=0`、`tsDiagnostics=0`）。本地 tstl 全量 36/36 通过。
- **单测**：`Test/UnitRunner.lua`（`POST /run`）标记文件 `.agent/test-results/unit-summary.txt`：
  `Test.ProgressTest :: passed | checks=36 failures=0`，`SUMMARY passed=7 failed=0 total=7`。
  覆盖：clamp 非法输入（NaN / ±Infinity / 负数 / 关卡数 0 / 非整数）、advanceUnlocked（success 解锁 /
  missed、crashed 不解锁 / 最后一关不越界 / 不回退）、存档往返（含垃圾内容、多行、越界夹紧，跑完还原）、
  `coreBackToSelect` 的 Aiming / Flying / Result / 重复调用四种相态。
- **运行时探针**（`Test/UiProbe.lua`，标记 `.agent/test-results/s22-ui.txt`）：`RESULT=PASS`，failures=0，
  5 张截图落盘（均为 2024×1230×4 = 9,958,098 字节）：
  `s22-result-success.tga` / `s22-result-missed.tga` / `s22-result-crashed.tga` /
  `s22-levelselect.tga`（任务要求的四张）+ `s22-nopanel.tga`（同机位对照帧），全部在
  `.agent/test-results/`。
  自动判定三条：截图可 TGA 解析；面板帧区域检测非 NONE（文字真的渲染了）；
  面板/选关帧平均亮度低于同机位无面板基线（24.3 / 21.1 < 26.2 ⇒ **面板确实画在场景与轨迹之上**）。
  报告里可直接读到卡片 bbox =(120,228)-(1908,996)、900×156 的主按钮亮块、
  6 个 828×~136 的关卡按钮、以及标题/副标题/说明行的连通域位置 —— 与布局计算逐项吻合。
- **关卡切换**（同一探针内）：照 `init.ts` 的调用序列再建第二关并 L1 → L2 → L1 切回，
  `switchProblems=0`，两关都回到 `Aiming`（覆盖“惰性建关 + visible / pushCamera / startLevel”这条真风险路径）。
- **整体入口**：`POST /run {file: init.lua, asProj: true, projectRoot: <proj>}` 运行约 7 秒无崩溃，
  日志三行：`progress file: %APPDATA%\IppClub\DoraSSR\escape-velocity.progress` /
  `progress loaded: unlocked=0` / `started: 6 levels, unlocked=0, level select shown`；
  `POST /stop` 后 `running=false`。
- **存档落盘**：`%APPDATA%\IppClub\DoraSSR\escape-velocity.progress`，10 字节，内容 `unlocked=0`
  （**在项目之外**，不污染仓库）。

**未验证**

- **真机触摸**：按钮点击与拖拽矄准的真实 `touch.location` 仍无实机标定（`Touch` 是私有构造，
  无头注入不可能）。探针走的是程序化调用路径，触摸坐标系仍需人工点一次（手册 §12 已记为待办）。
- **一次完整真人对局**（选关 → 拖 → 松手 → 飞行 → 结算 → 解锁 → 返回选关）未人工跑过；
  “success 解锁并写盘”目前由 `ProgressTest` 的纯函数断言 + `saveProgress`/`loadProgress` 往返守着，
  尚未在真实对局里贯穿。
- **视觉美观**：Agent 只能做几何/亮度层面的自检；卡片留白、字号、按钮配色需人工看图
  （`.agent/test-results/s22-*.tga` 需转 PNG）。

**下一步**：人工验收（转 PNG 看四张截图 + 真机点一次按钮）→ 关掉 S2 → 进 S3 视觉。

### 会话 13 · 工具链与通路（改用 DSH 接管开发）

**背景**：内置 Agent 的会话上下文已涨到 **40–52 万 tokens/请求**，其自动压缩（`[Memory] compression tool-calling attempt 1/5…3/5`）连续被服务端 524 掉（证据：引擎 `log.txt`）。开发方式改为**外部 Coding Agent（DSH）+ 引擎本体**：DSH 负责读写代码、编译、驱动引擎与验证，引擎只当运行时。

**已实现（工具链，均已实测）**

- **引擎 API 通路**：关掉引擎窗口设置里的「访问验证 / Auth Required」（`Script/Dev/Entry.lua:1026` 的 `HttpServer.authRequired`）后，8866 端口 API 无鉴权可用。实测：`POST /status` → 200；`POST /run`（项目入口）→ `running:true runId:3` 且日志出现 `game started: L1 直飞`；`POST /stop` 后 `run/status` → `running:false`；`POST /log` 可取引擎日志。
- **构建两条路**：① 引擎侧 `Dora.exe cli build -p .` → 全量 `Compiling … Compilation complete`，0 诊断（`[error] Duplicate compiler file: lualib_bundle.lua` 为已知噪音）；② 本地 tstl 工具（`build.mjs`，不依赖引擎与浏览器）。
- **本地构建标定**：**32/32 个文件与仓库已提交的 `.lua` 逐字节一致**（含 16 KB 的 `Test/Vision.lua`）。关键参数：`typescript-to-lua@1.37.1` + `typescript@5.9.3`（**必须 `npm i --legacy-peer-deps`；TS 6.0.2 会静默产出 `Math:sqrt(...)` 错码**）、`luaTarget=Lua55`、`luaLibImport=Require`、TAB 缩进、`luaExternalModules:['Dora']`；`-- [ts]: file` 与行尾 `-- <行号>` 标记属 IDE 后处理（已复刻）。
- **单测回归入口**：新增 `Test/UnitRunner.lua`（独立入口需显式 `require("Dora")`），批跑 6 个单测模块 → `.agent/test-results/unit-summary.txt`。**基线：6 模块 127 断言 0 失败**。
- **视觉验证**：引擎截图是未压缩 TGA（不支持直接读），改用 Python PIL 转 PNG 后由 DSH 原生看图；已实际查看 `s21-steady.tga`。
- **许可补齐（S4.4 提前完成）**：`LICENSE` 换为 gnu.org 官方全文（**34,523 B / 661 行，SHA256 双侧一致**）；版权通知移入 `README.md`，补作者 **Dragonzhi**、引擎版本、活动链接；已测设备填 **Web 浏览器**。
- **内置 Agent 提示词存档**：`.agent/dora-agent-prompts.md`（摘录 `DEFAULT_AGENT_PROMPT_PACK` 全文 + 工具与其余提示词位置索引）。附带发现：内置 Agent **其实支持 `/compact` 与 `/clear`**（`DoraAgent.ts:688`），只是界面没暴露。

**未验证 / 风险**

- 关闭「访问验证」后，同一局域网内其他设备也可无鉴权访问引擎 API（本机开发可接受，勿在不安全网络下长期关闭）。
- 本地构建工具目前在 `.temp/dora-build/`（gitignore 内），**尚未纳入仓库**；是否提升为 `tools/dora-build/` 待定。
- 引擎内置 tstl fork 的具体版本号无据可查，等价性由 32 个文件逐字节验证支撑。

**下一步**：S2.2 结算面板 + S2.3 关卡选择与解锁（进行中）。

### 会话 12 · 修复预测线垂直镜像（用户反馈）

**用户反馈**：“预测线渲染很奇怪，并不是一个准确的从探测器出发的线段。”

**根因（经多轮诊断定位）**：

- `View3D.getRayDirection` 的 viewPoint 是 **左下原点 +Y 向上**；
  S0.3（R4）标定时误判为“左上原点 +Y 向下”（中心点检验对 Y 翻转不敏感）。
- `project()` 继承了该镜像空间，`toOverlay()` 又“按图像坐标”多翻一次 y，
  ⇒ **所有 2D 覆盖层相对于真实渲染垂直镜像于屏幕中心**。
- 次要 bug：预测线只在拖动时重画，重试后相机 lerp 回矄准视图期间线会冻结在半途。

**诊断方法（严格实证，不靠猜）**：

1. `Test/ClearTest.ts` — 先排除“DrawNode.clear() 失效”假说（实测 clear() 正常）。
2. `Test/ProjCheckProbe.ts` — 对照我的 project() 输出与引擎 `getRayDirection`：
   射线完全一致（说明朝向正确），但用 `pick` 与截图位置对不上。
3. `Test/VerdictProbe.ts` — **颜色标记球最终裁决**：探测器染绿、火星染红、
   注视点放白球。结果：白球精确渲染在窗口中心（主点正确），
   而绿/红球与 project() 输出**恰好关于屏幕中心镜像** → 定案。

**修复**：

- `game/Projection.ts`：`toOverlay()` 改为恒等变换；头部约定改为“左下原点 +Y 向上”。
- `game/Trajectory.ts`：`projectPolyline` 不再翻转 y。
- `game/Hud.ts`：`localToOffset/offsetToLocal` 统一为 +Y 向上（`local.y - H/2`）；
  ⚠️ `computeAim` 的 `uy = -dy/len` **保留负号**（平面 y 轴与偏移 y 轴反向）。
- `game/Game.ts`：矄准态每帧重画预测线（不只在拖动时）。
- `Test/HudTest.ts`：坐标换算与方向断言按修正后语义更新。

**已验证的证据**：

- **编译**：全量 `build` 33/33 通过。
- **单测**：`TrajectoryTest` 10、`HudTest` 17、`GameTest` 30、`LevelDataTest` 34 —— 全过。
- **运行时**：`LineDirProbe` 两张 ASCII 图显示预测线现在**从探测器（屏幕下方）
  朝目标（上方）延伸**；`GameProbe` 完整循环 `RESULT=PASS`；
  `init.ts` 加载 L1 运行 3 秒干净退出。
- **副收获**：修正后屏幕方向语义 = 世界 +z（靠近相机）在屏幕**下方**
  （与真实相机一致，近景在画面下方）。游戏里探测器在下方、目标在上方，向上发射。

**待办**：S2.2 结算三态面板、S2.3 关卡选择与解锁进度。

### 会话 11 · S2.1 六关数据与目标判定

**已实现（源码）**

- `game/LevelData.ts`（227 行，纯数据 + 纯函数，不 import 'Dora'）：
  - 六关完整定义（愿景 §5 定稿曲线，每关只引入一个新旋钮）：
    1 直飞（无引力）/ 2 第一次弯曲 / 3 从背后抄过去（必须借力）/
    4 它动了（公转+时机）/ 5 两连弹 / 6 贴着过去（容差收窄）
  - 每关含：任务简报（金唱片/1977 风味）、行星物理+视觉、目标规格、边界与步数
  - `findGoalIndex` — 飞行采样点中找第一个进入目标容差的索引
    （目标行星移动时逐点用 t 时刻位置判定）
  - `scaledPlanets` / `getLevel` / `levelCount`
- `game/Game.ts` — 目标判定接入：
  - `resolveResult(outcome, goalIndex, goal)` 替代 `resolveOutcome`
    （优先级：到达目标 > 逃逸达成 > 撞毁 > 错过）
  - **结算在发射瞬间即完全确定**（轨迹+goalIndex+outcome 都已知）
  - 到达目标后飞行在到达点截断；回放时间吸附到终点（冻结帧停在到达瞬间）
- `init.ts` — 从 LevelData 加载第一关（S2.3 接入关卡选择）
- `Test/GameTest.ts` 扩到 30 断言；新增 `Test/LevelDataTest.ts`（34 断言）

**已验证的证据**

- **编译**：全量 `build` 28/28 通过。
- **单测**：`GameTest` = `passed checks=30`；`LevelDataTest` = `passed checks=34`
  （结构有效性、容差>半径、findGoalIndex 静止/移动目标、**每关可玩性硬门**）。
- **入口**：`init.ts` 加载 `L1 直飞` 运行 3 秒干净退出。

**调参过程（数据驱动）**

- 初版可玩性扫掠（轴向 5×5 网格）报 L3/L5 不可达 → 诊断扫掠发现两关其实
  各有 6 个成功解，只是解在斜向速度上（如 v=(-16,-14)）→ **测试扫掠改为
  角度×力度采样（12 方向 × 4 档）**，真实覆盖玩家连续输入空间。
- 回放每帧跳 4 个索引会越过 goalIndex → 收束时吸附 `flightTime = endIdx * dt`。

**未验证 / 待办**

- S2.2 结算三态面板（当前仍是最小 Label）。
- S2.3 关卡选择与解锁进度（含持久化）。
- 关卡手感（难度曲线）需真人试玩校准。

### 会话 10 · S1.5 状态机与主循环（S1 完成）

**已实现（源码）**

- `game/Game.ts`（280 行）— 状态机 + 主循环逻辑：
  - `GameCore`（纯逻辑可单测）：`coreLaunch`（发射时预推演整段飞行）/
    `coreUpdate`（回放推进 + 结局判定）/ `coreRetry` / `coreProbeIndex`
  - `resolveOutcome` — 物理结局 → 三态（§5.8 的 S1 简化版：escaped=success）
  - `createGame(level, deps)` — 驱动场景/相机/轨迹/矄准，回调 `onPhase`/`onResult`
  - **确定性设计**：发射瞬间用与预测线相同的 `simulate` 预推演，之后逐帧回放
    → “预测线看见的就是飞出来的”
- `init.ts` — 从 S0 静态场景改为**真实游戏入口**：组装全部模块 + 单一 `threadLoop`
  + 结果 Label + 重试点按层（仅 Result 态启用）
- `game/Config.ts` — 新增 `FlightPlayback=2`（回放速度）
- `Test/GameTest.ts`（22 断言）、`Test/GameProbe.ts`（完整循环探针）

**已验证的证据**

- **编译**：全量 `build` 26/26 通过。
- **单测**：`Test/GameTest.ts` → `passed checks=22 failures=0`
  （结局映射、发射守卫、回放时长与 FlightPlayback 一致、重试守卫与重置、
  索引夹紧、两次完整流程结局一致）。
- **运行时（`Test/GameProbe.ts`）**：完整循环 `RESULT=PASS`：
  - 拖拽 → `power=1.000`、`vel=(12.09,-18.38)` → 预测线可见（ASCII 图弯曲亮线）
  - 发射 @f20 → Flying → 飞行 6.2s（1500 步回放）→ `Result(missed)` @f395
  - 重试 @f406 → 回到 `Aiming` ✓
- **真实入口**：`init.ts` 运行 3 秒 `running=true`，`stopEntry()` 后干净退出。

**踩到的坑（本次新增）**

- **`threadLoop` 回调没有参数**：帧间隔要用 `App.deltaTime`（签名是 `(this: void) => boolean`）。
- **增量构建再次未转译 `Config.lua`**：新增 `FlightPlayback` 后运行时 nil → 全量重建解决。
- 探针脚本自身两个 bug：分析块门条件用了未赋值的 `retryFrame`（导致重试前就终止）、
  `App.elapsedTime` 在此环境恒为 0（改用帧号）。

**局限（如实记录）**

- 真实触摸的“松手发射”与“点按重试”无法无头验证（`Touch` 私有构造），
  需人工校对（与 S1.4 同一校准点 `localToOffset`）。
- 结算 UI 是最小版（一个 Label）；正式三态面板与“返回关卡选择”在 S2.2/S2.3。

### 会话 9 · S1.4 拖拽矄准与发射

**已实现（源码）**

- `game/Hud.ts`（273 行）— 拖拽矄准：
  - `computeAim(probeOffset, touchOffset, maxDragPx)` — 纯计算：方向 = 探测器→触摸点，
    力度 = 拖动距离/满力距离（夹紧），速度线性映射 [AimMinSpeed, AimMaxSpeed]
  - `localToOffset` / `offsetToLocal` — 全屏节点局部坐标 ↔ 投影偏移空间换算
  - `createAimInput(parent, viewW, viewH)` — 全屏触摸层 + `onDrag`/`onRelease`/`setEnabled`
  - `handleLocal` / `handleOffset` — 输入源可替换的缝隙（键盘降级/回放/无头测试）
- `game/Config.ts` — 新增 `AimMinSpeed=2` / `AimMaxSpeed=22` / `AimMaxDragPx=380`
- `game/Projection.ts` — 新增 `screenToPlaneY`（射线与 y=0 平面求交）
- `Test/HudTest.ts`（17 断言）、`Test/HudProbe.ts`（运行时链路探针）

**已验证的证据**

- **编译**：全量 `build` 通过。
- **单测**：`Test/HudTest.ts` → `passed checks=17 failures=0`
  （无拖动默认值、四方向语义、力度线性/夹紧/单调、投影往返、坐标换算互逆）。
- **运行时（`Test/HudProbe.ts`）**：
  - 驱动一次拖拽：`power=0.692`、`unit=(0.152, -0.988)`、`velocity=(2.41, -15.66)`
  - 该向量推演 → `outcome=crashed points=25`（直冲行星，物理正确）
  - 预测线在画面中可见（6 个区域，从探测器延伸向行星）

**关键设计修正（本次自查发现）**

初版把“探测器屏幕位置”（`project()` 输出 = **相对屏幕中心的偏移**）
与“触摸位置”（换算后 = **绝对像素**）直接相减 —— 两个空间不一致，方向会算错。
已统一为**投影偏移空间**（中心原点、+Y 向下），换算集中在 `localToOffset()`。

**局限（如实记录）**

- `Touch` 是私有构造，**无法**程序化注入真触摸事件 → 真实触摸的坐标系
  （`touch.location` 的原点/Y 方向）需一次人工校对；`localToOffset` 是唯一校准点。
- `onRelease` 回调只能由真触摸结束触发，无头环境无法验证（代码路径已由单测覆盖计算部分）。

### 会话 8 · S1.3 轨迹渲染（预测线 + 真实尾迹）

**已实现（源码）**

- `game/Trajectory.ts`（172 行）— 轨迹渲染：
  - `projectPolyline(points, y, basis)` — 批量把平面采样点投影到 2D 覆盖层坐标
  - `decimate(points, maxPoints)` — 均匀抽稀（保留首尾），控制移动端开销
  - `createTrajectoryView(parent, opts)` — 返回 `setPrediction` / `clearPrediction` / `setTrail` / `clearTrail`
  - 用 `DrawNode.drawSegment` + `drawDot`（圆头）而非 `Line`，因为 `Line` 线宽不可控
- `game/Projection.ts` — 新增 `prepareCamera` / `projectPrepared`（预计算相机基，避免每帧重算数百次）
- `Test/TrajectoryTest.ts`（10 断言）、`Test/TrajectoryProbe.ts`（运行时探针）

**已验证的证据**

- **编译**：全量 `build` 19/19 通过。
- **单测**：`Test/TrajectoryTest.ts` → `passed checks=10 failures=0`，
  含“预测线与尾迹逐点相同”（核心约束）、“预计算基与 project() 降为 float32 后逐位一致”。
- **运行时（`Test/TrajectoryProbe.ts`）**：轨迹在画面中清晰可见：
  - 区域检测从 **11 个 → 40+ 个**（改用 DrawNode 后）
  - 亮像素占比 **0.07% → 0.30%**
  - ASCII 图呈现“从上方下行、随引力向左弯曲”的曲线，符合物理推演

**踩到的坑**

- **`Director.entry` 是 `View3D`，不能挂 2D 绘制节点** → 轨迹必须挂在 `Director.ui`。
- **`Line` 线宽不可控**（约 1px），在 1080p 下几乎不可见 → 改用 `DrawNode.drawSegment`。
- **`Vec2` 是 float32**（引擎 C++ 类型），与 float64 普通对象比较会有 ~1e-8 相对误差。
- **增量构建有时不重新转译**：全量 `build` 报告成功但 `.lua` 未更新。需改一次 `.ts` 强制重编。

**未验证 / 待办**

- 轨迹尚未接入拖拽瞄准（S1.4）与主循环（S1.5）。

### 会话 7 · S1.2 场景与相机跟随

**已实现（源码）**

- `game/Scene.ts`（180 行）— 3D 场景搭建：
  - `planeToWorld(p, y)` — 平面坐标 → 世界坐标（y=0）
  - `buildScene(options)` — 方向光 + 行星（同资产染色/缩放）+ 土星环 + 探测器
  - 行星靠 `Model3D(path).getMaterial(0).baseColor` **逐实例染色**，靠 `scale` 区分大小
  - 返回 `GameScene`（`syncBodies` / `syncProbe` / `faceVelocity` / `probe` / `planets`）
- `game/CameraRig.ts`（174 行）— 单一相机 + 动态跟随（D3）：
  - `computeFit(points)` — 关键点包围盒中心 + 半对角
  - `computeRigStep(state, points, opts)` — 纯计算，不碰引擎对象
  - `createCameraRig` / `defaultRigOptions`（tilt=45, dist 25–100, lerp=0.1, fitFactor=1.6）

**已验证的证据**

- **编译**：全量 `build` 17/17 通过。
- **单测（纯逻辑）**：`Test/CameraRigTest.ts` → `passed checks=11 failures=0`
  （fit 计算、距离单调性、夹紧、倾角、平滑）。
- **运行时（`Test/SceneProbe.ts`）**：
  - `stats: draws=4 visible=4 triangles=260`（2 球 + 1 环 + 1 探测器）
  - 相机跟随：`rig distance range over flight: min=53.95 max=82.55`，`camera pulled back=true`
  - 视觉：Agent 用 `Test/Vision.ts` 自检初始帧与后期帧，两帧均检出物体
- **设计修正（有实测依据）**：初版相机用“探测器到目标的距离”作依据，
  但探测器会**飞过**目标，该距离非单调 → 实测 `first=50.41 last=48.31`（相机反而拉近）。
  改为“**关键点包围盒半对角**”后单调（`min=53.95 max=82.55`）。

**已踩并记录到手册 §7.2.1 的三个坑**

1. **对象成员函数默认带 self**：interface 成员函数生成 `obj:method(arg)` 冒号调用，
   把 `obj` 当第一个参数 → 运行时报 “field 'x' is nil”。**编译期不报错**。
   解法：`/** @noSelf **/`（用属性式函数类型**无效**）。
2. **`threadLoop` 返回值易搞反**：返回 `false` 继续、`true` 停止。
   写了 `return frame < 600` → 第 1 帧就停，看起来像“卡住”。
3. **工厂命名空间不能当类型**：用 `Vec3.Type` / `Node3D.Type`，不能写 `Vec3` / `Node3D`。

**未验证 / 待办**

- `Scene` / `CameraRig` 尚未接入完整主循环（S1.5）。
- 轨迹绘制未开始（S1.3）。

### 会话 6 · S1.1 物理内核（确定性）

**已实现（源码）**

- `game/Gravity.ts`（253 行，**零引擎依赖**，不 import 'Dora'）：
  - 类型：`P2` / `Body` / `ProbeState` / `SimOptions` / `SimResult` / `Outcome`
  - 函数：`bodyPositionAt`（公转）、`accelerationAt`（平方反比）、`step`（半隐式欧拉）、
    `collisionIndex`（撞毁）、`simulate`（**预测与真实共用**的推演）、
    `orbitalSpeed`、`applyScales`、`sub`/`length`/`distance`
- `Test/GravityTest.ts` — 10 组 / 25 项断言，首行输出 `passed`/`failed`，
  用 `requireProjectModule("Test.GravityTest")` 加载，**无需运行场景**。

**已验证的证据**

- **编译**：`game/Gravity.ts` 与 `Test/GravityTest.ts` 均通过（1/1）。
- **单测**：`checks=25 failures=0` → `passed`。
- **确定性（验收硬指标）**：同一输入连跑 5 次，轨迹 101 个采样点 **逐位相同**（bit-exact）。
- **物理正确性交叉验证**：`a(1)=100.0000`（= `gm/r²`）；`a(1)/a(2)=4.0`、`a(1)/a(4)=16.0`（平方反比）；
  圆轨道漂移 **0.000%**。
- **测试判别力（防止恒真测试）**：故意把平方反比改成线性（`invd3 → invd`），
  测试立即报 `failed failures=4`（`inverse-square`、`circular-orbit-radius`、`escape-detected`、`gravity-pulls-inward`）；
  已撤销并重跑确认 `passed`。
  - 额外发现：注入缺陷时 `determinism` **依然通过** → 确定性测试与物理正确性测试是**互补**的两类证据。

**未验证 / 待办**

- `Gravity.ts` 尚未接入渲染与玩法（S1.2–S1.5）。

### 会话 5 · 文本化视觉验证 + 关闭 R3（竖屏相机）

**背景**：用户要求优先解决“Agent 无法看图片”的问题。

**已实现（源码）**

- `Test/Vision.ts` — **文本化视觉验证工具库**：
  - 原理：`App.saveScreenshot` 输出未压缩 TGA（`type=2`，24/32bpp）；入口是引擎脚本，
    不受命令沙箱的“二进制不可读”限制，可用 `Content.load` 读字节并在引擎内解码。
  - 输出：ASCII 灰阶图 + 亮度直方图 + **列剖面** + 连通域区域检测。
  - API：`parseTga` / `luminanceAt` / `rgbAt` / `detectRegions` / `asciiMap` / `buildReport` / `captureReport`。
- `Test/VisionProbe.ts` — 视觉验证自检。
- `Test/CameraProbe.ts` — 竖屏相机覆盖计算（R3）。
- `game/Config.ts` — 补入平面→世界映射常量、相机倾角/距离安全区间。

**已验证的证据**

- **视觉工具判定力（实测）**：三物体放在 x=-6.5/0/+6.5 → 工具输出 `horizontal segments: 3`，
  三个 bbox 的 centroid 归一化 x = 0.091 / 0.498 / 0.881，与预期位置精确对应。
- **踩坑与修正（已写入代码注释）**：
  1. `saveScreenshot` 是**异步落盘**。第一次只请求后立即读，拿到的是**陈旧截图**
     （图像与上一次逐字节相同）。正确做法是“请求 → 隔几帧 → 读取”。
  2. 截图约 10 MB（2024×1230×4），**不能**把像素物化成 Lua 数组（实测失败），必须步长采样。
- **R3 关闭（决定性数据）**：用已标定的投影模块（误差 1px）对竖屏宽高比 0.5625 计算 NDC：

| 轨道朝向 | dist=30/tilt=45 时的 maxNdcX / maxNdcY | 结论 |
|---|---|---|
| 横向（沿世界 X） | 1.50 / 0.32 | ❌ 超出 1.5 倍，被裁 |
| 纵向（沿世界 Z） | 0.72 / 0.65 | ✅ 完整可见 |

  - 横向轨道需 `dist ≥ 50` 才装得下；纵向轨道 `dist ≥ 25` 即可。
  - tilt 安全区间：20–60°（maxNdcY 0.34–0.74）；>70° 贴边（≥0.86）。
  - ⇒ **物理平面必须沿屏幕纵向（世界 Z）展开**，已写入 `Config.ts` 与手册 §5.1。

**未验证 / 待办**

- 工具**不能**判断美观/可读性/手感 —— 仍需人工。
- S0.6（R6 包体积 17 MB）用户已决定暂不处理。



**背景**：用户反馈“运行游戏没有任何东西显示”。排查确认：**不是 bug，是 `init.ts` 本来就是空壳**（只有 `// @preview-file on clear` + `import {} from 'Dora'`）。

**已实现（源码）**

- `init.ts` — 从空壳改为**真实 3D 场景**（79 行）：相机、方向光、球体×2、土星环、探测器四面体，缓慢自转。既解决“看不到东西”，又充当 R1 的验证载体。

**已验证的证据**

- **编译**：`init.ts` 构建通过（1/1）。
- **运行时**：`enterEntryAsync("init.ts")` 运行 4 秒，日志输出 `[escape-velocity] draws=4 visible=4 triangles=260 view=2024x1230`；`stopEntry()` 后 `running=false`。`draws=4` ↔ 4 个模型；`triangles=260` ↔ 120×2 + 16 + 4，与网格面数完全吻合。
- **视觉（引擎内）**：截图 `.agent/vision/1790223969-446514564.png`（2024×1230）已生成，但 Agent 无图像分析工具，`visual: not_run`。
- **🔴 R1 关闭（用户实测，决定性证据）**：用 Web IDE 的「导出 HTML」，**浏览器内能看到 3 个 3D 物体**。
  - 意义：**Web 导出不需要从源码编译引擎**，也不需要本地装 Emscripten/Rust/Go 工具链。先前探测到的源码仓库缺失、`EMSDK` 未设置、无外壳能力等问题**全部不构成阻塞**。
  - 手册 §11 中 R1 的“退回 2D”回退方案**不触发**。
- **🚨 R6 缺口（用户实测）**：导出包体 **17 MB**，超 8 MB 目标。
  - 分析：包体由引擎 WASM 运行时主导，减小项目资产（三个 glTF 合计约 8 KB）几乎无影响。
  - 可能路径：① 确认“8 MB”是原始体积还是压缩后；WASM 压缩比通常 3–4 倍，17 MB 压缩后可能落入预算；② 源码构建时用 `DORA_WEB_PROFILE=core|custom` 裁剪功能。

**未验证 / 待办**

- S0.4（竖屏相机 R3）未开始。
- R6 口径与裁剪方案待定。



**背景**：`Line` 只能画 2D，而轨迹线（全场最重要视觉）需要画在 2D 覆盖层；`View3D` 无 world→screen 投影。

**已实现（源码）**

- `game/Projection.ts` — 纯函数投影模块：`project()`（世界→屏幕）、`unprojectDirection()`、已标定常量 `HANDEDNESS=1` / `FLIP_Y=false`、`toOverlay()`。
- `Test/ProjectionProbe.ts` — 自标定 + 回归测试。

**已验证的证据**

- **编译**：`game/Projection.ts` 与 `Test/ProjectionProbe.ts` 均通过（1/1）。
- **标定方法（排除猜测）**：`getRayDirection(viewPoint)` 的真值特性是“对已知世界点搜索方向点积最大的屏幕位置”。先用一个非对称相机（eye=(3,4,8)）验证：正确的 `viewPoint` 空间是 **像素坐标、原点在左上角（`[0,W]×[0,H]`，+Y 向下）**，手性 `right = cross(forward, up)`；而 `dot(getRayDirection(p), f)` 在 (1012, 614) 处为 1.000000 —— 正是 `View.size/2`。
- **投影精度（R4 关闭的决定性证据）**：回归测试 `Test/ProjectionProbe.ts` 反复输出 `RESULT=PASS`，实测：

| 世界点 | 真实屏幕位置 | 自建投影 | 误差 |
|---|---|---|---|
| 原点 | (1012, 614) | (1012.0, 615.0) | 1.00 px |
| +x (4,0,0) | (1694, 506) | (1693.3, 506.7) | 0.96 px |
| -x (-4,0,0) | (492, 698) | (492.6, 697.6) | 0.72 px |
| +y (0,3,0) | (1012, 1110) | (1012.0, 1109.2) | 0.75 px |
| -y (0,-3,0) | (1012, 238) | (1012.0, 238.2) | 0.20 px |

  最大误差 **1.00 px**（2024×1230，约 0.05%）→ **R4 关闭**。
- 早前的两种错误途径已排除并记录：`getRayOrigin` 返回的不是视点（相差 0.16），且射线不能直接反推相机基。

**未验证 / 待办**

- S0.4（竖屏相机 R3）、S0.5（Web 3D R1）、S0.6（包体积 R6）未开始。
- 投影模块尚未接入实际轨迹渲染（S1.3 再做）。



**背景**：用户启用互联网工具后，实测取物不可用：

- `fetch_url` 对 `raw.githubusercontent.com`、`cdn.jsdelivr.net`、`www.gnu.org` 三个域名均报 `failed to move downloaded file into target path`；引擎日志显示 `being used by another process`，且落盘文件经 `Content:load` 验证均为 **0 字节**。
- `git clone https://github.com/octocat/Hello-World.git` 报 `wsarecv: ... connected host has failed to respond`（超时）。
- 命令模式下的 `Content` 被沙箱限制：仅允许项目内路径，且无 `save`/`searchPaths`/`writablePath`；写文件必须通过入口（`enterEntryAsync`）。

**已实现（源码 + 资产）**

- `Test/gen_shapes.lua` — 离线几何生成器（Lua `string.pack` + 手写 base64），构建通过。
- `Assets/Model/Sphere.gltf` — 单位球（SEG=12/RING=6），61 顶点 / 120 面，base64 内嵌 2208 B buffer。
- `Assets/Model/Ring.gltf` — 扁平圆环（1.35/2.0，8 段，双面），16 顶点 / 16 面。
- `Assets/Model/Probe.gltf` — 正四面体探测器（指向 +X），12 顶点 / 4 面。
- `Test/Smoke.ts` — S0 资产加载冒烟测试（`Model3D` 加载三个资产 + `view.stats` 判定），构建通过。
- `docs/开发手册.md` §5.9/§8.1/§11/§12/§13 已同步离线资产方案、编译产物与源码同目录的注意项、R8（取物不可用）。

**已验证的证据**

- **编译**：`build` 全绿，4/4 文件（`init.ts`、`game/Config.ts`、`Test/Smoke.ts`、`Test/gen_shapes.lua`），无诊断。
- **数据正确性**：在引擎内重新计算三个网格的顶点/法线/索引并 base64 编码，与文件内容**逐字符比对全部 `MATCH=true`**（Sphere 2944、Ring 640、Probe 416 字符）。
- **运行时（已达成）**：入口释放后运行 `Test/Smoke.ts`，标记文件内容为 `status=PASS draws=3 visible=3 triangles=140 missing=`；`stopEntry()` 后 `success=true running=false`。
  - `draws=3` ↔ 三个资产各一次绘制；`triangles=140` ↔ 120+16+4，与三个网格面数精确吻合 → **`Model3D` 能加载并渲染自产 glTF**（关闭 R2 与 S0.1/S0.7）。
- **视觉**：截图已捕获（`.agent/vision/1790222441-939253569.png`，40 KB，2024×1230），但当前无图像分析工具（`read_file` 拒读二进制），**未由 Agent 目视确认** → `visual: not_run`，需人工查看。

**未验证 / 待办**

- S0.3（投影 R4）、S0.4（竖屏相机 R3）、S0.5（Web 3D R1）、S0.6（包体积 R6）均未开始。

### 会话 1 · 骨架初始化

**已实现（源码 + 文档）**

- `docs/开发手册.md` — 开发手册（决策 D1–D7、架构、物理/相机/轨迹方案、参数表、编码规范、构建与 Web 导出、验收标准与证据分级、裸测清单）。
- `README.md` — 项目入口说明与文档索引。
- `LICENSE` — AGPL-3.0 **通知头 + TODO 说明**（官方全文待补）。
- `.gitignore` — 忽略构建产物、Agent 运行时产物、临时目录。
- `Assets/.gitkeep`、`Test/.gitkeep` — 目录占位。
- `game/Config.ts` — 全局常量与调参表初版。
- `.agent/plan/PLAN.md`、`.agent/plan/PROGRESS.md` — 计划与进度。

**已验证的证据**

- 仓库基线：`git status` 显示工作区仅有 `init.ts` 与 `单程-项目愿景.md` 为未跟踪；`glob` 确认根目录只有这两个文件。
- 能力核实（读文档，非运行证据）：3D 栈存在（`Camera3D`/`Node3D`/`Model3D`/`DirectionalLight3D`/`Surface3D`/`Body3D`/`Shader`/`RenderTarget`）；TS 层**无**程序化几何工厂；`Line` 为 2D `Vec2[]`；`View3D` 无 world→screen 投影；Web 构建 `DORA_WEB_FEATURE_MODEL_3D` **默认 OFF**。
- `build`：`game/Config.ts` 与 `init.ts` 通过（2/2，`failed: 0`）。

## 阻塞项

1. 无硬阻塞。
2. **视觉验收需人工参与**：Agent 侧无图像分析工具，`Test/Smoke.ts` 的截图需人工查看确认造型与层级。
3. 外部素材取物不可用（R8），但不阻塞（改走代码生成）。

## 下一步

1. 人工查看 `.agent/vision/1790222441-939253569.png`，确认球 / 环 / 四面体造型与光影正常。
2. S0.3（投影 R4）→ S0.4（竖屏相机 R3）→ S0.5（Web 3D R1）→ S0.6（包体积 R6）。
