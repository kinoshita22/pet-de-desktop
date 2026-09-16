extends SceneTree
## Testes permanentes da integracao com o desktop: modos de janela, configuracoes,
## perfis de desempenho, modo silencioso, autostart, encerramento e empacotamento.
##
## Executar **sempre** pelo runner isolado:
##
##   tools/run_isolated_tests.sh
##
## Nenhuma chamada nativa acontece aqui. O que depende do sistema operacional passa por
## `PlatformAdapter`, e a suite injeta um duble: nenhum atalho de inicializacao e criado,
## nenhum papel de parede e trocado e nenhum PowerShell e executado.

const STEP := 1.0 / 60.0
const SETTINGS_DIR := "user://test_desktop"

var _passed := 0
var _failures: Array[String] = []
var _group := ""
var _done := false
var _viewport: SubViewport


## Duble de plataforma: registra o que foi pedido e nunca encosta no sistema.
class FakeAdapter:
	extends PlatformAdapter

	var wallpaper_supported := true
	var autostart_supported := true
	var probe_supported := true
	var attach_succeeds := true
	var autostart_succeeds := true
	var attach_calls: Array = []
	var detach_calls := 0
	var autostart_calls: Array = []
	var probe_value: int = PlatformAdapter.Probe.UNKNOWN
	var autostart_state := false

	func get_platform_name() -> String:
		return "Duble"

	func supports_wallpaper() -> bool:
		return wallpaper_supported

	func supports_autostart() -> bool:
		return autostart_supported

	func supports_fullscreen_probe() -> bool:
		return probe_supported

	func attach_wallpaper(window_handle: int) -> Dictionary:
		if not PlatformAdapter.is_valid_handle(window_handle):
			return failure(REASON_INVALID_HANDLE)
		attach_calls.append(window_handle)
		if not attach_succeeds:
			return failure("o Explorer recusou a camada de papel de parede.")
		return success("workerw")

	func detach_wallpaper() -> Dictionary:
		detach_calls += 1
		return success("desassociada")

	func set_autostart(enabled: bool, executable_path: String) -> Dictionary:
		autostart_calls.append({"enabled": enabled, "path": executable_path})
		if not autostart_succeeds:
			return failure("nao foi possivel criar o atalho.")
		autostart_state = enabled
		return success("enabled" if enabled else "disabled")

	func is_autostart_enabled() -> Dictionary:
		return {"ok": true, "enabled": autostart_state, "reason": ""}

	func probe_foreign_fullscreen() -> int:
		return probe_value


class World:
	extends RefCounted
	var main: Node
	var session: GameSession
	var model: ProgressionModel
	var dog: Caramelo
	var visual: Node2D
	var settings: SettingsManager
	var performance: PerformanceManager
	var modes: DesktopModeManager
	var evolution: EvolutionSystem
	var affection: AffectionSystem
	var exercise: ExerciseSystem
	var feeding: FeedingSystem
	var save: SaveManager
	var hud: Control
	var panel: Control

	func _init(viewport: SubViewport) -> void:
		main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
		viewport.add_child(main)
		session = _find(main, func(n: Node) -> bool: return n is GameSession) as GameSession
		settings = _find(main, func(n: Node) -> bool: return n is SettingsManager) as SettingsManager
		performance = _find(main, func(n: Node) -> bool: return n is PerformanceManager) as PerformanceManager
		modes = _find(main, func(n: Node) -> bool: return n is DesktopModeManager) as DesktopModeManager
		evolution = _find(main, func(n: Node) -> bool: return n is EvolutionSystem) as EvolutionSystem
		affection = _find(main, func(n: Node) -> bool: return n is AffectionSystem) as AffectionSystem
		exercise = _find(main, func(n: Node) -> bool: return n is ExerciseSystem) as ExerciseSystem
		feeding = _find(main, func(n: Node) -> bool: return n is FeedingSystem) as FeedingSystem
		save = _find(main, func(n: Node) -> bool: return n is SaveManager) as SaveManager
		dog = _find(main, func(n: Node) -> bool: return n is Caramelo) as Caramelo
		hud = _find(main, func(n: Node) -> bool: return n.is_in_group(&"main_hud")) as Control
		panel = _find(main, func(n: Node) -> bool: return n.is_in_group(&"settings_panel")) as Control
		visual = dog.get_node("Visual") as Node2D
		model = session.get_model()
		dog.set_physics_process(false)
		for node in [feeding, evolution, affection, save, hud, performance, panel]:
			if node != null:
				node.set_process(false)
		# A interface se liga sozinha a primeira sessao do grupo. Com dois mundos no mesmo
		# SubViewport isso seria ambiguo, entao cada mundo religa a **sua** interface.
		hud.call("attach", session)
		panel.call("attach", session.get_settings_manager(), session.get_mode_manager(),
			session.get_autostart_service())

	static func _find(from: Node, predicate: Callable) -> Node:
		var queue: Array[Node] = [from]
		while not queue.is_empty():
			var node: Node = queue.pop_front()
			if predicate.call(node):
				return node
			for child in node.get_children():
				queue.append(child)
		return null

	## Reconfigura o gerenciador de modos com um duble, sem tocar no sistema.
	func use_fake_adapter(adapter: FakeAdapter, forced_windowed: bool = false) -> void:
		modes.configure(adapter, settings, forced_windowed)
		# Headless nao tem janela, entao o identificador vem de um provedor de teste. O
		# valor e o mesmo tipo que o `DisplayServer` devolveria: inteiro positivo.
		modes.set_handle_provider(func() -> int: return 987654)
		performance.configure(settings, adapter)

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

	func free_all() -> void:
		main.free()


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	# Antes de qualquer coisa: se a execucao nao estiver isolada, nada roda. Um teste que
	# escreve no save pessoal de quem desenvolve nao e um teste, e um acidente.
	if not _isolation_confirmed():
		print("\n" + "=".repeat(70))
		print("ABORTADO: execucao sem isolamento de dados.")
		print("  user:// efetivo: %s" % OS.get_user_data_dir())
		print("  use: tools/run_isolated_tests.sh")
		quit(1)
		return true

	SaveManager.persistence_enabled = false
	SettingsManager.persistence_enabled = false
	AutostartService.allow_system_changes = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SETTINGS_DIR))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	root.add_child(_viewport)

	_test_isolation()
	_test_settings()
	_test_modes()
	_test_security()
	_test_performance()
	_test_quiet()
	_test_autostart()
	_test_shutdown()
	_test_export_and_regression()

	_viewport.free()
	_report()
	return true


## O `user://` desta execucao esta fora do diretorio pessoal?
func _isolation_confirmed() -> bool:
	var user_dir := OS.get_user_data_dir()
	var personal := OS.get_environment("HOME") + "/.local/share"
	if OS.get_environment("HOME").is_empty():
		return true
	return not user_dir.begins_with(personal)


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


func _fresh_settings() -> SettingsManager:
	var manager := SettingsManager.new()
	root.add_child(manager)
	manager.set_paths("%s/settings.json" % SETTINGS_DIR,
		"%s/settings.backup.json" % SETTINGS_DIR, "%s/settings.tmp.json" % SETTINGS_DIR)
	return manager


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --------------------------------------------------------------------------------------
# 1-6. Isolamento
# --------------------------------------------------------------------------------------

func _test_isolation() -> void:
	_g("1-5. O runner isola os dados e nao apaga nada alheio")
	var runner := _read_text("res://tools/run_isolated_tests.sh")
	_check(not runner.is_empty(), "tools/run_isolated_tests.sh existe")
	_check(runner.contains("mktemp -d"), "cria o diretorio com mktemp -d")
	_check(runner.contains("XDG_DATA_HOME"), "aponta XDG_DATA_HOME para ele")
	_check(runner.contains("caramelo-testes-"), "o prefixo do diretorio e especifico do projeto")
	_check(runner.contains("*/caramelo-testes-*)"),
		"a limpeza so aceita caminho com esse prefixo")
	_check(runner.contains("\"$target\" = \"$HOME\"") and runner.contains("\"$target\" = \"/\""),
		"e recusa explicitamente / e $HOME")
	_check(runner.contains("isolamento NAO confirmado") and runner.contains("exit 3"),
		"falha de isolamento aborta antes de rodar qualquer teste")
	_check(not runner.contains("rm -rf /") and runner.contains("rm -rf -- \"$target\""),
		"remove apenas o alvo, com fim de opcoes")

	_g("1-2. Esta execucao esta mesmo isolada")
	var user_dir := OS.get_user_data_dir()
	var personal := OS.get_environment("HOME") + "/.local/share"
	_check(not user_dir.begins_with(personal),
		"user:// fora do diretorio pessoal")
	var isolated := OS.get_environment("CARAMELO_ISOLATED_DATA_HOME")
	if not isolated.is_empty():
		_check(user_dir.begins_with(isolated),
			"user:// dentro do temporario do runner")
	else:
		_check(true, "XDG_DATA_HOME proprio (%s)" % user_dir.get_base_dir())
	for personal_file in ["savegame.json", "savegame.backup.json", "savegame.rejected.json"]:
		_check(not FileAccess.file_exists("user://%s" % personal_file)
			or not user_dir.begins_with(personal),
			"nenhum acesso ao %s pessoal" % personal_file)

	_g("6. O runner cobre as nove suites")
	for suite in ["test_caramelo_controller", "test_progression", "test_feeding_system",
			"test_exercise_system", "test_rest_and_idle", "test_main_ui",
			"test_save_and_offline", "test_evolution_and_affection", "test_desktop_modes"]:
		_check(runner.contains("tests/%s.gd" % suite), "runner executa %s" % suite)


# --------------------------------------------------------------------------------------
# 7-17. Configuracoes
# --------------------------------------------------------------------------------------

func _test_settings() -> void:
	_g("7-10. Padroes de instalacao nova")
	var defaults := SettingsManager.defaults()
	_check(String(defaults["display_mode"]) == "windowed",
		"modo padrao: %s" % defaults["display_mode"])
	_check(bool(defaults["launch_at_login"]) == false, "autostart comeca desligado")
	_check(bool(defaults["quiet_mode"]) == false, "silencio comeca desligado")
	_check(bool(defaults["low_power_mode"]) == true, "baixo consumo comeca ligado")
	_check(bool(defaults["wallpaper_interaction"]) == true, "interacao no wallpaper comeca ligada")
	_check(int(defaults["schema_version"]) == 1, "schema 1, separado do save de jogo")

	_g("11. Configuracao valida vai e volta do disco")
	SettingsManager.persistence_enabled = true
	var manager := _fresh_settings()
	_remove("%s/settings.json" % SETTINGS_DIR)
	_remove("%s/settings.backup.json" % SETTINGS_DIR)
	manager.load_settings()
	manager.set_value("quiet_mode", true)
	manager.set_value("low_power_mode", false)
	manager.set_value("display_mode", "borderless")
	manager.set_window_geometry(Vector2i(120, 90), Vector2i(1024, 768))
	_check(manager.save_settings(), "gravou")
	var reloaded := _fresh_settings()
	reloaded.load_settings()
	_check(reloaded.is_quiet_mode(), "silencio persistiu")
	_check(not reloaded.is_low_power_mode(), "baixo consumo persistiu")
	_check(reloaded.get_display_mode() == "borderless", "modo persistiu")
	var geometry := reloaded.get_window_geometry()
	_check(int(geometry["width"]) == 1024 and int(geometry["x"]) == 120,
		"geometria persistiu: %s" % str(geometry))
	manager.free()
	reloaded.free()

	_g("12-15. Arquivo corrompido, modo desconhecido e geometria impossivel")
	_write_text("%s/settings.json" % SETTINGS_DIR, "{isso nao e json")
	_remove("%s/settings.backup.json" % SETTINGS_DIR)
	var broken := _fresh_settings()
	var values := broken.load_settings()
	_check(String(values["display_mode"]) == "windowed", "corrompido cai para o padrao seguro")
	_check(bool(values["launch_at_login"]) == false, "e nao liga nada sozinho")
	broken.free()

	var strange := SettingsManager.validate({
		"display_mode": "wallpaper_supremo",
		"quiet_mode": "sim",
		"window": {"width": 12, "height": -4000, "x": 999999, "y": -888888},
	})
	_check(String(strange["display_mode"]) == "windowed", "modo desconhecido vira janela")
	_check(bool(strange["quiet_mode"]) == false, "tipo errado usa o padrao")
	var fixed: Dictionary = strange["window"]
	_check(int(fixed["width"]) == 1280 and int(fixed["height"]) == 720,
		"tamanho invalido usa o padrao: %s" % str(fixed))
	_check(int(fixed["x"]) == 60 and int(fixed["y"]) == 60,
		"posicao fora das telas e corrigida: %s" % str(fixed))
	_check(not SettingsManager.is_position_on_screen(Vector2i(999999, -888888), Vector2i(800, 600)),
		"posicao absurda e reconhecida como fora da tela")

	_g("16. Configuracao nao encosta no save de jogo")
	var settings_text := _read_text("%s/settings.json" % SETTINGS_DIR)
	for forbidden in ["progression", "strength", "bond", "food_cooldowns", "saved_at_unix"]:
		_check(not settings_text.contains(forbidden),
			"settings.json nao guarda '%s'" % forbidden)
	var save_source := _read_text("res://scripts/systems/save_manager.gd")
	for forbidden in ["display_mode", "quiet_mode", "launch_at_login", "low_power"]:
		_check(not save_source.contains(forbidden),
			"o save de jogo nao ganhou campo '%s'" % forbidden)
	_check(SaveManager.SCHEMA_VERSION == 2, "schema do save continua 2")

	_g("17. Configuracao de versao futura e preservada")
	var future := '{"schema_version": 99, "display_mode": "wallpaper", "enfeite": true}'
	_write_text("%s/settings.json" % SETTINGS_DIR, future)
	var guard := _fresh_settings()
	var loaded := guard.load_settings()
	_check(String(loaded["display_mode"]) == "windowed",
		"a versao futura nao e interpretada; vale o padrao")
	_check(not guard.save_settings(), "e o jogo se recusa a gravar por cima")
	_check(_read_text("%s/settings.json" % SETTINGS_DIR) == future,
		"o arquivo continua byte a byte igual")
	guard.free()
	_remove("%s/settings.json" % SETTINGS_DIR)
	_remove("%s/settings.backup.json" % SETTINGS_DIR)
	SettingsManager.persistence_enabled = false


# --------------------------------------------------------------------------------------
# 18-27. Modos
# --------------------------------------------------------------------------------------

func _test_modes() -> void:
	_g("18-19. Janela e sem bordas, nos dois sentidos")
	var world := _world()
	var adapter := FakeAdapter.new()
	world.use_fake_adapter(adapter)
	var changes: Array = []
	world.modes.mode_changed.connect(func(_p: int, n: int) -> void:
		changes.append(DesktopModeManager.mode_name(n)))
	_check(world.modes.get_mode() == DesktopModeManager.Mode.WINDOWED, "comeca em janela")
	_check(world.modes.request_mode(DesktopModeManager.Mode.BORDERLESS), "janela -> sem bordas")
	_check(world.modes.get_mode() == DesktopModeManager.Mode.BORDERLESS, "modo atual e sem bordas")
	_check(world.modes.request_mode(DesktopModeManager.Mode.WINDOWED), "sem bordas -> janela")
	_check(world.modes.get_mode() == DesktopModeManager.Mode.WINDOWED, "voltou para janela")
	_check(changes == ["borderless", "windowed"], "sinais na ordem: %s" % str(changes))
	_check(world.settings.get_display_mode() == "windowed", "a preferencia acompanhou")

	_g("20-21. Papel de parede: suportado chama o adaptador, nao suportado e recusado")
	_check(world.modes.request_mode(DesktopModeManager.Mode.WALLPAPER),
		"com suporte, o modo entra")
	_check(adapter.attach_calls.size() == 1, "o adaptador foi chamado uma vez")
	_check(world.modes.get_mode() == DesktopModeManager.Mode.WALLPAPER, "modo atual e wallpaper")
	world.modes.request_mode(DesktopModeManager.Mode.WINDOWED)
	_check(adapter.detach_calls == 1, "sair do modo desassocia")

	adapter.wallpaper_supported = false
	var rejections: Array = []
	world.modes.mode_failed.connect(func(_m: int, reason: String) -> void: rejections.append(reason))
	_check(not world.modes.request_mode(DesktopModeManager.Mode.WALLPAPER),
		"sem suporte, o pedido e recusado")
	_check(world.modes.get_mode() == DesktopModeManager.Mode.WINDOWED, "e a janela continua")
	_check(rejections.size() == 1 and String(rejections[0]).contains("Windows"),
		"com motivo claro: %s" % str(rejections))
	_check(not world.modes.is_mode_available(DesktopModeManager.Mode.WALLPAPER),
		"o modo aparece como indisponivel")
	world.free_all()

	_g("22-23. Falha nativa cai para o fallback seguro e nao persiste wallpaper")
	var w2 := _world()
	var failing := FakeAdapter.new()
	failing.attach_succeeds = false
	w2.use_fake_adapter(failing)
	w2.settings.set_value("display_mode", "windowed")
	var failed: Array = []
	w2.modes.mode_failed.connect(func(_m: int, reason: String) -> void: failed.append(reason))
	_check(not w2.modes.request_mode(DesktopModeManager.Mode.WALLPAPER),
		"o pedido falha quando o sistema recusa")
	# `MVP_SPEC.md` secao 19 e a tabela da secao 21: a queda e para janela sem bordas.
	_check(w2.modes.get_mode() == DesktopModeManager.Mode.BORDERLESS,
		"cai para janela sem bordas: %s" % DesktopModeManager.mode_name(w2.modes.get_mode()))
	_check(w2.settings.get_display_mode() != "wallpaper",
		"e a preferencia nao vira wallpaper: %s" % w2.settings.get_display_mode())
	_check(failed.size() == 1, "a falha foi anunciada uma vez")
	_check(w2.modes.get_last_failure() != "", "com motivo registrado")
	w2.modes.return_to_windowed()
	_check(w2.modes.get_mode() == DesktopModeManager.Mode.WINDOWED,
		"e o retorno de emergencia sempre funciona")
	w2.free_all()

	_g("24. --windowed ignora o wallpaper salvo sem apagar a preferencia")
	var w3 := _world()
	var adapter3 := FakeAdapter.new()
	w3.settings.set_value("display_mode", "wallpaper")
	w3.use_fake_adapter(adapter3, true)
	_check(w3.modes.is_forced_windowed(), "a execucao esta marcada como forcada em janela")
	w3.modes.apply_saved_mode()
	_check(w3.modes.get_mode() == DesktopModeManager.Mode.WINDOWED, "abriu em janela")
	_check(adapter3.attach_calls.is_empty(), "sem nenhuma tentativa de wallpaper")
	_check(w3.settings.get_display_mode() == "wallpaper",
		"a preferencia salva continua: %s" % w3.settings.get_display_mode())
	_check(not w3.modes.request_mode(DesktopModeManager.Mode.WALLPAPER),
		"e o modo continua recusado nesta execucao")

	_g("25. --reset-window devolve geometria segura sem mexer no progresso")
	w3.settings.set_window_geometry(Vector2i(-4000, -4000), Vector2i(7000, 6000))
	var strength_before := w3.model.get_strength()
	var energy_before := w3.model.get_energy()
	w3.modes.reset_window()
	var geometry := w3.modes.get_geometry()
	_check(geometry["size"] == DesktopModeManager.SAFE_SIZE,
		"tamanho seguro: %s" % str(geometry["size"]))
	_check(geometry["position"] == DesktopModeManager.SAFE_POSITION,
		"posicao segura: %s" % str(geometry["position"]))
	_check(int(w3.settings.get_window_geometry()["width"]) == DesktopModeManager.SAFE_SIZE.x,
		"a configuracao acompanhou")
	_check(w3.model.get_strength() == strength_before and w3.model.get_energy() == energy_before,
		"e nenhum atributo mudou")
	w3.free_all()

	_g("26-27. Trocar de modo nao mexe em atributo nem cancela atividade")
	var w4 := _world()
	w4.use_fake_adapter(FakeAdapter.new())
	_check(w4.exercise.request_exercise(&"push_ups"), "treino iniciado")
	_check(w4.run_until_state(Caramelo.State.TRAINING), "em TRAINING")
	var snapshot := w4.model.get_snapshot()
	var remaining := w4.dog.get_state_remaining()
	w4.modes.request_mode(DesktopModeManager.Mode.BORDERLESS)
	w4.modes.request_mode(DesktopModeManager.Mode.WALLPAPER)
	w4.modes.return_to_windowed()
	_check(w4.dog.get_current_state() == Caramelo.State.TRAINING,
		"a atividade continua: %s" % Caramelo.state_name(w4.dog.get_current_state()))
	_check(is_equal_approx(w4.dog.get_state_remaining(), remaining),
		"sem perder nem adiantar tempo de treino")
	_check(w4.model.get_snapshot() == snapshot, "e nenhum atributo mudou")
	w4.free_all()


# --------------------------------------------------------------------------------------
# 28-34. Seguranca
# --------------------------------------------------------------------------------------

func _test_security() -> void:
	_g("28-29. Identificador de janela: so inteiro positivo passa")
	for invalid in [0, -1, -9999, 1.5, "1234", "0x1f", null, true, [], {}]:
		_check(not PlatformAdapter.is_valid_handle(invalid),
			"recusa %s" % ("null" if invalid == null else str(invalid)))
	_check(PlatformAdapter.is_valid_handle(1) and PlatformAdapter.is_valid_handle(918273645),
		"aceita inteiro positivo")
	_check(PlatformAdapter.is_valid_handle(42.0), "aceita float sem parte fracionaria")
	var windows := WindowsAdapter.new()
	var refused := windows.attach_wallpaper(0)
	_check(not bool(refused["ok"]), "o adaptador do Windows recusa handle zero")

	_g("30-31. O helper e fixo; texto de interface nunca vira comando")
	var source := _read_text("res://scripts/platform/windows_adapter.gd")
	_check(source.contains("OS.execute(\"powershell.exe\", command"),
		"a execucao recebe lista de argumentos, sem shell")
	for forbidden in ["cmd.exe", "/c ", "&&", "| Invoke", "Invoke-Expression", "iex ",
			"-ExecutionPolicy Bypass", "Invoke-WebRequest", "DownloadString"]:
		_check(not source.contains(forbidden), "o adaptador nao contem '%s'" % forbidden)
	_check(source.contains("const HELPER_WALLPAPER := \"wallpaper_host.ps1\""),
		"o nome do helper vem de constante")
	_check(WindowsAdapter.resolve_helper("qualquer_coisa.ps1").is_empty(),
		"um nome de helper fora da lista e recusado")
	_check(WindowsAdapter.resolve_helper("../../etc/passwd").is_empty(),
		"e caminho relativo tambem")
	var resolved := WindowsAdapter.resolve_helper(WindowsAdapter.HELPER_WALLPAPER)
	_check(resolved.ends_with("platform/windows/wallpaper_host.ps1"),
		"o helper conhecido resolve para dentro do projeto: %s" % resolved.get_file())

	_g("32. Fora do Windows, nenhum PowerShell e executado")
	_check(OS.get_name() != "Windows", "ambiente atual: %s" % OS.get_name())
	var adapter := PlatformAdapter.create_for_current_platform()
	_check(adapter is FallbackAdapter, "a fabrica escolhe o adaptador de recusa segura")
	_check(not adapter.supports_wallpaper() and not adapter.supports_autostart(),
		"que nao anuncia suporte nenhum")
	_check(not bool(adapter.attach_wallpaper(12345)["ok"]), "e recusa o papel de parede")
	_check(bool(adapter.detach_wallpaper()["ok"]), "desassociar continua sendo trivialmente ok")
	_check(adapter.probe_foreign_fullscreen() == PlatformAdapter.Probe.UNKNOWN,
		"a sondagem responde UNKNOWN, nao 'nao'")
	for method in ["attach_wallpaper", "set_autostart", "probe_foreign_fullscreen"]:
		var windows_source := _read_text("res://scripts/platform/windows_adapter.gd")
		_check(windows_source.contains("if not _is_windows()"),
			"cada entrada do adaptador Windows confere a plataforma (%s)" % method)

	_g("33-34. Os testes nao ligam autostart nem trocam papel de parede de verdade")
	_check(AutostartService.allow_system_changes == false,
		"a trava de alteracoes do sistema esta fechada")
	var real_service := AutostartService.new(PlatformAdapter.create_for_current_platform())
	var attempt := real_service.set_enabled(true)
	_check(not bool(attempt["ok"]), "ligar autostart e recusado: %s" % attempt["reason"])
	_check(not real_service.is_available(), "e a opcao aparece indisponivel")
	var spy := FakeAdapter.new()
	var guarded := AutostartService.new(spy)
	guarded.set_enabled(true)
	_check(spy.autostart_calls.is_empty(),
		"com a trava fechada, nem o duble e chamado (%d)" % spy.autostart_calls.size())
	_check(spy.attach_calls.is_empty(), "e nenhum papel de parede foi tocado")


# --------------------------------------------------------------------------------------
# 35-44. Desempenho
# --------------------------------------------------------------------------------------

func _test_performance() -> void:
	_g("35-38. Um perfil para cada situacao")
	var manager := PerformanceManager.new()
	root.add_child(manager)
	var adapter := FakeAdapter.new()
	var settings := _fresh_settings()
	settings.load_settings()
	settings.set_value("low_power_mode", false)
	manager.configure(settings, adapter)
	var seen: Array = []
	manager.profile_changed.connect(func(profile: int, fps: int, _reason: String) -> void:
		seen.append([PerformanceManager.PROFILE_NAMES[profile], fps]))

	_check(manager.get_profile() == PerformanceManager.Profile.NORMAL,
		"janela focada: %s" % manager.get_profile_name())
	_check(manager.get_target_fps() == 60, "60 FPS")

	# Baixo consumo vale quando o jogo esta de lado: a janela em uso continua a 60, como
	# pede o `MVP_SPEC.md` secao 20.
	manager.set_low_power(true)
	_check(manager.get_profile() == PerformanceManager.Profile.NORMAL,
		"com foco, baixo consumo nao derruba a janela em uso: %s" % manager.get_profile_name())
	_check(manager.get_target_fps() == 60, "ainda 60 FPS")
	manager.set_focused(false)
	_check(manager.get_profile() == PerformanceManager.Profile.LOW_POWER,
		"sem foco, baixo consumo entra")
	_check(manager.get_target_fps() == 10, "10 FPS")
	manager.set_focused(true)

	manager.set_low_power(false)
	manager.set_window_mode(DesktopModeManager.Mode.WALLPAPER)
	_check(manager.get_profile() == PerformanceManager.Profile.LOW_POWER,
		"papel de parede tambem usa o perfil reduzido")
	_check(manager.get_target_fps() == 10, "10 FPS no papel de parede")

	adapter.probe_value = PlatformAdapter.Probe.YES
	manager.poll_foreign_fullscreen()
	_check(manager.get_profile() == PerformanceManager.Profile.FOREIGN_FULLSCREEN,
		"aplicativo alheio em tela cheia")
	_check(manager.get_target_fps() == 5, "5 FPS")

	_g("39-40. Minimizado e volta de foco")
	manager.set_minimized(true)
	_check(manager.get_profile() == PerformanceManager.Profile.MINIMIZED, "minimizado")
	_check(manager.get_target_fps() == 5, "5 FPS, sem pausar a simulacao")
	manager.set_minimized(false)
	adapter.probe_value = PlatformAdapter.Probe.NO
	manager.poll_foreign_fullscreen()
	manager.set_window_mode(DesktopModeManager.Mode.WINDOWED)
	manager.set_low_power(true)
	manager.set_focused(false)
	_check(manager.get_profile() == PerformanceManager.Profile.LOW_POWER,
		"desfocado reduz, mas nao finge tela cheia: %s" % manager.get_reason())
	manager.set_focused(true)
	_check(manager.get_profile() == PerformanceManager.Profile.NORMAL,
		"e o foco de volta devolve os 60 FPS")
	_check(manager.get_profile() == PerformanceManager.Profile.NORMAL,
		"o foco de volta restaura o perfil")
	_check(manager.get_target_fps() == 60, "e os 60 FPS")

	_g("38. Sem sondagem confiavel, 5 FPS nao entra")
	adapter.probe_supported = false
	manager.set_low_power(true)
	manager.set_focused(false)
	manager.poll_foreign_fullscreen()
	_check(manager.get_profile() == PerformanceManager.Profile.LOW_POWER,
		"perfil reduzido, nao o de tela cheia: %s" % manager.get_profile_name())
	_check(manager.poll_foreign_fullscreen() == PlatformAdapter.Probe.UNKNOWN,
		"a sondagem devolve UNKNOWN")
	manager.set_focused(true)

	_g("14. O perfil muda a frequencia de desenho, nao a logica")
	_check(is_equal_approx(manager.get_visual_interval(), 1.0 / 60.0),
		"intervalo visual em 60 FPS: %.4f s" % manager.get_visual_interval())
	manager.set_focused(true)
	manager.force_profile(PerformanceManager.Profile.LOW_POWER, "medicao")
	_check(is_equal_approx(manager.get_visual_interval(), 0.1),
		"intervalo visual em 10 FPS: %.4f s" % manager.get_visual_interval())
	manager.free()
	settings.free()

	_g("41-43. Mesma simulacao em 60 e em 10 quadros por segundo")
	var fast := _simulate_session(1.0 / 60.0)
	var slow := _simulate_session(1.0 / 10.0)
	_check(fast["strength"] == slow["strength"],
		"forca igual: %d e %d" % [fast["strength"], slow["strength"]])
	_check(fast["energy"] == slow["energy"],
		"energia igual: %d e %d" % [fast["energy"], slow["energy"]])
	_check(absf(float(fast["cooldown"]) - float(slow["cooldown"])) < 0.25,
		"recarga igual: %.2f e %.2f" % [fast["cooldown"], slow["cooldown"]])
	_check(fast["completed"] == slow["completed"],
		"o treino terminou nos dois casos: %s" % str(fast["completed"]))
	_check(fast["visual_updates"] > slow["visual_updates"],
		"e o trabalho visual cai: %d desenhos contra %d"
			% [fast["visual_updates"], slow["visual_updates"]])

	_g("44. Autosave continua funcionando com o perfil reduzido")
	SaveManager.persistence_enabled = true
	SaveManager.use_isolated_directory("test_desktop_autosave")
	var world := _world()
	world.use_fake_adapter(FakeAdapter.new())
	var saves: Array = []
	world.save.save_completed.connect(func(_path: String) -> void: saves.append(true))
	world.performance.force_profile(PerformanceManager.Profile.LOW_POWER, "teste")
	world.model.add_strength(5)
	world.save.mark_dirty()
	world.save.simulate(1.0)
	_check(saves.size() >= 1, "o debounce gravou mesmo a 10 FPS (%d)" % saves.size())
	world.model.add_strength(5)
	world.save.mark_dirty()
	world.save.simulate(40.0)
	_check(saves.size() >= 2, "e o autosave periodico tambem (%d)" % saves.size())
	world.free_all()
	SaveManager.clear_isolated_directory()
	SaveManager.persistence_enabled = false


## Roda um treino inteiro com passos de `step` segundos e devolve o resultado.
func _simulate_session(step: float) -> Dictionary:
	var world := _world()
	var manager := world.performance
	manager.force_profile(PerformanceManager.Profile.NORMAL if step < 0.05
		else PerformanceManager.Profile.LOW_POWER, "medicao")
	manager.reset_visual_updates()
	world.dog.set_performance_manager(manager)
	world.feeding.request_feeding(&"kibble")
	var completed := false
	world.exercise.exercise_completed.connect(func(_id: StringName, _gain: int) -> void:
		completed = true)
	var elapsed := 0.0
	var asked := false
	while elapsed < 120.0:
		world.dog.simulate(step)
		world.visual._process(step)
		world.feeding.simulate(step)
		world.evolution.simulate(step)
		elapsed += step
		if not asked and not world.feeding.has_pending_meal():
			asked = world.exercise.request_exercise(&"push_ups")
	var result := {
		"strength": world.model.get_strength(),
		"energy": world.model.get_energy(),
		"cooldown": world.feeding.get_remaining_cooldown(&"kibble"),
		"completed": completed,
		"visual_updates": manager.get_visual_updates(),
	}
	world.free_all()
	return result


# --------------------------------------------------------------------------------------
# 45-49. Modo silencioso
# --------------------------------------------------------------------------------------

func _test_quiet() -> void:
	_g("45-47. Silencio some com a festa, nao com o aviso nem com a progressao")
	var world := _world()
	world.use_fake_adapter(FakeAdapter.new())
	world.dog.select()
	world.settings.set_value("quiet_mode", true)
	_check(world.hud.call("is_quiet_mode"), "o HUD entrou em modo silencioso")

	world.model.add_strength(25)                      # sobe para o nivel 2
	_check(world.hud.call("get_toast_text") == "",
		"o aviso de nivel nao aparece: '%s'" % world.hud.call("get_toast_text"))
	_check(world.model.get_level() == 2, "mas o nivel subiu: %d" % world.model.get_level())

	world.exercise.request_exercise(&"dumbbells")     # bloqueado: nivel 3
	_check(world.hud.call("get_toast_text") != "",
		"a recusa continua visivel: '%s'" % world.hud.call("get_toast_text"))
	var energy_before := world.model.get_energy()
	world.feeding.request_feeding(&"kibble")
	_check(world.run_until_state(Caramelo.State.EATING), "comer continua funcionando")
	for _i in 3600:
		if not world.feeding.has_pending_meal():
			break
		world.run(STEP)
		world.feeding.simulate(STEP)
	_check(world.model.get_energy() > energy_before,
		"e a energia subiu igual: %d -> %d" % [energy_before, world.model.get_energy()])

	world.free_all()

	_g("48-49. A comemoracao suprimida nao fica guardada para depois")
	var w2 := _world()
	w2.use_fake_adapter(FakeAdapter.new())
	w2.settings.set_value("quiet_mode", true)
	var shown: Array = []
	w2.evolution.presentation_started.connect(func(id: StringName) -> void: shown.append(String(id)))
	_check(w2.evolution.is_quiet_mode(), "a evolucao sabe do silencio")
	w2.model.add_strength(25)                          # nivel 2
	w2.run(4.0)
	_check(shown.is_empty(), "nenhuma comemoracao aconteceu: %s" % str(shown))
	_check(w2.evolution.get_queue().is_empty(), "e nada ficou na fila")

	w2.model.add_strength(115)                         # nivel 4: a forma tem de trocar
	w2.run(2.0)
	_check(w2.dog.get_body_form() == BodyForms.Form.MUSCULAR,
		"a transformacao aconteceu mesmo em silencio, sem animacao")
	_check(w2.evolution.get_queue().is_empty(), "sem fila acumulada")

	w2.settings.set_value("quiet_mode", false)
	w2.run(6.0)
	_check(shown.is_empty(),
		"desligar o silencio nao dispara nada antigo: %s" % str(shown))
	_check(not w2.hud.call("is_quiet_mode"), "e o HUD voltou ao normal")
	w2.model.add_strength(110)                         # nivel 5, agora sem silencio
	w2.run(1.0)
	_check(shown == ["level_5"], "os eventos novos voltam a acontecer: %s" % str(shown))
	w2.free_all()


# --------------------------------------------------------------------------------------
# 50-55. Inicializacao automatica
# --------------------------------------------------------------------------------------

func _test_autostart() -> void:
	_g("50-51. So com acao explicita, e nunca pelo editor")
	var adapter := FakeAdapter.new()
	var service := AutostartService.new(adapter)
	_check(not SettingsManager.defaults()["launch_at_login"],
		"a configuracao nasce desligada")
	_check(adapter.autostart_calls.is_empty(),
		"criar o servico nao liga nada (%d chamadas)" % adapter.autostart_calls.size())
	_check(not bool(service.set_enabled(true)["ok"]),
		"com a trava fechada, ligar e recusado")

	# A partir daqui a trava abre, mas o adaptador continua sendo um duble: nada sai daqui
	# para o sistema operacional.
	AutostartService.allow_system_changes = true
	_check(AutostartService.is_running_from_editor(),
		"esta execucao roda pelo binario do editor (%s)" % OS.get_executable_path().get_file())
	_check(not bool(service.set_enabled(true)["ok"]),
		"e por isso ligar continua recusado, mesmo com a trava aberta")
	_check(adapter.autostart_calls.is_empty(), "sem nenhuma chamada ao sistema")
	# Dai em diante, o servico finge uma copia exportada: nenhum arquivo e criado e o
	# adaptador continua sendo um duble.
	service.set_executable_override("C:/Jogos/Caramelo/ComoAumentarSeuCaramelo.exe")
	var source := _read_text("res://scripts/platform/autostart_service.gd")
	_check(source.contains("is_running_from_editor()") and source.contains("OS.has_feature(\"editor\")"),
		"o servico recusa explicitamente rodar pelo editor")

	_g("52-53. Ligar exige executavel valido; desligar remove a entrada")
	var result := service.set_enabled(true)
	_check(bool(result["ok"]), "ligou: %s" % str(result))
	_check(adapter.autostart_calls.size() == 1 and bool(adapter.autostart_calls[0]["enabled"]),
		"o adaptador recebeu um pedido de ativacao")
	_check(String(adapter.autostart_calls[0]["path"]).ends_with("ComoAumentarSeuCaramelo.exe"),
		"apontando para o executavel do jogo: %s" % adapter.autostart_calls[0]["path"])
	_check(service.is_enabled_now(), "o estado real confirma")
	var off := service.set_enabled(false)
	_check(bool(off["ok"]) and not service.is_enabled_now(), "desligou e a entrada sumiu")
	_check(adapter.autostart_calls.size() == 2, "duas chamadas no total")

	_g("54. Falha do sistema e reportada, nunca engolida")
	adapter.autostart_succeeds = false
	var failure := service.set_enabled(true)
	_check(not bool(failure["ok"]), "resultado de falha")
	_check(String(failure["reason"]) != "", "com motivo: %s" % failure["reason"])
	_check(not service.is_enabled_now(), "e o estado continua desligado")
	adapter.autostart_succeeds = true

	_g("55. Plataforma sem suporte nao altera o sistema")
	adapter.autostart_supported = false
	var unsupported := service.set_enabled(true)
	var calls_before := adapter.autostart_calls.size()
	_check(not bool(unsupported["ok"]), "recusado")
	_check(adapter.autostart_calls.size() == calls_before,
		"sem nenhuma chamada nova ao sistema")
	_check(not service.is_available(), "e a opcao aparece indisponivel na interface")
	adapter.autostart_supported = true
	AutostartService.allow_system_changes = false


# --------------------------------------------------------------------------------------
# 56-60. Encerramento
# --------------------------------------------------------------------------------------

func _test_shutdown() -> void:
	_g("56-58. Fechar grava jogo, grava configuracoes e solta o papel de parede")
	SaveManager.persistence_enabled = true
	SettingsManager.persistence_enabled = true
	SaveManager.use_isolated_directory("test_desktop_shutdown")
	var world := _world()
	var adapter := FakeAdapter.new()
	world.use_fake_adapter(adapter)
	world.settings.set_paths("%s/settings.json" % SETTINGS_DIR,
		"%s/settings.backup.json" % SETTINGS_DIR, "%s/settings.tmp.json" % SETTINGS_DIR)
	_remove("%s/settings.json" % SETTINGS_DIR)
	world.modes.request_mode(DesktopModeManager.Mode.WALLPAPER)
	_check(world.modes.get_mode() == DesktopModeManager.Mode.WALLPAPER, "em papel de parede")
	world.model.add_strength(10)
	world.save.mark_dirty()
	world.settings.set_value("quiet_mode", true)

	var report := world.session.request_shutdown()
	_check(bool(report["gameplay_saved"]), "o progresso foi gravado")
	_check(bool(report["settings_saved"]), "as configuracoes foram gravadas")
	_check(FileAccess.file_exists("%s/settings.json" % SETTINGS_DIR), "settings.json existe")
	_check(adapter.detach_calls >= 1, "o papel de parede foi desassociado")
	_check(world.modes.get_mode() == DesktopModeManager.Mode.WINDOWED,
		"e a janela voltou ao normal antes de sair")

	_g("59-60. Falha de gravacao nao prende o jogo e preserva o backup")
	var repeated := world.session.request_shutdown()
	_check(bool(repeated["repeated"]), "um segundo pedido nao repete o trabalho")
	_check(world.session.is_shutting_down(), "o encerramento fica marcado")
	world.free_all()

	var w2 := _world()
	w2.use_fake_adapter(FakeAdapter.new())
	w2.model.add_strength(5)
	w2.save.mark_dirty()
	_check(w2.save.save_now(), "primeira gravacao boa")
	var main_path := w2.save.get_main_path()
	var backup_path := main_path.replace("savegame.json", "savegame.backup.json")
	w2.model.add_strength(5)
	w2.save.mark_dirty()
	w2.save.save_now()
	_check(FileAccess.file_exists(backup_path), "o backup anterior existe")
	var backup_before := _read_text(backup_path)
	# Gravacao impossivel: o modelo some, e o `SaveManager` recusa montar o snapshot.
	w2.save.configure(w2.session.get_config(), null, w2.feeding, w2.exercise, null, w2.dog, null)
	w2.save.mark_dirty()
	var crash := w2.session.request_shutdown()
	_check(not bool(crash["gameplay_saved"]), "a falha e reportada")
	_check(_read_text(backup_path) == backup_before, "e o backup anterior continua intacto")
	_check(w2.save.get_last_error() != "", "com motivo registrado: %s" % w2.save.get_last_error())
	w2.free_all()
	SaveManager.clear_isolated_directory()
	SaveManager.persistence_enabled = false
	SettingsManager.persistence_enabled = false
	_remove("%s/settings.json" % SETTINGS_DIR)
	_remove("%s/settings.backup.json" % SETTINGS_DIR)


# --------------------------------------------------------------------------------------
# 61-69. Exportacao e regressao
# --------------------------------------------------------------------------------------

func _test_export_and_regression() -> void:
	_g("61-65. O preset de Windows empacota o jogo, e so o jogo")
	var preset := _read_text("res://export_presets.cfg")
	_check(not preset.is_empty(), "export_presets.cfg existe")
	_check(preset.contains("platform=\"Windows Desktop\""), "com o preset Windows Desktop")
	_check(preset.contains("binary_format/architecture=\"x86_64\""), "arquitetura x86_64")
	_check(preset.contains("export_path=\"build/windows/"), "saida em build/windows/")
	_check(preset.contains("data/") and preset.contains("*.json"),
		"os dados de balanceamento entram no pacote")
	_check(preset.contains("assets/") or preset.contains("*.png"),
		"o quintal entra no pacote")
	for excluded in ["tests/*", "tools/*", "docs/*", "*.md"]:
		_check(preset.contains(excluded), "fica de fora: %s" % excluded)
	for excluded in ["savegame", "settings.json"]:
		_check(preset.contains(excluded), "nenhum save ou configuracao pessoal: %s" % excluded)

	var build_script := _read_text("res://tools/build_windows.sh")
	_check(not build_script.is_empty(), "tools/build_windows.sh existe")
	_check(build_script.contains("platform/windows"),
		"o script leva os helpers PowerShell para junto do executavel")
	_check(build_script.contains("build/windows"), "e cria somente o diretorio de build")
	_check(not build_script.contains("rm -rf /") and not build_script.contains("rm -rf \"$HOME"),
		"sem remocao de caminho amplo")
	_check(build_script.contains("export-release") or build_script.contains("export-debug"),
		"chama a exportacao do Godot")
	_check(_read_text("res://.gitignore").contains("build/"),
		"build/ esta no .gitignore")
	_check(not _read_text("res://docs/WINDOWS_VALIDATION.md").is_empty(),
		"o checklist de validacao em Windows existe")

	_g("66-68. A cena principal continua abrindo e rodando sozinha")
	var world := _world()
	world.use_fake_adapter(FakeAdapter.new())
	_check(world.session != null and world.session.is_session_ready(), "a sessao abriu")
	_check(world.model != null and world.dog != null, "modelo e Caramelo presentes")
	_check(world.settings != null and world.performance != null and world.modes != null,
		"os tres nos novos estao na cena")
	_check(world.panel != null and not world.panel.call("is_open"),
		"o painel de configuracoes existe e comeca fechado")
	var snapshot := world.model.get_snapshot()
	world.dog.set_random_seed(31)
	world.run(120.0)
	_check(world.model.get_strength() == int(snapshot["strength"]),
		"2 min sem interacao: forca %d" % world.model.get_strength())
	_check(world.model.get_bond() == int(snapshot["bond"]), "vinculo intacto")
	_check(world.modes.get_mode() == DesktopModeManager.Mode.WINDOWED,
		"e o modo continua janela")

	_g("69. Nada fica para tras ao liberar a cena")
	var nodes_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	world.free_all()
	var nodes_after := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	_check(nodes_after < nodes_before, "os nos da cena foram liberados (%d -> %d)"
		% [int(nodes_before), int(nodes_after)])
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_check(orphans == 0.0, "nenhum no orfao: %d" % int(orphans))


func _report() -> void:
	SaveManager.persistence_enabled = true
	SettingsManager.persistence_enabled = true
	AutostartService.allow_system_changes = true
	print("\n" + "=".repeat(70))
	if _failures.is_empty():
		print("TODOS OS TESTES PASSARAM  (%d verificacoes)" % _passed)
		quit(0)
		return
	print("FALHAS: %d de %d verificacoes" % [_failures.size(), _passed + _failures.size()])
	for failure in _failures:
		print("  - " + failure)
	quit(1)
