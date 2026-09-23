@tool
extends Skeleton2D
## Restores the authored unit scale of every bone the native solvers rotate.
##
## DarklightRig2 replaces SoupIK with Godot's own SkeletonModification2D nodes.
## SkeletonModification2DTwoBoneIK and SkeletonModification2DLookAt leave a
## residual scale (about 1e-7 per frame) on the bones they write, and it
## compounds: attached sprites inherit it through their RemoteTransform2D, so the
## hero slowly shrinks — about 0.02% after a minute, and the residue never
## settles. SoupIK, the solver the canonical rig keeps, leaves no such residue.
##
## The script sits on Skeleton2D itself: the node executes its modification stack
## before its own `_process`, so the authored scale is restored before the frame
## is drawn. It is generated into DarklightRig2.tscn by
## tests/regenerate_darklight_rig2.mjs, which also assigns it to the Skeleton2D
## node; the canonical rig keeps SoupIK and needs no guard.

var _bones: Array[Bone2D] = []


func _ready() -> void:
	process_priority = 1
	_collect_solved_bones()


func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	for bone: Bone2D in _bones:
		# Exact comparison on purpose: is_equal_approx tolerates a residue of 1e-5
		# and would let every attachment inherit it.
		if is_instance_valid(bone) and bone.scale != Vector2.ONE:
			bone.scale = Vector2.ONE


func _collect_solved_bones() -> void:
	_bones.clear()
	var stack: SkeletonModificationStack2D = get_modification_stack()
	if stack == null:
		return
	for index in stack.get_modification_count():
		var modification := stack.get_modification(index)
		if modification == null:
			continue
		var two_bone := modification as SkeletonModification2DTwoBoneIK
		if two_bone != null:
			_append_bone(two_bone.get_joint_one_bone2d_node())
			_append_bone(two_bone.get_joint_two_bone2d_node())
			continue
		var look := modification as SkeletonModification2DLookAt
		if look != null:
			_append_bone(look.get_bone2d_node())


func _append_bone(path: NodePath) -> void:
	var bone := get_node_or_null(path) as Bone2D
	if bone != null and bone not in _bones:
		_bones.append(bone)
