class_name SettingsManager
extends Node
## Preferencias de plataforma, gravadas **fora** do save de jogo.
##
## Sao coisas diferentes: o save guarda o que Caramelo conquistou; isto aqui guarda como a
## janela abre. Misturar os dois faria uma configuracao corrompida derrubar a progressao, e
## obrigaria a subir o schema do save toda vez que uma opcao de desktop mudasse. Por isso
## `user://settings.json` tem arquivo, versao, validacao e backup proprios.
##
## Toda leitura passa por validacao: valor de tipo errado, modo desconhecido, tamanho
## absurdo ou janela fora das telas caem para o padrao seguro, e o jogo abre. Um arquivo
## de uma **versao futura** nao e reescrito nem apagado: o jogo usa os padroes naquela
## sessao e preserva o arquivo para a versao que souber le-lo.

const SCHEMA_VERSION := 1
const DEFAULT_PATH := "user://settings.json"
const DEFAULT_BACKUP := "user://settings.backup.json"
const DEFAULT_TEMP := "user://settings.tmp.json"

## Faixas aceitas. Fora delas, o padrao entra no lugar — nunca o valor do arquivo.
const MIN_WIDTH := 640
const MIN_HEIGHT := 480
const MAX_WIDTH := 7680
const MAX_HEIGHT := 4320
const FPS_CHOICES: Array = [30, 60]

signal settings_loaded(settings: Dictionary)
signal settings_changed(key: String, value: Variant)
signal settings_saved()
signal settings_failed(reason: String)

## Desliga a escrita em disco. As suites que nao testam persistencia usam isto para nao
## deixar arquivo para a suite seguinte.
static var persistence_enabled := true

var _path := DEFAULT_PATH
var _backup_path := DEFAULT_BACKUP
var _temp_path := DEFAULT_TEMP
var _values: Dictionary = {}
var _future_version := 0
var _last_error := ""
var _loaded := false


## Padroes de instalacao nova. Papel de parede e autostart **comecam desligados**: os dois
## mexem no sistema de quem joga e exigem escolha explicita (`MVP_SPEC.md` secao 19).
static func defaults() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"display_mode": "windowed",
		"quiet_mode": false,
		"low_power_mode": true,
		"wallpaper_interaction": true,
		"launch_at_login": false,
		"window": {"width": 1280, "height": 720, "x": 60, "y": 60},
	}


func _ready() -> void:
	if _values.is_empty():
		_values = defaults()


func set_paths(main_path: String, backup_path: String, temp_path: String) -> void:
	_path = main_path
	_backup_path = backup_path
	_temp_path = temp_path


func get_settings_path() -> String:
	return _path


func get_last_error() -> String:
	return _last_error


func is_loaded() -> bool:
	return _loaded


# --------------------------------------------------------------------------------------
# Leitura
# --------------------------------------------------------------------------------------

## Carrega o arquivo, valida campo a campo e devolve os valores em uso.
##
## Nunca falha de forma dura: sem arquivo, com JSON quebrado ou com campos invalidos, o
## resultado sao os padroes. O que estava no disco so e substituido quando o jogo gravar.
func load_settings() -> Dictionary:
	_values = defaults()
	_future_version = 0
	_loaded = true
	if not persistence_enabled:
		settings_loaded.emit(get_all())
		return get_all()
	var text: Variant = _read(_path)
	if not (text is String):
		text = _read(_backup_path)
	if not (text is String):
		settings_loaded.emit(get_all())
		return get_all()
	# `JSON.new().parse` devolve codigo de erro em vez de imprimir: um arquivo corrompido e
	# um caso previsto aqui, nao um defeito para aparecer no log.
	var reader := JSON.new()
	var parsed: Variant = null
	if reader.parse(text as String) == OK:
		parsed = reader.data
	if not (parsed is Dictionary):
		_last_error = "settings.json ilegivel; usando os padroes."
		push_warning("SettingsManager: %s" % _last_error)
		settings_loaded.emit(get_all())
		return get_all()
	var data: Dictionary = parsed
	var version := int(data.get("schema_version", 0))
	if version > SCHEMA_VERSION:
		# Versao futura: nada e lido e, principalmente, nada e gravado por cima.
		_future_version = version
		_last_error = "settings.json e de uma versao mais nova (%d); preservado." % version
		push_warning("SettingsManager: %s" % _last_error)
		settings_loaded.emit(get_all())
		return get_all()
	_values = validate(data)
	settings_loaded.emit(get_all())
	return get_all()


## Peneira um dicionario cru e devolve um conjunto completo e seguro de valores.
static func validate(data: Dictionary) -> Dictionary:
	var safe := defaults()
	safe["display_mode"] = _valid_mode(data.get("display_mode"))
	safe["quiet_mode"] = _valid_bool(data.get("quiet_mode"), bool(safe["quiet_mode"]))
	safe["low_power_mode"] = _valid_bool(data.get("low_power_mode"), bool(safe["low_power_mode"]))
	safe["wallpaper_interaction"] = _valid_bool(data.get("wallpaper_interaction"),
		bool(safe["wallpaper_interaction"]))
	safe["launch_at_login"] = _valid_bool(data.get("launch_at_login"), false)
	if data.has("window_fps_limit"):
		safe["window_fps_limit"] = _valid_fps(data.get("window_fps_limit"))
	safe["window"] = _valid_window(data.get("window"))
	return safe


static func _valid_mode(value: Variant) -> String:
	if value is String and DesktopModeManager.MODE_NAMES.has(value as String):
		return value as String
	# Modo desconhecido nunca vira wallpaper: janela e o unico padrao seguro.
	return "windowed"


static func _valid_bool(value: Variant, fallback: bool) -> bool:
	return value as bool if value is bool else fallback


static func _valid_fps(value: Variant) -> int:
	if (value is int or value is float) and FPS_CHOICES.has(int(value)):
		return int(value)
	return 60


## Geometria utilizavel: tamanho dentro de faixa e janela visivel em alguma tela.
static func _valid_window(value: Variant) -> Dictionary:
	var fallback: Dictionary = (defaults()["window"] as Dictionary).duplicate()
	if not (value is Dictionary):
		return fallback
	var data: Dictionary = value
	var width := _valid_int(data.get("width"), int(fallback["width"]))
	var height := _valid_int(data.get("height"), int(fallback["height"]))
	if width < MIN_WIDTH or width > MAX_WIDTH:
		width = int(fallback["width"])
	if height < MIN_HEIGHT or height > MAX_HEIGHT:
		height = int(fallback["height"])
	var x := _valid_int(data.get("x"), int(fallback["x"]))
	var y := _valid_int(data.get("y"), int(fallback["y"]))
	if not is_position_on_screen(Vector2i(x, y), Vector2i(width, height)):
		x = int(fallback["x"])
		y = int(fallback["y"])
	return {"width": width, "height": height, "x": x, "y": y}


static func _valid_int(value: Variant, fallback: int) -> int:
	if value is int:
		return value as int
	if value is float and is_finite(value as float):
		return int(value as float)
	return fallback


## A janela precisa ter uma parte visivel em alguma tela. Um monitor desligado depois de
## fechar o jogo deixaria a janela num canto inacessivel; aqui isso e corrigido na leitura.
static func is_position_on_screen(position: Vector2i, size: Vector2i) -> bool:
	var window := Rect2i(position, Vector2i(maxi(size.x, 1), maxi(size.y, 1)))
	var screens := DisplayServer.get_screen_count()
	if screens <= 0:
		# Sem tela declarada (headless): so recusa coordenadas absurdas.
		return absi(position.x) < 20000 and absi(position.y) < 20000
	for index in screens:
		var usable := Rect2i(DisplayServer.screen_get_position(index),
			DisplayServer.screen_get_size(index))
		if usable.intersects(window):
			return true
	return false


# --------------------------------------------------------------------------------------
# Escrita
# --------------------------------------------------------------------------------------

## Grava com o mesmo cuidado do save de jogo: temporario, releitura, backup, promocao.
func save_settings() -> bool:
	if not persistence_enabled:
		return false
	if _future_version > SCHEMA_VERSION:
		# Preservar o arquivo de uma versao futura vale mais do que gravar preferencias.
		return _fail("settings.json de versao futura preservado; nada foi gravado.")
	var text := JSON.stringify(get_all(), "\t")
	if not _write(_temp_path, text):
		_remove(_temp_path)
		return _fail("nao foi possivel escrever o temporario das configuracoes.")
	var written: Variant = _read(_temp_path)
	if not (written is String) or (written as String).length() != text.length():
		_remove(_temp_path)
		return _fail("temporario das configuracoes incompleto.")
	if _exists(_path):
		_copy(_path, _backup_path)
	if not _copy(_temp_path, _path):
		_remove(_temp_path)
		return _fail("nao foi possivel promover as configuracoes; o arquivo anterior continua.")
	_remove(_temp_path)
	_last_error = ""
	settings_saved.emit()
	return true


func _fail(reason: String) -> bool:
	_last_error = reason
	push_warning("SettingsManager: %s" % reason)
	settings_failed.emit(reason)
	return false


# --------------------------------------------------------------------------------------
# Acesso
# --------------------------------------------------------------------------------------

func get_all() -> Dictionary:
	var copy := _values.duplicate(true)
	copy["schema_version"] = SCHEMA_VERSION
	return copy


func get_value(key: String, fallback: Variant = null) -> Variant:
	return _values.get(key, fallback)


func get_display_mode() -> String:
	return String(_values.get("display_mode", "windowed"))


func is_quiet_mode() -> bool:
	return bool(_values.get("quiet_mode", false))


func is_low_power_mode() -> bool:
	return bool(_values.get("low_power_mode", true))


func is_wallpaper_interactive() -> bool:
	return bool(_values.get("wallpaper_interaction", true))


func is_launch_at_login() -> bool:
	return bool(_values.get("launch_at_login", false))


func get_window_geometry() -> Dictionary:
	return (_values.get("window", defaults()["window"]) as Dictionary).duplicate()


## Altera um valor, validando antes. Devolve `true` quando o valor mudou de fato.
func set_value(key: String, value: Variant) -> bool:
	var candidate := _values.duplicate(true)
	candidate[key] = value
	var validated := validate(candidate)
	if not validated.has(key):
		return false
	if _values.get(key) == validated[key]:
		return false
	_values = validated
	settings_changed.emit(key, _values[key])
	return true


func set_window_geometry(position: Vector2i, size: Vector2i) -> void:
	var candidate := _values.duplicate(true)
	candidate["window"] = {"width": size.x, "height": size.y, "x": position.x, "y": position.y}
	_values = validate(candidate)
	settings_changed.emit("window", _values["window"])


## Volta tudo aos padroes de instalacao nova, sem gravar.
func reset_to_defaults() -> void:
	_values = defaults()
	settings_changed.emit("", null)


# --------------------------------------------------------------------------------------
# Disco
# --------------------------------------------------------------------------------------

func _exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return null
	var text := handle.get_as_text()
	handle.close()
	return text


func _write(path: String, text: String) -> bool:
	var handle := FileAccess.open(path, FileAccess.WRITE)
	if handle == null:
		return false
	handle.store_string(text)
	handle.close()
	return FileAccess.file_exists(path)


func _copy(from_path: String, to_path: String) -> bool:
	var text: Variant = _read(from_path)
	if not (text is String):
		return false
	return _write(to_path, text as String)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
