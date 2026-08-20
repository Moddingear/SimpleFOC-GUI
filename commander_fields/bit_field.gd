@tool
extends commander_field

signal on_update(active_fields: Array[String])
var num_active_cache = -1

@export var items : Array[String]:
	set(value):
		items = value
		for child in get_children():
			remove_child(child)
		for item in value:
			var new_child := CheckButton.new()
			new_child.text = item
			new_child.alignment = HORIZONTAL_ALIGNMENT_RIGHT
			add_child(new_child)
			new_child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			new_child.toggled.connect(_on_field_toggled)
			if item == "":
				new_child.visible = false

func gather_fields() -> Array[String]:
	return [commander_letter]

func update_active():
	var active : Array[String] = []
	for i in range(items.size()):
		var item : CheckButton = get_child(i)
		if item.button_pressed:
			active.push_back(items[i])
	on_update.emit(active)

func process_line(data: String) -> bool:
	var value = data.bin_to_int()
	for i in range(items.size()):
		var item : CheckButton = get_child(i)
		item.set_pressed_no_signal(value & (1<<i))
	update_active()
	num_active_cache = -1
	return true

func get_num_active():
	if num_active_cache != -1:
		return num_active_cache
	var num_active = 0
	for i in range(items.size()):
		var checkbox : CheckButton = get_child(i)
		if checkbox.button_pressed:
			num_active+=1
	num_active_cache = num_active
	return num_active

func get_command() -> String:
	var value = ""
	num_active_cache = 0
	for i in range(items.size()):
		var item : CheckButton = get_child(i)
		if item.button_pressed:
			value = "1" + value
			num_active_cache +=1
		else:
			value = "0" + value
	return "%s%s" % [commander_letter, value]
	

func _on_field_toggled(toggled_on: bool) -> void:
	SendValue.emit(get_command())
