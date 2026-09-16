class_name DesktopModeManager
extends Node
## Troca entre os tres modos de execucao e garante que sempre exista um caminho de volta.
##
## Os modos vem do `MVP_SPEC.md` secao 19: janela normal, janela sem bordas e papel de
## parede. Os dois primeiros sao janela comum e funcionam em qualquer sistema; o terceiro
## depende de integracao nativa e **so existe no Windows**.
##
## Regras que este no faz valer:
##
## * Instalacao nova abre em `WINDOWED`, nunca em papel de parede.
## * Papel de parede so e tentado depois de `session_ready`, uma vez, sem repetir por quadro.
## * Falha nativa **nao** e persistida: o modo salvo continua sendo o ultimo que funcionou.
## * Qualquer falha cai para um modo utilizavel e avisa, em vez de insistir ou encerrar.
## * `Ctrl+Shift+W`, `--windowed` e o botao das configuracoes sempre trazem a janela de volta.
##
## Nada aqui grava progresso de jogo: o gerenciador so conhece janela e configuracoes.

enum Mode { WINDOWED, BORDERLESS, WALLPAPER }

const MODE_NAMES: Array = ["windowed", "borderless", "wallpaper"]

## Geometria de resgate, usada por `--reset-window` e por qualquer volta de emergencia.
const SAFE_SIZE := Vector2i(1280, 720)
const SAFE_POSITION := Vector2i(60, 60)

signal mode_changed(previous_mode: int, new_mode: int)
signal mode_failed(requested_mode: int, reason: String)
## Mensagem curta para a interface mostrar sem interromper o jogo.
signal notice(message: String)

var _adapter: PlatformAdapter
var _settings: SettingsManager
var _mode := Mode.WINDOWED
var _wallpaper_attempted := false
var _last_failure := ""
var _geometry := {"position": SAFE_POSITION, "size": SAFE_SIZE}
var _forced_windowed := false
var _handle_provider: Callable = Callable()


## `forced_windowed` chega de fora — da linha de comando, em producao, e dos testes, na
## suite — para que a decisao continue sendo de quem chama, e nao um `if` escondido aqui.
func configure(adapter: PlatformAdapter, settings: SettingsManager,
		forced_windowed: bool = false) -> void:
	_adapter = adapter if adapter != null else FallbackAdapter.new()
	_settings = settings
	if _settings != null:
		var saved := _settings.get_window_geometry()
		_geometry = {
			"position": Vector2i(int(saved["x"]), int(saved["y"])),
			"size": Vector2i(int(saved["width"]), int(saved["height"])),
		}
	# `--windowed` vale so para esta execucao: a preferencia salva continua no arquivo.
	_forced_windowed = forced_windowed


func is_configured() -> bool:
	return _adapter != null


static func mode_name(mode: int) -> String:
	return String(MODE_NAMES[mode]) if mode >= 0 and mode < MODE_NAMES.size() else "windowed"


static func mode_from_name(name: String) -> int:
	var index := MODE_NAMES.find(name)
	return index if index >= 0 else Mode.WINDOWED


func get_mode() -> int:
	return _mode


func get_adapter() -> PlatformAdapter:
	return _adapter


func get_last_failure() -> String:
	return _last_failure


func get_geometry() -> Dictionary:
	return _geometry.duplicate()


func is_forced_windowed() -> bool:
	return _forced_windowed


## O modo esta disponivel neste sistema? Papel de parede depende do adaptador.
func is_mode_available(mode: int) -> bool:
	if mode == Mode.WALLPAPER:
		return _adapter != null and _adapter.supports_wallpaper()
	return mode == Mode.WINDOWED or mode == Mode.BORDERLESS


# --------------------------------------------------------------------------------------
# Troca de modo
# --------------------------------------------------------------------------------------

## Pede um modo. Devolve `true` so quando ele realmente passou a valer.
##
## `persist` grava a escolha nas configuracoes; uma falha **nunca** persiste. Trocar de
## modo nao toca em atributo, atividade nem save de jogo.
func request_mode(mode: int, persist: bool = true) -> bool:
	if not is_configured():
		return false
	if mode < 0 or mode >= MODE_NAMES.size():
		return _fail(Mode.WINDOWED, "modo desconhecido.")
	if mode == Mode.WALLPAPER and _forced_windowed:
		return _fail(mode, "aberto com --windowed: o papel de parede fica para a proxima vez.")
	if mode == Mode.WALLPAPER and not is_mode_available(mode):
		# Plataforma sem integracao: o jogo permanece em janela, como manda a secao 19.
		_apply_windowed()
		return _fail(mode, "o modo papel de parede so existe no Windows. A janela continua aberta.")
	if mode == _mode:
		_apply_mode(mode)
		return true

	var previous := _mode
	match mode:
		Mode.WINDOWED:
			_detach_if_needed()
			_apply_windowed()
		Mode.BORDERLESS:
			_detach_if_needed()
			_apply_borderless()
		Mode.WALLPAPER:
			var attached := _attach_wallpaper()
			if not attached["ok"]:
				# Fallback do `MVP_SPEC.md` secao 19: cai para janela sem bordas, avisa e
				# segue jogando. O modo salvo nao vira wallpaper.
				_apply_borderless()
				_mode = Mode.BORDERLESS
				mode_changed.emit(previous, _mode)
				return _fail(mode, String(attached["reason"]))
	_mode = mode
	if persist and _settings != null:
		_settings.set_value("display_mode", mode_name(mode))
	mode_changed.emit(previous, _mode)
	return true


## Volta para a janela normal. E a saida de emergencia: nunca falha, nunca depende de
## adaptador e devolve a janela a uma geometria utilizavel.
func return_to_windowed(persist: bool = true) -> void:
	_detach_if_needed()
	var previous := _mode
	_apply_windowed()
	_mode = Mode.WINDOWED
	if persist and _settings != null:
		_settings.set_value("display_mode", "windowed")
	if previous != _mode:
		mode_changed.emit(previous, _mode)


## `--reset-window`: devolve tamanho e posicao seguros sem encostar no progresso.
func reset_window() -> void:
	_geometry = {"position": SAFE_POSITION, "size": SAFE_SIZE}
	if _settings != null:
		_settings.set_window_geometry(SAFE_POSITION, SAFE_SIZE)
	_apply_geometry()
	notice.emit("Janela restaurada para %d × %d." % [SAFE_SIZE.x, SAFE_SIZE.y])


## Tentativa unica do modo salvo, depois de a sessao estar pronta. Papel de parede nunca e
## tentado de novo sozinho: uma falha registra e para por ali.
func apply_saved_mode() -> void:
	if _settings == null:
		return
	var desired := mode_from_name(_settings.get_display_mode())
	if _forced_windowed:
		return_to_windowed(false)
		notice.emit("Aberto em janela por --windowed; a preferencia salva foi mantida.")
		return
	if desired == Mode.WALLPAPER:
		if _wallpaper_attempted:
			return
		_wallpaper_attempted = true
	request_mode(desired, false)


## Encerramento: solta o papel de parede e devolve uma janela normal, para que a proxima
## abertura — ou o proprio desktop — nao fique com uma janela orfa presa ao Explorer.
func prepare_for_exit() -> void:
	if _mode == Mode.WALLPAPER:
		_detach_if_needed()
		_apply_windowed()
		_mode = Mode.WINDOWED


func _fail(requested_mode: int, reason: String) -> bool:
	_last_failure = reason
	mode_failed.emit(requested_mode, reason)
	notice.emit(reason)
	return false


func _attach_wallpaper() -> Dictionary:
	var handle := get_window_handle()
	if not PlatformAdapter.is_valid_handle(handle):
		return PlatformAdapter.failure(PlatformAdapter.REASON_INVALID_HANDLE)
	return _adapter.attach_wallpaper(handle)


func _detach_if_needed() -> void:
	if _adapter == null:
		return
	if _mode == Mode.WALLPAPER:
		var result := _adapter.detach_wallpaper()
		if not result["ok"]:
			push_warning("DesktopModeManager: %s" % String(result["reason"]))


# --------------------------------------------------------------------------------------
# Janela
# --------------------------------------------------------------------------------------

## Identificador nativo da janela, pela API oficial do `DisplayServer`. E o unico valor que
## sai daqui para um helper do sistema — e ele e conferido antes.
func get_window_handle() -> int:
	if _handle_provider.is_valid():
		return int(_handle_provider.call())
	if not _has_window_server():
		return 0
	var handle: int = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
	return handle


## Troca a origem do identificador de janela.
##
## Existe para os testes: sem janela de verdade — e headless nao tem — o caminho de
## sucesso do papel de parede nunca seria exercitado. Em producao ninguem chama isto, e o
## identificador continua vindo do `DisplayServer`.
func set_handle_provider(provider: Callable) -> void:
	_handle_provider = provider


func _has_window_server() -> bool:
	return DisplayServer.get_name() != "headless"


func _apply_windowed() -> void:
	if not _has_window_server():
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_apply_geometry()


func _apply_borderless() -> void:
	if not _has_window_server():
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	# Sem bordas continua sendo janela: nada de `always_on_top`, para nao prender a tela
	# de quem joga.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	DisplayServer.window_set_position(usable.position)
	DisplayServer.window_set_size(usable.size)


func _apply_mode(mode: int) -> void:
	match mode:
		Mode.WINDOWED: _apply_windowed()
		Mode.BORDERLESS: _apply_borderless()


func _apply_geometry() -> void:
	if not _has_window_server():
		return
	DisplayServer.window_set_size(_geometry["size"])
	DisplayServer.window_set_position(_geometry["position"])


## Guarda a geometria atual da janela, para reabrir onde ficou. Nao grava em disco: quem
## grava e o `SettingsManager`, no fechamento.
func remember_geometry() -> void:
	if not _has_window_server() or _mode != Mode.WINDOWED:
		return
	_geometry = {
		"position": DisplayServer.window_get_position(),
		"size": DisplayServer.window_get_size(),
	}
	if _settings != null:
		_settings.set_window_geometry(_geometry["position"], _geometry["size"])


# --------------------------------------------------------------------------------------
# Saidas de emergencia
# --------------------------------------------------------------------------------------

## `Ctrl+Shift+W` devolve a janela mesmo com o jogo preso atras dos icones do desktop.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_W and key.ctrl_pressed and key.shift_pressed:
		return_to_windowed()
		notice.emit("Voltando para a janela (Ctrl+Shift+W).")
		get_viewport().set_input_as_handled()


static func has_windowed_argument() -> bool:
	return OS.get_cmdline_args().has("--windowed") or OS.get_cmdline_user_args().has("--windowed")


static func has_reset_window_argument() -> bool:
	return OS.get_cmdline_args().has("--reset-window") \
		or OS.get_cmdline_user_args().has("--reset-window")
