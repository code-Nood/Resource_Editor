class_name BoolButton

extends Protocol

@onready var label:Label = %Label
@onready var check:CheckButton = %CheckButton

func setup(prop_name: String, _hint: String, initial_value: Variant) -> void:
	label.text = prop_name.capitalize()
	check.button_pressed = initial_value
	check.toggled.connect(func(v: bool): value_changed.emit(v))
