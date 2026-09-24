import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const [a, b] = process.argv.slice(2);
const A = fs.readFileSync(a);
const B = fs.readFileSync(b);
const sha = (x) => crypto.createHash("sha256").update(x).digest("hex");
console.log("A " + a + "  " + A.length + " B  sha256=" + sha(A));
console.log("B " + b + "  " + B.length + " B  sha256=" + sha(B));
console.log("byte-equal: " + (A.equals(B) ? "YES" : "NO"));
if (A.equals(B)) process.exit(0);

const la = A.toString("utf8").split("\n");
const lb = B.toString("utf8").split("\n");
console.log("lines A=" + la.length + " B=" + lb.length);
const n = Math.max(la.length, lb.length);
let first = -1;
for (let i = 0; i < n; i++) {
  if (la[i] !== lb[i]) { first = i; break; }
}
console.log("first differing line: " + (first + 1));
for (let i = Math.max(0, first - 3); i < Math.min(n, first + 6); i++) {
  const x = la[i] === undefined ? "<none>" : la[i];
  const y = lb[i] === undefined ? "<none>" : lb[i];
  const mark = x === y ? "  " : "!!";
  console.log(mark + " " + String(i + 1).padStart(4) + " A: " + JSON.stringify(x));
  console.log(mark + " " + String(i + 1).padStart(4) + " B: " + JSON.stringify(y));
}

// 归一化比较：去掉 A 侧的标记（"-- [ts]: ..." 头和行尾 " -- N"）后与 B 比较
const strip = (lines) => lines
  .filter((l, i) => !(i === 0 && /^-- \[[a-z]+\]: /.test(l)))
  .map((l) => l.replace(/ -- \d+$/, ""))
  .filter((l) => l.trim() !== "");
const sa = strip(la), sb = lb.filter((l) => l.trim() !== "");
console.log("\n--- 归一化(去标记/去空行)后 A=" + sa.length + " 行, B=" + sb.length + " 行 ---");
let f2 = -1;
for (let i = 0; i < Math.max(sa.length, sb.length); i++) if (sa[i] !== sb[i]) { f2 = i; break; }
console.log("first differing line (normalized): " + (f2 + 1));
for (let i = Math.max(0, f2 - 2); i < Math.min(Math.max(sa.length, sb.length), f2 + 5); i++) {
  console.log("  " + String(i + 1).padStart(4) + " A: " + JSON.stringify(sa[i] === undefined ? "<none>" : sa[i]));
  console.log("  " + String(i + 1).padStart(4) + " B: " + JSON.stringify(sb[i] === undefined ? "<none>" : sb[i]));
}
