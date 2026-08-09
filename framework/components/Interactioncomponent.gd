extends Component
class_name InteractionComponent

@export var interaction_distance: float = 48.0
var input_component: InputComponent

func _ready() -> void:
	input_component = actor.get_component(InputComponent) as InputComponent

	if input_component == null:
		push_error("InteractionComponent requires InputComponent")
		
func can_interact() -> bool:
	return false

func interact() -> void:
	pass

func _process(_delta: float) -> void:
	if input_component == null:
		return

	if input_component.is_interact_pressed():
		interact()
