extends SceneTree

var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func near(value: float, expected: float, message: String) -> void:
	check(is_equal_approx(value, expected), "%s: got %s, expected %s" % [message, value, expected])

func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player := preload("res://game/player/Player.tscn").instantiate() as Actor
	world.add_child(player)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var stats := player.get_component(CharacterAttributesComponent) as CharacterAttributesComponent
	var health := player.get_component(HealthComponent) as HealthComponent
	var mana := player.get_component(MagicComponent) as MagicComponent
	var stamina := player.get_component(StaminaComponent) as StaminaComponent
	var regen := player.get_component(RegenerationComponent) as RegenerationComponent
	var attack := player.get_component(AttackComponent) as AttackComponent
	var equipment := player.get_component(EquipmentComponent) as EquipmentComponent
	var inventory := player.get_component(InventoryComponent) as InventoryComponent
	var ranged := player.get_component(RangedWeaponComponent) as RangedWeaponComponent
	equipment.restore_runtime_state({"equipped_items": {}})
	near(health.get_max_health(), 100, "Base HP")
	near(mana.get_max_mana(), 100, "Base mana")
	near(stamina.get_max_stamina(), 100, "Base stamina")
	near(stats.get_physical_attack(), 1, "Base physical attack")
	near(stats.get_magic_attack(), 1, "Base magic attack")
	near(stats.get_attack_speed_multiplier(), 1, "Base attack speed")
	near(stats.get_magic_defense(), 1, "Base magic defense")
	near(stats.get_max_equip_load(), 100, "Base load capacity")
	stats.set_strength(2)
	stats.set_dexterity(2)
	stats.set_intelligence(2)
	stats.set_endurance(2)
	stats.set_wisdom(2)
	near(health.get_max_health(), 101, "END adds one HP")
	near(mana.get_max_mana(), 101, "WIS adds one mana")
	near(stats.get_physical_attack(), 2, "STR adds physical attack")
	near(stats.get_physical_defense(), 2, "STR adds armor")
	near(stats.get_magic_attack(), 2, "INT adds magic attack")
	near(stats.get_magic_defense(), 2, "INT adds magic defense")
	near(stats.get_max_equip_load(), 101, "END adds one capacity")
	near(stats.get_attack_speed_multiplier(), 1.01, "DEX attack percent")
	near(stats.get_run_speed_multiplier(), 1.01, "DEX run percent")
	near(stats.get_cast_speed_multiplier(), 1.01, "WIS cast percent")
	var movement := player.get_component(MovementComponent) as MovementComponent
	var input := player.get_component(InputComponent) as InputComponent
	var body := player.get_component(CharacterBodyComponent) as CharacterBodyComponent
	input._move_axis = 1.0
	movement._update_horizontal_velocity(10.0)
	near(body.get_velocity().x, movement.config.move_speed * 1.01, "Actual running speed scales from DEX")
	input._move_axis = 0.0
	body.set_velocity(Vector2.ZERO)
	near(stamina.get_max_stamina(), 100, "Stats leave stamina maximum fixed")
	health.take_damage(91)
	mana._set_mana(10)
	stamina.spend(90)
	regen._process(0.9)
	near(health.get_current_health(), 10, "No fractional HP tick")
	near(mana.get_mana(), 10, "No fractional mana tick")
	near(stamina.get_stamina(), 10, "No fractional stamina tick")
	stamina._process(1.0)
	near(stamina.get_stamina(), 10, "Legacy continuous regen is not doubled")
	regen._process(0.1)
	near(health.get_current_health(), 12, "Combat HP tick")
	near(mana.get_mana(), 12, "Combat mana tick")
	near(stamina.get_stamina(), 12, "Combat stamina tick")
	regen._process(3.0)
	near(health.get_current_health(), 18, "Three more combat ticks")
	regen._process(1.0)
	near(health.get_current_health(), 22, "Fifth second enables double regeneration")
	check(not regen.is_in_combat(), "Combat expires after five seconds")
	attack.attack_started.emit()
	check(regen.is_in_combat(), "An attack restarts combat timer")
	regen._process(1.0)
	near(health.get_current_health(), 24, "Attack restores combat regeneration rate")
	var armor := preload("res://game/items/armor/ScoutLeatherArmor.tres").duplicate(true) as ItemData
	armor.id = &"regeneration_test_armor"
	armor.equipment_profile.stats.health_regeneration = 3
	armor.equipment_profile.stats.mana_regeneration = 4
	armor.equipment_profile.stats.stamina_regeneration = 5
	armor.equipment_profile.stats.defense = 50
	armor.equipment_profile.stats.magic_defense = 100
	inventory.add_item(armor)
	equipment.equip_inventory_item(armor.id, ItemData.EquipSlot.CHEST)
	var defense := player.get_component(EquipmentDefenseComponent) as EquipmentDefenseComponent
	var hit := HitData.new(100, null)
	near(defense.modify_damage(hit, 100), 10000.0 / 152.0, "Physical hit uses STR and physical armor")
	hit.is_magic = true
	near(defense.modify_damage(hit, 100), 10000.0 / 202.0, "Magic hit uses INT and magic armor")
	health.take_damage(14)
	mana._set_mana(10)
	stamina.spend(stamina.get_stamina() - 10)
	regen._process(1.0)
	near(health.get_current_health(), 15, "Equipment adds HP regeneration")
	near(mana.get_mana(), 16, "Equipment adds mana regeneration")
	near(stamina.get_stamina(), 17, "Equipment adds stamina regeneration")
	equipment.unequip_item(ItemData.EquipSlot.CHEST)
	regen._process(1.0)
	near(health.get_current_health(), 17, "Unequipping removes regeneration bonus")
	stats.set_dexterity(101)
	near(ranged.get_attack_speed_multiplier(), 2, "Ranged uses general attack speed")
	equipment.equip_inventory_item(&"training_sword", ItemData.EquipSlot.MAIN_HAND)
	near(attack._get_equipped_melee_damage(), 12, "Actor physical attack plus weapon damage")
	var base_clip := player.get_node("_Visual/DarklightRig/AnimationPlayer") as AnimationPlayer
	check(attack.attack(), "Fast melee attack starts")
	near(attack.get_attack_duration(), base_clip.get_animation("attack").length / 2.0, "Melee duration scales")
	var visual := player.get_node("_Components/AnimationComponent")
	visual._current_state = ActorState.Behavior.GROUND_LIGHT_ATTACK
	visual._play_animation(&"attack")
	near(base_clip.get_playing_speed(), 2, "Rig animation matches damage timing")
	attack._finish_attack()
	stats.set_wisdom(101)
	equipment.equip_inventory_item(&"training_wand", ItemData.EquipSlot.MAIN_HAND)
	var aim := player.get_component(AimingComponent) as AimingComponent
	check(aim.begin_aim(mana), "Magic aim begins")
	mana._cast_spell()
	var spell := world.get_child(world.get_child_count() - 1) as Projectile
	check(spell != null and spell.is_magic, "Spell carries magic damage type")
	near(spell._damage, 2 + equipment.get_active_weapon_damage(), "INT base attack plus magic weapon")
	near(mana._timer, mana.config.cast_duration / 2, "Cast speed shortens cast phase")
	check(regen.is_in_combat(), "Casting enters combat")
	mana._set_phase(MagicComponent.Phase.NONE, 0)
	equipment.equip_inventory_item(&"training_bow", ItemData.EquipSlot.MAIN_HAND)
	ranged._ammo_id = &"training_arrows"
	ranged._fire(true)
	var bow_settings := equipment.get_equipped_item(ItemData.EquipSlot.MAIN_HAND).weapon_profile.ranged
	near(ranged._cooldown_timer, bow_settings.shot_cooldown / 2, "Attack speed shortens bow cooldown")
	near(ranged._phase_timer, bow_settings.release_duration / 2, "Attack speed shortens bow release")
	health.take_damage(1000)
	regen._process(10)
	near(health.get_current_health(), 0, "Regeneration never resurrects")
	world.queue_free()
	await process_frame
	print("Derived stats checks: ", failures, " failures")
	quit(1 if failures else 0)
