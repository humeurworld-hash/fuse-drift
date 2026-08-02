extends Object
class_name UIH

# Shared UI construction helpers so every screen keeps the same look.


static func make_label(text: String, size: int, color: Color = Color(0.92, 0.93, 0.97)) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", TH.FONT_BOLD)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	return lbl


static func make_button(text: String, font_size := 34, accent := Color(0.90, 0.82, 0.40)) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_override("font", TH.FONT_BOLD)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", accent)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))

	var sb := StyleBoxFlat.new()
	sb.bg_color = TH.SURFACE_RAISED
	sb.border_color = TH.HAIRLINE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 34.0
	sb.content_margin_right = 34.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	btn.add_theme_stylebox_override("normal", sb)

	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color(0.11, 0.15, 0.24)
	btn.add_theme_stylebox_override("hover", sb_hover)

	var sb_press := sb.duplicate()
	sb_press.bg_color = Color(0.15, 0.19, 0.30)
	btn.add_theme_stylebox_override("pressed", sb_press)
	return btn


static func make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.14, 0.97)
	sb.border_color = Color(0.90, 0.82, 0.40, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(24)
	sb.content_margin_left = 40.0
	sb.content_margin_right = 40.0
	sb.content_margin_top = 36.0
	sb.content_margin_bottom = 36.0
	panel.add_theme_stylebox_override("panel", sb)
	return panel
