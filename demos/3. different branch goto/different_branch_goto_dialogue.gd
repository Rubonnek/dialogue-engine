extends DialogueEngine

enum { DEFAULT_BRANCH = 0, DIFFERENT_BRANCH_ONE, DIFFERENT_BRANCH_TWO, DIFFERENT_BRANCH_THREE }


func _setup() -> void:
	var first_entry : DialogueEntry = add_text_entry("This is an example of...", DEFAULT_BRANCH)
	first_entry.set_goto_id(add_text_entry("how gotos work against different branch IDs", DIFFERENT_BRANCH_TWO).get_id())
	add_text_entry("Once you jump to a different branch ID, the DialogueEngine will only consider entries in that branch ID unless you jump to a different one.", DIFFERENT_BRANCH_TWO)
	add_text_entry("If, for example, you add another text entry to a branch ID that is empty, it will show up in Debugger/DialogueEngine as such.", DIFFERENT_BRANCH_TWO)
	add_text_entry("For example, this text will be shown on branch ID %d in the debugger and not connected to anything. It won't show up in the interaction either." % DIFFERENT_BRANCH_ONE, DIFFERENT_BRANCH_ONE)
	add_text_entry("You can also create full branches in a different branch ID", DIFFERENT_BRANCH_THREE)
	add_text_entry("But since there's no jump to this branch (i.e. no goto set to this branch ID)", DIFFERENT_BRANCH_THREE)
	add_text_entry("It won't show up in the interaction", DIFFERENT_BRANCH_THREE)
	add_text_entry("See the auto-generated graph in Debugger/DialogueEngine.", DIFFERENT_BRANCH_TWO)
	add_text_entry("Press <Enter> or <Space> to exit.", DIFFERENT_BRANCH_TWO)
