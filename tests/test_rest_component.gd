@tool
extends McpTestSuite

var _rest_finished_count: int = 0


class ActiveBehaviorComponent:
	extends Component


	func is_exclusive_behavior_active() -> bool:
		return true


func suite_name() -> String:
	return "rest"


func test_rest_point_heals_and_reports_resting_state() -> void:
	PlayerRespawnComponent.clear_saved_checkpoints()
	var player := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	player.add_child(components)

	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	var effects := StatusEffectComponent.new()
	var respawn := PlayerRespawnComponent.new()
	respawn.config = PlayerRespawnConfig.new()
	var rest := RestComponent.new()
	rest.config = RestConfig.new()
	var state := ActorStateComponent.new()
	for component: Component in [health, effects, respawn, rest, state]:
		components.add_child(component)
	player._collect_components()
	health.take_damage(40.0)
	var buff := StatusEffect.new()
	buff.effect_id = &"blessing"
	var debuff := StatusEffect.new()
	debuff.effect_id = &"poison"
	debuff.polarity = StatusEffect.Polarity.DEBUFF
	effects.apply_effect(buff)
	effects.apply_effect(debuff)

	var point := track(RestPoint.new()) as RestPoint
	point.global_position = Vector2(120.0, 80.0)
	var point_components := Node2D.new()
	point_components.name = "_Components"
	point.add_child(point_components)
	var interactable := InteractableComponent.new()
	point_components.add_child(interactable)
	point._collect_components()
	point._ready()

	interactable.interact(player)
	state.refresh_state()
	assert_eq(health.get_current_health(), health.get_max_health())
	assert_true(effects.has_effect(&"blessing"))
	assert_false(effects.has_effect(&"poison"))
	assert_eq(
		respawn.get_checkpoint_position(),
		point.global_position + point.spawn_offset
	)
	assert_true(rest.is_resting())
	assert_eq(state.get_state(), ActorState.Behavior.RESTING)
	assert_false(rest.start_rest())

	rest._process(rest.config.duration)
	state.refresh_state()
	assert_false(rest.is_resting())
	assert_eq(state.get_state(), ActorState.Behavior.IDLE)


func test_disabling_rest_finishes_the_active_condition_once() -> void:
	_rest_finished_count = 0
	var player := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	player.add_child(components)
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	var rest := RestComponent.new()
	rest.config = RestConfig.new()
	components.add_child(health)
	components.add_child(rest)
	player._collect_components()
	rest.rest_finished.connect(_on_rest_finished)

	assert_true(rest.start_rest())
	rest.disable()
	assert_false(rest.is_resting())
	assert_eq(_rest_finished_count, 1)
	rest.disable()
	assert_eq(_rest_finished_count, 1)


func test_rest_does_not_start_during_another_exclusive_behavior() -> void:
	var player := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	player.add_child(components)
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	var active_behavior := ActiveBehaviorComponent.new()
	var rest := RestComponent.new()
	rest.config = RestConfig.new()
	components.add_child(health)
	components.add_child(active_behavior)
	components.add_child(rest)
	player._collect_components()

	assert_false(rest.start_rest())
	assert_false(rest.is_resting())


func _on_rest_finished() -> void:
	_rest_finished_count += 1

func test_rest_refills_mana_and_rejected_rest_does_not() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var player := track(preload("res://game/player/Player.tscn").instantiate()) as Actor
	tree.root.add_child(player)
	var magic := player.get_component(MagicComponent) as MagicComponent
	var rest := player.get_component(RestComponent) as RestComponent
	var health := player.get_component(HealthComponent) as HealthComponent
	magic.restore_runtime_state(0.0)
	health.take_damage(10.0)
	assert_true(rest.start_rest())
	assert_eq(magic.get_mana(), magic.get_max_mana())
	assert_eq(health.get_current_health(), health.get_max_health())
	magic.restore_runtime_state(1.0)
	assert_false(rest.start_rest())
	assert_eq(magic.get_mana(), 1.0)
	rest._process(rest.config.duration)
	assert_true(rest.start_rest())
	assert_eq(magic.get_mana(), magic.get_max_mana())
	tree.root.remove_child(player)


func test_rest_restores_stamina_completely() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var player := track(preload("res://game/player/Player.tscn").instantiate()) as Actor
	tree.root.add_child(player)
	var stamina := player.get_component(StaminaComponent) as StaminaComponent
	var rest := player.get_component(RestComponent) as RestComponent
	assert_true(stamina.spend(stamina.get_max_stamina() * 0.5))
	assert_true(stamina.get_stamina() < stamina.get_max_stamina())
	assert_true(rest.start_rest())
	assert_eq(stamina.get_stamina(), stamina.get_max_stamina())
	tree.root.remove_child(player)


func _descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in node.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result


func _button_with_text(menu: Node, text: String) -> Button:
	for node: Node in _descendants(menu):
		var button := node as Button
		if button != null and button.text == text:
			return button
	return null


func _has_label(menu: Node, text: String) -> bool:
	for node: Node in _descendants(menu):
		var label := node as Label
		if label != null and label.text == text:
			return true
	return false


func _shelter_visitor() -> Actor:
	var player := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	player.add_child(components)
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var progression := ProgressionComponent.new()
	progression.config = ProgressionConfig.new()
	progression.config.requirement_growth = 1.0
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	for component: Component in [inventory, progression, health]:
		components.add_child(component)
	player._collect_components()
	return player


func test_shelter_menu_shows_both_exchange_lines_and_spends_the_purse() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var player := _shelter_visitor()
	tree.root.add_child(player)
	var inventory := player.get_component(InventoryComponent) as InventoryComponent
	var progression := player.get_component(ProgressionComponent) as ProgressionComponent
	var shelter := track(RestPoint.new()) as RestPoint
	progression.gain_experience(20)
	inventory.add_amber(90)

	var menu := track(preload("res://features/rest/ShelterMenu.gd").new()) as CanvasLayer
	menu.shelter = shelter
	menu.visitor = player
	tree.root.add_child(menu)

	assert_true(_has_label(menu, "ПОВЫШЕНИЕ УРОВНЯ · 1 / 100"))
	assert_true(_has_label(menu, "Опыт: 20 / 100. До уровня 2 не хватает 80 осколков."))
	var to_next := _button_with_text(menu, "Обменять 80 осколков · уровень 2")
	var exchange_all := _button_with_text(menu, "Обменять все осколки · 90")
	assert_true(to_next != null, "Строка обмена до следующего уровня")
	assert_true(exchange_all != null, "Строка обмена всего кошелька")
	assert_false(to_next.disabled)
	assert_false(exchange_all.disabled)

	exchange_all.pressed.emit()
	assert_eq(inventory.get_amber(), 0)
	assert_eq(progression.get_level(), 2)
	assert_eq(progression.get_experience(), 10)
	assert_true(_has_label(menu, "Обменяно 90 осколков."))

	tree.root.remove_child(menu)
	menu.free()
	tree.root.remove_child(player)


func test_shelter_menu_locks_the_level_line_at_the_cap() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var player := _shelter_visitor()
	tree.root.add_child(player)
	var inventory := player.get_component(InventoryComponent) as InventoryComponent
	var progression := player.get_component(ProgressionComponent) as ProgressionComponent
	progression.config.max_level = 2
	var shelter := track(RestPoint.new()) as RestPoint
	inventory.add_amber(500)

	var menu := track(preload("res://features/rest/ShelterMenu.gd").new()) as CanvasLayer
	menu.shelter = shelter
	menu.visitor = player
	tree.root.add_child(menu)

	var exchange_all := _button_with_text(menu, "Обменять все осколки · 100")
	assert_true(exchange_all != null, "На потолке обмен берёт только остаток до него")
	exchange_all.pressed.emit()
	assert_eq(inventory.get_amber(), 400)
	assert_eq(progression.get_level(), 2)
	assert_true(_has_label(menu, "ПОВЫШЕНИЕ УРОВНЯ · 2 / 2"))
	assert_true(
		_has_label(
			menu,
			"Достигнут максимальный уровень. Осколки остаются валютой убежища."
		)
	)
	assert_true(_button_with_text(menu, "Обменять все осколки · 0") == null)

	tree.root.remove_child(menu)
	menu.free()
	tree.root.remove_child(player)
