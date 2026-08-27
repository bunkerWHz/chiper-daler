extends Component
class_name InteractableComponent

@export var interaction_name: String = "Interact"

signal interacted
signal interacted_by(interactor: Actor)
var is_interactable: bool = true

func _ready() -> void:
	add_to_group("interactable")

func interact(interactor: Actor = null) -> void:
	interacted.emit()
	interacted_by.emit(interactor)

func can_interact() -> bool:
	return is_interactable

func enable_interaction() -> void:
	is_interactable = true

func disable_interaction() -> void:
	is_interactable = false
