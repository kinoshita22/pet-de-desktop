extends Control
## Painel "Enquanto você esteve fora".
##
## Converte o relatório estruturado do `OfflineProgress` em frases. A lógica de quanto foi
## aplicado é dos sistemas; aqui só se escolhe o texto — e só de fatos reais: um ganho zero
## nunca vira linha.
##
## Enquanto está aberto, bloqueia cliques no mundo, mas **não pausa o jogo**.

const GROUP := &"offline_summary"
const TITLE_FONT := 18
const LINE_FONT := 14
const BUTTON_FONT := 15
const PANEL_WIDTH := 360.0

var _lines: PackedStringArray = PackedStringArray()

@onready var _anchor: Control = $Anchor
@onready var _panel: PanelContainer = $Anchor/Panel
@onready var _layout: VBoxContainer = $Anchor/Panel/Layout
@onready var _title: Label = $Anchor/Panel/Layout/Title
@onready var _body: VBoxContainer = $Anchor/Panel/Layout/Body
@onready var _close_button: Button = $Anchor/Panel/Layout/CloseButton


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	# Fechado, não intercepta nada; aberto, segura os cliques do mundo.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_close_button.pressed.connect(close)
	get_viewport().size_changed.connect(_reposition)
	var session := GameSession.find_in(get_tree())
	if session != null:
		session.offline_progress_applied.connect(show_report)


## Monta e exibe o painel. Não aparece quando não há nada real a contar.
func show_report(report: Dictionary) -> void:
	_lines = build_lines(report)
	if _lines.is_empty():
		return
	for child in _body.get_children():
		child.queue_free()
	for line in _lines:
		var label := Label.new()
		label.text = line
		# Sem quebra automatica: as frases sao curtas e um rotulo que quebra sozinho
		# reporta altura minima calculada numa largura ainda nao definida, o que estoura
		# a altura do painel inteiro.
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_body.add_child(label)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_reposition()
	show()
	_close_button.grab_focus()


func close() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_open() -> bool:
	return visible


func get_lines() -> PackedStringArray:
	return _lines


## Frases derivadas do relatório. Estática para que os testes as verifiquem sem cena.
static func build_lines(report: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	if report.is_empty() or not bool(report.get("has_events", false)):
		return lines

	if String(report.get("recovery_message", "")) != "":
		lines.append("O save principal não pôde ser lido. O backup foi recuperado.")

	if bool(report.get("clock_went_backwards", false)):
		lines.append("O relógio do sistema retrocedeu; nenhum progresso offline foi aplicado.")
		return lines

	var elapsed := float(report.get("elapsed_seconds", 0.0))
	if elapsed > 0.0:
		var suffix := " (o máximo considerado)" if bool(report.get("capped", false)) else ""
		lines.append("Você ficou fora por %s%s." % [OfflineProgress.format_duration(elapsed), suffix])

	var meal := String(report.get("meal_completed", ""))
	if meal != "":
		var parts: Array[String] = []
		var meal_energy := int(report.get("energy_restored", 0))
		var bond := int(report.get("bond_gained", 0))
		if bond > 0:
			parts.append("%d de vínculo" % bond)
		lines.append("Caramelo terminou de comer %s%s." % [meal,
			" e ganhou %s" % " e ".join(parts) if not parts.is_empty() else ""])

	var exercise := String(report.get("exercise_completed", ""))
	var strength := int(report.get("strength_gained", 0))
	if exercise != "" and strength > 0:
		lines.append("Caramelo terminou o exercício %s e ganhou %d de força." % [exercise, strength])

	var energy := int(report.get("energy_restored", 0))
	if energy > 0:
		lines.append("Caramelo recuperou %d de energia." % energy)

	var foods: Array = report.get("foods_ready", [])
	if foods.size() == 1:
		lines.append("Um alimento ficou disponível novamente.")
	elif foods.size() > 1:
		lines.append("%d alimentos ficaram disponíveis novamente." % foods.size())

	var resumed := String(report.get("activity_resumed", ""))
	if resumed != "":
		lines.append("Caramelo continuou de onde parou.")

	return lines


func _reposition() -> void:
	if _anchor == null:
		return
	var viewport_size := get_viewport_rect().size
	var factor := UiScale.factor_for(self)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH * factor, 0.0)
	_title.add_theme_font_size_override("font_size", roundi(TITLE_FONT * factor))
	_close_button.add_theme_font_size_override("font_size", roundi(BUTTON_FONT * factor))
	_close_button.custom_minimum_size = Vector2(0.0, 32.0 * factor)
	_layout.add_theme_constant_override("separation", roundi(8 * factor))
	_body.add_theme_constant_override("separation", roundi(4 * factor))
	for child in _body.get_children():
		(child as Label).add_theme_font_size_override("font_size", roundi(LINE_FONT * factor))
	UiScale.scale_stylebox(_panel, factor, 14.0, 2.0, 10, 2)
	var panel_size := _panel.get_combined_minimum_size()
	_panel.size = panel_size
	_anchor.position = (viewport_size - panel_size) * 0.5
