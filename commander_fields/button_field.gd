extends commander_field

func gather_fields() -> Array[String]:
	return []

func process_line(_data: String) -> bool:
	return true

#No get command

func _on_pressed() -> void:
	var command := commander_letter
	SendValue.emit(command)
