@tool
extends RefCounted


## Saves a standalone composition with owned animation and configuration resources.
## Existing directories are never overwritten.
static func save_copy(source: Node, directory: String, enemy_name: String) -> Error:
	if source == null or not enemy_name.is_valid_identifier() or not directory.begins_with("res://"):
		return ERR_INVALID_PARAMETER
	if DirAccess.dir_exists_absolute(directory):
		return ERR_ALREADY_EXISTS
	var copy := source.duplicate()
	copy.name = enemy_name
	copy.scene_file_path = ""
	if copy is Node2D:
		(copy as Node2D).scale = Vector2.ONE
	var visual := copy.get_node_or_null("_Components/EnemyVisualComponent")
	if visual == null:
		copy.free()
		return ERR_INVALID_DATA
	var sprite := copy.get_node_or_null(visual.get("sprite_path")) as AnimatedSprite2D
	var player := copy.get_node_or_null(visual.get("animation_player_path")) as AnimationPlayer
	if sprite == null or player == null:
		copy.free()
		return ERR_INVALID_DATA
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		copy.free()
		return error
	var written := PackedStringArray()
	var frames: SpriteFrames
	if sprite.sprite_frames != null:
		frames = sprite.sprite_frames.duplicate(true) as SpriteFrames
	else:
		frames = SpriteFrames.new()
		frames.remove_animation(&"default")
		for clip: StringName in [&"idle", &"move", &"airborne", &"attack", &"death"]:
			frames.add_animation(clip)
			frames.set_animation_loop(clip, clip not in [&"attack", &"death"])
	var frames_path := directory.path_join("SpriteFrames.tres")
	error = ResourceSaver.save(frames, frames_path, ResourceSaver.FLAG_CHANGE_PATH)
	if error == OK:
		written.append(frames_path)
		frames.take_over_path(frames_path)
		sprite.sprite_frames = frames
	for library_name: StringName in player.get_animation_library_list():
		if error != OK:
			break
		var library := player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
		var filename := "AnimationLibrary.tres" if library_name == &"" else "AnimationLibrary_%s.tres" % String(library_name).validate_filename()
		var library_path := directory.path_join(filename)
		error = ResourceSaver.save(library, library_path, ResourceSaver.FLAG_CHANGE_PATH)
		if error == OK:
			written.append(library_path)
			library.take_over_path(library_path)
			player.remove_animation_library(library_name)
			player.add_animation_library(library_name, library)
	for component: Node in copy.get_node("_Components").get_children():
		for property: Dictionary in component.get_property_list():
			if property.name == "config":
				var config := component.get("config") as Resource
				if config != null:
					component.set("config", config.duplicate(true))
	if error == OK:
		var packed := PackedScene.new()
		error = packed.pack(copy)
		if error == OK:
			error = ResourceSaver.save(packed, directory.path_join(enemy_name + ".tscn"))
	copy.free()
	if error != OK:
		for path: String in written:
			DirAccess.remove_absolute(path)
		DirAccess.remove_absolute(directory)
	return error
