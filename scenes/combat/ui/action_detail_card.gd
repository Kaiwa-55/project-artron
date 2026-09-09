extends PanelContainer


func setup(source: Resource, actor: CombatantState, system, description: String) -> void:
	custom_minimum_size.x = 360
	get_node("Column/Description").text = description
	if source == null:
		return
	get_node("Column/Title").text = source.display_name
	var tags: PackedStringArray = []
	for trait_data in source.traits:
		if trait_data != null:
			tags.append(trait_data.display_name)
	get_node("Column/Traits").text = "  /  ".join(tags)
	var lines: PackedStringArray = []
	lines.append("Cost: %d AP" % source.ap_cost)
	var attack: AttackData
	var range_feet: float = 0
	if source is AttackData:
		attack = source
		range_feet = attack.range_feet
	else:
		if source is SkillData:
			attack = source.attack_data
			range_feet = system.skill_system.get_effective_range_feet(actor, source)
			lines[0] += "  |  %d Mana" % system.skill_system.get_effective_mana_cost(actor, source)
			lines.append("Cooldown: %d turns  |  Remaining: %d" % [source.cooldown_turns, int(actor.skill_cooldowns.get(source.id, 0))])
		elif source is AbilityData:
			attack = system.ability_system.get_attack_data(actor, source)
			range_feet = system.ability_system.get_targeting_range(actor, source)
			if source.faith_cost > 0:
				lines[0] += "  |  %d Faith" % source.faith_cost
			lines.append("Cooldown: %d turns  |  Remaining: %d" % [source.cooldown_turns, int(actor.ability_cooldowns.get(source.id, 0))])
			if source.uses_per_turn > 0:
				lines.append("Limit: %d per turn" % source.uses_per_turn)
		if source is SkillData or source is AbilityData:
			lines.append("Target: %s" % ["Single target", "Self", "Ground"][source.target_mode])
			match source.area_shape:
				1: lines.append("Circle radius: %.0f ft" % source.area_radius_feet)
				2: lines.append("Line: %.0f x %.0f ft" % [source.line_length_feet, source.line_width_feet])
				3: lines.append("Cone: %.0f ft / %.0f degrees" % [source.line_length_feet, source.cone_angle_degrees])
	lines.append("Range: %.0f ft" % range_feet)
	if attack != null:
		lines.append("Base damage: %d %s" % [attack.base_damage, attack.damage_type.capitalize()])
		lines.append("To Hit bonus: %+d  |  Defense: %s" % [attack.to_hit_bonus, DefenseTypes.Type.keys()[attack.defense_type].capitalize()])
		if attack.can_critical:
			lines.append("Critical: %d%% / x%.1f" % [attack.critical_chance, attack.critical_multiplier])
		for effect in attack.effects_on_hit:
			if effect != null:
				lines.append("On Hit: %s" % effect.display_name)
		for effect in attack.effects_on_miss:
			if effect != null:
				lines.append("On Miss: %s" % effect.display_name)
	get_node("Column/Stats").text = "\n".join(lines)
