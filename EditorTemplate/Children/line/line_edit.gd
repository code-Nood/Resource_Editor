class_name LineEditEditor

extends Protocol

@onready var label:Label = %Label
@onready var line_edit:LineEdit = %LineEdit

func _ready() -> void:
	# 让输入框横向填满整行（用代码设置，避免被场景重新序列化时丢失）
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func setup(prop_name: String, _hint: String, initial_value: Variant) -> void:
	label.text = prop_name.capitalize()
	line_edit.text = initial_value
	line_edit.text_changed.connect(func(t: String): value_changed.emit(t))

