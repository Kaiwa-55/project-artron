class_name EventEffect
extends Resource

enum Type {
	DAMAGE,
	HEAL,
	GAIN_ITEM,
	REMOVE_ITEM,
	ADD_STATUS,
	REMOVE_STATUS,
	MODIFY_FLAG,
	MODIFY_RESOURCE,
	START_ENCOUNTER,
	TELEPORT,
	REWARD,
	GAIN_EXPERIENCE,
}

@export var type: Type = Type.MODIFY_FLAG
@export var target_id: String = ""
@export var key: StringName
@export var amount: int = 0
@export var bool_value: bool = true
@export var text_value: String = ""
@export var item: ItemData
@export var status_effect: EffectData
@export var encounter: EncounterData
@export var position: Vector2 = Vector2.ZERO


func apply(context: EventContext) -> Dictionary:
	if context == null:
		return {"success": false, "reason": "Missing EventContext."}
	var actor := context.get_actor(target_id)
	match type:
		Type.DAMAGE:
			if actor != null:
				actor.hp = maxi(0, actor.hp - maxi(0, amount))
		Type.HEAL:
			if actor != null:
				actor.hp = mini(actor.max_hp, actor.hp + maxi(0, amount))
		Type.GAIN_ITEM:
			_add_item(actor, maxi(1, amount))
		Type.REMOVE_ITEM:
			_remove_item(actor, maxi(1, amount))
		Type.ADD_STATUS:
			if actor != null and status_effect != null:
				actor.add_effect(status_effect)
		Type.REMOVE_STATUS:
			if actor != null:
				actor.remove_status(String(key))
		Type.MODIFY_FLAG:
			context.game_state.set_flag(key, bool_value)
		Type.MODIFY_RESOURCE:
			_apply_resource_change(context, actor)
		Type.START_ENCOUNTER:
			return {"success": encounter != null, "start_encounter": encounter}
		Type.TELEPORT:
			context.data["teleport_position"] = position
		Type.REWARD:
			context.data.get_or_add("rewards", []).append({"id": String(key), "amount": amount, "text": text_value})
		Type.GAIN_EXPERIENCE:
			var progression := ProgressionSystem.new()
			if not target_id.is_empty():
				if actor != null:
					progression.add_experience(actor, maxi(0, amount))
			else:
				for member in context.party:
					if member != null:
						progression.add_experience(member, maxi(0, amount))
	return {"success": true, "effect_type": type}


func uses_choice_actor() -> bool:
	if not target_id.is_empty():
		return false
	if type in [Type.DAMAGE, Type.HEAL, Type.GAIN_ITEM, Type.REMOVE_ITEM, Type.ADD_STATUS, Type.REMOVE_STATUS]:
		return true
	return type == Type.MODIFY_RESOURCE and String(key).to_lower() in ["hp", "mana", "ap", "faith"]


func _apply_resource_change(context: EventContext, actor: CombatantState) -> void:
	var resource_id := String(key).to_lower()
	if actor != null and resource_id in ["hp", "mana", "ap", "faith"]:
		var maximum := int(actor.get("max_%s" % resource_id))
		actor.set(resource_id, clampi(int(actor.get(resource_id)) + amount, 0, maximum))
	elif resource_id.begins_with("reputation_"):
		context.game_state.modify_reputation(resource_id.trim_prefix("reputation_"), amount)
	else:
		context.game_state.modify_resource(key, amount)


func _add_item(actor: CombatantState, quantity: int) -> void:
	if actor == null or item == null:
		return
	for stack in actor.item_inventory:
		if stack != null and stack.item == item:
			stack.quantity += quantity
			return
	actor.item_inventory.append(ItemStack.new(item, quantity))


func _remove_item(actor: CombatantState, quantity: int) -> void:
	if actor == null:
		return
	var remaining := quantity
	for index in range(actor.item_inventory.size() - 1, -1, -1):
		var stack = actor.item_inventory[index]
		if stack == null or stack.item == null or stack.item.id != String(key):
			continue
		var removed: int = mini(remaining, stack.quantity)
		stack.quantity -= removed
		remaining -= removed
		if stack.quantity <= 0:
			actor.item_inventory.remove_at(index)
		if remaining <= 0:
			break
