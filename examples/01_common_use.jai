
run_01_common_use :: ()
{
	json_parser: JSON_Parser;
	json_init(*json_parser);

	{
		// Parse a double-quoted string

		str: string;
		success := parse(*json_parser, *str, "\"Ada Lovelace\"");

		assert(success);
		assert(str == "Ada Lovelace");
	}

	{
		// Parse a struct

		Link :: struct {
			label : string;
			url   : string;
		}

		link_json := #string END
		{
			"label": "Ada Lovelace's Wikipedia Page",
			"url"  : "https://en.wikipedia.org/wiki/Ada_Lovelace"
		}
		END

		link: Link;
		success := parse(*json_parser, *link, link_json);

		assert(success);
		print("link is:\n\n%\n\n", link);
	}

	{
		// Parse a fixed-sized array

		array: [3]u8;
		success := parse(*json_parser, *array, "[1,2,3]");

		assert(success);
		print("array is:\n\n%\n\n", array);
	}

	{
		print("Parse a structure from an existing instance\n\n");

		json := #string END
		{"name": "Ada", "age": 173}
		END

		Person :: struct {
			name : string;
			age  : u8;
		};

		existing_instance := Person.{};

		print("original JSON_Parser is: \n\n%\n", json);

		success := parse(*json_parser, *existing_instance, json);
		assert(success);

		print("existing_instance value is:\n\n%\n\n", existing_instance);
	}

	{
		print("Parse a structure including nested fields\n\n");

		json :=#string END
		{
			"id": "unique",
			"nested": {
				"f64": 12.002,
				"f32": 0.01,
				"str": "This is an example",
				"array": [1,2,3,4,5,6,7,8,9,10]
			}
		}
		END

		print("original JSON_Parser is: \n\n%\n", json);

		MyStruct :: struct
		{
			id: string;
			nested : struct
			{
				f64    : float64;
				f32    : float32;
				str    : string;
				array  : [10]s32;
			}
		};
		
		my_struct: MyStruct;
		success := parse(*json_parser, *my_struct, json);
		
		assert(success);

		print("my_struct value is:\n\n%\n\n", my_struct);
	}

	json_release(*json_parser);
	
	print("example_01_simple (end)\n");
}
