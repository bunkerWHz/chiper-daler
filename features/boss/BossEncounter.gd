extends Node2D
class_name BossEncounter

## Shared encounter lifecycle. Custom boss brains start on combat_started.
signal intro_started
signal combat_started
signal encounter_ended(victory: bool)

enum Phase { WAITING, INTRO, COMBAT, DEFEATED }
const HUD := preload("res://features/boss/BossHUD.tscn")
const ACTIVE_GROUP := &"active_boss_encounter"

@export var boss_name: String = "Boss"
@export_range(0.1, 10.0, 0.1) var intro_hold_seconds := 2.0
@export_range(0.1, 3.0, 0.1) var intro_fade_seconds := 0.6
## Additional boss-specific Component nodes to suspend until combat starts.
@export var combat_component_paths: Array[NodePath] = []

var phase := Phase.WAITING
var _actor: Actor
var _health: HealthComponent
var _player: Actor
var _player_health: HealthComponent
var _suspended: Array[Component] = []
var _movement: EnemyMovementComponent
var _move_intent := 0.0
var _hud: CanvasLayer
var _intro: Tween


func _ready() -> void:
	_actor = get_parent() as Actor
	assert(_actor != null, "BossEncounter must be a child of an Actor")
	_health = _actor.get_component(HealthComponent) as HealthComponent
	assert(_health != null, "BossEncounter requires HealthComponent")
	_health.died.connect(_on_boss_died)
	_health.health_changed.connect(_update_health)
	# Keep the authored arena in place when the boss moves during combat.
	var arena := $Arena as Area2D
	var arena_transform := arena.global_transform
	arena.top_level = true
	arena.global_transform = arena_transform
	$Arena.body_entered.connect(_on_body_entered)
	$Arena.body_exited.connect(_on_body_exited)
	_suspend_combat()


func _suspend_combat() -> void:
	# Release reaction-owned suspensions first; their timers must not re-enable
	# attacks after this encounter has returned to WAITING.
	for reaction_type: Script in [HitStunComponent, KnockbackComponent]:
		var reaction := _actor.get_component(reaction_type)
		if reaction != null and reaction.is_enabled:
			_suspended.append(reaction)
			reaction.disable()
	for component: Component in _actor.get_components():
		if (component is AttackComponent or component is HitboxComponent
			or component is HurtboxComponent or component is EnemyAttackComponent
			or component is EnemyChaseComponent or component is EnemyPatrolComponent
			or component is EnemyJumpComponent or component is EnemyFlightComponent
			or component is StatusEffectComponent
			or _is_custom_combat_component(component)):
			if component.is_enabled:
				_suspended.append(component)
				component.disable()
	_movement = _actor.get_component(EnemyMovementComponent) as EnemyMovementComponent
	if _movement != null:
		_move_intent = _movement.get_move_direction()
		_movement.stop()
		_movement.lock_move_direction()


func _is_custom_combat_component(component: Component) -> bool:
	for path: NodePath in combat_component_paths:
		if get_node_or_null(path) == component:
			return true
	return false


func _on_body_entered(body: Node2D) -> void:
	var candidate := _find_actor(body)
	if candidate != null and candidate.has_component(InputComponent):
		_try_enter.call_deferred(candidate)


func _try_enter(candidate: Actor) -> void:
	if is_instance_valid(candidate) and _is_in_arena(candidate):
		begin_encounter(candidate)


func _on_body_exited(body: Node2D) -> void:
	if _find_actor(body) == _player:
		_try_exit.call_deferred()


func _try_exit() -> void:
	if is_instance_valid(_player) and not _is_in_arena(_player):
		cancel_encounter()


func _is_in_arena(candidate: Actor) -> bool:
	for body: Node2D in $Arena.get_overlapping_bodies():
		if _find_actor(body) == candidate:
			return true
	return false


func _find_actor(node: Node) -> Actor:
	while node != null:
		if node is Actor:
			return node as Actor
		node = node.get_parent()
	return null


func begin_encounter(player: Actor) -> bool:
	if phase != Phase.WAITING or not is_instance_valid(player) or _health.is_dead():
		return false
	if get_tree().get_first_node_in_group(ACTIVE_GROUP) != null:
		return false
	var health := player.get_component(HealthComponent) as HealthComponent
	if health == null or health.is_dead():
		return false
	_player = player
	_player_health = health
	_player_health.died.connect(cancel_encounter)
	_player.tree_exiting.connect(cancel_encounter)
	add_to_group(ACTIVE_GROUP)
	phase = Phase.INTRO
	_hud = HUD.instantiate() as CanvasLayer
	add_child(_hud)
	_hud.get_node("Screen/IntroName").text = boss_name
	_hud.get_node("Screen/Health/Name").text = boss_name
	_update_health(0.0, _health.get_current_health())
	var title := _hud.get_node("Screen/IntroName") as Label
	_intro = create_tween()
	title.modulate.a = 0.0
	_intro.tween_property(title, "modulate:a", 1.0, intro_fade_seconds)
	_intro.tween_interval(intro_hold_seconds)
	_intro.tween_property(title, "modulate:a", 0.0, intro_fade_seconds)
	_intro.tween_callback(_start_combat)
	intro_started.emit()
	return true


func _start_combat() -> void:
	if phase != Phase.INTRO or not is_instance_valid(_player) or _player_health.is_dead():
		return
	_hud.get_node("Screen/IntroName").hide()
	_hud.get_node("Screen/Health").show()
	phase = Phase.COMBAT
	if _movement != null:
		_movement.unlock_move_direction()
		_movement.set_move_direction(_move_intent)
	for component: Component in _suspended:
		if is_instance_valid(component):
			component.enable()
	_suspended.clear()
	combat_started.emit()


func _update_health(_previous: float, current: float) -> void:
	if not is_instance_valid(_hud):
		return
	var bar := _hud.get_node("Screen/Health/Bar") as ProgressBar
	bar.max_value = _health.get_max_health()
	bar.value = current


func cancel_encounter() -> void:
	if phase != Phase.INTRO and phase != Phase.COMBAT:
		return
	if phase == Phase.COMBAT:
		_suspend_combat()
	phase = Phase.WAITING
	_cleanup()
	_health.heal(_health.get_max_health())
	encounter_ended.emit(false)


func _on_boss_died() -> void:
	phase = Phase.DEFEATED
	_cleanup()
	encounter_ended.emit(true)


func _cleanup() -> void:
	if _intro != null and _intro.is_valid():
		_intro.kill()
	if is_instance_valid(_hud):
		_hud.hide()
		_hud.queue_free()
	_hud = null
	if is_instance_valid(_player_health) and _player_health.died.is_connected(cancel_encounter):
		_player_health.died.disconnect(cancel_encounter)
	if is_instance_valid(_player) and _player.tree_exiting.is_connected(cancel_encounter):
		_player.tree_exiting.disconnect(cancel_encounter)
	_player = null
	_player_health = null
	remove_from_group(ACTIVE_GROUP)


func _exit_tree() -> void:
	_cleanup()
