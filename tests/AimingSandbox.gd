extends Node2D

@onready var player: Actor = $Player


func _ready() -> void:
	(player.get_component(DebugOverlayComponent) as DebugOverlayComponent).set_debug_visible(false)
	var inventory := player.get_component(InventoryComponent) as InventoryComponent
	var stone := preload("res://game/items/throwables/TrainingStone.tres") as ItemData
	inventory.add_item(stone, 20)
	var quick := player.get_component(QuickAccessComponent) as QuickAccessComponent
	quick.assign_item(1, stone.id)
	quick.activate_slot(1)
	_select_mode(EquipmentComponent.Slot.THROWABLE)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_F1: _select_mode(EquipmentComponent.Slot.THROWABLE)
		KEY_F2: _select_mode(EquipmentComponent.Slot.BOW)
		KEY_F3: _select_mode(EquipmentComponent.Slot.CROSSBOW)
		KEY_F4: _select_mode(EquipmentComponent.Slot.MAGIC)


func _select_mode(slot: EquipmentComponent.Slot) -> void:
	var equipment := player.get_component(EquipmentComponent) as EquipmentComponent
	var aim := player.get_component(AimingComponent) as AimingComponent
	aim.cancel_aim()
	var weapon_id: StringName = &""
	match slot:
		EquipmentComponent.Slot.BOW: weapon_id = &"training_bow"
		EquipmentComponent.Slot.CROSSBOW: weapon_id = &"training_crossbow"
		EquipmentComponent.Slot.MAGIC: weapon_id = &"training_staff"
	var inventory := player.get_component(InventoryComponent) as InventoryComponent
	for path: String in ["throwables/TrainingStone", "ammunition/TrainingArrows", "ammunition/TrainingBolts"]:
		var item := load("res://game/items/" + path + ".tres") as ItemData
		inventory.add_item(item, maxi(20 - inventory.get_quantity(item.id), 0))
	if not weapon_id.is_empty():
		# The starting weapon sets already hold the bow, the crossbow and the
		# staff, so switch to the set that owns the requested weapon instead of
		# equipping a second copy.
		var owner_set := _weapon_set_with(equipment, weapon_id)
		if owner_set >= 0:
			equipment.switch_weapon_set(owner_set)
		else:
			equipment.unequip_item(ItemData.EquipSlot.OFF_HAND)
			equipment.equip_inventory_item(weapon_id, ItemData.EquipSlot.MAIN_HAND)
	elif slot == EquipmentComponent.Slot.THROWABLE:
		(player.get_component(QuickAccessComponent) as QuickAccessComponent).activate_slot(1)
	equipment.equip(slot)
	var magic := player.get_component(MagicComponent) as MagicComponent
	magic.restore_mana(magic.get_max_mana())
	$CanvasLayer/Help.text = ("F1 Throw (R) | F2 Bow (J) | F3 Crossbow (J) | F4 Magic (J)\n"
		+ "Hold: mouse up/down or W/S | Turn: A/D | Release: fire | K: cancel\n"
		+ "Gamepad: Y throw, X shoot, B cancel, left stick aim/turn, LB/RB quick slots\n"
		+ "Mode: " + EquipmentComponent.Slot.keys()[slot] + " | F1-F4 refill prototype resources")


func _weapon_set_with(equipment: EquipmentComponent, weapon_id: StringName) -> int:
	for set_index in EquipmentComponent.WEAPON_SET_COUNT:
		if equipment.get_equipped_item_id(ItemData.EquipSlot.MAIN_HAND, 0, set_index) == weapon_id:
			return set_index
	return -1
