extends Node2D
class_name DamageNumberView

var _damage: float = 0.0
var _config: DamageNumberConfig
var _start_position: Vector2
var _elapsed: float = 0.0

@onready var _label: Label = %Label


func setup(
	damage: float,
	world_position: Vector2,
	config: DamageNumberConfig
) -> void:
	_damage = damage
	_config = config
	_start_position = world_position
	position = _start_position


func _ready() -> void:
	if _config == null:
		push_error("DamageNumberView requires setup before entering the tree")
		queue_free()
		return

	_label.text = str(roundi(_damage))
	_label.modulate = _config.color
	_label.add_theme_font_size_override(&"font_size", _config.font_size)


func _process(delta: float) -> void:
	if _config == null:
		return

	_elapsed = minf(_elapsed + delta, _config.duration)
	var progress := _elapsed / _config.duration
	position = _start_position + Vector2.UP * _config.rise_distance * progress
	modulate.a = 1.0 - progress

	if progress >= 1.0:
		queue_free()


func get_damage() -> float:
	return _damage
