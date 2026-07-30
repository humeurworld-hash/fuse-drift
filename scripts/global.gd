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
const LEVELS := [
	{ "moves": 25, "colors": 3, "goals": { 0: 15, 1: 15 },                       "veils": 0 },
	{ "moves": 24, "colors": 3, "goals": { 0: 14, 1: 14, 2: 14 },                "veils": 0 },
	{ "moves": 24, "colors": 4, "goals": { 0: 20, 3: 20 },                       "veils": 0 },
	{ "moves": 22, "colors": 4, "goals": { 0: 13, 1: 13, 2: 13, 3: 13 },         "veils": 0 },
	{ "moves": 22, "colors": 4, "goals": { 1: 20 },                              "veils": 4 },
	{ "moves": 22, "colors": 4, "goals": { 0: 16, 2: 16 },                       "veils": 6 },
	{ "moves": 25, "colors": 5, "goals": { 0: 15, 1: 15, 4: 15 },                "veils": 0 },
	{ "moves": 23, "colors": 5, "goals": { 3: 18, 4: 18 },                       "veils": 6 },
	{ "moves": 21, "colors": 5, "goals": { 0: 11, 1: 11, 2: 11, 3: 11, 4: 11 },  "veils": 0 },
	{ "moves": 24, "colors": 5, "goals": { 4: 22, 0: 18 },                       "veils": 8 },
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
