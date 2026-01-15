extends commander_field

class_name motor

@export var monitor_start_character = ""
@export var monitor_end_character = ""
var monitor_split_character = "\t"

@onready var monitored_fields := $"VBoxContainer/TabContainer/Monitoring/monitor variables"
@onready var graphs : Dictionary[String, buffer_graph] = {"Current":$current_graph, "Voltage":$voltage_graph, "Radians":$radians_graph}
@onready var graph_lines : Dictionary[String, buffer_graph] = {"Target": $radians_graph, 
	"Voltage Q":$voltage_graph, "Voltage D":$voltage_graph, 
	"Current Q":$current_graph, "Current D":$current_graph, 
	"Velocity":$radians_graph, "Angle":$radians_graph}
var active_lines : Array[String]

@onready var jog_slider := $VBoxContainer/HBoxContainer/HSlider
@onready var target_input := $VBoxContainer/HBoxContainer/SpinBox
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
	var num_splits : int = data.count(monitor_split_character)
	var has_end_char : bool = monitor_end_character.length() > 0
	if monitor_start_character == commander_letter && ((num_splits > 0 && !has_end_char) || (has_end_char && data.ends_with(monitor_end_character))):
		#this is a monitor data packet
		process_monitor(data.rstrip(monitor_end_character))
		return true
	elif data.is_valid_float():
		drag_value = float(data)
		target_input.set_value_no_signal(float(data))
		return true
	else:
		return super(data)

#data : no start/end character
func process_monitor(data:String):
	var split_data = data.split(monitor_split_character)
	if split_data.size() != active_lines.size():
		return
	for i in range(split_data.size()):
		var value := float(split_data[i])
		var line_name : String = active_lines[i]
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
