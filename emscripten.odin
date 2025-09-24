#+build wasm32, wasm64p32

/*
This allocator uses the malloc, calloc, free and realloc procs that emscripten
exposes in order to allocate memory. Just like Odin's default heap allocator
this uses proper alignment, so that maps and simd works.
*/

package game

import "base:intrinsics"
import "core:c"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:strings"

// This will create bindings to emscripten's implementation of libc
// memory allocation features.
@(default_calling_convention = "c")
foreign _ {
	calloc :: proc(num, size: c.size_t) -> rawptr ---
	free :: proc(ptr: rawptr) ---
	malloc :: proc(size: c.size_t) -> rawptr ---
	realloc :: proc(ptr: rawptr, size: c.size_t) -> rawptr ---
}

emscripten_allocator :: proc "contextless" () -> mem.Allocator {
	return mem.Allocator{emscripten_allocator_proc, nil}
}

emscripten_allocator_proc :: proc(
	allocator_data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old_memory: rawptr,
	old_size: int,
	location := #caller_location,
) -> (
	data: []byte,
	err: mem.Allocator_Error,
) {
	// These aligned alloc procs are almost indentical those in
	// `_heap_allocator_proc` in `core:os`. Without the proper alignment you
	// cannot use maps and simd features.

	aligned_alloc :: proc(
		size, alignment: int,
		zero_memory: bool,
		old_ptr: rawptr = nil,
	) -> (
		[]byte,
		mem.Allocator_Error,
	) {
		a := max(alignment, align_of(rawptr))
		space := size + a - 1

		allocated_mem: rawptr
		if old_ptr != nil {
			original_old_ptr := mem.ptr_offset((^rawptr)(old_ptr), -1)^
			allocated_mem = realloc(original_old_ptr, c.size_t(space + size_of(rawptr)))
		} else if zero_memory {
			// calloc automatically zeros memory, but it takes a number + size
			// instead of just size.
			allocated_mem = calloc(c.size_t(space + size_of(rawptr)), 1)
		} else {
			allocated_mem = malloc(c.size_t(space + size_of(rawptr)))
		}
		aligned_mem := rawptr(mem.ptr_offset((^u8)(allocated_mem), size_of(rawptr)))

		ptr := uintptr(aligned_mem)
		aligned_ptr := (ptr - 1 + uintptr(a)) & -uintptr(a)
		diff := int(aligned_ptr - ptr)
		if (size + diff) > space || allocated_mem == nil {
			return nil, .Out_Of_Memory
		}

		aligned_mem = rawptr(aligned_ptr)
		mem.ptr_offset((^rawptr)(aligned_mem), -1)^ = allocated_mem

		return mem.byte_slice(aligned_mem, size), nil
	}

	aligned_free :: proc(p: rawptr) {
		if p != nil {
			free(mem.ptr_offset((^rawptr)(p), -1)^)
		}
	}

	aligned_resize :: proc(
		p: rawptr,
		old_size: int,
		new_size: int,
		new_alignment: int,
	) -> (
		[]byte,
		mem.Allocator_Error,
	) {
		if p == nil {
			return nil, nil
		}
		return aligned_alloc(new_size, new_alignment, true, p)
	}

	switch mode {
	case .Alloc:
		return aligned_alloc(size, alignment, true)

	case .Alloc_Non_Zeroed:
		return aligned_alloc(size, alignment, false)

	case .Free:
		aligned_free(old_memory)
		return nil, nil

	case .Resize:
		if old_memory == nil {
			return aligned_alloc(size, alignment, true)
		}

		bytes := aligned_resize(old_memory, old_size, size, alignment) or_return

		// realloc doesn't zero the new bytes, so we do it manually.
		if size > old_size {
			new_region := raw_data(bytes[old_size:])
			intrinsics.mem_zero(new_region, size - old_size)
		}

		return bytes, nil

	case .Resize_Non_Zeroed:
		if old_memory == nil {
			return aligned_alloc(size, alignment, false)
		}

		return aligned_resize(old_memory, old_size, size, alignment)

	case .Query_Features:
		set := (^mem.Allocator_Mode_Set)(old_memory)
		if set != nil {
			set^ = {.Alloc, .Free, .Resize, .Query_Features}
		}
		return nil, nil

	case .Free_All, .Query_Info:
		return nil, .Mode_Not_Implemented
	}
	return nil, .Mode_Not_Implemented
}


/*
This logger is largely a copy of the console logger in `core:log`, but it uses
emscripten's `puts` proc to write into he console of the web browser.

This is more or less identical to the logger in Aronicu's repository:
https://github.com/Aronicu/Raylib-WASM/tree/main
*/
Emscripten_Logger_Opts :: log.Options{.Level, .Short_File_Path, .Line}

create_emscripten_logger :: proc(lowest := log.Level.Debug, opt := Emscripten_Logger_Opts) -> log.Logger {
	return log.Logger{data = nil, procedure = logger_proc, lowest_level = lowest, options = opt}
}

// This create's a binding to `puts` which will be linked in as part of the
// emscripten runtime.
@(default_calling_convention = "c")
foreign _ {
	puts :: proc(buffer: cstring) -> c.int ---
}

@(private = "file")
logger_proc :: proc(
	logger_data: rawptr,
	level: log.Level,
	text: string,
	options: log.Options,
	location := #caller_location,
) {
	b := strings.builder_make(context.temp_allocator)
	strings.write_string(&b, Level_Headers[level])
	do_location_header(options, &b, location)
	fmt.sbprint(&b, text)

	if bc, bc_err := strings.to_cstring(&b); bc_err == nil {
		puts(bc)
	}
}

@(private = "file")
Level_Headers := [?]string {
	0 ..< 10 = "[DEBUG] --- ",
	10 ..< 20 = "[INFO ] --- ",
	20 ..< 30 = "[WARN ] --- ",
	30 ..< 40 = "[ERROR] --- ",
	40 ..< 50 = "[FATAL] --- ",
}

@(private = "file")
do_location_header :: proc(opts: log.Options, buf: ^strings.Builder, location := #caller_location) {
	if log.Location_Header_Opts & opts == nil {
		return
	}
	fmt.sbprint(buf, "[")
	file := location.file_path
	if .Short_File_Path in opts {
		last := 0
		for r, i in location.file_path {
			if r == '/' {
				last = i + 1
			}
		}
		file = location.file_path[last:]
	}

	if log.Location_File_Opts & opts != nil {
		fmt.sbprint(buf, file)
	}
	if .Line in opts {
		if log.Location_File_Opts & opts != nil {
			fmt.sbprint(buf, ":")
		}
		fmt.sbprint(buf, location.line)
	}

	if .Procedure in opts {
		if (log.Location_File_Opts | {.Line}) & opts != nil {
			fmt.sbprint(buf, ":")
		}
		fmt.sbprintf(buf, "%s()", location.procedure)
	}

	fmt.sbprint(buf, "] ")
}
