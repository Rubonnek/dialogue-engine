extends DialogueEngine

var player_name : String # will be set by the UI code

func _setup() -> void:
	add_text_entry("Welcome adventurer. May I know you name?").set_metadata("get_player_name", "The UI code will act accordingly and inject player_name into DialogueEngine.")
	add_text_entry("The legendary {player_name}!? Please, follow me this way. I will personally show you our guild.").set_format({"player_name" : get.bind("player_name")}, DialogueEntry.FORMAT_FUNCTION)
	add_text_entry("Press <Enter> or <Space> to exit.")
