extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, 160)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(400, 20)
	shape.shape = rectangle
	floor_body.add_child(shape)
	world.add_child(floor_body)
	var enemy := Actor.new()
	enemy.position = Vector2(0, 20)
	var components := Node2D.new()
	components.name = "_Components"
	enemy.add_child(components)
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	components.add_child(health)
	var drop := (load("res://features/loot/LootDropComponent.tscn") as PackedScene).instantiate() as LootDropComponent
	var entry := LootEntry.new()
	entry.item = preload("res://game/items/weapons/TrainingSword.tres")
	entry.drop_chance = 1.0
	drop.loot_entries = [entry]
	components.add_child(drop)
	world.add_child(enemy)
	# Kill from a physics query callback, matching HitboxComponent.area_entered.
	var trigger := Area2D.new()
	trigger.position = floor_body.position
	var trigger_shape := CollisionShape2D.new()
	trigger_shape.shape = rectangle
	trigger.add_child(trigger_shape)
	trigger.body_entered.connect(func(_body: Node2D) -> void:
		health.take_damage(health.get_max_health())
		drop._on_health_died()
		enemy.queue_free()
	)
	world.add_child(trigger)
	await create_timer(0.1, true, true).timeout
	var bag: LootBag
	var bag_count := 0
	for child in world.get_children():
		if child is LootBag:
			bag = child as LootBag
			bag_count += 1
	if bag_count != 1:
		_fail("Physics callback must spawn exactly one bag even when enemy is freed")
		return
	trigger.queue_free()
	var bag_shape := bag.get_node(
		"_Components/CharacterBodyComponent/CharacterBody2D/CollisionShape2D"
	) as CollisionShape2D
	var bag_rectangle := bag_shape.shape as RectangleShape2D
	var bottom_offset := bag_shape.global_position.y - bag.global_position.y
	bottom_offset += bag_rectangle.size.y * bag_shape.global_scale.y * 0.5
	var expected_landing_y := floor_body.position.y - rectangle.size.y * 0.5 - bottom_offset
	await create_timer(0.15, true, true).timeout
	if bag.global_position.y <= 20:
		_fail("Airborne loot did not fall")
		return
	await create_timer(0.85, true, true).timeout
	if absf(bag.global_position.y - expected_landing_y) > 1.0:
		_fail("Loot did not land on the floor: %s" % bag.global_position)
		return
	var landed_position := bag.global_position
	await create_timer(0.2, true, true).timeout
	if bag.global_position.distance_to(landed_position) > 0.1:
		_fail("Landed loot did not remain stable")
		return
	floor_body.queue_free()
	await create_timer(0.2, true, true).timeout
	if bag.global_position.y <= landed_position.y + 5.0:
		_fail("Loot did not fall after its support was removed")
		return
	print("PASS: loot falls, lands, stays on the floor and falls when support is removed")
	world.free()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
