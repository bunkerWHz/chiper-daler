extends Component
class_name HitStopComponent

signal hit_stop_started
signal hit_stop_finished

@export var config: HitStopConfig

var _hitbox_component: HitboxComponent
var _hurtbox_component: HurtboxComponent
var _is_active: bool = false
var _finish_time_msec: int = 0
var _previous_time_scale: float = 1.0


func on_initialize() -> void:
	if config == null:
		push_error("HitStopComponent requires HitStopConfig")
		disable()
		return

	if (
		config.duration <= 0.0
		or config.time_scale <= 0.0
		or config.time_scale >= 1.0
		or not (config.on_hit_landed or config.on_hit_received)
	):
		push_error("HitStopComponent has an invalid config")
		disable()
		return

	if config.on_hit_landed:
		_hitbox_component = actor.get_component(HitboxComponent) as HitboxComponent

		if _hitbox_component == null or not _hitbox_component.is_enabled:
			push_error("HitStopComponent requires an enabled HitboxComponent")
			disable()
			return

		if not _hitbox_component.hit_landed.is_connected(_on_hit_landed):
			_hitbox_component.hit_landed.connect(_on_hit_landed)

	if config.on_hit_received:
		_hurtbox_component = (
			actor.get_component(HurtboxComponent)
			as HurtboxComponent
		)

		if _hurtbox_component == null or not _hurtbox_component.is_enabled:
			push_error("HitStopComponent requires an enabled HurtboxComponent")
			disable()
			return

		if not _hurtbox_component.hit_received.is_connected(_on_hit_received):
			_hurtbox_component.hit_received.connect(_on_hit_received)

	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if _is_active and Time.get_ticks_msec() >= _finish_time_msec:
		stop()


func trigger() -> bool:
	if not is_enabled:
		return false

	if not _is_active:
		_previous_time_scale = Engine.time_scale
		_is_active = true
		Engine.time_scale = config.time_scale
		hit_stop_started.emit()

	_finish_time_msec = (
		Time.get_ticks_msec()
		+ int(ceil(config.duration * 1000.0))
	)
	return true


func stop() -> void:
	if not _is_active:
		return

	Engine.time_scale = _previous_time_scale
	_is_active = false
	_finish_time_msec = 0
	hit_stop_finished.emit()


func is_active() -> bool:
	return _is_active


func disable() -> void:
	stop()
	super.disable()


func _exit_tree() -> void:
	stop()


func _on_hit_landed(
	_hurtbox: HurtboxComponent,
	_applied_damage: float
) -> void:
	trigger()


func _on_hit_received(
	_hit: HitData,
	_applied_damage: float
) -> void:
	trigger()
