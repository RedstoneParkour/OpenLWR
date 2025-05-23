extends CharacterBody3D

var target_position: Vector3 = position
var prev_position: Vector3 = position
var time_since_update: float = 0
var last_update_time: float = 0.1

func _dict_to_vec3(dict: Dictionary) -> Vector3:
	return Vector3(dict["x"], dict["y"], dict["z"])

func set_name_billboard(text: String):
	get_node("Sprite3D/SubViewport/Node2D/Label").text = text

func player_update(data: Dictionary):
	if data == null:
		# the remote player left
		queue_free()
		return
	rotation_degrees = _dict_to_vec3(data["rotation"])
	var new_position = _dict_to_vec3(data["position"])
	if (target_position - new_position).length() < 0.1:
		# probably a false update (or standing still)
		return
	prev_position = target_position
	target_position = _dict_to_vec3(data["position"])
	print(time_since_update)
	last_update_time = clamp(time_since_update, 1.0/60, 1.0/5)
	pass

func _process(delta: float):
	var weight: float = clamp(ease(time_since_update / last_update_time, -2.0), 0.0, 1.0)
	position = lerp(prev_position, target_position, weight)
	time_since_update += delta
	pass

func _ready():
	Network.register_player(name, get_path())
	set_name_billboard(name)

func _exit_tree():
	Network.unregister_player(name)
