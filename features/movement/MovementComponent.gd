extends Component
class_name MovementComponent
@export var config: MovementConfig

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

	if Input.is_action_just_pressed("jump") and body.is_on_floor():
		body.velocity.y = -config.jump_velocity

	if not body.is_on_floor():
		body.velocity.y += config.gravity * delta

	body.move_and_slide()
	
	print(body.velocity.y)
	print(body.velocity.x)
