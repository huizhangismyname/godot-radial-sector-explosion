class_name RadialSectorExplosion
extends Node

## 【整体逻辑位置】独立的目标排序式径向扇区爆炸求解器。
## 每次爆炸只执行一次圆形广域查询，再按目标合并、排序和结算。

const TARGET_LAYER: int = 1
const DISTANCE_LOSS_RATIO: float = 0.75
const DISTANCE_SEARCH_STEPS: int = 12
const MAX_QUERY_RESULTS: int = 4096

var last_sectors: Array[Dictionary] = []
var last_targets: Array[Dictionary] = []
var broad_phase_query_count: int = 0


func explode(
	center: Vector2,
	radius: float,
	sector_count: int,
	damage_per_sector: float
) -> Array[Dictionary]:
	if radius <= 0.0 or sector_count <= 0 or damage_per_sector <= 0.0:
		push_error("[RadialSectorExplosion] Radius, sector count and damage must be positive.")
		return []
	broad_phase_query_count = 0
	last_sectors = _create_sectors(sector_count, damage_per_sector)
	last_targets = _query_targets(center, radius, sector_count)
	for record: Dictionary in last_targets:
		_settle_target(record, last_sectors, radius)
	return last_sectors


func _create_sectors(count: int, damage: float) -> Array[Dictionary]:
	var sectors: Array[Dictionary] = []
	for sector_id: int in range(count):
		sectors.append({
			"sector_id": sector_id,
			"initial_damage": damage,
			"remaining_damage": damage,
			"current_distance": 0.0,
			"blocked": false,
		})
	return sectors


## 唯一物理范围查询；返回的多个Shape按Gameplay Target实例ID合并。
func _query_targets(center: Vector2, radius: float, sector_count: int) -> Array[Dictionary]:
	broad_phase_query_count += 1
	var circle := CircleShape2D.new()
	circle.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, center)
	query.collision_mask = TARGET_LAYER
	query.collide_with_bodies = true
	query.collide_with_areas = true
	var intersections: Array[Dictionary] = get_viewport().world_2d.direct_space_state.intersect_shape(
		query,
		MAX_QUERY_RESULTS
	)
	var records_by_id: Dictionary = {}
	for intersection: Dictionary in intersections:
		var collider := intersection["collider"] as CollisionObject2D
		if collider == null:
			continue
		var target: Object = _target_from_collider(collider)
		if target == null or not _target_available(target):
			continue
		var shape_data: Dictionary = _shape_data(collider, int(intersection["shape"]))
		if shape_data.is_empty():
			continue
		var target_id: int = target.get_instance_id()
		if not records_by_id.has(target_id):
			records_by_id[target_id] = {
				"target_id": target_id,
				"target": target,
				"nearest_distance": radius,
				"sector_ids": {},
			}
		var record: Dictionary = records_by_id[target_id]
		record["nearest_distance"] = minf(
			float(record["nearest_distance"]),
			_nearest_shape_distance(center, radius, shape_data)
		)
		_merge_shape_sectors(record["sector_ids"], center, shape_data, sector_count)
	var records: Array[Dictionary] = []
	for record: Dictionary in records_by_id.values():
		if not (record["sector_ids"] as Dictionary).is_empty():
			records.append(record)
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(float(a["nearest_distance"]), float(b["nearest_distance"])):
			return int(a["target_id"]) < int(b["target_id"])
		return float(a["nearest_distance"]) < float(b["nearest_distance"])
	)
	return records


func _target_from_collider(collider: CollisionObject2D) -> Object:
	if collider.has_method("get_explosion_target"):
		return collider.call("get_explosion_target") as Object
	return null


func _shape_data(collider: CollisionObject2D, global_shape_index: int) -> Dictionary:
	var owner_id: int = collider.shape_find_owner(global_shape_index)
	if owner_id < 0 or collider.is_shape_owner_disabled(owner_id):
		return {}
	for shape_id: int in range(collider.shape_owner_get_shape_count(owner_id)):
		if collider.shape_owner_get_shape_index(owner_id, shape_id) == global_shape_index:
			return {
				"shape": collider.shape_owner_get_shape(owner_id, shape_id),
				"transform": collider.global_transform * collider.shape_owner_get_transform(owner_id),
			}
	return {}


## 用扩张圆与真实Shape二分首次接触距离，不使用节点中心距离。
func _nearest_shape_distance(center: Vector2, radius: float, shape_data: Dictionary) -> float:
	var target_shape := shape_data["shape"] as Shape2D
	var target_transform := shape_data["transform"] as Transform2D
	var query_transform := Transform2D(0.0, center)
	var point_probe := CircleShape2D.new()
	point_probe.radius = 0.001
	if point_probe.collide(query_transform, target_shape, target_transform):
		return 0.0
	var low: float = 0.0
	var high: float = radius
	for _step: int in range(DISTANCE_SEARCH_STEPS):
		var middle: float = (low + high) * 0.5
		var probe := CircleShape2D.new()
		probe.radius = middle
		if probe.collide(query_transform, target_shape, target_transform):
			high = middle
		else:
			low = middle
	return high


## 从Shape边界的世界角度取得覆盖弧，再映射为Sector ID并集。
func _merge_shape_sectors(
	sector_set: Dictionary,
	center: Vector2,
	shape_data: Dictionary,
	sector_count: int
) -> void:
	var shape := shape_data["shape"] as Shape2D
	var transform := shape_data["transform"] as Transform2D
	var angles: Array[float] = _shape_boundary_angles(center, shape, transform)
	if angles.is_empty():
		return
	var point_probe := CircleShape2D.new()
	point_probe.radius = 0.001
	if point_probe.collide(Transform2D(0.0, center), shape, transform):
		for sector_id: int in range(sector_count):
			sector_set[sector_id] = true
		return
	angles.sort()
	var largest_gap: float = -1.0
	var gap_after: int = 0
	for index: int in range(angles.size()):
		var next_angle: float = angles[(index + 1) % angles.size()]
		if index == angles.size() - 1:
			next_angle += TAU
		var gap: float = next_angle - angles[index]
		if gap > largest_gap:
			largest_gap = gap
			gap_after = index
	var arc_start: float = angles[(gap_after + 1) % angles.size()]
	var arc_length: float = TAU - largest_gap
	var sector_angle: float = TAU / float(sector_count)
	for sector_id: int in range(sector_count):
		var sector_start: float = float(sector_id) * sector_angle - sector_angle * 0.5
		var sector_end: float = sector_start + sector_angle
		for wrap: int in range(-1, 2):
			var shifted_start: float = sector_start + float(wrap) * TAU
			var shifted_end: float = sector_end + float(wrap) * TAU
			if maxf(shifted_start, arc_start) <= minf(shifted_end, arc_start + arc_length):
				sector_set[sector_id] = true
				break
	if sector_set.is_empty():
		sector_set[floori(angles[0] / sector_angle) % sector_count] = true


func _shape_boundary_angles(center: Vector2, shape: Shape2D, transform: Transform2D) -> Array[float]:
	var local_points := PackedVector2Array()
	if shape is ConvexPolygonShape2D:
		local_points = (shape as ConvexPolygonShape2D).points
	elif shape is ConcavePolygonShape2D:
		local_points = (shape as ConcavePolygonShape2D).segments
	elif shape is RectangleShape2D:
		var half: Vector2 = (shape as RectangleShape2D).size * 0.5
		local_points = PackedVector2Array([
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y),
		])
	elif shape is CircleShape2D:
		var circle_radius: float = (shape as CircleShape2D).radius
		for index: int in range(32):
			local_points.append(Vector2.from_angle(TAU * index / 32.0) * circle_radius)
	elif shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var half_line: float = maxf((capsule.height - capsule.radius * 2.0) * 0.5, 0.0)
		for index: int in range(16):
			var angle: float = TAU * index / 16.0
			var cap_y: float = -half_line if sin(angle) < 0.0 else half_line
			local_points.append(Vector2(cos(angle), sin(angle)) * capsule.radius + Vector2(0.0, cap_y))
	elif shape is SegmentShape2D:
		local_points = PackedVector2Array([(shape as SegmentShape2D).a, (shape as SegmentShape2D).b])
	var angles: Array[float] = []
	for point: Vector2 in local_points:
		var offset: Vector2 = transform * point - center
		if not offset.is_zero_approx():
			angles.append(fposmod(offset.angle(), TAU))
	return angles


func _settle_target(record: Dictionary, sectors: Array[Dictionary], radius: float) -> void:
	var target: Object = record["target"]
	if not _target_available(target):
		return
	var distance: float = float(record["nearest_distance"])
	var active_sectors: Array[Dictionary] = []
	for sector_id: Variant in (record["sector_ids"] as Dictionary).keys():
		var sector: Dictionary = sectors[int(sector_id)]
		if bool(sector["blocked"]) or float(sector["remaining_damage"]) <= 0.0:
			continue
		_advance_sector(sector, distance, radius)
		if float(sector["remaining_damage"]) > 0.0:
			active_sectors.append(sector)
	if active_sectors.is_empty():
		return
	var modifier: float = _target_modifier(target)
	if not is_finite(modifier) or modifier <= 0.0:
		push_error("[RadialSectorExplosion] Target modifier must be finite and positive.")
		return
	var total_pool: float = 0.0
	for sector: Dictionary in active_sectors:
		total_pool += float(sector["remaining_damage"])
	var actual_damage: float = minf(_target_health(target), total_pool * modifier)
	var applied_damage: float = _apply_damage(target, actual_damage)
	if applied_damage <= 0.0:
		return
	var base_consumed: float = applied_damage / modifier
	for sector: Dictionary in active_sectors:
		var share: float = base_consumed * float(sector["remaining_damage"]) / total_pool
		sector["remaining_damage"] = maxf(float(sector["remaining_damage"]) - share, 0.0)
	if _target_blocks(target) and not _target_destroyed(target):
		for sector: Dictionary in active_sectors:
			sector["blocked"] = true


func _advance_sector(sector: Dictionary, new_distance: float, radius: float) -> void:
	var old_distance: float = float(sector["current_distance"])
	var delta_distance: float = maxf(new_distance - old_distance, 0.0)
	sector["remaining_damage"] = maxf(
		float(sector["remaining_damage"])
		- float(sector["initial_damage"]) * DISTANCE_LOSS_RATIO * delta_distance / radius,
		0.0
	)
	sector["current_distance"] = maxf(old_distance, new_distance)


func _target_available(target: Object) -> bool:
	return (
		is_instance_valid(target)
		and target.has_method("is_explosion_target_available")
		and bool(target.call("is_explosion_target_available"))
	)


func _target_destroyed(target: Object) -> bool:
	return not _target_available(target)


func _target_health(target: Object) -> float:
	if target.has_method("get_explosion_health"):
		return maxf(float(target.call("get_explosion_health")), 0.0)
	return 0.0


func _target_modifier(target: Object) -> float:
	if target.has_method("get_explosion_damage_modifier"):
		return float(target.call("get_explosion_damage_modifier"))
	return 1.0


func _target_blocks(target: Object) -> bool:
	if target.has_method("does_explosion_target_block"):
		return bool(target.call("does_explosion_target_block"))
	return true


func _apply_damage(target: Object, amount: float) -> float:
	if amount <= 0.0 or not target.has_method("receive_explosion_damage"):
		return 0.0
	return clampf(float(target.call("receive_explosion_damage", amount)), 0.0, amount)

