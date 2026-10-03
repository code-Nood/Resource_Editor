class_name MultilineTextEditor

extends Protocol

## 多行文本编辑器：用于 description 等长文本字段。
## 与 line_edit 结构保持一致（Protocol → HBoxContainer → Label + 编辑控件），
## 但编辑控件为 TextEdit（多行、可换行、框体更高）。

@onready var label: Label = %Label
@onready var text_edit: TextEdit = %TextEdit

func _ready() -> void:
	# 横向填满整行；高度保证足够（用代码设置，避免被场景重新序列化时丢失）
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.custom_minimum_size.y = 80

func setup(prop_name: String, _hint: String, initial_value: Variant) -> void:
	label.text = prop_name.capitalize()
	text_edit.text = initial_value if initial_value != null else ""
	# 只在首次连接，避免重复打开时叠加信号
	if not text_edit.text_changed.is_connected(_on_text_changed):
		text_edit.text_changed.connect(_on_text_changed)

func _on_text_changed() -> void:
	value_changed.emit(text_edit.text)

