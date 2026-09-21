extends SceneTree

## 【整体逻辑位置】独立工程的算法与双语界面回归验证。

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const SOLVER_SCRIPT: Script = preload("res://src/radial_sector_explosion.gd")
const TARGET_SCRIPT: Script = preload("res://src/demo_target.gd")


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	_verify_language_ui()
	var world := Node2D.new()
	root.add_child(world)
	var solver := SOLVER_SCRIPT.new() as Node
	world.add_child(solver)
	var front := _target(world, 1, &"wide_rectangle", 1000.0, Vector2(80.0, 0.0))
	var rear := _target(world, 2, &"rectangle", 300.0, Vector2(170.0, 0.0))
	var side := _target(world, 3, &"irregular", 300.0, Vector2(0.0, 150.0))
	await physics_frame

	solver.call("explode", Vector2.ZERO, 260.0, 32, 100.0)
	var last_targets: Array = solver.get("last_targets") as Array
	assert(int(solver.get("broad_phase_query_count")) == 1)
	assert(last_targets.size() == 3)
	assert(last_targets[0]["target"] == front)
	assert(float(front.get("current_health")) < float(front.get("max_health")))
	assert(is_equal_approx(float(rear.get("current_health")), float(rear.get("max_health"))))
	var side_record_count: int = 0
	for record: Dictionary in last_targets:
		if record["target"] == side:
			side_record_count += 1
	assert(side_record_count == 1)

	front.set("current_health", 10.0)
	solver.call("explode", Vector2.ZERO, 260.0, 32, 300.0)
	assert(not bool(front.call("is_explosion_target_available")))
	assert(float(rear.get("current_health")) < float(rear.get("max_health")))

	front.set("current_health", front.get("max_health"))
	rear.set("current_health", rear.get("max_health"))
	solver.call("explode", Vector2.ZERO, 260.0, 4, 20.0)
	var low_count: int = _sector_count_for(solver, front)
	front.set("current_health", front.get("max_health"))
	solver.call("explode", Vector2.ZERO, 260.0, 64, 20.0)
	var high_count: int = _sector_count_for(solver, front)
	assert(high_count > low_count)

	world.queue_free()
	await process_frame
	print("PASS: standalone project, bilingual UI, one-query merge/sort/block/penetration algorithm.")
	quit()


func _verify_language_ui() -> void:
	var demo := MAIN_SCENE.instantiate()
	root.add_child(demo)
	var language_option := demo.get_node("LeftPanel/LeftVBox/LanguageOption") as OptionButton
	language_option.select(1)
	language_option.item_selected.emit(1)
	assert((demo.get_node("LeftPanel/LeftVBox/ExplosionModeButton") as Button).text == "Switch to Explosion Mode")
	assert((demo.get_node("RightPanel/RightVBox/RectangleButton") as Button).text == "Rectangle")
	assert((demo.get_node("LeftPanel/LeftVBox/ModeLabel") as Label).text.begins_with("Mode:"))
	language_option.select(0)
	language_option.item_selected.emit(0)
	assert((demo.get_node("LeftPanel/LeftVBox/ExplosionModeButton") as Button).text == "切换到引爆模式")
	demo.queue_free()


func _target(
	world: Node2D,
	id: int,
	kind: StringName,
	health: float,
	position: Vector2
) -> Node2D:
	var target := TARGET_SCRIPT.new() as Node2D
	target.position = position
	target.call("configure", id, kind, health)
	world.add_child(target)
	return target


func _sector_count_for(solver: Node, target: Object) -> int:
	for record: Dictionary in (solver.get("last_targets") as Array):
		if record["target"] == target:
			return (record["sector_ids"] as Dictionary).size()
	return 0
