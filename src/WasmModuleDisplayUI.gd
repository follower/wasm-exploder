extends Control

onready var UI_EXTERN_LIST: Tree = self.find_node("ExternList", true, false)


var wasm = preload("res://addons/wasm-engine/WasmEngine.gd") # TODO: Handle properly
var wasm_engine
var module


func _ready():

    wasm_engine = wasm.WasmEngine.new()


# TODO: Pass loaded module instead?
func display_exploded_wasm_module(wasm_file_path: String):

    prints("Selected file:", wasm_file_path)

    UI_EXTERN_LIST.clear()

    var root: TreeItem = UI_EXTERN_LIST.create_item()
    root.set_text(0, wasm_file_path.get_file())
    root.set_tooltip(0, wasm_file_path)
