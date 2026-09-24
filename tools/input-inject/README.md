# tools/input-inject · 合成鼠标输入（真机触摸的可自动化替身）

Dora 的 `Touch` 是私有构造，探针无法注入真实触摸；但 **Dora 的触摸事件同时代表鼠标点击**，
所以在 Windows 桌面上可以用合成鼠标事件驱动游戏，从而把"触摸相关改动必须人工点一次"变成可复现的自动验收。

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

## 用法

```powershell
# 恢复窗口并打印几何（client 尺寸 / 客户区原点 / 是否前台）
powershell -NoProfile -ExecutionPolicy Bypass -File tools\input-inject\mousectl.ps1 -Action restore

# 单击（客户端坐标）
... -Action click -StartX 674 -StartY 191

# 拖动：按下 → 分步移动 → 抬起
... -Action drag -StartX 674 -StartY 600 -EndX 690 -EndY 320
```

脚本每次都会 `ShowWindow(SW_RESTORE)` + `SetForegroundWindow`，所以窗口最小化也能跑。

## 已用它验证过的流程（也是回归脚本的模板）

1. `POST /run {"file":"<proj>/init.lua","asProj":true,"projectRoot":"<proj>"}`
2. 点选关按钮（L1 → 客户端 `674,191`）→ 日志出现 `enter L1`
3. 拖动（`674,600` → `690,320`）→ 日志出现 `phase -> Flying`（**松手即发射**）
4. 等约 6 秒 → `result = ...` / `phase -> Result`
5. 点「重试本关」（客户端 `674,470`）→ `phase -> Aiming`

常用点位（View 坐标 → 客户端坐标，2024×1230 / 1349×820）：

| 目标 | View | Client |
|---|---|---|
| 选关 L1 按钮 | (1012, 943) | (674, 191) |
| 结算「重试本关」 | (1012, 525) | (674, 470) |
| 结算「返回关卡选择」 | (1012, 353) | (674, 585) |

## 注意

- 这是**鼠标**路径，能覆盖命中判定、坐标换算、状态机联动；真机多点触控/手势差异仍需人工抽查。
- 运行时会抢前台并移动光标（约 1 秒），别在你正忙时跑。
- 日志用引擎 API 读（`POST /log`）而不是 `log.txt`：文件有缓冲/轮转，API 是实时的。
- 按钮/面板的隐藏态**必须同时断触摸**（`setEnabled(false)`），否则隐藏节点可能继续参与命中 —— 踩过。
