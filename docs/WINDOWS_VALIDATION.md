# Validação em Windows — Etapa 12

**Nenhum item deste documento foi executado.** O ambiente de desenvolvimento é Linux
(Ubuntu 22.04, Godot 4.4.1) e não tem Windows, PowerShell, Wine nem os *export templates*
do Godot instalados. Tudo o que envolve `Progman`/`WorkerW`, atalho de inicialização e
detecção de tela cheia foi escrito com isolamento de plataforma e exercitado por testes
com dublê — **o comportamento real no Windows continua não verificado**.

Quem rodar esta lista deve marcar cada item só depois de executá-lo de verdade, numa
máquina Windows, com o pacote exportado. Um item que falhar vale mais registrado do que
corrigido às pressas: anote o que aconteceu e em qual versão do Windows.

## Antes de começar

1. Gerar o pacote numa máquina com os *export templates* instalados:

   ```bash
   tools/build_windows.sh
   ```

   O resultado fica em `build/windows/`: o executável, o `.pck` e a pasta
   `platform/windows/` com os três helpers PowerShell. **Copie a pasta inteira** — o jogo
   procura os helpers ao lado do executável.

2. Conferir a política de execução do PowerShell:

   ```powershell
   Get-ExecutionPolicy -Scope CurrentUser
   ```

   Em `Restricted` (padrão de muitas instalações) os helpers são bloqueados e o jogo
   **permanece em janela**, avisando. Isso é comportamento esperado, não defeito. Para
   permitir, e só se quem usa a máquina concordar:

   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   ```

   O jogo nunca usa `-ExecutionPolicy Bypass` por conta própria.

3. Anotar a versão do Windows, a resolução, a escala de tela e quantos monitores estão
   ligados. As três coisas mudam o resultado.

## Roteiro

| # | Item | Como verificar | Resultado |
| - | ---- | -------------- | --------- |
| 1 | Abrir em janela | Executar o `.exe`; a janela abre decorada e redimensionável | ☐ |
| 2 | Alterar para sem bordas | HUD → **Ajustes** → **Janela sem bordas** | ☐ |
| 3 | Voltar para janela | **Ajustes** → **Janela**; a decoração e a geometria voltam | ☐ |
| 4 | Ativar wallpaper | **Ajustes** → **Papel de parede** → confirmar; o jogo vai para trás dos ícones | ☐ |
| 5 | Confirmar ícones visíveis | Os ícones do desktop continuam por cima e clicáveis | ☐ |
| 6 | Confirmar barra de tarefas | A barra continua visível e utilizável, sem sobreposição permanente | ☐ |
| 7 | Testar interação | Com `Interagir no papel de parede` ligada, clicar em Caramelo (ver limitação abaixo) | ☐ |
| 8 | Abrir aplicativo em tela cheia | Abrir um vídeo ou jogo em tela cheia por ~10 s | ☐ |
| 9 | Confirmar perfil de 5 FPS | Voltar ao jogo e conferir o rodapé de diagnóstico ou o uso de CPU | ☐ |
| 10 | Voltar ao desktop | Fechar o aplicativo em tela cheia | ☐ |
| 11 | Confirmar recuperação para 10 FPS | O perfil volta a `baixo_consumo` em até ~5 s (intervalo da sondagem) | ☐ |
| 12 | Usar `Ctrl+Shift+W` | Com o jogo em papel de parede, o atalho devolve a janela | ☐ |
| 13 | Usar `--windowed` | `ComoAumentarSeuCaramelo.exe --windowed` abre em janela mesmo com wallpaper salvo | ☐ |
| 14 | Usar `--reset-window` | `ComoAumentarSeuCaramelo.exe --reset-window` devolve 1280 × 720 em (60, 60) | ☐ |
| 15 | Ativar autostart | **Ajustes** → **Iniciar com o sistema** → confirmar | ☐ |
| 16 | Reiniciar sessão | Sair e entrar de novo no Windows | ☐ |
| 17 | Confirmar inicialização | O jogo abre sozinho, no modo salvo | ☐ |
| 18 | Desabilitar autostart | **Ajustes** → desmarcar **Iniciar com o sistema** | ☐ |
| 19 | Confirmar remoção | `shell:startup` não tem mais `Como Aumentar Seu Caramelo.lnk` | ☐ |
| 20 | Fechar pelo HUD | **Ajustes** → **Fechar jogo** → confirmar | ☐ |
| 21 | Confirmar save | Reabrir: energia, força, vínculo e recargas continuam de onde pararam | ☐ |
| 22 | Corromper só as configurações | Editar `settings.json` para um texto inválido (**nunca** o `savegame.json`) | ☐ |
| 23 | Confirmar fallback seguro | O jogo abre em janela, com os padrões, e o save de jogo intacto | ☐ |
| 24 | Testar múltiplos monitores | Mover a janela para o segundo monitor, fechar, reabrir | ☐ |
| 25 | Testar escala 100%, 125% e 150% | Conferir que o HUD continua legível e dentro da tela em cada escala | ☐ |

Onde ficam os arquivos, para os itens 21 a 23:

```text
%APPDATA%\Godot\app_userdata\Como Aumentar Seu Caramelo\
    savegame.json           progresso
    savegame.backup.json    cópia anterior
    settings.json           preferências de desktop
```

## O que se espera que falhe, ou nem exista

Registrado antes do teste, para não virar surpresa:

* **Click-through seletivo não existe.** No modo papel de parede, a janela recebe os
  cliques na sua própria área. Não há recorte por região: o item 7 verifica se a interação
  funciona, não se o resto do desktop continua clicável através do jogo. Se isso atrapalhar,
  o caminho é voltar para janela — `Ctrl+Shift+W` — e não tentar contornar.
* **Bandeja do sistema não foi implementada.** O `MVP_SPEC.md` §19 a pede como forma
  sempre acessível de pausar ou fechar. O Godot 4 não tem API de bandeja, e adicionar uma
  extensão nativa está fora do escopo desta etapa. No lugar dela ficam o atalho
  `Ctrl+Shift+W`, o argumento `--windowed` e o botão **Fechar jogo** do painel.
* **A sondagem de tela cheia é uma aproximação.** Ela compara o retângulo da janela em
  primeiro plano com o monitor. Um aplicativo maximizado sem borda pode ser lido como tela
  cheia; o efeito prático é o jogo desenhar menos, nunca perder progresso.
* **A meta de CPU abaixo de 2% não foi medida em hardware real.** A máquina de
  desenvolvimento renderiza por software (Mesa llvmpipe), o que invalida qualquer número
  de CPU. O item a medir no Windows é o consumo em `baixo_consumo` com a janela minimizada.

## Como desfazer tudo

* **Sair do papel de parede:** `Ctrl+Shift+W`, ou abrir com `--windowed`.
* **Remover o autostart:** pelo painel, ou apagando o atalho em `shell:startup`.
* **Desinstalar:** apagar a pasta do pacote. O progresso fica em `%APPDATA%\Godot\...` e
  pode ser apagado à parte, se quiser mesmo perder o que Caramelo conquistou.
* **Nada foi escrito no registro**, nenhum serviço foi criado e nenhuma permissão de
  administrador foi pedida em momento algum.
