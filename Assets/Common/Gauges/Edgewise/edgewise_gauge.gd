extends Node3D

@export var netname: StringName
var id: int

@export var scale_min: float = -1.0
@export var scale_max: float = 1.0
@export var override_info_dict: bool = false

# this should REALLY NOT BE HERE
# but inputting everything manually is tedious
const gauges: Dictionary = {
	"four_rod_br": {
		"value": 1,
		"atypical" : true, #The min/maxes dont apply. This is simply used for receiving a value.
		"text" : false, #Is handled differently than regular gauges. Is text instead of a linear scale.
	},
	"four_rod_bl": {
		"value": 1,
		"atypical" : true,
		"text" : false,
	},
	"four_rod_tr": {
		"value": 1,
		"atypical" : true,
		"text" : false,
	},
	"four_rod_tl": {
		"value": 1,
		"atypical" : true,
		"text" : false,
	},
	"srm_a_counts": {
		"value": 0,
		"min_value": 0,
		"max_value": 16.11809565095832,
		"atypical" : false,
		"text" : false,
	},
	"srm_b_counts": {
		"value": 0,
		"min_value": 0,
		"max_value": 16.11809565095832,
		"atypical" : false,
		"text" : false,
	},
	"srm_c_counts": {
		"value": 0,
		"min_value": 0,
		"max_value": 16.11809565095832,
		"atypical" : false,
		"text" : false,
	},
	"srm_d_counts": {
		"value": 0,
		"min_value": 0,
		"max_value": 16.11809565095832,
		"atypical" : false,
		"text" : false,
	},
	
	"srm_a_period": {
		"value": 0,
		"min_value": -0.009998,
		"max_value": 0.09930,
		"atypical" : false,
		"text" : false,
	},
	"srm_b_period": {
		"value": 0,
		"min_value": -0.009998,
		"max_value": 0.09930,
		"atypical" : false,
		"text" : false,
	},
	"srm_c_period": {
		"value": 0,
		"min_value": -0.009998,
		"max_value": 0.09930,
		"atypical" : false,
		"text" : false,
	},
	"srm_d_period": {
		"value": 0,
		"min_value": -0.009998,
		"max_value": 0.09930,
		"atypical" : false,
		"text" : false,
	},
	
	"hpcs_flow": {
		"value": 0,
		"min_value": 0,
		"max_value": 7000,
		"atypical" : false,
		"text" : false,
	},
	"hpcs_press": {
		"value": 0,
		"min_value": 0,
		"max_value": 1500,
		"atypical" : false,
		"text" : false,
	},

	"rhr_b_flow": {
		"value": 0,
		"min_value": 0,
		"max_value": 10000,
		"atypical" : false,
		"text" : false,
	},
	"rhr_b_press": {
		"value": 0,
		"min_value": 0,
		"max_value": 600,
		"atypical" : false,
		"text" : false,
	},
	
	"rhr_c_flow": {
		"value": 0,
		"min_value": 0,
		"max_value": 10000,
		"atypical" : false,
		"text" : false,
	},
	"rhr_c_press": {
		"value": 0,
		"min_value": 0,
		"max_value": 600,
		"atypical" : false,
		"text" : false,
	},
	
	"rcic_flow": {
		"value": 0,
		"min_value": 0,
		"max_value": 700,
		"atypical" : false,
		"text" : false,
	},
	
	"rcic_rpm": {
		"value": 0,
		"min_value": 0,
		"max_value": 7000,
		"atypical" : false,
		"text" : false,
	},
	
	"rcic_supply_press": {
		"value": 0,
		"min_value": 0,
		"max_value": 1200,
		"atypical" : false,
		"text" : false,
	},
	"rcic_exhaust_press": {
		"value": 0,
		"min_value": 0,
		"max_value": 50,
		"atypical" : false,
		"text" : false,
	},
	
	"rcic_pump_disch_press": {
		"value": 0,
		"min_value": 0,
		"max_value": 1300,
		"atypical" : false,
		"text" : false,
	},
	"rcic_pump_suct_press": {
		"value": 0,
		"min_value": 0,
		"max_value": 100,
		"atypical" : false,
		"text" : false,
	},
	
	"lpcs_flow": {
		"value": 0,
		"min_value": 0,
		"max_value": 10000,
		"atypical" : false,
		"text" : false,
	},
	"lpcs_press": {
		"value": 0,
		"min_value": 0,
		"max_value": 600,
		"atypical" : false,
		"text" : false,
	},
	
	"rhr_a_flow": {
		"value": 0,
		"min_value": 0,
		"max_value": 10000,
		"atypical" : false,
		"text" : false,
	},
	"rhr_a_press": {
		"value": 0,
		"min_value": 0,
		"max_value": 600,
		"atypical" : false,
		"text" : false,
	},
	
	"bus_4_voltage": {
		"value": 0,
		"min_value": 0,
		"max_value": 6000,
		"atypical" : false,
		"text" : false,
	},
	"main_generator_sync": {
		"value": 0,
		"min_value": 0,
		"max_value": 0,
		"atypical" : false,
		"text" : false,
	},
	"div_1_sync": {
		"value": 0,
		"min_value": 0,
		"max_value": 0,
		"atypical" : false,
		"text" : false,
	},
	"div_2_sync": {
		"value": 0,
		"min_value": 0,
		"max_value": 0,
		"atypical" : false,
		"text" : false,
	},
	
	#Reactor Recirculation
	
	#RR B
	
	"rrc_p_1b_volts": {
		"value": 0,
		"min_value": 0,
		"max_value": 8000,
		"atypical" : false,
		"text" : false,
	},
	"rrc_p_1b_amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 1000,
		"atypical" : false,
		"text" : false,
	},
	
	"rrc_p_1b_freq": {
		"value": 0,
		"min_value": 0,
		"max_value": 70,
		"atypical" : false,
		"text" : false,
	},
	"rrc_p_1b_speed": {
		"value": 0,
		"min_value": 0,
		"max_value": 2000,
		"atypical" : false,
		"text" : false,
	},
	
	"station_1b_flow": {
		"value": 0,
		"min_value": 0,
		"max_value": 60000,
		"atypical" : false,
		"text" : false,
	},
	"station_1b_bias": {
		"value": 0,
		"min_value": -10,
		"max_value": 10,
		"atypical" : false,
		"text" : false,
	},
	"station_1b_demand": {
		"value": 0,
		"min_value": 0,
		"max_value": 70,
		"atypical" : false,
		"text" : false,
	},
	"station_1b_actual": {
		"value": 0,
		"min_value": 0,
		"max_value": 70,
		"atypical" : false,
		"text" : false,
	},
	
	#RR A
	
	"rrc_p_1a_volts": {
		"value": 0,
		"min_value": 0,
		"max_value": 8000,
		"atypical" : false,
		"text" : false,
	},
	"rrc_p_1a_amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 1000,
		"atypical" : false,
		"text" : false,
	},
	
	"rrc_p_1a_freq": {
		"value": 0,
		"min_value": 0,
		"max_value": 70,
		"atypical" : false,
		"text" : false,
	},
	"rrc_p_1a_speed": {
		"value": 0,
		"min_value": 0,
		"max_value": 2000,
		"atypical" : false,
		"text" : false,
	},
	
	"station_1a_flow": {
		"value": 0,
		"min_value": 0,
		"max_value": 60000,
		"atypical" : false,
		"text" : false,
	},
	"station_1a_bias": {
		"value": 0,
		"min_value": -10,
		"max_value": 10,
		"atypical" : false,
		"text" : false,
	},
	"station_1a_demand": {
		"value": 0,
		"min_value": 0,
		"max_value": 70,
		"atypical" : false,
		"text" : false,
	},
	"station_1a_actual": {
		"value": 0,
		"min_value": 0,
		"max_value": 70,
		"atypical" : false,
		"text" : false,
	},
	
	"rwm_group": {
		"value": -1,
		"atypical" : true,
		"text" : false,
	},
	"rwm_insert_error_1": {
		"value": -1,
		"atypical" : true,
		"text" : false,
	},
	"rwm_insert_error_2": {
		"value": -1,
		"atypical" : true,
		"text" : false,
	},
	"rwm_withdraw_error": {
		"value": -1,
		"atypical" : true,
		"text" : false,
	},
	
	"mt_rpm": {
		"value": 0,
		"min_value": 0,
		"max_value": 2200,
		"atypical" : false,
		"text" : false,
	},
	"mt_load": {
		"value": 0,
		"min_value": 0,
		"max_value": 1400,
		"atypical" : false,
		"text" : false,
	},
	"mt_load_set": {
		"value": 0,
		"min_value": 0,
		"max_value": 1400,
		"atypical" : false,
		"text" : false,
	},
	
	"bypass_valve1": {
		"value": 0,
		"min_value": 0,
		"max_value": 100,
		"atypical" : false,
		"text" : false,
	},
	"bypass_valve2": {
		"value": 0,
		"min_value": 0,
		"max_value": 100,
		"atypical" : false,
		"text" : false,
	},
	"bypass_valve3": {
		"value": 0,
		"min_value": 0,
		"max_value": 100,
		"atypical" : false,
		"text" : false,
	},
	"bypass_valve4": {
		"value": 0,
		"min_value": 0,
		"max_value": 100,
		"atypical" : false,
		"text" : false,
	},
	
	#condensate
	"cond_booster_discharge_press": {
		"value": 0,
		"min_value": 0,
		"max_value": 1000,
		"atypical" : false,
		"text" : false,
	},
	"cond_booster_discharge_temp": {
		"value": 0,
		"min_value": 0,
		"max_value": 200,
		"atypical" : false,
		"text" : false,
	},
	"cond_p_2a_amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 600,
		"atypical" : false,
		"text" : false,
	},
	"cond_p_2b_amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 600,
		"atypical" : false,
		"text" : false,
	},
	"cond_p_2c_amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 600,
		"atypical" : false,
		"text" : false,
	},
	
	"cond_discharge_press": {
		"value": 0,
		"min_value": 0,
		"max_value": 1000,
		"atypical" : false,
		"text" : false,
	},
	"cond_discharge_temp": {
		"value": 0,
		"min_value": 0,
		"max_value": 200,
		"atypical" : false,
		"text" : false,
	},
	"cond_p_1a_amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 600,
		"atypical" : false,
		"text" : false,
	},
	"cond_p_1b_amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 600,
		"atypical" : false,
		"text" : false,
	},
	"cond_p_1c_amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 600,
		"atypical" : false,
		"text" : false,
	},
	
	"rft_dt_1a_rpm": {
		"value": 0,
		"min_value": 0,
		"max_value": 6000,
		"atypical" : false,
		"text" : false,
	},
	"rft_dt_1b_rpm": {
		"value": 0,
		"min_value": 0,
		"max_value": 6000,
		"atypical" : false,
		"text" : false,
	},
	
	"rfw_rpv_inlet_pressure": {
		"value": 0,
		"min_value": 0,
		"max_value": 1600,
		"atypical" : false,
		"text" : false,
	},
	
	"crd_p_1a_amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 100,
		"atypical" : false,
		"text" : false,
	},
	"crd_p_1b_amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 100,
		"atypical" : false,
		"text" : false,
	},
	
	"charge_header_pressure": {
		"value": 0,
		"min_value": 0,
		"max_value": 2000,
		"atypical" : false,
		"text" : false,
	},
	"drive_header_flow": {
		"value": 0,
		"min_value": 0,
		"max_value": 50,
		"atypical" : false,
		"text" : false,
	},
	"cooling_header_flow": {
		"value": 0,
		"min_value": 0,
		"max_value": 80,
		"atypical" : false,
		"text" : false,
	},
	
	"drive_header_dp": {
		"value": 0,
		"min_value": -500,
		"max_value": 500,
		"atypical" : false,
		"text" : false,
	},
	"cooling_header_dp": {
		"value": 0,
		"min_value": -500,
		"max_value": 500,
		"atypical" : false,
		"text" : false,
	},
	
	"crd_system_flow": {
		"value": 0,
		"min_value": 0,
		"max_value": 300,
		"atypical" : false,
		"text" : false,
	},
	
	"sw_p_1a_amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 300,
		"atypical" : false,
		"text" : false,
	},
	"sw_a_flow": {
		"value": 0,
		"min_value": 0,
		"max_value": 12000,
		"atypical" : false,
		"text" : false,
	},
	"sw_a_press": {
		"value": 0,
		"min_value": 0,
		"max_value": 300,
		"atypical" : false,
		"text" : false,
	},
	"sw_a_temp": {
		"value": 0,
		"min_value": 0,
		"max_value": 200,
		"atypical" : false,
		"text" : false,
	},
	
	"cia_main_header_press": {
		"value": 0,
		"min_value": 0,
		"max_value": 300,
		"atypical" : false,
		"text" : false,
	},
	"cia_ads_a_header_press": {
		"value": 0,
		"min_value": 0,
		"max_value": 300,
		"atypical" : false,
		"text" : false,
	},
	
	"control_air_press": {
		"value": 0,
		"min_value": 0,
		"max_value": 150,
		"atypical" : false,
		"text" : false,
	},
	
	"dg1p1volts": {
		"value": 0,
		"min_value": 0,
		"max_value": 6000,
		"atypical" : false,
		"text" : false,
	},
	"dg1p2volts": {
		"value": 0,
		"min_value": 0,
		"max_value": 6000,
		"atypical" : false,
		"text" : false,
	},
	"dg1p3volts": {
		"value": 0,
		"min_value": 0,
		"max_value": 6000,
		"atypical" : false,
		"text" : false,
	},
	"dg1_freq": {
		"value": 0,
		"min_value": 55,
		"max_value": 65,
		"atypical" : false,
		"text" : false,
	},
	"dg1p1amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 700,
		"atypical" : false,
		"text" : false,
	},
	"dg1p2amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 700,
		"atypical" : false,
		"text" : false,
	},
	"dg1p3amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 700,
		"atypical" : false,
		"text" : false,
	},
	
	"sm7running": {
		"value": 0,
		"min_value": 0,
		"max_value": 6000,
		"atypical" : false,
		"text" : false,
	},
	"sm7incoming": {
		"value": 0,
		"min_value": 0,
		"max_value": 6000,
		"atypical" : false,
		"text" : false,
	},
	
	"sm7voltage": {
		"value": 0,
		"min_value": 0,
		"max_value": 6000,
		"atypical" : false,
		"text" : false,
	},
	"b7amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 800,
		"atypical" : false,
		"text" : false,
	},
	"7_1amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 800,
		"atypical" : false,
		"text" : false,
	},
	
	"73voltage": {
		"value": 0,
		"min_value": 0,
		"max_value": 600,
		"atypical" : false,
		"text" : false,
	},
	"73amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 200,
		"atypical" : false,
		"text" : false,
	},
	
	
	"dg2p1volts": {
		"value": 0,
		"min_value": 0,
		"max_value": 6000,
		"atypical" : false,
		"text" : false,
	},
	"dg2p2volts": {
		"value": 0,
		"min_value": 0,
		"max_value": 6000,
		"atypical" : false,
		"text" : false,
	},
	"dg2p3volts": {
		"value": 0,
		"min_value": 0,
		"max_value": 6000,
		"atypical" : false,
		"text" : false,
	},
	"dg2_freq": {
		"value": 0,
		"min_value": 55,
		"max_value": 65,
		"atypical" : false,
		"text" : false,
	},
	"dg2p1amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 700,
		"atypical" : false,
		"text" : false,
	},
	"dg2p2amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 700,
		"atypical" : false,
		"text" : false,
	},
	"dg2p3amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 700,
		"atypical" : false,
		"text" : false,
	},
	
	"sm8running": {
		"value": 0,
		"min_value": 0,
		"max_value": 6000,
		"atypical" : false,
		"text" : false,
	},
	"sm8incoming": {
		"value": 0,
		"min_value": 0,
		"max_value": 6000,
		"atypical" : false,
		"text" : false,
	},
	
	"sm8voltage": {
		"value": 0,
		"min_value": 0,
		"max_value": 6000,
		"atypical" : false,
		"text" : false,
	},
	"b8amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 800,
		"atypical" : false,
		"text" : false,
	},
	"8_3amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 800,
		"atypical" : false,
		"text" : false,
	},
	
	"83voltage": {
		"value": 0,
		"min_value": 0,
		"max_value": 600,
		"atypical" : false,
		"text" : false,
	},
	"83amps": {
		"value": 0,
		"min_value": 0,
		"max_value": 200,
		"atypical" : false,
		"text" : false,
	},
}

func calculate_vertical_scale_position(indicated_value, scale_min, scale_max, meter_min_position = -22.4, meter_max_position = 22.1):
	return clamp(meter_min_position+((meter_max_position-meter_min_position)*(indicated_value-scale_min)/(scale_max-scale_min)),meter_min_position,meter_max_position)*-1
	
func set_gauge_value(value, min, max):
	var tween = get_tree().create_tween()
	tween.set_parallel()
	tween.tween_property($edgewise_gauge/Needle, "rotation_degrees", Vector3(-180, 0, calculate_vertical_scale_position(value, min, max)), 0.3)
	
func gauge_update(value):
	set_gauge_value(value, scale_min, scale_max)

func net_update(info):
	print(info)
	pass

func _ready():
	if netname == &"":
		netname = StringName(name)
		push_warning("netname property of button is empty, using node name %s" % netname)
	if not override_info_dict:
		var info = gauges.get(netname)
		if info:
			scale_min = info["min_value"]
			scale_max = info["max_value"]
	id = Network.name_to_id(netname)
	Network.register_device(id, get_path())
