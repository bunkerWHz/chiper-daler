extends SceneTree

## Runtime check for the aiming angle memory on the real Player scene.
## Verifies that physics and the rig do not clear the memory while standing,
## that a new aim reuses the shot angle, and that walking clears it.
## Waits are wall-clock based, so any frame rate is accepted:
## godot --headless --path . --script tests/aiming_memory_runtime_check.gd

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await physics_frame


func _run() -> void:
	var world := preload("res://tests/AimingSandbox.tscn").instantiate() as Node2D
	root.add_child(world)
	var player := world.get_node("Player") as Actor
	var equipment := player.get_component(EquipmentComponent) as EquipmentComponent
	var body := player.get_component(CharacterBodyComponent) as CharacterBodyComponent
	var aim := player.get_component(AimingComponent) as AimingComponent
	var ranged := player.get_component(RangedWeaponComponent) as RangedWeaponComponent

	for _frame in 200:
		await physics_frame
		if body.is_on_floor():
			break
	check(body.is_on_floor(), "Player lands on the sandbox floor")
	await _wait(0.1)

	# The sandbox modes must all reach their action slot.
	for slot: int in [
		EquipmentComponent.Slot.THROWABLE,
		EquipmentComponent.Slot.BOW,
		EquipmentComponent.Slot.CROSSBOW,
		EquipmentComponent.Slot.MAGIC,
	]:
		world._select_mode(slot)
		await _wait(0.1)
		check(
			equipment.is_slot_active(slot),
			"Sandbox mode %s activates" % EquipmentComponent.Slot.keys()[slot]
		)

	world._select_mode(EquipmentComponent.Slot.BOW)
	await _wait(0.1)
	check(equipment.is_slot_active(EquipmentComponent.Slot.BOW), "Bow mode is active")
	check(
		equipment.get_equipped_item_id(ItemData.EquipSlot.MAIN_HAND) == &"training_bow",
		"Bow is in the main hand"
	)
	check(is_zero_approx(ranged.config.aim_default_angle_degrees), "Bow starts flat")

	# Hold the action, raise the aim with W, then release to shoot.
	Input.action_press(&"attack")
	Input.action_press(&"move_up")
	for _frame in 600:
		await physics_frame
		if aim._angle > 20.0:
			break
	Input.action_release(&"move_up")
	var aimed_angle: float = aim._angle
	check(aimed_angle > 20.0, "Held aim raises the bow above the default")
	Input.action_release(&"attack")
	await _wait(0.1)
	var remembered: float = aim.get_remembered_angle()
	check(aim.has_remembered_angle(), "A shot is remembered")
	check(
		is_equal_approx(remembered, aimed_angle),
		"Remembered angle matches the shot: %s vs %s" % [remembered, aimed_angle]
	)

	# Standing on the floor must not read as movement.
	await _wait(0.5)
	check(aim.has_remembered_angle(), "Standing still keeps the remembered angle")

	# A new aim inside the window starts from the remembered angle.
	Input.action_press(&"attack")
	await _wait(0.1)
	check(aim.is_aiming(), "Second aim begins")
	check(
		is_equal_approx(aim._angle, remembered),
		"Second aim reuses the shot angle: %s vs %s" % [aim._angle, remembered]
	)
	Input.action_release(&"attack")
	await _wait(0.2)
	check(aim.has_remembered_angle(), "The second shot is remembered too")

	# Walking clears the memory.
	Input.action_press(&"move_right")
	await _wait(0.5)
	Input.action_release(&"move_right")
	check(not aim.has_remembered_angle(), "Walking clears the remembered angle")

	# The window itself expires in real time.
	Input.action_press(&"attack")
	await _wait(0.1)
	Input.action_release(&"attack")
	await physics_frame
	check(aim.has_remembered_angle(), "Fresh shot is remembered before the window ends")
	var remaining := aim.get_remembered_time_left()
	var window_start := Time.get_ticks_msec()
	var ended := false
	for _frame in 900:
		await physics_frame
		if not aim.has_remembered_angle():
			ended = true
			break
	var elapsed := (Time.get_ticks_msec() - window_start) / 1000.0
	check(ended, "The remembered angle expires with the window")
	check(
		absf(remaining - elapsed) < 0.2,
		"The full window runs in real time: left %s s, waited %s s" % [remaining, elapsed]
	)
	check(
		elapsed >= aim.config.angle_memory_duration - 0.2,
		"The window is not shorter than configured: waited %s s" % elapsed
	)

	world.queue_free()
	await process_frame
	print("Aiming memory runtime: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
