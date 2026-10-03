extends Control

class_name Reference

# 纪念品编辑器专用：可拖动的 atlas 参考图。
# - 显示一张 Texture2D（通常来自 SouvenirResource.full_texture），尺寸 = 贴图原始尺寸。
# - 拖放模式（drag_enabled=true）：按下拖动，实时 snap 到 32px 网格格位。
# - 编辑模式（drag_enabled=false）：mouse_filter 置 IGNORE，鼠标穿透，可点身下格子。
# 位置不持久化：每次打开资源时由 GridInventoryEditor 重新生成于固定位置。

## 显示的贴图（矩形内整幅绘制，尺寸即贴图原始尺寸）
var texture: Texture2D = null

## 所属网格（用于取真实格 (0,0) 原点和合法范围），由外部注入
var grid: GridEditor = null

## 是否处于拖放模式（true=可交互拖动；false=忽略鼠标）
var drag_enabled: bool = true

## 单格像素尺寸（与 EditorPanel 一致，禁止写字面量 32）
var _cell_px: int = 32

## 编辑模式下的不透明度（参考图变淡，不遮挡底下的格子/选择）
const OPACITY_EDIT: float = 0.3
## 拖放模式下的不透明度（参考图完整显示，便于对齐）
const OPACITY_DRAG: float = 1.0

## 拖动中状态
var _dragging: bool = false
## 按下点相对本节点左上角的偏移（global 度量）
var _drag_grab: Vector2 = Vector2.ZERO


func _ready() -> void:
	_apply_mouse_mode()


## 设置贴图并按原始尺寸调整节点大小
func set_texture(tex: Texture2D) -> void:
	texture = tex
	if tex != null:
		size = Vector2(tex.get_size())
	queue_redraw()


## 设置单格像素与网格引用
func configure(p_grid: GridEditor, cell_px: int) -> void:
	grid = p_grid
	_cell_px = cell_px


## 切换拖放/编辑模式：同步鼠标过滤与不透明度
func set_drag_enabled(enabled: bool) -> void:
	drag_enabled = enabled
	_apply_mouse_mode()


func _apply_mouse_mode() -> void:
	# 拖放：STOP（接收鼠标事件）；编辑：IGNORE（穿透到身下节点）
	mouse_filter = Control.MOUSE_FILTER_STOP if drag_enabled else Control.MOUSE_FILTER_IGNORE
	# 不透明度随模式切换：拖放 100%（完整显示便于对齐），编辑 30%（变淡不遮格子）
	modulate.a = OPACITY_DRAG if drag_enabled else OPACITY_EDIT


func _draw() -> void:
	if texture != null:
		# 贴图按原始尺寸铺满 rect（size == 贴图尺寸）
		draw_texture(texture, Vector2.ZERO)


# ---- 拖动逻辑（仅拖放模式下到达这里）----
func _gui_input(event: InputEvent) -> void:
	if not drag_enabled:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				# 记录抓取偏移（global 坐标，避免后续计算受 position 影响）
				_drag_grab = get_global_mouse_position() - global_position
				# 首帧即吸附到最近合法格位（不写右侧特判，靠 clamp 自然收敛）
				_snap_now()
				accept_event()
			else:
				_dragging = false
				accept_event()
	elif event is InputEventMouseMotion and _dragging:
		# 拖动中每帧都吸附，保证任何一帧都不溢出合法区域
		_snap_now()
		accept_event()


# 依据“鼠标位置 - 抓取偏移”求目标矩形左上角，交给网格吸附到最近合法格位
func _snap_now() -> void:
	if grid == null:
		return
	var desired_pos := get_global_mouse_position() - _drag_grab
	var rect := Rect2(desired_pos, size)
	rect = grid.snap_rect_to_cell(rect)
	global_position = rect.position
