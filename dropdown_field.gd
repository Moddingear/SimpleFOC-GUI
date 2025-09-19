@tool
extends commander_field

@export var label : String = "":
	set(value):
		label = value
		get_node("RichTextLabel").text = value
		
@export var items : Array[String]:
	set(value):
		items = value
		$OptionButton.clear()
		for item in value:
			$OptionButton.add_item(item)

@export var raw_items : Array[String]

func gather_fields() -> Array[String]:
	return [commander_letter]

func process_line(data: String) -> void:
	for i in range(raw_items.size()):
		var item := raw_items[i]
		if data.to_lower() == item.to_lower():
			$OptionButton.select(i)


func _on_option_button_item_selected(index: int) -> void:
	var command := "%s%d" % [commander_letter, index]
	SendValue.emit(command)
