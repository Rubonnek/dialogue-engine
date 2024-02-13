extends DialogueEngine


func _setup() -> void:
	var first_entry : DialogueEntry = add_text_entry("This is an example of...")
	add_text_entry("This text will be shown on the debugger connected to branch ID 0")
	add_text_entry("This text will be shown on the debugger as a separate graph node not connected to branch id 0", 1)
	var first_entry_goto : DialogueEntry = add_text_entry("a skipped dialogue! Check the debugger out!")
	first_entry.set_goto_id(first_entry_goto.get_id())
	add_text_entry("Press <Enter> or <Space> to exit.")
