extends Node2D

## 【整体逻辑位置】独立目标排序式径向扇区爆炸交互展示。

const TARGET_SCRIPT: Script = preload("res://src/demo_target.gd")

@onready var explosion_solver: Node = %ExplosionSolver
@onready var radius_input: SpinBox = %RadiusInput
@onready var damage_input: SpinBox = %DamageInput
@onready var sector_input: SpinBox = %SectorInput
@onready var health_input: SpinBox = %HealthInput
@onready var language_option: OptionButton = %LanguageOption
@onready var mode_label: Label = %ModeLabel
@onready var result_label: Label = %ResultLabel

enum Language {
	ZH_CN,
	EN,
}

enum ResultState {
	INITIAL,
	PLACED,
	EXPLODED,
	CLEARED,
}

var current_language: Language = Language.ZH_CN
var result_state: ResultState = ResultState.INITIAL
var result_target_id: int = 0
var result_target_count: int = 0
var result_blocked_count: int = 0
var result_sector_count: int = 0
var placement_kind: StringName = &""
var next_target_id: int = 1
var explosion_position: Vector2 = Vector2.ZERO
var debug_radius: float = 0.0
var debug_sectors: Array[Dictionary] = []
var targets: Array[Node2D] = []


func _ready() -> void:
	language_option.item_selected.connect(_on_language_selected)
	%ExplosionModeButton.pressed.connect(_select_explosion_mode)
	%RectangleButton.pressed.connect(_select_placement.bind(&"rectangle"))
	%WideRectangleButton.pressed.connect(_select_placement.bind(&"wide_rectangle"))
	%CircleButton.pressed.connect(_select_placement.bind(&"circle"))
	%TriangleButton.pressed.connect(_select_placement.bind(&"triangle"))
	%IrregularButton.pressed.connect(_select_placement.bind(&"irregular"))
	%ClearButton.pressed.connect(_clear_targets)
	_apply_language()
	_select_explosion_mode()
	_refresh_result_text()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var mouse_position: Vector2 = event.position
	var viewport_size: Vector2 = get_viewport_rect().size
	if not Rect2(230.0, 0.0, viewport_size.x - 460.0, viewport_size.y).has_point(mouse_position):
		return
	if placement_kind.is_empty():
		_explode_at(mouse_position)
	else:
		_place_target(mouse_position)


func _on_language_selected(index: int) -> void:
	current_language = Language.EN if index == 1 else Language.ZH_CN
	_apply_language()
	_refresh_mode_text()
	_refresh_result_text()


func _apply_language() -> void:
	%CenterHint.text = _text("目标排序式径向扇区爆炸测试区", "Target-sorted Radial Sector Explosion Test")
	%LeftTitle.text = _text("爆炸参数", "EXPLOSION")
	%RightTitle.text = _text("目标形状", "TARGET SHAPES")
	%LanguageLabel.text = _text("语言", "Language")
	%RadiusLabel.text = _text("爆炸半径", "Explosion Radius")
	%DamageLabel.text = _text("每扇区爆炸伤害", "Explosion Damage / Sector")
	%SectorLabel.text = _text("扇区数量 / 密度", "Sector Count / Density")
	%ExplosionModeButton.text = _text("切换到引爆模式", "Switch to Explosion Mode")
	%ClearButton.text = _text("清空目标", "Clear Targets")
	%HealthLabel.text = _text("目标生命值", "Target Health")
	%RectangleButton.text = _text("矩形", "Rectangle")
	%WideRectangleButton.text = _text("宽矩形", "Wide Rectangle")
	%CircleButton.text = _text("圆形", "Circle")
	%TriangleButton.text = _text("三角形", "Triangle")
	%IrregularButton.text = _text("不规则 / 多碰撞形状", "Irregular / Multi Shape")
	%Help.text = _text(
		"选择形状后在中间点击放置。切换到引爆模式后，左键产生爆炸。红线表示被实体阻挡的扇区。",
		"Select a shape and click the center area to place it. In explosion mode, left-click to detonate. Red lines mark sectors blocked by a surviving target."
	)


func _text(zh_cn: String, en: String) -> String:
	return en if current_language == Language.EN else zh_cn


func _select_explosion_mode() -> void:
	placement_kind = &""
	_refresh_mode_text()


func _select_placement(kind: StringName) -> void:
	placement_kind = kind
	_refresh_mode_text()


func _refresh_mode_text() -> void:
	if placement_kind.is_empty():
		mode_label.text = _text("模式：点击中间区域引爆", "Mode: click the center area to detonate")
		return
	mode_label.text = _text(
		"模式：放置 %s" % _shape_name(placement_kind),
		"Mode: place %s" % _shape_name(placement_kind)
	)


func _shape_name(kind: StringName) -> String:
	match kind:
		&"rectangle":
			return _text("矩形", "Rectangle")
		&"wide_rectangle":
			return _text("宽矩形", "Wide Rectangle")
		&"circle":
			return _text("圆形", "Circle")
		&"triangle":
			return _text("三角形", "Triangle")
		&"irregular":
			return _text("不规则目标", "Irregular Target")
	return String(kind)


func _refresh_result_text() -> void:
	match result_state:
		ResultState.PLACED:
			result_label.text = _text(
				"已放置目标 %d；修改生命值只影响之后放置的目标。" % result_target_id,
				"Placed Target %d. Health changes only affect targets placed afterward." % result_target_id
			)
		ResultState.EXPLODED:
			result_label.text = _text(
				"目标记录 %d；阻挡扇区 %d/%d" % [
					result_target_count, result_blocked_count, result_sector_count,
				],
				"Target records: %d; blocked sectors: %d/%d" % [
					result_target_count, result_blocked_count, result_sector_count,
				]
			)
		ResultState.CLEARED:
			result_label.text = _text("测试区域已清空。", "Test area cleared.")
		_:
			result_label.text = _text(
				"先从右侧选择形状并放置。",
				"Select a shape on the right, then place it in the test area."
			)


func _place_target(world_position: Vector2) -> void:
	var target := TARGET_SCRIPT.new() as Node2D
	target.position = world_position
	target.call("configure", next_target_id, placement_kind, float(health_input.value))
	add_child(target)
	targets.append(target)
	next_target_id += 1
	result_state = ResultState.PLACED
	result_target_id = int(target.get("target_id"))
	_refresh_result_text()


func _explode_at(world_position: Vector2) -> void:
	# 等待物理服务器接收刚放置的目标，再进行一次正式结算。
	await get_tree().physics_frame
	explosion_position = world_position
	debug_radius = float(radius_input.value)
	debug_sectors = explosion_solver.call(
		"explode",
		world_position,
		debug_radius,
		int(sector_input.value),
		float(damage_input.value)
	)
	var blocked: int = 0
	for sector: Dictionary in debug_sectors:
		if bool(sector["blocked"]):
			blocked += 1
	result_state = ResultState.EXPLODED
	result_target_count = (explosion_solver.get("last_targets") as Array).size()
	result_blocked_count = blocked
	result_sector_count = debug_sectors.size()
	_refresh_result_text()
	queue_redraw()


func _clear_targets() -> void:
	for target: Node2D in targets:
		if is_instance_valid(target):
			target.queue_free()
	targets.clear()
	debug_sectors.clear()
	result_state = ResultState.CLEARED
	_refresh_result_text()
	queue_redraw()


func _draw() -> void:
	if debug_sectors.is_empty():
		return
	draw_arc(explosion_position, debug_radius, 0.0, TAU, 128, Color("d7a34c"), 2.0)
	var sector_angle: float = TAU / float(debug_sectors.size())
	for sector: Dictionary in debug_sectors:
		var angle: float = float(sector["sector_id"]) * sector_angle - sector_angle * 0.5
		var color: Color = Color("d95e4f") if bool(sector["blocked"]) else Color("816d55")
		draw_line(
			explosion_position,
			explosion_position + Vector2.from_angle(angle) * debug_radius,
			color,
			1.0
		)
