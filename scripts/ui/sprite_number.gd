extends Node2D
class_name SpriteNumber

# Pixel crop of the actual digit within each individual PNG
# Matches the NUM_REGIONS from mourk-miner's hud.gd
const REGIONS := [
	Rect2(183, 206, 163, 186),  # 0
	Rect2(454, 207, 124, 185),  # 1
	Rect2(689, 207, 159, 185),  # 2
	Rect2(944, 207, 162, 185),  # 3
	Rect2(1193, 207, 174, 185), # 4
	Rect2(168, 553, 167, 180),  # 5
	Rect2(425, 553, 166, 180),  # 6
	Rect2(684, 553, 147, 180),  # 7
	Rect2(1201, 552, 166, 181), # 8
	Rect2(944, 555, 199, 177),  # 9
]

const BASE_PATH := "res://assets/ui/numbers/"

# Height each digit is rendered at (width scales with aspect ratio)
@export var digit_height: float = 38.0
@export var digit_spacing: float = 2.0
@export var max_digits: int = 5
@export var animate_on_change: bool = true

var _textures: Array = []   # AtlasTexture per digit 0-9
var _rects: Array = []      # TextureRect per digit slot
var _value: int = -1        # -1 forces first refresh

func _ready() -> void:
	_load_textures()
	_build_rects()
	set_value(0)

func set_value(value: int) -> void:
	var new_val := maxi(0, value)
	var changed := new_val != _value
	_value = new_val
	_refresh_display()
	if changed and animate_on_change and is_inside_tree():
		_pop()

func _load_textures() -> void:
	_textures.clear()
	for i in 10:
		var path := BASE_PATH + str(i) + ".png"
		if ResourceLoader.exists(path):
			var src := load(path) as Texture2D
			var at := AtlasTexture.new()
			at.atlas = src
			at.region = REGIONS[i]
			_textures.append(at)
		else:
			_textures.append(null)

func _build_rects() -> void:
	for child in get_children():
		child.queue_free()
	_rects.clear()
	for i in max_digits:
		var r := TextureRect.new()
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(digit_height * 0.65, digit_height)
		r.size = r.custom_minimum_size
		r.position = Vector2(i * (digit_height * 0.65 + digit_spacing), -digit_height * 0.5)
		add_child(r)
		_rects.append(r)

func _refresh_display() -> void:
	var s := str(_value)
	var leading := true
	var start := max_digits - s.length()
	for i in max_digits:
		var rect: TextureRect = _rects[i]
		if i < start:
			# Leading blank — hide it
			rect.visible = false
		else:
			var d := int(s[i - start])
			# Suppress leading zeros (but always show the last digit)
			if leading and d == 0 and i < max_digits - 1:
				rect.visible = false
			else:
				leading = false
				rect.visible = true
				if d < _textures.size() and _textures[d] != null:
					rect.texture = _textures[d]

func _pop() -> void:
	scale = Vector2(1.35, 1.35)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.30) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
