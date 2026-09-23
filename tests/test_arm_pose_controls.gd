@tool
extends McpTestSuite


func suite_name() -> String:
	return "arm_pose_controls"


func test_hip_control_moves_bone_and_fk_arms_in_both_facings() -> void:
	var rig := track(load("res://game/player/darklight/DarklightRig.tscn").instantiate()) as Node2D
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	var hip := rig.get_node("CharacterContainer/Skeleton2D/Hip") as Bone2D
	var control := rig.get_node("CharacterContainer/Anim Targets/Hip") as Marker2D
	var arm = rig.get_node("CharacterContainer/Anim Targets/BackArmFK")
	arm.mode = 1
	for facing in [1.0, -1.0]:
		rig.scale.x = facing
		control.rotation = 0.0
		(control.get_node("BoneTransform") as RemoteTransform2D).force_update_transform()
		arm._process(0.0)
		var before: Vector2 = arm.wrist_bone.global_position
		control.rotation = 0.4
		control.position = Vector2(12, 140)
		(control.get_node("BoneTransform") as RemoteTransform2D).force_update_cache()
		(control.get_node("BoneTransform") as RemoteTransform2D).force_update_transform()
		arm._process(0.0)
		assert_true(is_equal_approx(hip.rotation, control.rotation))
		assert_true(hip.position.distance_to(control.position) < 0.01)
		assert_true(before.distance_to(arm.wrist_bone.global_position) > 10.0)
		assert_true(hip.scale.is_equal_approx(Vector2.ONE))
	var animation := rig.get_node("AnimationPlayer") as AnimationPlayer
	animation.play("RESET")
	animation.advance(0.0)
	assert_true(is_zero_approx(control.rotation))
	assert_true(control.position.is_equal_approx(Vector2(0, 136)))
	for clip_name in animation.get_animation_list():
		var clip := animation.get_animation(clip_name)
		for index in clip.get_track_count():
			assert_false(str(clip.track_get_path(index)).begins_with("CharacterContainer/Skeleton2D/Hip:"))


func test_fk_chain_and_ik_ownership_on_both_sides_and_facings() -> void:
	var rig := track(load("res://game/player/darklight/DarklightRig.tscn").instantiate()) as Node2D
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	for side in ["Back", "Front"]:
		var controls = rig.get_node("CharacterContainer/Anim Targets/" + side + "ArmFK")
		assert_true(controls.arm_ik.enabled)
		assert_true(controls.wrist_ik.enabled)
		controls.mode = 1
		assert_false(controls.arm_ik.enabled)
		assert_false(controls.wrist_ik.enabled)
		var shoulder := controls.get_node("Shoulder") as Marker2D
		var elbow := controls.get_node("Shoulder/Elbow") as Marker2D
		var wrist := controls.get_node("Shoulder/Elbow/Wrist") as Marker2D
		for facing in [1.0, -1.0]:
			rig.scale.x = facing
			shoulder.rotation = 0.3
			elbow.rotation = -0.5
			wrist.rotation = 0.2
			controls._process(0.0)
			var before: Vector2 = controls.wrist_bone.global_position
			elbow.rotation += 0.4
			controls._process(0.0)
			assert_true(before.distance_to(controls.wrist_bone.global_position) > 10.0)
			assert_true(wrist.global_position.distance_to(controls.wrist_bone.global_position) < 0.01)
			controls.arm_ik._process_loop(0.0)
			controls.wrist_ik._process_loop(0.0)
			assert_true(is_equal_approx(controls.elbow_bone.rotation, elbow.rotation))
			assert_true(is_equal_approx(controls.wrist_bone.rotation, wrist.rotation))
			before = controls.wrist_bone.global_position
			shoulder.rotation += 0.4
			controls._process(0.0)
			assert_true(before.distance_to(controls.wrist_bone.global_position) > 10.0)
		controls.mode = 0
		assert_true(controls.arm_ik.enabled)
		assert_true(controls.wrist_ik.enabled)


func test_reset_returns_both_arms_to_ik() -> void:
	var rig := track(load("res://game/player/darklight/DarklightRig.tscn").instantiate()) as Node2D
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	var animation := rig.get_node("AnimationPlayer") as AnimationPlayer
	for side in ["Back", "Front"]:
		var controls = rig.get_node("CharacterContainer/Anim Targets/" + side + "ArmFK")
		controls.mode = 1
		controls.get_node("Shoulder/Elbow").rotation = 0.8
	animation.play("RESET")
	animation.advance(0.0)
	for side in ["Back", "Front"]:
		var controls = rig.get_node("CharacterContainer/Anim Targets/" + side + "ArmFK")
		assert_eq(controls.mode, 0)
		assert_true(controls.arm_ik.enabled)
		assert_true(controls.wrist_ik.enabled)
		assert_eq(controls.get_node("Shoulder/Elbow").rotation, 0.0)


## DarklightRig2 has no SoupIK, so the same FK ownership rule has to switch off
## the native modifications that drive the arm's bones instead.
func test_native_rig_switches_off_its_arm_solvers_in_fk() -> void:
	var rig := track(load("res://game/player/darklight/DarklightRig2.tscn").instantiate()) as Node2D
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	var skeleton := rig.get_node("CharacterContainer/Skeleton2D") as Skeleton2D
	var stack: SkeletonModificationStack2D = skeleton.get_modification_stack()
	assert_true(stack != null)
	for side in ["Back", "Front"]:
		var controls = rig.get_node("CharacterContainer/Anim Targets/" + side + "ArmFK")
		var owned: Array = _arm_modifications(stack, skeleton, controls)
		assert_eq(owned.size(), 2, side + " arm must be driven by a two-bone IK and a look-at")
		for modification: SkeletonModification2D in owned:
			assert_true(modification.enabled)
		controls.mode = 1
		for modification: SkeletonModification2D in owned:
			assert_false(modification.enabled, side + " arm solvers must yield to the FK pose")
		controls.mode = 0
		for modification: SkeletonModification2D in owned:
			assert_true(modification.enabled)


func _arm_modifications(stack: SkeletonModificationStack2D, skeleton: Skeleton2D, controls: Node) -> Array:
	var bones := {}
	for bone: Bone2D in [controls.shoulder_bone, controls.elbow_bone, controls.wrist_bone]:
		bones[skeleton.get_path_to(bone)] = true
	var found: Array = []
	for index in stack.get_modification_count():
		var modification := stack.get_modification(index)
		var two_bone := modification as SkeletonModification2DTwoBoneIK
		if two_bone != null:
			if (bones.has(two_bone.get_joint_one_bone2d_node())
				or bones.has(two_bone.get_joint_two_bone2d_node())):
				found.append(modification)
			continue
		var look := modification as SkeletonModification2DLookAt
		if look != null and bones.has(look.get_bone2d_node()):
			found.append(modification)
	return found
