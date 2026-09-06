extends SceneTree
## Real renderer capture: run without --headless. Does not modify gameplay.
func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.content_scale_size = Vector2i(1280, 720)
	var wizard = load("res://scenes/character_creation/CharacterCreation.tscn").instantiate()
	wizard.auto_start_combat = false
	root.add_child(wizard)
	wizard.furthest_step = 6
	wizard.show_step(2)
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/creation-class-preview.png")
	wizard.show_step(0)
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/creation-identity-preview.png")
	for index in [3, 4, 5, 6]:
		wizard.show_step(index)
		for frame in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://work/creation-%s-preview.png" % wizard.catalog.steps[index].id)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	wizard.show_step(2)
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/creation-class-fullhd.png")
	wizard.queue_free()
	await process_frame
	quit()
