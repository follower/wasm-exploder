extends Control

var wasm = preload("res://addons/wasm-engine/WasmEngine.gd") # TODO: Handle properly
var wasm_engine
var module


func _ready():

    wasm_engine = wasm.WasmEngine.new()


# TODO: Pass loaded module instead?
func display_exploded_wasm_module(wasm_file_path: String):

    prints("Selected file:", wasm_file_path)
