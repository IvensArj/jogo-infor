# Sistemas modulares e laboratório integrado

Implementação e validação em 27/10/2026, Godot 4.7.2 no Windows.
O [registro de inspeção](modular-gameplay-architecture.md) descreve a arquitetura
encontrada antes da implementação. As alterações locais anteriores foram preservadas.

## Arquitetura

Os componentes novos usam Interactor, Interactable e seu indicador existentes.
InteractionRequirement continua sendo a condição Resource (`is_met -> bool`),
InteractionEffect continua sendo a ação Resource (`execute -> bool`). Não foram
criados outro sistema de interação, outro SaveManager ou novos Autoloads.

Inspectable e GameplayEventTrigger especializam Interactable. SequenceSwitch
encaminha seu ID ao SequencePuzzle; apenas o puzzle guarda a tentativa em memória.
Uma InspectionUI atende documentos, livros e descrições. DialogueManager recebeu
somente a arbitragem de inspeção/diálogo e sinais de bloqueio; o jogador conserva
gravidade, atrito e colisão. A pausa verdadeira continua usando SceneTree.paused.

GameState conserva itens, eventos e flags. Habilidades usam flags booleanas
`abilities/dash`, `abilities/double_jump` e `abilities/wall_jump`. Leitura de
documentos, eventos e puzzles concluídos usam `completed_events`. O formato
JSON permanece v2, com leitura v1 e as mesmas validações, backup e rollback.
SaveManager não foi modificado. A posição continua sendo restaurada pelo fluxo
existente; [checkpoints permanecem uma proposta](checkpoint-policy.md).

## Arquivos criados

Cada script novo possui seu `.gd.uid`, gerado pelo Godot e mantido junto ao fonte.
Esses arquivos guardam identidade de recurso, não lógica adicional.

| Arquivo | Finalidade |
| --- | --- |
| `systems/inspection/inspection_data.gd` | Título, texto e imagem opcional compartilháveis. |
| `gameplay/objects/inspectable/inspectable.gd` | Interação, primeira leitura e projeção persistente. |
| `gameplay/objects/inspectable/inspectable.tscn` | Área reutilizável na camada 8 com visual provisório. |
| `ui/inspection/inspection_ui.gd` | Abertura, fechamento, foco, rolagem e conteúdo. |
| `ui/inspection/inspection_ui.tscn` | Uma única interface para todos os conteúdos. |
| `systems/abilities/ability_profile.gd` | Perfil configurável das três habilidades existentes. |
| `systems/abilities/default_profile.tres` | Padrão legado editável no Inspector, com todas as habilidades disponíveis. |
| `systems/interaction/gameplay_context.gd` | Validação de nós e ancestrais sem dependência circular entre a base de efeitos e Interactable. |
| `systems/interaction/requirements/ability_requirement.gd` | Consulta de habilidade. |
| `systems/interaction/requirements/condition_group.gd` | Grupos ALL/ANY com validação de ciclos por chamada. |
| `systems/interaction/effects/unlock_ability_effect.gd` | Desbloqueio idempotente. |
| `systems/interaction/effects/start_dialogue_effect.gd` | Abertura de diálogo com validação. |
| `systems/interaction/effects/activate_mechanism_effect.gd` | Ativação tipada de FlagInteractable por NodePath configurado. |
| `gameplay/objects/event_trigger/event_trigger.gd` | Condição, ações, entrada em área/interação e conclusão persistente. |
| `gameplay/objects/event_trigger/event_trigger.tscn` | Área reutilizável, camada 8 e máscara 1. |
| `gameplay/objects/sequence_puzzle/sequence_puzzle.gd` | Sequência, tentativa, sinais e conclusão. |
| `gameplay/objects/sequence_puzzle/sequence_switch.gd` | Switch integrado ao Interactable. |
| `gameplay/objects/sequence_puzzle/sequence_switch.tscn` | Botão reutilizável com colisão e visual. |
| `scenes/levels/systems_test_entry.tscn` | Entrada segura do laboratório. |
| `scenes/levels/systems_test_level.tscn` | Fase integrada; não faz parte da campanha. |
| `scenes/levels/systems_test/systems_test_entry.gd` | Inicia sessão antes de solicitar nova partida. |
| `scenes/levels/systems_test/systems_test_session.gd` | Isola paths/progresso e permanece viva nas recargas. |
| `scenes/levels/systems_test/systems_test_level.gd` | Controles e feedback exclusivos do laboratório. |
| `scenes/levels/systems_test/test_profile.tres` | Dash e pulo duplo bloqueados, parede liberada. |
| `scenes/levels/systems_test/letter.tres` | Carta provisória. |
| `scenes/levels/systems_test/object.tres` | Descrição com imagem gerada por GradientTexture2D. |
| `scenes/levels/systems_test/book.tres` | Livro provisório. |
| `scenes/levels/systems_test/long_document.tres` | Texto longo para rolagem. |
| `tests/modular_runner.tscn` | Runner automatizado dos novos sistemas. |
| `tests/test_modular_gameplay.gd` | Testes de componentes, entradas e persistência integrada. |
| `tests/preview_runner.tscn` | Runner gráfico sem substituir a cena principal. |
| `tests/preview_systems.gd` | Capturas reproduzíveis de fase, documento e puzzle. |
| `docs/modular-gameplay-architecture.md` | Inspeção e plano anteriores à implementação. |
| `docs/sistemas-modulares.md` | APIs, configuração, inventário e validação. |

## Arquivos existentes modificados

| Arquivo | Integração |
| --- | --- |
| `gameplay/player/player.gd` | Três guardas de habilidade e sinal de inspeção; parâmetros/física mantidos. |
| `systems/progress/game_state.gd` | Perfil padrão, consulta, desbloqueio e sinal; sem alterar import/export. |
| `systems/dialogue/dialogue_manager.gd` | Exclusão mútua de interfaces, referências fracas e encerramento seguro. |
| `systems/interaction/interactor.gd` | Oculta alvo e bloqueia nova interação durante inspeção. |
| `systems/interaction/interactable.gd` | Preflight de contexto, sequência compartilhada e hook de conclusão com resultado; API antiga preservada. |
| `systems/interaction/effects/interaction_effect.gd` | Validação de contexto e execução ordenada compartilhada. |
| `systems/interaction/flag_interactable.gd` | Método tipado activate; restauração permanece separada. |
| `systems/interaction/requirements/interaction_requirement.gd` | Validação de configuração compatível. |
| `systems/interaction/requirements/flag_requirement.gd` | Valida ID para composição. |
| `systems/interaction/requirements/item_requirement.gd` | Valida ID para composição. |
| `systems/interaction/requirements/event_requirement.gd` | Valida ID para composição. |
| `ui/pause_menu/pause_menu.gd` | Impede abertura sobre inspeção/diálogo ou carregamento. |
| `project.godot` | Configura ui_cancel existente com Esc e B; nenhum Autoload/cena principal alterado. |
| `docs/salvamento.md` | Documenta novas categorias usando o mesmo JSON. |
| `README.md` | Link para este guia. |

## APIs públicas e contratos

- `InspectionData`: `title`, `body`, `image`; apenas configuração.
- `InspectionUI.open_content(data, source) -> bool`, `close()`: foco e UI.
- `Inspectable`: `content`, `persistent_id`, `persistent_read`,
  `first_read_event_id`, `has_read`; sinal `first_read(actor)`.
- `DialogueManager`: `inspection_active`, `begin_inspection(source, ui) -> bool`,
  `end_inspection()`, sinais `inspection_started` e `inspection_finished` sem
  argumentos. `blocks_interaction()` inclui inspeção e o quadro de fechamento.
  A API anterior de diálogo continua compatível.
- `AbilityProfile.allows(id) -> bool`, propriedades `dash`, `double_jump`,
  `wall_jump`. `GameState.has_ability(id)`, `unlock_ability(id) -> bool`,
  `apply_ability_profile(profile) -> bool`, sinal `ability_unlocked(id)`.
- `InteractionRequirement.is_configured() -> bool`; `is_met(actor)` continua
  sendo a avaliação sem efeitos. Base = sempre true. FlagRequirement com
  expected_value=false aceita flag válida ausente; ID inválido é rejeitado.
- `ConditionGroup`: `mode`, `conditions`. ALL vazio = true; ANY vazio = false.
  A árvore inteira é validada antes da avaliação, inclusive ramos de ANY. Ciclos
  diretos/indiretos e filhos ausentes invalidam o grupo; a pilha é local à chamada.
- `InteractionEffect.validate_context(actor, source) -> bool` e
  `execute_sequence(actions, actor, source) -> bool`. Os efeitos antigos mantêm
  `is_valid()` e `execute()`. Preflight não aplica recompensas.
- `Interactable._complete_interaction(actor) -> bool`: hook adicional para
  componentes que podem falhar na conclusão. A implementação padrão chama
  `_on_interact(actor) -> void`, preservando subclasses e sinais antigos.
- `FlagInteractable.activate() -> bool`: interface tipada, sem métodos arbitrários
  por string. Restauração continua chamando `apply_persistent_state`, sem recompensas.
- `GameplayEventTrigger`: `activation_mode`, `condition`, `effects`, `event_id`,
  `one_shot` e `persistent_completion`. Conclusão é gravada após todas as ações.
- `SequencePuzzle.submit_switch(id, actor) -> bool`, `reset_attempt()`,
  `is_configured()`, `current_step`, `is_completed`; sinais `attempt_changed(step)`,
  `correct_input(id)`, `incorrect_input(id)`, `completed` e `completion_failed`.
- `SequenceSwitch`: `switch_id`, referência tipada `puzzle`; usa Interactable.
- `GameplayContext.is_live(node)`: considera árvore, objeto e ancestrais em exclusão.

Flags, itens, eventos, desbloqueios e ativações permanentes são repetíveis e
idempotentes. Uma habilidade já disponível retorna false em unlock_ability sem
novo sinal; UnlockAbilityEffect considera o estado já liberado um sucesso.
Diálogo falha se uma interface bloqueante estiver ativa. Sequências não são
transações: uma falha em execução interrompe as ações restantes, retorna false
e emite aviso com índice; efeitos anteriores podem permanecer aplicados. Coloque
efeitos destrutivos/transições por último e use ações síncronas.

## Configuração no Inspector

### Documento, livro ou objeto

1. Instancie `gameplay/objects/inspectable/inspectable.tscn`.
2. Em content crie/carregue um InspectionData e preencha title, body e image
   opcional. Use Resources diferentes para conteúdos diferentes.
3. Configure action_text e interaction_name herdados. Mantenha camada 8.
4. Para leitura persistente, mantenha persistent_read=true e atribua um
   persistent_id explícito e exclusivo, como `level_01/carta_lida`.
5. Opcionalmente atribua first_read_event_id distinto, por exemplo
   `level_01/primeira_carta`. A primeira abertura bem-sucedida registra o evento;
   a restauração não o executa nem emite first_read novamente.
6. Adicione uma instância de `ui/inspection/inspection_ui.tscn` à fase.

Estrutura mínima: fase Node2D com Player existente (incluindo Interactor e
InteractionPrompt), Inspectable/CollisionShape2D e InspectionUI. Todos os
inspectables usam a mesma interface. O estado de leitura fica no objeto/GameState,
nunca no Resource compartilhado. Sem persistência, a leitura local dura a instância;
o evento opcional continua idempotente em GameState.

### Habilidades

Em um GameplayEventTrigger interativo, configure um UnlockAbilityEffect em effects
e escolha ability_id. Para persistir a conclusão do objeto, marque
persistent_completion e dê event_id próprio. O estado da habilidade já persiste
pelas flags, independentemente desse evento.

O perfil `systems/abilities/default_profile.tres` pode ser editado no Inspector.
O padrão de GameState mantém as três habilidades habilitadas para saves e
fases legados. Chaves explícitas carregadas têm prioridade sobre o perfil. Só
aplique apply_ability_profile ao iniciar uma sessão/nova partida planejada, nunca
em resposta a progress_changed ou a cada `_ready()` de jogador. O laboratório
faz isso somente no início e no reset solicitado, preservando unlocks ao carregar.

### Condições e ações

Crie InteractionRequirement, FlagRequirement, ItemRequirement, EventRequirement,
AbilityRequirement ou ConditionGroup em requirements de qualquer Interactable.
Use failure_message para a mensagem do indicador. Em grupos, adicione Resources
ao array conditions, escolha ALL/ANY e não crie referências circulares.

Em effects, adicione SetFlagEffect, CollectItemEffect, CompleteEventEffect,
UnlockAbilityEffect, StartDialogueEffect ou ActivateMechanismEffect. Preencha os
IDs ou dados requeridos. Para mecanismo, target_path é relativo à **origem da
ação**, que será o gatilho/Interactable ou o próprio SequencePuzzle.
O alvo precisa ser FlagInteractable (inclui FlagDoor e FlagLever), habilitado e
com persistent_id/state_flag válidos. O NodePath é só referência de cena;
não é um ID persistente. Não use nomes de nós para gerar identidade persistente.

### Gatilho persistente

Instancie `gameplay/objects/event_trigger/event_trigger.tscn`. Escolha INTERACTION
ou AREA_ENTRY. Configure condition opcional, pelo menos um efeito em effects,
one_shot para execução local única, ou persistent_completion/event_id para
conclusão permanente. A modalidade de área usa corpos no grupo Player, máscara 1;
a modalidade interativa usa o indicador existente. Sem ID persistente válido,
um gatilho marcado permanente não pode ser salvo/ativado.

A condição falsa bloqueia antes dos efeitos. Falha de ação não marca conclusão.
Na carga, apenas apply_persistent_state restaura has_interacted; recompensas e
diálogos não são reexecutados. O DialogueTrigger legado continua operacional.

### Puzzle de sequência

Adicione um Node2D com `gameplay/objects/sequence_puzzle/sequence_puzzle.gd`.
Configure ordered_switch_ids com IDs estáveis na ordem desejada e success_actions.
Instancie pelo menos três `sequence_switch.tscn`, dê switch_id próprio a cada um
e arraste o nó SequencePuzzle para puzzle no Inspector. Os nomes dos nós podem
mudar sem alterar os IDs. Exemplos reais estão em AreaD do laboratório.

Ative permanent e atribua persistent_id exclusivo para salvar a conclusão.
Abra a porta com ActivateMechanismEffect ou SetFlagEffect usando a state_flag
da porta. A porta reaplica sua flag ao carregar, sem executar o puzzle novamente.
Conecte correct_input/incorrect_input/attempt_changed para feedback opcional.
reset_attempt limpa somente a tentativa; o reset de conclusão está restrito ao
botão de progresso da sessão de teste, sem API que apague campanha.

## Fase integrada e isolamento

Abra `scenes/levels/systems_test_entry.tscn` e use F6. A própria
`scenes/levels/systems_test_level.tscn` também aceita F6 com isolamento.
Nenhuma delas substitui o menu principal ou a fase existente.

- Área A: carta, objeto com imagem, livro e documento longo; NPC com texto provisório.
- Área B: acionador exige o evento de leitura da carta, mostra mensagem bloqueada
  e abre uma porta pela ação tipada. Há passagem inferior segura.
- Área C: desbloqueios de dash/pulo duplo, plataformas e paredes opostas; piso
  contínuo oferece rota alternativa. Entrada em área demonstra diálogo automático.
- Área D: três botões, ordem 2 → 1 → 3; erro reinicia tentativa, sucesso abre a porta
  e grava conclusão/recompensa. A passagem inferior permanece acessível.

HUD: Salvar teste, Recarregar teste, Reiniciar tentativa, Zerar progresso do teste
e Sair do laboratório. Os botões usam foco nativo (Tab/direcional e Enter/A) e mouse.
O menu de pausa existente também salva apenas no slot isolado durante a sessão.

A sessão captura progresso, pending_save e os quatro paths anteriores antes da
entrada segura. Usa `user://systems_lab_<processo>_<tempo>/`, sem tocar nos arquivos
normais. Permanece fora da cena nas recargas; scene_changed tem callback **sem
argumentos**. Ao sair, restaura o snapshot e os paths, remove apenas seus quatro
arquivos conhecidos e seu diretório. Encerramento normal da árvore também limpa.
Fechamento forçado do processo pode deixar o diretório temporário; ele não é
utilizado como slot da campanha. Não abra saves externos como forma de entrar no
laboratório: use a cena de entrada, que cria o isolamento antes da transição.

Zerar progresso inicia nova partida isolada com o perfil de teste; não apaga o
último save isolado, que ainda pode ser recarregado até encerrar a sessão.

## Controles

Nenhuma ação nova. `ui_cancel` existente foi configurada explicitamente com Esc/B;
os outros mapeamentos foram preservados. E/Y abre interação e fecha inspeção;
Esc/B fecha inspeção; ui_up/ui_down e roda do mouse rolam texto. A entrada que
abre a interface não a fecha no mesmo quadro. Durante inspeção o jogador continua
caindo, mas comandos de movimento/pulo/dash/agachamento ficam bloqueados.
Diálogo e pausa não podem sobrepor a inspeção. Fechar restaura foco e controle.

## Como executar os testes

Executável verificado nesta máquina:

```powershell
$engine = 'C:\Users\conta\OneDrive\Documentos\Desktop\Godot fidirapariga.exe'
& $engine --headless --editor --path . --import --quit
& $engine --headless --path . res://tests/modular_runner.tscn
& $engine --headless --path . res://tests/interaction_runner.tscn
& $engine --headless --path . res://tests/physics_dialogue_runner.tscn
& $engine --headless --path . res://tests/runner.tscn
```

Para executar a captura gráfica, crie previamente um diretório de saída e use:

```powershell
& $engine --path . --resolution 1280x720 res://tests/preview_runner.tscn -- 'C:\caminho\existente\capturas'
```

Esse runner precisa de renderização gráfica; não use --headless. Ele grava
laboratorio.png, inspecao.png e puzzle.png no diretório informado e encerra.
Os testes normais não modificam saves da campanha e comparam seus hashes.

## Resultados executados

Validação final em 27/10/2026, Windows, Godot 4.7.2. Todos os comandos abaixo
terminaram com saída 0. Os testes existentes não foram alterados ou removidos.

| Grupo | Aprovado | Falhou | Não executado |
| --- | --- | --- | --- |
| `tests/modular_runner.tscn` | 124 verificações | 0 | Nenhum caso da suíte |
| `tests/interaction_runner.tscn` | 51 verificações | 0 | Nenhum caso da suíte |
| `tests/physics_dialogue_runner.tscn` | 88 verificações | 0 | Nenhum caso da suíte |
| `tests/runner.tscn` | 159 verificações | 0 | Nenhum caso da suíte |
| Importação no editor headless | Sem erros de script/recurso | 0 | — |
| Inicialização de cenas por 30 quadros | Menu, fase original, demo, entrada do laboratório e laboratório direto | 0 | Percurso humano completo |
| Runner gráfico em 1280×720 | OpenGL, capturas de laboratório/inspeção/puzzle revisadas | 0 | Outras resoluções e controle físico |

Total: **422 verificações automatizadas, zero falhas**. A suíte nova inclui
abertura/fechamento e conteúdo, texto longo, imagem opcional, foco, teclado,
controle simulado, clique de mouse, conflitos de interfaces, gravidade, invalidação,
habilidades e restrições entre paredes, grupos e ciclos, ações e falhas parciais,
gatilhos, sequência, restauração, perfil e hashes dos arquivos normais.

Os seis avisos da suíte modular são esperados: dois ciclos, um filho ausente e
três sequências interrompidas propositalmente. A suíte de interação emite dois
avisos ao remover origem/personagem durante efeitos. Os 12 erros `[SAVE]` da
suíte de salvamento correspondem às falhas simuladas de leitura, gravação,
promoção, cenas inválidas e rollback; não são falhas de verificação. A importação,
os smoke tests e a execução gráfica final não apresentaram esses erros/avisos.

O ciclo integrado verifica a posição no sinal game_loaded, antes de a gravidade
retomar, e confirma leitura, habilidade, eventos, portas e puzzle após recarga.
Na saída, compara o estado anterior e os hashes dos quatro arquivos normais.
O teste de movimento usa também uma sonda de parede para as restrições de
wall jump/slide; isso não substitui a avaliação humana da sensação de movimento.

Revisão final comparada ao snapshot anterior à tarefa: 52 arquivos novos
(incluindo 18 UIDs) e 15 arquivos existentes modificados, todos ligados ao escopo;
nenhum arquivo inicial ausente. SaveManager e todos os parâmetros exportados do
jogador permaneceram idênticos. `git diff --check`, revisão dos diffs contra o
snapshot e verificação de espaços dos arquivos novos passaram. Esse registro é
anterior à organização do histórico: naquele momento a branch era `main`, sem
commit, push, reset ou mudança da cena principal. A organização posterior dos
commits locais usa `feat/sistemas-modulares`; a edição anterior da disposição
dos objetos na fase original permanece fora dos commits. Nenhum push foi feito.

## Limites e verificação manual restante

Os sistemas requeridos estão implementados; nenhum sistema fundamental ficou
substituído por stub. As entradas de controle foram simuladas: controle físico,
hotplug e sensação de movimento não foram validados por uma pessoa jogando.
A captura gráfica inspeciona layout em 1280×720; não comprova acessibilidade em
todas as resoluções. Não há rollback genérico de ações de gameplay.

Para a verificação manual: percorra A→D sem habilidades, confirme a rota inferior,
leia/role/feche cada conteúdo por teclado/controle/mouse, desbloqueie habilidades,
teste paredes opostas, erre e acerte o puzzle, salve e recarregue, zere o progresso
e saia. Confira que a pausa interrompe a queda, enquanto leitura/diálogo não.
Use apenas os controles do laboratório para persistência manual.

Próximo passo necessário: esse percurso manual com controle físico e teste de
legibilidade em resoluções menores, antes de usar os componentes em conteúdo final.
