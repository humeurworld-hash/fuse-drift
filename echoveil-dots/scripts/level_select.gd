extends Control

# Level select — "threads". Locked threads stay behind the veil.


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = G.BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	add_child(VeilMotes.new())

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 26)
	add_child(vbox)

	vbox.add_child(UIH.make_label("CHOOSE  A  THREAD", 44, G.GOLD))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 26)
	vbox.add_child(grid)

	for i in G.level_count():
		var locked: bool = i + 1 > G.unlocked
		var btn := UIH.make_button(str(i + 1), 38)
		btn.custom_minimum_size = Vector2(150, 120)
		if locked:
			btn.text = "···"
			btn.disabled = true
			btn.modulate = Color(1, 1, 1, 0.35)
		else:
			var idx := i
			btn.pressed.connect(func() -> void:
				G.current_level = idx
				get_tree().change_scene_to_file("res://scenes/Game.tscn"))
		grid.add_child(btn)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var back := UIH.make_button("BACK", 28, Color(0.6, 0.64, 0.76))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	vbox.add_child(back)
