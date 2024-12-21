extends DialogueEngine


const SAVE_PATH : String = "user://save.dat"
var counter : int = 0
var start_counting_id : int = 0
var log_history : Array = []


func get_log_history() -> Array:
	return log_history


func _setup() -> void:
	add_text_entry("This is an example of an infinite dynamically generated/saved/loaded dialogue.")
	add_text_entry("You can save the dialogue progress at any time by clicking the save button above.")
	add_text_entry("And when you restart this scene, the dialogue will continue from where it left off.")
	add_text_entry("As the dialogue progresses, the graph in the debugger will update automatically as well.")
	add_text_entry("Let's count to infinity!!")
	dialogue_continued.connect(__log_history)
	dialogue_about_to_finish.connect(__continue_counting)

	# Load previous state if any
	load_state()


func __log_history(p_dialogue_entry : DialogueEntry) -> void:
	# Always track the log history:
	log_history.push_back(p_dialogue_entry.get_formatted_text())

func __continue_counting() -> void:
	counter += 1
	add_text_entry(str(counter))


func save_state() -> void:
	var file_handle: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file_handle.store_var(counter)
	file_handle.store_var(get_current_entry().get_id())
	file_handle.store_var(log_history)
	print("State Saved")


func load_state() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file_handle: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		counter = file_handle.get_var()
		var entry_id : int = file_handle.get_var()
		if has_entry_id(entry_id):
			set_current_entry(entry_id)
		else:
			set_current_entry(add_text_entry("Let's continue counting!!").get_id())
		log_history = file_handle.get_var()
		print("State Loaded")


func clear_state() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("State Cleared")
