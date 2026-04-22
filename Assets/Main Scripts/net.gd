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

var disconnect_reason: String
var disconnect_code: int = 0

var username: String = "cl0"
var version: String = "alpha2025223"

var player: Node3D

var queued_chat_messages: Array[String] = ["test"]

var inbound_packet_queue: Array[Dictionary] = []

# keys are int, values are NodePath
var devices: Dictionary = {}

# keys are int, values vary
var device_last_update: Dictionary = {}

# keys are int, values are boolean
var _client_updated_devices: Dictionary = {}

func register_device(id: int, device_path: NodePath) -> void:
	devices[id] = device_path
	var last_update = get_device_state(id)
	get_node(device_path).net_update(last_update)

func unregister_device(id: int) -> bool:
	return devices.erase(id)

func get_device_state(id: int) -> Variant:
	return device_last_update.get_or(id, null)

func _update_device(id: int, data) -> void:
	device_last_update.insert(id, data)
	if id in devices:
		get_node(devices[id]).net_update(data)

# net_read should be of the form (PackedByteArray) -> [Variant, PackedByteArray]
func _read_device_data(id: int, buf: PackedByteArray) -> Array:
	if id in devices:
		return get_node(devices[id]).net_read(buf)


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

func _parse_arguments() -> Dictionary:
	var arguments = {}
	for argument in OS.get_cmdline_user_args():
		if argument.find("=") > -1:
			var key_value = argument.split("=")
			arguments[key_value[0].lstrip("--")] = key_value[1]
		else:
			# Options without an argument will be present in the dictionary,
			# with the value set to an empty string.
			arguments[argument.lstrip("--")] = ""
	return arguments

var current_state: State = State.READY


var socket: PacketPeer = PacketPeerUdp.new()

func connect_async(host, port := 7001):
	print(socket.connect_to_host(host, port))
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
	var info = {}
	if player:
		var pos = player.position
		var rot = player.rotation
		info = {
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

func _read_packets():
	while socket.get_available_packet_count() > 0:
		var packet = PacketDecoder(socket.get_packet())
		if packet.pop_s32() != 0x1312:
			return net_disconnect("invalid packet header")
		var proto_version = pop_vu32(packet, 2)
		# what's 'version 1.0' represented as???
		var flags = pop_vu32(packet, 4)
		# no clue how to decode this, keep as-is i suppose
		inbound_packet_queue.append({
			version: proto_version,
			flags: flags,
			rest: packet
		})

func _process(delta):
	_dprint("")
	_dprint(current_state)
	_read_packets()
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
	var arguments = _parse_arguments()
	var djoin_ip = "127.0.0.1:7001"
	if arguments.has("username"):
		username = arguments.username
	if arguments.has("join"):
		if not arguments.join.is_empty():
			djoin_ip = arguments.join
		connect_async(djoin_ip)
	pass
