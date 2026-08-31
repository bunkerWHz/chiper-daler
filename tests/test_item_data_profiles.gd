@tool
extends McpTestSuite


func suite_name() -> String:
	return "item_data_profiles"


func test_profiles_separate_equipment_weapon_and_consumable_data() -> void:
	var item := ItemData.new()
	var equipment := ItemEquipmentProfile.new()
	var weapon := ItemWeaponProfile.new()
	var consumable := ItemConsumableProfile.new()
	equipment.allowed_slots = [
		ItemData.EquipSlot.MAIN_HAND,
		ItemData.EquipSlot.OFF_HAND,
	]
	equipment.stats = ItemStats.new()
	equipment.stats.damage = 12.0
	weapon.combat_mode = ItemData.CombatMode.MELEE
	weapon.visual_archetype = ItemData.VisualArchetype.LANCER
	consumable.use_effect = ItemData.UseEffect.HEAL
	consumable.use_value = 35.0
	consumable.use_visual_effect = ItemData.UseVisualEffect.HEAL
	item.equipment_profile = equipment
	item.weapon_profile = weapon
	item.consumable_profile = consumable

	assert_true(item.can_equip_in(ItemData.EquipSlot.MAIN_HAND))
	assert_true(item.can_equip_in(ItemData.EquipSlot.OFF_HAND))
	assert_eq(item.get_primary_equip_slot(), ItemData.EquipSlot.MAIN_HAND)
	assert_eq(item.get_equipment_stats().damage, 12.0)
	assert_eq(item.get_combat_mode(), ItemData.CombatMode.MELEE)
	assert_eq(item.get_visual_archetype(), ItemData.VisualArchetype.LANCER)
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
