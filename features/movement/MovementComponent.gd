extends Component
class_name MovementComponent

var body

func _ready() -> void:
	body = actor.get_component(CharacterBodyComponent).get_body()
