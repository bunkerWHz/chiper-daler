extends Component
class_name MovementComponent

signal state_changed(
	previous_state: MovementState.Type,
	current_state: MovementState.Type
)

@export var config: MovementConfig

var _input_component: InputComponent
var _body_component: CharacterBodyComponent
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

var _state: MovementState.Type = MovementState.Type.IDLE

func on_initialize() -> void:
	if config == null:
		push_error("MovementComponent requires MovementConfig")
		disable()
		return
	_body_component = actor.get_component(CharacterBodyComponent)
	if _body_component == null:
		push_error("MovementComponent requires CharacterBodyComponent")
		disable()
		return
	_input_component = actor.get_component(InputComponent)
	if _input_component == null:
		push_error("MovementComponent requires InputComponent")
		disable()
		return


func _physics_process(delta: float) -> void:
	
	_update_jump_buffer(delta)
	_update_coyote_time(delta)
	_update_horizontal_velocity(delta)
	_update_jump()
	_update_gravity(delta)
	_update_jump_cut()
	
	_body_component.move_and_slide()
	_update_state()
	

func _update_gravity(delta: float) -> void:
	if _body_component.is_on_floor():
		return

	var velocity := _body_component.get_velocity()
	velocity.y += config.gravity * delta
	_body_component.set_velocity(velocity)

func _update_horizontal_velocity(delta: float) -> void:
	var direction := _input_component.get_move_axis()
	var target_speed := direction * config.move_speed
	var velocity := _body_component.get_velocity()

	match config.acceleration_mode:
		MovementConfig.AccelerationMode.INSTANT:
			velocity.x = target_speed

		MovementConfig.AccelerationMode.SMOOTH:
			if direction != 0:
				velocity.x = move_toward(
					velocity.x,
					target_speed,
					config.acceleration * delta
				)
			else:
				velocity.x = move_toward(
					velocity.x,
					0.0,
					config.deceleration * delta
				)

	_body_component.set_velocity(velocity)

func _update_jump_buffer(delta: float) -> void:
	if _input_component.consume_jump_pressed():
		_jump_buffer_timer = config.jump_buffer_time

	elif _jump_buffer_timer > 0.0:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

func _update_coyote_time(delta: float) -> void:
	if _body_component.is_on_floor():
		_coyote_timer = config.coyote_time
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)
		
func _update_jump() -> void:
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		var velocity := _body_component.get_velocity()
		velocity.y = -config.jump_velocity
		_body_component.set_velocity(velocity)
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

func _update_jump_cut() -> void:
	var velocity := _body_component.get_velocity()

	if _input_component.is_jump_released() and velocity.y < 0.0:
		velocity.y *= config.jump_cut_multiplier
		_body_component.set_velocity(velocity)



func _update_state() -> void:
	_set_state(_resolve_state())


func _resolve_state() -> MovementState.Type:
	var velocity := _body_component.get_velocity()

	if not _body_component.is_on_floor():
		if velocity.y < 0.0:
			return MovementState.Type.JUMP

		return MovementState.Type.FALL

	if not is_zero_approx(velocity.x):
		return MovementState.Type.RUN

	return MovementState.Type.IDLE


func _set_state(new_state: MovementState.Type) -> void:
	if new_state == _state:
		return

	var previous_state := _state
	_state = new_state
	state_changed.emit(previous_state, _state)


func get_state() -> MovementState.Type:
	return _state
