extends commander_field

class_name motor

@export var monitor_start_character = ""
@export var monitor_end_character = ""
var monitor_split_character = "\t"

@onready var monitored_fields := %monitorVariables
@onready var graphs : Dictionary[String, buffer_graph] = {"Current":%currentGraph, "Voltage":%voltageGraph, "Radians":%radiansGraph}
@onready var graph_lines : Dictionary[String, buffer_graph] = {"Target": %radiansGraph, 
	"Voltage Q":%voltageGraph, "Voltage D":%voltageGraph, 
	"Current Q":%currentGraph, "Current D":%currentGraph, 
	"A current": %currentGraph, "B current": %currentGraph, "C current": %currentGraph,
	"Velocity":%radiansGraph, "Angle":%radiansGraph}
var active_lines : Array[String]
var last_monitor_tick = Time.get_ticks_usec()
var last_monitor_tick_update = Time.get_ticks_usec()

@onready var jog_slider := %jogSlider
@onready var target_input := %targetInput
var job_dragging = false
var drag_value :float = 0

func _ready() -> void:
	print("Available fields: ", gather_fields())
	
func _process(delta: float) -> void:
	if job_dragging:
		var added_value = delta * pow(jog_slider.value, 2) * 10 * signf(jog_slider.value)
		drag_value = drag_value + added_value
		var snapped_value = float("%.3f"%drag_value)
		set_target(snapped_value)
	else:
		jog_slider.set_value_no_signal(0)
		
func set_target(value:float) -> void:
	target_input.set_value_no_signal(value)
	var command = "%s%.3f" % [commander_letter, value]
	SendValue.emit(command)

func _on_refresh_pressed() -> void:
	WantsRefresh.emit(gather_fields())

func gather_fields() -> Array[String]:
	var fields := super()
	fields.push_back(commander_letter) #add target request
	return fields

func process_line(data: String) -> bool:
	#print(monitor_split_character)
	if is_monitor_line(monitor_start_character + data):
		#this is a monitor data packet
		process_monitor(data.rstrip(monitor_end_character))
		return true
	elif data.is_valid_float():
		drag_value = float(data)
		target_input.set_value_no_signal(float(data))
		return true
	else:
		return super(data)
		
func is_monitor_line(data:String) -> bool:
	if monitor_start_character.length() > 0:
		if monitor_start_character != commander_letter && !data.begins_with(monitor_start_character):
			return false
	if monitor_end_character.length() > 0 && !data.ends_with(monitor_end_character):
		return false
	var allowed_chars = "0123456789.e+-"+monitor_split_character
	var data_no_endstart = data.substr(monitor_start_character.length(), data.length() - monitor_end_character.length() - monitor_start_character.length())
	var disallowed_chars = data_no_endstart.remove_chars(allowed_chars)
	if disallowed_chars.length() > 0:
		return false
	var num_splits = data_no_endstart.count(monitor_split_character)
	if num_splits != monitored_fields.get_num_active()-1:
		return false
	return true

#data : no start/end character
func process_monitor(data:String):
	var now = Time.get_ticks_usec()
	var dt = now-last_monitor_tick
	if dt > 0 && %downsample.value >0 && now - last_monitor_tick_update > 1e6:
		%loopSpeed.text = "%fHz" % (%downsample.value / dt * 1e6)
		last_monitor_tick_update = now
	last_monitor_tick = now
	if %pauseButton.button_pressed:
		return
	var split_data = data.split(monitor_split_character)
	if split_data.size() != active_lines.size():
		if active_lines.size() != monitored_fields.get_num_active():
			printerr("Active line mismatch with selected fields!")
		return
	for i in range(split_data.size()):
		var value := float(split_data[i])
		var line_name : String = active_lines[-i-1]
		graph_lines[line_name].insert_point(line_name, value, 0)
	for graph in graphs.values():
		graph.advance()

func _on_spin_box_value_changed(value: float) -> void:
	drag_value = value
	var command = "%s%.3f" % [commander_letter, value]
	SendValue.emit(command)

func _on_monitored_fields_update(active_fields: Array[String]) -> void:
	for graph_name in graphs:
		var graph : buffer_graph = graphs[graph_name]
		var current_keys = graph.get_keys()
		for key in current_keys:
			if key not in active_fields:
				graph.hide_line(key)
		for field in active_fields:
			if field not in current_keys && graph_lines[field] == graph:
				graph.show_line(field)
	active_lines = active_fields


func _on_h_slider_drag_ended(value_changed: bool) -> void:
	job_dragging = false


func _on_h_slider_drag_started() -> void:
	job_dragging = true

func _on_points_box_value_changed(value: float) -> void:
	for key in graphs:
		graphs[key].loop_size = value


func _on_clear_button_pressed() -> void:
	for key in graphs:
		graphs[key].clear()


func _on_rollover_button_toggled(toggled_on: bool) -> void:
	for key in graphs:
		graphs[key].rollover = toggled_on


func _on_save_button_pressed() -> void:
	var state = save_state()
	var joined = "\n".join(state)
	DisplayServer.clipboard_set(joined)
