---
name: dora-ssr-engine
description: Dora SSR 引擎开发操作手册（本机环境）：引擎安装路径与端口、dora cli 命令、HTTP API 与「访问验证」鉴权、TS→Lua 两条构建路径、单测批跑入口、运行时探针与标记文件、TGA 截图转 PNG 看图、Dora 文档与 API 声明查询位置。当任务涉及 Dora SSR 引擎、.ts→.lua 构建、引擎内运行时验证、关卡/场景/相机/UI 的引擎 API，或需要查 Dora 文档与内置技能时使用。
---

# Dora SSR 引擎开发（本机）

项目根：`C:\Users\32485\AppData\Roaming\IppClub\DoraSSR\escape-velocity`（先读该仓库的 `AGENTS.md`）。
引擎安装：`C:\Users\32485\Downloads\dora-ssr-v1.9.3-windows-x86`（`Dora.exe`，v1.9.3.6）。

## 查文档 / 查 API（不需要引擎）

- 教程与示例：`<引擎>\Doc\{zh-Hans,en}\{Tutorial,Example}`
- **API 全量声明**：`<引擎>\Script\Lib\Dora\zh-Hans\Dora.d.ts`（276 KB；`tools/dora-build/dora-types/` 有副本）
- 引擎自带 7 个技能正文：`<引擎>\Doc\skills\*/SKILL.md`（dora-engine-coding 必读、ui-design、love-game-development、music-generation、memory、skill-creator、agent-command）
- 内置 Agent 提示词提取件：`.agent/dora-agent-prompts.md`
- 直接 grep 以上目录即可，不必依赖引擎。

## 端口与服务

| 端口 | 用途 |
|---|---|
| 8866 | HTTP：Web IDE 静态页 + 全部 JSON API |
| 8868 | WebSocket：引擎 → IDE 推送（`TranspileTSProbe` 等） |

**鉴权**：引擎设置面板里的「访问验证 / Auth Required」关闭后，8866 的 API 无鉴权可直接调；
开启时除 `/auth` 外全部返回 401（浏览器 IDE 持有会话令牌）。

## 常用命令

```powershell
$exe = 'C:\Users\32485\Downloads\dora-ssr-v1.9.3-windows-x86\Dora.exe'
& $exe cli status                 # 探活（含 Web IDE 是否连接）
& $exe cli build -p .             # 全量 TS→Lua，逐文件诊断（需 Web IDE 已连接）
& $exe cli log -n 50              # 引擎日志
& $exe cli doc search Sprite --source dora-tutorial --lang ts
node tools/dora-build/build.mjs --all        # 本地构建（不依赖引擎/浏览器，产物逐字节一致）
node tools/dora-build/compare-all.mjs out    # 与仓库产物逐字节比对
```

## 引擎 HTTP API（POST，JSON body）

- `/status`、`/run/status`、`/log`
- `/run`：项目 `{"file":"<proj>\\init.lua","asProj":true,"projectRoot":"<proj>"}`；单文件 `{"file":"<proj>\\Test\\XxxProbe","asProj":false}`
- `/stop`、`/ts/build {path}`（要求 Web IDE 已连接）、`/doc/search`、`/doc/read`

## 验证套路

1. 单测：`POST /run Test/UnitRunner` → 读 `.agent/test-results/unit-summary.txt` → `POST /stop`。
2. 运行时探针：`Test/*Probe.ts`，把结果写进 `.agent/test-results/*.txt`，找 `RESULT=PASS`。
3. 截图：`App.saveScreenshot` 出未压缩 TGA（约 10 MB）→
   `python -c "from PIL import Image; Image.open(r'x.tga').save(r'x.png')"` → 直接看图。
4. 真实触摸**无法**无头验证（`Touch` 私有构造），触摸相关改动必须人工点一次。
