extends Control

onready var INPUT_WASM_FILE_PATH: LineEdit = self.find_node("WasmFilePath", true, false)

onready var BUTTON_OPEN_WASM_FILE: Button = self.find_node("ButtonSelectWasmFile", true, false)


func _ready():

    $"ColorRectBackground".color = $"ColorRectBackground".color.lightened(0.25)

    BUTTON_OPEN_WASM_FILE.grab_focus()


func _on_ButtonSelectWasmFile_pressed() -> void:
    $"DialogSelectWasmFile".popup_centered_ratio()


func _on_DialogSelectWasmFile_file_selected(path: String) -> void:
    INPUT_WASM_FILE_PATH.text = path
