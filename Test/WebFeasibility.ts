/**
 * S0.5 可行性探测：在本环境中能否访问 Web 构建脚本与工具链。
 *
 * 结论记录到 .agent/test-results/s0-webprobe.txt
 */
import { Content, Path } from 'Dora';

const lines: string[] = [];

lines.push('=== Content.searchPaths ===');
for (let i = 0; i < Content.searchPaths.length; i++) {
	lines.push(`  [${i}] ${Content.searchPaths[i]}`);
}
lines.push(`writablePath = ${Content.writablePath}`);

// 引擎根目录（searchPaths[1] 是 <engine>/Script）
const engineScript = Content.searchPaths[1];
const engineRoot = Path(engineScript, '..');
lines.push(`engineRoot = ${engineRoot}`);

const probes = [
	Path(engineRoot, 'Tools'),
	Path(engineRoot, 'Tools/build-scripts'),
	Path(engineRoot, 'Tools/build-scripts/build_web.sh'),
	Path(engineRoot, 'Projects'),
	Path(engineRoot, 'Projects/Web/toolchain.env'),
	Path(engineRoot, 'Source'),
	Path(engineRoot, 'xmake.lua'),
	Path(engineRoot, 'CMakeLists.txt'),
];

lines.push('=== engine-root probes ===');
for (const p of probes) {
	try {
		const e = Content.exist(p);
		const d = e ? Content.isdir(p) : false;
		lines.push(`  ${p} -> exist=${e} isdir=${d}`);
	} catch (err) {
		lines.push(`  ${p} -> exception`);
	}
}

lines.push('=== engine-root listing ===');
try {
	for (const name of Content.getFiles(engineRoot)) {
		lines.push(`  ${name}`);
	}
} catch (err) {
	lines.push('  <listing failed>');
}

const out = Path(Content.searchPaths[0], '.agent', 'test-results', 's0-webprobe.txt');
Content.save(out, lines.join('\n'));
