extends SceneTree
## Testes permanentes do sistema de alimentacao.
##
## Executar:  godot --headless --path . --script tests/test_feeding_system.gd
##
## Nenhuma espera real: as duracoes de atividade avancam por `Caramelo.simulate` e as
## recargas por `FeedingSystem.simulate`, ambas em laco.

const STEP := 1.0 / 60.0
const MAIN_SCENE := "res://scenes/main/main.tscn"
const MENU_SCENE := "res://scenes/ui/food_menu.tscn"
const FOOD_POINT := Vector2(941.6, 792.1)

var _passed := 0
var _failures: Array[String] = []
var _group := ""
var _done := false
var _viewport: SubViewport


class Spy:
	extends RefCounted
	var events: Array = []
	func on_requested(id: StringName) -> void: events.append(["requested", String(id)])
	func on_rejected(id: StringName, reason: int) -> void:
		events.append(["rejected", String(id), FeedingSystem.rejection_name(reason)])
	func on_completed(id: StringName, energy: int, bond: int) -> void:
		events.append(["completed", String(id), energy, bond])
	func on_cooldown(id: StringName, remaining: float) -> void:
		events.append(["cooldown", String(id), remaining])
	func on_energy(p: int, n: int) -> void: events.append(["energy", p, n])
	func on_bond(p: int, n: int) -> void: events.append(["bond", p, n])
	func on_unlock(id: StringName) -> void: events.append(["unlock", String(id)])
	func names() -> Array:
		var out: Array = []
		for e in events:
			out.append(e[0])
		return out
	func count(kind: String) -> int:
		return names().count(kind)


## Cena principal viva num SubViewport, com o cachorro sob controle do teste.
class World:
	extends RefCounted
	var main: Node
	var session: GameSession
	var feeding: FeedingSystem
	var model: ProgressionModel
	var dog: Caramelo
	var menu: Control
	var bowl: Node2D
	var exercise: ExerciseSystem

	func _init(viewport: SubViewport) -> void:
		main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
		viewport.add_child(main)
		session = _find(main, func(n: Node) -> bool: return n is GameSession) as GameSession
		feeding = _find(main, func(n: Node) -> bool: return n is FeedingSystem) as FeedingSystem
		dog = _find(main, func(n: Node) -> bool: return n is Caramelo) as Caramelo
		bowl = _find(main, func(n: Node) -> bool: return n is FoodBowl) as Node2D
		menu = _find(main, func(n: Node) -> bool: return n.is_in_group(&"food_menu")) as Control
		exercise = _find(main, func(n: Node) -> bool: return n is ExerciseSystem) as ExerciseSystem
		model = session.get_model()
		dog.set_physics_process(false)
		feeding.set_process(false)

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
			feeding.simulate(1.0 / 60.0)

	## Avanca ate a refeicao pendente terminar, ou desiste.
	func finish_meal(limit: float = 60.0) -> bool:
		for _i in int(round(limit / (1.0 / 60.0))):
			if not feeding.has_pending_meal():
				return true
			dog.simulate(1.0 / 60.0)
			if not feeding.has_pending_meal():
				return true   # para antes de consumir recarga no quadro da conclusao
			feeding.simulate(1.0 / 60.0)
		return not feeding.has_pending_meal()

	func free_all() -> void:
		main.free()


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	root.add_child(_viewport)

	_test_request()
	_test_completion()
	_test_cooldowns()
	_test_dog_states()
	_test_scene_and_ui()
	_test_mutual_exclusion()

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
# 1-10. Solicitacao
# --------------------------------------------------------------------------------------

func _test_request() -> void:
	_g("1-6. Pedido aceito e pedidos recusados")
	var w := _world()
	var spy := Spy.new()
	w.feeding.feeding_requested.connect(spy.on_requested)
	w.feeding.feeding_rejected.connect(spy.on_rejected)
	w.model.energy_changed.connect(spy.on_energy)
	w.model.bond_changed.connect(spy.on_bond)

	_check(w.feeding.is_configured(), "sistema configurado pela GameSession")
	_check(w.feeding.request_feeding(&"kibble"), "alimento valido aceito")
	_check(spy.count("requested") == 1, "feeding_requested emitido uma vez (%d)" % spy.count("requested"))
	_check(w.model.get_energy() == 70 and w.model.get_bond() == 0,
		"aceite nao altera atributos: energia %d, vinculo %d" % [w.model.get_energy(), w.model.get_bond()])
	_check(spy.count("energy") == 0 and spy.count("bond") == 0, "nenhum sinal do modelo no aceite")
	_check(w.feeding.get_pending_food() == &"kibble", "refeicao pendente registrada")

	_check(not w.feeding.request_feeding(&"chicken_rice"), "segunda refeicao pendente recusada")
	_check(spy.events[-1][2] == "MEAL_PENDING", "codigo = %s" % spy.events[-1][2])
	_check(w.feeding.get_pending_food() == &"kibble", "pendencia original intacta")

	_g("7. Pedido aceito direciona Caramelo ao FoodPoint")
	_check(w.dog.get_current_state() == Caramelo.State.WALKING,
		"Caramelo caminhando (%s)" % Caramelo.state_name(w.dog.get_current_state()))
	_check(w.dog.get_destination().distance_to(FOOD_POINT) < 0.01,
		"destino = %s (FoodPoint %s)" % [w.dog.get_destination(), FOOD_POINT])
	w.finish_meal()
	w.free_all()

	_g("2. ID desconhecido")
	var w2 := _world()
	var spy2 := Spy.new()
	w2.feeding.feeding_rejected.connect(spy2.on_rejected)
	_check(not w2.feeding.request_feeding(&"pizza"), "ID inexistente recusado")
	_check(spy2.events[-1][2] == "UNKNOWN_FOOD", "codigo = %s" % spy2.events[-1][2])
	_check(not w2.feeding.has_pending_meal(), "nenhuma pendencia criada")
	_check(w2.dog.get_current_state() == Caramelo.State.IDLE, "Caramelo nao se moveu")
	_check(w2.model.get_energy() == 70 and w2.model.get_bond() == 0, "atributos intactos")

	_g("10. Cliques repetidos nao criam multiplas refeicoes")
	var accepted := 0
	for _i in 12:
		if w2.feeding.request_feeding(&"kibble"):
			accepted += 1
	_check(accepted == 1, "12 cliques -> %d refeicao(oes)" % accepted)
	_check(w2.feeding.get_pending_food() == &"kibble", "uma unica pendencia")
	w2.finish_meal()
	_check(w2.model.get_energy() == 90, "energia aplicada uma vez: %d" % w2.model.get_energy())
	w2.free_all()

	_g("3. Alimento em recarga")
	var w3 := _world()
	_check(w3.feeding.request_feeding(&"kibble"), "primeira racao aceita")
	w3.finish_meal()
	var spy3 := Spy.new()
	w3.feeding.feeding_rejected.connect(spy3.on_rejected)
	_check(not w3.feeding.request_feeding(&"kibble"), "racao em recarga recusada")
	_check(spy3.events[-1][2] == "ON_COOLDOWN", "codigo = %s" % spy3.events[-1][2])
	_check(w3.feeding.request_feeding(&"cheese_bread"), "outro alimento continua disponivel")
	w3.finish_meal()
	w3.free_all()


# --------------------------------------------------------------------------------------
# 11-21. Conclusao
# --------------------------------------------------------------------------------------

func _test_completion() -> void:
	_g("11-14, 20-21. Recompensa so na conclusao, uma unica vez")
	var w := _world()
	var spy := Spy.new()
	w.feeding.feeding_completed.connect(spy.on_completed)
	w.model.energy_changed.connect(spy.on_energy)
	w.model.bond_changed.connect(spy.on_bond)

	w.feeding.request_feeding(&"chicken_rice")
	w.run(0.3)
	_check(w.model.get_energy() == 70 and w.model.get_bond() == 0,
		"durante a caminhada nada e aplicado (%d / %d)" % [w.model.get_energy(), w.model.get_bond()])
	_check(w.dog.get_current_state() == Caramelo.State.WALKING, "ainda caminhando")

	var reached := false
	for _i in 3600:
		w.dog.simulate(STEP)
		w.feeding.simulate(STEP)
		if w.dog.get_current_state() == Caramelo.State.EATING:
			reached = true
			break
	_check(reached, "chegou e entrou em EATING")
	_check(w.model.get_energy() == 70, "entrar em EATING ainda nao paga (%d)" % w.model.get_energy())

	w.finish_meal()
	# frango com arroz: +35 energia, +2 vinculo (data/foods.json)
	_check(w.model.get_energy() == 100, "energia 70 + 35 com teto = %d" % w.model.get_energy())
	_check(w.model.get_bond() == 2, "vinculo = %d" % w.model.get_bond())
	_check(spy.count("completed") == 1, "feeding_completed uma vez (%d)" % spy.count("completed"))
	var completed: Array = spy.events.filter(func(e: Array) -> bool: return e[0] == "completed")[0]
	_check(completed[1] == "chicken_rice", "alimento informado = %s" % completed[1])
	_check(int(completed[2]) == 30, "energy_applied = %d (ganho efetivo apos clamp)" % int(completed[2]))
	_check(int(completed[3]) == 2, "bond_applied = %d" % int(completed[3]))
	_check(not w.feeding.has_pending_meal(), "pendencia limpa")

	_g("15-17. Sinais duplicados e conclusoes inesperadas sao ignorados")
	var energy_before := w.model.get_energy()
	var bond_before := w.model.get_bond()
	w.dog.activity_completed.emit(Caramelo.State.EATING)
	w.dog.activity_completed.emit(Caramelo.State.EATING)
	_check(w.model.get_energy() == energy_before and w.model.get_bond() == bond_before,
		"conclusao sem pendencia nao paga nada")
	_check(spy.count("completed") == 1, "nenhum feeding_completed extra")

	w.feeding.request_feeding(&"kibble")
	w.dog.activity_completed.emit(Caramelo.State.TRAINING)
	w.dog.activity_completed.emit(Caramelo.State.RESTING)
	_check(w.feeding.get_pending_food() == &"kibble",
		"conclusao de TRAINING/RESTING nao conclui a refeicao")
	_check(w.model.get_bond() == bond_before, "vinculo intacto")
	w.finish_meal()
	_check(spy.count("completed") == 2, "a refeicao real concluiu (%d no total)" % spy.count("completed"))
	w.free_all()

	_g("18-19. Energia cheia: sem energy_changed, mas com vinculo e recarga")
	var w2 := _world()
	var spy2 := Spy.new()
	w2.model.energy_changed.connect(spy2.on_energy)
	w2.model.bond_changed.connect(spy2.on_bond)
	w2.model.unlock_granted.connect(spy2.on_unlock)
	w2.feeding.feeding_completed.connect(spy2.on_completed)
	w2.feeding.cooldown_changed.connect(spy2.on_cooldown)
	w2.model.restore_energy(30)                      # energia cheia em 100
	spy2.events.clear()
	w2.feeding.request_feeding(&"cheese_bread")      # +15 energia, +3 vinculo
	w2.finish_meal()
	_check(spy2.count("energy") == 0, "nenhum energy_changed com energia cheia")
	_check(w2.model.get_energy() == 100, "energia continua 100")
	_check(w2.model.get_bond() == 3, "vinculo creditado integralmente: %d" % w2.model.get_bond())
	_check(spy2.count("completed") == 1, "refeicao concluida mesmo assim")
	_check(w2.feeding.get_remaining_cooldown(&"cheese_bread") > 0.0, "recarga iniciada mesmo assim")

	_g("Ordem obrigatoria dos efeitos")
	var w3 := _world()
	var spy3 := Spy.new()
	w3.model.energy_changed.connect(spy3.on_energy)
	w3.model.bond_changed.connect(spy3.on_bond)
	w3.model.unlock_granted.connect(spy3.on_unlock)
	w3.feeding.feeding_completed.connect(spy3.on_completed)
	w3.feeding.cooldown_changed.connect(spy3.on_cooldown)
	for _i in 9:                                     # leva o vinculo a 9 antes da refeicao
		w3.model.add_bond(1)
	spy3.events.clear()
	w3.feeding.request_feeding(&"kibble")            # +1 vinculo cruza o limiar 10
	w3.finish_meal()
	_check(spy3.names() == ["energy", "bond", "unlock", "completed", "cooldown"],
		"ordem = %s" % str(spy3.names()))
	w3.free_all()
	w2.free_all()


# --------------------------------------------------------------------------------------
# 22-30. Recargas
# --------------------------------------------------------------------------------------

func _test_cooldowns() -> void:
	_g("22-28. Recargas independentes, vindas do JSON")
	var w := _world()
	_check(w.feeding.get_remaining_cooldown(&"kibble") == 0.0, "sem recarga no inicio")
	w.feeding.request_feeding(&"kibble")
	_check(w.feeding.get_remaining_cooldown(&"kibble") == 0.0,
		"a recarga nao comeca na solicitacao (%.1f)" % w.feeding.get_remaining_cooldown(&"kibble"))
	w.finish_meal()
	_check(is_equal_approx(w.feeding.get_remaining_cooldown(&"kibble"), 300.0),
		"recarga de 300 s vinda do JSON: %.1f" % w.feeding.get_remaining_cooldown(&"kibble"))
	_check(w.feeding.get_remaining_cooldown(&"chicken_rice") == 0.0
		and w.feeding.get_remaining_cooldown(&"cheese_bread") == 0.0,
		"os outros dois continuam sem recarga")
	_check(w.feeding.is_available(&"chicken_rice"), "frango disponivel")
	_check(not w.feeding.is_available(&"kibble"), "racao indisponivel")

	w.feeding.simulate(120.0)
	_check(is_equal_approx(w.feeding.get_remaining_cooldown(&"kibble"), 180.0),
		"apos 120 s restam %.1f s" % w.feeding.get_remaining_cooldown(&"kibble"))

	w.feeding.request_feeding(&"chicken_rice")
	w.finish_meal()
	_check(is_equal_approx(w.feeding.get_remaining_cooldown(&"chicken_rice"), 900.0),
		"frango com recarga propria de 900 s")
	_check(w.feeding.get_remaining_cooldown(&"kibble") < 180.0,
		"a recarga da racao seguiu correndo: %.1f" % w.feeding.get_remaining_cooldown(&"kibble"))

	w.feeding.simulate(1000.0)
	_check(w.feeding.get_remaining_cooldown(&"kibble") == 0.0, "recarga chega exatamente a zero")
	_check(w.feeding.get_remaining_cooldown(&"chicken_rice") == 0.0, "e nunca fica negativa")
	_check(w.feeding.is_available(&"kibble") and w.feeding.is_available(&"chicken_rice"),
		"ambos voltam a ficar disponiveis")
	w.free_all()

	_g("29. Avanco simulado e deterministico")
	var trace_a := _cooldown_trace()
	var trace_b := _cooldown_trace()
	_check(trace_a == trace_b, "duas execucoes produzem a mesma serie: %s" % str(trace_a.slice(0, 4)))

	_g("30. cooldown_changed nao e emitido a cada quadro")
	var w2 := _world()
	var spy := Spy.new()
	w2.feeding.cooldown_changed.connect(spy.on_cooldown)
	w2.feeding.request_feeding(&"kibble")
	w2.finish_meal()
	spy.events.clear()
	for _i in 600:                                   # 10 s a 60 quadros por segundo
		w2.feeding.simulate(STEP)
	_check(spy.count("cooldown") <= 11,
		"600 quadros -> %d sinais (um por segundo, no maximo)" % spy.count("cooldown"))
	_check(spy.count("cooldown") >= 9, "mas atualiza de fato: %d sinais" % spy.count("cooldown"))
	w2.free_all()


func _cooldown_trace() -> Array:
	var w := _world()
	w.feeding.request_feeding(&"kibble")
	w.finish_meal()
	var trace: Array = []
	for _i in 20:
		w.feeding.simulate(7.5)
		trace.append(snappedf(w.feeding.get_remaining_cooldown(&"kibble"), 0.001))
	w.free_all()
	return trace


# --------------------------------------------------------------------------------------
# 31-37. Estado de Caramelo
# --------------------------------------------------------------------------------------

func _test_dog_states() -> void:
	_g("31-34. activity_completed")
	var w := _world()
	var seen: Array = []
	w.dog.activity_completed.connect(func(activity: int) -> void: seen.append(Caramelo.state_name(activity)))

	w.dog.request_state(Caramelo.State.EATING)
	_check(seen.is_empty(), "entrar em EATING nao emite activity_completed")
	_check(not w.dog.is_interruptible(), "EATING continua nao interrompivel")
	_check(not w.dog.request_state(Caramelo.State.IDLE), "comando durante EATING recusado")
	_check(seen.is_empty(), "transicao recusada nao emite activity_completed")
	w.run(Caramelo.EATING_DURATION + 0.2)
	_check(seen == ["EATING"], "conclusao natural emitiu uma vez: %s" % str(seen))
	w.run(Caramelo.HAPPY_DURATION + 0.2)
	_check(seen == ["EATING"], "HAPPY nao emite activity_completed: %s" % str(seen))

	_g("35. Pedidos durante TRAINING sao recusados")
	w.dog.request_state(Caramelo.State.TRAINING)
	var spy := Spy.new()
	w.feeding.feeding_rejected.connect(spy.on_rejected)
	_check(not w.feeding.request_feeding(&"kibble"), "alimentacao recusada durante TRAINING")
	_check(spy.events[-1][2] == "DOG_BUSY", "codigo = %s" % spy.events[-1][2])
	_check(not w.feeding.has_pending_meal(), "nenhuma pendencia")
	w.run(Caramelo.TRAINING_DURATION + Caramelo.HAPPY_DURATION + 0.4)
	_check(w.model.get_energy() == 70 and w.model.get_bond() == 0,
		"treino nao concede nada: energia %d, vinculo %d" % [w.model.get_energy(), w.model.get_bond()])
	w.free_all()

	_g("36. Pedido iniciado em RESTING segue so transicoes validas")
	var w2 := _world()
	var states: Array = []
	w2.dog.state_changed.connect(func(_p: int, n: int) -> void: states.append(Caramelo.state_name(n)))
	w2.dog.request_state(Caramelo.State.RESTING)
	states.clear()
	_check(w2.feeding.request_feeding(&"kibble"), "pedido aceito a partir de RESTING")
	# A matriz do MVP_SPEC nao liga RESTING a WALKING: Caramelo se levanta antes.
	_check(states == ["IDLE", "WALKING"], "caminho percorrido = %s" % str(states))
	_check(w2.finish_meal(), "a refeicao conclui normalmente")
	_check(w2.model.get_energy() == 90, "energia = %d" % w2.model.get_energy())
	w2.free_all()


# --------------------------------------------------------------------------------------
# 38-47. Cena e interface
# --------------------------------------------------------------------------------------

func _test_scene_and_ui() -> void:
	_g("38-40, 45. Pote e cena")
	var w := _world()
	var bowls: Array = []
	var systems: Array = []
	var queue: Array[Node] = [w.main]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		if node is FoodBowl:
			bowls.append(node)
		if node is FeedingSystem:
			systems.append(node)
		for child in node.get_children():
			queue.append(child)
	_check(bowls.size() == 1, "%d pote na cena" % bowls.size())
	_check(systems.size() == 1, "%d sistema de alimentacao na cena" % systems.size())

	var bowl: Node2D = bowls[0]
	var distance := bowl.position.distance_to(FOOD_POINT)
	_check(distance > 20.0 and distance < 120.0,
		"pote a %.0f px do FoodPoint: alinhado, mas Caramelo nao fica em cima" % distance)
	var polygon: PackedVector2Array = (w.main.get_node(
		"World/Backyard/WorldBounds/WalkableCollision") as CollisionPolygon2D).polygon
	_check(Geometry2D.is_point_in_polygon(bowl.position, polygon),
		"pote dentro da area caminhavel %s" % bowl.position)
	_check(bowl.get_parent().name == &"PropsLayer", "pote em PropsLayer (pai = %s)" % bowl.get_parent().name)

	_g("Pote emite sinal ao ser selecionado, e o menu responde")
	var opened: Array = []
	w.feeding.bowl_selected.connect(func() -> void: opened.append(true))
	bowl.call("select")
	_check(opened.size() == 1,
		"selecionar o pote emitiu bowl_selected uma vez (%d)" % opened.size())

	_g("41-43. Menu")
	_check(w.menu != null, "menu presente em Interface")
	var ids: Array = w.menu.call("get_item_ids")
	_check(ids.size() == 3, "%d alimentos no menu: %s" % [ids.size(), str(ids)])
	var config_ids: Array = []
	for food: Dictionary in w.feeding.get_foods():
		config_ids.append(StringName(food["id"]))
	_check(ids == config_ids, "os alimentos sao exatamente os do JSON")
	w.menu.call("close")
	_check(not w.menu.call("is_open"), "menu comeca/fica oculto")

	w.menu.call("open")
	_check(w.menu.call("is_open"), "menu abre")
	var button: Button = w.menu.call("get_button", &"kibble")
	_check(button != null and not button.disabled, "botao da racao habilitado")
	_check(button.text == "Racao", "nome de exibicao do JSON: '%s'" % button.text)

	_g("8-9. Menu fecha no aceite e continua utilizavel na recusa")
	button.pressed.emit()
	_check(not w.menu.call("is_open"), "menu fechou apos pedido aceito")
	_check(w.feeding.has_pending_meal(), "refeicao a caminho")
	w.menu.call("open")
	button.pressed.emit()
	_check(w.menu.call("is_open"), "menu continua aberto apos recusa")
	w.finish_meal()

	_g("43. Botao em recarga fica desabilitado, os outros nao")
	w.menu.call("open")
	_check(w.menu.call("get_button", &"kibble").disabled, "racao desabilitada durante a recarga")
	_check(not w.menu.call("get_button", &"chicken_rice").disabled, "frango continua habilitado")
	_check(not w.menu.call("get_button", &"cheese_bread").disabled, "pao de queijo continua habilitado")
	w.feeding.simulate(400.0)
	_check(not w.menu.call("get_button", &"kibble").disabled, "racao volta ao fim da recarga")

	_g("Menu oculto ou removido nao quebra o sistema")
	w.menu.call("close")
	w.menu.hide()
	_check(w.feeding.request_feeding(&"chicken_rice"), "pedido funciona com o menu oculto")
	w.finish_meal()
	var detached: Node = w.menu
	detached.get_parent().remove_child(detached)
	_check(w.feeding.request_feeding(&"cheese_bread"), "pedido funciona com o menu fora da arvore")
	w.finish_meal()
	detached.free()

	_g("44. A interface nao altera o modelo diretamente")
	var source := FileAccess.get_file_as_string("res://scripts/ui/food_menu.gd")
	for forbidden in ["restore_energy", "add_bond", "add_strength", "ProgressionModel", "get_model"]:
		_check(not source.contains(forbidden), "food_menu.gd nao menciona '%s'" % forbidden)
	w.free_all()

	_g("46. Execucao normal nao concede recompensa sem acao do jogador")
	var w2 := _world()
	w2.run(150.0)
	_check(w2.model.get_energy() == 70, "energia continua 70 (%d)" % w2.model.get_energy())
	_check(w2.model.get_bond() == 0, "vinculo continua 0 (%d)" % w2.model.get_bond())
	_check(w2.model.get_strength() == 0 and w2.model.get_level() == 1, "forca e nivel intactos")
	_check(not w2.feeding.has_pending_meal(), "nenhuma refeicao surgiu sozinha")
	w2.free_all()


# --------------------------------------------------------------------------------------
# Exclusao mutua com o treino (Etapa 7)
# --------------------------------------------------------------------------------------

func _test_mutual_exclusion() -> void:
	_g("Exclusao mutua: um treino em curso bloqueia a alimentacao")
	var w := _world()
	var spy := Spy.new()
	w.feeding.feeding_rejected.connect(spy.on_rejected)
	_check(w.exercise.request_exercise(&"push_ups"), "treino aceito")
	_check(w.dog.has_reserved_activity(), "Caramelo com atividade reservada")
	_check(not w.feeding.request_feeding(&"kibble"),
		"alimentacao recusada enquanto ele caminha para o equipamento")
	_check(spy.events[-1][2] == "ACTIVITY_RESERVED", "codigo = %s" % spy.events[-1][2])
	_check(not w.feeding.has_pending_meal(), "nenhuma refeicao pendente foi criada")
	_check(w.model.get_energy() == 70, "energia intacta: %d" % w.model.get_energy())

	for _i in 5400:
		if w.dog.get_current_state() == Caramelo.State.TRAINING:
			break
		w.dog.simulate(STEP)
	_check(w.dog.get_current_state() == Caramelo.State.TRAINING, "treino em execucao")
	_check(not w.feeding.request_feeding(&"chicken_rice"), "alimentacao recusada durante TRAINING")
	_check(spy.events[-1][2] == "DOG_BUSY", "codigo = %s" % spy.events[-1][2])
	_check(w.exercise.get_pending_exercise() == &"push_ups", "o treino nao foi substituido")

	for _i in 5400:
		if not w.exercise.has_pending_exercise():
			break
		w.dog.simulate(STEP)
	_check(not w.dog.has_reserved_activity(), "reserva liberada ao terminar o treino")
	_check(w.feeding.request_feeding(&"kibble"), "alimentacao volta a ser aceita")
	_check(w.finish_meal(), "e a refeicao conclui normalmente")
	_check(w.model.get_bond() == 1, "vinculo creditado: %d" % w.model.get_bond())

	_g("Exclusao mutua: uma refeicao em curso bloqueia o treino")
	var w2 := _world()
	var spy2 := Spy.new()
	w2.exercise.exercise_rejected.connect(func(id: StringName, reason: int) -> void:
		spy2.events.append(["rejected", String(id), ExerciseSystem.rejection_name(reason)]))
	_check(w2.feeding.request_feeding(&"kibble"), "refeicao aceita")
	_check(not w2.exercise.request_exercise(&"push_ups"), "treino recusado a caminho do pote")
	_check(spy2.events[-1][2] == "ACTIVITY_RESERVED", "codigo = %s" % spy2.events[-1][2])
	_check(w2.feeding.get_pending_food() == &"kibble", "refeicao intacta")

	var reached := false
	for _i in 5400:
		if w2.dog.get_current_state() == Caramelo.State.EATING:
			reached = true
			break
		w2.dog.simulate(STEP)
	_check(reached, "Caramelo chegou ao pote")
	_check(not w2.exercise.request_exercise(&"push_ups"), "treino recusado durante EATING")
	_check(spy2.events[-1][2] == "DOG_BUSY", "codigo = %s" % spy2.events[-1][2])
	_check(not w2.exercise.has_pending_exercise(), "nenhum treino em fila")
	_check(w2.finish_meal(), "refeicao conclui")
	_check(w2.model.get_strength() == 0, "nenhuma forca concedida: %d" % w2.model.get_strength())
	w2.free_all()
	w.free_all()


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
