extends SceneTree


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var requested_suites := OS.get_cmdline_user_args()
	var suites: Array = []
	var found_names := PackedStringArray()
	var files := DirAccess.get_files_at("res://tests")
	files.sort()
	for file: String in files:
		if not file.begins_with("test_") or not file.ends_with(".gd"):
			continue
		var script := load("res://tests/" + file) as Script
		if script == null or not script.can_instantiate():
			push_error("Cannot load test suite: " + file)
			quit(1)
			return
		var suite := script.new() as McpTestSuite
		if suite == null:
			push_error("Not a McpTestSuite: " + file)
			quit(1)
			return
		found_names.append(suite.suite_name())
		if requested_suites.is_empty() or suite.suite_name() in requested_suites:
			suites.append(suite)
	for requested: String in requested_suites:
		if requested not in found_names:
			push_error("Unknown suite: " + requested)
			quit(1)
			return
	if suites.is_empty():
		push_error("No test suites found")
		quit(1)
		return
	var runner := McpTestRunner.new()
	var results := runner.run_suites(suites)
	print(JSON.stringify(results))
	quit(1 if int(results.get("failed", 0)) > 0 else 0)
