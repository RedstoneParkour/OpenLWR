extends Node

signal connecting()
signal begin_login()
signal connected()
signal disconnected()

enum State {
	READY,
	CONNECTING,
	LOGIN,
	CONNECTED,
	DISCONNECTING,
}

enum ClientPackets {
	SWITCH_PARAMETERS_UPDATE = 2,
	BUTTON_PARAMETERS_UPDATE = 6,
	PLAYER_POSITION_PARAMETERS_UPDATE = 9,
	ROD_SELECT_UPDATE = 11,
	USER_LOGIN = 12,
	SYNCHRONIZE = 14,
	CHAT = 15,
	RCON = 19,
	RECORDER = 21,
}

enum ServerPackets {
	METER_PARAMETERS_UPDATE = 0,
	USER_LOGOUT = 1,
	SWITCH_PARAMETERS_UPDATE = 3,
	INDICATOR_PARAMETERS_UPDATE = 4,
	ALARM_PARAMETERS_UPDATE = 5,
	BUTTON_PARAMETERS_UPDATE = 7,
	PLAYER_POSITION_PARAMETERS_UPDATE = 8,
	ROD_POSITION_PARAMETERS_UPDATE = 10,
	USER_LOGIN_ACK = 13,
	CHAT = 16,
	DOWNLOAD_DATA = 17,
	KICK = 18,
	RECORDER = 20,
}

var disconnect_reason: String
var disconnect_code: int = 0

var username: String = "cl0"
var version: String = "alpha2025223"

# keys are stringnames, values are NodePaths that can handle 'gauge events'
var gauges: Dictionary = {}

# holds the last update, per key
var gauge_last_update: Dictionary = {}

func register_gauge(id: StringName, gauge_path: NodePath) -> void:
	gauges[id] = gauge_path
	var last_update = get_gauge_state(id)
	get_node(gauge_path).gauge_update(last_update)

func unregister_gauge(id: StringName) -> bool:
	return gauges.erase(id)

func get_gauge_state(id: StringName) -> Variant:
	return gauge_last_update.get_or_add(id, {})

func _update_gauge(id: StringName, data) -> void:
	get_gauge_state(id).merge(data, true)
	if id in gauges:
		get_node(gauges[id]).gauge_update(data)

# keys are stringnames, values are NodePaths that can handle 'switch events'
var switches: Dictionary = {}

# holds the last update, per key
var switch_last_update: Dictionary = {}

var _client_updated_switches: Dictionary = {}

func register_switch(id: StringName, switch_path: NodePath) -> void:
	switches[id] = switch_path
	var last_update = get_switch_state(id)
	get_node(switch_path).switch_update(last_update)

func unregister_switch(id: StringName) -> bool:
	return switches.erase(id)

func get_switch_state(id: StringName) -> Variant:
	return switch_last_update.get_or_add(id, {})

func _update_switch(id: StringName, data) -> void:
	get_switch_state(id).merge(data, true)
	if id in switches:
		get_node(switches[id]).switch_update(data)

func client_update_switch(id: StringName, data) -> void:
	_client_updated_switches[id] = data

# TODO: insert code for the rest of the network objects here
# NOTE: code for indicators needs to be slightly different

func _build_packet(id: int, data: String):
	# why do we base64 data if data is always JSON?
	return "%d|%s" % [id, Marshalls.utf8_to_base64(data)]

var current_state: State = State.READY

var downloads_complete: Dictionary = {
	switches = false,
	buttons = false,
	alarms = false,
	rods = false,
	recorders = false,
	}

var socket: WebSocketPeer = WebSocketPeer.new()

func connect_async(url):
	socket.connect_to_url(url)
	current_state = State.CONNECTING
	connecting.emit()

func net_disconnect(reason: String, code: int = 1000):
	socket.close(code, reason)
	current_state = State.DISCONNECTING

func _process_connecting(delta):
	socket.poll()
	var socket_state = socket.get_ready_state()
	match socket_state:
		WebSocketPeer.STATE_OPEN:
			current_state = State.LOGIN
			begin_login.emit()
		WebSocketPeer.STATE_CLOSED:
			net_disconnect("socket closed while connecting")

func _process_login(delta):
	socket.poll()
	var socket_state = socket.get_ready_state()
	match socket_state:
		WebSocketPeer.STATE_OPEN:
			while socket.get_available_packet_count():
				var packet = socket.get_packet().get_string_from_utf8().split("|")
				var packet_id = int(packet[0])
				var packet_data = Marshalls.base64_to_utf8(packet[1])

				match packet_id:
					ServerPackets.DOWNLOAD_DATA:
						packet_data = packet_data.split("|")
						var info = JSON.parse_string(packet_data[0])
						var info_name = JSON.parse_string(packet_data[1])

						downloads_complete[info_name] = true

						match info_name:
							"switches":
								for name in info:
									_update_switch(name, info[name])
							"buttons":
								for name in info:
									_update_button(name, info[name])
							"alarms":
								for name in info:
									_update_alarm(name, info[name])
							"rods":
								for name in info:
									_update_rod(name, info[name])
							"recorders":
								for name in info:
									_update_recorder(name, info[name])
					ServerPackets.USER_LOGIN_ACK:
						if downloads_complete.values().has(false):
							net_disconnect("incomplete download")
							return
						if packet_data == "ok":
							current_state = State.CONNECTED
							connected.emit()
						else:
							net_disconnect(packet_data)
		WebSocketPeer.STATE_CLOSED:
			net_disconnect("socket closed during login")

func _process_connected_receive(id: int, data: String):
	match id:
		ServerPackets.METER_PARAMETERS_UPDATE:
			var updated_gauges = JSON.parse_string(data)
			for gauge in updated_gauges:
				var info = updated_gauges[gauge]
				_update_gauge(gauge, info)
		ServerPackets.SWITCH_PARAMETERS_UPDATE:
			var server_updated_switches = JSON.parse_string(data)
			for switch_name in server_updated_switches:
				if switch_name in _client_updated_switches:
					continue
				var info = server_updated_switches[switch_name]
				_update_switch(switch_name, info)
		ServerPackets.INDICATOR_PARAMETERS_UPDATE:
			var updated_indicators = JSON.parse_string(data)
			for indicator in updated_indicators:
				var info = updated_indicators[indicator]
				_update_indicator(indicator, info)
		ServerPackets.ALARM_PARAMETERS_UPDATE:
			var alarm_data = data.split("|")
			var updated_alarms = JSON.parse_string(alarm_data[0])
			var updated_groups = JSON.parse_string(alarm_data[1])
			for alarm in updated_alarms:
				var info = updated_alarms[alarm]
				_update_alarm(alarm, info)
		ServerPackets.BUTTON_PARAMETERS_UPDATE:
			var updated_buttons = JSON.parse_string(data)
			for button in updated_buttons:
				if button in _client_updated_buttons:
					continue
				var info = updated_buttons[button]
				_update_button(button, info)

func _process_connected_send():
	pass

func _process_connected(delta):
	socket.poll()
	var socket_state = socket.get_ready_state()
	match socket_state:
		WebSocketPeer.STATE_OPEN:
			while socket.get_available_packet_count():
				var packet = socket.get_packet().get_string_from_utf8().split("|")
				var packet_id = int(packet[0])
				var packet_data = Marshalls.base64_to_utf8(packet[1])
				_process_connected_receive(packet_id, packet_data)
			_process_connected_send()

func _process_disconnecting(delta):
	match socket.get_ready_state():
		WebSocketPeer.STATE_CLOSING:
			socket.poll()
		WebSocketPeer.STATE_CLOSED:
			disconnect_reason = socket.get_close_reason()
			disconnect_code = socket.get_close_code()

func _on_ready():
	set_process(false)
	pass

func _on_login():
	var login_parameters = {
		username = username,
		version = version,
		}

	var data = JSON.stringify(login_parameters)
	var packet = _build_packet(ClientPackets.USER_LOGIN, data)
	socket.send_text(packet)
	pass

func _on_connecting():
	set_process(true)
	pass

func _process(delta):
	match current_state:
		State.CONNECTING:
			_process_connecting(delta)
		State.LOGIN:
			_process_login(delta)
		State.DISCONNECTING:
			_process_disconnecting(delta)
