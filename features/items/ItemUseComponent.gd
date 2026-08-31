extends Component
class_name ItemUseComponent

const BEHAVIOR_GATE := preload(
	"res://features/state/ExclusiveBehaviorGate.gd"
)
const LOCOMOTION_CONSTRAINT := preload(
	"res://features/movement/LocomotionConstraint.gd"
)

signal item_use_started(item: ItemData)
signal item_used(restored_health: float, remaining_charges: int)
signal item_use_cancelled
signal inventory_item_used(item: ItemData, applied_value: float, remaining: int)

@export var config: ItemUseConfig

var _input_component: InputComponent
var _body_component: CharacterBodyComponent
var _equipment_component: EquipmentComponent
var _health_component: HealthComponent
var _inventory_component: InventoryComponent
var _quick_access_component: QuickAccessComponent
var _magic_component: MagicComponent
var _progression_component: ProgressionComponent
var _status_effect_component: StatusEffectComponent
var _flask_charges_component: FlaskChargesComponent
var _use_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _active_inventory_item_id: StringName


func on_initialize() -> void:
	if config == null:
		push_error("ItemUseComponent requires ItemUseConfig")
		disable()
		return

	if (
		config.use_duration <= 0.0
		or config.cooldown < 0.0
	):
		push_error("ItemUseComponent has an invalid config")
		disable()
		return

	_input_component = actor.get_component(InputComponent) as InputComponent
	_body_component = (
		actor.get_component(CharacterBodyComponent) as CharacterBodyComponent
	)
	_equipment_component = (
		actor.get_component(EquipmentComponent) as EquipmentComponent
	)
	_health_component = actor.get_component(HealthComponent) as HealthComponent
	_inventory_component = (
		actor.get_component(InventoryComponent) as InventoryComponent
	)
	_quick_access_component = (
		actor.get_component(QuickAccessComponent) as QuickAccessComponent
	)
	_magic_component = actor.get_component(MagicComponent) as MagicComponent
	_progression_component = (
		actor.get_component(ProgressionComponent) as ProgressionComponent
	)
	_status_effect_component = (
		actor.get_component(StatusEffectComponent) as StatusEffectComponent
	)
	_flask_charges_component = (
		actor.get_component(FlaskChargesComponent) as FlaskChargesComponent
	)

	if _input_component == null or not _input_component.is_enabled:
		push_error("ItemUseComponent requires an enabled InputComponent")
		disable()
		return
	if _body_component == null or not _body_component.is_enabled:
		push_error("ItemUseComponent requires an enabled CharacterBodyComponent")
		disable()
		return

	if _equipment_component == null or not _equipment_component.is_enabled:
		push_error("ItemUseComponent requires an enabled EquipmentComponent")
		disable()
		return

	if _health_component == null or not _health_component.is_enabled:
		push_error("ItemUseComponent requires an enabled HealthComponent")
		disable()
		return
	if (
		_inventory_component == null
		or not _inventory_component.is_enabled
		or _quick_access_component == null
		or not _quick_access_component.is_enabled
	):
		push_error("ItemUseComponent requires enabled inventory and quick access")
		disable()
		return

	if not _equipment_component.equipment_changed.is_connected(
		_on_equipment_changed
	):
		_equipment_component.equipment_changed.connect(_on_equipment_changed)
	if not _health_component.damaged.is_connected(_on_health_damaged):
		_health_component.damaged.connect(_on_health_damaged)


func _process(delta: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)

	if _use_timer > 0.0:
		if not _body_component.is_on_floor():
			cancel_item_use()
		else:
			_use_timer = maxf(_use_timer - delta, 0.0)

			if _use_timer == 0.0:
				_finish_item_use()

	if (
		_is_item_use_context_selected()
		and _input_component.consume_interact_pressed()
	):
		use_item()


func use_item() -> bool:
	if not can_use_item():
		return false

	_active_inventory_item_id = _get_selected_inventory_item_id()
	_use_timer = config.use_duration
	item_use_started.emit(
		_inventory_component.get_item_data(_active_inventory_item_id)
		if not _active_inventory_item_id.is_empty()
		else null
	)
	return true


func begin_inventory_item_use(item_id: StringName) -> bool:
	if not can_begin_inventory_item_use(item_id):
		return false
	var item := _inventory_component.get_item_data(item_id)
	_active_inventory_item_id = item_id
	_use_timer = config.use_duration
	item_use_started.emit(item)
	return true


func can_begin_inventory_item_use(item_id: StringName) -> bool:
	if (
		not is_enabled
		or is_using_item()
		or not _body_component.is_on_floor()
		or _cooldown_timer > 0.0
		or not _health_component.is_alive()
		or BEHAVIOR_GATE.is_blocked(actor, self)
		or _inventory_component == null
		or not _inventory_component.has_item(item_id)
	):
		return false
	return _can_apply_inventory_item(_inventory_component.get_item_data(item_id))


func can_use_item() -> bool:
	var base_conditions := (
		is_enabled
		and not is_using_item()
		and _body_component.is_on_floor()
		and _cooldown_timer <= 0.0
		and _health_component.is_alive()
		and not BEHAVIOR_GATE.is_blocked(actor, self)
	)
	if not base_conditions:
		return false

	var item_id := _get_selected_inventory_item_id()
	if not item_id.is_empty():
		var item := _inventory_component.get_item_data(item_id)
		return (
			item != null
			and _inventory_component.has_item(item_id)
			and _has_available_charge(item)
			and _can_apply_inventory_item(item)
		)

	return false


func is_using_item() -> bool:
	return _use_timer > 0.0


func is_exclusive_behavior_active() -> bool:
	return is_using_item()


func get_locomotion_blocks() -> int:
	if not is_using_item():
		return LOCOMOTION_CONSTRAINT.Block.NONE
	return (
		LOCOMOTION_CONSTRAINT.Block.HORIZONTAL
		| LOCOMOTION_CONSTRAINT.Block.JUMP
		| LOCOMOTION_CONSTRAINT.Block.DODGE
	)


func get_remaining_charges() -> int:
	var item_id := _get_selected_inventory_item_id()
	if not item_id.is_empty():
		var item := _inventory_component.get_item_data(item_id)
		if item != null and item.is_flask():
			return (
				_flask_charges_component.get_charges(item_id)
				if _flask_charges_component != null
				else 0
			)
		return _inventory_component.get_quantity(item_id)
	return 0


func cancel_item_use() -> void:
	if not is_using_item():
		return

	_use_timer = 0.0
	_active_inventory_item_id = &""
	item_use_cancelled.emit()


func disable() -> void:
	cancel_item_use()
	super.disable()


func _finish_item_use() -> void:
	_finish_inventory_item_use()


func _finish_inventory_item_use() -> void:
	var item := _inventory_component.get_item_data(_active_inventory_item_id)
	var applied_value := _apply_inventory_item(item)
	if item == null or applied_value <= 0.0:
		_active_inventory_item_id = &""
		return

	if item.is_flask():
		if (
			_flask_charges_component == null
			or not _flask_charges_component.spend_charge(item.id)
		):
			_active_inventory_item_id = &""
			return
	else:
		_inventory_component.remove_item(item.id, 1)
	_cooldown_timer = config.cooldown
	var remaining := (
		_flask_charges_component.get_charges(item.id)
		if item.is_flask()
		else _inventory_component.get_quantity(item.id)
	)
	item_used.emit(
		applied_value
			if item.get_use_effect() == ItemData.UseEffect.HEAL
			else 0.0,
		remaining
	)
	inventory_item_used.emit(item, applied_value, remaining)
	_active_inventory_item_id = &""


func _get_selected_inventory_item_id() -> StringName:
	if (
		_inventory_component == null
		or not _inventory_component.is_enabled
		or _quick_access_component == null
		or not _quick_access_component.is_enabled
	):
		return &""
	return _quick_access_component.get_active_item_id()


func _is_item_use_context_selected() -> bool:
	var item_id := _get_selected_inventory_item_id()
	if item_id.is_empty():
		return true
	var item := _inventory_component.get_item_data(item_id)
	return item != null and item.category == ItemData.Category.CONSUMABLE


func _can_apply_inventory_item(item: ItemData) -> bool:
	if item == null or item.category != ItemData.Category.CONSUMABLE:
		return false
	if not _has_available_charge(item):
		return false

	var use_value := item.get_use_value()
	var status_effect := item.get_status_effect()
	match item.get_use_effect():
		ItemData.UseEffect.HEAL:
			return (
				use_value > 0.0
				and _health_component.get_current_health()
					< _health_component.get_max_health()
			)
		ItemData.UseEffect.RESTORE_MANA:
			return (
				use_value > 0.0
				and _magic_component != null
				and _magic_component.get_mana() < _magic_component.get_max_mana()
			)
		ItemData.UseEffect.GRANT_EXPERIENCE:
			return use_value > 0.0 and _progression_component != null
		ItemData.UseEffect.APPLY_BUFF:
			return (
				status_effect != null
				and status_effect.is_valid()
				and _status_effect_component != null
			)

	return false


func _has_available_charge(item: ItemData) -> bool:
	if item == null or not item.is_flask():
		return true
	return (
		_flask_charges_component != null
		and _flask_charges_component.can_spend_charge(item.id)
	)


func _apply_inventory_item(item: ItemData) -> float:
	if not _can_apply_inventory_item(item):
		return 0.0

	var use_value := item.get_use_value()
	var status_effect := item.get_status_effect()
	match item.get_use_effect():
		ItemData.UseEffect.HEAL:
			return _health_component.heal(use_value)
		ItemData.UseEffect.RESTORE_MANA:
			return _magic_component.restore_mana(use_value)
		ItemData.UseEffect.GRANT_EXPERIENCE:
			_progression_component.gain_experience(roundi(use_value))
			return use_value
		ItemData.UseEffect.APPLY_BUFF:
			return (
				use_value
				if _status_effect_component.apply_effect(status_effect)
				else 0.0
			)

	return 0.0


func _on_equipment_changed(
	_previous_slot: EquipmentComponent.Slot,
	current_slot: EquipmentComponent.Slot
) -> void:
	if current_slot != EquipmentComponent.Slot.ITEM:
		cancel_item_use()


func _on_health_damaged(_amount: float, _current_health: float) -> void:
	cancel_item_use()
