## Core Memory

### User Preferences

- 回复用简体中文；希望 Agent 少长篇思考、多动手。
- 对不确定的问题，必须先问再动手。
- 可启用互联网工具，但本环境实测取物不可用（见 Known Issues · R8）。
- 用户会主动指出 Agent 的短板（如"无法看图片"）并希望优先解决；认可"自建工具绕过引擎限制"的做法。
- 用户按里程碑节奏推进：完成一个小节→提交一次 git→进入下一节。

### Stable Facts

- 当前项目：《单程》Escape Velocity（Dora SSR 竖屏 3D 小游戏）。仓库位于工作区根，唯一事实来源 `docs/开发手册.md`。
- 形态：竖屏、单指触屏、六关、一次性发射的物理规划小游戏；物理 2D 平面积分、渲染 3D。
- 许可：AGPL-3.0-only。

### Known Decisions

- 七项产品/技术决策 D1–D7 已冻结，记录于 `docs/开发手册.md` §2。
- 3D 资产采用**代码生成自包含 glTF**（`Test/gen_shapes.lua`：纯 Lua `string.pack` + 手写 base64 → 写 `Assets/Model/*.gltf`），不依赖外部下载。

### Known Issues

- LICENSE 缺 AGPL-3.0 官方全文（提交前补）。
- **R8 网络取物不可用（已实测）**：`fetch_url` 对 raw.githubusercontent.com / cdn.jsdelivr.net / www.gnu.org 均报 `failed to move downloaded file into target path`（引擎日志：`being used by another process`），落盘文件经 `Content:load` 验证全为 **0 字节**；`git clone https://github.com/octocat/Hello-World.git` 报 `wsarecv ... connected host has failed to respond`（超时）。→ 改走代码生成资产，不再阻塞。
- **命令模式 Content 只读且被沙箱限制**：仅允许项目目录内路径（越界报 `Content path must stay inside projectDir`）；无 `save`/`searchPaths`/`writablePath`；**写文件必须通过入口**（`enterEntryAsync`）；命令模式 Content **无 `remove` 方法**，且无 `Content:save`。
- **入口租约（entry lease）**：Web IDE 正运行游戏占用入口时，`stopEntry()` 不释放（`getEntryStatus().running` 仍 `true`），`enterEntryAsync`/`previewGame` 均被拒（`Dora entry runtime is in use; stop the current game before previewing`）。需用户先停游戏才能跑运行时探针。
- **手工转录 base64 不可靠**：长 base64 手抄多次丢字符（Ring 曾少 27、36 字节）。正解：让生成器直接写文件，或写完后用「重算 → 逐字符比对 MATCH」校验。
- **Agent 无图像分析工具**：`read_file` 拒读二进制（PNG 报 `file is binary`）。**已用 `Test/Vision.ts` 文本化视觉验证绕过**（见下）。
- **Web 导出（R1）已关闭**：唯一可行路径是 Web IDE 自带的「导出 HTML / 打包 / 下载」（用户实机确认浏览器内 3D 正常）。**无需从源码构建引擎** —— 引擎为预编译发行版（`C:\Users\32485\Downloads\dora-ssr-v1.9.3-windows-x86\` 只有 `Dora.exe`/`gamecontrollerdb.txt`/`LICENSES`/`wa.dll`，无 `Tools/`、`Projects/`、`Source/`、`xmake.lua`、`CMakeLists.txt`）；且 `os.execute`/`io` 均为 `nil`（无 shell）、`EMSDK` 未设置。CLI 无 Web 构建命令。
- 🚨 **R6 包体积缺口**：Web 导出实测 **17 MB**，超 8 MB 目标（用户已决定暂不处理，口径待确认）。包体由引擎 WASM 主导，项目侧优化无济于事。

### Visual Verification Capability

- **Agent 能自己做视觉验证了**（无需人工看截图）。
- 工具：`Test/Vision.ts` — `App.saveScreenshot` 输出未压缩 TGA（type=2, 32bpp）→ 在引擎内解码 → ASCII 灰阶图 + 亮度直方图 + 列剖面 + 连通域检测。
- ⚠️ 两个已踩的坑（已写入代码注释与手册 §9.1）：
  1. `saveScreenshot` 是**异步落盘**，必须"请求 → 隔几帧 → 读取"，否则拿到陈旧截图。
  2. 截图约 10 MB，必须**步长采样**，不能物化像素数组（会失败）。
- 已实测：三个物体放在 x=-6.5/0/+6.5 → 正确输出 `segments: 3` 且三点位与预期对得上；纵向轨道三物体 y 归一化 0.21/0.49/0.83 自上而下完整可见。
- **能力边界**：只能验证"物体有没有、几个、在哪、多大、是否分离"，**不能**判断美观/可读性/手感。
- `previewGame({entry, captureAtSeconds})` 可截帧到 `.agent/vision/*.png`，但需要人看图；命令模式读该 PNG 会因 `file is binary and cannot be previewed` 而失败（解码必须在入口内做）。