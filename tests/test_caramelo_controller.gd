extends SceneTree
## Testes permanentes do controlador de Caramelo.
##
## Executar:  godot --headless --path . --script tests/test_caramelo_controller.gd
## Sai com codigo 0 quando tudo passa e 1 na primeira falha registrada.
##
## Nao ha framework externo. O tempo nunca e esperado de verdade: as duracoes sao
## simuladas chamando `Caramelo.simulate(delta)` em laco, o que torna a suite
## deterministica e instantanea.

const STEP := 1.0 / 60.0
const CARAMELO_SCENE := "res://scenes/dog/caramelo.tscn"
const BACKYARD_SCENE := "res://scenes/environment/backyard.tscn"
const MAIN_SCENE := "res://scenes/main/main.tscn"

var _passed := 0
var _failures: Array[String] = []
var _group := ""
var _done := false
var _viewport: SubViewport = null


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	root.add_child(_viewport)

	_test_initial_state()
	_test_states_exist()
	_test_valid_transition()
	_test_invalid_transition()
	_test_reentry_does_not_restart()
	_test_eating_not_interruptible()
	_test_training_not_interruptible()
	_test_commands_discarded_not_queued()
	_test_signal_once_per_transition()
	_test_no_signal_on_rejection()
	_test_destinations_inside_polygon()
	_test_autonomous_path_inside_polygon()
	_test_stops_at_destination()
	_test_fixed_seed_is_reproducible()
	_test_follows_backyard_transform()
	_test_main_scene_has_one_caramelo()

	_viewport.free()
	_report()
	return true


# --------------------------------------------------------------------------------------
# Infraestrutura
# --------------------------------------------------------------------------------------

func _group_name(name: String) -> void:
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


func _polygon_from_backyard() -> PackedVector2Array:
	var backyard := (load(BACKYARD_SCENE) as PackedScene).instantiate()
	var polygon: PackedVector2Array = (backyard.get_node("WorldBounds/WalkableCollision")
		as CollisionPolygon2D).polygon
	backyard.free()
	return polygon


## Caramelo isolado, ja configurado com a geometria real do quintal.
func _make_dog(seed_value: int = 20260916) -> Caramelo:
	var dog := (load(CARAMELO_SCENE) as PackedScene).instantiate() as Caramelo
	_viewport.add_child(dog)
	dog.set_physics_process(false)  # a simulacao e conduzida pelo teste, nao pelo motor
	dog.position = Vector2(880.0, 860.0)  # antes do poligono: evita o reposicionamento de guarda
	dog.set_random_seed(seed_value)
	dog.set_walkable_polygon(_polygon_from_backyard())
	dog.set_interaction_points(Vector2(941.6, 792.1), Vector2(689.0, 746.1), Vector2(1217.2, 734.6))
	return dog


func _run(dog: Caramelo, seconds: float) -> void:
	var steps := int(round(seconds / STEP))
	for _i in steps:
		dog.simulate(STEP)


## Simula ate o estado alvo aparecer. Devolve `false` se ele nao ocorrer no limite.
func _run_until(dog: Caramelo, state: int, limit_seconds: float = 60.0) -> bool:
	var steps := int(round(limit_seconds / STEP))
	for _i in steps:
		if dog.get_current_state() == state:
			return true
		dog.simulate(STEP)
	return dog.get_current_state() == state


func _inside_with_margin(point: Vector2, polygon: PackedVector2Array) -> bool:
	if not Geometry2D.is_point_in_polygon(point, polygon):
		return false
	var closest := INF
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		closest = minf(closest, point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)))
	return closest >= Caramelo.BODY_MARGIN - 0.01


class SignalSpy:
	extends RefCounted
	var events: Array = []
	func on_state_changed(previous_state: int, new_state: int) -> void:
		events.append([previous_state, new_state])


# --------------------------------------------------------------------------------------
# Testes
# --------------------------------------------------------------------------------------

func _test_initial_state() -> void:
	_group_name("1. Estado inicial e IDLE")
	var dog := _make_dog()
	_check(dog.get_current_state() == Caramelo.State.IDLE,
		"estado inicial = %s" % Caramelo.state_name(dog.get_current_state()))
	_check(dog.velocity == Vector2.ZERO, "comeca parado")
	dog.free()


func _test_states_exist() -> void:
	_group_name("2. Os seis estados obrigatorios existem")
	var expected := ["IDLE", "WALKING", "EATING", "TRAINING", "RESTING", "HAPPY"]
	var keys: Array = Caramelo.State.keys()
	_check(keys.size() == expected.size(), "quantidade de estados = %d" % keys.size())
	for name in expected:
		_check(keys.has(name), "estado %s definido" % name)
	_check(Caramelo.TRANSITIONS.size() == expected.size(), "matriz cobre os seis estados")


func _test_valid_transition() -> void:
	_group_name("3. Transicao valida e aceita")
	var dog := _make_dog()
	_check(dog.request_state(Caramelo.State.RESTING), "IDLE -> RESTING aceito")
	_check(dog.get_current_state() == Caramelo.State.RESTING,
		"estado agora = %s" % Caramelo.state_name(dog.get_current_state()))
	dog.free()


func _test_invalid_transition() -> void:
	_group_name("4. Transicao invalida e rejeitada")
	var dog := _make_dog()
	dog.request_state(Caramelo.State.RESTING)
	# A matriz do MVP_SPEC nao liga RESTING a WALKING nem a HAPPY.
	_check(not dog.request_state(Caramelo.State.WALKING), "RESTING -> WALKING rejeitado")
	_check(not dog.request_state(Caramelo.State.HAPPY), "RESTING -> HAPPY rejeitado")
	_check(dog.get_current_state() == Caramelo.State.RESTING, "permanece em RESTING")
	_check(not dog.request_state(99), "estado inexistente (99) rejeitado")
	_check(not dog.request_state(-1), "estado inexistente (-1) rejeitado")
	dog.free()


func _test_reentry_does_not_restart() -> void:
	_group_name("5. Reentrada no mesmo estado nao reinicia o estado")
	var dog := _make_dog()
	dog.request_state(Caramelo.State.HAPPY)
	_run(dog, Caramelo.HAPPY_DURATION * 0.75)
	_check(not dog.request_state(Caramelo.State.HAPPY), "HAPPY -> HAPPY recusado")
	_check(dog.get_current_state() == Caramelo.State.HAPPY, "ainda em HAPPY")
	_run(dog, Caramelo.HAPPY_DURATION * 0.35)
	# Passados ~110% da duracao, HAPPY tem de ter terminado. Se a reentrada tivesse
	# zerado o cronometro, ele ainda estaria correndo.
	_check(dog.get_current_state() != Caramelo.State.HAPPY,
		"HAPPY terminou no prazo original (estado = %s)"
			% Caramelo.state_name(dog.get_current_state()))
	dog.free()


func _test_eating_not_interruptible() -> void:
	_group_name("6. EATING nao pode ser interrompido")
	var dog := _make_dog()
	dog.request_state(Caramelo.State.EATING)
	_check(dog.get_current_state() == Caramelo.State.EATING, "entrou em EATING")
	_check(not dog.is_interruptible(), "is_interruptible() = false")
	for target in [Caramelo.State.IDLE, Caramelo.State.HAPPY, Caramelo.State.RESTING,
			Caramelo.State.WALKING, Caramelo.State.TRAINING]:
		_check(not dog.request_state(target),
			"comando %s descartado durante EATING" % Caramelo.state_name(target))
	_check(not dog.request_activity(Caramelo.State.TRAINING),
		"request_activity tambem e descartado durante EATING")
	_check(dog.get_current_state() == Caramelo.State.EATING, "continua em EATING")
	dog.free()


func _test_training_not_interruptible() -> void:
	_group_name("7. TRAINING nao pode ser interrompido")
	var dog := _make_dog()
	dog.request_state(Caramelo.State.TRAINING)
	_check(dog.get_current_state() == Caramelo.State.TRAINING, "entrou em TRAINING")
	_check(not dog.is_interruptible(), "is_interruptible() = false")
	for target in [Caramelo.State.IDLE, Caramelo.State.HAPPY, Caramelo.State.RESTING,
			Caramelo.State.WALKING, Caramelo.State.EATING]:
		_check(not dog.request_state(target),
			"comando %s descartado durante TRAINING" % Caramelo.state_name(target))
	_check(dog.get_current_state() == Caramelo.State.TRAINING, "continua em TRAINING")
	dog.free()


func _test_commands_discarded_not_queued() -> void:
	_group_name("8/9. Comandos descartados nao sao enfileirados nem executados depois")
	var dog := _make_dog()
	dog.request_state(Caramelo.State.EATING)
	dog.request_state(Caramelo.State.RESTING)   # descartado
	dog.request_state(Caramelo.State.WALKING)   # descartado
	_run(dog, Caramelo.EATING_DURATION + 0.2)
	# EATING termina no destino padrao HAPPY, nunca nos comandos recusados.
	_check(dog.get_current_state() == Caramelo.State.HAPPY,
		"apos EATING o estado e HAPPY, nao um comando recusado (= %s)"
			% Caramelo.state_name(dog.get_current_state()))
	_run(dog, Caramelo.HAPPY_DURATION + 0.2)
	_check(dog.get_current_state() == Caramelo.State.IDLE,
		"apos HAPPY volta a IDLE (= %s)" % Caramelo.state_name(dog.get_current_state()))
	dog.free()


func _test_signal_once_per_transition() -> void:
	_group_name("10. state_changed e emitido uma vez por transicao valida")
	var dog := _make_dog()
	var spy := SignalSpy.new()
	dog.state_changed.connect(spy.on_state_changed)
	dog.request_state(Caramelo.State.EATING)
	_check(spy.events.size() == 1, "1 sinal apos IDLE -> EATING (%d)" % spy.events.size())
	_check(spy.events[0][0] == Caramelo.State.IDLE and spy.events[0][1] == Caramelo.State.EATING,
		"carga do sinal = (IDLE, EATING)")
	_run(dog, Caramelo.EATING_DURATION + 0.2)
	_check(spy.events.size() == 2, "2 sinais apos EATING -> HAPPY (%d)" % spy.events.size())
	_run(dog, Caramelo.HAPPY_DURATION + 0.2)
	_check(spy.events.size() == 3, "3 sinais apos HAPPY -> IDLE (%d)" % spy.events.size())
	dog.free()


func _test_no_signal_on_rejection() -> void:
	_group_name("11. Transicao rejeitada nao emite sinal")
	var dog := _make_dog()
	var spy := SignalSpy.new()
	dog.state_changed.connect(spy.on_state_changed)
	dog.request_state(Caramelo.State.IDLE)      # reentrada
	dog.request_state(99)                       # inexistente
	dog.request_state(Caramelo.State.RESTING)   # valida: 1 sinal
	dog.request_state(Caramelo.State.WALKING)   # RESTING -> WALKING invalida
	dog.request_state(Caramelo.State.HAPPY)     # RESTING -> HAPPY invalida
	_check(spy.events.size() == 1,
		"apenas a transicao valida emitiu (%d sinais)" % spy.events.size())
	dog.free()


func _test_destinations_inside_polygon() -> void:
	_group_name("12. Destinos escolhidos ficam dentro do poligono")
	var polygon := _polygon_from_backyard()
	var dog := _make_dog(4242)
	var checked := 0
	for _i in 40:
		# Folga generosa: entre duas caminhadas cabem uma espera ociosa e um descanso.
		if not _run_until(dog, Caramelo.State.WALKING, 120.0):
			break
		var destination := dog.get_destination()
		if not _inside_with_margin(destination, polygon):
			_check(false, "destino %s fora da area util" % destination)
			break
		checked += 1
		if not _run_until(dog, Caramelo.State.IDLE, 120.0):
			break
	_check(checked >= 15, "%d destinos autonomos verificados, todos validos" % checked)
	dog.free()


func _test_autonomous_path_inside_polygon() -> void:
	_group_name("13. Trajetos autonomos permanecem dentro do poligono")
	var polygon := _polygon_from_backyard()
	var dog := _make_dog(777)
	var samples := 0
	var outside := 0
	var worst := Vector2.ZERO
	for _i in int(round(600.0 / STEP)):   # 10 minutos de jogo
		dog.simulate(STEP)
		samples += 1
		if not Geometry2D.is_point_in_polygon(dog.position, polygon):
			outside += 1
			worst = dog.position
	_check(outside == 0,
		"%d amostras em 10 min de jogo, %d fora do poligono%s"
			% [samples, outside, "" if outside == 0 else " (ex.: %s)" % worst])
	_check(_inside_with_margin(dog.position, polygon), "posicao final respeita a margem")
	dog.free()


func _test_stops_at_destination() -> void:
	_group_name("14. Caramelo para ao alcancar o destino, sem oscilar")
	var dog := _make_dog()
	_check(dog.request_activity(Caramelo.State.EATING), "request_activity(EATING) aceito")
	_check(dog.get_current_state() == Caramelo.State.WALKING,
		"caminha antes de comer (= %s)" % Caramelo.state_name(dog.get_current_state()))
	var target := dog.get_destination()
	_check(_run_until(dog, Caramelo.State.EATING, 30.0), "chega e entra em EATING")
	_check(dog.position.distance_to(target) <= Caramelo.ARRIVAL_TOLERANCE,
		"parou a %.3f px do destino" % dog.position.distance_to(target))
	_check(dog.velocity == Vector2.ZERO, "velocidade zerada ao parar")
	var resting_place := dog.position
	_run(dog, 1.0)
	_check(dog.position == resting_place, "nao oscila em volta do destino")
	dog.free()


func _test_fixed_seed_is_reproducible() -> void:
	_group_name("15. Semente fixa produz decisoes reproduziveis")
	var trace_a := _trace_with_seed(9001)
	var trace_b := _trace_with_seed(9001)
	var trace_c := _trace_with_seed(9002)
	_check(trace_a.size() > 8, "%d eventos registrados na amostra" % trace_a.size())
	_check(trace_a == trace_b, "mesma semente -> mesma sequencia de estados e destinos")
	_check(trace_a != trace_c, "semente diferente -> sequencia diferente")
	# Sem semente fixa o jogo entregue nao fica preso a uma unica sequencia.
	var free_a := _trace_with_seed(-1)
	var free_b := _trace_with_seed(-1)
	_check(free_a != free_b, "sem set_random_seed as execucoes divergem")


func _trace_with_seed(seed_value: int) -> Array:
	var dog := (load(CARAMELO_SCENE) as PackedScene).instantiate() as Caramelo
	_viewport.add_child(dog)
	dog.set_physics_process(false)
	dog.position = Vector2(880.0, 860.0)
	if seed_value >= 0:
		dog.set_random_seed(seed_value)
	dog.set_walkable_polygon(_polygon_from_backyard())
	var trace: Array = []
	var previous := dog.get_current_state()
	for _i in int(round(180.0 / STEP)):
		dog.simulate(STEP)
		var current := dog.get_current_state()
		if current != previous:
			trace.append("%s@%s" % [Caramelo.state_name(current), dog.get_destination().round()])
			previous = current
	dog.free()
	return trace


func _test_follows_backyard_transform() -> void:
	_group_name("16. Caramelo acompanha a transformacao do Backyard")
	for window in [Vector2i(1920, 1080), Vector2i(1024, 768), Vector2i(3440, 1440), Vector2i(640, 1000)]:
		var factor: float = minf(float(window.x) / 1920.0, float(window.y) / 1080.0)
		var sub := SubViewport.new()
		sub.size = Vector2i(int(round(float(window.x) / factor)), int(round(float(window.y) / factor)))
		root.add_child(sub)
		var main := (load(MAIN_SCENE) as PackedScene).instantiate()
		sub.add_child(main)
		var backyard := main.get_node("World/Backyard") as Node2D
		var dog := main.get_node("World/Backyard/CharacterLayer/Caramelo") as Caramelo
		var expected_global: Vector2 = backyard.get_global_transform() * dog.position
		var dog_scale: Vector2 = dog.get_global_transform().get_scale()
		var yard_scale: Vector2 = backyard.get_global_transform().get_scale()
		_check(dog_scale.is_equal_approx(yard_scale),
			"janela %dx%d: escala de Caramelo %s = escala do quintal %s"
				% [window.x, window.y, dog_scale.snappedf(0.0001), yard_scale.snappedf(0.0001)])
		_check(dog.global_position.distance_to(expected_global) < 0.01,
			"janela %dx%d: posicao global segue a transformacao do quintal" % [window.x, window.y])
		sub.free()


func _test_main_scene_has_one_caramelo() -> void:
	_group_name("17. A cena principal instancia exatamente um Caramelo")
	var sub := SubViewport.new()
	sub.size = Vector2i(1920, 1080)
	root.add_child(sub)
	var main := (load(MAIN_SCENE) as PackedScene).instantiate()
	sub.add_child(main)
	var found: Array = []
	var queue: Array = [main]
	while not queue.is_empty():
		var node: Node = queue.pop_back()
		if node is Caramelo:
			found.append(main.get_path_to(node))
		for child in node.get_children():
			queue.append(child)
	_check(found.size() == 1, "%d Caramelo(s) na cena principal: %s" % [found.size(), found])
	if found.size() == 1:
		var dog := main.get_node(found[0]) as Caramelo
		var polygon := _polygon_from_backyard()
		_check(_inside_with_margin(dog.position, polygon),
			"posicao inicial %s valida na area caminhavel" % dog.position)
		_check(dog.get_parent().name == "CharacterLayer",
			"instanciado em CharacterLayer (pai = %s)" % dog.get_parent().name)
		_check(dog.get_parent().y_sort_enabled, "CharacterLayer com y_sort_enabled")
	sub.free()


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
