# Sistemas modulares

Os componentes estendem Interactable, InteractionRequirement e InteractionEffect.
Não há outro sistema de interação ou persistência. O JSON v2 e a leitura v1 são preservados.

## Contexto e conclusão de ações

GameplayContext.is_live valida nó, árvore e ancestrais em exclusão.
InteractionEffect.validate_context e execute_sequence fazem preflight e execução
ordenada, com retorno booleano e aviso de falha parcial, sem promessa de rollback.
Interactable._complete_interaction retorna bool; o padrão chama o hook legado
_on_interact, preservando subclasses. Efeitos continuam Resources sem estado temporário.

## Inspeção

Instancie gameplay/objects/inspectable/inspectable.tscn e uma
ui/inspection/inspection_ui.tscn na fase com o Player existente. Atribua
um InspectionData em content com title, body e image opcional. Configure
persistent_id estável, persistent_read e first_read_event_id opcional.
A primeira abertura bem-sucedida grava completed_events; restauração não recompensa.
DialogueManager.begin_inspection/end_inspection e sinais sem argumentos arbitram
inspeção e diálogo. Gravidade e colisão continuam; comandos ficam bloqueados.
E/Y/Esc/B fecha; ui_up/down rola; botão Fechar aceita mouse. ui_cancel existente
recebe Esc/B, sem ação ou Autoload novo. Fechar restaura foco e controle.
Fonte inválida ou transição fecha a interface.
Testes: godot --headless --path . res://tests/modular_runner.tscn

## Habilidades

AbilityProfile e systems/abilities/default_profile.tres configuram o padrão
legado no Inspector, com dash, double_jump e wall_jump habilitados.
GameState.has_ability consulta flags abilities/<id> antes do padrão.
unlock_ability retorna true e emite ability_unlocked somente no primeiro desbloqueio.
apply_ability_profile é exclusivo do início de uma sessão, nunca da recarga.
Flags explícitas, inclusive false, persistem no JSON existente; reset limpa o
progresso e volta ao perfil. O jogador só ganhou guardas, sem alterar parâmetros.

## Condições

Use InteractionRequirement (sempre true), FlagRequirement (expected_value true/false),
ItemRequirement, EventRequirement, AbilityRequirement ou ConditionGroup no Inspector.
is_met(actor) retorna bool sem efeitos; is_configured valida configuração.
ConditionGroup.conditions aceita ALL/ANY aninhados; ALL vazio true, ANY vazio false.
Ciclos diretos/indiretos e filhos inválidos bloqueiam o grupo com aviso, sem pilha global.
Flag válida ausente vale false; ID inválido nunca satisfaz um requisito.

## Ações

Nos effects existentes use SetFlagEffect, CollectItemEffect, CompleteEventEffect,
UnlockAbilityEffect, StartDialogueEffect e ActivateMechanismEffect. Configure IDs,
diálogo ou target_path relativo à origem. O alvo precisa ser FlagInteractable
(como FlagDoor), habilitado e com IDs válidos; activate() é uma interface tipada.
Restauração usa apply_persistent_state sem recompensas. Recompensas são idempotentes.
Diálogo falha com outra interface bloqueante. Ações anteriores a uma falha podem
permanecer aplicadas; preflight não é uma transação.

## Gatilhos

Instancie gameplay/objects/event_trigger/event_trigger.tscn. Selecione INTERACTION
ou AREA_ENTRY, condition opcional e pelo menos uma ação em effects.
Configure one_shot para a instância ou persistent_completion/event_id para persistir.
Área usa grupo Player, camada 8 e máscara 1; interação usa o indicador existente.
Condição falsa impede ações. Falha não grava conclusão. Durante carga, somente
apply_persistent_state projeta GameState; recompensas não são reexecutadas.
DialogueTrigger legado é preservado.
