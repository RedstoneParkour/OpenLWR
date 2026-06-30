class_name DeviceRegistry
extends RefCounted

var root: Node

# keys are int, values are NodePath
var devices: Dictionary[int, NodePath] = {}

# keys are int, values are Dictionary
var device_last_update: Dictionary[int, Dictionary] = {}

func _init(rnode: Node):
	root = rnode

static func name_to_id(netname: StringName) -> int:
	print(netname)
	print(netname.to_ascii_buffer())
	var h = netname.sha256_buffer()
	#h = h.slice(0,8)
	h.reverse() # seems OLWR-server decodes it in the reverse endian lmao
	print(h)
	var id = h.decode_u64(0) #this should work (i hope)
	print(id)
	return id

func register_device(id: int, device_path: NodePath) -> void:
	devices[id] = device_path
	var last_update = get_device_state(id)
	root.get_node(device_path).net_update(last_update)

func unregister_device(id: int) -> bool:
	return devices.erase(id)

func get_device_state(id: int) -> Variant:
	return device_last_update.get(id, null)

func update_device(id: int, data: Dictionary) -> void:
	var known: Dictionary = device_last_update.get_or_add(id, {})
	known.merge(data, true)
	print(known)
	print("trying to update %s" % id)
	if id in devices:
		root.get_node(devices[id]).net_update(known)

# net_read should be of the form (PackedByteArray) -> [Variant, PackedByteArray]
func read_device_data(id: int, buf: PackedByteArray) -> Array:
	if id in devices:
		return root.get_node(devices[id]).net_read(buf)
	return [null, buf] # pass it through?
