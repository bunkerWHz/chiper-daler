@tool
extends McpTestSuite


func suite_name() -> String:
	return "pause_lease"


func test_last_owner_resumes_game_regardless_of_release_order() -> void:
	var tree := track(SceneTree.new()) as SceneTree
	for release_first in [true, false]:
		var first := PauseLease.acquire(tree)
		var second := PauseLease.acquire(tree)
		assert_true(tree.paused)
		var early := first if release_first else second
		var late := second if release_first else first
		early.release()
		assert_true(tree.paused)
		early.release()
		assert_true(tree.paused)
		late.release()
		assert_false(tree.paused)
		assert_false(tree.has_meta(PauseLease.STATE_KEY))


func test_preexisting_pause_is_preserved() -> void:
	var tree := track(SceneTree.new()) as SceneTree
	tree.paused = true
	var lease := PauseLease.acquire(tree)
	lease.release()
	assert_true(tree.paused)
	assert_false(tree.has_meta(PauseLease.STATE_KEY))


func test_dropping_lease_releases_its_pause() -> void:
	var tree := track(SceneTree.new()) as SceneTree
	var lease := PauseLease.acquire(tree)
	assert_true(tree.paused)
	lease = null
	assert_false(tree.paused)
	assert_false(tree.has_meta(PauseLease.STATE_KEY))


func test_release_after_tree_is_freed_is_safe() -> void:
	var tree := SceneTree.new()
	var lease := PauseLease.acquire(tree)
	tree.free()
	lease.release()
	assert_true(true, "Release must not access a freed SceneTree")
