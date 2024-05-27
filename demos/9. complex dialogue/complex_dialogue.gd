extends Control


@export var dialogue_gdscript : GDScript = null
var dialogue_engine : DialogueEngine = null

@onready var animator: AnimationPlayer = $Animator
@onready var vbox: VBoxContainer = $Center/Box/Margin/VBox/VBox
@onready var peter: TextureRect = $Center/Box/Margin/VBox/Peter
@onready var john: TextureRect = $Center/Box/Margin/VBox/John


func _ready() -> void:
	dialogue_engine = dialogue_gdscript.new()
	dialogue_engine.dialogue_started.connect(__on_dialogue_started)
	dialogue_engine.dialogue_continued.connect(__on_dialogue_continued)
	dialogue_engine.dialogue_finished.connect(__on_dialogue_finished)
	dialogue_engine.dialogue_cancelled.connect(__on_dialogue_cancelled)



func _input(p_input_event : InputEvent) -> void:
	if p_input_event.is_action_pressed(&"ui_accept"):
		if not animator.is_playing():
			dialogue_engine.advance()
		else:
			# Player is inpatient -- auto-advance the text
			var animation_name : StringName = animator.get_current_animation()
			var animation : Animation = animator.get_animation(animation_name)
			animator.advance(animation.get_length()) # this will fire the animation_finished signal automatically
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
	vbox.add_child(label, true)
	
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
	
	# Hide all portraits
	peter.hide()
	john.hide()
	
	# Show author portrait
	if p_dialogue_entry.has_metadata("author"):
		if p_dialogue_entry.get_metadata("author") == "Peter":
			peter.show()
		else:
			john.show()


func __on_dialogue_finished() -> void:
	print("Dialogue Finished! Exiting...")
	get_tree().quit()


func __on_dialogue_cancelled() -> void:
	print("Dialogue Cancelled! Exiting...")
	get_tree().quit()


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
	# Simple portrait animation keys
	var peter_track_index : int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(peter_track_index, "../../Peter:self_modulate")
	animation.track_set_interpolation_type(peter_track_index, Animation.INTERPOLATION_NEAREST)
	var john_track_index : int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(john_track_index, "../../John:self_modulate")
	animation.track_set_interpolation_type(john_track_index, Animation.INTERPOLATION_NEAREST)
	var sound_track_index : int = animation.add_track(Animation.TYPE_METHOD)
	# The path provided here points to the root node (i.e. ComplexDialogue node)
	animation.track_set_path(sound_track_index, "../../../../../..")

	# Configure keys
	var total_time : float = 0.0
	var total_visible_characters : int = 0
	var whitespace_time_offset : float = 0.0
	animation.track_insert_key(track_index, total_time, 0)
	animation.track_insert_key(peter_track_index, total_time, Color.WHITE)
	animation.track_insert_key(john_track_index, total_time, Color.WHITE)
	var total_animation_length : float = 0.0
	for character : String in p_text:
		total_time += p_time_per_character
		total_visible_characters += 1
		if not p_time_whitespace and whitespace_regex.sub(character, "", true).is_empty():
			whitespace_time_offset += p_time_per_character
			continue
		total_animation_length = total_time - whitespace_time_offset
		animation.track_insert_key(track_index, total_animation_length, total_visible_characters)
		# Simple portrait animation
		var should_blink : bool = total_visible_characters % 2 == 0 and total_visible_characters < p_text.length() - 1
		animation.track_insert_key(peter_track_index, total_animation_length, Color.DARK_GRAY if should_blink else Color.WHITE)
		animation.track_insert_key(john_track_index, total_animation_length, Color.DARK_GRAY if should_blink else Color.WHITE)
		# The sounds can be directly added here in the animation or in the function (called by the animation)
		if should_blink:
			animation.track_insert_key(sound_track_index, total_animation_length, {"method": "__play_sound", "args": []})
	
	animation.set_length(total_animation_length)

	if p_instant_first_character:
		if animation.track_get_key_count(track_index) > 0:
			# Shift all the keys back in time according to the time it took per character
			for key_index : int in animation.track_get_key_count(track_index):
				var key_time : float = animation.track_get_key_time(track_index, key_index)
				animation.track_set_key_time(track_index, key_index, key_time - p_time_per_character)
			animation.set_length(total_animation_length - p_time_per_character)
	return animation


func __play_sound() -> void:
	# Play dialogue sound here
	print("sound played")
