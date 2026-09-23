@tool
extends McpTestSuite

## Projectiles are scenes: artwork, collision, `sticks` and `pierce` are authored
## there, while the ability passes only flight and damage numbers. These tests
## guard the wiring between ammunition data and its scene, and the impact rules
## that differ per type.
##
## Physics-driven stick and pierce behaviour over real frames is covered by
## `tests/projectile_physics_check.gd`.

const ARROW_SCENE := "res://game/items/ammunition/TrainingArrows.tscn"
const BOLT_SCENE := "res://game/items/ammunition/TrainingBolts.tscn"


func suite_name() -> String:
	return "projectile"


func _target(hp: float = 100.0) -> Actor:
	var target := track(Actor.new()) as Actor
	var container := Node.new()
	container.name = "_Components"
	target.add_child(container)
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	health.config.max_health = hp
	container.add_child(health)
	container.add_child(HurtboxComponent.new())
	target._collect_components()
	return target


func _hurtbox_area(target: Actor) -> Area2D:
	var hurtbox := target.get_component(HurtboxComponent) as HurtboxComponent
	var area := Area2D.new()
	hurtbox.add_child(area)
	return area


func _open_projectile(scene_path: String) -> Projectile:
	var projectile := track(load(scene_path).instantiate()) as Projectile
	(Engine.get_main_loop() as SceneTree).root.add_child(projectile)
	return projectile


## The code-built projectile backs effects that ship no scene of their own.
func _open_generic() -> Projectile:
	var projectile := track(Projectile.create_generic()) as Projectile
	(Engine.get_main_loop() as SceneTree).root.add_child(projectile)
	return projectile


func test_every_ammunition_ships_its_own_projectile_scene() -> void:
	for entry: Array in [[&"training_arrows", ARROW_SCENE], [&"training_bolts", BOLT_SCENE]]:
		var item := load("res://game/items/ammunition/%s.tres" % String(entry[0]).to_pascal_case()) as ItemData
		assert_true(item != null, "missing ammunition item " + String(entry[0]))
		assert_true(item.ammunition_profile.projectile_scene != null, String(entry[0]) + " has no projectile scene")
		assert_eq(item.ammunition_profile.projectile_scene.resource_path, entry[1])
		var arrow := _open_projectile(String(entry[1]))
		var sprite := arrow.get_node("ProjectileSprite") as Sprite2D
		assert_true(sprite.texture != null, String(entry[0]) + " scene has no artwork")
		var capsule := (arrow.get_node("CollisionShape2D") as CollisionShape2D).shape as CapsuleShape2D
		assert_true(capsule != null, String(entry[0]) + " must author its own hit shape")
		# A projectile is long and thin: the capsule runs along the flight axis.
		assert_true(capsule.height > capsule.radius * 2.0)
		assert_true(arrow.sticks, "arrows and bolts must stay in the world")


func test_firing_a_bow_uses_the_ammunition_scene_and_keeps_its_art() -> void:
	var setup := preload("res://tests/AimingTestFactory.gd").create()
	track(setup.root)
	preload("res://tests/AimingTestFactory.gd").select_weapon(setup, EquipmentComponent.Slot.BOW)
	setup.input._attack_just_pressed = true
	setup.ranged._process(0.0)
	setup.input._attack_released = true
	setup.ranged._process(0.0)
	var projectile: Projectile = null
	for child: Node in setup.root.get_children():
		if child is Projectile:
			projectile = child
	assert_true(projectile != null, "firing must spawn a projectile")
	assert_eq(projectile.scene_file_path, ARROW_SCENE)
	assert_true(projectile.sticks)
	assert_true((projectile.get_node("ProjectileSprite") as Sprite2D).visible, "the scene artwork must stay visible")


func test_placeholder_shows_only_without_art() -> void:
	var generic := _open_generic()
	generic.setup_direction(null, Vector2.RIGHT, 100.0, 5.0, 0.0, 10.0)
	assert_true((generic.get_node("Visual") as CanvasItem).visible)
	assert_false((generic.get_node("ProjectileSprite") as Sprite2D).visible)
	# A runtime texture replaces the placeholder, as thrown items still do.
	var arrow := _open_projectile(ARROW_SCENE)
	arrow.setup_direction(null, Vector2.RIGHT, 100.0, 5.0, 0.0, 10.0)
	assert_true((arrow.get_node("ProjectileSprite") as Sprite2D).visible)
	assert_true(arrow.get_node_or_null("Visual") == null)


func test_pierce_damages_each_target_once_and_then_stops() -> void:
	var source := _target()
	var target := _target()
	var area := _hurtbox_area(target)
	var health := target.get_component(HealthComponent) as HealthComponent
	var projectile := _open_projectile(ARROW_SCENE)
	projectile.pierce = 1
	projectile.setup_direction(source, Vector2.RIGHT, 100.0, 10.0, 0.0, 10.0)
	projectile._on_area_entered(area)
	assert_eq(health.get_current_health(), 90.0)
	assert_false(projectile.is_queued_for_deletion(), "the first hit spends one pierce")
	projectile._on_area_entered(area)
	assert_eq(health.get_current_health(), 90.0, "the same target must not be hit twice")
	var second := _hurtbox_area(_target())
	projectile._on_area_entered(second)
	assert_true(projectile.is_queued_for_deletion(), "the last target stops the projectile")


func test_a_projectile_without_pierce_stops_at_the_first_target() -> void:
	var source := _target()
	var area := _hurtbox_area(_target())
	var projectile := _open_projectile(ARROW_SCENE)
	projectile.setup_direction(source, Vector2.RIGHT, 100.0, 10.0, 0.0, 10.0)
	projectile._on_area_entered(area)
	assert_true(projectile.is_queued_for_deletion())


func test_sticking_freezes_the_projectile_instead_of_freeing_it() -> void:
	var stuck := _open_projectile(ARROW_SCENE)
	stuck.setup_direction(null, Vector2.RIGHT, 100.0, 10.0, 0.0, 10.0)
	stuck._on_body_entered(null)
	assert_false(stuck.is_queued_for_deletion(), "a sticking projectile stays in the world")
	assert_false(stuck.is_physics_processing(), "a stuck projectile stops flying")

	var passing := _open_generic()
	passing.setup_direction(null, Vector2.RIGHT, 100.0, 10.0, 0.0, 10.0)
	passing._on_body_entered(null)
	assert_true(passing.is_queued_for_deletion(), "the generic projectile still vanishes")
