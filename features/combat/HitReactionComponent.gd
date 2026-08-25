extends Component
class_name HitReactionComponent

signal reaction_started
signal reaction_finished

@export var config: HitReactionConfig
@export var visual_path: NodePath = ^"_Visual"

var _hurtbox_component: HurtboxComponent
var _visual: CanvasItem
var _original_modulate: Color = Color.WHITE
var _original_scale: Vector2 = Vector2.ONE
var _reaction_timer: float = 0.0


func on_initialize() -> void:
	if config == null:
		push_error("HitReactionComponent requires HitReactionConfig")
		disable()
		return

	if config.duration <= 0.0 or config.scale_multiplier < 1.0:
		push_error("HitReactionComponent has an invalid config")
		disable()
		return

	_hurtbox_component = actor.get_component(HurtboxComponent) as HurtboxComponent

	if _hurtbox_component == null or not _hurtbox_component.is_enabled:
		push_error("HitReactionComponent requires an enabled HurtboxComponent")
		disable()
		return

	if not _hurtbox_component.hit_received.is_connected(_on_hit_received):
		_hurtbox_component.hit_received.connect(_on_hit_received)


func _ready() -> void:
	_visual = actor.get_node_or_null(visual_path) as CanvasItem

	if _visual == null:
		push_error("HitReactionComponent requires a CanvasItem visual")
		disable()
		return

	_original_modulate = _visual.modulate

	if _visual is Node2D:
		_original_scale = (_visual as Node2D).scale


func _process(delta: float) -> void:
	if _reaction_timer <= 0.0:
		return

	_reaction_timer = maxf(_reaction_timer - delta, 0.0)

	if _reaction_timer == 0.0:
		_finish_reaction()


func is_reacting() -> bool:
	return _reaction_timer > 0.0


func _on_hit_received(_hit: HitData, _applied_damage: float) -> void:
	if not is_enabled or _visual == null:
		return

	_reaction_timer = config.duration
	_visual.modulate = config.flash_modulate

	if _visual is Node2D:
		(_visual as Node2D).scale = _original_scale * config.scale_multiplier

	reaction_started.emit()


func _finish_reaction() -> void:
	if _visual == null:
		return

	_visual.modulate = _original_modulate

	if _visual is Node2D:
		(_visual as Node2D).scale = _original_scale

	reaction_finished.emit()
