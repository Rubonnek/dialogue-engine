extends DialogueEngine

func _setup() -> void:
	# Use DialogueEntry.set_metadata for data that must be available through DialogueEngine.dialogue_continued signal.
	# The metadata handling per DialogueEntry must be implemented by the user.
	add_text_entry("[i]We won! Let's goooo!![/i]").set_metadata("author", "Gary")
	add_text_entry("Press <Enter> or <Space> to exit.")
