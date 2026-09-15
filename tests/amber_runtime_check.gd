extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(640, 600)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(1280, 20)
	shape.shape = rectangle
	floor_body.add_child(shape)
	var floor_art := Polygon2D.new()
	floor_art.polygon = PackedVector2Array([-Vector2(640, 10), Vector2(640, -10), Vector2(640, 10), Vector2(-640, 10)])
	floor_art.color = Color(0.25, 0.3, 0.32)
	floor_body.add_child(floor_art)
	world.add_child(floor_body)
	var enemy := Actor.new()
	enemy.position = Vector2(640, 350)
	var components := Node2D.new()
	components.name = "_Components"
	enemy.add_child(components)
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	components.add_child(health)
	var reward := preload("res://features/progression/ExperienceRewardComponent.tscn").instantiate()
	components.add_child(reward)
	world.add_child(enemy)
	var trigger := Area2D.new()
	trigger.position = floor_body.position
	var trigger_shape := CollisionShape2D.new()
	trigger_shape.shape = rectangle
	trigger.add_child(trigger_shape)
	trigger.body_entered.connect(func(_body: Node2D) -> void:
		health.take_damage(1000)
		reward._on_health_died()
		enemy.queue_free()
	)
	world.add_child(trigger)
	await create_timer(0.15, true, true).timeout
	trigger.queue_free()
	var pickup: AmberShardPickup
	var count := 0
	for child in world.get_children():
		if child is AmberShardPickup:
			pickup = child
			count += 1
	if count != 1:
		_fail("Death must spawn one pickup after freeing its enemy")
		return
	if pickup.position.y <= 350:
		_fail("Pickup did not fall")
		return
	await create_timer(1.0, true, true).timeout
	var bottom := pickup.position.y + 610 * 0.035 / 2
	if absf(bottom - 590) > 1.0:
		_fail("Native-sized pickup does not align with floor: %f" % bottom)
		return
	var landed := pickup.position
	await create_timer(0.2, true, true).timeout
	if pickup.position.distance_to(landed) > 0.1:
		_fail("Pickup is unstable on the floor")
		return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/amber_pickup_preview.png")
	var player := preload("res://game/player/Player.tscn").instantiate() as Actor
	player.position = Vector2(500, 560)
	world.add_child(player)
	var inventory := player.get_component(InventoryComponent) as InventoryComponent
	# Move the real player's body through the pickup sensor without an interaction action.
	player.global_position = Vector2(640, 560)
	await create_timer(0.3, true, true).timeout
	if inventory.get_amber() != 25 or is_instance_valid(pickup):
		_fail("Player overlap did not automatically collect exactly 25 amber")
		return
	var shelter := preload("res://features/rest/RestPoint.tscn").instantiate() as RestPoint
	shelter.position = player.position
	world.add_child(shelter)
	inventory.add_amber(1000)
	shelter._on_interacted_by(player)
	await process_frame
	if not paused or not is_instance_valid(shelter._menu):
		_fail("Shelter interaction did not open and pause")
		return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/amber_shelter_preview.png")
	(shelter._menu._actions.get_child(0) as Button).pressed.emit()
	if inventory.get_amber() != 925 or (player.get_component(ProgressionComponent) as ProgressionComponent).get_level() != 2:
		_fail("Shelter button did not exchange amber for a level")
		return
	shelter._menu.queue_free()
	await process_frame
	if paused:
		_fail("Shelter close did not release pause")
		return
	shelter._on_interacted_by(player)
	var inventory_menu := player.get_component(InventoryMenuComponent) as InventoryMenuComponent
	inventory_menu.open_inventory()
	await process_frame
	await process_frame
	if is_instance_valid(shelter._menu) or not paused:
		_fail("Opening inventory must replace shelter and retain inventory pause")
		return
	inventory_menu.close_inventory()
	if paused:
		_fail("Closing inventory must release the final pause")
		return
	print("PASS: deferred death drop, floor alignment, stable rest, real player auto-pickup, shelter open/close")
	world.free()
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
