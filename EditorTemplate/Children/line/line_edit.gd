class_name LineEditEditor

extends Protocol

@onready var label:Label = %Label
@onready var line_edit:LineEdit = %LineEdit

func setup(prop_name: String, _hint: String, initial_value: Variant) -> void:
	label.text = prop_name.capitalize()
	line_edit.text = initial_value
	line_edit.text_changed.connect(func(t: String): value_changed.emit(t))
