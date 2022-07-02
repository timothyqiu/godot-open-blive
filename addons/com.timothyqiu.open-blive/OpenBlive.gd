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
const AuthCodeRequester := preload("auth_code/AuthCodeRequester.tscn")

export var access_key_id: String
export var access_key_secret: String
export var app_id := 0

var api_client: ApiClient
var danmaku_client: DanmakuClient

var _last_wss_links := PoolStringArray()
var _last_auth_body: String

var _game_id: String
var _game_heartbeat: Timer
var _game_anchor_info: Dictionary


func _ready():
	danmaku_client = DanmakuClient.new()
	danmaku_client.connect("auth_success", self, "_on_danmaku_server_connected")
	danmaku_client.connect("connection_error", self, "emit_signal", ["danmaku_server_connection_failed"])
	danmaku_client.connect("connection_closed", self, "_on_danmaku_server_connection_closed")
	
	for signal_name in ["danmaku_received", "gift_received", "superchat_added", "superchat_removed", "guard_hired"]:
		danmaku_client.connect(signal_name, self, "_pass_danmaku_event", [signal_name])
	
	_game_heartbeat = Timer.new()
	_game_heartbeat.wait_time = 20
	_game_heartbeat.connect("timeout", self, "_on_game_heartbeat")
	add_child(_game_heartbeat)


func _notification(what):
	match what:
		NOTIFICATION_INTERNAL_PHYSICS_PROCESS:
			danmaku_client.poll_and_heartbeat()


func prompt_for_auth_code() -> String:
	yield(get_tree(), "idle_frame")
	
	var prompt = AuthCodeRequester.instance()
	add_child(prompt)
	prompt.show_dialog()
	var code: String = yield(prompt, "submitted")
	prompt.queue_free()
	return code


func get_anchor_info() -> Dictionary:
	return _game_anchor_info


func start_danmaku(url := "", auth_body := ""):
	yield(get_tree(), "idle_frame")
	
	if url.empty() or auth_body.empty():
		if _last_wss_links.empty() or _last_auth_body.empty():
			printerr("请使用 start_game() 启动游戏，启动游戏后会自动开启弹幕。start_danmaku() 仅用于弹幕服务器断开后的重连。")
			emit_signal("danmaku_server_connection_failed")
			return
		url = _last_wss_links[0]
		auth_body = _last_auth_body
	
	set_physics_process_internal(true)
	danmaku_client.connect_with_auth(url, auth_body)


func stop_danmaku():
	yield(get_tree(), "idle_frame")
	danmaku_client.disconnect_from_host()


func start_game(code := "", with_danmaku := true):
	yield(get_tree(), "idle_frame")
	
	if access_key_id.empty() or access_key_secret.empty():
		printerr("未配置 access_key_id 及 access_key_secret，无法开启互动玩法")
		emit_signal("game_start_failed", -1)
		return
	if app_id <= 0:
		printerr("未配置 app_id，无法开启互动玩法")
		emit_signal("game_start_failed", -1)
		return
	
	if not api_client:
		api_client = ApiClient.new(access_key_id, access_key_secret)
	
	if not code:
		code = get_auth_code_from_cmdline()
	
	if not code:
		code = yield(prompt_for_auth_code(), "completed")
	
	if not code:
		emit_signal("game_start_failed", -1)
		return
	
	_game_id = ""
	_game_anchor_info = {}
	
	while true:
		var result: ApiClient.ApiCallResult = yield(
			api_client.request("/v2/app/start", {code=code, app_id=app_id}),
			"completed"
		)
		if result.is_ok():
			_game_id = result.data.game_info.game_id
			_game_anchor_info = result.data.anchor_info
			_game_heartbeat.start()
			
			_last_wss_links = result.data.websocket_info.wss_link
			_last_auth_body = result.data.websocket_info.auth_body
			
			emit_signal("game_started")
			
			if with_danmaku:
				start_danmaku(_last_wss_links[0], _last_auth_body)
			return
		
		match result.code:
			7001: # 请求冷静期
				yield(get_tree().create_timer(5), "timeout")
			
			_:
				printerr("start game error: (%d) %s" % [result.code, result.message])
				if result.type == ApiClient.ApiCallResult.Type.API_ERROR:
					emit_signal("game_start_failed", result.code)
				else:
					emit_signal("game_start_failed", -1)
				return


func stop_game(keep_danmaku := false):
	yield(get_tree(), "idle_frame")
	
	if not _game_id:
		return
	
	_game_heartbeat.stop()
	
	var result: ApiClient.ApiCallResult = yield(
		api_client.request("/v2/app/end", {game_id=_game_id, app_id=app_id}),
		"completed"
	)
	if not result.is_ok():
		printerr("stop game error: (%d) %s" % [result.code, result.message])
	
	_on_game_stopped()
	
	if not keep_danmaku:
		stop_danmaku()


func get_auth_code_from_cmdline() -> String:
	for argument in OS.get_cmdline_args():
		if argument.find("=") > -1:
			var key_value = argument.split("=")
			if key_value[0] == "code":
				return key_value[1]
	return ""


func _on_game_stopped():
	_game_heartbeat.stop()
	_game_id = ""
	_game_anchor_info = {}
	emit_signal("game_stopped")


func _pass_danmaku_event(data: Dictionary, target: String):
	emit_signal(target, data)


func _on_danmaku_server_connected():
	emit_signal("danmaku_server_connected")


func _on_danmaku_server_connection_closed(clean_close: bool):
	set_physics_process_internal(false)
	emit_signal("danmaku_server_disconnected")


func _on_game_heartbeat():
	# TODO: Heartbeat interval after call complete.
	var result : ApiClient.ApiCallResult = yield(
		api_client.request("/v2/app/heartbeat", {game_id=_game_id}),
		"completed"
	)
	if not result.is_ok() and result.type == ApiClient.ApiCallResult.Type.API_ERROR and result.code == 7003:
		_on_game_stopped()
