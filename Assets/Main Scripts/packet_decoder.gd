class_name PacketDecoder

var packet: PackedByteArray
var _ofs: int

func pop_u8() -> int:
	var ret = packet.decode_u8(_ofs)
	_ofs += 1
	return ret

func pop_u16() -> int:
	var ret = packet.decode_u16(_ofs)
	_ofs += 2
	return ret

func pop_u32() -> int:
	var ret = packet.decode_u32(_ofs)
	_ofs += 4
	return ret

func pop_u64() -> int:
	var ret = packet.decode_u64(_ofs)
	_ofs += 8
	return ret


func pop_s8() -> int:
	var ret = packet.decode_s8(_ofs)
	_ofs += 1
	return ret

func pop_s16() -> int:
	var ret = packet.decode_s16(_ofs)
	_ofs += 2
	return ret

func pop_s32() -> int:
	var ret = packet.decode_s32(_ofs)
	_ofs += 4
	return ret

func pop_s64() -> int:
	var ret = packet.decode_s64(_ofs)
	_ofs += 8
	return ret

const SEGMENT_BITS = 0x7F
const CONTINUE_BIT = 0x80

class VarintResult:
	var result
	var ok

	func _init(success, val):
		ok = success
		result = val

	func unwrap():
		if ok:
			return result
		else:
			Array.new()[3] # cause a script error

func _pop_varint(max_bytes: int) -> VarintResult:
	# adapted from https://minecraft.wiki/w/Java_Edition_protocol/Data_types#VarInt_and_VarLong
	var value = 0
	var position = 0

	while true:
		if _ofs >= packet.size():
			return VarintResult.new(false, "incomplete packet")
		var currentByte = pop_u8()
		value |= (currentByte & SEGMENT_BITS) << position

		if currentByte & CONTINUE_BIT == 0:
			break

		position += 7

		if position >= max_bytes * 8:
			return VarintResult.new(false, "packet too big")

	return VarintResult.new(true, value)

func pop_vu8() -> int:
	return _pop_varint(1).unwrap()

func pop_vu16() -> int:
	return _pop_varint(2).unwrap()

func pop_vu32() -> int:
	return _pop_varint(4).unwrap()

func pop_vu64() -> int:
	return _pop_varint(8).unwrap()

func pop_vs8() -> int:
	var unsigned = pop_vu8()
	if unsigned >> 7 == 1:
		return (unsigned & 0x7F) * -1
	else:
		return unsigned & 0x7F

func pop_vs16() -> int:
	var unsigned = pop_vu16()
	if unsigned >> 15 == 1:
		return (unsigned & 0x7FFF) * -1
	else:
		return unsigned & 0x7FFF

func pop_vs32() -> int:
	var unsigned = pop_vu32()
	if unsigned >> 31 == 1:
		return (unsigned & 0x7FFFFFFF) * -1
	else:
		return unsigned & 0x7FFFFFFF

# turns out gdscript is weird and has no u64, so u64's and s64's are the same???? (this may break???)
func pop_vs64() -> int:
	return _pop_varint(8).unwrap()

# DECODER FUNCTIONS

func dec_vi8(val: int, _prev = null) -> int:
	if val >> 7 == 1:
		return (val & 0x7F) * -1
	else:
		return (val & 0x7F)

func dec_vi16(val: int, _prev = null) -> int:
	if val >> 15 == 1:
		return (val & 0x7FFF) * -1
	else:
		return val & 0x7FFF
	
func dec_vi32(val: int, _prev = null) -> int:
	if val >> 31 == 1:
		return (val & 0x7FFFFFFF) * -1
	else:
		return (val & 0x7FFFFFFF)

# turns out gdscript is weird and has no u64, so u64's and s64's are the same???? (this may break???)
func dec_vi64(val: int, _prev = null) -> int:
	return val

func dec_vu8(val: int, _prev = null) -> int:
	return val & 0xFF

func dec_vu16(val: int, _prev = null) -> int:
	return val & 0xFFFF

func dec_vu32(val: int, _prev = null) -> int:
	return val & 0xFFFFFFFF

func dec_vu64(val: int, _prev = null) -> int:
	return val

func dec_bool(val: int, _prev = null) -> int:
	return val == 0x01

func dec_string(val: PackedByteArray, prev = null) -> String:
	if prev != null:
		prev = prev + val.get_string_from_utf8()
		return prev
	else:
		return val.get_string_from_utf8()

func dec_submsg(map, val: PackedByteArray, prev = null) -> Dictionary:
	var decoder = PacketDecoder.new(val)
	var ret = decoder.pop_message(map)
	if prev != null:
		ret.merge(prev)
	return ret

func dec_packed_repeated(popperName: StringName, val: PackedByteArray, prev = null) -> Array:
	var decoder = PacketDecoder.new(val)
	var ret = []
	while not decoder.is_empty():
		ret.insert(decoder.call(popperName))
	return ret

func dec_unpacked_repeated(decoder, val, prev = null) -> Array:
	if prev == null:
		prev = []
	prev.append(decoder(val))
	return prev
	

# dictionary of message id to decoding callable
func pop_message(map) -> Dictionary:
	var ret = {}
	while packet.size() - _ofs > 0:
		var tag = pop_vu64()
		var wtype = tag & 0x7
		var id = tag >> 3
		var val
		match wtype:
			0:#VARINT
				val = pop_vu64()
			1:#I64
				val = pop_u64()
			2:#LEN
				var l = pop_vu32()
				val = packet.slice(_ofs, _ofs+l)
				_ofs = _ofs+l
			3,4:#SGROUP,EGROUP
				assert(false,"SGROUP and EGROUP are not supported")
			5:#I32
				val = pop_u32()
		ret[id] = map[id](val, ret.get(id))

func is_empty():
	return _ofs == packet.size()

func _init(pckt):
	packet = pckt
	_ofs = 0
