extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func bag_quantity(menu: InventoryMenuComponent, id: StringName) -> int:
	var total := 0
	for stack: InventoryStack in menu._get_unequipped_stacks():
		if stack.item.id == id:
			total += stack.quantity
	return total

func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player := preload("res://game/player/Player.tscn").instantiate() as Actor
	world.add_child(player)
	var inventory := player.get_component(InventoryComponent) as InventoryComponent
	var equipment := player.get_component(EquipmentComponent) as EquipmentComponent
	var menu := player.get_component(InventoryMenuComponent) as InventoryMenuComponent
	var ranged := player.get_component(RangedWeaponComponent) as RangedWeaponComponent
	var codec := preload("res://features/save/PlayerSaveData.gd").new()
	for entry: Array in [["TrainingBow", "TrainingArrows", true], ["TrainingCrossbow", "TrainingBolts", false]]:
		var weapon := load("res://game/items/weapons/%s.tres" % entry[0]) as ItemData
		var ammo := load("res://game/items/ammunition/%s.tres" % entry[1]) as ItemData
		inventory.restore_runtime_state({"stacks": [{"item": weapon, "quantity": 2}, {"item": ammo, "quantity": 20}]})
		equipment.restore_runtime_state({"equipped_items": {}})
		check(equipment.equip_inventory_item(weapon.id, ItemData.EquipSlot.MAIN_HAND), "Equip ranged weapon")
		check(equipment.get_equipped_item_count(ammo.id) == 20, "Whole stack equipped")
		check(bag_quantity(menu, ammo.id) == 0, "Equipped ammunition absent from bag")
		check(is_equal_approx(equipment.get_total_equipped_weight(), weapon.weight + 20 * ammo.weight), "Whole stack contributes weight")
		menu.open_inventory()
		var found_count := false
		for button: Node in menu._equipment_slots.get_children():
			if button.drag_payload.get("item_id") == ammo.id:
				found_count = button.get_node("Quantity").text == "20" and button.get_node("Quantity").visible
		check(found_count, "Equipment cell shows ammunition count")
		menu.close_inventory()
		ranged._ammo_id = ammo.id
		ranged._fire(entry[2])
		check(inventory.get_quantity(ammo.id) == 19, "Shot spends exactly one equipped round")
		check(equipment.get_equipped_item_count(ammo.id) == 19, "Equipped remainder follows shooting")
		inventory.add_item(ammo, 5)
		check(equipment.get_equipped_item_count(ammo.id) == 24, "Picked up ammunition joins equipped stack")
		check(bag_quantity(menu, ammo.id) == 0, "No duplicate loose stack after pickup")
		var saved := codec.capture(player)
		codec.restore(player, saved)
		check(equipment.get_equipped_item_count(ammo.id) == 24, "Equipped stack survives restore")
		check(equipment.unequip_item(ItemData.EquipSlot.OFF_HAND), "Unequip ammunition")
		check(bag_quantity(menu, ammo.id) == 24, "All remaining rounds return to bag")
		saved = codec.capture(player)
		codec.restore(player, saved)
		check(not equipment.is_item_equipped(ammo.id), "Removed ammunition stays removed after loading")
		check(bag_quantity(menu, ammo.id) == 24, "Loading preserves unequipped stack")
		check(equipment.equip_inventory_item(ammo.id, ItemData.EquipSlot.OFF_HAND), "Reequip whole stack")
		inventory.add_item(weapon, 1)
		equipment.equip_inventory_item(weapon.id, ItemData.EquipSlot.MAIN_HAND, 0, 1)
		check(not equipment.equip_inventory_item(ammo.id, ItemData.EquipSlot.OFF_HAND, 0, 1), "Stack cannot occupy two sets at once")
		check(equipment.move_equipped_item(ItemData.EquipSlot.OFF_HAND, 0, 0, ItemData.EquipSlot.OFF_HAND, 0, 1), "Whole stack moves between sets")
		check(equipment.get_equipped_item_id(ItemData.EquipSlot.OFF_HAND, 0, 0).is_empty(), "Source slot cleared")
		check(equipment.get_equipped_item_count(ammo.id) == 24, "Moving stack never duplicates quantity")
		inventory.remove_item(ammo.id, 24)
		check(not equipment.is_item_equipped(ammo.id), "Exhausted stack clears equipment")
		check(bag_quantity(menu, ammo.id) == 0, "Exhausted stack leaves no phantom inventory item")
	world.queue_free()
	await process_frame
	print("Ammunition equipment checks: ", failures, " failures")
	quit(1 if failures else 0)
