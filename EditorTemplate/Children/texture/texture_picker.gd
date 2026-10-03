class_name TexturePicker

extends Protocol

@onready var label: Label = %Label
@onready var texture_button: Button = %TextureButton
@onready var texture: TextureRect = %Texture

var current_texture: Texture2D = null
var file_dialog: FileDialog = null
## 上次选择所在目录（打开对话框时自动定位到这里）
var _last_dir: String = TemplateRegistry.workspace_root + "/data/"

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
	# 记住并回到上次选择的目录（内嵌对话框生效；原生对话框多半会忽略、由系统自身记忆）
	if file_dialog != null and _last_dir != "" and DirAccess.dir_exists_absolute(_last_dir):
		file_dialog.current_dir = _last_dir
	# 原生对话框：由操作系统决定尺寸与样式，不受本项目 4 倍 stretch 影响
	file_dialog.popup_centered()

# ---- 创建选图对话框 ----
func _create_file_dialog() -> void:
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.use_native_dialog = true
	file_dialog.current_dir = _last_dir
	file_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp, *.svg, *.bmp, *.tres, *.res, *.atlastex", "贴图文件 (Texture2D)")
	file_dialog.file_selected.connect(_on_file_selected)
	file_dialog.canceled.connect(file_dialog.queue_free)
	add_child(file_dialog)

# ---- 从路径加载贴图（兼容工作区外绝对路径）----
func _load_texture(path: String) -> Texture2D:
	var base := ResourceLoader.load(path)
	if base is Texture2D:
		return base as Texture2D
	# 兜底：图片文件走 Image 读入
	var ext := path.get_extension().to_lower()
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	match ext:
		"jpg", "jpeg":
			err = img.load_jpg_from_buffer(FileAccess.get_file_as_bytes(path))
		"webp":
			err = img.load_webp_from_buffer(FileAccess.get_file_as_bytes(path))
		"bmp":
			err = img.load_bmp_from_buffer(FileAccess.get_file_as_bytes(path))
		_:
			err = img.load(path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)

# ---- 选中文件 -> 加载并回传（真包含：内嵌像素）----
func _on_file_selected(path: String) -> void:
	var dir := path.get_base_dir()
	if dir != "":
		_last_dir = dir
	# 支持工作区外的绝对路径：优先 ResourceLoader（.tres/.res 与绝对路径均可用）
	var tex := _load_texture(path)
	if tex == null:
		push_error("无法加载贴图：" + path)
		return
	# 真包含：提取像素并内嵌成 ImageTexture，避免依赖外部文件路径
	var img := tex.get_image()
	if img != null:
		tex = ImageTexture.create_from_image(img.duplicate())
	set_value(tex)
	value_changed.emit(tex)
