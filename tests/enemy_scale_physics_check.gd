extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, 200)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4000, 20)
	collision.shape = rectangle
	floor_body.add_child(collision)
	world.add_child(floor_body)
	var enemies: Array[Actor] = []
	for multiplier: float in [1.0, 2.0]:
		var enemy := (load("res://game/enemy/monsters/stone_maw/StoneMaw.tscn") as PackedScene).instantiate() as Actor
		enemy.scale *= multiplier
		enemy.position = Vector2(multiplier * 400, 40)
		world.add_child(enemy)
		for component: Component in enemy.get_components():
			if not component is EnemyMovementComponent and not component is CharacterBodyComponent:
				component.disable()
		(enemy.get_component(EnemyMovementComponent) as EnemyMovementComponent).stop()
		enemies.append(enemy)
	await create_timer(0.8, true, true).timeout
	for index: int in enemies.size():
		var enemy := enemies[index]
		var body := enemy.get_component(CharacterBodyComponent) as CharacterBodyComponent
		var expected_y := 190.0 - 10.0 * (index + 1)
		if not body.is_on_floor() or absf(enemy.global_position.y - expected_y) > 0.2:
			_fail("Scaled enemy did not land at its body boundary")
			return
		if not body.get_body().position.is_zero_approx():
			_fail("Body drifted away from actor after movement")
			return
	var original_x := enemies[0].global_position.x
	var large_x := enemies[1].global_position.x
	for enemy: Actor in enemies:
		(enemy.get_component(EnemyMovementComponent) as EnemyMovementComponent).set_move_direction(1.0)
	await create_timer(0.3, true, true).timeout
	var distance := enemies[0].global_position.x - original_x
	var large_distance := enemies[1].global_position.x - large_x
	if distance < 25.0 or distance > 35.0 or absf(distance - large_distance) > 0.1:
		_fail("Root scale changed world movement speed")
		return
	world.free()
	print("PASS: enemies at normal and double size land correctly and move at the same world speed")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
