
run_02_how_to_extend :: ()
{
	json_parser: JSON_Parser;
	json_init(*json_parser);

	{
		//
		// By default, the parser only handle the common types. As soon as you
		// want to deal with polymorphic types it won't work properly.
		// Let's say, for example, you need to parse a Table having a custom struct
		// as Value_Type. Since Tables are pretty common, a helper is available to
		// make the parser aware of this new type.
		
		// This is your custom type
		MyStruct :: struct {
			tag   : string;
			value : u8;
		};
		MyTable :: Table(string, MyStruct);

		// Override parser.parse_table's implementation:
		json_parser.parse_table_body = (using parser: *JSON_Parser, tis: *Type_Info_Struct, out_data: *void) -> success: bool
		{
			// Make sure we're parsing a MyTable
			if tis == type_info(MyTable)
			{
				// Then parse the table using a generic template:
				return generic_parse_table_body_T(parser, cast(*MyTable)out_data);
			}

			// Fallback on default
			return json_parse_table_body(parser, tis, out_data);
		}		

		// Now we can parse a JSON_Parser using this type:

		json :: #string END
		{
			"first" : {
				"tag"   : "example-03",
				"value" : 42
			}
		}
		END
		
		result : MyTable;
		ok := parse(*json_parser, *result, json);

		//assert(ok);

		my_struct_pointer := table_find_pointer(*result, "first");
		assert( my_struct_pointer != null );
		assert( my_struct_pointer.tag   == "example-03" );
		assert( my_struct_pointer.value == 42 );
	}
	json_release(*json_parser);

}
