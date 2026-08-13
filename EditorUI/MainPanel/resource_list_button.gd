class_name ResourceListButton

extends Control

## 左边资源列表中代表单个资源的按钮项。
## 参照 addons/inventory_editor 的 InventoryItem 模式：
## 持有一个资源引用 + 主面板引用，点击时通知主面板切换到该资源。

## 主面板引用（由 bind 时注入，用于回调切换详情）
var editor: Control = null

## 本按钮代表的资源
var resource: DataResource = null

# 不依赖 @onready 的节点引用，避免在 _ready 前调用 bind 时为空
var _button: Button = null


func _ready() -> void:
	# 获取内部按钮节点并连接点击信号
	_button = get_node_or_null("%Button")
	if _button != null:
		_button.pressed.connect(on_click)
	# 控件本身不拦截鼠标，把点击全部交给内部 Button
	mouse_filter = MOUSE_FILTER_IGNORE


## 绑定资源，并设置显示
func bind(target_resource: DataResource, target_editor: Control) -> void:
	if _button == null:
		_button = get_node_or_null("%Button")
		if _button != null:
			_button.pressed.connect(on_click)
	resource = target_resource
	editor = target_editor
	update_visual()


## 由主编辑器调用，刷新按钮的图标与文字
func update_visual() -> void:
	if resource == null or _button == null:
		return
	_button.icon = resource.icon       # 来自基类统一字段
	_button.text = resource.data_name  # 来自基类统一字段


func on_click() -> void:
	if editor and editor.has_method("select_resource"):
		editor.select_resource(resource)

