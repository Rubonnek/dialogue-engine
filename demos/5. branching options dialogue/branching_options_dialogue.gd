extends DialogueEngine


enum {
DEFAULT_TOPIC = 0, # this is the default branch id used at each add_text_entry call unless a different branch ID is specified
GO_BACK_TO_SLEEP = 1,
KEEP_WORKING = 2
}


func _setup() -> void:
	var entry : DialogueEntry = add_text_entry("The storm rages right outside the window. I should...")

	var option_id_1 : int = entry.add_option("Go back to sleep.")
	var option_id_1_entry : DialogueEntry = add_text_entry("That's right, sleep is for the strong 💪.", GO_BACK_TO_SLEEP)
	entry.set_option_goto_id(option_id_1, option_id_1_entry.get_id())

	var option_id_2 : int = entry.add_option("Get back to work.")
	var option_id_2_entry : DialogueEntry = add_text_entry("That's right, let's get back to work 🫡", KEEP_WORKING)
	entry.set_option_goto_id(option_id_2, option_id_2_entry.get_id())

	# Join branches into the default topic (i.e. branch id 0)
	var default_topic : DialogueEntry = add_text_entry("Some time passes...")
	option_id_1_entry.set_goto_id(default_topic.get_id())
	option_id_2_entry.set_goto_id(default_topic.get_id())

	# None of the following entries will be connected on the graph and won't be shown when advancing the dialogue
	add_text_entry("A sleep entry skipped due to missing goto against this entry.", GO_BACK_TO_SLEEP)
	add_text_entry("A working entry due to missing goto against this entry.", KEEP_WORKING)

	add_text_entry("<Press 'Space' or 'Enter' to quit>")
