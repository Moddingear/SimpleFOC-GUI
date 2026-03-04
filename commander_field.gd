extends Node

class_name commander_field

signal WantsRefresh(fields:Array[String])
signal SendValue(command:String)

#Letter to be intercepted. If empty, acts as a passthrough
@export var commander_letter : String = ""
@export var silent := false

var field_map : Dictionary[String, commander_field] = {}

#get all the messages that can be routed to here
func gather_fields() -> Array[String]:
	var retval : Array[String] = []
	for key in field_map:
		var child := field_map[key]
		if child.silent:
			continue
		var child_fields = child.gather_fields()
		for field in child_fields:
			retval.push_back(commander_letter + field)
	return retval

func get_commander_parent() -> commander_field:
	var parent = get_parent()
	#get the first commander field parent by going up the hierarchy
	while parent != null && parent is not commander_field:
		parent = parent.get_parent()
	return parent as commander_field

func _enter_tree() -> void:
	var commparent := get_commander_parent()
	if commparent != null:
		commparent.field_map[commander_letter] = self
		WantsRefresh.connect(commparent.OnChildWantsRefresh)
		SendValue.connect(commparent.OnChildSendValue)

func _exit_tree() -> void:
	var commparent := get_commander_parent()
	if commparent != null:
		commparent.field_map.erase(commander_letter)
		WantsRefresh.disconnect(commparent.OnChildWantsRefresh)
		SendValue.disconnect(commparent.OnChildSendValue)

func process_line(data: String) -> bool:
	var best_match := ""
	var motor_match : motor = null
	for key in field_map:
		if data.begins_with(key) && key.length() > best_match.length():
			best_match = key
	if best_match == "":
		#printerr("Missing key for %s at %s" % [data, get_path()])
		return false
	return field_map[best_match].process_line(data.right(-best_match.length()))

func OnChildWantsRefresh(fields:Array[String]) -> void:
	var this_fields : Array[String]
	for field in fields :
		this_fields.push_back(commander_letter + field)
	WantsRefresh.emit(this_fields)

func OnChildSendValue(command : String) -> void:
	SendValue.emit(commander_letter + command)
