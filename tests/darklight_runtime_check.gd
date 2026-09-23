extends SceneTree

var _failed := false


func _initialize() -> void:
	debug_collisions_hint = "--collision-preview" in OS.get_cmdline_user_args()
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2000, 40)
	collision.shape = rectangle
	floor_body.add_child(collision)
	floor_body.position.y = 100
	world.add_child(floor_body)
	var floor_art := Polygon2D.new()
	floor_art.polygon = PackedVector2Array([Vector2(-1000, 80), Vector2(1000, 80), Vector2(1000, 120), Vector2(-1000, 120)])
	floor_art.color = Color(0.22, 0.26, 0.3)
	world.add_child(floor_art)
	var player := (load("res://game/player/Player.tscn") as PackedScene).instantiate() as Actor
	world.add_child(player)
	(player.get_component(CameraComponent) as CameraComponent).get_camera().enabled = false
	var camera := Camera2D.new()
	camera.zoom = Vector2(4, 4)
	camera.position = Vector2(0, 20)
	world.add_child(camera)
	camera.make_current()
	var body := player.get_component(CharacterBodyComponent) as CharacterBodyComponent
	var visual := player.get_component(DarklightVisualComponent) as DarklightVisualComponent
	var state := player.get_component(ActorStateComponent) as ActorStateComponent
	var rig := player.get_node("_Visual/DarklightRig") as Node2D
	for frame in 65:
		await physics_frame
	_check(body.is_on_floor(), "Darklight must land on the existing player collision")
	_check(absf(player.position.y - 56.5) < 0.2, "The larger character must land with its feet at floor contact")
	_check(visual.get_animation_player().current_animation == &"idle", "FSM must drive idle")
	for sprite: Node in rig.find_children("*", "Sprite2D", true, false):
		_check((sprite as Sprite2D).scale.is_equal_approx(Vector2.ONE), "Native sprites must remain at unit scale")
	var head_query := PhysicsPointQueryParameters2D.new()
	head_query.position = player.global_position + Vector2(0, -60)
	head_query.collision_mask = 4
	head_query.collide_with_areas = true
	head_query.collide_with_bodies = false
	var head_hits := world.get_world_2d().direct_space_state.intersect_point(head_query)
	var upper_body_hittable := false
	for hit: Dictionary in head_hits:
		if hit.collider == player.get_node("_Components/HurtboxComponent/Area2D"):
			upper_body_hittable = true
	_check(upper_body_hittable, "Hurtbox must cover the upper body, not only the legs")
	await _capture("darklight_right")
	var start_x := player.position.x
	Input.action_press(&"move_left")
	for frame in 8:
		await physics_frame
	Input.action_release(&"move_left")
	_check(player.position.x < start_x, "Existing movement must move Darklight left")
	_check(rig.transform.determinant() < 0.0, "Skeleton and IK targets must face left together")
	for frame in 20:
		await physics_frame
	camera.position.x = player.position.x
	await _capture("darklight_left")
	Input.action_press(&"jump")
	for frame in 5:
		await physics_frame
	Input.action_release(&"jump")
	await process_frame
	await process_frame
	_check(not body.is_on_floor(), "Existing jump must work with the native rig scale")
	var cloth := rig.get_node("CharacterContainer/VisualDetails/Cloak/CloakAnimation") as AnimationPlayer
	_check(cloth.current_animation == &"jump", "Ascending must tuck the cloak")
	_check(state.get_state() in [ActorState.Behavior.JUMP, ActorState.Behavior.DOUBLE_JUMP], "Jump must be resolved by the current FSM: " + ActorState.get_behavior_name(state.get_state()))
	var saw_falling_cloak := false
	for frame in 100:
		await physics_frame
		if cloth.current_animation == &"fall":
			saw_falling_cloak = true
	_check(saw_falling_cloak, "Descending must inflate the cloak")
	_check(cloth.current_animation == &"wind", "Landing must restore wind")
	var dodge := player.get_component(DodgeComponent) as DodgeComponent
	var animation := visual.get_animation_player()
	# The ground dodge is the authored tucked roll and owns its own duration.
	_check(body.is_on_floor(), "The ground dodge check needs floor contact")
	Input.action_press(&"dodge")
	for frame in 3:
		await physics_frame
	Input.action_release(&"dodge")
	_check(dodge.is_dodging() and not dodge.is_air_dodge(), "Dodging on the floor must be the ground roll")
	_check(state.get_state() == ActorState.Behavior.DODGE, "The FSM must resolve the ground dodge: " + ActorState.get_behavior_name(state.get_state()))
	_check(animation.current_animation == &"dodge_roll", "The grounded dodge must play dodge_roll")
	_check(
		is_equal_approx(animation.get_playing_speed(), animation.get_animation(&"dodge_roll").length / dodge.config.roll_duration),
		"The roll must be retimed against roll_duration"
	)
	await _capture("darklight_dodge_roll")
	for frame in 45:
		await physics_frame
	_check(not dodge.is_dodging() and body.is_on_floor(), "The ground roll must finish on the floor")
	# The same action in the air is the short source clip.
	Input.action_press(&"jump")
	for frame in 5:
		await physics_frame
	Input.action_release(&"jump")
	for frame in 4:
		await physics_frame
	_check(not body.is_on_floor(), "The air dodge check needs the player off the floor")
	Input.action_press(&"dodge")
	for frame in 3:
		await physics_frame
	Input.action_release(&"dodge")
	_check(dodge.is_dodging() and dodge.is_air_dodge(), "Dodging in the air must be the air dodge")
	_check(animation.current_animation == &"dodge_air", "The airborne dodge must play dodge_air")
	for frame in 90:
		await physics_frame
	_check(body.is_on_floor(), "The player must land after the air dodge")
	var equipment := player.get_component(EquipmentComponent) as EquipmentComponent
	_check(equipment.switch_weapon_set(1), "Existing inventory must switch to the bow")
	var hand := rig.get_node("CharacterContainer/Skeleton2D/Hip/BackArmTop/BackArmMid/BackArmBot/OffHand") as Sprite2D
	_check(hand.texture == equipment.get_equipped_item(ItemData.EquipSlot.MAIN_HAND).equipped_texture, "Equipped bow must follow the opposite hand bone")
	for frame in 4:
		await physics_frame
	await _capture("darklight_bow")
	for frame in 65:
		await physics_frame
	Input.action_press(&"attack")
	for frame in 5:
		await process_frame
	var aiming := player.get_component(AimingComponent) as AimingComponent
	_check(visual._bow_pose_active, "Holding attack with a bow must activate the aiming pose")
	var head := rig.get_node("CharacterContainer/Skeleton2D/Hip/Torso/Head") as Bone2D
	var head_rest := rad_to_deg(head.rotation)
	for angle in [0.0, 45.0, 85.0, -45.0, -90.0]:
		aiming._angle = angle
		for frame in 3:
			await process_frame
		var arm = visual._bow_arm
		var reach: Vector2 = arm.wrist_bone.global_position - arm.shoulder_bone.global_position
		_check(reach.normalized().dot(aiming.get_direction()) > 0.999, "Bow arm must follow the live aim")
		var grip := arm.wrist_bone.get_node("OffHand") as Node2D
		var grip_axis: Vector2 = (grip.global_position - arm.wrist_bone.global_position).normalized()
		_check(grip_axis.dot(aiming.get_direction()) > 0.999, "Wrist-to-grip direction must follow aim")
		var head_follow := rad_to_deg(head.rotation) - head_rest
		_check(
			absf(head_follow + angle * visual.bow_head_follow) <= 2.0,
			"Head must follow the live aim: %s deg at %s" % [head_follow, angle]
		)
		await _capture("darklight_bow_aim_" + str(int(angle)))
	# Submit release at the start of a frame, not after frame_post_draw.
	await process_frame
	Input.action_release(&"attack")
	for frame in 5:
		await process_frame
	_check(not visual._bow_pose_active, "Releasing the bow must restore normal rig control")
	var menu := player.get_component(InventoryMenuComponent) as InventoryMenuComponent
	menu.open_inventory()
	_check(paused and menu.is_open(), "Existing inventory menu must open and pause gameplay")
	menu.close_inventory()
	_check(not paused, "Closing inventory must resume gameplay")
	print("Darklight runtime: ", "FAIL" if _failed else "PASS")
	world.queue_free()
	await process_frame
	quit(1 if _failed else 0)


func _capture(file_name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + file_name + ".png")
