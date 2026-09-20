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


func test_ranged_defaults_and_template_copies() -> void:
	for crossbow: bool in [false, true]:
		var profile := ItemWeaponProfile.new()
		profile.combat_mode = ItemData.CombatMode.CROSSBOW if crossbow else ItemData.CombatMode.BOW
		assert_eq(profile.ranged.projectile_speed, 820.0 if crossbow else 600.0)
		assert_eq(profile.ranged.projectile_gravity, 50.0 if crossbow else 350.0)
		assert_eq(profile.ranged.projectile_damage, 24.0 if crossbow else 18.0)
		var path := "res://game/items/templates/%s.tres" % ("Crossbow" if crossbow else "Bow")
		var template := load(path) as ItemData
		var copy := template.duplicate(true) as ItemData
		copy.weapon_profile.ranged.projectile_speed = 999.0
		assert_eq(template.weapon_profile.ranged.projectile_speed, 820.0 if crossbow else 600.0)
		profile.ranged.projectile_speed = 777.0
		profile.combat_mode = profile.combat_mode
		assert_eq(profile.ranged.projectile_speed, 777.0)


func test_ranged_settings_survive_resource_save() -> void:
	var item := (load("res://game/items/templates/Crossbow.tres") as ItemData).duplicate(true) as ItemData
	item.id = &"saved_crossbow"
	item.weapon_profile.ranged.projectile_speed = 913.0
	item.weapon_profile.ranged.projectile_gravity = 72.0
	var path := "res://.godot/test_ranged_item.tres"
	assert_eq(ResourceSaver.save(item, path), OK)
	var restored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemData
	assert_eq(restored.weapon_profile.ranged.projectile_speed, 913.0)
	assert_eq(restored.weapon_profile.ranged.projectile_gravity, 72.0)
	assert_eq(restored.weapon_profile.ranged.projectile_damage, 24.0)
	DirAccess.remove_absolute(path)


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


func test_new_items_start_with_weight_and_sell_price() -> void:
	var item := ItemData.new()
	assert_eq(item.weight, 1.0, "A new item must start with weight 1")
	assert_eq(item.sell_price, 1, "A new item must start with sell price 1")
	var template := load("res://game/items/templates/Weapon.tres") as ItemData
	var copy := template.duplicate(true) as ItemData
	assert_eq(copy.weight, 1.0, "A template copy must inherit the starting weight")
	assert_eq(copy.sell_price, 1, "A template copy must inherit the starting sell price")


func test_catalog_items_have_weight_and_price_except_flasks() -> void:
	var flasks := 0
	for folder: String in DirAccess.get_directories_at("res://game/items"):
		if folder == "templates":
			continue
		for filename: String in DirAccess.get_files_at("res://game/items/" + folder):
			if filename.get_extension() != "tres":
				continue
			var item := load("res://game/items/%s/%s" % [folder, filename]) as ItemData
			if item == null:
				continue
			if item.is_flask():
				flasks += 1
				assert_true(is_zero_approx(item.weight), "Flask must weigh nothing: %s" % item.id)
				assert_eq(item.sell_price, 0, "Flask must not be sold: %s" % item.id)
				continue
			assert_true(item.weight > 0.0, "Item without weight: %s" % item.id)
			assert_true(item.sell_price > 0, "Item without sell price: %s" % item.id)
	assert_true(flasks > 0, "Expected at least one flask in the catalog")


func test_display_slot_defaults_to_inventory_slot_and_serializes_independently() -> void:
	var item := ItemData.new()
	item.id = &"saved_visual_slot"
	item.equipment_profile = ItemEquipmentProfile.new()
	item.equipment_profile.allowed_slots = [ItemData.EquipSlot.MAIN_HAND]
	assert_eq(item.get_display_slot(ItemData.EquipSlot.MAIN_HAND), ItemData.EquipSlot.MAIN_HAND)
	assert_eq(item.get_display_slot(ItemData.EquipSlot.OFF_HAND), ItemData.EquipSlot.OFF_HAND)
	item.equipment_profile.display_slot = ItemEquipmentProfile.DisplaySlot.OFF_HAND
	item.equipped_texture = load("res://assets/Characters/Darklight/equipment/Bow.png") as Texture2D
	var path := "res://.godot/test_display_slot.tres"
	assert_eq(ResourceSaver.save(item, path), OK)
	var restored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemData
	assert_true(restored.can_equip_in(ItemData.EquipSlot.MAIN_HAND))
	assert_false(restored.can_equip_in(ItemData.EquipSlot.OFF_HAND))
	assert_eq(restored.get_display_slot(ItemData.EquipSlot.MAIN_HAND), ItemData.EquipSlot.OFF_HAND)
	assert_eq(restored.equipped_texture, item.equipped_texture)
	DirAccess.remove_absolute(path)
	for weapon: String in ["Bow", "Crossbow"]:
		for folder: String in ["weapons/Training", "templates/"]:
			var configured := load("res://game/items/" + folder + weapon + ".tres") as ItemData
			assert_eq(configured.get_primary_equip_slot(), ItemData.EquipSlot.MAIN_HAND)
			assert_eq(configured.get_display_slot(ItemData.EquipSlot.MAIN_HAND), ItemData.EquipSlot.OFF_HAND)
