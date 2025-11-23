#============================================================================
#  plugin.gd                                                                |
#============================================================================
#                         This file is part of:                             |
#                            DIALOGUE ENGINE                                |
#           https://github.com/Rubonnek/dialogue-engine                     |
#============================================================================
# Copyright (c) 2023-2025 Wilson Enrique Alvarez Torres                     |
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

@tool
extends EditorPlugin


var m_editor_debugger_plugin : EditorDebuggerPlugin = preload("debugger/editor_debugger_plugin.gd").new()


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
