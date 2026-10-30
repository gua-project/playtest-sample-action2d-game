extends RefCounted
## Deterministic swept-top platform physics. All gameplay clocks use tick().
const VERSION := "factory-scenario-1"
const DT := 1.0 / 60.0
const SIZE := Vector2(30, 42)
const BUGS := ["B01_PLATFORM_RESPAWN", "B02_CARGO_LOSS", "B03_DOUBLE_RESULT"]
var seed_value := 112
var bugs: Array = []
var mode := "title"
var stage := 0
var frame := 0
var pos := Vector2(64, 478)
var velocity := Vector2.ZERO
var grounded := true
var support := "floor"
var carrying := false
var cargo := Vector2(180, 500)
var cargo_lost := false
var checkpoint := false
var deaths := 0
var deliveries := 0
var outcomes := 0
var pending_respawn := false
var softlocked := false
var paused := false
var last_event := "ready"
var history: Array = []
var coyote := 0
var buffer := 0
var previous_jump := false
var previous_interact := false
var platform_x := 620.0

func reset(new_seed: int = 112, new_bugs: Array = []) -> void:
	seed_value = new_seed
	bugs = new_bugs.duplicate()
	stage = 0
	deaths = 0
	deliveries = 0
	outcomes = 0
	history.clear()
	paused = false
	mode = "title"
	initialize_stage()

func initialize_stage() -> void:
	frame = 0
	pos = Vector2(64, 478)
	velocity = Vector2.ZERO
	grounded = true
	support = "floor"
	carrying = false
	cargo = Vector2(180, 500)
	cargo_lost = false
	checkpoint = false
	pending_respawn = false
	softlocked = false
	coyote = 0
	buffer = 0
	previous_jump = false
	previous_interact = false
	platform_x = platform_position()
	_event("stage_ready")

func start() -> void:
	mode = "play"
	paused = false
	initialize_stage()

func replay() -> void:
	reset(seed_value, bugs)
	start()

func platforms() -> Array:
	# The final gap and dangerous loading dock deliberately require timing.
	return [Rect2(0, 520, 510, 160), Rect2(790, 520, 1000, 160),
		Rect2(360, 445, 130, 18), Rect2(565, 440, 95, 18),
		Rect2(710, 445, 110, 18), Rect2(platform_x, 485, 104, 16)]

func platform_position() -> float:
	return 603.0 + sin((float(frame) / 60.0 + float(seed_value % 17) * 0.1) * TAU / 4.0) * 90.0

func press_active() -> bool:
	var period := 240 if stage < 2 else 180
	return (frame + seed_value % 60) % period >= period * 2 / 3

func hazard() -> Rect2:
	return Rect2(1100, 310, 64, 210) if press_active() else Rect2(1100, 310, 64, 38)

func goal() -> Rect2:
	return Rect2(1530, 460, 92, 60)

func tick(axis: float, jump: bool, interact: bool) -> void:
	if mode != "play" or paused:
		previous_jump = jump
		previous_interact = interact
		return
	if pending_respawn:
		respawn()
		return
	if softlocked:
		return
	frame += 1
	var old_platform := platform_x
	platform_x = platform_position()
	if grounded and support == "moving":
		pos.x += platform_x - old_platform
	if jump and not previous_jump:
		buffer = 7
	previous_jump = jump
	if interact and not previous_interact:
		interact_cargo()
	previous_interact = interact
	if grounded:
		coyote = 6
	else:
		coyote = maxi(0, coyote - 1)
	var speed := 174.0 if carrying else 245.0
	velocity.x = clampf(axis, -1, 1) * speed
	if stage >= 1 and grounded and pos.x >= 865 and pos.x < 1035:
		velocity.x += 75.0
	if buffer > 0 and coyote > 0:
		velocity.y = -425.0 if carrying else -500.0
		grounded = false
		coyote = 0
		buffer = 0
	if not jump and velocity.y < -180.0:
		velocity.y = -180.0
	buffer = maxi(0, buffer - 1)
	velocity.y = minf(900, velocity.y + 1150.0 * DT)
	var old_bottom := pos.y + SIZE.y
	pos.x = clampf(pos.x + velocity.x * DT, 0, 1740)
	pos.y += velocity.y * DT
	grounded = false
	support = "air"
	var surfaces := platforms()
	for i in surfaces.size():
		var surface: Rect2 = surfaces[i]
		if velocity.y >= 0 and old_bottom <= surface.position.y + 0.1 and pos.y + SIZE.y >= surface.position.y and pos.x + SIZE.x > surface.position.x and pos.x < surface.end.x:
			pos.y = surface.position.y - SIZE.y
			velocity.y = 0
			grounded = true
			support = "moving" if i == 5 else "floor"
			break
	if carrying:
		cargo = pos + Vector2(0, -22)
	elif not cargo_lost:
		# Dropped cargo settles on a supporting surface and resets after a fall.
		var bottom := cargo.y + 20
		cargo.y += 240 * DT
		for surface: Rect2 in surfaces:
			if bottom <= surface.position.y + 0.1 and cargo.y + 20 >= surface.position.y and cargo.x + 24 > surface.position.x and cargo.x < surface.end.x:
				cargo.y = surface.position.y - 20
				break
		if cargo.y > 700:
			cargo = Vector2(850, 500) if checkpoint else Vector2(180, 500)
	if pos.x > 825 and grounded and not checkpoint:
		checkpoint = true
		_event("checkpoint")
	var at_goal := Rect2(pos, SIZE).intersects(goal()) and carrying
	var dead := pos.y > 680 or Rect2(pos, SIZE).intersects(hazard())
	# Stage 3's dock has a periodic gate overlapping the left edge of the goal.
	if stage == 2 and press_active() and Rect2(pos, SIZE).intersects(Rect2(1512, 460, 30, 60)):
		dead = true
	resolve_contacts(dead, at_goal)

func resolve_contacts(dead: bool, at_goal: bool) -> void:
	# Death wins the tick, always. Injection B03 deliberately violates this.
	if dead:
		die()
		if at_goal and "B03_DOUBLE_RESULT" in bugs:
			_event("BUG_double_result")
			complete_stage()
	elif at_goal:
		complete_stage()

func interact_cargo() -> void:
	if carrying:
		carrying = false
		cargo = pos + Vector2(32, 15)
		_event("cargo_placed")
	elif not cargo_lost and pos.distance_to(cargo) < 68:
		carrying = true
		_event("cargo_picked")

func die() -> void:
	deaths += 1
	outcomes += 1
	if carrying and "B02_CARGO_LOSS" in bugs:
		cargo_lost = true
	carrying = false
	pending_respawn = true
	if pos.y > 680 and pos.x > 510 and pos.x < 790 and "B01_PLATFORM_RESPAWN" in bugs:
		softlocked = true
		pending_respawn = false
	_event("death")

func respawn() -> void:
	pending_respawn = false
	pos = Vector2(835, 478) if checkpoint else Vector2(64, 478)
	velocity = Vector2.ZERO
	grounded = true
	support = "floor"
	carrying = false
	if not cargo_lost:
		cargo = Vector2(880, 500) if checkpoint else Vector2(180, 500)
	previous_jump = false
	previous_interact = false
	buffer = 0
	coyote = 0
	_event("respawn")

func complete_stage() -> void:
	deliveries += 1
	outcomes += 1
	_event("delivery")
	if stage == 2:
		mode = "result"
	else:
		stage += 1
		initialize_stage()

func _event(event: String) -> void:
	last_event = event
	history.append({"event": event, "frame": frame, "stage": stage, "bugs": bugs.duplicate()})
	if history.size() > 120:
		history.pop_front()

func snapshot() -> Dictionary:
	return {"version": VERSION, "seed": seed_value, "bugs": bugs.duplicate(), "mode": mode,
		"stage": stage, "frame": frame, "pos": [pos.x, pos.y], "velocity": [velocity.x, velocity.y],
		"grounded": grounded, "support": support, "carrying": carrying, "cargo": [cargo.x, cargo.y],
		"cargo_lost": cargo_lost, "checkpoint": checkpoint, "deaths": deaths, "deliveries": deliveries,
		"outcomes": outcomes, "pending_respawn": pending_respawn, "softlocked": softlocked,
		"paused": paused, "last_event": last_event, "history": history.duplicate(true),
		"coyote": coyote, "buffer": buffer, "previous_jump": previous_jump, "previous_interact": previous_interact}

func restore(data: Dictionary) -> bool:
	# Validate before changing anything: malformed saves never partially apply.
	var defaults := snapshot()
	if data.get("version") != VERSION:
		return false
	for key in defaults:
		if not data.has(key) or typeof(data[key]) != typeof(defaults[key]):
			# JSON numbers decode as float, so integer fields accept integral floats.
			if not (defaults[key] is int and data.get(key) is float and is_finite(data[key]) and data[key] == floor(data[key])):
				return false
	for field in ["pos", "velocity", "cargo"]:
		if data[field].size() != 2:
			return false
		for value in data[field]:
			if not (value is float or value is int) or not is_finite(float(value)) or absf(value) > 10000:
				return false
	if int(data.stage) < 0 or int(data.stage) > 2 or int(data.frame) < 0 or int(data.frame) > 100000000 or data.mode not in ["title", "play", "result"]:
		return false
	for bug in data.bugs:
		if bug not in BUGS:
			return false
	seed_value = int(data.seed)
	bugs = data.bugs.duplicate()
	mode = data.mode
	stage = int(data.stage)
	frame = int(data.frame)
	pos = Vector2(data.pos[0], data.pos[1])
	velocity = Vector2(data.velocity[0], data.velocity[1])
	grounded = data.grounded
	support = data.support
	carrying = data.carrying
	cargo = Vector2(data.cargo[0], data.cargo[1])
	cargo_lost = data.cargo_lost
	checkpoint = data.checkpoint
	deaths = int(data.deaths)
	deliveries = int(data.deliveries)
	outcomes = int(data.outcomes)
	pending_respawn = data.pending_respawn
	softlocked = data.softlocked
	paused = data.paused
	last_event = data.last_event
	history = data.history.duplicate(true)
	coyote = int(data.coyote)
	buffer = int(data.buffer)
	previous_jump = data.previous_jump
	previous_interact = data.previous_interact
	platform_x = platform_position()
	return true
