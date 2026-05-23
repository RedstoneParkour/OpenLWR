
extends Node3D

@export var netname: StringName
var id: int

enum SwitchFlag {
	GREEN,
	RED,
}

enum RotateOpposite {
	NO,
	UNSPECIFIED,
	YES,
}

@onready var player = $"/root/Node3D/Player"
var switch_position: int = 0
@export var switch_positions: Dictionary[int, float]
var switch_flag: SwitchFlag
var switch_local_push: bool = false
@export var switch_momentary: bool = false
@export var rotate_opposite: RotateOpposite = RotateOpposite.UNSPECIFIED
@onready var has_flag = get_node_or_null("selector_switch/Flag")
var flag_green = null
var flag_red = null

@export var light_nodes: Dictionary[String, NodePath] = {}

#func init():
	#switch = node_3d.switches[self.name]
	#switch.switch = self
	#switch.local_push = false
	#player.unclick_left.connect(switch_unclick)
	#if switch.lights != {}:
		#for light in switch.lights:
			#if light == "green" or light == "red":
				##this is so we dont have to make every light unique
				#var light_material = get_node(light+"/Lamp").get_material().duplicate()
				#get_node(light+"/Lamp").material = light_material
				#light_material.emission_enabled = switch["lights"][light]
				#switch["lights"][light] = light_material
			#else:
				#var light_material = get_node(light).get_material().duplicate()
				#get_node(light).material = light_material
				#light_material.emission_enabled = switch["lights"][light]
				#switch["lights"][light] = light_material
				#
	#if has_flag:
		#switch["flag"] = "green"
		##preload the materials here, if it has a flag
		#flag_green = preload("res://Assets/Materials/green_flag.tres")
		#flag_red = preload("res://Assets/Materials/red_flag.tres")
		#
	#switch_position_change(switch["position"],true)

func _find_light_node(netname: StringName):
	if light_nodes.has(netname):
		return light_nodes[netname]
	var node
	if netname == &"green" or netname == &"red":
		node = get_node(netname+"/Lamp")
	else:
		node = get_node(NodePath(netname))
	if node:
		node.material = node.material.duplicate()
	light_nodes[netname] = node
	return node

func _flag_to_string(flag: SwitchFlag):
	match flag:
		SwitchFlag.GREEN:
			return "green"
		SwitchFlag.RED:
			return "red"

func _string_to_flag(flag: String):
	match flag:
		"green":
			return SwitchFlag.GREEN
		"red":
			return SwitchFlag.RED

func _ready():
	if netname == &"":
		netname = StringName(name)
		push_warning("netname property of selector switch is empty, using node name %s" % netname)
	if rotate_opposite == RotateOpposite.UNSPECIFIED:
		rotate_opposite = RotateOpposite.YES if has_node("rotate_opposite") else RotateOpposite.NO
		push_warning("rotate_opposite property of switch %s left unspecified, using node check" % netname)
	id = Network.name_to_id(netname)
	Network.register_device(id, self.get_path())
	player.unclick_left.connect(switch_unclick)
	switch_model_update(true)

func net_update(info):
	#print(info)
	pass

func switch_update(info: Dictionary):
	if "lights" in info:
		for name in info.lights:
			_find_light_node(name)
			get_node(light_nodes[name]).material.emission_enabled = info.lights[name]
	if "position" in info:
		switch_position = info.position
	if "positions" in info:
		switch_positions = info.positions
	if "flag" in info:
		switch_flag = _string_to_flag(info.flag)
	switch_model_update()

func switch_model_update(nosound: bool = false):
	var rotate_position = switch_positions.get(switch_position, 0)
	var handle_rotation = round($"selector_switch/Handle".rotation_degrees.y)
	
	# used in the case where a switch was modeled such that it needs to be rotated the opposite direction
	if rotate_opposite == RotateOpposite.YES:
		rotate_position = rotate_position * -1
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
	switch_flag = SwitchFlag.RED if to_position >= 0 else SwitchFlag.GREEN
	switch_position = to_position
	switch_model_update(no_sound)
	
	const UBC = preload("res://Assets/Generated/Protocols/ubc.gd")
	var update_data = UBC.UBCMessage.Payload.Data.new()
	update_data.set_field(0)
	update_data.set_int_value(switch_position)
	Network.client_update(id, 0, update_data.to_bytes())

func switch_click_left(_camera, event, _position, _normal, _shape_idx):
	var mouse_click = event as InputEventMouseButton
	if mouse_click and mouse_click.button_index == 1:
		if mouse_click.pressed and (switch_position+1 in switch_positions):
			print("swotch")
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
		_client_switch_position_change(1)

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
