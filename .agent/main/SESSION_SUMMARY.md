## Session Summary

### Current Goal

《单程》Escape Velocity：**S2 关卡与结算进行中**。S0、S1 全部完成；S2.1 六关数据已交付；
**预测线垂直镜像 bug 已修复（用户反馈）**；下一步 S2.2 结算三态面板 → S2.3 关卡选择。

### Milestone Ledger (S0 · 已提交 `89be60e`)

- **S0.1 3D 资产** — `Test/gen_shapes.lua` 生成自包含 glTF（Sphere 61v/120f、Ring 16/16、Probe 12/4），base64 重算 `MATCH=true` → **PASS**
- **S0.2 R2 资产加载** — `Test/Smoke.ts` → `status=PASS draws=3 visible=3 triangles=140` → **PASS**
- **S0.3 R4 投影** — `game/Projection.ts` 标定，`Test/ProjectionProbe.ts` = `RESULT=PASS`，最大误差 **1.00 px** → **PASS**（⚠️ Y 轴约定在 S2 修正）
- **S0.4 R3 竖屏相机** — 纵向轨道 NDC 完整可见；横向 `maxNdcX=1.50` 被裁 → 平面沿世界 Z 展开 → **PASS**
- **S0.5 R1 Web 3D** — Web IDE「导出 HTML」→ 浏览器内可见 3 个 3D 物体（**用户实机**）→ **PASS**
- **S0.6 R6 包体积** — 实测 **17 MB** > 8 MB → **DEFERRED**（用户决定暂不处理）
- **S0.7 冒烟 / S0.8 视觉确认** → **PASS**

### Milestone Ledger (S1)

- **S1.1 物理内核** — `game/Gravity.ts`（零引擎依赖）+ `GravityTest` 25 断言；101 点逐位一致；已提交 `ed29f75` → **PASS**
- **S1.2 场景与相机** — `game/Scene.ts` + `game/CameraRig.ts`；`draws=4 triangles=260`；相机跟随 `min=53.95 max=82.55`；已提交 `94b77af` → **PASS**
- **S1.3 轨迹渲染** — `game/Trajectory.ts`；`TrajectoryTest` 10 断言；运行时区域检测 40+；已提交 `eb75f07` → **PASS**
- **S1.4 拖拽矄准** — `game/Hud.ts`；`HudTest` 17 断言；已提交 `3205cb8` → **PASS**
- **S1.5 状态机与主循环** — `game/Game.ts` + `init.ts`；`GameTest` 30 断言；完整循环 `RESULT=PASS`；已提交 `4125b1a` → **PASS**

### Milestone Ledger (S2)

- **S2.1 六关数据与目标判定** — `game/LevelData.ts`（六关 + `findGoalIndex`）；
  `resolveResult` 接入 Game；`LevelDataTest` 34 断言（含每关可玩性硬门）；已提交 `9d080b6` → **PASS**
- **🔴 预测线垂直镜像修复（用户反馈）** — 根因：S0.3 标定时把 `getRayDirection`
  的 viewPoint 误判为“左上原点 +Y 向下”（实为**左下原点 +Y 向上**）；`project()` 继承该镜像，
  `toOverlay()` 又多翻一次 y → 所有 2D 覆盖层垂直镜像于渲染。
  定案方法：颜色标记球对照（白注视点球精确在窗口中心，绿/红球与投影输出恰好镜像）。
  同步修 `Hud.localToOffset`（+Y 向上）与 `Game` 每帧重画预测线。全量 33/33、四套单测全过。
- **S2.2 结算三态面板 / S2.3 关卡选择与解锁** — 未开始。

### Recent Progress

- **S2 镜像修复方法**：先排除 `DrawNode.clear()` 失效（`ClearTest`）→ `getRayDirection` 对照
  （射线完全一致）→ 颜色标记球 + 注视点标记球最终裁决（`VerdictProbe`）。
- 修正后屏幕方向语义：世界 +z（靠近相机）在屏幕**下方**，-z 在上方
  → 探测器在下、目标在上，向上发射（与真实相机一致）。
- **S2.1 调参**：轴向 5×5 扫掠漏掉斜向解 → 改角度×力度采样（12 方向×4 档）。
- **S1.5 踩坑**：`threadLoop` 回调没有参数（用 `App.deltaTime`）。
- **S1.4 踩坑**：`Touch` 私有构造，无法程序化注入；`localToOffset` 是唯一校准点。
- **S1.3 踩坑**：`Line` 线宽不可控 → 改 `DrawNode.drawSegment`。

### Open Issues

- 🚨 **R6 包体积**：导出实测 **17 MB**，超 8 MB 目标；用户已决定**暂不处理**。
- `LICENSE` 需替换为 AGPL-3.0 官方全文。
- ⚠️ **入口租约**：Web IDE 占用入口时 `stopEntry()` 无效，需用户先停游戏。
- ⚠️ **增量构建** 有时不重新转译：改了 `.ts` 须强制重编（本次在 `Projection.lua` 上又踩一次）。
- ⚠️ 真实触摸坐标系需一次人工校对（`localToOffset` 是唯一校准点）。
- ⚠️ 结算 UI 是最小版（Label）；正式面板在 S2.2。
- ⚠️ 关卡手感（难度曲线）需真人试玩校准（用户反馈“手感还可以，大致有简单玩法”）。

### Visual Verification

- **Agent 能自行做基础视觉验证**（`Test/Vision.ts`：TGA → ASCII/亮度/列剖面/连通域；
  `rgbAt` 可做颜色标记对照）。局限：**美观与手感仍需人工**。
- 新增证据工具：`Test/VerdictProbe.ts`（颜色标记 + 注视点标记球）—— 靠它定位了镜像 bug。

### Active Checkpoint

- **当前目标**：S2.2 结算三态面板（成功/错过/撞毁 + 重试/返回）→ S2.3 关卡选择与解锁进度。
- **已完成**：S0 全部；S1.1–S1.5；S2.1；预测线镜像修复。
- **最新验证**：`build` 33/33 全绿；`TrajectoryTest` 10、`HudTest` 17、`GameTest` 30、
  `LevelDataTest` 34 全过；`GameProbe` 完整循环 `RESULT=PASS`；`init.ts` 加载 L1 干净退出。
- **关键约束**：竖屏 1080×1920（运行时窗口实测 2024×1230）；物理平面沿世界 Z 展开；
  世界 +z（近相机）在屏幕**下方**；Web 用 Web IDE「导出 HTML」；命令模式 Content 只读；
  TS 产物与源同目录；TSTL 坑：接口成员需属性式箭头函数、`threadLoop` false 继续、
  2D 节点挂 `Director.ui`、`Vec2` 是 float32、简写属性触发 TS100016。
- **下一步**：S2.2 结算三态面板。
