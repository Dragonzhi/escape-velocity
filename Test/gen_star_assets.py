# -*- coding: utf-8 -*-
"""星空资产生成器（Agent 侧运行，不进运行时）。

**2026-09-25 用户拍板采用方案 B（程序化星空贴图）**，放弃 C2（星点烤进网格壳）：
B 观感明显更好（软圆点 + 少量带十字光芒的亮星），且 70 KB / 2 三角面 / 1 draw call，
比 C2（180 KB / 1940 面）更小更省；横屏下 C2 的星点是明显的白色方块/菱形（截图为证）。
项目约束相应放宽：「零贴图」改为「**素材全部由本仓库代码生成，不引入第三方素材**」。

产出（即运行时采用的全部星空素材）：
  Assets/Image/starfield.png   2048x1024 等距圆柱星点图（PIL 程序化绘制）
  Assets/Model/StarQuad.gltf   自包含四边形（POSITION+NORMAL+TEXCOORD_0+uint16 索引，base64 data URI）
                               ⚠️ scale=1 时半边长就是 1（顶点 ±1），所以 **scale = 想要的半边长**

方案 C2 的生成代码（make_shell）已删除；需要时从 git 历史找回（38733a9 版本的本文件）。
烟雾测试结论与数据：.agent/test-results/s3-starfield.txt。

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
def make_starfield(path, w=1024, h=1024, stars=950, seed=20260924):
    """程序化星图（贴在 StarQuad 背板上，2026-09-25 起为运行时正式素材）。

    尺寸/密度按**游戏内截图**标定（.agent/test-results/s32-L1-aiming.png，会话 24）：
    首版 2048x1024 / 2600 颗 / r 0.6-3.4 在游戏里是"雪崩"——满屏 4-10px 的星点互相打架。
    贴图是 1:1 铺在方形背板上的：1 texel ≈ 2.3 屏幕像素（距离 600、fovY45、视高 1066），
    所以这里的 r 直接决定屏幕观感：0.3-0.5 → 1-2px 的暗星，0.85-1.4 → 3-4px 的亮星。
    """
    from PIL import Image, ImageDraw

    rng = random.Random(seed)
    img = Image.new("RGB", (w, h), (2, 3, 7))
    d = ImageDraw.Draw(img)

    for i in range(stars):
        if i < stars * 0.62:
            r, bright = rng.uniform(0.3, 0.5), rng.randint(70, 140)
        elif i < stars * 0.92:
            r, bright = rng.uniform(0.5, 0.85), rng.randint(140, 210)
        else:
            r, bright = rng.uniform(0.85, 1.4), rng.randint(210, 255)

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
        if r > 1.1:  # 少数亮星带十字光芒（首版阈值 2.6 是按 2 倍尺寸定的）
            d.line([x - r * 2.4, y, x + r * 2.4, y], fill=c)
            d.line([x, y - r * 2.4, x, y + r * 2.4], fill=c)

    img.save(path)
    return img.size


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


if __name__ == "__main__":
    assets = os.path.join(HERE, "..", "Assets")
    os.makedirs(os.path.join(assets, "Image"), exist_ok=True)
    print(make_starfield(os.path.join(assets, "Image", "starfield.png")), "starfield.png")
    make_quad(os.path.join(assets, "Model", "StarQuad.gltf"))
