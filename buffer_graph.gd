extends Control

class_name buffer_graph
#All graphs share the same time but not the same vertical axis
#Graphs are cyclic
@export var margin : float = 32
@export var loop_size : int = 1000
var point_storage : Dictionary[String, PackedVector2Array]
var validity_start : Dictionary[String, int]
var write_index :int

func comparator(a : Vector2, b : Vector2):
	return a.x < b.x

func insert_point(key:String, value:float, _time:float):
	point_storage[key][write_index] = Vector2(float(write_index)/loop_size, value)
	if validity_start[key] == posmod(write_index +1, loop_size):
		validity_start[key] = -1

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
	return Vector2(miny, maxy)

func get_minmax_unit(graph_rect:Rect2, minmax:Vector2)->float:
	var minlog = floorf(log(abs(minmax.x))/log(10))
	var maxlog = floorf(log(abs(minmax.y))/log(10))
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
	var font := ThemeDB.fallback_font
	for key in point_storage:
		var color := get_color(drawidx)
		var used_size = font.get_multiline_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(font, draw_pos, key, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
		draw_pos.x += used_size.x + margin
		drawidx+=1

func _draw() -> void:
	var drawidx : int = 0
	var rect = get_rect()
	var graph_rect = rect
	graph_rect.position = Vector2.ONE * margin
	graph_rect.size -= graph_rect.position*2
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
	
