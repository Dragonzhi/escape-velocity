## Session Summary

### Current Goal

《单程》Escape Velocity：**S1 核心循环已全部完成**（S1.1–S1.5 交付并有证据）；下一步 S2 关卡与结算。

### Milestone Ledger (S0)

- **S0.1 3D 资产** — `Test/gen_shapes.lua` 生成自包含 glTF（Sphere 61v/120f、Ring 16/16、Probe 12/4），base64 重算 `MATCH=true` → **PASS**
- **S0.2 R2 资产加载** — `Test/Smoke.ts` → `status=PASS draws=3 visible=3 triangles=140`（=120+16+4） → **PASS**
- **S0.3 R4 投影** — `game/Projection.ts` 自建并标定（`getRayDirection` 搜索法，非 `getRayOrigin`），`Test/ProjectionProbe.ts` 输出 `RESULT=PASS`，最大误差 **1.00 px** → **PASS**
- **S0.4 R3 竖屏相机** — `game/Config.ts` 标定（dist=30/tilt=45，纵向轨道，NDC 完整可见；倾角安全区 20–60°）→ **PASS**
- **S0.5 R1 Web 3D** — Web IDE「导出 HTML / 打包 / 下载」→ 浏览器内可见 3 个 3D 物体（**用户实测**，无需源码构建；CLI 无 Web 构建命令，源码构建需项目外工具链）→ **PASS**
- **S0.6 R6 包体积** — Web 导出实测 **17 MB** > 8 MB 目标 → **DEFERRED**（用户决定暂不处理）
- **S0.7 冒烟** — `build` 全绿 → **PASS**
- **S0.8 视觉确认** — 用户目视：球/环/棱锥从左至右（x=-2.2/0/+2.2）→ **PASS**

### Milestone Ledger (S1)

- **S1.1 物理内核** — `game/Gravity.ts`（零引擎依赖）+ `Test/GravityTest.ts`（25 断言全过）；**101 点逐位一致**；注入缺陷验证过测试判别力。已提交 `ed29f75` → **PASS**
- **S1.2 场景与相机** — `game/Scene.ts` + `game/CameraRig.ts`；运行时 `draws=4 triangles=260`；相机跟随 `min=53.95 max=82.55`（`pulled back=true`）；单测 11 断言全过 → **PASS**
- **S1.3 轨迹渲染** — `game/Trajectory.ts`（预测线 + 真实尾迹，共用同一份 `simulate`）；`Test/TrajectoryTest.ts` 10 断言全过；运行时区域检测 40+ 个 → **PASS**
- **S1.4 拖拽矄准** — `game/Hud.ts`；`Test/HudTest.ts` 17 断言全过；运行时链路验证（拖拽→velocity→simulate→预测线可见）；真触摸坐标系待人工校对 → **PASS（带人工校对项）**
- **S1.5 状态机与主循环** — `game/Game.ts` + `init.ts`；`Test/GameTest.ts` 22 断言全过；完整循环运行时 `RESULT=PASS`（拖→发射→飞行 6.2s→Result(missed)→重试回 Aiming）→ **PASS**

### Recent Progress

- 产出 `docs/开发手册.md`（唯一事实来源，D1–D7 冻结）、`README.md`、`LICENSE`（全文待补）、`.gitignore`、`game/Config.ts`、`.agent/plan/PLAN.md`。
- **互联网取物实测不可用（R8）**：`fetch_url` 三域名均落盘 0 字节；`git clone` 到 github 超时。→ **改走离线自造资产**。
- `Test/gen_shapes.lua` 生成 `Assets/Model/{Sphere,Ring,Probe}.gltf`；引擎内重算 base64 逐字符比对全部 `MATCH=true`（2944/640/416 字符）。
  - 踩坑：Ring 手抄 base64 多次丢字符（累计少 27、36 字节），最终把环从 24 段降到 8 段并一次性写准。
- `Test/Smoke.ts` 运行时 `status=PASS draws=3 triangles=140 missing=`，`stopEntry()` 后 `running=false` 干净退出。
- **R4 标定过程**：先用 `getRayOrigin` 反推视点失败（相差 0.16，各约定方向误差 0.74–1.25）；改用 `getRayDirection` 搜索法，`h=1 flipY=false` 误差 1.56px、`h=0` 误差 1361px → 定论；固化为回归测试，重复运行 `RESULT=PASS`，五点最大误差 1.00 px。
- `View3D.pick` 网格扫描可定位真实投影中心（`(1012,614)`≈`View.size/2`）；扫描需分帧、轮询标记要等到 `RESULT=`。
- **Agent 具备文本化视觉验证能力**（`Test/Vision.ts`），仍无法判断美观/手感。
- `init.ts` 由空壳改为真实 3D 场景；`build` 全绿。
- **S1.4 完成**：`game/Hud.ts`（矄准纯计算 + 触摸层）。关键修正：统一为投影偏移空间。
- **S1.5 完成**：`game/Game.ts`（GameCore 纯逻辑 + createGame）+ `init.ts` 真实游戏入口。
  确定性设计：发射时预推演整段飞行，之后逐帧回放。完整循环运行时 `RESULT=PASS`。
- `build` 全绿（26/26）。

### Open Issues

- 🚨 **R6 包体积**：导出实测 **17 MB**，超 8 MB 目标；用户已决定**暂不处理**。
- `LICENSE` 需替换为 AGPL-3.0 官方全文。
- ⚠️ **入口租约**：Web IDE 占用入口时 `stopEntry()` 无效，运行时探针（Smoke/SceneProbe/ProjectionProbe）跑不了，需用户先停游戏。
- ⚠️ **增量构建** 有时不重新转译：改了 `.ts` 必须重新 `build` 再看探针结果（本次曾因此读到旧标记文件）。
- S2 未开始（关卡数据、结算三态面板、关卡选择与解锁进度）。
- ⚠️ 真实触摸坐标系需一次人工校对（`localToOffset` 是唯一校准点）。
- ⚠️ 结算 UI 是最小版（Label）；正式面板在 S2.2。

### Visual Verification

- **Agent 已能自行做基础视觉验证**（`Test/Vision.ts`）：无需人工看截图即可判断物体是否渲染、有几个、在哪里。
- 局限：只覆盖几何/亮度层面，**美观与手感仍需人工**。

### Active Checkpoint

- **当前目标**：S1 已完成；开始 S2（关卡与结算）。
- **已完成**：S0 全部（R1/R2/R3/R4 关闭，R6 DEFERRED）；S1.1–S1.5 全部交付并有证据。
- **最新验证结果**：`build` 26/26 全绿；`GameTest` = `passed checks=22`；`GameProbe` 完整循环 `RESULT=PASS`（拖→发射→飞行 6.2s→Result(missed)→重试回 Aiming）；`init.ts` 运行 3 秒干净退出。
- **关键约束**：竖屏 1080×1920（运行时桌面窗口实测 2024×1230）；物理平面沿世界 Z 展开；Web 导出用 Web IDE 的「导出 HTML/打包」；命令模式 Content 只读（无 `remove`），写文件须走入口；入口被 Web IDE 占用时无法跑运行时探针；TS 产物与源同目录，`.gitignore` 不可笼统忽略 `*.lua`。
- **已读/已改文件**：`game/Config.ts`、`game/Projection.ts`、`game/Gravity.ts`、`game/Scene.ts`、`game/CameraRig.ts`、`game/Trajectory.ts`、`init.ts`、`Test/{Smoke,GravityTest,CameraRigTest,TrajectoryTest,TrajectoryProbe,ProjectionProbe,SceneProbe,Vision}.ts`、`Test/gen_shapes.lua`、`docs/开发手册.md`、`.agent/plan/{PLAN,PROGRESS}.md`。
- **下一步**：S2.1 `game/LevelData.ts`（六关数据）→ S2.2 结算三态面板 → S2.3 关卡选择与解锁。

**Next tool**: `edit_file`