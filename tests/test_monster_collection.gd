@tool
extends McpTestSuite

const MONSTERS = {
	"BogStinger": 1, "CaveImp": 3, "VenomHowler": 4, "EmberEye": 5,
	"HornedWretch": 7, "AshRaptor": 8, "MossCrawler": 9, "RustCyclops": 10,
}

func suite_name() -> String:
	return "monster_collection"

func test_new_monsters_have_complete_art_and_working_compositions() -> void:
	for monster_name: String in MONSTERS:
		var directory := "res://game/enemy/monsters/" + monster_name.to_snake_case()
		var monster := track((load(directory.path_join(monster_name + ".tscn")) as PackedScene).instantiate()) as Actor
		assert_eq(EnemyAuthoringChecks.inspect_scene(monster), PackedStringArray())
		var art := "res://assets/Enemies/Monster_%d/PNG Sequences" % MONSTERS[monster_name]
		var flying := DirAccess.dir_exists_absolute(art.path_join("Fly"))
		assert_eq(monster.has_node("_Components/EnemyFlightComponent"), flying)
		assert_eq(monster.has_node("_Components/EnemyMovementComponent"), not flying)
		var sprite := monster.get_node("_Visual/AnimatedSprite2D") as AnimatedSprite2D
		assert_eq(sprite.scale, Vector2.ONE)
		var player := monster.get_node("_Visual/AnimationPlayer") as AnimationPlayer
		for clip: StringName in EnemyAuthoringChecks.CLIPS:
			assert_eq(sprite.sprite_frames.get_frame_count(clip), 18)
			assert_eq(sprite.sprite_frames.get_animation_speed(clip), 18.0)
			assert_eq(player.get_animation(clip).length, 1.0)
			for index: int in 18:
				assert_true(sprite.sprite_frames.get_frame_texture(clip, index).resource_path.begins_with(art))
				assert_eq(sprite.sprite_frames.get_frame_texture(clip, index).get_size(), sprite.sprite_frames.get_frame_texture(&"idle", 0).get_size())
		var expected_move := "/Fly/" if flying else "/Walking/"
		assert_contains(sprite.sprite_frames.get_frame_texture(&"move", 0).resource_path, expected_move)
		(Engine.get_main_loop() as SceneTree).root.add_child(monster)
		monster.process_mode = Node.PROCESS_MODE_DISABLED
		for component: Component in monster.get_components():
			assert_true(component.is_enabled, monster_name + ": " + component.name)
		var attack := monster.get_component(AttackComponent) as AttackComponent
		assert_true(attack.attack())
		assert_eq(attack.get_attack_duration(), 1.0)
		var drop := monster.get_component(LootDropComponent) as LootDropComponent
		assert_true(drop.loot_entries[0].is_valid())

func test_monster_art_contains_only_png_sequences() -> void:
	for id: int in MONSTERS.values():
		var directory := "res://assets/Enemies/Monster_%d" % id
		assert_eq(DirAccess.get_directories_at(directory), PackedStringArray(["PNG Sequences"]))
		assert_eq(DirAccess.get_files_at(directory).size(), 0)
