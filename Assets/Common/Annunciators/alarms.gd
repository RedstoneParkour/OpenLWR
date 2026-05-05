extends Node3D

@export var netname: StringName
var id: int

@onready var alarm_group = self.name.substr(5,1)

func _ready():
	if netname == &"":
		netname = StringName(alarm_group)
		push_warning("netname property of alarm group is empty, using group name %s" % alarm_group)
	id = Network.name_to_id(netname)
	Network.register_device(id, get_path())


func group_update(info):
	var fast_alarm = get_node("Fast")
	var slow_alarm = get_node("Slow")
	if "F" in info:
		var fast_active = not info["F"]
		if fast_active:
			Network._dprint(netname)
		if fast_alarm.playing != fast_active:
			fast_alarm.playing = fast_active

	if "S" in info:
		var slow_active = not info["S"]
		if slow_alarm.playing != slow_active:
			slow_alarm.playing = slow_active
