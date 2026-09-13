extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sandbox = load("res://tests/EnemyPlatformSandbox.tscn").instantiate()
	# Let deferred spawning run, but keep actors still while checking positions.
	sandbox.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(sandbox)
	await process_frame
	var first := sandbox.get_node_or_null("Enemy") as Actor
	if first == null or first != sandbox.current_enemy:
		_fail(sandbox, "The sandbox did not spawn its first queued enemy")
		return
	if first.scene_file_path != sandbox.enemy_scenes[0].resource_path:
		_fail(sandbox, "The sandbox spawned the wrong first enemy")
		return
	if not first.global_position.is_equal_approx(sandbox.spawn_point.global_position):
		_fail(sandbox, "The first enemy did not spawn at EnemySpawn")
		return
	var death := first.get_component(DeathComponent) as DeathComponent
	if death == null:
		_fail(sandbox, "The queued enemy has no death component")
		return
	# Exercise the actual deferred connection used after the death animation.
	death.death_finished.emit()
	await process_frame
	var second := sandbox.get_node_or_null("Enemy") as Actor
	if second == null or second != sandbox.current_enemy:
		_fail(sandbox, "The sandbox did not spawn a replacement enemy")
		return
	if second.scene_file_path != sandbox.enemy_scenes[1].resource_path:
		_fail(sandbox, "The sandbox did not advance to its second queued enemy")
		return
	if not second.global_position.is_equal_approx(sandbox.spawn_point.global_position):
		_fail(sandbox, "The replacement enemy did not spawn at EnemySpawn")
		return
	sandbox.free()
	await process_frame
	print("PASS: sandbox spawns the first queued enemy and advances after death")
	quit(0)


func _fail(sandbox: Node, message: String) -> void:
	sandbox.free()
	push_error(message)
	quit(1)
