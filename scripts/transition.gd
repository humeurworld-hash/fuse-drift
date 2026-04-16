extends CanvasLayer

var _overlay: ColorRect
var _busy := false

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

func fade_to(scene_path: String, duration: float = 0.3) -> void:
	if _busy:
		return
	_busy = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_overlay, "color", Color(0, 0, 0, 1.0), duration)
	await t.finished
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	t = create_tween()
	t.tween_property(_overlay, "color", Color(0, 0, 0, 0.0), duration)
	await t.finished
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
