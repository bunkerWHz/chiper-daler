extends Component
class_name InteractableComponent

@export var interaction_name: String = "Interact"


func _ready() -> void:
	add_to_group("interactable")


func interact() -> void:
	print(interaction_name)
