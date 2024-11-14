extends DialogueEngine


func _setup() -> void:
	add_text_entry("Hello, how are you?").set_metadata("author", "Peter")
	add_text_entry("I'm fine, thank you! And you?").set_metadata("author", "John")
	add_text_entry("I'm fine too! Thank you!").set_metadata("author", "Peter")
	add_text_entry("What's your name?").set_metadata("author", "John")
	add_text_entry("I'm Peter, and you?").set_metadata("author", "Peter")
	add_text_entry("Nice to meet you Peter! I'm John!").set_metadata("author", "John")
	var entry: DialogueEntry = add_text_entry("Nice to meet you John!")
	entry.set_metadata("author", "Peter")
	entry.set_name("Exit")
