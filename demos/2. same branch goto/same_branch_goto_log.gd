extends VBoxContainer

@export var dialogue_gdscript : GDScript = null
var dialogue_engine : DialogueEngine = null


func _ready() -> void:
	dialogue_engine = dialogue_gdscript.new()
	dialogue_engine.dialogue_continued.connect(__on_dialogue_continued)
	dialogue_engine.dialogue_finished.connect(__on_dialogue_finished)


func _input(p_input_event : InputEvent) -> void:
	if p_input_event.is_action_pressed(&"ui_accept"):
		dialogue_engine.advance()


var enabled_buttons : Array[Button] = []
func __on_dialogue_continued(p_dialogue_entry : DialogueEntry) -> void:
	var label : RichTextLabel = RichTextLabel.new()
	label.set_use_bbcode(true)
	label.set_fit_content(true)
	label.set_text("  > " + p_dialogue_entry.get_text())
	add_child(label)

func __on_dialogue_finished() -> void:
	get_tree().quit()
