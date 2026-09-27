class_name TexturePicker

extends Protocol

@onready var label: Label = %Label
@onready var texture_button: Button = %TextureButton
@onready var texture: TextureRect = %Texture

var current_texture: Texture2D = null
var file_dialog: FileDialog = null

func setup(property_name: String, _hint_string: String, initial_value: Variant) -> void:
	# 字段名显示在左侧标签
	label.text = property_name.capitalize()
	# 连接插槽按钮
	if not texture_button.pressed.is_connected(_on_button_pressed):
		texture_button.pressed.connect(_on_button_pressed)
	# 初始化选图对话框（创建一次即可）
	if file_dialog == null:
		_create_file_dialog()
	# 设置初始贴图
	set_value(initial_value)

# ---- 设置当前贴图 ----
func set_value(tex: Texture2D) -> void:
	current_texture = tex
	texture.texture = tex

# ---- 点插槽 -> 弹选图框 ----
func _on_button_pressed() -> void:
	file_dialog.popup_centered_ratio(0.7)

# ---- 创建选图对话框 ----
func _create_file_dialog() -> void:
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.current_dir = TemplateRegistry.workspace_root + "/data/"
	file_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp, *.svg, *.bmp", "贴图文件 (Texture2D)")
	file_dialog.file_selected.connect(_on_file_selected)
	file_dialog.canceled.connect(file_dialog.queue_free)
	add_child(file_dialog)

# ---- 选中文件 -> 加载并回传（真包含：内嵌像素）----
func _on_file_selected(path: String) -> void:
	var tex := load(path) as Texture2D
	if tex == null:
		push_error("无法加载贴图：" + path)
		return
	# 真包含：提取像素并内嵌成 ImageTexture，避免依赖外部文件路径
	var img := tex.get_image()
	if img != null:
		tex = ImageTexture.create_from_image(img.duplicate())
	set_value(tex)
	value_changed.emit(tex)
