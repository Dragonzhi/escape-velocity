# tools/dora-build · Dora SSR 本地 TypeScript → Lua 构建工具

不依赖引擎（`Dora.exe`）、不依赖浏览器（Web IDE），产出与引擎 Web IDE **逐字节一致**的 `.lua`。
标定过程与逆向证据见 [`REPORT.md`](./REPORT.md)；**32/32 个文件与仓库已提交产物逐字节相同**。

## 为什么要它

引擎的 TS→Lua 编译**发生在浏览器里**：引擎通过 WebSocket 发 `TranspileTSProbe`，浏览器用 tstl 编译后回传 Lua；
所以页面上 `/ts/build` 在「Web IDE not connected」时会直接失败。本工具把同一条管线搬到 Node 里，让构建与 IDE 解耦。

## 安装

```bash
cd tools/dora-build
npm i --legacy-peer-deps     # ⚠️ 必须带该参数，见下方"版本钉死"
```

**版本必须钉死**：`typescript-to-lua@1.37.1` + `typescript@5.9.3`。
tstl 1.37.1 的 peerDependencies 钉的是 `typescript@6.0.2`，而 **TS 6.0.2 会静默产出错码**（`math.sqrt(...)` → `Math:sqrt(...)`），
体积也对不上（Gravity.lua 5576 B ≠ 5609 B）。升级 TS/tstl 必须成对重跑一致性门禁。

## 用法

```bash
# 单文件 → 与 .ts 同目录同名
node build.mjs game/Gravity.ts

# 整项目（排除 node_modules/.git/.temp 等）
node build.mjs --all

# 写到别处（推荐用于校验，避免覆盖仓库产物）
node build.mjs --all --out out
node compare-all.mjs out          # 逐字节比对，退出码即结论

# 一次性门禁
npm run verify
```

常用选项：`--root <dir>`、`--dora-dts <file>`、`--lua-target`（默认 Lua55）、`--lua-lib`（默认 Require）、
`--external`（默认 Dora）、`--deps`、`--no-markers`、`--emit-sourcemap`、`--json`、`--quiet`。
`node build.mjs --help` 有完整说明。

## 门禁纪律

- **不要**"先覆盖仓库 `.lua` 再 git diff"：产物一致时没有 diff，不一致时你已经改了文件。始终 `--out` 到临时目录再比对。
- 引擎升级后重跑 REPORT.md §2 的 bundle 逆向，确认默认 `luaTarget`/`luaLibImport`、行号标记算法、fork 差异是否变化。

## 与引擎行为对齐的要点（细节见 REPORT.md）

| 项 | 取值 |
|---|---|
| 编译选项 | `strict`、`jsx: React`、`target/module: ESNext`、`moduleResolution: Classic`、`noImplicitSelf`（与 IDE `buildCompilerOptions()` 逐字一致） |
| tstl | `luaTarget = Lua55`、`luaLibImport = Require`、外置模块 `['Dora']` |
| fork 差异 | 缩进用 **TAB**；私有选项 `luaExternalModules`（上游等价 `noResolvePaths`） |
| 行号标记 | `-- [ts]: <basename>` + 行尾 `-- <TS行号>` 是 **IDE 后处理**，已复刻；产物无 `.map`、无尾换行 |
| 手写 Lua | `Test/gen_shapes.lua` 等无对应 `.ts` 的文件不参与编译 |

## 目录内容

- `build.mjs` / `compare.mjs` / `compare-all.mjs` —— 构建与比对
- `REPORT.md` —— 标定报告（版本矩阵、逆向原文、残余差异、独立性结论）
- `dora-types/` —— Dora API 类型声明副本（编译期类型契约；摘自已安装的 Dora SSR v1.9.3，MIT），
  使工具在**没有引擎的机器上也能工作**；也可用 `--dora-dts` 指向引擎自带的 `Script/Lib/Dora/zh-Hans/Dora.d.ts`
- `node_modules/`、`out/` —— 不纳入版本控制

## 不依赖 Web IDE 缓存的 HTML 导出

在项目根目录运行 `node tools/export-web.mjs --engine "Dora.exe 所在目录"`。
工具先用临时目录全量构建，检查每份 Lua 与仓库一致，随后读取引擎 `www/web-player/runtime.json` 并验证全部运行时 SHA256。
复用安装目录的官方 `Service-*.js` 打包逻辑；只有工作空间 API 导入和 ZIP 压缩调度适配到 Node，HTML loader、manifest 和运行时保持官方实现。
目前适配本项目使用的 v1.9.3 打包器结构，升级后须重新验证；结构不兼容会停止导出。
输出 `build/escape-velocity-web-html.zip` 与解压目录 `build/web-html/`，只打包游戏 Lua、Assets 和许可说明，不含测试、构建依赖与编辑器状态。
如果报源码 / Lua 不一致，先按门禁纪律比对并同步相应 Lua，再重跑。
