extends SceneTree
## Testes permanentes do salvamento e do progresso offline.
##
## Executar:  godot --headless --path . --script tests/test_save_and_offline.gd
##
## Nunca consulta o relogio real: `OfflineProgress` recebe `now_unix` injetado. Os arquivos
## vao para um diretorio isolado em `user://`, apagado ao final — o save de quem joga
## nunca e tocado.

const DIR := "test_save_offline"
const MAX_ENERGY := 100
const FOOD_POINT := Vector2(941.6, 792.1)
const PUSH_UPS_POINT := Vector2(1580.0, 845.0)

var _passed := 0
var _failures: Array[String] = []
var _group := ""
var _done := false
var _viewport: SubViewport
var _config: GameConfig


## Adaptador que falha de propósito, para exercitar os caminhos de erro sem depender de
## permissões do sistema de arquivos.
class BrokenFiles:
	extends SaveManager.FileAdapter
	var fail_write := false
	var fail_copy_to := ""
	var truncate_write := false

	func write_text(path: String, text: String) -> bool:
		if fail_write:
			return false
		if truncate_write:
			return super.write_text(path, text.substr(0, maxi(text.length() / 2, 1)))
		return super.write_text(path, text)

	func copy(from_path: String, to_path: String) -> bool:
		if fail_copy_to != "" and to_path.ends_with(fail_copy_to):
			return false
		return super.copy(from_path, to_path)


class World:
	extends RefCounted
	var main: Node
	var session: GameSession
	var save: SaveManager
	var model: ProgressionModel
	var feeding: FeedingSystem
	var exercise: ExerciseSystem
	var rest: RestSystem
	var dog: Caramelo
	var hud: Control
	var summary: Control

	func _init(viewport: SubViewport) -> void:
		main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
		viewport.add_child(main)
		session = _find(main, func(n: Node) -> bool: return n is GameSession) as GameSession
		save = _find(main, func(n: Node) -> bool: return n is SaveManager) as SaveManager
		feeding = _find(main, func(n: Node) -> bool: return n is FeedingSystem) as FeedingSystem
		exercise = _find(main, func(n: Node) -> bool: return n is ExerciseSystem) as ExerciseSystem
		rest = _find(main, func(n: Node) -> bool: return n is RestSystem) as RestSystem
		dog = _find(main, func(n: Node) -> bool: return n is Caramelo) as Caramelo
		hud = _find(main, func(n: Node) -> bool: return n.is_in_group(&"main_hud")) as Control
		summary = _find(main, func(n: Node) -> bool: return n.is_in_group(&"offline_summary")) as Control
		model = session.get_model()
		dog.set_physics_process(false)
		feeding.set_process(false)
		rest.set_process(false)
		save.set_process(false)
		if hud != null:
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

	func run_until_state(state: int, limit: float = 90.0) -> bool:
		for _i in int(round(limit / (1.0 / 60.0))):
			if dog.get_current_state() == state:
				return true
			dog.simulate(1.0 / 60.0)
		return dog.get_current_state() == state

	func free_all() -> void:
		main.free()


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	SaveManager.use_isolated_directory(DIR)
	_config = GameConfig.load_default()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	root.add_child(_viewport)

	_test_schema()
	_test_atomic_write()
	_test_clock()
	_test_offline_feeding()
	_test_offline_exercise()
	_test_offline_rest_and_cooldowns()
	_test_resume()
	_test_startup_and_ui()
	_test_autosave()

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


func _path(name: String) -> String:
	return "user://%s/%s" % [DIR, name]


func _wipe() -> void:
	for name in ["savegame.json", "savegame.backup.json", "savegame.tmp.json", "savegame.rejected.json"]:
		var path := _path(name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write(path: String, text: String) -> void:
	var handle := FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(text)
	handle.close()


func _read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Snapshot mínimo válido, base para os testes negativos e de offline.
func _snapshot(overrides: Dictionary = {}) -> Dictionary:
	var base := {
		"schema_version": 2,
		"saved_at_unix": 1_000_000,
		"progression": {"energy": 70, "strength": 0, "bond": 0},
		"food_cooldowns": {},
		"rest": {"accumulated_seconds": 0.0},
		"affection": {"cooldown_remaining": 0.0},
		"dog": {"position": {"x": 880.0, "y": 860.0}, "facing": 1},
		"activity": null,
	}
	for key in overrides:
		base[key] = overrides[key]
	return base


func _validator() -> SaveManager:
	var manager := SaveManager.new()
	manager.configure(_config, null, null, null, null, null)
	return manager


# --------------------------------------------------------------------------------------
# 1-19. Schema e snapshot
# --------------------------------------------------------------------------------------

func _test_schema() -> void:
	_g("1-11. Snapshot: campos, tipos e ida e volta")
	_wipe()
	var w := _world()
	w.model.restore(42, 80, 7)
	w.feeding.restore_cooldowns({"kibble": 123.5})
	w.rest.restore_accumulated(41.25)
	w.dog.restore_placement(Vector2(900.0, 850.0), -1)
	var stamp := int(Time.get_unix_time_from_system())
	_check(w.save.save_now(stamp), "save gravado")

	_check(w.save.get_main_path().begins_with("user://"),
		"escrita fora de res://: %s" % w.save.get_main_path())
	var raw: Variant = _read_json(_path("savegame.json"))
	_check(raw is Dictionary, "JSON valido no disco")
	var data: Dictionary = raw
	_check(int(data["schema_version"]) == 2, "versao %d" % int(data["schema_version"]))
	_check(int(data["saved_at_unix"]) == stamp, "timestamp preservado")
	for field in ["progression", "food_cooldowns", "rest", "dog", "activity", "affection"]:
		_check(data.has(field), "campo obrigatorio '%s' presente" % field)
	var progression: Dictionary = data["progression"]
	_check(not progression.has("level"), "nivel NAO e persistido")
	_check(not progression.has("unlocks") and not data.has("unlocks"),
		"desbloqueios NAO sao persistidos")
	_check(int(progression["energy"]) == 42 and int(progression["strength"]) == 80
		and int(progression["bond"]) == 7, "atributos gravados: %s" % str(progression))
	_check(is_equal_approx(float((data["food_cooldowns"] as Dictionary)["kibble"]), 123.5),
		"recarga preservada")
	_check(is_equal_approx(float((data["rest"] as Dictionary)["accumulated_seconds"]), 41.25),
		"acumulador preservado")
	var dog_data: Dictionary = data["dog"]
	_check(is_equal_approx(float((dog_data["position"] as Dictionary)["x"]), 900.0),
		"posicao preservada")
	_check(int(dog_data["facing"]) == -1, "direcao preservada: %d" % int(dog_data["facing"]))
	w.free_all()

	_g("7. Reabrir restaura os mesmos atributos")
	var w2 := _world()
	_check(w2.model.get_energy() == 42 and w2.model.get_strength() == 80
		and w2.model.get_bond() == 7,
		"energia %d, forca %d, vinculo %d" % [w2.model.get_energy(), w2.model.get_strength(),
			w2.model.get_bond()])
	_check(w2.model.get_level() == 3, "forca 80 -> nivel %d, derivado e nao lido do save" % w2.model.get_level())
	_check(is_equal_approx(w2.feeding.get_remaining_cooldown(&"kibble"), 123.5)
		or w2.feeding.get_remaining_cooldown(&"kibble") < 123.5,
		"recarga restaurada: %.1f" % w2.feeding.get_remaining_cooldown(&"kibble"))
	w2.free_all()

	_g("12. Posicao invalida cai num ponto seguro")
	_wipe()
	var manager := _validator()
	var polygon_probe := _world()
	var invalid := _snapshot({"dog": {"position": {"x": 50.0, "y": 50.0}, "facing": 1}})
	_check(manager.validate(invalid, _config, MAX_ENERGY).is_empty(),
		"o snapshot em si e valido (a posicao so e recusada ao aplicar)")
	_check(not polygon_probe.dog.restore_placement(Vector2(50.0, 50.0), 1),
		"restore_placement recusa ponto fora do poligono")
	polygon_probe.free_all()

	_g("13-18. Snapshots invalidos sao recusados")
	for caso in [
		["campo obrigatorio ausente", func(d: Dictionary) -> void: d.erase("progression")],
		["energia acima do maximo", func(d: Dictionary) -> void: (d["progression"] as Dictionary)["energy"] = 500],
		["energia negativa", func(d: Dictionary) -> void: (d["progression"] as Dictionary)["energy"] = -1],
		["forca negativa", func(d: Dictionary) -> void: (d["progression"] as Dictionary)["strength"] = -5],
		["vinculo negativo", func(d: Dictionary) -> void: (d["progression"] as Dictionary)["bond"] = -2],
		["tipo invalido", func(d: Dictionary) -> void: (d["progression"] as Dictionary)["energy"] = "setenta"],
		["numero nao finito", func(d: Dictionary) -> void: (d["rest"] as Dictionary)["accumulated_seconds"] = INF],
		["recarga negativa", func(d: Dictionary) -> void: d["food_cooldowns"] = {"kibble": -3.0}],
		["alimento desconhecido", func(d: Dictionary) -> void: d["food_cooldowns"] = {"pizza": 10.0}],
		["direcao invalida", func(d: Dictionary) -> void: (d["dog"] as Dictionary)["facing"] = 7],
		["versao futura", func(d: Dictionary) -> void: d["schema_version"] = 99],
		["tipo de atividade desconhecido", func(d: Dictionary) -> void:
			d["activity"] = {"type": "danca", "phase": "running", "content_id": "", "remaining_seconds": 1.0,
				"energy_already_spent": false, "reward_already_applied": false, "target_id": ""}],
		["fase desconhecida", func(d: Dictionary) -> void:
			d["activity"] = {"type": "feeding", "phase": "voando", "content_id": "kibble", "remaining_seconds": 1.0,
				"energy_already_spent": false, "reward_already_applied": false, "target_id": "FoodPoint"}],
		["content_id inexistente", func(d: Dictionary) -> void:
			d["activity"] = {"type": "feeding", "phase": "running", "content_id": "pizza", "remaining_seconds": 1.0,
				"energy_already_spent": false, "reward_already_applied": false, "target_id": "FoodPoint"}],
		["treino em execucao sem debito", func(d: Dictionary) -> void:
			d["activity"] = {"type": "exercise", "phase": "running", "content_id": "push_ups",
				"remaining_seconds": 5.0, "energy_already_spent": false,
				"reward_already_applied": false, "target_id": "PushUpsPoint"}],
		["comer marcado como gasto de energia", func(d: Dictionary) -> void:
			d["activity"] = {"type": "feeding", "phase": "running", "content_id": "kibble",
				"remaining_seconds": 1.0, "energy_already_spent": true,
				"reward_already_applied": false, "target_id": "FoodPoint"}],
	]:
		var snapshot := _snapshot()
		(caso[1] as Callable).call(snapshot)
		var errors := manager.validate(snapshot, _config, MAX_ENERGY)
		_check(not errors.is_empty(), "%s -> %s" % [caso[0], errors[0] if not errors.is_empty() else "ACEITOU"])

	_check(manager.validate(_snapshot(), _config, MAX_ENERGY).is_empty(),
		"o snapshot de referencia continua valido")
	var extra := _snapshot()
	extra["campo_do_futuro"] = {"algo": 1}
	_check(manager.validate(extra, _config, MAX_ENERGY).is_empty(),
		"campo desconhecido e ignorado, para compatibilidade futura")
	manager.free()

	_g("19. Save inexistente inicia jogo novo")
	_wipe()
	var w3 := _world()
	_check(w3.model.get_energy() == 70 and w3.model.get_strength() == 0,
		"valores iniciais: %d / %d" % [w3.model.get_energy(), w3.model.get_strength()])
	_check(not w3.summary.call("is_open"), "nenhum resumo em jogo novo")
	w3.free_all()


# --------------------------------------------------------------------------------------
# 20-30. Escrita atomica e recuperacao
# --------------------------------------------------------------------------------------

func _test_atomic_write() -> void:
	_g("21-23. Falha de escrita preserva o save anterior")
	_wipe()
	var w := _world()
	w.model.restore(55, 10, 3)
	var t0 := int(Time.get_unix_time_from_system())
	_check(w.save.save_now(t0), "primeiro save")
	w.model.restore(60, 20, 4)
	_check(w.save.save_now(t0), "segundo save")
	_check(FileAccess.file_exists(_path("savegame.backup.json")),
		"o save anterior virou backup")
	var backup: Dictionary = _read_json(_path("savegame.backup.json"))
	_check(int((backup["progression"] as Dictionary)["energy"]) == 55,
		"backup guarda o estado anterior (%d)" % int((backup["progression"] as Dictionary)["energy"]))

	var broken := BrokenFiles.new()
	broken.fail_write = true
	w.save.set_file_adapter(broken)
	w.model.restore(99, 99, 99)
	_check(not w.save.save_now(t0), "escrita falha e recusada")
	var main_after: Dictionary = _read_json(_path("savegame.json"))
	_check(int((main_after["progression"] as Dictionary)["energy"]) == 60,
		"principal intacto apos a falha (%d)" % int((main_after["progression"] as Dictionary)["energy"]))
	_check(not FileAccess.file_exists(_path("savegame.tmp.json")), "temporario removido")

	_g("20, 27. Temporario incompleto nao substitui o principal")
	var truncating := BrokenFiles.new()
	truncating.truncate_write = true
	w.save.set_file_adapter(truncating)
	_check(not w.save.save_now(t0), "temporario truncado e recusado na revalidacao")
	main_after = _read_json(_path("savegame.json"))
	_check(int((main_after["progression"] as Dictionary)["energy"]) == 60, "principal continua intacto")

	_g("22. Falha ao preservar o backup nao destroi o principal")
	var no_backup := BrokenFiles.new()
	no_backup.fail_copy_to = "savegame.backup.json"
	w.save.set_file_adapter(no_backup)
	_check(not w.save.save_now(t0), "save abortado quando o backup nao pode ser preservado")
	_check(FileAccess.file_exists(_path("savegame.json")), "principal continua no lugar")
	w.save.set_file_adapter(SaveManager.FileAdapter.new())
	w.free_all()

	_g("24, 30. Principal corrompido usa o backup")
	_write(_path("savegame.json"), "{ isto nao e json ]")
	var loader := _validator()
	loader.set_paths(_path("savegame.json"), _path("savegame.backup.json"), _path("savegame.tmp.json"))
	var recovered: Array = []
	loader.backup_recovered.connect(func() -> void: recovered.append(true))
	var result := loader.load_snapshot(MAX_ENERGY)
	_check(int(result["source"]) == SaveManager.Source.BACKUP, "carregou do backup")
	_check(recovered.size() == 1, "backup_recovered emitido uma vez (%d)" % recovered.size())
	_check(int((((result["snapshot"] as Dictionary)["progression"]) as Dictionary)["energy"]) == 55,
		"o backup traz o estado anterior")
	_check(FileAccess.file_exists(_path("savegame.rejected.json")),
		"o principal ilegivel foi preservado numa copia")
	loader.free()
	var w2 := _world()
	_check(w2.model.get_energy() == 55, "e a sessao abriu com o estado do backup: %d" % w2.model.get_energy())
	w2.free_all()

	_g("25. Backup corrompido nao invalida o principal")
	_wipe()
	var w3 := _world()
	w3.model.restore(77, 5, 1)
	w3.save.save_now(int(Time.get_unix_time_from_system()))
	_write(_path("savegame.backup.json"), "lixo")
	var result3 := w3.save.load_snapshot(MAX_ENERGY)
	_check(int(result3["source"]) == SaveManager.Source.MAIN, "principal valido e usado normalmente")
	w3.free_all()

	_g("26. Principal e backup corrompidos comecam estado novo")
	_write(_path("savegame.json"), "lixo")
	_write(_path("savegame.backup.json"), "lixo tambem")
	var w4 := _world()
	_check(w4.model.get_energy() == 70 and w4.model.get_strength() == 0,
		"jogo novo: %d / %d" % [w4.model.get_energy(), w4.model.get_strength()])
	_check(FileAccess.file_exists(_path("savegame.json")), "os arquivos ruins nao foram apagados")
	w4.free_all()

	_g("28-29. Temporario abandonado e versao futura nao sao promovidos")
	_wipe()
	var w5 := _world()
	w5.model.restore(80, 0, 0)
	w5.save.save_now(int(Time.get_unix_time_from_system()))
	_write(_path("savegame.tmp.json"), JSON.stringify(_snapshot({"progression":
		{"energy": 1, "strength": 999, "bond": 999}})))
	var w6 := _world()
	_check(w6.model.get_strength() == 0,
		"temporario abandonado ignorado: forca %d" % w6.model.get_strength())
	w6.free_all()
	w5.free_all()

	_wipe()
	var future := _snapshot({"schema_version": 99})
	_write(_path("savegame.json"), JSON.stringify(future))
	var w7 := _world()
	_check(w7.model.get_energy() == 70, "save de versao futura recusado; jogo novo")
	var preserved: Variant = _read_json(_path("savegame.rejected.json"))
	_check(preserved is Dictionary and int((preserved as Dictionary)["schema_version"]) == 99,
		"e o arquivo dele foi preservado numa copia, nao destruido")
	w7.free_all()


# --------------------------------------------------------------------------------------
# 31-39. Relogio
# --------------------------------------------------------------------------------------

func _test_clock() -> void:
	_g("31-39. Tempo ausente, teto e relogio regressivo")
	var base := _snapshot({"saved_at_unix": 1_000_000})
	for caso in [[1_000_000, 0.0, "tempo igual"], [999_000, 0.0, "relogio regressivo"],
			[1_003_600, 3600.0, "uma hora"], [1_028_800, 28800.0, "oito horas"],
			[1_100_000, 28800.0, "mais de oito horas"]]:
		var out := OfflineProgress.reconcile(base.duplicate(true), _config, int(caso[0]), MAX_ENERGY)
		var report: Dictionary = out["report"]
		_check(is_equal_approx(float(report["elapsed_seconds"]), float(caso[1])),
			"%s -> %.0f s aplicados" % [caso[2], float(report["elapsed_seconds"])])

	var backwards := OfflineProgress.reconcile(base.duplicate(true), _config, 900_000, MAX_ENERGY)
	_check(bool((backwards["report"] as Dictionary)["clock_went_backwards"]),
		"relogio regressivo e sinalizado")
	var snapshot_back: Dictionary = backwards["snapshot"]
	_check(int((snapshot_back["progression"] as Dictionary)["energy"]) == 70,
		"e nao reduz atributo algum: energia %d"
			% int((snapshot_back["progression"] as Dictionary)["energy"]))
	_check(int(snapshot_back["saved_at_unix"]) == 900_000, "o timestamp e atualizado mesmo assim")

	var capped := OfflineProgress.reconcile(base.duplicate(true), _config, 2_000_000, MAX_ENERGY)
	_check(bool((capped["report"] as Dictionary)["capped"]), "o teto e sinalizado no relatorio")

	_g("39. OfflineProgress nao consulta o relogio real")
	var source := FileAccess.get_file_as_string("res://scripts/systems/offline_progress.gd")
	for forbidden in ["Time.get_unix", "Time.get_ticks", "FileAccess", "DirAccess"]:
		_check(not source.contains(forbidden), "offline_progress.gd nao usa '%s'" % forbidden)


# --------------------------------------------------------------------------------------
# 40-50. Alimentacao offline
# --------------------------------------------------------------------------------------

func _feeding_activity(phase: String, remaining: float, food := "kibble") -> Dictionary:
	return {"type": "feeding", "phase": phase, "content_id": food, "remaining_seconds": remaining,
		"energy_already_spent": false, "reward_already_applied": false, "target_id": "FoodPoint"}


func _test_offline_feeding() -> void:
	_g("40-41. Refeicao reservada ou a caminho e cancelada, sem recompensa")
	for phase in ["reserved", "walking"]:
		var snapshot := _snapshot({"activity": _feeding_activity(phase, 0.0)})
		var out := OfflineProgress.reconcile(snapshot, _config, 1_000_010, MAX_ENERGY)
		var final: Dictionary = out["snapshot"]
		var report: Dictionary = out["report"]
		_check(final["activity"] == null, "fase '%s': reserva desfeita" % phase)
		_check(int((final["progression"] as Dictionary)["bond"]) == 0, "nenhum vinculo aplicado")
		_check((final["food_cooldowns"] as Dictionary).is_empty(), "nenhuma recarga iniciada")
		_check(String(report["meal_completed"]) == "", "nada de refeicao concluida no relatorio")

	_g("42-43. Refeicao incompleta retoma com o tempo certo, sem recarga")
	var partial := _snapshot({"activity": _feeding_activity("running", 4.0)})
	var out2 := OfflineProgress.reconcile(partial, _config, 1_000_001, MAX_ENERGY)
	var snap2: Dictionary = out2["snapshot"]
	_check(snap2["activity"] != null, "atividade preservada")
	_check(is_equal_approx(float((snap2["activity"] as Dictionary)["remaining_seconds"]), 3.0),
		"restam %.1f s" % float((snap2["activity"] as Dictionary)["remaining_seconds"]))
	_check((snap2["food_cooldowns"] as Dictionary).is_empty(), "nenhuma recarga iniciada")
	_check(int((snap2["progression"] as Dictionary)["energy"]) == 70, "nenhuma recompensa")

	_g("44-49. Refeicao concluida offline paga uma vez e inicia a recarga")
	var done := _snapshot({"activity": _feeding_activity("running", 4.0)})
	# 4 s de refeicao + 100 s depois dela
	var out3 := OfflineProgress.reconcile(done, _config, 1_000_104, MAX_ENERGY)
	var snap3: Dictionary = out3["snapshot"]
	var report3: Dictionary = out3["report"]
	var prog3: Dictionary = snap3["progression"]
	_check(snap3["activity"] == null, "atividade limpa")
	_check(int(prog3["bond"]) == 1, "vinculo +1 (racao)")
	_check(int(prog3["energy"]) >= 90, "energia 70 +20 da racao e mais o descanso: %d" % int(prog3["energy"]))
	_check(String(report3["meal_completed"]) == "Racao", "relatorio: '%s'" % report3["meal_completed"])
	var cooldown3 := float((snap3["food_cooldowns"] as Dictionary)["kibble"])
	_check(is_equal_approx(cooldown3, 200.0),
		"recarga de 300 s comeca na conclusao e ja correu 100 s: %.0f" % cooldown3)

	_g("46-47. Energia cheia: vinculo e recarga acontecem mesmo assim")
	var full := _snapshot({"progression": {"energy": 100, "strength": 0, "bond": 0},
		"activity": _feeding_activity("running", 4.0)})
	var out4 := OfflineProgress.reconcile(full, _config, 1_000_010, MAX_ENERGY)
	var snap4: Dictionary = out4["snapshot"]
	_check(int((snap4["progression"] as Dictionary)["energy"]) == 100, "energia respeita o teto")
	_check(int((snap4["progression"] as Dictionary)["bond"]) == 1, "vinculo creditado")
	_check((snap4["food_cooldowns"] as Dictionary).has("kibble"), "recarga iniciada")
	_check(String((out4["report"] as Dictionary)["meal_completed"]) != "", "refeicao registrada")

	_g("50. Reconciliar de novo o estado ja reconciliado nao duplica nada")
	var again := OfflineProgress.reconcile(snap3.duplicate(true), _config,
		int(snap3["saved_at_unix"]), MAX_ENERGY)
	var snap5: Dictionary = again["snapshot"]
	_check(int((snap5["progression"] as Dictionary)["bond"]) == 1,
		"vinculo continua 1 (%d)" % int((snap5["progression"] as Dictionary)["bond"]))
	_check(int((snap5["progression"] as Dictionary)["energy"]) == int(prog3["energy"]),
		"energia inalterada")


# --------------------------------------------------------------------------------------
# 51-60. Treino offline
# --------------------------------------------------------------------------------------

func _exercise_activity(phase: String, remaining: float, spent: bool, id := "push_ups") -> Dictionary:
	return {"type": "exercise", "phase": phase, "content_id": id, "remaining_seconds": remaining,
		"energy_already_spent": spent, "reward_already_applied": false,
		"target_id": "PushUpsPoint"}


func _test_offline_exercise() -> void:
	_g("51-52. Treino reservado ou a caminho e cancelado, sem debito")
	for phase in ["reserved", "walking"]:
		var snapshot := _snapshot({"activity": _exercise_activity(phase, 0.0, false)})
		var out := OfflineProgress.reconcile(snapshot, _config, 1_000_010, MAX_ENERGY)
		var final: Dictionary = out["snapshot"]
		_check(final["activity"] == null, "fase '%s': reserva desfeita" % phase)
		_check(int((final["progression"] as Dictionary)["strength"]) == 0, "nenhuma forca")
		_check(int((final["progression"] as Dictionary)["energy"]) >= 70, "nenhum debito")

	_g("53-54. Treino incompleto retoma sem segundo debito nem forca")
	var partial := _snapshot({"progression": {"energy": 55, "strength": 0, "bond": 0},
		"activity": _exercise_activity("running", 20.0, true)})
	var out2 := OfflineProgress.reconcile(partial, _config, 1_000_005, MAX_ENERGY)
	var snap2: Dictionary = out2["snapshot"]
	_check(is_equal_approx(float((snap2["activity"] as Dictionary)["remaining_seconds"]), 15.0),
		"restam %.1f s" % float((snap2["activity"] as Dictionary)["remaining_seconds"]))
	_check(int((snap2["progression"] as Dictionary)["energy"]) == 55, "energia intacta: sem novo debito")
	_check(int((snap2["progression"] as Dictionary)["strength"]) == 0, "nenhuma forca ainda")

	_g("55-57, 60. Treino concluido concede forca uma vez e o resto vira descanso")
	var done := _snapshot({"progression": {"energy": 55, "strength": 20, "bond": 0},
		"activity": _exercise_activity("running", 20.0, true)})
	var out3 := OfflineProgress.reconcile(done, _config, 1_000_140, MAX_ENERGY)
	var snap3: Dictionary = out3["snapshot"]
	var prog3: Dictionary = snap3["progression"]
	_check(int(prog3["strength"]) == 25, "forca 20 + 5 = %d" % int(prog3["strength"]))
	_check(int(prog3["energy"]) == 57, "energia 55 + 2 do descanso (120 s) = %d" % int(prog3["energy"]))
	_check(snap3["activity"] == null, "atividade limpa")
	_check(String((out3["report"] as Dictionary)["exercise_completed"]) == "Flexoes",
		"relatorio: '%s'" % (out3["report"] as Dictionary)["exercise_completed"])

	_g("56. O nivel acompanha a forca restaurada")
	_wipe()
	var w := _world()
	w.model.restore(int(prog3["energy"]), int(prog3["strength"]), 0)
	_check(w.model.get_level() == 2, "forca %d -> nivel %d" % [w.model.get_strength(), w.model.get_level()])
	_check(w.model.has_unlock(&"level_2_celebration"), "desbloqueio derivado presente")
	_check(not w.model.has_unlock(&"dumbbells"), "e os que nao foram alcancados continuam fora")
	w.free_all()

	_g("58. Snapshot incoerente sobre o debito e recusado")
	var manager := _validator()
	var incoherent := _snapshot({"activity": _exercise_activity("running", 5.0, false)})
	_check(not manager.validate(incoherent, _config, MAX_ENERGY).is_empty(),
		"treino em execucao sem debito e rejeitado")

	_g("59. reward_already_applied impede nova forca")
	var paid := _exercise_activity("running", 5.0, true)
	paid["reward_already_applied"] = true
	var out4 := OfflineProgress.reconcile(_snapshot({"activity": paid}), _config, 1_000_100, MAX_ENERGY)
	_check(int(((out4["snapshot"] as Dictionary)["progression"] as Dictionary)["strength"]) == 0,
		"nenhuma forca concedida de novo")
	manager.free()


# --------------------------------------------------------------------------------------
# 61-71. Descanso e recargas offline
# --------------------------------------------------------------------------------------

func _test_offline_rest_and_cooldowns() -> void:
	_g("61-66. Descanso offline: taxa, acumulador e teto")
	var out := OfflineProgress.reconcile(_snapshot(), _config, 1_000_060, MAX_ENERGY)
	_check(int(((out["snapshot"] as Dictionary)["progression"] as Dictionary)["energy"]) == 71,
		"60 s de ausencia = +1 energia")

	var partial := _snapshot({"rest": {"accumulated_seconds": 30.0}})
	var out2 := OfflineProgress.reconcile(partial, _config, 1_000_030, MAX_ENERGY)
	_check(int(((out2["snapshot"] as Dictionary)["progression"] as Dictionary)["energy"]) == 71,
		"acumulador 30 s + ausencia 30 s = +1 energia")

	var out3 := OfflineProgress.reconcile(_snapshot(), _config, 1_000_095, MAX_ENERGY)
	var snap3: Dictionary = out3["snapshot"]
	_check(int((snap3["progression"] as Dictionary)["energy"]) == 71, "95 s = +1")
	_check(is_equal_approx(float((snap3["rest"] as Dictionary)["accumulated_seconds"]), 35.0),
		"restam %.1f s no acumulador" % float((snap3["rest"] as Dictionary)["accumulated_seconds"]))

	var out4 := OfflineProgress.reconcile(_snapshot(), _config, 1_000_000 + 28800, MAX_ENERGY)
	var snap4: Dictionary = out4["snapshot"]
	_check(int((snap4["progression"] as Dictionary)["energy"]) == 100, "8 h enchem a energia")
	_check(is_zero_approx(float((snap4["rest"] as Dictionary)["accumulated_seconds"])),
		"sem credito oculto apos a saturacao")
	_check(int((snap4["progression"] as Dictionary)["strength"]) == 0
		and int((snap4["progression"] as Dictionary)["bond"]) == 0,
		"descanso nao mexe em forca nem vinculo")

	var full := _snapshot({"progression": {"energy": 100, "strength": 0, "bond": 0},
		"rest": {"accumulated_seconds": 50.0}})
	var out5 := OfflineProgress.reconcile(full, _config, 1_000_600, MAX_ENERGY)
	_check(is_zero_approx(float(((out5["snapshot"] as Dictionary)["rest"] as Dictionary)["accumulated_seconds"])),
		"energia ja cheia: o tempo passa sem virar credito")

	_g("67-69. Recargas existentes diminuem e param em zero")
	var cooling := _snapshot({"food_cooldowns": {"kibble": 300.0, "chicken_rice": 900.0}})
	var out6 := OfflineProgress.reconcile(cooling, _config, 1_000_400, MAX_ENERGY)
	var cooldowns6: Dictionary = (out6["snapshot"] as Dictionary)["food_cooldowns"]
	_check(is_zero_approx(float(cooldowns6["kibble"])), "racao chega a zero (%.0f)" % float(cooldowns6["kibble"]))
	_check(is_equal_approx(float(cooldowns6["chicken_rice"]), 500.0),
		"frango baixa para %.0f, sem afetar o outro" % float(cooldowns6["chicken_rice"]))
	var out7 := OfflineProgress.reconcile(cooling.duplicate(true), _config, 1_100_000, MAX_ENERGY)
	var cooldowns7: Dictionary = (out7["snapshot"] as Dictionary)["food_cooldowns"]
	for key in cooldowns7:
		_check(float(cooldowns7[key]) >= 0.0, "%s nunca fica negativo (%.0f)" % [key, float(cooldowns7[key])])
	_check((out6["report"] as Dictionary)["foods_ready"].size() == 1,
		"o relatorio anota 1 alimento liberado")


# --------------------------------------------------------------------------------------
# 72-77. Retomada em runtime
# --------------------------------------------------------------------------------------

func _test_resume() -> void:
	_g("72, 74-76. EATING incompleto retoma no ponto, sem repetir caminhada nem recompensa")
	_wipe()
	var snapshot := _snapshot({"saved_at_unix": 1_000_000,
		"activity": _feeding_activity("running", 4.0)})
	snapshot["saved_at_unix"] = int(Time.get_unix_time_from_system()) - 1
	_write(_path("savegame.json"), JSON.stringify(snapshot))
	var w := _world()
	_check(w.dog.get_current_state() == Caramelo.State.EATING,
		"retomou em %s" % Caramelo.state_name(w.dog.get_current_state()))
	_check(w.dog.position.distance_to(FOOD_POINT) < 0.01, "no FoodPoint %s" % w.dog.position)
	_check(w.feeding.get_pending_food() == &"kibble", "refeicao pendente restaurada")
	_check(w.model.get_bond() == 0, "nenhuma recompensa antecipada")
	var remaining := w.dog.get_state_remaining()
	_check(remaining > 0.0 and remaining <= 4.0, "restam %.2f s" % remaining)

	_g("76. A recompensa sai so na conclusao posterior")
	for _i in 600:
		if w.feeding.has_pending_meal():
			w.dog.simulate(1.0 / 60.0)
	_check(w.model.get_bond() == 1, "vinculo creditado ao terminar: %d" % w.model.get_bond())
	_check(w.model.get_energy() == 90, "energia %d" % w.model.get_energy())
	w.free_all()

	_g("73, 75. TRAINING incompleto retoma sem segundo debito")
	_wipe()
	var training := _snapshot({"progression": {"energy": 55, "strength": 0, "bond": 0},
		"activity": _exercise_activity("running", 10.0, true)})
	training["saved_at_unix"] = int(Time.get_unix_time_from_system()) - 1
	_write(_path("savegame.json"), JSON.stringify(training))
	var w2 := _world()
	_check(w2.dog.get_current_state() == Caramelo.State.TRAINING,
		"retomou em %s" % Caramelo.state_name(w2.dog.get_current_state()))
	_check(w2.dog.position.distance_to(PUSH_UPS_POINT) < 0.01, "no PushUpsPoint %s" % w2.dog.position)
	_check(w2.model.get_energy() == 55, "energia intacta: sem segundo debito (%d)" % w2.model.get_energy())
	_check(w2.exercise.is_running(), "o sistema sabe que o treino ja comecou")

	_g("77. Fechar durante a retomada produz snapshot coerente")
	var snapshot2 := w2.save.build_snapshot(int(Time.get_unix_time_from_system()))
	var activity2: Dictionary = snapshot2["activity"]
	_check(String(activity2["type"]) == "exercise" and String(activity2["phase"]) == "running",
		"atividade gravada: %s/%s" % [activity2["type"], activity2["phase"]])
	_check(bool(activity2["energy_already_spent"]), "energia marcada como ja debitada")
	_check(float(activity2["remaining_seconds"]) > 0.0,
		"tempo restante %.2f s" % float(activity2["remaining_seconds"]))
	var manager := _validator()
	_check(manager.validate(snapshot2, _config, MAX_ENERGY).is_empty(), "e o snapshot e valido")
	manager.free()

	for _i in 1200:
		if w2.exercise.has_pending_exercise():
			w2.dog.simulate(1.0 / 60.0)
	_check(w2.model.get_strength() == 5, "forca concedida so na conclusao: %d" % w2.model.get_strength())
	_check(w2.model.get_energy() == 55, "e a energia nunca foi debitada de novo")
	w2.free_all()


# --------------------------------------------------------------------------------------
# 78-88. Inicializacao e interface
# --------------------------------------------------------------------------------------

func _test_startup_and_ui() -> void:
	_g("78-80, 88. A sessao carrega antes de liberar interacao")
	_wipe()
	var w := _world()
	w.model.restore(45, 30, 6)
	w.save.save_now(int(Time.get_unix_time_from_system()))
	w.free_all()

	var ready_count: Array = []
	var w2 := _world()
	w2.session.session_ready.connect(func() -> void: ready_count.append(true))
	_check(w2.session.is_session_ready(), "a sessao ja esta pronta no primeiro quadro")
	_check(w2.feeding.is_configured() and w2.exercise.is_configured() and w2.rest.is_configured(),
		"os sistemas so foram configurados depois da carga")
	_check(w2.model.get_strength() == 30, "estado carregado: forca %d" % w2.model.get_strength())
	var energy_label: Label = w2.hud.get_node("Anchor/Panel/Layout/Energy/Value")
	w2.dog.select()
	_check(energy_label.text.contains("/100") and not energy_label.text.contains("70/"),
		"o HUD reflete o estado carregado: '%s'" % energy_label.text)
	w2.free_all()

	_g("81-86. Resumo offline")
	_check(OfflineSummary_lines({"has_events": false}).is_empty(), "jogo novo nao gera linhas")
	var quiet := OfflineProgress.reconcile(_snapshot(), _config, 1_000_005, MAX_ENERGY)
	_check(OfflineSummary_lines(quiet["report"]).is_empty(),
		"ausencia curta sem nenhum evento nao gera linhas")

	var rested := OfflineProgress.reconcile(_snapshot(), _config, 1_008_100, MAX_ENERGY)
	var lines := OfflineSummary_lines(rested["report"])
	_check(lines.size() >= 2, "%d linhas: %s" % [lines.size(), str(lines)])
	_check(_any(lines, "ficou fora"), "informa o tempo")
	_check(_any(lines, "recuperou"), "informa a energia recuperada")
	_check(not _any(lines, "força"), "e nao inventa forca que nao houve")

	var meal := OfflineProgress.reconcile(
		_snapshot({"activity": _feeding_activity("running", 4.0)}), _config, 1_000_104, MAX_ENERGY)
	_check(_any(OfflineSummary_lines(meal["report"]), "terminou de comer"), "refeicao concluida aparece")

	var training := OfflineProgress.reconcile(
		_snapshot({"progression": {"energy": 55, "strength": 0, "bond": 0},
			"activity": _exercise_activity("running", 20.0, true)}), _config, 1_000_140, MAX_ENERGY)
	_check(_any(OfflineSummary_lines(training["report"]), "força"), "treino concluido aparece")

	var backwards := OfflineProgress.reconcile(_snapshot(), _config, 900_000, MAX_ENERGY)
	var back_lines := OfflineSummary_lines(backwards["report"])
	_check(_any(back_lines, "retrocedeu"), "relogio regressivo tem mensagem propria: %s" % str(back_lines))
	_check(back_lines.size() == 1, "e nada mais e mostrado")

	_check(_any(OfflineSummary_lines({"has_events": true, "recovery_message": "x",
		"clock_went_backwards": false, "elapsed_seconds": 0.0}), "backup"),
		"recuperacao de backup tem linha propria")

	_g("86-87. O painel bloqueia o mundo enquanto aberto e libera ao fechar")
	var w3 := _world()
	_check(not w3.summary.call("is_open"), "comeca fechado")
	_check(w3.summary.mouse_filter == Control.MOUSE_FILTER_IGNORE, "fechado, nao intercepta cliques")
	w3.summary.call("show_report", rested["report"])
	_check(w3.summary.call("is_open"), "abre com eventos reais")
	_check(w3.summary.mouse_filter == Control.MOUSE_FILTER_STOP, "aberto, segura os cliques do mundo")
	w3.summary.call("close")
	_check(not w3.summary.call("is_open") and w3.summary.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"fechar libera a interacao")
	w3.free_all()


func OfflineSummary_lines(report: Dictionary) -> PackedStringArray:
	return load("res://scripts/ui/offline_summary.gd").build_lines(report)


func _any(lines: PackedStringArray, needle: String) -> bool:
	for line in lines:
		if line.to_lower().contains(needle.to_lower()):
			return true
	return false


# --------------------------------------------------------------------------------------
# 89-98. Autosave
# --------------------------------------------------------------------------------------

func _test_autosave() -> void:
	_g("89-95. Gatilhos marcam o save, e o debounce agrupa")
	_wipe()
	var w := _world()
	var writes: Array = []
	w.save.save_completed.connect(func(_p: String) -> void: writes.append(true))
	w.save.save_now(int(Time.get_unix_time_from_system()))
	writes.clear()

	_check(not w.save.is_dirty(), "estado limpo apos gravar")
	w.model.add_strength(25)                                    # sobe de nivel
	_check(w.save.is_dirty(), "subir de nivel marca o save")
	w.save.simulate(0.2)
	_check(writes.is_empty(), "o debounce ainda segura a escrita")
	w.model.add_strength(5)
	w.model.add_bond(1)
	w.save.simulate(0.4)
	_check(writes.size() == 1, "eventos proximos viram uma escrita so (%d)" % writes.size())

	writes.clear()
	w.feeding.request_feeding(&"kibble")
	for _i in 5400:
		if not w.feeding.has_pending_meal():
			break
		w.dog.simulate(1.0 / 60.0)
	_check(w.save.is_dirty(), "alimentacao concluida marca o save")
	w.save.simulate(0.6)
	_check(writes.size() == 1, "e grava uma vez")

	writes.clear()
	w.model.restore_energy(100)
	w.exercise.request_exercise(&"push_ups")
	w.run_until_state(Caramelo.State.TRAINING)
	_check(w.save.is_dirty(), "inicio de treino marca o save, ja com a energia debitada")
	var snapshot := w.save.build_snapshot(int(Time.get_unix_time_from_system()))
	_check(bool((snapshot["activity"] as Dictionary)["energy_already_spent"]),
		"e o snapshot ja registra o debito")
	w.save.simulate(0.6)
	for _i in 5400:
		if not w.exercise.has_pending_exercise():
			break
		w.dog.simulate(1.0 / 60.0)
	_check(w.save.is_dirty(), "conclusao de treino marca o save")

	_g("94. Recarga pingando por segundo nao vira escrita por segundo")
	w.save.simulate(0.6)
	writes.clear()
	for _i in 600:
		w.feeding.simulate(1.0 / 60.0)
		w.save.simulate(1.0 / 60.0)
	_check(writes.is_empty(), "10 s de recarga correndo: %d escritas" % writes.size())

	_g("96. Autosave periodico com tempo simulado")
	w.model.add_bond(1)
	w.save.mark_dirty()
	writes.clear()
	w.save.simulate(0.6)
	_check(writes.size() == 1, "o debounce grava")
	w.save.mark_dirty()
	w.save.simulate(SaveManager.AUTOSAVE_SECONDS + 1.0)
	_check(writes.size() >= 2, "e o autosave periodico tambem (%d escritas)" % writes.size())

	_g("97-98. Encerramento forca a escrita; falha nao derruba a execucao")
	w.model.add_bond(1)
	w.save.mark_dirty()
	writes.clear()
	w.save._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(writes.size() == 1, "encerramento grava ignorando o debounce")

	var broken := BrokenFiles.new()
	broken.fail_write = true
	w.save.set_file_adapter(broken)
	var failures: Array = []
	w.save.save_failed.connect(func(reason: String) -> void: failures.append(reason))
	w.model.add_bond(1)
	w.save.mark_dirty()
	w.save.simulate(0.6)
	_check(failures.size() == 1, "a falha e anunciada: %s" % failures[0])
	_check(w.save.is_dirty(), "o estado continua sujo, para tentar de novo")
	_check(w.model.get_bond() > 0, "e o jogo segue rodando normalmente")
	w.save.set_file_adapter(SaveManager.FileAdapter.new())
	w.free_all()


func _report() -> void:
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
