# Plano de Desenvolvimento do MVP — 12 Etapas

Cada etapa produz um resultado testável e uma versão executável antes da próxima começar.
O objetivo não é construir todo o universo de *Como Aumentar Seu Caramelo* (ver [DESIGN.md](DESIGN.md)),
e sim validar se o cachorro animado, a progressão idle e o uso como papel de parede são agradáveis.

## Escopo fechado do MVP

O MVP contém **somente**:

* Um cachorro Caramelo.
* Duas aparências: inicial e musculosa.
* Um cenário: quintal / academia improvisada.
* Três atividades: comer, treinar e descansar.
* Dois exercícios: flexões e halteres.
* Três alimentos.
* Progressão por energia, força e vínculo.
* Cinco níveis.
* Animações simples.
* Progresso offline.
* Salvamento local.
* Modo janela e modo papel de parede.
* Modo silencioso ou de baixo consumo.

Ficam para **depois do MVP**: outros animais, loja, decoração livre, minijogos, eventos sazonais e múltiplos ambientes.

---

## Etapa 1 — Definir o documento do MVP

Criar `MVP_SPEC.md`, definindo:

* O que o jogador pode fazer.
* O que Caramelo faz sozinho.
* Quais atributos existem.
* Como os níveis são obtidos.
* O que muda visualmente.
* O que **não** fará parte do MVP.
* Critérios para considerar o MVP concluído.

### Ciclo principal

1. Caramelo descansa e recupera energia.
2. O jogador fornece alimento.
3. Caramelo recebe energia.
4. O jogador escolhe um exercício.
5. O exercício consome energia.
6. Caramelo recebe força e experiência.
7. Ele sobe de nível.
8. Sua aparência e suas animações evoluem.

**Resultado:** especificação clara o bastante para implementar cada funcionalidade sem inventar sistemas adicionais.

---

## Etapa 2 — Criar a estrutura técnica

* **Engine:** Godot 4
* **Linguagem:** GDScript
* **Plataforma inicial:** Windows
* **Resolução-base:** 1920 × 1080
* **Formato visual:** 2D
* **Dados locais:** arquivos JSON ou recursos Godot
* **Controle de versão:** Git

```text
como-aumentar-seu-caramelo/
├── assets/
│   ├── backgrounds/
│   ├── characters/
│   ├── food/
│   ├── equipment/
│   ├── ui/
│   ├── audio/
│   └── fonts/
├── data/
│   ├── foods.json
│   ├── exercises.json
│   └── levels.json
├── scenes/
│   ├── main/
│   ├── dog/
│   ├── environment/
│   └── ui/
├── scripts/
│   ├── systems/
│   ├── dog/
│   └── ui/
├── tests/
├── project.godot
├── MVP_SPEC.md
└── README.md
```

**Resultado:** o projeto abre no Godot e apresenta uma cena vazia com o fundo do quintal.

---

## Etapa 3 — Construir o cenário principal

O quintal é a única área do MVP. A cena contém:

* Imagem de fundo.
* Área caminhável.
* Ponto de alimentação.
* Ponto de treino.
* Ponto de descanso.
* Limites para o deslocamento do cachorro.
* Camadas preparadas para personagem, objetos e interface.

Mesmo usando inicialmente uma imagem única, manter os elementos interativos separados — o halter clicável não pode estar incorporado ao fundo.

**Resultado:** o cenário aparece corretamente em diferentes proporções de tela, sem cortar a área principal de interação.

---

## Etapa 4 — Implementar o controlador de Caramelo

Máquina de estados, estados iniciais:

```text
IDLE
WALKING
EATING
TRAINING
RESTING
HAPPY
```

Cada estado controla: animação atual · duração · possibilidade de interrupção · próximo estado permitido · mudança nos atributos · sons ou efeitos associados.

Transições:

```text
IDLE → WALKING
IDLE → EATING
IDLE → TRAINING
TRAINING → HAPPY
TRAINING → RESTING
RESTING → IDLE
```

Caramelo escolhe pequenas ações sozinho quando o jogador não interage.

**Resultado:** o cachorro alterna de maneira estável entre ociosidade, caminhada e descanso, sem participação do jogador.

---

## Etapa 5 — Criar os atributos e a progressão

| Atributo | Função                                      |
| -------- | ------------------------------------------- |
| Energia  | Permite executar exercícios                 |
| Força    | Representa o crescimento físico             |
| Vínculo  | Cresce com alimentação, carinho e interação |
| Nível    | Controla desbloqueios e aparência           |

Valores iniciais:

```text
energia: 70/100
força: 0
vínculo: 0
nível: 1
```

| Nível | Força necessária | Mudança                |
| ----- | ---------------: | ---------------------- |
| 1     |                0 | Caramelinho            |
| 2     |               25 | Flexão desbloqueada    |
| 3     |               70 | Halteres desbloqueados |
| 4     |              140 | Aparência mais robusta |
| 5     |              250 | Forma musculosa do MVP |

A progressão fica em `levels.json` — **sem números fixos espalhados pelo código**.

**Resultado:** ganhar força aumenta o nível e desbloqueia atividades corretamente.

---

## Etapa 6 — Implementar alimentação

| Alimento               | Energia | Vínculo | Observação          |
| ---------------------- | ------: | ------: | ------------------- |
| Ração                  |     +20 |      +1 | Opção comum         |
| Frango com arroz       |     +35 |      +2 | Recuperação maior   |
| Pão de queijo fictício |     +15 |      +3 | Animação mais feliz |

Fluxo: o jogador seleciona o pote → abre um pequeno menu → escolhe o alimento → Caramelo caminha até o pote → executa a animação de comer → os atributos são atualizados → o jogo salva automaticamente.

Sem inventário e sem moeda nesta fase. Os alimentos podem ter tempo de recarga para impedir uso infinito.

**Resultado:** é possível alimentar Caramelo e visualizar claramente a recuperação de energia.

---

## Etapa 7 — Implementar os exercícios

Somente dois exercícios.

| Exercício | Energia |     Duração | Força | Desbloqueio |
| --------- | ------: | ----------: | ----: | ----------- |
| Flexões   |      15 | 20 segundos |    +5 | Nível 2     |
| Halteres  |      25 | 30 segundos |    +9 | Nível 3     |

Cada exercício tem: preparação · repetição em loop · conclusão · reação de sucesso · pequena chance de animação engraçada.

A duração pode ser acelerada durante testes.

**Resultado:** o jogador seleciona um exercício, Caramelo treina e recebe a recompensa **uma única vez** ao concluir.

---

## Etapa 8 — Criar descanso e comportamento idle

Caramelo recupera energia automaticamente. Possibilidades: deitar no chão; dormir próximo à cadeira; sentar e observar o cenário; alongar-se; farejar objetos; perseguir uma mosca imaginária.

Regras:

* O descanso recupera energia lentamente.
* O jogador nunca é punido por deixar o jogo fechado.
* Caramelo não fica doente.
* Nenhum atributo importante cai abaixo de um limite crítico.
* Pedidos de atenção não podem aparecer com frequência irritante.

**Resultado:** o jogo continua visualmente interessante por pelo menos dez minutos sem interação.

---

## Etapa 9 — Construir a interface

Discreta, porque o jogo funciona como papel de parede.

Elementos: energia · força · vínculo · nível · botão de comida · botão de treino · botão de descanso · configurações · indicador da atividade atual.

Comportamento:

* Interface recolhida por padrão.
* Aparece ao clicar em Caramelo.
* Desaparece após alguns segundos.
* Tooltips explicam os botões.
* Barras não permanecem sobre o cachorro.
* Botões grandes o suficiente para uso rápido.

**Resultado:** todas as ações principais podem ser executadas em dois ou três cliques.

---

## Etapa 10 — Implementar salvamento e progresso offline

Salvar:

```text
energia
força
vínculo
nível
atividade atual
horário do último salvamento
configurações
aparência desbloqueada
```

Salvamento automático: depois de alimentar · depois de treinar · ao subir de nível · ao alterar configurações · ao fechar o jogo · periodicamente.

Ao abrir o jogo:

1. Ler o último horário salvo.
2. Calcular o tempo ausente.
3. Limitar o progresso offline (por exemplo, oito horas).
4. Recuperar energia.
5. Concluir um treino que já estava em andamento.
6. Mostrar um resumo curto.

> Enquanto você esteve fora, Caramelo descansou e recuperou 42 de energia.

**Nunca usar o relógio do computador para aplicar penalidades.**

**Resultado:** fechar e abrir o aplicativo mantém o progresso sem duplicar recompensas.

---

## Etapa 11 — Implementar a evolução visual

Duas formas no MVP: Caramelo inicial e Caramelo musculoso. A mudança acontece no nível 4 ou 5.

Preservar: cor da pelagem · formato do rosto · orelhas · coleira · expressão amigável · identidade geral do personagem.

Alterar: peito · ombros · patas dianteiras · postura · caminhada · pose após o exercício.

**Não basta aumentar a escala do sprite — a silhueta precisa realmente mudar.**

**Resultado:** o jogador percebe imediatamente o crescimento, mas ainda reconhece o mesmo cachorro.

---

## Etapa 12 — Papel de parede, otimização e entrega

Maior risco técnico; só depois que o jogo convencional funcionar.

Modos:

1. **Janela normal:** desenvolvimento e configurações.
2. **Janela sem bordas:** simulação de papel de parede.
3. **Papel de parede:** integração específica com o Windows.

Requisitos:

* Suporte a múltiplas resoluções.
* Limite de FPS configurável.
* Pausa ou redução para 5–10 FPS quando não houver atividade.
* Redução de processamento quando outra aplicação estiver em tela cheia.
* Áudio desativado por padrão no modo wallpaper.
* Opção de inicialização automática, nunca ativada silenciosamente.
* Maneira clara de fechar ou pausar.
* Recuperação segura caso a integração com o desktop falhe.

Exportação executável com: instalador ou pacote portátil · arquivo de configuração · salvamento separado do executável · README · lista de comandos e controles · formulário simples para feedback.

**Resultado:** uma pessoa consegue instalar, executar, interagir, fechar e abrir novamente sem assistência técnica.

---

## Ordem de trabalho

| Fase               | Etapas | Objetivo                       |
| ------------------ | ------ | ------------------------------ |
| Pré-produção       | 1–2    | Fechar escopo e estrutura      |
| Protótipo jogável  | 3–5    | Cenário, cachorro e progressão |
| Ciclo principal    | 6–8    | Comer, treinar e descansar     |
| Produto utilizável | 9–10   | Interface, save e offline      |
| Identidade do jogo | 11     | Evolução visual                |
| Entrega desktop    | 12     | Wallpaper, desempenho e build  |

## Marcos de validação

**Marco A — Protótipo (fim da etapa 5):** Caramelo aparece no quintal, move-se sozinho, possui energia e força, pode subir de nível.

**Marco B — Vertical slice (fim da etapa 8):** o ciclo completo funciona; é possível comer, treinar e descansar; o jogo já pode ser avaliado quanto à diversão.

**Marco C — MVP (fim da etapa 12):** progressão persistente, mudança de aparência, progresso offline e operação como papel de parede.

## Como conduzir cada etapa com o agente

Uma solicitação separada por etapa, exigindo:

1. Análise dos arquivos existentes.
2. Lista dos arquivos que serão modificados.
3. Implementação de **apenas uma etapa**.
4. Testes ou procedimento verificável.
5. Atualização do `README.md`.
6. Nenhuma funcionalidade fora do escopo.
7. Um commit separado após a validação.

Exemplo de pedido:

> Implemente somente a Etapa 4 descrita em `MVP_SPEC.md`. Antes de editar, examine a estrutura existente. Crie a máquina de estados de Caramelo com os estados IDLE, WALKING, EATING, TRAINING, RESTING e HAPPY. Não implemente alimentação ou exercícios completos ainda. Ao terminar, execute os testes possíveis e informe os arquivos alterados, limitações e procedimento de validação manual.

**Regra mais importante:** nunca pedir ao agente que construa o jogo inteiro de uma vez. Cada uma das 12 etapas deve produzir uma versão executável antes da próxima começar.
