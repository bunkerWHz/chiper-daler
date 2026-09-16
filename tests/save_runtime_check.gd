extends SceneTree

# Use an isolated APPDATA/LOCALAPPDATA, as described in docs/Testing.md.
var failures := 0
var checks := 0
var flow: Node

class FailingStore:
	extends "res://features/save/SaveStore.gd"

	func write_save(_path: String, _snapshot: Dictionary) -> Error:
		return ERR_FILE_CANT_WRITE


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func player() -> Actor:
	return current_scene.get_node("Player") as Actor


func _run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.godot/"):
		push_error("Save test requires an isolated profile inside .godot")
		quit(1)
		return
	flow = root.get_node("GameFlow")
	check(flow.start_game(false) == OK, "New game starts")
	await settle()
	paused = true
	check(not flow.read_save().is_empty(), "New game creates a full save")
	var inventory := player().get_component(InventoryComponent) as InventoryComponent
	var attributes := player().get_component(CharacterAttributesComponent) as CharacterAttributesComponent
	var progression := player().get_component(ProgressionComponent) as ProgressionComponent
	var equipment := player().get_component(EquipmentComponent) as EquipmentComponent
	var quick := player().get_component(QuickAccessComponent) as QuickAccessComponent
	var flask := player().get_component(FlaskChargesComponent) as FlaskChargesComponent
	var rest := current_scene.get_node("RestPoint") as RestPoint
	var chest := current_scene.get_node("TestChest")
	inventory.add_amber(1000)
	attributes.set_endurance(17)
	attributes.set_wisdom(13)
	progression.gain_experience(175)
	var item: ItemData = load("res://game/items/weapons/TrainingSword.tres")
	if not inventory.has_item(item.id):
		inventory.add_item(item)
	check(inventory.upgrade_weapon(item.id), "Weapon upgrade applied")
	var armor: ItemData = load("res://game/items/armor/ScholarHood.tres")
	if not inventory.has_item(armor.id):
		inventory.add_item(armor)
	check(equipment.equip_inventory_item(armor.id, ItemData.EquipSlot.HEAD), "Equip nondefault armor")
	check(equipment.switch_weapon_set(1), "Select second weapon set")
	for index: int in range(1, quick.config.slot_count):
		quick.clear_slot(index)
	check(quick.assign_item(3, &"mana_potion"), "Assign custom quick slot")
	check(quick.activate_slot(3), "Select custom quick slot")
	inventory.remove_item(&"training_arrows", maxi(inventory.get_quantity(&"training_arrows") - 3, 0))
	inventory.remove_item(&"training_bolts", maxi(inventory.get_quantity(&"training_bolts") - 2, 0))
	inventory.remove_item(&"training_stone", maxi(inventory.get_quantity(&"training_stone") - 1, 0))
	var stackable: ItemData
	for candidate: ItemData in flow.saves.store.codec.items.values():
		if candidate.stackable and not candidate.is_flask() and candidate.get_effective_stack_size() >= 8:
			stackable = candidate
			break
	check(stackable != null, "Catalog contains a stackable item")
	if stackable != null:
		inventory.add_item(stackable, 8)
		check(inventory.split_stack(stackable.id, 3), "Split a stack before saving")
	chest._on_interacted()
	var enemy := current_scene.get_node("Enemy") as Actor
	var enemy_id := enemy.get_instance_id()
	(enemy.get_component(HealthComponent) as HealthComponent).take_damage(1.0)
	rest._on_interacted_by(player())
	check(current_scene.get_node("Enemy").get_instance_id() != enemy_id, "Rest respawns ordinary enemies")
	check(flow.saves.rest_id == "shelter_start", "Rest stores stable ID")
	var expected: Dictionary = flow.saves.store.codec.capture(player())
	var expected_position := rest.global_position + rest.spawn_offset
	# Transient resources do not belong to the disk snapshot.
	(player().get_component(HealthComponent) as HealthComponent).take_damage(10)
	for stack: InventoryStack in inventory.get_stacks():
		if stack.item.is_flask():
			flask.spend_charge(stack.item.id)
	await settle()
	var saved: Dictionary = flow.read_save()
	check(saved.player == expected, "Autosave contains all persistent components and split stacks")
	check(saved.world.values().has(true), "World changes are saved with inventory")
	check(FileAccess.get_file_as_string(flow.SAVE_PATH).find("Object(") < 0, "File contains no runtime objects")
	check(flow.return_to_menu() == OK, "Return saves progress")
	await settle()
	check(flow.start_game(true) == OK, "Continue loads")
	await settle()
	paused = true
	check(flow.saves.store.codec.capture(player()) == expected, "Full character round trip including stack order")
	check(player().global_position.distance_to(expected_position) < 3.0, "Load positions player at restpoint")
	check(current_scene.get_node("TestChest").state == 1, "Opened chest stays open")
	var health := player().get_component(HealthComponent) as HealthComponent
	check(health.get_current_health() == health.get_max_health(), "Health restored to derived maximum")
	flask = player().get_component(FlaskChargesComponent) as FlaskChargesComponent
	inventory = player().get_component(InventoryComponent) as InventoryComponent
	for stack: InventoryStack in inventory.get_stacks():
		if stack.item.is_flask():
			check(flask.get_charges(stack.item.id) == flask.get_max_charges(stack.item.id), "Flasks refilled after load")
	# Stale coordinates are overridden by the authored ID position.
	saved = flow.read_save()
	saved.checkpoint = Vector2(-5000, -5000)
	check(flow.saves.store.write_save("user://moved.cfg", saved) == OK, "Write stale coordinate fixture")
	check(flow.return_to_menu() == OK, "Leave before moved-restpoint load")
	await settle()
	check(flow.saves.store.write_save(flow.SAVE_PATH, saved) == OK, "Install moved checkpoint fixture")
	check(flow.start_game(true) == OK, "Load by ID")
	await settle()
	paused = true
	check(player().global_position.distance_to(expected_position) < 3.0, "ID resolves current authored position")
	# Traversing another level preserves the character and the last rested level.
	check(flow.saves.travel_to(load("res://tests/fixtures/SaveTravelLevel.tscn")) == OK, "Level travel succeeds")
	await settle()
	paused = true
	check(flow.saves.store.codec.capture(player()) == expected, "Travel carries character data")
	check(flow.read_save().scene == flow.FIRST_LEVEL, "Travel does not silently change restpoint")
	var next_rest := current_scene.get_node("Shelter") as RestPoint
	next_rest._on_interacted_by(player())
	await settle()
	check(flow.read_save().scene == current_scene.scene_file_path, "Rest in next level moves return destination")
	# Death moves 80% of the wallet to a persistent recovery marker.
	inventory = player().get_component(InventoryComponent) as InventoryComponent
	inventory.add_amber(77)
	var expected_amber := inventory.get_amber()
	player().global_position += Vector2(500, 0)
	health = player().get_component(HealthComponent) as HealthComponent
	health.take_damage(health.get_max_health() * 10)
	var respawn := player().get_component(PlayerRespawnComponent) as PlayerRespawnComponent
	respawn._restart_current_scene()
	await settle()
	paused = true
	check((player().get_component(InventoryComponent) as InventoryComponent).get_amber() == 0, "Death empties wallet")
	check(flow.saves.lost_amber.get("amount", 0) == floori(expected_amber * 0.8), "Death leaves 80 percent for recovery")
	health = player().get_component(HealthComponent) as HealthComponent
	check(health.is_alive() and health.get_current_health() == health.get_max_health(), "Death creates healthy player")
	# Recovery, migration and validation use separate files.
	saved = flow.read_save()
	check(flow.saves.store.write_save("user://recovery.cfg", saved) == OK, "First recovery snapshot")
	check(flow.saves.store.write_save("user://recovery.cfg", saved) == OK, "Backup snapshot")
	var file := FileAccess.open("user://recovery.cfg", FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	check(flow.read_save("user://recovery.cfg").get("recovered", false), "Corrupt primary recovers backup")
	check(flow.saves.store.write_save("user://recovery.cfg", saved) == OK, "Save repairs corrupt primary")
	check(not flow.read_save("user://recovery.cfg").get("recovered", false), "Repaired primary loads")
	var invalid: Dictionary = saved.duplicate(true)
	invalid.player.inventory.stacks[0].item_id = "missing_item"
	check(flow.saves.store.write_save("user://invalid-item.cfg", invalid) == ERR_INVALID_DATA, "Unknown item ID rejected without losing progress")
	invalid = saved.duplicate(true)
	invalid.player.quick_access.assignments = [42]
	check(flow.saves.store.write_save("user://invalid-type.cfg", invalid) == ERR_INVALID_DATA, "Malformed component rejected")
	check(flow.saves.store.write_save("user://missing-directory/save.cfg", saved) != OK, "Disk write failure reported")
	invalid = saved.duplicate(true)
	invalid.player.erase("inventory")
	check(flow.saves.store.write_save("user://incomplete.cfg", invalid) == ERR_INVALID_DATA, "Incomplete snapshot is rejected")
	var working_store: RefCounted = flow.saves.store
	flow.saves.store = FailingStore.new()
	check(flow.return_to_menu() == ERR_FILE_CANT_WRITE, "Failed save blocks return to menu")
	check(flow.saves.active and is_instance_valid(flow._save_warning), "Failure stays in game and displays warning")
	flow.saves.store = working_store
	check(flow.save_checkpoint() == OK, "Retry succeeds after disk becomes writable")
	check(not is_instance_valid(flow._save_warning), "Successful retry clears warning")
	var legacy := ConfigFile.new()
	legacy.set_value("save", "version", 1)
	legacy.set_value("save", "scene", flow.FIRST_LEVEL)
	legacy.set_value("save", "checkpoint", expected_position)
	legacy.save("user://legacy.cfg")
	check(flow.read_save("user://legacy.cfg").get("player") == {}, "Legacy checkpoint migrates with default character")
	# New game clears every persistent domain.
	check(flow.return_to_menu() == OK, "Return before new game")
	await settle()
	check(flow.start_game(false) == OK, "New game replaces old playthrough")
	await settle()
	paused = true
	check(flow.saves.world.is_empty(), "New game clears world flags")
	check((player().get_component(InventoryComponent) as InventoryComponent).get_amber() == 0, "New game resets currency")
	check(current_scene.get_node("TestChest").state == 0, "New game closes chest")
	flow.saves.active = false
	print("Save runtime checks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
