extends CSGCylinder3D

@export var netname: StringName
var id: int
@onready var player := self.get_node("/root/Node3D/Player")

func _ready():
	if netname == &"":
		netname = StringName(name)
		push_warning("netname property of button is empty, using node name %s" % netname)
	id = Network.name_to_id(netname)
	Network.register_device(id, get_path())
	player.unclick_left.connect(button_state_change.bind(false))
	

func button_state_change(state: bool, update_server: bool = true):
	if update_server:
		var info = {
			state = state
		}
		push_warning("button press eaten!")
		#Network.client_update_button(id, info)
	pass
	# TODO: button audio

func button_update(info):
	if "state" in info:
		button_state_change(info["state"], false)

func switch_click(_camera, event, _position, _normal, _shape_idx):
	var mouse_click = event as InputEventMouseButton
	if mouse_click and mouse_click.button_index == 1:
		button_state_change(mouse_click.pressed)
