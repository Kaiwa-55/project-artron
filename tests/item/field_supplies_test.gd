extends SceneTree

const Antidote = preload("res://data/item/antidote_kit.tres")
const Focus = preload("res://data/item/focus_draught.tres")
const Lantern = preload("res://data/equipment/hunters_lantern.tres")
const Boots = preload("res://data/equipment/silent_boots.tres")
const Ring = preload("res://data/equipment/arcane_thread_ring.tres")
const Poisoned = preload("res://data/status/poisoned.tres")

var failures: Array[String] = []


func _init() -> void:
	var actor := CombatantState.new()
	actor.id = "player"
	actor.team = 1
	actor.base_max_hp = 20
	actor.base_max_mana = 5
	actor.base_max_ap = 5
	actor.skill_ranks["stealth"] = 3
	actor.equipment_inventory = [Lantern, Boots, Ring]
	actor.equipped_items = {3: Lantern, 6: Boots, 9: Ring}
	actor.item_inventory.append(ItemStack.new(Antidote, 1))
	actor.item_inventory.append(ItemStack.new(Focus, 2))
	var enemy := CombatantState.new()
	enemy.id = "enemy"
	enemy.team = 2
	enemy.base_max_hp = 20
	enemy.base_max_ap = 2
	enemy.position = Vector2(600, 0)
	var combat := CombatSystem.new()
	combat.start_combat([actor, enemy])
	combat.combat_state.current_actor_id = actor.id
	check(actor.max_mana == 6 and actor.get_skill_rank("stealth") == 5, "Ring and Boots grant their equipped bonuses")
	check(combat.map_rules.get_light_level_at(Vector2.ZERO) == 0 and combat.map_rules.get_light_level_at(Vector2(400, 0)) == 1, "Held Lantern brightens 30 ft only")
	check(not combat.use_consumable_item(actor.id, Antidote.id).success, "Antidote cannot be wasted without Poisoned")
	actor.add_effect(Poisoned)
	check(combat.use_consumable_item(actor.id, Antidote.id).success and not actor.has_status("poisoned"), "Antidote removes Poisoned")
	check(combat.consumable_item_executor.find_stack(actor, Antidote.id) == null, "Antidote is consumed")
	check(combat.use_consumable_item(actor.id, Focus.id).success and actor.focus_draught_ready_bonus == 2, "Focus Draught prepares the next Skill")
	var focus_stack: ItemStack = combat.consumable_item_executor.find_stack(actor, Focus.id)
	var ap_before_repeat := actor.ap
	check(not combat.use_consumable_item(actor.id, Focus.id).success and focus_stack.quantity == 1 and actor.ap == ap_before_repeat, "Focus cannot be consumed again while its bonus is pending")
	var skill := SkillData.new()
	skill.id = "focus_test_skill"
	skill.attack_data = AttackData.new()
	skill.attack_data.to_hit_bonus = 1
	var preview: AttackData = combat.skill_system.get_attack_data(skill, actor)
	check(preview.to_hit_bonus == 1 and actor.focus_draught_ready_bonus == 2, "Skill validation does not consume Focus")
	combat.skill_system.consume_skill_costs(actor, skill)
	var focused: AttackData = combat.skill_system.get_attack_data(skill, actor, true)
	check(focused.to_hit_bonus == 3, "Next Skill gains +2 accuracy")
	check(combat.skill_system.get_attack_data(skill, actor, true).to_hit_bonus == 1, "Focus applies to only one Skill")
	var buff_effect := EffectData.new()
	buff_effect.id = "test_consumable_attack_buff"
	buff_effect.attack_bonus = 2
	buff_effect.stack_mode = EffectData.StackMode.ADD_STACKS
	buff_effect.max_stacks = 5
	var buff_item := ConsumableData.new()
	buff_item.id = "test_buff_vial"
	buff_item.effects.append(buff_effect)
	actor.item_inventory.append(ItemStack.new(buff_item, 2))
	check(combat.use_consumable_item(actor.id, buff_item.id).success and combat.use_consumable_item(actor.id, buff_item.id).success, "Stat buff item can be used again to refresh")
	check(combat.effect_system.get_attack_bonus(actor) == 2 and actor.effects.any(func(instance): return instance.data.id == buff_effect.id and instance.stack_count == 1), "Repeated consumable buff never adds stacks or bonus")
	var other_buff := ConsumableData.new()
	other_buff.id = "other_attack_buff"
	var other_effect := EffectData.new()
	other_effect.id = "other_attack_buff_effect"
	other_effect.attack_bonus = 3
	other_buff.effects.append(other_effect)
	actor.item_inventory.append(ItemStack.new(other_buff, 1))
	var other_stack: ItemStack = combat.consumable_item_executor.find_stack(actor, other_buff.id)
	var ap_before_overlap := actor.ap
	check(not combat.use_consumable_item(actor.id, other_buff.id).success and other_stack.quantity == 1 and actor.ap == ap_before_overlap, "Different consumable buffs with the same bonus cannot overlap")
	actor.focus_draught_ready_bonus = 2
	combat.advance_turn()
	check(actor.focus_draught_ready_bonus == 0, "Unused Focus expires at turn end")
	var gear := EquipmentSystem.new()
	gear.toggle_equipment_without_cost(actor, Boots, 6)
	gear.toggle_equipment_without_cost(actor, Ring, 9)
	gear.toggle_equipment_without_cost(actor, Lantern, 3)
	check(actor.get_skill_rank("stealth") == 3 and actor.max_mana == 5, "Removing Boots and Ring removes their bonuses")
	check(combat.map_rules.get_light_level_at(Vector2.ZERO) == 1, "Removing Lantern removes its light")
	var healer = load("res://data/shop/healer_shop.tres")
	var outfitter = load("res://data/shop/outfitter_shop.tres")
	check(healer.offers.any(func(offer): return offer.product == Antidote) and healer.offers.any(func(offer): return offer.product == Focus), "Consumables are sold at the apothecary")
	check(outfitter.offers.any(func(offer): return offer.product == Lantern) and outfitter.offers.any(func(offer): return offer.product == Boots) and outfitter.offers.any(func(offer): return offer.product == Ring), "Equipment is sold at the outfitter")
	for failure in failures:
		push_error(failure)
	print("FIELD_SUPPLIES_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
