@tool
extends PanelContainer

@export var dialogue_engine_viewer_input_blocker_center_container_ : CenterContainer
@export var dialogue_engine_viewer_input_blocker_hint_rich_text_label_ : RichTextLabel

@export var dialogue_engine_viewer_engine_selection_line_edit_ : LineEdit
@export var dialogue_engine_viewer_engine_selection_tree_ : Tree
@export var dialogue_engine_viewer_graph_edit_ : GraphEdit

@onready var m_default_input_blocker_hint_text : String = dialogue_engine_viewer_input_blocker_hint_rich_text_label_.get_text()
var m_base_dialogue_entry_graph_node_packed_scene : PackedScene = preload("base_dialogue_entry_graph_node.tscn")

var _m_remote_dialogue_engine_id_to_tree_item_map_cache : Dictionary

func _ready() -> void:
	# Create the root tree item -- we'll ignore it by default
	var _root : TreeItem = dialogue_engine_viewer_engine_selection_tree_.create_item()

	# Connect Tree Signals
	var _success : int = dialogue_engine_viewer_engine_selection_tree_.item_selected.connect(__on_tree_item_selected)
	_success = dialogue_engine_viewer_engine_selection_tree_.nothing_selected.connect(__on_tree_nothing_selected)

	# Connect line edit for filtering the DialogueEngines list
	_success = dialogue_engine_viewer_engine_selection_line_edit_.text_changed.connect(__on_dialogue_selection_line_edit_text_changed)


func __on_dialogue_selection_line_edit_text_changed(p_filter : String) -> void:
	# Hide the TreeItem that don't match the filter
	var root : TreeItem = dialogue_engine_viewer_engine_selection_tree_.get_root()
	var column : int = 0
	for child : TreeItem in root.get_children():
		if p_filter.is_empty() or p_filter in child.get_text(column):
			child.set_visible(true)
		else:
			child.set_visible(false)

	# Select an item (if any):
	dialogue_engine_viewer_engine_selection_tree_.deselect_all()
	var did_select_item : bool = false
	for child : TreeItem in root.get_children():
		if child.is_visible():
			dialogue_engine_viewer_engine_selection_tree_.set_selected(child, column) # emits item_selected signal
			child.select(column) # highlights the item on the Tree
			did_select_item = true
			break
	if not did_select_item:
		__on_tree_nothing_selected()


# ==== EDITOR DEBUGGER PLUGIN PASSTHROUGH FUNCTIONS BEGIN ======
func on_editor_debugger_plugin_capture(p_message : String, p_data : Array) -> bool:
	var column : int = 0
	match p_message:
		"dialogue_engine:register_engine":
			var dialogue_engine_id : int = p_data[0]
			var dialogue_engine_name : String = p_data[1]
			var dialogue_engine_path : String = p_data[2]

			# Generate name
			var target_name : String
			if not dialogue_engine_name.is_empty():
				target_name = dialogue_engine_name
			else:
				if not dialogue_engine_path.is_empty():
					target_name = dialogue_engine_path.trim_prefix(dialogue_engine_path.get_base_dir().path_join("/"))
				else:
					target_name = "Dialogue"
			target_name = target_name + ":" + String.num_uint64(dialogue_engine_id)

			# Create the associated tree_item and add it as metadata against the tree itself so that we can extract it easily when we receive messages from this specific DialogueEngine instance id
			var dialogue_engine_tree_item : TreeItem = dialogue_engine_viewer_engine_selection_tree_.create_item()
			dialogue_engine_tree_item.set_text(column, target_name)
			_m_remote_dialogue_engine_id_to_tree_item_map_cache[dialogue_engine_id] = dialogue_engine_tree_item

			# Store a local DialogueEngine as metadata -- reuse one if provided.
			var dialogue_engine : DialogueEngine = DialogueEngine.new()
			dialogue_engine.set_meta(&"remote_object_id", dialogue_engine_id)
			dialogue_engine_tree_item.set_metadata(column, dialogue_engine)
			return true

		"dialogue_engine:dialogue_started":
			var dialogue_engine_id : int = p_data[0]
			var dialogue_engine_tree_item : TreeItem = _m_remote_dialogue_engine_id_to_tree_item_map_cache[dialogue_engine_id]
			var stored_dialogue_engine : DialogueEngine = dialogue_engine_tree_item.get_metadata(column)
			if stored_dialogue_engine.has_meta(&"dialogue_entries_visited"):
				var dialogue_entries_visited : Array = stored_dialogue_engine.get_meta(&"dialogue_entries_visited")
				dialogue_entries_visited.clear() # the dialogue just started -- no entries have been visited yet
			__clear_graph_node_highlights_if_needed(dialogue_engine_id)
			if stored_dialogue_engine.has_meta(&"dialogue_finished"):
				stored_dialogue_engine.remove_meta(&"dialogue_finished")
			if stored_dialogue_engine.has_meta(&"dialogue_cancelled"):
				stored_dialogue_engine.remove_meta(&"dialogue_cancelled")
			return true

		"dialogue_engine:entry_visited":
			# Track the entry visited to highlight it on the GraphEdit
			var dialogue_engine_id : int = p_data[0]
			var dialogue_engine_tree_item : TreeItem = _m_remote_dialogue_engine_id_to_tree_item_map_cache[dialogue_engine_id]
			var stored_dialogue_engine : DialogueEngine = dialogue_engine_tree_item.get_metadata(column)
			var dialogue_entry_id : int = p_data[1]
			var dialogue_entry : DialogueEntry = stored_dialogue_engine.get_entry_at(dialogue_entry_id)
			var dialogue_entries_visited : Array = stored_dialogue_engine.get_meta(&"dialogue_entries_visited", [])
			dialogue_entries_visited.push_back(dialogue_entry.get_id_as_text())
			if not stored_dialogue_engine.has_meta(&"dialogue_entries_visited"):
				stored_dialogue_engine.set_meta(&"dialogue_entries_visited", dialogue_entries_visited)
			__update_graph_node_highlights_if_needed(stored_dialogue_engine)
			return true

		"dialogue_engine:dialogue_finished":
			# Track the entry visited to highlight it on the GraphEdit
			var dialogue_engine_id : int = p_data[0]
			var dialogue_engine_tree_item : TreeItem = _m_remote_dialogue_engine_id_to_tree_item_map_cache[dialogue_engine_id]
			var stored_dialogue_engine : DialogueEngine = dialogue_engine_tree_item.get_metadata(column)
			stored_dialogue_engine.set_meta(&"dialogue_finished", true)
			__update_graph_node_highlights_if_needed(stored_dialogue_engine)
			return true

		"dialogue_engine:dialogue_cancelled":
			# Track the entry visited to highlight it on the GraphEdit
			var dialogue_engine_id : int = p_data[0]
			var dialogue_engine_tree_item : TreeItem = _m_remote_dialogue_engine_id_to_tree_item_map_cache[dialogue_engine_id]
			var stored_dialogue_engine : DialogueEngine = dialogue_engine_tree_item.get_metadata(column)
			stored_dialogue_engine.set_meta(&"dialogue_cancelled", true)
			__update_graph_node_highlights_if_needed(stored_dialogue_engine)
			return true

		"dialogue_engine:set_name":
			var dialogue_engine_id : int = p_data[0]
			var dialogue_engine_tree_item : TreeItem = _m_remote_dialogue_engine_id_to_tree_item_map_cache[dialogue_engine_id]
			var remote_name : String = p_data[1]
			dialogue_engine_tree_item.set_text(column, remote_name)
			__update_graph_if_needed(dialogue_engine_id)
			return true

		"dialogue_engine:set_branch_id":
			var dialogue_engine_id : int = p_data[0]
			var dialogue_engine_tree_item : TreeItem = _m_remote_dialogue_engine_id_to_tree_item_map_cache[dialogue_engine_id]
			var stored_dialogue_engine : DialogueEngine = dialogue_engine_tree_item.get_metadata(column)
			var branch_id : int = p_data[1]
			stored_dialogue_engine.set_branch_id(branch_id)
			__update_graph_if_needed(dialogue_engine_id)
			return true

		"dialogue_engine:sync_entry":
			var dialogue_engine_id : int = p_data[0]
			var dialogue_engine_tree_item : TreeItem = _m_remote_dialogue_engine_id_to_tree_item_map_cache[dialogue_engine_id]
			var stored_dialogue_engine : DialogueEngine = dialogue_engine_tree_item.get_metadata(column)
			var remote_dialogue_entry_id : int = p_data[1]
			# May need to resize the stored engine data in order inject the entry
			var stored_dialogue_engine_data : Array = stored_dialogue_engine.get_data()
			if stored_dialogue_engine_data.size() <= remote_dialogue_entry_id:
				if stored_dialogue_engine_data.resize(remote_dialogue_entry_id + 1) != OK:
					push_warning("DialogueEngineViewer: Unable to resize dialogue engine data array! The array won't be visualized properly.")
					return true
			var remote_dialogue_entry_data : Dictionary = p_data[2]
			var remote_dialogue_entry : DialogueEntry = DialogueEntry.new(0, null, remote_dialogue_entry_data)
			stored_dialogue_engine.set_entry_at(remote_dialogue_entry_id, remote_dialogue_entry)
			__update_graph_if_needed(dialogue_engine_id)
			return true

	push_warning("DialogueEngineViewer: This should not happen. Unmanaged capture: %s %s" % [p_message, p_data])
	return false
# ==== EDITOR DEBUGGER PLUGIN PASSTHROUGH FUNCTIONS ENDS ======


# ===== VISUALIZATION FUNCTIONS BEGIN ====
const _m_choose_dialogue_string : String = "Choose a DialogueEngine to visualize."
func __on_session_started() -> void:
	# Clear cache
	_m_remote_dialogue_engine_id_to_tree_item_map_cache.clear()

	# Clear the dialogue engine tree
	dialogue_engine_viewer_engine_selection_tree_.clear()
	var _root : TreeItem = dialogue_engine_viewer_engine_selection_tree_.create_item() # need to recreate the root TreeItem which gets ignored

	# Clean up the graph edit
	__cleanup_graph_edit()

	# Show hint
	dialogue_engine_viewer_input_blocker_hint_rich_text_label_.set_text(_m_choose_dialogue_string)
	dialogue_engine_viewer_input_blocker_center_container_.show()


func __on_tree_item_selected() -> void:
	# Only update the GraphEdit if the selected tree item differs from the previously selected one
	var selected_tree_item : TreeItem = dialogue_engine_viewer_engine_selection_tree_.get_selected()
	if is_instance_valid(selected_tree_item):
		if dialogue_engine_viewer_input_blocker_center_container_.is_visible():
			dialogue_engine_viewer_input_blocker_center_container_.hide()
		__refresh_graph_for_currently_selected_item()


func __on_tree_nothing_selected() -> void:
	__cleanup_graph_edit()
	dialogue_engine_viewer_input_blocker_hint_rich_text_label_.set_text(_m_choose_dialogue_string)
	dialogue_engine_viewer_input_blocker_center_container_.show()
	dialogue_engine_viewer_engine_selection_tree_.deselect_all()


func __update_graph_if_needed(p_dialogue_engine_id : int) -> void:
	if __is_selected_tree_item_related_to_dialogue_engine(p_dialogue_engine_id):
		__refresh_graph_for_currently_selected_item()


func __is_selected_tree_item_related_to_dialogue_engine(p_dialogue_engine_id : int) -> bool:
	var selected_tree_item : TreeItem = dialogue_engine_viewer_engine_selection_tree_.get_selected()
	if is_instance_valid(selected_tree_item):
		var target_dialogue_engine_tree_item : TreeItem = _m_remote_dialogue_engine_id_to_tree_item_map_cache[p_dialogue_engine_id]
		if target_dialogue_engine_tree_item == selected_tree_item:
			return true
	return false


# FUTURE TODO: Make colors configurable through EditorSettings
const _m_previously_visited_color : Color = Color(0.271, 0.447, 0.89)
const _m_last_node_visited_color : Color = Color(0, 0.529, 0.318)
const _m_cancelled_dialogue_color : Color = Color(0.69, 0, 0)
func __update_graph_node_highlights_if_needed(p_dialogue_engine : DialogueEngine) -> void:
	var dialogue_engine_id : int = p_dialogue_engine.get_meta(&"remote_object_id")
	var dialogue_entries_visited : Array = p_dialogue_engine.get_meta(&"dialogue_entries_visited", [])
	if __is_selected_tree_item_related_to_dialogue_engine(dialogue_engine_id):
		# Highlight all the previosuly visited nodes in a specific color
		for index : int in dialogue_entries_visited.size() - 1:
			var graph_node_visited : String = dialogue_entries_visited[index]
			var graph_node : GraphNode = dialogue_engine_viewer_graph_edit_.get_node_or_null(NodePath(graph_node_visited))
			if is_instance_valid(graph_node):
				var style_box_flat : StyleBoxFlat = graph_node.get_theme_stylebox(&"titlebar").duplicate(true)
				style_box_flat.set_bg_color(_m_previously_visited_color)
				graph_node.add_theme_stylebox_override(&"titlebar", style_box_flat)
				graph_node.add_theme_stylebox_override(&"titlebar_selected", style_box_flat)

		# Highlight the last node visited as a different color to identify it from the rest
		if not dialogue_entries_visited.is_empty():
			var graph_node_visited : String = dialogue_entries_visited[-1]
			var graph_node : GraphNode = dialogue_engine_viewer_graph_edit_.get_node_or_null(NodePath(graph_node_visited))
			if is_instance_valid(graph_node):
				var style_box_flat : StyleBoxFlat = graph_node.get_theme_stylebox(&"titlebar").duplicate(true)
				if p_dialogue_engine.has_meta(&"dialogue_finished"):
					style_box_flat.set_bg_color(_m_previously_visited_color)
				elif p_dialogue_engine.has_meta(&"dialogue_cancelled"):
					style_box_flat.set_bg_color(_m_cancelled_dialogue_color)
				else:
					style_box_flat.set_bg_color(_m_last_node_visited_color)
				graph_node.add_theme_stylebox_override(&"titlebar", style_box_flat)
				graph_node.add_theme_stylebox_override(&"titlebar_selected", style_box_flat)


func __clear_graph_node_highlights_if_needed(p_dialogue_engine_id : int) -> void:
	if __is_selected_tree_item_related_to_dialogue_engine(p_dialogue_engine_id):
		for child : Node in dialogue_engine_viewer_graph_edit_.get_children():
			if child is GraphNode:
				var graph_node : GraphNode = child
				if graph_node.has_theme_stylebox_override(&"titlebar"):
					graph_node.remove_theme_stylebox_override(&"titlebar")
				if graph_node.has_theme_stylebox_override(&"titlebar_selected"):
					graph_node.remove_theme_stylebox_override(&"titlebar_selected")


func __refresh_graph_for_currently_selected_item() -> void:
	var selected_tree_item : TreeItem = dialogue_engine_viewer_engine_selection_tree_.get_selected()
	if not is_instance_valid(selected_tree_item):
		push_warning("DialogueEngineViewer: Selected tree item is invalid! This should not happen! Unable to update DialogueEngine visualization!" )
		return
	var column : int = 0
	var dialogue_engine : DialogueEngine = selected_tree_item.get_metadata(column)

	# Add all the GraphNodes
	__cleanup_graph_edit()
	for dialogue_entry_id : int in dialogue_engine.size():
		var dialogue_entry : DialogueEntry = dialogue_engine.get_entry_at(dialogue_entry_id)
		var graph_node : GraphNode = m_base_dialogue_entry_graph_node_packed_scene.instantiate()

		var dialogue_entry_id_as_string : String = dialogue_entry.get_id_as_text()
		graph_node.set_name(dialogue_entry_id_as_string)
		var title : String
		if dialogue_entry.has_name():
			title = dialogue_entry.get_name() + " - ID: " + dialogue_entry_id_as_string
		else:
			title = "DialogueEntry ID: " + dialogue_entry_id_as_string
		graph_node.set_title(title)

		var branch_id_label : Label = graph_node.find_child("BranchIDLabel")
		branch_id_label.set_text(dialogue_entry.get_branch_id_as_text())

		if dialogue_entry.has_condition():
			# When conditions are involved Text, GoTo and Options are not allowed
			var text_h_split_container : HSplitContainer = graph_node.find_child("TextHSplitContainer")
			text_h_split_container.free()
			var goto_rich_text_label : RichTextLabel = graph_node.find_child("GoToRichTextLabel")
			goto_rich_text_label.free()
			var option_zero_h_split_container : HSplitContainer = graph_node.find_child("Option0HSplitContainer")
			option_zero_h_split_container.free()
			var format_h_split_container : HSplitContainer = graph_node.find_child("FormatHSplitContainer")
			format_h_split_container.free()

			# Process the condition data
			var condition_rich_text_label : RichTextLabel = graph_node.find_child("ConditionRichTextLabel")
			condition_rich_text_label.set_text(dialogue_entry._get_condition_as_string())
			var condition_true_goto_rich_text_label : RichTextLabel = graph_node.find_child("ConditionTrueGoToRichTextLabel")
			var condition_false_goto_rich_text_label : RichTextLabel = graph_node.find_child("ConditionFalseGoToRichTextLabel")
			graph_node.set_slot_enabled_right(condition_true_goto_rich_text_label.get_index(), true)
			graph_node.set_slot_enabled_right(condition_false_goto_rich_text_label.get_index(), true)
		else:
			# Remove the nodes relevant to the condition
			var condition_h_split_container : HSplitContainer = graph_node.find_child("ConditionHSplitContainer")
			condition_h_split_container.free()
			var condition_true_goto_rich_text_label : RichTextLabel = graph_node.find_child("ConditionTrueGoToRichTextLabel")
			condition_true_goto_rich_text_label.free()
			var condition_false_goto_rich_text_label : RichTextLabel = graph_node.find_child("ConditionFalseGoToRichTextLabel")
			condition_false_goto_rich_text_label.free()

			# Process the Text, Format, GoTo and Options

			var text_rich_text_label : RichTextLabel = graph_node.find_child("TextRichTextLabel")
			text_rich_text_label.set_text(dialogue_entry.get_text())

			if dialogue_entry.has_format():
				var format_rich_format_label : RichTextLabel = graph_node.find_child("FormatRichTextLabel")
				var format_dictionary : Dictionary = dialogue_entry.get_format()
				format_rich_format_label.set_text(JSON.stringify(format_dictionary, "\t"))
			else:
				var format_h_split_container : HSplitContainer = graph_node.find_child("FormatHSplitContainer")
				format_h_split_container.free()

			var goto_rich_text_label : RichTextLabel = graph_node.find_child("GoToRichTextLabel")
			if not dialogue_entry.has_goto_id():
				goto_rich_text_label.free()
			elif dialogue_entry.has_goto_id():
				graph_node.set_slot_enabled_right(goto_rich_text_label.get_index(), true)

			if not dialogue_entry.is_options_empty():
				# Configure the first option -- there's at least one option
				var options_count : int = dialogue_entry.get_option_count()
				var option_0_h_split_container : HSplitContainer = graph_node.find_child("Option0HSplitContainer")
				var option_text : String = dialogue_entry.get_option_text(0)
				var option_rich_text_label : RichTextLabel = graph_node.find_child("Option%dRichTextLabel" % 0, true, false)
				option_rich_text_label.set_text(option_text)
				graph_node.set_slot_enabled_right(option_0_h_split_container.get_index(), true)

				# Duplicate the current option template in the GraphNode and configure it
				var last_split_container : HSplitContainer = option_0_h_split_container # track the last added sibling so that the positioning is as expected
				if options_count > 1:
					for option_id : int in range(1, options_count):
						# Duplicate and update accordingly
						var duplicated_container : HSplitContainer = option_0_h_split_container.duplicate()
						var option_id_as_string : String = String.num_uint64(option_id)
						duplicated_container.set_name("Option%sHSplitContainer" % option_id_as_string)

						var duplicated_option_delimeter : RichTextLabel = duplicated_container.find_child("Option0DelimeterRichTextLabel", true, false)
						duplicated_option_delimeter.set_name("Option%sDelimeterRichTextLabel" % option_id_as_string)
						duplicated_option_delimeter.set_text(duplicated_option_delimeter.get_text().replace("0", option_id_as_string))

						var duplicated_option_panel_container : PanelContainer = duplicated_container.find_child("Option0BackgroundPanelContainer", true, false)
						duplicated_option_panel_container.set_name("Option%sBackgroundPanelContainer" % option_id_as_string)

						var duplicated_option_rich_text_label : RichTextLabel = duplicated_container.find_child("Option0RichTextLabel", true, false)
						duplicated_option_rich_text_label.set_name("Option%sRichTextLabel" % option_id_as_string)
						var duplicated_option_text : String = dialogue_entry.get_option_text(option_id)
						duplicated_option_rich_text_label.set_text(duplicated_option_text)

						last_split_container.add_sibling(duplicated_container)
						last_split_container = duplicated_container
						graph_node.set_slot_enabled_right(duplicated_container.get_index(), true)
			else:
				var option_zero_h_split_container : HSplitContainer = graph_node.find_child("Option0HSplitContainer")
				option_zero_h_split_container.free()

		var metadata : Dictionary = dialogue_entry.get_metadata_data()
		if not metadata.is_empty():
			var metadata_rich_text_label : RichTextLabel = graph_node.find_child("MetadataRichTextLabel")
			metadata_rich_text_label.set_text(JSON.stringify(metadata, "\t"))
		else:
			var metadata_h_split_container : HSplitContainer = graph_node.find_child("MetadataHSplitContainer")
			metadata_h_split_container.free()

		graph_node.set_slot_enabled_left(0, true) # this slot is always open since any DialogueEntry can connect to any DialogueEntry
		dialogue_engine_viewer_graph_edit_.add_child(graph_node)

	# Process GraphNode connections
	var node_string_ids : Array = []
	for dialogue_entry_id : int in dialogue_engine.size():
		var dialogue_entry : DialogueEntry = dialogue_engine.get_entry_at(dialogue_entry_id)
		var dialogue_entry_id_as_string : String = dialogue_entry.get_id_as_text()
		node_string_ids.push_back(dialogue_entry_id_as_string)

		if dialogue_entry.has_goto_id():
			var goto_dialogue_entry : DialogueEntry = dialogue_entry.get_goto_entry()

			# Add connection
			var from_node : String = dialogue_entry_id_as_string
			var from_port_in_connection_index_form : int = 0
			var to_node : String = goto_dialogue_entry.get_id_as_text()
			var to_port : int = 0
			var _success : int = dialogue_engine_viewer_graph_edit_.connect_node(from_node, from_port_in_connection_index_form, to_node, to_port)
		elif dialogue_entry.has_condition():
			var goto_ids : Dictionary = dialogue_entry.get_condition_goto_ids()

			# Add true connection
			var true_goto_id : int = goto_ids[true]
			if dialogue_engine.has_entry_id(true_goto_id):
				var goto_dialogue_entry : DialogueEntry = dialogue_engine.get_entry_at(true_goto_id)
				var from_node : String = dialogue_entry_id_as_string
				var from_port_in_connection_index_form : int = 0
				var to_node : String = goto_dialogue_entry.get_id_as_text()
				var to_port : int = 0
				var _success : int = dialogue_engine_viewer_graph_edit_.connect_node(from_node, from_port_in_connection_index_form, to_node, to_port)

			# Add false connection
			var false_goto_id : int = goto_ids[false]
			if dialogue_engine.has_entry_id(false_goto_id):
				var goto_dialogue_entry : DialogueEntry = dialogue_engine.get_entry_at(false_goto_id)
				var from_node : String = dialogue_entry_id_as_string
				var from_port_in_connection_index_form : int = 1
				var to_node : String = goto_dialogue_entry.get_id_as_text()
				var to_port : int = 0
				var _success : int = dialogue_engine_viewer_graph_edit_.connect_node(from_node, from_port_in_connection_index_form, to_node, to_port)
		elif not dialogue_entry.has_options():
			# Find the next available goto entry that has the same branch ID -- i.e. find the default goto if any
			var current_branch_id : int = dialogue_entry.get_branch_id()
			var goto_dialogue_entry : DialogueEntry = null
			for goto_needle : int in range(dialogue_entry_id + 1, dialogue_engine.size()):
				var needle_dialogue_entry : DialogueEntry = dialogue_engine.get_entry_at(goto_needle)
				if current_branch_id == needle_dialogue_entry.get_branch_id():
					goto_dialogue_entry = needle_dialogue_entry
					break
			if is_instance_valid(goto_dialogue_entry):
				# Enable slot
				var dialogue_entry_graph_node : GraphNode = dialogue_engine_viewer_graph_edit_.get_node(NodePath(dialogue_entry_id_as_string))
				var from_port_in_connection_index_form : int = 0
				dialogue_entry_graph_node.set_slot_enabled_right(from_port_in_connection_index_form, true)

				# Add connection
				var from_node : String = dialogue_entry_id_as_string
				var to_node : String = goto_dialogue_entry.get_id_as_text()
				var to_port : int = 0
				var _success : int = dialogue_engine_viewer_graph_edit_.connect_node(from_node, from_port_in_connection_index_form, to_node, to_port)
		elif dialogue_entry.has_options():
			var outgoing_port_number : int = 0
			for option_id : int in dialogue_entry.get_option_count():
				var option_goto_id : int = dialogue_entry.get_option_goto_id(option_id)
				if dialogue_engine.has_entry_id(option_goto_id):
					# Add connection
					var goto_dialogue_entry : DialogueEntry = dialogue_entry.get_option_goto_entry(option_id)
					var from_node : String = dialogue_entry_id_as_string
					var from_port_in_connection_index_form : int = outgoing_port_number
					var to_node : String = goto_dialogue_entry.get_id_as_text()
					var to_port : int = 0
					var _success : int = dialogue_engine_viewer_graph_edit_.connect_node(from_node, from_port_in_connection_index_form, to_node, to_port)
					outgoing_port_number += 1


	# Disable the first slot of all the nodes that have no incoming connections to make the graph more readable (this is purely for aesthetics)
	var connections_list : Array = dialogue_engine_viewer_graph_edit_.get_connection_list()
	for target_node_name : String in node_string_ids:
		var found_incoming_connection_to_first_slot : bool = false
		for connection_entry : Dictionary in connections_list:
			var to_node : String = connection_entry["to_node"]
			if to_node != target_node_name:
				continue
			var to_port : int = connection_entry["to_port"]
			if to_port == 0:
				found_incoming_connection_to_first_slot = true
				break
		if not found_incoming_connection_to_first_slot:
			var graph_node : GraphNode = dialogue_engine_viewer_graph_edit_.get_node(NodePath(target_node_name))
			graph_node.set_slot_enabled_left(0, false)

	# Do not block input against the GraphEdit
	dialogue_engine_viewer_input_blocker_center_container_.hide()

	# Highlight the nodes
	__update_graph_node_highlights_if_needed(dialogue_engine)

	# Finally auto arrange the nodes
	dialogue_engine_viewer_graph_edit_.arrange_nodes()


func __cleanup_graph_edit() -> void:
	dialogue_engine_viewer_graph_edit_.clear_connections()
	for child_node : Node in dialogue_engine_viewer_graph_edit_.get_children():
		if child_node is GraphNode:
			child_node.free()
# ===== VISUALIZATION FUNCTIONS END ====
