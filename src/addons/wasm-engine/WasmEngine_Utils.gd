# Renamed from `Utils.gd` to avoid clashes with other instances.

extends Reference

# TODO: Handle situation where `File.file_exists()`/`FileAccess::exists()` check
#       actually breaks shared library loading once exported. (Particularly Windows/WINE.)
# TODO: Handle this within Foreigner?
static func _get_correct_path(the_path) -> String:
    #
    # Handle path variations that occur on export when not using Godot resource
    # paths.
    #

    var f = File.new()

    if !f.file_exists(the_path):
        the_path = OS.get_executable_path().get_base_dir().plus_file(the_path.get_file())

    # TODO: Add other (per-platform) variants.

# via <https://github.com/godotengine/godot/blob/416cd715a3f51b7d74676fa7d4c8e34c3c2823c9/platform/osx/os_osx.mm#L1789-L1806>
#    String path = p_path;
#
#    if (!FileAccess::exists(path)) {
#        //this code exists so gdnative can load .dylib files from within the executable path
#        path = get_executable_path().get_base_dir().plus_file(p_path.get_file());
#    }
#
#    if (!FileAccess::exists(path)) {
#        //this code exists so gdnative can load .dylib files from a standard macOS location
#        path = get_executable_path().get_base_dir().plus_file("../Frameworks").plus_file(p_path.get_file());
#    }

    if !f.file_exists(the_path):
        the_path = OS.get_executable_path().get_base_dir().plus_file("../Frameworks").plus_file(the_path.get_file())

    return the_path
