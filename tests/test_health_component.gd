@tool
extends McpTestSuite

var _death_count: int = 0


func suite_name() -> String:
	return "health"


func setup() -> void:
	_death_count = 0


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


func _create_health(max_health: float) -> HealthComponent:
	var actor := track(Actor.new()) as Actor
	var health := HealthComponent.new()
	var config := HealthConfig.new()
	config.max_health = max_health
	health.config = config
	actor.add_child(health)
	health.initialize(actor)
	return health


func _on_died() -> void:
	_death_count += 1
