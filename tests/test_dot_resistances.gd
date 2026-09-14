@tool
extends McpTestSuite

var _directories: PackedStringArray = []


func suite_name() -> String:
	return "dot_resistances"


func teardown() -> void:
	for directory: String in _directories:
		for file: String in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(file))
		DirAccess.remove_absolute(directory)
	_directories.clear()


func _directory() -> String:
	var directory := "user://dot_resistances_%s" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	_directories.append(directory)
	return directory


func _effect(id: StringName) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_id = id
	effect.damage_per_tick = 10.0
	effect.duration = 3.0
	effect.polarity = StatusEffect.Polarity.DEBUFF
	return effect


func _target() -> Actor:
	var target := track(Actor.new()) as Actor
	var components := Node.new()
	components.name = "_Components"
	target.add_child(components)
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	health.config.max_health = 100.0
	components.add_child(health)
	components.add_child(StatusEffectComponent.new())
	target._collect_components()
	return target


func test_new_catalog_type_appears_in_existing_profiles_without_resetting_values() -> void:
	var catalog := DotCatalog.new()
	catalog.register_effect(_effect(&"burning"))
	var profile := DotResistances.new()
	profile.catalog = catalog
	profile.set("resistance/burning", 30.0)
	var notifications := [0]
	profile.property_list_changed.connect(func() -> void: notifications[0] += 1)
	assert_true(catalog.register_effect(_effect(&"brand_new_dot")))
	assert_eq(notifications[0], 1)
	assert_eq(profile.get_all(), {&"burning": 30.0, &"brand_new_dot": 0.0})
	var names: Array = []
	for property: Dictionary in profile.get_property_list():
		names.append(property.name)
	assert_true("resistance/brand_new_dot" in names)
	assert_false(catalog.register_effect(_effect(&"burning")))
	assert_eq(catalog.get_effect_ids().size(), 2)


func test_resistance_changes_only_matching_dot_damage_and_reads_each_tick() -> void:
	var target := _target()
	var effects := target.get_component(StatusEffectComponent) as StatusEffectComponent
	var health := target.get_component(HealthComponent) as HealthComponent
	effects.dot_resistances.set_percent(&"burning", 30.0)
	effects.apply_effect(_effect(&"burning"))
	effects.apply_effect(_effect(&"poison"))
	effects._process(1.0)
	assert_eq(health.get_current_health(), 83.0)
	assert_eq(effects.get_remaining(&"burning"), 2.0)
	effects.dot_resistances.set_percent(&"burning", 100.0)
	effects._process(1.0)
	assert_eq(health.get_current_health(), 73.0)
	assert_true(effects.has_effect(&"burning"))
	effects._process(1.0)
	assert_eq(health.get_current_health(), 63.0)
	assert_false(effects.has_debuff())


func test_full_resistance_emits_zero_tick_without_health_damage_or_death() -> void:
	var target := _target()
	var effects := target.get_component(StatusEffectComponent) as StatusEffectComponent
	var health := target.get_component(HealthComponent) as HealthComponent
	var events := [0, 0, 0]
	health.damaged.connect(func(_amount: float, _hp: float) -> void: events[0] += 1)
	health.died.connect(func() -> void: events[1] += 1)
	effects.effect_ticked.connect(func(_effect: StatusEffect, damage: float) -> void:
		assert_eq(damage, 0.0)
		events[2] += 1)
	effects.dot_resistances.set_percent(&"burning", 100.0)
	effects.apply_effect(_effect(&"burning"))
	effects._process(10.0)
	assert_eq(events, [0, 0, 3])
	assert_eq(health.get_current_health(), 100.0)
	assert_false(effects.has_debuff())


func test_missing_profile_and_unknown_type_default_to_full_damage() -> void:
	var profile := DotResistances.new()
	assert_eq(profile.reduce_damage(&"unregistered_dot", 10.0), 10.0)
	var target := _target()
	var effects := target.get_component(StatusEffectComponent) as StatusEffectComponent
	effects.dot_resistances = null
	effects.apply_effect(_effect(&"burning"))
	effects._process(1.0)
	assert_eq((target.get_component(HealthComponent) as HealthComponent).get_current_health(), 90.0)


func test_percentages_are_clamped_and_non_finite_values_do_not_corrupt_damage() -> void:
	var profile := DotResistances.new()
	profile.set_percent(&"burning", 150.0)
	assert_eq(profile.reduce_damage(&"burning", 10.0), 0.0)
	profile.set_percent(&"burning", -10.0)
	assert_eq(profile.reduce_damage(&"burning", 10.0), 10.0)
	profile.set_percent(&"burning", 30.0)
	profile.set_percent(&"burning", NAN)
	assert_eq(profile.get_percent(&"burning"), 30.0)
	profile.percentages[&"burning"] = INF
	assert_eq(profile.reduce_damage(&"burning", 10.0), 10.0)


func test_generated_dot_updates_registry_on_disk_and_existing_resistance_list() -> void:
	var directory := _directory()
	var catalog := DotCatalog.new()
	var path := directory.path_join("catalog.tres")
	assert_eq(ResourceSaver.save(catalog, path, ResourceSaver.FLAG_CHANGE_PATH), OK)
	catalog.take_over_path(path)
	var profile := DotResistances.new()
	profile.catalog = catalog
	var generator := track(DotEffectGenerator.new()) as DotEffectGenerator
	generator.effect_id = &"new_custom_dot"
	assert_eq(generator.save_effect(directory, catalog), OK)
	assert_eq(profile.get_all(), {&"new_custom_dot": 0.0})
	assert_eq(generator.save_effect(directory, catalog), ERR_ALREADY_EXISTS)
	var restored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as DotCatalog
	assert_true(restored.contains(&"new_custom_dot"))
	assert_eq(restored.effects[0].resource_path, directory.path_join("new_custom_dot.tres"))
	var dependencies := ResourceLoader.get_dependencies(path)
	assert_true("\n".join(dependencies).contains("new_custom_dot.tres"))


func test_profile_values_survive_saving_and_new_catalog_entries() -> void:
	var profile := DotResistances.new()
	profile.set("resistance/burning", 45.0)
	var path := _directory().path_join("profile.tres")
	assert_eq(ResourceSaver.save(profile, path), OK)
	var restored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as DotResistances
	assert_eq(restored.get_percent(&"burning"), 45.0)
	assert_eq(restored.get_percent(&"poison"), 0.0)
	assert_eq(restored.get_all().size(), DotResistances.DEFAULT_CATALOG.get_effect_ids().size())


func test_scene_instances_keep_resistances_independent_and_share_catalog() -> void:
	var scene := load("res://features/status/StatusEffectComponent.tscn") as PackedScene
	var first := track(scene.instantiate()) as StatusEffectComponent
	var second := track(scene.instantiate()) as StatusEffectComponent
	first.dot_resistances.set_percent(&"burning", 75.0)
	assert_eq(second.dot_resistances.get_percent(&"burning"), 0.0)
	assert_eq(first.dot_resistances.catalog, second.dot_resistances.catalog)
	assert_eq(first.dot_resistances.catalog, DotResistances.DEFAULT_CATALOG)


func test_rebuild_imports_manual_definitions_and_rejects_duplicate_ids() -> void:
	var directory := _directory()
	var catalog := DotCatalog.new()
	assert_eq(ResourceSaver.save(catalog, directory.path_join("catalog.tres"), ResourceSaver.FLAG_CHANGE_PATH), OK)
	catalog.take_over_path(directory.path_join("catalog.tres"))
	assert_eq(ResourceSaver.save(_effect(&"manual_dot"), directory.path_join("manual.tres")), OK)
	var generator := track(DotEffectGenerator.new()) as DotEffectGenerator
	assert_eq(generator.rebuild_catalog(directory, catalog), OK)
	assert_eq(catalog.get_effect_ids(), [&"manual_dot"])
	assert_eq(ResourceSaver.save(_effect(&"manual_dot"), directory.path_join("duplicate.tres")), OK)
	assert_eq(generator.rebuild_catalog(directory, catalog), ERR_INVALID_DATA)
	assert_eq(catalog.get_effect_ids(), [&"manual_dot"])


func test_project_catalog_contains_every_authored_dot() -> void:
	var catalog := DotResistances.DEFAULT_CATALOG as DotCatalog
	var ids: Array[StringName] = []
	for file: String in DirAccess.get_files_at("res://game/status"):
		if not file.ends_with(".tres"):
			continue
		var effect := load("res://game/status".path_join(file)) as StatusEffect
		if effect != null and effect.damage_per_tick > 0.0:
			assert_false(effect.effect_id in ids)
			ids.append(effect.effect_id)
	ids.sort()
	assert_eq(catalog.get_effect_ids(), ids)


func test_catalog_filters_regular_statuses_and_invalid_dot_definitions() -> void:
	var catalog := DotCatalog.new()
	var regular := _effect(&"buff")
	regular.damage_per_tick = 0.0
	assert_false(catalog.register_effect(regular))
	var invalid := _effect(&"invalid")
	invalid.tick_interval = 0.0
	assert_false(catalog.register_effect(invalid))
	invalid.tick_interval = 1.0
	invalid.duration = NAN
	assert_false(catalog.register_effect(invalid))
	catalog.effects = [regular, invalid, _effect(&"valid")]
	assert_eq(catalog.get_effect_ids(), [&"valid"])
