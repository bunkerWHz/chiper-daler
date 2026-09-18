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
