class_name MainPanel

extends Control

@onready var template_selector:OptionButton = %OptionButton
@onready var resource_list:VBoxContainer = %ItemList
@onready var detail_container:VBoxContainer = %Detail
@export var grid_inventory_editor:GridInventoryEditor

## 请求打开格子编辑器：把“正在编辑的资源”传出去
signal grid_edit_requested(res: Resource)

# 预加载列表项场景
var _list_item_scene: PackedScene = preload("res://EditorUI/MainPanel/resource_list_button.tscn")

var current_script: Script = null
var current_properties: Array = []   # 属性元数据数组
var current_resources: Array = []    # 当前类型的资源实例数组

# 防抖自动保存：编辑字段后延迟保存，防抖期内再次编辑则重置计时
var _save_timer: Timer
var _pending_save: Resource = null
# 当前正在编辑/选中的资源（用于清除等基于“选中项”的操作）
var _current_editing_res: Resource = null

#region 初始化与引用
func _ready():
	# 先初始化防抖自动保存 Timer（要在可能触发保存的调用之前创建）
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 1.5
	_save_timer.timeout.connect(_on_save_timer_timeout)
	add_child(_save_timer)

	# 填充模板下拉框
	for tname in TemplateRegistry.templates.keys():
		template_selector.add_item(tname)
	template_selector.item_selected.connect(_on_template_selected)

	# 模板下拉弹出菜单字体放大到 30 像素（用户端主题无法覆盖，这里直接设置）
	template_selector.get_popup().add_theme_font_size_override("font_size", 30)

	# 默认选中第一个模板（如果有）
	if template_selector.item_count > 0:
		template_selector.select(0)
		_on_template_selected(0)
	print("已注册模板：", TemplateRegistry.templates.keys())

	# 连接“切换”按钮：打开格子编辑器
	if has_node("Background/HBoxContainer/Grid"):
		($Background/HBoxContainer/Grid as Button).pressed.connect(_on_grid_edit_pressed)

	# 连接格子编辑器：信号 -> 打开；返回信号 -> 关闭
	if grid_inventory_editor != null:
		grid_edit_requested.connect(grid_inventory_editor.open_for)
		grid_inventory_editor.back_requested.connect(_close_grid_editor)

	# “非纪念品资源”警告：初始隐藏，Timer 到点后自动隐藏
	if has_node("Warning"):
		($Warning as Label).visible = false
	if has_node("Warning/Timer"):
		($Warning/Timer as Timer).one_shot = true
		($Warning/Timer as Timer).timeout.connect(_on_warning_timeout)
#endregion

#region 格子编辑器切换
## 点击“切换”：把当前编辑的资源交给格子编辑器打开
func _on_grid_edit_pressed() -> void:
	if _current_editing_res == null:
		push_warning("没有正在编辑的资源，无法打开格子编辑器")
		return
	# 仅允许纪念品资源跳转到格子编辑器
	if not _is_souvenir_script():
		_show_warning()
		return
	# 先落盘，确保资源已持久化、有可靠实例
	_flush_auto_save()
	grid_edit_requested.emit(_current_editing_res)

## 判断当前模板是否是纪念品资源（SouvenirResource 或其子类）
func _is_souvenir_script() -> bool:
	if current_script == null:
		return false
	if current_script == SouvenirResource:
		return true
	# 兼容继承自 SouvenirResource 的子类模板
	var sample = current_script.new()
	return sample is SouvenirResource

## 显示“非纪念品”警告，并（重新）启动自动隐藏计时
func _show_warning() -> void:
	var warning := get_node_or_null("Warning") as Label
	if warning == null:
		return
	warning.visible = true
	var timer := get_node_or_null("Warning/Timer") as Timer
	if timer != null:
		timer.start()  # 重新计时：多次点击会重置

## 警告计时到点：自动隐藏
func _on_warning_timeout() -> void:
	var warning := get_node_or_null("Warning") as Label
	if warning != null:
		warning.visible = false

## 格子编辑器请求返回：关闭并刷新主面板资源列表
func _close_grid_editor() -> void:
	if grid_inventory_editor != null:
		grid_inventory_editor.close()
	# 返回后重新加载列表（形状编辑可能改动了数据）
	refresh_list()
#endregion

#region 模板切换
func _on_template_selected(index: int):
	var type_name = template_selector.get_item_text(index)
	current_script = TemplateRegistry.templates[type_name]
	# 解析属性
	current_properties = PropertyHelper.get_editable_properties(current_script)
	# 加载该类型资源并重建按钮列表
	load_resources(type_name)
	refresh_list()
#endregion

#region 资源列表按钮
## 清空现有按钮列表，按 current_resources 重建
func refresh_list():
	for child in resource_list.get_children():
		child.queue_free()

	for res in current_resources:
		_add_list_button(res)

	# 选定第一个资源（如果有），在详情区显示
	if current_resources.size() > 0:
		select_resource(current_resources[0])
	else:
		_clear_detail_panel()

## 新建一个列表按钮并绑定资源
func _add_list_button(res: Resource) -> void:
	var item = _list_item_scene.instantiate()
	resource_list.add_child(item)
	if item is ResourceListButton:
		item.bind(res, self)

## 从按钮回调进入：点击某资源 -> 显示其详情
func select_resource(res: Resource) -> void:
	# 切换前先保存上一份待存资源（防抖 Flush）
	_flush_auto_save()
	_current_editing_res = res
	build_detail_panel(res)

## 刷新列表中和某资源对应的按钮（如 icon/data_name 变化后调用）
func _refresh_list_button(res: Resource) -> void:
	for child in resource_list.get_children():
		if child is ResourceListButton and child.resource == res:
			child.update_visual()
			return
#endregion

#region 资源加载与保存
func _data_dir_name(type_name: String) -> String:
	return type_name.to_lower().strip_edges().replace(" ", "_")

func _data_folder(type_name: String) -> String:
	return TemplateRegistry.workspace_root + "/data/" + _data_dir_name(type_name) + "/"

func load_resources(type_name: String):
	current_resources.clear()
	var folder = _data_folder(type_name)
	var dir = DirAccess.open(folder)
	if dir == null:
		return
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var res = load(folder + file) as Resource
			if res:
				current_resources.append(res)
		file = dir.get_next()
	current_resources.sort_custom(func(a, b): return a.id < b.id)

func save_resource(res: Resource):
	var type_name = template_selector.get_item_text(template_selector.selected)
	var folder = _data_folder(type_name)
	DirAccess.make_dir_recursive_absolute(folder)

	# data_name 为空时，用创建时分配的 id 兜底填充，避免存成空名/无意义名
	if res.get("data_name") != null and res.data_name.strip_edges() == "":
		res.data_name = str(res.id)
		# data_name 变化后同步刷新左侧列表按钮显示
		_refresh_list_button(res)

	var file_name: String
	if res.has_method("get") and res.get("data_name") != null and res.data_name.strip_edges() != "":
		file_name = res.data_name.strip_edges()
		file_name = file_name.replace("/", "_").replace("\\", "_").replace(":", "_")
	else:
		file_name = "untitled_" + str(res.id)
	var path = folder + file_name + ".tres"
	ResourceSaver.save(res, path)
	print("保存成功：", path)

func _on_save_pressed():
	# 手动保存时停掉防抖计时，避免立刻被触发重复保存
	_save_timer.stop()
	_pending_save = null
	if current_resources.is_empty():
		return
	for res in current_resources:
		save_resource(res)
	print("全部保存完成")

# ---- 防抖自动保存 ----
## 加入待保存队列并（重新）启动防抖计时
func _queue_auto_save(res: Resource) -> void:
	_pending_save = res
	_save_timer.start()

## 防抖计时结束后真正保存
func _on_save_timer_timeout() -> void:
	var to_save := _pending_save
	_pending_save = null
	if to_save != null:
		save_resource(to_save)

## 立即保存待存资源（切换资源/手动保存时调用）
func _flush_auto_save() -> void:
	_save_timer.stop()
	if _pending_save != null:
		save_resource(_pending_save)
		_pending_save = null
#endregion

#region 新建资源
func _on_new_resource_pressed() -> void:
	if current_script == null:
		push_error("未选择模板，无法新建资源")
		return
	var new_res = current_script.new()
	if new_res == null:
		push_error("无法实例化模板脚本：" + current_script.resource_path)
		return

	# 尝试自动生成 ID
	var existing_ids = current_resources.map(func(r): return r.id)
	var generated_id = 0

	var const_map: Dictionary = current_script.get_script_constant_map()
	if const_map.has("DEFAULT_CATEGORY"):
		var cat: int = int(const_map["DEFAULT_CATEGORY"])
		generated_id = InventoryResource.generate_id(cat, existing_ids)
	else:
		generated_id = 0

	new_res.id = generated_id

	current_resources.append(new_res)
	_add_list_button(new_res)
	select_resource(new_res)
	print("新建资源成功,ID = %d" % generated_id)
#endregion

#region 详情面板
func _clear_detail_panel():
	for child in detail_container.get_children():
		child.queue_free()

func build_detail_panel(res: Resource):
	_clear_detail_panel()

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_container.add_child(vbox)

	for prop in current_properties:
		var template_path = TemplateMapper.get_template_path(prop)
		if template_path.is_empty():
			continue

		var template_scene = load(template_path) as PackedScene
		if template_scene == null:
			continue

		var instance = template_scene.instantiate()

		if not instance is Protocol:
			push_error("模板 %s 未继承 Protocol,已跳过" % template_path)
			instance.queue_free()
			continue

		# 先加入树触发 _ready，确保模板内的 @onready 节点在 setup 前可用
		vbox.add_child(instance)

		var editor = instance as Protocol
		var initial_val = res.get(prop.name)
		editor.setup(prop.name, prop.hint_string, initial_val)
		editor.value_changed.connect(func(new_val):
			res.set(prop.name, new_val)
			# icon/data_name 等变化后同步刷新左侧按钮显示
			_refresh_list_button(res)
			# 防抖：延迟保存，防抖期内继续编辑会重置计时
			_queue_auto_save(res)
		)
#endregion

#region 导出
func _on_export_pressed():
	var all_data = {}
	for type_name in TemplateRegistry.templates:
		var script = TemplateRegistry.templates[type_name]
		var props = PropertyHelper.get_editable_properties(script)
		var folder = _data_folder(type_name)
		var type_dict = {}
		var dir = DirAccess.open(folder)
		if dir:
			dir.list_dir_begin()
			var file = dir.get_next()
			while file != "":
				if file.ends_with(".tres"):
					var res = load(folder + file) as Resource
					if res:
						var data_name: String = ""
						if res.get("data_name") != null:
							data_name = str(res.get("data_name"))
						var item = {
							"id": res.id,
							"data_name": data_name
						}
						for prop in props:
							var val = res.get(prop.name)
							if prop.type == TYPE_OBJECT and val is Texture2D:
								item[prop.name] = val.resource_path if val else ""
							else:
								item[prop.name] = val
						type_dict[res.id] = item
					file = dir.get_next()
		all_data[_data_dir_name(type_name)] = type_dict

	DirAccess.make_dir_recursive_absolute(TemplateRegistry.workspace_root + "/exports/")
	var path = TemplateRegistry.workspace_root + "/exports/game_data.dat"
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_var(all_data, true)
	f.close()
	print("导出成功：", path)
#endregion


func _on_clear_pressed() -> void:
	if _current_editing_res == null:
		push_warning("没有正在编辑的资源，无法清除")
		return
	var res = _current_editing_res
	# 保留 id/data_name（身份标识），其余可编辑字段全部清零
	for prop in current_properties:
		if prop.name == "id" or prop.name == "data_name":
			continue
		match prop.type:
			TYPE_STRING:
				res.set(prop.name, "")
			TYPE_BOOL:
				res.set(prop.name, false)
			TYPE_FLOAT:
				res.set(prop.name, 0.0)
			TYPE_OBJECT:
				res.set(prop.name, null)
			_:
				res.set(prop.name, 0)
	# 刷新左侧按钮显示 + 重建右侧详情面板
	_refresh_list_button(res)
	build_detail_panel(res)
	# 防抖保存
	_queue_auto_save(res)
	print("清除完成：", res.resource_path)

func _on_exit_pressed() -> void:
	# 退出前先把防抖待存资源落盘，避免丢改动
	_flush_auto_save()
	# 结束程序
	get_tree().quit()
