
main :: ()
{
	print("Running examples ...\n");
	defer print("Running examples (end)\n");

	print("======== example/00_quick_start ===========\n");

	run_00_quick_start();
	
	print("======== example/01_common_use ============\n");

	run_01_common_use();

	print("======== example/02_how_to_extend =========\n");

	run_02_how_to_extend();

}

#scope_file

// examples
#load "00_quick_start.jai";
#load "01_common_use.jai";
#load "02_how_to_extend.jai";

// Json Serializer Module
#import,file "../module.jai" (DEBUG=false); // turn this to true to get detailed logs

// Other Dependencies
#import "Basic";
#import "Hash_Table";