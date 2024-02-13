extends DialogueEngine

var have_we_talked_before : bool = false

enum branch {
	STRANGERS,
	ACQUAINTANCES,
}

func __have_we_talked_before() -> bool:
	return have_we_talked_before

func _setup() -> void:
	add_text_entry("Hello!")
	var condition_entry : DialogueEntry = add_conditional_entry(__have_we_talked_before)
	var if_true : DialogueEntry = add_text_entry("Hey! We meet again!", branch.STRANGERS)
	var if_false : DialogueEntry = add_text_entry("It's nice to meet you!", branch.ACQUAINTANCES)
	condition_entry.set_condition_goto_ids(if_true.get_id(), if_false.get_id())
	add_text_entry("<Press 'Enter' or 'Space' to exit>")

	dialogue_finished.connect(func() -> void: have_we_talked_before = true)
