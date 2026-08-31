@tool
extends McpTestSuite


func suite_name() -> String:
	return "starter_equipment"


func test_real_items_fill_starting_weapon_sets() -> void:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var input := InputComponent.new()
	var equipment_scene := load(
		"res://features/equipment/EquipmentComponent.tscn"
	) as PackedScene
	var equipment := equipment_scene.instantiate() as EquipmentComponent
	var inventory_scene := load(
		"res://features/inventory/InventoryComponent.tscn"
	) as PackedScene
	var inventory := inventory_scene.instantiate() as InventoryComponent
	var flasks := FlaskChargesComponent.new()
	var quick_scene := load(
		"res://features/inventory/QuickAccessComponent.tscn"
	) as PackedScene
	var quick_access := quick_scene.instantiate() as QuickAccessComponent
	for component: Component in [
		input, equipment, inventory, flasks, quick_access
	]:
		components.add_child(component)
	actor._collect_components()
	equipment._ready()

	for item_id: StringName in [
		&"training_rapier",
		&"training_katana",
		&"training_dagger",
		&"training_battle_axe",
		&"training_war_hammer",
		&"training_greatsword",
		&"training_great_hammer",
		&"training_staff",
		&"training_halberd",
		&"training_scythe",
		&"training_buckler",
		&"training_greatshield",
		&"training_parrying_dagger",
		&"scout_leather_armor",
		&"knight_plate_armor",
		&"scholar_robe",
		&"scout_leather_hood",
		&"knight_plate_helm",
		&"scholar_hood",
		&"scout_leather_mantle",
		&"knight_plate_pauldrons",
		&"scholar_mantle",
		&"scout_leather_gloves",
		&"knight_plate_gauntlets",
		&"scholar_handwraps",
		&"scout_utility_belt",
		&"knight_war_belt",
		&"scholar_sash",
		&"scout_leather_pants",
		&"knight_plate_leggings",
		&"scholar_trousers",
		&"scout_leather_boots",
		&"knight_plate_greaves",
		&"scholar_shoes",
		&"short_bow",
		&"light_crossbow",
	]:
		assert_eq(inventory.get_quantity(item_id), 1)
	assert_eq(inventory.get_capacity(), 60)
	for removed_id: StringName in [
		&"rusty_sword", &"wooden_shield", &"apprentice_focus", &"training_spear"
	]:
		assert_eq(inventory.get_quantity(removed_id), 0)
	assert_eq(inventory.get_quantity(&"health_potion"), 1)
	assert_eq(inventory.get_quantity(&"mana_potion"), 1)
	assert_eq(inventory.get_quantity(&"rage_potion"), 1)
	assert_eq(flasks.get_charges(&"health_potion"), 3)
	assert_eq(flasks.get_charges(&"mana_potion"), 3)
	assert_eq(flasks.get_charges(&"rage_potion"), 3)
	assert_eq(inventory.get_quantity(&"experience_tonic"), 2)
	assert_true(inventory.get_item_data(&"mana_potion").usable_in_combat)
	assert_true(inventory.get_item_data(&"rage_potion").usable_in_combat)
	assert_eq(
		inventory.get_item_data(&"training_halberd").get_visual_archetype(),
		ItemData.VisualArchetype.LANCER
	)
	assert_true(inventory.get_item_data(&"experience_tonic").usable_in_combat)
	assert_eq(
		equipment.get_equipped_item_id(
			ItemData.EquipSlot.MAIN_HAND, 0, 0
		),
		&"training_katana"
	)
	assert_eq(
		equipment.get_equipped_item_id(
			ItemData.EquipSlot.OFF_HAND, 0, 0
		),
		&"training_buckler"
	)
	assert_eq(
		equipment.get_equipped_item_id(
			ItemData.EquipSlot.MAIN_HAND, 0, 1
		),
		&"short_bow"
	)

	assert_eq(quick_access.get_slot(0).item_id, &"health_potion")
	assert_true(quick_access.is_slot_available(0))
	assert_false(quick_access.activate_slot(1))
	input._weapon_set_swap_pressed = true
	equipment._process(0.0)
	assert_eq(equipment.get_active_weapon_set(), 1)
	assert_eq(equipment.get_current_slot(), EquipmentComponent.Slot.BOW)
	assert_eq(equipment.get_total_defense(), 0.0)
	assert_true(quick_access.activate_slot(0))
	assert_eq(equipment.get_current_slot(), EquipmentComponent.Slot.BOW)


func test_replacing_active_main_hand_changes_combat_mode() -> void:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var input := InputComponent.new()
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var equipment := EquipmentComponent.new()
	for component: Component in [input, inventory, equipment]:
		components.add_child(component)
	actor._collect_components()

	var crossbow := load(
		"res://features/inventory/items/LightCrossbow.tres"
	) as ItemData
	inventory.add_item(crossbow)
	assert_true(equipment.equip_inventory_item(
		crossbow.id, ItemData.EquipSlot.MAIN_HAND
	))
	assert_eq(equipment.get_current_slot(), EquipmentComponent.Slot.CROSSBOW)
