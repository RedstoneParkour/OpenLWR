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

func connect_async(host, port := 7001):
	print(rec_socket.connect_to_host(host, port))
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

func _on_connecting():
	set_process(true)
	pass

func _gen_dec_common_header(decoder: PacketDecoder) -> Callable:
	return decoder.dec_submsg.bind({
		1: decoder.dec_u32,
		2: decoder.dec_vu32,
		3: decoder.dec_vu32,
	})

enum RECMessageType {
	REC_UNKNOWN = 0,
	REC_HANDSHAKE = 1,
	REC_HANDSHAKE_ACK = 2,
	REC_REGISTER_SESSION = 3,
	REC_SESSION_CLOSE = 4,
	REC_ACK_ONLY = 5,
	REC_EVENT = 6,
	REC_INTERACTION = 7,
	REC_INTERACTION_ACK = 8,
}
enum RECCloseReason {
	UNKNOWN = 0,
	TIMEOUT = 1,
	VERSION_MISMATCH = 2,
	VERIFICATION_FAILED = 3,
	INCOMPATIBLE_FEATURES = 4,
	PROTOCOL_ERROR = 5,
	DISCONNECTED = 6,
	SERVER_SHUTDOWN = 7,
}


func _gen_map(a: Callable, b: Callable) -> Callable:
	return func(v, prev):
		v = a.call(v, null)
		return b.call(v, prev)

func _read_packets():
	while rec_socket.get_available_bytes() > 0:
		var decoder = PacketDecoder.new(rec_socket.get_data(rec_socket.get_available_bytes()))
		var packet = decoder.pop_message({
			1: _gen_dec_common_header(decoder), #dose.proto.common.Header header = 1;
			2: _gen_map(decoder.dec_u64, func (v, prev = null): v as RECMessageType), #RECMessageType type = 2;
			#oneof payload {
			4: decoder.dec_submsg.bind({ #RECHandshakeAck handshake_ack = 4;
				#message RECHandshakeAck {
				1: decoder.dec_vu32, #uint32 session_id = 1;
				2: decoder.dec_vu32, #uint32 server_tick = 2;
				3: decoder.dec_vu32, #uint32 server_time = 2;
				#}
			}),
			6: decoder.dec_submsg.bind({ #RECSessionClose session_close = 6;
				#message RECSessionClose {
				1: _gen_map(decoder.dec_u64, func(v, prev = null): v as RECCloseReason), #Reason reason = 1;
				2: decoder.dec_string, #string message = 2;
				#}
			}),
			7: decoder.dec_submsg.bind({ #RECEvent event = 7;
				#message RECEvent {

				#}
			}),
			#}
		})
		
		if packet[1][1] != 0x1312:
			return net_disconnect("invalid packet header")
		var proto_version = packet[1][2]
		# what's 'version 1.0' represented as???
		var flags = packet[1][3]
		# no clue how to decode this, keep as-is i suppose
		

func _process(delta):
	_dprint("")
	_dprint(current_state)
	_read_packets()
	match current_state:
		State.CONNECTING:
			_process_connecting(delta)

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
