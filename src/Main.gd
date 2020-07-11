extends Control

onready var INPUT_WASM_FILE_PATH: LineEdit = self.find_node("WasmFilePath", true, false)

onready var BUTTON_OPEN_WASM_FILE: Button = self.find_node("ButtonSelectWasmFile", true, false)

onready var UI_WASM_DISPLAY: Control = self.find_node("WasmModuleDisplayUI", true, false)


func _ready():

    $"ColorRectBackground".color = $"ColorRectBackground".color.lightened(0.25)

    BUTTON_OPEN_WASM_FILE.grab_focus()


func _on_ButtonSelectWasmFile_pressed() -> void:
    $"DialogSelectWasmFile".popup_centered_ratio()


func _on_DialogSelectWasmFile_file_selected(path: String) -> void:
    INPUT_WASM_FILE_PATH.text = path

    UI_WASM_DISPLAY.display_exploded_wasm_module(INPUT_WASM_FILE_PATH.text)


func _on_DialogSelectWasmFile_about_to_show() -> void:

    # Workaround (bug?) where window title seems to get reverted to default "open" value.

    $"DialogSelectWasmFile".window_title = "Select WASM File..."
