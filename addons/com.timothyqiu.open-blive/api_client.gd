var _endpoint: String
var _access_key_id: String
var _access_key_secret: String

var _hmac := HMACContext.new()
var _http := HTTPClient.new()

var _debug_mode := false


class ApiCallResult:
	enum Type { SUCCESS, SYSTEM_ERROR, REQUEST_ERROR, HTTP_ERROR, API_ERROR }

	var type: int = Type.SUCCESS
	var code := 0
	var message: String
	var request_id: String
	var data: Dictionary

	static func make_success(data: Dictionary) -> ApiCallResult:
		var result := ApiCallResult.new()
		result.data = data
		return result

	static func make_system_error(code: int, message: String) -> ApiCallResult:
		var result := ApiCallResult.new()
		result.type = Type.SYSTEM_ERROR
		result.code = code
		result.message = message
		return result

	static func make_request_error(code: int, message: String) -> ApiCallResult:
		var result := ApiCallResult.new()
		result.type = Type.REQUEST_ERROR
		result.code = code
		result.message = message
		return result

	static func make_http_error(code: int, message: String) -> ApiCallResult:
		var result := ApiCallResult.new()
		result.type = Type.HTTP_ERROR
		result.code = code
		result.message = message
		return result

	static func make_api_error(code: int, message: String) -> ApiCallResult:
		var result := ApiCallResult.new()
		result.type = Type.API_ERROR
		result.code = code
		result.message = message
		return result

	func is_ok() -> bool:
		return type == Type.SUCCESS


func _init(key_id: String, key_secret: String) -> void:
	_access_key_id = key_id
	_access_key_secret = key_secret
	_endpoint = "https://live-open.biliapi.com"


func _generate_signature(chunk: String) -> String:
	var err := _hmac.start(HashingContext.HASH_SHA256, _access_key_secret.to_utf8())
	if err:
		printerr("OpenBlive: failed to start HMAC context.")
		return String()
	err = _hmac.update(chunk.to_utf8())
	if err:
		printerr("OpenBlive: failed to update HMAC context.")
		_hmac.finish()
		return String()
	return _hmac.finish().hex_encode()


func request(api: String, params: Dictionary) -> ApiCallResult:
	var body := to_json(params)
	var timestamp := OS.get_unix_time()
	var headers := [
		"x-bili-accesskeyid:%s" % _access_key_id,
		"x-bili-content-md5:%s" % body.md5_text(),
		"x-bili-signature-method:HMAC-SHA256",
		"x-bili-signature-nonce:%d" % (timestamp + randi() % 100000),
		"x-bili-signature-version:1.0",
		"x-bili-timestamp:%d" % timestamp,
	]
	var signature := _generate_signature(PoolStringArray(headers).join("\n"))
	headers.append_array([
		"Accept: application/json",
		"Content-Type: application/json",
		"Authorization: %s" % signature,
	])
	
	# So that the caller can safely yield this method.
	yield(Engine.get_main_loop(), "idle_frame")
	
	var err := _http.connect_to_host(_endpoint)
	if err:
		return ApiCallResult.make_system_error(err, "failed to start connection")
	
	while true:
		err = _http.poll()
		if err:
			return ApiCallResult.make_system_error(err, "failed when polling for connection")
		
		var status := _http.get_status()
		match status:
			HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING:
				yield(Engine.get_main_loop(), "idle_frame")
			HTTPClient.STATUS_CONNECTED:
				break
			_:
				return ApiCallResult.make_request_error(status, "failed when waiting for connection")
	
	err = _http.request(HTTPClient.METHOD_POST, api, headers, body)
	if err:
		return ApiCallResult.make_system_error(err, "failed to create request")
	
	while true:
		err = _http.poll()
		if err:
			return ApiCallResult.make_system_error(err, "failed when polling for request")
		
		var status := _http.get_status()
		match status:
			HTTPClient.STATUS_REQUESTING:
				yield(Engine.get_main_loop(), "idle_frame")
			HTTPClient.STATUS_BODY, HTTPClient.STATUS_CONNECTED:
				break
			_:
				return ApiCallResult.make_request_error(status, "failed when waiting for request")
	
	var http_code := _http.get_response_code()
	if http_code != HTTPClient.RESPONSE_OK:
		return ApiCallResult.make_http_error(http_code, "unexpected HTTP status code")
	
	var raw_response := PoolByteArray()
	while true:
		err = _http.poll()
		if err:
			return ApiCallResult.make_system_error(err, "failed when polling for response")
		
		var status := _http.get_status()
		match status:
			HTTPClient.STATUS_BODY:
				raw_response += _http.read_response_body_chunk()
			HTTPClient.STATUS_CONNECTED:
				break
			_:
				return ApiCallResult.make_request_error(status, "failed when waiting for response")
	
	var json_text := raw_response.get_string_from_utf8()
	var response := parse_json(json_text) as Dictionary
	
	var api_code = response.get("code")
	if api_code != 0:
		return ApiCallResult.make_api_error(api_code, response.get("message", json_text))
	return ApiCallResult.make_success(response.get("data", {}))

