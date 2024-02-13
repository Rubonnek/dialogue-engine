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


func __on_dialogue_started() -> void:
	print("Dialogue Started!")


func __on_dialogue_continued(p_dialogue_entry : DialogueEntry) -> void:
	var label : RichTextLabel = RichTextLabel.new()
	label.set_use_bbcode(true)
	label.set_fit_content(true)
	if p_dialogue_entry.has_metadata("author"):
		var author : String = p_dialogue_entry.get_metadata("author")
		label.set_text("  > " + author + ": " + p_dialogue_entry.get_text())
	else:
		label.set_text("  > " + p_dialogue_entry.get_text())
	add_child(label)


func __on_dialogue_finished() -> void:
	print("Dialogue Finished! Exiting...")
	get_tree().quit()


func __on_dialogue_cancelled() -> void:
	print("Dialogue Cancelled! Exiting...")
	get_tree().quit()

