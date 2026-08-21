extends commander_field

var serial_port = GdSerial.new()
@onready var serial_port_entry := %serialPort
@onready var baud_rate_entry := %baudRate
@onready var serial_connected_entry := %serialConnected
@onready var serial_refresh_button := %serialRefresh
@onready var serial_monitor_scroller := %serialOutput
@onready var serial_monitor_container := %serialChildHolder
var rx_line_buffer = ""
var last_rx_line :RichTextLabel = null
@export var num_serial_lines = 128

#path to save new motor 
var new_motor_save_path = "user://new_motor.json"

var motor_scene = preload("res://motor.tscn")
var motor_monitor_keys :Dictionary[String, motor] = {}

#if true, it means the serial was disconnected, and it will try to reconnect as soon as it finds it again
var serial_reconnect = false

var scroll_down_next_frame :bool = false

func refresh_ports(preselect_port : String, preselect_baud : int) -> void:
	var ports := serial_port.list_ports()
	serial_port_entry.clear()
	var port_select : int = 0
	for port in ports:
		var port_data = ports[port]
		if port_data["port_type"] != "Unknown":
			serial_port_entry.add_item("%s: %s" % [port_data["port_name"], port_data["device_name"]])
			if port_data["port_name"] == preselect_port:
				port_select = serial_port_entry.item_count-1
	if serial_port_entry.item_count > 0:
		serial_port_entry.select(port_select)
	var baud_select : int = 0
	var common_baud_rates = [9600, 19200, 28800, 38400, 57600, 76800, 115200, 230400, 460800, 576000, 921600]
	if baud_rate_entry.item_count == 0:
		for baud_rate in common_baud_rates:
			baud_rate_entry.add_item("%d" % baud_rate)
			if baud_rate == preselect_baud:
				baud_select = baud_rate_entry.item_count -1
		baud_rate_entry.select(baud_select)

func get_selected_port_path() -> String:
	var selected_index = serial_port_entry.selected
	if selected_index == -1:
		return ""
	return serial_port_entry.get_item_text(selected_index).split(":")[0]

func _ready() -> void:
	refresh_ports("", 115200)
	if FileAccess.file_exists(new_motor_save_path):
		var file = FileAccess.open(new_motor_save_path, FileAccess.READ)
		var parsed: Dictionary = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			%startChar.text = (parsed.get("startCharacter", %startChar.text.c_unescape()) as String).c_escape()
			%endChar.text = (parsed.get("endCharacter", %endChar.text.c_unescape()) as String).c_escape()
			%separatorChar.text = (parsed.get("splitCharacter", %separatorChar.text.c_unescape()) as String).c_escape()
			%commanderLetter.text = (parsed.get("commanderLetter", %commanderLetter.text.c_unescape()) as String).c_escape()
			%decimalBox.value = (parsed.get("decimals", int(%decimalBox.value)) as int)
	for i in range(num_serial_lines):
		last_rx_line = RichTextLabel.new()
		last_rx_line.fit_content = true
		last_rx_line.scroll_active = false
		last_rx_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		last_rx_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		last_rx_line.text = " "
		serial_monitor_container.add_child(last_rx_line)
	last_rx_line = null
	serial_monitor_scroller.set_deferred("scroll_vertical", ThemeDB.fallback_font.get_height() * num_serial_lines)

func process_monitor(command:String)-> bool:
	var selected_key :String = ""
	for key :String in motor_monitor_keys.keys():
		if selected_key.length() < key.length():
			if command.begins_with(key):
				selected_key = key
	if selected_key in motor_monitor_keys:
		var this_motor = motor_monitor_keys[selected_key]
		if this_motor.is_monitor_line(command):
			this_motor.process_monitor(command.substr(this_motor.monitor_start_character.length(), command.length() - this_motor.monitor_end_character.length() - this_motor.monitor_start_character.length()))
		return true
	return false

func add_serial_line(text):
	last_rx_line = serial_monitor_container.get_child(0)
	serial_monitor_container.move_child(last_rx_line, num_serial_lines)
	last_rx_line.text = text
	last_rx_line.remove_theme_color_override("default_color")

func process_serial():
	var nbbytes = serial_port.bytes_available()
	if nbbytes <= 0:
		return
	var received_raw := serial_port.read(nbbytes)
	var received := received_raw.get_string_from_ascii()
	#print("Received \"%s\"" % received)
	var scan_start :int = rx_line_buffer.length() 
	rx_line_buffer += received
	var last_newline = rx_line_buffer.rfind("\n", scan_start)
	for i in range(scan_start, rx_line_buffer.length()):
		if rx_line_buffer[i] == "\n":
			var line := rx_line_buffer.substr(last_newline, i - last_newline).rstrip("\r\n").lstrip("\r\n")
			last_newline = i
			var is_simplefoc_line = process_line(line)
			var is_monitor_line = process_monitor(line)
			var display_line = true
			if is_simplefoc_line and not %showSimpleFOC.button_pressed:
				display_line = false
			if is_monitor_line and not %showMonitor.button_pressed and not is_simplefoc_line:
				display_line = false
			if not display_line:
				if last_rx_line:
					serial_monitor_container.move_child(last_rx_line, 0)
					last_rx_line.text = " "
					last_rx_line = null
				continue
			if last_rx_line == null:
				add_serial_line(line)
			else:
				last_rx_line.text = line
			if is_simplefoc_line:
				last_rx_line.add_theme_color_override("default_color", Color.DARK_GREEN)
			elif is_monitor_line:
				last_rx_line.add_theme_color_override("default_color", Color.DARK_GOLDENROD)
			else:
				pass
			#this line is taken
			last_rx_line = null
	if last_newline != rx_line_buffer.length() -1:
		add_serial_line(rx_line_buffer.substr(last_newline).rstrip("\r\n").lstrip("\r\n"))

func _process(_delta: float) -> void:
	var serial_connected : bool = serial_port.is_open()
	# serial_connected_entry.set_pressed_no_signal(serial_connected)
	if !serial_connected && serial_reconnect:
		var selected_port = get_selected_port_path()
		var ports := serial_port.list_ports()
		for port in ports:
			var port_data = ports[port]
			if port_data["port_name"] == selected_port:
				serial_port.open()
				serial_port.clear_buffer()
				break
		serial_connected_entry.add_theme_color_override("button_checked_color", Color.RED)
	else:
		serial_connected_entry.remove_theme_color_override("button_checked_color")
		serial_connected_entry.set_pressed_no_signal(serial_connected)
	serial_refresh_button.disabled = serial_connected
	serial_port_entry.disabled = serial_connected
	baud_rate_entry.disabled = serial_connected
	
	if serial_connected:
		process_serial()
	else:
		($"." as TabContainer).current_tab = 0

func _exit_tree() -> void:
	serial_port.close()

func _on_connected_toggled(toggled_on: bool) -> void:
	if toggled_on:
		if serial_port_entry.selected == -1 || baud_rate_entry.selected == -1:
			return
		if serial_port.is_open():
			serial_port.close()
		serial_port.set_port(get_selected_port_path())
		serial_port.set_baud_rate(int(baud_rate_entry.get_item_text(baud_rate_entry.selected)))
		serial_port.clear_buffer()
		if !serial_port.open():
			serial_port.close()
		else:
			# attempt reconnection if serial is lost
			serial_reconnect = true
	else:
		serial_port.close()
		serial_reconnect = false

func OnChildWantsRefresh(fields:Array[String]) -> void:
	if !serial_port.is_open():
		return
	serial_port.writeline("@3")
	for field in fields:
		serial_port.writeline(field)

func OnChildSendValue(command : String) -> void:
	if !serial_port.is_open():
		return
	print("Sending \"%s\"" % command)
	serial_port.writeline(command)


func _on_refresh_pressed() -> void:
	refresh_ports("" if serial_port_entry.selected == -1 else serial_port_entry.get_item_text(serial_port_entry.selected), 0)


func _on_create_pressed() -> void:
	var nmotor : motor= motor_scene.instantiate()
	nmotor.monitor_start_character = %startChar.text.c_unescape()
	nmotor.monitor_end_character = %endChar.text.c_unescape()
	nmotor.monitor_split_character = %separatorChar.text.c_unescape()
	nmotor.commander_letter = %commanderLetter.text.c_unescape()
	var num_decimals = int(%decimalBox.value)
	var creation_dict = {
		"startCharacter": nmotor.monitor_start_character,
		"endCharacter": nmotor.monitor_end_character,
		"splitCharacter": nmotor.monitor_split_character,
		"commanderLetter": nmotor.commander_letter,
		"decimals": num_decimals,
	}
	FileAccess.open(new_motor_save_path, FileAccess.WRITE).store_line(JSON.stringify(creation_dict))
	OnChildSendValue("#%d" % num_decimals)
	nmotor.name = "Motor " + nmotor.commander_letter
	motor_monitor_keys[nmotor.monitor_start_character] = nmotor
	add_child(nmotor)
