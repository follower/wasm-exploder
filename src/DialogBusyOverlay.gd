#
# This is all pretty much just a workaround for the lack of
# a Mac busy cursor... *sigh*
#

# TODO: Add lack of certain Mac cursors to docs.
# TODO: Look at adding the "private" Mac busy cursor?

extends ColorRect


func _ready():

    if OS.get_name() == "OSX":
        self.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN


func show():
    #
    # Must be called like:
    #
    #    yield(self.find_parent("MainUI").get_node("DialogBusyOverlay").show(), "completed")
    #

    self.visible = true

    # Necessary for cursor image to get updated correctly.
    yield(VisualServer, "frame_post_draw")

    Input.set_default_cursor_shape(self.mouse_default_cursor_shape)

    # Note: Sometimes the following was required (maybe when `.show()` call wasn't a yield?).
    #
    ## Necessary for overlay to display correctly.
    # yield(VisualServer, "frame_post_draw")


func hide():

    self.visible = false
    Input.set_default_cursor_shape(Input.CURSOR_ARROW)
