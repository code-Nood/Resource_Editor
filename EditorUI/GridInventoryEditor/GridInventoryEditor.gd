extends Control

class_name GridInventoryEditor

## 请求返回主面板（由 MainPanel 连接）
signal back_requested

## 当前正在编辑的纪念品资源实例
var editing_res: Resource = null

## 本次在编辑器里挑选的贴图（已内嵌成 ImageTexture）
var _picked_texture: Texture2D = null

## 打开贴图时记住的默认目录（复用上次位置）
var _last_texture_dir: String = "res://"

@onready var _grid: GridEditor = get_node_or_null("GridEditor")
@onready var _popup: FileDialog = get_node_or_null("FileDialog")


func _ready() -> void:
	# 初始隐藏，由主面板“切换”按钮唤出
	visible = false

	# 返回按钮
	var back_btn := get_node_or_null("Background/Back") as Button
	if back_btn != null:
		back_btn.pressed.connect(_on_back_pressed)

	# 打开贴图按钮
	var file_open_btn := get_node_or_null("Background/HBoxContainer/file_open") as Button
	if file_open_btn != null:
		file_open_btn.pressed.connect(_on_file_open_pressed)

	# 清空选择按钮
	var clear_btn := get_node_or_null("Background/HBoxContainer/Clear") as Button
	if clear_btn != null:
		clear_btn.pressed.connect(_on_clear_pressed)

	# 保存资源按钮
	var save_btn := get_node_or_null("Background/HBoxContainer/Save") as Button
	if save_btn != null:
		save_btn.pressed.connect(_on_save_pressed)

	# 贴图选择对话框
	_ensure_file_dialog()


## 由主面板调用：打开格子编辑器，并绑定正在编辑的资源
func open_for(res: Resource) -> void:
	editing_res = res
	_refresh_resource_name()

	# 复位选择状态，避免上次编辑残留
	if _grid != null:
		_grid.clear_all()

	# 回填已保存的形状（若有），方便再次编辑
	_load_existing_shape()

	# 记住资源里已内嵌的贴图（本次未重选则原样保留）
	_picked_texture = null
	if res != null and res.get("full_texture") != null:
		var existing_tex = res.get("full_texture")
		if existing_tex is Texture2D:
			_picked_texture = existing_tex

	visible = true


## 关闭格子编辑器（不负责切回，仅隐藏；由主面板统一控制 visible）
func close() -> void:
	visible = false
	editing_res = null


## 更新“现在正在编辑”下的资源名标签
func _refresh_resource_name() -> void:
	var name_label: Label = get_node_or_null("Background/VBoxContainer/ResourceName") as Label
	if name_label == null:
		return
	if editing_res == null:
		name_label.text = ""
		return
	var shown := ""
	if editing_res.get("data_name") != null and str(editing_res.data_name).strip_edges() != "":
		shown = str(editing_res.data_name)
	elif editing_res.get("name") != null:
		shown = str(editing_res.name)
	name_label.text = shown

#region 已保存形状回填
## 打开资源时，把已存的 shape_offsets 还原到网格上（便于二次编辑）
func _load_existing_shape() -> void:
	if editing_res == null or _grid == null:
		return
	if editing_res.get("shape_offsets") == null:
		return
	var offsets: Array = editing_res.shape_offsets
	if offsets.is_empty():
		return

	# 已存形状的包围盒（起始格 (0,0) 是隐式的，需一并纳入）
	var min_c := Vector2i.ZERO
	var max_c := Vector2i.ZERO
	for off in offsets:
		min_c.x = min(min_c.x, off.x)
		min_c.y = min(min_c.y, off.y)
		max_c.x = max(max_c.x, off.x)
		max_c.y = max(max_c.y, off.y)

	# 把整块形状尽量放到网格中央，反推出起始格的网格绝对坐标
	var span := max_c - min_c
	var want_origin := Vector2i(
		int((_grid.columns_count - 1 - span.x) / 2.0),
		int((_grid.rows_count - 1 - span.y) / 2.0)
	)
	want_origin.x = clampi(want_origin.x, -min_c.x, _grid.columns_count - 1 - max_c.x)
	want_origin.y = clampi(want_origin.y, -min_c.y, _grid.rows_count - 1 - max_c.y)

	# 起始格绝对坐标 = want_origin；其余格 = want_origin + offset
	_grid.apply_shape(want_origin, offsets)
#endregion


#region 打开贴图
## 拉起文件对话框挑选贴图
func _on_file_open_pressed() -> void:
	if editing_res == null:
		push_warning("未绑定资源，无法打开贴图")
		return
	if _popup == null:
		_ensure_file_dialog()
	if _popup == null:
		return
	_popup.current_dir = _last_texture_dir
	_popup.popup_centered_ratio(0.8)


## 文件对话框选中贴图后
func _on_file_dialog_file_selected(path: String) -> void:
	if editing_res == null:
		return
	_last_texture_dir = path.get_base_dir()

	# 用 Image 读入像素，保证内嵌后自包含（不依赖外部 PNG 路径）
	var image := _load_image_from_path(path)
	if image == null:
		push_warning("无法读取贴图：" + path)
		return
	# 立即内嵌成 ImageTexture
	_picked_texture = ImageTexture.create_from_image(image)
	print("已载入贴图：", path, "  尺寸：", image.get_size())
#endregion


#region 清空选择
func _on_clear_pressed() -> void:
	if _grid != null:
		_grid.clear_all()
#endregion

#region 保存资源
func _on_save_pressed() -> void:
	if editing_res == null:
		push_warning("未绑定资源，无法保存")
		return
	if _grid == null:
		return

	# 至少要有原点格（起始格）
	if _grid.get_used_cell_count() == 0:
		push_warning("尚未选中任何格子，无法保存形状")
		return

	var offsets := _grid.get_shape_offsets()

	# 1) 写入 shape_offsets（仅除起始格 (0,0) 以外的相对坐标）
	if editing_res.get("shape_offsets") != null:
		editing_res.shape_offsets = offsets

	# 2) 写入包围盒 size（含起始格在内整体占用的宽高）
	var bbox := _compute_bounding_size(offsets)
	if editing_res.get("size") != null:
		editing_res.size = bbox

	# 3) 视觉锚点 = 起始格 (0,0)，与设计契约一致
	if editing_res.get("visual_anchor") != null:
		editing_res.visual_anchor = Vector2i.ZERO

	# 4) 内嵌底图像素（方案 a：自包含，打包/换目录不断链）
	if editing_res.get("full_texture") != null and _picked_texture != null:
		editing_res.full_texture = _embed_texture(_picked_texture)

	# 5) 落盘（复用主面板的目录/命名规则）
	_save_to_disk()

	print("格子形状已保存：size=%s，占格 %d 格" % [str(bbox), offsets.size() + 1])


## 计算包围盒尺寸（含起始格 (0,0) 与所有 offsets）
func _compute_bounding_size(offsets: Array) -> Vector2i:
	var min_c := Vector2i.ZERO
	var max_c := Vector2i.ZERO
	for off in offsets:
		min_c.x = min(min_c.x, off.x)
		min_c.y = min(min_c.y, off.y)
		max_c.x = max(max_c.x, off.x)
		max_c.y = max(max_c.y, off.y)
	return max_c - min_c + Vector2i.ONE
#endregion


#region 底层工具
## 把任意贴图转成内嵌的 ImageTexture（像素级自包含）
func _embed_texture(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return tex
	# 复制一份，避免与外部资源共享像素引用
	return ImageTexture.create_from_image(img.duplicate())


## 从磁盘路径读取 Image（支持 png/jpg/webp/bmp 等）
func _load_image_from_path(path: String) -> Image:
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
		# 兜底：按资源路径直接 load（适用于已导入的纹理）
		var loaded := load(path)
		if loaded is Texture2D:
			return (loaded as Texture2D).get_image()
		return null
	return img


## 按主面板同一套目录/命名规则保存资源
func _save_to_disk() -> void:
	var main := _find_main_panel()
	var folder: String
	if main != null:
		var type_name: String = main.template_selector.get_item_text(main.template_selector.selected)
		folder = main._data_folder(type_name)
	else:
		folder = TemplateRegistry.workspace_root + "/data/souvenir/"
	DirAccess.make_dir_recursive_absolute(folder)

	var file_name: String = ""
	if editing_res.get("data_name") != null and str(editing_res.data_name).strip_edges() != "":
		file_name = str(editing_res.data_name).strip_edges()
		file_name = file_name.replace("/", "_").replace("\\", "_").replace(":", "_")
	if file_name == "":
		file_name = "untitled_" + str(editing_res.id)

	var path := folder + file_name + ".tres"
	var err := ResourceSaver.save(editing_res, path)
	if err != OK:
		push_error("保存失败：%s（错误码 %d）" % [path, err])
	else:
		print("保存成功：", path)


## 向上查找主面板（用于复用其目录规则）
func _find_main_panel() -> MainPanel:
	var node: Node = self
	while node != null:
		if node is MainPanel:
			return node
		node = node.get_parent()
	return null


## 确保存在文件对话框（场景里没有则动态创建）
func _ensure_file_dialog() -> void:
	_popup = get_node_or_null("FileDialog") as FileDialog
	if _popup != null:
		if not _popup.file_selected.is_connected(_on_file_dialog_file_selected):
			_popup.file_selected.connect(_on_file_dialog_file_selected)
		return
	# 场景未配置时动态创建一个（兼容旧场景）
	_popup = FileDialog.new()
	_popup.name = "FileDialog"
	_popup.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_popup.access = FileDialog.ACCESS_RESOURCES
	_popup.add_filter("*.png, *.jpg, *.jpeg, *.webp, *.bmp", "图片")
	_popup.current_dir = "res://"
	add_child(_popup)
	_popup.file_selected.connect(_on_file_dialog_file_selected)


func _on_back_pressed() -> void:
	back_requested.emit()
#endregion
