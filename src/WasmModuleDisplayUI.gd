extends Control

onready var UI_EXTERN_LIST: Tree = self.find_node("ExternList", true, false)


var wasm = preload("res://addons/wasm-engine/WasmEngine.gd") # TODO: Handle properly
var wasm_engine
var module


# TODO: Export `wasm_file_path` instead?

func _ready():

    wasm_engine = wasm.WasmEngine.new()


const MAX_EXPORTS_TO_DISPLAY: int = 20
const MAX_IMPORTS_TO_DISPLAY: int = MAX_EXPORTS_TO_DISPLAY

# TODO: Pass loaded module instead?
func display_exploded_wasm_module(wasm_file_path: String):

    prints("Selected file:", wasm_file_path)

    UI_EXTERN_LIST.clear()

    UI_EXTERN_LIST.set_column_min_width(0, 8)
    UI_EXTERN_LIST.set_column_min_width(1, 2)
    UI_EXTERN_LIST.set_column_expand(0, true)
    UI_EXTERN_LIST.set_column_expand(1, true)

    var root: TreeItem = UI_EXTERN_LIST.create_item()
    root.set_text(0, wasm_file_path.get_file())
    root.set_tooltip(0, wasm_file_path)


    # TODO: Handle WASM in background thread?
    yield(self.find_parent("MainUI").get_node("DialogBusyOverlay").show(), "completed")

    module = wasm_engine.load_wasm_from_file(wasm_file_path)


    var exports_item: TreeItem = UI_EXTERN_LIST.create_item(root)
    exports_item.set_text(0, "Exports (%d)" % module.exports.size())

    var imports_item: TreeItem = UI_EXTERN_LIST.create_item(root)
    imports_item.set_text(0, "Imports (%d)" % module.imports.size())


    for index in range(min(MAX_EXPORTS_TO_DISPLAY, module.exports.size())):

        var current_export = module.exports.get_index(index)

        var current_item: TreeItem = UI_EXTERN_LIST.create_item(exports_item)
        current_item.set_text(0, current_export.name)

        # TODO: Use an icon?
        var current_item_type_indicator = wasm.extern_kind_as_string(current_export.type).substr(0,1).to_upper()
        current_item.set_tooltip(1, wasm.extern_kind_as_string(current_export.type))
        current_item.set_text(1, "%s" % [current_item_type_indicator])

    UI_EXTERN_LIST.grab_focus()
    exports_item.select(0)


    for index in range(min(MAX_IMPORTS_TO_DISPLAY, module.imports.size())):

        var current_import = module.imports.get_index(index)

        var current_item: TreeItem = UI_EXTERN_LIST.create_item(imports_item)
        current_item.set_text(0, current_import.name)

        # TODO: Use an icon?
        var current_item_type_indicator = wasm.extern_kind_as_string(current_import.type).substr(0,1).to_upper()
        current_item.set_tooltip(1, wasm.extern_kind_as_string(current_import.type))
        current_item.set_text(1, "%s" % [current_item_type_indicator])



    self.find_parent("MainUI").get_node("DialogBusyOverlay").hide()
