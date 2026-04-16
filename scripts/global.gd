extends Node

# 0 = show start panel, 1 = auto-start level 1, 2 = auto-start level 2
var selected_level: int = 0

var best_scores: Dictionary = { 1: 0, 2: 0 }

const SAVE_PATHS := {
	1: "user://mourk_run_l1.save",
	2: "user://mourk_run_l2.save",
}

# Legacy single-save path — migrated on first boot
const LEGACY_SAVE := "user://mourk_run.save"

func _ready() -> void:
	_migrate_legacy_save()
	_load_all_scores()

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
