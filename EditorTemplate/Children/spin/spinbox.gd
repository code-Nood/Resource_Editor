class_name IntSpinBoxEditor

extends Protocol

@onready var label:Label = %Label
@onready var spinbox:SpinBox = %SpinBox

func setup(prop_name: String, _hint: String, initial_value: Variant) -> void:
	label.text = prop_name.capitalize()
	spinbox.value = initial_value
	spinbox.value_changed.connect(func(v: float): value_changed.emit(int(v)))
