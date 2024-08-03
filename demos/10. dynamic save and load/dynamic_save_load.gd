extends Control


@export var dialogue_gdscript : GDScript = null
var dialogue_engine : DialogueEngine = null

@onready var dialogue : VBoxContainer = $VBox/Dialogue
@onready var history : CenterContainer = $History
@onready var history_log : VBoxContainer = $History/Panel/Margin/HistoryLog
@onready var animator : AnimationPlayer = $Animator


func _ready() -> void:
	dialogue_engine = dialogue_gdscript.new()
	dialogue_engine.dialogue_started.connect(__on_dialogue_started)
	dialogue_engine.dialogue_continued.connect(__on_dialogue_continued)
	dialogue_engine.dialogue_finished.connect(__on_dialogue_finished)
	dialogue_engine.dialogue_cancelled.connect(__on_dialogue_cancelled)


func _input(p_input_event : InputEvent) -> void:
	if p_input_event.is_action_pressed(&"ui_accept"):
		if animator.is_playing():
			# Player is inpatient -- auto-advance the text
			var animation_name : StringName = animator.get_current_animation()
			var animation : Animation = animator.get_animation(animation_name)
			animator.advance(animation.get_length()) # this will fire the animation_finished signal automatically else:
		else:
			# Advance current entry
			dialogue_engine.advance()
		accept_event() # accepting input event here to stop it from traversing into into buttons possibly added through the interaction


func __on_dialogue_started() -> void:
	print("Dialogue Started!")


func __on_dialogue_continued(p_dialogue_entry : DialogueEntry) -> void:
	# Add the text to the log:
	var label : RichTextLabel = RichTextLabel.new()
	label.set_use_bbcode(true)
	label.set_fit_content(true)
	if p_dialogue_entry.has_metadata("author"):
		var author : String = p_dialogue_entry.get_metadata("author")
		label.set_text("  > " + author + ": " + p_dialogue_entry.get_formatted_text())
	else:
		label.set_text("  > " + p_dialogue_entry.get_formatted_text())
	dialogue.add_child(label, true)

	# Setup the animation:
	animator.stop(true) # internally some timers do not reset properly unless we do this
	if not animator.has_animation_library(&"demo"):
		var new_animation_library : AnimationLibrary = AnimationLibrary.new()
		animator.add_animation_library(&"demo", new_animation_library)
	var animation_library : AnimationLibrary = animator.get_animation_library(&"demo")
	var animation : Animation = create_visible_characters_animation_per_character(label.get_text(), 0.045, true)
	animator.set_root_node(label.get_path())
	animation_library.add_animation(&"dialogue", animation)
	animator.play(&"demo/dialogue")


func __on_dialogue_finished() -> void:
	print("Dialogue Finished! Exiting...")
	get_tree().quit()


func __on_dialogue_cancelled() -> void:
	print("Dialogue Cancelled! Exiting...")
	get_tree().quit()


func __on_animation_started(p_animation_name : StringName) -> void:
	print("Animation started:", p_animation_name)


func create_visible_characters_animation_per_character(p_text : String, p_time_per_character : float, p_instant_first_character : bool = false, p_time_whitespace : bool = false)  -> Animation:
	# Do initial calculations
	var whitespace_regex : RegEx
	if not p_time_whitespace or p_instant_first_character:
		whitespace_regex = RegEx.new()
		whitespace_regex.compile("\\s")

	# Create animation and track
	var animation : Animation = Animation.new()
	var track_index : int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, ".:visible_characters")
	animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_LINEAR)

	# Configure keys
	var total_time : float = 0.0
	var total_visible_characters : int = 0
	var whitespace_time_offset : float = 0.0
	animation.track_insert_key(track_index, total_time, 0)
	var total_animation_length : float = 0.0
	for character : String in p_text:
		total_time += p_time_per_character
		total_visible_characters += 1
		if not p_time_whitespace and whitespace_regex.sub(character, "", true).is_empty():
			whitespace_time_offset += p_time_per_character
			continue
		total_animation_length = total_time - whitespace_time_offset
		animation.track_insert_key(track_index, total_animation_length, total_visible_characters)
	animation.set_length(total_animation_length)

	if p_instant_first_character:
		if animation.track_get_key_count(track_index) > 0:
			# Shift all the keys back in time according to the time it took per character
			for key_index : int in animation.track_get_key_count(track_index):
				var key_time : float = animation.track_get_key_time(track_index, key_index)
				animation.track_set_key_time(track_index, key_index, key_time - p_time_per_character)
			animation.set_length(total_animation_length - p_time_per_character)
	return animation


func _on_history_log_toggled(p_should_be_visible : bool) -> void:
	# Free all previous history labels
	for child: Node in history_log.get_children():
		child.queue_free()

	history.visible = p_should_be_visible

	if p_should_be_visible:
		@warning_ignore("unsafe_method_access")
		var log_history : Array = dialogue_engine.get_log_history()
		for text : String in log_history:
			var label: Label = Label.new()
			label.text = text
			history_log.add_child(label)


func _on_save_pressed() -> void:
	@warning_ignore("unsafe_method_access")
	dialogue_engine.save_state()
	get_tree().quit()


func _on_clear_pressed() -> void:
	@warning_ignore("unsafe_method_access")
	dialogue_engine.clear_state()
	get_tree().quit()
