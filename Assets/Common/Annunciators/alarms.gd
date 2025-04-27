extends Node3D

@export var id: StringName

@onready var alarm_group = self.name.substr(5,1)

func _ready():
	if id == &"":
		id = StringName(alarm_group)
		push_warning("id property of alarm group is empty, using group name %s" % alarm_group)
	Network.register_group(id, get_path())


func group_update(info):
	var fast_alarm = get_node("Fast")
	var slow_alarm = get_node("Slow")
	if "F" in info:
		var fast_active = not info["F"]
		if fast_active:
			Network._dprint(id)
		if fast_alarm.playing != fast_active:
			fast_alarm.playing = fast_active

	if "S" in info:
		var slow_active = not info["S"]
		if slow_alarm.playing != slow_active:
			slow_alarm.playing = slow_active
