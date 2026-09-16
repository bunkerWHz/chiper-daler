extends SceneTree
## godot --headless --path . --script tests/cave_tileset_check.gd

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var solid := load("res://assets/tilesets/cave/CaveTileSet.tres") as TileSet
	var platforms := load("res://assets/tilesets/cave/CaveOneWayTileSet.tres") as TileSet
	var decor := load("res://assets/tilesets/cave/CaveDecorTileSet.tres") as TileSet
	var trim := load("res://assets/tilesets/cave/CaveTrimTileSet.tres") as TileSet
	var fill := load("res://assets/tilesets/cave/CaveFillTileSet.tres") as TileSet
	var workshop: Node = load("res://levels/workshops/CaveTileSetWorkshop.tscn").instantiate()
	for entry in [[solid,11,"StandalonePlatforms",11],[platforms,11,"OneWayPlatforms",11],
		[decor,63,"BackDecor",63],[trim,26,"Trim",26],[fill,1,"Solid",5]]:
		var tiles: TileSet = entry[0]
		_check(tiles.get_source_count() == entry[1], "Piece count: " + entry[2])
		_check(tiles.get_patterns_count() == entry[3], "Pattern count: " + entry[2])
		_check(tiles.get_terrain_sets_count() == 0, "No unsupported auto-connect")
		_check(workshop.get_node("Terrain/" + entry[2]).tile_set == tiles, "External resource link")
		if tiles in [decor,trim]:
			_check(tiles.get_physics_layers_count() == 0, "Decoration has no physics")
		else:
			_check(tiles.get_physics_layer_collision_layer(0) == 1, "World collision layer")
		for index in range(tiles.get_source_count()):
			var id := tiles.get_source_id(index)
			var source := tiles.get_source(id) as TileSetAtlasSource
			var region := source.get_tile_texture_region(Vector2i.ZERO)
			_check(Rect2i(Vector2i.ZERO, source.texture.get_size()).encloses(region), "Crop stays inside image")
			_check(source.get_tiles_count() == 1, "One complete piece per source")
			var pattern := tiles.get_pattern(index)
			_check(pattern.get_cell_source_id(Vector2i.ZERO) == id, "Pattern points to its piece")
			if tiles in [decor,trim]:
				continue
			var data := source.get_tile_data(Vector2i.ZERO,0)
			_check(data.get_collision_polygons_count(0) > 0, "Solid piece has collision")
			for polygon in range(data.get_collision_polygons_count(0)):
				_check(data.is_collision_polygon_one_way(0,polygon) == (tiles == platforms), "Correct one-way flag")
				var points := data.get_collision_polygon_points(0,polygon)
				_check(not Geometry2D.triangulate_polygon(points).is_empty(), "Valid polygon")
				for point in points:
					_check(absf(point.x) <= region.size.x/2.0 and absf(point.y) <= region.size.y/2.0,
						"Collision stays inside native artwork bounds")
	_check(not workshop.get_node("Terrain/BackDecor").collision_enabled, "Back decor disabled")
	_check(not workshop.get_node("Terrain/FrontDecor").collision_enabled, "Front decor disabled")
	_check(not workshop.get_node("Terrain/Trim").collision_enabled, "Trim physics disabled")
	workshop.free()
	var world := Node2D.new()
	root.add_child(world)
	var layers: Array[TileMapLayer] = []
	for tiles in [solid,platforms,decor]:
		var layer := TileMapLayer.new()
		layer.tile_set = tiles
		layer.navigation_enabled = false
		world.add_child(layer)
		for index in range(tiles.get_source_count()):
			layer.set_cell(Vector2i(index*40,layers.size()*40),tiles.get_source_id(index),Vector2i.ZERO)
		layer.update_internals()
		layers.append(layer)
	await physics_frame
	await physics_frame
	var body := CharacterBody2D.new()
	body.collision_layer = 8
	body.collision_mask = 1
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16,24)
	collision.shape = rectangle
	body.add_child(collision)
	world.add_child(body)
	for index in range(solid.get_source_count()):
		var center := layers[0].map_to_local(Vector2i(index*40,0))
		body.position = center + Vector2(0,-1200)
		var hit := body.move_and_collide(Vector2(0,2400))
		_check(hit != null, "Body lands on solid piece %s" % index)
	for index in range(platforms.get_source_count()):
		var center := layers[1].map_to_local(Vector2i(index*40,40))
		body.position = center + Vector2(0,1000)
		for step in range(80):
			_check(body.move_and_collide(Vector2(0,-25)) == null, "Pass upward through platform %s" % index)
		var hit: KinematicCollision2D
		for step in range(80):
			hit = body.move_and_collide(Vector2(0,25))
			if hit != null:
				break
		_check(hit != null and hit.get_normal().y < -0.9, "Land on platform %s" % index)
	var space := world.get_world_2d().direct_space_state
	for index in range(decor.get_source_count()):
		var center := layers[2].map_to_local(Vector2i(index*40,80))
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(center-Vector2(0,1000),center+Vector2(0,1000),1))
		_check(hit.is_empty(), "Decor does not block movement")
	# Fill is independently paintable and seals neighboring cells without gaps.
	var fill_layer := TileMapLayer.new()
	fill_layer.tile_set = fill
	fill_layer.position = Vector2(0,10000)
	world.add_child(fill_layer)
	fill_layer.set_pattern(Vector2i.ZERO,fill.get_pattern(2))
	fill_layer.update_internals()
	await physics_frame
	await physics_frame
	body.position = Vector2(64,9900)
	_check(body.move_and_collide(Vector2(0,200)) != null, "Fill supports player")
	_check(body.move_and_collide(Vector2(1000,0)) == null, "Painted fill seams do not snag")
	_check(body.move_and_collide(Vector2(0,4)) != null, "Fill supports after crossing seams")
	var structure_index := 0
	for name in ["CaveColumn","CaveLedge","CaveWall","CaveCeiling"]:
		var structure: Node2D = load("res://game/level/cave/"+name+".tscn").instantiate()
		structure.position = Vector2(0,20000+structure_index*5000)
		world.add_child(structure)
		var size: Vector2i = structure.get_meta("geometry_size")
		_check(structure.scale == Vector2.ONE, "Structure authored at unit scale")
		_check(not structure.get_node("Fill").collision_enabled, "No duplicate fill physics")
		_check(structure.get_node("Geometry").get_child_count() == 1, "One continuous collider")
		_check(structure.get_node("Geometry/CollisionShape2D").shape.size == Vector2(size), "Collider matches core")
		for sprite in structure.get_node("Trim").get_children():
			_check(sprite is Sprite2D and sprite.scale == Vector2.ONE, "Trim is native-size visual only")
		await physics_frame
		await physics_frame
		body.position = structure.position + Vector2(64,-100)
		var landing := body.move_and_collide(Vector2(0,200))
		_check(landing != null and landing.get_normal().y < -0.9, name+" top supports player")
		_check(absf(body.position.y+12-structure.position.y) < 1, "Landing aligns with top of core")
		_check(body.move_and_collide(Vector2(size.x-128,0)) == null, "No snags at trim joints")
		body.position = structure.position + Vector2(-100,size.y/2.0)
		_check(body.move_and_collide(Vector2(200,0)) != null, name+" wall blocks player")
		body.position = structure.position + Vector2(size.x/2.0,size.y+100)
		_check(body.move_and_collide(Vector2(0,-200)) != null, name+" underside blocks player")
		structure_index += 1
	world.queue_free()
	if failures == 0:
		print("PASS: Cave fill, 26 nonphysical trims, 11 solid/one-way platforms, 63 decorations, 4 continuous structures")
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
