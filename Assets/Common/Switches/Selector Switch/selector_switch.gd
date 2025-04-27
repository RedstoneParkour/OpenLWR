
extends Node3D

@export var id: StringName

enum SwitchFlag {
	GREEN,
	RED,
}

@onready var player = $"/root/Node3D/Player"
var switch_position: int
var switch_positions: Dictionary
var switch_flag: SwitchFlag
var switch_local_push: bool = false
var switch_momentary: bool
@export var rotate_opposite: bool = false
@onready var has_flag = get_node_or_null("selector_switch/Flag")
var flag_green = null
var flag_red = null

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
	if id == &"":
		id = StringName(name)
		push_warning("id property of button is empty, using node name %s" % id)
	Network.register_switch(id, self.get_path())
	player.unclick_left.connect(switch_unclick)

func switch_update(info: Dictionary):
	if "position" in info:
		switch_position = info.position
	if "positions" in info:
		switch_positions = info.positions
	if "flag" in info:
		switch_flag = _string_to_flag(info.flag)
	switch_model_update()

func switch_model_update(nosound: bool = false):
	var rotate_position = switch_positions.get(str(switch_position), 0)
	var handle_rotation = round($"selector_switch/Handle".rotation_degrees.y)
	
	# used in the case where a switch was modeled such that it needs to be rotated the opposite direction
	if rotate_opposite:
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
	var new_info = {
		position = switch_position,
		flag = _flag_to_string(switch_flag),
	}
	Network.client_update_switch(id, new_info)

func switch_click_left(_camera, event, _position, _normal, _shape_idx):
	var mouse_click = event as InputEventMouseButton
	if mouse_click and mouse_click.button_index == 1:
		if mouse_click.pressed and (str(switch_position+1) in switch_positions):
			print("swotch")
			switch_local_push = true
			_client_switch_position_change(switch_position+1)
			

func switch_click_right(_camera, event, _position, _normal, _shape_idx):
	var mouse_click = event as InputEventMouseButton
	if mouse_click and mouse_click.button_index == 1:
		if mouse_click.pressed and (str(switch_position-1) in switch_positions):
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
