extends Actor
class_name RestPoint

var _interactable: InteractableComponent


func _ready() -> void:
	_interactable = get_component(InteractableComponent) as InteractableComponent
	if _interactable == null:
		push_error("RestPoint requires InteractableComponent")
		return

	_interactable.interacted_by.connect(_on_interacted_by)


func _on_interacted_by(interactor: Actor) -> void:
	if interactor == null:
		return

	var rest := interactor.get_component(RestComponent) as RestComponent
	if rest != null and rest.is_enabled:
		rest.start_rest()
