extends Node

var templates: Dictionary = {}
# 独立程序工作区根目录：用户可写目录（独立可执行程序里 res:// 是只读 pck，不能写）
var workspace_root: String = OS.get_user_data_dir()

func _ready() -> void:
	load_templates()

func load_templates() -> void:
	templates.clear()
	var dir := DirAccess.open("res://ResourceTemplate/Children/")
	if dir == null:
		push_error("没找到 ResourceTemplate/Children 文件夹！")
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".gd"):
			var script := load("res://ResourceTemplate/Children/" + file) as Script
			if script != null and _script_inherits_from(script, "DataResource"):
				var base_name := file.replace(".gd", "").capitalize()
				templates[base_name] = script
		file = dir.get_next()
	dir.list_dir_end()
	print("=== 扫描结束，共注册 ", templates.size(), " 个模板 ===")

func _script_inherits_from(script: Script, target_class: String) -> bool:
	var current: Script = script
	while current != null:
		if current.get_global_name() == target_class:
			return true
		current = current.get_base_script()
	return false
