extends CanvasLayer

const AUTH_CODE_SAVE_FILE := "user://open-blive.bin"

signal submitted(code)

onready var dialog: PopupDialog = $Dialog
onready var line_edit: LineEdit = $Dialog/LineEdit
onready var submit: TextureButton = $Dialog/Submit
onready var remember: CheckBox = $Dialog/Remember


func show_dialog():
	var saved := _load_auth_code()
	
	line_edit.text = saved
	_on_LineEdit_text_changed(saved)
	
	if saved:
		remember.pressed = true
	
	dialog.popup_centered()


func _load_auth_code() -> String:
	var file := File.new()
	var err := file.open(AUTH_CODE_SAVE_FILE, File.READ)
	if err:
		return ""
	var code := file.get_var() as String
	return code


func _save_auth_code(code: String):
	var file := File.new()
	var err := file.open(AUTH_CODE_SAVE_FILE, File.WRITE)
	if err:
		return
	file.store_var(code)


func _on_LineEdit_focus_entered():
	line_edit.add_stylebox_override("normal", null)


func _on_LineEdit_focus_exited():
	if line_edit.text.empty():
		line_edit.add_stylebox_override("normal", preload("line_edit_stylebox.tres"))


func _on_LineEdit_text_changed(new_text: String):
	submit.disabled = new_text.strip_edges().empty()


func _on_LineEdit_text_entered(new_text: String):
	if not submit.disabled:
		_on_Submit_pressed()


func _on_Submit_pressed():
	var code := line_edit.text.strip_edges()
	if remember.pressed:
		_save_auth_code(code)
	else:
		_save_auth_code("")
	emit_signal("submitted", code)
	dialog.hide()


func _on_Close_pressed():
	emit_signal("submitted", "")
	dialog.hide()


func _on_Link_pressed():
	var url := "https://link.bilibili.com/p/center/index#/my-room/start-live"
	var err := OS.shell_open(url)
	if err:
		printerr("Failed to open link to %s: %d" % [url, err])
