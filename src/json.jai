
//------------------------------------------------------------------------------
//
// Helpers
//
//------------------------------------------------------------------------------



//------------------------------------------------------------------------------
//
// JSON_Any with some utils
//
//------------------------------------------------------------------------------

JSON_Any :: struct
{
	type: JSON_Any_Type = .NULL; // u8
	union {
		boolean : bool;
		number  : float64;
		str     : string;
		array   : [..]JSON_Any;
		object  : *JSON_Object;
	};
#place boolean;
	b: bool = ---;
#place number;
	n: float64 = ---;
#place str;
	s: string = ---;
#place array;
	a: [..]JSON_Any = ---;
#place object;
	o: *JSON_Object = ---;
}

JSON_Any_Type :: enum u8
{
	NULL    :: 0;
	BOOLEAN :: 1;
	NUMBER  :: 2;
	STRING  :: 3;
	ARRAY   :: 4;
	OBJECT  :: 5;
}

JSON_Object :: Table(string, JSON_Any);

json_deep_copy :: (target: *JSON_Any, source: JSON_Any)
{
	assert(false, "Not implemented!");
}

json_copy :: (source: JSON_Any) -> JSON_Any
{
	result: JSON_Any;
	JSON_copy(*result, source);
	return result; 
}

json_copy :: (target: *JSON_Any, source: JSON_Any)
{
	if source.type == {
		case .STRING;
		target.type = .STRING;
			target.str = copy_string(source.str);
		case .NULL;
		case .NUMBER;
		case .BOOLEAN;
			target.* = source;
		case;
			print("type: %\n", source.type);
			assert(false, "Not implemented!");
	}
}

json_release :: (any: *JSON_Any)
{
	if any.type == {
		case .STRING;
		{
			free(any.str);
		}
		case .ARRAY;
		{
			for * elem : any.array
				json_release(elem);
			array_free(any.array);
		}
		case .OBJECT;
		{
			for any.object.entries
			{
				free(it.key);
				json_release(*it.value);
			}
			deinit(any.object);
			any.object = null;
		}
		case;
			// stack
	}
}

//
// TODO: this should be able to handle chained keys:
//       ex: JSON_find(*value, "field.sub_field.sub_sub_field");
json_find :: (value: JSON_Any, key: string) -> *JSON_Any
{
	if value.type == .OBJECT
	{
		return table_find_pointer(value.object, key);
	}
	return null;
}

//------------------------------------------------------------------------------
//
// Serialization
//
//------------------------------------------------------------------------------

// JSON Serializer, uses an internal buffer to accumulate strings
// Most of its procedures can be replaced by assigning a custom procedure.
JSON_Serializer :: struct
{	
	output_sb  : String_Builder;
	prettify   := false; // when true, insert spaces/tabs/newlines

	// overridable procedures:

	serialize          := json_serialize;
	serialize_null     := json_serialize_null;
	serialize_bool     := json_serialize_bool;
	serialize_integer  := json_serialize_integer;
	serialize_float    := json_serialize_float;
	serialize_string   := json_serialize_string;
	serialize_table    := json_serialize_table;
	serialize_value    := json_serialize_value;
	serialize_struct   := json_serialize_struct;
	serialize_JSON_Any := json_serialize_JSON_Any;
	serialize_array    := json_serialize_array;
	serialize_enum     := json_serialize_enum;
}

json_init :: (using serializer: *JSON_Serializer)
{
	init_string_builder(*output_sb);
}

json_release :: (using serializer: *JSON_Serializer)
{
	reset(*output_sb);
}

json_serialize_JSON_Any :: (using serializer: *JSON_Serializer, out_data: *void) -> bool
{
	return generic_serialize_JSON_Any(serializer, out_data);
}

json_serialize_null :: (using serializer: *JSON_Serializer) -> success: bool
{
	return json_serialize_formatted_string(serializer, "null");
}

json_serialize_bool :: (using serializer: *JSON_Serializer, data: bool) -> success: bool
{
	return json_serialize_formatted_string(serializer, ifx data "true" else "false");
}

json_serialize_integer :: (using serializer: *JSON_Serializer, data: s64) -> success: bool
{
	return json_serialize_formatted_string(serializer, "%", data);
}

json_serialize_float :: (using serializer: *JSON_Serializer, data: float64) -> success: bool
{
	return json_serialize_formatted_string(serializer, "%", data);
}

json_serialize_string :: (using serializer: *JSON_Serializer, data: string) -> success: bool
{
	return json_serialize_formatted_string(serializer, "\"%\"", data);
}

json_serialize_table :: (using serializer: *JSON_Serializer, data: *void, data_ti: *Type_Info_Struct) -> success: bool
{
	if data_ti == {
		// some common Table types
		case type_info(Table(string, string));  return json_serialize_table_T(serializer, cast(*Table(string, string))data);
		case type_info(Table(string, bool));    return json_serialize_table_T(serializer, cast(*Table(string, bool))data);
		case type_info(Table(string, u8));      return json_serialize_table_T(serializer, cast(*Table(string, u8))data);
		case type_info(Table(string, u16));     return json_serialize_table_T(serializer, cast(*Table(string, u16))data);
		case type_info(Table(string, u32));     return json_serialize_table_T(serializer, cast(*Table(string, u32))data);
		case type_info(Table(string, u64));     return json_serialize_table_T(serializer, cast(*Table(string, u64))data);
		case type_info(Table(string, s8));      return json_serialize_table_T(serializer, cast(*Table(string, s8))data);
		case type_info(Table(string, s16));     return json_serialize_table_T(serializer, cast(*Table(string, s16))data);
		case type_info(Table(string, s32));     return json_serialize_table_T(serializer, cast(*Table(string, s32))data);
		case type_info(Table(string, s64));     return json_serialize_table_T(serializer, cast(*Table(string, s64))data);
		case type_info(Table(string, float32)); return json_serialize_table_T(serializer, cast(*Table(string, float32))data);
		case type_info(Table(string, float64)); return json_serialize_table_T(serializer, cast(*Table(string, float64))data);
		case type_info(Table(string, JSON_Any));return json_serialize_table_T(serializer, cast(*Table(string, JSON_Any))data);
	}

	return false;
}

json_serialize_table_T :: (using serializer: *JSON_Serializer, table: *$T/Table) -> success: bool
{
	json_serialize_formatted_string(serializer, "{");

	item_count := 0;

	for * entry : table.entries
	{
		if entry.key == "" continue; // TODO: I had to filter entry based on non-empty keys, otherwise I got many keyval with empty key and null value, I have to investigate the serializer.

		if item_count != 0
			json_serialize_formatted_string(serializer, ",");

		if !serialize_value(serializer, *entry.key, type_info(T.Key_Type))
			return false;

		json_serialize_formatted_string(serializer, ":");

		if !serialize_value(serializer, *entry.value, type_info(T.Value_Type))
			return false;

		item_count += 1;
	}

	json_serialize_formatted_string(serializer, "}");

	return true;
}

json_serialize_array :: (using serializer: *JSON_Serializer, array_addr: *void, data_ti: *Type_Info_Array) -> success: bool
{
	assert(data_ti.array_type != .FIXED, "not implemented yet");

	json_serialize_formatted_string(serializer, "[");

	base_addr : *u8 = ifx data_ti.array_type == .FIXED then xx array_addr       else (cast(*[]u8)array_addr).data;
	count     : s64 = ifx data_ti.array_type == .FIXED then data_ti.array_count else (cast(*[]u8)array_addr).count;

	for i : 0..count-1
	{
		if i != 0 json_serialize_formatted_string(serializer, ",");

		if !serialize_value(serializer, base_addr + i * data_ti.element_type.runtime_size, type_info(JSON_Any))
			return false;
	}
	json_serialize_formatted_string(serializer, "]");

	return true;
}

json_serialize_struct :: (using serializer: *JSON_Serializer, data: *void, ti: *Type_Info_Struct) -> success: bool
{
	if ti == type_info(JSON_Any)
	{
		return json_serialize_JSON_Any(serializer, data);
	}

	if ti.name == "Table"
	{
		if ti == {
			case type_info(Table(string, JSON_Any)); return json_serialize_table_T(serializer, cast(*Table(string, JSON_Any))data );
			case; assert(false, "Not handled yet");
		}
	}

	json_serialize_formatted_string(serializer, "{");

	member_index := 0;
	for it: ti.members
	{
		if member_index != 0
		{
			json_serialize_formatted_string(serializer, ",");
		}

		if it.offset_into_constant_storage >= 0
		{
			debug_print("offset_into_constant_storage is not handled yet\n");
			continue;
		}

		// key
		key := it.name;
		if !serialize_string(serializer, key)
		{
			print("Unable to serialize key: \"%\"\n", key);
			return false;
		}

		// separator
		json_serialize_formatted_string(serializer, ":");

		// value
		member_addr := (cast(*u8)data) + it.offset_in_bytes;
		if !serialize_value(serializer, member_addr, it.type)
		{
			print("Unable to serialize member: %\n", key);
			return false;
		}

		member_index += 1;
	}

	json_serialize_formatted_string(serializer, "}");

	return true;
}

json_serialize_enum :: (using serializer: *JSON_Serializer, data: *void, data_ti: *Type_Info_Enum) -> success: bool
{
	// For now we serialize the name, more readable in JSON.
	name := data_ti.names[(cast(*u32)data).*];
	return serialize_string(serializer, name);
}

json_serialize_value :: (using serializer: *JSON_Serializer, data: *void, data_ti: *Type_Info) -> success: bool
{
	if data_ti.type == {
		case .BOOL;    return serialize_bool(serializer, (cast(*bool)data).* );
		case .INTEGER; return serialize_integer(serializer, (cast(*s32)data).*);
		case .FLOAT;   return serialize_float(serializer, (cast(*float64)data).*);
		case .STRING;  return serialize_string(serializer, (cast(*string)data).* );
		case .ARRAY;   return serialize_array(serializer, data, xx data_ti);
		case .STRUCT;  return serialize_struct(serializer, data, xx data_ti);
		case .ENUM;    return serialize_enum(serializer, data, xx data_ti);
		
		// skip
		case .PROCEDURE; return true;
		case .POINTER;   return true;
	}
	assert(false, "Unhandled case! %\n", data_ti.type);
	return false;
}

json_serialize :: (using serializer: *JSON_Serializer, data: *void, ti: *Type_Info) -> result: string
{
	ok := serialize_value(serializer, data, ti);
	result := builder_to_string(*output_sb,, allocator = temp);
	assert(ok); // asserts after print
	return result;
}

json_serialize_formatted_string :: (using serializer: *JSON_Serializer, format_string : string, args: .. Any) -> bool
{
	return print_to_builder(*output_sb, format_string, ..args);
}

//------------------------------------------------------------------------------
//
// Parsing
//
//------------------------------------------------------------------------------

JSON_Parser :: struct
{	
	#as using _parser: Parser;

	// data

	separator    = ",";      
	kv_separator = ":";

	input_text : string; // owned, input is always copied when parsing begins
	remainer   : string;
	messages   : [..]Parser_Message;

	// non-pure

	get_remainer             = (parser: *Parser) -> *string { return *(cast(*JSON_Parser)parser).remainer; };
	reset                    = (parser: *Parser, input: string) -> bool { return json_reset(xx parser, input); };
	parse_begin              = (parser: *Parser, ti: *Type_Info, data: *void) -> bool { return json_parse_begin(xx parser, ti, data); };
	parse_end                = (parser: *Parser, ti: *Type_Info, data: *void) -> bool { return json_parse_end(xx parser, ti, data); };
	parse_value              = generic_parse_value;
	parse_object_begin       = (parser: *Parser, tis: *Type_Info_Struct, data: *void) -> bool { return json_parse_object_begin(xx parser, tis, data); };
	parse_object_body        = generic_parse_object_body;
	parse_object_end         = (parser: *Parser, tis: *Type_Info_Struct, data: *void) -> bool { return json_parse_object_end(xx parser, tis, data); };	
	parse_object_member      = (parser: *Parser, tis: *Type_Info_Struct, data: *void, index: s64) -> bool { return json_parse_object_member(xx parser, tis, data, index); }
	parse_table_body         = (parser: *Parser, tis: *Type_Info_Struct, data: *void) -> bool { return generic_parse_table_body(parser, tis, data); };
	parse_array_begin        = (parser: *Parser, tia: *Type_Info_Array, data: *void) -> bool { return json_parse_array_begin(xx parser, tia, data); }
	parse_array_body         = (parser: *Parser, tia: *Type_Info_Array, data: *void) -> bool { return generic_parse_array_body(parser, tia, data); }
	parse_array_end          = (parser: *Parser, tia: *Type_Info_Array, data: *void) -> bool { return json_parse_array_end(xx parser, tia, data); }
	error                    = (parser: *Parser, string_format: string, args: ..Any, location := #caller_location) -> bool { return json_error(xx parser, string_format, ..args, location); };
      
    // pure

	parse_integer            = generic_parse_integer;
	parse_float              = generic_parse_float;    
	parse_string             = generic_parse_string;   
	parse_bool               = generic_parse_bool;     
	parse_null               = generic_parse_null; 
}

json_init :: (using parser: *JSON_Parser, $reset_procedures := false)
{
	#if reset_procedures
	{
		parser.* = .{}; // This would reset the custom procedures user could have assigned.
	}

	input_text = "";
	remainer   = input_text;
}

json_reset :: (using parser : *JSON_Parser, source: string) -> bool
{	
	if input_text.count != 0
	{
		free(parser.input_text);
	}

	input_text = copy_string(source); // since we keep this internally, we copy. We don't want it to change or be dellocated while parsing.
	remainer   = input_text;
	
	// note: array_reset free memory, but we don't want that here. Let's save an alloc.
	messages.count = 0; // message's strings are allocated using temp

	return true;
}

json_release :: (parser: *JSON_Parser)
{
	free(parser.input_text); // was copied, see JSON_init_parser(...)

	// note: array_reset free memory (which is something that might change, table_reset does not for example)
	array_reset(*parser.messages); // message's strings are allocated using temp
}

make_report :: (parser : *JSON_Parser) -> Parser_Report
{
	push_allocator(temp);

	// make report from state
	report: Parser_Report;
	report.input_text = parser.input_text;

	for message : parser.messages
	{
		if message.type == .ERROR
		{
			array_add(*report.errors, copy_message(message));
		}
	}

	return report;
}

json_parse_null :: (in_text: *string) -> bool
{
 	return generic_parse_exact_word(in_text, "null");
}

json_parse_object_begin :: (parser: *JSON_Parser, tis: *Type_Info_Struct, out_data: *void) -> success : bool
{
	eat_spaces(*parser.remainer);
	return eat_char(*parser.remainer, #char "{");
}

json_parse_object_end :: (parser: *JSON_Parser, tis: *Type_Info_Struct, out_data: *void) -> success : bool
{
	eat_spaces(*parser.remainer);
	return eat_char(*parser.remainer, #char "}");
}

json_parse_array_begin :: (parser: *JSON_Parser, tia: *Type_Info_Array, data: *void) -> success: bool
{
	eat_spaces(*parser.remainer);
	return eat_char(*parser.remainer, #char "[");
}

json_parse_array_end :: (parser: *JSON_Parser, tia: *Type_Info_Array, data: *void) -> success: bool
{
	eat_spaces(*parser.remainer);
	return eat_char(*parser.remainer, #char "]");
}

json_parse_object_T :: (parser: *JSON_Parser, out_data: *$T) -> bool
{
	return parser.parse_object(parser, type_info(T), out_data);
}

json_parse_separator :: (in_text: *string) -> success: bool
{
	eat_spaces(in_text);
	return eat_char(in_text, #char ",");
}

json_parse_kv_separator :: (in_text: *string) -> success: bool
{
	eat_spaces(in_text);
	return eat_char(in_text, #char ":");
}

json_parse_begin :: (using parser : *JSON_Parser, ti: *Type_Info, data: *void) -> success: bool
{
	debug_print("______________________________________________________________\n");
	debug_print("\n");
	debug_print(" json_parse_begin() - Parsing json: '%'\n", input_text);
	debug_print("\n");

	return true; // no reason to fail for now...
}

json_parse_end :: (using parser: *JSON_Parser, ti: *Type_Info, data: *void) -> success: bool
{
	eat_spaces(*remainer);

	if remainer.count
	{
		return error(parser, "Could not parse further");
	}
	
	debug_print("json_parse_end()\n");
	
	return true;
}

json_parse_table_T :: (using parser: *JSON_Parser, out_data: *Table) -> success: bool
{
	return parse_table_begin(parser)
		&& parse_table_body_template(parser, out_data)
		&& parse_table_end(parser);
}

json_error :: (using parser: *JSON_Parser, string_format: string, args: ..Any, location : Source_Code_Location = #caller_location) -> bool
{
	array_add(*messages, Parser_Message.{ .ERROR, tprint(string_format, ..args), remainer.data, location } );
	return false;
}

json_parse_object_member :: (using parser: *JSON_Parser, tis: *Type_Info_Struct, out_data: *void, index: s64) -> bool
{
	if index > 0 && !json_parse_separator(*remainer)
	{
		debug_print("Expecting a separator after key #%\n", index);
		return false;
	}

	key: string;
	if !parse_string(*key, *remainer,, allocator=temp)
	{
		return false;
	}

	if !generic_parse_exact_word(*remainer, ":")
	{
		return error(parser, "Expecting a keyvalue separator");
	}

	member, offset_in_bytes := get_field(tis, key);
	
	if member == null
	{
		return error(parser, "Unable to find field '%1' in struct '%2'", key, tis.name);
	}

	assert(offset_in_bytes >= 0, "Constants not handled, we should probably skip what's next. But no time to think about it now.");

	member_data: *void = (cast(*u8)out_data) + offset_in_bytes;

	debug_print("parsing struct member %.% (%)...\n", tis.name, key, member.type.*);

	init_data_with_type(member_data, member.type);

	if !parse_value(parser, member.type, member_data)
	{
		return error(parser, "Failed to parse %1's value (type: %2)\n", member.name, member.type.type);
	}

	return true;
}
