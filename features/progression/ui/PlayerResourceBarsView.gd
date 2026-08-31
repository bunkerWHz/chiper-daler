extends PanelContainer
class_name PlayerResourceBarsView

@export var actor_path: NodePath
@export var rage_effect_id: StringName = &"rage"
@export_range(0.1, 3600.0, 0.1) var fallback_rage_duration: float = 10.0

var _magic: MagicComponent
var _progression: ProgressionComponent
var _status_effects: StatusEffectComponent
var _displayed_mana: float = 0.0
var _displayed_max_mana: float = 1.0
var _displayed_experience: int = 0
var _displayed_required_experience: int = 1
var _displayed_rage: float = 0.0
var _displayed_max_rage: float = 10.0

@onready var _mana_bar: ProgressBar = %ManaBar
@onready var _mana_value: Label = %ManaValue
@onready var _experience_bar: ProgressBar = %ExperienceBar
@onready var _experience_value: Label = %ExperienceValue
@onready var _rage_bar: ProgressBar = %RageBar
@onready var _rage_value: Label = %RageValue


func _ready() -> void:
	if _magic == null or _progression == null or _status_effects == null:
		var target_actor := get_node_or_null(actor_path) as Actor
		if target_actor == null:
			push_error("PlayerResourceBarsView requires a valid Actor path")
			return
		bind_components(
			target_actor.get_component(MagicComponent) as MagicComponent,
			target_actor.get_component(ProgressionComponent) as ProgressionComponent,
			target_actor.get_component(StatusEffectComponent) as StatusEffectComponent
		)
	_apply_display()


func _process(_delta: float) -> void:
	_refresh_rage()


func bind_components(
	magic: MagicComponent,
	progression: ProgressionComponent,
	status_effects: StatusEffectComponent
) -> void:
	_disconnect_sources()
	_magic = magic
	_progression = progression
	_status_effects = status_effects
	if _magic == null or not _magic.is_enabled:
		push_error("PlayerResourceBarsView requires an enabled MagicComponent")
		return
	if _progression == null or not _progression.is_enabled:
		push_error("PlayerResourceBarsView requires an enabled ProgressionComponent")
		return
	if _status_effects == null or not _status_effects.is_enabled:
		push_error("PlayerResourceBarsView requires an enabled StatusEffectComponent")
		return

	_magic.mana_changed.connect(_on_mana_changed)
	_progression.experience_changed.connect(_on_experience_changed)
	_status_effects.effect_applied.connect(_on_effect_applied)
	_status_effects.effect_removed.connect(_on_effect_removed)
	_on_mana_changed(_magic.get_mana(), _magic.get_max_mana())
	_on_experience_changed(
		_progression.get_experience(),
		_progression.get_experience_required()
	)
	_displayed_max_rage = fallback_rage_duration
	_refresh_rage()


func get_displayed_mana() -> float:
	return _displayed_mana


func get_displayed_max_mana() -> float:
	return _displayed_max_mana


func get_displayed_experience() -> int:
	return _displayed_experience


func get_displayed_required_experience() -> int:
	return _displayed_required_experience


func get_displayed_rage() -> float:
	return _displayed_rage


func get_displayed_max_rage() -> float:
	return _displayed_max_rage


func _exit_tree() -> void:
	_disconnect_sources()


func _on_mana_changed(current: float, maximum: float) -> void:
	_displayed_max_mana = maxf(maximum, 1.0)
	_displayed_mana = clampf(current, 0.0, _displayed_max_mana)
	_apply_display_if_ready()


func _on_experience_changed(current: int, required: int) -> void:
	_displayed_required_experience = maxi(required, 1)
	_displayed_experience = clampi(
		current, 0, _displayed_required_experience
	)
	_apply_display_if_ready()


func _on_effect_applied(effect: StatusEffect) -> void:
	if effect != null and effect.effect_id == rage_effect_id:
		_displayed_max_rage = maxf(effect.duration, 0.1)
		_refresh_rage()


func _on_effect_removed(effect_id: StringName) -> void:
	if effect_id == rage_effect_id:
		_displayed_rage = 0.0
		_apply_display_if_ready()


func _refresh_rage() -> void:
	if _status_effects == null:
		return
	_displayed_rage = clampf(
		_status_effects.get_remaining(rage_effect_id),
		0.0,
		_displayed_max_rage
	)
	_apply_display_if_ready()


func _apply_display_if_ready() -> void:
	if is_node_ready():
		_apply_display()


func _apply_display() -> void:
	_mana_bar.max_value = _displayed_max_mana
	_mana_bar.value = _displayed_mana
	_mana_value.text = "%d / %d" % [
		roundi(_displayed_mana), roundi(_displayed_max_mana)
	]
	_experience_bar.max_value = _displayed_required_experience
	_experience_bar.value = _displayed_experience
	_experience_value.text = "%d / %d" % [
		_displayed_experience, _displayed_required_experience
	]
	_rage_bar.max_value = _displayed_max_rage
	_rage_bar.value = _displayed_rage
	_rage_value.text = "%.1f / %.1f" % [
		_displayed_rage, _displayed_max_rage
	]


func _disconnect_sources() -> void:
	if _magic != null and _magic.mana_changed.is_connected(_on_mana_changed):
		_magic.mana_changed.disconnect(_on_mana_changed)
	if (
		_progression != null
		and _progression.experience_changed.is_connected(
			_on_experience_changed
		)
	):
		_progression.experience_changed.disconnect(_on_experience_changed)
	if _status_effects != null:
		if _status_effects.effect_applied.is_connected(_on_effect_applied):
			_status_effects.effect_applied.disconnect(_on_effect_applied)
		if _status_effects.effect_removed.is_connected(_on_effect_removed):
			_status_effects.effect_removed.disconnect(_on_effect_removed)
