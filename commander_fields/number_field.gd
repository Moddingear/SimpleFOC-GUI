@tool
extends commander_field

@onready var watch_box := $Watch
var last_watch_ms = 0

@export var label:String = "":
	set(value):
		label = value
		get_node("RichTextLabel").text = value

@export var value:float:
	get:
		return %spinBox.value

func set_silent(new_value:bool):
	silent = new_value
	if watch_box:
		watch_box.visible = !new_value

func gather_fields() -> Array[String]:
	return [commander_letter]

func process_line(data: String) -> bool:
	var new_value := float(data)
	if new_value == -12345:
		%spinBox.set_value_no_signal(NAN)
	else:
		%spinBox.set_value_no_signal(new_value)
	return true

func get_command() -> String:
	if value == NAN:
		return ""
	return "%s%f" % [commander_letter, value]

func _ready() -> void:
	watch_box.visible = !silent
	super()

func _on_spin_box_value_changed(_new_value: float) -> void:
	SendValue.emit(get_command())

func _process(_delta: float) -> void:
	if watch_box.button_pressed:
		var this_loop_ms = Time.get_ticks_msec()
		if this_loop_ms - last_watch_ms >= 1000:
			last_watch_ms = this_loop_ms
			SendValue.emit(commander_letter)
