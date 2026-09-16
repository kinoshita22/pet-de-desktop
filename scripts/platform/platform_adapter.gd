class_name PlatformAdapter
extends RefCounted
## Fronteira entre o jogo e o sistema operacional.
##
## Tudo o que depende de API nativa — papel de parede, inicializacao automatica, deteccao
## de aplicativo em tela cheia — passa por aqui. O resto do jogo conversa so com esta
## interface, de modo que trocar de plataforma, ou trocar por um duble de teste, nao muda
## uma linha de `DesktopModeManager` nem de `PerformanceManager`.
##
## A implementacao base **nao faz nada e nao suporta nada**. Ela e a resposta honesta para
## qualquer sistema sem integracao propria: recusa com motivo, sem executar comando algum.

## Resposta de uma sondagem que pode nao ter resposta. `UNKNOWN` e um resultado legitimo:
## perder o foco nao e a mesma coisa que ter um aplicativo em tela cheia na frente.
enum Probe { UNKNOWN, NO, YES }

## Motivos de recusa. Viram texto na interface; o codigo continua sendo a verdade.
const REASON_UNSUPPORTED := "esta plataforma nao tem integracao de papel de parede."
const REASON_INVALID_HANDLE := "identificador de janela invalido."
const REASON_NO_EXECUTABLE := "o autostart so existe na versao exportada do jogo."


func get_platform_name() -> String:
	return OS.get_name()


func supports_wallpaper() -> bool:
	return false


func supports_autostart() -> bool:
	return false


func supports_fullscreen_probe() -> bool:
	return false


## Capacidades reais desta plataforma, para a interface desabilitar o que nao existe em
## vez de oferecer e falhar.
func get_capabilities() -> Dictionary:
	return {
		"platform": get_platform_name(),
		"wallpaper": supports_wallpaper(),
		"autostart": supports_autostart(),
		"fullscreen_probe": supports_fullscreen_probe(),
	}


## Prende a janela ao fundo do desktop. Devolve `{"ok": bool, "reason": String}`.
func attach_wallpaper(_window_handle: int) -> Dictionary:
	return failure(REASON_UNSUPPORTED)


func detach_wallpaper() -> Dictionary:
	return failure(REASON_UNSUPPORTED)


func set_autostart(_enabled: bool, _executable_path: String) -> Dictionary:
	return failure(REASON_UNSUPPORTED)


## `{"ok": bool, "enabled": bool, "reason": String}` — estado real, nunca o desejado.
func is_autostart_enabled() -> Dictionary:
	return {"ok": false, "enabled": false, "reason": REASON_UNSUPPORTED}


func probe_foreign_fullscreen() -> int:
	return Probe.UNKNOWN


# --------------------------------------------------------------------------------------
# Utilidades comuns
# --------------------------------------------------------------------------------------

## Um identificador de janela so vale se for inteiro positivo.
##
## E a unica coisa que chega do motor e segue para um helper do sistema, entao e validada
## aqui, num lugar so, antes de virar argumento. Texto de interface e conteudo de save
## **nunca** chegam a esta fronteira.
static func is_valid_handle(handle: Variant) -> bool:
	if handle is float:
		if not is_finite(handle as float) or handle != floorf(handle as float):
			return false
		handle = int(handle as float)
	if not (handle is int):
		return false
	return int(handle) > 0


static func success(detail: String = "") -> Dictionary:
	return {"ok": true, "reason": "", "detail": detail}


static func failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "detail": ""}


## Adaptador adequado ao sistema em execucao. So o Windows tem integracao propria; todo o
## resto recebe o adaptador de recusa segura.
static func create_for_current_platform() -> PlatformAdapter:
	if OS.get_name() == "Windows":
		return WindowsAdapter.new()
	return FallbackAdapter.new()
