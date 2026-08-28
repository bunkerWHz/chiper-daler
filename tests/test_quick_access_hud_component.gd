@tool
extends McpTestSuite


func suite_name() -> String:
	return "quick_access_hud"


func test_scene_places_hotbar_right_of_player_health() -> void:
	var hud_scene := load(
		"res://features/inventory/QuickAccessHUDComponent.tscn"
	) as PackedScene
	var hud := track(hud_scene.instantiate()) as QuickAccessHUDComponent
	var margin := hud.get_node("CanvasLayer/TopMargin") as MarginContainer
	assert_eq(margin.offset_left, 260.0)
	assert_eq(margin.offset_top, 16.0)
	assert_true(margin.offset_left > 248.0)


func test_slot_display_tracks_assignments_quantities_and_weapon_sets() -> void:
	var setup := _create_actor()
	var inventory := setup.inventory as InventoryComponent
	var equipment := setup.equipment as EquipmentComponent
	var quick_access := setup.quick_access as QuickAccessComponent
	var hud := setup.hud as QuickAccessHUDComponent

	var sword := _create_item(&"sword", "Sword", false)
	sword.equip_slot = ItemData.EquipSlot.MAIN_HAND
	sword.combat_mode = ItemData.CombatMode.MELEE
	var bomb := _create_item(&"bomb", "Fire Bomb", true)
	bomb.combat_mode = ItemData.CombatMode.THROWABLE
	inventory.add_item(sword)
	inventory.add_item(bomb, 3)
	equipment.equip_inventory_item(sword.id, ItemData.EquipSlot.MAIN_HAND, 0, 0)
	quick_access.assign_item(3, bomb.id)

	var weapon_display := hud.get_slot_display(0)
	assert_true(weapon_display.available)
	assert_true(weapon_display.equipped)
	assert_eq(weapon_display.detail, "Active • Sword")
	assert_eq(weapon_display.icon, ItemData.PLACEHOLDER_ICON)
	assert_eq(QuickAccessHUDComponent.ICON_SIZE, Vector2(64.0, 64.0))
	assert_false(hud.get_slot_display(1).available)
	assert_false(hud.get_slot_display(2).available)
	var item_display := hud.get_slot_display(3)
	assert_true(item_display.available)
	assert_eq(item_display.title, "Fire Bomb")
	assert_eq(item_display.quantity, "x3")
	assert_eq(item_display.icon, ItemData.PLACEHOLDER_ICON)

	quick_access.activate_slot(3)
	assert_true(hud.get_slot_display(3).active)
	assert_true(hud.get_slot_display(0).equipped)
	inventory.remove_item(bomb.id, 3)
	item_display = hud.get_slot_display(3)
	assert_false(item_display.available)
	assert_eq(item_display.detail, "Unavailable")
	quick_access.clear_slot(3)
	assert_eq(hud.get_slot_display(3).title, "Empty")


func _create_actor() -> Dictionary:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var input := InputComponent.new()
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var equipment := EquipmentComponent.new()
	var quick_access := QuickAccessComponent.new()
	quick_access.config = QuickAccessConfig.new()
	var hud := QuickAccessHUDComponent.new()
	for component: Component in [input, inventory, equipment, quick_access, hud]:
		components.add_child(component)
	actor._collect_components()
	return {
		"actor": actor,
		"inventory": inventory,
		"equipment": equipment,
		"quick_access": quick_access,
		"hud": hud,
	}


func _create_item(id: StringName, title: String, stackable: bool) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = title
	item.stackable = stackable
	item.max_stack_size = 10 if stackable else 1
	item.usable_in_combat = true
	return item
