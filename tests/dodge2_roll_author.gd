extends SceneTree
## Authoring and verification tool for Darklight's `dodge2` tucked forward roll.
##
## Run from the project root (a window is needed: the headless display server
## has no renderer):
##   godot --script tests/dodge2_roll_author.gd              # write the clip, verify it
##   godot --script tests/dodge2_roll_author.gd -- sheet      # also render a review sheet
##   godot --script tests/dodge2_roll_author.gd -- sweep      # compare tuck candidates
##   godot --headless --script tests/dodge2_roll_author.gd -- sweep
##
## Why the roll is generated: the rig only exposes the pelvis
## (`Anim Targets/Hip`) plus IK and look-at targets, so a tumble means rotating
## every target around the pelvis by the same roll angle. Each target is stored
## here as a pelvis-relative offset, rotated by the roll angle.
##
## Why the pelvis is placed from the framebuffer: the silhouette is sprites plus
## skinned limb polygons plus the cloak, and only the renderer knows where the
## skinned pieces land. Moving the pelvis translates the whole silhouette, so one
## rendered measurement per key gives the exact height at which the lowest lit
## pixel touches the ground line measured from the idle pose.

const RIG_PATH := "res://game/player/darklight/DarklightRig.tscn"
const CLIP_PATH := "res://game/player/darklight/animations/dodge2.tres"
const SHEET_PATH := "res://.godot/dodge2_preview_sheet.png"

const CONTAINER := "CharacterContainer/"
const HIP_PATH := CONTAINER + "Anim Targets/Hip"
const TARGET_PATHS := {
	"front_leg": CONTAINER + "Anim Targets/FrontLegIK",
	"back_leg": CONTAINER + "Anim Targets/BackLegIK",
	"front_arm": CONTAINER + "Anim Targets/FrontArmIK",
	"back_arm": CONTAINER + "Anim Targets/BackArmIK",
	"head": CONTAINER + "Anim Targets/Head_AT",
}
const AT_PATHS := {
	"front_leg": TARGET_PATHS["front_leg"] + "/FrontLeg_AT",
	"back_leg": TARGET_PATHS["back_leg"] + "/BackLeg_AT",
	"front_arm": TARGET_PATHS["front_arm"] + "/FrontArm_AT",
	"back_arm": TARGET_PATHS["back_arm"] + "/BackArm_AT",
}

# --- clip shape ---------------------------------------------------------
const LENGTH := 0.4
const STEP := 0.01
const TIP_END := 0.070
const TIP_DEGREES := 42.0
const ROLL_END := 0.330
const ROLL_DEGREES := 318.0
const TUCK_IN_END := 0.075
const TUCK_OUT_START := 0.305
const LEAN_PEAK := 46.0

# --- poses --------------------------------------------------------------
# Pelvis-relative target offsets. The standing pose repeats the idle artwork,
# the tuck folds every limb onto the torso so the silhouette becomes a ball.
const STAND := {
	"front_leg": Vector2(-190, 316),
	"back_leg": Vector2(90, 305),
	"front_arm": Vector2(-172, 19),
	"back_arm": Vector2(184, -40),
	"head": Vector2(342, -284),
}
const STAND_AT := {
	"front_leg": Vector2(184, 3),
	"back_leg": Vector2(111, 3),
	"front_arm": Vector2(95, -13),
	"back_arm": Vector2(9, 0),
}
const TUCK := {
	"front_leg": Vector2(-58, 120),
	"back_leg": Vector2(34, 138),
	"front_arm": Vector2(24, -244),
	"back_arm": Vector2(-18, -168),
	# Head bone (0,-269) plus 300 units straight down the tucked chin.
	"head": Vector2(0, 31),
}
const TUCK_AT := {
	"front_leg": Vector2(120, -44),
	"back_leg": Vector2(104, -28),
	"front_arm": Vector2(56, 40),
	"back_arm": Vector2(34, 52),
}

var _rig: Node2D
var _player: AnimationPlayer
var _animation := Animation.new()
var _ground := 0.0
var _camera: Camera2D
var _viewport: SubViewport
var _zoom := 1.0
var _frame_size := Vector2(1280, 720)
var _rendered := true
var _lit_bounds := Vector4.ZERO
var _hull_cache: Dictionary = {}
var _args: PackedStringArray = []


func _initialize() -> void:
	_args = OS.get_cmdline_user_args()
	call_deferred("_run")


func _run() -> void:
	_rig = (load(RIG_PATH) as PackedScene).instantiate() as Node2D
	root.add_child(_rig)
	_rig.position = Vector2(600, 600)
	_rig.scale = Vector2.ONE
	_player = _rig.get_node("AnimationPlayer") as AnimationPlayer
	_player.stop()
	_rendered = DisplayServer.get_name() != "headless"
	if _rendered:
		await _setup_camera()
	await _settle()
	_ground = await _measure_ground()
	print("ground line (rig units): %.1f%s" % [_ground, "" if _rendered else "  [sprites only: no renderer]"])
	if "sweep" in _args:
		await _sweep()
		_quit()
		return
	if "frames" in _args:
		var saved := load(CLIP_PATH) as Animation
		if saved != null:
			_player.get_animation_library(&"").add_animation(&"dodge2", saved)
		await _ascii_roll()
		_quit()
		return
	if "measure" in _args:
		await _measure_clips()
		_quit()
		return
	if "probe" in _args:
		await _probe_rigidity()
		_quit()
		return
	var samples := _roll_samples()
	for sample: Dictionary in samples:
		sample["hip"] = await _place_pelvis(sample)
	_build_clip(samples)
	var library := _player.get_animation_library(&"")
	if library.has_animation(&"dodge2"):
		library.remove_animation(&"dodge2")
	library.add_animation(&"dodge2", _animation)
	if "report" not in _args:
		var error := ResourceSaver.save(_animation, CLIP_PATH)
		print("saved %s -> %s" % [CLIP_PATH, error_string(error)])
	await _report()
	if "sheet" in _args:
		await _render_sheet()
	_quit()


func _quit() -> void:
	_rig.queue_free()
	await process_frame
	quit()


func _settle() -> void:
	await process_frame
	await physics_frame
	await process_frame


## Frames the whole tumble, with margin for the head sweep and the cloak.
## Rendering goes to an offscreen viewport: the window's swapchain returns frames
## a few frames late, which would place every key against the previous pose.
func _setup_camera() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(960, 540)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_camera = Camera2D.new()
	_camera.position = _rig.position + Vector2(38, -230)
	_viewport.add_child(_camera)
	root.remove_child(_rig)
	_viewport.add_child(_rig)
	_camera.make_current()
	_frame_size = Vector2(_viewport.size)
	_zoom = minf(_frame_size.x / 1900.0, _frame_size.y / 2400.0)
	_camera.zoom = Vector2(_zoom, _zoom)
	await process_frame


# --- floor contact ------------------------------------------------------


## The idle pose defines where the artwork meets the floor.
func _measure_ground() -> float:
	if not _rendered:
		_player.play(&"RESET")
		_player.advance(0.0)
		_player.play(&"idle")
		_player.advance(0.0)
		_player.pause()
		await _settle()
		var lowest := _sprite_silhouette().end.y
		_player.stop()
		return lowest
	_player.play(&"RESET")
	_player.advance(0.0)
	_player.play(&"idle")
	_player.advance(0.0)
	_player.pause()
	await _settle()
	var rig_y := await _lowest_lit_rig_y()
	_player.stop()
	return rig_y


## Poses the sample and returns the pelvis position that rests it on the floor.
func _place_pelvis(sample: Dictionary) -> Vector2:
	_set_cloak_visible(false)
	var probe := sample.duplicate()
	probe["hip"] = Vector2(sample["lean"], 0.0)
	_apply_pose(probe)
	await _settle()
	var lowest := 0.0
	if _rendered:
		lowest = await _rendered_lowest(probe)
	else:
		lowest = _sprite_lowest()
	_set_cloak_visible(true)
	var placed := Vector2(sample["lean"], _ground - lowest)
	if _rendered and absf(float(sample["time"]) - 0.1) < 0.001:
		var readings: Array[float] = []
		var check := sample.duplicate()
		check["hip"] = placed
		for round in 4:
			readings.append(await _rendered_lowest(check) - _ground)
		print("  repeated readings of one pose: ", readings)
	return placed


func _rendered_lowest(sample: Dictionary) -> float:
	_apply_pose(sample)
	await _settle()
	return await _lowest_lit_rig_y()


## The cloak is cloth: it is a separate player with its own wind loop, so it is
## excluded while the pelvis height is chosen and measured on its own below.
func _set_cloak_visible(state: bool) -> void:
	var cloak := _rig.get_node_or_null(CONTAINER + "VisualDetails/Cloak") as CanvasItem
	if cloak != null:
		cloak.visible = state


func _cloak_visible() -> bool:
	var cloak := _rig.get_node_or_null(CONTAINER + "VisualDetails/Cloak") as CanvasItem
	return cloak != null and cloak.visible


func _sprite_lowest() -> float:
	var lowest := -INF
	for point: Vector2 in _sprite_points():
		lowest = maxf(lowest, point.y)
	return lowest


## Lowest lit pixel of the current frame, converted to rig coordinates.
## Also stores the lit bounds of that frame in _lit_bounds (min x, min y, max x, max y).
func _lowest_lit_rig_y() -> float:
	await RenderingServer.frame_post_draw
	var frame := _viewport.get_texture().get_image()
	frame.convert(Image.FORMAT_RGBA8)
	var data := frame.get_data()
	var width := frame.get_width()
	var height := frame.get_height()
	var lowest := -1
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for y in range(height):
		var row_start := y * width * 4
		for x in width:
			if data[row_start + x * 4 + 3] <= 40:
				continue
			if lowest < 0 or y > lowest:
				lowest = y
			var rig := Vector2(
				_camera.position.x - _rig.position.x + (float(x) - _frame_size.x * 0.5) / _zoom,
				_camera.position.y - _rig.position.y + (float(y) - _frame_size.y * 0.5) / _zoom
			)
			minimum = minimum.min(rig)
			maximum = maximum.max(rig)
	_lit_bounds = Vector4(minimum.x, minimum.y, maximum.x, maximum.y)
	if lowest < 0:
		return _sprite_lowest()
	return _camera.position.y - _rig.position.y + (float(lowest) - _frame_size.y * 0.5) / _zoom


# --- pose model ---------------------------------------------------------


## Samples the roll's angle, tuck amount and pelvis lean over the clip.
func _roll_samples() -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	var count := int(round(LENGTH / STEP))
	for index in count + 1:
		var time := minf(index * STEP, LENGTH)
		var angle := _roll_angle_degrees(time)
		samples.append({
			"time": time,
			"angle": deg_to_rad(angle),
			"degrees": angle,
			"tuck": _tuck_amount(time),
			"lean": _lean(time),
		})
	return samples


## Tips forward, tumbles with the fastest turn mid-roll, then settles upright.
func _roll_angle_degrees(time: float) -> float:
	if time <= TIP_END:
		return TIP_DEGREES * pow(time / TIP_END, 1.7)
	if time <= ROLL_END:
		var progress := (time - TIP_END) / (ROLL_END - TIP_END)
		return TIP_DEGREES + (ROLL_DEGREES - TIP_DEGREES) * _smooth(progress)
	var progress := (time - ROLL_END) / (LENGTH - ROLL_END)
	return ROLL_DEGREES + (360.0 - ROLL_DEGREES) * (1.0 - pow(1.0 - progress, 1.8))


func _tuck_amount(time: float) -> float:
	if time <= TUCK_IN_END:
		return _smooth(time / TUCK_IN_END)
	if time <= TUCK_OUT_START:
		return 1.0
	return 1.0 - _smooth((time - TUCK_OUT_START) / (LENGTH - TUCK_OUT_START))


## A short forward push while committing, unwinding as the hero rises.
func _lean(time: float) -> float:
	if time <= TUCK_IN_END:
		return LEAN_PEAK * _smooth(time / TUCK_IN_END)
	if time <= TUCK_OUT_START:
		return LEAN_PEAK * (1.0 - 0.45 * _smooth((time - TUCK_IN_END) / (TUCK_OUT_START - TUCK_IN_END)))
	return LEAN_PEAK * 0.55 * (1.0 - _smooth((time - TUCK_OUT_START) / (LENGTH - TUCK_OUT_START)))


func _smooth(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


func _target_position(sample: Dictionary, name: String) -> Vector2:
	var offset: Vector2
	if sample.has("offsets"):
		offset = sample["offsets"][name]
	else:
		offset = (STAND[name] as Vector2).lerp(TUCK[name], sample["tuck"])
	return (sample["hip"] as Vector2) + offset.rotated(sample["angle"])


func _at_position(sample: Dictionary, name: String) -> Vector2:
	var offset: Vector2
	if sample.has("ats"):
		offset = sample["ats"][name]
	else:
		offset = (STAND_AT[name] as Vector2).lerp(TUCK_AT[name], sample["tuck"])
	return offset.rotated(sample["angle"])


func _apply_pose(sample: Dictionary) -> void:
	var hip := _rig.get_node(HIP_PATH) as Node2D
	hip.position = sample["hip"]
	hip.rotation = sample["angle"]
	for name: String in TARGET_PATHS:
		var node := _rig.get_node(TARGET_PATHS[name]) as Node2D
		node.position = _target_position(sample, name)
		node.rotation = 0.0
	for name: String in AT_PATHS:
		var node := _rig.get_node(AT_PATHS[name]) as Node2D
		node.position = _at_position(sample, name)
		node.rotation = 0.0


# --- clip ---------------------------------------------------------------


func _build_clip(samples: Array[Dictionary]) -> void:
	_animation.resource_name = "dodge2"
	_animation.length = LENGTH
	_animation.loop_mode = Animation.LOOP_NONE
	for name: String in TARGET_PATHS:
		_add_value_track(String(TARGET_PATHS[name]) + ":position")
		_add_value_track(String(TARGET_PATHS[name]) + ":rotation")
	for name: String in AT_PATHS:
		_add_value_track(String(AT_PATHS[name]) + ":position")
	_add_value_track(HIP_PATH + ":position")
	_add_value_track(HIP_PATH + ":rotation")
	for sample: Dictionary in samples:
		_write_sample(sample)


func _add_value_track(path: String) -> void:
	var track := _animation.add_track(Animation.TYPE_VALUE)
	_animation.track_set_path(track, NodePath(path))
	_animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)


func _write_sample(sample: Dictionary) -> void:
	var time: float = sample["time"]
	for name: String in TARGET_PATHS:
		_animation.track_insert_key(
			_find_track(String(TARGET_PATHS[name]) + ":position"), time, _target_position(sample, name)
		)
		_animation.track_insert_key(
			_find_track(String(TARGET_PATHS[name]) + ":rotation"), time, 0.0
		)
	for name: String in AT_PATHS:
		_animation.track_insert_key(
			_find_track(String(AT_PATHS[name]) + ":position"), time, _at_position(sample, name)
		)
	_animation.track_insert_key(_find_track(HIP_PATH + ":position"), time, sample["hip"])
	_animation.track_insert_key(_find_track(HIP_PATH + ":rotation"), time, sample["angle"])


func _find_track(path: String) -> int:
	for index in _animation.get_track_count():
		if _animation.track_get_path(index) == NodePath(path):
			return index
	push_error("Missing track " + path)
	return -1


# --- verification -------------------------------------------------------


## Replays the written clip and reports the pelvis path and floor contact.
func _report() -> void:
	print("%8s %8s %7s %18s %10s %10s %10s %10s" % ["time", "angle", "tuck", "pelvis", "body", "cloak", "sprite", "top"])
	var worst_body := -INF
	var worst_cloak := -INF
	var lowest_top := INF
	var worst_sprite := -INF
	var count := 21
	for index in count:
		var time := LENGTH * float(index) / float(count - 1)
		_player.play(&"dodge2")
		_player.seek(time, true)
		_player.pause()
		await _settle()
		var hip := (_rig.get_node(HIP_PATH) as Node2D).position
		var body := 0.0
		var cloak := 0.0
		var top := 0.0
		if _rendered:
			_set_cloak_visible(false)
			body = await _lowest_lit_rig_y() - _ground
			_set_cloak_visible(true)
			cloak = await _lowest_lit_rig_y() - _ground
			top = _sprite_silhouette().position.y - _ground
		else:
			var rect := _sprite_silhouette()
			body = rect.end.y - _ground
			cloak = body
			top = rect.position.y - _ground
		worst_body = maxf(worst_body, body)
		worst_cloak = maxf(worst_cloak, cloak)
		lowest_top = minf(lowest_top, top)
		var sprite := _sprite_silhouette().end.y - _ground
		worst_sprite = maxf(worst_sprite, sprite)
		print(
			"%8.3f %8.1f %7.2f (%+8.1f,%+8.1f) %+10.1f %+10.1f %+10.1f %+10.1f"
			% [
				time, rad_to_deg((_rig.get_node(HIP_PATH) as Node2D).rotation),
				_tuck_amount(time), hip.x, hip.y, body, cloak, sprite, top,
			]
		)
	print(
		"summary: worst body dip %+.1f, with cloak %+.1f, sprites only %+.1f, highest point %+.1f%s"
		% [worst_body, worst_cloak, worst_sprite, lowest_top, "" if _rendered else "  [no renderer]"]
	)
	await _report_tucked_cloak()


## The cloak is a separate player hanging on the pelvis: report how it behaves
## with its own air pose, which is what a roll would want to reuse.
func _report_tucked_cloak() -> void:
	if not _rendered:
		return
	var cloak := _rig.get_node_or_null(CONTAINER + "VisualDetails/Cloak") as Node2D
	if cloak == null:
		return
	var cloth := cloak.get_node_or_null("CloakAnimation") as AnimationPlayer
	if cloth == null or not cloth.has_animation(&"jump"):
		return
	for clip: StringName in [&"wind", &"jump", &"fall"]:
		cloth.play(clip)
		cloth.advance(0.0)
		cloth.pause()
		var worst := -INF
		for index in 21:
			_player.play(&"dodge2")
			_player.seek(LENGTH * float(index) / 20.0, true)
			_player.pause()
			await _settle()
			worst = maxf(worst, await _lowest_lit_rig_y() - _ground)
		print("cloak pose %-6s worst dip %+.1f" % [clip, worst])


## Renders the roll into one contact sheet, with the floor drawn in.
func _render_sheet() -> void:
	var columns := 7
	var frames := 21
	var cell := Vector2i(360, int(round(360.0 * _frame_size.y / _frame_size.x)))
	var sheet := Image.create(
		cell.x * columns, cell.y * ceili(float(frames) / float(columns)), false, Image.FORMAT_RGBA8
	)
	sheet.fill(Color(0.08, 0.09, 0.12))
	for index in frames:
		_player.play(&"dodge2")
		_player.seek(LENGTH * float(index) / float(frames - 1), true)
		_player.pause()
		await _settle()
		await RenderingServer.frame_post_draw
		var frame := _viewport.get_texture().get_image()
		frame.convert(Image.FORMAT_RGBA8)
		frame.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		sheet.blend_rect(
			frame, Rect2i(Vector2i.ZERO, cell),
			Vector2i(cell.x * (index % columns), cell.y * (index / columns))
		)
	var ground_row := int(round(
		(_ground - (_camera.position.y - _rig.position.y)) * _zoom + cell.y * 0.5
	))
	for column in columns:
		sheet.fill_rect(Rect2i(column * cell.x, ground_row, cell.x, 2), Color(0.35, 0.75, 0.45))
	sheet.save_png(SHEET_PATH)
	print("wrote %s (%d frames)" % [SHEET_PATH, frames])


## Prints a strip of roll poses as text, so the tumble can be judged without an
## image viewer. '#' is artwork, 'G' the ground line.
func _ascii_roll() -> void:
	for time in [0.0, 0.08, 0.14, 0.20, 0.26, 0.32, 0.40]:
		_player.play(&"dodge2")
		_player.seek(time, true)
		_player.pause()
		await _settle()
		var hip := (_rig.get_node(HIP_PATH) as Node2D).position
		print(
			"--- t=%.2f angle=%.0f pelvis=(%+.0f,%+.0f) ---"
			% [time, rad_to_deg((_rig.get_node(HIP_PATH) as Node2D).rotation), hip.x, hip.y]
		)
		await _ascii(40, 40)


## Prints the current viewport as text, so poses can be inspected without an
## image viewer. '#' is artwork, '.' is empty, 'G' marks the ground line.
func _ascii(columns := 96, rows := 40) -> void:
	await RenderingServer.frame_post_draw
	var frame := _viewport.get_texture().get_image()
	var step_x := maxi(1, frame.get_width() / columns)
	var step_y := maxi(1, frame.get_height() / rows)
	var ground_row := (float(_ground) - (_camera.position.y - _rig.position.y)) * _zoom + _frame_size.y * 0.5
	for row in rows:
		var line := ""
		for column in columns:
			var lit := false
			for dy in range(0, step_y, 2):
				for dx in range(0, step_x, 2):
					var y := row * step_y + dy
					if y < frame.get_height() and frame.get_pixel(column * step_x + dx, y).a > 0.3:
						lit = true
						break
				if lit:
					break
			var pixel_y := float(row * step_y + step_y * 0.5)
			if absf(pixel_y - ground_row) < step_y * 0.5:
				line += "#" if lit else "G"
			else:
				line += "#" if lit else "."
		print(line)


## Renders a fixed set of poses from the shipped clips, so rig edits can be
## compared before and after.
func _measure_clips() -> void:
	var poses := [
		[&"idle", 0.0], [&"run", 0.0], [&"run", 0.15], [&"run", 0.3],
		[&"jump", 0.05], [&"fall", 0.1], [&"heavy_attack", 0.15],
	]
	for pose: Array in poses:
		if not _player.has_animation(pose[0]):
			continue
		_player.stop()
		_player.play(pose[0])
		_player.seek(pose[1], true)
		_player.pause()
		await _settle()
		var lowest := await _lowest_lit_rig_y()
		print(
			"%-14s t=%.2f lowest %+8.1f  bbox x=[%+7.1f..%+7.1f] y=[%+7.1f..%+7.1f]"
			% [
				pose[0], pose[1], lowest,
				_lit_bounds.x, _lit_bounds.z, _lit_bounds.y, _lit_bounds.w,
			]
		)


## Measures how far the drawn silhouette moves when the pelvis moves: the
## placement rule assumes it translates rigidly, one pelvis unit for one unit.
func _probe_rigidity() -> void:
	await _probe_case("as authored", true)
	await _probe_case("polygon followers off", false)
	_quit()


func _probe_case(label: String, followers: bool) -> void:
	var sample := {}
	for candidate: Dictionary in _roll_samples():
		if absf(float(candidate["time"]) - 0.1) < 0.001:
			sample = candidate
	var polygons := _rig.get_node(CONTAINER + "Polygons") as Node2D
	var sprite_names: Array[String] = []
	for node: Node in _rig.find_children("*", "Sprite2D", true, false):
		sprite_names.append(String(node.name))
	var followers_nodes: Array[RemoteTransform2D] = []
	for node: Node in _rig.find_children("*", "RemoteTransform2D", true, false):
		var follower := node as RemoteTransform2D
		if String(follower.remote_path).begins_with("../../../../Polygons") or "Polygons" in String(follower.remote_path):
			followers_nodes.append(follower)
	for follower: RemoteTransform2D in followers_nodes:
		follower.update_position = followers
	print("case %s (followers %d)" % [label, followers_nodes.size()])
	for probe: Dictionary in [
		{"label": "all", "sprites": true, "polygons": true, "cloak": true},
		{"label": "skinned only", "sprites": false, "polygons": true, "cloak": false},
		{"label": "sprites only", "sprites": true, "polygons": false, "cloak": false},
	]:
		polygons.visible = probe["polygons"]
		_set_cloak_visible(probe["cloak"])
		for name: String in sprite_names:
			var sprite := _rig.find_child(name, true, false) as Sprite2D
			if sprite != null and name not in ["MainHand", "OffHand"]:
				sprite.visible = probe["sprites"]
		var reference := Vector4.ZERO
		for hip_y in [0.0, 100.0, 200.0]:
			var posed := sample.duplicate()
			posed["hip"] = Vector2(sample["lean"], hip_y)
			_apply_pose(posed)
			await _settle()
			var lowest := await _lowest_lit_rig_y()
			var centre := Vector2(
				(_lit_bounds.x + _lit_bounds.z) * 0.5, (_lit_bounds.y + _lit_bounds.w) * 0.5
			)
			if is_zero_approx(hip_y):
				reference = Vector4(centre.x, centre.y, lowest, 0.0)
			print(
				"  %-14s hip.y %+6.1f lowest %+8.1f gain %.2f | centre moved (%+.1f,%+.1f) gain %.2f"
				% [
					probe["label"], hip_y, lowest, (lowest - reference.z) / maxf(hip_y, 1.0),
					centre.x - reference.x, centre.y - reference.y,
					(centre.y - reference.y) / maxf(hip_y, 1.0),
				]
			)
	polygons.visible = true
	_set_cloak_visible(true)
	for name: String in sprite_names:
		var sprite := _rig.find_child(name, true, false) as Sprite2D
		if sprite != null and name not in ["MainHand", "OffHand"]:
			sprite.visible = true


## Compares candidate tucks by ball radius and pelvis travel. Sprite-based: it
## ranks shapes, the rendered pass decides the final floor contact.
func _sweep() -> void:
	print("%-24s %8s %8s %8s" % ["candidate", "radius", "min", "travel"])
	for candidate: Dictionary in _candidates():
		var sample := {
			"hip": Vector2.ZERO,
			"angle": 0.0,
			"offsets": candidate["offsets"],
			"ats": candidate["ats"],
		}
		_apply_pose(sample)
		await _settle()
		var cloud := _sprite_points()
		var lowest := INF
		var highest := -INF
		for step in 72:
			var angle := TAU * float(step) / 72.0
			var support := -INF
			for point: Vector2 in cloud:
				support = maxf(support, point.rotated(angle).y)
			lowest = minf(lowest, support)
			highest = maxf(highest, support)
		print(
			"%-24s %8.0f %8.0f %8.0f"
			% [candidate["label"], highest, lowest, highest - lowest]
		)


func _candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tight := (TUCK as Dictionary).duplicate()
	out.append(_candidate("A legs 130, head 90", tight, 90.0))
	out.append(_candidate("B legs 130, head 75", tight, 75.0))
	var mid := tight.duplicate()
	mid["front_leg"] = Vector2(-62, 168)
	mid["back_leg"] = Vector2(52, 176)
	out.append(_candidate("C legs 170, head 90", mid, 90.0))
	out.append(_candidate("D legs 170, head 75", mid, 75.0))
	var half := tight.duplicate()
	half["front_leg"] = Vector2(-70, 210)
	half["back_leg"] = Vector2(78, 206)
	out.append(_candidate("E legs 210, head 90", half, 90.0))
	var spread := tight.duplicate()
	spread["front_leg"] = Vector2(120, 230)
	spread["back_leg"] = Vector2(-40, 240)
	out.append(_candidate("F legs spread, head 90", spread, 90.0))
	return out


func _candidate(label: String, offsets: Dictionary, head_degrees: float) -> Dictionary:
	var tuck := offsets.duplicate()
	tuck["head"] = Vector2(0, -269) + Vector2.RIGHT.rotated(deg_to_rad(head_degrees)) * 300.0
	return {"label": label, "offsets": tuck, "ats": TUCK_AT}


# --- sprite outline -----------------------------------------------------


## Sprite artwork only, in rig space. Used for the headless ranking pass.
func _sprite_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var inverse := _rig.global_transform.affine_inverse()
	for node: Node in _rig.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if not sprite.visible or sprite.texture == null:
			continue
		var local := inverse * sprite.global_transform
		for point: Vector2 in _sprite_outline(sprite):
			points.append(local * point)
	return points


func _sprite_silhouette() -> Rect2:
	var points := _sprite_points()
	var rect := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		rect = rect.expand(point)
	return rect


## Hull of a sprite's opaque pixels, in the sprite's own local coordinates.
## Texture-space corners would exaggerate the roll radius: a rotated rectangle's
## corner sweeps much farther than the artwork it contains.
func _sprite_outline(sprite: Sprite2D) -> PackedVector2Array:
	var texture := sprite.texture
	if not _hull_cache.has(texture):
		_hull_cache[texture] = _texture_hull(texture)
	var size := texture.get_size()
	var origin := (-size * 0.5 if sprite.centered else Vector2.ZERO) + sprite.offset
	var points := PackedVector2Array()
	for point: Vector2 in _hull_cache[texture]:
		points.append(point + origin)
	return points


func _texture_hull(texture: Texture2D) -> PackedVector2Array:
	var image := texture.get_image()
	var points := PackedVector2Array()
	if image == null or image.is_empty():
		return PackedVector2Array([
			Vector2.ZERO, Vector2(texture.get_width(), 0),
			texture.get_size(), Vector2(0, texture.get_height()),
		])
	var width := image.get_width()
	var height := image.get_height()
	var step := maxi(1, int(floor(maxf(width, height) / 200.0)))
	for y in range(0, height, step):
		for x in range(0, width, step):
			if image.get_pixel(x, y).a > 0.4:
				points.append(Vector2(x, y))
	var hull := _convex_hull(points)
	if hull.is_empty():
		hull = PackedVector2Array([Vector2.ZERO, texture.get_size()])
	return hull


## Andrew's monotone chain hull; the sampled outline only needs to be convex.
func _convex_hull(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var sorted := Array(points)
	sorted.sort_custom(_sort_points)
	var lower: Array[Vector2] = []
	for point: Vector2 in sorted:
		while lower.size() >= 2 and _cross(lower[-2], lower[-1], point) <= 0.0:
			lower.pop_back()
		lower.append(point)
	var upper: Array[Vector2] = []
	for index in range(sorted.size() - 1, -1, -1):
		var point: Vector2 = sorted[index]
		while upper.size() >= 2 and _cross(upper[-2], upper[-1], point) <= 0.0:
			upper.pop_back()
		upper.append(point)
	lower.pop_back()
	upper.pop_back()
	var hull := PackedVector2Array(lower)
	hull.append_array(PackedVector2Array(upper))
	return hull


func _sort_points(a: Vector2, b: Vector2) -> bool:
	if not is_equal_approx(a.x, b.x):
		return a.x < b.x
	return a.y < b.y


func _cross(origin: Vector2, a: Vector2, b: Vector2) -> float:
	return (a.x - origin.x) * (b.y - origin.y) - (a.y - origin.y) * (b.x - origin.x)
