English version

Translation by GPT. Original concept and algorithm description by the author.

Target-Sorted Radial Sector Explosion

This is a lightweight layered explosion algorithm for 2D games. It is mainly designed to solve a problem with conventional circular AoE damage: it is difficult to correctly represent armor blocking, penetration, and damage to internal components.

The algorithm performs only one circular range query to collect all targets inside the explosion radius. These targets are then sorted from nearest to farthest based on the shortest geometric distance between each target and the explosion center.

The explosion itself is divided into multiple independent angular Sectors. Each target is mapped to one or more Sectors according to the angular range covered by its collision geometry.

Explosion

↓

Single circular range query

↓

Merge collision shapes by target ID

↓

Sort targets from nearest to farthest

↓

Determine which Sectors each target overlaps

↓

Resolve damage using the remaining damage of those Sectors

↓

Target survives → block the corresponding Sectors
Target destroyed → those Sectors continue propagating

Each Sector has its own independent Damage Pool, and its damage decreases according to the distance traveled from the explosion center.

Multiple Sectors may hit the same target at the same time. Their damage can be combined when resolving damage against that target, but the remaining energy is never redistributed between Sectors. Each Sector always keeps its own remaining damage, which preserves local armor protection and directional blocking.

The main purpose of this algorithm is to approximate blast propagation while still taking occlusion and penetration into account.

The Sector Density can be adjusted depending on the needs of the project. A higher density provides finer angular resolution and allows the explosion to distribute damage across more directions. A lower density produces a coarser and more simplified damage pattern, which may be useful for projects that do not require high precision.

For more complex collision geometry, the distance and Sector-overlap calculations can be extended with more accurate polygon-based tests. Complex scenes generally benefit from a higher Sector Density, since more angular samples provide a more detailed approximation of blast propagation.

The main goal of the algorithm is to allow blast energy to be blocked by objects while still allowing remaining energy to penetrate through destroyed structures and continue affecting targets behind them.

The same concept can also be adapted to 3D games. Instead of dividing a circle into 2D angular Sectors, the explosion volume can be divided into directional 3D cone sectors.

中文

这是一个用于 2D 游戏的轻量级分层爆炸算法，主要用于解决普通圆形 AoE 难以正确表现装甲遮挡、爆炸穿透以及内部模块受损的问题。

算法只进行一次圆形范围查询，取得爆炸半径内的所有目标，并根据目标碰撞几何到爆心的最近距离，从近到远进行排序。

爆炸本身被划分为多个独立的 Sector（扇区）。每个目标根据自身碰撞几何所覆盖的角度范围，映射到一个或多个 Sector。

Explosion

↓

一次圆形范围查询

↓

按目标 ID 合并 Collision Shape

↓

按照距离从近到远排序

↓

计算目标覆盖的 Sector

↓

使用这些 Sector 的剩余伤害进行结算

↓

目标存活 → 阻挡对应 Sector
目标摧毁 → Sector 继续向后传播

每个 Sector 都拥有独立的 Damage Pool，并根据爆炸传播距离产生伤害衰减。

多个 Sector 可以同时命中同一个目标。结算该目标时可以统计这些 Sector 的总伤害，但剩余能量不会在 Sector 之间重新分配。每个 Sector 始终保留自己的剩余伤害，因此局部装甲保护和不同方向的遮挡关系不会被破坏。

这个算法主要用于近似模拟爆炸波的传播，同时考虑遮挡和穿透。

可以根据项目需求调整 Sector Density（扇区密度）。较高的密度能够提供更精细的角度判断，使爆炸伤害在更多方向上进行分配；较低的密度则会得到更加粗略、简化的伤害分布，适合不需要高精度爆炸计算的项目。

对于复杂的碰撞几何，可以在距离计算和 Sector 覆盖判断中加入更精确的多边形检测。复杂场景通常也更适合使用较高的 Sector Density，以获得更细致的爆炸传播结果。

这个算法的核心目标，是让爆炸能够被前方结构遮挡，同时在结构被摧毁后，让对应方向上剩余的爆炸能量继续向后传播，从而形成自然的分层破坏与穿透效果。

同样的思路也可以扩展到 3D 项目中：将二维圆形中的 Sector 扩展为空间中的方向锥形区域，即可构建类似的 3D 爆炸传播模型。

<img width="512" height="512" alt="精灵-0002" src="https://github.com/user-attachments/assets/7561c8b4-8ab7-404d-a433-da0975fadd0c" />

爆炸产生时，1会先结算黄色区域所有的Sector伤害，然后再结算2受到的伤害，如果1吃掉了所有黄色区域的伤害那2就不会吃到红色区域的伤害，反之亦然。
