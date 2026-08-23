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
var write_index :int = 0
var max_string_width :float= 0
var vertical_axis := graphAxis.new()

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
		var valid_range: Array
		var vstart = validity_start[key]
		if vstart == -1:
			valid_range = range(loop_size)
		elif write_index > vstart:
			valid_range = range(vstart, write_index)
		else:
			valid_range = range(vstart, loop_size) + range(0, write_index)
		for i in valid_range:
			var point = storage[i]
			maxy = maxf(maxy, point.y)
			miny = minf(miny, point.y)
	if maxy == miny:
		return Vector2(miny - 0.5, maxy + 0.5)
	return Vector2(miny, maxy)

func get_color(index : int)->Color:
	return Color.from_hsv(float(index)/point_storage.size(), 1, 1)

func draw_polyline_safe(points:PackedVector2Array, color: Color):
	if points.size() >= 2:
		draw_polyline(points, color)

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
				draw_polyline_safe(point_storage[key].slice(valid_from), color)
				draw_polyline_safe(point_storage[key].slice(0, write_index), color)
			else:
				draw_polyline_safe(point_storage[key].slice(valid_from, write_index), color)
		drawidx += 1
	draw_set_transform(Vector2.ZERO)

func draw_vaxis(graph_rect:Rect2, unit:float, minmax:Vector2) ->void:
	var bottom_right : Vector2 = graph_rect.position + Vector2.DOWN*graph_rect.size.y
	vertical_axis.draw_axis(bottom_right, graph_rect.position, unit, graph_rect.size.x/400, minmax, self)

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

func is_valid_index(index:int, validity_start:int)-> bool:
	if validity_start == -1:
		return true
	if validity_start < write_index:
		return validity_start <= index and index < write_index
	else:
		return index < write_index or validity_start <= index

func draw_line_to_mouse(graph_rect:Rect2, minmax_snapped:Vector2):
	var mouse_pos:= get_mouse_local_position()
	var line_positions = []
	if not graph_rect.has_point(mouse_pos):
		return
	var t = (mouse_pos.x-graph_rect.position.x)/graph_rect.size.x
	var i = int(t*loop_size)
	var keys := point_storage.keys()
	var accumulated_text_width = 0
	for index:int in keys.size():
		var key = keys[index]
		var vstart = validity_start[key]
		if not is_valid_index(i, vstart):
			continue
		var value = point_storage[key][i].y
		var y = remap(value, minmax_snapped.y, minmax_snapped.x, graph_rect.position.y, graph_rect.position.y+graph_rect.size.y)
		var color := get_color(index)
		line_positions.push_back([y, value, color])
	line_positions.sort_custom(func(a,b): return absf(a[0]-mouse_pos.y) > absf(b[0]-mouse_pos.y))
	for position in line_positions:
		draw_line(mouse_pos, Vector2(mouse_pos.x, position[0]), position[2])
		var string := str(position[1]) + "  "
		var string_size := font.get_string_size(string)
		max_string_width = max(string_size.x, max_string_width)
		draw_string(font, graph_rect.position+Vector2(accumulated_text_width, graph_rect.size.y+string_size.y), string, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, position[2])
		accumulated_text_width+= max_string_width

func _draw() -> void:
	#var drawidx : int = 0
	var graph_rect = get_graph_rect()
	var minmax = get_minmax()
	var unit = vertical_axis.get_minmax_unit(graph_rect, minmax)
	var minmax_snapped = vertical_axis.minmax_unit_snap(minmax, unit)
	if point_storage.size() == 0:
		return
	draw_lines(graph_rect, minmax_snapped.x, minmax_snapped.y)
	draw_vaxis(graph_rect, unit, minmax_snapped)
	draw_legends(graph_rect)
	var line_offset = Vector2(graph_rect.size.x*write_index/loop_size, 0)
	draw_line(graph_rect.position +line_offset, graph_rect.position+line_offset+Vector2(0, graph_rect.size.y), Color.WHITE)
	draw_line_to_mouse(graph_rect, minmax_snapped)
	
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
