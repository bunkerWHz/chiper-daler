extends RefCounted
class_name QuickAccessSlot

enum Kind {
	EMPTY,
	ITEM,
}

var kind: Kind = Kind.EMPTY
var item_id: StringName


static func item_slot(id: StringName) -> QuickAccessSlot:
	var slot := QuickAccessSlot.new()
	slot.kind = Kind.ITEM
	slot.item_id = id
	return slot


func duplicate_slot() -> QuickAccessSlot:
	var result := QuickAccessSlot.new()
	result.kind = kind
	result.item_id = item_id
	return result
