extends SceneTree

## Guards the claim that DarklightRig2 is DarklightRig with only the IK solvers
## swapped: the same clips, driven into both rigs, must produce the same pose.
##
## The copy went through several hands — disabled soupik nodes, then a full
## removal of the SoupGroup subtree, plus hand-authored bone indices for the
## native stack — and every one of those is the kind of change that silently
## swaps an elbow to the other branch without moving the hand off its target.
## Comparing only the reached targets would miss it, so this samples every bone.
##
## Usage: godot --headless --path . --script tests/darklight_rig2_pose_check.gd

const SOUPIK_RIG := "res://game/player/darklight/DarklightRig.tscn"
const NATIVE_RIG := "res://game/player/darklight/DarklightRig2.tscn"

const BONES: Array[String] = [
	"Hip",
	"Hip/BackLegTop",
	"Hip/BackLegTop/BackLegMid",
	"Hip/BackLegTop/BackLegMid/BackLegBot",
	"Hip/FrontLegTop",
	"Hip/FrontLegTop/FrontLegMid",
	"Hip/FrontLegTop/FrontLegMid/FrontLegBot",
	"Hip/FrontArmTop",
	"Hip/FrontArmTop/FrontArmMid",
	"Hip/FrontArmTop/FrontArmMid/FrontArmBot",
	"Hip/BackArmTop",
	"Hip/BackArmTop/BackArmMid",
	"Hip/BackArmTop/BackArmMid/BackArmBot",
	"Hip/Torso",
	"Hip/Torso/Head",
]

const SAMPLES_PER_CLIP := 5
const TOLERANCE := 0.05
const COMPONENTS: Array[String] = ["position.x", "position.y", "rotation"]


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _sample(rig: Node) -> Array:
	var skeleton := rig.get_node("CharacterContainer/Skeleton2D")
	var values := []
	for bone_path: String in BONES:
		var bone := skeleton.get_node(bone_path) as Node2D
		values.append(bone.global_position.x)
		values.append(bone.global_position.y)
		values.append(bone.global_rotation)
	return values


func _compare(label: String, soupik: Node, native: Node, worst: Array) -> bool:
	var left := _sample(soupik)
	var right := _sample(native)
	for index in left.size():
		var delta: float = absf(float(left[index]) - float(right[index]))
		if delta > float(worst[0]):
			worst[0] = delta
			worst[1] = "%s %s.%s" % [label, BONES[index / 3], COMPONENTS[index % 3]]
		if delta > TOLERANCE:
			_fail("DarklightRig2 diverged from DarklightRig: %s %s.%s soupik=%.4f native=%.4f delta=%.4f" % [
				label, BONES[index / 3], COMPONENTS[index % 3], left[index], right[index], delta,
			])
			return false
	return true


func _run() -> void:
	var soupik := load(SOUPIK_RIG).instantiate() as Node2D
	var native := load(NATIVE_RIG).instantiate() as Node2D
	if soupik == null or native == null:
		_fail("Cannot instantiate both rigs")
		return
	root.add_child(soupik)
	root.add_child(native)

	if native.get_node_or_null("CharacterContainer/Skeleton2D/SoupGroup") != null:
		_fail("DarklightRig2 still carries the soupik SoupGroup subtree")
		return

	var soupik_player := soupik.get_node("AnimationPlayer") as AnimationPlayer
	var native_player := native.get_node("AnimationPlayer") as AnimationPlayer
	var clips := soupik_player.get_animation_list()
	clips.sort()

	var worst := [0.0, ""]
	var checks := 0
	for clip: StringName in clips:
		var length := soupik_player.get_animation(clip).length
		if length <= 0.0:
			continue
		for step in SAMPLES_PER_CLIP:
			var time := length * float(step) / float(SAMPLES_PER_CLIP)
			soupik_player.play(clip)
			soupik_player.seek(time, true)
			soupik_player.pause()
			native_player.play(clip)
			native_player.seek(time, true)
			native_player.pause()
			await process_frame
			await process_frame
			checks += 1
			if not _compare("%s@%.3f" % [clip, time], soupik, native, worst):
				return

	# The gameplay rig is mirrored as a whole for left facing, which makes the
	# skeleton's determinant negative. Both solver families must survive it.
	var mirror := Transform2D(Vector2(-1, 0), Vector2.DOWN, Vector2.ZERO)
	soupik.get_node("CharacterContainer").transform = mirror
	native.get_node("CharacterContainer").transform = mirror
	soupik_player.play(&"idle")
	soupik_player.seek(0.0, true)
	soupik_player.pause()
	native_player.play(&"idle")
	native_player.seek(0.0, true)
	native_player.pause()
	await process_frame
	await process_frame
	checks += 1
	if not _compare("idle@mirrored", soupik, native, worst):
		return

	if worst[0] > TOLERANCE:
		_fail("DarklightRig2 diverged: worst %.4f at %s" % [worst[0], worst[1]])
		return
	print("DarklightRig2 poses: PASS (%d poses over %d clips, worst deviation %.4f at %s)" % [
		checks, clips.size(), worst[0], worst[1],
	])
	quit(0)
