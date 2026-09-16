extends Node2D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("182128"))
	var player := $Player as Actor
	(player.get_component(DebugOverlayComponent) as DebugOverlayComponent).set_debug_visible(false)
	var camera := player.get_component(CameraComponent) as CameraComponent
	camera.get_camera().enabled = false
	$Camera2D.make_current()
	$UI/Panel/Damage.pressed.connect(_damage_boss)
	$UI/Panel/Restart.pressed.connect(func() -> void: get_tree().reload_current_scene())
	$StoneGolem/BossEncounter.intro_started.connect(func() -> void:
		$UI/Panel/Status.text = "Вступление — голем защищён, бой ещё не начался.")
	$StoneGolem/BossEncounter.combat_started.connect(func() -> void:
		$UI/Panel/Status.text = "Бой начался. Можно нанести урон. Атаки босса ещё не подключены.")
	$StoneGolem/BossEncounter.encounter_ended.connect(func(victory: bool) -> void:
		$UI/Panel/Status.text = "Босс побеждён." if victory else "Встреча сброшена. Войдите в зону снова.")


func _damage_boss() -> void:
	var boss := get_node_or_null("StoneGolem") as Actor
	if boss == null:
		return
	var encounter := boss.get_node("BossEncounter") as BossEncounter
	if encounter.phase == BossEncounter.Phase.COMBAT:
		(boss.get_component(HealthComponent) as HealthComponent).take_damage(20)
