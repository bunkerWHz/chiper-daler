@tool
extends McpTestSuite


func suite_name() -> String:
	return "aiming"


func test_tap_uses_default_angle_once_for_every_weapon() -> void:
	for slot: int in [EquipmentComponent.Slot.THROWABLE, EquipmentComponent.Slot.BOW,
		EquipmentComponent.Slot.CROSSBOW, EquipmentComponent.Slot.MAGIC]:
		var s := _create_actor()
		preload("res://tests/AimingTestFactory.gd").select_weapon(s, slot)
		var ability: Component = _ability(s, slot)
		_press(s, slot)
		_release(s, slot)
		ability._process(0.0)
		assert_false(s.aim.is_aiming())
		assert_eq(s.root.get_child_count(), 2)
		var projectile := s.root.get_child(1) as ThrownProjectile
		assert_true(projectile._velocity.normalized().is_equal_approx(Vector2.RIGHT.rotated(deg_to_rad(-5.0))))
		assert_true(projectile.global_position.is_equal_approx(s.aim.get_launch_position()))
		ability._process(0.0)
		assert_eq(s.root.get_child_count(), 2)


func test_mouse_keys_limits_and_turn_share_one_angle() -> void:
	var s := _create_actor()
	assert_true(s.aim.begin_aim(s.throwing))
	s.input._vertical_axis = -1.0
	s.aim._process(s.aim.config.hold_delay)
	s.aim._process(0.25)
	assert_true(is_equal_approx(s.aim._angle, 27.5))
	s.input._vertical_axis = 0.0
	s.input._aim_mouse_motion = 10.0
	s.aim._process(0.0)
	assert_true(is_equal_approx(s.aim._angle, 25.0))
	var right: Vector2 = s.aim.get_direction()
	s.input._move_axis = -1.0
	s.facing._physics_process(0.0)
	assert_true(s.aim.get_direction().is_equal_approx(Vector2(-right.x, right.y)))
	s.input._vertical_axis = -1.0
	s.aim._process(10.0)
	assert_true(s.aim.get_direction().is_equal_approx(Vector2.UP))
	s.input._vertical_axis = 1.0
	s.aim._process(10.0)
	assert_true(s.aim.get_direction().is_equal_approx(Vector2.DOWN))


func test_small_stick_deflection_changes_angle_more_slowly() -> void:
	var s := _create_actor()
	s.aim.begin_aim(s.throwing)
	s.aim._process(s.aim.config.hold_delay)
	s.input._vertical_axis = -0.5
	s.aim._process(0.5)
	assert_true(is_equal_approx(s.aim._angle, 27.5))


func test_downward_aim_fires_below_platform_for_every_weapon_and_facing() -> void:
	for slot: int in [EquipmentComponent.Slot.THROWABLE, EquipmentComponent.Slot.BOW,
		EquipmentComponent.Slot.CROSSBOW, EquipmentComponent.Slot.MAGIC]:
		for facing in [-1.0, 1.0]:
			var s := _create_actor()
			preload("res://tests/AimingTestFactory.gd").select_weapon(s, slot)
			var ability: Component = _ability(s, slot)
			_press(s, slot)
			ability._process(0.0)
			s.aim._process(s.aim.config.hold_delay)
			# Lower from +5 to -45 using the same mouse input as gameplay.
			s.input._aim_mouse_motion = 200.0
			s.aim._process(0.0)
			s.input._move_axis = facing
			s.facing._physics_process(0.0)
			var direction := Vector2(facing, 1.0).normalized()
			assert_true(s.aim.get_direction().is_equal_approx(direction))
			_release(s, slot)
			ability._process(0.0)
			var projectile := s.root.get_child(1) as ThrownProjectile
			assert_true(projectile._velocity.normalized().is_equal_approx(direction))
			assert_true(projectile._velocity.y > 0.0)


func test_hold_indicator_delay_and_new_session_reset() -> void:
	var s := _create_actor()
	s.aim.begin_aim(s.throwing)
	s.input._aim_mouse_motion = -200.0
	s.aim._process(s.aim.config.hold_delay * 0.5)
	assert_false(s.aim.is_indicator_visible())
	assert_true(is_equal_approx(s.aim._angle, 5.0))
	s.aim._process(s.aim.config.hold_delay)
	assert_true(s.aim.is_indicator_visible())
	s.input._aim_mouse_motion = -100.0
	s.aim._process(0.0)
	assert_true(s.aim._angle > 5.0)
	s.aim.end_aim(s.throwing)
	assert_false(s.aim.is_indicator_visible())
	s.aim.begin_aim(s.throwing)
	assert_true(is_equal_approx(s.aim._angle, 5.0))


func test_held_launch_matches_indicator_for_every_weapon() -> void:
	for slot: int in [EquipmentComponent.Slot.THROWABLE, EquipmentComponent.Slot.BOW,
		EquipmentComponent.Slot.CROSSBOW, EquipmentComponent.Slot.MAGIC]:
		var s := _create_actor()
		preload("res://tests/AimingTestFactory.gd").select_weapon(s, slot)
		var ability: Component = _ability(s, slot)
		_press(s, slot)
		ability._process(0.0)
		s.aim._process(s.aim.config.hold_delay)
		s.input._vertical_axis = -1.0
		s.aim._process(0.5)
		s.input._move_axis = -1.0
		s.facing._physics_process(0.0)
		var direction: Vector2 = s.aim.get_direction()
		_release(s, slot)
		ability._process(0.0)
		var projectile := s.root.get_child(1) as ThrownProjectile
		assert_true(projectile._velocity.normalized().is_equal_approx(direction))
		assert_false(s.aim.is_indicator_visible())


func test_focus_pause_and_disable_cancel_without_spending() -> void:
	for notification: int in [Node.NOTIFICATION_PAUSED, Node.NOTIFICATION_APPLICATION_FOCUS_OUT, -1]:
		var s := _create_actor()
		s.equipment.equip(EquipmentComponent.Slot.THROWABLE)
		_press(s, EquipmentComponent.Slot.THROWABLE)
		s.throwing._process(0.0)
		assert_true(s.aim.get_locomotion_blocks() != 0)
		if notification == -1:
			s.aim.disable()
		else:
			s.aim._notification(notification)
		assert_false(s.aim.is_aiming())
		assert_eq(s.throwing.get_phase(), ThrowingComponent.Phase.NONE)
		assert_eq(s.throwing.get_remaining_charges(), 5)
		assert_eq(s.aim.get_locomotion_blocks(), 0)
		_release(s, EquipmentComponent.Slot.THROWABLE)
		s.throwing._process(0.0)
		assert_eq(s.root.get_child_count(), 1)


func test_cancel_and_equipment_change_clean_up_all_owners() -> void:
	for slot: int in [EquipmentComponent.Slot.THROWABLE, EquipmentComponent.Slot.BOW,
		EquipmentComponent.Slot.CROSSBOW, EquipmentComponent.Slot.MAGIC]:
		var s := _create_actor()
		preload("res://tests/AimingTestFactory.gd").select_weapon(s, slot)
		var ability: Component = _ability(s, slot)
		_press(s, slot)
		ability._process(0.0)
		s.input._guard_just_pressed = true
		ability._process(0.0)
		assert_false(s.aim.is_aiming())
		assert_eq(s.root.get_child_count(), 1)
		_press(s, slot)
		ability._process(0.0)
		s.equipment.unequip_item(ItemData.EquipSlot.MAIN_HAND)
		assert_false(s.aim.is_aiming())
		assert_eq(s.throwing.get_remaining_charges(), 5)
		assert_eq(s.ranged.get_arrow_count(), 20)
		assert_eq(s.ranged.get_bolt_count(), 12)
		assert_eq(s.magic.get_mana(), 100.0)


func test_ballistic_and_straight_projectiles_use_same_launch_vector() -> void:
	var s := _create_actor()
	var ballistic := track(ThrownProjectile.new()) as ThrownProjectile
	var straight := track(ThrownProjectile.new()) as ThrownProjectile
	var direction := Vector2(1.0, -1.0).normalized()
	ballistic.setup_direction(s.actor, direction, 100.0, 1.0, 0.0, 10.0, null, 100.0)
	straight.setup_direction(s.actor, direction, 100.0, 1.0, 0.0, 10.0)
	ballistic._physics_process(0.5)
	straight._physics_process(0.5)
	assert_true(is_equal_approx(ballistic.position.x, straight.position.x))
	assert_true(is_equal_approx(ballistic.position.y - straight.position.y, 12.5))
	assert_true(is_equal_approx(ballistic._velocity.y - straight._velocity.y, 50.0))


func test_projectile_spin_preserves_trajectory_and_zero_tracks_velocity() -> void:
	var profile := ItemProjectileProfile.new()
	assert_eq(profile.rotation_speed, 0.0)
	var direction := Vector2.RIGHT.rotated(-0.3)
	for spin: float in [0.0, 360.0, -360.0]:
		var projectile := track(ThrownProjectile.new()) as ThrownProjectile
		projectile.setup_direction(null, direction, 100.0, 1.0, 0.0, 10.0, null, 100.0, spin)
		projectile._physics_process(0.25)
		projectile._physics_process(0.25)
		assert_true(projectile.position.is_equal_approx(direction * 50.0 + Vector2(0.0, 12.5)))
		var expected := projectile._velocity.angle() if spin == 0.0 else direction.angle() + deg_to_rad(spin) * 0.5
		assert_true(is_equal_approx(angle_difference(projectile.rotation, expected), 0.0))


func test_throw_passes_item_rotation_speed_to_projectile() -> void:
	var s := _create_actor()
	var item := s.inventory.get_item_data(&"training_stone") as ItemData
	var original := item.projectile_profile
	item.projectile_profile = original.duplicate() as ItemProjectileProfile
	item.projectile_profile.rotation_speed = -720.0
	_press(s, EquipmentComponent.Slot.THROWABLE)
	_release(s, EquipmentComponent.Slot.THROWABLE)
	s.throwing._process(0.0)
	item.projectile_profile = original
	assert_eq(s.root.get_child_count(), 2)
	var projectile := s.root.get_child(1) as ThrownProjectile
	var initial := projectile.rotation
	projectile._physics_process(0.125)
	assert_true(is_equal_approx(angle_difference(projectile.rotation, initial - PI / 2.0), 0.0))


func _press(s: Dictionary, slot: int) -> void:
	if slot == EquipmentComponent.Slot.THROWABLE:
		s.input._interact_pressed = true
	else:
		s.input._attack_just_pressed = true


func test_last_throwable_spends_inventory_and_preserves_held_weapon() -> void:
	var s := _create_actor()
	var mode: int = s.equipment.get_current_slot()
	var weapon: ItemData = s.equipment.get_equipped_item(ItemData.EquipSlot.MAIN_HAND)
	s.inventory.remove_item(&"training_stone", 4)
	_press(s, EquipmentComponent.Slot.THROWABLE)
	_release(s, EquipmentComponent.Slot.THROWABLE)
	s.throwing._process(0.0)
	assert_eq(s.inventory.get_quantity(&"training_stone"), 0)
	assert_eq(s.root.get_child_count(), 2)
	assert_eq(s.throwing.get_phase(), ThrowingComponent.Phase.ACTION)
	assert_false(s.aim.is_aiming())
	assert_eq(s.quick.get_active_slot(), 0)
	assert_eq(s.equipment.get_current_slot(), mode)
	assert_eq(s.equipment.get_equipped_item(ItemData.EquipSlot.MAIN_HAND), weapon)


func test_last_arrow_fires_once_then_empty_ammo_blocks_aim() -> void:
	var s := _create_actor()
	s.inventory.remove_item(&"training_arrows", 19)
	_press(s, EquipmentComponent.Slot.BOW)
	_release(s, EquipmentComponent.Slot.BOW)
	s.ranged._process(0.0)
	assert_eq(s.inventory.get_quantity(&"training_arrows"), 0)
	assert_eq(s.root.get_child_count(), 2)
	assert_eq(s.ranged.get_phase(), RangedWeaponComponent.Phase.BOW_LOOSE)
	s.ranged._process(1.0)
	_press(s, EquipmentComponent.Slot.BOW)
	s.ranged._process(0.0)
	assert_false(s.aim.is_aiming())
	assert_eq(s.root.get_child_count(), 2)


func test_dropping_ammo_or_switching_quick_slot_cancels_without_shot() -> void:
	var s := _create_actor()
	_press(s, EquipmentComponent.Slot.BOW)
	s.ranged._process(0.0)
	s.inventory.remove_item(&"training_arrows", 20)
	assert_false(s.aim.is_aiming())
	_release(s, EquipmentComponent.Slot.BOW)
	s.ranged._process(0.0)
	assert_eq(s.root.get_child_count(), 1)
	_press(s, EquipmentComponent.Slot.THROWABLE)
	s.throwing._process(0.0)
	s.quick.activate_slot(0)
	assert_false(s.aim.is_aiming())
	_release(s, EquipmentComponent.Slot.THROWABLE)
	s.throwing._process(0.0)
	assert_eq(s.inventory.get_quantity(&"training_stone"), 5)
	assert_eq(s.root.get_child_count(), 1)


func test_save_uses_inventory_and_accepts_legacy_counters() -> void:
	var s := _create_actor()
	var codec := preload("res://features/save/PlayerSaveData.gd").new()
	var state: Dictionary = codec.capture(s.actor)
	assert_false(state.has("ranged"))
	assert_false(state.has("throwing"))
	assert_true(codec.validate(state))
	state["ranged"] = {"arrows": 999, "bolts": 999}
	state["throwing"] = 999
	assert_true(codec.validate(state))
	codec.restore(s.actor, state)
	assert_eq(s.inventory.get_quantity(&"training_arrows"), 20)
	assert_eq(s.inventory.get_quantity(&"training_stone"), 5)


func test_gamepad_bindings_and_mouse_deltas_are_available() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		var found := false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion:
				found = true
		assert_true(found, String(action))
	var s := _create_actor()
	s.input._aim_mouse_motion = -25.0
	assert_eq(s.input.consume_aim_mouse_motion(), -25.0)
	assert_eq(s.input.consume_aim_mouse_motion(), 0.0)


func test_melee_guard_does_not_swallow_throw_cancel() -> void:
	var s := _create_actor()
	var sword := preload("res://game/items/weapons/TrainingSword.tres") as ItemData
	s.inventory.add_item(sword)
	s.equipment.equip_inventory_item(sword.id, ItemData.EquipSlot.MAIN_HAND)
	var guard := track(GuardComponent.new()) as GuardComponent
	guard.config = GuardConfig.new()
	guard.initialize(s.actor)
	assert_true(guard.start_guard())
	guard.stop_guard()
	_press(s, EquipmentComponent.Slot.THROWABLE)
	s.throwing._process(0.0)
	assert_true(s.aim.is_aiming())
	s.input._guard_just_pressed = true
	guard._process(0.0)
	s.throwing._process(0.0)
	assert_false(s.aim.is_aiming())
	assert_false(guard.is_parrying())
	assert_eq(s.inventory.get_quantity(&"training_stone"), 5)


func _release(s: Dictionary, slot: int) -> void:
	if slot == EquipmentComponent.Slot.THROWABLE:
		s.input._interact_released = true
	else:
		s.input._attack_released = true


func _ability(s: Dictionary, slot: int) -> Component:
	if slot == EquipmentComponent.Slot.THROWABLE:
		return s.throwing
	if slot == EquipmentComponent.Slot.MAGIC:
		return s.magic
	return s.ranged


func _create_actor() -> Dictionary:
	var setup := preload("res://tests/AimingTestFactory.gd").create()
	track(setup.root)
	return setup
