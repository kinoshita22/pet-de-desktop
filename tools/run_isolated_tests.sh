#!/usr/bin/env bash
#
# Executa as nove suites com um diretorio de dados descartavel.
#
# Motivo: `user://` aponta, em Linux, para "$XDG_DATA_HOME/godot/app_userdata/<projeto>".
# Rodando o jogo ou os testes sem isolar, a execucao escreve no save pessoal de quem
# desenvolve. Aqui `XDG_DATA_HOME` vira um diretorio temporario proprio, conferido antes
# do primeiro teste: se o isolamento nao puder ser confirmado, nada roda.
#
# Uso:
#   tools/run_isolated_tests.sh              # importa e roda tudo
#   GODOT_BIN=/caminho/godot tools/run_isolated_tests.sh
#
# O script nunca apaga nada fora do diretorio que ele mesmo criou.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# ---------------------------------------------------------------- executavel do Godot
GODOT_BIN="${GODOT_BIN:-}"
if [ -z "$GODOT_BIN" ]; then
	for candidate in godot godot4 "$HOME/.local/bin/godot"; do
		if command -v "$candidate" >/dev/null 2>&1; then
			GODOT_BIN="$(command -v "$candidate")"
			break
		fi
	done
fi
if [ -z "$GODOT_BIN" ] || ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "ERRO: Godot nao encontrado. Defina GODOT_BIN=/caminho/para/godot." >&2
	exit 2
fi

# ---------------------------------------------------------------- diretorio descartavel
TEST_DATA_HOME="$(mktemp -d "${TMPDIR:-/tmp}/caramelo-testes-XXXXXXXX")"

# A limpeza so aceita o diretorio criado aqui: nao aceita raiz, nao aceita $HOME, nao
# aceita caminho curto e nao aceita nada que nao tenha o prefixo do mktemp.
cleanup() {
	local target="${TEST_DATA_HOME:-}"
	if [ -z "$target" ] || [ ! -d "$target" ]; then
		return
	fi
	case "$target" in
		*/caramelo-testes-*) ;;
		*) echo "AVISO: diretorio temporario inesperado, nao removido: $target" >&2; return ;;
	esac
	if [ "$target" = "/" ] || [ "$target" = "$HOME" ] || [ "${#target}" -lt 12 ]; then
		echo "AVISO: recusando remover caminho amplo: $target" >&2
		return
	fi
	rm -rf -- "$target"
}
trap cleanup EXIT

if [ ! -d "$TEST_DATA_HOME" ]; then
	echo "ERRO: nao foi possivel criar o diretorio temporario." >&2
	exit 2
fi
if [ "$TEST_DATA_HOME" = "$HOME" ] || [ "$TEST_DATA_HOME" = "/" ]; then
	echo "ERRO: diretorio temporario invalido." >&2
	exit 2
fi

export XDG_DATA_HOME="$TEST_DATA_HOME"
export CARAMELO_ISOLATED_DATA_HOME="$TEST_DATA_HOME"

# ---------------------------------------------------------------- confirmacao do isolamento
PERSONAL_DATA_HOME="${HOME}/.local/share"
EFFECTIVE_USER_DIR="$("$GODOT_BIN" --headless --path . --script tools/print_user_dir.gd 2>/dev/null \
	| grep -E '^/' | tail -1 || true)"

if [ -z "$EFFECTIVE_USER_DIR" ]; then
	echo "ERRO: nao foi possivel descobrir o diretorio user:// efetivo." >&2
	exit 3
fi
case "$EFFECTIVE_USER_DIR" in
	"$TEST_DATA_HOME"/*) ;;
	*)
		echo "ERRO: isolamento NAO confirmado." >&2
		echo "  user:// efetivo: $EFFECTIVE_USER_DIR" >&2
		echo "  esperado dentro de: $TEST_DATA_HOME" >&2
		exit 3
		;;
esac
case "$EFFECTIVE_USER_DIR" in
	"$PERSONAL_DATA_HOME"/*)
		echo "ERRO: o teste apontaria para o diretorio pessoal. Abortado." >&2
		exit 3
		;;
esac

echo "Isolamento confirmado"
echo "  godot:    $GODOT_BIN"
echo "  user://:  $EFFECTIVE_USER_DIR"
echo

# ---------------------------------------------------------------- execucao
SUITES=(
	tests/test_caramelo_controller.gd
	tests/test_progression.gd
	tests/test_feeding_system.gd
	tests/test_exercise_system.gd
	tests/test_rest_and_idle.gd
	tests/test_main_ui.gd
	tests/test_save_and_offline.gd
	tests/test_evolution_and_affection.gd
	tests/test_desktop_modes.gd
)

FAILED=()

echo "== importando recursos"
if ! "$GODOT_BIN" --headless --path . --import >/dev/null 2>&1; then
	echo "ERRO: importacao falhou." >&2
	exit 1
fi

for suite in "${SUITES[@]}"; do
	name="$(basename "$suite" .gd)"
	output="$("$GODOT_BIN" --headless --path . --script "$suite" 2>&1)" && status=0 || status=$?
	summary="$(printf '%s\n' "$output" | grep -E 'PASSARAM|FALHAS' | tail -1)"
	printf '%-32s %s\n' "$name" "${summary:-sem resumo}"
	if [ "$status" -ne 0 ]; then
		FAILED+=("$name")
		printf '%s\n' "$output" | grep -E '^\s+\[FALHA\]|SCRIPT ERROR' | head -20
	fi
done

echo
echo "== execucao sem interacao (120 quadros)"
if ! "$GODOT_BIN" --headless --path . --quit-after 120 >/dev/null 2>&1; then
	echo "ERRO: a execucao headless falhou." >&2
	FAILED+=("execucao headless")
fi

echo
if [ "${#FAILED[@]}" -gt 0 ]; then
	echo "FALHOU: ${FAILED[*]}"
	exit 1
fi
echo "TUDO PASSOU — nenhum arquivo do save pessoal foi tocado."
