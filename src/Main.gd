extends Control

func _ready():

    $"ColorRectBackground".color = $"ColorRectBackground".color.lightened(0.25)
