@tool
extends McpTestSuite


func suite_name() -> String:
	return "ranged_weapon"


func test_bow_aims_and_looses_arrow_on_primary_release() -> void:
	var setup := _create_ranged_actor()
	var input := setup.input as InputComponent
	var equipment := setup.equipment as EquipmentComponent
	var ranged := setup.ranged as RangedWeaponComponent
	var actor_state := setup.actor_state as ActorStateComponent
	equipment.equip(EquipmentComponent.Slot.BOW)
	input._attack_just_pressed = true
	input._attack_pressed = true
	ranged._process(0.0)
	actor_state.refresh_state()
	assert_eq(actor_state.get_state(), ActorState.Behavior.AIM_BOW)

	input._attack_pressed = false
	input._attack_released = true
	ranged._process(0.0)
	actor_state.refresh_state()
	assert_eq(actor_state.get_state(), ActorState.Behavior.LOOSE_ARROW)
	assert_eq(ranged.get_arrow_count(), 19)

	ranged._process(ranged.config.release_duration)
	actor_state.refresh_state()
	assert_eq(actor_state.get_state(), ActorState.Behavior.IDLE)


func test_crossbow_fires_on_primary_release() -> void:
	var setup := _create_ranged_actor()
	var input := setup.input as InputComponent
	var equipment := setup.equipment as EquipmentComponent
	var ranged := setup.ranged as RangedWeaponComponent
	var actor_state := setup.actor_state as ActorStateComponent
	preload("res://tests/AimingTestFactory.gd").select_weapon(setup, EquipmentComponent.Slot.CROSSBOW)
	input._attack_just_pressed = true
	ranged._process(0.0)
	actor_state.refresh_state()
	assert_eq(actor_state.get_state(), ActorState.Behavior.AIM_CROSSBOW)

	input._attack_released = true
	ranged._process(0.0)
	actor_state.refresh_state()
	assert_eq(actor_state.get_state(), ActorState.Behavior.FIRE_CROSSBOW)
	assert_eq(ranged.get_bolt_count(), 11)


func test_ranged_aim_cancels_when_active_weapon_context_changes() -> void:
	var setup := _create_ranged_actor()
	var actor := setup.actor as Actor
	var input := setup.input as InputComponent
	var equipment := setup.equipment as EquipmentComponent
	var ranged := setup.ranged as RangedWeaponComponent
	equipment.equip(EquipmentComponent.Slot.BOW)
	input._attack_just_pressed = true
	ranged._process(0.0)
	assert_eq(ranged.get_phase(), RangedWeaponComponent.Phase.BOW_AIM)

	equipment.loadout_item_changed.emit(
		ItemData.EquipSlot.MAIN_HAND,
		0,
		equipment.get_active_weapon_set(),
		&"old_bow",
		&"new_bow"
	)
	assert_eq(ranged.get_phase(), RangedWeaponComponent.Phase.NONE)

	input._attack_just_pressed = true
	ranged._process(0.0)
	assert_eq(ranged.get_phase(), RangedWeaponComponent.Phase.BOW_AIM)
	equipment.switch_weapon_set(1)
	assert_eq(ranged.get_phase(), RangedWeaponComponent.Phase.NONE)

	var equipment_connections := equipment.equipment_changed.get_connections().size()
	var loadout_connections := equipment.loadout_item_changed.get_connections().size()
	var swap_connections := equipment.weapon_set_changed.get_connections().size()
	actor._collect_components()
	assert_eq(equipment.equipment_changed.get_connections().size(), equipment_connections)
	assert_eq(equipment.loadout_item_changed.get_connections().size(), loadout_connections)
	assert_eq(equipment.weapon_set_changed.get_connections().size(), swap_connections)


func test_bow_profile_requires_aim_and_fire_actions() -> void:
	var setup := _create_ranged_actor()
	var input := setup.input as InputComponent
	var inventory := setup.inventory as InventoryComponent
	var equipment := setup.equipment as EquipmentComponent
	var ranged := setup.ranged as RangedWeaponComponent
	var bow := ItemData.new()
	bow.id = &"restricted_bow"
	bow.equipment_profile = ItemEquipmentProfile.new()
	bow.equipment_profile.allowed_slots = [ItemData.EquipSlot.MAIN_HAND]
	bow.weapon_profile = ItemWeaponProfile.new()
	bow.weapon_profile.combat_mode = ItemData.CombatMode.BOW
	bow.weapon_profile.ammunition_type = &"arrow"
	bow.weapon_profile.available_actions = ItemWeaponProfile.Action.AIM
	inventory.add_item(bow)
	assert_true(equipment.equip_inventory_item(
		bow.id, ItemData.EquipSlot.MAIN_HAND
	))

	input._attack_just_pressed = true
	ranged._process(0.0)
	assert_eq(ranged.get_phase(), RangedWeaponComponent.Phase.BOW_AIM)
	input._attack_released = true
	ranged._process(0.0)
	assert_eq(ranged.get_phase(), RangedWeaponComponent.Phase.NONE)
	assert_eq(ranged.get_arrow_count(), 20)

	bow.weapon_profile.available_actions |= ItemWeaponProfile.Action.FIRE
	input._attack_just_pressed = true
	ranged._process(0.0)
	input._attack_released = true
	ranged._process(0.0)
	assert_eq(ranged.get_phase(), RangedWeaponComponent.Phase.BOW_LOOSE)
	assert_eq(ranged.get_arrow_count(), 19)


func _create_ranged_actor() -> Dictionary:
	var setup := preload("res://tests/AimingTestFactory.gd").create()
	track(setup.root)
	return setup
