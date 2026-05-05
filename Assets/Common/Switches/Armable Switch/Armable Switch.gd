extends Node3D

@export var netname: StringName
var id: int

var button_state: bool = false
var button_armed: bool = false

func _ready():
	if netname == &"":
		netname = StringName(name)
		push_warning("netname property of armable switch is empty, using node name %s" % netname)
	id = Network.name_to_id(netname)
	Network.register_device(id, get_path())
	pass
	
func animate_armed(armed:bool):
	pass
	
func animate_pressed(pressed:bool):
	pass

func _update_server():
	var info = {
		state = button_state,
		armed = button_armed,
	}
	push_warning("switch press eaten!")
	#Network.client_update_button(id, info)

func button_arm_change(to_position: bool, update_server: bool = true):
	button_armed = to_position
	var position = 45
	if to_position:
		position = -45
	if $"button".rotation_degrees.y !=  position:
		$"button".rotation_degrees.y = position
		$"Arm".playing = true
	if update_server:
		_update_server()
	
func button_state_change(state, update_server: bool = true):
	button_state = state
	if update_server:
		_update_server()

func button_update(info):
	if "state" in info:
		button_state_change(info["state"], false)
	if "armed" in info:
		button_arm_change(info["armed"], false)

func button_clicked(_camera, event, _position, _normal, _shape_idx):
	var mouse_click = event as InputEventMouseButton
	if mouse_click and mouse_click.button_index == 1 and button_armed and not Input.is_action_pressed("general_control_button"):
		button_state_change(mouse_click.pressed)
	elif mouse_click and mouse_click.button_index == 1 and Input.is_action_pressed("general_control_button") and mouse_click.pressed:
		button_arm_change(not button_armed)
