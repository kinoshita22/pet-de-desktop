class_name AutostartService
extends RefCounted
## Inicializacao automatica com o sistema — sempre por escolha explicita.
##
## O `MVP_SPEC.md` secao 19 e direto: "nunca ativada silenciosamente". Entao este servico
## comeca desligado, so age quando alguem pede, confirma o estado real no sistema em vez
## de acreditar na preferencia salva, e nunca escreve nada rodando pelo editor — apontar o
## login de quem joga para o executavel do Godot seria um erro dificil de desfazer.
##
## A entrada e um atalho na pasta Inicializar do usuario. Nao ha registro, nao ha
## privilegio de administrador e nao ha nada para a maquina inteira.

## Trava de seguranca das suites: com isto em `false`, nenhuma chamada chega ao sistema.
## Os testes exercitam a decisao, nunca o efeito.
static var allow_system_changes := true

var _adapter: PlatformAdapter
var _executable_override := ""


func _init(adapter: PlatformAdapter = null) -> void:
	_adapter = adapter if adapter != null else FallbackAdapter.new()


func get_adapter() -> PlatformAdapter:
	return _adapter


## Finge uma copia exportada. **So os testes chamam isto**: nenhum arquivo e criado, e o
## caminho serve apenas para conferir o que seria pedido ao sistema.
func set_executable_override(path: String) -> void:
	_executable_override = path


## Executavel que iria para o atalho, ou vazio quando nao ha um que sirva.
func executable_for_shortcut() -> String:
	if not _executable_override.is_empty():
		return _executable_override
	return executable_path()


## Faz sentido oferecer a opcao? So no Windows, e so numa copia exportada do jogo.
func is_available() -> bool:
	if _adapter == null or not _adapter.supports_autostart():
		return false
	return not executable_for_shortcut().is_empty()


static func is_running_from_editor() -> bool:
	return OS.has_feature("editor")


## Caminho do executavel do jogo, vazio quando ele nao serve para um atalho de login.
static func executable_path() -> String:
	if is_running_from_editor():
		return ""
	var path := OS.get_executable_path()
	return path if not path.is_empty() else ""


## Liga ou desliga. Devolve `{"ok": bool, "enabled": bool, "reason": String}`.
func set_enabled(enabled: bool) -> Dictionary:
	if not allow_system_changes:
		return _refused("alteracoes de sistema desligadas nesta execucao.")
	if _adapter == null or not _adapter.supports_autostart():
		return _refused("a inicializacao automatica so existe no Windows.")
	if enabled and executable_for_shortcut().is_empty():
		if is_running_from_editor():
			return _refused("rodando pelo editor: o atalho apontaria para o Godot, nao para o jogo.")
		return _refused("disponivel apenas na versao exportada do jogo.")
	var result := _adapter.set_autostart(enabled, executable_for_shortcut())
	if not bool(result["ok"]):
		return {"ok": false, "enabled": is_enabled_now(), "reason": String(result["reason"])}
	return {"ok": true, "enabled": enabled, "reason": ""}


## Estado real, perguntado ao sistema. A preferencia salva pode estar desatualizada se
## alguem apagar o atalho a mao — e aqui quem manda e o sistema.
func query_enabled() -> Dictionary:
	if _adapter == null or not _adapter.supports_autostart():
		return {"ok": true, "enabled": false, "reason": ""}
	return _adapter.is_autostart_enabled()


func is_enabled_now() -> bool:
	return bool(query_enabled().get("enabled", false))


func _refused(reason: String) -> Dictionary:
	return {"ok": false, "enabled": false, "reason": reason}
