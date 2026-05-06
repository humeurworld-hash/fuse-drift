extends Node2D

const BG_PATHS := [
	"res://scenes/menu/Landing Page.PNG",
	"res://scenes/menu/Menu Background.PNG",
	"res://scenes/menu/menu_bg.PNG",
	"res://scenes/menu/menu_bg.png",
]

@onready var background_art: Sprite2D = $BackgroundArt
@onready var fallback_bg: ColorRect = $FallbackBG
@onready var tap_label: Label = $UI/TapLabel
@onready var title_label: Label = $UI/TitleLabel
@onready var subtitle_label: Label = $UI/SubtitleLabel

var _ready_to_tap := false

func _ready() -> void:
	var has_art := _setup_background()
	# If no background art loaded, show title/subtitle so the screen isn't blank
	if not has_art:
		title_label.visible = true
		subtitle_label.visible = true
		var tt := title_label.create_tween()
		tt.tween_property(title_label, "modulate", Color(1, 1, 1, 1), 0.55) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var st := subtitle_label.create_tween()
		st.tween_interval(0.3)
		st.tween_property(subtitle_label, "modulate", Color(1, 1, 1, 1), 0.45) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Small delay before accepting input so it doesn't skip immediately
	await get_tree().create_timer(0.6).timeout
	_ready_to_tap = true
	# Pulse the tap label
	var tween := tap_label.create_tween().set_loops()
	tween.tween_property(tap_label, "modulate:a", 0.2, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(tap_label, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)

func _input(event: InputEvent) -> void:
	if not _ready_to_tap:
		return
	var is_tap: bool = event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var is_click: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if is_tap or is_click:
		_ready_to_tap = false
		get_viewport().set_input_as_handled()
		Transition.fade_to("res://scenes/menu/Menu.tscn")

# Returns true if background art loaded successfully
func _setup_background() -> bool:
	var vp := get_viewport_rect().size
	fallback_bg.size = vp
	background_art.visible = false
	for path in BG_PATHS:
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			if tex:
				background_art.texture = tex
				background_art.position = vp * 0.5
				var s := tex.get_size()
				background_art.scale = Vector2.ONE * maxf(vp.x / s.x, vp.y / s.y)
				background_art.visible = true
				return true
	return false
