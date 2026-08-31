@tool
extends McpTestSuite


func suite_name() -> String:
	return "equipment"


func test_tab_request_cycles_weapon_set() -> void:
	var setup := _create_equipped_actor()
	var input := setup.input as InputComponent
	var equipment := setup.equipment as EquipmentComponent

	assert_eq(equipment.get_active_weapon_set(), 0)
	assert_eq(InputComponent.WEAPON_SET_SWAP_ACTION, &"weapon_set_swap")
	assert_true(InputMap.has_action(InputComponent.WEAPON_SET_SWAP_ACTION))
	input._weapon_set_swap_pressed = true
	equipment._process(0.0)
	assert_eq(equipment.get_active_weapon_set(), 1)
	input._weapon_set_swap_pressed = true
	equipment._process(0.0)
	assert_eq(equipment.get_active_weapon_set(), 0)


func test_switching_from_melee_cancels_attack_and_guard() -> void:
	var setup := _create_equipped_actor()
	var equipment := setup.equipment as EquipmentComponent
	var attack := setup.attack as AttackComponent
	var guard := setup.guard as GuardComponent
	var hitbox := setup.hitbox as HitboxComponent

	assert_true(attack.attack())
	assert_true(attack.is_attacking())
	equipment.equip(EquipmentComponent.Slot.BOW)

	assert_false(attack.is_attacking())
	assert_false(attack.can_attack())
	assert_false(hitbox._area.monitoring)
	assert_false(guard.start_guard())
	assert_false(guard.start_parry())


func test_removing_last_active_weapon_disables_melee_actions() -> void:
	var setup := _create_equipped_actor()
	var inventory := setup.inventory as InventoryComponent
	var equipment := setup.equipment as EquipmentComponent
	var attack := setup.attack as AttackComponent
	var guard := setup.guard as GuardComponent
	var sword := setup.sword as ItemData

	assert_true(equipment.allows_melee_actions())
	assert_true(guard.start_guard())
	guard.stop_guard()
	assert_true(attack.attack())
	assert_eq(inventory.remove_item(sword.id), 1)
	assert_false(equipment.allows_melee_actions())
	assert_false(attack.is_attacking())
	assert_false(attack.attack())
	assert_false(attack.heavy_attack())
	assert_false(guard.start_guard())
	assert_false(guard.start_parry())


func test_weapon_and_offhand_profiles_gate_combat_actions() -> void:
	var setup := _create_equipped_actor()
	var inventory := setup.inventory as InventoryComponent
	var equipment := setup.equipment as EquipmentComponent
	var attack := setup.attack as AttackComponent
	var guard := setup.guard as GuardComponent
	var sword := setup.sword as ItemData
	var weapon_profile := ItemWeaponProfile.new()
	weapon_profile.combat_mode = ItemData.CombatMode.MELEE
	weapon_profile.available_actions = ItemWeaponProfile.Action.LIGHT_ATTACK
	sword.weapon_profile = weapon_profile
	var shield := _create_equippable(
		&"action_test_shield", ItemData.EquipSlot.OFF_HAND
	)
	var offhand_profile := ItemOffhandProfile.new()
	offhand_profile.available_actions = ItemOffhandProfile.Action.GUARD
	shield.offhand_profile = offhand_profile
	inventory.add_item(shield)
	assert_true(equipment.equip_inventory_item(
		shield.id, ItemData.EquipSlot.OFF_HAND
	))

	assert_true(equipment.allows_light_attack())
	assert_false(equipment.allows_heavy_attack())
	assert_true(equipment.allows_guard())
	assert_false(equipment.allows_parry())
	assert_false(attack.heavy_attack())
	assert_true(attack.attack())
	attack._process(attack.config.active_duration + attack.config.cooldown)
	assert_true(guard.start_guard())
	guard.stop_guard()
	assert_false(guard.start_parry())


func test_disabled_equipment_is_safe_for_scripted_combat() -> void:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)

	var input := InputComponent.new()
	var equipment := EquipmentComponent.new()
	equipment.disable()
	var facing := FacingComponent.new()
	var hitbox := HitboxComponent.new()
	var area := Area2D.new()
	area.name = "Area2D"
	hitbox.add_child(area)
	var attack := AttackComponent.new()
	attack.config = AttackConfig.new()
	var guard := GuardComponent.new()
	guard.config = GuardConfig.new()

	for component: Component in [
		input,
		equipment,
		facing,
		hitbox,
		attack,
		guard,
	]:
		components.add_child(component)

	actor._collect_components()
	hitbox._ready()
	attack._ready()

	assert_false(equipment.is_enabled)
	assert_true(attack.attack())
	attack._process(attack.config.active_duration)
	assert_true(guard.start_guard())


func test_paper_doll_supports_two_weapon_sets_and_slot_limits() -> void:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var input := InputComponent.new()
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var equipment := EquipmentComponent.new()
	components.add_child(input)
	components.add_child(equipment)
	components.add_child(inventory)
	actor._collect_components()

	var sword := _create_equippable(&"iron_sword", ItemData.EquipSlot.MAIN_HAND)
	var bow := _create_equippable(&"short_bow", ItemData.EquipSlot.MAIN_HAND)
	var shield := _create_equippable(&"wood_shield", ItemData.EquipSlot.OFF_HAND)
	var helmet := _create_equippable(&"iron_helmet", ItemData.EquipSlot.HEAD)
	var ring := _create_equippable(&"copper_ring", ItemData.EquipSlot.RING)
	var belt := _create_equippable(&"leather_belt", ItemData.EquipSlot.BELT)
	var boots := _create_equippable(&"leather_boots", ItemData.EquipSlot.FEET)
	var shoulder := _create_equippable(
		&"iron_shoulder", ItemData.EquipSlot.SHOULDER
	)
	var artifact := _create_equippable(
		&"old_artifact", ItemData.EquipSlot.ARTIFACT
	)
	var brooch := _create_equippable(&"silver_brooch", ItemData.EquipSlot.BROOCH)
	var rune := _create_equippable(&"minor_rune", ItemData.EquipSlot.RUNE)
	assert_eq(inventory.add_item(sword), 1)
	assert_eq(inventory.add_item(bow), 1)
	assert_eq(inventory.add_item(shield), 1)
	assert_eq(inventory.add_item(helmet), 1)
	assert_eq(inventory.add_item(ring, 4), 4)
	assert_eq(inventory.add_item(belt), 1)
	assert_eq(inventory.add_item(boots), 1)
	assert_eq(inventory.add_item(shoulder), 1)
	assert_eq(inventory.add_item(artifact), 1)
	assert_eq(inventory.add_item(brooch), 1)
	assert_eq(inventory.add_item(rune, 3), 3)

	assert_true(equipment.equip_inventory_item(
		sword.id, ItemData.EquipSlot.MAIN_HAND, 0, 0
	))
	assert_true(equipment.equip_inventory_item(
		shield.id, ItemData.EquipSlot.OFF_HAND, 0, 0
	))
	assert_true(equipment.equip_inventory_item(
		bow.id, ItemData.EquipSlot.MAIN_HAND, 0, 1
	))
	assert_true(equipment.equip_inventory_item(
		helmet.id, ItemData.EquipSlot.HEAD
	))
	assert_true(equipment.equip_inventory_item(
		ring.id, ItemData.EquipSlot.RING, 0
	))
	assert_true(equipment.equip_inventory_item(
		ring.id, ItemData.EquipSlot.RING, 1
	))
	assert_true(equipment.equip_inventory_item(
		ring.id, ItemData.EquipSlot.RING, 2
	))
	assert_true(equipment.equip_inventory_item(
		ring.id, ItemData.EquipSlot.RING, 3
	))
	assert_false(equipment.equip_inventory_item(
		ring.id, ItemData.EquipSlot.RING, 4
	))
	assert_true(equipment.equip_inventory_item(
		belt.id, ItemData.EquipSlot.BELT
	))
	assert_true(equipment.equip_inventory_item(
		boots.id, ItemData.EquipSlot.FEET
	))
	assert_true(equipment.equip_inventory_item(
		shoulder.id, ItemData.EquipSlot.SHOULDER
	))
	assert_true(equipment.equip_inventory_item(
		artifact.id, ItemData.EquipSlot.ARTIFACT
	))
	assert_true(equipment.equip_inventory_item(
		brooch.id, ItemData.EquipSlot.BROOCH
	))
	for rune_index in 3:
		assert_true(equipment.equip_inventory_item(
			rune.id, ItemData.EquipSlot.RUNE, rune_index
		))
	assert_false(equipment.equip_inventory_item(
		rune.id, ItemData.EquipSlot.RUNE, 3
	))
	assert_false(equipment.equip_inventory_item(
		helmet.id, ItemData.EquipSlot.OFF_HAND
	))

	assert_eq(
		equipment.get_equipped_item_id(ItemData.EquipSlot.MAIN_HAND, 0, 0),
		sword.id
	)
	assert_true(equipment.switch_weapon_set(1))
	assert_eq(equipment.get_active_weapon_set(), 1)
	assert_eq(
		equipment.get_equipped_item_id(ItemData.EquipSlot.MAIN_HAND),
		bow.id
	)
	var overlay := DebugOverlayComponent.new()
	overlay.actor = actor
	var lines := PackedStringArray()
	overlay._append_equipment_info(lines)
	assert_true(lines.has(
		"Weapon Set: 2  Main: short_bow  Off: none"
	))

	inventory.remove_item(sword.id)
	assert_eq(
		equipment.get_equipped_item_id(ItemData.EquipSlot.MAIN_HAND, 0, 0),
		&""
	)


func test_two_handed_weapon_reserves_both_hands_in_its_set() -> void:
	var setup := _create_equipment_only_actor()
	var inventory := setup.inventory as InventoryComponent
	var equipment := setup.equipment as EquipmentComponent
	var sword := _create_equippable(&"sword", ItemData.EquipSlot.MAIN_HAND)
	var spear := _create_equippable(&"spear", ItemData.EquipSlot.MAIN_HAND)
	var spear_profile := ItemWeaponProfile.new()
	spear_profile.handedness = ItemWeaponProfile.Handedness.TWO_HANDED
	spear.weapon_profile = spear_profile
	var shield := _create_equippable(&"shield", ItemData.EquipSlot.OFF_HAND)
	inventory.add_item(sword)
	inventory.add_item(spear)
	inventory.add_item(shield, 2)

	assert_true(equipment.equip_inventory_item(
		sword.id, ItemData.EquipSlot.MAIN_HAND, 0, 0
	))
	assert_true(equipment.equip_inventory_item(
		shield.id, ItemData.EquipSlot.OFF_HAND, 0, 0
	))
	assert_true(equipment.equip_inventory_item(
		shield.id, ItemData.EquipSlot.OFF_HAND, 0, 1
	))
	assert_true(equipment.equip_inventory_item(
		spear.id, ItemData.EquipSlot.MAIN_HAND, 0, 0
	))

	assert_eq(
		equipment.get_equipped_item_id(ItemData.EquipSlot.OFF_HAND, 0, 0),
		&""
	)
	assert_eq(
		equipment.get_equipped_item_id(ItemData.EquipSlot.OFF_HAND, 0, 1),
		shield.id
	)
	assert_false(equipment.is_off_hand_available(0))
	assert_true(equipment.is_off_hand_available(1))
	assert_false(equipment.equip_inventory_item(
		shield.id, ItemData.EquipSlot.OFF_HAND, 0, 0
	))


func test_ranged_two_handed_weapon_replaces_offhand_with_matching_ammo() -> void:
	var setup := _create_equipment_only_actor()
	var inventory := setup.inventory as InventoryComponent
	var equipment := setup.equipment as EquipmentComponent
	var sword := _create_equippable(&"sword", ItemData.EquipSlot.MAIN_HAND)
	var shield := _create_equippable(&"shield", ItemData.EquipSlot.OFF_HAND)
	var bow := _create_equippable(&"bow", ItemData.EquipSlot.MAIN_HAND)
	bow.weapon_profile = ItemWeaponProfile.new()
	bow.weapon_profile.family = ItemWeaponProfile.Family.BOW
	bow.weapon_profile.handedness = ItemWeaponProfile.Handedness.TWO_HANDED
	bow.weapon_profile.ammunition_type = &"arrow"
	var arrows := _create_equippable(
		&"arrows", ItemData.EquipSlot.OFF_HAND
	)
	arrows.category = ItemData.Category.AMMUNITION
	arrows.stackable = true
	arrows.max_stack_size = 99
	arrows.ammunition_profile = ItemAmmunitionProfile.new()
	arrows.ammunition_profile.ammunition_type = &"arrow"
	var bolts := _create_equippable(&"bolts", ItemData.EquipSlot.OFF_HAND)
	bolts.category = ItemData.Category.AMMUNITION
	bolts.ammunition_profile = ItemAmmunitionProfile.new()
	bolts.ammunition_profile.ammunition_type = &"bolt"
	for item: ItemData in [sword, shield, bow, arrows, bolts]:
		inventory.add_item(item, 10 if item == arrows else 1)
	assert_true(equipment.equip_inventory_item(
		sword.id, ItemData.EquipSlot.MAIN_HAND
	))
	assert_true(equipment.equip_inventory_item(
		shield.id, ItemData.EquipSlot.OFF_HAND
	))
	assert_true(equipment.equip_inventory_item(
		bow.id, ItemData.EquipSlot.MAIN_HAND
	))
	assert_eq(
		equipment.get_equipped_item_id(ItemData.EquipSlot.MAIN_HAND),
		bow.id
	)
	assert_eq(
		equipment.get_equipped_item_id(ItemData.EquipSlot.OFF_HAND),
		arrows.id
	)
	assert_false(equipment.is_item_equipped(sword.id))
	assert_false(equipment.is_item_equipped(shield.id))
	assert_false(equipment.equip_inventory_item(
		bolts.id, ItemData.EquipSlot.OFF_HAND
	))
	equipment.unequip_item(ItemData.EquipSlot.MAIN_HAND)
	assert_true(
		equipment.get_equipped_item_id(ItemData.EquipSlot.OFF_HAND).is_empty()
	)


func test_restored_two_handed_set_discards_incompatible_offhand() -> void:
	var setup := _create_equipment_only_actor()
	var inventory := setup.inventory as InventoryComponent
	var equipment := setup.equipment as EquipmentComponent
	var spear := _create_equippable(&"restored_spear", ItemData.EquipSlot.MAIN_HAND)
	var spear_profile := ItemWeaponProfile.new()
	spear_profile.handedness = ItemWeaponProfile.Handedness.TWO_HANDED
	spear.weapon_profile = spear_profile
	var shield := _create_equippable(
		&"restored_shield", ItemData.EquipSlot.OFF_HAND
	)
	inventory.add_item(spear)
	inventory.add_item(shield)
	var main_key := equipment._make_equipment_key(
		ItemData.EquipSlot.MAIN_HAND, 0, 0
	)
	var off_key := equipment._make_equipment_key(
		ItemData.EquipSlot.OFF_HAND, 0, 0
	)
	equipment.restore_runtime_state({
		"active_weapon_set": 0,
		"equipped_items": {
			main_key: spear.id,
			off_key: shield.id,
		},
	})

	assert_eq(
		equipment.get_equipped_item_id(ItemData.EquipSlot.MAIN_HAND), spear.id
	)
	assert_eq(
		equipment.get_equipped_item_id(ItemData.EquipSlot.OFF_HAND), &""
	)


func _create_equipped_actor() -> Dictionary:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)

	var input := InputComponent.new()
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var equipment := EquipmentComponent.new()
	var facing := FacingComponent.new()
	var hitbox := HitboxComponent.new()
	var area := Area2D.new()
	area.name = "Area2D"
	hitbox.add_child(area)
	var attack := AttackComponent.new()
	attack.config = AttackConfig.new()
	var guard := GuardComponent.new()
	guard.config = GuardConfig.new()

	for component: Component in [
		input,
		inventory,
		equipment,
		facing,
		hitbox,
		attack,
		guard,
	]:
		components.add_child(component)

	actor._collect_components()
	var sword := _create_equippable(
		&"equipped_test_sword", ItemData.EquipSlot.MAIN_HAND
	)
	sword.combat_mode = ItemData.CombatMode.MELEE
	inventory.add_item(sword)
	equipment.equip_inventory_item(
		sword.id, ItemData.EquipSlot.MAIN_HAND
	)
	hitbox._ready()
	attack._ready()

	return {
		"actor": actor,
		"input": input,
		"inventory": inventory,
		"equipment": equipment,
		"sword": sword,
		"facing": facing,
		"hitbox": hitbox,
		"attack": attack,
		"guard": guard,
	}


func _create_equipment_only_actor() -> Dictionary:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var input := InputComponent.new()
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var equipment := EquipmentComponent.new()
	components.add_child(input)
	components.add_child(inventory)
	components.add_child(equipment)
	actor._collect_components()
	return {
		"inventory": inventory,
		"equipment": equipment,
	}


func _create_equippable(
	id: StringName,
	equip_slot: ItemData.EquipSlot
) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.equip_slot = equip_slot
	return item
