@tool
extends McpTestSuite

## Structural contract of the SoupIK-free rig copy.
##
## DarklightRig2.tscn replaces all nine SoupIK solvers with native
## SkeletonModification2D nodes and carries no SoupGroup subtree at all.
## Behavioural equivalence with DarklightRig.tscn is established by pose
## comparison; these tests guard the wiring that makes it possible: the soupik
## nodes are gone, the native stack covers every one of them in the same order,
## and the serialized bone indices still match the skeleton they were authored
## against.

const RIG2_PATH := "res://game/player/darklight/DarklightRig2.tscn"

## Solver layout of the canonical DarklightRig.tscn; the copy must not have it.
const SOUPIK_SOLVER_PATHS: Array[String] = [
	"CharacterContainer/Skeleton2D/SoupGroup",
	"CharacterContainer/Skeleton2D/SoupGroup/Head/Head_AT",
	"CharacterContainer/Skeleton2D/SoupGroup/UpperBody/FrontArmIK",
	"CharacterContainer/Skeleton2D/SoupGroup/UpperBody/BackArmIK",
	"CharacterContainer/Skeleton2D/SoupGroup/UpperBody/FrontArmAT",
	"CharacterContainer/Skeleton2D/SoupGroup/UpperBody/BackArmAt",
	"CharacterContainer/Skeleton2D/SoupGroup/LowerBody/FrontLegIK",
	"CharacterContainer/Skeleton2D/SoupGroup/LowerBody/FrontLeg_AT",
	"CharacterContainer/Skeleton2D/SoupGroup/LowerBody/BackLegIK",
	"CharacterContainer/Skeleton2D/SoupGroup/LowerBody/BackLeg_AT",
]

## [kind, bone/joint_one, joint_two, target, flip_bend_direction]
const MODIFICATIONS: Array = [
	["look_at", "Hip/Torso/Head", "", "../Anim Targets/Head_AT", false],
	["two_bone", "Hip/FrontArmTop", "Hip/FrontArmTop/FrontArmMid", "../Anim Targets/FrontArmIK", true],
	["two_bone", "Hip/BackArmTop", "Hip/BackArmTop/BackArmMid", "../Anim Targets/BackArmIK", true],
	["look_at", "Hip/FrontArmTop/FrontArmMid/FrontArmBot", "", "../Anim Targets/FrontArmIK/FrontArm_AT", false],
	["look_at", "Hip/BackArmTop/BackArmMid/BackArmBot", "", "../Anim Targets/BackArmIK/BackArm_AT", false],
	["two_bone", "Hip/FrontLegTop", "Hip/FrontLegTop/FrontLegMid", "../Anim Targets/FrontLegIK", false],
	["look_at", "Hip/FrontLegTop/FrontLegMid/FrontLegBot", "", "../Anim Targets/FrontLegIK/FrontLeg_AT", false],
	["two_bone", "Hip/BackLegTop", "Hip/BackLegTop/BackLegMid", "../Anim Targets/BackLegIK", false],
	["look_at", "Hip/BackLegTop/BackLegMid/BackLegBot", "", "../Anim Targets/BackLegIK/BackLeg_AT", false],
]


func suite_name() -> String:
	return "darklight_rig2_ik"


func _open_rig() -> Node2D:
	var rig := track(load(RIG2_PATH).instantiate()) as Node2D
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	return rig


func test_the_copy_carries_no_soupik_nodes() -> void:
	var rig := _open_rig()
	for path: String in SOUPIK_SOLVER_PATHS:
		assert_true(rig.get_node_or_null(path) == null, "DarklightRig2 still carries the soupik node " + path)


func test_arm_pose_controls_no_longer_own_the_soupik_solvers() -> void:
	var rig := _open_rig()
	for side: String in ["Front", "Back"]:
		var controls := rig.get_node("CharacterContainer/Anim Targets/" + side + "ArmFK")
		assert_true(controls.arm_ik == null, side + "ArmFK still disables a soupik solver")
		assert_true(controls.wrist_ik == null, side + "ArmFK still disables a soupik solver")


func test_native_stack_replaces_every_solver_in_order() -> void:
	var rig := _open_rig()
	var skeleton := rig.get_node("CharacterContainer/Skeleton2D") as Skeleton2D
	var stack: SkeletonModificationStack2D = skeleton.get_modification_stack()
	assert_true(stack != null, "DarklightRig2 has no modification stack")
	if stack == null:
		return
	assert_eq(stack.get_modification_count(), MODIFICATIONS.size(), "wrong modification count")
	for index in MODIFICATIONS.size():
		var expected: Array = MODIFICATIONS[index]
		var modification: SkeletonModification2D = stack.get_modification(index)
		assert_true(modification != null, "missing modification %d" % index)
		if modification == null:
			continue
		if String(expected[0]) == "look_at":
			var look := modification as SkeletonModification2DLookAt
			assert_true(look != null, "modification %d is not a LookAt" % index)
			if look == null:
				continue
			assert_eq(String(look.get_target_node()), String(expected[3]), "wrong target on modification %d" % index)
			assert_eq(String(look.get_bone2d_node()), String(expected[1]), "wrong bone on modification %d" % index)
		else:
			var two_bone := modification as SkeletonModification2DTwoBoneIK
			assert_true(two_bone != null, "modification %d is not a TwoBoneIK" % index)
			if two_bone == null:
				continue
			assert_eq(String(two_bone.get_target_node()), String(expected[3]), "wrong target on modification %d" % index)
			assert_eq(String(two_bone.get_joint_one_bone2d_node()), String(expected[1]), "wrong first joint on modification %d" % index)
			assert_eq(String(two_bone.get_joint_two_bone2d_node()), String(expected[2]), "wrong second joint on modification %d" % index)
			assert_eq(two_bone.get_flip_bend_direction(), bool(expected[4]), "flip_bend_direction differs from soupik on modification %d (got %s)" % [index, str(two_bone.get_flip_bend_direction())])


func test_every_modification_resolves_against_the_live_skeleton() -> void:
	var rig := _open_rig()
	var skeleton := rig.get_node("CharacterContainer/Skeleton2D") as Skeleton2D
	var stack: SkeletonModificationStack2D = skeleton.get_modification_stack()
	assert_true(stack != null, "DarklightRig2 has no modification stack")
	if stack == null:
		return
	for index in MODIFICATIONS.size():
		var modification: SkeletonModification2D = stack.get_modification(index)
		if modification == null:
			continue
		var look := modification as SkeletonModification2DLookAt
		if look != null:
			var target := skeleton.get_node_or_null(look.get_target_node()) as Node2D
			assert_true(target != null, "modification %d targets a node that does not resolve" % index)
			var bone := skeleton.get_node_or_null(look.get_bone2d_node()) as Bone2D
			assert_true(bone != null, "modification %d bone does not resolve" % index)
			if bone == null:
				continue
			assert_eq(bone.get_index_in_skeleton(), look.get_bone_index(), "stale bone index on modification %d" % index)
			continue
		var two_bone := modification as SkeletonModification2DTwoBoneIK
		if two_bone == null:
			continue
		var two_target := skeleton.get_node_or_null(two_bone.get_target_node()) as Node2D
		assert_true(two_target != null, "modification %d targets a node that does not resolve" % index)
		var joint_one := skeleton.get_node_or_null(two_bone.get_joint_one_bone2d_node()) as Bone2D
		var joint_two := skeleton.get_node_or_null(two_bone.get_joint_two_bone2d_node()) as Bone2D
		assert_true(joint_one != null and joint_two != null, "modification %d joints do not resolve" % index)
		if joint_one == null or joint_two == null:
			continue
		assert_eq(joint_one.get_index_in_skeleton(), two_bone.get_joint_one_bone_idx(), "stale first joint index on modification %d" % index)
		assert_eq(joint_two.get_index_in_skeleton(), two_bone.get_joint_two_bone_idx(), "stale second joint index on modification %d" % index)
