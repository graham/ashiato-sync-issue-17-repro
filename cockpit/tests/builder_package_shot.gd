extends Node
## A visual record of the builder iPad's package actions.  Run windowed, never headless.
const OUT := "user://builder_package.png"
func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var page := ClipboardPage.new()
	page.size = Vector2(1024, 1280)
	page.position = Vector2(20, 20)
	layer.add_child(page)
	page.show_tab(ClipboardPage.Tab.BUILD)
	for frame in range(4): await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(OUT)
	print("[builder_package_shot] %s -> %s" % ["saved" if err == OK else "FAILED", ProjectSettings.globalize_path(OUT)])
	get_tree().quit(0 if err == OK else 1)
