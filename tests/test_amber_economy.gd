@tool
extends McpTestSuite

func suite_name() -> String:
	return "amber_economy"

func _player() -> Actor:
	var player := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	player.add_child(components)
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	inventory.config.capacity = 1
	var progression := ProgressionComponent.new()
	progression.config = ProgressionConfig.new()
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	var equipment := EquipmentComponent.new()
	for component: Component in [inventory, progression, health, equipment]:
		components.add_child(component)
	player._collect_components()
	return player

func test_pickup_ignores_capacity_and_cannot_collect_twice() -> void:
	var player := _player()
	var inventory := player.get_component(InventoryComponent) as InventoryComponent
	inventory.add_item(preload("res://game/items/weapons/TrainingSword.tres"))
	var pickup := track(preload("res://features/loot/AmberShardPickup.tscn").instantiate()) as AmberShardPickup
	assert_true(pickup.try_collect(player))
	assert_false(pickup.try_collect(player))
	assert_eq(inventory.get_amber(), 25)
	assert_eq(inventory.get_used_slots(), 1)
	assert_false(inventory.spend_amber(26))
	assert_false(inventory.spend_amber(-1))
	assert_eq(inventory.get_amber(), 25)

func test_shelter_purchase_failures_do_not_spend_currency() -> void:
	var player := _player()
	var inventory := player.get_component(InventoryComponent) as InventoryComponent
	var shelter := track(RestPoint.new()) as RestPoint
	inventory.add_amber(300)
	assert_true(shelter.buy_weapon(player, 0))
	assert_eq(inventory.get_amber(), 200)
	assert_false(shelter.buy_weapon(player, 1))
	assert_false(shelter.buy_weapon(player, -1))
	assert_eq(inventory.get_amber(), 200)
	player.position.x = 500
	assert_false(shelter.buy_level(player))
	assert_eq(inventory.get_amber(), 200)
	player.position.x = 0
	assert_true(shelter.buy_level(player))
	assert_eq(inventory.get_amber(), 100)
	assert_eq((player.get_component(ProgressionComponent) as ProgressionComponent).get_level(), 2)
	assert_false(shelter.buy_level(player))
	assert_eq(inventory.get_amber(), 100)

func test_upgrade_damage_and_runtime_state_roundtrip() -> void:
	var player := _player()
	var inventory := player.get_component(InventoryComponent) as InventoryComponent
	var equipment := player.get_component(EquipmentComponent) as EquipmentComponent
	var sword := preload("res://game/items/weapons/TrainingSword.tres")
	inventory.add_item(sword)
	equipment.equip_inventory_item(sword.id, ItemData.EquipSlot.MAIN_HAND)
	var original_damage := equipment.get_active_weapon_damage()
	inventory.add_amber(1000)
	var shelter := track(RestPoint.new()) as RestPoint
	for index in 5:
		assert_true(shelter.upgrade_equipped_weapon(player))
	assert_false(shelter.upgrade_equipped_weapon(player))
	assert_eq(inventory.get_amber(), 250)
	assert_true(is_equal_approx(equipment.get_active_weapon_damage(), original_damage * 1.5))
	assert_true(is_equal_approx(sword.get_equipment_stats().damage, original_damage))
	var state: Variant = inventory.capture_runtime_state()
	var restored_player := _player()
	var restored := restored_player.get_component(InventoryComponent) as InventoryComponent
	restored.restore_runtime_state(state)
	assert_eq(restored.get_amber(), 250)
	assert_eq(restored.get_weapon_upgrade(sword.id), 5)
	assert_eq(restored.get_quantity(sword.id), 1)

func test_dead_player_cannot_collect_or_spend() -> void:
	var player := _player()
	var inventory := player.get_component(InventoryComponent) as InventoryComponent
	inventory.add_amber(100)
	(player.get_component(HealthComponent) as HealthComponent).take_damage(1000)
	var pickup := track(preload("res://features/loot/AmberShardPickup.tscn").instantiate()) as AmberShardPickup
	assert_false(pickup.try_collect(player))
	var shelter := track(RestPoint.new()) as RestPoint
	assert_false(shelter.buy_level(player))
	assert_eq(inventory.get_amber(), 100)


func _flat_curve_player(max_level: int) -> Actor:
	var player := _player()
	var progression := player.get_component(ProgressionComponent) as ProgressionComponent
	progression.config.requirement_growth = 1.0
	progression.config.max_level = max_level
	return player


## 20 опыта, 90 осколков, до уровня не хватает 80: обмен забирает ровно 80,
## 10 осколков остаются в кошельке.
func test_exchange_to_next_level_keeps_the_remainder() -> void:
	var player := _flat_curve_player(100)
	var inventory := player.get_component(InventoryComponent) as InventoryComponent
	var progression := player.get_component(ProgressionComponent) as ProgressionComponent
	var shelter := track(RestPoint.new()) as RestPoint
	progression.gain_experience(20)
	inventory.add_amber(90)
	assert_eq(shelter.get_level_cost(player), 80)
	assert_true(shelter.buy_level(player))
	assert_eq(inventory.get_amber(), 10)
	assert_eq(progression.get_level(), 2)
	assert_eq(progression.get_experience(), 0)


func test_exchange_all_spends_the_whole_purse() -> void:
	var player := _flat_curve_player(100)
	var inventory := player.get_component(InventoryComponent) as InventoryComponent
	var progression := player.get_component(ProgressionComponent) as ProgressionComponent
	var shelter := track(RestPoint.new()) as RestPoint
	progression.gain_experience(20)
	inventory.add_amber(90)
	assert_eq(shelter.get_full_exchange_cost(player), 90)
	assert_true(shelter.buy_all_levels(player))
	assert_eq(inventory.get_amber(), 0)
	assert_eq(progression.get_level(), 2)
	assert_eq(progression.get_experience(), 10)


func test_exchange_all_stops_paying_for_levels_past_the_cap() -> void:
	var player := _flat_curve_player(2)
	var inventory := player.get_component(InventoryComponent) as InventoryComponent
	var progression := player.get_component(ProgressionComponent) as ProgressionComponent
	var shelter := track(RestPoint.new()) as RestPoint
	inventory.add_amber(500)
	assert_eq(shelter.get_full_exchange_cost(player), 100)
	assert_true(shelter.buy_all_levels(player))
	assert_eq(inventory.get_amber(), 400)
	assert_eq(progression.get_level(), 2)
	assert_true(progression.is_max_level())
	assert_eq(shelter.get_level_cost(player), 0)
	assert_eq(shelter.get_full_exchange_cost(player), 0)
	assert_false(shelter.buy_level(player))
	assert_false(shelter.buy_all_levels(player))
	assert_eq(inventory.get_amber(), 400)
