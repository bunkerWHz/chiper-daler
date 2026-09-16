extends Node2D

const CLIPS := [
	"idle", "move", "glowing", "ranged_attack", "melee_attack",
	"laser", "armor_buff", "block", "defeated", "appearance",
]
const PROJECTILE := preload("res://game/enemy/monsters/stone_golem/ArmProjectile.tscn")
@onready var golem: Actor = $StoneGolem
@onready var timeline: AnimationPlayer = $StoneGolem/_Visual/AnimationPlayer
@onready var sprite: AnimatedSprite2D = $StoneGolem/_Visual/AnimatedSprite2D
var picker: OptionButton
var status: Label
var _flipped := false
var _projectile: Area2D
var _shot_released := false
var _shot_direction := 1.0
var _shot_distance := 0.0


func _ready() -> void:
	# Presentation only: no damage, death, or autonomous actions in the preview.
	for component: Component in golem.get_components():
		component.disable()
	golem.get_node("_Visual/HealthBar").hide()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := VBoxContainer.new()
	panel.position = Vector2(24, 24)
	panel.add_theme_constant_override("separation", 12)
	canvas.add_child(panel)
	var title := Label.new()
	title.text = "STONE GOLEM — анимации"
	title.add_theme_font_size_override("font_size", 26)
	panel.add_child(title)
	picker = OptionButton.new()
	for clip: String in CLIPS:
		picker.add_item(clip)
	panel.add_child(picker)
	picker.item_selected.connect(func(_index: int) -> void: play_selected())
	var replay := Button.new()
	replay.text = "Проиграть заново"
	replay.pressed.connect(play_selected)
	panel.add_child(replay)
	var interrupt := Button.new()
	interrupt.text = "Сбить каст лазера"
	interrupt.pressed.connect(interrupt_laser_cast)
	panel.add_child(interrupt)
	var facing := CheckButton.new()
	facing.text = "Смотреть влево"
	facing.toggled.connect(_set_facing)
	panel.add_child(facing)
	var pause := CheckButton.new()
	pause.text = "Пауза анимации"
	pause.toggled.connect(func(value: bool) -> void: timeline.speed_scale = 0.0 if value else 1.0)
	panel.add_child(pause)
	status = Label.new()
	panel.add_child(status)
	var note := Label.new()
	note.text = "Блок: 8 кадров • Броня: 10 кадров (по исходникам)\nБоевые механики пока не подключены."
	panel.add_child(note)
	RenderingServer.set_default_clear_color(Color("182128"))
	play_selected()


func play_selected() -> void:
	_clear_projectile()
	_shot_released = false
	var clip: String = CLIPS[picker.selected]
	timeline.stop()
	timeline.play(clip)
	timeline.advance(0.0)
	status.text = "%s • %.1f сек • 10 кадров/с" % [clip, timeline.get_animation(clip).length]
	_set_facing(_flipped)


func _set_facing(flipped: bool) -> void:
	_flipped = flipped
	golem.position.x = 860.0 if flipped else 420.0
	sprite.flip_h = flipped
	var effect := golem.get_node("_Visual/LaserBeam") as AnimatedSprite2D
	effect.flip_h = flipped
	effect.position.x = -251.0 if flipped else -49.0


func interrupt_laser_cast() -> bool:
	if timeline.current_animation != &"laser":
		return false
	# The last character-frame key is the release boundary, shared with the beam.
	var cast := timeline.get_animation(&"laser")
	var track := cast.find_track(^"AnimatedSprite2D:frame", Animation.TYPE_VALUE)
	var release_time := cast.track_get_key_time(track, cast.track_get_key_count(track) - 1)
	if timeline.current_animation_position >= release_time:
		status.text = "Луч уже выпущен."
		return false
	timeline.stop()
	timeline.play(&"idle")
	timeline.advance(0.0)
	status.text = "Каст сбит — луч не выпущен."
	return true


func _process(delta: float) -> void:
	if timeline.current_animation == &"ranged_attack" and timeline.current_animation_position >= 0.5 and not _shot_released:
		_release_preview_projectile()
	if is_instance_valid(_projectile):
		var distance := 480.0 * delta * timeline.speed_scale
		_projectile.position.x += distance * _shot_direction
		_shot_distance += distance
		if _shot_distance >= 600.0:
			_clear_projectile()


func _release_preview_projectile() -> void:
	_shot_released = true
	_shot_distance = 0.0
	_shot_direction = -1.0 if _flipped else 1.0
	_projectile = PROJECTILE.instantiate() as Area2D
	var origin := golem.get_node("_Sockets/ProjectileOrigin") as Marker2D
	var local_origin := origin.position
	local_origin.x *= _shot_direction
	add_child(_projectile)
	_projectile.global_position = golem.to_global(local_origin)
	_projectile.get_node("AnimatedSprite2D").flip_h = _flipped


func _clear_projectile() -> void:
	if is_instance_valid(_projectile):
		_projectile.queue_free()
	_projectile = null
