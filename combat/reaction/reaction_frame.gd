class_name ReactionFrame
extends RefCounted

var id: int = 0
var trigger_id: int = 0
var depth: int = 0
var parent_id: int = 0
var request: ActionRequest
var prompt: Dictionary = {}
var selected_reaction_id: String = ""
var completed: bool = false
