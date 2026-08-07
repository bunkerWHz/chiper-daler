extends Component
class_name MovementComponent
@export var config: MovementConfig

var body: CharacterBody2D

var move_left
var move_right

func _ready() -> void:
	body = actor.get_component(CharacterBodyComponent).get_body()

func _physics_process(delta: float) -> void:
	
	#body.velocity.x = Input.get_axis("ui_left", "ui_right") * move_speed
	#move_and_slide()
	pass
