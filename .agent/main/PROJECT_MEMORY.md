## Project Memory

### Project Facts

- 项目：《单程》Escape Velocity。Dora SSR × Agent 社区小游戏征集的参赛项目（AtomGit 公开仓库）。
- 形态：竖屏 1080×1920 设计分辨率、单指触屏、六关、一次性发射的物理规划小游戏。
- 技术：TypeScript（编译为 Lua）+ Dora SSR；low poly 3D + 纯色 flat 零贴物；**物理 2D 平面积分，渲染 3D**。
- 许可：AGPL-3.0-only。
- 唯一事实来源：`docs/开发手册.md`；产品愿景：`单程-项目愿景.md`；计划：`.agent/plan/`（`PLAN.md`、`PROGRESS.md`）。

### Build And Run

- 入口：项目根 `init.ts`（真实 3D 场景）。需启动 Dora SSR 并保持 Web IDE 可用。
- 🔴 **Web 导出**：用 **Web IDE 自带的「导出 HTML / 打包 / 下载」**即可，**浏览器内 3D 正常**（用户实测）。
  **无需**从源码编译引擎 —— 引擎是预编译发行版（只有 `Dora.exe`/`wa.dll`/`LICENSES`），`Tools/`、`Projects/`、`Source/` 不存在；CLI 也没有 Web 构建命令。源码构建 Web 需 `Tools/build-scripts/build_web.sh` + Emscripten 5.0.5、Rust 1.85.1（`wasm32-unknown-emscripten`）、Go 1.24.3、Node.js、CMake 3.30.5（本环境不具备）。构建目录默认 `build/web`（`DORA_WEB_BUILD_DIR`），开关 `DORA_WEB_FEATURE_MODEL_3D`（默认 OFF）。
- 纯逻辑单测：`requireProjectModule("Test.GravityTest").runTests()` / `Test.CameraRigTest` / `Test.TrajectoryTest`（无需运行场景）。
- 运行时探针：`enterEntryAsync({fileName="Test/SceneProbe.ts"})` + 轮询标记文件到 `phase=done`。
  ⚠️ **入口租约**：Web IDE 占用入口时无法运行；`stopEntry()` 也不能释放。
  ⚠️ **轮询诀窍**：探针会先写 `phase=started`，轮询循环必须等到出现 `phase=done`（或 `RESULT=PASS/FAIL`）才停，否则会在扫描刚开始就杀掉入口。
- 离线资产生成：`Test/gen_shapes.lua`（在入口内执行才能写文件；命令模式 Content 只读）。
- 🚨 **包体积**：Web 导出实测 **17 MB** > 8 MB 目标（用户已决定暂不处理）。
- ⚠️ **TS 编译产物与源同目录**：`init.ts`→`init.lua`、`game/*.ts`→`game/*.lua`、`Test/*.ts`→`Test/*.lua`；但 `Test/gen_shapes.lua` 是手写源。→ `.gitignore` **不能笼统忽略 `*.lua`**（手册 §8.1）。`.agent/main/*.jsonl`（SESSION/HISTORY）与 `.agent/vision/`、`.agent/test-results/` 已忽略。

### Git History

- `2f2cbb6` init（仅 init.ts）
- `89be60e` **S0 裸测完成：关闭 R1/R2/R3/R4**（37 文件；提交信息有错别字"与时装工具链"，选择不改写历史）
- `ed29f75` **S1.1 物理内核**（`game/Gravity.ts` + `Test/GravityTest.ts`）
- `94b77af` **S1.2 场景与相机跟随**（`game/Scene.ts` + `game/CameraRig.ts` + 测试）

### Files And Architecture

- `docs/开发手册.md`：架构分层与模块清单、参数表、编码规范、验收标准与证据分级（§5.1 R3、§7.2.1 TSTL 坑、§8.1 lua 忽略规则、§9.1 视觉验证、§11 R1/R6）。
- `game/Config.ts`：全局常量与调参表（`PlaneToWorldX/Z`、`CameraTilt*`、`CameraMin/MaxDistance`、`PhysicsStep`、`MaxStepsPerFrame`、`PredictSteps`）。
- `game/Projection.ts`：**已标定**的 3D→2D 投影（纯函数）。手性 `right=cross(forward,up)`；`HANDEDNESS=1`、`FLIP_Y=false`；viewPoint 为左上角像素坐标（`[0,W]×[0,H]`，+Y 向下）；用 `toOverlay()` 转 Dora 2D 坐标。实测最大误差 **1.00 px**（2024×1230）。**S1.3 新增** `prepareCamera(cam, handedness, flipY)`（预计算相机基，供轨迹逐点投影）与 `projectPolyline(points, y, basis)`。
- `game/Gravity.ts`（**S1.1，零引擎依赖，253 行**）：类型 `P2`/`Body`/`ProbeState`/`SimOptions`/`SimResult`/`Outcome`；`bodyPositionAt`（行星公转）、`accelerationAt`（平方反比求和）、`step`（半隐式欧拉）、`collisionIndex`、`simulate`（**预测与真实共用的唯一推演实现**）、`orbitalSpeed`/`applyScales`/`sub`/`length`/`distance`。固定步长由调用方传入，不读时钟/帧率（确定性根基）。`applyScales` 不修改入参。
- `game/Scene.ts`（**S1.2，~180 行**）：`planeToWorld(p, y)`、`buildScene(options)`（方向光 + 行星 + 土星环 + 探测器）；行星用 `Model3D(path).getMaterial(0).baseColor` 逐实例染色；返回 `GameScene{ syncBodies, syncProbe, faceVelocity, probe, planets }`。
- `game/CameraRig.ts`（**S1.2，~174 行**）：`computeFit(points)`（关键点包围盒中心 + 半对角）、`computeRigStep`、`createCameraRig`、`defaultRigOptions`（tilt=45、dist 25–100、lerp=0.1）。接口成员函数必须标 `/** @noSelf **/`。
- `game/Trajectory.ts`（**S1.3 进行中，~178 行**）：`decimate`、`defaultOptions`、`projectPolyline`、预测线 + 真实尾迹（共用同一 `simulate` 结果：预测=整段路径，尾迹=已飞过的前缀）。
- `Assets/Model/`：离线生成的自包含 glTF（Sphere 61v/120f、Ring 16v/16f、Probe 12v/4f）。
- `Test/gen_shapes.lua`：离线几何生成器。
- 测试/探针：
  - `Test/GravityTest.ts`（S1.1，25 断言，`requireProjectModule` 加载，无需场景）
  - `Test/CameraRigTest.ts`（S1.2，11 断言）
  - `Test/TrajectoryTest.ts`（S1.3，10 断言）
  - `Test/TrajectoryProbe.ts`（S1.3 运行时探针；**构建失败中**）
  - `Test/SceneProbe.ts`（S1.2 运行时探针，场景渲染 + 相机跟随 + 视觉自检）
  - `Test/Smoke.ts`（S0 资产冒烟，`status=PASS draws=3 triangles=140`）
  - `Test/ProjectionProbe.ts`（投影标定回归，`getRayDirection` 搜索法，`RESULT=PASS maxPxErr=1.00`）
  - `Test/CameraProbe.ts`（R3 竖屏 NDC 计算）、`Test/CameraVisual.ts`（纵向轨道视觉确认）
  - `Test/WebFeasibility.ts`（一次性 R1 可行性诊断，保留）
  - `Test/Vision.ts`（文本化视觉验证工具库）、`Test/VisionProbe.ts`（自检）
- 仓库骨架：`README.md`、`.gitignore`、`LICENSE`、`Assets/`、`Test/`、`game/`、`.agent/plan/PLAN.md`。

### Decisions

- D1 引力弹弓：行星公转 + 真实弹弓（相对速度自然产生加速/减速），行星轨道速度调到肉眼可见。
- D2 时间：瞄准时全局冻结；松手瞬间行星从相位 0 开始公转、探测器同时发射。
- D3 相机：单一 Camera3D + 动态跟随拉远，不做视角硬切。
- D4 世界观：借真实天体名与视觉，但不守真实轨道比例。
- D5 失败流程：重试本关 / 返回关卡选择；进度只记已解锁关卡，无星级。
- D6 几何资产：代码能生成就用代码，其余用公开 low poly 素材。**实际落地为：外部取物不可用（R8），全部用 `Test/gen_shapes.lua` 代码生成。**
- D7 文档双落点：手册 + `.agent/plan/`。

### Camera And Layout Facts (S0/S1.2 实测)

- **竖屏 1080×1920（宽高比 0.5625）**；`View.fieldOfView` = 45°（垂直 FOV）。
- **桌面运行时窗口实测 2024×1230**（`View.size` 只读、无法运行时改窗口尺寸）；`aspect≈1.6455`。投影标定在该分辨率下完成。
- **物理平面必须沿屏幕纵向（世界 Z）展开**：横向展开的轨道在竖屏下 `maxNdcX=1.50` 被裁；
  纵向展开 `maxNdcX=0.72` / `maxNdcY=0.65` 完整可见（dist=30/tilt=45）。
- **倾角安全区间 20–60°**（>70° 贴边）；**纵向轨道 `dist ≥ 25` 即可框住整条轨道**。横向轨道需 `dist ≥ 50`。
- 已写入 `game/Config.ts`（`PlaneToWorldX/Z`、`CameraTilt*`、`CameraMin/MaxDistance`）。
- ⚠️ 竖屏验证靠已标定投影模块算 NDC 完成。

### Known Issues

- Dora TS 层**无**程序化几何工厂（无 `Sphere()`/自定义顶点网格），模型只能 `Model3D(path)` 加载 → 已用代码生成 glTF 解决。
- Dora TS 层**无** `Matrix4`/矩阵 API，也**无** world→screen 投影 → **已自建并标定**（`game/Projection.ts`）。
- **`View3D.getRayOrigin` 返回的不是视点**（相差 0.16），不要用它反推相机；正确做法是用 `getRayDirection` 做「射线方向 vs 目标方向」搜索法标定（dot 最大）。
- `Line` 只能画 2D（仅接受 `Vec2[]`，用 `Line.set(verts, color)` 画整条折线）；`DrawNode.drawSegment(from,to,radius,color)` 画线段；`View3D.pick(viewPoint)` 作为投影真值源。
- 🔴 **TSTL 坑（编译期不报错，运行时报错）**：
  1. **接口/对象成员函数默认带 self** → 生成 `obj:method(arg)` 冒号调用，参数错位，报 “attempt to perform arithmetic on a nil value (field 'x')”。解法：接口加 `/** @noSelf **/`（**属性式函数类型无效**，仍生成冒号调用）。`game/Scene.ts`、`game/CameraRig.ts` 已按此修。
  2. **`threadLoop` 返回 `false` 继续、`true` 停止**（易搞反；曾写 `return frame < 600` 导致第 1 帧即停）。
  3. **工厂命名空间不是类型**：标注用 `Vec3.Type` / `Node3D.Type`。
  4. **`Director.entry` 是 `View3D`（Node3D）**，2D 绘制节点（`DrawNode`/`Line`）必须挂 `Director.ui`；`Director.ui3D` 亦然。
  5. **`Vec2` 是 float32**：与 float64 普通对象比较有 ~1e-8 相对误差（实测 `Vec2(1586.6172844549)`→`1586.6173095703`）；断言时应两边都降为 float32 再逐位比较。
  6. **`null` 不支持**（TS100038，Lua 无 null 类型，用 `undefined`）；**`toExponential` 不支持**（用 `toFixed`）；**`saveScreenshot` 异步落盘**（需隔几帧再读）。
  7. **TS100016**：对象字面量里用简写属性引用局部函数会报"无 this 转换"，包一层箭头函数即可。
  8. **TS100037**：Lua 里只有 `false`/`nil` 为假，条件判断须显式 `!== undefined`。
  9. **增量构建有时不重新转译**：`build` 报成功但 `.lua` 未更新 → 改一次 `.ts`（哪怕改注释）强制重编；批处理编辑若报 "saved N/M operations" 说明有编辑静默失败，需重试。
  详见手册 §7.2.1 与 §5.5/§5.7。
- **Lua 无 `io` 库**（`io=nil`，`os.execute`/`os.rename`/`os.remove` 均 nil，仅 `os.getenv` 可用）；支持 `string.pack`/`string.unpack`/位运算（Lua 5.5），是离线生成 glTF 的基础。
- **命令模式 Content 只读且被沙箱限制**：路径越界报 `Content path must stay inside projectDir`；无 `remove`/`save` 方法；写文件必须走入口（`enterEntryAsync`）。命令模式读二进制文件报 `file is binary and cannot be previewed by read_file`。
- **入口租约**：Web IDE 占用入口时 `stopEntry()` 不释放（`running` 仍 true），`enterEntryAsync`/`previewGame` 报 `Dora entry runtime is in use`。
- **R8 网络取物不可用**：`fetch_url` 落盘 0 字节 / 移入目标路径失败；`git clone` 到 github 超时。
- `LICENSE` 目前是 AGPL-3.0 通知 + 官方全文链接，**尚未包含全文**，提交前必须补全。
- 🚨 **R6：Web 导出实测 17 MB**，超 8 MB 目标（包体由引擎 WASM 主导，项目侧无法解决）。