extends Component
class_name InteractableComponent

@export var interaction_name: String = "Interact"

signal interacted

func _ready() -> void:
	add_to_group("interactable")

func interact() -> void:
	interacted.emit()

func can_interact() -> bool:
	return true
