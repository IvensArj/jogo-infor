# Inspeção e plano de integração

Registro anterior à implementação, em 26/10/2026. A árvore já contém mudanças
locais da reorganização e das correções de física/diálogo; elas serão preservadas.
O status inicial completo e cópias dos fontes foram registrados fora do repositório
em um diretório temporário `jogo-infor-baseline-*` para revisão ao terminar.

## Sistemas existentes e APIs

| Sistema | Caminho | Contrato reutilizado |
| --- | --- | --- |
| Jogador | `gameplay/player/player.gd` e `player.tscn` | CharacterBody2D, uma resolução física, grupo Player, colisão física padrão e Interactor na camada de consulta 8. |
| Interação | `systems/interaction/interactor.gd`, `interactable.gd` | `try_interact`, `interact -> bool`, `can_interact`, `interacted`, `interaction_denied`, indicador e requisitos/efeitos configuráveis. |
| Condições | `systems/interaction/requirements/` | `InteractionRequirement.is_met(actor)`, flag (true/false), item, evento; base representa condição sempre verdadeira. |
| Ações | `systems/interaction/effects/` | `InteractionEffect.is_valid`, `execute(actor, source) -> bool`; flag, item e evento já existem. |
| Mecanismos | `systems/interaction/flag_interactable.gd`, `gameplay/objects/door/flag_door.gd` | Projeção idempotente de flag, `apply_persistent_state`, colisão adiada, IDs explícitos. |
| Diálogo | `systems/dialogue/`, `ui/dialogue/`, `gameplay/npc/` | `start_dialogue(data, source = null)`, `end_dialogue`, `blocks_interaction`, sinais sem argumentos de início/fim e linha tipada. |
| Gatilho legado | `gameplay/objects/dialogue_trigger/` | Ativação automática, guarda `SaveManager.is_loading`; API preservada. |
| Progresso | `systems/progress/game_state.gd` | Itens/eventos por ID, flags booleanas, import/export/reset e `progress_changed`. |
| Persistência | `systems/save/save_manager.gd` | JSON v2, leitura v1, validação, backup, rollback e caminhos configuráveis. Importa progresso antes de `_ready`; restaura posição em `_complete_transition`, depois aplica velocidade zero/interpolação. |
| Menus | `ui/main_menu/`, `ui/pause_menu/` | Pausa real por SceneTree.paused e foco nativo; sinais de botões e transição existente. |
| Testes | `tests/runner.tscn`, `interaction_runner.tscn`, `physics_dialogue_runner.tscn` | Runners próprios com contadores, saves isolados e saída por resultado. |

Input Map existente: move_left/right, jump, dash, crouch, interact e pause;
usar também as ações nativas ui_cancel/up/down/accept. Não adicionar ações.
Godot encontrado e verificado: 4.7.2.stable.official.ed1daf0bf.
`SceneTree.scene_changed` não envia argumento; o SaveManager o emite sem argumento.

## Integração mínima planejada

- Inspeção: Resource de conteúdo, Interactable especializado e uma UI compartilhada.
  Um nó auxiliar dentro de DialogueManager arbitra a inspeção; nenhum Autoload novo.
- Habilidades: perfil Resource com padrões legados habilitados; flags booleanas
  `abilities/<id>` em GameState e sinal somente para desbloqueio novo. Apenas
  três guardas nos pontos existentes de dash, pulo aéreo e pulo de parede.
- Condições: estender os requisitos existentes com habilidade e grupos ALL/ANY,
  validando ciclos por chamada, sem pilha global.
- Validação de contexto compartilhada em um auxiliar sem estado, mantendo
  Interactable.is_live compatível e evitando dependência circular com efeitos.
- Ações: estender efeitos existentes com desbloqueio, diálogo e ativação tipada
  de FlagInteractable. Reutilizar a ordem/preflight, sem alegar transação.
- Gatilho: subclasse Interactable com interação/entrada em área, condição e efeitos.
- Puzzle: Node2D que recebe IDs de switches Interactable, guarda tentativa local,
  executa os mesmos efeitos e restaura conclusão por evento existente.
- Laboratório: `scenes/levels/systems_test_level.tscn`, sessão de teste fora das
  cenas substituídas para manter paths isolados e snapshot do progresso original.

Mudanças previstas: GameState, pontos de habilidade/bloqueio do jogador,
DialogueManager, Interactor, pausa e validação de contexto dos efeitos existentes.
Novos componentes ficam em gameplay/objects, systems/inspection,
systems/abilities, nas pastas existentes de requisitos/efeitos, ui/inspection,
scenes/levels/systems_test e tests. Nenhuma cena principal será substituída.

## Riscos a verificar

Foco e entrada de abertura/fechamento; diálogos e inspeção mutuamente exclusivos;
fontes liberadas; perfil de teste aplicado só no início da sessão; cargas não
reexecutam recompensas; falhas parciais não marcam conclusão; recursos com ciclos;
saída do laboratório restaura paths e progresso anteriores. Preservar a transação
do SaveManager e sua emissão de scene_changed sem parâmetros. O save continua v2.
