# Política futura de checkpoints

## Situação atual e escopo

Este documento é uma proposta, não uma proteção implementada. O
[SaveManager](../systems/save/save_manager.gd) continua gravando a posição global
atual do jogador no JSON v2 e restaurando essa posição ao continuar. O formato,
a leitura de v1, o backup, a validação e o rollback não foram alterados nesta tarefa.
Consulte [salvamento](salvamento.md) para os contratos atuais.

**Risco ainda existente:** salvar pelo menu dentro de uma seção difícil permite
retornar àquela posição, inclusive em plataformas temporárias, quedas ou estados
de puzzle não persistidos. A pausa verdadeira impede a queda enquanto o menu
está aberto, mas não transforma essa posição em um ponto de retorno seguro.

## Separação dos dados

| Tipo | Dados | Política futura |
| --- | --- | --- |
| Progresso persistente | Itens coletados, habilidades desbloqueadas, eventos e puzzles concluídos, mudanças permanentes no mundo | Salvar e restaurar pelo GameState existente. |
| Progresso temporário | Posição atual, entradas de puzzles incompletos, plataformas temporárias, velocidade, dash e comandos pendentes | Reinicializar ao carregar; não promover automaticamente a progresso persistente. |
| Retorno seguro | Identidade da fase e ID do último checkpoint concluído | Persistir como progresso; resolver a posição segura na configuração da fase. |

Habilidades e puzzles são categorias futuras: esta proposta não cria inventário,
sistema de habilidades ou sistema de puzzles. Eventos e flags existentes podem
representar conclusões permanentes quando houver conteúdo que use essas regras.
Tentativas incompletas e mecanismos temporários devem ter estado inicial definido
ao restaurar a fase, sem reaplicar efeitos de interação.

## Ativação e retorno

1. Cada fase define uma entrada segura explícita. Ela é o retorno padrão de uma
   nova partida ou de uma partida sem checkpoint válido para a fase.
2. Cada checkpoint tem um ID explícito e estável, como `level_01/checkpoint_001`,
   e um ponto de retorno configurado no conteúdo da fase. Nomes de nós, NodePath,
   posição e IDs de instância não podem gerar a identidade persistente.
3. Só a conclusão validada de um checkpoint atualiza o último retorno. Uma mera
   passagem por um puzzle incompleto não registra conclusão.
4. Salvar manualmente grava o progresso permanente e o último checkpoint válido;
   não cria, ativa nem move um checkpoint para a posição atual do jogador.
5. Ao carregar, resolver fase e ID, aplicar o progresso permanente e reconstruir
   o estado temporário antes de posicionar o jogador. Limpar movimento e entradas
   pendentes e reiniciar a interpolação física, preservando o fluxo de transição.
6. Se o ID for desconhecido, removido, de outra fase ou seu retorno estiver
   bloqueado após aplicar o progresso, usar a entrada segura da fase. Se nem a
   entrada for válida, falhar e executar rollback, sem posicionar em local arbitrário.

A validação de segurança deverá considerar colisão, apoio estável, perigos e o
estado persistente do mundo. Coordenadas finitas, isoladamente, não garantem
um retorno seguro. IDs renomeados precisam de um mapa explícito de migração;
trocar o nome de um nó não deve afetar o checkpoint.

## Mudanças futuras no GameState

- Manter `collected_items`, `completed_events`, `flags` e `progress_changed`,
  com os métodos existentes compatíveis.
- Acrescentar estado tipado para a associação entre fase e último checkpoint
  concluído. Booleanos em `flags` não devem receber strings ou coordenadas;
  uma coleção de eventos concluídos, sozinha, não informa qual checkpoint foi o último.
- Oferecer consulta e atualização explícitas de checkpoint, validando IDs e
  notificando somente após uma alteração válida. A posição física fica no conteúdo
  da fase, não em um segundo registro paralelo de posições no GameState.
- Estender `normalize_data`, `import_data`, `export_data` e `reset_progress`
  de forma conjunta. Preparar todos os dados antes de substituir o estado e manter
  o modo sem notificação para restauração e rollback.
- Incluir os novos campos no snapshot transacional; uma transição com falha
  deve restaurar exatamente o checkpoint anterior e o restante do progresso.

## Mudanças futuras no SaveManager

- Manter uma única persistência JSON. Planejar uma nova versão do formato apenas
  junto da implementação e dos testes de migração; nenhuma alteração de formato
  foi feita agora.
- Em `_build_save_data`, deixar de usar a posição atual como retorno da partida.
  Gravar a identidade validada de fase/checkpoint fornecida pelo GameState.
- Em `_normalize_save`, validar a nova estrutura e converter formatos legados
  em memória. Manter validação de cenas, tipos, IDs e rejeição de versões desconhecidas.
- Em `_complete_transition`, resolver o retorno após a restauração do mundo e
  validar a posição antes de concluir. Preservar a limpeza de velocidade e
  interpolação e acrescentar limpeza explícita de estados temporários do jogador.
- Preservar escrita em temporário, releitura, rotação somente de principal válido,
  recuperação pelo backup, sinais públicos e o contrato de callbacks reversíveis.
  Não abrir uma segunda rota de carregamento fora do rollback existente.

## Compatibilidade e migração

Os saves v1 e v2 continuam funcionando exatamente como hoje até a implementação
futura. Para a migração, a proposta é preservar o progresso permanente disponível
(v1 não possui progresso do mundo), mas usar a entrada segura da fase como retorno
quando não houver checkpoint identificado. A posição legada **não deve se tornar
um checkpoint**: isso manteria o problema dos saves arbitrários.

Essa mudança futura de local de retorno precisa ser comunicada ao jogador e
validada com saves antigos reais. A leitura deve migrar apenas em memória; o
arquivo antigo só deve ser substituído em um salvamento confirmado, seguindo a
política existente de backup. Principal e backup precisam aceitar as versões
suportadas independentemente. Não converter nem sobrescrever o backup válido
por dados incompletos. Manter os caminhos de fases distribuídas ou oferecer
mapeamento de migração explícito quando houver mudança de caminho.

## Testes exigidos antes de mudar o comportamento

- Salvar manualmente em posições diferentes mantém o mesmo checkpoint.
- Concluir um checkpoint altera somente o retorno permitido; um checkpoint
  incompleto não altera o anterior. IDs duplicados ou inválidos são rejeitados.
- Carregar restaura itens, eventos, flags e puzzles concluídos, reinicia estados
  temporários e retorna ao checkpoint válido ou à entrada segura.
- Cobrir ausência de checkpoint, ID removido, mudança de nome/pai do nó, outra fase,
  colisão no retorno e entrada inválida, inclusive falha com rollback completo.
- Cobrir migração de v1/v2, formato futuro, versões desconhecidas, principal
  corrompido com backup legado e backups de versões diferentes.
- Reexecutar os testes de gravação, promoção, corrupção, rollback e isolamento de
  saves; acrescentar snapshot/restauração do novo estado de checkpoint.

## Validação das correções de física e diálogo

A suíte focada desta tarefa fica em `tests/physics_dialogue_runner.tscn`:

```text
godot --headless --editor --path . --import --quit
godot --headless --path . res://tests/physics_dialogue_runner.tscn
godot --headless --path . res://tests/interaction_runner.tscn
godot --headless --path . res://tests/runner.tscn
```

Ela não testa checkpoints implementados, pois eles ainda não existem. Teclado e
controle são simulados; sensação de movimento, apresentação visual e hardware
físico continuam exigindo validação manual.

Validação em 26/10/2026, Windows, Godot 4.7.2: importação sem erros; suíte de
física/diálogo com 88 verificações, interação com 51 e salvamento com 159, todas
sem falhas e com saída 0. As mensagens `[SAVE]` de erro pertencem às falhas
simuladas da suíte de salvamento. Menu principal, fase de testes e demonstração
de interação carregaram em headless por 30 quadros, sem erros. `git diff --check`
passou; os arquivos novos também foram revisados quanto a espaços no fim das linhas.
