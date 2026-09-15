extends SceneTree

var failures := 0
var checks := 0
var flow: Node


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func player() -> Actor:
	return current_scene.get_node("Player") as Actor


func inventory() -> InventoryComponent:
	return player().get_component(InventoryComponent) as InventoryComponent


func die_at(position: Vector2) -> void:
	player().global_position = position
	var health := player().get_component(HealthComponent) as HealthComponent
	health.take_damage(health.get_max_health() * 10)


func respawn() -> void:
	(player().get_component(PlayerRespawnComponent) as PlayerRespawnComponent)._restart_current_scene()
	await settle()
	paused = true


func _run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.godot/"):
		push_error("Use an isolated APPDATA profile inside .godot")
		quit(1)
		return
	flow = root.get_node("GameFlow")
	check(flow.start_game(false) == OK, "Start new game")
	await settle()
	paused = true
	inventory().add_amber(101)
	var position := Vector2(800, 100)
	die_at(position)
	check(inventory().get_amber() == 0, "Death drains disabled inventory")
	check(flow.saves.lost_amber.amount == 80, "Recoverable amount rounds down")
	check(flow.saves.lost_amber.position == position, "Records exact death position")
	flow.saves._on_player_died()
	check(flow.saves.lost_amber.amount == 80, "Duplicate death notification does not replace loss")
	await settle()
	var dead_marker: Area2D = flow.saves._lost_amber_marker
	check(not dead_marker.try_collect(player()), "Dead player cannot collect")
	check(flow.read_save().player.inventory.amber == 0, "Wallet deduction saved during death screen")
	check(flow.read_save().lost_amber.amount == 80, "Loss saved with deduction")
	check(flow.return_to_menu() == OK, "Exit during death screen")
	await settle()
	check(flow.start_game(true) == OK, "Load loss from disk")
	await settle()
	paused = true
	var marker: Area2D = flow.saves._lost_amber_marker
	check(is_instance_valid(marker) and marker.global_position == position, "Reload restores anchored marker")
	var enemy := current_scene.get_node("Enemy") as Actor
	check(not marker.try_collect(enemy), "Enemy cannot recover player loss")
	check(marker.try_collect(player()), "Living player recovers loss")
	check(not marker.try_collect(player()), "Same marker cannot collect twice")
	check(inventory().get_amber() == 80 and flow.saves.lost_amber.is_empty(), "Recover credits only 80 percent")
	await settle()
	check(flow.read_save().lost_amber.is_empty() and flow.read_save().player.inventory.amber == 80, "Collection saved atomically")
	# A second death replaces the unclaimed stash, even with no new currency.
	die_at(Vector2(900, 100))
	check(flow.saves.lost_amber.amount == 64, "Next death charges 20 percent again")
	await respawn()
	die_at(Vector2(1000, 100))
	check(flow.saves.lost_amber.is_empty(), "Empty-wallet death destroys previous stash")
	await respawn()
	inventory().add_amber(100)
	die_at(Vector2(800, 100))
	await respawn()
	inventory().add_amber(50)
	die_at(Vector2(1000, 100))
	check(flow.saves.lost_amber.amount == 40 and flow.saves.lost_amber.position == Vector2(1000, 100), "Second death replaces old stash with 80 percent of new wallet")
	await respawn()
	# Leaving the level hides the marker without destroying its record.
	check(flow.saves.travel_to(load("res://tests/fixtures/SaveTravelLevel.tscn")) == OK, "Travel to another level")
	await settle()
	paused = true
	check(not is_instance_valid(flow.saves._lost_amber_marker) and flow.saves.lost_amber.amount == 40, "Loss retained in another level")
	check(flow.saves.travel_to(load(flow.FIRST_LEVEL)) == OK, "Return to death level")
	await settle()
	paused = true
	check(is_instance_valid(flow.saves._lost_amber_marker), "Marker returns in correct level")
	# Verify real Area2D contact, not only direct recovery calls.
	marker = flow.saves._lost_amber_marker
	marker.global_position = (player().get_component(CharacterBodyComponent) as CharacterBodyComponent).get_body().global_position
	paused = false
	for index in 5:
		await physics_frame
	await settle()
	paused = true
	check(inventory().get_amber() == 40 and flow.saves.lost_amber.is_empty(), "Physics overlap collects marker")
	var snapshot: Dictionary = flow.read_save()
	var old := ConfigFile.new()
	for key: String in snapshot:
		if key != "lost_amber":
			old.set_value("save", key, snapshot[key])
	old.set_value("save", "version", 2)
	old.save("user://before-loss.cfg")
	check(flow.read_save("user://before-loss.cfg").get("lost_amber") == {}, "Version 2 migrates without loss")
	snapshot.lost_amber = {"scene": flow.FIRST_LEVEL, "position": Vector2.INF, "amount": 20}
	check(flow.saves.store.write_save("user://invalid-loss.cfg", snapshot) == ERR_INVALID_DATA, "Invalid loss position rejected")
	die_at(Vector2(800, 100))
	check(flow.start_game(false) == OK, "New game starts after loss")
	await settle()
	check(flow.saves.lost_amber.is_empty(), "New game clears loss")
	paused = true
	inventory().add_amber(1)
	die_at(Vector2(800, 100))
	check(inventory().get_amber() == 0 and flow.saves.lost_amber.is_empty(), "One amber rounds to no recovery marker")
	flow.saves.active = false
	print("Lost amber checks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
