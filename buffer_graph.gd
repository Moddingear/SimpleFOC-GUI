extends Control

class_name buffer_graph
#All graphs share the same time but not the same vertical axis
#Graphs are cyclic
@export var margin : float = 32
@export var loop_size : int = 1000
var point_storage : Dictionary[String, PackedVector2Array]
var validity_start : Dictionary[String, int]
var write_index :int
@export var groups : Dictionary[String, PackedStringArray]

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

func _draw() -> void:
	var drawidx : int = 0
	var rect = get_rect()
	draw_set_transform(Vector2.ZERO)
	var graph_rect = rect
	graph_rect.position = Vector2.ONE * margin
	graph_rect.size -= graph_rect.position*2
	#draw_rect(graph_rect, Color.AQUAMARINE)
	for group_name in groups:
		var maxy : float = -INF
		var miny : float = INF
		var numkeys : int = 0
		for key in groups[group_name]:
			if key in point_storage:
				numkeys += 1
				var storage := point_storage[key]
				for point in storage:
					maxy = maxf(maxy, point.y)
					miny = minf(miny, point.y)
		if numkeys == 0:
			continue
		if maxy == miny:
			drawidx += numkeys
			continue
		var scaley = graph_rect.size.y/(maxy-miny)
		draw_set_transform(graph_rect.position + Vector2(0, -miny*scaley), 0, Vector2(graph_rect.size.x, scaley))
		#draw_rect(Rect2(0,miny,1,maxy-miny), color)
		for key in groups[group_name]:
			if key in point_storage:
				var color = Color.from_hsv(float(drawidx)/point_storage.size(), 1, 1)
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
	var line_offset = Vector2(graph_rect.size.x*write_index/loop_size, 0)
	draw_line(graph_rect.position +line_offset, graph_rect.position+line_offset+Vector2(0, graph_rect.size.y), Color.WHITE)
