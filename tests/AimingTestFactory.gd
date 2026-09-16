extends RefCounted


static func create() -> Dictionary:
	var root := Node2D.new()
	var actor := Actor.new()
	root.add_child(actor)
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var input := InputComponent.new()
	var facing := FacingComponent.new()
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var equipment := EquipmentComponent.new()
	var quick := QuickAccessComponent.new()
	quick.config = QuickAccessConfig.new()
	var aim := AimingComponent.new()
	aim.config = AimingConfig.new()
	var throwing := ThrowingComponent.new()
	throwing.config = ThrowingConfig.new()
	var ranged := RangedWeaponComponent.new()
	ranged.config = RangedWeaponConfig.new()
	var magic := MagicComponent.new()
	magic.config = MagicConfig.new()
	var state := ActorStateComponent.new()
	for component: Component in [input, facing, inventory, equipment, quick, aim, throwing, ranged, magic, state]:
		components.add_child(component)
	actor._collect_components()
	for path: String in ["weapons/TrainingBow", "weapons/TrainingCrossbow", "weapons/TrainingStaff", "consumables/HealthPotion"]:
		inventory.add_item(load("res://game/items/" + path + ".tres") as ItemData)
	inventory.add_item(load("res://game/items/ammunition/TrainingArrows.tres") as ItemData, 20)
	inventory.add_item(load("res://game/items/ammunition/TrainingBolts.tres") as ItemData, 12)
	inventory.add_item(load("res://game/items/throwables/TrainingStone.tres") as ItemData, 5)
	quick.assign_item(1, &"training_stone")
	quick.activate_slot(1)
	var setup := {"root": root, "actor": actor, "input": input, "facing": facing,
		"inventory": inventory, "equipment": equipment, "quick": quick,
		"aim": aim, "throwing": throwing, "ranged": ranged, "magic": magic, "actor_state": state}
	select_weapon(setup, EquipmentComponent.Slot.BOW)
	return setup


static func select_weapon(setup: Dictionary, slot: int) -> void:
	var equipment := setup.equipment as EquipmentComponent
	var weapon_id: StringName = &""
	match slot:
		EquipmentComponent.Slot.BOW: weapon_id = &"training_bow"
		EquipmentComponent.Slot.CROSSBOW: weapon_id = &"training_crossbow"
		EquipmentComponent.Slot.MAGIC: weapon_id = &"training_staff"
	if not weapon_id.is_empty():
		equipment.unequip_item(ItemData.EquipSlot.OFF_HAND)
		equipment.equip_inventory_item(weapon_id, ItemData.EquipSlot.MAIN_HAND)
		if slot == EquipmentComponent.Slot.BOW:
			equipment.equip_inventory_item(&"training_arrows", ItemData.EquipSlot.OFF_HAND)
		elif slot == EquipmentComponent.Slot.CROSSBOW:
			equipment.equip_inventory_item(&"training_bolts", ItemData.EquipSlot.OFF_HAND)
	else:
		setup.quick.activate_slot(1)
