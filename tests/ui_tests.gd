extends SceneTree
var failures: Array = []
var checks := 0

func check(condition: bool, id: String) -> void:
	checks += 1
	if not condition:
		failures.append(id)
		push_error(id)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var save_dir := ProjectSettings.globalize_path("res://output/ui-test-save")
	DirAccess.make_dir_recursive_absolute(save_dir)
	OS.set_environment("FACTORY_SAVE_DIR", save_dir)
	OS.set_environment("GUA_BRIDGE_PORT", "18243")
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	for language in ["ja", "en"]:
		app.locale = language
		for mode in ["title", "play", "result"]:
			app.game.mode = mode
			app.game.paused = mode == "play"
			app.show_menu()
			await process_frame
			await process_frame
			var rect: Rect2 = app.panel.get_global_rect()
			check(rect.end.x <= 1152 and rect.end.y <= 720, "U01 menu inside viewport %s %s: %s" % [language, mode, rect])
	app.game.start()
	app.game.paused = true
	app.locale = "ja"
	app.saved_size = 0
	app.save_game()
	app.game.paused = false
	for i in 20:
		app.game.tick(1, false, false)
	app.locale = "en"
	app.saved_size = 2
	app.save_settings()
	app.load_game()
	check(app.game.pos == Vector2(64, 478) and app.game.frame == 0 and app.game.paused, "U02 actual main JSON load changes state")
	check(app.locale == "ja" and app.saved_size == 0, "U03 actual main settings restored")
	app.locale = "en"
	app.saved_size = 2
	app.load_settings()
	check(app.locale == "ja" and app.saved_size == 0, "U03 loaded settings persist across initialization")
	var before: Dictionary = app.game.snapshot()
	var file := FileAccess.open(app.save_path, FileAccess.WRITE)
	file.store_string("{broken-json")
	file.close()
	app.load_game()
	check(app.game.snapshot() == before and app.notice.begins_with("LOAD ERROR"), "U04 malformed file leaves state unchanged")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
