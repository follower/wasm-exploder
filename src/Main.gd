extends Control

onready var INPUT_WASM_FILE_PATH: LineEdit = self.find_node("WasmFilePath", true, false)

onready var BUTTON_OPEN_WASM_FILE: Button = self.find_node("ButtonSelectWasmFile", true, false)

onready var UI_WASM_DISPLAY: Control = self.find_node("WasmModuleDisplayUI", true, false)


func _ready():

    BUTTON_OPEN_WASM_FILE.grab_focus()

    # Workaround `grab_focus()` apparently also causing `hover` style to display.
    # TODO: Handle elsewhere and/or better?
    BUTTON_OPEN_WASM_FILE.notification(BUTTON_OPEN_WASM_FILE.NOTIFICATION_MOUSE_EXIT)


func _on_ButtonSelectWasmFile_pressed() -> void:
    $"DialogSelectWasmFile".popup_centered_ratio()


func _on_DialogSelectWasmFile_file_selected(path: String) -> void:
    INPUT_WASM_FILE_PATH.text = path

    UI_WASM_DISPLAY.display_exploded_wasm_module(INPUT_WASM_FILE_PATH.text)


func _on_DialogSelectWasmFile_about_to_show() -> void:

    # Workaround (bug?) where window title seems to get reverted to default "open" value.

    $"DialogSelectWasmFile".window_title = "Select WASM File..."


func _on_LabelAboutLink_gui_input(event: InputEvent) -> void:

    if event is InputEventMouseButton:
        if event.pressed and event.button_index == BUTTON_LEFT:
            get_tree().set_input_as_handled()
            $"DialogAbout".popup_centered_ratio()
