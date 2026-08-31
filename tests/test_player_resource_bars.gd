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
		"res://features/inventory/items/RagePotion.tres"
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


func test_scene_uses_requested_temporary_colors_and_sits_below_health() -> void:
	var packed := load(
		"res://features/progression/ui/PlayerResourceBarsView.tscn"
	) as PackedScene
	var view := track(packed.instantiate()) as PlayerResourceBarsView
	var mana_bar := view.get_node(
		"MarginContainer/Bars/Mana/ManaBar"
	) as ProgressBar
	var experience_bar := view.get_node(
		"MarginContainer/Bars/Experience/ExperienceBar"
	) as ProgressBar
	var stamina_bar := view.get_node(
		"MarginContainer/Bars/Stamina/StaminaBar"
	) as ProgressBar
	var rage_bar := view.get_node(
		"MarginContainer/Bars/Rage/RageBar"
	) as ProgressBar
	var mana_fill := mana_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var experience_fill := (
		experience_bar.get_theme_stylebox("fill") as StyleBoxFlat
	)
	var stamina_fill := stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var rage_fill := rage_bar.get_theme_stylebox("fill") as StyleBoxFlat

	assert_eq(view.offset_left, 16.0)
	assert_eq(view.offset_top, 82.0)
	assert_eq(mana_fill.bg_color, Color(0.12, 0.42, 0.95, 1.0))
	assert_eq(experience_fill.bg_color, Color(0.94, 0.94, 0.98, 1.0))
	assert_eq(stamina_fill.bg_color, Color(0.2, 0.75, 0.3, 1.0))
	assert_eq(rage_fill.bg_color, Color(1.0, 0.45, 0.08, 1.0))
