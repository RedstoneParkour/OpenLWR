extends Node

func _dprint(what):
	if Engine.get_physics_frames() % 60 == 0:
		print(what)

signal connecting()
signal begin_login()
signal connected()
signal disconnected()

signal chat_message(message: String)
signal new_player(name: StringName)

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

var player: Node3D

var queued_chat_messages: Array[String] = ["test"]

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
	gauge_last_update[id] = data
	if id in gauges:
		get_node(gauges[id]).gauge_update(data)


# keys are stringnames, values are NodePaths that can handle 'alarm events'
var alarms: Dictionary = {}

# holds the last update, per key
var alarm_last_update: Dictionary = {}

func register_alarm(id: StringName, alarm_path: NodePath) -> void:
	alarms[id] = alarm_path
	var last_update = get_alarm_state(id)
	get_node(alarm_path).alarm_update(last_update)

func unregister_alarm(id: StringName) -> bool:
	return alarms.erase(id)

func get_alarm_state(id: StringName) -> Variant:
	return alarm_last_update.get_or_add(id, {})

func _update_alarm(id: StringName, data) -> void:
	get_alarm_state(id).merge(data, true)
	if id in alarms:
		get_node(alarms[id]).alarm_update(data)


# keys are stringnames, values are NodePaths that can handle 'group events'
var groups: Dictionary = {}

# holds the last update, per key
var group_last_update: Dictionary = {}

func register_group(id: StringName, group_path: NodePath) -> void:
	groups[id] = group_path
	var last_update = get_group_state(id)
	get_node(group_path).group_update(last_update)

func unregister_group(id: StringName) -> bool:
	return groups.erase(id)

func get_group_state(id: StringName) -> Variant:
	return group_last_update.get_or_add(id, {})

func _update_group(id: StringName, data) -> void:
	get_group_state(id).merge(data, true)
	if id in groups:
		get_node(groups[id]).group_update(data)

# keys are stringnames, values are NodePaths that can handle 'indicator events'
var indicators: Dictionary = {}

# holds the last update, per key
var indicator_last_update: Dictionary = {}

func register_indicator(id: StringName, indicator_path: NodePath) -> void:
	indicators[id] = indicator_path
	var last_update = get_indicator_state(id)
	get_node(indicator_path).indicator_update(last_update)

func unregister_indicator(id: StringName) -> bool:
	return indicators.erase(id)

func get_indicator_state(id: StringName) -> Variant:
	return indicator_last_update.get_or_add(id, false)

func _update_indicator(id: StringName, data: bool) -> void:
	indicator_last_update[id] = data
	if id in indicators:
		get_node(indicators[id]).indicator_update(data)


# keys are stringnames, values are NodePaths that can handle 'switch events'
var switches: Dictionary = {}

# holds the last update, per key
var switch_last_update: Dictionary = {}

# holds switches updated by the client
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

# keys are stringnames, values are NodePaths that can handle 'button events'
var buttons: Dictionary = {}

# holds the last update, per key
var button_last_update: Dictionary = {}

# holds buttons updated by the client
var _client_updated_buttons: Dictionary = {}

func register_button(id: StringName, button_path: NodePath) -> void:
	buttons[id] = button_path
	var last_update = get_button_state(id)
	get_node(button_path).button_update(last_update)

func unregister_button(id: StringName) -> bool:
	return buttons.erase(id)

func get_button_state(id: StringName) -> Variant:
	return button_last_update.get_or_add(id, {})

func _update_button(id: StringName, data) -> void:
	get_button_state(id).merge(data, true)
	if id in buttons:
		print(id, data)
		get_node(buttons[id]).button_update(data)

func client_update_button(id: StringName, data) -> void:
	_client_updated_buttons[id] = data


var players: Dictionary = {}

var player_last_update: Dictionary = {}

func register_player(name: StringName, player_path: NodePath) -> void:
	players[name] = player_path
	var last_update = get_player_state(name)
	get_node(player_path).player_update(last_update)

func unregister_player(name: StringName) -> bool:
	return players.erase(name)

func get_player_state(name: StringName) -> Variant:
	return player_last_update.get(name)

func _update_player(name: StringName, data) -> void:
	if name in player_last_update and data != null:
		get_player_state(name).merge(data, true)
	else:
		player_last_update[name] = data

	if name in players:
		get_node(players[name]).player_update(data)
	else:
		# new player!
		new_player.emit(name)
	pass


# TODO: insert code for the rest of the network objects here
# NOTE: code for indicators needs to be slightly different

func _build_packet(id: int, data: String):
	# why do we base64 data if data is always JSON?
	return "%d|%s" % [id, Marshalls.utf8_to_base64(data)]

func _send_packet(id: int, data: String):
	var packet = _build_packet(id, data)
	socket.send_text(packet)

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
	print(socket.connect_to_url(url))
	current_state = State.CONNECTING
	connecting.emit()

func net_disconnect(reason: String, code: int = 1000):
	socket.close(code, reason)
	current_state = State.DISCONNECTING

func _process_connecting(delta):
	socket.poll()
	var socket_state = socket.get_ready_state()
	_dprint(socket_state)
	match socket_state:
		WebSocketPeer.STATE_OPEN:
			current_state = State.LOGIN
			begin_login.emit()
		WebSocketPeer.STATE_CLOSED:
			net_disconnect("socket closed while connecting")

func _send_player_info():
	if player:
		var pos = player.position
		var rot = player.rotation
		var info = {
			username: {
				position = {
					x = pos.x,
					y = pos.y,
					z = pos.z,
				},
				rotation = {
					x = rot.x,
					y = rot.y,
					z = rot.z,
				}
			}
		}
		var data = JSON.stringify(info)
		_send_packet(ClientPackets.PLAYER_POSITION_PARAMETERS_UPDATE, data)

func _process_login(delta):
	socket.poll()
	var socket_state = socket.get_ready_state()
	match socket_state:
		WebSocketPeer.STATE_OPEN:
			while socket.get_available_packet_count():
				var packet = socket.get_packet().get_string_from_utf8().split("|")
				var packet_id = int(packet[0])
				var packet_data = Marshalls.base64_to_utf8(packet[1])
				print(packet_id)
				match packet_id:
					ServerPackets.DOWNLOAD_DATA:
						packet_data = packet_data.split("|")
						var info = JSON.parse_string(packet_data[0])
						var info_name = JSON.parse_string(packet_data[1])
						print(info_name)
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
									#_update_rod(name, info[name])
									continue
							"recorders":
								for name in info:
									#_update_recorder(name, info[name])
									continue
					ServerPackets.USER_LOGIN_ACK:
						if downloads_complete.values().has(false):
							net_disconnect("incomplete download")
							return
						if packet_data == "ok":
							current_state = State.CONNECTED
							connected.emit()
						else:
							net_disconnect(packet_data)
			_send_player_info()
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
			for group in updated_groups:
				var info = updated_groups[group]
				_update_group(group, info)
		ServerPackets.BUTTON_PARAMETERS_UPDATE:
			var updated_buttons = JSON.parse_string(data)
			print(updated_buttons)
			for button in updated_buttons:
				if button in _client_updated_buttons:
					print("ignored " + button)
					continue
				var info = updated_buttons[button]
				_update_button(button, info)
		ServerPackets.CHAT:
			chat_message.emit(data)
		ServerPackets.PLAYER_POSITION_PARAMETERS_UPDATE:
			var updated_players = JSON.parse_string(data)
			for player in updated_players:
				var new_info = updated_players[player]
				if player == username:
					continue # its us, ignore this one

				_update_player(player, new_info)

func _process_connected_send():
	_send_player_info()
	if queued_chat_messages.size() > 0:
		for message in queued_chat_messages:
			_send_packet(ClientPackets.CHAT, message)
		queued_chat_messages.clear()
	
	if not _client_updated_buttons.is_empty():
		_send_packet(ClientPackets.BUTTON_PARAMETERS_UPDATE, JSON.stringify(_client_updated_buttons))
		_client_updated_buttons.clear()
	if not _client_updated_switches.is_empty():
		_send_packet(ClientPackets.SWITCH_PARAMETERS_UPDATE, JSON.stringify(_client_updated_switches))
		_client_updated_switches.clear()
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
			disconnected.emit(disconnect_reason, disconnect_code)
			print(disconnect_code, disconnect_reason)

func _on_ready():
	set_process(false)
	pass

func _on_login():
	var login_parameters = {
		username = username,
		version = version,
		}

	var data = JSON.stringify(login_parameters)
	_send_packet(ClientPackets.USER_LOGIN, data)
	
	pass

func _on_connecting():
	set_process(true)
	pass

func _process(delta):
	_dprint("")
	_dprint(current_state)
	match current_state:
		State.CONNECTING:
			_process_connecting(delta)
		State.LOGIN:
			_process_login(delta)
		State.CONNECTED:
			_process_connected(delta)
		State.DISCONNECTING:
			_process_disconnecting(delta)

func _ready():
	connecting.connect(_on_connecting)
	begin_login.connect(_on_login)
	disconnected.connect(_on_ready)
	_on_ready()
	pass

func _init():
	socket.inbound_buffer_size = 1_048_576 # = 2^20
