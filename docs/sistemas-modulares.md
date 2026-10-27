# Sistemas modulares

Os componentes estendem Interactable, InteractionRequirement e InteractionEffect.
Não há outro sistema de interação ou persistência. O JSON v2 e a leitura v1 são preservados.

## Contexto e conclusão de ações

GameplayContext.is_live valida nó, árvore e ancestrais em exclusão.
InteractionEffect.validate_context e execute_sequence fazem preflight e execução
ordenada, com retorno booleano e aviso de falha parcial, sem promessa de rollback.
Interactable._complete_interaction retorna bool; o padrão chama o hook legado
_on_interact, preservando subclasses. Efeitos continuam Resources sem estado temporário.
