# Como Aumentar Seu Caramelo — Documento de Design

**Gênero:** idle game, pet virtual e papel de parede interativo
**Plataforma inicial:** Windows
**Engine:** Godot (2D)
**Fantasia central:** cuidar, treinar e personalizar um legítimo vira-lata caramelo até ele se tornar uma lenda musculosa do bairro.

O humor deve vir das animações, situações e referências culturais — não de textos ou memes colados na interface.

## Regra central

> Caramelo come para obter energia, treina para transformar energia em força e descansa para consolidar seu progresso.

## Ciclo principal

1. Caramelo sente fome ou escolhe uma atividade.
2. O jogador oferece uma comida.
3. A comida gera energia e outros efeitos temporários.
4. O jogador seleciona um exercício ou deixa Caramelo decidir.
5. Caramelo treina durante alguns minutos.
6. O treino produz força, experiência e possíveis eventos.
7. Caramelo descansa.
8. Ao subir de nível, sua aparência, seus exercícios e o ambiente evoluem.

O jogador pode intervir, mas Caramelo também age sozinho — é isso que o mantém interessante como papel de parede.

## Ações de Caramelo

### Comportamentos autônomos

Enquanto o usuário trabalha, Caramelo pode: caminhar pelo cenário; dormir em uma cadeira de plástico; observar a rua pela janela; brincar com uma bola; perseguir uma mosca; procurar comida; cheirar objetos novos; latir para um entregador fora da tela; fazer pose diante de um espelho; falhar comicamente durante um exercício; interagir com outros animais; reagir ao ponteiro do mouse; comemorar quando o jogador retorna.

Essas ações não precisam gerar recursos. Sua função principal é transmitir personalidade e vida.

### Alimentação

| Alimento         | Efeito sugerido                 |
| ---------------- | ------------------------------- |
| Ração            | Energia equilibrada             |
| Frango com arroz | Recuperação após o treino       |
| Pão de queijo    | Felicidade temporária           |
| Açaí             | Energia rápida                  |
| Água de coco     | Recuperação de disposição       |
| Espetinho        | Grande bônus, aparecimento raro |
| Marmita fitness  | Bônus para ganho de força       |

Não transformar o jogo em simulador nutricional. Os alimentos brasileiros funcionam como identidade visual e escolhas estratégicas simples.

### Exercícios

Caramelo começa com movimentos improvisados e desbloqueia equipamentos melhores: correr atrás de uma moto imaginária; buscar uma bola; cabo de guerra; agachamento; flexão; flexão usando barras; levantamento de halteres; supino; levantamento de peso; corrida na praia; treino de agilidade em campo de futebol.

Cada exercício tem três animações: normal, falha engraçada e execução perfeita.

### Descanso

Dormir no sofá; deitar em frente ao ventilador; cochilar ao sol; dormir dentro de uma caixa pequena demais; ocupar a cama de outro animal; sonhar com comida ou exercícios.

O jogador não deve ser obrigado a esperar ativamente. Descanso e treinamento continuam com o aplicativo fechado.

## Ações do jogador

Interações de poucos segundos: alimentar; escolher o próximo exercício; fazer carinho; elogiar uma boa execução; ajudar em um minijogo curto; trocar roupas e acessórios; posicionar móveis e objetos; fotografar uma cena; enviar Caramelo para outro ambiente; convidar ou selecionar outro pet; ativar o modo silencioso; consultar o diário de progresso.

Interação de "motivação": o jogador clica ou movimenta o mouse no ritmo certo durante alguns segundos, dando um pequeno bônus ao exercício. Opcional, sem invalidar o progresso idle.

## Evolução física

Transformação gradual, mantendo Caramelo reconhecível.

| Fase                  | Aparência              | Conteúdo desbloqueado         |
| --------------------- | ---------------------- | ----------------------------- |
| 1 — Caramelinho       | Magro e desajeitado    | Comida, carinho e bola        |
| 2 — Ativo             | Corpo saudável         | Corrida e cabo de guerra      |
| 3 — Maromba de bairro | Primeiros músculos     | Halteres e acessórios fitness |
| 4 — Caramelo forte    | Peito e patas robustos | Supino e desafios             |
| 5 — Lenda nacional    | Musculoso e confiante  | Competições e itens especiais |

Cada fase altera: silhueta, postura, forma de caminhar, animações de exercício, reações dos outros personagens e intensidade das poses.

A evolução final não pode parecer desconfortável ou assustadora. O objetivo é um exagero carismático de desenho animado.

### Atributos

* **Energia:** usada nos exercícios.
* **Força:** principal progressão física.
* **Vínculo:** desbloqueia interações e comportamentos.
* **Técnica:** melhora a execução dos exercícios.

Fome e felicidade são estados temporários, sem punições graves. Caramelo nunca adoece nem perde níveis por ausência do jogador.

## Outros animais

Cada pet tem comportamento próprio, não apenas uma nova aparência: gato rajado desconfiado; papagaio que imita sons do jogo; pinscher extremamente corajoso; capivara tranquila; vira-lata preto companheiro; calopsita que pousa nos equipamentos.

Bônus leves — o gato melhora o descanso, o pinscher aumenta a motivação, a capivara reduz a perda de energia.

Interações entre animais: dormir juntos; disputar um brinquedo; treinar em dupla; roubar comida; reagir às roupas uns dos outros; formar amizades ou rivalidades.

## Roupas e acessórios

Camisa da seleção em versão fictícia; regata de academia; bermuda de praia; chinelo como objeto carregável; óculos espelhados; bandana; corrente dourada cartunesca; chapéu de festa junina; capa de chuva; fantasia de carnaval; coleiras e medalhas; luvas de treino.

Evitar marcas, escudos e personagens protegidos — criar versões originais inspiradas no cotidiano brasileiro.

## Ambientes

Começa no quintal brasileiro e expande para: sala com sofá e ventilador; academia improvisada na garagem; laje ao entardecer; praça do bairro; praia; feira de rua; festa junina; campo de futebol; calçadão; academia completa.

Itens decorativos: cadeira de plástico, churrasqueira, caixa térmica, plantas, azulejos, rede, rádio, varal, pôsteres e equipamentos improvisados.

O Brasil não aparece apenas por verde e amarelo. Usar arquitetura, vegetação, iluminação, objetos cotidianos, música e linguagem para produzir identidade autêntica.

## Humor brasileiro

### Animações
Caramelo encara o halter antes de desistir; um pinscher tenta levantar um peso enorme; o papagaio atua como treinador; Caramelo faz pose exagerada após um exercício fácil; uma capivara ocupa o banco de supino e se recusa a sair.

### Textos originais
"Hoje o treino sai." · "Foi buscar o shape." · "Personal disse que valeu." · "Descanso também é treino." · "Projeto Caramelo." · "Monstro do quintal." · "Treino pago, treino feito."

### Eventos inspirados em formatos de meme
Expectativa versus realidade; antes e depois; narrador dramático; reação exagerada de outro animal; objeto simples tratado como recompensa lendária.

Criar piadas originais inspiradas no humor brasileiro em vez de copiar imagens, bordões ou personagens protegidos.

## Funcionamento como papel de parede

* Caramelo ocupa principalmente a parte inferior da tela.
* Os controles aparecem somente quando ele é selecionado.
* O jogo reduz animações durante aplicativos em tela cheia.
* Existe modo silencioso e modo de baixo consumo.
* Notificações são opcionais.
* O jogo salva automaticamente.
* O progresso offline possui um limite razoável.
* A inicialização com o sistema exige consentimento.
* Caramelo nunca cobre permanentemente botões ou janelas.

Bandeja do sistema: abrir painel · alimentar rapidamente · iniciar treino · alternar ambiente · modo silencioso · pausar animações · fechar.

## Primeiro protótipo (MVP)

* Um Caramelo com duas formas físicas.
* Um quintal.
* Cinco comportamentos espontâneos.
* Três alimentos.
* Flexão, corrida e halteres.
* Energia, força e vínculo.
* Sistema simples de níveis.
* Cinco acessórios.
* Cinco eventos humorísticos.
* Progresso offline.
* Modo papel de parede e janela normal.
* Salvamento local.

### Perguntas que o protótipo precisa validar

1. É agradável deixar Caramelo visível durante o trabalho?
2. As pessoas retornam espontaneamente para observar sua evolução?
3. A transformação física gera curiosidade suficiente para continuar jogando?

Se isso funcionar, entram os outros pets, ambientes, decoração, histórias e eventos sazonais.

## Arquitetura

* **Engine:** Godot, 2D.
* **Caramelo como máquina de estados:** `ocioso`, `comendo`, `treinando`, `descansando`, `brincando`, `interagindo`.
* **Atributos e progressão separados das animações.**
* **Papel de parede como camada específica da plataforma**, permitindo que o mesmo jogo rode em janela convencional.
