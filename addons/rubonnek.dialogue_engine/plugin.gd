@tool
extends EditorPlugin


var m_editor_debugger_plugin : EditorDebuggerPlugin = (load((get_script() as Resource).get_path().get_base_dir().path_join("debugger/editor_debugger_plugin.gd")) as GDScript).new()


func _has_main_screen() -> bool:
	return false


func _get_plugin_name() -> String:
	return "DialogueEngineDebugger"


func _disable_plugin() -> void:
	remove_debugger_plugin(m_editor_debugger_plugin)


func _enter_tree() -> void:
	@warning_ignore("unsafe_method_access")
	add_debugger_plugin(m_editor_debugger_plugin)


func _exit_tree() -> void:
	remove_debugger_plugin(m_editor_debugger_plugin)
