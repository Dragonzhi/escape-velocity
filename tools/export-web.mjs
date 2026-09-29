#!/usr/bin/env node
// 使用已安装 Dora 的官方 HTML 打包器；不修改引擎，也不依赖 Web IDE 的编辑缓存。
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const engineArg = process.argv.indexOf('--engine');
if (engineArg < 0 || !process.argv[engineArg + 1]) {
	throw new Error('用法：node tools/export-web.mjs --engine <Dora.exe 所在目录>');
}
const engine = path.resolve(process.argv[engineArg + 1]);
const runtimeDir = path.join(engine, 'www', 'web-player');
const testDir = path.join(root, '.agent', 'test-results');
fs.mkdirSync(testDir, { recursive: true });
const buildDir = fs.mkdtempSync(path.join(testDir, 'web-export-build-'));
const outDir = path.join(root, 'build', 'web-html');
const doraDts = path.join(engine, 'Script', 'Lib', 'Dora', 'zh-Hans', 'Dora.d.ts');
const compile = spawnSync(process.execPath, [
	path.join(root, 'tools', 'dora-build', 'build.mjs'), '--all', '--dora-dts', doraDts, '--out', buildDir,
], { cwd: root, stdio: 'inherit' });
if (compile.status !== 0) throw new Error('全量构建失败，停止导出。');

function walk(dir) {
	return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
		const file = path.join(dir, entry.name);
		return entry.isDirectory() ? walk(file) : [file];
	});
}
// 正式产物必须与刚构建的源码一致，不使用过期 Lua。
const luaFiles = walk(buildDir).filter(file => file.endsWith('.lua'));
for (const file of luaFiles) {
	const current = path.join(root, path.relative(buildDir, file));
	if (!fs.existsSync(current) || !fs.readFileSync(current).equals(fs.readFileSync(file))) {
		throw new Error('源码 / Lua 不一致，请先同步：' + path.relative(root, current));
	}
}
console.log(`Lua 一致性：${luaFiles.length} 相同，0 不同。`);

const project = Object.create(null);
project['init.lua'] = fs.readFileSync(path.join(buildDir, 'init.lua'));
for (const file of walk(path.join(buildDir, 'game'))) {
	if (file.endsWith('.lua')) project[path.relative(buildDir, file).replaceAll('\\', '/')] = fs.readFileSync(file);
}
for (const file of walk(path.join(root, 'Assets'))) {
	const relative = path.relative(root, file).replaceAll('\\', '/');
	if (relative.split('/').some(part => part.startsWith('.'))
		|| relative.includes('/Source/') || /\.(?:py|ts|lua|mmpz)$/i.test(relative)
		|| relative === 'Assets/Audio/bgm_deep_space.wav') continue;
	project[relative] = fs.readFileSync(file);
}
for (const file of ['LICENSE', 'README.md']) project[file] = fs.readFileSync(path.join(root, file));

const runtimeIndex = fs.readFileSync(path.join(runtimeDir, 'runtime.json'));
const index = JSON.parse(runtimeIndex);
const runtime = Object.create(null);
for (const [name, spec] of Object.entries(index.files)) {
	if (name !== path.basename(name)) throw new Error('运行时索引路径无效：' + name);
	const bytes = fs.readFileSync(path.join(runtimeDir, name));
	if (bytes.length !== spec.size || createHash('sha256').update(bytes).digest('hex') !== spec.sha256) {
		throw new Error('官方运行时校验失败：' + name);
	}
	runtime[name] = bytes;
}
runtime['runtime.json'] = runtimeIndex;

// Service 模块包含官方 manifest、直接打开 HTML 的 loader、SHA256、ZIP 实现。
// 仅去掉工作空间 API 导入，并把 ZIP 的浏览器 Worker 调度换为同一实现的同步压缩。
const services = fs.readdirSync(path.join(engine, 'www', 'assets')).filter(name => /^Service-.*\.js$/.test(name));
const serviceFile = services.find(name => fs.readFileSync(path.join(engine, 'www', 'assets', name), 'utf8')
	.includes('async function _t('));
if (!serviceFile) throw new Error('找不到兼容的 Dora 官方打包器。');
let source = fs.readFileSync(path.join(engine, 'www', 'assets', serviceFile), 'utf8');
if (!source.includes('function Ee(') || !source.includes('function Oe(')
	|| !source.includes('function pe(') || !source.includes('function fe(')) {
	throw new Error('官方打包器结构已改变，需要更新适配，停止导出。');
}
source = source.replace(/^import\{[^;]+;import\{[^;]+;/, '');
source = source.replace(/export\{[^}]+\};?\s*$/, '');
source += '\nfe=(data,options,done)=>{queueMicrotask(()=>{try{done(null,pe(data,options));}catch(error){done(error,null);}});return ()=>{};};\nexport {_t as pack,Oe as unzip};';
const official = await import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'));
const archive = await official.pack(project, runtime, 'html');
const files = official.unzip(archive);
fs.mkdirSync(outDir, { recursive: true });
for (const [name, bytes] of Object.entries(files)) {
	const target = path.resolve(outDir, name);
	if (!target.startsWith(outDir + path.sep)) throw new Error('导出文件路径越界：' + name);
	fs.mkdirSync(path.dirname(target), { recursive: true });
	fs.writeFileSync(target, bytes);
}
const archiveFile = path.join(root, 'build', 'escape-velocity-web-html.zip');
fs.writeFileSync(archiveFile, archive);
console.log(`官方 HTML 作品包：${archiveFile}`);
console.log(`直接打开：${path.join(outDir, 'index.html')}`);
console.log(`运行时 ${index.engineVersion}，游戏文件 ${Object.keys(project).length}，ZIP ${(archive.length / 1024 / 1024).toFixed(2)} MiB。`);
