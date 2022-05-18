extends Node

signal danmaku_server_connected
signal danmaku_server_connection_failed
signal danmaku_server_disconnected

signal danmaku_received(data)
signal gift_received(data)
signal superchat_added(data)
signal superchat_removed(data)
signal guard_hired(data)

signal game_started
signal game_start_failed(code)
signal game_stopped

const ApiClient := preload("api_client.gd")
const DanmakuClient := preload("danmaku_client.gd")

export var access_key_id: String
export var access_key_secret: String
export var app_id := 0 # 大于 0 时启用互动玩法
export var room_id_override := 0 # 大于 0 时强制使用特定直播间（默认从命令行参数获取）

var api_client: ApiClient
var danmaku_client: DanmakuClient

var game_id: String
var game_heartbeat: Timer


func _ready():
	var room_id = room_id_override if room_id_override > 0 else _parse_room_id()
	api_client = ApiClient.new(room_id, access_key_id, access_key_secret)
	
	danmaku_client = DanmakuClient.new()
	danmaku_client.connect("auth_success", self, "_on_danmaku_server_connected")
	danmaku_client.connect("connection_error", self, "emit_signal", ["danmaku_server_connection_failed"])
	danmaku_client.connect("connection_closed", self, "_on_danmaku_server_connection_closed")
	
	for signal_name in ["danmaku_received", "gift_received", "superchat_added", "superchat_removed", "guard_hired"]:
		danmaku_client.connect(signal_name, self, "_pass_danmaku_event", [signal_name])
	
	game_heartbeat = Timer.new()
	game_heartbeat.wait_time = 30
	game_heartbeat.connect("timeout", self, "_on_game_heartbeat")
	add_child(game_heartbeat)


func _notification(what):
	match what:
		NOTIFICATION_INTERNAL_PHYSICS_PROCESS:
			danmaku_client.poll_and_heartbeat()


func start_danmaku():
	if access_key_id.empty() or access_key_secret.empty():
		printerr("未配置 access_key_id 及 access_key_secret，无法开启弹幕")
		emit_signal("danmaku_server_connection_failed")
		return
	
	var result: ApiClient.ApiCallResult = yield(api_client.get_websocket_info(), "completed")
	if result.is_ok():
		set_physics_process_internal(true)
		danmaku_client.connect_with_data(result.data)
	else:
		emit_signal("danmaku_server_connection_failed")


func stop_danmaku():
	danmaku_client.disconnect_from_host()


func start_game():
	if access_key_id.empty() or access_key_secret.empty():
		printerr("未配置 access_key_id 及 access_key_secret，无法开启互动玩法")
		emit_signal("game_start_failed", -1)
		return
	if app_id <= 0:
		printerr("未配置 app_id，无法开启互动玩法")
		emit_signal("game_start_failed", -1)
		return
	
	game_id = ""
	
	while true:
		var result: ApiClient.ApiCallResult = yield(api_client.app_start(app_id), "completed")
		if result.is_ok():
			game_id = result.data.game_id
			game_heartbeat.start()
			emit_signal("game_started")
			return
		
		match result.code:
			7001: # 请求冷静期
				yield(get_tree().create_timer(5), "timeout")
			
			_:
				push_error("failed to start game: (%d) %s" % [result.code, result.message])
				if result.type == ApiClient.ApiCallResult.Type.API_ERROR:
					emit_signal("game_start_failed", result.code)
				else:
					emit_signal("game_start_failed", -1)
				return


func stop_game():
	if not game_id:
		return
	
	game_heartbeat.stop()
	api_client.app_end(app_id, game_id)
	game_id = ""
	emit_signal("game_stopped")


func _parse_room_id() -> int:
	for argument in OS.get_cmdline_args():
		if argument.find("=") > -1:
			var key_value = argument.split("=")
			if key_value[0].trim_prefix("--") == "room_id":
				return int(key_value[1])
	printerr("未使用 `--room_id` 参数指定直播间。上架后在直播姬中启动会自动设置该参数；调试时可在项目设置 `editor/main_run_args` 中指定。正在默认使用 @timothyqiu 的直播间。")
	return 592299


func _pass_danmaku_event(data: Dictionary, target: String):
	emit_signal(target, data)


func _on_danmaku_server_connected():
	emit_signal("danmaku_server_connected")


func _on_danmaku_server_connection_closed(clean_close: bool):
	set_physics_process_internal(false)
	emit_signal("danmaku_server_disconnected")


func _on_game_heartbeat():
	api_client.app_heartbeat(game_id)
