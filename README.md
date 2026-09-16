# Como Aumentar Seu Caramelo

Jogo 2D idle para desktop que também funciona como papel de parede animado. O jogador cuida de um vira-lata caramelo brasileiro: ele come para recuperar energia, treina para ganhar força, descansa e evolui gradualmente até uma forma mais musculosa e carismática.

**A fonte oficial de requisitos é [`MVP_SPEC.md`](MVP_SPEC.md).** Em caso de divergência, ela prevalece sobre [`DESIGN.md`](DESIGN.md) (visão de longo prazo) e [`PLANO_MVP.md`](PLANO_MVP.md) (roteiro de 12 etapas).

## Estado atual

**Etapa 4 de 12 — Controlador de Caramelo.** O quintal tem um cachorro: ele fica ocioso, escolhe destinos, caminha até eles e descansa, sempre dentro da área caminhável. A máquina de estados completa já existe. **Ainda não há jogabilidade:** sem atributos, sem progressão, sem alimentação ou treino de verdade e sem interface.

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

## Caramelo

**A arte é provisória.** Não existe sprite de cachorro no projeto e esta etapa não podia criar assets externos, então Caramelo é montado com `Polygon2D` do próprio Godot: tronco, barriga, cabeça, focinho, nariz, olho, duas orelhas, coleira, rabo, quatro patas e uma sombra. São cerca de **143 × 88 px** no sistema de coordenadas-base, comparáveis à cadeira plástica do cenário. A silhueta será substituída por arte real na Etapa 5 — nada aqui pretende ser definitivo.

A representação deixa perceber direção (o nó `Visual` espelha em X), parado, caminhando, descansando, comendo, treinando e a reação feliz.

### Estrutura da cena

```text
Caramelo                (CharacterBody2D)   ← caramelo.gd
├── Visual              (Node2D)            ← caramelo_visual.gd
│   ├── Shadow          (Polygon2D)
│   ├── Tail            (Node2D)   pivô na base do rabo
│   │   └── TailShape   (Polygon2D)
│   ├── LegsBack        (Node2D)   pivô no quadril
│   │   ├── LegBackFar  (Polygon2D)   tom escuro: patas do lado oposto
│   │   └── LegBackNear (Polygon2D)
│   ├── Body            (Node2D)
│   │   ├── Torso       (Polygon2D)
│   │   └── Belly       (Polygon2D)
│   ├── LegsFront       (Node2D)   pivô no ombro
│   │   ├── LegFrontFar (Polygon2D)
│   │   └── LegFrontNear(Polygon2D)
│   ├── Collar          (Polygon2D)
│   └── Head            (Node2D)   pivô no pescoço
│       ├── EarFar · Skull · Muzzle · Nose · Eye · EarNear  (Polygon2D)
└── CollisionShape2D    (CapsuleShape2D deitada, do tamanho do tronco)
```

A **origem do nó fica nas patas**, no chão. É ela que o polígono caminhável valida e também a chave de ordenação do `y_sort_enabled` de `CharacterLayer`.

**Não há `AnimationPlayer`.** As poses são funções contínuas do tempo aplicadas a quatro pivôs (rabo, patas dianteiras, patas traseiras e cabeça) mais uma respiração em escala. Manter faixas de keyframes custaria um recurso que será descartado assim que a arte definitiva chegar, e funções contínuas sem sorteio garantem ausência de tremor. `Visual` só desenha: não conhece a área caminhável, não decide nada e não toca em atributo algum.

### Estados

Os seis estados do `MVP_SPEC.md` §10, no enum `Caramelo.State`. Não há strings de estado espalhadas pelo código.

| Estado | Entrada | Duração / término | Interrompível | Movimento | Visual |
| ------ | ------- | ----------------- | ------------- | --------- | ------ |
| `IDLE` | Estado inicial; fim de qualquer outro | Espera sorteada de 2,5 a 6 s, ao fim da qual decide a próxima ação | Sim | Parado | Respiração leve, rabo lento |
| `WALKING` | Ao receber um destino válido | Ao alcançar o destino | Sim — um novo comando substitui o destino | 130 px/s pelo trajeto | Balanço do corpo, patas alternadas, rabo no ritmo |
| `EATING` | Ao chegar ao `FoodPoint` | 4 s (S-4) | **Não** | Parado | Cabeça abaixada ao chão, rabo rápido |
| `TRAINING` | Ao chegar ao `TrainingPoint` | 6 s (marcador provisório) | **Não** | Parado | Corpo subindo e descendo |
| `RESTING` | Comando, ou decisão autônoma | Sorteada de 7 a 14 s | Sim | Parado | Deita: encolhe até o chão, respiração ampla |
| `HAPPY` | Fim de `EATING` ou `TRAINING`; comando | 2 s (S-4) | Sim | Parado | Pulinhos e rabo acelerado |

Nenhum estado altera `energy`, `strength`, `bond` ou `level` — esses atributos não existem ainda. `EATING`, `TRAINING` e `HAPPY` rodam só o comportamento visual e terminam sozinhos, sem recompensa.

As durações de comer e da reação feliz seguem a suposição **S-4** do `MVP_SPEC.md`. A do treino é um marcador: a duração real de cada exercício nasce de `data/exercises.json` na Etapa 5. **Nenhum valor aqui é balanceamento.**

### Matriz de transições

Reproduz literalmente o `MVP_SPEC.md` §10. Qualquer par fora dela é rejeitado explicitamente, com aviso — nunca tratado como caso especial silencioso.

| De ↓ / Para → | `IDLE` | `WALKING` | `EATING` | `TRAINING` | `RESTING` | `HAPPY` |
| ------------- | :----: | :-------: | :------: | :--------: | :-------: | :-----: |
| `IDLE`        |   —    |     ✅    |    ✅    |     ✅     |    ✅     |   ✅    |
| `WALKING`     |   ✅   |     —     |    ✅    |     ✅     |    ✅     |   ❌    |
| `EATING`      |   ✅   |     ❌    |    —     |     ❌     |    ❌     |   ✅    |
| `TRAINING`    |   ❌   |     ❌    |    ❌    |     —      |    ✅     |   ✅    |
| `RESTING`     |   ✅   |     ❌    |    ✅    |     ✅     |    —      |   ❌    |
| `HAPPY`       |   ✅   |     ❌    |    ❌    |     ❌     |    ✅     |   —     |

### Regras de interrupção

* `EATING` e `TRAINING` **não são interrompíveis**. Comandos recebidos durante eles são **descartados**, nunca enfileirados: quando a atividade termina, ela segue para o destino padrão (`HAPPY`), e não para o comando recusado.
* Reentrar no estado atual é recusado em vez de reiniciar o estado — o cronômetro em curso não é zerado.
* Uma transição rejeitada **não emite sinal**. Só transições aceitas emitem `state_changed(previous_state, new_state)`, exatamente uma vez cada.
* As transições internas por fim de duração (por exemplo `EATING → HAPPY`) não passam por `request_state`: não são comandos, e por isso não são descartadas por si mesmas.

### Comportamento autônomo

Sem interação, Caramelo alterna apenas entre `IDLE`, `WALKING` e `RESTING`. Começa em `IDLE`.

Ao fim de cada espera ociosa ele decide uma única vez — **nunca por quadro**, o que evita tremor e troca de estado frequente. A chance de caminhar é 72%; o resto é descansar. **Dois descansos seguidos são proibidos**, aplicando ao caso o princípio do `MVP_SPEC.md` §9 de não repetir o mesmo comportamento autônomo duas vezes em sequência. Medido em 20 sementes × 10 min: 22% de descansos e nenhuma sequência repetida, com troca de estado a cada ~9 s.

Se nenhum destino válido for sorteado, ele simplesmente continua ocioso e tenta de novo depois.

O gerador é um `RandomNumberGenerator` próprio, aleatorizado na abertura — o jogo entregue não fica preso a uma única sequência. `set_random_seed()` fixa a semente para os testes.

### Movimento e integração com o polígono

Caramelo recebe do ambiente a **área caminhável real**, não o retângulo envolvente.

* Um ponto só vale se estiver dentro do polígono (`Geometry2D.is_point_in_polygon`) **e** a pelo menos **26 px** de qualquer aresta. Essa margem mantém as patas confortavelmente no piso e ainda deixa 80% da área do polígono utilizável (≈ 321 000 px² de 400 000).
* O destino é validado **antes** de o movimento começar.
* Como o polígono é côncavo, o **trajeto** também é validado: o segmento inteiro é amostrado a cada 24 px e cada amostra precisa ser válida. Sem isso, dois pontos válidos poderiam ser ligados por uma linha que sai da área.
* Se a linha reta não serve, há um único desvio: um ponto interno seguro, o mais distante da borda, calculado por varredura em grade. Se nem essa rota de duas pernas serve, o destino é recusado e outro é sorteado. **Não há pathfinding** e nenhum `NavigationRegion2D` foi criado.
* Ao chegar, a posição é **encaixada exatamente** no destino e a velocidade é zerada — sem ultrapassar e sem oscilar em volta do ponto.
* O polígono do quintal **não foi alterado** para facilitar o movimento.

Na prática o quintal é quase convexo: medindo 4 000 pares de pontos válidos, só **0,4%** dos trajetos diretos precisam do desvio.

### Ordenação por profundidade

`CharacterLayer` tem `y_sort_enabled`, e a origem de Caramelo fica nas patas — então quem está mais embaixo na tela desenha à frente. O `z_index` das camadas continua o da Etapa 3: fundo (−100) < personagens (0) < objetos (10) < primeiro plano (20).

**Limitação:** a vegetação do primeiro plano continua pintada na imagem de fundo, ou seja, desenhada *atrás* de Caramelo. A área caminhável foi traçada acima dela justamente para que a sobreposição nunca aconteça. `ForegroundLayer` segue vazia, esperando um recorte dessa vegetação.

### Como o quintal configura Caramelo

Caramelo é instanciado dentro de `CharacterLayer`, em `backyard.tscn`, na posição `(880, 860)`.

Quem conhece a geometria é o ambiente: `backyard.gd` converte o polígono e os três `Marker2D` para o espaço de coordenadas de `CharacterLayer` e os entrega a cada filho que responda aos métodos correspondentes. Foi a opção **"método explícito de inicialização"** entre as sugeridas.

Assim Caramelo não procura nada por caminhos frágeis como `../../WorldBounds`, a checagem por `has_method` evita que o quintal dependa do tipo do personagem, e — por estar dentro de `Backyard` — ele herda automaticamente a escala uniforme aplicada pelo enquadramento, sem nenhum código extra.

### API pública

```gdscript
signal state_changed(previous_state: int, new_state: int)

func request_state(new_state: int) -> bool        # transição direta; false quando recusada
func request_activity(activity: int) -> bool      # caminha até o ponto e só então entra na atividade
func get_current_state() -> int
func get_destination() -> Vector2                 # destino do trajeto; a própria posição se parado
func is_interruptible() -> bool
func set_random_seed(value: int) -> void
func set_walkable_polygon(polygon: PackedVector2Array) -> void
func set_interaction_points(food: Vector2, training: Vector2, rest: Vector2) -> void
func simulate(delta: float) -> void
static func state_name(state: int) -> String
```

`request_state` devolve `false` — sem emitir sinal — para estado inexistente, estado atual não interrompível, par ausente da matriz e reentrada no estado atual.

`request_activity` existe porque o `MVP_SPEC.md` separa o deslocamento da atividade: o jogador escolhe a comida, Caramelo **caminha** até o pote e só ao chegar entra em `EATING`. Ela devolve `true` ao aceitar o comando, ainda que o estado imediato seja `WALKING`. Como a matriz não liga `RESTING` nem `HAPPY` a `WALKING`, nesses casos Caramelo primeiro se levanta (`→ IDLE`) e só então caminha — toda aresta percorrida continua válida.

`simulate` é o corpo de `_physics_process`, exposto porque o `MVP_SPEC.md` §20 ("Testabilidade") exige durações aceleráveis: os testes simulam minutos de jogo em milissegundos sem esperar tempo real nem mexer em `Engine.time_scale`. A propriedade exportada `development_time_scale` atende ao mesmo requisito em execução normal e vale `1.0` no jogo entregue.

**Não há `Timer`.** Os cronômetros de estado e de decisão são contadores internos avançados por `simulate`, porque nós `Timer` seguem o relógio do motor e não poderiam ser adiantados de forma determinística — o que inviabilizaria metade dos testes obrigatórios. Os papéis de `StateTimer` e `DecisionTimer` continuam existindo, como campos.

## Estrutura da cena principal

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
│       ├── CharacterLayer    (Node2D)       z = 0, y_sort_enabled
│       │   └── Caramelo      (instância de caramelo.tscn, em (880, 860))
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

## Como executar os testes

Os testes são permanentes, rodam sem janela e não dependem de nenhum framework externo:

```bash
godot --headless --path . --script tests/test_caramelo_controller.gd
```

Saem com código `0` quando tudo passa e `1` na primeira falha, imprimindo cada verificação. São **69 verificações** cobrindo estado inicial, existência dos seis estados, transições válidas e inválidas, reentrada, não interrupção de `EATING` e `TRAINING`, descarte de comandos, sinais, destinos e trajetos dentro do polígono, parada no destino, reprodutibilidade por semente, acompanhamento da transformação do quintal e unicidade de Caramelo na cena principal.

O tempo nunca é esperado de verdade: a suíte chama `Caramelo.simulate(delta)` em laço, de modo que dez minutos de jogo passam em milissegundos e o resultado é determinístico.

O esperado é uma janela preenchida de ponta a ponta pelo quintal ao entardecer, sem barras vazias e sem deformação. Ao arrastar a borda da janela, a imagem continua cobrindo tudo: em janelas mais largas que 16:9 ela é recortada em cima e embaixo, e em janelas mais altas, nas laterais.

## Como validar visualmente

```bash
godot --path . --resolution 1280x720 --position 60,60
```

Deixe rodando um ou dois minutos e observe Caramelo. O esperado:

* Ele começa parado, respirando, virado para a direita.
* De tempos em tempos escolhe um ponto do quintal e caminha até lá, virando o corpo conforme a direção.
* Ao chegar, para de vez — sem deslizar nem tremer em volta do ponto.
* De vez em quando deita para descansar e depois se levanta. Nunca dois descansos seguidos.
* As patas ficam sempre no piso de concreto: ele não sobe no muro, no telhado nem entra na vegetação da frente.
* Não há teletransporte: todo deslocamento é contínuo.

Em outras proporções, confira que a escala dele acompanha o quintal:

```bash
godot --path . --resolution 1024x768 --position 60,60
godot --path . --resolution 640x1000  --position 60,60
```

Com `--debug-collisions`, o polígono da área caminhável aparece desenhado sobre o piso, o que deixa ver que Caramelo nunca o atravessa:

```bash
godot --path . --resolution 1280x720 --position 60,60 --debug-collisions
```

O que conferir no cenário:

* O contorno acompanha o concreto e não invade telhado, céu, muros nem as plantas do primeiro plano.
* Ele encosta na base da parede do fundo, sem sobrar faixa de piso inalcançável.
* Redimensionando a janela, o contorno continua colado ao piso — ele escala junto com a arte.

## O que foi implementado nesta etapa

* `scenes/dog/caramelo.tscn`: a cena do cachorro, com a silhueta provisória em `Polygon2D` e a cápsula de colisão.
* `scripts/dog/caramelo.gd`: o controlador — máquina de estados, movimento dentro do polígono, decisões autônomas e API pública.
* `scripts/dog/caramelo_visual.gd`: as poses, separadas da lógica.
* `tests/test_caramelo_controller.gd`: 69 verificações permanentes, headless e determinísticas.
* `scenes/environment/backyard.tscn`: instancia Caramelo em `CharacterLayer` e liga `y_sort_enabled` na camada.
* `scripts/environment/backyard.gd`: passa a entregar aos personagens a área caminhável e os três pontos, convertidos para o espaço de `CharacterLayer`. O enquadramento da Etapa 3 não foi tocado.

`scenes/main/main.tscn` não mudou: Caramelo entra pelo quintal, não pela cena principal.

Sobre os arquivos de importação: `.godot/` (o cache gerado) permanece ignorado pelo Git, enquanto `assets/backgrounds/quintal_mvp.png.import` é versionado. Esse arquivo guarda o `uid://` do recurso e os parâmetros de importação; versioná-lo é a prática recomendada no Godot 4 e evita que a referência da cena mude a cada clone.

## Limitações conhecidas

* **A arte tem dois conjuntos de treino** — banco, barra e halteres à esquerda; barras de flexão à direita — e esta etapa prevê um único `TrainingPoint`, colocado no conjunto da esquerda. Quando os exercícios forem implementados (Etapa 6), flexões e halteres provavelmente precisarão de marcadores separados.
* **Não existe pote na imagem.** `FoodPoint` marca onde o pote entrará como objeto em `PropsLayer`, numa etapa posterior.
* **`ForegroundLayer` está vazia.** A vegetação do primeiro plano faz parte da imagem de fundo, então ela é desenhada *atrás* de Caramelo. A área caminhável foi traçada acima dessa vegetação justamente para esconder o problema. Fazer Caramelo passar de fato atrás das folhas exigiria recortá-las da arte, o que não foi feito para preservar o asset original.
* **Sem mipmaps.** Em janelas bem menores que 1672 px de largura a redução usa filtragem linear simples. Gerar mipmaps é uma otimização possível para a Etapa 12.
* **Proporções extremas recortam muito.** Em 640 × 1000 sobram cerca de 35% da largura da arte. O recorte é centrado e previsível, mas boa parte do quintal fica fora da tela.
* **Consumo não foi medido.** A máquina de desenvolvimento usa renderização por software (Mesa llvmpipe), inadequada para aferir as metas de FPS e CPU da seção 20 do `MVP_SPEC.md`. Isso fica para a Etapa 12, junto com a definição do computador de referência (ponto em aberto A-1).

### Caramelo

* **A arte é provisória e feita de formas geométricas.** É reconhecível como um vira-lata caramelo, mas não tem a expressividade que o `MVP_SPEC.md` §15 pede. Sprites reais chegam na Etapa 5.
* **Só a forma inicial existe.** A forma musculosa (níveis 4–5) não foi tentada.
* **O desvio de trajeto tem uma perna só.** Se nem a linha reta nem a rota pelo ponto interno servirem, o destino é recusado. Basta para este quintal, que é quase convexo (0,4% dos trajetos precisam do desvio), mas um cenário mais recortado exigiria outra solução.
* **Caramelo não desvia de objetos.** O `CharacterBody2D` tem cápsula de colisão e `velocity`, mas a posição é integrada diretamente em vez de `move_and_slide()` — não existe nada com que colidir, e `move_and_slide()` usaria o delta do motor, o que quebraria a simulação determinística dos testes. Quando a Etapa 6 trouxer objetos com corpo, a troca é de uma linha.
* **`EATING`, `TRAINING` e `HAPPY` não são jogabilidade.** Rodam o comportamento visual, respeitam as regras de interrupção e terminam sozinhos. Não concedem nada, porque não há atributos.
* **Um único `TrainingPoint`.** Segue valendo a limitação da Etapa 3: a arte tem dois conjuntos de treino e Caramelo só conhece o da esquerda.

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

* Arte definitiva de Caramelo e a forma musculosa dos níveis 4–5.
* Os cinco comportamentos ociosos do `MVP_SPEC.md` §9 (sentar, alongar, farejar, perseguir mosca). Esta etapa entrega apenas ocioso, caminhada e descanso.
* Carinho e os comportamentos afetivos por vínculo.
* Objetos do cenário como entidades próprias — pote, halteres e barras ainda fazem parte da imagem de fundo.
* Atributos (`energy`, `strength`, `bond`, `level`) e progressão de níveis.
* Alimentação, exercícios e descanso com efeito de verdade.
* Interface, barras e botões.
* Salvamento local e progresso offline.
* Modo papel de parede, modo silencioso e redução de consumo.
* Áudio — habilitado tecnicamente, mas nenhum som é reproduzido.
* Arquivos JSON de balanceamento em `data/`.

O roteiro completo está em [`PLANO_MVP.md`](PLANO_MVP.md).
