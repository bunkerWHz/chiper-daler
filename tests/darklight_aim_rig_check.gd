extends SceneTree

## The two Darklight rigs must answer the shared aim pose identically: the
## canonical SoupIK rig and the native-solver copy that gameplay uses.
##
## Run with:
##   godot --headless --path . --script tests/darklight_aim_rig_check.gd
##
## Both rigs are driven through Player.tscn with their `_Visual/DarklightRig`
## instance swapped, so the check does not depend on which rig the player scene
## currently ships. Every measurement is taken after real frames, with the live
## IK solvers running.

const SOUPIK_RIG := "res://game/player/darklight/DarklightRig.tscn"
const NATIVE_RIG := "res://game/player/darklight/DarklightRig2.tscn"
const AIM_ANGLES: Array[float] = [0.0, 30.0, -30.0, 60.0, -60.0]
## The rigs substitute the same solvers, so their poses may differ only by
## floating point noise.
const HEAD_TOLERANCE_DEGREES := 0.2
const AIM_TOLERANCE := 0.999

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


func _run() -> void:
	var soupik := await _measure_rig(SOUPIK_RIG)
	var native := await _measure_rig(NATIVE_RIG)
	for index in AIM_ANGLES.size():
		var angle: float = AIM_ANGLES[index]
		for measured: Dictionary in [soupik, native]:
			_check(measured.arm[index] > AIM_TOLERANCE, "%s arm misses the aim at %s" % [measured.rig, angle])
			_check(measured.hand[index] > AIM_TOLERANCE, "%s hand misses the aim at %s" % [measured.rig, angle])
		var gap: float = absf(float(soupik.head[index]) - float(native.head[index]))
		_check(
			gap <= HEAD_TOLERANCE_DEGREES,
			"Head follow differs between rigs at %s: %s deg vs %s deg" % [angle, soupik.head[index], native.head[index]]
		)
		if angle != 0.0:
			# Both rigs share one follow factor; only its linearity is checked here.
			var ratio: float = absf(float(native.head[index]) - float(native.head[0])) / absf(angle)
			_check(
				absf(ratio - native.head_follow) <= native.head_follow * 0.1,
				"The native head must follow the aim at %s deg per deg, measured %s" % [native.head_follow, ratio]
			)
	for measured: Dictionary in [soupik, native]:
		_check(not measured.pose_active, "%s must leave the aim pose after cancel" % measured.rig)
		_check(
			absf(measured.head_after_cancel) <= 0.5,
			"%s must restore the head after cancel, drift %s deg" % [measured.rig, measured.head_after_cancel]
		)
		_check(bool(measured.throw_tracked), "%s must answer the throwing aim too" % measured.rig)
	print("Darklight aim rigs: ", "FAIL" if _failed else "PASS")
	quit(1 if _failed else 0)


func _rig_player(rig_path: String) -> Actor:
	var player := (load("res://game/player/Player.tscn") as PackedScene).instantiate() as Actor
	var rig := player.get_node("_Visual/DarklightRig")
	var parent := rig.get_parent()
	var index := rig.get_index()
	parent.remove_child(rig)
	rig.free()
	var replacement := (load(rig_path) as PackedScene).instantiate() as Node2D
	replacement.name = "DarklightRig"
	parent.add_child(replacement)
	parent.move_child(replacement, index)
	return player


func _measure_rig(rig_path: String) -> Dictionary:
	var world := Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4000, 40)
	collision.shape = rectangle
	floor_body.add_child(collision)
	floor_body.position.y = 100
	world.add_child(floor_body)
	var player := _rig_player(rig_path)
	world.add_child(player)
	(player.get_component(CameraComponent) as CameraComponent).get_camera().enabled = false
	var visual := player.get_component(DarklightVisualComponent) as DarklightVisualComponent
	var aim := player.get_component(AimingComponent) as AimingComponent
	var ranged := player.get_component(RangedWeaponComponent) as RangedWeaponComponent
	var throwing := player.get_component(ThrowingComponent) as ThrowingComponent
	var quick := player.get_component(QuickAccessComponent) as QuickAccessComponent
	var input := player.get_component(InputComponent) as InputComponent
	var skeleton := player.get_node("_Visual/DarklightRig/CharacterContainer/Skeleton2D") as Skeleton2D
	var shoulder := skeleton.get_node("Hip/BackArmTop") as Bone2D
	var wrist := skeleton.get_node("Hip/BackArmTop/BackArmMid/BackArmBot") as Bone2D
	var grip := wrist.get_node("OffHand") as Node2D
	var head := skeleton.get_node("Hip/Torso/Head") as Bone2D
	for frame in 45:
		await physics_frame
	var idle_head := head.rotation
	var measured := {
		"rig": rig_path,
		"arm": [],
		"hand": [],
		"head": [],
		"head_follow": visual.bow_head_follow,
		"pose_active": true,
		"head_after_cancel": 0.0,
		"throw_tracked": false,
	}
	ranged._set_phase(RangedWeaponComponent.Phase.BOW_AIM, 0.0)
	ranged._ammo_id = &"training_arrows"
	for angle: float in AIM_ANGLES:
		aim._angle = angle
		for frame in 8:
			await physics_frame
		var direction: Vector2 = aim.get_direction()
		var reach: Vector2 = wrist.global_position - shoulder.global_position
		var hand: Vector2 = grip.global_position - wrist.global_position
		measured.arm.append(reach.normalized().dot(direction))
		measured.hand.append(hand.normalized().dot(direction))
		measured.head.append(rad_to_deg(head.rotation - idle_head))
	# The throwing aim shares the same pose path with a different owner.
	ranged._set_phase(RangedWeaponComponent.Phase.NONE, 0.0)
	for frame in 8:
		await physics_frame
	quick.assign_item(1, &"training_stone")
	quick.activate_slot(1)
	input._interact_pressed = true
	throwing._process(0.0)
	(player.get_component(ActorStateComponent) as ActorStateComponent).refresh_state()
	for frame in 12:
		await physics_frame
	aim._angle = 45.0
	for frame in 8:
		await physics_frame
	var throw_direction: Vector2 = aim.get_direction()
	var throw_reach: Vector2 = wrist.global_position - shoulder.global_position
	measured.throw_tracked = throw_reach.normalized().dot(throw_direction) > AIM_TOLERANCE
	throwing.cancel_throw()
	for frame in 20:
		await physics_frame
	measured.pose_active = visual._bow_pose_active
	measured.head_after_cancel = rad_to_deg(head.rotation - idle_head)
	world.queue_free()
	await process_frame
	return measured
