@tool
extends EditorDebuggerPlugin


var session_id_to_dialogue_engine_viewer : Dictionary = {}


func _setup_session(p_session_id : int) -> void:
	# Add a new tab in the debugger session UI containing a label.
	var dialogue_engine_viewer : Control = preload("dialogue_engine_viewer.tscn").instantiate()
	var editor_debugger_session : EditorDebuggerSession = get_session(p_session_id)

	# Listen to the session started and stopped signals.
	@warning_ignore("unsafe_property_access", "unsafe_call_argument")
	var _success : int = editor_debugger_session.started.connect(dialogue_engine_viewer.__on_session_started)

	# Add the session tab
	editor_debugger_session.add_session_tab(dialogue_engine_viewer)

	# Track sessions so that we can push the data from _capture into the right session
	session_id_to_dialogue_engine_viewer[p_session_id] = dialogue_engine_viewer


func _has_capture(p_prefix : String) -> bool:
	return p_prefix == "dialogue_engine"


func _capture(p_message : String, p_data : Array, p_session_id : int) -> bool:
	var dialogue_engine_viewer : Control = session_id_to_dialogue_engine_viewer[p_session_id]
	@warning_ignore("unsafe_method_access")
	return dialogue_engine_viewer.on_editor_debugger_plugin_capture(p_message, p_data)
