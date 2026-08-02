extends Node

# ── Design tokens ─────────────────────────────────────────────────────────────
#
# Single source of truth for type and surface styling, taken from the UI design
# pack (see DESIGN_SPEC.md). Anything visual that isn't gameplay colour lives
# here so a design revision is a one-file edit rather than a hunt through the
# scenes.

const FONT_REGULAR   := preload("res://assets/fonts/Manrope-Regular.ttf")
const FONT_BOLD      := preload("res://assets/fonts/Manrope-Bold.ttf")
const FONT_EXTRABOLD := preload("res://assets/fonts/Manrope-ExtraBold.ttf")

# Surfaces
const SURFACE       := Color("#0D141F")   # cards, chips, trays
const SURFACE_RAISED := Color("#121B2B")  # buttons, icon wells
const HAIRLINE      := Color(1, 1, 1, 0.06)

# Text
const TEXT_PRIMARY   := Color("#EBEDF7")
const TEXT_SECONDARY := Color("#8C94B3")
const TEXT_TERTIARY  := Color("#6B7594")
const TEXT_ON_GOLD   := Color("#080D17")

const WARDEN_BODY := Color("#1A1C26")
const WARDEN_EYE  := Color("#FF4D42")

# Facet pairs for the vector gem treatment: a lit face and a deep face per hue.
const HUE_DEEP := [
	Color("#8a1f38"),   # Ember
	Color("#1d4a8a"),   # Sorrow
	Color("#1f7a38"),   # Verdant
	Color("#8a7218"),   # Radiance
	Color("#5a2b8a"),   # Umbral
]


static func label(text: String, size: int, color: Color, weight := 1) -> Label:
	# weight: 0 regular, 1 bold, 2 extrabold
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", _font(weight))
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


static func _font(weight: int) -> FontFile:
	match weight:
		0: return FONT_REGULAR
		2: return FONT_EXTRABOLD
		_: return FONT_BOLD


static func card_style(radius := 12, fill := SURFACE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = HAIRLINE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	return sb


# Applies Manrope project-wide so anything not styled by hand still picks it up.
static func install(tree: SceneTree) -> void:
	var theme := Theme.new()
	theme.default_font = FONT_BOLD
	theme.default_font_size = 24
	tree.root.theme = theme
