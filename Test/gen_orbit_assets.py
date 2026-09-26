
# -*- coding: utf-8 -*-
"""开场/S3.3 的新资产生成器（Agent 侧运行，不进运行时）。

背景（用户 2026-09-26 对开场的五条反馈里，第 4、5 条要求换做法）：
  4) 轨道线与行星的遮挡关系错了 —— 2D 虚线永远盖在 3D 之上，行星挡不住线。
     ⇒ 轨道改成**真 3D 网格**（把八条轨道烘成一个 mesh，1 draw call），深度缓冲自然遮挡；
       同时把线压暗（材质 emissive 一个旋钮），不再抢戏。
  5) 星空用的是一个"钉在相机前方的面片"，相机换角度（开场从全景俯冲到特写、方位角转了 60°+）
     时会明显拉伸/透视错位。⇒ 改成**世界尺度的天球**（球面上等距圆柱映射），
     并且每帧把球心挪到相机位置 —— 这样旋转会带着星空转、平移不会产生视差（= 真实无穷远星空）。

产出：
  Assets/Image/starfield.png      2048x1024 等距圆柱星点图（球面密度均匀，两极不堆积）
  Assets/Model/StarSphere.gltf    单位球（半径 1，双面材质，UV = 经纬），runtime 里 scale 到天球半径
  Assets/Model/OrbitRings.gltf    八条轨道虚线圈烘成一个 mesh（xz 平面，y=0，半径与世界单位一致）

⚠️ 轨道半径**从 game/Opening.ts 的 Stations 表解析**（单一事实来源，避免两边各写一份）。
⚠️ StarQuad.gltf / 旧的 1024² starfield.png 已被取代，但保留在仓库里作回退（见 createStarBackdrop）。

用法：python Test/gen_orbit_assets.py
"""
import base64
import json
import math
import os
import random
import re
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.normpath(os.path.join(HERE, ".."))


# ---------------------------------------------------------------- glTF
def write_gltf(path, name, positions, normals, uvs, indices, color, emissive=(0.0, 0.0, 0.0), double_sided=True, bounds=None):
    pos = b"".join(struct.pack("<f", v) for v in positions)
    nrm = b"".join(struct.pack("<f", v) for v in normals)
    uvb = b"".join(struct.pack("<f", v) for v in uvs)
    idxfmt = "<I" if max(indices) > 65535 else "<H"
    idx = b"".join(struct.pack(idxfmt, v) for v in indices)
    vcount, icount = len(positions) // 3, len(indices)
    off_uv, off_idx = len(pos) + len(nrm), len(pos) + len(nrm) + len(uvb)
    if bounds is None:
        lo = [round(min(positions[a::3]), 6) for a in range(3)]
        hi = [round(max(positions[a::3]), 6) for a in range(3)]
    else:
        lo = [round(v, 6) for v in bounds[0]]
        hi = [round(v, 6) for v in bounds[1]]

    doc = {
        "asset": {"version": "2.0", "generator": "escape-velocity orbit/sky asset generator"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": name}],
        "meshes": [{"name": name, "primitives": [{
            "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
            "indices": 3, "material": 0}]}],
        "materials": [{"name": "Flat", "doubleSided": double_sided,
                       "emissiveFactor": [emissive[0], emissive[1], emissive[2]],
                       "pbrMetallicRoughness": {
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
            {"bufferView": 0, "componentType": 5126, "count": vcount, "type": "VEC3", "min": lo, "max": hi},
            {"bufferView": 1, "componentType": 5126, "count": vcount, "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": vcount, "type": "VEC2"},
            {"bufferView": 3, "componentType": 5123 if idxfmt == "<H" else 5125, "count": icount, "type": "SCALAR"},
        ],
    }
    text = json.dumps(doc, indent=1)
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    print("%-26s bytes=%6d verts=%5d tris=%5d" % (os.path.basename(path), len(text), vcount, icount // 3))


# ---------------------------------------------------------------- 星点贴图
def make_starfield(path, w=2048, h=1024, stars=6200, seed=20260926):
    """等距圆柱星点图（贴在天球内壁上）。

    密度标定：天球半径只影响视差、不影响角密度；**贴图宽度决定 1 texel 占多少度**。
    2048 宽 ⇒ 1 texel ≈ 0.176°；游戏里 45° 垂直视野占 1066 px ⇒ 1 texel ≈ 4.2 px。
    所以星点半径取 0.35–1.5 texel（屏幕上 1.5–6 px），亮度沿用方案 B 的经验值。
    """
    from PIL import Image, ImageDraw

    rng = random.Random(seed)
    img = Image.new("RGB", (w, h), (2, 3, 7))
    d = ImageDraw.Draw(img)

    for i in range(stars):
        if i < stars * 0.62:
            r, bright = rng.uniform(0.35, 0.55), rng.randint(70, 140)
        elif i < stars * 0.92:
            r, bright = rng.uniform(0.55, 0.95), rng.randint(140, 210)
        else:
            r, bright = rng.uniform(0.95, 1.5), rng.randint(210, 255)

        x = rng.uniform(0, w)
        y = math.degrees(math.asin(rng.uniform(-1, 1)))          # 球面均匀 ⇒ 两极不堆积
        y = (90.0 - y) / 180.0 * h

        t = rng.random()
        if t < 0.7:
            c = (bright, bright, min(255, int(bright * 1.06)))
        elif t < 0.9:
            c = (min(255, int(bright * 1.05)), min(255, int(bright * 0.98)), bright)
        else:
            c = (bright, min(255, int(bright * 0.92)), min(255, int(bright * 0.80)))

        d.ellipse([x - r, y - r, x + r, y + r], fill=c)
        if r > 1.15:
            d.line([x - r * 2.2, y, x + r * 2.2, y], fill=c)
            d.line([x, y - r * 2.2, x, y + r * 2.2], fill=c)
    img.save(path)
    return img.size


# ---------------------------------------------------------------- 天球
def make_sky_sphere(path, seg_u=48, seg_v=24):
    """单位球（半径 1）：UV = 经纬（u = 经度/360，v = 纬度/180），双面材质。

    runtime 里 scale 到天球半径（1200），**并且每帧把球心挪到相机位置** —— 于是
    旋转会带着星空一起转（正确），平移不产生视差（等价于无穷远，也是正确）。
    UV 球在极点处三角退化不影响观感（那里是零面积的极点行）。
    """
    positions, normals, uvs, indices = [], [], [], []
    for iv in range(seg_v + 1):
        v = iv / seg_v
        phi = v * math.pi            # 0 = 北极
        sin_p, cos_p = math.sin(phi), math.cos(phi)
        for iu in range(seg_u + 1):
            u = iu / seg_u
            theta = u * 2.0 * math.pi
            x, y, z = sin_p * math.cos(theta), cos_p, sin_p * math.sin(theta)
            positions += [x, y, z]
            normals += [x, y, z]
            uvs += [u, 1.0 - v]
    row = seg_u + 1
    for iv in range(seg_v):
        for iu in range(seg_u):
            a = iv * row + iu
            b = a + 1
            c = a + row
            dd = c + 1
            indices += [a, c, b, b, c, dd]
    write_gltf(path, "StarSphere", positions, normals, uvs, indices, (0.0, 0.0, 0.0),
               emissive=(1.0, 1.0, 1.0))


# ---------------------------------------------------------------- 轨道虚线圈
def parse_orbits():
    """从 game/Opening.ts 的 Stations 表里读轨道半径（单一事实来源）。"""
    src = open(os.path.join(PROJ, "game", "Opening.ts"), encoding="utf-8").read()
    hits = re.findall(r"model:\s*'([A-Za-z_]+)',\s*radius:\s*([0-9.]+),\s*orbit:\s*([0-9.]+)", src)
    out = [(name, float(orbit)) for name, _r, orbit in hits]
    if not out:
        raise SystemExit("没解析到 Stations 表（game/Opening.ts 的写法变了？）")
    return out


def make_orbit_rings(path, orbits, half_width=0.11, dash_on=1.25, dash_off=0.95):
    """把每条轨道烘成"虚线圈"：在 y=0 平面上、沿圆周等弧长切段的小四边形。

    - **半径就是世界单位**（不做缩放）⇒ 线宽在任何一条轨道上都是 half_width（缩放会把线宽一起放大）。
    - 弧长恒定（不是角度恒定）⇒ 内圈外圈的虚线段看起来一样长。
    - 八条烘成一个 mesh ⇒ 1 draw call；材质走 emissive，观感不受光照影响、可整体调暗。
    """
    positions, normals, uvs, indices = [], [], [], []
    for _name, radius in orbits:
        step = dash_on + dash_off
        count = max(8, int(round(2.0 * math.pi * radius / step)))
        arc = 2.0 * math.pi / count
        on_frac = dash_on / step
        for k in range(count):
            a0 = k * arc
            a1 = a0 + arc * on_frac
            for a in (a0, a1):
                ca, sa = math.cos(a), math.sin(a)
                # ⚠️ 线宽必须沿**半径方向**铺（(radius ± half_width)·(cos a, sin a)）。
                # 首版错铺在切线方向 ⇒ 两个维度落在同一根轴上，四边形面积归零，画面里**什么都看不到**
                # （不是没加载、也不是被剔除：日志里 rings=ok，但屏幕上一条线都没有）。
                for s in (-1.0, 1.0):
                    rr = radius + half_width * s
                    positions += [ca * rr, 0.0, sa * rr]
                    normals += [0.0, 1.0, 0.0]
                    uvs += [0.0, 0.0]
            base = len(positions) // 3 - 4
            # ⚠️ 每个 dash **正反两面都写一遍**（各 2 个三角形）：材质虽然声明了 doubleSided，
            # 但实测引擎对单面材质仍然背面剔除 —— 只写一面时从相机这一侧看就什么都没有
            # （2026-09-26 实测：日志 rings=ok、几何非退化，屏幕上却一条线都没有）。
            indices += [base, base + 1, base + 2, base + 1, base + 3, base + 2]
            indices += [base, base + 2, base + 1, base + 1, base + 2, base + 3]
    # ⚠️ 环全在 y = 0 平面上 ⇒ 包围盒高度为 0。退化包围盒有被剔除/算错的风险，
    # 这里给数据的 min/max 留一点余量（只影响剔除判定，不影响几何）。
    pad = 0.5
    lo = [min(positions[a::3]) - pad for a in range(3)]
    hi = [max(positions[a::3]) + pad for a in range(3)]
    write_gltf(path, "OrbitRings", positions, normals, uvs, indices, (0.0, 0.0, 0.0),
               emissive=(1.0, 1.0, 1.0), bounds=(lo, hi))


if __name__ == "__main__":
    img_dir = os.path.join(PROJ, "Assets", "Image")
    mdl_dir = os.path.join(PROJ, "Assets", "Model")
    os.makedirs(img_dir, exist_ok=True)
    print(make_starfield(os.path.join(img_dir, "starfield.png")), "starfield.png")
    make_sky_sphere(os.path.join(mdl_dir, "StarSphere.gltf"))
    orbits = parse_orbits()
    print("orbits parsed from game/Opening.ts:", orbits)
    make_orbit_rings(os.path.join(mdl_dir, "OrbitRings.gltf"), orbits)
