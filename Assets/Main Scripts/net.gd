extends Node

signal connecting()
signal login_download()
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

# keys are stringnames, values are NodePaths that can handle 'gauge events'
var gauges: Dictionary = {}

# holds the last update, per key
var gauge_last_update: Dictionary = {}

func register_gauge(id: StringName, gauge_path: NodePath) -> void:
	gauges[id] = gauge_path
	var last_update = gauge_last_update.get_or_add(id, {})
	get_node(gauge_path).gauge_update(last_update)

func unregister_gauge(id: StringName) -> bool:
	return gauges.remove(id)

func _update_gauge(id: StringName, data) -> bool:
	gauge_last_update.get_or_add(id, {}).merge(data, true)
	if id in gauges:
		get_node(gauges[id]).gauge_update(data)

# TODO: insert code for the rest of the network objects here
# NOTE: code for indicators needs to be slightly different

func _build_packet(id: int, data: str):
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

func disconnect(reason: String, code: int = 1000):
	socket.close(code, reason)
	current_state = State.DISCONNECTING

func _process_connecting(delta):
	socket.poll()
	var socket_state = socket.get_ready_state()
	match socket_state:
		case WebSocketPeer.STATE_OPEN:
			current_state = State.DOWNLOADING
			begin_download.emit()
		case WebSocketPeer.STATE_CLOSED:
			disconnect("socket closed while connecting")

func _process_login(delta):
	socket.poll()
	var socket_state = socket.get_ready_state()
	match socket_state:
		case WebSocketPeer.STATE_OPEN:
			while socket.get_available_packet_count():
				var packet = socket.get_packet().get_string_from_utf8().split("|")
				var packet_id = int(packet[0])
				var packet_data = Marshalls.base64_to_utf8(packet[1])

				match packet_id:
					case ServerPackets.DOWNLOAD_DATA:
						packet_data = packet_data.split("|")
						var info = json.parse_string(packet_data[0])
						var info_name = json.parse_string(packet_data[1])

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
					case ServerPackets.USER_LOGIN_ACK:
						if downloads_complete.values().has(false):
							disconnect("incomplete download")
							return
						if packet_data == "ok":
							current_state = State.CONNECTED
							connected.emit()
						else:
							disconnect(packet_data)
		case WebSocketPeer.STATE_CLOSED:
			disconnect("socket closed during login")

func _process_disconnecting():
	match socket.get_ready_state():
		case WebSocketPeer.STATE_CLOSING:
			socket.poll()
		case WebSocketPeer.STATE_CLOSED:
			disconnect_reason = get_close_reason()
			disconnect_code = get_close_code()

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
		case State.CONNECTING:
			_process_connecting(delta)
		case State.LOGIN:
			_process_login(delta)
		case State.DISCONNECTING:
			_process_disconnecting(delta)
