extends Component
class_name BlockReactionComponent

signal reaction_started(prevented_damage: float)
signal reaction_finished

@export var config: BlockReactionConfig
@export var visual_path: NodePath = ^"_Visual"

var _guard_component: GuardComponent
var _visual: Node2D
var _original_scale: Vector2 = Vector2.ONE
var _reaction_timer: float = 0.0


func on_initialize() -> void:
	if config == null:
		push_error("BlockReactionComponent requires BlockReactionConfig")
		disable()
		return

	if (
		config.duration <= 0.0
		or config.scale_multiplier.x <= 0.0
		or config.scale_multiplier.y <= 0.0
	):
		push_error("BlockReactionComponent has an invalid config")
		disable()
		return

	_guard_component = actor.get_component(GuardComponent) as GuardComponent

	if _guard_component == null or not _guard_component.is_enabled:
		push_error("BlockReactionComponent requires an enabled GuardComponent")
		disable()
		return

	if not _guard_component.damage_blocked.is_connected(_on_damage_blocked):
		_guard_component.damage_blocked.connect(_on_damage_blocked)


func _ready() -> void:
	_visual = actor.get_node_or_null(visual_path) as Node2D

	if _visual == null:
		push_error("BlockReactionComponent requires a Node2D visual")
		disable()
		return

	_original_scale = _visual.scale


func _process(delta: float) -> void:
	if _reaction_timer <= 0.0:
		return

	_reaction_timer = maxf(_reaction_timer - delta, 0.0)

	if _reaction_timer == 0.0:
		_finish_reaction()


func is_reacting() -> bool:
	return _reaction_timer > 0.0


func disable() -> void:
	_reaction_timer = 0.0

	if _visual != null:
		_visual.scale = _original_scale

	super.disable()


func _on_damage_blocked(_hit: HitData, prevented_damage: float) -> void:
	if not is_enabled or _visual == null:
		return

	_reaction_timer = config.duration
	_visual.scale = _original_scale * config.scale_multiplier
	reaction_started.emit(prevented_damage)


func _finish_reaction() -> void:
	if _visual == null:
		return

	_visual.scale = _original_scale
	reaction_finished.emit()
