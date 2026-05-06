extends CanvasLayer
class_name TutorialCard

signal tutorial_done

const AUTO_DISMISS := 30.0   # auto-close after 30 s if player never taps LET'S GO

const CARD_PATH := "res://scenes/game/tutorial_card.png"

var _timer: float = AUTO_DISMISS
var _card: TextureRect = null

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_dismiss()

# ── Build ───────────────────────────────────────────────────────────────────────

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size

	# Dark overlay behind the card
	var ov := ColorRect.new()
	ov.color = Color(0.0, 0.0, 0.0, 0.78)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ov)

	# ── Load image ──────────────────────────────────────────────────────────────
	if not ResourceLoader.exists(CARD_PATH):
		tutorial_done.emit()
		queue_free()
		return
	var tex: Texture2D = load(CARD_PATH)
	if tex == null:
		tutorial_done.emit()
		queue_free()
		return

	# ── Card dimensions — source image is ~1024×1103, roughly square-ish ────────
	# Fit to 92% of viewport width; clamp so it never overflows height either.
	var card_w := vp.x * 0.92
	var src := tex.get_size()
	var aspect := src.y / src.x if src.x > 0 else 1.0
	var card_h := card_w * aspect
	if card_h > vp.y * 0.92:
		card_h = vp.y * 0.92
		card_w = card_h / aspect

	_card = TextureRect.new()
	_card.texture = tex
	_card.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card.size = Vector2(card_w, card_h)
	_card.position = Vector2((vp.x - card_w) * 0.5, vp.y)   # starts below screen
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)

	# ── Transparent LET'S GO button over bottom ~15% of the card ────────────────
	# The button artwork sits in roughly the bottom 15% of the image.
	var btn := Button.new()
	btn.flat = true
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, empty)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(_dismiss)
	add_child(btn)

	# ── Slide in, then reposition the button to match the settled card ──────────
	var target_y := (vp.y - card_h) * 0.5
	var t := _card.create_tween()
	t.tween_property(_card, "position:y", target_y, 0.42) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		# Place button over the LET'S GO artwork area
		var cx := (vp.x - card_w) * 0.5
		var cy := target_y
		btn.size     = Vector2(card_w * 0.78, card_h * 0.16)
		btn.position = Vector2(cx + card_w * 0.11, cy + card_h * 0.826)
	)

# ── Dismiss ─────────────────────────────────────────────────────────────────────

func _dismiss() -> void:
	if not is_instance_valid(_card):
		tutorial_done.emit()
		queue_free()
		return
	set_process(false)
	var vp := get_viewport().get_visible_rect().size
	var t := _card.create_tween()
	t.tween_property(_card, "position:y", vp.y + 20.0, 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		tutorial_done.emit()
		queue_free()
	)
