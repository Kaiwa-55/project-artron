extends RefCounted

const UITheme := preload("res://scenes/ui/artron_ui_theme.gd")
const CombatTheme := preload("res://scenes/ui/combat_ui_theme.gd")
const MINOR_BUTTON_SIZE := 28.0
const MINOR_FONT_SIZE := 4

var host
var combat_system
var action_menu_panel: PanelContainer
var action_menu_title: Label
var action_menu_list: Container
var minor_action_title: Label
var minor_action_scroll: ScrollContainer
var minor_action_list: GridContainer
var minor_action_panel: VBoxContainer


func _init(p_host) -> void:
	host = p_host
	combat_system = host.combat_system
	action_menu_panel = host.action_menu_panel
	action_menu_title = host.action_menu_title
	action_menu_list = host.action_menu_list
	minor_action_title = host.minor_action_title
	minor_action_scroll = host.minor_action_scroll
	minor_action_list = host.minor_action_list
	minor_action_panel = host.get_node("UILayer/Control/CombatUI/Combat_bar/Action_bar_Minor")


func show_action_menu(category: String) -> void:
	minor_action_panel.visible = false
	for child in action_menu_list.get_children():
		action_menu_list.remove_child(child)
		child.queue_free()
	action_menu_title.text = "BASIC ACTION" if category == "basic" else category.to_upper()
	minor_action_title.text = action_menu_title.text
	minor_action_panel.set_meta("category", category)
	minor_action_scroll.visible = true
	minor_action_scroll.scroll_horizontal = 0
	var player: CombatantState = host.get_displayed_party_member()
	if player == null:
		return
	match category:
		"move":
			var available_move: float = combat_system.movement_system.get_available_distance_feet(player)
			add_action_menu_note("Speed %.1f ft · Available %.1f ft" % [player.get_effective_speed(), available_move])
			add_action_menu_note("Continuing an unfinished Move is free. A new Move costs 1 AP.")
		"attack":
			var listed_items: Array = []
			for slot in [0, 3]:
				var item = player.equipped_items.get(slot)
				if item != null and item.weapon_attack != null and not listed_items.has(item):
					listed_items.append(item)
					var weapon_attack: AttackData = item.weapon_attack
					if weapon_attack.ammunition_item_ids.is_empty():
						add_action_menu_button(weapon_attack.display_name, item.description, host.use_equipment_attack.bind(weapon_attack))
					else:
						for arrow_id in weapon_attack.ammunition_item_ids:
							var stack: ItemStack = combat_system.equipment_system.find_ammunition_stack(player, arrow_id)
							var arrow: ItemData = stack.item if stack != null else load("res://data/item/%s.tres" % arrow_id)
							if arrow == null:
								continue
							var selected_attack: AttackData = combat_system.equipment_system.create_ammunition_attack(weapon_attack, arrow)
							add_action_menu_button("%s (%d)" % [arrow.display_name, stack.quantity if stack != null else 0], "%s: %s" % [weapon_attack.display_name, arrow.description], host.use_equipment_attack.bind(selected_attack))
							var arrow_button := action_menu_list.get_child(action_menu_list.get_child_count() - 1) as Button
							arrow_button.disabled = stack == null or player.ap < selected_attack.ap_cost
			if player.unarmed_attack != null:
				var free_hand: bool = combat_system.equipment_system.has_free_hand(player)
				var unarmed_hint := "Melee · Unarmed · Requires at least one free hand."
				if not free_hand:
					unarmed_hint += " Both hands are occupied."
				add_action_menu_button(player.unarmed_attack.display_name, unarmed_hint, host.use_equipment_attack.bind(player.unarmed_attack))
				var unarmed_button := action_menu_list.get_child(action_menu_list.get_child_count() - 1) as Button
				unarmed_button.disabled = not free_hand or player.ap < player.unarmed_attack.ap_cost
			if listed_items.is_empty() and player.unarmed_attack == null:
				add_action_menu_note("No equipped weapon attacks.")
		"basic":
			add_action_menu_button("SEARCH", "1 AP · Choose any enemy, visible or not. Roll 3d8 + Perception vs 10 + Stealth. Success: reduce that enemy's Hide Concealment against you by 1.", host.begin_search_targeting, true)
			add_action_menu_button("HIDE", "1 AP · Roll 3d8 + Stealth against every enemy's 10 + Perception DC. Enemies with Line of Sight add +4 DC. Success: Concealment +1.", host.use_hide_from_menu, true)
			add_action_menu_button("GRAB", "Melee · 1 AP · 3d8 + STR vs Highest Defense. Applies Grabbed.", host.begin_basic_maneuver_targeting.bind(ActionTypes.Maneuver.GRAB), true)
			add_action_menu_button("PUSH", "Melee · 1 AP · Push up to STR modifier × 2 + 5 ft.", host.begin_basic_maneuver_targeting.bind(ActionTypes.Maneuver.PUSH), true)
			add_action_menu_button("PULL", "Melee · 1 AP · Pull up to STR modifier × 2 + 5 ft without overlapping.", host.begin_basic_maneuver_targeting.bind(ActionTypes.Maneuver.PULL), true)
			add_action_menu_button("TRIP", "Melee · 1 AP · Applies Prone until the target's next turn.", host.begin_basic_maneuver_targeting.bind(ActionTypes.Maneuver.TRIP), true)
			if player.has_status("prone"):
				add_action_menu_button("STAND", "1 AP · Remove Prone.", host.use_stand_from_menu, true)
			add_action_menu_button("THROW", "Open throwable weapons and items.", show_action_menu.bind("throw"), true)
			add_action_menu_button("ESCAPE", "Attempt to remove an escapable Status.", show_action_menu.bind("escape"), true)
		"throw":
			add_action_menu_button("← BACK TO BASIC ACTION", "Return to the Basic Action list.", show_action_menu.bind("basic"), true)
			var listed_items: Array = []
			for item in player.equipment_inventory:
				if item == null or listed_items.has(item):
					continue
				var thrown_attack: AttackData = combat_system.equipment_system.create_throw_attack(item)
				if thrown_attack == null:
					continue
				listed_items.append(item)
				var held: bool = combat_system.equipment_system.find_hand_slot(player, item) >= 0
				var returning: bool = combat_system.trait_system.attack_has_trait(thrown_attack, "returning")
				var hint := "Range %.0f ft. %s" % [thrown_attack.range_feet, "Returning: weapon is kept." if returning else "Weapon is consumed when thrown."]
				if not held:
					hint += " Equip this item in a hand slot first."
				elif player.ap < thrown_attack.ap_cost:
					hint += " Not enough AP."
				add_action_menu_button(item.display_name, hint, host.use_equipment_attack.bind(thrown_attack))
				var button := action_menu_list.get_child(action_menu_list.get_child_count() - 1) as Button
				button.disabled = not held or player.ap < thrown_attack.ap_cost
			if listed_items.is_empty():
				add_action_menu_note("No throwable items in inventory.")
		"escape":
			add_action_menu_button("← BACK TO BASIC ACTION", "Return to the Basic Action list.", show_action_menu.bind("basic"), true)
			var escapable: Array = combat_system.effect_system.get_escapable_effects(player)
			for instance in escapable:
				var dc: int = instance.source_class_dc if instance.source_class_dc > 0 else instance.data.default_escape_dc
				var tooltip := "Roll 3d8 + STR modifier vs DC %d. AP is spent whether the roll succeeds or fails." % dc
				add_action_menu_button(instance.data.display_name, tooltip, host.use_escape_from_menu.bind(instance.data.id))
				var escape_button := action_menu_list.get_child(action_menu_list.get_child_count() - 1) as Button
				escape_button.disabled = player.ap < instance.data.escape_ap_cost
			if escapable.is_empty():
				add_action_menu_note("No active Status can be escaped.")
		"skill":
			for skill in player.available_skills:
				if skill != null:
					add_action_menu_button(skill.display_name, skill.description, host.use_skill_from_menu.bind(skill))
			if player.available_skills.is_empty():
				add_action_menu_note("No Skills available.")
		"ability":
			var abilities: Array = combat_system.ability_system.get_active_abilities(player)
			for ability in abilities:
				if ability != null and not ability.is_passive and not ability.reaction_only:
					var ability_target: CombatantState = player
					if ability.target_mode == AbilityData.TargetMode.SINGLE_COMBATANT:
						ability_target = get_first_valid_ability_target(player, ability)
					var validation: ActionResult = combat_system.ability_system.validate_active_use(player, ability, ability_target)
					var tooltip: String = ability.description if validation.success else "%s\nUnavailable: %s" % [ability.description, validation.failure_reason]
					add_action_menu_button(ability.display_name, tooltip, host.use_ability_from_menu.bind(ability))
					var ability_button := action_menu_list.get_child(action_menu_list.get_child_count() - 1) as Button
					ability_button.disabled = not validation.success
			if action_menu_list.get_child_count() == 0:
				add_action_menu_note("No Active Abilities available.")
		"item":
			for stack in player.item_inventory:
				if stack == null or stack.item == null or not (stack.item is ConsumableData):
					continue
				var item: ConsumableData = stack.item
				var target_id := player.id
				if item.target_mode == ConsumableData.TargetMode.SINGLE_COMBATANT:
					var first_target := get_first_valid_item_target(player, item)
					target_id = first_target.id if first_target != null else ""
				var validation: ActionResult = combat_system.consumable_item_executor.validate(player.id, item.id, target_id)
				var tooltip: String = item.description if validation.success else "%s\nUnavailable: %s" % [item.description, validation.failure_reason]
				add_action_menu_button(item.display_name, tooltip, host.use_item_from_menu.bind(item))
				var item_button := action_menu_list.get_child(action_menu_list.get_child_count() - 1) as Button
				item_button.disabled = not validation.success
			if player.item_inventory.is_empty():
				add_action_menu_note("No Items available.")
	var current_actor: CombatantState = combat_system.get_combat_state().get_current_actor()
	var read_only: bool = current_actor == null or current_actor.id != player.id
	if read_only:
		for child in action_menu_list.get_children():
			if child is Button and not child.get_meta("menu_navigation", false):
				child.disabled = true
				child.tooltip_text = "This character can only use Actions during their Turn."
	minor_action_panel.visible = action_menu_list.get_child_count() > 0
	action_menu_panel.visible = false


func get_first_valid_ability_target(actor: CombatantState, ability: AbilityData) -> CombatantState:
	if actor == null or ability == null or combat_system == null:
		return null
	for candidate in combat_system.get_combat_state().combatants.values():
		if candidate != null and not candidate.is_dying() and combat_system.ability_system.target_filter_matches(actor, candidate, ability):
			return candidate
	return null


func get_first_valid_item_target(actor: CombatantState, item: ConsumableData) -> CombatantState:
	if actor == null or item == null or combat_system == null:
		return null
	for candidate in combat_system.get_combat_state().combatants.values():
		if candidate != null and combat_system.consumable_item_executor.validate(actor.id, item.id, candidate.id).success:
			return candidate
	return null


func add_action_menu_button(text: String, tooltip: String, action: Callable, menu_navigation: bool = false) -> void:
	var button := Button.new()
	var arguments := action.get_bound_arguments()
	if not arguments.is_empty() and (arguments[0] is AttackData or arguments[0] is SkillData or arguments[0] is AbilityData):
		button.set_script(preload("res://scenes/combat/ui/action_detail_button.gd"))
		button.detail_source = arguments[0]
		button.detail_actor = host.get_displayed_party_member()
		button.detail_system = combat_system
	button.text = text
	button.tooltip_text = tooltip
	button.set_meta("menu_navigation", menu_navigation)
	button.custom_minimum_size = Vector2.ONE * MINOR_BUTTON_SIZE
	button.clip_text = true
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", MINOR_FONT_SIZE)
	button.pressed.connect(func():
		action.call()
		if not menu_navigation:
			minor_action_panel.hide()
	)
	style_minor_action_button(button, _get_minor_action_icon(arguments))
	action_menu_list.add_child(button)
	_update_minor_action_columns()


func add_action_menu_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(80, MINOR_BUTTON_SIZE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("a99d8b"))
	label.add_theme_font_size_override("font_size", MINOR_FONT_SIZE)
	action_menu_list.add_child(label)
	_update_minor_action_columns()


func _update_minor_action_columns() -> void:
	var action_count: int = minor_action_list.get_child_count()
	# The dock scrolls horizontally; a second row extends below its viewport.
	minor_action_list.columns = maxi(1, action_count)
	var column_width := MINOR_BUTTON_SIZE
	for child in minor_action_list.get_children():
		if child is Label:
			column_width = maxf(column_width, child.custom_minimum_size.x)
	minor_action_panel.offset_right = minf(minor_action_panel.get_parent().size.x, maxf(60.0, minor_action_list.columns * (column_width + 2.0) + 6.0))


func _get_minor_action_icon(arguments: Array) -> Texture2D:
	if arguments.is_empty():
		return null
	var source = arguments[0]
	if source is Object and "icon_texture" in source:
		return source.icon_texture
	return null


func style_minor_action_button(button: Button, icon_texture: Texture2D) -> void:
	UITheme.apply_button_style(button)
	button.custom_minimum_size = Vector2.ONE * MINOR_BUTTON_SIZE
	button.clip_text = true
	var action_name := button.text
	# Keep the no-icon button caption available to existing menu integrations.
	button.text = action_name if icon_texture == null else ""
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(color_name, Color.TRANSPARENT)
	var label := UITheme.label(action_name, MINOR_FONT_SIZE)
	label.name = "ActionName"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 2
	label.offset_right = -2
	label.offset_bottom = -9
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_constant_override("line_spacing", -3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.max_lines_visible = 2
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_child(label)
	if icon_texture != null:
		var icon := TextureRect.new()
		icon.name = "ActionIcon"
		icon.texture = icon_texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(2, 2)
		icon.size = Vector2(10, 10)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		label.offset_left = 12
	var cost_badge_text := _get_action_cost_badge(button)
	if not cost_badge_text.is_empty():
		var badge := UITheme.label(cost_badge_text, MINOR_FONT_SIZE, UITheme.GOLD)
		badge.name = "CostBadge"
		badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		badge.offset_left = 2
		badge.offset_top = -8
		badge.offset_right = -2
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(badge)


func _get_action_cost_badge(button: Button) -> String:
	if not "detail_source" in button or button.detail_source == null:
		return ""
	var source = button.detail_source
	var actor: CombatantState = host.get_displayed_party_member()
	var parts := PackedStringArray()
	if "ap_cost" in source and int(source.ap_cost) > 0:
		parts.append("%d AP" % int(source.ap_cost))
	if source is SkillData:
		var mana_cost: int = combat_system.skill_system.get_effective_mana_cost(actor, source) if actor != null else source.mana_cost
		if mana_cost > 0:
			parts.append("%d M" % mana_cost)
		var skill_cooldown: int = combat_system.skill_system.get_remaining_cooldown(actor, source.id) if actor != null else 0
		if skill_cooldown > 0:
			parts.append("CD%d" % skill_cooldown)
	elif source is AbilityData:
		if source.faith_cost > 0:
			parts.append("%d F" % source.faith_cost)
		if source.finishing_gauge_cost > 0:
			parts.append("%d G" % source.finishing_gauge_cost)
		var ability_cooldown: int = combat_system.ability_system.get_remaining_cooldown(actor, source.id) if actor != null else 0
		if ability_cooldown > 0:
			parts.append("CD%d" % ability_cooldown)
	return " ".join(parts)
