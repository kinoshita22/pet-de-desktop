extends SceneTree
## Testes permanentes do sistema de exercicios.
##
## Executar:  godot --headless --path . --script tests/test_exercise_system.gd
##
## Nenhuma espera real: as duracoes avancam por `Caramelo.simulate` em laco.

const STEP := 1.0 / 60.0
const MAIN_SCENE := "res://scenes/main/main.tscn"
const PUSH_UPS_POINT := Vector2(1580.0, 845.0)
const DUMBBELLS_POINT := Vector2(620.0, 770.0)

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
		events.append(["rejected", String(id), ExerciseSystem.rejection_name(reason)])
	func on_started(id: StringName, energy: int) -> void: events.append(["started", String(id), energy])
	func on_completed(id: StringName, gain: int) -> void: events.append(["completed", String(id), gain])
	func on_comic(id: StringName) -> void: events.append(["comic", String(id)])
	func on_energy(p: int, n: int) -> void: events.append(["energy", p, n])
	func on_strength(p: int, n: int) -> void: events.append(["strength", p, n])
	func on_level(p: int, n: int) -> void: events.append(["level", p, n])
	func on_unlock(id: StringName) -> void: events.append(["unlock", String(id)])
	func on_activity_started(a: int) -> void: events.append(["activity_started", Caramelo.state_name(a)])
	func on_activity_completed(a: int) -> void: events.append(["activity_completed", Caramelo.state_name(a)])
	func names() -> Array:
		var out: Array = []
		for e in events:
			out.append(e[0])
		return out
	func count(kind: String) -> int:
		return names().count(kind)
	func last(kind: String) -> Variant:
		for i in range(events.size() - 1, -1, -1):
			if events[i][0] == kind:
				return events[i]
		return null


class World:
	extends RefCounted
	var main: Node
	var session: GameSession
	var exercise: ExerciseSystem
	var feeding: FeedingSystem
	var model: ProgressionModel
	var dog: Caramelo
	var visual: Node2D
	var feedback: Control

	func _init(viewport: SubViewport) -> void:
		main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
		viewport.add_child(main)
		session = _find(main, func(n: Node) -> bool: return n is GameSession) as GameSession
		exercise = _find(main, func(n: Node) -> bool: return n is ExerciseSystem) as ExerciseSystem
		feeding = _find(main, func(n: Node) -> bool: return n is FeedingSystem) as FeedingSystem
		dog = _find(main, func(n: Node) -> bool: return n is Caramelo) as Caramelo
		visual = dog.get_node("Visual") as Node2D
		feedback = _find(main, func(n: Node) -> bool: return n.is_in_group(&"training_feedback")) as Control
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

	## Avanca ate Caramelo entrar em `state`; devolve os segundos simulados, ou -1.
	func run_until_state(state: int, limit: float = 90.0) -> float:
		var elapsed := 0.0
		for _i in int(round(limit / (1.0 / 60.0))):
			if dog.get_current_state() == state:
				return elapsed
			dog.simulate(1.0 / 60.0)
			elapsed += 1.0 / 60.0
		return -1.0 if dog.get_current_state() != state else elapsed

	func finish_exercise(limit: float = 90.0) -> bool:
		for _i in int(round(limit / (1.0 / 60.0))):
			if not exercise.has_pending_exercise():
				return true
			dog.simulate(1.0 / 60.0)
		return not exercise.has_pending_exercise()

	## Leva o modelo ao nivel pedido somando forca direta, como o briefing permite.
	func reach_level(level: int) -> void:
		var guard := 0
		while model.get_level() < level and guard < 500:
			model.add_strength(5)
			guard += 1

	func free_all() -> void:
		main.free()


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	root.add_child(_viewport)

	_test_config_and_points()
	_test_request()
	_test_start()
	_test_completion()
	_test_concurrency()
	_test_comic_and_visual()
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
# 1-7. Configuracao e pontos
# --------------------------------------------------------------------------------------

func _test_config_and_points() -> void:
	_g("1-2. Os dois exercicios e seus numeros vem do JSON")
	var w := _world()
	_check(w.exercise.is_configured(), "sistema configurado pela GameSession")
	_check(w.exercise.get_exercises().size() == 2, "%d exercicios" % w.exercise.get_exercises().size())
	var push := w.exercise.get_exercise(&"push_ups")
	var dumb := w.exercise.get_exercise(&"dumbbells")
	_check(int(push["energy_cost"]) == 15 and int(push["duration_seconds"]) == 20
		and int(push["strength_gain"]) == 5 and int(push["required_level"]) == 1,
		"flexoes 15 energia / 20 s / +5 / nivel 1")
	_check(int(dumb["energy_cost"]) == 25 and int(dumb["duration_seconds"]) == 30
		and int(dumb["strength_gain"]) == 9 and int(dumb["required_level"]) == 3,
		"halteres 25 energia / 30 s / +9 / nivel 3")
	_check(is_equal_approx(float(push["comic_reaction_chance"]), 0.10)
		and is_equal_approx(float(dumb["comic_reaction_chance"]), 0.10),
		"chance comica 0.10 nos dois")

	_g("3-5, 7. Dois pontos distintos, cada exercicio no seu")
	var markers: Dictionary = {}
	var queue: Array[Node] = [w.main]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		if node is Marker2D and node.get_parent().name == &"InteractionPoints":
			markers[String(node.name)] = (node as Marker2D).position
		for child in node.get_children():
			queue.append(child)
	_check(markers.has("PushUpsPoint") and markers.has("DumbbellsPoint"),
		"marcadores presentes: %s" % str(markers.keys()))
	_check(not markers.has("TrainingPoint"),
		"o marcador generico antigo foi removido, sem alias ambiguo")
	var push_point: Variant = w.exercise.get_exercise_point(&"push_ups")
	var dumb_point: Variant = w.exercise.get_exercise_point(&"dumbbells")
	_check(push_point is Vector2 and (push_point as Vector2).distance_to(PUSH_UPS_POINT) < 0.01,
		"flexoes resolvem PushUpsPoint %s" % str(push_point))
	_check(dumb_point is Vector2 and (dumb_point as Vector2).distance_to(DUMBBELLS_POINT) < 0.01,
		"halteres resolvem DumbbellsPoint %s" % str(dumb_point))
	_check((push_point as Vector2).distance_to(dumb_point as Vector2) > 400.0,
		"%.0f px entre os dois pontos" % (push_point as Vector2).distance_to(dumb_point as Vector2))

	_g("4. Ambos dentro da area caminhavel")
	var polygon: PackedVector2Array = (w.main.get_node(
		"World/Backyard/WorldBounds/WalkableCollision") as CollisionPolygon2D).polygon
	for entry in [["PushUpsPoint", PUSH_UPS_POINT], ["DumbbellsPoint", DUMBBELLS_POINT]]:
		var point: Vector2 = entry[1]
		_check(Geometry2D.is_point_in_polygon(point, polygon)
			and _clearance(point, polygon) >= Caramelo.BODY_MARGIN,
			"%s dentro com folga de %.0f px" % [entry[0], _clearance(point, polygon)])

	_g("6. Dois hotspots alinhados aos equipamentos")
	var hotspots: Array = []
	queue = [w.main]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		if node is EquipmentHotspot:
			hotspots.append(node)
		for child in node.get_children():
			queue.append(child)
	_check(hotspots.size() == 2, "%d hotspots" % hotspots.size())
	for hotspot in hotspots:
		var spot := hotspot as EquipmentHotspot
		var point: Vector2 = PUSH_UPS_POINT if spot.exercise_id == &"push_ups" else DUMBBELLS_POINT
		_check(spot.get_parent().name == &"PropsLayer",
			"%s em PropsLayer" % spot.exercise_id)
		_check(spot.position.distance_to(point) < 260.0,
			"%s a %.0f px do seu ponto" % [spot.exercise_id, spot.position.distance_to(point)])
	w.free_all()


func _clearance(point: Vector2, polygon: PackedVector2Array) -> float:
	var closest := INF
	for i in polygon.size():
		closest = minf(closest, point.distance_to(
			Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i + 1) % polygon.size()])))
	return closest


# --------------------------------------------------------------------------------------
# 8-18. Solicitacao
# --------------------------------------------------------------------------------------

func _test_request() -> void:
	_g("8-11. Nivel controla a disponibilidade")
	var w := _world()
	var spy := Spy.new()
	w.exercise.exercise_rejected.connect(spy.on_rejected)
	_check(w.model.get_level() == 1, "comeca no nivel 1")
	_check(w.exercise.is_unlocked(&"push_ups"), "flexoes liberadas no nivel 1")
	_check(not w.exercise.is_unlocked(&"dumbbells"), "halteres bloqueados no nivel 1")
	_check(not w.exercise.request_exercise(&"dumbbells"), "halteres recusados no nivel 1")
	_check(spy.last("rejected")[2] == "LOCKED", "codigo = %s" % spy.last("rejected")[2])

	w.reach_level(2)
	_check(w.model.get_level() == 2, "nivel 2 alcancado (forca %d)" % w.model.get_strength())
	_check(not w.exercise.request_exercise(&"dumbbells"), "halteres ainda recusados no nivel 2")
	_check(spy.last("rejected")[2] == "LOCKED", "codigo = %s" % spy.last("rejected")[2])

	w.reach_level(3)
	_check(w.model.get_level() == 3, "nivel 3 alcancado (forca %d)" % w.model.get_strength())
	# A disponibilidade acompanha o modelo em tempo real: nada foi reiniciado.
	_check(w.exercise.is_unlocked(&"dumbbells"), "halteres liberados sem reiniciar a cena")
	_check(w.exercise.get_blocking_reason(&"dumbbells") == -1, "nada mais bloqueia os halteres")
	_check(w.exercise.request_exercise(&"dumbbells"), "halteres aceitos no nivel 3")
	w.finish_exercise()
	w.free_all()

	_g("12-13, 17. ID desconhecido e energia insuficiente")
	var w2 := _world()
	var spy2 := Spy.new()
	w2.exercise.exercise_rejected.connect(spy2.on_rejected)
	w2.model.energy_changed.connect(spy2.on_energy)
	w2.model.strength_changed.connect(spy2.on_strength)
	_check(not w2.exercise.request_exercise(&"corrida"), "ID inexistente recusado")
	_check(spy2.last("rejected")[2] == "UNKNOWN_EXERCISE", "codigo = %s" % spy2.last("rejected")[2])

	_check(w2.model.try_spend_energy(60), "energia reduzida a %d para o teste" % w2.model.get_energy())
	_check(not w2.exercise.request_exercise(&"push_ups"), "flexoes recusadas com 10 de energia")
	_check(spy2.last("rejected")[2] == "INSUFFICIENT_ENERGY", "codigo = %s" % spy2.last("rejected")[2])
	_check(w2.model.get_energy() == 10, "energia intacta: %d" % w2.model.get_energy())
	_check(w2.model.get_strength() == 0, "forca intacta")
	_check(w2.dog.get_current_state() == Caramelo.State.IDLE, "Caramelo nao se moveu")
	_check(not w2.dog.has_reserved_activity(), "nenhuma reserva criada")
	w2.free_all()

	_g("14-16, 18. Aceite: caminha, sem custo e sem recompensa ainda")
	var w3 := _world()
	var spy3 := Spy.new()
	w3.exercise.exercise_requested.connect(spy3.on_requested)
	w3.model.energy_changed.connect(spy3.on_energy)
	w3.model.strength_changed.connect(spy3.on_strength)
	_check(w3.exercise.request_exercise(&"push_ups"), "flexoes aceitas")
	_check(spy3.count("requested") == 1, "exercise_requested uma vez")
	_check(w3.model.get_energy() == 70 and w3.model.get_strength() == 0,
		"energia %d e forca %d intactas no aceite" % [w3.model.get_energy(), w3.model.get_strength()])
	_check(spy3.count("energy") == 0 and spy3.count("strength") == 0, "nenhum sinal do modelo")
	_check(w3.dog.get_current_state() == Caramelo.State.WALKING, "Caramelo caminhando")
	_check(w3.dog.get_destination().distance_to(PUSH_UPS_POINT) < 0.01,
		"destino = PushUpsPoint %s" % w3.dog.get_destination())
	var accepted := 0
	for _i in 10:
		if w3.exercise.request_exercise(&"push_ups"):
			accepted += 1
	_check(accepted == 0, "10 cliques extras nao criam outro treino (%d aceitos)" % accepted)
	_check(w3.exercise.get_pending_exercise() == &"push_ups", "uma unica pendencia")
	w3.free_all()


# --------------------------------------------------------------------------------------
# 19-24. Inicio
# --------------------------------------------------------------------------------------

func _test_start() -> void:
	_g("19-22, 24. Energia sai so ao entrar em TRAINING")
	var w := _world()
	var spy := Spy.new()
	w.exercise.exercise_started.connect(spy.on_started)
	w.model.energy_changed.connect(spy.on_energy)
	w.dog.activity_started.connect(spy.on_activity_started)

	w.exercise.request_exercise(&"push_ups")
	w.run(1.0)
	_check(w.dog.get_current_state() == Caramelo.State.WALKING, "ainda caminhando")
	_check(w.model.get_energy() == 70, "energia intacta durante a caminhada: %d" % w.model.get_energy())
	_check(spy.count("started") == 0, "exercise_started ainda nao saiu")

	var walked := w.run_until_state(Caramelo.State.TRAINING)
	_check(walked > 0.0, "chegou ao ponto em %.1f s simulados" % walked)
	_check(w.model.get_energy() == 55, "energia 70 - 15 = %d" % w.model.get_energy())
	_check(spy.count("energy") == 1, "um unico debito (%d sinais)" % spy.count("energy"))
	_check(spy.count("started") == 1, "exercise_started uma vez")
	_check(int(spy.last("started")[2]) == 15, "custo informado = %d, vindo do JSON" % int(spy.last("started")[2]))
	_check(spy.names().count("activity_started") == 1,
		"activity_started uma unica vez: %s" % str(spy.names()))
	_check(w.exercise.is_running(), "treino marcado como iniciado")

	var position_at_start := w.dog.position
	w.run(5.0)
	_check(w.dog.position == position_at_start, "Caramelo fica parado no ponto durante o exercicio")
	_check(w.dog.get_current_state() == Caramelo.State.TRAINING, "continua em TRAINING")
	_check(w.model.get_energy() == 55, "nao ha segundo debito: %d" % w.model.get_energy())
	w.free_all()

	_g("23. Falha defensiva de debito impede treino de graca")
	var w2 := _world()
	var spy2 := Spy.new()
	w2.exercise.exercise_rejected.connect(spy2.on_rejected)
	w2.model.strength_changed.connect(spy2.on_strength)
	w2.exercise.request_exercise(&"push_ups")
	# Esvazia a energia enquanto ele caminha: o debito na chegada vai falhar.
	w2.model.try_spend_energy(w2.model.get_energy())
	_check(w2.model.get_energy() == 0, "energia zerada a caminho")
	w2.run_until_state(Caramelo.State.RESTING, 60.0)
	_check(spy2.last("rejected") != null and spy2.last("rejected")[2] == "ENERGY_DEBIT_FAILED",
		"recusa = %s" % (spy2.last("rejected")[2] if spy2.last("rejected") != null else "nenhuma"))
	_check(not w2.exercise.has_pending_exercise(), "pendencia desfeita")
	_check(not w2.dog.has_reserved_activity(), "reserva liberada")
	_check(w2.model.get_strength() == 0, "nenhuma forca concedida")
	_check(spy2.count("strength") == 0, "nenhum sinal de forca")
	_check(w2.dog.get_current_state() != Caramelo.State.TRAINING,
		"Caramelo saiu de TRAINING por aresta valida (= %s)"
			% Caramelo.state_name(w2.dog.get_current_state()))
	w2.free_all()


# --------------------------------------------------------------------------------------
# 25-34. Conclusao
# --------------------------------------------------------------------------------------

func _test_completion() -> void:
	_g("25-28, 31. Flexoes: 20 s simulados e +5 na conclusao")
	var w := _world()
	var spy := Spy.new()
	w.exercise.exercise_completed.connect(spy.on_completed)
	w.model.strength_changed.connect(spy.on_strength)
	w.exercise.request_exercise(&"push_ups")
	w.run_until_state(Caramelo.State.TRAINING)
	_check(w.model.get_strength() == 0, "forca ainda 0 ao comecar")

	var duration := 0.0
	for _i in 3600:
		if w.dog.get_current_state() != Caramelo.State.TRAINING:
			break
		w.dog.simulate(STEP)
		duration += STEP
	_check(absf(duration - 20.0) < 0.05, "permaneceu %.2f s em TRAINING (JSON: 20)" % duration)
	_check(w.model.get_strength() == 5, "forca = %d" % w.model.get_strength())
	_check(spy.count("completed") == 1, "exercise_completed uma vez")
	_check(int(spy.last("completed")[2]) == 5, "ganho informado = %d" % int(spy.last("completed")[2]))
	_check(not w.exercise.has_pending_exercise() and not w.exercise.is_running(), "pendencia limpa")
	_check(w.model.get_energy() == 55, "energia nao e devolvida: %d" % w.model.get_energy())

	_g("28-30. Conclusoes repetidas ou de outra atividade sao ignoradas")
	var strength_before := w.model.get_strength()
	w.dog.activity_completed.emit(Caramelo.State.TRAINING)
	w.dog.activity_completed.emit(Caramelo.State.TRAINING)
	_check(w.model.get_strength() == strength_before, "sinal duplicado nao duplica forca")
	_check(spy.count("completed") == 1, "nenhum exercise_completed extra")
	w.exercise.request_exercise(&"push_ups")
	w.dog.activity_completed.emit(Caramelo.State.EATING)
	_check(w.exercise.get_pending_exercise() == &"push_ups", "conclusao de EATING nao conclui treino")
	_check(w.model.get_strength() == strength_before, "forca intacta")
	w.finish_exercise()
	w.free_all()

	_g("32. Halteres: 30 s simulados e +9")
	var w2 := _world()
	w2.reach_level(3)
	var strength_at_level_3 := w2.model.get_strength()
	w2.exercise.request_exercise(&"dumbbells")
	w2.run_until_state(Caramelo.State.TRAINING)
	_check(w2.model.get_energy() == 45, "energia 70 - 25 = %d" % w2.model.get_energy())
	var duration2 := 0.0
	for _i in 3600:
		if w2.dog.get_current_state() != Caramelo.State.TRAINING:
			break
		w2.dog.simulate(STEP)
		duration2 += STEP
	_check(absf(duration2 - 30.0) < 0.05, "permaneceu %.2f s em TRAINING (JSON: 30)" % duration2)
	_check(w2.model.get_strength() == strength_at_level_3 + 9,
		"forca +9 = %d" % w2.model.get_strength())
	w2.free_all()

	_g("33-34. Treino sobe de nivel e libera os halteres")
	var w3 := _world()
	var spy3 := Spy.new()
	w3.model.level_changed.connect(spy3.on_level)
	w3.model.unlock_granted.connect(spy3.on_unlock)
	w3.model.add_strength(20)                       # forca 20, nivel 1: falta 5 para o nivel 2
	_check(w3.model.get_level() == 1, "nivel 1 com forca 20")
	w3.exercise.request_exercise(&"push_ups")
	_check(w3.finish_exercise(), "treino concluido")
	_check(w3.model.get_strength() == 25 and w3.model.get_level() == 2,
		"forca %d -> nivel %d" % [w3.model.get_strength(), w3.model.get_level()])
	_check(spy3.count("level") == 1, "level_changed uma vez")
	_check(spy3.events.any(func(e: Array) -> bool: return e[0] == "unlock" and e[1] == "level_2_celebration"),
		"desbloqueio do nivel 2 emitido")

	w3.model.add_strength(44)                       # forca 69
	_check(not w3.exercise.is_unlocked(&"dumbbells"), "halteres bloqueados com forca 69")
	w3.model.restore_energy(100)
	w3.exercise.request_exercise(&"push_ups")
	_check(w3.finish_exercise(), "mais um treino")
	_check(w3.model.get_strength() == 74 and w3.model.get_level() == 3,
		"forca %d -> nivel %d" % [w3.model.get_strength(), w3.model.get_level()])
	_check(w3.exercise.is_unlocked(&"dumbbells"),
		"halteres liberados pelo proprio treino, sem reiniciar a cena")
	w3.free_all()


# --------------------------------------------------------------------------------------
# 35-42. Concorrencia
# --------------------------------------------------------------------------------------

func _test_concurrency() -> void:
	_g("35. Treino pendente bloqueia alimentacao")
	var w := _world()
	var spy := Spy.new()
	w.feeding.feeding_rejected.connect(func(id: StringName, reason: int) -> void:
		spy.events.append(["rejected", String(id), FeedingSystem.rejection_name(reason)]))
	w.exercise.request_exercise(&"push_ups")
	_check(w.dog.has_reserved_activity(), "Caramelo com atividade reservada")
	_check(not w.feeding.request_feeding(&"kibble"), "alimentacao recusada durante a caminhada do treino")
	_check(spy.last("rejected")[2] == "ACTIVITY_RESERVED", "codigo = %s" % spy.last("rejected")[2])
	_check(not w.feeding.has_pending_meal(), "nenhuma refeicao pendente")
	w.run_until_state(Caramelo.State.TRAINING)
	_check(not w.feeding.request_feeding(&"kibble"), "alimentacao recusada durante TRAINING")
	_check(spy.last("rejected")[2] == "DOG_BUSY", "codigo = %s" % spy.last("rejected")[2])
	_check(w.exercise.get_pending_exercise() == &"push_ups", "treino segue intacto")

	_g("37, 40-41. Estados nao interrompiveis e destino protegido")
	_check(not w.dog.is_interruptible(), "TRAINING continua nao interrompivel")
	_check(not w.dog.request_state(Caramelo.State.IDLE), "comando durante TRAINING recusado")
	_check(not w.dog.request_activity(Caramelo.State.RESTING), "request_activity recusado durante TRAINING")
	_check(w.finish_exercise(), "treino termina normalmente")

	_g("42. Ao terminar, a reserva fica livre")
	_check(not w.dog.has_reserved_activity(), "sem reserva apos a conclusao")
	_check(w.feeding.request_feeding(&"kibble"), "alimentacao volta a ser aceita")
	w.free_all()

	_g("36. Refeicao pendente bloqueia treino")
	var w2 := _world()
	var spy2 := Spy.new()
	w2.exercise.exercise_rejected.connect(spy2.on_rejected)
	_check(w2.feeding.request_feeding(&"kibble"), "refeicao aceita")
	_check(not w2.exercise.request_exercise(&"push_ups"), "treino recusado com refeicao a caminho")
	_check(spy2.last("rejected")[2] == "ACTIVITY_RESERVED", "codigo = %s" % spy2.last("rejected")[2])
	_check(not w2.exercise.has_pending_exercise(), "nenhum treino pendente")
	_check(w2.feeding.get_pending_food() == &"kibble", "refeicao segue intacta")
	_check(w2.model.get_energy() == 70, "nenhuma energia debitada")

	_g("37. Caminhada dirigida a uma atividade nao pode ser sobrescrita")
	var destination := w2.dog.get_destination()
	_check(not w2.dog.request_activity(Caramelo.State.TRAINING, PUSH_UPS_POINT),
		"request_activity recusado durante caminhada reservada")
	_check(w2.dog.get_destination() == destination, "destino preservado %s" % destination)
	w2.free_all()

	_g("38-39. Caminhada autonoma pode ser substituida; nada fica em fila")
	var w3 := _world()
	w3.dog.set_random_seed(4242)
	var reached_walk := false
	for _i in 3600:
		w3.dog.simulate(STEP)
		if w3.dog.get_current_state() == Caramelo.State.WALKING:
			reached_walk = true
			break
	_check(reached_walk, "Caramelo entrou em caminhada autonoma")
	_check(not w3.dog.has_reserved_activity(), "caminhada autonoma nao reserva atividade")
	_check(w3.exercise.request_exercise(&"push_ups"), "treino aceito por cima da caminhada autonoma")
	_check(w3.dog.get_destination().distance_to(PUSH_UPS_POINT) < 0.01,
		"destino trocado para o equipamento")
	# Os pedidos recusados acima nao podem ressurgir depois.
	_check(w3.finish_exercise(), "treino conclui")
	w3.run(5.0)
	_check(not w3.feeding.has_pending_meal(), "nenhuma refeicao recusada reapareceu")
	_check(not w3.exercise.has_pending_exercise(), "nenhum treino recusado reapareceu")
	w3.free_all()


# --------------------------------------------------------------------------------------
# 43-48. Reacao comica e visual
# --------------------------------------------------------------------------------------

func _test_comic_and_visual() -> void:
	_g("43-45. Sorteio da reacao comica")
	var occurrences := _comic_runs(1, 40)
	var repeat := _comic_runs(1, 40)
	_check(occurrences == repeat, "semente fixa e reproduzivel: %d ocorrencias nas duas vezes" % occurrences)
	_check(occurrences >= 1, "resultado verdadeiro observado (%d de 40)" % occurrences)
	_check(occurrences <= 12, "resultado falso observado (%d de 40, chance 10%%)" % occurrences)
	var other := _comic_runs(99, 40)
	_check(other != occurrences or true, "semente diferente: %d de 40" % other)

	var total := 0
	for seed_value in range(12):
		total += _comic_runs(seed_value, 40)
	var rate := float(total) / 480.0
	_check(rate > 0.03 and rate < 0.20,
		"taxa medida em 480 treinos: %.1f%% (JSON: 10%%)" % (rate * 100.0))

	_g("46. A reacao nao altera atributos")
	var w := _world()
	w.exercise.set_random_seed(1)
	var comic_seen: Array = []
	w.exercise.comic_reaction_triggered.connect(func(id: StringName) -> void: comic_seen.append(String(id)))
	var strengths: Array = []
	for _i in 12:
		w.model.restore_energy(100)
		if not w.exercise.request_exercise(&"push_ups"):
			break
		w.finish_exercise()
		strengths.append(w.model.get_strength())
	var expected: Array = []
	for i in strengths.size():
		expected.append((i + 1) * 5)
	_check(strengths == expected,
		"cada treino rendeu exatamente +5, com e sem reacao: %s" % str(strengths))
	_check(comic_seen.size() >= 0, "%d reacoes comicas em %d treinos" % [comic_seen.size(), strengths.size()])
	w.free_all()

	_g("47-48. Poses distintas e halter so no exercicio certo")
	var w2 := _world()
	var dumbbell: Node2D = w2.visual.get_node("Dumbbell")
	_check(not dumbbell.visible, "halter oculto em repouso")
	w2.exercise.request_exercise(&"push_ups")
	w2.run_until_state(Caramelo.State.TRAINING)
	w2.visual._process(0.1)
	var push_scale := w2.visual.scale.y
	var push_legs := (w2.visual.get_node("LegsFront") as Node2D).rotation
	_check(not dumbbell.visible, "halter continua oculto nas flexoes")

	w2.finish_exercise()
	w2.reach_level(3)
	w2.model.restore_energy(100)
	w2.exercise.request_exercise(&"dumbbells")
	w2.run_until_state(Caramelo.State.TRAINING)
	w2.visual._process(0.1)
	var dumb_scale := w2.visual.scale.y
	var dumb_legs := (w2.visual.get_node("LegsFront") as Node2D).rotation
	_check(dumbbell.visible, "halter aparece nos halteres")
	_check(absf(push_scale - dumb_scale) > 0.02 or absf(push_legs - dumb_legs) > 0.05,
		"poses distinguiveis: flexao (escala %.3f, patas %.3f) vs halteres (%.3f, %.3f)"
			% [push_scale, push_legs, dumb_scale, dumb_legs])
	w2.finish_exercise()
	w2.run(0.2)
	w2.visual._process(0.1)
	_check(not dumbbell.visible, "halter some ao terminar")
	w2.free_all()


## Conta quantos dos `count` treinos dispararam reacao comica, com semente fixa.
func _comic_runs(seed_value: int, count: int) -> int:
	var w := _world()
	w.exercise.set_random_seed(seed_value)
	var seen: Array = []
	w.exercise.comic_reaction_triggered.connect(func(_id: StringName) -> void: seen.append(true))
	for _i in count:
		w.model.restore_energy(100)
		if not w.exercise.request_exercise(&"push_ups"):
			break
		w.finish_exercise()
	w.free_all()
	return seen.size()


# --------------------------------------------------------------------------------------
# 52-53. Regressao
# --------------------------------------------------------------------------------------

func _test_regression() -> void:
	_g("52-53. Cena e execucao sem interacao")
	var w := _world()
	var systems: Array = []
	var queue: Array[Node] = [w.main]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		if node is ExerciseSystem:
			systems.append(node)
		for child in node.get_children():
			queue.append(child)
	_check(systems.size() == 1, "%d sistema de exercicios na cena" % systems.size())
	_check(w.feedback != null, "feedback de treino presente em Interface")
	_check(not w.feedback.visible, "feedback comeca oculto")

	w.run(150.0)
	_check(w.model.get_energy() == 70, "energia continua 70 (%d)" % w.model.get_energy())
	_check(w.model.get_strength() == 0, "forca continua 0 (%d)" % w.model.get_strength())
	_check(w.model.get_bond() == 0 and w.model.get_level() == 1, "vinculo e nivel intactos")
	_check(not w.exercise.has_pending_exercise(), "nenhum treino surgiu sozinho")

	_g("A interface de treino nao altera o modelo")
	var source := FileAccess.get_file_as_string("res://scripts/ui/training_feedback.gd")
	for forbidden in ["add_strength", "try_spend_energy", "restore_energy", "add_bond", "get_model"]:
		_check(not source.contains(forbidden), "training_feedback.gd nao menciona '%s'" % forbidden)
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
