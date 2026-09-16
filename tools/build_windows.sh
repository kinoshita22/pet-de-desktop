#!/usr/bin/env bash
#
# Exporta o jogo para Windows em `build/windows/` e leva junto os helpers PowerShell.
#
# O script nao baixa nada, nao instala nada e nao versiona o resultado: `build/` esta no
# .gitignore. Ele tambem nao encosta no save pessoal — exportar nao abre o jogo.
#
# Uso:
#   tools/build_windows.sh                    # release
#   tools/build_windows.sh --debug            # com console e simbolos
#   GODOT_BIN=/caminho/godot tools/build_windows.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PRESET="Windows Desktop"
OUTPUT_DIR="build/windows"
OUTPUT_EXE="$OUTPUT_DIR/ComoAumentarSeuCaramelo.exe"
MODE="--export-release"
if [ "${1:-}" = "--debug" ]; then
	MODE="--export-debug"
fi

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
if [ -z "$GODOT_BIN" ]; then
	echo "ERRO: Godot nao encontrado. Defina GODOT_BIN=/caminho/para/godot." >&2
	exit 2
fi

# ---------------------------------------------------------------- export templates
TEMPLATE_ROOT="${HOME}/.local/share/godot/export_templates"
GODOT_VERSION="$("$GODOT_BIN" --version 2>/dev/null | head -1 | cut -d. -f1-3)"
if [ -z "$(ls -A "$TEMPLATE_ROOT" 2>/dev/null || true)" ]; then
	cat >&2 <<MSG
ERRO: export templates do Godot nao estao instalados.

  Esperado em: $TEMPLATE_ROOT
  Versao do Godot: ${GODOT_VERSION:-desconhecida}

Instale pelo editor (Editor > Gerenciar modelos de exportacao) ou baixe o arquivo
"Export Templates" da versao correspondente em godotengine.org. Este script nao baixa
nada por conta propria.
MSG
	exit 3
fi

if [ ! -f export_presets.cfg ]; then
	echo "ERRO: export_presets.cfg nao encontrado." >&2
	exit 2
fi

# ---------------------------------------------------------------- exportacao
mkdir -p "$OUTPUT_DIR"

echo "== importando recursos"
"$GODOT_BIN" --headless --path . --import >/dev/null

echo "== exportando ($MODE)"
"$GODOT_BIN" --headless --path . "$MODE" "$PRESET" "$OUTPUT_EXE"

if [ ! -f "$OUTPUT_EXE" ]; then
	echo "ERRO: a exportacao nao produziu $OUTPUT_EXE" >&2
	exit 1
fi

# ---------------------------------------------------------------- helpers de plataforma
# O PowerShell le arquivos do disco: dentro do .pck eles nao serviriam de nada.
mkdir -p "$OUTPUT_DIR/platform/windows"
cp platform/windows/*.ps1 "$OUTPUT_DIR/platform/windows/"

echo
echo "Pacote em $OUTPUT_DIR:"
find "$OUTPUT_DIR" -type f -printf '  %-52p %10s bytes\n' | sort
echo
echo "Pronto. O pacote e portatil: copie a pasta inteira."
echo "Para desinstalar, apague a pasta e, se tiver ligado a inicializacao automatica,"
echo "remova o atalho em 'Inicializar' pelo proprio jogo antes de apagar."
