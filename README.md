# Como Aumentar Seu Caramelo

Jogo 2D idle para desktop que também funciona como papel de parede animado. O jogador cuida de um vira-lata caramelo brasileiro: ele come para recuperar energia, treina para ganhar força, descansa e evolui gradualmente até uma forma mais musculosa e carismática.

**A fonte oficial de requisitos é [`MVP_SPEC.md`](MVP_SPEC.md).** Em caso de divergência, ela prevalece sobre [`DESIGN.md`](DESIGN.md) (visão de longo prazo) e [`PLANO_MVP.md`](PLANO_MVP.md) (roteiro de 12 etapas).

## Estado atual

**Etapa 11 de 12 — Evolução visual e vínculo.** Caramelo agora tem duas formas: a inicial dos níveis 1–3 e a musculosa dos níveis 4–5, que chega com uma transformação de 1,4 s no instante em que a força cruza 140. Os níveis 2, 4 e 5 ganharam evento visual próprio, e o carinho virou ação de verdade: um clique dá +1 de vínculo, entra em recarga de um minuto e destrava três comportamentos afetivos ao longo da convivência. O save passou para a versão 2, migrando sozinho o que a versão anterior escreveu. **Modo papel de parede, configurações e áudio continuam fora.**

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
| `PushUpsPoint` | `(1580, 845)` | `(1376, 736)` | Entre as barras de flexão, à direita. Caramelo fica no meio delas, e as barras seguem visíveis dos dois lados |
| `DumbbellsPoint` | `(620, 770)` | `(540, 670)` | Junto à academia improvisada da esquerda — banco, barra e halteres —, com os pesos do chão à vista |
| `RestPoint` | `(1217.2, 734.6)` | `(1060, 640)` | À frente da cadeira plástica branca, exatamente o local que o `MVP_SPEC.md` §10 descreve para o estado `RESTING` ("deitado no chão ou perto da cadeira de plástico") |

Os quatro estão dentro da área caminhável, têm posições distintas e permanecem visíveis na tela nas resoluções validadas. `PushUpsPoint` e `DumbbellsPoint` substituíram, na Etapa 7, o `TrainingPoint` único que existia aqui.

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
| `IDLE` | Estado inicial; fim de qualquer outro | Espera sorteada de 2,5 a 6 s, ao fim da qual decide a próxima ação | Sim | Parado | Respiração leve e um dos cinco microcomportamentos |
| `WALKING` | Ao receber um destino válido | Ao alcançar o destino | Sim — um novo comando substitui o destino | 130 px/s pelo trajeto | Balanço do corpo, patas alternadas, rabo no ritmo |
| `EATING` | Ao chegar ao `FoodPoint` | 4 s (S-4) | **Não** | Parado | Cabeça abaixada ao chão, rabo rápido |
| `TRAINING` | Ao chegar ao ponto do exercício | duração vinda de `exercises.json` | **Não** | Parado | Flexões ou halteres, conforme o estilo |
| `RESTING` | `RestSystem.request_rest()`, ou decisão autônoma | Sorteada de 7 a 14 s | Sim | Parado | Deitado no chão, respiração lenta, olho quase fechado. **Recupera energia** |
| `HAPPY` | Fim de `EATING` ou `TRAINING`; comando | 2 s (S-4) | Sim | Parado | Pulinhos e rabo acelerado |

Nenhum estado altera `energy`, `strength`, `bond` ou `level` — esses atributos não existem ainda. `EATING`, `TRAINING` e `HAPPY` rodam só o comportamento visual e terminam sozinhos, sem recompensa.

As durações de comer e da reação feliz seguem a suposição **S-4** do `MVP_SPEC.md`. A do treino **vem dos dados**: quem pede a atividade informa por quanto tempo ela dura, via `set_activity_duration`. As constantes do controlador só valem como reserva, quando ninguém informa nada. **Caramelo não conhece custo nem recompensa.**

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

Ao fim de cada espera ociosa ele decide uma única vez — **nunca por quadro**, o que evita tremor e troca de estado frequente. A chance de descansar deixou de ser fixa na Etapa 8: ela vem da energia atual, entregue pelo `RestSystem`. **Dois descansos seguidos são proibidos**, aplicando ao caso o princípio do `MVP_SPEC.md` §9 de não repetir o mesmo comportamento autônomo duas vezes em sequência.

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
func request_activity(activity: int, target_override := Vector2.INF) -> bool
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

## Atributos e progressão

O modelo de dados existe e é testável, mas **nada ainda o alimenta**: comer, treinar e o carinho continuam sem efeito. Esta etapa entrega só o modelo, os dados e os sinais.

### Organização de `data/`

A divergência registrada na Etapa 2 está resolvida: `MVP_SPEC.md` §14 nomeia **arquivos**, não diretórios, e é ele que prevalece. Os diretórios vazios `data/foods/`, `data/exercises/` e `data/levels/` foram removidos junto com seus `.gitkeep`.

```text
data/
├── levels.json      progressão de nível, valores iniciais e limiares de vínculo
├── foods.json       os três alimentos
└── exercises.json   os dois exercícios
```

Nenhum número de balanceamento vive no código. O `MVP_SPEC.md` §14 é explícito: *"Nenhum valor de balanceamento — custo, duração, recompensa, limiar ou recarga — pode ser fixado diretamente no código."* Por isso até os **valores iniciais dos atributos** vêm de `levels.json`, e não de constantes.

### Esquema de `levels.json`

```jsonc
{
  "schema_version": 1,
  "max_level": 5,
  "initial_attributes": { "energy": 70, "max_energy": 100, "strength": 0, "bond": 0 },
  "strength_levels": [
    { "level": 1, "required_strength": 0, "description": "...", "unlocks": ["basic_actions", "push_ups"] }
  ],
  "bond_behaviors": [
    { "id": "petting_reaction", "required_bond": 10, "display_name": "..." }
  ]
}
```

Três seções claramente separadas: a tabela de força, os limiares de vínculo e os valores iniciais. `max_level` precisa bater com o tamanho da tabela — o carregador recusa se divergirem.

| Nível | Força | Desbloqueios |
| ----: | ----: | ------------ |
| 1 | 0 | `basic_actions`, `push_ups` |
| 2 | 25 | `level_2_celebration` |
| 3 | 70 | `dumbbells` |
| 4 | 140 | `muscular_form` |
| 5 | 250 | `final_pose`, `final_achievement_effect` |

| Vínculo | Comportamento |
| ------: | ------------- |
| 10 | `petting_reaction` — reação ao carinho |
| 25 | `startup_celebration` — comemoração especial ao iniciar |
| 50 | `rare_affection_idle` — animação afetiva rara |

Desbloqueios de nível e comportamentos de vínculo compartilham **um único espaço de identificadores**, e o carregador recusa colisões entre eles. Nenhum desses desbloqueios foi implementado visualmente; esta etapa só disponibiliza a consulta.

### Esquema de `foods.json`

```jsonc
{ "id": "kibble", "display_name": "Racao", "energy": 20, "bond": 1,
  "cooldown_seconds": 300, "animation_seconds": 4.0 }
```

| ID | Energia | Vínculo | Recarga |
| -- | ------: | ------: | ------: |
| `kibble` | +20 | +1 | 300 s |
| `chicken_rice` | +35 | +2 | 900 s |
| `cheese_bread` | +15 | +3 | 600 s |

Os nomes de exibição são em português; os IDs são técnicos e estáveis.

### Esquema de `exercises.json`

```jsonc
{ "id": "push_ups", "display_name": "Flexoes", "energy_cost": 15, "duration_seconds": 20,
  "strength_gain": 5, "required_level": 1, "unlock_id": "push_ups",
  "training_point": "PushUpsPoint", "comic_reaction_chance": 0.10 }
```

| ID | Energia | Duração | Força | Nível |
| -- | ------: | ------: | ----: | ----: |
| `push_ups` | 15 | 20 s | +5 | 1 |
| `dumbbells` | 25 | 30 s | +9 | 3 |

`unlock_id` e `required_level` são redundantes de propósito: o carregador exige que o desbloqueio exista em `levels.json` **e** que o nível em que ele aparece seja exatamente `required_level`. É essa redundância que torna a relação entre os arquivos verificável.

### Carregador de configuração

[`scripts/systems/game_config.gd`](scripts/systems/game_config.gd) lê e valida os três arquivos.

Ele verifica existência, sintaxe do JSON, a raiz do arquivo, presença de cada campo obrigatório, tipos, faixas e as relações entre os arquivos. Números de JSON chegam como `float` no Godot, então inteiros são aceitos só quando exatos.

**Um arquivo que existe mas está errado nunca é corrigido em silêncio nem substituído por padrões.** A configuração inteira é marcada inválida, `errors` descreve cada problema com arquivo e campo, e os acessores devolvem vazio — os dados só ficam visíveis depois que tudo passa. `GameSession` despeja cada erro com `push_error` e dispara um `assert`, para que a falha apareça durante o desenvolvimento em vez de virar comportamento estranho de jogo.

Exemplos de mensagem:

```text
levels.json/strength_levels[2]: limiar de forca 25 duplicado.
exercises.json/exercises[0]: 'dumbbells' e concedido no nivel 3, mas 'required_level' diz 1.
foods.json/foods[0]: 'energy' deve ser numero inteiro, veio String.
```

Não há download, atualização remota nem recarga em tempo de execução.

### Modelo de progressão

[`scripts/systems/progression_model.gd`](scripts/systems/progression_model.gd) não conhece cena, interface nem personagem — recebe um `GameConfig` e responde a chamadas. Roda inteiro sem abrir cena alguma.

Valores iniciais: `energy` 70, `max_energy` 100, `strength` 0, `bond` 0, `level` 1.

| Atributo | Regras |
| -------- | ------ |
| `energy` | Nunca abaixo de 0 nem acima de `max_energy`. A recuperação aplica clamp e informa quanto foi de fato aplicado. O gasto é **atômico**: sem saldo, nada muda. Custo zero ou negativo é recusado. |
| `strength` | Começa em 0 e **nunca diminui**. Ganho zero ou negativo é recusado. Não tem teto no modelo, embora o nível pare em 5. Cruzar vários limiares de uma vez funciona. |
| `bond` | Começa em 0, **nunca diminui**, sem teto. Ganho zero ou negativo é recusado. Libera só comportamentos afetivos — nunca bônus de força, energia ou velocidade. |
| `level` | **Derivado de `strength`, sempre.** Não existe campo `level` nem `set_level()`: não há segunda fonte de verdade capaz de divergir. Entre 1 e 5, nunca regride. |

#### API

```gdscript
func get_energy() -> int
func get_max_energy() -> int
func get_strength() -> int
func get_bond() -> int
func get_level() -> int                    # sempre derivado da força

func try_spend_energy(amount: int) -> bool # true só quando o gasto acontece; atômico
func restore_energy(amount: int) -> int    # devolve a energia EFETIVAMENTE restaurada
func add_strength(amount: int) -> int      # devolve o NOVO TOTAL de força
func add_bond(amount: int) -> int          # devolve o NOVO TOTAL de vínculo

func has_unlock(unlock_id: StringName) -> bool
func is_exercise_unlocked(exercise_id: StringName) -> bool
func get_unlocks() -> PackedStringArray
func get_unlocked_bond_behaviors() -> PackedStringArray
func get_snapshot() -> Dictionary          # cópia; alterá-la não afeta o modelo
func get_config() -> GameConfig
```

Nenhuma propriedade mutável é pública. `get_snapshot()` devolve cópia nova a cada chamada. `is_exercise_unlocked()` devolve `false` para identificador desconhecido — não há aceite silencioso.

#### Sinais e sua ordem

```gdscript
signal energy_changed(previous_value: int, new_value: int)
signal strength_changed(previous_value: int, new_value: int)
signal bond_changed(previous_value: int, new_value: int)
signal level_changed(previous_level: int, new_level: int)
signal unlock_granted(unlock_id: StringName)
```

A ordem é fixa e vale para toda operação:

```text
add_strength     →  strength_changed  →  level_changed  →  unlock_granted (1..N)
add_bond         →  bond_changed      →  unlock_granted (1..N)
restore_energy   →  energy_changed
try_spend_energy →  energy_changed
```

O atributo muda primeiro; as consequências derivadas vêm depois, do mais geral (nível) para o mais específico (cada desbloqueio). Os desbloqueios saem em ordem crescente de nível — ou de vínculo exigido — e, dentro do mesmo nível, na ordem do arquivo de dados.

Regras de emissão:

* Só emite quando o valor **realmente muda**. Recuperar energia já cheia devolve 0 e não emite nada.
* Operação recusada não emite sinal algum.
* Cada desbloqueio é emitido **uma única vez**. Cruzar vários níveis numa operação emite todos os intermediários, nenhum perdido.
* Consultar valores nunca emite sinal.

### `GameSession`

[`scripts/systems/game_session.gd`](scripts/systems/game_session.gd) é um `Node` na cena principal, o primeiro filho de `Main`:

```text
Main                    (Node)
├── GameSession         (Node)        ← carrega a configuração, possui o modelo
├── World               (Node2D)
│   └── Backyard        (instância de backyard.tscn)
└── Interface           (CanvasLayer, vazia)
```

Ela carrega a configuração **uma única vez por sessão**, cria e possui a instância do modelo e entra no grupo `game_session`. Quem precisar dela usa `GameSession.find_in(tree)`, nunca um caminho como `../../`.

**Não é Autoload** porque um Autoload seria estado global vivo também no editor e em cenas de teste, e nada aqui precisa disso.

### Separação entre o modelo e Caramelo

É um critério de aceitação, verificado por teste:

* Caramelo **não tem** propriedades nem métodos de `energy`, `strength`, `bond` ou `level`.
* Caramelo não conhece o modelo; o modelo não conhece a cena nem o controlador.
* `GameSession` não toca na máquina de estados de Caramelo e não se liga aos sinais dele.
* Nenhum estado gasta energia ou concede força ou vínculo. Rodar a cena por dois minutos deixa os valores exatamente em 70 / 0 / 0 / nível 1.

O acoplamento entre atributos e comportamento só aparece na Etapa 6.

## Sistema de alimentação

É o primeiro ciclo funcional do jogo: o jogador escolhe, Caramelo caminha e come, e só então os atributos mudam.

### Arquitetura

Cada parte segue sem conhecer as outras. O [`FeedingSystem`](scripts/systems/feeding_system.gd) é o único lugar que as liga.

| Parte | Responsabilidade | O que **não** faz |
| ----- | ---------------- | ----------------- |
| [`FoodBowl`](scripts/environment/food_bowl.gd) | Desenhar o pote e avisar que foi selecionado | Não conhece alimento, recarga nem modelo |
| [`FoodMenu`](scripts/ui/food_menu.gd) | Abrir/fechar, listar, mostrar recarga, encaminhar a escolha | **Nunca toca no modelo** nem aplica recompensa |
| [`FeedingSystem`](scripts/systems/feeding_system.gd) | Aceitar ou recusar, manter uma refeição pendente, pagar na conclusão, correr as recargas | Não mexe em propriedades internas do modelo, não anima Caramelo, não grava em disco |
| [`Caramelo`](scripts/dog/caramelo.gd) | Caminhar até `FoodPoint`, entrar em `EATING`, avisar a conclusão | **Não sabe qual alimento** nem quanto ele vale; não aplica recompensa nem controla recarga |
| [`ProgressionModel`](scripts/systems/progression_model.gd) | `restore_energy`, `add_bond`, limites e desbloqueios | Não sabe que houve uma refeição |

Nenhum número de balanceamento vive no código: energia, vínculo e recarga saem de `data/foods.json`, relidos dos dados validados no momento de pagar.

### Fluxo completo

```text
jogador clica no pote
  └─ FoodBowl.selected            → FeedingSystem.bowl_selected → FoodMenu abre
jogador escolhe um alimento
  └─ FoodMenu → FeedingSystem.request_feeding(food_id)
       ├─ recusa  → feeding_rejected(food_id, reason)   menu segue aberto, nada muda
       └─ aceita  → refeição pendente registrada
                    Caramelo.request_activity(EATING)
                    feeding_requested(food_id)          menu fecha
Caramelo: IDLE/RESTING/HAPPY → (IDLE) → WALKING até FoodPoint → EATING (4 s)
  └─ ao terminar sozinho: Caramelo.activity_completed(EATING)
       └─ FeedingSystem paga, limpa a pendência e inicia a recarga
```

O `MVP_SPEC.md` §10 separa deslocamento de atividade, e essa distinção foi preservada: aceitar um pedido **não** põe Caramelo em `EATING` — põe em `WALKING`. Ele só come ao chegar.

Como a matriz não liga `RESTING` nem `HAPPY` a `WALKING`, nem `HAPPY` a `EATING`, nesses casos Caramelo primeiro se levanta ou se acalma (`→ IDLE`). É o que permite pedir uma refeição enquanto ele ainda comemora a anterior. Toda aresta percorrida continua válida.

### Momento da recompensa

Nada é aplicado ao pedir, ao caminhar ou ao entrar em `EATING`. **Só na conclusão natural da atividade**, e exatamente uma vez.

Ordem obrigatória dos efeitos, verificada por teste:

```text
energy_changed              (do modelo, se a energia realmente mudou)
bond_changed                (do modelo)
unlock_granted              (do modelo, se o vínculo cruzou 10, 25 ou 50)
feeding_completed           (do sistema)
cooldown_changed            (do sistema)
```

Com a energia já em 100: **`energy_changed` não é emitido**, o vínculo ainda sobe, a refeição ainda conclui e a recarga ainda começa. `feeding_completed` informa o ganho **efetivo** — alimentar com 70 de energia usando frango com arroz (+35) reporta `energy_applied = 30`, não 35.

A recompensa não pode ser reaplicada: a pendência é limpa antes de `feeding_completed`, então um segundo `activity_completed` encontra o sistema vazio e é ignorado. Conclusões de `TRAINING` ou `RESTING` também são ignoradas.

### Recargas

Independentes por alimento, com a duração vinda do JSON.

* Começam **na conclusão**, nunca na solicitação.
* Correm com o menu fechado e chegam exatamente a zero, sem ficar negativas.
* Uma recarga não bloqueia os outros alimentos.
* `cooldown_changed` é emitido ao começar, a cada **segundo inteiro** e ao zerar — nunca a cada quadro. Uma recarga de 300 s gera 301 sinais, não 18 000.

`FeedingSystem.simulate(delta)` avança as recargas. A execução normal chama por `_process`; os testes adiantam minutos instantaneamente. **Nada sobrevive ao fechamento do aplicativo** — persistência e continuação offline são da Etapa 10.

### Sinais

```gdscript
signal bowl_selected()
signal feeding_requested(food_id: StringName)
signal feeding_rejected(food_id: StringName, reason: int)
signal feeding_completed(food_id: StringName, energy_applied: int, bond_applied: int)
signal cooldown_changed(food_id: StringName, remaining_seconds: float)
```

E em Caramelo:

```gdscript
signal activity_completed(activity: int)
```

Emitido **só quando a atividade termina sozinha**, ao esgotar a própria duração: nunca ao entrar no estado, nunca por transição recusada, nunca por comando. Não transporta recompensa — Caramelo não sabe o que a atividade vale. Cobre `EATING`, `TRAINING` e `RESTING`; `HAPPY` fica de fora, porque é reação e não atividade pedida.

### Códigos de rejeição

Códigos estáveis do enum `FeedingSystem.Rejection`, nunca frases livres. A interface traduz se precisar.

| Código | Quando |
| ------ | ------ |
| `NOT_CONFIGURED` | dependências ainda não entregues |
| `UNKNOWN_FOOD` | identificador ausente de `foods.json` |
| `ON_COOLDOWN` | aquele alimento ainda está em recarga |
| `MEAL_PENDING` | já existe uma refeição a caminho |
| `DOG_BUSY` | Caramelo está em `EATING` ou `TRAINING` |
| `DOG_REFUSED` | Caramelo recusou por outro motivo |

Pedidos **nunca são enfileirados**: um pedido recusado simplesmente não acontece. Doze cliques seguidos produzem uma refeição só.

### O pote

`FoodBowl` vive em `PropsLayer`, em `(987.6, 820.1)` — 54 px do `FoodPoint` `(941.6, 792.1)`. Alinhado com ele, mas deslocado o bastante para Caramelo não ficar exatamente em cima. **As coordenadas do `FoodPoint` e o polígono do quintal não foram alterados.**

É feito de `Polygon2D` do próprio Godot, sem asset externo: sombra, corpo, borda, interior e seis grãos. Como está em `PropsLayer` (`z_index` 10), acompanha a escala do quintal e é desenhado à frente de Caramelo.

A área clicável é uma `Area2D` com cápsula do tamanho do visual, com `monitoring` e `monitorable` desligados — ela existe só para captar o clique e **não bloqueia Caramelo**, que nem usa física para andar. Ao passar o mouse, o pote cresce 6% e clareia, e o cursor vira uma mãozinha.

### O menu

`FoodMenu` é um `Control` dentro de `Interface`. Fica oculto por padrão e alterna ao clicar no pote. Mostra os três alimentos **lidos do JSON**, com nome em português, ganhos de energia e vínculo e, quando em recarga, o tempo restante em `m:ss`. Só o alimento indisponível fica desabilitado. Fecha ao aceitar um pedido; uma recusa mantém o menu aberto e utilizável. Não pausa o jogo.

**Legibilidade em qualquer resolução.** Com `stretch/aspect = "expand"` o viewport cresce conforme a janela: em 640 × 1000 ele vira 1920 × 2849. Um painel de tamanho fixo em unidades do viewport encolheria a um terço na tela. O menu multiplica suas medidas pelo fator `viewport.y / janela.y`, de modo a ocupar sempre o mesmo espaço físico — medido: **300 × ~245 px de tela** em 1280 × 720, 1024 × 768 e 640 × 1000.

O fator é aplicado aos **tamanhos de fonte**, e não ao `scale` do nó: escalar o nó reamostraria o texto já rasterizado e ele sairia borrado nas proporções extremas.

Não é um sistema genérico de janelas — é um painel só, com três botões.

### Integração

`GameSession` resolve Caramelo, o pote e o `FoodPoint` **uma única vez**, na abertura, e entrega ao `FeedingSystem`. Não há busca por quadro e não há caminho frágil do tipo `../../World/Backyard`.

A varredura acontece no `_ready` da sessão porque a árvore inteira já está montada quando o primeiro `_ready` roda — instanciar uma cena constrói todo o ramo antes de adicioná-lo. Por isso não é preciso esperar quadro nenhum. Dependências ausentes viram `push_error` com mensagem específica.

```text
Main
├── GameSession          configuração, modelo, resolução de referências
│   └── FeedingSystem    pedidos, refeição pendente, recompensa, recargas
├── World
│   └── Backyard
│       ├── PropsLayer/FoodBowl
│       └── CharacterLayer/Caramelo
└── Interface
    └── FoodMenu
```

## Sistema de exercícios

O segundo ciclo funcional. Diferente da alimentação, ele tem **dois momentos de efeito**: a energia sai ao começar, a força entra ao terminar.

### Dois pontos de treino

A arte tem dois conjuntos de equipamento, e a limitação do marcador único registrada nas Etapas 3 e 4 está resolvida. `TrainingPoint` foi **removido** — não ficou alias nem marcador morto — e em seu lugar entraram dois marcadores distintos em `InteractionPoints`:

| Marcador | Coordenada (base 1920 × 1080) | Equipamento | Folga até a borda |
| -------- | ----------------------------- | ----------- | ----------------: |
| `PushUpsPoint` | `(1580, 845)` | Barras de flexão, à direita | 46 px |
| `DumbbellsPoint` | `(620, 770)` | Banco e halteres, à esquerda | 111 px |

Estão a **963 px** um do outro — não há como confundi-los. Ambos ficam dentro da área caminhável com folga maior que a margem do corpo, e todos os trajetos entre eles e os demais pontos são livres. Caramelo cobre parcialmente o equipamento, nunca por inteiro: nas flexões ele fica **entre** as barras, e nos halteres à frente do banco, com os pesos do chão visíveis.

Em `data/exercises.json`, `training_point` deixou de ser o genérico `TrainingPoint` e passou a nomear cada marcador. **Nenhum valor de balanceamento mudou** — custo, duração, ganho, nível e chance seguem exatamente como na Etapa 5.

### Hotspots

Os equipamentos já estão pintados no fundo, então não há nada a redesenhar. [`EquipmentHotspot`](scripts/environment/equipment_hotspot.gd) é uma cena reutilizável que só ocupa a região correspondente e capta o clique:

| Hotspot | Posição | Área |
| ------- | ------- | ---- |
| `PushUpsHotspot` | `(1580, 775)` | 215 × 130 |
| `DumbbellsHotspot` | `(400, 745)` | 270 × 200 |

Ficam em `PropsLayer`, acompanham a escala do quintal e, no hover, desenham um contorno claro e discreto — nada além disso. A `Area2D` tem `monitoring` e `monitorable` desligados: existe só para o clique e **não bloqueia Caramelo**.

### Fluxo completo

```text
jogador clica no equipamento
  └─ EquipmentHotspot.selected(exercise_id) → ExerciseSystem.request_exercise
       ├─ recusa  → exercise_rejected(id, reason)      nada muda
       └─ aceita  → reserva o exercício
                    Caramelo.set_training_style(id)
                    Caramelo.set_activity_duration(TRAINING, duração do JSON)
                    Caramelo.request_activity(TRAINING, ponto do exercício)
                    exercise_requested(id)
Caramelo caminha até o marcador correto
  └─ ao chegar: entra em TRAINING → activity_started(TRAINING)
       └─ ExerciseSystem debita a energia  →  exercise_started(id, custo)
Caramelo executa pela duração do JSON, parado no ponto
  └─ ao terminar sozinho: activity_completed(TRAINING)
       └─ força creditada → exercise_completed(id, ganho)
          sorteio da reação cômica (depois da recompensa)
```

**A duração vem do dado, não de uma constante.** `ExerciseSystem` informa a Caramelo por quanto tempo executar; ele não conhece custo nem recompensa, só o tempo e o estilo visual. Não existe tempo visual diferente do registrado: medido em teste, flexões duram 20,00 s e halteres 30,00 s simulados.

### Momento do débito e da recompensa

| Momento | O que acontece |
| ------- | -------------- |
| Pedido aceito | Nada. Energia e força intactas |
| Caminhada | Nada |
| **Entrada em `TRAINING`** | Energia debitada, uma única vez |
| Execução | Nada |
| **Conclusão natural** | Força creditada, uma única vez; nível e desbloqueios recalculados pelo modelo |

A energia **não é devolvida** ao concluir. Conclusões repetidas, de outra atividade, ou sem treino iniciado são ignoradas — a reserva é limpa antes de `exercise_completed`, então um segundo sinal encontra o sistema vazio.

**Falha defensiva.** A energia é conferida no pedido e nada mais a consome, então o débito na chegada deveria sempre funcionar. Ainda assim, se falhar: nenhum treino sai de graça, nenhuma força é concedida, a reserva é desfeita, Caramelo sai de `TRAINING` por uma aresta válida da matriz (`→ RESTING`) e sai `exercise_rejected` com `ENERGY_DEBIT_FAILED`.

### Exclusão mútua com a alimentação

A disputa é resolvida por **uma única fonte de verdade**: a reserva mantida em `Caramelo`, que vale do início da caminhada até o fim da atividade. Os dois sistemas consultam `dog.has_reserved_activity()` e **nunca conhecem um ao outro** — não há dependência circular.

| Situação | Resultado |
| -------- | --------- |
| Treino a caminho → pedir comida | recusado, `ACTIVITY_RESERVED` |
| Treino em execução → pedir comida | recusado, `DOG_BUSY` |
| Refeição a caminho → pedir treino | recusado, `ACTIVITY_RESERVED` |
| Comendo → pedir treino | recusado, `DOG_BUSY` |
| Caminhada **dirigida a uma atividade** | não pode ser substituída |
| Caminhada **autônoma** | pode ser substituída por uma atividade aceita |
| Atividade concluída | reserva liberada; o outro sistema volta a aceitar |

Nenhum pedido recusado fica em fila: ele simplesmente não acontece. `EATING` e `TRAINING` seguem não interrompíveis por comando — `cancel_reserved_activity()` existe apenas para o sistema que reservou desfazer o próprio pedido, e não é acessível ao jogador.

### Reação cômica

Sorteada com a chance do JSON (0,10), **depois** de a força já estar creditada — como exige a decisão D-5 do `MVP_SPEC.md`: nenhum resultado de sorteio pode influenciar a recompensa.

É puramente visual: uma versão exagerada de `HAPPY`, com pulo mais alto e giro. Não altera energia, força, vínculo, duração nem a matriz de transições. O sistema tem `RandomNumberGenerator` próprio, aleatorizado na abertura e fixável por `set_random_seed` nos testes. Medida em 480 treinos com sementes fixas, a taxa observada ficou dentro do esperado para 10%.

### Sinais e sua ordem

```gdscript
signal exercise_requested(exercise_id: StringName)
signal exercise_rejected(exercise_id: StringName, reason: int)
signal exercise_started(exercise_id: StringName, energy_spent: int)
signal exercise_completed(exercise_id: StringName, strength_added: int)
signal comic_reaction_triggered(exercise_id: StringName)
signal hotspot_hovered(exercise_id: StringName, hovered: bool)
```

E em Caramelo, novo nesta etapa:

```gdscript
signal activity_started(activity: int)
```

Emitido quando ele entra **de fato** na atividade — já no ponto, nunca durante a caminhada, exatamente uma vez, sempre antes da conclusão e nunca para um pedido recusado.

Ordem efetiva de um treino completo:

```text
exercise_requested
  … caminhada …
state_changed(WALKING → TRAINING)
activity_started(TRAINING)
energy_changed                     ← débito
exercise_started
  … duração do JSON …
state_changed(TRAINING → HAPPY)
activity_completed(TRAINING)
strength_changed                   ← recompensa
level_changed                      se cruzou um limiar
unlock_granted                     um por desbloqueio novo
exercise_completed
comic_reaction_triggered           se sorteada
```

### Códigos de rejeição

Enum `ExerciseSystem.Rejection`, estável, nunca frase livre:

| Código | Quando |
| ------ | ------ |
| `NOT_CONFIGURED` | dependências ainda não entregues |
| `UNKNOWN_EXERCISE` | identificador ausente de `exercises.json` |
| `LOCKED` | nível atual abaixo do exigido |
| `INSUFFICIENT_ENERGY` | energia menor que o custo |
| `EXERCISE_PENDING` | já existe um treino em andamento |
| `DOG_BUSY` | Caramelo em `EATING` ou `TRAINING` |
| `ACTIVITY_RESERVED` | Caramelo já tem outra atividade reservada |
| `POINT_NOT_FOUND` | o marcador do exercício não existe na cena |
| `DOG_REFUSED` | Caramelo recusou por outro motivo |
| `ENERGY_DEBIT_FAILED` | falha defensiva ao cobrar o custo na entrada |

`FeedingSystem.Rejection` ganhou `ACTIVITY_RESERVED` pelo mesmo motivo.

### Feedback contextual

[`TrainingFeedback`](scripts/ui/training_feedback.gd) é uma faixa curta de texto em `Interface`, oculta por padrão. Mostra, no hover: nome, custo e ganho (`Flexões · 15 energia → +5 força`) ou o motivo do bloqueio (`Halteres · bloqueado até o nível 3`). Ao começar mostra `−15 energia`; ao terminar, `Flexões concluído · +5 força`. Some sozinha.

**Não é o HUD da Etapa 9**: não há barras, não mostra energia nem força atuais e, como toda interface deste projeto, **não toca no modelo**. Usa a mesma compensação de escala do menu de alimentos — medida em ~277 × 37 px de tela nas quatro resoluções.

### Nível e disponibilidade

Flexões funcionam desde o nível 1. Halteres ficam bloqueados nos níveis 1 e 2 e liberam **exatamente** no nível 3. A disponibilidade é consultada ao modelo a cada pedido e a cada hover, então ela acompanha a subida de nível **sem reiniciar a cena** — inclusive quando o próprio treino é o que faz subir.

### Poses

Caramelo recebe só o nome do estilo (`push_ups` ou `dumbbells`), nunca custos ou recompensas.

* **Flexões:** o corpo desce e sobe, patas junto ao piso, sem deslocamento horizontal.
* **Halteres:** postura erguida, patas dianteiras alternando, e um **halter geométrico provisório** que aparece só durante esse exercício e some ao terminar.

## Descanso e comportamento ocioso

O ciclo autônomo fecha aqui: Caramelo agora recupera energia descansando, e a ociosidade deixou de ser uma pose só.

### Configuração

Em `data/levels.json`, seção `rest` — separada da progressão de força e dos limiares de vínculo:

```jsonc
"rest": {
  "energy_per_minute": 1,
  "low_energy_threshold": 30,
  "preferred_recovery_target": 50,
  "autonomous_weight_rested": 0.28,
  "autonomous_weight_low": 0.60,
  "autonomous_weight_critical": 0.90
}
```

A taxa vem da suposição **S-1** do `MVP_SPEC.md`; o ponto em aberto **A-3** pedia exatamente esta etapa para validá-la. Todos os valores são provisórios e ficam em dados — **nenhum deles aparece em script**. Os três pesos entraram aqui pelo mesmo motivo: a §14 proíbe balanceamento fixo no código.

O carregador recusa, com mensagem específica: taxa zero ou negativa, limiares fora de `0..max_energy`, alvo menor ou igual ao limiar baixo, pesos fora de `[0, 1]`, pesos que não cresçam conforme a energia cai, campo ausente e tipo errado.

### Recuperação de energia

```text
energia = ⌊ segundos acumulados em RESTING ÷ (60 ÷ energy_per_minute) ⌋
```

Com a configuração atual: **1 ponto a cada 60 segundos**.

A energia sobe **apenas** enquanto Caramelo está efetivamente em `RESTING`. Caminhar até a cadeira não conta, e `IDLE`, `WALKING`, `EATING`, `TRAINING` e `HAPPY` não recuperam nada — verificado por teste, dez minutos em cada um deles não movem a energia.

**Acumulador fracionário.** O tempo é somado numa fração e só vira energia em unidades inteiras, então descansos curtos somam:

```text
30 s + 20 s + 10 s  =  +1 energia
```

A fração sobrevive entre descansos **durante a mesma execução** — sair de `RESTING` não a descarta. Ela não é persistida: fechar o jogo a perde, como todo o resto até a Etapa 10.

Regras de borda:

* Delta zero ou negativo não recupera nada e não mexe no acumulador.
* Um delta grande aplica a quantidade correta de uma vez (605 s → +10, sobrando 5 s).
* A energia nunca passa de `max_energy`.
* **Saturar não deixa crédito escondido:** se a energia enche no meio de um intervalo, o excedente daquele período é descartado. Quarenta minutos de descanso a partir de 70 creditam 30, não 40.
* Com energia cheia, nenhum sinal redundante é emitido.

### Descanso solicitado

`RestSystem.request_rest()` manda Caramelo até o `RestPoint` `(1217.2, 734.6)`, à frente da cadeira plástica — o local que o `MVP_SPEC.md` §10 descreve para `RESTING`. **A coordenada não mudou.**

Aceitar significa só que ele foi mandado para lá: ele caminha, para no ponto e **só então** entra em `RESTING` e começa a recuperar. A reserva é liberada ao terminar.

`RESTING` continua **interrompível**, como manda a especificação — não virou estado bloqueado.

Não há botão na interface: a API existe para a Etapa 9 usar.

### Descanso autônomo

Continua acontecendo sozinho, mas agora a chance depende da energia. O peso é interpolado linearmente entre os três valores do JSON:

```text
energia ≥ 50 (alvo)          →  0,28   descanso ocasional
30 ≤ energia < 50            →  0,28 … 0,60, crescendo conforme cai
energia < 30 (limiar baixo)  →  0,60 … 0,90, até a energia zerar
```

| Energia | Peso | Descansos observados |
| ------: | ---: | -------------------: |
| 80 | 0,28 | 23% das decisões |
| 40 | 0,44 | 31% |
| 10 | 0,80 | 44% |

Quem calcula é o `RestSystem`, a partir da energia; ele entrega o número pronto a Caramelo por `set_rest_tendency`. **Caramelo nunca consulta o modelo** — a separação da Etapa 5 continua valendo.

O peso é só a chance do sorteio. Logo depois de um descanso, o próximo passo é sempre caminhar, então mesmo com energia no chão o descanso fica em 44% das decisões e nunca encadeia: medido em 10 minutos com a energia em 5, **zero descansos seguidos**, e ele volta a caminhar e a ficar ocioso normalmente. Energia baixa aumenta a tendência sem congelar o personagem, e **nunca** interrompe ou rouba o destino de uma refeição ou treino em andamento.

### Cinco microcomportamentos ociosos

Dentro de `IDLE`, Caramelo alterna entre cinco poses curtas (1,2 a 2,6 s cada):

| Comportamento | O que faz |
| ------------- | --------- |
| `LOOK_AROUND` | Vira a cabeça devagar de um lado a outro |
| `STRETCH` | Alonga o corpo para a frente e abaixa a frente |
| `SNIFF_GROUND` | Abaixa o focinho até o chão e fareja |
| `TAIL_WAG` | Abana o rabo rápido, com um leve requebrado |
| `CHASE_FLY` | Pula atrás de uma mosca imaginária |

**Não são estados públicos:** não entram na matriz de transições, não alteram atributo algum, não reservam atividade e não aparecem fora de `IDLE`. Uma atividade aceita encerra o microcomportamento na hora.

Eles cobrem quatro dos cinco comportamentos autônomos do `MVP_SPEC.md` §9 — sentar e observar, alongar-se, farejar e perseguir a mosca. O quinto da spec, *caminhar até um ponto aleatório*, já é o estado `WALKING`; `TAIL_WAG` entrou no lugar dele como quinta pose parada.

`CHASE_FLY` desloca **apenas o nó visual**, em poucos pixels: a posição lógica de Caramelo não muda, então ele nunca sai da área caminhável por causa disso.

O mesmo comportamento nunca é escolhido duas vezes seguidas — e a regra vale também entre duas ociosidades separadas por uma caminhada. O sorteio usa o gerador próprio de Caramelo, então uma semente fixa reproduz a sequência inteira.

```gdscript
signal idle_behavior_changed(previous_behavior: int, new_behavior: int)
```

É informativo: sai também ao entrar e sair de `IDLE`, com `IdleBehavior.NONE` de um dos lados, e não move jogabilidade alguma.

### Visual do descanso

Corpo achatado no chão, respiração ampla e lenta, cabeça baixa e **olho quase fechado**. Intensidade deliberadamente baixa: o jogo passa horas visível como papel de parede. A recuperação de energia não depende da animação estar à vista — ela acontece na simulação, não no desenho.

### Sinais e sua ordem

```gdscript
signal rest_requested()
signal rest_rejected(reason: int)
signal rest_started()
signal rest_energy_restored(amount: int)
signal rest_completed()
```

Ordem efetiva de um ponto recuperado:

```text
state_changed(… → RESTING)
rest_started                      uma vez por entrada
  … 60 s acumulados …
energy_changed                    do modelo
rest_energy_restored              do sistema, só quando a energia realmente sobe
  … ao sair …
state_changed(RESTING → IDLE)
rest_completed                    uma vez por saída
```

`rest_requested` sai **apenas** no pedido explícito. O descanso autônomo emite `rest_started` e `rest_completed`, mas nunca `rest_requested`.

### Códigos de rejeição

Enum `RestSystem.Rejection`, estável:

| Código | Quando |
| ------ | ------ |
| `NOT_CONFIGURED` | dependências ainda não entregues |
| `POINT_NOT_FOUND` | `RestPoint` ausente da cena |
| `DOG_BUSY` | Caramelo em `EATING` ou `TRAINING` |
| `ACTIVITY_RESERVED` | já há refeição, treino ou descanso reservado |
| `DOG_REFUSED` | Caramelo recusou por outro motivo |

A exclusão mútua continua baseada na **reserva única de Caramelo**: `RestSystem`, `FeedingSystem` e `ExerciseSystem` não se conhecem.

## Interface principal

O HUD reúne o que as etapas anteriores construíram: consultar os quatro atributos, ver o que Caramelo está fazendo e disparar as três atividades — tudo em no máximo três cliques.

Fica **oculto por padrão** e aparece ao clicar em Caramelo, como pede o `MVP_SPEC.md` §18. Fechado, não intercepta clique nenhum: o pote e os equipamentos continuam respondendo normalmente.

### Estrutura

```text
MainHUD                  (Control, canto inferior esquerdo)
├── Anchor
│   ├── Panel
│   │   └── Layout
│   │       ├── Header            "Caramelo"
│   │       ├── Level             "Nível 1"
│   │       ├── Energy            "Energia 70/100" + barra
│   │       ├── Strength          "Força 40" + "Próximo nível: 40/70"
│   │       ├── Bond              "Vínculo 8" + "Próxima reação: 8/10"
│   │       ├── CurrentActivity   "Ocioso"
│   │       └── ActionBar         Alimentar · Treinar · Descansar · Carinho
│   └── ContextContainer          marca onde os menus se encaixam
└── Toast                         mensagem curta, no topo
```

O painel mora no canto inferior esquerdo justamente para **não cobrir Caramelo**, que anda pelo centro e pela direita do quintal. Os menus contextuais abrem encostados na borda superior do painel.

No nível 5 a linha de força vira `Nível máximo`; passado o último limiar de vínculo, a de vínculo vira `Todas as reações liberadas`. Os limiares vêm da configuração, nunca de constantes.

### Atividade atual

O texto **não sai só do estado** — uma caminhada dirigida diz para onde vai, consultando a reserva de Caramelo:

| Situação | Texto |
| -------- | ----- |
| `IDLE` | Ocioso |
| `WALKING` sem reserva | Passeando |
| `WALKING` + reserva de comida | Indo comer |
| `WALKING` + reserva de treino | Indo treinar |
| `WALKING` + reserva de descanso | Indo descansar |
| `EATING` | Comendo |
| `TRAINING` com `push_ups` | Fazendo flexões |
| `TRAINING` com `dumbbells` | Treinando com halteres |
| `RESTING` | Descansando |
| `HAPPY` | Feliz |

### Fluxos, em cliques

| Ação | Cliques |
| ---- | ------: |
| Alimentar | 3 — Caramelo → `Alimentar` → alimento |
| Treinar | 3 — Caramelo → `Treinar` → exercício |
| Descansar | 2 — Caramelo → `Descansar` |
| Alimentar pelo atalho | 2 — pote → alimento |
| Treinar pelo atalho | 1 — equipamento |

O pote e os hotspots continuam funcionando exatamente como antes: o HUD é um caminho a mais, não um substituto.

**A interface nunca aplica nada.** Os botões chamam `FeedingSystem.request_feeding`, `ExerciseSystem.request_exercise` e `RestSystem.request_rest`; quem aplica energia, força e vínculo são os sistemas. Nenhum script de UI chama um mutador do modelo — há um teste que lê o código-fonte para garantir isso.

### Menu de exercícios

Lista os dois exercícios com custo e ganho vindos de `data/exercises.json`. Um exercício indisponível fica desabilitado **e diz por quê**, em texto — o bloqueio nunca é indicado só por cor:

```text
Flexões     15 energia  →  +5 força
Halteres    25 energia  →  +9 força  ·  bloqueado até o nível 3
```

Ele se atualiza por `level_changed` e `energy_changed`, então os halteres liberam **com o menu aberto**, sem reabrir a cena.

### Estados dos botões

* **Alimentar** e **Treinar** seguem habilitados mesmo com tudo bloqueado: abrir o menu é como o jogador descobre os tempos de recarga e os níveis exigidos.
* **Descansar** desabilita quando há atividade reservada ou Caramelo está em `EATING`/`TRAINING`, com o motivo no tooltip. Energia cheia não bloqueia — descansar também é comportamento visual.

### Menus contextuais e recolhimento

Só um menu aberto por vez: abrir treino fecha alimentação e vice-versa; fechar o HUD fecha os dois. **Escape** fecha primeiro o menu contextual e, se nenhum estiver aberto, o HUD. Nenhum menu pausa o jogo.

O HUD recolhe sozinho depois de **8 segundos** sem uso (`COLLAPSE_SECONDS`, comportamento de interface, não balanceamento). O contador reinicia ao selecionar Caramelo, apertar um botão, abrir um menu, passar o ponteiro sobre o HUD ou dar foco a um controle.

Não recolhe enquanto: um menu contextual estiver aberto, o ponteiro estiver sobre o HUD, um controle do HUD tiver o foco, ou um toast ainda estiver na tela.

`MainHUD.simulate(delta)` avança o recolhimento e o toast. A execução normal chama por `_process`; os testes adiantam os oito segundos instantaneamente.

### Toasts

Uma faixa curta no topo, que some sozinha em ~3 s e **não intercepta cliques**. Uma mensagem nova substitui a anterior; elas nunca se empilham.

Os sistemas continuam devolvendo **códigos estáveis**; a interface é que os traduz:

| Código | Mensagem |
| ------ | -------- |
| `ON_COOLDOWN` | Esse alimento ainda está descansando. |
| `LOCKED` | Halteres liberados no nível 3. |
| `INSUFFICIENT_ENERGY` | Energia insuficiente. |
| `DOG_BUSY`, `ACTIVITY_RESERVED` | Caramelo está ocupado. |

Também aparecem confirmações reais — `+20 energia  +1 vínculo`, `−15 energia`, `+5 força`, `Nível 3!`, `Descanso iniciado.` — sempre com os valores **efetivamente aplicados** pelos sistemas.

### Atualização por sinais

O HUD faz uma leitura completa ao abrir e, daí em diante, **só reage a sinais**. Não há consulta por quadro: `_process` apenas avança temporizadores.

| Origem | Sinais | O que atualiza |
| ------ | ------ | -------------- |
| `Caramelo` | `selected`, `state_changed`, `activity_started`, `activity_completed` | abertura, atividade, botões |
| `ProgressionModel` | `energy_changed`, `strength_changed`, `bond_changed`, `level_changed`, `unlock_granted` | atributos, botões, toast |
| `FeedingSystem` | `feeding_completed`, `feeding_rejected`, `cooldown_changed`, `bowl_selected` | toast, botões |
| `ExerciseSystem` | `exercise_started`, `exercise_completed`, `exercise_rejected` | toast |
| `RestSystem` | `rest_started`, `rest_completed`, `rest_rejected` | atividade, botões, toast |

Todas as conexões passam por um guarda contra duplicata, então religar o HUD não faz nada acontecer duas vezes.

### Seleção de Caramelo

Caramelo ganhou uma `SelectionArea` de 152 × 96 que acompanha o corpo e **espelha junto com a direção**. Clicar nela emite `selected` — e só isso: selecionar não interrompe atividade, não altera estado e funciona também durante `EATING` e `TRAINING`, para consulta.

O controlador **não conhece a interface**: ele avisa que foi selecionado e quem escuta decide.

### Teclado e acessibilidade básica

Enter ou espaço ativam o controle em foco, Tab percorre os botões na ordem em que aparecem, e Escape fecha. Os botões têm texto completo (não só ícones), tooltips curtos, altura mínima de 32 px e estados desabilitados que dizem o motivo em palavras.

### Responsividade

Toda a interface usa a mesma compensação de escala, agora extraída para [`UiScale`](scripts/ui/ui_scale.gd) e compartilhada pelos quatro scripts de UI — antes ela estava duplicada entre o menu de alimentos e o feedback de treino.

Medido em janelas reais: o painel mantém **264 × ~255 px de tela** em 1850 × 950, 1280 × 720, 1024 × 768 e 640 × 950 — quatro escalas de canvas diferentes (1,137 a 3,0). Em todas, HUD e menu ficam inteiros dentro da tela e não se sobrepõem.

## Evolução visual e vínculo

Treinar muda o corpo de Caramelo; conviver com ele muda o jeito que ele responde. São as duas recompensas visuais do MVP — e **nenhuma das duas dá atributo, item ou moeda**.

### As duas formas

O `MVP_SPEC.md` §15 fixa **exatamente duas formas**. O nível 5 não cria uma terceira: ele reaproveita a musculosa.

| | Inicial | Musculosa |
| --- | --- | --- |
| Níveis | 1, 2 e 3 | 4 e 5 |
| Tronco | 78 × 43 px | 98 × 49 px |
| Barriga | 56 × 20 px | 61 × 22 px |
| Pata dianteira | 14 px de largura | 20 px |
| Pata traseira | 15 px de largura | 17 px |
| Sombra | 85 px | 93 px |
| Cápsula de colisão | raio 17, altura 66 | raio 20, altura 73 |
| Área de seleção | 129 × 82 px | 141 × 88 px |

O que muda é peito, ombro, espessura das patas e postura. O que **não** muda é a identidade: a cor caramelo, a cabeça inteira — crânio, focinho, nariz, olho e orelhas —, a cauda e a coleira vermelha são os mesmos polígonos nas duas formas. Os testes comparam esses nós ponto a ponto.

As duas geometrias moram juntas em [`scripts/dog/body_forms.gd`](scripts/dog/body_forms.gd), como **dado**: nenhuma parte do desenho consulta nível: o visual troca o conjunto inteiro de uma vez.

### Quando a forma troca

```text
força → nível → forma
```

A força é a única coisa persistida; o nível é derivado dela e a forma é derivada do nível, por `BodyForms.form_for_level()`. **A forma nunca vai para o save** — guardá-la criaria uma segunda fonte de verdade capaz de divergir da força.

A transformação em si acontece uma vez, ao cruzar o limiar de 140 de força:

* Dura **1,4 s**, interpolando cada polígono entre as duas geometrias.
* A **posição lógica não muda** — nem no começo, nem no fim. Só a geometria desenhada e as duas caixas.
* A cápsula de colisão e a área de seleção acompanham a nova silhueta, de modo que clicar nele continua funcionando.
* Carregar um save de nível 4 ou 5 aplica a forma **em silêncio**, sem animação e sem repetir a comemoração.

### Eventos por nível

| Nível | Evento | O que acontece |
| --- | --- | --- |
| 2 | Comemoração | 1,8 s de pulo curto e rabo acelerado |
| 3 | — | nenhum evento visual; o nível só libera os halteres |
| 4 | Transformação | 1,4 s de mudança de forma |
| 5 | Pose final | 1,8 s de pose, com a forma musculosa |

Cada evento acontece **uma única vez**, mesmo que a força suba de 0 a 250 num único golpe de restauração: os eventos entram numa fila sem duplicatas.

### Comportamentos de vínculo

Os três comportamentos do `MVP_SPEC.md` §11 chegam por limiares de vínculo, vindos de `data/levels.json`:

| Vínculo | Comportamento |
| --- | --- |
| 10 | reação especial ao carinho, no lugar da reação simples |
| 25 | comemoração ao abrir o jogo, uma vez por sessão |
| 50 | animação afetiva rara, com 10% de chance a cada carinho |

Abaixo de 10 o carinho ainda tem resposta — a reação simples —, porque o `MVP_SPEC.md` §11 não admite interação sem retorno.

### Carinho

Dois cliques: um em Caramelo para abrir o HUD, outro em **Carinho**.

* Cada carinho aceito dá **+1 de vínculo** e nada mais: energia e força não se movem.
* Depois dele começa uma recarga de **60 s**, e é ela que impede o spam. O botão desabilita e o tooltip mostra o tempo restante, no formato `0:47`.
* O ganho, a recarga e a chance da reação rara vêm do bloco `affection` de `data/levels.json`. Não há número de carinho no código.

Quando o pedido não pode ser atendido, ele é **recusado com motivo** — nunca enfileirado para depois:

| Situação | Motivo | Mensagem |
| --- | --- | --- |
| Recarga em andamento | `ON_COOLDOWN` | Carinho disponível em 0:47. |
| Comendo ou treinando | `DOG_BUSY` | Caramelo está ocupado. |
| A caminho de uma atividade | `ACTIVITY_RESERVED` | Caramelo está ocupado. |
| Transformação ou comemoração na tela | `EVOLUTION_IN_PROGRESS` | Caramelo está ocupado. |
| Sessão ainda abrindo | `SESSION_NOT_READY` | Não dá para fazer carinho agora. |
| Resumo offline aberto | `INTERACTION_BLOCKED` | Não dá para fazer carinho agora. |

**Descansar e passear aceitam carinho.** Ele reage sem sair do lugar: o descanso continua contando e a caminhada mantém o destino lógico. Só `EATING` e `TRAINING` recusam, como manda a matriz de estados — que **não foi alterada** para acomodar animação nenhuma.

### A fila de apresentações

Transformação, comemorações e reações afetivas são **apresentações**: acontecem numa camada visual, sem estado público, sem reserva de atividade e sem tocar em atributo.

Quando um evento nasce com Caramelo ocupado, ele espera numa fila com prioridade fixa:

```text
1. transformação do nível 4
2. pose do nível 5
3. comemoração do nível 2
4. comemoração de sessão (vínculo 25)
5. reação rara (vínculo 50)
6. reação especial (vínculo 10)
7. reação simples
```

A atividade em andamento vem antes de tudo isso: a fila só é consumida quando Caramelo está interrompível e sem reserva. Um mesmo evento nunca entra duas vezes.

## Salvamento e progresso offline

O progresso sobrevive ao fechamento do processo, e o tempo em que o jogo ficou fechado é reconciliado na abertura seguinte — sem nunca pagar a mesma recompensa duas vezes.

### Onde fica

```text
user://savegame.json           save principal
user://savegame.backup.json    cópia do principal anterior
user://savegame.tmp.json       temporário, existe só durante a escrita
user://savegame.rejected.json  cópia de um save ilegível ou de versão futura
```

Sempre em `user://`, **nunca** no diretório do executável nem em `res://`, como pede o `MVP_SPEC.md` §16: mover ou desinstalar o jogo não apaga o progresso, e a versão portátil funciona igual. O formato é JSON legível, sem criptografia nem ofuscação — não há competição no MVP. O conteúdo do arquivo é **dado**, nunca executado.

### Schema versão 2

```jsonc
{
  "schema_version": 2,
  "saved_at_unix": 1758000000,
  "progression": { "energy": 70, "strength": 0, "bond": 0 },
  "food_cooldowns": { "kibble": 212.5 },
  "rest": { "accumulated_seconds": 41.25 },
  "affection": { "cooldown_remaining": 38.5 },   // desde a versão 2
  "dog": { "position": { "x": 880.0, "y": 860.0 }, "facing": 1 },
  "activity": {
    "type": "exercise",            // feeding | exercise | rest
    "phase": "running",            // reserved | walking | running
    "content_id": "push_ups",
    "remaining_seconds": 18.0,
    "energy_already_spent": true,
    "reward_already_applied": false,
    "target_id": "PushUpsPoint"
  }
}
```

**O que não é persistido, de propósito:** `level`, a forma corporal e a lista de desbloqueios. Os três são derivados da força; guardá-los criaria uma segunda fonte de verdade capaz de divergir do save. Também ficam de fora o deslocamento visual, a fase da respiração, o microcomportamento ocioso, a fila de apresentações e qualquer referência a nó, sinal ou `Callable`.

A recarga do carinho, essa sim, é gravada: ela é estado do jogo, não enfeite. Fechar e reabrir não devolve o carinho antes da hora.

### Migração v1 → v2

A versão 1 não tinha o bloco `affection`. Um save escrito por ela é aceito e atualizado na abertura:

1. O save é **validado na versão em que está** — um v1 quebrado é recusado como v1, antes de qualquer mudança.
2. `affection.cooldown_remaining` é criado zerado: quem volta de uma versão antiga pode fazer carinho na hora.
3. `schema_version` passa a 2 e o jogo grava o arquivo já migrado, disparando `save_migrated`.

Migrar é **idempotente**: um save que já está em v2 passa direto, sem reescrita. Um backup em v1 também é migrado quando é ele que sobra. Nada mais muda — atributos, recargas de comida, acumulador de descanso, posição e atividade em andamento atravessam a migração intactos.

Campos desconhecidos são **ignorados**, para que um save escrito por uma versão futura menor ainda carregue. Um `schema_version` maior que o suportado continua **recusado e preservado**: o arquivo é copiado para `savegame.rejected.json` antes que qualquer escrita aconteça, nunca destruído.

### Escrita atômica

```text
1. montar snapshot        5. preservar o principal anterior como backup
2. validar                6. promover o temporário a principal
3. escrever o temporário  7. reler o principal final e validar
4. reler e revalidar
```

**Nunca faltam as duas cópias ao mesmo tempo.** Se qualquer passo falhar, o último save válido continua no lugar, o temporário é removido e sai um erro claro — sem encerrar o jogo. Uma falha de autosave deixa o estado marcado como sujo, para tentar de novo.

### Recuperação

| Situação | O que acontece |
| -------- | -------------- |
| Principal válido | usado |
| Principal ausente | jogo novo (ou backup, se houver) |
| Principal ilegível, backup válido | **backup recuperado**, com linha no resumo |
| Backup ilegível, principal válido | ignorado; o principal segue normal |
| Ambos ilegíveis | jogo novo, com aviso não bloqueante |
| Versão futura | recusado; arquivo preservado em `.rejected.json` |
| Temporário abandonado | ignorado; nunca é promovido sozinho |

### Gatilhos de salvamento

Refeição concluída · início de treino (**depois** do débito) · treino concluído · descanso que realmente recuperou energia · subida de nível · recarga de comida que chegou a zero · carinho concluído · recarga do carinho que chegou a zero · migração de v1 para v2 · reconciliação offline · autosave periódico · fechamento da janela.

```text
debounce: 0,5 s     autosave periódico: 30 s
```

Cada gatilho apenas **marca** o estado como sujo; o `SaveManager` agrupa os próximos e escreve uma vez. É o que impede as recargas, que mudam a cada segundo, de virarem escrita a cada segundo — a do carinho grava quando é concedido e quando chega a zero, nunca no meio. O fechamento força a escrita ignorando o debounce — mas o jogo não depende disso: o autosave já garante o essencial.

### Relógio e teto

```text
raw_elapsed = now_unix − saved_at_unix     (Unix UTC)
```

| Caso | Resultado |
| ---- | --------- |
| `raw_elapsed <= 0` | zero progresso e **zero punição** |
| Relógio regressivo | idem, com mensagem própria no resumo |
| Até 8 h | aplicado integralmente |
| Mais de 8 h | aplicado exatamente **28 800 s** |
| Timestamp inválido | snapshot recusado |

[`OfflineProgress`](scripts/systems/offline_progress.gd) é **pura**: recebe `now_unix` por parâmetro e não abre arquivo, não consulta o relógio e não conhece cena alguma. Há um teste que lê o código-fonte para garantir.

### Ordem do cálculo offline

```text
1. tempo válido, limitado a 8 h        6. se terminou, o resto vira descanso
2. restaurar o snapshot em memória     7. sem atividade, todo o tempo é descanso
3. reduzir as recargas existentes      8. produzir o relatório
4. cancelar atividade só reservada     9. atualizar o timestamp
5. resolver atividade já iniciada     10. gravar o estado reconciliado
```

O passo 10 é o que impede a duplicação: uma segunda abertura já encontra o estado reconciliado.

### Alimentação offline

* **Reservada ou a caminho** — cancelada. Nenhuma energia, nenhum vínculo, nenhuma recarga.
* **`EATING` incompleto** — só o tempo restante é reduzido; Caramelo volta ao `FoodPoint` já comendo, sem repetir a caminhada, sem recompensa e sem recarga.
* **`EATING` concluído** — energia e vínculo uma única vez, a recarga começa **no momento lógico da conclusão** e corre só pelo tempo posterior a ela, e o que sobra vira descanso.

Com energia cheia: a energia aplicada pode ser zero, mas o vínculo ainda sobe, a recarga ainda começa e a refeição ainda conta como concluída.

### Treino offline

* **Reservado ou a caminho** — cancelado, sem débito e sem força.
* **`TRAINING` incompleto** — retoma no ponto do exercício com o tempo restante. **A energia não é debitada de novo**: ela saiu ao entrar em `TRAINING`, antes de o jogo fechar.
* **`TRAINING` concluído** — força uma única vez, nível e desbloqueios recalculados, e o resto do tempo vira descanso.

Um snapshot que diga `phase: "running"` com `energy_already_spent: false` é **incoerente e recusado** — seria um treino de graça.

### Descanso e recargas offline

A taxa é a mesma do jogo aberto: **1 energia por 60 s**, vinda de `data/levels.json`. O acumulador fracionário salvo entra no cálculo (`30 s guardados + 30 s de ausência = +1`), só unidades inteiras são aplicadas, o novo resto é preservado, a energia respeita o teto e o excedente após a saturação é descartado. Descanso não mexe em força nem em vínculo.

Recargas existentes correm por toda a ausência (`max(0, restante − elapsed)`), nunca ficam negativas e uma não afeta a outra. A interface recebe apenas o estado final reconciliado, não uma enxurrada de sinais por segundo.

### Retomada de atividade

Na abertura, uma atividade incompleta é recolocada pelas APIs explícitas `Caramelo.restore_activity`, `FeedingSystem.restore_pending_meal` e `ExerciseSystem.restore_pending_exercise` — nenhuma variável privada é forçada de fora. `activity_started` **não** é reemitido, justamente para que o sistema não cobre a energia outra vez; a conclusão sai normalmente quando o tempo acabar em runtime.

A posição salva é validada contra o polígono caminhável. Se cair fora, Caramelo vai para um ponto seguro — o polígono nunca é afrouxado para aceitar um save ruim. Quando há atividade retomada, vale o ponto do equipamento, não a posição salva.

### Resumo "Enquanto você esteve fora"

O painel aparece centralizado, bloqueia cliques no mundo enquanto aberto (sem pausar o jogo) e some com um botão claro. Ele **não aparece** em jogo novo nem quando a ausência não produziu nenhum evento.

Mostra apenas fatos reais — um ganho zero nunca vira linha:

```text
Você ficou fora por 2h 15min.
Caramelo recuperou 70 de energia.
Caramelo terminou de comer Racao e ganhou 1 de vínculo.
Caramelo terminou o exercício Flexoes e ganhou 5 de força.
2 alimentos ficaram disponíveis novamente.
O relógio do sistema retrocedeu; nenhum progresso offline foi aplicado.
O save principal não pôde ser lido. O backup foi recuperado.
```

`OfflineProgress` devolve um relatório **estruturado**; quem escolhe as palavras é a interface.

### Ordem de inicialização

Tudo acontece dentro do `_ready` da sessão, antes do primeiro quadro — a interface nunca chega a mostrar valores iniciais falsos:

```text
1. carregar configuração   5. restaurar ou cancelar a atividade
2. carregar principal      6. aplicar a forma do nível, em silêncio
   ou backup, migrando     7. ligar o autosave
   de v1 se preciso        8. anunciar `session_ready`
3. validar o snapshot      9. gravar o estado reconciliado
4. reconciliar o tempo
```

Os sistemas só são configurados depois da carga, então antes de `session_ready` nenhum pedido é aceito: o pote, os hotspots e os botões do HUD recusam com `NOT_CONFIGURED`, e o carinho recusa com `SESSION_NOT_READY`.

A forma é aplicada no passo 6 **sem animação e sem evento**: quem volta no nível 4 encontra o corpo musculoso já em cena, não assiste à transformação de novo. Pela mesma razão a fila de apresentações começa vazia.

### Recuperação manual

O save é JSON legível. Se o principal quebrar, basta copiar `savegame.backup.json` por cima de `savegame.json` no diretório de dados do usuário. Um save recusado por versão futura fica em `savegame.rejected.json` e pode ser guardado até a versão nova do jogo chegar.

## Estrutura da cena principal

```text
Main                    (Node)
├── GameSession         (Node)        ← configuração, modelo e resolução de referências
│   ├── FeedingSystem   (Node)        ← refeição: pedido, recompensa e recargas
│   ├── ExerciseSystem  (Node)        ← treino: pedido, débito, recompensa e reação
│   ├── RestSystem      (Node)        ← descanso: recuperação e tendência autônoma
│   ├── EvolutionSystem (Node)        ← forma corporal e fila de apresentações
│   ├── AffectionSystem (Node)        ← carinho, recarga e comportamentos de vínculo
│   └── SaveManager     (Node)        ← snapshot, escrita atômica e recuperação
├── World               (Node2D)
│   └── Backyard        (instância de backyard.tscn)
│       ├── Background        (Sprite2D)     z = -100
│       ├── WorldBounds       (Area2D)
│       │   └── WalkableCollision  (CollisionPolygon2D)
│       ├── InteractionPoints (Node2D)
│       │   ├── FoodPoint       (Marker2D)  (941.6, 792.1)
│       │   ├── PushUpsPoint    (Marker2D)  (1580, 845)
│       │   ├── DumbbellsPoint  (Marker2D)  (620, 770)
│       │   └── RestPoint       (Marker2D)  (1217.2, 734.6)
│       ├── CharacterLayer    (Node2D)       z = 0, y_sort_enabled
│       │   └── Caramelo      (instância de caramelo.tscn, em (880, 860))
│       ├── PropsLayer        (Node2D)       z = 10
│       │   ├── FoodBowl          (instância de food_bowl.tscn, em (987.6, 820.1))
│       │   ├── PushUpsHotspot    (instância de equipment_hotspot.tscn)
│       │   └── DumbbellsHotspot  (instância de equipment_hotspot.tscn)
│       └── ForegroundLayer   (Node2D)       z = 20
└── Interface           (CanvasLayer, camada 1) — tudo oculto por padrão
    ├── FoodMenu         (instância de food_menu.tscn)
    ├── ExerciseMenu     (instância de exercise_menu.tscn)
    ├── TrainingFeedback (instância de training_feedback.tscn)
    ├── MainHUD          (instância de main_hud.tscn)
    └── OfflineSummary   (instância de offline_summary.tscn)
```

`GameSession` é o primeiro filho de `Main`, antes de `World`: ela carrega a configuração no `_ready` e o resto da cena pode contar com o modelo já pronto.

O `ColorRect` provisório da Etapa 2 foi removido da cena principal depois que o fundo definitivo foi validado. O papel conceitual de `Background` passou para dentro de `backyard.tscn`, junto com o resto do cenário — manter um segundo fundo em `main.tscn` duplicaria a responsabilidade sem nenhum ganho.

`Interface` é um `CanvasLayer` de camada 1. Como o cenário vive na camada 0, a interface fica garantidamente acima dele. Até a Etapa 5 ela estava vazia; agora hospeda o menu de alimentos, que continua oculto por padrão.

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

São oito suítes permanentes, todas sem janela e sem nenhum framework externo. Cada uma sai com código `0` quando tudo passa e `1` caso contrário, imprimindo cada verificação.

```bash
# controlador de Caramelo — 69 verificações
godot --headless --path . --script tests/test_caramelo_controller.gd

# configuração, atributos e progressão — 187 verificações
godot --headless --path . --script tests/test_progression.gd

# sistema de alimentação e exclusão mútua — 129 verificações
godot --headless --path . --script tests/test_feeding_system.gd

# sistema de exercícios — 141 verificações
godot --headless --path . --script tests/test_exercise_system.gd

# descanso e comportamento ocioso — 127 verificações
godot --headless --path . --script tests/test_rest_and_idle.gd

# HUD principal e menus contextuais — 103 verificações
godot --headless --path . --script tests/test_main_ui.gd

# salvamento e progresso offline — 185 verificações
godot --headless --path . --script tests/test_save_and_offline.gd

# evolução visual e vínculo — 167 verificações
godot --headless --path . --script tests/test_evolution_and_affection.gd
```

Cada suíte trabalha num **diretório de save isolado** dentro de `user://`, apagado ao final: nenhuma delas encosta no save real nem na outra.

**`test_caramelo_controller.gd`** cobre estado inicial, existência dos seis estados, transições válidas e inválidas, reentrada, não interrupção de `EATING` e `TRAINING`, descarte de comandos, sinais, destinos e trajetos dentro do polígono, parada no destino, reprodutibilidade por semente, acompanhamento da transformação do quintal e unicidade de Caramelo na cena principal.

**`test_progression.gd`** cobre a existência e validade dos três JSON, campos obrigatórios, unicidade de IDs, limiares crescentes, relações entre arquivos, **22 formas diferentes de configuração inválida**, os limites e a atomicidade da energia, os cinco níveis, os desbloqueios de vínculo, valores e ordem dos sinais, a posse do modelo pela `GameSession`, o desacoplamento entre Caramelo e o modelo, e a aritmética da progressão.

**`test_feeding_system.gd`** cobre o pedido e as seis formas de recusa, o direcionamento ao `FoodPoint`, a recompensa só na conclusão e exatamente uma vez, sinais duplicados, conclusões de outra atividade, o teto de energia, a ordem obrigatória dos efeitos, recargas independentes vindas do JSON, a frequência de `cooldown_changed`, `activity_completed`, o pote e o menu na cena, e a ausência de recompensa sem ação do jogador.

**`test_exercise_system.gd`** cobre os dois exercícios e seus números vindos do JSON, os dois pontos distintos e a ausência do marcador antigo, os hotspots, o bloqueio por nível nos níveis 1, 2 e 3, as dez formas de recusa, o débito só na entrada e uma única vez, a falha defensiva de débito, as durações de 20 s e 30 s simuladas, a recompensa só na conclusão e uma única vez, a subida de nível pelo próprio treino, a exclusão mútua nos dois sentidos, a reação cômica com semente fixa e as poses distintas com o halter provisório.

**`test_rest_and_idle.gd`** cobre a seção `rest` e onze formas de configuração inválida, o acumulador fracionário (59 s nada, o segundo restante +1, descansos separados somando), a ausência de recuperação nos outros cinco estados, deltas inválidos, saturação sem crédito oculto, o descanso solicitado com suas cinco recusas, a tendência crescente por faixa de energia, a garantia de não encadear descansos, os cinco microcomportamentos com sorteio reprodutível e o deslocamento apenas visual de `CHASE_FLY`.

**`test_main_ui.gd`** cobre o HUD único e oculto, a abertura por seleção sem alterar nada, a ausência de conexões duplicadas, os quatro atributos e seus textos derivados da configuração, os dez textos de atividade, os três fluxos em cliques, o menu de exercícios com bloqueio por nível e por energia, os atalhos do pote e dos hotspots, a exclusividade dos menus, o recolhimento por tempo simulado, o Escape em duas etapas, o toast e a garantia de que nenhum script de UI chama mutador do modelo.

**`test_evolution_and_affection.gd`** cobre as duas formas e a derivação a partir do nível, a identidade preservada ponto a ponto, as caixas de colisão e seleção acompanhando a silhueta, os eventos dos níveis 2, 4 e 5 com adiamento e sem duplicata, a carga silenciosa de um nível alto, o carinho com seus sete motivos de recusa, os três comportamentos de vínculo, a comemoração de sessão uma vez só, a animação rara com semente fixa, o schema 2, a migração de um principal e de um backup em v1, a recusa que preserva o arquivo byte a byte, a recarga que corre offline, a reabertura sem vínculo duplicado nem evento repetido, o botão do HUD em dois cliques e a regressão das três atividades nas duas formas.

**`test_save_and_offline.gd`** cobre o schema e dezesseis formas de snapshot inválido, a escrita atômica com falhas simuladas por um adaptador de arquivos, a política de backup e de recuperação, as regras do relógio com `now_unix` injetado, a reconciliação de alimentação e treino em cada fase, o descanso com acumulador, as recargas, a retomada de atividade incompleta e os gatilhos de autosave com debounce.

Os casos negativos de configuração montam dados errados **em memória** ou escrevem em `user://`. Os arquivos reais de `data/` nunca são tocados.

O tempo nunca é esperado de verdade: as suítes chamam `Caramelo.simulate(delta)` e `FeedingSystem.simulate(delta)` em laço, de modo que dez minutos de jogo — ou uma recarga de quinze — passam em milissegundos, com resultado determinístico.

### Aritmética verificada

A suíte de progressão confirma os números do `MVP_SPEC.md` §13 executando o modelo de verdade:

| Verificação | Resultado |
| ----------- | --------- |
| Sair do nível 1 só com flexões | 5 sessões, 25 de força, 75 de energia |
| Chegar ao nível 3 só com flexões | 14 sessões, 70 de força, 210 de energia |
| Halteres disponíveis | exatamente ao alcançar o nível 3 |
| Nível 5 só com flexões | 50 sessões, 750 de energia |
| Nenhuma sessão sobe dois níveis | maior ganho (+9) < menor intervalo (25), varrido para força 0–259 |
| Nível 5 exige | força total 250 |
| Nível máximo após continuar treinando | permanece 5 |
| Caminho recomendado completo | 35 sessões e 735 de energia |

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

### Alimentação

1. Clique no **pote azul**, à direita de onde Caramelo costuma parar. O menu abre embaixo.
2. Confirme os três alimentos com nome, energia e vínculo.
3. Escolha um. O menu fecha e Caramelo caminha até o pote.
4. Ele abaixa a cabeça e come por cerca de 4 s, depois comemora.
5. Clique no pote de novo: **só aquele alimento** aparece esmaecido, com o tempo restante (`volta em 4:59`). Os outros dois continuam habilitados.
6. Espere e confirme que o tempo desce e o botão volta a funcionar.

Sem clicar em nada, energia e vínculo ficam parados em 70 e 0 — nenhuma recompensa acontece sozinha.

O menu foi verificado em 1920 × 1080, 1280 × 720, 1024 × 768 e 640 × 1000: ele nunca sai da tela e mantém o mesmo tamanho físico (300 × ~245 px) em todas.

### Treino

1. No nível 1, passe o mouse pelas **barras de flexão** (direita): aparece `Flexões · 15 energia → +5 força` e um contorno claro no equipamento.
2. Passe pelos **halteres** (esquerda): `Halteres · bloqueado até o nível 3`.
3. Clique nas barras. Caramelo caminha até lá — **a energia não muda durante a caminhada**.
4. Ao chegar, a faixa mostra `−15 energia` e ele começa a abaixar e subir o corpo por 20 s.
5. Ao terminar, `Flexões concluído · +5 força`. A força só entra aqui.
6. Repita até o nível 3 e volte aos halteres: agora aceitam, ele caminha para a **esquerda**, assume postura erguida com um halter provisório e treina 30 s por +9.

Durante um treino, o pote recusa qualquer alimento, e vice-versa. Nenhum pedido recusado acontece depois.

Verificado em 1920 × 1080, 1280 × 720, 1024 × 768 e 640 × 1000: a faixa de feedback mantém ~277 × 37 px de tela e nunca sai do enquadramento.

### Salvamento entre processos

Além das suítes, o ciclo foi validado com **processos separados de verdade**, num diretório de dados isolado:

```text
1. abrir, alterar o estado, salvar, encerrar
2. reabrir  → energia, força, vínculo e nível restaurados
3. iniciar um treino, salvar, encerrar
4. recuar só o timestamp do save e reabrir
            → o treino conclui offline e a força entra uma vez
5. reabrir duas vezes  → a recompensa NÃO se repete
6. corromper o principal e reabrir  → recuperado pelo backup
7. recuar o timestamp em 20 h  → aplicadas exatamente 8 h
8. adiantar o timestamp  → zero progresso e zero punição
```

### Interface

1. **Clique em Caramelo.** O HUD aparece no canto inferior esquerdo, com nível, energia, força, vínculo e a atividade atual.
2. Deixe o ponteiro longe dele: em 8 segundos ele recolhe sozinho.
3. Abra de novo e clique em **Alimentar** — o menu abre encostado acima do painel. Clique em **Treinar**: o de alimentação fecha.
4. No nível 1, **Halteres** aparece esmaecido com "bloqueado até o nível 3", em texto e não só em cor.
5. Treine até o nível 3 com o menu aberto: os halteres liberam sem reabrir nada.
6. **Escape** fecha primeiro o menu; apertando de novo, fecha o HUD.
7. Peça algo impossível (comida em recarga, treino durante treino): a faixa no topo explica e some sozinha.
8. Enquanto um menu está aberto ou o ponteiro está sobre o painel, o HUD não recolhe.

### Evolução e carinho

```bash
godot --path . --resolution 1280x720 --position 60,60
```

1. **Forma inicial.** Ele começa fino, de pernas estreitas, com a coleira vermelha à mostra.
2. Treine até o nível 2: um pulo curto de comemoração, e a forma **não** muda.
3. Treine até o nível 3: os halteres liberam e ele continua na forma inicial.
4. **Nível 4.** No instante em que a força chega a 140, o corpo engrossa em pouco mais de um segundo, sem sair do lugar. Cabeça, cor e coleira continuam os mesmos.
5. Mande treinar de novo, e depois descansar: flexões, halteres, caminhada e descanso funcionam igual na forma nova.
6. **Nível 5.** Uma pose final, ainda na forma musculosa — não existe terceira.
7. Clique nele e depois em **Carinho**: ele reage, o vínculo sobe 1 e o botão desabilita por um minuto, mostrando o relógio no tooltip.
8. Clique em **Carinho** de novo antes da hora: a faixa no topo diz quando ele volta a ficar disponível, e o vínculo não se move.
9. Com o vínculo em 10 ou mais, a reação ao carinho fica mais efusiva. Em 50 ou mais, de vez em quando sai uma animação mais longa.
10. Peça um treino e clique em **Carinho** enquanto ele treina: o botão está desabilitado e o treino não é interrompido.
11. Feche e reabra o jogo logo depois de um carinho: a recarga continua de onde parou, e nenhuma comemoração se repete.

### Descanso e ociosidade

Deixe rodando alguns minutos, sem clicar em nada:

1. Parado, ele alterna entre os cinco microcomportamentos — olhar em volta, se alongar, farejar o chão, abanar o rabo e pular atrás de uma mosca. **Nunca repete o mesmo duas vezes seguidas.**
2. De tempos em tempos escolhe um ponto e caminha até lá, sem tremor.
3. De vez em quando deita: corpo achatado no chão, respiração lenta, olho quase fechado.
4. **A energia só sobe enquanto ele está deitado**, +1 por minuto. Em qualquer outro estado ela fica parada.
5. Depois de descansar ele sempre volta a caminhar — não encadeia descansos.
6. Alimente-o ou mande treinar: a atividade tem prioridade e o descanso nunca a interrompe.
7. Com a energia baixa, ele passa a escolher descansar com mais frequência, mas continua andando e fazendo as poses ociosas.

Verificado em 1920 × 1080, 1280 × 720, 1024 × 768 e 640 × 1000: ele deita no mesmo ponto, à frente da cadeira, e a energia sobe igual.

### Área caminhável

Com `--debug-collisions`, o polígono da área caminhável aparece desenhado sobre o piso, o que deixa ver que Caramelo nunca o atravessa:

```bash
godot --path . --resolution 1280x720 --position 60,60 --debug-collisions
```

O que conferir no cenário:

* O contorno acompanha o concreto e não invade telhado, céu, muros nem as plantas do primeiro plano.
* Ele encosta na base da parede do fundo, sem sobrar faixa de piso inalcançável.
* Redimensionando a janela, o contorno continua colado ao piso — ele escala junto com a arte.

## O que foi implementado nesta etapa

* `scripts/dog/body_forms.gd`: a geometria das duas formas, como dado, e a regra `form_for_level()`.
* `scripts/dog/caramelo_visual.gd`: a transformação de 1,4 s, as comemorações de nível e as reações afetivas.
* `scripts/dog/caramelo.gd`: `apply_body_form()`, `play_presentation()`, `is_presenting()` e o sinal `body_form_changed` — sem nenhum estado novo na matriz pública.
* `scripts/systems/evolution_system.gd`: a fila de apresentações com prioridade, sem duplicatas, consumida só com Caramelo livre.
* `scripts/systems/affection_system.gd`: o carinho, a recarga, os sete motivos de recusa e os três comportamentos de vínculo.
* `scripts/systems/save_manager.gd`: schema 2, `migrate()` de v1 para v2 e o sinal `save_migrated`.
* `scripts/systems/offline_progress.gd`: a recarga do carinho correndo durante a ausência.
* `scripts/systems/game_config.gd` + `data/levels.json`: o bloco `affection` — ganho, recarga e chance da reação rara.
* `scripts/ui/main_hud.gd` e `scenes/ui/main_hud.tscn`: o botão **Carinho**, o toast do ganho e o tooltip da recarga.
* `tests/test_evolution_and_affection.gd`: 167 verificações permanentes.

**Nenhum valor de balanceamento anterior foi tocado**: os números de `data/foods.json`, `data/exercises.json` e os blocos já existentes de `data/levels.json` estão byte a byte iguais — o arquivo só ganhou o bloco `affection`. O asset do quintal também segue intacto.

Sobre os arquivos de importação: `.godot/` (o cache gerado) permanece ignorado pelo Git, enquanto `assets/backgrounds/quintal_mvp.png.import` é versionado. Esse arquivo guarda o `uid://` do recurso e os parâmetros de importação; versioná-lo é a prática recomendada no Godot 4 e evita que a referência da cena mude a cada clone.

## Limitações conhecidas

* **`ForegroundLayer` está vazia.** A vegetação do primeiro plano faz parte da imagem de fundo, então ela é desenhada *atrás* de Caramelo. A área caminhável foi traçada acima dessa vegetação justamente para esconder o problema. Fazer Caramelo passar de fato atrás das folhas exigiria recortá-las da arte, o que não foi feito para preservar o asset original.
* **Sem mipmaps.** Em janelas bem menores que 1672 px de largura a redução usa filtragem linear simples. Gerar mipmaps é uma otimização possível para a Etapa 12.
* **Proporções extremas recortam muito.** Em 640 × 1000 sobram cerca de 35% da largura da arte. O recorte é centrado e previsível, mas boa parte do quintal fica fora da tela.
* **Consumo não foi medido.** A máquina de desenvolvimento usa renderização por software (Mesa llvmpipe), inadequada para aferir as metas de FPS e CPU da seção 20 do `MVP_SPEC.md`. Isso fica para a Etapa 12, junto com a definição do computador de referência (ponto em aberto A-1).

### Caramelo

* **A arte é provisória e feita de formas geométricas.** É reconhecível como um vira-lata caramelo, mas não tem a expressividade que o `MVP_SPEC.md` §15 pede.
* **As duas formas saem das mesmas primitivas.** A musculosa é a inicial com peito, ombro e patas maiores; não há pose nova, músculo desenhado nem veia saltada. É o suficiente para ler a evolução à distância, mas está longe do que o `MVP_SPEC.md` §15 pede da arte final.
* **As apresentações são curtas e discretas.** Comemoração, pose final e reações afetivas duram um ou dois segundos e reaproveitam o mesmo deslocamento de corpo e rabo. Sem partícula, sem confete, sem áudio.
* **O desvio de trajeto tem uma perna só.** Se nem a linha reta nem a rota pelo ponto interno servirem, o destino é recusado. Basta para este quintal, que é quase convexo (0,4% dos trajetos precisam do desvio), mas um cenário mais recortado exigiria outra solução.
* **Caramelo não desvia de objetos.** O `CharacterBody2D` tem cápsula de colisão e `velocity`, mas a posição é integrada diretamente em vez de `move_and_slide()` — não existe nada com que colidir, e `move_and_slide()` usaria o delta do motor, o que quebraria a simulação determinística dos testes. Quando existirem objetos com corpo, a troca é de uma linha.
* **Os hotspots e o pote não bloqueiam nada.** Suas `Area2D` servem só para o clique, com `monitoring` e `monitorable` desligados.
* **`HAPPY` continua sem efeito nos atributos**, como manda o `MVP_SPEC.md` §10: quem paga é a ação que causou a alegria.

### Alimentação

* **Nada é persistido.** As recargas correm só com o aplicativo aberto e zeram ao reabrir. O `MVP_SPEC.md` §12 exige que elas continuem correndo com o jogo fechado — isso é da Etapa 10.
* **O pote é o único elemento clicável do cenário**, como manda a §6. O restante é pintura de fundo.
* **Caramelo não vira para o pote ao comer.** Se ele chega vindo da direita, come de costas para a vasilha. A arte é provisória e a correção vem com os sprites reais.
* **Sem fila e sem cancelamento.** Depois de aceito, o pedido vai até o fim: `EATING` é não interrompível por especificação, e não há como desistir a caminho.
* **O menu não mostra energia nem vínculo atuais.** Ele lista só o que cada alimento dá. As barras permanentes são o HUD da Etapa 9.
* **Valores provisórios.** As recargas de 5, 15 e 10 min seguem pendentes de playtest (ponto em aberto A-2 do `MVP_SPEC.md`).

### Salvamento

* **Um único slot.** Sem importação, exportação, nuvem ou conta — está fora do escopo do MVP.
* **Sem criptografia nem anticheat.** O `MVP_SPEC.md` §16 pede formato legível; editar o JSON à mão funciona.
* **O resumo offline não é interativo.** Ele informa e fecha; não há como desfazer nem inspecionar detalhes.
* **A reconciliação assume a taxa de descanso atual.** Mudar `energy_per_minute` entre duas sessões faz o tempo já decorrido ser convertido pela taxa nova.
* **O relógio é o do sistema.** Não há verificação de tempo além das regras da §17 — adiantar o relógio rende, no máximo, as oito horas do teto.
* **`NOTIFICATION_WM_CLOSE_REQUEST` é o único gatilho de fechamento.** Um encerramento forçado (kill, queda de energia) perde o que estiver dentro da janela do autosave.

### Interface

* **Sem configurações, bandeja ou modo silencioso.** O `MVP_SPEC.md` §18 e §19 pedem uma engrenagem de opções e controles de pausa; isso é das Etapas 11 e 12.
* **O HUD não some sozinho durante uma atividade longa.** Ele recolhe por inatividade como em qualquer outro momento, então um treino de 30 s termina com o painel fechado se ninguém mexer.
* **Sem navegação completa por teclado.** Tab e Escape funcionam, mas não há atalhos para as ações nem foco inicial definido ao abrir.
* **Os menus contextuais abrem sempre acima do painel**, à esquerda. Em janelas muito baixas eles empilham para cima, sem reposicionamento inteligente.
* **A `SelectionArea` de Caramelo e os hotspots de equipamento podem se sobrepor** quando ele está treinando: o clique cai em um dos dois conforme a ordem do motor. Nenhum dos resultados é destrutivo.
* **`ContextContainer` é só um marcador de ancoragem.** Os menus continuam sendo cenas independentes em `Interface`, não filhos do painel.

### Descanso e ociosidade

* **Nada é persistido.** O acumulador fracionário e a energia vivem só nesta execução. O `MVP_SPEC.md` §17 exige recuperação também com o jogo fechado — isso é da Etapa 10.
* **Sem botão de descanso.** `request_rest()` existe e está testado, mas nenhuma interface o chama: o botão é do HUD da Etapa 9.
* **A taxa de 1/min nunca foi medida em uso real.** Continua sendo a suposição S-1; o ponto em aberto A-3 pede playtest.
* **A pose de descanso é a mesma em qualquer lugar.** Ele deita igual no `RestPoint` e onde estiver quando descansa sozinho — não há pose específica encostada na cadeira.
* **Os microcomportamentos são poses, não animações.** São funções contínuas do tempo sobre os mesmos polígonos, como o resto da arte provisória.
* **`CHASE_FLY` não tem mosca.** O deslocamento sugere a perseguição; não há objeto algum desenhado.

### Treino

* **A reação cômica reaproveita `HAPPY`.** É uma variação exagerada da mesma pose, não uma animação própria.
* **O halter provisório é geométrico**, como o resto de Caramelo, e só aparece durante o exercício dos halteres.
* **Sem cancelamento.** Depois de aceito, o treino vai até o fim: `TRAINING` é não interrompível por especificação.
* **A duração de `EATING` ainda é constante.** O mecanismo de duração por dado existe e o treino já o usa; a alimentação continua com os 4 s da Etapa 4, sem ler `animation_seconds` de `foods.json`.
* **Caramelo não vira para o equipamento.** Assim como no pote, a direção depende de por onde ele chegou.
* **O nível 2 não ganhou comemoração própria** e a forma musculosa do nível 4 continua fora, como manda o escopo.

### Atributos e progressão

* **Alimentação e treino alimentam o modelo.** O carinho continua sem efeito.
* **Nada é salvo.** Fechar o jogo descarta energia, força, vínculo, nível e recargas; não há persistência nem progresso offline.
* **Os desbloqueios não têm efeito visual.** `muscular_form`, `final_pose`, `level_2_celebration` e os três comportamentos de vínculo existem só como consulta.
* **A configuração é lida só na abertura.** Editar um JSON com o jogo rodando não muda nada; é preciso reabrir. Não há recarga em tempo de execução, por decisão de escopo.
* **`max_energy` é fixo em 100.** Vem dos dados, mas nada no MVP o altera.
* **Valores provisórios.** As recargas dos alimentos e a chance de reação cômica seguem pendentes de playtest (ponto em aberto A-2 do `MVP_SPEC.md`).

### Evolução e vínculo

* **A transformação é interpolação de polígono.** Cada ponto caminha em linha reta entre as duas geometrias por 1,4 s. Fica legível, mas não tem antecipação, elasticidade nem sombra acompanhando o esforço — nada do que um animador faria.
* **A reação rara não tem variação.** Sorteada, ela sempre executa a mesma animação. O `MVP_SPEC.md` §11 pede raridade, não variedade, mas com vínculo alto ela começa a se repetir.
* **A comemoração de sessão exige que o jogo abra com vínculo 25.** Quem cruza o limiar durante a sessão só a vê na abertura seguinte.
* **Não há indicação de quanto falta para a próxima reação além do HUD.** O painel mostra `Vínculo 8` e `Próxima reação: 8/10`, mas nada no cenário sugere que ele está perto de destravar algo.
* **A recarga do carinho não aparece em contagem regressiva.** O botão desabilita e o tooltip mostra o tempo, mas só ao passar o ponteiro por cima.

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

As onze primeiras etapas do `PLANO_MVP.md` estão entregues. Seguem pendentes:

* Modo papel de parede, modo silencioso e redução de consumo.
* Arte definitiva de Caramelo: as duas formas ainda são compostas por polígonos.
* Objetos do cenário como entidades próprias — halteres e barras ainda fazem parte da imagem de fundo.
* Janela de configurações, bandeja do sistema e inicialização automática.
* Áudio — habilitado tecnicamente, mas nenhum som é reproduzido.


O roteiro completo está em [`PLANO_MVP.md`](PLANO_MVP.md).
