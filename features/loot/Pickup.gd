extends Actor
class_name Pickup

signal collected(collector: Actor, item: ItemData, quantity: int)

@export var item: ItemData
@export_range(1, 999, 1) var quantity: int = 1

var _interactable: InteractableComponent


func _ready() -> void:
	_interactable = get_component(InteractableComponent) as InteractableComponent
	if item == null or not item.is_valid() or quantity <= 0 or _interactable == null:
		push_error("Pickup requires a valid item, quantity, and InteractableComponent")
		return

	_update_interaction_name()
	_interactable.interacted_by.connect(_on_interacted_by)


func try_collect(collector: Actor) -> bool:
	if collector == null or item == null or not item.is_valid() or quantity <= 0:
		return false

	var inventory := collector.get_component(InventoryComponent) as InventoryComponent
	if inventory == null or not inventory.is_enabled:
		return false

	var accepted := inventory.add_item(item, quantity)
	if accepted <= 0:
		return false

	quantity -= accepted
	collected.emit(collector, item, accepted)
	if quantity == 0:
		queue_free()
	else:
		_update_interaction_name()
	return true


func _on_interacted_by(interactor: Actor) -> void:
	try_collect(interactor)


func _update_interaction_name() -> void:
	_interactable.interaction_name = "Pick up %s x%d" % [
		item.display_name,
		quantity,
	]
