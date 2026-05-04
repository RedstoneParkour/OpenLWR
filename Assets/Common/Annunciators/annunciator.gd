extends Node3D

enum AnnunciatorState {
	CLEAR,
	ACTIVE,
	ACKNOWLEDGED,
	ACTIVE_CLEAR,
}

var active_annunciator_on := false
var clear_annunciator_on := false

var alarm_dict: Dictionary = Network.device_last_update

var alarm_node = "Alarm1/"

var ann_light = {}

func _ready():
	set_process(false)
	if Network.current_state != Network.State.CONNECTED:
		await Network.connected
	for alarm_id in alarm_dict:
		var alarm = alarm_dict[alarm_id]
		var alarm_node = get_node("%s/Windows/%s" % [alarm.box, alarm.window])
		if not alarm_node is CSGBox3D:
				alarm_node = alarm_node.get_node("CSGBox3D")
		alarm_node.material = alarm_node.material.duplicate()
	#set_process(true)

func _process(delta):
	var new_active_annunciator_on := Engine.get_physics_frames() % 12 > 6
	if new_active_annunciator_on != active_annunciator_on:
		clear_annunciator_on = Engine.get_physics_frames() % 36 > 18
		active_annunciator_on = new_active_annunciator_on
		var alarm_active = false
		var clear_alarm_active = false

		for box in ann_light:
			ann_light[box].lights_on = 0
			ann_light[box].colors = []
			#ann_light[box].avg_color = Color()


		for alarm_id in alarm_dict:
			var alarm = alarm_dict[alarm_id]
			var alarm_node = get_node("%s/Windows/%s" % [alarm.box, alarm.window])
			if not alarm_node is CSGBox3D:
				alarm_node = alarm_node.get_node("CSGBox3D")

			if alarm.box not in ann_light:
				ann_light[alarm.box] = {
					"lights_on" : 0,
					"colors" : [],
					"avg_color" : Color(),
				}

			if alarm_node.material == null:
				continue
			match alarm.state as AnnunciatorState:
				AnnunciatorState.CLEAR:
					alarm_node.material.emission_enabled = false

				AnnunciatorState.ACTIVE:
					Network._dprint(alarm_id)
					alarm_node.material.emission_enabled = active_annunciator_on
					alarm_active = true

				AnnunciatorState.ACKNOWLEDGED:
					alarm_node.material.emission_enabled = true

				AnnunciatorState.ACTIVE_CLEAR:
					alarm_node.material.emission_enabled = clear_annunciator_on
					clear_alarm_active = true

			# TODO: allow clients to turn this off in settings as this probably has a pretty big performance impact
			# also disable when main lights on as it's not visible anyways
			# NOTE: the fancy lights causes problems on gl_compatibility
			if not RenderingServer.get_current_rendering_method() == "gl_compatibility":
				if alarm_node.material.emission_enabled == true:
					ann_light[alarm.box].lights_on += 1

					ann_light[alarm.box].colors.append(alarm_node.material.emission)

		
		for box in ann_light:
			var box_table = ann_light[box]
			box_table.avg_color = Color(0,0,0,1)
			for color in box_table.colors:
				box_table.avg_color += color

			if len(box_table.colors) != 0:
				box_table.avg_color = box_table.avg_color/len(box_table.colors)

			box_table.avg_color.a = 1

			#print(box_table.avg_color)
			if has_node(box+"/Lighting"):
				if box_table.lights_on > 0:
					get_node(box+"/Lighting").visible = true
					get_node(box+"/Lighting").light_energy = (box_table.lights_on/30)+0.003
					get_node(box+"/Lighting").light_color = box_table.avg_color
				else:
					get_node(box+"/Lighting").visible = false
