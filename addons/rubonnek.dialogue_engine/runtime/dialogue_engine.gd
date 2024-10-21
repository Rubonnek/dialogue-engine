#============================================================================
#  dialogue_engine.gd                                                       |
#============================================================================
#                         This file is part of:                             |
#                            DIALOGUE ENGINE                                |
#           https://github.com/Rubonnek/dialogue-engine                     |
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
## A minimalistic dialogue engine that fits into your GUI nodes and automatically graphs the branching dialogues for easy debugging.
##
## DialogueEngine provides an API for creating dialogue trees and walking them, and the user is responsible for providing the GUI code that presents the text to the player.
## The engine internally manages an array of dictionaries each of which are accessed as a [DialogueEntry] which are the basic representation of the entries within dialogue tree.
## [br]
## [br]
## Each [DialogueEntry] can be of two types: text or conditional. Text-based entries represent a block of text to be shown in the dialog along with possible options the player can choose. Conditional-based entries represent a bifurcation point in the dialogue tree the path of which is dictated by a user-supplied boolean [Callable].
## Each type of [DialogueEntry] can be added either through [method add_text_entry] or [method add_conditional_entry].
## [br]
## [br]
## [b]Quickstart[/b]:
## [codeblock]
## var dialogue_engine : DialogueEngine = DialogueEngine.new()
## dialogue_engine.add_text_entry("Hello")
##
## var print_dialogue : Callable = func (dialogue_entry : DialogueEntry) -> void:
##     print(dialogue_entry.get_text())
##
## dialogue_engine.dialogue_continued.connect(print_dialogue)
##
## dialogue_engine.advance() # prints "Hello"
## dialogue_engine.advance() # Nothing prints -- the dialogue finished.
## dialogue_engine.advance() # prints "Hello"
## dialogue_engine.advance() # Nothing prints -- the dialogue finished.
## [/codeblock]
## [br]
##
## @tutorial(Demos): https://github.com/Rubonnek/dialogue-engine/tree/master/demos
class_name DialogueEngine


## Emitted when the first [DialogueEntry] is read
signal dialogue_started
## Emitted when [method advance] visits a [DialogueEntry] that has text.
signal dialogue_continued(p_dialogue_entry : DialogueEntry)
## Emitted when [method advance] visits a [DialogueEntry] that either has text or has a condition.
signal entry_visited(p_dialogue_entry : DialogueEntry)
## Emitted when the dialogue is about to finish (i.e. when [method advance] is called and the internal read needle is at the last DialogueEntry).
signal dialogue_about_to_finish
## Emitted when the dialogue finishes.
signal dialogue_finished
## Emitted when reset() is called and the dialogue started but hasn't finished, or an invalid goto or chosen option has been encountered.
signal dialogue_cancelled


enum {
## Denotes the default branch ID when none is provideed
DEFAULT_BRANCH_ID = 0,
}


var _m_dialogue_tree : Array[Dictionary] = []
var _m_read_needle : int = 0
var _m_branch_id_needle : int = DEFAULT_BRANCH_ID
var _m_has_dialogue_started : bool = false
var _m_invalid_goto_detected : bool = false


## Adds a new text [DialogueEntry] to the engine and returns it.
func add_text_entry(p_text : String = "", p_branch_id : int = DEFAULT_BRANCH_ID) -> DialogueEntry:
	var write_needle : int = _m_dialogue_tree.size()
	var dialogue_entry : DialogueEntry = DialogueEntry.new(write_needle, self)
	var dialogue_entry_dictionary : Dictionary = dialogue_entry.get_data()
	_m_dialogue_tree.push_back(dialogue_entry_dictionary)
	dialogue_entry.set_branch_id(p_branch_id)
	dialogue_entry.set_text(p_text)
	return dialogue_entry


## Adds a new conditional [DialogueEntry] to the engine and returns it.
func add_conditional_entry(p_callable : Callable, p_branch_id : int = DEFAULT_BRANCH_ID) -> DialogueEntry:
	var write_needle : int = _m_dialogue_tree.size()
	var dialogue_entry : DialogueEntry = DialogueEntry.new(write_needle, self)
	var dialogue_entry_dictionary : Dictionary = dialogue_entry.get_data()
	_m_dialogue_tree.push_back(dialogue_entry_dictionary)
	dialogue_entry.set_branch_id(p_branch_id)
	dialogue_entry.set_condition(p_callable)
	return dialogue_entry


## Sets the branch ID used for the next [method advance] calls. Useful when initializing the engine. This function is called automatically by [method advance] when a jump (i.e. a goto) to a different branch ID is detected.
func set_branch_id(p_branch_id : int) -> void:
	_m_branch_id_needle = p_branch_id
	if EngineDebugger.is_active():
		EngineDebugger.send_message("dialogue_engine:set_branch_id", [get_instance_id(), p_branch_id])


## Returns the currently tracked branch ID that is being read by [method advance] calls.
func get_branch_id() -> int:
	return _m_branch_id_needle


## Returns the specified dialogue entry. Returns null if the dialogue entry does not exist.
func get_entry(p_entry_id : int) -> DialogueEntry:
	if has_entry_id(p_entry_id):
		return get_entry_at(p_entry_id)
	return null


## Returns the current dialogue entry. If there's no available entry or the dialogue has not started or has been cancelled or finished, it will return null.
func get_current_entry() -> DialogueEntry:
	var current_dialogue_id : int = clampi(_m_read_needle - 1, 0, size())
	if has_entry_id(current_dialogue_id):
		return get_entry_at(current_dialogue_id)
	return null


## Returns the current dialogue entry ID. Returns -1 when no current entry can be found.
func get_current_entry_id() -> int:
	var current_dialogue_id : int = clampi(_m_read_needle - 1, 0, size())
	if has_entry_id(current_dialogue_id):
		return current_dialogue_id
	return -1


## Sets the current dialogue entry if available.
func set_current_entry(p_id : int) -> void:
	if has_entry_id(p_id):
		var dialogue_entry : DialogueEntry = get_entry_at(p_id)
		_m_branch_id_needle = dialogue_entry.get_branch_id()
		_m_read_needle = p_id
	else:
		push_warning("DialogueEngine: Unable to set entry ID to '%d' since it's invalid." % p_id)


## Advances the dialogue and emits the next [DialogueEntry] with text data through the [signal dialogue_continued] signal. Entries with conditional data are emitted through the [signal entry_visited] signal.
func advance(p_instant_finish : bool = false) -> void:
	if _m_dialogue_tree.is_empty():
		push_warning("DialogueEngine: Traversing dialogue on an empty tree!")
		p_instant_finish = true # finish abruptly and as safely as possible

	if not _m_has_dialogue_started:
		_m_has_dialogue_started = true
		dialogue_started.emit()

	if _m_read_needle == _m_dialogue_tree.size():
		dialogue_about_to_finish.emit()

	if _m_invalid_goto_detected:
		__reset_needles()
		dialogue_cancelled.emit()

	if p_instant_finish:
		_m_read_needle = _m_dialogue_tree.size()
	else:
		var current_dialogue_entry : DialogueEntry = get_current_entry()
		if is_instance_valid(current_dialogue_entry) and current_dialogue_entry.has_condition():
			entry_visited.emit(current_dialogue_entry)
			var condition : Callable = current_dialogue_entry.get_condition()
			var result : bool = condition.call()
			var target_goto_id : int = current_dialogue_entry.get_condition_goto_ids()[result]
			if target_goto_id != DialogueEntry.INVALID_CONDITION_GOTO and has_entry_id(target_goto_id):
				var target_dialogue_entry : DialogueEntry = get_entry_at(target_goto_id)
				_m_read_needle = target_goto_id
				_m_branch_id_needle = target_dialogue_entry.get_branch_id()
			else:
				push_warning("DialogueEngine: Invalid condition goto for on entry ID '%d' found.\nCancelling dialogue." % [current_dialogue_entry.get_id()])
				__reset_needles()
				dialogue_cancelled.emit()
				return
		elif _m_read_needle != 0 and is_instance_valid(current_dialogue_entry) and current_dialogue_entry.has_options():
			var chosen_option_id : int = current_dialogue_entry.get_chosen_option()
			if chosen_option_id != DialogueEntry.INVALID_CHOSEN_OPTION:
				var option_goto_id : int = current_dialogue_entry.get_option_goto_id(chosen_option_id)
				if option_goto_id != DialogueEntry.INVALID_OPTION_GOTO and has_entry_id(option_goto_id):
					var target_dialogue_entry : DialogueEntry = get_entry_at(option_goto_id)
					_m_read_needle = option_goto_id
					_m_branch_id_needle = target_dialogue_entry.get_branch_id()
				else:
					push_warning("DialogueEngine: Invalid option goto for option ID '%d' with text '%s'.\nAssociated DialogueEntry ID '%d' with text '%s'\nCancelling dialogue." % [option_goto_id, current_dialogue_entry.get_option_text(option_goto_id), current_dialogue_entry.get_id(), current_dialogue_entry.get_text()])
					__reset_needles()
					dialogue_cancelled.emit()
					return
			else:
				push_warning("DialogueEngine: Invalid chosen option for option for DialogueEntry ID '%d' with text '%s'.\nCancelling dialogue." % [current_dialogue_entry.get_id(), current_dialogue_entry.get_text()])
				__reset_needles()
				dialogue_cancelled.emit()
				return

	for read_id : int in range(_m_read_needle, _m_dialogue_tree.size()):
		var target_dialogue_entry : DialogueEntry = get_entry_at(read_id)
		var target_dialogue_branch_id : int = target_dialogue_entry.get_branch_id()
		if _m_branch_id_needle == target_dialogue_branch_id:
			if target_dialogue_entry.has_condition():
				_m_read_needle = read_id + 1 # adding + 1 so that get_current_entry() returns target_dialogue_entry upon the next advance() call
				# This condition will be processed on the next advance() call
				advance()
				return
			# Process the top-level goto entry if needed -- we'll need to update the read needle and branch needle in order to read that goto entry upon the next call to next()
			var top_level_goto_id : int = target_dialogue_entry.get_goto_id()
			if top_level_goto_id == DialogueEntry.GOTO_DEFAULT:
				_m_read_needle = read_id + 1
			else:
				var top_level_goto_dialogue_entry : DialogueEntry = get_entry_at(top_level_goto_id)
				if is_instance_valid(top_level_goto_dialogue_entry):
					_m_read_needle = top_level_goto_id
					_m_branch_id_needle = top_level_goto_dialogue_entry.get_branch_id()
				else:
					push_warning("DialogueEngine: Invalid top-level goto detected on DialogueEntry ID '%d' with text '%s'.\nDialogue will be cancelled upon the next advance() call." % [target_dialogue_entry.get_id(), target_dialogue_entry.get_text()])
					_m_invalid_goto_detected = true
			entry_visited.emit(target_dialogue_entry)
			dialogue_continued.emit(target_dialogue_entry)
			return

	__reset_needles()
	dialogue_finished.emit()
	return


## Returns the number of dialogue tree entries stored.
func size() -> int:
	return _m_dialogue_tree.size()


## Returns true if no dialogue tree entry is stored.
func is_empty() -> bool:
	return _m_dialogue_tree.is_empty()


## Replaces the [DialogueEntry] at the provided ID.
func set_entry_at(p_entry_id : int, p_dialogue_entry : DialogueEntry) -> void:
	_m_dialogue_tree[p_entry_id] = p_dialogue_entry.get_data()


## Returns the [DialogueEntry] at the provided ID. Returns [code]null[/code] when the ID is invalid.
func get_entry_at(p_entry_id : int) -> DialogueEntry:
	if not has_entry_id(p_entry_id):
		push_warning("DialogueEngine: Attempted to return entry with invalid ID \"%d\"." % p_entry_id)
		return null
	var target_dialogue_entry_dictionary : Dictionary = _m_dialogue_tree[p_entry_id]
	return DialogueEntry.new(p_entry_id, self, target_dialogue_entry_dictionary)


## Returns true if a [DialogueEntry] ID is available.
func has_entry_id(p_entry_id : int) -> bool:
	return p_entry_id >= 0 and p_entry_id < _m_dialogue_tree.size()


## Returns the [DialogueEntry] with the provided name. See [method DialogueEntry.set_name].
func get_entry_with_name(p_dialogue_entry_name : String) -> DialogueEntry:
	if p_dialogue_entry_name == &"":
		push_warning("DialogueEngine: Attempted to return entry with empty name." % p_dialogue_entry_name)
		return null
	for entry_index : int in size():
		var target_dialogue_entry_dictionary : Dictionary = _m_dialogue_tree[entry_index]
		var dialogue_entry : DialogueEntry = DialogueEntry.new(entry_index, self, target_dialogue_entry_dictionary)
		if dialogue_entry.get_name() == p_dialogue_entry_name:
			return dialogue_entry
	push_warning("DialogueEngine: Attempted to return entry with non-existent name \"%s\"." % p_dialogue_entry_name)
	return null


## Injects the [DialogueEntry] at the end of the chain of its current branch.
func push_back(p_dialogue_entry : DialogueEntry) -> void:
	var write_needle : int = _m_dialogue_tree.size()
	_m_dialogue_tree.push_back(p_dialogue_entry.get_data())
	p_dialogue_entry.set_engine(self)
	p_dialogue_entry.set_id(write_needle)


## Pops a [DialogueEntry] from the chain.[br]
## br]
## [color=yellow]Warning:[/color] the returned entry will be detached from the dialogue engine.
func pop_back() -> DialogueEntry:
	var dialogue_entry_dictionary : Dictionary = _m_dialogue_tree.pop_back()
	var dialogue_entry : DialogueEntry = DialogueEntry.new(-1, null, dialogue_entry_dictionary)
	return dialogue_entry


## Resets the internal reading needle. Calling [method next]
func reset() -> void:
	# If we are not finished reading, the dialogue was cancelled -- notify listeners
	if _m_read_needle != 0 and _m_read_needle != _m_dialogue_tree.size():
		dialogue_cancelled.emit()
	__reset_needles()


## Clears all the dialogue added. After calling this function, [method is_empty] will return `true`.
func clear() -> void:
	_m_dialogue_tree.clear()


# Resets the needles used when advancing the dialogue.
func __reset_needles() -> void:
	_m_read_needle = 0
	_m_branch_id_needle = 0
	_m_has_dialogue_started = false
	_m_invalid_goto_detected = false


## Returns an a list of unique branch IDs associated with the engine.
func get_unique_branch_ids() -> Array:
	var branch_ids_dictionary : Dictionary = {}
	for dialogue_entry_id : int in _m_dialogue_tree.size():
		var dialogue_entry : DialogueEntry = get_entry_at(dialogue_entry_id)
		var branch_id : int = dialogue_entry.get_branch_id()
		branch_ids_dictionary[branch_id] = true
	return branch_ids_dictionary.keys()


## Sets the [DialogueEngine] data.
func set_data(p_dialogue_engine_data : Array[Dictionary]) -> void:
	_m_dialogue_tree = p_dialogue_engine_data
	if EngineDebugger.is_active():
		for dialogue_entry_id : int in _m_dialogue_tree.size():
			var dialogue_entry : DialogueEntry = get_entry_at(dialogue_entry_id)
			dialogue_entry.__send_entry_to_engine_viewer()


## Returns the [DialogueEngine] data. [DialogueEngine] by itself does not store any [Object] subclass -- each [DialogueEntry] is simply an API to manage data stored within a [Dictionary].
func get_data() -> Array[Dictionary]:
	return _m_dialogue_tree


## Sets a name to the engine. Internally it's only useful in debug builds since the name is only used for the dialogue viewer in the debugger.
func set_name(p_name : String) -> void:
	set_meta(&"name", p_name)
	if EngineDebugger.is_active():
		EngineDebugger.send_message("dialogue_engine:set_name", [get_instance_id(), p_name])


## Gets the name of the engine. Internally it's only useful in debug builds since the name is only used for the dialogue viewer in the debugger.
func get_name() -> String:
	return get_meta(&"name", "")


## [color=yellow]Warning:[/color] overriding [code]_init()[/code] will make the debugger behave unexpectedly under certain scenarios. Make sure to call [code]super()[/code] within the subclass for proper debugger support.
func _init() -> void:
	if EngineDebugger.is_active():
		# Register
		var current_script : Resource = get_script()
		var path : String = current_script.get_path()
		var name : String = get_name()
		EngineDebugger.send_message("dialogue_engine:register_engine", [get_instance_id(), name, path])

		# Setup event callbacks
		var notify_debugger_to_reset_graph_colors : Callable = func () -> void:
			EngineDebugger.send_message("dialogue_engine:dialogue_started", [get_instance_id()])
		var _success : int = dialogue_started.connect(notify_debugger_to_reset_graph_colors)

		var notify_debugger_of_entry_visited : Callable = func (p_dialogue_entry : DialogueEntry) -> void:
			EngineDebugger.send_message("dialogue_engine:entry_visited", [get_instance_id(), p_dialogue_entry.get_id()])
		_success = entry_visited.connect(notify_debugger_of_entry_visited)

		var notify_debugger_of_dialogue_finished : Callable = func () -> void:
			EngineDebugger.send_message("dialogue_engine:dialogue_finished", [get_instance_id()])
		_success = dialogue_finished.connect(notify_debugger_of_dialogue_finished)

		var notify_debugger_of_dialogue_cancelled : Callable = func () -> void:
			EngineDebugger.send_message("dialogue_engine:dialogue_cancelled", [get_instance_id()])
		_success = dialogue_cancelled.connect(notify_debugger_of_dialogue_cancelled)

	# Execute the "pure virtual" call -- users may (or may not) use this call to setup their dialogue
	_setup()


## Pseudo-virtual function. Called when [method DialogueEngine._init] finishes, useful when extending [DialogueEngine].
func _setup() -> void:
	pass
