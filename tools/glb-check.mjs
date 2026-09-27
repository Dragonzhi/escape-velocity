#!/usr/bin/env node
/**
 * glTF/GLB 交付自检（开发工具，不进游戏运行时）—— 直接在 Node 里读二进制，
 * 不用起引擎就能核对《模型交接_Trae.md》里那几条硬约定：
 *
 *   ① 单位球：半径 1.0、球心在原点（POSITION 的 min/max ≈ ±1）
 *   ② UV 齐全：每个 primitive 都要有 TEXCOORD_0
 *   ③ 不内嵌贴图：images = 0（贴图走 Assets/Image/ 外部文件）
 *   ④ 环：dualSided + alphaMode = BLEND 的材质（土星 xz / 天王星 xy 由建模保证）
 *   ⑤ 面数预算：行星 4k~8k、探测器 ≤ 2k/文件
 *
 * 用法：
 *   node tools/glb-check.mjs Assets/Model/Planet_Earth.glb
 *   node tools/glb-check.mjs \"Assets/Model/Planet_*.glb\"   （引号由 shell 展开，Windows 下请逐个传）
 *   node tools/glb-check.mjs --all      # Assets/Model 下所有 .glb
 */
import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";

function parseGlb(buf) {
	if (buf.readUInt32LE(0) !== 0x46546c67) throw new Error("不是 GLB（magic 不对）");
	const version = buf.readUInt32LE(4);
	let off = 12;
	let json = null;
	let bin = 0;
	while (off + 8 <= buf.length) {
		const len = buf.readUInt32LE(off);
		const type = buf.readUInt32LE(off + 4);
		if (type === 0x4e4f534a) json = JSON.parse(buf.slice(off + 8, off + 8 + len).toString("utf8"));
		else if (type === 0x004e4942) bin = len;
		off += 8 + len + ((4 - (len % 4)) % 4);
	}
	return { version, json, bin };
}

const args = process.argv.slice(2);
let files = [];
if (args.length === 0 || args[0] === "--all") {
	const dir = path.join(process.cwd(), "Assets", "Model");
	files = readdirSync(dir).filter((f) => f.toLowerCase().endsWith(".glb")).map((f) => path.join(dir, f));
} else {
	files = args.map((a) => path.resolve(a));
}

console.log("file                        tri    attr              img  mat  bbox half-extent  k(box)  材质");
for (const f of files) {
	const name = path.basename(f);
	let g;
	try {
		g = parseGlb(readFileSync(f));
	} catch (e) {
		console.log(name.padEnd(27), "解析失败：" + String(e).slice(0, 60));
		continue;
	}
	const j = g.json;
	const accs = j.accessors || [];
	let tri = 0;
	const attrs = new Set();
	const bmin = [1e9, 1e9, 1e9];
	const bmax = [-1e9, -1e9, -1e9];
	for (const m of j.meshes || []) {
		for (const p of m.primitives || []) {
			for (const k of Object.keys(p.attributes || {})) attrs.add(k);
			const ia = accs[p.indices];
			if (ia !== undefined) tri += Math.floor(ia.count / 3);
			const pa = accs[p.attributes.POSITION];
			if (pa !== undefined && pa.min !== undefined) {
				for (let i = 0; i < 3; i++) {
					if (pa.min[i] < bmin[i]) bmin[i] = pa.min[i];
					if (pa.max[i] > bmax[i]) bmax[i] = pa.max[i];
				}
			}
		}
	}
	const hex = Math.max(Math.abs(bmin[0]), Math.abs(bmax[0]), Math.abs(bmin[1]), Math.abs(bmax[1]), Math.abs(bmin[2]), Math.abs(bmax[2]));
	const corner = Math.sqrt(bmax[0] * bmax[0] + bmax[1] * bmax[1] + bmax[2] * bmax[2]);
	const mats = (j.materials || []).map((m) => {
		const ds = m.doubleSided === true ? "双面" : "";
		const am = m.alphaMode !== undefined && m.alphaMode !== "OPAQUE" ? m.alphaMode : "";
		const tex = m.pbrMetallicRoughness !== undefined && m.pbrMetallicRoughness.baseColorTexture !== undefined ? "有贴图" : "无贴图";
		return [m.name || "?", ds, am, tex].filter((x) => x !== "").join("/");
	});
	const bbox = bmin.map((v, i) => v.toFixed(2) + ".." + bmax[i].toFixed(2)).join(",");
	console.log(
		name.padEnd(27),
		String(tri).padStart(5),
		[...attrs].sort().join(",").padEnd(16),
		String((j.images || []).length).padStart(3),
		String((j.materials || []).length).padStart(4),
		" " + bbox.padEnd(24),
		hex.toFixed(3).padStart(6),
		corner.toFixed(3).padStart(7),
		" " + mats.join(" | "),
	);
}
