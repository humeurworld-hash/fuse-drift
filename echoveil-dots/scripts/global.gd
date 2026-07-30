extends Node

# ── EchoVeil: Mourk Weave — global state, levels, save data ───────────────────
#
# In EchoVeil, emotion is not invisible. It becomes Mourk — crystal energy
# formed from feeling. Each hue is an emotion; weaving threads between motes
# of the same hue gathers them. Closing a loop gathers every mote of that hue.

const SAVE_PATH := "user://mourk_weave.cfg"

# Emotion palette — Mourk hues.
const DOT_COLORS := [
	Color(1.00, 0.30, 0.45),   # Ember    — anger
	Color(0.30, 0.62, 1.00),   # Sorrow   — sadness
	Color(0.36, 0.92, 0.48),   # Verdant  — calm
	Color(0.98, 0.86, 0.35),   # Radiance — joy
	Color(0.72, 0.42, 1.00),   # Umbral   — fear
]
const DOT_NAMES := ["Ember", "Sorrow", "Verdant", "Radiance", "Umbral"]

# Mourk shard art — the same crystals that appear in Fuse: Mourk Run.
const SHARD_TEXTURES := [
	preload("res://assets/shards/ember.png"),
	preload("res://assets/shards/sorrow.png"),
	preload("res://assets/shards/verdant.png"),
	preload("res://assets/shards/radiance.png"),
	preload("res://assets/shards/umbral.png"),
]

const VEIL_COLOR := Color(0.42, 0.46, 0.58)
const GOLD := Color(0.90, 0.82, 0.40)
const BG_COLOR := Color(0.03, 0.05, 0.09)

# goals: { color index -> motes to gather }.  veils: veiled motes on the board;
# every veil must be lifted to clear the level (when veils > 0).
# Mechanics arrive gradually as the threads progress:
#   resonance — chance a spawned shard is resonant (joins any thread)
#   echo      — echo shards kept on the board (countdown; rewind neighbours)
#   wardens   — Canvas drones; strike each one to clear the thread
#   note      — one-line banner shown at level start when something is new
#
# Goals are large on purpose. One well-routed thread with a facet shockwave
# gathers 15-30 shards, so the old targets were cleared with ~80% of the move
# budget untouched. These are set against measured play, not guesswork.
const LEVELS := [
	{ "moves":  9, "colors": 3, "goals": { 0: 26, 1: 26 },                       "veils": 0,
		"resonance": 0.0,  "echo": 0, "wardens": 0,
		"note": "Drag between neighbouring shards of one hue — diagonals count." },
	{ "moves":  8, "colors": 3, "goals": { 0: 24, 1: 24, 2: 24 },                "veils": 0,
		"resonance": 0.0,  "echo": 0, "wardens": 0 },
	{ "moves": 13, "colors": 4, "goals": { 0: 26, 3: 26 },                       "veils": 0,
		"resonance": 0.0,  "echo": 0, "wardens": 1,
		"note": "A Canvas warden. End a thread on it to strike it — every drone must fall." },
	{ "moves": 10, "colors": 4, "goals": { 0: 22, 1: 22, 2: 22, 3: 22 },         "veils": 0,
		"resonance": 0.06, "echo": 0, "wardens": 1,
		"note": "A resonance. Weave through one and your thread can change hue and keep going." },
	{ "moves": 11, "colors": 4, "goals": { 1: 34 },                              "veils": 5,
		"resonance": 0.06, "echo": 0, "wardens": 2,
		"note": "Veiled shards can't be woven. Gather beside them to lift the veil." },
	{ "moves": 11, "colors": 4, "goals": { 0: 28, 2: 28 },                       "veils": 7,
		"resonance": 0.06, "echo": 0, "wardens": 2 },
	{ "moves": 11, "colors": 5, "goals": { 0: 26, 1: 26, 4: 26 },                "veils": 0,
		"resonance": 0.06, "echo": 1, "wardens": 2,
		"note": "The Loops. Echo shards rewind their neighbours — gather them in time." },
	{ "moves": 12, "colors": 5, "goals": { 3: 32, 4: 32 },                       "veils": 7,
		"resonance": 0.08, "echo": 1, "wardens": 3 },
	{ "moves":  7, "colors": 5, "goals": { 0: 22, 1: 22, 2: 22, 3: 22, 4: 22 },  "veils": 0,
		"resonance": 0.08, "echo": 2, "wardens": 3 },
	{ "moves": 11, "colors": 5, "goals": { 4: 36, 0: 32 },                       "veils": 9,
		"resonance": 0.08, "echo": 2, "wardens": 4 },
]

var current_level := 0
var unlocked := 1


func _ready() -> void:
	_load()


func level_count() -> int:
	return LEVELS.size()


func unlock_through(level_index: int) -> void:
	# level_index is the level just beaten (0-based); unlock the next one.
	if level_index + 2 > unlocked:
		unlocked = mini(level_index + 2, level_count())
		_save()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		unlocked = clampi(int(cfg.get_value("progress", "unlocked", 1)), 1, level_count())


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.save(SAVE_PATH)
