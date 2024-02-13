extends VBoxContainer

@export var dialogue_gdscript : GDScript = null
var dialogue_engine : DialogueEngine = null


func _ready() -> void:
	dialogue_engine = dialogue_gdscript.new()
	dialogue_engine.dialogue_started.connect(__on_dialogue_started)
	dialogue_engine.dialogue_continued.connect(__on_dialogue_continued)
	dialogue_engine.dialogue_finished.connect(__on_dialogue_finished)
	dialogue_engine.dialogue_cancelled.connect(__on_dialogue_cancelled)

func _input(p_input_event : InputEvent) -> void:
	if p_input_event.is_action_pressed(&"ui_accept"):
		dialogue_engine.advance()
		accept_event() # to avoid hidding an button due to the input event travelling through the children


func __on_dialogue_started() -> void:
	print("Dialogue Started!")


var enabled_buttons : Array[Button] = []
func __on_dialogue_continued(p_dialogue_entry : DialogueEntry) -> void:
	var label : RichTextLabel = RichTextLabel.new()
	label.set_use_bbcode(true)
	label.set_fit_content(true)
	label.set_text("  > " + p_dialogue_entry.get_text())
	add_child(label)

	if p_dialogue_entry.has_options():
		for option_id : int in range(0, p_dialogue_entry.get_option_count()):
			var option_text : String = p_dialogue_entry.get_option_text(option_id)
			var button : Button = Button.new()
			button.set_text(option_text)
			add_child(button)
			if option_id == 0:
				button.grab_focus()
			button.pressed.connect(__advance_dialogue_with_chosen_option.bind(option_id))
			enabled_buttons.push_back(button)
		set_process_input(false)


func __advance_dialogue_with_chosen_option(p_option_id : int) -> void:
	for button : Button in enabled_buttons:
		button.set_disabled(true)
	enabled_buttons.clear()

	var current_entry : DialogueEntry = dialogue_engine.get_current_entry()
	current_entry.choose_option(p_option_id)
	dialogue_engine.advance()

	set_process_input(true)


func __on_dialogue_finished() -> void:
	print("Dialogue Finished! Exiting...")
	get_tree().quit()


func __on_dialogue_cancelled() -> void:
	print("Dialogue Cancelled! Exiting...")
	get_tree().quit()

