extends CSGBox3D

@export var netname: StringName
var id: int

@onready var player = $"/root/Node3D/Player"
var button_state: bool
var button_armed: bool
var button_local_push: bool

func _ready():
	if netname == &"":
		netname = StringName(name)
		push_warning("netname property of button is empty, using node name %s" % netname)
	id = DeviceRegistry.name_to_id(netname)
	Network.register_device(id, get_path())
	player.unclick_left.connect(un_click)

func button_state_change(state: bool, update_server: bool = true):
	button_state = state
	if update_server:
		_client_button_update()
	# TODO: button audio
	
func button_arm_change(armed: bool, update_server: bool = true):
	button_armed = armed
	if update_server:
		_client_button_update()

func _client_button_update():
	var info = {
		state = button_state,
		armed = button_armed,
	}
	
	push_warning("button press eaten!")
	#Network.client_update_button(id, info)

func button_update(info):
	if "state" in info:
		button_state_change(info["state"], false)
	if "armed" in info:
		button_arm_change(info["armed"], false)

func un_click():
	if button_local_push == true:
		button_state_change(false)

func switch_click(_camera, event, _position, _normal, _shape_idx):
	var mouse_click = event as InputEventMouseButton
	if mouse_click and mouse_click.button_index == 1:
		button_local_push = mouse_click.pressed
		button_state_change(mouse_click.pressed)
