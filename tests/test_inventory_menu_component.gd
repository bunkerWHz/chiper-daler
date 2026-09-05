@tool
extends McpTestSuite


class GroundedBodyComponent:
	extends CharacterBodyComponent


	func on_initialize() -> void:
		pass


	func is_on_floor() -> bool:
		return true


func suite_name() -> String:
	return "inventory_menu"


func test_menu_lists_items_and_assigns_quick_slot() -> void:
	var world := track(Node2D.new()) as Node2D
	var actor := Actor.new()
	world.add_child(actor)
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)

	var input := InputComponent.new()
	var body := GroundedBodyComponent.new()
	var attributes := CharacterAttributesComponent.new()
	attributes.dexterity = 1
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var equipment := EquipmentComponent.new()
	var quick_access := QuickAccessComponent.new()
	quick_access.config = QuickAccessConfig.new()
	var item_use := ItemUseComponent.new()
	item_use.config = ItemUseConfig.new()
	var inventory_drop := InventoryDropComponent.new()
	inventory_drop.loot_bag_scene = load(
		"res://features/loot/LootBag.tscn"
	) as PackedScene
	var menu_scene := load(
		"res://features/inventory/InventoryMenuComponent.tscn"
	) as PackedScene
	var menu := menu_scene.instantiate() as InventoryMenuComponent
	var menu_panel := menu.get_node("CanvasLayer/Panel") as Control
	assert_eq(menu_panel.anchor_left, 0.25)
	assert_eq(menu_panel.anchor_top, 0.0)
	assert_eq(menu_panel.anchor_right, 0.75)
	assert_true(is_equal_approx(menu_panel.anchor_bottom, 0.95))
	assert_eq(menu_panel.offset_top, 92.0)
	for component: Component in [
		input,
		body,
		attributes,
		health,
		inventory,
		equipment,
		quick_access,
		item_use,
		inventory_drop,
		menu,
	]:
		components.add_child(component)
	actor._collect_components()
	menu._ready()

	var potion := ItemData.new()
	potion.id = &"test_potion"
	potion.display_name = "Test Potion"
	potion.category = ItemData.Category.CONSUMABLE
	potion.stackable = true
	potion.max_stack_size = 10
	potion.usable_in_combat = true
	potion.consumable_profile = ItemConsumableProfile.new()
	potion.consumable_profile.use_effect = ItemData.UseEffect.HEAL
	potion.consumable_profile.use_value = 35.0
	assert_eq(inventory.add_item(potion, 3), 3)
	health.take_damage(50.0)

	menu.open_inventory()
	var grid := menu.get_node(
		"CanvasLayer/Panel/Main/Content/Inventory/Scroll/Grid"
	) as GridContainer
	assert_eq(grid.columns, 5)
	assert_true(menu.is_open())
	assert_eq(grid.get_child_count(), inventory.get_capacity())
	assert_eq((grid.get_child(0) as Button).text, "")
	assert_eq((grid.get_child(0) as Button).icon, ItemData.PLACEHOLDER_ICON)
	assert_eq((grid.get_child(1) as Button).icon, ItemData.PLACEHOLDER_ICON)
	menu.show_item_details(potion.id)
	var detail_popup := menu.get_node("CanvasLayer/DetailPopup") as Control
	assert_true(detail_popup.visible)
	menu.hide_hover_details()
	assert_false(detail_popup.visible)
	var clicked_button := grid.get_child(0) as Button
	clicked_button.pressed.emit()
	assert_eq(clicked_button.get_parent(), null)
	assert_eq(grid.get_child_count(), inventory.get_capacity())
	assert_true(detail_popup.visible)
	var summary := menu.get_node(
		"CanvasLayer/Panel/Main/Content/Inventory/Summary"
	) as Label
	assert_true(summary.text.contains("Bag slots 1 / 40"))

	menu._select_item(potion.id)
	menu._use_selected_item()
	assert_false(menu.is_open())
	assert_true(item_use.is_using_item())
	assert_eq(health.get_current_health(), 50.0)
	assert_eq(inventory.get_quantity(potion.id), 3)
	item_use._process(item_use.config.use_duration)
	assert_eq(health.get_current_health(), 85.0)
	assert_eq(inventory.get_quantity(potion.id), 2)
	menu.open_inventory()
	menu._request_drop_selected_item()
	assert_eq(menu._drop_quantity.max_value, 2.0)
	menu._drop_quantity.value = 2
	menu._confirm_drop_selected_item()
	assert_eq(inventory.get_quantity(potion.id), 0)
	assert_true(world.get_child(1) is LootBag)
	var dropped_bag := world.get_child(1) as LootBag
	assert_true(dropped_bag.try_collect(actor))
	assert_eq(inventory.get_quantity(potion.id), 2)
	var potion_payload := menu._inventory_item_payload(potion)
	var double_click_button := InventoryDragButton.new()
	world.add_child(double_click_button)
	var double_click_calls: Array[int] = [0]
	double_click_button.double_clicked.connect(
		func() -> void: double_click_calls[0] += 1
	)
	var double_click_event := InputEventMouseButton.new()
	double_click_event.button_index = MOUSE_BUTTON_LEFT
	double_click_event.pressed = true
	double_click_event.double_click = true
	double_click_button._gui_input(double_click_event)
	assert_eq(double_click_calls[0], 1)
	var quick_drop_target := track(
		InventoryDragButton.new()
	) as InventoryDragButton
	quick_drop_target.drop_target = InventoryDragButton.TARGET_QUICK_SLOT
	assert_true(quick_drop_target._can_drop_data(Vector2.ZERO, potion_payload))
	quick_access.assign_item(3, potion.id)
	menu.show_quick_slot_details(3)
	assert_true(menu._detail_popup.get_text().contains("Test Potion"))
	menu.hide_hover_details()
	menu._on_inventory_data_dropped({
		"kind": InventoryDragButton.KIND_QUICK_SLOT,
		"slot_index": 3,
	})
	assert_eq(quick_access.get_slot(3).kind, QuickAccessSlot.Kind.EMPTY)
	var single_item := ItemData.new()
	single_item.id = &"single_test_item"
	single_item.display_name = "Single Test Item"
	single_item.category = ItemData.Category.MATERIAL
	inventory.add_item(single_item)
	menu._select_item(single_item.id)
	var child_count_before_single_drop := world.get_child_count()
	menu._request_drop_selected_item()
	assert_eq(inventory.get_quantity(single_item.id), 0)
	assert_eq(world.get_child_count(), child_count_before_single_drop + 1)
	assert_true(world.get_child(world.get_child_count() - 1) is LootBag)

	var sword := ItemData.new()
	sword.id = &"test_sword"
	sword.display_name = "Test Sword"
	sword.category = ItemData.Category.WEAPON
	sword.equipment_profile = ItemEquipmentProfile.new()
	sword.equipment_profile.allowed_slots = [ItemData.EquipSlot.MAIN_HAND]
	sword.equipment_profile.stats = ItemStats.new()
	sword.equipment_profile.stats.damage = 5.0
	sword.sell_price = 25
	inventory.add_item(sword)
	equipment.equip_inventory_item(sword.id, sword.get_primary_equip_slot())
	menu._rebuild()
	assert_eq(menu._get_unequipped_stacks().size(), 1)
	assert_eq(equipment.get_equipped_item_count(sword.id), 1)
	var sword_payload := menu._inventory_item_payload(sword)
	var equipment_drop_target := track(
		InventoryDragButton.new()
	) as InventoryDragButton
	equipment_drop_target.drop_target = InventoryDragButton.TARGET_EQUIPMENT
	equipment_drop_target.target_equip_slot = ItemData.EquipSlot.MAIN_HAND
	assert_true(equipment_drop_target._can_drop_data(Vector2.ZERO, sword_payload))
	equipment_drop_target.target_equip_slot = ItemData.EquipSlot.RING
	assert_false(equipment_drop_target._can_drop_data(Vector2.ZERO, sword_payload))
	var equipped_sword_payload := {
		"kind": InventoryDragButton.KIND_EQUIPPED_ITEM,
		"item_id": sword.id,
		"equip_slot": ItemData.EquipSlot.MAIN_HAND,
		"slot_index": 0,
		"weapon_set": 0,
	}
	equipment_drop_target.target_equip_slot = ItemData.EquipSlot.MAIN_HAND
	assert_true(equipment_drop_target._can_drop_data(
		Vector2.ZERO, equipped_sword_payload
	))
	menu._on_inventory_data_dropped({
		"kind": InventoryDragButton.KIND_EQUIPPED_ITEM,
		"equip_slot": ItemData.EquipSlot.MAIN_HAND,
		"slot_index": 0,
		"weapon_set": 0,
	})
	assert_false(equipment.is_item_equipped(sword.id))
	assert_eq(menu._get_unequipped_stacks().size(), 2)
	menu._on_equipment_data_dropped(
		sword_payload, ItemData.EquipSlot.MAIN_HAND, 0, 1
	)
	assert_eq(
		equipment.get_equipped_item_id(ItemData.EquipSlot.MAIN_HAND, 0, 1),
		sword.id
	)
	equipment.unequip_item(ItemData.EquipSlot.MAIN_HAND, 0, 1)
	equipment.equip_inventory_item(sword.id, sword.get_primary_equip_slot(), 0, 0)
	menu._on_equipment_data_dropped(
		equipped_sword_payload, ItemData.EquipSlot.MAIN_HAND, 0, 1
	)
	assert_eq(
		equipment.get_equipped_item_id(ItemData.EquipSlot.MAIN_HAND, 0, 1),
		sword.id
	)
	assert_true(
		equipment.get_equipped_item_id(
			ItemData.EquipSlot.MAIN_HAND, 0, 0
		).is_empty()
	)
	equipment.unequip_item(ItemData.EquipSlot.MAIN_HAND, 0, 1)
	equipment.equip_inventory_item(sword.id, sword.get_primary_equip_slot(), 0, 0)
	var crossbow := ItemData.new()
	crossbow.id = &"test_crossbow"
	crossbow.display_name = "Test Crossbow"
	crossbow.category = ItemData.Category.WEAPON
	crossbow.equipment_profile = ItemEquipmentProfile.new()
	crossbow.equipment_profile.allowed_slots = [ItemData.EquipSlot.MAIN_HAND]
	crossbow.equipment_profile.stats = ItemStats.new()
	crossbow.equipment_profile.stats.damage = 12.0
	crossbow.equipment_profile.stats.dexterity_requirement = 3
	crossbow.sell_price = 100
	crossbow.weapon_profile = ItemWeaponProfile.new()
	crossbow.weapon_profile.combat_mode = ItemData.CombatMode.CROSSBOW
	crossbow.weapon_profile.family = ItemWeaponProfile.Family.CROSSBOW
	crossbow.weapon_profile.handedness = (
		ItemWeaponProfile.Handedness.TWO_HANDED
	)
	crossbow.weapon_profile.primary_damage_type = (
		ItemWeaponProfile.DamageType.PIERCE
	)
	crossbow.weapon_profile.moveset_id = &"crossbow_test"
	crossbow.weapon_profile.available_actions = (
		ItemWeaponProfile.Action.AIM
		| ItemWeaponProfile.Action.FIRE
		| ItemWeaponProfile.Action.RELOAD
	)
	crossbow.weapon_profile.dexterity_scaling = 0.8
	crossbow.weapon_profile.ammunition_type = &"bolt"
	inventory.add_item(crossbow)
	menu._on_category_selected(ItemData.Category.WEAPON + 1)
	assert_eq(grid.get_child_count(), 1)
	menu._on_sort_selected(InventoryMenuComponent.SortMode.VALUE)
	assert_eq(
		(grid.get_child(0) as InventoryDragButton).drag_payload.item_id,
		crossbow.id
	)
	menu._on_category_selected(0)
	assert_eq(grid.get_child_count(), inventory.get_capacity())
	var equipment_slots := menu.get_node(
		"CanvasLayer/Panel/Main/Content/Equipment/EquipmentScroll/EquipmentSlots"
	) as GridContainer
	var equipment_column := equipment_slots.get_parent().get_parent() as VBoxContainer
	assert_eq(equipment_column.custom_minimum_size.x, 232.0)
	assert_eq(equipment_slots.columns, 3)
	assert_eq(equipment_slots.get_child_count(), 21)
	var expected_slots: Array[int] = [
		ItemData.EquipSlot.SHOULDER,
		ItemData.EquipSlot.HEAD,
		ItemData.EquipSlot.ARTIFACT,
		ItemData.EquipSlot.EARRING,
		ItemData.EquipSlot.AMULET,
		ItemData.EquipSlot.EARRING,
		ItemData.EquipSlot.MAIN_HAND,
		ItemData.EquipSlot.CHEST,
		ItemData.EquipSlot.BROOCH,
		ItemData.EquipSlot.HANDS,
		ItemData.EquipSlot.BELT,
		ItemData.EquipSlot.OFF_HAND,
		ItemData.EquipSlot.RING,
		ItemData.EquipSlot.LEGS,
		ItemData.EquipSlot.RING,
		ItemData.EquipSlot.RING,
		ItemData.EquipSlot.FEET,
		ItemData.EquipSlot.RING,
		ItemData.EquipSlot.RUNE,
		ItemData.EquipSlot.RUNE,
		ItemData.EquipSlot.RUNE,
	]
	for index in expected_slots.size():
		var equipment_button := (
			equipment_slots.get_child(index) as InventoryDragButton
		)
		assert_eq(int(equipment_button.target_equip_slot), expected_slots[index])
	var weapon_sets := menu.get_node(
		"CanvasLayer/Panel/Main/Content/Equipment/WeaponSets"
	) as HBoxContainer
	var set_one_button := weapon_sets.get_child(0) as Button
	var set_two_button := weapon_sets.get_child(1) as Button
	assert_eq(set_one_button.text, "Set 1")
	assert_eq(set_two_button.text, "Set 2")
	assert_false(set_one_button.text.contains("Active"))
	assert_eq(set_one_button.theme_type_variation, &"ActiveWeaponSet")
	assert_eq(set_two_button.theme_type_variation, &"")
	var first_equipped_button := (
		equipment_slots.get_child(6) as InventoryDragButton
	)
	assert_eq(first_equipped_button.text, "")
	assert_eq(first_equipped_button.icon, ItemData.PLACEHOLDER_ICON)
	first_equipped_button.focus_entered.emit()
	assert_true(detail_popup.visible)
	assert_true(menu._detail_popup.get_text().contains("Test Sword"))
	first_equipped_button.focus_exited.emit()
	menu._select_item(crossbow.id)
	var details := menu.get_node(
		"CanvasLayer/DetailPopup/Margin/Details"
	) as Label
	var equip_button := menu.get_node(
		"CanvasLayer/Panel/Main/Actions/Equip"
	) as Button
	assert_true(details.text.contains("Requirements not met: DEX 3"))
	assert_true(details.text.contains("Compared with Test Sword"))
	assert_true(details.text.contains("Damage +7.0"))
	assert_true(details.text.contains("Weapon: Crossbow  Two Handed"))
	assert_true(details.text.contains("Actions: Aim, Fire"))
	assert_false(details.text.contains("Reload"))
	assert_false(details.text.contains("Scaling:"))
	assert_false(details.text.contains("Speed x"))
	assert_false(details.text.contains("Moveset:"))
	assert_true(details.text.contains("Ammunition: Bolt"))
	var shield := load(
		"res://features/inventory/items/WoodenShield.tres"
	) as ItemData
	var shield_details := menu._detail_popup.get_item_text(shield)
	assert_true(shield_details.contains("Offhand: Medium Shield"))
	assert_true(shield_details.contains("Actions: Guard, Parry"))
	assert_true(shield_details.contains("Block 50%"))
	assert_true(equip_button.disabled)
	menu._equip_item_by_double_click(crossbow.id)
	assert_true(menu._action_feedback.visible)
	assert_true(menu._action_feedback.text.contains("DEX 3"))
	assert_false(equipment.is_item_equipped(crossbow.id))
	menu._activate_weapon_set(1)
	assert_false(menu._action_feedback.visible)
	assert_eq(equipment.get_active_weapon_set(), 1)
	assert_eq(set_one_button.theme_type_variation, &"")
	assert_eq(set_two_button.theme_type_variation, &"ActiveWeaponSet")
	menu._select_item(sword.id)
	menu._equip_selected_item()
	assert_false(equipment.is_item_equipped(sword.id))
	var boots_one := _create_equipment_item(
		&"boots_one", "Boots One", ItemData.EquipSlot.FEET
	)
	var boots_two := _create_equipment_item(
		&"boots_two", "Boots Two", ItemData.EquipSlot.FEET
	)
	inventory.add_item(boots_one)
	inventory.add_item(boots_two)
	menu._equip_item_by_double_click(boots_one.id)
	assert_eq(
		equipment.get_equipped_item_id(ItemData.EquipSlot.FEET),
		boots_one.id
	)
	menu._equip_item_by_double_click(boots_two.id)
	assert_eq(
		equipment.get_equipped_item_id(ItemData.EquipSlot.FEET),
		boots_two.id
	)
	var equipped_boots_button := (
		equipment_slots.get_child(16) as InventoryDragButton
	)
	equipped_boots_button.double_clicked.emit()
	assert_true(
		equipment.get_equipped_item_id(ItemData.EquipSlot.FEET).is_empty()
	)
	menu.close_inventory()
	assert_false(menu.is_open())


func test_menu_pause_lifecycle_preserves_other_owners() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var was_paused := tree.paused
	var player := track(load("res://game/player/Player.tscn").instantiate()) as Actor
	tree.root.add_child(player)
	var menu := player.get_component(InventoryMenuComponent) as InventoryMenuComponent

	# Closing a menu which never opened must not clear an existing pause.
	tree.paused = true
	menu.close_inventory()
	assert_true(tree.paused)
	menu.open_inventory()
	menu.close_inventory()
	assert_true(tree.paused)
	tree.paused = false

	menu.open_inventory()
	menu.open_inventory()
	assert_true(tree.paused)
	menu.close_inventory()
	assert_false(tree.paused)

	menu.open_inventory()
	var other_screen := PauseLease.acquire(tree)
	menu.disable()
	assert_true(tree.paused)
	assert_false(menu.is_open())
	other_screen.release()
	assert_false(tree.paused)

	menu.enable()
	assert_eq(menu.process_mode, Node.PROCESS_MODE_ALWAYS)
	menu.open_inventory()
	assert_true(tree.paused)
	tree.root.remove_child(player)
	assert_false(tree.paused)
	assert_false(tree.has_meta(PauseLease.STATE_KEY))
	tree.paused = was_paused


func _create_equipment_item(
	item_id: StringName,
	display_name: String,
	slot: ItemData.EquipSlot
) -> ItemData:
	var item := ItemData.new()
	item.id = item_id
	item.display_name = display_name
	item.category = ItemData.Category.ARMOR
	item.equipment_profile = ItemEquipmentProfile.new()
	item.equipment_profile.allowed_slots = [slot]
	item.equipment_profile.stats = ItemStats.new()
	return item
