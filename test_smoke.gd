extends Node

# Headless smoke test: drives the board logic directly.

var fails := 0


func _ready() -> void:
	await get_tree().process_frame
	var game = load("res://scenes/Game.tscn").instantiate()
	G.current_level = 4  # level with veils
	get_tree().root.add_child(game)
	await get_tree().process_frame

	_check(game.grid.size() == 6, "grid has 6 columns")
	var count := 0
	var veiled := 0
	for c in 6:
		for r in 6:
			if game.grid[c][r] != null:
				count += 1
				if game.grid[c][r].veiled:
					veiled += 1
	_check(count == 36, "board full at start (%d)" % count)
	var want_veils: int = G.LEVELS[4].veils
	_check(veiled == want_veils, "level 5 veils match its definition (%d)" % veiled)
	_check(game._has_move(), "a move exists at start")

	# Find an adjacent same-hue unveiled pair and resolve it.
	var pair := []
	for c in 6:
		for r in 6:
			var d = game.grid[c][r]
			if d == null or d.veiled:
				continue
			var n = game._dot_at(Vector2i(c + 1, r))
			if n != null and not n.veiled and n.color_idx == d.color_idx:
				pair = [Vector2i(c, r), Vector2i(c + 1, r)]
				break
		if not pair.is_empty():
			break
	_check(not pair.is_empty(), "found a weavable pair")

	var color: int = game._dot_at(pair[0]).color_idx
	var moves_before: int = game.moves_left
	var goal_before: int = game.goals.get(color, -1)
	await game._resolve(pair, color)

	_check(game.moves_left == moves_before - 1, "move consumed")
	if goal_before >= 0:
		_check(game.goals[color] == maxi(0, goal_before - 2), "goal decremented by 2")
	count = 0
	for c in 6:
		for r in 6:
			if game.grid[c][r] != null:
				count += 1
				_check(game.grid[c][r].cell == Vector2i(c, r), "dot cell matches grid slot")
	_check(count == 36, "board refilled to 36 (%d)" % count)
	_check(game._has_move(), "a move exists after refill")

	# Loop-close clear: gather every unveiled mote of one hue.
	var loop_color: int = game._dot_at(Vector2i(0, 0)).color_idx if not game._dot_at(Vector2i(0, 0)).veiled else game._dot_at(Vector2i(1, 1)).color_idx
	var cells := []
	for c in 6:
		for r in 6:
			var d = game.grid[c][r]
			if d != null and not d.veiled and d.color_idx == loop_color:
				cells.append(Vector2i(c, r))
	await game._resolve(cells, loop_color)
	count = 0
	for c in 6:
		for r in 6:
			if game.grid[c][r] != null:
				count += 1
	_check(count == 36, "board refilled after loop clear (%d)" % count)

	# Input-driven weave: push real touch events through the viewport and
	# verify they reach the board (guards against GUI eating touches).
	var pair2 := []
	for c in 6:
		for r in 6:
			var d = game.grid[c][r]
			if d == null or d.veiled:
				continue
			var n = game._dot_at(Vector2i(c + 1, r))
			if n != null and not n.veiled and n.color_idx == d.color_idx:
				pair2 = [Vector2i(c, r), Vector2i(c + 1, r)]
				break
		if not pair2.is_empty():
			break
	_check(not pair2.is_empty(), "found a pair for touch test")
	var moves_before2: int = game.moves_left
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = game._cell_pos(pair2[0])
	game.get_viewport().push_input(press, true)
	await get_tree().process_frame
	_check(game.dragging, "touch press starts a drag")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = game._cell_pos(pair2[1])
	game.get_viewport().push_input(drag, true)
	await get_tree().process_frame
	_check(game.path.size() == 2, "touch drag weaves second shard (%d)" % game.path.size())
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = game._cell_pos(pair2[1])
	game.get_viewport().push_input(release, true)
	await get_tree().process_frame
	for i in 60:
		if not game.busy:
			break
		await get_tree().process_frame
	_check(game.moves_left == moves_before2 - 1, "touch release resolves the weave")

	# Fresh board for the remaining mechanic checks.
	game.queue_free()
	await get_tree().process_frame
	game = load("res://scenes/Game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame

	# Resonance: a resonant shard joins a thread of any hue.
	var res_pair := []
	for c in 6:
		for r in 6:
			var d = game.grid[c][r]
			if d == null or d.veiled or d.echo_timer > 0:
				continue
			var n = game._dot_at(Vector2i(c + 1, r))
			if n != null and not n.veiled and n.echo_timer <= 0 and n.color_idx != d.color_idx:
				res_pair = [Vector2i(c, r), Vector2i(c + 1, r)]
				break
		if not res_pair.is_empty():
			break
	_check(not res_pair.is_empty(), "found a mismatched pair for resonance test")
	var rd = game._dot_at(res_pair[0])
	rd.resonant = true
	var moves_before3: int = game.moves_left
	var p2 := InputEventScreenTouch.new()
	p2.pressed = true
	p2.position = game._cell_pos(res_pair[0])
	game.get_viewport().push_input(p2, true)
	await get_tree().process_frame
	var d2 := InputEventScreenDrag.new()
	d2.position = game._cell_pos(res_pair[1])
	game.get_viewport().push_input(d2, true)
	await get_tree().process_frame
	_check(game.path.size() == 2, "resonant shard weaves into a mismatched hue (%d)" % game.path.size())
	var r2 := InputEventScreenTouch.new()
	r2.pressed = false
	r2.position = game._cell_pos(res_pair[1])
	game.get_viewport().push_input(r2, true)
	await get_tree().process_frame
	for i in 90:
		if not game.busy:
			break
		await get_tree().process_frame
	_check(game.moves_left <= moves_before3 - 1 + 1, "resonant weave resolved")

	# Diagonal adjacency + the minimum-loop guard.
	_check(game._adjacent(Vector2i(2, 2), Vector2i(3, 3)), "diagonal cells are adjacent")
	_check(game._adjacent(Vector2i(2, 2), Vector2i(3, 2)), "orthogonal cells are adjacent")
	_check(not game._adjacent(Vector2i(2, 2), Vector2i(4, 4)), "distant cells are not adjacent")
	_check(not game._adjacent(Vector2i(2, 2), Vector2i(2, 2)), "a cell is not adjacent to itself")
	_check(game._neighbours(Vector2i(2, 2)).size() == 8, "a cell has 8 neighbours")

	# Force a uniform patch, then verify a 3-shard diagonal L cannot close a
	# loop but a 4-shard square can.
	for c in 4:
		for r in 4:
			var dd = game.grid[c][r]
			dd.veiled = false
			dd.resonant = false
			dd.warden = false      # levels spawn drones; clear the test patch
			dd.echo_timer = 0
			dd.color_idx = 0
			dd.queue_redraw()
	game.busy = false
	game.game_over = false
	_weave(game, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0)])
	_check(not game.loop_closed, "3-shard diagonal L cannot close a loop")
	_check(game.path.size() == 3, "rejected close left the path intact (%d)" % game.path.size())
	game.dragging = false
	game.path.clear()
	game.loop_closed = false

	_weave(game, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(0, 0)])
	_check(game.loop_closed, "4-shard square closes a loop")
	game.dragging = false
	game.path.clear()
	game.loop_closed = false

	# Colour switching through a resonant shard (the Grindstone move).
	game.grid[0][0].color_idx = 0
	game.grid[1][0].resonant = true
	game.grid[1][0].queue_redraw()
	game.grid[2][0].color_idx = 2
	game.grid[2][0].queue_redraw()
	_weave(game, [Vector2i(0, 0), Vector2i(1, 0)])
	_check(game.switch_armed, "resonant shard arms a hue switch")
	_weave(game, [Vector2i(2, 0)], false)
	_check(game.path.size() == 3, "thread continues into a new hue (%d)" % game.path.size())
	_check(game.thread_color == 2, "thread hue switched to the new shard (%d)" % game.thread_color)
	_check(not game.switch_armed, "switch is spent after use")
	# ...and a second mismatched hue in a row is refused.
	game.grid[3][0].color_idx = 3
	game.grid[3][0].resonant = false
	game.grid[3][0].queue_redraw()
	_weave(game, [Vector2i(3, 0)], false)
	_check(game.path.size() == 3, "a second hue change without a resonance is refused")
	# Backtracking restores the pre-switch hue.
	_weave(game, [Vector2i(1, 0)], false)
	_check(game.switch_armed, "backtracking onto the resonance re-arms the switch")
	game.dragging = false
	game.path.clear()

	# ── Shape detection ──────────────────────────────────────────────────────
	# Straight diagonal run.
	game.path = _p([[0,0],[1,1],[2,2]])
	game.loop_closed = false
	var sh = game._analyse_shape()
	_check(sh.facet == 3, "3-shard diagonal is a facet (%d)" % sh.facet)
	game.path = _p([[0,0],[1,1],[2,2],[3,3],[4,4]])
	sh = game._analyse_shape()
	_check(sh.facet == 5, "5-shard diagonal run measured (%d)" % sh.facet)
	# A bend breaks the run.
	game.path = _p([[0,0],[1,1],[2,1],[3,2]])
	sh = game._analyse_shape()
	_check(sh.facet == 2, "a bend breaks the diagonal run (%d)" % sh.facet)
	# Orthogonal lines are not facets.
	game.path = _p([[0,0],[1,0],[2,0],[3,0]])
	sh = game._analyse_shape()
	_check(sh.facet == 0, "a straight orthogonal line is not a facet (%d)" % sh.facet)

	# Diamond: 4 shards around a centre cell.
	game.path = _p([[1,0],[2,1],[1,2],[0,1],[1,0]])
	game.loop_closed = true
	sh = game._analyse_shape()
	_check(sh.diamond, "rhombus loop is a diamond")
	_check(sh.centre == Vector2i(1, 1), "diamond centre found (%s)" % str(sh.centre))
	# A 2x2 square is a loop but NOT a diamond — its centre falls between cells.
	game.path = _p([[0,0],[1,0],[1,1],[0,1],[0,0]])
	sh = game._analyse_shape()
	_check(not sh.diamond, "a 2x2 square is not a diamond")

	# Knot: two diagonal segments crossing the same cell square.
	game.path = _p([[0,0],[1,1],[1,0],[0,1]])
	game.loop_closed = false
	sh = game._analyse_shape()
	_check(sh.knot, "crossing diagonals make a knot")
	game.path = _p([[0,0],[1,1],[2,2]])
	sh = game._analyse_shape()
	_check(not sh.knot, "a straight diagonal is not a knot")
	game.path = _p([[0,0],[1,0],[2,0],[2,1]])
	sh = game._analyse_shape()
	_check(not sh.knot, "an orthogonal path is not a knot")
	game.path.clear()
	game.loop_closed = false

	# ── Canvas wardens ───────────────────────────────────────────────────────
	for c in 4:
		for r in 4:
			var dd = game.grid[c][r]
			dd.veiled = false
			dd.resonant = false
			dd.warden = false
			dd.echo_timer = 0
			dd.color_idx = 0
			dd.queue_redraw()
	game.grid[2][0].warden = true
	game.grid[2][0].warden_timer = 2
	game.dragging = false
	game.path.clear()
	game.loop_closed = false

	# A thread cannot begin on a drone.
	game._start_drag(game._cell_pos(Vector2i(2, 0)))
	_check(not game.dragging, "a thread cannot start on a warden")

	# Nor can a drone be the second shard — a thread must carry Mourk first.
	_weave(game, [Vector2i(0, 0), Vector2i(1, 0)])
	_check(game.path.size() == 2, "thread of two shards woven (%d)" % game.path.size())
	_weave(game, [Vector2i(2, 0)], false)
	_check(game.path.size() == 3, "warden struck as the third shard (%d)" % game.path.size())
	# Striking ends the thread: nothing may follow.
	_weave(game, [Vector2i(3, 0)], false)
	_check(game.path.size() == 3, "the thread ends on the warden it struck")
	# But backing off it is allowed.
	_weave(game, [Vector2i(1, 0)], false)
	_check(game.path.size() == 2, "backtracking off a struck warden works (%d)" % game.path.size())

	# Striking one clears it from the board and off the counter.
	game.dragging = false
	game.path.clear()
	var wardens_before: int = game.wardens_left
	game.busy = false
	await game._resolve([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], 0)
	_check(game.wardens_left == wardens_before - 1,
		"striking a warden takes it off the counter (%d -> %d)" % [wardens_before, game.wardens_left])

	# A drone with wardens still standing blocks the win, goals or no goals.
	game.wardens_left = 1
	for k in game.goals:
		game.goals[k] = 0
	game.veils_left = 0
	_check(not game._goals_met(), "a standing warden blocks the clear")
	game.wardens_left = 0
	_check(game._goals_met(), "clearing the last warden completes the thread")

	# A fired drone shrouds what is around it.
	var fresh = load("res://scenes/Game.tscn").instantiate()
	get_tree().root.add_child(fresh)
	await get_tree().process_frame
	var wpos := Vector2i(-1, -1)
	for c in 6:
		for r in 6:
			if fresh.grid[c][r] != null and fresh.grid[c][r].warden:
				wpos = Vector2i(c, r)
	if wpos.x >= 0:
		for n in fresh._neighbours(wpos):
			var nd = fresh._dot_at(n)
			if nd != null:
				nd.veiled = false
		var before_v := _count_veiled(fresh)
		fresh._warden_fire(wpos)
		_check(_count_veiled(fresh) > before_v,
			"a firing warden shrouds its neighbours (%d -> %d)" % [before_v, _count_veiled(fresh)])
	fresh.queue_free()
	await get_tree().process_frame

	# Win/lose paths build their panels without erroring.
	game.game_over = false
	game._finish(false)
	await get_tree().process_frame
	game.queue_free()
	await get_tree().process_frame

	# Echo shards: level 7 keeps one ticking on the board.
	G.current_level = 6
	var game2 = load("res://scenes/Game.tscn").instantiate()
	get_tree().root.add_child(game2)
	await get_tree().process_frame
	_check(_count_echo(game2) == 1, "level 7 starts with 1 echo shard (%d)" % _count_echo(game2))
	var pair4 := _find_pair(game2)
	_check(not pair4.is_empty(), "found a pair on echo board")
	await game2._resolve(pair4, game2._dot_at(pair4[0]).color_idx)
	_check(_count_echo(game2) == 1, "echo quota maintained after a move (%d)" % _count_echo(game2))
	game2.queue_free()
	await get_tree().process_frame

	if fails == 0:
		print("SMOKE OK")
	else:
		print("SMOKE FAILED: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok: " + what)
	else:
		fails += 1
		printerr("  FAIL: " + what)


func _p(coords: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in coords:
		out.append(Vector2i(c[0], c[1]))
	return out


func _weave(g, cells: Array, start := true) -> void:
	# Drive the board's drag handlers directly with board coordinates.
	var i := 0
	for cell in cells:
		if start and i == 0:
			g._start_drag(g._cell_pos(cell))
		else:
			g._update_drag(g._cell_pos(cell))
		i += 1


func _find_pair(g) -> Array:
	for c in 6:
		for r in 6:
			var d = g.grid[c][r]
			if d == null or d.veiled:
				continue
			var n = g._dot_at(Vector2i(c + 1, r))
			if n != null and not n.veiled and n.color_idx == d.color_idx \
				and not d.resonant and not n.resonant:
				return [Vector2i(c, r), Vector2i(c + 1, r)]
	return []


func _count_veiled(g) -> int:
	var n := 0
	for c in 6:
		for r in 6:
			if g.grid[c][r] != null and g.grid[c][r].veiled:
				n += 1
	return n


func _count_echo(g) -> int:
	var n := 0
	for c in 6:
		for r in 6:
			if g.grid[c][r] != null and g.grid[c][r].echo_timer > 0:
				n += 1
	return n
