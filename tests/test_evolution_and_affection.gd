extends SceneTree
## Testes permanentes da evolucao visual e do sistema de carinho.
##
## Executar:  godot --headless --path . --script tests/test_evolution_and_affection.gd

const STEP := 1.0 / 60.0
const DIR := "test_evolution"

var _passed := 0
var _failures: Array[String] = []
var _group := ""
var _done := false
var _viewport: SubViewport
var _config: GameConfig


class World:
	extends RefCounted
	var main: Node
	var session: GameSession
	var model: ProgressionModel
	var dog: Caramelo
	var visual: Node2D
	var evolution: EvolutionSystem
	var affection: AffectionSystem
	var feeding: FeedingSystem
	var exercise: ExerciseSystem
	var rest: RestSystem
	var save: SaveManager
	var hud: Control

	func _init(viewport: SubViewport) -> void:
		main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
		viewport.add_child(main)
		session = _find(main, func(n: Node) -> bool: return n is GameSession) as GameSession
		evolution = _find(main, func(n: Node) -> bool: return n is EvolutionSystem) as EvolutionSystem
		affection = _find(main, func(n: Node) -> bool: return n is AffectionSystem) as AffectionSystem
		feeding = _find(main, func(n: Node) -> bool: return n is FeedingSystem) as FeedingSystem
		exercise = _find(main, func(n: Node) -> bool: return n is ExerciseSystem) as ExerciseSystem
		rest = _find(main, func(n: Node) -> bool: return n is RestSystem) as RestSystem
		save = _find(main, func(n: Node) -> bool: return n is SaveManager) as SaveManager
		dog = _find(main, func(n: Node) -> bool: return n is Caramelo) as Caramelo
		hud = _find(main, func(n: Node) -> bool: return n.is_in_group(&"main_hud")) as Control
		visual = dog.get_node("Visual") as Node2D
		model = session.get_model()
		dog.set_physics_process(false)
		for node in [feeding, rest, evolution, affection, save, hud]:
			if node != null:
				node.set_process(false)

	static func _find(from: Node, predicate: Callable) -> Node:
		var queue: Array[Node] = [from]
		while not queue.is_empty():
			var node: Node = queue.pop_front()
			if predicate.call(node):
				return node
			for child in node.get_children():
				queue.append(child)
		return null

	## Avanca cachorro, visual e fila de apresentacoes juntos.
	func run(seconds: float) -> void:
		for _i in int(round(seconds / (1.0 / 60.0))):
			dog.simulate(1.0 / 60.0)
			visual._process(1.0 / 60.0)
			evolution.simulate(1.0 / 60.0)
			affection.simulate(1.0 / 60.0)

	func run_until_state(state: int, limit: float = 90.0) -> bool:
		for _i in int(round(limit / (1.0 / 60.0))):
			if dog.get_current_state() == state:
				return true
			run(1.0 / 60.0)
		return dog.get_current_state() == state

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
	SaveManager.persistence_enabled = false
	_config = GameConfig.load_default()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	root.add_child(_viewport)

	_test_forms()
	_test_level_events()
	_test_affection()
	_test_bond_behaviors()
	_test_save_and_migration()
	_test_ui()
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
# 1-12. Formas
# --------------------------------------------------------------------------------------

func _test_forms() -> void:
	_g("1-6. A forma e derivada do nivel; existem exatamente duas")
	_check(BodyForms.FORM_NAMES.size() == 2,
		"%d formas: %s" % [BodyForms.FORM_NAMES.size(), str(BodyForms.FORM_NAMES)])
	for entry in [[1, BodyForms.Form.INITIAL], [2, BodyForms.Form.INITIAL],
			[3, BodyForms.Form.INITIAL], [4, BodyForms.Form.MUSCULAR], [5, BodyForms.Form.MUSCULAR]]:
		_check(BodyForms.form_for_level(int(entry[0])) == int(entry[1]),
			"nivel %d -> %s" % [entry[0], BodyForms.form_name(BodyForms.form_for_level(int(entry[0])))])
	_check(BodyForms.form_for_level(5) == BodyForms.form_for_level(4),
		"o nivel 5 reaproveita a forma do 4: nao ha terceira")

	_g("7-8. Identidade preservada, silhueta alterada")
	var initial: Dictionary = BodyForms.INITIAL
	var muscular: Dictionary = BodyForms.MUSCULAR
	for key in ["Tail/TailShape"]:
		_check(initial[key] == muscular[key], "%s identico nas duas formas" % key)
	var head_nodes := ["Skull", "Muzzle", "Nose", "Eye", "EarNear", "EarFar"]
	var w := _world()
	var before: Dictionary = {}
	for name in head_nodes:
		before[name] = (w.visual.get_node("Head/" + name) as Polygon2D).polygon
	var color_before := (w.visual.get_node("Body/Torso") as Polygon2D).color
	w.dog.apply_body_form(BodyForms.Form.MUSCULAR, false)
	for name in head_nodes:
		_check((w.visual.get_node("Head/" + name) as Polygon2D).polygon == before[name],
			"%s intacto na forma musculosa" % name)
	_check((w.visual.get_node("Body/Torso") as Polygon2D).color == color_before,
		"a cor caramelo nao muda")

	var initial_torso: PackedVector2Array = initial["Body/Torso"]
	var muscular_torso: PackedVector2Array = muscular["Body/Torso"]
	_check(_width(muscular_torso) > _width(initial_torso) * 1.1,
		"peito mais largo: %.0f -> %.0f" % [_width(initial_torso), _width(muscular_torso)])
	_check(_height(muscular_torso) > _height(initial_torso),
		"ombro mais volumoso: %.0f -> %.0f" % [_height(initial_torso), _height(muscular_torso)])
	_check(_width(muscular["LegsFront/LegFrontNear"]) > _width(initial["LegsFront/LegFrontNear"]),
		"patas dianteiras mais grossas")

	_g("9-12. Colisao, selecao e posicao logica")
	var capsule := (w.dog.get_node("CollisionShape2D") as CollisionShape2D).shape as CapsuleShape2D
	var rectangle := (w.dog.get_node("SelectionArea/CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var muscular_radius := capsule.radius
	var muscular_selection := rectangle.size
	var position_before := w.dog.position
	w.dog.apply_body_form(BodyForms.Form.INITIAL, false)
	_check(capsule.radius < muscular_radius,
		"colisao acompanha a forma: %.1f (inicial) < %.1f (musculosa)" % [capsule.radius, muscular_radius])
	_check(rectangle.size.x < muscular_selection.x,
		"area de selecao acompanha: %.0f < %.0f" % [rectangle.size.x, muscular_selection.x])
	_check(w.dog.position == position_before, "a posicao logica nao muda com a forma")

	var polygon: PackedVector2Array = (w.main.get_node(
		"World/Backyard/WorldBounds/WalkableCollision") as CollisionPolygon2D).polygon
	w.dog.apply_body_form(BodyForms.Form.MUSCULAR, false)
	_check(Geometry2D.is_point_in_polygon(w.dog.position, polygon),
		"a forma musculosa continua com as patas na area caminhavel")
	var half: Vector2 = (muscular["_selection"] as Dictionary)["size"]
	_check(half.x < 200.0 and half.y < 130.0,
		"e a silhueta continua compacta: %s" % half)
	w.free_all()


func _width(points: PackedVector2Array) -> float:
	var lo := INF
	var hi := -INF
	for point in points:
		lo = minf(lo, point.x)
		hi = maxf(hi, point.x)
	return hi - lo


func _height(points: PackedVector2Array) -> float:
	var lo := INF
	var hi := -INF
	for point in points:
		lo = minf(lo, point.y)
		hi = maxf(hi, point.y)
	return hi - lo


# --------------------------------------------------------------------------------------
# 13-22. Eventos de nivel
# --------------------------------------------------------------------------------------

func _test_level_events() -> void:
	_g("13-17. Cada nivel produz o seu evento, sem perder nenhum")
	var w := _world()
	var shown: Array = []
	w.evolution.presentation_started.connect(func(id: StringName) -> void: shown.append(String(id)))
	w.model.add_strength(25)                                  # nivel 2
	w.run(0.1)
	_check(shown == ["level_2"], "nivel 2: %s" % str(shown))
	_check(w.dog.get_body_form() == BodyForms.Form.INITIAL, "e a forma continua inicial")
	w.run(3.0)

	shown.clear()
	w.model.add_strength(45)                                  # nivel 3
	w.run(3.0)
	_check(shown.is_empty(), "nivel 3 nao produz forma nem comemoracao: %s" % str(shown))
	_check(w.dog.get_body_form() == BodyForms.Form.INITIAL, "forma ainda inicial no nivel 3")

	shown.clear()
	var evolutions: Array = []
	w.evolution.evolution_started.connect(func(level: int) -> void: evolutions.append(level))
	w.model.add_strength(70)                                  # nivel 4
	w.run(0.1)
	_check(shown == ["level_4"], "nivel 4: %s" % str(shown))
	_check(evolutions == [4], "evolution_started uma vez: %s" % str(evolutions))
	_check(w.dog.get_body_form() == BodyForms.Form.MUSCULAR, "trocou para a forma musculosa")
	w.run(3.0)

	shown.clear()
	w.model.add_strength(110)                                 # nivel 5
	w.run(0.1)
	_check(shown == ["level_5"], "nivel 5: %s" % str(shown))
	_check(w.dog.get_body_form() == BodyForms.Form.MUSCULAR, "sem terceira forma no nivel 5")
	w.free_all()

	_g("17. Ganhar varios niveis de uma vez nao perde eventos")
	var w2 := _world()
	var all_shown: Array = []
	w2.evolution.presentation_started.connect(func(id: StringName) -> void: all_shown.append(String(id)))
	w2.model.add_strength(250)                                # do 1 ao 5 de uma vez
	w2.run(12.0)
	_check(all_shown.has("level_4") and all_shown.has("level_5") and all_shown.has("level_2"),
		"todos os eventos do caminho aconteceram: %s" % str(all_shown))
	_check(all_shown.count("level_4") == 1, "e nenhum duplicou")
	_check(all_shown[0] == "level_4", "a transformacao tem prioridade: %s" % str(all_shown))
	w2.free_all()

	_g("18-20. Evento durante treino e adiado, acontece depois e nao duplica")
	var w3 := _world()
	var deferred: Array = []
	w3.evolution.presentation_started.connect(func(id: StringName) -> void: deferred.append(String(id)))
	w3.model.add_strength(135)                                # forca 135, nivel 3
	w3.run(6.0)
	deferred.clear()
	_check(w3.exercise.request_exercise(&"push_ups"), "treino iniciado")
	_check(w3.run_until_state(Caramelo.State.TRAINING), "em TRAINING")
	w3.model.add_strength(5)                                  # forca 140 -> nivel 4
	_check(w3.model.get_level() == 4, "a progressao acontece na hora: nivel %d" % w3.model.get_level())
	w3.run(2.0)
	_check(deferred.is_empty(), "mas a animacao espera: %s" % str(deferred))
	_check(w3.dog.get_current_state() == Caramelo.State.TRAINING, "o treino nao foi interrompido")
	_check(w3.evolution.get_queue().has(&"level_4"), "o evento ficou na fila")
	for _i in 5400:
		if w3.exercise.has_pending_exercise():
			w3.run(STEP)
		else:
			break
	w3.run(6.0)
	_check(deferred.count("level_4") == 1, "acontece uma vez quando ele fica livre: %s" % str(deferred))
	_check(w3.dog.get_body_form() == BodyForms.Form.MUSCULAR, "e a forma troca")
	w3.free_all()

	_g("21-22. Carregar um nivel alto aplica a forma em silencio")
	var w4 := _world()
	var quiet: Array = []
	w4.evolution.presentation_started.connect(func(id: StringName) -> void: quiet.append(String(id)))
	w4.model.restore(70, 250, 0)                              # nivel 5 restaurado
	w4.run(4.0)
	_check(w4.model.get_level() == 5, "nivel 5 restaurado")
	_check(w4.dog.get_body_form() == BodyForms.Form.MUSCULAR, "forma musculosa aplicada")
	_check(quiet.is_empty(), "sem comemoracao, transformacao ou pose final: %s" % str(quiet))
	_check(w4.evolution.get_queue().is_empty(), "e a fila fica vazia")
	w4.free_all()


# --------------------------------------------------------------------------------------
# 23-36. Carinho
# --------------------------------------------------------------------------------------

func _test_affection() -> void:
	_g("23-28. Carinho dá +1 vínculo e inicia a recarga")
	var affection_config := _config.get_affection()
	_check(int(affection_config["pet_bond_gain"]) == 1,
		"ganho do JSON: %d" % int(affection_config["pet_bond_gain"]))
	_check(is_equal_approx(float(affection_config["pet_cooldown_seconds"]), 60.0),
		"recarga do JSON: %.0f s" % float(affection_config["pet_cooldown_seconds"]))
	_check(is_equal_approx(float(affection_config["rare_behavior_chance"]), 0.10),
		"chance rara do JSON: %.2f" % float(affection_config["rare_behavior_chance"]))

	var w := _world()
	var completed: Array = []
	w.affection.pet_completed.connect(func(bond: int) -> void: completed.append(bond))
	_check(w.affection.request_pet(), "carinho aceito")
	_check(w.model.get_bond() == 1, "vinculo = %d" % w.model.get_bond())
	_check(completed == [1], "pet_completed(1): %s" % str(completed))
	_check(is_equal_approx(w.affection.get_cooldown_remaining(), 60.0),
		"recarga iniciada: %.0f s" % w.affection.get_cooldown_remaining())
	_check(w.model.get_energy() == 70 and w.model.get_strength() == 0,
		"e nada de energia ou forca: %d / %d" % [w.model.get_energy(), w.model.get_strength()])

	_g("27-28, 34. Cliques repetidos rendem um unico ganho")
	var accepted := 0
	for _i in 10:
		if w.affection.request_pet():
			accepted += 1
	_check(accepted == 0, "mais 10 cliques em recarga: %d aceitos" % accepted)
	_check(w.model.get_bond() == 1, "vinculo continua 1 apos 11 cliques seguidos")

	_g("35-36. Recarga chega a zero e nunca fica negativa")
	w.affection.simulate(30.0)
	_check(is_equal_approx(w.affection.get_cooldown_remaining(), 30.0),
		"restam %.0f s" % w.affection.get_cooldown_remaining())
	w.affection.simulate(100.0)
	_check(w.affection.get_cooldown_remaining() == 0.0, "chega exatamente a zero")
	_check(w.affection.is_available(), "e volta a ficar disponivel")
	_check(w.affection.request_pet() and w.model.get_bond() == 2, "novo carinho aceito")
	w.free_all()

	_g("29-33. Atividades que bloqueiam e estados que aceitam")
	var w2 := _world()
	var rejections: Array = []
	w2.affection.pet_rejected.connect(func(reason: int) -> void:
		rejections.append(AffectionSystem.rejection_name(reason)))
	w2.feeding.request_feeding(&"kibble")
	_check(not w2.affection.request_pet(), "refeicao a caminho bloqueia")
	_check(rejections[-1] == "ACTIVITY_RESERVED", "codigo = %s" % rejections[-1])
	_check(w2.run_until_state(Caramelo.State.EATING), "chegou ao pote")
	_check(not w2.affection.request_pet(), "EATING bloqueia")
	_check(rejections[-1] == "DOG_BUSY", "codigo = %s" % rejections[-1])
	_check(w2.model.get_bond() == 0, "nenhum vinculo creditado nas recusas")
	w2.free_all()

	var w3 := _world()
	w3.exercise.request_exercise(&"push_ups")
	w3.run_until_state(Caramelo.State.TRAINING)
	_check(not w3.affection.request_pet(), "TRAINING bloqueia")
	w3.free_all()

	_g("32-33. RESTING e caminhada autonoma aceitam sem mudar nada")
	var w4 := _world()
	w4.dog.request_state(Caramelo.State.RESTING)
	_check(w4.affection.request_pet(), "carinho aceito durante o descanso")
	_check(w4.dog.get_current_state() == Caramelo.State.RESTING,
		"e o descanso continua: %s" % Caramelo.state_name(w4.dog.get_current_state()))
	_check(w4.model.get_bond() == 1, "vinculo creditado")
	w4.free_all()

	var w5 := _world()
	w5.dog.set_random_seed(4242)
	var walking := false
	for _i in 3600:
		w5.run(STEP)
		if w5.dog.get_current_state() == Caramelo.State.WALKING:
			walking = true
			break
	_check(walking, "entrou em caminhada autonoma")
	var destination := w5.dog.get_destination()
	_check(w5.affection.request_pet(), "carinho aceito caminhando")
	_check(w5.dog.get_current_state() == Caramelo.State.WALKING, "continua caminhando")
	_check(w5.dog.get_destination() == destination, "e o destino logico nao muda")
	w5.free_all()


# --------------------------------------------------------------------------------------
# 37-48. Comportamentos de vinculo
# --------------------------------------------------------------------------------------

func _test_bond_behaviors() -> void:
	_g("37-40. Cada faixa de vinculo libera o seu comportamento")
	var w := _world()
	var behaviors: Array = []
	w.affection.affection_behavior_started.connect(func(id: StringName) -> void:
		behaviors.append(String(id)))
	w.affection.set_random_seed(1)
	w.affection.request_pet()
	_check(behaviors[-1] == "simple_affection",
		"abaixo de 10: reacao simples (%s)" % behaviors[-1])

	w.model.add_bond(20)                                       # vinculo 21
	w.affection.simulate(120.0)
	w.affection.request_pet()
	_check(behaviors[-1] == "petting_reaction",
		"a partir de 10: reacao especial (%s)" % behaviors[-1])
	_check(w.affection.get_unlocked_behaviors().has("petting_reaction"), "comportamento liberado")

	w.model.add_bond(10)                                       # vinculo 32
	_check(w.affection.get_unlocked_behaviors().has("startup_celebration"),
		"a partir de 25: comemoracao de inicio liberada")
	w.model.add_bond(30)                                       # vinculo 62
	_check(w.affection.get_unlocked_behaviors().has("rare_affection_idle"),
		"a partir de 50: animacao rara liberada")
	_check(w.model.get_strength() == 0 and w.model.get_energy() == 70,
		"e o vinculo nunca deu forca nem energia")
	w.free_all()

	_g("41-44. Comemoracao de inicio: uma vez por sessao, nunca antes de session_ready")
	var w2 := _world()
	w2.model.add_bond(30)
	_check(w2.affection.try_startup_celebration(), "aconteceu")
	_check(not w2.affection.try_startup_celebration(), "e nao se repete na mesma sessao")
	w2.affection.set_session_ready(false)
	_check(not w2.affection.request_pet(), "antes de session_ready nada acontece")
	w2.affection.set_session_ready(true)
	w2.affection.set_interaction_blocked(true)
	_check(not w2.affection.request_pet(), "com o resumo offline na tela tambem nao")
	w2.affection.set_interaction_blocked(false)
	w2.free_all()

	var w3 := _world()
	w3.model.add_bond(30)
	w3.exercise.request_exercise(&"push_ups")
	w3.run_until_state(Caramelo.State.TRAINING)
	var started: Array = []
	w3.evolution.presentation_started.connect(func(id: StringName) -> void: started.append(String(id)))
	_check(w3.affection.try_startup_celebration(), "a comemoracao e enfileirada")
	w3.run(2.0)
	_check(started.is_empty(), "mas espera o treino terminar: %s" % str(started))
	_check(w3.dog.get_current_state() == Caramelo.State.TRAINING,
		"e a atividade em andamento nao e interrompida")
	for _i in 5400:
		if w3.exercise.has_pending_exercise():
			w3.run(STEP)
		else:
			break
	w3.run(6.0)
	_check(started.count("startup_celebration") == 1,
		"e acontece uma unica vez depois: %s" % str(started))
	w3.free_all()

	_g("45-47. Animacao rara: chance do JSON, reproduzivel, sem alterar atributos")
	var counts: Array = []
	for seed_value in [7, 7, 99]:
		counts.append(_rare_runs(seed_value, 60))
	_check(counts[0] == counts[1], "semente fixa reproduz: %d e %d" % [counts[0], counts[1]])
	_check(counts[0] >= 1, "resultado verdadeiro observado (%d de 60)" % counts[0])
	_check(counts[0] <= 20, "e falso tambem (%d de 60, chance 10%%)" % counts[0])

	var w4 := _world()
	w4.affection.set_random_seed(7)
	w4.model.add_bond(60)
	var bond_before := w4.model.get_bond()
	for _i in 20:
		w4.affection.simulate(120.0)
		w4.affection.request_pet()
	_check(w4.model.get_bond() == bond_before + 20,
		"cada carinho rendeu exatamente +1, com e sem reacao rara: %d" % w4.model.get_bond())
	_check(w4.model.get_strength() == 0, "e a forca continua 0")
	w4.free_all()

	_g("48. O comportamento e so apresentacao: nao mexe no estado publico")
	var w5 := _world()
	w5.model.add_bond(60)
	w5.affection.set_random_seed(7)
	w5.dog.request_state(Caramelo.State.RESTING)
	var state_before := w5.dog.get_current_state()
	var position_before := w5.dog.position
	var remaining_before := w5.dog.get_state_remaining()
	var snapshot_before := w5.model.get_snapshot()
	w5.affection.request_pet()
	w5.run(2.0)
	_check(w5.dog.get_current_state() == state_before,
		"estado intacto: %s" % Caramelo.state_name(w5.dog.get_current_state()))
	_check(w5.dog.position == position_before, "posicao logica intacta")
	_check(w5.dog.get_state_remaining() < remaining_before,
		"o descanso seguiu contando normalmente")
	_check(int(w5.model.get_snapshot()["bond"]) == int(snapshot_before["bond"]) + 1
		and int(w5.model.get_snapshot()["energy"]) == int(snapshot_before["energy"])
		and int(w5.model.get_snapshot()["strength"]) == int(snapshot_before["strength"]),
		"so o vinculo mudou: %s" % str(w5.model.get_snapshot()))
	w5.free_all()


func _rare_runs(seed_value: int, count: int) -> int:
	var w := _world()
	w.affection.set_random_seed(seed_value)
	w.model.add_bond(60)
	var rare := 0
	w.affection.affection_behavior_started.connect(func(id: StringName) -> void:
		if id == &"rare_affection_idle":
			rare += 1)
	var seen: Array = []
	w.affection.affection_behavior_started.connect(func(id: StringName) -> void:
		seen.append(String(id)))
	for _i in count:
		w.affection.simulate(120.0)
		w.affection.request_pet()
	w.free_all()
	return seen.count("rare_affection_idle")


# --------------------------------------------------------------------------------------
# 49-65. Save e migracao
# --------------------------------------------------------------------------------------

func _v1_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"saved_at_unix": 1_000_000,
		"progression": {"energy": 55, "strength": 80, "bond": 12},
		"food_cooldowns": {"kibble": 120.0},
		"rest": {"accumulated_seconds": 33.5},
		"dog": {"position": {"x": 900.0, "y": 850.0}, "facing": -1},
		"activity": {"type": "exercise", "phase": "running", "content_id": "push_ups",
			"remaining_seconds": 9.0, "energy_already_spent": true,
			"reward_already_applied": false, "target_id": "PushUpsPoint"},
	}


## Migracao v1 -> v2, isolada para que uma recusa inesperada nao aborte o teardown do save.
func _migration_checks(manager: SaveManager) -> void:
	_g("53-59. Migracao v1 -> v2")
	var migrated := manager.migrate(_v1_snapshot(), _config, 100)
	var payload: Variant = migrated["snapshot"]
	if not _check(payload is Dictionary, "save v1 aceito: %s" % migrated["reason"]):
		return
	var final: Dictionary = payload
	_check(int(migrated["from_version"]) == 1, "origem registrada: v%d" % int(migrated["from_version"]))
	_check(int(final["schema_version"]) == 2, "atualizado para v%d" % int(final["schema_version"]))
	_check(is_zero_approx(float((final["affection"] as Dictionary)["cooldown_remaining"])),
		"recarga do carinho comeca zerada")
	var progression: Dictionary = final["progression"]
	_check(int(progression["energy"]) == 55 and int(progression["strength"]) == 80
		and int(progression["bond"]) == 12, "atributos preservados: %s" % str(progression))
	_check(is_equal_approx(float((final["food_cooldowns"] as Dictionary)["kibble"]), 120.0),
		"recargas de comida preservadas")
	_check(is_equal_approx(float((final["rest"] as Dictionary)["accumulated_seconds"]), 33.5),
		"acumulador de descanso preservado")
	_check((final["activity"] as Dictionary)["content_id"] == "push_ups",
		"atividade preservada")
	_check(is_equal_approx(float(((final["dog"] as Dictionary)["position"] as Dictionary)["x"]), 900.0)
		and int((final["dog"] as Dictionary)["facing"]) == -1, "posicao e direcao preservadas")

	var again := manager.migrate(final, _config, 100)
	_check(int(again["from_version"]) == 2 and (again["snapshot"] as Dictionary) == final,
		"migracao e idempotente: um v2 passa direto")

	_g("60-61. Falhas e versao futura")
	var broken := _v1_snapshot()
	(broken["progression"] as Dictionary)["energy"] = 999
	var refused := manager.migrate(broken, _config, 100)
	_check(refused["snapshot"] == null, "v1 invalido e recusado antes de migrar: %s" % refused["reason"])
	var future := _v1_snapshot()
	future["schema_version"] = 99
	_check(manager.migrate(future, _config, 100)["snapshot"] == null, "versao futura recusada")


func _test_save_and_migration() -> void:
	_g("49-52. Save novo usa v2 e nao persiste forma nem nivel")
	SaveManager.persistence_enabled = true
	SaveManager.use_isolated_directory(DIR)
	var w := _world()
	w.model.restore(60, 150, 30)
	var snapshot := w.save.build_snapshot(1_000_000)
	_check(int(snapshot["schema_version"]) == 2, "versao %d" % int(snapshot["schema_version"]))
	_check((snapshot["affection"] as Dictionary).has("cooldown_remaining"),
		"traz a recarga do carinho")
	var text := JSON.stringify(snapshot)
	for forbidden in ["body_form", "MUSCULAR", "\"level\"", "unlocks"]:
		_check(not text.contains(forbidden), "o save nao guarda '%s'" % forbidden)

	_migration_checks(w.save)

	_g("62-65. Recarga do carinho offline e sem duplicacao")
	var with_cooldown := w.save.build_snapshot(1_000_000)
	(with_cooldown["affection"] as Dictionary)["cooldown_remaining"] = 45.0
	var reconciled := OfflineProgress.reconcile(with_cooldown, _config, 1_000_030, 100)
	var out: Dictionary = (reconciled["snapshot"] as Dictionary)["affection"]
	_check(is_equal_approx(float(out["cooldown_remaining"]), 15.0),
		"30 s de ausencia deixam %.0f s" % float(out["cooldown_remaining"]))
	var long_gap := OfflineProgress.reconcile(with_cooldown.duplicate(true), _config, 1_100_000, 100)
	_check(float(((long_gap["snapshot"] as Dictionary)["affection"] as Dictionary)["cooldown_remaining"]) == 0.0,
		"ausencia longa zera, sem ficar negativa")
	var backwards := OfflineProgress.reconcile(with_cooldown.duplicate(true), _config, 900_000, 100)
	_check(is_equal_approx(float(((backwards["snapshot"] as Dictionary)["affection"] as Dictionary)
		["cooldown_remaining"]), 45.0), "relogio regressivo nao reduz a recarga")
	var bond_after := int(((long_gap["snapshot"] as Dictionary)["progression"] as Dictionary)["bond"])
	_check(bond_after == w.model.get_bond(), "e nenhum vinculo e concedido offline")

	_g("78. Reconciliar de novo nao aplica a mesma ausencia duas vezes")
	var pending: Dictionary = (_migrated_v1() as Dictionary)
	var once := OfflineProgress.reconcile(pending, _config, 1_000_100, 100)
	var first: Dictionary = once["snapshot"]
	var twice := OfflineProgress.reconcile(first.duplicate(true), _config, 1_000_100, 100)
	var second: Dictionary = twice["snapshot"]
	_check(String((once["report"] as Dictionary)["exercise_completed"]) != ""
		and int((first["progression"] as Dictionary)["strength"]) > 80,
		"o treino pendente terminou na primeira vez: forca %d"
			% int((first["progression"] as Dictionary)["strength"]))
	_check(second["progression"] == first["progression"],
		"e a segunda passagem nao mexe em nada: %s" % str(second["progression"]))
	_check(String((twice["report"] as Dictionary)["exercise_completed"]) == "",
		"nem repete o evento")
	w.free_all()

	_test_save_files()
	SaveManager.clear_isolated_directory()
	SaveManager.persistence_enabled = false


## Snapshot v1 do exercicio pendente, ja atualizado para a versao 2.
func _migrated_v1() -> Variant:
	var manager := SaveManager.new()
	root.add_child(manager)
	var migrated := manager.migrate(_v1_snapshot(), _config, 100)
	manager.free()
	return migrated["snapshot"]


## Ciclo completo em disco, no diretorio isolado: backup antigo, recusa e reabertura.
func _test_save_files() -> void:
	SaveManager.use_isolated_directory(DIR)
	var directory := SaveManager.directory_override
	var main_path := "%s/savegame.json" % directory
	var backup_path := "%s/savegame.backup.json" % directory
	var rejected_path := "%s/savegame.rejected.json" % directory

	_g("58. Um backup ainda na versao 1 e aceito e migrado")
	var w := _world()
	# A sessao recem-criada ja gravou o jogo novo; o teste quer so o backup antigo no disco.
	_remove(main_path)
	_remove(backup_path)
	_write(backup_path, JSON.stringify(_v1_snapshot()))
	var from_backup := w.save.load_snapshot(100)
	_check(int(from_backup["source"]) == SaveManager.Source.BACKUP,
		"origem: %s" % SaveManager.source_name(int(from_backup["source"])))
	var recovered: Dictionary = from_backup["snapshot"]
	_check(int(recovered["schema_version"]) == 2, "chegou na versao %d" % int(recovered["schema_version"]))
	_check(int((recovered["progression"] as Dictionary)["strength"]) == 80,
		"com os atributos do backup")

	_g("60. Um principal invalido e recusado e preservado sem alteracao")
	var broken := _v1_snapshot()
	(broken["progression"] as Dictionary)["energy"] = 999
	var broken_text := JSON.stringify(broken)
	_write(main_path, broken_text)
	var refused := w.save.load_snapshot(100)
	_check(int(refused["source"]) != SaveManager.Source.MAIN, "o principal nao foi usado")
	_check(FileAccess.file_exists(rejected_path), "uma copia intacta foi guardada")
	_check(FileAccess.get_file_as_string(rejected_path) == broken_text,
		"byte a byte igual ao arquivo original")
	w.free_all()

	_g("64-65. Reabrir mantem o vinculo e nao repete evento visual")
	SaveManager.use_isolated_directory(DIR)
	var w2 := _world()
	w2.model.restore(70, 250, 0)
	w2.run(3.0)
	_check(w2.affection.request_pet() and w2.model.get_bond() == 1, "carinho antes de fechar")
	_check(w2.save.save_now(), "sessao gravada")
	w2.free_all()

	var w3 := _world()
	var replayed: Array = []
	w3.evolution.presentation_started.connect(func(id: StringName) -> void: replayed.append(String(id)))
	w3.run(4.0)
	_check(w3.model.get_bond() == 1, "vinculo reaberto: %d" % w3.model.get_bond())
	_check(w3.model.get_level() == 5, "nivel %d restaurado" % w3.model.get_level())
	_check(w3.dog.get_body_form() == BodyForms.Form.MUSCULAR, "forma musculosa aplicada de novo")
	_check(replayed.is_empty(), "e nenhum evento visual se repete: %s" % str(replayed))
	var remaining := w3.affection.get_cooldown_remaining()
	_check(remaining > 0.0 and remaining <= 60.0,
		"a recarga do carinho veio junto: %.1f s" % remaining)
	_check(not w3.affection.request_pet(), "entao um novo carinho ainda e recusado")
	_check(w3.model.get_bond() == 1, "e o vinculo nao duplica: %d" % w3.model.get_bond())
	w3.free_all()


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("nao foi possivel escrever %s" % path)
		return
	file.store_string(text)
	file.close()


# --------------------------------------------------------------------------------------
# 66-73. Interface
# --------------------------------------------------------------------------------------

func _test_ui() -> void:
	_g("66-72. Botao de carinho no HUD, em dois cliques")
	var w := _world()
	var pet_button: Button = w.hud.get_node("Anchor/Panel/Layout/ActionBar/PetButton")
	_check(pet_button != null and pet_button.text == "Carinho",
		"quarto botao presente: '%s'" % pet_button.text)
	var buttons := (w.hud.get_node("Anchor/Panel/Layout/ActionBar") as Control).get_child_count()
	_check(buttons == 4, "%d botoes na barra de acoes" % buttons)

	w.dog.select()                                            # clique 1
	_check(w.hud.call("is_open"), "HUD aberto")
	_check(not pet_button.disabled, "botao habilitado")
	pet_button.pressed.emit()                                 # clique 2
	_check(w.model.get_bond() == 1, "o botao chamou o sistema: vinculo %d" % w.model.get_bond())
	_check(w.hud.call("get_toast_text") == "+1 vínculo",
		"toast do ganho real: '%s'" % w.hud.call("get_toast_text"))
	_check(pet_button.disabled, "em recarga, o botao desabilita")
	_check(pet_button.tooltip_text.contains(":"),
		"e o tooltip mostra o tempo: '%s'" % pet_button.tooltip_text)

	w.affection.simulate(120.0)
	w.hud.call("refresh")
	_check(not pet_button.disabled, "volta ao fim da recarga")
	w.exercise.request_exercise(&"push_ups")
	w.hud.call("refresh")
	_check(pet_button.disabled, "atividade reservada desabilita")

	_g("69. A interface nao altera o modelo")
	var source := FileAccess.get_file_as_string("res://scripts/ui/main_hud.gd")
	for forbidden in ["add_bond", "add_strength", "restore_energy", "try_spend_energy"]:
		_check(not source.contains(forbidden), "main_hud.gd nao chama '%s'" % forbidden)

	_g("73. O painel continua dentro da tela")
	var panel: Control = w.hud.get_node("Anchor/Panel")
	var anchor: Control = w.hud.get_node("Anchor")
	# Em headless nao ha janela, entao `UiScale.factor_for` satura no teto. Dividir por ele
	# devolve as medidas em pixels de tela: e assim que o painel aparece numa janela real
	# de 1920 x 1080, que e o que este SubViewport representa. As outras quatro resolucoes
	# ficam para a validacao visual.
	var factor := UiScale.factor_for(panel)
	var screen := Vector2(1920.0, 1080.0)
	var rect := Rect2(anchor.position / factor, panel.get_combined_minimum_size() / factor)
	_check(Rect2(Vector2.ZERO, screen).encloses(rect),
		"HUD %s dentro de %s" % [rect, screen])
	w.free_all()


# --------------------------------------------------------------------------------------
# 74-80. Regressao
# --------------------------------------------------------------------------------------

func _test_regression() -> void:
	_g("75-77. Alimentacao, treino e descanso seguem funcionais nas duas formas")
	for form in [BodyForms.Form.INITIAL, BodyForms.Form.MUSCULAR]:
		var w := _world()
		w.dog.apply_body_form(form, false)
		_check(w.feeding.request_feeding(&"kibble"), "%s: alimentacao aceita" % BodyForms.form_name(form))
		for _i in 5400:
			if not w.feeding.has_pending_meal():
				break
			w.run(STEP)
		_check(w.model.get_energy() == 90, "%s: energia %d" % [BodyForms.form_name(form), w.model.get_energy()])
		_check(w.exercise.request_exercise(&"push_ups"), "%s: treino aceito" % BodyForms.form_name(form))
		for _i in 5400:
			if not w.exercise.has_pending_exercise():
				break
			w.run(STEP)
		_check(w.model.get_strength() == 5, "%s: forca %d" % [BodyForms.form_name(form), w.model.get_strength()])
		_check(w.rest.request_rest(), "%s: descanso aceito" % BodyForms.form_name(form))
		w.free_all()

	_g("79-80. Cena e execucao sem interacao")
	var w2 := _world()
	var systems: Array = []
	var queue: Array[Node] = [w2.main]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		if node is AffectionSystem:
			systems.append(node)
		for child in node.get_children():
			queue.append(child)
	_check(systems.size() == 1, "%d AffectionSystem na cena" % systems.size())
	w2.dog.set_random_seed(77)
	w2.run(180.0)
	_check(w2.model.get_bond() == 0, "3 min sem interacao: vinculo %d" % w2.model.get_bond())
	_check(w2.model.get_strength() == 0, "e forca %d" % w2.model.get_strength())
	_check(w2.dog.get_body_form() == BodyForms.Form.INITIAL, "e a forma continua inicial")
	w2.free_all()


func _report() -> void:
	SaveManager.persistence_enabled = true
	SaveManager.clear_isolated_directory()
	print("\n" + "=".repeat(70))
	if _failures.is_empty():
		print("TODOS OS TESTES PASSARAM  (%d verificacoes)" % _passed)
		quit(0)
		return
	print("FALHAS: %d de %d verificacoes" % [_failures.size(), _passed + _failures.size()])
	for failure in _failures:
		print("  - " + failure)
	quit(1)
