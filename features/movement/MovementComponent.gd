extends Component
class_name MovementComponent
@export var config: MovementConfig

var body: CharacterBody2D

func _ready() -> void:
	var body_component := actor.get_component(CharacterBodyComponent) as CharacterBodyComponent
	body = body_component.get_body()

func _physics_process(_delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")
	body.velocity.x = direction * config.move_speed
	body.move_and_slide()
