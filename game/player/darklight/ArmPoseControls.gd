@tool
extends Node2D
## Rotate Shoulder, Shoulder/Elbow and Shoulder/Elbow/Wrist in FK mode.
## Positions follow bone pivots; these controls do not stretch the arm.

enum Mode { IK, FK }

@export var mode: Mode = Mode.IK:
	set(value):
		mode = value
		_update_solver_ownership()

@export var shoulder_bone: Bone2D
@export var elbow_bone: Bone2D
@export var wrist_bone: Bone2D
@export var arm_ik: SoupTwoBoneIK
@export var wrist_ik: SoupLookAt


func _ready() -> void:
	_update_solver_ownership()
	_process(0.0)


func _update_solver_ownership() -> void:
	if is_instance_valid(arm_ik):
		arm_ik.enabled = mode == Mode.IK
	if is_instance_valid(wrist_ik):
		wrist_ik.enabled = mode == Mode.IK
	_update_native_solver_ownership()


## A rig that replaces SoupIK with Godot's own solvers (DarklightRig2) must follow
## the same ownership rule: while this control poses the arm in FK, the native
## two-bone IK and look-at that drive the same bones are switched off, so the pose
## is the only writer instead of racing the solvers every frame.
func _update_native_solver_ownership() -> void:
	var skeleton := _find_skeleton()
	if skeleton == null:
		return
	var stack: SkeletonModificationStack2D = skeleton.get_modification_stack()
	if stack == null:
		return
	var owned := {}
	for bone: Bone2D in [shoulder_bone, elbow_bone, wrist_bone]:
		if is_instance_valid(bone):
			owned[skeleton.get_path_to(bone)] = true
	for index in stack.get_modification_count():
		var modification := stack.get_modification(index)
		if modification != null and _drives_owned_bone(modification, owned):
			modification.enabled = mode == Mode.IK


func _find_skeleton() -> Skeleton2D:
	if not is_instance_valid(shoulder_bone):
		return null
	var current := shoulder_bone.get_parent()
	while current != null:
		if current is Skeleton2D:
			return current as Skeleton2D
		current = current.get_parent()
	return null


func _drives_owned_bone(modification: SkeletonModification2D, owned: Dictionary) -> bool:
	var two_bone := modification as SkeletonModification2DTwoBoneIK
	if two_bone != null:
		return (
			owned.has(two_bone.get_joint_one_bone2d_node())
			or owned.has(two_bone.get_joint_two_bone2d_node())
		)
	var look := modification as SkeletonModification2DLookAt
	if look != null:
		return owned.has(look.get_bone2d_node())
	return false


func _process(_delta: float) -> void:
	if not is_instance_valid(shoulder_bone) or not is_instance_valid(elbow_bone) or not is_instance_valid(wrist_bone):
		return
	var shoulder := get_node_or_null("Shoulder") as Marker2D
	var elbow := get_node_or_null("Shoulder/Elbow") as Marker2D
	var wrist := get_node_or_null("Shoulder/Elbow/Wrist") as Marker2D
	if shoulder == null or elbow == null or wrist == null:
		return
	# Use the same parent space as the bones, including hip animation and facing.
	global_transform = (shoulder_bone.get_parent() as Node2D).global_transform
	shoulder.position = shoulder_bone.position
	elbow.position = elbow_bone.position
	wrist.position = wrist_bone.position
	if mode == Mode.FK:
		shoulder_bone.rotation = shoulder.rotation
		elbow_bone.rotation = elbow.rotation
		wrist_bone.rotation = wrist.rotation
