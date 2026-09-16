# Como Aumentar Seu Caramelo

Jogo 2D idle para desktop que também funciona como papel de parede animado. O jogador cuida de um vira-lata caramelo brasileiro: ele come para recuperar energia, treina para ganhar força, descansa e evolui gradualmente até uma forma mais musculosa e carismática.

**A fonte oficial de requisitos é [`MVP_SPEC.md`](MVP_SPEC.md).** Em caso de divergência, ela prevalece sobre [`DESIGN.md`](DESIGN.md) (visão de longo prazo) e [`PLANO_MVP.md`](PLANO_MVP.md) (roteiro de 12 etapas).

## Estado atual

**Etapa 6 de 12 — Sistema de alimentação.** O primeiro ciclo funcional está de pé: clicar no pote abre um menu com os três alimentos, Caramelo caminha até o pote, come, e só então ganha energia e vínculo — com recarga própria por alimento. **Treino, carinho, HUD, salvamento e progresso offline continuam fora.**

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
  "training_point": "TrainingPoint", "comic_reaction_chance": 0.10 }
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

## Estrutura da cena principal

```text
Main                    (Node)
├── GameSession         (Node)        ← configuração, modelo e resolução de referências
│   └── FeedingSystem   (Node)        ← pedidos, recompensa e recargas
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
│       │   └── FoodBowl      (instância de food_bowl.tscn, em (987.6, 820.1))
│       └── ForegroundLayer   (Node2D)       z = 20
└── Interface           (CanvasLayer, camada 1)
    └── FoodMenu        (instância de food_menu.tscn, oculto por padrão)
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

São duas suítes permanentes, ambas sem janela e sem nenhum framework externo. Cada uma sai com código `0` quando tudo passa e `1` caso contrário, imprimindo cada verificação.

```bash
# controlador de Caramelo — 69 verificações
godot --headless --path . --script tests/test_caramelo_controller.gd

# configuração, atributos e progressão — 187 verificações
godot --headless --path . --script tests/test_progression.gd

# sistema de alimentação — 105 verificações
godot --headless --path . --script tests/test_feeding_system.gd
```

**`test_caramelo_controller.gd`** cobre estado inicial, existência dos seis estados, transições válidas e inválidas, reentrada, não interrupção de `EATING` e `TRAINING`, descarte de comandos, sinais, destinos e trajetos dentro do polígono, parada no destino, reprodutibilidade por semente, acompanhamento da transformação do quintal e unicidade de Caramelo na cena principal.

**`test_progression.gd`** cobre a existência e validade dos três JSON, campos obrigatórios, unicidade de IDs, limiares crescentes, relações entre arquivos, **22 formas diferentes de configuração inválida**, os limites e a atomicidade da energia, os cinco níveis, os desbloqueios de vínculo, valores e ordem dos sinais, a posse do modelo pela `GameSession`, o desacoplamento entre Caramelo e o modelo, e a aritmética da progressão.

**`test_feeding_system.gd`** cobre o pedido e as seis formas de recusa, o direcionamento ao `FoodPoint`, a recompensa só na conclusão e exatamente uma vez, sinais duplicados, conclusões de outra atividade, o teto de energia, a ordem obrigatória dos efeitos, recargas independentes vindas do JSON, a frequência de `cooldown_changed`, `activity_completed`, o pote e o menu na cena, e a ausência de recompensa sem ação do jogador.

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

* `scripts/systems/feeding_system.gd`: o ciclo da refeição — pedido, pendência única, recompensa na conclusão e recargas.
* `scenes/environment/food_bowl.tscn` + `scripts/environment/food_bowl.gd`: o pote clicável, feito de polígonos.
* `scenes/ui/food_menu.tscn` + `scripts/ui/food_menu.gd`: o menu contextual dos três alimentos.
* `tests/test_feeding_system.gd`: 105 verificações permanentes.
* `scripts/dog/caramelo.gd`: ganhou o sinal `activity_completed` e passou a aceitar um pedido de atividade a partir de `HAPPY`, saltando por `IDLE`.
* `scripts/systems/game_session.gd`: resolve Caramelo, o pote e o `FoodPoint` uma única vez e configura o sistema.
* `scenes/environment/backyard.tscn` e `scenes/main/main.tscn`: instanciam o pote, o sistema e o menu.

`data/foods.json` **não foi alterado** — os três alimentos já estavam corretos desde a Etapa 5.

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
* **Um único `TrainingPoint`.** Segue valendo a limitação da Etapa 3: a arte tem dois conjuntos de treino e Caramelo só conhece o da esquerda. Os dois exercícios apontam para o mesmo `training_point` em `exercises.json`.

### Alimentação

* **Nada é persistido.** As recargas correm só com o aplicativo aberto e zeram ao reabrir. O `MVP_SPEC.md` §12 exige que elas continuem correndo com o jogo fechado — isso é da Etapa 10.
* **O pote é o único elemento clicável do cenário**, como manda a §6. O restante é pintura de fundo.
* **Caramelo não vira para o pote ao comer.** Se ele chega vindo da direita, come de costas para a vasilha. A arte é provisória e a correção vem com os sprites reais.
* **Sem fila e sem cancelamento.** Depois de aceito, o pedido vai até o fim: `EATING` é não interrompível por especificação, e não há como desistir a caminho.
* **O menu não mostra energia nem vínculo atuais.** Ele lista só o que cada alimento dá. As barras permanentes são o HUD da Etapa 9.
* **Valores provisórios.** As recargas de 5, 15 e 10 min seguem pendentes de playtest (ponto em aberto A-2 do `MVP_SPEC.md`).

### Atributos e progressão

* **Só a alimentação alimenta o modelo.** Treino e carinho continuam sem efeito, e nenhum estado gasta energia ou concede força.
* **Nada é salvo.** Fechar o jogo descarta energia, vínculo e recargas; não há persistência nem progresso offline.
* **Os desbloqueios não têm efeito visual.** `muscular_form`, `final_pose`, `level_2_celebration` e os três comportamentos de vínculo existem só como consulta.

* **A configuração é lida só na abertura.** Editar um JSON com o jogo rodando não muda nada; é preciso reabrir. Não há recarga em tempo de execução, por decisão de escopo.
* **`max_energy` é fixo em 100.** Vem dos dados, mas nada no MVP o altera.
* **Valores provisórios.** As recargas dos alimentos e a chance de reação cômica seguem pendentes de playtest (pontos em aberto A-2 do `MVP_SPEC.md`).

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
* Treino e descanso com efeito de verdade — só a alimentação está ligada ao modelo.
* Carinho e os comportamentos afetivos por vínculo.
* Interface, barras e botões.
* Salvamento local e progresso offline.
* Modo papel de parede, modo silencioso e redução de consumo.
* Áudio — habilitado tecnicamente, mas nenhum som é reproduzido.


O roteiro completo está em [`PLANO_MVP.md`](PLANO_MVP.md).
