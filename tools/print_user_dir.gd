extends SceneTree
## Imprime o diretorio `user://` efetivo e encerra. Usado pelo runner isolado para
## confirmar, **antes** de qualquer teste, que a execucao nao vai escrever no save pessoal.
##
##   godot --headless --path . --script tools/print_user_dir.gd

func _process(_delta: float) -> bool:
	print(OS.get_user_data_dir())
	quit(0)
	return true
