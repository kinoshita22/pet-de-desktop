class_name PerformanceManager
extends Node
## Decide quantos quadros por segundo o jogo tenta desenhar, e por que.
##
## As metas vem do `MVP_SPEC.md` secao 20: ate 60 FPS com a janela em uso, 10 FPS no papel
## de parede ou em baixo consumo, 5 FPS quando um aplicativo alheio ocupa a tela inteira, e
## perfil reduzido com a janela minimizada.
##
## O ponto delicado e o que **nao** muda junto: nada de jogabilidade depende de quadro. As
## atividades, as recargas, o descanso e o autosave andam por `delta`, entao 10 FPS e 60
## FPS produzem exatamente o mesmo resultado no mesmo tempo de relogio. O que cai e a
## frequencia de desenho — e, com ela, o trabalho visual por segundo.
##
## Perder o foco **nao** e o mesmo que ter um aplicativo em tela cheia na frente. Quando a
## sondagem nao existe, a resposta e `UNKNOWN` e o perfil de 5 FPS simplesmente nao entra.

enum Profile { NORMAL, LOW_POWER, FOREIGN_FULLSCREEN, MINIMIZED }

const PROFILE_NAMES: Array = ["normal", "baixo_consumo", "tela_cheia_alheia", "minimizado"]

## Metas da secao 20, em quadros por segundo.
const PROFILE_FPS: Dictionary = {
	Profile.NORMAL: 60,
	Profile.LOW_POWER: 10,
	Profile.FOREIGN_FULLSCREEN: 5,
	Profile.MINIMIZED: 5,
}

## Intervalo minimo entre duas sondagens de tela cheia. Perguntar ao sistema custa um
## processo; uma vez a cada cinco segundos e suficiente para o que ele decide.
const PROBE_INTERVAL := 5.0

signal profile_changed(profile: int, target_fps: int, reason: String)

var _adapter: PlatformAdapter
var _settings: SettingsManager
var _profile := Profile.NORMAL
var _reason := "janela em uso"
var _focused := true
var _minimized := false
var _low_power := false
var _window_mode := DesktopModeManager.Mode.WINDOWED
var _foreign_fullscreen := PlatformAdapter.Probe.UNKNOWN
var _probe_countdown := PROBE_INTERVAL
var _window_fps_limit := 60
var _apply_to_engine := true
var _visual_updates := 0


func _ready() -> void:
	# Em headless nao ha o que desenhar, e limitar o motor so faria os testes demorarem.
	_apply_to_engine = DisplayServer.get_name() != "headless"
	_evaluate("abertura")


func configure(settings: SettingsManager, adapter: PlatformAdapter) -> void:
	_settings = settings
	_adapter = adapter if adapter != null else FallbackAdapter.new()
	if _settings != null:
		_low_power = _settings.is_low_power_mode()
		_window_fps_limit = int(_settings.get_value("window_fps_limit", 60))
		if not _settings.settings_changed.is_connected(_on_settings_changed):
			_settings.settings_changed.connect(_on_settings_changed)
	_evaluate("configuracao aplicada")


func _process(delta: float) -> void:
	simulate(delta)


## Avanca a sondagem periodica. Publico para os testes adiantarem sem esperar tempo real.
func simulate(delta: float) -> void:
	if delta <= 0.0:
		return
	if not _should_probe():
		return
	_probe_countdown -= delta
	if _probe_countdown > 0.0:
		return
	_probe_countdown = PROBE_INTERVAL
	poll_foreign_fullscreen()


## So faz sentido perguntar quando o jogo esta fora do primeiro plano e existe sondagem.
func _should_probe() -> bool:
	if _adapter == null or not _adapter.supports_fullscreen_probe():
		return false
	return not _focused or _window_mode == DesktopModeManager.Mode.WALLPAPER


func poll_foreign_fullscreen() -> int:
	if _adapter == null or not _adapter.supports_fullscreen_probe():
		_foreign_fullscreen = PlatformAdapter.Probe.UNKNOWN
		return _foreign_fullscreen
	_foreign_fullscreen = _adapter.probe_foreign_fullscreen()
	_evaluate("sondagem de tela cheia")
	return _foreign_fullscreen


# --------------------------------------------------------------------------------------
# Entradas de estado
# --------------------------------------------------------------------------------------

func set_focused(focused: bool) -> void:
	if _focused == focused:
		return
	_focused = focused
	if focused:
		# Voltar ao foco descarta a suposicao anterior: o que estava em tela cheia pode ter
		# saido, e o proximo ciclo pergunta de novo.
		_foreign_fullscreen = PlatformAdapter.Probe.UNKNOWN
		_probe_countdown = PROBE_INTERVAL
	_evaluate("foco recuperado" if focused else "janela em segundo plano")


func set_minimized(minimized: bool) -> void:
	if _minimized == minimized:
		return
	_minimized = minimized
	_evaluate("janela minimizada" if minimized else "janela restaurada")


func set_window_mode(mode: int) -> void:
	if _window_mode == mode:
		return
	_window_mode = mode
	_evaluate("modo %s" % DesktopModeManager.mode_name(mode))


func set_low_power(enabled: bool) -> void:
	if _low_power == enabled:
		return
	_low_power = enabled
	_evaluate("baixo consumo ligado" if enabled else "baixo consumo desligado")


func set_foreign_fullscreen(probe: int) -> void:
	_foreign_fullscreen = probe
	_evaluate("estado de tela cheia informado")


## Aplica um perfil a mao. Existe para os testes e para a validacao de desempenho, que
## precisam do perfil sem depender do sistema operacional.
func force_profile(profile: int, reason: String = "aplicado manualmente") -> void:
	_set_profile(profile, reason)


# --------------------------------------------------------------------------------------
# Decisao
# --------------------------------------------------------------------------------------

func _evaluate(reason: String) -> void:
	_set_profile(_decide(), reason)


## A regra, em ordem. O caso interessante e o ultimo: **baixo consumo nao derruba a janela
## em uso**. O `MVP_SPEC.md` secao 20 pede ate 60 FPS no modo ativo, com interacao; quem
## liga a opcao quer economizar enquanto o jogo esta de lado, nao ver Caramelo andando aos
## trancos enquanto brinca com ele. Por isso ela vale quando o foco esta noutro lugar.
func _decide() -> int:
	if _minimized:
		return Profile.MINIMIZED
	if _foreign_fullscreen == PlatformAdapter.Probe.YES:
		return Profile.FOREIGN_FULLSCREEN
	if _window_mode == DesktopModeManager.Mode.WALLPAPER:
		# Papel de parede e ocioso por definicao: 10 FPS, com ou sem a opcao ligada.
		return Profile.LOW_POWER
	if not _focused and _low_power:
		# Desfocado: reduzir, mas nunca fingir que ha um aplicativo em tela cheia.
		return Profile.LOW_POWER
	return Profile.NORMAL


func _set_profile(profile: int, reason: String) -> void:
	var target := get_target_fps_for(profile)
	if profile == _profile and reason == _reason:
		_apply_engine_limit(target)
		return
	_profile = profile
	_reason = reason
	_apply_engine_limit(target)
	profile_changed.emit(_profile, target, _reason)


func _apply_engine_limit(target_fps: int) -> void:
	if _apply_to_engine:
		Engine.max_fps = target_fps


func _on_settings_changed(key: String, value: Variant) -> void:
	match key:
		"low_power_mode": set_low_power(bool(value))
		"window_fps_limit":
			_window_fps_limit = int(value)
			_evaluate("limite de FPS alterado")
		"":
			if _settings != null:
				set_low_power(_settings.is_low_power_mode())


# --------------------------------------------------------------------------------------
# Leitura
# --------------------------------------------------------------------------------------

func get_profile() -> int:
	return _profile


func get_profile_name() -> String:
	return String(PROFILE_NAMES[_profile])


func get_reason() -> String:
	return _reason


func get_target_fps() -> int:
	return get_target_fps_for(_profile)


func get_target_fps_for(profile: int) -> int:
	if profile == Profile.NORMAL:
		# O limite em janela e configuravel; os demais perfis vem da secao 20 e nao mudam.
		return clampi(_window_fps_limit, 10, 60)
	return int(PROFILE_FPS.get(profile, 60))


## Intervalo minimo entre duas atualizacoes puramente visuais, em segundos. Quem desenha
## usa isto para nao reconstruir poligono a 60 Hz quando o jogo esta a 10.
func get_visual_interval() -> float:
	return 1.0 / maxf(float(get_target_fps()), 1.0)


## Contador simples de desenvolvimento: quantas atualizacoes visuais aconteceram. Nao vai
## para a interface; serve para conferir que o perfil reduz trabalho de verdade.
func count_visual_update() -> void:
	_visual_updates += 1


func get_visual_updates() -> int:
	return _visual_updates


func reset_visual_updates() -> void:
	_visual_updates = 0


## Resumo legivel para diagnostico, sem HUD permanente.
func describe() -> String:
	return "perfil %s · %d FPS · %s" % [get_profile_name(), get_target_fps(), _reason]
