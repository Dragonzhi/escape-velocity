#!/usr/bin/env node
/**
 * build.mjs —— Dora SSR 本地 TypeScript -> Lua 构建工具
 *
 * 不依赖引擎（Dora.exe）、不依赖浏览器（Web IDE）。
 * 复刻引擎 Web IDE 的真实转译管线（证据见 REPORT.md）：
 *
 *   1. 用 TypeScript 编译器建 Program（选项与 IDE 的 buildCompilerOptions() 逐字一致）
 *   2. 用 tstl 的 Transpiler 转译，产出 code + sourceMap
 *   3. 用 IDE 的"打行号标记"算法后处理：
 *        -- [<ext>]: <basename>
 *        每行按 sourceMap 反查原始 TS 行号，行尾追加 " -- <line>"
 *        （已经含 "--" 的行不动；空行直接删除）
 *
 * 用法：
 *   node build.mjs <file.ts> [<file2.ts> ...] [options]
 *   node build.mjs --all [options]
 *
 * 选项：
 *   --all                 编译项目内全部 .ts（排除 node_modules/.git/.temp 等）
 *   --out <dir>           把 .lua 写到 <dir>（保持相对目录结构）；默认与 .ts 同目录同名
 *   --root <dir>          项目根目录（默认自动向上找含 .git 的目录）
 *   --dora-dts <file>     Dora.d.ts 路径（默认自动探测引擎安装目录）
 *   --lua-target <t>      Lua54 | Lua55 | Lua53 | LuaJIT | Lua51 | Universal | Luau（默认 Lua55）
 *   --lua-lib <kind>      Require | RequireMinimal | Inline | None（默认 Require）
 *   --external <names>    外置模块名（逗号分隔，可重复；默认 Dora）——require 原样保留、不做依赖解析
 *   --deps                连同被 import 的依赖文件一起写出
 *   --no-markers          不做 "-- <line>" 后处理（输出裸 tstl 结果，用于对比）
 *   --emit-sourcemap      同时写出 .lua.map（默认不写，与引擎一致）
 *   --json                结果以 JSON 输出
 *   --quiet               静默（只输出错误）
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ts from "typescript";
import tstl from "typescript-to-lua";
import sourceMapLib from "source-map";

const __filename = fileURLToPath(import.meta.url);

// ────────────── Dora fork 兼容补丁（唯一已知差异） ──────────────
//
// 引擎内置的 tstl（www/assets/tstl-*.js）里 LuaPrinter 用的是 TAB 缩进：
//     pushIndent(){this.currentIndent+=`\t`}popIndent(){this.currentIndent=this.currentIndent.slice(1)}
// 而 npm 上游 typescript-to-lua（1.10 ~ 1.37.1 全部如此）用的是 4 个空格：
//     pushIndent() { this.currentIndent += "    "; }
// 不补这一刀，行号标记全部正确、只有缩进不同。可用 --no-dora-indent 关闭。
if (process.env.DORA_NO_INDENT_PATCH !== "1" && !process.argv.includes("--no-dora-indent")) {
	tstl.LuaPrinter.prototype.pushIndent = function () { this.currentIndent += "\t"; };
	tstl.LuaPrinter.prototype.popIndent = function () { this.currentIndent = this.currentIndent.slice(1); };
}

// ─────────────────────────── 选项 ───────────────────────────

/**
 * 与引擎 Web IDE (www/assets/TranspileTS-*.js) 里 buildCompilerOptions() 逐字一致的选项。
 * luaTarget / luaLibImport 由调用方（引擎 probe）传入，IDE 默认值是：
 *   function G(e,t){return ee(e,t.LuaTarget.Lua55,t.LuaLibImportKind.Require)}
 */
function doraCompilerOptions(luaTarget, luaLibImport, externalModules) {
	return {
		strict: true,
		jsx: ts.JsxEmit.React,
		luaTarget,
		luaLibImport,
		// Dora fork 的私有选项：命中它的 require 路径不再做依赖解析，代码里原样保留 require("Dora")。
		luaExternalModules: externalModules,
		// 上游 tstl 的等价机制（picomatch glob）。没有这一条，上游会把 "Dora" 当普通模块去解析，
		// 解析失败后把 require("Dora") 改写成 require("game.Dora")（实测）。两者都保留：
		// luaExternalModules 供 Dora fork 使用，noResolvePaths 供上游 tstl 使用。
		noResolvePaths: externalModules,
		noHeader: true,
		sourceMap: true,
		noImplicitSelf: true,
		moduleResolution: ts.ModuleResolutionKind.Classic,
		target: ts.ScriptTarget.ESNext,
		module: ts.ModuleKind.ESNext,
	};
}

const LUA_TARGETS = {
	universal: tstl.LuaTarget.Universal,
	"5.0": tstl.LuaTarget.Lua50, lua50: tstl.LuaTarget.Lua50, "50": tstl.LuaTarget.Lua50,
	"5.1": tstl.LuaTarget.Lua51, lua51: tstl.LuaTarget.Lua51, "51": tstl.LuaTarget.Lua51,
	"5.2": tstl.LuaTarget.Lua52, lua52: tstl.LuaTarget.Lua52, "52": tstl.LuaTarget.Lua52,
	"5.3": tstl.LuaTarget.Lua53, lua53: tstl.LuaTarget.Lua53, "53": tstl.LuaTarget.Lua53,
	"5.4": tstl.LuaTarget.Lua54, lua54: tstl.LuaTarget.Lua54, "54": tstl.LuaTarget.Lua54,
	"5.5": tstl.LuaTarget.Lua55, lua55: tstl.LuaTarget.Lua55, "55": tstl.LuaTarget.Lua55,
	jit: tstl.LuaTarget.LuaJIT, luajit: tstl.LuaTarget.LuaJIT,
	luau: tstl.LuaTarget.Luau,
};

const LUA_LIB_KINDS = {
	none: tstl.LuaLibImportKind.None,
	inline: tstl.LuaLibImportKind.Inline,
	require: tstl.LuaLibImportKind.Require,
	"require-minimal": tstl.LuaLibImportKind.RequireMinimal,
	requireminimal: tstl.LuaLibImportKind.RequireMinimal,
};

const SKIP_DIRS = new Set([
	"node_modules", ".git", ".temp", ".agent", ".kilo", ".dora",
	"dist", "build", "result", "out", ".vscode", ".idea", "www",
]);

// ─────────────────────────── 命令行 ───────────────────────────

function parseArgs(argv) {
	const opts = {
		files: [], all: false, out: undefined, root: undefined, doraDts: undefined,
		luaTarget: tstl.LuaTarget.Lua55, luaLibImport: tstl.LuaLibImportKind.Require,
		external: ["Dora"],
		deps: false, markers: true, emitSourcemap: false, json: false, quiet: false,
	};
	for (let i = 0; i < argv.length; i++) {
		const a = argv[i];
		const next = () => {
			const v = argv[++i];
			if (v === undefined) throw new Error("缺少参数值: " + a);
			return v;
		};
		switch (a) {
			case "--all": opts.all = true; break;
			case "--out": case "-o": opts.out = next(); break;
			case "--root": opts.root = next(); break;
			case "--dora-dts": opts.doraDts = next(); break;
			case "--lua-target": {
				const v = next().toLowerCase();
				const t = LUA_TARGETS[v];
				if (t === undefined) throw new Error("未知 lua target: " + v);
				opts.luaTarget = t; break;
			}
			case "--lua-lib": {
				const v = next().toLowerCase();
				const k = LUA_LIB_KINDS[v];
				if (k === undefined) throw new Error("未知 luaLibImport: " + v);
				opts.luaLibImport = k; break;
			}
			case "--external":
				// 外置模块（require 原样保留、不做依赖解析）。默认 Dora；可重复或逗号分隔。
				for (const n of next().split(",")) if (n.trim() !== "" && !opts.external.includes(n.trim())) opts.external.push(n.trim());
				break;
			case "--deps": opts.deps = true; break;
			case "--no-markers": opts.markers = false; break;
			case "--emit-sourcemap": opts.emitSourcemap = true; break;
			case "--json": opts.json = true; break;
			case "--quiet": opts.quiet = true; break;
			case "-h": case "--help": opts.help = true; break;
			default:
				if (a.startsWith("-")) throw new Error("未知选项: " + a);
				opts.files.push(a);
		}
	}
	return opts;
}

function findProjectRoot(startDir) {
	let dir = startDir;
	for (;;) {
		if (fs.existsSync(path.join(dir, ".git"))) return dir;
		const parent = path.dirname(dir);
		if (parent === dir) return startDir;
		dir = parent;
	}
}

/** 探测引擎自带的 Dora.d.ts（优先 zh-Hans，与引擎 IDE 内置 lib 内容对应）。 */
function findDoraDts(explicit) {
	if (explicit) {
		const p = path.resolve(explicit);
		if (!fs.existsSync(p)) throw new Error("找不到 --dora-dts 指定的文件: " + p);
		return p;
	}
	const candidates = [];
	if (process.env.DORA_DTS) candidates.push(process.env.DORA_DTS);
	if (process.env.DORA_ROOT) {
		for (const v of ["zh-Hans", "en"]) candidates.push(path.join(process.env.DORA_ROOT, "Script/Lib/Dora", v, "Dora.d.ts"));
	}
	const bases = [
		path.join(process.env.USERPROFILE || "", "Downloads"),
		path.join(process.env.USERPROFILE || "", "Documents"),
		"C:\\Dora", "C:\\Program Files", "/opt", "/usr/local",
	];
	for (const base of bases) {
		let entries = [];
		try { entries = fs.readdirSync(base); } catch { continue; }
		for (const e of entries) {
			if (!/dora[-_]?ssr/i.test(e)) continue;
			const root = path.join(base, e);
			for (const v of ["zh-Hans", "en"]) {
				candidates.push(path.join(root, "Script/Lib/Dora", v, "Dora.d.ts"));
				candidates.push(path.join(root, "Assets/Script/Lib/Dora", v, "Dora.d.ts"));
			}
		}
	}
	for (const c of candidates) if (c && fs.existsSync(c)) return c;
	throw new Error(
		"未找到 Dora.d.ts。请用 --dora-dts <path> 指定，或设置环境变量 DORA_ROOT 指向引擎安装目录。"
	);
}

function collectAllTs(root) {
	const out = [];
	const walk = (dir) => {
		let entries;
		try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
		for (const e of entries) {
			if (e.isDirectory()) {
				if (SKIP_DIRS.has(e.name) || e.name.startsWith(".")) continue;
				walk(path.join(dir, e.name));
			} else if (e.isFile() && (e.name.endsWith(".ts") || e.name.endsWith(".tsx")) && !e.name.endsWith(".d.ts")) {
				out.push(path.join(dir, e.name));
			}
		}
	};
	walk(root);
	return out.sort();
}

// ─────────────────── Dora 的"行号标记"后处理 ───────────────────

/**
 * 逐字复刻引擎 IDE 的后处理（TranspileTS-*.js 中 transpileTypescript() 内）：
 *
 *   r = "-- [" + ext + "]: " + basename + "\n" + lua.split("\n").map((line, i) => {
 *         const column = line.search(/\S|$/);
 *         const original = consumer.originalPositionFor({ line: i + 1, column });
 *         if (original.line != null) last = original.line;
 *         const lineNumber = last ?? 1;
 *         return line.trim() === "" ? "" : line.match("--") ? line : line + " -- " + lineNumber;
 *       }).filter(l => l !== "").join("\n")
 */
async function applyDoraMarkers(lua, luaSourceMap, sourceFileName) {
	const lines = lua.split("\n");
	const ext = path.extname(sourceFileName).substring(1).toLowerCase();
	const header = "-- [" + ext + "]: " + path.basename(sourceFileName) + "\n";
	let result = "";
	await sourceMapLib.SourceMapConsumer.with(luaSourceMap, null, (consumer) => {
		let lastLine = null;
		result =
			header +
			lines
				.map((line, index) => {
					const column = line.search(/\S|$/);
					const original = consumer.originalPositionFor({ line: index + 1, column });
					if (original.line != null) lastLine = original.line;
					const lineNumber = lastLine ?? 1;
					if (line.trim() === "") return "";
					if (line.match("--")) return line;
					return line + " -- " + lineNumber;
				})
				.filter((l) => l !== "")
				.join("\n");
	});
	return result;
}

// ─────────────────────────── 编译 ───────────────────────────

function formatDiagnostics(diagnostics, root) {
	const host = {
		getCanonicalFileName: (f) => path.normalize(f),
		getCurrentDirectory: () => root,
		getNewLine: () => "\n",
	};
	return ts.formatDiagnostics(diagnostics, host).trimEnd();
}

async function build(opts) {
	const cwd = process.cwd();
	const root = path.resolve(opts.root ?? findProjectRoot(path.resolve(cwd)));
	let targets = opts.files.map((f) => path.resolve(cwd, f));
	if (opts.all) targets = targets.concat(collectAllTs(root));
	targets = [...new Set(targets)];
	if (targets.length === 0) throw new Error("没有要编译的文件（给几个 .ts，或用 --all）");
	for (const t of targets) {
		if (!fs.existsSync(t)) throw new Error("文件不存在: " + t);
	}

	const doraDts = findDoraDts(opts.doraDts);
	const compilerOptions = Object.assign(doraCompilerOptions(opts.luaTarget, opts.luaLibImport, opts.external), {
		baseUrl: root,
		rootDir: root,
		lib: [],
		types: [],
		skipLibCheck: true,
	});
	const rootNames = [...targets, doraDts];

	const program = ts.createProgram({ rootNames, options: compilerOptions });

	const emitHost = {
		directoryExists: (d) => { try { return fs.statSync(d).isDirectory(); } catch { return false; } },
		fileExists: (f) => { try { return fs.statSync(f).isFile(); } catch { return false; } },
		getCurrentDirectory: () => root,
		readFile: (f) => { try { return fs.readFileSync(f, "utf8"); } catch { return undefined; } },
		writeFile: () => {},
	};

	// 收集 tstl 输出（等价于引擎 IDE 里的 output-collector）
	const emitted = new Map();
	const transpiler = new tstl.Transpiler({ emitHost });
	const emitResult = transpiler.emit({
		program,
		writeFile: (fileName, data, _bom, _onError, sourceFiles) => {
			const f = path.normalize(fileName);
			if (f.endsWith(".lua")) {
				emitted.set(f, { lua: data, sourceFiles, sourceMap: undefined });
			} else if (f.endsWith(".lua.map")) {
				const base = f.slice(0, -4);
				const prev = emitted.get(base) || { lua: undefined, sourceFiles, sourceMap: undefined };
				prev.sourceMap = data;
				emitted.set(base, prev);
			}
		},
	});

	// 诊断：IDE 的做法是 pre-emit 诊断 + tstl 诊断，并过滤 2497 / 2666
	const diagnostics = [
		...ts.getPreEmitDiagnostics(program),
		...emitResult.diagnostics,
	].filter((d) => d.code !== 2497 && d.code !== 2666);

	const fmtHost = {
		getCanonicalFileName: (f) => path.normalize(f),
		getCurrentDirectory: () => root,
		getNewLine: () => "\n",
	};
	const describe = (d) => ({
		code: d.code,
		message: ts.flattenDiagnosticMessageText(d.messageText, "\n"),
		formatted: ts.formatDiagnostic(d, fmtHost).trim(),
	});

	const targetSet = new Set(targets.map((t) => path.normalize(t)));
	const wanted = new Set();
	for (const t of targets) wanted.add(path.normalize(tstl.getEmitPath(t, program)));
	if (opts.deps) for (const k of emitted.keys()) wanted.add(k);

	const results = [];
	for (const [outPath, out] of emitted) {
		if (!wanted.has(path.normalize(outPath))) continue;
		const sourceFile = (out.sourceFiles || []).find((sf) => targetSet.has(path.normalize(sf.fileName)));
		const sourceName = sourceFile ? sourceFile.fileName : outPath.replace(/\.lua$/, ".ts");
		const fileDiagnostics = diagnostics.filter(
			(d) => d.file && path.normalize(d.file.fileName) === path.normalize(sourceName)
		);
		const success = fileDiagnostics.length === 0 && out.lua !== undefined;

		let code = out.lua || "";
		if (opts.markers && out.sourceMap && out.lua) {
			code = await applyDoraMarkers(out.lua, out.sourceMap, sourceName);
		}

		const dest = opts.out
			? path.join(path.resolve(cwd, opts.out), path.relative(root, outPath))
			: outPath;

		if (success) {
			fs.mkdirSync(path.dirname(dest), { recursive: true });
			fs.writeFileSync(dest, code, "utf8");
			if (opts.emitSourcemap && out.sourceMap) fs.writeFileSync(dest + ".map", out.sourceMap, "utf8");
		}

		results.push({
			source: sourceName,
			output: dest,
			success,
			bytes: success ? Buffer.byteLength(code, "utf8") : 0,
			diagnostics: fileDiagnostics.map(describe),
		});
	}

	// 请求了但没产出的（例如语法错误导致 tstl 跳过）
	for (const t of targets) {
		const expected = path.normalize(tstl.getEmitPath(t, program));
		if (!results.some((r) => path.normalize(r.source) === path.normalize(t)) && !emitted.has(expected)) {
			results.push({
				source: t,
				output: null,
				success: false,
				bytes: 0,
				diagnostics: diagnostics
					.filter((d) => !d.file || path.normalize(d.file.fileName) === path.normalize(t))
					.map(describe),
			});
		}
	}

	const loose = diagnostics.filter(
		(d) => !d.file || !results.some((r) => path.normalize(r.source) === path.normalize(d.file.fileName))
	);

	return { root, doraDts, options: compilerOptions, results, loose, diagnostics: formatDiagnostics(loose, root) };
}

// ─────────────────────────── main ───────────────────────────

const opts = parseArgs(process.argv.slice(2));
if (opts.help) {
	console.log(fs.readFileSync(__filename, "utf8").split("*/")[0]);
	process.exit(0);
}

const out = await build(opts);
const failed = out.results.filter((r) => !r.success);

if (opts.json) {
	console.log(JSON.stringify({
		root: out.root,
		doraDts: out.doraDts,
		luaTarget: out.options.luaTarget,
		luaLibImport: out.options.luaLibImport,
		results: out.results,
		loose: out.loose.map((d) => ({ code: d.code, message: ts.flattenDiagnosticMessageText(d.messageText, "\n") })),
	}, null, 2));
} else {
	if (!opts.quiet) {
		console.log("Dora 本地构建  root=" + out.root);
		console.log("  Dora.d.ts  " + out.doraDts);
		console.log("  luaTarget  " + out.options.luaTarget + "   luaLibImport " + out.options.luaLibImport);
	}
	for (const r of out.results) {
		if (r.success) {
			if (!opts.quiet) console.log("  [ok]   " + path.relative(out.root, r.source) + "  ->  " + path.relative(out.root, r.output) + "  (" + r.bytes + " bytes)");
		} else {
			console.log("  [FAIL] " + path.relative(out.root, r.source));
			for (const d of r.diagnostics) console.log("         " + (d.formatted || ("TS" + d.code + ": " + d.message)));
		}
	}
	if (out.loose.length > 0) {
		console.log("\n其它诊断：");
		console.log(out.diagnostics);
	}
	if (!opts.quiet) {
		console.log("\n合计 " + out.results.length + " 个文件：" + (out.results.length - failed.length) + " 成功, " + failed.length + " 失败");
	}
}
process.exit(failed.length > 0 ? 1 : 0);
