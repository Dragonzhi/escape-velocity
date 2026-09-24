## Project Memory

### Project Facts

- 项目：《单程》Escape Velocity。Dora SSR × Agent 社区小游戏征集的参赛项目（AtomGit 公开仓库）。
- 形态：竖屏 1080×1920 设计分辨率、单指触屏、六关、一次性发射的物理规划小游戏。
- 技术：TypeScript（编译为 Lua）+ Dora SSR；low poly 3D + 纯色 flat 零贴物；**物理 2D 平面积分，渲染 3D**。
- 许可：AGPL-3.0-only。
- 唯一事实来源：`docs/开发手册.md`；产品愿景：`单程-项目愿景.md`；计划：`.agent/plan/`（`PLAN.md`、`PROGRESS.md`）。

### Build And Run

- 入口：项目根 `init.ts`（真实 3D 场景：球×2 + 环 + 探测器）。需启动 Dora SSR 并保持 Web IDE 可用。
- 🔴 **Web 导出**：用 **Web IDE 自带的「导出 HTML / 打包 / 下载」**即可，**浏览器内 3D 正常**（用户实测）。
  **无需**从源码编译引擎 —— 引擎是预编译发行版（只有 `Dora.exe`/`wa.dll`/`LICENSES`），`Tools/`、`Projects/` 不存在；CLI 也没有 Web 构建命令。源码构建 Web 需 `Tools/build-scripts/build_web.sh` + Emscripten 5.0.5、Rust 1.85.1（`wasm32-unknown-emscripten`）、Go 1.24.3、Node.js、xmake（本环境不具备）。
- 纯逻辑单测：`requireProjectModule("Test.GravityTest").runTests()`（无需运行场景）。
- 运行时探针：`enterEntryAsync({fileName="Test/SceneProbe.ts"})` + 轮询标记文件到 `phase=done`。
  ⚠️ **入口租约**（见 Known Issues）：Web IDE 占用入口时无法运行；`stopEntry()` 也不能释放。
  ⚠️ **轮询诀窍**：探针会先写 `phase=started`，轮询循环必须等到出现 `RESULT=PASS/FAIL` 才停，否则会在扫描刚开始就杀掉入口。
  ⚠️ **网格扫描要分帧**：`pick()` 逐点调用较慢，一帧内扫 4000+ 点会触发单帧限制；按帧切片推进（本次 `frames≈33`）。
- 离线资产生成：`Test/gen_shapes.lua`（在入口内执行才能写文件；命令模式 Content 只读）。
- 🚨 **包体积**：Web 导出实测 **17 MB** > 8 MB 目标（用户已决定暂不处理）。
- ⚠️ **TS 编译产物与源同目录**：`init.ts`→`init.lua`、`game/Config.ts`→`game/Config.lua`、`Test/Smoke.ts`→`Test/Smoke.lua`；但 `Test/gen_shapes.lua` 是手写源。→ `.gitignore` **不能笼统忽略 `*.lua`**（手册 §8.1）。

### Files And Architecture

- `docs/开发手册.md`：架构分层与模块清单、参数表、编码规范、验收标准与证据分级（§5.9/§11/§12/§13 已含离线资产方案与 R8；§8.1 记 lua 忽略规则）。
- `game/Config.ts`：全局常量与调参表（平面映射、相机安全区）。
- `game/Gravity.ts`：**零引擎依赖**的物理内核（固定步长、平方反比、`simulate` 预测与真实共用）。
- `game/Projection.ts`：**已标定**的 3D→2D 投影（纯函数）。手性 `right=cross(forward,up)`；`HANDEDNESS=1`、`FLIP_Y=false`；viewPoint 为左上角像素坐标（`[0,W]×[0,H]`，+Y 向下）；用 `toOverlay()` 转成 Dora 2D 坐标。实测最大误差 **1.00 px**（2024×1230）。
- `game/Scene.ts`：3D 场景搭建（同球体资产逐实例染色/缩放、土星环、探测器朝向）。
- `game/CameraRig.ts`：单一相机 + 动态跟随（包围盒半对角驱动，已实测单调）。
- `game/Trajectory.ts`：轨迹渲染（预测线 + 真实尾迹）。用 `DrawNode.drawSegment`（`Line` 线宽不可控）；挂在 `Director.ui`（`Director.entry` 是 View3D，挂不上 2D）。
- `game/Hud.ts`：拖拽矄准（`computeAim` 纯计算 + `createAimInput` 触摸层）。统一用**投影偏移空间**；`localToOffset` 是触摸坐标唯一校准点。
- `Assets/Model/`：离线生成的自包含 glTF（`Sphere.gltf` / `Ring.gltf` / `Probe.gltf`）。
  - Sphere：61v / 120f（生成参数 SEG=12、RING=6）。
  - Ring：16v / 16f（8 段扁平圆环，半径 1.35/2.0，法线全 (0,1,0)）。
  - Probe：12v / 4f（正四面体，指向 +X）。
- `Test/gen_shapes.lua`：离线几何生成器（Lua `string.pack` + 手写 base64，写 `Assets/Model/*.gltf`；构建通过）。
- `Test/Smoke.ts`：S0 资产加载冒烟测试（`Model3D` 加载三个资产 + `view.stats` 判定；`status=PASS draws=3 triangles=140`）。
- `Test/GravityTest.ts`：物理单测（25 断言，`requireProjectModule("Test.GravityTest").runTests()`）。
- `Test/CameraRigTest.ts`：相机机架单测（11 断言）。
- `Test/TrajectoryTest.ts`：轨迹单测（10 断言，含“预测线与尾迹逐点相同”）。
- `Test/TrajectoryProbe.ts`：轨迹运行时探针。
- `Test/HudTest.ts`：矄准单测（17 断言）。
- `Test/HudProbe.ts`：矄准→预测线链路运行时探针。
- `Test/ProjectionProbe.ts`：投影标定与回归测试（`getRayDirection` 搜索法取真值，输出 `RESULT=PASS/FAIL`；`maxPxErr=1.00`）。
- `Test/Vision.ts`：**文本化视觉验证工具库**（TGA→ASCII/统计/区域检测）。
- `Test/SceneProbe.ts`：场景+相机运行时探针。
- 仓库骨架：`README.md`、`.gitignore`、`LICENSE`、`Assets/`、`Test/`、`game/`、`.agent/plan/PLAN.md`。

### Decisions

- D1 引力弹弓：行星公转 + 真实弹弓（相对速度自然产生加速/减速），行星轨道速度调到肉眼可见。
- D2 时间：瞄准时全局冻结；松手瞬间行星从相位 0 开始公转、探测器同时发射。
- D3 相机：单一 Camera3D + 动态跟随拉远，不做视角硬切。
- D4 世界观：借真实天体名与视觉，但不守真实轨道比例。
- D5 失败流程：重试本关 / 返回关卡选择；进度只记已解锁关卡，无星级。
- D6 几何资产：代码能生成就用代码，其余用公开 low poly 素材。**实际落地为：外部取物不可用（R8），全部用 `Test/gen_shapes.lua` 代码生成。**
- D7 文档双落点：手册 + `.agent/plan/`。

### Camera And Layout Facts (S0 实测)

- **竖屏 1080×1920（宽高比 0.5625）**；`View.fieldOfView` = 45°（垂直 FOV）。
- **桌面运行时窗口实测 2024×1230**（`View.size` 只读、无法运行时改窗口尺寸）；`aspect≈1.6455`、`View.standardDistance≈1484.74`。投影标定在该分辨率下完成。
- **物理平面必须沿屏幕纵向（世界 Z）展开**：横向展开的轨道在竖屏下 `maxNdcX=1.50` 被裁；
  纵向展开 `maxNdcX=0.72` / `maxNdcY=0.65` 完整可见（dist=30/tilt=45）。
- **倾角安全区间 20–60°**（>70° 贴边）；**纵向轨道 `dist ≥ 25` 即可框住整条轨道**。
- 已写入 `game/Config.ts`（`PlaneToWorldX/Z`、`CameraTilt*`、`CameraMin/MaxDistance`）。
- ⚠️ 竖屏验证靠已标定投影模块算 NDC 完成。

### Known Issues

- Dora TS 层**无**程序化几何工厂（无 `Sphere()`/自定义顶点网格），模型只能 `Model3D(path)` 加载 → 已用代码生成 glTF 解决。
- Dora TS 层**无** `Matrix4`/矩阵 API，也**无** world→screen 投影 → **已自建并标定**（`game/Projection.ts`）。
- **`View3D.getRayOrigin` 返回的不是视点**（相差 0.16），不要用它反推相机；正确做法是用 `getRayDirection` 做「射线方向 vs 目标方向」搜索法标定（dot 最大）。
- `Line` 只能画 2D（仅接受 `Vec2[]`）；`View3D.pick(viewPoint)` 可作为投影真值源。
- 🔴 **TSTL 三大坑（编译期不报错，运行时报错）**：
  1. **对象/接口成员函数默认带 self** → 生成 `obj:method(arg)` 冒号调用，参数错位，报 “field 'x' is nil”。解法：`/** @noSelf **/`（属性式函数类型无效）。
  2. **`threadLoop` 返回 `false` 继续、`true` 停止**（易搞反）。
  3. **工厂命名空间不是类型**：标注用 `Vec3.Type` / `Node3D.Type`。
  4. 另：`saveScreenshot` 异步落盘（需隔几帧再读）；不支持 `toExponential`；不支持 `null`。
  5. **`Vec2` 是 float32**：与 float64 普通对象比较会有 ~1e-8 误差；断言时应两边都降为 float32。
  6. **增量构建有时不重新转译**：全量 `build` 报成功但 `.lua` 未更新 → 改一次 `.ts` 强制重编（本次踩到：改了源码未重编，读到旧标记文件）。
  7. **`Director.entry` 是 `View3D`**，2D 绘制节点（`DrawNode`/`Line`）必须挂 `Director.ui`。
  8. **`Touch` 是私有构造**，无法程序化注入真触摸事件 → 触摸坐标系需人工校对；
     用 `handleLocal`/`handleOffset` 缝隙做无头验证。
  9. **TS100016**：对象字面量里用简写属性引用局部函数会报“无 this 转换”错误，
     包一层箭头函数即可；接口用属性式箭头函数类型。
  详见手册 §7.2.1 与 §5.5/§5.7。
- 🔴 **TS100037**：Lua 里只有 `false`/`nil` 为假，条件判断须显式 `!== undefined`（`Test/Smoke.ts` 曾因此报错）。
- **Lua 无 `io` 库**（`io=nil`）；但支持 `string.pack` / `string.unpack` / 位运算（Lua 5.5），是离线生成 glTF 的基础。
- **命令模式 Content 只读且被沙箱限制**：路径越界报 `Content path must stay inside projectDir`；无 `remove` 方法；写文件必须走入口（`enterEntryAsync`）。
- **入口租约**：Web IDE 占用入口时 `stopEntry()` 不释放（`running` 仍 true），`enterEntryAsync`/`previewGame` 报 `Dora entry runtime is in use`。
- **R8 网络取物不可用**：`fetch_url` 落盘 0 字节 / 移入目标路径失败；`git clone` 到 github 超时。
- `LICENSE` 目前是 AGPL-3.0 通知 + 官方全文链接，**尚未包含全文**，提交前必须补全。
- 🚨 **R6：Web 导出实测 17 MB**，超 8 MB 目标（包体由引擎 WASM 主导，项目侧无法解决）。