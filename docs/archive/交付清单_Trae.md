# 交付清单 —— 模型升级（对应《模型交接_Trae.md》）

- 模型（含 UV）：`E:\BlenderWork\glb\*.glb`，对应源文件 `E:\BlenderWork\blend\*.blend`

> **接线状态（2026-09-27，我们这边）**：13 个 .glb 与 15 张贴图**已全部接进游戏并逐条核对**（`tools/glb-check.mjs`：
> 单位球 k=1.000 / UV 齐全 / images=0 / 环为双面 BLEND ✓）。行星贴图与环贴图已绑、地球夜面自发光已用、
> 两版探测器按 `probeVariant` 逐关切换（转轴 0.6495/0.6641、外接半径 1.084/0.871、共用 probe_atlas）。
> 唯一**没用上**的是 §C 的 7 个喷口锚点 —— 本作还没有粒子系统，等做尾焰时再接。
> 旧文件（`Probe_Body/Probe_Antenna/Probe_Voyager_v1`）保留未动，回退时改 `init.ts` 两行即可。
- 贴图（外部文件）：`E:\BlenderWork\textures\*`，拷入 `Assets/Image/` 即可（文件名已按 §3.6 全小写下划线）
- 本轮范围：行星系（含新增 Moon，另同步升级现有 Mars）、太阳、探测器两版（太阳能 / RTG）
- 全部 .glb 均为：glTF 2.0 binary、+Y Up、变换已应用（单位阵）、三角化；
  不含相机/灯光/空物体 —— 唯一例外是天线文件里作为转轴的 `Probe_Antenna`（§3.6 允许）

---

## A. §7 回报（先看这四条）

1. **是否内嵌贴图：否。** 所有 .glb 的 `images = 0`，只含几何 + UV（POSITION / NORMAL / TEXCOORD_0）。
   贴图全部走外部文件，可直接用 `Texture2D('Assets/Image/xxx')` 绑定。
2. **外接半径 k（scale=1 时）**：
   - 行星 / 月球 / 太阳：**k = 1.000**（单位球、球心在原点）
   - 带环行星：**k 只取本体 = 1.000**（环不参与标定；土星环 ±2.2、天王星环 ±1.95 仅视觉）
   - Probe_Solar_Body = **1.084**、Probe_RTG_Body = **0.871**、两个天线文件 = **0.361**
3. **朝向：与 §3.3 一致。** 探测器两根粗主杆沿 **+Z**、磁强计细杆沿 **-Z**（游戏里 -Z 朝前）
   → `ProbeYawOffsetDeg` 继续用 **-90**，无需改动。
   天线文件**原点 = 转轴**，静止（angleY=0）时**碟面法线 = 局部 +X**（已自检）。
   唯一需要更新的常量是 **AntennaPivotY：Solar 0.6495 / RTG 0.6641**。
4. **需要独立运动的子部件：无新增。** 每版探测器仍是"机体 + 天线"两个文件；
   机体文件内没有任何需要单独运动的子节点。

---

## B. 天体（9 个文件）

| 文件 | 三角面 | k | 环 | 贴图（尺寸） |
|---|---|---|---|---|
| Moon.glb | 5040 | 1.000 | — | moon.jpg 1024×512（环形山 + 月海暗斑） |
| Planet_Earth.glb | 5040 | 1.000 | — | planet_earth.jpg 2048×1024；planet_earth_emissive.png 2048×1024（夜面城市灯光，可选 emissiveTexture） |
| Planet_Venus.glb | 5040 | 1.000 | — | planet_venus.jpg 1024×512（硫酸云条纹） |
| Planet_Mars.glb | 5040 | 1.000 | — | planet_mars.jpg 1024×512（现有资产，一并升级） |
| Planet_Jupiter.glb | 5040 | 1.000 | — | planet_jupiter.jpg 1024×512（条带 + 大红斑） |
| Planet_Saturn.glb | 6192（本体 5040 + 环 1152） | 1.000 | **有**，xz 平面（法线 y），延伸 ±2.2 | planet_saturn.jpg 1024×512；planet_saturn_ring.png 512×8 |
| Planet_Uranus.glb | 5808（本体 5040 + 环 768） | 1.000 | **有**，xy 平面（法线 z，98° 轴倾），延伸 ±1.95 | planet_uranus.jpg 1024×512；planet_uranus_ring.png 512×8 |
| Planet_Neptune.glb | 5040 | 1.000 | — | planet_neptune.jpg 1024×512（大暗斑 + 云带） |
| Sun.glb | 6240 | 1.000 | — | sun.jpg 1024×512（米粒组织 + 黑子 + 边缘变暗；emissive 槽已按旧值写入） |

- UV 约定：等距圆柱。**U 沿经度环绕、接缝在 glTF +Z（背面）**；**V 沿纬度，北极 v=1 / 南极 v=0**（贴图第 0 行 = 北极）。
- 环 UV：**径向，U=0 内环 → U=1 外环**，V 沿圆周（配 1×N 条带，含缝隙与透明度）。
  环材质：doubleSided = true、alphaMode = BLEND（已实测导出正确）。

---

## C. 探测器（4 个文件）

| 文件 | 三角面 | k | 内容 |
|---|---|---|---|
| Probe_Solar_Body.glb | 940 | 1.084 | 总线舱 + MLI、桁架桅杆、太阳能板 ×2（含边框与加强肋）、相机 ×2、磁强计长杆、主推力器、RCS ×6 |
| Probe_Solar_Antenna.glb | 600 | 0.361 | 抛物面碟 + 馈源 + 3 根支撑杆（唯一空物体 `Probe_Antenna` 位于原点 = 转轴） |
| Probe_RTG_Body.glb | 1076 | 0.871 | 同上但无太阳能板，改为 RTG ×2（各 3 片散热鳍） |
| Probe_RTG_Antenna.glb | 600 | 0.361 | 与 Solar 天线相同 |

- **面数说明**：两版合计 1540 / 1676，**低于 §3.6 的 5k~12k 下限**。这是有意选择：探测器走
  "低模 + 1024² 细节贴图"路线（观感靠贴图与轮廓），更符合 §1 的包体压缩目标（17MB → 8MB）。
  若明确需要 5k+，可加密柱体段数与碟面细分再出一版。
- 尺寸：Solar 最长轴（Z）±0.87、RTG ±0.86，全在 ±1.0 内。
- 原点：**x = z = 0**（保证天线枢轴落在模型 Y 轴上）；y 仅按顶点质心下移
  （Solar 0.0905 / RTG 0.0759）以近似重心，缩放不跑位。
- 朝向细节：主杆（太阳能板 / RTG）朝 **+Z**；磁强计细杆与相机朝 **-Z**；
  主推力器与 6 个 RCS 在总线后端，**喷口朝 +Z**。
- 材质：沿用旧工程参数 `Probe_White / Gold / Alu / Gray / Dark / Black`（纯色 Principled，Roughness 1、Metallic 0），
  新增 1 个 `Probe_Panel`（太阳能电池板底色 0.055, 0.085, 0.190）。
  贴图用法：`probe_atlas.jpg` 作为 baseColorTexture（灰度细节，与材质颜色相乘）。
- **AntennaPivotY = 0.6495（Solar）/ 0.6641（RTG）**：把天线文件放到机体局部
  `(0, AntennaPivotY, 0)`、作为机体根的子节点即可（侧向偏移为 0，天线已在机体 Y 轴上）。

### 喷口粒子锚点（机体局部坐标 = 导出 glb 坐标；方向一律 +Z）

机体文件内**不含空节点**（§3.6 要求），位置以常量给出：

| 锚点 | Probe_Solar_Body | Probe_RTG_Body |
|---|---|---|
| Probe_FX_Thruster（主推力器喷口） | (0.000, -0.090, 0.300) | (0.000, -0.076, 0.300) |
| Probe_FX_RCS_1 | (0.220, -0.090, 0.270) | (0.220, -0.076, 0.270) |
| Probe_FX_RCS_2 | (0.110, 0.100, 0.270) | (0.110, 0.115, 0.270) |
| Probe_FX_RCS_3 | (-0.110, 0.100, 0.270) | (-0.110, 0.115, 0.270) |
| Probe_FX_RCS_4 | (-0.220, -0.090, 0.270) | (-0.220, -0.076, 0.270) |
| Probe_FX_RCS_5 | (-0.110, -0.281, 0.270) | (-0.110, -0.266, 0.270) |
| Probe_FX_RCS_6 | (0.110, -0.281, 0.270) | (0.110, -0.266, 0.270) |

---

## D. 探测器贴图图集分区（probe_atlas.jpg，1024×1024）

所有零件 UV 已归一化后映射进对应分区（四周 2% 内缩），两版探测器共用同一张图。
分区矩形按 UV 坐标 `(x0, y0, x1, y1)`：

| 分区 | 内容 | 对应材质 |
|---|---|---|
| (0.00, 0.50) – (0.25, 1.00) | 电池片栅格（8×8 + 主栅线） | Probe_Panel |
| (0.25, 0.50) – (0.50, 1.00) | 金箔褶皱 | Probe_Gold |
| (0.50, 0.50) – (0.75, 1.00) | 白毯细纹 + 拼缝 | Probe_White |
| (0.75, 0.50) – (1.00, 1.00) | 拉丝铝 | Probe_Alu |
| (0.00, 0.00) – (0.25, 0.50) | 灰板拼缝 + 铆钉 | Probe_Gray |
| (0.25, 0.00) – (0.50, 0.50) | 暗件细噪 | Probe_Dark |
| (0.50, 0.00) – (0.75, 0.50) | 相机（近黑） | Probe_Black |
| (0.75, 0.00) – (1.00, 0.50) | 备用（平灰，未使用） | — |

---

## E. 贴图文件清单（E:\BlenderWork\textures\）

| 文件 | 尺寸 | 用途 |
|---|---|---|
| moon.jpg | 1024×512 | Moon baseColor |
| planet_earth.jpg | 2048×1024 | 地球 baseColor |
| planet_earth_emissive.png | 2048×1024 | 地球夜面灯光（emissiveTexture，可选） |
| planet_venus.jpg / planet_mars.jpg / planet_jupiter.jpg | 1024×512 | 各自 baseColor |
| planet_saturn.jpg / planet_uranus.jpg / planet_neptune.jpg | 1024×512 | 各自 baseColor |
| planet_saturn_ring.png / planet_uranus_ring.png | 512×8 | 环条带（径向 U，含透明缝隙） |
| sun.jpg | 1024×512 | 太阳表面 |
| probe_atlas.jpg | 1024×1024 | 两版探测器共用细节图集 |

---

## F. 引擎侧需要更新的常量 / 绑定

- `ProbeYawOffsetDeg = -90` —— **不变**
- `AntennaPivotY`：**Solar 0.6495、RTG 0.6641**（新值，替换旧值）
- 行星：baseColorTexture = 对应 planet_*.jpg；地球夜面 emissiveTexture = planet_earth_emissive.png
- 土星 / 天王星环：材质需 alphaMode = Blend、doubleSided；贴图 **U=0 内环 → U=1 外环**
- 探测器：`probe_atlas.jpg` 绑定到 7 个材质的 baseColorTexture（UV 已按分区排好，直接用同一张图）

---

## G. 旧文件与备份

- 旧命名**保留未覆盖**（回退用，本轮未改动）：`Probe_Body.glb`、`Probe_Antenna.glb`、`Probe_Voyager_v1.glb`
- 本批升级前的版本已备份为 `*_pre-uv.glb` / `*_pre-uv.blend`
  （如 Planet_Earth_pre-uv.glb、Moon_pre-uv.glb、Sun_pre-uv.glb、Probe_Solar_Body_pre-uv.glb …），需要回退直接改名即可
- `Asteroid_01.glb`、`BlackHole.glb` 不在本次交接文档范围内，未改动

---

## H. §5 自检核对（全部通过）

- 单位球半径 1.0、球心在原点；探测器最长轴 ≤ ±1.0 —— 通过
- 所有网格 UV 齐全（导出后重导入复验：UV = 全有）—— 通过
- 变换为单位阵、+Y Up、三角化 —— 通过
- 无相机 / 灯光；空物体仅天线文件的 `Probe_Antenna` —— 通过
- 面数：行星 5040（预算 4k~8k）、太阳 6240（≤8k）、环 1152 / 768（≤2k）；
  探测器 940+600 / 1076+600（低于 5k 下限，原因见 C）—— 符合或已说明
- 贴图尺寸：行星 1024×512（地球 2048×1024，§3.6 允许）、太阳 1024×512、探测器 1024×1024、环 512×8 —— 符合
- 环平面：土星 xz（法线 y）/ 天王星 xy（法线 z），材质 Blend + doubleSided —— 通过
- 命名：Planet_* / Moon / Sun / Probe_Solar_* / Probe_RTG_*，与 §3.5 完全一致 —— 通过