extends commander_field

func gather_fields() -> Array[String]:
	return []

func process_line(data: String) -> bool:
	return true

func _on_pressed() -> void:
	var command := commander_letter
	SendValue.emit(command)
