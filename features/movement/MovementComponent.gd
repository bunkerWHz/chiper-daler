extends Component
class_name MovementComponent

func _ready() -> void:
	var body_component := actor.get_component(CharacterBodyComponent) as CharacterBodyComponent
	print(body_component.get_body())
