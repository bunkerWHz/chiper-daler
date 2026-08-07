extends Component
class_name MovementComponent
@export var config: MovementConfig

var body: CharacterBody2D

func _ready() -> void:
	var body_component := actor.get_component(CharacterBodyComponent) as CharacterBodyComponent
	body = body_component.get_body()

func _physics_process(delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")
	body.velocity.x = direction * config.move_speed
	if Input.is_action_just_pressed("jump") and body.is_on_floor():
		body.velocity.y = -config.jump_velocity
	if not body.is_on_floor():
		body.velocity.y += config.gravity * delta
	body.move_and_slide()
	print(body.velocity.y)
