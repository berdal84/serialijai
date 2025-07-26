
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
      
	parse_value              := xml_parse_value;
      
	parse_object             := xml_parse_object;
	parse_object_begin       := xml_parse_object_begin;
	parse_object_body        := xml_parse_object_body;
	parse_object_end         := xml_parse_object_end;	
	parse_value_separator    := xml_parse_value_separator;
	parse_keyvalue_separator := xml_parse_keyvalue_separator;

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
xml_parse_null        :: (in_text: *string) -> bool                                                     { return generic_parse_word(in_text, "null"); }
xml_parse             :: (using parser: *XML_Parser, ti: *Type_Info, data: *void, text: string) -> bool { return generic_parse(parser, ti, data, text); } // out_data must be initialized
xml_parse_value       :: (using parser: *XML_Parser, ti: *Type_Info, data: *void) -> bool               { return generic_parse_value(parser, ti, data); } // out_data must be  
xml_parse_object      :: (using parser: *XML_Parser, tis: *Type_Info_Struct, data: *void) -> bool       { return generic_parse_object(parser, tis, data); }
xml_parse_object_body :: (using parser: *XML_Parser, tis: *Type_Info_Struct, data: *void) -> bool       { return generic_parse_object_body(parser, tis, data); };
xml_parse_table       :: (p: *XML_Parser, tis: *Type_Info_Struct, out_data: *void) -> bool              { return generic_parse_table(p, tis, out_data); };
xml_parse_table_body  :: (p: *XML_Parser, tis: *Type_Info_Struct, out_data: *void) -> bool              { return generic_parse_table_body(p, tis, out_data); };
xml_parse_array       :: (p: *XML_Parser, tia: *Type_Info_Array, out_data: *void) -> bool               { return generic_parse_array(p, tia, out_data); };
xml_parse_array_body  :: (p: *XML_Parser, tia: *Type_Info_Array, out_data: *void) -> bool               { return generic_parse_array_body(p, tia, out_data); };

xml_parse_object_begin :: (parser: *XML_Parser) -> success : bool
{
	assert(false, "not implemented yet"); // parse "<name>"
	return false;
}

xml_parse_object_end :: (parser: *XML_Parser) -> success : bool
{
	assert(false, "not implemented yet"); // parse "</name>"
	return false;
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

xml_parse_value_separator :: (in_text: *string) -> success: bool
{
	assert(false, "not implemented yet");
	return false;
}

xml_parse_keyvalue_separator :: (in_text: *string) -> success: bool
{
	assert(false, "not implemented yet");
	return false;
}

xml_reset_parser :: (using parser: *XML_Parser, source: string)
{
	assert(false,"not implemented yet");
}

xml_parse_begin :: (using parser : *XML_Parser, source: string) -> success: bool
{
	xml_reset_parser(parser, source);

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
