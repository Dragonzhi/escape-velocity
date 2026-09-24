## Session Summary

### Current Goal

《单程》Escape Velocity：S0 裸测全部关闭，S1 核心循环进行中（S1.1 物理内核、S1.2 场景与相机已完成）。

### Milestone Ledger (S0)

- **S0.1 3D 资产** — `Test/gen_shapes.lua` 生成自包含 glTF（Sphere 61v/120f、Ring 16/16、Probe 12/4），base64 重算 `MATCH=true` → **PASS**
- **S0.2 R2 资产加载** — `Test/Smoke.ts` → `status=PASS draws=3 visible=3 triangles=140` → **PASS**
- **S0.3 R4 投影** — `game/Projection.ts` 自建并标定（`getRayDirection` 搜索法），`Test/ProjectionProbe.ts` 输出 `RESULT=PASS`，最大误差 **1.00 px** → **PASS**
- **S0.4 R3 竖屏相机** — `game/Config.ts` 标定（dist=30/tilt=45，纵向轨道，NDC 完整可见；倾角安全区 20–60°）→ **PASS**
- **S0.5 R1 Web 3D** — Web IDE「导出 HTML」→ 浏览器内可见 3 个 3D 物体（**用户实测**，无需源码构建）→ **PASS**
- **S0.6 R6 包体积** — Web 导出实测 **17 MB** > 8 MB 目标 → **DEFERRED**（用户决定暂不处理）
- **S0.7 冒烟** — `build` 全绿 → **PASS**
- **S0.8 视觉确认** — 用户目视：球/环/棱锥从左至右 → **PASS**

### Milestone Ledger (S1)

- **S1.1 物理内核** — `game/Gravity.ts`（零引擎依赖）+ `Test/GravityTest.ts`（25 断言全过）；**101 点逐位一致**；注入缺陷验证过测试判别力。已提交 `ed29f75` → **PASS**
- **S1.2 场景与相机** — `game/Scene.ts` + `game/CameraRig.ts`；运行时 `draws=4 triangles=260`；相机跟随 `min=53.95 max=82.55`（`pulled back=true`）；单测 11 断言全过 → **PASS**

### Recent Progress

- 产出 `docs/开发手册.md`（唯一事实来源，D1–D7 决策冻结）、`README.md`、`LICENSE`（全文待补）、`.gitignore`、`game/Config.ts`、`.agent/plan/PLAN.md`。
- 实测网络取物不可用 → 改为**代码生成资产**（`Test/gen_shapes.lua`）。
- 关闭 R1/R2/R3/R4；R6 暂缓（用户决定）。
- **Agent 具备文本化视觉验证能力**（`Test/Vision.ts`）：TGA→ASCII+统计+区域检测，无需人工看截图。
- `init.ts` 由空壳改为真实 3D 场景。
- `build` 全绿（17/17）。

### Open Issues

- 🚨 **R6 包体积**：导出实测 **17 MB**，超 8 MB 目标；用户已决定**暂不处理**。
- `LICENSE` 需替换为 AGPL-3.0 官方全文。
- S1.3–S1.5 未开始（轨迹、HUD、状态机）。

### Visual Verification

- **Agent 已能自行做基础视觉验证**（`Test/Vision.ts`）：无需人工看截图即可判断物体是否渲染、有几个、在哪里。
- 局限：只覆盖几何/亮度层面，**美观与手感仍需人工**。

### Active Checkpoint

- **已完成**：S0 全部（R1/R2/R3/R4 关闭，R6 DEFERRED）；S1.1、S1.2 交付并有证据。
- **最新验证结果**：`build` 17/17 全绿；`GravityTest` = `passed checks=25`；`CameraRigTest` = `passed checks=11`；`SceneProbe` 输出 `draws=4 triangles=260` 与 `camera pulled back=true`。
- **关键约束**：竖屏 1080×1920；物理平面沿世界 Z 展开；Web 导出用 Web IDE 的「导出 HTML」。
- **下一步**：S1.3 `game/Trajectory.ts`（预测线 + 真实尾迹，复用已标定投影）。
