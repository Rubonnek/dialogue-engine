# Dialogue Engine

<img src="icon.svg" width="128" height="128">

![GitHub Release](https://img.shields.io/github/v/release/Rubonnek/dialogue-engine?label=Current%20Release)
![Github Downloads](https://img.shields.io/github/downloads/Rubonnek/dialogue-engine/total?logo=github&label=GitHub%20Downloads)

A powerful yet minimalistic dialogue engine for the Godot Game Engine, designed for creating branching narratives with player choices, conditions, dynamic text formatting, and metadata support.

## :star: Features

- :evergreen_tree: Create complex dialogue trees with multiple choices, conditions, and branching paths using branch IDs
- :arrows_counterclockwise: Support for conditional branching with user-defined callables for dynamic decision-making
- :speech_balloon: Player choices with options, each linked to specific dialogue entries via goto IDs
- :pencil2: Dynamic text formatting using callables, arrays, and dictionaries for personalized dialogue
- :label: Named entries for easy reference and lookup within the dialogue tree
- :package: Metadata support for attaching custom data (e.g., actor names, emotions) to dialogue entries
- :signal_strength: Comprehensive signal system for dialogue events (started, continued, finished, canceled, etc.)
- :books: Simple to use -- just write the dialogue in GDScript
- :art: Easy to customize -- bring your own GUI nodes for presentation
- :hammer_and_wrench: Automated dialogue graphing and debugging integration with Godot's debugger

## :book: Usage

### Quickstart

```gdscript
var dialogue_engine : DialogueEngine = DialogueEngine.new()
dialogue_engine.add_text_entry("Hello")

var print_dialogue : Callable = func (dialogue_entry : DialogueEntry) -> void:
    print(dialogue_entry.get_text())

dialogue_engine.dialogue_continued.connect(print_dialogue)

dialogue_engine.advance() # prints "Hello"
dialogue_engine.advance() # Nothing prints -- the dialogue finished.
dialogue_engine.advance() # prints "Hello" again -- the dialogue restarted
dialogue_engine.advance() # Nothing prints -- the dialogue finished.
```

### API Overview

The dialogue engine consists of two main classes:

- **DialogueEngine**: Manages the dialogue tree and provides methods to add entries, advance through the dialogue, and handle branching logic. It emits signals like `dialogue_continued` when a text entry is reached, `dialogue_started`, `dialogue_finished`, etc.
- **DialogueEntry**: Represents a single node in the dialogue tree. It can contain text, options for player choices, conditions for branching, goto IDs for jumps, and metadata for custom data.

For more detailed API documentation, refer to the class documentation.

## :zap: Requirements

- Godot 4.2.1+

## :rocket: Getting Started

- Clone/[download](https://github.com/Rubonnek/dialogue-engine/archive/refs/heads/master.zip) the repository and check out the demos!

## :package: Installation

[Download](https://github.com/Rubonnek/dialogue-engine/archive/refs/heads/master.zip) or clone this repository and copy the contents of the
`addons` folder to your own project's `addons` folder, and enable the `Dialogue Engine` plugin in the Project Settings.
