extends Node2D
## Opening battlefield for Trench Shock.
##
## Column edges match the browser board (game version 0.10.0).
## Click a zone, a trench slot, or a soldier to highlight it and show its name.
## Dice, missions, Headquarters, and combat stay in the browser game.

const BOARD_W := 1024.0
const BOARD_H := 519.0
## Painted column edges, left to right, in board pixels.
const EDGES := [0.0, 174.0, 250.0, 330.0, 407.0, 614.0, 690.0, 771.0, 847.0, 1024.0]
## Trench wall bands: top, middle, bottom. Each vector is (y, height) as a fraction of the board.
const BANDS := [Vector2(0.0308, 0.2813), Vector2(0.3584, 0.2832), Vector2(0.6859, 0.2833)]
## Icon column inside each trench, as (x, width) fractions of that trench.
const DE_WALL := Vector2(0.0632, 0.6264)
const UK_WALL := Vector2(0.3051, 0.6215)
const REINFORCEMENTS := 12
const FIELD_TOKEN_W := 60.0
const FIELD_GAP := 6.0
const TRENCH_TOKEN_W := 46.0
const TRENCH_GAP := 8.0

const TEXTURE_DE: Texture2D = preload("res://art/soldier-german.png")
const TEXTURE_UK: Texture2D = preload("res://art/soldier-british.png")

const PAPER := Color(0.965, 0.937, 0.878, 0.96)
const INK := Color(0.102, 0.071, 0.047, 1)
const ZONE_WASH := Color(0.86, 0.64, 0.24, 0.24)
const SLOT_WASH := Color(0.86, 0.64, 0.24, 0.2)
const SOLDIER_WASH := Color(0.98, 0.95, 0.88, 0.35)

const ZONES := [
	{"id": "GermanTrench", "name": "German Trench", "side": "de", "kind": "trench", "soldiers": 3},
	{"id": "GermanZone1", "name": "German Zone 1", "side": "de", "kind": "field", "soldiers": 5},
	{"id": "GermanZone2", "name": "German Zone 2", "side": "de", "kind": "field", "soldiers": 5},
	{"id": "GermanZone3", "name": "German Zone 3", "side": "de", "kind": "field", "soldiers": 0},
	{"id": "Objective", "name": "Objective", "side": "", "kind": "field", "soldiers": 0},
	{"id": "BritishZone3", "name": "British Zone 3", "side": "uk", "kind": "field", "soldiers": 0},
	{"id": "BritishZone2", "name": "British Zone 2", "side": "uk", "kind": "field", "soldiers": 5},
	{"id": "BritishZone1", "name": "British Zone 1", "side": "uk", "kind": "field", "soldiers": 5},
	{"id": "BritishTrench", "name": "British Trench", "side": "uk", "kind": "trench", "soldiers": 3},
]

var _soldiers: Array = []
var _slots: Array = []
var _zones: Array = []
var _under: Frame
var _over: Frame
var _plaque: Panel
var _name_label: Label
var _picked: Sprite2D
var _counts := {"de": 0, "uk": 0}


func _ready() -> void:
	DisplayServer.window_set_title("Trench Shock")
	RenderingServer.set_default_clear_color(Color(0.07, 0.045, 0.03))
	var board := $Board as Sprite2D
	board.centered = false
	board.position = Vector2.ZERO
	board.z_index = 0

	_under = Frame.new()
	_under.name = "ZoneHighlight"
	_under.draw_border = false
	_under.z_index = 1
	add_child(_under)

	var pieces := Node2D.new()
	pieces.name = "Pieces"
	pieces.z_index = 2
	add_child(pieces)

	var markers := Node2D.new()
	markers.name = "Markers"
	markers.z_index = 3
	add_child(markers)

	_over = Frame.new()
	_over.name = "SelectionOutline"
	_over.draw_fill = false
	_over.z_index = 4
	add_child(_over)

	_build(pieces, markers)
	_build_plaque()


func _build(pieces: Node2D, markers: Node2D) -> void:
	for index in ZONES.size():
		var zone: Dictionary = ZONES[index]
		var column := _column_rect(index)
		var holder := Node2D.new()
		holder.name = str(zone["id"])
		pieces.add_child(holder)
		var side := str(zone["side"])
		var count := int(zone["soldiers"])
		if str(zone["kind"]) == "trench":
			_add_trench_markers(markers, column, side)
			if count > 0:
				_place_soldiers(holder, _floor_rect(column, side), side, count, TRENCH_TOKEN_W, TRENCH_GAP)
		elif count > 0:
			var field := Rect2(column.position.x + 4.0, 8.0, column.size.x - 8.0, BOARD_H - 16.0)
			_place_soldiers(holder, field, side, count, FIELD_TOKEN_W, FIELD_GAP)
		_zones.append({"name": str(zone["name"]), "rect": column, "wash": ZONE_WASH})


func _add_trench_markers(markers: Node2D, column: Rect2, side: String) -> void:
	var side_name := "German" if side == "de" else "British"
	# Germany's wall, top to bottom: Locked Dice, Casualties, Reinforcements.
	# Britain's wall, top to bottom: Reinforcements, Casualties, Locked Dice.
	if side == "de":
		_add_slot(markers, _band_rect(column, side, 1), side_name + " Casualties", "Casualties", false)
		_add_slot(markers, _band_rect(column, side, 2), side_name + " Reinforcements", str(REINFORCEMENTS), true)
	else:
		_add_slot(markers, _band_rect(column, side, 0), side_name + " Reinforcements", str(REINFORCEMENTS), true)
		_add_slot(markers, _band_rect(column, side, 1), side_name + " Casualties", "Casualties", false)


func _add_slot(markers: Node2D, slot: Rect2, area_name: String, badge_text: String, is_count: bool) -> void:
	var badge_size := Vector2(72, 48) if is_count else Vector2(minf(108.0, slot.size.x - 8.0), 26)
	var font_size := 32 if is_count else 14
	var badge := Rect2()
	badge.size = badge_size
	badge.position.x = slot.position.x + (slot.size.x - badge_size.x) * 0.5
	if is_count:
		badge.position.y = slot.position.y + (slot.size.y - badge_size.y) * 0.5
	else:
		badge.position.y = slot.position.y + 6.0
	var panel := _make_badge(badge, badge_text, font_size)
	panel.name = area_name.replace(" ", "")
	markers.add_child(panel)
	panel.position = badge.position
	panel.size = badge.size
	var label := panel.get_node("Text") as Label
	label.position = Vector2.ZERO
	label.size = badge.size
	_slots.append({"name": area_name, "rect": slot, "wash": SLOT_WASH})


func _place_soldiers(parent: Node2D, area: Rect2, side: String, count: int, token_w: float, gap: float) -> void:
	var texture := TEXTURE_DE if side == "de" else TEXTURE_UK
	var side_name := "German" if side == "de" else "British"
	var rects := _stack_rects(area, count, texture, token_w, gap)
	for rect in rects:
		_counts[side] = int(_counts[side]) + 1
		var sprite := Sprite2D.new()
		sprite.name = "%sSoldier%d" % [side_name, int(_counts[side])]
		sprite.texture = texture
		sprite.centered = true
		sprite.position = rect.get_center()
		var tex_size := texture.get_size()
		sprite.scale = Vector2(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
		parent.add_child(sprite)
		_soldiers.append({
			"name": side_name + " soldier",
			"rect": rect,
			"wash": SOLDIER_WASH,
			"sprite": sprite,
		})


func _stack_rects(area: Rect2, count: int, texture: Texture2D, token_w: float, gap: float) -> Array:
	var aspect := texture.get_height() / texture.get_width()
	token_w = minf(token_w, area.size.x)
	var token_h := token_w * aspect
	var total := count * token_h + (count - 1) * gap
	if total > area.size.y and count > 0:
		token_h = (area.size.y - (count - 1) * gap) / float(count)
		token_w = minf(token_h / aspect, area.size.x)
		token_h = token_w * aspect
		total = count * token_h + (count - 1) * gap
	var left := area.position.x + (area.size.x - token_w) * 0.5
	var top := area.position.y + (area.size.y - total) * 0.5
	var rects: Array = []
	for i in count:
		rects.append(Rect2(left, top + i * (token_h + gap), token_w, token_h))
	return rects


func _column_rect(index: int) -> Rect2:
	var left := float(EDGES[index])
	var right := float(EDGES[index + 1])
	return Rect2(left, 0.0, right - left, BOARD_H)


func _floor_rect(column: Rect2, side: String) -> Rect2:
	# Soldiers stand on the trench floor, beside the painted wall slots.
	var width := column.size.x * 0.30
	var rect := Rect2(column.position.x, 10.0, width, BOARD_H - 20.0)
	if side == "de":
		rect.position.x = column.position.x + column.size.x - width
	rect.position.x += 2.0
	rect.size.x -= 4.0
	return rect


func _band_rect(column: Rect2, side: String, band: int) -> Rect2:
	var wall := DE_WALL if side == "de" else UK_WALL
	var span := BANDS[band]
	return Rect2(
		column.position.x + column.size.x * wall.x,
		BOARD_H * span.x,
		column.size.x * wall.y,
		BOARD_H * span.y
	)


func _make_badge(rect: Rect2, text: String, font_size: int) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = rect.position
	panel.size = rect.size
	var style := _paper_style(INK, 2)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.name = "Text"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2.ZERO
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	panel.add_child(label)
	return panel


func _build_plaque() -> void:
	_plaque = Panel.new()
	_plaque.name = "NamePlate"
	_plaque.visible = false
	_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque.z_index = 6
	_plaque.add_theme_stylebox_override("panel", _paper_style(Color(0.72, 0.55, 0.28), 2))
	_name_label = Label.new()
	_name_label.name = "Name"
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", INK)
	_plaque.add_child(_name_label)
	add_child(_plaque)


func _paper_style(border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	return style


func _show_name(area_name: String) -> void:
	_name_label.text = area_name
	var measured := _name_label.get_minimum_size().x + 32.0
	var estimated := area_name.length() * 11.0 + 36.0
	var width := clampf(maxf(measured, estimated), 160.0, 560.0)
	_plaque.size = Vector2(width, 38.0)
	_plaque.position = Vector2((BOARD_W - width) * 0.5, 10.0)
	_name_label.position = Vector2.ZERO
	_name_label.size = _plaque.size
	_plaque.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	if button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	_pick(get_global_mouse_position())


func _pick(point: Vector2) -> void:
	var found := _hit(_soldiers, point)
	if found.is_empty():
		found = _hit(_slots, point)
	if found.is_empty():
		found = _hit(_zones, point)
	if found.is_empty():
		return
	var rect: Rect2 = found["rect"]
	var wash: Color = found["wash"]
	_select(str(found["name"]), rect, wash, found.get("sprite", null))
	get_viewport().set_input_as_handled()


func _hit(entries: Array, point: Vector2) -> Dictionary:
	for entry in entries:
		var item := entry as Dictionary
		var rect: Rect2 = item["rect"]
		if rect.has_point(point):
			return item
	return {}


func _select(area_name: String, rect: Rect2, wash: Color, sprite: Variant) -> void:
	if _picked:
		_picked.modulate = Color.WHITE
		_picked = null
	if sprite is Sprite2D:
		_picked = sprite as Sprite2D
		_picked.modulate = Color(1.12, 1.08, 1.02)
	_show_name(area_name)
	_under.area = rect
	_under.fill = wash
	_under.queue_redraw()
	_over.area = rect
	_over.queue_redraw()


class Frame extends Node2D:
	var area := Rect2()
	var fill := Color(0, 0, 0, 0)
	var draw_fill := true
	var draw_border := true

	func _draw() -> void:
		if area.size.x <= 0.0 or area.size.y <= 0.0:
			return
		if draw_fill and fill.a > 0.0:
			draw_rect(area, fill, true)
		if draw_border:
			draw_rect(area, Color(0.95, 0.82, 0.45), false, 3.0)
