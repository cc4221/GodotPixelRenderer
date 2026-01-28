@tool
extends ConfirmationDialog

signal generate_requested(scene_path: String)
signal generate_global_requested(scene_path: String)

var _line_edit: LineEdit
var _file_dialog: EditorFileDialog

func _init():
	title = "Create Dither3D Scene Copy"
	min_size = Vector2(500, 100)
	
	var vbox = VBoxContainer.new()
	# vbox.set_anchors_preset(Control.PRESET_FULL_RECT) # Not needed in Dialog usually, it manages child layout
	add_child(vbox)
	
	var label = Label.new()
	label.text = "Select a scene to process (a new copy will be created, original is safe):"
	vbox.add_child(label)
	
	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)
	
	_line_edit = LineEdit.new()
	_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_line_edit)
	
	var browse_button = Button.new()
	browse_button.text = "Browse..."
	browse_button.pressed.connect(_on_browse_pressed)
	hbox.add_child(browse_button)
	
	_file_dialog = EditorFileDialog.new()
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_file_dialog.filters = ["*.tscn ; Scene Files"]
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)
	
	confirmed.connect(_on_confirmed)
	custom_action.connect(_on_custom_action)
	
	# Wait for ready to set button text safely or do it here if possible
	# get_ok_button() might not be available in _init depending on Godot version/lifecycle
	# But usually it is for ConfirmationDialog.
	
func _ready():
	get_ok_button().text = "Generate (Local)"
	add_button("Generate (Global)", true, "global")

func _on_browse_pressed():
	_file_dialog.popup_centered_ratio(0.6)

func _on_file_selected(path: String):
	_line_edit.text = path

func _on_confirmed():
	generate_requested.emit(_line_edit.text)

func _on_custom_action(action: String):
	if action == "global":
		generate_global_requested.emit(_line_edit.text)
		hide()
