extends SceneTree
## Testes permanentes do descanso e dos microcomportamentos ociosos.
##
## Executar:  godot --headless --path . --script tests/test_rest_and_idle.gd
##
## Nenhuma espera real: `Caramelo.simulate` e `RestSystem.simulate` avancam o tempo.

const STEP := 1.0 / 60.0
const REST_POINT := Vector2(1217.2, 734.6)
const LEVELS_PATH := "res://data/levels.json"
const FOODS_PATH := "res://data/foods.json"
const EXERCISES_PATH := "res://data/exercises.json"

var _passed := 0
var _failures: Array[String] = []
var _group := ""
var _done := false
var _viewport: SubViewport


class Spy:
	extends RefCounted
	var events: Array = []
	func on_rest_requested() -> void: events.append(["requested"])
	func on_rest_rejected(reason: int) -> void:
		events.append(["rejected", RestSystem.rejection_name(reason)])
	func on_rest_started() -> void: events.append(["started"])
	func on_rest_completed() -> void: events.append(["completed"])
	func on_restored(amount: int) -> void: events.append(["restored", amount])
	func on_energy(p: int, n: int) -> void: events.append(["energy", p, n])
	func on_idle(p: int, n: int) -> void:
		events.append(["idle", Caramelo.idle_behavior_name(p), Caramelo.idle_behavior_name(n)])
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
	var rest: RestSystem
	var feeding: FeedingSystem
	var exercise: ExerciseSystem
	var model: ProgressionModel
	var dog: Caramelo
	var visual: Node2D

	func _init(viewport: SubViewport) -> void:
		main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
		viewport.add_child(main)
		session = _find(main, func(n: Node) -> bool: return n is GameSession) as GameSession
		rest = _find(main, func(n: Node) -> bool: return n is RestSystem) as RestSystem
		feeding = _find(main, func(n: Node) -> bool: return n is FeedingSystem) as FeedingSystem
		exercise = _find(main, func(n: Node) -> bool: return n is ExerciseSystem) as ExerciseSystem
		dog = _find(main, func(n: Node) -> bool: return n is Caramelo) as Caramelo
		visual = dog.get_node("Visual") as Node2D
		model = session.get_model()
		dog.set_physics_process(false)
		rest.set_process(false)
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

	## Avanca cachorro e descanso juntos, como no jogo.
	func run(seconds: float) -> void:
		for _i in int(round(seconds / (1.0 / 60.0))):
			dog.simulate(1.0 / 60.0)
			rest.simulate(1.0 / 60.0)

	func run_until_state(state: int, limit: float = 90.0) -> bool:
		for _i in int(round(limit / (1.0 / 60.0))):
			if dog.get_current_state() == state:
				return true
			dog.simulate(1.0 / 60.0)
			rest.simulate(1.0 / 60.0)
		return dog.get_current_state() == state

	func free_all() -> void:
		main.free()


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	# Sem persistencia: esta suite nao testa save, e cada mundo criado aqui precisa
	# comecar limpo, sem carregar o estado deixado pelo mundo anterior.
	SaveManager.persistence_enabled = false
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	root.add_child(_viewport)

	_test_config()
	_test_recovery()
	_test_requested_rest()
	_test_autonomous_rest()
	_test_idle_behaviors()
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


func _raw(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _rejects(label: String, mutate: Callable) -> void:
	var levels: Dictionary = (_raw(LEVELS_PATH) as Dictionary).duplicate(true)
	mutate.call(levels["rest"] as Dictionary)
	var config := GameConfig.from_dictionaries(levels, _raw(FOODS_PATH), _raw(EXERCISES_PATH))
	var ok := not config.is_valid and not config.errors.is_empty()
	_check(ok, "%s -> %s" % [label, config.errors[0] if not config.errors.is_empty() else "ACEITOU"])


# --------------------------------------------------------------------------------------
# 1-7. Configuracao
# --------------------------------------------------------------------------------------

func _test_config() -> void:
	_g("1-4. A secao de descanso vem de levels.json")
	var config := GameConfig.load_default()
	_check(config.is_valid, "configuracao real valida")
	var rest := config.get_rest()
	_check(not rest.is_empty(), "secao 'rest' presente: %s" % str(rest.keys()))
	_check(is_equal_approx(float(rest["energy_per_minute"]), 1.0),
		"taxa = %s energia por minuto" % rest["energy_per_minute"])
	_check(int(rest["low_energy_threshold"]) == 30, "limiar baixo = %d" % int(rest["low_energy_threshold"]))
	_check(int(rest["preferred_recovery_target"]) == 50,
		"alvo preferido = %d" % int(rest["preferred_recovery_target"]))
	_check(float(rest["autonomous_weight_rested"]) <= float(rest["autonomous_weight_low"])
		and float(rest["autonomous_weight_low"]) <= float(rest["autonomous_weight_critical"]),
		"pesos crescem com a queda de energia: %.2f / %.2f / %.2f"
			% [rest["autonomous_weight_rested"], rest["autonomous_weight_low"],
			   rest["autonomous_weight_critical"]])

	_g("5-7. Configuracao de descanso invalida e recusada")
	_rejects("taxa zero", func(r: Dictionary) -> void: r["energy_per_minute"] = 0)
	_rejects("taxa negativa", func(r: Dictionary) -> void: r["energy_per_minute"] = -1)
	_rejects("limiar acima de max_energy", func(r: Dictionary) -> void: r["low_energy_threshold"] = 140)
	_rejects("limiar negativo", func(r: Dictionary) -> void: r["low_energy_threshold"] = -5)
	_rejects("alvo acima de max_energy", func(r: Dictionary) -> void: r["preferred_recovery_target"] = 200)
	_rejects("alvo igual ao limiar", func(r: Dictionary) -> void: r["preferred_recovery_target"] = 30)
	_rejects("alvo menor que o limiar", func(r: Dictionary) -> void: r["preferred_recovery_target"] = 20)
	_rejects("peso fora de [0,1]", func(r: Dictionary) -> void: r["autonomous_weight_low"] = 1.5)
	_rejects("pesos nao monotonicos", func(r: Dictionary) -> void: r["autonomous_weight_critical"] = 0.1)
	_rejects("campo obrigatorio ausente", func(r: Dictionary) -> void: r.erase("energy_per_minute"))
	_rejects("tipo errado", func(r: Dictionary) -> void: r["low_energy_threshold"] = "trinta")

	var levels: Dictionary = (_raw(LEVELS_PATH) as Dictionary).duplicate(true)
	levels.erase("rest")
	var without := GameConfig.from_dictionaries(levels, _raw(FOODS_PATH), _raw(EXERCISES_PATH))
	_check(not without.is_valid and without.errors[0].contains("'rest'"),
		"secao ausente -> %s" % without.errors[0])


# --------------------------------------------------------------------------------------
# 8-18. Recuperacao
# --------------------------------------------------------------------------------------

func _test_recovery() -> void:
	_g("8-10, 18. Acumulador fracionario: 59 s nada, 60 s exatamente +1")
	var w := _world()
	_check(is_equal_approx(w.rest.get_seconds_per_energy(), 60.0),
		"%.1f s por energia, derivados da configuracao" % w.rest.get_seconds_per_energy())
	var spy := Spy.new()
	w.rest.rest_energy_restored.connect(spy.on_restored)
	w.model.energy_changed.connect(spy.on_energy)
	w.dog.request_state(Caramelo.State.RESTING)
	_check(w.dog.get_current_state() == Caramelo.State.RESTING, "em RESTING")

	w.rest.simulate(59.0)
	_check(w.model.get_energy() == 70, "59 s nao adicionam energia (%d)" % w.model.get_energy())
	_check(spy.events.is_empty(), "nenhum sinal ainda")
	w.rest.simulate(1.0)
	_check(w.model.get_energy() == 71, "o segundo restante adiciona exatamente 1 (%d)" % w.model.get_energy())
	_check(spy.count("restored") == 1 and int(spy.last("restored")[1]) == 1,
		"rest_energy_restored(1)")
	_check(spy.names() == ["energy", "restored"],
		"ordem: energy_changed antes de rest_energy_restored — %s" % str(spy.names()))

	_g("10. Descansos separados acumulam")
	var w2 := _world()
	w2.dog.request_state(Caramelo.State.RESTING)
	w2.rest.simulate(30.0)
	# sai de RESTING e volta: a fracao tem de sobreviver
	w2.dog.request_state(Caramelo.State.IDLE)
	w2.rest.simulate(120.0)
	_check(w2.model.get_energy() == 70, "fora de RESTING nao recupera (%d)" % w2.model.get_energy())
	w2.dog.request_state(Caramelo.State.RESTING)
	w2.rest.simulate(20.0)
	_check(w2.model.get_energy() == 70, "30 s + 20 s ainda nao chegam a 1 (%d)" % w2.model.get_energy())
	w2.rest.simulate(10.0)
	_check(w2.model.get_energy() == 71,
		"30 s + 20 s + 10 s = +1 energia (%d)" % w2.model.get_energy())
	w2.free_all()

	_g("11. Nenhum outro estado recupera energia")
	for state in [Caramelo.State.IDLE, Caramelo.State.WALKING, Caramelo.State.EATING,
			Caramelo.State.TRAINING, Caramelo.State.HAPPY]:
		var probe := _world()
		if state == Caramelo.State.WALKING:
			probe.dog.request_activity(Caramelo.State.EATING)
		else:
			probe.dog.request_state(state)
		var before := probe.model.get_energy()
		probe.rest.simulate(600.0)
		_check(probe.model.get_energy() == before,
			"%s: 10 min nao recuperam nada (%d)"
				% [Caramelo.state_name(probe.dog.get_current_state()), probe.model.get_energy()])
		probe.free_all()

	_g("12-14. Deltas invalidos e delta grande")
	var w3 := _world()
	w3.dog.request_state(Caramelo.State.RESTING)
	w3.rest.simulate(0.0)
	w3.rest.simulate(-120.0)
	_check(w3.model.get_energy() == 70, "delta zero e negativo nao recuperam (%d)" % w3.model.get_energy())
	_check(is_zero_approx(w3.rest.get_accumulated_seconds()), "acumulador intacto")
	w3.rest.simulate(605.0)
	_check(w3.model.get_energy() == 80, "605 s -> +10 energia (%d)" % w3.model.get_energy())
	_check(absf(w3.rest.get_accumulated_seconds() - 5.0) < 0.001,
		"restam %.1f s no acumulador" % w3.rest.get_accumulated_seconds())
	w3.free_all()

	_g("15-17. Teto e saturacao")
	var w4 := _world()
	var spy4 := Spy.new()
	w4.rest.rest_energy_restored.connect(spy4.on_restored)
	w4.model.energy_changed.connect(spy4.on_energy)
	w4.dog.request_state(Caramelo.State.RESTING)
	w4.rest.simulate(60.0 * 40.0)                   # 40 min para 30 pontos de folga
	_check(w4.model.get_energy() == 100, "energia satura em %d" % w4.model.get_energy())
	_check(is_zero_approx(w4.rest.get_accumulated_seconds()),
		"nenhum credito oculto guardado (%.2f s)" % w4.rest.get_accumulated_seconds())
	var restored_total := 0
	for event in spy4.events:
		if event[0] == "restored":
			restored_total += int(event[1])
	_check(restored_total == 30, "total creditado = %d, e nao os 40 do periodo" % restored_total)
	spy4.events.clear()
	w4.rest.simulate(600.0)
	_check(w4.model.get_energy() == 100, "continua em 100")
	_check(spy4.events.is_empty(), "com energia cheia nao ha sinal redundante")
	w4.free_all()
	w.free_all()


# --------------------------------------------------------------------------------------
# 19-29. Descanso solicitado
# --------------------------------------------------------------------------------------

func _test_requested_rest() -> void:
	_g("19-23, 29. Pedido aceito caminha ate o RestPoint")
	var w := _world()
	var spy := Spy.new()
	w.rest.rest_requested.connect(spy.on_rest_requested)
	w.rest.rest_started.connect(spy.on_rest_started)
	w.rest.rest_completed.connect(spy.on_rest_completed)
	w.rest.rest_rejected.connect(spy.on_rest_rejected)

	_check(w.rest.request_rest(), "pedido aceito")
	_check(spy.count("requested") == 1, "rest_requested uma vez")
	_check(w.dog.get_current_state() == Caramelo.State.WALKING, "Caramelo caminhando")
	_check(w.dog.get_destination().distance_to(REST_POINT) < 0.01,
		"destino = RestPoint %s" % w.dog.get_destination())
	_check(w.dog.has_reserved_activity(), "descanso reservado")

	var repeated := 0
	for _i in 8:
		if w.rest.request_rest():
			repeated += 1
	_check(repeated == 0, "8 pedidos extras nao criam outro descanso (%d aceitos)" % repeated)
	_check(spy.last("rejected")[1] == "ACTIVITY_RESERVED", "codigo = %s" % spy.last("rejected")[1])

	w.run(1.5)
	_check(w.model.get_energy() == 70, "nada recuperado durante a caminhada (%d)" % w.model.get_energy())
	_check(spy.count("started") == 0, "rest_started ainda nao saiu")

	_check(w.run_until_state(Caramelo.State.RESTING), "chegou e entrou em RESTING")
	_check(spy.count("started") == 1, "rest_started uma vez")
	_check(w.dog.position.distance_to(REST_POINT) < Caramelo.ARRIVAL_TOLERANCE,
		"parou no ponto, a %.2f px" % w.dog.position.distance_to(REST_POINT))

	w.rest.simulate(60.0)
	_check(w.model.get_energy() == 71, "recuperando no ponto (%d)" % w.model.get_energy())

	for _i in 3600:
		if w.dog.get_current_state() != Caramelo.State.RESTING:
			break
		w.dog.simulate(STEP)
	_check(spy.count("completed") == 1, "rest_completed uma vez ao sair")
	_check(not w.dog.has_reserved_activity(), "reserva liberada ao terminar")
	w.free_all()

	_g("24-28. Pedidos recusados")
	var w2 := _world()
	var spy2 := Spy.new()
	w2.rest.rest_rejected.connect(spy2.on_rest_rejected)
	w2.feeding.request_feeding(&"kibble")
	_check(not w2.rest.request_rest(), "refeicao pendente bloqueia descanso")
	_check(spy2.last("rejected")[1] == "ACTIVITY_RESERVED", "codigo = %s" % spy2.last("rejected")[1])
	_check(w2.feeding.get_pending_food() == &"kibble", "refeicao intacta")
	_check(w2.run_until_state(Caramelo.State.EATING), "chegou ao pote")
	_check(not w2.rest.request_rest(), "EATING bloqueia descanso")
	_check(spy2.last("rejected")[1] == "DOG_BUSY", "codigo = %s" % spy2.last("rejected")[1])
	_check(w2.dog.get_current_state() == Caramelo.State.EATING, "continua comendo")
	w2.free_all()

	var w3 := _world()
	var spy3 := Spy.new()
	w3.rest.rest_rejected.connect(spy3.on_rest_rejected)
	w3.exercise.request_exercise(&"push_ups")
	_check(not w3.rest.request_rest(), "treino pendente bloqueia descanso")
	_check(spy3.last("rejected")[1] == "ACTIVITY_RESERVED", "codigo = %s" % spy3.last("rejected")[1])
	_check(w3.run_until_state(Caramelo.State.TRAINING), "chegou ao equipamento")
	_check(not w3.rest.request_rest(), "TRAINING bloqueia descanso")
	_check(spy3.last("rejected")[1] == "DOG_BUSY", "codigo = %s" % spy3.last("rejected")[1])
	_check(w3.model.get_energy() == 55, "energia so mudou pelo treino (%d)" % w3.model.get_energy())
	# nenhum pedido recusado pode ressurgir depois
	for _i in 5400:
		if not w3.exercise.has_pending_exercise():
			break
		w3.dog.simulate(STEP)
	w3.run(6.0)
	_check(w3.dog.get_current_state() != Caramelo.State.RESTING
		or not w3.dog.has_reserved_activity(),
		"nenhum descanso recusado virou fila (estado = %s)"
			% Caramelo.state_name(w3.dog.get_current_state()))
	w3.free_all()


# --------------------------------------------------------------------------------------
# 30-36. Descanso autonomo
# --------------------------------------------------------------------------------------

## Fracao das decisoes autonomas que escolheram descansar, com a energia fixada.
func _rest_share(energy: int, seeds: int = 6, minutes: float = 12.0) -> float:
	var rests := 0
	var decisions := 0
	for seed_value in seeds:
		var w := _world()
		w.dog.set_random_seed(seed_value * 31 + 7)
		# fixa a energia e, com ela, a tendencia
		if energy < w.model.get_energy():
			w.model.try_spend_energy(w.model.get_energy() - energy)
		elif energy > w.model.get_energy():
			w.model.restore_energy(energy - w.model.get_energy())
		var previous := w.dog.get_current_state()
		for _i in int(round(minutes * 60.0 / STEP)):
			w.dog.simulate(STEP)            # sem rest.simulate: a energia fica travada
			var current := w.dog.get_current_state()
			if current != previous:
				if current == Caramelo.State.RESTING:
					rests += 1
					decisions += 1
				elif current == Caramelo.State.WALKING:
					decisions += 1
				previous = current
		w.free_all()
	return float(rests) / maxf(float(decisions), 1.0)


func _test_autonomous_rest() -> void:
	_g("30-32. A tendencia de descanso cresce conforme a energia cai")
	var w := _world()
	var high := w.rest._weight_for_energy(80)
	var mid := w.rest._weight_for_energy(40)
	var low := w.rest._weight_for_energy(10)
	_check(is_equal_approx(high, 0.28), "energia 80 -> peso %.2f" % high)
	_check(mid > high and mid < low, "energia 40 -> peso %.2f, entre os extremos" % mid)
	_check(low > 0.7, "energia 10 -> peso %.2f" % low)
	_check(is_equal_approx(w.rest._weight_for_energy(50), 0.28), "no alvo (50) o peso volta ao base")
	_check(is_equal_approx(w.rest._weight_for_energy(30), 0.60), "no limiar (30) o peso e o 'low'")
	# a tendencia chega a Caramelo sem que ele conheça o modelo
	w.model.try_spend_energy(60)
	_check(w.dog.get_rest_tendency() > 0.6,
		"Caramelo recebeu a tendencia %.2f com energia %d"
			% [w.dog.get_rest_tendency(), w.model.get_energy()])
	w.free_all()

	var share_high := _rest_share(80)
	var share_mid := _rest_share(40)
	var share_low := _rest_share(10)
	_check(share_high > 0.0, "com energia alta o descanso continua possivel: %.0f%%" % (share_high * 100.0))
	_check(share_mid > share_high, "entre 30 e 50 fica mais provavel: %.0f%% vs %.0f%%"
		% [share_mid * 100.0, share_high * 100.0])
	_check(share_low > share_mid, "abaixo de 30 e a escolha preferida: %.0f%%" % (share_low * 100.0))

	_g("35-36. Descanso nao se repete indefinidamente")
	_check(share_low < 0.55,
		"mesmo com energia no chao o descanso nao toma tudo: %.0f%% das decisoes" % (share_low * 100.0))
	var w2 := _world()
	w2.dog.set_random_seed(11)
	w2.model.try_spend_energy(65)                   # energia 5: tendencia maxima
	var sequence: Array = []
	for _i in int(round(600.0 / STEP)):
		w2.dog.simulate(STEP)
		var current := w2.dog.get_current_state()
		if sequence.is_empty() or sequence[-1] != current:
			sequence.append(current)
	var back_to_back := 0
	for i in range(1, sequence.size()):
		if sequence[i] == Caramelo.State.RESTING and sequence[i - 1] == Caramelo.State.IDLE \
				and i >= 2 and sequence[i - 2] == Caramelo.State.RESTING:
			back_to_back += 1
	_check(back_to_back == 0, "%d descansos encadeados sem caminhar entre eles" % back_to_back)
	_check(sequence.has(Caramelo.State.WALKING), "ele volta a caminhar mesmo com energia baixa")
	_check(sequence.count(Caramelo.State.IDLE) > 3, "e volta a ficar ocioso entre as coisas")
	w2.free_all()

	_g("33-34. Energia baixa nunca interrompe atividade dirigida")
	var w3 := _world()
	w3.model.try_spend_energy(50)                   # energia 20, abaixo do limiar
	_check(w3.exercise.request_exercise(&"push_ups"), "treino aceito com energia 20")
	_check(w3.run_until_state(Caramelo.State.TRAINING), "chegou ao equipamento")
	var destination := w3.dog.get_destination()
	w3.run(8.0)
	_check(w3.dog.get_current_state() == Caramelo.State.TRAINING,
		"segue treinando apesar da energia baixa (= %s)"
			% Caramelo.state_name(w3.dog.get_current_state()))
	_check(w3.model.get_energy() == 5, "energia debitada so pelo treino: %d" % w3.model.get_energy())
	_check(w3.dog.get_destination() == destination, "destino nao foi substituido")
	w3.free_all()

	var w4 := _world()
	w4.model.try_spend_energy(60)                   # energia 10
	_check(w4.feeding.request_feeding(&"kibble"), "refeicao aceita com energia 10")
	var walking_destination := w4.dog.get_destination()
	w4.run(0.5)
	_check(w4.dog.get_current_state() == Caramelo.State.WALKING, "caminhando ao pote")
	_check(w4.dog.get_destination() == walking_destination,
		"a tendencia de descanso nao rouba o destino")
	_check(w4.run_until_state(Caramelo.State.EATING), "chega e come")
	w4.free_all()


# --------------------------------------------------------------------------------------
# 37-46. Microcomportamentos
# --------------------------------------------------------------------------------------

func _test_idle_behaviors() -> void:
	_g("37-38, 41, 44-45. Cinco microcomportamentos, sem repetir em sequencia")
	_check(Caramelo.IDLE_BEHAVIOR_NAMES.size() == 5,
		"%d microcomportamentos: %s" % [Caramelo.IDLE_BEHAVIOR_NAMES.size(),
			str(Caramelo.IDLE_BEHAVIOR_NAMES)])
	var trace_a := _idle_trace(2024)
	var trace_b := _idle_trace(2024)
	var trace_c := _idle_trace(7)
	_check(trace_a == trace_b, "semente fixa reproduz a sequencia (%d trocas)" % trace_a.size())
	_check(trace_a != trace_c, "semente diferente produz outra sequencia")
	var seen: Dictionary = {}
	for name in trace_a:
		seen[name] = true
	for name in Caramelo.IDLE_BEHAVIOR_NAMES:
		_check(seen.has(name), "%s apareceu na simulacao longa" % name)
	var repeats := 0
	for i in range(1, trace_a.size()):
		if trace_a[i] == trace_a[i - 1]:
			repeats += 1
	_check(repeats == 0, "%d repeticoes consecutivas" % repeats)

	var w := _world()
	var spy := Spy.new()
	w.dog.idle_behavior_changed.connect(spy.on_idle)
	w.dog.set_random_seed(5)
	# Sair e voltar para IDLE: o microcomportamento zera na saida, entao a entrada sempre
	# publica a troca. Semear com o cachorro ja ocioso as vezes sorteia o comportamento que
	# ja estava em cena, e ai nao ha troca nenhuma para observar.
	w.dog.request_state(Caramelo.State.RESTING)
	w.run(0.05)
	w.dog.request_state(Caramelo.State.IDLE)
	w.run(0.05)
	var first: Variant = spy.last("idle")
	_check(first != null, "a entrada em IDLE publica o microcomportamento")
	_check(first != null and String(first[2]) != "NONE",
		"e o sinal informa anterior e novo: %s" % ("sem sinal" if first == null
			else "%s -> %s" % [first[1], first[2]]))
	_check(w.dog.get_idle_behavior() >= 0, "comportamento ativo em IDLE")

	_g("39-40, 46. Nada de gameplay e nenhuma mudanca de posicao logica")
	# A posicao e conferida quadro a quadro: so a caminhada pode move-la. Olhar apenas o fim
	# dos dois minutos deixaria passar um deslocamento ocorrido numa ociosidade do meio.
	var anchor := w.dog.position
	var moved_while_idle := 0.0
	for _i in int(round(120.0 / STEP)):
		var was_idle := w.dog.get_current_state() == Caramelo.State.IDLE
		w.run(STEP)
		if w.dog.get_current_state() != Caramelo.State.IDLE or not was_idle:
			anchor = w.dog.position
			continue
		moved_while_idle = maxf(moved_while_idle, w.dog.position.distance_to(anchor))
	_check(is_zero_approx(moved_while_idle),
		"posicao logica inalterada enquanto ocioso (%.3f px)" % moved_while_idle)
	_check(w.model.get_strength() == 0 and w.model.get_bond() == 0,
		"forca e vinculo intactos (%d / %d)" % [w.model.get_strength(), w.model.get_bond()])
	_check(not w.dog.has_reserved_activity() or w.dog.get_current_state() == Caramelo.State.WALKING,
		"microcomportamento nao reserva atividade")
	w.free_all()

	# CHASE_FLY so pode deslocar o no visual, nunca a posicao do controlador. Varre
	# sementes ate encontrar o comportamento durante uma ociosidade.
	var drift := 0.0
	var logical_kept := false
	var found := false
	for seed_value in 20:
		var w2 := _world()
		w2.dog.set_random_seed(seed_value * 13 + 1)
		var logical := w2.dog.position
		for _i in int(round(240.0 / STEP)):
			w2.dog.simulate(STEP)
			if w2.dog.get_current_state() != Caramelo.State.IDLE:
				continue
			if w2.dog.get_idle_behavior() != Caramelo.IdleBehavior.CHASE_FLY:
				continue
			w2.visual._process(0.08)
			drift = absf(w2.visual.position.x)
			logical_kept = w2.dog.position == logical
			found = true
			break
		w2.free_all()
		if found:
			break
	_check(found, "CHASE_FLY encontrado numa ociosidade")
	_check(drift > 0.5, "CHASE_FLY desloca o no visual (%.1f px)" % drift)
	_check(logical_kept, "e a posicao logica de Caramelo nao muda")

	_g("42-43. Fora de IDLE nao ha microcomportamento")
	var w3 := _world()
	w3.dog.request_state(Caramelo.State.IDLE)
	w3.run(0.05)
	_check(w3.dog.get_idle_behavior() != Caramelo.IdleBehavior.NONE, "ativo em IDLE")
	var spy3 := Spy.new()
	w3.dog.idle_behavior_changed.connect(spy3.on_idle)
	_check(w3.feeding.request_feeding(&"kibble"), "uma atividade aceita interrompe a ociosidade")
	_check(w3.dog.get_idle_behavior() == Caramelo.IdleBehavior.NONE,
		"microcomportamento encerrado ao sair de IDLE")
	_check(spy3.last("idle")[2] == "NONE", "o sinal avisou o encerramento")
	for state in [Caramelo.State.WALKING, Caramelo.State.EATING, Caramelo.State.HAPPY]:
		_check(w3.dog.get_idle_behavior() == Caramelo.IdleBehavior.NONE,
			"nenhum microcomportamento fora de IDLE")
		w3.run(0.2)
	w3.free_all()


func _idle_trace(seed_value: int) -> Array:
	var w := _world()
	w.dog.set_random_seed(seed_value)
	var trace: Array = []
	w.dog.idle_behavior_changed.connect(func(_p: int, n: int) -> void:
		if n != Caramelo.IdleBehavior.NONE:
			trace.append(Caramelo.idle_behavior_name(n)))
	for _i in int(round(600.0 / STEP)):
		w.dog.simulate(STEP)
	w.free_all()
	return trace


# --------------------------------------------------------------------------------------
# 51-54. Regressao
# --------------------------------------------------------------------------------------

func _test_regression() -> void:
	_g("52-54. Cena e execucao sem interacao")
	var w := _world()
	var systems: Array = []
	var queue: Array[Node] = [w.main]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		if node is RestSystem:
			systems.append(node)
		for child in node.get_children():
			queue.append(child)
	_check(systems.size() == 1, "%d RestSystem na cena" % systems.size())
	_check(w.rest.is_configured(), "configurado pela GameSession")

	w.dog.set_random_seed(99)
	var energy_seen: Array = []
	w.model.energy_changed.connect(func(_p: int, n: int) -> void: energy_seen.append(n))
	w.run(300.0)
	_check(w.model.get_strength() == 0 and w.model.get_bond() == 0,
		"5 min sem interacao: forca %d, vinculo %d" % [w.model.get_strength(), w.model.get_bond()])
	_check(w.model.get_level() == 1, "nivel continua 1")
	_check(w.model.get_energy() >= 70,
		"energia so pode ter subido pelo descanso: %d" % w.model.get_energy())

	_g("54. Sem passar por RESTING, a energia nao muda")
	var w2 := _world()
	var before := w2.model.get_energy()
	for _i in int(round(300.0 / STEP)):
		if w2.dog.get_current_state() == Caramelo.State.RESTING:
			w2.dog.request_state(Caramelo.State.IDLE)
		w2.dog.simulate(STEP)
		w2.rest.simulate(STEP)
	_check(w2.model.get_energy() == before,
		"5 min evitando RESTING: energia continua %d" % w2.model.get_energy())

	_g("51. Alimentacao e treino continuam mutuamente exclusivos")
	_check(w2.feeding.request_feeding(&"kibble"), "refeicao aceita")
	_check(not w2.exercise.request_exercise(&"push_ups"), "treino recusado")
	_check(not w2.rest.request_rest(), "descanso tambem recusado")
	w2.free_all()
	w.free_all()


func _report() -> void:
	SaveManager.persistence_enabled = true
	print("\n" + "=".repeat(70))
	if _failures.is_empty():
		print("TODOS OS TESTES PASSARAM  (%d verificacoes)" % _passed)
		quit(0)
		return
	print("FALHAS: %d de %d verificacoes" % [_failures.size(), _passed + _failures.size()])
	for failure in _failures:
		print("  - " + failure)
	quit(1)
