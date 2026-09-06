extends Control
## Reusable shell. Embedded users set auto_start_combat=false and handle the signal.
signal character_created(character: CharacterData)
signal creation_cancelled

const UI = preload("res://scenes/character_creation/creation_widgets.gd")
@export var catalog: Resource = preload("res://data/creation/default_creation_catalog.tres")
@export var draft_script: Script = preload("res://scenes/character_creation/creation_draft.gd")
@export var pages_script: Script = preload("res://scenes/character_creation/creation_pages.gd")
@export var auto_start_combat: bool = true
@export_file("*.tscn") var destination_scene: String = "res://scenes/prototype/PrototypeCombat.tscn"

var draft
var pages
var step_index: int = 0
var furthest_step: int = 0
var step_buttons: Array[Button] = []
var left: VBoxContainer
var center: VBoxContainer
var summary_column: VBoxContainer
var footer_message: Label
var next_button: Button
var back_button: Button
var focused_ability_id: String = ""
var focused_item
var ability_filter: int = 0
var ability_search: String = ""

func _ready() -> void:
	theme = UI.make_theme()
	draft = draft_script.new()
	draft.setup(catalog)
	pages = pages_script.new()
	build_shell()
	show_step(0)

func build_shell() -> void:
	var background := ColorRect.new()
	background.color = UI.INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var layout := UI.column(margin, 16)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	layout.add_child(header)
	var brand := UI.column(header, 3)
	brand.custom_minimum_size.x = 268
	brand.size_flags_horizontal = Control.SIZE_FILL
	UI.label(brand, "PROJECT ARTRON", 15, UI.GOLD, true)
	UI.label(brand, "CREATE CHARACTER", 22, UI.PAPER, true)
	var step_scroll := ScrollContainer.new()
	step_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	header.add_child(step_scroll)
	var navigation := HBoxContainer.new()
	navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_theme_constant_override("separation", 10)
	step_scroll.add_child(navigation)
	for index in range(catalog.steps.size()):
		var step: Dictionary = catalog.steps[index]
		var node := UI.button(navigation, "%02d\n%s" % [index + 1, step.title], func(): navigate(index))
		node.add_theme_font_size_override("font_size", 12)
		node.custom_minimum_size = Vector2(84, 64)
		step_buttons.append(node)
	UI.line(layout)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	layout.add_child(body)
	var list_panel := UI.panel(body)
	list_panel.custom_minimum_size.x = 240
	left = UI.scroll_column(list_panel)
	var detail_panel := UI.panel(body)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center = UI.scroll_column(detail_panel)
	center.add_theme_constant_override("separation", 10)
	var summary_panel := UI.panel(body)
	summary_panel.custom_minimum_size.x = 278
	summary_column = UI.scroll_column(summary_panel)
	summary_column.add_theme_constant_override("separation", 7)
	UI.line(layout)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 18)
	layout.add_child(footer)
	back_button = UI.button(footer, "BACK", go_back)
	back_button.custom_minimum_size.x = 190
	back_button.size_flags_horizontal = Control.SIZE_FILL
	footer_message = UI.label(footer, "", 14, UI.MUTED)
	footer_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	next_button = UI.button(footer, "CONTINUE", go_next, true)
	next_button.custom_minimum_size.x = 265
	next_button.size_flags_horizontal = Control.SIZE_FILL

func navigate(index: int) -> void:
	if index <= furthest_step:
		show_step(index)

func show_step(index: int) -> void:
	step_index = clampi(index, 0, catalog.steps.size() - 1)
	UI.clear(left)
	UI.clear(center)
	var renderer := "build_" + String(catalog.steps[step_index].id)
	if pages.has_method(renderer):
		pages.call(renderer, self)
	else:
		UI.label(center, "This step has no page renderer.", 22, UI.GOLD)
	refresh_summary()
	refresh_navigation()

func refresh() -> void:
	show_step(step_index)

func choose_custom_portrait() -> void:
	var dialog := FileDialog.new()
	dialog.title = "Choose Character Image"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Image Files"])
	dialog.file_selected.connect(func(path: String):
		var image := Image.new()
		var error := image.load(path)
		if error != OK or image.is_empty():
			draft.notice = "Could not load that image. Choose a PNG, JPG or WebP file."
			refresh_navigation()
		else:
			draft.notice = "Custom portrait selected."
			draft.set_custom_portrait(ImageTexture.create_from_image(image), path)
			refresh()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered_ratio(0.75)

func go_next() -> void:
	var reason: String = draft.step_error(catalog.steps[step_index].id)
	if not reason.is_empty():
		footer_message.text = reason
		return
	if step_index == catalog.steps.size() - 1:
		confirm_character()
		return
	furthest_step = maxi(furthest_step, step_index + 1)
	show_step(step_index + 1)

func go_back() -> void:
	if step_index == 0:
		if not auto_start_combat:
			creation_cancelled.emit()
			return
		var confirm := ConfirmationDialog.new()
		confirm.title = "Start a new character?"
		confirm.dialog_text = "Discard the current draft and start again?"
		confirm.confirmed.connect(func():
			draft = draft_script.new()
			draft.setup(catalog)
			furthest_step = 0
			focused_ability_id = ""
			focused_item = null
			show_step(0)
			confirm.queue_free())
		confirm.canceled.connect(confirm.queue_free)
		add_child(confirm)
		confirm.popup_centered(Vector2i(410, 130))
	else:
		show_step(step_index - 1)

func refresh_navigation() -> void:
	for index in range(step_buttons.size()):
		var current := index == step_index
		step_buttons[index].disabled = index > furthest_step
		step_buttons[index].add_theme_stylebox_override("normal", UI.box(Color("#29291e") if current else UI.INK, UI.GOLD if current else Color("#373c34"), 2 if current else 1))
	back_button.text = ("START OVER" if auto_start_combat else "CANCEL") if step_index == 0 else "‹  BACK: " + String(catalog.steps[step_index - 1].title)
	next_button.text = "CREATE CHARACTER  ›" if step_index == catalog.steps.size() - 1 else "CONTINUE: " + String(catalog.steps[step_index + 1].title) + "  ›"
	var reason: String = draft.validation_error() if step_index == catalog.steps.size() - 1 else draft.step_error(catalog.steps[step_index].id)
	next_button.disabled = not reason.is_empty()
	footer_message.text = reason if not reason.is_empty() else (draft.notice if not draft.notice.is_empty() else "Changes can be reviewed before creation.")

func refresh_summary() -> void:
	UI.clear(summary_column)
	UI.label(summary_column, "YOUR CHARACTER", 19, UI.GOLD, true)
	UI.line(summary_column)
	var portrait: Texture2D = draft.get_portrait_texture()
	if portrait != null:
		UI.square_art(summary_column, portrait, 85)
	UI.label(summary_column, draft.character_name if not draft.character_name.is_empty() else "Unnamed", 27, UI.PAPER, true)
	var ancestry_name: String = draft.ancestry.display_name if draft.ancestry != null else "Choose ancestry"
	var class_name_text: String = draft.character_class.display_name if draft.character_class != null else "Choose class"
	UI.label(summary_column, ancestry_name + " / " + class_name_text, 15, UI.MUTED)
	UI.label(summary_column, "LEVEL %d    ·    BUILD PREVIEW" % draft.level, 14, UI.GOLD)
	UI.line(summary_column)
	var state: CombatantState = draft.preview
	UI.label(summary_column, "HP %d   MANA %d   AP %d\nSPEED %.0f ft" % [state.max_hp, state.max_mana, state.max_ap, state.speed], 16)
	if state.max_faith > 0:
		UI.label(summary_column, "FAITH %d / %d   TEMP +%d" % [state.faith, state.max_faith, state.temporary_faith], 16, UI.GOLD)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	summary_column.add_child(grid)
	for entry in [["STR", state.strength], ["DEX", state.dexterity], ["CON", state.constitution], ["INT", state.intelligence], ["WIS", state.wisdom], ["CHA", state.charisma]]:
		UI.label(grid, "%s   %d" % entry, 15, UI.GOLD)
	UI.label(summary_column, "REF %d    FORT %d    WILL %d" % [state.reflex, state.fortitude, state.will], 13, UI.MUTED)
	UI.line(summary_column)
	UI.label(summary_column, "%d ABILITY POINT(S) LEFT" % state.ability_points, 14, UI.GOLD)
	var reason: String = draft.step_error("attributes")
	UI.label(summary_column, "Attribute choices complete" if reason.is_empty() else "Attribute choices pending", 14, UI.MUTED)
	var traits: PackedStringArray = []
	for entry in state.active_traits:
		traits.append(entry.display_name)
	UI.label(summary_column, " / ".join(traits), 14, UI.GOLD)
	var names: PackedStringArray = []
	for ability in state.available_abilities:
		if state.granted_ability_ids.has(ability.id) or state.selected_ability_ids.has(ability.id):
			names.append(ability.display_name)
	UI.label(summary_column, "\n".join(names), 14)

func confirm_character() -> void:
	var character: CharacterData = draft.finish()
	if character == null:
		refresh_navigation()
		return
	character_created.emit(character)
	if auto_start_combat:
		get_tree().set_meta("created_character_data", character)
		var error := get_tree().change_scene_to_file(destination_scene)
		if error != OK:
			footer_message.text = "Could not open the destination scene (%d)." % error
