@tool
extends commander_field

@export var label:String = "":
	set(value):
		label = value
		get_node("RichTextLabel").text = value

func gather_fields() -> Array[String]:
	return [commander_letter]

func process_line(data: String) -> bool:
	$SpinBox.set_value_no_signal(float(data))
	return true

func _on_spin_box_value_changed(value: float) -> void:
	var command := "%s%f" % [commander_letter, value]
	SendValue.emit(command)
