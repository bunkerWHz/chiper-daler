extends SceneTree
## Run: godot --headless --path . --script tests/green_forest_tileset_check.gd

const BITS = [
	TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_LEFT_SIDE, TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
]
const OFFSETS = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]
var failures := 0


func _initialize() -> void:
	var tiles := load("res://assets/tilesets/green_forest/GreenForestTileSet.tres") as TileSet
	_check(tiles != null, "TileSet loads")
	if tiles == null:
		quit(1)
		return
	_check(tiles.get_terrain_sets_count() == 1, "One terrain set")
	_check(tiles.get_terrain_set_mode(0) == TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES,
		"Terrain matches corners and sides")
	var atlas := tiles.get_source(0) as TileSetAtlasSource
	var masks := {}
	for index in range(atlas.get_tiles_count()):
		var data := atlas.get_tile_data(atlas.get_tile_id(index), 0)
		if data.terrain_set != 0:
			continue
		var mask := 0
		for bit in range(8):
			if data.get_terrain_peering_bit(BITS[bit]) == 0:
				mask |= 1 << bit
		_check(not masks.has(mask), "Unique terrain mask %s" % mask)
		masks[mask] = true
	# All 47 valid blob masks: a diagonal is solid only when both adjacent sides are solid.
	for mask in range(256):
		var valid := true
		for bit in [1, 3, 5, 7]:
			if mask & (1 << bit) and (not mask & (1 << (bit - 1)) or not mask & (1 << ((bit + 1) % 8))):
				valid = false
		_check(masks.has(mask) == valid, "Complete valid mask coverage %s" % mask)
	for coord in [Vector2i(0, 6), Vector2i(1, 6)]:
		_check(atlas.get_tile_data(coord, 0).terrain_set == -1, "Decorative holes excluded")
	_check(tiles.get_patterns_count() == 8, "Eight patterns")
	for index in range(tiles.get_patterns_count()):
		var pattern := tiles.get_pattern(index)
		var layer := TileMapLayer.new()
		layer.tile_set = tiles
		layer.set_pattern(Vector2i.ZERO, pattern)
		_verify_cells(layer, pattern.get_used_cells(), "Pattern %s" % index)
		layer.free()
	# Independent layouts exercise isolated cells, corners, narrow passages and holes.
	var random := RandomNumberGenerator.new()
	random.seed = 73829
	for trial in range(40):
		var cells: Array[Vector2i] = []
		for y in range(10):
			for x in range(10):
				if random.randf() < 0.65:
					cells.append(Vector2i(x, y))
		var layer := TileMapLayer.new()
		layer.tile_set = tiles
		layer.set_cells_terrain_connect(cells, 0, 0, false)
		_verify_cells(layer, cells, "Terrain layout %s" % trial)
		layer.free()
	if failures == 0:
		print("PASS: 47 terrain masks, 8 patterns, 40 terrain layouts")
	quit(0 if failures == 0 else 1)


func _verify_cells(layer: TileMapLayer, cells: Array[Vector2i], context: String) -> void:
	_check(layer.get_used_cells().size() == cells.size(), context + ": no extra tiles")
	for cell in cells:
		var data := layer.get_cell_tile_data(cell)
		_check(data != null, context + ": no missing tiles")
		if data == null:
			continue
		for bit in range(8):
			var solid := cells.has(cell + OFFSETS[bit])
			if bit % 2 == 1:
				solid = solid and cells.has(cell + OFFSETS[bit - 1]) and cells.has(cell + OFFSETS[(bit + 1) % 8])
			_check(data.get_terrain_peering_bit(BITS[bit]) == (0 if solid else -1),
				"%s: %s neighbor %s" % [context, cell, bit])


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
