extends Actor
class_name RestPoint

@export var spawn_offset: Vector2 = Vector2(0.0, -24.0)

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

	var respawn := (
		interactor.get_component(PlayerRespawnComponent)
		as PlayerRespawnComponent
	)
	if respawn != null and respawn.is_enabled:
		respawn.set_checkpoint_position(global_position + spawn_offset)
