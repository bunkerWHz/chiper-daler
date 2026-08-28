extends RefCounted
class_name QuickAccessSlot

enum Kind {
	EMPTY,
	WEAPON_SET,
	ITEM,
}

var kind: Kind = Kind.EMPTY
var weapon_set: int = -1
var item_id: StringName


static func weapon_set_slot(set_index: int) -> QuickAccessSlot:
	var slot := QuickAccessSlot.new()
	slot.kind = Kind.WEAPON_SET
	slot.weapon_set = set_index
	return slot


static func item_slot(id: StringName) -> QuickAccessSlot:
	var slot := QuickAccessSlot.new()
	slot.kind = Kind.ITEM
	slot.item_id = id
	return slot


func duplicate_slot() -> QuickAccessSlot:
	var result := QuickAccessSlot.new()
	result.kind = kind
	result.weapon_set = weapon_set
	result.item_id = item_id
	return result
