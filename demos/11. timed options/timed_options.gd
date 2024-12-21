extends VBoxContainer


@export var dialogue_gdscript : GDScript = null
var dialogue_engine : DialogueEngine = null

@onready var progress_bar : ProgressBar = $ProgressBar
@onready var vbox : VBoxContainer = $VBox


func _ready() -> void:
	dialogue_engine = dialogue_gdscript.new()
	dialogue_engine.dialogue_started.connect(__on_dialogue_started)
	dialogue_engine.dialogue_continued.connect(__on_dialogue_continued)
	dialogue_engine.dialogue_finished.connect(__on_dialogue_finished)
	dialogue_engine.dialogue_cancelled.connect(__on_dialogue_cancelled)


func _input(p_input_event : InputEvent) -> void:
	if p_input_event.is_action_pressed(&"ui_accept"):
		dialogue_engine.advance()
		accept_event() # to avoid hitting a button due to the input event travelling through the children


func __on_dialogue_started() -> void:
	print("Dialogue Started!")


var enabled_buttons : Array[Button] = []


func __on_dialogue_continued(p_dialogue_entry : DialogueEntry) -> void:
	var label : RichTextLabel = RichTextLabel.new()
	label.set_use_bbcode(true)
	label.set_fit_content(true)
	label.set_text("  > " + p_dialogue_entry.get_text())
	vbox.add_child(label)

	if p_dialogue_entry.has_options():
		var dont_show_options : Array = p_dialogue_entry.get_metadata("dont_show_options", [])
		for option_id : int in range(0, p_dialogue_entry.get_option_count()):
			if option_id in dont_show_options:
				continue
			var option_text : String = p_dialogue_entry.get_option_text(option_id)
			var button : Button = Button.new()
			button.set_text(option_text)
			vbox.add_child(button)
			var tween: Tween = create_tween()
			if option_id == 0:
				button.grab_focus()
				tween.tween_property(button, "modulate", Color.TRANSPARENT, 3.0)
				tween.tween_callback(button.hide)
			else:
				# Only show other buttons after the tween finishes
				button.hide()
				tween.tween_callback(button.show).set_delay(5.0)

				if option_id == 1:
					tween.tween_callback(button.grab_focus)
					tween.tween_callback(progress_bar.show)
					tween.tween_method(progress_bar.set_value, 1.0, 0.0, 2.0)

					# The timer has just finished
					tween.tween_callback(progress_bar.hide)
					tween.tween_callback(advance_dialogue_no_answer)
			button.pressed.connect(__advance_dialogue_with_chosen_option.bind(option_id))
			enabled_buttons.push_back(button)
		set_process_input(false)


func advance_dialogue_no_answer() -> void:
	for button : Button in enabled_buttons:
		button.set_disabled(true)

	var entry : DialogueEntry = dialogue_engine.get_current_entry()
	var option_id : int = entry.get_metadata("auto_choose")
	entry.choose_option(option_id)
	dialogue_engine.advance()
	set_process_input(true)


func __advance_dialogue_with_chosen_option(p_option_id : int) -> void:
	# Kill all tweens from processing further
	for tween: Tween in get_tree().get_processed_tweens():
		tween.kill()
	for button : Button in enabled_buttons:
		button.set_disabled(true)
		# Reset modulate of vanishing button
		button.modulate = Color.WHITE
	enabled_buttons.clear()
	progress_bar.hide()

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
