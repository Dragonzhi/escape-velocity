# -*- coding: utf-8 -*-
"""一次性资产生成器（Agent 侧运行，不进运行时）：S3 星空候选 B/C 的素材。

产出：
  Assets/Model/StarShell.gltf        单个网格烤进 N 个四边形（远处球壳，1 个 draw call）—— **已采用（方案 C2）**
  Assets/Model/StarShellBright.gltf  同上，少量暖色亮星（再加 1 个 draw call）—— **已采用**
  Test/starfield.png                 2048x1024 等距圆柱星点图（PIL 程序化绘制，零外部素材）
  Test/white1x1.png                  1x1 纯白（自定义 shader 的兜底纹理）
  Test/StarQuad.gltf                 自包含四边形（POSITION+NORMAL+TEXCOORD_0+uint16 索引，base64 data URI）

后三项是**方案 B（把星空贴图贴到一个四边形上）**的素材：2026-09-24 的烟雾测试里 B 也能跑通
（draws 4→5、三角面 260→262、58–70 KB），但当时选了 C2，所以它们不参与构建、只作为
"想换 B 时一条命令就能生成"的备份留着。结论与数据见 .agent/test-results/s3-starfield.txt。

用法：python Test/gen_star_assets.py
"""
import base64
import json
import math
import os
import random
import struct

HERE = os.path.dirname(os.path.abspath(__file__))


# ---------------------------------------------------------------- 星点贴图
def make_starfield(path, w=2048, h=1024, stars=2600, seed=20260924):
    from PIL import Image, ImageDraw

    rng = random.Random(seed)
    img = Image.new("RGB", (w, h), (2, 3, 7))
    d = ImageDraw.Draw(img)

    for i in range(stars):
        if i < stars * 0.62:
            r, bright = rng.uniform(0.6, 1.1), rng.randint(60, 130)
        elif i < stars * 0.92:
            r, bright = rng.uniform(1.1, 2.0), rng.randint(130, 210)
        else:
            r, bright = rng.uniform(2.0, 3.4), rng.randint(210, 255)

        x = rng.uniform(0, w)
        y = math.degrees(math.asin(rng.uniform(-1, 1)))   # 等距圆柱：两极不堆积
        y = (90.0 - y) / 180.0 * h

        t = rng.random()
        if t < 0.7:
            c = (bright, bright, min(255, int(bright * 1.06)))
        elif t < 0.9:
            c = (min(255, int(bright * 1.05)), min(255, int(bright * 0.98)), bright)
        else:
            c = (bright, min(255, int(bright * 0.92)), min(255, int(bright * 0.80)))

        d.ellipse([x - r, y - r, x + r, y + r], fill=c)
        if r > 2.6:  # 亮星带一点十字光芒
            d.line([x - r * 2.2, y, x + r * 2.2, y], fill=c)
            d.line([x, y - r * 2.2, x, y + r * 2.2], fill=c)

    img.save(path)
    return img.size


def make_white(path):
    from PIL import Image
    Image.new("RGB", (1, 1), (255, 255, 255)).save(path)


# ---------------------------------------------------------------- glTF
def write_gltf(path, name, positions, normals, uvs, indices, color):
    pos = b"".join(struct.pack("<f", v) for v in positions)
    nrm = b"".join(struct.pack("<f", v) for v in normals)
    uvb = b"".join(struct.pack("<f", v) for v in uvs)
    idxfmt = "<I" if max(indices) > 65535 else "<H"
    idx = b"".join(struct.pack(idxfmt, v) for v in indices)
    vcount, icount = len(positions) // 3, len(indices)
    off_uv, off_idx = len(pos) + len(nrm), len(pos) + len(nrm) + len(uvb)

    lo = [round(min(positions[a::3]), 6) for a in range(3)]
    hi = [round(max(positions[a::3]), 6) for a in range(3)]

    doc = {
        "asset": {"version": "2.0", "generator": "escape-velocity star asset generator"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": name}],
        "meshes": [{"name": name, "primitives": [{
            "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
            "indices": 3, "material": 0}]}],
        "materials": [{"name": "Flat", "doubleSided": True, "pbrMetallicRoughness": {
            "baseColorFactor": [color[0], color[1], color[2], 1],
            "metallicFactor": 0, "roughnessFactor": 1.0}}],
        "buffers": [{"byteLength": off_idx + len(idx),
                     "uri": "data:application/octet-stream;base64,"
                            + base64.b64encode(pos + nrm + uvb + idx).decode("ascii")}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(pos), "target": 34962},
            {"buffer": 0, "byteOffset": len(pos), "byteLength": len(nrm), "target": 34962},
            {"buffer": 0, "byteOffset": off_uv, "byteLength": len(uvb), "target": 34962},
            {"buffer": 0, "byteOffset": off_idx, "byteLength": len(idx), "target": 34963},
        ],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": vcount, "type": "VEC3",
             "min": lo, "max": hi},
            {"bufferView": 1, "componentType": 5126, "count": vcount, "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": vcount, "type": "VEC2"},
            {"bufferView": 3, "componentType": 5123 if idxfmt == "<H" else 5125,
             "count": icount, "type": "SCALAR"},
        ],
    }
    text = json.dumps(doc, indent=1)
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    print("%-24s bytes=%d verts=%d tris=%d" % (os.path.basename(path), len(text), vcount, icount // 3))


def make_quad(path):
    positions = [-1, -1, 0, 1, -1, 0, 1, 1, 0, -1, 1, 0]
    normals = [0, 0, 1] * 4
    uvs = [0, 1, 1, 1, 1, 0, 0, 0]
    write_gltf(path, "StarQuad", positions, normals, uvs, [0, 1, 2, 0, 2, 3], (1.0, 1.0, 1.0))


def make_shell(path, count=240, seed=20260924, rmin=200.0, rmax=380.0,
               smin=1.2, smax=3.6, color=(1.0, 1.0, 1.0)):
    """把 count 个四边形烤进**一个**网格：球壳分布、法线朝球心、单 draw call。"""
    rng = random.Random(seed)
    positions, normals, uvs, indices = [], [], [], []

    for _ in range(count):
        az = rng.uniform(0, 2 * math.pi)
        el = math.asin(rng.uniform(-1, 1))
        r = rng.uniform(rmin, rmax)
        cx = r * math.cos(el) * math.cos(az)
        cy = r * math.sin(el)
        cz = r * math.cos(el) * math.sin(az)

        # 朝球心：法线 n = -(c)/|c|，构造正交基
        nx, ny, nz = -cx / r, -cy / r, -cz / r
        upx, upy, upz = 0.0, 1.0, 0.0
        tx = upy * nz - upz * ny
        ty = upz * nx - upx * nz
        tz = upx * ny - upy * nx
        tl = math.sqrt(tx * tx + ty * ty + tz * tz)
        if tl < 1e-4:
            tx, ty, tz = 1.0, 0.0, 0.0
        else:
            tx, ty, tz = tx / tl, ty / tl, tz / tl
        bx = ny * tz - nz * ty
        by = nz * tx - nx * tz
        bz = nx * ty - ny * tx

        s = rng.uniform(smin, smax)
        base = len(positions) // 3
        for (su, sv) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            positions += [cx + (tx * su + bx * sv) * s,
                          cy + (ty * su + by * sv) * s,
                          cz + (tz * su + bz * sv) * s]
            normals += [nx, ny, nz]
        uvs += [0, 1, 1, 1, 1, 0, 0, 0]
        indices += [base, base + 1, base + 2, base, base + 2, base + 3]

    write_gltf(path, "StarShell", positions, normals, uvs, indices, color)


if __name__ == "__main__":
    print(make_starfield(os.path.join(HERE, "starfield.png")), "starfield.png")
    make_white(os.path.join(HERE, "white1x1.png"))
    print("white1x1.png 1x1")
    make_quad(os.path.join(HERE, "StarQuad.gltf"))
    # 星空壳（S3.2，烟雾测试选定 C2：把星点烤进一个网格 = 1 draw call、零贴图、深度天然正确）
    # 尺寸要按"屏幕像素"反推：距离 r 处的 s 单位张角 ≈ s/r 弧度，视高 1066 px / FOV 45° 时
    # s=0.30~0.85 @ r=150~380 约等于 1~4 像素 —— 看起来才是星点而不是方块（初版 s=1.2~3.6 约 24 像素，
    # 截图上是明显的白方块，已按此修正）。
    # 直接写进 Assets/Model/（模型资产的唯一位置；Test/ 下的副本已删除，避免两处不一致）
    assets = os.path.join(HERE, "..", "Assets", "Model")
    make_shell(os.path.join(assets, "StarShell.gltf"), count=900, rmin=150.0, rmax=380.0,
               smin=0.30, smax=0.85, color=(0.86, 0.89, 1.0))
    # 少量暖色亮星：给星空层次，代价只是多 1 个 draw call
    make_shell(os.path.join(assets, "StarShellBright.gltf"), count=70, seed=7, rmin=120.0, rmax=340.0,
               smin=0.9, smax=1.8, color=(1.0, 0.95, 0.82))
