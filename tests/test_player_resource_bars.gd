@tool
extends McpTestSuite


func suite_name() -> String:
	return "player_resource_bars"


func test_view_tracks_mana_experience_and_rage_duration() -> void:
	var packed := load("res://game/player/Player.tscn") as PackedScene
	var player := track(packed.instantiate()) as Actor
	player._collect_components()
	var magic := player.get_component(MagicComponent) as MagicComponent
	var stamina := player.get_component(StaminaComponent) as StaminaComponent
	var progression := (
		player.get_component(ProgressionComponent) as ProgressionComponent
	)
	var status_effects := (
		player.get_component(StatusEffectComponent) as StatusEffectComponent
	)
	var equipment := player.get_component(EquipmentComponent) as EquipmentComponent
	var visual := (
		player.get_component(TemporaryPlayerVisualComponent)
		as TemporaryPlayerVisualComponent
	)
	equipment._ready()
	visual._ready()
	var view := track(PlayerResourceBarsView.new()) as PlayerResourceBarsView
	view.bind_components(magic, stamina, progression, status_effects)

	assert_eq(view.get_displayed_mana(), magic.get_max_mana())
	magic.restore_runtime_state(40.0)
	assert_eq(view.get_displayed_mana(), 40.0)
	assert_true(stamina.spend(30.0))
	assert_eq(view.get_displayed_stamina(), 70.0)
	progression.gain_experience(25)
	assert_eq(view.get_displayed_experience(), 25)
	assert_eq(
		view.get_displayed_required_experience(),
		progression.get_experience_required()
	)

	var rage_item := load(
		"res://game/items/consumables/RagePotion.tres"
	) as ItemData
	assert_true(status_effects.apply_effect(rage_item.get_status_effect()))
	view._process(0.0)
	assert_eq(view.get_displayed_rage(), 10.0)
	assert_eq(view.get_displayed_max_rage(), 10.0)
	status_effects._process(4.0)
	view._process(0.0)
	assert_eq(view.get_displayed_rage(), 6.0)
	status_effects.remove_effect(&"rage")
	assert_eq(view.get_displayed_rage(), 0.0)


func test_resource_bars_have_distinct_labels_and_visible_ranges() -> void:
	var packed := load(
		"res://features/progression/ui/PlayerResourceBarsView.tscn"
	) as PackedScene
	var view := track(packed.instantiate()) as PlayerResourceBarsView
	var titles := PackedStringArray()
	for resource_name: String in ["Mana", "Experience", "Stamina", "Rage"]:
		var row := view.get_node("MarginContainer/Bars/" + resource_name)
		var title := row.get_node("Header/Title") as Label
		var bar := row.get_node(resource_name + "Bar") as ProgressBar
		assert_false(title.text.is_empty())
		assert_false(titles.has(title.text))
		titles.append(title.text)
		assert_true(title.visible)
		assert_true(bar.visible)
		assert_true(bar.max_value > bar.min_value)
