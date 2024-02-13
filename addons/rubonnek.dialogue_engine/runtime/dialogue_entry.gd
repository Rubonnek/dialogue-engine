#============================================================================
#  dialogue_entry.gd                                                        |
#============================================================================
#                         This file is part of:                             |
#                            DIALOGUE ENGINE                                |
#           https://github.com/Rubonnek/godot-dialogue-engine               |
#============================================================================
# Copyright (c) 2023-2024 Wilson Enrique Alvarez Torres                     |
#                                                                           |
# Permission is hereby granted, free of charge, to any person obtaining     |
# a copy of this software and associated documentation files (the           |
# "Software"), to deal in the Software without restriction, including       |
# without limitation the rights to use, copy, modify, merge, publish,       |
# distribute, sublicense, andor sell copies of the Software, and to         |
# permit persons to whom the Software is furnished to do so, subject to     |
# the following conditions:                                                 |
#                                                                           |
# The above copyright notice and this permission notice shall be            |
# included in all copies or substantial portions of the Software.           |
#                                                                           |
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,           |
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF        |
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.    |
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY      |
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,      |
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE         |
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                    |
#============================================================================

extends RefCounted
class_name DialogueEntry

## Basic representation of one piece of dialogue.
##
## Each dialogue entry is composed of:[br]
## [br]
## 	1. An ID that uniquely identifies the dialogue entry within the DialogueEngine. Internally this ID is the same as the array index where the dialogue entry is stored at within the [DialogueEngine].
## 	2. The text of the dialogue that might take place under the right condition, and[br]
## 	3. Multiple possible options for a response
## 	4. Custom metadata associated with the dialogue entry. For example the actor's name, their emotional state, a pre dialogue callback or post dialogue callback, or any other sort of metadata useful for displaying the progress of the dialogue[br]

var _m_dialogue_entry_dictionary : Dictionary = {}
var _m_dialogue_entry_dictionary_id : int = 0
var _m_dialogue_engine : DialogueEngine = null


enum {
## Default top-level goto.
GOTO_DEFAULT = -1,
## Default option goto when an option is added but not configured.
INVALID_CONDITION_GOTO = -2,
## Default option goto when an option is added but not configured.
INVALID_OPTION_GOTO = -2,
## Invalid option chosen.
INVALID_CHOSEN_OPTION = -2,
## Makes [method get_formatted_text] return the text as-is with no error. See [method set_format].
FORMAT_NONE = 1,
## Makes [method get_formatted_text] use String.format as the format operation for the text. See [method set_format].
FORMAT_FUNCTION = 2,
## Makes [method get_formatted_text] use the [code]%[/code] [String] format operator as the format operation for the text. See [method set_format].
FORMAT_OPERATOR = 3,
## Makes [method get_formatted_text] return the text as-is with a warning. See [method set_format].
FORMAT_INVALID = 3,
}



## Sets the text for the dialogue entry.
func set_text(p_dialogue_text : String) -> void:
	if p_dialogue_text.is_empty():
		if _m_dialogue_entry_dictionary.has(&"text"):
			var _ignore : int = _m_dialogue_entry_dictionary.erase(&"text")
	else:
		_m_dialogue_entry_dictionary[&"text"] = p_dialogue_text
	if has_condition():
		push_warning("DialogueEntry: Text was set on entry with ID '%d' but this same entry has a condition installed. The text will be ignored if the condition isn't removed.\nThe associated text is:\n\n\t\"%s\"" % [_m_dialogue_entry_dictionary_id, get_text()])
	__send_entry_to_engine_viewer()


## Returns the text of the dialogue entry.
func get_text() -> String:
	var text : String = _m_dialogue_entry_dictionary.get(&"text", "")
	return text


## Returns the text with the given text format data apply if previously given through [method set_format].
func get_formatted_text() -> String:
	var text : String = get_text()
	var format_variant : Variant = get_evaluated_format()
	@warning_ignore("unsafe_method_access")
	var is_empty : bool = format_variant.is_empty()
	if is_empty:
		return text
	else:
		var format_operation_id : int = get_format().get(&"format_operation_id", FORMAT_INVALID)
		if format_operation_id == FORMAT_NONE:
			return text
		elif format_operation_id == FORMAT_FUNCTION:
			return text.format(format_variant)
		elif format_operation_id == FORMAT_OPERATOR:
			return text % format_variant
		elif format_operation_id == FORMAT_INVALID:
			push_warning("DialogueEntry: found invalid format operation specifier! Not formatting requested text.")
			return text
	push_error("DialogueEntry: No format operation was identified. This should not happen.")
	return text


## Returns a copy of the format data where all the [Callable] getters are called and substituted with their return values.
func get_evaluated_format() -> Variant:
	var format_dictionary : Dictionary = get_format()
	var format_variant : Variant = format_dictionary.get(&"format_data", [])
	if (not format_variant is Array  and not format_variant is Dictionary):
		return format_variant
	@warning_ignore("unsafe_method_access")
	var is_empty : bool = format_variant.is_empty()
	if is_empty:
		return format_variant

	@warning_ignore("unsafe_method_access")
	var evaluated_format : Variant = format_variant.duplicate(true)

	@warning_ignore("untyped_declaration")
	var container_ref
	var queue : Array = []
	queue.push_back(evaluated_format)
	while not queue.is_empty():
		container_ref = queue.pop_back()
		if container_ref is Array:
			var container_ref_as_array : Array = container_ref
			queue.append_array(__evaluate_callables_in_array(container_ref_as_array))
		elif container_ref is Dictionary:
			var container_ref_as_dictionary : Dictionary = container_ref
			queue.append_array(__evaluate_callables_in_dictionary(container_ref_as_dictionary))
	return evaluated_format


# Calls callables in Array and replaces them with their return value. Returns an array of subcontainers (Array or Dictionary) that were not processed.
func __evaluate_callables_in_array(p_array : Array) -> Array:
	var pending_queue : Array = []
	for index : int in p_array.size():
		var variant : Variant = p_array[index]
		if variant is Callable:
			@warning_ignore("unsafe_method_access")
			p_array[index] = variant.call()
		elif variant is Array or variant is Dictionary:
			pending_queue.push_back(variant)
	return pending_queue


# Calls callables in Dictionary values and replaces them with their return value. Returns an array of subcontainers (Array or Dictionary) that were not processed.
func __evaluate_callables_in_dictionary(p_dictionary : Dictionary) -> Array:
	var pending_queue : Array = []
	for key : Variant in p_dictionary:
		var variant : Variant = p_dictionary[key]
		if variant is Callable:
			@warning_ignore("unsafe_method_access")
			p_dictionary[key] = variant.call()
		elif variant is Array or variant is Dictionary:
			pending_queue.push_back(variant)
	return pending_queue


## Returns true if the dialogue entry has text.
func has_text() -> bool:
	return _m_dialogue_entry_dictionary.has(&"text")


## Adds an option to the dialogue entry and returns its option id.
func add_option(p_text : String) -> int:
	var options_array : Array = _m_dialogue_entry_dictionary.get(&"options", [])
	options_array.push_back({&"text" : p_text})
	var option_id : int = options_array.size() - 1
	if not _m_dialogue_entry_dictionary.has(&"options"):
		_m_dialogue_entry_dictionary[&"options"] = options_array
	if has_condition():
		push_warning("DialogueEntry: An option was added to entry with ID '%d' but this same entry has a condition installed. The option will be ignored if the condition isn't removed.\nThe associated text of the first option is:\n\n\t\"%s\"" % [_m_dialogue_entry_dictionary_id, get_option_text(0)])
	__send_entry_to_engine_viewer()
	return option_id


## Overwrites the option text entry
func set_option_text(p_option_id : int, p_text : String) -> void:
	var options_array : Array = _m_dialogue_entry_dictionary.get(&"options", [])
	var target_option : Dictionary = options_array[p_option_id]
	target_option[&"text"] = p_text
	__send_entry_to_engine_viewer()


## Returns the option text at the specified option id.
func get_option_text(p_option_id : int) -> String:
	var options_array : Array = _m_dialogue_entry_dictionary.get(&"options", [])
	var target_option : Dictionary = options_array[p_option_id]
	var text : String = target_option.get(&"text", "")
	return text


## Sets the option goto entry
func set_option_goto_id(p_option_id : int, p_goto_id : int) -> void:
	var options_array : Array = _m_dialogue_entry_dictionary.get(&"options", [])
	var target_option : Dictionary = options_array[p_option_id]
	if _m_dialogue_engine.has_entry_at(p_goto_id):
		target_option[&"goto"] = p_goto_id
	else:
		push_warning("DialogueEntry: Attempted to set invalid option-level goto with id '%d' against DialogueEntry option id '%d' and text:\n\n\"%s\"\n\nThe previously installed goto will be removed if there's any." % [p_goto_id, p_option_id, get_option_text(p_option_id)])
		if target_option.has(&"goto"):
			var _ignore : bool = target_option.erase(&"goto")
	target_option[&"goto"] = p_goto_id
	__send_entry_to_engine_viewer()


## Returns the option goto ID stored at the specified option id.
func get_option_goto_id(p_option_id : int) -> int:
	var options_array : Array = _m_dialogue_entry_dictionary.get(&"options", [])
	var target_option : Dictionary = options_array[p_option_id]
	var goto_id : int = target_option.get(&"goto", INVALID_OPTION_GOTO)
	return goto_id


## Returns the [DialogueEntry] stored at the specified option id.
func get_option_goto_entry(p_option_id : int) -> DialogueEntry:
	var goto_id : int = get_option_goto_id(p_option_id)
	if not _m_dialogue_engine.has_entry_at(goto_id):
		push_warning("DialogueEntry: Option ID '%d' has an invalid goto ID.\nThe option contains the text:\n\n\"%s\"\n\nThe associated dialogue entry ID is '%d' with text \"%s\"" % [p_option_id, get_option_text(p_option_id), _m_dialogue_entry_dictionary_id, get_text()])
		return null
	else:
		var dialogue_entry : DialogueEntry = _m_dialogue_engine.get_entry_at(goto_id)
		return dialogue_entry


## Attaches a condition. Useful for branching dialogues when certain conditions must be met. If the dialogue entry has options, these will get ignored.
func set_condition(p_callable : Callable) -> void:
	# NOTE: No need to check if p_callable is null since an error will be generated automatically at runtime.
	_m_dialogue_entry_dictionary[&"condition"] = p_callable
	if has_text():
		push_warning("DialogueEntry: A condition was set on entry with ID '%d' but this same entry has text installed. The text will be ignored if the condition isn't removed.\nThe associated text is:\n\n\t\"%s\"" % [_m_dialogue_entry_dictionary_id, get_text()])
	if has_goto():
		push_warning("DialogueEntry: A condition was set on entry with ID '%d' but this same entry has a goto installed. The goto will be ignored if the condition isn't removed." % [_m_dialogue_entry_dictionary_id, get_text()])
	if has_options():
		push_warning("DialogueEntry: A condition was set on entry with ID '%d' but this same entry has options installed. The options will be ignored if the condition isn't removed.\nThe associated text of the first option is:\n\n\t\"%s\"" % [_m_dialogue_entry_dictionary_id, get_option_text(0)])
	__send_entry_to_engine_viewer()


## Get condition:
func get_condition() -> Callable:
	return _m_dialogue_entry_dictionary.get(&"condition", Callable())


## Returns true if the DialogueEntry has a condition.
func has_condition() -> bool:
	return _m_dialogue_entry_dictionary.has(&"condition")


## Sets the condition goto IDs.
func set_condition_goto_ids(p_goto_id_if_true : int, p_goto_id_if_false : int) -> void:
	_m_dialogue_entry_dictionary[&"condition_gotos"] = { true : p_goto_id_if_true, false : p_goto_id_if_false}
	__send_entry_to_engine_viewer()


## Returns the condition goto IDs.
func get_condition_goto_ids() -> Dictionary:
	return _m_dialogue_entry_dictionary.get(&"condition_gotos", { true : INVALID_CONDITION_GOTO, false : INVALID_CONDITION_GOTO})


## Removes the condition>
func remove_condition() -> void:
	if _m_dialogue_entry_dictionary.has(&"condition"):
		var _ignore : bool = _m_dialogue_entry_dictionary.erase(&"condition")
	if _m_dialogue_entry_dictionary.has(&"condition_gotos"):
		var _ignore : bool = _m_dialogue_entry_dictionary.erase(&"condition_gotos")
	__send_entry_to_engine_viewer()


# Returns condition as string. Only used by the debugger.
func _get_condition_as_string() -> String:
	return _m_dialogue_entry_dictionary.get(&"condition_string", "")


## Returns the number of options associated with the dialogue entry.
func get_option_count() -> int:
	var options_array : Array = _m_dialogue_entry_dictionary.get(&"options", [])
	return options_array.size()


## Returns true if the entry has options. False otherwise. Opposite of [method is_options_empty].
func has_options() -> bool:
	var options_array : Array = _m_dialogue_entry_dictionary.get(&"options", [])
	return not options_array.is_empty()


## Returns true if the entry has no options. False otherwise. Opposite of [method has_options].
func is_options_empty() -> bool:
	var options_array : Array = _m_dialogue_entry_dictionary.get(&"options", [])
	return options_array.is_empty()


## Sets the text for the dialogue entry.
func set_name(p_dialogue_entry_name : StringName) -> void:
	if p_dialogue_entry_name.is_empty():
		if _m_dialogue_entry_dictionary.has(&"name"):
			var _ignore : int = _m_dialogue_entry_dictionary.erase(&"name")
	else:
		_m_dialogue_entry_dictionary[&"name"] = p_dialogue_entry_name

	# Do a sanity check:
	if OS.is_debug_build():
		if not p_dialogue_entry_name.is_empty():
			for entry_id : int in _m_dialogue_engine.size():
				if entry_id != _m_dialogue_entry_dictionary_id:
					var dialogue_entry : DialogueEntry = _m_dialogue_engine.get_entry_at(entry_id)
					if p_dialogue_entry_name == dialogue_entry.get_name():
						push_warning("DialogueEntry IDs \"%d\" and \"%d\" have the same name \"%s\" -- DialogueEntry.get_entry_by_name() won't work as expected." % [_m_dialogue_entry_dictionary_id, dialogue_entry.get_id(), p_dialogue_entry_name])
	__send_entry_to_engine_viewer()


## Returns the text of the dialogue entry.
func get_name() -> StringName:
	var name : StringName = _m_dialogue_entry_dictionary.get(&"name", &"")
	return name


## Returns the text of the dialogue entry.
func has_name() -> bool:
	return _m_dialogue_entry_dictionary.has(&"name")


## Stores the format array or dictionary to be used in [method get_formatted_text].[br]
##[br]
##If [code]p_format_operation_id[/code] is [enum FORMAT_OPERATOR], [method get_formatted_text] will format the text [String] using the [code]%[/code] operator.[br]
##If [code]p_format_operation_id[/code] is [enum FORMAT_FUNCTION], [method get_formatted_text] will format the text [String] using the [method String.format].
func set_format(p_format_data : Variant, p_format_operation_id : int) -> void:
	if (not p_format_data is Array) and (not p_format_data is Dictionary):
		push_warning("DialogueEntry: Attempted to add unsupported format container to entry with ID %d." % _m_dialogue_entry_dictionary_id)
		return
	assert(p_format_operation_id == FORMAT_FUNCTION or p_format_operation_id == FORMAT_OPERATOR or p_format_operation_id == FORMAT_NONE)
	@warning_ignore("unsafe_method_access")
	var is_empty : bool = p_format_data.is_empty()
	if is_empty:
		var _ignore : bool = _m_dialogue_entry_dictionary.erase(&"format")
	else:
		_m_dialogue_entry_dictionary[&"format"] = { &"format_data" : p_format_data, &"format_operation_id" : p_format_operation_id }
	__send_entry_to_engine_viewer()


## Returns the format specified in [method set_format] as a Dictionary with keys [code]format_data[/code] and [code]format_operation_id[/code].
func get_format() -> Dictionary:
	var format_dictionary : Dictionary = _m_dialogue_entry_dictionary.get(&"format", {})
	return format_dictionary


## Returns true if a format dictionary or array is installed.
func has_format() -> bool:
	return _m_dialogue_entry_dictionary.has(&"format")


## Sets the text for the dialogue entry.
func remove_text_vars() -> void:
	if _m_dialogue_entry_dictionary.has(&"format"):
		var _ignore : bool = _m_dialogue_entry_dictionary.erase(&"format")


## Sets option to be processed by the next [method DialogueEngine.advance] call.
func choose_option(p_option_id : int) -> void:
	_m_dialogue_entry_dictionary[&"chosen_option"] = p_option_id


## Returns chosen option. If no chosen option was previously set, it will return [enum INVALID_CHOSEN_OPTION].
func get_chosen_option() -> int:
	return _m_dialogue_entry_dictionary.get(&"chosen_option", INVALID_CHOSEN_OPTION)


## Returns chosen option. If no chosen option was previously set, it will return [enum INVALID_CHOSEN_OPTION].
func has_chosen_option() -> bool:
	return get_chosen_option() != INVALID_CHOSEN_OPTION


## Removes the chosen option.
func remove_chosen_option() -> void:
	if _m_dialogue_entry_dictionary.has(&"chosen_option"):
		var _ignore : bool = _m_dialogue_entry_dictionary.erase(&"chosen_option")


## Removes all the options associated with the dialogue entry.
func clear_options() -> void:
	var options_array : Array = _m_dialogue_entry_dictionary.get(&"options", [])
	options_array.clear()


## Removes the option at the specified option id.
func remove_option_at(p_option_id : int) -> void:
	var options_array : Array = _m_dialogue_entry_dictionary.get(&"options", [])
	if p_option_id < options_array.size():
		options_array.remove_at(p_option_id)
	__send_entry_to_engine_viewer()


## Attaches a top-level goto dialogue entry which gets processed when no options are present and the dialogue entry was visited by [method DialgoueEngine.advance] call.[br]
## If the goto [DialogueEntry] has a different branch ID, the [DialogueEngine] branch needle will be updated to the specified goto [DialogueEntry] upon the next [method DialogueEngine.advance] call.
func set_goto_id(p_goto_id : int) -> void:
	if _m_dialogue_engine.has_entry_at(p_goto_id):
		_m_dialogue_entry_dictionary[&"goto"] = p_goto_id
	else:
		push_warning("DialogueEntry: Attempted to set invalid top-level goto with id '%d' against DialogueEntry with id '%d' and text:\n\n\"%s\"\n\nThe previously installed goto will be removed if there's any." % [p_goto_id, _m_dialogue_entry_dictionary_id, get_text()])
		if _m_dialogue_entry_dictionary.has(&"goto"):
			var _ignore : bool = _m_dialogue_entry_dictionary.erase(&"goto")
	if has_condition():
		push_warning("DialogueEntry: A goto was set on entry with ID '%d' but this same entry has a condition installed. The goto will be ignored if the condition isn't removed." % [_m_dialogue_entry_dictionary_id])
	__send_entry_to_engine_viewer()


## Returns the goto dialogue entry if any. Returns null when no goto is available. A default goto is calculated in [method DialogueEngine.advance] by default and it's calculated to be the next dialogue entry on the same branch as [method DialogueEngine.get_branch_id_needle].
func get_goto_entry() -> DialogueEntry:
	if _m_dialogue_entry_dictionary.has(&"goto"):
		var goto_id : int = _m_dialogue_entry_dictionary[&"goto"]
		if _m_dialogue_engine.has_entry_at(goto_id):
			return _m_dialogue_engine.get_entry_at(goto_id)
		else:
			push_warning("DialogueEntry: Attempted to get invalid top-level goto with id '%d' from DialogueEntry with id '%d' and text:\n\n\"%s\"\n\nReturning invalid null DialogueEntry." % [goto_id, _m_dialogue_entry_dictionary_id, get_text()])
			return null
	else:
		return null


## Returns the goto dialogue ID.
func get_goto_id() -> int:
	return _m_dialogue_entry_dictionary.get(&"goto", GOTO_DEFAULT)


## Returns the goto dialogue entry if any. Returns null when no goto is available. A default goto is calculated in [method DialogueEngine.advance] by default and it's calculated to be the next dialogue entry on the same branch as [method DialogueEngine.get_branch_id_needle].
func remove_goto() -> void:
	if _m_dialogue_entry_dictionary.has(&"goto"):
		var _ignore : bool = _m_dialogue_entry_dictionary.erase(&"goto")


## Returns true if the dialogue entry has specified top-level goto. False otherwise. Internally, when false, the default dialogue entry goto is the next dialogue ID that also falls under the same branch ID.
func has_goto() -> bool:
	return _m_dialogue_entry_dictionary.has(&"goto")


## Attaches the specified metadata to the dialogue entry.
func set_metadata(p_key : Variant, p_value : Variant) -> void:
	var metadata : Dictionary = _m_dialogue_entry_dictionary.get(&"metadata", {})
	metadata[p_key] = p_value
	if not _m_dialogue_entry_dictionary.has(&"metadata"):
		_m_dialogue_entry_dictionary[&"metadata"] = metadata
	__send_entry_to_engine_viewer()


## Returns the specified metadata from the dialogue entry.
func get_metadata(p_key : Variant, p_default_value : Variant = null) -> Variant:
	var metadata : Dictionary = _m_dialogue_entry_dictionary.get(&"metadata", {})
	return metadata.get(p_key, p_default_value)


## Returns true if there's metadata available with the specified key.
func has_metadata(p_key : Variant) -> Variant:
	var metadata : Dictionary = _m_dialogue_entry_dictionary.get(&"metadata", {})
	return metadata.has(p_key)


## Directly returns the internal metadata dictionary.
func get_metadata_data() -> Dictionary:
	var metadata : Dictionary = _m_dialogue_entry_dictionary.get(&"metadata", {})
	if metadata.is_empty():
		if not _m_dialogue_entry_dictionary.has(&"metadata"):
			# There's a chance the user wants to modify it externally and have it update the DialogueEntry automatically -- make sure we store a reference of that metadata:
			_m_dialogue_entry_dictionary[&"metadata"] = metadata
	return metadata


## Directly updates the internal metadata dictionary with [p_metadata].
func set_metadata_data(p_metadata : Dictionary) -> void:
	if p_metadata.is_empty():
		if _m_dialogue_entry_dictionary.has(&"metadata"):
			var _ignore : int = _m_dialogue_entry_dictionary.erase(&"metadata")
	else:
		var metadata : Dictionary = _m_dialogue_entry_dictionary.get(&"metadata", {})
		if not _m_dialogue_entry_dictionary.has(&"metadata"):
			_m_dialogue_entry_dictionary[&"metadata"] = metadata
		metadata.clear()
		metadata.merge(p_metadata)

## Attaches the id to the entry.[br]
## [br]
## [color=yellow]Warning:[/color] this is part of a low-level API to inject dialogue entry objects into the [DialogueEngine] under certain scenarios. This function does not directly update the ID as seen through [DialogueEngine]. Only use this function if you know what you are doing.
func set_id(p_id : int) -> void:
	_m_dialogue_entry_dictionary_id = p_id


## Returns the id of the entry.
func get_id() -> int:
	return _m_dialogue_entry_dictionary_id


## Returns the id of the entry as [String].
func get_id_as_text() -> String:
	return String.num_uint64(_m_dialogue_entry_dictionary_id)


## Attaches the branch id of the entry.
func set_branch_id(p_branch_id : int) -> void:
	if p_branch_id == DialogueEngine.DEFAULT_BRANCH_ID:
		if _m_dialogue_entry_dictionary.has(&"branch_id"):
			var _ignore : int = _m_dialogue_entry_dictionary.erase(&"branch_id")
	else:
		_m_dialogue_entry_dictionary[&"branch_id"] = p_branch_id
	__send_entry_to_engine_viewer()


## Returns the branch id of the entry.
func get_branch_id() -> int:
	var branch_id : int = _m_dialogue_entry_dictionary.get(&"branch_id", DialogueEngine.DEFAULT_BRANCH_ID)
	return branch_id


## Returns the branch id of the entry as text
func get_branch_id_as_text() -> String:
	var branch_id : int = _m_dialogue_entry_dictionary.get(&"branch_id", DialogueEngine.DEFAULT_BRANCH_ID)
	return String.num_uint64(branch_id)


## Sets the associated dialogue engine.[br]
## [br]
## [color=yellow]Warning:[/color] this is part of a low-level API to inject dialogue entry objects into the [DialogueEngine] under certain scenarios. This function does not properly update the dialogue engine associated with this dialogue entry. Only use this function if you know what you are doing.
func set_engine(p_dialogue_engine : DialogueEngine) -> void:
	_m_dialogue_engine = p_dialogue_engine


## Returns the associated dialogue engine.
func get_engine() -> DialogueEngine:
	return _m_dialogue_engine


## Sets the associated dialogue entry data.
func set_data(p_data : Dictionary) -> void:
	# The new data may not cover all the keys we currently have.
	# For this reason we clear all the current data before merging.
	_m_dialogue_entry_dictionary.clear()
	_m_dialogue_entry_dictionary.merge(p_data, true)
	__send_entry_to_engine_viewer()


## Returns the dialogue entry data.
func get_data() -> Dictionary:
	return _m_dialogue_entry_dictionary


# Utility function for sending a whole entry to the viewer.
func __send_entry_to_engine_viewer() -> void:
	if EngineDebugger.is_active():
		# NOTE: Do not use the dialogue_entry API directly here when setting values to avoid sending unnecessary data to the debugger about the duplicated dialogue entry being sent to display

		# The debugger viewer requires certain sections to be stringified -- duplicate the DialogueEntry data to avoid overriding the runtime data:
		var duplicated_dialogue_entry_data : Dictionary = get_data().duplicate(true)

		# Let's stringify all the metadata keys and values where needed -- we don't care to display those, we only care to show what the entry metadata has.
		if has_condition():
			var condition : Callable = get_condition()
			duplicated_dialogue_entry_data[&"condition_string"] = str(condition)

		# Let's stringify all the format keys and values where needed to display them in text form in the viewer
		if has_format():
			var stringified_format : Variant = __get_stringified_format()
			var format_operation_id : int = get_format().get(&"format_operation_id", FORMAT_INVALID)
			duplicated_dialogue_entry_data[&"format"] =  { &"format_data" : stringified_format, &"format_operation_id" : __stringify_format_operation_id(format_operation_id)}

		# Let's stringify all the metadata keys and values where needed to display them in text form in the viewer
		var metadata : Dictionary = get_metadata_data()
		if not metadata.is_empty():
			var stringified_metadata : Dictionary = {}
			for key : Variant in metadata:
				var value : Variant = metadata[key]
				if key is Callable or key is Object:
					stringified_metadata[str(key)] = str(value)
				else:
					stringified_metadata[key] = str(value)
			duplicated_dialogue_entry_data[&"metadata"] = stringified_metadata

		var dialogue_engine_id : int = _m_dialogue_engine.get_instance_id()
		EngineDebugger.send_message("dialogue_engine:sync_entry", [dialogue_engine_id, _m_dialogue_entry_dictionary_id, duplicated_dialogue_entry_data])


func __stringify_format_operation_id(p_format_operation_id : int) -> String:
	match p_format_operation_id:
		FORMAT_NONE:
			return "FORMAT_NONE"
		FORMAT_FUNCTION:
			return "FORMAT_FUNCTION"
		FORMAT_OPERATOR:
			return "FORMAT_OPERATOR"
		FORMAT_INVALID:
			return "FORMAT_INVALID"
	push_error("DialogueEntry: Could not stringify format operation id. This should not happen.")
	return "FORMAT_INVALID"


## Returns a copy of the format data where all the [Callable] getters are called and substituted with their return values.
func __get_stringified_format() -> Variant:
	var format_dictionary : Dictionary = get_format()
	var format_variant : Variant = format_dictionary.get(&"format_data", [])
	if (not format_variant is Array  and not format_variant is Dictionary):
		return format_variant
	@warning_ignore("unsafe_method_access")
	var is_empty : bool = format_variant.is_empty()
	if is_empty:
		return format_variant

	@warning_ignore("unsafe_method_access")
	var evaluated_format : Variant = format_variant.duplicate(true)

	@warning_ignore("untyped_declaration")
	var container_ref
	var queue : Array = []
	queue.push_back(evaluated_format)
	while not queue.is_empty():
		container_ref = queue.pop_back()
		if container_ref is Array:
			var container_ref_as_array : Array = container_ref
			queue.append_array(__stringify_callables_and_objects_in_array(container_ref_as_array))
		elif container_ref is Dictionary:
			var container_ref_as_dictionary : Dictionary = container_ref
			queue.append_array(__stringify_callables_and_objects_in_dictionary(container_ref_as_dictionary))
	return evaluated_format


# Calls callables in Array and replaces them with their return value. Returns an array of subcontainers (Array or Dictionary) that were not processed.
func __stringify_callables_and_objects_in_array(p_array : Array) -> Array:
	var pending_queue : Array = []
	for index : int in p_array.size():
		var variant : Variant = p_array[index]
		if variant is Callable or variant is Object:
			@warning_ignore("unsafe_method_access")
			p_array[index] = str(variant)
		elif variant is Array or variant is Dictionary:
			pending_queue.push_back(variant)
	return pending_queue


# Calls callables in Dictionary values and replaces them with their return value. Returns an array of subcontainers (Array or Dictionary) that were not processed.
func __stringify_callables_and_objects_in_dictionary(p_dictionary : Dictionary) -> Array:
	var pending_queue : Array = []
	for key : Variant in p_dictionary:
		var variant : Variant = p_dictionary[key]
		if variant is Callable or variant is Object:
			p_dictionary[key] = str(variant)
		elif variant is Array or variant is Dictionary:
			pending_queue.push_back(variant)
	return pending_queue

func _init(p_dialogue_entry_id : int = 0, p_dialogue_engine : DialogueEngine = null, p_target_dialogue_entry_dictionary : Dictionary = {}) -> void:
	_m_dialogue_entry_dictionary = p_target_dialogue_entry_dictionary
	_m_dialogue_entry_dictionary_id = p_dialogue_entry_id
	_m_dialogue_engine = p_dialogue_engine
