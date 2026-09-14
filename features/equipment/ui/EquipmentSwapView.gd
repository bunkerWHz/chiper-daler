extends Node2D
class_name EquipmentSwapView

@export var actor_path: NodePath = ^".."

var _swap: EquipmentSwapComponent
@onready var _bar: ProgressBar = $ProgressBar
@onready var _label: Label = $Label


func _ready() -> void:
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
	refresh()


func refresh() -> void:
	visible = is_instance_valid(_swap) and _swap.is_enabled and _swap.is_swapping()
	if visible and is_node_ready():
		_bar.value = _swap.get_progress()
		_label.text = "Смена: %.1f с" % _swap.get_remaining()


func _on_started(_target: int, _duration: float) -> void:
	refresh()


func _on_finished(_target: int, _completed: bool) -> void:
	refresh()
