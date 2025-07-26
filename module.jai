//
// json-serializer-jai
// a JSON_Parser Serializer written in Jai
// Bérenger Dalle-Cort (berenger@42borgata.com)
//
// Requirements:
//
//   Jai beta-2.012
//
// Limitations:
//
//
// User can override any function from JSON_Parser to create a custom behavior.
// By default, this library handle:
//
//      - strings     100%
//      - arrays       83% (fixed-size, resizable, views can't be parser)
//   	- integers:    90% (signed/unsigned, 8-64, no overflow check!)
//      - floats:      90% (32/64, no overflow check for 32)
//      - Table(T, U): 99% (requires manual intervention from user)
//      - JSON_Any    100% (any JSON_Parser can be loaded into this type)
//      - pointers:     0%
//      - Any:          0%
//
// Usage:
//
//   See ./example.jai
//
////////////////////////////////////////////////////////////////////////////////
//
// Dev notes:
//
// Import/load strategy:
//   Everything is loaded/imported from this file.
//
// TODOs:
//   - parser iterates a lot in Type_Info_Struct.members, we should probably
//     index members by name dynamically (when the struct is parsed for the
//     first time)
//   - Global state: we have a g_state, but we might want to avoid that and
//     pass it as a pointer from one procedure to another.
//     This reminds me a discussion with "Grouflon" about how to organize a parser,
//     and a reflection tool. Should we provide a little reflection tool separate
//	   from the parser? Probably yes. But let's think about it again when a first
//     version of the serializer will be implemented.
//   

#module_parameters (DEBUG := true, VERBOSE := true)();

// internal
#load "src/xml.jai";
#load "src/json.jai";
#load "src/common.jai";

// external
#import "Hash_Table";
#import "Basic";
#import "Reflection";
#import "String";
#import "Print_Color";
#import "File";
