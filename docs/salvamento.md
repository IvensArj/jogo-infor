# Salvamento e restauração

O sistema persiste a cena, a posição global do jogador e o progresso do mundo em JSON. A implementação está em [SaveManager](../systems/save/save_manager.gd) e [GameState](../systems/progress/game_state.gd).

## O que foi corrigido

| Comportamento anterior | Comportamento atual |
| --- | --- |
| O principal era apagado antes de promover o temporário. | O código promove o temporário por `rename_absolute()` sem apagar previamente o principal. As limitações do backend estão descritas abaixo. |
| Qualquer principal existente podia substituir o backup. | Somente um principal validado atualiza o backup. Um principal ausente ou corrompido preserva o backup existente. |
| Uma falha no carregamento podia deixar `GameState` alterado. | Um snapshot permite recuperar progresso, pausa, pendência e foco da interface, mantendo a instância anterior da cena viva durante a tentativa. |
| A importação apagava o progresso e notificava antes de terminar. | Todos os campos são validados antes da atribuição e a importação pública emite uma única notificação. |
| Objetos consultavam o progresso apenas ao iniciar. | Objetos reaplicam o estado quando `progress_changed` é emitido, inclusive em reset e rollback. |
| Não havia validação uniforme de IDs. | IDs são explícitos, estáveis e verificados na preparação da cena e no salvamento. |

## Arquivos e política de backup

Os caminhos anteriores foram preservados:

| Caminho | Finalidade |
| --- | --- |
| `user://savegame.json` | Save principal. |
| `user://savegame.tmp` | Nova gravação, ainda sem confirmação. |
| `user://savegame.bak` | Último principal válido preparado como backup. |
| `user://savegame.bak.tmp` | Preparação do backup antes de substituí-lo. |

O salvamento segue esta ordem:

1. Valida a cena, o jogador, os IDs e o progresso atual.
2. Grava, faz `flush()`, fecha e relê o temporário para validá-lo.
3. Se o principal for válido, prepara e valida o backup temporário e o promove para `.bak`.
4. Promove o novo temporário para o caminho principal.
5. Limpa temporários remanescentes e informa o resultado.

Se a preparação do backup falhar, a promoção do principal não começa. Se não houver principal válido, o backup existente não é rotacionado. A primeira gravação pode produzir somente o principal. Uma falha de promoção pode atualizar o backup para o principal que estava válido antes da tentativa.

`read_save()` procura primeiro o principal e, se ele estiver ausente ou inválido, tenta o backup. A leitura não promove arquivos nem aceita temporários como saves confirmados. `has_save()` utiliza a mesma validação.

Os quatro caminhos são configuráveis para isolar os testes. Origem e destino de cada promoção precisam ser arquivos distintos no mesmo diretório.

### Limites entre plataformas

O código não fornece uma garantia universal de substituição atômica. No Windows, o Godot 4.7.2 remove internamente um destino existente antes de executar `MoveFileW`; a operação pode falhar deixando o principal ausente. Por isso, a política conclui um backup válido antes da promoção do principal, permitindo recuperar a geração anterior pela leitura do `.bak`. [Implementação Windows do Godot 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/windows/dir_access_windows.cpp#L319-L325).

Essa recuperação cobre as falhas tratadas pelo fluxo e pressupõe armazenamento íntegro. `flush()` e a releitura não garantem durabilidade após queda de energia; a implementação Unix consultada utiliza `fflush()`, sem sincronização física equivalente a `fsync()`. [Implementação de `flush()` no Godot](https://github.com/godotengine/godot/blob/4.7/drivers/unix/file_access_unix.cpp#L312-L315).

## Formato e compatibilidade

Novas gravações usam a versão 2:

```json
{
  "version": 2,
  "scene": "res://scenes/levels/test_level.tscn",
  "player": {"position": {"x": 120.0, "y": 240.0}},
  "world": {
    "collected_items": ["test_level/coin_001"],
    "completed_events": ["test_level/intro"],
    "flags": {"gate_open": true, "boss_dead": false}
  },
  "meta": {"saved_at": "2026-10-24T12:00:00"}
}
```

A versão 1, com `player: {x, y}`, é convertida em memória para a estrutura atual e recebe progresso vazio. Isso também elimina o progresso de outra partida que estivesse em memória. A leitura não regrava o arquivo antigo; o próximo salvamento produz a versão 2.

Na versão 2, `world` e seus três campos são obrigatórios: itens e eventos são arrays de IDs, e flags são um dicionário de IDs para booleanos. JSON inválido, versões desconhecidas, tipos incorretos, coordenadas não finitas ou não representáveis por `Vector2` e caminhos de cena inválidos são rejeitados. Flags com valor `false` são preservadas. Metadados opcionais não interferem na restauração.

`GameState.import_data(data, notify)` valida e prepara os dicionários antes de substituir o estado. Dados inválidos retornam `false` sem modificar o progresso. O padrão `notify = true` emite `progress_changed` uma vez; a preparação e o rollback utilizam `false` para controlar a notificação no momento apropriado.

## Ciclo de carregamento

1. O carregador guarda um snapshot do progresso, da pausa, de `pending_save`, da cena atual e do controle com foco antes de instanciar a candidata, cobrindo também alterações em `GameState` durante `_init()`.
2. A tentativa bloqueia novas operações de salvamento/carregamento e pausa a árvore. A candidata é instanciada e validada fora da árvore.
3. Em execução adiada, a cena anterior sai da árvore, mas permanece viva. O progresso salvo é importado sem notificação antes da entrada da candidata.
4. A candidata executa seus callbacks de inicialização, recebe o estado dos objetos e passa por outra validação adiada.
5. O jogador recebe a posição global salva, tem a velocidade zerada quando é `CharacterBody2D` e reinicia a interpolação física.
6. No sucesso, a cena anterior é liberada, a pendência é limpa, os observadores são notificados e a nova partida fica despausada.

Quando a tentativa falha, a candidata é descartada e o carregador restaura o snapshot. A mesma instância da cena anterior é reinserida quando permanece válida. Sua remoção e reinserção podem executar novamente `_exit_tree()` e `_enter_tree()`. O controle que tinha foco o recupera se ainda existir, estiver na árvore, visível e aceitar foco; isso preserva a navegação por teclado sem depender de executar `_ready()` novamente.

A cena precisa conter exatamente um `Node2D` no grupo `Player`. A travessia ignora nós e subárvores marcados para exclusão. Antes de cada aplicação de estado, o objeto e seus ancestrais são verificados novamente: outra aplicação pode ter liberado ou removido um nó que ainda aparece no snapshot da travessia.

### Contrato dos scripts

O rollback cobre o estado controlado pelo carregador, não efeitos externos arbitrários. Durante `SaveManager.is_loading()`, `_init()`, `_enter_tree()`, `_ready()`, `_exit_tree()`, observadores e chamadas adiadas devem realizar apenas operações locais e reversíveis. Não devem gravar arquivos, emitir eventos externos de gameplay, alterar outros singletons ou criar objetos fora da cena.

Dados importantes não devem depender da entrada ou saída da árvore. `apply_persistent_state()` deve ser local e idempotente, definindo tanto estados positivos quanto negativos. Efeitos externos devem começar após `transition_finished(true)`. Esse contrato precisa ser respeitado pelos scripts; o carregador não o impõe automaticamente.

A interface atual mantém `apply_persistent_state() -> void`. Um retorno verificável para portas ou mecanismos cuja restauração possa falhar é uma evolução futura, ainda não implementada.

## APIs e sinais

| API ou sinal | Significado |
| --- | --- |
| `save_game() -> bool` | Resultado síncrono da gravação e validação; retorna `false` se o carregador estiver ocupado. |
| `new_game(path) -> bool` / `continue_game() -> bool` | `true` significa que a solicitação foi aceita; a restauração ainda precisa terminar. |
| `is_loading() -> bool` | Indica que há uma transição em preparação ou restauração. |
| `game_saved(success)` | Resultado de uma tentativa de gravação iniciada. |
| `game_loaded` | Continuação concluída, com cena, posição e objetos restaurados. Não é emitido para nova partida ou rollback. |
| `transition_finished(success)` | Resultado da transição de nova partida ou continuação. Falhas na preparação também podem emitir `false` antes de o método retornar. |
| `save_failed(message)` | Descreve falhas de salvamento ou carregamento. |

O menu de pausa bloqueia a saída para o menu principal enquanto há carregamento e não modifica `pending_save` diretamente.

## IDs e objetos persistentes

Defina IDs no Inspector e mantenha-os estáveis. A convenção para novos objetos é `nivel/objeto`, como `test_level/coin_001` ou `test_level/intro`. Não gere IDs a partir de nomes de nós, `NodePath`, posição ou `get_instance_id()`.

IDs antigos permanecem exatamente iguais, inclusive maiúsculas; não há conversão automática para a nova convenção. IDs vazios, com espaços nas extremidades, tabulações ou quebras de linha são inválidos. IDs de objetos persistentes devem ser únicos dentro da cena. O prefixo do nível evita colisões no progresso global entre cenas; a validação não percorre outras cenas para verificar essa convenção.

Um objeto persistente expõe `get_persistent_id()` e `apply_persistent_state()`. Opcionalmente, `uses_persistence()` permite desativar a exigência de ID, como nos gatilhos com `one_shot = false`.

O [coletável](../gameplay/objects/collectible/collectible.gd) deve ser anexado a um `Area2D` com `CollisionShape2D`. A coleta o esconde e desativa seu monitoramento, preservando a instância para reset e rollback. A atribuição adiada de `monitoring` é sempre agendada, mesmo que o valor atual já coincida: coletar e resetar no mesmo frame precisa preservar a última atualização.

O [gatilho de diálogo](../gameplay/objects/dialogue_trigger/dialogue_trigger.gd) recupera o evento concluído e reaplica `already_triggered` em notificações de progresso. Ambos observam `GameState.progress_changed` e verificam diretamente se estão na árvore e se algum ancestral está em exclusão, pois essas notificações não passam pela travessia do carregador. Seus handlers de `body_entered` também ignoram interações durante `SaveManager.is_loading()` para não iniciar coleta ou diálogo na preparação da cena.

## Leitura, habilidades e puzzles

Os [sistemas modulares](sistemas-modulares.md) mantêm o mesmo JSON v2. Leituras
persistentes usam seu ID em `world.completed_events`; eventos de primeira leitura
e puzzles concluídos usam IDs próprios nessa mesma categoria. Desbloqueios usam
flags booleanas `abilities/dash`, `abilities/double_jump` e `abilities/wall_jump`.
Itens e flags de mecanismos continuam usando as categorias existentes.

Nenhum campo novo foi introduzido. Saves v1/v2 sem flags de habilidade utilizam o
perfil padrão legado, com todas as habilidades habilitadas. Flags explícitas,
inclusive `false`, têm prioridade sobre o perfil. Importação e restauração não
emitem novos desbloqueios, primeiras leituras ou recompensas; objetos apenas
projetam seu estado persistente. Tentativas parciais de puzzle não são exportadas.

O laboratório usa paths temporários e um snapshot do GameState durante a sessão;
seus controles não gravam no slot normal. O perfil restrito do laboratório é
aplicado no início/reset do teste, nunca em cada carregamento. SaveManager,
validação, backup, rollback e restauração da posição permanecem inalterados.

## Como validar

Na raiz do projeto, com Godot 4.7 disponível como `godot`:

```bash
godot --headless --editor --path . --import --quit
godot --headless --path . res://tests/runner.tscn
```

A suíte usa cenas de teste e caminhos exclusivos em `user://save_tests_<identificador>/`, sem gravar nos saves normais. Ao terminar, remove seus arquivos e imprime a quantidade de verificações e falhas. O código de saída é `0` no sucesso e `1` quando uma verificação falha. Mensagens `[SAVE]` de erro são esperadas nas falhas simuladas; uma falha de verificação recebe o prefixo `TESTE:`.

A cobertura inclui v1 e v2, arquivos ausentes e corrompidos, validação do mundo, rotação e recuperação do backup, falhas de escrita e promoção, remoção do destino pelo backend, ciclo completo de cenas e objetos, IDs estáveis após renomear ou mudar o pai, rollback antes e depois de `_ready()`, recuperação do foco, nós liberados durante a aplicação de estado, guards dos sinais e coleta/reset no mesmo frame. O cenário destrutivo do Windows é simulado; o comando também deve ser executado nos sistemas de destino para validar o backend real.

Validação deste conjunto em 24/10/2026, com Godot 4.7.2 no Linux: importação headless sem erros, suíte com **155 verificações e 0 falhas** e saída `0`, preservando os saves normais e o estado dos autoloads. A fase existente também iniciou sem erros com `godot --headless --path . --quit-after 5 res://scenes/levels/test_level.tscn`, com saída `0`. A quantidade de verificações pode mudar conforme a suíte evoluir; o backend Windows não foi executado nessa validação.

Para uma verificação manual, crie uma cena com um jogador no grupo `Player`, um coletável com colisão e um gatilho com diálogo válido. Atribua IDs distintos no Inspector, colete o item, conclua o diálogo e salve. Saia e continue: confira posição, item oculto e diálogo de uso único já concluído. Renomeie ou mude o pai dos objetos mantendo seus IDs e repita. Um ID vazio ou duplicado deve impedir a preparação da cena ou o salvamento.
