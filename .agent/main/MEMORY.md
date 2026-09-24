# Core Memory

### User Preferences

- 回复用简体中文；希望 Agent 少长篇思考、多动手。
- 对不确定的问题，必须先问再动手。
- 可启用互联网工具，但本环境实测取物不可用（见 Known Issues · R8）。
- 用户会主动指出 Agent 的短板（如"无法看图片"）并希望优先解决；认可"自建工具绕过引擎限制"的做法。
- 用户按里程碑节奏推进：完成一个小节→提交一次 git→进入下一节。
- **用户会实机试玩并给反馈**（如"手感还可以，大致有简单玩法"、"预测线渲染很奇怪，不是从探测器出发的准确线段"）→ 反馈优先级高，先定位再前进。
- **git 提交信息里不能含中文分号 `；`**（引擎的 shell 语法检查会以 `shell syntax ";" is not supported` 拒绝）。

### Stable Facts

- 当前项目：《单程》Escape Velocity（Dora SSR 竖屏 3D 小游戏）。仓库位于工作区根，唯一事实来源 `docs/开发手册.md`。
- 形态：竖屏、单指触屏、六关、一次性发射的物理规划小游戏；物理 2D 平面积分、渲染 3D。
- 许可：AGPL-3.0-only（官方全文已就位）。
- 作者/版权人：**Dragonzhi**（2026）；**已测设备：Web 浏览器**。
- **开发方式（会话 13 起）**：外部 Coding Agent（DSH）+ 引擎本体 —— DSH 读写/编译/驱动/验证，引擎只当运行时。工具链速查见 `PROJECT_MEMORY.md` §Build And Run。

### Known Decisions

- 七项产品/技术决策 D1–D7 已冻结，记录于 `docs/开发手册.md` §2。
- 3D 资产采用**代码生成自包含 glTF**（`Test/gen_shapes.lua`：纯 Lua `string.pack` + 手写 base64 → 写 `Assets/Model/*.gltf`），不依赖外部下载。
- **确定性飞行回放**：发射瞬间用与预测线**同一个 `simulate`** 预推演整段飞行，之后逐帧回放 → "预测线看见的就是飞出来的"，且与 D2 时间模型自洽。
- **结算在发射瞬间即完全确定**（结局 + goalIndex 都在 `coreLaunch` 时算出）；到达目标后飞行在到达点截断，回放时间吸附到 `endIdx*dt`。

### Known Issues

- ✅ **LICENSE 已补齐**（gnu.org 官方全文 34,523 B，SHA256 校验通过；版权通知移到 README）。
- **工具链（会话 13 起可用）**：引擎 `Dora.exe cli build|run|stop|log|doc search`；引擎 HTTP API（8866，需关掉引擎设置里的「访问验证」）；本地 TS→Lua 构建（`.temp/dora-build/build.mjs`，不依赖引擎）；单测批跑入口 `Test/UnitRunner.lua`（**新增单测模块必须加进它的 modules 列表**）；截图 TGA→PNG 后可直接看图。
- **内置 Agent 已不可用**：主会话上下文 40–52 万 tokens/请求，压缩连续 524（引擎 `log.txt`）；它其实支持 `/compact`、`/clear`（`DoraAgent.ts:688`），但界面未暴露。
- **R8 网络取物不可用（已实测）**：`fetch_url` 对 raw.githubusercontent.com / cdn.jsdelivr.net / www.gnu.org 均报 `failed to move downloaded file into target path`（引擎日志：`being used by another process`），落盘文件经 `Content:load` 验证全为 **0 字节**；`git clone` 到 github 超时。→ 改走代码生成资产，不再阻塞。
- **命令模式 Content 只读且被沙箱限制**：仅允许项目目录内路径（越界报 `Content path must stay inside projectDir`）；无 `save`/`searchPaths`/`writablePath`；**写文件必须通过入口**（`enterEntryAsync`）；命令模式 Content **无 `remove` 方法**，且无 `Content:save`；读二进制文件报 `file is binary and cannot be previewed`。
- **入口租约（entry lease）**：Web IDE 正运行游戏占用入口时，`stopEntry()` 不释放（`getEntryStatus().running` 仍 `true`），`enterEntryAsync`/`previewGame` 均被拒（`Dora entry runtime is in use; stop the current game before previewing`）。需用户先停游戏才能跑运行时探针。
- **手工转录 base64 不可靠**：长 base64 手抄多次丢字符（Ring 曾少 27、36 字节）。正解：让生成器直接写文件，或写完后用「重算 → 逐字符比对 MATCH」校验。
- ~~**Agent 无图像分析工具**~~（会话 13 起对 DSH 不成立）：DSH 可原生看图 —— 引擎 TGA 截图用 `python -c "from PIL import Image; Image.open('x.tga').save('x.png')"` 转 PNG 即可判读画面与排版；`Test/Vision.ts` 的文本化验证仍保留作为自动化自检。
- **Web 导出（R1）已关闭**：唯一可行路径是 Web IDE 自带的「导出 HTML / 打包 / 下载」（用户实机确认浏览器内 3D 正常）。**无需从源码构建引擎** —— 引擎为预编译发行版（`C:\Users\32485\Downloads\dora-ssr-v1.9.3-windows-x86\` 只有 `Dora.exe`/`gamecontrollerdb.txt`/`LICENSES`/`wa.dll`，无 `Tools/`、`Projects/`、`Source/`、`xmake.lua`、`CMakeLists.txt`）；且 `os.execute`/`io` 均为 `nil`（无 shell）、`EMSDK` 未设置。CLI 无 Web 构建命令。
- 🚨 **R6 包体积缺口**：Web 导出实测 **17 MB**，超 8 MB 目标（用户已决定暂不处理，口径待确认）。包体由引擎 WASM 主导，项目侧优化无济于事。
- 🔴 **投影 Y 轴约定（已修正，最易再犯）**：`View3D.getRayDirection`/`pick` 的 **viewPoint 实为「左下原点、+Y 向上」**；S0.3（R4）标定时误判为「左上原点 +Y 向下」——**中心点检验对 Y 翻转不敏感**，所以 1px 的标定精度是真的却没发现方向反了。
  → `project()` 输出**就是中心原点 +Y 向上的偏移量，与 Dora 2D 覆盖层空间一致**：`toOverlay()` 必须是**恒等变换**，`projectPolyline` 绝不能翻转 y。
  ⚠️ 修正前所有 2D 覆盖层（预测线/尾迹）垂直镜像于真实渲染；修正后 **世界 +z（靠近相机）= 屏幕下方**（近景在画面下方，探测器在下、目标在上，向上发射）。
- **玩家可拖拽方向覆盖全平面**（手柄降级/回放保留 `handleLocal`/`handleOffset` 缝隙）；**真实触摸坐标系仍需一次人工校对**（`localToOffset` 是唯一校准点；`Touch` 私有构造无法程序化注入）。

### Visual Verification Capability

- **Agent 能自己做视觉验证了**（无需人工看截图）。
- 工具：`Test/Vision.ts` — `App.saveScreenshot` 输出未压缩 TGA（type=2, 32bpp）→ 在引擎内解码 → ASCII 灰阶图 + 亮度直方图 + 列剖面 + 连通域检测；`rgbAt` 可做颜色标记对照。
- ⚠️ 已踩的坑（已写入代码注释与手册 §9.1）：
  1. `saveScreenshot` 是**异步落盘**，必须"请求 → 隔几帧 → 读取"，否则拿到陈旧截图。
  2. 截图约 10 MB，必须**步长采样**，不能物化像素数组（会失败）。
  3. **区域检测（cell=12 中心采样）会漏掉 ~5px 宽的细竖线** → 诊断细线改用 ASCII 图（步长 4）。
- 诊断"渲染位置对不上"的强力方法：**颜色标记球** —— 给每个物体染不同色（探测器绿、行星红）+ 在相机注视点放白球（= 主点真值），再用 `rgbAt` 读回实际渲染位置。这套方法最终定位了垂直镜像 bug（`Test/VerdictProbe.ts`）。
- **能力边界**：只能验证"物体有没有、几个、在哪、多大、是否分离"，**不能**判断美观/可读性/手感。