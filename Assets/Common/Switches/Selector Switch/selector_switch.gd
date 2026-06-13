
extends Node3D

@export var netname: StringName
var id: int

enum SwitchFlag {
	GREEN,
	RED,
}

@onready var player = $"/root/Node3D/Player"
@export var switch_neutral_position: int = 0
var switch_position: int = 0
@export var switch_positions: Dictionary[int, float]
var switch_flag: SwitchFlag
var switch_local_push: bool = false
#array of two ints: [0] is the target position, [1] is the deadline (engine ticks, milliseconds)
var unacked_client_changes: Array[PackedInt64Array] = []
const CHANGE_ACK_TIMEOUT := 1000 # milliseconds
@export var switch_momentary: bool = false
@onready var has_flag = get_node_or_null("selector_switch/Flag")
var flag_green = preload("res://Assets/Materials/green_flag.tres")
var flag_red = preload("res://Assets/Materials/red_flag.tres")


func _ready():
	switch_position = switch_neutral_position
	if netname == &"":
		netname = StringName(name)
		push_warning("netname property of selector switch is empty, using node name %s" % netname)
	id = DeviceRegistry.name_to_id(netname)
	Network.register_device(id, self.get_path())
	player.unclick_left.connect(switch_unclick)
	switch_model_update(true)

func _push_client_update(new: int) -> void:
	var now = Time.get_ticks_msec()
	var deadline = now + CHANGE_ACK_TIMEOUT
	unacked_client_changes.append(PackedInt64Array([new, deadline]))
	while unacked_client_changes.size() > 0:
		var change = unacked_client_changes[0]
		if change[1] < now:
			unacked_client_changes.remove_at(0)
		else:
			break

func _is_client_update(new: int) -> bool:
	var now := Time.get_ticks_msec()
	var ret := false
	while unacked_client_changes.size() > 0:
		var change = unacked_client_changes[0]
		if change[0] == new:
			ret = true
			unacked_client_changes.remove_at(0)
			break
		elif change[1] < now:
			unacked_client_changes.remove_at(0)
		else:
			break
	return ret

func net_update(info):
	if info is Dictionary:
		var nosound = true
		var do_update = false
		if 0 in info: # switch position
			nosound = nosound and _is_client_update(info[0])
			do_update = true
			switch_position = info[0]
		if 1 in info: # switch flag
			do_update = true
			switch_flag = SwitchFlag.RED if info[1] else SwitchFlag.GREEN
		if do_update:
			switch_model_update(nosound)
	pass

func switch_model_update(nosound: bool = false):
	var rotate_position = switch_positions.get(switch_position, 0)
	var handle_rotation = round($"selector_switch/Handle".rotation_degrees.y)
	
	if handle_rotation != rotate_position:
		if not nosound:
			$"Move".playing = true
		$"selector_switch/Handle".rotation_degrees.y = rotate_position
	
	if has_flag:
		#TODO: sync flags with server		
		match switch_flag:#TODO: PTL Color (black)
			SwitchFlag.GREEN:
				has_flag.set_surface_override_material(0,flag_green)
			SwitchFlag.RED:
				has_flag.set_surface_override_material(0,flag_red)

func _client_switch_position_change(to_position: int, no_sound: bool = false):
	switch_position = to_position
	switch_model_update(no_sound)
	_push_client_update(to_position)
	
	const UBC = preload("res://Assets/Generated/Protocols/ubc.gd")
	var update_data = UBC.UBCMessage.Payload.Data.new()
	update_data.set_field(0)
	update_data.set_int_value(switch_position)
	Network.client_update(id, 0, update_data.to_bytes())

func switch_click_left(_camera, event, _position, _normal, _shape_idx):
	var mouse_click = event as InputEventMouseButton
	if mouse_click and mouse_click.button_index == 1:
		if mouse_click.pressed and (switch_position+1 in switch_positions):
			switch_local_push = true
			_client_switch_position_change(switch_position+1)
			

func switch_click_right(_camera, event, _position, _normal, _shape_idx):
	var mouse_click = event as InputEventMouseButton
	if mouse_click and mouse_click.button_index == 1:
		if mouse_click.pressed and (switch_position-1 in switch_positions):
			switch_local_push = true
			_client_switch_position_change(switch_position-1)
			
func switch_unclick():
	if switch_local_push and switch_momentary:
		_client_switch_position_change(switch_neutral_position)

func switch_click_ptl(_camera, event, _position, _normal, _shape_idx):
	print("pull to lock") #TODO

#func switch_vr_player(name):
	#
	#if name == "VRInteractionZoneL":
		#if (switch.position+1 in switch.positions):
			#switch_position_change(switch.position+1)
			#if switch.position >=2 and ("flag" in switch):
				#switch.flag = "red"
			#switch.updated = true
	#elif name == "VRInteractionZoneR":
		#if (switch.position-1 in switch.positions):
			#switch_position_change(switch.position-1)
			#if switch.position <=0 and ("flag" in switch):
				#switch.flag = "green"
			#switch.updated = true
