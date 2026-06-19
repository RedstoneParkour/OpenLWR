extends Node
class_name SNetwork

const REC = preload("res://Assets/Generated/Protocols/rec.gd")
const UBC = preload("res://Assets/Generated/Protocols/ubc.gd")

func _dprint(what):
	if _ubc_unregistered_time < 0.01:
		print("DEBUG: ", what)

signal connecting()
signal begin_login()
signal connected()
signal disconnected()

signal server_info_received(packet: REC.RECServerInfo)

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

var devices := DeviceRegistry.new(self)

func register_device(id: int, device_path: NodePath) -> void:
	devices.register_device(id, device_path)

func unregister_device(id: int) -> bool:
	return devices.unregister_device(id)

func get_device_state(id: int) -> Variant:
	return devices.get_device_state(id)

# map from interaction id to device id
var outbound_interactions: Dictionary[int, int] = {}
var next_interaction_id := 0

func client_update(id: int, type: int, data: PackedByteArray = PackedByteArray()) -> void:
	var interaction_id := next_interaction_id
	next_interaction_id += 1
	var packet := REC.RECMessage.new()
	_gen_rec_header(packet)
	var interaction = packet.new_interaction()
	packet.set_type(REC.RECMessageType.REC_INTERACTION)

	interaction.set_interaction_id(interaction_id)
	interaction.set_target_device(id)
	interaction.set_interaction_type(type)
	interaction.set_data(data)

	rec_socket.put_data(packet.to_bytes())


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
var do_login: bool = true

var rec_socket: StreamPeerTCP = StreamPeerTCP.new()
var rec_session_id: int = 0 # session 0 is invalid
var ubc_socket: PacketPeerUDP = PacketPeerUDP.new()
var ubc_session_id: int = 0
var uec_socket: PacketPeerUDP = PacketPeerUDP.new()
var uec_session_id: int = 0

func connect_async(host: String, port := 1312, login := true):
	do_login = login
	var err := rec_socket.connect_to_host(host, port+1)
	if err != Error.OK:
		print("shit went wrong! %s" % err)
		return
	if ubc_socket.bind(0) != Error.OK:
		print("unable to bind UBC socket")
		return
	assert(ubc_socket.is_bound())
	if ubc_socket.connect_to_host(host, port) != Error.OK:
		print("unable to set up UBC socket")
		return
	print("ubc listening on %s" % ubc_socket.get_local_port())
	current_state = State.CONNECTING
	connecting.emit()

const DEFAULT_REASON := REC.RECSessionClose.Reason.UNKNOWN
func net_disconnect(reason: String, code := DEFAULT_REASON) -> void:
	print("DISCONNECT %s %s" % [code, reason])
	var disconnect_msg := REC.RECMessage.new()
	_gen_rec_header(disconnect_msg)
	disconnect_msg.set_type(REC.RECMessageType.REC_SESSION_CLOSE)
	var disconnect_data := disconnect_msg.new_session_close()
	disconnect_data.set_msg(reason)
	disconnect_data.set_reason(code)
	rec_socket.put_data(disconnect_data.to_bytes())
	rec_socket.disconnect_from_host()
	ubc_socket.close()
	current_state = State.DISCONNECTING

func _process_connecting(delta):
	pass


func _on_ready():
	set_process(false)
	pass

func _on_login():
	if do_login:
		var packet := REC.RECMessage.new()
		_gen_rec_header(packet)
		var handshake := packet.new_handshake()
		packet.set_type(REC.RECMessageType.REC_HANDSHAKE)
		var capabilities := handshake.new_capabilities()
		capabilities.clear_supported_features()
		capabilities.clear_supported_environments()
		handshake.set_client_major_version(1)
		handshake.set_client_minor_version(0)
		handshake.set_verification(0)
		handshake.set_username(username)
		
		print("sending login packet")
		rec_socket.put_data(packet.to_bytes())
	
	pass

func _gen_rec_header(packet: REC.RECMessage) -> REC.Header:
	var header := packet.new_header()
	header.set_magic_number(0x1312)
	header.set_protocol_version(1)
	header.set_flags(1)
	return header
	
func _gen_ubc_header(header: UBC.Header) -> UBC.Header:
	header.set_magic_number(0x1312)
	header.set_protocol_version(1)
	header.set_flags(1)
	return header

func _on_connecting():
	set_process(true)
	pass

func _on_connected():
	print("login complete!")
	pass

func register_ubc_uec():
	# fuck the uec for now
	if ubc_session_id != 0 and (true or uec_session_id != 0):
		print("registering channels")
		const RECMessageType = REC.RECMessageType
		var regpack := REC.RECMessage.new()
		_gen_rec_header(regpack)
		regpack.set_type(RECMessageType.REC_REGISTER_SESSION)
		var register := regpack.new_register_session()
		register.set_ubc_session_id(ubc_session_id)
		register.set_uec_session_id(uec_session_id)
		
		rec_socket.put_data(regpack.to_bytes())

func _heartbeat_ubc():
	var packet = UBC.Heartbeat.new()
	packet.set_timestamp(Time.get_unix_time_from_system() * 1000 as int) # it wants in milliseconds
	_gen_ubc_header(packet.new_header())
	packet.set_session_id(ubc_session_id)
	
	#print("sending ubc heartbeat")
	ubc_socket.put_packet(packet.to_bytes())

var _ubc_unregistered_time := 0.0
func _tick_ubc_unregistered(delta: float):
	#if ubc_session_id != 0:
	#	return
	_ubc_unregistered_time += delta
	if _ubc_unregistered_time > 1.0:
		_ubc_unregistered_time = 0.0
		_heartbeat_ubc()
	pass

func _process_ubc_unregistered(packet: UBC.Heartbeat) -> void:
	if ubc_session_id != 0:
		return
	print(packet)
	if packet.has_session_id():
		ubc_session_id = packet.get_session_id()
		print("UBC SID acquired: %s" % ubc_session_id)
		register_ubc_uec()

func _process_ubc_connected(packet: UBC.UBCMessage) -> void:
	print("BEGIN UBC UPDATE PACKET")
	for device in packet.get_payloads():
		var id = device.get_device_id()
		print("DEVICE %s" % id)
		var data: Dictionary[int, Variant] = {}
		for field in device.get_data_fields():
			var value
			print("field %s type %s" % [field.get_field(), field.get_data_case()])
			if field.has_string_value():
				value = field.get_string_value()
				print("string value %s" % value)
			elif field.has_int_value():
				value = field.get_int_value()
				print("int value %s" % value)
			elif field.has_float_value():
				value = field.get_float_value()
				print("float value %s" % value)
			elif field.has_bool_value():
				value = field.get_bool_value()
				print("bool value %s" % value)
			elif field.has_bytes_value():
				value = field.get_bytes_value()
				print("bytes value %s" % value)
			data[field.get_field()] = value
		devices.update_device(id, data)

func _process_rec_login(packet: REC.RECMessage) -> void:
	match packet.get_type():
		REC.RECMessageType.REC_HANDSHAKE_ACK:
			current_state = State.CONNECTED
			rec_session_id = packet.get_handshake_ack().get_session_id()
			connected.emit()
		REC.RECMessageType.REC_SESSION_CLOSE:
			current_state = State.DISCONNECTING
			disconnected.emit()
			print("disconnected by server: %s" % packet.get_session_close().get_msg())
		REC.RECMessageType.REC_SERVER_INFO:
			server_info_received.emit(packet.get_server_info())
		var x:
			net_disconnect("invalid REC message type for state %s: %s" % [current_state, x])
	pass
	
func _process_rec_connected(packet: REC.RECMessage) -> void:
	match packet.get_type():
		REC.RECMessageType.REC_SERVER_INFO:
			server_info_received.emit(packet.get_server_info())
	pass

func _process_ubc_login(packet) -> void:
	if packet is UBC.Heartbeat:
		_process_ubc_unregistered(packet)

func _read_packets_rec(process_rec: Callable):
	if rec_socket.poll() != Error.OK:
		current_state = State.DISCONNECTING
		disconnected.emit()
		return
	while rec_socket.get_available_bytes() > 0:
		var packet := REC.RECMessage.new()
		var data: PackedByteArray = rec_socket.get_data(rec_socket.get_available_bytes())[1]
		packet.from_bytes(data)
		
		print(packet.to_string())
		
		if not packet.has_header():
			net_disconnect("no packet header!")
			return
		if packet.get_header().get_magic_number() != 0x1312:
			net_disconnect("invalid packet header")
			return
		
		process_rec.call(packet)

func _check_header_ubc(packet) -> bool:
	if not packet.has_header():
		net_disconnect("no packet header!")
		return false
	if packet.get_header().get_magic_number() != 0x1312:
		net_disconnect("invalid packet header")
		return false
	return true

func _read_packets_ubc(process_ubc: Callable, process_heartbeat: Callable):
	while ubc_socket.get_available_packet_count() > 0:
		print("reading packet ubc")
		var packet := UBC.UBCMessage.new()
		var data := ubc_socket.get_packet()
		if packet.from_bytes(data) == 0:
			print(packet.to_string())
			
			if _check_header_ubc(packet):
				process_ubc.call(packet)
		else:
			var heartbeat := UBC.Heartbeat.new()
			heartbeat.from_bytes(data)
			print(heartbeat.to_string())
			process_heartbeat.call(heartbeat)
		

func request_server_info():
	var packet := REC.RECMessage.new()
	_gen_rec_header(packet)
	packet.set_type(REC.RECMessageType.REC_SERVER_INFO_REQUEST)
	# request intentionally left empty
	var _request := packet.new_server_info_request()
	rec_socket.put_data(packet.to_bytes())

var last_net_update := Time.get_ticks_msec() as float / 1000.0
func _process(_delta: float):
	# so it turns out the delta can be wrong (it says 0.133 when its actually 1 second)
	# i believe some linux window managers play dirty and slow down rendering or something
	# and guess who's using one of those
	# anyways to prevent timeouts we calculate the delta ourselves
	var new_time := Time.get_ticks_msec() as float / 1000.0
	var delta := new_time - last_net_update
	last_net_update = new_time
	#print("net process %s %s" % [delta, _ubc_unregistered_time])
	
	_dprint("")
	_dprint(current_state)
	_tick_ubc_unregistered(delta)
	match current_state:
		State.CONNECTING:
			if rec_socket.poll() != Error.OK:
				print("disconnected!")
				current_state = State.DISCONNECTING
				disconnected.emit()
			if rec_socket.get_status() == StreamPeerSocket.STATUS_CONNECTED:
				print("connected!")
				current_state = State.LOGIN
				begin_login.emit()
		State.LOGIN:
			_read_packets_rec(_process_rec_login)
			_read_packets_ubc(func(): pass, _process_ubc_login)
		State.CONNECTED:
			_read_packets_rec(_process_rec_connected)
			_read_packets_ubc(_process_ubc_connected, _process_ubc_login)
		State.DISCONNECTING:
			rec_socket = StreamPeerTCP.new()
			ubc_socket = PacketPeerUDP.new()
			uec_socket = PacketPeerUDP.new()
			current_state = State.READY
			disconnected.emit()

func _ready():
	connecting.connect(_on_connecting)
	begin_login.connect(_on_login)
	disconnected.connect(_on_ready)
	connected.connect(_on_connected)
	_on_ready()
	if self == Network:
		var arguments := _parse_arguments()
		var djoin_ip := "127.0.0.1"
		if arguments.has("username"):
			username = arguments.username
		if arguments.has("join"):
			if not arguments.join.is_empty():
				djoin_ip = arguments.join
			connect_async(djoin_ip)
	pass

func _exit_tree() -> void:
	net_disconnect("User initiated disconnect", REC.RECSessionClose.Reason.DISCONNECTED)
