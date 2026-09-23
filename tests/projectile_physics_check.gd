extends SceneTree

## Physics-driven projectile behaviour: a real arrow sticking into real geometry
## and piercing a real target. The rule table itself is covered by
## `tests/test_projectile.gd`; this check runs the same rules through the physics
## server, where `body_entered` and `monitoring` actually matter.
##
## Run with:
##   godot --headless --path . --script tests/projectile_physics_check.gd

const ARROW_SCENE := "res://game/items/ammunition/TrainingArrows.tscn"
const HURTBOX_SCENE := "res://features/combat/HurtboxComponent.tscn"

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


func _actor(with_hurtbox: bool) -> Actor:
	var actor := Actor.new()
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	health.config.max_health = 100.0
	components.add_child(health)
	if with_hurtbox:
		components.add_child((load(HURTBOX_SCENE) as PackedScene).instantiate())
	actor._collect_components()
	return actor


func _hurtbox_shape(actor: Actor) -> CollisionShape2D:
	var hurtbox := actor.get_component(HurtboxComponent) as HurtboxComponent
	return hurtbox.get_node("Area2D/CollisionShape2D") as CollisionShape2D


func _arrow(world: Node2D, shooter: Actor, pierce: int, stick_lifetime: float) -> Projectile:
	var arrow := (load(ARROW_SCENE) as PackedScene).instantiate() as Projectile
	arrow.pierce = pierce
	arrow.stick_lifetime = stick_lifetime
	world.add_child(arrow)
	arrow.global_position = Vector2.ZERO
	arrow.setup_direction(shooter, Vector2.RIGHT, 900.0, 10.0, 0.0, 5.0)
	return arrow


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(40, 600)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	wall.position = Vector2(300, 0)
	world.add_child(wall)

	var shooter := _actor(false)
	shooter.global_position = Vector2(-400, 0)
	world.add_child(shooter)

	# An arrow that meets only geometry stays there and stops watching for hits.
	var stuck := _arrow(world, shooter, 0, 5.0)
	for frame in 30:
		await physics_frame
	_check(is_instance_valid(stuck), "A sticking arrow must stay in the world")
	if is_instance_valid(stuck):
		_check(stuck.get_parent() == world, "A sticking arrow must keep its parent")
		_check(not stuck.is_physics_processing(), "A stuck arrow must stop flying")
		_check(not stuck.monitoring, "A stuck arrow must stop watching for hits")
		_check(
			absf(stuck.global_position.x - 270.0) < 30.0,
			"The arrow must stop at the wall: x=" + str(stuck.global_position.x)
		)

	# It despawns on its own timer instead of piling up in the level.
	var short_lived := _arrow(world, shooter, 0, 0.1)
	for frame in 30:
		await physics_frame
	_check(not is_instance_valid(short_lived), "A stuck arrow must despawn after stick_lifetime")

	# Piercing spends one target and then stops in the wall behind it.
	var target := _actor(true)
	target.global_position = Vector2(150, 0)
	world.add_child(target)
	(_hurtbox_shape(target).shape as RectangleShape2D).size = Vector2(80, 300)
	var health := target.get_component(HealthComponent) as HealthComponent
	var piercing := _arrow(world, shooter, 1, 5.0)
	for frame in 40:
		await physics_frame
	_check(health.get_current_health() == 90.0, "A piercing arrow must damage the target once")
	_check(is_instance_valid(piercing), "A piercing arrow must fly on through its target")
	if is_instance_valid(piercing):
		_check(not piercing.is_physics_processing(), "The piercing arrow must finally stick in the wall")

	# Without pierce the same shot is spent on the target instead.
	var plain_target := _actor(true)
	plain_target.global_position = Vector2(150, 0)
	world.add_child(plain_target)
	(_hurtbox_shape(plain_target).shape as RectangleShape2D).size = Vector2(80, 300)
	var plain := _arrow(world, shooter, 0, 5.0)
	for frame in 40:
		await physics_frame
	_check(not is_instance_valid(plain), "An arrow without pierce must be spent on its target")

	print("Projectile runtime: ", "FAIL" if _failed else "PASS")
	world.queue_free()
	await process_frame
	quit(1 if _failed else 0)
