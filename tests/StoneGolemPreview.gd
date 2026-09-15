extends Node2D

const CLIPS := [
	"idle", "move", "glowing", "ranged_attack", "melee_attack", "laser_cast",
	"laser_beam", "laser", "armor_buff", "block", "defeated", "appearance",
	"arm_projectile", "arm_projectile_glowing",
]
@onready var golem: Actor = $StoneGolem
@onready var timeline: AnimationPlayer = $StoneGolem/_Visual/AnimationPlayer
@onready var sprite: AnimatedSprite2D = $StoneGolem/_Visual/AnimatedSprite2D
var picker: OptionButton
var status: Label
var _flipped := false


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
	for effect: AnimatedSprite2D in [golem.get_node("_Visual/LaserBeam"), golem.get_node("_Visual/ArmProjectile")]:
		effect.flip_h = flipped
		var width := 300.0 if effect.name == &"LaserBeam" else 100.0
		effect.position.x = 49.0 - width if flipped else -49.0
