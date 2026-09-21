class_name DemoExplosionTarget
extends StaticBody2D

## 【整体逻辑位置】独立演示项目使用的最小爆炸目标。

var target_id: int = 0
var max_health: float = 100.0
var current_health: float = 100.0
var shape_kind: StringName = &"rectangle"
var display_color: Color = Color("8c6548")


func configure(new_id: int, kind: StringName, health: float) -> void:
	target_id = new_id
	shape_kind = kind
	max_health = health
	current_health = health
	# 与独立求解器的TARGET_LAYER保持一致，避免目标脚本依赖全局类缓存。
	collision_layer = 1
	collision_mask = 0
	_build_shapes()
	queue_redraw()


func get_explosion_target() -> Object:
	return self


func is_explosion_target_available() -> bool:
	return current_health > 0.0


func get_explosion_health() -> float:
	return current_health


func get_explosion_damage_modifier() -> float:
	return 1.0


func does_explosion_target_block() -> bool:
	return true


func receive_explosion_damage(amount: float) -> float:
	var applied: float = minf(maxf(amount, 0.0), current_health)
	current_health -= applied
	queue_redraw()
	return applied


func _build_shapes() -> void:
	match shape_kind:
		&"wide_rectangle":
			_add_shape(_rectangle(Vector2(130.0, 38.0)))
		&"circle":
			var circle := CircleShape2D.new()
			circle.radius = 34.0
			_add_shape(circle)
		&"triangle":
			_add_shape(_polygon(PackedVector2Array([
				Vector2(0.0, -42.0), Vector2(42.0, 34.0), Vector2(-42.0, 34.0),
			])))
		&"irregular":
			# 两个Shape共享同一个Target，用于观察实例ID合并是否避免重复扣血。
			_add_shape(_polygon(PackedVector2Array([
				Vector2(-52.0, -24.0), Vector2(8.0, -38.0),
				Vector2(24.0, 4.0), Vector2(-38.0, 26.0),
			])))
			_add_shape(_polygon(PackedVector2Array([
				Vector2(10.0, -6.0), Vector2(54.0, -18.0),
				Vector2(46.0, 32.0), Vector2(6.0, 26.0),
			])))
		_:
			_add_shape(_rectangle(Vector2(64.0, 52.0)))


func _add_shape(shape: Shape2D) -> void:
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


func _rectangle(size: Vector2) -> RectangleShape2D:
	var shape := RectangleShape2D.new()
	shape.size = size
	return shape


func _polygon(points: PackedVector2Array) -> ConvexPolygonShape2D:
	var shape := ConvexPolygonShape2D.new()
	shape.points = points
	return shape


func _draw() -> void:
	var color: Color = display_color if current_health > 0.0 else Color("392f2b")
	for child: Node in get_children():
		if not child is CollisionShape2D:
			continue
		var shape: Shape2D = (child as CollisionShape2D).shape
		if shape is RectangleShape2D:
			var size: Vector2 = (shape as RectangleShape2D).size
			draw_rect(Rect2(-size * 0.5, size), color, true)
		elif shape is CircleShape2D:
			draw_circle(Vector2.ZERO, (shape as CircleShape2D).radius, color)
		elif shape is ConvexPolygonShape2D:
			draw_colored_polygon((shape as ConvexPolygonShape2D).points, color)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-34.0, 5.0),
		"%d  %.0f/%.0f" % [target_id, current_health, max_health],
		HORIZONTAL_ALIGNMENT_CENTER,
		68.0,
		13,
		Color.WHITE
	)
