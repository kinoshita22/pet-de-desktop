extends SceneTree
## Testes permanentes da configuracao, do modelo de atributos e da progressao.
##
## Executar:  godot --headless --path . --script tests/test_progression.gd
## Sai com 0 quando tudo passa e 1 caso contrario.
##
## Os casos negativos de configuracao montam dados errados **em memoria** ou escrevem em
## `user://`. Os arquivos reais de `data/` nunca sao tocados.

const LEVELS_PATH := "res://data/levels.json"
const FOODS_PATH := "res://data/foods.json"
const EXERCISES_PATH := "res://data/exercises.json"
const MAIN_SCENE := "res://scenes/main/main.tscn"
const CARAMELO_SCENE := "res://scenes/dog/caramelo.tscn"

var _passed := 0
var _failures: Array[String] = []
var _group := ""
var _done := false


class Spy:
	extends RefCounted
	var events: Array = []
	func on_energy(p: int, n: int) -> void: events.append(["energy", p, n])
	func on_strength(p: int, n: int) -> void: events.append(["strength", p, n])
	func on_bond(p: int, n: int) -> void: events.append(["bond", p, n])
	func on_level(p: int, n: int) -> void: events.append(["level", p, n])
	func on_unlock(id: StringName) -> void: events.append(["unlock", String(id)])
	func names() -> Array:
		var out: Array = []
		for e in events:
			out.append(e[0])
		return out
	func unlocks() -> Array:
		var out: Array = []
		for e in events:
			if e[0] == "unlock":
				out.append(e[1])
		return out


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	# Sem persistencia: esta suite nao testa save, e cada mundo criado aqui precisa
	# comecar limpo, sem carregar o estado deixado pelo mundo anterior.
	SaveManager.persistence_enabled = false

	_test_config_files()
	_test_config_relations()
	_test_config_rejection()
	_test_energy()
	_test_strength_and_level()
	_test_bond()
	_test_signals()
	_test_integration()
	_test_progression_arithmetic()

	_report()
	return true


# --------------------------------------------------------------------------------------
# Infraestrutura
# --------------------------------------------------------------------------------------

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


func _config() -> GameConfig:
	return GameConfig.load_default()


func _model() -> ProgressionModel:
	return ProgressionModel.new(_config())


func _raw(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Copia em memoria dos tres arquivos reais, para os testes negativos mutarem a vontade.
func _raw_set() -> Array:
	return [
		(_raw(LEVELS_PATH) as Dictionary).duplicate(true),
		(_raw(FOODS_PATH) as Dictionary).duplicate(true),
		(_raw(EXERCISES_PATH) as Dictionary).duplicate(true),
	]


func _rejects(label: String, mutate: Callable) -> void:
	var parts := _raw_set()
	mutate.call(parts[0], parts[1], parts[2])
	var config := GameConfig.from_dictionaries(parts[0], parts[1], parts[2])
	var ok := not config.is_valid and not config.errors.is_empty()
	_check(ok, "%s -> %s" % [label, config.errors[0] if not config.errors.is_empty() else "ACEITOU (deveria recusar)"])
	if ok:
		_check(config.get_levels().is_empty() and config.get_foods().is_empty(),
			"    dados continuam inacessiveis apos a recusa")


# --------------------------------------------------------------------------------------
# 1-11. Configuracao
# --------------------------------------------------------------------------------------

func _test_config_files() -> void:
	_g("1-4. Os tres JSON existem, sao validos e tem campos e IDs corretos")
	for path in [LEVELS_PATH, FOODS_PATH, EXERCISES_PATH]:
		_check(FileAccess.file_exists(path), "existe: " + path)
		_check(JSON.parse_string(FileAccess.get_file_as_string(path)) != null,
			"JSON sintaticamente valido: " + path)
	var config := _config()
	_check(config.is_valid, "configuracao real valida%s"
		% ("" if config.is_valid else " — " + config.describe_errors()))
	var ids: Dictionary = {}
	var duplicated := false
	for food in config.get_foods():
		if ids.has(food["id"]):
			duplicated = true
		ids[food["id"]] = true
	for exercise in config.get_exercises():
		if ids.has(exercise["id"]):
			duplicated = true
		ids[exercise["id"]] = true
	_check(not duplicated, "IDs de alimentos e exercicios sem duplicata (%d ids)" % ids.size())
	_check(config.get_foods().size() == 3, "3 alimentos carregados")
	_check(config.get_exercises().size() == 2, "2 exercicios carregados")

	_g("5-7. Tabela de niveis")
	var levels := config.get_levels()
	_check(levels.size() == 5, "5 niveis carregados")
	_check(int(levels[0]["required_strength"]) == 0, "nivel 1 comeca em forca 0")
	var increasing := true
	var previous := -1
	for entry in levels:
		if int(entry["required_strength"]) <= previous:
			increasing = false
		previous = int(entry["required_strength"])
	_check(increasing, "limiares estritamente crescentes: %s"
		% str(levels.map(func(e: Dictionary) -> int: return int(e["required_strength"]))))
	_check(config.get_max_level() == 5, "nivel maximo = %d" % config.get_max_level())

	_g("8-10. Exercicios")
	var push_ups := config.get_exercise(&"push_ups")
	var dumbbells := config.get_exercise(&"dumbbells")
	_check(int(push_ups["required_level"]) == 1, "flexoes liberadas no nivel 1")
	_check(int(dumbbells["required_level"]) == 3, "halteres liberados no nivel 3")
	_check(int(push_ups["energy_cost"]) == 15 and int(push_ups["duration_seconds"]) == 20
		and int(push_ups["strength_gain"]) == 5, "flexoes 15 energia / 20 s / +5")
	_check(int(dumbbells["energy_cost"]) == 25 and int(dumbbells["duration_seconds"]) == 30
		and int(dumbbells["strength_gain"]) == 9, "halteres 25 energia / 30 s / +9")
	var chances_ok := true
	for exercise in config.get_exercises():
		var chance := float(exercise["comic_reaction_chance"])
		if chance < 0.0 or chance > 1.0:
			chances_ok = false
	_check(chances_ok, "chances comicas dentro de [0, 1] (%.2f)"
		% float(push_ups["comic_reaction_chance"]))

	_g("Alimentos conforme o MVP_SPEC secao 12")
	for expected in [["kibble", 20, 1, 300], ["chicken_rice", 35, 2, 900], ["cheese_bread", 15, 3, 600]]:
		var food := config.get_food(StringName(expected[0]))
		_check(not food.is_empty() and int(food["energy"]) == int(expected[1])
			and int(food["bond"]) == int(expected[2])
			and int(food["cooldown_seconds"]) == int(expected[3]),
			"%s: +%d energia, +%d vinculo, %d s de recarga"
				% [expected[0], expected[1], expected[2], expected[3]])


func _test_config_relations() -> void:
	_g("11. Relacoes entre os arquivos")
	var config := _config()
	var consistent := true
	for exercise in config.get_exercises():
		var unlock_level := config.get_level_of_unlock(StringName(exercise["unlock_id"]))
		if unlock_level != int(exercise["required_level"]):
			consistent = false
	_check(consistent, "todo 'unlock_id' existe em levels.json no mesmo 'required_level'")
	_check(config.get_level_of_unlock(&"push_ups") == 1, "desbloqueio 'push_ups' esta no nivel 1")
	_check(config.get_level_of_unlock(&"dumbbells") == 3, "desbloqueio 'dumbbells' esta no nivel 3")
	_check(config.get_level_of_unlock(&"inexistente") == 0, "desbloqueio desconhecido devolve 0")
	var behaviors := config.get_bond_behaviors()
	_check(behaviors.size() == 3, "3 comportamentos de vinculo")
	_check(int(behaviors[0]["required_bond"]) == 10 and int(behaviors[1]["required_bond"]) == 25
		and int(behaviors[2]["required_bond"]) == 50, "limiares de vinculo 10 / 25 / 50")
	var initial := config.get_initial_attributes()
	_check(int(initial["energy"]) == 70 and int(initial["max_energy"]) == 100
		and int(initial["strength"]) == 0 and int(initial["bond"]) == 0,
		"valores iniciais vem dos dados: %s" % str(initial))


func _test_config_rejection() -> void:
	_g("12. Configuracao invalida e recusada com erro especifico")
	var missing := GameConfig.load_from("res://data/nao_existe.json", FOODS_PATH, EXERCISES_PATH)
	_check(not missing.is_valid and missing.errors[0].contains("nao encontrado"),
		"arquivo ausente -> %s" % missing.errors[0])

	var bad_path := "user://_teste_json_invalido.json"
	var handle := FileAccess.open(bad_path, FileAccess.WRITE)
	handle.store_string("{ isto nao e json ]")
	handle.close()
	var broken := GameConfig.load_from(bad_path, FOODS_PATH, EXERCISES_PATH)
	_check(not broken.is_valid and broken.errors[0].contains("JSON invalido"),
		"JSON malformado -> %s" % broken.errors[0])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))

	var not_object := GameConfig.from_dictionaries([], _raw(FOODS_PATH), _raw(EXERCISES_PATH))
	_check(not not_object.is_valid and not_object.errors[0].contains("objeto JSON"),
		"raiz que nao e objeto -> %s" % not_object.errors[0])
	_rejects("raiz sem os campos obrigatorios",
		func(l: Dictionary, _f: Dictionary, _e: Dictionary) -> void: l.clear())
	_rejects("campo obrigatorio ausente",
		func(l: Dictionary, _f: Dictionary, _e: Dictionary) -> void:
			(l["strength_levels"][2] as Dictionary).erase("required_strength"))
	_rejects("limiar nao crescente",
		func(l: Dictionary, _f: Dictionary, _e: Dictionary) -> void:
			l["strength_levels"][2]["required_strength"] = 25)
	_rejects("limiar duplicado",
		func(l: Dictionary, _f: Dictionary, _e: Dictionary) -> void:
			l["strength_levels"][3]["required_strength"] = 70)
	_rejects("nivel 1 nao comeca em zero",
		func(l: Dictionary, _f: Dictionary, _e: Dictionary) -> void:
			l["strength_levels"][0]["required_strength"] = 5)
	_rejects("max_level em desacordo com a tabela",
		func(l: Dictionary, _f: Dictionary, _e: Dictionary) -> void: l["max_level"] = 7)
	_rejects("desbloqueio repetido dentro do mesmo nivel",
		func(l: Dictionary, _f: Dictionary, _e: Dictionary) -> void:
			l["strength_levels"][0]["unlocks"] = ["basic_actions", "basic_actions"])
	_rejects("desbloqueio repetido entre niveis",
		func(l: Dictionary, _f: Dictionary, _e: Dictionary) -> void:
			l["strength_levels"][1]["unlocks"] = ["basic_actions"])
	_rejects("comportamento de vinculo colidindo com desbloqueio de nivel",
		func(l: Dictionary, _f: Dictionary, _e: Dictionary) -> void:
			l["bond_behaviors"][0]["id"] = "muscular_form")
	_rejects("energia inicial acima do teto",
		func(l: Dictionary, _f: Dictionary, _e: Dictionary) -> void:
			l["initial_attributes"]["energy"] = 150)
	_rejects("ID de alimento duplicado",
		func(_l: Dictionary, f: Dictionary, _e: Dictionary) -> void:
			f["foods"][1]["id"] = "kibble")
	_rejects("energia de alimento nao positiva",
		func(_l: Dictionary, f: Dictionary, _e: Dictionary) -> void: f["foods"][0]["energy"] = 0)
	_rejects("vinculo de alimento negativo",
		func(_l: Dictionary, f: Dictionary, _e: Dictionary) -> void: f["foods"][0]["bond"] = -1)
	_rejects("recarga negativa",
		func(_l: Dictionary, f: Dictionary, _e: Dictionary) -> void:
			f["foods"][0]["cooldown_seconds"] = -5)
	_rejects("tipo errado de campo",
		func(_l: Dictionary, f: Dictionary, _e: Dictionary) -> void: f["foods"][0]["energy"] = "vinte")
	_rejects("custo de exercicio nao positivo",
		func(_l: Dictionary, _f: Dictionary, e: Dictionary) -> void:
			e["exercises"][0]["energy_cost"] = 0)
	_rejects("duracao de exercicio nao positiva",
		func(_l: Dictionary, _f: Dictionary, e: Dictionary) -> void:
			e["exercises"][1]["duration_seconds"] = 0)
	_rejects("chance comica fora de [0,1]",
		func(_l: Dictionary, _f: Dictionary, e: Dictionary) -> void:
			e["exercises"][0]["comic_reaction_chance"] = 1.5)
	_rejects("nivel minimo inexistente",
		func(_l: Dictionary, _f: Dictionary, e: Dictionary) -> void:
			e["exercises"][0]["required_level"] = 9)
	_rejects("unlock_id inexistente em levels.json",
		func(_l: Dictionary, _f: Dictionary, e: Dictionary) -> void:
			e["exercises"][0]["unlock_id"] = "fantasma")
	_rejects("unlock_id em nivel diferente do required_level",
		func(_l: Dictionary, _f: Dictionary, e: Dictionary) -> void:
			e["exercises"][0]["unlock_id"] = "dumbbells")


# --------------------------------------------------------------------------------------
# 13-19. Energia
# --------------------------------------------------------------------------------------

func _test_energy() -> void:
	_g("13-19. Energia")
	var model := _model()
	_check(model.get_energy() == 70 and model.get_max_energy() == 100,
		"estado inicial %d/%d" % [model.get_energy(), model.get_max_energy()])

	_check(model.restore_energy(20) == 20, "recuperar 20 aplica 20 (energia 90)")
	_check(model.get_energy() == 90, "energia = %d" % model.get_energy())
	_check(model.restore_energy(50) == 10, "recuperar 50 com teto aplica so 10")
	_check(model.get_energy() == 100, "energia travada em %d" % model.get_energy())

	var spy := Spy.new()
	model.energy_changed.connect(spy.on_energy)
	_check(model.restore_energy(30) == 0, "recuperar com energia cheia aplica 0")
	_check(spy.events.is_empty(), "clamp sem mudanca nao emite sinal")

	_check(model.try_spend_energy(25), "gasto valido de 25 aceito")
	_check(model.get_energy() == 75, "energia = %d" % model.get_energy())
	_check(spy.events.size() == 1 and spy.events[0] == ["energy", 100, 75],
		"sinal de energia com valores corretos: %s" % str(spy.events))

	spy.events.clear()
	_check(not model.try_spend_energy(76), "gasto de 76 com saldo 75 falha")
	_check(model.get_energy() == 75, "energia intacta apos falha: %d" % model.get_energy())
	_check(spy.events.is_empty(), "gasto recusado nao emite sinal")

	_check(not model.try_spend_energy(0), "gasto de 0 recusado")
	_check(not model.try_spend_energy(-10), "gasto negativo recusado")
	_check(model.restore_energy(0) == 0, "recuperacao de 0 recusada")
	_check(model.restore_energy(-10) == 0, "recuperacao negativa recusada")
	_check(model.get_energy() == 75 and spy.events.is_empty(),
		"nenhum valor invalido alterou energia nem emitiu sinal")

	var drained := _model()
	_check(drained.try_spend_energy(70) and drained.get_energy() == 0,
		"gasto exato ate zero permitido")
	_check(not drained.try_spend_energy(1), "sem saldo, gasto de 1 falha")
	_check(drained.get_energy() == 0, "energia nunca fica negativa")
	_check(drained.get_snapshot()["energy"] == 0, "snapshot acompanha o valor")


# --------------------------------------------------------------------------------------
# 20-30. Forca e nivel
# --------------------------------------------------------------------------------------

func _test_strength_and_level() -> void:
	_g("20-27. Forca controla os cinco niveis")
	var model := _model()
	_check(model.get_strength() == 0 and model.get_level() == 1,
		"inicial: forca %d, nivel %d" % [model.get_strength(), model.get_level()])

	for expected in [[24, 1], [25, 2], [69, 2], [70, 3], [139, 3], [140, 4], [249, 4], [250, 5], [400, 5]]:
		var target := int(expected[0])
		var level := int(expected[1])
		var probe := _model()
		probe.add_strength(target)
		_check(probe.get_strength() == target and probe.get_level() == level,
			"forca %d -> nivel %d (obtido %d)" % [target, level, probe.get_level()])

	_g("27-28. Uma unica operacao cruza varios niveis sem perder desbloqueios")
	var jumper := _model()
	var spy := Spy.new()
	jumper.strength_changed.connect(spy.on_strength)
	jumper.level_changed.connect(spy.on_level)
	jumper.unlock_granted.connect(spy.on_unlock)
	_check(jumper.add_strength(250) == 250, "add_strength(250) devolve o novo total")
	_check(jumper.get_level() == 5, "nivel 5 alcancado de uma vez")
	_check(spy.unlocks() == ["level_2_celebration", "dumbbells", "muscular_form",
		"final_pose", "final_achievement_effect"],
		"todos os desbloqueios intermediarios emitidos, em ordem: %s" % str(spy.unlocks()))
	for unlock_id in ["basic_actions", "push_ups", "level_2_celebration", "dumbbells",
			"muscular_form", "final_pose", "final_achievement_effect"]:
		_check(jumper.has_unlock(StringName(unlock_id)), "has_unlock('%s')" % unlock_id)

	_g("29-30. Rejeicoes e ausencia de fonte de verdade paralela")
	var guard := _model()
	guard.add_strength(30)
	var spy2 := Spy.new()
	guard.strength_changed.connect(spy2.on_strength)
	guard.level_changed.connect(spy2.on_level)
	_check(guard.add_strength(-5) == 30, "forca negativa recusada, total intacto")
	_check(guard.add_strength(0) == 30, "ganho zero recusado")
	_check(guard.get_strength() == 30 and guard.get_level() == 2, "estado inalterado")
	_check(spy2.events.is_empty(), "operacao recusada nao emite sinal")

	var properties: Array = []
	for property in guard.get_property_list():
		properties.append(String(property["name"]))
	_check(not properties.has("level") and not properties.has("_level"),
		"nao existe campo 'level': o nivel e sempre derivado da forca")
	_check(not guard.has_method("set_level"), "nao existe set_level()")
	guard.add_strength(40)
	_check(guard.get_level() == 3, "nivel recalculado apos nova forca: %d" % guard.get_level())
	_check(guard.get_snapshot()["level"] == guard.get_level(), "snapshot concorda com get_level()")

	_g("Exercicios desbloqueados por nivel")
	var gate := _model()
	_check(gate.is_exercise_unlocked(&"push_ups"), "nivel 1: flexoes liberadas")
	_check(not gate.is_exercise_unlocked(&"dumbbells"), "nivel 1: halteres bloqueados")
	gate.add_strength(69)
	_check(not gate.is_exercise_unlocked(&"dumbbells"), "forca 69 (nivel 2): halteres ainda bloqueados")
	gate.add_strength(1)
	_check(gate.is_exercise_unlocked(&"dumbbells"), "forca 70 (nivel 3): halteres liberados")
	_check(not gate.is_exercise_unlocked(&"corrida"), "exercicio inexistente devolve false")


# --------------------------------------------------------------------------------------
# 31-37. Vinculo
# --------------------------------------------------------------------------------------

func _test_bond() -> void:
	_g("31-35. Vinculo e comportamentos afetivos")
	var model := _model()
	_check(model.get_bond() == 0, "inicial: vinculo %d" % model.get_bond())
	_check(model.get_unlocked_bond_behaviors().is_empty(), "nenhum comportamento liberado")

	model.add_bond(9)
	_check(model.get_bond() == 9, "vinculo 9")
	_check(not model.has_unlock(&"petting_reaction"), "vinculo 9 nao libera reacao ao carinho")

	_check(model.add_bond(1) == 10, "add_bond devolve o novo total")
	_check(model.has_unlock(&"petting_reaction"), "vinculo 10 libera reacao ao carinho")
	_check(model.get_unlocked_bond_behaviors() == PackedStringArray(["petting_reaction"]),
		"lista = %s" % str(model.get_unlocked_bond_behaviors()))

	model.add_bond(15)
	_check(model.get_bond() == 25 and model.has_unlock(&"startup_celebration"),
		"vinculo 25 libera comemoracao inicial")
	model.add_bond(25)
	_check(model.get_bond() == 50 and model.has_unlock(&"rare_affection_idle"),
		"vinculo 50 libera animacao afetiva rara")
	_check(model.get_unlocked_bond_behaviors().size() == 3, "os tres comportamentos liberados")

	_g("36-37. Salto multiplo e rejeicoes")
	var jumper := _model()
	var spy := Spy.new()
	jumper.bond_changed.connect(spy.on_bond)
	jumper.unlock_granted.connect(spy.on_unlock)
	jumper.add_bond(60)
	_check(spy.unlocks() == ["petting_reaction", "startup_celebration", "rare_affection_idle"],
		"cruzar 10, 25 e 50 de uma vez emite os tres, em ordem: %s" % str(spy.unlocks()))
	_check(jumper.get_bond() == 60, "vinculo nao tem teto no MVP: %d" % jumper.get_bond())

	spy.events.clear()
	_check(jumper.add_bond(-1) == 60, "vinculo negativo recusado")
	_check(jumper.add_bond(0) == 60, "ganho zero recusado")
	_check(spy.events.is_empty(), "recusa nao emite sinal")
	_check(jumper.get_strength() == 0 and jumper.get_level() == 1 and jumper.get_energy() == 70,
		"vinculo nao concede forca, nivel nem energia — eixos independentes")


# --------------------------------------------------------------------------------------
# 38-40. Sinais
# --------------------------------------------------------------------------------------

func _test_signals() -> void:
	_g("38-40. Sinais: valores, unicidade e ordem")
	var model := _model()
	var spy := Spy.new()
	model.energy_changed.connect(spy.on_energy)
	model.strength_changed.connect(spy.on_strength)
	model.bond_changed.connect(spy.on_bond)
	model.level_changed.connect(spy.on_level)
	model.unlock_granted.connect(spy.on_unlock)

	model.add_strength(25)
	_check(spy.events.size() == 3, "3 sinais na subida de nivel (%d)" % spy.events.size())
	_check(spy.names() == ["strength", "level", "unlock"],
		"ordem fixa strength -> level -> unlock: %s" % str(spy.names()))
	_check(spy.events[0] == ["strength", 0, 25], "strength_changed(0, 25)")
	_check(spy.events[1] == ["level", 1, 2], "level_changed(1, 2)")
	_check(spy.events[2] == ["unlock", "level_2_celebration"], "unlock_granted('level_2_celebration')")

	spy.events.clear()
	model.add_strength(5)
	_check(spy.names() == ["strength"], "ganho sem mudar de nivel emite so strength_changed")
	_check(spy.events[0] == ["strength", 25, 30], "strength_changed(25, 30)")

	spy.events.clear()
	model.add_bond(10)
	_check(spy.names() == ["bond", "unlock"], "ordem fixa bond -> unlock: %s" % str(spy.names()))
	_check(spy.events[0] == ["bond", 0, 10], "bond_changed(0, 10)")

	spy.events.clear()
	model.add_bond(5)
	_check(spy.names() == ["bond"], "vinculo sem cruzar limiar emite so bond_changed")

	spy.events.clear()
	var _ignored: Variant = model.get_snapshot()
	_ignored = model.get_level()
	_ignored = model.has_unlock(&"push_ups")
	_ignored = model.get_unlocked_bond_behaviors()
	_ignored = model.is_exercise_unlocked(&"dumbbells")
	_check(spy.events.is_empty(), "consultas nao emitem sinal algum")

	spy.events.clear()
	model.add_strength(220)
	var unlock_events := spy.unlocks()
	var seen: Dictionary = {}
	var duplicated := false
	for unlock_id in unlock_events:
		if seen.has(unlock_id):
			duplicated = true
		seen[unlock_id] = true
	_check(not duplicated, "nenhum desbloqueio emitido duas vezes: %s" % str(unlock_events))
	_check(spy.names().count("level") == 1, "uma unica emissao de level_changed no salto")

	spy.events.clear()
	model.add_strength(500)
	_check(spy.names() == ["strength"],
		"ja no nivel maximo, ganhar forca emite so strength_changed: %s" % str(spy.names()))
	_check(model.get_level() == 5, "nivel permanece 5 com forca %d" % model.get_strength())


# --------------------------------------------------------------------------------------
# 41-45. Integracao
# --------------------------------------------------------------------------------------

func _test_integration() -> void:
	_g("41-42. GameSession e a cena principal")
	var reads_before := GameConfig.file_read_count
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	root.add_child(viewport)
	var main := (load(MAIN_SCENE) as PackedScene).instantiate()
	viewport.add_child(main)

	var sessions: Array = []
	var models: Array = []
	var dogs: Array = []
	var queue: Array = [main]
	while not queue.is_empty():
		var node: Node = queue.pop_back()
		if node is GameSession:
			sessions.append(node)
		if node is Caramelo:
			dogs.append(node)
		for child in node.get_children():
			queue.append(child)
	_check(sessions.size() == 1, "%d GameSession na cena principal" % sessions.size())
	_check(dogs.size() == 1, "%d Caramelo na cena principal" % dogs.size())

	var session: GameSession = sessions[0]
	_check(session.is_ready(), "sessao carregou a configuracao com sucesso")
	var model_a := session.get_model()
	var model_b := session.get_model()
	_check(model_a != null and model_a == model_b, "a sessao possui exatamente um modelo")
	_check(GameSession.find_in(self) != null or session.is_in_group(GameSession.GROUP),
		"sessao registrada no grupo '%s'" % GameSession.GROUP)
	_check(GameConfig.file_read_count - reads_before == 3,
		"configuracao lida uma unica vez por sessao: %d arquivos"
			% (GameConfig.file_read_count - reads_before))

	_g("43. Caramelo continua sem atributos")
	var dog: Caramelo = dogs[0]
	var forbidden := ["energy", "strength", "bond", "level", "max_energy"]
	var found: Array = []
	for property in dog.get_property_list():
		var name := String(property["name"]).to_lower()
		for banned in forbidden:
			if name == banned or name == "_" + banned:
				found.append(name)
	_check(found.is_empty(), "nenhuma propriedade de atributo em Caramelo: %s" % str(found))
	var methods: Array = []
	for method in dog.get_method_list():
		var name := String(method["name"])
		if name.begins_with("get_energy") or name.begins_with("add_strength") \
				or name.begins_with("add_bond") or name.begins_with("get_level"):
			methods.append(name)
	_check(methods.is_empty(), "nenhum metodo de atributo em Caramelo: %s" % str(methods))
	_check(not dog.has_method("get_model"), "Caramelo nao conhece o modelo")

	_g("44. Executar a cena nao altera os valores iniciais")
	var before := model_a.get_snapshot()
	for _i in int(round(120.0 / (1.0 / 60.0))):   # 2 minutos de jogo
		dog.simulate(1.0 / 60.0)
	var after := model_a.get_snapshot()
	_check(int(after["energy"]) == 70, "energia continua 70 (%d)" % int(after["energy"]))
	_check(int(after["strength"]) == 0, "forca continua 0 (%d)" % int(after["strength"]))
	_check(int(after["bond"]) == 0, "vinculo continua 0 (%d)" % int(after["bond"]))
	_check(int(after["level"]) == 1, "nivel continua 1 (%d)" % int(after["level"]))
	_check(before["energy"] == after["energy"] and before["strength"] == after["strength"],
		"nenhum estado de Caramelo gastou energia nem concedeu forca")

	_g("45. Comportamento da Etapa 4 preservado (a suite completa roda a parte)")
	var autonomous := [Caramelo.State.IDLE, Caramelo.State.WALKING, Caramelo.State.RESTING]
	_check(autonomous.has(dog.get_current_state()),
		"apos 2 min sem comando, Caramelo so usou os estados autonomos: %s"
			% Caramelo.state_name(dog.get_current_state()))
	var fresh := (load(CARAMELO_SCENE) as PackedScene).instantiate() as Caramelo
	viewport.add_child(fresh)
	fresh.set_physics_process(false)
	_check(fresh.get_current_state() == Caramelo.State.IDLE, "novo Caramelo comeca em IDLE")
	fresh.request_state(Caramelo.State.EATING)
	_check(not fresh.is_interruptible(), "EATING continua nao interrompivel")
	_check(not fresh.request_state(Caramelo.State.IDLE), "comando durante EATING continua descartado")
	viewport.free()


# --------------------------------------------------------------------------------------
# Aritmetica da progressao
# --------------------------------------------------------------------------------------

func _test_progression_arithmetic() -> void:
	_g("Aritmetica da progressao (MVP_SPEC secoes 13 e 14)")
	var config := _config()
	var push_gain := int(config.get_exercise(&"push_ups")["strength_gain"])
	var push_cost := int(config.get_exercise(&"push_ups")["energy_cost"])
	var dumb_gain := int(config.get_exercise(&"dumbbells")["strength_gain"])

	var model := _model()
	var sessions := 0
	while model.get_level() < 2 and sessions < 1000:
		model.add_strength(push_gain)
		sessions += 1
	_check(model.get_level() == 2 and sessions == 5,
		"sair do nivel 1 so com flexoes: %d sessoes, %d de forca, %d de energia"
			% [sessions, model.get_strength(), sessions * push_cost])

	while model.get_level() < 3 and sessions < 1000:
		model.add_strength(push_gain)
		sessions += 1
	_check(model.get_level() == 3 and sessions == 14,
		"chegar ao nivel 3 so com flexoes: %d sessoes, %d de forca, %d de energia"
			% [sessions, model.get_strength(), sessions * push_cost])
	_check(model.is_exercise_unlocked(&"dumbbells"),
		"halteres ficam disponiveis exatamente ao alcancar o nivel 3")

	var only_push := _model()
	var push_sessions := 0
	while only_push.get_level() < 5 and push_sessions < 1000:
		only_push.add_strength(push_gain)
		push_sessions += 1
	_check(only_push.get_level() == 5 and push_sessions == 50,
		"nivel 5 e alcancavel so com flexoes: %d sessoes, %d de energia"
			% [push_sessions, push_sessions * push_cost])

	var levels := config.get_levels()
	var smallest_gap := 1 << 30
	for i in range(1, levels.size()):
		smallest_gap = mini(smallest_gap, int(levels[i]["required_strength"])
			- int(levels[i - 1]["required_strength"]))
	var biggest_gain := 0
	for exercise in config.get_exercises():
		biggest_gain = maxi(biggest_gain, int(exercise["strength_gain"]))
	_check(biggest_gain < smallest_gap,
		"maior ganho por sessao (%d) e menor que o menor intervalo entre niveis (%d): "
		% [biggest_gain, smallest_gap] + "nenhuma sessao sobe dois niveis")

	var double_jump := false
	for exercise in config.get_exercises():
		var gain := int(exercise["strength_gain"])
		for strength in range(0, 260):
			var probe := ProgressionModel.new(config)
			if strength > 0:
				probe.add_strength(strength)
			var before_level := probe.get_level()
			probe.add_strength(gain)
			if probe.get_level() - before_level >= 2:
				double_jump = true
	_check(not double_jump,
		"varrendo forca 0..259 com os dois exercicios, nenhuma sessao pula dois niveis")

	_check(int(levels[4]["required_strength"]) == 250,
		"nivel 5 exige forca total %d" % int(levels[4]["required_strength"]))
	var capped := _model()
	capped.add_strength(250)
	capped.add_strength(dumb_gain * 100)
	_check(capped.get_level() == 5 and capped.get_strength() == 250 + dumb_gain * 100,
		"forca segue subindo (%d) e o nivel permanece 5" % capped.get_strength())

	var recommended := [[25, push_gain], [45, push_gain], [70, dumb_gain], [110, dumb_gain]]
	var total_sessions := 0
	var total_energy := 0
	for leg in recommended:
		var needed := int(leg[0])
		var gain := int(leg[1])
		var cost := push_cost if gain == push_gain else int(config.get_exercise(&"dumbbells")["energy_cost"])
		var count := int(ceil(float(needed) / float(gain)))
		total_sessions += count
		total_energy += count * cost
	_check(total_sessions == 35 and total_energy == 735,
		"caminho recomendado do MVP_SPEC: %d sessoes e %d de energia"
			% [total_sessions, total_energy])


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
