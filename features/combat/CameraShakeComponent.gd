extends Component
class_name CameraShakeComponent

signal shake_started
signal shake_finished

@export var config: CameraShakeConfig

var _hitbox_component: HitboxComponent
var _camera_component: CameraComponent
var _camera: Camera2D
var _original_offset: Vector2 = Vector2.ZERO
var _timer: float = 0.0


func on_initialize() -> void:
	if config == null:
		push_error("CameraShakeComponent requires CameraShakeConfig")
		disable()
		return

	if config.duration <= 0.0 or config.strength <= 0.0:
		push_error("CameraShakeComponent has an invalid config")
		disable()
		return

	_hitbox_component = actor.get_component(HitboxComponent) as HitboxComponent
	_camera_component = actor.get_component(CameraComponent) as CameraComponent

	if _hitbox_component == null or not _hitbox_component.is_enabled:
		push_error("CameraShakeComponent requires an enabled HitboxComponent")
		disable()
		return

	if _camera_component == null or not _camera_component.is_enabled:
		push_error("CameraShakeComponent requires an enabled CameraComponent")
		disable()
		return

	if not _hitbox_component.hit_landed.is_connected(_on_hit_landed):
		_hitbox_component.hit_landed.connect(_on_hit_landed)


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return

	_timer = maxf(_timer - delta, 0.0)

	if _timer == 0.0:
		stop()
		return

	var intensity := _timer / config.duration
	_camera.offset = _original_offset + Vector2(
		randf_range(-config.strength, config.strength),
		randf_range(-config.strength, config.strength)
	) * intensity


func trigger() -> bool:
	if not is_enabled:
		return false

	_camera = _camera_component.get_camera()

	if _camera == null:
		return false

	if _timer <= 0.0:
		_original_offset = _camera.offset

	_timer = config.duration
	shake_started.emit()
	return true


func stop() -> void:
	if _timer <= 0.0 and _camera == null:
		return

	_timer = 0.0

	if is_instance_valid(_camera):
		_camera.offset = _original_offset

	_camera = null
	shake_finished.emit()


func is_shaking() -> bool:
	return _timer > 0.0


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
