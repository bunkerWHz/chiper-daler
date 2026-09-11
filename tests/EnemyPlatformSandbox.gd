extends Node2D

@export var enemy_scenes: Array[PackedScene] = []

var current_enemy: Actor
var _next_index: int = 0

@onready var spawn_point: Marker2D = $EnemySpawn
@onready var status_label: Label = $UI/CanvasLayer/MonsterStatus


func _ready() -> void:
	_spawn_next.call_deferred()


func _spawn_next() -> void:
	if enemy_scenes.is_empty():
		status_label.text = "Добавьте сцены в Enemy Scenes"
		return
	if is_instance_valid(current_enemy):
		remove_child(current_enemy)
		current_enemy.queue_free()
	var scene := enemy_scenes[_next_index]
	var enemy := scene.instantiate() as Actor if scene != null else null
	if enemy == null:
		status_label.text = "В Enemy Scenes должна быть сцена монстра"
		return
	var monster_name := String(enemy.name)
	# Keep the path used by the platform reach markers stable.
	enemy.name = "Enemy"
	enemy.position = to_local(spawn_point.global_position)
	add_child(enemy)
	current_enemy = enemy
	status_label.text = "%d / %d — %s\nУбейте монстра, чтобы появился следующий" % [
		_next_index + 1, enemy_scenes.size(), monster_name,
	]
	_next_index = (_next_index + 1) % enemy_scenes.size()
	var death := enemy.get_component(DeathComponent) as DeathComponent
	if death != null:
		# Finish the death animation and leave physics callbacks before spawning.
		death.death_finished.connect(_spawn_next, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
