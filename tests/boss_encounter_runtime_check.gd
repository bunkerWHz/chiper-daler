extends SceneTree

var checks := 0
var failures := 0
var starts := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var boss := load("res://game/enemy/monsters/stone_golem/StoneGolem.tscn").instantiate() as Actor
	boss.position = Vector2(500, 200)
	world.add_child(boss)
	# Keep the fixture stationary; production retains gravity during the intro.
	boss.get_component(EnemyMovementComponent).set_physics_process(false)
	var encounter := boss.get_node("BossEncounter") as BossEncounter
	encounter.intro_hold_seconds = 0.1
	encounter.intro_fade_seconds = 0.1
	encounter.combat_started.connect(func() -> void: starts += 1)
	var health := boss.get_component(HealthComponent) as HealthComponent
	var attack := boss.get_component(AttackComponent) as AttackComponent
	var hurtbox := boss.get_component(HurtboxComponent) as HurtboxComponent
	check(not boss.has_node("_Visual/HealthBar"), "No overhead boss HP")
	check(not attack.is_enabled and not hurtbox.is_enabled, "Waiting boss cannot attack or receive hits")
	var player := Actor.new()
	var components := Node.new()
	components.name = "_Components"
	player.add_child(components)
	var player_health := HealthComponent.new()
	player_health.config = HealthConfig.new()
	components.add_child(player_health)
	components.add_child(InputComponent.new())
	var body := CharacterBody2D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	body.add_child(shape)
	player.add_child(body)
	player.position = Vector2(2000, 0)
	world.add_child(player)
	await create_timer(0.05).timeout
	check(encounter.phase == BossEncounter.Phase.WAITING, "No introduction outside arena")
	player.position = boss.position
	await create_timer(0.08).timeout
	check(encounter.phase == BossEncounter.Phase.INTRO, "Physics entry starts introduction")
	check(not encounter.begin_encounter(player), "Duplicate entry rejected")
	check(not attack.is_enabled and starts == 0, "Combat waits for full intro")
	var hud := encounter.get_node("BossHUD")
	check(hud.get_node("Screen/IntroName").text == "Stone Golem", "Configured boss name shown")
	check(not hud.get_node("Screen/Health").visible, "HP waits for introduction")
	var hit := HitData.new(20, player)
	check(hurtbox.receive_hit(hit) == 0, "Actual damage blocked during intro")
	paused = true
	await create_timer(0.4, true).timeout
	check(encounter.phase == BossEncounter.Phase.INTRO, "Pause also pauses introduction")
	paused = false
	await create_timer(0.4).timeout
	check(starts == 1 and encounter.phase == BossEncounter.Phase.COMBAT, "One combat start after fade")
	check(not hud.get_node("Screen/IntroName").visible and hud.get_node("Screen/Health").visible, "Name disappears before combat HUD")
	check(attack.is_enabled and hurtbox.is_enabled, "Combat components restored")
	health.take_damage(20)
	check(hud.get_node("Screen/Health/Bar").value == 80, "HUD tracks damage")
	health.heal(5)
	check(hud.get_node("Screen/Health/Bar").value == 85, "HUD tracks healing")
	var arena_position: Vector2 = encounter.get_node("Arena").global_position
	check(arena_position == Vector2(500, 200), "Arena inherits authored boss position")
	check(encounter.get_node("Arena").global_scale == Vector2(3, 3), "Arena uses boss root scale")
	boss.position.x += 10
	check(encounter.get_node("Arena").global_position == arena_position, "Arena does not follow moving boss")
	hurtbox.receive_hit(HitData.new(1, player, Vector2(80, -20)))
	check((boss.get_component(HitStunComponent) as HitStunComponent).is_incapacitated(), "Reset fixture includes an active stun")
	player.position.x = 2000
	await create_timer(0.8).timeout
	check(encounter.phase == BossEncounter.Phase.WAITING and not attack.is_enabled, "Leaving arena resets fight")
	check(not (boss.get_component(HitStunComponent) as HitStunComponent).is_incapacitated(), "Reset cancels stun without delayed attack restoration")
	check(health.get_current_health() == 100 and not encounter.has_node("BossHUD"), "Reset heals boss and removes HUD")
	player.position = arena_position
	await create_timer(0.08).timeout
	check(encounter.phase == BossEncounter.Phase.INTRO, "Reentry replays introduction")
	player_health.take_damage(100)
	await create_timer(0.4).timeout
	check(encounter.phase == BossEncounter.Phase.WAITING and starts == 1, "Death during intro cancels delayed combat")
	check(not encounter.has_node("BossHUD"), "Death removes screen UI")
	player_health._current_health = 100
	check(encounter.begin_encounter(player), "New living attempt accepted")
	await create_timer(0.4).timeout
	player_health.take_damage(100)
	check(encounter.phase == BossEncounter.Phase.WAITING and not attack.is_enabled, "Player death during combat suspends boss")
	await process_frame
	player_health._current_health = 100
	encounter.begin_encounter(player)
	await create_timer(0.4).timeout
	health.take_damage(100)
	await process_frame
	check(encounter.phase == BossEncounter.Phase.DEFEATED, "Boss death completes encounter")
	check(not encounter.has_node("BossHUD") and not encounter.begin_encounter(player), "Defeated boss cannot restart")
	check(get_first_node_in_group(BossEncounter.ACTIVE_GROUP) == null, "Encounter releases HUD ownership")
	var other_boss := load("res://game/enemy/monsters/stone_golem/StoneGolem.tscn").instantiate() as Actor
	other_boss.position = Vector2(4000, 0)
	world.add_child(other_boss)
	var other := other_boss.get_node("BossEncounter") as BossEncounter
	other.boss_name = "Another Boss"
	check(other.begin_encounter(player), "Shared encounter supports another boss")
	check(other.get_node("BossHUD/Screen/IntroName").text == "Another Boss", "Boss names are scene properties")
	var third_boss := load("res://game/enemy/monsters/stone_golem/StoneGolem.tscn").instantiate() as Actor
	third_boss.position = Vector2(8000, 0)
	world.add_child(third_boss)
	var third := third_boss.get_node("BossEncounter") as BossEncounter
	check(not third.begin_encounter(player), "Two bosses cannot overlap their screen UI")
	other_boss.queue_free()
	await process_frame
	check(get_first_node_in_group(BossEncounter.ACTIVE_GROUP) == null, "Removing boss during intro releases UI")
	check(third.begin_encounter(player), "Next encounter can claim released UI")
	player.queue_free()
	await process_frame
	check(third.phase == BossEncounter.Phase.WAITING, "Removing player cancels introduction")
	world.queue_free()
	await process_frame
	print("Boss encounter: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
