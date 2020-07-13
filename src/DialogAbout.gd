extends AcceptDialog

func _ready():
    self.get_close_button().visible = false

    # TODO: Handle this in a better place?
    var license_files: Array = self.dir_contents("res://licenses/")

    var license_texts: String = ""

    for current_path in license_files:

        var current_file: File = File.new()
        var err = current_file.open(current_path, File.READ)

        license_texts += "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~ %s ~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n" % current_path.get_file()

        if err == OK:
            license_texts += current_file.get_as_text()
        else:
            license_texts += "An error occurred when accessing this file."

        current_file.close()

    $"VBoxContainer/TextEdit".text = license_texts


func dir_contents(path: String):
    var files_found = []

    # Copy pasta from help documentation...
    var dir = Directory.new()
    if dir.open(path) == OK:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if dir.current_is_dir():
                pass
            elif not file_name.begins_with("."):
                files_found.append(path.plus_file(file_name))
            file_name = dir.get_next()
    else:
        push_error("An error occurred when trying to access the path.")

    return files_found
