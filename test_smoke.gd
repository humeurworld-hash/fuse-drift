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
	_check(veiled == 4, "level 5 has 4 veils (%d)" % veiled)
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

	# Win/lose paths build their panels without erroring.
	game._finish(false)
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
