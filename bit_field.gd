@tool
extends commander_field

signal on_update(active_fields: Array[String])

@export var items : Array[String]:
	set(value):
		items = value
		for child in get_children():
			remove_child(child)
		for item in value:
			var new_child := CheckButton.new()
			new_child.text = item
			add_child(new_child)
			new_child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			new_child.toggled.connect(_on_field_toggled)

func gather_fields() -> Array[String]:
	return [commander_letter]

func update_active():
	var active : Array[String] = []
	for i in range(items.size()):
		var item : CheckButton = get_child(i)
		if item.button_pressed:
			active.push_back(items[i])
	on_update.emit(active)

func process_line(data: String) -> void:
	for i in range(items.size()):
		var item : CheckButton = get_child(i)
		item.set_pressed_no_signal(data[i] == "1")
	update_active()

func _on_field_toggled(toggled_on: bool) -> void:
	var value = ""
	for i in range(items.size()):
		var item : CheckButton = get_child(i)
		value += "1" if item.button_pressed else "0"
	var command := "%s%s" % [commander_letter, value]
	SendValue.emit(command)
	
