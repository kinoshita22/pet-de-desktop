extends SceneTree
## Testes permanentes do HUD principal e dos menus contextuais.
##
## Executar:  godot --headless --path . --script tests/test_main_ui.gd
##
## Nenhuma espera real: o recolhimento e o toast avancam por `MainHUD.simulate`.

const STEP := 1.0 / 60.0

var _passed := 0
var _failures: Array[String] = []
var _group := ""
var _done := false
var _viewport: SubViewport


class World:
	extends RefCounted
	var main: Node
	var session: GameSession
	var hud: Control
	var food_menu: Control
	var exercise_menu: Control
	var model: ProgressionModel
	var feeding: FeedingSystem
	var exercise: ExerciseSystem
	var rest: RestSystem
	var dog: Caramelo
	var bowl: Node2D
	var hotspots: Array = []

	func _init(viewport: SubViewport) -> void:
		main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
		viewport.add_child(main)
		session = _find(main, func(n: Node) -> bool: return n is GameSession) as GameSession
		hud = _find(main, func(n: Node) -> bool: return n.is_in_group(&"main_hud")) as Control
		food_menu = _find(main, func(n: Node) -> bool: return n.is_in_group(&"food_menu")) as Control
		exercise_menu = _find(main, func(n: Node) -> bool: return n.is_in_group(&"exercise_menu")) as Control
		dog = _find(main, func(n: Node) -> bool: return n is Caramelo) as Caramelo
		bowl = _find(main, func(n: Node) -> bool: return n is FoodBowl) as Node2D
		model = session.get_model()
		feeding = session.get_feeding_system()
		exercise = session.get_exercise_system()
		rest = session.get_rest_system()
		var queue: Array[Node] = [main]
		while not queue.is_empty():
			var node: Node = queue.pop_front()
			if node is EquipmentHotspot:
				hotspots.append(node)
			for child in node.get_children():
				queue.append(child)
		dog.set_physics_process(false)
		feeding.set_process(false)
		rest.set_process(false)
		hud.set_process(false)

	static func _find(from: Node, predicate: Callable) -> Node:
		var queue: Array[Node] = [from]
		while not queue.is_empty():
			var node: Node = queue.pop_front()
			if predicate.call(node):
				return node
			for child in node.get_children():
				queue.append(child)
		return null

	func run(seconds: float) -> void:
		for _i in int(round(seconds / (1.0 / 60.0))):
			dog.simulate(1.0 / 60.0)
			hud.call("simulate", 1.0 / 60.0)

	func run_until_state(state: int, limit: float = 90.0) -> bool:
		for _i in int(round(limit / (1.0 / 60.0))):
			if dog.get_current_state() == state:
				return true
			dog.simulate(1.0 / 60.0)
			hud.call("simulate", 1.0 / 60.0)
		return dog.get_current_state() == state

	func reach_level(level: int) -> void:
		var guard := 0
		while model.get_level() < level and guard < 500:
			model.add_strength(5)
			guard += 1

	func hotspot(exercise_id: StringName) -> Node:
		for spot in hotspots:
			if spot.exercise_id == exercise_id:
				return spot
		return null

	func free_all() -> void:
		main.free()


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	root.add_child(_viewport)

	_test_startup()
	_test_attributes()
	_test_activity()
	_test_feeding()
	_test_training()
	_test_rest()
	_test_menus_and_collapse()
	_test_regression()

	_viewport.free()
	_report()
	return true


func _g(name: String) -> void:
	_group = name
	print("\n%s" % name)


func _check(condition: bool, label: String) -> bool:
	if condition:
		_passed += 1
		print("  [ OK ] " + label)
	else:
		_failures.append("%s :: %s" % [_group, label])
		print("  [FALHA] " + label)
	return condition


func _world() -> World:
	return World.new(_viewport)


# --------------------------------------------------------------------------------------
# 1-6. Inicializacao
# --------------------------------------------------------------------------------------

func _test_startup() -> void:
	_g("1-6. HUD unico, oculto, revelado ao selecionar Caramelo")
	var w := _world()
	var huds: Array = []
	var queue: Array[Node] = [w.main]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		if node.is_in_group(&"main_hud"):
			huds.append(node)
		for child in node.get_children():
			queue.append(child)
	_check(huds.size() == 1, "%d HUD na cena" % huds.size())
	_check(not w.hud.call("is_open"), "comeca oculto")
	_check(w.hud.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"fechado, o HUD nao intercepta cliques do cenario")

	var snapshot := w.model.get_snapshot()
	var state_before := w.dog.get_current_state()
	w.dog.select()
	_check(w.hud.call("is_open"), "selecionar Caramelo abre o HUD")
	_check(w.model.get_snapshot() == snapshot, "abrir nao altera atributo algum")
	_check(w.dog.get_current_state() == state_before, "abrir nao altera o estado de Caramelo")

	w.dog.select()
	w.dog.select()
	_check(w.hud.call("is_open"), "selecionar de novo mantem aberto, sem duplicar nada")

	# reconectar nao pode duplicar sinal: o toast contaria duas vezes
	w.hud.call("attach", w.session)
	w.hud.call("attach", w.session)
	var toasts: Array = []
	w.model.level_changed.connect(func(_p: int, _n: int) -> void: toasts.append(true))
	w.model.add_strength(25)
	_check(toasts.size() == 1, "conexoes nao sao duplicadas ao religar (%d)" % toasts.size())

	w.hud.call("close")
	_check(not w.hud.call("is_open"), "fecha")
	_check(w.dog.get_current_state() == state_before, "fechar nao altera a atividade")
	w.free_all()


# --------------------------------------------------------------------------------------
# 7-15. Atributos
# --------------------------------------------------------------------------------------

func _test_attributes() -> void:
	_g("7-15. Resumo dos atributos, atualizado por sinal")
	var w := _world()
	w.dog.select()
	var level: Label = w.hud.get_node("Anchor/Panel/Layout/Level")
	var energy: Label = w.hud.get_node("Anchor/Panel/Layout/Energy/Value")
	var bar: ProgressBar = w.hud.get_node("Anchor/Panel/Layout/Energy/Bar")
	var strength: Label = w.hud.get_node("Anchor/Panel/Layout/Strength/Value")
	var strength_sub: Label = w.hud.get_node("Anchor/Panel/Layout/Strength/Sub")
	var bond: Label = w.hud.get_node("Anchor/Panel/Layout/Bond/Value")
	var bond_sub: Label = w.hud.get_node("Anchor/Panel/Layout/Bond/Sub")

	_check(level.text == "Nível 1", "nivel inicial: '%s'" % level.text)
	_check(energy.text == "Energia 70/100", "energia inicial: '%s'" % energy.text)
	_check(is_equal_approx(bar.value, 70.0) and is_equal_approx(bar.max_value, 100.0),
		"barra em %.0f/%.0f" % [bar.value, bar.max_value])
	_check(strength.text == "Força 0", "forca inicial: '%s'" % strength.text)
	_check(strength_sub.text == "Próximo nível: 0/25", "progresso: '%s'" % strength_sub.text)
	_check(bond.text == "Vínculo 0", "vinculo inicial: '%s'" % bond.text)
	_check(bond_sub.text == "Próxima reação: 0/10", "proximo vinculo: '%s'" % bond_sub.text)

	var snapshot := w.model.get_snapshot()
	w.hud.call("refresh")
	_check(w.model.get_snapshot() == snapshot, "consultar nao modifica o modelo")

	w.model.restore_energy(20)
	_check(energy.text == "Energia 90/100" and is_equal_approx(bar.value, 90.0),
		"energia por sinal: '%s'" % energy.text)
	w.model.add_bond(8)
	_check(bond.text == "Vínculo 8" and bond_sub.text == "Próxima reação: 8/10",
		"vinculo por sinal: '%s' / '%s'" % [bond.text, bond_sub.text])
	w.model.add_strength(40)
	_check(strength.text == "Força 40", "forca por sinal: '%s'" % strength.text)
	_check(level.text == "Nível 2", "nivel por sinal: '%s'" % level.text)
	_check(strength_sub.text == "Próximo nível: 40/70",
		"progresso ao proximo nivel: '%s'" % strength_sub.text)

	w.model.add_bond(50)
	_check(bond_sub.text == "Todas as reações liberadas",
		"apos o ultimo limiar: '%s'" % bond_sub.text)
	w.model.add_strength(400)
	_check(level.text == "Nível 5" and strength_sub.text == "Nível máximo",
		"nivel maximo: '%s' / '%s'" % [level.text, strength_sub.text])
	w.free_all()


# --------------------------------------------------------------------------------------
# 16-22. Atividade atual
# --------------------------------------------------------------------------------------

func _test_activity() -> void:
	_g("16-22. Texto da atividade sai do estado e da reserva")
	var w := _world()
	w.dog.select()
	_check(w.hud.call("get_activity_text") == "Ocioso",
		"IDLE: '%s'" % w.hud.call("get_activity_text"))

	# caminhada autonoma difere de caminhada dirigida
	w.dog.set_random_seed(4242)
	var walked := false
	for _i in 3600:
		w.dog.simulate(STEP)
		if w.dog.get_current_state() == Caramelo.State.WALKING:
			walked = true
			break
	_check(walked and w.hud.call("get_activity_text") == "Passeando",
		"caminhada autonoma: '%s'" % w.hud.call("get_activity_text"))
	w.free_all()

	for caso in [["kibble", "feeding", "Indo comer", "Comendo"],
			["push_ups", "exercise", "Indo treinar", "Fazendo flexões"],
			["", "rest", "Indo descansar", "Descansando"]]:
		var probe := _world()
		probe.dog.select()
		match caso[1]:
			"feeding": probe.feeding.request_feeding(StringName(caso[0]))
			"exercise": probe.exercise.request_exercise(StringName(caso[0]))
			"rest": probe.rest.request_rest()
		_check(probe.hud.call("get_activity_text") == caso[2],
			"caminhando: '%s'" % probe.hud.call("get_activity_text"))
		var target := Caramelo.State.EATING if caso[1] == "feeding" \
			else (Caramelo.State.TRAINING if caso[1] == "exercise" else Caramelo.State.RESTING)
		probe.run_until_state(target)
		_check(probe.hud.call("get_activity_text") == caso[3],
			"na atividade: '%s'" % probe.hud.call("get_activity_text"))
		probe.free_all()

	var w2 := _world()
	w2.dog.select()
	w2.reach_level(3)
	w2.exercise.request_exercise(&"dumbbells")
	w2.run_until_state(Caramelo.State.TRAINING)
	_check(w2.hud.call("get_activity_text") == "Treinando com halteres",
		"estilo do exercicio: '%s'" % w2.hud.call("get_activity_text"))
	for _i in 5400:
		if w2.dog.get_current_state() == Caramelo.State.HAPPY:
			break
		w2.dog.simulate(STEP)
	_check(w2.hud.call("get_activity_text") == "Feliz",
		"HAPPY: '%s'" % w2.hud.call("get_activity_text"))

	_g("22. O texto vem de sinal, nao de consulta por quadro")
	var source := FileAccess.get_file_as_string("res://scripts/ui/main_hud.gd")
	var process_body := source.split("func _process(delta: float) -> void:")[1].split("\n\n")[0]
	_check(process_body.contains("simulate(delta)") and not process_body.contains("_refresh"),
		"_process so avanca temporizadores: %s" % process_body.strip_edges().replace("\n", " "))
	w2.free_all()


# --------------------------------------------------------------------------------------
# 23-28. Alimentacao
# --------------------------------------------------------------------------------------

func _test_feeding() -> void:
	_g("23-28. Alimentar em tres cliques")
	var w := _world()
	var feed_button: Button = w.hud.get_node("Anchor/Panel/Layout/ActionBar/FeedButton")

	w.dog.select()                                          # clique 1
	feed_button.pressed.emit()                              # clique 2
	_check(w.food_menu.call("is_open"), "o botao abre o menu existente de alimentos")
	var ids: Array = w.food_menu.call("get_item_ids")
	_check(ids.size() == 3, "%d alimentos: %s" % [ids.size(), str(ids)])

	var energy_before := w.model.get_energy()
	var button: Button = w.food_menu.call("get_button", &"kibble")
	button.pressed.emit()                                   # clique 3
	_check(w.feeding.has_pending_meal(), "a selecao chamou o sistema")
	_check(w.model.get_energy() == energy_before, "e nao o modelo: energia intacta")
	_check(not w.food_menu.call("is_open"), "menu fecha ao aceitar")

	for _i in 5400:
		if not w.feeding.has_pending_meal():
			break
		w.dog.simulate(STEP)
	_check(w.hud.call("get_toast_text").contains("energia"),
		"toast do ganho: '%s'" % w.hud.call("get_toast_text"))

	_g("26-27. Pote continua como atalho e a recarga aparece")
	w.bowl.call("select")
	_check(w.food_menu.call("is_open"), "clicar no pote abre o menu")
	_check((w.food_menu.call("get_button", &"kibble") as Button).disabled,
		"a racao aparece desabilitada, em recarga")
	_check(not (w.food_menu.call("get_button", &"chicken_rice") as Button).disabled,
		"os outros seguem habilitados")

	_g("28. Rejeicao vira mensagem")
	(w.food_menu.call("get_button", &"chicken_rice") as Button).pressed.emit()
	for _i in 5400:
		if not w.feeding.has_pending_meal():
			break
		w.dog.simulate(STEP)
	w.feeding.request_feeding(&"kibble")
	_check(w.hud.call("get_toast_text") == "Esse alimento ainda está descansando.",
		"toast de recusa: '%s'" % w.hud.call("get_toast_text"))
	w.free_all()


# --------------------------------------------------------------------------------------
# 29-37. Treino
# --------------------------------------------------------------------------------------

func _test_training() -> void:
	_g("29-35. Treinar em tres cliques")
	var w := _world()
	var train_button: Button = w.hud.get_node("Anchor/Panel/Layout/ActionBar/TrainButton")

	w.dog.select()                                          # clique 1
	train_button.pressed.emit()                             # clique 2
	_check(w.exercise_menu.call("is_open"), "o botao abre o menu de exercicios")
	var ids: Array = w.exercise_menu.call("get_item_ids")
	_check(ids.size() == 2, "%d exercicios: %s" % [ids.size(), str(ids)])
	var push: Button = w.exercise_menu.call("get_button", &"push_ups")
	var dumb: Button = w.exercise_menu.call("get_button", &"dumbbells")
	_check(not push.disabled, "flexoes habilitadas no nivel 1")
	_check(dumb.disabled, "halteres desabilitados no nivel 1")
	_check(w.exercise_menu.call("get_detail_text", &"dumbbells").contains("nível 3"),
		"e o motivo aparece: '%s'" % w.exercise_menu.call("get_detail_text", &"dumbbells"))

	_g("33. Nivel 3 libera sem reabrir a cena")
	w.reach_level(3)
	_check(not dumb.disabled, "halteres habilitados apos subir de nivel, com o menu aberto")

	_g("34. Energia insuficiente desabilita")
	w.model.try_spend_energy(w.model.get_energy() - 5)
	_check(push.disabled and dumb.disabled, "com 5 de energia, os dois ficam desabilitados")
	_check(w.exercise_menu.call("get_detail_text", &"push_ups").contains("cansado"),
		"motivo: '%s'" % w.exercise_menu.call("get_detail_text", &"push_ups"))
	w.model.restore_energy(100)
	_check(not push.disabled, "volta ao normal com energia cheia")

	var strength_before := w.model.get_strength()
	push.pressed.emit()                                     # clique 3
	_check(w.exercise.has_pending_exercise(), "a selecao chamou o ExerciseSystem")
	_check(w.model.get_strength() == strength_before, "e nao o modelo: forca intacta")
	_check(not w.exercise_menu.call("is_open"), "menu fecha ao aceitar")

	w.run_until_state(Caramelo.State.TRAINING)
	_check(w.hud.call("get_toast_text").contains("energia"),
		"toast do debito: '%s'" % w.hud.call("get_toast_text"))
	for _i in 5400:
		if not w.exercise.has_pending_exercise():
			break
		w.dog.simulate(STEP)
	# o botao apertado foi o das flexoes, entao a recompensa e +5
	_check(w.hud.call("get_toast_text") == "+5 força",
		"toast da recompensa: '%s'" % w.hud.call("get_toast_text"))
	w.free_all()

	_g("36-37. Hotspots continuam funcionando e a recusa vira mensagem")
	var w2 := _world()
	w2.dog.select()
	w2.hotspot(&"push_ups").call("select")
	_check(w2.exercise.has_pending_exercise(), "o hotspot continua pedindo o treino")
	# pedir o mesmo exercicio de novo: o bloqueio agora e a ocupacao, nao o nivel
	w2.exercise.request_exercise(&"push_ups")
	_check(w2.hud.call("get_toast_text") == "Caramelo está ocupado.",
		"toast de recusa: '%s'" % w2.hud.call("get_toast_text"))
	w2.free_all()

	var w3 := _world()
	w3.dog.select()
	w3.exercise.request_exercise(&"dumbbells")
	_check(w3.hud.call("get_toast_text") == "Halteres liberados no nível 3.",
		"recusa por nivel: '%s'" % w3.hud.call("get_toast_text"))
	w3.free_all()


# --------------------------------------------------------------------------------------
# 38-41. Descanso
# --------------------------------------------------------------------------------------

func _test_rest() -> void:
	_g("38-41. Descansar em dois cliques")
	var w := _world()
	var rest_button: Button = w.hud.get_node("Anchor/Panel/Layout/ActionBar/RestButton")

	w.dog.select()                                          # clique 1
	_check(not rest_button.disabled, "botao habilitado com Caramelo livre")
	rest_button.pressed.emit()                              # clique 2
	_check(w.dog.get_reserved_activity() == Caramelo.State.RESTING,
		"o botao chamou request_rest()")
	_check(rest_button.disabled, "com atividade reservada, o botao desabilita")

	w.run_until_state(Caramelo.State.RESTING)
	_check(w.hud.call("get_activity_text") == "Descansando",
		"status: '%s'" % w.hud.call("get_activity_text"))
	_check(w.hud.call("get_toast_text") == "Descanso iniciado.",
		"toast: '%s'" % w.hud.call("get_toast_text"))
	w.free_all()

	var w2 := _world()
	w2.dog.select()
	var rest_button2: Button = w2.hud.get_node("Anchor/Panel/Layout/ActionBar/RestButton")
	w2.exercise.request_exercise(&"push_ups")
	_check(rest_button2.disabled, "treino reservado desabilita o descanso")
	w2.run_until_state(Caramelo.State.TRAINING)
	_check(rest_button2.disabled, "durante TRAINING continua desabilitado")
	var energy_before := w2.model.get_energy()
	w2.rest.request_rest()
	_check(w2.hud.call("get_toast_text") == "Caramelo está ocupado.",
		"recusa vira mensagem: '%s'" % w2.hud.call("get_toast_text"))
	_check(w2.model.get_energy() == energy_before, "recusa nao altera energia")
	w2.free_all()


# --------------------------------------------------------------------------------------
# 42-50. Menus e recolhimento
# --------------------------------------------------------------------------------------

func _test_menus_and_collapse() -> void:
	_g("42-44. Um menu por vez")
	var w := _world()
	var feed: Button = w.hud.get_node("Anchor/Panel/Layout/ActionBar/FeedButton")
	var train: Button = w.hud.get_node("Anchor/Panel/Layout/ActionBar/TrainButton")
	w.dog.select()
	feed.pressed.emit()
	_check(w.food_menu.call("is_open") and not w.exercise_menu.call("is_open"),
		"alimentacao aberta, treino fechado")
	train.pressed.emit()
	_check(w.exercise_menu.call("is_open") and not w.food_menu.call("is_open"),
		"abrir treino fecha alimentacao")
	feed.pressed.emit()
	_check(w.food_menu.call("is_open") and not w.exercise_menu.call("is_open"),
		"abrir alimentacao fecha treino")
	w.hud.call("close")
	_check(not w.food_menu.call("is_open") and not w.exercise_menu.call("is_open"),
		"fechar o HUD fecha os menus contextuais")

	_g("45-47. Recolhimento automatico")
	w.dog.select()
	_check(is_equal_approx(w.hud.call("get_seconds_until_collapse"), 8.0),
		"contador comeca em %.1f s" % w.hud.call("get_seconds_until_collapse"))
	w.hud.call("simulate", 5.0)
	_check(w.hud.call("is_open") and w.hud.call("get_seconds_until_collapse") < 4.0,
		"aos 5 s ainda aberto, faltando %.1f s" % w.hud.call("get_seconds_until_collapse"))
	feed.pressed.emit()
	w.hud.call("simulate", 30.0)
	_check(w.hud.call("is_open"), "com menu aberto nao recolhe nem apos 30 s")
	feed.pressed.emit()                                     # fecha o menu
	_check(not w.hud.call("has_context_menu_open"), "menu fechado")
	w.hud.call("simulate", 4.0)
	_check(w.hud.call("is_open"), "4 s depois ainda aberto")
	train.pressed.emit()
	train.pressed.emit()
	_check(is_equal_approx(w.hud.call("get_seconds_until_collapse"), 8.0),
		"interagir reinicia o contador")
	w.hud.call("simulate", 8.1)
	_check(not w.hud.call("is_open"), "recolhe apos 8 s de inatividade")

	_g("Ponteiro e foco seguram o HUD aberto")
	w.dog.select()
	w.hud.call("set_pointer_inside", true)
	w.hud.call("simulate", 30.0)
	_check(w.hud.call("is_open"), "ponteiro sobre o HUD impede recolher")
	w.hud.call("set_pointer_inside", false)
	w.hud.call("simulate", 8.1)
	_check(not w.hud.call("is_open"), "ao sair, recolhe normalmente")

	_g("48. Escape fecha o menu antes do HUD")
	w.dog.select()
	feed.pressed.emit()
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	w.hud.call("_unhandled_input", escape)
	_check(not w.food_menu.call("is_open"), "escape fechou o menu")
	_check(w.hud.call("is_open"), "e o HUD continua aberto")
	w.hud.call("_unhandled_input", escape)
	_check(not w.hud.call("is_open"), "segundo escape fecha o HUD")

	_g("49-50. Toast")
	w.dog.select()
	w.feeding.request_feeding(&"pizza")
	_check(w.hud.call("get_toast_text") != "", "toast apareceu: '%s'" % w.hud.call("get_toast_text"))
	var toast: Control = w.hud.get_node("Toast")
	_check(toast.mouse_filter == Control.MOUSE_FILTER_IGNORE, "toast nao intercepta cliques")
	_check((toast.get_node("Panel") as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"nem o painel dele")
	w.feeding.request_feeding(&"lasanha")
	_check(w.hud.call("get_toast_text") != "", "uma mensagem nova substitui a anterior")
	w.hud.call("simulate", 4.0)
	_check(w.hud.call("get_toast_text") == "", "toast some por tempo simulado")
	w.free_all()


# --------------------------------------------------------------------------------------
# 52-55. Regressao
# --------------------------------------------------------------------------------------

func _test_regression() -> void:
	_g("52-53. Execucao sem interacao")
	var w := _world()
	w.dog.set_random_seed(77)
	w.run(180.0)
	_check(not w.hud.call("is_open"), "o HUD nao abre sozinho")
	_check(w.model.get_strength() == 0 and w.model.get_bond() == 0,
		"forca %d e vinculo %d intactos" % [w.model.get_strength(), w.model.get_bond()])
	_check(not w.feeding.has_pending_meal() and not w.exercise.has_pending_exercise(),
		"nenhuma atividade surgiu sozinha")
	w.free_all()

	_g("55. Nenhuma UI chama metodos mutaveis do modelo")
	var mutators := ["restore_energy", "try_spend_energy", "add_strength", "add_bond"]
	for script in ["main_hud", "exercise_menu", "food_menu", "training_feedback"]:
		var source := FileAccess.get_file_as_string("res://scripts/ui/%s.gd" % script)
		var clean := true
		for mutator in mutators:
			if source.contains(mutator):
				clean = false
		_check(clean, "%s.gd nao chama nenhum mutador do modelo" % script)

	_g("54. Um HUD, um menu de cada tipo")
	var w2 := _world()
	var counts: Dictionary = {&"main_hud": 0, &"food_menu": 0, &"exercise_menu": 0}
	var queue: Array[Node] = [w2.main]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		for group: StringName in counts:
			if node.is_in_group(group):
				counts[group] += 1
		for child in node.get_children():
			queue.append(child)
	for group: StringName in counts:
		_check(int(counts[group]) == 1, "%s: %d instancia" % [group, int(counts[group])])
	w2.free_all()


func _report() -> void:
	print("\n" + "=".repeat(70))
	if _failures.is_empty():
		print("TODOS OS TESTES PASSARAM  (%d verificacoes)" % _passed)
		quit(0)
		return
	print("FALHAS: %d de %d verificacoes" % [_failures.size(), _passed + _failures.size()])
	for failure in _failures:
		print("  - " + failure)
	quit(1)
