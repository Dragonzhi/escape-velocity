import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const root = path.resolve("../../");
const outDir = process.argv[2] || "out";
const brief = process.argv.includes("--brief");
const sha = (b) => crypto.createHash("sha256").update(b).digest("hex").slice(0, 16);

const luaFiles = [];
const walk = (dir) => {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.isDirectory()) {
      if (["node_modules", ".git", ".temp", ".agent", ".kilo", "dist", "build"].includes(e.name)) continue;
      walk(path.join(dir, e.name));
    } else if (e.name.endsWith(".lua")) luaFiles.push(path.join(dir, e.name));
  }
};
walk(root);
luaFiles.sort();

let same = 0, diff = 0, missing = 0, nots = 0;
const diffList = [];
for (const lua of luaFiles) {
  const rel = path.relative(root, lua);
  const ts = lua.replace(/\.lua$/, ".ts");
  if (!fs.existsSync(ts)) { nots++; if (!brief) console.log("  [no-ts ] " + rel); continue; }
  const gen = path.join(path.resolve(outDir), rel);
  if (!fs.existsSync(gen)) { missing++; console.log("  [miss  ] " + rel); continue; }
  const A = fs.readFileSync(lua), B = fs.readFileSync(gen);
  if (A.equals(B)) { same++; if (!brief) console.log("  [ ==   ] " + rel + "  " + A.length + "B  sha=" + sha(A)); }
  else {
    diff++;
    const la = A.toString("utf8").split("\n"), lb = B.toString("utf8").split("\n");
    let first = -1;
    for (let i = 0; i < Math.max(la.length, lb.length); i++) if (la[i] !== lb[i]) { first = i; break; }
    diffList.push({ rel, linesA: la.length, linesB: lb.length, first: first + 1, a: la[first], b: lb[first] });
    console.log("  [ DIFF ] " + rel + "  首个不一致行 " + (first + 1));
    console.log("           committed: " + JSON.stringify(la[first]));
    console.log("           generated: " + JSON.stringify(lb[first]));
  }
}
console.log("\n汇总: 相同 " + same + " / 不同 " + diff + " / 未生成 " + missing + " / 无对应 .ts " + nots + "   (总计 " + luaFiles.length + ")");
