extends Control

var _requested_scene_path: String

func connect_server(ip: String, requested_scene: String):

	var server_ip_requested = ip
	var username_requested = $Panel/HSplitContainer/Control/HBoxContainer/ServerInfo/VBoxContainer/HBoxContainer/LineEdit.text
	globals.server_ip_requested_tojoin = server_ip_requested
	globals.username_requested_tojoin = username_requested
	globals.use_vr = $Panel/HSplitContainer/Control/HBoxContainer/ServerInfo/VBoxContainer/HBoxContainer/VREnable.button_pressed

	Network.username = username_requested
	_requested_scene_path = "res://Assets/Scenes/%s/control_room.tscn" % requested_scene
	Network.connect_async(server_ip_requested)
	ResourceLoader.load_threaded_request(_requested_scene_path)

func _on_connected():
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(_requested_scene_path))



func _ready():
	Network.connected.connect(_on_connected)
	
		
	if globals.disconnect_msg != "":
		$KickMessage/VBoxContainer/Name/Label.text = "You were disconnected with reason:\n%s" % globals.disconnect_msg
		$KickMessage.popup()
		globals.disconnect_msg = ""
		
	pass

func _on_add_server_pressed():
	$"Add server".popup()
	pass # Replace with function body.


func _on_line_edit_text_changed(username):
	var username_valid = len(username) <= 20 and len(username) >= 2
	$Panel/HSplitContainer/Control/HBoxContainer/ServerInfo/VBoxContainer/HBoxContainer2/Join.disabled = not username_valid
	$Panel/HSplitContainer/Control/HBoxContainer/ServerInfo/VBoxContainer/InvalidUser.visible = not username_valid
