#
# BSD 3-Clause License
#
# Copyright (c) 2018 - 2026, Oleg Malyavkin
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# DEBUG_TAB redefine this "  " if you need, example: const DEBUG_TAB = "\t"

const PROTO_VERSION = 3

const DEBUG_TAB : String = "  "

enum PB_ERR {
	NO_ERRORS = 0,
	VARINT_NOT_FOUND = -1,
	REPEATED_COUNT_NOT_FOUND = -2,
	REPEATED_COUNT_MISMATCH = -3,
	LENGTHDEL_SIZE_NOT_FOUND = -4,
	LENGTHDEL_SIZE_MISMATCH = -5,
	PACKAGE_SIZE_MISMATCH = -6,
	UNDEFINED_STATE = -7,
	PARSE_INCOMPLETE = -8,
	REQUIRED_FIELDS = -9
}

enum PB_DATA_TYPE {
	INT32 = 0,
	SINT32 = 1,
	UINT32 = 2,
	INT64 = 3,
	SINT64 = 4,
	UINT64 = 5,
	BOOL = 6,
	ENUM = 7,
	FIXED32 = 8,
	SFIXED32 = 9,
	FLOAT = 10,
	FIXED64 = 11,
	SFIXED64 = 12,
	DOUBLE = 13,
	STRING = 14,
	BYTES = 15,
	MESSAGE = 16,
	MAP = 17
}

const DEFAULT_VALUES_2 = {
	PB_DATA_TYPE.INT32: null,
	PB_DATA_TYPE.SINT32: null,
	PB_DATA_TYPE.UINT32: null,
	PB_DATA_TYPE.INT64: null,
	PB_DATA_TYPE.SINT64: null,
	PB_DATA_TYPE.UINT64: null,
	PB_DATA_TYPE.BOOL: null,
	PB_DATA_TYPE.ENUM: null,
	PB_DATA_TYPE.FIXED32: null,
	PB_DATA_TYPE.SFIXED32: null,
	PB_DATA_TYPE.FLOAT: null,
	PB_DATA_TYPE.FIXED64: null,
	PB_DATA_TYPE.SFIXED64: null,
	PB_DATA_TYPE.DOUBLE: null,
	PB_DATA_TYPE.STRING: null,
	PB_DATA_TYPE.BYTES: null,
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: null
}

const DEFAULT_VALUES_3 = {
	PB_DATA_TYPE.INT32: 0,
	PB_DATA_TYPE.SINT32: 0,
	PB_DATA_TYPE.UINT32: 0,
	PB_DATA_TYPE.INT64: 0,
	PB_DATA_TYPE.SINT64: 0,
	PB_DATA_TYPE.UINT64: 0,
	PB_DATA_TYPE.BOOL: false,
	PB_DATA_TYPE.ENUM: 0,
	PB_DATA_TYPE.FIXED32: 0,
	PB_DATA_TYPE.SFIXED32: 0,
	PB_DATA_TYPE.FLOAT: 0.0,
	PB_DATA_TYPE.FIXED64: 0,
	PB_DATA_TYPE.SFIXED64: 0,
	PB_DATA_TYPE.DOUBLE: 0.0,
	PB_DATA_TYPE.STRING: "",
	PB_DATA_TYPE.BYTES: [],
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: []
}

enum PB_TYPE {
	VARINT = 0,
	FIX64 = 1,
	LENGTHDEL = 2,
	STARTGROUP = 3,
	ENDGROUP = 4,
	FIX32 = 5,
	UNDEFINED = 8
}

enum PB_RULE {
	OPTIONAL = 0,
	REQUIRED = 1,
	REPEATED = 2,
	RESERVED = 3
}

enum PB_SERVICE_STATE {
	FILLED = 0,
	UNFILLED = 1
}

class PBField:
	func _init(a_name : String, a_type : int, a_rule : int, a_tag : int, packed : bool, a_value = null):
		name = a_name
		type = a_type
		rule = a_rule
		tag = a_tag
		option_packed = packed
		value = a_value
		
	var name : String
	var type : int
	var rule : int
	var tag : int
	var option_packed : bool
	var value
	var is_map_field : bool = false
	var option_default : bool = false

class PBTypeTag:
	var ok : bool = false
	var type : int
	var tag : int
	var offset : int

class PBServiceField:
	var field : PBField
	var func_ref = null
	var state : int = PB_SERVICE_STATE.UNFILLED

class PBPacker:
	static func convert_signed(n : int) -> int:
		if n < -2147483648:
			return (n << 1) ^ (n >> 63)
		else:
			return (n << 1) ^ (n >> 31)

	static func deconvert_signed(n : int) -> int:
		if n & 0x01:
			return ~(n >> 1)
		else:
			return (n >> 1)

	static func pack_varint(value) -> PackedByteArray:
		var varint : PackedByteArray = PackedByteArray()
		if typeof(value) == TYPE_BOOL:
			if value:
				value = 1
			else:
				value = 0
		for _i in range(9):
			var b = value & 0x7F
			value >>= 7
			if value:
				varint.append(b | 0x80)
			else:
				varint.append(b)
				break
		if varint.size() == 9 && (varint[8] & 0x80 != 0):
			varint.append(0x01)
		return varint

	static func pack_bytes(value, count : int, data_type : int) -> PackedByteArray:
		var bytes : PackedByteArray = PackedByteArray()
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_float(value)
			bytes = spb.get_data_array()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_double(value)
			bytes = spb.get_data_array()
		else:
			for _i in range(count):
				bytes.append(value & 0xFF)
				value >>= 8
		return bytes

	static func unpack_bytes(bytes : PackedByteArray, index : int, count : int, data_type : int):
		if data_type == PB_DATA_TYPE.FLOAT:
			return bytes.decode_float(index)
		elif data_type == PB_DATA_TYPE.DOUBLE:
			return bytes.decode_double(index)
		elif data_type == PB_DATA_TYPE.FIXED32:
			return bytes.decode_u32(index)
		elif data_type == PB_DATA_TYPE.SFIXED32:
			return bytes.decode_s32(index)
		elif data_type == PB_DATA_TYPE.FIXED64:
			return bytes.decode_u64(index)
		elif data_type == PB_DATA_TYPE.SFIXED64:
			return bytes.decode_s64(index)
		else:
			var value : int = 0
			for i in range(count):
				value |= bytes[index + i] << (8 * i)
			return value

	static func unpack_varint(varint_bytes) -> int:
		var value : int = 0
		var i: int = varint_bytes.size() - 1
		while i > -1:
			value = (value << 7) | (varint_bytes[i] & 0x7F)
			i -= 1
		return value

	static func pack_type_tag(type : int, tag : int) -> PackedByteArray:
		return pack_varint((tag << 3) | type)

	static func isolate_varint(bytes : PackedByteArray, index : int) -> PackedByteArray:
		var i: int = index
		while i <= index + 10 && i < bytes.size(): # Protobuf varint max size is 10 bytes
			if !(bytes[i] & 0x80):
				return bytes.slice(index, i + 1)
			i += 1
		return [] # Unreachable

	static func unpack_type_tag(bytes : PackedByteArray, index : int) -> PBTypeTag:
		var varint_bytes : PackedByteArray = isolate_varint(bytes, index)
		var result : PBTypeTag = PBTypeTag.new()
		if varint_bytes.size() != 0:
			result.ok = true
			result.offset = varint_bytes.size()
			var unpacked : int = unpack_varint(varint_bytes)
			result.type = unpacked & 0x07
			result.tag = unpacked >> 3
		return result

	static func pack_length_delimeted(type : int, tag : int, bytes : PackedByteArray) -> PackedByteArray:
		var result : PackedByteArray = pack_type_tag(type, tag)
		result.append_array(pack_varint(bytes.size()))
		result.append_array(bytes)
		return result

	static func pb_type_from_data_type(data_type : int) -> int:
		if data_type == PB_DATA_TYPE.INT32 || data_type == PB_DATA_TYPE.SINT32 || data_type == PB_DATA_TYPE.UINT32 || data_type == PB_DATA_TYPE.INT64 || data_type == PB_DATA_TYPE.SINT64 || data_type == PB_DATA_TYPE.UINT64 || data_type == PB_DATA_TYPE.BOOL || data_type == PB_DATA_TYPE.ENUM:
			return PB_TYPE.VARINT
		elif data_type == PB_DATA_TYPE.FIXED32 || data_type == PB_DATA_TYPE.SFIXED32 || data_type == PB_DATA_TYPE.FLOAT:
			return PB_TYPE.FIX32
		elif data_type == PB_DATA_TYPE.FIXED64 || data_type == PB_DATA_TYPE.SFIXED64 || data_type == PB_DATA_TYPE.DOUBLE:
			return PB_TYPE.FIX64
		elif data_type == PB_DATA_TYPE.STRING || data_type == PB_DATA_TYPE.BYTES || data_type == PB_DATA_TYPE.MESSAGE || data_type == PB_DATA_TYPE.MAP:
			return PB_TYPE.LENGTHDEL
		else:
			return PB_TYPE.UNDEFINED

	static func pack_field(field : PBField) -> PackedByteArray:
		var type : int = pb_type_from_data_type(field.type)
		var type_copy : int = type
		if field.rule == PB_RULE.REPEATED && field.option_packed:
			type = PB_TYPE.LENGTHDEL
		var head : PackedByteArray = pack_type_tag(type, field.tag)
		var data : PackedByteArray = PackedByteArray()
		if type == PB_TYPE.VARINT:
			var value
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						value = convert_signed(v)
					else:
						value = v
					data.append_array(pack_varint(value))
				return data
			else:
				if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
					value = convert_signed(field.value)
				else:
					value = field.value
				data = pack_varint(value)
		elif type == PB_TYPE.FIX32:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 4, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 4, field.type))
		elif type == PB_TYPE.FIX64:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 8, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 8, field.type))
		elif type == PB_TYPE.LENGTHDEL:
			if field.rule == PB_RULE.REPEATED:
				if type_copy == PB_TYPE.VARINT:
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						var signed_value : int
						for v in field.value:
							signed_value = convert_signed(v)
							data.append_array(pack_varint(signed_value))
					else:
						for v in field.value:
							data.append_array(pack_varint(v))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX32:
					for v in field.value:
						data.append_array(pack_bytes(v, 4, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX64:
					for v in field.value:
						data.append_array(pack_bytes(v, 8, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif field.type == PB_DATA_TYPE.STRING:
					for v in field.value:
						var obj = v.to_utf8_buffer()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
				elif field.type == PB_DATA_TYPE.BYTES:
					for v in field.value:
						data.append_array(pack_length_delimeted(type, field.tag, v))
					return data
				elif typeof(field.value[0]) == TYPE_OBJECT:
					for v in field.value:
						var obj : PackedByteArray = v.to_bytes()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
			else:
				if field.type == PB_DATA_TYPE.STRING:
					var str_bytes : PackedByteArray = field.value.to_utf8_buffer()
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && str_bytes.size() > 0):
						data.append_array(str_bytes)
						return pack_length_delimeted(type, field.tag, data)
				if field.type == PB_DATA_TYPE.BYTES:
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && field.value.size() > 0):
						data.append_array(field.value)
						return pack_length_delimeted(type, field.tag, data)
				elif typeof(field.value) == TYPE_OBJECT:
					var obj : PackedByteArray = field.value.to_bytes()
					if obj.size() > 0:
						data.append_array(obj)
					return pack_length_delimeted(type, field.tag, data)
				else:
					pass
		if data.size() > 0:
			head.append_array(data)
			return head
		else:
			return data

	static func skip_unknown_field(bytes : PackedByteArray, offset : int, type : int) -> int:
		if type == PB_TYPE.VARINT:
			return offset + isolate_varint(bytes, offset).size()
		if type == PB_TYPE.FIX64:
			return offset + 8
		if type == PB_TYPE.LENGTHDEL:
			var length_bytes : PackedByteArray = isolate_varint(bytes, offset)
			var length : int = unpack_varint(length_bytes)
			return offset + length_bytes.size() + length
		if type == PB_TYPE.FIX32:
			return offset + 4
		return PB_ERR.UNDEFINED_STATE

	static func unpack_field(bytes : PackedByteArray, offset : int, field : PBField, type : int, message_func_ref) -> int:
		if field.rule == PB_RULE.REPEATED && type != PB_TYPE.LENGTHDEL && field.option_packed:
			var count = isolate_varint(bytes, offset)
			if count.size() > 0:
				offset += count.size()
				count = unpack_varint(count)
				if type == PB_TYPE.VARINT:
					var val
					var counter = offset + count
					while offset < counter:
						val = isolate_varint(bytes, offset)
						if val.size() > 0:
							offset += val.size()
							val = unpack_varint(val)
							if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
								val = deconvert_signed(val)
							elif field.type == PB_DATA_TYPE.BOOL:
								if val:
									val = true
								else:
									val = false
							field.value.append(val)
						else:
							return PB_ERR.REPEATED_COUNT_MISMATCH
					return offset
				elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
					var type_size
					if type == PB_TYPE.FIX32:
						type_size = 4
					else:
						type_size = 8
					var val
					var counter = offset + count
					while offset < counter:
						if (offset + type_size) > bytes.size():
							return PB_ERR.REPEATED_COUNT_MISMATCH
						val = unpack_bytes(bytes, offset, type_size, field.type)
						offset += type_size
						field.value.append(val)
					return offset
			else:
				return PB_ERR.REPEATED_COUNT_NOT_FOUND
		else:
			if type == PB_TYPE.VARINT:
				var val = isolate_varint(bytes, offset)
				if val.size() > 0:
					offset += val.size()
					val = unpack_varint(val)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						val = deconvert_signed(val)
					elif field.type == PB_DATA_TYPE.BOOL:
						if val:
							val = true
						else:
							val = false
					if field.rule == PB_RULE.REPEATED:
						field.value.append(val)
					else:
						field.value = val
				else:
					return PB_ERR.VARINT_NOT_FOUND
				return offset
			elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
				var type_size
				if type == PB_TYPE.FIX32:
					type_size = 4
				else:
					type_size = 8
				var val
				if (offset + type_size) > bytes.size():
					return PB_ERR.REPEATED_COUNT_MISMATCH
				val = unpack_bytes(bytes, offset, type_size, field.type)
				offset += type_size
				if field.rule == PB_RULE.REPEATED:
					field.value.append(val)
				else:
					field.value = val
				return offset
			elif type == PB_TYPE.LENGTHDEL:
				var inner_size = isolate_varint(bytes, offset)
				if inner_size.size() > 0:
					offset += inner_size.size()
					inner_size = unpack_varint(inner_size)
					if inner_size >= 0:
						if inner_size + offset > bytes.size():
							return PB_ERR.LENGTHDEL_SIZE_MISMATCH
						if message_func_ref != null:
							var message = message_func_ref.call()
							if inner_size > 0:
								var sub_offset = message.from_bytes(bytes, offset, inner_size + offset)
								if sub_offset > 0:
									if sub_offset - offset >= inner_size:
										offset = sub_offset
										return offset
									else:
										return PB_ERR.LENGTHDEL_SIZE_MISMATCH
								return sub_offset
							else:
								return offset
						elif field.type == PB_DATA_TYPE.STRING:
							var str_bytes : PackedByteArray = bytes.slice(offset, inner_size + offset)
							if field.rule == PB_RULE.REPEATED:
								field.value.append(str_bytes.get_string_from_utf8())
							else:
								field.value = str_bytes.get_string_from_utf8()
							return offset + inner_size
						elif field.type == PB_DATA_TYPE.BYTES:
							var val_bytes : PackedByteArray = bytes.slice(offset, inner_size + offset)
							if field.rule == PB_RULE.REPEATED:
								field.value.append(val_bytes)
							else:
								field.value = val_bytes
							return offset + inner_size
					else:
						return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
				else:
					return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
		return PB_ERR.UNDEFINED_STATE

	static func unpack_message(data, bytes : PackedByteArray, offset : int, limit : int) -> int:
		while true:
			var tt : PBTypeTag = unpack_type_tag(bytes, offset)
			if tt.ok:
				offset += tt.offset
				if data.has(tt.tag):
					var service : PBServiceField = data[tt.tag]
					var type : int = pb_type_from_data_type(service.field.type)
					if type == tt.type || (tt.type == PB_TYPE.LENGTHDEL && service.field.rule == PB_RULE.REPEATED && service.field.option_packed):
						var res : int = unpack_field(bytes, offset, service.field, type, service.func_ref)
						if res > 0:
							service.state = PB_SERVICE_STATE.FILLED
							offset = res
							if offset == limit:
								return offset
							elif offset > limit:
								return PB_ERR.PACKAGE_SIZE_MISMATCH
						elif res < 0:
							return res
						else:
							break
				else:
					var res : int = skip_unknown_field(bytes, offset, tt.type)
					if res > 0:
						offset = res
						if offset == limit:
							return offset
						elif offset > limit:
							return PB_ERR.PACKAGE_SIZE_MISMATCH
					elif res < 0:
						return res
					else:
						break							
			else:
				return offset
		return PB_ERR.UNDEFINED_STATE

	static func pack_message(data) -> PackedByteArray:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : PackedByteArray = PackedByteArray()
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result.append_array(pack_field(data[i].field))
			elif data[i].field.rule == PB_RULE.REQUIRED:
				print("Error: required field is not filled: Tag:", data[i].field.tag)
				return PackedByteArray()
		return result

	static func check_required(data) -> bool:
		var keys : Array = data.keys()
		for i in keys:
			if data[i].field.rule == PB_RULE.REQUIRED && data[i].state == PB_SERVICE_STATE.UNFILLED:
				return false
		return true

	static func construct_map(key_values):
		var result = {}
		for kv in key_values:
			result[kv.get_key()] = kv.get_value()
		return result
	
	static func tabulate(text : String, nesting : int) -> String:
		var tab : String = ""
		for _i in range(nesting):
			tab += DEBUG_TAB
		return tab + text
	
	static func value_to_string(value, field : PBField, nesting : int) -> String:
		var result : String = ""
		var text : String
		if field.type == PB_DATA_TYPE.MESSAGE:
			result += "{"
			nesting += 1
			text = message_to_string(value.data, nesting)
			if text != "":
				result += "\n" + text
				nesting -= 1
				result += tabulate("}", nesting)
			else:
				nesting -= 1
				result += "}"
		elif field.type == PB_DATA_TYPE.BYTES:
			result += "<"
			for i in range(value.size()):
				result += str(value[i])
				if i != (value.size() - 1):
					result += ", "
			result += ">"
		elif field.type == PB_DATA_TYPE.STRING:
			result += "\"" + value + "\""
		elif field.type == PB_DATA_TYPE.ENUM:
			result += "ENUM::" + str(value)
		else:
			result += str(value)
		return result
	
	static func field_to_string(field : PBField, nesting : int) -> String:
		var result : String = tabulate(field.name + ": ", nesting)
		if field.type == PB_DATA_TYPE.MAP:
			if field.value.size() > 0:
				result += "(\n"
				nesting += 1
				for i in range(field.value.size()):
					var local_key_value = field.value[i].data[1].field
					result += tabulate(value_to_string(local_key_value.value, local_key_value, nesting), nesting) + ": "
					local_key_value = field.value[i].data[2].field
					result += value_to_string(local_key_value.value, local_key_value, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate(")", nesting)
			else:
				result += "()"
		elif field.rule == PB_RULE.REPEATED:
			if field.value.size() > 0:
				result += "[\n"
				nesting += 1
				for i in range(field.value.size()):
					result += tabulate(str(i) + ": ", nesting)
					result += value_to_string(field.value[i], field, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate("]", nesting)
			else:
				result += "[]"
		else:
			result += value_to_string(field.value, field, nesting)
		result += ";\n"
		return result
		
	static func message_to_string(data, nesting : int = 0) -> String:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : String = ""
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result += field_to_string(data[i].field, nesting)
			elif data[i].field.rule == PB_RULE.REQUIRED:
				result += data[i].field.name + ": " + "error"
		return result



############### USER DATA BEGIN ################


class RECMessage:
	func _init():
		var service
		
		__header = PBField.new("header", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __header
		service.func_ref = Callable(self, "new_header")
		data[__header.tag] = service
		
		__type = PBField.new("type", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __type
		data[__type.tag] = service
		
		__handshake = PBField.new("handshake", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __handshake
		service.func_ref = Callable(self, "new_handshake")
		data[__handshake.tag] = service
		
		__handshake_ack = PBField.new("handshake_ack", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __handshake_ack
		service.func_ref = Callable(self, "new_handshake_ack")
		data[__handshake_ack.tag] = service
		
		__register_session = PBField.new("register_session", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __register_session
		service.func_ref = Callable(self, "new_register_session")
		data[__register_session.tag] = service
		
		__session_close = PBField.new("session_close", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __session_close
		service.func_ref = Callable(self, "new_session_close")
		data[__session_close.tag] = service
		
		__event = PBField.new("event", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __event
		service.func_ref = Callable(self, "new_event")
		data[__event.tag] = service
		
		__interaction = PBField.new("interaction", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __interaction
		service.func_ref = Callable(self, "new_interaction")
		data[__interaction.tag] = service
		
		__interaction_ack = PBField.new("interaction_ack", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __interaction_ack
		service.func_ref = Callable(self, "new_interaction_ack")
		data[__interaction_ack.tag] = service
		
	var data = {}
	
	enum PayloadCase {
		PAYLOAD_NOT_SET = 0,
		HANDSHAKE = 3,
		HANDSHAKE_ACK = 4,
		REGISTER_SESSION = 5,
		SESSION_CLOSE = 6,
		EVENT = 7,
		INTERACTION = 8,
		INTERACTION_ACK = 9,
	}
	var _payload_case: int = 0

	var __header: PBField
	func has_header() -> bool:
		if __header.value != null:
			return true
		return false
	func get_header() -> Header:
		return __header.value
	func clear_header() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__header.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_header() -> Header:
		__header.value = Header.new()
		return __header.value
	
	var __type: PBField
	func has_type() -> bool:
		if __type.value != null:
			return true
		return false
	func get_type():
		return __type.value
	func clear_type() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_type(value) -> void:
		__type.value = value
	
	var __handshake: PBField
	func has_handshake() -> bool:
		return data[3].state == PB_SERVICE_STATE.FILLED
	func get_handshake() -> RECHandshake:
		return __handshake.value
	func clear_handshake() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_handshake() -> RECHandshake:
		data[3].state = PB_SERVICE_STATE.FILLED
		_payload_case = 3
		__handshake_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_session.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__session_close.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__event.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__interaction.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__interaction_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = RECHandshake.new()
		return __handshake.value
	
	var __handshake_ack: PBField
	func has_handshake_ack() -> bool:
		return data[4].state == PB_SERVICE_STATE.FILLED
	func get_handshake_ack() -> RECHandshakeAck:
		return __handshake_ack.value
	func clear_handshake_ack() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__handshake_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_handshake_ack() -> RECHandshakeAck:
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		data[4].state = PB_SERVICE_STATE.FILLED
		_payload_case = 4
		__register_session.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__session_close.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__event.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__interaction.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__interaction_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__handshake_ack.value = RECHandshakeAck.new()
		return __handshake_ack.value
	
	var __register_session: PBField
	func has_register_session() -> bool:
		return data[5].state == PB_SERVICE_STATE.FILLED
	func get_register_session() -> RECRegisterSession:
		return __register_session.value
	func clear_register_session() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__register_session.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_register_session() -> RECRegisterSession:
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__handshake_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		data[5].state = PB_SERVICE_STATE.FILLED
		_payload_case = 5
		__session_close.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__event.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__interaction.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__interaction_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__register_session.value = RECRegisterSession.new()
		return __register_session.value
	
	var __session_close: PBField
	func has_session_close() -> bool:
		return data[6].state == PB_SERVICE_STATE.FILLED
	func get_session_close() -> RECSessionClose:
		return __session_close.value
	func clear_session_close() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__session_close.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_session_close() -> RECSessionClose:
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__handshake_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_session.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		data[6].state = PB_SERVICE_STATE.FILLED
		_payload_case = 6
		__event.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__interaction.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__interaction_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__session_close.value = RECSessionClose.new()
		return __session_close.value
	
	var __event: PBField
	func has_event() -> bool:
		return data[7].state == PB_SERVICE_STATE.FILLED
	func get_event() -> RECEvent:
		return __event.value
	func clear_event() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__event.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_event() -> RECEvent:
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__handshake_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_session.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__session_close.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		data[7].state = PB_SERVICE_STATE.FILLED
		_payload_case = 7
		__interaction.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__interaction_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__event.value = RECEvent.new()
		return __event.value
	
	var __interaction: PBField
	func has_interaction() -> bool:
		return data[8].state == PB_SERVICE_STATE.FILLED
	func get_interaction() -> RECInteraction:
		return __interaction.value
	func clear_interaction() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__interaction.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_interaction() -> RECInteraction:
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__handshake_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_session.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__session_close.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__event.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		data[8].state = PB_SERVICE_STATE.FILLED
		_payload_case = 8
		__interaction_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__interaction.value = RECInteraction.new()
		return __interaction.value
	
	var __interaction_ack: PBField
	func has_interaction_ack() -> bool:
		return data[9].state == PB_SERVICE_STATE.FILLED
	func get_interaction_ack() -> RECInteractionAck:
		return __interaction_ack.value
	func clear_interaction_ack() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__interaction_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_interaction_ack() -> RECInteractionAck:
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__handshake_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_session.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__session_close.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__event.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__interaction.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		data[9].state = PB_SERVICE_STATE.FILLED
		_payload_case = 9
		__interaction_ack.value = RECInteractionAck.new()
		return __interaction_ack.value
	
	func get_payload_case() -> int:
		return _payload_case
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
enum RECMessageType {
	REC_UNKNOWN = 0,
	REC_HANDSHAKE = 1,
	REC_HANDSHAKE_ACK = 2,
	REC_REGISTER_SESSION = 3,
	REC_SESSION_CLOSE = 4,
	REC_EVENT = 6,
	REC_INTERACTION = 7,
	REC_INTERACTION_ACK = 8
}

enum HandshakeVerification {
	VERIFICATION_NONE = 0,
	VERIFICATION_BASIC = 1,
	VERIFICATION_JWT = 2,
	VERIFICATION_CUSTOM = 3
}

class RECHandshake:
	func _init():
		var service
		
		__capabilities = PBField.new("capabilities", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __capabilities
		service.func_ref = Callable(self, "new_capabilities")
		data[__capabilities.tag] = service
		
		__client_major_version = PBField.new("client_major_version", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __client_major_version
		data[__client_major_version.tag] = service
		
		__client_minor_version = PBField.new("client_minor_version", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __client_minor_version
		data[__client_minor_version.tag] = service
		
		__verification = PBField.new("verification", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __verification
		data[__verification.tag] = service
		
		__username = PBField.new("username", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __username
		data[__username.tag] = service
		
		__verification_data = PBField.new("verification_data", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __verification_data
		data[__verification_data.tag] = service
		
	var data = {}
	
	var __capabilities: PBField
	func has_capabilities() -> bool:
		if __capabilities.value != null:
			return true
		return false
	func get_capabilities() -> RECHandshake.Capabilities:
		return __capabilities.value
	func clear_capabilities() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__capabilities.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_capabilities() -> RECHandshake.Capabilities:
		__capabilities.value = RECHandshake.Capabilities.new()
		return __capabilities.value
	
	var __client_major_version: PBField
	func has_client_major_version() -> bool:
		if __client_major_version.value != null:
			return true
		return false
	func get_client_major_version() -> int:
		return __client_major_version.value
	func clear_client_major_version() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__client_major_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_client_major_version(value : int) -> void:
		__client_major_version.value = value
	
	var __client_minor_version: PBField
	func has_client_minor_version() -> bool:
		if __client_minor_version.value != null:
			return true
		return false
	func get_client_minor_version() -> int:
		return __client_minor_version.value
	func clear_client_minor_version() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__client_minor_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_client_minor_version(value : int) -> void:
		__client_minor_version.value = value
	
	var __verification: PBField
	func has_verification() -> bool:
		if __verification.value != null:
			return true
		return false
	func get_verification():
		return __verification.value
	func clear_verification() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__verification.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_verification(value) -> void:
		__verification.value = value
	
	var __username: PBField
	func has_username() -> bool:
		if __username.value != null:
			return true
		return false
	func get_username() -> String:
		return __username.value
	func clear_username() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__username.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_username(value : String) -> void:
		__username.value = value
	
	var __verification_data: PBField
	func has_verification_data() -> bool:
		if __verification_data.value != null:
			return true
		return false
	func get_verification_data() -> PackedByteArray:
		return __verification_data.value
	func clear_verification_data() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__verification_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_verification_data(value : PackedByteArray) -> void:
		__verification_data.value = value
	
	class Capabilities:
		func _init():
			var service
			
			var __supported_features_default: Array[String] = []
			__supported_features = PBField.new("supported_features", PB_DATA_TYPE.STRING, PB_RULE.REPEATED, 1, true, __supported_features_default)
			service = PBServiceField.new()
			service.field = __supported_features
			data[__supported_features.tag] = service
			
			var __supported_environments_default: Array[String] = []
			__supported_environments = PBField.new("supported_environments", PB_DATA_TYPE.STRING, PB_RULE.REPEATED, 2, true, __supported_environments_default)
			service = PBServiceField.new()
			service.field = __supported_environments
			data[__supported_environments.tag] = service
			
		var data = {}
		
		var __supported_features: PBField
		func get_supported_features() -> Array[String]:
			return __supported_features.value
		func clear_supported_features() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			__supported_features.value.clear()
		func add_supported_features(value : String) -> void:
			__supported_features.value.append(value)
		
		var __supported_environments: PBField
		func get_supported_environments() -> Array[String]:
			return __supported_environments.value
		func clear_supported_environments() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			__supported_environments.value.clear()
		func add_supported_environments(value : String) -> void:
			__supported_environments.value.append(value)
		
		func _to_string() -> String:
			return PBPacker.message_to_string(data)
			
		func to_bytes() -> PackedByteArray:
			return PBPacker.pack_message(data)
			
		func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
			var cur_limit = bytes.size()
			if limit != -1:
				cur_limit = limit
			var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
			if result == cur_limit:
				if PBPacker.check_required(data):
					if limit == -1:
						return PB_ERR.NO_ERRORS
				else:
					return PB_ERR.REQUIRED_FIELDS
			elif limit == -1 && result > 0:
				return PB_ERR.PARSE_INCOMPLETE
			return result
		
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RECHandshakeAck:
	func _init():
		var service
		
		__session_id = PBField.new("session_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __session_id
		data[__session_id.tag] = service
		
		__server_tick = PBField.new("server_tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __server_tick
		data[__server_tick.tag] = service
		
		__server_time = PBField.new("server_time", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __server_time
		data[__server_time.tag] = service
		
	var data = {}
	
	var __session_id: PBField
	func has_session_id() -> bool:
		if __session_id.value != null:
			return true
		return false
	func get_session_id() -> int:
		return __session_id.value
	func clear_session_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__session_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_session_id(value : int) -> void:
		__session_id.value = value
	
	var __server_tick: PBField
	func has_server_tick() -> bool:
		if __server_tick.value != null:
			return true
		return false
	func get_server_tick() -> int:
		return __server_tick.value
	func clear_server_tick() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__server_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_server_tick(value : int) -> void:
		__server_tick.value = value
	
	var __server_time: PBField
	func has_server_time() -> bool:
		if __server_time.value != null:
			return true
		return false
	func get_server_time() -> int:
		return __server_time.value
	func clear_server_time() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__server_time.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_server_time(value : int) -> void:
		__server_time.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RECRegisterSession:
	func _init():
		var service
		
		__ubc_session_id = PBField.new("ubc_session_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __ubc_session_id
		data[__ubc_session_id.tag] = service
		
		__uec_session_id = PBField.new("uec_session_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __uec_session_id
		data[__uec_session_id.tag] = service
		
	var data = {}
	
	var __ubc_session_id: PBField
	func has_ubc_session_id() -> bool:
		if __ubc_session_id.value != null:
			return true
		return false
	func get_ubc_session_id() -> int:
		return __ubc_session_id.value
	func clear_ubc_session_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ubc_session_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_ubc_session_id(value : int) -> void:
		__ubc_session_id.value = value
	
	var __uec_session_id: PBField
	func has_uec_session_id() -> bool:
		if __uec_session_id.value != null:
			return true
		return false
	func get_uec_session_id() -> int:
		return __uec_session_id.value
	func clear_uec_session_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__uec_session_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_uec_session_id(value : int) -> void:
		__uec_session_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RECSessionClose:
	func _init():
		var service
		
		__reason = PBField.new("reason", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __reason
		data[__reason.tag] = service
		
		__msg = PBField.new("msg", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __msg
		data[__msg.tag] = service
		
	var data = {}
	
	var __reason: PBField
	func has_reason() -> bool:
		if __reason.value != null:
			return true
		return false
	func get_reason():
		return __reason.value
	func clear_reason() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__reason.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_reason(value) -> void:
		__reason.value = value
	
	var __msg: PBField
	func has_msg() -> bool:
		if __msg.value != null:
			return true
		return false
	func get_msg() -> String:
		return __msg.value
	func clear_msg() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__msg.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_msg(value : String) -> void:
		__msg.value = value
	
	enum Reason {
		UNKNOWN = 0,
		TIMEOUT = 1,
		VERSION_MISMATCH = 2,
		VERIFICATION_FAILED = 3,
		INCOMPATIBLE_FEATURES = 4,
		PROTOCOL_ERROR = 5,
		DISCONNECTED = 6,
		SERVER_SHUTDOWN = 7
	}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RECEvent:
	func _init():
		var service
		
		__event_type = PBField.new("event_type", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __event_type
		data[__event_type.tag] = service
		
		__source_device = PBField.new("source_device", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __source_device
		data[__source_device.tag] = service
		
		__data = PBField.new("data", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __data
		data[__data.tag] = service
		
	var data = {}
	
	var __event_type: PBField
	func has_event_type() -> bool:
		if __event_type.value != null:
			return true
		return false
	func get_event_type() -> int:
		return __event_type.value
	func clear_event_type() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__event_type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_event_type(value : int) -> void:
		__event_type.value = value
	
	var __source_device: PBField
	func has_source_device() -> bool:
		if __source_device.value != null:
			return true
		return false
	func get_source_device() -> int:
		return __source_device.value
	func clear_source_device() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__source_device.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_source_device(value : int) -> void:
		__source_device.value = value
	
	var __data: PBField
	func has_data() -> bool:
		if __data.value != null:
			return true
		return false
	func get_data() -> PackedByteArray:
		return __data.value
	func clear_data() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_data(value : PackedByteArray) -> void:
		__data.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RECInteraction:
	func _init():
		var service
		
		__interaction_id = PBField.new("interaction_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __interaction_id
		data[__interaction_id.tag] = service
		
		__interaction_type = PBField.new("interaction_type", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __interaction_type
		data[__interaction_type.tag] = service
		
		__target_device = PBField.new("target_device", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __target_device
		data[__target_device.tag] = service
		
		__data = PBField.new("data", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __data
		data[__data.tag] = service
		
	var data = {}
	
	var __interaction_id: PBField
	func has_interaction_id() -> bool:
		if __interaction_id.value != null:
			return true
		return false
	func get_interaction_id() -> int:
		return __interaction_id.value
	func clear_interaction_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__interaction_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_interaction_id(value : int) -> void:
		__interaction_id.value = value
	
	var __interaction_type: PBField
	func has_interaction_type() -> bool:
		if __interaction_type.value != null:
			return true
		return false
	func get_interaction_type() -> int:
		return __interaction_type.value
	func clear_interaction_type() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__interaction_type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_interaction_type(value : int) -> void:
		__interaction_type.value = value
	
	var __target_device: PBField
	func has_target_device() -> bool:
		if __target_device.value != null:
			return true
		return false
	func get_target_device() -> int:
		return __target_device.value
	func clear_target_device() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__target_device.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_target_device(value : int) -> void:
		__target_device.value = value
	
	var __data: PBField
	func has_data() -> bool:
		if __data.value != null:
			return true
		return false
	func get_data() -> PackedByteArray:
		return __data.value
	func clear_data() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_data(value : PackedByteArray) -> void:
		__data.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RECInteractionAck:
	func _init():
		var service
		
		__interaction_id = PBField.new("interaction_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __interaction_id
		data[__interaction_id.tag] = service
		
		__success = PBField.new("success", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __success
		data[__success.tag] = service
		
		__result_data = PBField.new("result_data", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __result_data
		data[__result_data.tag] = service
		
	var data = {}
	
	var __interaction_id: PBField
	func has_interaction_id() -> bool:
		if __interaction_id.value != null:
			return true
		return false
	func get_interaction_id() -> int:
		return __interaction_id.value
	func clear_interaction_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__interaction_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_interaction_id(value : int) -> void:
		__interaction_id.value = value
	
	var __success: PBField
	func has_success() -> bool:
		if __success.value != null:
			return true
		return false
	func get_success() -> bool:
		return __success.value
	func clear_success() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_success(value : bool) -> void:
		__success.value = value
	
	var __result_data: PBField
	func has_result_data() -> bool:
		if __result_data.value != null:
			return true
		return false
	func get_result_data() -> PackedByteArray:
		return __result_data.value
	func clear_result_data() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__result_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_result_data(value : PackedByteArray) -> void:
		__result_data.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Header:
	func _init():
		var service
		
		__magic_number = PBField.new("magic_number", PB_DATA_TYPE.FIXED32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FIXED32])
		service = PBServiceField.new()
		service.field = __magic_number
		data[__magic_number.tag] = service
		
		__protocol_version = PBField.new("protocol_version", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __protocol_version
		data[__protocol_version.tag] = service
		
		__flags = PBField.new("flags", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __flags
		data[__flags.tag] = service
		
	var data = {}
	
	var __magic_number: PBField
	func has_magic_number() -> bool:
		if __magic_number.value != null:
			return true
		return false
	func get_magic_number() -> int:
		return __magic_number.value
	func clear_magic_number() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__magic_number.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FIXED32]
	func set_magic_number(value : int) -> void:
		__magic_number.value = value
	
	var __protocol_version: PBField
	func has_protocol_version() -> bool:
		if __protocol_version.value != null:
			return true
		return false
	func get_protocol_version() -> int:
		return __protocol_version.value
	func clear_protocol_version() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__protocol_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_protocol_version(value : int) -> void:
		__protocol_version.value = value
	
	var __flags: PBField
	func has_flags() -> bool:
		if __flags.value != null:
			return true
		return false
	func get_flags() -> int:
		return __flags.value
	func clear_flags() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__flags.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_flags(value : int) -> void:
		__flags.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
################ USER DATA END #################
