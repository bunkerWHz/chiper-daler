extends SceneTree

## Проверяет отладочный журнал боя: цвета строк, состояние боя, регенерацию и
## нанесённый урон приходят из настоящих компонентов Player.tscn.

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player := preload("res://game/player/Player.tscn").instantiate() as Actor
	world.add_child(player)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame

	var health := player.get_component(HealthComponent) as HealthComponent
	var regen := player.get_component(RegenerationComponent) as RegenerationComponent
	var log_component := (
		player.get_component(DebugCombatLogComponent) as DebugCombatLogComponent
	)
	var panel := player.get_node("_Components/DebugCombatLogComponent/CanvasLayer/Panel") as Control
	var state_label := panel.get_node("Margin/Rows/State") as Label

	check(log_component != null, "Player carries DebugCombatLogComponent")
	if log_component == null:
		quit(1)
		return

	check(is_equal_approx(panel.modulate.a, 0.3), "Panel is drawn at 30% opacity")
	check(panel.visible, "Panel starts visible")
	check(
		panel.anchor_top == 1.0 and panel.anchor_bottom == 1.0
		and panel.anchor_left == 0.0 and panel.anchor_right == 0.0,
		"Panel is anchored to the bottom-left corner"
	)
	var viewport_size := root.get_visible_rect().size
	var panel_rect := panel.get_global_rect()
	check(
		panel_rect.position.x < 40.0 and panel_rect.end.y > viewport_size.y - 40.0,
		"Panel is drawn in the bottom-left corner: " + str(panel_rect)
	)
	var log_view := panel.get_node("Margin/Rows/Log") as RichTextLabel
	check(log_view.size.y > 0.0, "Log view has a size: " + str(log_view.size))
	log_component._process(0.0)
	check(
		state_label.text.contains("ВНЕ БОЯ"),
		"Out of combat is reported on the first frame"
	)

	var mana := player.get_component(MagicComponent) as MagicComponent
	var stamina := player.get_component(StaminaComponent) as StaminaComponent
	mana._set_mana(10.0)
	check(stamina.spend(90.0), "Stamina is spent for the regeneration check")
	check(
		not regen.is_in_combat(),
		"Spending mana and stamina does not start combat"
	)
	health.take_damage(30.0)
	var health_after := health.get_current_health()
	log_component._process(0.0)
	check(regen.is_in_combat(), "Taking damage starts combat")
	check(
		state_label.text.contains("В БОЮ") and state_label.text.contains("реген ×1.0"),
		"In-combat state and combat rate are shown: " + state_label.text
	)
	var taken_line := _find_line(log_component, "урон по мне")
	check(taken_line.contains("[color=#ff5c5c]"), "Taken damage is red")
	check(taken_line.contains("−30"), "Taken damage prints its amount: " + taken_line)
	check(
		taken_line.contains("осталось %.0f" % health_after),
		"Taken damage prints the remainder: " + taken_line
	)

	regen._process(1.0)
	var regen_line := _find_line(log_component, "реген")
	check(regen_line.contains("[color=#6bff6b]"), "Regeneration is green")
	check(regen_line.contains("+1 HP"), "Health regeneration is printed: " + regen_line)
	check(regen_line.contains("+1 MP"), "Mana regeneration is printed: " + regen_line)
	check(
		regen_line.contains("+1 SP"),
		"Stamina regeneration is printed: " + regen_line
	)

	var dummy := _create_target("Dummy")
	world.add_child(dummy.actor)
	await process_frame
	dummy.hurtbox.receive_hit(HitData.new(42.0, player, Vector2.ZERO, true))
	var dealt_line := _find_line(log_component, "мой урон")
	check(dealt_line.contains("[color=#ffffff]"), "Dealt damage is white")
	check(dealt_line.contains("Dummy: 42"), "Dealt damage names the target")
	check(dealt_line.contains("КРИТ"), "Critical hits are marked")
	var shown := log_view.get_parsed_text()
	check(not shown.contains("[color="), "BBCode is parsed, not shown raw")
	check(shown.contains("мой урон"), "Dealt damage line is rendered")

	var before := log_component.get_lines().size()
	dummy.hurtbox.receive_hit(HitData.new(42.0, dummy.actor))
	check(
		log_component.get_lines().size() == before,
		"Damage from another actor is not logged as dealt by the player"
	)
	var taken_before := log_component.get_lines().size()
	player.get_component(HurtboxComponent).receive_hit(
		HitData.new(5.0, dummy.actor)
	)
	check(
		log_component.get_lines().size() == taken_before + 1,
		"Incoming hit is logged exactly once"
	)

	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(
			"res://.godot/debug_combat_log_preview.png"
		)

	regen._process(10.0)
	log_component._process(0.0)
	check(not regen.is_in_combat(), "Combat expires after the timeout")
	check(
		state_label.text.contains("ВНЕ БОЯ") and state_label.text.contains("реген ×2.0"),
		"Peaceful rate is shown after combat: " + state_label.text
	)
	check(
		_find_line(log_component, "БОЙ ЗАКОНЧИЛСЯ").contains("БОЙ ЗАКОНЧИЛСЯ"),
		"Combat end is written to the log"
	)

	var lines := log_component.get_lines()
	check(lines.size() <= log_component.max_lines, "Log keeps only the last lines")
	check(
		log_view.get_parsed_text().contains("реген"),
		"Log text is still rendered after rotation"
	)
	check(
		log_view.get_content_height() <= log_view.size.y + 1.0,
		"Full log fits the panel without clipping: %.1f in %.1f" % [
			log_view.get_content_height(),
			log_view.size.y,
		]
	)

	world.queue_free()
	await process_frame
	print("Debug combat log checks: ", failures, " failures")
	quit(1 if failures else 0)


func _find_line(log_component: DebugCombatLogComponent, needle: String) -> String:
	var lines := log_component.get_lines()

	for index in range(lines.size() - 1, -1, -1):
		if lines[index].contains(needle):
			return lines[index]

	failures += 1
	push_error("No log line contains: " + needle)
	return ""


func _create_target(target_name: String) -> Dictionary:
	var actor := Actor.new()
	actor.name = target_name
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var health := HealthComponent.new()
	var config := HealthConfig.new()
	config.max_health = 100.0
	health.config = config
	container.add_child(health)

	var hurtbox := HurtboxComponent.new()
	container.add_child(hurtbox)
	actor._collect_components()

	return {"actor": actor, "health": health, "hurtbox": hurtbox}
