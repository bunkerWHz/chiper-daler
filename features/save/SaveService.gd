extends Node

signal save_finished(error: Error)

const SAVE_PATH := "user://checkpoint.cfg"
var store := preload("res://features/save/SaveStore.gd").new()
var active := false
var world: Dictionary = {}
var checkpoint_scene := ""
var checkpoint_position := Vector2.ZERO
var rest_id := ""
var play_seconds := 0.0
var last_error: Error = OK
var _player: Actor
var _pending: Dictionary = {}
var _restoring := false
var _dirty := false
var _queued := false
var _retry_remaining := 0.0
var _enemies: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().scene_changed.connect(_on_scene_changed)


func _process(delta: float) -> void:
	if active and is_instance_valid(_player) and not get_tree().paused:
		play_seconds += delta
	if active and _dirty and last_error != OK:
		_retry_remaining -= delta
		if _retry_remaining <= 0.0:
			_retry_remaining = 5.0
			request_save()


func prepare(saved: Dictionary = {}) -> void:
	active = true
	_player = null
	_pending = saved.get("player", {}).duplicate(true)
	world = saved.get("world", {}).duplicate(true)
	checkpoint_scene = saved.get("scene", "")
	checkpoint_position = saved.get("checkpoint", Vector2.ZERO)
	rest_id = saved.get("rest_id", "")
	play_seconds = float(saved.get("play_seconds", 0))
	_dirty = false
	last_error = OK


func _on_scene_changed() -> void:
	if not active or get_tree().current_scene == null:
		return
	var scene := get_tree().current_scene
	_enemies.clear()
	for node: Node in get_tree().get_nodes_in_group(&"persistent_world"):
		if scene.is_ancestor_of(node):
			node.restore_persistent_state()
	for node: Node in scene.find_children("*", "", true, false):
		if node.is_in_group(&"enemies") and node is Actor and not node.scene_file_path.is_empty():
			_enemies.append({"scene": node.scene_file_path, "parent": scene.get_path_to(node.get_parent()), "transform": node.transform, "name": node.name})
		if node is PlayerRespawnComponent:
			_player = node.actor
	if not is_instance_valid(_player):
		return
	_restoring = true
	if not _pending.is_empty():
		store.codec.restore(_player, _pending)
	_pending.clear()
	var respawn := _player.get_component(PlayerRespawnComponent) as PlayerRespawnComponent
	if checkpoint_scene.is_empty():
		checkpoint_scene = scene.scene_file_path
		checkpoint_position = respawn.get_checkpoint_position()
	if checkpoint_scene == scene.scene_file_path:
		if not rest_id.is_empty():
			for node: Node in scene.find_children("*", "", true, false):
				if node is RestPoint and object_id(node, node.save_id) == rest_id:
					checkpoint_position = node.global_position + node.spawn_offset
		respawn.set_checkpoint_position(checkpoint_position)
		_player.global_position = checkpoint_position
	_bind_player()
	_restoring = false
	request_save()


func _bind_player() -> void:
	# Coalesce synchronous operations (purchase + payment, reward + source flag)
	# into one snapshot at the end of the current frame.
	var signals := {
		InventoryComponent: ["inventory_changed"],
		CharacterAttributesComponent: ["attributes_changed"],
		ProgressionComponent: ["experience_changed"],
		EquipmentComponent: ["equipment_changed", "weapon_set_changed", "loadout_item_changed"],
		QuickAccessComponent: ["active_slot_changed", "slot_assignment_changed"],
		RangedWeaponComponent: ["projectile_fired", "ammunition_changed"],
		ThrowingComponent: ["throwable_released", "charges_changed"],
		PlayerRespawnComponent: ["checkpoint_changed", "restart_scheduled"],
	}
	for type: Variant in signals:
		var component := _player.get_component(type)
		if component == null:
			continue
		for signal_name: String in signals[type]:
			if not component.has_signal(signal_name):
				continue
			var argument_count := 0
			for info: Dictionary in component.get_signal_list():
				if info.name == signal_name:
					argument_count = info.args.size()
			var callback := request_save.unbind(argument_count) if argument_count > 0 else request_save
			if not component.is_connected(signal_name, callback):
				component.connect(signal_name, callback)


func request_save() -> void:
	if not active or _restoring:
		return
	_dirty = true
	if not _queued:
		_queued = true
		_flush_deferred.call_deferred()


func _flush_deferred() -> void:
	_queued = false
	if _dirty and active and is_instance_valid(_player):
		save_now()


func save_now(path: String = SAVE_PATH) -> Error:
	if not active or not is_instance_valid(_player) or not _player.is_inside_tree():
		return ERR_UNAVAILABLE
	# Compatibility with callers that set a coordinate checkpoint directly.
	if rest_id.is_empty() and get_tree().current_scene.scene_file_path == checkpoint_scene:
		checkpoint_position = (_player.get_component(PlayerRespawnComponent) as PlayerRespawnComponent).get_checkpoint_position()
	var snapshot := {
		"scene": checkpoint_scene, "checkpoint": checkpoint_position,
		"rest_id": rest_id, "player": store.codec.capture(_player),
		"world": world.duplicate(true), "play_seconds": int(play_seconds),
		"date": Time.get_datetime_string_from_system().replace("T", " "),
	}
	last_error = store.write_save(path, snapshot)
	_dirty = last_error != OK
	if last_error != OK:
		_retry_remaining = 5.0
		push_warning("Could not save playthrough: " + error_string(last_error))
	save_finished.emit(last_error)
	return last_error


func rest_at(point: RestPoint, visitor: Actor) -> void:
	if not active or visitor != _player:
		return
	checkpoint_scene = get_tree().current_scene.scene_file_path
	checkpoint_position = point.global_position + point.spawn_offset
	rest_id = object_id(point, point.save_id)
	set_flag(point, point.save_id, "activated", true)
	reset_enemies()
	request_save()


func object_id(node: Node, explicit_id: String = "") -> String:
	if not explicit_id.is_empty():
		return explicit_id
	var scene := get_tree().current_scene
	return "path:" + String(scene.get_path_to(node)) if scene != null and scene.is_ancestor_of(node) else ""


func _world_key(node: Node, explicit_id: String, flag: String) -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	return scene.scene_file_path + "::" + object_id(node, explicit_id) + "::" + flag


func get_flag(node: Node, id: String, flag: String, default: Variant = false) -> Variant:
	return world.get(_world_key(node, id, flag), default) if active else default


func set_flag(node: Node, id: String, flag: String, value: Variant) -> void:
	if not active or not store.codec._plain_data(value):
		return
	world[_world_key(node, id, flag)] = value
	request_save()


func travel_to(scene: PackedScene) -> Error:
	if not active or not is_instance_valid(_player):
		return ERR_UNAVAILABLE
	var error := save_now()
	if error != OK:
		return error
	_pending = store.codec.capture(_player)
	error = get_tree().change_scene_to_packed(scene)
	if error == OK:
		_player = null
	return error


func respawn_at_checkpoint() -> bool:
	if not active or not is_instance_valid(_player):
		return false
	# Death uses current in-memory progress even when a disk write fails.
	save_now()
	_pending = store.codec.capture(_player)
	var error := get_tree().change_scene_to_file(checkpoint_scene)
	if error == OK:
		_player = null
	return error == OK


func reset_enemies() -> void:
	var scene := get_tree().current_scene
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		if scene.is_ancestor_of(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	for entry: Dictionary in _enemies:
		var parent := scene.get_node_or_null(entry.parent)
		if parent == null:
			continue
		var enemy := load(entry.scene).instantiate() as Actor
		enemy.name = entry.name
		enemy.transform = entry.transform
		parent.add_child(enemy)
