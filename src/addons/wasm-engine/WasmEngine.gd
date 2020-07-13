
enum ExternKind {
  WASM_EXTERN_FUNC,
  WASM_EXTERN_GLOBAL,
  WASM_EXTERN_TABLE,
  WASM_EXTERN_MEMORY,
}


static func extern_kind_as_string(extern_kind_value) -> String:
    var result: String = "unknown"

    match extern_kind_value:

        ExternKind.WASM_EXTERN_FUNC:
            result = "function"

        ExternKind.WASM_EXTERN_GLOBAL:
            result = "global"

        ExternKind.WASM_EXTERN_TABLE:
            result = "table"

        ExternKind.WASM_EXTERN_MEMORY:
            result = "memory"

    return result


enum ValKind {
  WASM_I32,
  WASM_I64,
  WASM_F32,
  WASM_F64,
  WASM_ANYREF = 128,
  WASM_FUNCREF,
}

const ValKindAsString = {
  ValKind.WASM_I32: "WASM_I32",
  ValKind.WASM_I64: "WASM_I64",
  ValKind.WASM_F32: "WASM_F32",
  ValKind.WASM_F64: "WASM_F64",
  ValKind.WASM_ANYREF: "WASM_ANYREF",
  ValKind.WASM_FUNCREF: "WASM_FUNCREF",
}


class WasmEngine:
    extends Reference

    var _foreigner # Foreigner instance
    var _lib       # libwasmtime instance.
    var _op        # Dummy buffer to provide short name to access pointer-related OPerations

    var _engine
    var _default_store

    func _init():

        # TODO: Handle this better/properly?
        var Foreigner = preload('res://addons/wasm-engine/wasm-engine.gdns')

        # TODO: Handle this better? (And/or support resource paths in Foreigner.)
        var path_to_libwasmtime = Foreigner.library.get_current_dependencies()[0].trim_prefix("res://")

        var WasmEngine_Utils = preload('res://addons/wasm-engine/WasmEngine_Utils.gd')

        self._foreigner = Foreigner.new()
        self._lib  = self._foreigner.open(WasmEngine_Utils._get_correct_path(path_to_libwasmtime))

        if not self._lib:
            push_error("Unable to load libwasmtime library.")
            return

        # Provides a short name for access to pointer-related OPerations.
        # TODO: Change this in Foreigner?
        self._op = self._foreigner.new_buffer(32)

        self._configure_ffi()

        self._init_engine()


    func _configure_ffi():

        # TODO: Add more and/or generate from header file?

        # via <https://github.com/WebAssembly/wasm-c-api/blob/06e4871fbdad4990157516b642aebf43791a326e/include/wasm.h>

        self._lib.define("wasm_engine_new", "pointer", [])
        self._lib.define("wasm_store_new", "pointer", ["pointer"])

        self._lib.define("wasm_byte_vec_new_uninitialized", "void", ["pointer", "sint32"])

        self._lib.define("wasm_module_validate", "uchar", ["pointer", "pointer"])
        self._lib.define("wasm_module_new", "pointer", ["pointer", "pointer"])
        self._lib.define("wasm_module_exports", "void", ["pointer", "pointer"])
        self._lib.define("wasm_module_imports", "void", ["pointer", "pointer"])

        # Note: Does *not* return a char * so can't use "string" as return type.
        self._lib.define("wasm_exporttype_name", "pointer", ["pointer"])
        self._lib.define("wasm_exporttype_type", "pointer", ["pointer"])

        self._lib.define("wasm_importtype_name", "pointer", ["pointer"])
        self._lib.define("wasm_importtype_type", "pointer", ["pointer"])

        self._lib.define("wasm_externtype_kind", "uchar", ["pointer"])
        self._lib.define("wasm_externtype_as_functype", "pointer", ["pointer"])

        self._lib.define("wasm_functype_params", "pointer", ["pointer"])
        self._lib.define("wasm_functype_results", "pointer", ["pointer"])

        self._lib.define("wasm_valtype_kind", "uchar", ["pointer"])

        self._lib.define("wasm_instance_new", "pointer", ["pointer", "pointer", "pointer", "pointer"])
        self._lib.define("wasm_instance_exports", "void", ["pointer", "pointer"])

        self._lib.define("wasm_extern_kind", "uchar", ["pointer"])
        self._lib.define("wasm_extern_as_func", "pointer", ["pointer"])

        self._lib.define("wasm_func_call", "pointer", ["pointer", "pointer", "pointer"])


    func _init_engine():

        self._engine = self._lib.invoke("wasm_engine_new", [])

        if not self._engine:
            # TODO: Handle better/differently?
            push_error("Unable to create a new engine instance...")
            return

        # Multiple stores are possible but presumably most common case is
        # a single store, so we create one by default.
        self._default_store = self._lib.invoke("wasm_store_new", [self._engine])


    func load_wasm(wasm_binary: PoolByteArray):

        # TODO: Move all of this into a static method of `WasmModule`?
        # TODO: Decide how much of "module" vs "module instance" difference to expose.

        var byte_vec = self._foreigner.new_buffer(32)

        # void wasm_byte_vec_new_uninitialized(&bytecode, bytecode_len);
        self._lib.invoke("wasm_byte_vec_new_uninitialized", [byte_vec, wasm_binary.size()])

        var op = self._op # meh
        op.memcpy(op.deref(op.offset(byte_vec.ptr(), 8)), wasm_binary)

        # bool wasm_module_validate(the_store, &bytecode)
        var module_is_valid = self._lib.invoke("wasm_module_validate", [self._default_store, byte_vec])

        if not module_is_valid:
            push_error("Module validation failed.")
            return

        var new_module_ptr = self._lib.invoke("wasm_module_new", [self._default_store, byte_vec])

        # TODO: wasm_byte_vec_delete(&bytecode);

        return WasmModule.new(new_module_ptr, self)


    func load_wasm_from_file(wasm_filepath: String):

        # TODO: Move all of this into a static method of `WasmModule`?

        var file = File.new()

        var err = file.open(wasm_filepath, File.READ)
        if err:
            push_error("Failed to open WASM file. Error number: %d\n" % [err] +
                       "  See: https://github.com/godotengine/godot/blob/master/core/error_list.h#L%d" % [42+err])
            return

        var file_content: PoolByteArray = file.get_buffer(file.get_len())

        file.close()

        return self.load_wasm(file_content)



#
# The use of this class is basically a work-around for the fact
# that inner classes can't easily refer to the outer class in
# which they are defined. *hand wave*
#
class WasmEngineClassesBase:
    extends Reference

    var _op
    var _lib
    var _engine
    var _foreigner

    func _init(_engine_):

        self._engine = _engine_ # TODO: Changing naming re: WasmEngine vs wasm_engine instance.

        self._op = self._engine._op
        self._lib = self._engine._lib

        self._foreigner = self._engine._foreigner



class WasmVec:
    extends WasmEngineClassesBase

    var base_ptr: int = 0
    var data_ptr: int = 0

    func _init(the_base_ptr: int, _engine_).(_engine_):
        # TODO: Allow ForeignBuffer to be supplied & call `.ptr()` ourselves?
        self.base_ptr = the_base_ptr

        self.data_ptr = self._op.offset(self.base_ptr, 8)

    func size():
        return self._op.deref(self.base_ptr) # Hacky! TODO: Be less hacky.



class WasmVecName:
    extends WasmVec

    func _init(the_base_ptr: int, _engine_).(the_base_ptr, _engine_):
        pass

    func as_string(): # `_to_string()` is an option but it seems more for debug.
        return self._op.string_at(self._op.deref(self.data_ptr), self.size())

    func get_index(index):
        return self.as_string()[index]



class WasmExportType:
    extends WasmEngineClassesBase

    var base_ptr: int = 0

    var name: String

    var type

    var _meta = {} # This is an interim solution until the type/class handling is reworked.

    func _init(the_base_ptr: int, _engine_).(_engine_):
        # TODO: Allow ForeignBuffer to be supplied & call `.ptr()` ourselves?
        self.base_ptr = the_base_ptr

        var wasm_name_ptr = self._lib.invoke("wasm_exporttype_name", [self.base_ptr])
        self.name = WasmVecName.new(wasm_name_ptr, self._engine).as_string()

        var exporttype_ptr = self._lib.invoke("wasm_exporttype_type", [self.base_ptr])
        self.type = self._lib.invoke("wasm_extern_kind", [exporttype_ptr])

        if self.type == ExternKind.WASM_EXTERN_FUNC:

            var functype_ptr = self._lib.invoke("wasm_externtype_as_functype", [exporttype_ptr])
            if functype_ptr == 0:
                push_error("Could not treat the export as a function.")
                return

            var params_vec_ptr = self._lib.invoke("wasm_functype_params", [functype_ptr])
            if params_vec_ptr == 0:
                push_error("Null pointer encountered.")
                return

            var params = WasmVecValType.new(params_vec_ptr, self._engine)

            var param_info = []

            for param_index in range(params.size()):
                var current_param = params.get_index(param_index)
                param_info.append(current_param.kind)

            self._meta["params"] = param_info


            var results_vec_ptr = self._lib.invoke("wasm_functype_results", [functype_ptr])
            if results_vec_ptr == 0:
                push_error("Null pointer encountered.")
                return

            var results = WasmVecValType.new(results_vec_ptr, self._engine)

            var result_info = []

            for result_index in range(results.size()):
                var current_result = results.get_index(result_index)
                result_info.append(current_result.kind)

            self._meta["results"] = result_info



class WasmVecExportType:
    extends WasmVec

    func _init(the_base_ptr: int, _engine_).(the_base_ptr, _engine_):
        pass

    func get_index(index):
        #
        # Note: The `data` member of the underlying vectors defined by `WASM_DECLARE_VEC`
        #       can either be:
        #
        #         * A pointer to a type (e.g. "byte"); or,
        #
        #         * A pointer to a pointer to a type (e.g. "name").
        #
        #       This affects how we retrieve an "item at the index" as the
        #       underlying vector may be:
        #
        #         * A vector of pointers to items; or,
        #
        #         * A vector of pointers to pointers to items.
        #
        #       ...or something vaguely like that.
        #
        #       TODO: Clarify this better & move comment to `WasmVec` class.
        #

        var pointer_to_pointer_at_index = self._op.offset(self._op.deref(self.data_ptr), 8 * index)
        var pointer_to_item = self._op.deref(pointer_to_pointer_at_index)

        return WasmExportType.new(pointer_to_item, self._engine)



class WasmVecValType:
    extends WasmVec

    func _init(the_base_ptr: int, _engine_).(the_base_ptr, _engine_):
        pass

    func get_index(index):
        #
        # Note: The `data` member of the underlying vectors defined by `WASM_DECLARE_VEC`
        #       can either be:
        #
        #         * A pointer to a type (e.g. "byte"); or,
        #
        #         * A pointer to a pointer to a type (e.g. "name").
        #
        #       This affects how we retrieve an "item at the index" as the
        #       underlying vector may be:
        #
        #         * A vector of pointers to items; or,
        #
        #         * A vector of pointers to pointers to items.
        #
        #       ...or something vaguely like that.
        #
        #       TODO: Clarify this better & move comment to `WasmVec` class.
        #

        var pointer_to_pointer_at_index = self._op.offset(self._op.deref(self.data_ptr), 8 * index)
        var pointer_to_item = self._op.deref(pointer_to_pointer_at_index)

        return WasmValType.new(pointer_to_item, self._engine)


class WasmValType:
    extends WasmEngineClassesBase

    var base_ptr: int = 0

    var kind

    func _init(the_base_ptr: int, _engine_).(_engine_):
        # TODO: Allow ForeignBuffer to be supplied & call `.ptr()` ourselves?
        self.base_ptr = the_base_ptr

        self.kind = self._lib.invoke("wasm_valtype_kind", [self.base_ptr])


# TODO: Don't duplicate the common functionality between WasmImport/ExportType?
class WasmImportType:
    extends WasmEngineClassesBase

    var base_ptr: int = 0

    var name: String

    var type

    var _meta = {} # This is an interim solution until the type/class handling is reworked.

    func _init(the_base_ptr: int, _engine_).(_engine_):
        # TODO: Allow ForeignBuffer to be supplied & call `.ptr()` ourselves?
        self.base_ptr = the_base_ptr

        var wasm_name_ptr = self._lib.invoke("wasm_importtype_name", [self.base_ptr])
        self.name = WasmVecName.new(wasm_name_ptr, self._engine).as_string()

        var importtype_ptr = self._lib.invoke("wasm_importtype_type", [self.base_ptr])
        type = self._lib.invoke("wasm_extern_kind", [importtype_ptr])


        if self.type == ExternKind.WASM_EXTERN_FUNC:

            var functype_ptr = self._lib.invoke("wasm_externtype_as_functype", [importtype_ptr])
            if functype_ptr == 0:
                push_error("Could not treat the import as a function.")
                return

            var params_vec_ptr = self._lib.invoke("wasm_functype_params", [functype_ptr])
            if params_vec_ptr == 0:
                push_error("Null pointer encountered.")
                return

            var params = WasmVecValType.new(params_vec_ptr, self._engine)

            var param_info = []

            for param_index in range(params.size()):
                var current_param = params.get_index(param_index)
                param_info.append(current_param.kind)

            self._meta["params"] = param_info


            var results_vec_ptr = self._lib.invoke("wasm_functype_results", [functype_ptr])
            if results_vec_ptr == 0:
                push_error("Null pointer encountered.")
                return

            var results = WasmVecValType.new(results_vec_ptr, self._engine)

            var result_info = []

            for result_index in range(results.size()):
                var current_result = results.get_index(result_index)
                result_info.append(current_result.kind)

            self._meta["results"] = result_info



class WasmVecImportType:
    extends WasmVec

    func _init(the_base_ptr: int, _engine_).(the_base_ptr, _engine_):
        pass

    func get_index(index):
        #
        # Note: The `data` member of the underlying vectors defined by `WASM_DECLARE_VEC`
        #       can either be:
        #
        #         * A pointer to a type (e.g. "byte"); or,
        #
        #         * A pointer to a pointer to a type (e.g. "name").
        #
        #       This affects how we retrieve an "item at the index" as the
        #       underlying vector may be:
        #
        #         * A vector of pointers to items; or,
        #
        #         * A vector of pointers to pointers to items.
        #
        #       ...or something vaguely like that.
        #
        #       TODO: Clarify this better & move comment to `WasmVec` class.
        #

        var pointer_to_pointer_at_index = self._op.offset(self._op.deref(self.data_ptr), 8 * index)
        var pointer_to_item = self._op.deref(pointer_to_pointer_at_index)

        return WasmImportType.new(pointer_to_item, self._engine)



const SIZE_wasm_extern_vec_t: int = 32 # TODO: Calculate actual size.

class WasmModule:
    extends WasmEngineClassesBase

    var _module_ptr: int

    var _instanced_module_ptr

    var _module_exports
    var _module_imports

    var _instanced_exports

    var _imports_ptr: int = 0 # nullptr for now.


    var exports
    var imports

    var _exported_functions = {}


    func _init(the_module_ptr: int, _engine_).(_engine_):
        self._module_ptr = the_module_ptr

        self._module_exports = self._foreigner.new_buffer(32)

        # WASM_API_EXTERN void wasm_module_exports(const wasm_module_t*, own wasm_exporttype_vec_t* out);
        self._lib.invoke("wasm_module_exports", [self._module_ptr, self._module_exports])

        # TODO: Expose via a wrapper class?
        # TODO: Either don't create a new instance of each export each time or generate all at once?
        self.exports = WasmVecExportType.new(self._module_exports.ptr(), self._engine)


        self._module_imports = self._foreigner.new_buffer(32)

        # WASM_API_EXTERN void wasm_module_imports(const wasm_module_t*, own wasm_importtype_vec_t* out);
        self._lib.invoke("wasm_module_imports", [self._module_ptr, self._module_imports])

        # TODO: Expose via a wrapper class?
        self.imports = WasmVecImportType.new(self._module_imports.ptr(), self._engine)


        if self.imports.size() > 0:
            push_warning("Import support not yet implemented.")
            # TODO: Handle differently?
            return

        # TODO: Don't instance until later?
        self._instanced_module_ptr = self._lib.invoke("wasm_instance_new", [self._engine._default_store, self._module_ptr, self._imports_ptr, 0]) # TODO: Supply trap argument. *hihat triplet*

        if self._instanced_module_ptr == 0:
            push_error("Failed to instance module.")
            # TODO: Handle differently?
            return


        # TODO: Rework this to have a `WasmExport` or `WasmFunction` class to wrap the instances?

        self._instanced_exports = self._foreigner.new_buffer(SIZE_wasm_extern_vec_t)

        self._lib.invoke("wasm_instance_exports", [self._instanced_module_ptr, self._instanced_exports.ptr()])

        #prints("    buffer:", self._instanced_exports.hex_encode_buffer())

        var __op = self._op

        for export_index in range(self.exports.size()):
            var current_export = self.exports.get_index(export_index) # TODO: Figure out why intermediate variable needed to avoid crash..?

            if current_export.type != ExternKind.WASM_EXTERN_FUNC:
                # TODO: Handle other export types?
                continue

            # TODO: Create a WasmVec sub-class for this?
            # TODO: Don't use magic numbers for offset/type sizes.
            var current_export_instanced_ptr = __op.deref(__op.offset(__op.deref(__op.offset(self._instanced_exports.ptr(), 8)), 8 * export_index))
            #print("    current_export_instanced_ptr: 0x%08x" % current_export_instanced_ptr)

            # TODO: Figure out if this is (a) redundant & (b) correct way to handle this.
            var export_type = self._lib.invoke("wasm_extern_kind", [current_export_instanced_ptr])

            if current_export.type != export_type:
                push_error("Export type mismatch.")
                # TODO: Handle differently?
                return


            # For our purposes this seems like it might be a bit redundant as it primarily
            # seems to be used to "launder" (i.e. cast) the pointer from the generic extern type
            # to the specific type (e.g. function). (It doesn't seem to change the pointer value.)
            #
            # It *does* however seem to include some typechecking and will return a null pointer
            # if the type of the extern *isn't* the requested target type (e.g. function).
            #
            var _instanced_function_ptr = self._lib.invoke("wasm_extern_as_func", [current_export_instanced_ptr])
            #prints("    _instanced_function_ptr:", "0x%08x" % _instanced_function_ptr)

            if _instanced_function_ptr == 0:
                push_error("Unable to instance function.")
                # TODO: Handle differently?
                #return
                continue

            self._exported_functions[current_export.name] = _instanced_function_ptr # TODO: Use a class for this?


    # TODO: This should really be in a `WasmExport` or `WasmFunction` class maybe?
    # TODO: Handle supplied arguments.
    func call_function(function_name: String):

        var _instanced_function_ptr = self._exported_functions[function_name]

        if _instanced_function_ptr == 0:
            push_error("Null pointer encountered.")
            return

        # wasm_val_t results[1];
        # wasm_trap_t *it_is_a_trap = wasm_func_call(the_func, NULL, results);

        var results_buffer = self._foreigner.new_buffer(32) # TODO: Handle size

        var returned_trap_ptr = self._lib.invoke("wasm_func_call", [_instanced_function_ptr, 0, results_buffer.ptr()])
        #prints("    returned_trap_ptr:", returned_trap_ptr)
        #prints("       results_buffer:", results_buffer.hex_encode_buffer())

        if returned_trap_ptr != 0:
            # TODO: Handle this properly.
            push_error("An error occurred.")
            return

        # TODO: Handle return value types properly. (Currently only handles uint32_t?)
        # TODO: Retrieve return value properly.
        var __op = self._op
        var the_return_value = int(__op.deref(__op.offset(results_buffer.ptr(), 8))) # TODO: Don't do this!
        #prints("     the_return_value:", "0x%08x" % the_return_value, ["",char(the_return_value)][int(the_return_value<0xff)])

        return the_return_value
