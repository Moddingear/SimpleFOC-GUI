extends Control

class_name buffer_graph
#All graphs share the same time but not the same vertical axis
#Graphs are cyclic
@export var margin : float = 32
@export var loop_size : int = 1000:
	set = set_loop_size
@export var font := ThemeDB.fallback_font
@export var rollover:bool = true
var point_storage : Dictionary[String, PackedVector2Array]
var validity_start : Dictionary[String, int]
var write_index :int
var max_string_width :float= 0

func comparator(a : Vector2, b : Vector2):
	return a.x < b.x

func set_loop_size(new_length: int):
	if loop_size == new_length:
		return
	for key in point_storage:
		var vector = point_storage[key]
		vector.resize(new_length)
		var scale_x = float(loop_size)/new_length
		for i in min(new_length, loop_size):
			vector[i].x *= scale_x
	for key in validity_start:
		var vs = validity_start[key]
		if vs != -1:
			vs = min(vs, new_length-1)
		elif new_length > loop_size:
			vs = 0
		validity_start[key] = vs
	write_index = min(new_length-1, write_index)
	loop_size = new_length

func clear():
	write_index = 0;
	for key in validity_start:
		validity_start[key] = 0

func insert_point(key:String, value:float, _time:float):
	if validity_start[key] == -1 && !rollover:
		pass
	else:
		point_storage[key][write_index] = Vector2(float(write_index)/loop_size, value)
	if validity_start[key] == posmod(write_index +1, loop_size):
		validity_start[key] = -1
	if !visible:
		visible = true;

func hide_line(key:String):
	point_storage.erase(key)
	validity_start.erase(key)

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func show_line(key:String):
	if key not in point_storage:
		point_storage[key] = PackedVector2Array()
		point_storage[key].resize(loop_size)
		validity_start[key] = write_index
	
func get_keys() -> Array[String]:
	return point_storage.keys()

func advance():
	write_index = posmod(write_index + 1, loop_size)
	queue_redraw()


func get_minmax()->Vector2:
	var maxy : float = -INF
	var miny : float = INF
	for key in point_storage:
		var storage := point_storage[key]
		for point in storage:
			maxy = maxf(maxy, point.y)
			miny = minf(miny, point.y)
	if maxy == miny:
		return Vector2(miny - 0.5, maxy + 0.5)
	return Vector2(miny, maxy)

func get_minmax_unit(graph_rect:Rect2, minmax:Vector2)->float:
	#var minlog = floorf(log(abs(minmax.x))/log(10))
	#var maxlog = floorf(log(abs(minmax.y))/log(10))
	var delta = minmax.y-minmax.x
	var deltalog = floorf(log(abs(delta))/log(10))
	var baselog = deltalog#maxf(minlog, maxlog)
	var maxgraduations = absf(floor(graph_rect.size.y/ThemeDB.fallback_font.get_height()))/2
	var unit = pow(10, baselog-1)
	while delta/unit > maxgraduations:
		if delta/unit/10 > maxgraduations:
			unit *= 10
		else:
			unit *= 2
	return unit

func minmax_unit_snap(minmax:Vector2, unit:float)->Vector2:
	var min_snapped = snappedf(minmax.x, unit)
	if min_snapped > minmax.x: min_snapped-=unit
	var max_snapped = snappedf(minmax.y, unit)
	if max_snapped < minmax.y: max_snapped+=unit
	return Vector2(min_snapped, max_snapped)

func get_color(index : int)->Color:
	return Color.from_hsv(float(index)/point_storage.size(), 1, 1)

func draw_lines(graph_rect:Rect2, miny:float, maxy:float) -> void:
	var scaley = graph_rect.size.y/(maxy-miny)
	var drawidx :int = 0
	var matrix : Transform2D = Transform2D(Vector2(graph_rect.size.x, 0), Vector2(0, -scaley), graph_rect.position + Vector2(0, maxy*scaley))
	draw_set_transform_matrix(matrix)
	#draw_rect(Rect2(0,miny,1,maxy-miny), Color.GREEN)
	for key in point_storage:
		var color = get_color(drawidx)
		var valid_from = validity_start[key]
		if valid_from == -1:
			draw_polyline(point_storage[key], color)
		else:
			if write_index < valid_from:
				#2 segments
				draw_polyline(point_storage[key].slice(valid_from), color)
				draw_polyline(point_storage[key].slice(0, write_index), color)
			else:
				draw_polyline(point_storage[key].slice(valid_from, write_index), color)
		drawidx += 1
	draw_set_transform(Vector2.ZERO)

func draw_vaxis(graph_rect:Rect2, unit:float, minmax:Vector2) ->void:
	var delta = minmax.y - minmax.x
	var num_units : int = roundi(delta/unit)
	var bottom_right : Vector2 = graph_rect.position + Vector2.DOWN*graph_rect.size.y
	if num_units > 1000:
		return
	for i in range(num_units):
		var alpha : float = float(i) / num_units
		var pos :Vector2 = bottom_right + Vector2.UP * graph_rect.size.y * alpha
		var value : float = snappedf(lerpf(minmax.x, minmax.y, alpha), unit)
		var text : String = str(value)
		var width = graph_rect.size.x/400 * (2 if snappedf(value, unit*10) == value else 1)
		draw_line(pos + Vector2.LEFT * width, pos+Vector2.RIGHT * width, Color.WHITE)
		draw_string(ThemeDB.fallback_font, pos + Vector2.RIGHT * width, text, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_line(bottom_right, bottom_right+Vector2.UP*graph_rect.size.y, Color.WHITE)

func draw_legends(graph_rect:Rect2)->void:
	var drawidx:int = 0
	var draw_pos = graph_rect.position
	for key in point_storage:
		var color := get_color(drawidx)
		var used_size = font.get_multiline_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(font, draw_pos, key, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
		draw_pos.x += used_size.x + margin
		drawidx+=1

func get_mouse_local_position(mouse_position = get_viewport().get_mouse_position()) -> Vector2:
	return mouse_position - get_global_rect().position

func get_graph_rect() ->Rect2:
	var rect = get_rect()
	var graph_rect = rect
	graph_rect.position = Vector2.ONE * margin
	graph_rect.size -= graph_rect.position*2
	return graph_rect

func is_mouse_inside()->bool:
	if !visible:
		return false
	return get_graph_rect().abs().has_point(get_mouse_local_position())

func _draw() -> void:
	#var drawidx : int = 0
	var graph_rect = get_graph_rect()
	var minmax = get_minmax()
	var unit = get_minmax_unit(graph_rect, minmax)
	var minmax_snapped = minmax_unit_snap(minmax, unit)
	if point_storage.size() == 0:
		return
	draw_lines(graph_rect, minmax_snapped.x, minmax_snapped.y)
	draw_vaxis(graph_rect, unit, minmax_snapped)
	draw_legends(graph_rect)
	var line_offset = Vector2(graph_rect.size.x*write_index/loop_size, 0)
	draw_line(graph_rect.position +line_offset, graph_rect.position+line_offset+Vector2(0, graph_rect.size.y), Color.WHITE)
	var mouse_pos:= get_mouse_local_position()
	if graph_rect.has_point(mouse_pos):
		var t = (mouse_pos.x-graph_rect.position.x)/graph_rect.size.x
		var i = int(t*loop_size)
		var keys := point_storage.keys()
		var accumulated_text_width = 0
		for index:int in keys.size():
			var key = keys[index]
			var value = point_storage[key][i].y
			var y = remap(value, minmax_snapped.y, minmax_snapped.x, graph_rect.position.y, graph_rect.position.y+graph_rect.size.y)
			var color := get_color(index)
			draw_line(mouse_pos, Vector2(mouse_pos.x, y), color)
			var string := str(value) + "  "
			var string_size := font.get_string_size(string)
			max_string_width = max(string_size.x, max_string_width)
			draw_string(font, graph_rect.position+Vector2(accumulated_text_width, graph_rect.size.y+string_size.y), string, 0, -1, 16, color)
			accumulated_text_width+= max_string_width
	
func _process(_delta: float) -> void:
	if is_mouse_inside():
		queue_redraw() #This is so that when the graph is updated not often, it doesn't feel laggy

func _input(event: InputEvent) -> void:
	if !visible:
		return
	if event is InputEventMouseButton:
		var relative_pos = get_mouse_local_position(event.position)
		if get_graph_rect().has_point(relative_pos) and event.button_index == MOUSE_BUTTON_RIGHT:
			print("Right click: hiding self")
			visible = false
