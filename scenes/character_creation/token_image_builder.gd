class_name TokenImageBuilder
extends RefCounted

const TOKEN_SIZE := 256

static func build(source: Texture2D, zoom: float = 1.0, offset: Vector2 = Vector2.ZERO) -> Texture2D:
	if source == null:
		return null
	var source_image := source.get_image()
	if source_image == null or source_image.is_empty():
		return source
	var source_size := source_image.get_size()
	var cover_scale: float = maxf(
		float(TOKEN_SIZE) / float(source_size.x),
		float(TOKEN_SIZE) / float(source_size.y)
	) * clampf(zoom, 0.5, 3.0)
	var fitted := source_image.duplicate()
	fitted.convert(Image.FORMAT_RGBA8)
	fitted.resize(
		maxi(1, roundi(source_size.x * cover_scale)),
		maxi(1, roundi(source_size.y * cover_scale)),
		Image.INTERPOLATE_LANCZOS
	)
	var output := Image.create(TOKEN_SIZE, TOKEN_SIZE, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	var destination := Vector2i(
		roundi((TOKEN_SIZE - fitted.get_width()) * 0.5 + offset.x),
		roundi((TOKEN_SIZE - fitted.get_height()) * 0.5 + offset.y)
	)
	output.blit_rect(fitted, Rect2i(Vector2i.ZERO, fitted.get_size()), destination)
	var center := Vector2(TOKEN_SIZE, TOKEN_SIZE) * 0.5
	var radius_squared := pow(TOKEN_SIZE * 0.5 - 1.0, 2.0)
	for y in range(TOKEN_SIZE):
		for x in range(TOKEN_SIZE):
			if Vector2(x + 0.5, y + 0.5).distance_squared_to(center) > radius_squared:
				output.set_pixel(x, y, Color.TRANSPARENT)
	return ImageTexture.create_from_image(output)
