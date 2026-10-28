# Controles multiplataforma — joystick 360° e multitoque

## Arquitetura atual

Implementação local para Godot **4.7.2 stable (ed1daf0bf)**. O Player continua usando
`Input.get_axis("move_left", "move_right")` e `Input.is_action_*()`. Sua física,
colisões, coyote time, jump buffer, altura variável, habilidades e saves não foram
reescritos. Não há novo Autoload ou plugin externo.

O `InputDeviceManager` existente mantém uma única instância de
`ui/touch_controls/touch_controls.tscn`, fora das fases. O CanvasLayer 10 acompanha a
viewport; diálogo e inspeção continuam na camada 20. A cena contém:

```text
TouchControls
├── Controls
│   ├── JoystickContainer
│   │   └── VirtualJoystick
│   ├── ActionButtons
│   │   ├── JumpButton
│   │   ├── DashButton
│   │   ├── CrouchButton
│   │   └── InteractButton
│   ├── PauseButton
│   └── Diagnostics (somente no modo de teste)
└── InputGuard
```

Não instancie cópias nas fases. O HUD só aparece com Player vivo dentro da cena atual
e método touch apropriado. O Interactor é encontrado por grupo e associado ao ator,
sem caminho de nó fixo. Seu `target_changed` controla o botão contextual. Alvos
bloqueados continuam mostrando o requisito, sem executar efeitos.

## Causa dos comandos presos e correção

Antes desta correção, o Git continha alterações rastreadas em README, project.godot,
nível de teste, InputDeviceManager, Interactor e interfaces; os controles touch,
documento, preset Android e testes ainda eram arquivos não rastreados. As alterações
locais não relacionadas foram preservadas. Não houve commit nem push.

A implementação existente já tinha joystick horizontal, TouchActionSource e testes
de multitoque. A reprodução nova encontrou uma falha específica de propriedade:

1. Duas áreas de botão sobrepostas recebiam o mesmo ScreenTouch nativamente.
2. O roteador registrava somente um dono, mas os dois botões emitiam ações.
3. No release, o roteador liberava o dono e consumia o evento antes do outro botão.
4. A fonte não registrada permanecia pressionada. O mesmo risco existia entre
   joystick e botão quando suas áreas de captura se cruzavam.

O teste de sobreposição falhou **antes** da correção, tanto na exclusividade quanto
no estado final das ações; passou depois. Os botões agora conferem `owns_touch()`
antes de alimentar TouchActionSource. Uma ativação nativa sem autorização é
desfeita imediatamente, sem emitir comando de gameplay. O joystick também exige
essa autorização quando está no HUD, mantendo funcionamento isolado sem roteador.

Uma segunda causa foi reproduzida **com renderização ativa**: TouchActionSource
chamava `Input.flush_buffered_events()` dentro dos callbacks de entrada. Esse flush
reentrava na fila global enquanto o evento original ainda estava sendo distribuído.
Em lotes rápidos, releases deixavam de chegar ao roteador e o joystick/botões
permaneciam ativos. Os lotes passavam em headless, mas falhavam na execução gráfica.
O flush interno foi removido; a engine agora drena os eventos na fase normal de
entrada. Não foi aplicado temporizador nem mudança global de configuração do Input.

A captura passou de índice isolado para **(device, index)**. Toque físico e toque
emulado podem usar índice igual sem se soltarem ou se moverem mutuamente. Press
duplicado de um contato ativo é ignorado; após cancelamento/ocultação, um press novo
do mesmo identificador pode iniciar uma nova captura.

Não foi usado timeout, liberação periódica ou action_release() global. O módulo de
ações por fonte existente foi ajustado para não reentrar na fila. Nenhum HUD paralelo ou Autoload foi
criado, e os botões atuais continuam no mesmo lugar, incluindo Agachar como opção.

## Referências estudadas e decisão

Foram consultados código, documentação e arquivos de licença dos três repositórios:

| Referência / revisão consultada | Análise e decisão |
|---|---|
| [MarcoFazioRandom/Virtual-Joystick-Godot](https://github.com/MarcoFazioRandom/Virtual-Joystick-Godot/tree/b90891ee990881757105883677adbb619f4c319c), `b90891ee990881757105883677adbb619f4c319c` | Captura de um índice, clamp, deadzone, saída normalizada e modos fixo/dinâmico/following. É uma boa referência enxuta; sua integração direta usa action_press/action_release e mapeia quatro direções. |
| [Repechul/Virtual-Joystick-DX](https://github.com/Repechul/Virtual-Joystick-DX/tree/3f73b954cc1f2b65066e1a3e53aa9bed694c409b), `3f73b954cc1f2b65066e1a3e53aa9bed694c409b` | Separa matemática, região, visual e hardware. Oferece mais modos, D-pad, haptics e ações. Importar o pacote duplicaria detecção de dispositivos e acrescentaria funcionalidades fora deste escopo. |
| [Wesley-Source/versatile-mobile-joystick](https://github.com/Wesley-Source/versatile-mobile-joystick/tree/bea520bbebfbc8ef22c42ca68feecfeeaf298721), `bea520bbebfbc8ef22c42ca68feecfeeaf298721` | Distingue área de captura, deadzone, limite e curva de força; usa índice de dedo e modos fixo/dinâmico. Suas ações verticais e liberação global não são adequadas ao contrato deste jogo. |

Na pesquisa anterior, os três tiveram licença MIT verificada: [Marco Fazio, 2019](https://github.com/MarcoFazioRandom/Virtual-Joystick-Godot/blob/b90891ee990881757105883677adbb619f4c319c/LICENSE),
[Repechul (Bugrhak), 2026](https://github.com/Repechul/Virtual-Joystick-DX/blob/3f73b954cc1f2b65066e1a3e53aa9bed694c409b/LICENCE) e
[Wesley Carlos, 2024](https://github.com/Wesley-Source/versatile-mobile-joystick/blob/bea520bbebfbc8ef22c42ca68feecfeeaf298721/LICENSE).

**Escolha:** implementação local original baseada nos conceitos estudados, sem
copiar código, texturas, cenas ou importar plugins. Não há componente MIT incorporado
ou licença de terceiros a redistribuir nesta implementação. Os links/revisões acima
registram a pesquisa; a detecção já existente do projeto foi reaproveitada.

## Joystick e Input Map

`virtual_joystick.tscn` é um componente Node2D reutilizável, sem dependência de Player,
InputDeviceManager, caminho de HUD ou sistema operacional. Sua posição é fixa no
canto inferior esquerdo. A conversão de coordenadas está em `_local_point()`; uma
futura opção dinâmica pode alterar a origem sem modificar a tradução das ações.
O modo dinâmico **não está implementado** nesta entrega.

Um ScreenTouch dentro de `touch_radius` captura `finger_index` e `finger_device`.
Somente ScreenDrag desse contato altera a saída. Outros dedos não podem roubar a
captura ou soltá-la. O dedo pode sair da área inicial durante o arraste: a captura é
mantida e o deslocamento é limitado. Soltar/cancelar libera imediatamente as ações;
o visual retorna suavemente ao centro.

O joystick agora produz `output: Vector2`, com comprimento de 0 a 1, e o visual se
move em 360° dentro de um limite circular. A deadzone é radial e a força restante é
remapeada continuamente. A resposta em X puro preserva a intensidade anterior.

```text
r = limit_length(deslocamento_local, max_radius) / max_radius
output = ZERO se length(r) <= deadzone
output = normalized(r) * (length(r) - deadzone) / (1 - deadzone), nos demais casos
move_left  = max(-output.x, 0)
move_right = max( output.x, 0)
```

A deadzone começa em **0,15**. Não há latência artificial no movimento: a suavização
é somente visual. `output_changed(Vector2)` informa a saída; `output_x` permanece
como leitura de compatibilidade. A classe se chama `TouchVirtualJoystick`, no mesmo
arquivo/cena e com o mesmo UID. Os consumidores locais foram atualizados.

### Agachamento com histerese

Os limiares se aplicam ao **Y de output, após deadzone e normalização**:

- Y >= `crouch_activate_threshold` (padrão 0,60): pressionar a ação `crouch`.
- Y <= `crouch_release_threshold` (padrão 0,40): liberar a fonte do joystick.
- Entre os limiares: manter o estado anterior, sem oscilações ou eventos repetidos.

Configure liberação menor que ativação; o cálculo limita configurações inválidas
para preservar uma banda de histerese. Comparações nos limites toleram erro numérico
de ponto flutuante. Centro, cima, release e cancelamento deixam essa fonte neutra.
Y não gera movimento vertical e cima não dispara pulo.

Baixo/esquerda e baixo/direita mantêm **movimento e crouch simultaneamente**. A saída
diagonal máxima é aproximadamente (±0,707, 0,707), suficiente para ativar o limiar
padrão. O Player conserva redução de velocidade, colisão, contato com o chão,
restrição de pulo agachado e verificação de espaço para levantar.

O botão Agachar foi mantido. Joystick, botão e teclado/gamepad são fontes
independentes: centralizar o analógico não libera o botão nem S ainda pressionados;
soltar o botão também não libera um analógico que continua inclinado para baixo.

## Uma única tradução de ações virtuais

`TouchActionSource` é um pequeno RefCounted compartilhado pelo joystick e pelos
botões. Cada instância recebe um `device_id` virtual exclusivo por contador. Ela
mantém somente as forças que possui, ignora valores repetidos e gera um novo
`InputEventAction` para cada mudança, com:

- `action`: a ação original do Input Map;
- `event_index = -1`: slot virtual separado dos atalhos físicos;
- `device`: identificador da mesma fonte no press, atualização e release;
- `pressed` e `strength`: estado/força de 0 a 1.

O evento entra por `Input.parse_input_event()` e a engine o distribui na fase normal
de entrada, atualizando consultas globais e `_input/_unhandled_input`. Não há flush
da fila global dentro de `_input`, pressed, released ou TouchActionSource. Cada
envio cria outro objeto de evento, conforme a API 4.7.2. A liberação também é um
InputEventAction da mesma fonte; **não usa action_release() global**.

Os testes que usam `Viewport.push_input()` drenam a fila explicitamente **depois**
que a chamada retorna da árvore, na fronteira do fixture. Os testes de lote usam
`Input.parse_input_event()` para enfileirar todos os contatos e só então drenam uma
vez. Isso verifica a situação real que não era coberta por eventos isolados.

Essa estratégia permite teclado/gamepad e touch simultâneos. Soltar o joystick não
cancela uma tecla física ainda pressionada, e vice-versa. Fontes independentes da
mesma ação são combinadas pela Godot. Isso foi testado nos dois sentidos, incluindo
força analógica parcial, sem modificar os eventos do Input Map.

Os botões continuam sendo `TouchScreenButton`, com captura nativa multitouch e
CircleShape2D maior que o desenho. Configure `action` no Inspector: em `_ready()`, o
adaptador armazena-a em `input_action` e esvazia somente o emissor nativo para evitar
que ele envie um segundo comando. Seus sinais passam exclusivamente por
TouchActionSource. `passby_press` fica desligado para ações discretas.

Não acrescente action_press(), action_release(), outro parse, push_input() ou uma
chamada manual ao Interactor nos sinais dos botões. `interact` já alcança o fluxo
existente uma vez; `pause` chega ao menu existente. Press/release de jump preservam
buffer, coyote time e altura variável. Dash/agachar continuam passando pelas regras
do Player.

Referências da API: [InputEventAction](https://docs.godotengine.org/en/stable/classes/class_inputeventaction.html),
[Input](https://docs.godotengine.org/en/stable/classes/class_input.html) e
[código da engine instalada](https://github.com/godotengine/godot/blob/ed1daf0bf/core/input/input.cpp).

## Captura, contexto e liberação

O InputGuard, último filho, executa antes dos componentes e atribui um dono por
(device, index). Cada componente verifica essa atribuição antes de ativar ações,
inclusive quando shapes se sobrepõem. Um botão aceita um contato por vez; dedos
extras sobre esse mesmo botão não viram fontes adicionais. Componentes diferentes
da mesma ação, como joystick e botão Agachar, têm fontes independentes.

Release e canceled liberam só o dono correspondente, independentemente da posição
do dedo. Cancelar não vira pressionamento. Contatos já cancelados são consumidos
até release; um press novo pode rearmá-los. Press repetido enquanto o mesmo contato
continua válido não produz outro comando nem bordas artificiais.

A filtragem de mouse acompanha somente a sequência cujo press começou sobre um
controle de gameplay. Não bloqueia indiscriminadamente mouse emulado de outra
interface porque existe algum dedo capturado. Menus continuam usando a emulação da
Godot e Buttons nativos. Na mudança para uma interface, levante os dedos de gameplay
antes de iniciar os gestos de interface: a emulação nativa de mouse usa um ponteiro.

| Estado | Resultado |
|---|---|
| Desktop normal | HUD oculto; teclado/mouse e gamepad preservados |
| Mobile com touch ativo | HUD disponível em gameplay |
| Gamepad utilizado | HUD oculto; liberar somente fontes touch |
| Voltar ao toque / desconectar gamepad ativo | HUD disponível novamente |
| Diálogo / inspeção / pausa / SaveManager em transição | Gameplay touch oculto e liberado |
| Player removido / cena trocada / HUD oculto / perda de foco | Capturas e fontes virtuais liberadas |
| Redimensionamento ou mudança de layout | Liberar entrada e exigir novo press |

O HUD escuta os sinais existentes e também verifica os estados reais no processo,
incluindo pausa externa e transições. Não duplica sua instância ao carregar fases.
Cada componente também libera suas fontes ao sair da árvore. Não há alteração no
SaveManager nem no formato do save.

DialogueUI mantém o botão de avançar/completar digitação; o frame de encerramento do
DialogueManager continua impedindo uma nova interação. InspectionUI mantém imagem
proporcional, ScrollContainer e fechamento por toque. PauseMenu conserva retomar,
salvar e retorno ao menu. O menu principal conserva nova partida/continuar.

## Dispositivos e glyphs

A API existente do InputDeviceManager foi preservada. `current_device` controla a
apresentação; `last_used_device` registra uso recente e `touchscreen_available`
representa disponibilidade. A detecção usa eventos, com filtro de drift dos eixos.
Conectar um gamepad não esconde o HUD até utilizá-lo. O layout manual permanece.

`InputEventAction` é ignorado pela detecção: o ID virtual nunca é interpretado como
gamepad. Mouse com DEVICE_ID_EMULATION também é ignorado. Toque emulado de mouse só
altera apresentação durante o teste touch e não marca touchscreen físico disponível.
No desktop, voltar a teclado/mouse recupera a apresentação física mesmo depois de
um toque. Em mobile, teclado/mouse físico conserva a disponibilidade do touch.

Xbox é o fallback; PlayStation/Nintendo continuam reconhecidos por nome e 8BitDo
segue o modo exposto pelo firmware. `set_layout_override("xbox"/"playstation"/
"nintendo")` resolve nomes ambíguos; `"auto"` retoma detecção. InputGlyphResolver e
PromptAnchor não foram alterados. Touch continua exibindo **Toque**.

## Ajustes no Inspector

Na raiz de `touch_controls.tscn`:

- `button_size`, `jump_size_multiplier`: tamanho das ações e destaque do pulo.
- `joystick_scale`, `joystick_offset`: tamanho e deslocamento da ilha esquerda.
- `actions_offset`, `pause_offset`: ajuste separado da ilha direita e pausa.
- `spacing`, `margin`, `opacity`: distância, margem e transparência.
- `respect_safe_area`: áreas seguras via SafeAreaLayout, reaproveitado pelas UIs.
- `show_debug_values`: X/Y, ação crouch e dono do joystick, somente no modo de teste.

No VirtualJoystick: `deadzone`, `max_radius`, `touch_radius` (captura ampliada),
`base_radius`, `knob_radius`, `visual_return_speed`, `action_crouch`,
`crouch_activate_threshold` e `crouch_release_threshold`. Nos botões, `touch_padding`
aumenta a Shape2D além do círculo desenhado. Configure os valores na cena antes de
executar; o layout do HUD também acompanha ajustes de tamanho/posição em runtime.

O layout limita os centros à área segura, considera o tamanho visual e de captura
do joystick e usa escala uniforme em proporções menores. O layout padrão foi
testado sem sobreposição, inclusive considerando as áreas ampliadas dos botões.
Deslocamentos personalizados ainda exigem revisão visual para evitar colisões
escolhidas manualmente.

Para acrescentar ação: cadastre-a no Input Map, duplique um botão de ActionButtons,
defina `action`/`caption` e adicione sua posição a `_layout()`. Para remapear eventos
em runtime, libere os controles antes de alterar o Input Map.

## Testar no PC

Abra `scenes/prototypes/touch_controls_preview.tscn` e pressione **F6**. Essa cena
ativa o modo debug touch e entra no laboratório existente com saves isolados. O
laboratório começa com dash/pulo duplo bloqueados; use os desbloqueios da fase para
verificar habilidades. Pare com **F8** e execute o projeto normalmente para voltar.

Alternativamente, substituindo godot pelo executável instalado:

```powershell
godot --path . -- --touch-controls
godot --path . --resolution 1280x720 -- --touch-controls
godot --path . --resolution 2400x1080 -- --touch-controls
```

O argumento precisa vir depois de `--`. A opção só habilita em build debug; não fica
ativa em produção. `set_touch_test_mode(false)` também desativa durante a sessão e
restaura a emulação original. No teste forçado, o HUD permanece disponível mesmo com
gamepad; desative-o para testar a ocultação automática normal.

O mouse representa um dedo: clique dentro da base e arraste. Observe X/Y e crouch
no rodapé, o zero dentro da deadzone e o retorno ao soltar. Arraste para baixo e
para as duas diagonais inferiores; confira a histerese antes de soltar. Combine mouse no joystick
com teclado para pular/dash/agachar; dois ou três dedos reais exigem uma touchscreen.
Os testes sintéticos usam índices separados. Redimensionar libera a entrada:
levante e pressione novamente.

Teste gamepads via USB/Bluetooth: use o controle, observe glyphs, desconecte-o durante
movimento e volte ao touchscreen. Teste Xbox, DualShock/DualSense, Switch e os modos
XInput/Switch de 8BitDo. O override de glyph não corrige mapeamento de driver.

## Android/iOS e roteiro em aparelho real

project.godot e o preset Android da etapa anterior foram preservados: referência
1152×648, landscape, canvas_items/expand, Compatibility e emulação de mouse por
touch habilitada. A emulação inversa só é ativada pelo teste debug. Física e qualidade
gráfica não foram alteradas.

Instale templates da **mesma Godot 4.7.2**, Java SDK e Android SDK exigidos pela engine;
configure Editor Settings → Export → Android. A máquina da entrega continua sem os
templates e o SDK configurado completo. O preset usa ARM64 e identificador provisório
`org.jogoinfor.game`: ajuste identidade, versão, ícones e assinatura antes de publicar.

```powershell
godot --headless --path . --export-debug Android C:/pasta-fora-do-repo/JogoInfor.apk
```

Nenhuma exportação Android nova foi validada nesta refatoração. A validação anterior
falhou por templates, Java SDK e ausência de platform-tools/adb/build-tools/apksigner.
Para iOS, são necessários macOS, Xcode, templates correspondentes e assinatura Apple;
a exportação iOS não foi testada na máquina Windows.

Checklist no aparelho:

1. Saída progressiva em 360°, zona morta radial, limite circular, retorno ao centro,
   arraste fora da área e segundo dedo sem roubar captura.
2. Joystick+pulo/dash/agachar; pulo curto/longo, coyote/buffer, pulo duplo, wall jump
   e slide após desbloqueios.
3. NPCs, portas, alavancas e requisitos bloqueados; cada toque executa uma vez.
4. Diálogo: completar digitação, avançar, terminar sem reabrir interação. Inspeção:
   arrastar texto longo, ver imagem e fechar.
5. Pausar com joystick inclinado, soltar dedos, retomar/salvar/continuar e voltar ao
   menu. Trocar/recarregar cenas e confirmar que não há controles duplicados.
6. Teclado/gamepad simultâneos ao touch, conexão e desconexão, modos dos gamepads.
7. Interromper toques, bloquear tela, alternar aplicativo e recuperar foco.
8. Recortes, barras do sistema, resolução, escala física dos alvos e desempenho.
9. Segurar baixo no joystick e botão Agachar simultaneamente; soltar uma fonte por
   vez, nas duas ordens, incluindo S ou gamepad ainda pressionados.
10. Oscilar o Y da saída entre 0,45 e 0,55, primeiro com crouch desligado e depois
    ligado. O estado deve permanecer até cruzar o limiar oposto.

## Testes automatizados e limites

```powershell
godot --headless --path . --editor --import
godot --headless --path . res://tests/runner.tscn
godot --headless --path . res://tests/physics_dialogue_runner.tscn
godot --headless --path . res://tests/interaction_runner.tscn
godot --headless --path . res://tests/modular_runner.tscn
godot --headless --path . res://tests/touch_runner.tscn
godot --path . --resolution 1152x648 res://tests/touch_runner.tscn
```

As suítes antigas incluem falhas deliberadas de saves/efeitos: avalie a conclusão,
o código de saída e a origem das mensagens, não apenas a presença da palavra ERROR.
A suíte touch testa eventos sintéticos pela árvore, emulação de mouse em Buttons,
multitoque, cancelamentos, mistura com fontes físicas, contexto, layout e transições
reais via SaveManager. Logs de importação e touch devem estar sem erros de script.

Headless e renderização no PC **não validam multitoque em celular**, drivers de
controle, Bluetooth, recortes reais ou exportação. O modo fixo é o único disponível;
reposicionamento dinâmico, layout canhoto, haptics e preferências de acessibilidade
ficam para evolução posterior.

## Arquivos desta refatoração

Resultados executados nesta entrega, em 27/10/2026:

| Verificação | Resultado |
|---|---|
| Importação headless | Saída 0; log sem erros de parsing/scripts |
| Save | 159 verificações, 0 falhas |
| Física/diálogo | 88 verificações, 0 falhas |
| Interações | 51 verificações, 0 falhas |
| Sistemas modulares | 124 verificações, 0 falhas |
| Joystick/touch headless | 496 verificações, 0 falhas |
| Joystick/touch com renderização ativa | As mesmas 496 verificações, 0 falhas |
| Capturas gráficas | Laboratório, joystick em diagonal inferior, inspeção e puzzle |
| git diff --check / indentação GDScript | Sem erros de whitespace ou indentação por espaços |

Total headless: **918 verificações sem falhas**, todas as suítes com saída 0.
Os logs também foram inspecionados: física/diálogo e touch sem erros; mensagens de
save inválido, condições circulares e efeitos interrompidos pertencem aos cenários
de falha deliberada das suítes antigas. A execução gráfica touch terminou com saída
0 e stderr vazio. Comparações de SHA-256 confirmaram a preservação de project.godot,
nível modificado anteriormente, Player, SaveManager, DialogueManager, glyph resolver
e scripts das interfaces preexistentes.

As verificações touch incluem todas as seis ordens de liberação de três dedos,
pares rápidos em um único lote, cancelamento de um dedo mantendo outro, sobreposição
de botões/joystick, press duplicado, índices iguais em origens física/emulada,
joystick e botão Agachar nas duas ordens de release, teclado físico sustentado,
diagonais com a redução de velocidade original do Player, limites exatos e ajustes
de histerese, pause em lote, quatro contatos ao pausar, transição com três contatos,
destruição/recriação do HUD pressionado e estados neutros após cada cenário.

Antes da correção, a nova reprodução de sobreposição falhava em duas verificações;
a execução gráfica dos lotes apresentou 11 falhas de estado. Ambas passaram após
as correções de propriedade e de flush reentrante. A captura `joystick_360.png`
mostra aproximadamente X=+0,71, Y=+0,71 e crouch ativo. Esses resultados não equivalem
à validação em touchscreen Android/iOS.

Nesta correção não foram criados nem removidos arquivos ou nós de HUD.

Modificados: `ui/touch_controls/virtual_joystick.gd`, `touch_action_button.gd`,
`touch_controls.gd`, `touch_action_source.gd`, `tests/test_touch_controls.gd`,
`tests/preview_systems.gd` e este documento. Cenas e UIDs existentes foram mantidos;
os tipos locais foram atualizados para `TouchVirtualJoystick`.

Reaproveitados sem alteração nesta correção: InputDeviceManager, SafeAreaLayout,
Player, Interactor, DialogueManager, InputGlyphResolver, SaveManager/GameState,
menus, cenas do laboratório, preset Android, project.godot e alterações locais
anteriores não relacionadas. A física continua coberta pelas suítes de regressão.
