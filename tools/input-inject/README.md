# tools/input-inject · 合成鼠标输入（真机触摸的可自动化替身）

Dora 的 `Touch` 是私有构造，探针注入不了真实触摸；但 **Dora 的触摸事件同时代表鼠标点击**，
所以在 Windows 桌面上可以用合成鼠标事件驱动游戏，把"触摸相关改动必须人工点一次"变成可复现的自动验收。

## 坐标换算（关键）

引擎按固定逻辑分辨率渲染，窗口客户区是缩放显示：

| 量 | 值（实测 2026-09-24） |
|---|---|
| `View.size`（逻辑坐标，UI 布局用它） | **2024 × 1230** |
| 窗口客户区（像素） | 1349 × 820 |
| 客户区左上角（屏幕坐标） | 由 `ClientToScreen` 实时取 |

```
client_x = view_x * (clientW / 2024)
client_y = (1230 - view_y) * (clientH / 1230)     # view_y 是左下原点，客户区是左上原点
```

`View.size` 用引擎内探针读（`Test/SizeProbe.lua` → `.agent/test-results/size-probe.txt`），不要写死。
脚本每次都会 `ShowWindow(SW_RESTORE)` + `SetForegroundWindow`，窗口最小化也能跑。

## 用法

```powershell
$mc = 'tools\input-inject\mousectl.ps1'

# 恢复窗口并打印几何（client 尺寸 / 客户区原点 / 是否前台）
powershell -NoProfile -ExecutionPolicy Bypass -File $mc -Action restore

# 单击 / 拖动
powershell ... -File $mc -Action click -StartX 674 -StartY 191
powershell ... -File $mc -Action drag  -StartX 674 -StartY 600 -EndX 700 -EndY 300

# 分段控制（验证"按下不动 / 拖动才变"这类时序行为）
powershell ... -File $mc -Action press   -StartX 900 -StartY 400
powershell ... -File $mc -Action move    -StartX 1200 -StartY 400 -Steps 6 -StepMs 700
powershell ... -File $mc -Action release

# 一条命令内"按住 → 移动 → 抬起"（-HoldMs 是按下后先保持的时间）
powershell ... -File $mc -Action drag -StartX 900 -StartY 400 -EndX 1200 -EndY 400 -Steps 6 -StepMs 700 -HoldMs 4000
```

⚠️ **只用仓库里这一份脚本**：`.temp/` 下曾经有过一份旧副本，参数不一致会报
`A parameter cannot be found ...` 并且**静默什么都不做**（排查浪费过时间）。旧副本已删除。

## 常用点位（View 坐标 → 客户端坐标，2024×1230 / 1349×820）

| 目标 | View | Client |
|---|---|---|
| 选关 L1 按钮 | (1012, 943) | (674, 191) |
| 结算「重试本关」 | (1012, 525) | (674, 470) |
| 结算「返回关卡选择」 | (1012, 353) | (674, 585) |

## 已用它验收过的流程（回归模板）

**A. 基本闭环**：点选关(674,191) → 拖动(674,600→700,300) → 日志应依次出现 `enter L1`、`phase -> Flying`、`result = ...`、`phase -> Result`。

**B. 相对拖动模型**（2026-09-24 起）：
1. 点选关进关；
2. 在**远离探测器**的位置按下（例如 client `900,400`）→ 按住：预测线应显示**直飞**（中性）；
3. 连按方向拖动（例如右拖到 `1200,400`）：线应跟着指向右边（方向 = 位移方向，长度 = 力度）；
4. 松手 → `phase -> Flying`（**松手才发射**）。

**C. 触摸覆盖**：在四个象限与中心各按一次，确认每次都触发（这条正是"按哪里都能瞄"的验收；
曾因触摸层 anchor 导致命中框只剩左下象限，见 `game/Hud.ts` 中 `root.anchor` 处的注释）。

## 注意

- 这是**鼠标**路径，覆盖命中判定、坐标换算、状态机联动；真机多点触控/手势差异仍需人工抽查。
- 运行时会抢前台并移动光标，别在你正忙时跑。
- 日志用引擎 API 读（`POST /log`）而不是 `log.txt`：文件有缓冲/轮转，API 是实时的。
- 按钮/面板隐藏时**必须同时断触摸**（`setEnabled(false)`）；且**节点的子坐标原点是 "位置 − anchor×尺寸"** ——
  全屏容器若 anchor 取 (0.5,0.5)，整棵子树会被推走半个屏幕（命中框缩小成象限）。踩过两次，见 `AGENTS.md`。
