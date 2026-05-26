extends PanelContainer

@export var server_name: String
@export var server_ip: String

@export var unselected: StyleBox
@export var selected: StyleBox

const REC = preload("res://Assets/Generated/Protocols/rec.gd")
var response: REC.RECServerInfo = null
var model: String = "test_scene"

const SERVER_MODELS: Dictionary[String, String] = {
	"OpenLWR Server": "test_scene",
}

func _ready():
	$LobbyItem/Line1/Label.text = server_name
	$LobbyItem/Line2/Label3.text = server_ip
	add_theme_stylebox_override("panel", unselected)
	$Network.begin_login.connect(_network_connected)
	$Network.server_info_received.connect(_network_server_info_received)
	$Network.connect_async(server_ip, 1312, false)
	
	pass

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
	pass

func _network_connected() -> void:
	print("requesting server info")
	$Network.request_server_info()
	pass

func _network_disconnected() -> void:
	if not response:
		return ping_fail.emit()

func _network_server_info_received(info: REC.RECServerInfo) -> void:
	$Timer.stop()
	ping_complete.emit(info)
	
func _on_timer_timeout() -> void:
	$Timer.stop()
	ping_fail.emit()

signal ping_complete(info: REC.RECServerInfo)

func _on_ping_complete(info: REC.RECServerInfo):
	model = SERVER_MODELS[info.get_server_name()]
	response = info
	
	var status: String = info.get_server_name()
	var online := str(info.get_current_sessions())
	$LobbyItem/Line2/Label3.text = status
	$LobbyItem/Line1/Label2.text = "%s online" % online
	_destroy_network()
	pass

signal ping_fail()

func _on_ping_fail():
	$LobbyItem/Line2/Label3.text = "[color=red]Unable to connect to server (skill issue)[/color]"
	$LobbyItem/Line1/Label2.text = "error"
	_destroy_network()
	pass

func _destroy_network():
	$Network.net_disconnect("ping succeeded")

func _on_focus_entered():
	add_theme_stylebox_override("panel", selected)
	pass

func _on_focus_exited():
	add_theme_stylebox_override("panel", unselected)
	pass
