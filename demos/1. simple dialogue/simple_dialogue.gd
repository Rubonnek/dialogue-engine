extends DialogueEngine

func _setup() -> void:
	add_text_entry("Hey...")
	add_text_entry("[i]Have [i][b]you[/b][/i] seen the code for this sample?[/i]")
	add_text_entry("[rainbow freq=1.0 sat=0.4 val=0.8]It's beautiful![/rainbow]")
	add_text_entry("[i][shake rate=20.0 level=5 connected=1]You won't believe it![/shake][/i]")
	add_text_entry("[code][i]Press <Enter> or <Space> to exit.[/i][/code]")
