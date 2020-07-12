extends Control

onready var UI_EXTERN_LIST: Tree = self.find_node("ExternList", true, false)


var wasm = preload("res://addons/wasm-engine/WasmEngine.gd") # TODO: Handle properly
var wasm_engine
var module


# TODO: Export `wasm_file_path` instead?

func _ready():

    self._resetDetailView()

    wasm_engine = wasm.WasmEngine.new()


const MAX_EXPORTS_TO_DISPLAY: int = 200
const MAX_IMPORTS_TO_DISPLAY: int = MAX_EXPORTS_TO_DISPLAY

# TODO: Pass loaded module instead?
func display_exploded_wasm_module(wasm_file_path: String):

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
        current_item.set_metadata(0, current_export)

        # TODO: Use an icon?
        var current_item_type_indicator = wasm.extern_kind_as_string(current_export.type).substr(0,1).to_upper()
        current_item.set_tooltip(1, wasm.extern_kind_as_string(current_export.type))
        current_item.set_text(1, "%s" % [current_item_type_indicator])

    if MAX_EXPORTS_TO_DISPLAY < module.exports.size():
        var current_item: TreeItem = UI_EXTERN_LIST.create_item(exports_item)
        current_item.set_text(0, "...")
        current_item.set_text_align(0, TreeItem.ALIGN_CENTER)

    UI_EXTERN_LIST.grab_focus()
    exports_item.select(0)


    for index in range(min(MAX_IMPORTS_TO_DISPLAY, module.imports.size())):

        var current_import = module.imports.get_index(index)

        var current_item: TreeItem = UI_EXTERN_LIST.create_item(imports_item)
        current_item.set_text(0, current_import.name)
        current_item.set_metadata(0, current_import)

        # TODO: Use an icon?
        var current_item_type_indicator = wasm.extern_kind_as_string(current_import.type).substr(0,1).to_upper()
        current_item.set_tooltip(1, wasm.extern_kind_as_string(current_import.type))
        current_item.set_text(1, "%s" % [current_item_type_indicator])

    if MAX_IMPORTS_TO_DISPLAY < module.imports.size():
        var current_item: TreeItem = UI_EXTERN_LIST.create_item(imports_item)
        current_item.set_text(0, "...")
        current_item.set_text_align(0, TreeItem.ALIGN_CENTER)


    self.find_parent("MainUI").get_node("DialogBusyOverlay").hide()


func _resetDetailView():

    $"DetailView/LabelParamTypes".visible = false
    $"DetailView/LabelType".visible = true

    $"DetailView/HBoxContainer/LabelResultTypes".text = ""
    $"DetailView/HBoxContainer/LabelName".text = ""
    $"DetailView/LabelType".text = ""
    $"DetailView/LabelParamTypes".text = ""


func _on_ExternList_item_selected() -> void:

    var selected_tree_item = UI_EXTERN_LIST.get_next_selected(null)

    self._resetDetailView()

    var extern_item = selected_tree_item.get_metadata(0)

    if extern_item == null:
        # TODO: Show summary when file name & section titles selected?
        return

    var _meta: Dictionary = extern_item._meta

    $"DetailView/HBoxContainer/LabelName".text = "%s" % extern_item.name
    $"DetailView/LabelType".text = "Type: %s" % wasm.extern_kind_as_string(extern_item.type)
