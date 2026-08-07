extends Component
class_name MovementComponent
@export var config: MovementConfig

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

var body: CharacterBody2D

func _ready() -> void:
	var body_component := actor.get_component(CharacterBodyComponent) as CharacterBodyComponent
	body = body_component.get_body()

func _update_horizontal_velocity(direction: float, delta: float) -> void:
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

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")

	_update_horizontal_velocity(direction, delta)
	
	if body.is_on_floor():
		coyote_timer = config.coyote_time
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)
	
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = config.jump_buffer_time
	elif jump_buffer_timer > 0.0:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		body.velocity.y = -config.jump_velocity

		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	if not body.is_on_floor():
		body.velocity.y += config.gravity * delta

	body.move_and_slide()
	
	print(body.velocity.y)
	print(body.velocity.x)
