# Como Aumentar Seu Caramelo

Jogo 2D idle para desktop que também funciona como papel de parede animado. O jogador cuida de um vira-lata caramelo brasileiro: ele come para recuperar energia, treina para ganhar força, descansa e evolui gradualmente até uma forma mais musculosa e carismática.

**A fonte oficial de requisitos é [`MVP_SPEC.md`](MVP_SPEC.md).** Em caso de divergência, ela prevalece sobre [`DESIGN.md`](DESIGN.md) (visão de longo prazo) e [`PLANO_MVP.md`](PLANO_MVP.md) (roteiro de 12 etapas).

## Estado atual

**Etapa 3 de 12 — Cenário principal.** O quintal definitivo já é o fundo do jogo, com área caminhável, pontos de interação e camadas preparadas para as próximas etapas. **Ainda não há cachorro nem jogabilidade.**

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

## O cenário do quintal

### Arquivos

| Item | Caminho |
| ---- | ------- |
| Cena do ambiente | [`scenes/environment/backyard.tscn`](scenes/environment/backyard.tscn) |
| Script de enquadramento | [`scripts/environment/backyard.gd`](scripts/environment/backyard.gd) |
| Imagem de fundo | [`assets/backgrounds/quintal_mvp.png`](assets/backgrounds/quintal_mvp.png) |
| Cena principal | [`scenes/main/main.tscn`](scenes/main/main.tscn) |

O asset é a **única** imagem do projeto e foi usado sem alteração: 1672 × 941 px, RGB de 8 bits, não entrelaçado, proporção 1,7768 (16:9 com desvio de 0,053%). Nenhuma versão derivada, redimensionada ou recortada foi gerada.

### Sistema de coordenadas

Toda a cena é autorada no **sistema de coordenadas-base 1920 × 1080**, o mesmo definido na Etapa 2. A arte, que é menor, entra como um `Sprite2D` centralizado em `(960, 540)` com escala uniforme de **1,1483254** (`1920 / 1672`), o que a faz medir exatamente 1920 × 1080,57 — uma sangria vertical de 0,57 px, dividida entre topo e base.

As medidas tiradas diretamente da arte convertem-se para a base multiplicando por esse mesmo fator.

### Política de escala e recorte

O projeto usa `stretch/mode = "canvas_items"` com `stretch/aspect = "expand"`. Isso significa que o **viewport cresce** no eixo com folga, em vez de gerar barras pretas:

| Janela | Viewport resultante | Escala aplicada | Recorte da arte |
| ------ | ------------------- | --------------: | --------------- |
| 1920 × 1080 | 1920 × 1080 | 1,1483 | nenhum |
| 1280 × 720 | 1920 × 1080 | 1,1483 | nenhum |
| 1024 × 768 | 1920 × 1440 | 1,5311 | 320 px de cada lado |
| 3440 × 1440 | 2580 × 1080 | 1,5431 | 186 px em cima e embaixo |
| 640 × 1000 | 1920 × 3000 | 3,1898 | 1707 px de cada lado |

A regra aplicada é a mesma de `background-size: cover`: **escala uniforme igual ao maior fator necessário, com o excedente recortado simetricamente**. A imagem nunca é esticada de forma desigual e nunca deixa faixas vazias. Em proporções distantes de 16:9 o recorte é grande, mas é previsível e centrado, preservando a área útil do piso — o que o `MVP_SPEC.md` prefere a qualquer deformação.

Isso não pode ser feito só com propriedades de cena, porque depende do tamanho do viewport em tempo de execução. Por isso `Backyard` tem um script, e ele faz **apenas** isso — não há lógica de jogo nele.

O script escala o **nó inteiro**, e não somente o fundo. É o que mantém a área caminhável e os pontos de interação colados ao piso desenhado em qualquer resolução: se apenas o fundo fosse reescalado, o polígono deixaria de coincidir com o piso assim que a proporção da janela mudasse.

### Área caminhável

`WorldBounds` é um `Area2D` com um `CollisionPolygon2D` chamado `WalkableCollision`, de **19 vértices** e cerca de 400 000 px² na base 1920 × 1080. O polígono foi traçado sobre a arte real e acompanha o piso de concreto, deixando de fora telhado, céu, paredes, o degrau de azulejos à esquerda e a vegetação desfocada do primeiro plano.

A borda frontal para antes das plantas de primeiro plano de propósito: elas estão pintadas na imagem de fundo e, portanto, ficariam **atrás** de Caramelo. Mantendo o cachorro acima dessa linha, o problema não aparece.

O polígono é simples (verificado: nenhuma autointerseção) e continua editável no Godot, vértice a vértice.

**Colisão — configuração explícita:**

| Propriedade | Valor | Motivo |
| ----------- | ----- | ------ |
| `collision_layer` | 1 | Camada 1 fica reservada para os limites do cenário |
| `collision_mask` | 0 | O quintal não detecta nada; quem consulta é o personagem |
| `monitoring` | `false` | Não existe corpo algum ainda — evita processamento inútil |
| `monitorable` | `false` | Idem |

Na Etapa 4, quando Caramelo existir, basta ligar `monitorable` ou consultar o polígono geometricamente com `Geometry2D.is_point_in_polygon`. Nenhuma navegação automática foi implementada e nenhum `NavigationRegion2D` foi criado — não são necessários para caminhar até pontos fixos.

A visualização da colisão só aparece com `--debug-collisions` ou com *Visible Collision Shapes* ligado no editor; na execução normal ela não é desenhada.

### Pontos de interação

Três `Marker2D` sob `InteractionPoints`. Eles apenas marcam posições: não executam ação nenhuma, não têm script e não desenham ícone durante o jogo (o gizmo do `Marker2D` é exclusivo do editor).

| Marcador | Posição (base 1920 × 1080) | Origem na arte | Por que ali |
| -------- | -------------------------- | -------------- | ----------- |
| `FoodPoint` | `(941.6, 792.1)` | `(820, 690)` | Piso aberto no centro, à frente do banco de concreto encostado no muro. O pote é um dos **únicos** elementos clicáveis do cenário (`MVP_SPEC.md` §6), então precisa de espaço livre em volta, longe dos equipamentos e da vegetação |
| `TrainingPoint` | `(689.0, 746.1)` | `(600, 650)` | Junto à academia improvisada da esquerda — banco, barra e halteres. Fica no piso livre entre os pés do banco e os halteres, de onde Caramelo alcança o equipamento |
| `RestPoint` | `(1217.2, 734.6)` | `(1060, 640)` | À frente da cadeira plástica branca, exatamente o local que o `MVP_SPEC.md` §10 descreve para o estado `RESTING` ("deitado no chão ou perto da cadeira de plástico") |

Os três estão dentro da área caminhável, têm posições distintas (a menor distância entre eles é 257 px) e permanecem visíveis na tela nas cinco resoluções validadas.

### Camadas

Ordem de desenho explícita por `z_index`, para não depender só da ordem na árvore:

| Nó | `z_index` | Responsabilidade |
| -- | --------: | ---------------- |
| `Background` | −100 | A imagem do quintal, sempre atrás de tudo |
| `CharacterLayer` | 0 | Receberá Caramelo na Etapa 4 |
| `PropsLayer` | 10 | Receberá objetos interativos posteriores, como o pote |
| `ForegroundLayer` | 20 | Elementos que podem passar visualmente à frente de Caramelo |

As três camadas estão vazias nesta etapa, como previsto.

O `Background` é um `Sprite2D`, e não um `TextureRect`: um `Sprite2D` não participa da captura de eventos de mouse, então o fundo nunca intercepta cliques destinados às futuras entidades.

## Estrutura da cena

```text
Main                    (Node)
├── World               (Node2D)
│   └── Backyard        (instância de backyard.tscn)
│       ├── Background        (Sprite2D)     z = -100
│       ├── WorldBounds       (Area2D)
│       │   └── WalkableCollision  (CollisionPolygon2D)
│       ├── InteractionPoints (Node2D)
│       │   ├── FoodPoint     (Marker2D)
│       │   ├── TrainingPoint (Marker2D)
│       │   └── RestPoint     (Marker2D)
│       ├── CharacterLayer    (Node2D)       z = 0
│       ├── PropsLayer        (Node2D)       z = 10
│       └── ForegroundLayer   (Node2D)       z = 20
└── Interface           (CanvasLayer, camada 1, vazia)
```

O `ColorRect` provisório da Etapa 2 foi removido da cena principal depois que o fundo definitivo foi validado. O papel conceitual de `Background` passou para dentro de `backyard.tscn`, junto com o resto do cenário — manter um segundo fundo em `main.tscn` duplicaria a responsabilidade sem nenhum ganho.

`Interface` continua vazia e em `CanvasLayer` de camada 1. Como o cenário vive na camada 0, a interface fica garantidamente acima dele.

### Por que a raiz `Main` é um `Node`

Decisão da Etapa 2, mantida: um `Control` filho de `Node2D` ancora contra o retângulo do pai, que num `Node2D` é sempre zero — um fundo em `Control` ficaria com tamanho 0 × 0 e a tela apareceria com a cor padrão do Godot. Com a raiz sendo um `Node`, qualquer `Control` ancora contra o viewport e acompanha o redimensionamento. O mundo do jogo fica sob `World`, que é `Node2D`.

O fundo atual é um `Sprite2D` e não depende mais desse detalhe, mas a regra continua valendo para a HUD da Etapa 9, que será feita de `Control`.

## Como abrir o projeto

1. Instale o Godot 4.4 ou superior (build padrão; **não** é necessária a versão .NET/C#).
2. Abra o Godot, escolha **Importar** e selecione o arquivo `project.godot` na raiz deste repositório.
3. Abra o projeto.

## Como executar

No editor, pressione **F5** (Executar Projeto). A cena principal já está configurada como `res://scenes/main/main.tscn`. Para inspecionar só o cenário, abra `scenes/environment/backyard.tscn` e pressione **F6**.

Pelo terminal:

```bash
# executar normalmente
godot --path .

# validação visual manual do cenário, em janela pequena e posicionada
godot --path . --resolution 1280x720 --position 60,60

# conferir o comportamento em proporções extremas
godot --path . --resolution 1024x768 --position 60,60
godot --path . --resolution 640x1000 --position 60,60

# ver a área caminhável desenhada por cima do cenário
godot --path . --resolution 1280x720 --position 60,60 --debug-collisions

# apenas importar recursos e sair (valida o projeto sem abrir o editor)
godot --headless --path . --import

# executar sem janela, encerrando após 120 quadros
godot --headless --path . --quit-after 120
```

O esperado é uma janela preenchida de ponta a ponta pelo quintal ao entardecer, sem barras vazias e sem deformação. Ao arrastar a borda da janela, a imagem continua cobrindo tudo: em janelas mais largas que 16:9 ela é recortada em cima e embaixo, e em janelas mais altas, nas laterais.

## Como validar o cenário

Com `--debug-collisions`, o polígono da área caminhável aparece desenhado sobre o piso. O que conferir:

* O contorno acompanha o concreto e não invade telhado, céu, muros nem as plantas do primeiro plano.
* Ele encosta na base da parede do fundo, sem sobrar faixa de piso inalcançável.
* Redimensionando a janela, o contorno continua colado ao piso — ele escala junto com a arte.

## O que foi implementado nesta etapa

* `scenes/environment/backyard.tscn`: cena própria do ambiente, instanciável, com fundo definitivo, área caminhável, três pontos de interação e três camadas vazias.
* `scripts/environment/backyard.gd`: 32 linhas que apenas encaixam o cenário no viewport preservando a proporção.
* `scenes/main/main.tscn`: passa a instanciar o quintal dentro de `World`; `ColorRect` provisório removido.
* Importação da imagem pelo Godot, com filtragem linear no `Background` (a arte é pintada, não pixel art — a filtragem *Nearest* padrão do projeto deixaria o redimensionamento serrilhado). O padrão do projeto não foi alterado, só o nó do fundo.

Sobre os arquivos de importação: `.godot/` (o cache gerado) permanece ignorado pelo Git, enquanto `assets/backgrounds/quintal_mvp.png.import` é versionado. Esse arquivo guarda o `uid://` do recurso e os parâmetros de importação; versioná-lo é a prática recomendada no Godot 4 e evita que a referência da cena mude a cada clone.

## Limitações conhecidas

* **A arte tem dois conjuntos de treino** — banco, barra e halteres à esquerda; barras de flexão à direita — e esta etapa prevê um único `TrainingPoint`, colocado no conjunto da esquerda. Quando os exercícios forem implementados (Etapa 6), flexões e halteres provavelmente precisarão de marcadores separados.
* **Não existe pote na imagem.** `FoodPoint` marca onde o pote entrará como objeto em `PropsLayer`, numa etapa posterior.
* **`ForegroundLayer` está vazia.** A vegetação do primeiro plano faz parte da imagem de fundo, então ela é desenhada *atrás* de Caramelo. A área caminhável foi traçada acima dessa vegetação justamente para esconder o problema. Fazer Caramelo passar de fato atrás das folhas exigiria recortá-las da arte, o que não foi feito para preservar o asset original.
* **Sem mipmaps.** Em janelas bem menores que 1672 px de largura a redução usa filtragem linear simples. Gerar mipmaps é uma otimização possível para a Etapa 12.
* **Proporções extremas recortam muito.** Em 640 × 1000 sobram cerca de 35% da largura da arte. O recorte é centrado e previsível, mas boa parte do quintal fica fora da tela.
* **Consumo não foi medido.** A máquina de desenvolvimento usa renderização por software (Mesa llvmpipe), inadequada para aferir as metas de FPS e CPU da seção 20 do `MVP_SPEC.md`. Isso fica para a Etapa 12, junto com a definição do computador de referência (ponto em aberto A-1).

## Estrutura de diretórios

```text
assets/          imagens, áudio e fontes
  audio/  backgrounds/  characters/  equipment/  fonts/  food/  ui/
data/            balanceamento em arquivos de dados, fora do código
  exercises/  foods/  levels/
scenes/          cenas Godot
  dog/  environment/  main/  ui/
scripts/         GDScript
  dog/  environment/  systems/  ui/
tests/           testes
```

Diretórios ainda vazios contêm um `.gitkeep`, porque o Git não rastreia diretórios vazios.

## O que ainda não foi implementado

Nada de jogabilidade existe. Em particular, seguem pendentes:

* Caramelo, suas animações e a máquina de estados (`IDLE`, `WALKING`, `EATING`, `TRAINING`, `RESTING`, `HAPPY`).
* Objetos do cenário como entidades próprias — pote, halteres e barras ainda fazem parte da imagem de fundo.
* Atributos (`energy`, `strength`, `bond`, `level`) e progressão de níveis.
* Alimentação, exercícios e descanso.
* Interface, barras e botões.
* Salvamento local e progresso offline.
* Modo papel de parede, modo silencioso e redução de consumo.
* Áudio — habilitado tecnicamente, mas nenhum som é reproduzido.
* Arquivos JSON de balanceamento em `data/`.
* Testes permanentes.

O roteiro completo está em [`PLANO_MVP.md`](PLANO_MVP.md).
