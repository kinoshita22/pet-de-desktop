extends Control
## Painel de configuracoes do desktop, aberto pelo HUD.
##
## Segue as regras dos outros menus contextuais: comeca oculto, encosta na borda superior
## do painel do HUD, um de cada vez, Escape fecha. **Nao altera atributo nem atividade** —
## ele le e escreve preferencias, e pede ao `DesktopModeManager` que troque de modo.
##
## Duas escolhas mexem no sistema de quem joga: papel de parede e inicializar com o
## sistema. As duas pedem uma confirmacao simples — o botao vira "Confirmar?" e so a
## segunda batida vale —, e nenhuma delas vem ligada de fabrica.

const MENU_GROUP := &"settings_panel"
const PANEL_WIDTH := 320.0
const MARGIN_BOTTOM := 28.0
const TITLE_FONT := 16
const BUTTON_FONT := 14
const LABEL_FONT := 12
const NOTE_FONT := 11
const BUTTON_HEIGHT := 28.0
const SEPARATION := 8
## Tempo que uma confirmacao fica de pe antes de o botao voltar ao texto normal.
const CONFIRM_SECONDS := 4.0

const MODE_LABELS: Dictionary = {
	DesktopModeManager.Mode.WINDOWED: "Janela",
	DesktopModeManager.Mode.BORDERLESS: "Janela sem bordas",
	DesktopModeManager.Mode.WALLPAPER: "Papel de parede",
}

const TOGGLE_LABELS: Dictionary = {
	"quiet_mode": "Modo silencioso",
	"low_power_mode": "Baixo consumo fora de uso",
	"wallpaper_interaction": "Interagir no papel de parede (indisponível)",
	"launch_at_login": "Iniciar com o sistema",
}

signal quit_requested()

var _settings: SettingsManager
var _modes: DesktopModeManager
var _autostart: AutostartService
var _anchor_rect := Rect2()
var _mode_buttons: Dictionary = {}
var _toggles: Dictionary = {}
var _fps_buttons: Dictionary = {}
var _pending_confirm := ""
var _confirm_seconds := 0.0

@onready var _anchor: Control = $Anchor
@onready var _panel: PanelContainer = $Anchor/Panel
@onready var _layout: VBoxContainer = $Anchor/Panel/Layout
@onready var _title: Label = $Anchor/Panel/Layout/Title
@onready var _display_label: Label = $Anchor/Panel/Layout/DisplayLabel
@onready var _display_modes: VBoxContainer = $Anchor/Panel/Layout/DisplayModes
@onready var _platform_note: Label = $Anchor/Panel/Layout/PlatformNote
@onready var _toggle_box: VBoxContainer = $Anchor/Panel/Layout/Toggles
@onready var _fps_row: HBoxContainer = $Anchor/Panel/Layout/FpsRow
@onready var _fps_label: Label = $Anchor/Panel/Layout/FpsRow/FpsLabel
@onready var _actions: VBoxContainer = $Anchor/Panel/Layout/Actions
@onready var _back_button: Button = $Anchor/Panel/Layout/Actions/BackToWindowButton
@onready var _quit_button: Button = $Anchor/Panel/Layout/Actions/QuitButton
@onready var _close_button: Button = $Anchor/Panel/Layout/CloseButton


func _ready() -> void:
	add_to_group(MENU_GROUP)
	hide()
	_close_button.pressed.connect(close)
	_back_button.pressed.connect(_on_back_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	get_viewport().size_changed.connect(_reposition)
	_build_controls()
	var session := GameSession.find_in(get_tree())
	if session != null:
		attach(session.get_settings_manager(), session.get_mode_manager(),
			session.get_autostart_service())


func attach(settings: SettingsManager, modes: DesktopModeManager,
		autostart: AutostartService) -> void:
	_settings = settings
	_modes = modes
	_autostart = autostart
	if _settings != null and not _settings.settings_changed.is_connected(_on_settings_changed):
		_settings.settings_changed.connect(_on_settings_changed)
	if _modes != null and not _modes.mode_changed.is_connected(_on_mode_changed):
		_modes.mode_changed.connect(_on_mode_changed)
	_refresh()


func _process(delta: float) -> void:
	simulate(delta)


## Avanca o tempo da confirmacao pendente. Publico para os testes nao esperarem de verdade.
func simulate(delta: float) -> void:
	if _pending_confirm.is_empty() or delta <= 0.0:
		return
	_confirm_seconds -= delta
	if _confirm_seconds <= 0.0:
		_clear_confirmation()


# --------------------------------------------------------------------------------------
# Abertura
# --------------------------------------------------------------------------------------

func set_anchor_rect(rect: Rect2) -> void:
	_anchor_rect = rect
	if visible:
		_reposition()


func open() -> void:
	_refresh()
	_reposition()
	show()


func close() -> void:
	_clear_confirmation()
	hide()


func is_open() -> bool:
	return visible


# --------------------------------------------------------------------------------------
# Construcao
# --------------------------------------------------------------------------------------

func _build_controls() -> void:
	for mode: int in [DesktopModeManager.Mode.WINDOWED, DesktopModeManager.Mode.BORDERLESS,
			DesktopModeManager.Mode.WALLPAPER]:
		var button := Button.new()
		button.name = "Mode%d" % mode
		button.text = String(MODE_LABELS[mode])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_mode_pressed.bind(mode))
		_display_modes.add_child(button)
		_mode_buttons[mode] = button

	for key: String in ["quiet_mode", "low_power_mode", "wallpaper_interaction", "launch_at_login"]:
		var toggle := CheckBox.new()
		toggle.name = key
		toggle.text = String(TOGGLE_LABELS[key])
		toggle.toggled.connect(_on_toggle_changed.bind(key))
		_toggle_box.add_child(toggle)
		_toggles[key] = toggle

	for fps: int in SettingsManager.FPS_CHOICES:
		var button := Button.new()
		button.name = "Fps%d" % fps
		button.text = "%d" % fps
		button.pressed.connect(_on_fps_pressed.bind(fps))
		_fps_row.add_child(button)
		_fps_buttons[fps] = button


# --------------------------------------------------------------------------------------
# Leitura da configuracao
# --------------------------------------------------------------------------------------

func _refresh() -> void:
	if _settings == null:
		return
	var current := DesktopModeManager.mode_from_name(_settings.get_display_mode())
	if _modes != null:
		current = _modes.get_mode()
	for mode: int in _mode_buttons:
		var button := _mode_buttons[mode] as Button
		var available := _modes == null or _modes.is_mode_available(mode)
		button.disabled = not available or mode == current
		button.button_pressed = mode == current
		if not available:
			button.tooltip_text = "Indisponível nesta plataforma"
		elif mode == current:
			button.tooltip_text = "Modo atual"
		else:
			button.tooltip_text = "Mudar para %s" % String(MODE_LABELS[mode])

	(_toggles["quiet_mode"] as CheckBox).set_pressed_no_signal(_settings.is_quiet_mode())
	(_toggles["low_power_mode"] as CheckBox).set_pressed_no_signal(_settings.is_low_power_mode())
	(_toggles["wallpaper_interaction"] as CheckBox).set_pressed_no_signal(
		_settings.is_wallpaper_interactive())
	var autostart_toggle := _toggles["launch_at_login"] as CheckBox
	autostart_toggle.set_pressed_no_signal(_settings.is_launch_at_login())
	var autostart_available := _autostart != null and _autostart.is_available()
	autostart_toggle.disabled = not autostart_available
	autostart_toggle.tooltip_text = "Disponível na versão exportada para Windows" \
		if not autostart_available else "Criar um atalho na pasta Inicializar do usuário"

	# Click-through seletivo nao existe neste MVP, e o papel de parede nao recebe cliques.
	# Oferecer o interruptor ligado seria prometer o que o jogo nao faz: ele fica sempre
	# desabilitado, com o motivo escrito, ate que a interacao exista de verdade.
	var wallpaper_toggle := _toggles["wallpaper_interaction"] as CheckBox
	wallpaper_toggle.disabled = true
	wallpaper_toggle.tooltip_text = \
		"No papel de parede o jogo não recebe cliques: volte para janela para interagir."

	var limit := int(_settings.get_value("window_fps_limit", 60))
	for fps: int in _fps_buttons:
		var button := _fps_buttons[fps] as Button
		button.disabled = fps == limit
		button.button_pressed = fps == limit

	_platform_note.text = _platform_text()
	_back_button.disabled = _modes != null and _modes.get_mode() == DesktopModeManager.Mode.WINDOWED


func _platform_text() -> String:
	if _modes == null:
		return ""
	if _modes.is_mode_available(DesktopModeManager.Mode.WALLPAPER):
		return "Ctrl+Shift+W volta para a janela a qualquer momento."
	var platform := _modes.get_adapter().get_platform_name() if _modes.get_adapter() != null else OS.get_name()
	return "Papel de parede: só no Windows (aqui: %s)." % platform


# --------------------------------------------------------------------------------------
# Acoes
# --------------------------------------------------------------------------------------

func _on_mode_pressed(mode: int) -> void:
	if _modes == null:
		return
	# Papel de parede muda como o jogo aparece na maquina inteira: pede confirmacao.
	if mode == DesktopModeManager.Mode.WALLPAPER and not _confirmed("mode_wallpaper",
			_mode_buttons[mode] as Button):
		return
	_clear_confirmation()
	_modes.request_mode(mode)
	_refresh()


func _on_toggle_changed(pressed: bool, key: String) -> void:
	if _settings == null:
		return
	if key == "launch_at_login" and pressed:
		# Ligar o autostart escreve na pasta Inicializar: nunca acontece num clique so.
		if not _confirmed("launch_at_login", _toggles[key] as CheckBox):
			(_toggles[key] as CheckBox).set_pressed_no_signal(false)
			return
		_clear_confirmation()
		if _autostart != null:
			var result := _autostart.set_enabled(true)
			if not bool(result["ok"]):
				(_toggles[key] as CheckBox).set_pressed_no_signal(false)
				return
		_settings.set_value(key, true)
		_refresh()
		return
	if key == "launch_at_login" and not pressed and _autostart != null:
		_autostart.set_enabled(false)
	_settings.set_value(key, pressed)
	_refresh()


func _on_fps_pressed(fps: int) -> void:
	if _settings == null:
		return
	_settings.set_value("window_fps_limit", fps)
	_refresh()


func _on_back_pressed() -> void:
	if _modes != null:
		_modes.return_to_windowed()
	_refresh()


func _on_quit_pressed() -> void:
	if not _confirmed("quit", _quit_button):
		return
	_clear_confirmation()
	quit_requested.emit()


func _on_settings_changed(_key: String, _value: Variant) -> void:
	if visible:
		_refresh()


func _on_mode_changed(_previous: int, _new_mode: int) -> void:
	_refresh()


# --------------------------------------------------------------------------------------
# Confirmacao simples
# --------------------------------------------------------------------------------------

## Primeira batida arma a confirmacao e muda o texto; a segunda executa. A confirmacao
## expira sozinha, para nao ficar armada de uma sessao para outra.
func _confirmed(action: String, control: Control) -> bool:
	if _pending_confirm == action:
		return true
	_clear_confirmation()
	_pending_confirm = action
	_confirm_seconds = CONFIRM_SECONDS
	if control is Button:
		(control as Button).set_meta("texto_original", (control as Button).text)
		(control as Button).text = "Confirmar?"
	elif control is CheckBox:
		(control as CheckBox).set_meta("texto_original", (control as CheckBox).text)
		(control as CheckBox).text = "Confirmar?"
	return false


func _clear_confirmation() -> void:
	_pending_confirm = ""
	_confirm_seconds = 0.0
	for control: Node in [_quit_button] + _mode_buttons.values() + _toggles.values():
		if control.has_meta("texto_original"):
			control.set("text", control.get_meta("texto_original"))
			control.remove_meta("texto_original")


func has_pending_confirmation() -> bool:
	return not _pending_confirm.is_empty()


# --------------------------------------------------------------------------------------
# Leitura para testes
# --------------------------------------------------------------------------------------

func get_mode_button(mode: int) -> Button:
	return _mode_buttons.get(mode) as Button


func get_toggle(key: String) -> CheckBox:
	return _toggles.get(key) as CheckBox


func get_fps_button(fps: int) -> Button:
	return _fps_buttons.get(fps) as Button


func get_platform_note() -> String:
	return _platform_note.text


# --------------------------------------------------------------------------------------
# Posicionamento
# --------------------------------------------------------------------------------------

func _reposition() -> void:
	if _anchor == null or _panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var factor := UiScale.factor_for(self)
	_apply_scale(factor)
	var panel_size := _panel.get_combined_minimum_size()
	_panel.size = panel_size
	if _anchor_rect.size != Vector2.ZERO:
		_anchor.position = Vector2(
			clampf(_anchor_rect.position.x, 8.0 * factor,
				maxf(viewport_size.x - panel_size.x - 8.0 * factor, 8.0 * factor)),
			maxf(_anchor_rect.position.y - panel_size.y - 8.0 * factor, 8.0 * factor))
		return
	_anchor.position = Vector2(
		(viewport_size.x - panel_size.x) * 0.5,
		maxf(viewport_size.y - panel_size.y - MARGIN_BOTTOM * factor, 8.0 * factor))


func _apply_scale(factor: float) -> void:
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH * factor, 0.0)
	_title.add_theme_font_size_override("font_size", roundi(TITLE_FONT * factor))
	_layout.add_theme_constant_override("separation", roundi(SEPARATION * factor))
	_display_modes.add_theme_constant_override("separation", roundi(4 * factor))
	_toggle_box.add_theme_constant_override("separation", roundi(4 * factor))
	_actions.add_theme_constant_override("separation", roundi(4 * factor))
	_fps_row.add_theme_constant_override("separation", roundi(6 * factor))
	for label in [_display_label, _fps_label]:
		label.add_theme_font_size_override("font_size", roundi(LABEL_FONT * factor))
	_platform_note.add_theme_font_size_override("font_size", roundi(NOTE_FONT * factor))
	for button: Node in _mode_buttons.values() + _fps_buttons.values() \
			+ [_back_button, _quit_button, _close_button]:
		(button as Button).add_theme_font_size_override("font_size", roundi(BUTTON_FONT * factor))
		(button as Button).custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT * factor)
	for toggle: Node in _toggles.values():
		(toggle as CheckBox).add_theme_font_size_override("font_size", roundi(LABEL_FONT * factor))
	UiScale.scale_stylebox(_panel, factor)
