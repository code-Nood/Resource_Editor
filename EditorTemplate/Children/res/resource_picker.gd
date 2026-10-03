class_name ResourcePicker

extends Protocol

## 属性字段名（显示在左侧标签）
var property_name: String = ""

## 当前holder里持有的（已内嵌的）贴图
var current_texture: Texture2D = null

var _file_dialog: FileDialog = null
## 上次选择所在目录（打开对话框时自动定位到这里）
var _last_dir: String = TemplateRegistry.workspace_root + "/data/"

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
	if _file_dialog != null and _last_dir != "" and DirAccess.dir_exists_absolute(_last_dir):
		_file_dialog.current_dir = _last_dir
	# 原生对话框：由操作系统决定尺寸与样式，不受本项目 4 倍 stretch 影响
	_file_dialog.popup_centered()


func _create_file_dialog() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	_file_dialog.current_dir = _last_dir
	_file_dialog.add_filter("*.tres, *.res, *.atlastex, *.png, *.jpg, *.jpeg, *.webp, *.bmp", "贴图资源")
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)


## 选中一个资源 -> 内嵌并回传。
## - 选中 AtlasTexture（如 Asset/Arts/*.atlastex）：走"自包含打包"——
##   把它的底图（atlas）整图像素内嵌成 full_texture，再新建一个指向该内嵌底图、
##   region 照抄的 atlas_texture。两者共用同一张内嵌图，闭环自包含，打包不断链。
## - 选中普通 Texture2D：提取像素内嵌成 ImageTexture（原逻辑）。
func _on_file_selected(path: String) -> void:
	var dir := path.get_base_dir()
	if dir != "":
		_last_dir = dir
	# 用 ResourceLoader 以支持工作区外的绝对路径 .tres/.res（load() 只认 res:// / user://）
	var picked := ResourceLoader.load(path) as Texture2D
	if picked == null:
		push_error("所选资源不是贴图：" + path)
		return

	# 分支一：真 AtlasTexture —— 内嵌底图整图，重建指向内嵌底图的 atlas
	if picked is AtlasTexture:
		var src_atlas := picked as AtlasTexture
		var base_tex := src_atlas.atlas
		if base_tex == null:
			push_error("AtlasTexture 未引用底图，无法内嵌：" + path)
			return
		var base_img := base_tex.get_image()
		if base_img == null:
			push_error("无法从底图提取像素：" + path)
			return
		# 内嵌整图（自包含）：full 与 atlas 共用这一张内嵌纹理
		var embedded_full := ImageTexture.create_from_image(base_img.duplicate())
		var embedded_atlas := AtlasTexture.new()
		embedded_atlas.atlas = embedded_full
		embedded_atlas.region = src_atlas.region
		embedded_atlas.margin = src_atlas.margin
		set_value(embedded_atlas)
		# 一次性回传关联的一对贴图：full 为底图，atlas 为引用底图的裁剪
		value_changed.emit(embedded_atlas)
		texture_pair_changed.emit(embedded_full, embedded_atlas)
		print("已内嵌 AtlasTexture：", path, "  region=", src_atlas.region)
		return

	# 分支二：普通 Texture2D —— 提取像素内嵌
	var img := picked.get_image()
	if img == null:
		push_error("无法从资源提取像素：" + path)
		return
	var embedded := ImageTexture.create_from_image(img.duplicate())
	set_value(embedded)
	value_changed.emit(embedded)
