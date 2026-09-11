extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sandbox = load("res://tests/EnemyPlatformSandbox.tscn").instantiate()
	root.add_child(sandbox)
	sandbox.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	await process_frame
	var count: int = sandbox.enemy_scenes.size()
	assert(count == 10)
	for index: int in count:
		var enemy: Actor = sandbox.current_enemy
		assert(is_instance_valid(enemy))
		assert(enemy.scene_file_path == sandbox.enemy_scenes[index].resource_path)
		assert(sandbox.get_node("Enemy") == enemy)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		var health := enemy.get_component(HealthComponent) as HealthComponent
		var death := enemy.get_component(DeathComponent) as DeathComponent
		health.take_damage(health.get_max_health())
		assert(sandbox.current_enemy == enemy)
		death._process(death.config.duration)
		await process_frame
		await process_frame
	assert(sandbox.current_enemy.scene_file_path == sandbox.enemy_scenes[0].resource_path)
	sandbox.free()
	await process_frame
	print("PASS: all 10 monsters spawn after death, then the sequence restarts")
	quit()
