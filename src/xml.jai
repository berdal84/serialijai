

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

xml_parse_key_value :: (key: *string, value: *string, input_text: string) -> bool
{
	print("xml_parse_key_value...\n");

	eat_spaces(input_text);

	// Parse key
	key.* = input_text;
	key.count = 0;

	while key.count < input_text.count
	{
		key.count += 1;
		last_char := key.data[key.count-1];

		if !is_alpha(last_char)
		{
			return false;
		}

		if last_char == keyvalue_separator
		{
			key.count -= 1;
			break;
		}	
	}

	print("-- found key: %\n", key.*);

	remainer := input_text;
	advance(*remainer, key.count + 1);

	// Parse value
	if !generic_parse_string(value, *remainer)
		return false;

	print("-- found value: %\n", value.*);

	return true;
}

// For now, there is nothing specific about JSON for those procedures,
// I share them with other parsers.
xml_parse_integer     :: generic_parse_integer;
xml_parse_float       :: generic_parse_float;
xml_parse_string      :: generic_parse_string;
xml_parse_bool        :: generic_parse_bool;
xml_parse_null        :: (in_text: *string) -> bool                                                     { return generic_parse_word(in_text, "null"); }
xml_parse             :: (using parser: *XML_Parser, ti: *Type_Info, data: *void, text: string) -> bool { return generic_parse(parser, ti, data, text); } // out_data must be initialized
xml_parse_value       :: (using parser: *XML_Parser, ti: *Type_Info, data: *void) -> bool               { return generic_parse_value(parser, ti, data); } // out_data must be  
xml_parse_object      :: (using parser: *XML_Parser, tis: *Type_Info_Struct, data: *void) -> bool       { return generic_parse_object(parser, tis, data); }
xml_parse_object_body :: (using parser: *XML_Parser, tis: *Type_Info_Struct, data: *void) -> bool
{
	// TODO: children
	return true;
};

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

xml_parse_object_begin :: (using parser: *XML_Parser, tis: *Type_Info_Struct, out_data: *void) -> success : bool
{
	expected_tag := tis.name;

	print("xml_parse_object_begin... tag=%\n", expected_tag);
	
	if !generic_parse_word(*remainer, tprint("<%", expected_tag) )
		return false;

	// parse attrs as the body (optionnal)
	generic_parse_keyvalues(parser, tis, out_data);

	// optionnal in short syntax (<tag attr="val" />)
	eat_char(*remainer, #char ">");

	print("xml_parse_object_begin tag=% DONE\n", expected_tag);	
	return true;
}

xml_parse_object_end :: (using parser: *XML_Parser, tis: *Type_Info_Struct, out_data: *void) -> success : bool
{
	expected_tag := tis.name;
	
	temp_remainer := remainer;
	
	if !generic_parse_word(*temp_remainer, tprint("</%>", expected_tag) ) // verbose syntax <tag></tag>
		if !generic_parse_word(*temp_remainer, "/>") // short syntax <tag/>
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