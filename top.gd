extends commander_field

var serial_port = GdSerial.new()
@onready var serial_port_entry := $Serial/HBoxContainer/Port
@onready var baud_rate_entry := $Serial/HBoxContainer/BaudRate
@onready var serial_connected_entry := $Serial/HBoxContainer/Connected
@onready var serial_refresh_button := $Serial/HBoxContainer/Refresh
@onready var serial_monitor := $"Serial/Serial output"

func refresh_ports(preselect_port : String, preselect_baud : int) -> void:
	var ports := serial_port.list_ports()
	serial_port_entry.clear()
	var port_select : int = 0
	for port in ports:
		var port_data = ports[port]
		if port_data["port_type"] != "Unknown":
			serial_port_entry.add_item(port_data["port_name"])
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

func _ready() -> void:
	refresh_ports("", 115200)

func _process(delta: float) -> void:
	var serial_connected : bool = serial_port.is_open()
	serial_connected_entry.set_pressed_no_signal(serial_connected)
	serial_refresh_button.disabled = serial_connected
	serial_port_entry.disabled = serial_connected
	baud_rate_entry.disabled = serial_connected
	
	if serial_connected:
		var nbbytes = serial_port.bytes_available()
		if nbbytes > 0:
			var received_raw := serial_port.read(nbbytes)
			var received := received_raw.get_string_from_ascii()
			#print("Received \"%s\"" % received)
			var scan_start :int = serial_monitor.text.length() 
			var concat :String = serial_monitor.text + received
			var last_newline = concat.rfind("\n", scan_start)
			for i in range(scan_start, concat.length()):
				if concat[i] == "\n":
					var line := concat.substr(last_newline, i - last_newline)
					process_line(line.rstrip("\r\n").lstrip("\r\n"))
					last_newline = i
			serial_monitor.text = concat.right(1<<15) #only keep the last text received to avoid slowing down too much
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
		serial_port.set_port(serial_port_entry.get_item_text(serial_port_entry.selected))
		serial_port.set_baud_rate(int(baud_rate_entry.get_item_text(baud_rate_entry.selected)))
		serial_port.clear_buffer()
		if !serial_port.open():
			serial_port.close()
	else:
		serial_port.close()

func OnChildWantsRefresh(fields:Array[String]) -> void:
	if !serial_port.is_open():
		return
	for field in fields:
		serial_port.writeline(field)

func OnChildSendValue(command : String) -> void:
	if !serial_port.is_open():
		return
	print("Sending \"%s\"" % command)
	serial_port.writeline(command)


func _on_refresh_pressed() -> void:
	refresh_ports("" if serial_port_entry.selected == -1 else serial_port_entry.get_item_text(serial_port_entry.selected), 0)
