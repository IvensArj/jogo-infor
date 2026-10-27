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
