extends Actor
class_name Pickup

signal collected(collector: Actor, applied_amount: float)

@export var data: PickupData

var _interactable: InteractableComponent


func _ready() -> void:
	_interactable = get_component(InteractableComponent) as InteractableComponent
	if data == null or not data.is_valid() or _interactable == null:
		push_error("Pickup requires valid data and InteractableComponent")
		return

	_interactable.interaction_name = "Pick up %s" % data.display_name
	_interactable.interacted_by.connect(_on_interacted_by)


func try_collect(collector: Actor) -> bool:
	if collector == null or data == null or not data.is_valid():
		return false

	var applied := _apply_to(collector)
	if applied <= 0.0:
		return false

	collected.emit(collector, applied)
	queue_free()
	return true


func _on_interacted_by(interactor: Actor) -> void:
	try_collect(interactor)


func _apply_to(collector: Actor) -> float:
	match data.kind:
		PickupData.Kind.HEALTH:
			var health := collector.get_component(HealthComponent) as HealthComponent
			return health.heal(data.amount) if health != null else 0.0
		PickupData.Kind.ITEM_CHARGE:
			var items := collector.get_component(ItemUseComponent) as ItemUseComponent
			return float(items.add_charges(roundi(data.amount))) if items != null else 0.0
		PickupData.Kind.THROWABLE:
			var throwing := collector.get_component(ThrowingComponent) as ThrowingComponent
			return float(throwing.add_charges(roundi(data.amount))) if throwing != null else 0.0
		PickupData.Kind.ARROW:
			var ranged := collector.get_component(RangedWeaponComponent) as RangedWeaponComponent
			return float(ranged.add_arrows(roundi(data.amount))) if ranged != null else 0.0
		PickupData.Kind.BOLT:
			var ranged := collector.get_component(RangedWeaponComponent) as RangedWeaponComponent
			return float(ranged.add_bolts(roundi(data.amount))) if ranged != null else 0.0
		PickupData.Kind.MANA:
			var magic := collector.get_component(MagicComponent) as MagicComponent
			return magic.restore_mana(data.amount) if magic != null else 0.0
		PickupData.Kind.EXPERIENCE:
			var progression := collector.get_component(ProgressionComponent) as ProgressionComponent
			if progression == null:
				return 0.0
			progression.gain_experience(roundi(data.amount))
			return data.amount

	return 0.0
