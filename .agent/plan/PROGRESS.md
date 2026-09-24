# 实施进度

> 状态只能根据**已观察到的证据**更新。写了代码 = 已实现；构建通过 = 构建通过；进程存活 = 运行时存活。它们都不能证明未测试的输入、状态转换、输赢流程、持久化、时序或视觉行为。
> 步骤定义见 [`PLAN.md`](./PLAN.md)，技术细节见 [`docs/开发手册.md`](../../docs/开发手册.md)。

## 当前阶段

**S1 核心循环进行中**。S0 已完成；S1.1 物理内核、S1.2 场景与相机、S1.3 轨迹均已交付并有证据。

## 变更日志

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
