#+build windows
package main

import "core:fmt"
import "core:os"
import os2 "core:os/os2"

// Windows layout build. The phone build does not compile this file.
// Art stays in GlomRemastered/resources; this looks beside the exe, in the
// working directory, then in that sibling folder.

find_asset_root_desktop :: proc() -> string {
	exe_dir, err := os2.get_executable_directory(context.allocator)
	if err == nil {
		probe := fmt.tprintf("%s/resources/glom.png", exe_dir)
		if os.exists(probe) {
			return exe_dir
		}
		delete(exe_dir)
	}
	cwd := os.get_current_directory(context.allocator)
	probe := fmt.tprintf("%s/resources/glom.png", cwd)
	if os.exists(probe) {
		return cwd
	}
	rel := fmt.aprintf("%s/../GlomRemastered", cwd)
	probe = fmt.tprintf("%s/resources/glom.png", rel)
	if os.exists(probe) {
		delete(cwd)
		return rel
	}
	delete(rel)
	return cwd
}
