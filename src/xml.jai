
//
// XML_Elem
//

XML_Elem :: struct @xml:tag=*
{
	tag      : string;
	attrs    : Table(string, XML_Attr); @xml:attrs
	children : [..]XML_Elem;            @xml:children // ex: "<tag><child1></child1></tag>"
	content  : string;                  @xml:content  // raw content, ex: "<tag>This is a raw content</tag>".
}

XML_Attr :: struct {
	type: XML_Attr_Type;
	union {
		number  : float64;
		str     : string;
		boolean : bool;
	}
#place boolean;
	b: bool = ---;
#place number;
	n: float64 = ---;
#place str;
	s: string = ---;
}

XML_Attr_Type :: enum {
	NULL    :: 0;
	NUMBER  :: 1;
	STRING  :: 2;
	BOOLEAN :: 3;
}

xml_find_attr :: (elem: XML_Elem, attr_name: string) -> ok: bool, XML_Attr
{
	ok, ptr := table_find_new(*elem.attrs, attr_name);
	return ok, ptr;
}

//
// XML Parser
//

XML_Parser :: struct
{	
	#as using _parser: Parser;

	// data

	separator    = " ";
	kv_separator = "=";

	input_text   : string; // owned
	remainer     : string; // view over input_text's data
	messages     : [..]Parser_Message;

	tag_hierarchy_stack : [..]string;

	// non-pure
	
	get_remainer             = (parser: *Parser) -> *string { return *(cast(*XML_Parser)parser).remainer; };
	reset                    = (parser: *Parser, input: string) -> bool { return xml_reset(xx parser, input); };
	parse_begin              = (parser: *Parser, ti: *Type_Info, data: *void) -> bool { return xml_parse_begin(xx parser, ti, data); };
	parse_end                = (parser: *Parser, ti: *Type_Info, data: *void) -> bool { return xml_parse_end(xx parser, ti, data); };
	parse_value              = generic_parse_value;
	parse_object_begin       = (parser: *Parser, tis: *Type_Info_Struct, data: *void) -> bool { return xml_parse_object_begin(xx parser, tis, data); };
	parse_object_body        = generic_parse_object_body;
	parse_object_end         = (parser: *Parser, tis: *Type_Info_Struct, data: *void) -> bool { return xml_parse_object_end(xx parser, tis, data); };	
	parse_object_member      = (parser: *Parser, tis: *Type_Info_Struct, data: *void, index: s64) -> bool { return xml_parse_object_member(xx parser, tis, data); }
	parse_table_body         = (parser: *Parser, tis: *Type_Info_Struct, data: *void) -> bool { return generic_parse_table_body(parser, tis, data); };
	parse_array_begin        = (parser: *Parser, tia: *Type_Info_Array, data: *void) -> bool { return xml_parse_array_begin(xx parser, tia, data); }
	parse_array_body         = (parser: *Parser, tia: *Type_Info_Array, data: *void) -> bool { return generic_parse_array_body(parser, tia, data); }
	parse_array_end          = (parser: *Parser, tia: *Type_Info_Array, data: *void) -> bool { return xml_parse_array_end(xx parser, tia, data); }
	error                    = (parser: *Parser, string_format: string, args: ..Any, location := #caller_location) -> bool { return xml_error(xx parser, string_format, ..args, location); };
    
    // pure

    parse_integer            = generic_parse_integer;
	parse_float              = generic_parse_float;    
	parse_string             = xml_parse_string;   
	parse_bool               = generic_parse_bool;     
	parse_null               = generic_parse_null;     
}

xml_parse_object_member :: (using parser: *JSON_Parser, tis: *Type_Info_Struct, out_data: *void) -> bool
{
	key : string;
	if !xml_parse_unknown_tag_open(*key, *remainer)
	{
		return false;
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
		return error(parser, "Failed to parse %1's value (type: %2)\n", member.name, tprint_type(member.type) );
	}

	if !xml_parse_tag_close(key, *remainer)
	{
		return error(parser, "Expecting </%>\n");
	}

	return true;
}
xml_parse_string :: (out_data: *string, in_text: *string) -> bool
{
	assert(out_data != null);

	out_data.* = "";		

	debug_print("xml_parse_string ...\n");
	defer debug_print("xml_parse_string (end)\n");

	eat_spaces(in_text);

	//
	// In XML, a string does not need to be in double quotes (ex: <string>This is a String</string> )
	// In this implementation we parse any char until we reach "<" (new tag) or end of string.
	//
	begin: *u8 = in_text.data;
	current_char: *u8 = begin;
	escape_next_char := false;
	while (true)
	{
		debug_print("xml_parse_string() - Searching '<' ... %\n", string.{ data=begin, count=current_char-begin+1 } );
		if !escape_next_char && current_char.* ==  #char "<"
        {
        	debug_print("xml_parse_string() - Searching '<' ... FOUND at pos %\n", current_char-begin);
        	break;
        }
		
		escape_next_char = current_char.* == #char "\\";
        
        current_char += 1;

        if current_char == in_text.data + in_text.count
        {
        	return false;
        }
    }

    portion := slice(in_text.*, 0, current_char - begin);
	out_data.* = copy_string(portion); // we copy because we do not want to return something pointing to our internal input_text.

	advance(in_text, current_char - begin);

	debug_print("-- parsed string = '%'\n", out_data.*);

	return true;
}

xml_get_remainer :: (parser: *XML_Parser) -> *string
{
	return *parser.remainer;
}

xml_init :: (using parser: *XML_Parser)
{
	input_text = "";
	remainer   = input_text;
}

xml_reset :: (using parser : *XML_Parser, source: string) -> bool
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

xml_release :: (parser: *XML_Parser)
{
	free(parser.input_text); // was copied, see JSON_init_parser(...)

	// note: array_reset free memory (which is something that might change, table_reset does not for example)
	array_reset(*parser.messages); // message's strings are allocated using temp
}

xml_release :: (attr: XML_Attr)
{
	if attr.type == .STRING
	{
		free(attr.s);
	}
}

xml_release :: (elem: XML_Elem)
{
	free(elem.tag);
	free(elem.content);

	for elem.attrs.entries
	{
		free(it.key);
		xml_release(it.value);
	}
	deinit(*elem.attrs);

	for elem.children
	{
		xml_release(it);
	}
}

xml_parse_separator :: (text: *string) -> bool
{
	return eat_spaces(text) > 0;
}

xml_parse_kv_separator :: (text: *string) -> bool
{
	eat_spaces(text);
	return eat_char(text, #char "=");
}

xml_parse_attribute_key :: (out_data: *string, in_text: *string) -> bool
{
	debug_print("xml_parse_attribute_key ...\n");

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

	debug_print("xml_parse_attribute_key -- found: \"%\"\n", token);

	out_data.* = token;
	advance(in_text, out_data.count);
	return true;
}

xml_parse_attribute_value :: (using parser: *XML_Parser, ti: *Type_Info, out_data: *void) -> bool
{
	value_as_string : string;

	if !generic_parse_string_view(*value_as_string, *remainer)
	{
		return error(parser, "Unable to parse attribute value\n");
	}

	if ti.type == {
		case .STRING;
		{
			(cast(*string)out_data).* = copy_string(value_as_string);
			return true;
		}
		case .INTEGER;
		{
			return parse_integer(xx ti, out_data, *value_as_string);
		}
		case .FLOAT;
		{
			return parse_float(xx ti, out_data, *value_as_string);
		}
		case .BOOL;
		{
			return parse_bool(out_data, *value_as_string);
		}
	}

	if ti == type_info(XML_Attr)
	{
		attr := (cast(*XML_Attr)out_data);

		if parse_float(type_info(float64), *attr.n, *value_as_string)
		{
			attr.type = .NUMBER;
			return true;
		}
		if parse_bool(*attr.b, *value_as_string)
		{
			attr.type = .BOOLEAN;
			return true;
		}

		attr.type = .STRING;
		attr.str  = copy_string(value_as_string);

		return true;
	}

	return error(parser, "Unhandled attribute type %\n", ti.type);	
}

xml_parse_attributes_as_table :: (using parser: *XML_Parser, table: *Table(string, XML_Attr)) -> bool
{
	debug_print("xml_parse_attributes_as_table ...\n");
	defer debug_print("xml_parse_attributes_as_table (end)\n");

	key_index := 0;
	while ( remainer.count )
	{
		key: string;

		if !xml_parse_attribute_key(*key, *remainer)
		{
			break;
		}

		debug_print("-- found key: '%'\n", key);

		if !generic_parse_exact_word(*remainer, kv_separator)
		{
			return error(parser, "Expecting a keyvalue separator");
		}

		attr: XML_Attr;

		if !xml_parse_attribute_value(parser, type_info(XML_Attr), *attr)
		{
			return error(parser, "Failed to parse %'s value (type: XML_Attr)\n", key);
		}

		table_add(table, copy_string(key), attr);

		if eat_spaces(*remainer) == 0
		{
			break;
		}

		key_index += 1;
	}

	return true;
}

xml_parse_attributes_as_struct_members :: (using parser: *XML_Parser, tis: *Type_Info_Struct, out_data: *void ) -> bool
{
	debug_print("xml_parse_attributes %...\n", tis.name);
	defer debug_print("xml_parse_attributes % (end)\n", tis.name);

	key_index := 0;
	while ( remainer.count )
	{
		key: string;

		if !xml_parse_attribute_key(*key, *remainer,, allocator=temp)
		{
			break;
		}

		debug_print("-- found key: '%'\n", key);

		if !generic_parse_exact_word(*remainer, kv_separator)
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

		if !xml_parse_attribute_value(parser, member.type, member_data)
		{
			return error(parser, "Failed to parse %1's value (type: %2)\n", member.name, tprint_type(member.type) );
		}

		if eat_spaces(*remainer) == 0
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
	tag_note_prefix :: "xml:tag=";
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

xml_find_attrs_table :: (tis: *Type_Info_Struct, data: *void) -> *Table(string, XML_Attr)
{
	tag_note_prefix :: "xml:attrs";
	for member : tis.members
	{
		for note : member.notes
		{
			if note == tag_note_prefix
			{
				table_ptr : *void = (cast(*u8)data) + member.offset_in_bytes;
				return table_ptr;
			}
		}
	}
	return null;
}

xml_parse_object_begin :: (using parser: *XML_Parser, tis: *Type_Info_Struct, out_data: *void) -> success : bool
{
	tag := xml_get_tag_from_notes(tis);

	debug_print("xml_parse_object_begin... tag=%\n", tag);
	defer debug_print("xml_parse_object_begin tag=% DONE\n", tag);	
	
	if tag == "*" // * is any
	{
		if !xml_parse_unknown_tag_open(*tag, *remainer) // TODO: tag must be the same when closing the object. We need some nested states to handle that.
		{
			return error(xx parser, "Unable to parse % tag (<%)\n", tprint_type(tis), tag);	
		}
	}
	else if !xml_parse_tag_open(tag, *remainer)
	{
		return error(xx parser, "Unable to parse % tag (<%)\n", tprint_type(tis), tag);	
	}

	init_data_with_type(out_data, tis);

	attr_table := xml_find_attrs_table(tis, out_data); // user can group attributes in a single field using, ex: MyStruct { attrs: Table(string, XML_Attr); @xml:attrs }
	if attr_table != null
	{
		if !xml_parse_attributes_as_table(parser, attr_table)
		{
			return error(xx parser, "Unable to parse %'s attributes (as table)", tprint_type(tis) );
		}
	}
	else
	{
		if !xml_parse_attributes_as_struct_members(parser, tis, out_data)
		{
			return error(xx parser, "Unable to parse %'s attributes", tprint_type(tis) );
		}
	}
	

	// optionnal in short syntax (<tag attr="val" />)
	eat_char(*remainer, #char ">");

	array_add(*tag_hierarchy_stack, tag);
	
	return true;
}

xml_parse_unknown_tag_open :: (out_tag: *string, in_text: *string) -> bool
{
	//
	// parse " <"
	//
	cursor : string = in_text.*;
	
	if !generic_parse_exact_word(*cursor, "<")
	{
		return false;
	}

	//
	// parse identifier/tag
	//
	eat_spaces(*cursor);

	if cursor.count == 0
	{
		return false;
	}

	if !is_alpha(cursor.data[0])
	{
		return false;
	}

	out_tag.data  = cursor.data;
	out_tag.count = 0;

	while out_tag.count < cursor.count
	{
		out_tag.count += 1;
		advance(*cursor, 1);
		last_char := out_tag.data[out_tag.count-1];
		if !is_alnum(last_char)
		{
			out_tag.count -= 1;
			break;
		}
	}

	// optionnal for short notation: <tag/>
	generic_parse_exact_word(*cursor, ">");

	debug_print("xml_parse_unknown_tag_open - result: %\n", out_tag.*);

	in_text.* = cursor;

	return true;
}

xml_parse_tag_open :: (tag: string, in_text: *string) -> bool
{
	expected_word := tprint("<%", tag);
	if !generic_parse_exact_word(in_text, expected_word)
	{
		return false;
	}
	eat_char(in_text, #char ">"); // optionnal
	return true;
}

xml_parse_tag_close :: (tag: string, in_text: *string) -> bool
{
	expected_word := tprint("</%>", tag);
	return generic_parse_exact_word(in_text, expected_word);
}

xml_parse_object_end :: (using parser: *XML_Parser, tis: *Type_Info_Struct, out_data: *void) -> success : bool
{
	tag := pop(*tag_hierarchy_stack);
	
	temp_remainer := remainer;
	
	if tag == "*"
	{

	}
	else
	{
		if !xml_parse_tag_close(tag, *temp_remainer)
			if !generic_parse_exact_word(*temp_remainer, "/>") // short syntax <tag/>
				return false;
	}

	remainer = temp_remainer;

	return true;
}


xml_parse_array_begin :: (parser: *XML_Parser, tia: *Type_Info_Array, data: *void) -> success: bool
{
	assert(false, "not implemented yet"); // parse "<array>"
	return false;
}

xml_parse_array_end :: (parser: *XML_Parser, tia: *Type_Info_Array, data: *void) -> success: bool
{
	assert(false, "not implemented yet"); // parse "</array>"
	return false;
}

xml_parse_object_T :: (parser: *XML_Parser, out_data: *$T) -> bool
{
	return parse_object(parser, type_info(T), out_data);
}

xml_parse_begin :: (using parser : *XML_Parser, ti: *Type_Info, data: *void) -> success: bool
{
	debug_print("______________________________________________________________\n");
	debug_print("\n");
	debug_print(" xml_parse_begin() - Parsing xml: '%'\n", input_text);
	debug_print("\n");

	return true; // no reason to fail for now...
}

xml_parse_end :: (using parser: *XML_Parser, ti: *Type_Info, data: *void) -> success: bool
{
	eat_spaces(*remainer);

	if remainer.count
	{
		return error(xx parser, "Could not parse further");
	}
	
	debug_print("xml_parse_end()\n");
	
	return true;
}

xml_error :: (using parser: *XML_Parser, string_format: string, args: ..Any, location := #caller_location) -> bool
{
	array_add(*messages, Parser_Message.{ .ERROR, tprint(string_format, ..args), remainer.data, location } );
	return false;
}

xml_make_report :: (parser : *XML_Parser = null) -> Parser_Report
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

make_report :: (parser : *XML_Parser) -> Parser_Report
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