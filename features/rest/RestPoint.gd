extends Actor
class_name RestPoint

@export var spawn_offset: Vector2 = Vector2(0.0, -24.0)
@export var shop_weapons: Array[ItemData] = [
	preload("res://game/items/weapons/TrainingSword.tres"),
	preload("res://game/items/weapons/TrainingBow.tres"),
	preload("res://game/items/weapons/TrainingStaff.tres"),
]
@export_range(1, 100000, 1) var weapon_price: int = 100
@export_range(1, 100000, 1) var upgrade_base_cost: int = 50
@export_range(1.0, 500.0) var service_radius: float = 100.0
var _menu: CanvasLayer

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
	if is_inside_tree() and _can_trade(interactor) and not is_instance_valid(_menu):
		_menu = preload("res://features/rest/ShelterMenu.gd").new()
		_menu.shelter = self
		_menu.visitor = interactor
		add_child(_menu)


func _can_trade(visitor: Actor) -> bool:
	if visitor == null or global_position.distance_to(visitor.global_position) > service_radius:
		return false
	var health := visitor.get_component(HealthComponent) as HealthComponent
	var inventory := visitor.get_component(InventoryComponent) as InventoryComponent
	return health != null and not health.is_dead() and inventory != null and inventory.is_enabled


func get_level_cost(visitor: Actor) -> int:
	var progression := visitor.get_component(ProgressionComponent) as ProgressionComponent
	if progression == null or not progression.is_enabled:
		return 0
	return progression.get_experience_required() - progression.get_experience()


func buy_level(visitor: Actor) -> bool:
	if not _can_trade(visitor):
		return false
	var cost := get_level_cost(visitor)
	var inventory := visitor.get_component(InventoryComponent) as InventoryComponent
	if cost <= 0 or not inventory.spend_amber(cost):
		return false
	(visitor.get_component(ProgressionComponent) as ProgressionComponent).gain_experience(cost)
	return true


func get_weapon_price(_index: int) -> int:
	return weapon_price


func buy_weapon(visitor: Actor, index: int) -> bool:
	if not _can_trade(visitor) or index < 0 or index >= shop_weapons.size():
		return false
	var item := shop_weapons[index]
	if item == null or not item.is_valid() or item.category != ItemData.Category.WEAPON:
		return false
	var inventory := visitor.get_component(InventoryComponent) as InventoryComponent
	var cost := get_weapon_price(index)
	if inventory.get_amber() < cost or inventory.add_item(item, 1) != 1:
		return false
	inventory.spend_amber(cost)
	return true


func upgrade_equipped_weapon(visitor: Actor) -> bool:
	if not _can_trade(visitor):
		return false
	var equipment := visitor.get_component(EquipmentComponent) as EquipmentComponent
	if equipment == null or not equipment.is_enabled:
		return false
	var item := equipment.get_equipped_item(ItemData.EquipSlot.MAIN_HAND)
	if item == null or item.category != ItemData.Category.WEAPON:
		return false
	var inventory := visitor.get_component(InventoryComponent) as InventoryComponent
	var level := inventory.get_weapon_upgrade(item.id)
	var cost := upgrade_base_cost * (level + 1)
	if level >= 5 or inventory.get_amber() < cost:
		return false
	if not inventory.upgrade_weapon(item.id):
		return false
	inventory.spend_amber(cost)
	return true
