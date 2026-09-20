extends SceneTree

const Data := preload("res://game/menu/CharacterCreationData.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var flow := root.get_node("GameFlow")
	var draft := Data.new()
	check(draft.remaining_points() == 5, "Five points available after minimums")
	check(not draft.change_attribute("strength", -1), "Cannot reduce below one")
	check(flow.start_created_game(draft) == ERR_INVALID_PARAMETER, "Invalid draft cannot start")
	draft.character_name = "  Испытатель  "
	for index in 5:
		check(draft.change_attribute("strength", 1), "Allocate free point")
	check(not draft.change_attribute("strength", 1), "Cannot spend an eleventh point")
	check(draft.change_attribute("strength", -1), "Refund point")
	check(draft.change_attribute("wisdom", 1), "Reallocate point")
	for weapon in Data.WEAPONS.size():
		for armor in range(Data.TOPS.size() * Data.BOTTOMS.size()):
			draft.weapon_index = weapon
			draft.top_index = armor / Data.BOTTOMS.size()
			draft.bottom_index = armor % Data.BOTTOMS.size()
			check(flow.saves.store.codec.validate(draft.player_state()), "Every gear combination serializes")
	draft.weapon_index = 4
	draft.top_index = 2
	draft.bottom_index = 0
	check(change_scene_to_file(flow.CHARACTER_CREATION) == OK, "Creation scene opens")
	await process_frame
	await process_frame
	check(current_scene._start_button.disabled, "Incomplete form blocks start")
	# Empty-name validation and the longest equipment warning used to clip the footer.
	var armor_picker := current_scene.find_child("TopPicker", true, false) as OptionButton
	armor_picker.select(1)
	armor_picker.item_selected.emit(1)
	await process_frame
	await process_frame
	var action_bar: Control = current_scene._start_button.get_parent()
	check(root.get_visible_rect().encloses(action_bar.get_global_rect()), "Actions fit with validation and overload warning")
	var ancestor: Node = action_bar.get_parent()
	while ancestor != null:
		check(not ancestor is ScrollContainer, "Footer stays outside clipped scrolling content")
		ancestor = ancestor.get_parent()
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("character-creation-footer.png"))
	var name_input := current_scene.find_child("CharacterName", true, false) as LineEdit
	name_input.text = draft.character_name
	name_input.text_changed.emit(name_input.text)
	for index in 4:
		current_scene._plus["strength"].pressed.emit()
	current_scene._plus["wisdom"].pressed.emit()
	for entry: Array in [["WeaponPicker", 4], ["TopPicker", 2], ["BottomPicker", 0]]:
		var picker := current_scene.find_child(entry[0], true, false) as OptionButton
		picker.select(entry[1])
		picker.item_selected.emit(entry[1])
	check(current_scene.draft.player_state() == draft.player_state(), "Form inputs produce expected draft")
	check(not current_scene._start_button.disabled, "Valid form enables start")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("character-creation.png"))
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	flow._unhandled_input(escape)
	check(not paused, "Creation never opens gameplay pause")
	check(flow.start_created_game(draft) == OK, "Created game starts")
	await process_frame
	await physics_frame
	await process_frame
	var player: Actor = flow.saves._player
	check(is_instance_valid(player), "Gameplay player found")
	var state: Dictionary = flow.saves.store.codec.capture(player)
	check(state.identity.name == "Испытатель", "Name trimmed and applied")
	check(state.attributes.strength == 5 and state.attributes.wisdom == 2, "Allocated stats applied")
	var inventory := player.get_component(InventoryComponent) as InventoryComponent
	check(inventory.has_item(&"training_arrows", 20), "Bow includes arrows")
	check(not inventory.has_item(&"training_sword"), "Sandbox arsenal removed")
	var equipment := player.get_component(EquipmentComponent) as EquipmentComponent
	check(equipment.get_equipped_item_id(ItemData.EquipSlot.MAIN_HAND) == &"training_bow", "Selected weapon equipped")
	check(equipment.get_equipped_item_id(ItemData.EquipSlot.CHEST) == &"scholar_robe", "Selected armor equipped")
	check(equipment.get_equipped_item_id(ItemData.EquipSlot.LEGS) == &"scout_leather_pants", "Bottom selected independently of top")
	var inventory_menu := player.get_component(InventoryMenuComponent) as InventoryMenuComponent
	inventory_menu.open_inventory()
	check("Испытатель" in inventory_menu.get_node("CanvasLayer/Panel/Main/Header/Title").text, "Chosen name shown in inventory")
	inventory_menu.close_inventory()
	for weapon in Data.WEAPONS.size():
		for armor in range(Data.TOPS.size() * Data.BOTTOMS.size()):
			draft.weapon_index = weapon
			draft.top_index = armor / Data.BOTTOMS.size()
			draft.bottom_index = armor % Data.BOTTOMS.size()
			flow.saves.store.codec.restore(player, draft.player_state())
			for item: ItemData in draft.selected_items():
				check(equipment.is_item_equipped(item.id), "Every selected starting item equips")
			var armor_count := 0
			for stack: InventoryStack in inventory.get_stacks():
				if stack.item.category == ItemData.Category.ARMOR:
					armor_count += stack.quantity
			check(armor_count == 2, "Starting armor contains exactly top and bottom")
			for slot: ItemData.EquipSlot in [ItemData.EquipSlot.HEAD, ItemData.EquipSlot.SHOULDER, ItemData.EquipSlot.HANDS, ItemData.EquipSlot.BELT, ItemData.EquipSlot.FEET]:
				check(equipment.get_equipped_item(slot) == null, "Other armor slots stay empty")
	flow.saves.store.codec.restore(player, state)
	check(flow.save_checkpoint() == OK, "Created hero saves")
	check(flow.read_save().player.identity.name == "Испытатель", "Name survives disk round trip")
	check(flow.return_to_menu() == OK, "Return to menu")
	await process_frame
	await process_frame
	# Merely opening/cancelling creation must not replace the save.
	current_scene._create_character()
	await process_frame
	await process_frame
	current_scene._back()
	await process_frame
	await process_frame
	check(flow.read_save().player.identity.name == "Испытатель", "Cancel preserves existing hero")
	check(flow.start_game(true) == OK, "Continue created hero")
	await process_frame
	await physics_frame
	await process_frame
	check(flow.saves._player.character_name == "Испытатель", "Loaded hero has chosen name")
	check(flow.saves.store.codec.capture(flow.saves._player).attributes == state.attributes, "Loaded attributes preserved")
	var legacy := state.duplicate(true)
	legacy.erase("identity")
	check(flow.saves.store.codec.validate(legacy), "Older saves remain supported")
	flow.saves.store.codec.restore(flow.saves._player, legacy)
	check(flow.saves._player.character_name == "Darklight", "Older saves use default name")
	print("Character creation checks: ", failures, " failures")
	flow.saves.active = false
	quit(1 if failures else 0)
