@tool
extends Node
class_name EnemyAuthoringChecks

## Editor-only checks for a standalone enemy composition; never initialize gameplay here.
const CLIPS: Array[StringName] = [&"idle", &"move", &"airborne", &"attack", &"death"]
var _refresh_time: float = 0.0
var _last_warnings := PackedStringArray()


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		update_configuration_warnings()


func _process(delta: float) -> void:
	_refresh_time += delta
	if _refresh_time < 0.5:
		return
	_refresh_time = 0.0
	var warnings := inspect_scene(get_parent())
	if warnings != _last_warnings:
		_last_warnings = warnings
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	return inspect_scene(get_parent())


static func inspect_scene(enemy: Node) -> PackedStringArray:
	var warnings := PackedStringArray()
	if enemy == null:
		return warnings
	var components := enemy.get_node_or_null("_Components")
	if components == null:
		warnings.append("Add a _Components node containing the enemy's components.")
		return warnings
	var by_type: Dictionary = {}
	for node: Node in components.get_children():
		var script := node.get_script() as Script
		if script != null:
			by_type[script.get_global_name()] = node
	for type: StringName in [&"CharacterBodyComponent", &"HealthComponent", &"EnemyVisualComponent"]:
		if not by_type.has(type):
			warnings.append("Add %s under _Components." % type)
	if not by_type.has(&"EnemyMovementComponent") and not by_type.has(&"EnemyFlightComponent"):
		warnings.append("Add EnemyMovementComponent or EnemyFlightComponent for locomotion.")
	for type: StringName in by_type:
		var node: Node = by_type[type]
		for property: Dictionary in node.get_property_list():
			if property.name == "config" and node.get("config") == null:
				warnings.append("Assign a config resource to %s." % node.name)
	if by_type.has(&"EnemyAttackComponent") and not by_type.has(&"AttackComponent"):
		warnings.append("EnemyAttackComponent needs an AttackComponent.")
	var attack: Node = by_type.get(&"AttackComponent")
	if attack != null:
		if not by_type.has(&"HitboxComponent"):
			warnings.append("AttackComponent needs a HitboxComponent.")
		if attack.get("animation_driven_damage_window") and not by_type.has(&"AnimationEventComponent"):
			warnings.append("Animation-driven attacks need AnimationEventComponent.")
	var visual: Node = by_type.get(&"EnemyVisualComponent")
	if visual == null:
		return warnings
	var sprite := enemy.get_node_or_null(visual.get("sprite_path")) as AnimatedSprite2D
	var player := enemy.get_node_or_null(visual.get("animation_player_path")) as AnimationPlayer
	if sprite == null or sprite.sprite_frames == null:
		warnings.append("Assign AnimatedSprite2D with SpriteFrames at EnemyVisualComponent's Sprite Path.")
	if player == null:
		warnings.append("Assign AnimationPlayer at EnemyVisualComponent's Animation Player Path.")
		return warnings
	for clip: StringName in CLIPS:
		if sprite != null and sprite.sprite_frames != null:
			if not sprite.sprite_frames.has_animation(clip) or sprite.sprite_frames.get_frame_count(clip) == 0:
				warnings.append("SpriteFrames needs a non-empty '%s' animation." % clip)
		if not player.has_animation(clip):
			warnings.append("AnimationPlayer needs a '%s' clip." % clip)
		elif clip in [&"attack", &"death"] and player.get_animation(clip).loop_mode != Animation.LOOP_NONE:
			warnings.append("Turn off looping for the '%s' clip." % clip)
	if attack != null:
		var timing_path: NodePath = attack.get("timing_player_path")
		if timing_path.is_empty() or attack.get_node_or_null(timing_path) != player:
			warnings.append("Point AttackComponent's Timing Player Path to the enemy's AnimationPlayer.")
		elif attack.get("timing_clip") != &"attack":
			warnings.append("Use 'attack' as Timing Clip to match EnemyVisualComponent.")
		if attack.get("animation_driven_damage_window") and player.has_animation(&"attack"):
			_check_hit_events(player, warnings)
	return warnings


static func _check_hit_events(player: AnimationPlayer, warnings: PackedStringArray) -> void:
	var clip := player.get_animation(&"attack")
	var root := player.get_node_or_null(player.root_node)
	var events: Dictionary = {}
	for track: int in clip.get_track_count():
		if clip.track_get_type(track) != Animation.TYPE_METHOD or not clip.track_is_enabled(track):
			continue
		var target := root.get_node_or_null(clip.track_get_path(track)) if root != null else null
		var script := target.get_script() as Script if target != null else null
		if script == null or script.get_global_name() != &"AnimationEventComponent":
			continue
		for index: int in clip.track_get_key_count(track):
			var key: Dictionary = clip.track_get_key_value(track, index)
			var args: Array = key.get("args", [])
			if key.get("method") == &"emit_event" and not args.is_empty():
				events[args[0]] = clip.track_get_key_time(track, index)
	for event: StringName in [&"hitbox_on", &"hitbox_off"]:
		if not events.has(event):
			warnings.append("Add '%s' in the attack clip on an enabled method track targeting AnimationEventComponent.emit_event." % event)
	if events.has(&"hitbox_on") and events.has(&"hitbox_off"):
		if events[&"hitbox_on"] >= events[&"hitbox_off"] or events[&"hitbox_off"] > clip.length:
			warnings.append("Place hitbox_on before hitbox_off, both within the attack clip.")
