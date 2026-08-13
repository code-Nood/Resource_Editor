class_name Option

extends Protocol

@onready var label:Label = %Label
@onready var option_button:OptionButton = %OptionButton

func setup(prop_name: String, hint_str: String, initial_value: Variant) -> void:
	label.text = prop_name.capitalize()
	option_button.clear()
	var options = hint_str.split(",")
	for opt in options:
		option_button.add_item(opt.strip_edges())
	option_button.selected = initial_value
	# 下拉弹出菜单字体（用户端主题覆盖不到，这里直接设置）
	option_button.get_popup().add_theme_font_size_override("font_size", 30)
	option_button.item_selected.connect(func(idx: int): value_changed.emit(idx))

