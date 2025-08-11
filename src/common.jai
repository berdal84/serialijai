
//
// Parser interface, see XML_Parser/JSON_Parser implementations
//

Parser :: struct
{	
	// data

	separator    : string;
	kv_separator : string;

	// procedures using Parser's state

	get_remainer       : #type (parser: *Parser) -> *string;
	reset              : #type (parser: *Parser, input: string) -> bool;
	parse_value        : #type (parser: *Parser, ti: *Type_Info, data: *void) -> bool;
	parse_begin        : #type (parser: *Parser, ti: *Type_Info, data: *void) -> bool;
    parse_end          : #type (parser: *Parser, ti: *Type_Info, data: *void) -> bool;
    parse_object       : #type (parser: *Parser, tis: *Type_Info_Struct, data: *void) -> bool;
    parse_object_begin : #type (parser: *Parser, tis: *Type_Info_Struct, data: *void) -> bool;
    parse_object_body  : #type (parser: *Parser, tis: *Type_Info_Struct, data: *void) -> bool;
    parse_object_end   : #type (parser: *Parser, tis: *Type_Info_Struct, data: *void) -> bool;
	parse_table_body   : #type (parser: *Parser, tis: *Type_Info_Struct, data: *void) -> bool;      
	parse_array_begin  : #type (parser: *Parser, tia: *Type_Info_Array, data: *void) -> bool;
	parse_array_body   : #type (parser: *Parser, tia: *Type_Info_Array, data: *void) -> bool;
	parse_array_end    : #type (parser: *Parser, tia: *Type_Info_Array, data: *void) -> bool;   
	error              : #type (parser: *Parser, format_string: string, args: ..Any, location := #caller_location) -> bool;

	// pure  procedures

	parse_integer      : #type (info_integer: *Type_Info_Integer, out_data: *void, in_text: *string) -> bool;
	parse_float        : #type (info_float: *Type_Info_Float, out_data: *void, in_text: *string) -> bool;   
	parse_string       : #type (out_data: *string, in_text: *string) -> bool;   
	parse_bool         : #type (out_data: *bool, in_text: *string) -> bool ;     
	parse_null         : #type (in_text: *string) -> bool;  
}

//
// Some generic procedures
//


parse :: (using parser: *Parser, out_data: *$T, input: string) -> success: bool
{
	return generic_parse(parser, type_info(T), out_data, input);
}

parse_file :: (using parser: *Parser, out_data: *$T, file_path: string) -> success: bool
{
	content, file_read := read_entire_file(file_path, log_errors=true);
	defer free(content);
	if !file_read
	{
		print("Unable to file '%'\n", file_path);
		return false;
	}
	return generic_parse(parser, type_info(T), out_data, content);
}

serialize :: (using serializer: *$Serializer_T, data: *$T) -> json: string
{
	input_ti := type_info(T);
	return serialize(serializer, data, input_ti);
}

serialize :: (using serializer: *$Serializer_T, data: *void, input_ti: *Type_Info) -> json: string
{
	return serialize(serializer, data, input_ti);
}

generic_parse :: (using parser: *Parser, ti: *Type_Info, out_data: *void, input: string) -> bool
{
	if !reset(parser, input)
		return error(parser, "Unable to reset parser\n");
	if !parse_begin(parser, ti, out_data)
		return error(parser, "Unable to begin %\n", tprint_type(ti) );
	if !parse_value(parser, ti, out_data)
		return error(parser, "Unable to parse %'s value\n", tprint_type(ti) );
	if !parse_end(parser, ti, out_data)
		return error(parser, "Unable to end %\n", tprint_type(ti) );
	return true;
}

generic_parse_object :: (using parser: *Parser, tis: *Type_Info_Struct, out_data: *void) -> bool
{
	if !parse_object_begin(parser, tis, out_data)
	{
		return false;
	}

	if tis.name == "Table"
	{
		if !parse_table_body(parser, tis, out_data)
		{
			return error(parser, "Unable to parse table body (type: %)\n", tprint_type(tis));
		}
	}
	else
	{
		if !parse_object_body(parser, tis, out_data)
		{
			return error(parser, "Unable to parse object body (type: %)\n", tprint_type(tis));
		}
	}

	if !parse_object_end(parser, tis, out_data)
	{
		return error(parser, "Unable to parse object end (type: %)\n", tprint_type(tis));
	}

	return true;
}


generic_parse_value :: (using parser: *Parser, ti: *Type_Info, out_data: *void) -> success: bool
{
	debug_print("generic_parse_value (%) ...\n", tprint_type(ti));
	defer debug_print("generic_parse_value (%) DONE\n", tprint_type(ti));

	remainer := get_remainer(parser);

	if ti.type == {
	    
	    case .INTEGER; return parse_integer(xx ti, out_data, remainer);
	    case .FLOAT;   return parse_float(xx ti, out_data, remainer);
	    case .BOOL;    return parse_bool(xx out_data, remainer);
	    case .STRING;  return parse_string(xx out_data, remainer );
	    case .ARRAY;   return generic_parse_array(parser, xx ti, out_data);
	    case .STRUCT;  return parse_object(parser, xx ti, out_data);

	    // case .POINTER;
	    // case .PROCEDURE;
	    // case .VOID;
	    // case .OVERLOAD_SET;
	    // case .ANY;
	    // case .ENUM;
	    // case .POLYMORPHIC_VARIABLE;
	    // case .TYPE;
	    // case .CODE;
	    // case .UNTYPED_LITERAL;
	    // case .UNTYPED_ENUM;
	    // case .VARIANT;
	    case; return error(parser, "Unhandled type: %", tprint_type(ti) );
	}
}

generic_parse_array :: (using parser: *Parser, tia: *Type_Info_Array, out_data: *void) -> bool
{
	if !parse_array_begin(parser, tia, out_data)
		return false;

	if !parse_array_body(parser, tia, out_data)
		return false;

	return parse_array_end(parser, tia, out_data);
}

generic_parse_array_T :: (using parser: *Parser, out_data: *$Array_T) -> bool
{
	return generic_parse_array(parser, type_info(Array_T), out_data);
}


generic_parse_array_body :: (using parser: *Parser, info_array: *Type_Info_Array, out_data: *void) -> bool
{
	if #complete info_array.array_type ==
	{
		case .FIXED;     return generic_parse_array_body_T(parser, out_data, info_array, .FIXED);
		case .RESIZABLE; return generic_parse_array_body_T(parser, out_data, info_array, .RESIZABLE);
		case .VIEW;      return error(parser, "array_type == .VIEW is not handled!");
	}
}

generic_parse_array_body_T :: (
	using parser: *Parser,
	out_array:    *void,
	ti_array:     *Type_Info_Array,		
	$array_type:  Type_Info_Array.Array_Type
	) -> success: bool
{
	elem_size := ti_array.element_type.runtime_size;
	next_id   := 0;

	assert(array_type != .VIEW, "array_type .VIEW is not supported, please provide a resizable array.");

	remainer := get_remainer(parser);
	while( remainer.count )
	{
		#if array_type == .FIXED
		{
			if next_id == ti_array.array_count
			{
				debug_print("-- fixed array end-bound reached (count: %)\n", ti_array.array_count);
				break;
			}
		}

		ate_separator := next_id && generic_parse_exact_word(remainer, separator);
		
		if next_id && !ate_separator
		{
			debug_print("-- no more elements to parse (next_id: %)\n", next_id);
			break;
		}
		else
		{
			debug_print("-- try to parse element with id %\n", next_id);
		}

		// reserve space for next element
		#if array_type == {

			// not handled!
			case .VIEW;
			{
				assert(false);
			}

			case .RESIZABLE;
			{
				array_reserve(cast(*Resizable_Array) out_array, next_id + 1 , elem_size );
			}
		}


		// get element's pointer

		out_array_data : *void = ifx array_type == .FIXED then out_array
			                                         else (cast(*Resizable_Array)out_array).data;

		el_ptr : *void = ((cast(*u8)out_array_data)) + (next_id * elem_size);

		// initialize the element

		init_data_with_type(el_ptr, ti_array.element_type);

		// parse element's value

		remainer_backup := remainer;
		if !parse_value(parser, ti_array.element_type, el_ptr)
		{
			remainer.* = remainer_backup.*;

			if ate_separator
				return error(parser, remainer.*, "Expecting value");
			break;
		}

		debug_print("-- parsed array element with id %\n", next_id );

		next_id += 1;						
	}

	// Update array data/count based on array type
	#if array_type == {

		case .FIXED;
		{
			// count is fixed, and data was written inplace.
		}

		//case .VIEW; not handled
		//{
			//out_array := (cast(*[..]u8)out_data);
			// assign temporary array to our view, temp_array is allocated with temp allocator
			//out_array.count = next_id;
			//out_array.data  = temp_array.data;
		//}

		case .RESIZABLE;
		{
			// data was written inplace, but count needs to be updated
			(cast(*[..]u8)out_array).count = next_id;
		}

	}

	return true;
}

generic_parse_table_T:: (using parser: *Parser, out_data: *$T/Table) -> success: bool
{
	tis := type_info(T);

	if !parse_object_begin(parser, tis, out_data)
	{
		return false;
	}
	
	if !generic_parse_table_body_T(parser, out_data)
	{
		return false;
	}

	return parse_object_end(parser, tis, out_data);
}

generic_parse_table:: (using parser: *Parser, tis:* Type_Info_Struct, out_data: *void) -> success: bool
{
	if !parse_object_begin(parser, tis, out_data)
	{
		return false;
	}
	
	if !parse_table_body(parser, tis, out_data)
	{
		return false;
	}

	return parse_object_end(parser, tis, out_data);
}

generic_parse_table_body:: (using parser: *Parser, info_struct: *Type_Info_Struct, out_data: *void) -> (success: bool)
{
	if info_struct == {
		// some common Table types
		case type_info(Table(string, string));  return generic_parse_table_body_T(parser, cast(*Table(string, string))out_data);
		case type_info(Table(string, bool));    return generic_parse_table_body_T(parser, cast(*Table(string, bool))out_data);
		case type_info(Table(string, u8));      return generic_parse_table_body_T(parser, cast(*Table(string, u8))out_data);
		case type_info(Table(string, u16));     return generic_parse_table_body_T(parser, cast(*Table(string, u16))out_data);
		case type_info(Table(string, u32));     return generic_parse_table_body_T(parser, cast(*Table(string, u32))out_data);
		case type_info(Table(string, u64));     return generic_parse_table_body_T(parser, cast(*Table(string, u64))out_data);
		case type_info(Table(string, s8));      return generic_parse_table_body_T(parser, cast(*Table(string, s8))out_data);
		case type_info(Table(string, s16));     return generic_parse_table_body_T(parser, cast(*Table(string, s16))out_data);
		case type_info(Table(string, s32));     return generic_parse_table_body_T(parser, cast(*Table(string, s32))out_data);
		case type_info(Table(string, s64));     return generic_parse_table_body_T(parser, cast(*Table(string, s64))out_data);
		case type_info(Table(string, float32)); return generic_parse_table_body_T(parser, cast(*Table(string, float32))out_data);
		case type_info(Table(string, float64)); return generic_parse_table_body_T(parser, cast(*Table(string, float64))out_data);
		case type_info(Table(string, JSON_Any));return generic_parse_table_body_T(parser, cast(*Table(string, JSON_Any))out_data); // even if it is weird to see this in a generic_xxx function, a JSON_Any is just a struct, we could parse it from an XML...
	}

	return false;
}

generic_parse_table_body_T :: (using parser: *Parser, out_table: *$T/Table) -> success: bool
{
	i := 0;
	remainer := get_remainer(parser);
	while ( remainer.count )
	{
		ate_comma := i && generic_parse_exact_word(remainer, separator);

		key: T.Key_Type;
		assert(T.Key_Type == string);
		if !parse_string(*key, remainer)
		{
			if ate_comma
				return error(parser, "Expecting a key after comma");				
			break;
		}

		if !generic_parse_exact_word(remainer, kv_separator)
		{
			return false;
		}

		value : T.Value_Type;

		if !parse_value(parser, type_info(T.Value_Type), *value)
		{
			return error(parser, "Unable to parse %1's value (type: %2)\n", key, T.Value_Type);
		}

		debug_print(" -- adding \"% : %\" into Table ...\n", key, value);
		table_add(out_table, key, value); // no need to copy_string(key), is is already allocated on the heap by parse_string

		i += 1;
	}

	return true;
}

generic_parse_bool :: (out_data: *bool, in_text: *string) -> success: bool
{
	eat_spaces(in_text);

	debug_print("parse_bool ...\n");
	defer debug_print("parse_bool (end)\n");

	if generic_parse_exact_word(in_text, "true")
	{
		(cast(*bool)out_data).* = true;
		return true;
	}

	if generic_parse_exact_word(in_text, "false")
	{
		(cast(*bool)out_data).* = false;
		return true;
	}

	return false;
}

generic_parse_integer :: (info_integer: *Type_Info_Integer, out_data: *void, in_text: *string) -> success: bool
{
	if info_integer.signed {
		if info_integer.runtime_size == {
    		case 1; return generic_parse_integer_T(cast(* s8) out_data, in_text);
    		case 2; return generic_parse_integer_T(cast(*s16) out_data, in_text);
    		case 4; return generic_parse_integer_T(cast(*s32) out_data, in_text);
    		case 8; return generic_parse_integer_T(cast(*s64) out_data, in_text);
    	}
	} else if info_integer.runtime_size == {
		case 1; return generic_parse_integer_T(cast(*u8 )out_data, in_text);
		case 2; return generic_parse_integer_T(cast(*u16)out_data, in_text);
		case 4; return generic_parse_integer_T(cast(*u32)out_data, in_text);
		case 8; return generic_parse_integer_T(cast(*u64)out_data, in_text);
    }
	assert(false, "Unexpected INTEGER, signed: %, runtime_size: %", info_integer.signed, info_integer.runtime_size);
	return false;
}

generic_parse_integer_T :: (out_integer: *$T, in_text: *string) -> bool
{
	info_integer :: type_info(T);

	debug_print("generic_parse_int_T (%) ...\n", T);
	defer debug_print("generic_parse_int_T (%) DONE\n", T);

	value:, success:, in_text.* = string_to_int(in_text.*, 10, T);

	if !success
	{
		return false;
	}

	debug_print("-- value = % \n", value);
	
	out_integer.* = value;

	return true;
}

generic_parse_float :: (info_float: *Type_Info_Float, out_data: *void, in_text: *string) -> success: bool
{
	if info_float.runtime_size == {
		case 4; return generic_parse_float_T(cast(*float32)out_data, in_text);
		case 8; return generic_parse_float_T(cast(*float64)out_data, in_text);
	}
	assert(false, "Unexpected FLOAT, runtime_size: %", info_float.runtime_size);
	return false;
}


generic_parse_float_T :: (out_float: *$T, in_text: *string ) -> bool
{
	eat_spaces(in_text);

	debug_print("generic_parse_float_T (%) ...\n", T);
	defer debug_print("generic_parse_float_T (%) DONE\n", T);

	result64:, success:, in_text.* = string_to_float(in_text.*);
	
	if !success
	{
		return false;
	}

	debug_print("-- value = % (parsed as float64, will be cast)\n", result64);

	out_float.* = cast(T)result64; // TODO: warns on precision loss?
	
	return true;
}	

generic_parse_string :: (out_data: *string, in_text: *string) -> bool
{
	view : string;
	if generic_parse_string_view(*view, in_text)
	{
		out_data.* = copy_string(view);
		return true;
	}
	return false;
}

generic_parse_string_view :: (out_data: *string, in_text: *string, $delimiter := #char "\"", $escape := #char "\\") -> bool
{
	assert(out_data != null);

	debug_print("generic_parse_string ...\n");
	defer debug_print("generic_parse_string (end)\n");

	eat_spaces(in_text);

	if !eat_char(in_text, delimiter)
	{
		return false;
	}

	// eat everything until we find an unescaped '"'
	begin: *u8 = in_text.data;
	current_char: *u8 = begin;
	escape_next_char := false;
	while (true)
	{
		debug_print("generic_parse_string() - Searching delimiter: % ... %\n", delimiter, string.{ data=begin, count=current_char-begin+1 } );
		if !escape_next_char && current_char.* ==  delimiter
        {
        	debug_print("generic_parse_string() - Searching delimiter: % ... FOUND at pos %\n", delimiter, current_char-begin);
        	break;
        }
		
		escape_next_char = current_char.* == escape;
        
        current_char += 1;

        if current_char == in_text.data + in_text.count
        {
        	return false;
        }
    }

    portion := slice(in_text.*, 0, current_char - begin);
	out_data.* = portion; // we return a view, see generic_parse_string.

	advance(in_text, current_char - begin + 1);

	debug_print("-- parsed string = '%'\n", out_data.*);

	return true;
}

generic_parse_null :: (in_text: *string) -> bool
{
	return generic_parse_exact_word(in_text, "null");
}

generic_parse_exact_word :: (in_text: *string, expected_word : string) -> success: bool
{
	eat_spaces(in_text); // ensure in_text starts with a non space char
	
	if in_text.count < expected_word.count
	{
		return false;
	}

	for 0..expected_word.count-1
	{
		if in_text.data[it] != expected_word[it]
		{
			return false;
		}
	}

	advance(in_text, expected_word.count);
	return true;
}

generic_serialize_JSON_Any :: (using serializer: *$T, data: *JSON_Any) -> success: bool
{
	assert(data != null);
	
	if data.type == {
		case .NULL;    return serialize_null(serializer);
		case .BOOLEAN; return serialize_bool(serializer, data.boolean);
		case .NUMBER;  return serialize_float(serializer, data.number);
		case .STRING;  return serialize_string(serializer, data.str);
		case .ARRAY;   return serialize_array(serializer, *data.array, type_info([..]JSON_Any));
		case .OBJECT;  return serialize_table(serializer, data.object, type_info(JSON_Object));
	}
	assert(false, "Unhandled case!");
	return false;
}

print_report :: (report: Parser_Report)
{
	push_allocator(temp);

	PAD      :: "   ";
	DOTS     ::     "...";
	DATA_LCOUNT :: 20;
	DATA_RCOUNT :: 20;

	for < error, i : report.errors
	{
		pos   := error.data_addr - report.input_text.data;
		
		begin := max(pos - DATA_LCOUNT, 0);
		end   := min(pos + DATA_RCOUNT, report.input_text.count);

		portion := report.input_text;
		advance(*portion, begin);
		portion.count = end-begin;
		
		portion = copy_string(portion);
		portion = replace(portion, "\n", "");

		l_pad       := "                                                      ";
		l_pad.count  = pos - begin;
		if pos != 0 then l_pad.count += DOTS.count;

		// Error message
		using error.loc;
		print("At %:%:% %\n\n", fully_pathed_filename, line_number, character_number, error.text);

		// portion (with maybe some ... before and after)
		print( PAD );
		if pos != 0 then print( DOTS );
		print(portion);
		if portion.count != report.input_text.count then print( DOTS );

		print("\n");

		// cursor to point the current character
		print("%1%2^\n", PAD, l_pad);

		print("\n\n");
	}
	print("\n");

	result := ifx report.errors.count == 0 then "Parsing done with success" else "Parsing failed";
	color  := ifx report.errors.count == 0 then Console_Color.GREEN else Console_Color.RED;
	
	print("\n");
	set_console_color(color);
	print(" >>> %", result);
	reset_console_color();

	if report.errors.count
	{
		print(" found % error(s), see above\n", report.errors.count);
		
	}
	print("\n");
}

eat_spaces :: ( text: *string, spaces := " \n\t" ) -> s64
{
	begin := text.data;
	while text.count && is_any(text.*[0], spaces)
	{
		advance(text);
	}
	return text.data - begin;
}

eat_char:: (in_text: *string, char: u8) -> bool
{
	if in_text.data[0] != char
	{
		return false;
	}

	debug_print("-- eat '%'\n", to_string(*char, 1) );

	advance(in_text);

	return true;
}

// usage: ti: *Type_Info_Struct; key_ti : *TypeInfo = get_specified_param_ti(ti, "Key_Type");
get_specified_parameter_ti :: (info: *Type_Info_Struct, specified_parameter_name: string) -> *Type_Info
{
  	if info.polymorph_source_struct == null
  		return null;

    for * it: info.specified_parameters
    {
    	if it.name == specified_parameter_name
    	{
            address: *u8;
            
            if it.offset_into_constant_storage < 0 {
                address = (cast(*u8)*context) + it.offset_in_bytes;
            } else {
                address = info.constant_storage.data + it.offset_into_constant_storage;
            }

            return (cast(**void)address).*;
    	}
    }

    return null;
}

// Initialize a piece of memory knowing its type info
init_data_with_type :: (data: *void, data_ti: *Type_Info)
{
	// Some struct may have an initializer
	if data_ti.type == .STRUCT
	{
		tis := cast(*Type_Info_Struct)data_ti;
		if (tis.initializer)
		{
			tis.initializer(data);
			return;
		}
	}

	// By default
	memset(data, 0, data_ti.runtime_size);
}

debug_print :: (string_format: string, args: ..Any) #expand
{
	#if DEBUG {
		print(string_format, ..args);;
	}
}

tprint_type :: (info: *Type_Info, print_parameters_matching_defaults := false) -> string
{
	builder: String_Builder;
	print_type_to_builder(*builder, info, print_parameters_matching_defaults);
	return builder_to_string(*builder,, allocator=temp);
}

#scope_module

Parser_Report :: struct
{
	input_text : string;      // The input string provided to the JSON_Parser/Serializer
	errors     : [..]Parser_Message;
};

Parser_Message_Type :: enum u8
{
	MESSAGE :: 0;
	WARNING :: 1;
	ERROR   :: 2;
}

Parser_Message :: struct
{
	type      : Parser_Message_Type;
	text      : string;
	data_addr : *u8;
	loc       : Source_Code_Location;
}

copy_message :: (using message: Parser_Message) -> Parser_Message
{
	return .{
		type=type,
		text=copy_string(text),
		data_addr=data_addr,
		loc=loc
	};
}