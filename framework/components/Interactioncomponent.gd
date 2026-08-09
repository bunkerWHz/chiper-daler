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



func _process(_delta: float) -> void:
	if input_component == null:
		return

	if input_component.is_interact_pressed():
		interact()



func find_nearest_interactable() -> InteractableComponent:
	var nearest: InteractableComponent = null
	var nearest_distance: float = interaction_distance

	for node in get_tree().get_nodes_in_group("interactable"):
		if not node is InteractableComponent:
			continue

		var interactable: InteractableComponent = node as InteractableComponent

		var distance: float = actor.global_position.distance_to(
			interactable.actor.global_position
		)

		if distance <= nearest_distance:
			nearest = interactable
			nearest_distance = distance

	return nearest

func interact() -> void:
	var interactable: InteractableComponent = find_nearest_interactable()

	if interactable == null:
		return

	interactable.interact()
