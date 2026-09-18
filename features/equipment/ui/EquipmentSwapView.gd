@tool
extends Node2D
class_name EquipmentSwapView

@export var actor_path: NodePath = ^".."
## Width in the parent's native units; height and head gap stay in world pixels.
@export var native_width: float = 64.0
@export var bar_height: float = 4.0
@export var head_gap: float = 4.0

var _swap: EquipmentSwapComponent
@onready var _bar: ProgressBar = $ProgressBar
@onready var _label: Label = $Label


func _ready() -> void:
	_update_layout()
	if Engine.is_editor_hint():
		return
	var target := get_node_or_null(actor_path) as Actor
	if target != null:
		bind_swap(target.get_component(EquipmentSwapComponent) as EquipmentSwapComponent)
	refresh()


func bind_swap(value: EquipmentSwapComponent) -> void:
	if is_instance_valid(_swap):
		if _swap.swap_started.is_connected(_on_started):
			_swap.swap_started.disconnect(_on_started)
		if _swap.swap_finished.is_connected(_on_finished):
			_swap.swap_finished.disconnect(_on_finished)
	_swap = value
	if _swap != null:
		_swap.swap_started.connect(_on_started)
		_swap.swap_finished.connect(_on_finished)
	if is_node_ready():
		refresh()


func _process(_delta: float) -> void:
	_update_layout()
	if Engine.is_editor_hint():
		return
	refresh()


func _update_layout() -> void:
	var parent := get_parent() as Node2D
	var parent_scale := parent.global_scale.abs() if parent != null else Vector2.ONE
	if is_zero_approx(parent_scale.x) or is_zero_approx(parent_scale.y):
		return
	# Keep the authored head anchor in parent space, but cancel inherited UI scaling.
	scale = Vector2.ONE / parent_scale
	var width := native_width * parent_scale.x
	_bar.position = Vector2(-width * 0.5, -head_gap - bar_height)
	_bar.size = Vector2(width, bar_height)
	_label.position = Vector2(-width * 0.5, -head_gap - bar_height - 16.0)
	_label.size = Vector2(width, 14.0)


func refresh() -> void:
	visible = is_instance_valid(_swap) and _swap.is_enabled and _swap.is_swapping()
	if visible and is_node_ready():
		_bar.value = _swap.get_progress()
		_label.text = "%.1f с" % _swap.get_remaining()


func _on_started(_target: int, _duration: float) -> void:
	refresh()


func _on_finished(_target: int, _completed: bool) -> void:
	refresh()
