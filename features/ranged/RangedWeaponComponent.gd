extends Component
class_name RangedWeaponComponent

enum Phase {
	NONE,
	BOW_AIM,
	BOW_LOOSE,
	CROSSBOW_AIM,
	CROSSBOW_FIRE,
}

signal phase_changed(previous_phase: Phase, current_phase: Phase)
signal projectile_fired(phase: Phase, remaining_ammo: int)
signal ammunition_changed

const PROJECTILE_SCENE := preload("res://features/throwing/ThrownProjectile.tscn")
const ARROW_TEXTURE := preload("res://assets/Test/Hero/Archer/Arrow.png")
const BEHAVIOR_GATE := preload(
	"res://features/state/ExclusiveBehaviorGate.gd"
)

@export var config: RangedWeaponConfig

var _input_component: InputComponent
var _equipment_component: EquipmentComponent
var _facing_component: FacingComponent
var _phase: Phase = Phase.NONE
var _phase_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _inventory: InventoryComponent
var _ammo_id: StringName
var _aim: AimingComponent


func on_initialize() -> void:
	if config == null:
		push_error("RangedWeaponComponent requires RangedWeaponConfig")
		disable()
		return

	if (
		config.release_duration <= 0.0
		or config.shot_cooldown < 0.0
		or config.arrow_speed <= 0.0
		or config.bolt_speed <= 0.0
		or config.projectile_lifetime <= 0.0
		or config.arrow_damage < 0.0
		or config.bolt_damage < 0.0
		or config.knockback < 0.0
		or config.arrow_gravity < 0.0
		or config.bolt_gravity < 0.0
	):
		push_error("RangedWeaponComponent has an invalid config")
		disable()
		return

	_input_component = actor.get_component(InputComponent) as InputComponent
	_equipment_component = actor.get_component(EquipmentComponent) as EquipmentComponent
	_facing_component = actor.get_component(FacingComponent) as FacingComponent

	if (
		_input_component == null
		or not _input_component.is_enabled
		or _equipment_component == null
		or not _equipment_component.is_enabled
		or _facing_component == null
		or not _facing_component.is_enabled
	):
		push_error(
			"RangedWeaponComponent requires enabled input, equipment, and facing"
		)
		disable()
		return

	_inventory = actor.get_component(InventoryComponent) as InventoryComponent
	_aim = actor.get_component(AimingComponent) as AimingComponent
	if _aim != null and not _aim.aim_cancelled.is_connected(_on_aim_cancelled):
		_aim.aim_cancelled.connect(_on_aim_cancelled)
	if _inventory == null or not _inventory.is_enabled or _aim == null or not _aim.is_enabled:
		push_error("RangedWeaponComponent requires enabled inventory and aiming")
		disable()
		return
	if not _inventory.inventory_changed.is_connected(_on_inventory_changed):
		_inventory.inventory_changed.connect(_on_inventory_changed)
	if not _equipment_component.equipment_changed.is_connected(
		_on_equipment_changed
	):
		_equipment_component.equipment_changed.connect(
			_on_equipment_changed
		)
	if not _equipment_component.loadout_item_changed.is_connected(
		_on_loadout_item_changed
	):
		_equipment_component.loadout_item_changed.connect(
			_on_loadout_item_changed
		)
	if not _equipment_component.weapon_set_changed.is_connected(
		_on_weapon_set_changed
	):
		_equipment_component.weapon_set_changed.connect(
			_on_weapon_set_changed
		)


func _process(delta: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	_update_release(delta)

	if _equipment_component.is_slot_active(EquipmentComponent.Slot.BOW):
		_process_bow_input()
	elif _equipment_component.is_slot_active(EquipmentComponent.Slot.CROSSBOW):
		_process_crossbow_input()


func get_phase() -> Phase:
	return _phase


func is_exclusive_behavior_active() -> bool:
	return _phase != Phase.NONE


func get_arrow_count() -> int:
	return _count_ammunition(&"arrow")


func get_bolt_count() -> int:
	return _count_ammunition(&"bolt")


func _count_ammunition(kind: StringName) -> int:
	var total := 0
	if _inventory == null:
		return total
	for stack: InventoryStack in _inventory.get_stacks():
		if stack.item.category == ItemData.Category.AMMUNITION and stack.item.get_ammunition_type() == kind:
			total += stack.quantity
	return total


func _get_ammunition() -> ItemData:
	var item := _equipment_component.get_equipped_item(ItemData.EquipSlot.OFF_HAND)
	if item == null or not _equipment_component.is_ammunition_compatible(item):
		return null
	return item if _inventory.has_item(item.id) else null


func _on_inventory_changed() -> void:
	if (_phase == Phase.BOW_AIM or _phase == Phase.CROSSBOW_AIM) and not _inventory.has_item(_ammo_id):
		cancel_aim()
	ammunition_changed.emit()

func cancel_aim() -> void:
	if _phase == Phase.BOW_AIM or _phase == Phase.CROSSBOW_AIM:
		_set_phase(Phase.NONE, 0.0)


func disable() -> void:
	_set_phase(Phase.NONE, 0.0)
	super.disable()


func _process_bow_input() -> void:
	_process_weapon_input(true)


func _process_crossbow_input() -> void:
	_process_weapon_input(false)


func _process_weapon_input(bow: bool) -> void:
	var aiming_phase := Phase.BOW_AIM if bow else Phase.CROSSBOW_AIM
	if _phase == Phase.NONE and _input_component.consume_attack_pressed():
		var ammo := _get_ammunition()
		var allowed := _equipment_component.allows_bow_aim() if bow else _equipment_component.allows_crossbow_aim()
		if ammo != null and allowed and _cooldown_timer <= 0.0 and not BEHAVIOR_GATE.is_blocked(actor, self):
			_ammo_id = ammo.id
			_set_phase(aiming_phase, 0.0)
	if _phase == aiming_phase:
		if _input_component.consume_guard_just_pressed():
			cancel_aim()
		elif _input_component.consume_attack_released():
			_fire(bow)


func _fire(bow: bool) -> void:
	var ammo := _get_ammunition()
	var allowed := _equipment_component.allows_bow_fire() if bow else _equipment_component.allows_crossbow_fire()
	if ammo == null or ammo.id != _ammo_id or not allowed or actor.get_parent() == null:
		cancel_aim()
		return
	# Release before inventory callbacks reconcile an exhausted offhand stack.
	var release_phase := Phase.BOW_LOOSE if bow else Phase.CROSSBOW_FIRE
	var weapon := _equipment_component.get_equipped_item(ItemData.EquipSlot.MAIN_HAND)
	var settings := weapon.weapon_profile.ranged
	if settings == null or not settings.is_valid():
		cancel_aim()
		return
	# Capture before ending aim/resetting the pose, including the last arrow.
	var launch_position := _aim.get_launch_position()
	_set_phase(release_phase, settings.release_duration / get_attack_speed_multiplier())
	_spawn_projectile(settings.projectile_speed, settings.projectile_damage,
		ARROW_TEXTURE if bow else null, settings.projectile_gravity, settings, launch_position)
	_inventory.remove_item(ammo.id, 1)
	projectile_fired.emit(release_phase, _inventory.get_quantity(ammo.id))
	_cooldown_timer = settings.shot_cooldown / get_attack_speed_multiplier()


func get_attack_speed_multiplier() -> float:
	var attributes := actor.get_component(CharacterAttributesComponent) as CharacterAttributesComponent
	return attributes.get_attack_speed_multiplier() if attributes != null and attributes.is_enabled else 1.0

func _update_release(delta: float) -> void:
	if _phase != Phase.BOW_LOOSE and _phase != Phase.CROSSBOW_FIRE:
		return

	_phase_timer = maxf(_phase_timer - delta, 0.0)

	if _phase_timer == 0.0:
		_set_phase(Phase.NONE, 0.0)


func _spawn_projectile(
	speed: float,
	damage: float,
	visual_texture: Texture2D = null,
	gravity: float = 0.0,
	settings: ItemRangedProfile = null,
	launch_position: Vector2 = Vector2.INF
) -> void:
	var parent := actor.get_parent()

	if parent == null:
		return

	var projectile := PROJECTILE_SCENE.instantiate() as ThrownProjectile
	parent.add_child(projectile)
	projectile.global_position = _aim.get_launch_position() if launch_position == Vector2.INF else launch_position
	var attributes := actor.get_component(CharacterAttributesComponent) as CharacterAttributesComponent
	if attributes != null and attributes.is_enabled:
		damage += attributes.get_physical_attack()
	projectile.setup_direction(
		actor,
		_aim.get_direction(),
		speed,
		damage + _equipment_component.get_active_weapon_damage(),
		settings.knockback if settings != null else config.knockback,
		settings.projectile_lifetime if settings != null else config.projectile_lifetime,
		visual_texture,
		gravity
	)


func _set_phase(new_phase: Phase, duration: float) -> void:
	if new_phase == _phase:
		return

	var previous_phase := _phase
	if _aim != null:
		if new_phase == Phase.BOW_AIM or new_phase == Phase.CROSSBOW_AIM:
			if not _aim.begin_aim(self):
				return
		else:
			_aim.end_aim(self)
	_phase = new_phase
	_phase_timer = duration
	phase_changed.emit(previous_phase, _phase)


func _on_aim_cancelled(aim_owner: Component) -> void:
	if aim_owner == self:
		cancel_aim()


func _on_equipment_changed(
	_previous_slot: EquipmentComponent.Slot,
	_current_slot: EquipmentComponent.Slot
) -> void:
	cancel_aim()


func _on_loadout_item_changed(
	equip_slot: ItemData.EquipSlot,
	_slot_index: int,
	weapon_set: int,
	_previous_item_id: StringName,
	_current_item_id: StringName
) -> void:
	if (
		equip_slot in [ItemData.EquipSlot.MAIN_HAND, ItemData.EquipSlot.OFF_HAND]
		and weapon_set == _equipment_component.get_active_weapon_set()
	):
		cancel_aim()


func _on_weapon_set_changed(_previous_set: int, _current_set: int) -> void:
	cancel_aim()
