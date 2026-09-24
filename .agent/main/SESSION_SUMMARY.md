# Session Summary

### Current Goal

《单程》Escape Velocity：**S2 已交付，并修完两轮真机问题**（会话 15–20）——
S2.1 六关数据 / S2.2 结算三态面板 / S2.3 关卡选择与解锁进度；随后真机反馈的三件事全部修好并有证据：
① 瞄准层没接到状态机（“进关卡拖不动”的真根因）、② 交互改为**相对拖动**且修掉触摸命中框只剩左下象限、
③ **视口尺寸变化整体重建**（手机浏览器“预测线跑偏 / 竖屏没适配”的根因）。
**下一步 S3 视觉**（星球与土星环造型、轨迹发光与星空、金唱片开场与关间简报、可选粒子/后处理）。
**唯一开放的真机项**：修复后的 Web 导出包在**手机浏览器**上重跑一遍（选关 → 拖 → 松手 → 结算）。
开发方式：DSH（外部 Coding Agent）接管读写/编译/驱动/验证，引擎只当运行时；工具链见 `PROGRESS.md` 会话 13 与 `PROJECT_MEMORY.md` §Build And Run。

### Milestone Ledger (S0 · 已提交 `89be60e`)

- **S0.1 3D 资产** — `Test/gen_shapes.lua` 生成自包含 glTF（Sphere 61v/120f、Ring 16/16、Probe 12/4），base64 重算 `MATCH=true` → **PASS**
- **S0.2 R2 资产加载** — `Test/Smoke.ts` → `status=PASS draws=3 visible=3 triangles=140` → **PASS**
- **S0.3 R4 投影** — `game/Projection.ts` 标定，`Test/ProjectionProbe.ts` = `RESULT=PASS`，最大误差 **1.00 px** → **PASS**（⚠️ Y 轴约定已在 S2 修正）
- **S0.4 R3 竖屏相机** — 纵向轨道 NDC 完整可见；横向 `maxNdcX=1.50` 被裁 → 平面沿世界 Z 展开 → **PASS**
- **S0.5 R1 Web 3D** — Web IDE「导出 HTML」→ 浏览器内可见 3 个 3D 物体（**用户实机**）→ **PASS**
- **S0.6 R6 包体积** — 实测 **17 MB** > 8 MB → **DEFERRED**（用户决定暂不处理）
- **S0.7 冒烟 / S0.8 视觉确认** → **PASS**

### Milestone Ledger (S1)

- **S1.1 物理内核** — `game/Gravity.ts`（零引擎依赖）+ `GravityTest` 25 断言；101 点逐位一致；已提交 `ed29f75` → **PASS**
- **S1.2 场景与相机** — `game/Scene.ts` + `game/CameraRig.ts`；`draws=4 triangles=260`；相机跟随 `min=53.95 max=82.55`；已提交 `94b77af` → **PASS**
- **S1.3 轨迹渲染** — `game/Trajectory.ts`；`TrajectoryTest` 10 断言；运行时区域检测 40+、亮像素 0.30%（初版 `Line` 仅 11 区域 / 0.07% → 改 `DrawNode`）；已提交 `eb75f07` → **PASS**
- **S1.4 拖拽瞄准** — `game/Hud.ts`；`HudTest` 17 断言；运行时 `power=0.692 unit=(0.152,-0.988) vel=(2.41,-15.66)` → 预测线可见；真触摸坐标系待人工校对；已提交 `3205cb8` → **PASS**
- **S1.5 状态机与主循环** — `game/Game.ts` + `init.ts`；`GameTest` 22 断言；`GameProbe` 完整循环 `RESULT=PASS`；已提交 `4125b1a` → **PASS**

### Milestone Ledger (S2)

- **S2.1 六关数据与目标判定** — `game/LevelData.ts`（六关 + `findGoalIndex`）；`resolveResult` 接入 Game；`GameTest` 30 + `LevelDataTest` 34（含每关可玩性硬门）；已提交 `9d080b6` → **PASS**
- **🔴 预测线垂直镜像修复（用户反馈）** — 已提交 `7cb72b0` → **PASS**（详见下）
- **S2.2 结算三态面板 / S2.3 关卡选择与解锁** — `game/Ui.ts` + `game/Hud.ts`（`createResultPanel` / `createLevelSelect`）+ `game/Progress.ts`（解锁纯函数 + `Content.writablePath` 存档）+ `Game` 的 `LevelSelect` 相态与 `coreBackToSelect`/`startLevel` + `init.ts` 启动即选关、惰性建关；`UiProbe` = `RESULT=PASS`（三态 + 选关截图人工查看）；`ProgressTest` 36 断言；已提交 `4033e09` → **PASS**
- **会话 15–20 · 真机问题三连修**（每项都有截图/日志/单测证据）→ **PASS**：
  1. `09645a5` 瞄准层没接到状态机（“进关卡拖不动”的**真根因**；会话 15 的“全屏吞触摸层”判断被如实纠正）；
  2. `bd12af8` 交互改**相对拖动**（按下 = 摇杆零点 → 直飞；位移决定方向/力度；松手才发射）+ 触摸命中框 `anchor` 改 `(0,0)`（六点网格实测）；
  3. `238cc95` 预测线整体平移半屏（投影输出空间 ≠ 绘制层空间，层原点显式传参）；
  4. `21a5c78` 竖屏（601×1066）布局溢出修复（选关 2 列×3 行、结算按钮不出卡片）；
  5. `31cba6e` **视口变化整体重建**（`onAppChange === 'Size'`）+ `set-window.ps1` 竖屏窗口；
  6. `e62c07d`/`4c160f9`/`283e9cb`/`138e6ce` 清理残留诊断、启动日志带视口与平台、守则补“提交前必须构建全绿”。

### 预测线垂直镜像修复（用户反馈，已修）

**用户反馈**：预测线渲染很奇怪，不是从探测器出发的准确线段。

**根因**：`View3D.getRayDirection` 的 viewPoint 实为**左下原点 +Y 向上**，而 S0.3（R4）标定时误判为"左上原点 +Y 向下"（**中心点检验对 Y 翻转不敏感**，故 1px 精度是真的、方向却反了）。`project()` 继承该镜像空间，`toOverlay()` 又"按图像坐标"多翻一次 y → **所有 2D 覆盖层（预测线）垂直镜像于真实渲染**。
**次因**：预测线只在拖动时重画，重试后相机 lerp 回瞄准视图期间线冻结在半途。

**诊断链（不靠猜）**：
1. `Test/ClearTest.ts` — 先排除"`DrawNode.clear()` 失效"假说（实测 clear 后画面全黑、0 亮像素）。
2. `Test/ProjCheckProbe.ts` — 对照 `project()` 与引擎 `getRayDirection`：**射线完全一致**（中心射线、顶部像素射线逐位吻合），但 `pick`/截图位置对不上。
3. `Test/VerdictProbe.ts` — **颜色标记球最终裁决**：探测器染绿、火星染红、注视点放白球。结果白球精确渲染在窗口中心 (1013,614)=主点真值，而**绿/红球与 `project()` 输出恰好关于屏幕中心镜像** → 定案。
4. 一度误判为"整体下移 224px"，因混淆了两个亮斑归属（探测器四面体 scale 1.6 比火星球 displayRadius 1.2 更大）。

**修复**：`Projection.toOverlay` 改恒等变换；`Trajectory.projectPolyline` 不翻转 y；`Hud.localToOffset/offsetToLocal` 统一 +Y 向上；**`computeAim` 的 `uy = -dy/len` 负号必须保留**（平面 y 轴与偏移 y 轴反向 —— 我一度删掉负号，被 `HudTest` 当场抓回：`dir-up-toward-goal: vy=15.33`）；`Game` 瞄准态**每帧**重画预测线。

**副收获**：修正后屏幕方向语义 = **世界 +z（靠近相机）在屏幕下方**（与真实相机一致，近景在画面下方）—— 探测器在下、目标在上，向上发射。S1.3 时"线看起来合理"实为镜像后的巧合。

### Recent Progress

- **会话 20 · 视口尺寸变化没处理（手机真机问题的根因）**：所有几何都在**启动时**读一次 `View.size` 就算死了，而手机浏览器画布启动后还会变一次 ⇒ 预测线偏移、新区域收不到触摸。修复：`buildPanels()`（可重复调用）+ `relayoutForViewport()`（隐藏旧层与旧运行时、更新容器 `size`、重建面板、恢复当前状态），监听 `Director.entry.onAppChange(name === 'Size')`。验证：运行中改窗口 → 日志 `viewport rebuilt: 601x1066` → 用**竖屏坐标**点击仍能正确进关；截图确认选关 2×3 与预测线笔直向上。附带工具 `tools/input-inject/set-window.ps1`（**必须 CRLF**）。已提交 `31cba6e`。
- **会话 19 · 竖屏（交付形态）实测**：用 Win32 `MoveWindow` 把窗口改成 400×710（`View.size` 601×1066）后，发现两处溢出并有截图证据 —— 选关 6 行竖排 870 > 可用 636（L6 被裁、底部提示出屏）、结算按钮写死 ≥560 而卡片只有 529（按钮戳出卡片）。修复：列数随宽高比自适应（竖 **2×3** / 横 1×6）、按钮尺寸按可用空间推算、下限降到 160×72；结算按钮宽 = 卡片宽 − 60。已提交 `21a5c78`。
- **会话 18 · 相对拖动 + 命中框象限 bug**：用户要求“按哪里都能瞄、松手才发射、按下时线回到直飞”。实现：按下点 = 摇杆零点（复用 `computeAim`，把按下点当 `probeOffset`），位移方向/长度决定方向与力度。同时定位到 `createAimInput` 根节点 `anchor=(0.5,0.5)` 导致**命中框只剩左下象限**（子坐标原点 = 位置 − anchor×尺寸），改 `(0,0)` 后六点网格全部命中。已提交 `bd12af8`。
- **会话 17 · 预测线整体平移半屏**：S2.2 把 2D 层从 `Director.ui` 改挂 `levelLayers[i]` 后，绘制层子空间变成“左下原点绝对像素”，而 `project()` 输出是“中心原点偏移” ⇒ 整条线平移 (+W/2, +H/2)。修复：`projectPolyline` 增加显式 `originX/originY`，`TrajectoryOptions.layerOriginX/Y`；新增回归断言 `layer-origin-is-half-view`（读全局 `View.size` 的第一版被 `basis-matches-project` 当场判失败，证明测试有判别力）。已提交 `238cc95`。
- **会话 16 · “进关卡拖不动”的真根因**：S2.2 重写 `init.ts` 时**漏掉把瞄准层接到状态机的两行**（`aim.onDrag` / `aim.onRelease`），触摸到了但状态机没动。新增能力：**合成鼠标输入注入**（Dora 的触摸事件同时代表鼠标点击）→ `tools/input-inject/mousectl.ps1`，触摸类改动从此可自动验收。已提交 `09645a5`。
- **会话 15 · 全屏吞触摸层**（当时的判断，后被会话 16 纠正为非根因）：给面板底板设 `touchEnabled + swallowTouches` 会独占点击且 `hide()` 没断触摸；已移除全屏独占层并在 `hide()` 里 `setEnabled(false)`（加固本身保留）。已提交 `dddb404`。
- **会话 14 · S2.2 + S2.3 交付**：`game/Ui.ts`（2D 原语）+ `game/Hud.ts` 的 `createResultPanel`/`createLevelSelect` + `game/Progress.ts`（解锁推进纯函数 + `Content.writablePath` 存档）+ `Game` 的 `LevelSelect` 相态与 `coreBackToSelect`/`startLevel` + `init.ts` 启动即选关。证据：cli build 69/69 无诊断；单测 `SUMMARY passed=7 failed=0 total=7`（新增 ProgressTest 36 断言）；探针 `Test/UiProbe.ts` = `RESULT=PASS` 且 `switchProblems=0`；整项目入口启动约 7s 无崩；**结算三态与选关截图已转 PNG 人工逐张查看**（布局/配色/文案一致）。实测踩坑并修复：`swallowTouches` 全屏触摸层独占触摸 → `AimInput.setEnabled` 同步 `touchLayer.touchEnabled`。已提交 `4033e09`。

- **会话 13 工具链**：发动机 HTTP API 打通（关掉「访问验证」后无鉴权）；两条构建路（`Dora.exe cli build` + 本地 tstl `tools/dora-build/`，产物逐字节一致）；`Test/UnitRunner.lua` 批跑单测；TGA→PIL→PNG 原生看图；`LICENSE` 补官方全文；作者/已测设备/引擎版本写入 README。
- **S1.3 踩坑**：`Line` 线宽不可控 → `DrawNode.drawSegment` + 顶点 `drawDot`；`Director.entry` 是 `View3D`，2D 节点须挂 `Director.ui`。
- **S1.4 自查发现真 bug**：`project()` 输出（相对屏幕中心偏移）与触摸换算（绝对像素）混用 → 统一为"投影偏移空间"（编译不报错、单测也测不出，只有跑通真实数据链路才暴露）。
- **S1.5 踩坑**：`threadLoop` 回调无参数（用 `App.deltaTime`）；增量构建**第二次**未转译 `Config.lua` → 全量重建解决；`App.elapsedTime` 在此环境恒为 0（用帧号）。
- **S2.1 调参（数据驱动）**：初版可玩性扫掠（轴向 5×5 网格）误报 L3/L5 不可达；细扫掠发现两关各有 6 个成功解（在斜向速度上，如 `v=(-16,-14)`）→ 测试扫掠改为**角度×力度采样**（12 方向 × 4 档）。回放每帧跳 4 个索引会越过 goalIndex → 收束时吸附 `flightTime = endIdx*dt`。
- **镜像修复期间**：`toOverlay` 的 `.ts` 替换一度只成功一半（另一处编辑静默失败），靠 grep 编译产物 `Projection.lua` 才发现仍是 `y = -p.y`。

### Open Issues

- ⚠️ **手机浏览器待复测（当前唯一开放的真机项）**：修复后的 Web 导出包需在手机上重跑「选关 → 拖 → 松手 → 结算」。
  桌面侧的触摸路径**已可自动验收**（`tools/input-inject/mousectl.ps1` 合成鼠标 = 真实命中判定；六点网格 + 相对拖动 + 松手发射 + 按钮点击均已跑通）。
- ⚠️ 解锁写盘由单测（存档往返）+ 真机文件（`%APPDATA%\IppClub\DoraSSR\escape-velocity.progress`）双重守着；「success 解锁下一关」的完整真人对局仍建议在手机复测时顺带确认。

- ✅ LICENSE 官方全文已补齐；作者 / 已测设备已填 README。
- ⚠️ 引擎「访问验证」当前关闭（本机开发所需）：同局域网其他设备也能无鉴权访问 8866 API，勿在不安全网络下长期关闭。
- ✅ 本地构建工具已迁入 `tools/dora-build/` 并纳入版本控制（提交 `029bdad`，门禁 `npm run verify`）。
- 🚨 **R6 包体积**：导出实测 **17 MB**，超 8 MB 目标；用户已决定**暂不处理**。
- ⚠️ **入口租约**：Web IDE 占用入口时 `stopEntry()` 无效，需用户先停游戏。
- ⚠️ **增量构建** 有时不重新转译（本会话在 `Config.lua`、`Projection.lua` 各踩一次）。
- ✅ **触摸路径在桌面上已可自动验收**（`tools/input-inject/mousectl.ps1` 合成鼠标 = 真实命中判定）；真机（手机）只需一次整体复测。

- ⚠️ 关卡手感（难度曲线）需真人试玩校准（用户反馈"手感还可以，大致有简单玩法"）。
- ⚠️ 区域检测（cell=12 中心采样）会漏掉 ~5px 宽的细竖线 → 诊断细线改用 ASCII 图。

### Visual Verification

- **Agent 能自行做基础视觉验证**（`Test/Vision.ts`：TGA → ASCII/亮度/列剖面/连通域；`rgbAt` 可做颜色标记对照）。局限：**美观与手感仍需人工**。
- 强力诊断法：**颜色标记球**（给每个物体染色 + 注视点放白球 = 主点真值）—— 靠它定位了垂直镜像 bug（`Test/VerdictProbe.ts`）。

### Active Checkpoint

- **当前目标**：**S3 视觉** —— S3.1 星球与土星环造型 → S3.2 轨迹发光与星空 → S3.3 金唱片开场与关间简报 → 可选 S3.4 粒子/后处理。
  每项的交付物与可观测验收判据见 `.agent/plan/PLAN.md`。
- **已完成**：S0 全部（`89be60e`）；S1.1–S1.5（`ed29f75`/`94b77af`/`eb75f07`/`3205cb8`/`4125b1a`）；S2.1（`9d080b6`）；镜像修复（`7cb72b0`）；S2.2 + S2.3（`4033e09`）；
  真机三连修（`dddb404`/`09645a5`/`238cc95`/`bd12af8`/`21a5c78`/`31cba6e`）；守则与清理（`c0179fc`/`e62c07d`/`4c160f9`/`138e6ce`/`283e9cb`）。
- **最新验证结果（会话 20 结束态）**：`node tools/dora-build/build.mjs --all` = **36/36 成功**；单测 `SUMMARY passed=7 failed=0 total=7`（7 模块 / 164 断言）；
  运行中改视口 → `viewport rebuilt: 601x1066`，之后用**竖屏坐标**点击仍能正确进关；合成鼠标闭环 `enter L1` → `phase -> Flying` → `result = …` → 点重试回 `Aiming`；
  竖屏（601×1066）与横屏（2024×1231）两套布局截图均人工查看通过。
- **关键约束**：`View.size` = 客户区 ×1.5（横屏实测 2024×1230 / 竖屏 601×1066）；物理平面沿世界 Z 展开；**世界 +z（近相机）在屏幕下方**；
  `getRayDirection` viewPoint = 左下原点 +Y 向上（`toOverlay` 恒等）；**全屏容器 `anchor` 必须是 (0,0)**；**投影输出空间 ≠ 绘制层空间（层原点显式传参）**；
  **视口变化必须重建**；Web 导出用 Web IDE「导出 HTML」；命令模式 Content 只读；入口被占用时跑不了运行时探针；TS 产物与源同目录（`*.lua` 不可笼统忽略）；
  `.ps1` 必须 CRLF；TSTL 坑：接口成员需 `@noSelf`/属性式箭头、`threadLoop` false 继续且回调无参（用 `App.deltaTime`）、2D 节点挂 `Director.ui`、`Vec2` 是 float32、简写属性触发 TS100016、`Model3D.Type`。
- **下一步**：**S3.1** —— 提高球体细分（`Test/gen_shapes.lua`）或产出更精细的自产 glTF、定稿六关行星配色/尺寸（`LevelData.visuals`）、土星环与探测器造型；
  流程仍是「改代码 → `node tools/dora-build/build.mjs --all` 36/36 → 截图/探针验证 → 更新 `PROGRESS.md` → 提交」。
- ⚠️ **开放项**：手机浏览器上重跑 Web 导出包（选关 → 拖 → 松手 → 结算）。