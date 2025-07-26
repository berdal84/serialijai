
run_00_quick_start :: ()
{
	json_parser: JSON_Parser;
	json_serializer: JSON_Serializer;

	json_init(*json_parser);
	json_init(*json_serializer);

	JSON_string :: #string END
{
	"id"    : 1,
	"title" : "Women In Science",
	"related_links" : [
		"https://en.wikipedia.org/wiki/Ada_Lovelace",
		"https://en.wikipedia.org/wiki/Margaret_Hamilton_(software_engineer)"
	]
}
	END

	print("Let's consider the following JSON_Parser string:\n\n");
	print("%\n", JSON_string);

	//  ... and its related Jai Type:

	Topic :: struct {
		id            : u8;
		title         : string;
		related_links : [..]string;
	}

	// Let's parse the previous json string using that type:
	{
		print("We are going to parse it ...\n");

		topic: Topic;
		success := parse(*json_parser, *topic, JSON_string);

		print("Parsing done.\n");

		// Optionally, you can print a report when parsing failed,
		// this can be useful to spot a syntax in your JSON_Parser.
		//
		// JSON_print_report( JSON_make_report() );

		// Whether you print the report or not, you should always check for the
		// success before to go further
		assert(success);

		// Now we can use our data
		assert(topic.id == 1);
		assert(topic.title == "Women In Science");
		assert(topic.related_links.count == 2);
		print("Here is the serialisation of the parsed data:\n\n%\n\n", topic );
	}

	{
		print("A last example to illustrate you can parse without knowing the type in advance.");
		print("In such case the program will use JSON_Any to store your data in a tree-like structure.\n");

		// In case you want quickly load a data from a JSON_Parser, you can do it
		// by using the default Type "JSON_Any".
		// This type can hold anything a json can represent, but is less easy to
		// manipulate.
		//
		// Let's parse the same JSON_Parser without giving a type:
		
		data: JSON_Any;
		success := parse(*json_parser, *data, JSON_string);
		
		// previous line is equivalent to:
		// data, success := parse(*json_parser, JSON_string, JSON_Any); 

		print("Parsing done.");
		assert( success, "Unable to parse: % (%)\n", JSON_string, data);

		print("Let's use the function JSON_find() to get the value of the field \"title\"...\n");
		title := json_find(*data, "title");
		// note: I would like to implement a better JSON_find, to handle multiple
		//       keys, for example: JSON_find(*some_data, "field.sub_field.items[2]")
		print("title's value is: '%'\n\n", title.str );

		print("Here is the serialisation of the parsed data as JSON_Any:\n\n%\n\n", serialize(*json_serializer, *data));
	}

	json_release(*json_parser);
	json_release(*json_serializer);
}
