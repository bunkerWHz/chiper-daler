extends RefCounted
class_name PauseLease

const STATE_KEY: StringName = &"_game_pause_leases"

var _tree_ref: WeakRef


## Hold this lease while a screen or scenario needs the game paused.
## Other owners must acquire their own lease instead of writing tree.paused.
static func acquire(tree: SceneTree) -> PauseLease:
	var lease := PauseLease.new()
	lease._tree_ref = weakref(tree)
	if not tree.has_meta(STATE_KEY):
		tree.set_meta(STATE_KEY, {"owners": 0, "was_paused": tree.paused})
	var state: Dictionary = tree.get_meta(STATE_KEY)
	state.owners += 1
	tree.paused = true
	return lease


func release() -> void:
	var tree_ref := _tree_ref
	_tree_ref = null
	PauseLease._release_tree(tree_ref)


static func _release_tree(tree_ref: WeakRef) -> void:
	if tree_ref == null:
		return
	var tree := tree_ref.get_ref() as SceneTree
	if tree == null or not tree.has_meta(STATE_KEY):
		return
	var state: Dictionary = tree.get_meta(STATE_KEY)
	state.owners -= 1
	if int(state.owners) == 0:
		tree.remove_meta(STATE_KEY)
		tree.paused = bool(state.was_paused)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		PauseLease._release_tree(_tree_ref)
