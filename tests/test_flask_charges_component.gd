@tool
extends McpTestSuite


func suite_name() -> String:
	return "flask_charges"


func test_flask_is_unique_persistent_and_refilled_by_rest() -> void:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var flasks := FlaskChargesComponent.new()
	var rest := RestComponent.new()
	rest.config = RestConfig.new()
	for component: Component in [health, inventory, flasks, rest]:
		components.add_child(component)
	actor._collect_components()

	var flask := load(
		"res://features/inventory/items/HealthPotion.tres"
	) as ItemData
	assert_eq(inventory.add_item(flask, 8), 1)
	assert_eq(inventory.get_quantity(flask.id), 1)
	assert_eq(flasks.get_charges(flask.id), 3)
	assert_eq(inventory.add_item(flask), 0)
	assert_eq(inventory.remove_item(flask.id), 0)

	assert_true(flasks.spend_charge(flask.id))
	assert_true(flasks.spend_charge(flask.id))
	assert_true(flasks.spend_charge(flask.id))
	assert_false(flasks.spend_charge(flask.id))
	assert_eq(flasks.get_charges(flask.id), 0)
	assert_eq(inventory.get_quantity(flask.id), 1)
	assert_true(rest.start_rest())
	assert_eq(flasks.get_charges(flask.id), 3)


func test_flask_charge_state_restores_without_exceeding_maximum() -> void:
	var setup := _create_flask_owner()
	var flasks := setup.flasks as FlaskChargesComponent
	var flask := setup.flask as ItemData
	flasks.spend_charge(flask.id)
	var state: Variant = flasks.capture_runtime_state()
	flasks.refill_all()
	assert_eq(flasks.get_charges(flask.id), 3)
	flasks.restore_runtime_state(state)
	assert_eq(flasks.get_charges(flask.id), 2)
	flasks.restore_runtime_state({flask.id: 100})
	assert_eq(flasks.get_charges(flask.id), 3)


func test_empty_flask_remains_owned_visible_selected_and_not_droppable() -> void:
	var packed := load("res://game/player/Player.tscn") as PackedScene
	var player := track(packed.instantiate()) as Actor
	player._collect_components()
	var inventory := player.get_component(InventoryComponent) as InventoryComponent
	var flasks := player.get_component(FlaskChargesComponent) as FlaskChargesComponent
	var quick_access := (
		player.get_component(QuickAccessComponent) as QuickAccessComponent
	)
	var hud := (
		player.get_component(QuickAccessHUDComponent) as QuickAccessHUDComponent
	)
	var inventory_drop := (
		player.get_component(InventoryDropComponent) as InventoryDropComponent
	)
	for _charge in 3:
		assert_true(flasks.spend_charge(&"health_potion"))

	assert_eq(flasks.get_charges(&"health_potion"), 0)
	assert_eq(inventory.get_quantity(&"health_potion"), 1)
	assert_true(quick_access.is_slot_available(0))
	assert_true(quick_access.activate_slot(0))
	assert_eq(quick_access.get_active_item_quantity(), 0)
	var display := hud.get_slot_display(0)
	assert_true(display.available)
	assert_false(display.ready)
	assert_eq(display.quantity, "x0")
	assert_eq(display.detail, "Empty")
	assert_eq(inventory_drop.drop_item(&"health_potion"), null)


func _create_flask_owner() -> Dictionary:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var flasks := FlaskChargesComponent.new()
	components.add_child(inventory)
	components.add_child(flasks)
	actor._collect_components()
	var flask := load(
		"res://features/inventory/items/HealthPotion.tres"
	) as ItemData
	inventory.add_item(flask)
	return {
		"flasks": flasks,
		"flask": flask,
	}
