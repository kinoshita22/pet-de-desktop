# MVP_SPEC — Como Aumentar Seu Caramelo

**Versão:** 1.1 · **Data:** 2026-09-16 · **Etapa:** 1 de 12 (ver [PLANO_MVP.md](PLANO_MVP.md))
**Status:** fonte oficial de requisitos do MVP. Em caso de divergência, este documento prevalece sobre `DESIGN.md` (visão de longo prazo) e sobre `PLANO_MVP.md` (roteiro de execução).

---

## 1. Resumo

*Como Aumentar Seu Caramelo* é um jogo 2D idle para desktop que também funciona como papel de parede animado. O jogador cuida de um cachorro vira-lata caramelo brasileiro que come para recuperar energia, treina para ganhar força, descansa e evolui gradualmente até uma aparência mais musculosa e carismática.

O MVP entrega um único animal, um único cenário, duas formas visuais, cinco níveis e o ciclo completo de comer, treinar e descansar — com salvamento local, progresso offline limitado e operação tanto em janela quanto como papel de parede no Windows.

Nada neste documento descreve código. Ele define **o que** o MVP faz; **como** implementar é assunto das etapas 2 a 12.

---

## 2. Objetivo do MVP

O MVP existe para responder três perguntas, e não para esgotar o conteúdo do jogo:

1. É agradável deixar Caramelo visível durante o trabalho?
2. As pessoas retornam espontaneamente para observar sua evolução?
3. A transformação física gera curiosidade suficiente para continuar jogando?

Consequência prática: qualquer funcionalidade que não ajude a responder essas três perguntas fica fora, mesmo que seja barata de implementar.

---

## 3. Público e plataforma

* **Público:** pessoa que passa horas no computador e quer uma presença leve e divertida na tela, sem obrigação de atenção contínua.
* **Plataforma-alvo do MVP:** Windows (desktop).
* **Engine:** Godot 4 · **Linguagem:** GDScript · **Formato:** 2D.
* **Resolução-base:** 1920 × 1080, com suporte a outras resoluções e proporções.
* **Conectividade:** nenhuma. O jogo funciona integralmente offline; não há contas, servidores nem telemetria.
* **Modos de execução:** janela normal e papel de parede.

O desenvolvimento pode ocorrer em Linux (Godot é multiplataforma), mas o único alvo validado do MVP é Windows — em especial a integração de papel de parede, que é específica da plataforma.

---

## 4. Fantasia central

Cuidar, treinar e acompanhar um legítimo vira-lata caramelo até ele virar uma lenda musculosa do bairro.

Regra que rege todo o sistema:

> Caramelo come para obter energia, treina para transformar energia em força e descansa para consolidar seu progresso.

O tom é de exagero carismático de desenho animado. O humor vem das animações e das situações, não de texto colado na interface. Caramelo nunca adoece, nunca regride e nunca cobra a atenção do jogador de forma insistente.

---

## 5. Ciclo principal

1. Caramelo descansa e recupera energia.
2. O jogador escolhe um alimento.
3. Caramelo come e recebe energia e vínculo.
4. O jogador seleciona um exercício desbloqueado.
5. O exercício consome energia.
6. Caramelo recebe força.
7. Ao alcançar a força necessária, Caramelo sobe de nível.
8. Novos exercícios ou mudanças visuais são desbloqueados.
9. O jogo salva o progresso automaticamente.
10. Com o aplicativo fechado, Caramelo pode descansar e concluir uma atividade já iniciada.

O ciclo é opcional em todos os passos: sem nenhuma intervenção do jogador, Caramelo continua descansando, caminhando e realizando ações ociosas indefinidamente.

---

## 6. Escopo obrigatório

O MVP **deve** conter:

| # | Item | Detalhe |
| - | ---- | ------- |
| 1 | Um cachorro Caramelo | Único personagem jogável |
| 2 | Um cenário | Quintal brasileiro com academia improvisada |
| 3 | Duas formas visuais | Inicial e musculosa |
| 4 | Cinco níveis | Progressão de 1 a 5 |
| 5 | Três atividades | Comer, treinar e descansar |
| 6 | Dois exercícios | Flexões e halteres |
| 7 | Três alimentos | Ração, frango com arroz e pão de queijo fictício |
| 8 | Quatro atributos | `energy`, `strength`, `bond`, `level` |
| 9 | Comportamentos autônomos simples | Caramelo age sozinho sem o jogador |
| 10 | Interface recolhível | Oculta por padrão |
| 11 | Salvamento local automático | Sem intervenção do jogador |
| 12 | Progresso offline limitado | Teto de 8 horas |
| 13 | Modo janela | Para desenvolvimento e uso comum |
| 14 | Modo papel de parede | Windows |
| 15 | Modo silencioso / baixo consumo | Redução de áudio e processamento |

### Composição do quintal

O cenário do MVP está fechado e contém exatamente:

* Fundo do quintal brasileiro.
* Área central caminhável.
* Pote de comida.
* Área de descanso.
* Halteres.
* Barras de flexão, ou marcação visual da área de flexões.
* Cadeira plástica.
* Plantas.
* Varal.
* Elementos decorativos não interativos.

**Somente o pote, Caramelo e os controles das atividades são interativos.** Todo o resto é cenário — inclusive halteres e barras, que são acionados pela interface de treino, e não por clique direto no objeto.

---

## 7. Fora do escopo

O MVP **não** terá, explicitamente:

* Outros animais (gato, papagaio, pinscher, capivara, etc.).
* Multiplayer.
* Loja ou pagamentos.
* Moedas premium.
* Sistema completo de inventário.
* Personalização avançada (roupas e acessórios).
* Decoração livre de ambiente.
* Múltiplos ambientes.
* Minijogos complexos.
* Competições.
* Eventos sazonais.
* Integração online.
* Contas de usuário.
* Serviços em nuvem.
* Rankings.
* Conquistas de plataforma (Steam, etc.).
* Versões para dispositivos móveis.

Também ficam fora, por decorrência: o atributo *Técnica*, o exercício *corrida*, os eventos humorísticos roteirizados e os acessórios descritos no `DESIGN.md`. Esses itens permanecem na visão de longo prazo, não no MVP.

---

## 8. Ações do jogador

Todas as ações são opcionais e resolvidas em **no máximo três cliques**.

| Ação | Caminho | Pré-condição | Efeito |
| ---- | ------- | ------------ | ------ |
| Abrir a interface | Clicar em Caramelo | — | A HUD aparece |
| Alimentar | HUD → botão de comida → escolher alimento | Alimento fora da recarga | Caramelo caminha até o pote e come |
| Treinar | HUD → botão de treino → escolher exercício | Exercício desbloqueado e energia suficiente | Caramelo caminha até o equipamento e treina |
| Mandar descansar | HUD → botão de descanso | Caramelo não está em atividade não interrompível | Caramelo vai descansar |
| Fazer carinho | Clicar/arrastar sobre Caramelo | Fora de `EATING` e `TRAINING`, e fora da recarga | +1 de vínculo; não consome energia |
| Abrir configurações | HUD → engrenagem | — | Painel de opções |
| Pausar animações | Configurações ou bandeja do sistema | — | Jogo congela e reduz consumo |
| Alternar modo | Configurações ou bandeja | — | Janela ↔ papel de parede |
| Fechar | Bandeja do sistema ou janela | — | Salva e encerra |

Não há ação obrigatória. O jogador pode nunca clicar em nada e ainda assim ver Caramelo evoluir lentamente pelo descanso — apenas mais devagar.

---

## 9. Comportamentos de Caramelo

Caramelo age sozinho quando o jogador não interage. O MVP inclui **cinco comportamentos autônomos simples**:

1. Caminhar até um ponto aleatório da área caminhável.
2. Sentar e observar o cenário.
3. Alongar-se.
4. Farejar um objeto do quintal.
5. Perseguir uma mosca imaginária.

Regras dos comportamentos autônomos:

* Não alteram `strength`, `bond` nem `level`.
* Não consomem energia de forma relevante (custo zero no MVP).
* Nunca interrompem uma atividade solicitada pelo jogador.
* São escolhidos aleatoriamente, sem repetir o mesmo comportamento duas vezes seguidas.
* Existe um intervalo de ociosidade entre eles, para que o cenário não pareça agitado demais.

Além disso, Caramelo reage visualmente ao retorno do jogador (transição para `HAPPY`) e descansa por conta própria quando a energia está baixa.

### Comportamentos afetivos desbloqueados por vínculo

O vínculo desbloqueia **apenas comportamentos**, nunca bônus numéricos:

| Vínculo | Comportamento desbloqueado |
| ------: | -------------------------- |
| 10 | Reação ao carinho |
| 25 | Comemoração especial ao iniciar o jogo |
| 50 | Animação afetiva rara, durante a ociosidade |

Os três limiares ficam em dados. Abaixo de 10 de vínculo, o carinho ainda é aceito e ainda credita vínculo — apenas não há reação dedicada.

---

## 10. Máquina de estados

Estados do MVP: `IDLE`, `WALKING`, `EATING`, `TRAINING`, `RESTING`, `HAPPY`.

Regra geral: **a cada instante Caramelo está em exatamente um estado**, e todo estado sabe terminar sozinho — nenhum estado depende do jogador para ser encerrado.

### `IDLE`

* **Início:** ao terminar qualquer outro estado sem destino específico; é o estado inicial do jogo.
* **Fim:** após um intervalo curto, escolhendo um comportamento autônomo, ou imediatamente ao receber um comando do jogador.
* **Interrompível:** sim, sempre.
* **Próximos permitidos:** `WALKING`, `EATING`, `TRAINING`, `RESTING`, `HAPPY`.
* **Atributos:** nenhum efeito.
* **Visual:** Caramelo parado, respirando, com micro-animações (orelha, rabo, piscar).

### `WALKING`

* **Início:** ao escolher um ponto de destino — aleatório (comportamento autônomo) ou funcional (pote, equipamento, local de descanso).
* **Fim:** ao alcançar o destino.
* **Interrompível:** sim; um novo comando substitui o destino.
* **Próximos permitidos:** `IDLE`, `EATING`, `TRAINING`, `RESTING`.
* **Atributos:** nenhum efeito no MVP.
* **Visual:** ciclo de caminhada; a silhueta e o ritmo mudam conforme a forma visual atual.

### `EATING`

* **Início:** ao chegar ao pote depois que o jogador escolheu um alimento.
* **Fim:** ao terminar a animação de comer (≈ 4 s).
* **Interrompível:** não. Comandos recebidos durante o estado são descartados, não enfileirados.
* **Próximos permitidos:** `HAPPY` (padrão), `IDLE`.
* **Atributos:** aplica `energy` e `bond` do alimento, uma única vez, ao **concluir**.
* **Visual:** Caramelo abaixado no pote, rabo abanando; ao final, lambe o focinho.

### `TRAINING`

* **Início:** ao chegar ao equipamento, com o exercício desbloqueado e energia suficiente.
* **Fim:** ao completar a duração do exercício.
* **Interrompível:** não pelo jogador. É interrompido apenas pelo encerramento do aplicativo — e, nesse caso, a atividade é retomada e concluída na próxima abertura (ver seção 17).
* **Próximos permitidos:** `HAPPY` (padrão), `RESTING` (se a energia ficar baixa).
* **Atributos:** debita `energy` no **início**; credita `strength` uma única vez na **conclusão**.
* **Visual:** preparação → repetição em loop → conclusão. Pequena chance de uma reação cômica puramente visual, sem efeito nos atributos.

### `RESTING`

* **Início:** por comando do jogador, por energia baixa, ou automaticamente após um treino exaustivo.
* **Fim:** quando a energia chega a 100, quando o jogador dá outro comando, ou após um tempo mínimo de descanso.
* **Interrompível:** sim, por comando do jogador.
* **Próximos permitidos:** `IDLE`, `EATING`, `TRAINING`.
* **Atributos:** recupera `energy` de forma contínua e lenta.
* **Visual:** deitado no chão ou perto da cadeira de plástico, respirando devagar; possível sono.

### `HAPPY`

* **Início:** após concluir um exercício, após comer, ao subir de nível, ao receber carinho ou quando o jogador retorna.
* **Fim:** após uma animação curta (≈ 2 s).
* **Interrompível:** sim.
* **Próximos permitidos:** `IDLE`, `RESTING`.
* **Atributos:** nenhum efeito direto. O ganho de vínculo pertence à ação que causou a alegria.
* **Visual:** pulo, latido mudo, pose de vitória; no caso de subida de nível, uma pose mais exagerada.

### Transições permitidas

```text
IDLE     → WALKING | EATING | TRAINING | RESTING | HAPPY
WALKING  → IDLE | EATING | TRAINING | RESTING
EATING   → HAPPY | IDLE
TRAINING → HAPPY | RESTING
RESTING  → IDLE | EATING | TRAINING
HAPPY    → IDLE | RESTING
```

Qualquer transição não listada é inválida e deve ser rejeitada em vez de tratada como caso especial.

O carinho **não é um estado**: é uma interação pontual, aceita em `IDLE`, `WALKING`, `RESTING` e `HAPPY`, e recusada em `EATING` e `TRAINING`. Quando há reação de carinho desbloqueada (vínculo ≥ 10), ela ocorre como uma transição comum para `HAPPY`.

---

## 11. Atributos

| Atributo | Tipo | Inicial | Mínimo | Máximo |
| -------- | ---- | ------: | -----: | -----: |
| `energy` | número | 70 | 0 | 100 |
| `strength` | número acumulativo | 0 | 0 | 250 (teto do MVP) |
| `bond` | número acumulativo | 0 | 0 | sem teto no MVP |
| `level` | inteiro | 1 | 1 | 5 |

### `energy`

* **Aumenta:** ao comer (valor do alimento) e ao descansar (recuperação passiva contínua, também aplicada offline).
* **Diminui:** apenas ao iniciar um exercício, pelo custo fixo do exercício.
* **Nunca ultrapassa 100.** O excedente de um alimento é descartado, não acumulado.
* **Nunca fica negativo.** Um exercício só começa se `energy >= custo`.
* Não decai com o tempo. Caramelo não perde energia por estar ocioso, nem passivamente, nem offline.

### `strength`

* **Aumenta:** somente ao **concluir** um exercício.
* **Nunca diminui.** Não há decaimento, penalidade ou reset.
* É a única fonte de progressão de nível.

### `bond`

* **Aumenta:** ao comer (valor do alimento) e ao receber carinho (+1, com recarga).
* **Nunca diminui.**
* **Desbloqueia apenas comportamentos afetivos** nos limiares 10, 25 e 50 (seção 9), todos configuráveis por dados.
* **Nunca concede bônus de força, energia ou velocidade**, nem acelera qualquer progressão. Vínculo e força são eixos independentes: o vínculo mede afeto, a força mede treino.

### `level`

* Derivado de `strength` pela tabela da seção 14. Nunca diminui.
* Como o maior ganho de força por sessão é +9 e o menor intervalo entre níveis é 25, **é impossível subir dois níveis de uma só vez** — a animação de subida de nível nunca precisa ser enfileirada.

### Energia insuficiente

Quando `energy < custo` do exercício escolhido:

* O exercício **não começa** e nenhuma energia é debitada.
* O botão do exercício aparece desabilitado, com a razão visível ("Caramelo está cansado").
* A interface sugere a ação que resolve — alimentar ou descansar.
* Não há penalidade, mensagem de erro agressiva nem falha de Caramelo por isso.

### Garantia contra perdas por ausência

`strength`, `bond` e `level` **nunca diminuem por nenhum motivo**, incluindo ausência de dias ou meses. Não existe fome punitiva, doença, decaimento nem reset. A única variável que o tempo movimenta é `energy`, e apenas para cima.

---

## 12. Alimentação

| Alimento | Energia | Vínculo | Animação | Recarga |
| -------- | ------: | ------: | -------: | ------: |
| Ração | +20 | +1 | ≈ 4 s | 5 min |
| Frango com arroz | +35 | +2 | ≈ 5 s | 15 min |
| Pão de queijo fictício | +15 | +3 | ≈ 4 s | 10 min |

Regras:

* **Recarga por alimento, não global:** cada alimento tem seu próprio contador, de modo que sempre há alguma opção disponível. Os valores acima são provisórios, ficam em `data/foods.json` e serão reavaliados em playtest na Etapa 6.
* **Teto de 100:** alimentar com energia em 95 e dar ração (+20) resulta em 100, não 115. O vínculo é creditado integralmente mesmo assim.
* **Alimentar com energia em 100** é permitido: vale o ganho de vínculo e a animação. A interface deixa claro que a energia não subirá.
* **Sem inventário e sem moeda.** Os alimentos não são possuídos nem comprados; a recarga é o único limitador.
* **Aplicação única, na conclusão** da animação de comer. Fechar o jogo durante a animação não credita nada e não consome a recarga.
* **Salvamento automático** imediatamente após a aplicação dos efeitos.
* A recarga é contada em tempo real e **continua correndo com o jogo fechado**, para não punir quem sai.

---

## 13. Exercícios

| Exercício | Energia | Duração | Força | Desbloqueio |
| --------- | ------: | ------: | ----: | ----------- |
| Flexões | 15 | 20 s | +5 | **Nível 1** (disponíveis desde o início) |
| Halteres | 25 | 30 s | +9 | Nível 3 |

Cada exercício possui obrigatoriamente:

1. **Preparação** — Caramelo se posiciona no equipamento (curta, não cancelável a partir daqui).
2. **Animação repetida** — o loop da execução, que ocupa a maior parte da duração.
3. **Conclusão** — a última repetição, encerrando o loop.
4. **Reação de sucesso** — transição para `HAPPY`.
5. **Reação cômica opcional** — chance inicial de **10%**, configurável por dados. É puramente visual, **não altera a recompensa** e é sorteada **somente depois que a força já foi creditada**, de modo que nenhum resultado de sorteio possa influenciar o ganho.

Regras:

* **Energia debitada no início**, força creditada **apenas uma vez na conclusão**. Um exercício interrompido pelo fechamento do aplicativo é retomado e pago na reabertura, nunca pago duas vezes (seção 17).
* **Bloqueio por energia:** sem energia suficiente, o exercício não inicia (seção 11).
* **Bloqueio por nível:** exercícios não desbloqueados não aparecem como opção selecionável; aparecem esmaecidos, com o nível exigido visível, para comunicar progressão.
* **Sem fila:** solicitar um exercício enquanto outro corre é ignorado, não enfileirado.
* A duração precisa ser acelerável por uma opção de desenvolvimento, para tornar os testes viáveis — sem afetar o jogo entregue.

### Custo da progressão (verificação de consistência)

Com as flexões disponíveis desde o nível 1, o caminho recomendado é treinar flexões até o nível 3 e halteres em seguida:

| Trecho | Força faltante | Exercício | Sessões | Energia | Tempo de treino |
| ------ | -------------: | --------- | ------: | ------: | --------------: |
| Nível 1 → 2 | 25 | Flexões | 5 | 75 | 1 min 40 s |
| Nível 2 → 3 | 45 | Flexões | 9 | 135 | 3 min 00 s |
| Nível 3 → 4 | 70 | Halteres | 8 | 200 | 4 min 00 s |
| Nível 4 → 5 | 110 | Halteres | 13 | 325 | 6 min 30 s |
| **Total** | **250** | — | **35** | **735** | **≈ 15 min 10 s** |

**Verificação de destravamento:** o nível 1 dispõe das flexões, que custam 15 de energia contra os 70 iniciais — Caramelo pode treinar desde o primeiro segundo de jogo, sem depender de alimento. Com 5 sessões de flexões (75 de energia) chega-se ao nível 2 e com mais 9 ao nível 3, que libera os halteres. **O nível 3 é alcançável usando somente flexões: 14 sessões, 210 de energia, 4 min 40 s de treino.** Não existe nenhum ponto da progressão em que o jogador fique sem exercício disponível.

**Verificação de redundância:** mesmo ignorando os halteres por completo, as flexões sozinhas levam ao nível 5 — 50 sessões, 750 de energia, 16 min 40 s. Os halteres tornam a progressão mais eficiente (0,36 de força por energia contra 0,33), mas nunca são obrigatórios.

Esses 735 pontos de energia são o verdadeiro regulador do ritmo: como a energia tem teto de 100, chegar ao nível 5 exige pelo menos oito ciclos completos de recuperação. Com a recuperação assumida em **+1 de energia por minuto** (suposição **S-1**) e uso regular dos alimentos, o nível 5 fica a cerca de **um a dois dias de uso casual** — compatível com um idle game de papel de parede.

---

## 14. Progressão e níveis

| Nível | Força necessária | Desbloqueio |
| ----- | ---------------: | ----------- |
| 1 | 0 | Alimentação, descanso, **flexões** e ações ociosas |
| 2 | 25 | Nova animação de comemoração |
| 3 | 70 | Halteres |
| 4 | 140 | Forma musculosa |
| 5 | 250 | Pose final e efeito visual de conquista |

Regras:

* O nível é recalculado a partir de `strength` sempre que a força muda.
* Subir de nível dispara `HAPPY` com pose exagerada e uma notificação discreta na HUD.
* O nível **nunca regride**, mesmo que a tabela seja reconfigurada para valores maiores em uma atualização.
* **Todos esses números ficam em `data/levels.json`**, `data/foods.json` e `data/exercises.json`. Nenhum valor de balanceamento — custo, duração, recompensa, limiar ou recarga — pode ser fixado diretamente no código. Ajustar o ritmo do jogo deve ser possível editando dados, sem recompilar e sem tocar em lógica.

O desbloqueio do **nível 2 é exclusivamente visual**: substitui a animação de comemoração por uma versão mais expressiva. Ele **não introduz nenhum sistema novo** — nenhuma mecânica, recurso, tela ou atributo depende dele, e sua ausência não quebraria a progressão.

**A progressão não trava em nenhum ponto:** as flexões estão disponíveis no nível 1, de modo que Caramelo pode ganhar força desde o início (verificações na seção 13).

---

## 15. Evolução visual

O MVP tem **exatamente duas formas visuais**, sem exceção:

| Níveis | Forma |
| ------ | ----- |
| 1 – 3 | Inicial ("Caramelinho") |
| 4 – 5 | Musculosa |

O **nível 5 não adiciona uma terceira forma**. Ele libera somente uma pose final e um efeito visual de conquista, reaproveitando integralmente os sprites da forma musculosa.

**Preservar** em ambas: cor da pelagem, formato do rosto, orelhas, coleira, expressão amigável e a identidade geral do personagem.

**Alterar** entre elas: peito, ombros, patas dianteiras, postura, ciclo de caminhada e a pose pós-exercício.

Regras:

* **Não basta escalar o sprite.** A silhueta precisa mudar de fato — o reconhecimento tem que vir do rosto e da cor, não do tamanho.
* A troca acontece **na subida para o nível 4**, com animação de transição, nunca por substituição abrupta entre um quadro e outro.
* A forma musculosa é um exagero de desenho animado carismático, jamais desconfortável ou assustador.
* A forma alcançada é persistida no save e restaurada na abertura.

---

## 16. Salvamento

O save é local, automático e invisível para o jogador. Não há botão de salvar, nem slots, nem save manual.

Conteúdo do save:

```text
save_version          versão do formato, para migração futura
energy                0–100
strength              acumulado
bond                  acumulado
level                 1–5
current_activity      atividade em andamento (tipo, início, duração, recompensa paga)
last_saved_utc        horário do último salvamento, em UTC
food_cooldowns        horário de liberação de cada alimento
settings              modo de janela, áudio, FPS, autostart, modo silencioso
unlocked_appearance   forma visual atual
```

Momentos de salvamento:

* Depois de alimentar (após aplicar os efeitos).
* Depois de treinar (após creditar a força).
* Ao subir de nível.
* Ao alterar qualquer configuração.
* Ao fechar o jogo, inclusive ao fechar pela bandeja.
* Periodicamente, durante a execução.

Requisitos:

* **Fora do diretório do executável**, na área de dados do usuário — desinstalar ou mover o jogo não pode apagar o progresso.
* **Escrita atômica:** gravar em arquivo temporário e substituir, para que uma queda de energia no meio da escrita não corrompa o save.
* **Save ausente ou corrompido** inicia um jogo novo com os valores iniciais, avisando o jogador de forma não alarmante, sem travar a abertura.
* Formato legível (JSON), sem ofuscação nem proteção anticheat — não há competição no MVP.

---

## 17. Progresso offline

Ao abrir o jogo, calcula-se o tempo decorrido desde `last_saved_utc` e aplica-se:

1. **Teto de 8 horas.** Ausências maiores são tratadas como 8 horas. O teto fica em dados, não no código.
2. **Recuperação passiva de energia** pela mesma taxa do descanso ativo, limitada ao teto de 100. Na prática, qualquer ausência longa devolve Caramelo com energia cheia.
3. **Conclusão de uma atividade em andamento:** se havia um exercício correndo e o tempo decorrido cobre a duração restante, a recompensa é creditada uma única vez. Se não cobre, a atividade continua de onde parou.
4. **Nenhuma perda** de força, vínculo ou nível.
5. **Nenhuma punição** pela ausência, em nenhuma forma: sem fome, sem doença, sem decaimento, sem mensagem de culpa.
6. **Resumo curto ao retornar**, em uma linha, dispensável com um clique:
   > Enquanto você esteve fora, Caramelo descansou e recuperou 42 de energia.
7. **Proteção contra duplicação:** a recompensa da atividade traz uma marca de paga; `last_saved_utc` é reescrito imediatamente após aplicar o progresso offline, de modo que reabrir o jogo em seguida não credite nada de novo.
8. **Proteção contra alteração do relógio:** se o horário atual for anterior a `last_saved_utc`, o tempo decorrido é tratado como zero — sem progresso e **sem penalidade**. Adiantar o relógio rende, no máximo, as 8 horas do teto.

Como a energia tem teto de 100 e a recuperação assumida é de +1/min, o teto de 8 horas raramente é o limitador real: a energia satura em pouco menos de duas horas. O teto existe sobretudo para delimitar a conclusão de atividades e para manter previsível qualquer ganho passivo introduzido depois do MVP.

---

## 18. Interface

* **Recolhida por padrão.** Em repouso, a tela mostra apenas o cenário e Caramelo.
* **Aparece ao selecionar Caramelo** e se recolhe sozinha após alguns segundos de inatividade.
* **Nunca fica sobre o cachorro** — as barras e botões se posicionam de forma a não cobrir o personagem.
* **No máximo três cliques** para qualquer ação principal.
* **Botões grandes**, com tooltips explicativos.

Elementos: energia · força · vínculo · nível · botão de comida · botão de treino · botão de descanso · configurações · indicador da atividade atual.

Regras de conduta:

* **Sem notificações invasivas.** Nada de pop-ups, alertas de sistema ou pedidos de atenção. Avisos ocorrem dentro da própria cena, discretamente.
* Estados indisponíveis são mostrados desabilitados **com a razão visível**, nunca ocultados sem explicação.
* Caramelo continua realizando ações visuais mesmo com a interface aberta.
* O jogador tem sempre uma forma clara e imediata de **pausar e fechar**, disponível tanto na interface quanto na bandeja do sistema.

---

## 19. Requisitos do modo papel de parede

Três modos de execução:

1. **Janela normal** — desenvolvimento, configuração e uso comum.
2. **Janela sem bordas** — simulação de papel de parede; também é o *fallback* seguro.
3. **Papel de parede** — integração específica com o Windows.

Requisitos:

* Caramelo ocupa preferencialmente a **parte inferior da tela** e **nunca cobre permanentemente** botões, ícones ou janelas.
* **Áudio desligado por padrão** no modo papel de parede.
* **Limite de FPS configurável:** até 60 FPS em modo ativo, 10 FPS no modo papel de parede ocioso, e 5 FPS ou animações pausadas quando um aplicativo em tela cheia é detectado (seção 20).
* **Redução de processamento** quando outro aplicativo está em tela cheia.
* Suporte a **múltiplas resoluções** e a mudanças de resolução em tempo de execução.
* **Inicialização automática com o sistema é opcional e nunca ativada silenciosamente** — exige consentimento explícito.
* **Forma clara de pausar ou fechar**, sempre acessível pela bandeja do sistema.
* **Recuperação segura:** se a integração com o desktop falhar, o jogo cai para janela sem bordas e informa o ocorrido, em vez de encerrar ou insistir.

Bandeja do sistema (mínimo do MVP): abrir painel · alimentar · iniciar treino · modo silencioso · pausar animações · fechar.

---

## 20. Requisitos não funcionais

### Metas de desempenho

São **metas iniciais, não garantias absolutas**. Servem para orientar a implementação; o consumo real será medido e ajustado na Etapa 12 (otimização e entrega).

| Situação | Meta |
| -------- | ---- |
| Modo ativo (janela, com interação) | Até 60 FPS |
| Modo papel de parede ocioso | 10 FPS |
| Aplicativo em tela cheia detectado | 5 FPS, ou animações pausadas |
| CPU média no modo ocioso | Abaixo de 2% |

O "computador de referência" para a medição de CPU **ainda não está definido** e será fixado durante os testes da Etapa 12. Até lá, o número de 2% é uma direção, não um critério de reprovação.

### Demais requisitos
* **Offline total:** nenhum fluxo pode exigir internet, em nenhum momento.
* **Sem telemetria e sem coleta de dados.** Nenhum dado sai da máquina.
* **Abertura rápida:** o jogo mostra Caramelo em poucos segundos, sem tela de carregamento longa.
* **Estabilidade:** operação contínua por dias sem vazamento de memória nem degradação — o modo papel de parede pressupõe processo de longa duração.
* **Dados separados do código:** todo balanceamento em `data/*.json`.
* **Testabilidade:** duração de atividades acelerável e estado inicial ajustável em modo de desenvolvimento.
* **Localização:** português do Brasil apenas, com os textos centralizados para facilitar tradução futura.
* **Sem marcas, escudos, bordões ou personagens protegidos** em nenhum asset.

---

## 21. Casos extremos

| Situação | Comportamento esperado |
| -------- | ---------------------- |
| Energia insuficiente para o exercício | Exercício bloqueado, nenhuma energia debitada, razão visível na interface |
| Alimentar com energia em 100 | Permitido; energia permanece 100, vínculo é creditado |
| Alimento em recarga | Opção desabilitada com o tempo restante visível |
| Jogo fechado durante o treino | Atividade retomada e concluída na reabertura, paga uma única vez |
| Jogo fechado durante a animação de comer | Nada é creditado e a recarga não é consumida |
| Clique repetido no botão de treino | Cliques adicionais ignorados; sem fila e sem cobrança dupla |
| Comando durante estado não interrompível | Comando descartado, com aviso discreto |
| Relógio do sistema atrasado | Tempo decorrido tratado como zero; sem progresso e sem penalidade |
| Relógio do sistema adiantado | Ganho limitado ao teto de 8 horas |
| Ausência de meses | Igual a 8 horas de ausência; nada é perdido |
| Save corrompido ou ausente | Jogo novo com valores iniciais e aviso não alarmante |
| Save de versão anterior | Migrado pelo `save_version`; na dúvida, preserva força, vínculo e nível |
| Duas instâncias do jogo abertas | A segunda instância não inicia e traz a primeira para frente |
| Mudança de resolução ou monitor desconectado | Cena reposicionada sem perder o estado; Caramelo permanece dentro da área visível |
| Falha na integração de papel de parede | Queda para janela sem bordas, com aviso |
| Aplicativo em tela cheia em primeiro plano | FPS e processamento reduzidos automaticamente |
| Máquina suspensa e retomada | Tratado como ausência: mesmas regras do progresso offline |
| Nível atingido exatamente no limiar | O limiar é inclusivo: 25 de força já é nível 2 |
| Carinho durante `EATING` ou `TRAINING` | Recusado sem efeito e sem consumir a recarga; sem mensagem de erro |
| Carinho com vínculo abaixo de 10 | Aceito e creditado normalmente; apenas sem reação dedicada |
| Carinho repetido em sequência | Limitado pela recarga; cliques extras não creditam vínculo |
| Limiar de vínculo cruzado durante `EATING` | O comportamento afetivo fica disponível a partir do próximo estado interrompível |
| Reação cômica sorteada | Ocorre após a força já ter sido creditada; nunca altera a recompensa |
| Jogador ignora os halteres por completo | Progressão continua viável até o nível 5 apenas com flexões |

---

## 22. Critérios de aceitação

O MVP está concluído quando todos os itens abaixo forem verificáveis por uma pessoa, sem conexão com a internet:

* [ ] Caramelo aparece corretamente no cenário do quintal.
* [ ] Comer funciona: seleção, caminhada, animação e efeito nos atributos.
* [ ] Treinar funciona: seleção, caminhada, preparação, loop, conclusão e recompensa.
* [ ] Descansar funciona e recupera energia de forma contínua.
* [ ] `energy` é atualizada corretamente e nunca sai do intervalo de 0 a 100.
* [ ] `strength`, `bond` e `level` são atualizados corretamente e nunca diminuem.
* [ ] Os cinco níveis podem ser alcançados.
* [ ] Flexões estão disponíveis desde o nível 1 e halteres a partir do nível 3.
* [ ] É possível sair do nível 1 sem alimentar Caramelo nenhuma vez.
* [ ] É possível alcançar o nível 3 usando somente flexões.
* [ ] O desbloqueio do nível 2 é apenas visual e não introduz nenhum sistema novo.
* [ ] Os comportamentos afetivos surgem nos limiares de vínculo 10, 25 e 50.
* [ ] `bond` não concede nenhum bônus de força, energia ou velocidade.
* [ ] O carinho credita +1 de vínculo, respeita a recarga e é recusado em `EATING` e `TRAINING`.
* [ ] A reação cômica ocorre em cerca de 10% dos exercícios e nunca altera a recompensa.
* [ ] As recargas de alimento continuam correndo com o aplicativo fechado.
* [ ] O cenário contém todos os elementos fixados na seção 6, e apenas o pote e Caramelo são clicáveis.
* [ ] A aparência muda uma única vez, na subida para o nível 4, com mudança real de silhueta.
* [ ] O nível 5 entrega pose final e efeito de conquista, sem introduzir uma terceira forma.
* [ ] O salvamento persiste após fechar e reabrir o aplicativo.
* [ ] O progresso offline não duplica recompensas em nenhuma sequência de fechar e abrir.
* [ ] Alterar o relógio do sistema não gera punição nem recompensa além do teto.
* [ ] Caramelo executa os cinco comportamentos autônomos sem interação.
* [ ] O jogo permanece visualmente interessante por dez minutos sem interação.
* [ ] A interface fica recolhida por padrão e aparece ao selecionar Caramelo.
* [ ] Toda ação principal é executável em no máximo três cliques.
* [ ] O jogo funciona em janela normal.
* [ ] O modo papel de parede funciona no Windows.
* [ ] O consumo de recursos pode ser reduzido, com efeito mensurável.
* [ ] As metas de FPS da seção 20 são atingidas: 60 ativo, 10 ocioso, 5 ou pausado em tela cheia.
* [ ] Existe forma clara de pausar e fechar o aplicativo.
* [ ] Todo o balanceamento pode ser alterado editando `data/*.json`, sem tocar no código.
* [ ] Todos os fluxos principais são testáveis sem conexão com a internet.

---

## 23. Decisões pendentes

### 23.1 Decisões resolvidas

Aprovadas em 2026-09-16 e já incorporadas ao corpo deste documento.

| # | Questão | Resolução |
| - | ------- | --------- |
| **D-1** | Progressão bloqueada no nível 1 | **Flexões disponíveis desde o nível 1.** O nível 2 passa a desbloquear apenas uma nova animação de comemoração; halteres seguem no nível 3 (seções 13 e 14) |
| **D-2** | Quantas formas visuais | **Exatamente duas:** inicial nos níveis 1–3, musculosa nos níveis 4–5. O nível 5 entrega pose final e efeito de conquista, não uma terceira forma (seção 15) |
| **D-3** | Função do vínculo | Desbloqueia **apenas comportamentos afetivos** nos limiares 10, 25 e 50, configuráveis por dados. Nenhum bônus de força, energia ou velocidade. O carinho entra como interação simples: sem custo de energia, +1 de vínculo, com recarga, recusado em `EATING` e `TRAINING` (seções 9 e 11) |
| **D-4** | Recargas dos alimentos | Provisoriamente ração 5 min, frango com arroz 15 min, pão de queijo 10 min; correm com o aplicativo fechado e ficam em dados (seção 12) |
| **D-5** | Reação cômica | Chance inicial de 10%, puramente visual, sem alterar a recompensa, sorteada apenas **depois** de a força ser creditada, configurável por dados (seção 13) |
| **D-6** | Consumo de recursos | Metas iniciais, não garantias: 60 FPS ativo, 10 FPS ocioso, 5 FPS ou pausado em tela cheia, CPU média abaixo de 2% em modo ocioso. Medição e ajuste na Etapa 12 (seção 20) |
| **D-7** | Conteúdo do quintal | Lista fechada de elementos; apenas o pote, Caramelo e os controles das atividades são interativos (seção 6) |

### 23.2 Suposições adotadas

Preenchem lacunas do escopo. São reversíveis — alterá-las muda apenas dados, não estrutura.

| # | Suposição | Impacto se mudar |
| - | --------- | ---------------- |
| S-1 | Descanso recupera **+1 de energia por minuto** (0 → 100 em ≈ 100 min), mesma taxa online e offline | Ritmo geral do jogo; só um número em `data` |
| S-2 | Comportamentos autônomos não consomem energia | Simplifica o balanceamento |
| S-3 | A recarga do carinho é curta (ordem de segundos), só para impedir vínculo infinito por cliques | Frequência de interação afetiva |
| S-4 | Animações: comer ≈ 4–5 s, `HAPPY` ≈ 2 s | Ritmo das animações |
| S-5 | Vínculo não tem teto; acima de 50 nada mais é desbloqueado no MVP | Nenhum, dentro do escopo |

### 23.3 Pontos ainda em aberto

Nenhum deles bloqueia as Etapas 2 a 4.

| # | Ponto | Quando resolver |
| - | ----- | --------------- |
| A-1 | Computador de referência para medir a CPU | Etapa 12 |
| A-2 | Confirmar em playtest as recargas (D-4) e a chance cômica (D-5) | Etapas 6 e 7 |
| A-3 | A taxa de recuperação de energia (S-1) nunca foi validada em uso real | Etapa 8 |
| A-4 | Estilo visual concreto do quintal — a lista de elementos está fechada, a direção de arte não | Etapa 3 |

### 23.4 Conflitos com documentos existentes

`MVP_SPEC.md` é a **fonte principal de requisitos do MVP**. `DESIGN.md` e `PLANO_MVP.md` permanecem intactos e valem como visão de longo prazo e roteiro de execução; onde divergirem do que está aqui, este documento prevalece.

| Documento | Divergência | Resolução |
| --------- | ----------- | --------- |
| `DESIGN.md` | Lista o quarto atributo como **Técnica** | No MVP o quarto atributo é `level`. `technique` fica **fora do MVP** |
| `DESIGN.md` | MVP com três exercícios (flexão, **corrida**, halteres), cinco acessórios e cinco eventos humorísticos | Reduzido a dois exercícios; acessórios e eventos roteirizados ficam fora |
| `DESIGN.md` | Cinco fases de evolução física nomeadas | O MVP tem cinco níveis, mas apenas duas formas visuais |
| `DESIGN.md` | Não define recargas de alimento nem limiares de vínculo | Fixados aqui (seções 9 e 12) |
| `PLANO_MVP.md` | Flexões desbloqueadas no **nível 2** | Substituído: flexões disponíveis no **nível 1** (D-1) |
| `PLANO_MVP.md` | Troca de forma visual "no nível 4 ou 5" | Substituído: troca única, no **nível 4** (D-2) |
| `PLANO_MVP.md` | Não menciona carinho como ação do jogador | Carinho **permanece** como fonte simples de vínculo, sem virar sistema próprio |

---

*Fim do MVP_SPEC. Todas as decisões que bloqueavam a implementação estão resolvidas. Próxima etapa: 2 — estrutura técnica do projeto Godot.*
