extends Control

#All graphs share the same time but not the same vertical axis
#Graphs are cyclic

@export var loop_time : float = 10 #seconds
var point_storage : Dictionary[String, Array]
var write_time : Dictionary[String, float]

func comparator(a : Vector2, b : Vector2):
	return a.x < b.x

func insert_point(key:String, value:float, time:float):
	if key not in write_time:
		write_time[key] = 0
	if key not in point_storage:
		point_storage[key] = []
	time = fposmod(time, loop_time)
	var point = Vector2(time, value)
	var last_write_time := write_time[key]
	var storage := point_storage[key]
	var delete_start := storage.bsearch_custom(last_write_time, comparator)
	var delete_end := storage.bsearch_custom(time, comparator)
	#delete everything between time and last_write_time
	if time > last_write_time:
		var delta = delete_end - delete_start
		if delta == 0:
			storage.insert(delete_end, point)
		elif delta == 1:
			storage[delete_start] = point
		else:
			for i in range(delta -1):
				storage.remove_at(delete_start)
			storage[delete_start] = point
	else:
		storage.resize(delete_end+1)
		for i in range(delete_start-1):
			storage.remove_at(0)
		storage[0] = point
	write_time[key] = time

func _draw() -> void:
	for key in point_storage:
		draw_polyline(point_storage[key], Color.WHITE)
