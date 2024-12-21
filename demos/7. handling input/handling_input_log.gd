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
		accept_event()


func __on_dialogue_started() -> void:
	print("Dialogue Started!")


func __on_dialogue_continued(p_dialogue_entry : DialogueEntry) -> void:
	var label : RichTextLabel = RichTextLabel.new()
	label.set_use_bbcode(true)
	label.set_fit_content(true)
	if p_dialogue_entry.has_metadata("author"):
		var author : String = p_dialogue_entry.get_metadata("author")
		label.set_text("  > " + author + ": " + p_dialogue_entry.get_formatted_text())
	else:
		label.set_text("  > " + p_dialogue_entry.get_formatted_text())
	add_child(label)

	if p_dialogue_entry.has_metadata("get_player_name"):
		__get_player_name()


func __on_dialogue_finished() -> void:
	print("Dialogue Finished! Exiting...")
	get_tree().quit()


func __on_dialogue_cancelled() -> void:
	print("Dialogue Cancelled! Exiting...")
	get_tree().quit()

func __get_player_name() -> void:
	var line_edit : LineEdit = LineEdit.new()
	add_child(line_edit)
	var p_data : Array = []
	line_edit.text_submitted.connect(func(text : String) -> void:
		p_data.push_back(text)
		)
	line_edit.grab_focus()
	line_edit.set_placeholder("Enter your name.")
	set_process_input(false)
	# Must wait to get the player name in order to update the variable within DialogueEngine
	await line_edit.text_submitted
	line_edit.set_editable(false)
	@warning_ignore("unsafe_property_access")
	dialogue_engine.player_name = p_data[0]
	set_process_input(true)
	dialogue_engine.advance()
