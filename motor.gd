extends commander_field

class_name motor

@export var monitor_start_character = ""
@export var monitor_end_character = ""
var monitor_split_character = "\t"

@onready var monitored_fields := $"TabContainer/Monitoring/monitor variables"
@onready var graph : buffer_graph = $buffer_graph
var graph_lines : Array[String]

func _ready() -> void:
	print("Available fields: ", gather_fields())

func _on_refresh_pressed() -> void:
	WantsRefresh.emit(gather_fields())

func gather_fields() -> Array[String]:
	var fields := super()
	fields.push_back(commander_letter) #add target request
	return fields

func process_line(data: String) -> void:
	#print(monitor_split_character)
	var num_splits := data.count(monitor_split_character)
	if num_splits > 0 && data.ends_with(monitor_end_character) && monitor_start_character == commander_letter:
		#this is a monitor data packet
		process_monitor(data.rstrip(monitor_end_character))
	elif data.is_valid_float():
		$HBoxContainer/SpinBox.set_value_no_signal(float(data))
	else:
		super(data)

#data : no start/end character
func process_monitor(data:String):
	var split_data = data.split(monitor_split_character)
	if split_data.size() != graph_lines.size():
		return
	for i in range(split_data.size()):
		var value = float(split_data[i])
		graph.insert_point(graph_lines[i], value, 0)
	graph.advance()

func _on_spin_box_value_changed(value: float) -> void:
	var command = "%s%f" % [commander_letter, value]
	SendValue.emit(command)

func _on_monitored_fields_update(active_fields: Array[String]) -> void:
	var removed_keys = []
	var current_keys = graph.get_keys()
	for key in current_keys:
		if key not in active_fields:
			graph.hide_line(key)
			removed_keys.push_back(key)
	for field in active_fields:
		if field not in current_keys:
			graph.show_line(field)
	graph_lines = active_fields
