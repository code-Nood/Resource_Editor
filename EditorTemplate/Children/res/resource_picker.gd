class_name ResourcePicker

extends Protocol

## 属性字段名（显示在左侧标签）
var property_name: String = ""

## 当前holder里持有的（已内嵌的）贴图
var current_texture: Texture2D = null

var _file_dialog: FileDialog = null

@onready var _label: Label = %Label
@onready var _texture: TextureRect = %Texture
@onready var _button: Button = %Button


func setup(p_name: String, _hint_string: String, initial_value: Variant) -> void:
	property_name = p_name
	_label.text = p_name

	# 按钮 -> 弹资源选择
	if not _button.pressed.is_connected(_on_button_pressed):
		_button.pressed.connect(_on_button_pressed)

	# 资源选择对话框（创建一次即可）
	if _file_dialog == null:
		_create_file_dialog()

	# 初始化值（可能是外部引用，展示即可，不改写）
	set_value(initial_value)


## 设置当前贴图（同时刷新缩略图与按钮文本）
func set_value(tex: Texture2D) -> void:
	current_texture = tex
	_texture.texture = tex
	if tex == null:
		_button.text = "选择资源..."
	elif tex.resource_path != "":
		_button.text = tex.resource_path.get_file()
	else:
		_button.text = "(已内嵌贴图)"


func _on_button_pressed() -> void:
	_file_dialog.popup_centered_ratio(0.7)


func _create_file_dialog() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.current_dir = "res://"
	_file_dialog.add_filter("*.tres, *.res, *.png, *.jpg, *.jpeg, *.webp, *.bmp", "贴图资源")
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)


## 选中一个资源 -> 提取像素 -> 内嵌成 ImageTexture -> 回传
func _on_file_selected(path: String) -> void:
	var picked := load(path) as Texture2D
	if picked == null:
		push_error("所选资源不是贴图：" + path)
		return
	# 真包含：提取像素并内嵌（AtlasTexture.get_image() 会返回裁剪后的那块）
	var img := picked.get_image()
	if img == null:
		push_error("无法从资源提取像素：" + path)
		return
	var embedded := ImageTexture.create_from_image(img.duplicate())
	set_value(embedded)
	value_changed.emit(embedded)
