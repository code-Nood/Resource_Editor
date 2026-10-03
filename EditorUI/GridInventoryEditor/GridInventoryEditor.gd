extends Control

class_name GridInventoryEditor

## 请求返回主面板（由 MainPanel 连接）
signal back_requested

## 当前正在编辑的纪念品资源实例
var editing_res: Resource = null

@onready var _grid: GridEditor = get_node_or_null("GridEditor")
@onready var _preview: RotPreview = get_node_or_null("RotPreview")
@onready var _rot_option: OptionButton = get_node_or_null("Background/HBoxContainer/RotOption")
@onready var _used_label: Label = get_node_or_null("Background/VBoxContainer/UsedCells")
@onready var _mode_label: Label = get_node_or_null("%ModeLabel")

## 参考图节点（atlas 拖动参考），动态生成，位置不持久化
var _reference: Reference = null
## 拖放模式：true=可拖动参考图；false=编辑模式（参考图穿透鼠标）
var _drag_mode: bool = true
## 参考图初始中心位置（逻辑画布坐标，固定值，不持久化）
const REFERENCE_CENTER := Vector2(400, 135)

## 当前预览档位（0=DEG_0，1=90，2=180，3=270）
var _rotation_index: int = 0
## 单格像素尺寸（与 EditorPanel.custom_minimum_size 一致）
const CELL_PX: int = 32

func _ready() -> void:
	# 初始隐藏，由主面板“切换”按钮唤出
	visible = false

	# 返回按钮
	var back_btn := get_node_or_null("Background/Back") as Button
	if back_btn != null:
		back_btn.pressed.connect(_on_back_pressed)

	# 清空选择按钮
	var clear_btn := get_node_or_null("Background/HBoxContainer/Clear") as Button
	if clear_btn != null:
		clear_btn.pressed.connect(_on_clear_pressed)

	# 保存资源按钮
	var save_btn := get_node_or_null("Background/HBoxContainer/Save") as Button
	if save_btn != null:
		save_btn.pressed.connect(_on_save_pressed)

	# 切换拖放/编辑模式按钮
	var mode_btn := get_node_or_null("Background/HBoxContainer/Button") as Button
	if mode_btn != null:
		mode_btn.pressed.connect(_on_toggle_mode_pressed)

	# 旋转档位下拉：切换即刷新只读预览
	if _rot_option != null:
		_rot_option.selected = _rotation_index
		_rot_option.item_selected.connect(_on_rot_selected)

	# 选择变化 -> 刷新预览 + 占格数
	if _grid != null:
		_grid.selection_changed.connect(_refresh_preview)
		_grid.selection_changed.connect(_refresh_used_cells)

	# 初始模式标签
	_refresh_mode_label()

	# 让预览层矩形与网格矩形对齐（用代码兜底，避免场景里的位置被 --import 回滚）
	_align_preview_to_grid()

## 把只读预览层的矩形对齐到 GridEditor 的矩形，使其"名副其实"。
## 蓝框实际绘制位置由传入的真实格原点决定（见 _refresh_preview），此对齐只是让预览层
## 覆盖网格区域；Control 默认不裁剪，即便不完全重合也不会画错。
func _align_preview_to_grid() -> void:
	if _preview == null or _grid == null:
		return
	_preview.position = _grid.position
	_preview.size = _grid.size

## 由主面板调用：打开格子编辑器，并绑定正在编辑的资源
func open_for(res: Resource) -> void:
	editing_res = res
	_refresh_resource_name()

	# 复位档位与预览
	_rotation_index = 0
	if _rot_option != null:
		_rot_option.selected = 0
	if _preview != null:
		_preview.clear_cells()

	# 复位选择状态，避免上次编辑残留
	if _grid != null:
		_grid.clear_all()

	# 回填已保存的形状（若有），方便再次编辑
	_load_existing_shape()

	# 参考图：每次打开都在固定中心重生，并显示资源自带的贴图（位置不持久化）
	_spawn_reference()
	_refresh_reference_texture()

	_refresh_used_cells()

	visible = true

## 关闭格子编辑器（不负责切回，仅隐藏；由主面板统一控制 visible）
func close() -> void:
	visible = false
	editing_res = null
	if _preview != null:
		_preview.clear_cells()
	# 参考图随资源关闭一并销毁（位置不持久化，下次打开重生）
	if _reference != null:
		_reference.queue_free()
		_reference = null
	_refresh_used_cells()

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

#region 参考图（atlas 拖动参考）
## 生成参考图节点：中心固定在 REFERENCE_CENTER，位置不持久化。
## 若已存在则复位到初始中心（不重复创建）。
func _spawn_reference() -> void:
	if _grid == null:
		return
	if _reference == null:
		_reference = Reference.new()
		_reference.name = "Reference"
		add_child(_reference)
		_reference.configure(_grid, CELL_PX)
	# 复位到初始中心（左上角 = 中心 - 半尺寸；size 由 set_texture 决定）
	_apply_reference_center()
	# 应用当前模式（拖放/编辑）到新节点的鼠标过滤
	_reference.set_drag_enabled(_drag_mode)

## 依据当前贴图尺寸，把参考图中心对齐到 REFERENCE_CENTER
func _apply_reference_center() -> void:
	if _reference == null:
		return
	var half := _reference.size * 0.5
	_reference.global_position = REFERENCE_CENTER - half

## 把资源自带的贴图喂给参考图（优先 atlas_texture，回退 full_texture）。
## 尺寸随之更新，中心保持。贴图由主面板属性编辑器预先配置，本编辑器只读。
func _refresh_reference_texture() -> void:
	if _reference == null:
		return
	_reference.set_texture(_resolve_reference_texture())
	_apply_reference_center()

## 取参考图用的贴图：优先 atlas_texture（游戏端展示用），回退 full_texture
func _resolve_reference_texture() -> Texture2D:
	if editing_res == null:
		return null
	var atlas = editing_res.get("atlas_texture")
	if atlas is Texture2D:
		return atlas
	var full = editing_res.get("full_texture")
	if full is Texture2D:
		return full
	return null

## 切换拖放/编辑模式
func _on_toggle_mode_pressed() -> void:
	_drag_mode = not _drag_mode
	if _reference != null:
		_reference.set_drag_enabled(_drag_mode)
	_refresh_mode_label()

## 刷新模式标签文本（复用场景里既有的 ModeLabel）
func _refresh_mode_label() -> void:
	if _mode_label == null:
		return
	_mode_label.text = "当前模式：" + ("拖放" if _drag_mode else "编辑")
#endregion

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

#region 旋转预览（只读叠加）
## 档位下拉回调
func _on_rot_selected(index: int) -> void:
	_rotation_index = index
	_refresh_preview()

## 依据当前选择 + 当前档位，刷新只读预览层（不改 _selection）
func _refresh_preview() -> void:
	if _preview == null or _grid == null:
		return
	var cells := _grid.get_preview_cells_for_rot(_rotation_index)
	# 传入真实格原点（转成 RotPreview 局部坐标），让预览层不再自算格子位置
	_preview.set_cells(cells, CELL_PX, _grid.cell_origin() - _preview.global_position)
#endregion

#region 已占格数显示
## 面板常驻刷新"已占格数"（= 形状占格总数，含起始格）
func _refresh_used_cells() -> void:
	if _used_label == null:
		return
	var count := 0
	if _grid != null:
		count = _grid.get_used_cell_count()
	_used_label.text = "已占格数：%d" % count
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

	# R6 校验：shape_offsets 绝不含 (0,0)（导出逻辑已剔除，这里显式断言兜底）
	for off in offsets:
		if off == Vector2i.ZERO:
			push_warning("形状非法：shape_offsets 不应包含起始格 (0,0)")
			return

	# 1) 写入 shape_offsets（仅除起始格 (0,0) 以外的相对坐标）
	if editing_res.get("shape_offsets") != null:
		editing_res.shape_offsets = offsets

	# 2) 视觉锚点 = 起始格 (0,0)，与设计契约一致
	if editing_res.get("visual_anchor") != null:
		editing_res.visual_anchor = Vector2i.ZERO

	# 注意：atlas_texture 由主面板属性编辑器负责配置，GIE 只读（见 _resolve_reference_texture）。
	# 这里绝不再重建/覆盖 atlas_texture，否则会把主面板设好的子区域冲成全图。

	# 4) 落盘前 id 唯一性兜底校验（复用主面板通用工具）
	var conflict := _assert_id_unique_for_save()
	if conflict != "":
		push_warning("保存被拒绝：%s" % conflict)
		return

	# 5) 落盘（复用主面板的目录/命名规则）
	_save_to_disk()

	print("格子形状已保存：占格 %d 格" % (offsets.size() + 1))
#endregion

## 落盘前 id 唯一性校验：复用主面板的通用工具；无主面板时退回本地扫描。
func _assert_id_unique_for_save() -> String:
	if editing_res == null:
		return ""
	var main := _find_main_panel()
	if main != null:
		var type_name: String = main.template_selector.get_item_text(main.template_selector.selected)
		return main.assert_id_unique(editing_res, type_name)
	return ""

#region 底层工具
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

func _on_back_pressed() -> void:
	back_requested.emit()
#endregion
