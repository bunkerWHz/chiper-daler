extends Component
class_name DebugCombatLogComponent

## Temporary combat log in the bottom-left corner: damage dealt, damage taken,
## resource regeneration and the current combat state of the owner.
##
## Combat itself is not detected here — it is read from RegenerationComponent,
## which owns the rule (own attack or received damage, five seconds of timeout).
## The log only makes that invisible timer visible.
##
## Damage dealt is read from the hurtboxes of other Actor: HitData.source_actor
## names the attacker, so melee swings, projectiles, thrown items and spells all
## arrive through one path. Damage taken comes from HealthComponent.damaged,
## which also covers periodic damage that never passes through a hurtbox.

## Damage the owner dealt to somebody else.
const COLOR_DEALT := "ffffff"
## Damage the owner received.
const COLOR_TAKEN := "ff5c5c"
## Restored health, mana and stamina.
const COLOR_REGEN := "6bff6b"
const COLOR_COMBAT := "ffb347"
const COLOR_PEACE := "6bff6b"
const COLOR_TIME := "8a8a8a"

@export var visible_on_start: bool = true
@export_range(0.05, 1.0, 0.05) var opacity: float = 0.3
@export_range(4, 60, 1) var max_lines: int = 12

var _panel: Control
var _state_label: Label
var _log: RichTextLabel
var _lines: PackedStringArray = PackedStringArray()
var _health: HealthComponent
var _regen: RegenerationComponent
var _elapsed: float = 0.0
var _in_combat: bool = false
var _state_known: bool = false


func on_initialize() -> void:
	_health = actor.get_component(HealthComponent) as HealthComponent
	_regen = actor.get_component(RegenerationComponent) as RegenerationComponent

	if _health == null or _regen == null:
		push_error(
			"DebugCombatLogComponent requires HealthComponent and RegenerationComponent"
		)
		disable()
		return

	_health.damaged.connect(_on_damage_taken)
	_regen.regenerated.connect(_on_regenerated)


func _ready() -> void:
	_panel = get_node_or_null("CanvasLayer/Panel") as Control
	_state_label = get_node_or_null("CanvasLayer/Panel/Margin/Rows/State") as Label
	_log = get_node_or_null("CanvasLayer/Panel/Margin/Rows/Log") as RichTextLabel

	if _panel == null or _state_label == null or _log == null:
		push_error("DebugCombatLogComponent requires Panel, State and Log nodes")
		disable()
		return

	_panel.modulate = Color(1.0, 1.0, 1.0, opacity)
	_panel.visible = visible_on_start

	var tree := get_tree()

	if tree == null:
		return

	tree.node_added.connect(_on_node_added)
	_watch_hurtboxes(tree.root)


func _process(delta: float) -> void:
	_elapsed += delta
	_update_combat_state()


func set_log_visible(value: bool) -> void:
	if _panel != null:
		_panel.visible = value


func is_log_visible() -> bool:
	return _panel != null and _panel.visible


func get_lines() -> PackedStringArray:
	return _lines


## The owner must keep logging death and respawn, so the component survives it.
func should_disable_on_actor_death() -> bool:
	return false


func _update_combat_state() -> void:
	if _regen == null or not _regen.is_enabled:
		return

	var in_combat := _regen.is_in_combat()

	if not _state_known or in_combat != _in_combat:
		_state_known = true
		_in_combat = in_combat
		_append(
			"[color=#%s]%s[/color]" % [
				COLOR_COMBAT if in_combat else COLOR_PEACE,
				"БОЙ НАЧАЛСЯ" if in_combat else "БОЙ ЗАКОНЧИЛСЯ",
			]
		)

	_state_label.text = _combat_state_text(in_combat)
	_state_label.add_theme_color_override(
		"font_color",
		Color(COLOR_COMBAT) if in_combat else Color(COLOR_PEACE)
	)


func _combat_state_text(in_combat: bool) -> String:
	var multiplier := _regen.get_regeneration_multiplier()

	if not in_combat:
		return "БОЙ: ВНЕ БОЯ  реген ×%.1f" % multiplier

	return "БОЙ: В БОЮ  осталось %.1f с  реген ×%.1f" % [
		_regen.get_combat_remaining(),
		multiplier,
	]


func _on_damage_taken(amount: float, current_health: float) -> void:
	_append(
		"[color=#%s]урон по мне −%.0f HP  (осталось %.0f / %.0f)[/color]" % [
			COLOR_TAKEN,
			amount,
			current_health,
			_health.get_max_health(),
		]
	)


func _on_regenerated(health: float, mana: float, stamina: float) -> void:
	var parts := PackedStringArray()

	if health > 0.0:
		parts.append("+%.0f HP" % health)
	if mana > 0.0:
		parts.append("+%.0f MP" % mana)
	if stamina > 0.0:
		parts.append("+%.0f SP" % stamina)

	if parts.is_empty():
		return

	_append("[color=#%s]реген  %s[/color]" % [COLOR_REGEN, "  ".join(parts)])


func _on_hit_received(
	hit: HitData,
	applied_damage: float,
	hurtbox: HurtboxComponent
) -> void:
	if not is_enabled or hit == null or hit.source_actor != actor:
		return

	var target_name := "цель"

	if hurtbox != null and hurtbox.actor != null:
		target_name = str(hurtbox.actor.name)

	_append(
		"[color=#%s]мой урон → %s: %.0f%s[/color]" % [
			COLOR_DEALT,
			target_name,
			applied_damage,
			" КРИТ" if hit.is_critical else "",
		]
	)


func _on_node_added(node: Node) -> void:
	if node is HurtboxComponent:
		_watch_hurtbox(node as HurtboxComponent)


func _watch_hurtboxes(node: Node) -> void:
	if node is HurtboxComponent:
		_watch_hurtbox(node as HurtboxComponent)

	for child in node.get_children():
		_watch_hurtboxes(child)


func _watch_hurtbox(hurtbox: HurtboxComponent) -> void:
	if hurtbox == null or hurtbox.actor == actor:
		return
	if hurtbox.hit_received.is_connected(_on_hit_received):
		return

	hurtbox.hit_received.connect(_on_hit_received.bind(hurtbox))


func _append(line: String) -> void:
	if _log == null:
		return

	_lines.append("[color=#%s]%6.1f[/color]  %s" % [COLOR_TIME, _elapsed, line])

	while _lines.size() > max_lines:
		_lines.remove_at(0)

	_log.text = "\n".join(_lines)
