class_name FallbackAdapter
extends PlatformAdapter
## Adaptador para todo sistema sem integracao nativa — Linux e macOS, hoje.
##
## Ele existe para que a ausencia de suporte seja um **caminho testado**, e nao um `if`
## espalhado pelo codigo: recusa com motivo, nao executa processo nenhum e nunca deixa o
## jogo num estado do qual nao se possa sair. O modo papel de parede simplesmente nao
## esta disponivel aqui, e a interface mostra isso antes de o jogador tentar.

func get_platform_name() -> String:
	return OS.get_name()


func supports_wallpaper() -> bool:
	return false


func supports_autostart() -> bool:
	return false


func supports_fullscreen_probe() -> bool:
	return false


func attach_wallpaper(_window_handle: int) -> Dictionary:
	return failure("o modo papel de parede so existe no Windows; a janela continua como esta.")


func detach_wallpaper() -> Dictionary:
	# Nao ha nada preso: desassociar e um sucesso trivial, nunca um erro.
	return success("nada a desassociar")


func set_autostart(_enabled: bool, _executable_path: String) -> Dictionary:
	return failure("a inicializacao automatica so existe no Windows.")


func is_autostart_enabled() -> Dictionary:
	return {"ok": true, "enabled": false, "reason": ""}


func probe_foreign_fullscreen() -> int:
	# Sem sondagem confiavel: `UNKNOWN` e a resposta honesta. Quem consome nunca confunde
	# isto com "nao ha aplicativo em tela cheia".
	return Probe.UNKNOWN
