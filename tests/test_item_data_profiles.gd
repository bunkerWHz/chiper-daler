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


func test_one_handed_training_weapons_have_distinct_profiles() -> void:
	var rapier := load(
		"res://features/inventory/items/TrainingRapier.tres"
	) as ItemData
	var katana := load(
		"res://features/inventory/items/TrainingKatana.tres"
	) as ItemData
	var dagger := load(
		"res://features/inventory/items/TrainingDagger.tres"
	) as ItemData

	assert_eq(rapier.weapon_profile.family, ItemWeaponProfile.Family.RAPIER)
	assert_eq(rapier.weapon_profile.primary_damage_type, ItemWeaponProfile.DamageType.PIERCE)
	assert_true(rapier.has_weapon_action(ItemWeaponProfile.Action.PARRY))
	assert_false(rapier.has_weapon_action(ItemWeaponProfile.Action.GUARD))
	assert_eq(katana.weapon_profile.family, ItemWeaponProfile.Family.KATANA)
	assert_true(katana.has_weapon_action(ItemWeaponProfile.Action.GUARD))
	assert_eq(dagger.weapon_profile.family, ItemWeaponProfile.Family.DAGGER)
	assert_eq(dagger.weapon_profile.attack_speed_multiplier, 1.4)
	assert_eq(dagger.weapon_profile.reach_multiplier, 0.7)
	assert_eq(dagger.weapon_profile.critical_damage_multiplier, 3.0)
	assert_true(dagger.weapon_profile.dexterity_scaling > rapier.weapon_profile.dexterity_scaling)


func test_strength_weapon_batch_is_two_handed_and_distinct() -> void:
	var axe := load(
		"res://features/inventory/items/TrainingBattleAxe.tres"
	) as ItemData
	var hammer := load(
		"res://features/inventory/items/TrainingWarHammer.tres"
	) as ItemData
	var greatsword := load(
		"res://features/inventory/items/TrainingGreatsword.tres"
	) as ItemData

	assert_true(axe.is_two_handed_weapon())
	assert_true(hammer.is_two_handed_weapon())
	assert_true(greatsword.is_two_handed_weapon())
	assert_eq(axe.weapon_profile.family, ItemWeaponProfile.Family.AXE)
	assert_eq(axe.weapon_profile.primary_damage_type, ItemWeaponProfile.DamageType.SLASH)
	assert_eq(hammer.weapon_profile.family, ItemWeaponProfile.Family.MACE)
	assert_eq(hammer.weapon_profile.primary_damage_type, ItemWeaponProfile.DamageType.STRIKE)
	assert_eq(greatsword.weapon_profile.family, ItemWeaponProfile.Family.GREAT_SWORD)
	assert_true(greatsword.weapon_profile.reach_multiplier > hammer.weapon_profile.reach_multiplier)
	assert_true(hammer.weapon_profile.stagger_power > axe.weapon_profile.stagger_power)


func test_specialized_two_handed_weapon_batch_has_expected_roles() -> void:
	var great_hammer := load(
		"res://features/inventory/items/TrainingGreatHammer.tres"
	) as ItemData
	var staff := load(
		"res://features/inventory/items/TrainingStaff.tres"
	) as ItemData
	var halberd := load(
		"res://features/inventory/items/TrainingHalberd.tres"
	) as ItemData
	var scythe := load(
		"res://features/inventory/items/TrainingScythe.tres"
	) as ItemData

	for item: ItemData in [great_hammer, staff, halberd, scythe]:
		assert_true(item.is_two_handed_weapon())
	assert_eq(great_hammer.weapon_profile.family, ItemWeaponProfile.Family.GREAT_HAMMER)
	assert_eq(great_hammer.weapon_profile.stagger_power, 3.0)
	assert_eq(staff.weapon_profile.family, ItemWeaponProfile.Family.STAFF)
	assert_true(staff.has_weapon_action(ItemWeaponProfile.Action.CAST))
	assert_true(staff.has_weapon_action(ItemWeaponProfile.Action.CHANNEL))
	assert_false(staff.has_weapon_action(ItemWeaponProfile.Action.LIGHT_ATTACK))
	assert_eq(halberd.weapon_profile.family, ItemWeaponProfile.Family.POLEARM)
	assert_eq(halberd.weapon_profile.reach_multiplier, 1.6)
	assert_eq(scythe.weapon_profile.family, ItemWeaponProfile.Family.SCYTHE)
	assert_eq(scythe.weapon_profile.critical_damage_multiplier, 2.5)


func test_offhand_batch_has_distinct_defensive_roles() -> void:
	var buckler := load("res://features/inventory/items/TrainingBuckler.tres") as ItemData
	var greatshield := load("res://features/inventory/items/TrainingGreatshield.tres") as ItemData
	var dagger := load("res://features/inventory/items/TrainingParryingDagger.tres") as ItemData
	assert_eq(buckler.offhand_profile.family, ItemOffhandProfile.Family.BUCKLER)
	assert_true(buckler.has_offhand_action(ItemOffhandProfile.Action.PARRY))
	assert_eq(buckler.offhand_profile.parry_window_multiplier, 1.35)
	assert_eq(greatshield.offhand_profile.family, ItemOffhandProfile.Family.GREATSHIELD)
	assert_true(greatshield.has_offhand_action(ItemOffhandProfile.Action.GUARD))
	assert_false(greatshield.has_offhand_action(ItemOffhandProfile.Action.PARRY))
	assert_eq(greatshield.offhand_profile.block_damage_reduction, 0.75)
	assert_eq(dagger.offhand_profile.family, ItemOffhandProfile.Family.PARRYING_DAGGER)
	assert_eq(dagger.offhand_profile.parry_window_multiplier, 1.5)


func test_armor_classes_have_distinct_weight_defense_and_poise() -> void:
	var light := load("res://features/inventory/items/ScoutLeatherArmor.tres") as ItemData
	var heavy := load("res://features/inventory/items/KnightPlateArmor.tres") as ItemData
	var robe := load("res://features/inventory/items/ScholarRobe.tres") as ItemData
	assert_eq(light.armor_profile.armor_class, ItemArmorProfile.ArmorClass.LIGHT)
	assert_eq(heavy.armor_profile.armor_class, ItemArmorProfile.ArmorClass.HEAVY)
	assert_eq(robe.armor_profile.armor_class, ItemArmorProfile.ArmorClass.ROBE)
	assert_true(heavy.weight > light.weight)
	assert_true(heavy.get_equipment_stats().defense > light.get_equipment_stats().defense)
	assert_true(heavy.armor_profile.poise > light.armor_profile.poise)
	assert_true(light.weight > robe.weight)
	assert_eq(robe.get_equipment_stats().intelligence_requirement, 5)
