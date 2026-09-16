# Como Aumentar Seu Caramelo

Jogo 2D idle para desktop que também funciona como papel de parede animado. O jogador cuida de um vira-lata caramelo brasileiro: ele come para recuperar energia, treina para ganhar força, descansa e evolui gradualmente até uma forma mais musculosa e carismática.

**A fonte oficial de requisitos é [`MVP_SPEC.md`](MVP_SPEC.md).** Em caso de divergência, ela prevalece sobre [`DESIGN.md`](DESIGN.md) (visão de longo prazo) e [`PLANO_MVP.md`](PLANO_MVP.md) (roteiro de 12 etapas).

## Estado atual

**Etapa 2 de 12 — Estrutura técnica.** Existe apenas a fundação do projeto: configuração, árvore de diretórios e uma cena inicial com fundo provisório de cor sólida. **Não há jogo ainda.**

## Requisitos

| Item | Valor |
| ---- | ----- |
| Engine | Godot 4.4 ou superior (desenvolvido com 4.4.1) |
| Linguagem | GDScript |
| Resolução-base | 1920 × 1080 |
| Renderizador | Compatibility (`gl_compatibility`) |
| Plataforma-alvo | Windows |
| Dependências externas | Nenhuma |

Não há plugins, addons nem bibliotecas de terceiros. Basta o Godot.

### Por que o renderizador Compatibility

O jogo roda como papel de parede, ou seja, fica ligado por horas em segundo plano enquanto a pessoa trabalha. O `MVP_SPEC.md` fixa metas agressivas de consumo: 10 FPS no modo ocioso e CPU média abaixo de 2%.

O renderizador **Compatibility** (OpenGL 3.3 / ES 3.0 / WebGL 2) atende melhor a esse cenário do que Forward+ ou Mobile:

* Menor consumo de CPU, GPU e memória em cena ociosa.
* Inicialização mais rápida, o que importa para um app que abre junto com a sessão.
* Roda em placas integradas e máquinas antigas, sem exigir Vulkan.
* O MVP é 2D sem iluminação dinâmica, sem sombras e sem pós-processamento — nenhum recurso exclusivo de Forward+ é necessário.

## Como abrir o projeto

1. Instale o Godot 4.4 ou superior (build padrão; **não** é necessária a versão .NET/C#).
2. Abra o Godot, escolha **Importar** e selecione o arquivo `project.godot` na raiz deste repositório.
3. Abra o projeto.

## Como executar

No editor, pressione **F5** (Executar Projeto). A cena principal já está configurada como `res://scenes/main/main.tscn`.

Pelo terminal:

```bash
# executar normalmente
godot --path .

# executar sem janela, encerrando após 60 quadros (verificação rápida)
godot --headless --path . --quit-after 60

# apenas importar recursos e sair (valida o projeto sem abrir o editor)
godot --headless --path . --import
```

O esperado é uma janela de 1920 × 1080 preenchida por uma cor sólida quente (caramelo, `#C8763E`). Redimensionar a janela mantém o fundo cobrindo toda a área.

## Estrutura de diretórios

```text
assets/          imagens, áudio e fontes
  audio/  backgrounds/  characters/  equipment/  fonts/  food/  ui/
data/            balanceamento em arquivos de dados, fora do código
  exercises/  foods/  levels/
scenes/          cenas Godot
  dog/  environment/  main/  ui/
scripts/         GDScript
  dog/  systems/  ui/
tests/           testes
```

Diretórios ainda vazios contêm um `.gitkeep`, porque o Git não rastreia diretórios vazios.

## O que foi implementado nesta etapa

* `project.godot` configurado: nome, cena principal, renderizador, resolução-base 1920 × 1080, modo janela, limite de 60 FPS e redimensionamento adaptável a diferentes proporções.
* Árvore de diretórios completa, versionada com `.gitkeep`.
* `scenes/main/main.tscn` com três nós: `Background` (cor sólida provisória), `World` (contêiner vazio para cenário e cachorro) e `Interface` (camada vazia para a futura UI).

O nó raiz `Main` é um `Node`, e não um `Node2D`, de propósito: um `Control` filho de `Node2D` ancora contra o retângulo do pai, que num `Node2D` é sempre zero — o `Background` ficaria com tamanho 0 × 0 e a tela apareceria com a cor padrão do Godot. Com a raiz sendo um `Node`, o `Background` ancora contra o viewport e acompanha qualquer redimensionamento. O mundo do jogo fica sob `World`, que é `Node2D`.
* `.gitignore` adequado ao Godot 4.

Nenhum script foi criado: a cena não precisa de lógica, e todas as propriedades são definidas diretamente nos nós.

## O que ainda não foi implementado

Nada de jogabilidade existe. Em particular, seguem pendentes:

* Caramelo, suas animações e a máquina de estados (`IDLE`, `WALKING`, `EATING`, `TRAINING`, `RESTING`, `HAPPY`).
* Cenário definitivo do quintal e imagem de fundo real.
* Atributos (`energy`, `strength`, `bond`, `level`) e progressão de níveis.
* Alimentação, exercícios e descanso.
* Interface, barras e botões.
* Salvamento local e progresso offline.
* Modo papel de parede, modo silencioso e redução de consumo.
* Áudio — habilitado tecnicamente, mas nenhum som é reproduzido.
* Testes.

O roteiro completo está em [`PLANO_MVP.md`](PLANO_MVP.md).
