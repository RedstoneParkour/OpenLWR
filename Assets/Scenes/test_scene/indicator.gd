extends Node

@export var netname: StringName
var id: int

func _ready():
	if netname == &"":
		netname = StringName(name)
		push_warning("netname property of indicator is empty, using node name %s" % netname)
	id = DeviceRegistry.name_to_id(netname)
	Network.register_device(id, self.get_path())

func net_update(info):
	if info:
		print("updating")
		get_node("Lamp").material.emission_enabled = info[0]
	print(info)
	pass
