@tool
extends McpTestSuite


func suite_name() -> String:
	return "item_data_profiles"


func test_profiles_separate_equipment_weapon_and_consumable_data() -> void:
	var item := ItemData.new()
	var equipment := ItemEquipmentProfile.new()
	var weapon := ItemWeaponProfile.new()
	var offhand := ItemOffhandProfile.new()
	var consumable := ItemConsumableProfile.new()
	equipment.allowed_slots = [
		ItemData.EquipSlot.MAIN_HAND,
		ItemData.EquipSlot.OFF_HAND,
	]
	equipment.stats = ItemStats.new()
	equipment.stats.damage = 12.0
	weapon.combat_mode = ItemData.CombatMode.MELEE
	weapon.visual_archetype = ItemData.VisualArchetype.LANCER
	weapon.family = ItemWeaponProfile.Family.SPEAR
	weapon.handedness = ItemWeaponProfile.Handedness.TWO_HANDED
	weapon.available_actions = (
		ItemWeaponProfile.Action.LIGHT_ATTACK
		| ItemWeaponProfile.Action.HEAVY_ATTACK
	)
	offhand.family = ItemOffhandProfile.Family.BUCKLER
	offhand.available_actions = ItemOffhandProfile.Action.PARRY
	consumable.use_effect = ItemData.UseEffect.HEAL
	consumable.use_value = 35.0
	consumable.use_visual_effect = ItemData.UseVisualEffect.HEAL
	item.equipment_profile = equipment
	item.weapon_profile = weapon
	item.offhand_profile = offhand
	item.consumable_profile = consumable

	assert_true(item.can_equip_in(ItemData.EquipSlot.MAIN_HAND))
	assert_true(item.can_equip_in(ItemData.EquipSlot.OFF_HAND))
	assert_eq(item.get_primary_equip_slot(), ItemData.EquipSlot.MAIN_HAND)
	assert_eq(item.get_equipment_stats().damage, 12.0)
	assert_eq(item.get_combat_mode(), ItemData.CombatMode.MELEE)
	assert_eq(item.get_visual_archetype(), ItemData.VisualArchetype.LANCER)
	assert_true(item.is_two_handed_weapon())
	assert_true(item.has_weapon_action(ItemWeaponProfile.Action.LIGHT_ATTACK))
	assert_false(item.has_weapon_action(ItemWeaponProfile.Action.GUARD))
	assert_true(item.has_offhand_action(ItemOffhandProfile.Action.PARRY))
	assert_eq(item.get_use_effect(), ItemData.UseEffect.HEAL)
	assert_eq(item.get_use_value(), 35.0)
	assert_eq(item.get_use_visual_effect(), ItemData.UseVisualEffect.HEAL)


func test_legacy_fields_remain_readable_during_migration() -> void:
	var item := ItemData.new()
	item.equip_slot = ItemData.EquipSlot.RING
	item.combat_mode = ItemData.CombatMode.MAGIC
	item.visual_archetype = ItemData.VisualArchetype.ARCHER
	item.use_effect = ItemData.UseEffect.RESTORE_MANA
	item.use_value = 20.0
	item.stats = ItemStats.new()
	item.stats.defense = 3.0

	assert_true(item.can_equip_in(ItemData.EquipSlot.RING))
	assert_eq(item.get_primary_equip_slot(), ItemData.EquipSlot.RING)
	assert_eq(item.get_combat_mode(), ItemData.CombatMode.MAGIC)
	assert_eq(item.get_visual_archetype(), ItemData.VisualArchetype.ARCHER)
	assert_eq(item.get_use_effect(), ItemData.UseEffect.RESTORE_MANA)
	assert_eq(item.get_use_value(), 20.0)
	assert_eq(item.get_equipment_stats().defense, 3.0)


func test_sample_weapons_and_shield_use_specialized_profiles() -> void:
	var sword := load(
		"res://features/inventory/items/RustySword.tres"
	) as ItemData
	var spear := load(
		"res://features/inventory/items/TrainingSpear.tres"
	) as ItemData
	var bow := load(
		"res://features/inventory/items/ShortBow.tres"
	) as ItemData
	var crossbow := load(
		"res://features/inventory/items/LightCrossbow.tres"
	) as ItemData
	var focus := load(
		"res://features/inventory/items/ApprenticeFocus.tres"
	) as ItemData
	var shield := load(
		"res://features/inventory/items/WoodenShield.tres"
	) as ItemData

	assert_eq(sword.weapon_profile.family, ItemWeaponProfile.Family.SWORD)
	assert_true(sword.has_weapon_action(ItemWeaponProfile.Action.PARRY))
	assert_eq(spear.weapon_profile.family, ItemWeaponProfile.Family.SPEAR)
	assert_true(spear.is_two_handed_weapon())
	assert_eq(bow.weapon_profile.ammunition_type, &"arrow")
	assert_true(bow.is_two_handed_weapon())
	assert_true(crossbow.has_weapon_action(ItemWeaponProfile.Action.RELOAD))
	assert_eq(focus.weapon_profile.intelligence_scaling, 1.0)
	assert_eq(shield.weapon_profile, null)
	assert_eq(
		shield.offhand_profile.family,
		ItemOffhandProfile.Family.MEDIUM_SHIELD
	)
	assert_true(shield.has_offhand_action(ItemOffhandProfile.Action.GUARD))
