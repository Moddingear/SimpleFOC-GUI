extends commander_field

func gather_fields() -> Array[String]:
	return [commander_letter]

func process_line(data: String) -> void:
	var selfbutton :CheckButton = get_node(".")
	selfbutton.set_pressed_no_signal(int(data))

func _on_toggled(toggled_on: bool) -> void:
	var command := "%s%d" % [commander_letter, int(toggled_on)]
	SendValue.emit(command)
