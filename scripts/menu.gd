extends Control

# Title screen — dark veil, drifting Mourk motes, one way forward.


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
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var title := UIH.make_label("ECHOVEIL", 92, G.GOLD)
	vbox.add_child(title)

	var subtitle := UIH.make_label("MOURK  WEAVE", 34, Color(0.75, 0.78, 0.88))
	vbox.add_child(subtitle)

	vbox.add_child(_spacer(30))

	var tagline := UIH.make_label("Emotion is not invisible.\nWeave it. Gather it. Lift the veil.", 24, Color(0.55, 0.58, 0.70))
	vbox.add_child(tagline)

	vbox.add_child(_spacer(40))

	# A row of the five Mourk shards.
	var shard_row := HBoxContainer.new()
	shard_row.alignment = BoxContainer.ALIGNMENT_CENTER
	shard_row.add_theme_constant_override("separation", 14)
	shard_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for tex in G.SHARD_TEXTURES:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(96, 96)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shard_row.add_child(tr)
	vbox.add_child(shard_row)

	vbox.add_child(_spacer(50))

	var play := UIH.make_button("WEAVE", 40)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn"))
	vbox.add_child(play)

	# Gentle title pulse.
	var tw := create_tween().set_loops()
	tw.tween_property(title, "modulate", Color(1, 1, 1, 0.72), 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "modulate", Color(1, 1, 1, 1.0), 1.6).set_trans(Tween.TRANS_SINE)


func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s
