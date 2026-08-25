extends Component
class_name MovementComponent
@export var config: MovementConfig

var input_component: InputComponent
var body_component: CharacterBodyComponent
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var move_input: float = 0.0

var body: CharacterBody2D:
	get:
		return body_component.get_body()
var state: MovementState.Type = MovementState.Type.IDLE

func on_initialize() -> void:
	if config == null:
		push_error("MovementComponent requires MovementConfig")
		disable()
		return
	body_component = actor.get_component(CharacterBodyComponent)
	if body_component == null:
		push_error("MovementComponent requires CharacterBodyComponent")
		disable()
		return
	input_component = actor.get_component(InputComponent)
	if input_component == null:
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
	
	body_component.move()
	_update_state()
	

func _update_gravity(delta):
	if not body.is_on_floor():
		body.velocity.y += config.gravity * delta

func _update_horizontal_velocity(delta: float) -> void:
	var direction := input_component.get_move_input()
	var target_speed := direction * config.move_speed

	match config.acceleration_mode:
		MovementConfig.AccelerationMode.INSTANT:
			body.velocity.x = target_speed

		MovementConfig.AccelerationMode.SMOOTH:
			if direction != 0:
				body.velocity.x = move_toward(
					body.velocity.x,
					target_speed,
					config.acceleration * delta
				)
			else:
				body.velocity.x = move_toward(
					body.velocity.x,
					0.0,
					config.deceleration * delta
				)

func _update_jump_buffer(delta):
	if input_component.consume_jump_request():
		jump_buffer_timer = config.jump_buffer_time

	elif jump_buffer_timer > 0.0:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

func _update_coyote_time(delta):
	if body.is_on_floor():
		coyote_timer = config.coyote_time
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)
		
func _update_jump():
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
			body.velocity.y = -config.jump_velocity
			jump_buffer_timer = 0.0
			coyote_timer = 0.0

func _update_jump_cut():
	if input_component.is_jump_released() and body.velocity.y < 0.0:
		body.velocity.y *= config.jump_cut_multiplier



func _update_state() -> void:
	if not body_component.is_on_floor():
		if body.velocity.y < 0.0:
			state = MovementState.Type.JUMP
		else:
			state = MovementState.Type.FALL
		return

	if abs(body.velocity.x) > 0.0:
		state = MovementState.Type.RUN
	else:
		state = MovementState.Type.IDLE

func get_state() -> MovementState.Type:
	return state


func get_move_direction() -> float:
	return input_component.get_move_input()
