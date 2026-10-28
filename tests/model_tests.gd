extends SceneTree
const Factory := preload("res://scripts/factory.gd")
var checks := 0
var failures: Array = []
var report: Array = []

func check(value: bool, id: String) -> void:
	checks += 1
	if not value:
		failures.append(id)
		push_error(id)

func fresh(bugs: Array = []) -> RefCounted:
	var m := Factory.new()
	m.reset(112, bugs)
	m.start()
	return m

func _initialize() -> void:
	var a := fresh()
	var b := fresh()
	for i in 120:
		a.tick(1, i >= 70 and i < 105, i == 25)
		b.tick(1, i >= 70 and i < 105, i == 25)
	check(a.snapshot() == b.snapshot(), "T01 same seed/input deterministic")
	a.paused = true
	var before: Dictionary = a.snapshot()
	for i in 60:
		a.tick(0, false, false)
	check(a.frame == before.frame and a.pos == Vector2(before.pos[0], before.pos[1]), "T02 pause freezes physics and phase")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(a.snapshot()))
	check(b.restore(saved), "T03 JSON save accepted")
	check(JSON.parse_string(JSON.stringify(b.snapshot())) == JSON.parse_string(JSON.stringify(a.snapshot())), "T03 all simulation state roundtrips")
	saved.pos = ["invalid", 0]
	before = b.snapshot()
	check(not b.restore(saved) and b.snapshot() == before, "T03 malformed save is atomic")
	var high := fresh()
	var low := fresh()
	for i in 16:
		high.tick(0, true, false)
		low.tick(0, i < 3, false)
	check(high.pos.y < low.pos.y - 40, "T04 jump hold changes apex")
	var carrying := fresh()
	carrying.carrying = true
	carrying.tick(1, true, false)
	high = fresh()
	high.tick(1, true, false)
	check(carrying.velocity.x < high.velocity.x and carrying.velocity.y > high.velocity.y, "T05 carrying changes movement immediately")
	for bug in ["", "B01_PLATFORM_RESPAWN", "B02_CARGO_LOSS", "B03_DOUBLE_RESULT"]:
		var m := fresh([] if bug == "" else [bug])
		if bug == "" or bug == "B01_PLATFORM_RESPAWN":
			m.pos = Vector2(680, 685)
			m.tick(0, false, false)
			m.tick(0, false, false)
			check(m.softlocked == (bug != ""), "T06 gap recovery detector " + bug)
			if bug == "":
				check(m.pos == Vector2(64, 478) and m.deaths == 1, "T06 exactly one respawn")
		m = fresh([] if bug == "" else [bug])
		m.carrying = true
		m.die()
		m.paused = true
		m.tick(0, false, false)
		check(m.pending_respawn and m.deaths == 1, "T07 death-pause defers exactly one recovery " + bug)
		m.paused = false
		m.tick(0, false, false)
		check(not m.pending_respawn and m.cargo_lost == (bug == "B02_CARGO_LOSS"), "T07 cargo loss detector " + bug)
		m = fresh([] if bug == "" else [bug])
		m.resolve_contacts(true, true)
		check(m.deliveries == (1 if bug == "B03_DOUBLE_RESULT" else 0), "T08 death-goal priority detector " + bug)
		check(m.outcomes == (2 if bug == "B03_DOUBLE_RESULT" else 1), "T08 outcome count " + bug)
	var moving := fresh()
	moving.platform_x = moving.platform_position()
	moving.pos = Vector2(moving.platform_x + 20, 443)
	moving.support = "moving"
	var relative: float = moving.pos.x - moving.platform_x
	moving.tick(0, false, false)
	check(absf(moving.pos.x - moving.platform_x - relative) < 0.001, "T09 moving platform relative motion")
	var landing := fresh()
	landing.pos = Vector2(100, 474)
	landing.velocity.y = 300
	landing.grounded = false
	landing.tick(0, true, false)
	landing.tick(0, true, false)
	check(landing.velocity.y < 0, "T10 buffered pre-landing jump")
	var conveyor := fresh()
	conveyor.stage = 1
	conveyor.pos = Vector2(900, 478)
	conveyor.tick(0, false, false)
	check(conveyor.pos.x > 900, "T11 conveyor moves idle robot")
	var route := fresh()
	var jump_count := 0
	var jump_remaining := 0
	var prior_stage := -1
	for i in 9000:
		if route.mode == "result":
			break
		if route.stage != prior_stage:
			prior_stage = route.stage
			jump_count = 0
			jump_remaining = 0
		var x: float = route.pos.x
		var axis := 1.0
		var interact: bool = not route.carrying and x >= 140 and x < 190
		if jump_count < 3 and x >= [330, 465, 630][jump_count] and route.grounded:
			jump_remaining = 44
			jump_count += 1
		if x > 1035 and x < 1070 and not safe_phase(route):
			axis = 0
		if route.stage == 2 and x > 1450 and x < 1480 and not safe_phase(route):
			axis = 0
		route.tick(axis, jump_remaining > 0, interact)
		jump_remaining = maxi(0, jump_remaining - 1)
		if i % 120 == 0:
			report.append({"stage": route.stage, "frame": route.frame, "pos": [route.pos.x, route.pos.y], "carrying": route.carrying, "deaths": route.deaths})
	check(route.mode == "result" and route.deliveries == 3, "T12 ordinary movement/pickup/jump clears three stages")
	check(route.deaths == 0, "T12 timed route avoids hazards")
	route.replay()
	check(route.mode == "play" and route.stage == 0 and route.deliveries == 0, "T13 replay resets progression")
	print(JSON.stringify({"checks": checks, "failures": failures, "route": report}))
	quit(0 if failures.is_empty() else 1)

func safe_phase(m: RefCounted) -> bool:
	var period := 240 if m.stage < 2 else 180
	return (m.frame + m.seed_value % 60) % period < 50



