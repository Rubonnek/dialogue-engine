extends VBoxContainer

@export var dialogue_gdscript : GDScript = null
var dialogue_engine : DialogueEngine = null

@onready var animation_player : AnimationPlayer = find_child("LogAnimationPlayer")


func _ready() -> void:
	dialogue_engine = dialogue_gdscript.new()
	dialogue_engine.dialogue_started.connect(__on_dialogue_started)
	dialogue_engine.dialogue_continued.connect(__on_dialogue_continued)
	dialogue_engine.dialogue_finished.connect(__on_dialogue_finished)
	dialogue_engine.dialogue_cancelled.connect(__on_dialogue_cancelled)


func _input(p_input_event : InputEvent) -> void:
	if p_input_event.is_action_pressed(&"ui_accept"):
		if not animation_player.is_playing():
			dialogue_engine.advance()
		else:
			# Player is inpatient -- auto-advance the text
			var animation_name : StringName = animation_player.get_current_animation()
			var animation : Animation = animation_player.get_animation(animation_name)
			animation_player.advance(animation.get_length()) # this will fire the animation_finished signal automatically
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
	add_child(label, true)

	# Setup the animation:
	animation_player.stop(true) # internally some timers do not reset properly unless we do this
	if not animation_player.has_animation_library(&"demo"):
		var new_animation_library : AnimationLibrary = AnimationLibrary.new()
		animation_player.add_animation_library(&"demo", new_animation_library)
	var animation_library : AnimationLibrary = animation_player.get_animation_library(&"demo")
	var animation : Animation = create_visible_characters_animation_per_character(label.get_text(), 0.045, true)
	animation_player.set_root_node(label.get_path())
	animation_library.add_animation(&"dialogue", animation)
	animation_player.play(&"demo/dialogue")

	# Setup the post dialogue callback
	if p_dialogue_entry.has_metadata(&"get_player_name"):
		animation_player.animation_finished.connect(__on_animation_finished.bind(__get_player_name), CONNECT_ONE_SHOT)


func __on_dialogue_finished() -> void:
	print("Dialogue Finished! Exiting...")
	get_tree().quit()


func __on_dialogue_cancelled() -> void:
	print("Dialogue Cancelled! Exiting...")
	get_tree().quit()


# Must return player name to update the variable within DialogueEngine
func __get_player_name() -> void:
	# Get player name into the current stack:
	var line_edit : LineEdit = LineEdit.new()
	add_child(line_edit)
	var p_data : Array = []
	line_edit.text_submitted.connect(func(text : String) -> void:
		p_data.push_back(text)
		)
	line_edit.grab_focus()
	line_edit.set_placeholder("Enter your name.")

	# Disable input processing by this node to avoid calling DialogueEngine.advance if the user presses space or enter
	set_process_input(false)

	await line_edit.text_submitted
	line_edit.set_editable(false)

	# Allow the user to progress the dialogue
	set_process_input(true)

	# Auto-advance the dialogue so the user does not have to press space or enter again
	@warning_ignore("unsafe_property_access")
	dialogue_engine.player_name = p_data[0]
	dialogue_engine.advance()


func __on_animation_started(p_animation_name : StringName) -> void:
	print("Animation started:", p_animation_name)


func __on_animation_finished(p_animation_name : StringName, p_post_dialogue_callback : Callable) -> void:
	if p_animation_name == &"demo/dialogue":
		p_post_dialogue_callback.call()


# Utility function to animate the text at a constant speed
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


