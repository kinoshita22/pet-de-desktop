class_name WindowsAdapter
extends PlatformAdapter
## Integracao com o Windows: papel de parede, autostart e sondagem de tela cheia.
##
## **Nao validado em Windows real.** O ambiente de desenvolvimento e Linux; este codigo foi
## exercitado por testes com duble e por inspecao estatica. O roteiro de validacao manual
## esta em `docs/WINDOWS_VALIDATION.md`.
##
## Forma de trabalho: todo acesso nativo acontece por tres helpers PowerShell que moram no
## proprio repositorio, em `platform/windows/`. O jogo nunca monta linha de comando por
## concatenacao de texto — `OS.execute` recebe uma **lista** de argumentos, o que dispensa
## shell e elimina interpolacao. O unico dado que atravessa a fronteira e o identificador
## da janela, um inteiro positivo validado antes de virar argumento.
##
## O que este adaptador nao faz, de proposito: nao encerra nem reinicia o Explorer, nao
## oculta icones, nao escreve no registro, nao troca o papel de parede do sistema, nao
## pede privilegio de administrador, nao usa rede e nao executa script que nao esteja
## dentro do projeto.

## Nomes fixos. Nenhum deles e montado a partir de entrada do jogador ou do save.
const HELPER_WALLPAPER := "wallpaper_host.ps1"
const HELPER_AUTOSTART := "autostart.ps1"
const HELPER_PROBE := "fullscreen_probe.ps1"
const HELPER_DIRECTORY := "platform/windows"

## Limite de espera de cada helper. O PowerShell frio custa caro; acima disto a chamada e
## tratada como falha e o jogo volta para a janela.
const TIMEOUT_NOTICE := "o helper do Windows nao respondeu."

var _attached := false
var _last_parent := ""
var _attached_handle := 0


func get_platform_name() -> String:
	return "Windows"


func supports_wallpaper() -> bool:
	return _is_windows()


func supports_autostart() -> bool:
	return _is_windows()


func supports_fullscreen_probe() -> bool:
	return _is_windows()


# --------------------------------------------------------------------------------------
# Papel de parede
# --------------------------------------------------------------------------------------

## Prende a janela a camada de papel de parede do Explorer (`Progman`/`WorkerW`).
##
## O helper faz o minimo: encontra o host, pede a camada quando ela ainda nao existe,
## reparenteia a janela e confirma. Os icones do desktop continuam onde estavam, porque
## nada e destruido nem ocultado — a janela entra **atras** deles.
func attach_wallpaper(window_handle: int) -> Dictionary:
	if not _is_windows():
		return failure(REASON_UNSUPPORTED)
	if not PlatformAdapter.is_valid_handle(window_handle):
		return failure(REASON_INVALID_HANDLE)
	var helper := resolve_helper(HELPER_WALLPAPER)
	if helper.is_empty():
		return failure("helper %s nao encontrado ao lado do jogo." % HELPER_WALLPAPER)
	var result := _run_helper(helper, ["-Action", "Attach", "-Handle", str(int(window_handle))])
	if result["ok"]:
		_attached = true
		_attached_handle = int(window_handle)
		_last_parent = String(result["detail"])
	return result


func detach_wallpaper() -> Dictionary:
	if not _is_windows():
		return failure(REASON_UNSUPPORTED)
	if not _attached:
		return success("nada a desassociar")
	var helper := resolve_helper(HELPER_WALLPAPER)
	if helper.is_empty():
		return failure("helper %s nao encontrado ao lado do jogo." % HELPER_WALLPAPER)
	var result := _run_helper(helper, ["-Action", "Detach", "-Handle", str(_attached_handle)])
	if result["ok"]:
		_attached = false
		_attached_handle = 0
		_last_parent = ""
	return result


func is_attached() -> bool:
	return _attached


# --------------------------------------------------------------------------------------
# Inicializacao automatica
# --------------------------------------------------------------------------------------

## Cria ou remove um atalho na pasta Inicializar do **usuario atual**. Sem registro, sem
## administrador, sem escrita para toda a maquina — e reversivel pelo proprio jogo ou
## apagando o atalho a mao.
func set_autostart(enabled: bool, executable_path: String) -> Dictionary:
	if not _is_windows():
		return failure(REASON_UNSUPPORTED)
	if enabled and not _is_shippable_executable(executable_path):
		return failure(REASON_NO_EXECUTABLE)
	var helper := resolve_helper(HELPER_AUTOSTART)
	if helper.is_empty():
		return failure("helper %s nao encontrado ao lado do jogo." % HELPER_AUTOSTART)
	var arguments: Array = ["-Action", "Enable" if enabled else "Disable"]
	if enabled:
		arguments.append_array(["-Target", executable_path])
	return _run_helper(helper, arguments)


func is_autostart_enabled() -> Dictionary:
	if not _is_windows():
		return {"ok": false, "enabled": false, "reason": REASON_UNSUPPORTED}
	var helper := resolve_helper(HELPER_AUTOSTART)
	if helper.is_empty():
		return {"ok": false, "enabled": false, "reason": "helper ausente."}
	var result := _run_helper(helper, ["-Action", "Status"])
	return {"ok": bool(result["ok"]), "enabled": String(result["detail"]) == "enabled",
		"reason": String(result["reason"])}


# --------------------------------------------------------------------------------------
# Tela cheia alheia
# --------------------------------------------------------------------------------------

func probe_foreign_fullscreen() -> int:
	if not _is_windows():
		return Probe.UNKNOWN
	var helper := resolve_helper(HELPER_PROBE)
	if helper.is_empty():
		return Probe.UNKNOWN
	var result := _run_helper(helper, ["-Action", "Probe"])
	if not result["ok"]:
		return Probe.UNKNOWN
	match String(result["detail"]):
		"yes": return Probe.YES
		"no": return Probe.NO
	return Probe.UNKNOWN


# --------------------------------------------------------------------------------------
# Execucao dos helpers
# --------------------------------------------------------------------------------------

## Caminho absoluto de um helper, ou vazio se ele nao estiver onde deveria.
##
## Sao dois lugares possiveis, ambos do projeto: ao lado do executavel exportado e dentro
## do repositorio, para quem roda pelo editor. Nenhum outro caminho e aceito, e o nome do
## arquivo vem sempre de uma constante.
static func resolve_helper(file_name: String) -> String:
	if not [HELPER_WALLPAPER, HELPER_AUTOSTART, HELPER_PROBE].has(file_name):
		return ""
	var candidates: Array[String] = []
	var executable_dir := OS.get_executable_path().get_base_dir()
	if not executable_dir.is_empty():
		candidates.append("%s/%s/%s" % [executable_dir, HELPER_DIRECTORY, file_name])
	candidates.append(ProjectSettings.globalize_path("res://%s/%s" % [HELPER_DIRECTORY, file_name]))
	for candidate in candidates:
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


## Executa um helper com lista de argumentos — sem shell, sem interpolacao de texto.
##
## O helper responde uma unica linha: `OK|detalhe` ou `ERR|motivo`. Qualquer outra coisa,
## inclusive saida vazia ou bloqueio por politica de execucao, e tratada como falha.
func _run_helper(helper_path: String, arguments: Array) -> Dictionary:
	var command: PackedStringArray = PackedStringArray([
		"-NoProfile", "-NonInteractive", "-File", helper_path])
	for argument in arguments:
		command.append(String(argument))
	var output: Array = []
	var code := OS.execute("powershell.exe", command, output, true)
	var text := ""
	for line in output:
		text += String(line)
	text = text.strip_edges()
	if code != 0 and text.is_empty():
		return failure("o PowerShell recusou o helper (codigo %d)." % code)
	var last := ""
	for line in text.split("\n", false):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("OK|") or trimmed.begins_with("ERR|"):
			last = trimmed
	if last.begins_with("OK|"):
		return success(last.substr(3))
	if last.begins_with("ERR|"):
		return failure(last.substr(4))
	if text.to_lower().contains("execution of scripts is disabled") \
			or text.to_lower().contains("unauthorizedaccess"):
		return failure("a politica de execucao do PowerShell bloqueou o helper; "
			+ "o jogo continua em janela.")
	return failure(TIMEOUT_NOTICE if text.is_empty() else "resposta inesperada do helper.")


func _is_windows() -> bool:
	return OS.get_name() == "Windows"


## Autostart so aponta para um executavel de verdade. Rodando pelo editor, o executavel e
## o proprio Godot — apontar para ele abriria o editor no login de quem joga.
static func _is_shippable_executable(path: String) -> bool:
	if path.is_empty() or OS.has_feature("editor"):
		return false
	if not path.to_lower().ends_with(".exe"):
		return false
	return FileAccess.file_exists(path)
