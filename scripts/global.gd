extends Node

# 0 = show start panel, 1 = auto-start level 1, 2 = auto-start level 2
var selected_level: int = 0

var best_scores: Dictionary = { 1: 0, 2: 0, 3: 0 }

const SAVE_PATHS := {
	1: "user://mourk_run_l1.save",
	2: "user://mourk_run_l2.save",
	3: "user://mourk_run_l3.save",
}

# Legacy single-save path — migrated on first boot
const LEGACY_SAVE := "user://mourk_run.save"

const UNLOCK_SAVE := "user://mourk_unlocks.save"
var unlocked_levels: Array = [1]

# ── DEV FLAG ── set false before shipping ──────────────────────────────────
const DEV_UNLOCK_ALL := true

const SETTINGS_SAVE := "user://settings.cfg"
var music_volume: float = 1.0
var sfx_volume:   float = 1.0

func _ready() -> void:
	_migrate_legacy_save()
	_load_all_scores()
	_load_unlocks()
	load_audio_settings()
	if DEV_UNLOCK_ALL:
		for lvl in [1, 2, 3]:
			if not lvl in unlocked_levels:
				unlocked_levels.append(lvl)

func load_audio_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_SAVE) == OK:
		music_volume = cfg.get_value("audio", "music", 1.0)
		sfx_volume   = cfg.get_value("audio", "sfx",   1.0)
	apply_sfx_volume()

func save_audio_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx",   sfx_volume)
	cfg.save(SETTINGS_SAVE)

func apply_sfx_volume() -> void:
	var db := linear_to_db(maxf(sfx_volume, 0.001))
	AudioServer.set_bus_volume_db(0, db)

func is_unlocked(level: int) -> bool:
	return level in unlocked_levels

func unlock_level(level: int) -> void:
	if not level in unlocked_levels:
		unlocked_levels.append(level)
		_save_unlocks()

func _load_unlocks() -> void:
	if FileAccess.file_exists(UNLOCK_SAVE):
		var file := FileAccess.open(UNLOCK_SAVE, FileAccess.READ)
		if file:
			var mask := file.get_32()
			unlocked_levels.clear()
			for i in range(8):
				if mask & (1 << i):
					unlocked_levels.append(i + 1)
	if not 1 in unlocked_levels:
		unlocked_levels.append(1)

func _save_unlocks() -> void:
	var mask := 0
	for level in unlocked_levels:
		mask |= (1 << (level - 1))
	var file := FileAccess.open(UNLOCK_SAVE, FileAccess.WRITE)
	if file:
		file.store_32(mask)

func _load_all_scores() -> void:
	for level in SAVE_PATHS:
		var path: String = SAVE_PATHS[level]
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				best_scores[level] = file.get_32()

func save_best(level: int, value: int) -> void:
	if value <= best_scores.get(level, 0):
		return
	best_scores[level] = value
	var path: String = SAVE_PATHS.get(level, "")
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_32(value)

func get_best(level: int) -> int:
	return best_scores.get(level, 0)

func get_overall_best() -> int:
	var top := 0
	for level in best_scores:
		if best_scores[level] > top:
			top = best_scores[level]
	return top

func _migrate_legacy_save() -> void:
	if not FileAccess.file_exists(LEGACY_SAVE):
		return
	var file := FileAccess.open(LEGACY_SAVE, FileAccess.READ)
	if file:
		var old_best := file.get_32()
		if old_best > 0:
			# Attribute old score to level 1
			var out := FileAccess.open(SAVE_PATHS[1], FileAccess.WRITE)
			if out:
				out.store_32(old_best)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_SAVE))
