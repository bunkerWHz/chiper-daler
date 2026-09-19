@tool
extends McpTestSuite


func suite_name() -> String:
	return "darklight_visual"


func test_bow_shots_and_indicator_use_grip_before_pose_reset() -> void:
	for facing in [FacingComponent.Direction.RIGHT, FacingComponent.Direction.LEFT]:
		for angle in [-90.0, -45.0, 0.0, 45.0, 90.0]:
			var world := track(Node2D.new()) as Node2D
			(Engine.get_main_loop() as SceneTree).root.add_child(world)
			var player := load("res://game/player/Player.tscn").instantiate() as Actor
			world.add_child(player)
			player.position = Vector2(120, -250)
			var visual := player.get_component(DarklightVisualComponent) as DarklightVisualComponent
			var equipment := player.get_component(EquipmentComponent) as EquipmentComponent
			equipment.switch_weapon_set(1)
			var ranged := player.get_component(RangedWeaponComponent) as RangedWeaponComponent
			var aim := player.get_component(AimingComponent) as AimingComponent
			(player.get_component(FacingComponent) as FacingComponent)._set_direction(facing)
			ranged._set_phase(RangedWeaponComponent.Phase.BOW_AIM, 0.0)
			ranged._ammo_id = &"training_arrows"
			aim._angle = angle
			# No visual process tick: querying the origin must already pose a tap shot.
			var origin := aim.get_launch_position()
			var grip := visual._bow_arm.wrist_bone.get_node("OffHand") as Node2D
			assert_true(origin.is_equal_approx(grip.global_position))
			aim._elapsed = aim.config.hold_delay
			var indicator = aim.get_child(0)
			indicator._process(0.0)
			assert_true(indicator.global_position.is_equal_approx(origin))
			var inventory := player.get_component(InventoryComponent) as InventoryComponent
			inventory.remove_item(&"training_arrows", inventory.get_quantity(&"training_arrows") - 1)
			ranged._fire(true)
			var projectile := world.get_child(world.get_child_count() - 1) as ThrownProjectile
			assert_true(projectile != null)
			assert_true(projectile.global_position.is_equal_approx(origin))
			assert_false(aim.is_aiming())
			assert_eq(inventory.get_quantity(&"training_arrows"), 0)
			assert_true(aim.get_launch_position().is_equal_approx(player.global_position + aim.config.launch_offset))


func test_bow_pose_tracks_aim_and_restores_after_cancel() -> void:
	var player := track(load("res://game/player/Player.tscn").instantiate()) as Actor
	(Engine.get_main_loop() as SceneTree).root.add_child(player)
	var visual := player.get_component(DarklightVisualComponent) as DarklightVisualComponent
	var aim := player.get_component(AimingComponent) as AimingComponent
	var ranged := player.get_component(RangedWeaponComponent) as RangedWeaponComponent
	var facing := player.get_component(FacingComponent) as FacingComponent
	var arm = visual._bow_arm
	var head := visual._head_ik.bone_node
	var original_head := head.rotation
	var original_physics := player.transform
	var original_wrist_target: Transform2D = arm.wrist_ik.target_node.transform
	var radius := -1.0
	aim._owner = ranged
	ranged._phase = RangedWeaponComponent.Phase.BOW_AIM
	for direction in [FacingComponent.Direction.RIGHT, FacingComponent.Direction.LEFT]:
		facing._set_direction(direction)
		visual._apply_facing(direction)
		for angle in [0.0, 45.0, 90.0, 15.0, -45.0, -90.0]:
			aim._angle = angle
			visual._process(0.0)
			var expected_shoulder: float = -arm.elbow_bone.position.angle() - deg_to_rad(angle)
			assert_true(is_equal_approx(arm.shoulder_bone.rotation, expected_shoulder))
			assert_true(is_equal_approx(head.rotation, original_head - deg_to_rad(angle) * 0.25))
			assert_false(arm.arm_ik.enabled)
			assert_false(visual._head_ik.enabled)
			assert_true(arm.wrist_ik.enabled)
			var reach: Vector2 = arm.wrist_bone.global_position - arm.shoulder_bone.global_position
			if radius < 0.0:
				radius = reach.length()
			assert_true(is_equal_approx(reach.length(), radius), "Reach radius changed")
			assert_true(reach.normalized().dot(aim.get_direction()) > 0.999, "Arm misses aim: %s vs %s" % [reach.normalized(), aim.get_direction()])
			var grip := arm.wrist_bone.get_node("OffHand") as Node2D
			var wrist_axis: Vector2 = (grip.global_position - arm.wrist_bone.global_position).normalized()
			assert_true(wrist_axis.dot(aim.get_direction()) > 0.999, "Wrist misses aim: %s vs %s" % [wrist_axis, aim.get_direction()])
			var look_axis: Vector2 = arm.wrist_ik.target_node.global_position - arm.wrist_bone.global_position
			assert_true(look_axis.normalized().dot(arm.wrist_bone.global_transform.x.normalized()) > 0.999, "Look target misses wrist axis")
			visual._process(0.0)
			assert_true(is_equal_approx(head.rotation, original_head - deg_to_rad(angle) * 0.25))
	aim._owner = null
	ranged._phase = RangedWeaponComponent.Phase.NONE
	visual._process(0.0)
	assert_false(visual._bow_pose_active)
	assert_true(arm.arm_ik.enabled)
	assert_true(visual._head_ik.enabled)
	assert_true(is_equal_approx(head.rotation, original_head))
	assert_eq(player.transform, original_physics)
	assert_true(arm.wrist_ik.target_node.transform.is_equal_approx(original_wrist_target))
	# Crossbows and magic do not acquire the bow's FK pose.
	aim._owner = ranged
	ranged._phase = RangedWeaponComponent.Phase.CROSSBOW_AIM
	visual._process(0.0)
	assert_false(visual._bow_pose_active)
	ranged._phase = RangedWeaponComponent.Phase.BOW_AIM
	visual._process(0.0)
	visual.disable()
	assert_false(visual._bow_pose_active)
	assert_true(arm.arm_ik.enabled)


func test_throw_aim_follows_angles_hides_both_hands_and_restores_equipment() -> void:
	for scenario: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)]:
		var release := scenario.y == 1
		var world := track(Node2D.new()) as Node2D
		(Engine.get_main_loop() as SceneTree).root.add_child(world)
		var player := load("res://game/player/Player.tscn").instantiate() as Actor
		world.add_child(player)
		var visual := player.get_component(DarklightVisualComponent) as DarklightVisualComponent
		var equipment := player.get_component(EquipmentComponent) as EquipmentComponent
		equipment.switch_weapon_set(scenario.x)
		var main_was_visible := visual._main_hand.visible
		var off_was_visible := visual._off_hand.visible
		var held := equipment.get_equipped_item(ItemData.EquipSlot.MAIN_HAND)
		var throwing := player.get_component(ThrowingComponent) as ThrowingComponent
		var aim := player.get_component(AimingComponent) as AimingComponent
		var quick := player.get_component(QuickAccessComponent) as QuickAccessComponent
		quick.assign_item(1, &"training_stone")
		quick.activate_slot(1)
		var input := player.get_component(InputComponent) as InputComponent
		input._interact_pressed = true
		throwing._process(0.0)
		(player.get_component(ActorStateComponent) as ActorStateComponent).refresh_state()
		assert_eq(visual.get_animation_player().current_animation, &"throw_aim")
		assert_false(visual._main_hand.visible)
		var arm = visual._bow_arm
		for facing in [FacingComponent.Direction.RIGHT, FacingComponent.Direction.LEFT]:
			(player.get_component(FacingComponent) as FacingComponent)._set_direction(facing)
			for angle: float in [-90.0, -45.0, 0.0, 45.0, 90.0]:
				aim._angle = angle
				visual._process(0.0)
				assert_false(visual._main_hand.visible)
				assert_false(visual._off_hand.visible)
				var reach: Vector2 = arm.wrist_bone.global_position - arm.shoulder_bone.global_position
				assert_true(reach.normalized().dot(aim.get_direction()) > 0.999)
				var head_angle: float = visual._head_ik.bone_node.rotation
				visual._head_ik.enabled = true
				visual._head_ik._process_loop(0.0)
				assert_true(is_equal_approx(head_angle, visual._head_ik.bone_node.rotation - deg_to_rad(angle) * visual.bow_head_follow))
				visual._head_ik.enabled = false
				visual._refresh_equipment_visuals()
				assert_false(visual._main_hand.visible)
				assert_false(visual._off_hand.visible)
		var origin := aim.get_launch_position()
		assert_true(origin.is_equal_approx((arm.wrist_bone.get_node("OffHand") as Node2D).global_position))
		if release:
			input._interact_released = true
			throwing._process(0.0)
			var projectile := world.get_child(world.get_child_count() - 1) as ThrownProjectile
			assert_true(projectile.global_position.is_equal_approx(origin))
		else:
			throwing.cancel_throw()
		(player.get_component(ActorStateComponent) as ActorStateComponent).refresh_state()
		visual._process(0.0)
		assert_eq(visual._main_hand.visible, main_was_visible)
		assert_eq(visual._off_hand.visible, off_was_visible)
		assert_false(visual._bow_pose_active)
		assert_eq(equipment.get_equipped_item(ItemData.EquipSlot.MAIN_HAND), held)


func test_active_equipment_updates_both_skeletal_hand_attachments() -> void:
	var setup := _create_player_visual()
	var equipment := setup.equipment as EquipmentComponent
	var main := setup.player.get_node("_Visual/DarklightRig/CharacterContainer/VisualDetails/MainHand") as Sprite2D
	var off := setup.player.get_node("_Visual/DarklightRig/CharacterContainer/VisualDetails/OffHand") as Sprite2D
	assert_eq(main.texture, equipment.get_equipped_item(ItemData.EquipSlot.MAIN_HAND).equipped_texture)
	assert_true(main.visible)
	assert_true(off.visible)
	assert_true(off.get_node("ShieldGrip").get_child_count() == 1)
	assert_true(equipment.switch_weapon_set(1))
	assert_false(main.visible)
	assert_eq(main.get_node("ShieldGrip").get_child_count(), 0)
	assert_eq(off.texture, equipment.get_equipped_item(ItemData.EquipSlot.MAIN_HAND).equipped_texture)
	assert_true(off.visible)
	assert_true(equipment.switch_weapon_set(0))
	assert_true(main.visible)
	assert_eq(main.texture, equipment.get_equipped_item(ItemData.EquipSlot.MAIN_HAND).equipped_texture)
	assert_true(off.get_node("ShieldGrip").get_child_count() == 1)
	assert_true(equipment.switch_weapon_set(1))
	assert_true(equipment.unequip_item(ItemData.EquipSlot.MAIN_HAND))
	assert_false(main.visible)
	assert_false(off.visible)
	assert_eq(off.get_node("ShieldGrip").get_child_count(), 0)



func test_fsm_selects_attack_variants_and_facing_preserves_physics() -> void:
	var setup := _create_player_visual()
	var visual := setup.visual as DarklightVisualComponent
	var player := setup.player as Actor
	var state := player.get_component(ActorStateComponent) as ActorStateComponent
	var expected := {
		ActorState.Behavior.RUN: &"run",
		ActorState.Behavior.JUMP: &"jump",
		ActorState.Behavior.WALL_JUMP: &"wall_jump",
		ActorState.Behavior.FALL: &"fall",
		ActorState.Behavior.DODGE: &"dodge",
		ActorState.Behavior.GROUND_LIGHT_ATTACK: &"attack",
		ActorState.Behavior.GROUND_HEAVY_ATTACK: &"heavy_attack",
		ActorState.Behavior.AIR_LIGHT_ATTACK: &"air_attack",
		ActorState.Behavior.AIR_HEAVY_ATTACK: &"air_heavy_attack",
		ActorState.Behavior.BLOCKING: &"block",
		ActorState.Behavior.THROWING_AIM: &"throw_aim",
		ActorState.Behavior.AIM_BOW: &"bow_aim",
		ActorState.Behavior.AIM_CROSSBOW: &"crossbow_aim",
		ActorState.Behavior.MAGIC_CHARGE: &"magic_aim",
	}
	for behavior: int in expected:
		state.state_changed.emit(ActorState.Behavior.IDLE, behavior)
		assert_eq(visual.get_animation_player().current_animation, expected[behavior])
		assert_eq(visual.get_state(), behavior)
	var body := (player.get_component(CharacterBodyComponent) as CharacterBodyComponent).get_body()
	var before := body.transform
	var facing := player.get_component(FacingComponent) as FacingComponent
	facing._set_direction(FacingComponent.Direction.LEFT)
	var rig := player.get_node("_Visual/DarklightRig") as Node2D
	assert_true(rig.transform.determinant() < 0.0)
	assert_eq(body.transform, before)
	assert_eq(player.scale, Vector2(0.1, 0.1))
	facing._set_direction(FacingComponent.Direction.RIGHT)
	assert_true(rig.transform.determinant() > 0.0)


func test_authored_bow_pose_survives_aim_updates_and_cancel() -> void:
	var player := track(load("res://game/player/Player.tscn").instantiate()) as Actor
	(Engine.get_main_loop() as SceneTree).root.add_child(player)
	var visual := player.get_component(DarklightVisualComponent) as DarklightVisualComponent
	var animation := visual.get_animation_player()
	# Work on a private library so editing this test's pose cannot affect other players.
	var library := animation.get_animation_library(&"").duplicate(true) as AnimationLibrary
	animation.remove_animation_library(&"")
	animation.add_animation_library(&"", library)
	var clip := animation.get_animation(&"bow_aim")
	var path := NodePath("CharacterContainer/Anim Targets/BackArmFK/Shoulder/Elbow:rotation")
	var track_index := clip.find_track(path, Animation.TYPE_VALUE)
	clip.track_set_key_value(track_index, 0, 0.4)
	clip.track_insert_key(track_index, 1.0, 0.8)
	var aim := player.get_component(AimingComponent) as AimingComponent
	var ranged := player.get_component(RangedWeaponComponent) as RangedWeaponComponent
	var state := player.get_component(ActorStateComponent) as ActorStateComponent
	aim._owner = ranged
	ranged._phase = RangedWeaponComponent.Phase.BOW_AIM
	state.state_changed.emit(ActorState.Behavior.IDLE, ActorState.Behavior.AIM_BOW)
	animation.seek(0.5, true)
	for facing in [FacingComponent.Direction.RIGHT, FacingComponent.Direction.LEFT]:
		visual._apply_facing(facing)
		for angle: float in [-45.0, 0.0, 45.0]:
			aim._angle = angle
			visual._process(0.0)
			assert_true(is_equal_approx(visual._bow_arm.elbow_bone.rotation, 0.6))
			var shoulder: float = visual._bow_arm.shoulder_bone.rotation
			var head: float = visual._head_ik.bone_node.rotation
			visual._process(0.0)
			assert_true(is_equal_approx(visual._bow_arm.shoulder_bone.rotation, shoulder))
			assert_true(is_equal_approx(visual._head_ik.bone_node.rotation, head))
	aim._owner = null
	ranged._phase = RangedWeaponComponent.Phase.NONE
	state.state_changed.emit(ActorState.Behavior.AIM_BOW, ActorState.Behavior.IDLE)
	assert_eq(animation.current_animation, &"idle")
	assert_false(visual._bow_pose_active)
	assert_true(visual._bow_arm.arm_ik.enabled)


func test_native_collision_shapes_follow_requested_player_size() -> void:
	var setup := _create_player_visual()
	var player := setup.player as Actor
	for path: String in ["CharacterBodyComponent/CharacterBody2D", "HurtboxComponent/Area2D"]:
		var collision := player.get_node("_Components/" + path + "/CollisionShape2D") as CollisionShape2D
		assert_eq(collision.scale, Vector2.ONE)
		assert_eq((collision.shape as RectangleShape2D).size, Vector2(412, 970))
		assert_eq(collision.position, Vector2(0, -250))
		assert_true(((collision.shape as RectangleShape2D).size * player.scale).is_equal_approx(Vector2(41.2, 97)))
	var hitbox := player.get_node("_Components/HitboxComponent") as Node2D
	assert_eq(hitbox.position * player.scale, Vector2(50, -25))
	var hit_shape := hitbox.get_node("Area2D/CollisionShape2D") as CollisionShape2D
	assert_eq(hit_shape.scale, Vector2.ONE)
	assert_eq((hit_shape.shape as RectangleShape2D).size, Vector2(500, 500))



func test_flasks_play_drink_without_legacy_overlays() -> void:
	var setup := _create_player_visual()
	var visual := setup.visual as DarklightVisualComponent
	var item_use := setup.item_use as ItemUseComponent
	var inventory := setup.inventory as InventoryComponent
	for item_id in [&"health_potion", &"mana_potion", &"rage_potion"]:
		var item := inventory.get_item_data(item_id)
		assert_true(item.icon != null)
		assert_true(item.icon.resource_path.begins_with("res://assets/items/Flasks/"))
		item_use.item_use_started.emit(item)
		visual._apply_state(ActorState.Behavior.USING_ITEM, true)
		assert_eq(visual.get_animation_player().current_animation, &"drink")
		assert_false(visual.get_item_effect_sprite().visible)
		assert_false(visual._main_hand.visible)
		assert_false(visual._off_hand.visible)
		# Equipment refreshes must not reveal weapons during the drinking pose.
		visual._refresh_equipment_visuals()
		assert_false(visual._main_hand.visible)
		assert_false(visual._off_hand.visible)
		var animation := visual.get_animation_player()
		assert_eq(animation.speed_scale, 1.0)
		assert_true(is_equal_approx(animation.get_playing_speed(), animation.get_animation(&"drink").length / item_use.config.use_duration))
		item_use.item_use_cancelled.emit()
		visual._apply_state(ActorState.Behavior.IDLE)
		assert_eq(animation.current_animation, &"idle")
		assert_false(visual.get_item_effect_sprite().visible)
		assert_true(visual._main_hand.visible)
		assert_true(visual._off_hand.visible)
	# Normal completion also restores the currently equipped visuals.
	item_use.item_use_started.emit(inventory.get_item_data(&"health_potion"))
	visual._apply_state(ActorState.Behavior.USING_ITEM)
	visual._apply_state(ActorState.Behavior.IDLE)
	assert_true(visual._main_hand.visible)
	assert_true(visual._off_hand.visible)
	var rage := inventory.get_item_data(&"rage_potion")
	assert_true((setup.status_effects as StatusEffectComponent).apply_effect(rage.get_status_effect()))
	assert_true(visual.get_buff_effect_sprite().visible)

func _create_player_visual() -> Dictionary:
	var packed := load("res://game/player/Player.tscn") as PackedScene
	var player := track(packed.instantiate()) as Actor
	player._collect_components()
	var equipment := player.get_component(EquipmentComponent) as EquipmentComponent
	var visual := (
		player.get_component(DarklightVisualComponent)
		as DarklightVisualComponent
	)
	equipment._ready()
	visual._ready()
	return {
		"player": player,
		"visual": visual,
		"equipment": equipment,
		"inventory": player.get_component(InventoryComponent),
		"item_use": player.get_component(ItemUseComponent),
		"status_effects": player.get_component(StatusEffectComponent),
	}


func test_quiver_follows_equipped_ammunition_and_empty_stacks() -> void:
	var setup := _create_player_visual()
	var equipment := setup.equipment as EquipmentComponent
	var inventory := setup.inventory as InventoryComponent
	var quiver := setup.player.get_node("_Visual/DarklightRig/CharacterContainer/VisualDetails/Arrows") as Sprite2D
	assert_false(quiver.visible)
	assert_true(equipment.switch_weapon_set(1))
	assert_true(quiver.visible)
	assert_true(equipment.unequip_item(ItemData.EquipSlot.OFF_HAND))
	assert_false(quiver.visible)
	assert_true(equipment.equip_inventory_item(&"training_arrows", ItemData.EquipSlot.OFF_HAND))
	assert_true(quiver.visible)
	var count := inventory.get_quantity(&"training_arrows")
	assert_eq(inventory.remove_item(&"training_arrows", count), count)
	assert_false(quiver.visible)
	assert_true(equipment.equip_inventory_item(&"training_crossbow", ItemData.EquipSlot.MAIN_HAND))
	assert_eq(equipment.get_equipped_item_id(ItemData.EquipSlot.OFF_HAND), &"training_bolts")
	assert_true(quiver.visible)
	assert_true(equipment.switch_weapon_set(0))
	assert_false(quiver.visible)
	assert_true(equipment.switch_weapon_set(1))
	assert_true(quiver.visible)
	count = inventory.get_quantity(&"training_bolts")
	assert_eq(inventory.remove_item(&"training_bolts", count), count)
	assert_false(quiver.visible)


func test_display_override_changes_texture_without_moving_inventory_slot_or_grip() -> void:
	var setup := _create_player_visual()
	var inventory := setup.inventory as InventoryComponent
	var equipment := setup.equipment as EquipmentComponent
	var off := setup.player.get_node("_Visual/DarklightRig/CharacterContainer/VisualDetails/OffHand") as Sprite2D
	var main := setup.player.get_node("_Visual/DarklightRig/CharacterContainer/VisualDetails/MainHand") as Sprite2D
	var marker := Marker2D.new()
	off.add_child(marker)
	var grip_offset := off.offset
	var grip_centered := off.centered
	var item := ItemData.new()
	item.id = &"display_override_probe"
	item.category = ItemData.Category.WEAPON
	item.equipment_profile = ItemEquipmentProfile.new()
	item.equipment_profile.allowed_slots = [ItemData.EquipSlot.MAIN_HAND]
	item.equipment_profile.display_slot = ItemEquipmentProfile.DisplaySlot.OFF_HAND
	item.equipped_texture = load("res://assets/Characters/Darklight/equipment/Sword.png") as Texture2D
	inventory.add_item(item)
	assert_true(equipment.equip_inventory_item(item.id, ItemData.EquipSlot.MAIN_HAND))
	assert_eq(equipment.get_equipped_item_id(ItemData.EquipSlot.MAIN_HAND), item.id)
	assert_eq(off.texture, item.equipped_texture)
	assert_false(main.visible)
	assert_eq(marker.get_parent(), off)
	assert_eq(off.offset, grip_offset)
	assert_eq(off.centered, grip_centered)
	assert_true(off.scale.is_equal_approx(Vector2.ONE))
