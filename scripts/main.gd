extends Control
const Model := preload("res://scripts/factory.gd")
const Adapter := preload("res://addons/gua/gua_auto_adapter.gd")
const FontAsset := preload("res://assets/MPLUS1p-Regular.ttf")
var game := Model.new()
var gua: RefCounted
var observer: RefCounted
var world_nodes: Dictionary = {}
var semantic: Dictionary = {"move": 0.0, "jump": false, "interact": false}
var locale := "ja"
var accumulator := 0.0
var fixed_clock := false
var camera_x := 0.0
var panel: PanelContainer
var panel_box: VBoxContainer
var hud: Label
var status: Label
var controls: Label
var notice := ""
var saved_size := 0
var action_log: Array = []
var menu_buttons: Dictionary = {}
var last_input := ""
var save_path := "user://factory-save.json"
var settings_path := "user://settings.json"

func tr2(ja: String, en: String) -> String:
	return ja if locale == "ja" else en

func _ready() -> void:
	var custom_save := OS.get_environment("FACTORY_SAVE_DIR")
	if not custom_save.is_empty():
		DirAccess.make_dir_recursive_absolute(custom_save)
		save_path = custom_save.path_join("factory-save.json")
		settings_path = custom_save.path_join("settings.json")
	load_settings()
	var app_theme := Theme.new()
	app_theme.default_font = FontAsset
	app_theme.default_font_size = 16
	app_theme.set_color("font_color", "Label", Color("dce9f5"))
	app_theme.set_color("font_color", "Button", Color("e9f5ff"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("233c51") if state == "normal" else Color("34637a")
		style.set_content_margin_all(6)
		style.set_corner_radius_all(5)
		app_theme.set_stylebox(state, "Button", style)
	theme = app_theme
	game.reset()
	hud = label_at(Vector2(28, 20), 28)
	status = label_at(Vector2(28, 70), 16)
	controls = label_at(Vector2(28, 652), 16)
	var pause_button := Button.new()
	pause_button.text = "Ⅱ  Esc"
	pause_button.position = Vector2(1020, 26)
	pause_button.set_meta("gua_id", "pause")
	pause_button.pressed.connect(toggle_pause)
	add_child(pause_button)
	panel = PanelContainer.new()
	panel.position = Vector2(326, 135)
	panel.size = Vector2(500, 0)
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color("122637")
	box_style.set_content_margin_all(24)
	box_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", box_style)
	add_child(panel)
	panel_box = VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 5)
	panel.add_child(panel_box)
	setup_gua()
	show_menu()

func label_at(at: Vector2, font_size: int) -> Label:
	var node := Label.new()
	node.position = at
	node.add_theme_font_size_override("font_size", font_size)
	add_child(node)
	return node

func setup_gua() -> void:
	gua = Adapter.new()
	gua.attach(self)
	gua.game_input_action_changed.connect(func(id: String, value: Variant):
		if semantic.has(id):
			semantic[id] = value)
	var actions: Array[Dictionary] = [
		{"id": "move", "description": "Horizontal motion, -1 left to 1 right", "value_type": "axis1d", "minimum": -1.0, "maximum": 1.0, "holdable": true, "active": true, "bindings": ["A/D", "Left/Right"]},
		{"id": "jump", "description": "Hold for a higher jump; release cuts ascent", "value_type": "button", "holdable": true, "active": true, "bindings": ["Space"]},
		{"id": "interact", "description": "Pick up or place nearby cargo on press", "value_type": "button", "holdable": true, "active": true, "bindings": ["E"]}]
	if not gua.configure_game_input_actions("factory", actions, true):
		push_error("Gua action configuration failed")
	var port := int(OS.get_environment("GUA_BRIDGE_PORT"))
	if port == 0:
		port = 18241
	if not gua.start_inspector_bridge(port):
		push_error("Gua bridge bind failed: %s" % port)
	fixed_clock = OS.get_cmdline_user_args().has("--fixed-clock")
	if fixed_clock:
		gua.clock_install(0.0, 1000.0 / 60.0)
		gua.clock_pause()
		gua.clock_tick.connect(func(delta: float): advance(delta))
	for id in ["robot", "cargo", "platform", "press", "goal", "checkpoint"]:
		var node := Node2D.new()
		node.name = id
		node.set_meta("gua_world_id", id)
		node.set_meta("gua_world_label", id)
		node.add_to_group("gua_world_object")
		add_child(node)
		world_nodes[id] = node
	update_world()
	gua.update(game.mode)
	# No additional exposure rules: Observe defaults and standard Gua policy apply.
	observer = gua.create_observe_owner(3)
	for key in ["mode", "stage", "frame", "carrying", "cargo_lost", "checkpoint", "deaths", "deliveries", "outcomes", "paused", "pending_respawn", "softlocked", "support", "last_event", "seed", "bugs"]:
		observer.observe(key, observed_value.bind(key))
	observer.observe("press_active", func(): return {"type": "bool", "value": game.press_active()})
	observer.observe("grounded", func(): return {"type": "bool", "value": game.grounded})
	print("FACTORY_READY bridge=%s gua=1.1.2 fixed_clock=%s scenario=%s" % [gua.inspector_bridge_url(), fixed_clock, Model.VERSION])

func observed_value(key: String) -> Dictionary:
	var value: Variant = game.snapshot()[key]
	if value is Array:
		return {"type": "list", "elementType": "string", "value": value}
	var kind := "string"
	if value is bool:
		kind = "bool"
	elif value is int:
		kind = "integer"
	return {"type": kind, "value": value}

func _exit_tree() -> void:
	if gua != null:
		gua.dispose()
	for control: BaseButton in menu_buttons.values():
		if is_instance_valid(control) and control.get_parent() == null:
			control.free()

func _process(delta: float) -> void:
	if not fixed_clock:
		advance(minf(delta, 0.1))
	update_world()
	refresh_hud()
	queue_redraw()
	gua.update(game.mode + ("-paused" if game.paused else ""))

func advance(delta: float) -> void:
	accumulator += delta
	while accumulator + 0.0000001 >= Model.DT:
		accumulator -= Model.DT
		var axis := float(semantic.move)
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			axis -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			axis += 1
		var jump := bool(semantic.jump) or Input.is_physical_key_pressed(KEY_SPACE)
		var interact := bool(semantic.interact) or Input.is_physical_key_pressed(KEY_E)
		var input_text := "%s,%s,%s" % [axis, jump, interact]
		if input_text != last_input:
			action_log.append({"stage": game.stage, "frame": game.frame, "axis": axis, "jump": jump, "interact": interact})
			last_input = input_text
		var before := game.mode
		game.tick(axis, jump, interact)
		if game.mode != before:
			show_menu()
	# Virtual clock callbacks run inside Gua.update before its World publication.
	# Synchronize positions here as well as on rendered frames.
	update_world()
	refresh_hud()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle_pause()
		get_viewport().set_input_as_handled()

func update_world() -> void:
	if world_nodes.is_empty():
		return
	world_nodes.robot.position = game.pos
	world_nodes.cargo.position = game.cargo
	world_nodes.cargo.set_meta("gua_world_active", not game.cargo_lost)
	world_nodes.platform.position = Vector2(game.platform_x, 485)
	world_nodes.press.position = game.hazard().position
	world_nodes.goal.position = game.goal().position
	world_nodes.checkpoint.position = Vector2(835, 520)

func refresh_hud() -> void:
	hud.text = tr2("配送ロボットの工場", "DELIVERY ROBOT FACTORY") + "  /  %02d—03" % (game.stage + 1)
	status.text = "%s  ·  %s  ·  %s: %d  ·  seed %d  ·  tick %d\n%s" % [
		tr2("荷物をゴールへ届けよう", "Deliver the cargo to the loading dock"),
		tr2("運搬中", "CARRYING") if game.carrying else tr2("荷物なし", "EMPTY"),
		tr2("復帰", "Deaths"), game.deaths, game.seed_value, game.frame,
		"NORMAL" if game.bugs.is_empty() else "INJECTION: " + ", ".join(game.bugs)]
	controls.text = tr2("A/D・←/→ 移動   Space ジャンプ（長押しで高く）   E 取得/設置   Esc ポーズ", "A/D · ←/→ Move   Space Jump (hold for height)   E Pick up/place   Esc Pause") + "\n" + notice
	status.set_meta("gua_id", "status")

func button(id: String, text: String, action: Callable) -> Button:
	var b: Button
	if menu_buttons.has(id):
		b = menu_buttons[id]
	else:
		b = Button.new()
		b.set_meta("gua_id", id)
		b.pressed.connect(action)
		menu_buttons[id] = b
	b.text = text
	panel_box.add_child(b)
	return b

func show_menu() -> void:
	for child in panel_box.get_children():
		panel_box.remove_child(child)
		if not child is BaseButton:
			child.queue_free()
	panel.visible = game.mode != "play" or game.paused
	if not panel.visible:
		return
	var heading := Label.new()
	heading.add_theme_font_size_override("font_size", 24)
	heading.text = tr2("工場へようこそ", "WELCOME TO THE FACTORY")
	if game.mode == "result":
		heading.text = tr2("配送完了！ 3 / 3", "ALL DELIVERIES COMPLETE! 3 / 3")
	elif game.paused:
		heading.text = tr2("一時停止", "PAUSED")
	panel_box.add_child(heading)
	if game.mode == "title":
		button("start", tr2("配送を開始", "Start delivery"), func():
			game.start()
			accumulator = 0
			show_menu())
	elif game.mode == "result":
		button("replay", tr2("もう一度プレイ", "Replay"), func():
			game.replay()
			accumulator = 0
			show_menu())
	else:
		button("resume", tr2("再開", "Resume"), toggle_pause)
		button("save", tr2("セーブ", "Save"), save_game)
	button("load", tr2("ロード（停止状態で復元）", "Load (restore paused)"), load_game)
	button("language", tr2("Language → English", "言語 → 日本語"), func():
		locale = "en" if locale == "ja" else "ja"
		save_settings()
		show_menu())
	button("size", tr2("画面サイズ切替", "Change window size"), func():
		saved_size = (saved_size + 1) % 3
		apply_window_size()
		save_settings())
	button("reset", tr2("初期状態にリセット", "Reset to title"), func():
		game.reset(game.seed_value, game.bugs)
		accumulator = 0
		notice = tr2("同じシードでリセットしました", "Reset using the same seed")
		show_menu())
	if game.mode == "title":
		var seed_row := HBoxContainer.new()
		var seed_label := Label.new()
		seed_label.text = "Seed"
		seed_row.add_child(seed_label)
		var seed_control := SpinBox.new()
		seed_control.min_value = 0
		seed_control.max_value = 999999
		seed_control.value = game.seed_value
		seed_control.set_meta("gua_id", "seed")
		seed_control.value_changed.connect(func(value: float): game.reset(int(value), game.bugs))
		seed_row.add_child(seed_control)
		panel_box.add_child(seed_row)
		for bug in Model.BUGS:
			var check: CheckBox
			if menu_buttons.has(bug):
				check = menu_buttons[bug]
			else:
				check = CheckBox.new()
				check.set_meta("gua_id", bug)
				check.toggled.connect(func(enabled: bool):
					if enabled and bug not in game.bugs:
						game.bugs.append(bug)
					elif not enabled:
						game.bugs.erase(bug))
				menu_buttons[bug] = check
			check.text = bug
			check.set_pressed_no_signal(bug in game.bugs)
			panel_box.add_child(check)
	panel.reset_size()

func toggle_pause() -> void:
	if game.mode == "play":
		game.paused = not game.paused
		show_menu()

func save_game() -> void:
	var data := {"game": game.snapshot(), "locale": locale, "size": saved_size}
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		notice = "SAVE ERROR %s" % FileAccess.get_open_error()
		return
	file.store_string(JSON.stringify(data))
	file.close()
	var error := DirAccess.rename_absolute(save_path + ".tmp", save_path)
	notice = "SAVED" if error == OK else "SAVE ERROR %s" % error
	# Evidence is recorded separately; it is never used to drive gameplay.
	var evidence := FileAccess.open(save_path.get_base_dir().path_join("last-run.json"), FileAccess.WRITE)
	if evidence != null:
		evidence.store_string(JSON.stringify({"scenario": Model.VERSION, "seed": game.seed_value, "bugs": game.bugs, "history": game.history, "inputs": action_log}))

func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		notice = tr2("セーブがありません", "No save found")
		return
	var data: Variant = parse_json_file(save_path)
	if not valid_settings(data) or not data.get("game") is Dictionary or not game.restore(data.game):
		notice = "LOAD ERROR: invalid save"
		return
	locale = data.locale
	saved_size = int(data.size)
	game.paused = game.mode == "play"
	accumulator = 0
	notice = "LOADED"
	apply_window_size()
	save_settings()
	show_menu()

func load_settings() -> void:
	if FileAccess.file_exists(settings_path):
		var data: Variant = parse_json_file(settings_path)
		if valid_settings(data):
			locale = data.locale
			saved_size = int(data.size)
	apply_window_size()

func valid_settings(data: Variant) -> bool:
	if not data is Dictionary or data.get("locale") not in ["ja", "en"]:
		return false
	var value: Variant = data.get("size")
	return (value is int or value is float) and value >= 0 and value <= 2 and value == floor(value)

func parse_json_file(path: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data

func save_settings() -> void:
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"locale": locale, "size": saved_size}))

func apply_window_size() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size([Vector2i(960, 600), Vector2i(1152, 720), Vector2i(1440, 900)][saved_size])

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 720), Color("091724"))
	camera_x = clampf(game.pos.x - 390, 0, 640)
	for x in range(0, 2000, 80):
		draw_line(Vector2(x - camera_x * 0.3, 130), Vector2(x - camera_x * 0.3, 640), Color("132b3e"), 1)
	draw_string(FontAsset, Vector2(30, 260), "FACTORY / %02d" % (game.stage + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color("142e42"))
	for rect: Rect2 in game.platforms():
		var screen := Rect2(rect.position + Vector2(-camera_x, 70), rect.size)
		draw_rect(screen, Color("29475b"))
		draw_line(screen.position, screen.position + Vector2(rect.size.x, 0), Color("76a2ba"), 3)
	if game.stage >= 1:
		var conveyor := Rect2(865 - camera_x, 581, 170, 9)
		draw_rect(conveyor, Color("e4ad5a"))
		for x in range(865, 1035, 18):
			draw_line(Vector2(x - camera_x, 586), Vector2(x + 8 - camera_x, 586), Color("533819"), 3)
	var press := game.hazard()
	draw_rect(Rect2(press.position + Vector2(-camera_x, 70), press.size), Color("ef6575") if game.press_active() else Color("6d7886"))
	draw_string(FontAsset, Vector2(1070 - camera_x, 365), tr2("プレス", "PRESS"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ed8b94"))
	if game.stage == 2:
		draw_rect(Rect2(1512 - camera_x, 530, 30, 60), Color("ef6575") if game.press_active() else Color("29475b"))
	draw_rect(Rect2(1530 - camera_x, 530, 92, 60), Color("337b72"), false, 4)
	draw_string(FontAsset, Vector2(1520 - camera_x, 520), "DELIVERY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("73e0be"))
	draw_line(Vector2(835 - camera_x, 590), Vector2(835 - camera_x, 530), Color("73e0be"), 3)
	draw_rect(Rect2(835 - camera_x, 530, 28, 18), Color("73e0be") if game.checkpoint else Color("406358"))
	if not game.cargo_lost:
		draw_rect(Rect2(game.cargo + Vector2(-camera_x, 70), Vector2(24, 20)), Color("f3b562"))
	var robot := Rect2(game.pos + Vector2(-camera_x, 70), Model.SIZE)
	draw_rect(robot, Color("65cee1"))
	draw_rect(Rect2(robot.position + Vector2(4, 7), Vector2(22, 12)), Color("142a40"))
	draw_circle(robot.position + Vector2(9, 12), 2, Color("edfaff"))
	draw_circle(robot.position + Vector2(21, 12), 2, Color("edfaff"))
	draw_circle(robot.position + Vector2(6, 41), 6, Color("071018"))
	draw_circle(robot.position + Vector2(24, 41), 6, Color("071018"))
	draw_rect(Rect2(0, 640, 1152, 80), Color("102536"))
