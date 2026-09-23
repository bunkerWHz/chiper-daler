extends SceneTree

# Audit of authored ItemData resources. Read-only: it reports, it never edits.
#
# Run from the project root:
#   godot --headless --path . --script tests/item_audit.gd
#
# Prints one JSON object. Severities:
#   error   - a documented project rule is broken
#   pending - a known gap tracked in docs/Item_Plan.md (art, hand textures)
#   note    - a deliberate scheme that looks like an omission

const PLACEHOLDER := "icon_placeholder.png"
# Armor and accessories are not drawn on the hero, ammunition does not occupy a
# visual hand, so only these need world artwork.
const HELD_SLOTS := ["MAIN_HAND", "OFF_HAND"]
const NOT_DRAWN := ["AMMUNITION", "CONSUMABLE", "THROWABLE", "MATERIAL", "KEY", "LORE", "SCROLL"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var items: Array = []
	var findings: Array = []
	var ids: Dictionary = {}
	var folders := DirAccess.get_directories_at("res://game/items")
	folders.sort()

	for folder: String in folders:
		var files := DirAccess.get_files_at("res://game/items/" + folder)
		files.sort()
		for file: String in files:
			if not file.ends_with(".tres"):
				continue
			var path := "res://game/items/%s/%s" % [folder, file]
			var item := load(path) as ItemData
			if item == null:
				findings.append(_finding("error", folder, file, "not an ItemData resource"))
				continue
			var described := _describe(folder, file, item)
			items.append(described)
			_add_findings(findings, described)
			if folder != "templates":
				if ids.has(item.id):
					findings.append(_finding("error", folder, file, "duplicate id %s" % item.id))
				ids[item.id] = true

	print(JSON.stringify({
		"item_count": items.size(),
		"unique_ids": ids.size(),
		"items": items,
		"findings": findings,
	}))
	quit(0)


func _describe(folder: String, file: String, item: ItemData) -> Dictionary:
	var allowed := PackedStringArray()
	if item.equipment_profile != null:
		for slot: int in item.equipment_profile.allowed_slots:
			allowed.append(ItemData.EquipSlot.keys()[slot])

	var icon_state := "none"
	if item.icon != null:
		icon_state = "placeholder" if item.icon.resource_path.contains(PLACEHOLDER) else "own"

	var pending := PackedStringArray()
	var primary: String = ItemData.EquipSlot.keys()[item.get_primary_equip_slot()]
	var category_name: String = ItemData.Category.keys()[item.category]
	if folder != "templates":
		if icon_state == "none":
			pending.append("icon")
		if icon_state == "placeholder":
			pending.append("icon-pending")
		var is_held := HELD_SLOTS.has(primary) and not NOT_DRAWN.has(category_name)
		if is_held and item.equipped_texture == null and item.equipped_visual == null:
			pending.append("world-art")

	return {
		"folder": folder,
		"file": file,
		"id": String(item.id),
		"name": item.display_name,
		"category": ItemData.Category.keys()[item.category],
		"rarity": ItemData.Rarity.keys()[item.rarity],
		"weight": item.weight,
		"sell_price": item.sell_price,
		"stackable": item.stackable,
		"max_stack": item.max_stack_size,
		"valid": item.is_valid(),
		"is_flask": item.is_flask(),
		"description_length": item.description.length(),
		"icon_state": icon_state,
		"has_hand_visual": item.equipped_texture != null or item.equipped_visual != null,
		"has_equipment_profile": item.equipment_profile != null,
		"has_weapon_profile": item.weapon_profile != null,
		"has_offhand_profile": item.offhand_profile != null,
		"has_armor_profile": item.armor_profile != null,
		"has_consumable_profile": item.consumable_profile != null,
		"has_ammunition_profile": item.ammunition_profile != null,
		"has_projectile_profile": item.projectile_profile != null,
		"allowed_slots": allowed,
		"primary_slot": ItemData.EquipSlot.keys()[item.get_primary_equip_slot()],
		"combat_mode": ItemData.CombatMode.keys()[item.get_combat_mode()],
		"damage": item.get_equipment_stats().damage if item.get_equipment_stats() != null else 0.0,
		"defense": item.get_equipment_stats().defense if item.get_equipment_stats() != null else 0.0,
		"pending": pending,
	}


func _add_findings(findings: Array, item: Dictionary) -> void:
	var folder: String = item["folder"]
	var file: String = item["file"]

	if folder == "templates":
		if not item["id"].is_empty():
			findings.append(_finding("error", folder, file, "template carries an id: %s" % item["id"]))
		if item["icon_state"] != "placeholder":
			findings.append(_finding("note", folder, file, "template does not use the shared placeholder icon"))
		return

	if not item["valid"]:
		findings.append(_finding("error", folder, file, "ItemData.is_valid() is false"))

	if item["is_flask"]:
		if not is_zero_approx(item["weight"]):
			findings.append(_finding("error", folder, file, "flask weighs %s, expected 0" % item["weight"]))
	elif float(item["weight"]) <= 0.0:
		findings.append(_finding("error", folder, file, "no weight"))

	# Flasks are drunk and ammunition is spent by firing: neither is ever sold.
	if item["is_flask"] or item["has_ammunition_profile"]:
		if int(item["sell_price"]) != 0:
			findings.append(_finding("error", folder, file, "%s must not be sold, price is %s" % [item["category"], item["sell_price"]]))
	elif int(item["sell_price"]) <= 0:
		findings.append(_finding("error", folder, file, "no sell price"))

	match item["icon_state"]:
		"none":
			findings.append(_finding("pending", folder, file, "no icon, the UI shows the shared placeholder"))
		"placeholder":
			findings.append(_finding("note", folder, file, "reuses the shared placeholder icon"))
	if item["pending"].has("world-art"):
		findings.append(_finding("pending", folder, file, "no world artwork, hidden while equipped"))

	if int(item["description_length"]) == 0:
		findings.append(_finding("pending", folder, file, "empty description"))

	var category: String = item["category"]
	if category == "WEAPON":
		if not item["has_weapon_profile"]:
			findings.append(_finding("error", folder, file, "WEAPON without a weapon profile"))
		if not item["has_equipment_profile"]:
			findings.append(_finding("error", folder, file, "WEAPON without an equipment profile"))
	elif category == "ARMOR":
		if not item["has_equipment_profile"]:
			findings.append(_finding("error", folder, file, "ARMOR without an equipment profile"))
		elif not item["has_armor_profile"] and not item["has_offhand_profile"]:
			findings.append(_finding("error", folder, file, "ARMOR without an armor or offhand profile"))
		elif not item["has_armor_profile"]:
			findings.append(_finding("note", folder, file, "shield-style ARMOR: offhand profile without an armor profile"))
	elif category == "CONSUMABLE":
		if not item["has_consumable_profile"]:
			findings.append(_finding("error", folder, file, "CONSUMABLE without a consumable profile"))
	elif category == "AMMUNITION":
		if not item["has_ammunition_profile"]:
			findings.append(_finding("error", folder, file, "AMMUNITION without an ammunition profile"))
	elif category == "THROWABLE":
		if not item["has_projectile_profile"]:
			findings.append(_finding("error", folder, file, "THROWABLE without a projectile profile"))
	elif item["has_weapon_profile"]:
		findings.append(_finding("error", folder, file, "weapon profile on category %s" % category))

	if item["has_equipment_profile"] and (item["allowed_slots"] as PackedStringArray).is_empty():
		findings.append(_finding("error", folder, file, "equipment profile without allowed slots"))

	if item["stackable"] and int(item["max_stack"]) <= 1:
		findings.append(_finding("error", folder, file, "stackable with max stack %s" % item["max_stack"]))
	if not item["stackable"] and int(item["max_stack"]) != 1:
		findings.append(_finding("error", folder, file, "not stackable with max stack %s" % item["max_stack"]))

	if category == "WEAPON" and float(item["damage"]) <= 0.0:
		findings.append(_finding("error", folder, file, "weapon with zero damage"))
	if category == "ARMOR" and item["has_armor_profile"] and float(item["defense"]) <= 0.0:
		findings.append(_finding("error", folder, file, "armor with zero defense"))

	if not item["id"].is_valid_identifier():
		findings.append(_finding("error", folder, file, "id is not a lowercase identifier: %s" % item["id"]))


func _finding(severity: String, folder: String, file: String, message: String) -> Dictionary:
	return {"severity": severity, "folder": folder, "file": file, "message": message}
