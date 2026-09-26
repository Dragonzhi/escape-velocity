#!/usr/bin/env python3
"""按关卡数据生成"行星轨道圈"（S3.9：用户要求 —— 行星要动，所以得有轨道指示，不起眼的灰）。

与 Test/gen_orbit_assets.py 的分工：那个脚本烘的是**开场**的八条轨道（半径写死在 Opening.Stations）；
这个脚本烘的是**关卡**的轨道圈，半径从 game/LevelData.ts 的 ORBIT 表里解析（单一事实来源），
每个半径一个文件 Assets/Model/OrbitRing_<R>.gltf —— 半径就是世界单位，不做缩放
（缩放会把线宽一起放大，开场那次踩过）。

⚠️ 为什么不用 2D 画：2D 永远盖在 3D 之上，行星挡不住线（会话 27 的用户反馈正是这个）。

用法：python Test/gen_level_orbits.py
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_orbit_assets import make_orbit_rings  # noqa: E402  （复用同一个烘 mesh 的实现）

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def parse_level_orbits():
    """从 game/LevelData.ts 的 ORBIT 表解析轨道半径（顺序保留）。"""
    src = open(os.path.join(ROOT, "game", "LevelData.ts"), encoding="utf-8").read()
    m = re.search(r"const ORBIT = \{([^}]*)\}", src)
    if m is None:
        raise SystemExit("没有找到 ORBIT 表（game/LevelData.ts）")
    out = []
    for key, val in re.findall(r"(\w+)\s*:\s*([0-9.]+)", m.group(1)):
        out.append((key, float(val)))
    return out


def main():
    mdl = os.path.join(ROOT, "Assets", "Model")
    orbits = parse_level_orbits()
    seen = set()
    for name, r in orbits:
        if r in seen:
            continue
        seen.add(r)
        # 线宽/虚线随半径一起放大：屏幕上看起来一样粗（相机距离也随尺度变大）
        half = max(0.30, r * 0.006)
        dash_on = max(1.6, r * 0.023)
        dash_off = dash_on * 0.78
        path = os.path.join(mdl, "OrbitRing_%d.gltf" % int(round(r)))
        # make_orbit_rings 收的是 [(名字, 半径)] 列表（开场那边一次烘八条）
        make_orbit_rings(path, [(name, r)], half_width=half, dash_on=dash_on, dash_off=dash_off)
        print("ok  %-16s r=%6.1f half=%.2f dash=%.2f/%.2f" % (os.path.basename(path), r, half, dash_on, dash_off))
    print("共 %d 个轨道圈（来自 %s）" % (len(seen), ", ".join("%s=%g" % o for o in orbits)))


if __name__ == "__main__":
    main()
