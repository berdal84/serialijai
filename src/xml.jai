

XML_Attr_Type :: enum
{
	NULL    :: 0;
	BOOLEAN :: 1;
	NUMBER  :: 2;
	STRING  :: 3;
}

XML_Attr :: struct
{
	type: XML_Attr_Type;
	union {
		b    : bool;
		n    : float64;
		s    : string;
		data : [8]u8;
	};
}

XML_Elem :: struct
{
	tag      : string;
	attrs    : Table(string, XML_Attr);
	children : [..]XML_Elem;
}

XML_Parser :: struct
{	
	// data

	verbose    := false;
	input_text : string; // owned
	remainer   : string; // view over input_text's data
	messages   : [..]Generic_Parser_Message;

	// overridable procedures:

	parse                    := xml_parse;
	parse_begin              := xml_parse_begin;
	parse_end                := xml_parse_end;
    parse_key                := xml_parse_key;
	parse_value              := xml_parse_value;
      
	parse_object             := xml_parse_object;
	parse_object_begin       := xml_parse_object_begin;
	parse_object_body        := xml_parse_object_body;
	parse_object_end         := xml_parse_object_end;	
    parse_separator          := xml_parse_separator;
    parse_kv_separator       := xml_parse_kv_separator;
    parse_attr_value         := xml_parse_attr_value;
	parse_table_body         := xml_parse_table_body;
      
	parse_array              := xml_parse_array;
	parse_array_begin        := xml_parse_array_begin;
	parse_array_body         := xml_parse_array_body;
	parse_array_end          := xml_parse_array_end;
      
	parse_integer            := xml_parse_integer;  
	parse_float              := xml_parse_float;    
	parse_string             := xml_parse_string;   
	parse_bool               := xml_parse_bool;     
	parse_null               := xml_parse_null;     
      

	error                    := xml_error;
}

xml_init :: (using parser: *XML_Parser)
{
	input_text = "";
	remainer   = input_text;
}

xml_reset :: (using parser : *XML_Parser, source: string)
{	
	if input_text.count != 0
	{
		free(parser.input_text);
	}

	input_text = copy_string(source); // since we keep this internally, we copy. We don't want it to change or be dellocated while parsing.
	remainer   = input_text;
	
	// note: array_reset free memory, but we don't want that here. Let's save an alloc.
	messages.count = 0; // message's strings are allocated using temp
}

xml_release :: (parser: *XML_Parser)
{
	free(parser.input_text); // was copied, see JSON_init_parser(...)

	// note: array_reset free memory (which is something that might change, table_reset does not for example)
	array_reset(*parser.messages); // message's strings are allocated using temp
}

// For now, there is nothing specific about JSON for those procedures,
// I share them with other parsers.
xml_parse_integer     :: generic_parse_integer;
xml_parse_float       :: generic_parse_float;
xml_parse_string      :: generic_parse_string;
xml_parse_bool        :: generic_parse_bool;
xml_parse_null        :: (in_text: *string) -> bool                                                     { return generic_parse_exact_word(in_text, "null"); }
xml_parse             :: (using parser: *XML_Parser, ti: *Type_Info, data: *void, text: string) -> bool { return generic_parse(parser, ti, data, text); } // out_data must be initialized
xml_parse_value       :: (using parser: *XML_Parser, ti: *Type_Info, data: *void) -> bool               { return generic_parse_value(parser, ti, data); } // out_data must be  
xml_parse_object      :: (using parser: *XML_Parser, tis: *Type_Info_Struct, data: *void) -> bool       { return generic_parse_object(parser, tis, data); }
xml_parse_table       :: (p: *XML_Parser, tis: *Type_Info_Struct, out_data: *void) -> bool              { return generic_parse_table(p, tis, out_data); };
xml_parse_table_body  :: (p: *XML_Parser, tis: *Type_Info_Struct, out_data: *void) -> bool              { return generic_parse_table_body(p, tis, out_data); };
xml_parse_array       :: (p: *XML_Parser, tia: *Type_Info_Array, out_data: *void) -> bool               { return generic_parse_array(p, tia, out_data); };
xml_parse_array_body  :: (p: *XML_Parser, tia: *Type_Info_Array, out_data: *void) -> bool               { return generic_parse_array_body(p, tia, out_data); };

xml_parse_separator :: (text: *string) -> bool
{
	return eat_spaces(text) > 0;
}

xml_parse_kv_separator :: (text: *string) -> bool
{
	eat_spaces(text);
	return eat_char(text, #char "=");
}

xml_parse_key :: (out_data: *string, in_text: *string) -> bool
{
	eat_spaces(in_text);

	token := in_text.*;
	token.count = 0;

	while token.count < in_text.count
	{
		if token.count
		{
			last_char := token.data[token.count-1];
			if !is_alpha(last_char)
			{
				token.count -= 1;
				break;
			}
		}
		token.count += 1;
	}

	if token.count == 0
		return false;

	print("xml_parse_key -- found: \"%\"\n", token);
	out_data.* = token;
	advance(in_text, out_data.count);
	return true;
}

xml_parse_attr_key :: (using parser: *XML_Parser, key: *string) -> bool
{
	return generic_parse_string(key, *remainer);
}

xml_parse_attr_value :: (using parser: *XML_Parser, ti: *Type_Info, out_data: *void) -> bool
{
	value_as_string : string;

	if !generic_parse_string(*value_as_string, *remainer)
	{
		free(value_as_string);
		return error(parser, "Unable to parse attribute value\n");
	}

	if ti.type == {
		case .STRING;
		{
			(cast(*string)out_data).* = value_as_string;
			return true;
		}
		case .INTEGER;
		{
			ok := parse_integer(xx ti, out_data, *value_as_string);
			free(value_as_string);
			return ok;
		}
		case .FLOAT;
		{
			ok := parse_float(xx ti, out_data, *value_as_string);
			free(value_as_string);
			return ok;
		}
		case .BOOL;
		{
			ok := parse_bool(out_data, *value_as_string);
			free(value_as_string);
			return ok;
		}
	}
	return error(parser, "Unhandled attribute type %\n", ti.type);	
}

xml_parse_attrs :: (using parser: *$T, tis: *Type_Info_Struct, out_data: *void ) -> bool
{
	#if DEBUG print("xml_parse_attrs %...\n", tis.name);
	defer #if DEBUG print("xml_parse_attrs % (end)\n", tis.name);

	key_index := 0;
	while ( remainer.count )
	{
		key: string;

		if !parse_key(*key, *remainer,, allocator=temp)
		{
			break;
		}

		if !parse_kv_separator(*remainer)
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

		#if DEBUG print("parsing struct member %.% (%)...\n", tis.name, key, member.type.*);

		initialize(member_data, member.type);

		if !parse_attr_value(parser, member.type, member_data)
		{
			return error(parser, "Failed to parse %1's value (type: %2)\n", member.name, member.type.type);
		}

		if !parse_separator(*remainer)
		{
			break;
		}

		key_index += 1;
	}

	return true;
}

xml_get_tag_from_notes :: (tis: *Type_Info_Struct) -> string
{
	// look in notes
	tag_note_prefix := "xml:tag=";
	for tis.notes
	{
		note := it;
		if slice(note, 0, tag_note_prefix.count) == tag_note_prefix
		{
			return advance(note, tag_note_prefix.count);
		}
	}

	// use struct name by default
	return tis.name;
}

xml_parse_object_begin :: (using parser: *XML_Parser, tis: *Type_Info_Struct, out_data: *void) -> success : bool
{
	expected_tag := xml_get_tag_from_notes(tis);

	print("xml_parse_object_begin... tag=%\n", expected_tag);
	defer print("xml_parse_object_begin tag=% DONE\n", expected_tag);	
	
	if !xml_parse_tag_open(expected_tag, *remainer)
		return error(parser, "Unable to parse <%\n", expected_tag);

	initialize(out_data, tis);

	if !xml_parse_attrs(parser, tis, out_data)
		return false;

	// optionnal in short syntax (<tag attr="val" />)
	eat_char(*remainer, #char ">");

	return true;
}

xml_parse_unknown_tag_open :: (out_tag: *string, in_text: *string) -> bool
{
	//
	// parse " <"
	//
	temp_text : string = in_text.*;

	eat_spaces(*temp_text);
	
	if !eat_char(*temp_text, #char "<")
	{
		return false;
	}

	//
	// parse identifier/tag
	//
	eat_spaces(*temp_text);

	if temp_text.count == 0
	{
		return false;
	}

	if !is_alpha(temp_text.data[0])
	{
		return false;
	}

	out_tag.data  = temp_text.data;
	out_tag.count = 0;

	while out_tag.count < temp_text.count
	{
		out_tag.count += 1;
		last_char := out_tag.data[out_tag.count-1];
		if !is_alnum(last_char)
		{
			out_tag.count -= 1;
			break;
		}
	}

	// optionnal for short notation: <tag/>
	eat_char(*temp_text, #char ">");

	print("xml_parse_unknown_tag_open - result: %\n", out_tag.*);

	in_text.* = temp_text;

	return true;
}

xml_parse_tag_open :: (expected_tag: string, in_text: *string) -> bool
{
	expected_word := tprint("<%", expected_tag);
	if !generic_parse_exact_word(in_text, expected_word)
	{
		return false;
	}
	eat_char(in_text, #char ">"); // optionnal
	return true;
}

xml_parse_tag_close :: (expected_tag: string, in_text: *string) -> bool
{
	expected_word := tprint("</%>", expected_tag);
	return generic_parse_exact_word(in_text, expected_word);
}

xml_parse_object_body :: (using parser: *XML_Parser, tis: *Type_Info_Struct, out_data: *void) -> bool
{
	print("xml_parse_object_body ...\n");
	defer print("xml_parse_object_body DONE\n");

	while remainer.count
	{
		key : string;
		if !xml_parse_unknown_tag_open(*key, *remainer)
		{
			break;
		}

		member, offset_in_bytes := get_field(tis, key);
		
		if member == null
		{
			return error(parser, "Unable to find field '%1' in struct '%2'", key, tis.name);
		}

		assert(offset_in_bytes >= 0, "Constants not handled, we should probably skip what's next. But no time to think about it now.");

		member_data: *void = (cast(*u8)out_data) + offset_in_bytes;

		initialize(member_data, member.type);

		if !parse_value(parser, member.type, member_data)
		{
			return error(parser, "Unable to parse value for %\n", key);
		}

		if !xml_parse_tag_close(key, *remainer)
		{
			return error(parser, "Expecting </%>\n");
		}
	}

	return true;
}

xml_parse_object_end :: (using parser: *XML_Parser, tis: *Type_Info_Struct, out_data: *void) -> success : bool
{
	expected_tag := xml_get_tag_from_notes(tis);
	
	temp_remainer := remainer;
	
	if !xml_parse_tag_close(expected_tag, *temp_remainer)
		if !generic_parse_exact_word(*temp_remainer, "/>") // short syntax <tag/>
			return false;

	remainer = temp_remainer;

	return true;
}


xml_parse_array_begin :: (parser: *XML_Parser) -> success: bool
{
	assert(false, "not implemented yet"); // parse "<array>"
	return false;
}

xml_parse_array_end :: (parser: *XML_Parser) -> success: bool
{
	assert(false, "not implemented yet"); // parse "</array>"
	return false;
}

xml_parse_object_T :: (parser: *XML_Parser, out_data: *$T) -> bool
{
	return parse_object(parser, type_info(T), out_data);
}

xml_parse_begin :: (using parser : *XML_Parser, source: string) -> success: bool
{
	xml_reset(parser, source);

	if parser.verbose
	{
		print("______________________________________________________________\n");
		print("\n");
		print(" xml_parse_begin() - Parsing xml: '%'\n", source);
		print("\n");
	}

	return true; // no reason to fail for now...
}

xml_parse_end :: (using parser: *XML_Parser) -> success: bool
{
	eat_spaces(*remainer);

	if remainer.count
	{
		return error(parser, "Could not parse further");
	}
	
	if verbose print("xml_parse_end()\n");
	
	return true;
}

xml_error :: (using parser: *XML_Parser, string_format: string, args: ..Any, location := #caller_location) -> bool
{
	array_add(*messages, Generic_Parser_Message.{ .ERROR, tprint(string_format, ..args), remainer.data, location } );
	return false;
}

xml_make_report :: (parser : *XML_Parser = null) -> Generic_Parser_Report
{
	push_allocator(temp);

	// make report from state
	report: Generic_Parser_Report;
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

make_report :: (parser : *XML_Parser) -> Generic_Parser_Report
{
	push_allocator(temp);

	// make report from state
	report: Generic_Parser_Report;
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