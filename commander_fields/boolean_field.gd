extends commander_field

func gather_fields() -> Array[String]:
	return [commander_letter]

func process_line(data: String) -> bool:
	var selfbutton :CheckButton = get_node(".")
	selfbutton.set_pressed_no_signal(int(data))
	return true

func get_command() -> String:
	return "%s%d" % [commander_letter, int(($"." as Button).button_pressed)]

func _on_toggled(_toggled_on: bool) -> void:
	SendValue.emit(get_command())
