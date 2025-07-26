

DEBUG_MEMORY             :: true;  // check for mem leaks (Basic module)
DEBUG_SERIALISER         :: true; // enable detailed messages in serializer
ASSERT_WHEN_EXPECT_FAILS :: false; // fail as soon as an expectation failed

g_parser : JSON_Parser;

main :: ()
{
	test_begin();

	{
		json_init(*g_parser);

		test_JSON_parse__JSON_Any();
		test_JSON_parse__primitive();
		test_JSON_parse__array();
		test_JSON_parse__struct();
		test_JSON_parse__Table();
		test_JSON_parse__customization();
		test_JSON_parse__file();

		json_release(*g_parser);

		#if DEBUG_MEMORY
	    {
	        report: = make_leak_report();
	        if report.sorted_summaries.count
	        {
	            log_leak_report(report);
	            assert(false, "make_leak_report() FAILED\n");
	        }
	        else
	        {
	            print("make_leak_report() OK\n");
	        }
	    }
	}

	test_end();
}

#scope_file

test_JSON_parse__JSON_Any :: ()
{
	print_title("JSON_Any");

	// Note: JSON_Any is included in the library, a custom parser is added
	//       when user call init() (unless opted-out)

	{
		value : JSON_Any;
		ok := parse(*g_parser, *value, "null");

		print_report( json_make_report(*g_parser) );
		
		expect(ok);
		expect(value.type == .NULL);
	}

	{
		value : JSON_Any;
		ok := parse(*g_parser, *value, "true");

		print_report( json_make_report(*g_parser) );
		
		expect(ok);
		expect(value.type == .BOOLEAN);
		expect(value.b == true);
	}

	{
		value : JSON_Any;
		ok := parse(*g_parser, *value, "42.0");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}
		
		expect(ok);
		expect(value.type == .NUMBER);
		expect(value.n == 42.0);
	}

	{
		value : JSON_Any;
		ok := parse(*g_parser, *value, "\"Hello, world!\"");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}
		
		expect(ok);
		expect(value.type == .STRING);
		expect(value.str == "Hello, world!");

		// release memory
		json_release(*value);
	}

	{
		value : JSON_Any;
		ok := parse(*g_parser, *value, "wrong");

		print_report( json_make_report(*g_parser) );
		
		expect(!ok);
	}

	{
		value : JSON_Any;
		ok := parse(*g_parser, *value, "[1,2,3]");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}
		
		expect(ok);
		expect(value.type == .ARRAY);
		expect(value.a.count == 3);
		expect(value.a[0].n == 1);
		expect(value.a[1].n == 2);
		expect(value.a[2].n == 3);

		json_release(*value);
	}

	{
		value : JSON_Any;
		ok := parse(*g_parser, *value, "[ [1], [1,2], [1,2,3] ]");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}
		
		expect(ok);
		expect(value.type == .ARRAY);
		expect(value.a.count == 3);
		expect(value.a[0].a.count == 1);
		expect(value.a[0].a[0] == 1.0);

		expect(value.a[1].a.count == 2);
		expect(value.a[2].a[0] == 1.0 );
		expect(value.a[2].a[1] == 2.0 );

		expect(value.a[2].a.count == 3);
		expect(value.a[2].a[0] == 1.0 );
		expect(value.a[2].a[1] == 2.0 );
		expect(value.a[2].a[2] == 3.0 );

		json_release(*value);
	}

	{
		obj : JSON_Any;
		ok := parse(*g_parser, *obj, "{ \"b\": true, \"str\": \"my_string\" }");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}
		
		expect(ok);
		expect(obj.type == .OBJECT);
		expect(json_find(obj, "str").str == "my_string");
		expect(json_find(obj, "b").b == true);

		json_release(*obj);
	}
}

test_JSON_parse__primitive :: ()
{
	print_title("boolean");
	
	{
		value : bool = false;
		ok := parse(*g_parser, *value, "true");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}
		
		expect(ok);
		expect(value==true);
	}

	{
		value: bool = true;
		ok := parse(*g_parser, *value, "false");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}

		expect(ok);
		expect(value==false);
	}
	
	{
		value: bool;
		ok := parse(*g_parser, *value, "tRuE");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}
		
		expect(!ok);
	}

	{
		value : bool = true;

		ok := parse(*g_parser, *value, "f@lse");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}
		
		expect(!ok);
	}

	print_title("string");

	{
		value: string;
		ok := parse(*g_parser, *value, "\"Ada Lovelace\"");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}

		expect(ok);
		expect(value=="Ada Lovelace");

		// Release memory
		free(value);
	}
	
	print_title("float");

	{
		value: float;
		ok := parse(*g_parser, *value, "0.125");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}

		expect(ok);
		expect(value==0.125);
	}

	{
		value: float;
		ok := parse(*g_parser, *value, "42.125");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}

		expect(ok);
		expect(value==42.125);
	}

	{
		value: float;
		ok := parse(*g_parser, *value, "1");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}

		expect(ok);
		expect(value==1.0);
	}

	{
		value: float;

		ok := parse(*g_parser, *value, "-1.2");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}

		expect(ok);
		expect(value==-1.2);
	}
}

test_JSON_parse__array :: ()
{
	print_title("array (FIXED)");

	{
		array: [1]s32;
		ok := parse(*g_parser, *array, "[42]");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}

		expect(ok);
		expect(array.count == 1);
	}

	{
		array: [2]s32;
		ok := parse(*g_parser, *array, "[ 1, 2]");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}

		expect(ok);
		expect(array[0] == 1);
		expect(array[1] == 2);
		expect(array.count == 2);
	}
	
	{
		array: [4]s32;
		ok := parse(*g_parser, *array, "[4,3,2,1]");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}

		expect(ok);
		expect(array[0] == 4);
		expect(array[1] == 3);
		expect(array[2] == 2);
		expect(array[3] == 1);
		expect(array.count == 4);
	}

	print_title("array (RESIZABLE)");

	{
		array: [..]s32;
		defer array_free(array);

		ok := parse(*g_parser, *array, "[0,1,2,3]");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}

		expect(ok);
		expect(array.count == 4);
		expect(array[0] == 0);
		expect(array[1] == 1);
		expect(array[2] == 2);
		expect(array[3] == 3);
	}

	print_title("array (VIEW)");

	{
		array: []s32 = .[0,0,0];
		ok := parse(*g_parser, *array, "[1,2,3]");
		expect(!ok);
	}

}

test_JSON_parse__struct :: ()
{
print_title("struct");

	{
		json := #string END
{
	"field": {
		"f64": 123456.125,
		"f32": 0.123456,
		"str": "Hello JSON_Parser!",
		"array": [7, 13],
		"table": {}
	}
}
END
		NestedStructure :: struct
		{
			field : struct
			{
				f64    : float64;
				f32    : float32;
				str    : string;
				array  : [2]s32;
				table  : Table(string, string);
			}
		};

		nested_structure: NestedStructure;
		ok := parse(*g_parser, *nested_structure, json);

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}

		expect(ok);

		using nested_structure.field;
		expect(array[0] == 7);
		expect(array[1] == 13);
		expect(str == "Hello JSON_Parser!");
		expect(f64 == 123456.125);
		expect(f32 == 0.123456);
		expect(table.count == 0);

		free(nested_structure.field.str);
		for nested_structure.field.table.entries
		{
			free(it.key);
			free(it.value);
		}
		deinit(*nested_structure.field.table);
	}

	print_title("array of struct");
	{
		json := #string END
		{
			"array": [
				{ "id": 1},
				{ "id": 2},
				{ "id": 3},
				{ "id": 4}
			]
		}
		END

		My_Struct :: struct { id: u8; };
		obj : struct {
			array: [..]My_Struct;
		}
		ok := parse(*g_parser, *obj, json);

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}
		
		expect(ok);
		expect(obj.array.count == 4);
		expect(obj.array[0].id == 1);
		expect(obj.array[1].id == 2);
		expect(obj.array[2].id == 3);
		expect(obj.array[3].id == 4);

		array_free(obj.array);
	}
}

test_JSON_parse__Table :: ()
{
	print_title("Table(string, $T)");
	
	// By default, the parser does not know how to parse a Table
	// This is due to the fact polymorphic types cannot be reflected at runtime
	// or would require a compile-time solution that might provoke a compile-time
	// logaritmic explosion.
	//
	// So we add our Table type here:

	{
		table: Table(string, string);
		ok := parse(*g_parser, *table, "{}");

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}

		expect(ok);
		expect(table.count == 0);
	}

	{
		json :=
#string END
{
	"first name" : "Ada",
	"last name"  : "Lovelace"
}
END
		table : Table(string, string);

		ok := parse(*g_parser, *table, json);

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}

		expect(ok);

		found, name := table_find_new(*table, "first name");
		expect(found);
		expect(name == "Ada");

		// release memory
		for table.entries
		{
			free(it.key);
			free(it.value);
		}
		deinit(*table);
	}
	
	{
		json := #string END
{
	"one"   : 1,
	"two"   : 2,
	"three" : 3
}
END
		table : Table(string, float64);
		ok := parse(*g_parser, *table, json);

		report := json_make_report(*g_parser);

		if report.errors.count {
			print_report(report);
		}

		expect(ok);

		expect(table.count == 3);
		value: float64;
		ok, value = table_find_new(*table, "one");   expect(ok); expect(value == 1.0);
		ok, value = table_find_new(*table, "two");   expect(ok); expect(value == 2.0);
		ok, value = table_find_new(*table, "three"); expect(ok); expect(value == 3.0);

		// release memory
		for table.entries
		{
			free(it.key);
		}
		deinit(*table);
	}
}

test_JSON_parse__customization :: ()
{
	print_title("Customization");

	MyStruct :: struct { id: u8; name : string; };
	MyTable :: Table(string, MyStruct);

	release_my_struct :: (s: *MyStruct)
	{
		free(s.name);
	}

	release_my_table :: (t: *MyTable)
	{
		for t.entries
		{
			free(it.key);
			release_my_struct(*it.value);
		}
		deinit(t);
	}

	{
		print("First, let's show you that when parsing a table using the generic JSON_Any type:\n");
		data : JSON_Any;
		ok := parse(*g_parser, *data, "{ \"item_01\": { \"id\": 42, \"name\": \"Ada\" } }");

		expect(ok);

		print("Parsing succeeded, but you don't get a typed response.\n");
		print("This is because the parser is unaware of MyStruct.\n\n");

		// release memory
		json_release(*data);
	}

	{
		print("Now, if we override the parse_table_body function, we'll get an appropriate result:\n");

		my_table: MyTable;

		print("This just requires two steps.\nFirst, you initialize json manually.\n");
		print("Then, you override parse_table_body.\n");
		parse_table_body_backup := g_parser.parse_table_body;
		g_parser.parse_table_body = (using parser: *JSON_Parser, tis: *Type_Info_Struct, out_data: *void) -> success: bool
		{
			if tis == type_info(MyTable)
				return  generic_parse_table_body_T(parser, cast(*MyTable)out_data);	

			return parse_table_body(parser, tis, out_data); // fallback on default
		}

		print("Now you can parse the json string...\n");
		ok := parse(*g_parser, *my_table, "{ \"item_01\": { \"id\": 42, \"name\": \"Ada\" } }");

		expect(ok);

		print("Et voilà! The data is loaded!\n");
		ptr := table_find_pointer(*my_table, "item_01");
		expect( ptr != null );
		expect( ptr.id   == 42 );
		expect( ptr.name == "Ada" );

		// release memory
		release_my_table(*my_table);

		// Restore the default function so other tests do not get impacted
		g_parser.parse_table_body = parse_table_body_backup;
	}
}

test_JSON_parse__file :: ()
{
	print_title("file");

	{
		json: JSON_Any;
		ok := parse_file(*g_parser, *json, "tests/array.json");
		expect(ok);
		expect(json.array.count != 0);

		json_release(*json);
	}
}

expect :: (code: Code, loc := #caller_location) #expand 
{
	g_expect_count += 1;

	if (#insert code) == false
	{
		g_expect_failed_count += 1;

		code_str :: #run get_code_name(code);

		print("%:%:% Expression '%' is false, but was expected to be true.\n", loc.fully_pathed_filename, loc.line_number, loc.character_number, code_str);

		#if ASSERT_WHEN_EXPECT_FAILS assert(false, "expect() FAILED, see messages above.");
	}
}


g_expect_count := 0;
g_expect_failed_count := 0;

test_begin :: ()
{
	g_expect_count = 0;
	g_expect_failed_count = 0;

	print_title("Test Begin");
}

test_end :: ()
{
	print("Test END\n");

	success := g_expect_failed_count == 0;

	print("------------------------------------------------------------------\n\n");
	defer print("\n------------------------------------------------------------------\n");
	if !success
	{
		assert(false, ">>> %/% expectation(s) failed! See errors above...\n\n", g_expect_failed_count, g_expect_count);
	}
	else
	{
		set_console_color(Console_Color.GREEN);
		print(">>> %/% tests passed!\n", g_expect_count-g_expect_failed_count, g_expect_count);
		reset_console_color();
	}
	
}

print_title :: (title: string)
{
	color  :: Console_Color.YELLOW;

	set_console_color(color);
	print("\n================================================================\n");
	print("  %\n", title);
	print("================================================================\n");
	reset_console_color();
}

//
// Override == operator to compare a JSON_Any with a given value.
// This is mainly to save time in tests, not really to use it in your code.
//
operator == :: (value: JSON_Any, other: $T) -> bool
{
	#if type_info(T).type == {
		case .BOOL;    assert(value.type == .BOOL);   return value.boolean  == other;
		case .STRING;  assert(value.type == .STRING); return value.str      == other;
		case .FLOAT;   assert(value.type == .NUMBER); return value.number   == other;
		case; assert(false, "% is not supported by JSON_Any. Use bool, float64, or string if possible.", T );
	}
}

// Json Serializer Module
#import,file "../module.jai"(DEBUG=DEBUG_SERIALISER);

// Other Dependencies
#import "Basic"()(MEMORY_DEBUGGER=DEBUG_MEMORY);
#import "Hash_Table";
#import "Print_Color";
#import "Print_Vars";
#import "Compiler";