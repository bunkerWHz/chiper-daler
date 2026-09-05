@tool
extends McpTestSuite


func suite_name() -> String:
	return "item_authoring"


func test_templates_have_presentation_and_require_a_unique_id() -> void:
	for filename: String in DirAccess.get_files_at("res://game/items/templates"):
		if filename.get_extension() != "tres":
			continue
		var template := load("res://game/items/templates/" + filename) as ItemData
		assert_true(template != null)
		assert_true(template.icon != null)
		assert_false(template.display_name.is_empty())
		assert_false(template.is_valid())
		var item := template.duplicate(true) as ItemData
		item.id = &"new_test_item"
		item.display_name = "New test item"
		assert_true(item.is_valid())
		assert_true(template.id.is_empty())
		assert_ne(item.display_name, template.display_name)


func test_weapon_and_armor_templates_supply_independent_equipment_profiles() -> void:
	var weapon := load("res://game/items/templates/Weapon.tres") as ItemData
	var copy := weapon.duplicate(true) as ItemData
	copy.equipment_profile.stats.damage = 42.0
	assert_ne(copy.get_equipment_stats().damage, weapon.get_equipment_stats().damage)
	assert_true(copy.can_equip_in(ItemData.EquipSlot.MAIN_HAND))
	assert_true(copy.has_weapon_action(ItemWeaponProfile.Action.LIGHT_ATTACK))
	var armor := load("res://game/items/templates/Armor.tres") as ItemData
	assert_true(armor.can_equip_in(ItemData.EquipSlot.CHEST))
	assert_true(armor.armor_profile != null)
	assert_true(armor.get_equipment_stats().defense > 0.0)


func test_catalog_items_remain_valid_with_unique_ids() -> void:
	var ids: Dictionary = {}
	for folder: String in DirAccess.get_directories_at("res://game/items"):
		if folder == "templates":
			continue
		for filename: String in DirAccess.get_files_at("res://game/items/" + folder):
			if filename.get_extension() != "tres":
				continue
			var item := load("res://game/items/%s/%s" % [folder, filename]) as ItemData
			assert_true(item != null and item.is_valid())
			assert_false(ids.has(item.id), "Duplicate item ID: %s" % item.id)
			ids[item.id] = true
	assert_false(ids.is_empty())
