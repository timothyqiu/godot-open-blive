extends Control

var quitting := false

onready var blive = $OpenBlive
onready var output = $Output

onready var game_start: Button = $Dashboard/Game/Start
onready var game_end: Button = $Dashboard/Game/End
onready var danmaku_connect: Button = $Dashboard/Danmaku/Connect
onready var danmaku_disconnect: Button = $Dashboard/Danmaku/Disconnect


func _ready():
	get_tree().set_auto_accept_quit(false) # 需要在退出前停止游戏


func _notification(what):
	if what == NOTIFICATION_WM_QUIT_REQUEST and not quitting:
		quitting = true
		yield(blive.stop_game(), "completed")
		get_tree().quit()


func _set_danmaku_connected(v: bool):
	danmaku_connect.disabled = v
	danmaku_disconnect.disabled = not v


func _set_game_started(v: bool):
	game_start.disabled = v
	game_end.disabled = not v


func _append_datetime():
	var dt := OS.get_datetime()
	output.push_color(Color(1, 1, 1, 0.5))
	output.add_text("[%02d-%02d %02d:%02d:%02d]" % [dt.month, dt.day, dt.hour, dt.minute, dt.second])
	output.pop()


func _on_OpenBlive_danmaku_server_connected():
	_append_datetime()
	output.append_bbcode("[color=#22bb22]弹幕已连接[/color]\n")
	_set_danmaku_connected(true)


func _on_OpenBlive_danmaku_server_connection_failed():
	_append_datetime()
	output.append_bbcode("[color=#bb2222]弹幕连接失败[/color]\n")
	_set_danmaku_connected(false)


func _on_OpenBlive_danmaku_server_disconnected():
	_append_datetime()
	output.append_bbcode("[color=#222222]弹幕已断开[/color]\n")
	_set_danmaku_connected(false)


func _on_OpenBlive_danmaku_server_heartbeat_failed():
	_append_datetime()
	output.append_bbcode("[color=#222222]弹幕心跳错误，已断开[/color]\n")
	_set_danmaku_connected(false)


func _on_OpenBlive_danmaku_received(data: Dictionary):
	# 详细的字段信息见官方文档
	# https://open-live.bilibili.com/document/liveRoomData.html#%E8%8E%B7%E5%8F%96%E5%BC%B9%E5%B9%95%E4%BF%A1%E6%81%AF
	
	_append_datetime()
	output.push_meta(data.uface) # 头像 URL：可以在 Godot 中下载并显示，但需要自行识别图像格式，见 Image
	output.add_text(data.uname) # 昵称。如需对用户进行唯一区分建议用 danmaku.uid
	output.pop()
	output.append_bbcode(" [color=grey]说[/color] ")
	output.add_text(data.msg + "\n") # 弹幕内容


func _on_OpenBlive_gift_received(data: Dictionary):
	# 详细的字段信息见官方文档
	# https://open-live.bilibili.com/document/liveRoomData.html#%E8%8E%B7%E5%8F%96%E7%A4%BC%E7%89%A9%E4%BF%A1%E6%81%AF
	
	_append_datetime()
	output.push_meta(data.uface) # 头像 URL：可以在 Godot 中下载并显示，但需要自行识别图像格式，见 Image
	output.add_text(data.uname) # 昵称。如需对用户进行唯一区分建议用 danmaku.uid
	output.pop()
	output.append_bbcode(" [color=grey]送出[/color] ")
	output.add_text("%s×%d\n" % [data.gift_name, data.gift_num]) # 礼物名称及数量。如需对礼物进行唯一区分建议用 gift.gift_id


func _on_OpenBlive_game_started():
	_append_datetime()
	output.append_bbcode("[color=#22bb22]游戏已开启[/color] ")
	output.add_text("当前主播：%s\n" % blive.get_anchor_info().uname)
	_set_game_started(true)


func _on_OpenBlive_game_start_failed(code: int):
	_append_datetime()
	output.append_bbcode("[color=#bb2222]开启游戏失败: %d[/color]\n" % code)
	_set_game_started(false)


func _on_OpenBlive_game_stopped():
	_append_datetime()
	output.append_bbcode("[color=#222222]游戏已结束[/color]\n")
	_set_game_started(false)


func _on_Output_meta_clicked(meta):
	var err := OS.shell_open(meta)
	if err:
		printerr("Cannot open ", meta, " => ", err)


func _on_Start_pressed():
	game_start.disabled = true
	blive.start_game()


func _on_End_pressed():
	game_end.disabled = true
	blive.stop_game()


func _on_Connect_pressed():
	danmaku_connect.disabled = true
	blive.start_danmaku()


func _on_Disconnect_pressed():
	danmaku_disconnect.disabled = true
	blive.stop_danmaku()
