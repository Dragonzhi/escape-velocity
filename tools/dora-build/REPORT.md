# Dora SSR TypeScript → Lua 本地构建工具 · 标定报告

工作区：`.temp/dora-build/`（`.temp/` 已被 .gitignore 忽略，未改动仓库任何源码或已提交 `.lua`）
日期：2026-09-24 · 结论：**32/32 个已提交 `.lua` 逐字节复现，含指定的 Gravity / Projection / Trajectory 三个文件**

---

## 0. 结论速览

| 项目 | 结果 |
| --- | --- |
| `game/Gravity.ts` → `game/Gravity.lua` | ✅ byte-for-byte（`fc /b`：no differences encountered） |
| `game/Projection.ts` → `game/Projection.lua` | ✅ byte-for-byte |
| `game/Trajectory.ts` → `game/Trajectory.lua` | ✅ byte-for-byte |
| 全项目（32 个 .ts，`--all`） | ✅ 32 相同 / 0 不同 / 0 未生成 |
| 整项目编译 | ✅ 支持（`--all`） |
| 逐文件诊断 | ✅ `file(line,col): error TSxxxx: msg`，出错文件不落盘 |
| 需要引擎 / 浏览器 | ❌ 不需要（仅需引擎自带的 `Dora.d.ts` 作类型声明，可用副本替代，已实测） |

入口：

```powershell
cd .temp\dora-build
node build.mjs ../../game/Gravity.ts ../../game/Projection.ts ../../game/Trajectory.ts   # 默认写回 .ts 同目录同名 .lua
node build.mjs --all --out out                                                            # 整项目，产物落到 out/（验证用，不覆盖仓库）
node compare-all.mjs out                                                                   # 与仓库已提交 .lua 逐字节比对
```

---

## 1. 精确版本（实测 `node -e "require(.../package.json).version"`）

| 组件 | 版本 | 来源 / 说明 |
| --- | --- | --- |
| Node | v22.20.0 | 本机 |
| npm | 11.13.0 | 本机 |
| typescript-to-lua | **1.37.1** | npm 最新（已钉死在 package.json） |
| typescript | **5.9.3** | **必须钉死**，见 §5.1；引擎内置的也是 5.9.3 |
| source-map | 0.7.6 | tstl 的传递依赖，用于复刻行号标记 |
| 引擎内置 TS | 5.9.3 | `www/typescript-3b25ee0544fe.js` 里 `version="5.9.3"` |
| 引擎内置 tstl | 无版本串 | `www/assets/tstl-B01o_sTy.js`（173,703 B），是上游 fork，见 §2.3 |

> ⚠️ `npm i typescript-to-lua typescript` 的默认结果**不可用**：tstl 1.37.1 的 `peerDependencies` 把 typescript 精确钉在 `6.0.2`（实测 `npm error peer typescript@"6.0.2" from typescript-to-lua@1.37.1`），而 TS 6.0.2 产出的 Lua 是错的（§5.1）。正确安装方式：
> `npm i --legacy-peer-deps`（package.json 已写死 `"typescript": "5.9.3"`、`"typescript-to-lua": "1.37.1"`，package-lock.json 已同步）。

---

## 2. 引擎的转译管线是怎么被逆向出来的（原始证据）

### 2.1 选项构造函数（逐字，来自 `www/assets/TranspileTS-Da-1bhZU.js`）

```js
function ee(e,t,n){return{strict:!0,jsx:e.JsxEmit.React,luaTarget:t,luaLibImport:n,luaExternalModules:[`Dora`],
  noHeader:!0,sourceMap:!0,noImplicitSelf:!0,moduleResolution:e.ModuleResolutionKind.Classic,
  target:e.ScriptTarget.ESNext,module:e.ModuleKind.ESNext}}
function G(e,t){return ee(e,t.LuaTarget.Lua55,t.LuaLibImportKind.Require)}
```

→ 引擎**默认**是 **`luaTarget = Lua55` + `luaLibImport = Require`**（探针可覆盖，但默认值即本次标定所用值）。

### 2.2 行号标记后处理（逐字，同文件 `transpileTypescript()` 内）

```js
let t = g.luaSourceMap;
if (t !== undefined && g.lua !== undefined) {
  let n = g.lua.split(`\n`), r;
  return await k.SourceMapConsumer.with(t, null, t => {
    let i = null;
    r = `-- [${s.path.extname(e).substring(1).toLowerCase()}]: ${s.path.basename(e)}\n` +
      n.map((e, n) => {
        let r = e.search(/\S|$/), a = t.originalPositionFor({ line: n + 1, column: r });
        a.line != null && (i = a.line);
        let o = i ?? 1;
        return e.trim() === `` ? `` : e.match(`--`) ? e : e + ` -- ${o}`;
      }).filter(e => e !== ``).join(`\n`)
  }), ...
}
```

要点（已在 `build.mjs::applyDoraMarkers()` 里逐字复刻）：
* 首行 `-- [<扩展名>]: <文件名>`；
* 每行取「第一个非空白字符」的列号去查 sourcemap；查到就更新「当前行号」，查不到就**沿用上一次**（sticky）；从未查到则 `1`；
* 行内已含 `--` 的行不改；空白行变成空串并被 `.filter` 丢弃；最后 `join("\n")` ⇒ **文件末尾没有换行符**（实测 `game/Gravity.lua` 末字节是 `-- 238` 的 `8`，无 `\n`）；
* 因此产物里没有空行，也没有 `.lua.map`（`inlineSourceMap` 未开，`sourceMap` 只用于上面的行号计算）。

### 2.3 引擎内置的是上游 tstl 的 fork —— 两处差异

**(a) TAB 缩进。** 引擎 bundle 里的打印器（逐字）：

```js
pushIndent(){this.currentIndent+=`\t`}popIndent(){this.currentIndent=this.currentIndent.slice(1)}
```

上游 npm 版本（实测 1.10.0 / 1.12.0 / 1.15.0 / 1.18.0 / 1.20.0 / 1.22.0 / 1.24.0 / 1.25.0 / 1.26.0 ~ 1.37.1 全部）都是 4 空格：

```js
pushIndent() { this.currentIndent += "    "; }
```

**(b) 私有选项 `luaExternalModules`。** 该选项**不在**上游 `TypeScriptToLuaOptions`（`dist/CompilerOptions.d.ts`）里，是 fork 新增。bundle 里的实现（逐字）：

```js
for(let t of Bd(e.code).reverse())
  if(!this.options.luaExternalModules?.includes(t.requirePath)){ ...resolveImport... }
```

即：打印出来的 `require("Dora")` 命中白名单就**跳过依赖解析**，代码文本原样保留。

> 没有 (a) 时：行号、注释、语句顺序全对，**只有缩进不同**（tab vs 4 空格）→ 见 §5.2 实测 diff。
> 没有 (b) 时：上游会去解析 `"Dora"`，解析失败后把 `require("Dora")` **改写成 `require("game.Dora")`** 并报 `TS100000` → 见 §5.3 实测 diff。
> 上游的等价机制是 `noResolvePaths`（`dist/transpilation/resolve.js:97`，picomatch glob），本工具两个选项同时给（Dora fork 认前者、上游认后者）。

---

## 3. 最终选项对象（逐字，`build.mjs::doraCompilerOptions()`）

```js
{
  strict: true,                                       // ← 与 IDE 一致
  jsx: ts.JsxEmit.React,                              // ← 与 IDE 一致
  luaTarget: tstl.LuaTarget.Lua55,                    // ← 与 IDE 默认 G() 一致
  luaLibImport: tstl.LuaLibImportKind.Require,        // ← 与 IDE 默认 G() 一致
  luaExternalModules: ["Dora"],                       // ← 与 IDE 一致（Dora fork 私有）
  noHeader: true,                                     // ← 与 IDE 一致
  sourceMap: true,                                    // ← 与 IDE 一致（只用来算行号，不落盘）
  noImplicitSelf: true,                               // ← 与 IDE 一致
  moduleResolution: ts.ModuleResolutionKind.Classic,  // ← 与 IDE 一致
  target: ts.ScriptTarget.ESNext,                     // ← 与 IDE 一致
  module: ts.ModuleKind.ESNext,                       // ← 与 IDE 一致
  noResolvePaths: ["Dora"],                           // ← 本地补充：上游 tstl 的等价机制（见 §2.3b）
  baseUrl: <项目根>, rootDir: <项目根>,                // ← IDE 里 J() 也是 { ...opts, baseUrl: projectRoot, rootDir: projectRoot }
  lib: [], types: [], skipLibCheck: true,             // ← 本地环境适配，不影响产出字节（见下）
}
```

* `lib: []` + 把引擎的 `Dora.d.ts` 作为 rootFile 一起进 program：等价于 IDE 把 `Dora.d.ts` 当默认 lib（`getDefaultLibFileName: () => "lib.Dora.d.ts"`）的做法；`Dora.d.ts` 内部是 `declare module "Dora" { ... }` 且 `/// <reference path="es6-subset.d.ts" />` + `lua.d.ts`，所以 `Math`、`string` 等全局类型也来自这套声明。
* `skipLibCheck: true` 只影响诊断，不影响 emit；实测开/关对 32 个文件的字节结果无影响。
* 诊断过滤：与 IDE 相同，忽略 `TS2497`（may be converted to a module）与 `TS2666`。

---

## 4. 验收结果

### 4.1 三个指定文件（`fc /b` + SHA256）

```
Gravity.lua committed  EE9B730FDEC71CBD810B81213D094CFF47C01D3F9E57A6F3543F6224A8CE12D5
Gravity.lua generated  EE9B730FDEC71CBD810B81213D094CFF47C01D3F9E57A6F3543F6224A8CE12D5
Projection.lua committed CAD3E4C04E9911A8047DB8765891075A1EA9D8F2E0116AC0036267CB4892FF40
Projection.lua generated CAD3E4C04E9911A8047DB8765891075A1EA9D8F2E0116AC0036267CB4892FF40
Trajectory.lua committed 3EFAE40171106FA082E01C914A7183A1C859B61DDAAEF89AB1466FCB496AD622
Trajectory.lua generated 3EFAE40171106FA082E01C914A7183A1C859B61DDAAEF89AB1466FCB496AD622

Gravity    : FC: no differences encountered
Projection : FC: no differences encountered
Trajectory : FC: no differences encountered
```

### 4.2 全项目（`node build.mjs --all --out out`）

```
合计 32 个文件：32 成功, 0 失败
汇总: 相同 32 / 不同 0 / 未生成 0 / 无对应 .ts 1   (总计 33)
```

逐文件（sha256 前 16 位）：

```
Test\CameraProbe.lua      7005B 815b2393eb4823f0      game\CameraRig.lua    3905B 209fc66a58bdc1a0
Test\CameraRigTest.lua    6082B 469c854ab504a2db      game\Config.lua       1920B 129f2fdf0d021a1c
Test\CameraVisual.lua     3237B d9b2acffe7893eca      game\Game.lua         8409B 92b829d70b068bc1
Test\ClearTest.lua        2669B e5322f51e51e6863      game\Gravity.lua      5609B ee9b730fdec71cbd
Test\GameProbe.lua        7708B fd36430e7a598817      game\Hud.lua          6818B 4a6beac978890e93
Test\GameTest.lua        10548B a18a10f6df6dec37      game\LevelData.lua    7607B 2ec01ae44ed2ffc8
Test\GravityTest.lua     11919B 8a20d22a80a27714      game\Projection.lua   6324B cad3e4c04e9911a8
Test\HudProbe.lua         6051B 17d757fa0334e5e8      game\Scene.lua        3576B a400a0a24368e895
Test\HudTest.lua          8209B b25323616ef052fb      game\Trajectory.lua   4171B 3efae40171106fa0
Test\LevelDataTest.lua    7870B 1d36b7ddb7c9b180      init.lua              4806B 68b76107f28b9829
Test\LineAlignProbe.lua   6366B bbd86dc6a298452c      (Test\gen_shapes.lua 无对应 .ts，跳过)
Test\LineDirProbe.lua     6124B 2f090881ea0f90f6
Test\ProjCheckProbe.lua   7538B 7fa7a78d4b212fac
Test\ProjectionProbe.lua  5640B bbcab9696b9b3ccb
Test\SceneProbe.lua       7217B b05ab32e3516dc81
Test\Smoke.lua            2635B 1107edfb1635b4b7
Test\TrajectoryProbe.lua  5111B a8292a35306f5081
Test\TrajectoryTest.lua   7730B ea91fb4eca7e65a3
Test\VerdictProbe.lua     8028B 23ea3d772899a9bf
Test\Vision.lua          16148B fe52f2835cfbcf1f   ← 16KB，含 lualib(__TS__Class 等)，同样逐字节一致
Test\VisionProbe.lua      3231B 8271f48e6f5d75a4
Test\WebFeasibility.lua   2351B 7d2ece8ad078f772
```

### 4.3 选项矩阵（`--all` 后逐字节比对）

| luaTarget | luaLibImport | 相同 / 总 | 结论 |
| --- | --- | --- | --- |
| **Lua55** | **Require** | **32 / 32** | ✅ 引擎 IDE 默认值（`G()`） |
| Lua54 | Require | 32 / 32 | ✅ 也一致（本代码库无区分 5.3/5.4/5.5 的语法） |
| Lua53 | Require | 32 / 32 | ✅ 同上 |
| LuaJIT | Require | 28 / 32 | ❌ 首个差异示例：`probeNode.angleY = math.atan2(...)` 一侧不同 |
| Universal | Require | 23 / 32 | ❌ 首个差异示例：`local __continue3` |
| Lua55 | RequireMinimal | 32 / 32 | ✅（该选项只影响 lualib_bundle 的产出，单文件产物不变） |
| Lua55 | Inline | 16 / 32 | ❌ 出现 `-- Lua Library inline imports` |

→ 标定结论：`Lua55 + Require`（= 引擎默认）。Lua53/54 同样能复现，但按引擎的真实取值取 Lua55。

---

## 5. 残余差异与踩过的坑（均已解决，此处保留证据）

### 5.1 TypeScript 版本：6.0.2 会产出**错误代码**（必须 5.9.3）

```
$ npm i typescript@6.0.2 --no-save ; node build.mjs ../../game/Gravity.ts --out out_ts6
error TS5101: Option 'baseUrl' is deprecated ...
first differing line: 11
!!   11 A: "\treturn math.sqrt(a.x * a.x + a.y * a.y) -- 100"     ← 仓库已提交（正确）
!!   11 B: "\treturn Math:sqrt(a.x * a.x + a.y * a.y) -- 100"     ← TS 6.0.2 产出
A 5609 B vs B 5576 B → byte-equal: NO
```

### 5.2 缩进：上游 tstl 是 4 空格，Dora fork 是 TAB

未打补丁时（行号标记已完全正确）：

```
!!    7 A: "\treturn {x = a.x - b.x, y = a.y - b.y} -- 95"
!!    7 B: "    return {x = a.x - b.x, y = a.y - b.y} -- 95"
```

修复：`build.mjs` 顶部对 `tstl.LuaPrinter.prototype.pushIndent/popIndent` 打 3 行补丁（`--no-dora-indent` 可关闭）。修复后 5609B == 5609B。

### 5.3 外置模块：`require("Dora")` 被改写

未加 `noResolvePaths` 时：

```
!!    3 A: "local ____Dora = require(\"Dora\") -- 20"
!!    3 B: "local ____Dora = require(\"game.Dora\") -- 20"
其它诊断： error TS100000: Could not resolve lua source files for require path 'Dora' in file game\Trajectory.ts.
```

修复：编译器选项加 `noResolvePaths: ["Dora"]`。

### 5.4 仍然存在的（非差异）事项

1. `Test/gen_shapes.lua` 有 `.lua` 无 `.ts`，无法（也不需要）复现。
2. 引擎 fork 的 tstl 具体版本号**无据可查**（bundle 里没有任何版本串）。当前结论建立在「上游 1.37.1 + 2 处 fork 差异」之上，并用 32 个真实文件逐字节比对验证等价；若将来某文件出现字节差异，第一嫌疑仍是 tstl 版本差。
3. 其它 Dora 外置模块（`DoraX` / `ImGui` / `YarnRunner` / `love` / `nvg` …）若被 import，需要用 `--external ImGui,DoraX` 显式声明，否则会重演 §5.3 的改写（会伴随 TS100000 诊断，不会静默出错）。本仓库未使用这些模块。
4. 本工具**不生成 `lualib_bundle.lua`**（引擎自带 `Script/Lib/lualib_bundle.lua`）；`luaLibImport: Require` 下产物只引用它，不需要重新生成。
5. 产物末尾无换行符、无 `.lua.map`、无空行——这是引擎的行为，已如实复刻（如果接入 IDE/格式化工具请勿「顺手补一个换行」）。

---

## 6. 「能否在没有引擎与浏览器的情况下独立工作」

**能。** 具体边界（均已实测）：

| 依赖 | 是否需要 | 证据 |
| --- | --- | --- |
| 引擎进程 `Dora.exe` | ❌ 不需要 | 全程未启动引擎 |
| 浏览器 / Web IDE / WebSocket | ❌ 不需要 | 转译全在 Node 内完成 |
| 引擎的 `Dora.d.ts`（类型声明，276 KB） | ⚠️ 类型检查需要，**运行不需要** | 见下 |
| npm registry | 仅首次装依赖 | `npm i --legacy-peer-deps` |

`Dora.d.ts` 只是编译期的类型契约（脚本侧 `import ... from 'Dora'` 的实际实现由引擎运行时提供）。它可以通过三种方式提供：

1. 默认自动探测（`DORA_ROOT` 环境变量 / 常见安装目录下的 `dora-ssr*`）；
2. `--dora-dts <path>`；
3. **自带副本**：本工作区已复制 `Script/Lib/Dora/zh-Hans/*.d.ts` 到 `.temp/dora-build/dora-types/`，实测：

```
$ node build.mjs ../../game/Gravity.ts ../../game/Trajectory.ts --out out_standalone --dora-dts dora-types/Dora.d.ts
  [ok]   game\Gravity.ts  ->  ...\out_standalone\game\Gravity.lua  (5609 bytes)
  [ok]   game\Trajectory.ts  ->  ...\out_standalone\game\Trajectory.lua  (4171 bytes)
Trajectory.lua: sha256=3efae40171106fa0… byte-equal: YES
```

即：把 `dora-types/` 一起带走，整套工具（`build.mjs` + 两个依赖）与引擎安装目录完全解耦。

---

## 7. 目录清单

```
.temp/dora-build/
├── build.mjs            构建工具（TS→Lua + Dora 行号标记 + 诊断）
├── compare.mjs          单文件逐字节比对（SHA256 / 首个不一致行 / 归一化比对）
├── compare-all.mjs      全项目比对汇总
├── dora-types/          引擎 Dora.d.ts 等的本地副本（可选，用于脱离引擎目录编译）
├── out/                 本次全项目构建产物（与仓库已提交 .lua 逐字节一致）
├── probes/              逆向引擎管线时用的一次性探针脚本（证据留存）
├── refs/                Dora-SSR 仓库文件树快照（§2 逆向时的检索用）
├── scratch/Bad.ts       故意写错的样例（用于演示逐文件诊断，产物不落盘）
├── package.json         typescript 5.9.3 / typescript-to-lua 1.37.1（精确钉死）
└── node_modules/        仅 15 个包（tstl + ts + 传递依赖）
```

---

## 8. 复现步骤（照抄即可）

```powershell
cd .temp\dora-build
npm i --legacy-peer-deps                                  # 注意：不能用默认 peer 解析，会装成 TS 6.0.2
node build.mjs --all --out out                            # 32 个文件全部编译
node compare-all.mjs out                                  # 期望：相同 32 / 不同 0
# 单个文件（默认写回 .ts 同目录同名 .lua，与引擎落盘位置一致）：
node build.mjs ../../game/Gravity.ts
```

## 9. 下一步建议

1. 把 `.temp/dora-build/` 提升为正式目录（如 `tools/dora-build/`）并加进 git，`build.mjs` 即可作为「无 IDE 也能产 .lua」的常规构建入口；建议同时把 `out/` 的比对纳入 CI（`node compare-all.mjs out` 退出码即验收）。
2. 若要在提交前做一致性门禁，可用 `--out` 生成到临时目录后比对仓库 `.lua`，**不要**直接覆盖仓库产物后再 `git diff`（因为字节一致时无 diff、不一致时你已经改了文件）。
3. 依赖升级要成对验证：TS 或 tstl 任一升级后必须重跑 `compare-all.mjs`（本次已证明 TS 6.0.2 会静默产出错误代码）。
4. 引擎若升级到新版本，建议重跑一次 §2 的 bundle 逆向（`luaTarget`/`luaLibImport` 默认值、行号标记算法、fork 差异是否变化），本报告 §2 的原文片段可直接用于 diff。
