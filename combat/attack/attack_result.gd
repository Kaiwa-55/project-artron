class_name AttackResult
extends RefCounted


var hit: bool = false

var roll: int = 0
var original_defense: int = 0
var defense: int = 0
var margin: int = 0

var attack_modifier: int = 0
var repeated_attack_penalty: int = 0

var damage: int = 0
var conditional_damage_bonus: int = 0
var damage_bonus_source: String = ""
var conditional_damage_bonuses: Array[Dictionary] = []
var critical: bool = false
var critical_roll: int = 0
var immune: bool = false
var triggered_abilities: Array[Dictionary] = []
var resistance: int = 0
var final_damage: int = 0
var reaction_damage_reduction: int = 0
var redirected_damage_target: CombatantState
var finishing_gauge_gained: int = 0

var applied_effects: Array[String] = []
var deferred: bool = false
