extends PanelContainer
class_name ItemDetailsView

var weapon_set: int = -1
var _inventory: InventoryComponent
var _equipment: EquipmentComponent
var _flask_charges: FlaskChargesComponent


func configure(inventory: InventoryComponent, equipment: EquipmentComponent, flasks: FlaskChargesComponent) -> void:
	_inventory = inventory
	_equipment = equipment
	_flask_charges = flasks


func set_text(value: String) -> void:
	get_node("Margin/Details").text = value


func get_text() -> String:
	return get_node("Margin/Details").text


func get_item_text(item: ItemData) -> String:
	var detail_lines := PackedStringArray()
	detail_lines.append("%s [%s]" % [
		item.display_name,
		ItemData.Category.keys()[item.category].capitalize(),
	])
	detail_lines.append(item.description)
	var upgrade := _inventory.get_weapon_upgrade(item.id)
	if upgrade > 0:
		detail_lines.append("Amber upgrade: +%d (+%d%% weapon damage)" % [upgrade, upgrade * 10])
	var owned_quantity := _inventory.get_quantity(item.id)
	var equipped_quantity := _equipment.get_equipped_item_count(item.id)
	if item.is_flask():
		var current_charges := (
			_flask_charges.get_charges(item.id)
			if _flask_charges != null
			else 0
		)
		detail_lines.append("Charges: %d / %d" % [
			current_charges,
			item.get_flask_max_charges(),
		])
	elif equipped_quantity > 0:
		detail_lines.append("Bag: %d  Equipped: %d" % [
			maxi(owned_quantity - equipped_quantity, 0),
			equipped_quantity,
		])
	else:
		detail_lines.append("Qty: %d" % owned_quantity)
	detail_lines.append("Weight: %.2f  Sell: %d" % [
		item.weight,
		item.sell_price,
	])
	_append_weapon_profile(detail_lines, item.weapon_profile)
	_append_offhand_profile(detail_lines, item.offhand_profile)
	_append_armor_profile(detail_lines, item.armor_profile)
	if item.ammunition_profile != null:
		detail_lines.append(
			"Ammunition: %s" % _enum_label(item.get_ammunition_type())
		)
	_append_item_stats(detail_lines, item)
	return "\n".join(detail_lines)


func _append_item_stats(lines: PackedStringArray, item: ItemData) -> void:
	var item_stats := item.get_equipment_stats()
	if item_stats == null:
		return
	lines.append("Damage: %.1f  Defense: %.1f" % [
		item_stats.damage * (1.0 + 0.1 * _inventory.get_weapon_upgrade(item.id)),
		item_stats.defense,
	])
	var equip_slot := item.get_primary_equip_slot()
	if equip_slot == ItemData.EquipSlot.NONE:
		return
	var equipped := _equipment.get_equipped_item(equip_slot, 0, weapon_set)
	var equipped_stats := (
		equipped.get_equipment_stats() if equipped != null else null
	)
	if equipped == null or equipped.id == item.id or equipped_stats == null:
		return
	lines.append("Compared with %s: Damage %+.1f / Defense %+.1f" % [
		equipped.display_name,
		item_stats.damage * (1.0 + 0.1 * _inventory.get_weapon_upgrade(item.id)) - equipped_stats.damage * (1.0 + 0.1 * _inventory.get_weapon_upgrade(equipped.id)),
		item_stats.defense - equipped_stats.defense,
	])


func _append_weapon_profile(
	lines: PackedStringArray,
	profile: ItemWeaponProfile
) -> void:
	if profile == null:
		return
	lines.append("Weapon: %s  %s" % [
		_enum_label(ItemWeaponProfile.Family.keys()[profile.family]),
		_enum_label(ItemWeaponProfile.Handedness.keys()[profile.handedness]),
	])
	var actions := PackedStringArray()
	for entry: Dictionary in [
		{"flag": ItemWeaponProfile.Action.LIGHT_ATTACK, "label": "Light"},
		{"flag": ItemWeaponProfile.Action.HEAVY_ATTACK, "label": "Heavy"},
		{"flag": ItemWeaponProfile.Action.GUARD, "label": "Guard"},
		{"flag": ItemWeaponProfile.Action.PARRY, "label": "Parry"},
		{"flag": ItemWeaponProfile.Action.AIM, "label": "Aim"},
		{"flag": ItemWeaponProfile.Action.FIRE, "label": "Fire"},
		{"flag": ItemWeaponProfile.Action.CAST, "label": "Cast"},
		{"flag": ItemWeaponProfile.Action.CHANNEL, "label": "Channel"},
	]:
		if profile.has_action(int(entry.flag) as ItemWeaponProfile.Action):
			actions.append(String(entry.label))
	if not actions.is_empty():
		lines.append("Actions: %s" % ", ".join(actions))
	if profile.combat_mode == ItemData.CombatMode.MELEE:
		lines.append("Critical x%.2f" % profile.critical_damage_multiplier)
		lines.append("Reach x%.2f" % clampf(profile.reach_multiplier, 0.1, 5.0))
	if not profile.ammunition_type.is_empty():
		lines.append("Ammunition: %s" % _enum_label(profile.ammunition_type))


func _append_offhand_profile(
	lines: PackedStringArray,
	profile: ItemOffhandProfile
) -> void:
	if profile == null:
		return
	lines.append("Offhand: %s" % _enum_label(
		ItemOffhandProfile.Family.keys()[profile.family]
	))
	var actions := PackedStringArray()
	for entry: Dictionary in [
		{"flag": ItemOffhandProfile.Action.GUARD, "label": "Guard"},
		{"flag": ItemOffhandProfile.Action.PARRY, "label": "Parry"},
	]:
		if profile.has_action(int(entry.flag) as ItemOffhandProfile.Action):
			actions.append(String(entry.label))
	if not actions.is_empty():
		lines.append("Actions: %s" % ", ".join(actions))
	lines.append("Block %.0f%%  Parry x%.2f" % [
		profile.block_damage_reduction * 100.0,
		profile.parry_window_multiplier,
	])


func _append_armor_profile(
	lines: PackedStringArray,
	profile: ItemArmorProfile
) -> void:
	if profile == null:
		return
	lines.append("Armor: %s" % _enum_label(ItemArmorProfile.ArmorClass.keys()[profile.armor_class]))
	if not profile.set_id.is_empty():
		lines.append("Set: %s" % _enum_label(profile.set_id))


func _enum_label(value: Variant) -> String:
	return String(value).replace("_", " ").capitalize()
