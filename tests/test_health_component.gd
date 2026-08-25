@tool
extends McpTestSuite

var _death_count: int = 0
var _respawn_schedule_count: int = 0


func suite_name() -> String:
	return "health"


func setup() -> void:
	_death_count = 0
	_respawn_schedule_count = 0


func test_health_initializes_at_maximum() -> void:
	var health := _create_health(120.0)

	assert_eq(health.get_current_health(), 120.0)
	assert_eq(health.get_max_health(), 120.0)
	assert_eq(health.get_health_ratio(), 1.0)
	assert_true(health.is_alive())
	assert_false(health.is_dead())


func test_damage_is_clamped_and_reports_applied_amount() -> void:
	var health := _create_health(100.0)

	assert_eq(health.take_damage(25.0), 25.0)
	assert_eq(health.get_current_health(), 75.0)
	assert_eq(health.take_damage(100.0), 75.0)
	assert_eq(health.get_current_health(), 0.0)
	assert_eq(health.take_damage(10.0), 0.0)
	assert_true(health.is_dead())


func test_death_signal_is_emitted_once() -> void:
	var health := _create_health(10.0)
	health.died.connect(_on_died)

	health.take_damage(10.0)
	health.take_damage(10.0)

	assert_eq(_death_count, 1)


func test_non_positive_damage_is_ignored() -> void:
	var health := _create_health(100.0)

	assert_eq(health.take_damage(0.0), 0.0)
	assert_eq(health.take_damage(-10.0), 0.0)
	assert_eq(health.get_current_health(), 100.0)


func test_death_component_disables_other_components() -> void:
	var target := _create_death_target(false)

	target.health.take_damage(10.0)

	assert_true(target.death.is_dying())
	assert_true(target.death.is_enabled)
	assert_false(target.health.is_enabled)
	assert_false(target.other_component.is_enabled)

	target.death._process(target.config.duration)

	assert_false(target.death.is_dying())


func test_death_component_fades_visual() -> void:
	var target := _create_death_target(true)

	target.health.take_damage(10.0)
	target.death._process(target.config.duration * 0.5)

	assert_true(absf(target.visual.modulate.a - 0.5) < 0.001)

	target.death._process(target.config.duration * 0.5)

	assert_eq(target.visual.modulate.a, 0.0)


func test_player_respawn_is_scheduled_once() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var health := HealthComponent.new()
	var health_config := HealthConfig.new()
	health_config.max_health = 10.0
	health.config = health_config
	container.add_child(health)

	var respawn := PlayerRespawnComponent.new()
	var respawn_config := PlayerRespawnConfig.new()
	respawn_config.restart_delay = 0.5
	respawn.config = respawn_config
	container.add_child(respawn)
	actor._collect_components()
	respawn.restart_scheduled.connect(_on_respawn_scheduled)

	health.take_damage(10.0)
	health.take_damage(10.0)

	assert_true(respawn.is_restart_scheduled())
	assert_eq(_respawn_schedule_count, 1)


func _create_health(max_health: float) -> HealthComponent:
	var actor := track(Actor.new()) as Actor
	var health := HealthComponent.new()
	var config := HealthConfig.new()
	config.max_health = max_health
	health.config = config
	actor.add_child(health)
	health.initialize(actor)
	return health


func _create_death_target(fade_visual: bool) -> Dictionary:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var visual := Node2D.new()
	visual.name = "_Visual"
	actor.add_child(visual)

	var health := HealthComponent.new()
	var health_config := HealthConfig.new()
	health_config.max_health = 10.0
	health.config = health_config
	container.add_child(health)

	var other_component := Component.new()
	container.add_child(other_component)

	var death := DeathComponent.new()
	var death_config := DeathConfig.new()
	death_config.duration = 0.2
	death_config.fade_visual = fade_visual
	death_config.remove_actor_on_finish = false
	death.config = death_config
	container.add_child(death)

	actor._collect_components()
	death._ready()

	return {
		"actor": actor,
		"health": health,
		"other_component": other_component,
		"death": death,
		"config": death_config,
		"visual": visual
	}


func _on_died() -> void:
	_death_count += 1


func _on_respawn_scheduled(_delay: float) -> void:
	_respawn_schedule_count += 1
