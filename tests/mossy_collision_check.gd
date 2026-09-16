extends SceneTree
## Run: godot --headless --path . --script tests/mossy_collision_check.gd

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var solid := load("res://assets/tilesets/mossy/MossyTileSet.tres") as TileSet
	var platforms := load("res://assets/tilesets/mossy/MossyOneWayTileSet.tres") as TileSet
	var workshop: Node = load("res://levels/workshops/TileSetWorkshop.tscn").instantiate()
	_check(workshop.get_node("Terrain/Solid").tile_set == solid, "Workshop uses shared solid resource")
	_check(workshop.get_node("Terrain/OneWayPlatforms").tile_set == platforms, "Workshop uses shared one-way resource")
	for path in ["Terrain/BackDecor", "Terrain/FrontDecor"]:
		_check(not workshop.get_node(path).collision_enabled, "Workshop decoration disables physics")
	workshop.free()
	for tiles in [solid, platforms]:
		_check(tiles.get_physics_layers_count() == 1, "One physics layer")
		_check(tiles.get_physics_layer_collision_layer(0) == 1, "World layer 1")
		var atlas := tiles.get_source(0) as TileSetAtlasSource
		for index in range(atlas.get_tiles_count()):
			var data := atlas.get_tile_data(atlas.get_tile_id(index), 0)
			_check(data.get_collision_polygons_count(0) > 0, "Every tile has collision")
			for polygon in range(data.get_collision_polygons_count(0)):
				var points := data.get_collision_polygon_points(0, polygon)
				_check(not Geometry2D.triangulate_polygon(points).is_empty(), "Valid polygon")
				_check(data.is_collision_polygon_one_way(0, polygon) == (tiles == platforms),
					"Solid and one-way behavior remain separate")
	var world := Node2D.new()
	root.add_child(world)
	var floor_layer := _layer(world, solid)
	floor_layer.set_pattern(Vector2i.ZERO, solid.get_pattern(0))
	floor_layer.set_cell(Vector2i(12, 0), 0, Vector2i(0, 6))
	floor_layer.set_cell(Vector2i(14, 0), 0, Vector2i(1, 6))
	var one_way := _layer(world, platforms)
	one_way.set_pattern(Vector2i(6, 0), platforms.get_pattern(0))
	var decor := _layer(world, solid)
	decor.collision_enabled = false
	decor.set_pattern(Vector2i(16, 0), solid.get_pattern(0))
	for layer in [floor_layer, one_way, decor]:
		layer.update_internals()
	await physics_frame
	await physics_frame
	var space := world.get_world_2d().direct_space_state
	# A flat surface across all top seams, inset from transparent grass tips.
	for x in range(160, 1376, 16):
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(x, -100), Vector2(x, 300), 1))
		_check(not hit.is_empty() and absf(hit.position.y - 64.0) < 0.1, "Continuous flat ground at x=%s" % x)
	_check(_point(space, Vector2(16, 16)).is_empty(), "Transparent outer corner is empty")
	_check(_point(space, Vector2(16 * 512 + 256, 256)).is_empty(), "Decoration has no collision")
	for x in [12, 14]:
		_check(_point(space, Vector2(x * 512 + 256, 256)).is_empty(), "Hole stays open")
		_check(not _point(space, Vector2(x * 512 + 256, 80)).is_empty(), "Hole rim stays solid")
	# Same layer/mask as the player. Actual body sweeps exercise Godot physics.
	var body := CharacterBody2D.new()
	body.collision_layer = 8
	body.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(32, 48)
	shape.shape = rectangle
	body.add_child(shape)
	world.add_child(body)
	body.position = Vector2(256, -100)
	var landing := body.move_and_collide(Vector2(0, 500))
	_check(landing != null and landing.get_normal().y < -0.9, "Player lands on solid terrain")
	_check(body.move_and_collide(Vector2(1024, 0)) == null, "Player crosses tile seams without snagging")
	_check(body.move_and_collide(Vector2(0, 4)) != null, "Player still supported after crossing seams")
	body.position = Vector2(-100, 768)
	_check(body.move_and_collide(Vector2(500, 0)) != null, "Solid wall blocks the player")
	body.position = Vector2(768, 1800)
	_check(body.move_and_collide(Vector2(0, -600)) != null, "Solid ceiling blocks the player")
	body.position = Vector2(8 * 512 + 256, 300)
	_check(body.move_and_collide(Vector2(0, -500)) == null, "One-way platform allows upward passage")
	landing = body.move_and_collide(Vector2(0, 500))
	_check(landing != null and landing.get_normal().y < -0.9, "One-way platform catches downward motion")
	# A falling item uses a different layer but the same world mask.
	var item := RigidBody2D.new()
	item.collision_layer = 0
	item.collision_mask = 1
	item.lock_rotation = true
	# The project uses per-object gravity; global gravity is intentionally zero.
	item.constant_force = Vector2(0, 980)
	var item_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12
	item_shape.shape = circle
	item.add_child(item_shape)
	item.position = Vector2(768, -80)
	world.add_child(item)
	for frame in range(100):
		await physics_frame
	_check(absf(item.position.y - 52) < 3, "Falling loot rests on ground (actual y=%s)" % item.position.y)
	world.queue_free()
	if failures == 0:
		print("PASS: tile polygons, ground seams, walls, ceilings, open holes, decoration, one-way passage, falling loot")
	quit(0 if failures == 0 else 1)


func _layer(parent: Node2D, tiles: TileSet) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = tiles
	layer.navigation_enabled = false
	parent.add_child(layer)
	return layer


func _point(space: PhysicsDirectSpaceState2D, position: Vector2) -> Array[Dictionary]:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = position
	query.collision_mask = 1
	return space.intersect_point(query)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
