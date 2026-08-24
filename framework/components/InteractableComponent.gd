extends Component
class_name InteractableComponent

@export var interaction_name: String = "Interact"

signal interacted
var is_interactable: bool = true

func _ready() -> void:
	add_to_group("interactable")

func interact() -> void:
	interacted.emit()

func can_interact() -> bool:
	return is_interactable

func enable_interaction() -> void:
	is_interactable = true

func disable_interaction() -> void:
	is_interactable = false
