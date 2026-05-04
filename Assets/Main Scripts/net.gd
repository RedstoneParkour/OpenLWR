extends Node

const REC = preload("res://Assets/Generated/Protocols/rec.gd")

func _dprint(what):
	if Engine.get_process_frames() % 60 == 0:
		push_warning("DEBUG: ", what)

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

func register_device(name: StringName, device_path: NodePath) -> void:
	return
	var id := 0 # TODO: SOMETHING HERE!
	devices[id] = device_path
	var last_update = get_device_state(id)
	get_node(device_path).net_update(last_update)

func unregister_device(id: int) -> bool:
	return devices.erase(id)

func get_device_state(id: int) -> Variant:
	return device_last_update.get(id, null)

func _update_device(id: int, data) -> void:
	device_last_update[id] = data
	if id in devices:
		get_node(devices[id]).net_update(data)

# net_read should be of the form (PackedByteArray) -> [Variant, PackedByteArray]
func _read_device_data(id: int, buf: PackedByteArray) -> Array:
	if id in devices:
		return get_node(devices[id]).net_read(buf)
	return [null, buf] # pass it through?


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


var rec_socket: StreamPeerTCP = StreamPeerTCP.new()
var ubc_socket: PacketPeerUDP = PacketPeerUDP.new()
var uec_socket: PacketPeerUDP = PacketPeerUDP.new()

func connect_async(host, port := 1312):
	if rec_socket.connect_to_host(host, port+1) != Error.OK:
		print("shit went wrong!")
		return
	current_state = State.CONNECTING
	connecting.emit()

func net_disconnect(reason: String, code: int = 1000):
	rec_socket.close(code, reason)
	current_state = State.DISCONNECTING

func _process_connecting(delta):
	pass


func _on_ready():
	set_process(false)
	pass

func _on_login():
	var login_parameters = {
		username = username,
		version = version,
		}

	var data = JSON.stringify(login_parameters)
	
	pass

func _gen_rec_header(packet: REC.RECMessage) -> REC.Header:
	var header := packet.new_header()
	header.set_magic_number(0x1312)
	header.set_protocol_version(0)
	header.set_flags(0)
	return header

func _on_connecting():
	var packet := REC.RECMessage.new()
	_gen_rec_header(packet)
	var handshake := packet.new_handshake()
	var capabilities := handshake.new_capabilities()
	capabilities.clear_supported_features()
	capabilities.clear_supported_environments()
	handshake.set_client_major_version(2)
	handshake.set_client_minor_version(0)
	handshake.set_verification(0)
	handshake.set_username(username)
	
	rec_socket.put_data(packet.to_bytes())
	set_process(true)
	pass


func _process_rec_connecting(packet: REC.RECMessage) -> void:
	match packet.get_type():
		REC.RECMessageType.REC_HANDSHAKE_ACK:
			current_state = State.CONNECTED
		REC.RECMessageType.REC_SESSION_CLOSE:
			current_state = State.DISCONNECTING
			disconnected.emit()
			print("disconnected by server: %s" % packet.get_session_close().get_msg())
		var x:
			net_disconnect("invalid REC message type for state %s: %s" % [current_state, x])
	pass


func _read_packets(process_rec: Callable):
	while rec_socket.get_available_bytes() > 0:
		var packet := REC.RECMessage.new()
		var data := rec_socket.get_data(rec_socket.get_available_bytes())
		packet.from_bytes(data)
		
		print(packet.to_string())
		
		if packet.get_header().get_magic_number() != 0x1312:
			return net_disconnect("invalid packet header")
		
		process_rec.call(packet)

func _process(delta):
	_dprint("")
	_dprint(current_state)
	var process_rec
	match current_state:
		State.CONNECTING:
			process_rec = _process_rec_connecting
	_read_packets(process_rec)

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
